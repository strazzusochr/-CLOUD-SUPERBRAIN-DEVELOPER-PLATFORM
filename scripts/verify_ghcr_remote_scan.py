#!/usr/bin/env python3
"""Run and verify the fail-closed Trivy scan for all GHCR platform digests.

The workflow installs one checksum-pinned Trivy binary, then this script scans
the twelve immutable platform manifests from ``ghcr-release-manifest-v1``.
Aggregate evidence is written only after every report proves zero secret
findings and zero HIGH/CRITICAL vulnerabilities.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence


CONTRACT_VERSION = "remote-image-scan-evidence-v1"
GHCR_MANIFEST_CONTRACT = "ghcr-release-manifest-v1"
TRIVY_VERSION = "0.72.0"
TRIVY_BINARY_SHA256 = "0e69edd134a3c338baa1a6806920773615d682b18cbc6a0cba2a3b658ef9b63e"
TRIVY_DOWNLOAD_URL = (
    "https://github.com/aquasecurity/trivy/releases/download/"
    "v0.72.0/trivy_0.72.0_Linux-64bit.tar.gz"
)
EXPECTED_SERVICES = (
    "agent-api",
    "mcp-gateway",
    "frontend",
    "llm-gateway",
    "agent-worker",
    "memory-worker",
)
EXPECTED_PLATFORMS = ("linux/amd64", "linux/arm64")
DIGEST_RE = re.compile(r"sha256:[0-9a-f]{64}")
SHA256_RE = re.compile(r"[0-9a-f]{64}")
SHA40_RE = re.compile(r"[0-9a-f]{40}")


class VerificationError(RuntimeError):
    """Raised when remote scan evidence cannot be credited."""


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise VerificationError(message)


def _read_json(path: Path, label: str) -> tuple[dict[str, Any], bytes]:
    _require(path.is_file(), f"{label} is missing: {path}")
    try:
        raw = path.read_bytes()
        value = json.loads(raw.decode("utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise VerificationError(f"{label} is not valid UTF-8 JSON") from exc
    _require(isinstance(value, dict), f"{label} must be a JSON object")
    return value, raw


def _sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _require_digest(value: Any, label: str) -> str:
    _require(isinstance(value, str) and DIGEST_RE.fullmatch(value) is not None, f"{label} is not a sha256 digest")
    return value


def _require_sha40(value: Any, label: str) -> str:
    _require(isinstance(value, str) and SHA40_RE.fullmatch(value) is not None, f"{label} is not a lowercase 40-hex SHA")
    return value


def _parse_timestamp(value: Any, label: str) -> str:
    _require(isinstance(value, str) and value, f"{label} is missing")
    normalized = value[:-1] + "+00:00" if value.endswith("Z") else value
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError as exc:
        raise VerificationError(f"{label} is not an RFC3339 timestamp") from exc
    _require(parsed.tzinfo is not None, f"{label} must include a timezone")
    return value


def report_filename(service: str, platform: str) -> str:
    _require(service in EXPECTED_SERVICES, f"unknown service for report filename: {service}")
    _require(platform in EXPECTED_PLATFORMS, f"unknown platform for report filename: {platform}")
    return f"{service}-{platform.replace('/', '-')}.trivy.json"


def _manifest_matrix(manifest: Mapping[str, Any]) -> tuple[str, str, str, str, list[dict[str, str]]]:
    _require(manifest.get("contract_version") == GHCR_MANIFEST_CONTRACT, "GHCR manifest contract mismatch")
    _require(manifest.get("status") == "verified", "GHCR manifest is not verified")
    _require(manifest.get("registry") == "ghcr.io", "GHCR manifest registry mismatch")
    _require(manifest.get("publication_complete") is True, "GHCR publication is incomplete")
    _require(manifest.get("secret_output") is False, "GHCR manifest secret_output must be false")
    _require(manifest.get("mutable_tag_fallback_used") is False, "mutable tag fallback is forbidden")

    namespace = manifest.get("namespace")
    _require(
        isinstance(namespace, str)
        and re.fullmatch(r"ghcr\.io/[a-z0-9_.-]+/[a-z0-9_.-]+", namespace) is not None,
        "GHCR namespace is invalid",
    )
    candidate_sha = _require_sha40(manifest.get("candidate_sha"), "candidate_sha")
    control_sha = _require_sha40(manifest.get("control_sha"), "control_sha")
    _require(candidate_sha != control_sha, "candidate and control SHA must remain distinct")
    active = manifest.get("active_release_candidate")
    _require(isinstance(active, dict), "active release-candidate binding is missing")
    release_id = active.get("release_id")
    _require(
        isinstance(release_id, str) and re.fullmatch(r"prod-candidate-[A-Za-z0-9._-]+", release_id) is not None,
        "active release id is invalid",
    )
    _require(active.get("source_commit_sha") == candidate_sha, "active release source mismatch")

    images = manifest.get("images")
    _require(isinstance(images, list) and len(images) == 6, "GHCR manifest must contain exactly six images")
    _require(manifest.get("service_count") == 6, "GHCR manifest service_count must be six")
    _require(manifest.get("unique_top_digest_count") == 6, "GHCR manifest must prove six top digests")

    expected_source = None
    workflow = manifest.get("workflow")
    if isinstance(workflow, dict) and isinstance(workflow.get("repository"), str):
        expected_source = f"https://github.com/{workflow['repository']}"
    _require(expected_source is not None, "workflow repository binding is missing")

    services: set[str] = set()
    top_digests: set[str] = set()
    platform_digests: set[str] = set()
    matrix: list[dict[str, str]] = []
    for image in images:
        _require(isinstance(image, dict), "GHCR image entry must be an object")
        service = image.get("service")
        _require(service in EXPECTED_SERVICES, "GHCR manifest contains an unknown service")
        _require(service not in services, f"GHCR manifest duplicates service {service}")
        services.add(service)
        top_digest = _require_digest(image.get("digest"), f"{service} top digest")
        _require(top_digest not in top_digests, f"GHCR manifest duplicates top digest for {service}")
        top_digests.add(top_digest)
        _require(image.get("image_ref") == f"{namespace}/{service}:{candidate_sha}", f"{service} candidate tag mismatch")
        entries = image.get("index_platforms")
        _require(isinstance(entries, list) and len(entries) == 2, f"{service} must have exactly two platform digests")
        seen_platforms: set[str] = set()
        for entry in entries:
            _require(isinstance(entry, dict), f"{service} platform entry must be an object")
            platform = entry.get("platform")
            _require(platform in EXPECTED_PLATFORMS, f"{service} has an unexpected platform")
            _require(platform not in seen_platforms, f"{service} duplicates platform {platform}")
            seen_platforms.add(platform)
            platform_digest = _require_digest(entry.get("digest"), f"{service} {platform} digest")
            _require(platform_digest not in platform_digests, f"platform digest is duplicated: {platform_digest}")
            platform_digests.add(platform_digest)
            digest_ref = f"{namespace}/{service}@{platform_digest}"
            _require(entry.get("digest_ref") == digest_ref, f"{service} {platform} immutable reference mismatch")
            labels = entry.get("oci_labels")
            _require(isinstance(labels, dict), f"{service} {platform} OCI labels are missing")
            _require(labels.get("org.opencontainers.image.source") == expected_source, f"{service} {platform} OCI source mismatch")
            _require(labels.get("org.opencontainers.image.revision") == candidate_sha, f"{service} {platform} OCI revision mismatch")
            _require(labels.get("org.opencontainers.image.version") == f"candidate-{candidate_sha}", f"{service} {platform} OCI version mismatch")
            matrix.append(
                {
                    "service": service,
                    "platform": platform,
                    "digest": platform_digest,
                    "digest_ref": digest_ref,
                    "top_digest": top_digest,
                }
            )
        _require(seen_platforms == set(EXPECTED_PLATFORMS), f"{service} platform set is incomplete")

    _require(services == set(EXPECTED_SERVICES), "GHCR service set is incomplete")
    _require(len(top_digests) == 6, "six unique top digests are required")
    _require(len(platform_digests) == 12 and len(matrix) == 12, "twelve unique platform digests are required")
    matrix.sort(key=lambda item: (EXPECTED_SERVICES.index(item["service"]), EXPECTED_PLATFORMS.index(item["platform"])))
    return release_id, candidate_sha, control_sha, namespace, matrix


def _finding_counts(report: Mapping[str, Any], label: str) -> tuple[int, int, int]:
    results = report.get("Results", [])
    _require(isinstance(results, list), f"{label} Results must be an array")
    secrets = 0
    high = 0
    critical = 0
    for result in results:
        _require(isinstance(result, dict), f"{label} result entry must be an object")
        secret_entries = result.get("Secrets", [])
        vulnerability_entries = result.get("Vulnerabilities", [])
        _require(isinstance(secret_entries, list), f"{label} Secrets must be an array")
        _require(isinstance(vulnerability_entries, list), f"{label} Vulnerabilities must be an array")
        secrets += len(secret_entries)
        for vulnerability in vulnerability_entries:
            _require(isinstance(vulnerability, dict), f"{label} vulnerability must be an object")
            severity = vulnerability.get("Severity")
            if severity == "HIGH":
                high += 1
            elif severity == "CRITICAL":
                critical += 1
    return secrets, high, critical


def build_remote_scan_evidence(
    manifest_path: Path,
    reports_dir: Path,
    db_metadata_path: Path,
    *,
    trivy_version: str,
    trivy_binary_sha256: str,
) -> dict[str, Any]:
    """Validate already-produced raw Trivy reports and return aggregate evidence."""

    manifest, manifest_raw = _read_json(Path(manifest_path), "GHCR manifest")
    release_id, candidate_sha, control_sha, namespace, matrix = _manifest_matrix(manifest)
    _require(trivy_version == TRIVY_VERSION, "Trivy version is not pinned to the approved release")
    _require(trivy_binary_sha256 == TRIVY_BINARY_SHA256, "Trivy binary checksum is not the approved pin")
    _require(Path(reports_dir).is_dir(), "Trivy reports directory is missing")

    expected_names = {report_filename(item["service"], item["platform"]) for item in matrix}
    actual_names = {path.name for path in Path(reports_dir).iterdir() if path.is_file()}
    _require(actual_names == expected_names, "Trivy report set has missing or unexpected files")

    db_metadata, db_raw = _read_json(Path(db_metadata_path), "Trivy DB metadata")
    db_version = db_metadata.get("Version", db_metadata.get("version"))
    _require(type(db_version) is int and db_version > 0, "Trivy DB metadata Version is invalid")
    updated_at = _parse_timestamp(db_metadata.get("UpdatedAt", db_metadata.get("updated_at")), "Trivy DB UpdatedAt")
    next_update = _parse_timestamp(db_metadata.get("NextUpdate", db_metadata.get("next_update")), "Trivy DB NextUpdate")
    downloaded_at = _parse_timestamp(db_metadata.get("DownloadedAt", db_metadata.get("downloaded_at")), "Trivy DB DownloadedAt")

    scans: list[dict[str, Any]] = []
    total_secrets = 0
    total_high = 0
    total_critical = 0
    for item in matrix:
        filename = report_filename(item["service"], item["platform"])
        report_path = Path(reports_dir) / filename
        report, raw = _read_json(report_path, f"Trivy report {filename}")
        _require(report.get("SchemaVersion") == 2, f"{filename} SchemaVersion must be 2")
        _require(report.get("ArtifactName") == item["digest_ref"], f"{filename} immutable ArtifactName mismatch")
        _require(report.get("ArtifactType") == "container_image", f"{filename} ArtifactType mismatch")
        _parse_timestamp(report.get("CreatedAt"), f"{filename} CreatedAt")
        metadata = report.get("Metadata")
        _require(isinstance(metadata, dict), f"{filename} Metadata is missing")
        repo_digests = metadata.get("RepoDigests")
        if repo_digests is not None:
            _require(isinstance(repo_digests, list) and item["digest_ref"] in repo_digests, f"{filename} RepoDigests mismatch")
        secret_count, high_count, critical_count = _finding_counts(report, filename)
        _require(secret_count == 0, f"{filename} secret findings must be zero (observed {secret_count})")
        _require(high_count == 0, f"{filename} HIGH vulnerabilities must be zero (observed {high_count})")
        _require(critical_count == 0, f"{filename} CRITICAL vulnerabilities must be zero (observed {critical_count})")
        total_secrets += secret_count
        total_high += high_count
        total_critical += critical_count
        scans.append(
            {
                "service": item["service"],
                "platform": item["platform"],
                "top_digest": item["top_digest"],
                "image_digest": item["digest"],
                "immutable_reference": item["digest_ref"],
                "report_path": f"trivy-reports/{filename}",
                "report_sha256": _sha256(raw),
                "secret_findings": secret_count,
                "high_vulnerabilities": high_count,
                "critical_vulnerabilities": critical_count,
                "status": "verified",
            }
        )

    binding_material = "\n".join(
        f"{scan['service']}|{scan['platform']}|{scan['image_digest']}|{scan['report_sha256']}"
        for scan in scans
    ) + "\n"
    return {
        "contract_version": CONTRACT_VERSION,
        "status": "verified",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
        "release_id": release_id,
        "source_commit_sha": candidate_sha,
        "control_commit_sha": control_sha,
        "registry": "ghcr.io",
        "namespace": namespace,
        "manifest": {
            "contract_version": GHCR_MANIFEST_CONTRACT,
            "path": Path(manifest_path).name,
            "sha256": _sha256(manifest_raw),
        },
        "scanner": {
            "name": "trivy",
            "version": TRIVY_VERSION,
            "version_pinned": True,
            "binary_sha256": TRIVY_BINARY_SHA256,
            "binary_checksum_verified": True,
            "download_url": TRIVY_DOWNLOAD_URL,
            "scanners": ["vuln", "secret"],
            "severity_gate": ["HIGH", "CRITICAL"],
            "ignore_unfixed": False,
            "database": {
                "metadata_path": Path(db_metadata_path).name,
                "metadata_sha256": _sha256(db_raw),
                "version": db_version,
                "updated_at": updated_at,
                "next_update": next_update,
                "downloaded_at": downloaded_at,
            },
        },
        "service_count": 6,
        "top_digest_count": 6,
        "platform_digest_count": 12,
        "scan_count": len(scans),
        "secret_findings": total_secrets,
        "high_vulnerabilities": total_high,
        "critical_vulnerabilities": total_critical,
        "scans": scans,
        "aggregate_binding_sha256": hashlib.sha256(binding_material.encode("utf-8")).hexdigest(),
        "all_platform_digests_scanned": True,
        "credit_eligible": True,
        "remote_registry_read_only": True,
        "registry_write_performed": False,
        "registry_delete_performed": False,
        "provider_writes": False,
        "production_deploy": False,
        "release_promotion": False,
        "secret_output": False,
    }


def _write_json_exclusive(path: Path, value: Mapping[str, Any]) -> None:
    _require(path.parent.is_dir(), f"output parent directory is missing: {path.parent}")
    try:
        with path.open("x", encoding="utf-8", newline="\n") as handle:
            json.dump(value, handle, indent=2, sort_keys=True, ensure_ascii=True)
            handle.write("\n")
    except FileExistsError as exc:
        raise VerificationError(f"output already exists and cannot be overwritten: {path}") from exc


def _copy_exclusive(source: Path, destination: Path) -> None:
    _require(source.is_file(), f"Trivy DB metadata is missing after scan: {source}")
    _require(destination.parent.is_dir(), f"DB metadata output parent is missing: {destination.parent}")
    try:
        with source.open("rb") as input_handle, destination.open("xb") as output_handle:
            shutil.copyfileobj(input_handle, output_handle)
    except FileExistsError as exc:
        raise VerificationError("Trivy DB metadata output already exists") from exc


def execute_remote_scans(
    manifest_path: Path,
    trivy_binary: Path,
    reports_dir: Path,
    cache_dir: Path,
    db_metadata_output: Path,
) -> None:
    _require(trivy_binary.is_file(), "checksum-pinned Trivy binary is missing")
    observed_binary_sha = _sha256(trivy_binary.read_bytes())
    _require(observed_binary_sha == TRIVY_BINARY_SHA256, "Trivy executable checksum mismatch")
    version = subprocess.run(
        [str(trivy_binary), "--version"],
        check=False,
        capture_output=True,
        text=True,
        timeout=30,
    )
    _require(version.returncode == 0, "Trivy version check failed")
    _require(re.search(rf"(?m)^Version:\s*{re.escape(TRIVY_VERSION)}\s*$", version.stdout) is not None, "Trivy runtime version mismatch")

    manifest, _ = _read_json(manifest_path, "GHCR manifest")
    _, _, _, _, matrix = _manifest_matrix(manifest)
    _require(not reports_dir.exists(), "Trivy reports directory must not already exist")
    reports_dir.mkdir(parents=False)
    cache_dir.mkdir(parents=True, exist_ok=True)

    for item in matrix:
        output = reports_dir / report_filename(item["service"], item["platform"])
        command = [
            str(trivy_binary),
            "--cache-dir",
            str(cache_dir),
            "image",
            "--scanners",
            "vuln,secret",
            "--severity",
            "HIGH,CRITICAL",
            "--format",
            "json",
            "--output",
            str(output),
            "--exit-code",
            "1",
            "--no-progress",
            "--timeout",
            "15m",
            item["digest_ref"],
        ]
        # Scanner diagnostics are intentionally not persisted: they are not
        # needed for the gate and can expose registry implementation details.
        try:
            result = subprocess.run(
                command,
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=20 * 60,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise VerificationError(
                f"Trivy execution failed for {item['service']} {item['platform']}"
            ) from exc
        _require(
            result.returncode == 0,
            f"Trivy rejected {item['service']} {item['platform']} (findings or scan failure)",
        )
        _require(output.is_file(), f"Trivy report was not emitted for {item['service']} {item['platform']}")

    _copy_exclusive(cache_dir / "db" / "metadata.json", db_metadata_output)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--trivy-binary", type=Path, required=True)
    parser.add_argument("--reports-dir", type=Path, required=True)
    parser.add_argument("--cache-dir", type=Path, required=True)
    parser.add_argument("--db-metadata-output", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        execute_remote_scans(
            args.manifest,
            args.trivy_binary,
            args.reports_dir,
            args.cache_dir,
            args.db_metadata_output,
        )
        evidence = build_remote_scan_evidence(
            args.manifest,
            args.reports_dir,
            args.db_metadata_output,
            trivy_version=TRIVY_VERSION,
            trivy_binary_sha256=TRIVY_BINARY_SHA256,
        )
        _write_json_exclusive(args.output, evidence)
    except VerificationError as exc:
        print(f"[ghcr-remote-scan] ERROR: {exc}", file=sys.stderr)
        return 1
    print(
        "[ghcr-remote-scan] PASS services=6 top_digests=6 platform_digests=12 "
        "secrets=0 high=0 critical=0 scanner=trivy@0.72.0"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

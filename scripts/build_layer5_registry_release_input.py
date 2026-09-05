#!/usr/bin/env python3
"""Build the exact Layer-5 86->100 registry release scorer input."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any, Mapping, Sequence

from collect_ghcr_publication_evidence import (
    ENVIRONMENT_NAME,
    REGISTRY_DIGEST_CONTRACT,
    REVIEW_CONTRACT,
)
from verify_ghcr_remote_scan import (
    CONTRACT_VERSION as REMOTE_SCAN_CONTRACT,
    EXPECTED_PLATFORMS,
    EXPECTED_SERVICES,
    GHCR_MANIFEST_CONTRACT,
    TRIVY_VERSION,
    _manifest_matrix,
)


CONTRACT_VERSION = "layer5-registry-release-credit-evidence-v1"
SBOM_CONTRACT = "mcp-candidate-sbom-evidence-v2"
REQUIRED_SYFT_VERSION = "1.51.0"
REQUIRED_SYFT_BINARY_SHA256 = "75adfff66c266adac51fe8addeca97702f82b4d822d02bf70b79f556c84d3a46"
CRITERIA = (
    ("immutable_registry_digests", 3, "ghcr_manifest"),
    ("candidate_sbom", 3, "candidate_sbom"),
    ("remote_image_scan", 2, "remote_image_scan"),
    ("protected_publish", 6, "registry_publication_review"),
)
SHA256_RE = re.compile(r"[0-9a-f]{64}")
DIGEST_RE = re.compile(r"sha256:[0-9a-f]{64}")


class VerificationError(RuntimeError):
    """Raised when any of the four Layer-5 criteria is unproven."""


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


def _artifact(contract: str, path: Path, raw: bytes) -> dict[str, str]:
    return {"contract_version": contract, "path": path.name, "sha256": _sha256(raw)}


def _resolve_child(parent: Path, relative: Any, label: str) -> Path:
    _require(isinstance(relative, str) and relative and "\\" not in relative, f"{label} path is invalid")
    candidate = Path(relative)
    _require(not candidate.is_absolute() and ".." not in candidate.parts, f"{label} path escapes the evidence directory")
    resolved_parent = parent.resolve()
    resolved = (parent / candidate).resolve()
    _require(resolved == resolved_parent or resolved_parent in resolved.parents, f"{label} path escapes the evidence directory")
    return resolved


def _validate_review(review: Mapping[str, Any], release_id: str, candidate_sha: str, control_sha: str) -> None:
    _require(review.get("contract_version") == REVIEW_CONTRACT, "registry publication review contract mismatch")
    _require(review.get("status") == "verified", "registry publication review is not verified")
    _require(review.get("release_id") == release_id, "registry publication review release mismatch")
    _require(review.get("source_commit_sha") == candidate_sha, "registry publication review source mismatch")
    _require(review.get("control_commit_sha") == control_sha, "registry publication review control mismatch")
    _require(review.get("environment") == ENVIRONMENT_NAME, "registry publication review environment mismatch")
    approval = review.get("review")
    _require(isinstance(approval, dict) and approval.get("state") == "approved", "registry publication review is not approved")
    reviewer_distinct = approval.get("reviewer_distinct_from_triggering_actor")
    _require(type(reviewer_distinct) is bool, "registry publication reviewer/actor relation is invalid")
    _require(approval.get("required_reviewers_configured") is True, "registry publication required reviewers are not configured")
    prevent_self_review = approval.get("prevent_self_review")
    _require(type(prevent_self_review) is bool, "registry publication prevent_self_review setting is invalid")
    if prevent_self_review:
        _require(reviewer_distinct is True, "registry publication violated its self-review prevention rule")
    # The collector records the environment's policy, but credit has a stricter
    # reviewer-separation contract. A valid self-review receipt is not L5 credit.
    _require(reviewer_distinct is True, "registry publication reviewer separation is required for credit")
    reviewer = approval.get("reviewer")
    _require(isinstance(reviewer, dict) and reviewer.get("type") == "User", "registry publication reviewer is invalid")
    reviewer_login = reviewer.get("login")
    _require(isinstance(reviewer_login, str) and bool(reviewer_login.strip()), "registry publication reviewer login is invalid")
    jobs = review.get("publish_jobs")
    _require(isinstance(jobs, list) and len(jobs) == 6 and review.get("publish_job_count") == 6, "registry publication must bind six publish jobs")
    _require({job.get("service") for job in jobs if isinstance(job, dict)} == set(EXPECTED_SERVICES), "registry publication job service set mismatch")
    for job in jobs:
        _require(isinstance(job, dict), "registry publication job must be an object")
        _require(job.get("status") == "completed" and job.get("conclusion") == "success", "registry publication job did not succeed")
        push = job.get("push_step")
        _require(isinstance(push, dict) and push.get("status") == "completed" and push.get("conclusion") == "success", "registry publication push step did not execute")
    workflow = review.get("workflow")
    _require(isinstance(workflow, dict), "registry publication workflow binding is missing")
    actor = workflow.get("triggering_actor")
    _require(isinstance(actor, str) and bool(actor.strip()), "registry publication triggering actor is invalid")
    _require(reviewer_login.casefold() != actor.casefold(), "registry publication reviewer separation contradicts recorded identities")
    _require(workflow.get("name") == "main-deploy" and workflow.get("event") == "workflow_dispatch", "registry publication workflow mismatch")
    _require(workflow.get("run_attempt") == 1 and review.get("plan_only") is False, "static or rerun publication evidence is not credit eligible")
    artifact = review.get("artifact")
    _require(isinstance(artifact, dict), "registry publication artifact binding is missing")
    _require(isinstance(artifact.get("id"), str) and artifact["id"].isdigit(), "registry publication artifact id is invalid")
    _require(isinstance(artifact.get("digest"), str) and DIGEST_RE.fullmatch(artifact["digest"]) is not None, "registry publication artifact digest is invalid")
    _require(review.get("all_publish_jobs_successful") is True and review.get("all_publish_steps_executed") is True, "registry publication jobs are incomplete")
    _require(review.get("approval_required_before_publish_jobs") is True, "registry publication review did not gate publish jobs")
    _require(review.get("registry_publish_performed") is True and review.get("registry_publish_verified") is True, "registry publication is not verified")
    for key, expected in (
        ("production_deploy", False),
        ("release_promotion", False),
        ("provider_writes", False),
        ("secret_output", False),
    ):
        _require(review.get(key) is expected, f"registry publication review {key} non-claim mismatch")


def _validate_registry(
    registry: Mapping[str, Any],
    manifest: Mapping[str, Any],
    remote: Mapping[str, Any],
    review: Mapping[str, Any],
    *,
    manifest_sha: str,
    remote_sha: str,
    review_sha: str,
) -> None:
    release_id, candidate_sha, control_sha, namespace, matrix = _manifest_matrix(manifest)
    _require(registry.get("contract_version") == REGISTRY_DIGEST_CONTRACT, "candidate registry digest contract mismatch")
    _require(registry.get("status") == "verified", "candidate registry digest evidence is not verified")
    _require(registry.get("release_id") == release_id, "candidate registry release mismatch")
    _require(registry.get("source_commit_sha") == candidate_sha, "candidate registry source mismatch")
    _require(registry.get("control_commit_sha") == control_sha, "candidate registry control mismatch")
    _require(registry.get("namespace") == namespace, "candidate registry namespace mismatch")
    _require(registry.get("service_count") == 6 and registry.get("top_digest_count") == 6, "candidate registry top digest counts mismatch")
    _require(registry.get("platform_digest_count") == 12, "candidate registry platform digest count mismatch")
    _require(registry.get("registry_publish_verified") is True, "candidate registry publication is not verified")
    _require(registry.get("remote_scan_verified") is True, "candidate registry remote scan is not verified")
    _require(registry.get("protected_publish_review_verified") is True, "candidate registry protected review is not verified")
    _require(registry.get("mutable_reference_used") is False, "candidate registry uses a mutable reference")
    _require(registry.get("ghcr_manifest") == {"contract_version": GHCR_MANIFEST_CONTRACT, "sha256": manifest_sha}, "candidate registry GHCR manifest binding mismatch")
    remote_binding = registry.get("remote_image_scan")
    _require(isinstance(remote_binding, dict) and remote_binding.get("contract_version") == REMOTE_SCAN_CONTRACT and remote_binding.get("sha256") == remote_sha, "candidate registry remote scan binding mismatch")
    review_binding = registry.get("publication_review")
    _require(isinstance(review_binding, dict) and review_binding.get("contract_version") == REVIEW_CONTRACT and review_binding.get("sha256") == review_sha, "candidate registry publication review binding mismatch")

    expected_platform = {(item["service"], item["platform"]): item for item in matrix}
    manifest_images = {image["service"]: image for image in manifest["images"]}
    remote_scans = {(scan["service"], scan["platform"]): scan for scan in remote["scans"]}
    images = registry.get("images")
    _require(isinstance(images, list) and len(images) == 6, "candidate registry must contain six images")
    seen: set[str] = set()
    top_digests: set[str] = set()
    platform_digests: set[str] = set()
    for image in images:
        _require(isinstance(image, dict), "candidate registry image must be an object")
        service = image.get("service")
        _require(service in EXPECTED_SERVICES and service not in seen, "candidate registry service set is invalid")
        seen.add(service)
        manifest_image = manifest_images[service]
        top_digest = image.get("digest")
        _require(top_digest == manifest_image["digest"] and top_digest not in top_digests, "candidate registry top digest mismatch")
        top_digests.add(top_digest)
        _require(image.get("immutable_reference") == f"{namespace}/{service}@{top_digest}", "candidate registry immutable top reference mismatch")
        _require(image.get("oci_revision") == candidate_sha, "candidate registry OCI revision mismatch")
        _require(image.get("oci_source") == f"https://github.com/{manifest['workflow']['repository']}", "candidate registry OCI source mismatch")
        attestation = image.get("attestation")
        _require(isinstance(attestation, dict) and attestation.get("verified") is True and attestation.get("statement_sha256") == manifest_sha, "candidate registry attestation mismatch")
        platforms = image.get("platform_digests")
        _require(isinstance(platforms, list) and len(platforms) == 2, "candidate registry image must contain two platform digests")
        service_report_hashes: list[str] = []
        observed_platforms: set[str] = set()
        for platform in platforms:
            _require(isinstance(platform, dict), "candidate registry platform entry must be an object")
            platform_name = platform.get("platform")
            key = (service, platform_name)
            _require(key in expected_platform and platform_name not in observed_platforms, "candidate registry platform set mismatch")
            observed_platforms.add(platform_name)
            expected = expected_platform[key]
            _require(platform.get("digest") == expected["digest"], "candidate registry platform digest mismatch")
            _require(platform.get("immutable_reference") == expected["digest_ref"], "candidate registry immutable platform reference mismatch")
            platform_digests.add(platform["digest"])
            scan = platform.get("remote_scan")
            expected_scan = remote_scans[key]
            _require(isinstance(scan, dict) and scan.get("verified") is True, "candidate registry platform scan is not verified")
            _require(scan.get("scanner") == "trivy" and scan.get("scanner_version") == TRIVY_VERSION, "candidate registry platform scanner mismatch")
            _require(scan.get("report_sha256") == expected_scan["report_sha256"], "candidate registry platform report hash mismatch")
            _require(scan.get("secret_findings") == 0 and scan.get("high_vulnerabilities") == 0 and scan.get("critical_vulnerabilities") == 0, "candidate registry platform scan is not clean")
            service_report_hashes.append(scan["report_sha256"])
        _require(observed_platforms == set(EXPECTED_PLATFORMS), "candidate registry platform set is incomplete")
        service_binding = hashlib.sha256(("\n".join(service_report_hashes) + "\n").encode("utf-8")).hexdigest()
        aggregate_scan = image.get("remote_scan")
        _require(isinstance(aggregate_scan, dict) and aggregate_scan.get("verified") is True, "candidate registry service scan is not verified")
        _require(aggregate_scan.get("platform_scan_count") == 2 and aggregate_scan.get("report_sha256") == service_binding, "candidate registry service scan binding mismatch")
    _require(seen == set(EXPECTED_SERVICES) and len(top_digests) == 6 and len(platform_digests) == 12, "candidate registry digest inventory is incomplete")


def _validate_sbom(
    sbom: Mapping[str, Any],
    sbom_path: Path,
    registry: Mapping[str, Any],
    release_id: str,
    candidate_sha: str,
) -> None:
    _require(sbom.get("contract_version") == SBOM_CONTRACT, "candidate sbom contract mismatch")
    _require(sbom.get("status") == "verified", "candidate sbom is not verified")
    _require(sbom.get("release_id") == release_id, "candidate sbom release mismatch")
    _require(sbom.get("source_commit_sha") == candidate_sha, "candidate sbom source mismatch")
    _require(sbom.get("service_count") == 6 and sbom.get("sbom_count") == 6, "candidate sbom count must be six")
    _require(sbom.get("sbom_format") == "CycloneDX JSON", "candidate sbom format mismatch")
    _require(sbom.get("syft_version") == REQUIRED_SYFT_VERSION, "candidate sbom Syft version mismatch")
    _require(
        sbom.get("syft_binary_sha256") == REQUIRED_SYFT_BINARY_SHA256,
        "candidate sbom Syft binary hash mismatch",
    )
    _require(sbom.get("immutable_registry_digests_bound") is True and sbom.get("credit_eligible") is True, "candidate sbom is not registry-bound and credit eligible")
    _require(sbom.get("registry_publish_performed") is False, "candidate sbom verifier must remain read-only")
    _require(sbom.get("provider_writes") is False and sbom.get("production_deploy") is False and sbom.get("secret_output") is False, "candidate sbom non-claim mismatch")
    registry_images = {image["service"]: image for image in registry["images"]}
    images = sbom.get("images")
    _require(isinstance(images, list) and len(images) == 6, "candidate sbom image inventory must contain six items")
    seen: set[str] = set()
    for image in images:
        _require(isinstance(image, dict), "candidate sbom image entry must be an object")
        service = image.get("service")
        _require(service in registry_images and service not in seen, "candidate sbom service inventory mismatch")
        seen.add(service)
        registry_image = registry_images[service]
        _require(image.get("registry_digest") == registry_image["digest"], "candidate sbom registry digest mismatch")
        _require(image.get("immutable_registry_reference") == registry_image["immutable_reference"], "candidate sbom immutable reference mismatch")
        _require(image.get("remote_scan_sha256") == registry_image["remote_scan"]["report_sha256"], "candidate sbom remote scan binding mismatch")
        _require(image.get("bom_format") == "CycloneDX", "candidate sbom entry format mismatch")
        expected_hash = image.get("sbom_sha256")
        _require(isinstance(expected_hash, str) and SHA256_RE.fullmatch(expected_hash) is not None, "candidate sbom hash is invalid")
        raw_path = _resolve_child(sbom_path.parent, image.get("sbom_path"), f"{service} sbom")
        sbom_document, raw = _read_json(raw_path, f"{service} CycloneDX sbom")
        _require(_sha256(raw) == expected_hash, f"{service} sbom hash mismatch")
        _require(sbom_document.get("bomFormat") == "CycloneDX", f"{service} document is not CycloneDX")
        _require(isinstance(sbom_document.get("components"), list) and len(sbom_document["components"]) > 0, f"{service} CycloneDX components are missing")
    _require(seen == set(EXPECTED_SERVICES), "candidate sbom service set is incomplete")


def build_layer5_registry_release_input(
    ghcr_manifest_path: Path,
    candidate_registry_digests_path: Path,
    remote_image_scan_path: Path,
    candidate_sbom_path: Path,
    registry_publication_review_path: Path,
) -> dict[str, Any]:
    paths = [
        Path(ghcr_manifest_path),
        Path(candidate_registry_digests_path),
        Path(remote_image_scan_path),
        Path(candidate_sbom_path),
        Path(registry_publication_review_path),
    ]
    manifest, manifest_raw = _read_json(paths[0], "GHCR manifest")
    registry, registry_raw = _read_json(paths[1], "candidate registry digests")
    remote, remote_raw = _read_json(paths[2], "remote image scan")
    sbom, sbom_raw = _read_json(paths[3], "candidate sbom")
    review, review_raw = _read_json(paths[4], "registry publication review")
    release_id, candidate_sha, control_sha, _, matrix = _manifest_matrix(manifest)
    manifest_sha = _sha256(manifest_raw)
    remote_sha = _sha256(remote_raw)
    review_sha = _sha256(review_raw)
    _require(remote.get("contract_version") == REMOTE_SCAN_CONTRACT and remote.get("credit_eligible") is True, "remote image scan is not credit eligible")
    _require(remote.get("release_id") == release_id and remote.get("source_commit_sha") == candidate_sha and remote.get("control_commit_sha") == control_sha, "remote image scan candidate binding mismatch")
    _require(remote.get("scan_count") == 12 and remote.get("secret_findings") == 0 and remote.get("high_vulnerabilities") == 0 and remote.get("critical_vulnerabilities") == 0, "remote image scan findings/count mismatch")
    _require(len(matrix) == 12, "GHCR manifest platform matrix mismatch")
    _validate_review(review, release_id, candidate_sha, control_sha)
    _validate_registry(registry, manifest, remote, review, manifest_sha=manifest_sha, remote_sha=remote_sha, review_sha=review_sha)
    _validate_sbom(sbom, paths[3], registry, release_id, candidate_sha)

    artifacts = {
        "ghcr_manifest": _artifact(GHCR_MANIFEST_CONTRACT, paths[0], manifest_raw),
        "candidate_registry_digests": _artifact(REGISTRY_DIGEST_CONTRACT, paths[1], registry_raw),
        "remote_image_scan": _artifact(REMOTE_SCAN_CONTRACT, paths[2], remote_raw),
        "candidate_sbom": _artifact(SBOM_CONTRACT, paths[3], sbom_raw),
        "registry_publication_review": _artifact(REVIEW_CONTRACT, paths[4], review_raw),
    }
    criteria = [
        {
            "id": criterion_id,
            "points": points,
            "status": "verified",
            "evidence_sha256": artifacts[artifact_id]["sha256"],
        }
        for criterion_id, points, artifact_id in CRITERIA
    ]
    return {
        "contract_version": CONTRACT_VERSION,
        "status": "verified",
        "scope": "vertical",
        "cell_id": "layer_5",
        "old_percent": 86,
        "new_percent": 100,
        "points_awarded": 14,
        "credit_eligible": True,
        "release_id": release_id,
        "source_commit_sha": candidate_sha,
        "control_commit_sha": control_sha,
        "owner_grant_ref": registry.get("owner_grant_ref"),
        "criteria": criteria,
        "artifacts": artifacts,
        "registry_summary": {
            "service_count": 6,
            "unique_top_digest_count": 6,
            "platform_digest_count": 12,
        },
        "sbom_summary": {
            "sbom_count": 6,
            "bom_format": "CycloneDX",
            "credit_eligible": True,
        },
        "scan_summary": {
            "scanner": "trivy",
            "scanner_version": TRIVY_VERSION,
            "scan_count": 12,
            "secret_findings": 0,
            "high_vulnerabilities": 0,
            "critical_vulnerabilities": 0,
        },
        "review_summary": {
            "environment": ENVIRONMENT_NAME,
            "state": "approved",
            "run_id": review["workflow"]["run_id"],
            "run_attempt": 1,
            "reviewer": review["review"]["reviewer"]["login"],
            "reviewer_distinct_from_triggering_actor": review["review"]["reviewer_distinct_from_triggering_actor"],
        },
        "registry_publish_performed": True,
        "production_deploy": False,
        "release_promotion": False,
        "provider_writes": False,
        "secret_output": False,
    }


def _write_exclusive(path: Path, value: Mapping[str, Any]) -> None:
    _require(path.parent.is_dir(), f"output parent directory is missing: {path.parent}")
    try:
        with path.open("x", encoding="utf-8", newline="\n") as handle:
            json.dump(value, handle, indent=2, sort_keys=True, ensure_ascii=True)
            handle.write("\n")
    except FileExistsError as exc:
        raise VerificationError(f"output already exists and cannot be overwritten: {path}") from exc


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ghcr-manifest", type=Path, required=True)
    parser.add_argument("--candidate-registry-digests", type=Path, required=True)
    parser.add_argument("--remote-image-scan", type=Path, required=True)
    parser.add_argument("--candidate-sbom", type=Path, required=True)
    parser.add_argument("--registry-publication-review", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        evidence = build_layer5_registry_release_input(
            args.ghcr_manifest,
            args.candidate_registry_digests,
            args.remote_image_scan,
            args.candidate_sbom,
            args.registry_publication_review,
        )
        _write_exclusive(args.output, evidence)
    except VerificationError as exc:
        print(f"[layer5-registry-release-input] ERROR: {exc}", file=sys.stderr)
        return 1
    print("[layer5-registry-release-input] PASS credit_eligible=true points=14 transition=86->100")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

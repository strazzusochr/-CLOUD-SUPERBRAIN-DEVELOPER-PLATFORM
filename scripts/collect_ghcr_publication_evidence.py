#!/usr/bin/env python3
"""Collect fail-closed GHCR publication, review, and digest evidence.

Inputs are read-only GitHub REST responses captured by ``main-deploy`` after the
six protected publish jobs completed. The collector persists no API token and
never copies approval comments into its sanitized evidence.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence

from verify_ghcr_remote_scan import (
    CONTRACT_VERSION as REMOTE_SCAN_CONTRACT,
    EXPECTED_PLATFORMS,
    EXPECTED_SERVICES,
    GHCR_MANIFEST_CONTRACT,
    TRIVY_BINARY_SHA256,
    TRIVY_VERSION,
    _manifest_matrix,
)


REVIEW_CONTRACT = "registry-publication-review-evidence-v1"
REGISTRY_DIGEST_CONTRACT = "candidate-registry-digests-v1"
CAPABILITY_CONTRACT = "capability-gate-state-v1"
ENVIRONMENT_NAME = "registry-publication"
SHA256_RE = re.compile(r"[0-9a-f]{64}")
DIGEST_RE = re.compile(r"sha256:[0-9a-f]{64}")
RUN_ID_RE = re.compile(r"[1-9][0-9]*")


class VerificationError(RuntimeError):
    """Raised when protected registry publication cannot be proven."""


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise VerificationError(message)


def _json_bytes(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=True) + "\n").encode("utf-8")


def _sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _read_json(path: Path, label: str, *, array_allowed: bool = False) -> tuple[Any, bytes]:
    _require(path.is_file(), f"{label} is missing: {path}")
    try:
        raw = path.read_bytes()
        value = json.loads(raw.decode("utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise VerificationError(f"{label} is not valid UTF-8 JSON") from exc
    if array_allowed:
        _require(isinstance(value, (dict, list)), f"{label} must be a JSON object or array")
    else:
        _require(isinstance(value, dict), f"{label} must be a JSON object")
    return value, raw


def _timestamp(value: Any, label: str) -> str:
    _require(isinstance(value, str) and value, f"{label} is missing")
    normalized = value[:-1] + "+00:00" if value.endswith("Z") else value
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError as exc:
        raise VerificationError(f"{label} is not an RFC3339 timestamp") from exc
    _require(parsed.tzinfo is not None, f"{label} must contain a timezone")
    return value


def _validate_remote_scan(remote: Mapping[str, Any], remote_path: Path, manifest_sha256: str, matrix: list[dict[str, str]]) -> None:
    _require(remote.get("contract_version") == REMOTE_SCAN_CONTRACT, "remote image scan contract mismatch")
    _require(remote.get("status") == "verified", "remote image scan is not verified")
    _require(remote.get("credit_eligible") is True, "remote image scan is not credit eligible")
    _require(remote.get("service_count") == 6, "remote image scan service count mismatch")
    _require(remote.get("top_digest_count") == 6, "remote image scan top digest count mismatch")
    _require(remote.get("platform_digest_count") == 12, "remote image scan platform digest count mismatch")
    _require(remote.get("scan_count") == 12, "remote image scan must contain twelve scans")
    _require(remote.get("secret_findings") == 0, "remote image scan contains secret findings")
    _require(remote.get("high_vulnerabilities") == 0, "remote image scan contains HIGH vulnerabilities")
    _require(remote.get("critical_vulnerabilities") == 0, "remote image scan contains CRITICAL vulnerabilities")
    _require(remote.get("secret_output") is False, "remote image scan secret_output must be false")
    _require(remote.get("registry_write_performed") is False, "remote scan may not write to the registry")
    manifest_binding = remote.get("manifest")
    _require(isinstance(manifest_binding, dict) and manifest_binding.get("sha256") == manifest_sha256, "remote scan GHCR manifest hash mismatch")
    scanner = remote.get("scanner")
    _require(isinstance(scanner, dict), "remote scan scanner binding is missing")
    _require(scanner.get("name") == "trivy", "remote scan must use Trivy")
    _require(scanner.get("version") == TRIVY_VERSION and scanner.get("version_pinned") is True, "remote scan Trivy version pin mismatch")
    _require(scanner.get("binary_sha256") == TRIVY_BINARY_SHA256 and scanner.get("binary_checksum_verified") is True, "remote scan Trivy checksum pin mismatch")
    _require(scanner.get("scanners") == ["vuln", "secret"], "remote scan must enable vuln and secret scanners")
    _require(scanner.get("severity_gate") == ["HIGH", "CRITICAL"], "remote scan severity gate mismatch")

    scans = remote.get("scans")
    _require(isinstance(scans, list) and len(scans) == 12, "remote scan entries must contain exactly twelve items")
    expected = {(item["service"], item["platform"]): item for item in matrix}
    observed: set[tuple[str, str]] = set()
    report_hashes: set[str] = set()
    for scan in scans:
        _require(isinstance(scan, dict), "remote scan entry must be an object")
        key = (scan.get("service"), scan.get("platform"))
        _require(key in expected, "remote scan contains an unexpected service/platform")
        _require(key not in observed, "remote scan duplicates a service/platform")
        observed.add(key)
        expected_item = expected[key]
        _require(scan.get("image_digest") == expected_item["digest"], "remote scan digest mismatch")
        _require(scan.get("immutable_reference") == expected_item["digest_ref"], "remote scan immutable reference mismatch")
        _require(scan.get("top_digest") == expected_item["top_digest"], "remote scan top digest mismatch")
        report_hash = scan.get("report_sha256")
        _require(isinstance(report_hash, str) and SHA256_RE.fullmatch(report_hash) is not None, "remote scan report hash is invalid")
        _require(report_hash not in report_hashes, "remote scan report hash is duplicated")
        report_hashes.add(report_hash)
        report_relative = scan.get("report_path")
        _require(isinstance(report_relative, str) and re.fullmatch(r"trivy-reports/[a-z0-9-]+\.trivy\.json", report_relative) is not None, "remote scan report path is invalid")
        report_file = remote_path.parent / report_relative
        _require(report_file.is_file(), f"remote scan raw report is missing: {report_relative}")
        _require(_sha256(report_file.read_bytes()) == report_hash, f"remote scan raw report hash mismatch: {report_relative}")
        _require(scan.get("secret_findings") == 0, "remote scan entry contains a secret")
        _require(scan.get("high_vulnerabilities") == 0, "remote scan entry contains a HIGH vulnerability")
        _require(scan.get("critical_vulnerabilities") == 0, "remote scan entry contains a CRITICAL vulnerability")
    _require(observed == set(expected), "remote scan service/platform set is incomplete")


def _select_publish_jobs(jobs_payload: Mapping[str, Any], control_sha: str) -> list[dict[str, Any]]:
    jobs = jobs_payload.get("jobs")
    _require(isinstance(jobs, list), "workflow jobs response is missing jobs")
    selected: dict[str, dict[str, Any]] = {}
    pattern = re.compile(r"^Publish immutable (agent-api|mcp-gateway|frontend|llm-gateway|agent-worker|memory-worker) candidate(?: \(.*\))?$")
    for job in jobs:
        if not isinstance(job, dict) or not isinstance(job.get("name"), str):
            continue
        match = pattern.fullmatch(job["name"])
        if match is None:
            continue
        service = match.group(1)
        _require(service not in selected, f"workflow jobs duplicate publish service {service}")
        _require(job.get("status") == "completed" and job.get("conclusion") == "success", f"publish job did not succeed: {service}")
        _require(job.get("head_sha") == control_sha, f"publish job control SHA mismatch: {service}")
        started_at = _timestamp(job.get("started_at"), f"{service} publish job started_at")
        completed_at = _timestamp(job.get("completed_at"), f"{service} publish job completed_at")
        steps = job.get("steps")
        _require(isinstance(steps, list), f"publish job steps are missing: {service}")
        push_steps = [step for step in steps if isinstance(step, dict) and step.get("name") == "Build and push absent candidate tag once"]
        _require(len(push_steps) == 1, f"publish push step is missing or duplicated: {service}")
        push_step = push_steps[0]
        _require(push_step.get("status") == "completed" and push_step.get("conclusion") == "success", f"publish push step was skipped or failed: {service}")
        selected[service] = {
            "service": service,
            "job_id": job.get("id"),
            "name": job["name"],
            "status": "completed",
            "conclusion": "success",
            "started_at": started_at,
            "completed_at": completed_at,
            "push_step": {
                "name": "Build and push absent candidate tag once",
                "status": "completed",
                "conclusion": "success",
                "started_at": _timestamp(push_step.get("started_at"), f"{service} push step started_at"),
                "completed_at": _timestamp(push_step.get("completed_at"), f"{service} push step completed_at"),
            },
        }
    _require(set(selected) == set(EXPECTED_SERVICES), "exactly six successful publish jobs are required")
    return [selected[service] for service in EXPECTED_SERVICES]


def _require_candidate_preflight(jobs_payload: Mapping[str, Any], control_sha: str) -> None:
    """Bind the dispatch candidate through the successful fail-closed preflight.

    GitHub's workflow-run REST response does not expose ``workflow_dispatch``
    inputs. The preflight job is therefore the API-visible proof that the exact
    candidate input was validated before any protected publication job ran.
    """

    jobs = jobs_payload.get("jobs")
    _require(isinstance(jobs, list), "workflow jobs response is missing jobs")
    matches = [
        job
        for job in jobs
        if isinstance(job, dict) and job.get("name") == "Bind control SHA to tracked candidate truth"
    ]
    _require(len(matches) == 1, "exactly one candidate preflight job is required")
    preflight = matches[0]
    _require(
        preflight.get("status") == "completed" and preflight.get("conclusion") == "success",
        "candidate preflight job did not succeed",
    )
    _require(preflight.get("head_sha") == control_sha, "candidate preflight control SHA mismatch")
    steps = preflight.get("steps")
    _require(isinstance(steps, list), "candidate preflight steps are missing")
    validation_steps = [
        step
        for step in steps
        if isinstance(step, dict) and step.get("name") == "Validate control branch and active candidate"
    ]
    _require(len(validation_steps) == 1, "candidate preflight validation step is missing or duplicated")
    validation = validation_steps[0]
    _require(
        validation.get("status") == "completed" and validation.get("conclusion") == "success",
        "candidate preflight validation step did not succeed",
    )


def _select_review(approvals_payload: Any, environment_payload: Mapping[str, Any], triggering_actor: str) -> dict[str, Any]:
    _require(isinstance(approvals_payload, list), "workflow approval history must be an array")
    relevant: list[Mapping[str, Any]] = []
    for approval in approvals_payload:
        if not isinstance(approval, dict) or approval.get("state") != "approved":
            continue
        environments = approval.get("environments")
        if isinstance(environments, list) and any(
            isinstance(item, dict) and item.get("name") == ENVIRONMENT_NAME for item in environments
        ):
            relevant.append(approval)
    _require(len(relevant) == 1, "exactly one approved registry-publication review is required")
    approval = relevant[0]
    user = approval.get("user")
    _require(isinstance(user, dict), "approved registry-publication review has no reviewer")
    login = user.get("login")
    _require(isinstance(login, str) and re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})", login) is not None, "registry-publication reviewer login is invalid")
    _require(user.get("type") == "User", "registry-publication reviewer must be a real User")
    _require(type(user.get("id")) is int and user["id"] > 0, "registry-publication reviewer id is invalid")
    reviewer_distinct = login.casefold() != triggering_actor.casefold()

    _require(environment_payload.get("name") == ENVIRONMENT_NAME, "registry-publication environment readback mismatch")
    rules = environment_payload.get("protection_rules")
    _require(isinstance(rules, list), "registry-publication protection rules are unavailable")
    reviewer_rules = [rule for rule in rules if isinstance(rule, dict) and rule.get("type") == "required_reviewers"]
    _require(len(reviewer_rules) == 1, "registry-publication must have one required_reviewers rule")
    reviewer_rule = reviewer_rules[0]
    prevent_self_review = reviewer_rule.get("prevent_self_review")
    _require(type(prevent_self_review) is bool, "registry-publication prevent_self_review setting is invalid")
    if prevent_self_review:
        _require(reviewer_distinct, "registry-publication environment forbids self review")
    configured_reviewers = reviewer_rule.get("reviewers")
    _require(isinstance(configured_reviewers, list) and len(configured_reviewers) > 0, "registry-publication required reviewers are empty")
    reviewer_is_configured = any(
        isinstance(item, dict)
        and item.get("type") == "User"
        and isinstance(item.get("reviewer"), dict)
        and item["reviewer"].get("id") == user["id"]
        and str(item["reviewer"].get("login", "")).casefold() == login.casefold()
        for item in configured_reviewers
    )
    _require(reviewer_is_configured, "registry-publication approval user is not a configured required reviewer")
    return {
        "state": "approved",
        "reviewer": {
            "login": login,
            "id": user["id"],
            "node_id": user.get("node_id", ""),
            "type": "User",
        },
        "reviewer_distinct_from_triggering_actor": reviewer_distinct,
        "required_reviewers_configured": True,
        "prevent_self_review": prevent_self_review,
        "approval_history_source": "GET /repos/{owner}/{repo}/actions/runs/{run_id}/approvals",
        "comment_persisted": False,
    }


def _validate_workflow_source(path: Path) -> tuple[str, bytes]:
    _require(path.is_file(), "main-deploy workflow source is missing")
    raw = path.read_bytes()
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise VerificationError("main-deploy workflow is not UTF-8") from exc
    for marker in (
        "name: main-deploy",
        "name: registry-publication",
        "packages: write",
        "Build and push absent candidate tag once",
        "python scripts/verify_ghcr_candidate.py",
        "python scripts/verify_ghcr_remote_scan.py",
        "python scripts/collect_ghcr_publication_evidence.py",
    ):
        _require(marker in text, f"main-deploy workflow is missing protected publication marker: {marker}")
    return _sha256(raw), raw


def build_publication_evidence(
    manifest_path: Path,
    remote_scan_path: Path,
    run_path: Path,
    jobs_path: Path,
    approvals_path: Path,
    environment_path: Path,
    artifact_path: Path,
    capability_gates_path: Path,
    workflow_path: Path,
    expected_artifact_id: str,
    expected_artifact_digest: str,
) -> tuple[dict[str, Any], dict[str, Any]]:
    manifest_path = Path(manifest_path)
    remote_scan_path = Path(remote_scan_path)
    manifest, manifest_raw = _read_json(manifest_path, "GHCR manifest")
    release_id, candidate_sha, control_sha, namespace, matrix = _manifest_matrix(manifest)
    manifest_sha = _sha256(manifest_raw)
    remote, remote_raw = _read_json(remote_scan_path, "remote image scan")
    _validate_remote_scan(remote, remote_scan_path, manifest_sha, matrix)
    _require(remote.get("release_id") == release_id, "remote scan release id mismatch")
    _require(remote.get("source_commit_sha") == candidate_sha, "remote scan source SHA mismatch")
    _require(remote.get("control_commit_sha") == control_sha, "remote scan control SHA mismatch")
    remote_sha = _sha256(remote_raw)

    run, run_raw = _read_json(Path(run_path), "workflow run readback")
    run_id = str(run.get("id"))
    _require(RUN_ID_RE.fullmatch(run_id) is not None, "workflow run id is invalid")
    _require(run_id == str(manifest["workflow"]["run_id"]), "workflow run id does not match GHCR manifest")
    _require(run.get("run_attempt") == 1 and manifest["workflow"]["run_attempt"] == 1, "registry publication reruns are not credit eligible")
    _require(run.get("name") == "main-deploy", "workflow run name mismatch")
    _require(run.get("event") == "workflow_dispatch", "registry publication must be workflow_dispatch")
    _require(run.get("head_sha") == control_sha, "workflow run control SHA mismatch")
    _require(run.get("head_branch") == "chore/repo-bootstrap", "workflow run branch mismatch")
    _require(run.get("html_url") == manifest["workflow"]["run_url"], "workflow run URL mismatch")
    actor = run.get("actor")
    _require(isinstance(actor, dict) and isinstance(actor.get("login"), str), "workflow triggering actor is missing")
    triggering_actor = actor["login"]

    jobs, jobs_raw = _read_json(Path(jobs_path), "workflow jobs readback")
    _require_candidate_preflight(jobs, control_sha)
    inputs = run.get("inputs")
    if inputs is not None:
        _require(
            isinstance(inputs, dict) and inputs.get("candidate_sha") == candidate_sha,
            "workflow dispatch candidate input mismatch",
        )
    publish_jobs = _select_publish_jobs(jobs, control_sha)
    approvals, approvals_raw = _read_json(Path(approvals_path), "workflow approval history", array_allowed=True)
    environment, environment_raw = _read_json(Path(environment_path), "registry-publication environment")
    review = _select_review(approvals, environment, triggering_actor)

    artifact, artifact_raw = _read_json(Path(artifact_path), "Actions artifact readback")
    _require(RUN_ID_RE.fullmatch(str(expected_artifact_id)) is not None, "expected artifact id is invalid")
    _require(DIGEST_RE.fullmatch(expected_artifact_digest) is not None, "expected artifact digest is invalid")
    _require(str(artifact.get("id")) == str(expected_artifact_id), "Actions artifact id mismatch")
    _require(artifact.get("digest") == expected_artifact_digest, "Actions artifact digest mismatch")
    expected_name = f"ghcr-candidate-{candidate_sha}-{run_id}-1"
    _require(artifact.get("name") == expected_name, "Actions artifact name mismatch")
    _require(artifact.get("expired") is False, "Actions artifact is expired")
    _require(type(artifact.get("size_in_bytes")) is int and artifact["size_in_bytes"] > 0, "Actions artifact is empty")
    artifact_run = artifact.get("workflow_run")
    _require(isinstance(artifact_run, dict), "Actions artifact workflow binding is missing")
    _require(str(artifact_run.get("id")) == run_id and artifact_run.get("head_sha") == control_sha, "Actions artifact workflow binding mismatch")

    capability, capability_raw = _read_json(Path(capability_gates_path), "capability gate state")
    _require(capability.get("contract_version") == CAPABILITY_CONTRACT, "capability gate contract mismatch")
    gates = capability.get("gates")
    gate = gates.get("docker_registry_publish") if isinstance(gates, dict) else None
    _require(isinstance(gate, dict), "docker_registry_publish gate is missing")
    _require(gate.get("owner_granted") is True, "docker_registry_publish Owner grant is missing")
    owner_grant_ref = gate.get("owner_grant_ref")
    _require(isinstance(owner_grant_ref, str) and owner_grant_ref.strip(), "docker_registry_publish Owner grant reference is missing")
    _require(gate.get("paid_provider") is False, "docker_registry_publish must remain zero-card")
    _require(gate.get("live_verified") is False, "docker_registry_publish live_verified must remain verifier-owned before collection")

    workflow_sha, _ = _validate_workflow_source(Path(workflow_path))
    publication = {
        "contract_version": REVIEW_CONTRACT,
        "status": "verified",
        "collected_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
        "release_id": release_id,
        "source_commit_sha": candidate_sha,
        "control_commit_sha": control_sha,
        "repository": manifest["workflow"]["repository"],
        "workflow": {
            "name": "main-deploy",
            "event": "workflow_dispatch",
            "run_id": run_id,
            "run_attempt": 1,
            "run_url": manifest["workflow"]["run_url"],
            "ref": manifest["workflow"]["ref"],
            "head_sha": control_sha,
            "candidate_sha": candidate_sha,
            "triggering_actor": triggering_actor,
            "workflow_path": ".github/workflows/main-deploy.yml",
            "workflow_sha256": workflow_sha,
        },
        "environment": ENVIRONMENT_NAME,
        "environment_id": environment.get("id"),
        "environment_protection_verified": True,
        "review": review,
        "publish_job_count": 6,
        "publish_jobs": publish_jobs,
        "all_publish_jobs_successful": True,
        "all_publish_steps_executed": True,
        "approval_required_before_publish_jobs": True,
        "artifact": {
            "id": str(expected_artifact_id),
            "name": expected_name,
            "digest": expected_artifact_digest,
            "size_in_bytes": artifact["size_in_bytes"],
            "expired": False,
            "archive_download_url": artifact.get("archive_download_url"),
            "manifest_sha256": manifest_sha,
            "remote_scan_sha256": remote_sha,
        },
        "owner_grant": {
            "gate_id": "docker_registry_publish",
            "owner_granted": True,
            "owner_grant_ref": owner_grant_ref,
            "paid_provider": False,
            "capability_gate_contract": CAPABILITY_CONTRACT,
            "capability_gate_sha256": _sha256(capability_raw),
        },
        "api_readback_sha256": {
            "run": _sha256(run_raw),
            "jobs": _sha256(jobs_raw),
            "approvals": _sha256(approvals_raw),
            "environment": _sha256(environment_raw),
            "artifact": _sha256(artifact_raw),
        },
        "plan_only": False,
        "registry_publish_performed": True,
        "registry_publish_verified": True,
        "production_deploy": False,
        "release_promotion": False,
        "provider_writes": False,
        "secret_output": False,
    }
    publication_sha = _sha256(_json_bytes(publication))

    scan_map = {(scan["service"], scan["platform"]): scan for scan in remote["scans"]}
    images: list[dict[str, Any]] = []
    for image in manifest["images"]:
        service = image["service"]
        platforms: list[dict[str, Any]] = []
        service_report_hashes: list[str] = []
        for platform_entry in image["index_platforms"]:
            platform = platform_entry["platform"]
            scan = scan_map[(service, platform)]
            service_report_hashes.append(scan["report_sha256"])
            platforms.append(
                {
                    "platform": platform,
                    "digest": platform_entry["digest"],
                    "immutable_reference": platform_entry["digest_ref"],
                    "remote_scan": {
                        "verified": True,
                        "scanner": "trivy",
                        "scanner_version": TRIVY_VERSION,
                        "report_path": scan["report_path"],
                        "report_sha256": scan["report_sha256"],
                        "secret_findings": 0,
                        "high_vulnerabilities": 0,
                        "critical_vulnerabilities": 0,
                    },
                }
            )
        service_scan_binding = hashlib.sha256(("\n".join(service_report_hashes) + "\n").encode("utf-8")).hexdigest()
        top_digest = image["digest"]
        images.append(
            {
                "service": service,
                "digest": top_digest,
                "immutable_reference": f"{namespace}/{service}@{top_digest}",
                "oci_revision": candidate_sha,
                "oci_source": f"https://github.com/{manifest['workflow']['repository']}",
                "platform_digests": platforms,
                "attestation": {
                    "verified": True,
                    "type": "ghcr-manifest-readback",
                    "image_digest": top_digest,
                    "source_commit_sha": candidate_sha,
                    "statement_sha256": manifest_sha,
                },
                "remote_scan": {
                    "verified": True,
                    "image_digest": top_digest,
                    "scanner": "trivy",
                    "scanner_version": TRIVY_VERSION,
                    "platform_scan_count": 2,
                    "report_sha256": service_scan_binding,
                    "evidence_sha256": remote_sha,
                    "secret_findings": 0,
                    "high_vulnerabilities": 0,
                    "critical_vulnerabilities": 0,
                },
            }
        )

    registry = {
        "contract_version": REGISTRY_DIGEST_CONTRACT,
        "status": "verified",
        "release_id": release_id,
        "source_commit_sha": candidate_sha,
        "candidate_sha": candidate_sha,
        "control_commit_sha": control_sha,
        "registry": "ghcr.io",
        "namespace": namespace,
        "service_count": 6,
        "top_digest_count": 6,
        "platform_digest_count": 12,
        "images": images,
        "ghcr_manifest": {
            "contract_version": GHCR_MANIFEST_CONTRACT,
            "sha256": manifest_sha,
        },
        "remote_image_scan": {
            "contract_version": REMOTE_SCAN_CONTRACT,
            "sha256": remote_sha,
            "scan_count": 12,
            "scanner": "trivy",
            "scanner_version": TRIVY_VERSION,
            "secret_findings": 0,
            "high_vulnerabilities": 0,
            "critical_vulnerabilities": 0,
        },
        "publication_review": {
            "contract_version": REVIEW_CONTRACT,
            "sha256": publication_sha,
            "environment": ENVIRONMENT_NAME,
            "state": "approved",
            "run_id": run_id,
            "run_attempt": 1,
            "artifact_id": str(expected_artifact_id),
            "artifact_digest": expected_artifact_digest,
        },
        "owner_grant_ref": owner_grant_ref,
        "registry_publish_verified": True,
        "remote_scan_verified": True,
        "protected_publish_review_verified": True,
        "mutable_reference_used": False,
        "provider_writes": False,
        "production_deploy": False,
        "release_promotion": False,
        "secret_output": False,
    }
    return publication, registry


def _write_exclusive(path: Path, value: Mapping[str, Any]) -> None:
    _require(path.parent.is_dir(), f"output parent directory is missing: {path.parent}")
    try:
        with path.open("xb") as handle:
            handle.write(_json_bytes(value))
    except FileExistsError as exc:
        raise VerificationError(f"output already exists and cannot be overwritten: {path}") from exc


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--remote-scan", type=Path, required=True)
    parser.add_argument("--run", type=Path, required=True)
    parser.add_argument("--jobs", type=Path, required=True)
    parser.add_argument("--approvals", type=Path, required=True)
    parser.add_argument("--environment", type=Path, required=True)
    parser.add_argument("--artifact", type=Path, required=True)
    parser.add_argument("--capability-gates", type=Path, required=True)
    parser.add_argument("--workflow", type=Path, required=True)
    parser.add_argument("--expected-artifact-id", required=True)
    parser.add_argument("--expected-artifact-digest", required=True)
    parser.add_argument("--publication-output", type=Path, required=True)
    parser.add_argument("--registry-output", type=Path, required=True)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        publication, registry = build_publication_evidence(
            manifest_path=args.manifest,
            remote_scan_path=args.remote_scan,
            run_path=args.run,
            jobs_path=args.jobs,
            approvals_path=args.approvals,
            environment_path=args.environment,
            artifact_path=args.artifact,
            capability_gates_path=args.capability_gates,
            workflow_path=args.workflow,
            expected_artifact_id=args.expected_artifact_id,
            expected_artifact_digest=args.expected_artifact_digest,
        )
        _write_exclusive(args.publication_output, publication)
        _write_exclusive(args.registry_output, registry)
    except VerificationError as exc:
        print(f"[ghcr-publication-collector] ERROR: {exc}", file=sys.stderr)
        return 1
    print(
        "[ghcr-publication-collector] PASS review=approved environment=registry-publication "
        "publish_jobs=6 top_digests=6 platform_digests=12 secret_output=false"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Evidence-only scorer for the exact Layer-5 86 -> 100 registry slice."""

from __future__ import annotations

import json
import re
import sys
from pathlib import PurePosixPath
from typing import Any, Callable

try:
    from . import progress_credit_scorer_common as common
except ImportError:  # Direct execution from the repository root.
    import progress_credit_scorer_common as common


SCORER_COMMAND = "python scripts/score_layer5_registry_release_credit.py --score-v1"
AGGREGATE_CONTRACT = "layer5-registry-release-credit-evidence-v1"
REQUALIFICATION_CONTRACT = "layer5-registry-release-credit-requalification-v1"
GATE_PATH = "docs/runtime-state/capability-gates.json"
GATE_VERIFIER = "scripts/verify_layer5_registry_release_evidence.py"
ARTIFACT_CONTRACTS = {
    "ghcr_manifest": "ghcr-release-manifest-v1",
    "candidate_registry_digests": "candidate-registry-digests-v1",
    "remote_image_scan": "remote-image-scan-evidence-v1",
    "candidate_sbom": "mcp-candidate-sbom-evidence-v2",
    "registry_publication_review": "registry-publication-review-evidence-v1",
}
EXPECTED_SERVICES = {
    "agent-api",
    "mcp-gateway",
    "frontend",
    "llm-gateway",
    "agent-worker",
    "memory-worker",
}

ScoreError = common.ScoreError


def _validate_gate_binding(
    source_sha: str,
    artifact_path: str,
    artifact_sha256: str,
    *,
    load_blob: Callable[[str, str], bytes],
) -> None:
    capability = common.decode_json(load_blob(source_sha, GATE_PATH), "capability gates")
    common.require(capability.get("contract_version") == "capability-gate-state-v1", "capability gate contract mismatch")
    gate = capability.get("gates", {}).get("docker_registry_publish", {})
    common.require(gate.get("owner_granted") is True and gate.get("live_verified") is True, "registry gate is not promoted")
    common.require(gate.get("provider") == "ghcr" and gate.get("paid_provider") is False, "registry gate provider mismatch")
    common.require(isinstance(gate.get("owner_grant_ref"), str) and gate["owner_grant_ref"].strip(), "registry gate Owner reference missing")
    common.require(gate.get("verifier") == GATE_VERIFIER, "registry gate verifier mismatch")
    common.require(str(gate.get("evidence_artifact", "")).replace("\\", "/") == artifact_path, "registry gate evidence path mismatch")
    common.require(str(gate.get("evidence_sha256", "")).lower() == artifact_sha256, "registry gate evidence hash mismatch")


def _child_path(aggregate_path: str, value: Any, context: str) -> str:
    child = common.validate_repo_path(value, context)
    child_parts = PurePosixPath(child)
    common.require(len(child_parts.parts) == 1, f"{context} must be a sibling filename")
    return (PurePosixPath(aggregate_path).parent / child_parts).as_posix()


def _validate_manifest(value: dict[str, Any], release_id: str, candidate_sha: str, control_sha: str) -> None:
    common.require(value.get("contract_version") == ARTIFACT_CONTRACTS["ghcr_manifest"], "GHCR manifest contract mismatch")
    common.require(value.get("status") == "verified", "GHCR manifest is not verified")
    common.require(value.get("candidate_sha") == candidate_sha, "GHCR manifest candidate mismatch")
    common.require(value.get("control_sha") == control_sha, "GHCR manifest control mismatch")
    active = value.get("active_release_candidate")
    common.require(isinstance(active, dict), "GHCR active candidate binding missing")
    common.require(active.get("release_id") == release_id, "GHCR release binding mismatch")
    common.require(active.get("source_commit_sha") == candidate_sha, "GHCR active source mismatch")
    common.require(value.get("service_count") == 6, "GHCR service count mismatch")
    common.require(set(value.get("services", [])) == EXPECTED_SERVICES, "GHCR service set mismatch")
    common.require(value.get("unique_top_digest_count") == 6, "GHCR top digest count mismatch")
    common.require(value.get("publication_complete") is True, "GHCR publication is incomplete")
    common.require(value.get("inspection_read_only") is True, "GHCR digest readback was not read-only")
    common.require(value.get("registry_write_performed") is False, "GHCR manifest verifier performed a registry write")
    images = value.get("images")
    common.require(isinstance(images, list) and len(images) == 6, "GHCR image count mismatch")
    top: set[str] = set()
    platforms: set[str] = set()
    services: set[str] = set()
    for image in images:
        common.require(isinstance(image, dict), "GHCR image entry is invalid")
        service = image.get("service")
        common.require(service in EXPECTED_SERVICES and service not in services, "GHCR image service mismatch")
        services.add(str(service))
        digest = image.get("digest")
        common.require(isinstance(digest, str) and re.fullmatch(r"sha256:[0-9a-f]{64}", digest) is not None, "GHCR top digest is invalid")
        common.require(digest not in top, "GHCR top digest is duplicated")
        top.add(digest)
        children = image.get("index_platforms")
        common.require(isinstance(children, list) and len(children) == 2, "GHCR platform matrix mismatch")
        for child in children:
            common.require(isinstance(child, dict), "GHCR platform entry is invalid")
            platform = child.get("platform")
            common.require(platform in {"linux/amd64", "linux/arm64"}, "GHCR platform is invalid")
            key = f"{service}:{platform}"
            common.require(key not in platforms, "GHCR platform is duplicated")
            platforms.add(key)
            common.require(re.fullmatch(r"sha256:[0-9a-f]{64}", str(child.get("digest", ""))) is not None, "GHCR platform digest is invalid")
    common.require(len(platforms) == 12, "GHCR platform digest count mismatch")


def _validate_supporting_artifacts(
    artifacts: dict[str, dict[str, Any]],
    payloads: dict[str, dict[str, Any]],
    *,
    release_id: str,
    candidate_sha: str,
    control_sha: str,
) -> None:
    registry = payloads["candidate_registry_digests"]
    common.require(registry.get("status") == "verified", "registry digest evidence is not verified")
    common.require(registry.get("release_id") == release_id, "registry digest release mismatch")
    common.require(registry.get("source_commit_sha") == candidate_sha, "registry digest source mismatch")
    common.require(registry.get("control_commit_sha") == control_sha, "registry digest control mismatch")
    common.require(registry.get("service_count") == 6 and registry.get("top_digest_count") == 6, "registry digest count mismatch")
    common.require(registry.get("platform_digest_count") == 12, "registry platform count mismatch")
    common.require(registry.get("registry_publish_verified") is True, "registry publication is not verified")
    common.require(registry.get("remote_scan_verified") is True, "registry scan is not verified")
    common.require(registry.get("protected_publish_review_verified") is True, "registry protected review is not verified")
    common.require(registry.get("mutable_reference_used") is False, "registry evidence used a mutable reference")

    remote = payloads["remote_image_scan"]
    common.require(remote.get("status") == "verified" and remote.get("credit_eligible") is True, "remote image scan is not credit eligible")
    common.require(remote.get("release_id") == release_id and remote.get("source_commit_sha") == candidate_sha, "remote image scan source mismatch")
    common.require(remote.get("control_commit_sha") == control_sha, "remote image scan control mismatch")
    common.require(remote.get("scan_count") == 12, "remote image scan count mismatch")
    for key in ("secret_findings", "high_vulnerabilities", "critical_vulnerabilities"):
        common.require(remote.get(key) == 0, f"remote image scan {key} must be zero")
    common.require(remote.get("registry_write_performed") is False and remote.get("secret_output") is False, "remote image scan crossed its read-only boundary")

    sbom = payloads["candidate_sbom"]
    common.require(sbom.get("status") == "verified" and sbom.get("credit_eligible") is True, "candidate SBOM is not verified")
    common.require(sbom.get("release_id") == release_id and sbom.get("source_commit_sha") == candidate_sha, "candidate SBOM source mismatch")
    common.require(sbom.get("service_count") == 6 and sbom.get("sbom_count") == 6, "candidate SBOM count mismatch")
    common.require(sbom.get("immutable_registry_digests_bound") is True, "candidate SBOM is not digest bound")
    common.require(sbom.get("secret_output") is False, "candidate SBOM exposed a secret")

    review = payloads["registry_publication_review"]
    common.require(review.get("status") == "verified", "registry publication review is not verified")
    common.require(review.get("release_id") == release_id and review.get("source_commit_sha") == candidate_sha, "registry review source mismatch")
    common.require(review.get("control_commit_sha") == control_sha, "registry review control mismatch")
    common.require(review.get("environment") == "registry-publication", "registry review environment mismatch")
    common.require(review.get("publish_job_count") == 6 and review.get("all_publish_jobs_successful") is True, "registry publish jobs are incomplete")
    common.require(review.get("all_publish_steps_executed") is True, "registry publish steps were skipped")
    common.require(review.get("approval_required_before_publish_jobs") is True, "registry environment review ordering mismatch")
    workflow = review.get("workflow")
    common.require(isinstance(workflow, dict) and workflow.get("event") == "workflow_dispatch" and workflow.get("run_attempt") == 1, "registry workflow provenance mismatch")
    approval = review.get("review")
    common.require(isinstance(approval, dict) and approval.get("state") == "approved", "registry review state mismatch")
    common.require(approval.get("reviewer_distinct_from_triggering_actor") is True, "registry reviewer separation mismatch")
    reviewer = approval.get("reviewer")
    common.require(isinstance(reviewer, dict) and reviewer.get("type") == "User", "registry reviewer identity missing")
    login = reviewer.get("login")
    actor = workflow.get("triggering_actor")
    common.require(isinstance(login, str) and bool(login.strip()), "registry reviewer login missing")
    common.require(isinstance(actor, str) and bool(actor.strip()), "registry triggering actor missing")
    common.require(login.casefold() != actor.casefold(), "registry reviewer separation contradicts recorded identities")
    for key in ("production_deploy", "release_promotion", "provider_writes", "secret_output"):
        common.require(review.get(key) is False, f"registry review {key} must be false")

    common.require(registry.get("ghcr_manifest", {}).get("sha256") == artifacts["ghcr_manifest"]["sha256"], "registry-to-manifest hash mismatch")
    common.require(registry.get("remote_image_scan", {}).get("sha256") == artifacts["remote_image_scan"]["sha256"], "registry-to-scan hash mismatch")
    common.require(registry.get("publication_review", {}).get("sha256") == artifacts["registry_publication_review"]["sha256"], "registry-to-review hash mismatch")


def score_request(
    request: dict[str, Any],
    *,
    load_blob: Callable[[str, str], bytes] = common.git_blob,
    is_ancestor: Callable[[str, str], bool] = common.git_is_ancestor,
) -> dict[str, Any]:
    request_source, request_artifact_path, request_artifact = common.validate_request_artifact(
        request,
        scorer_command=SCORER_COMMAND,
        scope="vertical",
        cell_id="layer_5",
        old_percent=86,
        new_percent=100,
        load_blob=load_blob,
    )
    evidence_source = request_source
    artifact_path = request_artifact_path
    artifact_sha256 = request["artifact_sha256"]
    aggregate = request_artifact
    if request_artifact.get("contract_version") == REQUALIFICATION_CONTRACT:
        common.require(
            re.fullmatch(
                r"docs/release-artifacts/[^/]+-evidence/registry/layer5-registry-release-credit-requalification\.json",
                request_artifact_path,
            )
            is not None,
            "unexpected L5 registry requalification path",
        )
        common.require_exact_keys(
            request_artifact,
            {
                "contract_version",
                "status",
                "scope",
                "cell_id",
                "old_percent",
                "new_percent",
                "points_awarded",
                "credit_eligible",
                "current_candidate",
                "historical_evidence",
                "requalification_read_only",
                "registry_write_performed",
                "production_deploy",
                "release_promotion",
                "provider_writes",
                "secret_output",
            },
            "L5 registry requalification",
        )
        common.require(request_artifact.get("status") == "verified", "L5 registry requalification is not verified")
        common.require(request_artifact.get("scope") == "vertical" and request_artifact.get("cell_id") == "layer_5", "L5 registry requalification cell mismatch")
        common.require((request_artifact.get("old_percent"), request_artifact.get("new_percent"), request_artifact.get("points_awarded")) == (86, 100, 14), "L5 registry requalification transition mismatch")
        common.require(request_artifact.get("credit_eligible") is True and request_artifact.get("requalification_read_only") is True, "L5 registry requalification is not credit eligible")
        for key in ("registry_write_performed", "production_deploy", "release_promotion", "provider_writes", "secret_output"):
            common.require(request_artifact.get(key) is False, f"L5 registry requalification {key} must be false")

        current_candidate = common.require_exact_keys(
            request_artifact.get("current_candidate"),
            {"release_id", "source_commit_sha"},
            "L5 registry requalification current candidate",
        )
        common.validate_candidate_pointer(
            evidence_source_sha=request_source,
            candidate_source_sha=current_candidate["source_commit_sha"],
            release_id=current_candidate["release_id"],
            load_blob=load_blob,
            is_ancestor=is_ancestor,
        )
        historical = common.require_exact_keys(
            request_artifact.get("historical_evidence"),
            {"contract_version", "source_sha", "path", "sha256"},
            "L5 registry historical evidence",
        )
        common.require(historical["contract_version"] == AGGREGATE_CONTRACT, "L5 registry historical contract mismatch")
        historical_source = common.require_lower_hex(historical["source_sha"], 40, "L5 registry historical source SHA")
        common.require(historical_source != request_source and is_ancestor(historical_source, request_source), "L5 registry historical evidence is not a strict requalification ancestor")
        historical_path = common.validate_repo_path(historical["path"], "L5 registry historical evidence path")
        historical_sha256 = common.require_lower_hex(historical["sha256"], 64, "L5 registry historical evidence SHA-256")
        historical_payload, _ = common.load_hashed_json(
            historical_source,
            historical_path,
            historical_sha256,
            context="L5 registry historical evidence",
            load_blob=load_blob,
        )
        _validate_gate_binding(
            request_source,
            historical_path,
            historical_sha256,
            load_blob=load_blob,
        )
        evidence_source = historical_source
        artifact_path = historical_path
        artifact_sha256 = historical_sha256
        aggregate = historical_payload

    common.require(re.fullmatch(r"docs/release-artifacts/[^/]+-evidence/registry/layer5-registry-release-credit-evidence\.json", artifact_path) is not None, "unexpected L5 registry aggregate path")
    common.require(aggregate.get("contract_version") == AGGREGATE_CONTRACT, "L5 registry aggregate contract mismatch")
    common.require(aggregate.get("status") == "verified" and aggregate.get("credit_eligible") is True, "L5 registry aggregate is not verified")
    common.require(aggregate.get("scope") == "vertical" and aggregate.get("cell_id") == "layer_5", "L5 registry aggregate cell mismatch")
    common.require((aggregate.get("old_percent"), aggregate.get("new_percent"), aggregate.get("points_awarded")) == (86, 100, 14), "L5 registry credit transition mismatch")
    for key, expected in (("registry_publish_performed", True), ("production_deploy", False), ("release_promotion", False), ("provider_writes", False), ("secret_output", False)):
        common.require(aggregate.get(key) is expected, f"L5 registry aggregate {key} mismatch")

    release_id, candidate_sha = common.validate_candidate_pointer(
        evidence_source_sha=evidence_source,
        candidate_source_sha=aggregate.get("source_commit_sha"),
        release_id=aggregate.get("release_id"),
        load_blob=load_blob,
        is_ancestor=is_ancestor,
    )
    control_sha = common.require_lower_hex(aggregate.get("control_commit_sha"), 40, "L5 registry control SHA")
    common.require(is_ancestor(candidate_sha, control_sha), "L5 registry control is not a candidate descendant")
    common.require(is_ancestor(control_sha, evidence_source), "L5 registry evidence does not descend from its control")

    refs = common.require_exact_keys(aggregate.get("artifacts"), set(ARTIFACT_CONTRACTS), "L5 registry artifacts")
    payloads: dict[str, dict[str, Any]] = {}
    for name, contract in ARTIFACT_CONTRACTS.items():
        ref = common.require_exact_keys(refs[name], {"contract_version", "path", "sha256"}, f"L5 {name} reference")
        common.require(ref["contract_version"] == contract, f"L5 {name} contract binding mismatch")
        child_path = _child_path(artifact_path, ref["path"], f"L5 {name} path")
        payload, _ = common.load_hashed_json(evidence_source, child_path, ref["sha256"], context=f"L5 {name}", load_blob=load_blob)
        common.require(payload.get("contract_version") == contract, f"L5 {name} contract mismatch")
        payloads[name] = payload
    _validate_manifest(payloads["ghcr_manifest"], release_id, candidate_sha, control_sha)
    _validate_supporting_artifacts(refs, payloads, release_id=release_id, candidate_sha=candidate_sha, control_sha=control_sha)

    criteria = aggregate.get("criteria")
    expected_criteria = {
        "immutable_registry_digests": (3, refs["ghcr_manifest"]["sha256"]),
        "candidate_sbom": (3, refs["candidate_sbom"]["sha256"]),
        "remote_image_scan": (2, refs["remote_image_scan"]["sha256"]),
        "protected_publish": (6, refs["registry_publication_review"]["sha256"]),
    }
    common.require(isinstance(criteria, list) and len(criteria) == 4, "L5 registry criterion count mismatch")
    seen: set[str] = set()
    for criterion in criteria:
        common.require(isinstance(criterion, dict), "L5 registry criterion is invalid")
        criterion_id = criterion.get("id")
        common.require(criterion_id in expected_criteria and criterion_id not in seen, "L5 registry criterion set mismatch")
        seen.add(str(criterion_id))
        points, digest = expected_criteria[str(criterion_id)]
        common.require(criterion == {"id": criterion_id, "points": points, "status": "verified", "evidence_sha256": digest}, f"L5 registry criterion {criterion_id} mismatch")
    common.require(seen == set(expected_criteria), "L5 registry criterion set incomplete")

    _validate_gate_binding(
        evidence_source,
        artifact_path,
        artifact_sha256,
        load_blob=load_blob,
    )
    return common.scorer_result(request)


def main(argv: list[str]) -> int:
    if argv != ["--score-v1"]:
        print("[layer5-registry-release-scorer] unsupported invocation", file=sys.stderr)
        return 2
    try:
        request = json.load(sys.stdin)
        result = score_request(request)
    except (ScoreError, json.JSONDecodeError, UnicodeError, OSError) as exc:
        print(f"[layer5-registry-release-scorer] rejected: {exc}", file=sys.stderr)
        return 2
    json.dump(result, sys.stdout, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

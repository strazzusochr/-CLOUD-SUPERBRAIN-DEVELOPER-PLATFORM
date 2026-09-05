#!/usr/bin/env python3
"""Evidence-only scorer for the exact Phase-6 90 -> 100 scale slice."""

from __future__ import annotations

import hashlib
import json
import re
import sys
from datetime import datetime, timezone
from typing import Any, Callable

try:
    from . import progress_credit_scorer_common as common
except ImportError:  # Direct execution from the repository root.
    import progress_credit_scorer_common as common


SCORER_COMMAND = "python scripts/score_phase6_scale_credit.py --score-v1"
EVIDENCE_CONTRACT = "phase6-scale-evidence-v2"
READBACK_CONTRACT = "github-actions-phase6-scale-execution-readback-v1"
CAPABILITY_PATH = "docs/runtime-state/capability-gates.json"
PHASE6_VERIFIER_PATH = "scripts/verify-phase6-scale-evidence.ps1"

ScoreError = common.ScoreError
BINDING_KEYS = common.BINDING_KEYS


def _normalized_path(value: Any) -> str:
    common.require(isinstance(value, str), "phase6 gate evidence path missing")
    return common.validate_repo_path(value.replace("\\", "/"), "phase6 gate evidence path")


def _validate_scale_payload(evidence: dict[str, Any]) -> str:
    common.require(evidence.get("contract_version") == EVIDENCE_CONTRACT, "Phase6 evidence contract mismatch")
    common.require(evidence.get("result") == "provisional_pending_github_readback", "Phase6 raw result status mismatch")
    request_budget = evidence.get("request_budget")
    common.require(isinstance(request_budget, dict), "Phase6 request budget is missing")
    expected_budget = {
        "worker_cap": 900,
        "worker_requests_issued": 900,
        "read_requests_issued": 800,
        "create_requests_issued": 50,
        "cleanup_delete_requests_issued": 50,
        "control_edge_requests_issued": 244,
    }
    for key, value in expected_budget.items():
        common.require(request_budget.get(key) == value, f"Phase6 request budget {key} mismatch")
    common.require(request_budget.get("cap_respected") is True, "Phase6 Worker cap was not respected")
    common.require(request_budget.get("exact_plan_executed") is True, "Phase6 exact request plan was not executed")

    read_tiers = evidence.get("read_tiers")
    common.require(isinstance(read_tiers, list) and len(read_tiers) == 3, "Phase6 read tier matrix mismatch")
    read_valid = 0
    read_429 = 0
    expected_tiers = ((1, 60), (10, 240), (50, 500))
    for index, (tier, expected) in enumerate(zip(read_tiers, expected_tiers)):
        common.require(isinstance(tier, dict), f"Phase6 read tier {index} is invalid")
        concurrency, requests = expected
        common.require(tier.get("concurrency") == concurrency and tier.get("requests") == requests, f"Phase6 read tier {index} plan mismatch")
        outcome_keys = ("valid_health_200", "invalid_health_200", "throttled_429", "server_5xx", "transport_fail", "other_status")
        for key in outcome_keys:
            common.require(type(tier.get(key)) is int and tier[key] >= 0, f"Phase6 read tier {index} {key} is invalid")
        common.require(sum(tier[key] for key in outcome_keys) == requests, f"Phase6 read tier {index} accounting mismatch")
        common.require(tier.get("server_5xx") == 0 and tier.get("transport_fail") == 0, f"Phase6 read tier {index} has 5xx or transport failures")
        p95 = tier.get("p95_ms")
        common.require(type(p95) in {int, float} and 0 <= float(p95) <= 1500, f"Phase6 read tier {index} p95 exceeds threshold")
        read_valid += int(tier["valid_health_200"])
        read_429 += int(tier["throttled_429"])

    health_validation = evidence.get("health_validation")
    common.require(isinstance(health_validation, dict), "Phase6 health validation is missing")
    common.require(health_validation.get("valid_json_count") == read_valid, "Phase6 health validation count mismatch")
    common.require(health_validation.get("invalid_json_or_contract_count") == 0, "Phase6 health validation contains invalid responses")
    common.require(health_validation.get("validation_failures") == [], "Phase6 health validation has failures")

    write_tier = evidence.get("write_tier")
    common.require(isinstance(write_tier, dict), "Phase6 write tier is missing")
    common.require(write_tier.get("records_planned") == 50, "Phase6 write count mismatch")
    common.require(write_tier.get("valid_post_insert_readbacks") == 50, "Phase6 write readback count mismatch")
    common.require(write_tier.get("concurrency") == 10, "Phase6 write concurrency mismatch")
    for key in (
        "record_loss_count",
        "duplicate_count",
        "duplicate_request_id_count",
        "duplicate_audit_event_id_count",
        "field_failure_count",
        "hash_failure_count",
        "audit_failure_count",
        "throttled_429",
        "server_5xx",
        "transport_fail",
    ):
        common.require(write_tier.get(key) == 0, f"Phase6 write tier {key} must be zero")

    cleanup = evidence.get("cleanup")
    common.require(isinstance(cleanup, dict), "Phase6 cleanup evidence is missing")
    common.require(
        cleanup.get("verified_count") == 50
        and cleanup.get("literal_success_count") == 50
        and cleanup.get("required_count") == 50
        and cleanup.get("complete") is True,
        "Phase6 cleanup is incomplete",
    )
    for key in ("throttled_429", "unclean_throttle_count", "server_5xx", "transport_fail"):
        common.require(cleanup.get(key) == 0, f"Phase6 cleanup {key} must be zero")

    aggregate = evidence.get("aggregate")
    common.require(isinstance(aggregate, dict), "Phase6 aggregate is missing")
    common.require(aggregate.get("criterion_met") is True, "Phase6 criterion was not met")
    common.require(aggregate.get("failures") == [], "Phase6 aggregate has failures")
    common.require(aggregate.get("server_5xx_total") == 0, "Phase6 aggregate has server 5xx failures")
    common.require(aggregate.get("transport_fail_total") == 0, "Phase6 aggregate has transport failures")
    common.require(aggregate.get("http_429_counted_as_success") is False, "Phase6 counted throttling as success")
    literal_success = aggregate.get("literal_success_count")
    success_ratio = aggregate.get("success_ratio")
    worst_p95 = aggregate.get("worst_p95_ms")
    common.require(type(literal_success) is int and 891 <= literal_success <= 900, "Phase6 literal success threshold mismatch")
    common.require(type(success_ratio) in {int, float} and 0.99 <= float(success_ratio) <= 1.0, "Phase6 success ratio threshold mismatch")
    common.require(abs(float(success_ratio) - round(literal_success / 900, 4)) <= 0.00005, "Phase6 success ratio accounting mismatch")
    common.require(type(worst_p95) in {int, float} and 0 <= float(worst_p95) <= 1500, "Phase6 aggregate p95 exceeds threshold")
    common.require(aggregate.get("throttled_429_total") == read_429, "Phase6 throttling accounting mismatch")
    common.require(literal_success == read_valid + 50 + 50, "Phase6 literal success accounting mismatch")
    common.require(evidence.get("gate_may_open") is False, "Phase6 raw evidence self-opened a gate")
    common.require(evidence.get("gate_promotion_performed") is False, "Phase6 raw evidence performed promotion")
    common.require(evidence.get("percentage_credit_awarded") == 0, "Phase6 raw evidence self-awarded credit")
    auth = evidence.get("auth")
    common.require(isinstance(auth, dict) and auth.get("value_recorded") is False, "Phase6 evidence recorded an auth value")
    common.require(auth.get("environment_variable_name") == "AGENT_API_AUTH_TOKEN", "Phase6 auth variable mismatch")

    binding = evidence.get("source_binding")
    common.require(isinstance(binding, dict), "Phase6 source binding is missing")
    candidate_sha = common.require_lower_hex(binding.get("source_commit_sha"), 40, "Phase6 candidate source SHA")
    common.require(binding.get("owner_granted") is True, "Phase6 Owner grant is not bound")
    common.require(isinstance(binding.get("owner_grant_ref"), str) and binding["owner_grant_ref"].strip(), "Phase6 Owner grant ref missing")
    common.require(binding.get("health_json_source_binding_verified") is True, "Phase6 health source binding failed")
    common.require(binding.get("preview_guard_verified") is True, "Phase6 Preview guard is not verified")
    execution = binding.get("execution_attestation")
    common.require(isinstance(execution, dict), "Phase6 execution attestation is missing")
    common.require(execution.get("github_actions") is True, "Phase6 execution is not GitHub Actions attested")
    common.require(execution.get("event_name") == "workflow_dispatch", "Phase6 execution was not explicitly dispatched")
    common.require(execution.get("run_attempt") == 1, "Phase6 execution must be the first run attempt")
    common.require(execution.get("post_run_api_readback_required") is True, "Phase6 execution did not require API readback")
    common.require(execution.get("verified") is False, "Phase6 raw execution binding must remain provisional")
    common.require(execution.get("source_commit_sha") == candidate_sha, "Phase6 execution source mismatch")
    common.require(type(execution.get("run_id")) is int and execution["run_id"] > 0, "Phase6 execution run id is invalid")
    common.require(isinstance(execution.get("artifact_name"), str) and execution["artifact_name"], "Phase6 execution artifact name missing")
    generated_at = evidence.get("generated_at_utc")
    common.require_iso_utc(generated_at, "Phase6 evidence generated_at_utc")
    return candidate_sha


def _parse_utc(value: Any, context: str) -> datetime:
    text = common.require_iso_utc(value, context)
    parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
    common.require(parsed.tzinfo is not None, f"{context} lacks timezone")
    return parsed.astimezone(timezone.utc)


def _load_execution_readback(
    evidence_source: str,
    artifact_path: str,
    artifact_sha256: str,
    *,
    load_blob: Callable[[str, str], bytes],
) -> dict[str, Any]:
    readback_path = f"{artifact_path}.execution-readback.json"
    sidecar_path = f"{readback_path}.sha256"
    sidecar = load_blob(evidence_source, sidecar_path).decode("utf-8")
    match = re.fullmatch(r"([0-9a-f]{64})  ([^\\/\r\n]+)\r?\n?", sidecar)
    common.require(match is not None, "Phase6 execution-readback sidecar is invalid")
    common.require(match.group(2) == readback_path.rsplit("/", 1)[-1], "Phase6 execution-readback sidecar filename mismatch")
    readback_blob = load_blob(evidence_source, readback_path)
    common.require(hashlib.sha256(readback_blob).hexdigest() == match.group(1), "Phase6 execution-readback hash mismatch")
    readback = common.decode_json(readback_blob, "Phase6 execution readback")
    common.require(readback.get("contract_version") == READBACK_CONTRACT, "Phase6 execution-readback contract mismatch")
    common.require(readback.get("secret_output") is False, "Phase6 execution readback exposed a secret")
    run = readback.get("run")
    common.require(isinstance(run, dict), "Phase6 execution run readback is missing")
    common.require(run.get("run_attempt") == 1, "Phase6 readback run attempt mismatch")
    common.require(run.get("event") == "workflow_dispatch", "Phase6 readback event mismatch")
    common.require(run.get("status") == "completed" and run.get("conclusion") == "success", "Phase6 run did not succeed")
    artifact = readback.get("artifact")
    common.require(isinstance(artifact, dict) and artifact.get("expired") is False, "Phase6 GitHub artifact is unavailable")
    common.require(
        isinstance(artifact.get("digest"), str) and re.fullmatch(r"sha256:[0-9a-f]{64}", artifact["digest"]) is not None,
        "Phase6 GitHub artifact digest is invalid",
    )
    common.require(
        str(readback.get("downloaded_evidence_sha256", "")).lower() == artifact_sha256,
        "Phase6 downloaded evidence hash mismatch",
    )
    common.require_iso_utc(readback.get("collected_at_utc"), "Phase6 readback collected_at_utc")
    return readback


def score_request(
    request: dict[str, Any],
    *,
    load_blob: Callable[[str, str], bytes] = common.git_blob,
    is_ancestor: Callable[[str, str], bool] = common.git_is_ancestor,
) -> dict[str, Any]:
    evidence_source, artifact_path, evidence = common.validate_request_artifact(
        request,
        scorer_command=SCORER_COMMAND,
        scope="horizontal",
        cell_id="phase_6",
        old_percent=90,
        new_percent=100,
        load_blob=load_blob,
    )
    candidate_sha = _validate_scale_payload(evidence)
    readback = _load_execution_readback(
        evidence_source,
        artifact_path,
        request["artifact_sha256"],
        load_blob=load_blob,
    )
    execution = evidence["source_binding"]["execution_attestation"]
    run = readback["run"]
    artifact = readback["artifact"]
    common.require(run.get("id") == execution.get("run_id"), "Phase6 execution/readback run id mismatch")
    common.require(run.get("head_sha") == execution.get("head_sha"), "Phase6 execution/readback head SHA mismatch")
    common.require(artifact.get("name") == execution.get("artifact_name"), "Phase6 execution/readback artifact name mismatch")
    workflow_run = artifact.get("workflow_run")
    common.require(isinstance(workflow_run, dict), "Phase6 artifact workflow-run binding missing")
    common.require(workflow_run.get("id") == execution.get("run_id") and workflow_run.get("head_sha") == execution.get("head_sha"), "Phase6 artifact workflow-run binding mismatch")
    generated_at = _parse_utc(evidence.get("generated_at_utc"), "Phase6 evidence generated_at_utc")
    collected_at = _parse_utc(readback.get("collected_at_utc"), "Phase6 readback collected_at_utc")
    common.require(collected_at >= generated_at, "Phase6 readback predates evidence")
    common.require((collected_at - generated_at).total_seconds() <= 86400, "Phase6 readback exceeded the 24-hour window")

    pointer = common.decode_json(load_blob(evidence_source, common.CURRENT_CANDIDATE_PATH), "current candidate")
    common.validate_candidate_pointer(
        evidence_source_sha=evidence_source,
        candidate_source_sha=candidate_sha,
        release_id=pointer.get("active_release_id"),
        load_blob=load_blob,
        is_ancestor=is_ancestor,
    )
    capability = common.decode_json(load_blob(evidence_source, CAPABILITY_PATH), "capability gates")
    common.require(capability.get("contract_version") == "capability-gate-state-v1", "capability gate contract mismatch")
    gate = capability.get("gates", {}).get("phase6_scale_runtime", {})
    common.require(gate.get("owner_granted") is True and gate.get("live_verified") is True, "Phase6 gate is not promoted")
    common.require(gate.get("paid_provider") is False, "Phase6 gate is not free-only")
    common.require(gate.get("provider") == "cloudflare-workers-d1-zero-card", "Phase6 gate provider mismatch")
    common.require(gate.get("verifier") == PHASE6_VERIFIER_PATH, "Phase6 gate verifier mismatch")
    common.require(_normalized_path(gate.get("evidence_artifact")) == artifact_path, "Phase6 gate artifact path mismatch")
    common.require(str(gate.get("evidence_sha256", "")).lower() == request["artifact_sha256"], "Phase6 gate artifact hash mismatch")
    return common.scorer_result(request)


def main(argv: list[str]) -> int:
    if argv != ["--score-v1"]:
        print("[phase6-scale-scorer] unsupported invocation", file=sys.stderr)
        return 2
    try:
        request = json.load(sys.stdin)
        result = score_request(request)
    except (ScoreError, json.JSONDecodeError, UnicodeError, OSError) as exc:
        print(f"[phase6-scale-scorer] rejected: {exc}", file=sys.stderr)
        return 2
    json.dump(result, sys.stdout, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

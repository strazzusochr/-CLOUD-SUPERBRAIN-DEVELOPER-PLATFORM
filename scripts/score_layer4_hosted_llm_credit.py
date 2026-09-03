#!/usr/bin/env python3
"""Evidence-only scorer for the exact Layer-4 55 -> 100 hosted-LLM slice."""

from __future__ import annotations

import json
import re
import sys
from typing import Any, Callable

try:
    from . import progress_credit_scorer_common as common
    from . import validate_layer4_hosted_llm_current_evidence as deep_validator
except ImportError:  # Direct execution from the repository root.
    import progress_credit_scorer_common as common
    import validate_layer4_hosted_llm_current_evidence as deep_validator


SCORER_COMMAND = "python scripts/score_layer4_hosted_llm_credit.py --score-v1"
AGGREGATE_CONTRACT = "layer4-hosted-llm-current-evidence-v1"
AGGREGATE_EVIDENCE_REF = "current_hosted_llm_seven_criteria_credit_bound"
AGGREGATE_FILENAME = "layer4-hosted-llm-current-evidence.json"
FORBIDDEN_LEGACY_CONTRACT = "live-llm-bounded-evidence-chain-v1"

AGGREGATE_KEYS = {
    "contract_version",
    "status",
    "evidence_ref",
    "checked_at",
    "scope",
    "cell_id",
    "release_id",
    "source",
    "rubric_approval_commit",
    "authority",
    "gates",
    "baseline_percent",
    "credited_percent",
    "credit_points_total",
    "historical_credit",
    "criteria",
    "provider_calls_total_observed",
    "live_provider_calls_verified",
    "hosted_audit_write_verified",
    "direct_provider_calls",
    "provider_writes",
    "production_deploy",
    "release_promotion",
    "secret_output",
    "non_claims",
}
SOURCE_KEYS = {
    "commit_sha",
    "archive_sha256",
    "gateway_tree_sha",
    "runtime_blob",
    "wrangler_blob",
    "rubric_blob",
    "capability_blob",
}
AUTHORITY_KEYS = {"owner_grant_ref_sha256", "gate_evidence_path", "gate_evidence_blob"}
GATE_KEYS = {"live_llm_owner_granted", "live_llm_live_verified", "paid_provider"}
HISTORICAL_KEYS = {
    "included_in_baseline_points",
    "excluded_from_delta",
    "forbidden_report_contracts",
    "legacy_progress_credit_recommended",
}
CRITERION_KEYS = {
    "criterion_id",
    "points",
    "report_path",
    "report_sha256",
    "report_contract",
    "evidence_ref",
    "claim_ids",
}
CRITERIA: dict[str, dict[str, Any]] = {
    "hosted_generative_source_bound": {
        "points": 10,
        "contract": "llm-hosted-current-evidence-chain-v2",
        "evidence_ref": "current_hosted_llm_generative_verified",
        "claim_ids": ["hosted_generative_source_bound"],
    },
    "hosted_stream_semantic_parity": {
        "points": 10,
        "contract": "llm-hosted-stream-parity-evidence-v2",
        "evidence_ref": "current_hosted_llm_stream_parity_verified",
        "claim_ids": ["hosted_stream_semantic_parity"],
    },
    "hosted_routing_and_completion_audit": {
        "points": 8,
        "contract": "llm-hosted-current-evidence-chain-v2",
        "evidence_ref": "current_hosted_llm_routing_completion_audit_verified",
        "claim_ids": ["hosted_routing_allowlist", "hosted_completion_audit"],
    },
    "hosted_fallback_bounded_audited": {
        "points": 3,
        "contract": "llm-hosted-fallback-evidence-v2",
        "evidence_ref": "current_hosted_llm_fallback_verified",
        "claim_ids": ["hosted_fallback_bounded_audited"],
    },
    "hosted_budget_guard_pre_provider": {
        "points": 3,
        "contract": "llm-hosted-budget-guard-evidence-v2",
        "evidence_ref": "current_hosted_llm_budget_guard_verified",
        "claim_ids": ["hosted_budget_guard_pre_provider"],
    },
    "hosted_trace_correlation": {
        "points": 4,
        "contract": "llm-hosted-trace-correlation-evidence-v2",
        "evidence_ref": "current_hosted_llm_trace_correlation_verified",
        "claim_ids": ["hosted_trace_correlation"],
    },
    "hosted_negative_guards_pre_provider": {
        "points": 7,
        "contract": "llm-hosted-negative-guards-evidence-v2",
        "evidence_ref": "current_hosted_llm_negative_guards_verified",
        "claim_ids": ["hosted_auth_guard", "hosted_oversize_guard", "hosted_schema_policy_guard"],
    },
}

ScoreError = common.ScoreError
BINDING_KEYS = common.BINDING_KEYS


def _report_source(report: dict[str, Any]) -> Any:
    if "source_commit_sha" in report:
        return report["source_commit_sha"]
    source = report.get("source")
    if isinstance(source, dict):
        return source.get("commit_sha", source.get("source_commit_sha"))
    source_binding = report.get("source_binding")
    if isinstance(source_binding, dict):
        return source_binding.get("source_commit_sha", source_binding.get("commit_sha"))
    return None


def _validate_report(report: dict[str, Any], spec: dict[str, Any], candidate_sha: str, context: str) -> None:
    common.require(report.get("contract_version") == spec["contract"], f"{context} contract mismatch")
    if "evidence_ref" in report:
        common.require(
            report["evidence_ref"] in {spec["evidence_ref"], "current_hosted_llm_generative_routing_audit_verified"},
            f"{context} evidence ref mismatch",
        )
    common.require(report.get("status") in {"verified", "passed"}, f"{context} is not verified")
    common.require(_report_source(report) == candidate_sha, f"{context} source mismatch")
    for key in ("secret_output", "provider_writes", "production_deploy", "release_promotion"):
        if key in report:
            common.require(report[key] is False, f"{context} {key} must be false")
    if "credit_eligible" in report:
        common.require(report["credit_eligible"] is True, f"{context} is not credit eligible")


def score_request(
    request: dict[str, Any],
    *,
    load_blob: Callable[[str, str], bytes] = common.git_blob,
    is_ancestor: Callable[[str, str], bool] = common.git_is_ancestor,
) -> dict[str, Any]:
    evidence_source, artifact_path, aggregate = common.validate_request_artifact(
        request,
        scorer_command=SCORER_COMMAND,
        scope="vertical",
        cell_id="layer_4",
        old_percent=55,
        new_percent=100,
        load_blob=load_blob,
    )
    common.require(
        re.fullmatch(
            r"docs/release-artifacts/[^/]+-evidence/hosted-layer/"
            + re.escape(AGGREGATE_FILENAME),
            artifact_path,
        )
        is not None,
        "unexpected L4 aggregate artifact path",
    )
    try:
        deep_validator.validate_aggregate(
            aggregate,
            lambda path: load_blob(evidence_source, path),
        )
    except deep_validator.EvidenceError as exc:
        raise common.ScoreError(f"L4 deep evidence validation failed: {exc}") from exc
    common.require_exact_keys(aggregate, AGGREGATE_KEYS, "L4 aggregate")
    common.require(aggregate["contract_version"] == AGGREGATE_CONTRACT, "L4 aggregate contract mismatch")
    common.require(aggregate["status"] == "verified", "L4 aggregate is not verified")
    common.require(aggregate["evidence_ref"] == AGGREGATE_EVIDENCE_REF, "L4 aggregate evidence ref mismatch")
    common.require_iso_utc(aggregate["checked_at"], "L4 checked_at")
    common.require(aggregate["scope"] == "vertical" and aggregate["cell_id"] == "layer_4", "L4 aggregate cell mismatch")
    common.require(
        aggregate["baseline_percent"] == 55
        and aggregate["credited_percent"] == 100
        and aggregate["credit_points_total"] == 45,
        "L4 aggregate credit transition mismatch",
    )
    common.require(type(aggregate["provider_calls_total_observed"]) is int and aggregate["provider_calls_total_observed"] > 0, "L4 provider call count missing")
    common.require(aggregate["live_provider_calls_verified"] is True, "L4 live provider calls not verified")
    common.require(aggregate["hosted_audit_write_verified"] is True, "L4 hosted audit write not verified")
    for key in ("direct_provider_calls", "provider_writes", "production_deploy", "release_promotion", "secret_output"):
        common.require(aggregate[key] is False, f"L4 aggregate {key} must be false")
    common.require(isinstance(aggregate["non_claims"], list) and aggregate["non_claims"], "L4 non-claims missing")

    source = common.require_exact_keys(aggregate["source"], SOURCE_KEYS, "L4 source")
    candidate_sha = common.require_lower_hex(source["commit_sha"], 40, "L4 candidate source SHA")
    common.require_lower_hex(source["archive_sha256"], 64, "L4 source archive SHA-256")
    for key in ("gateway_tree_sha", "runtime_blob", "wrangler_blob", "rubric_blob", "capability_blob"):
        common.require_lower_hex(source[key], 40, f"L4 source {key}")
    common.validate_candidate_pointer(
        evidence_source_sha=evidence_source,
        candidate_source_sha=candidate_sha,
        release_id=aggregate["release_id"],
        load_blob=load_blob,
        is_ancestor=is_ancestor,
    )
    common.require(
        artifact_path.startswith(
            f"docs/release-artifacts/{aggregate['release_id']}-evidence/hosted-layer/"
        ),
        "L4 aggregate path does not match its release id",
    )
    rubric_approval = common.require_lower_hex(aggregate["rubric_approval_commit"], 40, "L4 rubric approval commit")
    common.require(is_ancestor(rubric_approval, candidate_sha), "L4 rubric approval is not a candidate ancestor")

    authority = common.require_exact_keys(aggregate["authority"], AUTHORITY_KEYS, "L4 authority")
    common.require_lower_hex(authority["owner_grant_ref_sha256"], 64, "L4 Owner grant ref SHA-256")
    common.validate_repo_path(authority["gate_evidence_path"], "L4 gate evidence path")
    common.require_lower_hex(authority["gate_evidence_blob"], 40, "L4 gate evidence blob")
    gates = common.require_exact_keys(aggregate["gates"], GATE_KEYS, "L4 gates")
    common.require(gates == {"live_llm_owner_granted": True, "live_llm_live_verified": True, "paid_provider": False}, "L4 gate state mismatch")
    historical = common.require_exact_keys(aggregate["historical_credit"], HISTORICAL_KEYS, "L4 historical credit")
    common.require(
        historical["included_in_baseline_points"] == 10
        and historical["excluded_from_delta"] is True
        and historical["forbidden_report_contracts"] == [FORBIDDEN_LEGACY_CONTRACT]
        and historical["legacy_progress_credit_recommended"] == 0,
        "L4 historical credit exclusion mismatch",
    )

    criteria = aggregate["criteria"]
    common.require(isinstance(criteria, list) and len(criteria) == 7, "L4 criterion count mismatch")
    observed: set[str] = set()
    observed_claims: set[str] = set()
    path_by_criterion: dict[str, str] = {}
    hash_by_criterion: dict[str, str] = {}
    total = 0
    for index, raw in enumerate(criteria):
        criterion = common.require_exact_keys(raw, CRITERION_KEYS, f"L4 criterion[{index}]")
        criterion_id = criterion["criterion_id"]
        common.require(isinstance(criterion_id, str) and criterion_id in CRITERIA, "unsupported L4 criterion")
        common.require(criterion_id not in observed, "duplicate L4 criterion")
        observed.add(criterion_id)
        spec = CRITERIA[criterion_id]
        common.require(criterion["points"] == spec["points"], f"{criterion_id} points mismatch")
        common.require(criterion["report_contract"] == spec["contract"], f"{criterion_id} report contract binding mismatch")
        common.require(criterion["evidence_ref"] == spec["evidence_ref"], f"{criterion_id} evidence ref binding mismatch")
        common.require(criterion["claim_ids"] == spec["claim_ids"], f"{criterion_id} claim IDs mismatch")
        for claim_id in criterion["claim_ids"]:
            common.require(claim_id not in observed_claims, f"duplicate L4 atomic claim {claim_id}")
            observed_claims.add(claim_id)
        report, report_path = common.load_hashed_json(
            evidence_source,
            criterion["report_path"],
            criterion["report_sha256"],
            context=criterion_id,
            load_blob=load_blob,
        )
        path_by_criterion[criterion_id] = report_path
        hash_by_criterion[criterion_id] = criterion["report_sha256"]
        _validate_report(report, spec, candidate_sha, criterion_id)
        common.require(report.get("contract_version") != FORBIDDEN_LEGACY_CONTRACT, "legacy L4 evidence was reused")
        total += int(spec["points"])
    common.require(observed == set(CRITERIA), "L4 criterion set mismatch")
    common.require(total == 45, "L4 criterion total mismatch")
    common.require(
        path_by_criterion["hosted_generative_source_bound"]
        == path_by_criterion["hosted_routing_and_completion_audit"]
        and hash_by_criterion["hosted_generative_source_bound"]
        == hash_by_criterion["hosted_routing_and_completion_audit"],
        "L4 shared current-chain report binding mismatch",
    )
    for criterion_id, path in path_by_criterion.items():
        if criterion_id not in {"hosted_generative_source_bound", "hosted_routing_and_completion_audit"}:
            common.require(
                path not in {
                    other_path
                    for other_id, other_path in path_by_criterion.items()
                    if other_id != criterion_id
                },
                f"{criterion_id} unexpectedly reuses another report",
            )
    return common.scorer_result(request)


def main(argv: list[str]) -> int:
    if argv != ["--score-v1"]:
        print("[layer4-hosted-llm-scorer] unsupported invocation", file=sys.stderr)
        return 2
    try:
        request = json.load(sys.stdin)
        result = score_request(request)
    except (ScoreError, json.JSONDecodeError, UnicodeError, OSError) as exc:
        print(f"[layer4-hosted-llm-scorer] rejected: {exc}", file=sys.stderr)
        return 2
    json.dump(result, sys.stdout, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

#!/usr/bin/env python3
"""Validate the exact current-hosted Layer-4 evidence set.

This module is intentionally independent from the progress manifest.  It builds
and validates the immutable scorer input for the seven *new* hosted criteria
only (45 points).  The older bounded live-LLM chain is named explicitly as
historical baseline evidence and can never be supplied as a current report.
"""

from __future__ import annotations

import hashlib
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any, Callable


BUILD_INPUT_CONTRACT = "layer4-hosted-llm-current-evidence-build-input-v1"
AGGREGATE_CONTRACT = "layer4-hosted-llm-current-evidence-v1"
AGGREGATE_EVIDENCE_REF = "current_hosted_llm_seven_criteria_credit_bound"
CURRENT_CHAIN_CONTRACT = "llm-hosted-current-evidence-chain-v2"
LEGACY_CHAIN_CONTRACT = "live-llm-bounded-evidence-chain-v1"
SANCTIONED_BASE_URL = "https://cloud-superbrain-llm-gateway-preview.strazzusochr.workers.dev"

BASELINE_PERCENT = 55
CREDITED_PERCENT = 100
CURRENT_CREDIT_POINTS = 45
HISTORICAL_CREDIT_POINTS_EXCLUDED = 10
PROVIDER_CALLS_TOTAL = 6

REPORT_KEYS = ("current_chain", "stream", "fallback", "budget", "trace", "negative")
BUILD_INPUT_KEYS = {
    "contract_version",
    "release_id",
    "candidate_source_commit_sha",
    "candidate_source_archive_sha256",
    "rubric_approval_commit",
    "reports",
}

REPORT_SPECS: dict[str, tuple[str, str, int]] = {
    "current_chain": (
        CURRENT_CHAIN_CONTRACT,
        "L4 current hosted generation, routing allowlist, and completion audit",
        18,
    ),
    "stream": (
        "llm-hosted-stream-parity-evidence-v2",
        "L4 hosted stream and non-stream are semantically equal",
        10,
    ),
    "fallback": (
        "llm-hosted-fallback-evidence-v2",
        "L4 hosted fallback is bounded and audited",
        3,
    ),
    "budget": (
        "llm-hosted-budget-guard-evidence-v2",
        "L4 hosted budget guard stops before provider execution",
        3,
    ),
    "trace": (
        "llm-hosted-trace-correlation-evidence-v2",
        "L4 hosted trace ID correlates gateway, provider, and immutable evidence",
        4,
    ),
    "negative": (
        "llm-hosted-negative-guards-evidence-v2",
        "L4 hosted auth, oversize, schema, and policy guards stop before provider execution",
        7,
    ),
}

CRITERIA: tuple[dict[str, Any], ...] = (
    {
        "criterion_id": "hosted_generative_source_bound",
        "points": 10,
        "report_key": "current_chain",
        "evidence_ref": "current_hosted_llm_generative_verified",
        "claim_ids": ["hosted_generative_source_bound"],
    },
    {
        "criterion_id": "hosted_stream_semantic_parity",
        "points": 10,
        "report_key": "stream",
        "evidence_ref": "current_hosted_llm_stream_parity_verified",
        "claim_ids": ["hosted_stream_semantic_parity"],
    },
    {
        "criterion_id": "hosted_routing_and_completion_audit",
        "points": 8,
        "report_key": "current_chain",
        "evidence_ref": "current_hosted_llm_routing_completion_audit_verified",
        "claim_ids": ["hosted_routing_allowlist", "hosted_completion_audit"],
    },
    {
        "criterion_id": "hosted_fallback_bounded_audited",
        "points": 3,
        "report_key": "fallback",
        "evidence_ref": "current_hosted_llm_fallback_verified",
        "claim_ids": ["hosted_fallback_bounded_audited"],
    },
    {
        "criterion_id": "hosted_budget_guard_pre_provider",
        "points": 3,
        "report_key": "budget",
        "evidence_ref": "current_hosted_llm_budget_guard_verified",
        "claim_ids": ["hosted_budget_guard_pre_provider"],
    },
    {
        "criterion_id": "hosted_trace_correlation",
        "points": 4,
        "report_key": "trace",
        "evidence_ref": "current_hosted_llm_trace_correlation_verified",
        "claim_ids": ["hosted_trace_correlation"],
    },
    {
        "criterion_id": "hosted_negative_guards_pre_provider",
        "points": 7,
        "report_key": "negative",
        "evidence_ref": "current_hosted_llm_negative_guards_verified",
        "claim_ids": [
            "hosted_auth_guard",
            "hosted_oversize_guard",
            "hosted_schema_policy_guard",
        ],
    },
)

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

CRITERION_KEYS = {
    "criterion_id",
    "points",
    "report_path",
    "report_sha256",
    "report_contract",
    "evidence_ref",
    "claim_ids",
}

HISTORICAL_CREDIT = {
    "included_in_baseline_points": HISTORICAL_CREDIT_POINTS_EXCLUDED,
    "excluded_from_delta": True,
    "forbidden_report_contracts": [LEGACY_CHAIN_CONTRACT],
    "legacy_progress_credit_recommended": 0,
}

NON_CLAIMS = [
    "Credit is limited to the seven current hosted L4 criteria (45 points).",
    "The historical bounded evidence chain remains included in the 55-point baseline and receives no delta credit.",
    "No paid provider, direct provider call, production deploy, release promotion, or secret output is claimed.",
    "Raw verifier evidence must be immutable, candidate-source-bound, and secret-redacted.",
]


class EvidenceError(ValueError):
    """Raised when any current-evidence invariant is not proven exactly."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise EvidenceError(message)


def require_exact_keys(value: Any, expected: set[str], context: str) -> dict[str, Any]:
    require(isinstance(value, dict), f"{context} must be an object")
    require(set(value) == expected, f"{context} keys mismatch")
    return value


def require_bool(value: Any, expected: bool, context: str) -> None:
    require(type(value) is bool and value is expected, f"{context} must be JSON boolean {str(expected).lower()}")


def require_lower_hex(value: Any, length: int, context: str) -> str:
    require(
        isinstance(value, str) and re.fullmatch(rf"[0-9a-f]{{{length}}}", value) is not None,
        f"{context} must be lowercase hex",
    )
    return value


def require_iso_utc(value: Any, context: str) -> str:
    require(
        isinstance(value, str)
        and re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z", value) is not None,
        f"{context} must be an ISO UTC timestamp",
    )
    return value


def normalized_repo_path(value: Any, context: str) -> str:
    require(isinstance(value, str) and value, f"{context} missing")
    require("\\" not in value, f"{context} must use POSIX separators")
    path = PurePosixPath(value)
    require(
        not path.is_absolute()
        and path.as_posix() == value
        and "." not in path.parts
        and ".." not in path.parts
        and re.fullmatch(r"[A-Za-z0-9._/-]+", value) is not None,
        f"{context} is not a normalized repository path",
    )
    return value


def decode_json(blob: bytes, context: str) -> dict[str, Any]:
    try:
        value = json.loads(blob.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise EvidenceError(f"{context} is invalid JSON") from exc
    require(isinstance(value, dict), f"{context} root must be an object")
    return value


def _required_object(report: dict[str, Any], key: str, context: str) -> dict[str, Any]:
    value = report.get(key)
    require(isinstance(value, dict), f"{context} {key} must be an object")
    return value


def _common_identity(report: dict[str, Any], report_key: str) -> dict[str, Any]:
    source = _required_object(report, "source", report_key)
    for key in (
        "commit_sha",
        "gateway_tree_sha",
        "verifier_blob",
        "runtime_blob",
        "wrangler_blob",
        "rubric_blob",
        "capability_blob",
    ):
        require_lower_hex(source.get(key), 40, f"{report_key} source {key}")
    require_lower_hex(source.get("archive_sha256"), 64, f"{report_key} source archive_sha256")
    if report_key == "current_chain":
        require_lower_hex(source.get("implementation_blob"), 40, "current_chain source implementation_blob")

    authority = _required_object(report, "authority", report_key)
    require_exact_keys(
        authority,
        {"owner_grant_ref_sha256", "gate_evidence_path", "gate_evidence_blob"},
        f"{report_key} authority",
    )
    require_lower_hex(authority["owner_grant_ref_sha256"], 64, f"{report_key} owner grant ref")
    normalized_repo_path(authority["gate_evidence_path"], f"{report_key} gate evidence path")
    require_lower_hex(authority["gate_evidence_blob"], 40, f"{report_key} gate evidence blob")
    return {
        "source": {
            "commit_sha": source["commit_sha"],
            "archive_sha256": source["archive_sha256"],
            "gateway_tree_sha": source["gateway_tree_sha"],
            "runtime_blob": source["runtime_blob"],
            "wrangler_blob": source["wrangler_blob"],
            "rubric_blob": source["rubric_blob"],
            "capability_blob": source["capability_blob"],
        },
        "authority": dict(authority),
    }


def _validate_current_chain(report: dict[str, Any]) -> None:
    require(report.get("evidence_ref") == "current_hosted_llm_generative_routing_audit_verified", "current_chain evidence ref mismatch")
    atomics = report.get("criteria")
    require(isinstance(atomics, list), "current_chain criteria must be an array")
    expected = [
        {"claim_id": "hosted_generative_source_bound", "points": 10},
        {"claim_id": "hosted_routing_allowlist", "points": 4},
        {"claim_id": "hosted_completion_audit", "points": 4},
    ]
    require(atomics == expected, "current_chain atomic criteria mismatch")

    generation = _required_object(report, "generation", "current_chain")
    require(isinstance(generation.get("model"), str) and generation["model"].startswith("@cf/"), "current_chain generation model mismatch")
    require(generation.get("provider") == "workers-ai", "current_chain generation provider mismatch")
    for key in ("response_sha256", "request_id_sha256", "trace_id_sha256", "gateway_log_id_sha256"):
        require_lower_hex(generation.get(key), 64, f"current_chain generation {key}")
    require(isinstance(generation.get("d1_evidence_ref"), str) and generation["d1_evidence_ref"].startswith("d1_audit:"), "current_chain generation D1 evidence missing")
    require_bool(generation.get("source_bound"), True, "current_chain generation source_bound")
    require_bool(generation.get("gateway_log_readback_verified"), True, "current_chain generation gateway_log_readback_verified")

    routing = _required_object(report, "routing", "current_chain")
    require(routing.get("requested_model") == generation["model"], "current_chain requested model mismatch")
    require(routing.get("selected_model") == generation["model"], "current_chain selected model mismatch")
    require_lower_hex(routing.get("allowed_models_sha256"), 64, "current_chain allowed_models_sha256")
    require(type(routing.get("allowed_model_count")) is int and routing["allowed_model_count"] >= 1, "current_chain allowed model count mismatch")
    require_bool(routing.get("allowlist_verified"), True, "current_chain allowlist_verified")
    require_bool(routing.get("gateway_only"), True, "current_chain gateway_only")
    require_bool(routing.get("fallback_used"), False, "current_chain fallback_used")

    audit = _required_object(report, "audit", "current_chain")
    require_bool(audit.get("persisted"), True, "current_chain audit persisted")
    require_bool(audit.get("readback_verified"), True, "current_chain audit readback_verified")
    require_bool(audit.get("source_bound"), True, "current_chain audit source_bound")
    require(audit.get("provider_call_count") == 1, "current_chain audit provider call count mismatch")

    historical = _required_object(report, "historical_evidence", "current_chain")
    require_exact_keys(
        historical,
        {"contract_version", "progress_credit_recommended", "excluded_from_current_delta"},
        "current_chain historical evidence",
    )
    require(historical["contract_version"] == LEGACY_CHAIN_CONTRACT, "current_chain historical contract mismatch")
    require(historical["progress_credit_recommended"] == 0, "current_chain historical progress credit must remain zero")
    require_bool(historical["excluded_from_current_delta"], True, "current_chain historical exclusion")
    require_bool(report.get("live_provider_calls"), True, "current_chain live_provider_calls")
    require(report.get("provider_call_count") == 1, "current_chain provider call count mismatch")


def _validate_stream(report: dict[str, Any]) -> None:
    require_bool(report.get("live_provider_calls"), True, "stream live_provider_calls")
    require(report.get("provider_call_count") == 2, "stream provider call count mismatch")
    require_bool(report.get("semantic_parity"), True, "stream semantic_parity")
    nonstream = _required_object(report, "nonstream", "stream")
    streamed = _required_object(report, "stream", "stream")
    for key, value in (("nonstream", nonstream), ("stream", streamed)):
        require_bool(value.get("gateway_log_readback_verified"), True, f"{key} gateway log readback")
        require_bool(value.get("audit_readback_verified"), True, f"{key} audit readback")
    require(type(streamed.get("frame_count")) is int and streamed["frame_count"] > 0, "stream frame count mismatch")
    require(streamed.get("done_count") == 1, "stream DONE count mismatch")
    require_bool(streamed.get("synthetic_terminal_frame"), False, "stream synthetic terminal frame")


def _validate_fallback(report: dict[str, Any]) -> None:
    require_bool(report.get("live_provider_calls"), True, "fallback live_provider_calls")
    require(report.get("provider_call_count") == 2, "fallback provider call count mismatch")
    fallback = _required_object(report, "fallback", "fallback")
    require(fallback.get("provider_attempt_count") == 2, "fallback provider attempt count mismatch")
    ids = fallback.get("gateway_log_id_sha256")
    require(isinstance(ids, list) and len(ids) == 2 and len(set(ids)) == 2, "fallback gateway log IDs must be two distinct hashes")
    for index, value in enumerate(ids):
        require_lower_hex(value, 64, f"fallback gateway log hash {index}")
    require(isinstance(fallback.get("d1_evidence_ref"), str) and fallback["d1_evidence_ref"].startswith("d1_audit:"), "fallback D1 evidence missing")
    require_bool(fallback.get("gateway_log_readback_verified"), True, "fallback gateway log readback")
    require_bool(fallback.get("audit_readback_verified"), True, "fallback audit readback")


def _validate_budget(report: dict[str, Any]) -> None:
    require_bool(report.get("live_provider_calls"), False, "budget live_provider_calls")
    probe = _required_object(report, "probe", "budget")
    require(probe.get("http_status") == 422, "budget HTTP status mismatch")
    require(probe.get("error") == "input_limit_exceeded", "budget error mismatch")
    require(probe.get("provider_call_count") == 0, "budget provider call count mismatch")
    require_bool(probe.get("audit_readback_verified"), True, "budget audit readback")
    require_bool(probe.get("gateway_log_readback_required"), False, "budget gateway log readback requirement")


def _validate_trace(report: dict[str, Any]) -> None:
    require_bool(report.get("live_provider_calls"), True, "trace live_provider_calls")
    require(report.get("provider_call_count") == 1, "trace provider call count mismatch")
    trace = _required_object(report, "trace", "trace")
    require_lower_hex(trace.get("trace_id"), 32, "trace ID")
    require_lower_hex(trace.get("gateway_log_id_sha256"), 64, "trace gateway log hash")
    require(isinstance(trace.get("d1_evidence_ref"), str) and trace["d1_evidence_ref"].startswith("d1_audit:"), "trace D1 evidence missing")
    require_bool(trace.get("gateway_log_readback_verified"), True, "trace gateway log readback")
    require_bool(trace.get("audit_readback_verified"), True, "trace audit readback")


def _validate_negative(report: dict[str, Any]) -> None:
    require_bool(report.get("live_provider_calls"), False, "negative live_provider_calls")
    require(report.get("provider_call_count") == 0, "negative provider call count mismatch")
    probes = report.get("probes")
    require(isinstance(probes, list) and len(probes) == 5, "negative probe count mismatch")
    matrix = {
        probe.get("name"): (probe.get("http_status"), probe.get("error"))
        for probe in probes
        if isinstance(probe, dict)
    }
    require(
        matrix
        == {
            "missing_auth": (401, "gateway_authentication_required"),
            "invalid_auth": (401, "gateway_authentication_required"),
            "oversize": (422, "input_limit_exceeded"),
            "schema_violation": (422, "invalid_messages"),
            "policy_violation": (403, "model_not_allowed"),
        },
        "negative probe matrix mismatch",
    )


SPECIFIC_VALIDATORS: dict[str, Callable[[dict[str, Any]], None]] = {
    "current_chain": _validate_current_chain,
    "stream": _validate_stream,
    "fallback": _validate_fallback,
    "budget": _validate_budget,
    "trace": _validate_trace,
    "negative": _validate_negative,
}


def validate_report(
    report: dict[str, Any],
    report_key: str,
    *,
    source_commit_sha: str,
    source_archive_sha256: str,
    rubric_approval_commit: str,
) -> dict[str, Any]:
    require(report_key in REPORT_SPECS, f"unsupported report key: {report_key}")
    contract, criterion, points = REPORT_SPECS[report_key]
    require(report.get("contract_version") == contract, f"{report_key} contract mismatch")
    require(report.get("contract_version") != LEGACY_CHAIN_CONTRACT, f"{report_key} uses historical evidence")
    require(report.get("status") == "verified", f"{report_key} status mismatch")
    require(report.get("criterion") == criterion, f"{report_key} criterion mismatch")
    require(report.get("criterion_points") == points, f"{report_key} criterion points mismatch")
    require_bool(report.get("credit_eligible"), True, f"{report_key} credit_eligible")
    require_iso_utc(report.get("checked_at"), f"{report_key} checked_at")
    require(report.get("base_url") == SANCTIONED_BASE_URL, f"{report_key} base URL mismatch")
    require(report.get("rubric_approval_commit") == rubric_approval_commit, f"{report_key} rubric mismatch")
    identity = _common_identity(report, report_key)
    require(identity["source"]["commit_sha"] == source_commit_sha, f"{report_key} source commit mismatch")
    require(identity["source"]["archive_sha256"] == source_archive_sha256, f"{report_key} source archive mismatch")
    for key in (
        "direct_provider_calls",
        "provider_writes",
        "secret_output",
        "manifest_updated",
        "delta_ledger_entry_created",
        "production_deploy",
        "release_promotion",
    ):
        require_bool(report.get(key), False, f"{report_key} {key}")
    require_bool(report.get("hosted_audit_write"), True, f"{report_key} hosted_audit_write")
    SPECIFIC_VALIDATORS[report_key](report)
    return identity


def _read_reports(
    paths: dict[str, Any],
    load_report: Callable[[str], bytes],
    *,
    source_commit_sha: str,
    source_archive_sha256: str,
    rubric_approval_commit: str,
) -> tuple[dict[str, bytes], dict[str, dict[str, Any]], dict[str, Any]]:
    require_exact_keys(paths, set(REPORT_KEYS), "report path map")
    blobs: dict[str, bytes] = {}
    reports: dict[str, dict[str, Any]] = {}
    common_identity: dict[str, Any] | None = None
    for report_key in REPORT_KEYS:
        path = normalized_repo_path(paths[report_key], f"{report_key} report path")
        try:
            blob = load_report(path)
        except (KeyError, OSError) as exc:
            raise EvidenceError(f"{report_key} report cannot be read") from exc
        require(isinstance(blob, bytes), f"{report_key} loader must return bytes")
        report = decode_json(blob, report_key)
        identity = validate_report(
            report,
            report_key,
            source_commit_sha=source_commit_sha,
            source_archive_sha256=source_archive_sha256,
            rubric_approval_commit=rubric_approval_commit,
        )
        if common_identity is None:
            common_identity = identity
        else:
            require(identity["source"] == common_identity["source"], f"{report_key} common source binding mismatch")
            require(identity["authority"] == common_identity["authority"], f"{report_key} authority binding mismatch")
        blobs[report_key] = blob
        reports[report_key] = report
    assert common_identity is not None
    return blobs, reports, common_identity


def build_aggregate(
    build_input: dict[str, Any],
    load_report: Callable[[str], bytes],
    *,
    checked_at: str | None = None,
) -> dict[str, Any]:
    request = require_exact_keys(build_input, BUILD_INPUT_KEYS, "build input")
    require(request["contract_version"] == BUILD_INPUT_CONTRACT, "build input contract mismatch")
    release_id = request["release_id"]
    require(isinstance(release_id, str) and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{2,127}", release_id) is not None, "release_id invalid")
    source_sha = require_lower_hex(request["candidate_source_commit_sha"], 40, "candidate source commit")
    archive_sha = require_lower_hex(request["candidate_source_archive_sha256"], 64, "candidate source archive")
    rubric_sha = require_lower_hex(request["rubric_approval_commit"], 40, "rubric approval commit")
    blobs, _, identity = _read_reports(
        request["reports"],
        load_report,
        source_commit_sha=source_sha,
        source_archive_sha256=archive_sha,
        rubric_approval_commit=rubric_sha,
    )
    timestamp = checked_at or datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")
    require_iso_utc(timestamp, "aggregate checked_at")

    criteria: list[dict[str, Any]] = []
    for spec in CRITERIA:
        report_key = spec["report_key"]
        report_path = request["reports"][report_key]
        criteria.append(
            {
                "criterion_id": spec["criterion_id"],
                "points": spec["points"],
                "report_path": report_path,
                "report_sha256": hashlib.sha256(blobs[report_key]).hexdigest(),
                "report_contract": REPORT_SPECS[report_key][0],
                "evidence_ref": spec["evidence_ref"],
                "claim_ids": list(spec["claim_ids"]),
            }
        )

    aggregate = {
        "contract_version": AGGREGATE_CONTRACT,
        "status": "verified",
        "evidence_ref": AGGREGATE_EVIDENCE_REF,
        "checked_at": timestamp,
        "scope": "vertical",
        "cell_id": "layer_4",
        "release_id": release_id,
        "source": identity["source"],
        "rubric_approval_commit": rubric_sha,
        "authority": identity["authority"],
        "gates": {
            "live_llm_owner_granted": True,
            "live_llm_live_verified": True,
            "paid_provider": False,
        },
        "baseline_percent": BASELINE_PERCENT,
        "credited_percent": CREDITED_PERCENT,
        "credit_points_total": CURRENT_CREDIT_POINTS,
        "historical_credit": dict(HISTORICAL_CREDIT),
        "criteria": criteria,
        "provider_calls_total_observed": PROVIDER_CALLS_TOTAL,
        "live_provider_calls_verified": True,
        "hosted_audit_write_verified": True,
        "direct_provider_calls": False,
        "provider_writes": False,
        "production_deploy": False,
        "release_promotion": False,
        "secret_output": False,
        "non_claims": list(NON_CLAIMS),
    }
    validate_aggregate(aggregate, load_report)
    return aggregate


def validate_aggregate(
    aggregate: dict[str, Any],
    load_report: Callable[[str], bytes],
) -> dict[str, Any]:
    value = require_exact_keys(aggregate, AGGREGATE_KEYS, "aggregate")
    require(value["contract_version"] == AGGREGATE_CONTRACT, "aggregate contract mismatch")
    require(value["status"] == "verified", "aggregate status mismatch")
    require(value["evidence_ref"] == AGGREGATE_EVIDENCE_REF, "aggregate evidence ref mismatch")
    require_iso_utc(value["checked_at"], "aggregate checked_at")
    require(value["scope"] == "vertical" and value["cell_id"] == "layer_4", "aggregate scope/cell mismatch")
    require(isinstance(value["release_id"], str) and value["release_id"], "aggregate release missing")
    source = require_exact_keys(
        value["source"],
        {"commit_sha", "archive_sha256", "gateway_tree_sha", "runtime_blob", "wrangler_blob", "rubric_blob", "capability_blob"},
        "aggregate source",
    )
    source_sha = require_lower_hex(source["commit_sha"], 40, "aggregate source commit")
    archive_sha = require_lower_hex(source["archive_sha256"], 64, "aggregate source archive")
    for key in ("gateway_tree_sha", "runtime_blob", "wrangler_blob", "rubric_blob", "capability_blob"):
        require_lower_hex(source[key], 40, f"aggregate source {key}")
    rubric_sha = require_lower_hex(value["rubric_approval_commit"], 40, "aggregate rubric approval commit")
    authority = require_exact_keys(
        value["authority"],
        {"owner_grant_ref_sha256", "gate_evidence_path", "gate_evidence_blob"},
        "aggregate authority",
    )
    require_lower_hex(authority["owner_grant_ref_sha256"], 64, "aggregate owner grant ref")
    normalized_repo_path(authority["gate_evidence_path"], "aggregate gate evidence path")
    require_lower_hex(authority["gate_evidence_blob"], 40, "aggregate gate evidence blob")
    gates = require_exact_keys(
        value["gates"],
        {"live_llm_owner_granted", "live_llm_live_verified", "paid_provider"},
        "aggregate gates",
    )
    require_bool(gates["live_llm_owner_granted"], True, "aggregate live LLM Owner gate")
    require_bool(gates["live_llm_live_verified"], True, "aggregate live LLM verified gate")
    require_bool(gates["paid_provider"], False, "aggregate paid provider")
    require(
        value["baseline_percent"] == BASELINE_PERCENT
        and value["credited_percent"] == CREDITED_PERCENT
        and value["credit_points_total"] == CURRENT_CREDIT_POINTS,
        "aggregate points transition mismatch",
    )
    require(value["historical_credit"] == HISTORICAL_CREDIT, "aggregate historical credit exclusion mismatch")
    require(value["provider_calls_total_observed"] == PROVIDER_CALLS_TOTAL, "aggregate provider call total mismatch")
    require_bool(value["live_provider_calls_verified"], True, "aggregate live provider verification")
    require_bool(value["hosted_audit_write_verified"], True, "aggregate hosted audit write verification")
    for key in ("direct_provider_calls", "provider_writes", "production_deploy", "release_promotion", "secret_output"):
        require_bool(value[key], False, f"aggregate {key}")
    require(value["non_claims"] == NON_CLAIMS, "aggregate non-claims mismatch")

    criteria = value["criteria"]
    require(isinstance(criteria, list) and len(criteria) == len(CRITERIA), "aggregate criterion count mismatch")
    report_paths: dict[str, str] = {}
    total = 0
    claim_ids: set[str] = set()
    loaded_reports: dict[str, dict[str, Any]] = {}
    for index, spec in enumerate(CRITERIA):
        criterion = require_exact_keys(criteria[index], CRITERION_KEYS, f"criterion {index}")
        require(criterion["criterion_id"] == spec["criterion_id"], f"criterion {index} ID mismatch")
        require(criterion["points"] == spec["points"], f"criterion {spec['criterion_id']} points mismatch")
        require(criterion["claim_ids"] == spec["claim_ids"], f"criterion {spec['criterion_id']} claim IDs mismatch")
        for claim_id in criterion["claim_ids"]:
            require(claim_id not in claim_ids, f"criterion claim duplicated: {claim_id}")
            claim_ids.add(claim_id)
        report_key = spec["report_key"]
        report_path = normalized_repo_path(criterion["report_path"], f"criterion {spec['criterion_id']} report path")
        require(criterion["report_contract"] == REPORT_SPECS[report_key][0], f"criterion {spec['criterion_id']} report binding mismatch")
        require(criterion["evidence_ref"] == spec["evidence_ref"], f"criterion {spec['criterion_id']} evidence ref mismatch")
        if report_key in report_paths:
            require(
                report_key == "current_chain" and report_paths[report_key] == report_path,
                f"criterion {spec['criterion_id']} report binding is duplicated",
            )
        else:
            require(report_path not in report_paths.values(), f"criterion {spec['criterion_id']} report binding is reused")
            report_paths[report_key] = report_path
        try:
            blob = load_report(report_path)
        except (KeyError, OSError) as exc:
            raise EvidenceError(f"criterion {spec['criterion_id']} report cannot be read") from exc
        require(isinstance(blob, bytes), f"criterion {spec['criterion_id']} loader must return bytes")
        expected_hash = require_lower_hex(criterion["report_sha256"], 64, f"criterion {spec['criterion_id']} report hash")
        require(hashlib.sha256(blob).hexdigest() == expected_hash, f"criterion {spec['criterion_id']} report hash mismatch")
        report = decode_json(blob, report_key)
        validate_report(
            report,
            report_key,
            source_commit_sha=source_sha,
            source_archive_sha256=archive_sha,
            rubric_approval_commit=rubric_sha,
        )
        report_identity = _common_identity(report, report_key)
        require(report_identity["source"] == source, f"criterion {spec['criterion_id']} aggregate source mismatch")
        require(report_identity["authority"] == authority, f"criterion {spec['criterion_id']} aggregate authority mismatch")
        loaded_reports[report_key] = report
        total += criterion["points"]
    require(set(report_paths) == set(REPORT_KEYS), "aggregate report set mismatch")
    require(total == CURRENT_CREDIT_POINTS, "aggregate criterion points do not total 45")
    require(loaded_reports["current_chain"]["contract_version"] != LEGACY_CHAIN_CONTRACT, "historical chain cannot receive current credit")
    return {
        "contract_version": AGGREGATE_CONTRACT,
        "scope": "vertical",
        "cell_id": "layer_4",
        "baseline_percent": BASELINE_PERCENT,
        "credited_percent": CREDITED_PERCENT,
        "credit_points_total": CURRENT_CREDIT_POINTS,
        "historical_credit_excluded": True,
        "evidence_verified": True,
    }


def filesystem_loader(root: Path) -> Callable[[str], bytes]:
    resolved_root = root.resolve()

    def load(path: str) -> bytes:
        normalized = normalized_repo_path(path, "report path")
        candidate = (resolved_root / PurePosixPath(normalized)).resolve()
        require(candidate.is_relative_to(resolved_root), "report path escapes repository root")
        return candidate.read_bytes()

    return load


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[0] != "--validate-v1":
        print("[layer4-current-evidence] unsupported invocation", file=sys.stderr)
        return 2
    repo_root = Path(__file__).resolve().parents[1]
    input_path = normalized_repo_path(argv[1], "aggregate input path")
    try:
        aggregate = decode_json((repo_root / PurePosixPath(input_path)).read_bytes(), "aggregate")
        summary = validate_aggregate(aggregate, filesystem_loader(repo_root))
    except (EvidenceError, OSError) as exc:
        print(f"[layer4-current-evidence] rejected: {exc}", file=sys.stderr)
        return 2
    print(json.dumps(summary, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

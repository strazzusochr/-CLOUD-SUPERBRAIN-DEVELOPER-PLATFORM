#!/usr/bin/env python3
"""Evidence-only scorer for the exact Phase-3 44 -> 100 OAuth slice."""

from __future__ import annotations

import hashlib
import json
import re
import sys
from typing import Any, Callable

try:
    from . import progress_credit_scorer_common as common
    from .score_phase5_market_ready_credit import _validate_auth
except ImportError:  # Direct execution from the repository root.
    import progress_credit_scorer_common as common
    from score_phase5_market_ready_credit import _validate_auth


SCORER_COMMAND = "python scripts/score_phase3_oauth_credit.py --score-v1"
AGGREGATE_CONTRACT = "phase3-oauth-credit-evidence-v1"
FLOW_CONTRACT = "cloudflare-oauth-hosted-current-flow-v1"
AUTH_CONTRACT = "production-auth-identity-proof-v1"
CAPABILITY_CONTRACT = "capability-gate-state-v1"
RAW_VERIFIER_PATH = "scripts/verify-cloudflare-oauth-p3-raw-evidence.ps1"
AUTH_VERIFIER_PATH = "scripts/verify-production-auth-identity-evidence.ps1"
STEP_NAMES = [
    "anonymous_login_no_identity",
    "github_start_exact_query",
    "github_cancel_no_credentials",
    "github_authorize_owner_identity",
    "callback_one_time_state",
    "auth_me_verified_identity",
    "reload_session_continuity",
    "refresh_atomic_rotation",
    "old_refresh_replay_rejected",
    "callback_replay_rejected",
    "logout_revocation_audited",
    "post_logout_refresh_rejected",
]
STEP_STATUSES = [401, 303, 401, 200, 303, 200, 200, 200, 401, 401, 200, 401]
AUDIT_EVENTS = [
    ("github_cancel_no_credentials", "auth_github_callback_blocked"),
    ("callback_one_time_state", "auth_github_callback_verified"),
    ("refresh_atomic_rotation", "auth_refresh_rotated"),
    ("old_refresh_replay_rejected", "auth_refresh_reuse_blocked"),
    ("callback_replay_rejected", "auth_github_callback_blocked"),
    ("logout_revocation_audited", "auth_logout_revoked"),
]
CRITERIA = {
    "P3-01": 8,
    "P3-02": 12,
    "P3-03": 8,
    "P3-04": 6,
    "P3-05": 8,
    "P3-06": 6,
    "P3-07": 4,
    "P3-08": 4,
}

ScoreError = common.ScoreError


def _validate_flow(flow: dict[str, Any], candidate_sha: str) -> str:
    common.require(flow.get("contract_version") == FLOW_CONTRACT, "OAuth flow contract mismatch")
    common.require(flow.get("status") == "evidence_envelope_complete", "OAuth flow envelope is incomplete")
    common.require(flow.get("architecture") == "cloudflare_native", "OAuth architecture mismatch")
    binding = flow.get("source_binding")
    common.require(isinstance(binding, dict), "OAuth source binding missing")
    for key in ("candidate_source_commit_sha", "worker_source_commit_sha"):
        common.require(binding.get(key) == candidate_sha, f"OAuth {key} mismatch")
    frontend_source_sha = common.require_lower_hex(
        binding.get("frontend_source_commit_sha"), 40, "OAuth frontend source SHA"
    )
    common.require(re.fullmatch(r"[0-9a-f]{64}", str(binding.get("worker_source_archive_sha256", ""))) is not None, "OAuth Worker archive binding invalid")
    frontend_origin = binding.get("frontend_origin")
    worker_origin = binding.get("worker_origin")
    common.require(isinstance(frontend_origin, str) and re.fullmatch(r"https://[^\s/]+\.vercel\.app", frontend_origin) is not None, "OAuth frontend origin mismatch")
    common.require(isinstance(worker_origin, str) and re.fullmatch(r"https://[^\s/]+\.workers\.dev", worker_origin) is not None, "OAuth Worker origin mismatch")
    common.require(binding.get("callback_url") == f"{frontend_origin}/api/v1/auth/callback", "OAuth callback URL mismatch")

    execution = flow.get("execution")
    common.require(isinstance(execution, dict), "OAuth execution binding missing")
    common.require(execution.get("target") == "production", "OAuth execution must use the canonical production identity origin")
    common.require(execution.get("transport") == "hosted_https" and execution.get("browser_execution") == "real_chrome", "OAuth execution is not a real hosted browser flow")
    common.require(execution.get("human_click_count") == 12, "OAuth human click count mismatch")
    common.require(execution.get("oauth_scope") == "read:user", "OAuth scope must be read:user")
    common.require(execution.get("provider_call_count") == 2, "OAuth provider call count mismatch")
    common.require(execution.get("provider_write_count") == 0 and execution.get("deployment_write_count") == 0, "OAuth evidence crossed a write boundary")
    common.require(execution.get("localhost_transport_count") == 0, "OAuth evidence used localhost")

    steps = flow.get("human_flow_steps")
    common.require(isinstance(steps, list) and len(steps) == 12, "OAuth proof must contain exactly 12 human-flow steps")
    sessions: dict[str, str] = {}
    for index, step in enumerate(steps):
        common.require(isinstance(step, dict), f"OAuth step[{index}] is invalid")
        common.require(step.get("sequence") == index + 1 and step.get("name") == STEP_NAMES[index], f"OAuth step[{index}] sequence mismatch")
        common.require(step.get("http_status") == STEP_STATUSES[index], f"OAuth step[{index}] HTTP status mismatch")
        common.require(step.get("human_click_count") == 1, f"OAuth step[{index}] lacks one human click")
        common.require(step.get("secret_value_count") == 0, f"OAuth step[{index}] contains a secret")
        common.require(re.fullmatch(r"[0-9a-f]{64}", str(step.get("request_correlation_sha256", ""))) is not None, f"OAuth step[{index}] request correlation invalid")
        if index >= 4:
            session = step.get("session_correlation_sha256")
            common.require(re.fullmatch(r"[0-9a-f]{64}", str(session or "")) is not None, f"OAuth step[{index}] session correlation invalid")
            sessions[STEP_NAMES[index]] = str(session)
        else:
            common.require(step.get("session_correlation_sha256") is None, f"OAuth step[{index}] invented a pre-auth session")
    family_a_session = sessions["callback_one_time_state"]
    common.require(all(sessions[name] == family_a_session for name in STEP_NAMES[4:10]), "OAuth family A session correlation mismatch")
    family_b_session = sessions["logout_revocation_audited"]
    common.require(sessions["post_logout_refresh_rejected"] == family_b_session and family_b_session != family_a_session, "OAuth family B session correlation mismatch")

    token_families = flow.get("token_families")
    common.require(isinstance(token_families, dict), "OAuth token family proof missing")
    common.require(token_families.get("contract_version") == "cloudflare-oauth-token-families-v1", "OAuth token family contract mismatch")
    common.require(token_families.get("distinct_family_count") == 2 and token_families.get("distinct_family_ids_verified") is True, "OAuth token families are not distinct")
    common.require(token_families.get("secret_value_count") == 0, "OAuth token family proof contains a secret")
    families = token_families.get("families")
    common.require(isinstance(families, list) and len(families) == 2, "OAuth proof must contain two token families")
    expected_families = (("family_a", "refresh_replay", family_a_session), ("family_b", "logout", family_b_session))
    family_ids: list[str] = []
    for family, expected in zip(families, expected_families):
        common.require(isinstance(family, dict), "OAuth token family entry is invalid")
        label, purpose, session = expected
        common.require(family.get("label") == label and family.get("purpose") == purpose, f"OAuth {label} role mismatch")
        family_hash = str(family.get("family_id_sha256", ""))
        common.require(re.fullmatch(r"[0-9a-f]{64}", family_hash) is not None, f"OAuth {label} identity hash invalid")
        common.require(family.get("session_correlation_sha256") == session, f"OAuth {label} session mismatch")
        common.require(family.get("credential_issue_after_terminal_count") == 0, f"OAuth {label} issued credentials after termination")
        family_ids.append(family_hash)
    common.require(len(set(family_ids)) == 2, "OAuth family identity hashes are not distinct")

    atomic = flow.get("atomic_replay_evidence")
    common.require(isinstance(atomic, dict), "OAuth atomic replay evidence missing")
    attempts = atomic.get("parallel_attempt_count")
    common.require(type(attempts) is int and attempts >= 2 and atomic.get("successful_rotation_count") == 1, "OAuth refresh rotation was not atomic")
    common.require(atomic.get("rejected_rotation_count") == attempts - 1, "OAuth parallel refresh rejection mismatch")
    common.require(atomic.get("old_refresh_replay_http_status") == 401 and atomic.get("callback_replay_http_status") == 401, "OAuth replay did not fail closed")
    for key in ("family_revocation_row_count", "replacement_refresh_rejection_count", "callback_state_consumption_count", "cancel_state_consumption_count"):
        common.require(atomic.get(key) == 1, f"OAuth atomic evidence {key} mismatch")
    common.require(atomic.get("callback_replay_credential_issue_count") == 0 and atomic.get("secret_value_count") == 0, "OAuth callback replay issued credentials or exposed a secret")

    correlations = flow.get("audit_correlations")
    common.require(isinstance(correlations, list) and len(correlations) == 6, "OAuth audit correlation count mismatch")
    observed = [(entry.get("step"), entry.get("event_type")) for entry in correlations if isinstance(entry, dict)]
    common.require(observed == AUDIT_EVENTS, "OAuth audit event sequence mismatch")
    for entry in correlations:
        common.require(entry.get("persisted_row_count") == 1 and entry.get("d1_readback_match_count") == 1, "OAuth audit readback mismatch")
        common.require(entry.get("persisted_sequence") == 1 and entry.get("credential_boundary_sequence") == 2, "OAuth audit was not persisted before credential issuance")
        common.require(entry.get("sensitive_field_count") == 0 and entry.get("secret_value_count") == 0, "OAuth audit contains sensitive data")

    redaction = flow.get("redaction")
    common.require(isinstance(redaction, dict) and redaction.get("identity_representation") == "sha256_only", "OAuth identity redaction mismatch")
    for key in ("sensitive_key_count", "sensitive_value_count", "log_scan_finding_count", "secret_scan_finding_count"):
        common.require(redaction.get(key) == 0, f"OAuth redaction {key} must be zero")
    transition = flow.get("gate_transition")
    common.require(isinstance(transition, dict) and all(value == 0 for value in transition.values()), "OAuth raw proof mutated a gate or percentage")
    return frontend_source_sha


def score_request(
    request: dict[str, Any],
    *,
    load_blob: Callable[[str, str], bytes] = common.git_blob,
    is_ancestor: Callable[[str, str], bool] = common.git_is_ancestor,
) -> dict[str, Any]:
    evidence_source, artifact_path, aggregate = common.validate_request_artifact(
        request,
        scorer_command=SCORER_COMMAND,
        scope="horizontal",
        cell_id="phase_3",
        old_percent=44,
        new_percent=100,
        load_blob=load_blob,
    )
    common.require(re.fullmatch(r"docs/release-artifacts/[^/]+-evidence/oauth/phase3-oauth-credit-evidence\.json", artifact_path) is not None, "unexpected Phase-3 aggregate path")
    expected_keys = {
        "contract_version", "status", "scope", "cell_id", "old_percent", "new_percent", "points_awarded",
        "credit_eligible", "release_id", "candidate_source_commit_sha", "criteria", "evidence",
        "live_github_oauth_calls", "provider_writes", "production_deploy", "release_promotion", "secret_output",
    }
    common.require_exact_keys(aggregate, expected_keys, "Phase-3 aggregate")
    common.require(aggregate["contract_version"] == AGGREGATE_CONTRACT and aggregate["status"] == "verified", "Phase-3 aggregate is not verified")
    common.require(aggregate["scope"] == "horizontal" and aggregate["cell_id"] == "phase_3", "Phase-3 aggregate cell mismatch")
    common.require((aggregate["old_percent"], aggregate["new_percent"], aggregate["points_awarded"]) == (44, 100, 56), "Phase-3 transition mismatch")
    common.require(aggregate["credit_eligible"] is True and aggregate["live_github_oauth_calls"] == 2, "Phase-3 live OAuth proof mismatch")
    for key in ("provider_writes", "production_deploy", "release_promotion", "secret_output"):
        common.require(aggregate[key] is False, f"Phase-3 aggregate {key} must be false")
    criteria = aggregate["criteria"]
    common.require(isinstance(criteria, list) and len(criteria) == 8, "Phase-3 criterion count mismatch")
    observed: set[str] = set()
    for entry in criteria:
        common.require(isinstance(entry, dict), "Phase-3 criterion is invalid")
        criterion_id = entry.get("id")
        common.require(criterion_id in CRITERIA and criterion_id not in observed, "Phase-3 criterion set mismatch")
        observed.add(str(criterion_id))
        common.require(entry == {"id": criterion_id, "points": CRITERIA[str(criterion_id)], "status": "verified"}, f"Phase-3 {criterion_id} mismatch")
    common.require(observed == set(CRITERIA), "Phase-3 criterion set incomplete")

    release_id, candidate_sha = common.validate_candidate_pointer(
        evidence_source_sha=evidence_source,
        candidate_source_sha=aggregate["candidate_source_commit_sha"],
        release_id=aggregate["release_id"],
        load_blob=load_blob,
        is_ancestor=is_ancestor,
    )
    evidence = common.require_exact_keys(aggregate["evidence"], {"flow", "production_auth_identity", "capability_gates", "raw_verifier"}, "Phase-3 evidence")
    flow, _ = common.validate_reference(evidence["flow"], source_sha=evidence_source, expected_contract=FLOW_CONTRACT, context="OAuth flow", load_blob=load_blob)
    auth, auth_path = common.validate_reference(evidence["production_auth_identity"], source_sha=evidence_source, expected_contract=AUTH_CONTRACT, context="production auth identity", load_blob=load_blob)
    capability, capability_path = common.validate_reference(evidence["capability_gates"], source_sha=evidence_source, expected_contract=CAPABILITY_CONTRACT, context="capability gates", load_blob=load_blob)
    common.require(capability_path == "docs/runtime-state/capability-gates.json", "Phase-3 capability path mismatch")
    raw_verifier = common.require_exact_keys(evidence["raw_verifier"], {"path", "sha256"}, "OAuth raw verifier")
    common.require(raw_verifier["path"] == RAW_VERIFIER_PATH, "OAuth raw verifier path mismatch")
    verifier_blob = load_blob(evidence_source, RAW_VERIFIER_PATH)
    common.require(hashlib.sha256(verifier_blob).hexdigest() == common.require_lower_hex(raw_verifier["sha256"], 64, "OAuth raw verifier SHA-256"), "OAuth raw verifier hash mismatch")
    frontend_source_sha = _validate_flow(flow, candidate_sha)
    common.require(
        is_ancestor(frontend_source_sha, evidence_source),
        "OAuth frontend source is not an ancestor of the evidence source",
    )
    _validate_auth(auth, candidate_sha)
    gate = capability.get("gates", {}).get("production_auth_identity", {})
    common.require(gate.get("owner_granted") is True and gate.get("live_verified") is True, "production auth gate is not promoted")
    common.require(gate.get("paid_provider") is False and gate.get("verifier") == AUTH_VERIFIER_PATH, "production auth gate verifier mismatch")
    common.require(str(gate.get("evidence_artifact", "")).replace("\\", "/") == auth_path, "production auth gate evidence path mismatch")
    common.require(str(gate.get("evidence_sha256", "")).lower() == evidence["production_auth_identity"]["sha256"], "production auth gate evidence hash mismatch")
    del release_id
    return common.scorer_result(request)


def main(argv: list[str]) -> int:
    if argv != ["--score-v1"]:
        print("[phase3-oauth-scorer] unsupported invocation", file=sys.stderr)
        return 2
    try:
        request = json.load(sys.stdin)
        result = score_request(request)
    except (ScoreError, json.JSONDecodeError, UnicodeError, OSError) as exc:
        print(f"[phase3-oauth-scorer] rejected: {exc}", file=sys.stderr)
        return 2
    json.dump(result, sys.stdout, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

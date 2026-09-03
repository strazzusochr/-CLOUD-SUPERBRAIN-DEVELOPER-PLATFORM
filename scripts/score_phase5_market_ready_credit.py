#!/usr/bin/env python3
"""Evidence-only scorer for the atomic Phase-5 89 -> 100 I1/I5 slice."""

from __future__ import annotations

import json
import re
import sys
from typing import Any, Callable

try:
    from . import progress_credit_scorer_common as common
except ImportError:  # Direct execution from the repository root.
    import progress_credit_scorer_common as common


SCORER_COMMAND = "python scripts/score_phase5_market_ready_credit.py --score-v1"
AGGREGATE_CONTRACT = "phase5-market-ready-credit-evidence-v1"
I1_CONTRACT = "i1-hosted-candidate-parity-v1"
AUTH_CONTRACT = "production-auth-identity-proof-v1"
CAPABILITY_CONTRACT = "capability-gate-state-v1"
AUTH_VERIFIER = "scripts/verify-production-auth-identity-evidence.ps1"
EXPECTED_SERVICES = {
    "frontend",
    "agent-api",
    "agent-worker",
    "memory-worker",
    "mcp-gateway",
    "llm-gateway",
}
AUTH_TRUE_FIELDS = {
    "hosted_https",
    "real_browser",
    "oauth_start_verified",
    "oauth_scope_exact_read_user_verified",
    "oauth_state_one_time_verified",
    "callback_verified",
    "callback_replay_rejected_verified",
    "session_readback_verified",
    "refresh_verified",
    "refresh_family_replay_rejected_verified",
    "logout_verified",
    "audit_readback_verified",
    "audit_before_credential_verified",
    "refresh_revoked_verified",
    "cookies_cleared_verified",
    "rollback_verified",
    "unauthenticated_me_401_verified",
    "cookie_policy_verified",
    "owner_numeric_id_allowlist_verified",
    "source_parity_verified",
    "request_session_audit_correlation_verified",
    "redaction_verified",
    "branch_protection_verified",
    "secret_scan_verified",
    "live_github_oauth_call",
}
AUTH_FALSE_FIELDS = {"dev_only", "secret_output", "gate_promotion_performed", "verifier_mutations_performed"}

ScoreError = common.ScoreError


def _validate_i1(proof: dict[str, Any], release_id: str, candidate_sha: str) -> None:
    common.require(proof.get("contract_version") == I1_CONTRACT and proof.get("status") == "verified", "I1 proof is not verified")
    common.require(proof.get("release_id") == release_id and proof.get("source_commit_sha") == candidate_sha, "I1 candidate binding mismatch")
    base_url = proof.get("base_url")
    common.require(isinstance(base_url, str) and re.fullmatch(r"https://[^\s/]+", base_url) is not None, "I1 origin must be non-local HTTPS")
    common.require("localhost" not in base_url.lower() and "127.0.0.1" not in base_url, "I1 origin may not be local")
    hosting = proof.get("hosting")
    common.require(isinstance(hosting, dict) and hosting.get("provider") in {"github_codespaces", "cloudflare_named_tunnel"}, "I1 hosting provider mismatch")
    for key in ("registry_digest_readback_verified", "runtime_image_identity_verified", "oci_source_revision_verified", "same_origin_https_verified", "sse_verified", "digest_only_compose_verified", "source_bind_mounts_absent", "builds_absent"):
        common.require(proof.get(key) is True, f"I1 {key} is not verified")
    for key in ("live_provider_calls", "registry_write_performed", "production_deploy", "release_promotion", "secret_output"):
        common.require(proof.get(key) is False, f"I1 {key} must be false")
    images = proof.get("images")
    common.require(proof.get("service_count") == 6 and isinstance(images, list) and len(images) == 6, "I1 service count mismatch")
    seen: set[str] = set()
    for image in images:
        common.require(isinstance(image, dict), "I1 image entry is invalid")
        service = image.get("service")
        common.require(service in EXPECTED_SERVICES and service not in seen, "I1 service set mismatch")
        seen.add(str(service))
        for key in ("top_digest", "amd64_manifest_digest", "config_digest", "runtime_image_id"):
            common.require(re.fullmatch(r"sha256:[0-9a-f]{64}", str(image.get(key, ""))) is not None, f"I1 {service} {key} is invalid")
        common.require(image.get("runtime_image_id") == image.get("config_digest"), f"I1 {service} runtime identity mismatch")
        common.require(image.get("oci_revision") == candidate_sha, f"I1 {service} OCI revision mismatch")
        common.require(image.get("source_bind_mount_count") == 0, f"I1 {service} source bind mount detected")
        common.require(image.get("running") is True and image.get("healthy") is True, f"I1 {service} is not healthy")
    common.require(seen == EXPECTED_SERVICES, "I1 service set incomplete")


def _validate_auth(proof: dict[str, Any], candidate_sha: str) -> str:
    common.require(proof.get("contract_version") == AUTH_CONTRACT and proof.get("status") == "verified", "production auth proof is not verified")
    common.require(proof.get("oauth_scope") == "read:user", "production auth OAuth scope mismatch")
    expected_steps = [
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
    common.require(proof.get("human_flow_verified_steps") == expected_steps, "production auth human-flow sequence mismatch")
    for key in AUTH_TRUE_FIELDS:
        common.require(proof.get(key) is True, f"production auth {key} is not verified")
    for key in AUTH_FALSE_FIELDS:
        common.require(proof.get(key) is False, f"production auth {key} must be false")
    binding = proof.get("source_binding")
    common.require(isinstance(binding, dict), "production auth source binding missing")
    for key in ("source_commit_sha", "auth_runtime_source_commit_sha"):
        common.require(binding.get(key) == candidate_sha, f"production auth {key} mismatch")
    frontend_source_sha = common.require_lower_hex(
        binding.get("frontend_source_commit_sha"), 40, "production auth frontend source SHA"
    )
    common.require(binding.get("immutable_frontend_deployment_verified") is True, "production auth frontend deployment is not immutable")
    common.require(binding.get("immutable_auth_runtime_deployment_verified") is True, "production auth runtime deployment is not immutable")
    callback_origin = binding.get("callback_origin")
    common.require(isinstance(callback_origin, str) and re.fullmatch(r"https://[^\s/]+", callback_origin) is not None, "production auth callback origin mismatch")
    common.require(binding.get("callback_url") == f"{callback_origin}/api/v1/auth/callback", "production auth callback URL mismatch")
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
        cell_id="phase_5",
        old_percent=89,
        new_percent=100,
        load_blob=load_blob,
    )
    common.require(re.fullmatch(r"docs/release-artifacts/[^/]+-evidence/phase5/phase5-market-ready-credit-evidence\.json", artifact_path) is not None, "unexpected Phase-5 aggregate path")
    expected_keys = {
        "contract_version", "status", "scope", "cell_id", "old_percent", "new_percent", "percent_delta",
        "credit_eligible", "release_id", "candidate_source_commit_sha", "verified_item_ids", "evidence", "claims",
        "live_provider_calls_verified", "provider_writes", "registry_write_performed", "production_deploy",
        "release_promotion", "secret_output",
    }
    common.require_exact_keys(aggregate, expected_keys, "Phase-5 aggregate")
    common.require(aggregate["contract_version"] == AGGREGATE_CONTRACT and aggregate["status"] == "verified", "Phase-5 aggregate is not verified")
    common.require(aggregate["scope"] == "horizontal" and aggregate["cell_id"] == "phase_5", "Phase-5 aggregate cell mismatch")
    common.require((aggregate["old_percent"], aggregate["new_percent"], aggregate["percent_delta"]) == (89, 100, 11), "Phase-5 transition mismatch")
    common.require(aggregate["credit_eligible"] is True and aggregate["verified_item_ids"] == ["I1", "I5"], "Phase-5 item credit mismatch")
    claims = common.require_exact_keys(aggregate["claims"], {"hosted_candidate_parity_verified", "production_auth_identity_verified", "verified_item_count"}, "Phase-5 claims")
    common.require(claims == {"hosted_candidate_parity_verified": True, "production_auth_identity_verified": True, "verified_item_count": 2}, "Phase-5 claims mismatch")
    common.require(aggregate["live_provider_calls_verified"] is True, "Phase-5 OAuth provider call is not verified")
    for key in ("provider_writes", "registry_write_performed", "production_deploy", "release_promotion", "secret_output"):
        common.require(aggregate[key] is False, f"Phase-5 aggregate {key} must be false")

    release_id, candidate_sha = common.validate_candidate_pointer(
        evidence_source_sha=evidence_source,
        candidate_source_sha=aggregate["candidate_source_commit_sha"],
        release_id=aggregate["release_id"],
        load_blob=load_blob,
        is_ancestor=is_ancestor,
    )
    evidence = common.require_exact_keys(aggregate["evidence"], {"hosted_candidate_parity", "production_auth_identity", "capability_gates"}, "Phase-5 evidence")
    i1, i1_path = common.validate_reference(evidence["hosted_candidate_parity"], source_sha=evidence_source, expected_contract=I1_CONTRACT, context="I1 proof", load_blob=load_blob)
    auth, auth_path = common.validate_reference(evidence["production_auth_identity"], source_sha=evidence_source, expected_contract=AUTH_CONTRACT, context="production auth proof", load_blob=load_blob)
    capability, capability_path = common.validate_reference(evidence["capability_gates"], source_sha=evidence_source, expected_contract=CAPABILITY_CONTRACT, context="capability gates", load_blob=load_blob)
    common.require(capability_path == "docs/runtime-state/capability-gates.json", "Phase-5 capability path mismatch")
    _validate_i1(i1, release_id, candidate_sha)
    frontend_source_sha = _validate_auth(auth, candidate_sha)
    common.require(
        is_ancestor(frontend_source_sha, evidence_source),
        "production auth frontend source is not an ancestor of the evidence source",
    )
    gate = capability.get("gates", {}).get("production_auth_identity", {})
    common.require(gate.get("owner_granted") is True and gate.get("live_verified") is True, "production auth gate is not promoted")
    common.require(gate.get("paid_provider") is False, "production auth gate is not free-only")
    common.require(isinstance(gate.get("owner_grant_ref"), str) and gate["owner_grant_ref"].strip(), "production auth gate Owner reference missing")
    common.require(gate.get("verifier") == AUTH_VERIFIER, "production auth gate verifier mismatch")
    common.require(str(gate.get("evidence_artifact", "")).replace("\\", "/") == auth_path, "production auth gate evidence path mismatch")
    common.require(str(gate.get("evidence_sha256", "")).lower() == evidence["production_auth_identity"]["sha256"], "production auth gate evidence hash mismatch")
    common.require(i1_path != auth_path, "Phase-5 I1 and I5 evidence may not alias")
    return common.scorer_result(request)


def main(argv: list[str]) -> int:
    if argv != ["--score-v1"]:
        print("[phase5-market-ready-scorer] unsupported invocation", file=sys.stderr)
        return 2
    try:
        request = json.load(sys.stdin)
        result = score_request(request)
    except (ScoreError, json.JSONDecodeError, UnicodeError, OSError) as exc:
        print(f"[phase5-market-ready-scorer] rejected: {exc}", file=sys.stderr)
        return 2
    json.dump(result, sys.stdout, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

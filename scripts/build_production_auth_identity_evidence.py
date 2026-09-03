#!/usr/bin/env python3
"""Build the immutable production-auth identity proof from sanitized live receipts."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any, Mapping, Sequence

from score_phase3_oauth_credit import STEP_NAMES, _validate_flow


CONTRACT_VERSION = "production-auth-identity-proof-v1"
CI_CONTRACT = "exact-head-ci-attestation-v1"


class EvidenceError(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise EvidenceError(message)


def read_json(path: Path, label: str) -> tuple[dict[str, Any], bytes]:
    require(path.is_file(), f"{label} is missing")
    try:
        raw = path.read_bytes()
        value = json.loads(raw.decode("utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise EvidenceError(f"{label} is not valid UTF-8 JSON") from exc
    require(isinstance(value, dict), f"{label} must be an object")
    return value, raw


def file_ref(path: Path) -> str:
    resolved = path.resolve()
    root = Path(__file__).resolve().parents[1]
    try:
        relative = resolved.relative_to(root).as_posix()
    except ValueError as exc:
        raise EvidenceError("evidence input must stay inside the repository") from exc
    require(".." not in Path(relative).parts, "evidence input path is unsafe")
    return relative


def hash_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def validate_ci(ci: Mapping[str, Any], candidate_sha: str) -> None:
    require(ci.get("contract_version") == CI_CONTRACT and ci.get("status") == "verified", "exact-head CI attestation is not verified")
    require(ci.get("source_commit_sha") == candidate_sha, "exact-head CI source mismatch")
    require(type(ci.get("run_id")) is int and ci["run_id"] > 0, "exact-head CI run id is invalid")
    require(ci.get("run_attempt") == 1, "exact-head CI must use run attempt one")
    require(ci.get("failed_job_count") == 0 and ci.get("skipped_job_count") == 0, "exact-head CI contains failed or skipped jobs")
    for key in ("required_checks_passed", "branch_protection_verified", "secret_scan_verified", "oauth_regression_verified"):
        require(ci.get(key) is True, f"exact-head CI {key} is not verified")
    require(ci.get("secret_output") is False, "exact-head CI attestation exposed a secret")


def build_evidence(
    *,
    candidate_sha: str,
    flow_path: Path,
    runtime_path: Path,
    frontend_path: Path,
    architecture_path: Path,
    ci_path: Path,
) -> dict[str, Any]:
    require(re.fullmatch(r"[0-9a-f]{40}", candidate_sha) is not None, "candidate SHA must be lowercase 40-hex")
    flow, _ = read_json(flow_path, "OAuth flow evidence")
    runtime, runtime_raw = read_json(runtime_path, "OAuth runtime evidence")
    frontend, frontend_raw = read_json(frontend_path, "frontend hosted evidence")
    architecture, architecture_raw = read_json(architecture_path, "production auth architecture decision")
    ci, _ = read_json(ci_path, "exact-head CI attestation")
    frontend_source_sha = _validate_flow(flow, candidate_sha)
    validate_ci(ci, candidate_sha)

    require(runtime.get("contract_version") == "cloudflare-oauth-hosted-current-v1", "OAuth runtime contract mismatch")
    require(runtime.get("status") == "verified" and runtime.get("architecture") == "cloudflare_native", "OAuth runtime is not verified")
    require(runtime.get("source_commit_sha") == candidate_sha, "OAuth runtime source mismatch")
    require(isinstance(runtime.get("deployment_id"), str) and runtime["deployment_id"], "OAuth runtime deployment id missing")
    require(runtime.get("provider_writes") is False and runtime.get("deployment_writes") is False and runtime.get("secret_output") is False, "OAuth runtime evidence crossed a write/secret boundary")

    require(frontend.get("contract_version") == "frontend-hosted-current-proof-v1" and frontend.get("status") == "verified", "frontend hosted evidence is not verified")
    require(frontend.get("source_commit_sha") == frontend_source_sha, "frontend hosted source mismatch")
    require(frontend.get("vercel_target") == "production", "production auth requires the canonical production frontend target")
    require(frontend.get("deployment_metadata_verified") is True and frontend.get("deployment_alias_content_parity") is True, "frontend deployment parity is not verified")
    require(frontend.get("production_operational_deploy_verified") is True and frontend.get("production_release_claimed") is False, "frontend production operational evidence mismatch")
    frontend_origin = frontend.get("production_alias")
    require(isinstance(frontend_origin, str) and re.fullmatch(r"https://[^\s/]+\.vercel\.app", frontend_origin) is not None, "canonical frontend origin is invalid")
    require(isinstance(frontend.get("deployment_id"), str) and frontend["deployment_id"], "frontend deployment id missing")

    require(architecture.get("contract_version") == "production-auth-architecture-decision-v1", "production auth ADR contract mismatch")
    require(architecture.get("status") == "owner_approved" and architecture.get("owner_approved") is True, "production auth ADR is not Owner-approved")
    require(architecture.get("selected_architecture") == "cloudflare_native" and architecture.get("target") == "production", "production auth ADR selection mismatch")
    require(architecture.get("callback_origin") == frontend_origin and architecture.get("source_commit_sha") == candidate_sha, "production auth ADR source/origin mismatch")
    require(architecture.get("auth_runtime_evidence_ref") == file_ref(runtime_path), "production auth ADR runtime evidence mismatch")
    require(architecture.get("auth_runtime_verifier_ref") == "scripts/verify-cloudflare-oauth-hosted-current.ps1", "production auth ADR verifier mismatch")
    require(architecture.get("secret_output") is False, "production auth ADR exposed a secret")

    binding = flow.get("source_binding")
    execution = flow.get("execution")
    require(isinstance(binding, dict) and binding.get("frontend_origin") == frontend_origin, "OAuth flow canonical frontend origin mismatch")
    require(binding.get("worker_origin") == runtime.get("runtime_origin"), "OAuth flow Worker origin mismatch")
    require(binding.get("callback_url") == f"{frontend_origin}/api/v1/auth/callback", "OAuth flow callback mismatch")
    require(hashlib.sha256(str(frontend["deployment_id"]).encode()).hexdigest() == binding.get("frontend_deployment_id_sha256"), "OAuth flow frontend deployment binding mismatch")
    require(hashlib.sha256(str(runtime["deployment_id"]).encode()).hexdigest() == binding.get("worker_deployment_id_sha256"), "OAuth flow Worker deployment binding mismatch")
    require(isinstance(execution, dict) and execution.get("provider_call_count") == 2, "OAuth flow provider call count mismatch")

    evidence: dict[str, Any] = {
        "contract_version": CONTRACT_VERSION,
        "status": "verified",
        "oauth_scope": "read:user",
        "human_flow_verified_steps": list(STEP_NAMES),
        "source_binding": {
            "source_commit_sha": candidate_sha,
            "frontend_source_commit_sha": frontend_source_sha,
            "auth_runtime_source_commit_sha": candidate_sha,
            "deployment_id": runtime["deployment_id"],
            "frontend_deployment_id": frontend["deployment_id"],
            "auth_runtime_deployment_id": runtime["deployment_id"],
            "immutable_frontend_deployment_verified": True,
            "immutable_auth_runtime_deployment_verified": True,
            "frontend_origin_evidence_ref": file_ref(frontend_path),
            "frontend_origin_evidence_sha256": hash_bytes(frontend_raw),
            "owner_architecture_decision_ref": file_ref(architecture_path),
            "owner_architecture_decision_sha256": hash_bytes(architecture_raw),
            "auth_runtime_evidence_ref": file_ref(runtime_path),
            "auth_runtime_evidence_sha256": hash_bytes(runtime_raw),
            "callback_origin": frontend_origin,
            "callback_url": f"{frontend_origin}/api/v1/auth/callback",
        },
    }
    true_fields = (
        "hosted_https", "real_browser", "oauth_start_verified", "oauth_scope_exact_read_user_verified",
        "oauth_state_one_time_verified", "callback_verified", "callback_replay_rejected_verified",
        "session_readback_verified", "refresh_verified", "refresh_family_replay_rejected_verified",
        "logout_verified", "audit_readback_verified", "audit_before_credential_verified",
        "refresh_revoked_verified", "cookies_cleared_verified", "rollback_verified",
        "unauthenticated_me_401_verified", "cookie_policy_verified", "owner_numeric_id_allowlist_verified",
        "source_parity_verified", "request_session_audit_correlation_verified", "redaction_verified",
        "branch_protection_verified", "secret_scan_verified", "live_github_oauth_call",
    )
    evidence.update({key: True for key in true_fields})
    evidence.update({
        "dev_only": False,
        "secret_output": False,
        "gate_promotion_performed": False,
        "verifier_mutations_performed": False,
    })
    return evidence


def write_exclusive(path: Path, value: Mapping[str, Any]) -> None:
    require(path.parent.is_dir(), "production auth output parent must already exist")
    try:
        with path.open("x", encoding="utf-8", newline="\n") as handle:
            json.dump(value, handle, indent=2, sort_keys=True, ensure_ascii=True)
            handle.write("\n")
    except FileExistsError as exc:
        raise EvidenceError("production auth output already exists; immutable evidence is never overwritten") from exc


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate-sha", required=True)
    parser.add_argument("--flow", type=Path, required=True)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--frontend", type=Path, required=True)
    parser.add_argument("--architecture-decision", type=Path, required=True)
    parser.add_argument("--ci-attestation", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        value = build_evidence(
            candidate_sha=args.candidate_sha,
            flow_path=args.flow,
            runtime_path=args.runtime,
            frontend_path=args.frontend,
            architecture_path=args.architecture_decision,
            ci_path=args.ci_attestation,
        )
        write_exclusive(args.output, value)
    except (EvidenceError, ValueError, OSError) as exc:
        print(f"[production-auth-evidence-builder] ERROR: {exc}", file=sys.stderr)
        return 1
    print("[production-auth-evidence-builder] PASS status=verified live_oauth_calls=2 gate_promotion=false secret_output=false")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

from __future__ import annotations

import copy
import hashlib
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
VERIFIER = REPO_ROOT / "scripts" / "verify-cloudflare-oauth-hosted-current.ps1"

RUNTIME_REF = "docs/runtime-state/cloudflare-oauth-hosted-current.json"
FLOW_REF = "docs/runtime-state/cloudflare-oauth-hosted-current-flow.json"
FRONTEND_REF = "docs/runtime-state/frontend-hosted-current.json"
OWNER_REF = "docs/runtime-state/cloudflare-oauth-hosted-candidate-architecture-approval.json"
CONSENT_REF = "docs/runtime-state/cloudflare-oauth-hosted-candidate-consent-approval.json"
BROWSER_REF = "evidence/oauth-browser-sanitized.json"
D1_REF = "evidence/oauth-d1-sanitized.json"
AUDIT_REF = "evidence/oauth-audit-sanitized.json"
BROWSER_SCORER_REF = "evidence/oauth-browser-scorer.json"
D1_SCORER_REF = "evidence/oauth-d1-scorer.json"
AUDIT_SCORER_REF = "evidence/oauth-audit-scorer.json"

FRONTEND_ORIGIN = "https://frontend-fixture.vercel.app"
IMMUTABLE_FRONTEND_ORIGIN = "https://frontend-immutable-fixture.vercel.app"
WORKER_ORIGIN = "https://auth-fixture.example.workers.dev"
FRONTEND_DEPLOYMENT_ID = "frontend-deployment-fixture"
WORKER_DEPLOYMENT_ID = "worker-deployment-fixture"
WORKER_ARCHIVE_SHA = "a" * 64
SESSION_A_SHA = hashlib.sha256(b"sanitized-session-correlation-family-a").hexdigest()
SESSION_B_SHA = hashlib.sha256(b"sanitized-session-correlation-family-b").hexdigest()
FAMILY_A_SHA = hashlib.sha256(b"refresh-family-a").hexdigest()
FAMILY_B_SHA = hashlib.sha256(b"refresh-family-b").hexdigest()

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

STEP_CONTRACT = [
    ("browser", "navigate_login_and_read_auth_me", 401, "unauthenticated", False, False, False),
    ("browser_d1", "click_github_sign_in", 303, "redirected_exact_scope", True, False, False),
    ("browser_d1_audit", "click_github_cancel", 401, "denied_no_credentials_state_consumed", True, False, True),
    ("browser", "click_github_authorize", 200, "owner_consent_recorded", False, False, False),
    ("browser_d1_audit", "follow_callback_redirect", 303, "identity_verified_credentials_issued", True, True, True),
    ("browser", "read_auth_me", 200, "identity_readback_verified", False, False, False),
    ("browser", "reload_authenticated_page", 200, "session_continuity_verified", False, False, False),
    ("browser_d1_audit", "click_refresh_action", 200, "refresh_rotated_once", True, True, True),
    ("browser_d1_audit", "replay_previous_refresh_via_browser_action", 401, "replay_401_family_revoked", True, False, True),
    ("browser_d1_audit", "replay_consumed_callback_via_browser_action", 401, "callback_replay_401_no_credentials", True, False, True),
    ("browser_d1_audit", "click_logout_action", 200, "one_active_refresh_revoked_audited", True, False, True),
    ("browser_d1", "click_refresh_after_logout", 401, "refresh_401_revoked", True, False, False),
]

D1_STEPS = [
    "github_start_exact_query",
    "github_cancel_no_credentials",
    "callback_one_time_state",
    "refresh_atomic_rotation",
    "old_refresh_replay_rejected",
    "callback_replay_rejected",
    "logout_revocation_audited",
    "post_logout_refresh_rejected",
]

AUDIT_CONTRACT = [
    ("github_cancel_no_credentials", "auth_github_callback_blocked"),
    ("callback_one_time_state", "auth_github_callback_verified"),
    ("refresh_atomic_rotation", "auth_refresh_rotated"),
    ("old_refresh_replay_rejected", "auth_refresh_reuse_blocked"),
    ("callback_replay_rejected", "auth_github_callback_blocked"),
    ("logout_revocation_audited", "auth_logout_revoked"),
]

FACT_CODES = {
    "browser": {
        "anonymous_login_no_identity": ["human_navigation", "auth_me_http_401", "identity_projection_absent"],
        "github_start_exact_query": ["human_click", "github_redirect_http_303", "oauth_scope_exact_read_user"],
        "github_cancel_no_credentials": ["human_click", "provider_cancel_http_401", "credential_issue_count_0"],
        "github_authorize_owner_identity": ["human_click", "owner_consent_visible", "numeric_identity_only_hashed"],
        "callback_one_time_state": ["callback_http_303", "one_time_state_consumed", "credential_issue_count_1"],
        "auth_me_verified_identity": ["auth_me_http_200", "jwt_claims_verified", "numeric_identity_only_hashed"],
        "reload_session_continuity": ["human_reload", "auth_me_http_200", "session_hash_stable"],
        "refresh_atomic_rotation": ["human_click", "refresh_http_200", "credential_issue_count_1"],
        "old_refresh_replay_rejected": ["human_click", "refresh_replay_http_401", "credential_issue_count_0"],
        "callback_replay_rejected": ["human_click", "callback_replay_http_401", "credential_issue_count_0"],
        "logout_revocation_audited": ["human_click", "logout_http_200", "credential_issue_count_0"],
        "post_logout_refresh_rejected": ["human_click", "post_logout_refresh_http_401", "credential_issue_count_0"],
    },
    "d1_readback": {
        "github_start_exact_query": ["oauth_state_insert_count_1", "pending_state_count_1"],
        "github_cancel_no_credentials": ["oauth_state_delete_count_1", "credential_row_delta_0"],
        "callback_one_time_state": ["oauth_state_delete_count_1", "refresh_family_insert_count_1", "audit_before_credential_sequence"],
        "refresh_atomic_rotation": ["serialized_compare_and_swap", "parallel_attempt_count_2", "rotation_success_count_1", "rotation_reject_count_1", "history_insert_count_1", "active_refresh_count_1"],
        "old_refresh_replay_rejected": ["family_revocation_count_1", "active_refresh_count_0", "refresh_replay_http_401"],
        "callback_replay_rejected": ["oauth_state_count_0", "credential_row_delta_0", "callback_replay_http_401"],
        "logout_revocation_audited": ["active_refresh_count_1_to_0", "revoked_history_insert_count_1"],
        "post_logout_refresh_rejected": ["active_refresh_count_0", "credential_row_delta_0", "post_logout_refresh_http_401"],
    },
    "audit_readback": {
        step: ["audit_row_count_1", "event_type_exact", "request_hash_match", "session_hash_match_or_preauth", "sensitive_field_count_0", "persisted_before_credential_boundary"]
        for step, _ in AUDIT_CONTRACT
    },
}

SCORER_REFS = {
    "browser": BROWSER_SCORER_REF,
    "d1_readback": D1_SCORER_REF,
    "audit_readback": AUDIT_SCORER_REF,
}


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_text(value: str) -> str:
    return sha256_bytes(value.encode("utf-8"))


def json_bytes(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")


def observation_fact_sha256(observations: list[dict[str, object]]) -> str:
    lines = []
    for observation in observations:
        lines.append(
            "|".join(
                (
                    str(observation["sequence"]),
                    str(observation["step"]),
                    str(observation["http_status"]),
                    ",".join(str(value) for value in observation["fact_codes"]),
                    str(observation["request_correlation_sha256"]),
                    str(observation["session_correlation_sha256"] or ""),
                    str(observation["source_record_sha256"]),
                )
            )
        )
    return sha256_text("\n".join(lines))


def session_sha_for_step_index(step_index: int) -> str | None:
    if step_index < 4:
        return None
    if step_index < 10:
        return SESSION_A_SHA
    return SESSION_B_SHA


class CloudflareOauthHostedCurrentTests(unittest.TestCase):
    def git(self, root: Path, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["git", *args], cwd=root, check=True, capture_output=True, text=True
        )

    def commit_all(self, root: Path, message: str) -> None:
        self.git(root, "add", "scripts", "docs", "evidence")
        self.git(root, "commit", "--quiet", "-m", message)

    def write_json(self, root: Path, relative: str, value: object) -> bytes:
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        payload = json_bytes(value)
        path.write_bytes(payload)
        return payload

    def make_repo(
        self, target: str = "production"
    ) -> tuple[tempfile.TemporaryDirectory[str], Path, str]:
        directory = tempfile.TemporaryDirectory()
        root = Path(directory.name)
        (root / "scripts").mkdir(parents=True)
        shutil.copy2(VERIFIER, root / "scripts" / VERIFIER.name)

        self.git(root, "init", "--quiet")
        self.git(root, "config", "user.email", "oauth-verifier@example.invalid")
        self.git(root, "config", "user.name", "OAuth Verifier Test")
        (root / "frontend-source.txt").write_text(
            "existing canonical frontend source\n", encoding="utf-8"
        )
        self.git(root, "add", "frontend-source.txt")
        self.git(root, "commit", "--quiet", "-m", "frontend source")
        frontend_source_sha = self.git(root, "rev-parse", "HEAD").stdout.strip()
        (root / "candidate-source.txt").write_text(
            "immutable OAuth candidate source\n", encoding="utf-8"
        )
        self.git(root, "add", "candidate-source.txt")
        self.git(root, "commit", "--quiet", "-m", "candidate source")
        candidate_sha = self.git(root, "rev-parse", "HEAD").stdout.strip()

        runtime = {
            "contract_version": "cloudflare-oauth-hosted-current-v1",
            "status": "verified",
            "architecture": "cloudflare_native",
            "source_commit_sha": candidate_sha,
            "deployment_id": WORKER_DEPLOYMENT_ID,
            "runtime_origin": WORKER_ORIGIN,
            "provider_writes": False,
            "deployment_writes": False,
            "secret_output": False,
        }
        runtime_payload = self.write_json(root, RUNTIME_REF, runtime)

        frontend = {
            "contract_version": "frontend-hosted-current-proof-v1",
            "status": "verified",
            "source_commit_sha": frontend_source_sha,
            "deployment_id": FRONTEND_DEPLOYMENT_ID,
            "immutable_deployment_url": IMMUTABLE_FRONTEND_ORIGIN,
            "production_alias": FRONTEND_ORIGIN,
            "vercel_target": "production",
            "deployment_metadata_verified": True,
            "deployment_alias_content_parity": True,
            "production_operational_deploy_verified": True,
            "production_release_claimed": False,
        }
        frontend_payload = self.write_json(root, FRONTEND_REF, frontend)

        owner = {
            "contract_version": "cloudflare-oauth-hosted-candidate-architecture-approval-v1",
            "status": "owner_approved",
            "owner_approved": True,
            "selected_architecture": "cloudflare_native",
            "target": target,
            "callback_origin": FRONTEND_ORIGIN,
            "source_commit_sha": candidate_sha,
            "auth_runtime_evidence_ref": RUNTIME_REF,
            "auth_runtime_verifier_ref": "scripts/verify-cloudflare-oauth-hosted-current.ps1",
            "secret_output": False,
        }
        owner_payload = self.write_json(root, OWNER_REF, owner)

        consent = {
            "contract_version": "cloudflare-oauth-hosted-candidate-consent-approval-v1",
            "status": "owner_approved",
            "owner_approved": True,
            "source_commit_sha": candidate_sha,
            "target": target,
            "architecture": "cloudflare_native",
            "oauth_scope": "read:user",
            "frontend_origin": FRONTEND_ORIGIN,
            "worker_origin": WORKER_ORIGIN,
            "real_provider_consent_approved": True,
            "approved_at": "2026-08-30T10:00:00Z",
            "secret_output": False,
        }
        consent_payload = self.write_json(root, CONSENT_REF, consent)

        request_hashes = [sha256_text(f"request-correlation-{index}") for index in range(1, 13)]
        frontend_deployment_hash = sha256_text(FRONTEND_DEPLOYMENT_ID)
        worker_deployment_hash = sha256_text(WORKER_DEPLOYMENT_ID)
        sensitive_hash_bindings = {
            "provider_user_id_sha256": sha256_text("provider-user-id"),
            "subject_sha256": sha256_text("provider-subject"),
            "oauth_code_sha256": sha256_text("one-time-oauth-code"),
            "oauth_state_sha256": sha256_text("one-time-oauth-state"),
            "access_token_sha256": sha256_text("access-cookie-value"),
            "refresh_token_before_sha256": sha256_text("refresh-before"),
            "refresh_token_after_sha256": sha256_text("refresh-after"),
            "cookie_bundle_sha256": sha256_text("sanitized-cookie-bundle"),
        }
        covered_by_kind = {
            "browser": STEP_NAMES,
            "d1_readback": D1_STEPS,
            "audit_readback": [step for step, _ in AUDIT_CONTRACT],
        }
        audit_events = list(dict.fromkeys(event for _, event in AUDIT_CONTRACT))
        artifact_refs = {
            "browser": BROWSER_REF,
            "d1_readback": D1_REF,
            "audit_readback": AUDIT_REF,
        }
        artifact_payloads: dict[str, bytes] = {}
        artifact_observations: dict[str, list[dict[str, object]]] = {}
        for kind, covered in covered_by_kind.items():
            covered_requests = [request_hashes[STEP_NAMES.index(step)] for step in covered]
            observations = []
            for step in covered:
                step_index = STEP_NAMES.index(step)
                observations.append(
                    {
                        "sequence": step_index + 1,
                        "step": step,
                        "http_status": STEP_CONTRACT[step_index][2],
                        "fact_codes": FACT_CODES[kind][step],
                        "request_correlation_sha256": request_hashes[step_index],
                        "session_correlation_sha256": session_sha_for_step_index(step_index),
                        "source_record_sha256": sha256_text(f"raw-derived-{kind}-{step}"),
                    }
                )
            artifact_observations[kind] = observations
            artifact = {
                "contract_version": "cloudflare-oauth-sanitized-observation-artifact-v2",
                "status": "raw_derived_sanitized",
                "artifact_kind": kind,
                "candidate_source_commit_sha": candidate_sha,
                "frontend_deployment_id_sha256": frontend_deployment_hash,
                "worker_deployment_id_sha256": worker_deployment_hash,
                "covered_steps": covered,
                "request_correlation_sha256s": covered_requests,
                "session_correlation_sha256s": list(
                    dict.fromkeys(
                        session_sha_for_step_index(STEP_NAMES.index(step))
                        for step in covered
                        if session_sha_for_step_index(STEP_NAMES.index(step)) is not None
                    )
                ),
                "audit_event_types": audit_events if kind == "audit_readback" else [],
                "generated_at": "2026-08-30T10:05:00Z",
                "raw_capture_sha256": sha256_text(f"ephemeral-raw-capture-{kind}"),
                "redaction_manifest_sha256": sha256_text(f"redaction-manifest-{kind}"),
                "sensitive_value_sha256s": (
                    list(sensitive_hash_bindings.values())
                    if kind == "browser"
                    else [
                        sensitive_hash_bindings[key]
                        for key in (
                            "subject_sha256",
                            "oauth_state_sha256",
                            "refresh_token_before_sha256",
                            "refresh_token_after_sha256",
                        )
                    ]
                    if kind == "d1_readback"
                    else [
                        sensitive_hash_bindings["provider_user_id_sha256"],
                        sensitive_hash_bindings["subject_sha256"],
                    ]
                ),
                "observations": observations,
                "secret_value_count": 0,
            }
            artifact_payloads[kind] = self.write_json(root, artifact_refs[kind], artifact)
        artifact_hashes = {
            kind: sha256_bytes(payload) for kind, payload in artifact_payloads.items()
        }

        scorer_payloads: dict[str, bytes] = {}
        verifier_sha = sha256_bytes((root / "scripts" / VERIFIER.name).read_bytes())
        for kind in ("browser", "d1_readback", "audit_readback"):
            scorer = {
                "contract_version": "cloudflare-oauth-sanitized-scorer-output-v1",
                "status": "computed",
                "scorer_kind": kind,
                "candidate_source_commit_sha": candidate_sha,
                "input_artifact_ref": artifact_refs[kind],
                "input_artifact_sha256": artifact_hashes[kind],
                "scorer_implementation_ref": "scripts/verify-cloudflare-oauth-hosted-current.ps1",
                "scorer_implementation_sha256": verifier_sha,
                "computed_fact_sha256": observation_fact_sha256(artifact_observations[kind]),
                "record_count": len(artifact_observations[kind]),
                "failed_record_count": 0,
                "scored_at": "2026-08-30T10:06:00Z",
                "secret_value_count": 0,
            }
            scorer_payloads[kind] = self.write_json(root, SCORER_REFS[kind], scorer)
        scorer_hashes = {
            kind: sha256_bytes(payload) for kind, payload in scorer_payloads.items()
        }

        steps: list[dict[str, object]] = []
        for index, (name, contract) in enumerate(zip(STEP_NAMES, STEP_CONTRACT), start=1):
            surface, action, status, outcome, d1, credentials, audit = contract
            evidence = {
                "browser_ref": BROWSER_REF,
                "browser_sha256": artifact_hashes["browser"],
                "d1_ref": D1_REF if d1 else None,
                "d1_sha256": artifact_hashes["d1_readback"] if d1 else None,
                "audit_ref": AUDIT_REF if audit else None,
                "audit_sha256": artifact_hashes["audit_readback"] if audit else None,
            }
            steps.append(
                {
                    "sequence": index,
                    "name": name,
                    "surface": surface,
                    "action": action,
                    "http_status": status,
                    "outcome": outcome,
                    "human_click_count": 1,
                    "d1_readback_match_count": 1 if d1 else 0,
                    "credential_issue_count": 1 if credentials else 0,
                    "request_correlation_sha256": request_hashes[index - 1],
                    "session_correlation_sha256": session_sha_for_step_index(index - 1),
                    "evidence": evidence,
                    "secret_value_count": 0,
                }
            )

        audits = []
        for step_name, event_type in AUDIT_CONTRACT:
            step = steps[STEP_NAMES.index(step_name)]
            audits.append(
                {
                    "step": step_name,
                    "event_type": event_type,
                    "request_correlation_sha256": step["request_correlation_sha256"],
                    "session_correlation_sha256": step["session_correlation_sha256"],
                    "audit_event_id_sha256": sha256_text(f"audit-event-{step_name}"),
                    "persisted_row_count": 1,
                    "d1_readback_match_count": 1,
                    "persisted_sequence": 1,
                    "credential_boundary_sequence": 2,
                    "evidence_ref": AUDIT_REF,
                    "evidence_sha256": artifact_hashes["audit_readback"],
                    "scorer_ref": AUDIT_SCORER_REF,
                    "scorer_sha256": scorer_hashes["audit_readback"],
                    "sensitive_field_count": 0,
                    "secret_value_count": 0,
                }
            )

        flow = {
            "contract_version": "cloudflare-oauth-hosted-current-flow-v1",
            "status": "evidence_envelope_complete",
            "architecture": "cloudflare_native",
            "source_binding": {
                "candidate_source_commit_sha": candidate_sha,
                "frontend_source_commit_sha": frontend_source_sha,
                "worker_source_commit_sha": candidate_sha,
                "worker_source_archive_sha256": WORKER_ARCHIVE_SHA,
                "frontend_deployment_id_sha256": frontend_deployment_hash,
                "worker_deployment_id_sha256": worker_deployment_hash,
                "frontend_origin": FRONTEND_ORIGIN,
                "worker_origin": WORKER_ORIGIN,
                "callback_url": f"{FRONTEND_ORIGIN}/api/v1/auth/callback",
                "frontend_evidence_ref": FRONTEND_REF,
                "frontend_evidence_sha256": sha256_bytes(frontend_payload),
                "runtime_evidence_sha256": sha256_bytes(runtime_payload),
            },
            "approval_binding": {
                "owner_architecture_decision_ref": OWNER_REF,
                "owner_architecture_decision_sha256": sha256_bytes(owner_payload),
                "live_consent_approval_ref": CONSENT_REF,
                "live_consent_approval_sha256": sha256_bytes(consent_payload),
                "owner_approved_candidate_sha": candidate_sha,
                "approved_oauth_scope": "read:user",
                "approved_callback_origin": FRONTEND_ORIGIN,
                "approved_worker_origin": WORKER_ORIGIN,
            },
            "sensitive_hash_bindings": sensitive_hash_bindings,
            "execution": {
                "target": target,
                "transport": "hosted_https",
                "browser_channel": "chrome",
                "browser_execution": "real_chrome",
                "human_click_count": 12,
                "identity_evidence": "numeric_owner_identity_sha256_only",
                "oauth_scope": "read:user",
                "provider_call_count": 2,
                "provider_write_count": 0,
                "deployment_write_count": 0,
                "localhost_transport_count": 0,
                "owner_interaction": "interactive_consent",
                "started_at": "2026-08-30T10:01:00Z",
                "completed_at": "2026-08-30T10:10:00Z",
            },
            "human_flow_steps": steps,
            "token_families": {
                "contract_version": "cloudflare-oauth-token-families-v1",
                "distinct_family_count": 2,
                "distinct_family_ids_verified": True,
                "families": [
                    {
                        "label": "family_a",
                        "purpose": "refresh_replay",
                        "family_id_sha256": FAMILY_A_SHA,
                        "session_correlation_sha256": SESSION_A_SHA,
                        "issuance_evidence_step": "callback_one_time_state",
                        "terminal_evidence_step": "old_refresh_replay_rejected",
                        "terminal_reason": "token_replay_detected",
                        "terminal_http_status": 401,
                        "credential_issue_after_terminal_count": 0,
                    },
                    {
                        "label": "family_b",
                        "purpose": "logout",
                        "family_id_sha256": FAMILY_B_SHA,
                        "session_correlation_sha256": SESSION_B_SHA,
                        "issuance_evidence_step": "independent_family_b_callback",
                        "terminal_evidence_step": "logout_revocation_audited",
                        "terminal_reason": "user_logout",
                        "terminal_http_status": 200,
                        "credential_issue_after_terminal_count": 0,
                    },
                ],
                "secret_value_count": 0,
            },
            "scorer_outputs": {
                kind: {"ref": SCORER_REFS[kind], "sha256": scorer_hashes[kind]}
                for kind in ("browser", "d1_readback", "audit_readback")
            },
            "atomic_replay_evidence": {
                "rotation_serialization": "durable_object_or_d1_transaction",
                "parallel_attempt_count": 2,
                "successful_rotation_count": 1,
                "rejected_rotation_count": 1,
                "old_refresh_replay_http_status": 401,
                "family_revocation_row_count": 1,
                "replacement_refresh_rejection_count": 1,
                "callback_state_consumption_count": 1,
                "callback_replay_http_status": 401,
                "callback_replay_credential_issue_count": 0,
                "cancel_state_consumption_count": 1,
                "d1_readback_match_count": 8,
                "evidence_ref": D1_REF,
                "evidence_sha256": artifact_hashes["d1_readback"],
                "scorer_ref": D1_SCORER_REF,
                "scorer_sha256": scorer_hashes["d1_readback"],
                "secret_value_count": 0,
            },
            "audit_correlations": audits,
            "redaction": {
                "identity_representation": "sha256_only",
                "sensitive_key_count": 0,
                "sensitive_value_count": 0,
                "artifact_scan_count": 3,
                "log_scan_finding_count": 0,
                "secret_scan_finding_count": 0,
            },
            "gate_transition": {
                "verifier_mutation_count": 0,
                "gate_promotion_count": 0,
                "live_verified_mutation_count": 0,
                "percentage_change_count": 0,
                "production_release_count": 0,
            },
            "non_claims": [
                "no_gate_promotion",
                "no_live_verified_mutation",
                "no_provider_writes",
                "no_deployment_writes",
                "no_secret_output",
                "evidence_envelope_not_full_live_replay",
                "no_production_release",
            ],
        }
        self.write_json(root, FLOW_REF, flow)
        self.commit_all(root, "tracked sanitized OAuth evidence")
        return directory, root, candidate_sha

    def run_verifier(
        self, root: Path, candidate_sha: str, *extra: str
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                "pwsh",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(root / "scripts" / VERIFIER.name),
                "-ExpectedCandidateSha",
                candidate_sha,
                *extra,
            ],
            cwd=root,
            check=False,
            capture_output=True,
            text=True,
        )

    def update_flow(
        self, root: Path, mutate, *, commit: bool = True
    ) -> dict[str, object]:
        path = root / FLOW_REF
        value = json.loads(path.read_text(encoding="utf-8"))
        mutate(value)
        path.write_bytes(json_bytes(value))
        if commit:
            self.commit_all(root, "mutated OAuth evidence fixture")
        return value

    def test_valid_static_evidence_passes_read_only_without_writes(self) -> None:
        directory, root, candidate_sha = self.make_repo()
        with directory:
            before_status = self.git(root, "status", "--porcelain").stdout
            before_files = sorted(
                (path.relative_to(root).as_posix(), sha256_bytes(path.read_bytes()))
                for path in root.rglob("*")
                if path.is_file() and ".git" not in path.parts
            )
            completed = self.run_verifier(root, candidate_sha, "-ValidateOnly")
            after_status = self.git(root, "status", "--porcelain").stdout
            after_files = sorted(
                (path.relative_to(root).as_posix(), sha256_bytes(path.read_bytes()))
                for path in root.rglob("*")
                if path.is_file() and ".git" not in path.parts
            )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertIn("status=verified architecture=cloudflare_native", completed.stdout)
        self.assertIn("exact_human_flow_steps=12 atomic_replay_evidence=scored", completed.stdout)
        self.assertIn(
            "read_only=true source_parity=true proof_scope=production_identity", completed.stdout
        )
        self.assertIn(
            "full_live_proof=false production_release=false gate_promotion_performed=false live_verified_set=false secret_output=false",
            completed.stdout,
        )
        self.assertEqual(before_status, after_status)
        self.assertEqual(before_files, after_files)

    def test_exact_twelve_step_order_and_http_contract_fail_closed(self) -> None:
        directory, root, candidate_sha = self.make_repo()
        with directory:
            self.update_flow(
                root,
                lambda flow: flow["human_flow_steps"].__setitem__(
                    8,
                    {
                        **flow["human_flow_steps"][8],
                        "http_status": 200,
                    },
                ),
            )
            completed = self.run_verifier(root, candidate_sha, "-ValidateOnly")
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("HTTP status mismatch", completed.stderr)

        directory, root, candidate_sha = self.make_repo()
        with directory:
            self.update_flow(
                root,
                lambda flow: flow.__setitem__(
                    "human_flow_steps", list(reversed(flow["human_flow_steps"]))
                ),
            )
            completed = self.run_verifier(root, candidate_sha, "-ValidateOnly")
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("sequence mismatch", completed.stderr)

    def test_source_and_hashed_deployment_parity_fail_closed(self) -> None:
        directory, root, candidate_sha = self.make_repo()
        with directory:
            self.update_flow(
                root,
                lambda flow: flow["source_binding"].__setitem__(
                    "worker_source_commit_sha", "b" * 40
                ),
            )
            completed = self.run_verifier(root, candidate_sha, "-ValidateOnly")
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("worker_source_commit_sha", completed.stderr)

        directory, root, candidate_sha = self.make_repo()
        with directory:
            self.update_flow(
                root,
                lambda flow: flow["source_binding"].__setitem__(
                    "frontend_deployment_id_sha256", "c" * 64
                ),
            )
            completed = self.run_verifier(root, candidate_sha, "-ValidateOnly")
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("Frontend deployment binding mismatch", completed.stderr)

    def test_atomic_rotation_callback_replay_and_cancel_state_fail_closed(self) -> None:
        fields = (
            "family_revocation_row_count",
            "replacement_refresh_rejection_count",
            "callback_state_consumption_count",
            "cancel_state_consumption_count",
            "d1_readback_match_count",
        )
        for field in fields:
            with self.subTest(field=field):
                directory, root, candidate_sha = self.make_repo()
                with directory:
                    self.update_flow(
                        root,
                        lambda flow, field=field: flow["atomic_replay_evidence"].__setitem__(
                            field, 0
                        ),
                    )
                    completed = self.run_verifier(root, candidate_sha, "-ValidateOnly")
                self.assertNotEqual(completed.returncode, 0)
                self.assertIn(field, completed.stderr)

    def test_refresh_replay_and_logout_require_two_distinct_token_families(self) -> None:
        mutations = (
            lambda flow: flow["token_families"]["families"][1].__setitem__(
                "family_id_sha256", FAMILY_A_SHA
            ),
            lambda flow: flow["token_families"]["families"][1].__setitem__(
                "session_correlation_sha256", SESSION_A_SHA
            ),
            lambda flow: flow["human_flow_steps"][10].__setitem__(
                "session_correlation_sha256", SESSION_A_SHA
            ),
        )
        for mutate in mutations:
            directory, root, candidate_sha = self.make_repo()
            with directory:
                self.update_flow(root, mutate)
                completed = self.run_verifier(root, candidate_sha, "-ValidateOnly")
            self.assertNotEqual(completed.returncode, 0)
            self.assertRegex(completed.stderr.lower(), r"famil(?:y|ies)")

    def test_callback_refresh_logout_audit_correlation_fail_closed(self) -> None:
        directory, root, candidate_sha = self.make_repo()
        with directory:
            self.update_flow(
                root,
                lambda flow: flow["audit_correlations"][1].__setitem__(
                    "request_correlation_sha256", "d" * 64
                ),
            )
            completed = self.run_verifier(root, candidate_sha, "-ValidateOnly")
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("request correlation mismatch", completed.stderr)

        directory, root, candidate_sha = self.make_repo()
        with directory:
            self.update_flow(
                root,
                lambda flow: flow["audit_correlations"][5].__setitem__(
                    "persisted_sequence", 3
                ),
            )
            completed = self.run_verifier(root, candidate_sha, "-ValidateOnly")
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("persisted_sequence", completed.stderr)

    def test_raw_identity_token_cookie_state_and_code_values_fail_closed(self) -> None:
        raw_fields = (
            ("provider_user_id", "123456789"),
            ("subject_id", False),
            ("request_id", 0),
            ("session_id", ["hidden-by-type"]),
            ("audit_event_id", None),
            ("opaque_numeric_value", 123456789),
            ("opaque_uuid_value", "123e4567-e89b-42d3-a456-426614174000"),
            ("access_token", "gho_fixtureRawTokenValue123"),
            ("oauth_state", "phase3-auth-state-fixtureRawState123"),
            ("oauth_code", "fixture-code-value"),
            ("cookie", "__Host-sb_refresh=fixtureRawCookieValue"),
        )
        for field, value in raw_fields:
            with self.subTest(field=field):
                directory, root, candidate_sha = self.make_repo()
                with directory:
                    self.update_flow(root, lambda flow, field=field, value=value: flow.__setitem__(field, value))
                    completed = self.run_verifier(root, candidate_sha, "-ValidateOnly")
                self.assertNotEqual(completed.returncode, 0)
                self.assertIn("sensitive evidence key", completed.stderr)

    def test_sensitive_values_require_distinct_sha256_only_counterparts(self) -> None:
        directory, root, candidate_sha = self.make_repo()
        with directory:
            self.update_flow(
                root,
                lambda flow: flow["sensitive_hash_bindings"].__setitem__(
                    "subject_sha256",
                    flow["sensitive_hash_bindings"]["provider_user_id_sha256"],
                ),
            )
            completed = self.run_verifier(root, candidate_sha, "-ValidateOnly")
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("distinct SHA256-only counterpart", completed.stderr)

    def test_dirty_or_untracked_evidence_and_unapproved_hosted_mode_fail_closed(self) -> None:
        directory, root, candidate_sha = self.make_repo()
        with directory:
            self.update_flow(
                root,
                lambda flow: flow["execution"].__setitem__("owner_interaction", "absent"),
                commit=False,
            )
            completed = self.run_verifier(root, candidate_sha, "-ValidateOnly")
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("clean relative to HEAD", completed.stderr)

        directory, root, candidate_sha = self.make_repo()
        with directory:
            completed = self.run_verifier(root, candidate_sha, "-Hosted")
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("Hosted mode requires explicit HostedBaseUrl", completed.stderr)

    def test_production_target_is_required_and_alias_parity_is_fail_closed(self) -> None:
        directory, root, candidate_sha = self.make_repo(target="production")
        with directory:
            completed = self.run_verifier(root, candidate_sha, "-ValidateOnly")
        self.assertEqual(completed.returncode, 0, completed.stderr)

        for target in ("preview", "staging"):
            with self.subTest(target=target):
                directory, root, candidate_sha = self.make_repo(target=target)
                with directory:
                    completed = self.run_verifier(root, candidate_sha, "-ValidateOnly")
                self.assertNotEqual(completed.returncode, 0)
                self.assertIn("production", completed.stderr)

        directory, root, candidate_sha = self.make_repo(target="production")
        with directory:
            frontend_path = root / FRONTEND_REF
            frontend = json.loads(frontend_path.read_text(encoding="utf-8"))
            frontend["deployment_alias_content_parity"] = False
            frontend_path.write_bytes(json_bytes(frontend))
            frontend_hash = sha256_bytes(frontend_path.read_bytes())
            flow_path = root / FLOW_REF
            flow = json.loads(flow_path.read_text(encoding="utf-8"))
            flow["source_binding"]["frontend_evidence_sha256"] = frontend_hash
            flow_path.write_bytes(json_bytes(flow))
            self.commit_all(root, "removed production alias parity")
            completed = self.run_verifier(root, candidate_sha, "-ValidateOnly")
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("alias", completed.stderr.lower())

    def test_artifact_and_scorer_tampering_cannot_be_replaced_by_boolean_claims(self) -> None:
        directory, root, candidate_sha = self.make_repo()
        with directory:
            browser_path = root / BROWSER_REF
            browser = json.loads(browser_path.read_text(encoding="utf-8"))
            browser["observations"][0]["fact_codes"] = ["self_declared_pass"]
            browser_path.write_bytes(json_bytes(browser))
            browser_hash = sha256_bytes(browser_path.read_bytes())
            flow_path = root / FLOW_REF
            flow = json.loads(flow_path.read_text(encoding="utf-8"))
            for step in flow["human_flow_steps"]:
                step["evidence"]["browser_sha256"] = browser_hash
            flow["scorer_outputs"]["browser"]["self_declared_verified"] = True
            flow_path.write_bytes(json_bytes(flow))
            self.commit_all(root, "tampered self-declared evidence")
            completed = self.run_verifier(root, candidate_sha, "-ValidateOnly")
        self.assertNotEqual(completed.returncode, 0)
        self.assertTrue(
            "sensitive evidence key" in completed.stderr
            or "unexpected property" in completed.stderr
            or "fact codes" in completed.stderr
        )

        directory, root, candidate_sha = self.make_repo()
        with directory:
            scorer_path = root / BROWSER_SCORER_REF
            scorer = json.loads(scorer_path.read_text(encoding="utf-8"))
            scorer["computed_fact_sha256"] = "e" * 64
            scorer_path.write_bytes(json_bytes(scorer))
            scorer_hash = sha256_bytes(scorer_path.read_bytes())
            flow_path = root / FLOW_REF
            flow = json.loads(flow_path.read_text(encoding="utf-8"))
            flow["scorer_outputs"]["browser"]["sha256"] = scorer_hash
            flow_path.write_bytes(json_bytes(flow))
            self.commit_all(root, "tampered scorer output")
            completed = self.run_verifier(root, candidate_sha, "-ValidateOnly")
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("computed fact hash mismatch", completed.stderr)

    def test_script_contains_no_evidence_or_gate_write_primitives(self) -> None:
        source = VERIFIER.read_text(encoding="utf-8")
        for forbidden in (
            "Set-Content",
            "Out-File",
            "Add-Content",
            "New-Item",
            "Remove-Item",
            "Move-Item",
            "Copy-Item",
            "live_verified =",
        ):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, source)


if __name__ == "__main__":
    unittest.main()

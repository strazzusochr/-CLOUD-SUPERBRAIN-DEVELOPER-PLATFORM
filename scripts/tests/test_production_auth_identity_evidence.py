from __future__ import annotations

import copy
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
VERIFIER = REPO_ROOT / "scripts" / "verify-production-auth-identity-evidence.ps1"
SOURCE_SHA = "a" * 40
FLOW_STEPS = [
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


def valid_evidence() -> dict[str, object]:
    evidence: dict[str, object] = {
        "contract_version": "production-auth-identity-proof-v1",
        "status": "verified",
        "oauth_scope": "read:user",
        "human_flow_verified_steps": FLOW_STEPS,
        "source_binding": {
            "source_commit_sha": SOURCE_SHA,
            "frontend_source_commit_sha": SOURCE_SHA,
            "auth_runtime_source_commit_sha": SOURCE_SHA,
            "deployment_id": "auth-runtime-deployment-1",
            "frontend_deployment_id": "frontend-deployment-1",
            "auth_runtime_deployment_id": "auth-runtime-deployment-1",
            "immutable_frontend_deployment_verified": True,
            "immutable_auth_runtime_deployment_verified": True,
            "callback_origin": "https://auth.example.test",
            "callback_url": "https://auth.example.test/api/v1/auth/callback",
        },
    }
    for field in (
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
    ):
        evidence[field] = True
    for field in (
        "dev_only",
        "secret_output",
        "gate_promotion_performed",
        "verifier_mutations_performed",
    ):
        evidence[field] = False
    return evidence


class ProductionAuthIdentityEvidenceTests(unittest.TestCase):
    def make_repo(self, evidence: dict[str, object]) -> tuple[tempfile.TemporaryDirectory[str], Path]:
        directory = tempfile.TemporaryDirectory()
        root = Path(directory.name)
        scripts = root / "scripts"
        scripts.mkdir()
        shutil.copy2(VERIFIER, scripts / VERIFIER.name)
        evidence_path = root / "evidence" / "production-auth.json"
        evidence_path.parent.mkdir()
        evidence_path.write_text(json.dumps(evidence, sort_keys=True), encoding="utf-8")
        for command in (
            ["git", "init", "--quiet"],
            ["git", "config", "user.email", "auth-verifier-test@example.invalid"],
            ["git", "config", "user.name", "Auth Verifier Test"],
            ["git", "add", "scripts", "evidence"],
            ["git", "commit", "--quiet", "-m", "test fixture"],
        ):
            subprocess.run(command, cwd=root, check=True, capture_output=True, text=True)
        return directory, root

    def run_verifier(self, root: Path, *extra: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                "pwsh",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(root / "scripts" / VERIFIER.name),
                "-EvidencePath",
                "evidence/production-auth.json",
                "-ExpectedCandidateSha",
                SOURCE_SHA,
                *extra,
            ],
            cwd=root,
            check=False,
            capture_output=True,
            text=True,
        )

    def test_valid_tracked_evidence_passes_read_only_validation(self) -> None:
        directory, root = self.make_repo(valid_evidence())
        with directory:
            completed = self.run_verifier(root, "-ValidateOnly")
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertIn(
            "validation_mode=true read_only=true gate_promotion_performed=false secret_output=false",
            completed.stdout,
        )

    def test_transition_fields_fail_closed(self) -> None:
        for field in (
            "oauth_scope_exact_read_user_verified",
            "oauth_state_one_time_verified",
            "callback_replay_rejected_verified",
            "refresh_family_replay_rejected_verified",
            "audit_before_credential_verified",
        ):
            with self.subTest(field=field):
                evidence = valid_evidence()
                evidence[field] = False
                directory, root = self.make_repo(evidence)
                with directory:
                    completed = self.run_verifier(root, "-ValidateOnly")
                self.assertNotEqual(completed.returncode, 0)

    def test_local_callback_raw_secret_and_dirty_evidence_fail_closed(self) -> None:
        local = valid_evidence()
        binding = local["source_binding"]
        assert isinstance(binding, dict)
        binding["callback_origin"] = "https://localhost"
        binding["callback_url"] = "https://localhost/api/v1/auth/callback"
        directory, root = self.make_repo(local)
        with directory:
            completed = self.run_verifier(root, "-ValidateOnly")
        self.assertNotEqual(completed.returncode, 0)

        secret = valid_evidence()
        secret["access_token"] = "forbidden-test-value"
        directory, root = self.make_repo(secret)
        with directory:
            completed = self.run_verifier(root, "-ValidateOnly")
        self.assertNotEqual(completed.returncode, 0)

        directory, root = self.make_repo(valid_evidence())
        with directory:
            evidence_path = root / "evidence" / "production-auth.json"
            evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
            evidence["oauth_scope"] = "read:user user:email"
            evidence_path.write_text(json.dumps(evidence, sort_keys=True), encoding="utf-8")
            completed = self.run_verifier(root, "-ValidateOnly")
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("Evidence must be clean relative to HEAD", completed.stderr)

    def test_validate_only_is_mandatory(self) -> None:
        directory, root = self.make_repo(copy.deepcopy(valid_evidence()))
        with directory:
            completed = self.run_verifier(root)
        self.assertNotEqual(completed.returncode, 0)


if __name__ == "__main__":
    unittest.main()

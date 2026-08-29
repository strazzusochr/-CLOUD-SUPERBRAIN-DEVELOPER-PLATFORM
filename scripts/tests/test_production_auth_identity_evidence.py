from __future__ import annotations

import copy
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
VERIFIER = REPO_ROOT / "scripts" / "verify-production-auth-identity-evidence.ps1"
SOURCE_SHA = "<fixture-source-sha>"
FRONTEND_ORIGIN = "https://frontend.example.test"
FRONTEND_ORIGIN_EVIDENCE_REF = "docs/runtime-state/frontend-hosted-current.json"
FRONTEND_ORIGIN_EVIDENCE_SHA256_PLACEHOLDER = "<fixture-sha256>"
ARCHITECTURE_DECISION_REF = "docs/runtime-state/production-auth-architecture-decision.json"
ARCHITECTURE_DECISION_SHA256_PLACEHOLDER = "<fixture-adr-sha256>"
AUTH_RUNTIME_EVIDENCE_REF = "docs/runtime-state/cloudflare-oauth-hosted-current.json"
AUTH_RUNTIME_EVIDENCE_SHA256_PLACEHOLDER = "<fixture-runtime-sha256>"
OAUTH_CONFIGURATION_NAMES = (
    "GITHUB_OAUTH_CLIENT_ID",
    "GITHUB_OAUTH_CLIENT_SECRET",
    "GITHUB_OAUTH_REDIRECT_URI",
    "GITHUB_OAUTH_OWNER_IDS",
    "JWT_SIGNING_SECRET",
)
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
            "frontend_origin_evidence_ref": FRONTEND_ORIGIN_EVIDENCE_REF,
            "frontend_origin_evidence_sha256": FRONTEND_ORIGIN_EVIDENCE_SHA256_PLACEHOLDER,
            "owner_architecture_decision_ref": ARCHITECTURE_DECISION_REF,
            "owner_architecture_decision_sha256": ARCHITECTURE_DECISION_SHA256_PLACEHOLDER,
            "auth_runtime_evidence_ref": AUTH_RUNTIME_EVIDENCE_REF,
            "auth_runtime_evidence_sha256": AUTH_RUNTIME_EVIDENCE_SHA256_PLACEHOLDER,
            "callback_origin": FRONTEND_ORIGIN,
            "callback_url": f"{FRONTEND_ORIGIN}/api/v1/auth/callback",
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


def valid_frontend_origin_evidence() -> dict[str, object]:
    return {
        "contract_version": "frontend-hosted-current-proof-v1",
        "status": "verified",
        "source_commit_sha": SOURCE_SHA,
        "source_archive_sha256": None,
        "deployment_id": "frontend-deployment-1",
        "immutable_deployment_url": "https://frontend-immutable.vercel.app",
        "production_alias": FRONTEND_ORIGIN,
        "vercel_target": "production",
        "vercel_scope": "strazzusochrs-projects",
        "vercel_project_id": "prj_ZbSNRVz5ijLQ4tQR61liHFw1x5eY",
        "vercel_project_name": "frontend",
        "git_source_type": "github",
        "git_source_repo_id": "1218719331",
        "git_source_ref": "codex/test-fixture",
        "proof_artifact": "evidence/frontend-responsive-proof.json",
        "proof_generated_at": "2026-08-29T00:00:00Z",
        "browser_channel": "chrome",
        "browser_version": "148.0.7778.96",
        "page_count": 22,
        "viewport_count": 2,
        "click_navigation_count": 44,
        "overflow_failures": 0,
        "overlay_collision_failures": 0,
        "console_errors": 0,
        "read_endpoint_count": 32,
        "former_500_endpoint_count": 8,
        "frontend_progress_before": 99,
        "frontend_progress_after": 100,
        "deployment_metadata_verified": True,
        "deployment_alias_content_parity": True,
        "production_operational_deploy_verified": True,
        "production_release_claimed": False,
        "non_claims": [],
    }


def valid_architecture_decision() -> dict[str, object]:
    return {
        "contract_version": "production-auth-architecture-decision-v1",
        "status": "owner_approved",
        "owner_approved": True,
        "selected_architecture": "cloudflare_native",
        "target": "production",
        "callback_origin": FRONTEND_ORIGIN,
        "source_commit_sha": SOURCE_SHA,
        "auth_runtime_evidence_ref": AUTH_RUNTIME_EVIDENCE_REF,
        "auth_runtime_verifier_ref": "scripts/verify-cloudflare-oauth-hosted-current.ps1",
        "secret_output": False,
    }


def valid_auth_runtime_evidence() -> dict[str, object]:
    return {
        "contract_version": "cloudflare-oauth-hosted-current-v1",
        "status": "verified",
        "architecture": "cloudflare_native",
        "source_commit_sha": SOURCE_SHA,
        "deployment_id": "auth-runtime-deployment-1",
        "runtime_origin": "https://auth-runtime-fixture.workers.dev",
        "provider_writes": False,
        "deployment_writes": False,
        "secret_output": False,
    }


class ProductionAuthIdentityEvidenceTests(unittest.TestCase):
    def make_repo(
        self,
        evidence: dict[str, object],
        frontend_origin_evidence: dict[str, object] | None = None,
        frontend_verifier_succeeds: bool = True,
        architecture_decision: dict[str, object] | None = None,
        auth_runtime_evidence: dict[str, object] | None = None,
        auth_runtime_verifier_succeeds: bool = True,
    ) -> tuple[tempfile.TemporaryDirectory[str], Path]:
        directory = tempfile.TemporaryDirectory()
        root = Path(directory.name)
        scripts = root / "scripts"
        scripts.mkdir()
        shutil.copy2(VERIFIER, scripts / VERIFIER.name)
        frontend_verifier = scripts / "verify-frontend-hosted-current.ps1"
        if frontend_verifier_succeeds:
            frontend_verifier.write_text(
                "param([string]$ConfigPath,[switch]$ValidateOnly)\n"
                "if (-not $ValidateOnly) { exit 9 }\n"
                "Write-Host '[frontend-hosted-current] status=verified full_validation=true validation_mode=true browser_skipped=true verification_written=false'\n",
                encoding="utf-8",
            )
        else:
            frontend_verifier.write_text("param(); exit 7\n", encoding="utf-8")
        runtime_verifier = scripts / "verify-cloudflare-oauth-hosted-current.ps1"
        if auth_runtime_verifier_succeeds:
            runtime_verifier.write_text(
                "param([string]$EvidencePath,[string]$ExpectedCandidateSha,[switch]$ValidateOnly)\n"
                "if (-not $ValidateOnly) { exit 9 }\n"
                "Write-Host '[production-auth-runtime] status=verified architecture=cloudflare_native validation_mode=true read_only=true provider_writes=false deployment_writes=false secret_output=false'\n",
                encoding="utf-8",
            )
        else:
            runtime_verifier.write_text("param(); exit 8\n", encoding="utf-8")
        for command in (
            ["git", "init", "--quiet"],
            ["git", "config", "user.email", "auth-verifier-test@example.invalid"],
            ["git", "config", "user.name", "Auth Verifier Test"],
        ):
            subprocess.run(command, cwd=root, check=True, capture_output=True, text=True)
        source_marker = root / "candidate-source.txt"
        source_marker.write_text("immutable production-auth candidate source\n", encoding="utf-8")
        subprocess.run(["git", "add", source_marker.name], cwd=root, check=True)
        subprocess.run(
            ["git", "commit", "--quiet", "-m", "candidate source"],
            cwd=root,
            check=True,
        )
        candidate_sha = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=root, text=True
        ).strip()

        binding = evidence.get("source_binding")
        if isinstance(binding, dict):
            for field in (
                "source_commit_sha",
                "frontend_source_commit_sha",
                "auth_runtime_source_commit_sha",
            ):
                if binding.get(field) == SOURCE_SHA:
                    binding[field] = candidate_sha
        origin_evidence = frontend_origin_evidence or valid_frontend_origin_evidence()
        if origin_evidence.get("source_commit_sha") == SOURCE_SHA:
            origin_evidence["source_commit_sha"] = candidate_sha
        frontend_origin_path = root / FRONTEND_ORIGIN_EVIDENCE_REF
        frontend_origin_path.parent.mkdir(parents=True)
        frontend_origin_bytes = json.dumps(
            origin_evidence,
            sort_keys=True,
        ).encode("utf-8")
        frontend_origin_path.write_bytes(frontend_origin_bytes)
        decision = architecture_decision or valid_architecture_decision()
        if decision.get("source_commit_sha") == SOURCE_SHA:
            decision["source_commit_sha"] = candidate_sha
        decision_path = root / ARCHITECTURE_DECISION_REF
        decision_path.parent.mkdir(parents=True, exist_ok=True)
        decision_bytes = json.dumps(decision, sort_keys=True).encode("utf-8")
        decision_path.write_bytes(decision_bytes)
        runtime_evidence = auth_runtime_evidence or valid_auth_runtime_evidence()
        if runtime_evidence.get("source_commit_sha") == SOURCE_SHA:
            runtime_evidence["source_commit_sha"] = candidate_sha
        runtime_evidence_path = root / AUTH_RUNTIME_EVIDENCE_REF
        runtime_evidence_path.parent.mkdir(parents=True, exist_ok=True)
        runtime_evidence_bytes = json.dumps(runtime_evidence, sort_keys=True).encode("utf-8")
        runtime_evidence_path.write_bytes(runtime_evidence_bytes)
        if isinstance(binding, dict):
            if binding.get("frontend_origin_evidence_sha256") == FRONTEND_ORIGIN_EVIDENCE_SHA256_PLACEHOLDER:
                binding["frontend_origin_evidence_sha256"] = hashlib.sha256(frontend_origin_bytes).hexdigest()
            if binding.get("owner_architecture_decision_sha256") == ARCHITECTURE_DECISION_SHA256_PLACEHOLDER:
                binding["owner_architecture_decision_sha256"] = hashlib.sha256(decision_bytes).hexdigest()
            if binding.get("auth_runtime_evidence_sha256") == AUTH_RUNTIME_EVIDENCE_SHA256_PLACEHOLDER:
                binding["auth_runtime_evidence_sha256"] = hashlib.sha256(runtime_evidence_bytes).hexdigest()
        evidence_path = root / "evidence" / "production-auth.json"
        evidence_path.parent.mkdir(parents=True, exist_ok=True)
        evidence_path.write_text(json.dumps(evidence, sort_keys=True), encoding="utf-8")
        for command in (
            ["git", "add", "scripts", "evidence", "docs"],
            ["git", "commit", "--quiet", "-m", "test evidence"],
        ):
            subprocess.run(command, cwd=root, check=True, capture_output=True, text=True)
        return directory, root

    def run_verifier(
        self,
        root: Path,
        *extra: str,
        expected_candidate_sha: str | None = None,
    ) -> subprocess.CompletedProcess[str]:
        candidate_sha = expected_candidate_sha or subprocess.check_output(
            ["git", "rev-list", "--max-parents=0", "HEAD"], cwd=root, text=True
        ).strip()
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
                candidate_sha,
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
        self.assertIn("callback_origin_bound=true", completed.stdout)
        self.assertIn("owner_architecture_adr_bound=true", completed.stdout)
        self.assertIn("auth_runtime_bound=true", completed.stdout)

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

    def test_unknown_secret_fields_reversed_flow_and_custom_port_fail_closed(self) -> None:
        secret = valid_evidence()
        secret["token"] = "forbidden-test-value"
        directory, root = self.make_repo(secret)
        with directory:
            completed = self.run_verifier(root, "-ValidateOnly")
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("must contain exactly 34 properties", completed.stderr)

        reversed_flow = valid_evidence()
        reversed_flow["human_flow_verified_steps"] = list(reversed(FLOW_STEPS))
        directory, root = self.make_repo(reversed_flow)
        with directory:
            completed = self.run_verifier(root, "-ValidateOnly")
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("human-flow step 0", completed.stderr)

        custom_port = valid_evidence()
        binding = custom_port["source_binding"]
        assert isinstance(binding, dict)
        binding["callback_origin"] = "https://frontend.example.test:8443"
        binding["callback_url"] = "https://frontend.example.test:8443/api/v1/auth/callback"
        directory, root = self.make_repo(custom_port)
        with directory:
            completed = self.run_verifier(root, "-ValidateOnly")
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("default HTTPS port", completed.stderr)

    def test_nonexistent_or_nonancestor_candidate_sha_fails_closed(self) -> None:
        directory, root = self.make_repo(valid_evidence())
        with directory:
            completed = self.run_verifier(
                root,
                "-ValidateOnly",
                expected_candidate_sha="a" * 40,
            )
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("resolve to a local commit", completed.stderr)

    def test_callback_origin_must_match_bound_frontend_origin_evidence(self) -> None:
        evidence = valid_evidence()
        binding = evidence["source_binding"]
        assert isinstance(binding, dict)
        binding["callback_origin"] = "https://unrelated.example.test"
        binding["callback_url"] = "https://unrelated.example.test/api/v1/auth/callback"
        directory, root = self.make_repo(evidence)
        with directory:
            completed = self.run_verifier(root, "-ValidateOnly")
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("callback_origin must equal", completed.stderr)

    def test_dynamic_frontend_origin_verifier_failure_blocks_auth_evidence(self) -> None:
        directory, root = self.make_repo(
            valid_evidence(), frontend_verifier_succeeds=False
        )
        with directory:
            completed = self.run_verifier(root, "-ValidateOnly")
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("dynamic validation failed", completed.stderr)

    def test_owner_architecture_and_runtime_evidence_fail_closed(self) -> None:
        decision = valid_architecture_decision()
        decision["owner_approved"] = False
        directory, root = self.make_repo(
            valid_evidence(), architecture_decision=decision
        )
        with directory:
            completed = self.run_verifier(root, "-ValidateOnly")
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("owner_approved", completed.stderr)

        runtime_evidence = valid_auth_runtime_evidence()
        runtime_evidence["source_commit_sha"] = "b" * 40
        directory, root = self.make_repo(
            valid_evidence(), auth_runtime_evidence=runtime_evidence
        )
        with directory:
            completed = self.run_verifier(root, "-ValidateOnly")
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("source_commit_sha", completed.stderr)

        directory, root = self.make_repo(
            valid_evidence(), auth_runtime_verifier_succeeds=False
        )
        with directory:
            completed = self.run_verifier(root, "-ValidateOnly")
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("auth runtime dynamic validation failed", completed.stderr)

    def test_frontend_origin_evidence_reference_and_hash_fail_closed(self) -> None:
        for field, value in (
            ("frontend_origin_evidence_ref", "evidence/missing-origin.json"),
            ("frontend_origin_evidence_sha256", "b" * 64),
        ):
            with self.subTest(field=field):
                evidence = valid_evidence()
                binding = evidence["source_binding"]
                assert isinstance(binding, dict)
                binding[field] = value
                directory, root = self.make_repo(evidence)
                with directory:
                    completed = self.run_verifier(root, "-ValidateOnly")
                self.assertNotEqual(completed.returncode, 0)

    def test_alternate_tracked_frontend_origin_file_cannot_replace_canonical_state(self) -> None:
        evidence = valid_evidence()
        binding = evidence["source_binding"]
        assert isinstance(binding, dict)
        alternate_ref = "evidence/alternate-frontend-origin.json"
        binding["frontend_origin_evidence_ref"] = alternate_ref
        directory, root = self.make_repo(evidence)
        with directory:
            alternate_path = root / alternate_ref
            alternate_path.parent.mkdir(parents=True, exist_ok=True)
            alternate_bytes = json.dumps(valid_frontend_origin_evidence(), sort_keys=True).encode("utf-8")
            alternate_path.write_bytes(alternate_bytes)
            binding["frontend_origin_evidence_sha256"] = hashlib.sha256(alternate_bytes).hexdigest()
            evidence_path = root / "evidence" / "production-auth.json"
            evidence_path.write_text(json.dumps(evidence, sort_keys=True), encoding="utf-8")
            subprocess.run(["git", "add", "."], cwd=root, check=True)
            subprocess.run(["git", "commit", "--quiet", "-m", "alternate"], cwd=root, check=True)
            completed = self.run_verifier(root, "-ValidateOnly")
        self.assertNotEqual(completed.returncode, 0)
        stderr_without_ansi = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", completed.stderr)
        normalized_stderr = " ".join(stderr_without_ansi.split())
        self.assertIn(
            "source_binding.frontend_origin_evidence_ref must use the canonical hosted frontend state path.",
            normalized_stderr,
        )

    def test_backend_or_stale_origin_evidence_cannot_substitute_for_frontend(self) -> None:
        for field, value in (
            ("vercel_project_name", "cloud-superbrain-developer-platform"),
            ("vercel_project_id", "prj_otherfrontend"),
            ("vercel_scope", "different-scope"),
            ("source_commit_sha", "b" * 40),
            ("deployment_id", "different-deployment"),
            ("deployment_alias_content_parity", False),
            ("production_operational_deploy_verified", False),
        ):
            with self.subTest(field=field):
                origin_evidence = valid_frontend_origin_evidence()
                origin_evidence[field] = value
                evidence = valid_evidence()
                directory, root = self.make_repo(evidence, origin_evidence)
                with directory:
                    completed = self.run_verifier(root, "-ValidateOnly")
                self.assertNotEqual(completed.returncode, 0)

    def test_templates_are_name_only_and_runbook_matches_start_script(self) -> None:
        for template_name in (".env.example", "staging.env.template"):
            template = (REPO_ROOT / template_name).read_text(encoding="utf-8")
            lines = template.splitlines()
            for name in OAUTH_CONFIGURATION_NAMES:
                with self.subTest(template=template_name, name=name):
                    self.assertEqual(lines.count(f"{name}="), 1)

        start_script = (REPO_ROOT / "scripts" / "start-dev-live.ps1").read_text(encoding="utf-8")
        for name in OAUTH_CONFIGURATION_NAMES:
            self.assertIn(f"'{name}'", start_script)

        runbook = (
            REPO_ROOT / "docs" / "runbooks" / "PRODUCTION_OAUTH_FIXPLAN_2026-08-29.md"
        ).read_text(encoding="utf-8")
        self.assertIn("laedt bereits alle fuenf Namen", runbook)
        self.assertNotIn("laedt derzeit nur vier OAuth-Namen", runbook)

    def test_validate_only_is_mandatory(self) -> None:
        directory, root = self.make_repo(copy.deepcopy(valid_evidence()))
        with directory:
            completed = self.run_verifier(root)
        self.assertNotEqual(completed.returncode, 0)


if __name__ == "__main__":
    unittest.main()

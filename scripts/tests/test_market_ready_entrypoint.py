from __future__ import annotations

import json
import shutil
import subprocess
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]


class MarketReadyEntrypointTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        npm = shutil.which("npm")
        if npm is None:
            raise unittest.SkipTest("npm is unavailable")
        completed = subprocess.run(
            [npm, "pkg", "get", "scripts"],
            cwd=REPO_ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
        cls.scripts = json.loads(completed.stdout)

    def test_plain_market_ready_runs_the_external_gate_audit(self) -> None:
        command = self.scripts["verify:market-ready"]
        self.assertIn(" -IncludeExternalGates", command)
        self.assertNotIn(" -RequireReady", command)

    def test_static_audit_stays_offline_and_require_ready_stays_fail_closed(self) -> None:
        static_command = self.scripts["verify:market-ready:static"]
        require_ready_command = self.scripts["verify:market-ready:require-ready"]
        self.assertNotIn(" -IncludeExternalGates", static_command)
        self.assertIn(" -IncludeExternalGates", require_ready_command)
        self.assertIn(" -RequireReady", require_ready_command)

    def test_production_auth_gate_has_a_real_verifier_availability_transition(self) -> None:
        source = (REPO_ROOT / "scripts" / "verify-market-ready.ps1").read_text(
            encoding="utf-8"
        )
        arm = source.split('"production_auth_identity" {', 1)[1].split(
            '"docker_registry_publish" {', 1
        )[0]
        markers = (
            '$authVerifierRelative = "scripts/verify-production-auth-identity-evidence.ps1"',
            "Resolve-RepoScopedFile $authVerifierRelative",
            "Test-TrackedCleanRepoFile $authVerifierRelative",
            "-EvidencePath $relativeEvidence",
            "-ExpectedCandidateSha $ExpectedCandidateSha",
            "-ValidateOnly",
            "auth_dedicated_non_mutating_verifier_failed",
            "validation_mode=true read_only=true gate_promotion_performed=false secret_output=false",
            "oauth_scope_exact_read_user_verified",
            "oauth_state_one_time_verified",
            "callback_replay_rejected_verified",
            "refresh_family_replay_rejected_verified",
            "audit_before_credential_verified",
        )
        for marker in markers:
            with self.subTest(marker=marker):
                self.assertIn(marker, arm)

        guard = "if ([string]$Gate.verifier -ne $authVerifierRelative -or"
        unavailable = '$failures.Add("auth_dedicated_non_mutating_verifier_unavailable")'
        self.assertEqual(arm.count(unavailable), 1)
        self.assertLess(arm.index(guard), arm.index(unavailable))

    def test_production_auth_evidence_verifier_is_read_only_and_fail_closed(self) -> None:
        source = (
            REPO_ROOT / "scripts" / "verify-production-auth-identity-evidence.ps1"
        ).read_text(encoding="utf-8")
        for marker in (
            "production-auth-identity-proof-v1",
            "oauth_scope_exact_read_user_verified",
            "oauth_state_one_time_verified",
            "callback_replay_rejected_verified",
            "refresh_family_replay_rejected_verified",
            "audit_before_credential_verified",
            "human_flow_verified_steps",
            "Evidence must contain exactly the 12 canonical human-flow steps.",
            "Evidence must be clean relative to HEAD.",
            "validation_mode=true read_only=true gate_promotion_performed=false secret_output=false",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, source)
        self.assertIn("if (-not $ValidateOnly)", source)
        self.assertNotIn("Invoke-WebRequest", source)
        self.assertNotIn("Invoke-RestMethod", source)


if __name__ == "__main__":
    unittest.main()

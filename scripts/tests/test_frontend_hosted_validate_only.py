from __future__ import annotations

import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
VERIFIER = REPO_ROOT / "scripts" / "verify-frontend-hosted-current.ps1"


class FrontendHostedValidateOnlyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = VERIFIER.read_text(encoding="utf-8")

    def test_validate_only_selects_the_full_non_mutating_path(self) -> None:
        for marker in (
            "[switch]$ValidateOnly",
            "if ($ValidateOnly) { $SkipBrowser = $true }",
            "full_validation=true",
            "validation_mode=true",
            "browser_skipped=true",
            "verification_written=false",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, self.source)

        static_guard = "Assert-True (-not ($StaticOnly -and $ValidateOnly))"
        dynamic_start = "$deploymentBefore = Get-AuthenticatedDeployment"
        endpoint_loop = "foreach ($path in $requiredReadPaths)"
        dynamic_end = "$deploymentAfter = Get-AuthenticatedDeployment"
        self.assertIn(static_guard, self.source)
        self.assertLess(self.source.index(dynamic_start), self.source.index(endpoint_loop))
        self.assertLess(self.source.index(endpoint_loop), self.source.index(dynamic_end))

    def test_validate_only_suppresses_the_only_artifact_write(self) -> None:
        self.assertEqual(self.source.count("Set-Content"), 1)
        guarded_write = re.compile(
            r"if \(-not \$ValidateOnly\)\s*\{\s*"
            r"\$verification \| ConvertTo-Json -Depth 5 \| Set-Content "
            r"-LiteralPath \$verificationPath -Encoding utf8\s*\}",
            re.MULTILINE,
        )
        self.assertRegex(self.source, guarded_write)

    def test_preview_target_normalizes_vercel_api_null_without_weakening_production(self) -> None:
        for marker in (
            '$ExpectedTarget -ceq "preview"',
            '$deploymentTarget = "preview"',
            '"Vercel frontend deployment target"',
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, self.source)

        self.assertNotIn(
            'Assert-True (-not [string]::IsNullOrWhiteSpace([string]$deployment.target))',
            self.source,
        )

    def test_workspace_artifacts_accepts_only_the_exact_hosted_d1_read_contract(self) -> None:
        for marker in (
            '$path -ceq "/api/v1/workspace/artifacts"',
            '[string]$responseJson.source -ceq "cloudflare-d1"',
            '"cloudflare-d1-stateful-runtime-v1"',
            '"hosted D1 artifact read persisted"',
            '"hosted D1 artifact read direct_provider_calls"',
            '"hosted D1 artifact read live_provider_calls"',
            '"hosted D1 artifact read secret_output"',
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, self.source)


if __name__ == "__main__":
    unittest.main()

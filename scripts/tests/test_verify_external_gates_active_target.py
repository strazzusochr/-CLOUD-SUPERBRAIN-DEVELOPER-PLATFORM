import shutil
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
VERIFY_EXTERNAL_GATES = ROOT / "scripts" / "verify-external-gates.ps1"
VERIFY_PHASE1 = ROOT / "scripts" / "verify-phase1.ps1"
PR_CHECK = ROOT / ".github" / "workflows" / "pr-check.yml"


class VerifyExternalGatesActiveTargetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        source = VERIFY_EXTERNAL_GATES.read_text(encoding="utf-8")
        start_marker = "function Resolve-ActiveTargetGate"
        end_marker = "function Assert-HostedBaseUrlSafe"
        start = source.index(start_marker)
        end = source.index(end_marker, start)
        cls.resolver_block = source[start:end]
        cls.powershell = shutil.which("pwsh") or shutil.which("powershell")

    def resolve(self, missing: list[str]) -> str:
        if not self.powershell:
            self.skipTest("PowerShell is required for the resolver regression fixture")
        values = ", ".join("'" + item.replace("'", "''") + "'" for item in missing)
        script = (
            "$ErrorActionPreference = 'Stop'\n"
            f"{self.resolver_block}\n"
            f"$missing = @({values})\n"
            "$result = Resolve-ActiveTargetGate $missing\n"
            "[Console]::Out.Write([string]$result)\n"
        )
        result = subprocess.run(
            [self.powershell, "-NoProfile", "-NonInteractive", "-Command", "-"],
            input=script,
            text=True,
            capture_output=True,
            cwd=ROOT,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        return result.stdout

    def test_ghcr_is_active_when_it_is_the_only_missing_gate(self) -> None:
        self.assertEqual(
            self.resolve(["ghcr_image_digest_verify"]),
            "ghcr_image_digest_verify",
        )

    def test_first_missing_gate_wins_deterministically(self) -> None:
        self.assertEqual(
            self.resolve(
                [
                    "hosted_agent_api_contracts",
                    "ghcr_image_digest_verify",
                    "vercel_backend_origin_health",
                ]
            ),
            "hosted_agent_api_contracts",
        )

    def test_empty_missing_gate_list_has_no_active_target(self) -> None:
        self.assertEqual(self.resolve([]), "")

    def test_resolver_skips_blank_entries_fail_closed(self) -> None:
        self.assertEqual(
            self.resolve(["", "ghcr_image_digest_verify"]),
            "ghcr_image_digest_verify",
        )

    def test_summary_uses_resolved_target_instead_of_hardcoded_gate(self) -> None:
        source = VERIFY_EXTERNAL_GATES.read_text(encoding="utf-8")
        self.assertIn("$activeTargetGate = Resolve-ActiveTargetGate $missing", source)
        self.assertIn("active_target_gate = $activeTargetGate", source)
        self.assertNotIn(
            'active_target_gate = "cloudflare_native_zero_card_hosted_runtime"',
            source,
        )


class GitleaksTemporaryMirrorContractTests(unittest.TestCase):
    def test_external_gate_scan_uses_relative_source_inside_mirror(self) -> None:
        source = VERIFY_EXTERNAL_GATES.read_text(encoding="utf-8")
        self.assertIn("Push-Location -LiteralPath $gitleaksScanRoot", source)
        self.assertIn(
            '@("detect", "--no-git", "--source", ".", "--config", ".gitleaks.toml", "--redact", "--timeout", "600")',
            source,
        )
        self.assertNotIn(
            '@("detect", "--no-git", "--source", $gitleaksScanRoot',
            source,
        )

    def test_phase1_scan_uses_relative_source_inside_mirror(self) -> None:
        source = VERIFY_PHASE1.read_text(encoding="utf-8")
        self.assertIn("Push-Location -LiteralPath $gitleaksScanRoot", source)
        self.assertIn(
            "detect --no-git --source . --config .gitleaks.toml --redact --timeout 600",
            source,
        )
        self.assertNotIn("--source $gitleaksScanRoot --config .gitleaks.toml", source)

    def test_gitleaks_positive_control_remains_required(self) -> None:
        workflow = PR_CHECK.read_text(encoding="utf-8")
        self.assertIn("Verify gitleaks positive control", workflow)
        self.assertIn("gitleaks-positive-control.txt", workflow)
        self.assertIn("--exit-code 42", workflow)
        self.assertIn('test "${probe_status}" -eq 42', workflow)


if __name__ == "__main__":
    unittest.main()

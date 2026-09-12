import json
import shutil
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
VERIFY_PHASE1 = ROOT / "scripts" / "verify-phase1.ps1"


class VerifyPhase1ExternalGateActiveTargetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        source = VERIFY_PHASE1.read_text(encoding="utf-8")
        start_marker = "function Assert-ExternalGateActiveTargetConsistency"
        end_marker = 'Write-Host "[verify] supply-chain pins"'
        start = source.index(start_marker)
        end = source.index(end_marker, start)
        cls.guard_block = source[start:end]
        cls.source = source
        cls.powershell = shutil.which("pwsh") or shutil.which("powershell")

    def run_guard(self, record: dict[str, object]) -> subprocess.CompletedProcess[str]:
        if not self.powershell:
            self.skipTest("PowerShell is required for the verifier regression fixture")
        payload = json.dumps(record, separators=(",", ":"))
        script = (
            "$ErrorActionPreference = 'Stop'\n"
            f"{self.guard_block}\n"
            f"$record = @'\n{payload}\n'@ | ConvertFrom-Json\n"
            "try {\n"
            "  Assert-ExternalGateActiveTargetConsistency $record 'fixture'\n"
            "} catch {\n"
            "  [Console]::Error.WriteLine($_.Exception.Message)\n"
            "  exit 1\n"
            "}\n"
        )
        return subprocess.run(
            [self.powershell, "-NoProfile", "-NonInteractive", "-Command", script],
            text=True,
            capture_output=True,
            cwd=ROOT,
            check=False,
        )

    def assert_passes(self, record: dict[str, object]) -> None:
        result = self.run_guard(record)
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def assert_fails(self, record: dict[str, object]) -> None:
        result = self.run_guard(record)
        self.assertNotEqual(result.returncode, 0, "fixture unexpectedly passed")

    def test_ghcr_target_matches_only_missing_gate(self) -> None:
        self.assert_passes(
            {
                "missing_or_failed_gates": ["ghcr_image_digest_verify"],
                "active_target_gate": "ghcr_image_digest_verify",
            }
        )

    def test_first_ordered_missing_gate_is_required(self) -> None:
        self.assert_passes(
            {
                "missing_or_failed_gates": [
                    "hosted_agent_api_contracts",
                    "ghcr_image_digest_verify",
                ],
                "active_target_gate": "hosted_agent_api_contracts",
            }
        )

    def test_stale_cloudflare_target_fails_for_ghcr_missing(self) -> None:
        self.assert_fails(
            {
                "missing_or_failed_gates": ["ghcr_image_digest_verify"],
                "active_target_gate": "cloudflare_native_zero_card_hosted_runtime",
            }
        )

    def test_nonfirst_missing_target_fails(self) -> None:
        self.assert_fails(
            {
                "missing_or_failed_gates": [
                    "hosted_agent_api_contracts",
                    "ghcr_image_digest_verify",
                ],
                "active_target_gate": "ghcr_image_digest_verify",
            }
        )

    def test_empty_missing_list_requires_empty_target(self) -> None:
        self.assert_passes(
            {"missing_or_failed_gates": [], "active_target_gate": ""}
        )
        self.assert_fails(
            {
                "missing_or_failed_gates": [],
                "active_target_gate": "cloudflare_native_zero_card_hosted_runtime",
            }
        )

    def test_missing_fields_and_blank_gate_ids_fail_closed(self) -> None:
        self.assert_fails({"active_target_gate": ""})
        self.assert_fails({"missing_or_failed_gates": []})
        self.assert_fails(
            {"missing_or_failed_gates": [""], "active_target_gate": ""}
        )

    def test_summary_and_audit_both_use_dynamic_guard(self) -> None:
        self.assertIn(
            'Assert-ExternalGateActiveTargetConsistency $externalGateSummary "Canonical external gate summary"',
            self.source,
        )
        self.assertIn(
            'Assert-ExternalGateActiveTargetConsistency $currentAudit "Canonical external gate audit"',
            self.source,
        )
        self.assertNotIn(
            'active_target_gate -ne "cloudflare_native_zero_card_hosted_runtime"',
            self.source,
        )


class VerifyPhase1ExternalGateClaimMapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        source = VERIFY_PHASE1.read_text(encoding="utf-8")
        start_marker = "$actualMissingExternalGates = @("
        end_marker = "if (\n  $externalGateSummary.PSObject.Properties.Name -contains \"fly_live_budget_claim_allowed\""
        start = source.index(start_marker)
        end = source.index(end_marker, start)
        cls.claim_map_block = source[start:end]
        cls.powershell = shutil.which("pwsh") or shutil.which("powershell")

    def run_claim_map(self, summary: dict[str, object]) -> subprocess.CompletedProcess[str]:
        if not self.powershell:
            self.skipTest("PowerShell is required for the verifier regression fixture")
        payload = json.dumps(summary, separators=(",", ":"))
        script = (
            "$ErrorActionPreference = 'Stop'\n"
            f"$externalGateSummary = @'\n{payload}\n'@ | ConvertFrom-Json\n"
            f"{self.claim_map_block}\n"
        )
        return subprocess.run(
            [self.powershell, "-NoProfile", "-NonInteractive", "-Command", "-"],
            input=script,
            text=True,
            capture_output=True,
            cwd=ROOT,
            check=False,
        )

    @staticmethod
    def summary(missing: list[str]) -> dict[str, object]:
        return {
            "missing_or_failed_gates": missing,
            "hosted_staging_claim_allowed": "hosted_agent_api_contracts" not in missing,
            "branch_protection_claim_allowed": "github_branch_protection_current_verify" not in missing,
            "ghcr_image_digest_claim_allowed": "ghcr_image_digest_verify" not in missing,
            "vercel_backend_origins_claim_allowed": "vercel_backend_origin_health" not in missing,
            "canonical_gitleaks_claim_allowed": "canonical_gitleaks_scan" not in missing,
            "cloudflare_native_zero_card_hosted_runtime_claim_allowed": (
                "cloudflare_native_zero_card_hosted_runtime" not in missing
            ),
        }

    def assert_passes(self, summary: dict[str, object]) -> None:
        result = self.run_claim_map(summary)
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def assert_fails(self, summary: dict[str, object]) -> None:
        result = self.run_claim_map(summary)
        self.assertNotEqual(result.returncode, 0, "fixture unexpectedly passed")

    def test_current_three_gate_missing_set_passes(self) -> None:
        self.assert_passes(
            self.summary(
                [
                    "hosted_agent_api_contracts",
                    "ghcr_image_digest_verify",
                    "vercel_backend_origin_health",
                ]
            )
        )

    def test_claim_map_accepts_all_flags_true_with_empty_missing_set(self) -> None:
        self.assert_passes(self.summary([]))

    def test_ghcr_publication_transition_passes_while_hosted_gates_remain(self) -> None:
        self.assert_passes(
            self.summary(
                [
                    "hosted_agent_api_contracts",
                    "vercel_backend_origin_health",
                ]
            )
        )

    def test_false_claim_with_omitted_missing_id_fails(self) -> None:
        summary = self.summary([])
        summary["hosted_staging_claim_allowed"] = False
        self.assert_fails(summary)

    def test_true_claim_with_present_missing_id_fails(self) -> None:
        summary = self.summary(["ghcr_image_digest_verify"])
        summary["ghcr_image_digest_claim_allowed"] = True
        self.assert_fails(summary)

    def test_unknown_missing_id_fails(self) -> None:
        self.assert_fails(self.summary(["unknown_external_gate"]))

    def test_duplicate_missing_id_fails(self) -> None:
        self.assert_fails(
            self.summary(
                [
                    "ghcr_image_digest_verify",
                    "ghcr_image_digest_verify",
                ]
            )
        )

    def test_case_variant_missing_id_fails(self) -> None:
        self.assert_fails(self.summary(["GHCR_IMAGE_DIGEST_VERIFY"]))

    def test_delimiter_collision_missing_id_fails(self) -> None:
        summary = self.summary(
            [
                "hosted_agent_api_contracts",
                "ghcr_image_digest_verify",
            ]
        )
        summary["missing_or_failed_gates"] = [
            "ghcr_image_digest_verify|hosted_agent_api_contracts"
        ]
        self.assert_fails(summary)

    def test_source_does_not_mask_duplicates_or_require_ghcr_missing(self) -> None:
        self.assertNotIn("Sort-Object -Unique", self.claim_map_block)
        self.assertNotIn("must still list the unpublished GHCR digest", self.claim_map_block)


if __name__ == "__main__":
    unittest.main()

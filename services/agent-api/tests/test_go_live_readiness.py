from __future__ import annotations

import unittest
from unittest.mock import patch

from app import main


class GoLiveReadinessTests(unittest.TestCase):
    def readiness(self, missing_gates: list[str]) -> dict[str, object]:
        summary = {
            "contract_version": "external-gate-summary-v2",
            "status": "verified" if not missing_gates else "blocked",
            "missing_or_failed_gates": list(missing_gates),
            "frontend_preview_claim_allowed": "hosted_agent_api_contracts" not in missing_gates,
            "hosted_staging_claim_allowed": "hosted_agent_api_contracts" not in missing_gates,
            "branch_protection_claim_allowed": "github_branch_protection_current_verify" not in missing_gates,
            "ghcr_image_digest_claim_allowed": "ghcr_image_digest_verify" not in missing_gates,
            "vercel_backend_origins_claim_allowed": "vercel_backend_origin_health" not in missing_gates,
            "canonical_gitleaks_claim_allowed": "canonical_gitleaks_scan" not in missing_gates,
            "cloudflare_native_zero_card_hosted_runtime_claim_allowed": (
                "cloudflare_native_zero_card_hosted_runtime" not in missing_gates
            ),
            "production_deploy_claim_allowed": not missing_gates,
        }
        with (
            patch.object(main, "project_progress_payload", return_value={"overall_percent": 89}),
            patch.object(
                main,
                "project_progress_completion_payload",
                return_value={"status": "blocked_external_gates", "can_set_all_to_100": False, "hard_blockers": []},
            ),
            patch.object(main, "external_gate_state", return_value={"status": "action_required", "blocked_release_gates": []}),
            patch.object(
                main,
                "cloud_deployment_preflight_state",
                return_value={"status": "action_required", "preflight_ready": False, "gates": [], "missing_or_blocked_gates": []},
            ),
            patch.object(
                main,
                "cloud_layer_readiness_state",
                return_value={"status": "partial", "ready_layer_count": 4, "total_layer_count": 7, "layers": []},
            ),
            patch.object(main, "workspace_wiring_payload", return_value={"page_count": 22, "contract_version": "workspace-surface-wiring-v1"}),
            patch.object(main, "external_gate_summary_state", return_value=summary),
        ):
            return main.go_live_readiness_state()

    def test_expected_external_audit_gates_match_current_canonical_missing_set(self) -> None:
        missing = [
            "hosted_agent_api_contracts",
            "ghcr_image_digest_verify",
            "vercel_backend_origin_health",
        ]
        readiness = self.readiness(missing)

        self.assertEqual(readiness["external_audit_missing_or_failed_gates"], missing)
        self.assertEqual(readiness["external_audit_expected_missing_or_failed_gates"], missing)

    def test_expected_external_audit_gates_clear_when_the_canonical_set_clears(self) -> None:
        readiness = self.readiness([])

        self.assertEqual(readiness["external_audit_missing_or_failed_gates"], [])
        self.assertEqual(readiness["external_audit_expected_missing_or_failed_gates"], [])

    def test_surface_contract_requires_the_canonical_missing_gate_alias(self) -> None:
        with patch.object(main, "go_live_readiness_state", return_value={"non_claims": []}):
            contract = main.go_live_readiness_contract_payload()

        self.assertIn(
            "external_audit_expected_missing_or_failed_gates",
            contract["required_top_level_fields"],
        )


if __name__ == "__main__":
    unittest.main()

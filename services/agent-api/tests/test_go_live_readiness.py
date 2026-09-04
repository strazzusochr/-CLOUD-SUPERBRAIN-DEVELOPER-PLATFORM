from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from app import main


class GoLiveReadinessTests(unittest.TestCase):
    CANONICAL_CLAIM_GATES = (
        ("hosted_staging_claim_allowed", "hosted_agent_api_contracts"),
        ("branch_protection_claim_allowed", "github_branch_protection_current_verify"),
        ("ghcr_image_digest_claim_allowed", "ghcr_image_digest_verify"),
        ("vercel_backend_origins_claim_allowed", "vercel_backend_origin_health"),
        ("canonical_gitleaks_claim_allowed", "canonical_gitleaks_scan"),
        (
            "cloudflare_native_zero_card_hosted_runtime_claim_allowed",
            "cloudflare_native_zero_card_hosted_runtime",
        ),
    )

    def external_summary_payload(self) -> dict[str, object]:
        gate_ids = [gate for _, gate in self.CANONICAL_CLAIM_GATES]
        candidate_sha = "a" * 40
        return {
            "contract_version": "external-gate-summary-v2",
            "source_contract_version": "external-gate-audit-v2",
            "source_artifact": "docs/runtime-state/external-gate-audit-v2.json",
            "local_run_artifact": ".phase1-artifacts/external-gate-audit-v2-20260829-120000.json",
            "generated_at_utc": "2026-08-29T12:00:00Z",
            "status": "verified",
            "active_target_gate": "cloudflare_native_zero_card_hosted_runtime",
            "requested_release_candidate_selector": candidate_sha,
            "active_release_candidate_sha": candidate_sha,
            "ghcr_published_manifest_ref": "docs/release-artifacts/ghcr-published-manifest.json",
            "ghcr_candidate_readback_source_artifact": "docs/runtime-state/external-gate-audit-v2.json",
            "gate_ids": gate_ids,
            "frontend_preview_claim_allowed": True,
            **{claim: True for claim, _ in self.CANONICAL_CLAIM_GATES},
            "production_deploy_claim_allowed": True,
            "missing_or_failed_gates": [],
            "failed_hosted_required_probe_ids": [],
            "failed_vercel_origin_probe_ids": [],
        }

    def load_external_summary(self, payload: dict[str, object]) -> dict[str, object]:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "external-gate-summary.json"
            path.write_text(json.dumps(payload), encoding="utf-8")
            with patch.object(main, "external_gate_summary_path", return_value=path):
                return main.external_gate_summary_state()

    def readiness(
        self,
        missing_gates: list[str],
        *,
        summary_overrides: dict[str, object] | None = None,
    ) -> dict[str, object]:
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
        summary.update(summary_overrides or {})
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

    def test_expected_external_audit_gates_are_independently_derived_from_claims(self) -> None:
        missing = [
            "hosted_agent_api_contracts",
            "github_branch_protection_current_verify",
            "ghcr_image_digest_verify",
            "vercel_backend_origin_health",
            "canonical_gitleaks_scan",
            "cloudflare_native_zero_card_hosted_runtime",
        ]
        readiness = self.readiness(missing)

        self.assertEqual(readiness["external_audit_missing_or_failed_gates"], missing)
        self.assertEqual(readiness["external_audit_expected_missing_or_failed_gates"], missing)
        self.assertTrue(readiness["external_audit_summary_consistent"])
        self.assertEqual(readiness["external_audit_summary_consistency_errors"], [])

    def test_expected_external_audit_gates_clear_when_the_canonical_set_clears(self) -> None:
        readiness = self.readiness([])

        self.assertEqual(readiness["external_audit_missing_or_failed_gates"], [])
        self.assertEqual(readiness["external_audit_expected_missing_or_failed_gates"], [])
        self.assertTrue(readiness["external_audit_summary_consistent"])

    def test_expected_missing_gates_do_not_copy_a_forged_raw_list(self) -> None:
        readiness = self.readiness(
            [],
            summary_overrides={
                "hosted_staging_claim_allowed": False,
                "production_deploy_claim_allowed": False,
            },
        )

        self.assertEqual(readiness["external_audit_missing_or_failed_gates"], [])
        self.assertEqual(
            readiness["external_audit_expected_missing_or_failed_gates"],
            ["hosted_agent_api_contracts"],
        )
        self.assertFalse(readiness["external_audit_summary_consistent"])
        self.assertIn(
            "missing_gate_sequence_mismatch",
            readiness["external_audit_summary_consistency_errors"],
        )
        self.assertEqual(readiness["status"], "blocked_external_gates")

    def test_missing_gate_order_must_match_canonical_claim_order(self) -> None:
        canonical = [gate for _, gate in self.CANONICAL_CLAIM_GATES]
        readiness = self.readiness(list(reversed(canonical)))

        self.assertEqual(
            readiness["external_audit_expected_missing_or_failed_gates"],
            canonical,
        )
        self.assertIn(
            "missing_gate_sequence_mismatch",
            readiness["external_audit_summary_consistency_errors"],
        )

    def test_duplicate_missing_gate_is_rejected(self) -> None:
        readiness = self.readiness(
            ["hosted_agent_api_contracts", "hosted_agent_api_contracts"],
        )

        self.assertIn(
            "missing_gate_sequence_mismatch",
            readiness["external_audit_summary_consistency_errors"],
        )

    def test_unknown_or_case_changed_missing_gate_is_rejected(self) -> None:
        for forged_gate in ("Hosted_Agent_API_Contracts", "unknown_release_gate"):
            with self.subTest(forged_gate=forged_gate):
                readiness = self.readiness([forged_gate])
                self.assertIn(
                    "missing_gate_sequence_mismatch",
                    readiness["external_audit_summary_consistency_errors"],
                )

    def test_summary_status_must_match_derived_missing_gates(self) -> None:
        readiness = self.readiness(
            ["hosted_agent_api_contracts"],
            summary_overrides={"status": "verified"},
        )

        self.assertEqual(readiness["external_audit_expected_status"], "blocked")
        self.assertIn(
            "summary_status_mismatch",
            readiness["external_audit_summary_consistency_errors"],
        )

    def test_production_claim_must_match_all_six_derived_claims(self) -> None:
        readiness = self.readiness(
            ["hosted_agent_api_contracts"],
            summary_overrides={"production_deploy_claim_allowed": True},
        )

        self.assertFalse(
            readiness["external_audit_expected_production_deploy_claim_allowed"],
        )
        self.assertIn(
            "production_deploy_claim_mismatch",
            readiness["external_audit_summary_consistency_errors"],
        )

    def test_non_boolean_claim_is_fail_closed(self) -> None:
        readiness = self.readiness(
            [],
            summary_overrides={
                "hosted_staging_claim_allowed": "true",
                "production_deploy_claim_allowed": False,
            },
        )

        self.assertEqual(
            readiness["external_audit_expected_missing_or_failed_gates"],
            ["hosted_agent_api_contracts"],
        )
        self.assertIn(
            "claim_not_boolean:hosted_staging_claim_allowed",
            readiness["external_audit_summary_consistency_errors"],
        )

    def test_runtime_summary_preserves_valid_source_provenance(self) -> None:
        payload = self.external_summary_payload()
        summary = self.load_external_summary(payload)

        for field in (
            "local_run_artifact",
            "requested_release_candidate_selector",
            "active_release_candidate_sha",
            "ghcr_published_manifest_ref",
            "ghcr_candidate_readback_source_artifact",
            "gate_ids",
        ):
            self.assertEqual(summary[field], payload[field])
        self.assertTrue(summary["provenance_valid"])
        self.assertEqual(summary["provenance_validation_errors"], [])

    def test_runtime_summary_rejects_forged_provenance(self) -> None:
        canonical_gate_ids = [gate for _, gate in self.CANONICAL_CLAIM_GATES]
        mutations = (
            ("gate_ids", list(reversed(canonical_gate_ids)), "gate_ids_not_canonical"),
            ("gate_ids", canonical_gate_ids + [canonical_gate_ids[-1]], "gate_ids_not_canonical"),
            ("gate_ids", canonical_gate_ids[:-1] + ["unknown_release_gate"], "gate_ids_not_canonical"),
            (
                "requested_release_candidate_selector",
                "A" * 40,
                "requested_release_candidate_selector_invalid",
            ),
            (
                "active_release_candidate_sha",
                "not-a-sha",
                "active_release_candidate_sha_invalid",
            ),
            (
                "active_release_candidate_sha",
                "b" * 40,
                "active_release_candidate_sha_selector_mismatch",
            ),
        )
        for field, forged_value, expected_error in mutations:
            with self.subTest(field=field):
                payload = self.external_summary_payload()
                payload[field] = forged_value
                summary = self.load_external_summary(payload)
                self.assertFalse(summary["provenance_valid"])
                self.assertIn(expected_error, summary["provenance_validation_errors"])
                self.assertEqual(summary["status"], "invalid_summary")
                self.assertFalse(summary["production_deploy_claim_allowed"])

    def test_runtime_summary_rejects_omitted_provenance(self) -> None:
        for field in main.EXTERNAL_AUDIT_REQUIRED_PROVENANCE_FIELDS:
            with self.subTest(field=field):
                payload = self.external_summary_payload()
                del payload[field]
                summary = self.load_external_summary(payload)
                self.assertFalse(summary["provenance_valid"])
                self.assertIn(
                    f"{field}_missing",
                    summary["provenance_validation_errors"],
                )
                self.assertEqual(summary["status"], "invalid_summary")
                self.assertFalse(summary["production_deploy_claim_allowed"])

    def test_verified_ghcr_claim_requires_both_evidence_refs(self) -> None:
        for field in (
            "ghcr_published_manifest_ref",
            "ghcr_candidate_readback_source_artifact",
        ):
            with self.subTest(field=field):
                payload = self.external_summary_payload()
                payload[field] = ""
                summary = self.load_external_summary(payload)
                self.assertFalse(summary["provenance_valid"])
                self.assertIn(
                    f"ghcr_claim_{field}_missing",
                    summary["provenance_validation_errors"],
                )
                self.assertEqual(summary["status"], "invalid_summary")
                self.assertFalse(summary["production_deploy_claim_allowed"])

    def test_surface_contract_requires_the_canonical_missing_gate_alias(self) -> None:
        with patch.object(main, "go_live_readiness_state", return_value={"non_claims": []}):
            contract = main.go_live_readiness_contract_payload()

        self.assertIn(
            "external_audit_expected_missing_or_failed_gates",
            contract["required_top_level_fields"],
        )
        self.assertIn(
            "external_audit_summary_consistent",
            contract["required_top_level_fields"],
        )


if __name__ == "__main__":
    unittest.main()

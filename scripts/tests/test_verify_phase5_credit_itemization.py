from __future__ import annotations

import copy
import subprocess
import unittest
from unittest.mock import patch

from scripts import verify_phase5_credit_itemization as verifier


RELEASE_ID = "prod-candidate-2026-07-31-local-rc11"
SOURCE_SHA = "a" * 40


def summary_proof(chain: str, command: str) -> tuple[dict[str, object], dict[str, object]]:
    anchors = ["successful verification anchor"]
    entry: dict[str, object] = {
        "command": command,
        "success_anchors": anchors,
    }
    proof: dict[str, object] = {
        "contract_version": "phase5-local-verification-summary-v1",
        "chain": chain,
        "release_id": RELEASE_ID,
        "source_commit_sha": SOURCE_SHA,
        "command": command,
        "status": "passed",
        "exit_code": 0,
        "dev_only": True,
        "hosted_proof": False,
        "secret_output": False,
        "raw_log_sha256": "A" * 64,
        "observed_success_anchors": anchors,
        "non_claims": [
            "DEV-ONLY; hosted proof still blocked.",
            "This evidence does not claim production readiness.",
        ],
    }
    return proof, entry


def candidate_images_proof() -> dict[str, object]:
    images: list[dict[str, object]] = []
    for index, service in enumerate(sorted(verifier.EXPECTED_CANDIDATE_SERVICES), start=1):
        images.append(
            {
                "service": service,
                "image_tag": f"cloud-superbrain-production-candidate/{service}:{SOURCE_SHA}",
                "image_id": f"sha256:{index:064x}",
                "image_size_bytes": 1024 + index,
                "dockerfile": f"services/{service}/Dockerfile",
                "dockerfile_sha256": f"{index + 10:064x}",
                "source_file": f"services/{service}/source.py",
                "embedded_file": "/app/source.py",
                "source_file_sha256": f"{index + 20:064x}",
                "embedded_file_sha256": f"{index + 20:064x}",
                "oci_revision": SOURCE_SHA,
                "oci_source": "https://github.com/example/project",
                "oci_version": RELEASE_ID,
            }
        )
    return {
        "contract_version": "phase5-production-candidate-local-v1",
        "evidence_ref": "phase5_local_production_candidate_verified",
        "status": "verified",
        "release_id": RELEASE_ID,
        "source_commit_sha": SOURCE_SHA,
        "source_boundary": "committed_git_archive_only",
        "git_archive_sha256": "b" * 64,
        "service_count": 6,
        "images": images,
        "phase5_progress_before_proof": 68,
        "phase5_progress_after_proof": 68,
        "progress_credit_claimed": False,
        "rollback_target": "c" * 40,
        "rollback_target_source": "active_release_candidate",
        "registry_publish": False,
        "hosted_staging_parity": False,
        "production_deploy": False,
        "release_promotion": False,
        "owner_review_approved": False,
        "secret_output": False,
        "non_claims": [
            "Local image IDs are not GHCR digests.",
            "DEV-ONLY; hosted proof still blocked.",
            "No production deployment or release promotion was performed.",
        ],
    }


def candidate_runtime_proof() -> dict[str, object]:
    return {
        "contract_version": "phase5-production-candidate-local-verification-v1",
        "evidence_ref": "phase5_local_production_candidate_verified",
        "status": "verified",
        "verification_scope": "full_with_browser",
        "release_id": RELEASE_ID,
        "source_commit_sha": SOURCE_SHA,
        "service_count": 6,
        "api_contract_verified": True,
        "local_image_identity_verified": True,
        "embedded_source_hash_parity_verified": True,
        "candidate_runtime_source_parity_verified": True,
        "browser_click_verified": True,
        "rollback_target": "b" * 40,
        "registry_publish": False,
        "hosted_staging_parity": False,
        "production_deploy": False,
        "release_promotion": False,
        "secret_output": False,
    }


class Phase5CreditEvidenceTests(unittest.TestCase):
    def assert_rejected(self, callback, expected: str) -> None:
        with self.assertRaisesRegex(SystemExit, expected):
            callback()

    def test_summary_proof_accepts_bound_canonical_runtime(self) -> None:
        proof, entry = summary_proof("runtime", "npm run verify:runtime")
        verifier.validate_summary_proof("runtime", proof, entry, RELEASE_ID, SOURCE_SHA)

    def test_summary_proof_rejects_anchor_or_source_relabeling(self) -> None:
        proof, entry = summary_proof("browser", "npm run verify:browser")
        relabeled = copy.deepcopy(proof)
        relabeled["source_commit_sha"] = "b" * 40
        self.assert_rejected(
            lambda: verifier.validate_summary_proof("browser", relabeled, entry, RELEASE_ID, SOURCE_SHA),
            "source SHA mismatch",
        )
        proof["observed_success_anchors"] = ["different successful anchor"]
        self.assert_rejected(
            lambda: verifier.validate_summary_proof("browser", proof, entry, RELEASE_ID, SOURCE_SHA),
            "observed anchors do not match readiness",
        )

    def test_security_summary_requires_both_scanners(self) -> None:
        proof, entry = summary_proof("security", "npm audit --audit-level=moderate")
        self.assert_rejected(
            lambda: verifier.validate_summary_proof("security", proof, entry, RELEASE_ID, SOURCE_SHA),
            "canonical security generator or name npm audit and gitleaks",
        )
        command = "pwsh -File scripts/write-rc11-security-evidence.ps1"
        generator_proof, generator_entry = summary_proof("security", command)
        verifier.validate_summary_proof(
            "security",
            generator_proof,
            generator_entry,
            RELEASE_ID,
            SOURCE_SHA,
        )

    def test_candidate_images_accepts_six_bound_unique_images(self) -> None:
        verifier.validate_candidate_images_proof(candidate_images_proof(), RELEASE_ID, SOURCE_SHA)

    def test_candidate_images_rejects_duplicate_service_and_oci_drift(self) -> None:
        duplicate = candidate_images_proof()
        images = duplicate["images"]
        assert isinstance(images, list)
        assert isinstance(images[0], dict) and isinstance(images[1], dict)
        images[1]["service"] = images[0]["service"]
        self.assert_rejected(
            lambda: verifier.validate_candidate_images_proof(duplicate, RELEASE_ID, SOURCE_SHA),
            "service is duplicated",
        )

        oci_drift = candidate_images_proof()
        drift_images = oci_drift["images"]
        assert isinstance(drift_images, list) and isinstance(drift_images[0], dict)
        drift_images[0]["oci_revision"] = "b" * 40
        self.assert_rejected(
            lambda: verifier.validate_candidate_images_proof(oci_drift, RELEASE_ID, SOURCE_SHA),
            "OCI revision mismatch",
        )

    def test_candidate_runtime_requires_full_browser_click_and_source_parity(self) -> None:
        verifier.validate_candidate_runtime_proof(candidate_runtime_proof(), RELEASE_ID, SOURCE_SHA)
        no_click = candidate_runtime_proof()
        no_click["browser_click_verified"] = False
        self.assert_rejected(
            lambda: verifier.validate_candidate_runtime_proof(no_click, RELEASE_ID, SOURCE_SHA),
            "browser_click_verified must be true",
        )
        no_parity = candidate_runtime_proof()
        no_parity["candidate_runtime_source_parity_verified"] = False
        self.assert_rejected(
            lambda: verifier.validate_candidate_runtime_proof(no_parity, RELEASE_ID, SOURCE_SHA),
            "candidate_runtime_source_parity_verified must be true",
        )

    def test_expected_tracked_evidence_paths_are_exact(self) -> None:
        expected = {
            f"docs/release-artifacts/{RELEASE_ID}-evidence/{filename}"
            for filename in verifier.LOCAL_VERIFICATION_FILES.values()
        }
        self.assertEqual(
            expected,
            {
                f"docs/release-artifacts/{RELEASE_ID}-evidence/runtime.json",
                f"docs/release-artifacts/{RELEASE_ID}-evidence/browser.json",
                f"docs/release-artifacts/{RELEASE_ID}-evidence/security.json",
                f"docs/release-artifacts/{RELEASE_ID}-evidence/candidate-images.json",
                f"docs/release-artifacts/{RELEASE_ID}-evidence/candidate-runtime.json",
            },
        )

    def test_runtime_source_parity_includes_and_rejects_deletions(self) -> None:
        deleted_path = "apps/frontend/app/page.tsx"
        captured_args: tuple[str, ...] = ()

        def fake_run_git(*args: str) -> subprocess.CompletedProcess[str]:
            nonlocal captured_args
            captured_args = args
            return subprocess.CompletedProcess(args, 0, f"{deleted_path}\0", "")

        with patch.object(verifier, "run_git", side_effect=fake_run_git):
            self.assert_rejected(
                lambda: verifier.require_runtime_source_parity(SOURCE_SHA, {}, {}, 89),
                "runtime-source drift outside the exact post-qualification truth transition",
            )

        self.assertIn("--diff-filter=ACDMRTUXB", captured_args)


if __name__ == "__main__":
    unittest.main()

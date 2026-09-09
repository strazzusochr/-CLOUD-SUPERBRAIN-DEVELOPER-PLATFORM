from __future__ import annotations

import json
import hashlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from scripts.tests import test_layer5_registry_release_evidence as fixtures

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from verify_candidate_registry_receipts import validate_candidate_registry_receipts


class CandidateRegistryReceiptTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.relative = f"docs/release-artifacts/{fixtures.RELEASE_ID}-evidence/registry"
        self.receipts = self.root / self.relative
        inputs = fixtures.Layer5RegistryReleaseEvidenceTests()._publication_inputs(self.receipts)
        review, registry = fixtures.build_publication_evidence(**inputs)
        fixtures.write_json(self.receipts / "registry-publication-review.json", review)
        fixtures.write_json(self.receipts / "candidate-registry-digests.json", registry)
        self.write_recovery(review, registry)
        self.candidate = self.root / "candidate.md"
        self.write_candidate()

    def write_recovery(self, review: dict[str, object], registry: dict[str, object]) -> None:
        review_path = self.receipts / "registry-publication-review.json"
        registry_path = self.receipts / "candidate-registry-digests.json"
        workflow = review["workflow"]
        artifact = review["artifact"]
        assert isinstance(workflow, dict) and isinstance(artifact, dict)
        fixtures.write_json(self.receipts / "receipt-recovery-provenance.json", {
            "candidate_sha": fixtures.CANDIDATE_SHA,
            "collected_at_utc": "2026-09-09T17:29:43Z",
            "contract_version": "ghcr-publication-receipt-recovery-v1",
            "production_deploy": False,
            "publication_receipt_sha256": hashlib.sha256(review_path.read_bytes()).hexdigest(),
            "recovery_control_sha": "d" * 40,
            "recovery_run_attempt": 1,
            "recovery_run_id": "34383219636",
            "registry_digest_contract_sha256": hashlib.sha256(registry_path.read_bytes()).hexdigest(),
            "registry_write_performed": False,
            "release_promotion": False,
            "repository": "strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM",
            "secret_output": False,
            "source_artifact_digest": artifact["digest"],
            "source_artifact_id": artifact["id"],
            "source_control_sha": fixtures.CONTROL_SHA,
            "source_run_attempt": 1,
            "source_run_id": str(workflow["run_id"]),
            "status": "verified",
        })

    def write_candidate(self, status: str = "verified_candidate") -> None:
        self.candidate.write_text(
            f"release_id: `{fixtures.RELEASE_ID}`\n"
            f"source_commit_sha: `{fixtures.CANDIDATE_SHA}`\n"
            f"immutable_image_commit_sha: `{fixtures.CANDIDATE_SHA}`\n"
            f"immutable_tag_set: `{fixtures.NAMESPACE}/<service>:{fixtures.CANDIDATE_SHA}`\n"
            f"immutable_tag_publish_status: `{status}`\n"
            f"registry_publication_review: `{self.relative}/registry-publication-review.json`\n"
            f"registry_digest_contract: `{self.relative}/candidate-registry-digests.json`\n"
            f"registry_receipt_recovery: `{self.relative}/receipt-recovery-provenance.json`\n"
            "environment: `production-candidate`\nowner_decision: `no-release`\n"
            "hosted_staging_parity: `false`\nThis artifact does not claim a production rollout.\n"
            "Production deployment still requires the release-candidate gate bundle and a separate rollout proof.\n",
            encoding="utf-8",
        )

    def validate(self) -> str:
        with mock.patch("verify_candidate_registry_receipts._git_is_ancestor", return_value=True):
            return validate_candidate_registry_receipts(self.root, self.candidate, fixtures.RELEASE_ID, fixtures.CANDIDATE_SHA)

    def mutate(self, filename: str, change) -> None:
        path = self.receipts / filename
        payload = json.loads(path.read_text(encoding="utf-8"))
        change(payload)
        fixtures.write_json(path, payload)

    def test_valid_published_candidate_passes_without_credit_or_publication(self) -> None:
        before = {path: path.read_bytes() for path in self.receipts.rglob("*") if path.is_file()}
        self.assertEqual(self.validate(), "verified_candidate")
        self.assertEqual(before, {path: path.read_bytes() for path in before})

    def test_unpublished_candidate_needs_no_publication_receipts(self) -> None:
        self.write_candidate("unpublished")
        (self.receipts / "registry-publication-review.json").unlink()
        self.assertEqual(self.validate(), "unpublished")

    def test_recovery_hash_tamper_and_nonclaim_are_rejected(self) -> None:
        self.mutate("receipt-recovery-provenance.json", lambda value: value.update(publication_receipt_sha256="f" * 64))
        with self.assertRaisesRegex(RuntimeError, "publication receipt hash mismatch"):
            self.validate()
        review = json.loads((self.receipts / "registry-publication-review.json").read_text(encoding="utf-8"))
        registry = json.loads((self.receipts / "candidate-registry-digests.json").read_text(encoding="utf-8"))
        self.write_recovery(review, registry)
        self.mutate("receipt-recovery-provenance.json", lambda value: value.update(registry_write_performed=True))
        with self.assertRaisesRegex(RuntimeError, "registry_write_performed non-claim mismatch"):
            self.validate()

    def test_recovery_control_must_descend_from_publication_control(self) -> None:
        (self.root / ".git").write_text("fixture", encoding="ascii")
        with mock.patch("verify_candidate_registry_receipts._git_is_ancestor", return_value=False):
            with self.assertRaisesRegex(RuntimeError, "must descend"):
                validate_candidate_registry_receipts(self.root, self.candidate, fixtures.RELEASE_ID, fixtures.CANDIDATE_SHA)

    def test_source_mismatch_is_rejected(self) -> None:
        self.mutate("candidate-registry-digests.json", lambda value: value.update(source_commit_sha="f" * 40))
        with self.assertRaisesRegex(RuntimeError, "source mismatch"):
            self.validate()

    def test_forged_digest_is_rejected(self) -> None:
        self.mutate("candidate-registry-digests.json", lambda value: value["images"][0].update(digest="sha256:" + "f" * 64))
        with self.assertRaisesRegex(RuntimeError, "top digest mismatch"):
            self.validate()

    def test_incomplete_service_inventory_is_rejected(self) -> None:
        self.mutate("candidate-registry-digests.json", lambda value: value["images"].pop())
        with self.assertRaisesRegex(RuntimeError, "six images"):
            self.validate()

    def test_unapproved_review_is_rejected(self) -> None:
        self.mutate("registry-publication-review.json", lambda value: value["review"].update(state="pending"))
        with self.assertRaisesRegex(RuntimeError, "not approved"):
            self.validate()

    def test_missing_or_tampered_raw_scan_is_rejected(self) -> None:
        scan = next((self.receipts / "trivy-reports").glob("*.json"))
        scan.write_text("{}", encoding="utf-8")
        with self.assertRaisesRegex(RuntimeError, "raw report hash mismatch"):
            self.validate()

    def test_receipt_path_escape_and_duplicate_status_are_rejected(self) -> None:
        original = self.candidate.read_text(encoding="utf-8")
        self.candidate.write_text(original.replace(self.relative, "../foreign"), encoding="utf-8")
        with self.assertRaisesRegex(RuntimeError, "path mismatch"):
            self.validate()
        self.candidate.write_text(original + "immutable_tag_publish_status: `unpublished`\n", encoding="utf-8")
        with self.assertRaisesRegex(RuntimeError, "exactly once"):
            self.validate()

    def test_existing_powershell_candidate_guard_accepts_both_states_and_rejects_forgery(self) -> None:
        powershell = shutil.which("pwsh") or shutil.which("powershell")
        self.assertIsNotNone(powershell, "PowerShell is required to exercise the local candidate guard")
        source = (ROOT / "scripts" / "verify-phase5-production-candidate-local.ps1").read_text(encoding="utf-8")
        start = source.index("  foreach ($marker in @(\n    'environment:")
        guard = source[start:source.index('  $source = Get-Content', start)]
        interpreter = sys.executable.replace("'", "''")
        script = """param([string]$Fixture)
$ErrorActionPreference = 'Stop'
$inputData = Get-Content -LiteralPath $Fixture -Raw | ConvertFrom-Json
$repoRoot = $inputData.root
$candidatePath = $inputData.candidate
$candidate = Get-Content -LiteralPath $candidatePath -Raw
$candidateConfig = [pscustomobject]@{active_release_id=$inputData.release_id}
$candidateSourceSha = $inputData.source_sha
function Assert-True([string]$Label, $Condition) { if (-not $Condition) { throw $Label } }
""" + f"function py {{ & '{interpreter}' @($args | Select-Object -Skip 1); $global:LASTEXITCODE = $LASTEXITCODE }}\n" + guard
        script_path = self.root / "guard.ps1"
        script_path.write_text(script, encoding="utf-8")
        fixture_path = fixtures.write_json(self.root / "guard-input.json", {
            "root": str(self.root), "candidate": str(self.candidate),
            "release_id": fixtures.RELEASE_ID, "source_sha": fixtures.CANDIDATE_SHA,
        })
        for status, forged, expected in (("unpublished", False, 0), ("verified_candidate", False, 0), ("verified_candidate", True, 1)):
            with self.subTest(status=status, forged=forged):
                self.write_candidate(status)
                if forged:
                    self.mutate("candidate-registry-digests.json", lambda value: value.update(source_commit_sha="f" * 40))
                result = subprocess.run([powershell, "-NoProfile", "-File", str(script_path), str(fixture_path)], cwd=ROOT, capture_output=True, text=True, timeout=30, check=False)
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()

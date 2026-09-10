from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WRITER = ROOT / "scripts" / "write-market-ready-owner-request.ps1"
VERIFIER = ROOT / "scripts" / "verify-market-ready-owner-request.ps1"


class MarketReadyOwnerRequestTests(unittest.TestCase):
    def test_writer_confines_output_to_platform_temp_or_request_root(self) -> None:
        source = WRITER.read_text(encoding="utf-8")
        self.assertNotIn("& git.exe ", source)
        self.assertIn("[IO.Path]::GetFullPath([IO.Path]::GetTempPath())", source)
        self.assertIn("output is confined to a temporary/request artifact root", source)

    def test_writer_and_verifier_emit_no_authorization_or_credit(self) -> None:
        head = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
        with tempfile.TemporaryDirectory() as temp_dir:
            output = Path(temp_dir) / "owner-request.json"
            writer = subprocess.run(
                [
                    "pwsh",
                    "-NoProfile",
                    "-File",
                    str(WRITER),
                    "-SourceSha",
                    head,
                    "-QualificationSha",
                    head,
                    "-ReleaseId",
                    "prod-candidate-2026-09-02-local-rc999",
                    "-OutputPath",
                    str(output),
                ],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(writer.returncode, 0, writer.stdout + writer.stderr)
            verifier = subprocess.run(
                [
                    "pwsh",
                    "-NoProfile",
                    "-File",
                    str(VERIFIER),
                    "-RequestPath",
                    str(output),
                    "-ExpectedSourceSha",
                    head,
                    "-ExpectedQualificationSha",
                    head,
                ],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(verifier.returncode, 0, verifier.stdout + verifier.stderr)
            request = json.loads(output.read_text(encoding="utf-8-sig"))
            self.assertEqual(len(request["actions"]), 8)
            self.assertTrue(all(action["owner_decision"] == "pending" for action in request["actions"]))
            self.assertEqual(request["evidence_policy"]["percentage_credit_from_request"], 0)
            self.assertFalse(request["evidence_policy"]["secret_output"])

    def test_verifier_rejects_grant_or_credit_in_request(self) -> None:
        source = VERIFIER.read_text(encoding="utf-8")
        self.assertIn("all decisions remain pending", source)
        self.assertIn("no credit", source)
        self.assertIn("secret output false", source)
        self.assertIn("no credential-shaped fields", source)

    def test_finish_line_requires_source_truth_projection_binding_at_100(self) -> None:
        market_ready = (ROOT / "scripts" / "verify-market-ready.ps1").read_text(encoding="utf-8")
        candidate = (ROOT / "scripts" / "verify-current-release-candidate.ps1").read_text(encoding="utf-8")
        self.assertIn('Add-Result "source-truth-projection-binding"', market_ready)
        self.assertIn("$allHundred -and $overallHundred", market_ready)
        self.assertIn("--require-ready", market_ready)
        self.assertIn("dual_binding_transition=", candidate)
        self.assertIn("verify_source_truth_projection_binding.py", candidate)


if __name__ == "__main__":
    unittest.main()

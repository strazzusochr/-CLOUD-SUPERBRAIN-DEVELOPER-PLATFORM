from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class SourceQualificationControlTests(unittest.TestCase):
    def test_writer_and_verifier_bind_release_to_source_without_credit(self) -> None:
        with tempfile.TemporaryDirectory(dir="D:\\_sb_tmp") as temp_dir:
            repo = Path(temp_dir)
            (repo / "scripts").mkdir(parents=True)
            shutil.copy2(ROOT / "scripts" / "write-source-qualification-control.ps1", repo / "scripts")
            shutil.copy2(ROOT / "scripts" / "verify-source-qualification-control.ps1", repo / "scripts")
            subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
            subprocess.run(["git", "config", "user.email", "test@example.invalid"], cwd=repo, check=True)
            subprocess.run(["git", "config", "user.name", "Test"], cwd=repo, check=True)
            (repo / "source.txt").write_text("source\n", encoding="utf-8")
            subprocess.run(["git", "add", "."], cwd=repo, check=True)
            subprocess.run(["git", "commit", "-qm", "source"], cwd=repo, check=True)
            source = subprocess.run(
                ["git", "rev-parse", "HEAD"], cwd=repo, capture_output=True, text=True, check=True
            ).stdout.strip()
            release = "prod-candidate-2026-09-02-local-rc999"
            writer = subprocess.run(
                [
                    "pwsh",
                    "-NoProfile",
                    "-File",
                    str(repo / "scripts" / "write-source-qualification-control.ps1"),
                    "-SourceSha",
                    source,
                    "-ReleaseId",
                    release,
                ],
                cwd=repo,
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
                    str(repo / "scripts" / "verify-source-qualification-control.ps1"),
                    "-ExpectedSourceSha",
                    source,
                    "-ExpectedReleaseId",
                    release,
                ],
                cwd=repo,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(verifier.returncode, 0, verifier.stdout + verifier.stderr)
            control = json.loads((repo / "docs/runtime-state/source-qualification-control.json").read_text(encoding="utf-8-sig"))
            self.assertEqual(control["runtime_candidate_sha"], source)
            self.assertRegex(control["source_archive_sha256"], r"^[0-9a-f]{64}$")
            self.assertEqual(control["percentage_credit_awarded"], 0)
            self.assertFalse(control["production_rollout_claimed"])
            self.assertFalse(control["secret_output"])

    def test_pr_check_accepts_only_the_control_json_in_new_mode(self) -> None:
        workflow = (ROOT / ".github/workflows/pr-check.yml").read_text(encoding="utf-8")
        self.assertIn('qualification_control_path = "docs/runtime-state/source-qualification-control.json"', workflow)
        self.assertIn("control_delta != [qualification_control_path]", workflow)
        self.assertIn("source qualification control candidate mismatch", workflow)
        self.assertIn("source qualification control archive hash mismatch", workflow)
        self.assertIn("source qualification control may not award credit", workflow)


if __name__ == "__main__":
    unittest.main()

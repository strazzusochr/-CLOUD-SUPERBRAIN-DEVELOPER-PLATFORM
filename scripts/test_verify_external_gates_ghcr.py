from __future__ import annotations

import re
import subprocess
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
EXTERNAL_GATES = REPO_ROOT / "scripts" / "verify-external-gates.ps1"


class ExternalGateGhcrBindingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = EXTERNAL_GATES.read_text(encoding="utf-8-sig")
        match = re.search(
            r"(?ms)^function Invoke-GhcrCandidateProbe\b(?P<body>.*?)(?=^function\s|^\$localBase\s*=)",
            cls.source,
        )
        if match is None:
            raise AssertionError("Invoke-GhcrCandidateProbe function is missing")
        cls.function_body = match.group("body")

    def test_powershell_source_parses(self) -> None:
        command = (
            "$tokens=$null; $errors=$null; "
            f"[System.Management.Automation.Language.Parser]::ParseFile('{EXTERNAL_GATES}',"
            "[ref]$tokens,[ref]$errors) > $null; "
            "if($errors.Count){$errors | % Message; exit 1}"
        )
        completed = subprocess.run(
            ["pwsh", "-NoProfile", "-Command", command],
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)

    def test_registry_gate_has_no_mutable_tag_default(self) -> None:
        parameter_block = self.source.split(")\n\n$ErrorActionPreference", 1)[0]
        self.assertNotIn("$ImageTag", parameter_block)
        self.assertNotIn("$env:IMAGE_TAG", parameter_block)
        self.assertIn("$ActiveReleaseCandidateSha", parameter_block)
        self.assertIn("$env:ACTIVE_RELEASE_CANDIDATE_SHA", parameter_block)
        self.assertRegex(self.function_body, r"\^\[0-9a-f\]\{40\}\$")
        self.assertIn("mutable tags are rejected", self.function_body)

    def test_registry_gate_delegates_only_to_read_only_exact_verifier(self) -> None:
        self.assertIn("scripts\\verify_ghcr_candidate.py", self.function_body)
        self.assertIn('"--source-manifest"', self.function_body)
        self.assertIn('"--active-candidate-sha"', self.function_body)
        self.assertIn('"--candidate-sha"', self.function_body)
        self.assertNotRegex(self.function_body, r"docker\s+(?:push|tag|manifest\s+push)")
        self.assertNotIn("buildx build", self.function_body)

    def test_registry_gate_requires_full_digest_and_provenance_readback(self) -> None:
        for anchor in (
            "source_manifest_bound",
            "digest_readback_matches_publication",
            "inspected_image_count",
            "inspected_platform_manifest_count",
            "active_release_candidate.source_commit_sha",
            "active_release_candidate.image_tag",
            "selected_tag_is_exact_candidate_sha",
            "registry_write_performed",
            "registry_delete_performed",
        ):
            self.assertIn(anchor, self.function_body)
        self.assertIn("ghcr_candidate_readback", self.source)
        self.assertIn("active_release_candidate_sha = [string]$summary.active_release_candidate_sha", self.source)


if __name__ == "__main__":
    unittest.main()

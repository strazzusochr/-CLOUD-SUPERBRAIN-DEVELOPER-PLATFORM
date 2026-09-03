from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "verify-o4-effective-compose.ps1"


class O4EffectiveComposeGuardTests(unittest.TestCase):
    def test_canonical_effective_compose_is_verified(self) -> None:
        result = subprocess.run(
            [
                "pwsh",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(SCRIPT),
                "-RepoRoot",
                str(ROOT),
            ],
            cwd=ROOT,
            text=True,
            capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("[o4-effective-compose] PASS", result.stdout)

    def test_repository_local_docker_shadow_is_rejected_before_execution(self) -> None:
        with tempfile.TemporaryDirectory(prefix="o4-compose-shadow-") as temporary:
            fake_root = Path(temporary)
            fake_docker = fake_root / ("docker.exe" if os.name == "nt" else "docker")
            fake_docker.write_bytes(b"this file must never be executed")
            result = subprocess.run(
                [
                    "pwsh",
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(SCRIPT),
                    "-RepoRoot",
                    str(fake_root),
                    "-DockerExecutable",
                    str(fake_docker),
                ],
                cwd=ROOT,
                text=True,
                capture_output=True,
            )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("shadow executable is forbidden", result.stderr)


if __name__ == "__main__":
    unittest.main()

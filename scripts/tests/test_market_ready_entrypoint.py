from __future__ import annotations

import json
import shutil
import subprocess
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]


class MarketReadyEntrypointTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        npm = shutil.which("npm")
        if npm is None:
            raise unittest.SkipTest("npm is unavailable")
        completed = subprocess.run(
            [npm, "pkg", "get", "scripts"],
            cwd=REPO_ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
        cls.scripts = json.loads(completed.stdout)

    def test_plain_market_ready_runs_the_external_gate_audit(self) -> None:
        command = self.scripts["verify:market-ready"]
        self.assertIn(" -IncludeExternalGates", command)
        self.assertNotIn(" -RequireReady", command)

    def test_static_audit_stays_offline_and_require_ready_stays_fail_closed(self) -> None:
        static_command = self.scripts["verify:market-ready:static"]
        require_ready_command = self.scripts["verify:market-ready:require-ready"]
        self.assertNotIn(" -IncludeExternalGates", static_command)
        self.assertIn(" -IncludeExternalGates", require_ready_command)
        self.assertIn(" -RequireReady", require_ready_command)


if __name__ == "__main__":
    unittest.main()

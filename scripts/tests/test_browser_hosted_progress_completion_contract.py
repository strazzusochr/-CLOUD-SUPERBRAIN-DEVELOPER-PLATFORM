from __future__ import annotations

import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
VERIFIERS = (
    REPO_ROOT / "scripts" / "verify-browser-contract.ps1",
    REPO_ROOT / "scripts" / "verify-hosted-staging.ps1",
)


class BrowserHostedProgressCompletionContractTests(unittest.TestCase):
    def test_verifiers_derive_blocked_or_ready_from_progress_and_blockers(self) -> None:
        for verifier in VERIFIERS:
            source = verifier.read_text(encoding="utf-8")
            with self.subTest(verifier=verifier.name):
                for marker in (
                    "$expectedProjectProgressCompletionReady",
                    '"ready_for_100_percent_review"',
                    '"blocked_external_gates"',
                    "can_set_all_to_100",
                    "missing_external_gates",
                    "hard_blockers",
                ):
                    self.assertIn(marker, source)

                self.assertNotIn(
                    'Assert-Contains "project progress completion status" $projectProgressCompletion \'"status":"blocked_external_gates"\'',
                    source,
                )
                self.assertNotIn(
                    'Assert-Contains "project progress completion cannot set all to 100" $projectProgressCompletion \'"can_set_all_to_100":false\'',
                    source,
                )

    def test_paused_clock_browser_paths_do_not_wait_for_networkidle(self) -> None:
        source = (REPO_ROOT / "apps" / "frontend" / "e2e" / "organism.spec.ts").read_text(encoding="utf-8")
        clock_sections = source.split("page.clock.install")[1:]
        self.assertGreaterEqual(len(clock_sections), 2)
        for index, section in enumerate(clock_sections, start=1):
            before_pause = section.split("page.clock.pauseAt", maxsplit=1)[0]
            with self.subTest(clock_section=index):
                self.assertNotIn('waitUntil: "networkidle"', before_pause)
                self.assertIn('waitUntil: "domcontentloaded"', before_pause)


if __name__ == "__main__":
    unittest.main()

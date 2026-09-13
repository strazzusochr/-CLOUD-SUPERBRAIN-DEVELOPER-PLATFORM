from __future__ import annotations

import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
CONSUMERS = (
    "scripts/verify-phase1-runtime.ps1",
    "scripts/verify-browser-contract.ps1",
    "scripts/verify-hosted-staging.ps1",
    "scripts/verify-go-live-readiness.ps1",
    "scripts/verify-current-release-candidate.ps1",
)
MIRROR_CONSUMERS = CONSUMERS[:4]


class ExternalGateTargetConsumerTests(unittest.TestCase):
    def test_current_truth_consumers_derive_the_active_target(self) -> None:
        for relative in CONSUMERS:
            with self.subTest(script=relative):
                source = (REPO_ROOT / relative).read_text(encoding="utf-8-sig")
                self.assertIn("$expectedActiveTarget", source)
                self.assertIn("missing_or_failed_gates", source)
                self.assertNotIn("active Cloudflare target", source)
                self.assertIsNone(
                    re.search(
                        r"active_target_gate\s+-(?:c)?(?:eq|ne)\s+"
                        r"[\"']cloudflare_native_zero_card_hosted_runtime[\"']",
                        source,
                    )
                )

    def test_current_truth_consumers_bind_summary_and_audit_missing_sets(self) -> None:
        for relative in MIRROR_CONSUMERS:
            with self.subTest(script=relative):
                source = (REPO_ROOT / relative).read_text(encoding="utf-8-sig")
                self.assertIn("$canonicalMissingGates", source)
                self.assertRegex(source, r"AuditMissingGates")
                self.assertRegex(source, r"missing (?:gate|set).*parity|missing-set exact parity")


if __name__ == "__main__":
    unittest.main()

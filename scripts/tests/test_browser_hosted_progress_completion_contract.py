from __future__ import annotations

import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
VERIFIERS = (
    REPO_ROOT / "scripts" / "verify-browser-contract.ps1",
    REPO_ROOT / "scripts" / "verify-hosted-staging.ps1",
)


class BrowserHostedProgressCompletionContractTests(unittest.TestCase):
    def test_runtime_completion_blockers_follow_current_capability_gate_state(self) -> None:
        source = (REPO_ROOT / "scripts" / "verify-phase1-runtime.ps1").read_text(encoding="utf-8")
        for marker in (
            "$completionGateExpectations = @(",
            'gate_id = "production_auth_identity"',
            'gate_id = "docker_registry_publish"',
            'blocker = "production_auth_identity_requires_owner_configured_oauth_and_hosted_url"',
            'blocker = "docker_registry_publish_requires_owner_release_gate"',
            'Assert-False "project progress completion verified gate blocker absent:',
            'Assert-True "project progress completion closed gate blocker present:',
        ):
            self.assertIn(marker, source)

    def test_runtime_compose_recreates_use_the_worktree_head_override(self) -> None:
        source = (REPO_ROOT / "scripts" / "verify-phase1-runtime.ps1").read_text(encoding="utf-8")
        self.assertIn('git rev-parse --path-format=absolute --git-path HEAD', source)
        self.assertIn('target: /app/o4-git/HEAD', source)
        self.assertIn('$composeArgs += @("-f", $shimPath)', source)
        self.assertEqual(source.count("docker compose @composeArgs"), 3)
        self.assertNotIn("docker compose -f docker-compose.dev.yml", source)

    def test_runtime_candidate_proof_uses_the_active_release_evidence_directory(self) -> None:
        source = (REPO_ROOT / "scripts" / "verify-phase1-runtime.ps1").read_text(encoding="utf-8")
        self.assertIn('$activeCandidatePointer = Get-Content -LiteralPath "docs\\release-artifacts\\current-release-candidate.json"', source)
        self.assertIn('$activeCandidateEvidenceDir = Join-Path "docs\\release-artifacts"', source)
        self.assertIn('-ArtifactDir $activeCandidateEvidenceDir', source)

    def test_runtime_recreate_loads_only_the_existing_local_service_and_oauth_secrets(self) -> None:
        source = (REPO_ROOT / "scripts" / "verify-phase1-runtime.ps1").read_text(encoding="utf-8")
        self.assertIn('$runtimeComposeSecretKeys = @(', source)
        for key in (
            "AGENT_API_AUTH_TOKEN",
            "GITHUB_OAUTH_CLIENT_ID",
            "GITHUB_OAUTH_CLIENT_SECRET",
            "GITHUB_OAUTH_REDIRECT_URI",
            "GITHUB_OAUTH_OWNER_IDS",
            "JWT_SIGNING_SECRET",
        ):
            self.assertIn(f'"{key}"', source)
        self.assertIn('[Environment]::SetEnvironmentVariable($secretKey, $secretValue, "Process")', source)
        self.assertNotIn('Write-Host $secretValue', source)

    def test_accessibility_evidence_capture_follows_unfiltered_network_assertions(self) -> None:
        source = (REPO_ROOT / "apps" / "frontend" / "e2e" / "organism.spec.ts").read_text(encoding="utf-8")
        body = source.split('test("organism Phase-6 accessibility honors', 1)[1].split('\n  test(', 1)[0]
        capture = body.index('captureAccessibilityRequests = true;')
        network_assertion = body.index('expect(accessibilityRequests, "accessibility controls remain browser-local").toEqual([])')
        error_assertion = body.index('expect(errors, "no console/page errors during accessibility interactions").toEqual([])')
        capture_end = body.index('captureAccessibilityRequests = false;', capture)
        screenshot = body.index('await page.screenshot(')
        self.assertLess(capture, network_assertion)
        self.assertLess(network_assertion, capture_end)
        self.assertLess(error_assertion, capture_end)
        self.assertLess(capture_end, screenshot)
        self.assertIn('accessibilityRequests.push(request.url());', body)
        self.assertNotIn('next-router-prefetch', body)
        self.assertNotIn('_rsc', body)

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

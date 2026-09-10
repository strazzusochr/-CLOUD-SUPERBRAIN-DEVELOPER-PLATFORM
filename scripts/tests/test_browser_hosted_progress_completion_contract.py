from __future__ import annotations

import copy
import importlib
import json
import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[2]
VERIFIERS = (
    REPO_ROOT / "scripts" / "verify-browser-contract.ps1",
    REPO_ROOT / "scripts" / "verify-hosted-staging.ps1",
    REPO_ROOT / "scripts" / "verify-phase1-runtime.ps1",
)


class BrowserHostedProgressCompletionContractTests(unittest.TestCase):
    def test_dev_codegen_is_container_local_and_checkpoint_restart_is_targeted(self) -> None:
        compose = (REPO_ROOT / 'docker-compose.dev.yml').read_text(encoding='utf-8')
        frontend = compose.split('  frontend:\n', 1)[1].split('\n  agent-api:', 1)[0]
        self.assertNotIn('./apps/frontend/next-env.d.ts:', frontend)
        self.assertIn('./apps/frontend/tsconfig.json:/app/tsconfig.json:ro', frontend)
        self.assertIn('read_only: true', frontend)
        self.assertIn('- /tmp', frontend)
        dockerfile = (REPO_ROOT / 'apps/frontend/Dockerfile').read_text(encoding='utf-8')
        dev = dockerfile.split(' AS dev-runner\n', 1)[1].split('\nFROM ', 1)[0]
        self.assertIn('next-env.template.d.ts', dev)
        self.assertIn('ln -s /tmp/superbrain-next-env.d.ts /app/next-env.d.ts', dev)
        self.assertIn('exec npm run dev', dev)
        runtime = (REPO_ROOT / 'scripts/verify-phase1-runtime.ps1').read_text(encoding='utf-8')
        self.assertIn('up -d --no-deps --force-recreate agent-api nginx', runtime)
        self.assertNotIn('up -d --force-recreate agent-api nginx', runtime)

    def test_all_http_verifiers_replay_credit_before_accepting_the_projection(self) -> None:
        for verifier in VERIFIERS:
            source = verifier.read_text(encoding="utf-8")
            with self.subTest(verifier=verifier.name):
                self.assertIn('verify_project_progress_projection.py', source)
                self.assertLess(source.index('verify_project_progress_projection.py'), source.index('/api/v1/project/progress/completion'))
                self.assertIn('project progress completion has exactly one Layer 4 item', source)
                self.assertNotIn('[int]$layer4Progress[0].percent -lt 100', source)
        static = (REPO_ROOT / 'scripts/verify-phase1.ps1').read_text(encoding='utf-8')
        self.assertNotIn('[int]$layer4Progress[0].percent -ge 100', static)
        self.assertIn('py -3 scripts\\verify_project_progress_manifest.py', static)
        for stale in ('"Layer 4 equal 100"', '\'"can_set_all_to_100":false\'', '\'"status":"blocked_external_gates"\''):
            self.assertNotIn(stale, static)

    def test_actual_powershell_completion_logic_accepts_only_the_correct_state(self) -> None:
        # Execute the real, network-free assertion block, not a Python reimplementation.
        cases = []
        for total, complete, missing, hard in ((90, False, [], []), (100, True, [], []), (100, True, ['hosted'], []), (100, True, [], ['identity'])):
            ready = total == 100 and complete and not missing and not hard
            expected = {'current_overall_percent': total, 'status': 'ready_for_100_percent_review' if ready else 'blocked_external_gates', 'can_set_all_to_100': bool(ready)}
            cases.append({'total': total, 'complete': complete, 'missing': missing, 'hard': hard, 'response': expected, 'accept': True})
            for field, value in (('status', 'blocked_external_gates' if ready else 'ready_for_100_percent_review'), ('can_set_all_to_100', not ready), ('can_set_all_to_100', str(ready).lower()), ('current_overall_percent', 99)):
                cases.append({'total': total, 'complete': complete, 'missing': missing, 'hard': hard, 'response': {**expected, field: value}, 'accept': False})
        for verifier in VERIFIERS:
            source = verifier.read_text(encoding='utf-8')
            start = source.index('$projectProgressItems = @(')
            end = source.index('$capabilityGateState =', start)
            # Hosted also checks the local gap blocker here; supply it for incomplete input.
            fixtures = copy.deepcopy(cases)
            for case in fixtures:
                if not case['complete']:
                    case['hard'].append('local_progress_gaps_require_verified_evidence_for_each_phase_and_layer')
            script = r'''
$ErrorActionPreference = 'Stop'
function Assert-True($label, $condition) { if (-not $condition) { throw $label } }
$cases = [Console]::In.ReadToEnd() | ConvertFrom-Json
foreach ($case in $cases) {
  $expectedOverallPercent = [int]$case.total
  $progressManifest = [pscustomobject]@{
    horizontal = [pscustomobject]@{ items = @([pscustomobject]@{percent= $(if($case.complete){100}else{44})}) }
    vertical = [pscustomobject]@{ items = @([pscustomobject]@{percent=100}) }
  }
  $projectProgressCompletionJson = $case.response
  $projectProgressCompletionMissingGates = @($case.missing)
  $projectProgressCompletionHardBlockers = @($case.hard)
  $accepted = $true
  try { & {
''' + source[start:end] + r'''
  } } catch { $accepted = $false }
  if ($accepted -ne [bool]$case.accept) { throw 'completion fixture expectation mismatch' }
}
Write-Output 'completion-fixtures-pass'
'''
            result = subprocess.run(['pwsh', '-NoProfile', '-NonInteractive', '-Command', script], input=json.dumps(fixtures), text=True, capture_output=True, timeout=30, cwd=REPO_ROOT)
            with self.subTest(verifier=verifier.name):
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('completion-fixtures-pass', result.stdout)

    def test_projection_cli_replays_real_committed_evidence_without_a_release_claim(self) -> None:
        result = subprocess.run(
            [sys.executable, 'scripts/verify_project_progress_projection.py'],
            cwd=REPO_ROOT, capture_output=True, text=True, timeout=120,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('ledger_and_mirrors_verified=true', result.stdout)
        self.assertIn('candidate_qualification_checked=false', result.stdout)
        self.assertIn('release_readiness_claimed=false', result.stdout)
        self.assertIn('new_credit=0', result.stdout)

    def test_projection_guard_rejects_unbacked_or_tampered_credit(self) -> None:
        guard = importlib.import_module('scripts.verify_project_progress_projection')
        core = guard.progress
        original_load = core.load_json
        original_ledger = original_load(REPO_ROOT / core.DELTA_LEDGER_PATH)
        self.assertTrue(any(entry['cell_id'] == 'layer_4' for entry in original_ledger['entries']))
        # Only fixture input is replaced. The real pinned baseline, ancestry,
        # committed-blob hashes, approved scorers and mirror checks all execute.
        mutations = (
            ('missing_credit', lambda ledger, entry: ledger.update(entries=[])),
            ('baseline_inflation', lambda ledger, entry: ledger['baseline'].update(overall_percent=100)),
            ('wrong_artifact_hash', lambda ledger, entry: entry.update(artifact_sha256='0' * 64)),
            ('missing_source', lambda ledger, entry: entry.update(source_sha='0' * 40)),
            ('missing_artifact', lambda ledger, entry: entry.update(artifact_path='docs/release-artifacts/nonexistent-hosted-proof.json')),
            ('bounded_o6_not_hosted_credit', lambda ledger, entry: entry.update(verifier_command='python scripts/verify-live-llm-evidence-chain.ps1')),
            ('wrong_projection_hash', lambda ledger, entry: entry.update(projection_sha256='0' * 64)),
        )
        for name, mutate in mutations:
            ledger = copy.deepcopy(original_ledger)
            entry = next(item for item in ledger['entries'] if item['cell_id'] == 'layer_4')
            mutate(ledger, entry)

            def fixture_load(path: Path):
                return ledger if path == REPO_ROOT / core.DELTA_LEDGER_PATH else original_load(path)

            with self.subTest(case=name), patch.object(core, 'load_json', side_effect=fixture_load):
                with self.assertRaises(SystemExit):
                    guard.verify_projection(REPO_ROOT)

    def test_projection_guard_does_not_replace_the_full_candidate_checks(self) -> None:
        source = (REPO_ROOT / 'scripts/verify_project_progress_manifest.py').read_text(encoding='utf-8')
        main = source.split('def main() -> int:', 1)[1]
        self.assertIn('validate_current_candidate_freshness(', main)
        self.assertIn('phase5_result.returncode == 0', main)
        guard = (REPO_ROOT / 'scripts/verify_project_progress_projection.py').read_text(encoding='utf-8')
        self.assertIn('progress.validate_progress_truth(', guard)
        self.assertNotIn('APPROVED_DELTA_SCORERS =', guard)
        self.assertNotIn('resolve_delta_ledger_path', guard)

    def test_static_cross_references_execute_against_the_current_http_verifiers(self) -> None:
        script = r'''
$ErrorActionPreference = 'Stop'
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path (Get-Location) 'scripts/verify-phase1.ps1'), [ref]$null, [ref]$null)
$blocks = @($ast.FindAll({ param($node)
  if ($node -isnot [System.Management.Automation.Language.ForEachStatementAst]) { return $false }
  foreach ($name in @('$runtimeVerifier', '$hostedVerifier', '$browserContractScript')) {
    if ($node.Extent.Text.Contains($name + '.Contains($required)')) { return $true }
  }
  return $false
}, $true))
if ($blocks.Count -lt 23) { throw 'static verifier reference blocks are missing' }
$runtimeVerifier = Get-Content scripts/verify-phase1-runtime.ps1 -Raw
$hostedVerifier = Get-Content scripts/verify-hosted-staging.ps1 -Raw
$browserContractScript = Get-Content scripts/verify-browser-contract.ps1 -Raw
foreach ($block in $blocks) { & ([scriptblock]::Create($block.Extent.Text)) }
'''
        result = subprocess.run(['pwsh', '-NoProfile', '-NonInteractive', '-Command', script], cwd=REPO_ROOT, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)

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
        self.assertIn('$activeCandidateImages = Join-Path $activeCandidateEvidenceDir "candidate-images.json"', source)
        self.assertIn("superbrain-phase1-runtime-candidate", source)
        self.assertIn('$runtimeCandidateRelativeDir = Join-Path ".runtime-temp\\superbrain-phase1-runtime-candidate"', source)
        self.assertIn('Copy-Item -LiteralPath $activeCandidateImages', source)
        self.assertIn('-ArtifactDir $runtimeCandidateRelativeDir', source)
        self.assertIn('Remove-Item -LiteralPath $runtimeCandidateArtifactDir -Recurse -Force', source)

    def test_runtime_o4_proof_uses_bounded_temporary_evidence(self) -> None:
        source = (REPO_ROOT / "scripts" / "verify-phase1-runtime.ps1").read_text(encoding="utf-8")
        self.assertIn("superbrain-phase1-runtime-o4", source)
        self.assertIn('-RuntimeReportPath $runtimeO4ReportPath', source)
        self.assertIn('Remove-Item -LiteralPath $runtimeO4ArtifactDir -Recurse -Force', source)
        self.assertNotIn(
            'scripts\\verify-o4-live-writes.ps1 -BaseUrl $baseUrl -AllowLocalhost -RuntimeProof\n',
            source.replace("`r`n", "`n"),
        )

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

param(
  [string]$ReleaseId = "prod-candidate-2026-05-05-rc1",
  [string]$BaseUrl = $(if ($env:STAGING_BASE_URL) { $env:STAGING_BASE_URL } else { "" })
)

$ErrorActionPreference = "Stop"

function Assert-HostedBaseUrlConfigured {
  if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    throw "Hosted verifier requires -BaseUrl or env:STAGING_BASE_URL (HTTPS, non-localhost)."
  }
  if ($BaseUrl -notmatch '^https://') {
    throw "Hosted verifier requires an HTTPS BaseUrl."
  }
  if ($BaseUrl -match 'localhost|127\.0\.0\.1|\[::1\]|0\.0\.0\.0|host\.docker\.internal') {
    throw "Hosted verifier refuses localhost and loopback BaseUrl values."
  }
}
Assert-HostedBaseUrlConfigured


function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Verification failed: $label did not contain '$expected'."
  }
}

function Assert-Equal($label, $actual, $expected) {
  if ($actual -ne $expected) {
    throw "Verification failed: $label expected '$expected' but got '$actual'."
  }
}

function Get-Json($uri) {
  $python = @"
import urllib.request
with urllib.request.urlopen(r'''$uri''', timeout=30) as response:
    print(response.read().decode("utf-8"))
"@
  $content = $python | py -3 -
  return ($content | ConvertFrom-Json)
}

$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase4 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_4" }).percent)
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)
$artifactPath = "docs\release-artifacts\$ReleaseId-checklist-conformance.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing checklist conformance artifact: $artifactPath"
}
$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "release_id: ``$ReleaseId``",
  "overall_percent: ``$expectedOverall``",
  "phase_4_percent: ``$expectedPhase4``",
  "phase_5_percent: ``$expectedPhase5``",
  'integrity_status: `verified`',
  'external_gates_status: `verified`',
  'completion_can_set_all_to_100: `false`',
  'owner_decision: `no-release`',
  'Code Readiness',
  'Infrastructure Readiness',
  'Observability Readiness',
  'Operations Readiness'
)) {
  Assert-Contains "checklist conformance artifact" $artifact $required
}

$candidatePath = "docs\release-artifacts\$ReleaseId.md"
if (-not (Test-Path $candidatePath)) {
  throw "Missing candidate artifact: $candidatePath"
}
$candidate = Get-Content $candidatePath -Raw
Assert-Contains "candidate checklist proof linked" $candidate 'checklist_conformance_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-checklist-conformance.md`'
Assert-Contains "candidate evidence checklist proof linked" $candidate 'Checklist conformance proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-checklist-conformance.md`'

foreach ($required in @(
  '## Code Readiness',
  '## Infrastructure Readiness',
  '## Observability Readiness',
  '## Operations Readiness',
  '- [x] CI/CD successful',
  '- [x] Smoke successful',
  '- [x] Hosted staging verified',
  '- [x] GHCR candidate images verified',
  '- [x] Rollback runbook applicable',
  '- [x] Incident response runbook present',
  '- [x] Secret rotation runbook present',
  '- [x] Owner review documented',
  '- [x] Production non-claim preserved until rollout proof exists'
)) {
  Assert-Contains "candidate checklist sections" $candidate $required
}

foreach ($required in @(
  'release_id: `prod-candidate-2026-05-05-rc1`',
  'source_branch:',
  'source_commit_sha:',
  'workflow_run_url:',
  'pipeline_status:',
  'immutable_tag_set:',
  'owner_decision_proof:',
  'executed_rollback_rerun_proof:',
  'budget_review_proof:',
  'open_questions_acceptance_proof:',
  'provenance_review_proof:',
  'smoke_recheck_proof:',
  'observability_recheck_proof:',
  'browser_evidence_reactivation_proof:',
  'browser_proof:',
  'post_rollback_browser_revalidation_proof:',
  'final_browser_e2e_recheck_proof:',
  'full_verifier_sweep_proof:',
  'truth_mirror_rebaseline_proof:',
  'release_readiness_rerun_proof:',
  'review_gate: `reviewed`',
  'owner_decision: `no-release`',
  'rollback_note:'
)) {
  Assert-Contains "candidate required fields" $candidate $required
}

$health = Get-Json "$BaseUrl/api/v1/health"
Assert-Equal "hosted health status" $health.status "healthy"

$progress = Get-Json "$BaseUrl/api/v1/project/progress"
$phase4 = $progress.horizontal.items | Where-Object { $_.id -eq "phase_4" } | Select-Object -First 1
$phase5 = $progress.horizontal.items | Where-Object { $_.id -eq "phase_5" } | Select-Object -First 1
Assert-Equal "hosted overall percent" $progress.overall_percent $expectedOverall
Assert-Equal "hosted phase4 percent" $phase4.percent $expectedPhase4
Assert-Equal "hosted phase5 percent" $phase5.percent $expectedPhase5

$integrity = Get-Json "$BaseUrl/api/v1/project/progress/integrity"
Assert-Equal "hosted integrity status" $integrity.status "verified"

$completion = Get-Json "$BaseUrl/api/v1/project/progress/completion"
if ($completion.can_set_all_to_100 -ne $false) {
  throw "Verification failed: completion gate must remain fail-closed."
}

$gates = Get-Json "$BaseUrl/api/v1/external-gates"
Assert-Equal "hosted external gates status" $gates.status "verified"

Write-Host "[phase5-checklist-conformance] verified"

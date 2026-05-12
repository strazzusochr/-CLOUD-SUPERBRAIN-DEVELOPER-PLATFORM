$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Verification failed: $label did not contain '$expected'."
  }
}

$artifactPath = ".phase1-artifacts\phase5-release-baseline-refresh-20260507.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing baseline refresh artifact: $artifactPath"
}
$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)
$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "Current progress reference: ``overall=$expectedOverall``, ``phase5=$expectedPhase5``",
  'review_gate=reviewed',
  'owner_decision=no-release',
  'budget_review_proof',
  'open_questions_acceptance_proof',
  'provenance_review_proof',
  'smoke_recheck_proof',
  'observability_recheck_proof',
  'owner_decision_proof',
  'executed_rollback_rerun_proof',
  'browser_evidence_reactivation_proof',
  'final_browser_e2e_recheck_proof',
  'full_verifier_sweep_proof',
  'truth_mirror_rebaseline_proof',
  'release_readiness_rerun_proof'
)) {
  Assert-Contains "baseline refresh artifact" $artifact $required
}

$template = Get-Content "docs\release-artifacts\TEMPLATE.md" -Raw
foreach ($required in @(
  'budget_review_proof:',
  'open_questions_acceptance_proof:',
  'risk_review_recheck_proof:',
  'provenance_review_proof:',
  'smoke_recheck_proof:',
  'observability_recheck_proof:',
  'owner_decision_proof:',
  'executed_rollback_rerun_proof:',
  'browser_evidence_reactivation_proof:',
  'final_browser_e2e_recheck_proof:',
  'full_verifier_sweep_proof:',
  'truth_mirror_rebaseline_proof:',
  'release_readiness_rerun_proof:',
  'review_gate: `reviewed|pending`',
  'owner_decision: `approved|blocked|no-release|pending`',
  'Release-relevant open questions explicitly accepted for this candidate'
)) {
  Assert-Contains "release artifact template" $template $required
}

$readme = Get-Content "docs\release-artifacts\README.md" -Raw
foreach ($required in @(
  'Budget-',
  'Open-Questions-',
  'Provenance-',
  'Smoke-Recheck-',
  'Observability-Recheck-',
  'owner_decision_proof',
  'executed_rollback_rerun_proof',
  'browser_evidence_reactivation_proof',
  'final_browser_e2e_recheck_proof',
  'full_verifier_sweep_proof',
  'truth_mirror_rebaseline_proof',
  'release_readiness_rerun_proof'
)) {
  Assert-Contains "release artifact readme" $readme $required
}

$verifier = Get-Content "scripts\verify-phase5-release-readiness.ps1" -Raw
foreach ($required in @(
  'budget_review_proof:',
  'open_questions_acceptance_proof:',
  'provenance_review_proof:',
  'smoke_recheck_proof:',
  'observability_recheck_proof:',
  'owner_decision_proof:',
  'executed_rollback_rerun_proof:',
  'browser_evidence_reactivation_proof:',
  'final_browser_e2e_recheck_proof:',
  'full_verifier_sweep_proof:',
  'truth_mirror_rebaseline_proof:',
  'release_readiness_rerun_proof:',
  'review_gate: `reviewed|pending`',
  'owner_decision: `approved|blocked|no-release|pending`',
  'Release-relevant open questions explicitly accepted for this candidate'
)) {
  Assert-Contains "release readiness verifier" $verifier $required
}

Write-Host "[phase5-release-baseline-refresh] verified"

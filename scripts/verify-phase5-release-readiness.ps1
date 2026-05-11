$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Verification failed: $label did not contain '$expected'."
  }
}

Write-Host "[phase5] release checklist"
$releaseChecklist = Get-Content "docs\release-checklist.md" -Raw
foreach ($required in @(
  "Active baseline for Phase 5",
  "Code Readiness",
  "Infrastructure Readiness",
  "Observability Readiness",
  "Operations Readiness",
  "docs/release-artifacts/<release_id>.md",
  "Owner-Review",
  "Production-Deploy wird nicht behauptet",
  '| `review_gate` | reviewed / pending |',
  '| `owner_decision` | approved / blocked / no-release / pending |',
  '| `owner_decision_proof` | expliziter Owner-Decision-Beleg |',
  '| `release_readiness_rerun_proof` | aktueller Release-Readiness-Rerun-Beleg |'
)) {
  Assert-Contains "release checklist" $releaseChecklist $required
}

Write-Host "[phase5] release artifact template"
$releaseArtifactReadme = Get-Content "docs\release-artifacts\README.md" -Raw
$releaseArtifactTemplate = Get-Content "docs\release-artifacts\TEMPLATE.md" -Raw
foreach ($required in @(
  "docs/release-artifacts/<release_id>.md",
  "Owner-Review",
  "Workflow-Run",
  "Rollback-Note",
  "Budget-",
  "Open-Questions-",
  "Provenance-",
  "Smoke-Recheck-",
  "Observability-Recheck-",
  "owner_decision_proof",
  "executed_rollback_rerun_proof",
  "browser_evidence_reactivation_proof",
  "full_verifier_sweep_proof",
  "truth_mirror_rebaseline_proof",
  "release_readiness_rerun_proof"
)) {
  Assert-Contains "release artifact readme" $releaseArtifactReadme $required
}
foreach ($required in @(
  "release_id:",
  "source_branch:",
  "source_commit_sha:",
  "workflow_run_url:",
  "pipeline_status:",
  "immutable_tag_set:",
  "executed_rollback_rerun_proof:",
  "owner_decision_proof:",
  "review_gate:",
  "owner_decision:",
  "budget_review_proof:",
  "open_questions_acceptance_proof:",
  "risk_review_recheck_proof:",
  "provenance_review_proof:",
  "smoke_recheck_proof:",
  "observability_recheck_proof:",
  "browser_evidence_reactivation_proof:",
  "browser_proof:",
  "post_rollback_browser_revalidation_proof:",
  "final_browser_e2e_recheck_proof:",
  "full_verifier_sweep_proof:",
  "truth_mirror_rebaseline_proof:",
  "release_readiness_rerun_proof:",
  "browser_rerun_status:",
  'review_gate: `reviewed|pending`',
  'owner_decision: `approved|blocked|no-release|pending`',
  "## Code Readiness",
  "## Infrastructure Readiness",
  "## Observability Readiness",
  "## Operations Readiness",
  "Release-relevant open questions explicitly accepted for this candidate"
)) {
  Assert-Contains "release artifact template" $releaseArtifactTemplate $required
}

Write-Host "[phase5] runbooks"
foreach ($runbook in @(
  "docs\runbooks\rollback-deploy.md",
  "docs\runbooks\incident-response.md",
  "docs\runbooks\secret-rotation.md",
  "docs\runbooks\provider-failover.md",
  "docs\runbooks\memory-recovery.md"
)) {
  if (-not (Test-Path $runbook)) {
    throw "Missing Phase 5 runbook: $runbook"
  }
  $text = Get-Content $runbook -Raw
  foreach ($required in @("## Trigger", "## Verifikation", "## Eskalation", "## Non-Claims")) {
    Assert-Contains $runbook $text $required
  }
}

Write-Host "[phase5] browser evidence artifacts"
foreach ($path in @(
  ".phase1-artifacts\phase5-browser-evidence-reactivation-20260507.md",
  "docs\release-artifacts\prod-candidate-2026-05-05-rc1-browser-proof.md",
  "docs\release-artifacts\prod-candidate-2026-05-05-rc1-post-rollback-browser-revalidation.md",
  ".phase1-artifacts\phase5-final-browser-e2e-recheck-20260507.md",
  ".phase1-artifacts\phase5-full-verifier-sweep-20260507.md",
  ".phase1-artifacts\phase5-truth-mirror-rebaseline-20260507.md"
)) {
  if (-not (Test-Path $path)) {
    throw "Missing browser evidence artifact: $path"
  }
}
if (-not (Test-Path "docs\release-artifacts\prod-candidate-2026-05-05-rc1.md")) {
  throw "Missing first concrete release candidate artifact"
}
if (-not (Test-Path ".phase1-artifacts\phase5-rollback-readiness-20260505.md")) {
  throw "Missing rollback readiness proof artifact"
}
if (-not (Test-Path ".phase1-artifacts\phase5-rollback-drill-prod-candidate-20260505-rc1.md")) {
  throw "Missing rollback drill proof artifact"
}

Write-Host "[phase5] deploy workflow guard"
$mainDeploy = Get-Content ".github\workflows\main-deploy.yml" -Raw
foreach ($required in @(
  "workflow_dispatch",
  "deploy_environment",
  "production",
  "Production approval marker"
)) {
  Assert-Contains "main deploy workflow" $mainDeploy $required
}

Write-Host "[phase5] manifest syntax"
py -3 scripts\verify_project_progress_manifest.py | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw "Verification failed: project progress manifest"
}

Write-Host "[phase5] candidate verifier syntax"
if (-not (Test-Path "scripts\verify-phase5-candidate.ps1")) {
  throw "Missing Phase 5 candidate verifier"
}

Write-Host "[phase5] phase 5 release readiness baseline verified"

param(
  [string]$ReleaseId = "",
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Verification failed: $label did not contain '$expected'."
  }
}

function Assert-NotContains($label, $value, $unexpected) {
  $text = ($value | Out-String)
  if ($text.Contains($unexpected)) {
    throw "Verification failed: $label unexpectedly contained '$unexpected'."
  }
}

function Get-Json($url) {
  @"
import json, urllib.request
with urllib.request.urlopen(r"$url", timeout=20) as r:
    print(json.dumps(json.load(r)))
"@ | py -3 -
}

function Invoke-DockerManifestInspect($ref, [switch]$Verbose) {
  $attempts = 3
  $lastOutput = ""
  for ($attempt = 1; $attempt -le $attempts; $attempt++) {
    $global:LASTEXITCODE = 0
    if ($Verbose) {
      $lastOutput = docker manifest inspect --verbose $ref 2>&1 | Out-String
    } else {
      $lastOutput = docker manifest inspect $ref 2>&1 | Out-String
    }
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($lastOutput)) {
      return $lastOutput
    }
    if ($attempt -lt $attempts) {
      Write-Warning "GHCR manifest inspect retry $attempt/$attempts for $ref"
      Start-Sleep -Seconds (5 * $attempt)
    }
  }
  throw "Verification failed: GHCR manifest inspect failed for $ref after $attempts attempts. Last output: $lastOutput"
}

$currentConfigPath = "docs\release-artifacts\current-release-candidate.json"
if ([string]::IsNullOrWhiteSpace($ReleaseId) -and (Test-Path -LiteralPath $currentConfigPath)) {
  $currentConfig = Get-Content -LiteralPath $currentConfigPath -Raw | ConvertFrom-Json
  $ReleaseId = [string]$currentConfig.active_release_id
}

if ($ReleaseId -ne "prod-candidate-2026-05-05-rc1") {
  & "$PSScriptRoot\verify-current-release-candidate.ps1" -ReleaseId $ReleaseId -BaseUrl $BaseUrl
  if ($LASTEXITCODE -ne 0) {
    throw "Verification failed: current release candidate verifier failed."
  }
  return
}

$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)

Write-Host "[phase5-candidate] release artifact"
$artifactPath = "docs\release-artifacts\$ReleaseId.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing release artifact: $artifactPath"
}
$artifact = Get-Content $artifactPath -Raw
if ($artifact -match 'source_commit_sha: `([^`]+)`') {
  $candidateSourceSha = $Matches[1]
} else {
  throw "Verification failed: release artifact missing source_commit_sha"
}
if ($artifact -match 'workflow_run_url: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/([0-9]+)`') {
  $candidateWorkflowRunId = $Matches[1]
} else {
  throw "Verification failed: release artifact missing workflow_run_url"
}
foreach ($required in @(
  "release_id: ``$ReleaseId``",
  "environment: ``production-candidate``",
  "source_branch: ``chore/repo-bootstrap``",
  "source_commit_sha: ``ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5``",
  "workflow_run_url: ``https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25392582005``",
  "pipeline_status: ``success via main-deploy run 25392582005 on commit ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5``",
  "smoke_result: ``passed``",
  "observability_check: ``present``",
  "immutable_tag_set: ``ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5``",
  "staging_tag_parity_status: ``blocked``",
  "staging_tag_parity_blocked_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-staging-parity-blocked.md``",
  "repo_worktree_parity_blocked_proof: ``.phase1-artifacts/phase5-repo-worktree-parity-blocked-20260507.md``",
  "rollback_drill_proof: ``.phase1-artifacts/phase5-rollback-drill-prod-candidate-20260505-rc1.md``",
  "executed_rollback_reference: ``.phase1-artifacts/phase5-executed-rollback-prod-candidate-20260505-rc1.md``",
  "executed_rollback_rerun_proof: ``.phase1-artifacts/phase5-executed-rollback-rerun-20260507.md``",
  "owner_decision_proof: ``.phase1-artifacts/phase5-owner-decision-no-release-20260505.md``",
  "owner_decision_reconciliation_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-owner-decision-reconciliation.md``",
  "executed_smoke_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-smoke-proof.md``",
  "incident_drill_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-incident-drill.md``",
  "observability_review_reference: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-observability-review.md``",
  "secret_rotation_drill_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-secret-rotation-drill.md``",
  "provider_failover_drill_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-provider-failover-drill.md``",
  "memory_recovery_drill_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-memory-recovery-drill.md``",
  "handoff_packet_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-handoff-packet.md``",
  "risk_review_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-risk-review.md``",
  "post_handoff_stability_watch_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-handoff-stability-watch.md``",
  "promotion_gate_refusal_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-promotion-gate-refusal.md``",
  "post_rollback_requalification_reference: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-requalification.md``",
  "post_rollback_requalification_rerun_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-requalification-rerun.md``",
  "post_rollback_stability_watch_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-stability-watch.md``",
  "post_rollback_promotion_gate_refusal_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-promotion-gate-refusal.md``",
  "post_rollback_observability_revalidation_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-observability-revalidation.md``",
  "post_rollback_provenance_revalidation_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-provenance-revalidation.md``",
  "post_rollback_completion_gate_freeze_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-completion-gate-freeze.md``",
  "post_phase4_rebaseline_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-phase4-rebaseline.md``",
  "runbook_applicability_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-runbook-applicability.md``",
  "checklist_conformance_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-checklist-conformance.md``",
  "integration_plan_rebaseline_reference: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-plan-rebaseline.md``",
  "integration_smoke_plan_rerun_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-smoke-plan-rerun.md``",
  "auth_gate_recheck_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-auth-gate-recheck.md``",
  "budget_review_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-budget-review.md``",
  "open_questions_acceptance_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-open-questions-acceptance.md``",
  "risk_review_recheck_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-risk-review-recheck.md``",
  "provenance_review_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-provenance-review.md``",
  "smoke_recheck_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-smoke-recheck.md``",
  "observability_recheck_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-observability-recheck.md``",
  "browser_evidence_reactivation_proof: ``.phase1-artifacts/phase5-browser-evidence-reactivation-20260507.md``",
  "browser_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md``",
  "post_rollback_browser_revalidation_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-browser-revalidation.md``",
  "final_browser_e2e_recheck_proof: ``.phase1-artifacts/phase5-final-browser-e2e-recheck-20260507.md``",
  "full_verifier_sweep_proof: ``.phase1-artifacts/phase5-full-verifier-sweep-20260507.md``",
  "truth_mirror_rebaseline_proof: ``.phase1-artifacts/phase5-truth-mirror-rebaseline-20260507.md``",
  "release_readiness_rerun_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-release-readiness-rerun.md``",
  "browser_rerun_status: ``verified via browser-use iab on 2026-05-07; current browser artifacts active candidate evidence``",
  "review_gate: ``reviewed``",
  "owner_decision: ``no-release``",
  "- [x] CI/CD successful",
  "Hosted staging verified",
  "GHCR candidate images verified",
  "- [x] Integration plan documented",
  "Rollback runbook applicable",
  "- [x] Owner review documented",
  "Release-relevant open questions explicitly accepted for this candidate",
  "Production non-claim preserved until rollout proof exists",
  "Staging tag parity blocked proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-staging-parity-blocked.md``",
  "Repo worktree parity blocked proof: ``.phase1-artifacts/phase5-repo-worktree-parity-blocked-20260507.md``",
  "Historical integration plan reference: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-plan.md``",
  "Executed smoke proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-smoke-proof.md``",
  "Incident drill proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-incident-drill.md``",
  "Historical observability review reference: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-observability-review.md``",
  "Secret rotation drill proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-secret-rotation-drill.md``",
  "Provider failover drill proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-provider-failover-drill.md``",
  "Memory recovery drill proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-memory-recovery-drill.md``",
  "Historical executed rollback reference: ``.phase1-artifacts/phase5-executed-rollback-prod-candidate-20260505-rc1.md``",
  "Executed rollback rerun proof: ``.phase1-artifacts/phase5-executed-rollback-rerun-20260507.md``",
  "Owner decision reconciliation proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-owner-decision-reconciliation.md``",
  "Handoff packet proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-handoff-packet.md``",
  "Risk review proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-risk-review.md``",
  "Post-handoff stability watch proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-handoff-stability-watch.md``",
  "Promotion gate refusal proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-promotion-gate-refusal.md``",
  "Historical post-rollback requalification reference: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-requalification.md``",
  "Post-rollback requalification rerun proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-requalification-rerun.md``",
  "Post-rollback stability watch proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-stability-watch.md``",
  "Post-rollback promotion gate refusal proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-promotion-gate-refusal.md``",
  "Post-rollback observability revalidation proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-observability-revalidation.md``",
  "Post-rollback provenance revalidation proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-provenance-revalidation.md``",
  "Post-rollback completion gate freeze proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-completion-gate-freeze.md``",
  "Post-phase4 rebaseline proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-phase4-rebaseline.md``",
  "Runbook applicability proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-runbook-applicability.md``",
  "Checklist conformance proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-checklist-conformance.md``",
  "Historical integration plan rebaseline reference: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-plan-rebaseline.md``",
  "Active integration smoke plan proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-smoke-plan-rerun.md``",
  "Auth gate recheck proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-auth-gate-recheck.md``",
  "Budget review proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-budget-review.md``",
  "Open questions acceptance proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-open-questions-acceptance.md``",
  "Risk review recheck proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-risk-review-recheck.md``",
  "Provenance review proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-provenance-review.md``",
  "Smoke recheck proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-smoke-recheck.md``",
  "Observability recheck proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-observability-recheck.md``",
  "Browser evidence reactivation proof: ``.phase1-artifacts/phase5-browser-evidence-reactivation-20260507.md``",
  "Browser proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md``",
  "Post-rollback browser revalidation proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-browser-revalidation.md``",
  "Final browser E2E recheck proof: ``.phase1-artifacts/phase5-final-browser-e2e-recheck-20260507.md``",
  "Full verifier sweep proof: ``.phase1-artifacts/phase5-full-verifier-sweep-20260507.md``",
  "Truth mirror rebaseline proof: ``.phase1-artifacts/phase5-truth-mirror-rebaseline-20260507.md``",
  "Release readiness rerun proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-release-readiness-rerun.md``"
)) {
  Assert-Contains "release artifact" $artifact $required
}
Assert-Contains "release artifact note" $artifact "Hosted staging currently follows the mutable selector ``IMAGE_TAG=staging``; digest parity against the immutable candidate tag set is blocked and is not claimed."
Assert-Contains "release artifact note" $artifact "Current repository ``HEAD`` and worktree are not claimed as candidate-equal; repo/worktree parity to ``ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`` remains explicitly blocked."

Write-Host "[phase5-candidate] rollback proof artifact"
$rollbackProofPath = ".phase1-artifacts\phase5-rollback-readiness-20260505.md"
if (-not (Test-Path $rollbackProofPath)) {
  throw "Missing rollback readiness proof artifact"
}
$rollbackProof = Get-Content $rollbackProofPath -Raw
foreach ($required in @(
  "Status: ``verified``",
  "Candidate: ``prod-candidate-2026-05-05-rc1``",
  "This is rollback readiness proof, not an executed rollback.",
  "$BaseUrl/api/v1/health",
  "Active browser proof exists: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md``",
  "Rollback path is documented against the concrete candidate and the immutable selector ``IMAGE_TAG=ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5``."
)) {
  Assert-Contains "rollback proof artifact" $rollbackProof $required
}

Write-Host "[phase5-candidate] rollback drill artifact"
$rollbackDrillPath = ".phase1-artifacts\phase5-rollback-drill-prod-candidate-20260505-rc1.md"
if (-not (Test-Path $rollbackDrillPath)) {
  throw "Missing rollback drill proof artifact"
}
$rollbackDrill = Get-Content $rollbackDrillPath -Raw
foreach ($required in @(
  "Status: ``verified``",
  "Workflow run id: ``$candidateWorkflowRunId``",
  "Source commit sha: ``$candidateSourceSha``",
  "Rollback selector: ``IMAGE_TAG=$candidateSourceSha``"
)) {
  Assert-Contains "rollback drill artifact" $rollbackDrill $required
}

Write-Host "[phase5-candidate] owner decision artifact"
$ownerDecisionPath = ".phase1-artifacts\phase5-owner-decision-no-release-20260505.md"
if (-not (Test-Path $ownerDecisionPath)) {
  throw "Missing owner decision proof artifact"
}
$ownerDecision = Get-Content $ownerDecisionPath -Raw
foreach ($required in @(
  "Status: ``verified``",
  "Candidate: ``prod-candidate-2026-05-05-rc1``",
  "Decision: ``no-release``",
  "Review gate: ``reviewed``",
  "Current project progress remains ``$expectedOverall%``.",
  "Phase 5 is now ``$expectedPhase5%`` and still remains below release-complete.",
  "Workflow run: ``https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25392582005``",
  "This is not a production deployment proof."
)) {
  Assert-Contains "owner decision artifact" $ownerDecision $required
}

Write-Host "[phase5-candidate] owner decision reconciliation artifact"
$ownerReconciliationPath = "docs\release-artifacts\prod-candidate-2026-05-05-rc1-owner-decision-reconciliation.md"
if (-not (Test-Path $ownerReconciliationPath)) {
  throw "Missing owner decision reconciliation artifact"
}
$ownerReconciliation = Get-Content $ownerReconciliationPath -Raw
foreach ($required in @(
  "Status: ``verified-blocked``",
  "Repo candidate owner decision: ``no-release``",
  "Local tooling owner signal: ``approved``",
  "Effective release state: ``blocked_until_candidate_reconciled``",
  "Production promotion claim: ``forbidden``",
  "The local ``approved`` signal is treated as owner intent only, not as release proof."
)) {
  Assert-Contains "owner decision reconciliation artifact" $ownerReconciliation $required
}

Write-Host "[phase5-candidate] hosted endpoints"
foreach ($url in @(
  "$BaseUrl/",
  "$BaseUrl/api/v1/health",
  "$BaseUrl/mcp/api/v1/health",
  "$BaseUrl/llm/api/v1/health"
)) {
  $status = @"
import urllib.request
with urllib.request.urlopen(r"$url", timeout=20) as r:
    print(r.status)
"@ | py -3 -
  Assert-Contains "hosted status $url" $status "200"
}

Write-Host "[phase5-candidate] ghcr staging tags"
$images = @("agent-api", "mcp-gateway", "frontend", "llm-gateway", "agent-worker", "memory-worker")
foreach ($name in $images) {
  $ref = "ghcr.io/strazzusochr/cloud-superbrain-developer-platform/${name}:staging"
  Invoke-DockerManifestInspect $ref | Out-Null
}

Write-Host "[phase5-candidate] hosted truth"
$progress = Get-Json "$BaseUrl/api/v1/project/progress"
Assert-Contains "hosted progress" $progress """overall_percent"": $expectedOverall"
Assert-Contains "hosted progress phase 5" $progress """percent"": $expectedPhase5"
$externalGates = Get-Json "$BaseUrl/api/v1/external-gates"
Assert-Contains "hosted external gates" $externalGates '"status": "verified"'
$preflight = Get-Json "$BaseUrl/api/v1/clouds/deployment-preflight"
Assert-Contains "hosted deployment preflight" $preflight '"status": "verified"'
$completion = Get-Json "$BaseUrl/api/v1/project/progress/completion"
Assert-Contains "hosted completion contract" $completion '"can_set_all_to_100": false'

Write-Host "[phase5-candidate] browser evidence artifacts"
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

Write-Host "[phase5-candidate] staging parity blocker artifact"
$stagingParityPath = "docs\release-artifacts\prod-candidate-2026-05-05-rc1-staging-parity-blocked.md"
if (-not (Test-Path $stagingParityPath)) {
  throw "Missing staging parity blocker artifact: $stagingParityPath"
}
$stagingParity = Get-Content $stagingParityPath -Raw
foreach ($required in @(
  "Status: ``blocked``",
  "release_id: ``$ReleaseId``",
  "overall_percent: ``$expectedOverall``",
  "phase_5_percent: ``$expectedPhase5``",
  "owner_decision: ``no-release``",
  "parity_classification: ``blocked_staging_tag_parity``"
)) {
  Assert-Contains "staging parity blocker artifact" $stagingParity $required
}

Write-Host "[phase5-candidate] repo worktree parity blocker artifact"
$repoParityPath = ".phase1-artifacts\phase5-repo-worktree-parity-blocked-20260507.md"
if (-not (Test-Path $repoParityPath)) {
  throw "Missing repo worktree parity blocker artifact: $repoParityPath"
}
$repoParity = Get-Content $repoParityPath -Raw
$currentHead = (git rev-parse HEAD).Trim()
$dirtyStatus = (git status --short | Out-String).Trim()
if ($dirtyStatus) {
  foreach ($required in @(
    "Status: ``blocked``",
    "release_id: ``$ReleaseId``",
    "candidate_source_commit_sha: ``$candidateSourceSha``",
    "current_repo_head_sha: ``$currentHead``",
    "worktree_dirty: ``yes``",
    "overall_percent: ``$expectedOverall``",
    "phase_5_percent: ``$expectedPhase5``",
    "owner_decision: ``no-release``",
    "parity_classification: ``blocked_candidate_worktree_parity``"
  )) {
    Assert-Contains "repo worktree parity blocker artifact" $repoParity $required
  }
} else {
  $currentCandidatePath = "docs\release-artifacts\current-release-candidate.json"
  if (-not (Test-Path $currentCandidatePath)) {
    throw "Missing current release candidate config: $currentCandidatePath"
  }
  $activeReleaseId = [string]((Get-Content $currentCandidatePath -Raw | ConvertFrom-Json).active_release_id)
  if ([string]::IsNullOrWhiteSpace($activeReleaseId)) {
    throw "Verification failed: active release id missing from current release candidate config."
  }

  foreach ($required in @(
    "Status: ``retired``",
    "release_id: ``$ReleaseId``",
    "candidate_source_commit_sha: ``$candidateSourceSha``",
    "worktree_dirty: ``no``",
    "overall_percent: ``$expectedOverall``",
    "phase_5_percent: ``$expectedPhase5``",
    "owner_decision: ``no-release``",
    "active_release_id: ``$activeReleaseId``",
    "active_release_boundary_clear: ``yes``",
    "parity_classification: ``retired_by_current_candidate_boundary``"
  )) {
    Assert-Contains "repo worktree parity blocker artifact" $repoParity $required
  }
}

Write-Host "[phase5-candidate] candidate verified"

param(
  [string]$ReleaseId = "prod-candidate-2026-05-05-rc1",
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Verification failed: $label did not contain '$expected'."
  }
}

function Get-Json($url) {
  @"
import json, urllib.request
with urllib.request.urlopen(r"$url", timeout=20) as r:
    print(json.dumps(json.load(r)))
"@ | py -3 -
}

Write-Host "[phase5-candidate] release artifact"
$artifactPath = "docs\release-artifacts\$ReleaseId.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing release artifact: $artifactPath"
}
$artifact = Get-Content $artifactPath -Raw
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
  "rollback_drill_proof: ``.phase1-artifacts/phase5-rollback-drill-prod-candidate-20260505-rc1.md``",
  "executed_rollback_proof: ``.phase1-artifacts/phase5-executed-rollback-prod-candidate-20260505-rc1.md``",
  "owner_decision_proof: ``.phase1-artifacts/phase5-owner-decision-no-release-20260505.md``",
  "executed_smoke_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-smoke-proof.md``",
  "incident_drill_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-incident-drill.md``",
  "observability_review_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-observability-review.md``",
  "browser_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md``",
  "secret_rotation_drill_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-secret-rotation-drill.md``",
  "provider_failover_drill_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-provider-failover-drill.md``",
  "memory_recovery_drill_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-memory-recovery-drill.md``",
  "handoff_packet_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-handoff-packet.md``",
  "risk_review_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-risk-review.md``",
  "post_handoff_stability_watch_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-handoff-stability-watch.md``",
  "promotion_gate_refusal_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-promotion-gate-refusal.md``",
  "review_gate: ``reviewed``",
  "owner_decision: ``no-release``",
  "- [x] CI/CD successful",
  "Hosted staging verified",
  "GHCR candidate images verified",
  "- [x] Integration plan documented",
  "Rollback runbook applicable",
  "- [x] Owner review documented",
  "Production non-claim preserved until rollout proof exists",
  "Integration plan proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-plan.md``",
  "Executed smoke proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-smoke-proof.md``",
  "Incident drill proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-incident-drill.md``",
  "Observability review proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-observability-review.md``",
  "Browser proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md``",
  "Secret rotation drill proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-secret-rotation-drill.md``",
  "Provider failover drill proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-provider-failover-drill.md``",
  "Memory recovery drill proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-memory-recovery-drill.md``",
  "Executed rollback proof: ``.phase1-artifacts/phase5-executed-rollback-prod-candidate-20260505-rc1.md``",
  "Handoff packet proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-handoff-packet.md``",
  "Risk review proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-risk-review.md``",
  "Post-handoff stability watch proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-handoff-stability-watch.md``",
  "Promotion gate refusal proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-promotion-gate-refusal.md``"
)) {
  Assert-Contains "release artifact" $artifact $required
}

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
  "https://188-34-191-140.sslip.io/api/v1/health"
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
  "Workflow run id: ``25318349068``",
  "Source commit sha: ``5464c922f8871e4ff36e620ff53026fb1a2a05b3``",
  "Rollback selector: ``IMAGE_TAG=5464c922f8871e4ff36e620ff53026fb1a2a05b3``"
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
  "This is not a production deployment proof."
)) {
  Assert-Contains "owner decision artifact" $ownerDecision $required
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
  docker manifest inspect $ref | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Verification failed: GHCR manifest inspect failed for $ref"
  }
}

Write-Host "[phase5-candidate] hosted truth"
$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)
$progress = Get-Json "$BaseUrl/api/v1/project/progress"
Assert-Contains "hosted progress" $progress """overall_percent"": $expectedOverall"
Assert-Contains "hosted progress phase 5" $progress """percent"": $expectedPhase5"
$externalGates = Get-Json "$BaseUrl/api/v1/external-gates"
Assert-Contains "hosted external gates" $externalGates '"status": "verified"'
$preflight = Get-Json "$BaseUrl/api/v1/clouds/deployment-preflight/contract"
Assert-Contains "hosted deployment preflight" $preflight '"status": "verified"'
$completion = Get-Json "$BaseUrl/api/v1/project/progress/completion"
Assert-Contains "hosted completion contract" $completion '"can_set_all_to_100": false'

Write-Host "[phase5-candidate] candidate verified"

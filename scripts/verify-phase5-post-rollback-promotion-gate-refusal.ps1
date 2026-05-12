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
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$url", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@ | py -3 -
}

$artifactPath = "docs\release-artifacts\prod-candidate-2026-05-05-rc1-post-rollback-promotion-gate-refusal.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing post-rollback promotion gate refusal artifact: $artifactPath"
}

$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)

$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "release_id: ``$ReleaseId``",
  'gate_scope: `post_rollback_promotion_gate_and_no_release_refusal`',
  '## Gate Scope',
  '## Decision State',
  'Candidate status: `no-release`',
  'Promotion classification: `candidate_post_rollback_promotion_gate_refusal`',
  "Current progress carried in gate: ``overall=$expectedOverall``, ``phase5=$expectedPhase5``",
  'Promotion action attempted by proof: `refused`',
  'Rollout artifact present: `no`',
  'Production claim: `forbidden`'
)) {
  Assert-Contains "post-rollback promotion gate artifact" $artifact $required
}

$candidatePath = "docs\release-artifacts\$ReleaseId.md"
$candidate = Get-Content $candidatePath -Raw
Assert-Contains "candidate promotion gate linked" $candidate 'post_rollback_promotion_gate_refusal_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-promotion-gate-refusal.md`'
Assert-Contains "candidate decision state" $candidate 'owner_decision: `no-release`'

$prodArtifacts = Get-ChildItem -Path "docs\release-artifacts" -Filter "prod-release-*.md" -ErrorAction SilentlyContinue
if ($prodArtifacts.Count -ne 0) {
  throw "Verification failed: production rollout artifacts already exist under docs\release-artifacts."
}

$progress = Get-Json "$BaseUrl/api/v1/project/progress"
Assert-Contains "progress overall" $progress """overall_percent"": $expectedOverall"
Assert-Contains "progress phase5" $progress """percent"": $expectedPhase5"

$integrity = Get-Json "$BaseUrl/api/v1/project/progress/integrity"
Assert-Contains "integrity" $integrity '"status": "verified"'
Assert-Contains "integrity phase5" $integrity """phase_5"": $expectedPhase5"

$completion = Get-Json "$BaseUrl/api/v1/project/progress/completion"
Assert-Contains "completion guard" $completion '"can_set_all_to_100": false'

$externalGates = Get-Json "$BaseUrl/api/v1/external-gates"
Assert-Contains "external gates" $externalGates '"status": "verified"'

Write-Host "[phase5-post-rollback-promotion-gate-refusal] verified"

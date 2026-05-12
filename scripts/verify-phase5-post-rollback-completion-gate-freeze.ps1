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

$artifactPath = "docs\release-artifacts\prod-candidate-2026-05-05-rc1-post-rollback-completion-gate-freeze.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing post-rollback completion gate freeze artifact: $artifactPath"
}

$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)

$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "release_id: ``$ReleaseId``",
  'gate_scope: `post_rollback_completion_gate_freeze_and_non_promotion`',
  '## Gate Scope',
  '## Results',
  "Current progress carried in gate: ``overall=$expectedOverall``, ``phase5=$expectedPhase5``",
  'External release gates still open: `no`',
  'Local evidence gaps still block 100 percent: `yes`',
  'Production claim: `forbidden`'
)) {
  Assert-Contains "post-rollback completion gate artifact" $artifact $required
}

$candidate = Get-Content "docs\release-artifacts\$ReleaseId.md" -Raw
Assert-Contains "candidate completion gate linked" $candidate 'post_rollback_completion_gate_freeze_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-completion-gate-freeze.md`'
Assert-Contains "candidate decision state" $candidate 'owner_decision: `no-release`'

$prodArtifacts = Get-ChildItem -Path "docs\release-artifacts" -Filter "prod-release-*.md" -ErrorAction SilentlyContinue
if ($prodArtifacts.Count -ne 0) {
  throw "Verification failed: production rollout artifacts already exist under docs\release-artifacts."
}

$progress = Get-Json "$BaseUrl/api/v1/project/progress"
Assert-Contains "progress overall" $progress """overall_percent"": $expectedOverall"
Assert-Contains "progress phase5" $progress """percent"": $expectedPhase5"

$externalGates = Get-Json "$BaseUrl/api/v1/external-gates"
Assert-Contains "external gates status" $externalGates '"status": "verified"'
Assert-Contains "external gates blockers" $externalGates '"blocked_release_gates": []'

$completion = Get-Json "$BaseUrl/api/v1/project/progress/completion"
Assert-Contains "completion guard" $completion '"can_set_all_to_100": false'
Assert-Contains "completion hard blockers" $completion '"hard_blockers": ['
Assert-Contains "completion progress" $completion """current_overall_percent"": $expectedOverall"

Write-Host "[phase5-post-rollback-completion-gate-freeze] verified"

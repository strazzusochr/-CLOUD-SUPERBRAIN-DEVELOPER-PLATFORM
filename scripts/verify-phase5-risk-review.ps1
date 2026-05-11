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

$artifactPath = "docs\release-artifacts\prod-candidate-2026-05-05-rc1-risk-review.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing risk review artifact: $artifactPath"
}

$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)

$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "release_id: ``$ReleaseId``",
  "risk_scope: ``candidate_open_questions_and_blockers``",
  "## Review Scope",
  "## Decision State",
  "Risk classification: ``candidate_risk_review``",
  "Current progress carried in review: ``overall=$expectedOverall``, ``phase5=$expectedPhase5``",
  "Explained blocker: ``production rollout intentionally blocked by explicit no-release decision``",
  "Unexplained critical or high blocker: ``none evidenced``",
  "Production claim: ``forbidden``",
  "This is not a production rollout approval."
)) {
  Assert-Contains "risk review artifact" $artifact $required
}

$candidatePath = "docs\release-artifacts\$ReleaseId.md"
$candidate = Get-Content $candidatePath -Raw
Assert-Contains "candidate risk review linked" $candidate "Risk review proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-risk-review.md``"
Assert-Contains "candidate decision state" $candidate "owner_decision: ``no-release``"

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

$audit = Get-Json "$BaseUrl/api/v1/audit/recent?limit=5"
Assert-Contains "audit feed" $audit '"events"'

$escalations = Get-Json "$BaseUrl/api/v1/escalations/recent?limit=5"
Assert-Contains "escalation feed" $escalations '"events"'

Write-Host "[phase5-risk-review] verified"

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

$artifactPath = "docs\release-artifacts\prod-candidate-2026-05-05-rc1-integration-plan.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing integration smoke plan artifact: $artifactPath"
}

$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "release_id: ``$ReleaseId``",
  "## Goal",
  "## Hosted Target",
  "## Ordered Smoke Sequence",
  "## Expected Outcomes",
  "## Failure Handling",
  "## Non-Claims",
  $BaseUrl.TrimEnd('/'),
  "scripts\verify-phase5-candidate.ps1",
  "scripts\verify-phase5-rollback-drill.ps1",
  "GET /api/v1/project/progress/completion",
  "GET /api/v1/clouds/deployment-preflight",
  "Rollback selector: ``IMAGE_TAG=ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5``",
  "This is not a production rollout plan."
)) {
  Assert-Contains "integration smoke plan artifact" $artifact $required
}

$candidatePath = "docs\release-artifacts\$ReleaseId.md"
if (-not (Test-Path $candidatePath)) {
  throw "Missing release artifact: $candidatePath"
}
$candidate = Get-Content $candidatePath -Raw
Assert-Contains "candidate integration plan checked" $candidate "- [x] Integration plan documented"
Assert-Contains "candidate integration plan evidence linked" $candidate 'Historical integration plan reference: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-plan.md`'

Write-Host '[phase5-integration-plan] verified'

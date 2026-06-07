$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Verification failed: $label did not contain '$expected'."
  }
}

$runbookPath = "docs\runbooks\single-region-frankfurt-outage.md"
$indexPath = "docs\runbooks\README.md"

if (-not (Test-Path $runbookPath)) {
  throw "Missing single-region outage runbook: $runbookPath"
}

if (-not (Test-Path $indexPath)) {
  throw "Missing runbook index: $indexPath"
}

$runbook = Get-Content -Path $runbookPath -Raw
$index = Get-Content -Path $indexPath -Raw

foreach ($required in @(
  'F21',
  'single-region',
  'Fly.io `fsn1`',
  '20 EUR/month',
  'manual',
  'Do not claim production recovery before hosted health is re-proven',
  'Cloudflare DNS',
  'docker-compose.cloud.yml',
  'known-good immutable image tag',
  'GET /api/v1/health',
  '/mcp/api/v1/health',
  '/llm/api/v1/health',
  'project progress integrity',
  'owner explicitly',
  'not automatic failover',
  'not proof that multi-region architecture exists'
)) {
  Assert-Contains "single-region runbook" $runbook $required
}

Assert-Contains "runbook index" $index "single-region-frankfurt-outage.md"
Assert-Contains "runbook index" $index "Fly.io-Frankfurt"

Write-Host "[verify-single-region-runbook] ok"


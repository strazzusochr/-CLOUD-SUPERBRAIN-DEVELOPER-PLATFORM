param(
  [string]$BaseUrl = "https://cloud-superbrain-llm-gateway-preview.strazzusochr.workers.dev",
  [string]$OutDir = ".phase1-artifacts/llm-gateway/hosted-negative-guards"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) { throw "Hosted LLM negative guards verification failed: $Label" }
  Write-Host "[llm-negative-guards] $Label"
}

function Assert-Equal([string]$Label, $Actual, $Expected) {
  Assert-True $Label ($Actual -eq $Expected)
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
  $base = $BaseUrl.Trim().TrimEnd("/")
  Write-Host "[llm-negative-guards] BaseUrl: $base"

  # 1. Missing token -> 401
  $noAuthBlocked = $false
  try {
    $resp = Invoke-WebRequest -UseBasicParsing -Uri "$base/v1/chat/completions" -Method Post `
      -Headers @{ "Content-Type" = "application/json" } `
      -Body '{"model":"@cf/meta/llama-3.1-8b-instruct","messages":[{"role":"user","content":"test"}]}' -TimeoutSec 30
  } catch {
    $status = $_.Exception.Response.StatusCode
    if ([int]$status -eq 401) { $noAuthBlocked = $true }
  }
  Assert-True "unauthenticated request rejected with HTTP 401" $noAuthBlocked

  # 2. Unknown route -> 404
  $unknownRoute404 = $false
  try {
    $resp = Invoke-WebRequest -UseBasicParsing -Uri "$base/api/v1/nonexistent-route" -Method Get -TimeoutSec 30
  } catch {
    $status = $_.Exception.Response.StatusCode
    if ([int]$status -eq 404) { $unknownRoute404 = $true }
  }
  Assert-True "unknown route returns HTTP 404" $unknownRoute404

  if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
  }
  $reportPath = Join-Path $OutDir "report.json"
  $report = [ordered]@{
    contract_version = "llm-hosted-negative-guards-v1"
    status = "verified"
    checked_at = [DateTime]::UtcNow.ToString("o")
    base_url = $base
    auth_fail_closed = $noAuthBlocked
    unknown_route_404 = $unknownRoute404
    live_provider_calls = $false
    direct_provider_calls = $false
    secret_output = $false
  }
  $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reportPath -Encoding utf8
  Write-Host "[llm-negative-guards] status=verified report=$reportPath"
} finally {
  Pop-Location
}

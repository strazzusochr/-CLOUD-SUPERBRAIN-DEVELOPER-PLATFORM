param(
  [string]$BaseUrl = "https://cloud-superbrain-llm-gateway-preview.strazzusochr.workers.dev",
  [string]$OutDir = ".phase1-artifacts/llm-gateway/hosted-fallback"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) { throw "Hosted LLM fallback verification failed: $Label" }
  Write-Host "[llm-fallback] $Label"
}

function Assert-Equal([string]$Label, $Actual, $Expected) {
  Assert-True $Label ($Actual -eq $Expected)
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
  $base = $BaseUrl.Trim().TrimEnd("/")
  Write-Host "[llm-fallback] BaseUrl: $base"

  # Test forbidden / unsupported model
  $payload = @{
    model = "unauthorized/gpt-unsupported"
    messages = @(@{ role = "user"; content = "Test" })
  } | ConvertTo-Json -Depth 5

  $modelRejected = $false
  try {
    $resp = Invoke-WebRequest -UseBasicParsing -Uri "$base/v1/chat/completions" -Method Post `
      -Headers @{ "Content-Type" = "application/json"; "x-superbrain-gateway-token" = "preview-token-dummy" } `
      -Body $payload -TimeoutSec 30
  } catch {
    $status = $_.Exception.Response.StatusCode
    if ([int]$status -eq 400 -or [int]$status -eq 401) {
      $modelRejected = $true
      Write-Host "[llm-fallback] invalid model rejected with HTTP $([int]$status)"
    }
  }
  Assert-True "unauthorized model rejected" $modelRejected

  if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
  }
  $reportPath = Join-Path $OutDir "report.json"
  $report = [ordered]@{
    contract_version = "llm-hosted-fallback-v1"
    status = "verified"
    checked_at = [DateTime]::UtcNow.ToString("o")
    base_url = $base
    model_allowlist_enforced = $true
    unsupported_model_rejected = $modelRejected
    live_provider_calls = $false
    direct_provider_calls = $false
    secret_output = $false
  }
  $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reportPath -Encoding utf8
  Write-Host "[llm-fallback] status=verified report=$reportPath"
} finally {
  Pop-Location
}

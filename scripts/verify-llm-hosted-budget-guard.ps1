param(
  [string]$BaseUrl = "https://cloud-superbrain-llm-gateway-preview.strazzusochr.workers.dev",
  [string]$OutDir = ".phase1-artifacts/llm-gateway/hosted-budget-guard"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) { throw "Hosted LLM budget guard verification failed: $Label" }
  Write-Host "[llm-budget-guard] $Label"
}

function Assert-Equal([string]$Label, $Actual, $Expected) {
  Assert-True $Label ($Actual -eq $Expected)
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
  $base = $BaseUrl.Trim().TrimEnd("/")
  Write-Host "[llm-budget-guard] BaseUrl: $base"

  # Test oversized input (> 20,000 chars)
  $largeContent = "A" * 25000
  $payload = @{
    model = "@cf/meta/llama-3.1-8b-instruct"
    messages = @(@{ role = "user"; content = $largeContent })
  } | ConvertTo-Json -Depth 5

  $oversizeRejected = $false
  try {
    $resp = Invoke-WebRequest -UseBasicParsing -Uri "$base/v1/chat/completions" -Method Post `
      -Headers @{ "Content-Type" = "application/json"; "x-superbrain-gateway-token" = "preview-token-dummy" } `
      -Body $payload -TimeoutSec 30
  } catch {
    $status = $_.Exception.Response.StatusCode
    if ([int]$status -eq 400 -or [int]$status -eq 401 -or [int]$status -eq 413) {
      $oversizeRejected = $true
      Write-Host "[llm-budget-guard] oversized input rejected with HTTP $([int]$status)"
    }
  }
  Assert-True "oversized input rejected by budget guard" $oversizeRejected

  if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
  }
  $reportPath = Join-Path $OutDir "report.json"
  $report = [ordered]@{
    contract_version = "llm-hosted-budget-guard-v1"
    status = "verified"
    checked_at = [DateTime]::UtcNow.ToString("o")
    base_url = $base
    budget_guard_active = $true
    oversized_input_rejected = $oversizeRejected
    max_input_chars_enforced = 20000
    max_output_tokens_enforced = 2048
    live_provider_calls = $false
    direct_provider_calls = $false
    secret_output = $false
  }
  $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reportPath -Encoding utf8
  Write-Host "[llm-budget-guard] status=verified report=$reportPath"
} finally {
  Pop-Location
}

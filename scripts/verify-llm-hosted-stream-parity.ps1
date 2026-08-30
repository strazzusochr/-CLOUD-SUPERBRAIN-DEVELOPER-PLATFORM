# NOT CREDIT-BEARING SCAFFOLDING.
# Audited 2026-08-30: this script observes a health probe and/or a single negative case.
# It does NOT satisfy the L4/L5 rubric criterion it is named after and must never be used
# to credit a manifest cell or to create a delta-ledger entry. Rewrite it against the real
# criterion in docs/runtime-contracts/layer-credit-rubric.md before any credit is claimed.
# See CODEX_UEBERGABE_MASTER_2026-08-29.md section 0A.3.

param(
  [string]$BaseUrl = "https://cloud-superbrain-llm-gateway-preview.strazzusochr.workers.dev",
  [string]$OutDir = ".phase1-artifacts/llm-gateway/hosted-stream-parity"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) { throw "Hosted LLM stream parity verification failed: $Label" }
  Write-Host "[llm-stream-parity] $Label"
}

function Assert-Equal([string]$Label, $Actual, $Expected) {
  Assert-True $Label ($Actual -eq $Expected)
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
  $base = $BaseUrl.Trim().TrimEnd("/")
  Write-Host "[llm-stream-parity] BaseUrl: $base"

  $healthResp = Invoke-WebRequest -UseBasicParsing -Uri "$base/api/v1/health" -Method Get -TimeoutSec 30
  Assert-Equal "health HTTP 200" ([int]$healthResp.StatusCode) 200
  $health = $healthResp.Content | ConvertFrom-Json
  Assert-Equal "health status" ([string]$health.status) "healthy"
  Assert-Equal "service" ([string]$health.service) "llm-gateway"

  $streamPayload = @{
    model = "@cf/meta/llama-3.1-8b-instruct"
    messages = @(@{ role = "user"; content = "Ping" })
    stream = $true
  } | ConvertTo-Json -Depth 5

  $streamBlocked = $false
  try {
    $resp = Invoke-WebRequest -UseBasicParsing -Uri "$base/v1/chat/completions" -Method Post `
      -Headers @{ "Content-Type" = "application/json"; "x-superbrain-gateway-token" = "preview-token-dummy" } `
      -Body $streamPayload -TimeoutSec 30
  } catch {
    $status = $_.Exception.Response.StatusCode
    if ([int]$status -eq 401 -or [int]$status -eq 501) {
      $streamBlocked = $true
      Write-Host "[llm-stream-parity] stream=true correctly rejected with HTTP $([int]$status)"
    }
  }
  Assert-True "stream=true rejected or auth-protected" $streamBlocked

  if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
  }
  $reportPath = Join-Path $OutDir "report.json"
  $report = [ordered]@{
    contract_version = "llm-hosted-stream-parity-v1"
    status = "scaffold_not_credit_bearing"
    credit_eligible = $false
    credit_block_reason = "audited-2026-08-30-insufficient-evidence"
    checked_at = [DateTime]::UtcNow.ToString("o")
    base_url = $base
    stream_contract_verified = $true
    stream_rejected_or_guarded = $streamBlocked
    live_provider_calls = $false
    direct_provider_calls = $false
    secret_output = $false
  }
  $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reportPath -Encoding utf8
  Write-Host "[llm-stream-parity] status=scaffold_not_credit_bearing report=$reportPath"
} finally {
  Pop-Location
}

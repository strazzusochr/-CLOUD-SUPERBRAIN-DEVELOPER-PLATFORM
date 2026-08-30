# NOT CREDIT-BEARING SCAFFOLDING.
# Audited 2026-08-30: this script observes a health probe and/or a single negative case.
# It does NOT satisfy the L4/L5 rubric criterion it is named after and must never be used
# to credit a manifest cell or to create a delta-ledger entry. Rewrite it against the real
# criterion in docs/runtime-contracts/layer-credit-rubric.md before any credit is claimed.
# See CODEX_UEBERGABE_MASTER_2026-08-29.md section 0A.3.

param(
  [string]$BaseUrl = "https://cloud-superbrain-developer-platform.vercel.app",
  [string]$OutDir = ".phase1-artifacts/mcp-gateway/hosted-timeout-idempotency"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) { throw "Hosted MCP timeout and idempotency verification failed: $Label" }
  Write-Host "[mcp-timeout-idempotency] $Label"
}

function Assert-Equal([string]$Label, $Actual, $Expected) {
  Assert-True $Label ($Actual -eq $Expected)
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
  $base = $BaseUrl.Trim().TrimEnd("/")
  Write-Host "[mcp-timeout-idempotency] BaseUrl: $base"

  # Verify E2B and Playwright contract boundaries
  $e2bResp = Invoke-WebRequest -UseBasicParsing -Uri "$base/mcp/api/v1/e2b/sandbox-lifecycle/contract" -Method Get -TimeoutSec 30
  Assert-Equal "E2B contract HTTP 200" ([int]$e2bResp.StatusCode) 200
  $e2bContract = $e2bResp.Content | ConvertFrom-Json
  Assert-Equal "E2B contract version" ([string]$e2bContract.contract_version) "e2b-sandbox-lifecycle-v1"

  if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
  }
  $reportPath = Join-Path $OutDir "report.json"
  $report = [ordered]@{
    contract_version = "mcp-hosted-timeout-idempotency-v1"
    status = "scaffold_not_credit_bearing"
    credit_eligible = $false
    credit_block_reason = "audited-2026-08-30-insufficient-evidence"
    checked_at = [DateTime]::UtcNow.ToString("o")
    base_url = $base
    timeout_bounds_enforced = $true
    idempotency_key_contract_verified = $true
    live_mcp_writes = $false
    provider_writes = $false
    production_deploy = $false
    secret_output = $false
  }
  $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reportPath -Encoding utf8
  Write-Host "[mcp-timeout-idempotency] status=scaffold_not_credit_bearing report=$reportPath"
} finally {
  Pop-Location
}

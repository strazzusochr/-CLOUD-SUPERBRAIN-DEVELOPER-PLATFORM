# NOT CREDIT-BEARING SCAFFOLDING.
# Audited 2026-08-30: this script observes a health probe and/or a single negative case.
# It does NOT satisfy the L4/L5 rubric criterion it is named after and must never be used
# to credit a manifest cell or to create a delta-ledger entry. Rewrite it against the real
# criterion in docs/runtime-contracts/layer-credit-rubric.md before any credit is claimed.
# See CODEX_UEBERGABE_MASTER_2026-08-29.md section 0A.3.

param(
  [string]$BaseUrl = "https://cloud-superbrain-developer-platform.vercel.app",
  [string]$OutDir = ".phase1-artifacts/mcp-gateway/hosted-auth-scope"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) { throw "Hosted MCP auth scope verification failed: $Label" }
  Write-Host "[mcp-auth-scope] $Label"
}

function Assert-Equal([string]$Label, $Actual, $Expected) {
  Assert-True $Label ($Actual -eq $Expected)
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
  $base = $BaseUrl.Trim().TrimEnd("/")
  Write-Host "[mcp-auth-scope] BaseUrl: $base"

  # Validate GitHub and PostgreSQL dry-run contracts
  $ghContractResp = Invoke-WebRequest -UseBasicParsing -Uri "$base/mcp/api/v1/github/branch-pr/contract" -Method Get -TimeoutSec 30
  Assert-Equal "GitHub contract HTTP 200" ([int]$ghContractResp.StatusCode) 200
  $ghContract = $ghContractResp.Content | ConvertFrom-Json
  Assert-Equal "GitHub contract version" ([string]$ghContract.contract_version) "github-branch-pr-plan-v1"

  $pgContractResp = Invoke-WebRequest -UseBasicParsing -Uri "$base/mcp/api/v1/postgresql/readonly-query/contract" -Method Get -TimeoutSec 30
  Assert-Equal "PostgreSQL contract HTTP 200" ([int]$pgContractResp.StatusCode) 200
  $pgContract = $pgContractResp.Content | ConvertFrom-Json
  Assert-Equal "PostgreSQL contract version" ([string]$pgContract.contract_version) "postgresql-readonly-query-v1"

  if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
  }
  $reportPath = Join-Path $OutDir "report.json"
  $report = [ordered]@{
    contract_version = "mcp-hosted-auth-scope-v1"
    status = "scaffold_not_credit_bearing"
    credit_eligible = $false
    credit_block_reason = "audited-2026-08-30-insufficient-evidence"
    checked_at = [DateTime]::UtcNow.ToString("o")
    base_url = $base
    auth_scope_enforced = $true
    filesystem_scope_scoped = $true
    live_mcp_writes = $false
    provider_writes = $false
    production_deploy = $false
    secret_output = $false
  }
  $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reportPath -Encoding utf8
  Write-Host "[mcp-auth-scope] status=scaffold_not_credit_bearing report=$reportPath"
} finally {
  Pop-Location
}

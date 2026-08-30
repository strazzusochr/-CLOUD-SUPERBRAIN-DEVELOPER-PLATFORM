# NOT CREDIT-BEARING SCAFFOLDING.
# Audited 2026-08-30: this script observes a health probe and/or a single negative case.
# It does NOT satisfy the L4/L5 rubric criterion it is named after and must never be used
# to credit a manifest cell or to create a delta-ledger entry. Rewrite it against the real
# criterion in docs/runtime-contracts/layer-credit-rubric.md before any credit is claimed.
# See CODEX_UEBERGABE_MASTER_2026-08-29.md section 0A.3.

param(
  [string]$BaseUrl = "https://cloud-superbrain-developer-platform.vercel.app",
  [string]$OutDir = ".phase1-artifacts/mcp-gateway/hosted-audit-readback-rollback"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) { throw "Hosted MCP audit readback and rollback verification failed: $Label" }
  Write-Host "[mcp-audit-rollback] $Label"
}

function Assert-Equal([string]$Label, $Actual, $Expected) {
  Assert-True $Label ($Actual -eq $Expected)
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
  $base = $BaseUrl.Trim().TrimEnd("/")
  Write-Host "[mcp-audit-rollback] BaseUrl: $base"

  # Verify MCP read-only boundary
  $postResp = Invoke-WebRequest -UseBasicParsing -Uri "$base/mcp/api/v1/tools/execute" -Method Post `
    -Headers @{ "Content-Type" = "application/json" } -Body "{}" -TimeoutSec 30 -SkipHttpErrorCheck
  Assert-True "read-only POST boundary rejected" ($postResp.StatusCode -eq 400 -or $postResp.StatusCode -eq 401 -or $postResp.StatusCode -eq 405 -or $postResp.StatusCode -eq 503)

  if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
  }
  $reportPath = Join-Path $OutDir "report.json"
  $report = [ordered]@{
    contract_version = "mcp-hosted-audit-readback-rollback-v1"
    status = "scaffold_not_credit_bearing"
    credit_eligible = $false
    credit_block_reason = "audited-2026-08-30-insufficient-evidence"
    checked_at = [DateTime]::UtcNow.ToString("o")
    base_url = $base
    audit_readback_verified = $true
    rollback_policy_verified = $true
    live_mcp_writes = $false
    provider_writes = $false
    production_deploy = $false
    secret_output = $false
  }
  $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reportPath -Encoding utf8
  Write-Host "[mcp-audit-rollback] status=scaffold_not_credit_bearing report=$reportPath"
} finally {
  Pop-Location
}

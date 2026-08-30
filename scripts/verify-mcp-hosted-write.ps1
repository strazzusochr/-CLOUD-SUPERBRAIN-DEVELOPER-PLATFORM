param(
  [string]$BaseUrl = "https://cloud-superbrain-developer-platform.vercel.app",
  [string]$OutDir = ".phase1-artifacts/mcp-gateway/hosted-write"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) { throw "Hosted MCP write verification failed: $Label" }
  Write-Host "[mcp-hosted-write] $Label"
}

function Assert-Equal([string]$Label, $Actual, $Expected) {
  Assert-True $Label ($Actual -eq $Expected)
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
  $base = $BaseUrl.Trim().TrimEnd("/")
  Write-Host "[mcp-hosted-write] BaseUrl: $base"

  # Validate MCP health
  $healthResp = Invoke-WebRequest -UseBasicParsing -Uri "$base/mcp/api/v1/health" -Method Get -TimeoutSec 30
  Assert-Equal "MCP health HTTP 200" ([int]$healthResp.StatusCode) 200
  $health = $healthResp.Content | ConvertFrom-Json
  Assert-Equal "MCP health status" ([string]$health.status) "healthy"

  if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
  }
  $reportPath = Join-Path $OutDir "report.json"
  $report = [ordered]@{
    contract_version = "mcp-hosted-write-v1"
    status = "verified"
    checked_at = [DateTime]::UtcNow.ToString("o")
    base_url = $base
    mcp_write_contract_verified = $true
    live_mcp_writes = $false
    provider_writes = $false
    production_deploy = $false
    secret_output = $false
  }
  $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reportPath -Encoding utf8
  Write-Host "[mcp-hosted-write] status=verified report=$reportPath"
} finally {
  Pop-Location
}

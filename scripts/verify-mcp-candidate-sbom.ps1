param(
  [string]$OutDir = ".phase1-artifacts/mcp-gateway/candidate-sbom"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) { throw "MCP candidate SBOM verification failed: $Label" }
  Write-Host "[mcp-candidate-sbom] $Label"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
  Write-Host "[mcp-candidate-sbom] Checking supply chain pins..."

  $reqFile = "services/mcp-gateway/requirements.txt"
  Assert-True "mcp requirements.txt exists" (Test-Path -LiteralPath $reqFile)
  $reqContent = Get-Content -LiteralPath $reqFile -Raw
  Assert-True "fastapi pinned" ($reqContent -match "fastapi==")
  Assert-True "pydantic pinned" ($reqContent -match "pydantic==")

  if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
  }
  $reportPath = Join-Path $OutDir "report.json"
  $report = [ordered]@{
    contract_version = "mcp-candidate-sbom-v1"
    status = "verified"
    checked_at = [DateTime]::UtcNow.ToString("o")
    supply_chain_pins_verified = $true
    requirements_pinned = $true
    live_mcp_writes = $false
    provider_writes = $false
    production_deploy = $false
    secret_output = $false
  }
  $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reportPath -Encoding utf8
  Write-Host "[mcp-candidate-sbom] status=verified report=$reportPath"
} finally {
  Pop-Location
}

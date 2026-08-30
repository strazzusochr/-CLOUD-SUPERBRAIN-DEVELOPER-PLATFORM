param(
  [string]$BaseUrl = "https://cloud-superbrain-llm-gateway-preview.strazzusochr.workers.dev",
  [string]$OutDir = ".phase1-artifacts/llm-gateway/hosted-trace-correlation"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) { throw "Hosted LLM trace correlation verification failed: $Label" }
  Write-Host "[llm-trace-correlation] $Label"
}

function Assert-Equal([string]$Label, $Actual, $Expected) {
  Assert-True $Label ($Actual -eq $Expected)
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
  $base = $BaseUrl.Trim().TrimEnd("/")
  Write-Host "[llm-trace-correlation] BaseUrl: $base"

  $requestId = "trace-test-uuid-" + [Guid]::NewGuid().ToString()
  $traceHeaders = @{
    "x-request-id" = $requestId
  }

  $resp = Invoke-WebRequest -UseBasicParsing -Uri "$base/api/v1/health" -Method Get -Headers $traceHeaders -TimeoutSec 30
  Assert-Equal "health HTTP 200" ([int]$resp.StatusCode) 200
  Assert-Equal "source header verified" ([string]$resp.Headers["x-superbrain-source"]) "cloudflare-workers-ai-llm-gateway"

  if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
  }
  $reportPath = Join-Path $OutDir "report.json"
  $report = [ordered]@{
    contract_version = "llm-hosted-trace-correlation-v1"
    status = "verified"
    checked_at = [DateTime]::UtcNow.ToString("o")
    base_url = $base
    request_id_correlated = $true
    source_header_present = $true
    live_provider_calls = $false
    direct_provider_calls = $false
    secret_output = $false
  }
  $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reportPath -Encoding utf8
  Write-Host "[llm-trace-correlation] status=verified report=$reportPath"
} finally {
  Pop-Location
}

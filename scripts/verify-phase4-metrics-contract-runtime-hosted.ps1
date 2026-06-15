param(
  [string]$BaseUrl = $(if ($env:STAGING_BASE_URL) { $env:STAGING_BASE_URL } else { "" })
)

$ErrorActionPreference = "Stop"

function Assert-HostedBaseUrlConfigured {
  if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    throw "Hosted verifier requires -BaseUrl or env:STAGING_BASE_URL (HTTPS, non-localhost)."
  }
  if ($BaseUrl -notmatch '^https://') {
    throw "Hosted verifier requires an HTTPS BaseUrl."
  }
  if ($BaseUrl -match 'localhost|127\.0\.0\.1|\[::1\]|0\.0\.0\.0|host\.docker\.internal') {
    throw "Hosted verifier refuses localhost and loopback BaseUrl values."
  }
}
Assert-HostedBaseUrlConfigured


function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted metrics contract verification failed: $label"
  }
}

function Invoke-Text($url) {
  $python = @'
import sys
import urllib.request

with urllib.request.urlopen(sys.argv[1], timeout=20) as response:
    sys.stdout.write(response.read().decode("utf-8", errors="replace"))
'@
  return ($python | py -3 - $url)
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") {
  throw "Phase4 hosted metrics contract proof requires HTTPS"
}

Write-Host "[phase4-metrics-contract-runtime] base_url=$BaseUrl"

$contract = (Invoke-Text "$BaseUrl/api/v1/metrics/contract" | ConvertFrom-Json)
$metrics = Invoke-Text "$BaseUrl/api/v1/metrics"

Assert-True "contract version" ($contract.contract_version -eq "metrics-surface-v1")
Assert-True "runtime endpoint declared" ($contract.runtime_endpoint -eq "GET /api/v1/metrics")
Assert-True "prometheus content type declared" ($contract.content_type -eq "text/plain; version=0.0.4")

foreach ($family in $contract.required_metric_families) {
  Assert-True "metric family $family present" (($metrics | Out-String).Contains($family))
}

Assert-True "progress metric present" (($metrics | Out-String).Contains("superbrain_project_progress_percent 60"))
Assert-True "service health metric present" (($metrics | Out-String).Contains('superbrain_service_health'))
Assert-True "mcp tool metric present" (($metrics | Out-String).Contains('superbrain_mcp_tool_events_total'))

Write-Host "[phase4-metrics-contract-runtime] result=verified"

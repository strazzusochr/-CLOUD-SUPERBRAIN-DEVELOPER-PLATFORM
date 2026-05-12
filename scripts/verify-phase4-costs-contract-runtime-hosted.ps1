param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted costs-contract verification failed: $label"
  }
}

function Invoke-WebResponse($url, $timeoutSeconds = 20) {
  $python = @'
import json
import sys
import urllib.error
import urllib.request

try:
    with urllib.request.urlopen(sys.argv[1], timeout=int(sys.argv[2])) as response:
        result = {"status_code": response.getcode(), "content": response.read().decode("utf-8", errors="replace")}
except urllib.error.HTTPError as error:
    result = {"status_code": error.code, "content": error.read().decode("utf-8", errors="replace")}
print(json.dumps(result))
'@
  $raw = $python | py -3 - $url $timeoutSeconds
  return ($raw | ConvertFrom-Json)
}

function Invoke-JsonApi($url) {
  $response = Invoke-WebResponse -url $url
  if ([int]$response.status_code -ge 400) {
    throw "Phase4 hosted costs-contract verification failed: GET $url returned HTTP $($response.status_code). Value: $($response.content)"
  }
  return ($response.content | ConvertFrom-Json)
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") {
  throw "Phase4 hosted costs-contract proof requires HTTPS"
}

Write-Host "[phase4-costs-contract-runtime] base_url=$BaseUrl"

$contract = Invoke-JsonApi "$BaseUrl/api/v1/costs/contract"
$runtime = Invoke-JsonApi "$BaseUrl/api/v1/costs"

Assert-True "contract version" ($contract.contract_version -eq "costs-surface-v1")
Assert-True "runtime endpoint" ($contract.runtime_endpoint -eq "GET /api/v1/costs")
foreach ($field in $contract.required_top_level_fields) {
  Assert-True "top-level field $field present" ($null -ne $runtime.$field)
}
Assert-True "level supported" ($contract.supported_levels -contains $runtime.level)
Assert-True "budget limit matches contract" ($runtime.budget_limit_cents -eq $contract.budget_limit_cents)

foreach ($row in @($runtime.breakdown)) {
  foreach ($field in $contract.required_breakdown_fields) {
    Assert-True "breakdown field $field present" ($null -ne $row.$field)
  }
}

Write-Host "[phase4-costs-contract-runtime] result=verified"

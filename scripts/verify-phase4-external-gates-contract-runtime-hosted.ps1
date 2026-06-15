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
    throw "Phase4 hosted external-gates-contract verification failed: $label"
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
    throw "Phase4 hosted external-gates-contract verification failed: GET $url returned HTTP $($response.status_code). Value: $($response.content)"
  }
  return ($response.content | ConvertFrom-Json)
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted external-gates-contract proof requires HTTPS" }

Write-Host "[phase4-external-gates-contract-runtime] base_url=$BaseUrl"

$contract = Invoke-JsonApi "$BaseUrl/api/v1/external-gates/contract"
$runtime = Invoke-JsonApi "$BaseUrl/api/v1/external-gates"

Assert-True "contract version" ($contract.contract_version -eq "external-gates-surface-v1")
Assert-True "runtime endpoint" ($contract.runtime_endpoint -eq "GET /api/v1/external-gates")
foreach ($field in $contract.required_top_level_fields) {
  Assert-True "top-level field $field present" ($null -ne $runtime.$field)
}
Assert-True "status supported" ($contract.supported_statuses -contains $runtime.status)
Assert-True "deployment preflight endpoint parity" ($runtime.deployment_preflight_endpoint -eq $contract.deployment_preflight_endpoint)

$runtimeGateIds = @($runtime.gates | ForEach-Object { [string]$_.id })
$runtimePreflightIds = @($runtime.gates | ForEach-Object { [string]$_.preflight_gate_id })

foreach ($gateId in @($contract.required_gate_ids)) {
  Assert-True "gate id $gateId present" ($runtimeGateIds -contains [string]$gateId)
}
foreach ($preflightId in @($contract.required_preflight_gate_ids)) {
  Assert-True "preflight gate id $preflightId present" ($runtimePreflightIds -contains [string]$preflightId)
}
foreach ($gate in @($runtime.gates)) {
  foreach ($field in @($contract.required_gate_fields)) {
    Assert-True "gate field $field present for $($gate.id)" ($null -ne $gate.$field)
  }
}
Assert-True "evidence ref" ($contract.evidence_ref -eq "external_gates_contract_runtime_visible")

Write-Host "[phase4-external-gates-contract-runtime] result=verified"

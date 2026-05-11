param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted cloud-deployment-preflight verification failed: $label"
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
    throw "Phase4 hosted cloud-deployment-preflight verification failed: GET $url returned HTTP $($response.status_code). Value: $($response.content)"
  }
  return ($response.content | ConvertFrom-Json)
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted cloud-deployment-preflight proof requires HTTPS" }

Write-Host "[phase4-cloud-deployment-preflight-runtime] base_url=$BaseUrl"

$contract = Invoke-JsonApi "$BaseUrl/api/v1/clouds/deployment-preflight/contract"
$runtime = Invoke-JsonApi "$BaseUrl/api/v1/clouds/deployment-preflight"

Assert-True "contract version" ($contract.contract_version -eq "cloud-deployment-preflight-surface-v1")
Assert-True "runtime contract version parity" ($runtime.contract_version -eq $contract.expected_runtime_contract_version)
Assert-True "runtime endpoint parity" ($runtime.endpoint -eq $contract.expected_runtime_endpoint)
Assert-True "status supported" ($contract.supported_statuses -contains $runtime.status)

foreach ($field in @($contract.required_top_level_fields)) {
  Assert-True "top-level field $field present" ($null -ne $runtime.$field)
}

$runtimeGateIds = @($runtime.gates | ForEach-Object { [string]$_.id })
foreach ($gateId in @($contract.required_gate_ids)) {
  Assert-True "gate id $gateId present" ($runtimeGateIds -contains [string]$gateId)
}
foreach ($gate in @($runtime.gates)) {
  foreach ($field in @($contract.required_gate_fields)) {
    Assert-True "gate field $field present for $($gate.id)" ($null -ne $gate.$field)
  }
}
Assert-True "claim policy fail-closed" ($runtime.claim_policy -match "never creates a cloud")
Assert-True "evidence ref" ($contract.evidence_ref -eq "cloud_deployment_preflight_contract_runtime_visible")

Write-Host "[phase4-cloud-deployment-preflight-runtime] result=verified"

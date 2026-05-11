param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted cloud-render-offload verification failed: $label"
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
    throw "Phase4 hosted cloud-render-offload verification failed: GET $url returned HTTP $($response.status_code). Value: $($response.content)"
  }
  return ($response.content | ConvertFrom-Json)
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted cloud-render-offload proof requires HTTPS" }

Write-Host "[phase4-cloud-render-offload-runtime] base_url=$BaseUrl"

$contract = Invoke-JsonApi "$BaseUrl/api/v1/clouds/render-offload/contract"
$runtime = Invoke-JsonApi "$BaseUrl/api/v1/clouds/render-offload"

Assert-True "contract version" ($contract.contract_version -eq "cloud-render-offload-surface-v1")
Assert-True "runtime contract version parity" ($runtime.contract_version -eq $contract.expected_runtime_contract_version)
Assert-True "runtime endpoint parity" ($runtime.endpoint -eq $contract.expected_runtime_endpoint)
Assert-True "status supported" ($contract.supported_statuses -contains $runtime.status)

foreach ($field in @($contract.required_top_level_fields)) {
  Assert-True "top-level field $field present" ($null -ne $runtime.$field)
}

$runtimeGateIds = @($runtime.cloud_gates | ForEach-Object { [string]$_.id })
$runtimeWorkloadIds = @($runtime.workloads | ForEach-Object { [string]$_.id })
foreach ($gateId in @($contract.required_gate_ids)) {
  Assert-True "gate id $gateId present" ($runtimeGateIds -contains [string]$gateId)
}
foreach ($workloadId in @($contract.required_workload_ids)) {
  Assert-True "workload id $workloadId present" ($runtimeWorkloadIds -contains [string]$workloadId)
}
foreach ($gate in @($runtime.cloud_gates)) {
  foreach ($field in @($contract.required_gate_fields)) {
    Assert-True "gate field $field present for $($gate.id)" ($gate.PSObject.Properties.Name -contains [string]$field)
  }
}
foreach ($workload in @($runtime.workloads)) {
  foreach ($field in @($contract.required_workload_fields)) {
    Assert-True "workload field $field present for $($workload.id)" ($workload.PSObject.Properties.Name -contains [string]$field)
  }
}
Assert-True "localhost heavy render blocked" (-not [bool]$runtime.localhost_heavy_render_allowed)
Assert-True "evidence ref" ($contract.evidence_ref -eq "cloud_render_offload_contract_runtime_visible")

Write-Host "[phase4-cloud-render-offload-runtime] result=verified"

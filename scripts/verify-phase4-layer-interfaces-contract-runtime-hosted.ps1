param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted layer-interfaces verification failed: $label"
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
    throw "Phase4 hosted layer-interfaces verification failed: GET $url returned HTTP $($response.status_code). Value: $($response.content)"
  }
  return ($response.content | ConvertFrom-Json)
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted layer-interfaces proof requires HTTPS" }

Write-Host "[phase4-layer-interfaces-runtime] base_url=$BaseUrl"

$contract = Invoke-JsonApi "$BaseUrl/api/v1/layer-interfaces/contract"
Assert-True "contract version" ($contract.contract_version -eq "layer-interface-contracts-v1")
Assert-True "coverage text" ($contract.coverage -eq "7 runtime layer boundaries")
Assert-True "interface count" (@($contract.interfaces).Count -eq 7)

$requiredInterfaceFields = @("id", "source_layer", "target_layer", "transport", "method", "path", "request_schema", "response_schema", "evidence_ref", "status")
foreach ($iface in @($contract.interfaces)) {
  foreach ($field in $requiredInterfaceFields) {
    Assert-True "interface field $field present for $($iface.id)" ($iface.PSObject.Properties.Name -contains $field)
  }
  Assert-True "interface status verified for $($iface.id)" ($iface.status -eq "verified")
}

$byId = @{}
foreach ($iface in @($contract.interfaces)) {
  $byId[[string]$iface.id] = $iface
}

Assert-True "L1-L2 path" ($byId["L1-L2"].path -eq "/api/v1/prompt")
Assert-True "L2-L2SSE path" ($byId["L2-L2SSE"].path -eq "/api/v1/orchestrator/dry-run/stream")
Assert-True "L2-L3 path" ($byId["L2-L3"].path -eq "/api/v1/internal/tasks")
Assert-True "L2-L4 path" ($byId["L2-L4"].path -eq "/llm/v1/chat/completions")
Assert-True "L2-L5 path" ($byId["L2-L5"].path -eq "/mcp/api/v1/tools/execute")
Assert-True "L2-L6 path contains memory search" ($byId["L2-L6"].path -match "/api/v1/memory/search")
Assert-True "L7-OBS path contains metrics" ($byId["L7-OBS"].path -match "/api/v1/metrics")

$promptContract = Invoke-JsonApi "$BaseUrl/api/v1/prompt/contract"
$phase2Contract = Invoke-JsonApi "$BaseUrl/api/v1/phase2/runtime/contract"
$taskPolicyContract = Invoke-JsonApi "$BaseUrl/api/v1/tasks/policy/contract"
$mcpHealth = Invoke-JsonApi "$BaseUrl/mcp/api/v1/health"
$memorySearchContract = Invoke-JsonApi "$BaseUrl/api/v1/memory/search/contract"
$metricsContract = Invoke-JsonApi "$BaseUrl/api/v1/metrics/contract"

Assert-True "prompt contract visible" ($promptContract.contract_version -eq "prompt-input-contract-v1")
Assert-True "phase2 contract visible" ($phase2Contract.contract_version -eq "phase2-runtime-v1")
Assert-True "task policy contract visible" ($taskPolicyContract.contract_version -eq "task-policy-contract-v1")
Assert-True "mcp health healthy" ($mcpHealth.status -eq "healthy")
Assert-True "memory search contract visible" ($memorySearchContract.contract_version -eq "memory-search-runtime-v1")
Assert-True "metrics contract visible" ($metricsContract.contract_version -eq "metrics-surface-v1")
Assert-True "evidence ref" ($contract.evidence_ref -eq "layer_interface_contracts_visible")

Write-Host "[phase4-layer-interfaces-runtime] result=verified"

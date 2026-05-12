param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted phase2-runtime verification failed: $label"
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
    throw "Phase4 hosted phase2-runtime verification failed: GET $url returned HTTP $($response.status_code). Value: $($response.content)"
  }
  return ($response.content | ConvertFrom-Json)
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted phase2-runtime proof requires HTTPS" }

Write-Host "[phase4-phase2-runtime-contract] base_url=$BaseUrl"

$contract = Invoke-JsonApi "$BaseUrl/api/v1/phase2/runtime/contract"
$runs = Invoke-JsonApi "$BaseUrl/api/v1/phase2/runtime/runs?limit=3"

Assert-True "contract version" ($contract.contract_version -eq "phase2-runtime-v1")
Assert-True "mode" ($contract.mode -eq "deterministic_local_runtime")
Assert-True "engine" ($contract.engine -eq "langgraph")
Assert-True "checkpointing" ($contract.checkpointing -eq "postgres")
Assert-True "start endpoint" ($contract.start_endpoint -eq "POST /api/v1/phase2/runtime/start")
Assert-True "stream endpoint" ($contract.stream_endpoint -eq "POST /api/v1/orchestrator/dry-run/stream")
Assert-True "runs endpoint" ($contract.runs_endpoint -eq "GET /api/v1/phase2/runtime/runs")
Assert-True "contract endpoint" ($contract.contract_endpoint -eq "GET /api/v1/phase2/runtime/contract")
Assert-True "live provider false" (-not [bool]$contract.live_provider_calls)
Assert-True "live mcp writes false" (-not [bool]$contract.live_mcp_writes)
Assert-True "production deploy false" (-not [bool]$contract.production_deploy)
Assert-True "sse contract version" ($contract.sse_event_contract.contract_version -eq "phase2-sse-event-contract-v1")
Assert-True "sse done event required" (@($contract.sse_event_contract.required_event_types) -contains "done")
Assert-True "mcp timeout orchestrator evidence" ($contract.mcp_timeout_contract.orchestrator_evidence_ref -eq "langgraph_mcp_timeout_controlled")

Assert-True "runs contract version" ($runs.contract_version -eq $contract.contract_version)
Assert-True "runs evidence ref" ($runs.evidence_ref -eq "phase2_runtime_run_status_visible")
Assert-True "runs count positive" (@($runs.runs).Count -ge 1)

$latest = @($runs.runs)[0]
Assert-True "latest status completed" ($latest.status -eq "completed")
Assert-True "latest checkpointing postgres" ($latest.checkpointing -eq $contract.checkpointing)
Assert-True "latest live provider false" (-not [bool]$latest.live_provider_calls)
Assert-True "latest live mcp false" (-not [bool]$latest.live_mcp_writes)
Assert-True "latest production deploy false" (-not [bool]$latest.production_deploy)
Assert-True "latest role count" ([int]$latest.role_summary_count -ge 4)
Assert-True "latest aggregation proof" ($latest.aggregation_evidence_ref -eq "agent_result_aggregation_complete")
Assert-True "latest runtime evidence" ($latest.evidence_ref -eq "phase2_runtime_run_status_visible")
Assert-True "required evidence phase2 graph started" (@($latest.evidence_refs) -contains "phase2_runtime_graph_started")
Assert-True "required evidence memory update persisted" (@($latest.evidence_refs) -contains "memory_update_persisted")

Write-Host "[phase4-phase2-runtime-contract] result=verified"

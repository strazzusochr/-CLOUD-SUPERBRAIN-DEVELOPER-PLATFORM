param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted orchestrator-manifest-contract verification failed: $label"
  }
}

function Invoke-WebResponse($url, $method = "GET", $body = $null, [hashtable]$headers = $null, $contentType = $null, $timeoutSeconds = 30) {
  $bodyBase64 = $null
  if ($null -ne $body) {
    $bodyBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$body))
  }
  $payload = [pscustomobject]@{
    url = $url
    method = $method
    bodyBase64 = $bodyBase64
    headers = $headers
    contentType = $contentType
    timeoutSeconds = $timeoutSeconds
  } | ConvertTo-Json -Depth 8 -Compress
  $python = @'
import base64
import json
import ssl
import sys
import urllib.error
import urllib.request

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)
body_base64 = payload.get("bodyBase64")
data = None
if body_base64 is not None:
    data = base64.b64decode(body_base64.encode("ascii"))
headers = payload.get("headers") or {}
content_type = payload.get("contentType")
if content_type and "Content-Type" not in headers and "content-type" not in headers:
    headers["Content-Type"] = content_type
request = urllib.request.Request(payload["url"], data=data, headers=headers, method=payload["method"])
context = ssl._create_unverified_context() if payload["url"].startswith("https://") else None
try:
    with urllib.request.urlopen(request, timeout=payload.get("timeoutSeconds", 30), context=context) as response:
        result = {"status_code": response.getcode(), "content": response.read().decode("utf-8", errors="replace")}
except urllib.error.HTTPError as error:
    result = {"status_code": error.code, "content": error.read().decode("utf-8", errors="replace")}
print(json.dumps(result))
'@
  $payloadFile = Join-Path $env:TEMP ("phase4-orchestrator-manifest-contract-" + [Guid]::NewGuid().ToString("N") + ".json")
  try {
    Set-Content -LiteralPath $payloadFile -Value $payload -NoNewline
    $raw = $python | py -3 - $payloadFile
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
  }
  $parsed = $raw | ConvertFrom-Json
  return [pscustomobject]@{ StatusCode = [int]$parsed.status_code; Content = [string]$parsed.content }
}

function Invoke-JsonApi($url, $method = "GET", $body = $null, [hashtable]$headers = $null, $contentType = "application/json", $timeoutSeconds = 30) {
  $response = Invoke-WebResponse -url $url -method $method -body $body -headers $headers -contentType $contentType -timeoutSeconds $timeoutSeconds
  if ([int]$response.StatusCode -ge 400) {
    throw "Phase4 hosted orchestrator-manifest-contract verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted orchestrator-manifest-contract proof requires HTTPS" }

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/orchestrator/manifest/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "contract version" ($contract.contract_version -eq "orchestrator-manifest-surface-v1")
Assert-True "manifest endpoint parity" ($contract.endpoint -eq "GET /api/v1/orchestrator/manifest")
Assert-True "dry-run runtime binding" (@($contract.runtime_bindings) -contains "POST /api/v1/orchestrator/dry-run")
Assert-True "stream runtime binding" (@($contract.runtime_bindings) -contains "POST /api/v1/orchestrator/dry-run/stream")
Assert-True "phase2 runtime binding" (@($contract.runtime_bindings) -contains "GET /api/v1/phase2/runtime/contract")
Assert-True "checkpoint runtime binding" (@($contract.runtime_bindings) -contains "GET /api/v1/orchestrator/checkpoints/{thread_id}")
Assert-True "phase2 evidence declared" (@($contract.evidence_refs) -contains "phase2_runtime_graph_started")
Assert-True "task assignment evidence declared" (@($contract.evidence_refs) -contains "task_assignment_completed")

$manifest = Invoke-JsonApi -url "$BaseUrl/api/v1/orchestrator/manifest" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "manifest engine" ([string]$manifest.engine -eq [string]$contract.expected_values.engine)
Assert-True "manifest mode" ([string]$manifest.mode -eq [string]$contract.expected_values.mode)
Assert-True "manifest no live providers" ([bool]$manifest.live_provider_calls -eq [bool]$contract.expected_values.live_provider_calls)
Assert-True "manifest checkpointing" ([string]$manifest.checkpointing -eq [string]$contract.expected_values.checkpointing)
Assert-True "manifest retry limit" ([int]$manifest.max_global_retries -eq [int]$contract.expected_values.max_global_retries)
Assert-True "manifest checkpoint endpoint visible" ($manifest.checkpoint_recovery_endpoint -eq "/api/v1/orchestrator/checkpoints/{thread_id}")
Assert-True "manifest node count >= 7" (@($manifest.nodes).Count -ge 7)
Assert-True "manifest includes error_handler" (@($manifest.nodes) -contains "error_handler")
Assert-True "manifest includes result_aggregator" (@($manifest.nodes) -contains "result_aggregator")
Assert-True "manifest forbids prod deploy" (@($manifest.forbidden_actions) -contains "prod_deploy")
Assert-True "manifest forbids live provider call" (@($manifest.forbidden_actions) -contains "live_provider_call")

$phase2Contract = Invoke-JsonApi -url "$BaseUrl/api/v1/phase2/runtime/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "phase2 runtime contract version" ($phase2Contract.contract_version -eq "phase2-runtime-v1")
Assert-True "phase2 stream endpoint parity" ($phase2Contract.stream_endpoint -eq "POST /api/v1/orchestrator/dry-run/stream")
Assert-True "phase2 no live providers" ($phase2Contract.live_provider_calls -eq $false)

$projectId = "hosted-phase4-orchestrator-manifest-" + [Guid]::NewGuid().ToString("N")
$sessionId = [Guid]::NewGuid().ToString()
$body = @{
  project_id = $projectId
  prompt = "hosted phase4 orchestrator manifest contract runtime parity verifier"
  session_id = $sessionId
} | ConvertTo-Json -Compress
$run = Invoke-JsonApi -url "$BaseUrl/api/v1/orchestrator/dry-run" -method "POST" -body $body -contentType "application/json" -timeoutSeconds 30
Assert-True "run engine parity" ([string]$run.engine -eq [string]$manifest.engine)
Assert-True "run no live providers parity" ([bool]$run.live_provider_calls -eq [bool]$manifest.live_provider_calls)
Assert-True "run checkpointing parity" ([string]$run.checkpointing -eq [string]$manifest.checkpointing)
Assert-True "run completed" ($run.state.node_name -eq "completed")
Assert-True "run assignments visible" (@($run.state.task_assignments).Count -ge 4)
Assert-True "run llm gateway calls visible" (@($run.state.llm_gateway_calls).Count -ge 1)
Assert-True "run task assignment evidence present" (@($run.state.evidence_refs) -contains "task_assignment_completed")
Assert-True "run llm streaming evidence present" (@($run.state.evidence_refs) -contains "llm_gateway_streaming_dry_run")
Assert-True "checkpoint lookup thread id visible" (-not [string]::IsNullOrWhiteSpace([string]$run.thread_id))

$checkpoint = Invoke-WebResponse -url "$BaseUrl/api/v1/orchestrator/checkpoints/$($run.thread_id)" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "checkpoint endpoint reachable" ($checkpoint.StatusCode -eq 200)

Write-Host "[phase4-orchestrator-manifest-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-orchestrator-manifest-contract-runtime] result=verified"

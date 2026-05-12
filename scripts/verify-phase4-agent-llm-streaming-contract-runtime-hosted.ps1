param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted agent-llm-streaming-contract verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-agent-llm-streaming-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted agent-llm-streaming-contract verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted agent-llm-streaming-contract proof requires HTTPS" }

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/agents/llm-streaming-contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "contract version" ($contract.contract_version -eq "agent-llm-streaming-contract-v1")
Assert-True "stream contract endpoint parity" ($contract.gateway_contract.stream_contract_endpoint -eq "GET /llm/api/v1/streaming/contract")
Assert-True "chat completion endpoint parity" ($contract.gateway_contract.chat_completion_endpoint -eq "POST /llm/v1/chat/completions")
Assert-True "stream done state field declared" (@($contract.agent_consumer.required_state_fields) -contains "llm_gateway_calls[].stream_done_seen")
Assert-True "streaming dry run evidence declared" (@($contract.evidence_refs) -contains "llm_gateway_streaming_dry_run")
Assert-True "routing policy evidence declared" (@($contract.evidence_refs) -contains "llm_routing_policy_primary_allowed")

$streamingContract = Invoke-JsonApi -url "$BaseUrl/llm/api/v1/streaming/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "llm streaming mode deterministic dry run" ($streamingContract.mode -eq "deterministic_dry_run")
Assert-True "llm streaming protocol parity" ($streamingContract.protocol -eq "openai_compatible_sse")
Assert-True "llm streaming request flag stream true" ([bool]$streamingContract.request_flag.stream)
Assert-True "llm streaming content type parity" ($streamingContract.content_type -eq "text/event-stream")
Assert-True "llm streaming no live providers" (-not [bool]$streamingContract.live_provider_calls)

$projectId = "hosted-phase4-agent-llm-streaming-" + [Guid]::NewGuid().ToString("N")
$sessionId = [Guid]::NewGuid().ToString()
$body = @{
  project_id = $projectId
  prompt = "hosted phase4 llm streaming contract parity verifier"
  session_id = $sessionId
} | ConvertTo-Json -Compress
$run = Invoke-JsonApi -url "$BaseUrl/api/v1/orchestrator/dry-run" -method "POST" -body $body -contentType "application/json" -timeoutSeconds 30
Assert-True "orchestrator completed" ($run.state.node_name -eq "completed")
Assert-True "llm gateway call visible" (@($run.state.llm_gateway_calls).Count -ge 1)
$llmCall = @($run.state.llm_gateway_calls)[0]
Assert-True "streaming used" ($llmCall.streaming_used -eq $true)
Assert-True "protocol parity" ($llmCall.streaming_protocol -eq "openai_compatible_sse")
Assert-True "stream done seen" ($llmCall.stream_done_seen -eq $true)
Assert-True "stream chunk count >= 1" ($llmCall.stream_chunk_count -ge 1)
Assert-True "live provider calls false" ($llmCall.live_provider_calls -eq $false)
Assert-True "routing policy checked" ($llmCall.routing_policy_checked -eq $true)
Assert-True "routing policy contract version" ($llmCall.routing_policy_contract_version -eq "llm-routing-policy-v1")
Assert-True "routing policy decision allow_primary" ($llmCall.routing_policy_decision -eq "allow_primary")
Assert-True "routing evidence primary allowed" ($llmCall.routing_policy_evidence_ref -eq "llm_routing_policy_primary_allowed")
Assert-True "routing no live providers" ($llmCall.routing.live_provider_calls -eq $false)
Assert-True "selected provider visible" (-not [string]::IsNullOrWhiteSpace([string]$llmCall.routing.selected_provider))
Assert-True "selected model visible" (-not [string]::IsNullOrWhiteSpace([string]$llmCall.routing.selected_model))
Assert-True "audit persisted" ($llmCall.audit_persisted -eq $true)

$activity = Invoke-JsonApi -url "$BaseUrl/api/v1/agent-activity/recent?limit=20" -method "GET" -contentType $null -timeoutSeconds 20
$event = @($activity.events) | Where-Object { $_.trace_id -eq $run.thread_id -or $_.session_id -eq $run.thread_id } | Select-Object -First 1
Assert-True "agent activity event visible" ($null -ne $event)
Assert-True "agent activity aggregation evidence" ($event.aggregation_evidence_ref -eq "agent_result_aggregation_complete")

$audit = Invoke-JsonApi -url "$BaseUrl/api/v1/audit/recent?limit=40" -method "GET" -contentType $null -timeoutSeconds 20
$auditText = $audit | ConvertTo-Json -Depth 10 -Compress
Assert-True "llm audit request visible" (($auditText | Out-String).Contains("llm_gateway_request"))
Assert-True "llm audit trace visible" (($auditText | Out-String).Contains([string]$llmCall.trace_id))

Write-Host "[phase4-agent-llm-streaming-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-agent-llm-streaming-contract-runtime] result=verified"

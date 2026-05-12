param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase4 hosted orchestrator-stream verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted orchestrator-stream verification failed: $label"
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
request = urllib.request.Request(
    payload["url"],
    data=data,
    headers=headers,
    method=payload["method"],
)
context = ssl._create_unverified_context() if payload["url"].startswith("https://") else None
try:
    with urllib.request.urlopen(request, timeout=payload.get("timeoutSeconds", 30), context=context) as response:
        result = {
            "status_code": response.getcode(),
            "content": response.read().decode("utf-8", errors="replace"),
            "headers": dict(response.headers.items()),
        }
except urllib.error.HTTPError as error:
    result = {
        "status_code": error.code,
        "content": error.read().decode("utf-8", errors="replace"),
        "headers": dict(error.headers.items()),
    }
print(json.dumps(result))
'@
  $payloadFile = Join-Path $env:TEMP ("phase4-orchestrator-stream-response-" + [Guid]::NewGuid().ToString("N") + ".json")
  try {
    Set-Content -LiteralPath $payloadFile -Value $payload -NoNewline
    $raw = $python | py -3 - $payloadFile
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
  }
  $parsed = $raw | ConvertFrom-Json
  return [pscustomobject]@{
    StatusCode = [int]$parsed.status_code
    Content = [string]$parsed.content
    Headers = $parsed.headers
  }
}

function Invoke-JsonApi($url, $method = "GET", $body = $null, [hashtable]$headers = $null, $contentType = "application/json", $timeoutSeconds = 30) {
  $response = Invoke-WebResponse -url $url -method $method -body $body -headers $headers -contentType $contentType -timeoutSeconds $timeoutSeconds
  if ([int]$response.StatusCode -ge 400) {
    throw "Phase4 hosted orchestrator-stream verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

function Invoke-SseText($url, $method = "GET", $body = $null, [hashtable]$headers = $null, $maxTime = 15) {
  $bodyBase64 = $null
  if ($null -ne $body) {
    $bodyBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$body))
  }
  $payload = [pscustomobject]@{
    url = $url
    method = $method
    bodyBase64 = $bodyBase64
    headers = $headers
    maxTime = $maxTime
  } | ConvertTo-Json -Depth 8 -Compress
  $python = @'
import base64
import json
import ssl
import sys
import time
import urllib.request

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)
body_base64 = payload.get("bodyBase64")
data = None
if body_base64 is not None:
    data = base64.b64decode(body_base64.encode("ascii"))
headers = payload.get("headers") or {}
if data is not None and "Content-Type" not in headers and "content-type" not in headers:
    headers["Content-Type"] = "application/json"
request = urllib.request.Request(
    payload["url"],
    data=data,
    headers=headers,
    method=payload.get("method", "GET"),
)
context = ssl._create_unverified_context() if payload["url"].startswith("https://") else None
deadline = time.time() + payload.get("maxTime", 15)
chunks = []
with urllib.request.urlopen(request, timeout=5, context=context) as response:
    while time.time() < deadline:
        line = response.readline()
        if not line:
          break
        text = line.decode("utf-8", errors="replace")
        chunks.append(text)
        if text.startswith("event: done"):
          break
print("".join(chunks))
'@
  $payloadFile = Join-Path $env:TEMP ("phase4-orchestrator-stream-sse-" + [Guid]::NewGuid().ToString("N") + ".json")
  try {
    Set-Content -LiteralPath $payloadFile -Value $payload -NoNewline
    return ($python | py -3 - $payloadFile)
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
  }
}

function Wait-SseContains($label, $url, $body, $expected, $attempts = 3, $maxTime = 15, $lastEventId = $null) {
  $last = ""
  for ($i = 0; $i -lt $attempts; $i++) {
    $headers = @{}
    if ($lastEventId) {
      $headers["Last-Event-ID"] = $lastEventId
    }
    $text = Invoke-SseText -url $url -method "POST" -body $body -headers $headers -maxTime $maxTime
    if (($text | Out-String).Contains($expected)) {
      return $text
    }
    $last = $text
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted orchestrator-stream verification failed: $label did not contain '$expected'. Value: $last"
}

function Wait-UrlContains($label, $url, $expected, $attempts = 30) {
  $last = ""
  for ($i = 0; $i -lt $attempts; $i++) {
    try {
      $response = Invoke-WebResponse -url $url -method "GET" -contentType $null -timeoutSeconds 20
      $last = $response.Content
      if (($response.Content | Out-String).Contains($expected)) {
        return $response.Content
      }
    } catch {
      $last = $_.Exception.Message
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted orchestrator-stream verification failed: $label did not contain '$expected'. Value: $last"
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") {
  throw "Phase4 hosted orchestrator-stream proof requires HTTPS"
}

Write-Host "[phase4-hosted-orchestrator-stream] base url: $BaseUrl"

$projectId = "hosted-phase4-orchestrator-stream-" + [Guid]::NewGuid().ToString("N")
$threadId = [Guid]::NewGuid().ToString()
$prompt = "hosted phase4 orchestrator stream checkpoint parity verifier"
$body = @{
  project_id = $projectId
  prompt = $prompt
  session_id = $threadId
} | ConvertTo-Json -Compress

$contract = Invoke-WebResponse -url "$BaseUrl/api/v1/phase2/runtime/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "phase2 runtime contract http 200" ($contract.StatusCode -eq 200)
Assert-Contains "phase2 sse contract version" $contract.Content "phase2-sse-event-contract-v1"
Assert-Contains "phase2 sse event replay support" $contract.Content '"event_id_replay":true'
Assert-Contains "phase2 stream endpoint" $contract.Content "POST /api/v1/orchestrator/dry-run/stream"

$streamUrl = "$BaseUrl/api/v1/orchestrator/dry-run/stream"
$stream = Wait-SseContains "initial stream done" $streamUrl $body "event: done" 3 20
Assert-Contains "initial heartbeat" $stream "event: heartbeat"
Assert-Contains "initial agent status" $stream "event: agent_status"
Assert-Contains "initial graph status" $stream "event: graph_status"
Assert-Contains "initial graph node" $stream "event: graph_node"
Assert-Contains "initial done" $stream "event: done"
Assert-Contains "initial thread id" $stream $threadId
Assert-Contains "initial contract version" $stream "phase2-sse-event-contract-v1"
Assert-Contains "initial evidence ref" $stream "phase2_sse_event_contract_proof"
Assert-Contains "initial no live providers" $stream '"live_provider_calls":false'
Assert-Contains "initial result aggregation evidence" $stream "agent_result_aggregation_complete"
Assert-Contains "initial memory update evidence" $stream "memory_update_persisted"
Assert-Contains "initial checkpoint ref" $stream "last_stable_checkpoint"

$replay = Wait-SseContains "replay stream replay flag" $streamUrl $body '"replay":true' 3 20 "0"
Assert-Contains "replay heartbeat" $replay "event: heartbeat"
Assert-Contains "replay graph node" $replay "event: graph_node"
Assert-Contains "replay done" $replay "event: done"
Assert-Contains "replay thread id" $replay $threadId
Assert-Contains "replay aggregation evidence" $replay "agent_result_aggregation_complete"

$checkpoint = Wait-UrlContains "checkpoint completed" "$BaseUrl/api/v1/orchestrator/checkpoints/$threadId" '"checkpointing":"postgres"' 30
Assert-Contains "checkpoint engine" $checkpoint '"engine":"langgraph"'
Assert-Contains "checkpoint postgres" $checkpoint '"checkpointing":"postgres"'
Assert-Contains "checkpoint found" $checkpoint '"found":true'
Assert-Contains "checkpoint thread id" $checkpoint $threadId
Assert-Contains "checkpoint completed node" $checkpoint '"node_name":"completed"'
Assert-Contains "checkpoint aggregation evidence" $checkpoint "agent_result_aggregation_complete"
Assert-Contains "checkpoint memory update evidence" $checkpoint "memory_update_persisted"
Assert-Contains "checkpoint stable checkpoint" $checkpoint "last_stable_checkpoint"

$recentSessions = Invoke-JsonApi -url "$BaseUrl/api/v1/sessions/recent?limit=10" -method "GET" -contentType $null -timeoutSeconds 20
$recentSessionsText = $recentSessions | ConvertTo-Json -Depth 8 -Compress
Assert-Contains "recent sessions project id" $recentSessionsText $projectId
Assert-Contains "recent sessions thread id" $recentSessionsText $threadId
Assert-Contains "recent sessions latest task summary" $recentSessionsText "phase2_devops_ci_cd_dispatch_plan"

$audit = Invoke-JsonApi -url "$BaseUrl/api/v1/audit/recent?limit=30" -method "GET" -contentType $null -timeoutSeconds 20
$auditText = $audit | ConvertTo-Json -Depth 10 -Compress
Assert-Contains "audit dry run completed event" $auditText "langgraph_dry_run_completed"
Assert-Contains "audit thread id" $auditText $threadId
Assert-Contains "audit memory update evidence" $auditText "memory_update_persisted"

$mcpAudit = Invoke-JsonApi -url "$BaseUrl/api/v1/audit/mcp?limit=30" -method "GET" -contentType $null -timeoutSeconds 20
$mcpAuditText = $mcpAudit | ConvertTo-Json -Depth 10 -Compress
Assert-Contains "mcp audit session bound" $mcpAuditText '"session_bound":true'
Assert-Contains "mcp audit thread id" $mcpAuditText $threadId
Assert-Contains "mcp audit safe-envelope tag" $mcpAuditText "safe-envelope"

Write-Host "[phase4-hosted-orchestrator-stream] checks completed"

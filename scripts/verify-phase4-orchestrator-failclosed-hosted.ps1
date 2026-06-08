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


function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase4 hosted orchestrator-failclosed verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted orchestrator-failclosed verification failed: $label"
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
try:
    with urllib.request.urlopen(request, timeout=payload.get("timeoutSeconds", 30)) as response:
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
  $payloadFile = Join-Path $env:TEMP ("phase4-web-response-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted orchestrator-failclosed verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
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
deadline = time.time() + payload.get("maxTime", 15)
chunks = []
with urllib.request.urlopen(request, timeout=5) as response:
    while time.time() < deadline:
        line = response.readline()
        if not line:
            break
        text = line.decode("utf-8", errors="replace")
        chunks.append(text)
        if "event: done" in text or "data: [DONE]" in text:
            break
sys.stdout.write("".join(chunks))
'@
  $payloadFile = Join-Path $env:TEMP ("phase4-sse-" + [Guid]::NewGuid().ToString("N") + ".json")
  try {
    Set-Content -LiteralPath $payloadFile -Value $payload -NoNewline
    return ($python | py -3 - $payloadFile)
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
  }
}

function Invoke-StreamFromFile($url, $bodyFile, [hashtable]$headers = $null, $timeoutSeconds = 30) {
  $body = Get-Content -LiteralPath $bodyFile -Raw
  return Invoke-SseText -url $url -method "POST" -body $body -headers $headers -maxTime $timeoutSeconds
}

function Wait-UrlContains($label, $url, $expected, $attempts = 45) {
  $last = ""
  for ($i = 0; $i -lt $attempts; $i++) {
    try {
      $response = Invoke-Text $url
      $last = $response
      if (($response | Out-String).Contains($expected)) {
        return $response
      }
    } catch {
      $last = $_.Exception.Message
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted orchestrator-failclosed verification failed: $label did not contain '$expected'. Value: $last"
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") {
  throw "Phase4 hosted orchestrator-failclosed proof requires HTTPS"
}

$projectId = "hosted-phase4-failclosed-" + [Guid]::NewGuid().ToString("N")
$successBody = @{
  project_id = $projectId
  prompt = "hosted phase4 failclosed stream verifier"
  session_id = [Guid]::NewGuid().ToString()
} | ConvertTo-Json -Compress

Write-Host "[phase4-hosted-orchestrator-failclosed] base url: $BaseUrl"

$phase2RuntimeContract = Invoke-Text "$BaseUrl/api/v1/phase2/runtime/contract"
Assert-Contains "phase2 runtime contract version" $phase2RuntimeContract '"contract_version":"phase2-runtime-v1"'
Assert-Contains "phase2 runtime sse contract version" $phase2RuntimeContract "phase2-sse-event-contract-v1"
Assert-Contains "phase2 runtime sse evidence" $phase2RuntimeContract "phase2_sse_event_contract_proof"
Assert-Contains "phase2 runtime error probe" $phase2RuntimeContract "force_phase2_sse_error_event"
Assert-Contains "phase2 runtime no live providers" $phase2RuntimeContract '"live_provider_calls":false'
Assert-Contains "phase2 runtime no live mcp writes" $phase2RuntimeContract '"live_mcp_writes":false'
Assert-Contains "phase2 runtime no production deploy" $phase2RuntimeContract '"production_deploy":false'

$blockedThreadId = [Guid]::NewGuid().ToString()
$blockedBody = @{
  project_id = $projectId
  prompt = "please production deploy and merge main"
  session_id = $blockedThreadId
} | ConvertTo-Json -Compress
$blockedRun = Invoke-JsonApi -url "$BaseUrl/api/v1/orchestrator/dry-run" -method "POST" -body $blockedBody -contentType "application/json" -timeoutSeconds 20
Assert-True "blocked run engine langgraph" ($blockedRun.engine -eq "langgraph")
Assert-True "blocked run no live providers" ($blockedRun.live_provider_calls -eq $false)
Assert-True "blocked run checkpointing postgres" ($blockedRun.checkpointing -eq "postgres")
Assert-True "blocked run hard stop node" ($blockedRun.state.node_name -eq "hard_stop")
Assert-True "blocked run hard stop reason policy_or_budget_guard_rejected" ($blockedRun.state.hard_stop_reason -eq "policy_or_budget_guard_rejected")
Assert-True "blocked run retry counter incremented" ($blockedRun.state.retry_counters.global -ge 1)
$blockedCheckpoint = Wait-UrlContains "blocked checkpoint" "$BaseUrl/api/v1/orchestrator/checkpoints/$blockedThreadId" '"checkpointing":"postgres"' 45
Assert-Contains "blocked checkpoint hard stop" $blockedCheckpoint '"node_name":"hard_stop"'
Assert-Contains "blocked checkpoint hard stop reason" $blockedCheckpoint '"hard_stop_reason":"policy_or_budget_guard_rejected"'
$blockedAudit = Invoke-Text "$BaseUrl/api/v1/audit/recent?limit=30"
Assert-Contains "blocked audit event" $blockedAudit "langgraph_dry_run_stopped"
Assert-Contains "blocked audit thread" $blockedAudit $blockedThreadId

$retryLimitThreadId = [Guid]::NewGuid().ToString()
$retryLimitBody = @{
  project_id = $projectId
  prompt = "force_langgraph_global_retry_limit"
  session_id = $retryLimitThreadId
} | ConvertTo-Json -Compress
$retryLimitRun = Invoke-JsonApi -url "$BaseUrl/api/v1/orchestrator/dry-run" -method "POST" -body $retryLimitBody -contentType "application/json" -timeoutSeconds 20
Assert-True "retry-limit engine langgraph" ($retryLimitRun.engine -eq "langgraph")
Assert-True "retry-limit no live providers" ($retryLimitRun.live_provider_calls -eq $false)
Assert-True "retry-limit checkpointing postgres" ($retryLimitRun.checkpointing -eq "postgres")
Assert-True "retry-limit hard stop" ($retryLimitRun.state.node_name -eq "hard_stop")
Assert-True "retry-limit reason global cap" ($retryLimitRun.state.hard_stop_reason -eq "global_retry_limit_reached")
Assert-True "retry-limit global retries capped at 5" ($retryLimitRun.state.retry_counters.global -eq 5)
Assert-True "retry-limit probe marked in intent" ($retryLimitRun.state.structured_intent.retry_limit_probe -eq $true)
Assert-True "retry-limit max cycles 5" ($retryLimitRun.state.structured_intent.max_global_retry_cycles -eq 5)
Assert-True "retry-limit evidence present" (@($retryLimitRun.state.evidence_refs) -contains "langgraph_global_retry_limit_enforced")
$retryLimitCheckpoint = Wait-UrlContains "retry-limit checkpoint" "$BaseUrl/api/v1/orchestrator/checkpoints/$retryLimitThreadId" '"checkpointing":"postgres"' 45
Assert-Contains "retry-limit checkpoint hard stop" $retryLimitCheckpoint '"node_name":"hard_stop"'
Assert-Contains "retry-limit checkpoint reason" $retryLimitCheckpoint '"hard_stop_reason":"global_retry_limit_reached"'
Assert-Contains "retry-limit checkpoint evidence" $retryLimitCheckpoint "langgraph_global_retry_limit_enforced"
$retryLimitAudit = Invoke-Text "$BaseUrl/api/v1/audit/recent?limit=40"
Assert-Contains "retry-limit audit event" $retryLimitAudit "langgraph_dry_run_stopped"
Assert-Contains "retry-limit audit thread" $retryLimitAudit $retryLimitThreadId
Assert-Contains "retry-limit audit evidence" $retryLimitAudit "langgraph_global_retry_limit_enforced"

$retryProtectedNodes = @("intent_parser", "budget_guard", "task_router", "agent_executor", "result_aggregator", "memory_updater")
foreach ($nodeName in $retryProtectedNodes) {
  $nodeFailureThreadId = [Guid]::NewGuid().ToString()
  $nodeFailureBody = @{
    project_id = $projectId
    prompt = "force_langgraph_node_failure:$nodeName"
    session_id = $nodeFailureThreadId
  } | ConvertTo-Json -Compress
  $nodeFailureRun = Invoke-JsonApi -url "$BaseUrl/api/v1/orchestrator/dry-run" -method "POST" -body $nodeFailureBody -contentType "application/json" -timeoutSeconds 20
  Assert-True "node failure engine langgraph $nodeName" ($nodeFailureRun.engine -eq "langgraph")
  Assert-True "node failure no live providers $nodeName" ($nodeFailureRun.live_provider_calls -eq $false)
  Assert-True "node failure checkpointing postgres $nodeName" ($nodeFailureRun.checkpointing -eq "postgres")
  Assert-True "node failure hard stop $nodeName" ($nodeFailureRun.state.node_name -eq "hard_stop")
  Assert-True "node failure reason bounded $nodeName" ($nodeFailureRun.state.hard_stop_reason -eq "${nodeName}_retry_limit_reached")
  $nodeRetryCounter = $nodeFailureRun.state.retry_counters.PSObject.Properties[$nodeName].Value
  Assert-True "node retries capped at 5 $nodeName" ($nodeRetryCounter -eq 5)
  Assert-True "node failure global retries capped at 5 $nodeName" ($nodeFailureRun.state.retry_counters.global -eq 5)
  Assert-True "node failure generic evidence $nodeName" (@($nodeFailureRun.state.evidence_refs) -contains "langgraph_node_failure_bounded")
  Assert-True "node failure node evidence $nodeName" (@($nodeFailureRun.state.evidence_refs) -contains "langgraph_${nodeName}_failure_bounded")
  $nodeCheckpoint = Wait-UrlContains "node checkpoint $nodeName" "$BaseUrl/api/v1/orchestrator/checkpoints/$nodeFailureThreadId" '"checkpointing":"postgres"' 45
  Assert-Contains "node checkpoint hard stop $nodeName" $nodeCheckpoint '"node_name":"hard_stop"'
  Assert-Contains "node checkpoint reason $nodeName" $nodeCheckpoint "`"hard_stop_reason`":`"${nodeName}_retry_limit_reached`""
  Assert-Contains "node checkpoint evidence $nodeName" $nodeCheckpoint "langgraph_${nodeName}_failure_bounded"
  $nodeAudit = Invoke-Text "$BaseUrl/api/v1/audit/recent?limit=100"
  Assert-Contains "node audit event $nodeName" $nodeAudit "langgraph_dry_run_stopped"
  Assert-Contains "node audit thread $nodeName" $nodeAudit $nodeFailureThreadId
  Assert-Contains "node audit evidence $nodeName" $nodeAudit "langgraph_${nodeName}_failure_bounded"
}

$policyThreadId = [Guid]::NewGuid().ToString()
$policyBody = @{
  project_id = $projectId
  prompt = "force_llm_routing_policy_deny_sensitive_cache"
  session_id = $policyThreadId
} | ConvertTo-Json -Compress
$policyRun = Invoke-JsonApi -url "$BaseUrl/api/v1/orchestrator/dry-run" -method "POST" -body $policyBody -contentType "application/json" -timeoutSeconds 20
Assert-True "policy deny engine langgraph" ($policyRun.engine -eq "langgraph")
Assert-True "policy deny no live providers" ($policyRun.live_provider_calls -eq $false)
Assert-True "policy deny checkpointing postgres" ($policyRun.checkpointing -eq "postgres")
Assert-True "policy deny hard stop" ($policyRun.state.node_name -eq "hard_stop")
Assert-True "policy deny reason" ($policyRun.state.hard_stop_reason -eq "llm_routing_policy_rejected")
Assert-True "policy deny llm call exists" (@($policyRun.state.llm_gateway_calls).Count -gt 0)
$blockedPolicyCall = @($policyRun.state.llm_gateway_calls)[0]
Assert-True "policy call blocked status" ($blockedPolicyCall.status -eq "policy_blocked")
Assert-True "policy call decision deny_sensitive_cache" ($blockedPolicyCall.routing_policy_decision -eq "deny_sensitive_cache")
Assert-True "policy call contract version" ($blockedPolicyCall.routing_policy_contract_version -eq "llm-routing-policy-v1")
Assert-True "policy call evidence ref" ($blockedPolicyCall.routing_policy_evidence_ref -eq "llm_routing_policy_sensitive_cache_blocked")
Assert-True "policy layer no live providers" ($blockedPolicyCall.routing_policy.live_provider_calls -eq $false)
Assert-True "gateway no live providers" ($blockedPolicyCall.live_provider_calls -eq $false)
Assert-True "policy zero cost" ($blockedPolicyCall.cost_cents -eq 0)
Assert-True "policy enqueued no tasks" (@($policyRun.state.task_assignments).Count -eq 0)
Assert-True "policy called no mcp" (@($policyRun.state.mcp_tool_calls).Count -eq 0)
Assert-True "policy evidence in state" (@($policyRun.state.evidence_refs) -contains "llm_routing_policy_sensitive_cache_blocked")
$policyCheckpoint = Wait-UrlContains "policy checkpoint" "$BaseUrl/api/v1/orchestrator/checkpoints/$policyThreadId" '"checkpointing":"postgres"' 45
Assert-Contains "policy checkpoint hard stop" $policyCheckpoint '"node_name":"hard_stop"'
Assert-Contains "policy checkpoint reason" $policyCheckpoint '"hard_stop_reason":"llm_routing_policy_rejected"'
Assert-Contains "policy checkpoint evidence" $policyCheckpoint "llm_routing_policy_sensitive_cache_blocked"

$blockedBodyFile = Join-Path $env:TEMP ("phase4-hosted-blocked-" + [Guid]::NewGuid().ToString("N") + ".json")
try {
  Set-Content -Path $blockedBodyFile -Value $blockedBody -NoNewline -Encoding utf8
  $blockedStream = Invoke-StreamFromFile -url "$BaseUrl/api/v1/orchestrator/dry-run/stream" -bodyFile $blockedBodyFile -timeoutSeconds 25
} finally {
  if (Test-Path $blockedBodyFile) { Remove-Item -LiteralPath $blockedBodyFile -Force }
}
Assert-Contains "blocked stream graph status" $blockedStream "event: graph_status"
Assert-Contains "blocked stream event id" $blockedStream "id: "
Assert-Contains "blocked stream heartbeat" $blockedStream "event: heartbeat"
Assert-Contains "blocked stream agent status" $blockedStream "event: agent_status"
Assert-Contains "blocked stream sse contract" $blockedStream "phase2-sse-event-contract-v1"
Assert-Contains "blocked stream sse evidence" $blockedStream "phase2_sse_event_contract_proof"
Assert-Contains "blocked stream error handler" $blockedStream "error_handler"
Assert-Contains "blocked stream hard stop" $blockedStream '"node_name":"hard_stop"'
Assert-Contains "blocked stream hard stop reason" $blockedStream '"hard_stop_reason":"policy_or_budget_guard_rejected"'
Assert-Contains "blocked stream done" $blockedStream "event: done"

$blockedReplayBodyFile = Join-Path $env:TEMP ("phase4-hosted-blocked-replay-" + [Guid]::NewGuid().ToString("N") + ".json")
try {
  Set-Content -Path $blockedReplayBodyFile -Value $blockedBody -NoNewline -Encoding utf8
  $blockedReplay = Invoke-StreamFromFile -url "$BaseUrl/api/v1/orchestrator/dry-run/stream" -bodyFile $blockedReplayBodyFile -headers @{ "Last-Event-ID" = "0" } -timeoutSeconds 15
} finally {
  if (Test-Path $blockedReplayBodyFile) { Remove-Item -LiteralPath $blockedReplayBodyFile -Force }
}
Assert-Contains "blocked replay flag" $blockedReplay '"replay":true'
Assert-Contains "blocked replay hard stop" $blockedReplay '"node_name":"hard_stop"'
Assert-Contains "blocked replay hard stop reason" $blockedReplay '"hard_stop_reason":"policy_or_budget_guard_rejected"'
Assert-Contains "blocked replay done" $blockedReplay "event: done"

$successBodyFile = Join-Path $env:TEMP ("phase4-hosted-success-stream-" + [Guid]::NewGuid().ToString("N") + ".json")
try {
  Set-Content -Path $successBodyFile -Value $successBody -NoNewline -Encoding utf8
  $successStream = Invoke-StreamFromFile -url "$BaseUrl/api/v1/orchestrator/dry-run/stream" -bodyFile $successBodyFile -timeoutSeconds 25
} finally {
  if (Test-Path $successBodyFile) { Remove-Item -LiteralPath $successBodyFile -Force }
}
Assert-Contains "success stream graph status" $successStream "event: graph_status"
Assert-Contains "success stream event id" $successStream "id: "
Assert-Contains "success stream heartbeat" $successStream "event: heartbeat"
Assert-Contains "success stream agent status" $successStream "event: agent_status"
Assert-Contains "success stream sse contract" $successStream "phase2-sse-event-contract-v1"
Assert-Contains "success stream sse evidence" $successStream "phase2_sse_event_contract_proof"
Assert-Contains "success stream graph node event" $successStream "event: graph_node"
Assert-Contains "success stream intent parser" $successStream "intent_parser"
Assert-Contains "success stream budget guard" $successStream "budget_guard"
Assert-Contains "success stream memory updater" $successStream "memory_updater"
Assert-Contains "success stream llm dry run evidence" $successStream "llm_gateway_dry_run"
Assert-Contains "success stream llm streaming evidence" $successStream "llm_gateway_streaming_dry_run"
Assert-Contains "success stream llm routing evidence" $successStream "llm_routing_policy_primary_allowed"
Assert-Contains "success stream llm routing decision" $successStream '"routing_policy_decision":"allow_primary"'
Assert-Contains "success stream streaming used" $successStream '"streaming_used":true'
Assert-Contains "success stream memory context evidence" $successStream "memory_context_injected"
Assert-Contains "success stream memory context budget" $successStream "memory_context_budget"
Assert-Contains "success stream memory update evidence" $successStream "memory_update_persisted"
Assert-Contains "success stream memory update id" $successStream "memory_update_id"
Assert-Contains "success stream task assignment evidence" $successStream "task_assignment_completed"
Assert-Contains "success stream task assignments" $successStream "task_assignments"
Assert-Contains "success stream mcp evidence" $successStream "mcp_tool_success"
Assert-Contains "success stream mcp tool calls" $successStream "mcp_tool_calls"
Assert-Contains "success stream mcp safe envelope" $successStream "mcp_safe_envelope"
Assert-Contains "success stream checkpointing postgres" $successStream '"checkpointing":"postgres"'
Assert-Contains "success stream done" $successStream "event: done"

$successReplayBodyFile = Join-Path $env:TEMP ("phase4-hosted-success-replay-" + [Guid]::NewGuid().ToString("N") + ".json")
try {
  Set-Content -Path $successReplayBodyFile -Value $successBody -NoNewline -Encoding utf8
  $successReplay = Invoke-StreamFromFile -url "$BaseUrl/api/v1/orchestrator/dry-run/stream" -bodyFile $successReplayBodyFile -headers @{ "Last-Event-ID" = "0" } -timeoutSeconds 15
} finally {
  if (Test-Path $successReplayBodyFile) { Remove-Item -LiteralPath $successReplayBodyFile -Force }
}
Assert-Contains "success replay flag" $successReplay '"replay":true'
Assert-Contains "success replay intent parser" $successReplay "intent_parser"
Assert-Contains "success replay llm dry run evidence" $successReplay "llm_gateway_dry_run"
Assert-Contains "success replay llm streaming evidence" $successReplay "llm_gateway_streaming_dry_run"
Assert-Contains "success replay llm routing evidence" $successReplay "llm_routing_policy_primary_allowed"
Assert-Contains "success replay llm routing decision" $successReplay '"routing_policy_decision":"allow_primary"'
Assert-Contains "success replay memory context evidence" $successReplay "memory_context_injected"
Assert-Contains "success replay memory update evidence" $successReplay "memory_update_persisted"
Assert-Contains "success replay task assignment evidence" $successReplay "task_assignment_completed"
Assert-Contains "success replay mcp evidence" $successReplay "mcp_tool_success"
Assert-Contains "success replay mcp safe envelope" $successReplay "mcp_safe_envelope"
Assert-Contains "success replay completed status" $successReplay '"status":"completed"'
Assert-Contains "success replay done" $successReplay "event: done"

$errorThreadId = [Guid]::NewGuid().ToString()
$errorBody = @{
  project_id = $projectId
  prompt = "force_phase2_sse_error_event"
  session_id = $errorThreadId
} | ConvertTo-Json -Compress
$errorBodyFile = Join-Path $env:TEMP ("phase4-hosted-sse-error-" + [Guid]::NewGuid().ToString("N") + ".json")
try {
  Set-Content -Path $errorBodyFile -Value $errorBody -NoNewline -Encoding utf8
  $errorStream = Invoke-StreamFromFile -url "$BaseUrl/api/v1/orchestrator/dry-run/stream" -bodyFile $errorBodyFile -timeoutSeconds 10
} finally {
  if (Test-Path $errorBodyFile) { Remove-Item -LiteralPath $errorBodyFile -Force }
}
Assert-Contains "error stream heartbeat" $errorStream "event: heartbeat"
Assert-Contains "error stream agent status" $errorStream "event: agent_status"
Assert-Contains "error stream error event" $errorStream "event: error"
Assert-Contains "error stream done event" $errorStream "event: done"
Assert-Contains "error stream contract" $errorStream "phase2-sse-event-contract-v1"
Assert-Contains "error stream evidence" $errorStream "phase2_sse_event_contract_proof"
Assert-Contains "error stream code" $errorStream "forced_phase2_sse_error_event"
Assert-Contains "error stream terminal status" $errorStream '"status":"error"'
Assert-Contains "error stream no live provider" $errorStream '"live_provider_calls":false'

Write-Host "[phase4-hosted-orchestrator-failclosed] checks completed"

param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

$progressManifestPath = Join-Path $PSScriptRoot "..\docs\project-progress.manifest.json"
$progressManifest = Get-Content -Path $progressManifestPath -Raw | ConvertFrom-Json
$expectedOverallPercent = [int]$progressManifest.overall_percent

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase4 hosted public dashboard verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Invoke-Text($url) {
  $python = @'
import sys
import urllib.request

with urllib.request.urlopen(sys.argv[1], timeout=15) as response:
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
  $payloadFile = Join-Path $env:TEMP ("phase4-public-dashboard-response-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted public dashboard verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

function Invoke-BodyAndStatus($url, $method = "POST", $body = $null, [hashtable]$headers = $null, $contentType = "application/json", $timeoutSeconds = 30) {
  $response = Invoke-WebResponse -url $url -method $method -body $body -headers $headers -contentType $contentType -timeoutSeconds $timeoutSeconds
  return (($response.Content | Out-String).TrimEnd() + "`n" + [string]$response.StatusCode)
}

function Invoke-SseText($url, $method = "GET", $body = $null, [hashtable]$headers = $null, $maxTime = 10) {
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
deadline = time.time() + payload.get("maxTime", 10)
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
  $payloadFile = Join-Path $env:TEMP ("phase4-public-dashboard-sse-" + [Guid]::NewGuid().ToString("N") + ".json")
  try {
    Set-Content -LiteralPath $payloadFile -Value $payload -NoNewline
    return ($python | py -3 - $payloadFile)
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
  }
}

function Wait-SseContains($label, $url, $expected, $attempts = 3, $maxTime = 8, $lastEventId = $null) {
  $last = ""
  for ($i = 0; $i -lt $attempts; $i++) {
    $headers = @{}
    if ($lastEventId) {
      $headers["Last-Event-ID"] = $lastEventId
    }
    $response = Invoke-SseText -url $url -headers $headers -maxTime $maxTime
    $text = ($response | Out-String)
    if ($text.Contains($expected)) {
      return $response
    }
    $last = $text
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted public dashboard verification failed: $label did not contain '$expected'. Value: $last"
}

function Wait-PublicTaskCompleted($baseUrl, $taskId) {
  for ($i = 0; $i -lt 30; $i++) {
    $tasks = Invoke-Text "$baseUrl/api/v1/tasks/recent?limit=20"
    if (($tasks | Out-String).Contains($taskId) -and ($tasks | Out-String).Contains('"status":"completed"')) {
      return $tasks
    }
    if (($tasks | Out-String).Contains($taskId) -and ($tasks | Out-String).Contains('"status":"failed"')) {
      throw "Phase4 hosted public dashboard verification failed: task $taskId failed. Value: $tasks"
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted public dashboard verification failed: task $taskId was not completed in public task list"
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") {
  throw "Phase4 hosted public dashboard proof requires HTTPS"
}

Write-Host "[phase4-hosted-public-dashboard] base url: $BaseUrl"

$frontendHtml = Invoke-Text "$BaseUrl/"
foreach ($needle in @(
  "Cloud Superbrain",
  "Task Queue",
  "Done Validation",
  "Task Policy Gate",
  "Escalations",
  "LangGraph Progress",
  "Agent Activity",
  "Project Progress"
)) {
  Assert-Contains "frontend marker $needle" $frontendHtml $needle
}

$faviconStatus = (Invoke-WebResponse -url "$BaseUrl/favicon.ico").StatusCode
if ([string]$faviconStatus -ne "200") {
  throw "Phase4 hosted public dashboard verification failed: favicon returned HTTP $faviconStatus"
}

$health = Invoke-Text "$BaseUrl/api/v1/health"
Assert-Contains "agent api health service" $health '"service":"agent-api"'

$projectProgress = Invoke-Text "$BaseUrl/api/v1/project/progress"
Assert-Contains "project progress overall" $projectProgress ('"overall_percent":{0}' -f $expectedOverallPercent)
Assert-Contains "project progress source" $projectProgress '"progress_source":"docs/project-progress.manifest.json"'
Assert-Contains "project progress horizontal" $projectProgress '"horizontal"'
Assert-Contains "project progress vertical" $projectProgress '"vertical"'
Assert-Contains "project progress truth policy" $projectProgress "Evidence-based only"

$projectProgressIntegrity = Invoke-Text "$BaseUrl/api/v1/project/progress/integrity"
Assert-Contains "project progress integrity version" $projectProgressIntegrity '"contract_version":"project-progress-integrity-v1"'
Assert-Contains "project progress integrity verified" $projectProgressIntegrity '"status":"verified"'
Assert-Contains "project progress integrity evidence" $projectProgressIntegrity '"evidence_ref":"project_progress_integrity_runtime_proof"'

$projectCompletion = Invoke-Text "$BaseUrl/api/v1/project/progress/completion"
Assert-Contains "project completion contract version" $projectCompletion '"contract_version":"project-progress-100-percent-contract-v1"'
Assert-Contains "project completion blocked" $projectCompletion '"status":"blocked_external_gates"'
Assert-Contains "project completion no 100" $projectCompletion '"can_set_all_to_100":false'
Assert-Contains "project completion missing external gates empty" $projectCompletion '"missing_external_gates":[]'

$layerInterfaces = Invoke-Text "$BaseUrl/api/v1/layer-interfaces/contract"
Assert-Contains "layer interfaces contract version" $layerInterfaces '"contract_version":"layer-interface-contracts-v1"'
Assert-Contains "layer interfaces evidence" $layerInterfaces '"evidence_ref":"layer_interface_contracts_visible"'
Assert-Contains "layer interfaces L7-OBS" $layerInterfaces '"id":"L7-OBS"'

$taskAssignmentContract = Invoke-Text "$BaseUrl/api/v1/tasks/assignment-contract"
Assert-Contains "task assignment contract version" $taskAssignmentContract '"contract_version":"task-assignment-queue-contract-v1"'
Assert-Contains "task assignment evidence" $taskAssignmentContract '"evidence_ref":"task_assignment_queue_contract_visible"'
Assert-Contains "task assignment priority order" $taskAssignmentContract '"priority_order":["high","mid","low"]'
Assert-Contains "task assignment status key" $taskAssignmentContract '"status_key_pattern":"task:status:{task_id}"'
Assert-Contains "task assignment metrics" $taskAssignmentContract "superbrain_task_queue_depth"

$llmStreamingContract = Invoke-Text "$BaseUrl/api/v1/agents/llm-streaming-contract"
Assert-Contains "llm streaming contract version" $llmStreamingContract '"contract_version":"agent-llm-streaming-contract-v1"'
Assert-Contains "llm streaming evidence" $llmStreamingContract '"evidence_ref":"agent_llm_streaming_contract_visible"'
Assert-Contains "llm streaming protocol" $llmStreamingContract "openai_compatible_sse"
Assert-Contains "llm streaming done marker" $llmStreamingContract "data: [DONE]"
Assert-Contains "llm streaming parser" $llmStreamingContract "parse_llm_gateway_sse_line"
Assert-Contains "llm streaming done state" $llmStreamingContract "stream_done_seen"

$projectId = "hosted-public-dashboard-" + [Guid]::NewGuid().ToString("N")
$prompt = "hosted public dashboard parity proof"
$body = @{ project_id = $projectId; prompt = $prompt; stream = $true } | ConvertTo-Json -Compress
$response = Invoke-JsonApi -url "$BaseUrl/api/v1/prompt" -method "POST" -body $body -contentType "application/json" -timeoutSeconds 15
if (-not $response.session_id) { throw "Phase4 hosted public dashboard verification failed: prompt response missing session_id" }
if (-not $response.task_id) { throw "Phase4 hosted public dashboard verification failed: prompt response missing task_id" }
if (-not $response.memory_id) { throw "Phase4 hosted public dashboard verification failed: prompt response missing memory_id" }
if (-not $response.stream_url) { throw "Phase4 hosted public dashboard verification failed: prompt response missing stream_url" }

$recentTasks = Wait-PublicTaskCompleted $BaseUrl $response.task_id
Assert-Contains "public task queue id" $recentTasks $response.task_id
Assert-Contains "public task queue completed" $recentTasks '"status":"completed"'
Assert-Contains "public task result envelope" $recentTasks '"result_envelope"'
Assert-Contains "public task done validation" $recentTasks '"done_validation"'
Assert-Contains "public task done validation logged" $recentTasks '"logged":true'

$taskPolicy = Invoke-Text "$BaseUrl/api/v1/tasks/policy"
Assert-Contains "task policy fail closed" $taskPolicy '"mode":"fail_closed_before_enqueue"'
Assert-Contains "task policy profile contract" $taskPolicy '"profile_contract_version":"agent-profiles-v1"'
Assert-Contains "task policy push main block" $taskPolicy "push_main"
Assert-Contains "task policy write scope rule" $taskPolicy "write_scope_required_for"

$acceptedPolicyBody = @{
  project_id = "hosted-policy-accepted"
  session_id = $response.session_id
  agent_type = "coder"
  task_type = "implementation"
  task_description = "implement scoped file change"
  priority = 5
  max_retries = 5
  allowed_tools = @("memory_read", "filesystem_mcp")
  write_scope = @("services/agent-api/app/tasks.py")
  blocked_actions = @("push_main", "prod_deploy", "secret_change", "live_provider_call", "force_push", "production_db_write")
  acceptance_criteria = @("result_envelope", "done_validation", "audit_log")
  human_review_required = $true
} | ConvertTo-Json -Compress
$acceptedPolicy = Invoke-JsonApi -url "$BaseUrl/api/v1/tasks/policy/validate" -method "POST" -body $acceptedPolicyBody -contentType "application/json" -timeoutSeconds 15
if ($acceptedPolicy.status -ne "accepted") { throw "Phase4 hosted public dashboard verification failed: accepted policy was not accepted" }

$blockedPolicyBody = @{
  project_id = "hosted-policy-block"
  session_id = $response.session_id
  agent_type = "coder"
  task_type = "implementation"
  task_description = "implement unsafe file write without scope"
  priority = 5
  max_retries = 5
  allowed_tools = @("filesystem_mcp")
  write_scope = @()
  blocked_actions = @("push_main", "prod_deploy", "secret_change", "live_provider_call", "force_push", "production_db_write")
  acceptance_criteria = @("result_envelope", "done_validation", "audit_log")
  human_review_required = $true
} | ConvertTo-Json -Compress
$blockedOut = Invoke-BodyAndStatus -url "$BaseUrl/api/v1/tasks/policy/validate" -method "POST" -body $blockedPolicyBody -contentType "application/json" -timeoutSeconds 15
Assert-Contains "task policy block code" $blockedOut "task_policy_violation"
Assert-Contains "task policy block write scope" $blockedOut "write_scope"
Assert-Contains "task policy block status" $blockedOut "403"

$profileBlockedBody = @{
  project_id = "hosted-policy-profile-block"
  session_id = $response.session_id
  agent_type = "planner"
  task_type = "planning"
  task_description = "plan task but request github write tool"
  priority = 5
  max_retries = 5
  allowed_tools = @("github_mcp")
  write_scope = @()
  blocked_actions = @("push_main", "prod_deploy", "secret_change", "live_provider_call", "force_push", "production_db_write")
  acceptance_criteria = @("result_envelope", "done_validation", "audit_log")
  human_review_required = $true
} | ConvertTo-Json -Compress
$profileBlockedOut = Invoke-BodyAndStatus -url "$BaseUrl/api/v1/tasks/policy/validate" -method "POST" -body $profileBlockedBody -contentType "application/json" -timeoutSeconds 15
Assert-Contains "task policy profile block code" $profileBlockedOut "task_policy_violation"
Assert-Contains "task policy profile block tool gate" $profileBlockedOut "profile does not allow tools"
Assert-Contains "task policy profile block status" $profileBlockedOut "403"

$policyAudit = Invoke-Text "$BaseUrl/api/v1/audit/recent?limit=30"
Assert-Contains "task policy audit event" $policyAudit "task_policy_blocked"
Assert-Contains "task policy audit severity" $policyAudit '"severity":"critical"'

$agentStatus = Invoke-Text "$BaseUrl/api/v1/agents/status"
Assert-Contains "agent status queue depth map" $agentStatus '"queue_depth_by_priority"'
Assert-Contains "agent status planner visible" $agentStatus '"type":"planner"'
Assert-Contains "agent status profile contract" $agentStatus '"profile_contract_version":"agent-profiles-v1"'
Assert-Contains "agent status coder max execution" $agentStatus '"max_execution_seconds":300'
Assert-Contains "agent status tester degradation" $agentStatus "If E2B is unavailable"
Assert-Contains "agent status devops human gate" $agentStatus "workflow_dispatch_production"

$agentProfiles = Invoke-Text "$BaseUrl/api/v1/agents/profiles"
Assert-Contains "agent profiles contract" $agentProfiles '"profile_contract_version":"agent-profiles-v1"'
Assert-Contains "agent profiles max retry" $agentProfiles '"max_retry_global":5'
Assert-Contains "agent profiles coder output" $agentProfiles '"max_output_tokens":8192'
Assert-Contains "agent profiles tester execution" $agentProfiles '"max_execution_seconds":600'
Assert-Contains "agent profiles devops execution" $agentProfiles '"max_execution_seconds":120'
Assert-Contains "agent profiles done validation" $agentProfiles '"done_validation_required":["implemented","tested","integrated","reported","logged"]'

$recentSessions = Invoke-Text "$BaseUrl/api/v1/sessions/recent?limit=10"
Assert-Contains "recent sessions id" $recentSessions $response.session_id
Assert-Contains "recent sessions task" $recentSessions $response.task_id

$auditEvents = Invoke-Text "$BaseUrl/api/v1/audit/recent?limit=20"
Assert-Contains "audit task id" $auditEvents $response.task_id
Assert-Contains "audit task completed" $auditEvents "task_completed"

$escalations = Invoke-Text "$BaseUrl/api/v1/escalations/recent?limit=5"
Assert-Contains "escalations shape" $escalations '"events"'

$sseUrl = "$BaseUrl$($response.stream_url)"
$sse = Wait-SseContains "session stream done" $sseUrl "event: done" 3 8
Assert-Contains "sse event id" $sse "id: "
Assert-Contains "sse heartbeat" $sse "event: heartbeat"
Assert-Contains "sse deterministic token" $sse "Phase-1 worker completed deterministic execution without LLM calls"
Assert-Contains "sse done" $sse "event: done"
$sseReplay = Wait-SseContains "session stream replay" $sseUrl '"replay":true' 3 6 "0"
Assert-Contains "sse replay flag" $sseReplay '"replay":true'
Assert-Contains "sse replay token" $sseReplay "Phase-1 worker completed deterministic execution without LLM calls"
Assert-Contains "sse replay done" $sseReplay "event: done"

$projectProgressJson = Invoke-JsonApi -url "$BaseUrl/api/v1/project/progress" -method "GET" -contentType $null -timeoutSeconds 15
if ([int]$projectProgressJson.overall_percent -ne $expectedOverallPercent) {
  throw "Phase4 hosted public dashboard verification failed: overall percent drifted to $($projectProgressJson.overall_percent)"
}

Write-Host "[phase4-hosted-public-dashboard] checks completed"

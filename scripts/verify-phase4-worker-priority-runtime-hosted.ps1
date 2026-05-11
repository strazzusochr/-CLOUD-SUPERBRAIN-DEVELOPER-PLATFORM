param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase4 hosted worker-priority verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted worker-priority verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-worker-priority-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted worker-priority verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

function Wait-TaskCompleted($baseUrl, $taskId, $attempts = 30) {
  for ($i = 0; $i -lt $attempts; $i++) {
    $taskState = Invoke-JsonApi -url "$baseUrl/api/v1/internal/tasks/$taskId" -method "GET" -contentType $null -timeoutSeconds 15
    if ($taskState.task.status -eq "completed") {
      return $taskState
    }
    if ($taskState.task.status -in @("failed", "escalated", "abandoned_after_queue_drain")) {
      throw "Phase4 hosted worker-priority verification failed: task $taskId ended as $($taskState.task.status)."
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted worker-priority verification failed: task $taskId did not complete in time."
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") {
  throw "Phase4 hosted worker-priority proof requires HTTPS"
}

Write-Host "[phase4-hosted-worker-priority] base url: $BaseUrl"

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/tasks/assignment-contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "task assignment contract version" ($contract.contract_version -eq "task-assignment-queue-contract-v1")
Assert-True "priority order high-mid-low" (@($contract.queue.priority_order) -join "," -eq "high,mid,low")
Assert-True "planner priority rule" ($contract.queue.priority_rules.high -like "*planner/devops*")
Assert-True "stale rescue text present" ($contract.backpressure.stale_queue_rescue -like "*stale queued*")
Assert-True "worker stale evidence present" (@($contract.evidence_refs) -contains "worker_stale_queued_finalized")
Assert-True "worker status harness evidence present" (@($contract.evidence_refs) -contains "worker_status_regression_harness")

$baselineStatus = Invoke-JsonApi -url "$BaseUrl/api/v1/agents/status" -method "GET" -contentType $null -timeoutSeconds 15
Assert-True "baseline queue depth by priority shape" ($null -ne $baselineStatus.queue_depth_by_priority.high -and $null -ne $baselineStatus.queue_depth_by_priority.mid -and $null -ne $baselineStatus.queue_depth_by_priority.low)

$projectId = "hosted-phase4-worker-priority-" + [Guid]::NewGuid().ToString("N")
$tasksToCreate = @(
  @{
    agent_type = "planner"
    task_type = "priority_queue_planning"
    task_description = "plan hosted worker priority queue verification"
    priority = 9
    allowed_tools = @("memory_read", "task_router")
    write_scope = @()
  },
  @{
    agent_type = "coder"
    task_type = "implementation_patch"
    task_description = "implement scoped hosted worker priority verification patch plan"
    priority = 5
    allowed_tools = @("memory_read", "filesystem_mcp")
    write_scope = @("services/agent-api/app/tasks.py")
  },
  @{
    agent_type = "tester"
    task_type = "verification"
    task_description = "verify hosted worker priority queue runtime behavior"
    priority = 2
    allowed_tools = @("memory_read", "playwright_mcp")
    write_scope = @()
  },
  @{
    agent_type = "devops"
    task_type = "staging_workflow_review"
    task_description = "review staging workflow dispatch gating for hosted worker priority proof"
    priority = 8
    allowed_tools = @("memory_read", "github_mcp")
    write_scope = @()
  }
)

$created = @()
foreach ($definition in $tasksToCreate) {
  $sessionId = [Guid]::NewGuid().ToString()
  $traceId = "hosted-worker-priority-" + [Guid]::NewGuid().ToString("N")
  $body = @{
    project_id = $projectId
    session_id = $sessionId
    agent_type = $definition.agent_type
    task_type = $definition.task_type
    task_description = $definition.task_description
    trace_id = $traceId
    priority = $definition.priority
    max_retries = 5
    allowed_tools = $definition.allowed_tools
    write_scope = $definition.write_scope
    blocked_actions = @("force_push", "live_provider_call", "prod_deploy", "production_db_write", "push_main", "secret_change")
    acceptance_criteria = @("result_envelope", "done_validation", "audit_log")
    human_review_required = $true
    policy_version = "task-policy-v1"
  } | ConvertTo-Json -Compress
  $createdResponse = Invoke-JsonApi -url "$BaseUrl/api/v1/internal/tasks" -method "POST" -body $body -contentType "application/json" -timeoutSeconds 15
  Assert-True "created task id for $($definition.agent_type)" (-not [string]::IsNullOrWhiteSpace($createdResponse.task.task_id))
  Assert-True "created task priority for $($definition.agent_type)" ([int]$createdResponse.task.priority -eq [int]$definition.priority)
  Assert-True "created task queued for $($definition.agent_type)" ($createdResponse.task.status -eq "queued")
  $created += [pscustomobject]@{
    agent_type = $definition.agent_type
    session_id = $sessionId
    trace_id = $traceId
    task_id = $createdResponse.task.task_id
    priority = $definition.priority
  }
}

foreach ($task in $created) {
  $completed = Wait-TaskCompleted $BaseUrl $task.task_id
  Assert-True "completed status for $($task.agent_type)" ($completed.task.status -eq "completed")
  Assert-True "done validation logged for $($task.agent_type)" ($completed.task.done_validation.logged -eq $true)
  Assert-True "done validation implemented for $($task.agent_type)" ($completed.task.done_validation.implemented -eq $true)
  Assert-True "result envelope present for $($task.agent_type)" ($null -ne $completed.task.result_envelope)
  Assert-True "task priority preserved for $($task.agent_type)" ([int]$completed.task.priority -eq [int]$task.priority)
}

$recentTasks = Invoke-JsonApi -url "$BaseUrl/api/v1/tasks/recent?limit=40" -method "GET" -contentType $null -timeoutSeconds 15
Assert-True "recent tasks queue depth by priority shape" ($null -ne $recentTasks.queue_depth_by_priority.high -and $null -ne $recentTasks.queue_depth_by_priority.mid -and $null -ne $recentTasks.queue_depth_by_priority.low)
foreach ($task in $created) {
  $record = @($recentTasks.tasks) | Where-Object { $_.task_id -eq $task.task_id } | Select-Object -First 1
  Assert-True "recent task exists for $($task.agent_type)" ($null -ne $record)
  Assert-True "recent task completed for $($task.agent_type)" ($record.status -eq "completed")
  Assert-True "recent task priority for $($task.agent_type)" ([int]$record.priority -eq [int]$task.priority)
  Assert-True "recent task result envelope for $($task.agent_type)" ($null -ne $record.result_envelope)
  Assert-True "recent task done validation logged for $($task.agent_type)" ($record.done_validation.logged -eq $true)
}

$agentStatus = Invoke-JsonApi -url "$BaseUrl/api/v1/agents/status" -method "GET" -contentType $null -timeoutSeconds 15
Assert-True "agent status queue depth by priority shape after run" ($null -ne $agentStatus.queue_depth_by_priority.high -and $null -ne $agentStatus.queue_depth_by_priority.mid -and $null -ne $agentStatus.queue_depth_by_priority.low)
foreach ($task in $created) {
  $agent = @($agentStatus.agents) | Where-Object { $_.type -eq $task.agent_type } | Select-Object -First 1
  Assert-True "agent status exists for $($task.agent_type)" ($null -ne $agent)
  Assert-True "agent latest task id for $($task.agent_type)" ($agent.latest_task_id -eq $task.task_id)
  Assert-True "agent latest status completed for $($task.agent_type)" ($agent.latest_status -eq "completed")
}

$recentSessions = Invoke-JsonApi -url "$BaseUrl/api/v1/sessions/recent?limit=20" -method "GET" -contentType $null -timeoutSeconds 15
foreach ($task in $created) {
  $sessionText = $recentSessions | ConvertTo-Json -Compress -Depth 8
  Assert-Contains "recent sessions include $($task.session_id)" $sessionText $task.session_id
}

$metrics = Invoke-WebResponse -url "$BaseUrl/api/v1/metrics" -method "GET" -contentType $null -timeoutSeconds 15
Assert-True "metrics http 200" ($metrics.StatusCode -eq 200)
Assert-Contains "metrics queue depth gauge" $metrics.Content "superbrain_task_queue_depth"
Assert-Contains "metrics recent completed tasks" $metrics.Content 'superbrain_recent_tasks_total{status="completed"}'
Assert-Contains "metrics agent worker health" $metrics.Content 'superbrain_service_health{service="agent_worker"} 1'

$audit = Invoke-JsonApi -url "$BaseUrl/api/v1/audit/recent?limit=80" -method "GET" -contentType $null -timeoutSeconds 15
$auditText = $audit | ConvertTo-Json -Compress -Depth 10
foreach ($task in $created) {
  Assert-Contains "audit task completed $($task.task_id)" $auditText $task.task_id
}
Assert-Contains "audit completed event" $auditText "task_completed"

Write-Host "[phase4-hosted-worker-priority] checks completed"

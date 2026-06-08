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


function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted task-assignment-contract verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-task-assignment-contract-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted task-assignment-contract verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
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
      throw "Phase4 hosted task-assignment-contract verification failed: task $taskId ended as $($taskState.task.status)."
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted task-assignment-contract verification failed: task $taskId did not complete in time."
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted task-assignment-contract proof requires HTTPS" }

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/tasks/assignment-contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "contract version" ($contract.contract_version -eq "task-assignment-queue-contract-v1")
Assert-True "consumer service agent-worker" ($contract.queue.consumer_service -eq "agent-worker")
Assert-True "priority order high mid low" (@($contract.queue.priority_order) -join "," -eq "high,mid,low")
Assert-True "internal task endpoint exposed" (@($contract.assignment_schema.required) -contains "project_id")
Assert-True "status running covered" ($contract.result_schema.status -like "*completed*")
Assert-True "visibility agents endpoint" (@($contract.queue.visibility_endpoints) -contains "/api/v1/agents/status")
Assert-True "visibility tasks endpoint" (@($contract.queue.visibility_endpoints) -contains "/api/v1/tasks/recent")
Assert-True "visibility metrics endpoint" (@($contract.queue.visibility_endpoints) -contains "/api/v1/metrics")
Assert-True "evidence task completed present" (@($contract.evidence_refs) -contains "task_assignment_completed")

$projectId = "hosted-phase4-task-assignment-contract-" + [Guid]::NewGuid().ToString("N")
$sessionId = [Guid]::NewGuid().ToString()
$traceId = "hosted-task-assignment-" + [Guid]::NewGuid().ToString("N")
$body = @{
  project_id = $projectId
  session_id = $sessionId
  agent_type = "planner"
  task_type = "assignment_contract_probe"
  task_description = "verify hosted task assignment contract runtime parity"
  trace_id = $traceId
  priority = 9
  max_retries = 5
  allowed_tools = @("memory_read", "task_router")
  write_scope = @()
  blocked_actions = @("force_push", "live_provider_call", "prod_deploy", "production_db_write", "push_main", "secret_change")
  acceptance_criteria = @("result_envelope", "done_validation", "audit_log")
  human_review_required = $true
  policy_version = "task-policy-v1"
} | ConvertTo-Json -Compress
$created = Invoke-JsonApi -url "$BaseUrl/api/v1/internal/tasks" -method "POST" -body $body -contentType "application/json" -timeoutSeconds 20
Assert-True "task id returned" (-not [string]::IsNullOrWhiteSpace([string]$created.task.task_id))
Assert-True "created queued" ($created.task.status -eq "queued")
Assert-True "priority preserved on create" ([int]$created.task.priority -eq 9)
Assert-True "created queue depth visible" ($null -ne $created.queue_depth)
$taskId = [string]$created.task.task_id

$completed = Wait-TaskCompleted $BaseUrl $taskId
Assert-True "completed status" ($completed.task.status -eq "completed")
Assert-True "result envelope visible" ($null -ne $completed.task.result_envelope)
Assert-True "done validation logged" ($completed.task.done_validation.logged -eq $true)

$recentTasks = Invoke-JsonApi -url "$BaseUrl/api/v1/tasks/recent?limit=20" -method "GET" -contentType $null -timeoutSeconds 20
$recentTask = @($recentTasks.tasks) | Where-Object { $_.task_id -eq $taskId } | Select-Object -First 1
Assert-True "recent task visible" ($null -ne $recentTask)
Assert-True "recent task completed" ($recentTask.status -eq "completed")
Assert-True "recent task trace visible" (-not [string]::IsNullOrWhiteSpace([string]$recentTask.trace_id))
Assert-True "recent task request parity field visible" ($recentTask.PSObject.Properties.Name -contains "request_id")
Assert-True "recent queue depth high visible" ($null -ne $recentTasks.queue_depth_by_priority.high)
Assert-True "recent queue depth mid visible" ($null -ne $recentTasks.queue_depth_by_priority.mid)
Assert-True "recent queue depth low visible" ($null -ne $recentTasks.queue_depth_by_priority.low)

$agentStatus = Invoke-JsonApi -url "$BaseUrl/api/v1/agents/status" -method "GET" -contentType $null -timeoutSeconds 20
$planner = @($agentStatus.agents) | Where-Object { $_.type -eq "planner" } | Select-Object -First 1
Assert-True "planner status visible" ($null -ne $planner)
Assert-True "planner latest task id parity" ($planner.latest_task_id -eq $taskId)
Assert-True "planner latest status completed" ($planner.latest_status -eq "completed")

$metrics = Invoke-WebResponse -url "$BaseUrl/api/v1/metrics" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "metrics http 200" ($metrics.StatusCode -eq 200)
Assert-True "metrics queue depth counter visible" (($metrics.Content | Out-String).Contains("superbrain_task_queue_depth"))

Write-Host "[phase4-task-assignment-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-task-assignment-contract-runtime] result=verified"

param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted recent-tasks-contract runtime verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-recent-tasks-contract-runtime-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted recent-tasks-contract runtime verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
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
      throw "Phase4 hosted recent-tasks-contract runtime verification failed: task $taskId ended as $($taskState.task.status)."
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted recent-tasks-contract runtime verification failed: task $taskId did not complete in time."
}

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/tasks/recent/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "contract version" ($contract.contract_version -eq "recent-tasks-feed-v1")
Assert-True "queue fields visible" (@($contract.queue_fields) -contains "queue_depth")
Assert-True "supported escalated visible" (@($contract.supported_statuses) -contains "escalated")

$projectId = "hosted-phase4-recent-tasks-contract-" + [Guid]::NewGuid().ToString("N")
$sessionId = [Guid]::NewGuid().ToString()
$traceId = "hosted-recent-tasks-contract-" + [Guid]::NewGuid().ToString("N")
$body = @{
  project_id = $projectId
  session_id = $sessionId
  agent_type = "planner"
  task_type = "recent_tasks_contract_runtime"
  task_description = "verify hosted recent tasks contract runtime parity"
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
$taskId = $created.task.task_id
Assert-True "created task id" (-not [string]::IsNullOrWhiteSpace($taskId))

$completed = Wait-TaskCompleted -baseUrl $BaseUrl -taskId $taskId
Assert-True "completed status" ($completed.task.status -eq "completed")

$recent = Invoke-JsonApi -url "$BaseUrl/api/v1/tasks/recent?limit=40" -method "GET" -contentType $null -timeoutSeconds 20
$record = @($recent.tasks) | Where-Object { $_.task_id -eq $taskId } | Select-Object -First 1
Assert-True "recent task visible" ($null -ne $record)

foreach ($field in @($contract.top_level_fields)) {
  Assert-True "top level field visible $field" ($record.PSObject.Properties.Name -contains [string]$field)
}

Assert-True "request field visible" ($record.PSObject.Properties.Name -contains "request_id")
Assert-True "trace field visible" (-not [string]::IsNullOrWhiteSpace($record.trace_id))
Assert-True "trace parity" ($record.trace_id -eq $completed.task.trace_id)
Assert-True "priority parity" ([int]$record.priority -eq 9)
Assert-True "policy version parity" ($record.policy_version -eq "task-policy-v1")
Assert-True "done validation visible" ($record.done_validation.logged -eq $true)
Assert-True "queue depth by priority visible" ($null -ne $recent.queue_depth_by_priority.high)

$audit = Invoke-JsonApi -url "$BaseUrl/api/v1/audit/recent?limit=80" -method "GET" -contentType $null -timeoutSeconds 20
$auditText = $audit | ConvertTo-Json -Compress -Depth 10
Assert-True "audit contains task id" ($auditText.Contains($taskId))

Write-Host "[phase4-recent-tasks-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-recent-tasks-contract-runtime] result=verified"

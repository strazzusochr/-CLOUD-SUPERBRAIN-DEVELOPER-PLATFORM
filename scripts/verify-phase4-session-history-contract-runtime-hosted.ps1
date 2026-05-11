param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted session-history-contract runtime verification failed: $label"
  }
}

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase4 hosted session-history-contract runtime verification failed: $label did not contain '$expected'. Value: $text"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-session-history-contract-runtime-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted session-history-contract runtime verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

function Wait-SessionCompleted($baseUrl, $sessionId, $taskId, $attempts = 30) {
  for ($i = 0; $i -lt $attempts; $i++) {
    $history = Invoke-JsonApi -url "$baseUrl/api/v1/sessions/$sessionId/history" -method "GET" -contentType $null -timeoutSeconds 20
    $task = @($history.tasks) | Where-Object { $_.task_id -eq $taskId } | Select-Object -First 1
    if ($null -ne $task) {
      if ($task.status -eq "completed") {
        return $history
      }
      if ($task.status -in @("failed", "escalated", "abandoned_after_queue_drain")) {
        throw "Phase4 hosted session-history-contract runtime verification failed: task $taskId ended as $($task.status)."
      }
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted session-history-contract runtime verification failed: task $taskId did not complete in time."
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") {
  throw "Phase4 hosted session-history-contract proof requires HTTPS"
}

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/sessions/history/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "contract version" ($contract.contract_version -eq "session-history-v1")
Assert-True "top level sections visible" (@($contract.top_level_sections) -contains "audit_events")
Assert-True "supported completed visible" (@($contract.supported_statuses) -contains "completed")

$projectId = "hosted-phase4-session-history-contract-" + [Guid]::NewGuid().ToString("N")
$prompt = "phase4 session history contract runtime parity prompt"
$promptBody = @{
  project_id = $projectId
  prompt = $prompt
  stream = $false
} | ConvertTo-Json -Compress

$created = Invoke-JsonApi -url "$BaseUrl/api/v1/prompt" -method "POST" -body $promptBody -contentType "application/json" -timeoutSeconds 20
Assert-True "session id returned" (-not [string]::IsNullOrWhiteSpace($created.session_id))
Assert-True "task id returned" (-not [string]::IsNullOrWhiteSpace($created.task_id))

$history = Wait-SessionCompleted -baseUrl $BaseUrl -sessionId $created.session_id -taskId $created.task_id
Assert-True "history contract version" ($history.contract_version -eq "session-history-v1")
Assert-True "history evidence ref" ($history.evidence_ref -eq "session_history_openable_project_state")

foreach ($section in @($contract.top_level_sections)) {
  Assert-True "top level section visible $section" ($history.PSObject.Properties.Name -contains [string]$section)
}
foreach ($field in @($contract.session_fields)) {
  Assert-True "session field visible $field" ($history.session.PSObject.Properties.Name -contains [string]$field)
}

$taskRecord = @($history.tasks) | Where-Object { $_.task_id -eq $created.task_id } | Select-Object -First 1
Assert-True "history task visible" ($null -ne $taskRecord)
foreach ($field in @($contract.task_fields)) {
  Assert-True "task field visible $field" ($taskRecord.PSObject.Properties.Name -contains [string]$field)
}
Assert-True "session parity" ($history.session.session_id -eq $created.session_id)
Assert-True "project parity" ($history.session.project_id -eq $projectId)
Assert-True "prompt visible" (($history.messages | ConvertTo-Json -Depth 8 -Compress).Contains($prompt))
Assert-True "task status completed" ($taskRecord.status -eq "completed")
Assert-True "trace visible" (-not [string]::IsNullOrWhiteSpace($taskRecord.trace_id))

$recentSessions = Invoke-JsonApi -url "$BaseUrl/api/v1/sessions/recent?limit=20" -method "GET" -contentType $null -timeoutSeconds 20
$recentSession = @($recentSessions.sessions) | Where-Object { $_.session_id -eq $created.session_id } | Select-Object -First 1
Assert-True "recent session visible" ($null -ne $recentSession)
Assert-True "recent session latest task parity" ($recentSession.latest_task_id -eq $created.task_id)

$recentTasks = Invoke-JsonApi -url "$BaseUrl/api/v1/tasks/recent?limit=40" -method "GET" -contentType $null -timeoutSeconds 20
$recentTask = @($recentTasks.tasks) | Where-Object { $_.task_id -eq $created.task_id } | Select-Object -First 1
Assert-True "recent task visible" ($null -ne $recentTask)
Assert-True "recent task session parity" ($recentTask.session_id -eq $created.session_id)

$audit = Invoke-JsonApi -url "$BaseUrl/api/v1/audit/recent?limit=80" -method "GET" -contentType $null -timeoutSeconds 20
$auditText = $audit | ConvertTo-Json -Depth 12 -Compress
Assert-Contains "audit contains session id" $auditText $created.session_id
Assert-Contains "audit contains task id" $auditText $created.task_id

$activity = Invoke-JsonApi -url "$BaseUrl/api/v1/agent-activity/recent?limit=40" -method "GET" -contentType $null -timeoutSeconds 20
$activityText = $activity | ConvertTo-Json -Depth 12 -Compress
Assert-Contains "activity contains session id" $activityText $created.session_id
Assert-Contains "activity contains task id" $activityText $created.task_id

Write-Host "[phase4-session-history-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-session-history-contract-runtime] result=verified"

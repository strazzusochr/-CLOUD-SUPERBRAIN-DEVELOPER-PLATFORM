param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted recent-sessions-contract runtime verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-recent-sessions-contract-runtime-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted recent-sessions-contract runtime verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
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
        throw "Phase4 hosted recent-sessions-contract runtime verification failed: task $taskId ended as $($task.status)."
      }
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted recent-sessions-contract runtime verification failed: task $taskId did not complete in time."
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") {
  throw "Phase4 hosted recent-sessions-contract proof requires HTTPS"
}

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/sessions/recent/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "contract version" ($contract.contract_version -eq "recent-sessions-feed-v1")
Assert-True "supported completed visible" (@($contract.supported_statuses) -contains "completed")
Assert-True "supported escalated visible" (@($contract.supported_statuses) -contains "escalated")

$projectId = "hosted-phase4-recent-sessions-contract-" + [Guid]::NewGuid().ToString("N")
$prompt = "phase4 recent sessions contract runtime parity prompt"
$promptBody = @{
  project_id = $projectId
  prompt = $prompt
  stream = $false
} | ConvertTo-Json -Compress

$created = Invoke-JsonApi -url "$BaseUrl/api/v1/prompt" -method "POST" -body $promptBody -contentType "application/json" -timeoutSeconds 20
Assert-True "session id returned" (-not [string]::IsNullOrWhiteSpace($created.session_id))
Assert-True "task id returned" (-not [string]::IsNullOrWhiteSpace($created.task_id))

$history = Wait-SessionCompleted -baseUrl $BaseUrl -sessionId $created.session_id -taskId $created.task_id
$historyTask = @($history.tasks) | Where-Object { $_.task_id -eq $created.task_id } | Select-Object -First 1
Assert-True "history task visible" ($null -ne $historyTask)

$recentSessions = Invoke-JsonApi -url "$BaseUrl/api/v1/sessions/recent?limit=20" -method "GET" -contentType $null -timeoutSeconds 20
$sessionRecord = @($recentSessions.sessions) | Where-Object { $_.session_id -eq $created.session_id } | Select-Object -First 1
Assert-True "recent session visible" ($null -ne $sessionRecord)

foreach ($field in @($contract.top_level_fields)) {
  Assert-True "top level field visible $field" ($sessionRecord.PSObject.Properties.Name -contains [string]$field)
}

Assert-True "project parity" ($sessionRecord.project_id -eq $projectId)
Assert-True "latest task parity" ($sessionRecord.latest_task_id -eq $created.task_id)
Assert-True "latest task status parity" ($sessionRecord.latest_task_status -eq "completed")
Assert-True "prompt parity" ($sessionRecord.prompt -eq $prompt)
Assert-True "assistant result visible" (-not [string]::IsNullOrWhiteSpace($sessionRecord.assistant_result))
Assert-True "trace visible" (-not [string]::IsNullOrWhiteSpace($sessionRecord.trace_id))
Assert-True "history trace parity" ($sessionRecord.trace_id -eq $historyTask.trace_id)
Assert-True "request field visible" ($sessionRecord.PSObject.Properties.Name -contains "request_id")
Assert-True "correlation field visible" ($sessionRecord.PSObject.Properties.Name -contains "correlation_evidence_ref")
Assert-True "audit feed field visible" ($sessionRecord.PSObject.Properties.Name -contains "audit_feed_evidence_ref")

$recentTasks = Invoke-JsonApi -url "$BaseUrl/api/v1/tasks/recent?limit=40" -method "GET" -contentType $null -timeoutSeconds 20
$taskRecord = @($recentTasks.tasks) | Where-Object { $_.task_id -eq $created.task_id } | Select-Object -First 1
Assert-True "recent task visible" ($null -ne $taskRecord)
Assert-True "recent task session parity" ($taskRecord.session_id -eq $created.session_id)

$activity = Invoke-JsonApi -url "$BaseUrl/api/v1/agent-activity/recent?limit=40" -method "GET" -contentType $null -timeoutSeconds 20
$activityText = $activity | ConvertTo-Json -Depth 10 -Compress
Assert-True "activity contains session id" ($activityText.Contains($created.session_id))
Assert-True "activity contains task id" ($activityText.Contains($created.task_id))

$audit = Invoke-JsonApi -url "$BaseUrl/api/v1/audit/recent?limit=80" -method "GET" -contentType $null -timeoutSeconds 20
$auditText = $audit | ConvertTo-Json -Depth 10 -Compress
Assert-True "audit contains session id" ($auditText.Contains($created.session_id))
Assert-True "audit contains task id" ($auditText.Contains($created.task_id))

Write-Host "[phase4-recent-sessions-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-recent-sessions-contract-runtime] result=verified"

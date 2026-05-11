param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted audit-feed-contract runtime verification failed: $label"
  }
}

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase4 hosted audit-feed-contract runtime verification failed: $label did not contain '$expected'. Value: $text"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-audit-feed-contract-runtime-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted audit-feed-contract runtime verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
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
        throw "Phase4 hosted audit-feed-contract runtime verification failed: task $taskId ended as $($task.status)."
      }
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted audit-feed-contract runtime verification failed: task $taskId did not complete in time."
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") {
  throw "Phase4 hosted audit-feed-contract proof requires HTTPS"
}

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/audit/recent/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "contract version" ($contract.contract_version -eq "audit-feed-v1")
Assert-True "supported task_completed visible" (@($contract.supported_event_types) -contains "task_completed")
Assert-True "top level request field visible" (@($contract.top_level_fields) -contains "request_id")

$projectId = "hosted-phase4-audit-feed-contract-" + [Guid]::NewGuid().ToString("N")
$prompt = "phase4 audit feed contract runtime parity prompt"
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

$audit = Invoke-JsonApi -url "$BaseUrl/api/v1/audit/recent?limit=80" -method "GET" -contentType $null -timeoutSeconds 20
$auditRecord = @($audit.events) | Where-Object {
  $_.session_id -eq $created.session_id -and (
    ($_.details.task_id -eq $created.task_id) -or
    (($_ | ConvertTo-Json -Depth 8 -Compress).Contains($created.task_id))
  )
} | Select-Object -First 1
Assert-True "audit record visible" ($null -ne $auditRecord)

foreach ($field in @($contract.top_level_fields)) {
  Assert-True "top level field visible $field" ($auditRecord.PSObject.Properties.Name -contains [string]$field)
}

Assert-True "event type completed" ($auditRecord.event_type -eq "task_completed")
Assert-True "session parity" ($auditRecord.session_id -eq $created.session_id)
Assert-True "trace visible" (-not [string]::IsNullOrWhiteSpace($auditRecord.trace_id))
Assert-True "trace parity" ($auditRecord.trace_id -eq $historyTask.trace_id)
Assert-True "correlation evidence visible" (-not [string]::IsNullOrWhiteSpace($auditRecord.correlation_evidence_ref))
Assert-True "audit feed evidence visible" ($auditRecord.audit_feed_evidence_ref -eq "request_id_audit_feed_visible")

$recentTasks = Invoke-JsonApi -url "$BaseUrl/api/v1/tasks/recent?limit=40" -method "GET" -contentType $null -timeoutSeconds 20
$taskRecord = @($recentTasks.tasks) | Where-Object { $_.task_id -eq $created.task_id } | Select-Object -First 1
Assert-True "recent task visible" ($null -ne $taskRecord)

$activity = Invoke-JsonApi -url "$BaseUrl/api/v1/agent-activity/recent?limit=40" -method "GET" -contentType $null -timeoutSeconds 20
$activityText = $activity | ConvertTo-Json -Depth 12 -Compress
Assert-Contains "activity contains task id" $activityText $created.task_id
Assert-Contains "activity contains session id" $activityText $created.session_id

$historyText = $history | ConvertTo-Json -Depth 12 -Compress
Assert-Contains "history contains task id" $historyText $created.task_id
Assert-Contains "history contains prompt" $historyText $prompt

Write-Host "[phase4-audit-feed-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-audit-feed-contract-runtime] result=verified"

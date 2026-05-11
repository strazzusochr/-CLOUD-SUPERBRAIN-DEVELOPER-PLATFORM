param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase4 hosted session-stream verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted session-stream verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-session-stream-response-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted session-stream verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

function Invoke-SseText($url, [hashtable]$headers = $null, $maxTime = 10) {
  $payload = [pscustomobject]@{
    url = $url
    headers = $headers
    maxTime = $maxTime
  } | ConvertTo-Json -Depth 8 -Compress
  $python = @'
import json
import ssl
import sys
import time
import urllib.request

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)
request = urllib.request.Request(payload["url"], headers=payload.get("headers") or {})
deadline = time.time() + payload.get("maxTime", 10)
chunks = []
context = ssl._create_unverified_context() if payload["url"].startswith("https://") else None
with urllib.request.urlopen(request, timeout=5, context=context) as response:
    while time.time() < deadline:
        line = response.readline()
        if not line:
            break
        decoded = line.decode("utf-8", errors="replace")
        chunks.append(decoded)
        if decoded.startswith("event: done"):
            break
        if '"replay":true' in decoded and decoded.startswith("data:"):
            continue
print("".join(chunks))
'@
  $payloadFile = Join-Path $env:TEMP ("phase4-session-stream-sse-" + [Guid]::NewGuid().ToString("N") + ".json")
  try {
    Set-Content -LiteralPath $payloadFile -Value $payload -NoNewline
    return ($python | py -3 - $payloadFile)
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
  }
}

function Wait-SseContains($label, $url, $expected, $attempts = 3, $maxTime = 10, $lastEventId = $null) {
  $last = ""
  for ($i = 0; $i -lt $attempts; $i++) {
    $headers = @{}
    if ($lastEventId) {
      $headers["Last-Event-ID"] = $lastEventId
    }
    $text = Invoke-SseText -url $url -headers $headers -maxTime $maxTime
    if (($text | Out-String).Contains($expected)) {
      return $text
    }
    $last = $text
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted session-stream verification failed: $label did not contain '$expected'. Value: $last"
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
        throw "Phase4 hosted session-stream verification failed: task $taskId ended as $($task.status)."
      }
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted session-stream verification failed: task $taskId did not complete in time."
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") {
  throw "Phase4 hosted session-stream proof requires HTTPS"
}

Write-Host "[phase4-hosted-session-stream] base url: $BaseUrl"

$projectId = "hosted-phase4-session-stream-" + [Guid]::NewGuid().ToString("N")
$prompt = "phase4 session stream parity prompt"
$promptBody = @{
  project_id = $projectId
  prompt = $prompt
  stream = $true
} | ConvertTo-Json -Compress
$created = Invoke-JsonApi -url "$BaseUrl/api/v1/prompt" -method "POST" -body $promptBody -contentType "application/json" -timeoutSeconds 20
Assert-True "session id returned" (-not [string]::IsNullOrWhiteSpace($created.session_id))
Assert-True "task id returned" (-not [string]::IsNullOrWhiteSpace($created.task_id))
Assert-True "stream url returned" (-not [string]::IsNullOrWhiteSpace($created.stream_url))

$history = Wait-SessionCompleted $BaseUrl $created.session_id $created.task_id
$historyText = $history | ConvertTo-Json -Depth 10 -Compress
Assert-True "session history contract version" ($history.contract_version -eq "session-history-v1")
Assert-Contains "history session id" $historyText $created.session_id
Assert-Contains "history project id" $historyText $projectId
Assert-Contains "history prompt" $historyText $prompt
Assert-Contains "history task id" $historyText $created.task_id
Assert-Contains "history completed result" $historyText "Phase-1 worker completed deterministic execution without LLM calls"
Assert-Contains "history evidence ref" $historyText "session_history_openable_project_state"

$streamUrl = "$BaseUrl$($created.stream_url)"
$stream = Wait-SseContains "initial stream heartbeat" $streamUrl "event: heartbeat" 3 10
Assert-Contains "initial stream id" $stream "id: 1"
Assert-Contains "initial stream heartbeat" $stream "event: heartbeat"
Assert-Contains "initial stream agent status" $stream "event: agent_status"
Assert-Contains "initial stream token" $stream "event: token"
Assert-Contains "initial stream done" $stream "event: done"
Assert-Contains "initial stream task id" $stream $created.task_id
Assert-Contains "initial stream deterministic result" $stream "Phase-1 worker completed deterministic execution without LLM calls"

$replay = Wait-SseContains "replay stream replay flag" $streamUrl '"replay":true' 3 10 "0"
Assert-Contains "replay stream id" $replay "id: 1"
Assert-Contains "replay heartbeat replay flag" $replay '"replay":true'
Assert-Contains "replay task id" $replay $created.task_id
Assert-Contains "replay deterministic result" $replay "Phase-1 worker completed deterministic execution without LLM calls"
Assert-Contains "replay done" $replay "event: done"

$recentSessions = Invoke-JsonApi -url "$BaseUrl/api/v1/sessions/recent?limit=10" -method "GET" -contentType $null -timeoutSeconds 15
$recentSessionsText = $recentSessions | ConvertTo-Json -Depth 8 -Compress
Assert-Contains "recent sessions include session id" $recentSessionsText $created.session_id
Assert-Contains "recent sessions include task id" $recentSessionsText $created.task_id
Assert-Contains "recent sessions include prompt" $recentSessionsText $prompt

$audit = Invoke-JsonApi -url "$BaseUrl/api/v1/audit/recent?limit=20" -method "GET" -contentType $null -timeoutSeconds 15
$auditText = $audit | ConvertTo-Json -Depth 10 -Compress
Assert-Contains "audit task completed" $auditText "task_completed"
Assert-Contains "audit session id" $auditText $created.session_id
Assert-Contains "audit task id" $auditText $created.task_id

Write-Host "[phase4-hosted-session-stream] checks completed"

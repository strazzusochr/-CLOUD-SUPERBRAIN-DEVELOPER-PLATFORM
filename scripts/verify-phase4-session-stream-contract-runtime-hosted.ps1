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
    throw "Phase4 hosted session-stream-contract verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted session-stream-contract verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-session-stream-contract-response-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted session-stream-contract verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
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
print("".join(chunks))
'@
  $payloadFile = Join-Path $env:TEMP ("phase4-session-stream-contract-sse-" + [Guid]::NewGuid().ToString("N") + ".json")
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
  throw "Phase4 hosted session-stream-contract verification failed: $label did not contain '$expected'. Value: $last"
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
        throw "Phase4 hosted session-stream-contract verification failed: task $taskId ended as $($task.status)."
      }
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted session-stream-contract verification failed: task $taskId did not complete in time."
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted session-stream-contract proof requires HTTPS" }

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/session/stream/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "surface contract version" ($contract.contract_version -eq "session-stream-surface-v1")
Assert-True "endpoint parity" ($contract.endpoint -eq "GET /api/v1/session/stream/contract")
Assert-True "runtime endpoint parity" ($contract.runtime_endpoint -eq "GET /api/v1/session/{session_id}/stream")
Assert-True "content type parity" ($contract.content_type -eq "text/event-stream")
Assert-True "replay header parity" ($contract.replay_header -eq "Last-Event-ID")
Assert-True "required event token" (@($contract.required_event_types) -contains "token")
Assert-True "required event done" (@($contract.required_event_types) -contains "done")

$projectId = "hosted-phase4-session-stream-contract-" + [Guid]::NewGuid().ToString("N")
$prompt = "phase4 session stream contract parity prompt"
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
Assert-True "history contract version" ($history.contract_version -eq "session-history-v1")
Assert-Contains "history task id" $historyText $created.task_id

$streamUrl = "$BaseUrl$($created.stream_url)"
$stream = Wait-SseContains "initial stream done" $streamUrl "event: done" 3 10
Assert-Contains "initial heartbeat" $stream "event: heartbeat"
Assert-Contains "initial agent status" $stream "event: agent_status"
Assert-Contains "initial token" $stream "event: token"
Assert-Contains "initial done" $stream "event: done"
Assert-Contains "initial task id" $stream $created.task_id
Assert-Contains "initial result text" $stream "Phase-1 worker completed deterministic execution without LLM calls"

$replay = Wait-SseContains "replay flag" $streamUrl '"replay":true' 3 10 "0"
Assert-Contains "replay done" $replay "event: done"
Assert-Contains "replay task id" $replay $created.task_id

$recentSessions = Invoke-JsonApi -url "$BaseUrl/api/v1/sessions/recent?limit=10" -method "GET" -contentType $null -timeoutSeconds 15
$recentSessionsText = $recentSessions | ConvertTo-Json -Depth 8 -Compress
Assert-Contains "recent sessions session id" $recentSessionsText $created.session_id
Assert-Contains "recent sessions task id" $recentSessionsText $created.task_id

$audit = Invoke-JsonApi -url "$BaseUrl/api/v1/audit/recent?limit=20" -method "GET" -contentType $null -timeoutSeconds 15
$auditText = $audit | ConvertTo-Json -Depth 10 -Compress
Assert-Contains "audit task completed" $auditText "task_completed"
Assert-Contains "audit session id" $auditText $created.session_id

Write-Host "[phase4-session-stream-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-session-stream-contract-runtime] result=verified"

param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [string]$KeyPath = "C:\Users\immer\.ssh\oracle_key",
  [string]$StagingHost = "188.34.191.140",
  [string]$RemoteUser = "root",
  [string]$RemoteRootPath = "/app"
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase4 hosted session-memory verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted session-memory verification failed: $label"
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
import ssl

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
  $payloadFile = Join-Path $env:TEMP ("phase4-session-memory-response-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted session-memory verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

function Wait-SessionTaskCompleted($baseUrl, $sessionId, $taskId, $attempts = 30) {
  for ($i = 0; $i -lt $attempts; $i++) {
    $history = Invoke-JsonApi -url "$baseUrl/api/v1/sessions/$sessionId/history" -method "GET" -contentType $null -timeoutSeconds 20
    $task = @($history.tasks) | Where-Object { $_.task_id -eq $taskId } | Select-Object -First 1
    if ($null -ne $task) {
      if ($task.status -eq "completed") {
        return $history
      }
      if ($task.status -in @("failed", "escalated", "abandoned_after_queue_drain")) {
        throw "Phase4 hosted session-memory verification failed: task $taskId ended as $($task.status)."
      }
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted session-memory verification failed: task $taskId did not complete in time."
}

function Invoke-RemoteMemoryConsolidation($projectId, $sessionId) {
  if (-not (Test-Path -LiteralPath $KeyPath)) {
    throw "Phase4 hosted session-memory verification failed: SSH key path not found: $KeyPath"
  }

  $needle = "phase4 hosted memory parity " + [Guid]::NewGuid().ToString("N")
  $idem = "phase4-memory-" + [Guid]::NewGuid().ToString("N")
  $localPy = Join-Path $env:TEMP ("phase4-session-memory-seed-" + [Guid]::NewGuid().ToString("N") + ".py")
  $remotePy = "/tmp/phase4_session_memory_seed.py"
  $script = @"
import json
import subprocess

project_id = "$projectId"
session_id = "$sessionId"
needle = "$needle"
idem = "$idem"
payload = {
    "project_id": project_id,
    "session_id": session_id,
    "content_text": needle,
    "metadata": {"source": "phase4_session_memory_parity_hosted"},
    "idempotency_key": idem,
}
seed = "import json, os, redis; client=redis.Redis.from_url(os.environ['REDIS_URL']); key='memory:working:{0}'; payload={1}; client.set(key, json.dumps(payload), ex=300); print(client.ttl(key))".format(idem, repr(payload))
subprocess.run(["docker", "compose", "--env-file", ".env", "-f", "docker-compose.cloud.yml", "exec", "-T", "agent-api", "python", "-c", seed], check=True)
run = subprocess.run(["docker", "compose", "--env-file", ".env", "-f", "docker-compose.cloud.yml", "exec", "-T", "memory-worker", "python", "-m", "app.worker", "--once"], check=True, capture_output=True, text=True)
print(json.dumps({"needle": needle, "idempotency_key": idem, "worker_output": run.stdout.strip()}, ensure_ascii=True))
"@
  Set-Content -LiteralPath $localPy -Value $script -Encoding UTF8
  try {
    $target = "{0}@{1}:{2}" -f $RemoteUser, $StagingHost, $remotePy
    scp -i $KeyPath -o StrictHostKeyChecking=no $localPy $target | Out-Null
    $output = ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingHost" "cd $RemoteRootPath && python3 $remotePy"
    return (($output | Select-Object -Last 1) | ConvertFrom-Json)
  } finally {
    Remove-Item -LiteralPath $localPy -Force -ErrorAction SilentlyContinue
    ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingHost" "rm -f $remotePy" | Out-Null
  }
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") {
  throw "Phase4 hosted session-memory proof requires HTTPS"
}

Write-Host "[phase4-hosted-session-memory] base url: $BaseUrl"

$health = Invoke-JsonApi -url "$BaseUrl/api/v1/health" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "agent worker healthy" ($health.services.agent_worker.status -eq "healthy")
Assert-True "memory worker healthy" ($health.services.memory_worker.status -eq "healthy")

$projectId = "hosted-phase4-session-memory-" + [Guid]::NewGuid().ToString("N")
$prompt = "phase4 session memory parity proof prompt"
$promptBody = @{
  project_id = $projectId
  prompt = $prompt
  stream = $true
} | ConvertTo-Json -Compress
$created = Invoke-JsonApi -url "$BaseUrl/api/v1/prompt" -method "POST" -body $promptBody -contentType "application/json" -timeoutSeconds 20
Assert-True "session id returned" (-not [string]::IsNullOrWhiteSpace($created.session_id))
Assert-True "task id returned" (-not [string]::IsNullOrWhiteSpace($created.task_id))
Assert-True "memory id returned" (-not [string]::IsNullOrWhiteSpace($created.memory_id))

$history = Wait-SessionTaskCompleted $BaseUrl $created.session_id $created.task_id
Assert-True "session history contract version" ($history.contract_version -eq "session-history-v1")
Assert-True "history session id matches" ($history.session.session_id -eq $created.session_id)
Assert-True "history latest task id matches" ($history.session.metadata.latest_task_id -eq $created.task_id)
Assert-Contains "history prompt visible" ($history | ConvertTo-Json -Depth 10 -Compress) $prompt
Assert-Contains "history worker result visible" ($history | ConvertTo-Json -Depth 10 -Compress) "Phase-1 worker completed deterministic execution without LLM calls"

$seeded = Invoke-RemoteMemoryConsolidation -projectId $projectId -sessionId $created.session_id
Assert-Contains "memory worker one-shot consolidated" $seeded.worker_output '"consolidated": 1'

$recentSessions = Invoke-JsonApi -url "$BaseUrl/api/v1/sessions/recent?limit=10" -method "GET" -contentType $null -timeoutSeconds 15
$recentSessionsText = $recentSessions | ConvertTo-Json -Depth 8 -Compress
Assert-Contains "recent sessions include project id" $recentSessionsText $projectId
Assert-Contains "recent sessions include session id" $recentSessionsText $created.session_id
Assert-Contains "recent sessions include task id" $recentSessionsText $created.task_id

$historyAfterMemory = Invoke-JsonApi -url "$BaseUrl/api/v1/sessions/$($created.session_id)/history" -method "GET" -contentType $null -timeoutSeconds 20
$historyAfterText = $historyAfterMemory | ConvertTo-Json -Depth 10 -Compress
Assert-Contains "history memory consolidated event" $historyAfterText "memory_consolidated"
Assert-Contains "history memory idempotency" $historyAfterText $seeded.idempotency_key

$encodedNeedle = [uri]::EscapeDataString([string]$seeded.needle)
$search = Invoke-JsonApi -url "$BaseUrl/api/v1/memory/search?q=$encodedNeedle&project_id=$projectId&limit=5" -method "GET" -contentType $null -timeoutSeconds 20
$searchText = $search | ConvertTo-Json -Depth 8 -Compress
Assert-Contains "memory search needle" $searchText $seeded.needle
Assert-Contains "memory search mode" $searchText '"search_mode":"lexical_fallback"'

$consolidation = Invoke-JsonApi -url "$BaseUrl/api/v1/memory/consolidation/recent?limit=10" -method "GET" -contentType $null -timeoutSeconds 20
$consolidationText = $consolidation | ConvertTo-Json -Depth 10 -Compress
Assert-Contains "consolidation event type" $consolidationText "memory_consolidated"
Assert-Contains "consolidation idempotency key" $consolidationText $seeded.idempotency_key
Assert-Contains "consolidation session id" $consolidationText $created.session_id

$metrics = Invoke-WebResponse -url "$BaseUrl/api/v1/metrics" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "metrics http 200" ($metrics.StatusCode -eq 200)
Assert-Contains "metrics memory worker health" $metrics.Content 'superbrain_service_health{service="memory_worker"} 1'
Assert-Contains "metrics agent sessions total" $metrics.Content "superbrain_agent_sessions_total"
Assert-Contains "metrics memory entries total" $metrics.Content "superbrain_memory_entries_total"
Assert-Contains "metrics memory consolidation counter" $metrics.Content 'superbrain_memory_consolidation_events_total{event_type="memory_consolidated",reason="none",severity="info"}'

Write-Host "[phase4-hosted-session-memory] checks completed"

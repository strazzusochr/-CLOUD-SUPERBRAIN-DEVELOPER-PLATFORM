param(
  [string]$BaseUrl = $(if ($env:STAGING_BASE_URL) { $env:STAGING_BASE_URL } else { "" }),
  [string]$KeyPath = $env:STAGING_SSH_KEY_PATH,
  [string]$StagingHost = $env:STAGING_SSH_HOST,
  [string]$RemoteUser = "root",
  [string]$RemoteRootPath = "/app"
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
    throw "Phase4 hosted failure-cross-surface verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-failure-cross-surface-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted failure-cross-surface verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

function Invoke-RemoteSeedFailureCrossSurface() {
  $traceId = [Guid]::NewGuid().ToString()
  $projectId = [Guid]::NewGuid().ToString()
  $coderSessionId = [Guid]::NewGuid().ToString()
  $testerSessionId = [Guid]::NewGuid().ToString()
  $coderTaskId = [Guid]::NewGuid().ToString()
  $testerTaskId = [Guid]::NewGuid().ToString()
  $localPy = Join-Path $env:TEMP ("phase4-failure-cross-surface-seed-" + [Guid]::NewGuid().ToString("N") + ".py")
  $remotePy = "/tmp/phase4_failure_cross_surface_seed.py"
  $script = @"
import json
import os
import subprocess

seed_code = r'''
from datetime import datetime, timedelta, timezone
import json
import os
import psycopg
from psycopg.types.json import Json
import redis

project_id = "$projectId"
trace_id = "$traceId"
coder_session_id = "$coderSessionId"
tester_session_id = "$testerSessionId"
coder_task_id = "$coderTaskId"
tester_task_id = "$testerTaskId"
now = datetime.now(timezone.utc)
old = (now - timedelta(seconds=180)).isoformat()

def task(task_id, session_id, agent_type, status, retry_count, max_retries, error, task_type):
    return {
        "project_id": project_id,
        "session_id": session_id,
        "agent_type": agent_type,
        "task_type": task_type,
        "task_description": "hosted cross-surface failure proof for " + task_type,
        "task_id": task_id,
        "status": status,
        "created_at": old,
        "updated_at": old,
        "trace_id": trace_id,
        "priority": 5,
        "max_retries": max_retries,
        "allowed_tools": ["memory_read", "task_router"],
        "write_scope": [],
        "blocked_actions": ["force_push", "live_provider_call", "prod_deploy", "push_main", "delete_without_approval"],
        "acceptance_criteria": ["result_envelope", "done_validation", "audit_log"],
        "human_review_required": True,
        "policy_version": "task-policy-v1",
        "retry_count": retry_count,
        "result": None,
        "error": error,
        "result_envelope": None,
        "done_validation": None,
    }

with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO projects(id, name, owner_id, metadata)
            VALUES (%s, 'hosted-phase4-failure-cross-surface', 'runtime-verifier', %s)
            ON CONFLICT (id) DO NOTHING
            """,
            (project_id, Json({"source": "verify-phase4-failure-cross-surface-hosted"})),
        )
        cur.execute(
            """
            INSERT INTO agent_sessions(id, project_id, agent_list, metadata)
            VALUES (%s, %s, %s, %s), (%s, %s, %s, %s)
            ON CONFLICT (id) DO NOTHING
            """,
            (
                coder_session_id, project_id, ["planner", "coder", "tester", "devops"], Json({"trace_id": trace_id, "latest_task_id": coder_task_id}),
                tester_session_id, project_id, ["planner", "coder", "tester", "devops"], Json({"trace_id": trace_id, "latest_task_id": tester_task_id}),
            ),
        )
        cur.execute(
            """
            INSERT INTO audit_log(event_type, session_id, details, severity, created_at)
            VALUES
              ('task_escalated', %s, %s, 'warning', %s),
              ('task_abandoned_after_queue_drain', %s, %s, 'warning', %s)
            """,
            (
                coder_session_id,
                Json({
                    "trace_id": trace_id,
                    "task_id": coder_task_id,
                    "agent_type": "coder",
                    "status": "escalated",
                    "retry_count": 1,
                    "max_retries": 1,
                    "error": "foreign_key_violation_cross_surface_escalated",
                }),
                now,
                tester_session_id,
                Json({
                    "trace_id": trace_id,
                    "task_id": tester_task_id,
                    "agent_type": "tester",
                    "status": "abandoned_after_queue_drain",
                    "retry_count": 0,
                    "max_retries": 1,
                    "error": "stale queued task abandoned after bounded rescue cross surface",
                }),
                now,
            ),
        )

client = redis.Redis.from_url(os.environ["REDIS_URL"], decode_responses=True)
client.set("task:status:" + coder_task_id, json.dumps(task(coder_task_id, coder_session_id, "coder", "escalated", 1, 1, "foreign_key_violation_cross_surface_escalated", "hosted_cross_surface_coder"), separators=(",", ":")), ex=86400)
client.set("task:status:" + tester_task_id, json.dumps(task(tester_task_id, tester_session_id, "tester", "abandoned_after_queue_drain", 0, 1, "stale queued task abandoned after bounded rescue cross surface", "hosted_cross_surface_tester"), separators=(",", ":")), ex=86400)

print(json.dumps({
    "trace_id": trace_id,
    "coder_session_id": coder_session_id,
    "tester_session_id": tester_session_id,
    "coder_task_id": coder_task_id,
    "tester_task_id": tester_task_id,
}))
'''.strip()

compose = [
    "docker", "compose",
    "--env-file", os.path.join("$RemoteRootPath", ".env"),
    "-f", os.path.join("$RemoteRootPath", "docker-compose.cloud.yml"),
]
subprocess.run(compose + ["exec", "-T", "agent-api", "python", "-c", seed_code], check=True)
print(json.dumps({
    "trace_id": "$traceId",
    "coder_session_id": "$coderSessionId",
    "tester_session_id": "$testerSessionId",
    "coder_task_id": "$coderTaskId",
    "tester_task_id": "$testerTaskId",
}))
"@
  Set-Content -LiteralPath $localPy -Value $script
  try {
    scp -i $KeyPath -o StrictHostKeyChecking=no $localPy "${RemoteUser}@${StagingHost}:$remotePy" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Phase4 hosted failure-cross-surface verification failed: could not copy seed script" }
    $raw = ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingHost" "python3 $remotePy"
    if ($LASTEXITCODE -ne 0) { throw "Phase4 hosted failure-cross-surface verification failed: remote seed execution failed" }
    $jsonLine = @($raw -split "`r?`n" | Where-Object { $_.Trim() }) | Select-Object -Last 1
    return ($jsonLine | ConvertFrom-Json)
  } finally {
    if (Test-Path -LiteralPath $localPy) { Remove-Item -LiteralPath $localPy -Force }
    ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingHost" "rm -f $remotePy" | Out-Null
  }
}

function Wait-ActivityEvents($baseUrl, $traceId, $attempts = 20) {
  $last = $null
  for ($i = 0; $i -lt $attempts; $i++) {
    $last = Invoke-JsonApi -url "$baseUrl/api/v1/agent-activity/recent?limit=20&trace_id=$traceId" -method "GET" -contentType $null -timeoutSeconds 20
    if ((@($last.events) | Measure-Object).Count -ge 2) { return $last }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted failure-cross-surface verification failed: activity events not visible for trace $traceId"
}

$seed = Invoke-RemoteSeedFailureCrossSurface
$activity = Wait-ActivityEvents -baseUrl $BaseUrl -traceId $seed.trace_id
$events = @($activity.events)
$coderActivity = $events | Where-Object { $_.task_id -eq $seed.coder_task_id } | Select-Object -First 1
$testerActivity = $events | Where-Object { $_.task_id -eq $seed.tester_task_id } | Select-Object -First 1

$tasksRecent = Invoke-JsonApi -url "$BaseUrl/api/v1/tasks/recent?limit=50" -method "GET" -contentType $null -timeoutSeconds 20
$sessionsRecent = Invoke-JsonApi -url "$BaseUrl/api/v1/sessions/recent?limit=50" -method "GET" -contentType $null -timeoutSeconds 20
$coderHistory = Invoke-JsonApi -url "$BaseUrl/api/v1/sessions/$($seed.coder_session_id)/history" -method "GET" -contentType $null -timeoutSeconds 20
$testerHistory = Invoke-JsonApi -url "$BaseUrl/api/v1/sessions/$($seed.tester_session_id)/history" -method "GET" -contentType $null -timeoutSeconds 20

$coderTask = @($tasksRecent.tasks) | Where-Object { $_.task_id -eq $seed.coder_task_id } | Select-Object -First 1
$testerTask = @($tasksRecent.tasks) | Where-Object { $_.task_id -eq $seed.tester_task_id } | Select-Object -First 1
$coderSession = @($sessionsRecent.sessions) | Where-Object { $_.session_id -eq $seed.coder_session_id } | Select-Object -First 1
$testerSession = @($sessionsRecent.sessions) | Where-Object { $_.session_id -eq $seed.tester_session_id } | Select-Object -First 1
$coderHistoryTask = @($coderHistory.tasks) | Where-Object { $_.task_id -eq $seed.coder_task_id } | Select-Object -First 1
$testerHistoryTask = @($testerHistory.tasks) | Where-Object { $_.task_id -eq $seed.tester_task_id } | Select-Object -First 1

Assert-True "coder activity visible" ($null -ne $coderActivity)
Assert-True "tester activity visible" ($null -ne $testerActivity)
Assert-True "coder task recent visible" ($null -ne $coderTask)
Assert-True "tester task recent visible" ($null -ne $testerTask)
Assert-True "coder session recent visible" ($null -ne $coderSession)
Assert-True "tester session recent visible" ($null -ne $testerSession)
Assert-True "coder history task visible" ($null -ne $coderHistoryTask)
Assert-True "tester history task visible" ($null -ne $testerHistoryTask)

Assert-True "coder status parity activity->task" ($coderActivity.task_status -eq $coderTask.status)
Assert-True "tester status parity activity->task" ($testerActivity.task_status -eq $testerTask.status)
Assert-True "coder status parity task->history" ($coderTask.status -eq $coderHistoryTask.status)
Assert-True "tester status parity task->history" ($testerTask.status -eq $testerHistoryTask.status)
Assert-True "coder retry parity" ([int]$coderActivity.retry_count -eq [int]$coderTask.retry_count -and [int]$coderTask.retry_count -eq [int]$coderHistoryTask.retry_count)
Assert-True "tester retry parity" ([int]$testerActivity.retry_count -eq [int]$testerTask.retry_count -and [int]$testerTask.retry_count -eq [int]$testerHistoryTask.retry_count)
Assert-True "coder max retry parity" ([int]$coderActivity.max_retries -eq [int]$coderTask.max_retries -and [int]$coderTask.max_retries -eq [int]$coderHistoryTask.max_retries)
Assert-True "tester max retry parity" ([int]$testerActivity.max_retries -eq [int]$testerTask.max_retries -and [int]$testerTask.max_retries -eq [int]$testerHistoryTask.max_retries)
Assert-True "coder session latest task parity" ($coderSession.latest_task_id -eq $seed.coder_task_id -and $coderSession.latest_task_status -eq "escalated")
Assert-True "tester session latest task parity" ($testerSession.latest_task_id -eq $seed.tester_task_id -and $testerSession.latest_task_status -eq "abandoned_after_queue_drain")
Assert-True "coder error visible everywhere" (($coderActivity.error | Out-String).Contains("foreign_key_violation_cross_surface_escalated") -and ($coderTask.error | Out-String).Contains("foreign_key_violation_cross_surface_escalated") -and ($coderHistoryTask.error | Out-String).Contains("foreign_key_violation_cross_surface_escalated"))
Assert-True "tester error visible everywhere" (($testerActivity.error | Out-String).Contains("stale queued task abandoned after bounded rescue cross surface") -and ($testerTask.error | Out-String).Contains("stale queued task abandoned after bounded rescue cross surface") -and ($testerHistoryTask.error | Out-String).Contains("stale queued task abandoned after bounded rescue cross surface"))

Write-Host "[phase4-hosted-failure-cross-surface] checks completed"

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


function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase4 hosted session-failure-history verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted session-failure-history verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-session-failure-history-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted session-failure-history verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

function Wait-TaskStatus($baseUrl, $taskId, $expectedStatus, $attempts = 45) {
  $last = $null
  for ($i = 0; $i -lt $attempts; $i++) {
    $last = Invoke-JsonApi -url "$baseUrl/api/v1/internal/tasks/$taskId" -method "GET" -contentType $null -timeoutSeconds 20
    if ($last.task.status -eq $expectedStatus) {
      return $last
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted session-failure-history verification failed: task $taskId did not become $expectedStatus. Value: $($last | ConvertTo-Json -Depth 8 -Compress)"
}

function Invoke-RemoteSeedSessionFailureState() {
  if (-not (Test-Path -LiteralPath $KeyPath)) {
    throw "Phase4 hosted session-failure-history verification failed: SSH key path not found: $KeyPath"
  }

  $seedProjectId = [Guid]::NewGuid().ToString()
  $rehydrateSessionId = [Guid]::NewGuid().ToString()
  $abandonSessionId = [Guid]::NewGuid().ToString()
  $rehydrateTaskId = [Guid]::NewGuid().ToString()
  $abandonTaskId = [Guid]::NewGuid().ToString()
  $rehydrateSummary = "Hosted session failure rehydrate proof completed from audit."
  $localPy = Join-Path $env:TEMP ("phase4-session-failure-seed-" + [Guid]::NewGuid().ToString("N") + ".py")
  $remotePy = "/tmp/phase4_session_failure_seed.py"
  $script = @"
import json
import subprocess

seed_code = r'''
import json
import os
from datetime import datetime, timedelta, timezone

import psycopg
from psycopg.types.json import Json
import redis

project_id = "$seedProjectId"
rehydrate_session_id = "$rehydrateSessionId"
abandon_session_id = "$abandonSessionId"
rehydrate_task_id = "$rehydrateTaskId"
abandon_task_id = "$abandonTaskId"
rehydrate_summary = "$rehydrateSummary"
now = datetime.now(timezone.utc)
old = (now - timedelta(seconds=180)).isoformat()

def task(task_id, session_id, agent_type, task_type):
    return {
        "project_id": project_id,
        "session_id": session_id,
        "agent_type": agent_type,
        "task_type": task_type,
        "task_description": "hosted session failure surface parity proof for " + task_type,
        "task_id": task_id,
        "status": "queued",
        "created_at": old,
        "updated_at": old,
        "trace_id": "hosted-phase4-session-failure:" + task_id,
        "priority": 5,
        "max_retries": 1,
        "allowed_tools": ["memory_read", "task_router"],
        "write_scope": [],
        "blocked_actions": ["force_push", "live_provider_call", "prod_deploy", "push_main", "delete_without_approval"],
        "acceptance_criteria": ["result_envelope", "done_validation", "audit_log"],
        "human_review_required": True,
        "policy_version": "task-policy-v1",
        "retry_count": 0,
        "result": None,
        "error": None,
        "result_envelope": None,
        "done_validation": None,
    }

result_envelope = {
    "agent_id": "coder",
    "role": "coder",
    "task_id": rehydrate_task_id,
    "status": "completed",
    "summary": rehydrate_summary,
    "artifacts": [{"type": "audit-log", "path": "postgres://audit_log"}],
    "evidence_refs": ["agent-worker:deterministic-completion", "audit_log:task_completed"],
}
done_validation = {
    "implemented": True,
    "tested": True,
    "integrated": True,
    "reported": True,
    "logged": True,
}

with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO projects(id, name, owner_id, metadata)
            VALUES (%s, 'hosted-phase4-session-failure', 'runtime-verifier', %s)
            ON CONFLICT (id) DO NOTHING
            """,
            (project_id, Json({"source": "verify-phase4-session-failure-history-hosted"})),
        )
        cur.execute(
            """
            INSERT INTO agent_sessions(id, project_id, agent_list, metadata)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (id) DO NOTHING
            """,
            (
                rehydrate_session_id,
                project_id,
                ["planner", "coder", "tester", "devops"],
                Json(
                    {
                        "source": "hosted-session-failure-rehydrate-proof",
                        "latest_task_id": rehydrate_task_id,
                        "latest_worker_task_id": rehydrate_task_id,
                        "latest_worker_result": rehydrate_summary,
                    }
                ),
            ),
        )
        cur.execute(
            """
            INSERT INTO agent_sessions(id, project_id, agent_list, metadata)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (id) DO NOTHING
            """,
            (
                abandon_session_id,
                project_id,
                ["planner", "coder", "tester", "devops"],
                Json(
                    {
                        "source": "hosted-session-failure-abandon-proof",
                        "latest_task_id": abandon_task_id,
                    }
                ),
            ),
        )
        cur.execute(
            """
            INSERT INTO audit_log(event_type, session_id, details, severity)
            VALUES ('task_completed', %s, %s, 'info')
            """,
            (
                rehydrate_session_id,
                Json(
                    {
                        "task_id": rehydrate_task_id,
                        "task_type": "hosted_session_failure_rehydrate_regression",
                        "agent_type": "coder",
                        "worker": "agent-worker",
                        "trace_id": "hosted-phase4-session-failure:" + rehydrate_task_id,
                        "llm_calls": 0,
                        "result_envelope": result_envelope,
                        "done_validation": done_validation,
                    }
                ),
            ),
        )
    conn.commit()

client = redis.Redis.from_url(os.environ["REDIS_URL"], decode_responses=True)
client.set(
    "task:status:" + rehydrate_task_id,
    json.dumps(
        task(rehydrate_task_id, rehydrate_session_id, "coder", "hosted_session_failure_rehydrate_regression"),
        separators=(",", ":"),
    ),
    ex=86400,
)
client.set(
    "task:status:" + abandon_task_id,
    json.dumps(
        task(abandon_task_id, abandon_session_id, "tester", "hosted_session_failure_abandon_regression"),
        separators=(",", ":"),
    ),
    ex=86400,
)
print(
    json.dumps(
        {
            "project_id": project_id,
            "rehydrate_session_id": rehydrate_session_id,
            "abandon_session_id": abandon_session_id,
            "rehydrate_task_id": rehydrate_task_id,
            "abandon_task_id": abandon_task_id,
            "rehydrate_summary": rehydrate_summary,
        }
    )
)
'''

run = subprocess.run(
    ["docker", "compose", "--env-file", ".env", "-f", "docker-compose.cloud.yml", "exec", "-T", "agent-api", "python", "-c", seed_code],
    capture_output=True,
    text=True,
)
if run.returncode != 0:
    raise SystemExit(
        json.dumps(
            {
                "seed_failed": True,
                "returncode": run.returncode,
                "stdout": run.stdout,
                "stderr": run.stderr,
            }
        )
    )
print(run.stdout.strip().splitlines()[-1])
"@
  Set-Content -LiteralPath $localPy -Value $script -Encoding UTF8
  try {
    $target = "{0}@{1}:{2}" -f $RemoteUser, $StagingHost, $remotePy
    scp -i $KeyPath -o StrictHostKeyChecking=no $localPy $target | Out-Null
    $output = ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingHost" "cd $RemoteRootPath && python3 $remotePy"
    if ($LASTEXITCODE -ne 0) {
      throw "Phase4 hosted session-failure-history verification failed: remote seed failed. Output: $output"
    }
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
  throw "Phase4 hosted session-failure-history proof requires HTTPS"
}

Write-Host "[phase4-hosted-session-failure-history] base url: $BaseUrl"

$seeded = Invoke-RemoteSeedSessionFailureState

$rehydrated = Wait-TaskStatus $BaseUrl $seeded.rehydrate_task_id "completed"
$abandoned = Wait-TaskStatus $BaseUrl $seeded.abandon_task_id "abandoned_after_queue_drain"

Assert-Contains "rehydrated summary visible in task state" ($rehydrated | ConvertTo-Json -Depth 10 -Compress) $seeded.rehydrate_summary
Assert-Contains "abandoned error visible in task state" ($abandoned | ConvertTo-Json -Depth 10 -Compress) "queued status had no matching queue item"

$rehydrateHistory = Invoke-JsonApi -url "$BaseUrl/api/v1/sessions/$($seeded.rehydrate_session_id)/history" -method "GET" -contentType $null -timeoutSeconds 20
$rehydrateHistoryText = $rehydrateHistory | ConvertTo-Json -Depth 12 -Compress
Assert-True "rehydrate history contract" ($rehydrateHistory.contract_version -eq "session-history-v1")
Assert-True "rehydrate history session id" ($rehydrateHistory.session.session_id -eq $seeded.rehydrate_session_id)
Assert-Contains "rehydrate history task id" $rehydrateHistoryText $seeded.rehydrate_task_id
Assert-Contains "rehydrate history completed status" $rehydrateHistoryText '"status":"completed"'
Assert-Contains "rehydrate history summary" $rehydrateHistoryText $seeded.rehydrate_summary
Assert-Contains "rehydrate audit event" $rehydrateHistoryText "task_status_rehydrated_from_audit"
Assert-Contains "rehydrate audit evidence" $rehydrateHistoryText "worker_status_rehydrated_from_completed_audit"

$abandonHistory = Invoke-JsonApi -url "$BaseUrl/api/v1/sessions/$($seeded.abandon_session_id)/history" -method "GET" -contentType $null -timeoutSeconds 20
$abandonHistoryText = $abandonHistory | ConvertTo-Json -Depth 12 -Compress
Assert-True "abandon history contract" ($abandonHistory.contract_version -eq "session-history-v1")
Assert-True "abandon history session id" ($abandonHistory.session.session_id -eq $seeded.abandon_session_id)
Assert-Contains "abandon history task id" $abandonHistoryText $seeded.abandon_task_id
Assert-Contains "abandon history abandoned status" $abandonHistoryText '"status":"abandoned_after_queue_drain"'
Assert-Contains "abandon audit event" $abandonHistoryText "task_abandoned_after_queue_drain"
Assert-Contains "abandon audit evidence" $abandonHistoryText "worker_stale_queued_finalized"

$recentSessions = Invoke-JsonApi -url "$BaseUrl/api/v1/sessions/recent?limit=20" -method "GET" -contentType $null -timeoutSeconds 20
$recentSessionsText = $recentSessions | ConvertTo-Json -Depth 10 -Compress
Assert-Contains "recent sessions include rehydrate session" $recentSessionsText $seeded.rehydrate_session_id
Assert-Contains "recent sessions include abandon session" $recentSessionsText $seeded.abandon_session_id
Assert-Contains "recent sessions include rehydrate task" $recentSessionsText $seeded.rehydrate_task_id
Assert-Contains "recent sessions include abandon task" $recentSessionsText $seeded.abandon_task_id
Assert-Contains "recent sessions include rehydrate summary" $recentSessionsText $seeded.rehydrate_summary
$rehydrateRecent = @($recentSessions.sessions) | Where-Object { $_.session_id -eq $seeded.rehydrate_session_id } | Select-Object -First 1
$abandonRecent = @($recentSessions.sessions) | Where-Object { $_.session_id -eq $seeded.abandon_session_id } | Select-Object -First 1
Assert-True "recent rehydrate session exists" ($null -ne $rehydrateRecent)
Assert-True "recent abandon session exists" ($null -ne $abandonRecent)
Assert-True "recent rehydrate latest task status completed" ($rehydrateRecent.latest_task_status -eq "completed")
Assert-True "recent abandon latest task status abandoned" ($abandonRecent.latest_task_status -eq "abandoned_after_queue_drain")
Assert-Contains "recent abandon latest error visible" ($abandonRecent | ConvertTo-Json -Depth 8 -Compress) "queued status had no matching queue item"
Assert-True "recent rehydrate retry count zero" ([int]$rehydrateRecent.latest_retry_count -eq 0)
Assert-True "recent abandon retry count zero" ([int]$abandonRecent.latest_retry_count -eq 0)

$audit = Invoke-JsonApi -url "$BaseUrl/api/v1/audit/recent?limit=100" -method "GET" -contentType $null -timeoutSeconds 20
$auditText = $audit | ConvertTo-Json -Depth 12 -Compress
Assert-Contains "audit contains rehydrate session" $auditText $seeded.rehydrate_session_id
Assert-Contains "audit contains abandon session" $auditText $seeded.abandon_session_id
Assert-Contains "audit contains task_status_rehydrated_from_audit" $auditText "task_status_rehydrated_from_audit"
Assert-Contains "audit contains task_abandoned_after_queue_drain" $auditText "task_abandoned_after_queue_drain"

Write-Host "[phase4-hosted-session-failure-history] checks completed"

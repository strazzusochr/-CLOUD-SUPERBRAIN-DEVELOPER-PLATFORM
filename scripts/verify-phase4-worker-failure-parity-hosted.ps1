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
    throw "Phase4 hosted worker-failure verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted worker-failure verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-worker-failure-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted worker-failure verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
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
  throw "Phase4 hosted worker-failure verification failed: task $taskId did not become $expectedStatus. Value: $($last | ConvertTo-Json -Depth 8 -Compress)"
}

function Wait-RecentTaskStatus($baseUrl, $taskId, $expectedStatus, $attempts = 30) {
  $last = $null
  for ($i = 0; $i -lt $attempts; $i++) {
    $last = Invoke-JsonApi -url "$baseUrl/api/v1/tasks/recent?limit=80" -method "GET" -contentType $null -timeoutSeconds 20
    $record = @($last.tasks) | Where-Object { $_.task_id -eq $taskId } | Select-Object -First 1
    if ($null -ne $record -and $record.status -eq $expectedStatus) {
      return $record
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted worker-failure verification failed: recent task $taskId did not become $expectedStatus."
}

function Wait-AuditText($baseUrl, $expected, $attempts = 30) {
  for ($i = 0; $i -lt $attempts; $i++) {
    $audit = Invoke-JsonApi -url "$baseUrl/api/v1/audit/recent?limit=100" -method "GET" -contentType $null -timeoutSeconds 20
    $text = $audit | ConvertTo-Json -Depth 12 -Compress
    if ($text.Contains($expected)) {
      return $text
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted worker-failure verification failed: audit feed did not contain '$expected'."
}

function Wait-EscalationText($baseUrl, $expected, $attempts = 30) {
  for ($i = 0; $i -lt $attempts; $i++) {
    $events = Invoke-JsonApi -url "$baseUrl/api/v1/escalations/recent?limit=40" -method "GET" -contentType $null -timeoutSeconds 20
    $text = $events | ConvertTo-Json -Depth 10 -Compress
    if ($text.Contains($expected)) {
      return $text
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted worker-failure verification failed: escalation feed did not contain '$expected'."
}

function Invoke-RemoteSeedWorkerFailureState() {
  if (-not (Test-Path -LiteralPath $KeyPath)) {
    throw "Phase4 hosted worker-failure verification failed: SSH key path not found: $KeyPath"
  }

  $seedProjectId = [Guid]::NewGuid().ToString()
  $escalateSessionId = [Guid]::NewGuid().ToString()
  $rehydrateSessionId = [Guid]::NewGuid().ToString()
  $abandonSessionId = [Guid]::NewGuid().ToString()
  $escalateTaskId = [Guid]::NewGuid().ToString()
  $rehydrateTaskId = [Guid]::NewGuid().ToString()
  $abandonTaskId = [Guid]::NewGuid().ToString()
  $localPy = Join-Path $env:TEMP ("phase4-worker-failure-seed-" + [Guid]::NewGuid().ToString("N") + ".py")
  $remotePy = "/tmp/phase4_worker_failure_seed.py"
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
escalate_session_id = "$escalateSessionId"
rehydrate_session_id = "$rehydrateSessionId"
abandon_session_id = "$abandonSessionId"
escalate_task_id = "$escalateTaskId"
rehydrate_task_id = "$rehydrateTaskId"
abandon_task_id = "$abandonTaskId"
now = datetime.now(timezone.utc)
old = (now - timedelta(seconds=180)).isoformat()

def task(task_id, session_id, agent_type, task_type, created_at=old, max_retries=1):
    return {
        "project_id": project_id,
        "session_id": session_id,
        "agent_type": agent_type,
        "task_type": task_type,
        "task_description": "hosted phase4 worker failure parity proof for " + task_type,
        "task_id": task_id,
        "status": "queued",
        "created_at": created_at,
        "updated_at": created_at,
        "trace_id": "hosted-phase4-worker-failure:" + task_id,
        "priority": 5,
        "max_retries": max_retries,
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
    "summary": "Hosted worker stale queued rehydrate proof completed from audit.",
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
            VALUES (%s, 'hosted-phase4-worker-failure', 'runtime-verifier', %s)
            ON CONFLICT (id) DO NOTHING
            """,
            (project_id, Json({"source": "verify-phase4-worker-failure-parity-hosted"})),
        )
        for session_id, source in (
            (rehydrate_session_id, "hosted-worker-status-rehydrate-proof"),
            (abandon_session_id, "hosted-worker-status-abandon-proof"),
        ):
            cur.execute(
                """
                INSERT INTO agent_sessions(id, project_id, agent_list, metadata)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (id) DO NOTHING
                """,
                (session_id, project_id, ["planner", "coder", "tester", "devops"], Json({"source": source})),
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
                        "task_type": "hosted_worker_status_rehydrate_regression",
                        "agent_type": "coder",
                        "worker": "agent-worker",
                        "trace_id": "hosted-phase4-worker-failure:" + rehydrate_task_id,
                        "llm_calls": 0,
                        "result_envelope": result_envelope,
                        "done_validation": done_validation,
                    }
                ),
            ),
        )
    conn.commit()

client = redis.Redis.from_url(os.environ["REDIS_URL"], decode_responses=True)
escalate_payload = json.dumps(
    task(
        escalate_task_id,
        escalate_session_id,
        "coder",
        "hosted_worker_failure_escalation_regression",
        datetime.now(timezone.utc).isoformat(),
        1,
    ),
    separators=(",", ":"),
)
client.set("task:status:" + escalate_task_id, escalate_payload, ex=86400)
client.rpush("tasks:agent:queue", escalate_payload)
client.set(
    "task:status:" + rehydrate_task_id,
    json.dumps(
        task(rehydrate_task_id, rehydrate_session_id, "coder", "hosted_worker_status_rehydrate_regression"),
        separators=(",", ":"),
    ),
    ex=86400,
)
client.set(
    "task:status:" + abandon_task_id,
    json.dumps(
        task(abandon_task_id, abandon_session_id, "tester", "hosted_worker_status_abandon_regression"),
        separators=(",", ":"),
    ),
    ex=86400,
)
print(
    json.dumps(
        {
            "project_id": project_id,
            "escalate_session_id": escalate_session_id,
            "rehydrate_session_id": rehydrate_session_id,
            "abandon_session_id": abandon_session_id,
            "escalate_task_id": escalate_taskId if False else escalate_task_id,
            "rehydrate_task_id": rehydrate_task_id,
            "abandon_task_id": abandon_task_id,
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
      throw "Phase4 hosted worker-failure verification failed: remote seed failed. Output: $output"
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
  throw "Phase4 hosted worker-failure proof requires HTTPS"
}

Write-Host "[phase4-hosted-worker-failure] base url: $BaseUrl"

$health = Invoke-JsonApi -url "$BaseUrl/api/v1/health" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "agent worker healthy" ($health.services.agent_worker.status -eq "healthy")
Assert-True "redis healthy" ($health.services.redis.status -eq "healthy")
Assert-True "postgres healthy" ($health.services.postgres.status -eq "healthy")

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/tasks/assignment-contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "task assignment contract version" ($contract.contract_version -eq "task-assignment-queue-contract-v1")
Assert-True "worker stale evidence present" (@($contract.evidence_refs) -contains "worker_stale_queued_finalized")
Assert-True "worker status harness evidence present" (@($contract.evidence_refs) -contains "worker_status_regression_harness")

$seeded = Invoke-RemoteSeedWorkerFailureState

$escalated = Wait-TaskStatus $BaseUrl $seeded.escalate_task_id "escalated"
Assert-Contains "escalated error foreign key" ($escalated | ConvertTo-Json -Depth 10 -Compress) "ForeignKeyViolation"

$rehydrated = Wait-TaskStatus $BaseUrl $seeded.rehydrate_task_id "completed"
Assert-Contains "rehydrated summary" ($rehydrated | ConvertTo-Json -Depth 10 -Compress) "Hosted worker stale queued rehydrate proof completed from audit."
Assert-True "rehydrated done validation logged" ($rehydrated.task.done_validation.logged -eq $true)

$abandoned = Wait-TaskStatus $BaseUrl $seeded.abandon_task_id "abandoned_after_queue_drain"
Assert-Contains "abandoned error" ($abandoned | ConvertTo-Json -Depth 10 -Compress) "queued status had no matching queue item"

$recentEscalated = Wait-RecentTaskStatus $BaseUrl $seeded.escalate_task_id "escalated"
Assert-True "recent escalated retry count" ([int]$recentEscalated.retry_count -eq 1)
$recentRehydrated = Wait-RecentTaskStatus $BaseUrl $seeded.rehydrate_task_id "completed"
$recentAbandoned = Wait-RecentTaskStatus $BaseUrl $seeded.abandon_task_id "abandoned_after_queue_drain"
Assert-True "recent rehydrated logged" ($recentRehydrated.done_validation.logged -eq $true)
Assert-Contains "recent abandoned error" ($recentAbandoned | ConvertTo-Json -Depth 8 -Compress) "queued status had no matching queue item"

$auditText = Wait-AuditText $BaseUrl $seeded.escalate_task_id
Assert-Contains "audit retry event" $auditText "task_retry"
Assert-Contains "audit failure event" $auditText "task_failed"
Assert-Contains "audit escalation event" $auditText "task_escalated"
Assert-Contains "audit rehydrate event" $auditText "task_status_rehydrated_from_audit"
Assert-Contains "audit rehydrate evidence" $auditText "worker_status_rehydrated_from_completed_audit"
Assert-Contains "audit abandoned event" $auditText "task_abandoned_after_queue_drain"
Assert-Contains "audit abandoned evidence" $auditText "worker_stale_queued_finalized"
Assert-Contains "audit rehydrate task id" $auditText $seeded.rehydrate_task_id
Assert-Contains "audit abandoned task id" $auditText $seeded.abandon_task_id

$escalationText = Wait-EscalationText $BaseUrl $seeded.escalate_task_id
Assert-Contains "escalation status" $escalationText '"status":"escalated"'
Assert-Contains "escalation event type" $escalationText "task_escalated"

$metrics = Invoke-WebResponse -url "$BaseUrl/api/v1/metrics" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "metrics http 200" ($metrics.StatusCode -eq 200)
Assert-Contains "metrics queue depth gauge" $metrics.Content "superbrain_task_queue_depth"
Assert-Contains "metrics escalated total" $metrics.Content 'superbrain_recent_tasks_total{status="escalated"}'
Assert-Contains "metrics abandoned total" $metrics.Content 'superbrain_recent_tasks_total{status="abandoned_after_queue_drain"}'

Write-Host "[phase4-hosted-worker-failure] checks completed"

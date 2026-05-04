param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Worker status regression verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Worker status regression verification failed: $label"
  }
}

function Invoke-Text($url) {
  return curl.exe -sS $url
}

function Invoke-AgentApiPython($code) {
  $output = $code | docker exec -i cloud-superbrain-phase1-dev-agent-api-1 python -
  if ($LASTEXITCODE -ne 0) {
    throw "Worker status regression verification failed: agent-api python command failed"
  }
  return $output
}

function Wait-TaskStatus($taskId, $expectedStatus, $attempts = 30) {
  $last = ""
  for ($i = 0; $i -lt $attempts; $i++) {
    $last = docker exec cloud-superbrain-phase1-dev-agent-api-1 python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/internal/tasks/$taskId', timeout=5).read().decode())"
    if (($last | Out-String).Contains("`"status`":`"$expectedStatus`"")) {
      return $last
    }
    Start-Sleep -Seconds 1
  }
  throw "Worker status regression verification failed: task $taskId did not become $expectedStatus. Value: $last"
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ((-not $AllowLocalhost) -and ($BaseUrl -match "localhost|127\.0\.0\.1|\[::1\]")) {
  throw "Worker status regression proof refuses localhost unless -AllowLocalhost is set"
}

Write-Host "[worker-status] base url: $BaseUrl"

Write-Host "[worker-status] health"
$health = Invoke-Text "$BaseUrl/api/v1/health"
Assert-Contains "agent-api health" $health '"status":"healthy"'
Assert-Contains "agent worker healthy" $health '"agent_worker":{"status":"healthy"'
Assert-Contains "redis healthy" $health '"redis":{"status":"healthy"'
Assert-Contains "postgres healthy" $health '"postgres":{"status":"healthy"'

Write-Host "[worker-status] seed stale queued regression records"
$seedCode = @'
import json
import os
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import psycopg
from psycopg.types.json import Json
import redis

project_id = str(uuid4())
abandon_session_id = str(uuid4())
rehydrate_session_id = str(uuid4())
fresh_session_id = str(uuid4())
queued_session_id = str(uuid4())
malformed_session_id = str(uuid4())
abandon_task_id = str(uuid4())
rehydrate_task_id = str(uuid4())
fresh_task_id = str(uuid4())
queued_task_id = str(uuid4())
malformed_task_id = str(uuid4())
now = datetime.now(timezone.utc)
old = (now - timedelta(seconds=120)).isoformat()
fresh = now.isoformat()

def task(task_id, session_id, agent_type, task_type, created_at=old):
    return {
        "project_id": project_id,
        "session_id": session_id,
        "agent_type": agent_type,
        "task_type": task_type,
        "task_description": f"worker status regression proof for {task_type}",
        "task_id": task_id,
        "status": "queued",
        "created_at": created_at,
        "updated_at": created_at,
        "trace_id": f"worker-status-regression:{task_id}",
        "priority": 5,
        "max_retries": 5,
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
    "summary": "Worker status regression rehydrate proof completed from audit.",
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
            VALUES (%s, 'worker-status-regression', 'runtime-verifier', %s)
            ON CONFLICT (id) DO NOTHING
            """,
            (project_id, Json({"source": "verify-worker-status-regression"})),
        )
        for session_id, source in (
            (abandon_session_id, "worker-status-abandon-proof"),
            (rehydrate_session_id, "worker-status-rehydrate-proof"),
            (fresh_session_id, "worker-status-fresh-proof"),
            (queued_session_id, "worker-status-queued-proof"),
            (malformed_session_id, "worker-status-malformed-proof"),
        ):
            cur.execute(
                """
                INSERT INTO agent_sessions(id, project_id, agent_list, metadata)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (id) DO NOTHING
                """,
                (session_id, project_id, ["planner", "coder", "tester", "devops"], Json({"source": source})),
            )
        for session_id, task_id, details in (
            (
                rehydrate_session_id,
                rehydrate_task_id,
                {
                    "task_id": rehydrate_task_id,
                    "task_type": "worker_status_rehydrate_regression",
                    "agent_type": "coder",
                    "worker": "agent-worker",
                    "trace_id": f"worker-status-regression:{rehydrate_task_id}",
                    "llm_calls": 0,
                    "result_envelope": result_envelope,
                    "done_validation": done_validation,
                },
            ),
            (
                malformed_session_id,
                malformed_task_id,
                {
                    "task_id": malformed_task_id,
                    "task_type": "worker_status_malformed_audit_regression",
                    "agent_type": "planner",
                    "worker": "agent-worker",
                    "trace_id": f"worker-status-regression:{malformed_task_id}",
                    "llm_calls": 0,
                    "result_envelope": "malformed",
                    "done_validation": True,
                },
            ),
        ):
            cur.execute(
            """
            INSERT INTO audit_log(event_type, session_id, details, severity)
            VALUES ('task_completed', %s, %s, 'info')
            """,
            (
                session_id,
                Json(details),
            ),
        )
    conn.commit()

client = redis.Redis.from_url(os.environ["REDIS_URL"], decode_responses=True)
client.set(f"task:status:{abandon_task_id}", json.dumps(task(abandon_task_id, abandon_session_id, "tester", "worker_status_abandon_regression"), separators=(",", ":")), ex=3600)
client.set(f"task:status:{rehydrate_task_id}", json.dumps(task(rehydrate_task_id, rehydrate_session_id, "coder", "worker_status_rehydrate_regression"), separators=(",", ":")), ex=3600)
client.set(f"task:status:{fresh_task_id}", json.dumps(task(fresh_task_id, fresh_session_id, "devops", "worker_status_fresh_regression", fresh), separators=(",", ":")), ex=3600)
queued_payload = json.dumps(task(queued_task_id, queued_session_id, "planner", "worker_status_queued_regression"), separators=(",", ":"))
client.set(f"task:status:{queued_task_id}", queued_payload, ex=3600)
client.rpush("tasks:agent:queue", queued_payload)
client.set(f"task:status:{malformed_task_id}", json.dumps(task(malformed_task_id, malformed_session_id, "planner", "worker_status_malformed_audit_regression"), separators=(",", ":")), ex=3600)
print(json.dumps({
    "project_id": project_id,
    "abandon_session_id": abandon_session_id,
    "rehydrate_session_id": rehydrate_session_id,
    "fresh_session_id": fresh_session_id,
    "queued_session_id": queued_session_id,
    "malformed_session_id": malformed_session_id,
    "abandon_task_id": abandon_task_id,
    "rehydrate_task_id": rehydrate_task_id,
    "fresh_task_id": fresh_task_id,
    "queued_task_id": queued_task_id,
    "malformed_task_id": malformed_task_id,
}))
'@
$seed = Invoke-AgentApiPython $seedCode | ConvertFrom-Json

Write-Host "[worker-status] wait for abandoned stale queued status"
$abandonedStatus = Wait-TaskStatus $seed.abandon_task_id "abandoned_after_queue_drain"
Assert-Contains "abandoned error" $abandonedStatus "queued status had no matching queue item"

Write-Host "[worker-status] wait for completed audit rehydrate status"
$rehydratedStatus = Wait-TaskStatus $seed.rehydrate_task_id "completed"
Assert-Contains "rehydrated result envelope" $rehydratedStatus "Worker status regression rehydrate proof completed from audit"
Assert-Contains "rehydrated done validation" $rehydratedStatus '"logged":true'

Write-Host "[worker-status] wait for malformed completion audit to abandon"
$malformedStatus = Wait-TaskStatus $seed.malformed_task_id "abandoned_after_queue_drain"
Assert-Contains "malformed audit did not rehydrate" $malformedStatus "queued status had no matching queue item"

Write-Host "[worker-status] fresh queued status remains queued"
$freshStatus = docker exec cloud-superbrain-phase1-dev-agent-api-1 python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/internal/tasks/$($seed.fresh_task_id)', timeout=5).read().decode())"
Assert-Contains "fresh queued untouched" $freshStatus '"status":"queued"'

Write-Host "[worker-status] queued list item is processed rather than abandoned"
$queuedStatus = Wait-TaskStatus $seed.queued_task_id "completed"
Assert-Contains "queued task completed" $queuedStatus "agent-worker:deterministic-completion"

Write-Host "[worker-status] audit proof"
$auditCode = @"
import json
import os

import psycopg

abandon_session_id = "$($seed.abandon_session_id)"
rehydrate_session_id = "$($seed.rehydrate_session_id)"
malformed_session_id = "$($seed.malformed_session_id)"
abandon_task_id = "$($seed.abandon_task_id)"
rehydrate_task_id = "$($seed.rehydrate_task_id)"
malformed_task_id = "$($seed.malformed_task_id)"

with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
    rows = conn.execute(
        """
        SELECT event_type, severity, details->>'task_type' AS task_type, details->>'status' AS status, details->>'evidence_ref' AS evidence_ref, COUNT(*)
        FROM audit_log
        WHERE (session_id = %s AND details->>'task_id' = %s)
           OR (session_id = %s AND details->>'task_id' = %s)
           OR (session_id = %s AND details->>'task_id' = %s)
        GROUP BY event_type, severity, task_type, status, evidence_ref
        ORDER BY event_type, severity
        """,
        (abandon_session_id, abandon_task_id, rehydrate_session_id, rehydrate_task_id, malformed_session_id, malformed_task_id),
    ).fetchall()
print(json.dumps([
    {
        "event_type": row[0],
        "severity": row[1],
        "task_type": row[2],
        "status": row[3],
        "evidence_ref": row[4],
        "count": row[5],
    }
    for row in rows
]))
"@
$auditProof = Invoke-AgentApiPython $auditCode
Assert-Contains "abandoned audit event" $auditProof "task_abandoned_after_queue_drain"
Assert-Contains "abandoned audit evidence" $auditProof "worker_stale_queued_finalized"
Assert-Contains "rehydrate audit event" $auditProof "task_status_rehydrated_from_audit"
Assert-Contains "rehydrate audit evidence" $auditProof "worker_status_rehydrated_from_completed_audit"
Assert-Contains "malformed audit abandoned" $auditProof "worker_status_malformed_audit_regression"

Write-Host "[worker-status] queue depth"
$queueDepth = Invoke-AgentApiPython "import os, redis; print(redis.Redis.from_url(os.environ['REDIS_URL']).llen('tasks:agent:queue'))"
Assert-Contains "queue depth drained" $queueDepth "0"

Write-Host "[worker-status] direct dry-run parity"
$directSessionId = [Guid]::NewGuid().ToString()
$directBody = @{
  project_id = "worker-status-regression-project"
  prompt = "worker status regression direct dry-run parity proof"
  session_id = $directSessionId
} | ConvertTo-Json -Compress
$directRun = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/v1/orchestrator/dry-run" -ContentType "application/json" -Body $directBody
Assert-True "direct graph completed" ($directRun.state.node_name -eq "completed")
Assert-True "direct partial failure false" ($directRun.state.result.partial_failure -eq $false)
Assert-True "direct aggregation complete" ($directRun.state.result.verification_evidence -contains "agent_result_aggregation_complete")
$expectedRoles = @("planner", "coder", "tester", "devops")
foreach ($role in $expectedRoles) {
  $roleSummary = @($directRun.state.result.per_role_results) | Where-Object { $_.role -eq $role } | Select-Object -First 1
  Assert-True "direct per-role summary for $role" ($null -ne $roleSummary)
  Assert-True "direct per-role completed for $role" ($roleSummary.status -eq "completed")
}

Write-Host "[worker-status] stream dry-run parity"
$streamSessionId = [Guid]::NewGuid().ToString()
$streamTimeoutSeconds = 90
$streamBody = @{
  project_id = "worker-status-regression-project"
  prompt = "worker status regression stream dry-run parity proof"
  session_id = $streamSessionId
} | ConvertTo-Json -Compress
$streamBodyFile = Join-Path $env:TEMP ("worker-status-stream-" + [Guid]::NewGuid().ToString("N") + ".json")
try {
  Set-Content -LiteralPath $streamBodyFile -Value $streamBody -NoNewline -Encoding utf8
  $streamRun = curl.exe -sN --max-time $streamTimeoutSeconds -X POST -H "Content-Type: application/json" --data-binary "@$streamBodyFile" "$BaseUrl/api/v1/orchestrator/dry-run/stream"
} finally {
  if (Test-Path $streamBodyFile) { Remove-Item -LiteralPath $streamBodyFile -Force }
}
Assert-Contains "stream done event" $streamRun "event: done"
Assert-Contains "stream graph completed" $streamRun '"status":"completed"'
Assert-Contains "stream node completed" $streamRun '"node_name":"completed"'
Assert-Contains "stream partial false" $streamRun '"partial_failure":false'
Assert-Contains "stream aggregation complete" $streamRun "agent_result_aggregation_complete"
foreach ($role in $expectedRoles) {
  Assert-Contains "stream per-role $role" $streamRun "`"role`":`"$role`""
}

Write-Host "[worker-status] stream audit proof"
$streamAudit = Invoke-Text "$BaseUrl/api/v1/audit/recent?limit=80"
Assert-Contains "stream audit completed" $streamAudit "langgraph_dry_run_completed"
Assert-Contains "stream audit session" $streamAudit $streamSessionId
Assert-Contains "stream audit aggregation" $streamAudit "agent_result_aggregation_complete"

Write-Host "[worker-status] regression checks completed"

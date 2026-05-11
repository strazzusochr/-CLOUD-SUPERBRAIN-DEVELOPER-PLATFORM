param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [string]$KeyPath = "C:\Users\immer\.ssh\oracle_key",
  [string]$StagingHost = "188.34.191.140",
  [string]$RemoteUser = "root",
  [string]$RemoteRootPath = "/app"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted failure-audit-escalation verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-failure-audit-escalation-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted failure-audit-escalation verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

function Invoke-RemoteSeedFailureAuditEscalation() {
  $traceId = [Guid]::NewGuid().ToString()
  $projectId = [Guid]::NewGuid().ToString()
  $coderSessionId = [Guid]::NewGuid().ToString()
  $testerSessionId = [Guid]::NewGuid().ToString()
  $coderTaskId = [Guid]::NewGuid().ToString()
  $testerTaskId = [Guid]::NewGuid().ToString()
  $localPy = Join-Path $env:TEMP ("phase4-failure-audit-escalation-seed-" + [Guid]::NewGuid().ToString("N") + ".py")
  $remotePy = "/tmp/phase4_failure_audit_escalation_seed.py"
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
        "task_description": "hosted failure audit parity proof for " + task_type,
        "task_id": task_id,
        "status": status,
        "created_at": old,
        "updated_at": old,
        "trace_id": trace_id,
        "priority": 5,
        "max_retries": max_retries,
        "allowed_tools": ["audit_recent"],
        "write_scope": [],
        "blocked_actions": ["force_push", "live_provider_call", "prod_deploy", "push_main", "delete_without_approval"],
        "acceptance_criteria": ["audit parity visible"],
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
            VALUES (%s, 'hosted-phase4-failure-audit-escalation', 'runtime-verifier', %s)
            ON CONFLICT (id) DO NOTHING
            """,
            (project_id, Json({"source": "verify-phase4-failure-audit-escalation-parity-hosted"})),
        )
        cur.execute(
            """
            INSERT INTO agent_sessions(id, project_id, agent_list, metadata)
            VALUES (%s, %s, %s, %s), (%s, %s, %s, %s)
            ON CONFLICT (id) DO UPDATE
            SET metadata = agent_sessions.metadata || EXCLUDED.metadata
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
                    "error": "foreign_key_violation_failure_audit_escalated",
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
                    "error": "stale queued task abandoned after bounded rescue failure audit",
                }),
                now,
            ),
        )

client = redis.Redis.from_url(os.environ["REDIS_URL"], decode_responses=True)
client.set("task:status:" + coder_task_id, json.dumps(task(coder_task_id, coder_session_id, "coder", "escalated", 1, 1, "foreign_key_violation_failure_audit_escalated", "hosted_failure_audit_coder"), separators=(",", ":")), ex=86400)
client.set("task:status:" + tester_task_id, json.dumps(task(tester_task_id, tester_session_id, "tester", "abandoned_after_queue_drain", 0, 1, "stale queued task abandoned after bounded rescue failure audit", "hosted_failure_audit_tester"), separators=(",", ":")), ex=86400)

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
    if ($LASTEXITCODE -ne 0) { throw "Phase4 hosted failure-audit-escalation verification failed: could not copy seed script" }
    $raw = ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingHost" "python3 $remotePy"
    if ($LASTEXITCODE -ne 0) { throw "Phase4 hosted failure-audit-escalation verification failed: remote seed execution failed" }
    $jsonLine = @($raw -split "`r?`n" | Where-Object { $_.Trim() }) | Select-Object -Last 1
    return ($jsonLine | ConvertFrom-Json)
  } finally {
    if (Test-Path -LiteralPath $localPy) { Remove-Item -LiteralPath $localPy -Force }
    ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingHost" "rm -f $remotePy" | Out-Null
  }
}

function Wait-AuditParity($baseUrl, $seed, $attempts = 20) {
  for ($i = 0; $i -lt $attempts; $i++) {
    $audit = Invoke-JsonApi -url "$baseUrl/api/v1/audit/recent?limit=50" -method "GET" -contentType $null -timeoutSeconds 20
    $escalations = Invoke-JsonApi -url "$baseUrl/api/v1/escalations/recent?limit=50" -method "GET" -contentType $null -timeoutSeconds 20
    $coderAudit = @($audit.events) | Where-Object { $_.details.task_id -eq $seed.coder_task_id -and $_.event_type -eq "task_escalated" } | Select-Object -First 1
    $testerAudit = @($audit.events) | Where-Object { $_.details.task_id -eq $seed.tester_task_id -and $_.event_type -eq "task_abandoned_after_queue_drain" } | Select-Object -First 1
    $coderEscalation = @($escalations.events) | Where-Object { $_.details.task_id -eq $seed.coder_task_id } | Select-Object -First 1
    if ($null -ne $coderAudit -and $null -ne $testerAudit -and $null -ne $coderEscalation) {
      return [pscustomobject]@{
        audit = $audit
        escalations = $escalations
        coderAudit = $coderAudit
        testerAudit = $testerAudit
        coderEscalation = $coderEscalation
      }
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted failure-audit-escalation verification failed: audit/escalation entries did not appear for the seeded tasks"
}

$seed = Invoke-RemoteSeedFailureAuditEscalation
$auditBundle = Wait-AuditParity -baseUrl $BaseUrl -seed $seed
$coderHistory = Invoke-JsonApi -url "$BaseUrl/api/v1/sessions/$($seed.coder_session_id)/history" -method "GET" -contentType $null -timeoutSeconds 20
$testerHistory = Invoke-JsonApi -url "$BaseUrl/api/v1/sessions/$($seed.tester_session_id)/history" -method "GET" -contentType $null -timeoutSeconds 20
$coderHistoryAudit = @($coderHistory.audit_events) | Where-Object { $_.details.task_id -eq $seed.coder_task_id -and $_.event_type -eq "task_escalated" } | Select-Object -First 1
$testerHistoryAudit = @($testerHistory.audit_events) | Where-Object { $_.details.task_id -eq $seed.tester_task_id -and $_.event_type -eq "task_abandoned_after_queue_drain" } | Select-Object -First 1

Assert-True "coder audit visible in history" ($null -ne $coderHistoryAudit)
Assert-True "tester audit visible in history" ($null -ne $testerHistoryAudit)
Assert-True "coder trace parity" ($auditBundle.coderAudit.trace_id -eq $seed.trace_id -and $coderHistoryAudit.trace_id -eq $seed.trace_id -and $auditBundle.coderEscalation.details.trace_id -eq $seed.trace_id)
Assert-True "tester trace parity" ($auditBundle.testerAudit.trace_id -eq $seed.trace_id -and $testerHistoryAudit.trace_id -eq $seed.trace_id)
Assert-True "coder retry parity" ([int]$auditBundle.coderAudit.details.retry_count -eq [int]$auditBundle.coderEscalation.details.retry_count)
Assert-True "tester retry parity" ([int]$auditBundle.testerAudit.details.retry_count -eq [int]$testerHistoryAudit.details.retry_count)
Assert-True "coder max retry parity" ([int]$auditBundle.coderAudit.details.max_retries -eq [int]$auditBundle.coderEscalation.details.max_retries)
Assert-True "tester max retry parity" ([int]$auditBundle.testerAudit.details.max_retries -eq [int]$testerHistoryAudit.details.max_retries)
Assert-True "coder severity parity" ($auditBundle.coderAudit.severity -eq "warning" -and $auditBundle.coderEscalation.severity -eq "warning" -and $coderHistoryAudit.severity -eq "warning")
Assert-True "tester severity parity" ($auditBundle.testerAudit.severity -eq "warning" -and $testerHistoryAudit.severity -eq "warning")
Assert-True "coder error parity" (($auditBundle.coderAudit.details.error | Out-String).Contains("foreign_key_violation_failure_audit_escalated") -and ($coderHistoryAudit.details.error | Out-String).Contains("foreign_key_violation_failure_audit_escalated"))
Assert-True "tester error parity" (($auditBundle.testerAudit.details.error | Out-String).Contains("stale queued task abandoned after bounded rescue failure audit") -and ($testerHistoryAudit.details.error | Out-String).Contains("stale queued task abandoned after bounded rescue failure audit"))

Write-Host "[phase4-hosted-failure-audit-escalation] checks completed"

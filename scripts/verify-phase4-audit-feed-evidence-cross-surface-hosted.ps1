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
    throw "Phase4 hosted audit-feed-evidence cross-surface verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-audit-feed-evidence-cross-surface-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted audit-feed-evidence cross-surface verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

function Invoke-RemoteSeedAuditFeedEvidence() {
  $traceId = [Guid]::NewGuid().ToString()
  $requestId = "req-" + [Guid]::NewGuid().ToString("N")
  $projectId = [Guid]::NewGuid().ToString()
  $coderSessionId = [Guid]::NewGuid().ToString()
  $coderTaskId = [Guid]::NewGuid().ToString()
  $localPy = Join-Path $env:TEMP ("phase4-audit-feed-evidence-seed-" + [Guid]::NewGuid().ToString("N") + ".py")
  $remotePy = "/tmp/phase4_audit_feed_evidence_seed.py"
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
request_id = "$requestId"
correlation_evidence_ref = "request_id_audit_correlation"
audit_feed_evidence_ref = "request_id_audit_feed_visible"
coder_session_id = "$coderSessionId"
coder_task_id = "$coderTaskId"
now = datetime.now(timezone.utc)
old = (now - timedelta(seconds=180)).isoformat()

task = {
    "project_id": project_id,
    "session_id": coder_session_id,
    "agent_type": "coder",
    "task_type": "hosted_audit_feed_evidence_coder",
    "task_description": "hosted audit feed evidence cross-surface proof",
    "task_id": coder_task_id,
    "status": "escalated",
    "created_at": old,
    "updated_at": old,
    "trace_id": trace_id,
    "priority": 5,
    "max_retries": 1,
    "allowed_tools": ["memory_read", "task_router"],
    "write_scope": [],
    "blocked_actions": ["force_push", "live_provider_call", "prod_deploy", "push_main", "delete_without_approval"],
    "acceptance_criteria": ["result_envelope", "done_validation", "audit_log"],
    "human_review_required": True,
    "policy_version": "task-policy-v1",
    "retry_count": 1,
    "result": None,
    "error": "foreign_key_violation_audit_feed_evidence_cross_surface",
    "result_envelope": None,
    "done_validation": None,
}

details = {
    "trace_id": trace_id,
    "request_id": request_id,
    "correlation_evidence_ref": correlation_evidence_ref,
    "audit_feed_evidence_ref": audit_feed_evidence_ref,
    "task_id": coder_task_id,
    "agent_type": "coder",
    "status": "escalated",
    "retry_count": 1,
    "max_retries": 1,
    "error": "foreign_key_violation_audit_feed_evidence_cross_surface",
}

with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO projects(id, name, owner_id, metadata)
            VALUES (%s, 'hosted-phase4-audit-feed-evidence', 'runtime-verifier', %s)
            ON CONFLICT (id) DO NOTHING
            """,
            (project_id, Json({"source": "verify-phase4-audit-feed-evidence-cross-surface-hosted"})),
        )
        cur.execute(
            """
            INSERT INTO agent_sessions(id, project_id, agent_list, metadata)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (id) DO UPDATE
            SET metadata = agent_sessions.metadata || EXCLUDED.metadata
            """,
            (
                coder_session_id,
                project_id,
                ["planner", "coder", "tester", "devops"],
                Json({
                    "trace_id": trace_id,
                    "request_id": request_id,
                    "correlation_evidence_ref": correlation_evidence_ref,
                    "audit_feed_evidence_ref": audit_feed_evidence_ref,
                    "latest_task_id": coder_task_id
                }),
            ),
        )
        cur.execute(
            """
            INSERT INTO audit_log(event_type, user_id, session_id, details, severity, created_at)
            VALUES ('task_escalated', 'coder', %s, %s, 'warning', %s)
            """,
            (
                coder_session_id,
                Json(details),
                now,
            ),
        )

client = redis.Redis.from_url(os.environ["REDIS_URL"], decode_responses=True)
client.set("task:status:" + coder_task_id, json.dumps(task, separators=(",", ":")), ex=86400)

print(json.dumps({
    "trace_id": trace_id,
    "request_id": request_id,
    "correlation_evidence_ref": correlation_evidence_ref,
    "audit_feed_evidence_ref": audit_feed_evidence_ref,
    "coder_session_id": coder_session_id,
    "coder_task_id": coder_task_id,
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
    "request_id": "$requestId",
    "correlation_evidence_ref": "request_id_audit_correlation",
    "audit_feed_evidence_ref": "request_id_audit_feed_visible",
    "coder_session_id": "$coderSessionId",
    "coder_task_id": "$coderTaskId",
}))
"@
  Set-Content -LiteralPath $localPy -Value $script
  try {
    scp -i $KeyPath -o StrictHostKeyChecking=no $localPy "${RemoteUser}@${StagingHost}:$remotePy" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Phase4 hosted audit-feed-evidence cross-surface verification failed: could not copy seed script" }
    $raw = ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingHost" "python3 $remotePy"
    if ($LASTEXITCODE -ne 0) { throw "Phase4 hosted audit-feed-evidence cross-surface verification failed: remote seed execution failed" }
    $jsonLine = @($raw -split "`r?`n" | Where-Object { $_.Trim() }) | Select-Object -Last 1
    return ($jsonLine | ConvertFrom-Json)
  } finally {
    if (Test-Path -LiteralPath $localPy) { Remove-Item -LiteralPath $localPy -Force }
    ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingHost" "rm -f $remotePy" | Out-Null
  }
}

function Wait-SurfaceEvidence($baseUrl, $seed, $attempts = 20) {
  $last = $null
  for ($i = 0; $i -lt $attempts; $i++) {
    $last = Invoke-JsonApi -url "$baseUrl/api/v1/escalations/recent?limit=50" -method "GET" -contentType $null -timeoutSeconds 20
    $coder = @($last.events) | Where-Object { $_.details.task_id -eq $seed.coder_task_id } | Select-Object -First 1
    if ($null -ne $coder -and $coder.audit_feed_evidence_ref -eq $seed.audit_feed_evidence_ref) {
      return $last
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted audit-feed-evidence cross-surface verification failed: escalations/recent did not expose the seeded audit-feed evidence"
}

$seed = Invoke-RemoteSeedAuditFeedEvidence
$escalations = Wait-SurfaceEvidence -baseUrl $BaseUrl -seed $seed
$agentsStatus = Invoke-JsonApi -url "$BaseUrl/api/v1/agents/status" -method "GET" -contentType $null -timeoutSeconds 20
$tasksRecent = Invoke-JsonApi -url "$BaseUrl/api/v1/tasks/recent?limit=100" -method "GET" -contentType $null -timeoutSeconds 20
$sessionsRecent = Invoke-JsonApi -url "$BaseUrl/api/v1/sessions/recent?limit=50" -method "GET" -contentType $null -timeoutSeconds 20
$coderHistory = Invoke-JsonApi -url "$BaseUrl/api/v1/sessions/$($seed.coder_session_id)/history" -method "GET" -contentType $null -timeoutSeconds 20
$auditRecent = Invoke-JsonApi -url "$BaseUrl/api/v1/audit/recent?limit=100" -method "GET" -contentType $null -timeoutSeconds 20
$agentActivity = Invoke-JsonApi -url "$BaseUrl/api/v1/agent-activity/recent?trace_id=$($seed.trace_id)&limit=50" -method "GET" -contentType $null -timeoutSeconds 20

$coderEscalation = @($escalations.events) | Where-Object { $_.details.task_id -eq $seed.coder_task_id } | Select-Object -First 1
$coderAgentStatus = @($agentsStatus.agents) | Where-Object { $_.latest_task_id -eq $seed.coder_task_id } | Select-Object -First 1
$coderTask = @($tasksRecent.tasks) | Where-Object { $_.task_id -eq $seed.coder_task_id } | Select-Object -First 1
$coderSession = @($sessionsRecent.sessions) | Where-Object { $_.session_id -eq $seed.coder_session_id } | Select-Object -First 1
$coderHistoryTask = @($coderHistory.tasks) | Where-Object { $_.task_id -eq $seed.coder_task_id } | Select-Object -First 1
$coderAudit = @($auditRecent.events) | Where-Object { $_.details.task_id -eq $seed.coder_task_id } | Select-Object -First 1
$coderActivity = @($agentActivity.events) | Where-Object { $_.task_id -eq $seed.coder_task_id } | Select-Object -First 1

$surfaces = @(
  @{ name = "coder escalation"; item = $coderEscalation; request = "request_id"; trace = "trace_id"; corr = "correlation_evidence_ref"; audit = "audit_feed_evidence_ref" },
  @{ name = "coder agent status"; item = $coderAgentStatus; request = "latest_request_id"; trace = "latest_trace_id"; corr = "latest_correlation_evidence_ref"; audit = "latest_audit_feed_evidence_ref" },
  @{ name = "coder task"; item = $coderTask; request = "request_id"; trace = "trace_id"; corr = "correlation_evidence_ref"; audit = "audit_feed_evidence_ref" },
  @{ name = "coder session"; item = $coderSession; request = "request_id"; trace = "trace_id"; corr = "correlation_evidence_ref"; audit = "audit_feed_evidence_ref" },
  @{ name = "coder history task"; item = $coderHistoryTask; request = "request_id"; trace = "trace_id"; corr = "correlation_evidence_ref"; audit = "audit_feed_evidence_ref" },
  @{ name = "coder audit"; item = $coderAudit; request = "request_id"; trace = "trace_id"; corr = "correlation_evidence_ref"; audit = "audit_feed_evidence_ref" },
  @{ name = "coder activity"; item = $coderActivity; request = "request_id"; trace = "trace_id"; corr = "correlation_evidence_ref"; audit = "audit_feed_evidence_ref" }
)

foreach ($surface in $surfaces) {
  Assert-True "$($surface.name) visible" ($null -ne $surface.item)
  Assert-True "$($surface.name) request parity" ($surface.item.($surface.request) -eq $seed.request_id)
  Assert-True "$($surface.name) trace parity" ($surface.item.($surface.trace) -eq $seed.trace_id)
  Assert-True "$($surface.name) correlation parity" ($surface.item.($surface.corr) -eq $seed.correlation_evidence_ref)
  Assert-True "$($surface.name) audit evidence parity" ($surface.item.($surface.audit) -eq $seed.audit_feed_evidence_ref)
}

Write-Host "[phase4-audit-feed-evidence-cross-surface] base_url=$BaseUrl"
Write-Host "[phase4-audit-feed-evidence-cross-surface] trace_id=$($seed.trace_id)"
Write-Host "[phase4-audit-feed-evidence-cross-surface] request_id=$($seed.request_id)"
Write-Host "[phase4-audit-feed-evidence-cross-surface] coder_task_id=$($seed.coder_task_id)"
Write-Host "[phase4-audit-feed-evidence-cross-surface] result=verified"

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
    throw "Phase4 hosted escalation-request-correlation verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-escalation-request-correlation-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted escalation-request-correlation verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

function Invoke-RemoteSeedEscalationRequestCorrelation() {
  $traceId = [Guid]::NewGuid().ToString()
  $requestId = "req-" + [Guid]::NewGuid().ToString("N")
  $projectId = [Guid]::NewGuid().ToString()
  $coderSessionId = [Guid]::NewGuid().ToString()
  $coderTaskId = [Guid]::NewGuid().ToString()
  $localPy = Join-Path $env:TEMP ("phase4-escalation-request-correlation-seed-" + [Guid]::NewGuid().ToString("N") + ".py")
  $remotePy = "/tmp/phase4_escalation_request_correlation_seed.py"
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
coder_session_id = "$coderSessionId"
coder_task_id = "$coderTaskId"
now = datetime.now(timezone.utc)
old = (now - timedelta(seconds=180)).isoformat()

task = {
    "project_id": project_id,
    "session_id": coder_session_id,
    "agent_type": "coder",
    "task_type": "hosted_escalation_request_correlation_coder",
    "task_description": "hosted escalation request correlation proof",
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
    "error": "foreign_key_violation_escalation_request_correlation",
    "result_envelope": None,
    "done_validation": None,
}

with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO projects(id, name, owner_id, metadata)
            VALUES (%s, 'hosted-phase4-escalation-request-correlation', 'runtime-verifier', %s)
            ON CONFLICT (id) DO NOTHING
            """,
            (project_id, Json({"source": "verify-phase4-escalation-request-correlation-hosted"})),
        )
        cur.execute(
            """
            INSERT INTO agent_sessions(id, project_id, agent_list, metadata)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (id) DO UPDATE
            SET metadata = agent_sessions.metadata || EXCLUDED.metadata
            """,
            (
                coder_session_id, project_id, ["planner", "coder", "tester", "devops"], Json({"trace_id": trace_id, "request_id": request_id, "latest_task_id": coder_task_id}),
            ),
        )
        cur.execute(
            """
            INSERT INTO audit_log(event_type, session_id, details, severity, created_at)
            VALUES ('task_escalated', %s, %s, 'warning', %s)
            """,
            (
                coder_session_id,
                Json({
                    "trace_id": trace_id,
                    "request_id": request_id,
                    "correlation_evidence_ref": correlation_evidence_ref,
                    "task_id": coder_task_id,
                    "agent_type": "coder",
                    "status": "escalated",
                    "retry_count": 1,
                    "max_retries": 1,
                    "error": "foreign_key_violation_escalation_request_correlation",
                }),
                now,
            ),
        )

client = redis.Redis.from_url(os.environ["REDIS_URL"], decode_responses=True)
client.set("task:status:" + coder_task_id, json.dumps(task, separators=(",", ":")), ex=86400)

print(json.dumps({
    "trace_id": trace_id,
    "request_id": request_id,
    "correlation_evidence_ref": correlation_evidence_ref,
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
    "coder_session_id": "$coderSessionId",
    "coder_task_id": "$coderTaskId",
}))
"@
  Set-Content -LiteralPath $localPy -Value $script
  try {
    scp -i $KeyPath -o StrictHostKeyChecking=no $localPy "${RemoteUser}@${StagingHost}:$remotePy" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Phase4 hosted escalation-request-correlation verification failed: could not copy seed script" }
    $raw = ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingHost" "python3 $remotePy"
    if ($LASTEXITCODE -ne 0) { throw "Phase4 hosted escalation-request-correlation verification failed: remote seed execution failed" }
    $jsonLine = @($raw -split "`r?`n" | Where-Object { $_.Trim() }) | Select-Object -Last 1
    return ($jsonLine | ConvertFrom-Json)
  } finally {
    if (Test-Path -LiteralPath $localPy) { Remove-Item -LiteralPath $localPy -Force }
    ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingHost" "rm -f $remotePy" | Out-Null
  }
}

function Wait-EscalationCorrelation($baseUrl, $seed, $attempts = 20) {
  $last = $null
  for ($i = 0; $i -lt $attempts; $i++) {
    $last = Invoke-JsonApi -url "$baseUrl/api/v1/escalations/recent?limit=50" -method "GET" -contentType $null -timeoutSeconds 20
    $coder = @($last.events) | Where-Object { $_.details.task_id -eq $seed.coder_task_id } | Select-Object -First 1
    if ($null -ne $coder -and $coder.request_id -eq $seed.request_id) {
      return $last
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted escalation-request-correlation verification failed: escalations/recent did not expose the seeded request correlation"
}

$seed = Invoke-RemoteSeedEscalationRequestCorrelation
$escalations = Wait-EscalationCorrelation -baseUrl $BaseUrl -seed $seed
$coderEscalation = @($escalations.events) | Where-Object { $_.details.task_id -eq $seed.coder_task_id } | Select-Object -First 1
$tasksRecent = Invoke-JsonApi -url "$BaseUrl/api/v1/tasks/recent?limit=100" -method "GET" -contentType $null -timeoutSeconds 20
$sessionsRecent = Invoke-JsonApi -url "$BaseUrl/api/v1/sessions/recent?limit=50" -method "GET" -contentType $null -timeoutSeconds 20
$coderHistory = Invoke-JsonApi -url "$BaseUrl/api/v1/sessions/$($seed.coder_session_id)/history" -method "GET" -contentType $null -timeoutSeconds 20
$auditRecent = Invoke-JsonApi -url "$BaseUrl/api/v1/audit/recent?limit=100" -method "GET" -contentType $null -timeoutSeconds 20

$coderTask = @($tasksRecent.tasks) | Where-Object { $_.task_id -eq $seed.coder_task_id } | Select-Object -First 1
$coderSession = @($sessionsRecent.sessions) | Where-Object { $_.session_id -eq $seed.coder_session_id } | Select-Object -First 1
$coderHistoryTask = @($coderHistory.tasks) | Where-Object { $_.task_id -eq $seed.coder_task_id } | Select-Object -First 1
$coderAudit = @($auditRecent.events) | Where-Object { $_.details.task_id -eq $seed.coder_task_id } | Select-Object -First 1

$surfaces = @(
  @{ name = "coder escalation"; item = $coderEscalation; request = "request_id"; trace = "trace_id"; corr = "correlation_evidence_ref" },
  @{ name = "coder task"; item = $coderTask; request = "request_id"; trace = "trace_id"; corr = "correlation_evidence_ref" },
  @{ name = "coder session"; item = $coderSession; request = "request_id"; trace = "trace_id"; corr = "correlation_evidence_ref" },
  @{ name = "coder history task"; item = $coderHistoryTask; request = "request_id"; trace = "trace_id"; corr = "correlation_evidence_ref" },
  @{ name = "coder audit"; item = $coderAudit; request = "request_id"; trace = "trace_id"; corr = "correlation_evidence_ref" }
)

foreach ($surface in $surfaces) {
  Assert-True "$($surface.name) visible" ($null -ne $surface.item)
  Assert-True "$($surface.name) request parity" ($surface.item.($surface.request) -eq $seed.request_id)
  Assert-True "$($surface.name) trace parity" ($surface.item.($surface.trace) -eq $seed.trace_id)
  Assert-True "$($surface.name) correlation parity" ($surface.item.($surface.corr) -eq $seed.correlation_evidence_ref)
}

Write-Host "[phase4-escalation-request-correlation] base_url=$BaseUrl"
Write-Host "[phase4-escalation-request-correlation] trace_id=$($seed.trace_id)"
Write-Host "[phase4-escalation-request-correlation] request_id=$($seed.request_id)"
Write-Host "[phase4-escalation-request-correlation] coder_task_id=$($seed.coder_task_id)"
Write-Host "[phase4-escalation-request-correlation] result=verified"

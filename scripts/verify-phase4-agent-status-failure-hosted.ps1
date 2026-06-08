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
    throw "Phase4 hosted agent-status-failure verification failed: $label"
  }
}

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase4 hosted agent-status-failure verification failed: $label did not contain '$expected'. Value: $text"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-agent-status-failure-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted agent-status-failure verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

function Invoke-RemoteSeedAgentFailureStatus() {
  if (-not (Test-Path -LiteralPath $KeyPath)) {
    throw "Phase4 hosted agent-status-failure verification failed: SSH key path not found: $KeyPath"
  }

  $projectId = [Guid]::NewGuid().ToString()
  $coderSessionId = [Guid]::NewGuid().ToString()
  $testerSessionId = [Guid]::NewGuid().ToString()
  $coderTaskId = [Guid]::NewGuid().ToString()
  $testerTaskId = [Guid]::NewGuid().ToString()
  $localPy = Join-Path $env:TEMP ("phase4-agent-status-seed-" + [Guid]::NewGuid().ToString("N") + ".py")
  $remotePy = "/tmp/phase4_agent_status_seed.py"
$script = @"
import json
import os
import subprocess

seed_code = r'''
from datetime import datetime, timedelta, timezone
import os

import json
import psycopg
import redis
from psycopg.types.json import Json
from app.db import redis_url
from app.tasks import TASK_STATUS_PREFIX, TASK_TTL_SECONDS

project_id = "$projectId"
coder_session_id = "$coderSessionId"
tester_session_id = "$testerSessionId"
coder_task_id = "$coderTaskId"
tester_task_id = "$testerTaskId"
old = (datetime.now(timezone.utc) - timedelta(seconds=90)).isoformat()

client = redis.Redis.from_url(redis_url(), socket_timeout=2, socket_connect_timeout=2, decode_responses=True)

with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO projects(id, name, owner_id, metadata)
            VALUES (%s, 'hosted-phase4-agent-status', 'runtime-verifier', %s)
            ON CONFLICT (id) DO NOTHING
            """,
            (project_id, Json({"source": "verify-phase4-agent-status-failure-hosted"})),
        )
        cur.execute(
            """
            INSERT INTO agent_sessions(id, project_id, agent_list, metadata)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (id) DO NOTHING
            """,
            (
                coder_session_id,
                project_id,
                ["planner", "coder", "tester", "devops"],
                Json({"source": "hosted-agent-status-coder-error-proof", "latest_task_id": coder_task_id}),
            ),
        )
        cur.execute(
            """
            INSERT INTO agent_sessions(id, project_id, agent_list, metadata)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (id) DO NOTHING
            """,
            (
                tester_session_id,
                project_id,
                ["planner", "coder", "tester", "devops"],
                Json({"source": "hosted-agent-status-tester-error-proof", "latest_task_id": tester_task_id}),
            ),
        )
        cur.execute(
            """
            INSERT INTO audit_log(event_type, session_id, details, severity)
            VALUES
              ('task_escalated', %s, %s, 'warning'),
              ('task_abandoned_after_queue_drain', %s, %s, 'warning')
            """,
            (
                coder_session_id,
                Json({"task_id": coder_task_id, "agent_type": "coder", "retry_count": 1, "max_retries": 1}),
                tester_session_id,
                Json({"task_id": tester_task_id, "agent_type": "tester", "status": "abandoned_after_queue_drain"}),
            ),
        )

client.setex(
    TASK_STATUS_PREFIX + coder_task_id,
    TASK_TTL_SECONDS,
    json.dumps({
        "project_id": project_id,
        "session_id": coder_session_id,
        "agent_type": "coder",
        "task_type": "hosted_agent_status_escalated_regression",
        "task_description": "hosted agent status escalated regression proof",
        "task_id": coder_task_id,
        "status": "escalated",
        "created_at": old,
        "updated_at": old,
        "trace_id": "hosted-phase4-agent-status:" + coder_task_id,
        "priority": 5,
        "max_retries": 1,
        "allowed_tools": ["memory_read"],
        "write_scope": [],
        "blocked_actions": ["force_push", "live_provider_call", "prod_deploy", "push_main", "delete_without_approval"],
        "acceptance_criteria": ["error surfaced in agents/status"],
        "human_review_required": True,
        "policy_version": "task-policy-v1",
        "retry_count": 1,
        "result": None,
        "error": "foreign_key_violation_proof_escalated",
        "result_envelope": None,
        "done_validation": None,
    }),
)

client.setex(
    TASK_STATUS_PREFIX + tester_task_id,
    TASK_TTL_SECONDS,
    json.dumps({
        "project_id": project_id,
        "session_id": tester_session_id,
        "agent_type": "tester",
        "task_type": "hosted_agent_status_abandoned_regression",
        "task_description": "hosted agent status abandoned regression proof",
        "task_id": tester_task_id,
        "status": "abandoned_after_queue_drain",
        "created_at": old,
        "updated_at": old,
        "trace_id": "hosted-phase4-agent-status:" + tester_task_id,
        "priority": 4,
        "max_retries": 1,
        "allowed_tools": ["audit_recent"],
        "write_scope": [],
        "blocked_actions": ["force_push", "live_provider_call", "prod_deploy", "push_main", "delete_without_approval"],
        "acceptance_criteria": ["abandoned status surfaced in agents/status"],
        "human_review_required": True,
        "policy_version": "task-policy-v1",
        "retry_count": 0,
        "result": None,
        "error": "stale queued task abandoned after bounded rescue",
        "result_envelope": None,
        "done_validation": None,
    }),
)
'''.strip()

compose = [
    "docker", "compose",
    "--env-file", os.path.join("$RemoteRootPath", ".env"),
    "-f", os.path.join("$RemoteRootPath", "docker-compose.cloud.yml"),
]
subprocess.run(compose + ["exec", "-T", "agent-api", "python", "-c", seed_code], check=True)
print(json.dumps({
    "project_id": "$projectId",
    "coder_session_id": "$coderSessionId",
    "tester_session_id": "$testerSessionId",
    "coder_task_id": "$coderTaskId",
    "tester_task_id": "$testerTaskId",
}))
"@
  Set-Content -LiteralPath $localPy -Value $script
  try {
    scp -i $KeyPath -o StrictHostKeyChecking=no $localPy "${RemoteUser}@${StagingHost}:$remotePy" | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "Phase4 hosted agent-status-failure verification failed: could not copy seed script"
    }
    $raw = ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingHost" "python3 $remotePy"
    if ($LASTEXITCODE -ne 0) {
      throw "Phase4 hosted agent-status-failure verification failed: remote seed execution failed"
    }
    return ($raw | ConvertFrom-Json)
  } finally {
    if (Test-Path -LiteralPath $localPy) {
      Remove-Item -LiteralPath $localPy -Force
    }
    ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingHost" "rm -f $remotePy" | Out-Null
  }
}

function Wait-AgentSnapshot($baseUrl, $expectedTaskId, $expectedStatus, $attempts = 20) {
  $last = $null
  for ($i = 0; $i -lt $attempts; $i++) {
    $last = Invoke-JsonApi -url "$baseUrl/api/v1/agents/status" -method "GET" -contentType $null -timeoutSeconds 20
    $match = @($last.agents) | Where-Object { $_.latest_task_id -eq $expectedTaskId -and $_.latest_status -eq $expectedStatus } | Select-Object -First 1
    if ($null -ne $match) {
      return @{ Snapshot = $last; Agent = $match }
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted agent-status-failure verification failed: agent snapshot for task $expectedTaskId / $expectedStatus not visible."
}

$seed = Invoke-RemoteSeedAgentFailureStatus
$coderSnapshot = Wait-AgentSnapshot -baseUrl $BaseUrl -expectedTaskId $seed.coder_task_id -expectedStatus "escalated"
$testerSnapshot = Wait-AgentSnapshot -baseUrl $BaseUrl -expectedTaskId $seed.tester_task_id -expectedStatus "abandoned_after_queue_drain"
$recentTasks = Invoke-JsonApi -url "$BaseUrl/api/v1/tasks/recent?limit=60" -method "GET" -contentType $null -timeoutSeconds 20
$audit = Invoke-JsonApi -url "$BaseUrl/api/v1/audit/recent?limit=80" -method "GET" -contentType $null -timeoutSeconds 20
$health = Invoke-JsonApi -url "$BaseUrl/api/v1/health" -method "GET" -contentType $null -timeoutSeconds 20

$coder = $coderSnapshot.Agent
$tester = $testerSnapshot.Agent
$coderTask = @($recentTasks.tasks) | Where-Object { $_.task_id -eq $seed.coder_task_id } | Select-Object -First 1
$testerTask = @($recentTasks.tasks) | Where-Object { $_.task_id -eq $seed.tester_task_id } | Select-Object -First 1

Assert-True "health healthy" ($health.status -eq "healthy")
Assert-True "coder surfaced as error" ($coder.status -eq "error")
Assert-True "coder latest escalated" ($coder.latest_status -eq "escalated")
Assert-True "coder retries surfaced" ([int]$coder.retries -eq 1)
Assert-True "coder latest retry count surfaced" ([int]$coder.latest_retry_count -eq 1)
Assert-True "coder latest max retries surfaced" ([int]$coder.latest_max_retries -eq 1)
Assert-Contains "coder latest error surfaced" $coder.latest_error "foreign_key_violation_proof_escalated"
Assert-True "tester surfaced as error" ($tester.status -eq "error")
Assert-True "tester latest abandoned" ($tester.latest_status -eq "abandoned_after_queue_drain")
Assert-Contains "tester latest error surfaced" $tester.latest_error "stale queued task abandoned after bounded rescue"
Assert-True "recent task coder visible" ($null -ne $coderTask)
Assert-True "recent task coder escalated" ($coderTask.status -eq "escalated")
Assert-True "recent task tester visible" ($null -ne $testerTask)
Assert-True "recent task tester abandoned" ($testerTask.status -eq "abandoned_after_queue_drain")
Assert-Contains "audit escalated" ($audit | ConvertTo-Json -Depth 10 -Compress) "task_escalated"
Assert-Contains "audit abandoned" ($audit | ConvertTo-Json -Depth 10 -Compress) "task_abandoned_after_queue_drain"

Write-Host "[phase4-hosted-agent-status-failure] checks completed"

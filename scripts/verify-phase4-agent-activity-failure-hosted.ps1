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
    throw "Phase4 hosted agent-activity-failure verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-agent-activity-failure-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted agent-activity-failure verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

function Invoke-RemoteSeedAgentActivityFailure() {
  $traceId = [Guid]::NewGuid().ToString()
  $projectId = [Guid]::NewGuid().ToString()
  $coderSessionId = [Guid]::NewGuid().ToString()
  $testerSessionId = [Guid]::NewGuid().ToString()
  $coderTaskId = [Guid]::NewGuid().ToString()
  $testerTaskId = [Guid]::NewGuid().ToString()
  $localPy = Join-Path $env:TEMP ("phase4-agent-activity-seed-" + [Guid]::NewGuid().ToString("N") + ".py")
  $remotePy = "/tmp/phase4_agent_activity_failure_seed.py"
  $script = @"
import json
import os
import subprocess

seed_code = r'''
from datetime import datetime, timezone
import os
import psycopg
from psycopg.types.json import Json

project_id = "$projectId"
trace_id = "$traceId"
coder_session_id = "$coderSessionId"
tester_session_id = "$testerSessionId"
coder_task_id = "$coderTaskId"
tester_task_id = "$testerTaskId"
now = datetime.now(timezone.utc)

with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO projects(id, name, owner_id, metadata)
            VALUES (%s, 'hosted-phase4-agent-activity-failure', 'runtime-verifier', %s)
            ON CONFLICT (id) DO NOTHING
            """,
            (project_id, Json({"source": "verify-phase4-agent-activity-failure-hosted"})),
        )
        cur.execute(
            """
            INSERT INTO agent_sessions(id, project_id, agent_list, metadata)
            VALUES (%s, %s, %s, %s), (%s, %s, %s, %s)
            ON CONFLICT (id) DO NOTHING
            """,
            (
                coder_session_id, project_id, ["planner", "coder", "tester", "devops"], Json({"trace_id": trace_id}),
                tester_session_id, project_id, ["planner", "coder", "tester", "devops"], Json({"trace_id": trace_id}),
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
                    "error": "foreign_key_violation_proof_escalated",
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
                    "error": "stale queued task abandoned after bounded rescue",
                }),
                now,
            ),
        )
'''.strip()

compose = [
    "docker", "compose",
    "--env-file", os.path.join("$RemoteRootPath", ".env"),
    "-f", os.path.join("$RemoteRootPath", "docker-compose.cloud.yml"),
]
subprocess.run(compose + ["exec", "-T", "agent-api", "python", "-c", seed_code], check=True)
print(json.dumps({
    "trace_id": "$traceId",
    "coder_task_id": "$coderTaskId",
    "tester_task_id": "$testerTaskId",
}))
"@
  Set-Content -LiteralPath $localPy -Value $script
  try {
    scp -i $KeyPath -o StrictHostKeyChecking=no $localPy "${RemoteUser}@${StagingHost}:$remotePy" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Phase4 hosted agent-activity-failure verification failed: could not copy seed script" }
    $raw = ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingHost" "python3 $remotePy"
    if ($LASTEXITCODE -ne 0) { throw "Phase4 hosted agent-activity-failure verification failed: remote seed execution failed" }
    return ($raw | ConvertFrom-Json)
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
  throw "Phase4 hosted agent-activity-failure verification failed: activity events not visible for trace $traceId"
}

$seed = Invoke-RemoteSeedAgentActivityFailure
$activity = Wait-ActivityEvents -baseUrl $BaseUrl -traceId $seed.trace_id
$events = @($activity.events)
$coder = $events | Where-Object { $_.task_id -eq $seed.coder_task_id } | Select-Object -First 1
$tester = $events | Where-Object { $_.task_id -eq $seed.tester_task_id } | Select-Object -First 1
$health = Invoke-JsonApi -url "$BaseUrl/api/v1/health" -method "GET" -contentType $null -timeoutSeconds 20

Assert-True "health healthy" ($health.status -eq "healthy")
Assert-True "coder event visible" ($null -ne $coder)
Assert-True "coder top-level agent type" ($coder.agent_type -eq "coder")
Assert-True "coder top-level status" ($coder.task_status -eq "escalated")
Assert-True "coder retry_count surfaced" ([int]$coder.retry_count -eq 1)
Assert-True "coder max_retries surfaced" ([int]$coder.max_retries -eq 1)
Assert-True "coder error surfaced" (($coder.error | Out-String).Contains("foreign_key_violation_proof_escalated"))
Assert-True "tester event visible" ($null -ne $tester)
Assert-True "tester top-level agent type" ($tester.agent_type -eq "tester")
Assert-True "tester top-level status" ($tester.task_status -eq "abandoned_after_queue_drain")
Assert-True "tester retry_count surfaced" ([int]$tester.retry_count -eq 0)
Assert-True "tester max_retries surfaced" ([int]$tester.max_retries -eq 1)
Assert-True "tester error surfaced" (($tester.error | Out-String).Contains("stale queued task abandoned after bounded rescue"))

Write-Host "[phase4-hosted-agent-activity-failure] checks completed"

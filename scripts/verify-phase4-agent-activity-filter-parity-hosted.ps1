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
    throw "Phase4 hosted agent-activity-filter-parity verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-agent-activity-filter-parity-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted agent-activity-filter-parity verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

function Invoke-RemoteSeedAgentActivityFilters() {
  $traceId = [Guid]::NewGuid().ToString()
  $projectId = [Guid]::NewGuid().ToString()
  $coderSessionId = [Guid]::NewGuid().ToString()
  $testerSessionId = [Guid]::NewGuid().ToString()
  $coderTaskId = [Guid]::NewGuid().ToString()
  $testerTaskId = [Guid]::NewGuid().ToString()
  $localPy = Join-Path $env:TEMP ("phase4-agent-activity-filter-seed-" + [Guid]::NewGuid().ToString("N") + ".py")
  $remotePy = "/tmp/phase4_agent_activity_filter_seed.py"
  $script = @"
import json
import os
import subprocess

seed_code = r'''
from datetime import datetime, timezone
import json
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
            VALUES (%s, 'hosted-phase4-agent-activity-filter-parity', 'runtime-verifier', %s)
            ON CONFLICT (id) DO NOTHING
            """,
            (project_id, Json({"source": "verify-phase4-agent-activity-filter-parity-hosted"})),
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
            INSERT INTO audit_log(event_type, user_id, session_id, details, severity, created_at)
            VALUES
              ('task_escalated', 'coder', %s, %s, 'warning', %s),
              ('task_abandoned_after_queue_drain', 'tester', %s, %s, 'warning', %s)
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
                    "error": "agent_activity_filter_coder_escalated",
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
                    "error": "agent_activity_filter_tester_abandoned",
                }),
                now,
            ),
        )

print(json.dumps({
    "trace_id": trace_id,
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
    "coder_task_id": "$coderTaskId",
    "tester_task_id": "$testerTaskId",
}))
"@
  Set-Content -LiteralPath $localPy -Value $script
  try {
    scp -i $KeyPath -o StrictHostKeyChecking=no $localPy "${RemoteUser}@${StagingHost}:$remotePy" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Phase4 hosted agent-activity-filter-parity verification failed: could not copy seed script" }
    $raw = ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingHost" "python3 $remotePy"
    if ($LASTEXITCODE -ne 0) { throw "Phase4 hosted agent-activity-filter-parity verification failed: remote seed execution failed" }
    $jsonLine = @($raw -split "`r?`n" | Where-Object { $_.Trim() }) | Select-Object -Last 1
    return ($jsonLine | ConvertFrom-Json)
  } finally {
    if (Test-Path -LiteralPath $localPy) { Remove-Item -LiteralPath $localPy -Force }
    ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingHost" "rm -f $remotePy" | Out-Null
  }
}

function Wait-ActivityVisible($baseUrl, $traceId, $attempts = 20) {
  for ($i = 0; $i -lt $attempts; $i++) {
    $activity = Invoke-JsonApi -url "$baseUrl/api/v1/agent-activity/recent?limit=20&trace_id=$traceId" -method "GET" -contentType $null -timeoutSeconds 20
    if ((@($activity.events) | Measure-Object).Count -ge 2) {
      return $activity
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted agent-activity-filter-parity verification failed: seeded activity events not visible"
}

$seed = Invoke-RemoteSeedAgentActivityFilters
$allEvents = Wait-ActivityVisible -baseUrl $BaseUrl -traceId $seed.trace_id
$coderFiltered = Invoke-JsonApi -url "$BaseUrl/api/v1/agent-activity/recent?limit=20&trace_id=$($seed.trace_id)&agent_type=coder&event_type=task_escalated&severity=warning" -method "GET" -contentType $null -timeoutSeconds 20
$testerFiltered = Invoke-JsonApi -url "$BaseUrl/api/v1/agent-activity/recent?limit=20&trace_id=$($seed.trace_id)&agent_type=tester&event_type=task_abandoned_after_queue_drain&severity=warning" -method "GET" -contentType $null -timeoutSeconds 20
$audit = Invoke-JsonApi -url "$BaseUrl/api/v1/audit/recent?limit=50" -method "GET" -contentType $null -timeoutSeconds 20

$coderAll = @($allEvents.events) | Where-Object { $_.task_id -eq $seed.coder_task_id } | Select-Object -First 1
$testerAll = @($allEvents.events) | Where-Object { $_.task_id -eq $seed.tester_task_id } | Select-Object -First 1
$coderOne = @($coderFiltered.events) | Select-Object -First 1
$testerOne = @($testerFiltered.events) | Select-Object -First 1
$coderAudit = @($audit.events) | Where-Object { $_.details.task_id -eq $seed.coder_task_id -and $_.event_type -eq "task_escalated" } | Select-Object -First 1
$testerAudit = @($audit.events) | Where-Object { $_.details.task_id -eq $seed.tester_task_id -and $_.event_type -eq "task_abandoned_after_queue_drain" } | Select-Object -First 1

Assert-True "coder all-feed visible" ($null -ne $coderAll)
Assert-True "tester all-feed visible" ($null -ne $testerAll)
Assert-True "coder filtered visible" ($null -ne $coderOne)
Assert-True "tester filtered visible" ($null -ne $testerOne)
Assert-True "coder audit visible" ($null -ne $coderAudit)
Assert-True "tester audit visible" ($null -ne $testerAudit)

Assert-True "coder filtered count exact" ((@($coderFiltered.events) | Measure-Object).Count -eq 1)
Assert-True "tester filtered count exact" ((@($testerFiltered.events) | Measure-Object).Count -eq 1)
Assert-True "coder filtered agent type" ($coderOne.agent_type -eq "coder")
Assert-True "tester filtered agent type" ($testerOne.agent_type -eq "tester")
Assert-True "coder filtered event type" ($coderOne.event_type -eq "task_escalated")
Assert-True "tester filtered event type" ($testerOne.event_type -eq "task_abandoned_after_queue_drain")
Assert-True "coder filtered severity" ($coderOne.severity -eq "warning")
Assert-True "tester filtered severity" ($testerOne.severity -eq "warning")
Assert-True "coder filtered trace parity" ($coderOne.trace_id -eq $seed.trace_id -and $coderAudit.trace_id -eq $seed.trace_id)
Assert-True "tester filtered trace parity" ($testerOne.trace_id -eq $seed.trace_id -and $testerAudit.trace_id -eq $seed.trace_id)
Assert-True "coder filtered task parity" ($coderOne.task_id -eq $seed.coder_task_id -and $coderAudit.details.task_id -eq $seed.coder_task_id)
Assert-True "tester filtered task parity" ($testerOne.task_id -eq $seed.tester_task_id -and $testerAudit.details.task_id -eq $seed.tester_task_id)
Assert-True "coder filtered retry parity" ([int]$coderOne.retry_count -eq [int]$coderAudit.details.retry_count)
Assert-True "tester filtered retry parity" ([int]$testerOne.retry_count -eq [int]$testerAudit.details.retry_count)

Write-Host "[phase4-hosted-agent-activity-filter-parity] checks completed"

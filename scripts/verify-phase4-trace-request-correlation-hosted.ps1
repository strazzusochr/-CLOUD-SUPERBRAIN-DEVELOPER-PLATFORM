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
    throw "Phase4 hosted trace-request-correlation verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-trace-request-correlation-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted trace-request-correlation verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

function Invoke-RemoteSeedTraceRequestCorrelation() {
  $traceId = [Guid]::NewGuid().ToString()
  $requestId = "req-phase4-" + [Guid]::NewGuid().ToString("N").Substring(0, 20)
  $projectId = [Guid]::NewGuid().ToString()
  $coderSessionId = [Guid]::NewGuid().ToString()
  $testerSessionId = [Guid]::NewGuid().ToString()
  $coderTaskId = [Guid]::NewGuid().ToString()
  $testerTaskId = [Guid]::NewGuid().ToString()
  $localPy = Join-Path $env:TEMP ("phase4-trace-request-correlation-seed-" + [Guid]::NewGuid().ToString("N") + ".py")
  $remotePy = "/tmp/phase4_trace_request_correlation_seed.py"
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
request_id = "$requestId"
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
            VALUES (%s, 'hosted-phase4-trace-request-correlation', 'runtime-verifier', %s)
            ON CONFLICT (id) DO NOTHING
            """,
            (project_id, Json({"source": "verify-phase4-trace-request-correlation-hosted"})),
        )
        cur.execute(
            """
            INSERT INTO agent_sessions(id, project_id, agent_list, metadata)
            VALUES (%s, %s, %s, %s), (%s, %s, %s, %s)
            ON CONFLICT (id) DO UPDATE
            SET metadata = agent_sessions.metadata || EXCLUDED.metadata
            """,
            (
                coder_session_id, project_id, ["planner", "coder", "tester", "devops"], Json({"trace_id": trace_id, "latest_task_id": coder_task_id, "request_id": request_id}),
                tester_session_id, project_id, ["planner", "coder", "tester", "devops"], Json({"trace_id": trace_id, "latest_task_id": tester_task_id, "request_id": request_id}),
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
                    "request_id": request_id,
                    "session_id": coder_session_id,
                    "task_id": coder_task_id,
                    "agent_type": "coder",
                    "status": "escalated",
                    "retry_count": 1,
                    "max_retries": 1,
                    "error": "trace_request_correlation_escalated",
                    "correlation_evidence_ref": "request_id_audit_correlation",
                }),
                now,
                tester_session_id,
                Json({
                    "trace_id": trace_id,
                    "request_id": request_id,
                    "session_id": tester_session_id,
                    "task_id": tester_task_id,
                    "agent_type": "tester",
                    "status": "abandoned_after_queue_drain",
                    "retry_count": 0,
                    "max_retries": 1,
                    "error": "trace_request_correlation_abandoned",
                    "correlation_evidence_ref": "request_id_audit_correlation",
                }),
                now,
            ),
        )

print(json.dumps({
    "trace_id": trace_id,
    "request_id": request_id,
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
    "request_id": "$requestId",
    "coder_session_id": "$coderSessionId",
    "tester_session_id": "$testerSessionId",
    "coder_task_id": "$coderTaskId",
    "tester_task_id": "$testerTaskId",
}))
"@
  Set-Content -LiteralPath $localPy -Value $script
  try {
    scp -i $KeyPath -o StrictHostKeyChecking=no $localPy "${RemoteUser}@${StagingHost}:$remotePy" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Phase4 hosted trace-request-correlation verification failed: could not copy seed script" }
    $raw = ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingHost" "python3 $remotePy"
    if ($LASTEXITCODE -ne 0) { throw "Phase4 hosted trace-request-correlation verification failed: remote seed execution failed" }
    $jsonLine = @($raw -split "`r?`n" | Where-Object { $_.Trim() }) | Select-Object -Last 1
    return ($jsonLine | ConvertFrom-Json)
  } finally {
    if (Test-Path -LiteralPath $localPy) { Remove-Item -LiteralPath $localPy -Force }
    ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingHost" "rm -f $remotePy" | Out-Null
  }
}

function Wait-CorrelationParity($baseUrl, $seed, $attempts = 20) {
  for ($i = 0; $i -lt $attempts; $i++) {
    $activity = Invoke-JsonApi -url "$baseUrl/api/v1/agent-activity/recent?limit=20&trace_id=$($seed.trace_id)" -method "GET" -contentType $null -timeoutSeconds 20
    $audit = Invoke-JsonApi -url "$baseUrl/api/v1/audit/recent?limit=50" -method "GET" -contentType $null -timeoutSeconds 20
    $coderActivity = @($activity.events) | Where-Object { $_.task_id -eq $seed.coder_task_id } | Select-Object -First 1
    $testerActivity = @($activity.events) | Where-Object { $_.task_id -eq $seed.tester_task_id } | Select-Object -First 1
    $coderAudit = @($audit.events) | Where-Object { $_.details.task_id -eq $seed.coder_task_id -and $_.event_type -eq "task_escalated" } | Select-Object -First 1
    $testerAudit = @($audit.events) | Where-Object { $_.details.task_id -eq $seed.tester_task_id -and $_.event_type -eq "task_abandoned_after_queue_drain" } | Select-Object -First 1
    if ($null -ne $coderActivity -and $null -ne $testerActivity -and $null -ne $coderAudit -and $null -ne $testerAudit) {
      return [pscustomobject]@{
        activity = $activity
        audit = $audit
        coderActivity = $coderActivity
        testerActivity = $testerActivity
        coderAudit = $coderAudit
        testerAudit = $testerAudit
      }
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted trace-request-correlation verification failed: seeded correlation events did not appear across activity and audit feeds"
}

$requestContract = Invoke-JsonApi -url "$BaseUrl/api/v1/request/contract" -method "GET" -contentType $null -timeoutSeconds 20
$seed = Invoke-RemoteSeedTraceRequestCorrelation
$bundle = Wait-CorrelationParity -baseUrl $BaseUrl -seed $seed
$coderHistory = Invoke-JsonApi -url "$BaseUrl/api/v1/sessions/$($seed.coder_session_id)/history" -method "GET" -contentType $null -timeoutSeconds 20
$testerHistory = Invoke-JsonApi -url "$BaseUrl/api/v1/sessions/$($seed.tester_session_id)/history" -method "GET" -contentType $null -timeoutSeconds 20
$coderHistoryAudit = @($coderHistory.audit_events) | Where-Object { $_.details.task_id -eq $seed.coder_task_id -and $_.event_type -eq "task_escalated" } | Select-Object -First 1
$testerHistoryAudit = @($testerHistory.audit_events) | Where-Object { $_.details.task_id -eq $seed.tester_task_id -and $_.event_type -eq "task_abandoned_after_queue_drain" } | Select-Object -First 1

Assert-True "request contract visible" ($requestContract.contract_version -eq "request-id-correlation-v1")
Assert-True "request contract audit correlation ref" ($requestContract.evidence_refs.audit_correlation -eq "request_id_audit_correlation")
Assert-True "request contract audit feed ref" ($requestContract.evidence_refs.audit_feed_visibility -eq "request_id_audit_feed_visible")
Assert-True "request contract fields" (@($requestContract.audit_correlation_fields) -contains "request_id" -and @($requestContract.audit_correlation_fields) -contains "trace_id")

Assert-True "coder history audit visible" ($null -ne $coderHistoryAudit)
Assert-True "tester history audit visible" ($null -ne $testerHistoryAudit)

Assert-True "coder trace parity activity->audit->history" (
  $bundle.coderActivity.trace_id -eq $seed.trace_id -and
  $bundle.coderAudit.trace_id -eq $seed.trace_id -and
  $coderHistoryAudit.trace_id -eq $seed.trace_id
)
Assert-True "tester trace parity activity->audit->history" (
  $bundle.testerActivity.trace_id -eq $seed.trace_id -and
  $bundle.testerAudit.trace_id -eq $seed.trace_id -and
  $testerHistoryAudit.trace_id -eq $seed.trace_id
)
Assert-True "coder request id parity activity->audit->history" (
  $bundle.coderActivity.details.request_id -eq $seed.request_id -and
  $bundle.coderAudit.request_id -eq $seed.request_id -and
  $coderHistoryAudit.request_id -eq $seed.request_id
)
Assert-True "tester request id parity activity->audit->history" (
  $bundle.testerActivity.details.request_id -eq $seed.request_id -and
  $bundle.testerAudit.request_id -eq $seed.request_id -and
  $testerHistoryAudit.request_id -eq $seed.request_id
)
Assert-True "coder correlation evidence parity activity->audit->history" (
  $bundle.coderActivity.details.correlation_evidence_ref -eq "request_id_audit_correlation" -and
  $bundle.coderAudit.correlation_evidence_ref -eq "request_id_audit_correlation" -and
  $coderHistoryAudit.details.correlation_evidence_ref -eq "request_id_audit_correlation"
)
Assert-True "tester correlation evidence parity activity->audit->history" (
  $bundle.testerActivity.details.correlation_evidence_ref -eq "request_id_audit_correlation" -and
  $bundle.testerAudit.correlation_evidence_ref -eq "request_id_audit_correlation" -and
  $testerHistoryAudit.details.correlation_evidence_ref -eq "request_id_audit_correlation"
)
Assert-True "audit feed evidence visible for coder" ($bundle.coderAudit.audit_feed_evidence_ref -eq "request_id_audit_feed_visible")
Assert-True "audit feed evidence visible for tester" ($bundle.testerAudit.audit_feed_evidence_ref -eq "request_id_audit_feed_visible")

Write-Host "[phase4-hosted-trace-request-correlation] checks completed"

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
    throw "Phase4 hosted agent-status-contract runtime verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-agent-status-contract-runtime-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted agent-status-contract runtime verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

function Invoke-RemoteSeedAgentStatusContract() {
  $traceId = [Guid]::NewGuid().ToString()
  $requestId = "req-" + [Guid]::NewGuid().ToString("N")
  $projectId = [Guid]::NewGuid().ToString()
  $coderSessionId = [Guid]::NewGuid().ToString()
  $testerSessionId = [Guid]::NewGuid().ToString()
  $coderTaskId = [Guid]::NewGuid().ToString()
  $testerTaskId = [Guid]::NewGuid().ToString()
  $localPy = Join-Path $env:TEMP ("phase4-agent-status-contract-seed-" + [Guid]::NewGuid().ToString("N") + ".py")
  $remotePy = "/tmp/phase4_agent_status_contract_seed.py"
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
correlation_evidence_ref = "request_id_agent_status_visible"
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
        "task_description": "hosted agent status contract proof for " + task_type,
        "task_id": task_id,
        "status": status,
        "created_at": old,
        "updated_at": old,
        "trace_id": trace_id,
        "priority": 5,
        "max_retries": max_retries,
        "allowed_tools": ["memory_read", "task_router"],
        "write_scope": [],
        "blocked_actions": ["force_push", "live_provider_call", "prod_deploy", "push_main", "delete_without_approval"],
        "acceptance_criteria": ["result_envelope", "done_validation", "audit_log"],
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
            VALUES (%s, 'hosted-phase4-agent-status-contract', 'runtime-verifier', %s)
            ON CONFLICT (id) DO NOTHING
            """,
            (project_id, Json({"source": "verify-phase4-agent-status-contract-runtime-hosted"})),
        )
        cur.execute(
            """
            INSERT INTO agent_sessions(id, project_id, agent_list, metadata)
            VALUES (%s, %s, %s, %s), (%s, %s, %s, %s)
            ON CONFLICT (id) DO UPDATE
            SET metadata = agent_sessions.metadata || EXCLUDED.metadata
            """,
            (
                coder_session_id, project_id, ["planner", "coder", "tester", "devops"], Json({"trace_id": trace_id, "request_id": request_id, "latest_task_id": coder_task_id}),
                tester_session_id, project_id, ["planner", "coder", "tester", "devops"], Json({"trace_id": trace_id, "request_id": request_id, "latest_task_id": tester_task_id}),
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
                    "request_id": request_id,
                    "correlation_evidence_ref": correlation_evidence_ref,
                    "task_id": coder_task_id,
                    "agent_type": "coder",
                    "status": "escalated",
                    "retry_count": 1,
                    "max_retries": 1,
                    "error": "foreign_key_violation_agent_status_contract_escalated",
                }),
                now,
                tester_session_id,
                Json({
                    "trace_id": trace_id,
                    "request_id": request_id,
                    "correlation_evidence_ref": correlation_evidence_ref,
                    "task_id": tester_task_id,
                    "agent_type": "tester",
                    "status": "abandoned_after_queue_drain",
                    "retry_count": 0,
                    "max_retries": 1,
                    "error": "stale queued task abandoned after bounded rescue agent status contract",
                }),
                now,
            ),
        )

client = redis.Redis.from_url(os.environ["REDIS_URL"], decode_responses=True)
client.set("task:status:" + coder_task_id, json.dumps(task(coder_task_id, coder_session_id, "coder", "escalated", 1, 1, "foreign_key_violation_agent_status_contract_escalated", "hosted_agent_status_contract_coder"), separators=(",", ":")), ex=86400)
client.set("task:status:" + tester_task_id, json.dumps(task(tester_task_id, tester_session_id, "tester", "abandoned_after_queue_drain", 0, 1, "stale queued task abandoned after bounded rescue agent status contract", "hosted_agent_status_contract_tester"), separators=(",", ":")), ex=86400)

print(json.dumps({
    "trace_id": trace_id,
    "request_id": request_id,
    "correlation_evidence_ref": correlation_evidence_ref,
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
"@
  Set-Content -LiteralPath $localPy -Value $script
  try {
    scp -i $KeyPath -o StrictHostKeyChecking=no $localPy "${RemoteUser}@${StagingHost}:$remotePy" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Phase4 hosted agent-status-contract runtime verification failed: could not copy seed script" }
    $raw = ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingHost" "python3 $remotePy"
    if ($LASTEXITCODE -ne 0) { throw "Phase4 hosted agent-status-contract runtime verification failed: remote seed execution failed" }
    $jsonLine = @($raw -split "`r?`n" | Where-Object { $_.Trim() }) | Select-Object -Last 1
    return ($jsonLine | ConvertFrom-Json)
  } finally {
    if (Test-Path -LiteralPath $localPy) { Remove-Item -LiteralPath $localPy -Force }
    ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingHost" "rm -f $remotePy" | Out-Null
  }
}

function Wait-AgentStatusSurface($baseUrl, $seed, $attempts = 20) {
  $last = $null
  for ($i = 0; $i -lt $attempts; $i++) {
    $last = Invoke-JsonApi -url "$baseUrl/api/v1/agents/status" -method "GET" -contentType $null -timeoutSeconds 20
    $coder = @($last.agents) | Where-Object { $_.type -eq "coder" } | Select-Object -First 1
    $tester = @($last.agents) | Where-Object { $_.type -eq "tester" } | Select-Object -First 1
    if (
      $null -ne $coder -and
      $null -ne $tester -and
      $coder.latest_task_id -eq $seed.coder_task_id -and
      $tester.latest_task_id -eq $seed.tester_task_id
    ) {
      return $last
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted agent-status-contract runtime verification failed: agents/status did not expose the seeded tasks"
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") {
  throw "Phase4 hosted agent-status-contract proof requires HTTPS"
}

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/agents/status/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "contract version" ($contract.contract_version -eq "agent-status-feed-v1")
Assert-True "error status supported" (@($contract.supported_statuses) -contains "error")
Assert-True "escalated latest status supported" (@($contract.supported_latest_task_statuses) -contains "escalated")
Assert-True "abandoned latest status supported" (@($contract.supported_latest_task_statuses) -contains "abandoned_after_queue_drain")

$seed = Invoke-RemoteSeedAgentStatusContract
$agents = Wait-AgentStatusSurface -baseUrl $BaseUrl -seed $seed
$coderAgent = @($agents.agents) | Where-Object { $_.type -eq "coder" } | Select-Object -First 1
$testerAgent = @($agents.agents) | Where-Object { $_.type -eq "tester" } | Select-Object -First 1

Assert-True "coder agent visible" ($null -ne $coderAgent)
Assert-True "tester agent visible" ($null -ne $testerAgent)

foreach ($field in @($contract.top_level_fields)) {
  Assert-True "coder field visible $field" ($coderAgent.PSObject.Properties.Name -contains [string]$field)
  Assert-True "tester field visible $field" ($testerAgent.PSObject.Properties.Name -contains [string]$field)
}

Assert-True "coder status is error" ($coderAgent.status -eq "error")
Assert-True "tester status is error" ($testerAgent.status -eq "error")
Assert-True "coder latest task parity" ($coderAgent.latest_task_id -eq $seed.coder_task_id)
Assert-True "tester latest task parity" ($testerAgent.latest_task_id -eq $seed.tester_task_id)
Assert-True "coder latest status parity" ($coderAgent.latest_status -eq "escalated")
Assert-True "tester latest status parity" ($testerAgent.latest_status -eq "abandoned_after_queue_drain")
Assert-True "coder request parity" ($coderAgent.latest_request_id -eq $seed.request_id)
Assert-True "tester request parity" ($testerAgent.latest_request_id -eq $seed.request_id)
Assert-True "coder trace parity" ($coderAgent.latest_trace_id -eq $seed.trace_id)
Assert-True "tester trace parity" ($testerAgent.latest_trace_id -eq $seed.trace_id)
Assert-True "coder correlation parity" ($coderAgent.latest_correlation_evidence_ref -eq $seed.correlation_evidence_ref)
Assert-True "tester correlation parity" ($testerAgent.latest_correlation_evidence_ref -eq $seed.correlation_evidence_ref)
Assert-True "coder audit evidence visible" ($coderAgent.latest_audit_feed_evidence_ref -eq "request_id_audit_feed_visible")
Assert-True "tester audit evidence visible" ($testerAgent.latest_audit_feed_evidence_ref -eq "request_id_audit_feed_visible")

Write-Host "[phase4-agent-status-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-agent-status-contract-runtime] trace_id=$($seed.trace_id)"
Write-Host "[phase4-agent-status-contract-runtime] request_id=$($seed.request_id)"
Write-Host "[phase4-agent-status-contract-runtime] result=verified"

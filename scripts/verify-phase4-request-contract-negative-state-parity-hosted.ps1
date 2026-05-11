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
    throw "Phase4 hosted request-contract negative-state parity verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-request-contract-negative-state-parity-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted request-contract negative-state parity verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

function Invoke-RemoteSeedNegativeStateParity() {
  $traceId = [Guid]::NewGuid().ToString()
  $requestId = "req-" + [Guid]::NewGuid().ToString("N")
  $projectId = [Guid]::NewGuid().ToString()
  $coderSessionId = [Guid]::NewGuid().ToString()
  $testerSessionId = [Guid]::NewGuid().ToString()
  $coderTaskId = [Guid]::NewGuid().ToString()
  $testerTaskId = [Guid]::NewGuid().ToString()
  $localPy = Join-Path $env:TEMP ("phase4-request-contract-negative-state-parity-seed-" + [Guid]::NewGuid().ToString("N") + ".py")
  $remotePy = "/tmp/phase4_request_contract_negative_state_parity_seed.py"
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
        "task_description": "hosted request contract negative-state parity proof for " + task_type,
        "task_id": task_id,
        "status": status,
        "created_at": old,
        "updated_at": old,
        "trace_id": trace_id,
        "request_id": request_id,
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
        "correlation_evidence_ref": correlation_evidence_ref,
        "audit_feed_evidence_ref": audit_feed_evidence_ref,
    }

def audit_details(task_id, agent_type, status, retry_count, max_retries, error):
    return {
        "trace_id": trace_id,
        "request_id": request_id,
        "correlation_evidence_ref": correlation_evidence_ref,
        "audit_feed_evidence_ref": audit_feed_evidence_ref,
        "task_id": task_id,
        "agent_type": agent_type,
        "status": status,
        "retry_count": retry_count,
        "max_retries": max_retries,
        "error": error,
    }

with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO projects(id, name, owner_id, metadata)
            VALUES (%s, 'hosted-phase4-request-contract-negative-state-parity', 'runtime-verifier', %s)
            ON CONFLICT (id) DO NOTHING
            """,
            (project_id, Json({"source": "verify-phase4-request-contract-negative-state-parity-hosted"})),
        )
        cur.execute(
            """
            INSERT INTO agent_sessions(id, project_id, agent_list, metadata)
            VALUES (%s, %s, %s, %s), (%s, %s, %s, %s)
            ON CONFLICT (id) DO UPDATE
            SET metadata = agent_sessions.metadata || EXCLUDED.metadata
            """,
            (
                coder_session_id, project_id, ["planner", "coder", "tester", "devops"], Json({
                    "trace_id": trace_id,
                    "request_id": request_id,
                    "correlation_evidence_ref": correlation_evidence_ref,
                    "audit_feed_evidence_ref": audit_feed_evidence_ref,
                    "latest_task_id": coder_task_id
                }),
                tester_session_id, project_id, ["planner", "coder", "tester", "devops"], Json({
                    "trace_id": trace_id,
                    "request_id": request_id,
                    "correlation_evidence_ref": correlation_evidence_ref,
                    "audit_feed_evidence_ref": audit_feed_evidence_ref,
                    "latest_task_id": tester_task_id
                }),
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
                Json(audit_details(coder_task_id, "coder", "escalated", 1, 1, "request_contract_negative_state_parity_escalation")),
                now,
                tester_session_id,
                Json(audit_details(tester_task_id, "tester", "abandoned_after_queue_drain", 0, 1, "request_contract_negative_state_parity_abandon")),
                now,
            ),
        )

client = redis.Redis.from_url(os.environ["REDIS_URL"], decode_responses=True)
client.set("task:status:" + coder_task_id, json.dumps(task(coder_task_id, coder_session_id, "coder", "escalated", 1, 1, "request_contract_negative_state_parity_escalation", "hosted_request_contract_negative_state_coder"), separators=(",", ":")), ex=86400)
client.set("task:status:" + tester_task_id, json.dumps(task(tester_task_id, tester_session_id, "tester", "abandoned_after_queue_drain", 0, 1, "request_contract_negative_state_parity_abandon", "hosted_request_contract_negative_state_tester"), separators=(",", ":")), ex=86400)

print(json.dumps({
    "trace_id": trace_id,
    "request_id": request_id,
    "correlation_evidence_ref": correlation_evidence_ref,
    "audit_feed_evidence_ref": audit_feed_evidence_ref,
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
    "correlation_evidence_ref": "request_id_audit_correlation",
    "audit_feed_evidence_ref": "request_id_audit_feed_visible",
    "coder_session_id": "$coderSessionId",
    "tester_session_id": "$testerSessionId",
    "coder_task_id": "$coderTaskId",
    "tester_task_id": "$testerTaskId",
}))
"@
  Set-Content -LiteralPath $localPy -Value $script
  try {
    scp -i $KeyPath -o StrictHostKeyChecking=no $localPy "${RemoteUser}@${StagingHost}:$remotePy" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Phase4 hosted request-contract negative-state parity verification failed: could not copy seed script" }
    $raw = ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingHost" "python3 $remotePy"
    if ($LASTEXITCODE -ne 0) { throw "Phase4 hosted request-contract negative-state parity verification failed: remote seed execution failed" }
    $jsonLine = @($raw -split "`r?`n" | Where-Object { $_.Trim() }) | Select-Object -Last 1
    return ($jsonLine | ConvertFrom-Json)
  } finally {
    if (Test-Path -LiteralPath $localPy) { Remove-Item -LiteralPath $localPy -Force }
    ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingHost" "rm -f $remotePy" | Out-Null
  }
}

function Wait-DualVisibility($baseUrl, $seed, $attempts = 20) {
  for ($i = 0; $i -lt $attempts; $i++) {
    $status = Invoke-JsonApi -url "$baseUrl/api/v1/agents/status" -method "GET" -contentType $null -timeoutSeconds 20
    $coder = @($status.agents) | Where-Object { $_.latest_task_id -eq $seed.coder_task_id } | Select-Object -First 1
    $tester = @($status.agents) | Where-Object { $_.latest_task_id -eq $seed.tester_task_id } | Select-Object -First 1
    if ($null -ne $coder -and $null -ne $tester) {
      return
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted request-contract negative-state parity verification failed: seeded paths not visible on agents/status"
}

function Get-SurfaceItems($path, $baseUrl, $seed) {
  switch ($path) {
    "/api/v1/agents/status" {
      $status = Invoke-JsonApi -url "$baseUrl/api/v1/agents/status" -method "GET" -contentType $null -timeoutSeconds 20
      return @(
        (@($status.agents) | Where-Object { $_.latest_task_id -eq $seed.coder_task_id } | Select-Object -First 1),
        (@($status.agents) | Where-Object { $_.latest_task_id -eq $seed.tester_task_id } | Select-Object -First 1)
      )
    }
    "/api/v1/agent-activity/recent" {
      $activity = Invoke-JsonApi -url "$baseUrl/api/v1/agent-activity/recent?trace_id=$($seed.trace_id)&limit=50" -method "GET" -contentType $null -timeoutSeconds 20
      return @(
        (@($activity.events) | Where-Object { $_.task_id -eq $seed.coder_task_id } | Select-Object -First 1),
        (@($activity.events) | Where-Object { $_.task_id -eq $seed.tester_task_id } | Select-Object -First 1)
      )
    }
    "/api/v1/tasks/recent" {
      $tasks = Invoke-JsonApi -url "$baseUrl/api/v1/tasks/recent?limit=100" -method "GET" -contentType $null -timeoutSeconds 20
      return @(
        (@($tasks.tasks) | Where-Object { $_.task_id -eq $seed.coder_task_id } | Select-Object -First 1),
        (@($tasks.tasks) | Where-Object { $_.task_id -eq $seed.tester_task_id } | Select-Object -First 1)
      )
    }
    "/api/v1/sessions/recent" {
      $sessions = Invoke-JsonApi -url "$baseUrl/api/v1/sessions/recent?limit=50" -method "GET" -contentType $null -timeoutSeconds 20
      return @(
        (@($sessions.sessions) | Where-Object { $_.session_id -eq $seed.coder_session_id } | Select-Object -First 1),
        (@($sessions.sessions) | Where-Object { $_.session_id -eq $seed.tester_session_id } | Select-Object -First 1)
      )
    }
    "/api/v1/sessions/{session_id}/history" {
      $coderHistory = Invoke-JsonApi -url "$baseUrl/api/v1/sessions/$($seed.coder_session_id)/history" -method "GET" -contentType $null -timeoutSeconds 20
      $testerHistory = Invoke-JsonApi -url "$baseUrl/api/v1/sessions/$($seed.tester_session_id)/history" -method "GET" -contentType $null -timeoutSeconds 20
      return @(
        (@($coderHistory.tasks) | Where-Object { $_.task_id -eq $seed.coder_task_id } | Select-Object -First 1),
        (@($testerHistory.tasks) | Where-Object { $_.task_id -eq $seed.tester_task_id } | Select-Object -First 1)
      )
    }
    "/api/v1/audit/recent" {
      $audit = Invoke-JsonApi -url "$baseUrl/api/v1/audit/recent?limit=100" -method "GET" -contentType $null -timeoutSeconds 20
      return @(
        (@($audit.events) | Where-Object { $_.details.task_id -eq $seed.coder_task_id } | Select-Object -First 1),
        (@($audit.events) | Where-Object { $_.details.task_id -eq $seed.tester_task_id } | Select-Object -First 1)
      )
    }
    "/api/v1/escalations/recent" {
      $escalations = Invoke-JsonApi -url "$baseUrl/api/v1/escalations/recent?limit=50" -method "GET" -contentType $null -timeoutSeconds 20
      return @(
        (@($escalations.events) | Where-Object { $_.details.task_id -eq $seed.coder_task_id } | Select-Object -First 1)
      )
    }
    default {
      throw "Phase4 hosted request-contract negative-state parity verification failed: unknown registry path $path"
    }
  }
}

$seed = Invoke-RemoteSeedNegativeStateParity
Wait-DualVisibility -baseUrl $BaseUrl -seed $seed

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/request/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "contract version" ($contract.contract_version -eq "request-id-correlation-v1")
$registry = @($contract.public_surface_registry)

$expected = @{
  "/api/v1/agents/status" = @("escalated", "abandoned_after_queue_drain")
  "/api/v1/agent-activity/recent" = @("escalated", "abandoned_after_queue_drain")
  "/api/v1/tasks/recent" = @("escalated", "abandoned_after_queue_drain")
  "/api/v1/sessions/recent" = @("escalated", "abandoned_after_queue_drain")
  "/api/v1/sessions/{session_id}/history" = @("escalated", "abandoned_after_queue_drain")
  "/api/v1/audit/recent" = @("escalated", "abandoned_after_queue_drain")
  "/api/v1/escalations/recent" = @("escalated")
}

foreach ($path in $expected.Keys) {
  $row = $registry | Where-Object { $_.path -eq $path } | Select-Object -First 1
  Assert-True "registry row visible $path" ($null -ne $row)
  $statuses = @($row.supported_statuses)
  Assert-True "supported statuses visible $path" ($statuses.Count -eq $expected[$path].Count)
  foreach ($status in $expected[$path]) {
    Assert-True "supported status $status for $path" ($statuses -contains $status)
  }
  $items = @(Get-SurfaceItems -path $path -baseUrl $BaseUrl -seed $seed)
  Assert-True "runtime item count $path" ($items.Count -eq $expected[$path].Count)
  foreach ($item in $items) {
    Assert-True "runtime item visible $path" ($null -ne $item)
    Assert-True "runtime request field visible $path" (($item.PSObject.Properties.Name -contains [string]$row.request_field))
    Assert-True "runtime trace field visible $path" (($item.PSObject.Properties.Name -contains [string]$row.trace_field))
    Assert-True "runtime correlation field visible $path" (($item.PSObject.Properties.Name -contains [string]$row.correlation_field))
    Assert-True "runtime audit field visible $path" (($item.PSObject.Properties.Name -contains [string]$row.audit_feed_field))
    Assert-True "runtime request parity $path" ($item.([string]$row.request_field) -eq $seed.request_id)
    Assert-True "runtime trace parity $path" ($item.([string]$row.trace_field) -eq $seed.trace_id)
    Assert-True "runtime correlation parity $path" ($item.([string]$row.correlation_field) -eq $seed.correlation_evidence_ref)
    Assert-True "runtime audit parity $path" ($item.([string]$row.audit_feed_field) -eq $seed.audit_feed_evidence_ref)
  }
}

Write-Host "[phase4-request-contract-negative-state-parity] base_url=$BaseUrl"
Write-Host "[phase4-request-contract-negative-state-parity] registered_paths=$($expected.Keys.Count)"
Write-Host "[phase4-request-contract-negative-state-parity] result=verified"

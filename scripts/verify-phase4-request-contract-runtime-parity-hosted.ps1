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
    throw "Phase4 hosted request-contract runtime parity verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-request-contract-runtime-parity-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted request-contract runtime parity verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

function Invoke-RemoteSeedRequestContractRuntimeParity() {
  $traceId = [Guid]::NewGuid().ToString()
  $requestId = "req-" + [Guid]::NewGuid().ToString("N")
  $projectId = [Guid]::NewGuid().ToString()
  $sessionId = [Guid]::NewGuid().ToString()
  $taskId = [Guid]::NewGuid().ToString()
  $localPy = Join-Path $env:TEMP ("phase4-request-contract-runtime-parity-seed-" + [Guid]::NewGuid().ToString("N") + ".py")
  $remotePy = "/tmp/phase4_request_contract_runtime_parity_seed.py"
  $script = @"
import json
import os
import subprocess

seed_code = r'''
from datetime import datetime, timedelta, timezone
import os
import psycopg
from psycopg.types.json import Json
import redis

project_id = "$projectId"
trace_id = "$traceId"
request_id = "$requestId"
correlation_evidence_ref = "request_id_audit_correlation"
audit_feed_evidence_ref = "request_id_audit_feed_visible"
session_id = "$sessionId"
task_id = "$taskId"
now = datetime.now(timezone.utc)
old = (now - timedelta(seconds=180)).isoformat()

task_payload = {
    "project_id": project_id,
    "session_id": session_id,
    "agent_type": "coder",
    "task_type": "hosted_request_contract_runtime_parity",
    "task_description": "hosted request contract runtime parity proof",
    "task_id": task_id,
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
    "error": "request_contract_runtime_parity_escalation",
    "result_envelope": None,
    "done_validation": None,
    "request_id": request_id,
    "correlation_evidence_ref": correlation_evidence_ref,
    "audit_feed_evidence_ref": audit_feed_evidence_ref,
}

audit_details = {
    "trace_id": trace_id,
    "request_id": request_id,
    "correlation_evidence_ref": correlation_evidence_ref,
    "audit_feed_evidence_ref": audit_feed_evidence_ref,
    "task_id": task_id,
    "agent_type": "coder",
    "status": "escalated",
    "retry_count": 1,
    "max_retries": 1,
    "error": "request_contract_runtime_parity_escalation",
}

with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO projects(id, name, owner_id, metadata)
            VALUES (%s, 'hosted-phase4-request-contract-runtime-parity', 'runtime-verifier', %s)
            ON CONFLICT (id) DO NOTHING
            """,
            (project_id, Json({"source": "verify-phase4-request-contract-runtime-parity-hosted"})),
        )
        cur.execute(
            """
            INSERT INTO agent_sessions(id, project_id, agent_list, metadata)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (id) DO UPDATE
            SET metadata = agent_sessions.metadata || EXCLUDED.metadata
            """,
            (
                session_id,
                project_id,
                ["planner", "coder", "tester", "devops"],
                Json({
                    "trace_id": trace_id,
                    "request_id": request_id,
                    "correlation_evidence_ref": correlation_evidence_ref,
                    "audit_feed_evidence_ref": audit_feed_evidence_ref,
                    "latest_task_id": task_id,
                    "latest_task_type": "hosted_request_contract_runtime_parity"
                }),
            ),
        )
        cur.execute(
            """
            INSERT INTO audit_log(event_type, user_id, session_id, details, severity, created_at)
            VALUES ('task_escalated', 'coder', %s, %s, 'warning', %s)
            """,
            (session_id, Json(audit_details), now),
        )

client = redis.Redis.from_url(os.environ["REDIS_URL"], decode_responses=True)
import json as _json
client.set("task:status:" + task_id, _json.dumps(task_payload, separators=(",", ":")), ex=86400)

print(_json.dumps({
    "trace_id": trace_id,
    "request_id": request_id,
    "correlation_evidence_ref": correlation_evidence_ref,
    "audit_feed_evidence_ref": audit_feed_evidence_ref,
    "session_id": session_id,
    "task_id": task_id,
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
    "session_id": "$sessionId",
    "task_id": "$taskId",
}))
"@
  Set-Content -LiteralPath $localPy -Value $script
  try {
    scp -i $KeyPath -o StrictHostKeyChecking=no $localPy "${RemoteUser}@${StagingHost}:$remotePy" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Phase4 hosted request-contract runtime parity verification failed: could not copy seed script" }
    $raw = ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingHost" "python3 $remotePy"
    if ($LASTEXITCODE -ne 0) { throw "Phase4 hosted request-contract runtime parity verification failed: remote seed execution failed" }
    $jsonLine = @($raw -split "`r?`n" | Where-Object { $_.Trim() }) | Select-Object -Last 1
    return ($jsonLine | ConvertFrom-Json)
  } finally {
    if (Test-Path -LiteralPath $localPy) { Remove-Item -LiteralPath $localPy -Force }
    ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingHost" "rm -f $remotePy" | Out-Null
  }
}

function Wait-SeedVisibility($baseUrl, $seed, $attempts = 20) {
  for ($i = 0; $i -lt $attempts; $i++) {
    $status = Invoke-JsonApi -url "$baseUrl/api/v1/agents/status" -method "GET" -contentType $null -timeoutSeconds 20
    $agent = @($status.agents) | Where-Object { $_.latest_task_id -eq $seed.task_id } | Select-Object -First 1
    if (
      $null -ne $agent -and
      $agent.latest_request_id -eq $seed.request_id -and
      $agent.latest_trace_id -eq $seed.trace_id
    ) {
      return $status
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted request-contract runtime parity verification failed: seeded task not visible on agents/status"
}

function Get-RegisteredSurfaceItem($path, $baseUrl, $seed) {
  switch ($path) {
    "/api/v1/agents/status" {
      $status = Invoke-JsonApi -url "$baseUrl/api/v1/agents/status" -method "GET" -contentType $null -timeoutSeconds 20
      return @($status.agents) | Where-Object { $_.latest_task_id -eq $seed.task_id } | Select-Object -First 1
    }
    "/api/v1/agent-activity/recent" {
      $activity = Invoke-JsonApi -url "$baseUrl/api/v1/agent-activity/recent?trace_id=$($seed.trace_id)&limit=50" -method "GET" -contentType $null -timeoutSeconds 20
      return @($activity.events) | Where-Object { $_.task_id -eq $seed.task_id } | Select-Object -First 1
    }
    "/api/v1/tasks/recent" {
      $tasks = Invoke-JsonApi -url "$baseUrl/api/v1/tasks/recent?limit=100" -method "GET" -contentType $null -timeoutSeconds 20
      return @($tasks.tasks) | Where-Object { $_.task_id -eq $seed.task_id } | Select-Object -First 1
    }
    "/api/v1/sessions/recent" {
      $sessions = Invoke-JsonApi -url "$baseUrl/api/v1/sessions/recent?limit=50" -method "GET" -contentType $null -timeoutSeconds 20
      return @($sessions.sessions) | Where-Object { $_.session_id -eq $seed.session_id } | Select-Object -First 1
    }
    "/api/v1/sessions/{session_id}/history" {
      $history = Invoke-JsonApi -url "$baseUrl/api/v1/sessions/$($seed.session_id)/history" -method "GET" -contentType $null -timeoutSeconds 20
      return @($history.tasks) | Where-Object { $_.task_id -eq $seed.task_id } | Select-Object -First 1
    }
    "/api/v1/audit/recent" {
      $audit = Invoke-JsonApi -url "$baseUrl/api/v1/audit/recent?limit=100" -method "GET" -contentType $null -timeoutSeconds 20
      return @($audit.events) | Where-Object { $_.details.task_id -eq $seed.task_id } | Select-Object -First 1
    }
    "/api/v1/escalations/recent" {
      $escalations = Invoke-JsonApi -url "$baseUrl/api/v1/escalations/recent?limit=50" -method "GET" -contentType $null -timeoutSeconds 20
      return @($escalations.events) | Where-Object { $_.details.task_id -eq $seed.task_id } | Select-Object -First 1
    }
    default {
      throw "Phase4 hosted request-contract runtime parity verification failed: unknown registry path $path"
    }
  }
}

$seed = Invoke-RemoteSeedRequestContractRuntimeParity
$null = Wait-SeedVisibility -baseUrl $BaseUrl -seed $seed

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/request/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "contract version" ($contract.contract_version -eq "request-id-correlation-v1")
Assert-True "public surface registry visible" ($null -ne $contract.public_surface_registry)

$registry = @($contract.public_surface_registry)
$expectedPaths = @(
  "/api/v1/agents/status",
  "/api/v1/agent-activity/recent",
  "/api/v1/tasks/recent",
  "/api/v1/sessions/recent",
  "/api/v1/sessions/{session_id}/history",
  "/api/v1/audit/recent",
  "/api/v1/escalations/recent"
)

foreach ($path in $expectedPaths) {
  $row = $registry | Where-Object { $_.path -eq $path } | Select-Object -First 1
  Assert-True "registry row visible $path" ($null -ne $row)
  $item = Get-RegisteredSurfaceItem -path $path -baseUrl $BaseUrl -seed $seed
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

$progress = Invoke-JsonApi -url "$BaseUrl/api/v1/project/progress" -method "GET" -contentType $null -timeoutSeconds 20
$phase4 = @($progress.horizontal.items) | Where-Object { $_.id -eq "phase_4" } | Select-Object -First 1
Assert-True "phase4 at least 51" ([int]$phase4.percent -ge 51)

Write-Host "[phase4-request-contract-runtime-parity] base_url=$BaseUrl"
Write-Host "[phase4-request-contract-runtime-parity] registered_paths=$($expectedPaths.Count)"
Write-Host "[phase4-request-contract-runtime-parity] result=verified"

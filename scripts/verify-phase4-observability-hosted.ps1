param(
  [string]$BaseUrl = $(if ($env:STAGING_BASE_URL) { $env:STAGING_BASE_URL } else { "" })
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


function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase4 hosted observability verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted observability verification failed: $label"
  }
}

function Invoke-Text($url) {
  $python = @'
import sys
import urllib.request

with urllib.request.urlopen(sys.argv[1], timeout=20) as response:
    sys.stdout.write(response.read().decode("utf-8", errors="replace"))
'@
  return ($python | py -3 - $url)
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
try:
    with urllib.request.urlopen(request, timeout=payload.get("timeoutSeconds", 30)) as response:
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
  $payloadFile = Join-Path $env:TEMP ("phase4-observability-response-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted observability verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") {
  throw "Phase4 hosted observability proof requires HTTPS"
}

$manifestPath = Join-Path $PSScriptRoot "..\docs\project-progress.manifest.json"
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$expectedOverallPercent = [int]$manifest.overall_percent

Write-Host "[phase4-hosted-observability] base url: $BaseUrl"

$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "frontend progress integrity panel" $frontendHtml "Progress Integrity"
Assert-Contains "frontend agent activity panel" $frontendHtml "Agent Activity"

$projectProgressIntegrity = Invoke-Text "$BaseUrl/api/v1/project/progress/integrity"
Assert-Contains "project progress integrity version" $projectProgressIntegrity '"contract_version":"project-progress-integrity-v1"'
Assert-Contains "project progress integrity verified" $projectProgressIntegrity '"status":"verified"'
Assert-Contains "project progress integrity evidence" $projectProgressIntegrity '"evidence_ref":"project_progress_integrity_runtime_proof"'
Assert-Contains "project progress integrity computed" $projectProgressIntegrity ('"computed_overall_percent":{0}' -f $expectedOverallPercent)
Assert-Contains "project progress integrity manifest" $projectProgressIntegrity ('"manifest_overall_percent":{0}' -f $expectedOverallPercent)

$agentActivityContract = Invoke-Text "$BaseUrl/api/v1/agent-activity/contract"
Assert-Contains "agent activity contract version" $agentActivityContract '"contract_version":"agent-activity-trace-v1"'
Assert-Contains "agent activity source filtered feed" $agentActivityContract "GET /api/v1/agent-activity/recent?limit=50"
Assert-Contains "agent activity source audit" $agentActivityContract "GET /api/v1/audit/recent?limit=50"
Assert-Contains "agent activity filtered evidence" $agentActivityContract "agent_activity_filtered_feed_visible"
Assert-Contains "agent activity no public langfuse" $agentActivityContract "no_public_langfuse_without_auth"

$agentActivityFeed = Invoke-Text "$BaseUrl/api/v1/agent-activity/recent?limit=20&severity=info"
Assert-Contains "agent activity feed contract" $agentActivityFeed '"contract_version":"agent-activity-trace-v1"'
Assert-Contains "agent activity feed mode" $agentActivityFeed '"mode":"audit_log_backed_filtered_feed"'
Assert-Contains "agent activity feed severity" $agentActivityFeed '"severity":"info"'
Assert-Contains "agent activity feed evidence" $agentActivityFeed "agent_activity_filtered_feed_visible"
Assert-Contains "agent activity role summaries" $agentActivityFeed "per_role_results"
Assert-Contains "agent activity aggregation evidence" $agentActivityFeed "agent_result_aggregation_complete"

$auditRecent = Invoke-Text "$BaseUrl/api/v1/audit/recent?limit=40"
Assert-Contains "audit recent task completed" $auditRecent "task_completed"
Assert-Contains "audit recent request id feed evidence" $auditRecent "request_id_audit_feed_visible"
Assert-Contains "audit recent mcp event" $auditRecent "mcp_tool_executed"

$metrics = Invoke-Text "$BaseUrl/api/v1/metrics"
Assert-Contains "metrics budget percentage" $metrics "superbrain_budget_spent_percentage"
Assert-Contains "metrics project progress" $metrics ("superbrain_project_progress_percent {0}" -f $expectedOverallPercent)
Assert-Contains "metrics rate limit capacity" $metrics "superbrain_prompt_rate_limit_capacity"
Assert-Contains "metrics rate limit remaining" $metrics "superbrain_prompt_rate_limit_remaining"
Assert-Contains "metrics rate limit used" $metrics "superbrain_prompt_rate_limit_used"
Assert-Contains "metrics session limit capacity" $metrics "superbrain_session_llm_call_limit"
Assert-Contains "metrics session limit remaining" $metrics "superbrain_session_llm_call_remaining"
Assert-Contains "metrics session limit used" $metrics "superbrain_session_llm_call_used"
Assert-Contains "metrics infra budget percentage" $metrics "superbrain_infra_budget_spent_percentage"
Assert-Contains "metrics infra budget projected" $metrics "superbrain_infra_budget_projected_cost_cents"
Assert-Contains "metrics external gates" $metrics "superbrain_external_gate_configured"
Assert-Contains "metrics queue depth" $metrics "superbrain_task_queue_depth"
Assert-Contains "metrics agent worker service" $metrics 'service="agent_worker"'
Assert-Contains "metrics memory worker service" $metrics 'service="memory_worker"'
Assert-Contains "metrics llm gateway service" $metrics 'service="llm_gateway"'
Assert-Contains "metrics audit counter" $metrics "superbrain_audit_events_total"
Assert-Contains "metrics mcp tool counter" $metrics "superbrain_mcp_tool_events_total"
Assert-Contains "metrics blocked counter" $metrics 'status="blocked"'
Assert-Contains "metrics timeout counter" $metrics 'status="timeout"'
Assert-Contains "metrics degraded counter" $metrics 'status="degraded"'
Assert-Contains "metrics memory consolidation counter" $metrics "superbrain_memory_consolidation_events_total"
Assert-Contains "metrics checkpoint tables" $metrics "superbrain_checkpoint_tables_total 4"

$progress = Invoke-JsonApi -url "$BaseUrl/api/v1/project/progress" -method "GET" -contentType $null -timeoutSeconds 15
Assert-True "project progress overall matches manifest" ([int]$progress.overall_percent -eq $expectedOverallPercent)

Write-Host "[phase4-hosted-observability] checks completed"

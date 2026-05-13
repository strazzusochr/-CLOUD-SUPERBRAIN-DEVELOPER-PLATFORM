param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted MCP audit-feed contract verification failed: $label"
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
try:
    with urllib.request.urlopen(request, timeout=payload.get("timeoutSeconds", 30)) as response:
        result = {"status_code": response.getcode(), "content": response.read().decode("utf-8", errors="replace")}
except urllib.error.HTTPError as error:
    result = {"status_code": error.code, "content": error.read().decode("utf-8", errors="replace")}
print(json.dumps(result))
'@
  $payloadFile = Join-Path $env:TEMP ("phase4-mcp-audit-feed-" + [Guid]::NewGuid().ToString("N") + ".json")
  try {
    Set-Content -LiteralPath $payloadFile -Value $payload -NoNewline
    $raw = $python | py -3 - $payloadFile
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
  }
  return ($raw | ConvertFrom-Json)
}

function Invoke-JsonApi($url, $method = "GET", $body = $null, $contentType = "application/json") {
  $response = Invoke-WebResponse -url $url -method $method -body $body -contentType $contentType
  if ([int]$response.status_code -ge 400) {
    throw "Phase4 hosted MCP audit-feed contract verification failed: $method $url returned HTTP $($response.status_code). Value: $($response.content)"
  }
  return ($response.content | ConvertFrom-Json)
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted MCP audit-feed proof requires HTTPS" }

Write-Host "[phase4-mcp-audit-feed-contract-runtime] base_url=$BaseUrl"

$contract = Invoke-JsonApi "$BaseUrl/api/v1/audit/mcp/contract"
Assert-True "contract version" ($contract.contract_version -eq "mcp-audit-feed-v1")

$sessionId = [guid]::NewGuid().ToString()
$traceId = "mcp-audit-feed-proof-" + ([guid]::NewGuid().ToString("N"))
$requestId = "req-mcp-audit-feed-" + ([guid]::NewGuid().ToString("N"))
$toolRequestId = "mcp-audit-feed-proof-" + ([guid]::NewGuid().ToString("N"))
$runId = "mcp-audit-feed-run-" + ([guid]::NewGuid().ToString("N"))

$eventBody = @{
  tool_request_id = $toolRequestId
  run_id = $runId
  session_id = $sessionId
  trace_id = $traceId
  request_id = $requestId
  agent_role = "devops"
  toolset = "github"
  capability = "plan_branch_pr"
  status = "blocked"
  error_class = "github_scope_violation"
  sanitized_summary = "Hosted MCP audit feed proof event"
  evidence_ref = "github_branch_pr_policy"
  result_ref = "mcp_audit_feed_contract_runtime_proof"
  duration_ms = 42
  retry_after_ms = 0
  audit_tags = @("hosted", "mcp-audit-feed", "contract")
} | ConvertTo-Json -Compress

$created = Invoke-JsonApi "$BaseUrl/internal/audit/mcp-tool-events" "POST" $eventBody
Assert-True "created event type" ($created.event_type -eq "mcp_tool_executed")

$runtime = Invoke-JsonApi "$BaseUrl/api/v1/audit/mcp?limit=20"
$match = $runtime.events | Where-Object { $_.details.tool_request_id -eq $toolRequestId } | Select-Object -First 1
Assert-True "mcp audit event visible" ($null -ne $match)
foreach ($field in $contract.top_level_fields) {
  Assert-True "event top-level field $field present" ($null -ne $match.$field)
}
foreach ($field in $contract.required_detail_fields) {
  Assert-True "event detail field $field present" ($null -ne $match.details.$field)
}
Assert-True "tool request id roundtrip" ($match.details.tool_request_id -eq $toolRequestId)
Assert-True "request id roundtrip" ($match.request_id -eq $requestId -and $match.details.request_id -eq $requestId)
Assert-True "trace id roundtrip" ($match.details.trace_id -eq $traceId)
Assert-True "session bound" ($match.details.session_bound -eq $true)
Assert-True "audit evidence ref" ($match.details.audit_evidence_ref -eq "mcp_tool_session_bound_audit")
Assert-True "request correlation ref" ($match.correlation_evidence_ref -eq "request_id_audit_correlation")
Assert-True "audit feed ref" ($match.audit_feed_evidence_ref -eq "request_id_audit_feed_visible")

Write-Host "[phase4-mcp-audit-feed-contract-runtime] result=verified"

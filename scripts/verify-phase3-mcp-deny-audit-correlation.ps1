param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase3 MCP deny audit correlation verification failed: $Label"
  }
}

function Invoke-JsonApi($Url, $Method = "GET", $Body = $null, $TimeoutSeconds = 30) {
  $headers = @{ "Accept" = "application/json" }
  if ($null -ne $Body) {
    return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers -ContentType "application/json" -Body $Body -TimeoutSec $TimeoutSeconds
  }
  return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers -TimeoutSec $TimeoutSeconds
}

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
  throw "BaseUrl is required"
}
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://" -and -not $AllowLocalhost) {
  throw "Phase3 MCP deny audit correlation proof requires HTTPS unless -AllowLocalhost is set"
}

Write-Host "[phase3-mcp-deny-audit-correlation] base_url=$BaseUrl"

$mcpContract = Invoke-JsonApi "$BaseUrl/mcp/api/v1/version-pinning/contract"
Assert-True "unsupported capability evidence listed" (@($mcpContract.evidence_refs) -contains "mcp_unsupported_capability_guard")
Assert-True "denied audit evidence listed" (@($mcpContract.evidence_refs) -contains "mcp_denied_tool_audit_correlation")

$auditContract = Invoke-JsonApi "$BaseUrl/api/v1/audit/mcp/contract"
Assert-True "audit contract top-level request_id" (@($auditContract.top_level_fields) -contains "request_id")
Assert-True "audit contract top-level correlation" (@($auditContract.top_level_fields) -contains "correlation_evidence_ref")
Assert-True "audit contract blocked denied correlation" (@($auditContract.blocked_detail_fields) -contains "denied_tool_correlation_evidence_ref")
Assert-True "audit contract evidence denied correlation" ($auditContract.evidence_refs.denied_tool_correlation -eq "mcp_denied_tool_audit_correlation")

$sessionId = [guid]::NewGuid().ToString()
$traceId = "mcp-deny-correlation-" + ([guid]::NewGuid().ToString("N"))
$requestId = "req-mcp-deny-" + ([guid]::NewGuid().ToString("N"))
$toolRequestId = "mcp-deny-" + ([guid]::NewGuid().ToString("N"))
$runId = "mcp-deny-run-" + ([guid]::NewGuid().ToString("N"))

$body = @{
  tool_request_id = $toolRequestId
  run_id = $runId
  session_id = $sessionId
  trace_id = $traceId
  request_id = $requestId
  agent_role = "devops"
  toolset = "github"
  capability = "delete_branch"
  intent_summary = "Verifier proves denied MCP capability audit correlation without live write."
  input_ref = (@{ branch = "main"; token_hint = "redaction-proof-value" } | ConvertTo-Json -Compress)
  allowed_scope = "feature/mcp-deny-correlation"
  timeout_ms = 1000
  retry_budget = 0
  idempotency_key = $toolRequestId
  audit_tags = @("phase3", "mcp-deny", "audit-correlation")
  redaction_required = $true
  expected_output_type = "blocked_tool_result"
} | ConvertTo-Json -Depth 6 -Compress

$result = Invoke-JsonApi "$BaseUrl/mcp/api/v1/tools/execute" "POST" $body
Assert-True "mcp result blocked" ($result.status -eq "blocked")
Assert-True "mcp result unsupported capability" ($result.error_class -eq "unsupported_capability")
Assert-True "mcp result evidence" ($result.evidence_ref -eq "mcp_unsupported_capability_guard")
Assert-True "mcp audit persisted" ($result.audit_persisted -eq $true)

Start-Sleep -Milliseconds 500

$mcpAudit = Invoke-JsonApi "$BaseUrl/api/v1/audit/mcp?limit=50"
$mcpMatch = @($mcpAudit.events) | Where-Object { $_.details.tool_request_id -eq $toolRequestId } | Select-Object -First 1
Assert-True "mcp audit match visible" ($null -ne $mcpMatch)
Assert-True "mcp audit request id" ($mcpMatch.request_id -eq $requestId)
Assert-True "mcp audit trace id" ($mcpMatch.trace_id -eq $traceId)
Assert-True "mcp audit correlation ref" ($mcpMatch.correlation_evidence_ref -eq "request_id_audit_correlation")
Assert-True "mcp audit feed ref" ($mcpMatch.audit_feed_evidence_ref -eq "request_id_audit_feed_visible")
Assert-True "mcp audit denied ref" ($mcpMatch.details.denied_tool_correlation_evidence_ref -eq "mcp_denied_tool_audit_correlation")
Assert-True "mcp audit status" ($mcpMatch.details.status -eq "blocked")
Assert-True "mcp audit redacted input absent" (-not (($mcpMatch | ConvertTo-Json -Depth 20) -like "*redaction-proof-value*"))

$recentAudit = Invoke-JsonApi "$BaseUrl/api/v1/audit/recent?limit=50"
$recentMatch = @($recentAudit.events) | Where-Object { $_.details.tool_request_id -eq $toolRequestId } | Select-Object -First 1
Assert-True "recent audit match visible" ($null -ne $recentMatch)
Assert-True "recent audit request id" ($recentMatch.request_id -eq $requestId)
Assert-True "recent audit trace id" ($recentMatch.trace_id -eq $traceId)
Assert-True "recent audit correlation ref" ($recentMatch.correlation_evidence_ref -eq "request_id_audit_correlation")

$activity = Invoke-JsonApi "$BaseUrl/api/v1/agent-activity/recent?limit=50&event_type=mcp_tool_executed&trace_id=$traceId"
$activityMatch = @($activity.events) | Where-Object { $_.details.tool_request_id -eq $toolRequestId } | Select-Object -First 1
Assert-True "agent activity match visible" ($null -ne $activityMatch)
Assert-True "agent activity request id" ($activityMatch.request_id -eq $requestId)
Assert-True "agent activity trace id" ($activityMatch.trace_id -eq $traceId)
Assert-True "agent activity correlation ref" ($activityMatch.correlation_evidence_ref -eq "request_id_audit_correlation")
Assert-True "agent activity feed ref" ($activityMatch.audit_feed_evidence_ref -eq "request_id_audit_feed_visible")

Write-Host "[phase3-mcp-deny-audit-correlation] ok"

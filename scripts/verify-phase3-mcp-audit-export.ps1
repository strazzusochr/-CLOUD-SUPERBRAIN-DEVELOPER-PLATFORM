param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [switch]$RequireSeed
)

$ErrorActionPreference = "Stop"

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Phase3 MCP audit export verification failed: $Label did not contain '$Expected'. Value: $text"
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase3 MCP audit export verification failed: $Label"
  }
}

function Invoke-Json($Url, $Method = "GET", $Body = $null, $TimeoutSeconds = 30) {
  $headers = @{ "Accept" = "application/json" }
  if ($null -ne $Body) {
    return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers -ContentType "application/json" -Body $Body -TimeoutSec $TimeoutSeconds
  }
  return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers -TimeoutSec $TimeoutSeconds
}

function Invoke-Text($Url) {
  return (Invoke-WebRequest -UseBasicParsing -Method GET -Uri $Url -TimeoutSec 30).Content
}

function Header-Value($Response, [string]$Name) {
  $value = $Response.Headers[$Name]
  if ($value -is [array]) { return [string]$value[0] }
  return [string]$value
}

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ((-not $AllowLocalhost) -and ($BaseUrl -match "localhost|127\.0\.0\.1|\[::1\]")) {
  throw "Phase3 MCP audit export proof refuses localhost unless -AllowLocalhost is set"
}

Write-Host "[phase3-mcp-audit-export] base_url=$BaseUrl"

$forbiddenPattern = "redaction-proof-value|sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Bearer [A-Za-z0-9_.-]{16,}|Cookie:|Set-Cookie:|eyJ[A-Za-z0-9_-]{10,}\.|private key"

$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "frontend mcp audit export panel" $frontendHtml "MCP Audit Export"
Assert-Contains "frontend mcp audit export version" $frontendHtml "mcp-audit-export-v1"
Assert-Contains "frontend mcp audit export evidence" $frontendHtml "mcp_audit_export_visible"
Assert-Contains "frontend mcp audit export audit evidence" $frontendHtml "mcp_audit_export_audit_persisted"
Assert-Contains "frontend mcp audit export no-live evidence" $frontendHtml "mcp_audit_no_live_write_guard"
Assert-Contains "frontend mcp audit export endpoint" $frontendHtml "GET /api/v1/audit/mcp/export"

$contract = Invoke-Json "$BaseUrl/api/v1/audit/mcp/export/contract"
Assert-True "contract version" ($contract.contract_version -eq "mcp-audit-export-v1")
Assert-True "parent contract" ($contract.parent_contract_version -eq "mcp-audit-feed-v1")
Assert-True "mode" ($contract.mode -eq "read_only_mcp_audit_csv_export")
Assert-True "endpoint" ($contract.endpoint -eq "GET /api/v1/audit/mcp/export?format=csv&limit=80")
Assert-True "contract endpoint" ($contract.contract_endpoint -eq "GET /api/v1/audit/mcp/export/contract")
Assert-True "csv supported" (@($contract.supported_formats) -contains "csv")
Assert-True "evidence" ($contract.evidence_ref -eq "mcp_audit_export_visible")
Assert-True "audit evidence" ($contract.export_audit_evidence_ref -eq "mcp_audit_export_audit_persisted")
Assert-True "redaction evidence" ($contract.redaction_evidence_ref -eq "mcp_audit_redaction_enforced")
Assert-True "no live write evidence" ($contract.no_live_mcp_write_evidence_ref -eq "mcp_audit_no_live_write_guard")
Assert-True "read only" ($contract.read_only -eq $true)
Assert-True "audit persisted" ($contract.audit_persisted -eq $true)
Assert-True "no live write claim" ($contract.live_mcp_writes_claimed -eq $false)
Assert-True "no input refs" ($contract.input_refs_returned -eq $false)
Assert-True "no provider credentials" ($contract.provider_credentials_returned -eq $false)
Assert-True "no raw details" ($contract.raw_details_returned -eq $false)

$expectedHeader = "sequence_index,event_id,created_at,event_type,severity,trace_id,request_id,session_id,agent_role,toolset,capability,status,error_class,duration_ms,retry_after_ms,session_bound,input_ref_stored,live_mcp_writes,evidence_ref,audit_feed_evidence_ref,correlation_evidence_ref,redaction_evidence_ref,no_live_mcp_write_evidence_ref"
Assert-True "contract columns" ((@($contract.columns) -join ",") -eq $expectedHeader)

$sessionId = [Guid]::NewGuid().ToString()
$traceId = "phase3-mcp-audit-export-" + [Guid]::NewGuid().ToString("N")
$requestId = "req-mcp-audit-export-" + [Guid]::NewGuid().ToString("N")
$toolRequestId = "mcp-export-" + [Guid]::NewGuid().ToString("N")
$runId = "mcp-export-run-" + [Guid]::NewGuid().ToString("N")
$exportTraceId = "mcp-audit-export-proof-" + [Guid]::NewGuid().ToString("N")
$exportRequestId = "req-mcp-audit-export-proof-" + [Guid]::NewGuid().ToString("N")

$body = @{
  tool_request_id = $toolRequestId
  run_id = $runId
  session_id = $sessionId
  trace_id = $traceId
  request_id = $requestId
  agent_role = "devops"
  toolset = "github"
  capability = "delete_branch"
  intent_summary = "Verifier proves MCP audit export redaction without live write."
  input_ref = (@{ branch = "main"; token_hint = "redaction-proof-value"; bearer = "Authorization: Bearer mcpsecret" } | ConvertTo-Json -Compress)
  allowed_scope = "feature/mcp-audit-export"
  timeout_ms = 1000
  retry_budget = 0
  idempotency_key = $toolRequestId
  audit_tags = @("phase3", "mcp-audit-export", "redaction")
  redaction_required = $true
  expected_output_type = "blocked_tool_result"
} | ConvertTo-Json -Depth 6 -Compress

$seed = Invoke-Json "$BaseUrl/mcp/api/v1/tools/execute" "POST" $body 45
Assert-True "mcp result blocked" ($seed.status -eq "blocked")
Assert-True "mcp result unsupported capability" ($seed.error_class -eq "unsupported_capability")
Assert-True "mcp audit persisted" ($seed.audit_persisted -eq $true)
Assert-True "mcp result no forbidden leak" (-not (($seed | ConvertTo-Json -Depth 20) -match $forbiddenPattern))

Start-Sleep -Milliseconds 500

$exportResponse = Invoke-WebRequest -UseBasicParsing -Method GET -Uri "$BaseUrl/api/v1/audit/mcp/export?format=csv&limit=80&trace_id=$exportTraceId&request_id=$exportRequestId" -TimeoutSec 30
Assert-True "export status" ([int]$exportResponse.StatusCode -eq 200)
Assert-Contains "content type csv" (Header-Value $exportResponse "Content-Type") "text/csv"
Assert-Contains "content disposition filename" (Header-Value $exportResponse "Content-Disposition") "superbrain-mcp-audit.csv"
Assert-True "header contract version" ((Header-Value $exportResponse "X-Contract-Version") -eq "mcp-audit-export-v1")
Assert-True "header evidence" ((Header-Value $exportResponse "X-Evidence-Ref") -eq "mcp_audit_export_visible")
Assert-True "header audit evidence" ((Header-Value $exportResponse "X-Export-Audit-Evidence-Ref") -eq "mcp_audit_export_audit_persisted")
Assert-True "header redaction evidence" ((Header-Value $exportResponse "X-Redaction-Evidence-Ref") -eq "mcp_audit_redaction_enforced")
Assert-True "header no live write evidence" ((Header-Value $exportResponse "X-No-Live-Mcp-Write-Evidence-Ref") -eq "mcp_audit_no_live_write_guard")
Assert-True "header trace" ((Header-Value $exportResponse "X-Trace-Id") -eq $exportTraceId)
Assert-True "header request" ((Header-Value $exportResponse "X-Request-Id") -eq $exportRequestId)

$csv = [string]$exportResponse.Content
Assert-Contains "csv header" $csv $expectedHeader
Assert-Contains "csv trace visible" $csv $traceId
Assert-Contains "csv request visible" $csv $requestId
Assert-Contains "csv toolset visible" $csv "github"
Assert-Contains "csv capability visible" $csv "delete_branch"
Assert-Contains "csv status visible" $csv "blocked"
Assert-Contains "csv evidence visible" $csv "mcp_audit_export_visible"
Assert-Contains "csv redaction visible" $csv "mcp_audit_redaction_enforced"
Assert-Contains "csv no live write visible" $csv "mcp_audit_no_live_write_guard"
Assert-True "csv no forbidden pattern leak" (-not ($csv -match $forbiddenPattern))

$feed = Invoke-Text "$BaseUrl/api/v1/audit/mcp?limit=80"
Assert-Contains "feed trace visible" $feed $traceId
Assert-Contains "feed redaction evidence" $feed "mcp_audit_redaction_enforced"
Assert-True "feed no forbidden pattern leak" (-not ($feed -match $forbiddenPattern))

$snapshot = Invoke-Text "$BaseUrl/api/v1/audit/mcp/snapshot?limit=80"
Assert-Contains "snapshot redaction clear" $snapshot '"redaction_status":"clear"'
Assert-True "snapshot no forbidden pattern leak" (-not ($snapshot -match $forbiddenPattern))

$recentAudit = Invoke-Json "$BaseUrl/api/v1/audit/recent?limit=100"
$exportAudit = @($recentAudit.events) | Where-Object {
  $_.event_type -eq "mcp_audit_export_generated" -and
  $_.details.trace_id -eq $exportTraceId -and
  $_.details.request_id -eq $exportRequestId
} | Select-Object -First 1
Assert-True "export audit persisted" ($null -ne $exportAudit)
Assert-True "export audit evidence" ($exportAudit.details.evidence_ref -eq "mcp_audit_export_audit_persisted")
Assert-True "export audit redaction" ($exportAudit.details.redaction_evidence_ref -eq "mcp_audit_redaction_enforced")
Assert-True "export audit no-live write" ($exportAudit.details.no_live_mcp_write_evidence_ref -eq "mcp_audit_no_live_write_guard")
Assert-True "export audit no forbidden pattern leak" (-not (($exportAudit | ConvertTo-Json -Depth 20) -match $forbiddenPattern))

Write-Host "[phase3-mcp-audit-export] status=verified"
Write-Host "contract_version=mcp-audit-export-v1"
Write-Host "evidence_ref=mcp_audit_export_visible"
Write-Host "audit_evidence_ref=mcp_audit_export_audit_persisted"

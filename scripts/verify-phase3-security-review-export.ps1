param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [switch]$RequireSeed
)

$ErrorActionPreference = "Stop"

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Phase3 security review export verification failed: $Label did not contain '$Expected'. Value: $text"
  }
}

function Assert-NotContains($Label, $Value, $Unexpected) {
  $text = ($Value | Out-String)
  if ($text.Contains($Unexpected)) {
    throw "Phase3 security review export verification failed: $Label contained '$Unexpected'. Value: $text"
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase3 security review export verification failed: $Label"
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
  throw "Phase3 security review export proof refuses localhost unless -AllowLocalhost is set"
}

Write-Host "[phase3-security-review-export] base_url=$BaseUrl"

if ($RequireSeed) {
  $queueVerifier = Join-Path $PSScriptRoot "verify-phase3-security-review-queue.ps1"
  if ($BaseUrl -match "localhost|127\.0\.0\.1|\[::1\]") {
    & $queueVerifier -BaseUrl $BaseUrl -AllowLocalhost
  } else {
    & $queueVerifier -BaseUrl $BaseUrl
  }
}

$forbiddenPattern = "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Bearer [A-Za-z0-9_.-]{16,}|Cookie:|Set-Cookie:|prompt_body|raw_file_contents|BEGIN PRIVATE KEY|private key"
$queueForbiddenPattern = "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Bearer [A-Za-z0-9_.-]{16,}|Cookie:|Set-Cookie:|BEGIN PRIVATE KEY|private key"
$expectedHeader = "sequence_index,queue_item_id,source_event_id,created_at,event_type,category,severity,status,risk_badge,request_id,trace_id,summary,redaction_applied,detail_keys,evidence_ref,item_evidence_ref,redaction_evidence_ref,filter_evidence_ref,decision_history_evidence_ref,source_security_surface_evidence_ref"

$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "frontend security review export panel" $frontendHtml "Security Review Export"
Assert-Contains "frontend security review export version" $frontendHtml "security-review-queue-export-v1"
Assert-Contains "frontend security review export evidence" $frontendHtml "security_review_queue_export_visible"
Assert-Contains "frontend security review export audit evidence" $frontendHtml "security_review_queue_export_audit_persisted"
Assert-Contains "frontend security review export endpoint" $frontendHtml "GET /api/v1/security/review-queue/export"

$parentContract = Invoke-Json "$BaseUrl/api/v1/security/review-queue/contract"
Assert-True "parent export endpoint" ($parentContract.export_endpoint -eq "GET /api/v1/security/review-queue/export?format=csv&limit=80")
Assert-True "parent export contract endpoint" ($parentContract.export_contract_endpoint -eq "GET /api/v1/security/review-queue/export/contract")
Assert-True "parent export contract version" ($parentContract.export_contract_version -eq "security-review-queue-export-v1")
Assert-True "parent csv support" (@($parentContract.supported_export_formats) -contains "csv")
Assert-True "parent export evidence" ($parentContract.evidence_refs.export_visible -eq "security_review_queue_export_visible")
Assert-True "parent export audit evidence" ($parentContract.evidence_refs.export_audit_persisted -eq "security_review_queue_export_audit_persisted")
Assert-True "parent export columns" ((@($parentContract.export_columns) -join ",") -eq $expectedHeader)
Assert-True "parent audit persisted" ($parentContract.audit_persisted -eq $true)

$contract = Invoke-Json "$BaseUrl/api/v1/security/review-queue/export/contract"
Assert-True "contract version" ($contract.contract_version -eq "security-review-queue-export-v1")
Assert-True "parent contract" ($contract.parent_contract_version -eq "security-review-queue-v1")
Assert-True "mode" ($contract.mode -eq "read_only_security_review_queue_csv_export")
Assert-True "endpoint" ($contract.endpoint -eq "GET /api/v1/security/review-queue/export?format=csv&limit=80")
Assert-True "contract endpoint" ($contract.contract_endpoint -eq "GET /api/v1/security/review-queue/export/contract")
Assert-True "source table" ($contract.source_table -eq "audit_log")
Assert-True "filename" ($contract.filename_pattern -eq "superbrain-security-review-queue.csv")
Assert-True "columns" ((@($contract.columns) -join ",") -eq $expectedHeader)
Assert-True "evidence" ($contract.evidence_ref -eq "security_review_queue_export_visible")
Assert-True "audit evidence" ($contract.export_audit_evidence_ref -eq "security_review_queue_export_audit_persisted")
Assert-True "redaction evidence" ($contract.redaction_evidence_ref -eq "security_review_redaction_enforced")
Assert-True "mutation evidence" ($contract.mutation_block_evidence_ref -eq "security_review_mutation_blocked")
Assert-True "read only" ($contract.read_only -eq $true)
Assert-True "audit persisted" ($contract.audit_persisted -eq $true)
Assert-True "no live provider" ($contract.live_provider_calls_claimed -eq $false)
Assert-True "no live mcp writes" ($contract.live_mcp_writes_claimed -eq $false)
Assert-True "no production rollout" ($contract.production_rollout_claimed -eq $false)
Assert-True "no promotion" ($contract.promotion_allowed -eq $false)
Assert-True "no prompt bodies" ($contract.prompt_bodies_returned -eq $false)
Assert-True "no raw details" ($contract.raw_details_returned -eq $false)

$suffix = [Guid]::NewGuid().ToString("N")
$redactionSecret = ("sk" + "-proj-securityreviewexport") + $suffix
$cspRequestId = "security-review-export-csp-$suffix"
$cspTraceId = "trace-security-review-export-csp-$suffix"
$cspBody = @{
  request_id = $cspRequestId
  trace_id = $cspTraceId
  user_agent = "phase3-security-review-export-verifier"
  report = @{
    "document-uri" = "$BaseUrl/"
    "blocked-uri" = "https://blocked.example.invalid/security-review-export.js"
    "violated-directive" = "script-src"
    "effective-directive" = "script-src"
    "original-policy" = "default-src self; proof=$redactionSecret; verifier_session=$suffix"
  }
} | ConvertTo-Json -Compress -Depth 8
$cspResult = Invoke-Json "$BaseUrl/api/v1/security/csp/report" "POST" $cspBody
Assert-True "csp accepted" ($cspResult.status -eq "accepted")
Assert-True "csp audit persisted" ($cspResult.audit_persisted -eq $true)

Start-Sleep -Milliseconds 700

$queue = Invoke-Text "$BaseUrl/api/v1/security/review-queue?limit=80"
Assert-Contains "queue request visible" $queue $cspRequestId
Assert-Contains "queue trace visible" $queue $cspTraceId
Assert-Contains "queue redaction evidence" $queue "security_review_redaction_enforced"
Assert-True "queue no forbidden leak" (-not ($queue -match $queueForbiddenPattern))
Assert-NotContains "queue raw secret absent" $queue $redactionSecret

$exportTraceId = "security-review-export-proof-" + [Guid]::NewGuid().ToString("N")
$exportRequestId = "req-security-review-export-" + [Guid]::NewGuid().ToString("N")
$exportResponse = Invoke-WebRequest -UseBasicParsing -Method GET -Uri "$BaseUrl/api/v1/security/review-queue/export?format=csv&limit=80&trace_id=$exportTraceId&request_id=$exportRequestId" -TimeoutSec 30
Assert-True "export status" ([int]$exportResponse.StatusCode -eq 200)
Assert-Contains "content type csv" (Header-Value $exportResponse "Content-Type") "text/csv"
Assert-Contains "content disposition filename" (Header-Value $exportResponse "Content-Disposition") "superbrain-security-review-queue.csv"
Assert-True "header contract version" ((Header-Value $exportResponse "X-Contract-Version") -eq "security-review-queue-export-v1")
Assert-True "header evidence" ((Header-Value $exportResponse "X-Evidence-Ref") -eq "security_review_queue_export_visible")
Assert-True "header audit evidence" ((Header-Value $exportResponse "X-Export-Audit-Evidence-Ref") -eq "security_review_queue_export_audit_persisted")
Assert-True "header redaction evidence" ((Header-Value $exportResponse "X-Redaction-Evidence-Ref") -eq "security_review_redaction_enforced")
Assert-True "header mutation evidence" ((Header-Value $exportResponse "X-Mutation-Block-Evidence-Ref") -eq "security_review_mutation_blocked")
Assert-True "header trace" ((Header-Value $exportResponse "X-Trace-Id") -eq $exportTraceId)
Assert-True "header request" ((Header-Value $exportResponse "X-Request-Id") -eq $exportRequestId)

$csv = [string]$exportResponse.Content
Assert-Contains "csv header" $csv $expectedHeader
Assert-Contains "csv request visible" $csv $cspRequestId
Assert-Contains "csv trace visible" $csv $cspTraceId
Assert-Contains "csv export evidence" $csv "security_review_queue_export_visible"
Assert-Contains "csv item evidence" $csv "security_review_item_visible"
Assert-Contains "csv redaction evidence" $csv "security_review_redaction_enforced"
Assert-Contains "csv source evidence" $csv "security_audit_surface_visible"
Assert-True "csv no forbidden pattern leak" (-not ($csv -match $forbiddenPattern))
Assert-NotContains "csv raw secret absent" $csv $redactionSecret

$recentAudit = Invoke-Json "$BaseUrl/api/v1/audit/recent?limit=100"
$exportAudit = @($recentAudit.events) | Where-Object {
  $_.event_type -eq "security_review_queue_export_generated" -and
  $_.details.trace_id -eq $exportTraceId -and
  $_.details.request_id -eq $exportRequestId
} | Select-Object -First 1
Assert-True "export audit persisted" ($null -ne $exportAudit)
Assert-True "export audit evidence" ($exportAudit.details.evidence_ref -eq "security_review_queue_export_audit_persisted")
Assert-True "export audit redaction" ($exportAudit.details.redaction_evidence_ref -eq "security_review_redaction_enforced")
Assert-True "export audit no rollout" ($exportAudit.details.production_rollout_claimed -eq $false)
Assert-True "export audit no forbidden pattern leak" (-not (($exportAudit | ConvertTo-Json -Depth 20) -match $forbiddenPattern))

Write-Host "[phase3-security-review-export] status=verified"
Write-Host "contract_version=security-review-queue-export-v1"
Write-Host "evidence_ref=security_review_queue_export_visible"
Write-Host "audit_evidence_ref=security_review_queue_export_audit_persisted"

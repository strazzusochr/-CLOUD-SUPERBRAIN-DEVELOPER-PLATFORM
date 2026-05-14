param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [switch]$AllowLocalhost,
  [switch]$RequireFullCorrelation
)

$ErrorActionPreference = "Stop"

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase3 gateway correlation export verification failed: $Label"
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $Text = ($Value | Out-String)
  if (-not $Text.Contains($Expected)) {
    throw "Phase3 gateway correlation export verification failed: $Label did not contain '$Expected'. Value: $Text"
  }
}

function Invoke-Text($Url) {
  return (Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 60).Content
}

function Invoke-JsonApi($Url) {
  return Invoke-RestMethod -Method Get -Uri $Url -Headers @{ Accept = "application/json" } -TimeoutSec 30
}

function Header-Value($Response, [string]$Name) {
  $value = $Response.Headers[$Name]
  if ($value -is [array]) {
    return [string]$value[0]
  }
  return [string]$value
}

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
  throw "BaseUrl is required"
}
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://" -and -not $AllowLocalhost) {
  throw "Phase3 gateway correlation export proof requires HTTPS unless -AllowLocalhost is set"
}

Write-Host "[phase3-gateway-correlation-export] base_url=$BaseUrl"

if ($RequireFullCorrelation) {
  $snapshotArgs = @{ BaseUrl = $BaseUrl }
  if ($AllowLocalhost) {
    $snapshotArgs["AllowLocalhost"] = $true
  }
  & "$PSScriptRoot\verify-phase3-gateway-correlation-snapshot.ps1" @snapshotArgs
}

$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "frontend export panel" $frontendHtml "Gateway Correlation Export"
Assert-Contains "frontend export contract marker" $frontendHtml "gateway-correlation-export-v1"
Assert-Contains "frontend export evidence marker" $frontendHtml "gateway_correlation_export_visible"
Assert-Contains "frontend export audit marker" $frontendHtml "gateway_correlation_export_audit_persisted"
Assert-Contains "frontend export redaction marker" $frontendHtml "gateway_correlation_redaction_enforced"
Assert-Contains "frontend export no live write marker" $frontendHtml "gateway_correlation_no_live_write_guard"
Assert-Contains "frontend export endpoint marker" $frontendHtml "GET /api/v1/security/gateway-correlation/export"

$contract = Invoke-JsonApi "$BaseUrl/api/v1/security/gateway-correlation/contract"
Assert-True "parent contract version" ($contract.contract_version -eq "gateway-correlation-snapshot-v1")
Assert-True "export contract version visible" ($contract.export_contract_version -eq "gateway-correlation-export-v1")
Assert-True "export endpoint visible" ($contract.export_endpoint -eq "GET /api/v1/security/gateway-correlation/export?format=csv&limit=80")
Assert-True "export contract endpoint visible" ($contract.export_contract_endpoint -eq "GET /api/v1/security/gateway-correlation/export/contract")
Assert-True "contract export evidence" ($contract.export_evidence_ref -eq "gateway_correlation_export_visible")
Assert-True "contract export audit evidence" ($contract.export_audit_evidence_ref -eq "gateway_correlation_export_audit_persisted")
Assert-True "contract read-only" ($contract.read_only -eq $true)
Assert-True "contract no live provider" ($contract.live_provider_calls_claimed -eq $false)
Assert-True "contract no live mcp" ($contract.live_mcp_writes_claimed -eq $false)
Assert-True "contract export columns" (@($contract.export_columns | Where-Object { $_ -eq "correlation_key" }).Count -eq 1)

$exportContract = Invoke-JsonApi "$BaseUrl/api/v1/security/gateway-correlation/export/contract"
Assert-True "export version" ($exportContract.contract_version -eq "gateway-correlation-export-v1")
Assert-True "export parent version" ($exportContract.parent_contract_version -eq "gateway-correlation-snapshot-v1")
Assert-True "export mode" ($exportContract.mode -eq "read_only_gateway_correlation_csv_export")
Assert-True "export endpoint" ($exportContract.endpoint -eq "GET /api/v1/security/gateway-correlation/export?format=csv&limit=80")
Assert-True "export contract endpoint" ($exportContract.contract_endpoint -eq "GET /api/v1/security/gateway-correlation/export/contract")
Assert-True "export evidence" ($exportContract.evidence_ref -eq "gateway_correlation_export_visible")
Assert-True "export audit evidence" ($exportContract.export_audit_evidence_ref -eq "gateway_correlation_export_audit_persisted")
Assert-True "export redaction evidence" ($exportContract.redaction_evidence_ref -eq "gateway_correlation_redaction_enforced")
Assert-True "export no-live-write evidence" ($exportContract.no_live_write_evidence_ref -eq "gateway_correlation_no_live_write_guard")
Assert-True "export read-only" ($exportContract.read_only -eq $true)
Assert-True "export audit persisted" ($exportContract.audit_persisted -eq $true)
Assert-True "export no production rollout" ($exportContract.production_rollout_claimed -eq $false)
Assert-True "export promotion blocked" ($exportContract.promotion_allowed -eq $false)
Assert-True "export prompt bodies absent" ($exportContract.prompt_bodies_returned -eq $false)
Assert-True "export input refs absent" ($exportContract.tool_input_refs_returned -eq $false)
Assert-True "export credentials absent" ($exportContract.provider_credentials_returned -eq $false)

$snapshot = Invoke-JsonApi "$BaseUrl/api/v1/security/gateway-correlation/snapshot?limit=80"
if ($RequireFullCorrelation) {
  Assert-True "snapshot full correlation present" ([int]$snapshot.full_correlation_count -ge 1)
}

$exportTraceId = "gateway-correlation-export-proof-" + [Guid]::NewGuid().ToString("N")
$exportRequestId = "req-gateway-correlation-export-" + [Guid]::NewGuid().ToString("N")
$exportResponse = Invoke-WebRequest -Method GET -Uri "$BaseUrl/api/v1/security/gateway-correlation/export?format=csv&limit=80&trace_id=$exportTraceId&request_id=$exportRequestId" -TimeoutSec 30
$csv = [string]$exportResponse.Content

Assert-True "header contract version" ((Header-Value $exportResponse "X-Contract-Version") -eq "gateway-correlation-export-v1")
Assert-True "header evidence" ((Header-Value $exportResponse "X-Evidence-Ref") -eq "gateway_correlation_export_visible")
Assert-True "header audit evidence" ((Header-Value $exportResponse "X-Export-Audit-Evidence-Ref") -eq "gateway_correlation_export_audit_persisted")
Assert-True "header redaction evidence" ((Header-Value $exportResponse "X-Redaction-Evidence-Ref") -eq "gateway_correlation_redaction_enforced")
Assert-True "header trace id" ((Header-Value $exportResponse "X-Trace-Id") -eq $exportTraceId)
Assert-True "header request id" ((Header-Value $exportResponse "X-Request-Id") -eq $exportRequestId)

Assert-Contains "csv header correlation key" $csv "sequence_index,correlation_key,trace_id,request_id,session_id,correlation_state"
Assert-Contains "csv export evidence" $csv "gateway_correlation_export_visible"
Assert-Contains "csv export audit evidence" $csv "gateway_correlation_export_audit_persisted"
Assert-Contains "csv redaction evidence" $csv "gateway_correlation_redaction_enforced"
Assert-Contains "csv no-live-write evidence" $csv "gateway_correlation_no_live_write_guard"
Assert-True "csv no prompt leak" (-not $csv.Contains("prompt_body"))
Assert-True "csv no input ref leak" (-not $csv.Contains("redaction-proof-value"))
Assert-True "csv no secret pattern leak" (-not ($csv -match "sk-proj-|github_pat_|ghp_|vck_|cfat_|hcloud_|hf_|glpat-"))

$recentAudit = Invoke-JsonApi "$BaseUrl/api/v1/audit/recent?limit=80"
$auditRecord = @($recentAudit.events) | Where-Object {
  $_.event_type -eq "gateway_correlation_export_generated" -and
  $_.details.trace_id -eq $exportTraceId -and
  $_.details.request_id -eq $exportRequestId
} | Select-Object -First 1
Assert-True "export audit persisted" ($null -ne $auditRecord)
Assert-True "export audit evidence" ($auditRecord.details.evidence_ref -eq "gateway_correlation_export_audit_persisted")
Assert-True "export audit visible evidence" ($auditRecord.details.export_evidence_ref -eq "gateway_correlation_export_visible")
Assert-True "export audit redaction" ($auditRecord.details.redaction_evidence_ref -eq "gateway_correlation_redaction_enforced")
Assert-True "export audit no-live-write" ($auditRecord.details.no_live_write_evidence_ref -eq "gateway_correlation_no_live_write_guard")
Assert-True "export audit no forbidden leak" (-not (($auditRecord | ConvertTo-Json -Depth 20 -Compress) -match "sk-proj-|github_pat_|ghp_|vck_|cfat_|hcloud_|hf_|glpat-|redaction-proof-value"))

Write-Host "[phase3-gateway-correlation-export] status=verified"
Write-Host "contract_version=gateway-correlation-export-v1"
Write-Host "evidence_ref=gateway_correlation_export_visible"
Write-Host "audit_evidence_ref=gateway_correlation_export_audit_persisted"

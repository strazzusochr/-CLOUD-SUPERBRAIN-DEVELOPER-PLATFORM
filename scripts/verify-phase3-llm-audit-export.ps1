param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [switch]$RequireSeed
)

$ErrorActionPreference = "Stop"

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Phase3 LLM audit export verification failed: $Label did not contain '$Expected'. Value: $text"
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase3 LLM audit export verification failed: $Label"
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
  throw "Phase3 LLM audit export proof refuses localhost unless -AllowLocalhost is set"
}

Write-Host "[phase3-llm-audit-export] base_url=$BaseUrl"

$forbiddenPattern = "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Bearer [A-Za-z0-9_.-]{16,}|Cookie:|Set-Cookie:|eyJ[A-Za-z0-9_-]{10,}\.|private key"

$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "frontend llm audit export panel" $frontendHtml "LLM Audit Export"
Assert-Contains "frontend llm audit export version" $frontendHtml "llm-audit-export-v1"
Assert-Contains "frontend llm audit export evidence" $frontendHtml "llm_audit_export_visible"
Assert-Contains "frontend llm audit export audit evidence" $frontendHtml "llm_audit_export_audit_persisted"
Assert-Contains "frontend llm audit export no-live evidence" $frontendHtml "llm_audit_no_live_provider_guard"
Assert-Contains "frontend llm audit export endpoint" $frontendHtml "GET /api/v1/audit/llm/export"

$contract = Invoke-Json "$BaseUrl/api/v1/audit/llm/export/contract"
Assert-True "contract version" ($contract.contract_version -eq "llm-audit-export-v1")
Assert-True "parent contract" ($contract.parent_contract_version -eq "llm-audit-feed-v1")
Assert-True "mode" ($contract.mode -eq "read_only_llm_audit_csv_export")
Assert-True "endpoint" ($contract.endpoint -eq "GET /api/v1/audit/llm/export?format=csv&limit=80")
Assert-True "contract endpoint" ($contract.contract_endpoint -eq "GET /api/v1/audit/llm/export/contract")
Assert-True "csv supported" (@($contract.supported_formats) -contains "csv")
Assert-True "evidence" ($contract.evidence_ref -eq "llm_audit_export_visible")
Assert-True "audit evidence" ($contract.export_audit_evidence_ref -eq "llm_audit_export_audit_persisted")
Assert-True "redaction evidence" ($contract.redaction_evidence_ref -eq "llm_audit_redaction_enforced")
Assert-True "no live provider evidence" ($contract.no_live_provider_evidence_ref -eq "llm_audit_no_live_provider_guard")
Assert-True "read only" ($contract.read_only -eq $true)
Assert-True "audit persisted" ($contract.audit_persisted -eq $true)
Assert-True "no live provider claim" ($contract.live_provider_calls_claimed -eq $false)
Assert-True "no prompt bodies" ($contract.prompt_bodies_returned -eq $false)
Assert-True "no provider credentials" ($contract.provider_credentials_returned -eq $false)
Assert-True "no raw details" ($contract.raw_details_returned -eq $false)

$expectedHeader = "sequence_index,event_id,created_at,event_type,severity,trace_id,model_name,provider_name,agent_type,status,input_tokens,output_tokens,cost_cents,live_provider_calls,prompt_body_stored,evidence_ref,audit_feed_evidence_ref,redaction_evidence_ref,no_live_provider_evidence_ref"
Assert-True "contract columns" ((@($contract.columns) -join ",") -eq $expectedHeader)

$traceId = "phase3-llm-audit-export-" + [Guid]::NewGuid().ToString("N")
$exportTraceId = "llm-audit-export-proof-" + [Guid]::NewGuid().ToString("N")
$exportRequestId = "req-llm-audit-export-" + [Guid]::NewGuid().ToString("N")
$secretProbe = ("sk" + "-proj-llmexport") + [Guid]::NewGuid().ToString("N")
$canaryParts = @(
  $secretProbe,
  ("gh" + "p_" + "exportcanary123456789"),
  ("github" + "_pat_" + "exportcanary_1234567890"),
  ("vc" + "k_" + "exportcanary_12345678901234567890"),
  ("cf" + "at_" + "exportcanary_12345678901234567890"),
  ("hcloud" + "_" + "exportcanary_12345678"),
  ("h" + "f_" + "exportcanary_12345678901234567890"),
  ("gl" + "pat-" + "exportcanary-1234567890"),
  ("Authorization: " + "Bearer exportsecret"),
  ("Cookie: " + "exportcookie"),
  ("ey" + "Jexport.header.payload")
)
$canary = $canaryParts -join " "

$body = @{
  model = "deepseek-ai/DeepSeek-V4-Flash:fastest"
  messages = @(@{ role = "user"; content = "phase3 llm audit export proof $canary" })
  stream = $false
  metadata = @{
    trace_id = $traceId
    agent_type = "tester"
  }
} | ConvertTo-Json -Compress -Depth 8

$seed = Invoke-Json "$BaseUrl/llm/v1/chat/completions" "POST" $body 45
Assert-True "llm dry-run id" (-not [string]::IsNullOrWhiteSpace([string]$seed.id))
Assert-True "llm dry-run no live call" ($seed.live_provider_calls -eq $false)
Assert-True "llm dry-run audit persisted" ($seed.audit_persisted -eq $true)

Start-Sleep -Milliseconds 500

$exportResponse = Invoke-WebRequest -UseBasicParsing -Method GET -Uri "$BaseUrl/api/v1/audit/llm/export?format=csv&limit=80&trace_id=$exportTraceId&request_id=$exportRequestId" -TimeoutSec 30
Assert-True "export status" ([int]$exportResponse.StatusCode -eq 200)
Assert-Contains "content type csv" (Header-Value $exportResponse "Content-Type") "text/csv"
Assert-Contains "content disposition filename" (Header-Value $exportResponse "Content-Disposition") "superbrain-llm-audit.csv"
Assert-True "header contract version" ((Header-Value $exportResponse "X-Contract-Version") -eq "llm-audit-export-v1")
Assert-True "header evidence" ((Header-Value $exportResponse "X-Evidence-Ref") -eq "llm_audit_export_visible")
Assert-True "header audit evidence" ((Header-Value $exportResponse "X-Export-Audit-Evidence-Ref") -eq "llm_audit_export_audit_persisted")
Assert-True "header redaction evidence" ((Header-Value $exportResponse "X-Redaction-Evidence-Ref") -eq "llm_audit_redaction_enforced")
Assert-True "header no live provider evidence" ((Header-Value $exportResponse "X-No-Live-Provider-Evidence-Ref") -eq "llm_audit_no_live_provider_guard")
Assert-True "header trace" ((Header-Value $exportResponse "X-Trace-Id") -eq $exportTraceId)
Assert-True "header request" ((Header-Value $exportResponse "X-Request-Id") -eq $exportRequestId)

$csv = [string]$exportResponse.Content
Assert-Contains "csv header" $csv $expectedHeader
Assert-Contains "csv trace visible" $csv $traceId
Assert-Contains "csv model visible" $csv "deepseek-ai/DeepSeek-V4-Flash:fastest"
Assert-Contains "csv provider visible" $csv "deterministic-dry-run"
Assert-Contains "csv evidence visible" $csv "llm_audit_export_visible"
Assert-Contains "csv redaction visible" $csv "llm_audit_redaction_enforced"
Assert-Contains "csv no live provider visible" $csv "llm_audit_no_live_provider_guard"
Assert-True "csv no forbidden pattern leak" (-not ($csv -match $forbiddenPattern))

$feed = Invoke-Text "$BaseUrl/api/v1/audit/llm?limit=80"
Assert-Contains "feed trace visible" $feed $traceId
Assert-Contains "feed redaction evidence" $feed "llm_audit_redaction_enforced"
Assert-True "feed no forbidden pattern leak" (-not ($feed -match $forbiddenPattern))

$snapshot = Invoke-Text "$BaseUrl/api/v1/audit/llm/snapshot?limit=80"
Assert-Contains "snapshot redaction clear" $snapshot '"redaction_status":"clear"'
Assert-True "snapshot no forbidden pattern leak" (-not ($snapshot -match $forbiddenPattern))

$recentAudit = Invoke-Json "$BaseUrl/api/v1/audit/recent?limit=100"
$exportAudit = @($recentAudit.events) | Where-Object {
  $_.event_type -eq "llm_audit_export_generated" -and
  $_.details.trace_id -eq $exportTraceId -and
  $_.details.request_id -eq $exportRequestId
} | Select-Object -First 1
Assert-True "export audit persisted" ($null -ne $exportAudit)
Assert-True "export audit evidence" ($exportAudit.details.evidence_ref -eq "llm_audit_export_audit_persisted")
Assert-True "export audit redaction" ($exportAudit.details.redaction_evidence_ref -eq "llm_audit_redaction_enforced")
Assert-True "export audit no-live provider" ($exportAudit.details.no_live_provider_evidence_ref -eq "llm_audit_no_live_provider_guard")
Assert-True "export audit no forbidden pattern leak" (-not (($exportAudit | ConvertTo-Json -Depth 20) -match $forbiddenPattern))

Write-Host "[phase3-llm-audit-export] status=verified"
Write-Host "contract_version=llm-audit-export-v1"
Write-Host "evidence_ref=llm_audit_export_visible"
Write-Host "audit_evidence_ref=llm_audit_export_audit_persisted"

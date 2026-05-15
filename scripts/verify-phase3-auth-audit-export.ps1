param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [switch]$AllowLocalhost,
  [switch]$RequireLifecycle
)

$ErrorActionPreference = "Stop"

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase3 auth audit export verification failed: $Label"
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $Text = ($Value | Out-String)
  if (-not $Text.Contains($Expected)) {
    throw "Phase3 auth audit export verification failed: $Label missing '$Expected'"
  }
}

function Invoke-Text($Url) {
  return (Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 60).Content
}

function Invoke-JsonApi($Url) {
  return Invoke-RestMethod -Method Get -Uri $Url -Headers @{ Accept = "application/json" } -TimeoutSec 30
}

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
  throw "BaseUrl is required"
}
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://" -and -not $AllowLocalhost) {
  throw "Phase3 auth audit export proof requires HTTPS unless -AllowLocalhost is set"
}

Write-Host "[phase3-auth-audit-export] base_url=$BaseUrl"

$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "frontend auth panel" $frontendHtml "Auth Contract"
Assert-Contains "frontend auth export panel" $frontendHtml "Auth Audit Export"
Assert-Contains "frontend auth export contract marker" $frontendHtml "auth-audit-export-v1"
Assert-Contains "frontend auth export evidence marker" $frontendHtml "auth_audit_export_visible"
Assert-Contains "frontend auth export audit marker" $frontendHtml "auth_audit_export_audit_persisted"
Assert-Contains "frontend auth export redaction marker" $frontendHtml "auth_audit_redaction_enforced"
Assert-Contains "frontend auth export no live oauth marker" $frontendHtml "auth_no_live_oauth_guard"
Assert-Contains "frontend auth export endpoint marker" $frontendHtml "GET /api/v1/audit/auth/export"

$contract = Invoke-JsonApi "$BaseUrl/api/v1/audit/auth/contract"
Assert-True "contract version" ($contract.contract_version -eq "auth-audit-snapshot-v1")
Assert-True "contract export endpoint" ($contract.export_endpoint -eq "GET /api/v1/audit/auth/export?format=csv&limit=80")
Assert-True "contract export contract endpoint" ($contract.export_contract_endpoint -eq "GET /api/v1/audit/auth/export/contract")
Assert-True "contract export version" ($contract.export_contract_version -eq "auth-audit-export-v1")
Assert-True "contract export evidence" ($contract.export_evidence_ref -eq "auth_audit_export_visible")
Assert-True "contract export audit evidence" ($contract.export_audit_evidence_ref -eq "auth_audit_export_audit_persisted")
Assert-True "contract export read-only" ($contract.read_only -eq $true)
Assert-True "contract export audit persisted" ($contract.audit_persisted -eq $true)
Assert-True "contract export csv support" (@($contract.supported_export_formats) -contains "csv")
Assert-True "contract export fields" (@($contract.export_columns | Where-Object { $_ -eq "sequence_index" }).Count -eq 1)

$exportContract = Invoke-JsonApi "$BaseUrl/api/v1/audit/auth/export/contract"
Assert-True "export version" ($exportContract.contract_version -eq "auth-audit-export-v1")
Assert-True "export parent version" ($exportContract.parent_contract_version -eq "auth-audit-snapshot-v1")
Assert-True "export mode" ($exportContract.mode -eq "read_only_auth_audit_csv_export")
Assert-True "export endpoint" ($exportContract.endpoint -eq "GET /api/v1/audit/auth/export?format=csv&limit=80")
Assert-True "export evidence" ($exportContract.evidence_ref -eq "auth_audit_export_visible")
Assert-True "export audit evidence" ($exportContract.export_audit_evidence_ref -eq "auth_audit_export_audit_persisted")
Assert-True "export redaction evidence" ($exportContract.redaction_evidence_ref -eq "auth_audit_redaction_enforced")
Assert-True "export no live oauth evidence" ($exportContract.no_live_oauth_evidence_ref -eq "auth_no_live_oauth_guard")
Assert-True "export read-only" ($exportContract.read_only -eq $true)
Assert-True "export audit persisted" ($exportContract.audit_persisted -eq $true)
Assert-True "export no live oauth claim" ($exportContract.live_github_oauth_call_claimed -eq $false)
Assert-True "export production false" ($exportContract.production_rollout_claimed -eq $false)
Assert-True "export promotion false" ($exportContract.promotion_allowed -eq $false)
Assert-True "export tokens absent" ($exportContract.tokens_returned -eq $false)
Assert-True "export cookies absent" ($exportContract.cookies_returned -eq $false)
Assert-True "export auth headers absent" ($exportContract.authorization_headers_returned -eq $false)
Assert-True "export blacklist keys absent" ($exportContract.blacklist_keys_returned -eq $false)
Assert-True "export oauth codes absent" ($exportContract.oauth_codes_returned -eq $false)
Assert-True "export oauth states absent" ($exportContract.oauth_states_returned -eq $false)
Assert-True "export raw details absent" ($exportContract.raw_details_returned -eq $false)

$snapshot = Invoke-JsonApi "$BaseUrl/api/v1/audit/auth/snapshot?limit=80"
$risk = Invoke-JsonApi "$BaseUrl/api/v1/audit/auth/risk-rollup?limit=80"
$timeline = Invoke-JsonApi "$BaseUrl/api/v1/audit/auth/timeline?limit=80"
Assert-True "snapshot no forbidden hits" ([int]$snapshot.forbidden_pattern_hits -eq 0)
Assert-True "risk no forbidden hits" ([int]$risk.forbidden_pattern_hits -eq 0)
Assert-True "timeline no forbidden hits" ([int]$timeline.forbidden_pattern_hits -eq 0)

$traceId = "auth-audit-export-proof-" + [Guid]::NewGuid().ToString("N")
$requestId = "auth-audit-export-request-" + [Guid]::NewGuid().ToString("N")
$exportResponse = Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/api/v1/audit/auth/export?format=csv&limit=80&trace_id=$traceId&request_id=$requestId" -TimeoutSec 60
Assert-True "export status" ([int]$exportResponse.StatusCode -eq 200)
Assert-Contains "export content type" $exportResponse.Headers."Content-Type" "text/csv"
Assert-Contains "export filename" $exportResponse.Headers."Content-Disposition" "superbrain-auth-audit.csv"
Assert-True "export contract header" ($exportResponse.Headers."X-Contract-Version" -eq "auth-audit-export-v1")
Assert-True "export evidence header" ($exportResponse.Headers."X-Evidence-Ref" -eq "auth_audit_export_visible")
Assert-True "export audit evidence header" ($exportResponse.Headers."X-Export-Audit-Evidence-Ref" -eq "auth_audit_export_audit_persisted")
Assert-True "export redaction evidence header" ($exportResponse.Headers."X-Redaction-Evidence-Ref" -eq "auth_audit_redaction_enforced")
Assert-True "export no live oauth evidence header" ($exportResponse.Headers."X-No-Live-Oauth-Evidence-Ref" -eq "auth_no_live_oauth_guard")
Assert-True "export trace header" ($exportResponse.Headers."X-Trace-Id" -eq $traceId)
Assert-True "export request header" ($exportResponse.Headers."X-Request-Id" -eq $requestId)

$csvText = [string]$exportResponse.Content
$expectedHeader = "sequence_index,event_id,created_at,event_type,lifecycle_step,status,severity,trace_id,code_present,cookie_http_only,cookie_secure,cookie_same_site,live_github_oauth_call,evidence_ref,redaction_evidence_ref,no_live_oauth_evidence_ref"
Assert-Contains "export csv header" $csvText $expectedHeader
Assert-True "export no access token leak" (-not $csvText.Contains("access_token"))
Assert-True "export no refresh token leak" (-not $csvText.Contains("refresh_token"))
Assert-True "export no blacklist key leak" (-not $csvText.Contains("blacklist_key"))
Assert-True "export no oauth code leak" (-not $csvText.Contains('"code"'))
Assert-True "export no oauth state leak" (-not $csvText.Contains('"state"'))
Assert-True "export no raw details leak" (-not $csvText.Contains("details"))
Assert-True "export no secret pattern leak" (-not ($csvText -match "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Cookie:|auth:refresh:blacklist:|csr_[A-Za-z0-9_-]{16,}|eyJ[A-Za-z0-9_-]{10,}\."))

if ($RequireLifecycle) {
  Assert-True "auth lifecycle events present" ([int]$snapshot.events_scanned -ge 3)
  Assert-Contains "csv callback event" $csvText "auth_github_callback_contract"
  Assert-Contains "csv refresh rotation event" $csvText "auth_refresh_rotated"
  Assert-Contains "csv refresh reuse event" $csvText "auth_refresh_reuse_blocked"
  Assert-Contains "csv logout event" $csvText "auth_logout_revoked"
}

$recentAudit = Invoke-JsonApi "$BaseUrl/api/v1/audit/recent?limit=100"
$recentAuditText = $recentAudit | ConvertTo-Json -Depth 30 -Compress
Assert-Contains "export audit event" $recentAuditText "auth_audit_export_generated"
Assert-Contains "export audit trace id" $recentAuditText $traceId
Assert-Contains "export audit request id" $recentAuditText $requestId
Assert-Contains "export audit evidence persisted" $recentAuditText "auth_audit_export_audit_persisted"
Assert-True "recent audit no raw blacklist key" (-not $recentAuditText.Contains('"blacklist_key":'))
Assert-True "recent audit no raw oauth state" (-not $recentAuditText.Contains('"state":'))
Assert-True "recent audit no raw oauth code" (-not $recentAuditText.Contains('"code":'))
Assert-True "recent audit no secret pattern leak" (-not ($recentAuditText -match "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Cookie:|auth:refresh:blacklist:|csr_[A-Za-z0-9_-]{16,}|eyJ[A-Za-z0-9_-]{10,}\."))

$canaryId = [Guid]::NewGuid().ToString("N")
$unsafeTrace = "unsafe $canaryId Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJleHBvcnQtY2FuYXJ5In0.signature Cookie: refresh_token=csr_$canaryId auth:refresh:blacklist:$canaryId"
$codeCanary = "code-$canaryId"
$stateCanary = "state-$canaryId"
Invoke-JsonApi "$BaseUrl/api/v1/auth/callback?code=$([uri]::EscapeDataString($codeCanary))&state=$([uri]::EscapeDataString($stateCanary))" | Out-Null
$refreshToken = "csr_$canaryId"
$refreshBody = @{ refresh_token = $refreshToken; trace_id = $unsafeTrace } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/v1/auth/refresh" -Headers @{ Accept = "application/json" } -ContentType "application/json" -Body $refreshBody -TimeoutSec 30 | Out-Null
try {
  Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/v1/auth/refresh" -Headers @{ Accept = "application/json" } -ContentType "application/json" -Body $refreshBody -TimeoutSec 30 | Out-Null
} catch {
  if (-not $_.Exception.Message.Contains("401")) { throw }
}
Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/v1/auth/logout" -Headers @{ Accept = "application/json" } -ContentType "application/json" -Body $refreshBody -TimeoutSec 30 | Out-Null

$exportAfter = Invoke-Text "$BaseUrl/api/v1/audit/auth/export?format=csv&limit=80"
$timelineAfter = Invoke-JsonApi "$BaseUrl/api/v1/audit/auth/timeline?limit=80"
$recentAfter = Invoke-JsonApi "$BaseUrl/api/v1/audit/recent?limit=100"
$combinedText = (@{ export = $exportAfter; timeline = $timelineAfter; recent = $recentAfter } | ConvertTo-Json -Depth 40 -Compress)
foreach ($forbidden in @(
  $unsafeTrace,
  $codeCanary,
  $stateCanary,
  $refreshToken,
  "Authorization: Bearer",
  "Cookie:",
  "Set-Cookie",
  "auth:refresh:blacklist:$canaryId",
  "eyJhbGciOiJIUzI1NiJ9",
  '"access_token":',
  '"refresh_token":',
  '"blacklist_key":',
  '"code":',
  '"state":'
)) {
  Assert-True "adversarial canary omitted $forbidden" (-not $combinedText.Contains($forbidden))
}
Assert-True "unsafe trace redacted in export" ($exportAfter.Contains("trace-redacted-"))
$canaryTimelineEvents = @($timelineAfter.timeline | Where-Object { $_.trace_id -like "trace-redacted-*" })
Assert-True "unsafe trace redacted in timeline" ($canaryTimelineEvents.Count -ge 1)
$canaryRecentEvents = @($recentAfter.events | Where-Object { $_.trace_id -like "trace-redacted-*" })
Assert-True "unsafe trace redacted in recent audit" ($canaryRecentEvents.Count -ge 1)

Write-Host "status=verified"
Write-Host "contract_version=auth-audit-export-v1"
Write-Host "evidence_ref=auth_audit_export_visible"
Write-Host "audit_evidence_ref=auth_audit_export_audit_persisted"
Write-Host "redaction_evidence_ref=auth_audit_redaction_enforced"

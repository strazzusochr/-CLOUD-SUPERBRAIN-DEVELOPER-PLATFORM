param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [switch]$AllowLocalhost,
  [switch]$RequireLifecycle
)

$ErrorActionPreference = "Stop"

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase3 auth audit timeline verification failed: $Label"
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $Text = ($Value | Out-String)
  if (-not $Text.Contains($Expected)) {
    throw "Phase3 auth audit timeline verification failed: $Label missing '$Expected'"
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
  throw "Phase3 auth audit timeline proof requires HTTPS unless -AllowLocalhost is set"
}

Write-Host "[phase3-auth-audit-timeline] base_url=$BaseUrl"

$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "frontend auth panel" $frontendHtml "Auth Contract"
Assert-Contains "frontend auth timeline panel" $frontendHtml "Auth Audit Timeline"
Assert-Contains "frontend auth timeline contract marker" $frontendHtml "auth-audit-timeline-v1"
Assert-Contains "frontend auth timeline evidence marker" $frontendHtml "auth_audit_timeline_visible"
Assert-Contains "frontend auth timeline redaction marker" $frontendHtml "auth_audit_redaction_enforced"
Assert-Contains "frontend auth timeline no live oauth marker" $frontendHtml "auth_no_live_oauth_guard"
Assert-Contains "frontend auth timeline endpoint marker" $frontendHtml "GET /api/v1/audit/auth/timeline"

$contract = Invoke-JsonApi "$BaseUrl/api/v1/audit/auth/contract"
Assert-True "contract version" ($contract.contract_version -eq "auth-audit-snapshot-v1")
Assert-True "timeline endpoint" ($contract.timeline_endpoint -eq "GET /api/v1/audit/auth/timeline")
Assert-True "timeline contract version" ($contract.timeline_contract_version -eq "auth-audit-timeline-v1")
Assert-True "timeline evidence ref" ($contract.timeline_evidence_ref -eq "auth_audit_timeline_visible")
Assert-True "contract read-only" ($contract.read_only -eq $true)
Assert-True "contract no live oauth" ($contract.live_github_oauth_call_claimed -eq $false)
Assert-True "contract timeline fields" (@($contract.timeline_fields | Where-Object { $_ -eq "sequence_index" }).Count -eq 1)

$snapshot = Invoke-JsonApi "$BaseUrl/api/v1/audit/auth/snapshot?limit=80"
$risk = Invoke-JsonApi "$BaseUrl/api/v1/audit/auth/risk-rollup?limit=80"
$timeline = Invoke-JsonApi "$BaseUrl/api/v1/audit/auth/timeline?limit=80"
$recentAudit = Invoke-JsonApi "$BaseUrl/api/v1/audit/recent?limit=80"
Assert-True "timeline version" ($timeline.contract_version -eq "auth-audit-timeline-v1")
Assert-True "timeline parent version" ($timeline.parent_contract_version -eq "auth-audit-snapshot-v1")
Assert-True "timeline mode" ($timeline.mode -eq "read_only_auth_audit_timeline")
Assert-True "timeline endpoint" ($timeline.endpoint -eq "GET /api/v1/audit/auth/timeline")
Assert-True "timeline evidence" ($timeline.evidence_ref -eq "auth_audit_timeline_visible")
Assert-True "timeline snapshot evidence" ($timeline.snapshot_evidence_ref -eq "auth_audit_snapshot_visible")
Assert-True "timeline risk evidence" ($timeline.risk_rollup_evidence_ref -eq "auth_audit_risk_rollup_visible")
Assert-True "timeline redaction evidence" ($timeline.redaction_evidence_ref -eq "auth_audit_redaction_enforced")
Assert-True "timeline no live oauth evidence" ($timeline.no_live_oauth_evidence_ref -eq "auth_no_live_oauth_guard")
Assert-True "timeline read-only" ($timeline.read_only -eq $true)
Assert-True "timeline no live oauth claim" ($timeline.live_github_oauth_call_claimed -eq $false)
Assert-True "timeline production false" ($timeline.production_rollout_claimed -eq $false)
Assert-True "timeline promotion false" ($timeline.promotion_allowed -eq $false)
Assert-True "timeline tokens absent" ($timeline.tokens_returned -eq $false)
Assert-True "timeline cookies absent" ($timeline.cookies_returned -eq $false)
Assert-True "timeline auth headers absent" ($timeline.authorization_headers_returned -eq $false)
Assert-True "timeline blacklist keys absent" ($timeline.blacklist_keys_returned -eq $false)
Assert-True "timeline oauth codes absent" ($timeline.oauth_codes_returned -eq $false)
Assert-True "timeline oauth states absent" ($timeline.oauth_states_returned -eq $false)
Assert-True "timeline forbidden hits clear" ([int]$timeline.forbidden_pattern_hits -eq 0)
Assert-True "timeline no live oauth count" ([int]$timeline.live_github_oauth_call_count -eq 0)
Assert-True "timeline redaction clear" ($timeline.redaction_status -eq "clear")
Assert-True "timeline oauth dry run only" ($timeline.oauth_status -eq "dry_run_only")
Assert-True "timeline snapshot parity" ([int]$timeline.events_scanned -eq [int]$snapshot.events_scanned)
Assert-True "timeline risk parity" ([int]$timeline.events_scanned -eq [int]$risk.events_scanned)
Assert-True "timeline count parity" ([int]$timeline.timeline_count -eq @($timeline.timeline).Count)

$allowedTimelineFields = @(
  "sequence_index",
  "event_id",
  "created_at",
  "event_type",
  "timeline_leg",
  "trace_id",
  "lifecycle_step",
  "status",
  "severity",
  "code_present",
  "cookie_flags",
  "live_github_oauth_call",
  "evidence_ref",
  "redaction_evidence_ref",
  "no_live_oauth_evidence_ref"
)
$lastIndex = 0
foreach ($event in @($timeline.timeline)) {
  Assert-True "timeline sequence monotonic" ([int]$event.sequence_index -gt $lastIndex)
  $lastIndex = [int]$event.sequence_index
  Assert-True "timeline leg safe" (@("dry_run_callback", "refresh_rotation", "refresh_reuse_block", "logout_revoke", "unknown") -contains [string]$event.timeline_leg)
  Assert-True "timeline no live oauth event" ($event.live_github_oauth_call -eq $false)
  foreach ($field in @($event.PSObject.Properties.Name)) {
    Assert-True "timeline event field allowlist $field" ($allowedTimelineFields -contains $field)
  }
}

if ($RequireLifecycle) {
  Assert-True "auth lifecycle events present" ([int]$timeline.events_scanned -ge 3)
  Assert-True "timeline has dry-run callback leg" ([int]$timeline.timeline_leg_counts.dry_run_callback -ge 1)
  Assert-True "timeline has refresh rotation leg" ([int]$timeline.timeline_leg_counts.refresh_rotation -ge 1)
  Assert-True "timeline has refresh reuse block leg" ([int]$timeline.timeline_leg_counts.refresh_reuse_block -ge 1)
  Assert-True "timeline has logout revoke leg" ([int]$timeline.timeline_leg_counts.logout_revoke -ge 1)
}

$timelineText = $timeline | ConvertTo-Json -Depth 30 -Compress
Assert-True "timeline no access token leak" (-not $timelineText.Contains('"access_token":'))
Assert-True "timeline no refresh token leak" (-not $timelineText.Contains('"refresh_token":'))
Assert-True "timeline no blacklist key leak" (-not $timelineText.Contains('"blacklist_key":'))
Assert-True "timeline no oauth code leak" (-not $timelineText.Contains('"code":'))
Assert-True "timeline no oauth state leak" (-not $timelineText.Contains('"state":'))
Assert-True "timeline no raw details leak" (-not $timelineText.Contains('"details":'))
Assert-True "timeline no secret pattern leak" (-not ($timelineText -match "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Cookie:|auth:refresh:blacklist:|csr_[A-Za-z0-9_-]{16,}|eyJ[A-Za-z0-9_-]{10,}\."))

$recentAuditText = $recentAudit | ConvertTo-Json -Depth 30 -Compress
Assert-True "recent audit no raw blacklist key" (-not $recentAuditText.Contains('"blacklist_key":'))
Assert-True "recent audit no raw oauth state" (-not $recentAuditText.Contains('"state":'))
Assert-True "recent audit no raw oauth code" (-not $recentAuditText.Contains('"code":'))
Assert-True "recent audit no secret pattern leak" (-not ($recentAuditText -match "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Cookie:|auth:refresh:blacklist:|csr_[A-Za-z0-9_-]{16,}|eyJ[A-Za-z0-9_-]{10,}\."))

$canaryId = [Guid]::NewGuid().ToString("N")
$unsafeTrace = "unsafe $canaryId Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0ZXN0LWNhbmFyeSJ9.signature Cookie: refresh_token=csr_$canaryId auth:refresh:blacklist:$canaryId"
$codeCanary = "code-$canaryId"
$stateCanary = "state-$canaryId"
$callbackUrl = "$BaseUrl/api/v1/auth/callback?code=$([uri]::EscapeDataString($codeCanary))&state=$([uri]::EscapeDataString($stateCanary))"
Invoke-JsonApi $callbackUrl | Out-Null
$refreshToken = "csr_$canaryId"
$refreshBody = @{ refresh_token = $refreshToken; trace_id = $unsafeTrace } | ConvertTo-Json -Compress
Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/v1/auth/refresh" -Headers @{ Accept = "application/json" } -ContentType "application/json" -Body $refreshBody -TimeoutSec 30 | Out-Null
try {
  Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/v1/auth/refresh" -Headers @{ Accept = "application/json" } -ContentType "application/json" -Body $refreshBody -TimeoutSec 30 | Out-Null
} catch {
  if (-not $_.Exception.Message.Contains("401")) { throw }
}
Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/v1/auth/logout" -Headers @{ Accept = "application/json" } -ContentType "application/json" -Body $refreshBody -TimeoutSec 30 | Out-Null

$timelineAfter = Invoke-JsonApi "$BaseUrl/api/v1/audit/auth/timeline?limit=80"
$recentAfter = Invoke-JsonApi "$BaseUrl/api/v1/audit/recent?limit=80"
$combinedText = (@{ timeline = $timelineAfter; recent = $recentAfter } | ConvertTo-Json -Depth 40 -Compress)
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
$canaryTimelineEvents = @($timelineAfter.timeline | Where-Object { $_.trace_id -like "trace-redacted-*" })
Assert-True "unsafe trace redacted in timeline" ($canaryTimelineEvents.Count -ge 1)
foreach ($event in $canaryTimelineEvents) {
  Assert-True "unsafe trace redaction shape" ([string]$event.trace_id -match "^trace-redacted-[0-9a-f]{16}$")
}
$canaryRecentEvents = @($recentAfter.events | Where-Object { $_.trace_id -like "trace-redacted-*" })
Assert-True "unsafe trace redacted in recent audit" ($canaryRecentEvents.Count -ge 1)

Write-Host "status=verified"
Write-Host "contract_version=auth-audit-timeline-v1"
Write-Host "evidence_ref=auth_audit_timeline_visible"
Write-Host "redaction_evidence_ref=auth_audit_redaction_enforced"
Write-Host "no_live_oauth_evidence_ref=auth_no_live_oauth_guard"

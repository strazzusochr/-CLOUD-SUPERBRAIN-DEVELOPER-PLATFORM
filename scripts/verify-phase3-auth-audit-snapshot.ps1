param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [switch]$AllowLocalhost,
  [switch]$RequireLifecycle
)

$ErrorActionPreference = "Stop"

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase3 auth audit snapshot verification failed: $Label"
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $Text = ($Value | Out-String)
  if (-not $Text.Contains($Expected)) {
    throw "Phase3 auth audit snapshot verification failed: $Label did not contain '$Expected'. Value: $Text"
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
  throw "Phase3 auth audit snapshot proof requires HTTPS unless -AllowLocalhost is set"
}

Write-Host "[phase3-auth-audit-snapshot] base_url=$BaseUrl"

$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "frontend auth panel" $frontendHtml "Auth Contract"
Assert-Contains "frontend auth audit panel" $frontendHtml "Auth Audit Snapshot"
Assert-Contains "frontend auth audit contract marker" $frontendHtml "auth-audit-snapshot-v1"
Assert-Contains "frontend auth audit evidence marker" $frontendHtml "auth_audit_snapshot_visible"
Assert-Contains "frontend auth audit redaction marker" $frontendHtml "auth_audit_redaction_enforced"
Assert-Contains "frontend auth audit no live oauth marker" $frontendHtml "auth_no_live_oauth_guard"
Assert-Contains "frontend auth audit endpoint marker" $frontendHtml "GET /api/v1/audit/auth/snapshot"

$contract = Invoke-JsonApi "$BaseUrl/api/v1/audit/auth/contract"
Assert-True "contract version" ($contract.contract_version -eq "auth-audit-snapshot-v1")
Assert-True "parent contract version" ($contract.parent_contract_version -eq "auth-github-jwt-refresh-v1")
Assert-True "snapshot endpoint" ($contract.endpoint -eq "GET /api/v1/audit/auth/snapshot")
Assert-True "contract endpoint" ($contract.contract_endpoint -eq "GET /api/v1/audit/auth/contract")
Assert-True "contract read-only" ($contract.read_only -eq $true)
Assert-True "contract no live oauth" ($contract.live_github_oauth_call_claimed -eq $false)
Assert-True "contract tokens absent" ($contract.tokens_returned -eq $false)
Assert-True "contract cookies absent" ($contract.cookies_returned -eq $false)
Assert-True "contract blacklist keys absent" ($contract.blacklist_keys_returned -eq $false)
Assert-True "contract oauth codes absent" ($contract.oauth_codes_returned -eq $false)
Assert-True "contract oauth states absent" ($contract.oauth_states_returned -eq $false)
Assert-True "contract evidence" ($contract.evidence_ref -eq "auth_audit_snapshot_visible")
Assert-True "contract redaction evidence" ($contract.redaction_evidence_ref -eq "auth_audit_redaction_enforced")
Assert-True "contract no live oauth evidence" ($contract.no_live_oauth_evidence_ref -eq "auth_no_live_oauth_guard")

$snapshot = Invoke-JsonApi "$BaseUrl/api/v1/audit/auth/snapshot?limit=80"
Assert-True "snapshot version" ($snapshot.contract_version -eq "auth-audit-snapshot-v1")
Assert-True "snapshot mode" ($snapshot.mode -eq "read_only_auth_audit_snapshot")
Assert-True "snapshot read-only" ($snapshot.read_only -eq $true)
Assert-True "snapshot no live oauth claim" ($snapshot.live_github_oauth_call_claimed -eq $false)
Assert-True "snapshot tokens absent" ($snapshot.tokens_returned -eq $false)
Assert-True "snapshot cookies absent" ($snapshot.cookies_returned -eq $false)
Assert-True "snapshot auth headers absent" ($snapshot.authorization_headers_returned -eq $false)
Assert-True "snapshot blacklist keys absent" ($snapshot.blacklist_keys_returned -eq $false)
Assert-True "snapshot oauth codes absent" ($snapshot.oauth_codes_returned -eq $false)
Assert-True "snapshot oauth states absent" ($snapshot.oauth_states_returned -eq $false)
Assert-True "snapshot forbidden hits clear" ([int]$snapshot.forbidden_pattern_hits -eq 0)
Assert-True "snapshot redaction clear" ($snapshot.redaction_status -eq "clear")
Assert-True "snapshot no live oauth count" ([int]$snapshot.live_github_oauth_call_count -eq 0)
Assert-True "snapshot event projection bounded" (@($snapshot.events).Count -le [int]$snapshot.events_scanned)

$allowedEventFields = @(
  "event_id",
  "event_type",
  "trace_id",
  "lifecycle_step",
  "status",
  "severity",
  "created_at",
  "code_present",
  "cookie_flags",
  "live_github_oauth_call",
  "evidence_ref",
  "redaction_evidence_ref",
  "no_live_oauth_evidence_ref"
)
foreach ($event in @($snapshot.events)) {
  $eventFields = @($event.PSObject.Properties.Name)
  foreach ($field in $eventFields) {
    Assert-True "snapshot event field allowlist $field" ($allowedEventFields -contains $field)
  }
  Assert-True "snapshot event no raw details" (-not ($eventFields -contains "details"))
  Assert-True "snapshot event no user id" (-not ($eventFields -contains "user_id"))
  Assert-True "snapshot event no session id" (-not ($eventFields -contains "session_id"))
  Assert-True "snapshot event no auth header" (-not ($eventFields -contains "authorization_header"))
  Assert-True "snapshot event no cookie value" (-not ($eventFields -contains "cookie"))
  Assert-True "snapshot event no token hash" (-not ($eventFields -contains "token_hash"))
}

if ($RequireLifecycle) {
  Assert-True "auth lifecycle events present" ([int]$snapshot.events_scanned -ge 3)
  Assert-True "refresh rotated present" ([int]$snapshot.event_type_counts.auth_refresh_rotated -ge 1)
  Assert-True "refresh reuse blocked present" ([int]$snapshot.event_type_counts.auth_refresh_reuse_blocked -ge 1)
  Assert-True "logout revoked present" ([int]$snapshot.event_type_counts.auth_logout_revoked -ge 1)
}

$snapshotText = $snapshot | ConvertTo-Json -Depth 30 -Compress
Assert-True "snapshot no access token leak" (-not $snapshotText.Contains('"access_token":'))
Assert-True "snapshot no refresh token leak" (-not $snapshotText.Contains('"refresh_token":'))
Assert-True "snapshot no blacklist key leak" (-not $snapshotText.Contains('"blacklist_key":'))
Assert-True "snapshot no oauth code leak" (-not $snapshotText.Contains('"code":'))
Assert-True "snapshot no oauth state leak" (-not $snapshotText.Contains('"state":'))
Assert-True "snapshot no secret pattern leak" (-not ($snapshotText -match "sk-proj-|github_pat_|ghp_|vck_|cfat_|hcloud_|hf_|glpat-"))

Write-Host "status=verified"
Write-Host "contract_version=auth-audit-snapshot-v1"
Write-Host "evidence_ref=auth_audit_snapshot_visible"
Write-Host "redaction_evidence_ref=auth_audit_redaction_enforced"
Write-Host "no_live_oauth_evidence_ref=auth_no_live_oauth_guard"

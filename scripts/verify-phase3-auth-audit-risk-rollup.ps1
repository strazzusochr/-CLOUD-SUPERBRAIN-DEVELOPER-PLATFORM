param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [switch]$AllowLocalhost,
  [switch]$RequireLifecycle
)

$ErrorActionPreference = "Stop"

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase3 auth audit risk rollup verification failed: $Label"
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $Text = ($Value | Out-String)
  if (-not $Text.Contains($Expected)) {
    throw "Phase3 auth audit risk rollup verification failed: $Label missing '$Expected'"
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
  throw "Phase3 auth audit risk rollup proof requires HTTPS unless -AllowLocalhost is set"
}

Write-Host "[phase3-auth-audit-risk-rollup] base_url=$BaseUrl"

$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "frontend auth panel" $frontendHtml "Auth Contract"
Assert-Contains "frontend auth risk panel" $frontendHtml "Auth Audit Risk Rollup"
Assert-Contains "frontend auth risk contract marker" $frontendHtml "auth-audit-risk-rollup-v1"
Assert-Contains "frontend auth risk evidence marker" $frontendHtml "auth_audit_risk_rollup_visible"
Assert-Contains "frontend auth risk redaction marker" $frontendHtml "auth_audit_redaction_enforced"
Assert-Contains "frontend auth risk no live oauth marker" $frontendHtml "auth_no_live_oauth_guard"
Assert-Contains "frontend auth risk endpoint marker" $frontendHtml "GET /api/v1/audit/auth/risk-rollup"

$contract = Invoke-JsonApi "$BaseUrl/api/v1/audit/auth/contract"
Assert-True "contract version" ($contract.contract_version -eq "auth-audit-snapshot-v1")
Assert-True "risk endpoint" ($contract.risk_rollup_endpoint -eq "GET /api/v1/audit/auth/risk-rollup")
Assert-True "risk contract version" ($contract.risk_rollup_contract_version -eq "auth-audit-risk-rollup-v1")
Assert-True "risk evidence ref" ($contract.risk_rollup_evidence_ref -eq "auth_audit_risk_rollup_visible")
Assert-True "contract read-only" ($contract.read_only -eq $true)
Assert-True "contract no live oauth" ($contract.live_github_oauth_call_claimed -eq $false)
Assert-True "contract tokens absent" ($contract.tokens_returned -eq $false)
Assert-True "contract cookies absent" ($contract.cookies_returned -eq $false)
Assert-True "contract auth headers absent" ($contract.authorization_headers_returned -eq $false)
Assert-True "contract blacklist keys absent" ($contract.blacklist_keys_returned -eq $false)
Assert-True "contract oauth codes absent" ($contract.oauth_codes_returned -eq $false)
Assert-True "contract oauth states absent" ($contract.oauth_states_returned -eq $false)

$risk = Invoke-JsonApi "$BaseUrl/api/v1/audit/auth/risk-rollup?limit=80"
Assert-True "risk version" ($risk.contract_version -eq "auth-audit-risk-rollup-v1")
Assert-True "risk parent version" ($risk.parent_contract_version -eq "auth-audit-snapshot-v1")
Assert-True "risk mode" ($risk.mode -eq "read_only_auth_audit_risk_rollup")
Assert-True "risk endpoint" ($risk.endpoint -eq "GET /api/v1/audit/auth/risk-rollup")
Assert-True "risk snapshot endpoint" ($risk.snapshot_endpoint -eq "GET /api/v1/audit/auth/snapshot")
Assert-True "risk evidence" ($risk.evidence_ref -eq "auth_audit_risk_rollup_visible")
Assert-True "risk snapshot evidence" ($risk.snapshot_evidence_ref -eq "auth_audit_snapshot_visible")
Assert-True "risk redaction evidence" ($risk.redaction_evidence_ref -eq "auth_audit_redaction_enforced")
Assert-True "risk no live oauth evidence" ($risk.no_live_oauth_evidence_ref -eq "auth_no_live_oauth_guard")
Assert-True "risk read-only" ($risk.read_only -eq $true)
Assert-True "risk no live oauth claim" ($risk.live_github_oauth_call_claimed -eq $false)
Assert-True "risk production false" ($risk.production_rollout_claimed -eq $false)
Assert-True "risk promotion false" ($risk.promotion_allowed -eq $false)
Assert-True "risk tokens absent" ($risk.tokens_returned -eq $false)
Assert-True "risk cookies absent" ($risk.cookies_returned -eq $false)
Assert-True "risk auth headers absent" ($risk.authorization_headers_returned -eq $false)
Assert-True "risk blacklist keys absent" ($risk.blacklist_keys_returned -eq $false)
Assert-True "risk oauth codes absent" ($risk.oauth_codes_returned -eq $false)
Assert-True "risk oauth states absent" ($risk.oauth_states_returned -eq $false)
Assert-True "risk forbidden hits clear" ([int]$risk.forbidden_pattern_hits -eq 0)
Assert-True "risk no live oauth count" ([int]$risk.live_github_oauth_call_count -eq 0)
Assert-True "risk blocker count clear" ([int]$risk.blocker_count -eq 0)
Assert-True "risk redaction clear" ($risk.redaction_status -eq "clear")
Assert-True "risk oauth dry run only" ($risk.oauth_status -eq "dry_run_only")
Assert-True "risk status supported" (@("clear", "review", "blocked") -contains [string]$risk.risk_status)
Assert-True "risk badges visible" (@($risk.risk_badges).Count -ge 3)

if ($RequireLifecycle) {
  Assert-True "auth lifecycle events present" ([int]$risk.events_scanned -ge 3)
  Assert-True "dry-run callback present" ([int]$risk.dry_run_callback_count -ge 1)
  Assert-True "refresh rotated present" ([int]$risk.refresh_rotation_count -ge 1)
  Assert-True "refresh reuse blocked present" ([int]$risk.refresh_reuse_block_count -ge 1)
  Assert-True "logout revoked present" ([int]$risk.logout_revoke_count -ge 1)
  Assert-True "review count includes reuse block" ([int]$risk.review_count -ge 1)
}

$riskText = $risk | ConvertTo-Json -Depth 30 -Compress
Assert-True "risk no access token leak" (-not $riskText.Contains('"access_token":'))
Assert-True "risk no refresh token leak" (-not $riskText.Contains('"refresh_token":'))
Assert-True "risk no blacklist key leak" (-not $riskText.Contains('"blacklist_key":'))
Assert-True "risk no oauth code leak" (-not $riskText.Contains('"code":'))
Assert-True "risk no oauth state leak" (-not $riskText.Contains('"state":'))
Assert-True "risk no secret pattern leak" (-not ($riskText -match "sk-proj-|github_pat_|ghp_|vck_|cfat_|hcloud_|hf_|glpat-"))

Write-Host "status=verified"
Write-Host "contract_version=auth-audit-risk-rollup-v1"
Write-Host "evidence_ref=auth_audit_risk_rollup_visible"
Write-Host "redaction_evidence_ref=auth_audit_redaction_enforced"
Write-Host "no_live_oauth_evidence_ref=auth_no_live_oauth_guard"

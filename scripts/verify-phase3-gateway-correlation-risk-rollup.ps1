param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [switch]$AllowLocalhost,
  [switch]$RequireFullCorrelation
)

$ErrorActionPreference = "Stop"

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase3 gateway correlation risk rollup verification failed: $Label"
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $Text = ($Value | Out-String)
  if (-not $Text.Contains($Expected)) {
    throw "Phase3 gateway correlation risk rollup verification failed: $Label did not contain '$Expected'. Value: $Text"
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
  throw "Phase3 gateway correlation risk rollup proof requires HTTPS unless -AllowLocalhost is set"
}

Write-Host "[phase3-gateway-correlation-risk-rollup] base_url=$BaseUrl"

$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "frontend risk rollup panel" $frontendHtml "Gateway Correlation Risk Rollup"
Assert-Contains "frontend risk contract marker" $frontendHtml "gateway-correlation-risk-rollup-v1"
Assert-Contains "frontend risk evidence marker" $frontendHtml "gateway_correlation_risk_rollup_visible"
Assert-Contains "frontend redaction marker" $frontendHtml "gateway_correlation_redaction_enforced"
Assert-Contains "frontend no live write marker" $frontendHtml "gateway_correlation_no_live_write_guard"
Assert-Contains "frontend risk endpoint marker" $frontendHtml "GET /api/v1/security/gateway-correlation/risk-rollup"

$contract = Invoke-JsonApi "$BaseUrl/api/v1/security/gateway-correlation/contract"
Assert-True "parent contract version" ($contract.contract_version -eq "gateway-correlation-snapshot-v1")
Assert-True "risk contract version" ($contract.risk_rollup_contract_version -eq "gateway-correlation-risk-rollup-v1")
Assert-True "risk endpoint" ($contract.risk_rollup_endpoint -eq "GET /api/v1/security/gateway-correlation/risk-rollup")
Assert-True "contract read-only" ($contract.read_only -eq $true)
Assert-True "contract no live provider" ($contract.live_provider_calls_claimed -eq $false)
Assert-True "contract no live mcp" ($contract.live_mcp_writes_claimed -eq $false)
Assert-True "contract risk evidence" ($contract.risk_rollup_evidence_ref -eq "gateway_correlation_risk_rollup_visible")
Assert-True "contract redaction evidence" ($contract.redaction_evidence_ref -eq "gateway_correlation_redaction_enforced")
Assert-True "contract no live write evidence" ($contract.no_live_write_evidence_ref -eq "gateway_correlation_no_live_write_guard")

$snapshot = Invoke-JsonApi "$BaseUrl/api/v1/security/gateway-correlation/snapshot?limit=80"
$rollup = Invoke-JsonApi "$BaseUrl/api/v1/security/gateway-correlation/risk-rollup?limit=80"

Assert-True "rollup contract version" ($rollup.contract_version -eq "gateway-correlation-risk-rollup-v1")
Assert-True "rollup parent version" ($rollup.parent_contract_version -eq "gateway-correlation-snapshot-v1")
Assert-True "rollup mode" ($rollup.mode -eq "read_only_gateway_correlation_risk_rollup")
Assert-True "rollup read-only" ($rollup.read_only -eq $true)
Assert-True "rollup no live provider claim" ($rollup.live_provider_calls_claimed -eq $false)
Assert-True "rollup no live mcp claim" ($rollup.live_mcp_writes_claimed -eq $false)
Assert-True "rollup no production rollout" ($rollup.production_rollout_claimed -eq $false)
Assert-True "rollup promotion blocked" ($rollup.promotion_allowed -eq $false)
Assert-True "rollup prompt bodies absent" ($rollup.prompt_bodies_returned -eq $false)
Assert-True "rollup input refs absent" ($rollup.tool_input_refs_returned -eq $false)
Assert-True "rollup credentials absent" ($rollup.provider_credentials_returned -eq $false)
Assert-True "rollup forbidden hits clear" ([int]$rollup.forbidden_pattern_hits -eq 0)
Assert-True "rollup redaction clear" ($rollup.redaction_status -eq "clear")
Assert-True "rollup no live provider count" ([int]$rollup.live_provider_call_count -eq 0)
Assert-True "rollup no live mcp count" ([int]$rollup.live_mcp_write_count -eq 0)
Assert-True "rollup blocker count clear" ([int]$rollup.blocker_count -eq 0)
Assert-True "rollup event parity" ([int]$rollup.events_scanned -eq [int]$snapshot.events_scanned)
Assert-True "rollup group parity" ([int]$rollup.groups_scanned -eq [int]$snapshot.groups_scanned)
Assert-True "rollup has badges" (@($rollup.risk_badges).Count -ge 3)
Assert-True "rollup has redaction badge" (@($rollup.risk_badges | Where-Object { $_.id -eq "redaction" -and $_.status -eq "clear" }).Count -ge 1)
Assert-True "rollup has no-live-write badge" (@($rollup.risk_badges | Where-Object { $_.id -eq "live_mcp_write" -and $_.status -eq "clear" }).Count -ge 1)

if ($RequireFullCorrelation) {
  Assert-True "rollup full correlation present" ([int]$rollup.full_correlation_count -ge 1)
  Assert-True "rollup has group risk rows" (@($rollup.group_risks).Count -ge 1)
}

$rollupText = $rollup | ConvertTo-Json -Depth 30 -Compress
Assert-True "rollup no prompt body leak" (-not $rollupText.Contains("prompt_body"))
Assert-True "rollup no raw input ref leak" (-not $rollupText.Contains('"input_ref":'))
Assert-True "rollup no redaction probe leak" (-not $rollupText.Contains("redaction-proof-value"))
Assert-True "rollup no secret pattern leak" (-not ($rollupText -match "sk-proj-|github_pat_|ghp_|vck_|cfat_|hcloud_|hf_|glpat-"))

Write-Host "status=verified"
Write-Host "contract_version=gateway-correlation-risk-rollup-v1"
Write-Host "evidence_ref=gateway_correlation_risk_rollup_visible"
Write-Host "redaction_evidence_ref=gateway_correlation_redaction_enforced"
Write-Host "no_live_write_evidence_ref=gateway_correlation_no_live_write_guard"

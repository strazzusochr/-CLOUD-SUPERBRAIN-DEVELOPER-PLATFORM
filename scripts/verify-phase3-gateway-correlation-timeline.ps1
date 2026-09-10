param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [switch]$AllowLocalhost,
  [switch]$RequireFullCorrelation
)

$ErrorActionPreference = "Stop"

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase3 gateway correlation timeline verification failed: $Label"
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $Text = ($Value | Out-String)
  if (-not $Text.Contains($Expected)) {
    throw "Phase3 gateway correlation timeline verification failed: $Label did not contain '$Expected'. Value: $Text"
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
  throw "Phase3 gateway correlation timeline proof requires HTTPS unless -AllowLocalhost is set"
}

Write-Host "[phase3-gateway-correlation-timeline] base_url=$BaseUrl"

$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "frontend timeline panel" $frontendHtml "Gateway Correlation Timeline"
Assert-Contains "frontend timeline contract marker" $frontendHtml "gateway-correlation-timeline-v1"
Assert-Contains "frontend timeline evidence marker" $frontendHtml "gateway_correlation_timeline_visible"
Assert-Contains "frontend timeline redaction marker" $frontendHtml "gateway_correlation_redaction_enforced"
Assert-Contains "frontend timeline no live write marker" $frontendHtml "gateway_correlation_no_live_write_guard"
Assert-Contains "frontend timeline endpoint marker" $frontendHtml "GET /api/v1/security/gateway-correlation/timeline"

$contract = Invoke-JsonApi "$BaseUrl/api/v1/security/gateway-correlation/contract"
Assert-True "parent contract version" ($contract.contract_version -eq "gateway-correlation-snapshot-v1")
Assert-True "timeline contract version" ($contract.timeline_contract_version -eq "gateway-correlation-timeline-v1")
Assert-True "timeline endpoint" ($contract.timeline_endpoint -eq "GET /api/v1/security/gateway-correlation/timeline")
Assert-True "contract read-only" ($contract.read_only -eq $true)
Assert-True "contract no live provider" ($contract.live_provider_calls_claimed -eq $false)
Assert-True "contract no live mcp" ($contract.live_mcp_writes_claimed -eq $false)
Assert-True "contract timeline evidence" ($contract.timeline_evidence_ref -eq "gateway_correlation_timeline_visible")
Assert-True "contract redaction evidence" ($contract.redaction_evidence_ref -eq "gateway_correlation_redaction_enforced")
Assert-True "contract no live write evidence" ($contract.no_live_write_evidence_ref -eq "gateway_correlation_no_live_write_guard")
Assert-True "contract timeline fields" (@($contract.timeline_fields | Where-Object { $_ -eq "sequence_index" }).Count -eq 1)

$snapshot = Invoke-JsonApi "$BaseUrl/api/v1/security/gateway-correlation/snapshot?limit=80"
$rollup = Invoke-JsonApi "$BaseUrl/api/v1/security/gateway-correlation/risk-rollup?limit=80"
$timeline = Invoke-JsonApi "$BaseUrl/api/v1/security/gateway-correlation/timeline?limit=80"

Assert-True "timeline contract version" ($timeline.contract_version -eq "gateway-correlation-timeline-v1")
Assert-True "timeline parent version" ($timeline.parent_contract_version -eq "gateway-correlation-snapshot-v1")
Assert-True "timeline mode" ($timeline.mode -eq "read_only_gateway_correlation_timeline")
Assert-True "timeline read-only" ($timeline.read_only -eq $true)
Assert-True "timeline no live provider claim" ($timeline.live_provider_calls_claimed -eq $false)
Assert-True "timeline no live mcp claim" ($timeline.live_mcp_writes_claimed -eq $false)
Assert-True "timeline no production rollout" ($timeline.production_rollout_claimed -eq $false)
Assert-True "timeline promotion blocked" ($timeline.promotion_allowed -eq $false)
Assert-True "timeline prompt bodies absent" ($timeline.prompt_bodies_returned -eq $false)
Assert-True "timeline input refs absent" ($timeline.tool_input_refs_returned -eq $false)
Assert-True "timeline credentials absent" ($timeline.provider_credentials_returned -eq $false)
Assert-True "timeline forbidden hits clear" ([int]$timeline.forbidden_pattern_hits -eq 0)
Assert-True "timeline redaction clear" ($timeline.redaction_status -eq "clear")
Assert-True "timeline no live provider count" ([int]$timeline.live_provider_call_count -eq 0)
Assert-True "timeline no live mcp count" ([int]$timeline.live_mcp_write_count -eq 0)
Assert-True "timeline event parity" ([int]$timeline.events_scanned -eq [int]$snapshot.events_scanned)
Assert-True "timeline count parity" ([int]$timeline.timeline_count -eq @($timeline.timeline).Count)
Assert-True "timeline rollup parity" ([int]$timeline.events_scanned -eq [int]$rollup.events_scanned)

$lastIndex = 0
foreach ($event in @($timeline.timeline)) {
  Assert-True "timeline sequence monotonic" ([int]$event.sequence_index -gt $lastIndex)
  Assert-True "timeline leg safe" (@("agent_task", "llm_audit", "mcp_audit", "unknown") -contains [string]$event.timeline_leg)
  Assert-True "timeline no live provider event" ($event.live_provider_calls -eq $false)
  Assert-True "timeline no live mcp event" ($event.live_mcp_writes -eq $false)
  Assert-True "timeline redaction ref present" (-not [string]::IsNullOrWhiteSpace([string]$event.redaction_evidence_ref))
  Assert-True "timeline no-live-write ref present" (-not [string]::IsNullOrWhiteSpace([string]$event.no_live_write_evidence_ref))
  $lastIndex = [int]$event.sequence_index
}

if ($RequireFullCorrelation) {
  Assert-True "timeline has agent task leg" ([int]$timeline.timeline_leg_counts.agent_task -ge 1)
  Assert-True "timeline has llm audit leg" ([int]$timeline.timeline_leg_counts.llm_audit -ge 1)
  Assert-True "timeline has mcp audit leg" ([int]$timeline.timeline_leg_counts.mcp_audit -ge 1)
  Assert-True "snapshot full correlation present" ([int]$snapshot.full_correlation_count -ge 1)
  Assert-True "rollup full correlation present" ([int]$rollup.full_correlation_count -ge 1)
}

$timelineText = $timeline | ConvertTo-Json -Depth 30 -Compress
Assert-True "timeline no prompt body leak" (-not $timelineText.Contains("prompt_body"))
Assert-True "timeline no raw input ref leak" (-not $timelineText.Contains('"input_ref":'))
Assert-True "timeline no redaction probe leak" (-not $timelineText.Contains("redaction-proof-value"))
Assert-True "timeline no secret pattern leak" (-not ($timelineText -match "sk-proj-|github_pat_|ghp_|vck_|cfat_|hcloud_|hf_|glpat-"))

Write-Host "status=verified"
Write-Host "contract_version=gateway-correlation-timeline-v1"
Write-Host "evidence_ref=gateway_correlation_timeline_visible"
Write-Host "redaction_evidence_ref=gateway_correlation_redaction_enforced"
Write-Host "no_live_write_evidence_ref=gateway_correlation_no_live_write_guard"

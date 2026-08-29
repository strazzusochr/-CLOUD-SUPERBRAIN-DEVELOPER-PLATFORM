param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Go-live readiness verification failed: $label"
  }
}

function Assert-Contains($label, $items, [string]$expected) {
  $values = @($items | ForEach-Object { [string]$_ })
  if (-not ($values -contains $expected)) {
    throw "Go-live readiness verification failed: $label missing '$expected'. Actual: $($values -join ', ')"
  }
}

function Assert-NotContains($label, $items, [string]$unexpected) {
  $values = @($items | ForEach-Object { [string]$_ })
  if ($values -contains $unexpected) {
    throw "Go-live readiness verification failed: $label unexpectedly contained '$unexpected'."
  }
}

function Assert-NoSecretPattern($label, $value) {
  $text = $value | ConvertTo-Json -Depth 20 -Compress
  foreach ($pattern in @(
    "sk-[A-Za-z0-9_-]{20,}",
    "sk-ant-[A-Za-z0-9_-]{20,}",
    "xai-[A-Za-z0-9_-]{20,}",
    "vck_[A-Za-z0-9_-]{20,}",
    "ghp_[A-Za-z0-9_]{20,}",
    "BEGIN (RSA|OPENSSH|EC|PRIVATE) KEY"
  )) {
    if ([regex]::IsMatch($text, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
      throw "Go-live readiness verification failed: $label exposed forbidden secret-like pattern"
    }
  }
}

function Read-StrictBooleanProperty($label, $value, [string]$propertyName) {
  $property = $value.PSObject.Properties[$propertyName]
  Assert-True "$label property '$propertyName' exists" ($null -ne $property)
  Assert-True "$label property '$propertyName' is boolean" ($property.Value -is [System.Boolean])
  return [bool]$property.Value
}

function Invoke-Json($url) {
  try {
    return Invoke-RestMethod -Uri $url -Method GET -TimeoutSec 30
  } catch {
    throw "Go-live readiness verification failed: GET $url failed: $($_.Exception.Message)"
  }
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ((-not $AllowLocalhost) -and ($BaseUrl -match "localhost|127\.0\.0\.1|\[::1\]")) {
  throw "Go-live readiness proof refuses localhost unless -AllowLocalhost is set"
}

$progressManifest = Get-Content -Path "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$progressManifest.overall_percent
$summary = Get-Content -Path "docs\runtime-state\external-gate-summary.json" -Raw | ConvertFrom-Json
Assert-True "summary contract v2" ([string]$summary.contract_version -eq "external-gate-summary-v2")
Assert-True "summary source contract v2" ([string]$summary.source_contract_version -eq "external-gate-audit-v2")
Assert-True "summary active Cloudflare target" ([string]$summary.active_target_gate -eq "cloudflare_native_zero_card_hosted_runtime")
$canonicalExternalAuditClaimGates = [ordered]@{
  hosted_staging_claim_allowed = "hosted_agent_api_contracts"
  branch_protection_claim_allowed = "github_branch_protection_current_verify"
  ghcr_image_digest_claim_allowed = "ghcr_image_digest_verify"
  vercel_backend_origins_claim_allowed = "vercel_backend_origin_health"
  canonical_gitleaks_claim_allowed = "canonical_gitleaks_scan"
  cloudflare_native_zero_card_hosted_runtime_claim_allowed = "cloudflare_native_zero_card_hosted_runtime"
}
$canonicalExternalAuditGateIds = @($canonicalExternalAuditClaimGates.Values | ForEach-Object { [string]$_ })
Assert-True "summary canonical gate IDs exact order and case" ((@($summary.gate_ids | ForEach-Object { [string]$_ }) -join "|") -ceq ($canonicalExternalAuditGateIds -join "|"))
$externalAuditClaimValues = [ordered]@{}
foreach ($claimField in $canonicalExternalAuditClaimGates.Keys) {
  $externalAuditClaimValues[$claimField] = Read-StrictBooleanProperty "summary" $summary $claimField
}
$expectedExternalAuditMissingGates = @(
  $canonicalExternalAuditClaimGates.GetEnumerator() |
    Where-Object { -not $externalAuditClaimValues[$_.Key] } |
    ForEach-Object { [string]$_.Value }
)
$canonicalMissingGates = @($summary.missing_or_failed_gates | ForEach-Object { [string]$_ })
Assert-True "summary missing gates exact derived order, case, membership, and cardinality" (($canonicalMissingGates -join "|") -ceq ($expectedExternalAuditMissingGates -join "|"))
$expectedExternalAuditStatus = if ($expectedExternalAuditMissingGates.Count -eq 0) { "verified" } else { "blocked" }
Assert-True "summary status follows independently derived claims" ([string]$summary.status -ceq $expectedExternalAuditStatus)
$summaryProductionClaim = Read-StrictBooleanProperty "summary" $summary "production_deploy_claim_allowed"
$expectedExternalAuditProductionClaim = $expectedExternalAuditMissingGates.Count -eq 0
Assert-True "summary production claim follows all six canonical claims" ($summaryProductionClaim -eq $expectedExternalAuditProductionClaim)
$expectedRuntimeGateClaims = [ordered]@{
  ghcr_images = $externalAuditClaimValues.ghcr_image_digest_claim_allowed
  cloudflare_native_zero_card_hosted_runtime = $externalAuditClaimValues.cloudflare_native_zero_card_hosted_runtime_claim_allowed
  hosted_backend_origins = $externalAuditClaimValues.vercel_backend_origins_claim_allowed
  hosted_staging = $externalAuditClaimValues.hosted_staging_claim_allowed
  branch_protection = $externalAuditClaimValues.branch_protection_claim_allowed
  canonical_secret_scan = $externalAuditClaimValues.canonical_gitleaks_claim_allowed
}
$expectedRuntimeBlockedGates = @($expectedRuntimeGateClaims.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { [string]$_.Key })
$summaryVerified = $expectedExternalAuditStatus -eq "verified" -and $expectedExternalAuditMissingGates.Count -eq 0
$expectedRuntimeGateStatus = if ($summaryVerified -and $expectedRuntimeBlockedGates.Count -eq 0) { "verified" } else { "action_required" }
$expectedRuntimePreflightStatus = if ($expectedRuntimeBlockedGates.Count -gt 0) { "action_required" } elseif ($summaryVerified -and $summaryProductionClaim) { "verified" } else { "ready_for_external_execution" }

Write-Host "[go-live-readiness] runtime contract"
$readiness = Invoke-Json "$BaseUrl/api/v1/clouds/go-live-readiness"
$contract = Invoke-Json "$BaseUrl/api/v1/clouds/go-live-readiness/contract"
Assert-NoSecretPattern "runtime readiness" $readiness
Assert-NoSecretPattern "runtime readiness contract" $contract

Assert-True "readiness contract version" ($readiness.contract_version -eq "go-live-readiness-v1")
Assert-True "readiness status supported" (@("blocked_external_gates", "ready_for_owner_cloud_execution") -contains [string]$readiness.status)
Assert-True "overall percent parity" ([int]$readiness.overall_percent -eq $expectedOverall)
Assert-True "workspace page count" ([int]$readiness.workspace_page_count -eq 22)
Assert-True "cloud layer count" ([int]$readiness.cloud_layer_total_count -eq 7)
Assert-True "external audit required" ($readiness.external_audit_required -eq $true)
Assert-True "owner activation plan-only" ($readiness.owner_activation.default_mode -eq "PlanOnly")
Assert-True "owner activation plan contract v2" ($readiness.owner_activation.plan_contract -eq "owner-cloud-gate-activation-plan-v2")
Assert-True "owner apply not allowed in Codex" ($readiness.owner_activation.apply_allowed_in_codex -eq $false)
if ($readiness.external_audit_claims.cloudflare_native_zero_card_hosted_runtime_claim_allowed -eq $false) {
  foreach ($requiredInput in @(
    "CLOUDFLARE_ACCOUNT_ID",
    "CLOUDFLARE_API_TOKEN",
    "CLOUDFLARE_STATEFUL_BASE_URL"
  )) {
    Assert-Contains "required Cloudflare owner inputs" $readiness.required_owner_inputs $requiredInput
  }
  foreach ($requiredScope in @(
    "workers_scripts_edit",
    "d1_edit",
    "durable_objects_edit",
    "queues_edit"
  )) {
    Assert-Contains "required Cloudflare owner scopes" $readiness.required_owner_scopes $requiredScope
  }
}
if ($readiness.external_audit_claims.hosted_staging_claim_allowed -eq $false) {
  Assert-Contains "required owner inputs" $readiness.required_owner_inputs "STAGING_BASE_URL"
}
if ($readiness.external_audit_claims.vercel_backend_origins_claim_allowed -eq $false) {
  Assert-Contains "required owner inputs" $readiness.required_owner_inputs "AGENT_API_BASE_URL"
  Assert-Contains "required owner inputs" $readiness.required_owner_inputs "MCP_GATEWAY_BASE_URL"
  Assert-Contains "required owner inputs" $readiness.required_owner_inputs "LLM_GATEWAY_BASE_URL"
}
Assert-True "runtime preflight status follows canonical summary" ([string]$readiness.runtime_preflight_status -eq $expectedRuntimePreflightStatus)
Assert-True "runtime preflight blocker parity" ((@($readiness.runtime_preflight_missing_or_blocked_gates | Sort-Object) -join ",") -eq (@($expectedRuntimeBlockedGates | Sort-Object) -join ","))
Assert-True "runtime external gate status follows canonical summary" ([string]$readiness.runtime_external_gate_status -eq $expectedRuntimeGateStatus)
Assert-True "runtime external blocker parity" ((@($readiness.runtime_external_blocked_release_gates | Sort-Object) -join ",") -eq (@($expectedRuntimeBlockedGates | Sort-Object) -join ","))
Assert-True "external audit summary configured" ($readiness.external_audit_summary.configured -eq $true)
Assert-True "external audit summary contract" ($readiness.external_audit_summary.contract_version -eq "external-gate-summary-v2")
Assert-True "external audit source contract" ($readiness.external_audit_summary.source_contract_version -eq "external-gate-audit-v2")
Assert-True "runtime active Cloudflare target" ($readiness.external_audit_summary.active_target_gate -eq "cloudflare_native_zero_card_hosted_runtime")
Assert-True "external audit summary status supported" (@("blocked", "verified") -contains [string]$readiness.external_audit_summary_status)
foreach ($claimField in $canonicalExternalAuditClaimGates.Keys) {
  $runtimeClaim = Read-StrictBooleanProperty "runtime external audit claims" $readiness.external_audit_claims $claimField
  Assert-True "runtime external audit claim '$claimField' parity" ($runtimeClaim -eq $externalAuditClaimValues[$claimField])
}
$runtimeProductionClaim = Read-StrictBooleanProperty "runtime external audit claims" $readiness.external_audit_claims "production_deploy_claim_allowed"
Assert-True "external audit production claim parity" ($runtimeProductionClaim -eq $summaryProductionClaim)
$runtimeMissingGates = @($readiness.external_audit_missing_or_failed_gates | ForEach-Object { [string]$_ })
$runtimeExpectedMissingGates = @($readiness.external_audit_expected_missing_or_failed_gates | ForEach-Object { [string]$_ })
Assert-True "runtime external audit missing-set exact parity" (($runtimeMissingGates -join "|") -ceq ($canonicalMissingGates -join "|"))
Assert-True "runtime independently derived missing-set exact parity" (($runtimeExpectedMissingGates -join "|") -ceq ($expectedExternalAuditMissingGates -join "|"))
$runtimeSummaryConsistent = Read-StrictBooleanProperty "runtime readiness" $readiness "external_audit_summary_consistent"
Assert-True "runtime external audit summary consistency" $runtimeSummaryConsistent
Assert-True "runtime external audit consistency errors empty" (@($readiness.external_audit_summary_consistency_errors).Count -eq 0)
Assert-True "runtime expected external audit status" ([string]$readiness.external_audit_expected_status -ceq $expectedExternalAuditStatus)
$runtimeExpectedProductionClaim = Read-StrictBooleanProperty "runtime readiness" $readiness "external_audit_expected_production_deploy_claim_allowed"
Assert-True "runtime expected production claim" ($runtimeExpectedProductionClaim -eq $expectedExternalAuditProductionClaim)
$runtimeProvenanceValid = Read-StrictBooleanProperty "runtime sanitized summary" $readiness.external_audit_summary "provenance_valid"
Assert-True "runtime sanitized summary provenance valid" $runtimeProvenanceValid
Assert-True "runtime sanitized summary provenance errors empty" (@($readiness.external_audit_summary.provenance_validation_errors).Count -eq 0)
Assert-True "runtime canonical gate IDs exact parity" ((@($readiness.external_audit_summary.gate_ids | ForEach-Object { [string]$_ }) -join "|") -ceq ($canonicalExternalAuditGateIds -join "|"))
if ($readiness.external_audit_claims.hosted_staging_claim_allowed -eq $true) {
  Assert-NotContains "runtime hosted Agent API gate closed" $readiness.external_audit_missing_or_failed_gates "hosted_agent_api_contracts"
} else {
  Assert-Contains "runtime external audit missing gate" $readiness.external_audit_missing_or_failed_gates "hosted_agent_api_contracts"
}
if ($readiness.external_audit_claims.vercel_backend_origins_claim_allowed -eq $true) {
  Assert-NotContains "runtime Vercel origin gate closed" $readiness.external_audit_missing_or_failed_gates "vercel_backend_origin_health"
} else {
  Assert-Contains "runtime external audit missing gate" $readiness.external_audit_missing_or_failed_gates "vercel_backend_origin_health"
}
if ($readiness.external_audit_claims.branch_protection_claim_allowed -eq $false) {
  Assert-Contains "runtime external audit missing gate" $readiness.external_audit_missing_or_failed_gates "github_branch_protection_current_verify"
  Assert-Contains "required owner inputs" $readiness.required_owner_inputs "BRANCH_PROTECTION_TOKEN"
} else {
  Assert-NotContains "runtime branch protection gate closed" $readiness.external_audit_missing_or_failed_gates "github_branch_protection_current_verify"
}
if ($readiness.external_audit_claims.cloudflare_native_zero_card_hosted_runtime_claim_allowed -eq $false) {
  Assert-Contains "runtime external audit missing gate" $readiness.external_audit_missing_or_failed_gates "cloudflare_native_zero_card_hosted_runtime"
} else {
  Assert-NotContains "runtime Cloudflare-native gate closed" $readiness.external_audit_missing_or_failed_gates "cloudflare_native_zero_card_hosted_runtime"
}
Assert-NotContains "runtime active external audit excludes retired Fly gate" $readiness.external_audit_missing_or_failed_gates "fly_live_budget_check"

Assert-True "contract version" ($contract.contract_version -eq "go-live-readiness-surface-v1")
Assert-True "contract runtime endpoint" ($contract.runtime_endpoint -eq "GET /api/v1/clouds/go-live-readiness")
Assert-Contains "contract guarded endpoint" $contract.guarded_endpoints "GET /api/v1/project/progress/completion"
Assert-Contains "contract guarded endpoint" $contract.guarded_endpoints "GET /api/v1/external-gates"
Assert-Contains "contract canonical missing-set alias" $contract.required_top_level_fields "external_audit_expected_missing_or_failed_gates"
Assert-Contains "contract required verifier" $contract.required_verifiers "scripts/verify-external-gates.ps1"

Write-Host "[go-live-readiness] canonical standard external gate audit"
$canonicalAuditPath = Join-Path (Get-Location) ([string]$summary.source_artifact)
Assert-True "canonical external audit artifact exists" (Test-Path -LiteralPath $canonicalAuditPath)
$canonicalAuditRelativePath = ([string]$summary.source_artifact).Replace("\", "/")
Assert-True "canonical audit uses durable v2 path" ($canonicalAuditRelativePath -eq "docs/runtime-state/external-gate-audit-v2.json")
$trackedAuditPath = git ls-files --error-unmatch -- $canonicalAuditRelativePath 2>$null
Assert-True "canonical audit is tracked" ($LASTEXITCODE -eq 0 -and @($trackedAuditPath).Count -eq 1)
$canonicalAudit = Get-Item -LiteralPath $canonicalAuditPath
$audit = Get-Content -LiteralPath $canonicalAudit.FullName -Raw | ConvertFrom-Json
Assert-NoSecretPattern "external gate audit" $audit
Assert-True "external audit contract" ($audit.contract_version -eq "external-gate-audit-v2")
Assert-True "external audit active Cloudflare target" ($audit.active_target_gate -eq "cloudflare_native_zero_card_hosted_runtime")
Assert-True "external audit status supported" (@("blocked", "verified") -contains [string]$audit.status)
if ($audit.status -eq "verified") {
  Assert-True "verified external audit has no missing gates" (@($audit.missing_or_failed_gates).Count -eq 0)
}
if ($audit.hosted_staging_claim_allowed -eq $true) {
  Assert-NotContains "external audit hosted Agent API gate closed" $audit.missing_or_failed_gates "hosted_agent_api_contracts"
} else {
  Assert-Contains "external audit missing gate" $audit.missing_or_failed_gates "hosted_agent_api_contracts"
}
if ($audit.vercel_backend_origins_claim_allowed -eq $true) {
  Assert-NotContains "external audit Vercel origin gate closed" $audit.missing_or_failed_gates "vercel_backend_origin_health"
} else {
  Assert-Contains "external audit missing gate" $audit.missing_or_failed_gates "vercel_backend_origin_health"
}
if ($audit.branch_protection_claim_allowed -eq $false) {
  Assert-Contains "external audit missing gate" $audit.missing_or_failed_gates "github_branch_protection_current_verify"
} else {
  Assert-NotContains "external audit branch protection gate closed" $audit.missing_or_failed_gates "github_branch_protection_current_verify"
}
if ($audit.cloudflare_native_zero_card_hosted_runtime_claim_allowed -eq $false) {
  Assert-Contains "external audit missing gate" $audit.missing_or_failed_gates "cloudflare_native_zero_card_hosted_runtime"
} else {
  Assert-NotContains "external audit Cloudflare-native gate closed" $audit.missing_or_failed_gates "cloudflare_native_zero_card_hosted_runtime"
}
Assert-NotContains "external audit active blockers exclude retired Fly gate" $audit.missing_or_failed_gates "fly_live_budget_check"
Assert-True "external audit has no active Fly claim field" (-not ($audit.PSObject.Properties.Name -contains "fly_live_budget_claim_allowed"))
if (-not [string]::IsNullOrWhiteSpace([string]$audit.local_run_artifact)) {
  $localRunArtifact = ([string]$audit.local_run_artifact).Replace("\", "/")
  Assert-True "optional local run artifact pattern" ($localRunArtifact -match '^\.phase1-artifacts/external-gate-audit-v2-\d{8}-\d{6}\.json$')
}

Write-Host "[go-live-readiness] sanitized external gate summary"
Assert-NoSecretPattern "sanitized external gate summary" $summary
Assert-True "summary contract" ($summary.contract_version -eq "external-gate-summary-v2")
Assert-True "summary source contract parity" ($summary.source_contract_version -eq $audit.contract_version)
Assert-True "summary active target parity" ($summary.active_target_gate -eq $audit.active_target_gate)
Assert-True "summary status" ($summary.status -eq $audit.status)
Assert-True "summary production claim parity" ($summary.production_deploy_claim_allowed -eq $audit.production_deploy_claim_allowed)
Assert-True "summary audit timestamp parity" ($summary.generated_at_utc -eq $audit.generated_at_utc)
Assert-True "summary source artifact points to canonical audit" ([System.IO.Path]::GetFileName([string]$summary.source_artifact) -eq $canonicalAudit.Name)
if ($summary.hosted_staging_claim_allowed -eq $true) {
  Assert-NotContains "summary hosted Agent API gate closed" $summary.missing_or_failed_gates "hosted_agent_api_contracts"
} else {
  Assert-Contains "summary missing gate" $summary.missing_or_failed_gates "hosted_agent_api_contracts"
}
if ($summary.vercel_backend_origins_claim_allowed -eq $true) {
  Assert-NotContains "summary Vercel origin gate closed" $summary.missing_or_failed_gates "vercel_backend_origin_health"
} else {
  Assert-Contains "summary missing gate" $summary.missing_or_failed_gates "vercel_backend_origin_health"
}
if ($summary.branch_protection_claim_allowed -eq $false) {
  Assert-Contains "summary missing gate" $summary.missing_or_failed_gates "github_branch_protection_current_verify"
} else {
  Assert-NotContains "summary branch protection gate closed" $summary.missing_or_failed_gates "github_branch_protection_current_verify"
}
if ($summary.cloudflare_native_zero_card_hosted_runtime_claim_allowed -eq $false) {
  Assert-Contains "summary missing gate" $summary.missing_or_failed_gates "cloudflare_native_zero_card_hosted_runtime"
} else {
  Assert-NotContains "summary Cloudflare-native gate closed" $summary.missing_or_failed_gates "cloudflare_native_zero_card_hosted_runtime"
}
Assert-NotContains "summary active blockers exclude retired Fly gate" $summary.missing_or_failed_gates "fly_live_budget_check"
Assert-True "summary has no active Fly claim field" (-not ($summary.PSObject.Properties.Name -contains "fly_live_budget_claim_allowed"))
Assert-True "summary legacy Fly provenance is historical" (
  [string]$summary.legacy_provenance.status -eq "historical_only" -and
  [string]$summary.legacy_provenance.retired_gate_id -eq "fly_live_budget_check"
)

Write-Host "[go-live-readiness] artifact=$($canonicalAudit.FullName)"
Write-Host "[go-live-readiness] status=$($readiness.status)"
Write-Host "[go-live-readiness] checks completed"

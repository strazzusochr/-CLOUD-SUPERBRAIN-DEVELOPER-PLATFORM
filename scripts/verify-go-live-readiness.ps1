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
$expectedRuntimeGateClaims = [ordered]@{
  ghcr_images = [bool]$summary.ghcr_image_digest_claim_allowed
  fly_cloud_stack = [bool]$summary.fly_live_budget_claim_allowed
  hosted_backend_origins = [bool]$summary.vercel_backend_origins_claim_allowed
  hosted_staging = [bool]$summary.hosted_staging_claim_allowed
  branch_protection = [bool]$summary.branch_protection_claim_allowed
  canonical_secret_scan = [bool]$summary.canonical_gitleaks_claim_allowed
}
$expectedRuntimeBlockedGates = @($expectedRuntimeGateClaims.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { [string]$_.Key })
$summaryVerified = [string]$summary.status -eq "verified" -and @($summary.missing_or_failed_gates).Count -eq 0
$expectedRuntimeGateStatus = if ($summaryVerified -and $expectedRuntimeBlockedGates.Count -eq 0) { "verified" } else { "action_required" }
$expectedRuntimePreflightStatus = if ($expectedRuntimeBlockedGates.Count -gt 0) { "action_required" } elseif ($summaryVerified -and [bool]$summary.production_deploy_claim_allowed) { "verified" } else { "ready_for_external_execution" }

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
Assert-True "owner apply not allowed in Codex" ($readiness.owner_activation.apply_allowed_in_codex -eq $false)
if ($readiness.external_audit_claims.fly_live_budget_claim_allowed -eq $false) {
  Assert-Contains "required owner inputs" $readiness.required_owner_inputs "FLY_API_TOKEN"
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
Assert-True "external audit summary contract" ($readiness.external_audit_summary.contract_version -eq "external-gate-summary-v1")
Assert-True "external audit summary status supported" (@("blocked", "verified") -contains [string]$readiness.external_audit_summary_status)
Assert-True "external audit production claim parity" ($readiness.external_audit_claims.production_deploy_claim_allowed -eq [bool]$readiness.external_audit_summary.production_deploy_claim_allowed)
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
if ($readiness.external_audit_claims.fly_live_budget_claim_allowed -eq $false) {
  Assert-Contains "runtime external audit missing gate" $readiness.external_audit_missing_or_failed_gates "fly_live_budget_check"
} else {
  Assert-NotContains "runtime Fly budget gate closed" $readiness.external_audit_missing_or_failed_gates "fly_live_budget_check"
}

Assert-True "contract version" ($contract.contract_version -eq "go-live-readiness-surface-v1")
Assert-True "contract runtime endpoint" ($contract.runtime_endpoint -eq "GET /api/v1/clouds/go-live-readiness")
Assert-Contains "contract guarded endpoint" $contract.guarded_endpoints "GET /api/v1/project/progress/completion"
Assert-Contains "contract guarded endpoint" $contract.guarded_endpoints "GET /api/v1/external-gates"
Assert-Contains "contract required verifier" $contract.required_verifiers "scripts/verify-external-gates.ps1"

Write-Host "[go-live-readiness] canonical standard external gate audit"
$canonicalAuditPath = Join-Path (Get-Location) ([string]$summary.source_artifact)
Assert-True "canonical external audit artifact exists" (Test-Path -LiteralPath $canonicalAuditPath)
$canonicalAudit = Get-Item -LiteralPath $canonicalAuditPath
$audit = Get-Content -LiteralPath $canonicalAudit.FullName -Raw | ConvertFrom-Json
Assert-NoSecretPattern "external gate audit" $audit
Assert-True "external audit contract" ($audit.contract_version -eq "external-gate-audit-v1")
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
if ($audit.fly_live_budget_claim_allowed -eq $false) {
  Assert-Contains "external audit missing gate" $audit.missing_or_failed_gates "fly_live_budget_check"
} else {
  Assert-NotContains "external audit Fly budget gate closed" $audit.missing_or_failed_gates "fly_live_budget_check"
}

Write-Host "[go-live-readiness] sanitized external gate summary"
Assert-NoSecretPattern "sanitized external gate summary" $summary
Assert-True "summary contract" ($summary.contract_version -eq "external-gate-summary-v1")
Assert-True "summary source contract parity" ($summary.source_contract_version -eq $audit.contract_version)
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
if ($summary.fly_live_budget_claim_allowed -eq $false) {
  Assert-Contains "summary missing gate" $summary.missing_or_failed_gates "fly_live_budget_check"
} else {
  Assert-NotContains "summary Fly budget gate closed" $summary.missing_or_failed_gates "fly_live_budget_check"
}

Write-Host "[go-live-readiness] artifact=$($canonicalAudit.FullName)"
Write-Host "[go-live-readiness] status=$($readiness.status)"
Write-Host "[go-live-readiness] checks completed"

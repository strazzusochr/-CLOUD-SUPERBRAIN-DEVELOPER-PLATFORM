$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Verification failed: $label did not contain '$expected'."
  }
}

function Assert-NotRegex($label, $value, $pattern) {
  $text = ($value | Out-String)
  if ([regex]::IsMatch($text, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
    throw "Verification failed: $label matched forbidden pattern '$pattern'."
  }
}

Write-Host "[verify-owner-cloud-gate] static contract"
if (-not (Test-Path "scripts\owner-cloud-gate-activation.ps1")) {
  throw "Missing owner cloud gate activation script"
}
if (-not (Test-Path "docs\runbooks\cloud-gate-owner-activation-2026-06-09.md")) {
  throw "Missing owner cloud gate activation runbook"
}

$script = Get-Content -Path "scripts\owner-cloud-gate-activation.ps1" -Raw
$runbook = Get-Content -Path "docs\runbooks\cloud-gate-owner-activation-2026-06-09.md" -Raw

foreach ($required in @(
  "owner-cloud-gate-activation-plan-v2",
  "PlanOnly",
  "OwnerGate",
  "-Apply requires -OwnerGate",
  "cloudflare_native_zero_card_hosted_runtime",
  "cloud_mutation_default",
  "hosted_writes_default",
  "presence-only; never print token values",
  "Assert-CloudHttpsUrl",
  "Test-RetiredHostedBaseUrl",
  "STAGING_BASE_URL",
  "CLOUDFLARE_STATEFUL_BASE_URL",
  "CLOUDFLARE_ACCOUNT_ID",
  "CLOUDFLARE_API_TOKEN",
  "Workers Scripts:Edit",
  "D1:Edit",
  "Durable Objects:Edit",
  "Queues:Edit",
  "Workers AI:Read",
  "R2:Edit",
  "Workers AI:Read",
  "R2:Edit only if zero-card activation is verified",
  "workers_scripts_edit",
  "workers_ai_read",
  "r2_edit_if_zero_card_verified",
  "zero_card_activation",
  "hosted_write_approval",
  "VERCEL_TOKEN",
  "GHCR_TOKEN",
  "BRANCH_PROTECTION_TOKEN",
  "verify-cloudflare-stateful-runtime.ps1",
  "-AllowHostedWrites",
  "verify-browser-contract.ps1",
  "verify-external-gates.ps1",
  "no gate closure without hosted verifier artifact",
  "no percentage credit from this plan",
  "O6 bounded live LLM is already owner_granted and live_verified",
  "historical_only"
)) {
  Assert-Contains "owner activation script" $script $required
}

foreach ($required in @(
  "Owner Cloud Gate Activation",
  "Plan-only by default",
  "No secret values",
  "external-gate-summary-v2",
  "external-gate-audit-v2",
  "cloudflare_native_zero_card_hosted_runtime",
  "Cloudflare HTTPS",
  "Vercel HTTPS staging",
  "CLOUDFLARE_STATEFUL_BASE_URL",
  "CLOUDFLARE_ACCOUNT_ID",
  "CLOUDFLARE_API_TOKEN",
  "Workers Scripts:Edit",
  "D1:Edit",
  "Durable Objects:Edit",
  "Queues:Edit",
  "AllowHostedWrites",
  "fail-closed",
  "O6 is not an Owner-required action",
  "Layer 4 equal 100",
  "historical_only",
  "No progress percentage changes"
)) {
  Assert-Contains "owner activation runbook" $runbook $required
}

Assert-NotRegex "owner activation script" $script "sk-[A-Za-z0-9_-]{20,}"
Assert-NotRegex "owner activation script" $script "xai-[A-Za-z0-9_-]{20,}"
Assert-NotRegex "owner activation script" $script "vck_[A-Za-z0-9_-]{20,}"
Assert-NotRegex "owner activation script" $script "--token"
Assert-NotRegex "owner activation script" $script 'Write-Host\s+\$env:[A-Z0-9_]*TOKEN'
Assert-NotRegex "owner activation script" $script "188-34-191-140\.sslip\.io"
Assert-NotRegex "owner activation runbook" $runbook "188-34-191-140\.sslip\.io"
Assert-NotRegex "owner activation script" $script "FLY_API_TOKEN"
Assert-NotRegex "owner activation script" $script "fly_live_budget"
Assert-NotRegex "owner activation script" $script "fly deploy"
Assert-NotRegex "owner activation runbook active requirements" $runbook "Required Owner Inputs[\s\S]*FLY_API_TOKEN"

$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\owner-cloud-gate-activation.ps1",
  [ref]$null,
  [ref]$parseErrors
) | Out-Null
if ($parseErrors -and $parseErrors.Count -gt 0) {
  $parseErrors | ForEach-Object { Write-Error $_.Message }
  throw "Owner cloud gate activation script has parse errors"
}

$verifyArtifact = ".phase1-artifacts\owner-cloud-gate-activation-verify.json"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\owner-cloud-gate-activation.ps1 `
  -StagingBaseUrl "https://staging.example.invalid" `
  -CloudflareStatefulBaseUrl "https://stateful.example.invalid" `
  -ArtifactPath $verifyArtifact | Out-Null

if ($LASTEXITCODE -ne 0) {
  throw "Owner cloud gate activation plan-only run failed"
}

$plan = Get-Content -Path $verifyArtifact -Raw | ConvertFrom-Json
if ($plan.contract -ne "owner-cloud-gate-activation-plan-v2") {
  throw "Plan artifact has wrong contract"
}
if ($plan.mode -ne "PlanOnly") {
  throw "Plan artifact must default to PlanOnly"
}
if ($plan.apply_allowed -ne $false) {
  throw "Plan artifact must not allow apply by default"
}
if ($plan.active_target_gate -ne "cloudflare_native_zero_card_hosted_runtime") {
  throw "Plan artifact has wrong active target"
}
if ($plan.required_origins.CLOUDFLARE_STATEFUL_BASE_URL -ne "https://stateful.example.invalid") {
  throw "Plan artifact did not preserve CLOUDFLARE_STATEFUL_BASE_URL"
}
if ($plan.hosted_writes_default -ne "disabled") {
  throw "Plan artifact must keep hosted writes disabled"
}
if ($plan.required_owner_scope_attestations.hosted_write_approval -ne $false) {
  throw "Plan artifact must keep hosted write approval fail-closed"
}
if ($plan.required_owner_scope_attestations.zero_card_activation -ne $false) {
  throw "Plan artifact must keep zero-card activation fail-closed"
}
if ([int](@($plan.non_claims | Where-Object { $_ -eq "no percentage credit from this plan" }).Count) -ne 1) {
  throw "Plan artifact must deny percentage credit"
}

Write-Host "[verify-owner-cloud-gate] checks completed"

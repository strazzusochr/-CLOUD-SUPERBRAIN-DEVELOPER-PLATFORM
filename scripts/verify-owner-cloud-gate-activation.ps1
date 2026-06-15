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
  "owner-cloud-gate-activation-plan-v1",
  "PlanOnly",
  "OwnerGate",
  "-Apply requires -OwnerGate",
  "cloud_mutation_default",
  "presence-only; never print token values",
  "Assert-CloudHttpsUrl",
  "Test-RetiredHostedBaseUrl",
  "STAGING_REWRITES_ENABLED",
  "STAGING_BASE_URL",
  "AGENT_API_BASE_URL",
  "MCP_GATEWAY_BASE_URL",
  "LLM_GATEWAY_BASE_URL",
  "VERCEL_TOKEN",
  "FLY_API_TOKEN",
  "GHCR_TOKEN",
  "BRANCH_PROTECTION_TOKEN",
  "fly.agent-api.toml",
  "fly.mcp-gateway.toml",
  "fly.llm-gateway.toml",
  "verify-browser-contract.ps1",
  "verify-external-gates.ps1",
  "no gate closure without hosted verifier artifact"
)) {
  Assert-Contains "owner activation script" $script $required
}

foreach ($required in @(
  "Owner Cloud Gate Activation",
  "Plan-only by default",
  "No secret values",
  "Vercel HTTPS staging",
  "Fly.io origins",
  "AGENT_API_BASE_URL",
  "MCP_GATEWAY_BASE_URL",
  "LLM_GATEWAY_BASE_URL",
  "hosted_agent_api_contracts",
  "vercel_backend_origin_health",
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
  -AgentApiBaseUrl "https://agent.example.invalid" `
  -McpGatewayBaseUrl "https://mcp.example.invalid" `
  -LlmGatewayBaseUrl "https://llm.example.invalid" `
  -ArtifactPath $verifyArtifact | Out-Null

if ($LASTEXITCODE -ne 0) {
  throw "Owner cloud gate activation plan-only run failed"
}

$plan = Get-Content -Path $verifyArtifact -Raw | ConvertFrom-Json
if ($plan.contract -ne "owner-cloud-gate-activation-plan-v1") {
  throw "Plan artifact has wrong contract"
}
if ($plan.mode -ne "PlanOnly") {
  throw "Plan artifact must default to PlanOnly"
}
if ($plan.apply_allowed -ne $false) {
  throw "Plan artifact must not allow apply by default"
}
if ($plan.required_origins.AGENT_API_BASE_URL -ne "https://agent.example.invalid") {
  throw "Plan artifact did not preserve AGENT_API_BASE_URL"
}

Write-Host "[verify-owner-cloud-gate] checks completed"

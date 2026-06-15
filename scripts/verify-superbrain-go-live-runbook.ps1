$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Verification failed: $label did not contain '$expected'."
  }
}

function Assert-NotContains($label, $value, $forbidden) {
  $text = ($value | Out-String)
  if ($text.Contains($forbidden)) {
    throw "Verification failed: $label contained forbidden text '$forbidden'."
  }
}

function Assert-NotRegex($label, $value, $pattern) {
  $text = ($value | Out-String)
  if ([regex]::IsMatch($text, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
    throw "Verification failed: $label matched forbidden pattern '$pattern'."
  }
}

Write-Host "[verify-go-live-runbook] static contract"

if (-not (Test-Path "docs\SUPERBRAIN_GO_LIVE.md")) {
  throw "Missing docs\SUPERBRAIN_GO_LIVE.md"
}
if (-not (Test-Path "apps\frontend\package.json")) {
  throw "Missing apps\frontend\package.json"
}

$runbook = Get-Content -Path "docs\SUPERBRAIN_GO_LIVE.md" -Raw
$packageJson = Get-Content -Path "apps\frontend\package.json" -Raw | ConvertFrom-Json

foreach ($required in @(
  "owner-gated",
  "read-only prepared",
  "Projekt-AGENTS.md",
  "keine Cloud-Mutation",
  "keinen Deploy",
  "keinen Registry-Push",
  "keine Live-Provider-Aktivierung",
  "keinen MCP-Write",
  "kein Production-Claim",
  "DEV-ONLY",
  "Vercel Frontend",
  "Fly.io Runtime",
  "GHCR Registry",
  "Grafana Cloud Observability",
  "Retired/historical only: Hetzner, GitKraken, Oracle",
  "external-gate-summary-v1",
  "GET /api/v1/clouds/go-live-readiness",
  "hosted_agent_api_contracts",
  "github_branch_protection_current_verify",
  "vercel_backend_origin_health",
  "fly_live_budget_check",
  "STAGING_BASE_URL",
  "AGENT_API_BASE_URL",
  "MCP_GATEWAY_BASE_URL",
  "LLM_GATEWAY_BASE_URL",
  "BRANCH_PROTECTION_TOKEN",
  "FLY_API_TOKEN",
  "presence-only",
  "Secret output bleibt dauerhaft geschlossen",
  "Keine Fortschrittsprozente steigen"
)) {
  Assert-Contains "go-live runbook" $runbook $required
}

$versionRequirements = @{
  "next" = $packageJson.dependencies.next
  "react" = $packageJson.dependencies.react
  "react-dom" = $packageJson.dependencies."react-dom"
  "three" = $packageJson.dependencies.three
  "@react-three/fiber" = $packageJson.dependencies."@react-three/fiber"
  "@react-three/drei" = $packageJson.dependencies."@react-three/drei"
  "@react-three/postprocessing" = $packageJson.dependencies."@react-three/postprocessing"
  "@playwright/test" = $packageJson.devDependencies."@playwright/test"
  "typescript" = $packageJson.devDependencies.typescript
}

foreach ($name in $versionRequirements.Keys) {
  $expected = "${name}: $($versionRequirements[$name])"
  Assert-Contains "go-live runbook version baseline" $runbook $expected
}

foreach ($forbidden in @(
  "Gates sind nicht mehr `"fuer immer zu`"",
  "Supervisor die noetigen Gates",
  "Die globale Lock-Regel gilt hier NICHT",
  "Opus 4.8 = Supervisor",
  "Next.js 16.2.6",
  "React 19.2.6",
  "STAGING_REWRITES_ENABLED=false",
  "alle 8 Gates closed",
  "Die Plattform IST gebaut und deployed"
)) {
  Assert-NotContains "go-live runbook" $runbook $forbidden
}

Assert-NotRegex "go-live runbook" $runbook "sk-[A-Za-z0-9_-]{20,}"
Assert-NotRegex "go-live runbook" $runbook "xai-[A-Za-z0-9_-]{20,}"
Assert-NotRegex "go-live runbook" $runbook "vck_[A-Za-z0-9_-]{20,}"
Assert-NotRegex "go-live runbook" $runbook "188-34-191-140\.sslip\.io"

Write-Host "[verify-go-live-runbook] checks completed"

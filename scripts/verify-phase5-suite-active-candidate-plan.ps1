param()

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Verification failed: $label did not contain '$expected'."
  }
}

function Assert-NotContains($label, $value, $unexpected) {
  $text = ($value | Out-String)
  if ($text.Contains($unexpected)) {
    throw "Verification failed: $label unexpectedly contained '$unexpected'."
  }
}

$configPath = "docs\release-artifacts\current-release-candidate.json"
if (-not (Test-Path -LiteralPath $configPath)) {
  throw "Missing current release candidate config: $configPath"
}

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$activeReleaseId = [string]$config.active_release_id
if ([string]::IsNullOrWhiteSpace($activeReleaseId)) {
  throw "Verification failed: active_release_id is missing from $configPath."
}
if ($activeReleaseId -eq "prod-candidate-2026-05-05-rc1") {
  throw "Verification failed: active release candidate still points at retired historical RC1."
}

$plan = & "$PSScriptRoot\verify.ps1" -Suite phase5 -Plan *>&1 | Out-String
if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
  throw "Verification failed: phase5 suite plan exited with code $LASTEXITCODE."
}

Assert-Contains "phase5 plan active candidate default" $plan "verify-phase5-candidate.ps1 (default parameters)"
Assert-NotContains "phase5 plan active candidate stale override" $plan "verify-phase5-candidate.ps1 -ReleaseId prod-candidate-2026-05-05-rc1"
Assert-Contains "phase5 plan active candidate rerun proof" $plan "verify-phase5-active-candidate-gate-rerun.ps1 (default parameters)"
Assert-Contains "phase5 plan active runtime proof" $plan "verify-phase5-active-runtime-evidence-bundle.ps1 (default parameters)"
Assert-Contains "phase5 plan active security proof" $plan "verify-phase5-active-security-evidence-bundle.ps1 (default parameters)"
Assert-Contains "phase5 plan active runtime guard matrix proof" $plan "verify-phase5-active-runtime-guard-matrix-bundle.ps1 (default parameters)"
Assert-Contains "phase5 plan active gateway execution proof" $plan "verify-phase5-active-gateway-execution-bundle.ps1 (default parameters)"
Assert-Contains "phase5 plan active memory operations proof" $plan "verify-phase5-active-memory-operations-bundle.ps1 (default parameters)"
Assert-Contains "phase5 plan active memory success correlation proof" $plan "verify-phase5-active-memory-success-correlation-bundle.ps1 (default parameters)"
Assert-Contains "phase5 plan active agent operations proof" $plan "verify-phase5-active-agent-operations-bundle.ps1 (default parameters)"
Assert-Contains "phase5 plan active agent success correlation proof" $plan "verify-phase5-active-agent-success-correlation-bundle.ps1 (default parameters)"
Assert-Contains "phase5 plan active LLM operations proof" $plan "verify-phase5-active-llm-operations-bundle.ps1 (default parameters)"
Assert-Contains "phase5 plan active LLM success correlation proof" $plan "verify-phase5-active-llm-success-correlation-bundle.ps1 (default parameters)"
Assert-Contains "phase5 plan active LLM guard correlation proof" $plan "verify-phase5-active-llm-guard-correlation-bundle.ps1 (default parameters)"
Assert-Contains "phase5 plan active MCP operations proof" $plan "verify-phase5-active-mcp-operations-bundle.ps1 (default parameters)"
Assert-Contains "phase5 plan active MCP success correlation proof" $plan "verify-phase5-active-mcp-success-correlation-bundle.ps1 (default parameters)"
Assert-Contains "phase5 plan active MCP guard correlation proof" $plan "verify-phase5-active-mcp-guard-correlation-bundle.ps1 (default parameters)"
Assert-Contains "phase5 plan active frontend-orchestrator proof" $plan "verify-phase5-active-frontend-orchestrator-evidence-bundle.ps1 (default parameters)"
Assert-Contains "phase5 plan active observability rebaseline proof" $plan "verify-phase5-active-observability-rebaseline-bundle.ps1 (default parameters)"
Assert-Contains "phase5 plan active verifier sweep proof" $plan "verify-phase5-active-verifier-sweep-bundle.ps1 (default parameters)"
Assert-Contains "phase5 plan active full-suite rebaseline proof" $plan "verify-phase5-full-verifier-sweep.ps1 (default parameters)"
Assert-Contains "phase5 plan vercel status proof" $plan "verify-phase5-vercel-github-deployment-status.ps1 (default parameters)"
Assert-Contains "phase5 plan historical artifact coverage" $plan "verify-phase5-staging-parity-blocked.ps1 -ReleaseId prod-candidate-2026-05-05-rc1"
Assert-Contains "phase5 plan historical artifact coverage" $plan "verify-phase5-release-readiness-rerun.ps1 -ReleaseId prod-candidate-2026-05-05-rc1"

Write-Host "[phase5-suite-active-candidate-plan] verified"

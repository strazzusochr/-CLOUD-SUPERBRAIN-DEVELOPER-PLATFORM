param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [string]$OutDir = ".codex\runs\CURRENT\phase6\gameplay-state-local"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase6 3D gameplay state verification failed: $label"
  }
}

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase6 3D gameplay state verification failed: $label missing '$expected'"
  }
}

function Invoke-Text($url) {
  return (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 30).Content
}

function Invoke-Json($url) {
  return (Invoke-Text $url) | ConvertFrom-Json
}

$BaseUrl = $BaseUrl.TrimEnd("/")
$isLocalhost = $BaseUrl -match "^http://(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\])(:|/|$)"
if ($isLocalhost -and -not $AllowLocalhost) {
  throw "Localhost verification requires -AllowLocalhost and remains DEV-ONLY"
}
if (($BaseUrl -notmatch "^https://") -and -not $AllowLocalhost) {
  throw "Non-HTTPS verification requires -AllowLocalhost"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$artifactDir = if ([System.IO.Path]::IsPathRooted($OutDir)) { $OutDir } else { Join-Path $repoRoot $OutDir }
New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null

Write-Host "[phase6-gameplay-state] runtime contract"
$contract = Invoke-Json "$BaseUrl/api/v1/phase6/3d-gameplay-state/contract"
Assert-True "contract version" ($contract.contract_version -eq "phase6-3d-gameplay-state-runtime-v1")
Assert-True "endpoint" ($contract.endpoint -eq "GET /api/v1/phase6/3d-gameplay-state/contract")
Assert-True "evidence" ($contract.evidence_ref -eq "phase6_3d_gameplay_state_runtime_visible")
Assert-True "strategy" ($contract.gameplay_state_strategy -eq "local_objective_score_checkpoint_state_machine")
Assert-True "objectives" ((@($contract.objectives) -join ",") -eq "collect,checkpoint,survive")
Assert-True "collect transition" ($contract.objective_transitions.collect.next -eq "checkpoint")
Assert-True "checkpoint transition" ($contract.objective_transitions.checkpoint.next -eq "survive")
Assert-True "survive transition" ($contract.objective_transitions.survive.next -eq "collect")
Assert-True "score increment" ([int]$contract.score_increment -eq 10)
Assert-True "checkpoint increment" ([int]$contract.checkpoint_increment -eq 1)
Assert-True "loop interval" ([int]$contract.loop_interval_ms -eq 1000)
Assert-True "pause safe" ($contract.pause_safe_loop_required -eq $true)
Assert-True "local state" ($contract.local_gameplay_state_only_required -eq $true)
Assert-True "applied state" ($contract.applied_runtime_state_attributes_required -eq $true)
Assert-True "no multiplayer" ($contract.multiplayer_netcode_allowed -eq $false)
Assert-True "no server sync" ($contract.server_authoritative_sync_allowed -eq $false)
Assert-True "no physics" ($contract.physics_engine_required -eq $false)
Assert-True "no asset fetch" ($contract.external_asset_fetch_allowed -eq $false)
Assert-True "no network required" ($contract.network_calls_required -eq $false)
Assert-True "phase6 target" ([int]$contract.phase6_progress_after_proof -eq 48)
Assert-True "scenario count" ([int]$contract.scenario_count -eq 8)
Assert-True "pass count" ([int]$contract.pass_count -eq 8)
Assert-True "all scenarios pass" ($contract.all_scenarios_pass -eq $true)

foreach ($scenarioName in @(
  "objective_state_overlay_visible",
  "local_score_counter_visible",
  "checkpoint_counter_visible",
  "deterministic_gameplay_state_machine",
  "pause_safe_game_loop_state",
  "input_event_binding_reused",
  "local_gameplay_state_only",
  "phase6_progress_gate_bound_to_gameplay_state_verifier"
)) {
  $scenario = @($contract.scenarios) | Where-Object { $_.scenario -eq $scenarioName } | Select-Object -First 1
  Assert-True "scenario present $scenarioName" ($null -ne $scenario)
  Assert-True "scenario pass $scenarioName" ($scenario.pass -eq $true)
  foreach ($guard in @(
    "local_model_downloads",
    "multiplayer_netcode_started",
    "server_authoritative_sync_started",
    "physics_engine_started",
    "external_asset_fetch",
    "server_side_gpu_started",
    "heavy_local_render_allowed",
    "provider_write",
    "live_mcp_write",
    "production_deploy",
    "secret_values_returned",
    "release_promotion"
  )) {
    Assert-True "scenario guard $scenarioName/$guard" ($scenario.$guard -eq $false)
  }
}

Write-Host "[phase6-gameplay-state] frontend and source guards"
$organismHtml = Invoke-Text "$BaseUrl/organism"
foreach ($required in @(
  "phase6-gameplay-state-controls",
  "phase6-gameplay-objective",
  "phase6-gameplay-score",
  "phase6-gameplay-checkpoints",
  "phase6-gameplay-pause",
  "phase6-gameplay-state"
)) {
  Assert-Contains "organism HTML" $organismHtml $required
}

$viewSource = Get-Content -LiteralPath (Join-Path $repoRoot "apps\frontend\components\organism\OrganismView.tsx") -Raw
$canvasSource = Get-Content -LiteralPath (Join-Path $repoRoot "apps\frontend\components\organism\CortexCanvas3D.tsx") -Raw
$testSource = Get-Content -LiteralPath (Join-Path $repoRoot "apps\frontend\e2e\organism.spec.ts") -Raw
$apiSource = Get-Content -LiteralPath (Join-Path $repoRoot "services\agent-api\app\main.py") -Raw
$docSource = Get-Content -LiteralPath (Join-Path $repoRoot "docs\runtime-contracts\phase6-3d-gameplay-state-runtime.md") -Raw
foreach ($required in @("GAMEPLAY_OBJECTIVES", "completeGameplayObjective", "gameplayTicks", "KeyG", "local_state_only=true")) {
  Assert-Contains "OrganismView source" $viewSource $required
}
foreach ($required in @("GAMEPLAY_BEACONS", "GameplayBeacon", "data-gameplay-objective", "data-gameplay-paused", "data-gameplay-local-only")) {
  Assert-Contains "CortexCanvas3D source" $canvasSource $required
}
foreach ($required in @("Phase-6 gameplay state is deterministic", "data-gameplay-ticks", "gameplay controls remain browser-local", "phase6-gameplay-state.png")) {
  Assert-Contains "Playwright source" $testSource $required
}
foreach ($required in @("PHASE6_3D_GAMEPLAY_STATE_CONTRACT_VERSION", "phase6_3d_gameplay_state_runtime_contract_payload", "/api/v1/phase6/3d-gameplay-state/contract", "network_calls_required")) {
  Assert-Contains "Agent API source" $apiSource $required
}
foreach ($required in @('phase6-3d-gameplay-state-runtime-v1', 'Phase 6 may move from `40%` to `48%`', 'No multiplayer or netcode', 'DEV-ONLY')) {
  Assert-Contains "contract document" $docSource $required
}

$manifest = Get-Content -LiteralPath (Join-Path $repoRoot "docs\project-progress.manifest.json") -Raw | ConvertFrom-Json
$phase6 = @($manifest.horizontal.items) | Where-Object { $_.id -eq "phase_6" } | Select-Object -First 1
Assert-True "manifest phase6 48 minimum" ([int]$phase6.percent -ge 48)
Assert-Contains "manifest gameplay marker" $phase6.status "phase6_3d_gameplay_state_runtime_visible"
Assert-Contains "manifest gameplay controls marker" $phase6.status "gameplay_state_controls_verified"

Write-Host "[phase6-gameplay-state] Chromium interaction proof"
$previousBaseUrl = $env:PHASE6_BASE_URL
$previousArtifactDir = $env:PHASE6_ARTIFACT_DIR
try {
  $env:PHASE6_BASE_URL = $BaseUrl
  $env:PHASE6_ARTIFACT_DIR = $artifactDir
  Push-Location (Join-Path $repoRoot "apps\frontend")
  try {
    npx playwright test --grep "Phase-6 gameplay state is deterministic" --workers=1 --reporter=line
    if ($LASTEXITCODE -ne 0) {
      throw "Playwright gameplay state proof failed with exit code $LASTEXITCODE"
    }
  } finally {
    Pop-Location
  }
} finally {
  $env:PHASE6_BASE_URL = $previousBaseUrl
  $env:PHASE6_ARTIFACT_DIR = $previousArtifactDir
}

$screenshotPath = Join-Path $artifactDir "phase6-gameplay-state.png"
Assert-True "gameplay screenshot exists" (Test-Path -LiteralPath $screenshotPath)
$screenshotBytes = (Get-Item -LiteralPath $screenshotPath).Length
Assert-True "gameplay screenshot is nonblank-sized" ($screenshotBytes -gt 25000)

$report = [ordered]@{
  contract_version = "phase6-3d-gameplay-state-runtime-v1"
  status = "verified"
  scope = if ($isLocalhost) { "DEV-ONLY" } else { "hosted_https" }
  base_url = $BaseUrl
  objectives = @("collect", "checkpoint", "survive")
  score_increment = 10
  checkpoint_increment = 1
  pause_safe_loop = $true
  browser_local_state = $true
  screenshot = @{ path = "phase6-gameplay-state.png"; bytes = $screenshotBytes }
  multiplayer_netcode_started = $false
  server_authoritative_sync_started = $false
  provider_write = $false
  live_mcp_write = $false
  production_deploy = $false
  generated_at = (Get-Date).ToUniversalTime().ToString("o")
}
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $artifactDir "report.json") -Encoding utf8

Write-Host "[phase6-gameplay-state] result=verified"
Write-Host "[phase6-gameplay-state] evidence_ref=phase6_3d_gameplay_state_runtime_visible"
Write-Host "[phase6-gameplay-state] screenshot_bytes=$screenshotBytes"

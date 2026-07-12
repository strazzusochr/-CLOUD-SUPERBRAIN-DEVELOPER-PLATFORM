param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [string]$OutDir = ".codex\runs\CURRENT\phase6\camera-lighting-local"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase6 3D camera lighting verification failed: $label"
  }
}

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase6 3D camera lighting verification failed: $label missing '$expected'"
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
$artifactDir = if ([System.IO.Path]::IsPathRooted($OutDir)) {
  $OutDir
} else {
  Join-Path $repoRoot $OutDir
}
New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null

Write-Host "[phase6-camera-lighting] runtime contract"
$contract = Invoke-Json "$BaseUrl/api/v1/phase6/3d-camera-lighting/contract"
Assert-True "contract version" ($contract.contract_version -eq "phase6-3d-camera-lighting-runtime-v1")
Assert-True "endpoint" ($contract.endpoint -eq "GET /api/v1/phase6/3d-camera-lighting/contract")
Assert-True "evidence" ($contract.evidence_ref -eq "phase6_3d_camera_lighting_runtime_visible")
Assert-True "strategy" ($contract.camera_lighting_strategy -eq "local_camera_rig_lighting_profile_state")
Assert-True "camera presets" (@($contract.camera_presets).Count -eq 3)
Assert-True "lighting profiles" (@($contract.lighting_profiles).Count -eq 3)
Assert-True "fov steps" ((@($contract.safe_fov_degrees) -join ",") -eq "38,45,58")
Assert-True "safe exposure min" ([double]$contract.safe_exposure_range.min -eq 0.72)
Assert-True "safe exposure max" ([double]$contract.safe_exposure_range.max -eq 1.18)
Assert-True "safe exposure step" ([double]$contract.safe_exposure_range.step -eq 0.02)
Assert-True "applied state required" ($contract.applied_runtime_state_attributes_required -eq $true)
Assert-True "browser local state" ($contract.local_camera_lighting_state_only_required -eq $true)
Assert-True "no shader hotload" ($contract.shader_hotload_allowed -eq $false)
Assert-True "no external asset fetch" ($contract.external_asset_fetch_allowed -eq $false)
Assert-True "no network required" ($contract.network_calls_required -eq $false)
Assert-True "phase6 target" ([int]$contract.phase6_progress_after_proof -eq 40)
Assert-True "scenario count" ([int]$contract.scenario_count -eq 8)
Assert-True "pass count" ([int]$contract.pass_count -eq 8)
Assert-True "all scenarios pass" ($contract.all_scenarios_pass -eq $true)

foreach ($scenarioName in @(
  "camera_preset_switch_visible",
  "fov_step_control_visible",
  "lighting_profile_switch_visible",
  "safe_exposure_bounds_visible",
  "camera_lighting_state_overlay_visible",
  "local_camera_lighting_state_only",
  "cloud_render_boundary_still_closed",
  "phase6_progress_gate_bound_to_camera_lighting_verifier"
)) {
  $scenario = @($contract.scenarios) | Where-Object { $_.scenario -eq $scenarioName } | Select-Object -First 1
  Assert-True "scenario present $scenarioName" ($null -ne $scenario)
  Assert-True "scenario pass $scenarioName" ($scenario.pass -eq $true)
  foreach ($guard in @(
    "local_model_downloads",
    "external_asset_fetch",
    "shader_hotload_started",
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

Write-Host "[phase6-camera-lighting] frontend and source guards"
$organismHtml = Invoke-Text "$BaseUrl/organism"
foreach ($required in @(
  "phase6-camera-lighting-controls",
  "phase6-camera-preset-wide",
  "phase6-lighting-profile-studio",
  "phase6-camera-fov",
  "phase6-lighting-exposure",
  "phase6-camera-lighting-state"
)) {
  Assert-Contains "organism HTML" $organismHtml $required
}

$viewSource = Get-Content -LiteralPath (Join-Path $repoRoot "apps\frontend\components\organism\OrganismView.tsx") -Raw
$canvasSource = Get-Content -LiteralPath (Join-Path $repoRoot "apps\frontend\components\organism\CortexCanvas3D.tsx") -Raw
$testSource = Get-Content -LiteralPath (Join-Path $repoRoot "apps\frontend\e2e\organism.spec.ts") -Raw
$apiSource = Get-Content -LiteralPath (Join-Path $repoRoot "services\agent-api\app\main.py") -Raw
$docSource = Get-Content -LiteralPath (Join-Path $repoRoot "docs\runtime-contracts\phase6-3d-camera-lighting-runtime.md") -Raw
foreach ($required in @("CAMERA_PRESETS", "LIGHTING_PROFILES", 'id: "top"', 'id: "sunrise"', 'phase6-camera-preset-${preset.id}', 'phase6-lighting-profile-${profile.id}', "safeExposure", "local_state_only=true")) {
  Assert-Contains "OrganismView source" $viewSource $required
}
foreach ($required in @("PerspectiveCamera", "CAMERA_PRESETS", "LIGHTING_PROFILES", "ACESFilmicToneMapping", "data-camera-position", "data-tone-exposure")) {
  Assert-Contains "CortexCanvas3D source" $canvasSource $required
}
foreach ($required in @("Phase-6 camera and lighting controls", "data-camera-position", "0.72", "1.18", "browser-local", "phase6-camera-lighting.png")) {
  Assert-Contains "Playwright source" $testSource $required
}
foreach ($required in @("PHASE6_3D_CAMERA_LIGHTING_CONTRACT_VERSION", "phase6_3d_camera_lighting_runtime_contract_payload", "/api/v1/phase6/3d-camera-lighting/contract", "network_calls_required")) {
  Assert-Contains "Agent API source" $apiSource $required
}
foreach ($required in @('phase6-3d-camera-lighting-runtime-v1', 'Phase 6 to move from `32%` to `40%`', 'No shader hotload', 'DEV-ONLY')) {
  Assert-Contains "contract document" $docSource $required
}

$manifest = Get-Content -LiteralPath (Join-Path $repoRoot "docs\project-progress.manifest.json") -Raw | ConvertFrom-Json
$phase6 = @($manifest.horizontal.items) | Where-Object { $_.id -eq "phase_6" } | Select-Object -First 1
Assert-True "manifest phase6 40 minimum" ([int]$phase6.percent -ge 40)
Assert-Contains "manifest camera lighting marker" $phase6.status "phase6_3d_camera_lighting_runtime_visible"
Assert-Contains "manifest camera controls marker" $phase6.status "camera_lighting_controls_verified"

Write-Host "[phase6-camera-lighting] Chromium interaction proof"
$previousBaseUrl = $env:PHASE6_BASE_URL
$previousArtifactDir = $env:PHASE6_ARTIFACT_DIR
try {
  $env:PHASE6_BASE_URL = $BaseUrl
  $env:PHASE6_ARTIFACT_DIR = $artifactDir
  Push-Location (Join-Path $repoRoot "apps\frontend")
  try {
    npx playwright test --grep "Phase-6 camera and lighting controls" --workers=1 --reporter=line
    if ($LASTEXITCODE -ne 0) {
      throw "Playwright camera and lighting proof failed with exit code $LASTEXITCODE"
    }
  } finally {
    Pop-Location
  }
} finally {
  $env:PHASE6_BASE_URL = $previousBaseUrl
  $env:PHASE6_ARTIFACT_DIR = $previousArtifactDir
}

$screenshotPath = Join-Path $artifactDir "phase6-camera-lighting.png"
Assert-True "camera lighting screenshot exists" (Test-Path -LiteralPath $screenshotPath)
$screenshotBytes = (Get-Item -LiteralPath $screenshotPath).Length
Assert-True "camera lighting screenshot is nonblank-sized" ($screenshotBytes -gt 25000)

$report = [ordered]@{
  contract_version = "phase6-3d-camera-lighting-runtime-v1"
  status = "verified"
  scope = if ($isLocalhost) { "DEV-ONLY" } else { "hosted_https" }
  base_url = $BaseUrl
  camera_presets = @("wide", "close", "top")
  lighting_profiles = @("studio", "night", "sunrise")
  safe_fov_degrees = @(38, 45, 58)
  safe_exposure_range = @{ min = 0.72; max = 1.18; step = 0.02 }
  screenshot = @{ path = "phase6-camera-lighting.png"; bytes = $screenshotBytes }
  provider_write = $false
  live_mcp_write = $false
  production_deploy = $false
  generated_at = (Get-Date).ToUniversalTime().ToString("o")
}
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $artifactDir "report.json") -Encoding utf8

Write-Host "[phase6-camera-lighting] result=verified"
Write-Host "[phase6-camera-lighting] evidence_ref=phase6_3d_camera_lighting_runtime_visible"
Write-Host "[phase6-camera-lighting] screenshot_bytes=$screenshotBytes"

param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [string]$OutDir = ".codex\runs\CURRENT\phase6\accessibility-local"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) { throw "Phase6 accessibility verification failed: $label" }
}
function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) { throw "Phase6 accessibility verification failed: $label missing '$expected'" }
}
function Invoke-Text($url) { return (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 30).Content }
function Invoke-Json($url) { return (Invoke-Text $url) | ConvertFrom-Json }

$BaseUrl = $BaseUrl.TrimEnd("/")
$isLocalhost = $BaseUrl -match "^http://(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\])(:|/|$)"
if ($isLocalhost -and -not $AllowLocalhost) { throw "Localhost verification requires -AllowLocalhost and remains DEV-ONLY" }
if (($BaseUrl -notmatch "^https://") -and -not $AllowLocalhost) { throw "Non-HTTPS verification requires -AllowLocalhost" }
$repoRoot = Split-Path -Parent $PSScriptRoot
$artifactDir = if ([IO.Path]::IsPathRooted($OutDir)) { $OutDir } else { Join-Path $repoRoot $OutDir }
New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null

Write-Host "[phase6-accessibility] runtime contract"
$contract = Invoke-Json "$BaseUrl/api/v1/phase6/3d-accessibility/contract"
Assert-True "version" ($contract.contract_version -eq "phase6-3d-accessibility-runtime-v1")
Assert-True "endpoint" ($contract.endpoint -eq "GET /api/v1/phase6/3d-accessibility/contract")
Assert-True "evidence" ($contract.evidence_ref -eq "phase6_3d_accessibility_runtime_visible")
Assert-True "strategy" ($contract.accessibility_strategy -eq "system_aware_reduced_motion_semantic_keyboard_fallback")
Assert-True "manual toggle" ($contract.manual_reduced_motion_toggle_required -eq $true)
Assert-True "system preference" ($contract.system_preference_detection_required -eq $true)
Assert-True "2d fallback" ($contract.static_2d_fallback_required -eq $true)
Assert-True "semantic region" ($contract.semantic_region_required -eq $true)
Assert-True "focus" ($contract.programmatic_scene_focus_required -eq $true)
Assert-True "focus visible" ($contract.global_focus_visible_required -eq $true)
Assert-True "live status" ($contract.live_status_region_required -eq $true)
Assert-True "items" ([int]$contract.accessible_item_count -eq 10)
Assert-True "keys" ((@($contract.keyboard_navigation_keys) -join ",") -eq "ArrowDown,ArrowRight,ArrowUp,ArrowLeft,Home,End,Enter,Space")
Assert-True "no speech" ($contract.speech_service_required -eq $false)
Assert-True "no telemetry" ($contract.accessibility_telemetry_export_allowed -eq $false)
Assert-True "no persistence" ($contract.persistent_preference_write_allowed -eq $false)
Assert-True "no network" ($contract.network_calls_required -eq $false)
Assert-True "target" ([int]$contract.phase6_progress_after_proof -eq 72)
Assert-True "scenarios" ([int]$contract.scenario_count -eq 8 -and [int]$contract.pass_count -eq 8 -and $contract.all_scenarios_pass -eq $true)
foreach ($name in @("manual_reduced_motion_toggle_visible","system_reduced_motion_preference_honored","semantic_2d_fallback_region_visible","keyboard_fallback_navigation_visible","focus_visible_and_programmatic_focus_visible","accessible_status_live_region_visible","accessibility_local_only","phase6_progress_gate_bound_to_accessibility_verifier")) {
  $scenario = @($contract.scenarios) | Where-Object scenario -eq $name | Select-Object -First 1
  Assert-True "scenario $name" ($null -ne $scenario -and $scenario.pass -eq $true)
  foreach ($guard in @("speech_service_started","accessibility_telemetry_export","persistent_preference_write","network_calls","provider_write","live_mcp_write","production_deploy","secret_values_returned","release_promotion")) {
    Assert-True "guard $name/$guard" ($scenario.$guard -eq $false)
  }
}

Write-Host "[phase6-accessibility] frontend and source guards"
$html = Invoke-Text "$BaseUrl/organism"
foreach ($required in @("phase6-accessibility-controls","phase6-reduced-motion-toggle","phase6-focus-scene","phase6-accessibility-state")) { Assert-Contains "HTML" $html $required }
$view = Get-Content (Join-Path $repoRoot "apps\frontend\components\organism\OrganismView.tsx") -Raw
$canvas = Get-Content (Join-Path $repoRoot "apps\frontend\components\organism\CortexCanvas.tsx") -Raw
$test = Get-Content (Join-Path $repoRoot "apps\frontend\e2e\organism.spec.ts") -Raw
$api = Get-Content (Join-Path $repoRoot "services\agent-api\app\main.py") -Raw
$doc = Get-Content (Join-Path $repoRoot "docs\runtime-contracts\phase6-3d-accessibility-runtime.md") -Raw
foreach ($required in @("systemReducedMotion","effectiveReducedMotion","prefers-reduced-motion: reduce",'aria-controls="organism-cortex-surface"',"focusCortexSurface",'role="status"')) { Assert-Contains "view" $view $required }
foreach ($required in @("phase6-reduced-motion-fallback","handleFallbackKeyDown","ArrowDown","Home","End","aria-current")) { Assert-Contains "fallback" $canvas $required }
foreach ($required in @("Phase-6 accessibility honors",'reducedMotion: "reduce"',"toBeFocused","ArrowDown","phase6-accessibility.png","accessibility controls remain browser-local")) { Assert-Contains "test" $test $required }
foreach ($required in @("PHASE6_3D_ACCESSIBILITY_CONTRACT_VERSION","phase6_3d_accessibility_runtime_contract_payload","/api/v1/phase6/3d-accessibility/contract")) { Assert-Contains "api" $api $required }
foreach ($required in @('phase6-3d-accessibility-runtime-v1','Phase 6 may move from `64%` to `72%`','No speech service','DEV-ONLY')) { Assert-Contains "doc" $doc $required }

$manifest = Get-Content (Join-Path $repoRoot "docs\project-progress.manifest.json") -Raw | ConvertFrom-Json
$phase6 = @($manifest.horizontal.items) | Where-Object id -eq "phase_6" | Select-Object -First 1
Assert-True "manifest phase6 minimum 72" ([int]$phase6.percent -ge 72)
Assert-Contains "manifest marker" $phase6.status "phase6_3d_accessibility_runtime_visible"
Assert-Contains "manifest focus marker" $phase6.status "reduced_motion_keyboard_focus_verified"

Write-Host "[phase6-accessibility] Chromium interaction proof"
$oldBase = $env:PHASE6_BASE_URL; $oldDir = $env:PHASE6_ARTIFACT_DIR
try {
  $env:PHASE6_BASE_URL = $BaseUrl; $env:PHASE6_ARTIFACT_DIR = $artifactDir
  Push-Location (Join-Path $repoRoot "apps\frontend")
  try { npx playwright test --grep "Phase-6 accessibility honors" --workers=1 --reporter=line; if ($LASTEXITCODE -ne 0) { throw "Playwright accessibility proof failed" } } finally { Pop-Location }
} finally { $env:PHASE6_BASE_URL = $oldBase; $env:PHASE6_ARTIFACT_DIR = $oldDir }
$screenshot = Join-Path $artifactDir "phase6-accessibility.png"
Assert-True "screenshot exists" (Test-Path $screenshot)
$bytes = (Get-Item $screenshot).Length
Assert-True "screenshot size" ($bytes -gt 25000)
@{ contract_version="phase6-3d-accessibility-runtime-v1"; status="verified"; scope=if($isLocalhost){"DEV-ONLY"}else{"hosted_https"}; accessible_items=10; manual_reduced_motion=$true; system_preference=$true; keyboard_focus=$true; network_calls=$false; production_deploy=$false; screenshot=@{path="phase6-accessibility.png";bytes=$bytes}; generated_at=(Get-Date).ToUniversalTime().ToString("o") } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $artifactDir "report.json") -Encoding utf8
Write-Host "[phase6-accessibility] result=verified"
Write-Host "[phase6-accessibility] screenshot_bytes=$bytes"

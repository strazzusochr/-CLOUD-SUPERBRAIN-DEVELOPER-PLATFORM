param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [string]$OutDir = ".codex\runs\CURRENT\phase6\save-load-local"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase6 3D save/load verification failed: $label"
  }
}

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase6 3D save/load verification failed: $label missing '$expected'"
  }
}

function Assert-NotContains($label, $value, $unexpected) {
  $text = ($value | Out-String)
  if ($text.Contains($unexpected)) {
    throw "Phase6 3D save/load verification failed: $label unexpectedly contains '$unexpected'"
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

Write-Host "[phase6-save-load] runtime contract"
$contract = Invoke-Json "$BaseUrl/api/v1/phase6/3d-save-load/contract"
Assert-True "contract version" ($contract.contract_version -eq "phase6-3d-save-load-runtime-v1")
Assert-True "endpoint" ($contract.endpoint -eq "GET /api/v1/phase6/3d-save-load/contract")
Assert-True "evidence" ($contract.evidence_ref -eq "phase6_3d_save_load_runtime_visible")
Assert-True "strategy" ($contract.save_load_strategy -eq "typed_allowlisted_react_state_snapshot")
Assert-True "field count" ([int]$contract.snapshot_field_count -eq 15)
Assert-True "slot count" ([int]$contract.snapshot_slots -eq 1)
Assert-True "capture" ($contract.capture_required -eq $true)
Assert-True "restore" ($contract.restore_required -eq $true)
Assert-True "clear" ($contract.clear_required -eq $true)
Assert-True "load blocked before snapshot" ($contract.load_disabled_without_snapshot_required -eq $true)
Assert-True "volatile only" ($contract.volatile_browser_memory_only_required -eq $true)
Assert-True "reload discard" ($contract.snapshot_discarded_on_reload_required -eq $true)
Assert-True "no local storage" ($contract.local_storage_allowed -eq $false)
Assert-True "no indexeddb" ($contract.indexeddb_allowed -eq $false)
Assert-True "no cookies" ($contract.cookie_persistence_allowed -eq $false)
Assert-True "no cache" ($contract.service_worker_cache_allowed -eq $false)
Assert-True "no cloud sync" ($contract.cloud_save_sync_allowed -eq $false)
Assert-True "no binary upload" ($contract.binary_snapshot_upload_allowed -eq $false)
Assert-True "no server write" ($contract.server_snapshot_write_allowed -eq $false)
Assert-True "no network required" ($contract.network_calls_required -eq $false)
Assert-True "phase6 target" ([int]$contract.phase6_progress_after_proof -eq 64)
Assert-True "scenario count" ([int]$contract.scenario_count -eq 8)
Assert-True "pass count" ([int]$contract.pass_count -eq 8)
Assert-True "all scenarios pass" ($contract.all_scenarios_pass -eq $true)

foreach ($scenarioName in @(
  "scene_snapshot_capture_visible",
  "scene_snapshot_restore_visible",
  "scene_snapshot_clear_visible",
  "load_without_snapshot_blocked",
  "volatile_browser_memory_only",
  "persistent_browser_storage_blocked",
  "cloud_save_sync_blocked",
  "phase6_progress_gate_bound_to_save_load_verifier"
)) {
  $scenario = @($contract.scenarios) | Where-Object { $_.scenario -eq $scenarioName } | Select-Object -First 1
  Assert-True "scenario present $scenarioName" ($null -ne $scenario)
  Assert-True "scenario pass $scenarioName" ($scenario.pass -eq $true)
  foreach ($guard in @(
    "local_storage_write",
    "indexeddb_write",
    "cookie_write",
    "service_worker_cache_write",
    "cloud_save_sync",
    "binary_snapshot_upload",
    "server_snapshot_write",
    "network_calls",
    "provider_write",
    "live_mcp_write",
    "production_deploy",
    "secret_values_returned",
    "release_promotion"
  )) {
    Assert-True "scenario guard $scenarioName/$guard" ($scenario.$guard -eq $false)
  }
}

Write-Host "[phase6-save-load] frontend and source guards"
$organismHtml = Invoke-Text "$BaseUrl/organism"
foreach ($required in @(
  "phase6-save-load-controls",
  "phase6-save-snapshot",
  "phase6-load-snapshot",
  "phase6-clear-snapshot",
  "phase6-save-load-state"
)) {
  Assert-Contains "organism HTML" $organismHtml $required
}

$viewSource = Get-Content -LiteralPath (Join-Path $repoRoot "apps\frontend\components\organism\OrganismView.tsx") -Raw
$testSource = Get-Content -LiteralPath (Join-Path $repoRoot "apps\frontend\e2e\organism.spec.ts") -Raw
$apiSource = Get-Content -LiteralPath (Join-Path $repoRoot "services\agent-api\app\main.py") -Raw
$docSource = Get-Content -LiteralPath (Join-Path $repoRoot "docs\runtime-contracts\phase6-3d-save-load-runtime.md") -Raw
foreach ($required in @("Phase6SceneSnapshot", "savedSnapshot", "saveSceneSnapshot", "loadSceneSnapshot", "clearSceneSnapshot", "storage=react_state", "reload_persistence=false")) {
  Assert-Contains "OrganismView source" $viewSource $required
}
foreach ($forbidden in @("window.localStorage", "indexedDB.open", "document.cookie", "caches.open")) {
  Assert-NotContains "OrganismView persistent storage path" $viewSource $forbidden
}
foreach ($required in @("Phase-6 save and load restores", "snapshot_status=restored", "save load controls remain browser-local", "phase6-save-load.png")) {
  Assert-Contains "Playwright source" $testSource $required
}
foreach ($required in @("PHASE6_3D_SAVE_LOAD_CONTRACT_VERSION", "phase6_3d_save_load_runtime_contract_payload", "/api/v1/phase6/3d-save-load/contract", "network_calls_required")) {
  Assert-Contains "Agent API source" $apiSource $required
}
foreach ($required in @('phase6-3d-save-load-runtime-v1', 'Phase 6 may move from `56%` to `64%`', 'No persistent browser storage', 'DEV-ONLY')) {
  Assert-Contains "contract document" $docSource $required
}

$manifest = Get-Content -LiteralPath (Join-Path $repoRoot "docs\project-progress.manifest.json") -Raw | ConvertFrom-Json
$phase6 = @($manifest.horizontal.items) | Where-Object { $_.id -eq "phase_6" } | Select-Object -First 1
Assert-True "manifest phase6 64 minimum" ([int]$phase6.percent -ge 64)
Assert-Contains "manifest save load marker" $phase6.status "phase6_3d_save_load_runtime_visible"
Assert-Contains "manifest snapshot restore marker" $phase6.status "browser_memory_snapshot_restore_verified"

Write-Host "[phase6-save-load] Chromium interaction proof"
$previousBaseUrl = $env:PHASE6_BASE_URL
$previousArtifactDir = $env:PHASE6_ARTIFACT_DIR
try {
  $env:PHASE6_BASE_URL = $BaseUrl
  $env:PHASE6_ARTIFACT_DIR = $artifactDir
  Push-Location (Join-Path $repoRoot "apps\frontend")
  try {
    npx playwright test --grep "Phase-6 save and load restores" --workers=1 --reporter=line
    if ($LASTEXITCODE -ne 0) {
      throw "Playwright save/load proof failed with exit code $LASTEXITCODE"
    }
  } finally {
    Pop-Location
  }
} finally {
  $env:PHASE6_BASE_URL = $previousBaseUrl
  $env:PHASE6_ARTIFACT_DIR = $previousArtifactDir
}

$screenshotPath = Join-Path $artifactDir "phase6-save-load.png"
Assert-True "save/load screenshot exists" (Test-Path -LiteralPath $screenshotPath)
$screenshotBytes = (Get-Item -LiteralPath $screenshotPath).Length
Assert-True "save/load screenshot is nonblank-sized" ($screenshotBytes -gt 25000)

$report = [ordered]@{
  contract_version = "phase6-3d-save-load-runtime-v1"
  status = "verified"
  scope = if ($isLocalhost) { "DEV-ONLY" } else { "hosted_https" }
  base_url = $BaseUrl
  snapshot_field_count = 15
  snapshot_slots = 1
  storage = "volatile_react_state"
  reload_persistence = $false
  screenshot = @{ path = "phase6-save-load.png"; bytes = $screenshotBytes }
  local_storage_write = $false
  indexeddb_write = $false
  cookie_write = $false
  service_worker_cache_write = $false
  cloud_save_sync = $false
  binary_snapshot_upload = $false
  server_snapshot_write = $false
  network_calls = $false
  provider_write = $false
  live_mcp_write = $false
  production_deploy = $false
  generated_at = (Get-Date).ToUniversalTime().ToString("o")
}
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $artifactDir "report.json") -Encoding utf8

Write-Host "[phase6-save-load] result=verified"
Write-Host "[phase6-save-load] evidence_ref=phase6_3d_save_load_runtime_visible"
Write-Host "[phase6-save-load] screenshot_bytes=$screenshotBytes"

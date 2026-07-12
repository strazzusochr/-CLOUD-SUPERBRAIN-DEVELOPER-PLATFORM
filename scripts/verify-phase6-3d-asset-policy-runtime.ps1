param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [string]$OutDir = ".codex\runs\CURRENT\phase6\asset-policy-local"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase6 3D asset policy verification failed: $label"
  }
}

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase6 3D asset policy verification failed: $label missing '$expected'"
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

Write-Host "[phase6-asset-policy] runtime contract"
$contract = Invoke-Json "$BaseUrl/api/v1/phase6/3d-asset-policy/contract"
Assert-True "contract version" ($contract.contract_version -eq "phase6-3d-asset-policy-runtime-v1")
Assert-True "endpoint" ($contract.endpoint -eq "GET /api/v1/phase6/3d-asset-policy/contract")
Assert-True "evidence" ($contract.evidence_ref -eq "phase6_3d_asset_policy_runtime_visible")
Assert-True "strategy" ($contract.asset_policy_strategy -eq "local_procedural_primitive_asset_catalog")
Assert-True "asset profile ids" ((@($contract.asset_profiles | ForEach-Object { $_.id }) -join ",") -eq "cube,beacon,ring")
Assert-True "material variant ids" ((@($contract.material_variants | ForEach-Object { $_.id }) -join ",") -eq "cyan,amber,rose")
Assert-True "asset catalog count" ([int]$contract.asset_catalog_count -eq 3)
Assert-True "material variant count" ([int]$contract.material_variant_count -eq 3)
Assert-True "remote asset count" ([int]$contract.remote_asset_count -eq 0)
Assert-True "uploaded asset count" ([int]$contract.uploaded_asset_count -eq 0)
Assert-True "procedural only" ($contract.procedural_primitives_only_required -eq $true)
Assert-True "local manifest" ($contract.local_asset_manifest_only_required -eq $true)
Assert-True "applied state" ($contract.applied_runtime_state_attributes_required -eq $true)
Assert-True "no external asset fetch" ($contract.external_asset_fetch_allowed -eq $false)
Assert-True "no binary upload" ($contract.binary_asset_upload_allowed -eq $false)
Assert-True "no remote cdn" ($contract.remote_cdn_allowed -eq $false)
Assert-True "no asset pipeline" ($contract.asset_pipeline_service_started -eq $false)
Assert-True "no network required" ($contract.network_calls_required -eq $false)
Assert-True "phase6 target" ([int]$contract.phase6_progress_after_proof -eq 56)
Assert-True "scenario count" ([int]$contract.scenario_count -eq 8)
Assert-True "pass count" ([int]$contract.pass_count -eq 8)
Assert-True "all scenarios pass" ($contract.all_scenarios_pass -eq $true)

foreach ($scenarioName in @(
  "procedural_asset_catalog_visible",
  "asset_profile_switch_visible",
  "material_policy_variant_visible",
  "local_asset_manifest_visible",
  "external_asset_fetch_blocked",
  "binary_asset_upload_blocked",
  "local_asset_policy_only",
  "phase6_progress_gate_bound_to_asset_policy_verifier"
)) {
  $scenario = @($contract.scenarios) | Where-Object { $_.scenario -eq $scenarioName } | Select-Object -First 1
  Assert-True "scenario present $scenarioName" ($null -ne $scenario)
  Assert-True "scenario pass $scenarioName" ($scenario.pass -eq $true)
  foreach ($guard in @(
    "local_model_downloads",
    "external_asset_fetch",
    "binary_asset_upload",
    "remote_cdn_fetch",
    "asset_pipeline_service_started",
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

Write-Host "[phase6-asset-policy] frontend and source guards"
$organismHtml = Invoke-Text "$BaseUrl/organism"
foreach ($required in @(
  "phase6-asset-policy-controls",
  "phase6-asset-profile-cube",
  "phase6-asset-profile-beacon",
  "phase6-asset-profile-ring",
  "phase6-material-variant-cyan",
  "phase6-material-variant-amber",
  "phase6-material-variant-rose",
  "phase6-asset-manifest"
)) {
  Assert-Contains "organism HTML" $organismHtml $required
}

$viewSource = Get-Content -LiteralPath (Join-Path $repoRoot "apps\frontend\components\organism\OrganismView.tsx") -Raw
$canvasSource = Get-Content -LiteralPath (Join-Path $repoRoot "apps\frontend\components\organism\CortexCanvas3D.tsx") -Raw
$testSource = Get-Content -LiteralPath (Join-Path $repoRoot "apps\frontend\e2e\organism.spec.ts") -Raw
$apiSource = Get-Content -LiteralPath (Join-Path $repoRoot "services\agent-api\app\main.py") -Raw
$docSource = Get-Content -LiteralPath (Join-Path $repoRoot "docs\runtime-contracts\phase6-3d-asset-policy-runtime.md") -Raw
foreach ($required in @("ASSET_PROFILES", "MATERIAL_VARIANTS", "selectAssetProfile", "selectMaterialVariant", "remote_assets=0", "binary_upload=false")) {
  Assert-Contains "OrganismView source" $viewSource $required
}
foreach ($required in @("AssetPolicyPreview", "boxGeometry", "coneGeometry", "torusGeometry", "data-asset-profile", "data-binary-asset-upload", "data-asset-policy-local-only")) {
  Assert-Contains "CortexCanvas3D source" $canvasSource $required
}
foreach ($required in @("Phase-6 asset policy applies procedural profiles", "data-remote-asset-count", "asset policy controls remain browser-local", "phase6-asset-policy.png")) {
  Assert-Contains "Playwright source" $testSource $required
}
foreach ($required in @("PHASE6_3D_ASSET_POLICY_CONTRACT_VERSION", "phase6_3d_asset_policy_runtime_contract_payload", "/api/v1/phase6/3d-asset-policy/contract", "network_calls_required")) {
  Assert-Contains "Agent API source" $apiSource $required
}
foreach ($required in @('phase6-3d-asset-policy-runtime-v1', 'Phase 6 may move from `48%` to `56%`', 'No external asset fetch', 'DEV-ONLY')) {
  Assert-Contains "contract document" $docSource $required
}

$manifest = Get-Content -LiteralPath (Join-Path $repoRoot "docs\project-progress.manifest.json") -Raw | ConvertFrom-Json
$phase6 = @($manifest.horizontal.items) | Where-Object { $_.id -eq "phase_6" } | Select-Object -First 1
Assert-True "manifest phase6 56 minimum" ([int]$phase6.percent -ge 56)
Assert-Contains "manifest asset marker" $phase6.status "phase6_3d_asset_policy_runtime_visible"
Assert-Contains "manifest asset controls marker" $phase6.status "asset_policy_controls_verified"

Write-Host "[phase6-asset-policy] Chromium interaction proof"
$previousBaseUrl = $env:PHASE6_BASE_URL
$previousArtifactDir = $env:PHASE6_ARTIFACT_DIR
try {
  $env:PHASE6_BASE_URL = $BaseUrl
  $env:PHASE6_ARTIFACT_DIR = $artifactDir
  Push-Location (Join-Path $repoRoot "apps\frontend")
  try {
    npx playwright test --grep "Phase-6 asset policy applies procedural profiles" --workers=1 --reporter=line
    if ($LASTEXITCODE -ne 0) {
      throw "Playwright asset policy proof failed with exit code $LASTEXITCODE"
    }
  } finally {
    Pop-Location
  }
} finally {
  $env:PHASE6_BASE_URL = $previousBaseUrl
  $env:PHASE6_ARTIFACT_DIR = $previousArtifactDir
}

$screenshotPath = Join-Path $artifactDir "phase6-asset-policy.png"
Assert-True "asset policy screenshot exists" (Test-Path -LiteralPath $screenshotPath)
$screenshotBytes = (Get-Item -LiteralPath $screenshotPath).Length
Assert-True "asset policy screenshot is nonblank-sized" ($screenshotBytes -gt 25000)

$report = [ordered]@{
  contract_version = "phase6-3d-asset-policy-runtime-v1"
  status = "verified"
  scope = if ($isLocalhost) { "DEV-ONLY" } else { "hosted_https" }
  base_url = $BaseUrl
  asset_profiles = @("cube", "beacon", "ring")
  material_variants = @("cyan", "amber", "rose")
  asset_catalog_count = 3
  material_variant_count = 3
  remote_asset_count = 0
  uploaded_asset_count = 0
  browser_local_state = $true
  screenshot = @{ path = "phase6-asset-policy.png"; bytes = $screenshotBytes }
  external_asset_fetch = $false
  binary_asset_upload = $false
  remote_cdn_fetch = $false
  asset_pipeline_service_started = $false
  provider_write = $false
  live_mcp_write = $false
  production_deploy = $false
  generated_at = (Get-Date).ToUniversalTime().ToString("o")
}
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $artifactDir "report.json") -Encoding utf8

Write-Host "[phase6-asset-policy] result=verified"
Write-Host "[phase6-asset-policy] evidence_ref=phase6_3d_asset_policy_runtime_visible"
Write-Host "[phase6-asset-policy] screenshot_bytes=$screenshotBytes"

param(
  [string]$BaseUrl = "",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Verification failed: $label did not contain '$expected'."
  }
}

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Verification failed: $label"
  }
}

function Invoke-Json($url) {
  $response = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 30
  return ($response.Content | ConvertFrom-Json)
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$referenceRoot = Join-Path $repoRoot "docs\reference"
$currentDesignRoot = Join-Path $referenceRoot "aktuell desin"
$frontendContractPath = Join-Path $repoRoot "apps\frontend\lib\referenceDesign.ts"
$frontendRoutePath = Join-Path $repoRoot "apps\frontend\app\api\v1\design\reference-contract\route.ts"
$agentApiPath = Join-Path $repoRoot "services\agent-api\app\main.py"
$browserVerifierPath = Join-Path $repoRoot "scripts\verify-browser-contract.ps1"

Write-Host "[reference-design] static contract"

foreach ($requiredPath in @($referenceRoot, $currentDesignRoot, $frontendContractPath, $frontendRoutePath, $agentApiPath, $browserVerifierPath)) {
  if (-not (Test-Path -LiteralPath $requiredPath)) {
    throw "Missing reference-design dependency: $requiredPath"
  }
}

$rootImages = @(Get-ChildItem -LiteralPath $referenceRoot -File | Where-Object { $_.Extension -in @(".png", ".jpg", ".jpeg") })
$currentScreenshots = @(Get-ChildItem -LiteralPath $currentDesignRoot -File | Where-Object { $_.Extension -in @(".png", ".jpg", ".jpeg") })
$motionVideos = @(Get-ChildItem -LiteralPath $referenceRoot -File | Where-Object { $_.Extension -in @(".mp4", ".webm") })

Assert-True "root reference image inventory >= 3" ($rootImages.Count -ge 3)
Assert-True "current design screenshot inventory >= 15" ($currentScreenshots.Count -ge 15)
Assert-True "motion reference video inventory >= 1" ($motionVideos.Count -ge 1)

$frontendContract = Get-Content -LiteralPath $frontendContractPath -Raw
$frontendRoute = Get-Content -LiteralPath $frontendRoutePath -Raw
$agentApi = Get-Content -LiteralPath $agentApiPath -Raw
$browserVerifier = Get-Content -LiteralPath $browserVerifierPath -Raw

foreach ($required in @(
  "reference-design-conformance-v1",
  "reference_design_conformance_visible",
  "industrial-developer-workbench",
  "rootImagesMin: 3",
  "currentDesignScreenshotsMin: 15",
  "motionVideosMin: 1",
  "expected_page_count: 22",
  "real-time 3D cognitive organism",
  "project-status-wall-on-workbench",
  "fake-live-data",
  "cartoon-bubble-cards",
  "retired-provider-defaults",
  "This contract does not claim pixel-perfect visual completion",
  "Local evidence remains DEV-ONLY"
)) {
  Assert-Contains "frontend reference design contract" $frontendContract $required
}

foreach ($required in @(
  "referenceDesignContract",
  "force-static",
  "/api/v1/design/reference-contract"
)) {
  Assert-Contains "frontend reference design route" $frontendRoute $required
}

foreach ($required in @(
  "REFERENCE_DESIGN_CONTRACT_VERSION",
  "reference-design-conformance-v1",
  "REFERENCE_DESIGN_EVIDENCE_REF",
  "reference_design_conformance_visible",
  "reference_design_contract_payload",
  "/api/v1/design/reference-contract",
  "industrial-developer-workbench",
  "expected_page_count",
  "real-time 3D cognitive organism",
  "project-status-wall-on-workbench",
  "fake-live-data",
  "cartoon-bubble-cards"
)) {
  Assert-Contains "agent-api reference design mirror" $agentApi $required
}

foreach ($required in @(
  "[browser-contract] reference design contract",
  "/api/v1/design/reference-contract",
  '"contract_version":"reference-design-conformance-v1"',
  '"evidence_ref":"reference_design_conformance_visible"',
  '"expected_page_count":22',
  "industrial-developer-workbench",
  "Local evidence remains DEV-ONLY"
)) {
  Assert-Contains "browser contract reference design proof" $browserVerifier $required
}

if ($BaseUrl) {
  $BaseUrl = $BaseUrl.TrimEnd("/")
  if ((-not $AllowLocalhost) -and ($BaseUrl -match "localhost|127\.0\.0\.1|\[::1\]")) {
    throw "Reference design runtime proof refuses localhost unless -AllowLocalhost is set"
  }
  Write-Host "[reference-design] runtime contract $BaseUrl"
  $runtime = Invoke-Json "$BaseUrl/api/v1/design/reference-contract"
  Assert-True "runtime contract version" ($runtime.contract_version -eq "reference-design-conformance-v1")
  Assert-True "runtime evidence ref" ($runtime.evidence_ref -eq "reference_design_conformance_visible")
  Assert-True "runtime expected page count" ([int]$runtime.expected_page_count -eq 22)
  Assert-True "runtime page count" ([int]$runtime.page_count -eq 22)
  Assert-True "runtime visual language" ($runtime.design_rules.visualLanguage -eq "industrial-developer-workbench")
  Assert-True "runtime no fake live rule" ($runtime.organism_requirements.no_fake_live -eq $true)
}

Write-Host "[reference-design] checks completed"

[CmdletBinding()]
param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [switch]$ApproveLiveProviderCall,
  [string]$ExpectedGatewayProvider = "cloudflare-workers-ai",
  [string]$EvidenceDir = ".codex\runs\CURRENT\product-acceptance"
)

$ErrorActionPreference = "Stop"

function Assert-True([string]$Label, $Condition) {
  if (-not $Condition) {
    throw "Product acceptance failed: $Label"
  }
}

function Set-ProcessEnvironment([string]$Name, [string]$Value) {
  [Environment]::SetEnvironmentVariable($Name, $Value, [EnvironmentVariableTarget]::Process)
}

if (-not $ApproveLiveProviderCall) {
  throw "Product acceptance requires explicit -ApproveLiveProviderCall because it performs one real LLM provider call and persists one build."
}

$parsedBaseUrl = $null
if (-not [Uri]::TryCreate($BaseUrl, [UriKind]::Absolute, [ref]$parsedBaseUrl)) {
  throw "Product acceptance failed: BaseUrl must be an absolute URL."
}
$isLocalhost = @("localhost", "127.0.0.1", "::1") -contains $parsedBaseUrl.Host
Assert-True "this verifier is DEV-ONLY and requires localhost" $isLocalhost
Assert-True "-AllowLocalhost is required for DEV-ONLY proof" $AllowLocalhost
Assert-True "BaseUrl must use http or https" ($parsedBaseUrl.Scheme -in @("http", "https"))
Assert-True "BaseUrl must target localhost port 8081" ($parsedBaseUrl.Port -eq 8081)
Assert-True "BaseUrl must not contain credentials" (-not $parsedBaseUrl.UserInfo)
Assert-True "BaseUrl must not contain query or fragment" (-not $parsedBaseUrl.Query -and -not $parsedBaseUrl.Fragment)
Assert-True "BaseUrl must be an origin without a path" ($parsedBaseUrl.AbsolutePath -eq "/")
Assert-True "ExpectedGatewayProvider is required" (-not [string]::IsNullOrWhiteSpace($ExpectedGatewayProvider))

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$frontendRoot = Join-Path $repoRoot "apps\frontend"
$specPath = Join-Path $frontendRoot "e2e\product-acceptance.spec.ts"
Assert-True "Playwright product acceptance spec exists" (Test-Path -LiteralPath $specPath -PathType Leaf)
Assert-True "frontend node_modules exists; run npm install --prefix apps/frontend first" (Test-Path -LiteralPath (Join-Path $frontendRoot "node_modules\@playwright\test") -PathType Container)

$specSource = Get-Content -LiteralPath $specPath -Raw
foreach ($forbiddenPattern in @(
  "\.route\s*\(",
  "route\.fulfill\s*\(",
  "route\.continue\s*\(",
  "route\.abort\s*\(",
  "addInitScript\s*\("
)) {
  Assert-True "no mocks, route interception, or injected fake state ($forbiddenPattern)" (-not ($specSource -match $forbiddenPattern))
}
foreach ($requiredMarker in @(
  "PRODUCT_ACCEPTANCE_BASE_URL",
  "live_provider_calls",
  "gateway_provider",
  "persisted",
  "persisted-build-frame",
  "pixelProbe",
  "page.reload",
  "console_error_count",
  "mocks_used: false"
)) {
  Assert-True "spec marker present: $requiredMarker" $specSource.Contains($requiredMarker)
}

$evidencePath = if ([IO.Path]::IsPathRooted($EvidenceDir)) {
  [IO.Path]::GetFullPath($EvidenceDir)
} else {
  [IO.Path]::GetFullPath((Join-Path $repoRoot $EvidenceDir))
}
$repoPrefix = $repoRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
Assert-True "EvidenceDir must stay inside the repository" $evidencePath.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)
New-Item -ItemType Directory -Path $evidencePath -Force | Out-Null
$reportPath = Join-Path $evidencePath "report.json"
$screenshotPath = Join-Path $evidencePath "product-acceptance.png"
foreach ($staleArtifact in @($reportPath, $screenshotPath)) {
  if (Test-Path -LiteralPath $staleArtifact -PathType Leaf) {
    Remove-Item -LiteralPath $staleArtifact -Force
  }
}

$environmentNames = @(
  "PHASE6_BASE_URL",
  "PRODUCT_ACCEPTANCE_BASE_URL",
  "PRODUCT_ACCEPTANCE_ARTIFACT_DIR",
  "PRODUCT_ACCEPTANCE_EXPECTED_GATEWAY_PROVIDER"
)
$previousEnvironment = @{}
foreach ($name in $environmentNames) {
  $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, [EnvironmentVariableTarget]::Process)
}

$normalizedBaseUrl = $parsedBaseUrl.GetLeftPart([UriPartial]::Authority)
Write-Host "[product-acceptance] DEV-ONLY base url: $normalizedBaseUrl"
Write-Host "[product-acceptance] one live provider call explicitly approved; expected gateway: $ExpectedGatewayProvider"
Write-Host "[product-acceptance] evidence: $evidencePath"

$playwrightExitCode = 1
try {
  Set-ProcessEnvironment "PHASE6_BASE_URL" $normalizedBaseUrl
  Set-ProcessEnvironment "PRODUCT_ACCEPTANCE_BASE_URL" $normalizedBaseUrl
  Set-ProcessEnvironment "PRODUCT_ACCEPTANCE_ARTIFACT_DIR" $evidencePath
  Set-ProcessEnvironment "PRODUCT_ACCEPTANCE_EXPECTED_GATEWAY_PROVIDER" $ExpectedGatewayProvider

  & npm.cmd run test:e2e:product-acceptance --prefix $frontendRoot
  $playwrightExitCode = $LASTEXITCODE
} finally {
  foreach ($name in $environmentNames) {
    Set-ProcessEnvironment $name $previousEnvironment[$name]
  }
}

Assert-True "JSON evidence report exists" (Test-Path -LiteralPath $reportPath -PathType Leaf)
$report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json

if ($playwrightExitCode -ne 0) {
  $failure = if ($report.failure) { [string]$report.failure } else { "see Playwright output and JSON evidence" }
  throw "Product acceptance failed in Chromium (exit $playwrightExitCode): $failure. Evidence: $reportPath"
}

Assert-True "report status is verified" ([string]$report.status -eq "verified")
Assert-True "report is explicitly DEV-ONLY" ([bool]$report.dev_only -and -not [bool]$report.hosted_proof)
Assert-True "exactly one build POST occurred" ([int]$report.build_post_count -eq 1)
Assert-True "live_provider_calls=true" ([bool]$report.build.live_provider_calls)
Assert-True "expected gateway provider" ([string]$report.build.gateway_provider -eq $ExpectedGatewayProvider)
Assert-True "gateway mode is documented" (-not [string]::IsNullOrWhiteSpace([string]$report.build.gateway_mode))
Assert-True "build is persisted" ([bool]$report.build.persisted -and [bool]$report.build.audit_persisted)
Assert-True "no direct provider bypass" (-not [bool]$report.build.direct_provider_calls)
Assert-True "Three.js marker verified" ([bool]$report.html.markers.three_js)
Assert-True "WebGL marker verified" ([bool]$report.html.markers.webgl)
Assert-True "rendered canvas is nonblank" ([bool]$report.run.nonblank_canvas)
Assert-True "keyboard/click changes pixels or visible state" (
  [bool]$report.interaction.click_pixel_changed -or
  [bool]$report.interaction.keyboard_pixel_changed -or
  [bool]$report.interaction.visible_dom_state_changed
)
Assert-True "same artifact survives reload" ([bool]$report.persistence.same_artifact_after_reload)
Assert-True "zero console errors" ([int]$report.console_error_count -eq 0)
Assert-True "zero page errors" ([int]$report.page_error_count -eq 0)
Assert-True "no mocks used" (-not [bool]$report.mocks_used -and -not [bool]$report.route_interception_used)
Assert-True "screenshot evidence exists" (Test-Path -LiteralPath $screenshotPath -PathType Leaf)
Assert-True "screenshot evidence is non-empty" ((Get-Item -LiteralPath $screenshotPath).Length -gt 1000)

Write-Host "[product-acceptance] PASS DEV-ONLY; hosted proof still blocked"
Write-Host "[product-acceptance] build_id=$($report.build.build_id) provider=$($report.build.gateway_provider) live_provider_calls=true"
Write-Host "[product-acceptance] report=$reportPath"

[CmdletBinding()]
param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [string]$EvidenceDir = ".codex\runs\CURRENT\22-page-actions"
)

$ErrorActionPreference = "Stop"

function Assert-True([string]$Label, $Condition) {
  if (-not $Condition) {
    throw "22-page action acceptance failed: $Label"
  }
}

function Set-ProcessEnvironment([string]$Name, [AllowNull()][string]$Value) {
  [Environment]::SetEnvironmentVariable($Name, $Value, [EnvironmentVariableTarget]::Process)
}

$parsedBaseUrl = $null
if (-not [Uri]::TryCreate($BaseUrl, [UriKind]::Absolute, [ref]$parsedBaseUrl)) {
  throw "22-page action acceptance failed: BaseUrl must be an absolute URL."
}
$isLocalhost = @("localhost", "127.0.0.1", "::1") -contains $parsedBaseUrl.Host
Assert-True "this verifier is DEV-ONLY and requires localhost" $isLocalhost
Assert-True "-AllowLocalhost is required for DEV-ONLY proof" $AllowLocalhost
Assert-True "BaseUrl must use http or https" ($parsedBaseUrl.Scheme -in @("http", "https"))
Assert-True "BaseUrl must target localhost port 8081" ($parsedBaseUrl.Port -eq 8081)
Assert-True "BaseUrl must not contain credentials" (-not $parsedBaseUrl.UserInfo)
Assert-True "BaseUrl must not contain query or fragment" (-not $parsedBaseUrl.Query -and -not $parsedBaseUrl.Fragment)
Assert-True "BaseUrl must be an origin without a path" ($parsedBaseUrl.AbsolutePath -eq "/")

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$frontendRoot = Join-Path $repoRoot "apps\frontend"
$specPath = Join-Path $frontendRoot "e2e\22-page-actions.spec.ts"
$matrixPath = Join-Path $frontendRoot "lib\actionMatrix.ts"
$productReportPath = Join-Path $repoRoot ".codex\runs\CURRENT\product-acceptance\report.json"
Assert-True "Playwright 22-page action spec exists" (Test-Path -LiteralPath $specPath -PathType Leaf)
Assert-True "canonical action registry exists" (Test-Path -LiteralPath $matrixPath -PathType Leaf)
Assert-True "green product-acceptance evidence exists" (Test-Path -LiteralPath $productReportPath -PathType Leaf)
Assert-True "frontend node_modules exists; run npm install --prefix apps/frontend first" (
  Test-Path -LiteralPath (Join-Path $frontendRoot "node_modules\@playwright\test") -PathType Container
)

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
  "ACTION_MATRIX",
  "WORKSPACE_PAGES",
  "memberActions",
  "expectedEffect",
  "direct_effect_count",
  "preverified_exact_control_count",
  "source_binding_sha256",
  "unregistered_page_local_action_count",
  "click_only_passes",
  "provider_request_count",
  "route_interception_used: false",
  "mocks_used: false"
)) {
  Assert-True "spec marker present: $requiredMarker" $specSource.Contains($requiredMarker)
}
foreach ($forbiddenPassMode in @(
  "named_current_evidence_plus_mounted_contract",
  "shared_component_canonical_effect_plus_route_mount",
  "mounted_control_plus_family_effect_contract"
)) {
  Assert-True "no non-direct pass mode: $forbiddenPassMode" (-not $specSource.Contains($forbiddenPassMode))
}

$matrixSource = Get-Content -LiteralPath $matrixPath -Raw
foreach ($requiredMatrixMarker in @(
  "ACTION_MATRIX_CONTRACT_VERSION",
  "ACTION_MATRIX",
  "ACTION_MATRIX_SUMMARY",
  "validateActionMatrix",
  "memberActions"
)) {
  Assert-True "registry marker present: $requiredMatrixMarker" $matrixSource.Contains($requiredMatrixMarker)
}
$productReport = Get-Content -LiteralPath $productReportPath -Raw | ConvertFrom-Json
$productSpecPath = Join-Path $frontendRoot "e2e\product-acceptance.spec.ts"
$productSpecSource = Get-Content -LiteralPath $productSpecPath -Raw
Assert-True "P0 product acceptance uses the exact workbench control" $productSpecSource.Contains('await page.getByTestId("ws-build").click();')
Assert-True "product-acceptance evidence is verified" ([string]$productReport.status -eq "verified")
$productBuildId = [string]$productReport.build.build_id
Assert-True "product-acceptance build id is valid" ($productBuildId -match "^[A-Za-z0-9_-]{1,64}$")
Assert-True "product-acceptance build is persisted" ([bool]$productReport.build.persisted -and [bool]$productReport.build.audit_persisted)
Assert-True "product-acceptance build used the approved live provider" ([bool]$productReport.build.live_provider_calls)

$evidencePath = if ([IO.Path]::IsPathRooted($EvidenceDir)) {
  [IO.Path]::GetFullPath($EvidenceDir)
} else {
  [IO.Path]::GetFullPath((Join-Path $repoRoot $EvidenceDir))
}
$repoPrefix = $repoRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
Assert-True "EvidenceDir must stay inside the repository" $evidencePath.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)
New-Item -ItemType Directory -Path $evidencePath -Force | Out-Null
$reportPath = Join-Path $evidencePath "report.json"
if (Test-Path -LiteralPath $reportPath -PathType Leaf) {
  Remove-Item -LiteralPath $reportPath -Force
}

$environmentNames = @(
  "PHASE6_BASE_URL",
  "PAGE_ACTIONS_BASE_URL",
  "PAGE_ACTIONS_ARTIFACT_DIR",
  "PAGE_ACTIONS_BUILD_ID",
  "PAGE_ACTIONS_GIT_HEAD"
)
$previousEnvironment = @{}
foreach ($name in $environmentNames) {
  $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, [EnvironmentVariableTarget]::Process)
}

$normalizedBaseUrl = $parsedBaseUrl.GetLeftPart([UriPartial]::Authority)
$gitHead = (& git.exe -C $repoRoot rev-parse HEAD).Trim()
Assert-True "git HEAD is available for source binding" ($gitHead -match "^[0-9a-f]{40}$")
Write-Host "[22-page-actions] DEV-ONLY base url: $normalizedBaseUrl"
Write-Host "[22-page-actions] only the two registered build controls may call the provider; mocks, interception, and Docker are forbidden"
Write-Host "[22-page-actions] evidence: $evidencePath"

$playwrightExitCode = 1
try {
  Set-ProcessEnvironment "PHASE6_BASE_URL" $normalizedBaseUrl
  Set-ProcessEnvironment "PAGE_ACTIONS_BASE_URL" $normalizedBaseUrl
  Set-ProcessEnvironment "PAGE_ACTIONS_ARTIFACT_DIR" $evidencePath
  Set-ProcessEnvironment "PAGE_ACTIONS_BUILD_ID" $productBuildId
  Set-ProcessEnvironment "PAGE_ACTIONS_GIT_HEAD" $gitHead

  & npm.cmd run test:e2e:22-page-actions --prefix $frontendRoot
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
  throw "22-page action acceptance failed in Chromium (exit $playwrightExitCode): $failure. Evidence: $reportPath"
}

Assert-True "report contract version" ([string]$report.contract_version -eq "22-page-action-acceptance-v2")
Assert-True "report status is verified" ([string]$report.status -eq "verified")
Assert-True "report is explicitly DEV-ONLY" ([bool]$report.dev_only -and -not [bool]$report.hosted_proof)
Assert-True "exactly 22 canonical routes registered" ([int]$report.registered_route_count -eq 22)
Assert-True "all 22 canonical routes visited" ([int]$report.visited_route_count -eq 22)
Assert-True "route registry parity" ([bool]$report.route_registry_parity)
Assert-True "every enabled family audited" (
  [int]$report.audited_enabled_family_count -eq [int]$report.registered_enabled_family_count
)
Assert-True "every enabled family has an effect proof" (
  [int]$report.effect_verified_family_count -eq [int]$report.registered_enabled_family_count
)
Assert-True "every enabled member action audited" (
  [int]$report.audited_enabled_member_action_count -eq [int]$report.registered_enabled_member_action_count
)
Assert-True "at least one enabled action family exists" ([int]$report.registered_enabled_family_count -gt 0)
Assert-True "at least one enabled member action exists" ([int]$report.registered_enabled_member_action_count -gt 0)
Assert-True "source binding hash exists" ([string]$report.source_binding_sha256 -match "^[0-9a-f]{64}$")
Assert-True "source binding records exact git HEAD" ([string]$report.source_binding.git_head -eq $gitHead)
Assert-True "all enabled actions are direct except exact P0 workbench control" (
  [int]$report.direct_effect_count + [int]$report.preverified_exact_control_count -eq [int]$report.registered_enabled_member_action_count
)
Assert-True "exactly one exact-control P0 proof" ([int]$report.preverified_exact_control_count -eq 1)
Assert-True "zero other non-direct passes" ([int]$report.non_direct_pass_count -eq 0)
$excludedAvailabilityCount = (
  [int]$report.excluded_spec_only_count +
  [int]$report.excluded_contract_only_count +
  [int]$report.excluded_provider_gated_count +
  [int]$report.excluded_conditional_count
)
Assert-True "excluded availability counts add up" (
  [int]$report.excluded_member_action_count -eq $excludedAvailabilityCount
)
Assert-True "zero unregistered visible page-local controls" ([int]$report.unregistered_page_local_action_count -eq 0)
Assert-True "zero dead actions" ([int]$report.dead_action_count -eq 0)
Assert-True "zero click-only passes" ([int]$report.click_only_passes -eq 0)
Assert-True "exactly two route-local build requests" (
  [int]$report.provider_request_count -eq 2 -and [int]$report.allowed_build_request_count -eq 2
)
Assert-True "both route-local builds report the approved live provider" ([int]$report.live_provider_response_count -eq 2)
Assert-True "zero provider bypass requests" ([int]$report.unexpected_provider_request_count -eq 0)
Assert-True "zero console errors" ([int]$report.console_error_count -eq 0)
Assert-True "zero page errors" ([int]$report.page_error_count -eq 0)
Assert-True "no mocks used" (-not [bool]$report.mocks_used -and -not [bool]$report.route_interception_used)
Assert-True "no secret output" (-not [bool]$report.secret_output)

Write-Host "[22-page-actions] PASS DEV-ONLY; hosted proof still blocked"
Write-Host "[22-page-actions] routes=22 families=$($report.audited_enabled_family_count) direct=$($report.direct_effect_count) preverified_exact=$($report.preverified_exact_control_count)"
Write-Host "[22-page-actions] report=$reportPath"

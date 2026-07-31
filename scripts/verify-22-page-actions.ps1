[CmdletBinding()]
param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [switch]$AllowHosted,
  [switch]$ApproveLiveProviderCalls,
  [string]$EvidenceDir = ".codex\runs\CURRENT\22-page-actions",
  [string]$ProductReportPath = ".codex\runs\CURRENT\product-acceptance\report.json",
  [string]$ExpectedSourceCommitSha = "",
  [string]$ExpectedDeploymentId = "",
  [string]$VercelScope = "strazzusochrs-projects",
  [string]$HostedStatePath = "docs\runtime-state\cloudflare-native-hosted-current.json",
  [switch]$PromoteHostedState
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

function Get-Sha256([string]$Path) {
  $resolved = (Resolve-Path -LiteralPath $Path).Path
  $stream = [IO.File]::OpenRead($resolved)
  $sha256 = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace("-", "")
  } finally {
    $sha256.Dispose()
    $stream.Dispose()
  }
}

function Get-GitArchiveSha256([string]$RepoRoot, [string]$CommitSha) {
  $temporaryPath = [IO.Path]::Combine(
    [IO.Path]::GetTempPath(),
    "cloud-superbrain-22-page-source-" + [Guid]::NewGuid().ToString("N") + ".tar"
  )
  try {
    & git.exe -C $RepoRoot archive --format=tar "--output=$temporaryPath" $CommitSha
    Assert-True "expected source archive can be created" ($LASTEXITCODE -eq 0)
    return (Get-Sha256 $temporaryPath).ToLowerInvariant()
  } finally {
    if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
      Remove-Item -LiteralPath $temporaryPath -Force
    }
  }
}

function Get-Utf8Sha256([string]$Value) {
  $algorithm = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    return -join ($algorithm.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") })
  } finally {
    $algorithm.Dispose()
  }
}

function Resolve-RepoScopedPath(
  [string]$RepoRoot,
  [string]$Path,
  [string]$Label,
  [bool]$MustExist,
  [bool]$Leaf = $true
) {
  $resolved = if ([IO.Path]::IsPathRooted($Path)) {
    [IO.Path]::GetFullPath($Path)
  } else {
    [IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
  }
  $repoPrefix = $RepoRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
  Assert-True "$Label stays inside the repository" $resolved.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)
  if ($MustExist) {
    $pathType = if ($Leaf) { "Leaf" } else { "Container" }
    Assert-True "$Label exists" (Test-Path -LiteralPath $resolved -PathType $pathType)
  }
  return $resolved
}

if (-not $ApproveLiveProviderCalls) {
  throw "22-page action acceptance requires explicit -ApproveLiveProviderCalls because two registered controls perform one real LLM provider call each and persist their builds."
}

$parsedBaseUrl = $null
if (-not [Uri]::TryCreate($BaseUrl, [UriKind]::Absolute, [ref]$parsedBaseUrl)) {
  throw "22-page action acceptance failed: BaseUrl must be an absolute URL."
}
$isLocalhost = @("localhost", "127.0.0.1", "::1") -contains $parsedBaseUrl.Host
Assert-True "BaseUrl must use http or https" ($parsedBaseUrl.Scheme -in @("http", "https"))
Assert-True "BaseUrl must not contain credentials" (-not $parsedBaseUrl.UserInfo)
Assert-True "BaseUrl must not contain query or fragment" (-not $parsedBaseUrl.Query -and -not $parsedBaseUrl.Fragment)
Assert-True "BaseUrl must be an origin without a path" ($parsedBaseUrl.AbsolutePath -eq "/")
if ($isLocalhost) {
  Assert-True "-AllowLocalhost is required for DEV-ONLY proof" $AllowLocalhost
  Assert-True "-AllowHosted cannot be combined with localhost" (-not [bool]$AllowHosted)
  Assert-True "DEV-ONLY BaseUrl must target localhost port 8081" ($parsedBaseUrl.Port -eq 8081)
  Assert-True "hosted-state promotion cannot use localhost" (-not [bool]$PromoteHostedState)
} else {
  Assert-True "-AllowHosted is required for hosted proof" $AllowHosted
  Assert-True "-AllowLocalhost cannot be combined with hosted proof" (-not [bool]$AllowLocalhost)
  Assert-True "hosted BaseUrl must use HTTPS" ($parsedBaseUrl.Scheme -eq "https")
  Assert-True "hosted BaseUrl must use standard HTTPS" ($parsedBaseUrl.Port -eq 443)
  Assert-True "hosted BaseUrl must be a Vercel deployment origin" $parsedBaseUrl.Host.EndsWith(".vercel.app", [StringComparison]::OrdinalIgnoreCase)
  Assert-True "hosted proof requires ExpectedSourceCommitSha" ($ExpectedSourceCommitSha -match "^[0-9a-f]{40}$")
  Assert-True "hosted proof requires ExpectedDeploymentId" ($ExpectedDeploymentId -match "^dpl_[A-Za-z0-9]+$")
  Assert-True "hosted proof requires VercelScope" (-not [string]::IsNullOrWhiteSpace($VercelScope))
}

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$repoPrefix = $repoRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
$frontendRoot = Join-Path $repoRoot "apps\frontend"
$specPath = Join-Path $frontendRoot "e2e\22-page-actions.spec.ts"
$matrixPath = Join-Path $frontendRoot "lib\actionMatrix.ts"
$navPath = Join-Path $frontendRoot "lib\nav.tsx"
$productSpecPath = Join-Path $frontendRoot "e2e\product-acceptance.spec.ts"
$resolvedProductReport = Resolve-RepoScopedPath -RepoRoot $repoRoot -Path $ProductReportPath -Label "green product-acceptance evidence" -MustExist $true
$resolvedHostedState = Resolve-RepoScopedPath -RepoRoot $repoRoot -Path $HostedStatePath -Label "hosted runtime state" -MustExist (-not $isLocalhost)
$productReportRelativePath = $resolvedProductReport.Substring($repoPrefix.Length).Replace("\", "/")
$productReportSha256 = Get-Sha256 $resolvedProductReport

Assert-True "Playwright 22-page action spec exists" (Test-Path -LiteralPath $specPath -PathType Leaf)
Assert-True "canonical action registry exists" (Test-Path -LiteralPath $matrixPath -PathType Leaf)
Assert-True "workspace navigation registry exists" (Test-Path -LiteralPath $navPath -PathType Leaf)
Assert-True "product-acceptance spec exists" (Test-Path -LiteralPath $productSpecPath -PathType Leaf)
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
  "mocks_used: false",
  "PAGE_ACTIONS_PROOF_SCOPE",
  "PAGE_ACTIONS_PRODUCT_REPORT_PATH"
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

$productReport = Get-Content -LiteralPath $resolvedProductReport -Raw | ConvertFrom-Json
$productSpecSource = Get-Content -LiteralPath $productSpecPath -Raw
Assert-True "P0 product acceptance uses the exact workbench control" $productSpecSource.Contains('await page.getByTestId("ws-build").click();')
Assert-True "product-acceptance evidence contract" ([string]$productReport.contract_version -eq "product-acceptance-3d-game-v1")
Assert-True "product-acceptance evidence is verified" ([string]$productReport.status -eq "verified")
$productBuildId = [string]$productReport.build.build_id
Assert-True "product-acceptance build id is valid" ($productBuildId -match "^[A-Za-z0-9_-]{1,64}$")
Assert-True "product-acceptance build is persisted with mutation audit proof" (
  [bool]$productReport.build.persisted -and [bool]$productReport.build.audit_persisted
)
Assert-True "product-acceptance build used the approved live provider" (
  [bool]$productReport.build.live_provider_calls -and
  [string]$productReport.build.gateway_provider -eq "cloudflare-workers-ai"
)
Assert-True "product-acceptance build did not bypass the gateway" (-not [bool]$productReport.build.direct_provider_calls)
Assert-True "product-acceptance emitted no secret" (-not [bool]$productReport.secret_output)

$normalizedBaseUrl = $parsedBaseUrl.GetLeftPart([UriPartial]::Authority)
$gitHead = (& git.exe -C $repoRoot rev-parse HEAD).Trim()
Assert-True "git HEAD is available for source binding" ($gitHead -match "^[0-9a-f]{40}$")
$sourceCommitSha = ""
$sourceArchiveSha256 = ""
$deploymentMetadataVerified = $false
$hostedState = $null
if (-not $isLocalhost) {
  Assert-True "hosted source commit equals current verifier HEAD" ($ExpectedSourceCommitSha -eq $gitHead)
  & git.exe -C $repoRoot cat-file -e "$ExpectedSourceCommitSha^{commit}" 2>$null
  Assert-True "expected hosted source commit exists" ($LASTEXITCODE -eq 0)
  & git.exe -C $repoRoot diff --quiet $ExpectedSourceCommitSha -- apps/frontend/e2e/22-page-actions.spec.ts apps/frontend/lib/actionMatrix.ts apps/frontend/lib/nav.tsx scripts/verify-22-page-actions.ps1
  Assert-True "hosted action spec, registries, and verifier match the expected source commit" ($LASTEXITCODE -eq 0)
  $sourceCommitSha = $ExpectedSourceCommitSha
  $sourceArchiveSha256 = Get-GitArchiveSha256 -RepoRoot $repoRoot -CommitSha $ExpectedSourceCommitSha

  Assert-True "product-acceptance report is hosted" (
    -not [bool]$productReport.dev_only -and
    [bool]$productReport.hosted_proof -and
    [string]$productReport.proof_scope -eq "hosted_https"
  )
  $productBaseUri = $null
  Assert-True "product-acceptance BaseUrl is absolute" (
    [Uri]::TryCreate([string]$productReport.base_url, [UriKind]::Absolute, [ref]$productBaseUri)
  )
  Assert-True "product-acceptance BaseUrl is hosted HTTPS" (
    $productBaseUri.Scheme -eq "https" -and
    $productBaseUri.Port -eq 443 -and
    $productBaseUri.Host.EndsWith(".vercel.app", [StringComparison]::OrdinalIgnoreCase)
  )
  $productSourceCommitSha = [string]$productReport.source_binding.source_commit_sha
  $productSourceArchiveSha256 = [string]$productReport.source_binding.source_archive_sha256
  $productDeploymentId = [string]$productReport.source_binding.deployment_id
  Assert-True "product-acceptance source commit is valid" ($productSourceCommitSha -match "^[0-9a-f]{40}$")
  Assert-True "product-acceptance source archive is valid" ($productSourceArchiveSha256 -match "^[0-9a-f]{64}$")
  Assert-True "product-acceptance deployment id is valid" ($productDeploymentId -match "^dpl_[A-Za-z0-9]+$")
  & git.exe -C $repoRoot merge-base --is-ancestor $productSourceCommitSha $ExpectedSourceCommitSha
  Assert-True "product-acceptance source is an ancestor of the hosted 22-page source" ($LASTEXITCODE -eq 0)
  & git.exe -C $repoRoot diff --quiet $productSourceCommitSha -- apps/frontend/e2e/product-acceptance.spec.ts scripts/verify-product-acceptance.ps1
  Assert-True "product-acceptance proof machinery is unchanged since its source-bound run" ($LASTEXITCODE -eq 0)

  $hostedState = Get-Content -LiteralPath $resolvedHostedState -Raw | ConvertFrom-Json
  Assert-True "hosted runtime state contract" ([string]$hostedState.contract_version -eq "cloudflare-native-hosted-current-v1")
  Assert-True "hosted O2Core state is verified" (
    [string]$hostedState.status -eq "verified" -and
    [bool]$hostedState.hosted_proof -and
    [bool]$hostedState.hosted_source_parity_verified -and
    [bool]$hostedState.hosted_stateful_roundtrip_verified -and
    -not [bool]$hostedState.r2_enabled -and
    -not [bool]$hostedState.paid_provider
  )
  Assert-True "hosted product-acceptance state is verified" ([bool]$hostedState.product_acceptance_hosted_proof)
  Assert-True "hosted product evidence path matches" (
    [string]$hostedState.product_acceptance_evidence_artifact -eq $productReportRelativePath
  )
  Assert-True "hosted product evidence hash matches" (
    [string]$hostedState.product_acceptance_evidence_sha256 -eq $productReportSha256
  )
  Assert-True "hosted product BaseUrl matches report" (
    [string]$hostedState.product_acceptance_base_url -eq [string]$productReport.base_url
  )
  Assert-True "hosted product source commit matches report" (
    [string]$hostedState.product_acceptance_source_commit_sha -eq $productSourceCommitSha
  )
  Assert-True "hosted product source archive matches report" (
    [string]$hostedState.product_acceptance_source_archive_sha256 -eq $productSourceArchiveSha256
  )
  Assert-True "hosted product deployment matches report" (
    [string]$hostedState.product_acceptance_deployment_id -eq $productDeploymentId
  )

  $vercelArguments = @(
    "api",
    "/v13/deployments/$ExpectedDeploymentId",
    "--scope",
    $VercelScope,
    "--raw"
  )
  if (-not [string]::IsNullOrWhiteSpace($env:VERCEL_TOKEN)) {
    $vercelArguments += @("--token", $env:VERCEL_TOKEN)
  }
  $previousErrorActionPreference = $ErrorActionPreference
  $vercelExitCode = 1
  try {
    $ErrorActionPreference = "Continue"
    $deploymentRaw = @(& vercel.cmd @vercelArguments 2>$null)
    $vercelExitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  Assert-True "authenticated Vercel deployment metadata lookup succeeds" ($vercelExitCode -eq 0)
  $deploymentJsonText = $deploymentRaw | Where-Object { $_ -match '^\{' } | Select-Object -Last 1
  Assert-True "Vercel deployment metadata payload exists" (-not [string]::IsNullOrWhiteSpace([string]$deploymentJsonText))
  $deployment = ([string]$deploymentJsonText) | ConvertFrom-Json
  $deploymentId = if (-not [string]::IsNullOrWhiteSpace([string]$deployment.id)) {
    [string]$deployment.id
  } else {
    [string]$deployment.uid
  }
  $deploymentTarget = if ([string]::IsNullOrWhiteSpace([string]$deployment.target)) {
    "preview"
  } else {
    [string]$deployment.target
  }
  Assert-True "Vercel deployment id matches" ($deploymentId -eq $ExpectedDeploymentId)
  Assert-True "Vercel deployment is READY" ([string]$deployment.readyState -eq "READY")
  Assert-True "Vercel deployment is preview-only" ($deploymentTarget -eq "preview")
  Assert-True "Vercel deployment source commit matches" ([string]$deployment.meta.githubCommitSha -eq $ExpectedSourceCommitSha)
  Assert-True "Vercel deployment URL matches BaseUrl" (("https://" + [string]$deployment.url) -eq $normalizedBaseUrl)
  $deploymentMetadataVerified = $true
}

$evidencePath = if ([IO.Path]::IsPathRooted($EvidenceDir)) {
  [IO.Path]::GetFullPath($EvidenceDir)
} else {
  [IO.Path]::GetFullPath((Join-Path $repoRoot $EvidenceDir))
}
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
  "PAGE_ACTIONS_GIT_HEAD",
  "PAGE_ACTIONS_PROOF_SCOPE",
  "PAGE_ACTIONS_SOURCE_COMMIT_SHA",
  "PAGE_ACTIONS_SOURCE_ARCHIVE_SHA256",
  "PAGE_ACTIONS_DEPLOYMENT_ID",
  "PAGE_ACTIONS_PRODUCT_REPORT_PATH"
)
$previousEnvironment = @{}
foreach ($name in $environmentNames) {
  $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, [EnvironmentVariableTarget]::Process)
}

$proofScope = if ($isLocalhost) { "dev_only_localhost" } else { "hosted_https" }
$proofLabel = if ($isLocalhost) { "DEV-ONLY" } else { "HOSTED-HTTPS" }
Write-Host "[22-page-actions] $proofLabel base url: $normalizedBaseUrl"
Write-Host "[22-page-actions] two registered build controls are explicitly approved; mocks, interception, and direct provider bypass are forbidden"
Write-Host "[22-page-actions] evidence: $evidencePath"

$playwrightExitCode = 1
try {
  Set-ProcessEnvironment "PHASE6_BASE_URL" $normalizedBaseUrl
  Set-ProcessEnvironment "PAGE_ACTIONS_BASE_URL" $normalizedBaseUrl
  Set-ProcessEnvironment "PAGE_ACTIONS_ARTIFACT_DIR" $evidencePath
  Set-ProcessEnvironment "PAGE_ACTIONS_BUILD_ID" $productBuildId
  Set-ProcessEnvironment "PAGE_ACTIONS_GIT_HEAD" $gitHead
  Set-ProcessEnvironment "PAGE_ACTIONS_PROOF_SCOPE" $proofScope
  Set-ProcessEnvironment "PAGE_ACTIONS_SOURCE_COMMIT_SHA" $sourceCommitSha
  Set-ProcessEnvironment "PAGE_ACTIONS_SOURCE_ARCHIVE_SHA256" $sourceArchiveSha256
  Set-ProcessEnvironment "PAGE_ACTIONS_DEPLOYMENT_ID" $(if ($isLocalhost) { "" } else { $ExpectedDeploymentId })
  Set-ProcessEnvironment "PAGE_ACTIONS_PRODUCT_REPORT_PATH" $resolvedProductReport

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
if ($isLocalhost) {
  Assert-True "report is explicitly DEV-ONLY" ([bool]$report.dev_only -and -not [bool]$report.hosted_proof)
  Assert-True "report has DEV-ONLY scope" ([string]$report.proof_scope -eq "dev_only_localhost")
} else {
  Assert-True "report is explicitly hosted" (-not [bool]$report.dev_only -and [bool]$report.hosted_proof)
  Assert-True "report has hosted HTTPS scope" ([string]$report.proof_scope -eq "hosted_https")
  Assert-True "hosted Vercel deployment metadata was verified" $deploymentMetadataVerified
  Assert-True "report source commit matches" ([string]$report.source_binding.source_commit_sha -eq $sourceCommitSha)
  Assert-True "report source archive matches" ([string]$report.source_binding.source_archive_sha256 -eq $sourceArchiveSha256)
  Assert-True "report deployment id matches" ([string]$report.source_binding.deployment_id -eq $ExpectedDeploymentId)
}
Assert-True "source binding records exact git HEAD" ([string]$report.source_binding.git_head -eq $gitHead)
Assert-True "source binding records exact product report path" (
  [string]$report.source_binding.product_acceptance_report_path -eq $productReportRelativePath
)
Assert-True "source binding records exact product report hash" (
  [string]$report.source_binding.product_acceptance_report_sha256 -eq $productReportSha256.ToLowerInvariant()
)

$expectedSourceFiles = @{
  action_spec = $specPath
  action_matrix = $matrixPath
  workspace_nav = $navPath
  product_acceptance_spec = $productSpecPath
  product_acceptance_report = $resolvedProductReport
}
$expectedSourceHashes = @{}
foreach ($entry in $expectedSourceFiles.GetEnumerator()) {
  $expectedHash = (Get-Sha256 $entry.Value).ToLowerInvariant()
  $expectedSourceHashes[$entry.Key] = $expectedHash
  Assert-True "source file hash matches: $($entry.Key)" (
    [string]$report.source_binding.files_sha256.PSObject.Properties[$entry.Key].Value -eq $expectedHash
  )
}
$sourceBindingMaterial = (
  $expectedSourceHashes.Keys |
    Sort-Object |
    ForEach-Object { "${_}:$($expectedSourceHashes[$_])" }
) -join "`n"
$expectedSourceBindingSha256 = Get-Utf8Sha256 $sourceBindingMaterial
Assert-True "source binding hash matches all bound files" (
  [string]$report.source_binding_sha256 -eq $expectedSourceBindingSha256
)

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

foreach ($actionId in @("home-build", "games-build-run")) {
  $matchingAction = @($report.actions | Where-Object { [string]$_.action_id -eq $actionId })
  Assert-True "$actionId has one direct proof" ($matchingAction.Count -eq 1)
  Assert-True "$actionId mutation proves persistence and audit" (
    [bool]$matchingAction[0].details.persisted -and [bool]$matchingAction[0].details.audit_persisted
  )
  Assert-True "$actionId uses the approved live gateway" (
    [bool]$matchingAction[0].details.live_provider_calls -and
    [string]$matchingAction[0].details.gateway_provider -eq "cloudflare-workers-ai" -and
    -not [bool]$matchingAction[0].details.direct_provider_calls
  )
}
$workbenchProof = @($report.actions | Where-Object { [string]$_.action_id -eq "workbench-build" })
Assert-True "workbench-build has one exact source-bound P0 proof" ($workbenchProof.Count -eq 1)
Assert-True "workbench-build binds the supplied product report" (
  [string]$workbenchProof[0].details.p0_product_acceptance_report_sha256 -eq $productReportSha256.ToLowerInvariant()
)

$reportSha256 = Get-Sha256 $reportPath
if ($PromoteHostedState) {
  Assert-True "hosted-state promotion requires hosted proof" (-not $isLocalhost)
  $hostedState = Get-Content -LiteralPath $resolvedHostedState -Raw | ConvertFrom-Json
  Assert-True "hosted state remains source-bound and product-verified" (
    [string]$hostedState.contract_version -eq "cloudflare-native-hosted-current-v1" -and
    [string]$hostedState.status -eq "verified" -and
    [bool]$hostedState.hosted_proof -and
    [bool]$hostedState.hosted_source_parity_verified -and
    [bool]$hostedState.hosted_stateful_roundtrip_verified -and
    [bool]$hostedState.product_acceptance_hosted_proof -and
    [string]$hostedState.product_acceptance_evidence_artifact -eq $productReportRelativePath -and
    [string]$hostedState.product_acceptance_evidence_sha256 -eq $productReportSha256 -and
    -not [bool]$hostedState.r2_enabled -and
    -not [bool]$hostedState.paid_provider
  )
  $reportRelativePath = $reportPath.Substring($repoPrefix.Length).Replace("\", "/")
  $workspaceVerifiedAtUtc = if ($report.completed_at -is [DateTime]) {
    ([DateTime]$report.completed_at).ToUniversalTime().ToString(
      "yyyy-MM-ddTHH:mm:ss.fffZ",
      [Globalization.CultureInfo]::InvariantCulture
    )
  } else {
    ([DateTimeOffset]::Parse(
      [string]$report.completed_at,
      [Globalization.CultureInfo]::InvariantCulture,
      [Globalization.DateTimeStyles]::RoundtripKind
    )).ToUniversalTime().ToString(
      "yyyy-MM-ddTHH:mm:ss.fffZ",
      [Globalization.CultureInfo]::InvariantCulture
    )
  }
  $hostedState.workspace_22_page_hosted_proof = $true
  $hostedState | Add-Member -NotePropertyName "workspace_22_page_verified_at_utc" -NotePropertyValue $workspaceVerifiedAtUtc -Force
  $hostedState | Add-Member -NotePropertyName "workspace_22_page_base_url" -NotePropertyValue $normalizedBaseUrl -Force
  $hostedState | Add-Member -NotePropertyName "workspace_22_page_deployment_id" -NotePropertyValue $ExpectedDeploymentId -Force
  $hostedState | Add-Member -NotePropertyName "workspace_22_page_source_commit_sha" -NotePropertyValue $sourceCommitSha -Force
  $hostedState | Add-Member -NotePropertyName "workspace_22_page_source_archive_sha256" -NotePropertyValue $sourceArchiveSha256 -Force
  $hostedState | Add-Member -NotePropertyName "workspace_22_page_evidence_artifact" -NotePropertyValue $reportRelativePath -Force
  $hostedState | Add-Member -NotePropertyName "workspace_22_page_evidence_sha256" -NotePropertyValue $reportSha256 -Force
  $hostedState | Add-Member -NotePropertyName "workspace_22_page_source_binding_sha256" -NotePropertyValue ([string]$report.source_binding_sha256) -Force
  $hostedState | Add-Member -NotePropertyName "workspace_22_page_product_evidence_sha256" -NotePropertyValue $productReportSha256 -Force
  $hostedState | Add-Member -NotePropertyName "workspace_22_page_registered_route_count" -NotePropertyValue ([int]$report.registered_route_count) -Force
  $hostedState | Add-Member -NotePropertyName "workspace_22_page_audited_family_count" -NotePropertyValue ([int]$report.audited_enabled_family_count) -Force
  $hostedState | Add-Member -NotePropertyName "workspace_22_page_audited_member_action_count" -NotePropertyValue ([int]$report.audited_enabled_member_action_count) -Force
  $hostedState | Add-Member -NotePropertyName "workspace_22_page_direct_effect_count" -NotePropertyValue ([int]$report.direct_effect_count) -Force
  $hostedState | Add-Member -NotePropertyName "workspace_22_page_preverified_exact_control_count" -NotePropertyValue ([int]$report.preverified_exact_control_count) -Force
  $hostedState | Add-Member -NotePropertyName "workspace_22_page_dead_action_count" -NotePropertyValue ([int]$report.dead_action_count) -Force
  $hostedState | Add-Member -NotePropertyName "workspace_22_page_unregistered_action_count" -NotePropertyValue ([int]$report.unregistered_page_local_action_count) -Force
  $hostedState | Add-Member -NotePropertyName "workspace_22_page_click_only_pass_count" -NotePropertyValue ([int]$report.click_only_passes) -Force
  $hostedState | Add-Member -NotePropertyName "workspace_22_page_non_direct_pass_count" -NotePropertyValue ([int]$report.non_direct_pass_count) -Force
  $hostedState | Add-Member -NotePropertyName "workspace_22_page_live_provider_response_count" -NotePropertyValue ([int]$report.live_provider_response_count) -Force
  $hostedState | Add-Member -NotePropertyName "workspace_22_page_unexpected_provider_request_count" -NotePropertyValue ([int]$report.unexpected_provider_request_count) -Force
  $hostedState | Add-Member -NotePropertyName "workspace_22_page_secret_output" -NotePropertyValue ([bool]$report.secret_output) -Force
  $hostedState.non_claims = @(
    "This state proves the hosted O2Core runtime, one source-bound hosted product-acceptance flow, and the source-bound hosted 22-page action matrix.",
    "This state does not prove Vectorize semantic retrieval, GHCR publication, production release, or any R2 capability.",
    "The bounded product and action proofs used only the LLM Gateway; direct provider calls and live MCP writes remained false.",
    "R2 remains unbound and historical-only; no paid fallback or percentage credit was used."
  )

  $temporaryState = $resolvedHostedState + ".candidate-" + [Guid]::NewGuid().ToString("N")
  $rollbackState = $resolvedHostedState + ".rollback-" + [Guid]::NewGuid().ToString("N")
  try {
    [IO.File]::WriteAllText(
      $temporaryState,
      ($hostedState | ConvertTo-Json -Depth 20),
      [Text.UTF8Encoding]::new($false)
    )
    $candidateState = Get-Content -LiteralPath $temporaryState -Raw | ConvertFrom-Json
    Assert-True "candidate hosted 22-page state is verified" (
      [bool]$candidateState.workspace_22_page_hosted_proof -and
      [string]$candidateState.workspace_22_page_evidence_sha256 -eq $reportSha256 -and
      [int]$candidateState.workspace_22_page_dead_action_count -eq 0 -and
      [int]$candidateState.workspace_22_page_unregistered_action_count -eq 0 -and
      [int]$candidateState.workspace_22_page_click_only_pass_count -eq 0 -and
      [int]$candidateState.workspace_22_page_unexpected_provider_request_count -eq 0 -and
      -not [bool]$candidateState.workspace_22_page_secret_output
    )
    [IO.File]::Replace($temporaryState, $resolvedHostedState, $rollbackState, $true)
  } finally {
    if (Test-Path -LiteralPath $temporaryState -PathType Leaf) {
      Remove-Item -LiteralPath $temporaryState -Force
    }
    if (Test-Path -LiteralPath $rollbackState -PathType Leaf) {
      Remove-Item -LiteralPath $rollbackState -Force
    }
  }
}

$resultLabel = if ($isLocalhost) { "PASS DEV-ONLY; hosted proof still blocked" } else { "PASS HOSTED; hosted_proof=true" }
Write-Host "[22-page-actions] $resultLabel"
Write-Host "[22-page-actions] routes=22 families=$($report.audited_enabled_family_count) members=$($report.audited_enabled_member_action_count) direct=$($report.direct_effect_count) preverified_exact=$($report.preverified_exact_control_count)"
Write-Host "[22-page-actions] report=$reportPath sha256=$reportSha256"

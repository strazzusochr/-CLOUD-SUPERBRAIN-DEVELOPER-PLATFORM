[CmdletBinding()]
param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [switch]$AllowHosted,
  [switch]$ApproveLiveProviderCall,
  [string]$ExpectedGatewayProvider = "cloudflare-workers-ai",
  [string]$EvidenceDir = ".codex\runs\CURRENT\product-acceptance",
  [string]$ExpectedSourceCommitSha = "",
  [string]$ExpectedDeploymentId = "",
  [string]$VercelScope = "strazzusochrs-projects",
  [string]$HostedStatePath = "docs\runtime-state\cloudflare-native-hosted-current.json",
  [switch]$PromoteHostedState
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

function Get-GitArchiveSha256([string]$RepoRoot, [string]$CommitSha) {
  $temporaryPath = [IO.Path]::Combine(
    [IO.Path]::GetTempPath(),
    "cloud-superbrain-product-source-" + [Guid]::NewGuid().ToString("N") + ".tar"
  )
  try {
    & git.exe -C $RepoRoot archive --format=tar "--output=$temporaryPath" $CommitSha
    Assert-True "expected source archive can be created" ($LASTEXITCODE -eq 0)
    return (Get-FileHash -LiteralPath $temporaryPath -Algorithm SHA256).Hash.ToLowerInvariant()
  } finally {
    if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
      Remove-Item -LiteralPath $temporaryPath -Force
    }
  }
}

function Resolve-RepoScopedPath([string]$RepoRoot, [string]$Path, [string]$Label, [bool]$MustExist) {
  $resolved = if ([IO.Path]::IsPathRooted($Path)) {
    [IO.Path]::GetFullPath($Path)
  } else {
    [IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
  }
  $repoPrefix = $RepoRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
  Assert-True "$Label stays inside the repository" $resolved.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)
  if ($MustExist) {
    Assert-True "$Label exists" (Test-Path -LiteralPath $resolved -PathType Leaf)
  }
  return $resolved
}

if (-not $ApproveLiveProviderCall) {
  throw "Product acceptance requires explicit -ApproveLiveProviderCall because it performs one real LLM provider call and persists one build."
}

$parsedBaseUrl = $null
if (-not [Uri]::TryCreate($BaseUrl, [UriKind]::Absolute, [ref]$parsedBaseUrl)) {
  throw "Product acceptance failed: BaseUrl must be an absolute URL."
}
$isLocalhost = @("localhost", "127.0.0.1", "::1") -contains $parsedBaseUrl.Host
Assert-True "BaseUrl must use http or https" ($parsedBaseUrl.Scheme -in @("http", "https"))
Assert-True "BaseUrl must not contain credentials" (-not $parsedBaseUrl.UserInfo)
Assert-True "BaseUrl must not contain query or fragment" (-not $parsedBaseUrl.Query -and -not $parsedBaseUrl.Fragment)
Assert-True "BaseUrl must be an origin without a path" ($parsedBaseUrl.AbsolutePath -eq "/")
Assert-True "ExpectedGatewayProvider is required" (-not [string]::IsNullOrWhiteSpace($ExpectedGatewayProvider))
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
$frontendRoot = Join-Path $repoRoot "apps\frontend"
$specPath = Join-Path $frontendRoot "e2e\product-acceptance.spec.ts"
$normalizedBaseUrl = $parsedBaseUrl.GetLeftPart([UriPartial]::Authority)
$sourceCommitSha = ""
$sourceArchiveSha256 = ""
$deploymentMetadataVerified = $false
if (-not $isLocalhost) {
  $gitHead = (& git.exe -C $repoRoot rev-parse HEAD).Trim()
  Assert-True "git HEAD is available for hosted source binding" ($gitHead -match "^[0-9a-f]{40}$")
  Assert-True "hosted source commit equals current verifier HEAD" ($ExpectedSourceCommitSha -eq $gitHead)
  & git.exe -C $repoRoot cat-file -e "$ExpectedSourceCommitSha^{commit}" 2>$null
  Assert-True "expected hosted source commit exists" ($LASTEXITCODE -eq 0)
  & git.exe -C $repoRoot diff --quiet $ExpectedSourceCommitSha -- apps/frontend scripts/verify-product-acceptance.ps1
  Assert-True "hosted frontend and product verifier match the expected source commit" ($LASTEXITCODE -eq 0)
  $sourceCommitSha = $ExpectedSourceCommitSha
  $sourceArchiveSha256 = Get-GitArchiveSha256 -RepoRoot $repoRoot -CommitSha $ExpectedSourceCommitSha

  $deploymentRaw = @(
    & vercel.cmd api "/v13/deployments/$ExpectedDeploymentId" `
      --scope $VercelScope `
      --raw 2>$null
  )
  Assert-True "authenticated Vercel deployment metadata lookup succeeds" ($LASTEXITCODE -eq 0)
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
  "PRODUCT_ACCEPTANCE_EXPECTED_GATEWAY_PROVIDER",
  "PRODUCT_ACCEPTANCE_SOURCE_COMMIT_SHA",
  "PRODUCT_ACCEPTANCE_SOURCE_ARCHIVE_SHA256",
  "PRODUCT_ACCEPTANCE_DEPLOYMENT_ID"
)
$previousEnvironment = @{}
foreach ($name in $environmentNames) {
  $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, [EnvironmentVariableTarget]::Process)
}

$proofScope = if ($isLocalhost) { "DEV-ONLY" } else { "HOSTED-HTTPS" }
Write-Host "[product-acceptance] $proofScope base url: $normalizedBaseUrl"
Write-Host "[product-acceptance] one live provider call explicitly approved; expected gateway: $ExpectedGatewayProvider"
Write-Host "[product-acceptance] evidence: $evidencePath"

$playwrightExitCode = 1
try {
  Set-ProcessEnvironment "PHASE6_BASE_URL" $normalizedBaseUrl
  Set-ProcessEnvironment "PRODUCT_ACCEPTANCE_BASE_URL" $normalizedBaseUrl
  Set-ProcessEnvironment "PRODUCT_ACCEPTANCE_ARTIFACT_DIR" $evidencePath
  Set-ProcessEnvironment "PRODUCT_ACCEPTANCE_EXPECTED_GATEWAY_PROVIDER" $ExpectedGatewayProvider
  Set-ProcessEnvironment "PRODUCT_ACCEPTANCE_SOURCE_COMMIT_SHA" $sourceCommitSha
  Set-ProcessEnvironment "PRODUCT_ACCEPTANCE_SOURCE_ARCHIVE_SHA256" $sourceArchiveSha256
  Set-ProcessEnvironment "PRODUCT_ACCEPTANCE_DEPLOYMENT_ID" $(if ($isLocalhost) { "" } else { $ExpectedDeploymentId })

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

$reportSha256 = (Get-FileHash -LiteralPath $reportPath -Algorithm SHA256).Hash.ToUpperInvariant()
if ($PromoteHostedState) {
  Assert-True "hosted-state promotion requires hosted proof" (-not $isLocalhost)
  $resolvedHostedState = Resolve-RepoScopedPath -RepoRoot $repoRoot -Path $HostedStatePath -Label "Hosted runtime state" -MustExist $true
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
  $reportRelativePath = $reportPath.Substring($repoPrefix.Length).Replace("\", "/")
  $hostedState.product_acceptance_hosted_proof = $true
  $hostedState | Add-Member -NotePropertyName "product_acceptance_verified_at_utc" -NotePropertyValue ([string]$report.completed_at) -Force
  $hostedState | Add-Member -NotePropertyName "product_acceptance_base_url" -NotePropertyValue $normalizedBaseUrl -Force
  $hostedState | Add-Member -NotePropertyName "product_acceptance_deployment_id" -NotePropertyValue $ExpectedDeploymentId -Force
  $hostedState | Add-Member -NotePropertyName "product_acceptance_source_commit_sha" -NotePropertyValue $sourceCommitSha -Force
  $hostedState | Add-Member -NotePropertyName "product_acceptance_source_archive_sha256" -NotePropertyValue $sourceArchiveSha256 -Force
  $hostedState | Add-Member -NotePropertyName "product_acceptance_evidence_artifact" -NotePropertyValue $reportRelativePath -Force
  $hostedState | Add-Member -NotePropertyName "product_acceptance_evidence_sha256" -NotePropertyValue $reportSha256 -Force
  $hostedState | Add-Member -NotePropertyName "product_acceptance_build_post_count" -NotePropertyValue ([int]$report.build_post_count) -Force
  $hostedState | Add-Member -NotePropertyName "product_acceptance_live_provider_calls" -NotePropertyValue ([bool]$report.build.live_provider_calls) -Force
  $hostedState | Add-Member -NotePropertyName "product_acceptance_direct_provider_calls" -NotePropertyValue ([bool]$report.build.direct_provider_calls) -Force
  $hostedState | Add-Member -NotePropertyName "product_acceptance_secret_output" -NotePropertyValue ([bool]$report.secret_output) -Force
  $hostedState.non_claims = @(
    "This state proves the hosted O2Core runtime and one source-bound hosted product-acceptance flow.",
    "This state does not yet prove the hosted 22-page action matrix, Vectorize semantic retrieval, GHCR publication, or production release.",
    "The product proof used one bounded live-provider build through the LLM Gateway; direct provider calls and live MCP writes remained false.",
    "R2 remains unbound and historical-only; no paid fallback or percentage credit was used."
  )

  $temporaryState = $resolvedHostedState + ".candidate-" + [Guid]::NewGuid().ToString("N")
  $rollbackState = $resolvedHostedState + ".rollback-" + [Guid]::NewGuid().ToString("N")
  try {
    [IO.File]::WriteAllText(
      $temporaryState,
      ($hostedState | ConvertTo-Json -Depth 16),
      [Text.UTF8Encoding]::new($false)
    )
    $candidateState = Get-Content -LiteralPath $temporaryState -Raw | ConvertFrom-Json
    Assert-True "candidate hosted product state is verified" (
      [bool]$candidateState.product_acceptance_hosted_proof -and
      [string]$candidateState.product_acceptance_evidence_sha256 -eq $reportSha256
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
Write-Host "[product-acceptance] $resultLabel"
Write-Host "[product-acceptance] build_id=$($report.build.build_id) provider=$($report.build.gateway_provider) live_provider_calls=true"
Write-Host "[product-acceptance] report=$reportPath sha256=$reportSha256"

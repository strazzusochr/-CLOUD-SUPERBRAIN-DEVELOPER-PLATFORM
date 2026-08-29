param(
  [string]$ConfigPath = "docs\runtime-state\frontend-hosted-current.json",
  [switch]$StaticOnly,
  [switch]$SkipBrowser,
  [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Assert-Equal($Actual, $Expected, [string]$Label) {
  if ($Actual -ne $Expected) { throw "$Label expected '$Expected' but got '$Actual'" }
}

function ConvertFrom-JsonPreservingDates([string]$Json) {
  if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey("DateKind")) {
    return ConvertFrom-Json -InputObject $Json -DateKind String
  }
  return ConvertFrom-Json -InputObject $Json
}

function Get-ContentSha([string]$Content) {
  $bytes = [Text.Encoding]::UTF8.GetBytes($Content)
  $sha256 = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha256.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
  } finally {
    $sha256.Dispose()
  }
}

function Get-HttpText([string]$Uri) {
  Add-Type -AssemblyName System.Net.Http
  $handler = New-Object System.Net.Http.HttpClientHandler
  $handler.AllowAutoRedirect = $false
  $client = New-Object System.Net.Http.HttpClient($handler)
  $client.Timeout = [TimeSpan]::FromSeconds(30)
  try {
    $response = $client.GetAsync($Uri).GetAwaiter().GetResult()
    $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    return [pscustomobject]@{
      StatusCode = [int]$response.StatusCode
      Content = $content
      ContentType = [string]$response.Content.Headers.ContentType.MediaType
      FinalUri = [string]$response.RequestMessage.RequestUri.AbsoluteUri
    }
  } finally {
    $client.Dispose()
  }
}

function Assert-JsonFalseProperty([object]$Value, [string]$PropertyName, [string]$Label) {
  $property = $Value.PSObject.Properties[$PropertyName]
  Assert-True ($null -ne $property) "$Label property '$PropertyName' is missing"
  Assert-Equal ([bool]$property.Value) $false "$Label property '$PropertyName'"
}

function ConvertTo-ExactHost([string]$Value, [string]$Label) {
  Assert-True (-not [string]::IsNullOrWhiteSpace($Value)) "$Label is missing"
  $candidate = $Value.Trim()
  if ($candidate -match '^https://') {
    try {
      $uri = [Uri]$candidate
    } catch {
      throw "$Label is not a valid HTTPS URL"
    }
    Assert-Equal ([string]$uri.Scheme) "https" "$Label scheme"
    Assert-True ($uri.IsDefaultPort) "$Label must not use a custom port"
    Assert-Equal ([string]$uri.AbsolutePath) "/" "$Label path"
    Assert-True ([string]::IsNullOrWhiteSpace([string]$uri.Query)) "$Label must not contain a query"
    Assert-True ([string]::IsNullOrWhiteSpace([string]$uri.Fragment)) "$Label must not contain a fragment"
    return $uri.DnsSafeHost.ToLowerInvariant()
  }
  Assert-True ($candidate -match '^[A-Za-z0-9.-]+$') "$Label is not a host"
  return $candidate.ToLowerInvariant()
}

function ConvertTo-UtcInstant($Value, [string]$Label) {
  Assert-True ($null -ne $Value) "$Label is missing"
  $text = [string]$Value
  Assert-True (-not [string]::IsNullOrWhiteSpace($text)) "$Label is missing"
  if ($text -match '^\d+$') {
    try {
      $milliseconds = [Convert]::ToInt64($text, [Globalization.CultureInfo]::InvariantCulture)
      Assert-True ($milliseconds -gt 0) "$Label must be a positive Unix-millisecond timestamp"
      return [DateTimeOffset]::FromUnixTimeMilliseconds($milliseconds).ToUniversalTime()
    } catch {
      throw "$Label is not a valid Unix-millisecond timestamp"
    }
  }
  try {
    return [DateTimeOffset]::Parse(
      $text,
      [Globalization.CultureInfo]::InvariantCulture,
      [Globalization.DateTimeStyles]::RoundtripKind
    ).ToUniversalTime()
  } catch {
    throw "$Label is not a valid ISO-8601 timestamp"
  }
}

function Get-AuthenticatedDeployment([object]$Config, [string]$ExpectedTarget, [bool]$RequireArchive) {
  $vercelScope = if ([string]::IsNullOrWhiteSpace([string]$Config.vercel_scope)) {
    "strazzusochrs-projects"
  } else {
    [string]$Config.vercel_scope
  }
  $deploymentLookupExit = -1
  $previousErrorAction = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $deploymentRaw = @(& vercel.cmd api "/v13/deployments/$($Config.deployment_id)" `
      --scope $vercelScope --raw 2>$null)
    $deploymentLookupExit = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorAction
  }
  Assert-True ($deploymentLookupExit -eq 0) "Authenticated Vercel frontend deployment metadata lookup failed"
  Assert-True ($deploymentRaw.Count -gt 0) "Authenticated Vercel frontend deployment metadata was empty"
  try {
    $deployment = ConvertFrom-JsonPreservingDates ($deploymentRaw -join "`n")
  } catch {
    throw "Authenticated Vercel frontend deployment metadata was not valid JSON"
  }

  Assert-Equal ([string]$deployment.id) ([string]$Config.deployment_id) "Vercel frontend deployment id"
  Assert-Equal ([string]$deployment.readyState) "READY" "Vercel frontend deployment state"
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$deployment.target)) "Vercel frontend deployment target is missing"
  Assert-Equal ([string]$deployment.target) $ExpectedTarget "Vercel frontend deployment target"
  Assert-Equal ([string]$deployment.projectId) ([string]$Config.vercel_project_id) "Vercel frontend project id"
  Assert-Equal ([string]$deployment.project.id) ([string]$Config.vercel_project_id) "Vercel frontend nested project id"
  Assert-Equal ([string]$deployment.name) ([string]$Config.vercel_project_name) "Vercel frontend deployment project name"
  Assert-Equal ([string]$deployment.project.name) ([string]$Config.vercel_project_name) "Vercel frontend nested project name"
  Assert-Equal ([string]$deployment.source) "redeploy" "Vercel frontend deployment source"
  Assert-Equal ([string]$deployment.meta.action) "redeploy" "Vercel frontend deployment action"

  $configuredDeploymentHost = ConvertTo-ExactHost ([string]$Config.immutable_deployment_url) "configured immutable deployment URL"
  $actualDeploymentHost = ConvertTo-ExactHost ([string]$deployment.url) "Vercel frontend deployment URL"
  Assert-Equal $actualDeploymentHost $configuredDeploymentHost "Vercel frontend deployment URL host"

  if ($ExpectedTarget -eq "production") {
    $configuredAliasHost = ConvertTo-ExactHost ([string]$Config.production_alias) "configured production alias"
    $actualAliasHosts = @(
      foreach ($aliasValue in @($deployment.alias)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$aliasValue)) {
          ConvertTo-ExactHost ([string]$aliasValue) "Vercel frontend deployment alias"
        }
      }
    )
    Assert-True ($actualAliasHosts.Count -gt 0) "Vercel frontend deployment aliases are missing"
    Assert-True ($actualAliasHosts -contains $configuredAliasHost) "Configured production alias is not assigned to the Vercel frontend deployment"
  }

  $shaCandidates = [ordered]@{
    "meta.sourceCommitSha" = [string]$deployment.meta.sourceCommitSha
    "gitSource.sha" = [string]$deployment.gitSource.sha
    "meta.githubCommitSha" = [string]$deployment.meta.githubCommitSha
  }
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$deployment.gitSource.sha)) "Vercel frontend authoritative gitSource.sha is missing"
  Assert-Equal ([string]$deployment.gitSource.type) ([string]$Config.git_source_type) "Vercel frontend git source type"
  Assert-Equal ([string]$deployment.gitSource.repoId) ([string]$Config.git_source_repo_id) "Vercel frontend git repository id"
  Assert-Equal ([string]$deployment.gitSource.ref) ([string]$Config.git_source_ref) "Vercel frontend git ref"
  $populatedShaCandidates = @(
    foreach ($entry in $shaCandidates.GetEnumerator()) {
      if (-not [string]::IsNullOrWhiteSpace($entry.Value)) {
        $normalizedSha = $entry.Value.ToLowerInvariant()
        Assert-True ($normalizedSha -match '^[0-9a-f]{40}$') "Vercel frontend SHA source $($entry.Key) is invalid"
        [pscustomobject]@{ Name = $entry.Key; Value = $normalizedSha }
      }
    }
  )
  Assert-True ($populatedShaCandidates.Count -gt 0) "Vercel frontend deployment metadata contains no source SHA"
  $distinctSourceShas = @($populatedShaCandidates.Value | Sort-Object -Unique)
  Assert-Equal $distinctSourceShas.Count 1 "Vercel frontend source SHA consensus count"
  foreach ($shaCandidate in $populatedShaCandidates) {
    Assert-Equal $shaCandidate.Value ([string]$Config.source_commit_sha) "Vercel frontend source SHA $($shaCandidate.Name)"
  }

  if ($RequireArchive) {
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$deployment.meta.sourceArchiveSha256)) "Vercel frontend archive SHA-256 metadata is missing"
    Assert-Equal ([string]$deployment.meta.sourceArchiveSha256) ([string]$Config.source_archive_sha256) "Vercel frontend archive SHA-256"
  } else {
    Assert-True ([string]::IsNullOrWhiteSpace([string]$deployment.meta.sourceArchiveSha256)) "Vercel frontend unexpectedly exposes an unbound archive SHA-256"
  }

  return [pscustomobject]@{
    Deployment = $deployment
    CreatedAt = ConvertTo-UtcInstant $deployment.createdAt "Vercel frontend deployment createdAt"
    AliasAssignedAt = ConvertTo-UtcInstant $deployment.aliasAssignedAt "Vercel frontend deployment aliasAssignedAt"
  }
}

function Assert-ProofFreshness([DateTimeOffset]$ProofGeneratedAt, [object]$DeploymentSnapshot, [string]$Label) {
  Assert-True ($ProofGeneratedAt -ge [DateTimeOffset]$DeploymentSnapshot.CreatedAt) "$Label predates Vercel deployment creation"
  Assert-True ($ProofGeneratedAt -ge [DateTimeOffset]$DeploymentSnapshot.AliasAssignedAt) "$Label predates Vercel alias assignment"
}

try {
  Assert-True (-not ($StaticOnly -and $ValidateOnly)) "Choose either static validation or full non-mutating validation, not both."
  if ($ValidateOnly) { $SkipBrowser = $true }

  Assert-True (Test-Path -LiteralPath $ConfigPath) "Hosted frontend proof config missing: $ConfigPath"
  $config = ConvertFrom-JsonPreservingDates (Get-Content -LiteralPath $ConfigPath -Raw)
  Assert-Equal ([string]$config.contract_version) "frontend-hosted-current-proof-v1" "config contract"
  Assert-Equal ([string]$config.status) "verified" "config status"
  Assert-True ([string]$config.source_commit_sha -match '^[0-9a-f]{40}$') "Invalid hosted frontend source SHA"
  Assert-True ([string]$config.deployment_id -match '^dpl_[A-Za-z0-9]+$') "Invalid Vercel deployment id"
  Assert-True ([string]$config.vercel_scope -match '^[A-Za-z0-9-]+$') "Invalid Vercel scope"
  Assert-True ([string]$config.vercel_project_id -match '^prj_[A-Za-z0-9]+$') "Invalid Vercel project id"
  Assert-True ([string]$config.vercel_project_name -match '^[A-Za-z0-9-]+$') "Invalid Vercel project name"
  Assert-Equal ([string]$config.git_source_type) "github" "configured git source type"
  Assert-True ([string]$config.git_source_repo_id -match '^\d+$') "Invalid configured git repository id"
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$config.git_source_ref)) "Configured git ref is missing"
  Assert-True ([string]$config.immutable_deployment_url -match '^https://[^/]+\.vercel\.app$') "Invalid immutable deployment URL"
  Assert-True ([string]$config.immutable_deployment_url -notmatch 'localhost|127\.0\.0\.1') "Hosted proof cannot use localhost"
  $null = ConvertTo-ExactHost ([string]$config.immutable_deployment_url) "configured immutable deployment URL"
  $vercelTarget = [string]$config.vercel_target
  if ([string]::IsNullOrWhiteSpace($vercelTarget)) { $vercelTarget = "production" }
  Assert-True (@("preview", "production") -contains $vercelTarget) "Invalid Vercel target"
  $productionAlias = [string]$config.production_alias
  if ($vercelTarget -eq "production") {
    Assert-True ($productionAlias -match '^https://[^/]+\.vercel\.app$') "Invalid production alias"
    $null = ConvertTo-ExactHost $productionAlias "configured production alias"
  } elseif (-not [string]::IsNullOrWhiteSpace($productionAlias)) {
    Assert-True ($productionAlias -match '^https://[^/]+\.vercel\.app$') "Invalid contextual production alias"
  }
  $browserBaseUrl = if ($vercelTarget -eq "production") {
    $productionAlias
  } else {
    [string]$config.immutable_deployment_url
  }
  $hasArchiveSha = -not [string]::IsNullOrWhiteSpace([string]$config.source_archive_sha256)
  if ($vercelTarget -eq "preview") {
    Assert-True $hasArchiveSha "Preview proof requires a source archive SHA-256"
  }
  if ($hasArchiveSha) {
    Assert-True ([string]$config.source_archive_sha256 -match '^[0-9a-f]{64}$') "Invalid hosted frontend archive SHA-256"
  }
  $aliasParityRequired = if ($null -ne $config.PSObject.Properties["deployment_alias_content_parity"]) {
    [bool]$config.deployment_alias_content_parity
  } else {
    $vercelTarget -eq "production"
  }
  Assert-Equal $aliasParityRequired ($vercelTarget -eq "production") "target/alias parity contract"
  Assert-Equal ([string]$config.browser_channel) "chrome" "browser channel"
  Assert-Equal ([int]$config.page_count) 22 "configured page count"
  Assert-Equal ([int]$config.viewport_count) 2 "configured viewport count"
  Assert-Equal ([int]$config.click_navigation_count) 44 "configured click count"
  Assert-Equal ([int]$config.frontend_progress_before) 99 "frontend progress before"
  Assert-Equal ([int]$config.frontend_progress_after) 100 "frontend progress after"
  if ($vercelTarget -eq "production") {
    Assert-True ([bool]$config.production_operational_deploy_verified) "Production target requires operational deploy proof"
    Assert-Equal ([int]$config.read_endpoint_count) 32 "configured production read endpoint count"
    Assert-Equal ([int]$config.former_500_endpoint_count) 8 "configured former-500 endpoint count"
  }
  Assert-True (-not [bool]$config.production_release_claimed) "Hosted frontend proof cannot claim a platform production release"

  git cat-file -e "$($config.source_commit_sha)^{commit}" 2>$null
  Assert-True ($LASTEXITCODE -eq 0) "Hosted frontend source commit is unavailable locally"
  git merge-base --is-ancestor ([string]$config.source_commit_sha) HEAD
  Assert-True ($LASTEXITCODE -eq 0) "Hosted frontend source commit is not an ancestor of HEAD"

  $runnerSource = Get-Content -LiteralPath "scripts\verify-workspace-responsive-browser.cjs" -Raw
  foreach ($marker in @("--browser-channel", "browser_channel", "browser_version", "hosted_https")) {
    Assert-True $runnerSource.Contains($marker) "Responsive runner missing hosted Chrome marker: $marker"
  }

  if ($StaticOnly) {
    Write-Host "[frontend-hosted-current] static checks completed"
    exit 0
  }

  $deploymentBefore = Get-AuthenticatedDeployment $config $vercelTarget $hasArchiveSha

  $proofPath = Join-Path $repoRoot ([string]$config.proof_artifact)
  $proofDir = Split-Path -Parent $proofPath
  if (-not $SkipBrowser) {
    & node "scripts\verify-workspace-responsive-browser.cjs" `
      --base-url $browserBaseUrl `
      --out ([string](Split-Path -Parent ([string]$config.proof_artifact))) `
      --browser-channel chrome
    Assert-True ($LASTEXITCODE -eq 0) "Hosted Google Chrome 22x2 proof failed"
  }

  Assert-True (Test-Path -LiteralPath $proofPath) "Hosted frontend proof report missing: $proofPath"
  $proof = ConvertFrom-JsonPreservingDates (Get-Content -LiteralPath $proofPath -Raw)
  Assert-Equal ([string]$proof.contract_version) "frontend-22-page-responsive-browser-v1" "proof contract"
  Assert-Equal ([string]$proof.status) "verified" "proof status"
  Assert-Equal ([string]$proof.scope) "hosted_https" "proof scope"
  Assert-Equal ([string]$proof.base_url) $browserBaseUrl "proof URL"
  Assert-Equal ([string]$proof.browser_channel) "chrome" "proof browser channel"
  Assert-True ([string]$proof.browser_version -match '^\d+\.\d+\.\d+\.\d+$') "Proof browser version is invalid"
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$config.browser_version)) "Configured browser version is missing"
  Assert-Equal ([string]$proof.browser_version) ([string]$config.browser_version) "configured/report browser version"
  Assert-Equal ([int]$proof.page_count) 22 "proof page count"
  Assert-Equal ([int]$proof.viewport_count) 2 "proof viewport count"
  Assert-Equal ([int]$proof.click_navigation_count) 44 "proof click count"
  Assert-Equal ([int]$proof.overflow_failures) 0 "proof overflow failures"
  Assert-Equal ([int]$proof.overlay_collision_failures) 0 "proof overlay collision failures"
  Assert-Equal ([int]$proof.console_errors) 0 "proof console errors"
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$config.proof_generated_at)) "Configured proof_generated_at is required for a dynamic hosted proof"
  Assert-Equal ([string]$proof.generated_at) ([string]$config.proof_generated_at) "configured/report proof generated_at"
  $proofGeneratedAt = ConvertTo-UtcInstant $proof.generated_at "hosted proof generated_at"
  Assert-ProofFreshness $proofGeneratedAt $deploymentBefore "Hosted frontend proof"

  $desktop = @($proof.results.desktop)
  $mobile = @($proof.results.mobile)
  $expectedRoutes = @(
    "/workbench", "/organism", "/organism/replay", "/organism/map", "/agents",
    "/files", "/files/local", "/tools", "/marketplace", "/observe", "/games",
    "/apps", "/media", "/docs-output", "/evidence", "/diagnostics",
    "/design-system", "/technology", "/settings", "/open-source", "/home", "/login"
  )
  Assert-Equal $desktop.Count 22 "desktop route count"
  Assert-Equal $mobile.Count 22 "mobile route count"
  foreach ($entry in @($desktop + $mobile)) {
    Assert-True ([bool]$entry.clickNavigation) "Route was not reached by a real command-palette click: $($entry.route)"
    Assert-True ([int]$entry.horizontalDocumentOverflow -le 2) "Route overflow exceeded 2px: $($entry.route)"
    Assert-Equal @($entry.overflowElements).Count 0 "route overflow elements $($entry.route)"
    Assert-Equal @($entry.overlayCollisions).Count 0 "route overlay collisions $($entry.route)"
    Assert-Equal @($entry.consoleErrors).Count 0 "route console errors $($entry.route)"
    Assert-True (-not [bool]$entry.notFoundVisible) "Not-found marker visible on $($entry.route)"
  }
  $desktopRouteKey = (($desktop.route | Sort-Object) -join ',')
  $mobileRouteKey = (($mobile.route | Sort-Object) -join ',')
  $expectedRouteKey = (($expectedRoutes | Sort-Object) -join ',')
  Assert-Equal @($desktop.route | Sort-Object -Unique).Count 22 "unique desktop route count"
  Assert-Equal @($mobile.route | Sort-Object -Unique).Count 22 "unique mobile route count"
  Assert-Equal $desktopRouteKey $expectedRouteKey "canonical desktop route inventory"
  Assert-Equal $mobileRouteKey $expectedRouteKey "canonical mobile route inventory"
  Assert-Equal $desktopRouteKey $mobileRouteKey "desktop/mobile route parity"

  $expectedScreenshots = @("desktop-home.png", "desktop-organism.png", "mobile-home.png", "mobile-organism.png")
  $actualScreenshots = @($proof.screenshots)
  Assert-Equal $actualScreenshots.Count 4 "proof screenshot count"
  Assert-Equal @($actualScreenshots | Sort-Object -Unique).Count 4 "unique proof screenshot count"
  Assert-Equal (($actualScreenshots | Sort-Object) -join ',') (($expectedScreenshots | Sort-Object) -join ',') "proof screenshot inventory"
  foreach ($screenshot in $actualScreenshots) {
    $screenshotPath = Join-Path $proofDir ([string]$screenshot)
    Assert-True (Test-Path -LiteralPath $screenshotPath) "Hosted screenshot missing: $screenshot"
    Assert-True ((Get-Item -LiteralPath $screenshotPath).Length -gt 20000) "Hosted screenshot too small: $screenshot"
  }

  $deploymentRoot = Get-HttpText "$($config.immutable_deployment_url)/"
  $deploymentWiring = Get-HttpText "$($config.immutable_deployment_url)/api/v1/workspace/wiring"
  foreach ($response in @($deploymentRoot, $deploymentWiring)) {
    Assert-Equal ([int]$response.StatusCode) 200 "hosted response status"
  }
  Assert-Equal ([string]$deploymentRoot.ContentType) "text/html" "immutable root content type"
  Assert-Equal ([string]$deploymentWiring.ContentType) "application/json" "immutable wiring content type"
  $deploymentAliasContentParity = $false
  if ($aliasParityRequired) {
    $aliasRoot = Get-HttpText "$productionAlias/"
    $aliasWiring = Get-HttpText "$productionAlias/api/v1/workspace/wiring"
    foreach ($response in @($aliasRoot, $aliasWiring)) {
      Assert-Equal ([int]$response.StatusCode) 200 "hosted alias response status"
    }
    Assert-Equal ([string]$aliasRoot.ContentType) "text/html" "alias root content type"
    Assert-Equal ([string]$aliasWiring.ContentType) "application/json" "alias wiring content type"
    Assert-Equal (Get-ContentSha $deploymentRoot.Content) (Get-ContentSha $aliasRoot.Content) "deployment/alias root parity"
    Assert-Equal (Get-ContentSha $deploymentWiring.Content) (Get-ContentSha $aliasWiring.Content) "deployment/alias wiring parity"
    $deploymentAliasContentParity = $true
  }
  $wiring = $deploymentWiring.Content | ConvertFrom-Json
  Assert-Equal ([string]$wiring.contract_version) "workspace-surface-wiring-v1" "hosted wiring contract"
  Assert-Equal @($wiring.surfaces).Count 22 "hosted wiring page count"

  $former500Paths = @(
    "/api/v1/agent-activity/recent",
    "/api/v1/audit/mcp",
    "/api/v1/audit/recent",
    "/api/v1/escalations/recent",
    "/api/v1/memory/consolidation/recent",
    "/api/v1/rotation/events",
    "/api/v1/sessions/recent",
    "/api/v1/workspace/artifacts"
  )
  $requiredReadPaths = @($former500Paths) + @(
    "/api/v1/health",
    "/api/v1/builds",
    "/api/v1/memory/embedding-consistency/contract",
    "/api/v1/organism/contract",
    "/api/v1/organism/events",
    "/api/v1/organism/live-state",
    "/api/v1/organism/replay",
    "/api/v1/organism/topology",
    "/api/v1/organism/regions",
    "/api/v1/organism/safety",
    "/api/v1/auth/session",
    "/api/v1/auth/contract",
    "/api/health",
    "/api/v1/design/reference-contract",
    "/api/v1/workspace/wiring",
    "/api/v1/workspace/vertical-stack",
    "/api/v1/platform/verify",
    "/api/v1/models/capabilities",
    "/api/v1/project/progress",
    "/api/v1/project/progress/integrity",
    "/api/v1/clouds",
    "/api/v1/clouds/layers",
    "/api/v1/metrics",
    "/api/v1/agents/status"
  )
  Assert-Equal $requiredReadPaths.Count 32 "hosted read endpoint inventory"
  foreach ($path in $requiredReadPaths) {
    $requestedUri = "$browserBaseUrl$path"
    $response = Get-HttpText $requestedUri
    Assert-Equal ([int]$response.StatusCode) 200 "hosted read endpoint $path"
    Assert-Equal ([string]$response.FinalUri) $requestedUri "hosted read endpoint final URI $path"
    if ($path -eq "/api/v1/metrics") {
      Assert-Equal ([string]$response.ContentType) "text/plain" "hosted metrics content type"
      Assert-True (-not [string]::IsNullOrWhiteSpace([string]$response.Content)) "Hosted metrics response is empty"
      continue
    }
    Assert-Equal ([string]$response.ContentType) "application/json" "hosted JSON content type $path"
    try {
      $responseJson = $response.Content | ConvertFrom-Json
    } catch {
      throw "Hosted read endpoint returned invalid JSON: $path"
    }
    Assert-True ($null -ne $responseJson) "Hosted read endpoint returned null JSON: $path"
    if ($former500Paths -contains $path) {
      Assert-Equal ([string]$responseJson.source) "frontend-projection" "former-500 source label $path"
      foreach ($falseProperty in @(
        "live_backend", "direct_provider_calls", "live_provider_calls",
        "live_mcp_writes", "production_deploy", "secret_output"
      )) {
        Assert-JsonFalseProperty $responseJson $falseProperty "former-500 response $path"
      }
    }
  }

  # Bracket all browser, content-parity, and endpoint work with authenticated
  # metadata reads so the final verified artifact cannot rely on stale binding.
  $deploymentAfter = Get-AuthenticatedDeployment $config $vercelTarget $hasArchiveSha
  Assert-ProofFreshness $proofGeneratedAt $deploymentAfter "Hosted frontend proof"

  $verification = [ordered]@{
    contract_version = "frontend-hosted-current-verification-v1"
    status = "verified"
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    source_commit_sha = [string]$config.source_commit_sha
    source_archive_sha256 = if ($hasArchiveSha) { [string]$config.source_archive_sha256 } else { $null }
    deployment_id = [string]$config.deployment_id
    immutable_deployment_url = [string]$config.immutable_deployment_url
    production_alias = $productionAlias
    vercel_target = $vercelTarget
    browser_channel = [string]$proof.browser_channel
    browser_version = [string]$proof.browser_version
    page_count = 22
    viewport_count = 2
    click_navigation_count = 44
    overflow_failures = 0
    overlay_collision_failures = 0
    console_errors = 0
    proof_generated_at = [string]$proof.generated_at
    deployment_created_at = ([DateTimeOffset]$deploymentAfter.CreatedAt).ToString("o")
    alias_assigned_at = ([DateTimeOffset]$deploymentAfter.AliasAssignedAt).ToString("o")
    deployment_metadata_read_count = 2
    deployment_metadata_verified = $true
    deployment_alias_content_parity = $deploymentAliasContentParity
    browser_base_url = $browserBaseUrl
    read_endpoint_count = $requiredReadPaths.Count
    former_500_endpoint_count = $former500Paths.Count
    read_endpoint_failures = 0
    production_operational_deploy_verified = ($vercelTarget -eq "production")
    production_release_claimed = $false
  }
  $verificationPath = Join-Path $proofDir "verification.json"
  if (-not $ValidateOnly) {
    $verification | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $verificationPath -Encoding utf8
  }
  if ($ValidateOnly) {
    Write-Host "[frontend-hosted-current] status=verified target=$vercelTarget pages=22 viewports=2 clicks=44 browser=$($proof.browser_version) full_validation=true validation_mode=true browser_skipped=true verification_written=false"
  } else {
    Write-Host "[frontend-hosted-current] status=verified target=$vercelTarget pages=22 viewports=2 clicks=44 browser=$($proof.browser_version)"
  }
} finally {
  Pop-Location
}

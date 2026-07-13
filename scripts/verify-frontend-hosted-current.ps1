param(
  [string]$ConfigPath = "docs\runtime-state\frontend-hosted-current.json",
  [switch]$StaticOnly,
  [switch]$SkipBrowser
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
  $client = New-Object System.Net.Http.HttpClient
  $client.Timeout = [TimeSpan]::FromSeconds(30)
  try {
    $response = $client.GetAsync($Uri).GetAwaiter().GetResult()
    $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    return [pscustomobject]@{ StatusCode = [int]$response.StatusCode; Content = $content }
  } finally {
    $client.Dispose()
  }
}

try {
  Assert-True (Test-Path -LiteralPath $ConfigPath) "Hosted frontend proof config missing: $ConfigPath"
  $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
  Assert-Equal ([string]$config.contract_version) "frontend-hosted-current-proof-v1" "config contract"
  Assert-Equal ([string]$config.status) "verified" "config status"
  Assert-True ([string]$config.source_commit_sha -match '^[0-9a-f]{40}$') "Invalid hosted frontend source SHA"
  Assert-True ([string]$config.deployment_id -match '^dpl_[A-Za-z0-9]+$') "Invalid Vercel deployment id"
  Assert-True ([string]$config.immutable_deployment_url -match '^https://[^/]+\.vercel\.app$') "Invalid immutable deployment URL"
  Assert-True ([string]$config.production_alias -match '^https://[^/]+\.vercel\.app$') "Invalid production alias"
  Assert-True ([string]$config.immutable_deployment_url -notmatch 'localhost|127\.0\.0\.1') "Hosted proof cannot use localhost"
  Assert-Equal ([string]$config.browser_channel) "chrome" "browser channel"
  Assert-Equal ([int]$config.page_count) 22 "configured page count"
  Assert-Equal ([int]$config.viewport_count) 2 "configured viewport count"
  Assert-Equal ([int]$config.click_navigation_count) 44 "configured click count"
  Assert-Equal ([int]$config.frontend_progress_before) 99 "frontend progress before"
  Assert-Equal ([int]$config.frontend_progress_after) 100 "frontend progress after"
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

  $proofPath = Join-Path $repoRoot ([string]$config.proof_artifact)
  $proofDir = Split-Path -Parent $proofPath
  if (-not $SkipBrowser) {
    & node "scripts\verify-workspace-responsive-browser.cjs" `
      --base-url ([string]$config.immutable_deployment_url) `
      --out ([string](Split-Path -Parent ([string]$config.proof_artifact))) `
      --browser-channel chrome
    Assert-True ($LASTEXITCODE -eq 0) "Hosted Google Chrome 22x2 proof failed"
  }

  Assert-True (Test-Path -LiteralPath $proofPath) "Hosted frontend proof report missing: $proofPath"
  $proof = Get-Content -LiteralPath $proofPath -Raw | ConvertFrom-Json
  Assert-Equal ([string]$proof.contract_version) "frontend-22-page-responsive-browser-v1" "proof contract"
  Assert-Equal ([string]$proof.status) "verified" "proof status"
  Assert-Equal ([string]$proof.scope) "hosted_https" "proof scope"
  Assert-Equal ([string]$proof.base_url) ([string]$config.immutable_deployment_url) "proof URL"
  Assert-Equal ([string]$proof.browser_channel) "chrome" "proof browser channel"
  Assert-True ([string]$proof.browser_version -match '^\d+\.\d+\.\d+\.\d+$') "Proof browser version is invalid"
  Assert-Equal ([int]$proof.page_count) 22 "proof page count"
  Assert-Equal ([int]$proof.viewport_count) 2 "proof viewport count"
  Assert-Equal ([int]$proof.click_navigation_count) 44 "proof click count"
  Assert-Equal ([int]$proof.overflow_failures) 0 "proof overflow failures"
  Assert-Equal ([int]$proof.overlay_collision_failures) 0 "proof overlay collision failures"
  Assert-Equal ([int]$proof.console_errors) 0 "proof console errors"

  $desktop = @($proof.results.desktop)
  $mobile = @($proof.results.mobile)
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
  Assert-Equal $desktopRouteKey $mobileRouteKey "desktop/mobile route parity"

  foreach ($screenshot in @($proof.screenshots)) {
    $screenshotPath = Join-Path $proofDir ([string]$screenshot)
    Assert-True (Test-Path -LiteralPath $screenshotPath) "Hosted screenshot missing: $screenshot"
    Assert-True ((Get-Item -LiteralPath $screenshotPath).Length -gt 20000) "Hosted screenshot too small: $screenshot"
  }

  $deploymentRoot = Get-HttpText "$($config.immutable_deployment_url)/"
  $aliasRoot = Get-HttpText "$($config.production_alias)/"
  $deploymentWiring = Get-HttpText "$($config.immutable_deployment_url)/api/v1/workspace/wiring"
  $aliasWiring = Get-HttpText "$($config.production_alias)/api/v1/workspace/wiring"
  foreach ($response in @($deploymentRoot, $aliasRoot, $deploymentWiring, $aliasWiring)) {
    Assert-Equal ([int]$response.StatusCode) 200 "hosted response status"
  }
  Assert-Equal (Get-ContentSha $deploymentRoot.Content) (Get-ContentSha $aliasRoot.Content) "deployment/alias root parity"
  Assert-Equal (Get-ContentSha $deploymentWiring.Content) (Get-ContentSha $aliasWiring.Content) "deployment/alias wiring parity"
  $wiring = $deploymentWiring.Content | ConvertFrom-Json
  Assert-Equal ([string]$wiring.contract_version) "workspace-surface-wiring-v1" "hosted wiring contract"
  Assert-Equal @($wiring.surfaces).Count 22 "hosted wiring page count"

  $verification = [ordered]@{
    contract_version = "frontend-hosted-current-verification-v1"
    status = "verified"
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    source_commit_sha = [string]$config.source_commit_sha
    deployment_id = [string]$config.deployment_id
    immutable_deployment_url = [string]$config.immutable_deployment_url
    production_alias = [string]$config.production_alias
    browser_channel = [string]$proof.browser_channel
    browser_version = [string]$proof.browser_version
    page_count = 22
    viewport_count = 2
    click_navigation_count = 44
    overflow_failures = 0
    overlay_collision_failures = 0
    console_errors = 0
    deployment_alias_content_parity = $true
    production_release_claimed = $false
  }
  $verification | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $proofDir "verification.json") -Encoding utf8
  Write-Host "[frontend-hosted-current] status=verified pages=22 viewports=2 clicks=44 browser=$($proof.browser_version)"
} finally {
  Pop-Location
}

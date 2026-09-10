param(
  [string]$ReleaseId = "prod-candidate-2026-05-11-rc1",
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [string]$StagingIp = "188.34.191.140",
  [string]$KeyPath = "",
  [string]$RemoteAppDir = "/app"
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Verification failed: $label did not contain '$expected'."
  }
}

function Assert-Equal($label, $actual, $expected) {
  if ($actual -ne $expected) {
    throw "Verification failed: $label expected '$expected' but got '$actual'."
  }
}

function Assert-HttpsPublicUrl([string]$Url) {
  if ([string]::IsNullOrWhiteSpace($Url) -or -not $Url.StartsWith("https://")) {
    throw "BaseUrl must be a public https URL."
  }
  $uri = [Uri]$Url
  if ($uri.Host -in @("localhost", "127.0.0.1", "::1")) {
    throw "BaseUrl must not be localhost."
  }
}

function Invoke-DeployPlan($Arguments, [bool]$ShouldPass, [string]$ExpectedText) {
  $previousErrorActionPreference = $ErrorActionPreference
  $hasNativePreference = Test-Path variable:PSNativeCommandUseErrorActionPreference
  if ($hasNativePreference) {
    $previousNativePreference = $PSNativeCommandUseErrorActionPreference
  }
  $ErrorActionPreference = "Continue"
  if ($hasNativePreference) {
    $PSNativeCommandUseErrorActionPreference = $false
  }
  try {
    $output = @(& powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\deploy-to-staging.ps1" @Arguments 2>&1 | ForEach-Object { $_.ToString() }) | Out-String
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
    if ($hasNativePreference) {
      $PSNativeCommandUseErrorActionPreference = $previousNativePreference
    }
  }
  if ($ShouldPass -and $exitCode -ne 0) {
    throw "Verification failed: deploy plan expected PASS but failed with exit code $exitCode. Output: $output"
  }
  if (-not $ShouldPass -and $exitCode -eq 0) {
    throw "Verification failed: deploy plan expected FAIL but passed. Output: $output"
  }
  Assert-Contains "deploy plan output" $output $ExpectedText
  return $output
}

function Get-Json($Uri) {
  $response = Invoke-WebRequest -Uri $Uri -UseBasicParsing -TimeoutSec 30
  if ($response.StatusCode -ne 200) {
    throw "GET $Uri failed with HTTP $($response.StatusCode)."
  }
  return ($response.Content | ConvertFrom-Json)
}

Assert-HttpsPublicUrl $BaseUrl

$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)
$expectedFrontend = [int](($manifest.vertical.items | Where-Object { $_.id -eq "layer_1" }).percent)

$artifactPath = "docs\release-artifacts\$ReleaseId-frontend-source-build-path.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing frontend source build artifact: $artifactPath"
}
$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "release_id: ``$ReleaseId``",
  "overall_percent: ``$expectedOverall``",
  "phase_5_percent: ``$expectedPhase5``",
  "frontend_percent: ``$expectedFrontend``",
  'staging_only: `true`',
  'production_rollout_claimed: `false`',
  'ghcr_push_claimed: `false`',
  'immutable_candidate_parity_claimed: `false`',
  'frontend_container_image: `cloud-superbrain-frontend:source-staging`',
  'frontend_pull_policy: `never`',
  'backend_image_selector: `IMAGE_TAG=staging`',
  'rollback_observed_after_invalid_selector_attempt: `yes`'
)) {
  Assert-Contains "frontend source build artifact" $artifact $required
}

$deployScript = Get-Content "scripts\deploy-to-staging.ps1" -Raw
Assert-Contains "deploy script frontend source switch" $deployScript "[switch]`$FrontendSourceBuild"
Assert-Contains "deploy script source override" $deployScript "docker-compose.frontend-source.yml"
Assert-Contains "deploy script source pull policy" $deployScript "pull_policy: never"
Assert-Contains "deploy script immutable source guard" $deployScript "Frontend source builds are staging-only and cannot use immutable SHA image tags."

$planOutput = Invoke-DeployPlan @(
  "-PlanOnly",
  "-FrontendSourceBuild",
  "-ImageTag",
  "staging"
) $true "Build frontend on remote: True"
Assert-Contains "frontend source plan override" $planOutput "Frontend source build override: docker-compose.frontend-source.yml"
Assert-Contains "frontend source plan pull set" $planOutput "Pull services: agent-api agent-worker memory-worker mcp-gateway llm-gateway nginx caddy"

Invoke-DeployPlan @(
  "-PlanOnly",
  "-FrontendSourceBuild",
  "-ImageTag",
  "b0c2773b1d122745947315a8d39734d5a6c96d6b"
) $false "Frontend source builds are staging-only and cannot use immutable SHA image tags." | Out-Null

$root = Invoke-WebRequest -Uri $BaseUrl -UseBasicParsing -TimeoutSec 30
if ($root.StatusCode -ne 200) {
  throw "Hosted root failed with HTTP $($root.StatusCode)."
}
foreach ($marker in @("Cloud Superbrain", "Project Progress", "Live Agent Control", "Runtime Guard")) {
  Assert-Contains "hosted frontend root" $root.Content $marker
}

$health = Get-Json "$BaseUrl/api/v1/health"
Assert-Equal "hosted health status" $health.status "healthy"
$progress = Get-Json "$BaseUrl/api/v1/project/progress"
Assert-Equal "hosted overall percent" $progress.overall_percent $expectedOverall
$phase5 = $progress.horizontal.items | Where-Object { $_.id -eq "phase_5" } | Select-Object -First 1
Assert-Equal "hosted phase5 percent" $phase5.percent $expectedPhase5
$frontend = $progress.vertical.items | Where-Object { $_.id -eq "layer_1" } | Select-Object -First 1
Assert-Equal "hosted frontend percent" $frontend.percent $expectedFrontend

if (-not [string]::IsNullOrWhiteSpace($KeyPath)) {
  $remoteProof = @(ssh -i $KeyPath -o StrictHostKeyChecking=no "root@$StagingIp" "cd $RemoteAppDir && docker compose --env-file .env -f docker-compose.cloud.yml -f docker-compose.frontend-source.yml ps frontend --format json && grep -n 'pull_policy: never\|cloud-superbrain-frontend:source-staging' docker-compose.frontend-source.yml" 2>&1 | ForEach-Object { $_.ToString() }) | Out-String
  if ($LASTEXITCODE -ne 0) {
    throw "Remote frontend source proof failed: $remoteProof"
  }
  Assert-Contains "remote frontend source image" $remoteProof "cloud-superbrain-frontend:source-staging"
  Assert-Contains "remote frontend pull policy" $remoteProof "pull_policy: never"
}

Write-Host "[phase5-frontend-source-build-path] verified"

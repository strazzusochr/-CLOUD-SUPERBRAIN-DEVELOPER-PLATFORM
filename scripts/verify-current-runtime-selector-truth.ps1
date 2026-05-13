param(
  [string]$ReleaseId = "",
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [string]$RemoteHost = "188.34.191.140",
  [string]$RemoteUser = "root",
  [string]$RemoteAppDir = "/app",
  [string]$KeyPath = "",
  [switch]$RequireRemoteProof
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

function Assert-False($label, $value) {
  if ([bool]$value) {
    throw "Verification failed: $label expected false."
  }
}

function Assert-PublicHttpsUrl($label, $value) {
  if ([string]::IsNullOrWhiteSpace($value)) {
    throw "Verification failed: $label is empty."
  }
  $uri = [System.Uri]$value
  if ($uri.Scheme -ne "https") {
    throw "Verification failed: $label must use https."
  }
  if ($uri.Host -in @("localhost", "127.0.0.1", "::1")) {
    throw "Verification failed: $label must not be localhost."
  }
}

function Assert-RemotePath($label, $value) {
  if ([string]::IsNullOrWhiteSpace($value) -or $value -notmatch '^/[A-Za-z0-9_./-]+$') {
    throw "Verification failed: $label contains unsafe remote path characters."
  }
}

function Assert-RemoteIdentity($label, $value) {
  if ([string]::IsNullOrWhiteSpace($value) -or $value -notmatch '^[A-Za-z0-9_.:-]+$') {
    throw "Verification failed: $label contains unsafe remote identity characters."
  }
}

function Get-Json($Uri) {
  (Invoke-WebRequest -UseBasicParsing -Uri $Uri -TimeoutSec 30).Content | ConvertFrom-Json
}

Assert-PublicHttpsUrl "BaseUrl" $BaseUrl
Assert-RemotePath "RemoteAppDir" $RemoteAppDir
Assert-RemoteIdentity "RemoteHost" $RemoteHost
Assert-RemoteIdentity "RemoteUser" $RemoteUser

$config = Get-Content "docs\release-artifacts\current-release-candidate.json" -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($ReleaseId)) {
  $ReleaseId = [string]$config.active_release_id
}
Assert-False "production rollout claimed" $config.production_rollout_claimed

$candidatePath = "docs\release-artifacts\$ReleaseId.md"
if (-not (Test-Path $candidatePath)) {
  throw "Missing release candidate artifact: $candidatePath"
}
$candidate = Get-Content $candidatePath -Raw
Assert-Contains "release artifact parity block" $candidate 'immutable_staging_parity_status: `blocked_after_frontend_source_build`'
Assert-Contains "release artifact hosted selector" $candidate 'hosted_selector_observed: `IMAGE_TAG=staging`'
Assert-Contains "release artifact frontend runtime image" $candidate 'frontend_runtime_image_observed: `cloud-superbrain-frontend:source-staging`'
Assert-Contains "release artifact non-claim" $candidate "This artifact does not claim a production rollout."

$artifactPath = "docs\release-artifacts\$ReleaseId-runtime-selector-truth.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing runtime selector truth artifact: $artifactPath"
}
$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified-blocked`',
  "release_id: ``$ReleaseId``",
  'current_hosted_selector: `IMAGE_TAG=staging`',
  'frontend_runtime_image: `cloud-superbrain-frontend:source-staging`',
  'immutable_candidate_parity_claimed: `false`',
  'production_rollout_claimed: `false`',
  'ghcr_push_claimed: `false`',
  'immutable_staging_parity_status: `blocked_after_frontend_source_build`',
  'next_allowed_action: `build_new_immutable_candidate_or_run_image_filesystem_candidate_deploy`'
)) {
  Assert-Contains "runtime selector truth artifact" $artifact $required
}

$root = Invoke-WebRequest -Uri $BaseUrl -UseBasicParsing -TimeoutSec 30
Assert-Equal "hosted root status" ([int]$root.StatusCode) 200
Assert-Contains "hosted root current UI marker" $root.Content "Live Agent Control"
Assert-Contains "hosted root runtime guard marker" $root.Content "Runtime Guard"

$progress = Get-Json "$BaseUrl/api/v1/project/progress"
Assert-Equal "hosted overall percent" ([int]$progress.overall_percent) 71
$phase5 = $progress.horizontal.items | Where-Object { $_.id -eq "phase_5" } | Select-Object -First 1
Assert-Equal "hosted phase5 percent" ([int]$phase5.percent) 69

if ([string]::IsNullOrWhiteSpace($KeyPath)) {
  $KeyPath = [Environment]::GetEnvironmentVariable("STAGING_SSH_KEY_PATH")
}
if ($RequireRemoteProof -and [string]::IsNullOrWhiteSpace($KeyPath)) {
  throw "RequireRemoteProof needs -KeyPath or STAGING_SSH_KEY_PATH."
}

if (-not [string]::IsNullOrWhiteSpace($KeyPath)) {
  $remoteProof = @(ssh -i $KeyPath -o StrictHostKeyChecking=no "${RemoteUser}@${RemoteHost}" "cd $RemoteAppDir && grep '^IMAGE_TAG=' .env && docker compose --env-file .env -f docker-compose.cloud.yml -f docker-compose.frontend-source.yml ps frontend --format json && grep -n 'pull_policy: never\|cloud-superbrain-frontend:source-staging' docker-compose.frontend-source.yml" 2>&1 | ForEach-Object { $_.ToString() }) | Out-String
  if ($LASTEXITCODE -ne 0) {
    throw "Remote runtime selector proof failed: $remoteProof"
  }
  Assert-Contains "remote selector" $remoteProof "IMAGE_TAG=staging"
  Assert-Contains "remote frontend image" $remoteProof "cloud-superbrain-frontend:source-staging"
  Assert-Contains "remote frontend pull policy" $remoteProof "pull_policy: never"
}

Write-Host "[current-runtime-selector-truth] verified-blocked"

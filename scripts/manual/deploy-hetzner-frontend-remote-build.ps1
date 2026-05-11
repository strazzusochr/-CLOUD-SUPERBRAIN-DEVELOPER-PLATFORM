param(
  [string]$StagingIp = "188.34.191.140",
  [string]$RemoteUser = "root",
  [string]$RemoteAppDir = "/app",
  [string]$KeyPath = "",
  [string]$ImageTag = ("frontend-remote-" + (Get-Date -Format "yyyyMMddHHmmss")),
  [string]$StagingBaseUrl = "https://188-34-191-140.sslip.io",
  [switch]$PlanOnly
)

$ErrorActionPreference = "Stop"

function Assert-SafeTag([string]$Tag) {
  if ([string]::IsNullOrWhiteSpace($Tag) -or $Tag.Length -gt 128 -or $Tag -notmatch '^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$') {
    throw "Invalid Docker tag: $Tag"
  }
}

function Assert-RemoteHost([string]$HostName) {
  if ([string]::IsNullOrWhiteSpace($HostName) -or $HostName -notmatch '^[A-Za-z0-9_.:-]+$') {
    throw "Unsafe remote host: $HostName"
  }
}

function Assert-RemoteUser([string]$User) {
  if ([string]::IsNullOrWhiteSpace($User) -or $User -notmatch '^[A-Za-z_][A-Za-z0-9_-]{0,31}$') {
    throw "Unsafe remote user: $User"
  }
}

function Assert-RemotePath([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path) -or $Path -notmatch '^/[A-Za-z0-9_./-]+$') {
    throw "Unsafe remote path: $Path"
  }
}

function Invoke-Ssh([string]$Command) {
  ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingIp" $Command
  if ($LASTEXITCODE -ne 0) {
    throw "SSH failed: $Command"
  }
}

function Invoke-Scp([string]$Source, [string]$Destination) {
  scp -i $KeyPath -o StrictHostKeyChecking=no $Source "${RemoteUser}@${StagingIp}:$Destination"
  if ($LASTEXITCODE -ne 0) {
    throw "SCP failed: $Source -> $Destination"
  }
}

if ([string]::IsNullOrWhiteSpace($KeyPath)) {
  $KeyPath = [Environment]::GetEnvironmentVariable("STAGING_SSH_KEY_PATH")
}
if ([string]::IsNullOrWhiteSpace($KeyPath)) {
  throw "KeyPath or STAGING_SSH_KEY_PATH is required."
}

Assert-SafeTag $ImageTag
Assert-RemoteHost $StagingIp
Assert-RemoteUser $RemoteUser
Assert-RemotePath $RemoteAppDir

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).ProviderPath
$frontendPath = Join-Path $repoRoot "apps\frontend"
if (-not (Test-Path -LiteralPath (Join-Path $frontendPath "Dockerfile") -PathType Leaf)) {
  throw "Frontend Dockerfile missing: $frontendPath"
}

$namespace = "ghcr.io/strazzusochr/cloud-superbrain-developer-platform"
$image = "$namespace/frontend:$ImageTag"
$remoteBuildDir = "/tmp/superbrain-frontend-build-$ImageTag"
$remoteArchive = "$remoteBuildDir/frontend.tar"
$remoteOverride = "$RemoteAppDir/docker-compose.frontend-remote-build.yml"

Write-Host "[plan] host=$StagingIp"
Write-Host "[plan] image=$image"
Write-Host "[plan] remote_build_dir=$remoteBuildDir"
Write-Host "[plan] override=$remoteOverride"
if ($PlanOnly) {
  return
}

$archivePath = Join-Path ([System.IO.Path]::GetTempPath()) ("superbrain-frontend-" + [Guid]::NewGuid().ToString("N") + ".tar")
try {
  Push-Location $frontendPath
  tar --exclude node_modules --exclude .next --exclude out --exclude coverage --exclude .env -cf $archivePath .
  if ($LASTEXITCODE -ne 0) {
    throw "tar archive failed for apps/frontend"
  }
} finally {
  Pop-Location
}

try {
  Invoke-Ssh "rm -rf $remoteBuildDir && mkdir -p $remoteBuildDir"
  Invoke-Scp $archivePath $remoteArchive
  Invoke-Ssh "cd $remoteBuildDir && tar -xf frontend.tar && docker build -t $image ."

  $override = @"
services:
  frontend:
    image: $image
    pull_policy: never
"@
  $overridePath = Join-Path ([System.IO.Path]::GetTempPath()) ("superbrain-frontend-override-" + [Guid]::NewGuid().ToString("N") + ".yml")
  Set-Content -LiteralPath $overridePath -Value $override -Encoding UTF8
  Invoke-Scp $overridePath $remoteOverride
  Remove-Item -LiteralPath $overridePath -Force

  Invoke-Ssh "cd $RemoteAppDir && docker compose --env-file .env -f docker-compose.cloud.yml -f docker-compose.frontend-remote-build.yml up -d --no-deps frontend"

  $probe = Invoke-WebRequest -Uri $StagingBaseUrl -UseBasicParsing -TimeoutSec 30
  if ($probe.StatusCode -ne 200) {
    throw "Hosted root probe failed after frontend remote build: $($probe.StatusCode)"
  }

  $health = Invoke-WebRequest -Uri "$StagingBaseUrl/api/v1/health" -UseBasicParsing -TimeoutSec 30
  if ($health.StatusCode -ne 200) {
    throw "Hosted API probe failed after frontend remote build: $($health.StatusCode)"
  }

  Write-Host "[done] frontend_remote_image=$image"
  Write-Host "[done] hosted_root=$StagingBaseUrl"
  Write-Host "[done] hosted_api=$StagingBaseUrl/api/v1/health"
} finally {
  if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
  }
}

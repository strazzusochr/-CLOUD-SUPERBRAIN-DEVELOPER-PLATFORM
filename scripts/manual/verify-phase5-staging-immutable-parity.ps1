param(
  [string]$ReleaseId = "",
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [string]$CandidateSha = "",
  [string]$RemoteHost = "188.34.191.140",
  [string]$RemoteUser = "root",
  [string]$RemoteAppDir = "/app",
  [string]$KeyPath = "",
  [switch]$RequireVerified
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

function Assert-Sha($label, $value) {
  if ([string]::IsNullOrWhiteSpace($value) -or $value -notmatch '^[0-9a-f]{40}$') {
    throw "Verification failed: $label is not a 40-character lowercase SHA."
  }
}

function Assert-ReleaseId($label, $value) {
  if ([string]::IsNullOrWhiteSpace($value) -or $value -notmatch '^prod-candidate-[0-9]{4}-[0-9]{2}-[0-9]{2}-rc[0-9]+$') {
    throw "Verification failed: $label is not a valid release candidate id."
  }
}

function Assert-PublicHttpsUrl($label, $value) {
  if ([string]::IsNullOrWhiteSpace($value)) {
    throw "Verification failed: $label is empty."
  }
  try {
    $uri = [System.Uri]$value
  } catch {
    throw "Verification failed: $label is not a valid URL."
  }
  if ($uri.Scheme -ne "https") {
    throw "Verification failed: $label must use https."
  }
  $urlHost = $uri.Host.ToLowerInvariant()
  if (
    $urlHost -eq "localhost" -or
    $urlHost.EndsWith(".local") -or
    $urlHost -match '^(127\.|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)'
  ) {
    throw "Verification failed: $label must be a public hosted URL, not $urlHost."
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

function Get-Json($uri) {
  (Invoke-WebRequest -UseBasicParsing -Uri $uri -TimeoutSec 30).Content
}

function Invoke-DeployPlan($Arguments) {
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
  if ($exitCode -ne 0) {
    throw "Verification failed: immutable deploy plan failed with exit code $exitCode. Output: $output"
  }
  return $output
}

function Invoke-Ssh($command) {
  ssh -i $KeyPath -o StrictHostKeyChecking=no "${RemoteUser}@${RemoteHost}" $command
  if ($LASTEXITCODE -ne 0) {
    throw "SSH command failed: $command"
  }
}

Assert-PublicHttpsUrl "BaseUrl" $BaseUrl
Assert-RemotePath "RemoteAppDir" $RemoteAppDir
Assert-RemoteIdentity "RemoteHost" $RemoteHost
Assert-RemoteIdentity "RemoteUser" $RemoteUser

$configPath = "docs\release-artifacts\current-release-candidate.json"
if ([string]::IsNullOrWhiteSpace($ReleaseId)) {
  if (-not (Test-Path $configPath)) {
    throw "Missing current release candidate config: $configPath"
  }
  $config = Get-Content $configPath -Raw | ConvertFrom-Json
  $ReleaseId = [string]$config.active_release_id
}
Assert-ReleaseId "ReleaseId" $ReleaseId

$candidatePath = "docs\release-artifacts\$ReleaseId.md"
if (-not (Test-Path $candidatePath)) {
  throw "Missing release candidate artifact: $candidatePath"
}
$candidate = Get-Content $candidatePath -Raw
Assert-Contains "candidate release id" $candidate "release_id: ``$ReleaseId``"
if ($candidate -notmatch '(?m)^source_commit_sha:\s*`([^`]+)`\s*$') {
  throw "Verification failed: candidate artifact missing source_commit_sha."
}
$candidateSourceSha = $Matches[1]
Assert-Sha "candidate source sha" $candidateSourceSha
if ($candidate -match '(?m)^immutable_image_commit_sha:\s*`([^`]+)`\s*$') {
  $immutableImageCommitSha = $Matches[1]
} else {
  $immutableImageCommitSha = $candidateSourceSha
}
Assert-Sha "candidate immutable image commit sha" $immutableImageCommitSha
if ([string]::IsNullOrWhiteSpace($CandidateSha)) {
  $CandidateSha = $immutableImageCommitSha
}
Assert-Sha "CandidateSha" $CandidateSha
Assert-Equal "candidate immutable image commit sha" $immutableImageCommitSha $CandidateSha
Assert-Contains "candidate immutable tag set" $candidate "immutable_tag_set: ``ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:$CandidateSha``"

$deployScript = Get-Content "scripts\deploy-to-staging.ps1" -Raw
Assert-Contains "deploy image filesystem switch" $deployScript "[switch]`$UseImageFilesystem"
Assert-Contains "deploy plan switch" $deployScript "[switch]`$PlanOnly"
Assert-Contains "deploy immutable guard" $deployScript "Immutable image tag deploys must use -UseImageFilesystem or matching -SourceRef"
Assert-Contains "deploy rollback guard" $deployScript "Staging deploy failed; restoring previous remote selector files."

$plan = Invoke-DeployPlan @(
  "-PlanOnly",
  "-UseImageFilesystem",
  "-ImageTag",
  $CandidateSha
)
Assert-Contains "immutable plan image filesystem" $plan "Use image filesystem: True"
Assert-Contains "immutable plan image tag" $plan "Image tag: $CandidateSha"
Assert-Contains "immutable plan services" $plan "Deploy services: frontend agent-api agent-worker memory-worker mcp-gateway llm-gateway nginx caddy"

if (-not $RequireVerified) {
  Write-Host "[phase5-staging-immutable-parity] ready"
  return
}

if ([string]::IsNullOrWhiteSpace($KeyPath)) {
  $KeyPath = [Environment]::GetEnvironmentVariable("STAGING_SSH_KEY_PATH")
}
if ([string]::IsNullOrWhiteSpace($KeyPath)) {
  throw "RequireVerified needs -KeyPath or STAGING_SSH_KEY_PATH."
}

$selector = (Invoke-Ssh "cd $RemoteAppDir && grep '^IMAGE_TAG=' .env").Trim()
Assert-Equal "remote IMAGE_TAG selector" $selector "IMAGE_TAG=$CandidateSha"

$hotMounts = (Invoke-Ssh "cd $RemoteAppDir && (grep -E './services/(agent-api|agent-worker|memory-worker|mcp-gateway|llm-gateway)/app:/app/app:ro' docker-compose.cloud.yml || true)") | Out-String
if (-not [string]::IsNullOrWhiteSpace($hotMounts)) {
  throw "Verification failed: remote compose still contains service app hot-mounts."
}

$namespace = "ghcr.io/strazzusochr/cloud-superbrain-developer-platform"
$services = @("frontend", "agent-api", "agent-worker", "memory-worker", "mcp-gateway", "llm-gateway")
foreach ($service in $services) {
  $containerId = (Invoke-Ssh "cd $RemoteAppDir && docker compose --env-file .env -f docker-compose.cloud.yml ps -q $service").Trim()
  if ([string]::IsNullOrWhiteSpace($containerId)) {
    throw "Verification failed: missing running container for $service."
  }
  $imageRef = (Invoke-Ssh "docker inspect --format '{{.Config.Image}}' $containerId").Trim()
  Assert-Equal "running image for $service" $imageRef "$namespace/${service}:$CandidateSha"
}

foreach ($url in @(
  "$BaseUrl/",
  "$BaseUrl/api/v1/health",
  "$BaseUrl/mcp/api/v1/health",
  "$BaseUrl/llm/api/v1/health"
)) {
  $status = (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 30).StatusCode
  Assert-Contains "hosted status $url" $status "200"
}

$integrity = Get-Json "$BaseUrl/api/v1/project/progress/integrity" | ConvertFrom-Json
Assert-Equal "hosted integrity status" $integrity.status "verified"

Write-Host "[phase5-staging-immutable-parity] verified"

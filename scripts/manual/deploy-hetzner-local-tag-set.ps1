param(
  [string]$StagingIp = "188.34.191.140",
  [string]$RemoteUser = "root",
  [string]$RemoteAppDir = "/app",
  [string]$KeyPath = "",
  [string]$TargetTag = "deploy-20260511-agentfix-full",
  [string]$StagingBaseUrl = "https://188-34-191-140.sslip.io",
  [switch]$PlanOnly
)

$ErrorActionPreference = "Stop"

function Assert-Tag([string]$Tag) {
  if ([string]::IsNullOrWhiteSpace($Tag) -or $Tag.Length -gt 128 -or $Tag -notmatch '^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$') {
    throw "Invalid tag: $Tag"
  }
}

function Assert-RemoteValue([string]$Name, [string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[A-Za-z0-9_./:-]+$') {
    throw "Unsafe ${Name}: $Value"
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

function Invoke-HostedStatus([string]$Url) {
  $python = @"
import ssl, sys, urllib.request
ctx = ssl._create_unverified_context()
with urllib.request.urlopen(sys.argv[1], context=ctx, timeout=30) as r:
    print(r.status)
"@
  $status = @($python) | py -3 - $Url
  if ($LASTEXITCODE -ne 0) {
    throw "Hosted probe failed: $Url"
  }
  return [int]($status | Select-Object -First 1)
}

if ([string]::IsNullOrWhiteSpace($KeyPath)) {
  $KeyPath = [Environment]::GetEnvironmentVariable("STAGING_SSH_KEY_PATH")
}
if ([string]::IsNullOrWhiteSpace($KeyPath)) {
  throw "KeyPath or STAGING_SSH_KEY_PATH is required."
}

Assert-Tag $TargetTag
Assert-RemoteValue "StagingIp" $StagingIp
Assert-RemoteValue "RemoteUser" $RemoteUser
Assert-RemoteValue "RemoteAppDir" $RemoteAppDir

$services = @("frontend", "agent-api", "agent-worker", "memory-worker", "mcp-gateway", "llm-gateway", "nginx", "caddy")
$appServices = @("frontend", "agent-api", "agent-worker", "memory-worker", "mcp-gateway", "llm-gateway")
$remoteOverride = "$RemoteAppDir/docker-compose.local-tag-set.yml"
$backupName = ".env.bak.local-tag-$([DateTime]::UtcNow.ToString("yyyyMMddHHmmss"))"

Write-Host "[plan] host=$StagingIp"
Write-Host "[plan] target_tag=$TargetTag"
Write-Host "[plan] override=$remoteOverride"
Write-Host "[plan] services=$($services -join ',')"
if ($PlanOnly) {
  return
}

$override = @"
services:
  frontend:
    pull_policy: never
  agent-api:
    pull_policy: never
  agent-worker:
    pull_policy: never
  memory-worker:
    pull_policy: never
  mcp-gateway:
    pull_policy: never
  llm-gateway:
    pull_policy: never
"@
$overridePath = Join-Path ([System.IO.Path]::GetTempPath()) ("superbrain-local-tag-set-" + [Guid]::NewGuid().ToString("N") + ".yml")
Set-Content -LiteralPath $overridePath -Value $override -Encoding UTF8

try {
  foreach ($service in $appServices) {
    Invoke-Ssh "docker image inspect ghcr.io/strazzusochr/cloud-superbrain-developer-platform/${service}:$TargetTag >/dev/null"
  }

  Invoke-Scp $overridePath $remoteOverride
  Invoke-Ssh "cd $RemoteAppDir && cp .env $backupName"
  Invoke-Ssh "cd $RemoteAppDir && grep -vE '^(IMAGE_TAG)=' .env > .env.tmp && printf 'IMAGE_TAG=%s\n' '$TargetTag' >> .env.tmp && mv .env.tmp .env"
  Invoke-Ssh "cd $RemoteAppDir && docker compose --env-file .env -f docker-compose.cloud.yml -f docker-compose.local-tag-set.yml up -d --force-recreate --remove-orphans $($services -join ' ')"

  foreach ($url in @($StagingBaseUrl, "$StagingBaseUrl/api/v1/health", "$StagingBaseUrl/llm/api/v1/health")) {
    $status = Invoke-HostedStatus $url
    if ($status -ne 200) {
      throw "Hosted probe returned ${status}: $url"
    }
  }

  Write-Host "[done] target_tag=$TargetTag"
  Write-Host "[done] hosted_root=$StagingBaseUrl"
} catch {
  Write-Warning "Local tag deploy failed; restoring previous .env selector."
  Invoke-Ssh "cd $RemoteAppDir && if [ -f $backupName ]; then cp $backupName .env; docker compose --env-file .env -f docker-compose.cloud.yml up -d --force-recreate --remove-orphans $($services -join ' '); fi"
  throw
} finally {
  if (Test-Path -LiteralPath $overridePath) {
    Remove-Item -LiteralPath $overridePath -Force
  }
}

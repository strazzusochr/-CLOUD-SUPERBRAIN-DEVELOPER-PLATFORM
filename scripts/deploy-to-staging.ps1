param(
    [string]$StagingIp = "188.34.191.140",
    [string]$KeyPath = "",
    [string]$RemoteAppDir = "/app",
    [string]$RemoteUser = "root",
    [string]$StagingBaseUrl = "",
    [string]$StagingHostname = "",
    [string]$ImageTag = "",
    [string]$SourceRef = "",
    [switch]$UseImageFilesystem,
    [switch]$FrontendSourceBuild,
    [switch]$PlanOnly,
    [switch]$RequireHttps = $true
)

$ErrorActionPreference = "Stop"
$DeploySourceRoot = (Get-Location).ProviderPath
$TemporaryPaths = @()

function Get-RequiredEnv([string]$Name) {
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Required environment variable missing: $Name"
    }
    return $value
}

function Assert-HttpsUrl([string]$Name, [string]$Url) {
    if ([string]::IsNullOrWhiteSpace($Url)) {
        throw "$Name must not be empty"
    }
    if (-not $Url.StartsWith("https://")) {
        throw "$Name must use https://"
    }
}

function Assert-DockerTag([string]$Name, [string]$Tag) {
    if ([string]::IsNullOrWhiteSpace($Tag)) {
        throw "$Name must not be empty"
    }
    if ($Tag.Length -gt 128 -or $Tag -notmatch '^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$') {
        throw "$Name contains invalid Docker tag characters"
    }
}

function Assert-GitRef([string]$Name, [string]$Ref) {
    if ([string]::IsNullOrWhiteSpace($Ref)) {
        return
    }
    if ($Ref.Length -gt 128 -or $Ref -notmatch '^[A-Za-z0-9_./-]+$') {
        throw "$Name contains invalid Git ref characters"
    }
}

function Assert-RemotePath([string]$Name, [string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path -notmatch '^/[A-Za-z0-9_./-]+$') {
        throw "$Name contains unsafe remote path characters"
    }
}

function Assert-RemoteUser([string]$Name, [string]$User) {
    if ([string]::IsNullOrWhiteSpace($User) -or $User -notmatch '^[A-Za-z_][A-Za-z0-9_-]{0,31}$') {
        throw "$Name contains unsafe SSH user characters"
    }
}

function Assert-RemoteHost([string]$Name, [string]$HostName) {
    if ([string]::IsNullOrWhiteSpace($HostName) -or $HostName -notmatch '^[A-Za-z0-9_.:-]+$') {
        throw "$Name contains unsafe SSH host characters"
    }
}

function Assert-RemoteValue([string]$Name, [string]$Value) {
    if ($null -eq $Value -or $Value -match "[\r\n']") {
        throw "$Name contains unsafe remote shell value characters"
    }
}

function Get-SourcePath([string]$RelativePath) {
    return Join-Path $DeploySourceRoot $RelativePath
}

function Register-TemporaryPath([string]$Path) {
    $script:TemporaryPaths += $Path
}

function Remove-TemporaryPaths {
    $tempRoot = [System.IO.Path]::GetTempPath()
    foreach ($path in $script:TemporaryPaths) {
        if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path)) {
            continue
        }
        $resolved = (Resolve-Path -LiteralPath $path).ProviderPath
        $leaf = Split-Path -Leaf $resolved
        if (-not $resolved.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -or -not $leaf.StartsWith("superbrain-deploy-source-", [System.StringComparison]::Ordinal)) {
            throw "Refusing to remove unexpected temporary path: $resolved"
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}

function Assert-SourceFile([string]$RelativePath) {
    $path = Get-SourcePath $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required deployment source file missing: $RelativePath"
    }
    return $path
}

function Assert-SourceDirectory([string]$RelativePath) {
    $path = Get-SourcePath $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Container)) {
        throw "Required deployment source directory missing: $RelativePath"
    }
    return $path
}

function Get-DefaultHostname([string]$Ip) {
    return ($Ip -replace '\.', '-') + ".sslip.io"
}

function Invoke-HostedGet([string]$Url) {
    $python = @"
import json, ssl, sys, urllib.request
url = sys.argv[1]
ctx = ssl.create_default_context()
with urllib.request.urlopen(url, context=ctx, timeout=30) as response:
    body = response.read().decode("utf-8", errors="replace")
    print(json.dumps({
        "status": response.status,
        "body": body
    }))
"@
    $raw = @($python) | py -3 - $Url
    if ($LASTEXITCODE -ne 0) {
        throw "Hosted GET probe failed: $Url"
    }
    return ($raw | Out-String | ConvertFrom-Json)
}

function Invoke-Ssh([string]$Command) {
    $normalizedCommand = $Command -replace "`r`n", "`n"
    $normalizedCommand = $normalizedCommand -replace "`r", "`n"
    ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingIp" $normalizedCommand
    if ($LASTEXITCODE -ne 0) {
        throw "SSH command failed: $Command"
    }
}

function Invoke-Scp([string]$Source, [string]$Destination) {
    scp -i $KeyPath -o StrictHostKeyChecking=no $Source "${RemoteUser}@${StagingIp}:$Destination"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP failed: $Source -> $Destination"
    }
}

function Invoke-ScpRecursive([string]$Source, [string]$Destination) {
    scp -r -i $KeyPath -o StrictHostKeyChecking=no $Source "${RemoteUser}@${StagingIp}:$Destination"
    if ($LASTEXITCODE -ne 0) {
        throw "Recursive SCP failed: $Source -> $Destination"
    }
}

function Restore-RemoteDeployment([string]$EnvBackupName, [string]$ComposeBackupName, [string]$Services) {
    Write-Warning "Staging deploy failed; restoring previous remote selector files."
    Invoke-Ssh "cd $RemoteAppDir && if [ -f $EnvBackupName ]; then cp $EnvBackupName .env; fi && if [ -f $ComposeBackupName ]; then cp $ComposeBackupName docker-compose.cloud.yml; fi && docker compose --env-file .env -f docker-compose.cloud.yml up -d --force-recreate --remove-orphans $Services"
}

if ([string]::IsNullOrWhiteSpace($StagingBaseUrl)) {
    $StagingBaseUrl = [Environment]::GetEnvironmentVariable("STAGING_BASE_URL")
}

if ([string]::IsNullOrWhiteSpace($StagingHostname)) {
    $StagingHostname = [Environment]::GetEnvironmentVariable("STAGING_HOSTNAME")
}

if ([string]::IsNullOrWhiteSpace($KeyPath)) {
    $KeyPath = [Environment]::GetEnvironmentVariable("STAGING_SSH_KEY_PATH")
}

if ([string]::IsNullOrWhiteSpace($ImageTag)) {
    $ImageTag = [Environment]::GetEnvironmentVariable("IMAGE_TAG")
}

if ([string]::IsNullOrWhiteSpace($ImageTag)) {
    $ImageTag = "staging"
}

if ([string]::IsNullOrWhiteSpace($StagingHostname)) {
    $StagingHostname = Get-DefaultHostname $StagingIp
}

if ([string]::IsNullOrWhiteSpace($StagingBaseUrl)) {
    $StagingBaseUrl = "https://$StagingHostname"
}

if ($RequireHttps) {
    Assert-HttpsUrl "STAGING_BASE_URL" $StagingBaseUrl
}
Assert-RemotePath "REMOTE_APP_DIR" $RemoteAppDir
Assert-RemoteUser "REMOTE_USER" $RemoteUser
Assert-RemoteHost "STAGING_IP" $StagingIp
Assert-RemoteValue "STAGING_HOSTNAME" $StagingHostname
Assert-RemoteValue "STAGING_BASE_URL" $StagingBaseUrl
Assert-DockerTag "IMAGE_TAG" $ImageTag
Assert-GitRef "SOURCE_REF" $SourceRef
$imageTagIsImmutableSha = $ImageTag -match '^[0-9a-f]{40}$'
if ($FrontendSourceBuild -and $UseImageFilesystem) {
    throw "Frontend source builds are staging-only and cannot be combined with -UseImageFilesystem."
}
if ($FrontendSourceBuild -and $imageTagIsImmutableSha) {
    throw "Frontend source builds are staging-only and cannot use immutable SHA image tags."
}
if ($imageTagIsImmutableSha -and -not $UseImageFilesystem -and $SourceRef -ne $ImageTag) {
    throw "Immutable image tag deploys must use -UseImageFilesystem or matching -SourceRef $ImageTag to avoid mixing candidate images with mutable hot-mounted source."
}
if ($imageTagIsImmutableSha -and -not [string]::IsNullOrWhiteSpace($SourceRef) -and $SourceRef -ne $ImageTag) {
    throw "Immutable image tag deploys must use an empty SourceRef for the current infra overlay or a SourceRef matching $ImageTag."
}

try {
if (-not [string]::IsNullOrWhiteSpace($SourceRef)) {
    $DeploySourceRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("superbrain-deploy-source-" + [Guid]::NewGuid().ToString("N"))
    $archivePath = Join-Path ([System.IO.Path]::GetTempPath()) ("superbrain-deploy-source-" + [Guid]::NewGuid().ToString("N") + ".tar")
    Register-TemporaryPath $DeploySourceRoot
    Register-TemporaryPath $archivePath
    New-Item -ItemType Directory -Path $DeploySourceRoot -Force | Out-Null
    Write-Host "--- Preparing deployment source ref $SourceRef ---"
    & git archive --format=tar -o $archivePath $SourceRef
    if ($LASTEXITCODE -ne 0) {
        throw "git archive failed for source ref: $SourceRef"
    }
    & tar -xf $archivePath -C $DeploySourceRoot
    if ($LASTEXITCODE -ne 0) {
        throw "tar extraction failed for source ref: $SourceRef"
    }
}

$composeSourcePath = Assert-SourceFile "docker-compose.cloud.yml"
$composeText = Get-Content -LiteralPath $composeSourcePath -Raw
$composeDeployPath = $composeSourcePath
$frontendSourceComposePath = $null
$hotMountPattern = '(?m)^[ \t]+- \./services/(agent-api|agent-worker|memory-worker|mcp-gateway|llm-gateway)/app:/app/app:ro\r?\n'
$hotMountCount = [regex]::Matches($composeText, $hotMountPattern).Count
$hasCaddyService = $composeText -match '(?m)^  caddy:'
$hasRosterMount = $composeText.Contains("autonomous-agent-roster.json")

if ($RequireHttps -and -not $hasCaddyService) {
    throw "Selected docker-compose.cloud.yml has no caddy service; HTTPS staging deploy requires caddy. Use the current compose source or pass -RequireHttps:`$false only for an explicit HTTP-only staging test."
}

if ($UseImageFilesystem) {
    $composeImageFilesystemText = $composeText -replace $hotMountPattern, ''
    $composeImageFilesystemText = [regex]::Replace($composeImageFilesystemText, '(?m)^    volumes:\r?\n(?=    [A-Za-z_-]+:)', '')
    if ([regex]::Matches($composeImageFilesystemText, $hotMountPattern).Count -ne 0) {
        throw "Failed to remove service hot-mount entries from image-filesystem compose."
    }
    $composeDeployPath = Join-Path ([System.IO.Path]::GetTempPath()) ("superbrain-deploy-source-" + [Guid]::NewGuid().ToString("N") + "-docker-compose.cloud.yml")
    Register-TemporaryPath $composeDeployPath
    Set-Content -LiteralPath $composeDeployPath -Value $composeImageFilesystemText -Encoding UTF8
}

if ($FrontendSourceBuild) {
    $frontendSourceComposePath = Join-Path ([System.IO.Path]::GetTempPath()) ("superbrain-deploy-source-" + [Guid]::NewGuid().ToString("N") + "-docker-compose.frontend-source.yml")
    Register-TemporaryPath $frontendSourceComposePath
    @"
services:
  frontend:
    build:
      context: ./apps/frontend
      dockerfile: Dockerfile
      target: runner
    image: cloud-superbrain-frontend:source-staging
    pull_policy: never
"@ | Set-Content -LiteralPath $frontendSourceComposePath -Encoding UTF8
}

$deployServices = @("frontend", "agent-api", "agent-worker", "memory-worker", "mcp-gateway", "llm-gateway", "nginx")
if ($hasCaddyService) {
    $deployServices += "caddy"
}
$deployServiceArgs = $deployServices -join " "
$composeCommandFiles = "-f docker-compose.cloud.yml"
if ($FrontendSourceBuild) {
    $composeCommandFiles = "-f docker-compose.cloud.yml -f docker-compose.frontend-source.yml"
}
$pullServices = $deployServices
if ($FrontendSourceBuild) {
    $pullServices = @($deployServices | Where-Object { $_ -ne "frontend" })
}
$pullServiceArgs = $pullServices -join " "

if ($PlanOnly) {
    Write-Host "--- Staging deployment plan only ---"
    Write-Host "Hosted base URL: $StagingBaseUrl"
    Write-Host "Hosted hostname: $StagingHostname"
    Write-Host "Image tag: $ImageTag"
    Write-Host "Source ref: $SourceRef"
    Write-Host "Use image filesystem: $UseImageFilesystem"
    Write-Host "Build frontend on remote: $FrontendSourceBuild"
    if ($FrontendSourceBuild) {
        Write-Host "Frontend source build override: docker-compose.frontend-source.yml"
        Write-Host "Frontend source build image: cloud-superbrain-frontend:source-staging"
    }
    Write-Host "Service hot-mount entries in source compose: $hotMountCount"
    Write-Host "Compose has caddy: $hasCaddyService"
    Write-Host "Compose has roster mount: $hasRosterMount"
    Write-Host "Deploy services: $deployServiceArgs"
    Write-Host "Pull services: $pullServiceArgs"
    Assert-SourceFile "infrastructure/nginx/cloud.conf" | Out-Null
    Assert-SourceFile "docs/project-progress.manifest.json" | Out-Null
    Assert-SourceFile "PROJECT_STATE.md" | Out-Null
    if ($hasCaddyService) {
        Assert-SourceFile "infrastructure/caddy/Caddyfile" | Out-Null
    }
    if ($hasRosterMount) {
        Assert-SourceFile "docs/codex-integration/autonomous-agent-roster.json" | Out-Null
    }
    if (-not $UseImageFilesystem) {
        foreach ($path in @(
            "services/agent-api/app",
            "services/agent-worker/app",
            "services/memory-worker/app",
            "services/mcp-gateway/app",
            "services/llm-gateway/app"
        )) {
            if (-not (Test-Path -LiteralPath (Get-SourcePath $path) -PathType Container)) {
                throw "Required hot-mount source directory missing: $path"
            }
        }
    }
    if ($FrontendSourceBuild) {
        foreach ($path in @(
            "apps/frontend/Dockerfile",
            "apps/frontend/package.json",
            "apps/frontend/package-lock.json",
            "apps/frontend/next.config.mjs",
            "apps/frontend/tsconfig.json",
            "apps/frontend/next-env.d.ts",
            "apps/frontend/.dockerignore"
        )) {
            Assert-SourceFile $path | Out-Null
        }
        Assert-SourceDirectory "apps/frontend/app" | Out-Null
    }
    return
}

if ([string]::IsNullOrWhiteSpace($KeyPath)) {
    throw "Staging SSH key path must be provided via -KeyPath or STAGING_SSH_KEY_PATH"
}

Write-Host "--- Preparing remote directories ---"
Invoke-Ssh "mkdir -p $RemoteAppDir/apps $RemoteAppDir/infrastructure/nginx $RemoteAppDir/infrastructure/caddy $RemoteAppDir/infrastructure/postgres/init $RemoteAppDir/progress $RemoteAppDir/docs/codex-integration $RemoteAppDir/services/agent-api $RemoteAppDir/services/agent-worker $RemoteAppDir/services/memory-worker $RemoteAppDir/services/mcp-gateway $RemoteAppDir/services/llm-gateway"

if (-not $UseImageFilesystem) {
    Write-Host "--- Resetting remote hot-mount source directories ---"
    Invoke-Ssh "rm -rf $RemoteAppDir/services/agent-api/app $RemoteAppDir/services/agent-worker/app $RemoteAppDir/services/memory-worker/app $RemoteAppDir/services/mcp-gateway/app $RemoteAppDir/services/llm-gateway/app && mkdir -p $RemoteAppDir/services/agent-api $RemoteAppDir/services/agent-worker $RemoteAppDir/services/memory-worker $RemoteAppDir/services/mcp-gateway $RemoteAppDir/services/llm-gateway"
} else {
    Write-Host "--- Using service code from immutable container images ---"
}

if ($FrontendSourceBuild) {
    Write-Host "--- Resetting remote frontend source directory ---"
    Invoke-Ssh "rm -rf $RemoteAppDir/apps/frontend && mkdir -p $RemoteAppDir/apps/frontend"
}

$remoteBackupSuffix = [DateTime]::UtcNow.ToString("yyyyMMddHHmmss")
$remoteEnvBackupName = ".env.bak.codex-$remoteBackupSuffix"
$remoteComposeBackupName = "docker-compose.cloud.yml.bak.codex-$remoteBackupSuffix"
Write-Host "--- Backing up remote deployment selector files ---"
Invoke-Ssh "cd $RemoteAppDir && test -f .env && cp .env $remoteEnvBackupName && if [ -f docker-compose.cloud.yml ]; then cp docker-compose.cloud.yml $remoteComposeBackupName; fi"
$remoteBackupCreated = $true

try {
Write-Host "--- Copying non-secret deployment files ---"
Invoke-Scp $composeDeployPath "$RemoteAppDir/docker-compose.cloud.yml"
if ($FrontendSourceBuild) {
    Invoke-Scp $frontendSourceComposePath "$RemoteAppDir/docker-compose.frontend-source.yml"
}
Invoke-Scp (Get-SourcePath "infrastructure/nginx/cloud.conf") "$RemoteAppDir/infrastructure/nginx/cloud.conf"
if ($hasCaddyService) {
    Invoke-Scp (Get-SourcePath "infrastructure/caddy/Caddyfile") "$RemoteAppDir/infrastructure/caddy/Caddyfile"
}
Invoke-Scp (Get-SourcePath "docs/project-progress.manifest.json") "$RemoteAppDir/progress/project-progress.manifest.json"
Invoke-Scp (Get-SourcePath "docs/project-progress.manifest.json") "$RemoteAppDir/docs/project-progress.manifest.json"
if ($hasRosterMount) {
    Invoke-Scp (Get-SourcePath "docs/codex-integration/autonomous-agent-roster.json") "$RemoteAppDir/docs/codex-integration/autonomous-agent-roster.json"
}
Invoke-Scp (Get-SourcePath "PROJECT_STATE.md") "$RemoteAppDir/PROJECT_STATE.md"
if (-not $UseImageFilesystem) {
    Invoke-ScpRecursive (Get-SourcePath "services/agent-api/app") "$RemoteAppDir/services/agent-api/"
    Invoke-ScpRecursive (Get-SourcePath "services/agent-worker/app") "$RemoteAppDir/services/agent-worker/"
    Invoke-ScpRecursive (Get-SourcePath "services/memory-worker/app") "$RemoteAppDir/services/memory-worker/"
    Invoke-ScpRecursive (Get-SourcePath "services/mcp-gateway/app") "$RemoteAppDir/services/mcp-gateway/"
    Invoke-ScpRecursive (Get-SourcePath "services/llm-gateway/app") "$RemoteAppDir/services/llm-gateway/"
}
if ($FrontendSourceBuild) {
    foreach ($relativePath in @(
        "apps/frontend/Dockerfile",
        "apps/frontend/package.json",
        "apps/frontend/package-lock.json",
        "apps/frontend/next.config.mjs",
        "apps/frontend/tsconfig.json",
        "apps/frontend/next-env.d.ts",
        "apps/frontend/.dockerignore"
    )) {
        Invoke-Scp (Get-SourcePath $relativePath) "$RemoteAppDir/apps/frontend/$(Split-Path -Leaf $relativePath)"
    }
    Invoke-ScpRecursive (Get-SourcePath "apps/frontend/app") "$RemoteAppDir/apps/frontend/"
    if (Test-Path -LiteralPath (Get-SourcePath "apps/frontend/public") -PathType Container) {
        Invoke-ScpRecursive (Get-SourcePath "apps/frontend/public") "$RemoteAppDir/apps/frontend/"
    }
}

Write-Host "--- Verifying remote secret file exists ---"
Invoke-Ssh "test -f $RemoteAppDir/.env"

Write-Host "--- Updating remote non-secret staging variables ---"
$remoteUpdate = @"
set -e
cd $RemoteAppDir
grep -vE '^(STAGING_HOSTNAME|STAGING_BASE_URL|AGENT_API_BASE_URL|MCP_GATEWAY_BASE_URL|LLM_GATEWAY_BASE_URL|IMAGE_TAG)=' .env > .env.tmp
printf 'STAGING_HOSTNAME=%s\n' '$StagingHostname' >> .env.tmp
printf 'STAGING_BASE_URL=%s\n' '$StagingBaseUrl' >> .env.tmp
printf 'AGENT_API_BASE_URL=%s\n' '$StagingBaseUrl' >> .env.tmp
printf 'MCP_GATEWAY_BASE_URL=%s/mcp\n' '$StagingBaseUrl' >> .env.tmp
printf 'LLM_GATEWAY_BASE_URL=%s/llm\n' '$StagingBaseUrl' >> .env.tmp
printf 'IMAGE_TAG=%s\n' '$ImageTag' >> .env.tmp
mv .env.tmp .env
"@
Invoke-Ssh $remoteUpdate

Write-Host "--- Deploying staging stack ---"
Invoke-Ssh "cd $RemoteAppDir && docker compose --env-file .env -f docker-compose.cloud.yml pull $pullServiceArgs && docker compose --env-file .env $composeCommandFiles up -d --build --force-recreate --remove-orphans $deployServiceArgs"

Write-Host "--- Remote health probes ---"
Invoke-Ssh "cd $RemoteAppDir && docker compose --env-file .env $composeCommandFiles ps"

$ProgressPreference = "SilentlyContinue"
$rootResponse = Invoke-HostedGet $StagingBaseUrl
if ($rootResponse.status -ne 200) {
    throw "Hosted root probe failed: $($rootResponse.status)"
}

$healthResponse = Invoke-HostedGet "$StagingBaseUrl/api/v1/health"
if ($healthResponse.status -ne 200) {
    throw "Hosted agent API health probe failed: $($healthResponse.status)"
}
} catch {
    if ($remoteBackupCreated) {
        Restore-RemoteDeployment $remoteEnvBackupName $remoteComposeBackupName $deployServiceArgs
    }
    throw
}

Write-Host "--- Deployment complete ---"
Write-Host "Hosted root: $StagingBaseUrl"
Write-Host "Hosted API health: $StagingBaseUrl/api/v1/health"
Write-Host "Hosted image tag: $ImageTag"
if (-not [string]::IsNullOrWhiteSpace($SourceRef)) {
    Write-Host "Hosted source ref: $SourceRef"
}
Write-Host "Hosted image filesystem: $UseImageFilesystem"
Write-Host "Hosted frontend source build: $FrontendSourceBuild"
} finally {
    Remove-TemporaryPaths
}

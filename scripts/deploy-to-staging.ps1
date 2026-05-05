param(
    [string]$StagingIp = "188.34.191.140",
    [string]$KeyPath = "",
    [string]$RemoteAppDir = "/app",
    [string]$RemoteUser = "root",
    [string]$StagingBaseUrl = "",
    [string]$StagingHostname = "",
    [switch]$RequireHttps = $true
)

$ErrorActionPreference = "Stop"

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
    ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingIp" $Command
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

if ([string]::IsNullOrWhiteSpace($StagingBaseUrl)) {
    $StagingBaseUrl = [Environment]::GetEnvironmentVariable("STAGING_BASE_URL")
}

if ([string]::IsNullOrWhiteSpace($StagingHostname)) {
    $StagingHostname = [Environment]::GetEnvironmentVariable("STAGING_HOSTNAME")
}

if ([string]::IsNullOrWhiteSpace($KeyPath)) {
    $KeyPath = [Environment]::GetEnvironmentVariable("STAGING_SSH_KEY_PATH")
}

if ([string]::IsNullOrWhiteSpace($KeyPath)) {
    throw "Staging SSH key path must be provided via -KeyPath or STAGING_SSH_KEY_PATH"
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

Write-Host "--- Preparing remote directories ---"
Invoke-Ssh "mkdir -p $RemoteAppDir/infrastructure/nginx $RemoteAppDir/infrastructure/caddy $RemoteAppDir/infrastructure/postgres/init $RemoteAppDir/progress $RemoteAppDir/docs $RemoteAppDir/services/agent-api $RemoteAppDir/services/agent-worker $RemoteAppDir/services/memory-worker $RemoteAppDir/services/mcp-gateway $RemoteAppDir/services/llm-gateway"

Write-Host "--- Copying non-secret deployment files ---"
Invoke-Scp "docker-compose.cloud.yml" "$RemoteAppDir/docker-compose.cloud.yml"
Invoke-Scp "infrastructure/nginx/cloud.conf" "$RemoteAppDir/infrastructure/nginx/cloud.conf"
Invoke-Scp "infrastructure/caddy/Caddyfile" "$RemoteAppDir/infrastructure/caddy/Caddyfile"
Invoke-Scp "docs/project-progress.manifest.json" "$RemoteAppDir/progress/project-progress.manifest.json"
Invoke-Scp "PROJECT_STATE.md" "$RemoteAppDir/PROJECT_STATE.md"
Invoke-ScpRecursive "services/agent-api/app" "$RemoteAppDir/services/agent-api/"
Invoke-ScpRecursive "services/agent-worker/app" "$RemoteAppDir/services/agent-worker/"
Invoke-ScpRecursive "services/memory-worker/app" "$RemoteAppDir/services/memory-worker/"
Invoke-ScpRecursive "services/mcp-gateway/app" "$RemoteAppDir/services/mcp-gateway/"
Invoke-ScpRecursive "services/llm-gateway/app" "$RemoteAppDir/services/llm-gateway/"

Write-Host "--- Verifying remote secret file exists ---"
Invoke-Ssh "test -f $RemoteAppDir/.env"

Write-Host "--- Updating remote non-secret staging variables ---"
$remoteUpdate = @"
set -e
cd $RemoteAppDir
cp .env .env.bak
grep -vE '^(STAGING_HOSTNAME|STAGING_BASE_URL|AGENT_API_BASE_URL|MCP_GATEWAY_BASE_URL|LLM_GATEWAY_BASE_URL|IMAGE_TAG)=' .env > .env.tmp
printf 'STAGING_HOSTNAME=%s\n' '$StagingHostname' >> .env.tmp
printf 'STAGING_BASE_URL=%s\n' '$StagingBaseUrl' >> .env.tmp
printf 'AGENT_API_BASE_URL=%s/api\n' '$StagingBaseUrl' >> .env.tmp
printf 'MCP_GATEWAY_BASE_URL=%s/mcp\n' '$StagingBaseUrl' >> .env.tmp
printf 'LLM_GATEWAY_BASE_URL=%s/llm\n' '$StagingBaseUrl' >> .env.tmp
printf 'IMAGE_TAG=%s\n' 'staging' >> .env.tmp
mv .env.tmp .env
"@
Invoke-Ssh $remoteUpdate

Write-Host "--- Deploying staging stack ---"
Invoke-Ssh "cd $RemoteAppDir && docker compose --env-file .env -f docker-compose.cloud.yml pull && docker compose --env-file .env -f docker-compose.cloud.yml up -d"

Write-Host "--- Remote health probes ---"
Invoke-Ssh "cd $RemoteAppDir && docker compose --env-file .env -f docker-compose.cloud.yml ps"

$ProgressPreference = "SilentlyContinue"
$rootResponse = Invoke-HostedGet $StagingBaseUrl
if ($rootResponse.status -ne 200) {
    throw "Hosted root probe failed: $($rootResponse.status)"
}

$healthResponse = Invoke-HostedGet "$StagingBaseUrl/api/v1/health"
if ($healthResponse.status -ne 200) {
    throw "Hosted agent API health probe failed: $($healthResponse.status)"
}

Write-Host "--- Deployment complete ---"
Write-Host "Hosted root: $StagingBaseUrl"
Write-Host "Hosted API health: $StagingBaseUrl/api/v1/health"

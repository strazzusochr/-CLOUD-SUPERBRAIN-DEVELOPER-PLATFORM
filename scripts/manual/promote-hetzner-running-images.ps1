param(
  [string]$StagingIp = "188.34.191.140",
  [string]$RemoteUser = "root",
  [string]$RemoteAppDir = "/app",
  [string]$KeyPath = "",
  [string]$Namespace = "ghcr.io/strazzusochr/cloud-superbrain-developer-platform",
  [string]$SourceTag = "deploy-20260511-182742-hfrouter",
  [string]$FrontendSourceTag = "frontend-agentfix-20260511",
  [string]$TargetTag = ("deploy-" + (Get-Date -Format "yyyyMMdd-HHmmss") + "-agentfix"),
  [string]$GhcrUser = "strazzusochr",
  [switch]$Push,
  [switch]$PlanOnly
)

$ErrorActionPreference = "Stop"

function Assert-Tag([string]$Name, [string]$Tag) {
  if ([string]::IsNullOrWhiteSpace($Tag) -or $Tag.Length -gt 128 -or $Tag -notmatch '^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$') {
    throw "Invalid ${Name}: $Tag"
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

function Quote-NativeArgument([string]$Value) {
  return '"' + ($Value -replace '\\', '\\' -replace '"', '\"') + '"'
}

function Invoke-RemoteDockerLogin([string]$Token) {
  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = "ssh"
  $sshTarget = "$RemoteUser@$StagingIp"
  $remoteCommand = "docker login ghcr.io -u $GhcrUser --password-stdin"
  $psi.Arguments = @(
    "-i", (Quote-NativeArgument $KeyPath),
    "-o", "StrictHostKeyChecking=no",
    (Quote-NativeArgument $sshTarget),
    (Quote-NativeArgument $remoteCommand)
  ) -join " "
  $psi.RedirectStandardInput = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true

  $process = [System.Diagnostics.Process]::Start($psi)
  $process.StandardInput.WriteLine($Token)
  $process.StandardInput.Close()
  $stdout = $process.StandardOutput.ReadToEnd()
  $stderr = $process.StandardError.ReadToEnd()
  $process.WaitForExit()
  if (-not [string]::IsNullOrWhiteSpace($stdout)) {
    Write-Host $stdout.Trim()
  }
  if (-not [string]::IsNullOrWhiteSpace($stderr)) {
    Write-Host $stderr.Trim()
  }
  if ($process.ExitCode -ne 0) {
    throw "Remote GHCR login failed."
  }
}

if ([string]::IsNullOrWhiteSpace($KeyPath)) {
  $KeyPath = [Environment]::GetEnvironmentVariable("STAGING_SSH_KEY_PATH")
}
if ([string]::IsNullOrWhiteSpace($KeyPath)) {
  throw "KeyPath or STAGING_SSH_KEY_PATH is required."
}

Assert-RemoteValue "StagingIp" $StagingIp
Assert-RemoteValue "RemoteUser" $RemoteUser
Assert-RemoteValue "RemoteAppDir" $RemoteAppDir
Assert-RemoteValue "Namespace" $Namespace
Assert-RemoteValue "GhcrUser" $GhcrUser
Assert-Tag "SourceTag" $SourceTag
Assert-Tag "FrontendSourceTag" $FrontendSourceTag
Assert-Tag "TargetTag" $TargetTag

$services = @("agent-api", "agent-worker", "memory-worker", "llm-gateway", "mcp-gateway", "frontend")
$mappings = foreach ($service in $services) {
  $source = if ($service -eq "frontend") {
    "$Namespace/${service}:$FrontendSourceTag"
  } else {
    "$Namespace/${service}:$SourceTag"
  }
  [pscustomobject]@{
    service = $service
    source = $source
    target = "$Namespace/${service}:$TargetTag"
  }
}

Write-Host "[plan] host=$StagingIp"
Write-Host "[plan] source_tag=$SourceTag"
Write-Host "[plan] frontend_source_tag=$FrontendSourceTag"
Write-Host "[plan] target_tag=$TargetTag"
foreach ($mapping in $mappings) {
  Write-Host ("[plan] {0}: {1} -> {2}" -f $mapping.service, $mapping.source, $mapping.target)
}
if ($PlanOnly) {
  return
}

$arch = (& ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$StagingIp" "uname -m") | Out-String
if ($LASTEXITCODE -ne 0 -or $arch.Trim() -notin @("aarch64", "arm64")) {
  throw "Remote host is not ARM64: $($arch.Trim())"
}

Invoke-Ssh "docker info --format '{{.ServerVersion}}'"
Invoke-Ssh "cd $RemoteAppDir && test -f .env && test -f docker-compose.cloud.yml"

foreach ($mapping in $mappings) {
  Invoke-Ssh "docker image inspect $($mapping.source) >/dev/null"
  Invoke-Ssh "docker tag $($mapping.source) $($mapping.target)"
}

if ($Push) {
  $token = [Environment]::GetEnvironmentVariable("GHCR_TOKEN", "Process")
  if ([string]::IsNullOrWhiteSpace($token)) {
    $token = [Environment]::GetEnvironmentVariable("GITHUB_TOKEN", "Process")
  }
  if ([string]::IsNullOrWhiteSpace($token)) {
    throw "GHCR_TOKEN or GITHUB_TOKEN is required for -Push."
  }

  Invoke-RemoteDockerLogin -Token $token

  foreach ($mapping in $mappings) {
    Invoke-Ssh "docker push $($mapping.target)"
  }
}

Write-Host "[done] target_tag=$TargetTag"
if (-not $Push) {
  Write-Host "[done] local_remote_tags_created=true"
  Write-Host "[next] rerun with -Push before deploy-to-staging can pull this tag from GHCR"
}

[CmdletBinding()]
param(
  [string]$RepoRoot = '',
  [string]$DockerExecutable = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "O4 effective Compose verification failed: $Message" }
}

$root = if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
} else {
  [IO.Path]::GetFullPath($RepoRoot)
}
Assert-True (Test-Path -LiteralPath $root -PathType Container) 'repository root is missing'
$rootPrefix = $root.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar

$dockerPath = if ([string]::IsNullOrWhiteSpace($DockerExecutable)) {
  $command = Get-Command docker -CommandType Application -ErrorAction Stop | Select-Object -First 1
  [IO.Path]::GetFullPath($command.Source)
} else {
  [IO.Path]::GetFullPath($DockerExecutable)
}
Assert-True (Test-Path -LiteralPath $dockerPath -PathType Leaf) 'Docker application is missing'
Assert-True (-not $dockerPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) 'repository-local Docker shadow executable is forbidden'

$composePath = [IO.Path]::GetFullPath((Join-Path $root 'docker-compose.dev.yml'))
Assert-True $composePath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase) 'Compose path escapes the repository'
Assert-True (Test-Path -LiteralPath $composePath -PathType Leaf) 'canonical Compose file is missing'

$rendered = @(& $dockerPath compose --project-directory $root --file $composePath config --format json 2>$null)
Assert-True ($LASTEXITCODE -eq 0) 'docker compose config did not exit zero'
try {
  $config = (($rendered | ForEach-Object { [string]$_ }) -join "`n") | ConvertFrom-Json
} catch {
  throw 'O4 effective Compose verification failed: rendered configuration is not JSON'
}
Assert-True ($null -ne $config.services) 'rendered services are missing'

function Get-Service([string]$Name) {
  $property = $config.services.PSObject.Properties[$Name]
  Assert-True ($null -ne $property) "service is missing: $Name"
  return $property.Value
}

function Assert-EffectiveBind(
  [string]$ServiceName,
  [string]$Target,
  [string]$ExpectedRelativeSource,
  [bool]$ExpectedReadOnly
) {
  $service = Get-Service $ServiceName
  $matches = @($service.volumes | Where-Object { [string]$_.target -ceq $Target })
  Assert-True ($matches.Count -eq 1) "effective bind target is missing or duplicated: $ServiceName $Target"
  $mount = $matches[0]
  Assert-True ([string]$mount.type -ceq 'bind') "effective mount is not a bind: $ServiceName $Target"
  $expected = [IO.Path]::GetFullPath((Join-Path $root $ExpectedRelativeSource))
  $actual = [IO.Path]::GetFullPath([string]$mount.source)
  Assert-True ($actual -ceq $expected) "effective bind source drift: $ServiceName $Target"
  $readOnlyProperty = $mount.PSObject.Properties['read_only']
  $actualReadOnly = $null -ne $readOnlyProperty -and [bool]$readOnlyProperty.Value
  Assert-True ($actualReadOnly -eq $ExpectedReadOnly) "effective bind mode drift: $ServiceName $Target"
}

Assert-EffectiveBind 'mcp-gateway' '/tmp/agent-workspace' '.phase1-artifacts/o4-live-write-workspace' $false
Assert-EffectiveBind 'mcp-gateway' '/app/progress/owner-input-manifest.json' 'docs/runtime-state/owner-input-manifest.json' $true
Assert-EffectiveBind 'mcp-gateway' '/app/o4-git/HEAD' '.git/HEAD' $true
Assert-EffectiveBind 'mcp-gateway' '/app/app' 'services/mcp-gateway/app' $true
Assert-EffectiveBind 'agent-api' '/app/progress/owner-input-manifest.json' 'docs/runtime-state/owner-input-manifest.json' $true
Assert-EffectiveBind 'agent-api' '/app/progress/capability-gates.json' 'docs/runtime-state/capability-gates.json' $true
Assert-EffectiveBind 'agent-api' '/app/o4-git/HEAD' '.git/HEAD' $true
Assert-EffectiveBind 'agent-api' '/app/app' 'services/agent-api/app' $true

foreach ($serviceName in @('mcp-gateway', 'agent-api')) {
  $environment = (Get-Service $serviceName).environment
  Assert-True ($null -ne $environment) "effective environment is missing: $serviceName"
  Assert-True ([string]$environment.O4_LIVE_WRITE_PROBE_ENABLED -ceq 'true') "O4 probe flag drift: $serviceName"
}
Assert-True ([string](Get-Service 'mcp-gateway').environment.O4_LIVE_WRITE_NEGATIVE_TEST_ENABLED -ceq 'true') 'O4 negative-test flag drift'

Write-Host '[o4-effective-compose] PASS canonical_file=true effective_mounts=8 shadow_docker=false secret_output=false'

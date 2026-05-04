param(
  [string]$ProjectName = "cloud-superbrain-phase1-dev",
  [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Fail($Message) {
  throw "Resource measurement failed: $Message"
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Fail "docker CLI is not available"
}

$containerIds = @(docker ps --filter "label=com.docker.compose.project=$ProjectName" --format "{{.ID}}")
if (-not $containerIds -or $containerIds.Count -eq 0) {
  Fail "no running containers found for compose project '$ProjectName'"
}

$statsLines = @(docker stats --no-stream --format "{{json .}}" @containerIds)
$measurements = @()

foreach ($line in $statsLines) {
  if ([string]::IsNullOrWhiteSpace($line)) {
    continue
  }

  $stat = $line | ConvertFrom-Json
  $inspect = docker inspect $stat.ID | ConvertFrom-Json
  if (-not $inspect -or $inspect.Count -eq 0) {
    Fail "docker inspect returned no data for $($stat.ID)"
  }

  $service = $inspect[0].Config.Labels."com.docker.compose.service"
  $memoryLimitBytes = [int64]$inspect[0].HostConfig.Memory
  $nanoCpus = [int64]$inspect[0].HostConfig.NanoCpus
  $cpuLimit = if ($nanoCpus -gt 0) { [math]::Round($nanoCpus / 1000000000, 2) } else { 0 }

  $measurements += [pscustomobject]@{
    service = $service
    container_id = $stat.ID
    name = $stat.Name
    cpu_percent = $stat.CPUPerc
    memory_usage = $stat.MemUsage
    memory_percent = $stat.MemPerc
    memory_limit_bytes = $memoryLimitBytes
    cpu_limit = $cpuLimit
    network_io = $stat.NetIO
    block_io = $stat.BlockIO
  }
}

$ordered = @($measurements | Sort-Object service)
$payload = [pscustomobject]@{
  project = $ProjectName
  measured_at = (Get-Date).ToUniversalTime().ToString("o")
  container_count = $ordered.Count
  upgrade_rule = "No Hetzner upgrade without empirical CPU/RAM pressure and infra-budget proof."
  measurements = $ordered
}

if ($JsonOnly) {
  $payload | ConvertTo-Json -Depth 6 -Compress
} else {
  $payload | ConvertTo-Json -Depth 6
}

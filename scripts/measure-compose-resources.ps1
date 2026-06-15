param(
  [string]$ProjectName = "cloud-superbrain-phase1-dev",
  [switch]$JsonOnly,
  [switch]$Verify
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Fail "docker CLI is not available"
}
try {
  $serverVersion = (docker info --format "{{.ServerVersion}}" 2>&1 | Out-String).Trim()
  if ([string]::IsNullOrWhiteSpace($serverVersion)) {
    Fail "docker engine readiness probe returned an empty server version"
  }
} catch {
  Fail "docker engine is not ready for compose resource measurement"
}

function Fail($Message) {
  throw "Resource measurement failed: $Message"
}

$prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
$containerIds = @(docker ps --filter "label=com.docker.compose.project=$ProjectName" --format "{{.ID}}" 2>$null)
$ErrorActionPreference = $prevEap
if (-not $containerIds -or $containerIds.Count -eq 0) {
  Fail "no running containers found for compose project '$ProjectName'"
}

$measurements = @()

foreach ($containerId in $containerIds) {
  $prevEap2 = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  $inspect = docker inspect $containerId 2>$null | ConvertFrom-Json
  $ErrorActionPreference = $prevEap2
  if (-not $inspect -or $inspect.Count -eq 0) {
    Fail "docker inspect returned no data for $containerId"
  }

  $service = $inspect[0].Config.Labels."com.docker.compose.service"
  $memoryLimitBytes = [int64]$inspect[0].HostConfig.Memory
  $nanoCpus = [int64]$inspect[0].HostConfig.NanoCpus
  $cpuLimit = if ($nanoCpus -gt 0) { [math]::Round($nanoCpus / 1000000000, 2) } else { 0 }

  $measurements += [pscustomobject]@{
    service = $service
    container_id = $containerId
    name = [string]$inspect[0].Name
    cpu_percent = $null
    memory_usage = $null
    memory_percent = $null
    memory_limit_bytes = $memoryLimitBytes
    cpu_limit = $cpuLimit
    network_io = $null
    block_io = $null
  }
}

$ordered = @($measurements | Sort-Object service)
$payload = [pscustomobject]@{
  project = $ProjectName
  measured_at = (Get-Date).ToUniversalTime().ToString("o")
  container_count = $ordered.Count
  upgrade_rule = "No Fly.io upgrade without empirical CPU/RAM pressure and infra-budget proof."
  measurements = $ordered
}

if ($Verify) {
  # Validate fields and print "OK <project> <count>" — avoids PS5.1 BOM-in-pipe limitation
  $json = $payload | ConvertTo-Json -Depth 6 -Compress
  $tmp = [System.IO.Path]::GetTempFileName()
  [System.IO.File]::WriteAllText($tmp, $json, [System.Text.UTF8Encoding]::new($false))
  try {
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $result = py -3 -c "import json; d=json.load(open(r'$tmp',encoding='utf-8')); print('OK', d['project'], d['container_count'])" 2>&1
    $pyExit = $LASTEXITCODE; $ErrorActionPreference = $prevEap
    if ($pyExit -ne 0) { throw "Verify failed: $result" }
    Write-Output $result
  } finally { Remove-Item $tmp -ErrorAction SilentlyContinue }
} elseif ($JsonOnly) {
  $json = $payload | ConvertTo-Json -Depth 6 -Compress
  $tmp = [System.IO.Path]::GetTempFileName()
  [System.IO.File]::WriteAllText($tmp, $json + "`n", [System.Text.UTF8Encoding]::new($false))
  try { cmd /c "type `"$tmp`"" } finally { Remove-Item $tmp -ErrorAction SilentlyContinue }
} else {
  $payload | ConvertTo-Json -Depth 6
}

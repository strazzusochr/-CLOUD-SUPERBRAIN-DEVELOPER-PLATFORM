param(
  [string]$Container = "cloud-superbrain-phase1-dev-redis-1",
  [string]$ComposeFile = "docker-compose.dev.yml",
  [string]$Service = "redis",
  [string]$Key = "",
  [string]$Value = "",
  [int]$TtlSeconds = 600
)

$ErrorActionPreference = "Stop"

function Assert-LastExitCode($label) {
  if ($LASTEXITCODE -ne 0) {
    throw "Redis persistence proof failed: $label"
  }
}

function Invoke-Redis([string[]]$arguments) {
  $output = docker exec $Container redis-cli @arguments 2>&1
  Assert-LastExitCode ("redis-cli " + ($arguments -join " "))
  return ($output | Out-String).Trim()
}

if ([string]::IsNullOrWhiteSpace($Key)) {
  $Key = "phase1:redis:persistence:" + [Guid]::NewGuid().ToString("N")
}
if ([string]::IsNullOrWhiteSpace($Value)) {
  $Value = "redis-aof-proof-" + [Guid]::NewGuid().ToString("N")
}

$containerId = docker ps --filter "name=^/$Container$" --format "{{.ID}}"
Assert-LastExitCode "inspect redis container"
if ([string]::IsNullOrWhiteSpace($containerId)) {
  throw "Redis persistence proof failed: container '$Container' is not running"
}

$aofConfig = Invoke-Redis @("CONFIG", "GET", "appendonly")
if (-not (($aofConfig | Out-String).Contains("yes"))) {
  throw "Redis persistence proof failed: appendonly is not enabled"
}

$setResult = Invoke-Redis @("SET", $Key, $Value, "EX", [string]$TtlSeconds)
if ($setResult -ne "OK") {
  throw "Redis persistence proof failed: SET did not return OK"
}

Invoke-Redis @("SAVE") | Out-Null

$env:NGINX_HTTP_PORT = if ($env:NGINX_HTTP_PORT) { $env:NGINX_HTTP_PORT } else { "8081" }
docker compose -f $ComposeFile up -d --force-recreate $Service | Out-Null
Assert-LastExitCode "force-recreate redis"

for ($i = 0; $i -lt 30; $i++) {
  try {
    $ping = Invoke-Redis @("PING")
    if ($ping -eq "PONG") {
      break
    }
  } catch {
    Start-Sleep -Seconds 1
  }
  if ($i -eq 29) {
    throw "Redis persistence proof failed: Redis did not become healthy after recreate"
  }
  Start-Sleep -Seconds 1
}

$restored = Invoke-Redis @("GET", $Key)
if ($restored -ne $Value) {
  throw "Redis persistence proof failed: persisted key value mismatch after recreate"
}

$ttlAfter = Invoke-Redis @("TTL", $Key)
if ([int]$ttlAfter -le 0) {
  throw "Redis persistence proof failed: key TTL missing after recreate"
}

Invoke-Redis @("DEL", $Key) | Out-Null

$manifest = [ordered]@{
  generated_at = (Get-Date).ToUniversalTime().ToString("o")
  container = $Container
  compose_file = $ComposeFile
  service = $Service
  key = $Key
  appendonly_enabled = $true
  forced_container_recreate = $true
  restored_value_matches = $true
  ttl_after_restart_seconds = [int]$ttlAfter
  cleanup_status = "key_deleted"
  no_secret_material = $true
}

Write-Output ($manifest | ConvertTo-Json -Depth 5 -Compress)

param(
  [string]$Container = "cloud-superbrain-phase1-dev-postgres-1",
  [string]$SourceDatabase = "superbrain_prod",
  [string]$DbUser = "superbrain",
  [string]$OutputDir = ".phase1-artifacts/postgres-backups",
  [string]$RestoreDatabase = "",
  [switch]$KeepDatabase
)

$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "require-docker-readiness.ps1") -GateName "phase1 PostgreSQL restore proof"

function Assert-LastExitCode($label) {
  if ($LASTEXITCODE -ne 0) {
    throw "PostgreSQL restore proof failed: $label"
  }
}

function Invoke-ContainerCommand($label, [string[]]$arguments) {
  $output = docker exec $Container @arguments 2>&1
  Assert-LastExitCode $label
  return ($output | Out-String).Trim()
}

function Assert-SafeDatabaseName([string]$name) {
  if ($name -notmatch '^[a-zA-Z_][a-zA-Z0-9_]*$') {
    throw "PostgreSQL restore proof failed: unsafe restore database name '$name'"
  }
}

$containerId = docker ps --filter "name=^/$Container$" --format "{{.ID}}"
Assert-LastExitCode "inspect postgres container"
if ([string]::IsNullOrWhiteSpace($containerId)) {
  throw "PostgreSQL restore proof failed: container '$Container' is not running"
}

if ([string]::IsNullOrWhiteSpace($RestoreDatabase)) {
  $RestoreDatabase = "superbrain_restore_probe_" + [Guid]::NewGuid().ToString("N")
}
Assert-SafeDatabaseName $RestoreDatabase

$backupJson = powershell -ExecutionPolicy Bypass -File scripts\backup-postgres-phase1.ps1 `
  -Container $Container `
  -Database $SourceDatabase `
  -DbUser $DbUser `
  -OutputDir $OutputDir
$backup = $backupJson | ConvertFrom-Json
if (-not $backup.schema_only) {
  throw "PostgreSQL restore proof failed: restore drill requires a schema-only backup"
}
if (-not (Test-Path $backup.dump_file)) {
  throw "PostgreSQL restore proof failed: dump file missing: $($backup.dump_file)"
}

$cleanupStatus = "not_started"
try {
  Invoke-ContainerCommand "create restore database" @(
    "psql", "-U", $DbUser, "-d", "postgres", "-v", "ON_ERROR_STOP=1", "-c",
    "CREATE DATABASE ""$RestoreDatabase"";"
  ) | Out-Null

  Get-Content -Path $backup.dump_file -Raw | docker exec -i $Container psql -U $DbUser -d $RestoreDatabase -v ON_ERROR_STOP=1 | Out-Null
  Assert-LastExitCode "restore schema dump"

  $requiredTables = @("projects", "agent_sessions", "agent_messages", "memory_entries", "cost_tracking", "audit_log")
  $restoredTableCount = Invoke-ContainerCommand "restored app table count" @(
    "psql", "-U", $DbUser, "-d", $RestoreDatabase, "-tAc",
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('projects','agent_sessions','agent_messages','memory_entries','cost_tracking','audit_log');"
  )
  if ([int]$restoredTableCount -ne 6) {
    throw "PostgreSQL restore proof failed: expected 6 required app tables, found $restoredTableCount"
  }

  $extensionCsv = Invoke-ContainerCommand "restored extension inventory" @(
    "psql", "-U", $DbUser, "-d", $RestoreDatabase, "-tAc",
    "SELECT extname FROM pg_extension WHERE extname IN ('vector','pgcrypto') ORDER BY extname;"
  )
  foreach ($requiredExtension in @("pgcrypto", "vector")) {
    if (-not (($extensionCsv | Out-String).Contains($requiredExtension))) {
      throw "PostgreSQL restore proof failed: restored database missing extension '$requiredExtension'"
    }
  }

  $checkpointTableCount = Invoke-ContainerCommand "restored checkpoint table count" @(
    "psql", "-U", $DbUser, "-d", $RestoreDatabase, "-tAc",
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('checkpoints','checkpoint_blobs','checkpoint_writes','checkpoint_migrations');"
  )
  if ([int]$checkpointTableCount -lt 4) {
    throw "PostgreSQL restore proof failed: expected at least 4 checkpoint tables, found $checkpointTableCount"
  }

  $rowCounts = @{}
  foreach ($table in $requiredTables) {
    $count = Invoke-ContainerCommand "restored row count $table" @(
      "psql", "-U", $DbUser, "-d", $RestoreDatabase, "-tAc",
      "SELECT COUNT(*) FROM public.$table;"
    )
    $rowCounts[$table] = [int]$count
  }

  $cleanupStatus = if ($KeepDatabase) { "kept" } else { "pending" }
  $manifest = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    restore_database = $RestoreDatabase
    source_database = $SourceDatabase
    backup_dump_file = $backup.dump_file
    schema_only = $true
    restored_required_tables = [int]$restoredTableCount
    restored_checkpoint_tables = [int]$checkpointTableCount
    restored_extensions = @($extensionCsv -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    restored_row_counts = $rowCounts
    isolated_temp_database = $true
    cleanup_status = $cleanupStatus
    no_production_database_mutation = $true
  }
} finally {
  if (-not $KeepDatabase) {
    Invoke-ContainerCommand "drop restore database" @(
      "psql", "-U", $DbUser, "-d", "postgres", "-v", "ON_ERROR_STOP=1", "-c",
      "DROP DATABASE IF EXISTS ""$RestoreDatabase"" WITH (FORCE);"
    ) | Out-Null
    $cleanupStatus = "dropped"
  }
}

if (-not $KeepDatabase) {
  $manifest.cleanup_status = $cleanupStatus
}

$manifestJson = $manifest | ConvertTo-Json -Depth 6 -Compress
Write-Output $manifestJson

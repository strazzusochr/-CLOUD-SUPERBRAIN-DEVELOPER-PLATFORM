param(
  [string]$Container = "cloud-superbrain-phase1-dev-postgres-1",
  [string]$Database = "superbrain_prod",
  [string]$DbUser = "superbrain",
  [string]$OutputDir = ".phase1-artifacts/postgres-backups",
  [switch]$IncludeData
)

$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "require-docker-readiness.ps1") -GateName "phase1 PostgreSQL backup proof"

function Assert-LastExitCode($label) {
  if ($LASTEXITCODE -ne 0) {
    throw "PostgreSQL backup proof failed: $label"
  }
}

function Invoke-ContainerCommand($label, [string[]]$arguments) {
  $output = docker exec $Container @arguments 2>&1
  Assert-LastExitCode $label
  return ($output | Out-String).Trim()
}

$containerId = docker ps --filter "name=^/$Container$" --format "{{.ID}}"
Assert-LastExitCode "inspect postgres container"
if ([string]::IsNullOrWhiteSpace($containerId)) {
  throw "PostgreSQL backup proof failed: container '$Container' is not running"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$mode = if ($IncludeData) { "data" } else { "schema" }
$dumpFile = Join-Path $OutputDir "$Database-$mode-$timestamp.sql"
$manifestFile = Join-Path $OutputDir "$Database-$mode-$timestamp.manifest.json"

$dumpArgs = @("pg_dump", "-U", $DbUser, "-d", $Database, "--no-owner", "--no-privileges", "--format=plain")
if (-not $IncludeData) {
  $dumpArgs += "--schema-only"
}

$dumpText = Invoke-ContainerCommand "pg_dump $mode" $dumpArgs
foreach ($requiredFragment in @(
  "CREATE TABLE public.projects",
  "CREATE TABLE public.agent_sessions",
  "CREATE TABLE public.agent_messages",
  "CREATE TABLE public.memory_entries",
  "CREATE TABLE public.cost_tracking",
  "CREATE TABLE public.audit_log"
)) {
  if (-not $dumpText.Contains($requiredFragment)) {
    throw "PostgreSQL backup proof failed: dump missing '$requiredFragment'"
  }
}

Set-Content -Path $dumpFile -Value $dumpText -Encoding utf8

$extensionCsv = Invoke-ContainerCommand "extension inventory" @(
  "psql", "-U", $DbUser, "-d", $Database, "-tAc",
  "SELECT extname FROM pg_extension WHERE extname IN ('vector','pgcrypto') ORDER BY extname;"
)
foreach ($requiredExtension in @("pgcrypto", "vector")) {
  if (-not (($extensionCsv | Out-String).Contains($requiredExtension))) {
    throw "PostgreSQL backup proof failed: extension '$requiredExtension' not present"
  }
}

$checkpointTableCount = Invoke-ContainerCommand "checkpoint table count" @(
  "psql", "-U", $DbUser, "-d", $Database, "-tAc",
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('checkpoints','checkpoint_blobs','checkpoint_writes','checkpoint_migrations');"
)
if ([int]$checkpointTableCount -lt 4) {
  throw "PostgreSQL backup proof failed: expected at least 4 LangGraph checkpoint tables, found $checkpointTableCount"
}

$requiredTables = @("projects", "agent_sessions", "agent_messages", "memory_entries", "cost_tracking", "audit_log")
$rowCounts = @{}
foreach ($table in $requiredTables) {
  $count = Invoke-ContainerCommand "row count $table" @(
    "psql", "-U", $DbUser, "-d", $Database, "-tAc",
    "SELECT COUNT(*) FROM public.$table;"
  )
  $rowCounts[$table] = [int]$count
}

$manifest = [ordered]@{
  generated_at = (Get-Date).ToUniversalTime().ToString("o")
  mode = $mode
  container = $Container
  database = $Database
  user = $DbUser
  dump_file = $dumpFile
  manifest_file = $manifestFile
  schema_only = -not $IncludeData.IsPresent
  required_tables = $requiredTables
  extensions = @($extensionCsv -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  checkpoint_tables = [int]$checkpointTableCount
  row_counts = $rowCounts
  no_secret_material = $true
  restore_note = "Schema proof only by default. Use -IncludeData only for controlled, local backup drills."
}

$manifestJson = $manifest | ConvertTo-Json -Depth 6 -Compress
Set-Content -Path $manifestFile -Value $manifestJson -Encoding utf8
Write-Output $manifestJson

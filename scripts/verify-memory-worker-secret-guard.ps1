param(
  [switch]$StaticOnly,
  [string]$OutDir = ".codex\runs\CURRENT\memory\worker-secret-guard"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) { throw "Memory worker secret guard verification failed: $label" }
}

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Memory worker secret guard verification failed: $label missing '$expected'"
  }
}

function Assert-NotContains($label, $value, $forbidden) {
  $text = ($value | Out-String)
  if ($text.Contains($forbidden)) {
    throw "Memory worker secret guard verification failed: $label contained forbidden value"
  }
}

function Assert-LastExitCode($label) {
  if ($LASTEXITCODE -ne 0) { throw "Memory worker secret guard verification failed: $label" }
}

function Invoke-Sql($query) {
  $result = docker exec cloud-superbrain-phase1-dev-postgres-1 psql -U superbrain -d superbrain_prod -tAc $query
  Assert-LastExitCode "PostgreSQL query"
  return ($result | Out-String).Trim()
}

function Wait-SqlContains($label, $query, $expected, $attempts = 20) {
  $last = ""
  for ($i = 0; $i -lt $attempts; $i++) {
    $last = Invoke-Sql $query
    if ($last.Contains($expected)) { return $last }
    Start-Sleep -Milliseconds 500
  }
  throw "Memory worker secret guard verification failed: $label expected '$expected', got '$last'"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $repoRoot "services\memory-worker\app\worker.py"
$contractPath = Join-Path $repoRoot "docs\runtime-contracts\memory-consolidation-job.md"
$workerSource = Get-Content $workerPath -Raw
$contractSource = Get-Content $contractPath -Raw

Write-Host "[memory-secret-guard] static contract"
foreach ($required in @(
  "SENSITIVE_FIELD_NAMES",
  "contains_secret(memory.metadata)",
  'secret_scope = "metadata"',
  '"reason": "secret_pattern_detected"',
  '"memory_consolidation_blocked"'
)) { Assert-Contains "worker source" $workerSource $required }
foreach ($required in @(
  "memory_worker_metadata_secret_guard_verified",
  "nested metadata",
  "memory_consolidation_blocked"
)) { Assert-Contains "contract documentation" $contractSource $required }

if ($StaticOnly) {
  Write-Host "[memory-secret-guard] status=verified_static"
  exit 0
}

Write-Host "[memory-secret-guard] nested metadata runtime proof"
$suffix = [Guid]::NewGuid().ToString("N")
$secretKey = "memory:working:metadata-secret-$suffix"
$safeKey = "memory:working:metadata-safe-$suffix"
$secretIdempotency = "metadata-secret-$suffix"
$safeIdempotency = "metadata-safe-$suffix"
$fakeSecret = "ghp_" + $suffix + "proof"
$projectId = "memory-secret-guard-$suffix"

$secretPayload = @{
  project_id = $projectId
  session_id = $null
  content_text = "metadata guard blocked probe"
  metadata = @{ nested = @{ credentials = @{ access_token = $fakeSecret } } }
  idempotency_key = $secretIdempotency
} | ConvertTo-Json -Depth 8 -Compress
$safePayload = @{
  project_id = $projectId
  session_id = $null
  content_text = "metadata guard safe control $suffix"
  metadata = @{ nested = @{ classification = "safe"; reference = $suffix } }
  idempotency_key = $safeIdempotency
} | ConvertTo-Json -Depth 8 -Compress
$secretPayloadB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($secretPayload))
$safePayloadB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($safePayload))

docker exec cloud-superbrain-phase1-dev-memory-worker-1 python -c "import base64, os, redis; r=redis.Redis.from_url(os.environ['REDIS_URL']); r.set('$secretKey', base64.b64decode('$secretPayloadB64'), ex=3600); r.set('$safeKey', base64.b64decode('$safePayloadB64'), ex=3600)"
Assert-LastExitCode "seed Redis working memory"

$run = docker exec cloud-superbrain-phase1-dev-memory-worker-1 python -m app.worker --once --force
Assert-LastExitCode "memory worker forced one-shot"
Assert-Contains "one-shot output" $run '"eligible"'

Wait-SqlContains "blocked audit" "SELECT COUNT(*) FROM audit_log WHERE event_type='memory_consolidation_blocked' AND details->>'idempotency_key'='$secretIdempotency' AND details->>'reason'='secret_pattern_detected' AND details->>'secret_scope'='metadata';" "1" | Out-Null
Wait-SqlContains "safe control persistence" "SELECT COUNT(*) FROM memory_entries WHERE metadata->>'idempotency_key'='$safeIdempotency' AND metadata#>>'{nested,classification}'='safe' AND consolidation_status='consolidated';" "1" | Out-Null

$blockedMemoryCount = Invoke-Sql "SELECT COUNT(*) FROM memory_entries WHERE metadata->>'idempotency_key'='$secretIdempotency';"
Assert-True "secret-bearing metadata was not persisted" ($blockedMemoryCount -eq "0")
$rawMemoryCount = Invoke-Sql "SELECT COUNT(*) FROM memory_entries WHERE content_text LIKE '%$fakeSecret%' OR metadata::text LIKE '%$fakeSecret%';"
Assert-True "raw token absent from memory entries" ($rawMemoryCount -eq "0")
$rawAuditCount = Invoke-Sql "SELECT COUNT(*) FROM audit_log WHERE details::text LIKE '%$fakeSecret%';"
Assert-True "raw token absent from audit log" ($rawAuditCount -eq "0")

$remainingKeys = docker exec cloud-superbrain-phase1-dev-memory-worker-1 python -c "import os, redis; r=redis.Redis.from_url(os.environ['REDIS_URL']); print(int(r.exists('$secretKey')) + int(r.exists('$safeKey')))"
Assert-LastExitCode "Redis key consumption probe"
Assert-True "processed Redis keys consumed" (($remainingKeys | Out-String).Trim() -eq "0")
Assert-NotContains "one-shot output redaction" $run $fakeSecret

$artifactDir = if ([IO.Path]::IsPathRooted($OutDir)) { $OutDir } else { Join-Path $repoRoot $OutDir }
New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
@{
  contract_version = "memory-worker-secret-guard-v1"
  status = "verified"
  scope = "DEV-ONLY"
  evidence_ref = "memory_worker_metadata_secret_guard_verified"
  nested_metadata_secret_blocked = $true
  blocked_memory_rows = 0
  sanitized_block_audit_persisted = $true
  raw_secret_persisted = $false
  redis_keys_consumed = $true
  safe_nested_metadata_consolidated = $true
  live_embedding_provider_calls = $false
  model_downloads = $false
  generated_at = (Get-Date).ToUniversalTime().ToString("o")
} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $artifactDir "report.json") -Encoding utf8

Write-Host "[memory-secret-guard] status=verified raw_secret_persisted=False"

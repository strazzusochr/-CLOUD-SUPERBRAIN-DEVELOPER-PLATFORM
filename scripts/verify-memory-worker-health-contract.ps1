param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Memory worker health verification failed: $label"
  }
}

function Assert-Contains($label, $text, $expected) {
  if (-not ($text -like "*$expected*")) {
    throw "Memory worker health verification failed: $label missing '$expected'"
  }
}

function Invoke-Text($url) {
  (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 30).Content
}

function Invoke-Json($url) {
  (Invoke-Text $url) | ConvertFrom-Json
}

$isLocalhost = $BaseUrl -match "^http://(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\])(:|/|$)"
if ($isLocalhost -and -not $AllowLocalhost) {
  throw "Localhost verification requires -AllowLocalhost and remains DEV-ONLY"
}
if (($BaseUrl -notmatch "^https://") -and -not $AllowLocalhost) {
  throw "Non-HTTPS verification requires -AllowLocalhost"
}

$contract = Invoke-Json "$BaseUrl/api/v1/memory/worker-health/contract"
Assert-True "contract version" ($contract.contract_version -eq "memory-worker-health-contract-v1")
Assert-True "evidence ref" ($contract.evidence_ref -eq "memory_worker_health_contract_visible")
Assert-True "status verified" ($contract.status -eq "verified")
Assert-True "heartbeat key" ($contract.heartbeat_key -eq "memory-worker:heartbeat")
Assert-True "healthcheck command" ($contract.docker_healthcheck_command -eq "python -m app.worker --healthcheck")
Assert-True "healthcheck timeout" ([int]$contract.docker_healthcheck_timeout_seconds -eq 15)
Assert-True "runtime snapshot healthy" ($contract.runtime_snapshot.status -eq "healthy")
Assert-True "runtime heartbeat fresh" (-not [bool]$contract.runtime_snapshot.stale_heartbeat)
Assert-True "no live embedding non-claim" (@($contract.non_claims) -contains "No live embedding provider call is made by this contract.")
Assert-True "max age bounded" ([int]$contract.max_heartbeat_age_seconds -gt 0)
Assert-True "max batch bounded" ([int]$contract.max_batch_runtime_seconds -gt 0)

$health = Invoke-Json "$BaseUrl/api/v1/health"
Assert-True "health memory worker healthy" ($health.services.memory_worker.status -eq "healthy")
Assert-True "health memory worker contract" ($health.services.memory_worker.contract_version -eq "memory-worker-health-contract-v1")
Assert-True "health memory worker evidence" ($health.services.memory_worker.evidence_ref -eq "memory_worker_health_contract_visible")
Assert-True "health stale heartbeat false" (-not [bool]$health.services.memory_worker.stale_heartbeat)

$metrics = Invoke-Text "$BaseUrl/api/v1/metrics"
Assert-Contains "metrics memory worker service" $metrics 'superbrain_service_health{service="memory_worker"} 1'

$workerSource = Get-Content -Path "services\memory-worker\app\worker.py" -Raw
foreach ($required in @("MEMORY_WORKER_HEALTH_CONTRACT_VERSION", "memory-worker-health-contract-v1", "memory_worker_health_contract_visible", "--healthcheck", "max_heartbeat_age_seconds")) {
  Assert-Contains "worker source $required" $workerSource $required
}

$apiSource = Get-Content -Path "services\agent-api\app\main.py" -Raw
foreach ($required in @("memory_worker_health_contract_payload", "/api/v1/memory/worker-health/contract", "python -m app.worker --healthcheck", "memory_worker_health_contract_visible")) {
  Assert-Contains "agent api source $required" $apiSource $required
}

$devCompose = Get-Content -Path "docker-compose.dev.yml" -Raw
$cloudCompose = Get-Content -Path "docker-compose.cloud.yml" -Raw
foreach ($compose in @($devCompose, $cloudCompose)) {
  Assert-Contains "compose healthcheck module" $compose '"python", "-m", "app.worker", "--healthcheck"'
  Assert-Contains "compose health max age" $compose "MEMORY_WORKER_HEALTH_MAX_AGE_SECONDS"
  Assert-Contains "compose health timeout" $compose "timeout: 15s"
}

$doc = Get-Content -Path "docs\runtime-contracts\memory-worker-health-contract.md" -Raw
foreach ($required in @("memory-worker-health-contract-v1", "memory_worker_health_contract_visible", "GET /api/v1/memory/worker-health/contract", "python -m app.worker --healthcheck", "No live embedding provider call")) {
  Assert-Contains "contract doc $required" $doc $required
}

Write-Host "[memory-worker-health] base_url=$BaseUrl"
Write-Host "[memory-worker-health] result=verified"

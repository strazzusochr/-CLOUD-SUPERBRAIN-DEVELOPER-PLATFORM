param(
  [string]$BaseUrl = "http://localhost:8081",
  [string]$StreamUrl = "",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Autopilot mode verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Autopilot mode verification failed: $label"
  }
}

function Assert-LocalhostAllowed($label, $url) {
  if ((-not $AllowLocalhost) -and ($url -match "localhost|127\.0\.0\.1|\[::1\]")) {
    throw "Autopilot mode proof refuses localhost for $label unless -AllowLocalhost is set"
  }
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}
$BaseUrl = $BaseUrl.TrimEnd("/")
if (-not $StreamUrl) {
  $StreamUrl = "$BaseUrl/api/stream"
}
Assert-LocalhostAllowed "BaseUrl" $BaseUrl
Assert-LocalhostAllowed "StreamUrl" $StreamUrl

Write-Host "[autopilot] base url: $BaseUrl"
Write-Host "[autopilot] stream url: $StreamUrl"

Write-Host "[autopilot] health"
$health = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/v1/health" -TimeoutSec 15
Assert-True "agent-api health is healthy" ($health.status -eq "healthy")
Assert-True "postgres healthy" ($health.services.postgres.status -eq "healthy")
Assert-True "redis healthy" ($health.services.redis.status -eq "healthy")
Assert-True "agent worker healthy" ($health.services.agent_worker.status -eq "healthy")
Assert-True "memory worker healthy" ($health.services.memory_worker.status -eq "healthy")
Assert-True "mcp gateway healthy" ($health.services.mcp_gateway.status -eq "healthy")
Assert-True "llm gateway healthy" ($health.services.llm_gateway.status -eq "healthy")
Assert-True "llm gateway dry-run mode" ($health.services.llm_gateway.live_provider_calls -eq $false)

Write-Host "[autopilot] project progress"
$progress = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/v1/project/progress" -TimeoutSec 15
Assert-True "overall progress 47" ($progress.overall_percent -eq 47)
Assert-True "seven horizontal phases" (@($progress.horizontal.items).Count -eq 7)
Assert-True "seven vertical layers" (@($progress.vertical.items).Count -eq 7)
$phase2 = @($progress.horizontal.items) | Where-Object { $_.id -eq "phase_2" } | Select-Object -First 1
$phase4 = @($progress.horizontal.items) | Where-Object { $_.id -eq "phase_4" } | Select-Object -First 1
$frontend = @($progress.vertical.items) | Where-Object { $_.id -eq "layer_1" } | Select-Object -First 1
$agentPool = @($progress.vertical.items) | Where-Object { $_.id -eq "layer_3" } | Select-Object -First 1
Assert-True "phase 2 is 86" ($phase2.percent -eq 86)
Assert-True "phase 4 is 15" ($phase4.percent -eq 15)
Assert-True "frontend is 97" ($frontend.percent -eq 97)
Assert-True "agent pool is 61" ($agentPool.percent -eq 61)
Assert-Contains "truth policy" $progress.truth_policy "Evidence-based only"

Write-Host "[autopilot] project progress integrity"
$progressIntegrity = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/v1/project/progress/integrity" -TimeoutSec 15
Assert-True "progress integrity verified" ($progressIntegrity.status -eq "verified")
Assert-True "progress integrity computed overall" ($progressIntegrity.computed_overall_percent -eq 47)
Assert-True "progress integrity manifest overall" ($progressIntegrity.manifest_overall_percent -eq 47)
Assert-Contains "progress integrity evidence" $progressIntegrity.evidence_ref "project_progress_integrity_runtime_proof"

Write-Host "[autopilot] orchestrator manifest"
$manifest = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/v1/orchestrator/manifest" -TimeoutSec 15
Assert-True "langgraph engine" ($manifest.engine -eq "langgraph")
Assert-True "deterministic dry-run mode" ($manifest.mode -eq "deterministic_dry_run")
Assert-True "no live provider calls" ($manifest.live_provider_calls -eq $false)
Assert-True "postgres checkpointing" ($manifest.checkpointing -eq "postgres")
Assert-True "forbidden live provider call guard" ($manifest.forbidden_actions -contains "live_provider_call")

Write-Host "[autopilot] superbrain stream"
$body = @{
  prompt = "autopilot mode proof: verify deterministic local Superbrain stream without live provider calls"
} | ConvertTo-Json -Compress
$streamResponse = Invoke-WebRequest -UseBasicParsing -Method Post -Uri $StreamUrl -ContentType "application/json" -Body $body -TimeoutSec 30
$streamText = $streamResponse.Content
Assert-Contains "stream status init" $streamText "event: status"
Assert-Contains "stream init message" $streamText "Agent gestartet"
Assert-Contains "stream llm message" $streamText "LLM wird aufgerufen"
Assert-Contains "stream token" $streamText "event: token"
Assert-Contains "stream deterministic response" $streamText "LLM gateway deterministic dry-run response"
Assert-Contains "stream no live provider calls" $streamText "live_provider_calls=false"
Assert-Contains "stream done" $streamText "event: done"
Assert-Contains "stream success" $streamText '"success": true'

$proof = [ordered]@{
  autopilot_mode_proof = $true
  base_url = $BaseUrl
  stream_url = $StreamUrl
  overall_percent = $progress.overall_percent
  phase2_percent = $phase2.percent
  phase4_percent = $phase4.percent
  progress_integrity = $progressIntegrity.status
  frontend_percent = $frontend.percent
  agent_pool_percent = $agentPool.percent
  stream_events = @("status:init", "status:llm", "token", "done")
  live_provider_calls = $false
  evidence_ref = "autopilot-mode-stream-proof"
  non_claims = @(
    "No live LLM provider calls are verified.",
    "No live MCP writes are verified.",
    "No production deployment is verified."
  )
}

Write-Output ($proof | ConvertTo-Json -Depth 6 -Compress)
Write-Host "[autopilot] checks completed"

param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [string]$RunId = ""
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Organism runtime event verification failed: $label"
  }
}

function Assert-NotContains($label, $value, $forbidden) {
  $text = ($value | Out-String)
  if ($text.Contains($forbidden)) {
    throw "Organism runtime event verification failed: $label contained forbidden '$forbidden'."
  }
}

if ($BaseUrl -match "^http://(localhost|127\.0\.0\.1)(:\d+)?") {
  if (-not $AllowLocalhost) {
    throw "Organism runtime event verification refused localhost without -AllowLocalhost"
  }
}

$effectiveRunId = $RunId.Trim()
if (-not $effectiveRunId) {
  $phase2RuntimeThreadId = [Guid]::NewGuid().ToString()
  $phase2RuntimeBody = @{
    project_id = "organism-runtime-events-project"
    prompt = "organism runtime event redaction projection proof"
    session_id = $phase2RuntimeThreadId
  } | ConvertTo-Json -Compress
  $phase2RuntimeRun = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/v1/phase2/runtime/start" -ContentType "application/json" -Body $phase2RuntimeBody -TimeoutSec 120
  Assert-True "phase2 runtime started" ($phase2RuntimeRun.status -eq "started")
  Assert-True "phase2 runtime no live provider" ($phase2RuntimeRun.live_provider_calls -eq $false)
  Assert-True "phase2 runtime no mcp writes" ($phase2RuntimeRun.live_mcp_writes -eq $false)
  Assert-True "phase2 runtime no production deploy" ($phase2RuntimeRun.production_deploy -eq $false)
  $effectiveRunId = [string]$phase2RuntimeRun.thread_id
}

Assert-True "run id available" (-not [string]::IsNullOrWhiteSpace($effectiveRunId))

$events = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/v1/organism/events?run_id=$([uri]::EscapeDataString($effectiveRunId))" -TimeoutSec 30
$eventsJson = $events | ConvertTo-Json -Depth 20 -Compress
Assert-True "events contract" ($events.contract_version -eq "organism-events-v1")
Assert-True "events source" ($events.source -eq "agent-api")
Assert-True "events source kind" ($events.source_kind -eq "agent_api_redacted")
Assert-True "events live" ($events.live -eq $true)
Assert-True "events run id" ([string]$events.run_id -eq $effectiveRunId)
Assert-True "events present" (@($events.events).Count -gt 0)
Assert-True "events non-claims include read-only projection" (@($events.non_claims) -contains "read-only audit projection")
Assert-NotContains "events raw details" $eventsJson '"details":'
Assert-NotContains "events raw user id" $eventsJson '"user_id":'
Assert-NotContains "events raw session id" $eventsJson '"session_id":'
Assert-NotContains "events prompt leakage" $eventsJson '"prompt":'

foreach ($event in @($events.events)) {
  Assert-True "event source kind" ($event.source_kind -eq "agent_api_redacted")
  Assert-True "event no secret output" ($event.secret_output -eq $false)
  Assert-True "event read-only writes false" ($event.writes -eq $false)
  Assert-True "event has mapped hub" (-not [string]::IsNullOrWhiteSpace([string]$event.hub))
  Assert-True "event has mapped regions" (@($event.regions).Count -gt 0)
}

$replay = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/v1/organism/replay?run_id=$([uri]::EscapeDataString($effectiveRunId))" -TimeoutSec 30
$replayJson = $replay | ConvertTo-Json -Depth 20 -Compress
Assert-True "replay contract" ($replay.contract_version -eq "organism-replay-v1")
Assert-True "replay source" ($replay.source -eq "agent-api")
Assert-True "replay source kind" ($replay.source_kind -eq "agent_api_redacted")
Assert-True "replay live" ($replay.live -eq $true)
Assert-True "replay run id" ([string]$replay.run_id -eq $effectiveRunId)
Assert-True "replay available" ($replay.replay_available -eq $true)
Assert-True "replay frames present" (@($replay.frames).Count -gt 0)
Assert-True "replay non-claims include read-only projection" (@($replay.non_claims) -contains "read-only audit projection")
Assert-NotContains "replay raw details" $replayJson '"details":'
Assert-NotContains "replay raw user id" $replayJson '"user_id":'
Assert-NotContains "replay raw session id" $replayJson '"session_id":'
Assert-NotContains "replay prompt leakage" $replayJson '"prompt":'

foreach ($frame in @($replay.frames)) {
  Assert-True "frame source kind" ($frame.source_kind -eq "agent_api_redacted")
  Assert-True "frame active hub" (@($frame.active).Count -gt 0)
  Assert-True "frame regions" (@($frame.regions).Count -gt 0)
}

Write-Host "[organism-runtime-events] verified run_id=$effectiveRunId source_kind=agent_api_redacted"

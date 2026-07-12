param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [string]$OutDir = ".codex\runs\CURRENT\phase6\netcode-local"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) { throw "Phase6 netcode loopback verification failed: $label" }
}
function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) { throw "Phase6 netcode loopback verification failed: $label missing '$expected'" }
}
function Invoke-Text($url) { return (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 30).Content }
function Invoke-Json($url) { return (Invoke-Text $url) | ConvertFrom-Json }

$BaseUrl = $BaseUrl.TrimEnd("/")
$isLocalhost = $BaseUrl -match "^http://(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\])(:|/|$)"
if ($isLocalhost -and -not $AllowLocalhost) { throw "Localhost verification requires -AllowLocalhost and remains DEV-ONLY" }
if (($BaseUrl -notmatch "^https://") -and -not $AllowLocalhost) { throw "Non-HTTPS verification requires -AllowLocalhost" }
$repoRoot = Split-Path -Parent $PSScriptRoot
$artifactDir = if ([IO.Path]::IsPathRooted($OutDir)) { $OutDir } else { Join-Path $repoRoot $OutDir }
New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null

Write-Host "[phase6-netcode] runtime contract"
$contract = Invoke-Json "$BaseUrl/api/v1/phase6/3d-netcode/contract"
Assert-True "version" ($contract.contract_version -eq "phase6-3d-netcode-loopback-runtime-v1")
Assert-True "endpoint" ($contract.endpoint -eq "GET /api/v1/phase6/3d-netcode/contract")
Assert-True "evidence" ($contract.evidence_ref -eq "phase6_3d_netcode_loopback_runtime_visible")
Assert-True "strategy" ($contract.netcode_strategy -eq "two_peer_manual_lockstep_browser_loopback")
Assert-True "transport" ($contract.transport -eq "loopback")
Assert-True "session slots" ([int]$contract.session_slots -eq 1)
Assert-True "peer limit" ([int]$contract.maximum_peers -eq 2)
Assert-True "peer ids" ((@($contract.peer_ids) -join ",") -eq "host,guest")
Assert-True "ready barrier" ($contract.ready_barrier_required -eq $true)
Assert-True "manual lockstep" ($contract.manual_lockstep_required -eq $true)
Assert-True "packets per tick" ([int]$contract.packets_per_tick -eq 2)
Assert-True "sequence" ($contract.sequence_monotonic_required -eq $true)
Assert-True "disconnect" ($contract.disconnect_stops_simulation_required -eq $true)
Assert-True "remote marker" ($contract.threejs_remote_peer_marker_required -eq $true)
Assert-True "browser memory" ($contract.browser_memory_only_required -eq $true)
Assert-True "no websocket" ($contract.websocket_allowed -eq $false)
Assert-True "no webrtc" ($contract.webrtc_allowed -eq $false)
Assert-True "no matchmaking" ($contract.matchmaking_allowed -eq $false)
Assert-True "no public lobby" ($contract.public_lobby_allowed -eq $false)
Assert-True "no server sync" ($contract.server_authoritative_sync_allowed -eq $false)
Assert-True "no network" ($contract.network_calls_required -eq $false)
Assert-True "target" ([int]$contract.phase6_progress_after_proof -eq 80)
Assert-True "scenarios" ([int]$contract.scenario_count -eq 8 -and [int]$contract.pass_count -eq 8 -and $contract.all_scenarios_pass -eq $true)
foreach ($name in @("loopback_session_lifecycle_visible","two_peer_join_leave_visible","two_peer_ready_barrier_visible","deterministic_lockstep_tick_visible","monotonic_packet_sequence_visible","guest_disconnect_fail_closed_visible","remote_transport_boundary_closed","phase6_progress_gate_bound_to_netcode_verifier")) {
  $scenario = @($contract.scenarios) | Where-Object scenario -eq $name | Select-Object -First 1
  Assert-True "scenario $name" ($null -ne $scenario -and $scenario.pass -eq $true)
  foreach ($guard in @("websocket_started","webrtc_started","matchmaking_started","public_lobby_started","server_authoritative_sync_started","network_calls","provider_write","live_mcp_write","production_deploy","secret_values_returned","release_promotion")) {
    Assert-True "guard $name/$guard" ($scenario.$guard -eq $false)
  }
}

Write-Host "[phase6-netcode] frontend and source guards"
$html = Invoke-Text "$BaseUrl/organism"
foreach ($required in @("phase6-netcode-controls","phase6-netcode-create","phase6-netcode-join","phase6-netcode-start","phase6-netcode-tick","phase6-netcode-state")) { Assert-Contains "HTML" $html $required }
$view = Get-Content (Join-Path $repoRoot "apps\frontend\components\organism\OrganismView.tsx") -Raw
$canvas = Get-Content (Join-Path $repoRoot "apps\frontend\components\organism\CortexCanvas3D.tsx") -Raw
$live = Get-Content (Join-Path $repoRoot "apps\frontend\components\organism\CortexLive.tsx") -Raw
$test = Get-Content (Join-Path $repoRoot "apps\frontend\e2e\organism.spec.ts") -Raw
$api = Get-Content (Join-Path $repoRoot "services\agent-api\app\main.py") -Raw
$doc = Get-Content (Join-Path $repoRoot "docs\runtime-contracts\phase6-3d-netcode-loopback-runtime.md") -Raw
foreach ($required in @("netcodeSessionActive","joinLoopbackGuest","startLoopbackLockstep","advanceLoopbackTick","disconnectLoopbackGuest","transport=loopback","websocket=false","server_sync=false","public_lobby=false")) { Assert-Contains "view" $view $required }
foreach ($required in @("function LoopbackPeer","data-netcode-transport","data-netcode-guest-connected","data-netcode-running","data-netcode-sequence","data-netcode-websocket")) { Assert-Contains "canvas" $canvas $required }
foreach ($required in @("netcodeGuestConnected","netcodeRunning","netcodeSequence")) { Assert-Contains "live" $live $required }
foreach ($required in @("Phase-6 netcode loopback enforces","packets=5","sequence=5","phase6-netcode-loopback.png","netcode loopback controls perform no network transport","websocket_allowed")) { Assert-Contains "test" $test $required }
foreach ($required in @("PHASE6_3D_NETCODE_CONTRACT_VERSION","phase6_3d_netcode_loopback_runtime_contract_payload","/api/v1/phase6/3d-netcode/contract")) { Assert-Contains "api" $api $required }
foreach ($required in @("phase6-3d-netcode-loopback-runtime-v1",'Phase 6 may move from `72%` to `80%`',"WebSocket","server-authoritative","DEV-ONLY")) { Assert-Contains "doc" $doc $required }

$manifest = Get-Content (Join-Path $repoRoot "docs\project-progress.manifest.json") -Raw | ConvertFrom-Json
$phase6 = @($manifest.horizontal.items) | Where-Object id -eq "phase_6" | Select-Object -First 1
Assert-True "manifest phase6 80" ([int]$phase6.percent -eq 80)
Assert-True "manifest overall 82" ([int]$manifest.overall_percent -eq 82)
Assert-Contains "manifest marker" $phase6.status "phase6_3d_netcode_loopback_runtime_visible"
Assert-Contains "manifest lockstep marker" $phase6.status "two_peer_lockstep_verified"
Assert-Contains "manifest remote boundary" $phase6.status "remote_transport_boundary_closed"

Write-Host "[phase6-netcode] Chromium interaction proof"
$oldBase = $env:PHASE6_BASE_URL; $oldDir = $env:PHASE6_ARTIFACT_DIR
try {
  $env:PHASE6_BASE_URL = $BaseUrl; $env:PHASE6_ARTIFACT_DIR = $artifactDir
  Push-Location (Join-Path $repoRoot "apps\frontend")
  try { npx playwright test --grep "Phase-6 netcode loopback enforces" --workers=1 --reporter=line; if ($LASTEXITCODE -ne 0) { throw "Playwright netcode loopback proof failed" } } finally { Pop-Location }
} finally { $env:PHASE6_BASE_URL = $oldBase; $env:PHASE6_ARTIFACT_DIR = $oldDir }
$screenshot = Join-Path $artifactDir "phase6-netcode-loopback.png"
Assert-True "screenshot exists" (Test-Path $screenshot)
$bytes = (Get-Item $screenshot).Length
Assert-True "screenshot size" ($bytes -gt 25000)
@{ contract_version="phase6-3d-netcode-loopback-runtime-v1"; status="verified"; scope=if($isLocalhost){"DEV-ONLY"}else{"hosted_https"}; transport="loopback"; peers=2; ticks=2; packets=5; sequence=5; websocket=$false; webrtc=$false; server_sync=$false; network_calls=$false; production_deploy=$false; screenshot=@{path="phase6-netcode-loopback.png";bytes=$bytes}; generated_at=(Get-Date).ToUniversalTime().ToString("o") } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $artifactDir "report.json") -Encoding utf8
Write-Host "[phase6-netcode] result=verified"
Write-Host "[phase6-netcode] screenshot_bytes=$bytes"

param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [string]$OutDir = ".codex\runs\CURRENT\phase6\scoreboard-performance-local"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) { throw "Phase6 local scoreboard/performance verification failed: $label" }
}
function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) { throw "Phase6 local scoreboard/performance verification failed: $label missing '$expected'" }
}
function Invoke-Text($url) { return (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 30).Content }
function Invoke-Json($url) { return (Invoke-Text $url) | ConvertFrom-Json }
function Get-Sha256($path) {
  $sha = [Security.Cryptography.SHA256]::Create()
  $stream = [IO.File]::OpenRead($path)
  try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace("-", "").ToLowerInvariant() }
  finally { $stream.Dispose(); $sha.Dispose() }
}

$BaseUrl = $BaseUrl.TrimEnd("/")
$isLocalhost = $BaseUrl -match "^http://(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\])(:|/|$)"
if ($isLocalhost -and -not $AllowLocalhost) { throw "Localhost verification requires -AllowLocalhost and remains DEV-ONLY" }
if (($BaseUrl -notmatch "^https://") -and -not $AllowLocalhost) { throw "Non-HTTPS verification requires -AllowLocalhost" }
$repoRoot = Split-Path -Parent $PSScriptRoot
$artifactDir = if ([IO.Path]::IsPathRooted($OutDir)) { $OutDir } else { Join-Path $repoRoot $OutDir }
New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null

Write-Host "[phase6-scoreboard-performance] runtime contract"
$contract = Invoke-Json "$BaseUrl/api/v1/phase6/local-scoreboard-performance/contract"
Assert-True "version" ($contract.contract_version -eq "phase6-local-scoreboard-performance-runtime-v1")
Assert-True "endpoint" ($contract.endpoint -eq "GET /api/v1/phase6/local-scoreboard-performance/contract")
Assert-True "evidence" ($contract.evidence_ref -eq "phase6_local_scoreboard_performance_runtime_visible")
Assert-True "mode" ($contract.mode -eq "phase6_volatile_scoreboard_bounded_frame_sample_contract")
Assert-True "scope" ($contract.leaderboard_scope -eq "volatile_browser_memory")
Assert-True "top three" ([int]$contract.leaderboard_maximum_entries -eq 3)
Assert-True "sort order" ((@($contract.leaderboard_sort_order) -join ",") -eq "score_desc,completions_desc,capture_sequence_asc")
Assert-True "entry fields" ((@($contract.leaderboard_entry_fields) -join ",") -eq "capture_sequence,score,completions")
Assert-True "no user input fields" (@($contract.leaderboard_user_input_fields).Count -eq 0)
Assert-True "score source" ($contract.score_source -eq "current_deterministic_gameplay_state")
Assert-True "stats source" ($contract.performance_sample_source -eq "existing_threejs_renderer_stats")
Assert-True "sample count" ([int]$contract.performance_sample_count -eq 12)
Assert-True "sample cadence" ($contract.performance_sample_cadence -eq "renderer_stats_update_approximately_500ms")
Assert-True "sample aggregation" ($contract.performance_aggregation -eq "arithmetic_mean_rounded_to_one_decimal")
Assert-True "derived interval" ($contract.performance_frame_interval_semantics -eq "derived_from_fps_not_independent_gpu_timing")
Assert-True "invalid sample guard" ($contract.performance_invalid_sample_policy -eq "ignore_non_finite_zero_or_negative_samples")
Assert-True "sample timeout" ([int]$contract.performance_timeout_seconds -eq 20 -and $contract.performance_timeout_result -eq "fail_renderer_inactive_timeout")
Assert-True "sample restart" ($contract.performance_restart_policy -eq "discard_previous_samples_and_restart_at_zero")
Assert-True "minimum fps" ([int]$contract.performance_minimum_fps -eq 25)
Assert-True "maximum frame time" ([int]$contract.performance_maximum_frame_ms -eq 40)
Assert-True "browser memory" ($contract.browser_memory_only_required -eq $true)
Assert-True "no sync" ($contract.leaderboard_sync_allowed -eq $false)
Assert-True "no persistence" ($contract.persistent_storage_allowed -eq $false)
Assert-True "no account" ($contract.account_identity_required -eq $false)
Assert-True "no telemetry" ($contract.telemetry_allowed -eq $false)
Assert-True "no network" ($contract.network_calls_required -eq $false)
Assert-True "no capacity claim" ($contract.scale_capacity_claim_allowed -eq $false)
Assert-True "target" ([int]$contract.phase6_progress_after_proof -eq 90)
Assert-True "policy scenarios are not runtime proof" ($contract.scenario_semantics -eq "static_policy_requirements_not_runtime_evidence" -and $contract.runtime_browser_evidence_required -eq $true)
Assert-True "scenarios" ([int]$contract.scenario_count -eq 8 -and [int]$contract.pass_count -eq 8 -and $contract.all_scenarios_pass -eq $true)
foreach ($method in @("POST", "PUT", "DELETE")) {
  $statusCode = curl.exe -sS -o NUL -w "%{http_code}" -X $method "$BaseUrl/api/v1/phase6/local-scoreboard-performance/contract"
  Assert-True "$method is read-only boundary" ([string]$statusCode -eq "405")
}
foreach ($name in @("volatile_top_three_runs_visible","deterministic_score_ordering_visible","leaderboard_reset_visible","bounded_frame_sample_visible","frame_budget_result_visible","remote_score_sync_boundary_closed","capacity_claim_boundary_closed","phase6_progress_gate_bound_to_scoreboard_verifier")) {
  $scenario = @($contract.scenarios) | Where-Object scenario -eq $name | Select-Object -First 1
  Assert-True "scenario $name" ($null -ne $scenario -and $scenario.pass -eq $true)
  foreach ($guard in @("leaderboard_sync_started","persistent_storage_started","telemetry_started","network_calls","provider_write","live_mcp_write","production_deploy","secret_values_returned","release_promotion","scale_capacity_claimed")) {
    Assert-True "guard $name/$guard" ($scenario.$guard -eq $false)
  }
}

Write-Host "[phase6-scoreboard-performance] frontend and source guards"
$html = Invoke-Text "$BaseUrl/organism"
foreach ($required in @("phase6-scoreboard-performance-controls","phase6-leaderboard-capture","phase6-leaderboard-reset","phase6-performance-start","phase6-performance-state")) { Assert-Contains "HTML" $html $required }
$view = Get-Content (Join-Path $repoRoot "apps\frontend\components\organism\OrganismView.tsx") -Raw
$test = Get-Content (Join-Path $repoRoot "apps\frontend\e2e\organism.spec.ts") -Raw
$api = Get-Content (Join-Path $repoRoot "services\agent-api\app\main.py") -Raw
$doc = Get-Content (Join-Path $repoRoot "docs\runtime-contracts\phase6-local-scoreboard-performance-runtime.md") -Raw
$wiring = Get-Content (Join-Path $repoRoot "apps\frontend\lib\workspaceWiring.ts") -Raw
foreach ($required in @("phase6-scoreboard-performance-controls","phase6-leaderboard-capture","phase6-leaderboard-reset","phase6-leaderboard-list","phase6-performance-start","phase6-performance-result","local_only=true","sync=false","storage=false","network=false")) { Assert-Contains "view" $view $required }
foreach ($required in @("Phase-6 local scoreboard and performance sample stay browser-local","phase6-local-scoreboard-performance-runtime-v1","phase6-local-scoreboard-performance.png","fetch","xhr","websocket","localStorage","indexedDB")) { Assert-Contains "test" $test $required }
foreach ($required in @("PHASE6_LOCAL_SCOREBOARD_CONTRACT_VERSION","phase6_local_scoreboard_performance_runtime_contract_payload","/api/v1/phase6/local-scoreboard-performance/contract")) { Assert-Contains "api" $api $required }
foreach ($required in @("phase6-local-scoreboard-performance-runtime-v1",'Phase 6 may move from `80%` to `90%`',"twelve-sample","DEV-ONLY")) { Assert-Contains "doc" $doc $required }
Assert-Contains "workspace wiring" $wiring "/api/v1/phase6/local-scoreboard-performance/contract"

$manifest = Get-Content (Join-Path $repoRoot "docs\project-progress.manifest.json") -Raw | ConvertFrom-Json
$phase6 = @($manifest.horizontal.items) | Where-Object id -eq "phase_6" | Select-Object -First 1
Assert-True "manifest phase6 90" ($null -ne $phase6 -and [int]$phase6.percent -eq 90)
$expectedOverall = [int][Math]::Round((@($manifest.horizontal.items) | Measure-Object -Property percent -Average).Average)
Assert-True "manifest overall equals rounded horizontal phase average" ([int]$manifest.overall_percent -eq $expectedOverall)
foreach ($marker in @("phase6_local_scoreboard_performance_runtime_visible","local_top3_frame_sample_verified","phase6_local_leaderboard_runtime_visible","phase6_deterministic_top3_ordering_verified","phase6_performance_sample_runtime_visible","phase6_frame_budget_classification_verified","phase6_leaderboard_sync_blocked","phase6_capacity_claim_blocked")) { Assert-Contains "manifest marker" $phase6.status $marker }

Write-Host "[phase6-scoreboard-performance] Chromium interaction proof"
$oldBase = $env:PHASE6_BASE_URL
$oldDir = $env:PHASE6_ARTIFACT_DIR
try {
  $env:PHASE6_BASE_URL = $BaseUrl
  $env:PHASE6_ARTIFACT_DIR = $artifactDir
  Push-Location (Join-Path $repoRoot "apps\frontend")
  try {
    npx playwright test --grep "Phase-6 local scoreboard and performance sample stay browser-local" --workers=1 --reporter=line
    if ($LASTEXITCODE -ne 0) { throw "Playwright local scoreboard/performance proof failed" }
  } finally { Pop-Location }
} finally {
  $env:PHASE6_BASE_URL = $oldBase
  $env:PHASE6_ARTIFACT_DIR = $oldDir
}
$screenshot = Join-Path $artifactDir "phase6-local-scoreboard-performance.png"
Assert-True "screenshot exists" (Test-Path $screenshot)
$bytes = (Get-Item $screenshot).Length
Assert-True "screenshot size" ($bytes -gt 25000)
$observedPath = Join-Path $artifactDir "phase6-local-scoreboard-performance-observed.json"
Assert-True "observed evidence exists" (Test-Path $observedPath)
$observed = Get-Content $observedPath -Raw | ConvertFrom-Json
Assert-True "observed contract" ($observed.contractVersion -eq "phase6-local-scoreboard-performance-runtime-v1")
$observedTop3 = @($observed.leaderboard.observedTop3)
Assert-True "observed leaderboard maximum" ([int]$observed.leaderboard.maximumEntries -eq 3 -and $observedTop3.Count -eq 3)
Assert-True "observed deterministic ranking" ((@($observedTop3 | ForEach-Object { [string]$_.runId }) -join ",") -eq "L003,L004,L002")
Assert-True "observed ranking values" ([int]$observedTop3[0].score -eq 20 -and [int]$observedTop3[0].completions -eq 3 -and [int]$observedTop3[2].score -eq 10 -and [int]$observedTop3[2].completions -eq 2)
$observedSamples = @($observed.performance.samples)
Assert-True "observed twelve samples" ($observedSamples.Count -eq 12)
Assert-True "observed finite positive samples" (@($observedSamples | Where-Object { [double]::IsNaN([double]$_.fps) -or [double]::IsInfinity([double]$_.fps) -or [double]::IsNaN([double]$_.ms) -or [double]::IsInfinity([double]$_.ms) -or [double]$_.fps -le 0 -or [double]$_.ms -le 0 }).Count -eq 0)
$calculatedFps = [math]::Round([double](($observedSamples | Measure-Object -Property fps -Average).Average), 1)
$calculatedMs = [math]::Round([double](($observedSamples | Measure-Object -Property ms -Average).Average), 1)
Assert-True "observed fps average" ([double]$observed.performance.averages.fps -eq $calculatedFps)
Assert-True "observed frame average" ([double]$observed.performance.averages.frameIntervalMs -eq $calculatedMs)
$expectedClassification = if ($calculatedFps -ge 25 -and $calculatedMs -le 40) { "pass" } else { "fail" }
Assert-True "observed classification" ([string]$observed.performance.terminalClassification -eq $expectedClassification)
Assert-True "observed thresholds" ([int]$observed.performance.thresholds.minimumFps -eq 25 -and [int]$observed.performance.thresholds.maximumFrameIntervalMs -eq 40)
Assert-True "observed derived interval" ($observed.performance.frameIntervalSource -eq "derived_from_fps" -and $observed.performance.gpuBenchmarkClaimed -eq $false)
Assert-True "observed pixel proof" ([int]$observed.pixelStats.nonZeroSamples -gt 100 -and [int]$observed.pixelStats.uniqueColorBuckets -gt 8)
Assert-True "observed viewport" ([int]$observed.viewport.width -gt 0 -and [int]$observed.viewport.height -gt 0)
Assert-True "observed non-claims" ($observed.nonClaims.sync -eq $false -and $observed.nonClaims.storage -eq $false -and $observed.nonClaims.network -eq $false -and $observed.nonClaims.capacityClaim -eq $false -and $observed.nonClaims.scaleClaim -eq $false)
foreach ($guard in $observed.guards.PSObject.Properties) {
  Assert-True "observed guard $($guard.Name)" ([int]$guard.Value -eq 0)
}

$sourceHashes = @{}
foreach ($relativePath in @("apps\frontend\components\organism\OrganismView.tsx","apps\frontend\e2e\organism.spec.ts","services\agent-api\app\main.py","scripts\verify-phase6-local-scoreboard-performance-runtime.ps1")) {
  $sourceHashes[$relativePath.Replace("\", "/")] = Get-Sha256 (Join-Path $repoRoot $relativePath)
}
$generatedAt = (Get-Date).ToUniversalTime().ToString("o")
$report = @{
  contract_version = "phase6-local-scoreboard-performance-runtime-v1"
  status = "verified"
  scope = if ($isLocalhost) { "DEV-ONLY" } else { "hosted_https" }
  leaderboard = @{ maximum_entries = 3; observed_top3 = $observedTop3 }
  performance = @{ sample_count = 12; samples = $observedSamples; average_fps = $calculatedFps; average_frame_interval_ms = $calculatedMs; classification = $expectedClassification; minimum_fps = 25; maximum_frame_interval_ms = 40; frame_interval_source = "derived_from_fps"; gpu_benchmark_claimed = $false }
  guard_counters = $observed.guards
  pixel_stats = $observed.pixelStats
  viewport = $observed.viewport
  non_claims = @{ leaderboard_sync = $false; persistent_storage = $false; network_calls = $false; scale_capacity_claimed = $false; production_deploy = $false }
  source_head = (git -C $repoRoot rev-parse HEAD).Trim()
  source_hashes = $sourceHashes
  production_deploy = $false
  screenshot = @{ path = "phase6-local-scoreboard-performance.png"; bytes = $bytes }
  observed_evidence = "phase6-local-scoreboard-performance-observed.json"
  generated_at = $generatedAt
}
$report | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $artifactDir "report.json") -Encoding utf8
@"
# Phase 6 Local Scoreboard And Performance Proof

- Status: verified
- Scope: $(if ($isLocalhost) { "DEV-ONLY" } else { "hosted_https" })
- Generated: $generatedAt
- Top 3: $(@($observedTop3 | ForEach-Object { "$($_.runId):score=$($_.score):completions=$($_.completions)" }) -join ", ")
- Samples: 12
- Average FPS: $calculatedFps
- Average frame interval: $calculatedMs ms (derived from FPS)
- Classification: $expectedClassification
- Pixel proof: non-zero=$($observed.pixelStats.nonZeroSamples), color-buckets=$($observed.pixelStats.uniqueColorBuckets)
- Guard counters: all zero
- Leaderboard sync: false
- Persistent storage: false
- Network calls: false
- Scale/capacity claim: false
- Production deploy: false

This is bounded browser interaction evidence, not a GPU benchmark, hosted scale proof, capacity claim, or production performance proof.
"@ | Set-Content (Join-Path $artifactDir "report.md") -Encoding utf8
Write-Host "[phase6-scoreboard-performance] result=verified"
Write-Host "[phase6-scoreboard-performance] screenshot_bytes=$bytes"

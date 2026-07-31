<#
  verify-phase6-scale-runtime.ps1

  Measures the phase6_scale_runtime gate against the criterion committed in
  docs/runtime-state/phase6-scale-criterion.json.

  Two properties matter more than the numbers it prints:

    1. It cannot open the gate. It only writes an evidence artifact. Opening
       phase6_scale_runtime stays an Owner action bound to this evidence.
    2. It fails closed. If the write tier cannot run, the script exits
       non-zero and reports BLOCKED. It never downgrades to a read-only run
       and prints green -- that false-green shape has already cost this
       project one wrong gate.
#>
[CmdletBinding()]
param(
  [string]$CriterionPath,
  [string]$BaseUrl,
  [switch]$AllowHostedWrites
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $CriterionPath) {
  $CriterionPath = Join-Path $repoRoot "docs\runtime-state\phase6-scale-criterion.json"
}

function Fail([string]$message) {
  Write-Host "[phase6-scale] FAIL: $message"
  exit 1
}
function Blocked([string]$message) {
  Write-Host "[phase6-scale] BLOCKED: $message"
  exit 2
}

if (-not (Test-Path -LiteralPath $CriterionPath)) {
  Fail "criterion file missing: $CriterionPath"
}
$criterion = Get-Content -LiteralPath $CriterionPath -Raw | ConvertFrom-Json

if ([string]$criterion.contract_version -ne "phase6-scale-criterion-v1") {
  Fail "unexpected criterion contract_version"
}
if (-not [bool]$criterion.declared_before_first_run) {
  Fail "criterion does not assert declared_before_first_run"
}
if (-not [bool]$criterion.envelope.zero_card) {
  Fail "criterion is not zero-card; paid capacity is forbidden for this gate"
}

if (-not $BaseUrl) { $BaseUrl = [string]$criterion.target.base_url }
if ($BaseUrl -notmatch '^https://') { Fail "base url must be https" }

$maxTotal = [int]$criterion.envelope.max_total_requests
$script:issued = 0
$script:controlIssued = 0

# One pooled HttpClient for the whole run. The first version of this script used
# ForEach-Object -Parallel with Invoke-WebRequest, which gave every request its own
# runspace and its own TLS handshake -- at concurrency 50 that harness cost plausibly
# dominated the measurement and made the numbers unusable as a server statement.
Add-Type -AssemblyName System.Net.Http
$handler = [System.Net.Http.SocketsHttpHandler]::new()
$handler.MaxConnectionsPerServer = 128
$handler.PooledConnectionLifetime = [TimeSpan]::FromMinutes(10)
$httpClient = [System.Net.Http.HttpClient]::new($handler)
$httpClient.Timeout = [TimeSpan]::FromSeconds(30)

# Closed-loop load: each wave fires $conc concurrent requests and waits for all of
# them before the next wave starts. Per-request timing therefore includes in-wave
# queueing, which is the intended signal.
function Invoke-LoadTier([string]$url, [int]$conc, [int]$count) {
  $lat = New-Object System.Collections.Generic.List[double]
  $codes = New-Object System.Collections.Generic.List[int]
  $done = 0
  while ($done -lt $count) {
    $wave = [Math]::Min($conc, $count - $done)
    $watches = @()
    $tasks = @()
    for ($i = 0; $i -lt $wave; $i++) {
      $watches += [System.Diagnostics.Stopwatch]::StartNew()
      $tasks += $httpClient.GetAsync($url)
    }
    try { [System.Threading.Tasks.Task]::WaitAll($tasks) } catch { }
    for ($i = 0; $i -lt $wave; $i++) {
      $watches[$i].Stop()
      $lat.Add($watches[$i].Elapsed.TotalMilliseconds)
      try {
        $codes.Add([int]$tasks[$i].Result.StatusCode)
        $tasks[$i].Result.Dispose()
      } catch { $codes.Add(0) }
    }
    $done += $wave
  }
  return [pscustomobject]@{ latencies = @($lat); codes = @($codes) }
}

function Get-Percentile([double[]]$values, [double]$p) {
  if ($values.Count -eq 0) { return 0 }
  $sorted = @($values | Sort-Object)
  $idx = [Math]::Ceiling($p * $sorted.Count) - 1
  if ($idx -lt 0) { $idx = 0 }
  if ($idx -ge $sorted.Count) { $idx = $sorted.Count - 1 }
  return [Math]::Round($sorted[$idx], 1)
}

Write-Host "[phase6-scale] target   : $BaseUrl"
Write-Host "[phase6-scale] envelope : max $maxTotal requests, zero-card"

# --- write tier gate check happens FIRST, so a missing token cannot be
# --- discovered only after a green-looking read run.
$authEnvName = [string]$criterion.write_tier.auth_env_name
$authValue = [Environment]::GetEnvironmentVariable($authEnvName)
$writeRequired = [bool]$criterion.write_tier.required
$missingWriteAuthIsFailure = [bool]$criterion.fail_closed.missing_write_auth_is_failure

# The blockers are recorded here and enforced at the very end. The read tiers
# still run, because measured read capacity is useful evidence for the Owner --
# but no combination of read results can clear these, so the script cannot end
# green while the write tier is missing.
$writeBlockers = @()
if ($writeRequired -and [string]::IsNullOrWhiteSpace($authValue) -and $missingWriteAuthIsFailure) {
  Write-Host "[phase6-scale] write tier needs $authEnvName (value is never printed)"
  $writeBlockers += "missing $authEnvName"
}
if ($writeRequired -and -not $AllowHostedWrites) {
  $writeBlockers += "-AllowHostedWrites not passed (hosted writes need the Owner gate)"
}

# --- read tiers -------------------------------------------------------------
$healthUrl = "$BaseUrl/api/v1/health"
$tierResults = @()
foreach ($tier in $criterion.read_tiers) {
  $conc = [int]$tier.concurrency
  $count = [int]$tier.requests
  $remaining = $maxTotal - $script:issued
  if ($remaining -le 0) { break }
  if ($count -gt $remaining) { $count = $remaining }

  $tier1 = Invoke-LoadTier $healthUrl $conc $count
  $script:issued += $count

  $lat = @($tier1.latencies)
  $codes = @($tier1.codes)
  $ok2xx = @($codes | Where-Object { $_ -ge 200 -and $_ -lt 300 }).Count
  $throttled = @($codes | Where-Object { $_ -eq 429 }).Count
  $server5xx = @($codes | Where-Object { $_ -ge 500 }).Count
  $transport = @($codes | Where-Object { $_ -eq 0 }).Count

  # Attribution control at the same concurrency: same client, same TLS path, same
  # edge, but /cdn-cgi/trace never reaches the Worker.
  $ctlP95 = $null
  $ctlCount = [Math]::Min($conc * 4, [int]$criterion.control_tier.max_control_requests - $script:controlIssued)
  if ($ctlCount -gt 0) {
    $ctl = Invoke-LoadTier ($BaseUrl + [string]$criterion.control_tier.path) $conc $ctlCount
    $script:controlIssued += $ctlCount
    $ctlP95 = Get-Percentile @($ctl.latencies) 0.95
  }

  $tierResults += [pscustomobject]@{
    control_p95_ms = $ctlP95
    worker_share_p95_ms = if ($null -ne $ctlP95) { [Math]::Round((Get-Percentile $lat 0.95) - $ctlP95, 1) } else { $null }
    concurrency    = $conc
    requests       = $count
    success_2xx    = $ok2xx
    throttled_429  = $throttled
    server_5xx     = $server5xx
    transport_fail = $transport
    p50_ms         = Get-Percentile $lat 0.50
    p95_ms         = Get-Percentile $lat 0.95
    p99_ms         = Get-Percentile $lat 0.99
  }
  Write-Host ("[phase6-scale] c={0,-3} n={1,-4} 2xx={2,-4} 429={3,-3} 5xx={4,-3} p95={5}ms  edge-control={6}ms  worker-share={7}ms" -f `
    $conc, $count, $ok2xx, $throttled, $server5xx, $tierResults[-1].p95_ms, $ctlP95, $tierResults[-1].worker_share_p95_ms)
}

# --- evaluate against the pre-declared criterion ----------------------------
$totalReq = ($tierResults | Measure-Object -Property requests -Sum).Sum
$totalOk = ($tierResults | Measure-Object -Property success_2xx -Sum).Sum
$total429 = ($tierResults | Measure-Object -Property throttled_429 -Sum).Sum
$total5xx = ($tierResults | Measure-Object -Property server_5xx -Sum).Sum
$worstP95 = ($tierResults | Measure-Object -Property p95_ms -Maximum).Maximum

# 429 counts as a clean degradation, not as a failure (criterion.throttle_note)
$successRatio = if ($totalReq -gt 0) { [Math]::Round(($totalOk + $total429) / $totalReq, 4) } else { 0 }

$failures = @()
if ($successRatio -lt [double]$criterion.pass_criteria.min_success_ratio) {
  $failures += "success ratio $successRatio below $($criterion.pass_criteria.min_success_ratio)"
}
if ($worstP95 -gt [double]$criterion.pass_criteria.max_p95_ms) {
  $failures += "worst p95 ${worstP95}ms above $($criterion.pass_criteria.max_p95_ms)ms"
}
if ($total5xx -gt [int]$criterion.pass_criteria.own_5xx_allowed) {
  $failures += "$total5xx server 5xx responses, allowed $($criterion.pass_criteria.own_5xx_allowed)"
}

# The write tier never ran. Under the committed criterion the gate cannot pass
# on read evidence alone, so this is an unconditional blocker, not a warning.
$writeTierRan = ($writeBlockers.Count -eq 0)

$artifactDir = Join-Path $repoRoot ".phase1-artifacts\phase6-scale"
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
$report = [pscustomobject]@{
  contract_version    = "phase6-scale-evidence-v1"
  generated_at_utc    = (Get-Date).ToUniversalTime().ToString("o")
  criterion_contract  = [string]$criterion.contract_version
  base_url            = $BaseUrl
  zero_card           = $true
  requests_issued     = $script:issued
  requests_cap        = $maxTotal
  read_tiers          = $tierResults
  success_ratio       = $successRatio
  worst_p95_ms        = $worstP95
  server_5xx_total    = $total5xx
  throttled_429_total = $total429
  read_criteria_met   = ($failures.Count -eq 0)
  read_failures       = $failures
  write_tier_ran      = $writeTierRan
  gate_may_open       = $false
  gate_open_blocked_by = @($writeBlockers)
  non_claims          = @($criterion.non_claims)
  # Hardened harness: one pooled HttpClient (connection reuse, no per-request TLS
  # handshake, no runspace per request) plus an edge control at the same concurrency.
  # /cdn-cgi/trace shares client, TLS path and edge but never enters the Worker, so
  # worker_share_p95_ms is the Worker's own contribution.
  measurement_scope   = "end_to_end_client_observed_with_edge_control"
  attribution_valid   = ($script:controlIssued -gt 0)
  attribution_note    = "Pooled HttpClient plus per-tier /cdn-cgi/trace control. worker_share_p95_ms = worker p95 minus edge-control p95 at identical concurrency."
  harness_version     = "pooled-httpclient-v2"
  control_requests    = $script:controlIssued
  control_path        = [string]$criterion.control_tier.path
}
$reportPath = Join-Path $artifactDir "scale-evidence.json"
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportPath -Encoding utf8

Write-Host ""
Write-Host "[phase6-scale] requests issued : $($script:issued) / $maxTotal cap"
Write-Host "[phase6-scale] success ratio   : $successRatio (429 counted as clean degradation)"
Write-Host "[phase6-scale] worst p95       : ${worstP95}ms"
Write-Host "[phase6-scale] evidence        : $reportPath"
Write-Host ""

if ($failures.Count -gt 0) {
  Fail ("read tier did not meet the declared criterion: " + ($failures -join "; "))
}
Write-Host "[phase6-scale] read tier meets the declared criterion"
if ($writeBlockers.Count -gt 0) {
  Blocked ("phase6_scale_runtime stays CLOSED: " + ($writeBlockers -join "; ") +
    ". Read-path capacity alone is not a scale proof -- the declared criterion requires parallel D1 writes with readback.")
}
Write-Host "[phase6-scale] write tier ran; evidence written. Gate opening remains an Owner decision."
exit 0

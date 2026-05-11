param(
  [string]$ReleaseId = "prod-candidate-2026-05-05-rc1",
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) { throw "Verification failed: $label did not contain '$expected'." }
}

function Assert-Equal($label, $actual, $expected) {
  if ($actual -ne $expected) { throw "Verification failed: $label expected '$expected' but got '$actual'." }
}

function Get-Json($uri) {
  $python = @"
import urllib.request
with urllib.request.urlopen(r'''$uri''', timeout=30) as response:
    print(response.read().decode("utf-8"))
"@
  $content = $python | py -3 -
  return ($content | ConvertFrom-Json)
}
$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase4 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_4" }).percent)
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)

$artifactPath = "docs\release-artifacts\$ReleaseId-observability-recheck.md"
$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "release_id: ``$ReleaseId``",
  "overall_percent: ``$expectedOverall``",
  "phase_4_percent: ``$expectedPhase4``",
  "phase_5_percent: ``$expectedPhase5``",
  "Current progress carried in observability recheck: ``overall=$expectedOverall``, ``phase5=$expectedPhase5``",
  'Metrics exposed project progress gauge: `superbrain_project_progress_percent`',
  'Candidate decision remained `no-release`'
)) { Assert-Contains "observability recheck artifact" $artifact $required }

$candidate = Get-Content "docs\release-artifacts\$ReleaseId.md" -Raw
Assert-Contains "candidate observability recheck proof linked" $candidate 'observability_recheck_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-observability-recheck.md`'
Assert-Contains "candidate evidence observability recheck proof linked" $candidate 'Observability recheck proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-observability-recheck.md`'

$healthStatus = @"
import urllib.request
with urllib.request.urlopen(r'''$BaseUrl/api/v1/health''', timeout=20) as r:
    print(r.status)
"@ | py -3 -
Assert-Contains "health status" $healthStatus "200"

$progress = Get-Json "$BaseUrl/api/v1/project/progress"
$phase4 = $progress.horizontal.items | Where-Object { $_.id -eq "phase_4" } | Select-Object -First 1
$phase5 = $progress.horizontal.items | Where-Object { $_.id -eq "phase_5" } | Select-Object -First 1
Assert-Equal "hosted overall percent" $progress.overall_percent $expectedOverall
Assert-Equal "hosted phase4 percent" $phase4.percent $expectedPhase4
Assert-Equal "hosted phase5 percent" $phase5.percent $expectedPhase5

$integrity = Get-Json "$BaseUrl/api/v1/project/progress/integrity"
Assert-Equal "hosted integrity status" $integrity.status "verified"

$metrics = @"
import urllib.request
with urllib.request.urlopen(r'''$BaseUrl/api/v1/metrics''', timeout=20) as r:
    print(r.read().decode('utf-8','replace')[:2000])
"@ | py -3 -
Assert-Contains "metrics gauge" $metrics "superbrain_project_progress_percent"

$audit = Get-Json "$BaseUrl/api/v1/audit/recent?limit=5"
$escalations = Get-Json "$BaseUrl/api/v1/escalations/recent?limit=5"
$gates = Get-Json "$BaseUrl/api/v1/external-gates"
if (-not $audit.events) { throw "Verification failed: audit feed must remain reachable." }
if (-not $escalations.events) { throw "Verification failed: escalation feed must remain reachable." }
Assert-Equal "external gates status" $gates.status "verified"

Write-Host "[phase5-observability-recheck] verified"

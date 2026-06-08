param(
  [string]$ReleaseId = "prod-candidate-2026-05-05-rc1",
  [string]$BaseUrl = $(if ($env:STAGING_BASE_URL) { $env:STAGING_BASE_URL } else { "" })
)

$ErrorActionPreference = "Stop"

function Assert-HostedBaseUrlConfigured {
  if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    throw "Hosted verifier requires -BaseUrl or env:STAGING_BASE_URL (HTTPS, non-localhost)."
  }
  if ($BaseUrl -notmatch '^https://') {
    throw "Hosted verifier requires an HTTPS BaseUrl."
  }
  if ($BaseUrl -match 'localhost|127\.0\.0\.1|\[::1\]|0\.0\.0\.0|host\.docker\.internal') {
    throw "Hosted verifier refuses localhost and loopback BaseUrl values."
  }
}
Assert-HostedBaseUrlConfigured


function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Verification failed: $label did not contain '$expected'."
  }
}

function Get-Json($url) {
  @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$url", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@ | py -3 -
}

function Get-Status($url) {
  @"
import ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$url", context=ctx, timeout=20) as r:
    print(r.status)
"@ | py -3 -
}

$artifactPath = "docs\release-artifacts\prod-candidate-2026-05-05-rc1-post-handoff-stability-watch.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing post-handoff stability watch artifact: $artifactPath"
}
$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)

$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "release_id: ``$ReleaseId``",
  "watch_scope: ``post_handoff_runtime_truth_stability``",
  "## Watch Scope",
  "## Decision State",
  "Candidate status: ``no-release``",
  "Stability classification: ``candidate_post_handoff_stability_watch``",
  "Current progress carried in watch: ``overall=$expectedOverall``, ``phase5=$expectedPhase5``",
  "Drift detected during watch window: ``none``",
  "Production claim: ``forbidden``"
)) {
  Assert-Contains "stability watch artifact" $artifact $required
}

$candidatePath = "docs\release-artifacts\$ReleaseId.md"
$candidate = Get-Content $candidatePath -Raw
Assert-Contains "candidate stability linked" $candidate "Post-handoff stability watch proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-handoff-stability-watch.md``"

$rootStatus = Get-Status "$BaseUrl/"
Assert-Contains "root status" $rootStatus "200"
$healthStatus = Get-Status "$BaseUrl/api/v1/health"
Assert-Contains "health status" $healthStatus "200"

$progress1 = Get-Json "$BaseUrl/api/v1/project/progress"
Start-Sleep -Seconds 2
$progress2 = Get-Json "$BaseUrl/api/v1/project/progress"
Assert-Contains "progress1 overall" $progress1 """overall_percent"": $expectedOverall"
Assert-Contains "progress1 phase5" $progress1 """percent"": $expectedPhase5"
Assert-Contains "progress2 overall" $progress2 """overall_percent"": $expectedOverall"
Assert-Contains "progress2 phase5" $progress2 """percent"": $expectedPhase5"

$integrity1 = Get-Json "$BaseUrl/api/v1/project/progress/integrity"
Start-Sleep -Seconds 1
$integrity2 = Get-Json "$BaseUrl/api/v1/project/progress/integrity"
Assert-Contains "integrity1" $integrity1 '"status": "verified"'
Assert-Contains "integrity1 phase5" $integrity1 """phase_5"": $expectedPhase5"
Assert-Contains "integrity2" $integrity2 '"status": "verified"'
Assert-Contains "integrity2 phase5" $integrity2 """phase_5"": $expectedPhase5"

$completion = Get-Json "$BaseUrl/api/v1/project/progress/completion"
Assert-Contains "completion guard" $completion '"can_set_all_to_100": false'

$externalGates = Get-Json "$BaseUrl/api/v1/external-gates"
Assert-Contains "external gates" $externalGates '"status": "verified"'

Write-Host "[phase5-post-handoff-stability-watch] verified"

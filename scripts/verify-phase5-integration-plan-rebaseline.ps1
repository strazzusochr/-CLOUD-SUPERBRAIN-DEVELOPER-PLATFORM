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
  if (-not $text.Contains($expected)) { throw "Verification failed: $label did not contain '$expected'." }
}
function Assert-Equal($label, $actual, $expected) {
  if ($actual -ne $expected) { throw "Verification failed: $label expected '$expected' but got '$actual'." }
}
function Get-Json($uri) {
  $content = @"
import urllib.request
with urllib.request.urlopen(r'''$uri''', timeout=30) as response:
    print(response.read().decode('utf-8'))
"@ | py -3 -
  return ($content | ConvertFrom-Json)
}
$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase4 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_4" }).percent)
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)
$artifactPath = "docs\release-artifacts\$ReleaseId-integration-plan-rebaseline.md"
$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "release_id: ``$ReleaseId``",
  'rollback_selector: `IMAGE_TAG=ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`',
  'current_selector: `IMAGE_TAG=staging`',
  "overall_percent: ``$expectedOverall``",
  "phase_4_percent: ``$expectedPhase4``",
  "phase_5_percent: ``$expectedPhase5``",
  'scripts\verify-phase5-executed-rollback.ps1'
)) { Assert-Contains "integration plan rebaseline artifact" $artifact $required }
$candidate = Get-Content "docs\release-artifacts\$ReleaseId.md" -Raw
Assert-Contains "candidate integration rebaseline reference linked" $candidate 'integration_plan_rebaseline_reference: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-plan-rebaseline.md`'
Assert-Contains "candidate evidence integration rebaseline reference linked" $candidate 'Historical integration plan rebaseline reference: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-plan-rebaseline.md`'
$progress = Get-Json "$BaseUrl/api/v1/project/progress"
$phase4 = $progress.horizontal.items | Where-Object { $_.id -eq "phase_4" } | Select-Object -First 1
$phase5 = $progress.horizontal.items | Where-Object { $_.id -eq "phase_5" } | Select-Object -First 1
Assert-Equal "hosted overall percent" $progress.overall_percent $expectedOverall
Assert-Equal "hosted phase4 percent" $phase4.percent $expectedPhase4
Assert-Equal "hosted phase5 percent" $phase5.percent $expectedPhase5
$integrity = Get-Json "$BaseUrl/api/v1/project/progress/integrity"
Assert-Equal "hosted integrity status" $integrity.status "verified"
$completion = Get-Json "$BaseUrl/api/v1/project/progress/completion"
if ($completion.can_set_all_to_100 -ne $false) { throw "Verification failed: completion gate must remain fail-closed." }
Write-Host "[phase5-integration-plan-rebaseline] verified"

param(
  [string]$ReleaseId = "prod-candidate-2026-05-05-rc1",
  [string]$BaseUrl = $(if ($env:STAGING_BASE_URL) { $env:STAGING_BASE_URL } else { "" }),
  [switch]$RequireLocal
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

function Get-Text($url) {
@"
import ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$url", context=ctx, timeout=20) as r:
    print(r.read().decode("utf-8", errors="replace"))
"@ | py -3 -
}

function Get-Json($url) {
@"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$url", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@ | py -3 -
}

$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)

$artifactPath = ".phase1-artifacts\phase5-final-browser-e2e-recheck-20260507.md"
$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "Candidate: ``$ReleaseId``",
  'Browser tool: `browser-use iab via mcp__node_repl__.js`',
  "Current progress reference: ``overall=$expectedOverall``, ``phase5=$expectedPhase5``",
  "Hosted URL: ``$($BaseUrl.TrimEnd('/') + '/')``",
  'Phase 5 - Release Readiness',
  'Progress Integrity',
  'Error Response Contract',
  'System Unavailable Fallback'
)) {
  Assert-Contains "final browser e2e artifact" $artifact $required
}
if ($RequireLocal) {
  Assert-Contains "final browser e2e artifact" $artifact 'Local URL: `http://localhost:8081/`'
}

$candidate = Get-Content "docs\release-artifacts\$ReleaseId.md" -Raw
Assert-Contains "candidate final browser field" $candidate 'final_browser_e2e_recheck_proof: `.phase1-artifacts/phase5-final-browser-e2e-recheck-20260507.md`'
Assert-Contains "candidate final browser evidence bullet" $candidate 'Final browser E2E recheck proof: `.phase1-artifacts/phase5-final-browser-e2e-recheck-20260507.md`'

$hostedHtml = Get-Text "$BaseUrl/"
if ($RequireLocal) {
  $localHtml = Get-Text "http://localhost:8081/"
}
foreach ($required in @(
  'Cloud Superbrain',
  'Project Progress',
  'External Gates',
  'Phase 5 - Release Readiness',
  'Progress Integrity',
  'Error Response Contract',
  'System Unavailable Fallback'
)) {
  if ($RequireLocal) {
    Assert-Contains "local html" $localHtml $required
  }
  Assert-Contains "hosted html" $hostedHtml $required
}

$progress = Get-Json "$BaseUrl/api/v1/project/progress"
Assert-Contains "hosted progress overall" $progress """overall_percent"": $expectedOverall"
Assert-Contains "hosted progress phase5" $progress """percent"": $expectedPhase5"
$integrity = Get-Json "$BaseUrl/api/v1/project/progress/integrity"
Assert-Contains "integrity" $integrity '"status": "verified"'

Write-Host "[phase5-final-browser-e2e-recheck] verified"

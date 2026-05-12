param(
  [string]$ReleaseId = "prod-candidate-2026-05-05-rc1",
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

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

function Get-Text($url) {
  @"
import ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$url", context=ctx, timeout=20) as r:
    print(r.read().decode("utf-8", errors="replace"))
"@ | py -3 -
}

$artifactPath = "docs\release-artifacts\prod-candidate-2026-05-05-rc1-browser-proof.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing browser proof artifact: $artifactPath"
}

$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "release_id: ``$ReleaseId``",
  'browser_tool: `browser-use iab via mcp__node_repl__.js`',
  'browser_bridge_scope: `sslip_io_hosted_staging_allowed`',
  'browser_logs_warnings_or_errors: `0`',
  'Title: `Cloud Superbrain`',
  "URL: ``$($BaseUrl.TrimEnd('/') + '/')``",
  'Phase 5 - Release Readiness',
  'Progress Integrity'
)) {
  Assert-Contains "browser proof artifact" $artifact $required
}

$candidatePath = "docs\release-artifacts\$ReleaseId.md"
if (-not (Test-Path $candidatePath)) {
  throw "Missing release artifact: $candidatePath"
}
$candidate = Get-Content $candidatePath -Raw
Assert-Contains "candidate browser status" $candidate 'browser_rerun_status: `verified via browser-use iab on 2026-05-07; current browser artifacts active candidate evidence`'
Assert-Contains "candidate browser proof field" $candidate 'browser_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md`'
Assert-Contains "candidate browser proof bullet" $candidate 'Browser proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md`'

$html = Get-Text "$BaseUrl/"
foreach ($required in @(
  '<title>Cloud Superbrain</title>',
  'Project Progress',
  'External Gates',
  'Phase 5 - Release Readiness',
  'Progress Integrity',
  'Error Response Contract',
  'System Unavailable Fallback'
)) {
  Assert-Contains "hosted html" $html $required
}

$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)
$progress = Get-Json "$BaseUrl/api/v1/project/progress"
Assert-Contains "hosted progress overall" $progress """overall_percent"": $expectedOverall"
Assert-Contains "hosted progress phase5" $progress """percent"": $expectedPhase5"
$integrity = Get-Json "$BaseUrl/api/v1/project/progress/integrity"
Assert-Contains "integrity" $integrity '"status": "verified"'

Write-Host "[phase5-browser-proof] live hosted browser evidence verified"

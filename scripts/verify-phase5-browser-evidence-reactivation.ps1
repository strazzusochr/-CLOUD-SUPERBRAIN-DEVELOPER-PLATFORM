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

$artifactPath = ".phase1-artifacts\phase5-browser-evidence-reactivation-20260507.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing browser evidence reactivation artifact: $artifactPath"
}
$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "Candidate: ``$ReleaseId``",
  'Browser tool: `browser-use iab via mcp__node_repl__.js`',
  "Hosted URL: ``$($BaseUrl.TrimEnd('/') + '/')``",
  'Phase 5 - Release Readiness',
  'Verified browser logs on the hosted run contained `0` warnings/errors.'
)) {
  Assert-Contains "browser evidence reactivation artifact" $artifact $required
}
if ($RequireLocal) {
  Assert-Contains "browser evidence reactivation artifact" $artifact 'Local URL: `http://localhost:8081/`'
}

$candidatePath = "docs\release-artifacts\$ReleaseId.md"
$candidate = Get-Content $candidatePath -Raw
foreach ($required in @(
  'browser_evidence_reactivation_proof: `.phase1-artifacts/phase5-browser-evidence-reactivation-20260507.md`',
  'browser_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md`',
  'post_rollback_browser_revalidation_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-browser-revalidation.md`',
  'browser_rerun_status: `verified via browser-use iab on 2026-05-07; current browser artifacts active candidate evidence`'
)) {
  Assert-Contains "candidate browser evidence reactivation" $candidate $required
}

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

Write-Host "[phase5-browser-evidence-reactivation] browser evidence reactivation verified"

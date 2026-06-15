param(
  [string]$ReleaseId = "prod-candidate-2026-05-05-rc1",
  [string]$BaseUrl = $(if ($env:STAGING_BASE_URL) { $env:STAGING_BASE_URL } else { "" })
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Verification failed: $label did not contain '$expected'."
  }
}

function Assert-NotContains($label, $value, $unexpected) {
  $text = ($value | Out-String)
  if ($text.Contains($unexpected)) {
    throw "Verification failed: $label unexpectedly contained '$unexpected'."
  }
}

function Assert-NotMatches($label, $value, $pattern) {
  $text = ($value | Out-String)
  if ($text -match $pattern) {
    throw "Verification failed: $label unexpectedly matched '$pattern'."
  }
}

function Assert-OptionalHostedBoundary {
  if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    return
  }
  if ($BaseUrl -notmatch '^https://') {
    throw "Hosted verifier requires an HTTPS BaseUrl when -BaseUrl is supplied."
  }
  if ($BaseUrl -match 'localhost|127\.0\.0\.1|\[::1\]|0\.0\.0\.0|host\.docker\.internal') {
    throw "Hosted verifier refuses localhost and loopback BaseUrl values."
  }
  if ($BaseUrl -match 'sslip\.io|188\.34\.191\.140|hetzner') {
    throw "Hosted verifier refuses retired sslip.io/Hetzner BaseUrl values."
  }
}
Assert-OptionalHostedBoundary

$artifactPath = "docs\release-artifacts\prod-candidate-2026-05-05-rc1-browser-proof.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing browser proof artifact: $artifactPath"
}

$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `superseded`',
  "release_id: ``$ReleaseId``",
  'historical_base_url: `https://188-34-191-140.sslip.io`',
  'retired_boundary: `sslip_io_hetzner`',
  'current_candidate_evidence: `false`',
  'current_hosted_gate_status: `blocked_pending_vercel_fly`',
  'browser_tool: `browser-use iab via mcp__node_repl__.js`',
  'browser_logs_warnings_or_errors: `0`',
  'Title: `Cloud Superbrain`',
  'URL: `https://188-34-191-140.sslip.io/`',
  'Phase 5 - Release Readiness',
  'Progress Integrity',
  'This is historical provenance only and does not close current hosted browser, staged, or external gates.'
)) {
  Assert-Contains "browser proof artifact" $artifact $required
}
Assert-NotContains "browser proof artifact" $artifact 'Status: `verified`'
Assert-NotContains "browser proof artifact" $artifact 'browser_bridge_scope: `sslip_io_hosted_staging_allowed`'

$candidatePath = "docs\release-artifacts\$ReleaseId.md"
if (-not (Test-Path $candidatePath)) {
  throw "Missing release artifact: $candidatePath"
}
$candidate = Get-Content $candidatePath -Raw
Assert-Contains "candidate browser status" $candidate 'browser_rerun_status: `superseded; historical sslip/Hetzner browser artifacts retained for provenance only; current browser evidence requires Vercel HTTPS STAGING_BASE_URL plus reachable Fly origins`'
Assert-Contains "candidate browser proof field" $candidate 'historical_browser_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md`'
Assert-Contains "candidate browser proof bullet" $candidate 'Historical browser proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md`'
Assert-NotMatches "candidate active browser field" $candidate '(?m)^browser_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof\.md`$'
Assert-NotContains "candidate active browser bullet" $candidate 'Browser proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md`'
Assert-NotContains "candidate active browser status" $candidate 'current browser artifacts active candidate evidence'

Write-Host "[phase5-browser-proof] historical browser proof retired; current hosted browser gate remains blocked"

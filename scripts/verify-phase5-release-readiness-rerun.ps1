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

$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase4 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_4" }).percent)
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)

$artifactPath = "docs\release-artifacts\prod-candidate-2026-05-05-rc1-release-readiness-rerun.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing release readiness rerun artifact: $artifactPath"
}
$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  "Status: ``verified``",
  "release_id: ``$ReleaseId``",
  "environment: ``production-candidate``",
  "overall_percent: ``$expectedOverall``",
  "phase_4_percent: ``$expectedPhase4``",
  "phase_5_percent: ``$expectedPhase5``",
  "integrity_status: ``verified``",
  "external_gates_status: ``verified``",
  "owner_decision: ``no-release``"
)) {
  Assert-Contains "release readiness rerun artifact" $artifact $required
}

$candidate = Get-Content "docs\release-artifacts\$ReleaseId.md" -Raw
Assert-Contains "candidate release readiness rerun linked" $candidate "release_readiness_rerun_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-release-readiness-rerun.md``"
Assert-Contains "candidate staging parity blocker linked" $candidate 'staging_tag_parity_blocked_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-staging-parity-blocked.md`'
Assert-Contains "candidate repo worktree parity blocker linked" $candidate 'repo_worktree_parity_blocked_proof: `.phase1-artifacts/phase5-repo-worktree-parity-blocked-20260507.md`'

$releaseChecklist = Get-Content "docs\release-checklist.md" -Raw
foreach ($required in @(
  "Code Readiness",
  "Infrastructure Readiness",
  "Observability Readiness",
  "Operations Readiness"
)) {
  Assert-Contains "release checklist" $releaseChecklist $required
}

foreach ($runbook in @(
  "docs\runbooks\rollback-deploy.md",
  "docs\runbooks\incident-response.md",
  "docs\runbooks\secret-rotation.md",
  "docs\runbooks\provider-failover.md",
  "docs\runbooks\memory-recovery.md"
)) {
  $text = Get-Content $runbook -Raw
  foreach ($required in @("## Trigger", "## Verifikation", "## Eskalation", "## Non-Claims")) {
    Assert-Contains $runbook $text $required
  }
}

$progress = Get-Json "$BaseUrl/api/v1/project/progress"
Assert-Contains "progress overall" $progress """overall_percent"": $expectedOverall"
Assert-Contains "progress phase5" $progress """percent"": $expectedPhase5"

$integrity = Get-Json "$BaseUrl/api/v1/project/progress/integrity"
Assert-Contains "integrity status" $integrity '"status": "verified"'

$completion = Get-Json "$BaseUrl/api/v1/project/progress/completion"
Assert-Contains "completion" $completion '"can_set_all_to_100": false'

$externalGates = Get-Json "$BaseUrl/api/v1/external-gates"
Assert-Contains "external gates" $externalGates '"status": "verified"'

foreach ($path in @(
  ".phase1-artifacts\phase5-browser-evidence-reactivation-20260507.md",
  "docs\release-artifacts\prod-candidate-2026-05-05-rc1-browser-proof.md",
  "docs\release-artifacts\prod-candidate-2026-05-05-rc1-post-rollback-browser-revalidation.md",
  ".phase1-artifacts\phase5-final-browser-e2e-recheck-20260507.md"
)) {
  if (-not (Test-Path $path)) {
    throw "Missing required browser evidence path: $path"
  }
}

Write-Host "[phase5-release-readiness-rerun] verified"

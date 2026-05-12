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
$artifactPath = "docs\release-artifacts\$ReleaseId-risk-review-recheck.md"
$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "release_id: ``$ReleaseId``",
  "overall_percent: ``$expectedOverall``",
  "phase_4_percent: ``$expectedPhase4``",
  "phase_5_percent: ``$expectedPhase5``",
  'Risk classification: `candidate_risk_review_recheck`',
  "Current progress carried in review: ``overall=$expectedOverall``, ``phase5=$expectedPhase5``",
  'Unexplained critical or high blocker: `none evidenced`',
  'Residual risk accepted for rollout: `no`'
)) { Assert-Contains "risk review recheck artifact" $artifact $required }

$candidate = Get-Content "docs\release-artifacts\$ReleaseId.md" -Raw
Assert-Contains "candidate risk recheck proof linked" $candidate 'risk_review_recheck_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-risk-review-recheck.md`'
Assert-Contains "candidate evidence risk recheck proof linked" $candidate 'Risk review recheck proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-risk-review-recheck.md`'

$progress = Get-Json "$BaseUrl/api/v1/project/progress"
$integrity = Get-Json "$BaseUrl/api/v1/project/progress/integrity"
$completion = Get-Json "$BaseUrl/api/v1/project/progress/completion"
$gates = Get-Json "$BaseUrl/api/v1/external-gates"
$audit = Get-Json "$BaseUrl/api/v1/audit/recent?limit=5"
$escalations = Get-Json "$BaseUrl/api/v1/escalations/recent?limit=5"

$phase4 = $progress.horizontal.items | Where-Object { $_.id -eq "phase_4" } | Select-Object -First 1
$phase5 = $progress.horizontal.items | Where-Object { $_.id -eq "phase_5" } | Select-Object -First 1

Assert-Equal "hosted overall percent" $progress.overall_percent $expectedOverall
Assert-Equal "hosted phase4 percent" $phase4.percent $expectedPhase4
Assert-Equal "hosted phase5 percent" $phase5.percent $expectedPhase5
Assert-Equal "hosted integrity status" $integrity.status "verified"
Assert-Equal "external gates status" $gates.status "verified"
if ($completion.can_set_all_to_100 -ne $false) { throw "Verification failed: completion gate must remain fail-closed." }
if (-not $audit.events) { throw "Verification failed: audit feed must remain reachable." }
if (-not $escalations.events) { throw "Verification failed: escalation feed must remain reachable." }

Write-Host "[phase5-risk-review-recheck] verified"

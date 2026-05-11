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
$artifactPath = "docs\release-artifacts\$ReleaseId-budget-review.md"
$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "release_id: ``$ReleaseId``",
  "overall_percent: ``$expectedOverall``",
  "phase_4_percent: ``$expectedPhase4``",
  "phase_5_percent: ``$expectedPhase5``",
  "Current progress carried in review: ``overall=$expectedOverall``, ``phase5=$expectedPhase5``",
  'budget_contract_version: `budget-surface-v1`',
  'infra_budget_contract_version: `infra-budget-surface-v1`',
  'Budget classification: `candidate_budget_review`',
  'Infrastructure budget remains within configured limit: `yes`'
)) { Assert-Contains "budget review artifact" $artifact $required }

$candidate = Get-Content "docs\release-artifacts\$ReleaseId.md" -Raw
Assert-Contains "candidate budget proof linked" $candidate 'budget_review_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-budget-review.md`'
Assert-Contains "candidate evidence budget proof linked" $candidate 'Budget review proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-budget-review.md`'

$budget = Get-Json "$BaseUrl/api/v1/budget"
$infra = Get-Json "$BaseUrl/api/v1/infra/budget"
$costs = Get-Json "$BaseUrl/api/v1/costs"
$gates = Get-Json "$BaseUrl/api/v1/external-gates"
$progress = Get-Json "$BaseUrl/api/v1/project/progress"
$integrity = Get-Json "$BaseUrl/api/v1/project/progress/integrity"

$phase4 = $progress.horizontal.items | Where-Object { $_.id -eq "phase_4" } | Select-Object -First 1
$phase5 = $progress.horizontal.items | Where-Object { $_.id -eq "phase_5" } | Select-Object -First 1

Assert-Equal "budget level" $budget.level "ok"
if ($budget.allow_new_calls -ne $true) { throw "Verification failed: call budget must allow new calls." }
Assert-Equal "infra level" $infra.level "ok"
if ($infra.allow_new_infra -ne $true) { throw "Verification failed: infra budget must allow new infra." }
if ($infra.live_verified -ne $true) { throw "Verification failed: infra budget must remain live verified." }
Assert-Equal "infra source" $infra.source "hetzner_api_readonly"
Assert-Equal "costs level" $costs.level "ok"
Assert-Equal "external gates status" $gates.status "verified"
Assert-Equal "hosted overall percent" $progress.overall_percent $expectedOverall
Assert-Equal "hosted phase4 percent" $phase4.percent $expectedPhase4
Assert-Equal "hosted phase5 percent" $phase5.percent $expectedPhase5
Assert-Equal "hosted integrity status" $integrity.status "verified"

Write-Host "[phase5-budget-review] verified"

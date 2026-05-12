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
$artifactPath = "docs\release-artifacts\$ReleaseId-open-questions-acceptance.md"
$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "release_id: ``$ReleaseId``",
  "overall_percent: ``$expectedOverall``",
  "phase_4_percent: ``$expectedPhase4``",
  "phase_5_percent: ``$expectedPhase5``",
  'Acceptance classification: `candidate_open_questions_acceptance`',
  "Current progress carried in review: ``overall=$expectedOverall``, ``phase5=$expectedPhase5``",
  'Open questions accepted for rollout: `no`',
  'Open questions accepted for continued staging evidence work: `yes`'
)) { Assert-Contains "open questions artifact" $artifact $required }

$candidate = Get-Content "docs\release-artifacts\$ReleaseId.md" -Raw
Assert-Contains "candidate open questions proof linked" $candidate 'open_questions_acceptance_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-open-questions-acceptance.md`'
Assert-Contains "candidate evidence open questions proof linked" $candidate 'Open questions acceptance proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-open-questions-acceptance.md`'
Assert-Contains "candidate checklist open questions item" $candidate '- [x] Release-relevant open questions explicitly accepted for this candidate'
Assert-Contains "candidate owner decision" $candidate 'owner_decision: `no-release`'

$progress = Get-Json "$BaseUrl/api/v1/project/progress"
$completion = Get-Json "$BaseUrl/api/v1/project/progress/completion"
$gates = Get-Json "$BaseUrl/api/v1/external-gates"
$integrity = Get-Json "$BaseUrl/api/v1/project/progress/integrity"

$phase4 = $progress.horizontal.items | Where-Object { $_.id -eq "phase_4" } | Select-Object -First 1
$phase5 = $progress.horizontal.items | Where-Object { $_.id -eq "phase_5" } | Select-Object -First 1

Assert-Equal "hosted overall percent" $progress.overall_percent $expectedOverall
Assert-Equal "hosted phase4 percent" $phase4.percent $expectedPhase4
Assert-Equal "hosted phase5 percent" $phase5.percent $expectedPhase5
Assert-Equal "hosted integrity status" $integrity.status "verified"
Assert-Equal "external gates status" $gates.status "verified"
if ($completion.can_set_all_to_100 -ne $false) { throw "Verification failed: completion gate must remain fail-closed." }

Write-Host "[phase5-open-questions-acceptance] verified"

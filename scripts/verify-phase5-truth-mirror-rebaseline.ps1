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

$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)

$artifactPath = ".phase1-artifacts\phase5-truth-mirror-rebaseline-20260507.md"
$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "Candidate: ``$ReleaseId``",
  "Current progress reference: ``overall=$expectedOverall``, ``phase5=$expectedPhase5``",
  'docs/project-progress.manifest.json',
  'docs/verification-register.md',
  'PROJECT_STATE.md',
  'AI_HANDOFF.md',
  'docs/release-artifacts/prod-candidate-2026-05-05-rc1.md'
)) {
  Assert-Contains "truth mirror rebaseline artifact" $artifact $required
}

$candidate = Get-Content "docs\release-artifacts\$ReleaseId.md" -Raw
Assert-Contains "candidate truth mirror field" $candidate 'truth_mirror_rebaseline_proof: `.phase1-artifacts/phase5-truth-mirror-rebaseline-20260507.md`'
Assert-Contains "candidate truth mirror evidence bullet" $candidate 'Truth mirror rebaseline proof: `.phase1-artifacts/phase5-truth-mirror-rebaseline-20260507.md`'

$handoff = Get-Content "AI_HANDOFF.md" -Raw
$projectState = Get-Content "PROJECT_STATE.md" -Raw
$register = Get-Content "docs\verification-register.md" -Raw
Assert-Contains "handoff overall" $handoff ("Overall: ``{0}%``" -f $expectedOverall)
Assert-Contains "handoff phase5" $handoff ("P5: ``{0}%``" -f $expectedPhase5)
Assert-Contains "project state overall" $projectState ("## AKTUELLER FORTSCHRITT: {0}%" -f $expectedOverall)
Assert-Contains "project state phase5" $projectState ("| P5   | {0}%" -f $expectedPhase5)
Assert-Contains "verification register authority overall" $register ("Current verified progress is total ``{0}%``" -f $expectedOverall)
Assert-Contains "verification register authority phase5" $register ("Phase 5 ``{0}%``" -f $expectedPhase5)
Assert-Contains "handoff active browser evidence" $handoff 'phase5-final-browser-e2e-recheck-20260507.md'
Assert-Contains "project state active browser evidence" $projectState 'phase5-final-browser-e2e-recheck-20260507.md'
Assert-Contains "handoff repo parity blocker" $handoff 'last fully verified candidate remains `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`'
Assert-Contains "project state repo parity blocker" $projectState 'aktuell blockierter Repo-Worktree-Paritaet'

$progress = Get-Json "$BaseUrl/api/v1/project/progress"
Assert-Contains "hosted progress overall" $progress """overall_percent"": $expectedOverall"
Assert-Contains "hosted progress phase5" $progress """percent"": $expectedPhase5"

Write-Host "[phase5-truth-mirror-rebaseline] verified"

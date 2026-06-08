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

function Invoke-Python($code) {
@"
$code
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

$artifactPath = "docs\release-artifacts\prod-candidate-2026-05-05-rc1-handoff-packet.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing handoff packet artifact: $artifactPath"
}
$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)

$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "release_id: ``$ReleaseId``",
  "packet_scope: ``release communication and operator handoff``",
  "## Packet Contents",
  "## Communication State",
  "Candidate status: ``no-release``",
  "Progress state carried in packet: ``overall=$expectedOverall``, ``phase5=$expectedPhase5``",
  "Production claim: ``forbidden``",
  "This is not a production rollout packet."
)) {
  Assert-Contains "handoff packet artifact" $artifact $required
}

foreach ($requiredPath in @(
  "AI_HANDOFF.md",
  "PROJECT_STATE.md",
  "docs\verification-register.md",
  "docs\project-progress.manifest.json",
  "docs\release-artifacts\prod-candidate-2026-05-05-rc1.md",
  ".phase1-artifacts\phase5-rollback-drill-prod-candidate-20260505-rc1.md",
  ".phase1-artifacts\phase5-owner-decision-no-release-20260505.md"
)) {
  if (-not (Test-Path $requiredPath)) {
    throw "Missing handoff packet file: $requiredPath"
  }
}

$candidatePath = "docs\release-artifacts\$ReleaseId.md"
$candidate = Get-Content $candidatePath -Raw
Assert-Contains "candidate handoff linked" $candidate "Handoff packet proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-handoff-packet.md``"

$handoff = Get-Content "AI_HANDOFF.md" -Raw
Assert-Contains "handoff current overall" $handoff "Overall: ``$expectedOverall%``"
Assert-Contains "handoff current p5" $handoff "- P5: ``$expectedPhase5%``"

$projectState = Get-Content "PROJECT_STATE.md" -Raw
Assert-Contains "project state overall" $projectState "## AKTUELLER FORTSCHRITT: $expectedOverall%"
Assert-Contains "project state p5 row" $projectState "| P5   | $expectedPhase5%    |"

$register = Get-Content "docs\verification-register.md" -Raw
Assert-Contains "register current p5" $register "Phase 5 ``$expectedPhase5%``"
Assert-Contains "register handoff packet entry" $register "prod-candidate-2026-05-05-rc1-handoff-packet.md"

$progress = Get-Json "$BaseUrl/api/v1/project/progress"
Assert-Contains "progress overall" $progress """overall_percent"": $expectedOverall"
Assert-Contains "progress phase5" $progress """percent"": $expectedPhase5"

$integrity = Get-Json "$BaseUrl/api/v1/project/progress/integrity"
Assert-Contains "integrity" $integrity '"status": "verified"'
Assert-Contains "integrity phase5" $integrity """phase_5"": $expectedPhase5"

Write-Host "[phase5-handoff-packet] verified"

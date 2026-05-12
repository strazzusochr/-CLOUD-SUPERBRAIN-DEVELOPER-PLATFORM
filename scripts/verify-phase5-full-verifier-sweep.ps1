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

$artifactPath = ".phase1-artifacts\phase5-full-verifier-sweep-20260507.md"
$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "Candidate: ``$ReleaseId``",
  "Current progress reference: ``overall=$expectedOverall``, ``phase5=$expectedPhase5``",
  'full `verify-phase5*.ps1` sweep: `passed`',
  '`verify-phase1.ps1`: `passed`',
  '`gitleaks`: `no leaks found`'
)) {
  Assert-Contains "full verifier sweep artifact" $artifact $required
}

$candidate = Get-Content "docs\release-artifacts\$ReleaseId.md" -Raw
Assert-Contains "candidate full sweep field" $candidate 'full_verifier_sweep_proof: `.phase1-artifacts/phase5-full-verifier-sweep-20260507.md`'
Assert-Contains "candidate full sweep evidence bullet" $candidate 'Full verifier sweep proof: `.phase1-artifacts/phase5-full-verifier-sweep-20260507.md`'
Assert-Contains "candidate staging parity blocker field" $candidate 'staging_tag_parity_blocked_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-staging-parity-blocked.md`'
Assert-Contains "candidate staging parity blocker evidence bullet" $candidate 'Staging tag parity blocked proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-staging-parity-blocked.md`'
Assert-Contains "candidate repo parity blocker field" $candidate 'repo_worktree_parity_blocked_proof: `.phase1-artifacts/phase5-repo-worktree-parity-blocked-20260507.md`'
Assert-Contains "candidate repo parity blocker evidence bullet" $candidate 'Repo worktree parity blocked proof: `.phase1-artifacts/phase5-repo-worktree-parity-blocked-20260507.md`'

$phase5Scripts = Get-ChildItem "scripts\verify-phase5*.ps1"
if ($phase5Scripts.Count -lt 10) {
  throw "Verification failed: expected a full phase5 verifier set."
}

$progress = Get-Json "$BaseUrl/api/v1/project/progress"
Assert-Contains "hosted progress overall" $progress """overall_percent"": $expectedOverall"
Assert-Contains "hosted progress phase5" $progress """percent"": $expectedPhase5"
$integrity = Get-Json "$BaseUrl/api/v1/project/progress/integrity"
Assert-Contains "integrity" $integrity '"status": "verified"'

Write-Host "[phase5-full-verifier-sweep] verified"

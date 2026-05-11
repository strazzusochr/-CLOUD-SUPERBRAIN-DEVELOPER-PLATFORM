param(
  [string]$ReleaseId = "prod-candidate-2026-05-05-rc1"
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Verification failed: $label did not contain '$expected'."
  }
}

$artifactPath = ".phase1-artifacts\phase5-repo-worktree-parity-blocked-20260507.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing repo worktree parity blocker artifact: $artifactPath"
}

$candidate = Get-Content "docs\release-artifacts\$ReleaseId.md" -Raw
if ($candidate -match 'source_commit_sha: `([^`]+)`') {
  $candidateSha = $Matches[1]
} else {
  throw "Verification failed: candidate artifact missing source_commit_sha."
}

$headSha = (git rev-parse HEAD).Trim()
$dirty = (git status --short | Out-String).Trim()
if (-not $dirty) {
  throw "Verification failed: worktree is clean; repo parity blocker should be retired or rewritten."
}
if ($headSha -eq $candidateSha) {
  throw "Verification failed: HEAD already equals candidate SHA; repo parity blocker should be retired or rewritten."
}

$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)

$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `blocked`',
  "release_id: ``$ReleaseId``",
  "candidate_source_commit_sha: ``$candidateSha``",
  "current_repo_head_sha: ``$headSha``",
  'worktree_dirty: `yes`',
  "overall_percent: ``$expectedOverall``",
  "phase_5_percent: ``$expectedPhase5``",
  'owner_decision: `no-release`',
  'parity_classification: `blocked_candidate_worktree_parity`',
  'Current repo/head parity to the candidate remains blocked: `yes`'
)) {
  Assert-Contains "repo worktree parity blocker artifact" $artifact $required
}

Write-Host "[phase5-repo-worktree-parity-blocked] verified"

param(
  [string]$ReleaseId = "",
  [string]$CurrentReleaseCandidatePath = "docs\release-artifacts\current-release-candidate.json",
  [string]$OutputPath = ".phase1-artifacts\worktree-release-boundary-20260510.json",
  [switch]$ReportOnly,
  [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"

function Get-CandidateField([string]$Content, [string]$Name) {
  $pattern = "(?m)^$([regex]::Escape($Name)):\s*``([^``]+)``\s*$"
  if ($Content -match $pattern) {
    return $Matches[1]
  }
  return ""
}

function Convert-GitStatusLine([string]$Line) {
  if ([string]::IsNullOrWhiteSpace($Line) -or $Line.Length -lt 3) {
    return $null
  }

  $indexStatus = $Line.Substring(0, 1)
  $worktreeStatus = $Line.Substring(1, 1)
  $path = $Line.Substring(3)
  $path = $path -replace '\\', '/'
  $staged = ($indexStatus -ne " " -and $indexStatus -ne "?")
  $unstaged = ($worktreeStatus -ne " " -and $worktreeStatus -ne "?")
  $untracked = ($indexStatus -eq "?" -and $worktreeStatus -eq "?")

  return [pscustomobject]@{
    raw = $Line
    index_status = $indexStatus
    worktree_status = $worktreeStatus
    path = $path
    staged = $staged
    unstaged = $unstaged
    untracked = $untracked
    staged_and_modified = ($staged -and $unstaged)
  }
}

function Test-RiskyArtifactPath([string]$Path) {
  $normalized = $Path -replace '\\', '/'
  $patterns = @(
    '(^|/)vercel_storage\.json$',
    '(^|/)hetzner_.*\.(json|png|html)$',
    '(^|/)cf_.*\.(png|html)$',
    '(^|/)github_.*\.(png|html)$',
    '(^|/)gitlab_.*\.(png|html)$',
    '(^|/)vercel_.*\.(png|html)$',
    '(^|/)debug-artifacts/',
    '(^|/)\.secrets\.baseline$',
    '(^|/).*token.*\.(txt|png|html|json)$',
    '(^|/).*tokens.*\.(txt|png|html|json)$',
    '(^|/).*secret.*\.(txt|env|json)$',
    '(^|/).*\.local\.env$'
  )

  foreach ($pattern in $patterns) {
    if ($normalized -match $pattern) {
      return $true
    }
  }
  return $false
}

function Resolve-ReleaseId([string]$ExplicitReleaseId, [string]$ConfigPath) {
  if (-not [string]::IsNullOrWhiteSpace($ExplicitReleaseId)) {
    return $ExplicitReleaseId
  }

  if (Test-Path -LiteralPath $ConfigPath) {
    $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    if (-not [string]::IsNullOrWhiteSpace([string]$config.active_release_id)) {
      return [string]$config.active_release_id
    }
  }

  return "prod-candidate-2026-05-05-rc1"
}

function Test-ReleaseMetadataPath([string]$Path) {
  $normalized = $Path -replace '\\', '/'
  if ($normalized -like "docs/release-artifacts/*") {
    return $true
  }
  if ($normalized -eq "docs/analysis/release-rebaseline-decision-20260511.json") {
    return $true
  }
  if ($normalized -like "docs/analysis/*REVIEW*2026-05-*.md" -or $normalized -like "docs/analysis/*RUNBOOK*2026-05-*.md") {
    return $true
  }
  if ($normalized -like "docs/CLOUD_TRUTH_2026-05-*.md") {
    return $true
  }
  if ($normalized -like "scripts/verify-*.ps1") {
    return $true
  }
  return $false
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  $resolvedReleaseId = Resolve-ReleaseId -ExplicitReleaseId $ReleaseId -ConfigPath $CurrentReleaseCandidatePath
  $candidatePath = Join-Path "docs\release-artifacts" "$resolvedReleaseId.md"
  if (-not (Test-Path -LiteralPath $candidatePath)) {
    throw "Missing release candidate artifact: $candidatePath"
  }

  $candidate = Get-Content -LiteralPath $candidatePath -Raw
  $candidateSha = Get-CandidateField -Content $candidate -Name "source_commit_sha"
  $ownerDecision = Get-CandidateField -Content $candidate -Name "owner_decision"
  if ([string]::IsNullOrWhiteSpace($candidateSha)) {
    throw "Release candidate artifact does not declare source_commit_sha."
  }

  $headSha = (git rev-parse HEAD).Trim()
  $statusLines = @(git status --porcelain=v1)
  $entries = @()
  foreach ($line in $statusLines) {
    $entry = Convert-GitStatusLine -Line $line
    if ($null -ne $entry) {
      $entries += $entry
    }
  }

  $stagedEntries = @($entries | Where-Object { $_.staged })
  $unstagedEntries = @($entries | Where-Object { $_.unstaged })
  $untrackedEntries = @($entries | Where-Object { $_.untracked })
  $doubleModifiedEntries = @($entries | Where-Object { $_.staged_and_modified })
  $riskyEntries = @($entries | Where-Object { Test-RiskyArtifactPath -Path $_.path })

  $headExactlyMatchesCandidate = ($headSha -eq $candidateSha)
  $candidateIsAncestorOfHead = $false
  $metadataDeltaPaths = @()
  $nonMetadataDeltaPaths = @()
  $releaseMetadataOnlyDelta = $false
  if (-not $headExactlyMatchesCandidate) {
    $global:LASTEXITCODE = 0
    git merge-base --is-ancestor $candidateSha HEAD 2>$null
    $candidateIsAncestorOfHead = ($LASTEXITCODE -eq 0)
    if ($candidateIsAncestorOfHead) {
      $metadataDeltaPaths = @(git diff --name-only "$candidateSha..HEAD" | ForEach-Object { $_ -replace '\\', '/' })
      $nonMetadataDeltaPaths = @($metadataDeltaPaths | Where-Object { -not (Test-ReleaseMetadataPath -Path ([string]$_)) })
      $releaseMetadataOnlyDelta = ($metadataDeltaPaths.Count -gt 0 -and $nonMetadataDeltaPaths.Count -eq 0)
    }
  }

  $headMatchesCandidate = ($headExactlyMatchesCandidate -or $releaseMetadataOnlyDelta)
  $worktreeClean = ($entries.Count -eq 0)
  $ownerApproved = ($ownerDecision -eq "approved")
  $releaseBoundaryClear = ($headMatchesCandidate -and $worktreeClean -and $ownerApproved)

  $blockers = [System.Collections.Generic.List[string]]::new()
  if (-not $headMatchesCandidate) {
    $blockers.Add("current_head_does_not_match_candidate_source_sha")
  }
  if (-not $worktreeClean) {
    $blockers.Add("worktree_is_dirty")
  }
  if ($stagedEntries.Count -gt 0) {
    $blockers.Add("staged_changes_present")
  }
  if ($unstagedEntries.Count -gt 0) {
    $blockers.Add("unstaged_changes_present")
  }
  if ($untrackedEntries.Count -gt 0) {
    $blockers.Add("untracked_files_present")
  }
  if ($doubleModifiedEntries.Count -gt 0) {
    $blockers.Add("same_files_are_staged_and_modified")
  }
  if ($riskyEntries.Count -gt 0) {
    $blockers.Add("sensitive_or_debug_artifact_paths_present")
  }
  if (-not $ownerApproved) {
    $blockers.Add("owner_decision_not_approved_in_candidate_artifact")
  }

  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    release_id = $resolvedReleaseId
    active_release_candidate_config = $CurrentReleaseCandidatePath
    candidate_artifact = $candidatePath
    candidate_source_sha = $candidateSha
    current_head_sha = $headSha
    head_matches_candidate = $headMatchesCandidate
    head_exactly_matches_candidate_source = $headExactlyMatchesCandidate
    candidate_source_is_ancestor_of_head = $candidateIsAncestorOfHead
    release_metadata_only_delta = $releaseMetadataOnlyDelta
    owner_decision = $ownerDecision
    owner_approved = $ownerApproved
    worktree_clean = $worktreeClean
    release_boundary_clear = $releaseBoundaryClear
    status = if ($releaseBoundaryClear) { "ready" } else { "blocked" }
    blockers = @($blockers)
    counts = [ordered]@{
      total_status_entries = $entries.Count
      staged = $stagedEntries.Count
      unstaged = $unstagedEntries.Count
      untracked = $untrackedEntries.Count
      staged_and_modified = $doubleModifiedEntries.Count
      risky_artifact_paths = $riskyEntries.Count
    }
    staged_and_modified_paths = @($doubleModifiedEntries | Select-Object -ExpandProperty path)
    risky_artifact_paths = @($riskyEntries | Select-Object -ExpandProperty path)
    metadata_delta_paths = @($metadataDeltaPaths)
    non_metadata_delta_paths = @($nonMetadataDeltaPaths)
    staged_paths = @($stagedEntries | Select-Object -ExpandProperty path)
    unstaged_paths_sample = @($unstagedEntries | Select-Object -First 30 -ExpandProperty path)
    untracked_paths_sample = @($untrackedEntries | Select-Object -First 50 -ExpandProperty path)
    policy = [ordered]@{
      may_stage_or_commit = $releaseBoundaryClear
      may_release = $releaseBoundaryClear
      may_deploy_production = $false
      required_next_action = if ($releaseBoundaryClear) { "run release-candidate gate bundle before any deploy claim" } else { "choose rebaseline or cleanup strategy; do not stage, commit, push, or deploy as release truth" }
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $outputParent = Split-Path $OutputPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($outputParent)) {
      New-Item -ItemType Directory -Force -Path $outputParent | Out-Null
    }
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
  }

  if ($JsonOnly) {
    $summary | ConvertTo-Json -Depth 8
  } else {
    Write-Host "[worktree-release-boundary] status=$($summary.status)"
    Write-Host "[worktree-release-boundary] release_boundary_clear=$($summary.release_boundary_clear)"
    Write-Host "[worktree-release-boundary] head_matches_candidate=$($summary.head_matches_candidate)"
    Write-Host "[worktree-release-boundary] worktree_clean=$($summary.worktree_clean)"
    Write-Host "[worktree-release-boundary] owner_decision=$($summary.owner_decision)"
    Write-Host "[worktree-release-boundary] counts total=$($summary.counts.total_status_entries) staged=$($summary.counts.staged) unstaged=$($summary.counts.unstaged) untracked=$($summary.counts.untracked) staged_and_modified=$($summary.counts.staged_and_modified) risky=$($summary.counts.risky_artifact_paths)"
    Write-Host "[worktree-release-boundary] blockers=$($summary.blockers -join ',')"
  }

  if (-not $releaseBoundaryClear -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}

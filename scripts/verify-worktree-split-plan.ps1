param(
  [string]$QuarantinePlanPath = ".phase1-artifacts\worktree-quarantine-plan-20260510.json",
  [string]$ReleaseBoundaryPath = ".phase1-artifacts\worktree-release-boundary-20260510.json",
  [string]$OwnerDecisionPath = "docs\analysis\worktree-owner-decision-20260510.json",
  [string]$OutputPath = ".phase1-artifacts\worktree-split-plan-20260510.json",
  [switch]$ReportOnly,
  [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"

function Read-JsonArtifact([string]$Path, [string]$Label) {
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Missing $Label artifact: $Path"
  }

  return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

function Invoke-DependencyVerifier([string]$ScriptName, [string]$OutputPath) {
  if (Test-Path -LiteralPath $OutputPath) {
    return
  }

  $scriptPath = Join-Path $PSScriptRoot $ScriptName
  if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Missing dependency verifier: $ScriptName"
  }

  & $scriptPath -ReportOnly -OutputPath $OutputPath | Out-Null
}

function Normalize-RepoPath([string]$Path) {
  return ($Path -replace '\\', '/')
}

function Add-Path([hashtable]$PathSet, [string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path)) {
    return
  }

  $normalized = Normalize-RepoPath -Path $Path
  if (-not $PathSet.ContainsKey($normalized)) {
    $PathSet[$normalized] = $true
  }
}

function New-SplitAction([string]$Path) {
  return [pscustomobject]@{
    path = $Path
    review_type = "split-required"
    current_issue = "path has staged changes and additional unstaged worktree changes"
    inspect_staged_command = "git diff --cached -- '$Path'"
    inspect_worktree_command = "git diff -- '$Path'"
    normalize_command_example = "git restore --staged -- '$Path'"
    restage_after_review_command_example = "git add -- '$Path'"
    executable_by_this_verifier = $false
    requires_owner_decision = $true
    required_gate = "git status --short must show no staged-and-modified entry for this path"
    content_included_in_artifact = $false
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  Invoke-DependencyVerifier -ScriptName "verify-worktree-quarantine-plan.ps1" -OutputPath $QuarantinePlanPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-release-boundary.ps1" -OutputPath $ReleaseBoundaryPath

  $quarantinePlan = Read-JsonArtifact -Path $QuarantinePlanPath -Label "quarantine-plan"
  $releaseBoundary = Read-JsonArtifact -Path $ReleaseBoundaryPath -Label "release-boundary"

  $splitPathSet = @{}
  foreach ($item in @($quarantinePlan.split_required_actions)) {
    Add-Path -PathSet $splitPathSet -Path ([string]$item.path)
  }
  foreach ($path in @($releaseBoundary.staged_and_modified_paths)) {
    Add-Path -PathSet $splitPathSet -Path ([string]$path)
  }

  $splitPaths = @($splitPathSet.Keys | Sort-Object)
  $actions = @()
  foreach ($path in $splitPaths) {
    $actions += New-SplitAction -Path $path
  }

  $clear = ($actions.Count -eq 0)
  $ownerDecisionPresent = Test-Path -LiteralPath $OwnerDecisionPath
  $blockers = @()
  if (-not $clear) {
    $blockers += "staged_and_modified_paths_present"
    if ($ownerDecisionPresent) {
      $blockers += "worktree_split_normalization_required"
    } else {
      $blockers += "worktree_split_plan_requires_owner_decision"
    }
  }

  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    status = if ($clear) { "split-plan-clear" } else { "split-plan-blocked" }
    clear = $clear
    quarantine_plan_path = $QuarantinePlanPath
    release_boundary_path = $ReleaseBoundaryPath
    owner_decision_path = $OwnerDecisionPath
    owner_decision_present = $ownerDecisionPresent
    blockers = @($blockers)
    split_path_count = $actions.Count
    split_paths = $splitPaths
    actions = @($actions)
    counts = [ordered]@{
      quarantine_split_required = [int]$quarantinePlan.counts.split_required
      release_boundary_staged_and_modified = [int]$releaseBoundary.counts.staged_and_modified
      planned_split_actions = [int]$actions.Count
    }
    required_next_action = if ($clear) {
      "No staged-and-modified paths are present."
    } else {
      "Inspect staged and worktree diffs path-by-path, then use an owner-approved normalization path before any commit boundary."
    }
    policy = [ordered]@{
      mutates_repository = $false
      executes_requested_actions = $false
      script_supports_execution = $false
      may_unstage = $false
      may_stage = $false
      may_commit = $false
      may_push = $false
      may_deploy = $false
      may_release = $false
    }
    leak_prevention = [ordered]@{
      file_contents_included = $false
      diff_contents_included = $false
      secret_values_included = $false
      tokens_included = $false
      env_values_included = $false
      path_only_artifact = $true
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
    Write-Host "[worktree-split-plan] status=$($summary.status)"
    Write-Host "[worktree-split-plan] clear=$($summary.clear)"
    Write-Host "[worktree-split-plan] split_path_count=$($summary.split_path_count)"
    Write-Host "[worktree-split-plan] blockers=$($summary.blockers -join ',')"
  }

  if (-not $clear -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}

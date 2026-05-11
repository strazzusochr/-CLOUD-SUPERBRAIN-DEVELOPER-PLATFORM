param(
  [string]$CleanupPlanPath = ".phase1-artifacts\worktree-cleanup-plan-20260510.json",
  [string]$OutputPath = ".phase1-artifacts\worktree-quarantine-plan-20260510.json",
  [string]$QuarantineRoot = "debug-artifacts\quarantine\2026-05-10",
  [switch]$ReportOnly,
  [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"

function Get-BatchPaths([object]$Plan, [string]$Id) {
  $batch = $Plan.batches | Where-Object { $_.id -eq $Id } | Select-Object -First 1
  if ($null -eq $batch) {
    return @()
  }
  return @($batch.paths)
}

function Convert-ToForwardSlash([string]$Path) {
  return ($Path -replace '\\', '/')
}

function New-QuarantineAction([string]$Path, [string]$Root) {
  $normalized = Convert-ToForwardSlash -Path $Path
  $destinationRoot = Convert-ToForwardSlash -Path $Root

  return [pscustomobject]@{
    path = $normalized
    proposed_destination = "$destinationRoot/$normalized"
    action = "owner_decision_required_before_move_or_exclusion"
    default_policy = "exclude_from_release_scope_unless_explicitly_accepted"
    mutates_repository = $false
  }
}

function New-ReviewAction([string]$Path, [string]$ReviewType, [string]$Action, [string]$Gate) {
  return [pscustomobject]@{
    path = (Convert-ToForwardSlash -Path $Path)
    review_type = $ReviewType
    action = $Action
    gate = $Gate
    content_included_in_artifact = $false
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  if (-not (Test-Path -LiteralPath $CleanupPlanPath)) {
    & (Join-Path $PSScriptRoot "verify-worktree-cleanup-plan.ps1") -ReportOnly -OutputPath $CleanupPlanPath | Out-Null
  }

  if (-not (Test-Path -LiteralPath $CleanupPlanPath)) {
    throw "Missing worktree cleanup plan artifact: $CleanupPlanPath"
  }

  $cleanupPlan = Get-Content -LiteralPath $CleanupPlanPath -Raw | ConvertFrom-Json
  $securityPaths = @(Get-BatchPaths -Plan $cleanupPlan -Id "security-review")
  $quarantinePaths = @(Get-BatchPaths -Plan $cleanupPlan -Id "exclude-or-quarantine")
  $splitRequiredPaths = @(Get-BatchPaths -Plan $cleanupPlan -Id "split-required")

  $quarantineActions = @(
    $quarantinePaths | ForEach-Object {
      New-QuarantineAction -Path $_ -Root $QuarantineRoot
    }
  )

  $securityReviewActions = @(
    $securityPaths | ForEach-Object {
      New-ReviewAction `
        -Path $_ `
        -ReviewType "security-review" `
        -Action "manual_secret_sensitive_review_before_stage_or_commit" `
        -Gate "security suite clean after review; no secret values in diff or artifacts"
    }
  )

  $splitReviewActions = @(
    $splitRequiredPaths | ForEach-Object {
      New-ReviewAction `
        -Path $_ `
        -ReviewType "split-required" `
        -Action "normalize_staged_and_worktree_versions_before_commit_boundary" `
        -Gate "git status must show no staged-and-modified MM entries"
    }
  )

  $blocked = (($securityPaths.Count + $quarantinePaths.Count + $splitRequiredPaths.Count) -gt 0)
  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    cleanup_plan_path = $CleanupPlanPath
    status = if ($blocked) { "quarantine-plan-blocked" } else { "clear" }
    recommended_first_strategy = if ($blocked) { "cleanup-first-before-rebaseline" } else { "none" }
    counts = [ordered]@{
      security_review = $securityPaths.Count
      exclude_or_quarantine = $quarantinePaths.Count
      split_required = $splitRequiredPaths.Count
      total_blocking_review_items = ($securityPaths.Count + $quarantinePaths.Count + $splitRequiredPaths.Count)
    }
    quarantine_actions = $quarantineActions
    security_review_actions = $securityReviewActions
    split_required_actions = $splitReviewActions
    release_gates = @(
      "security-review paths require manual review and clean security suite before staging",
      "exclude-or-quarantine paths require owner decision before release scope inclusion",
      "split-required paths require staged/worktree normalization before commit boundary",
      "release-boundary suite must pass after any cleanup or rebaseline"
    )
    leak_prevention = [ordered]@{
      file_contents_included = $false
      secret_values_included = $false
      tokens_included = $false
      env_values_included = $false
      path_only_artifact = $true
    }
    policy = [ordered]@{
      mutates_repository = $false
      may_create_quarantine_directory = $false
      may_move = $false
      may_delete = $false
      may_unstage = $false
      may_stage = $false
      may_commit = $false
      may_push = $false
      may_deploy = $false
      required_next_action = "Owner must choose cleanup-first, evidence-only-rebaseline, or runtime-rebaseline before repository mutation."
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $outputParent = Split-Path $OutputPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($outputParent)) {
      New-Item -ItemType Directory -Force -Path $outputParent | Out-Null
    }
    $summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
  }

  if ($JsonOnly) {
    $summary | ConvertTo-Json -Depth 10
  } else {
    Write-Host "[worktree-quarantine-plan] status=$($summary.status)"
    Write-Host "[worktree-quarantine-plan] security_review=$($summary.counts.security_review)"
    Write-Host "[worktree-quarantine-plan] exclude_or_quarantine=$($summary.counts.exclude_or_quarantine)"
    Write-Host "[worktree-quarantine-plan] split_required=$($summary.counts.split_required)"
    Write-Host "[worktree-quarantine-plan] mutates_repository=$($summary.policy.mutates_repository)"
  }

  if ($blocked -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}

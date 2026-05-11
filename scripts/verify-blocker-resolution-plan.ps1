param(
  [string]$InventoryPath = ".phase1-artifacts\worktree-change-inventory-20260510.json",
  [string]$QuarantinePlanPath = ".phase1-artifacts\worktree-quarantine-plan-20260510.json",
  [string]$OwnerDecisionPath = ".phase1-artifacts\worktree-owner-decision-20260510.json",
  [string]$SplitPlanPath = ".phase1-artifacts\worktree-split-plan-20260510.json",
  [string]$CleanupExecutionPlanPath = ".phase1-artifacts\worktree-cleanup-execution-plan-20260510.json",
  [string]$OwnerDecisionPacketPath = ".phase1-artifacts\worktree-owner-decision-packet-20260510.json",
  [string]$SecurityReviewActionPacketPath = ".phase1-artifacts\worktree-security-review-action-packet-20260511.json",
  [string]$ReleaseBoundaryPath = ".phase1-artifacts\worktree-release-boundary-20260510.json",
  [string]$VercelAccessPath = ".phase1-artifacts\vercel-access-20260510.json",
  [string]$OutputPath = ".phase1-artifacts\blocker-resolution-plan-20260511.json",
  [switch]$ReportOnly,
  [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"

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

function Read-JsonArtifact([string]$Path, [string]$Label) {
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Missing $Label artifact: $Path"
  }

  return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

function Add-Blocker([System.Collections.Generic.List[string]]$Blockers, [string]$Blocker) {
  if (-not [string]::IsNullOrWhiteSpace($Blocker) -and -not $Blockers.Contains($Blocker)) {
    $Blockers.Add($Blocker)
  }
}

function New-Resolution(
  [string]$Blocker,
  [string]$Owner,
  [string]$Category,
  [string]$RequiredAction,
  [string]$VerificationGate,
  [bool]$RequiresOwnerDecision,
  [bool]$RequiresCloudAccess
) {
  return [pscustomobject]@{
    blocker = $Blocker
    owner = $Owner
    category = $Category
    required_action = $RequiredAction
    verification_gate = $VerificationGate
    requires_owner_decision = $RequiresOwnerDecision
    requires_cloud_access = $RequiresCloudAccess
    mutates_repository = $false
  }
}

function Get-ResolutionForBlocker([string]$Blocker) {
  switch ($Blocker) {
    "current_head_does_not_match_candidate_source_sha" {
      return New-Resolution $Blocker "release-owner" "release-provenance" "Choose a rebaseline strategy or move the release candidate to the current reviewed source SHA." "verify-worktree-release-boundary.ps1" $true $false
    }
    "worktree_is_dirty" {
      return New-Resolution $Blocker "repo-owner" "worktree-boundary" "Resolve the dirty worktree through an owner-approved cleanup or rebaseline path." "verify-worktree-change-inventory.ps1" $true $false
    }
    "staged_changes_present" {
      return New-Resolution $Blocker "repo-owner" "staging-boundary" "Inspect staged paths and include them only through a reviewed batch plan." "verify-worktree-cleanup-plan.ps1" $true $false
    }
    "unstaged_changes_present" {
      return New-Resolution $Blocker "repo-owner" "worktree-boundary" "Inspect unstaged paths and decide cleanup, quarantine, or rebaseline." "verify-worktree-cleanup-plan.ps1" $true $false
    }
    "untracked_files_present" {
      return New-Resolution $Blocker "repo-owner" "worktree-boundary" "Review untracked paths and decide whether each belongs in release scope." "verify-worktree-cleanup-plan.ps1" $true $false
    }
    "same_files_are_staged_and_modified" {
      return New-Resolution $Blocker "repo-owner" "split-required" "Normalize staged-and-modified paths after inspecting staged and worktree diffs." "verify-worktree-split-plan.ps1" $true $false
    }
    "owner_decision_not_approved_in_candidate_artifact" {
      return New-Resolution $Blocker "release-owner" "owner-approval" "Update release candidate truth only after an explicit owner decision exists." "verify-worktree-owner-decision.ps1" $true $false
    }
    "owner_decision:owner_decision_file_missing" {
      return New-Resolution $Blocker "owner" "owner-approval" "Create docs/analysis/worktree-owner-decision-20260510.json from the checked template." "verify-worktree-owner-decision.ps1" $true $false
    }
    "vercel_access:token_valid_but_project_not_visible" {
      return New-Resolution $Blocker "cloud-owner" "vercel-access" "Provide a Vercel token that can read the configured project/team, or relink apps/frontend/.vercel/project.json." "verify-vercel-access.ps1" $false $true
    }
    "blocking_review_items_present" {
      return New-Resolution $Blocker "repo-owner" "review-boundary" "Clear security-review, quarantine, and split-required items through reviewed batches." "verify-worktree-quarantine-plan.ps1" $true $false
    }
    "cleanup_execution_plan_blocked" {
      return New-Resolution $Blocker "owner" "cleanup-approval" "Provide a valid owner decision before any cleanup executor can be considered." "verify-worktree-cleanup-execution-plan.ps1" $true $false
    }
    "worktree_split_plan_blocked" {
      return New-Resolution $Blocker "repo-owner" "split-required" "Review the 8 split-required paths and normalize them before a commit boundary." "verify-worktree-split-plan.ps1" $true $false
    }
    "dirty_worktree_inventory_present" {
      return New-Resolution $Blocker "repo-owner" "worktree-inventory" "Reduce the worktree inventory to zero or record an approved rebaseline." "verify-worktree-change-inventory.ps1" $true $false
    }
    "owner_decision_packet_invalid" {
      return New-Resolution $Blocker "repo-owner" "handoff-quality" "Fix the owner decision packet template or verifier before using the handoff." "verify-worktree-owner-decision-packet.ps1" $false $false
    }
    "security_probe_failed" {
      return New-Resolution $Blocker "security-owner" "security" "Fix the security verifier failure before any release boundary can be reopened." "verify-security.ps1" $false $false
    }
    "detect_secrets_baseline_hotspots_present" {
      return New-Resolution $Blocker "security-owner" "security" "Review or resolve every detect-secrets baseline hotspot without copying secret values into artifacts." "verify-worktree-security-review-action-packet.ps1" $true $false
    }
    default {
      return $null
    }
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  Invoke-DependencyVerifier -ScriptName "verify-worktree-change-inventory.ps1" -OutputPath $InventoryPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-quarantine-plan.ps1" -OutputPath $QuarantinePlanPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-owner-decision.ps1" -OutputPath $OwnerDecisionPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-split-plan.ps1" -OutputPath $SplitPlanPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-cleanup-execution-plan.ps1" -OutputPath $CleanupExecutionPlanPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-owner-decision-packet.ps1" -OutputPath $OwnerDecisionPacketPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-security-review-action-packet.ps1" -OutputPath $SecurityReviewActionPacketPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-release-boundary.ps1" -OutputPath $ReleaseBoundaryPath
  Invoke-DependencyVerifier -ScriptName "verify-vercel-access.ps1" -OutputPath $VercelAccessPath

  $inventory = Read-JsonArtifact -Path $InventoryPath -Label "inventory"
  $quarantinePlan = Read-JsonArtifact -Path $QuarantinePlanPath -Label "quarantine-plan"
  $ownerDecision = Read-JsonArtifact -Path $OwnerDecisionPath -Label "owner-decision"
  $splitPlan = Read-JsonArtifact -Path $SplitPlanPath -Label "split-plan"
  $cleanupExecutionPlan = Read-JsonArtifact -Path $CleanupExecutionPlanPath -Label "cleanup-execution-plan"
  $ownerDecisionPacket = Read-JsonArtifact -Path $OwnerDecisionPacketPath -Label "owner-decision-packet"
  $securityReviewActionPacket = Read-JsonArtifact -Path $SecurityReviewActionPacketPath -Label "security-review-action-packet"
  $releaseBoundary = Read-JsonArtifact -Path $ReleaseBoundaryPath -Label "release-boundary"
  $vercelAccess = Read-JsonArtifact -Path $VercelAccessPath -Label "vercel-access"

  $blockers = [System.Collections.Generic.List[string]]::new()
  foreach ($blocker in @($releaseBoundary.blockers)) {
    Add-Blocker -Blockers $blockers -Blocker ([string]$blocker)
  }
  foreach ($decisionError in @($ownerDecision.errors)) {
    Add-Blocker -Blockers $blockers -Blocker ("owner_decision:$decisionError")
  }
  if ($vercelAccess.safe_to_deploy_via_vercel -ne $true) {
    Add-Blocker -Blockers $blockers -Blocker ("vercel_access:$($vercelAccess.classification)")
  }
  if ($quarantinePlan.counts.total_blocking_review_items -gt 0) {
    Add-Blocker -Blockers $blockers -Blocker "blocking_review_items_present"
  }
  if ($cleanupExecutionPlan.ready -ne $true) {
    Add-Blocker -Blockers $blockers -Blocker "cleanup_execution_plan_blocked"
  }
  if ($splitPlan.clear -ne $true) {
    Add-Blocker -Blockers $blockers -Blocker "worktree_split_plan_blocked"
  }
  if ($ownerDecisionPacket.valid -ne $true) {
    Add-Blocker -Blockers $blockers -Blocker "owner_decision_packet_invalid"
  }
  if ([int]$securityReviewActionPacket.baseline_hotspot_count -gt 0) {
    Add-Blocker -Blockers $blockers -Blocker "detect_secrets_baseline_hotspots_present"
  }
  if ($inventory.total_entries -gt 0) {
    Add-Blocker -Blockers $blockers -Blocker "dirty_worktree_inventory_present"
  }

  $resolutions = [System.Collections.Generic.List[object]]::new()
  $unknownBlockers = [System.Collections.Generic.List[string]]::new()
  foreach ($blocker in @($blockers | Sort-Object)) {
    $resolution = Get-ResolutionForBlocker -Blocker ([string]$blocker)
    if ($null -eq $resolution) {
      $unknownBlockers.Add([string]$blocker)
    } else {
      $resolutions.Add($resolution)
    }
  }

  $valid = ($unknownBlockers.Count -eq 0)
  $clear = ($valid -and $blockers.Count -eq 0)
  $status = if ($valid) {
    if ($clear) { "resolution-plan-clear" } else { "resolution-plan-valid-blocked" }
  } else {
    "resolution-plan-invalid"
  }

  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    status = $status
    valid = $valid
    clear = $clear
    blocker_count = $blockers.Count
    mapped_blocker_count = $resolutions.Count
    unknown_blocker_count = $unknownBlockers.Count
    unknown_blockers = @($unknownBlockers)
    resolutions = @($resolutions)
    source_artifacts = [ordered]@{
      inventory = $InventoryPath
      quarantine_plan = $QuarantinePlanPath
      owner_decision = $OwnerDecisionPath
      split_plan = $SplitPlanPath
      cleanup_execution_plan = $CleanupExecutionPlanPath
      owner_decision_packet = $OwnerDecisionPacketPath
      security_review_action_packet = $SecurityReviewActionPacketPath
      release_boundary = $ReleaseBoundaryPath
      vercel_access = $VercelAccessPath
    }
    category_counts = @($resolutions | Group-Object -Property category | Sort-Object Name | ForEach-Object {
      [pscustomobject]@{
        name = [string]$_.Name
        count = [int]$_.Count
      }
    })
    policy = [ordered]@{
      mutates_repository = $false
      executes_requested_actions = $false
      may_cleanup = $false
      may_stage = $false
      may_commit = $false
      may_push = $false
      may_deploy = $false
      may_release = $false
      required_next_action = if ($valid) {
        "Resolve blockers by owner/category; rerun release-boundary after each reviewed change."
      } else {
        "Add a resolution mapping for every unknown blocker before using this handoff."
      }
    }
    leak_prevention = [ordered]@{
      file_contents_included = $false
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
    Write-Host "[blocker-resolution-plan] status=$($summary.status)"
    Write-Host "[blocker-resolution-plan] valid=$($summary.valid)"
    Write-Host "[blocker-resolution-plan] clear=$($summary.clear)"
    Write-Host "[blocker-resolution-plan] blocker_count=$($summary.blocker_count)"
    Write-Host "[blocker-resolution-plan] unknown_blocker_count=$($summary.unknown_blocker_count)"
  }

  if (-not $valid -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}

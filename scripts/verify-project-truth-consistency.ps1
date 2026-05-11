param(
  [string]$TruthStatePath = ".phase1-artifacts\project-truth-state-20260510.json",
  [string]$InventoryPath = ".phase1-artifacts\worktree-change-inventory-20260510.json",
  [string]$ReviewActionMatrixPath = ".phase1-artifacts\worktree-review-action-matrix-20260511.json",
  [string]$QuarantinePlanPath = ".phase1-artifacts\worktree-quarantine-plan-20260510.json",
  [string]$QuarantineActionPacketPath = ".phase1-artifacts\worktree-quarantine-action-packet-20260511.json",
  [string]$SecurityReviewPacketPath = ".phase1-artifacts\worktree-security-review-packet-20260511.json",
  [string]$SecurityReviewActionPacketPath = ".phase1-artifacts\worktree-security-review-action-packet-20260511.json",
  [string]$OwnerDecisionPath = ".phase1-artifacts\worktree-owner-decision-20260510.json",
  [string]$SplitPlanPath = ".phase1-artifacts\worktree-split-plan-20260510.json",
  [string]$SplitActionPacketPath = ".phase1-artifacts\worktree-split-action-packet-20260511.json",
  [string]$CleanupExecutionPlanPath = ".phase1-artifacts\worktree-cleanup-execution-plan-20260510.json",
  [string]$OwnerDecisionPacketPath = ".phase1-artifacts\worktree-owner-decision-packet-20260510.json",
  [string]$OwnerDecisionCandidatesPath = ".phase1-artifacts\worktree-owner-decision-candidates-20260511.json",
  [string]$OwnerActionPacketPath = ".phase1-artifacts\worktree-owner-action-packet-20260511.json",
  [string]$OwnerDecisionReadinessPacketPath = ".phase1-artifacts\owner-decision-readiness-packet-20260511.json",
  [string]$ReleaseBoundaryPath = ".phase1-artifacts\worktree-release-boundary-20260510.json",
  [string]$VercelAccessPath = ".phase1-artifacts\vercel-access-20260510.json",
  [string]$VercelRemediationPlanPath = ".phase1-artifacts\vercel-remediation-plan-20260511.json",
  [string]$ReleaseRebaselinePlanPath = ".phase1-artifacts\release-rebaseline-plan-20260511.json",
  [string]$BlockerResolutionPlanPath = ".phase1-artifacts\blocker-resolution-plan-20260511.json",
  [string]$OutputPath = ".phase1-artifacts\project-truth-consistency-20260510.json",
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

function Add-Finding([System.Collections.Generic.List[object]]$Findings, [string]$Id, [string]$Expected, [string]$Actual) {
  $Findings.Add([pscustomobject]@{
    id = $Id
    expected = $Expected
    actual = $Actual
  })
}

function Assert-EqualValue(
  [System.Collections.Generic.List[object]]$Findings,
  [string]$Id,
  [object]$Expected,
  [object]$Actual
) {
  if ([string]$Expected -ne [string]$Actual) {
    Add-Finding -Findings $Findings -Id $Id -Expected ([string]$Expected) -Actual ([string]$Actual)
  }
}

function Assert-BlockerPresent(
  [System.Collections.Generic.List[object]]$Findings,
  [object[]]$Blockers,
  [string]$Blocker
) {
  if (@($Blockers) -notcontains $Blocker) {
    Add-Finding -Findings $Findings -Id "missing_blocker:$Blocker" -Expected "present" -Actual "missing"
  }
}

function Get-ArtifactTimestamp([object]$Artifact) {
  if ($null -eq $Artifact -or [string]::IsNullOrWhiteSpace([string]$Artifact.generated_at)) {
    return $null
  }

  return [datetimeoffset]::Parse([string]$Artifact.generated_at)
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  if (-not (Test-Path -LiteralPath $TruthStatePath)) {
    & (Join-Path $PSScriptRoot "verify-project-truth-state.ps1") -ReportOnly -OutputPath $TruthStatePath | Out-Null
  }

  $truth = Read-JsonArtifact -Path $TruthStatePath -Label "truth-state"
  $inventory = Read-JsonArtifact -Path $InventoryPath -Label "inventory"
  $reviewActionMatrix = Read-JsonArtifact -Path $ReviewActionMatrixPath -Label "review-action-matrix"
  $quarantine = Read-JsonArtifact -Path $QuarantinePlanPath -Label "quarantine-plan"
  $quarantineActionPacket = Read-JsonArtifact -Path $QuarantineActionPacketPath -Label "quarantine-action-packet"
  $securityReviewPacket = Read-JsonArtifact -Path $SecurityReviewPacketPath -Label "security-review-packet"
  $securityReviewActionPacket = Read-JsonArtifact -Path $SecurityReviewActionPacketPath -Label "security-review-action-packet"
  $ownerDecision = Read-JsonArtifact -Path $OwnerDecisionPath -Label "owner-decision"
  $splitPlan = Read-JsonArtifact -Path $SplitPlanPath -Label "split-plan"
  $splitActionPacket = Read-JsonArtifact -Path $SplitActionPacketPath -Label "split-action-packet"
  $cleanupExecutionPlan = Read-JsonArtifact -Path $CleanupExecutionPlanPath -Label "cleanup-execution-plan"
  $ownerDecisionPacket = Read-JsonArtifact -Path $OwnerDecisionPacketPath -Label "owner-decision-packet"
  $ownerDecisionCandidates = Read-JsonArtifact -Path $OwnerDecisionCandidatesPath -Label "owner-decision-candidates"
  $ownerActionPacket = Read-JsonArtifact -Path $OwnerActionPacketPath -Label "owner-action-packet"
  $ownerDecisionReadinessPacket = Read-JsonArtifact -Path $OwnerDecisionReadinessPacketPath -Label "owner-decision-readiness-packet"
  $releaseBoundary = Read-JsonArtifact -Path $ReleaseBoundaryPath -Label "release-boundary"
  $vercelAccess = Read-JsonArtifact -Path $VercelAccessPath -Label "vercel-access"
  $vercelRemediationPlan = Read-JsonArtifact -Path $VercelRemediationPlanPath -Label "vercel-remediation-plan"
  $releaseRebaselinePlan = Read-JsonArtifact -Path $ReleaseRebaselinePlanPath -Label "release-rebaseline-plan"
  $blockerResolutionPlan = Read-JsonArtifact -Path $BlockerResolutionPlanPath -Label "blocker-resolution-plan"

  $findings = [System.Collections.Generic.List[object]]::new()

  Assert-EqualValue $findings "counts.total_status_entries" $inventory.total_entries $truth.counts.total_status_entries
  Assert-EqualValue $findings "counts.staged_and_modified" $releaseBoundary.counts.staged_and_modified $truth.counts.staged_and_modified
  Assert-EqualValue $findings "counts.staged" $releaseBoundary.counts.staged $truth.counts.staged
  Assert-EqualValue $findings "counts.unstaged" $releaseBoundary.counts.unstaged $truth.counts.unstaged
  Assert-EqualValue $findings "counts.untracked" $releaseBoundary.counts.untracked $truth.counts.untracked
  Assert-EqualValue $findings "counts.review_action_matrix_batches" $reviewActionMatrix.batch_count $truth.counts.review_action_matrix_batches
  Assert-EqualValue $findings "counts.review_action_matrix_unique_paths" $reviewActionMatrix.unique_path_count $truth.counts.review_action_matrix_unique_paths
  Assert-EqualValue $findings "counts.review_action_matrix_path_references" $reviewActionMatrix.batch_path_reference_count $truth.counts.review_action_matrix_path_references
  Assert-EqualValue $findings "counts.review_action_matrix_findings" $reviewActionMatrix.finding_count $truth.counts.review_action_matrix_findings
  Assert-EqualValue $findings "counts.security_review" $quarantine.counts.security_review $truth.counts.security_review
  Assert-EqualValue $findings "counts.quarantine_action_count" $quarantineActionPacket.action_count $truth.counts.quarantine_action_count
  Assert-EqualValue $findings "counts.quarantine_action_findings" $quarantineActionPacket.finding_count $truth.counts.quarantine_action_findings
  Assert-EqualValue $findings "counts.security_review_packet_paths" $securityReviewPacket.security_review_count $truth.counts.security_review_packet_paths
  Assert-EqualValue $findings "counts.security_review_packet_findings" $securityReviewPacket.finding_count $truth.counts.security_review_packet_findings
  Assert-EqualValue $findings "counts.security_review_action_count" $securityReviewActionPacket.action_count $truth.counts.security_review_action_count
  Assert-EqualValue $findings "counts.security_review_baseline_hotspot_count" $securityReviewActionPacket.baseline_hotspot_count $truth.counts.security_review_baseline_hotspot_count
  Assert-EqualValue $findings "counts.security_review_baseline_hotspot_findings" $securityReviewActionPacket.baseline_hotspot_finding_count $truth.counts.security_review_baseline_hotspot_findings
  Assert-EqualValue $findings "counts.security_review_action_findings" $securityReviewActionPacket.finding_count $truth.counts.security_review_action_findings
  Assert-EqualValue $findings "counts.exclude_or_quarantine" $quarantine.counts.exclude_or_quarantine $truth.counts.exclude_or_quarantine
  Assert-EqualValue $findings "counts.split_required" $quarantine.counts.split_required $truth.counts.split_required
  Assert-EqualValue $findings "counts.split_plan_actions" $splitPlan.split_path_count $truth.counts.split_plan_actions
  Assert-EqualValue $findings "counts.split_action_count" $splitActionPacket.action_count $truth.counts.split_action_count
  Assert-EqualValue $findings "counts.split_action_findings" $splitActionPacket.finding_count $truth.counts.split_action_findings
  Assert-EqualValue $findings "counts.cleanup_candidate_actions" $cleanupExecutionPlan.candidate_action_count $truth.counts.cleanup_candidate_actions
  Assert-EqualValue $findings "counts.owner_decision_packet_findings" $ownerDecisionPacket.finding_count $truth.counts.owner_decision_packet_findings
  Assert-EqualValue $findings "counts.owner_decision_candidate_options" $ownerDecisionCandidates.candidate_count $truth.counts.owner_decision_candidate_options
  Assert-EqualValue $findings "counts.owner_decision_candidate_findings" $ownerDecisionCandidates.finding_count $truth.counts.owner_decision_candidate_findings
  Assert-EqualValue $findings "counts.owner_decision_currently_actionable_candidates" $ownerDecisionCandidates.currently_actionable_candidate_count $truth.counts.owner_decision_currently_actionable_candidates
  Assert-EqualValue $findings "counts.owner_action_count" $ownerActionPacket.action_count $truth.counts.owner_action_count
  Assert-EqualValue $findings "counts.owner_action_findings" $ownerActionPacket.finding_count $truth.counts.owner_action_findings
  Assert-EqualValue $findings "counts.owner_decision_readiness_items" $ownerDecisionReadinessPacket.required_item_count $truth.counts.owner_decision_readiness_items
  Assert-EqualValue $findings "counts.owner_decision_readiness_findings" $ownerDecisionReadinessPacket.finding_count $truth.counts.owner_decision_readiness_findings
  Assert-EqualValue $findings "counts.blocker_resolution_unknowns" $blockerResolutionPlan.unknown_blocker_count $truth.counts.blocker_resolution_unknowns
  Assert-EqualValue $findings "counts.blocker_resolution_mapped" $blockerResolutionPlan.mapped_blocker_count $truth.counts.blocker_resolution_mapped
  Assert-EqualValue $findings "counts.vercel_remediation_actions" $vercelRemediationPlan.remediation_action_count $truth.counts.vercel_remediation_actions
  Assert-EqualValue $findings "counts.vercel_remediation_findings" $vercelRemediationPlan.finding_count $truth.counts.vercel_remediation_findings
  Assert-EqualValue $findings "counts.release_rebaseline_options" $releaseRebaselinePlan.option_count $truth.counts.release_rebaseline_options
  Assert-EqualValue $findings "counts.release_rebaseline_findings" $releaseRebaselinePlan.finding_count $truth.counts.release_rebaseline_findings

  Assert-EqualValue $findings "gates.worktree_clean" $releaseBoundary.worktree_clean $truth.gates.worktree_clean
  Assert-EqualValue $findings "gates.release_boundary_clear" $releaseBoundary.release_boundary_clear $truth.gates.release_boundary_clear
  Assert-EqualValue $findings "gates.owner_decision_valid" $ownerDecision.decision_valid $truth.gates.owner_decision_valid
  Assert-EqualValue $findings "gates.split_plan_clear" $splitPlan.clear $truth.gates.split_plan_clear
  Assert-EqualValue $findings "gates.split_action_packet_valid" $splitActionPacket.valid $truth.gates.split_action_packet_valid
  Assert-EqualValue $findings "gates.cleanup_execution_ready" $cleanupExecutionPlan.ready $truth.gates.cleanup_execution_ready
  Assert-EqualValue $findings "gates.owner_decision_packet_valid" $ownerDecisionPacket.valid $truth.gates.owner_decision_packet_valid
  Assert-EqualValue $findings "gates.owner_decision_candidates_valid" $ownerDecisionCandidates.valid $truth.gates.owner_decision_candidates_valid
  Assert-EqualValue $findings "gates.owner_action_packet_valid" $ownerActionPacket.valid $truth.gates.owner_action_packet_valid
  Assert-EqualValue $findings "gates.owner_decision_readiness_packet_valid" $ownerDecisionReadinessPacket.valid $truth.gates.owner_decision_readiness_packet_valid
  Assert-EqualValue $findings "gates.blocker_resolution_plan_valid" $blockerResolutionPlan.valid $truth.gates.blocker_resolution_plan_valid
  Assert-EqualValue $findings "gates.vercel_remediation_plan_valid" $vercelRemediationPlan.valid $truth.gates.vercel_remediation_plan_valid
  Assert-EqualValue $findings "gates.release_rebaseline_plan_valid" $releaseRebaselinePlan.valid $truth.gates.release_rebaseline_plan_valid
  Assert-EqualValue $findings "gates.vercel_access_ready" $vercelAccess.safe_to_deploy_via_vercel $truth.gates.vercel_access_ready
  Assert-EqualValue $findings "gates.review_action_matrix_valid" $reviewActionMatrix.valid $truth.gates.review_action_matrix_valid
  Assert-EqualValue $findings "gates.quarantine_action_packet_valid" $quarantineActionPacket.valid $truth.gates.quarantine_action_packet_valid
  Assert-EqualValue $findings "gates.security_review_packet_valid" $securityReviewPacket.valid $truth.gates.security_review_packet_valid
  Assert-EqualValue $findings "gates.security_review_action_packet_valid" $securityReviewActionPacket.valid $truth.gates.security_review_action_packet_valid

  Assert-EqualValue $findings "vercel.classification" $vercelAccess.classification $truth.vercel.classification
  Assert-EqualValue $findings "vercel.safe_to_deploy_via_vercel" $vercelAccess.safe_to_deploy_via_vercel $truth.vercel.safe_to_deploy_via_vercel
  Assert-EqualValue $findings "release_candidate.head_matches_candidate" $releaseBoundary.head_matches_candidate $truth.release_candidate.head_matches_candidate
  Assert-EqualValue $findings "release_candidate.needs_rebaseline" $releaseRebaselinePlan.needs_rebaseline $truth.release_candidate.needs_rebaseline
  Assert-EqualValue $findings "release_candidate.owner_approved" $releaseBoundary.owner_approved $truth.release_candidate.owner_approved

  Assert-EqualValue $findings "policy.may_cleanup" $false $truth.policy.may_cleanup
  Assert-EqualValue $findings "policy.may_stage" $false $truth.policy.may_stage
  Assert-EqualValue $findings "policy.may_commit" $false $truth.policy.may_commit
  Assert-EqualValue $findings "policy.may_push" $false $truth.policy.may_push
  Assert-EqualValue $findings "policy.may_deploy" $false $truth.policy.may_deploy
  Assert-EqualValue $findings "policy.may_release" $false $truth.policy.may_release
  Assert-EqualValue $findings "leak_prevention.file_contents_included" $false $truth.leak_prevention.file_contents_included
  Assert-EqualValue $findings "leak_prevention.secret_values_included" $false $truth.leak_prevention.secret_values_included
  Assert-EqualValue $findings "leak_prevention.tokens_included" $false $truth.leak_prevention.tokens_included
  Assert-EqualValue $findings "leak_prevention.env_values_included" $false $truth.leak_prevention.env_values_included

  if ($truth.truth_ready -eq $true -and $truth.status -ne "ready-for-next-gate") {
    Add-Finding $findings "truth_ready_status" "ready-for-next-gate when truth_ready=true" ([string]$truth.status)
  }
  if ($truth.truth_ready -ne $true -and $truth.status -ne "blocked") {
    Add-Finding $findings "blocked_status" "blocked when truth_ready=false" ([string]$truth.status)
  }

  if ($inventory.total_entries -gt 0) {
    Assert-BlockerPresent $findings $truth.blockers "dirty_worktree_inventory_present"
  }
  if ($reviewActionMatrix.valid -ne $true) {
    Assert-BlockerPresent $findings $truth.blockers "review_action_matrix_invalid"
  }
  if ($quarantine.counts.total_blocking_review_items -gt 0) {
    Assert-BlockerPresent $findings $truth.blockers "blocking_review_items_present"
  }
  if ($quarantineActionPacket.valid -ne $true) {
    Assert-BlockerPresent $findings $truth.blockers "quarantine_action_packet_invalid"
  }
  if ($securityReviewPacket.valid -ne $true) {
    Assert-BlockerPresent $findings $truth.blockers "security_review_packet_invalid"
  }
  if ($securityReviewActionPacket.valid -ne $true) {
    Assert-BlockerPresent $findings $truth.blockers "security_review_action_packet_invalid"
  }
  if ([int]$securityReviewActionPacket.baseline_hotspot_count -gt 0) {
    Assert-BlockerPresent $findings $truth.blockers "detect_secrets_baseline_hotspots_present"
  }
  if ($cleanupExecutionPlan.ready -ne $true) {
    Assert-BlockerPresent $findings $truth.blockers "cleanup_execution_plan_blocked"
  }
  if ($splitPlan.clear -ne $true) {
    Assert-BlockerPresent $findings $truth.blockers "worktree_split_plan_blocked"
  }
  if ($splitActionPacket.valid -ne $true) {
    Assert-BlockerPresent $findings $truth.blockers "split_action_packet_invalid"
  }
  if ($ownerDecisionPacket.valid -ne $true) {
    Assert-BlockerPresent $findings $truth.blockers "owner_decision_packet_invalid"
  }
  if ($ownerDecisionCandidates.valid -ne $true) {
    Assert-BlockerPresent $findings $truth.blockers "owner_decision_candidates_invalid"
  }
  if ($ownerActionPacket.valid -ne $true) {
    Assert-BlockerPresent $findings $truth.blockers "owner_action_packet_invalid"
  }
  if ($ownerDecisionReadinessPacket.valid -ne $true) {
    Assert-BlockerPresent $findings $truth.blockers "owner_decision_readiness_packet_invalid"
  }
  if ($blockerResolutionPlan.valid -ne $true) {
    Assert-BlockerPresent $findings $truth.blockers "blocker_resolution_plan_invalid"
  }
  if ($vercelRemediationPlan.valid -ne $true) {
    Assert-BlockerPresent $findings $truth.blockers "vercel_remediation_plan_invalid"
  }
  if ($releaseRebaselinePlan.valid -ne $true) {
    Assert-BlockerPresent $findings $truth.blockers "release_rebaseline_plan_invalid"
  }
  if ($ownerDecision.decision_valid -ne $true) {
    foreach ($decisionError in @($ownerDecision.errors)) {
      Assert-BlockerPresent $findings $truth.blockers "owner_decision:$decisionError"
    }
  }
  if ($vercelAccess.safe_to_deploy_via_vercel -ne $true) {
    Assert-BlockerPresent $findings $truth.blockers "vercel_access:$($vercelAccess.classification)"
  }

  foreach ($artifactPath in @(
    $truth.evidence.inventory,
    $truth.evidence.cleanup_plan,
    $truth.evidence.review_action_matrix,
    $truth.evidence.quarantine_plan,
    $truth.evidence.quarantine_action_packet,
    $truth.evidence.security_review_packet,
    $truth.evidence.security_review_action_packet,
    $truth.evidence.owner_decision,
    $truth.evidence.split_plan,
    $truth.evidence.split_action_packet,
    $truth.evidence.cleanup_execution_plan,
    $truth.evidence.owner_decision_packet,
    $truth.evidence.owner_decision_candidates,
    $truth.evidence.owner_action_packet,
    $truth.evidence.owner_decision_readiness_packet,
    $truth.evidence.release_boundary,
    $truth.evidence.vercel_access,
    $truth.evidence.vercel_remediation_plan,
    $truth.evidence.release_rebaseline_plan,
    $truth.evidence.blocker_resolution_plan
  )) {
    $artifactPathText = [string]$artifactPath
    if ([string]::IsNullOrWhiteSpace($artifactPathText)) {
      Add-Finding $findings "evidence_path_empty" "non-empty path" ""
    } elseif (-not (Test-Path -LiteralPath $artifactPathText)) {
      Add-Finding $findings "evidence_path_missing" "exists" $artifactPathText
    }
  }

  $truthTimestamp = Get-ArtifactTimestamp -Artifact $truth
  $staleDependencies = @()
  foreach ($pair in @(
    @{ label = "inventory"; artifact = $inventory },
    @{ label = "review_action_matrix"; artifact = $reviewActionMatrix },
    @{ label = "quarantine_plan"; artifact = $quarantine },
    @{ label = "quarantine_action_packet"; artifact = $quarantineActionPacket },
    @{ label = "security_review_packet"; artifact = $securityReviewPacket },
    @{ label = "security_review_action_packet"; artifact = $securityReviewActionPacket },
    @{ label = "owner_decision"; artifact = $ownerDecision },
    @{ label = "split_plan"; artifact = $splitPlan },
    @{ label = "split_action_packet"; artifact = $splitActionPacket },
    @{ label = "cleanup_execution_plan"; artifact = $cleanupExecutionPlan },
    @{ label = "owner_decision_packet"; artifact = $ownerDecisionPacket },
    @{ label = "owner_decision_candidates"; artifact = $ownerDecisionCandidates },
    @{ label = "owner_action_packet"; artifact = $ownerActionPacket },
    @{ label = "owner_decision_readiness_packet"; artifact = $ownerDecisionReadinessPacket },
    @{ label = "release_boundary"; artifact = $releaseBoundary },
    @{ label = "vercel_access"; artifact = $vercelAccess },
    @{ label = "vercel_remediation_plan"; artifact = $vercelRemediationPlan },
    @{ label = "release_rebaseline_plan"; artifact = $releaseRebaselinePlan },
    @{ label = "blocker_resolution_plan"; artifact = $blockerResolutionPlan }
  )) {
    $timestamp = Get-ArtifactTimestamp -Artifact $pair.artifact
    if ($null -ne $truthTimestamp -and $null -ne $timestamp -and $timestamp -gt $truthTimestamp) {
      $staleDependencies += $pair.label
    }
  }
  if ($staleDependencies.Count -gt 0) {
    Add-Finding $findings "truth_state_stale" "truth generated after dependencies" ($staleDependencies -join ",")
  }

  $consistent = ($findings.Count -eq 0)
  $status = if ($consistent) {
    if ($truth.truth_ready -eq $true) { "consistent-ready-for-next-gate" } else { "consistent-blocked" }
  } else {
    "inconsistent"
  }

  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    status = $status
    consistent = $consistent
    truth_ready = $truth.truth_ready
    truth_status = $truth.status
    finding_count = $findings.Count
    findings = @($findings)
    checked_artifacts = [ordered]@{
      truth_state = $TruthStatePath
      inventory = $InventoryPath
      review_action_matrix = $ReviewActionMatrixPath
      quarantine_plan = $QuarantinePlanPath
      quarantine_action_packet = $QuarantineActionPacketPath
      security_review_packet = $SecurityReviewPacketPath
      security_review_action_packet = $SecurityReviewActionPacketPath
      owner_decision = $OwnerDecisionPath
      split_plan = $SplitPlanPath
      split_action_packet = $SplitActionPacketPath
      cleanup_execution_plan = $CleanupExecutionPlanPath
      owner_decision_packet = $OwnerDecisionPacketPath
      owner_decision_candidates = $OwnerDecisionCandidatesPath
      owner_action_packet = $OwnerActionPacketPath
      owner_decision_readiness_packet = $OwnerDecisionReadinessPacketPath
      release_boundary = $ReleaseBoundaryPath
      vercel_access = $VercelAccessPath
      vercel_remediation_plan = $VercelRemediationPlanPath
      release_rebaseline_plan = $ReleaseRebaselinePlanPath
      blocker_resolution_plan = $BlockerResolutionPlanPath
    }
    policy = [ordered]@{
      mutates_repository = $false
      may_cleanup = $false
      may_stage = $false
      may_commit = $false
      may_push = $false
      may_deploy = $false
      may_release = $false
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
    Write-Host "[project-truth-consistency] status=$($summary.status)"
    Write-Host "[project-truth-consistency] consistent=$($summary.consistent)"
    Write-Host "[project-truth-consistency] truth_ready=$($summary.truth_ready)"
    Write-Host "[project-truth-consistency] finding_count=$($summary.finding_count)"
    foreach ($finding in @($findings)) {
      Write-Host ("[project-truth-consistency] finding={0} expected={1} actual={2}" -f $finding.id, $finding.expected, $finding.actual)
    }
  }

  if (-not $consistent -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}

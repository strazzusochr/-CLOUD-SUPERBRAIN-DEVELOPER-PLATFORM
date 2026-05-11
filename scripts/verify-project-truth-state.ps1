param(
  [string]$InventoryPath = ".phase1-artifacts\worktree-change-inventory-20260510.json",
  [string]$CleanupPlanPath = ".phase1-artifacts\worktree-cleanup-plan-20260510.json",
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
  [string]$OutputPath = ".phase1-artifacts\project-truth-state-20260510.json",
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

function Invoke-SecurityProbe() {
  $scriptPath = Join-Path $PSScriptRoot "verify-security.ps1"
  if (-not (Test-Path -LiteralPath $scriptPath)) {
    return [pscustomobject]@{
      checked = $false
      status = "missing"
      passed = $false
      error = "verify-security.ps1 not found"
    }
  }

  try {
    $global:LASTEXITCODE = 0
    & $scriptPath | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "verify-security.ps1 exited with code $LASTEXITCODE"
    }
    return [pscustomobject]@{
      checked = $true
      status = "passed"
      passed = $true
      error = $null
    }
  } catch {
    return [pscustomobject]@{
      checked = $true
      status = "failed"
      passed = $false
      error = $_.Exception.Message
    }
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  Invoke-DependencyVerifier -ScriptName "verify-worktree-change-inventory.ps1" -OutputPath $InventoryPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-cleanup-plan.ps1" -OutputPath $CleanupPlanPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-review-action-matrix.ps1" -OutputPath $ReviewActionMatrixPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-quarantine-plan.ps1" -OutputPath $QuarantinePlanPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-quarantine-action-packet.ps1" -OutputPath $QuarantineActionPacketPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-security-review-packet.ps1" -OutputPath $SecurityReviewPacketPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-security-review-action-packet.ps1" -OutputPath $SecurityReviewActionPacketPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-owner-decision.ps1" -OutputPath $OwnerDecisionPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-split-plan.ps1" -OutputPath $SplitPlanPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-split-action-packet.ps1" -OutputPath $SplitActionPacketPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-cleanup-execution-plan.ps1" -OutputPath $CleanupExecutionPlanPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-owner-decision-packet.ps1" -OutputPath $OwnerDecisionPacketPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-owner-decision-candidates.ps1" -OutputPath $OwnerDecisionCandidatesPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-owner-action-packet.ps1" -OutputPath $OwnerActionPacketPath
  Invoke-DependencyVerifier -ScriptName "verify-owner-decision-readiness-packet.ps1" -OutputPath $OwnerDecisionReadinessPacketPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-release-boundary.ps1" -OutputPath $ReleaseBoundaryPath
  Invoke-DependencyVerifier -ScriptName "verify-vercel-access.ps1" -OutputPath $VercelAccessPath
  Invoke-DependencyVerifier -ScriptName "verify-vercel-remediation-plan.ps1" -OutputPath $VercelRemediationPlanPath
  Invoke-DependencyVerifier -ScriptName "verify-release-rebaseline-plan.ps1" -OutputPath $ReleaseRebaselinePlanPath
  Invoke-DependencyVerifier -ScriptName "verify-blocker-resolution-plan.ps1" -OutputPath $BlockerResolutionPlanPath

  $inventory = Read-JsonArtifact -Path $InventoryPath -Label "inventory"
  $cleanupPlan = Read-JsonArtifact -Path $CleanupPlanPath -Label "cleanup-plan"
  $reviewActionMatrix = Read-JsonArtifact -Path $ReviewActionMatrixPath -Label "review-action-matrix"
  $quarantinePlan = Read-JsonArtifact -Path $QuarantinePlanPath -Label "quarantine-plan"
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
  $securityProbe = Invoke-SecurityProbe

  $blockers = [System.Collections.Generic.List[string]]::new()
  foreach ($blocker in @($releaseBoundary.blockers)) {
    Add-Blocker -Blockers $blockers -Blocker ([string]$blocker)
  }
  foreach ($decisionError in @($ownerDecision.errors)) {
    Add-Blocker -Blockers $blockers -Blocker ("owner_decision:$decisionError")
  }
  if (-not $securityProbe.passed) {
    Add-Blocker -Blockers $blockers -Blocker "security_probe_failed"
  }
  if ($reviewActionMatrix.valid -ne $true) {
    Add-Blocker -Blockers $blockers -Blocker "review_action_matrix_invalid"
  }
  if ($quarantineActionPacket.valid -ne $true) {
    Add-Blocker -Blockers $blockers -Blocker "quarantine_action_packet_invalid"
  }
  if ($securityReviewPacket.valid -ne $true) {
    Add-Blocker -Blockers $blockers -Blocker "security_review_packet_invalid"
  }
  if ($securityReviewActionPacket.valid -ne $true) {
    Add-Blocker -Blockers $blockers -Blocker "security_review_action_packet_invalid"
  }
  if ([int]$securityReviewActionPacket.baseline_hotspot_count -gt 0) {
    Add-Blocker -Blockers $blockers -Blocker "detect_secrets_baseline_hotspots_present"
  }
  if ($vercelAccess.safe_to_deploy_via_vercel -ne $true) {
    Add-Blocker -Blockers $blockers -Blocker ("vercel_access:$($vercelAccess.classification)")
  }
  if ($vercelRemediationPlan.valid -ne $true) {
    Add-Blocker -Blockers $blockers -Blocker "vercel_remediation_plan_invalid"
  }
  if ($releaseRebaselinePlan.valid -ne $true) {
    Add-Blocker -Blockers $blockers -Blocker "release_rebaseline_plan_invalid"
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
  if ($splitActionPacket.valid -ne $true) {
    Add-Blocker -Blockers $blockers -Blocker "split_action_packet_invalid"
  }
  if ($ownerDecisionPacket.valid -ne $true) {
    Add-Blocker -Blockers $blockers -Blocker "owner_decision_packet_invalid"
  }
  if ($ownerDecisionCandidates.valid -ne $true) {
    Add-Blocker -Blockers $blockers -Blocker "owner_decision_candidates_invalid"
  }
  if ($ownerActionPacket.valid -ne $true) {
    Add-Blocker -Blockers $blockers -Blocker "owner_action_packet_invalid"
  }
  if ($ownerDecisionReadinessPacket.valid -ne $true) {
    Add-Blocker -Blockers $blockers -Blocker "owner_decision_readiness_packet_invalid"
  }
  if ($blockerResolutionPlan.valid -ne $true) {
    Add-Blocker -Blockers $blockers -Blocker "blocker_resolution_plan_invalid"
  }
  if ($inventory.total_entries -gt 0) {
    Add-Blocker -Blockers $blockers -Blocker "dirty_worktree_inventory_present"
  }

  $releaseBoundaryClear = ($releaseBoundary.release_boundary_clear -eq $true)
  $ownerDecisionValid = ($ownerDecision.decision_valid -eq $true)
  $vercelReady = ($vercelAccess.safe_to_deploy_via_vercel -eq $true)
  $vercelRemediationPlanValid = ($vercelRemediationPlan.valid -eq $true)
  $releaseRebaselinePlanValid = ($releaseRebaselinePlan.valid -eq $true)
  $securityPassed = ($securityProbe.passed -eq $true)
  $reviewActionMatrixValid = ($reviewActionMatrix.valid -eq $true)
  $quarantineActionPacketValid = ($quarantineActionPacket.valid -eq $true)
  $securityReviewPacketValid = ($securityReviewPacket.valid -eq $true)
  $securityReviewActionPacketValid = ($securityReviewActionPacket.valid -eq $true)
  $worktreeClean = ($releaseBoundary.worktree_clean -eq $true)
  $splitPlanClear = ($splitPlan.clear -eq $true)
  $splitActionPacketValid = ($splitActionPacket.valid -eq $true)
  $ownerDecisionPacketValid = ($ownerDecisionPacket.valid -eq $true)
  $ownerDecisionCandidatesValid = ($ownerDecisionCandidates.valid -eq $true)
  $ownerActionPacketValid = ($ownerActionPacket.valid -eq $true)
  $ownerDecisionReadinessPacketValid = ($ownerDecisionReadinessPacket.valid -eq $true)
  $blockerResolutionPlanValid = ($blockerResolutionPlan.valid -eq $true)

  $truthReady = ($releaseBoundaryClear -and $ownerDecisionValid -and $ownerDecisionPacketValid -and $ownerDecisionCandidatesValid -and $ownerActionPacketValid -and $ownerDecisionReadinessPacketValid -and $blockerResolutionPlanValid -and $vercelRemediationPlanValid -and $releaseRebaselinePlanValid -and $vercelReady -and $securityPassed -and $reviewActionMatrixValid -and $quarantineActionPacketValid -and $securityReviewPacketValid -and $securityReviewActionPacketValid -and $worktreeClean -and $splitPlanClear -and $splitActionPacketValid)
  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    status = if ($truthReady) { "ready-for-next-gate" } else { "blocked" }
    truth_ready = $truthReady
    blockers = @($blockers)
    evidence = [ordered]@{
      inventory = $InventoryPath
      cleanup_plan = $CleanupPlanPath
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
    gates = [ordered]@{
      worktree_clean = $worktreeClean
      release_boundary_clear = $releaseBoundaryClear
      owner_decision_valid = $ownerDecisionValid
      split_plan_clear = $splitPlanClear
      split_action_packet_valid = $splitActionPacketValid
      cleanup_execution_ready = ($cleanupExecutionPlan.ready -eq $true)
      owner_decision_packet_valid = $ownerDecisionPacketValid
      owner_decision_candidates_valid = $ownerDecisionCandidatesValid
      owner_action_packet_valid = $ownerActionPacketValid
      owner_decision_readiness_packet_valid = $ownerDecisionReadinessPacketValid
      blocker_resolution_plan_valid = $blockerResolutionPlanValid
      vercel_remediation_plan_valid = $vercelRemediationPlanValid
      release_rebaseline_plan_valid = $releaseRebaselinePlanValid
      vercel_access_ready = $vercelReady
      security_passed = $securityPassed
      review_action_matrix_valid = $reviewActionMatrixValid
      quarantine_action_packet_valid = $quarantineActionPacketValid
      security_review_packet_valid = $securityReviewPacketValid
      security_review_action_packet_valid = $securityReviewActionPacketValid
    }
    counts = [ordered]@{
      total_status_entries = [int]$inventory.total_entries
      staged_and_modified = [int]$releaseBoundary.counts.staged_and_modified
      staged = [int]$releaseBoundary.counts.staged
      unstaged = [int]$releaseBoundary.counts.unstaged
      untracked = [int]$releaseBoundary.counts.untracked
      review_action_matrix_batches = [int]$reviewActionMatrix.batch_count
      review_action_matrix_unique_paths = [int]$reviewActionMatrix.unique_path_count
      review_action_matrix_path_references = [int]$reviewActionMatrix.batch_path_reference_count
      review_action_matrix_findings = [int]$reviewActionMatrix.finding_count
      security_review = [int]$quarantinePlan.counts.security_review
      quarantine_action_count = [int]$quarantineActionPacket.action_count
      quarantine_action_findings = [int]$quarantineActionPacket.finding_count
      security_review_packet_paths = [int]$securityReviewPacket.security_review_count
      security_review_packet_findings = [int]$securityReviewPacket.finding_count
      security_review_action_count = [int]$securityReviewActionPacket.action_count
      security_review_baseline_hotspot_count = [int]$securityReviewActionPacket.baseline_hotspot_count
      security_review_baseline_hotspot_findings = [int]$securityReviewActionPacket.baseline_hotspot_finding_count
      security_review_action_findings = [int]$securityReviewActionPacket.finding_count
      exclude_or_quarantine = [int]$quarantinePlan.counts.exclude_or_quarantine
      split_required = [int]$quarantinePlan.counts.split_required
      split_plan_actions = [int]$splitPlan.split_path_count
      split_action_count = [int]$splitActionPacket.action_count
      split_action_findings = [int]$splitActionPacket.finding_count
      cleanup_candidate_actions = [int]$cleanupExecutionPlan.candidate_action_count
      owner_decision_packet_findings = [int]$ownerDecisionPacket.finding_count
      owner_decision_candidate_options = [int]$ownerDecisionCandidates.candidate_count
      owner_decision_candidate_findings = [int]$ownerDecisionCandidates.finding_count
      owner_decision_currently_actionable_candidates = [int]$ownerDecisionCandidates.currently_actionable_candidate_count
      owner_action_count = [int]$ownerActionPacket.action_count
      owner_action_findings = [int]$ownerActionPacket.finding_count
      owner_decision_readiness_items = [int]$ownerDecisionReadinessPacket.required_item_count
      owner_decision_readiness_findings = [int]$ownerDecisionReadinessPacket.finding_count
      blocker_resolution_unknowns = [int]$blockerResolutionPlan.unknown_blocker_count
      blocker_resolution_mapped = [int]$blockerResolutionPlan.mapped_blocker_count
      vercel_remediation_actions = [int]$vercelRemediationPlan.remediation_action_count
      vercel_remediation_findings = [int]$vercelRemediationPlan.finding_count
      release_rebaseline_options = [int]$releaseRebaselinePlan.option_count
      release_rebaseline_findings = [int]$releaseRebaselinePlan.finding_count
    }
    vercel = [ordered]@{
      status = $vercelAccess.status
      classification = $vercelAccess.classification
      safe_to_deploy_via_vercel = $vercelReady
      required_fix = $vercelAccess.required_fix
    }
    release_candidate = [ordered]@{
      release_id = $releaseBoundary.release_id
      candidate_source_sha = $releaseBoundary.candidate_source_sha
      current_head_sha = $releaseBoundary.current_head_sha
      head_matches_candidate = $releaseBoundary.head_matches_candidate
      needs_rebaseline = $releaseRebaselinePlan.needs_rebaseline
      owner_decision = $releaseBoundary.owner_decision
      owner_approved = $releaseBoundary.owner_approved
    }
    security = [ordered]@{
      checked = $securityProbe.checked
      status = $securityProbe.status
      passed = $securityProbe.passed
      error = $securityProbe.error
    }
    policy = [ordered]@{
      mutates_repository = $false
      may_cleanup = $false
      may_stage = $false
      may_commit = $false
      may_push = $false
      may_deploy = $false
      may_release = $false
      required_next_action = if ($truthReady) {
        "Run the explicit next gate before any mutation or deployment claim."
      } else {
        "Resolve blockers; do not stage, commit, push, deploy, or claim release readiness."
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
    Write-Host "[project-truth-state] status=$($summary.status)"
    Write-Host "[project-truth-state] truth_ready=$($summary.truth_ready)"
    Write-Host "[project-truth-state] worktree_clean=$($summary.gates.worktree_clean)"
    Write-Host "[project-truth-state] release_boundary_clear=$($summary.gates.release_boundary_clear)"
    Write-Host "[project-truth-state] owner_decision_valid=$($summary.gates.owner_decision_valid)"
    Write-Host "[project-truth-state] split_plan_clear=$($summary.gates.split_plan_clear)"
    Write-Host "[project-truth-state] split_action_packet_valid=$($summary.gates.split_action_packet_valid)"
    Write-Host "[project-truth-state] owner_decision_packet_valid=$($summary.gates.owner_decision_packet_valid)"
    Write-Host "[project-truth-state] owner_decision_candidates_valid=$($summary.gates.owner_decision_candidates_valid)"
    Write-Host "[project-truth-state] owner_action_packet_valid=$($summary.gates.owner_action_packet_valid)"
    Write-Host "[project-truth-state] owner_decision_readiness_packet_valid=$($summary.gates.owner_decision_readiness_packet_valid)"
    Write-Host "[project-truth-state] blocker_resolution_plan_valid=$($summary.gates.blocker_resolution_plan_valid)"
    Write-Host "[project-truth-state] vercel_remediation_plan_valid=$($summary.gates.vercel_remediation_plan_valid)"
    Write-Host "[project-truth-state] release_rebaseline_plan_valid=$($summary.gates.release_rebaseline_plan_valid)"
    Write-Host "[project-truth-state] vercel_access_ready=$($summary.gates.vercel_access_ready)"
    Write-Host "[project-truth-state] security_passed=$($summary.gates.security_passed)"
    Write-Host "[project-truth-state] review_action_matrix_valid=$($summary.gates.review_action_matrix_valid)"
    Write-Host "[project-truth-state] quarantine_action_packet_valid=$($summary.gates.quarantine_action_packet_valid)"
    Write-Host "[project-truth-state] security_review_packet_valid=$($summary.gates.security_review_packet_valid)"
    Write-Host "[project-truth-state] security_review_action_packet_valid=$($summary.gates.security_review_action_packet_valid)"
    Write-Host "[project-truth-state] blockers=$($summary.blockers -join ',')"
  }

  if (-not $truthReady -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}

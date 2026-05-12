param(
  [string]$OwnerDecisionPacketPath = ".phase1-artifacts\worktree-owner-decision-packet-20260510.json",
  [string]$QuarantinePlanPath = ".phase1-artifacts\worktree-quarantine-plan-20260510.json",
  [string]$SplitPlanPath = ".phase1-artifacts\worktree-split-plan-20260510.json",
  [string]$CleanupExecutionPlanPath = ".phase1-artifacts\worktree-cleanup-execution-plan-20260510.json",
  [string]$ReleaseRebaselinePlanPath = ".phase1-artifacts\release-rebaseline-plan-20260511.json",
  [string]$OutputPath = ".phase1-artifacts\worktree-owner-decision-candidates-20260511.json",
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

function Add-Finding([System.Collections.Generic.List[object]]$Findings, [string]$Id, [string]$Expected, [string]$Actual) {
  $Findings.Add([pscustomobject]@{
    id = $Id
    expected = $Expected
    actual = $Actual
  })
}

function New-AllowedActions(
  [bool]$MayMove,
  [bool]$MayDelete,
  [bool]$MayUnstage,
  [bool]$MayStage
) {
  return [ordered]@{
    may_move = $MayMove
    may_delete = $MayDelete
    may_unstage = $MayUnstage
    may_stage = $MayStage
    may_commit = $false
    may_push = $false
    may_deploy = $false
  }
}

function New-Candidate(
  [string]$Id,
  [string]$Strategy,
  [string]$Intent,
  [object]$AllowedActions,
  [string[]]$Preconditions,
  [bool]$ValidForOwnerDecisionVerifier,
  [bool]$CurrentlyActionable
) {
  return [pscustomobject]@{
    id = $Id
    strategy = $Strategy
    intent = $Intent
    decision_payload_preview = [ordered]@{
      decision_id = $Id
      decided_at = "<required-iso8601>"
      approved_by = "<required-owner>"
      strategy = $Strategy
      allowed_actions = $AllowedActions
      notes = "Owner must review current artifacts before copying this candidate into the real decision file."
    }
    preconditions = @($Preconditions)
    valid_for_owner_decision_verifier = $ValidForOwnerDecisionVerifier
    currently_actionable = $CurrentlyActionable
    mutates_repository = $false
  }
}

function Test-ForbiddenActionsFalse([object]$Candidate) {
  $actions = $Candidate.decision_payload_preview.allowed_actions
  return (
    $actions.may_commit -eq $false -and
    $actions.may_push -eq $false -and
    $actions.may_deploy -eq $false
  )
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  Invoke-DependencyVerifier -ScriptName "verify-worktree-owner-decision-packet.ps1" -OutputPath $OwnerDecisionPacketPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-quarantine-plan.ps1" -OutputPath $QuarantinePlanPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-split-plan.ps1" -OutputPath $SplitPlanPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-cleanup-execution-plan.ps1" -OutputPath $CleanupExecutionPlanPath
  Invoke-DependencyVerifier -ScriptName "verify-release-rebaseline-plan.ps1" -OutputPath $ReleaseRebaselinePlanPath

  $ownerDecisionPacket = Read-JsonArtifact -Path $OwnerDecisionPacketPath -Label "owner-decision-packet"
  $quarantinePlan = Read-JsonArtifact -Path $QuarantinePlanPath -Label "quarantine-plan"
  $splitPlan = Read-JsonArtifact -Path $SplitPlanPath -Label "split-plan"
  $cleanupExecutionPlan = Read-JsonArtifact -Path $CleanupExecutionPlanPath -Label "cleanup-execution-plan"
  $releaseRebaselinePlan = Read-JsonArtifact -Path $ReleaseRebaselinePlanPath -Label "release-rebaseline-plan"

  $securityReview = [int]$quarantinePlan.counts.security_review
  $excludeOrQuarantine = [int]$quarantinePlan.counts.exclude_or_quarantine
  $splitRequired = [int]$quarantinePlan.counts.split_required
  $blockingReviewItems = [int]$quarantinePlan.counts.total_blocking_review_items
  $needsRebaseline = ($releaseRebaselinePlan.needs_rebaseline -eq $true)

  $candidates = @(
    New-Candidate `
      -Id "owner-decision-cleanup-first-20260511" `
      -Strategy "cleanup-first" `
      -Intent "Authorize only reviewed cleanup preparation: quarantine/move eligible debug artifacts and normalize staged-vs-worktree conflicts before any commit boundary." `
      -AllowedActions (New-AllowedActions -MayMove $true -MayDelete $false -MayUnstage $true -MayStage $false) `
      -Preconditions @("review security-sensitive paths", "review debug/quarantine paths", "inspect staged-and-modified files") `
      -ValidForOwnerDecisionVerifier $true `
      -CurrentlyActionable ($ownerDecisionPacket.valid -eq $true)
    New-Candidate `
      -Id "owner-decision-evidence-only-rebaseline-20260511" `
      -Strategy "evidence-only-rebaseline" `
      -Intent "Allow staging reviewed evidence-only artifacts after security and split blockers are cleared, while keeping commit/push/deploy blocked." `
      -AllowedActions (New-AllowedActions -MayMove $false -MayDelete $false -MayUnstage $false -MayStage $true) `
      -Preconditions @("security_review=0", "split_required=0", "release-boundary rerun after staging selection") `
      -ValidForOwnerDecisionVerifier $true `
      -CurrentlyActionable ($securityReview -eq 0 -and $splitRequired -eq 0)
    New-Candidate `
      -Id "owner-decision-runtime-rebaseline-20260511" `
      -Strategy "runtime-rebaseline" `
      -Intent "Allow staging reviewed runtime changes only after runtime, security, split, and release-boundary gates are clean." `
      -AllowedActions (New-AllowedActions -MayMove $false -MayDelete $false -MayUnstage $false -MayStage $true) `
      -Preconditions @("security_review=0", "split_required=0", "runtime gates pass", "release rebaseline path selected") `
      -ValidForOwnerDecisionVerifier $true `
      -CurrentlyActionable ($securityReview -eq 0 -and $splitRequired -eq 0 -and -not $needsRebaseline)
    New-Candidate `
      -Id "owner-decision-defer-20260511" `
      -Strategy "defer" `
      -Intent "Keep every mutation blocked and require another reviewed packet before any cleanup or staging." `
      -AllowedActions (New-AllowedActions -MayMove $false -MayDelete $false -MayUnstage $false -MayStage $false) `
      -Preconditions @("blocking_review_items=0 if used as a completion decision") `
      -ValidForOwnerDecisionVerifier ($blockingReviewItems -eq 0) `
      -CurrentlyActionable $false
  )

  $findings = [System.Collections.Generic.List[object]]::new()
  $allowedStrategies = @("cleanup-first", "evidence-only-rebaseline", "runtime-rebaseline", "defer")
  foreach ($candidate in @($candidates)) {
    if ($allowedStrategies -notcontains $candidate.strategy) {
      Add-Finding $findings "strategy_not_allowed:$($candidate.id)" ($allowedStrategies -join ",") ([string]$candidate.strategy)
    }
    if (-not (Test-ForbiddenActionsFalse -Candidate $candidate)) {
      Add-Finding $findings "forbidden_action_enabled:$($candidate.id)" "may_commit/may_push/may_deploy false" "one or more true"
    }
    if ($candidate.decision_payload_preview.approved_by -ne "<required-owner>") {
      Add-Finding $findings "approved_by_not_placeholder:$($candidate.id)" "<required-owner>" ([string]$candidate.decision_payload_preview.approved_by)
    }
    if ($candidate.decision_payload_preview.decided_at -ne "<required-iso8601>") {
      Add-Finding $findings "decided_at_not_placeholder:$($candidate.id)" "<required-iso8601>" ([string]$candidate.decision_payload_preview.decided_at)
    }
  }

  if ($ownerDecisionPacket.valid -ne $true) {
    Add-Finding $findings "owner_decision_packet_valid" "true" ([string]$ownerDecisionPacket.valid)
  }
  if ($cleanupExecutionPlan.ready -ne $true) {
    Add-Finding $findings "cleanup_execution_plan_ready" "true" ([string]$cleanupExecutionPlan.ready)
  }
  if ([int]$cleanupExecutionPlan.candidate_action_count -lt 0) {
    Add-Finding $findings "cleanup_candidate_action_count" ">=0" ([string]$cleanupExecutionPlan.candidate_action_count)
  }
  if ([int]$splitPlan.split_path_count -ne $splitRequired) {
    Add-Finding $findings "split_count_consistency" ([string]$splitRequired) ([string]$splitPlan.split_path_count)
  }
  if ([int]$releaseRebaselinePlan.option_count -ne 4) {
    Add-Finding $findings "release_rebaseline_option_count" "4" ([string]$releaseRebaselinePlan.option_count)
  }

  $valid = ($findings.Count -eq 0)
  $decisionRequired = ($ownerDecisionPacket.decision_required -eq $true)
  $currentlyActionableCount = @($candidates | Where-Object { $_.currently_actionable -eq $true }).Count
  $verifierValidCount = @($candidates | Where-Object { $_.valid_for_owner_decision_verifier -eq $true }).Count
  $status = if ($valid) {
    if ($decisionRequired) { "owner-decision-candidates-valid-blocked" } else { "owner-decision-candidates-valid-ready" }
  } else {
    "owner-decision-candidates-invalid"
  }

  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    status = $status
    valid = $valid
    decision_required = $decisionRequired
    candidate_count = @($candidates).Count
    verifier_valid_candidate_count = $verifierValidCount
    currently_actionable_candidate_count = $currentlyActionableCount
    finding_count = $findings.Count
    findings = @($findings)
    required_decision_file = "docs\analysis\worktree-owner-decision-20260510.json"
    candidates = @($candidates)
    source_artifacts = [ordered]@{
      owner_decision_packet = $OwnerDecisionPacketPath
      quarantine_plan = $QuarantinePlanPath
      split_plan = $SplitPlanPath
      cleanup_execution_plan = $CleanupExecutionPlanPath
      release_rebaseline_plan = $ReleaseRebaselinePlanPath
    }
    current_blockers = [ordered]@{
      security_review = $securityReview
      exclude_or_quarantine = $excludeOrQuarantine
      split_required = $splitRequired
      blocking_review_items = $blockingReviewItems
      needs_rebaseline = $needsRebaseline
    }
    policy = [ordered]@{
      mutates_repository = $false
      executes_requested_actions = $false
      creates_owner_decision = $false
      may_cleanup = $false
      may_stage = $false
      may_commit = $false
      may_push = $false
      may_deploy = $false
      may_release = $false
      required_next_action = "Owner must choose and create the real decision file; this verifier only emits candidates."
    }
    leak_prevention = [ordered]@{
      source_file_contents_included = $false
      secret_values_included = $false
      tokens_included = $false
      env_values_included = $false
      candidate_payloads_are_placeholders = $true
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
    Write-Host "[worktree-owner-decision-candidates] status=$($summary.status)"
    Write-Host "[worktree-owner-decision-candidates] valid=$($summary.valid)"
    Write-Host "[worktree-owner-decision-candidates] decision_required=$($summary.decision_required)"
    Write-Host "[worktree-owner-decision-candidates] candidate_count=$($summary.candidate_count)"
    Write-Host "[worktree-owner-decision-candidates] verifier_valid_candidate_count=$($summary.verifier_valid_candidate_count)"
    Write-Host "[worktree-owner-decision-candidates] currently_actionable_candidate_count=$($summary.currently_actionable_candidate_count)"
    Write-Host "[worktree-owner-decision-candidates] finding_count=$($summary.finding_count)"
    foreach ($finding in @($findings)) {
      Write-Host ("[worktree-owner-decision-candidates] finding={0} expected={1} actual={2}" -f $finding.id, $finding.expected, $finding.actual)
    }
  }

  if (-not $valid -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}

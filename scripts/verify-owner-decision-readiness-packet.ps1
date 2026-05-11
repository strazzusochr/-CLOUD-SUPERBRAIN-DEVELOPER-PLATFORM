param(
  [string]$ReviewActionMatrixPath = ".phase1-artifacts\worktree-review-action-matrix-20260511.json",
  [string]$QuarantineActionPacketPath = ".phase1-artifacts\worktree-quarantine-action-packet-20260511.json",
  [string]$SecurityReviewActionPacketPath = ".phase1-artifacts\worktree-security-review-action-packet-20260511.json",
  [string]$SplitActionPacketPath = ".phase1-artifacts\worktree-split-action-packet-20260511.json",
  [string]$OwnerDecisionPacketPath = ".phase1-artifacts\worktree-owner-decision-packet-20260510.json",
  [string]$OwnerDecisionCandidatesPath = ".phase1-artifacts\worktree-owner-decision-candidates-20260511.json",
  [string]$OwnerActionPacketPath = ".phase1-artifacts\worktree-owner-action-packet-20260511.json",
  [string]$VercelRemediationPlanPath = ".phase1-artifacts\vercel-remediation-plan-20260511.json",
  [string]$ReleaseRebaselinePlanPath = ".phase1-artifacts\release-rebaseline-plan-20260511.json",
  [string]$BlockerResolutionPlanPath = ".phase1-artifacts\blocker-resolution-plan-20260511.json",
  [string]$OutputPath = ".phase1-artifacts\owner-decision-readiness-packet-20260511.json",
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

function New-ReadinessItem(
  [string]$Id,
  [string]$Owner,
  [string]$RequiredAction,
  [string]$SourceArtifact,
  [string]$VerificationGate,
  [int]$UnitCount,
  [bool]$RequiresOwnerDecision,
  [bool]$RequiresCloudAccess
) {
  return [pscustomobject]@{
    id = $Id
    owner = $Owner
    required_action = $RequiredAction
    source_artifact = $SourceArtifact
    verification_gate = $VerificationGate
    unit_count = $UnitCount
    requires_owner_decision = $RequiresOwnerDecision
    requires_cloud_access = $RequiresCloudAccess
    executable_by_this_gate = $false
    mutates_repository = $false
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  Invoke-DependencyVerifier -ScriptName "verify-worktree-review-action-matrix.ps1" -OutputPath $ReviewActionMatrixPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-quarantine-action-packet.ps1" -OutputPath $QuarantineActionPacketPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-security-review-action-packet.ps1" -OutputPath $SecurityReviewActionPacketPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-split-action-packet.ps1" -OutputPath $SplitActionPacketPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-owner-decision-packet.ps1" -OutputPath $OwnerDecisionPacketPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-owner-decision-candidates.ps1" -OutputPath $OwnerDecisionCandidatesPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-owner-action-packet.ps1" -OutputPath $OwnerActionPacketPath
  Invoke-DependencyVerifier -ScriptName "verify-vercel-remediation-plan.ps1" -OutputPath $VercelRemediationPlanPath
  Invoke-DependencyVerifier -ScriptName "verify-release-rebaseline-plan.ps1" -OutputPath $ReleaseRebaselinePlanPath
  Invoke-DependencyVerifier -ScriptName "verify-blocker-resolution-plan.ps1" -OutputPath $BlockerResolutionPlanPath

  $reviewActionMatrix = Read-JsonArtifact -Path $ReviewActionMatrixPath -Label "review-action-matrix"
  $quarantineActionPacket = Read-JsonArtifact -Path $QuarantineActionPacketPath -Label "quarantine-action-packet"
  $securityReviewActionPacket = Read-JsonArtifact -Path $SecurityReviewActionPacketPath -Label "security-review-action-packet"
  $splitActionPacket = Read-JsonArtifact -Path $SplitActionPacketPath -Label "split-action-packet"
  $ownerDecisionPacket = Read-JsonArtifact -Path $OwnerDecisionPacketPath -Label "owner-decision-packet"
  $ownerDecisionCandidates = Read-JsonArtifact -Path $OwnerDecisionCandidatesPath -Label "owner-decision-candidates"
  $ownerActionPacket = Read-JsonArtifact -Path $OwnerActionPacketPath -Label "owner-action-packet"
  $vercelRemediationPlan = Read-JsonArtifact -Path $VercelRemediationPlanPath -Label "vercel-remediation-plan"
  $releaseRebaselinePlan = Read-JsonArtifact -Path $ReleaseRebaselinePlanPath -Label "release-rebaseline-plan"
  $blockerResolutionPlan = Read-JsonArtifact -Path $BlockerResolutionPlanPath -Label "blocker-resolution-plan"

  $findings = [System.Collections.Generic.List[object]]::new()
  $expectedReviewReady = ([int]$reviewActionMatrix.batch_count -eq 0 -and [int]$reviewActionMatrix.unique_path_count -eq 0)
  $expectedBlockerClear = ([int]$blockerResolutionPlan.blocker_count -eq 0)

  Assert-EqualValue $findings "review_action_matrix.valid" $true $reviewActionMatrix.valid
  Assert-EqualValue $findings "review_action_matrix.ready" $expectedReviewReady $reviewActionMatrix.ready
  Assert-EqualValue $findings "review_action_matrix.finding_count" 0 $reviewActionMatrix.finding_count
  Assert-EqualValue $findings "quarantine_action_packet.valid" $true $quarantineActionPacket.valid
  Assert-EqualValue $findings "quarantine_action_packet.ready" $true $quarantineActionPacket.ready
  Assert-EqualValue $findings "quarantine_action_packet.action_count" 0 $quarantineActionPacket.action_count
  Assert-EqualValue $findings "quarantine_action_packet.finding_count" 0 $quarantineActionPacket.finding_count
  Assert-EqualValue $findings "security_review_action_packet.valid" $true $securityReviewActionPacket.valid
  Assert-EqualValue $findings "security_review_action_packet.ready" $true $securityReviewActionPacket.ready
  Assert-EqualValue $findings "security_review_action_packet.action_count" 0 $securityReviewActionPacket.action_count
  Assert-EqualValue $findings "security_review_action_packet.baseline_hotspot_count" 0 $securityReviewActionPacket.baseline_hotspot_count
  Assert-EqualValue $findings "security_review_action_packet.baseline_hotspot_finding_count" 0 $securityReviewActionPacket.baseline_hotspot_finding_count
  Assert-EqualValue $findings "security_review_action_packet.finding_count" 0 $securityReviewActionPacket.finding_count
  Assert-EqualValue $findings "split_action_packet.valid" $true $splitActionPacket.valid
  Assert-EqualValue $findings "split_action_packet.ready" $true $splitActionPacket.ready
  Assert-EqualValue $findings "split_action_packet.action_count" 0 $splitActionPacket.action_count
  Assert-EqualValue $findings "split_action_packet.finding_count" 0 $splitActionPacket.finding_count
  Assert-EqualValue $findings "owner_decision_packet.valid" $true $ownerDecisionPacket.valid
  Assert-EqualValue $findings "owner_decision_packet.decision_required" $false $ownerDecisionPacket.decision_required
  Assert-EqualValue $findings "owner_decision_candidates.valid" $true $ownerDecisionCandidates.valid
  Assert-EqualValue $findings "owner_decision_candidates.candidate_count" 4 $ownerDecisionCandidates.candidate_count
  Assert-EqualValue $findings "owner_decision_candidates.currently_actionable_candidate_count" 2 $ownerDecisionCandidates.currently_actionable_candidate_count
  Assert-EqualValue $findings "owner_action_packet.valid" $true $ownerActionPacket.valid
  Assert-EqualValue $findings "owner_action_packet.ready" $true $ownerActionPacket.ready
  Assert-EqualValue $findings "owner_action_packet.action_count" 0 $ownerActionPacket.action_count
  Assert-EqualValue $findings "vercel_remediation_plan.valid" $true $vercelRemediationPlan.valid
  Assert-EqualValue $findings "vercel_remediation_plan.ready" $true $vercelRemediationPlan.ready
  Assert-EqualValue $findings "vercel_remediation_plan.remediation_action_count" 1 $vercelRemediationPlan.remediation_action_count
  Assert-EqualValue $findings "release_rebaseline_plan.valid" $true $releaseRebaselinePlan.valid
  Assert-EqualValue $findings "release_rebaseline_plan.option_count" 4 $releaseRebaselinePlan.option_count
  Assert-EqualValue $findings "blocker_resolution_plan.valid" $true $blockerResolutionPlan.valid
  Assert-EqualValue $findings "blocker_resolution_plan.clear" $expectedBlockerClear $blockerResolutionPlan.clear
  Assert-EqualValue $findings "blocker_resolution_plan.unknown_blocker_count" 0 $blockerResolutionPlan.unknown_blocker_count

  $readinessItems = @(
    New-ReadinessItem `
      -Id "owner-decision-recorded" `
      -Owner "owner" `
      -RequiredAction "Owner decision file is present; keep it valid while resolving remaining cleanup, security, split, and rebaseline items." `
      -SourceArtifact $OwnerActionPacketPath `
      -VerificationGate "verify-worktree-owner-decision.ps1" `
      -UnitCount ([int]$ownerActionPacket.action_count) `
      -RequiresOwnerDecision $false `
      -RequiresCloudAccess $false
    New-ReadinessItem `
      -Id "resolve-review-batches" `
      -Owner "repo-owner" `
      -RequiredAction "Resolve each cleanup-plan review batch before cleanup, staging, commit, push, deploy, or release." `
      -SourceArtifact $ReviewActionMatrixPath `
      -VerificationGate "verify-worktree-review-action-matrix.ps1" `
      -UnitCount ([int]$reviewActionMatrix.batch_count) `
      -RequiresOwnerDecision (-not ($reviewActionMatrix.ready -eq $true)) `
      -RequiresCloudAccess $false
    New-ReadinessItem `
      -Id "resolve-quarantine-actions" `
      -Owner "repo-owner" `
      -RequiredAction "Quarantine actions are clear; keep debug/browser helpers outside release scope." `
      -SourceArtifact $QuarantineActionPacketPath `
      -VerificationGate "verify-worktree-quarantine-action-packet.ps1" `
      -UnitCount ([int]$quarantineActionPacket.action_count) `
      -RequiresOwnerDecision $false `
      -RequiresCloudAccess $false
    New-ReadinessItem `
      -Id "resolve-security-review-actions" `
      -Owner "security-owner" `
      -RequiredAction "Security-review paths and detect-secrets baseline hotspots are cleared by docs\analysis\security-review-clearance-20260511.json; keep security gates green." `
      -SourceArtifact $SecurityReviewActionPacketPath `
      -VerificationGate "verify-worktree-security-review-action-packet.ps1" `
      -UnitCount ([int]$securityReviewActionPacket.action_count + [int]$securityReviewActionPacket.baseline_hotspot_count) `
      -RequiresOwnerDecision $false `
      -RequiresCloudAccess $false
    New-ReadinessItem `
      -Id "resolve-split-actions" `
      -Owner "repo-owner" `
      -RequiredAction "Split normalization is clear; keep staged-and-modified count at zero while resolving remaining review batches." `
      -SourceArtifact $SplitActionPacketPath `
      -VerificationGate "verify-worktree-split-action-packet.ps1" `
      -UnitCount ([int]$splitActionPacket.action_count) `
      -RequiresOwnerDecision $false `
      -RequiresCloudAccess $false
    New-ReadinessItem `
      -Id "confirm-vercel-access-ready" `
      -Owner "cloud-owner" `
      -RequiredAction "Vercel access is ready; keep verify-vercel-access.ps1 green before any release-boundary rebaseline." `
      -SourceArtifact $VercelRemediationPlanPath `
      -VerificationGate "verify-vercel-access.ps1" `
      -UnitCount ([int]$vercelRemediationPlan.remediation_action_count) `
      -RequiresOwnerDecision $false `
      -RequiresCloudAccess $true
    New-ReadinessItem `
      -Id "choose-release-rebaseline-path" `
      -Owner "release-owner" `
      -RequiredAction "Choose one release rebaseline path with explicit owner approval before any release claim." `
      -SourceArtifact $ReleaseRebaselinePlanPath `
      -VerificationGate "verify-release-rebaseline-plan.ps1" `
      -UnitCount ([int]$releaseRebaselinePlan.option_count) `
      -RequiresOwnerDecision (-not ($releaseRebaselinePlan.ready -eq $true)) `
      -RequiresCloudAccess $true
    New-ReadinessItem `
      -Id "resolve-mapped-blockers" `
      -Owner "repo-owner" `
      -RequiredAction "Resolve every mapped blocker by owner/category and rerun release-boundary after each reviewed change." `
      -SourceArtifact $BlockerResolutionPlanPath `
      -VerificationGate "verify-blocker-resolution-plan.ps1" `
      -UnitCount ([int]$blockerResolutionPlan.mapped_blocker_count) `
      -RequiresOwnerDecision (-not ($blockerResolutionPlan.clear -eq $true)) `
      -RequiresCloudAccess $true
  )

  $valid = ($findings.Count -eq 0)
  $ready = ($valid `
    -and $ownerDecisionPacket.decision_required -ne $true `
    -and $ownerActionPacket.ready -eq $true `
    -and $reviewActionMatrix.ready -eq $true `
    -and $quarantineActionPacket.ready -eq $true `
    -and $securityReviewActionPacket.ready -eq $true `
    -and $splitActionPacket.ready -eq $true `
    -and $vercelRemediationPlan.ready -eq $true `
    -and $releaseRebaselinePlan.ready -eq $true `
    -and $blockerResolutionPlan.clear -eq $true)
  $status = if ($valid) {
    if ($ready) { "owner-decision-readiness-ready" } else { "owner-decision-readiness-valid-blocked" }
  } else {
    "owner-decision-readiness-invalid"
  }

  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    status = $status
    valid = $valid
    ready = $ready
    finding_count = $findings.Count
    findings = @($findings)
    required_item_count = @($readinessItems).Count
    required_items = @($readinessItems)
    counts = [ordered]@{
      review_action_matrix_batches = [int]$reviewActionMatrix.batch_count
      review_action_matrix_unique_paths = [int]$reviewActionMatrix.unique_path_count
      review_action_matrix_path_references = [int]$reviewActionMatrix.batch_path_reference_count
      quarantine_action_count = [int]$quarantineActionPacket.action_count
      security_review_action_count = [int]$securityReviewActionPacket.action_count
      security_review_baseline_hotspot_count = [int]$securityReviewActionPacket.baseline_hotspot_count
      security_review_baseline_hotspot_findings = [int]$securityReviewActionPacket.baseline_hotspot_finding_count
      split_action_count = [int]$splitActionPacket.action_count
      owner_action_count = [int]$ownerActionPacket.action_count
      owner_decision_candidate_options = [int]$ownerDecisionCandidates.candidate_count
      owner_decision_currently_actionable_candidates = [int]$ownerDecisionCandidates.currently_actionable_candidate_count
      vercel_remediation_actions = [int]$vercelRemediationPlan.remediation_action_count
      release_rebaseline_options = [int]$releaseRebaselinePlan.option_count
      blocker_resolution_mapped = [int]$blockerResolutionPlan.mapped_blocker_count
      blocker_resolution_unknowns = [int]$blockerResolutionPlan.unknown_blocker_count
    }
    source_artifacts = [ordered]@{
      review_action_matrix = $ReviewActionMatrixPath
      quarantine_action_packet = $QuarantineActionPacketPath
      security_review_action_packet = $SecurityReviewActionPacketPath
      split_action_packet = $SplitActionPacketPath
      owner_decision_packet = $OwnerDecisionPacketPath
      owner_decision_candidates = $OwnerDecisionCandidatesPath
      owner_action_packet = $OwnerActionPacketPath
      vercel_remediation_plan = $VercelRemediationPlanPath
      release_rebaseline_plan = $ReleaseRebaselinePlanPath
      blocker_resolution_plan = $BlockerResolutionPlanPath
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
      required_next_action = if ($ready) {
        "Owner-decision readiness is clear; rerun release-boundary before any mutation."
      } else {
        "Resolve required items; do not stage, commit, push, deploy, release, or claim readiness."
      }
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
    $summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
  }

  if ($JsonOnly) {
    $summary | ConvertTo-Json -Depth 10
  } else {
    Write-Host "[owner-decision-readiness-packet] status=$($summary.status)"
    Write-Host "[owner-decision-readiness-packet] valid=$($summary.valid)"
    Write-Host "[owner-decision-readiness-packet] ready=$($summary.ready)"
    Write-Host "[owner-decision-readiness-packet] required_item_count=$($summary.required_item_count)"
    Write-Host "[owner-decision-readiness-packet] finding_count=$($summary.finding_count)"
    foreach ($finding in @($findings)) {
      Write-Host ("[owner-decision-readiness-packet] finding={0} expected={1} actual={2}" -f $finding.id, $finding.expected, $finding.actual)
    }
  }

  if (-not $valid -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}

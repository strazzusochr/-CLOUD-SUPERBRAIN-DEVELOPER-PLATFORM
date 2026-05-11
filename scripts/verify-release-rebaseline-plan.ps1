param(
  [string]$ReleaseBoundaryPath = ".phase1-artifacts\worktree-release-boundary-20260510.json",
  [string]$OwnerDecisionPacketPath = ".phase1-artifacts\worktree-owner-decision-packet-20260510.json",
  [string]$BlockerResolutionPlanPath = ".phase1-artifacts\blocker-resolution-plan-20260511.json",
  [string]$ReleaseRebaselineDecisionPath = "docs\analysis\release-rebaseline-decision-20260511.json",
  [string]$OutputPath = ".phase1-artifacts\release-rebaseline-plan-20260511.json",
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

function Read-OptionalJsonArtifact([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    return $null
  }

  return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

function New-RebaselineOption(
  [string]$Id,
  [string]$Owner,
  [string]$Action,
  [string]$WhenToUse,
  [string[]]$VerificationGates,
  [bool]$RequiresOwnerDecision,
  [bool]$RequiresCleanWorktree,
  [bool]$RequiresCloudAccess,
  [bool]$AllowedByThisGate
) {
  return [pscustomobject]@{
    id = $Id
    owner = $Owner
    action = $Action
    when_to_use = $WhenToUse
    verification_gates = @($VerificationGates)
    requires_owner_decision = $RequiresOwnerDecision
    requires_clean_worktree = $RequiresCleanWorktree
    requires_cloud_access = $RequiresCloudAccess
    allowed_by_this_gate = $AllowedByThisGate
    mutates_repository = $false
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  Invoke-DependencyVerifier -ScriptName "verify-worktree-release-boundary.ps1" -OutputPath $ReleaseBoundaryPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-owner-decision-packet.ps1" -OutputPath $OwnerDecisionPacketPath
  Invoke-DependencyVerifier -ScriptName "verify-blocker-resolution-plan.ps1" -OutputPath $BlockerResolutionPlanPath

  $releaseBoundary = Read-JsonArtifact -Path $ReleaseBoundaryPath -Label "release-boundary"
  $ownerDecisionPacket = Read-JsonArtifact -Path $OwnerDecisionPacketPath -Label "owner-decision-packet"
  $blockerResolutionPlan = Read-JsonArtifact -Path $BlockerResolutionPlanPath -Label "blocker-resolution-plan"
  $releaseRebaselineDecision = Read-OptionalJsonArtifact -Path $ReleaseRebaselineDecisionPath

  $findings = [System.Collections.Generic.List[object]]::new()
  $candidateSha = [string]$releaseBoundary.candidate_source_sha
  $currentHeadSha = [string]$releaseBoundary.current_head_sha
  $headMatchesCandidate = ($releaseBoundary.head_matches_candidate -eq $true)
  $needsRebaseline = (-not $headMatchesCandidate)

  if ([string]::IsNullOrWhiteSpace($candidateSha)) {
    Add-Finding $findings "candidate_source_sha_missing" "non-empty candidate source sha" "missing"
  }
  if ([string]::IsNullOrWhiteSpace($currentHeadSha)) {
    Add-Finding $findings "current_head_sha_missing" "non-empty current head sha" "missing"
  }
  if ($needsRebaseline -and @($releaseBoundary.blockers) -notcontains "current_head_does_not_match_candidate_source_sha") {
    Add-Finding $findings "missing_sha_mismatch_blocker" "current_head_does_not_match_candidate_source_sha" "missing"
  }
  if ($ownerDecisionPacket.valid -ne $true) {
    Add-Finding $findings "owner_decision_packet_valid" "true" ([string]$ownerDecisionPacket.valid)
  }
  if ($blockerResolutionPlan.valid -ne $true) {
    Add-Finding $findings "blocker_resolution_plan_valid" "true" ([string]$blockerResolutionPlan.valid)
  }

  $options = @(
    New-RebaselineOption `
      -Id "keep-rc1-and-restore-head" `
      -Owner "release-owner" `
      -Action "Keep the existing RC1 source SHA and explicitly restore/rebuild the worktree to that source before any new release claim." `
      -WhenToUse "Use only if RC1 remains the intended release source and current HEAD drift is accidental." `
      -VerificationGates @("verify-worktree-release-boundary.ps1", "verify.ps1 -Suite release-boundary") `
      -RequiresOwnerDecision $true `
      -RequiresCleanWorktree $true `
      -RequiresCloudAccess $false `
      -AllowedByThisGate $false
    New-RebaselineOption `
      -Id "create-new-candidate-from-current-head" `
      -Owner "release-owner" `
      -Action "Create a new release candidate artifact from the current reviewed HEAD after worktree cleanup and owner approval." `
      -WhenToUse "Use when current HEAD intentionally supersedes RC1." `
      -VerificationGates @("verify-worktree-release-boundary.ps1", "verify.ps1 -Suite release-candidate") `
      -RequiresOwnerDecision $true `
      -RequiresCleanWorktree $true `
      -RequiresCloudAccess $true `
      -AllowedByThisGate $false
    New-RebaselineOption `
      -Id "evidence-only-rebaseline" `
      -Owner "repo-owner" `
      -Action "Refresh truth/evidence artifacts to describe the current dirty state without changing release eligibility." `
      -WhenToUse "Use when another reviewer needs an exact current-state handoff but release remains blocked." `
      -VerificationGates @("verify-project-truth-state.ps1", "verify-project-truth-consistency.ps1", "verify-external-review-packet.ps1") `
      -RequiresOwnerDecision $true `
      -RequiresCleanWorktree $false `
      -RequiresCloudAccess $false `
      -AllowedByThisGate $false
    New-RebaselineOption `
      -Id "runtime-rebaseline-after-clean-sweep" `
      -Owner "release-owner" `
      -Action "After cleanup, rerun runtime, hosted, security, and release-candidate suites before replacing the release baseline." `
      -WhenToUse "Use when the release baseline must follow the implemented runtime rather than the historical RC1 artifact." `
      -VerificationGates @("verify.ps1 -Suite security", "verify.ps1 -Suite hosted-core", "verify.ps1 -Suite phase5", "verify.ps1 -Suite release-boundary") `
      -RequiresOwnerDecision $true `
      -RequiresCleanWorktree $true `
      -RequiresCloudAccess $true `
      -AllowedByThisGate $false
  )

  $decisionPresent = ($null -ne $releaseRebaselineDecision)
  $decisionValid = $false
  $selectedOption = $null
  if ($decisionPresent) {
    $selectedOption = [string]$releaseRebaselineDecision.selected_option
    $allowedOptionIds = @($options | Select-Object -ExpandProperty id)
    if ($allowedOptionIds -notcontains $selectedOption) {
      Add-Finding $findings "release_rebaseline_decision.selected_option" ($allowedOptionIds -join ",") $selectedOption
    }
    if ($releaseRebaselineDecision.release_claim_allowed -ne $false) {
      Add-Finding $findings "release_rebaseline_decision.release_claim_allowed" "false" ([string]$releaseRebaselineDecision.release_claim_allowed)
    }
    foreach ($flag in @("may_stage", "may_commit", "may_push", "may_deploy", "may_release")) {
      if ($releaseRebaselineDecision.$flag -ne $false) {
        Add-Finding $findings "release_rebaseline_decision.$flag" "false" ([string]$releaseRebaselineDecision.$flag)
      }
    }
    if ([string]::IsNullOrWhiteSpace([string]$releaseRebaselineDecision.approved_by)) {
      Add-Finding $findings "release_rebaseline_decision.approved_by" "non-empty" "empty"
    }
    $decisionValid = ($findings.Count -eq 0 -and $allowedOptionIds -contains $selectedOption)
  }

  $valid = ($findings.Count -eq 0)
  $ready = ($valid -and -not $needsRebaseline -and $releaseBoundary.release_boundary_clear -eq $true)
  $status = if ($valid) {
    if ($ready) {
      "release-rebaseline-ready"
    } elseif ($decisionValid -and $selectedOption -eq "evidence-only-rebaseline") {
      "release-rebaseline-evidence-only-selected-blocked"
    } else {
      "release-rebaseline-valid-blocked"
    }
  } else {
    "release-rebaseline-invalid"
  }

  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    status = $status
    valid = $valid
    ready = $ready
    needs_rebaseline = $needsRebaseline
    finding_count = $findings.Count
    findings = @($findings)
    release_id = $releaseBoundary.release_id
    candidate_source_sha = $candidateSha
    current_head_sha = $currentHeadSha
    head_matches_candidate = $headMatchesCandidate
    decision_present = $decisionPresent
    decision_valid = $decisionValid
    selected_option = $selectedOption
    option_count = @($options).Count
    options = @($options)
    source_artifacts = [ordered]@{
      release_boundary = $ReleaseBoundaryPath
      owner_decision_packet = $OwnerDecisionPacketPath
      blocker_resolution_plan = $BlockerResolutionPlanPath
      release_rebaseline_decision = $ReleaseRebaselineDecisionPath
    }
    policy = [ordered]@{
      mutates_repository = $false
      executes_requested_actions = $false
      may_cleanup = $false
      may_stage = $false
      may_commit = $false
      may_push = $false
      may_deploy = $false
      may_release = $false
      required_next_action = if ($needsRebaseline) {
        "Choose one rebaseline path with an explicit owner decision; do not mutate git or release artifacts from this gate."
      } else {
        "No SHA rebaseline is required; continue to the next release-boundary gate."
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
    Write-Host "[release-rebaseline-plan] status=$($summary.status)"
    Write-Host "[release-rebaseline-plan] valid=$($summary.valid)"
    Write-Host "[release-rebaseline-plan] ready=$($summary.ready)"
    Write-Host "[release-rebaseline-plan] needs_rebaseline=$($summary.needs_rebaseline)"
    Write-Host "[release-rebaseline-plan] option_count=$($summary.option_count)"
    Write-Host "[release-rebaseline-plan] finding_count=$($summary.finding_count)"
  }

  if (-not $valid -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}

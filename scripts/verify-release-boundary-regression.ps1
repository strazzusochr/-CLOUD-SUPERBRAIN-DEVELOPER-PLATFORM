param(
  [string]$OutputPath = ".phase1-artifacts\release-boundary-regression-20260510.json",
  [switch]$ReportOnly,
  [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"

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

function Assert-ContainsValue(
  [System.Collections.Generic.List[object]]$Findings,
  [string]$Id,
  [object[]]$Values,
  [string]$Expected
) {
  if (@($Values) -notcontains $Expected) {
    Add-Finding -Findings $Findings -Id $Id -Expected $Expected -Actual "missing"
  }
}

function Assert-TextContains(
  [System.Collections.Generic.List[object]]$Findings,
  [string]$Id,
  [string]$Content,
  [string]$Expected
) {
  if ($Content -notlike "*$Expected*") {
    Add-Finding -Findings $Findings -Id $Id -Expected $Expected -Actual "missing"
  }
}

function Read-JsonArtifact([string]$Path, [string]$Label) {
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Missing $Label artifact: $Path"
  }

  return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

function Test-PowerShellParser([string]$ScriptPath, [System.Collections.Generic.List[object]]$Findings) {
  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tokens, [ref]$errors) | Out-Null
  if ($errors.Count -gt 0) {
    Add-Finding -Findings $Findings -Id "parser:$ScriptPath" -Expected "0 parser errors" -Actual ([string]$errors.Count)
  }
}

function Invoke-ReportOnlyVerifier([string]$ScriptName) {
  $scriptPath = Join-Path $PSScriptRoot $ScriptName
  if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Missing verifier script: $ScriptName"
  }

  $global:LASTEXITCODE = 0
  & $scriptPath -ReportOnly | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "$ScriptName exited with code $LASTEXITCODE"
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  $findings = [System.Collections.Generic.List[object]]::new()
  $parserTargets = @(
    "scripts\verify-worktree-review-action-matrix.ps1",
    "scripts\verify-worktree-cleanup-execution-plan.ps1",
    "scripts\verify-worktree-split-plan.ps1",
    "scripts\verify-worktree-split-action-packet.ps1",
    "scripts\verify-worktree-quarantine-action-packet.ps1",
    "scripts\verify-worktree-security-review-packet.ps1",
    "scripts\verify-worktree-security-review-action-packet.ps1",
    "scripts\verify-worktree-owner-decision.ps1",
    "scripts\verify-worktree-owner-decision-packet.ps1",
    "scripts\verify-worktree-owner-decision-candidates.ps1",
    "scripts\verify-worktree-owner-action-packet.ps1",
    "scripts\verify-owner-decision-readiness-packet.ps1",
    "scripts\verify-vercel-project-git-readiness.ps1",
    "scripts\verify-vercel-git-link.ps1",
    "scripts\verify-vercel-remediation-plan.ps1",
    "scripts\verify-release-rebaseline-plan.ps1",
    "scripts\verify-blocker-resolution-plan.ps1",
    "scripts\verify-project-truth-state.ps1",
    "scripts\verify-project-truth-consistency.ps1",
    "scripts\verify-external-review-packet.ps1",
    "scripts\verify-evidence-artifact-safety.ps1"
  )

  foreach ($target in $parserTargets) {
    Test-PowerShellParser -ScriptPath $target -Findings $findings
  }

  foreach ($scriptName in @(
    "verify-worktree-review-action-matrix.ps1",
    "verify-worktree-cleanup-execution-plan.ps1",
    "verify-worktree-split-plan.ps1",
    "verify-worktree-split-action-packet.ps1",
    "verify-worktree-quarantine-action-packet.ps1",
    "verify-worktree-security-review-packet.ps1",
    "verify-worktree-security-review-action-packet.ps1",
    "verify-worktree-owner-decision.ps1",
    "verify-worktree-owner-decision-packet.ps1",
    "verify-worktree-owner-decision-candidates.ps1",
    "verify-worktree-owner-action-packet.ps1",
    "verify-owner-decision-readiness-packet.ps1",
    "verify-vercel-project-git-readiness.ps1",
    "verify-vercel-git-link.ps1",
    "verify-vercel-remediation-plan.ps1",
    "verify-release-rebaseline-plan.ps1",
    "verify-blocker-resolution-plan.ps1",
    "verify-project-truth-state.ps1",
    "verify-project-truth-consistency.ps1",
    "verify-external-review-packet.ps1",
    "verify-evidence-artifact-safety.ps1"
  )) {
    Invoke-ReportOnlyVerifier -ScriptName $scriptName
  }

  $reviewActionMatrix = Read-JsonArtifact -Path ".phase1-artifacts\worktree-review-action-matrix-20260511.json" -Label "review-action-matrix"
  $cleanupExecution = Read-JsonArtifact -Path ".phase1-artifacts\worktree-cleanup-execution-plan-20260510.json" -Label "cleanup-execution-plan"
  $splitPlan = Read-JsonArtifact -Path ".phase1-artifacts\worktree-split-plan-20260510.json" -Label "split-plan"
  $splitActionPacket = Read-JsonArtifact -Path ".phase1-artifacts\worktree-split-action-packet-20260511.json" -Label "split-action-packet"
  $quarantineActionPacket = Read-JsonArtifact -Path ".phase1-artifacts\worktree-quarantine-action-packet-20260511.json" -Label "quarantine-action-packet"
  $securityReviewPacket = Read-JsonArtifact -Path ".phase1-artifacts\worktree-security-review-packet-20260511.json" -Label "security-review-packet"
  $securityReviewActionPacket = Read-JsonArtifact -Path ".phase1-artifacts\worktree-security-review-action-packet-20260511.json" -Label "security-review-action-packet"
  $ownerDecision = Read-JsonArtifact -Path ".phase1-artifacts\worktree-owner-decision-20260510.json" -Label "owner-decision"
  $ownerPacket = Read-JsonArtifact -Path ".phase1-artifacts\worktree-owner-decision-packet-20260510.json" -Label "owner-decision-packet"
  $ownerCandidates = Read-JsonArtifact -Path ".phase1-artifacts\worktree-owner-decision-candidates-20260511.json" -Label "owner-decision-candidates"
  $ownerActionPacket = Read-JsonArtifact -Path ".phase1-artifacts\worktree-owner-action-packet-20260511.json" -Label "owner-action-packet"
  $ownerReadinessPacket = Read-JsonArtifact -Path ".phase1-artifacts\owner-decision-readiness-packet-20260511.json" -Label "owner-decision-readiness-packet"
  $vercelProjectGitReadiness = Read-JsonArtifact -Path ".phase1-artifacts\vercel-project-git-readiness-20260513.json" -Label "vercel-project-git-readiness"
  $vercelGitLink = Read-JsonArtifact -Path ".phase1-artifacts\vercel-git-link-20260513.json" -Label "vercel-git-link"
  $vercelRemediation = Read-JsonArtifact -Path ".phase1-artifacts\vercel-remediation-plan-20260511.json" -Label "vercel-remediation-plan"
  $releaseRebaseline = Read-JsonArtifact -Path ".phase1-artifacts\release-rebaseline-plan-20260511.json" -Label "release-rebaseline-plan"
  $resolutionPlan = Read-JsonArtifact -Path ".phase1-artifacts\blocker-resolution-plan-20260511.json" -Label "blocker-resolution-plan"
  $truth = Read-JsonArtifact -Path ".phase1-artifacts\project-truth-state-20260510.json" -Label "project-truth-state"
  $consistency = Read-JsonArtifact -Path ".phase1-artifacts\project-truth-consistency-20260510.json" -Label "project-truth-consistency"
  $reviewPacket = Read-JsonArtifact -Path ".phase1-artifacts\external-review-packet-20260510.json" -Label "external-review-packet"
  $artifactSafety = Read-JsonArtifact -Path ".phase1-artifacts\evidence-artifact-safety-20260510.json" -Label "evidence-artifact-safety"
  $ownerDecisionVerifierContent = Get-Content -LiteralPath "scripts\verify-worktree-owner-decision.ps1" -Raw
  $ownerDecisionSchema = Read-JsonArtifact -Path "docs\analysis\WORKTREE_OWNER_DECISION_SCHEMA_2026-05-11.json" -Label "owner-decision-schema"

  Assert-EqualValue $findings "review_matrix.status" "review-action-matrix-clear" $reviewActionMatrix.status
  Assert-EqualValue $findings "review_matrix.valid" $true $reviewActionMatrix.valid
  Assert-EqualValue $findings "review_matrix.ready" $true $reviewActionMatrix.ready
  Assert-EqualValue $findings "review_matrix.batch_count" 0 $reviewActionMatrix.batch_count
  Assert-EqualValue $findings "review_matrix.finding_count" 0 $reviewActionMatrix.finding_count

  Assert-EqualValue $findings "cleanup.status" "cleanup-execution-plan-ready" $cleanupExecution.status
  Assert-EqualValue $findings "cleanup.ready" $true $cleanupExecution.ready
  Assert-EqualValue $findings "cleanup.candidate_action_count" 0 $cleanupExecution.candidate_action_count
  Assert-EqualValue $findings "cleanup.blocker_count" 0 (@($cleanupExecution.blockers).Count)

  Assert-EqualValue $findings "split.status" "split-plan-clear" $splitPlan.status
  Assert-EqualValue $findings "split.clear" $true $splitPlan.clear
  Assert-EqualValue $findings "split.split_path_count" 0 $splitPlan.split_path_count
  Assert-EqualValue $findings "split.blocker_count" 0 (@($splitPlan.blockers).Count)

  Assert-EqualValue $findings "split_action.status" "split-action-packet-clear" $splitActionPacket.status
  Assert-EqualValue $findings "split_action.valid" $true $splitActionPacket.valid
  Assert-EqualValue $findings "split_action.ready" $true $splitActionPacket.ready
  Assert-EqualValue $findings "split_action.action_count" 0 $splitActionPacket.action_count
  Assert-EqualValue $findings "split_action.finding_count" 0 $splitActionPacket.finding_count

  Assert-EqualValue $findings "quarantine_action.status" "quarantine-action-packet-clear" $quarantineActionPacket.status
  Assert-EqualValue $findings "quarantine_action.valid" $true $quarantineActionPacket.valid
  Assert-EqualValue $findings "quarantine_action.ready" $true $quarantineActionPacket.ready
  Assert-EqualValue $findings "quarantine_action.action_count" 0 $quarantineActionPacket.action_count
  Assert-EqualValue $findings "quarantine_action.finding_count" 0 $quarantineActionPacket.finding_count

  Assert-EqualValue $findings "security_review.status" "security-review-packet-clear" $securityReviewPacket.status
  Assert-EqualValue $findings "security_review.valid" $true $securityReviewPacket.valid
  Assert-EqualValue $findings "security_review.ready" $true $securityReviewPacket.ready
  Assert-EqualValue $findings "security_review.security_review_count" 0 $securityReviewPacket.security_review_count
  Assert-EqualValue $findings "security_review.security_probe_passed" $true $securityReviewPacket.security_probe.passed
  Assert-EqualValue $findings "security_review.finding_count" 0 $securityReviewPacket.finding_count

  Assert-EqualValue $findings "security_review_action.status" "security-review-action-packet-clear" $securityReviewActionPacket.status
  Assert-EqualValue $findings "security_review_action.valid" $true $securityReviewActionPacket.valid
  Assert-EqualValue $findings "security_review_action.ready" $true $securityReviewActionPacket.ready
  Assert-EqualValue $findings "security_review_action.action_count" 0 $securityReviewActionPacket.action_count
  Assert-EqualValue $findings "security_review_action.baseline_hotspot_count" 0 $securityReviewActionPacket.baseline_hotspot_count
  Assert-EqualValue $findings "security_review_action.baseline_hotspot_finding_count" 0 $securityReviewActionPacket.baseline_hotspot_finding_count
  Assert-EqualValue $findings "security_review_action.security_probe_passed" $true $securityReviewActionPacket.security_probe.passed
  Assert-EqualValue $findings "security_review_action.finding_count" 0 $securityReviewActionPacket.finding_count

  Assert-EqualValue $findings "owner_decision.status" "owner-decision-valid-mutation-authorized" $ownerDecision.status
  Assert-EqualValue $findings "owner_decision.decision_present" $true $ownerDecision.decision_present
  Assert-EqualValue $findings "owner_decision.decision_valid" $true $ownerDecision.decision_valid
  Assert-EqualValue $findings "owner_decision.strategy" "cleanup-first" $ownerDecision.strategy
  Assert-EqualValue $findings "owner_decision.schema_present" $true $ownerDecision.schema_present
  Assert-TextContains $findings "owner_decision_hardening.root_extra" $ownerDecisionVerifierContent "root_property_not_allowed"
  Assert-TextContains $findings "owner_decision_hardening.action_extra" $ownerDecisionVerifierContent "allowed_actions_property_not_allowed"
  Assert-TextContains $findings "owner_decision_hardening.scope_extra" $ownerDecisionVerifierContent "scope_property_not_allowed"
  Assert-EqualValue $findings "owner_schema.additional_properties_root" $false $ownerDecisionSchema.additionalProperties
  Assert-EqualValue $findings "owner_schema.additional_properties_actions" $false $ownerDecisionSchema.properties.allowed_actions.additionalProperties
  Assert-EqualValue $findings "owner_schema.additional_properties_scope" $false $ownerDecisionSchema.properties.scope.additionalProperties

  Assert-EqualValue $findings "owner_packet.status" "owner-decision-packet-valid-ready" $ownerPacket.status
  Assert-EqualValue $findings "owner_packet.valid" $true $ownerPacket.valid
  Assert-EqualValue $findings "owner_packet.decision_required" $false $ownerPacket.decision_required
  Assert-EqualValue $findings "owner_packet.finding_count" 0 $ownerPacket.finding_count

  Assert-EqualValue $findings "owner_candidates.status" "owner-decision-candidates-valid-ready" $ownerCandidates.status
  Assert-EqualValue $findings "owner_candidates.valid" $true $ownerCandidates.valid
  Assert-EqualValue $findings "owner_candidates.decision_required" $false $ownerCandidates.decision_required
  Assert-EqualValue $findings "owner_candidates.candidate_count" 4 $ownerCandidates.candidate_count
  Assert-EqualValue $findings "owner_candidates.verifier_valid_candidate_count" 4 $ownerCandidates.verifier_valid_candidate_count
  Assert-EqualValue $findings "owner_candidates.finding_count" 0 $ownerCandidates.finding_count

  Assert-EqualValue $findings "owner_action.status" "owner-action-packet-valid-ready" $ownerActionPacket.status
  Assert-EqualValue $findings "owner_action.valid" $true $ownerActionPacket.valid
  Assert-EqualValue $findings "owner_action.ready" $true $ownerActionPacket.ready
  Assert-EqualValue $findings "owner_action.decision_required" $false $ownerActionPacket.decision_required
  Assert-EqualValue $findings "owner_action.action_count" 0 $ownerActionPacket.action_count
  Assert-EqualValue $findings "owner_action.candidate_count" 4 $ownerActionPacket.candidate_count
  Assert-EqualValue $findings "owner_action.finding_count" 0 $ownerActionPacket.finding_count

  Assert-EqualValue $findings "owner_readiness.status" "owner-decision-readiness-ready" $ownerReadinessPacket.status
  Assert-EqualValue $findings "owner_readiness.valid" $true $ownerReadinessPacket.valid
  Assert-EqualValue $findings "owner_readiness.ready" $true $ownerReadinessPacket.ready
  Assert-EqualValue $findings "owner_readiness.required_item_count" 8 $ownerReadinessPacket.required_item_count
  Assert-EqualValue $findings "owner_readiness.finding_count" 0 $ownerReadinessPacket.finding_count

  Assert-EqualValue $findings "vercel_project_git.status" "ready" $vercelProjectGitReadiness.status
  Assert-EqualValue $findings "vercel_project_git.ready" $true $vercelProjectGitReadiness.ready
  Assert-EqualValue $findings "vercel_project_git.classification" "project_link_git_config_ready" $vercelProjectGitReadiness.classification
  Assert-EqualValue $findings "vercel_project_git.blocking_failure_count" 0 $vercelProjectGitReadiness.blocking_failure_count
  Assert-EqualValue $findings "vercel_project_git.no_secrets" $false $vercelProjectGitReadiness.leak_prevention.secret_values_included

  Assert-EqualValue $findings "vercel_git_link.status" "ready" $vercelGitLink.status
  Assert-EqualValue $findings "vercel_git_link.classification" "vercel_git_link_ready" $vercelGitLink.classification
  Assert-EqualValue $findings "vercel_git_link.safe_for_git_auto_deploy" $true $vercelGitLink.safe_for_git_auto_deploy
  Assert-EqualValue $findings "vercel_git_link.http_status" 200 $vercelGitLink.http_status
  Assert-EqualValue $findings "vercel_git_link.root_directory" "apps/frontend" $vercelGitLink.observed.rootDirectory
  Assert-EqualValue $findings "vercel_git_link.link_org" "strazzusochr" $vercelGitLink.observed.linkOrg
  Assert-EqualValue $findings "vercel_git_link.link_repo" "-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM" $vercelGitLink.observed.linkRepo
  Assert-EqualValue $findings "vercel_git_link.production_branch" "chore/repo-bootstrap" $vercelGitLink.observed.linkProductionBranch

  Assert-EqualValue $findings "vercel_remediation.status" "vercel-remediation-ready" $vercelRemediation.status
  Assert-EqualValue $findings "vercel_remediation.valid" $true $vercelRemediation.valid
  Assert-EqualValue $findings "vercel_remediation.ready" $true $vercelRemediation.ready
  Assert-EqualValue $findings "vercel_remediation.classification" "project_visible_with_configured_team" $vercelRemediation.classification
  Assert-EqualValue $findings "vercel_remediation.finding_count" 0 $vercelRemediation.finding_count

  Assert-EqualValue $findings "release_rebaseline.status" "release-rebaseline-ready" $releaseRebaseline.status
  Assert-EqualValue $findings "release_rebaseline.valid" $true $releaseRebaseline.valid
  Assert-EqualValue $findings "release_rebaseline.ready" $true $releaseRebaseline.ready
  Assert-EqualValue $findings "release_rebaseline.needs_rebaseline" $false $releaseRebaseline.needs_rebaseline
  Assert-EqualValue $findings "release_rebaseline.option_count" 4 $releaseRebaseline.option_count
  Assert-EqualValue $findings "release_rebaseline.finding_count" 0 $releaseRebaseline.finding_count

  Assert-EqualValue $findings "resolution.status" "resolution-plan-clear" $resolutionPlan.status
  Assert-EqualValue $findings "resolution.valid" $true $resolutionPlan.valid
  Assert-EqualValue $findings "resolution.clear" $true $resolutionPlan.clear
  Assert-EqualValue $findings "resolution.blocker_count" 0 $resolutionPlan.blocker_count
  Assert-EqualValue $findings "resolution.unknown_blocker_count" 0 $resolutionPlan.unknown_blocker_count

  Assert-EqualValue $findings "truth.status" "ready-for-next-gate" $truth.status
  Assert-EqualValue $findings "truth.truth_ready" $true $truth.truth_ready
  Assert-EqualValue $findings "truth.review_action_matrix_valid" $true $truth.gates.review_action_matrix_valid
  Assert-EqualValue $findings "truth.security_passed" $true $truth.gates.security_passed
  Assert-EqualValue $findings "truth.split_action_packet_valid" $true $truth.gates.split_action_packet_valid
  Assert-EqualValue $findings "truth.quarantine_action_packet_valid" $true $truth.gates.quarantine_action_packet_valid
  Assert-EqualValue $findings "truth.security_review_packet_valid" $true $truth.gates.security_review_packet_valid
  Assert-EqualValue $findings "truth.security_review_action_packet_valid" $true $truth.gates.security_review_action_packet_valid
  Assert-EqualValue $findings "truth.security_review_baseline_hotspot_count" 0 $truth.counts.security_review_baseline_hotspot_count
  Assert-EqualValue $findings "truth.security_review_baseline_hotspot_findings" 0 $truth.counts.security_review_baseline_hotspot_findings
  Assert-EqualValue $findings "truth.owner_decision_packet_valid" $true $truth.gates.owner_decision_packet_valid
  Assert-EqualValue $findings "truth.owner_decision_candidates_valid" $true $truth.gates.owner_decision_candidates_valid
  Assert-EqualValue $findings "truth.owner_action_packet_valid" $true $truth.gates.owner_action_packet_valid
  Assert-EqualValue $findings "truth.owner_decision_readiness_packet_valid" $true $truth.gates.owner_decision_readiness_packet_valid
  Assert-EqualValue $findings "truth.blocker_resolution_plan_valid" $true $truth.gates.blocker_resolution_plan_valid
  Assert-EqualValue $findings "truth.vercel_remediation_plan_valid" $true $truth.gates.vercel_remediation_plan_valid
  Assert-EqualValue $findings "truth.release_rebaseline_plan_valid" $true $truth.gates.release_rebaseline_plan_valid
  Assert-EqualValue $findings "truth.policy.may_cleanup" $false $truth.policy.may_cleanup
  Assert-EqualValue $findings "truth.policy.may_commit" $false $truth.policy.may_commit
  Assert-EqualValue $findings "truth.policy.may_push" $false $truth.policy.may_push
  Assert-EqualValue $findings "truth.policy.may_deploy" $false $truth.policy.may_deploy

  Assert-EqualValue $findings "consistency.status" "consistent-ready-for-next-gate" $consistency.status
  Assert-EqualValue $findings "consistency.consistent" $true $consistency.consistent
  Assert-EqualValue $findings "consistency.finding_count" 0 $consistency.finding_count

  Assert-EqualValue $findings "review_packet.status" "review-packet-valid-ready" $reviewPacket.status
  Assert-EqualValue $findings "review_packet.valid" $true $reviewPacket.valid
  Assert-EqualValue $findings "review_packet.finding_count" 0 $reviewPacket.finding_count

  Assert-EqualValue $findings "artifact_safety.status" "safe" $artifactSafety.status
  Assert-EqualValue $findings "artifact_safety.safe" $true $artifactSafety.safe
  if ($artifactSafety.artifact_count -lt 240) {
    Add-Finding $findings "artifact_safety.artifact_count_minimum" ">=240" $artifactSafety.artifact_count
  }
  Assert-EqualValue $findings "artifact_safety.finding_count" 0 $artifactSafety.finding_count

  $passed = ($findings.Count -eq 0)
  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    status = if ($passed) { "passed" } else { "failed" }
    passed = $passed
    finding_count = $findings.Count
    findings = @($findings)
    checked_scripts = $parserTargets
    checked_artifacts = @(
      ".phase1-artifacts\worktree-cleanup-execution-plan-20260510.json",
      ".phase1-artifacts\worktree-review-action-matrix-20260511.json",
      ".phase1-artifacts\worktree-split-plan-20260510.json",
      ".phase1-artifacts\worktree-split-action-packet-20260511.json",
      ".phase1-artifacts\worktree-quarantine-action-packet-20260511.json",
      ".phase1-artifacts\worktree-security-review-packet-20260511.json",
      ".phase1-artifacts\worktree-security-review-action-packet-20260511.json",
      ".phase1-artifacts\worktree-owner-decision-20260510.json",
      ".phase1-artifacts\worktree-owner-decision-packet-20260510.json",
      ".phase1-artifacts\worktree-owner-decision-candidates-20260511.json",
      ".phase1-artifacts\worktree-owner-action-packet-20260511.json",
      ".phase1-artifacts\owner-decision-readiness-packet-20260511.json",
      ".phase1-artifacts\vercel-project-git-readiness-20260513.json",
      ".phase1-artifacts\vercel-git-link-20260513.json",
      ".phase1-artifacts\vercel-remediation-plan-20260511.json",
      ".phase1-artifacts\release-rebaseline-plan-20260511.json",
      ".phase1-artifacts\blocker-resolution-plan-20260511.json",
      ".phase1-artifacts\project-truth-state-20260510.json",
      ".phase1-artifacts\project-truth-consistency-20260510.json",
      ".phase1-artifacts\external-review-packet-20260510.json",
      ".phase1-artifacts\evidence-artifact-safety-20260510.json"
    )
    policy = [ordered]@{
      mutates_repository = $false
      may_cleanup = $false
      may_stage = $false
      may_commit = $false
      may_push = $false
      may_deploy = $false
      may_release = $false
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
    Write-Host "[release-boundary-regression] status=$($summary.status)"
    Write-Host "[release-boundary-regression] passed=$($summary.passed)"
    Write-Host "[release-boundary-regression] finding_count=$($summary.finding_count)"
    foreach ($finding in @($findings)) {
      Write-Host ("[release-boundary-regression] finding={0} expected={1} actual={2}" -f $finding.id, $finding.expected, $finding.actual)
    }
  }

  if (-not $passed -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}

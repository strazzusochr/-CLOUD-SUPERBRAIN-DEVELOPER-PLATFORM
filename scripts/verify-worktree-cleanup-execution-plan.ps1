param(
  [string]$OwnerDecisionPath = ".phase1-artifacts\worktree-owner-decision-20260510.json",
  [string]$QuarantinePlanPath = ".phase1-artifacts\worktree-quarantine-plan-20260510.json",
  [string]$OutputPath = ".phase1-artifacts\worktree-cleanup-execution-plan-20260510.json",
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

function New-CandidateAction([string]$Kind, [string]$Path, [string]$ProposedDestination = "") {
  $command = switch ($Kind) {
    "move_to_quarantine" {
      "Move-Item -LiteralPath '$Path' -Destination '$ProposedDestination'"
    }
    "unstage_for_review" {
      "git restore --staged -- '$Path'"
    }
    "security_manual_review" {
      "manual review only; no command generated"
    }
    default {
      "manual review only"
    }
  }

  return [pscustomobject]@{
    kind = $Kind
    path = $Path
    proposed_destination = if ([string]::IsNullOrWhiteSpace($ProposedDestination)) { $null } else { $ProposedDestination }
    command_example = $command
    executable_by_this_verifier = $false
    requires_owner_decision = $true
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  if (-not (Test-Path -LiteralPath $OwnerDecisionPath)) {
    & (Join-Path $PSScriptRoot "verify-worktree-owner-decision.ps1") -ReportOnly -OutputPath $OwnerDecisionPath | Out-Null
  }
  if (-not (Test-Path -LiteralPath $QuarantinePlanPath)) {
    & (Join-Path $PSScriptRoot "verify-worktree-quarantine-plan.ps1") -ReportOnly -OutputPath $QuarantinePlanPath | Out-Null
  }

  $ownerDecision = Read-JsonArtifact -Path $OwnerDecisionPath -Label "owner-decision"
  $quarantinePlan = Read-JsonArtifact -Path $QuarantinePlanPath -Label "quarantine-plan"

  $actions = [System.Collections.Generic.List[object]]::new()
  foreach ($item in @($quarantinePlan.quarantine_actions)) {
    $actions.Add((New-CandidateAction -Kind "move_to_quarantine" -Path ([string]$item.path) -ProposedDestination ([string]$item.proposed_destination)))
  }
  foreach ($item in @($quarantinePlan.split_required_actions)) {
    $actions.Add((New-CandidateAction -Kind "unstage_for_review" -Path ([string]$item.path)))
  }
  foreach ($item in @($quarantinePlan.security_review_actions)) {
    $actions.Add((New-CandidateAction -Kind "security_manual_review" -Path ([string]$item.path)))
  }

  $decisionValid = ($ownerDecision.decision_valid -eq $true)
  $mutationAllowed = ($ownerDecision.policy.mutation_allowed_by_decision -eq $true)
  $ready = ($decisionValid -and $mutationAllowed)
  $blockers = [System.Collections.Generic.List[string]]::new()
  if (-not $decisionValid) {
    $blockers.Add("owner_decision_not_valid")
  }
  foreach ($errorItem in @($ownerDecision.errors)) {
    $blockers.Add("owner_decision:$errorItem")
  }
  if (-not $mutationAllowed) {
    $blockers.Add("mutation_not_allowed_by_owner_decision")
  }

  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    status = if ($ready) { "cleanup-execution-plan-ready" } else { "cleanup-execution-blocked" }
    ready = $ready
    owner_decision_path = $OwnerDecisionPath
    quarantine_plan_path = $QuarantinePlanPath
    blockers = @($blockers)
    candidate_action_count = $actions.Count
    candidate_actions = @($actions)
    allowed_actions = $ownerDecision.allowed_actions
    policy = [ordered]@{
      mutates_repository = $false
      executes_requested_actions = $false
      script_supports_execution = $false
      may_move = $false
      may_delete = $false
      may_unstage = $false
      may_stage = $false
      may_commit = $false
      may_push = $false
      may_deploy = $false
      may_release = $false
      required_next_action = if ($ready) {
        "Use a separate reviewed executor; this verifier only emits a dry-run action plan."
      } else {
        "Create a valid owner decision and rerun release-boundary; no cleanup execution is allowed now."
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
    $summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
  }

  if ($JsonOnly) {
    $summary | ConvertTo-Json -Depth 10
  } else {
    Write-Host "[worktree-cleanup-execution-plan] status=$($summary.status)"
    Write-Host "[worktree-cleanup-execution-plan] ready=$($summary.ready)"
    Write-Host "[worktree-cleanup-execution-plan] candidate_action_count=$($summary.candidate_action_count)"
    Write-Host "[worktree-cleanup-execution-plan] blockers=$($summary.blockers -join ',')"
  }

  if (-not $ready -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}

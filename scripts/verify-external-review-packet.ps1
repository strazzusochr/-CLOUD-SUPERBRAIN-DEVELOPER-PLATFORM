param(
  [string]$TruthStatePath = ".phase1-artifacts\project-truth-state-20260510.json",
  [string]$ConsistencyPath = ".phase1-artifacts\project-truth-consistency-20260510.json",
  [string]$ReviewPacketPath = "docs\analysis\EXTERNAL_REVIEW_PACKET_2026-05-10.md",
  [string]$OperatorRunbookPath = "docs\analysis\OWNER_OPERATOR_RUNBOOK_2026-05-11.md",
  [string]$OutputPath = ".phase1-artifacts\external-review-packet-20260510.json",
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

function Assert-PacketContains(
  [System.Collections.Generic.List[object]]$Findings,
  [string]$Content,
  [string]$Needle
) {
  if ($Content -notlike "*$Needle*") {
    Add-Finding -Findings $Findings -Id "packet_missing:$Needle" -Expected "present" -Actual "missing"
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  if (-not (Test-Path -LiteralPath $TruthStatePath)) {
    & (Join-Path $PSScriptRoot "verify-project-truth-state.ps1") -ReportOnly -OutputPath $TruthStatePath | Out-Null
  }
  if (-not (Test-Path -LiteralPath $ConsistencyPath)) {
    & (Join-Path $PSScriptRoot "verify-project-truth-consistency.ps1") -ReportOnly -OutputPath $ConsistencyPath | Out-Null
  }

  $truth = Read-JsonArtifact -Path $TruthStatePath -Label "truth-state"
  $consistency = Read-JsonArtifact -Path $ConsistencyPath -Label "truth-consistency"
  $findings = [System.Collections.Generic.List[object]]::new()

  if (-not (Test-Path -LiteralPath $ReviewPacketPath)) {
    Add-Finding -Findings $findings -Id "review_packet_missing" -Expected "exists" -Actual $ReviewPacketPath
    $packetContent = ""
  } else {
    $packetContent = Get-Content -LiteralPath $ReviewPacketPath -Raw
  }

  if (-not (Test-Path -LiteralPath $OperatorRunbookPath)) {
    Add-Finding -Findings $findings -Id "operator_runbook_missing" -Expected "exists" -Actual $OperatorRunbookPath
    $runbookContent = ""
  } else {
    $runbookContent = Get-Content -LiteralPath $OperatorRunbookPath -Raw
  }

  $packetRequired = @(
    ".phase1-artifacts\project-truth-state-20260510.json",
    ".phase1-artifacts\project-truth-consistency-20260510.json",
    ".phase1-artifacts\blocker-resolution-plan-20260511.json",
    ".phase1-artifacts\vercel-remediation-plan-20260511.json",
    ".phase1-artifacts\release-rebaseline-plan-20260511.json",
    "docs\analysis\OWNER_OPERATOR_RUNBOOK_2026-05-11.md",
    "docs\analysis\WORKTREE_OWNER_DECISION_SCHEMA_2026-05-11.json",
    ".phase1-artifacts\worktree-review-action-matrix-20260511.json",
    ".phase1-artifacts\worktree-owner-decision-packet-20260510.json",
    ".phase1-artifacts\worktree-owner-decision-candidates-20260511.json",
    ".phase1-artifacts\worktree-owner-action-packet-20260511.json",
    ".phase1-artifacts\owner-decision-readiness-packet-20260511.json",
    ".phase1-artifacts\worktree-quarantine-action-packet-20260511.json",
    ".phase1-artifacts\worktree-split-plan-20260510.json",
    ".phase1-artifacts\worktree-split-action-packet-20260511.json",
    ".phase1-artifacts\worktree-cleanup-execution-plan-20260510.json",
    "scripts\verify.ps1 -Suite release-boundary -ReportOnly -MaxWaitSeconds 1",
    ".phase1-artifacts\worktree-security-review-packet-20260511.json",
    ".phase1-artifacts\worktree-security-review-action-packet-20260511.json",
    "truth_ready=$($truth.truth_ready.ToString().ToLowerInvariant())",
    "status=$($truth.status)",
    "release_boundary_clear=$($truth.gates.release_boundary_clear.ToString().ToLowerInvariant())",
    "worktree_clean=$($truth.gates.worktree_clean.ToString().ToLowerInvariant())",
    "release_id=$($truth.release_candidate.release_id)",
    "candidate_source_sha=$($truth.release_candidate.candidate_source_sha)",
    "head_matches_candidate=$($truth.release_candidate.head_matches_candidate.ToString().ToLowerInvariant())",
    "may_cleanup=false",
    "may_stage=false",
    "may_commit=false",
    "may_push=false",
    "may_deploy=false",
    "may_release=false",
    "review_action_matrix_valid=true",
    "review_action_matrix_batches=$($truth.counts.review_action_matrix_batches)",
    "review_action_matrix_unique_paths=$($truth.counts.review_action_matrix_unique_paths)",
    "owner_decision_packet_valid=true",
    "owner_decision_candidates_valid=true",
    "owner_decision_candidate_options=4",
    "owner_action_packet_valid=true",
    "owner_action_count=0",
    "owner_decision_readiness_packet_valid=true",
    "owner_decision_readiness_items=8",
    "OWNER_OPERATOR_RUNBOOK_2026-05-11.md",
    "quarantine_action_packet_valid=true",
    "quarantine_action_count=0",
    "split_action_packet_valid=true",
    "split_action_count=0",
    "security_review_packet_valid=true",
    "security_review_packet_paths=0",
    "security_review_action_packet_valid=true",
    "security_review_action_count=0",
    "security_review_baseline_hotspots=0",
    "security_review_baseline_hotspot_findings=0",
    "blocker_resolution_plan_valid=true",
    "blocker_resolution_mapped=$($truth.counts.blocker_resolution_mapped)",
    "blocker_resolution_unknowns=0",
    "vercel_remediation_plan_valid=true",
    "release_rebaseline_plan_valid=true",
    "release_rebaseline_options=4",
    "classification=project_visible_with_configured_team",
    "owner_decision_valid=true",
    "staged_and_modified=0"
  )
  foreach ($required in $packetRequired) {
    Assert-PacketContains -Findings $findings -Content $packetContent -Needle $required
  }

  $runbookRequired = @(
    "truth_ready=$($truth.truth_ready.ToString().ToLowerInvariant())",
    "release_boundary_clear=$($truth.gates.release_boundary_clear.ToString().ToLowerInvariant())",
    "release_id=$($truth.release_candidate.release_id)",
    "owner_decision_valid=true",
    "vercel_access_ready=true",
    "security_passed=true",
    "git restore --staged .",
    "git add",
    "git commit",
    "git push",
    "vercel deploy",
    "docker push",
    "production deploy",
    "release promotion",
    "docs\analysis\worktree-owner-decision-20260510.json",
    "docs\analysis\WORKTREE_OWNER_DECISION_TEMPLATE_2026-05-10.json",
    "docs\analysis\WORKTREE_OWNER_DECISION_SCHEMA_2026-05-11.json",
    "cleanup-first",
    "create-new-candidate-from-current-head",
    "runtime-rebaseline",
    "defer",
    "may_commit=false",
    "may_push=false",
    "may_deploy=false",
    ".phase1-artifacts\worktree-security-review-action-packet-20260511.json",
    "detect-secrets baseline hotspots",
    "baseline_hotspot_count=0",
    ".phase1-artifacts\worktree-quarantine-action-packet-20260511.json",
    ".phase1-artifacts\worktree-split-action-packet-20260511.json",
    ".phase1-artifacts\worktree-review-action-matrix-20260511.json",
    ".phase1-artifacts\vercel-remediation-plan-20260511.json",
    ".phase1-artifacts\release-rebaseline-plan-20260511.json",
    "classification=project_visible_with_configured_team",
    "keep-rc1-and-restore-head",
    "scripts\verify.ps1 -Suite security",
    "scripts\verify.ps1 -Suite release-boundary -ReportOnly -MaxWaitSeconds 1",
    "This runbook is not an approval."
  )
  foreach ($required in $runbookRequired) {
    Assert-PacketContains -Findings $findings -Content $runbookContent -Needle $required
  }

  if ($truth.policy.may_commit -ne $false -or $truth.policy.may_push -ne $false -or $truth.policy.may_deploy -ne $false) {
    Add-Finding -Findings $findings -Id "truth_policy_not_fail_closed" -Expected "commit/push/deploy false" -Actual "one or more true"
  }
  if ($consistency.consistent -ne $true) {
    Add-Finding -Findings $findings -Id "truth_consistency_not_clean" -Expected "consistent=true" -Actual ([string]$consistency.consistent)
  }
  if ($consistency.finding_count -ne 0) {
    Add-Finding -Findings $findings -Id "truth_consistency_findings_present" -Expected "0" -Actual ([string]$consistency.finding_count)
  }
  if ($truth.leak_prevention.secret_values_included -ne $false -or $truth.leak_prevention.tokens_included -ne $false) {
    Add-Finding -Findings $findings -Id "truth_leak_prevention_not_fail_closed" -Expected "secret/tokens false" -Actual "one or more true"
  }

  $valid = ($findings.Count -eq 0)
  $status = if ($valid) {
    if ($truth.truth_ready -eq $true) { "review-packet-valid-ready" } else { "review-packet-valid-blocked" }
  } else {
    "review-packet-invalid"
  }

  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    status = $status
    valid = $valid
    finding_count = $findings.Count
    findings = @($findings)
    review_packet_path = $ReviewPacketPath
    operator_runbook_path = $OperatorRunbookPath
    truth_state_path = $TruthStatePath
    consistency_path = $ConsistencyPath
    truth_status = $truth.status
    truth_ready = $truth.truth_ready
    consistency_status = $consistency.status
    consistency_clean = $consistency.consistent
    counts = $truth.counts
    blockers = @($truth.blockers)
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
    Write-Host "[external-review-packet] status=$($summary.status)"
    Write-Host "[external-review-packet] valid=$($summary.valid)"
    Write-Host "[external-review-packet] truth_ready=$($summary.truth_ready)"
    Write-Host "[external-review-packet] consistency_clean=$($summary.consistency_clean)"
    Write-Host "[external-review-packet] finding_count=$($summary.finding_count)"
    foreach ($finding in @($findings)) {
      Write-Host ("[external-review-packet] finding={0} expected={1} actual={2}" -f $finding.id, $finding.expected, $finding.actual)
    }
  }

  if (-not $valid -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}

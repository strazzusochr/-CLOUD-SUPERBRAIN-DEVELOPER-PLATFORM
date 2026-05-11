param(
  [string]$TemplatePath = "docs\analysis\WORKTREE_OWNER_DECISION_TEMPLATE_2026-05-10.json",
  [string]$SchemaPath = "docs\analysis\WORKTREE_OWNER_DECISION_SCHEMA_2026-05-11.json",
  [string]$OwnerDecisionPath = ".phase1-artifacts\worktree-owner-decision-20260510.json",
  [string]$QuarantinePlanPath = ".phase1-artifacts\worktree-quarantine-plan-20260510.json",
  [string]$SplitPlanPath = ".phase1-artifacts\worktree-split-plan-20260510.json",
  [string]$CleanupExecutionPlanPath = ".phase1-artifacts\worktree-cleanup-execution-plan-20260510.json",
  [string]$OutputPath = ".phase1-artifacts\worktree-owner-decision-packet-20260510.json",
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

function Add-Finding([System.Collections.Generic.List[object]]$Findings, [string]$Id, [string]$Expected, [string]$Actual) {
  $Findings.Add([pscustomobject]@{
    id = $Id
    expected = $Expected
    actual = $Actual
  })
}

function Test-PropertyPresent([object]$Object, [string]$Name) {
  if ($null -eq $Object) {
    return $false
  }

  return ($null -ne $Object.PSObject.Properties[$Name])
}

function Test-BooleanPropertyFalse([object]$Object, [string]$Name) {
  if (-not (Test-PropertyPresent -Object $Object -Name $Name)) {
    return $false
  }

  $value = $Object.PSObject.Properties[$Name].Value
  return ($value -is [bool] -and -not $value)
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  Invoke-DependencyVerifier -ScriptName "verify-worktree-owner-decision.ps1" -OutputPath $OwnerDecisionPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-quarantine-plan.ps1" -OutputPath $QuarantinePlanPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-split-plan.ps1" -OutputPath $SplitPlanPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-cleanup-execution-plan.ps1" -OutputPath $CleanupExecutionPlanPath

  $ownerDecision = Read-JsonArtifact -Path $OwnerDecisionPath -Label "owner-decision"
  $quarantinePlan = Read-JsonArtifact -Path $QuarantinePlanPath -Label "quarantine-plan"
  $splitPlan = Read-JsonArtifact -Path $SplitPlanPath -Label "split-plan"
  $cleanupExecutionPlan = Read-JsonArtifact -Path $CleanupExecutionPlanPath -Label "cleanup-execution-plan"

  $findings = [System.Collections.Generic.List[object]]::new()
  $template = $null
  $schema = $null
  if (-not (Test-Path -LiteralPath $TemplatePath)) {
    Add-Finding -Findings $findings -Id "template_missing" -Expected "exists" -Actual $TemplatePath
  } else {
    try {
      $template = Get-Content -LiteralPath $TemplatePath -Raw | ConvertFrom-Json
    } catch {
      Add-Finding -Findings $findings -Id "template_invalid_json" -Expected "valid JSON" -Actual $_.Exception.Message
    }
  }
  if (-not (Test-Path -LiteralPath $SchemaPath)) {
    Add-Finding -Findings $findings -Id "schema_missing" -Expected "exists" -Actual $SchemaPath
  } else {
    try {
      $schema = Get-Content -LiteralPath $SchemaPath -Raw | ConvertFrom-Json
    } catch {
      Add-Finding -Findings $findings -Id "schema_invalid_json" -Expected "valid JSON" -Actual $_.Exception.Message
    }
  }

  foreach ($field in @("decision_id", "decided_at", "approved_by", "strategy", "allowed_actions", "scope", "notes")) {
    if (-not (Test-PropertyPresent -Object $template -Name $field)) {
      Add-Finding -Findings $findings -Id "template_field_missing:$field" -Expected "present" -Actual "missing"
    }
    if ($null -ne $schema -and @($schema.required) -notcontains $field) {
      Add-Finding -Findings $findings -Id "schema_required_field_missing:$field" -Expected "present" -Actual "missing"
    }
  }

  if (Test-PropertyPresent -Object $template -Name "allowed_actions") {
    foreach ($actionName in @("may_move", "may_delete", "may_unstage", "may_stage", "may_commit", "may_push", "may_deploy")) {
      if (-not (Test-PropertyPresent -Object $template.allowed_actions -Name $actionName)) {
        Add-Finding -Findings $findings -Id "template_allowed_action_missing:$actionName" -Expected "present" -Actual "missing"
      }
      if ($null -ne $schema -and @($schema.properties.allowed_actions.required) -notcontains $actionName) {
        Add-Finding -Findings $findings -Id "schema_allowed_action_missing:$actionName" -Expected "present" -Actual "missing"
      }
    }

    foreach ($forbiddenName in @("may_commit", "may_push", "may_deploy")) {
      if (-not (Test-BooleanPropertyFalse -Object $template.allowed_actions -Name $forbiddenName)) {
        Add-Finding -Findings $findings -Id "template_forbidden_action_not_false:$forbiddenName" -Expected "false" -Actual "not false"
      }
    }
  }

  $packetValid = ($findings.Count -eq 0)
  $decisionRequired = ($ownerDecision.decision_valid -ne $true)
  $blockingReviewItems = [int]$quarantinePlan.counts.total_blocking_review_items
  $status = if ($packetValid) {
    if ($decisionRequired) { "owner-decision-packet-valid-blocked" } else { "owner-decision-packet-valid-ready" }
  } else {
    "owner-decision-packet-invalid"
  }

  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    status = $status
    valid = $packetValid
    decision_required = $decisionRequired
    finding_count = $findings.Count
    findings = @($findings)
    required_decision_file = "docs\analysis\worktree-owner-decision-20260510.json"
    template_path = $TemplatePath
    schema_path = $SchemaPath
    source_artifacts = [ordered]@{
      owner_decision = $OwnerDecisionPath
      quarantine_plan = $QuarantinePlanPath
      split_plan = $SplitPlanPath
      cleanup_execution_plan = $CleanupExecutionPlanPath
    }
    current_decision = [ordered]@{
      status = $ownerDecision.status
      decision_present = $ownerDecision.decision_present
      decision_valid = $ownerDecision.decision_valid
      errors = @($ownerDecision.errors)
    }
    current_blockers = [ordered]@{
      blocking_review_items = $blockingReviewItems
      security_review = [int]$quarantinePlan.counts.security_review
      exclude_or_quarantine = [int]$quarantinePlan.counts.exclude_or_quarantine
      split_required = [int]$quarantinePlan.counts.split_required
      split_plan_actions = [int]$splitPlan.split_path_count
      cleanup_candidate_actions = [int]$cleanupExecutionPlan.candidate_action_count
    }
    allowed_strategies = @(
      [ordered]@{
        strategy = "cleanup-first"
        intent = "Review sensitive/debug/split paths first, then perform separately approved cleanup or normalization."
        may_set_true = @("may_move", "may_unstage")
        must_remain_false = @("may_commit", "may_push", "may_deploy")
      },
      [ordered]@{
        strategy = "evidence-only-rebaseline"
        intent = "Allow staging of reviewed evidence-only files after security and split blockers are cleared."
        may_set_true = @("may_stage")
        must_remain_false = @("may_commit", "may_push", "may_deploy")
      },
      [ordered]@{
        strategy = "runtime-rebaseline"
        intent = "Allow staging of reviewed runtime files after security and split blockers are cleared."
        may_set_true = @("may_stage")
        must_remain_false = @("may_commit", "may_push", "may_deploy")
      },
      [ordered]@{
        strategy = "defer"
        intent = "Keep all mutations blocked."
        may_set_true = @()
        must_remain_false = @("may_move", "may_delete", "may_unstage", "may_stage", "may_commit", "may_push", "may_deploy")
        current_validity_note = if ($blockingReviewItems -gt 0) { "not valid while blocking review items remain" } else { "valid no-mutation decision" }
      }
    )
    required_owner_action = if ($decisionRequired) {
      "Create docs/analysis/worktree-owner-decision-20260510.json from the template; set approved_by, decided_at, strategy, and allowed_actions explicitly; keep may_commit, may_push, and may_deploy false."
    } else {
      "Owner decision artifact is valid; continue with the next explicit reviewed gate."
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
    Write-Host "[worktree-owner-decision-packet] status=$($summary.status)"
    Write-Host "[worktree-owner-decision-packet] valid=$($summary.valid)"
    Write-Host "[worktree-owner-decision-packet] decision_required=$($summary.decision_required)"
    Write-Host "[worktree-owner-decision-packet] finding_count=$($summary.finding_count)"
    foreach ($finding in @($findings)) {
      Write-Host ("[worktree-owner-decision-packet] finding={0} expected={1} actual={2}" -f $finding.id, $finding.expected, $finding.actual)
    }
  }

  if (-not $packetValid -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}

param(
  [string]$DecisionPath = "docs\analysis\worktree-owner-decision-20260510.json",
  [string]$SchemaPath = "docs\analysis\WORKTREE_OWNER_DECISION_SCHEMA_2026-05-11.json",
  [string]$QuarantinePlanPath = ".phase1-artifacts\worktree-quarantine-plan-20260510.json",
  [string]$OutputPath = ".phase1-artifacts\worktree-owner-decision-20260510.json",
  [switch]$ReportOnly,
  [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"

function Test-TruthyBoolean([object]$Value) {
  if ($null -eq $Value) {
    return $false
  }
  return ($Value -is [bool] -and $Value)
}

function Get-AllowedAction([object]$Decision, [string]$Name) {
  if ($null -eq $Decision -or $null -eq $Decision.allowed_actions) {
    return $false
  }

  $property = $Decision.allowed_actions.PSObject.Properties[$Name]
  if ($null -eq $property) {
    return $false
  }

  return (Test-TruthyBoolean -Value $property.Value)
}

function Test-PropertyPresent([object]$Object, [string]$Name) {
  if ($null -eq $Object) {
    return $false
  }

  return ($null -ne $Object.PSObject.Properties[$Name])
}

function Test-NonEmptyString([object]$Object, [string]$Name) {
  if (-not (Test-PropertyPresent -Object $Object -Name $Name)) {
    return $false
  }

  $value = $Object.PSObject.Properties[$Name].Value
  return ($value -is [string] -and -not [string]::IsNullOrWhiteSpace($value))
}

function Test-BooleanProperty([object]$Object, [string]$Name) {
  if (-not (Test-PropertyPresent -Object $Object -Name $Name)) {
    return $false
  }

  return ($Object.PSObject.Properties[$Name].Value -is [bool])
}

function Validate-DecisionShape([object]$Decision, [System.Collections.Generic.List[string]]$Errors) {
  $allowedRootFields = @("decision_id", "decided_at", "approved_by", "strategy", "allowed_actions", "scope", "notes")
  foreach ($property in @($Decision.PSObject.Properties.Name)) {
    if ($allowedRootFields -notcontains $property) {
      $Errors.Add("root_property_not_allowed:$property")
    }
  }

  foreach ($field in @("decision_id", "decided_at", "approved_by", "strategy", "notes")) {
    if (-not (Test-NonEmptyString -Object $Decision -Name $field)) {
      $Errors.Add("$($field)_missing_or_not_string")
    }
  }

  if ((Test-PropertyPresent -Object $Decision -Name "decided_at") -and [string]$Decision.decided_at -notmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$') {
    $Errors.Add("decided_at_not_utc_iso8601_seconds")
  }

  if (-not (Test-PropertyPresent -Object $Decision -Name "allowed_actions")) {
    $Errors.Add("allowed_actions_missing")
  } else {
    $allowedActionFields = @("may_move", "may_delete", "may_unstage", "may_stage", "may_commit", "may_push", "may_deploy")
    foreach ($property in @($Decision.allowed_actions.PSObject.Properties.Name)) {
      if ($allowedActionFields -notcontains $property) {
        $Errors.Add("allowed_actions_property_not_allowed:$property")
      }
    }

    foreach ($actionName in @("may_move", "may_delete", "may_unstage", "may_stage", "may_commit", "may_push", "may_deploy")) {
      if (-not (Test-BooleanProperty -Object $Decision.allowed_actions -Name $actionName)) {
        $Errors.Add("allowed_actions.$actionName`_missing_or_not_boolean")
      }
    }
  }

  if (-not (Test-PropertyPresent -Object $Decision -Name "scope")) {
    $Errors.Add("scope_missing")
  } else {
    $allowedScopeFields = @("security_review_paths", "quarantine_paths", "split_required_paths")
    foreach ($property in @($Decision.scope.PSObject.Properties.Name)) {
      if ($allowedScopeFields -notcontains $property) {
        $Errors.Add("scope_property_not_allowed:$property")
      }
    }

    foreach ($scopeName in @("security_review_paths", "quarantine_paths", "split_required_paths")) {
      if (-not (Test-NonEmptyString -Object $Decision.scope -Name $scopeName)) {
        $Errors.Add("scope.$scopeName`_missing_or_not_string")
      }
    }
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  if (-not (Test-Path -LiteralPath $QuarantinePlanPath)) {
    & (Join-Path $PSScriptRoot "verify-worktree-quarantine-plan.ps1") -ReportOnly -OutputPath $QuarantinePlanPath | Out-Null
  }

  if (-not (Test-Path -LiteralPath $QuarantinePlanPath)) {
    throw "Missing worktree quarantine plan artifact: $QuarantinePlanPath"
  }

  $quarantinePlan = Get-Content -LiteralPath $QuarantinePlanPath -Raw | ConvertFrom-Json
  $schemaPresent = Test-Path -LiteralPath $SchemaPath
  $decisionPresent = Test-Path -LiteralPath $DecisionPath
  $decision = $null
  $errors = [System.Collections.Generic.List[string]]::new()

  if ($schemaPresent) {
    try {
      $schema = Get-Content -LiteralPath $SchemaPath -Raw | ConvertFrom-Json
      foreach ($field in @("decision_id", "decided_at", "approved_by", "strategy", "allowed_actions", "scope", "notes")) {
        if (@($schema.required) -notcontains $field) {
          $errors.Add("schema_required_field_missing:$field")
        }
      }
      foreach ($actionName in @("may_move", "may_delete", "may_unstage", "may_stage", "may_commit", "may_push", "may_deploy")) {
        if (@($schema.properties.allowed_actions.required) -notcontains $actionName) {
          $errors.Add("schema_allowed_action_missing:$actionName")
        }
      }
    } catch {
      $errors.Add("owner_decision_schema_invalid_json")
    }
  } else {
    $errors.Add("owner_decision_schema_missing")
  }

  if ($decisionPresent) {
    try {
      $decision = Get-Content -LiteralPath $DecisionPath -Raw | ConvertFrom-Json -DateKind String
    } catch {
      $errors.Add("decision_file_is_not_valid_json")
    }
  } else {
    $errors.Add("owner_decision_file_missing")
  }

  $allowedStrategies = @("cleanup-first", "evidence-only-rebaseline", "runtime-rebaseline", "defer")
  $strategy = ""
  if ($null -ne $decision) {
    Validate-DecisionShape -Decision $decision -Errors $errors
    $strategy = [string]$decision.strategy
    if ($allowedStrategies -notcontains $strategy) {
      $errors.Add("strategy_not_allowed")
    }
  }

  $mayMove = Get-AllowedAction -Decision $decision -Name "may_move"
  $mayDelete = Get-AllowedAction -Decision $decision -Name "may_delete"
  $mayUnstage = Get-AllowedAction -Decision $decision -Name "may_unstage"
  $mayStage = Get-AllowedAction -Decision $decision -Name "may_stage"
  $mayCommit = Get-AllowedAction -Decision $decision -Name "may_commit"
  $mayPush = Get-AllowedAction -Decision $decision -Name "may_push"
  $mayDeploy = Get-AllowedAction -Decision $decision -Name "may_deploy"

  if ($mayDeploy) {
    $errors.Add("may_deploy_must_remain_false_for_worktree_cleanup_decision")
  }
  if ($mayPush) {
    $errors.Add("may_push_must_remain_false_until_release_boundary_is_clear")
  }
  if ($mayCommit) {
    $errors.Add("may_commit_must_remain_false_until_split_required_and_security_review_are_clear")
  }

  $hasBlockingReviewItems = ($quarantinePlan.counts.total_blocking_review_items -gt 0)
  if ($hasBlockingReviewItems -and $strategy -eq "defer") {
    $errors.Add("strategy_defer_keeps_cleanup_blocked")
  }

  $decisionValid = ($errors.Count -eq 0)
  $mutationAllowed = ($decisionValid -and ($mayMove -or $mayDelete -or $mayUnstage -or $mayStage))

  $status = if ($decisionValid) {
    if ($mutationAllowed) { "owner-decision-valid-mutation-authorized" } else { "owner-decision-valid-no-mutation" }
  } else {
    "owner-decision-blocked"
  }

  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    decision_path = $DecisionPath
    schema_path = $SchemaPath
    schema_present = $schemaPresent
    decision_present = $decisionPresent
    quarantine_plan_path = $QuarantinePlanPath
    status = $status
    decision_valid = $decisionValid
    strategy = if ([string]::IsNullOrWhiteSpace($strategy)) { $null } else { $strategy }
    errors = @($errors)
    blocking_review_counts = [ordered]@{
      security_review = [int]$quarantinePlan.counts.security_review
      exclude_or_quarantine = [int]$quarantinePlan.counts.exclude_or_quarantine
      split_required = [int]$quarantinePlan.counts.split_required
      total_blocking_review_items = [int]$quarantinePlan.counts.total_blocking_review_items
    }
    allowed_actions = [ordered]@{
      may_move = $mayMove
      may_delete = $mayDelete
      may_unstage = $mayUnstage
      may_stage = $mayStage
      may_commit = $mayCommit
      may_push = $mayPush
      may_deploy = $mayDeploy
    }
    policy = [ordered]@{
      mutates_repository = $false
      executes_requested_actions = $false
      mutation_allowed_by_decision = $mutationAllowed
      may_commit = $false
      may_push = $false
      may_deploy = $false
      required_next_action = if ($decisionValid) {
        "Run an explicit cleanup executor only if separately requested; this verifier does not mutate the repository."
      } else {
        "Create docs/analysis/worktree-owner-decision-20260510.json from the template and rerun release-boundary."
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
    Write-Host "[worktree-owner-decision] status=$($summary.status)"
    Write-Host "[worktree-owner-decision] decision_present=$($summary.decision_present)"
    Write-Host "[worktree-owner-decision] decision_valid=$($summary.decision_valid)"
    Write-Host "[worktree-owner-decision] strategy=$($summary.strategy)"
    Write-Host "[worktree-owner-decision] mutation_allowed_by_decision=$($summary.policy.mutation_allowed_by_decision)"
    if ($summary.errors.Count -gt 0) {
      Write-Host "[worktree-owner-decision] errors=$($summary.errors -join ',')"
    }
  }

  if (-not $decisionValid -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}

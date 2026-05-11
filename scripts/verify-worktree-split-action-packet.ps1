param(
  [string]$SplitPlanPath = ".phase1-artifacts\worktree-split-plan-20260510.json",
  [string]$OutputPath = ".phase1-artifacts\worktree-split-action-packet-20260511.json",
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

function Convert-ToForwardSlash([string]$Path) {
  return ($Path -replace '\\', '/')
}

function New-OwnerAction([object]$Action) {
  $path = Convert-ToForwardSlash -Path ([string]$Action.path)
  return [pscustomobject]@{
    id = "normalize-staged-worktree-split:$path"
    kind = "owner_decision_required"
    source_path = $path
    current_issue = "path has staged changes and additional unstaged worktree changes"
    required_owner_decision = "Choose whether to keep staged content, unstage and review both diffs, or restage the final intended file state."
    safe_inspection_commands = @(
      [string]$Action.inspect_staged_command,
      [string]$Action.inspect_worktree_command
    )
    candidate_normalization_commands = @(
      [string]$Action.normalize_command_example,
      [string]$Action.restage_after_review_command_example
    )
    verification_gate = "git status --short must show no staged-and-modified MM entry for this path."
    executable_by_this_gate = $false
    mutates_repository = $false
    diff_contents_included = $false
    file_contents_included = $false
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  Invoke-DependencyVerifier -ScriptName "verify-worktree-split-plan.ps1" -OutputPath $SplitPlanPath

  $splitPlan = Read-JsonArtifact -Path $SplitPlanPath -Label "split-plan"
  $splitActions = @($splitPlan.actions)
  $findings = [System.Collections.Generic.List[object]]::new()

  if ([int]$splitPlan.split_path_count -ne $splitActions.Count) {
    Add-Finding $findings "split_action_count" ([string]$splitPlan.split_path_count) ([string]$splitActions.Count)
  }

  foreach ($action in $splitActions) {
    $path = Convert-ToForwardSlash -Path ([string]$action.path)

    if ([string]::IsNullOrWhiteSpace($path)) {
      Add-Finding $findings "path_empty" "non-empty" "empty"
    }
    if ($path -like "../*" -or $path -like "*/../*" -or $path -like "*..\\*") {
      Add-Finding $findings "path_traversal:$path" "no parent traversal" $path
    }
    if ([string]$action.review_type -ne "split-required") {
      Add-Finding $findings "review_type:$path" "split-required" ([string]$action.review_type)
    }
    if ($action.executable_by_this_verifier -ne $false) {
      Add-Finding $findings "executable_by_this_verifier:$path" "false" ([string]$action.executable_by_this_verifier)
    }
    if ($action.requires_owner_decision -ne $true) {
      Add-Finding $findings "requires_owner_decision:$path" "true" ([string]$action.requires_owner_decision)
    }
    if ($action.content_included_in_artifact -ne $false) {
      Add-Finding $findings "content_included_in_artifact:$path" "false" ([string]$action.content_included_in_artifact)
    }
    foreach ($property in @("inspect_staged_command", "inspect_worktree_command", "normalize_command_example", "restage_after_review_command_example")) {
      $value = [string]$action.$property
      if ([string]::IsNullOrWhiteSpace($value)) {
        Add-Finding $findings "$property`:$path" "non-empty command example" "empty"
      }
    }
  }

  $ownerActions = @($splitActions | ForEach-Object { New-OwnerAction -Action $_ })
  $valid = ($findings.Count -eq 0)
  $ready = ($valid -and $ownerActions.Count -eq 0)
  $status = if ($valid) {
    if ($ready) { "split-action-packet-clear" } else { "split-action-packet-valid-blocked" }
  } else {
    "split-action-packet-invalid"
  }

  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    status = $status
    valid = $valid
    ready = $ready
    action_count = $ownerActions.Count
    finding_count = $findings.Count
    findings = @($findings)
    owner_actions = @($ownerActions)
    source_artifacts = [ordered]@{
      split_plan = $SplitPlanPath
    }
    policy = [ordered]@{
      mutates_repository = $false
      executes_requested_actions = $false
      may_unstage = $false
      may_stage = $false
      may_commit = $false
      may_push = $false
      may_deploy = $false
      may_release = $false
      required_next_action = if ($ready) {
        "Split path list is clear; rerun release-boundary."
      } else {
        "Owner must normalize every staged-and-modified path before any commit boundary."
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
    Write-Host "[worktree-split-action-packet] status=$($summary.status)"
    Write-Host "[worktree-split-action-packet] valid=$($summary.valid)"
    Write-Host "[worktree-split-action-packet] ready=$($summary.ready)"
    Write-Host "[worktree-split-action-packet] action_count=$($summary.action_count)"
    Write-Host "[worktree-split-action-packet] finding_count=$($summary.finding_count)"
    foreach ($finding in @($findings)) {
      Write-Host ("[worktree-split-action-packet] finding={0} expected={1} actual={2}" -f $finding.id, $finding.expected, $finding.actual)
    }
  }

  if (-not $valid -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}

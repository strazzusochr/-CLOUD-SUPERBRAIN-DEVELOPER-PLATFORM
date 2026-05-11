param(
  [string]$QuarantinePlanPath = ".phase1-artifacts\worktree-quarantine-plan-20260510.json",
  [string]$OutputPath = ".phase1-artifacts\worktree-quarantine-action-packet-20260511.json",
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
  return [pscustomobject]@{
    id = "quarantine-or-exclude:$($Action.path)"
    kind = "owner_decision_required"
    source_path = [string]$Action.path
    proposed_destination = [string]$Action.proposed_destination
    default_policy = "exclude_from_release_scope_unless_explicitly_accepted"
    required_owner_decision = "Choose exclude-from-release, move-to-quarantine, or explicitly accept into release scope."
    verification_gate = "Rerun scripts\\verify.ps1 -Suite release-boundary -ReportOnly -MaxWaitSeconds 1 after owner action."
    executable_by_this_gate = $false
    mutates_repository = $false
    file_contents_included = $false
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  Invoke-DependencyVerifier -ScriptName "verify-worktree-quarantine-plan.ps1" -OutputPath $QuarantinePlanPath

  $quarantinePlan = Read-JsonArtifact -Path $QuarantinePlanPath -Label "quarantine-plan"
  $quarantineActions = @($quarantinePlan.quarantine_actions)
  $findings = [System.Collections.Generic.List[object]]::new()

  if ([int]$quarantinePlan.counts.exclude_or_quarantine -ne $quarantineActions.Count) {
    Add-Finding $findings "quarantine_action_count" ([string]$quarantinePlan.counts.exclude_or_quarantine) ([string]$quarantineActions.Count)
  }

  foreach ($action in $quarantineActions) {
    $path = Convert-ToForwardSlash -Path ([string]$action.path)
    $destination = Convert-ToForwardSlash -Path ([string]$action.proposed_destination)

    if ([string]::IsNullOrWhiteSpace($path)) {
      Add-Finding $findings "path_empty" "non-empty" "empty"
    }
    if ($path -like "../*" -or $path -like "*/../*" -or $path -like "*..\\*") {
      Add-Finding $findings "path_traversal:$path" "no parent traversal" $path
    }
    if ([string]$action.action -ne "owner_decision_required_before_move_or_exclusion") {
      Add-Finding $findings "action:$path" "owner_decision_required_before_move_or_exclusion" ([string]$action.action)
    }
    if ([string]$action.default_policy -ne "exclude_from_release_scope_unless_explicitly_accepted") {
      Add-Finding $findings "default_policy:$path" "exclude_from_release_scope_unless_explicitly_accepted" ([string]$action.default_policy)
    }
    if ($action.mutates_repository -ne $false) {
      Add-Finding $findings "mutates_repository:$path" "false" ([string]$action.mutates_repository)
    }
    if ($destination -notlike "debug-artifacts/quarantine/*/$path") {
      Add-Finding $findings "proposed_destination:$path" "debug-artifacts/quarantine/<date>/$path" $destination
    }
  }

  $ownerActions = @($quarantineActions | ForEach-Object { New-OwnerAction -Action $_ })
  $valid = ($findings.Count -eq 0)
  $ready = ($valid -and $ownerActions.Count -eq 0)
  $status = if ($valid) {
    if ($ready) { "quarantine-action-packet-clear" } else { "quarantine-action-packet-valid-blocked" }
  } else {
    "quarantine-action-packet-invalid"
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
      quarantine_plan = $QuarantinePlanPath
    }
    policy = [ordered]@{
      mutates_repository = $false
      executes_requested_actions = $false
      creates_quarantine_directory = $false
      may_move = $false
      may_delete = $false
      may_unstage = $false
      may_stage = $false
      may_commit = $false
      may_push = $false
      may_deploy = $false
      may_release = $false
      required_next_action = if ($ready) {
        "Quarantine path list is clear; rerun release-boundary."
      } else {
        "Owner must explicitly decide each quarantine candidate before any release scope inclusion."
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
    Write-Host "[worktree-quarantine-action-packet] status=$($summary.status)"
    Write-Host "[worktree-quarantine-action-packet] valid=$($summary.valid)"
    Write-Host "[worktree-quarantine-action-packet] ready=$($summary.ready)"
    Write-Host "[worktree-quarantine-action-packet] action_count=$($summary.action_count)"
    Write-Host "[worktree-quarantine-action-packet] finding_count=$($summary.finding_count)"
    foreach ($finding in @($findings)) {
      Write-Host ("[worktree-quarantine-action-packet] finding={0} expected={1} actual={2}" -f $finding.id, $finding.expected, $finding.actual)
    }
  }

  if (-not $valid -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}

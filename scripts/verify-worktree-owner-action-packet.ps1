param(
  [string]$OwnerDecisionCandidatesPath = ".phase1-artifacts\worktree-owner-decision-candidates-20260511.json",
  [string]$OwnerDecisionPacketPath = ".phase1-artifacts\worktree-owner-decision-packet-20260510.json",
  [string]$TemplatePath = "docs\analysis\WORKTREE_OWNER_DECISION_TEMPLATE_2026-05-10.json",
  [string]$SchemaPath = "docs\analysis\WORKTREE_OWNER_DECISION_SCHEMA_2026-05-11.json",
  [string]$OutputPath = ".phase1-artifacts\worktree-owner-action-packet-20260511.json",
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

function Test-PropertyPresent([object]$Object, [string]$Name) {
  if ($null -eq $Object) {
    return $false
  }

  return ($null -ne $Object.PSObject.Properties[$Name])
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  Invoke-DependencyVerifier -ScriptName "verify-worktree-owner-decision-candidates.ps1" -OutputPath $OwnerDecisionCandidatesPath
  Invoke-DependencyVerifier -ScriptName "verify-worktree-owner-decision-packet.ps1" -OutputPath $OwnerDecisionPacketPath

  $candidates = Read-JsonArtifact -Path $OwnerDecisionCandidatesPath -Label "owner-decision-candidates"
  $packet = Read-JsonArtifact -Path $OwnerDecisionPacketPath -Label "owner-decision-packet"
  $template = $null
  $findings = [System.Collections.Generic.List[object]]::new()

  if (-not (Test-Path -LiteralPath $TemplatePath)) {
    Add-Finding $findings "template_missing" "exists" $TemplatePath
  } else {
    try {
      $template = Get-Content -LiteralPath $TemplatePath -Raw | ConvertFrom-Json
    } catch {
      Add-Finding $findings "template_invalid_json" "valid JSON" $_.Exception.Message
    }
  }
  if (-not (Test-Path -LiteralPath $SchemaPath)) {
    Add-Finding $findings "schema_missing" "exists" $SchemaPath
  } else {
    try {
      Get-Content -LiteralPath $SchemaPath -Raw | ConvertFrom-Json | Out-Null
    } catch {
      Add-Finding $findings "schema_invalid_json" "valid JSON" $_.Exception.Message
    }
  }

  $requiredDecisionFile = "docs\analysis\worktree-owner-decision-20260510.json"
  $requiredFields = @("decision_id", "decided_at", "approved_by", "strategy", "allowed_actions", "scope", "notes")
  $requiredAllowedActions = @("may_move", "may_delete", "may_unstage", "may_stage", "may_commit", "may_push", "may_deploy")
  $allowedStrategies = @("cleanup-first", "evidence-only-rebaseline", "runtime-rebaseline", "defer")

  if ($candidates.valid -ne $true) {
    Add-Finding $findings "owner_decision_candidates_valid" "true" ([string]$candidates.valid)
  }
  $decisionRequired = ($packet.decision_required -eq $true)
  if ([bool]$candidates.decision_required -ne $decisionRequired) {
    Add-Finding $findings "decision_required" ([string]$decisionRequired) ([string]$candidates.decision_required)
  }
  if ([int]$candidates.candidate_count -ne 4) {
    Add-Finding $findings "candidate_count" "4" ([string]$candidates.candidate_count)
  }
  if ([int]$candidates.currently_actionable_candidate_count -lt 1) {
    Add-Finding $findings "currently_actionable_candidate_count" ">=1" ([string]$candidates.currently_actionable_candidate_count)
  }
  if ($packet.valid -ne $true) {
    Add-Finding $findings "owner_decision_packet_valid" "true" ([string]$packet.valid)
  }
  if ([string]$packet.required_decision_file -ne $requiredDecisionFile) {
    Add-Finding $findings "required_decision_file" $requiredDecisionFile ([string]$packet.required_decision_file)
  }

  foreach ($field in $requiredFields) {
    if (-not (Test-PropertyPresent -Object $template -Name $field)) {
      Add-Finding $findings "template_field_missing:$field" "present" "missing"
    }
  }
  if (Test-PropertyPresent -Object $template -Name "allowed_actions") {
    foreach ($action in $requiredAllowedActions) {
      if (-not (Test-PropertyPresent -Object $template.allowed_actions -Name $action)) {
        Add-Finding $findings "template_allowed_action_missing:$action" "present" "missing"
      }
    }
  }

  $currentlyActionable = @($candidates.candidates | Where-Object { $_.currently_actionable -eq $true })
  $actionableStrategies = @($currentlyActionable | Select-Object -ExpandProperty strategy)
  foreach ($strategy in @($actionableStrategies)) {
    if ($allowedStrategies -notcontains $strategy) {
      Add-Finding $findings "actionable_strategy_not_allowed" ($allowedStrategies -join ",") ([string]$strategy)
    }
  }

  $ownerActions = @()
  if ($decisionRequired) {
    $ownerActions += [ordered]@{
      id = "create-owner-decision-file"
      target_path = $requiredDecisionFile
      source_template = $TemplatePath
      source_schema = $SchemaPath
      candidate_source_artifact = $OwnerDecisionCandidatesPath
      required_fields = $requiredFields
      required_allowed_actions = $requiredAllowedActions
      allowed_strategies = $allowedStrategies
      currently_actionable_strategies = @($actionableStrategies)
      hard_false_actions = @("may_commit", "may_push", "may_deploy")
      instructions = @(
        "Copy the template structure into the target path.",
        "Validate the decision shape against the schema path before rerunning gates.",
        "Set approved_by to the responsible human owner.",
        "Set decided_at to an ISO-8601 timestamp.",
        "Choose exactly one allowed strategy.",
        "Keep may_commit, may_push, and may_deploy false.",
        "Rerun scripts\\verify.ps1 -Suite release-boundary -ReportOnly -MaxWaitSeconds 1."
      )
      mutates_repository = $false
      executed_by_this_gate = $false
    }
  }

  $valid = ($findings.Count -eq 0)
  $ready = ($valid -and -not $decisionRequired)
  $status = if ($valid) {
    if ($ready) { "owner-action-packet-valid-ready" } else { "owner-action-packet-valid-blocked" }
  } else {
    "owner-action-packet-invalid"
  }

  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    status = $status
    valid = $valid
    ready = $ready
    decision_required = $decisionRequired
    action_count = @($ownerActions).Count
    candidate_count = [int]$candidates.candidate_count
    currently_actionable_strategy_count = @($actionableStrategies).Count
    finding_count = $findings.Count
    findings = @($findings)
    required_decision_file = $requiredDecisionFile
    owner_actions = @($ownerActions)
    source_artifacts = [ordered]@{
      owner_decision_candidates = $OwnerDecisionCandidatesPath
      owner_decision_packet = $OwnerDecisionPacketPath
      template = $TemplatePath
      schema = $SchemaPath
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
      required_next_action = if ($decisionRequired) {
        "Owner must create the real decision file from the template and rerun release-boundary."
      } else {
        "Owner decision file is present and valid; continue with cleanup/split/security gates."
      }
    }
    leak_prevention = [ordered]@{
      source_file_contents_included = $false
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
    Write-Host "[worktree-owner-action-packet] status=$($summary.status)"
    Write-Host "[worktree-owner-action-packet] valid=$($summary.valid)"
    Write-Host "[worktree-owner-action-packet] ready=$($summary.ready)"
    Write-Host "[worktree-owner-action-packet] decision_required=$($summary.decision_required)"
    Write-Host "[worktree-owner-action-packet] action_count=$($summary.action_count)"
    Write-Host "[worktree-owner-action-packet] candidate_count=$($summary.candidate_count)"
    Write-Host "[worktree-owner-action-packet] finding_count=$($summary.finding_count)"
    foreach ($finding in @($findings)) {
      Write-Host ("[worktree-owner-action-packet] finding={0} expected={1} actual={2}" -f $finding.id, $finding.expected, $finding.actual)
    }
  }

  if (-not $valid -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}

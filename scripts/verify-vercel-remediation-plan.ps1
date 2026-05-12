param(
  [string]$VercelAccessPath = ".phase1-artifacts\vercel-access-20260510.json",
  [string]$OutputPath = ".phase1-artifacts\vercel-remediation-plan-20260511.json",
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

function New-RemediationAction([string]$Id, [string]$Owner, [string]$Action, [string]$VerificationGate, [bool]$RequiresDashboard, [bool]$RequiresSecretChange) {
  return [pscustomobject]@{
    id = $Id
    owner = $Owner
    action = $Action
    verification_gate = $VerificationGate
    requires_dashboard = $RequiresDashboard
    requires_secret_change = $RequiresSecretChange
    mutates_repository = $false
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  Invoke-DependencyVerifier -ScriptName "verify-vercel-access.ps1" -OutputPath $VercelAccessPath
  $vercelAccess = Read-JsonArtifact -Path $VercelAccessPath -Label "vercel-access"

  $findings = [System.Collections.Generic.List[object]]::new()
  $knownClassifications = @(
    "project_visible_with_configured_team",
    "project_visible_without_configured_team_team_scope_mismatch",
    "project_listed_but_direct_lookup_failed",
    "token_valid_but_project_not_visible",
    "token_invalid_or_expired",
    "token_forbidden_for_project_or_team",
    "missing_vercel_token",
    "missing_vercel_project_id",
    "vercel_api_unreachable_or_scope_unknown",
    "node_unavailable",
    "node_probe_non_json"
  )
  $classification = [string]$vercelAccess.classification
  if ($knownClassifications -notcontains $classification) {
    Add-Finding -Findings $findings -Id "unknown_vercel_classification" -Expected ($knownClassifications -join ",") -Actual $classification
  }

  $actions = [System.Collections.Generic.List[object]]::new()
  switch ($classification) {
    "project_visible_with_configured_team" {
      $actions.Add((New-RemediationAction "none-required" "cloud-owner" "Vercel project is visible with the configured team; continue to release-boundary gates." "verify-vercel-access.ps1" $false $false))
    }
    "project_visible_without_configured_team_team_scope_mismatch" {
      $actions.Add((New-RemediationAction "fix-team-scope" "cloud-owner" "Correct VERCEL_TEAM_ID/VERCEL_ORG_ID or relink the local project to the visible team." "verify-vercel-access.ps1" $true $false))
      $actions.Add((New-RemediationAction "explicit-link" "cloud-owner" "Run an explicit non-interactive link with the intended project and scope, then rerun the Vercel access gate." "verify-vercel-access.ps1" $true $false))
    }
    "project_listed_but_direct_lookup_failed" {
      $actions.Add((New-RemediationAction "relink-project" "cloud-owner" "Relink apps/frontend to the listed project so direct lookup and project JSON agree." "verify-vercel-access.ps1" $true $false))
    }
    "token_valid_but_project_not_visible" {
      $actions.Add((New-RemediationAction "grant-project-access" "cloud-owner" "Use a Vercel account/team token that can read the configured project." "verify-vercel-access.ps1" $true $true))
      $actions.Add((New-RemediationAction "relink-project-json" "cloud-owner" "Relink apps/frontend/.vercel/project.json to a project visible to the current account/team." "verify-vercel-access.ps1" $true $false))
      $actions.Add((New-RemediationAction "confirm-team-membership" "cloud-owner" "Confirm the Vercel account is a member of the configured team and can list the project." "verify-vercel-access.ps1" $true $false))
    }
    "token_invalid_or_expired" {
      $actions.Add((New-RemediationAction "replace-token" "cloud-owner" "Replace the private Vercel token and rerun the access gate; never commit the token." "verify-vercel-access.ps1" $false $true))
    }
    "token_forbidden_for_project_or_team" {
      $actions.Add((New-RemediationAction "grant-token-scope" "cloud-owner" "Grant the token/account access to the configured team/project." "verify-vercel-access.ps1" $true $true))
    }
    "missing_vercel_token" {
      $actions.Add((New-RemediationAction "set-private-token" "cloud-owner" "Set VERCEL_TOKEN in the private local env file, not in the repo." "verify-vercel-access.ps1" $false $true))
    }
    "missing_vercel_project_id" {
      $actions.Add((New-RemediationAction "restore-project-link" "cloud-owner" "Restore apps/frontend/.vercel/project.json or set a private VERCEL_PROJECT_ID." "verify-vercel-access.ps1" $true $false))
    }
    default {
      $actions.Add((New-RemediationAction "inspect-vercel-access" "cloud-owner" "Inspect Vercel account, team, API availability, and local link state before any deployment." "verify-vercel-access.ps1" $true $false))
    }
  }

  $ready = ($vercelAccess.safe_to_deploy_via_vercel -eq $true)
  $valid = ($findings.Count -eq 0)
  $status = if ($valid) {
    if ($ready) { "vercel-remediation-ready" } else { "vercel-remediation-valid-blocked" }
  } else {
    "vercel-remediation-invalid"
  }

  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    status = $status
    valid = $valid
    ready = $ready
    finding_count = $findings.Count
    findings = @($findings)
    vercel_access_path = $VercelAccessPath
    classification = $classification
    access_status = $vercelAccess.status
    safe_to_deploy_via_vercel = $ready
    token_present = [bool]$vercelAccess.token_present
    project_json_present = [bool]$vercelAccess.project_json_present
    project_id_present = [bool]$vercelAccess.project_id_present
    team_id_present = [bool]$vercelAccess.team_id_present
    http_status_project_with_team = [int]$vercelAccess.http_status_project_with_team
    remediation_action_count = $actions.Count
    remediation_actions = @($actions)
    proof_commands = @(
      "powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-vercel-access.ps1 -ReportOnly",
      "powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -Suite release-boundary -ReportOnly -MaxWaitSeconds 1"
    )
    redaction = [ordered]@{
      project_id_included = $false
      team_id_included = $false
      token_included = $false
      env_values_included = $false
      probe_body_included = $false
    }
    policy = [ordered]@{
      mutates_repository = $false
      executes_requested_actions = $false
      may_set_secret = $false
      may_relink_project = $false
      may_deploy = $false
      may_release = $false
      required_next_action = if ($ready) {
        "Vercel access is ready; continue with the release-boundary suite."
      } else {
        "Apply one remediation action outside this verifier, then rerun verify-vercel-access.ps1."
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
    Write-Host "[vercel-remediation-plan] status=$($summary.status)"
    Write-Host "[vercel-remediation-plan] valid=$($summary.valid)"
    Write-Host "[vercel-remediation-plan] ready=$($summary.ready)"
    Write-Host "[vercel-remediation-plan] classification=$($summary.classification)"
    Write-Host "[vercel-remediation-plan] remediation_action_count=$($summary.remediation_action_count)"
    Write-Host "[vercel-remediation-plan] finding_count=$($summary.finding_count)"
  }

  if (-not $valid -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}

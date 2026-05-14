param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [switch]$AllowLocalhost,
  [switch]$ReportOnly,
  [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"

function Assert-Equal($Label, $Actual, $Expected) {
  if ($Actual -ne $Expected) {
    throw "Autonomous roster/master-plan bundle verification failed: $Label expected '$Expected' but got '$Actual'."
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Autonomous roster/master-plan bundle verification failed: $Label"
  }
}

function Assert-False($Label, $Value) {
  if ([bool]$Value) {
    throw "Autonomous roster/master-plan bundle verification failed: $Label expected false."
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Autonomous roster/master-plan bundle verification failed: $Label missing '$Expected'."
  }
}

function Assert-NotSecretBearing($Label, $Value) {
  $text = ($Value | Out-String)
  $forbiddenPattern = "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Bearer [A-Za-z0-9_.-]{16,}|Cookie:|Set-Cookie:|BEGIN PRIVATE KEY|private key|raw_file_contents|redaction-proof-value"
  if ($text -match $forbiddenPattern) {
    throw "Autonomous roster/master-plan bundle verification failed: $Label contained a forbidden secret/raw-payload pattern."
  }
}

function Invoke-JsonApi([string]$Url) {
  return Invoke-RestMethod -Method Get -Uri $Url -Headers @{ Accept = "application/json" } -TimeoutSec 60
}

function Invoke-Text([string]$Url) {
  $response = Invoke-WebRequest -UseBasicParsing -Method Get -Uri $Url -TimeoutSec 60
  Assert-Equal "$Url HTTP status" ([int]$response.StatusCode) 200
  return [string]$response.Content
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    throw "BaseUrl is required."
  }
  $BaseUrl = $BaseUrl.TrimEnd("/")
  if ((-not $AllowLocalhost) -and ($BaseUrl -notmatch "^https://")) {
    throw "Autonomous roster/master-plan bundle requires HTTPS unless -AllowLocalhost is set."
  }

  $config = Get-Content -LiteralPath "docs\release-artifacts\current-release-candidate.json" -Raw | ConvertFrom-Json
  Assert-False "production rollout claimed" $config.production_rollout_claimed

  $masterContract = Invoke-JsonApi "$BaseUrl/api/v1/team/master-plan/contract"
  Assert-Equal "master plan contract version" $masterContract.contract_version "autonomous-master-plan-v1"
  Assert-Equal "master plan runtime endpoint" $masterContract.runtime_endpoint "GET /api/v1/team/master-plan"
  Assert-Equal "master plan evidence" $masterContract.evidence_ref "autonomous_master_plan_runtime_visible"
  foreach ($role in @("supervisor", "planner", "explorer", "coder", "tester")) {
    Assert-True "master plan required role $role" (@($masterContract.required_logical_roles) -contains $role)
  }
  Assert-True "master plan required project state" (@($masterContract.required_documents) -contains "PROJECT_STATE.md")

  $masterPlan = Invoke-JsonApi "$BaseUrl/api/v1/team/master-plan"
  Assert-Equal "master plan version" $masterPlan.contract_version "autonomous-master-plan-v1"
  Assert-Equal "master plan status" $masterPlan.status "loaded"
  Assert-Equal "master plan source" $masterPlan.source_document "PROJECT_STATE.md"
  Assert-Equal "master plan binding document" $masterPlan.binding_document "docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md"
  Assert-Equal "master plan progress manifest" $masterPlan.progress_manifest "docs/project-progress.manifest.json"
  Assert-Equal "master plan evidence ref" $masterPlan.evidence_ref "autonomous_master_plan_runtime_visible"
  Assert-Equal "master plan phase 2" ([int]$masterPlan.phase_percentages.phase_2) 88
  Assert-Equal "master plan phase 5" ([int]$masterPlan.phase_percentages.phase_5) 75
  Assert-Equal "master plan agent pool" ([int]$masterPlan.layer_percentages.layer_3) 74
  Assert-True "master plan dispatch endpoints" (@($masterPlan.dispatch_endpoints) -contains "POST /api/v1/task/dispatch")
  Assert-True "master plan external runtime status visible" (@("disabled", "ready") -contains [string]$masterPlan.external_runtime_adapter.status)
  Assert-NotSecretBearing "master plan payload" ($masterPlan | ConvertTo-Json -Depth 20 -Compress)

  $rosterContract = Invoke-JsonApi "$BaseUrl/api/v1/team/roster/contract"
  Assert-Equal "roster contract version" $rosterContract.contract_version "autonomous-agent-roster-v1"
  Assert-Equal "roster runtime endpoint" $rosterContract.runtime_endpoint "GET /api/v1/team/roster"
  Assert-Equal "roster evidence" $rosterContract.evidence_ref "autonomous_agent_roster_runtime_visible"
  Assert-True "roster required document" (@($rosterContract.required_documents) -contains "docs/codex-integration/autonomous-agent-roster.json")
  foreach ($binding in @("langgraph", "external_adapter")) {
    Assert-True "roster required runtime binding $binding" (@($rosterContract.required_runtime_binding_keys) -contains $binding)
  }

  $roster = Invoke-JsonApi "$BaseUrl/api/v1/team/roster"
  Assert-Equal "roster version" $roster.contract_version "autonomous-agent-roster-v1"
  Assert-Equal "roster status" $roster.status "loaded"
  Assert-Equal "roster source" $roster.source_document "docs/codex-integration/autonomous-agent-roster.json"
  Assert-Equal "roster evidence ref" $roster.evidence_ref "autonomous_agent_roster_runtime_visible"
  Assert-True "roster role count" ([int]$roster.role_count -ge 14)
  $roleIds = @($roster.roles | ForEach-Object { [string]$_.id })
  foreach ($roleId in @("default", "explorer", "worker", "backend_platform", "cloud_infra_devops")) {
    Assert-True "roster role $roleId visible" ($roleIds -contains $roleId)
  }
  Assert-Equal "langgraph binding active" $roster.runtime_bindings.langgraph.status "active"
  Assert-True "external adapter status visible" (@("disabled", "ready") -contains [string]$roster.runtime_bindings.external_adapter.status)
  Assert-True "validated startable default" (@($roster.launcher_status.validated_startable) -contains "default")
  Assert-True "validated startable worker" (@($roster.launcher_status.validated_startable) -contains "worker")
  Assert-NotSecretBearing "roster payload" ($roster | ConvertTo-Json -Depth 30 -Compress)

  $teamStatus = Invoke-JsonApi "$BaseUrl/api/v1/team/status"
  Assert-Equal "team status contract version" $teamStatus.contract_version "autonomous-coding-team-v1"
  Assert-Equal "team dispatch contract version" $teamStatus.dispatch_contract_version "autonomous-task-dispatch-v1"
  Assert-True "team runtime source visible" (@("internal_queue", "external_adapter") -contains [string]$teamStatus.runtime_source)
  Assert-True "team external runtime status visible" (@("disabled", "ready") -contains [string]$teamStatus.external_runtime.status)
  Assert-True "team logical roles" (@($teamStatus.logical_roles).Count -eq 5)

  $dispatches = Invoke-JsonApi "$BaseUrl/api/v1/task/dispatches/recent?limit=10"
  Assert-Equal "dispatch feed contract version" $dispatches.contract_version "autonomous-task-dispatch-v1"
  $completedDispatches = @($dispatches.dispatches | Where-Object { $_.status -eq "completed" })
  Assert-True "completed dispatch visible" ($completedDispatches.Count -ge 1)
  $firstDispatch = $null
  foreach ($dispatch in $completedDispatches) {
    $assignmentRoles = @($dispatch.assignments | Where-Object {
      $_.status -eq "completed" -and
      $_.provenance_evidence_ref -eq "autonomous_team_dispatch_task_provenance"
    } | ForEach-Object { [string]$_.logical_role })
    $allRolesVisible = $true
    foreach ($role in @("supervisor", "planner", "explorer", "coder", "tester")) {
      if (-not ($assignmentRoles -contains $role)) {
        $allRolesVisible = $false
      }
    }
    if ($allRolesVisible) {
      $firstDispatch = $dispatch
      break
    }
  }
  Assert-True "completed dispatch has five role assignments" ($null -ne $firstDispatch)
  $firstDispatchRoles = @($firstDispatch.assignments | Where-Object {
    $_.status -eq "completed" -and
    $_.provenance_evidence_ref -eq "autonomous_team_dispatch_task_provenance"
  } | ForEach-Object { [string]$_.logical_role })
  foreach ($role in @("supervisor", "planner", "explorer", "coder", "tester")) {
    Assert-True "completed dispatch assignment $role" ($firstDispatchRoles -contains $role)
  }
  Assert-NotSecretBearing "dispatch feed payload" ($dispatches | ConvertTo-Json -Depth 30 -Compress)

  $homepage = Invoke-Text "$BaseUrl/"
  foreach ($marker in @("Autonomous Master Plan", "Persisted Agent Roster")) {
    Assert-Contains "homepage marker" $homepage $marker
  }
  Assert-NotSecretBearing "homepage" $homepage

  $summary = [ordered]@{
    status = "passed"
    passed = $true
    base_url = $BaseUrl
    active_release_id = [string]$config.active_release_id
    production_rollout_claimed = $false
    master_plan_contract_version = [string]$masterPlan.contract_version
    master_plan_evidence_ref = [string]$masterPlan.evidence_ref
    roster_contract_version = [string]$roster.contract_version
    roster_evidence_ref = [string]$roster.evidence_ref
    roster_role_count = [int]$roster.role_count
    team_contract_version = [string]$teamStatus.contract_version
    completed_dispatch_visible = $true
    policy = [ordered]@{
      mutates_production = $false
      deploys_production = $false
      claims_rollout = $false
      reads_secret_values = $false
      includes_secrets = $false
      live_provider_calls_claimed = $false
      live_mcp_writes_claimed = $false
    }
  }

  if ($JsonOnly) {
    $summary | ConvertTo-Json -Depth 8
  } else {
    Write-Host "[autonomous-roster-master-plan-bundle] verified"
    Write-Host "[autonomous-roster-master-plan-bundle] base_url=$BaseUrl"
    Write-Host "[autonomous-roster-master-plan-bundle] roster_role_count=$($summary.roster_role_count)"
  }
} catch {
  if ($ReportOnly) {
    $summary = [ordered]@{
      status = "failed"
      passed = $false
      base_url = $BaseUrl
      error = $_.Exception.Message
      production_rollout_claimed = $false
    }
    if ($JsonOnly) {
      $summary | ConvertTo-Json -Depth 4
    } else {
      Write-Host "[autonomous-roster-master-plan-bundle] failed"
      Write-Host "[autonomous-roster-master-plan-bundle] error=$($_.Exception.Message)"
    }
    exit 0
  }
  throw
} finally {
  Pop-Location
}

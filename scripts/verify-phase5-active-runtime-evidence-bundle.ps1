param(
  [string]$ReleaseId = "",
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [switch]$AllowLocalhost,
  [switch]$ReportOnly,
  [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"

function Assert-Equal($Label, $Actual, $Expected) {
  if ($Actual -ne $Expected) {
    throw "Phase5 active runtime evidence bundle verification failed: $Label expected '$Expected' but got '$Actual'."
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase5 active runtime evidence bundle verification failed: $Label"
  }
}

function Assert-False($Label, $Value) {
  if ([bool]$Value) {
    throw "Phase5 active runtime evidence bundle verification failed: $Label expected false."
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Phase5 active runtime evidence bundle verification failed: $Label missing '$Expected'."
  }
}

function Assert-NotSecretBearing($Label, $Value) {
  $text = ($Value | Out-String)
  $forbiddenPattern = "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Bearer [A-Za-z0-9_.-]{16,}|Cookie:|Set-Cookie:|BEGIN PRIVATE KEY|private key|raw_file_contents|redaction-proof-value"
  if ($text -match $forbiddenPattern) {
    throw "Phase5 active runtime evidence bundle verification failed: $Label contained a forbidden secret/raw-payload pattern."
  }
}

function Assert-Sha($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[0-9a-f]{40}$') {
    throw "Phase5 active runtime evidence bundle verification failed: $Label is not a lowercase 40-character SHA."
  }
}

function Assert-ReleaseId($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^prod-candidate-[0-9]{4}-[0-9]{2}-[0-9]{2}-rc[0-9]+$') {
    throw "Phase5 active runtime evidence bundle verification failed: $Label is not a valid release candidate id."
  }
}

function Assert-RequiredRefs($Label, $Refs, [string[]]$RequiredRefs) {
  $visibleRefs = @($Refs | ForEach-Object { [string]$_ })
  foreach ($ref in $RequiredRefs) {
    Assert-True "$Label $ref" ($visibleRefs -contains $ref)
  }
}

function Invoke-JsonApi([string]$Url) {
  return Invoke-RestMethod -Method Get -Uri $Url -Headers @{ Accept = "application/json" } -TimeoutSec 90
}

function Invoke-Text([string]$Url) {
  $response = Invoke-WebRequest -UseBasicParsing -Method Get -Uri $Url -TimeoutSec 60
  Assert-Equal "$Url HTTP status" ([int]$response.StatusCode) 200
  return [string]$response.Content
}

function Assert-RuntimeRun($Run) {
  Assert-Equal "runtime run contract version" $Run.contract_version "phase2-runtime-v1"
  Assert-Equal "runtime run status" $Run.status "completed"
  Assert-Equal "runtime run node" $Run.node_name "completed"
  Assert-Equal "runtime run checkpointing" $Run.checkpointing "postgres"
  Assert-False "runtime run live provider calls" $Run.live_provider_calls
  Assert-False "runtime run live mcp writes" $Run.live_mcp_writes
  Assert-False "runtime run production deploy" $Run.production_deploy
  Assert-Equal "runtime run evidence ref" $Run.evidence_ref "phase2_runtime_run_status_visible"
  Assert-Equal "runtime run aggregation evidence" $Run.aggregation_evidence_ref "agent_result_aggregation_complete"
  Assert-True "runtime run role summary count" ([int]$Run.role_summary_count -ge 4)
  Assert-RequiredRefs "runtime run evidence refs" $Run.evidence_refs @(
    "phase2_runtime_graph_started",
    "task_assignment_completed",
    "memory_update_persisted",
    "agent_result_aggregation_complete"
  )
  $roles = @($Run.per_role_results | ForEach-Object { [string]$_.role })
  foreach ($role in @("planner", "coder", "tester", "devops")) {
    Assert-True "runtime run role $role visible" ($roles -contains $role)
    $roleResult = @($Run.per_role_results | Where-Object { [string]$_.role -eq $role }) | Select-Object -First 1
    Assert-Equal "runtime run role $role status" $roleResult.status "completed"
    Assert-True "runtime run role $role done validation" ([bool]$roleResult.done_validation.implemented -and [bool]$roleResult.done_validation.tested -and [bool]$roleResult.done_validation.logged)
    Assert-Equal "runtime run role $role llm routing policy" $roleResult.llm_routing_policy_decision "allow_primary"
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    throw "BaseUrl is required."
  }
  $BaseUrl = $BaseUrl.TrimEnd("/")
  if ((-not $AllowLocalhost) -and ($BaseUrl -notmatch "^https://")) {
    throw "Phase5 active runtime evidence bundle requires HTTPS unless -AllowLocalhost is set."
  }

  $configPath = "docs\release-artifacts\current-release-candidate.json"
  Assert-True "current release candidate config exists" (Test-Path -LiteralPath $configPath)
  $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
  $activeReleaseId = [string]$config.active_release_id
  if ([string]::IsNullOrWhiteSpace($ReleaseId)) {
    $ReleaseId = $activeReleaseId
  }
  Assert-Equal "release id" $ReleaseId $activeReleaseId
  Assert-ReleaseId "release id" $ReleaseId
  Assert-False "production rollout claimed" $config.production_rollout_claimed

  $candidatePath = "docs\release-artifacts\$ReleaseId.md"
  Assert-True "active release candidate artifact exists" (Test-Path -LiteralPath $candidatePath)
  $candidate = Get-Content -LiteralPath $candidatePath -Raw
  Assert-Contains "candidate id" $candidate "release_id: ``$ReleaseId``"
  Assert-Contains "candidate environment" $candidate "environment: ``production-candidate``"
  Assert-Contains "candidate non-claim" $candidate "This artifact does not claim a production rollout."
  Assert-Contains "candidate phase2 proof link" $candidate "phase2_runtime_dual_surface_proof: ``docs/release-artifacts/$ReleaseId-phase2-runtime-dual-surface-20260514.md``"
  Assert-Contains "candidate runtime bundle proof link" $candidate "active_runtime_evidence_bundle_proof: ``docs/release-artifacts/$ReleaseId-active-runtime-evidence-bundle-20260514.md``"
  Assert-NotSecretBearing "candidate artifact" $candidate

  if ($candidate -notmatch '(?m)^source_commit_sha:\s*`([^`]+)`\s*$') {
    throw "Active release artifact is missing source_commit_sha."
  }
  $sourceSha = $Matches[1]
  Assert-Sha "source commit sha" $sourceSha
  if ($candidate -notmatch '(?m)^immutable_image_commit_sha:\s*`([^`]+)`\s*$') {
    throw "Active release artifact is missing immutable_image_commit_sha."
  }
  $immutableSha = $Matches[1]
  Assert-Sha "immutable image commit sha" $immutableSha

  $proofPath = "docs\release-artifacts\$ReleaseId-active-runtime-evidence-bundle-20260514.md"
  Assert-True "active runtime evidence bundle proof exists" (Test-Path -LiteralPath $proofPath)
  $proof = Get-Content -LiteralPath $proofPath -Raw
  foreach ($required in @(
    "Status: ``verified``",
    "release_id: ``$ReleaseId``",
    "source_commit_sha: ``$sourceSha``",
    "immutable_image_commit_sha: ``$immutableSha``",
    "production_rollout_claimed: ``false``",
    "runtime_surface_count: ``8``",
    "This proof does not claim a production rollout.",
    "This proof does not claim release promotion.",
    "This proof does not claim live LLM provider calls.",
    "This proof does not claim live MCP writes.",
    "This proof does not claim local model downloads.",
    "This proof does not include secret values."
  )) {
    Assert-Contains "active runtime proof artifact" $proof $required
  }
  if ($AllowLocalhost) {
    Assert-Contains "active runtime proof local control plane" $proof "local_control_plane_url: ``$BaseUrl``"
  } else {
    Assert-Contains "active runtime proof base url" $proof "base_url: ``$BaseUrl``"
  }
  Assert-NotSecretBearing "active runtime proof artifact" $proof

  $progress = Invoke-JsonApi "$BaseUrl/api/v1/project/progress"
  Assert-Equal "progress overall" ([int]$progress.overall_percent) 81
  $phase2 = @($progress.horizontal.items | Where-Object { $_.id -eq "phase_2" }) | Select-Object -First 1
  $phase5 = @($progress.horizontal.items | Where-Object { $_.id -eq "phase_5" }) | Select-Object -First 1
  Assert-Equal "progress phase2" ([int]$phase2.percent) 88
  Assert-Equal "progress phase5" ([int]$phase5.percent) 82
  Assert-NotSecretBearing "progress payload" ($progress | ConvertTo-Json -Depth 20 -Compress)

  $integrity = Invoke-JsonApi "$BaseUrl/api/v1/project/progress/integrity"
  Assert-Equal "progress integrity version" $integrity.contract_version "project-progress-integrity-v1"
  Assert-Equal "progress integrity status" $integrity.status "verified"
  Assert-Equal "progress integrity manifest percent" ([int]$integrity.manifest_overall_percent) 81
  Assert-Equal "progress integrity computed percent" ([int]$integrity.computed_overall_percent) 81
  Assert-True "progress integrity no mismatches" (@($integrity.mismatches).Count -eq 0)

  $runtimeContract = Invoke-JsonApi "$BaseUrl/api/v1/phase2/runtime/contract"
  Assert-Equal "runtime contract version" $runtimeContract.contract_version "phase2-runtime-v1"
  Assert-Equal "runtime contract mode" $runtimeContract.mode "deterministic_local_runtime"
  Assert-Equal "runtime contract engine" $runtimeContract.engine "langgraph"
  Assert-Equal "runtime contract checkpointing" $runtimeContract.checkpointing "postgres"
  Assert-False "runtime contract live provider calls" $runtimeContract.live_provider_calls
  Assert-False "runtime contract live mcp writes" $runtimeContract.live_mcp_writes
  Assert-False "runtime contract production deploy" $runtimeContract.production_deploy
  Assert-RequiredRefs "runtime contract evidence refs" $runtimeContract.required_evidence_refs @(
    "phase2_runtime_graph_started",
    "phase2_sse_event_contract_proof",
    "langgraph_mcp_timeout_controlled",
    "task_assignment_completed",
    "memory_update_persisted"
  )

  $runs = Invoke-JsonApi "$BaseUrl/api/v1/phase2/runtime/runs?limit=5"
  Assert-Equal "runs contract version" $runs.contract_version "phase2-runtime-v1"
  Assert-Equal "runs mode" $runs.mode "audit_log_backed_phase2_runtime_runs"
  Assert-Equal "runs evidence ref" $runs.evidence_ref "phase2_runtime_run_status_visible"
  Assert-True "runs visible" (@($runs.runs).Count -ge 1)
  $latestRun = @($runs.runs)[0]
  Assert-RuntimeRun $latestRun
  Assert-NotSecretBearing "runs payload" ($runs | ConvertTo-Json -Depth 40 -Compress)

  $orchestratorManifest = Invoke-JsonApi "$BaseUrl/api/v1/orchestrator/manifest"
  Assert-Equal "orchestrator engine" $orchestratorManifest.engine "langgraph"
  Assert-Equal "orchestrator mode" $orchestratorManifest.mode "deterministic_dry_run"
  Assert-Equal "orchestrator checkpointing" $orchestratorManifest.checkpointing "postgres"
  Assert-False "orchestrator live provider calls" $orchestratorManifest.live_provider_calls
  Assert-True "orchestrator node coverage" (@($orchestratorManifest.nodes).Count -ge 7)
  Assert-True "orchestrator forbids prod deploy" (@($orchestratorManifest.forbidden_actions) -contains "prod_deploy")
  Assert-True "orchestrator forbids live provider call" (@($orchestratorManifest.forbidden_actions) -contains "live_provider_call")

  $agents = Invoke-JsonApi "$BaseUrl/api/v1/agents/status"
  Assert-True "agent queue depth nonnegative" ([int]$agents.queue_depth -ge 0)
  $agentTypes = @($agents.agents | ForEach-Object { [string]$_.type })
  foreach ($role in @("planner", "coder", "tester", "devops")) {
    Assert-True "agent $role visible" ($agentTypes -contains $role)
    $agent = @($agents.agents | Where-Object { [string]$_.type -eq $role }) | Select-Object -First 1
    Assert-Equal "agent $role profile contract" $agent.profile_contract_version "agent-profiles-v1"
    Assert-True "agent $role status visible" (-not [string]::IsNullOrWhiteSpace([string]$agent.status))
    Assert-True "agent $role latest status visible" (-not [string]::IsNullOrWhiteSpace([string]$agent.latest_status))
    Assert-True "agent $role blocks live provider" (@($agent.blocked_actions) -contains "live_provider_call")
    Assert-True "agent $role blocks prod deploy" (@($agent.blocked_actions) -contains "prod_deploy")
  }
  Assert-NotSecretBearing "agents payload" ($agents | ConvertTo-Json -Depth 30 -Compress)

  $activity = Invoke-JsonApi "$BaseUrl/api/v1/agent-activity/recent?event_type=phase2_runtime_graph_started&limit=5"
  Assert-Equal "activity contract version" $activity.contract_version "agent-activity-trace-v1"
  Assert-Equal "activity evidence ref" $activity.evidence_ref "agent_activity_filtered_feed_visible"
  $runtimeActivity = @($activity.events | Where-Object { $_.event_type -eq "phase2_runtime_graph_started" }) | Select-Object -First 1
  Assert-True "runtime activity event visible" ($null -ne $runtimeActivity)
  Assert-False "runtime activity live provider calls" $runtimeActivity.details.live_provider_calls
  Assert-False "runtime activity live mcp writes" $runtimeActivity.details.live_mcp_writes
  Assert-False "runtime activity production deploy" $runtimeActivity.details.production_deploy
  Assert-Equal "runtime activity aggregation evidence" $runtimeActivity.aggregation_evidence_ref "agent_result_aggregation_complete"
  Assert-True "runtime activity role summary count" ([int]$runtimeActivity.role_summary_count -ge 4)
  Assert-NotSecretBearing "activity payload" ($activity | ConvertTo-Json -Depth 40 -Compress)

  $masterPlan = Invoke-JsonApi "$BaseUrl/api/v1/team/master-plan"
  Assert-Equal "master plan contract version" $masterPlan.contract_version "autonomous-master-plan-v1"
  Assert-Equal "master plan evidence" $masterPlan.evidence_ref "autonomous_master_plan_runtime_visible"
  Assert-Equal "master plan overall" ([int]$masterPlan.overall_percent) 81
  Assert-Equal "master plan phase2" ([int]$masterPlan.phase_percentages.phase_2) 88
  Assert-Equal "master plan phase5" ([int]$masterPlan.phase_percentages.phase_5) 82
  Assert-True "master plan logical roles" (@($masterPlan.logical_roles).Count -eq 5)
  Assert-NotSecretBearing "master plan payload" ($masterPlan | ConvertTo-Json -Depth 20 -Compress)

  $roster = Invoke-JsonApi "$BaseUrl/api/v1/team/roster"
  Assert-Equal "roster contract version" $roster.contract_version "autonomous-agent-roster-v1"
  Assert-Equal "roster evidence" $roster.evidence_ref "autonomous_agent_roster_runtime_visible"
  Assert-True "roster role count" ([int]$roster.role_count -ge 14)
  Assert-Equal "roster langgraph binding" $roster.runtime_bindings.langgraph.status "active"
  Assert-True "roster external adapter status visible" (@("disabled", "ready") -contains [string]$roster.runtime_bindings.external_adapter.status)
  Assert-NotSecretBearing "roster payload" ($roster | ConvertTo-Json -Depth 30 -Compress)

  $teamStatus = Invoke-JsonApi "$BaseUrl/api/v1/team/status"
  Assert-Equal "team status contract version" $teamStatus.contract_version "autonomous-coding-team-v1"
  Assert-Equal "team dispatch contract version" $teamStatus.dispatch_contract_version "autonomous-task-dispatch-v1"
  Assert-True "team logical roles" (@($teamStatus.logical_roles).Count -eq 5)
  Assert-True "team external runtime status visible" (@("disabled", "ready") -contains [string]$teamStatus.external_runtime.status)
  Assert-NotSecretBearing "team status payload" ($teamStatus | ConvertTo-Json -Depth 30 -Compress)

  $homepage = Invoke-Text "$BaseUrl/"
  foreach ($marker in @("LangGraph Progress", "Runtime Runs", "Agent Activity", "Autonomous Master Plan", "Persisted Agent Roster")) {
    Assert-Contains "homepage marker" $homepage $marker
  }
  Assert-NotSecretBearing "homepage" $homepage

  $summary = [ordered]@{
    status = "passed"
    passed = $true
    release_id = $ReleaseId
    base_url = $BaseUrl
    source_commit_sha = $sourceSha
    immutable_image_commit_sha = $immutableSha
    production_rollout_claimed = $false
    runtime_surface_count = 8
    latest_run_id = [string]$latestRun.run_id
    latest_thread_id = [string]$latestRun.thread_id
    role_summary_count = [int]$latestRun.role_summary_count
    surfaces = @(
      "project-progress",
      "project-progress-integrity",
      "phase2-runtime-contract",
      "phase2-runtime-runs",
      "orchestrator-manifest",
      "agents-status",
      "agent-activity",
      "team-roster-master-plan"
    )
    policy = [ordered]@{
      mutates_production = $false
      deploys_production = $false
      claims_rollout = $false
      reads_secret_values = $false
      includes_secrets = $false
      live_provider_calls_claimed = $false
      live_mcp_writes_claimed = $false
      local_model_downloads = $false
    }
  }
  Assert-NotSecretBearing "summary" ($summary | ConvertTo-Json -Depth 8 -Compress)

  if ($JsonOnly) {
    $summary | ConvertTo-Json -Depth 8
  } else {
    Write-Host "[phase5-active-runtime-evidence-bundle] verified"
    Write-Host "[phase5-active-runtime-evidence-bundle] release_id=$ReleaseId"
    Write-Host "[phase5-active-runtime-evidence-bundle] runtime_surface_count=$($summary.runtime_surface_count)"
  }
} catch {
  if ($ReportOnly) {
    $summary = [ordered]@{
      status = "failed"
      passed = $false
      release_id = $ReleaseId
      base_url = $BaseUrl
      error = $_.Exception.Message
      production_rollout_claimed = $false
    }
    if ($JsonOnly) {
      $summary | ConvertTo-Json -Depth 4
    } else {
      Write-Host "[phase5-active-runtime-evidence-bundle] failed"
      Write-Host "[phase5-active-runtime-evidence-bundle] error=$($_.Exception.Message)"
    }
    exit 0
  }
  throw
} finally {
  Pop-Location
}

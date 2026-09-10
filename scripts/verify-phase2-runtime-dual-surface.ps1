param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [switch]$ReportOnly,
  [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"

function Assert-Equal($Label, $Actual, $Expected) {
  if ($Actual -ne $Expected) {
    throw "Phase2 runtime dual-surface verification failed: $Label expected '$Expected' but got '$Actual'."
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase2 runtime dual-surface verification failed: $Label"
  }
}

function Assert-False($Label, $Value) {
  if ([bool]$Value) {
    throw "Phase2 runtime dual-surface verification failed: $Label expected false."
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Phase2 runtime dual-surface verification failed: $Label missing '$Expected'."
  }
}

function Assert-NotSecretBearing($Label, $Value) {
  $text = ($Value | Out-String)
  $forbiddenPattern = "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Bearer [A-Za-z0-9_.-]{16,}|Cookie:|Set-Cookie:|BEGIN PRIVATE KEY|private key|raw_file_contents|redaction-proof-value"
  if ($text -match $forbiddenPattern) {
    throw "Phase2 runtime dual-surface verification failed: $Label contained a forbidden secret/raw-payload pattern."
  }
}

function Invoke-JsonApi([string]$Url, [string]$Method = "GET", $Body = $null) {
  $headers = @{ Accept = "application/json" }
  if ($Method -eq "GET") {
    return Invoke-RestMethod -Method Get -Uri $Url -Headers $headers -TimeoutSec 90
  }

  $jsonBody = if ($Body -is [string]) {
    $Body
  } else {
    $Body | ConvertTo-Json -Depth 20 -Compress
  }
  return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers -ContentType "application/json" -Body $jsonBody -TimeoutSec 120
}

function Invoke-Text([string]$Url) {
  $response = Invoke-WebRequest -UseBasicParsing -Method Get -Uri $Url -TimeoutSec 60
  Assert-Equal "$Url HTTP status" ([int]$response.StatusCode) 200
  return [string]$response.Content
}

function Assert-RequiredRefs($Label, $Refs, [string[]]$RequiredRefs) {
  $visibleRefs = @($Refs | ForEach-Object { [string]$_ })
  foreach ($ref in $RequiredRefs) {
    Assert-True "$Label $ref" ($visibleRefs -contains $ref)
  }
}

function Wait-RunVisible([string]$BaseUrl, [string]$RunId) {
  $runs = $null
  $targetRun = $null
  for ($attempt = 1; $attempt -le 12; $attempt++) {
    $runs = Invoke-JsonApi "$BaseUrl/api/v1/phase2/runtime/runs?limit=10"
    $targetRun = @($runs.runs | Where-Object { [string]$_.run_id -eq $RunId }) | Select-Object -First 1
    if ($null -ne $targetRun) {
      return [pscustomobject]@{
        Runs = $runs
        TargetRun = $targetRun
      }
    }
    Start-Sleep -Seconds 2
  }

  return [pscustomobject]@{
    Runs = $runs
    TargetRun = $null
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    throw "BaseUrl is required."
  }
  $BaseUrl = $BaseUrl.TrimEnd("/")
  $localHttp = $BaseUrl -match "^http://(localhost|127\.0\.0\.1|\[::1\])(:|/|$)"
  if ((-not $AllowLocalhost) -and (-not $localHttp) -and ($BaseUrl -notmatch "^https://")) {
    throw "Phase2 runtime dual-surface proof requires HTTPS unless -AllowLocalhost is set."
  }

  $config = Get-Content -LiteralPath "docs\release-artifacts\current-release-candidate.json" -Raw | ConvertFrom-Json
  Assert-False "production rollout claimed" $config.production_rollout_claimed

  $contract = Invoke-JsonApi "$BaseUrl/api/v1/phase2/runtime/contract"
  Assert-Equal "runtime contract version" $contract.contract_version "phase2-runtime-v1"
  Assert-Equal "runtime mode" $contract.mode "deterministic_local_runtime"
  Assert-Equal "runtime engine" $contract.engine "langgraph"
  Assert-Equal "runtime checkpointing" $contract.checkpointing "postgres"
  Assert-Equal "start endpoint" $contract.start_endpoint "POST /api/v1/phase2/runtime/start"
  Assert-Equal "stream endpoint" $contract.stream_endpoint "POST /api/v1/orchestrator/dry-run/stream"
  Assert-Equal "runs endpoint" $contract.runs_endpoint "GET /api/v1/phase2/runtime/runs"
  Assert-Equal "contract endpoint" $contract.contract_endpoint "GET /api/v1/phase2/runtime/contract"
  Assert-False "runtime live provider calls" $contract.live_provider_calls
  Assert-False "runtime live mcp writes" $contract.live_mcp_writes
  Assert-False "runtime production deploy" $contract.production_deploy
  Assert-Equal "runtime live-provider gate" $contract.gates.gate_d_live_providers "closed"
  Assert-Equal "runtime live-write gate" $contract.gates.gate_e_live_writes_and_deploy "closed"
  Assert-Equal "sse contract version" $contract.sse_event_contract.contract_version "phase2-sse-event-contract-v1"
  Assert-True "sse done event required" (@($contract.sse_event_contract.required_event_types) -contains "done")
  Assert-Equal "mcp timeout orchestrator evidence" $contract.mcp_timeout_contract.orchestrator_evidence_ref "langgraph_mcp_timeout_controlled"
  Assert-RequiredRefs "runtime contract required evidence" $contract.required_evidence_refs @(
    "phase2_runtime_graph_started",
    "phase2_sse_event_contract_proof",
    "langgraph_mcp_timeout_controlled",
    "task_assignment_completed",
    "memory_update_persisted"
  )
  Assert-NotSecretBearing "runtime contract payload" ($contract | ConvertTo-Json -Depth 20 -Compress)

  $startContract = Invoke-JsonApi "$BaseUrl/api/v1/phase2/runtime/start/contract"
  Assert-Equal "start contract version" $startContract.contract_version "phase2-runtime-start-surface-v1"
  Assert-Equal "start contract endpoint" $startContract.endpoint "GET /api/v1/phase2/runtime/start/contract"
  Assert-Equal "start runtime endpoint" $startContract.runtime_endpoint "POST /api/v1/phase2/runtime/start"
  Assert-Equal "start runtime contract version" $startContract.runtime_contract_version "phase2-runtime-v1"
  Assert-Equal "start expected status" $startContract.expected_status "started"
  Assert-Equal "start expected engine" $startContract.expected_engine "langgraph"
  Assert-Equal "start expected mode" $startContract.expected_mode "deterministic_local_runtime"
  Assert-Equal "start expected checkpointing" $startContract.expected_checkpointing "postgres"
  Assert-False "start expected live provider calls" $startContract.expected_live_provider_calls
  Assert-False "start expected live mcp writes" $startContract.expected_live_mcp_writes
  Assert-False "start expected production deploy" $startContract.expected_production_deploy
  Assert-RequiredRefs "start contract required state evidence" $startContract.required_state_evidence_refs @(
    "phase2_runtime_graph_started",
    "task_assignment_completed",
    "memory_update_persisted"
  )
  Assert-NotSecretBearing "start contract payload" ($startContract | ConvertTo-Json -Depth 20 -Compress)

  $projectId = "phase2-dual-surface-" + [Guid]::NewGuid().ToString("N")
  $sessionId = [Guid]::NewGuid().ToString()
  $runtime = Invoke-JsonApi "$BaseUrl/api/v1/phase2/runtime/start" "POST" @{
    project_id = $projectId
    prompt = "phase2 runtime dual-surface verifier"
    session_id = $sessionId
  }

  Assert-Equal "runtime result contract version" $runtime.contract_version "phase2-runtime-v1"
  Assert-Equal "runtime status" $runtime.status "started"
  Assert-Equal "runtime mode" $runtime.mode "deterministic_local_runtime"
  Assert-Equal "runtime engine" $runtime.engine "langgraph"
  Assert-Equal "runtime checkpointing" $runtime.checkpointing "postgres"
  Assert-False "runtime result live provider calls" $runtime.live_provider_calls
  Assert-False "runtime result live mcp writes" $runtime.live_mcp_writes
  Assert-False "runtime result production deploy" $runtime.production_deploy
  Assert-Equal "runtime evidence ref" $runtime.evidence_ref "phase2_runtime_graph_started"
  Assert-True "runtime thread id visible" (-not [string]::IsNullOrWhiteSpace([string]$runtime.thread_id))
  Assert-True "runtime run id visible" (-not [string]::IsNullOrWhiteSpace([string]$runtime.run_id))
  Assert-Equal "runtime state project id" $runtime.state.project_id $projectId
  Assert-Equal "runtime state session id" $runtime.state.session_id $sessionId
  Assert-Equal "runtime state node" $runtime.state.node_name "completed"
  Assert-RequiredRefs "runtime state evidence" $runtime.state.evidence_refs @(
    "phase2_runtime_graph_started",
    "task_assignment_completed",
    "memory_update_persisted",
    "agent_result_aggregation_complete"
  )
  Assert-False "runtime partial failure" $runtime.state.result.partial_failure
  $runtimeRoles = @($runtime.state.result.per_role_results | ForEach-Object { [string]$_.role })
  foreach ($role in @("planner", "coder", "tester", "devops")) {
    Assert-True "runtime role $role visible" ($runtimeRoles -contains $role)
    $roleResult = @($runtime.state.result.per_role_results | Where-Object { [string]$_.role -eq $role }) | Select-Object -First 1
    Assert-Equal "runtime role $role status" $roleResult.status "completed"
    Assert-True "runtime role $role done validation" ([bool]$roleResult.done_validation.implemented -and [bool]$roleResult.done_validation.tested -and [bool]$roleResult.done_validation.logged)
  }
  Assert-NotSecretBearing "runtime start payload" ($runtime | ConvertTo-Json -Depth 40 -Compress)

  $runsContract = Invoke-JsonApi "$BaseUrl/api/v1/phase2/runtime/runs/contract"
  Assert-Equal "runs contract version" $runsContract.contract_version "phase2-runtime-runs-surface-v1"
  Assert-Equal "runs contract endpoint" $runsContract.endpoint "GET /api/v1/phase2/runtime/runs/contract"
  Assert-Equal "runs runtime endpoint" $runsContract.runtime_endpoint "GET /api/v1/phase2/runtime/runs"
  Assert-Equal "runs runtime contract version" $runsContract.runtime_contract_version "phase2-runtime-v1"
  Assert-Equal "runs expected mode" $runsContract.expected_mode "audit_log_backed_phase2_runtime_runs"
  Assert-Equal "runs expected source event type" $runsContract.expected_source_event_type "phase2_runtime_graph_started"
  Assert-RequiredRefs "runs contract required evidence" $runsContract.required_evidence_refs @(
    "phase2_runtime_graph_started",
    "memory_update_persisted",
    "agent_result_aggregation_complete"
  )
  Assert-NotSecretBearing "runs contract payload" ($runsContract | ConvertTo-Json -Depth 20 -Compress)

  $runProbe = Wait-RunVisible -BaseUrl $BaseUrl -RunId ([string]$runtime.run_id)
  $runs = $runProbe.Runs
  $targetRun = $runProbe.TargetRun
  Assert-True "fresh run visible in runs feed" ($null -ne $targetRun)
  Assert-Equal "runs contract version parity" $runs.contract_version $contract.contract_version
  Assert-Equal "runs mode" $runs.mode $runsContract.expected_mode
  Assert-Equal "runs source event type" $runs.source_event_type $runsContract.expected_source_event_type
  Assert-Equal "runs evidence ref" $runs.evidence_ref "phase2_runtime_run_status_visible"
  Assert-True "runs feed count" (@($runs.runs).Count -ge 1)
  Assert-Equal "target run status" $targetRun.status "completed"
  Assert-Equal "target run contract version" $targetRun.contract_version "phase2-runtime-v1"
  Assert-Equal "target run checkpointing" $targetRun.checkpointing "postgres"
  Assert-False "target run live provider calls" $targetRun.live_provider_calls
  Assert-False "target run live mcp writes" $targetRun.live_mcp_writes
  Assert-False "target run production deploy" $targetRun.production_deploy
  Assert-Equal "target run evidence ref" $targetRun.evidence_ref "phase2_runtime_run_status_visible"
  Assert-Equal "target run aggregation evidence" $targetRun.aggregation_evidence_ref "agent_result_aggregation_complete"
  Assert-True "target run role summary count" ([int]$targetRun.role_summary_count -ge 4)
  Assert-RequiredRefs "target run evidence" $targetRun.evidence_refs @(
    "phase2_runtime_graph_started",
    "memory_update_persisted",
    "agent_result_aggregation_complete"
  )
  $targetRoles = @($targetRun.per_role_results | ForEach-Object { [string]$_.role })
  foreach ($role in @("planner", "coder", "tester", "devops")) {
    Assert-True "target run role $role visible" ($targetRoles -contains $role)
    $roleResult = @($targetRun.per_role_results | Where-Object { [string]$_.role -eq $role }) | Select-Object -First 1
    Assert-Equal "target run role $role status" $roleResult.status "completed"
    Assert-True "target run role $role done validation" ([bool]$roleResult.done_validation.implemented -and [bool]$roleResult.done_validation.tested -and [bool]$roleResult.done_validation.logged)
    Assert-True "target run role $role mcp status" (@("success", "controlled_error") -contains [string]$roleResult.mcp_status)
    Assert-Equal "target run role $role llm routing policy" $roleResult.llm_routing_policy_decision "allow_primary"
  }
  Assert-NotSecretBearing "runs payload" ($runs | ConvertTo-Json -Depth 40 -Compress)

  $homepage = Invoke-Text "$BaseUrl/"
  foreach ($marker in @("Runtime Runs", "phase2_runtime_run_status_visible", "LangGraph")) {
    Assert-Contains "homepage marker" $homepage $marker
  }
  Assert-NotSecretBearing "homepage" $homepage

  $summary = [ordered]@{
    status = "passed"
    passed = $true
    base_url = $BaseUrl
    active_release_id = [string]$config.active_release_id
    production_rollout_claimed = $false
    runtime_contract_version = [string]$contract.contract_version
    start_contract_version = [string]$startContract.contract_version
    runs_contract_version = [string]$runsContract.contract_version
    run_id = [string]$runtime.run_id
    thread_id = [string]$runtime.thread_id
    role_summary_count = [int]$targetRun.role_summary_count
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
    Write-Host "[phase2-runtime-dual-surface] verified"
    Write-Host "[phase2-runtime-dual-surface] base_url=$BaseUrl"
    Write-Host "[phase2-runtime-dual-surface] run_id=$($summary.run_id)"
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
      Write-Host "[phase2-runtime-dual-surface] failed"
      Write-Host "[phase2-runtime-dual-surface] error=$($_.Exception.Message)"
    }
    exit 0
  }
  throw
} finally {
  Pop-Location
}

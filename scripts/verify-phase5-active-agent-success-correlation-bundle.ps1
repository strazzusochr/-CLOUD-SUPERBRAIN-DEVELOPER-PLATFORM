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
    throw "Phase5 active agent success correlation bundle verification failed: $Label expected '$Expected' but got '$Actual'."
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase5 active agent success correlation bundle verification failed: $Label"
  }
}

function Assert-False($Label, $Value) {
  if ([bool]$Value) {
    throw "Phase5 active agent success correlation bundle verification failed: $Label expected false."
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Phase5 active agent success correlation bundle verification failed: $Label missing '$Expected'."
  }
}

function Assert-Sha($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[0-9a-f]{40}$') {
    throw "Phase5 active agent success correlation bundle verification failed: $Label is not a lowercase 40-character SHA."
  }
}

function Assert-ReleaseId($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^prod-candidate-[0-9]{4}-[0-9]{2}-[0-9]{2}-rc[0-9]+$') {
    throw "Phase5 active agent success correlation bundle verification failed: $Label is not a valid release candidate id."
  }
}

function Assert-NotSecretBearing($Label, $Value) {
  $text = ($Value | Out-String)
  $forbiddenPattern = "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Bearer [A-Za-z0-9_.-]{16,}|Cookie:|Set-Cookie:|BEGIN PRIVATE KEY|private key|raw_file_contents|redaction-proof-value"
  if ($text -match $forbiddenPattern) {
    throw "Phase5 active agent success correlation bundle verification failed: $Label contained a forbidden secret/raw-payload pattern."
  }
}

function Invoke-JsonApi([string]$Url, [string]$Method = "GET", [string]$Body = $null, [hashtable]$Headers = @{}) {
  $mergedHeaders = @{ Accept = "application/json" }
  foreach ($key in $Headers.Keys) {
    $mergedHeaders[$key] = $Headers[$key]
  }
  if (-not [string]::IsNullOrEmpty($Body)) {
    return Invoke-RestMethod -Method $Method -Uri $Url -Headers $mergedHeaders -ContentType "application/json" -Body $Body -TimeoutSec 90
  }
  return Invoke-RestMethod -Method $Method -Uri $Url -Headers $mergedHeaders -TimeoutSec 90
}

function Invoke-RepoScript([string]$Label, [string]$Path, [string[]]$Arguments) {
  $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments 2>&1
  $text = ($output | Out-String)
  if ($LASTEXITCODE -ne 0) {
    throw "$Label failed: $text"
  }
  Assert-NotSecretBearing $Label $text
  return ,$text
}

function Wait-Until([string]$Label, [scriptblock]$Probe, [int]$TimeoutSeconds = 120, [int]$SleepMilliseconds = 1000) {
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  $lastError = $null
  while ((Get-Date) -lt $deadline) {
    try {
      $result = & $Probe
      if ($null -ne $result) {
        return $result
      }
    } catch {
      $lastError = $_.Exception.Message
    }
    Start-Sleep -Milliseconds $SleepMilliseconds
  }
  if ($lastError) {
    throw "$Label timed out: $lastError"
  }
  throw "$Label timed out."
}

function Invoke-AgentSuccessCorrelationProbe([string]$BaseUrl) {
  $sessionId = [guid]::NewGuid().ToString()
  $traceId = "phase5-agent-success-" + [guid]::NewGuid().ToString("N")
  $requestId = "req-phase5-agent-success-" + [guid]::NewGuid().ToString("N")
  $headers = @{ "X-Request-Id" = $requestId; "X-Trace-Id" = $traceId }
  $body = @{
    project_id = "phase5-agent-success-correlation"
    session_id = $sessionId
    agent_type = "planner"
    task_type = "phase5_agent_success_correlation"
    task_description = "Phase5 agent success correlation deterministic worker proof."
    trace_id = $traceId
    priority = 8
  } | ConvertTo-Json -Depth 8 -Compress

  $created = Invoke-JsonApi "$BaseUrl/api/v1/internal/tasks" "POST" $body $headers
  Assert-True "created task visible" ($null -ne $created.task)
  Assert-Equal "created task session id" ([string]$created.task.session_id) $sessionId
  Assert-Equal "created task trace id" ([string]$created.task.trace_id) $traceId
  Assert-Equal "created task request id" ([string]$created.task.request_id) $requestId
  Assert-NotSecretBearing "created task" ($created | ConvertTo-Json -Depth 30 -Compress)
  $taskId = [string]$created.task.task_id

  $completed = Wait-Until "task completion" {
    $status = Invoke-JsonApi "$BaseUrl/api/v1/internal/tasks/$taskId"
    if ($status.task.status -eq "completed") {
      return $status
    }
    if ($status.task.status -in @("failed", "escalated", "abandoned_after_queue_drain")) {
      throw "task reached terminal non-success status: $($status.task.status)"
    }
    return $null
  }
  Assert-Equal "completed task request id" ([string]$completed.task.request_id) $requestId
  Assert-Equal "completed task trace id" ([string]$completed.task.trace_id) $traceId
  Assert-Equal "completed task status" ([string]$completed.task.status) "completed"
  Assert-Equal "completed result status" ([string]$completed.task.result_envelope.status) "completed"
  Assert-Equal "completed envelope request id" ([string]$completed.task.result_envelope.correlation.request_id) $requestId
  Assert-Equal "completed envelope session id" ([string]$completed.task.result_envelope.correlation.session_id) $sessionId
  Assert-False "completed envelope live provider" $completed.task.result_envelope.correlation.live_provider_calls
  Assert-NotSecretBearing "completed task" ($completed | ConvertTo-Json -Depth 30 -Compress)

  $recentTask = Wait-Until "recent task correlation" {
    $recent = Invoke-JsonApi "$BaseUrl/api/v1/tasks/recent?limit=100"
    $match = @($recent.tasks) | Where-Object { $_.task_id -eq $taskId } | Select-Object -First 1
    if ($match -and $match.request_id -eq $requestId) {
      return $match
    }
    return $null
  }
  Assert-Equal "recent task correlation ref" ([string]$recentTask.correlation_evidence_ref) "request_id_audit_correlation"
  Assert-Equal "recent task audit feed ref" ([string]$recentTask.audit_feed_evidence_ref) "request_id_audit_feed_visible"

  $auditMatch = Wait-Until "task audit correlation" {
    $audit = Invoke-JsonApi "$BaseUrl/api/v1/audit/recent?limit=100"
    $match = @($audit.events) | Where-Object { $_.event_type -eq "task_completed" -and $_.details.task_id -eq $taskId } | Select-Object -First 1
    if ($match -and $match.request_id -eq $requestId) {
      return $match
    }
    return $null
  }
  Assert-Equal "audit trace id" ([string]$auditMatch.trace_id) $traceId
  Assert-Equal "audit session id" ([string]$auditMatch.session_id) $sessionId
  Assert-Equal "audit request id" ([string]$auditMatch.request_id) $requestId
  Assert-Equal "audit correlation ref" ([string]$auditMatch.correlation_evidence_ref) "request_id_audit_correlation"
  Assert-False "audit live provider calls" $auditMatch.details.live_provider_calls
  Assert-False "audit live mcp writes" $auditMatch.details.live_mcp_writes
  Assert-NotSecretBearing "task audit match" ($auditMatch | ConvertTo-Json -Depth 30 -Compress)

  $activityMatch = Wait-Until "agent activity correlation" {
    $activity = Invoke-JsonApi "$BaseUrl/api/v1/agent-activity/recent?limit=100&event_type=task_completed&trace_id=$traceId"
    $match = @($activity.events) | Where-Object { $_.task_id -eq $taskId } | Select-Object -First 1
    if ($match -and $match.request_id -eq $requestId) {
      return $match
    }
    return $null
  }
  Assert-Equal "agent activity trace id" ([string]$activityMatch.trace_id) $traceId
  Assert-Equal "agent activity session id" ([string]$activityMatch.session_id) $sessionId
  Assert-Equal "agent activity correlation ref" ([string]$activityMatch.correlation_evidence_ref) "request_id_audit_correlation"
  Assert-Equal "agent activity feed ref" ([string]$activityMatch.audit_feed_evidence_ref) "request_id_audit_feed_visible"
  Assert-NotSecretBearing "agent activity match" ($activityMatch | ConvertTo-Json -Depth 30 -Compress)

  $timelineMatch = Wait-Until "gateway timeline agent task" {
    $timeline = Invoke-JsonApi "$BaseUrl/api/v1/security/gateway-correlation/timeline?limit=80"
    $match = @($timeline.timeline) | Where-Object { $_.event_type -eq "task_completed" -and $_.trace_id -eq $traceId } | Select-Object -First 1
    if ($match -and $match.request_id -eq $requestId) {
      return $match
    }
    return $null
  }
  Assert-Equal "gateway timeline leg" ([string]$timelineMatch.timeline_leg) "agent_task"
  Assert-Equal "gateway timeline request id" ([string]$timelineMatch.request_id) $requestId
  Assert-Equal "gateway timeline session id" ([string]$timelineMatch.session_id) $sessionId
  Assert-False "gateway timeline live provider" $timelineMatch.live_provider_calls
  Assert-False "gateway timeline live mcp" $timelineMatch.live_mcp_writes
  Assert-NotSecretBearing "gateway timeline match" ($timelineMatch | ConvertTo-Json -Depth 30 -Compress)

  $dispatchSessionId = [guid]::NewGuid().ToString()
  $dispatchTraceId = "phase5-agent-dispatch-success-" + [guid]::NewGuid().ToString("N")
  $dispatchRequestId = "req-phase5-agent-dispatch-success-" + [guid]::NewGuid().ToString("N")
  $dispatchBody = @{
    project_id = "phase5-agent-success-correlation"
    session_id = $dispatchSessionId
    objective = "Phase5 autonomous dispatch success correlation runtime proof."
    trace_id = $dispatchTraceId
    acceptance_criteria = @(
      "result_envelope",
      "done_validation",
      "audit_log",
      "request_id_visible",
      "trace_id_visible",
      "audit_feed_visible"
    )
  } | ConvertTo-Json -Depth 8 -Compress
  $dispatch = Invoke-JsonApi "$BaseUrl/api/v1/task/dispatch" "POST" $dispatchBody @{ "X-Request-Id" = $dispatchRequestId; "X-Trace-Id" = $dispatchTraceId }
  Assert-Equal "dispatch request id" ([string]$dispatch.request_id) $dispatchRequestId
  Assert-Equal "dispatch trace id" ([string]$dispatch.trace_id) $dispatchTraceId
  Assert-Equal "dispatch session id" ([string]$dispatch.session_id) $dispatchSessionId
  Assert-True "dispatch assignments visible" (@($dispatch.assignments).Count -ge 5)
  Assert-NotSecretBearing "dispatch" ($dispatch | ConvertTo-Json -Depth 30 -Compress)
  $dispatchId = [string]$dispatch.dispatch_id

  $teamStatus = Wait-Until "autonomous team dispatch completion" {
    $team = Invoke-JsonApi "$BaseUrl/api/v1/team/status?dispatch_id=$dispatchId"
    if ($team.status -eq "completed") {
      return $team
    }
    if ($team.status -in @("failed", "attention")) {
      throw "autonomous dispatch reached non-success status: $($team.status)"
    }
    return $null
  } 180 1000
  Assert-Equal "team status request id" ([string]$teamStatus.request_id) $dispatchRequestId
  Assert-Equal "team status trace id" ([string]$teamStatus.trace_id) $dispatchTraceId
  Assert-Equal "team status session id" ([string]$teamStatus.session_id) $dispatchSessionId
  Assert-True "team assignments completed" (@($teamStatus.members | Where-Object { $_.status -eq "completed" }).Count -ge 5)
  $firstAssignment = @($teamStatus.members) | Select-Object -First 1
  Assert-Equal "team assignment request id" ([string]$firstAssignment.request_id) $dispatchRequestId
  Assert-Equal "team assignment trace id" ([string]$firstAssignment.trace_id) $dispatchTraceId
  Assert-Equal "team assignment correlation ref" ([string]$firstAssignment.correlation_evidence_ref) "request_id_audit_correlation"
  Assert-NotSecretBearing "team status" ($teamStatus | ConvertTo-Json -Depth 30 -Compress)

  $dispatchAudit = Wait-Until "dispatch audit correlation" {
    $audit = Invoke-JsonApi "$BaseUrl/api/v1/audit/recent?limit=100"
    $match = @($audit.events) | Where-Object { $_.event_type -eq "autonomous_team_dispatch" -and $_.details.dispatch_id -eq $dispatchId } | Select-Object -First 1
    if ($match -and $match.request_id -eq $dispatchRequestId) {
      return $match
    }
    return $null
  }
  Assert-Equal "dispatch audit correlation ref" ([string]$dispatchAudit.correlation_evidence_ref) "request_id_audit_correlation"
  Assert-Equal "dispatch audit feed ref" ([string]$dispatchAudit.audit_feed_evidence_ref) "request_id_audit_feed_visible"
  Assert-NotSecretBearing "dispatch audit" ($dispatchAudit | ConvertTo-Json -Depth 30 -Compress)

  return [ordered]@{
    task_id = $taskId
    dispatch_id = $dispatchId
    request_id_visible = $true
    trace_id_visible = $true
    session_id_visible = $true
    direct_task_status = [string]$completed.task.status
    dispatch_status = [string]$teamStatus.status
    assignment_count = @($teamStatus.members).Count
    gateway_timeline_leg = [string]$timelineMatch.timeline_leg
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
    throw "Phase5 active agent success correlation bundle requires HTTPS unless -AllowLocalhost is set."
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
  Assert-Contains "candidate agent success correlation proof" $candidate "active_agent_success_correlation_bundle_proof: ``docs/release-artifacts/$ReleaseId-active-agent-success-correlation-bundle-20260515.md``"
  Assert-Contains "candidate non-claim" $candidate "This artifact does not claim a production rollout."
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
  Assert-Contains "candidate hosted selector" $candidate "hosted_selector_observed: ``IMAGE_TAG=$immutableSha``"

  $proofPath = "docs\release-artifacts\$ReleaseId-active-agent-success-correlation-bundle-20260515.md"
  Assert-True "active agent success correlation proof exists" (Test-Path -LiteralPath $proofPath)
  $proof = Get-Content -LiteralPath $proofPath -Raw
  foreach ($required in @(
    "Status: ``verified``",
    "release_id: ``$ReleaseId``",
    "source_commit_sha: ``$sourceSha``",
    "immutable_image_commit_sha: ``$immutableSha``",
    "base_url: ``https://188-34-191-140.sslip.io``",
    "production_rollout_claimed: ``false``",
    "agent_success_gate_count: ``8``",
    "changed_horizontal: ``Phase 2 88->89; Phase 5 84->85``",
    "changed_vertical: ``Agent Pool 75->76``",
    "This proof does not claim a production rollout.",
    "This proof does not claim release promotion.",
    "This proof does not claim live LLM provider calls.",
    "This proof does not claim live MCP writes.",
    "This proof does not claim local model downloads.",
    "This proof does not include secret values."
  )) {
    Assert-Contains "active agent success correlation proof artifact" $proof $required
  }
  Assert-NotSecretBearing "active agent success correlation proof artifact" $proof

  $progress = Invoke-JsonApi "$BaseUrl/api/v1/project/progress"
  Assert-Equal "progress overall" ([int]$progress.overall_percent) 82
  $phase2 = @($progress.horizontal.items | Where-Object { $_.id -eq "phase_2" }) | Select-Object -First 1
  Assert-Equal "progress phase2" ([int]$phase2.percent) 89
  Assert-Contains "phase2 status" $phase2.status "active_agent_success_correlation_runtime_verified"
  $phase5 = @($progress.horizontal.items | Where-Object { $_.id -eq "phase_5" }) | Select-Object -First 1
  Assert-Equal "progress phase5" ([int]$phase5.percent) 89
  Assert-Contains "phase5 status" $phase5.status "active_agent_success_correlation_bundle_verified"
  $agentPool = @($progress.vertical.items | Where-Object { $_.id -eq "layer_3" }) | Select-Object -First 1
  Assert-Equal "Agent Pool percent" ([int]$agentPool.percent) 76
  Assert-Contains "Agent Pool status" $agentPool.status "active_agent_success_correlation_runtime_verified"
  Assert-NotSecretBearing "progress payload" ($progress | ConvertTo-Json -Depth 20 -Compress)

  $probe = Invoke-AgentSuccessCorrelationProbe $BaseUrl
  Invoke-RepoScript "evidence-artifact-safety" "scripts\verify-evidence-artifact-safety.ps1" @() | Out-Null

  $summary = [ordered]@{
    status = "passed"
    passed = $true
    release_id = $ReleaseId
    base_url = $BaseUrl
    source_commit_sha = $sourceSha
    immutable_image_commit_sha = $immutableSha
    production_rollout_claimed = $false
    agent_success_gate_count = 8
    changed_horizontal = "Phase 2 88->89; Phase 5 84->85"
    changed_vertical = "Agent Pool 75->76"
    agent_success_correlation = $probe
    gates = @(
      "internal-task-success-correlation",
      "task-status-request-correlation",
      "recent-tasks-request-correlation",
      "audit-feed-task-correlation",
      "agent-activity-task-correlation",
      "gateway-timeline-agent-task-correlation",
      "autonomous-dispatch-success-correlation",
      "evidence-artifact-safety"
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
    Write-Host "[phase5-active-agent-success-correlation-bundle] verified"
    Write-Host "[phase5-active-agent-success-correlation-bundle] release_id=$ReleaseId"
    Write-Host "[phase5-active-agent-success-correlation-bundle] agent_success_gate_count=$($summary.agent_success_gate_count)"
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
      Write-Host "[phase5-active-agent-success-correlation-bundle] failed"
      Write-Host "[phase5-active-agent-success-correlation-bundle] error=$($_.Exception.Message)"
    }
    exit 0
  }
  throw
} finally {
  Pop-Location
}

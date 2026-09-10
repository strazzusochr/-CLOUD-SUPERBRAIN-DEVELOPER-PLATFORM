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
    throw "Phase5 active observability rebaseline bundle verification failed: $Label expected '$Expected' but got '$Actual'."
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase5 active observability rebaseline bundle verification failed: $Label"
  }
}

function Assert-False($Label, $Value) {
  if ([bool]$Value) {
    throw "Phase5 active observability rebaseline bundle verification failed: $Label expected false."
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Phase5 active observability rebaseline bundle verification failed: $Label missing '$Expected'."
  }
}

function Assert-NotSecretBearing($Label, $Value) {
  $text = ($Value | Out-String)
  $forbiddenPattern = "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Bearer [A-Za-z0-9_.-]{16,}|Cookie:|Set-Cookie:|BEGIN PRIVATE KEY|private key|raw_file_contents|redaction-proof-value"
  if ($text -match $forbiddenPattern) {
    throw "Phase5 active observability rebaseline bundle verification failed: $Label contained a forbidden secret/raw-payload pattern."
  }
}

function Assert-Sha($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[0-9a-f]{40}$') {
    throw "Phase5 active observability rebaseline bundle verification failed: $Label is not a lowercase 40-character SHA."
  }
}

function Assert-ReleaseId($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^prod-candidate-[0-9]{4}-[0-9]{2}-[0-9]{2}-rc[0-9]+$') {
    throw "Phase5 active observability rebaseline bundle verification failed: $Label is not a valid release candidate id."
  }
}

function Invoke-JsonApi([string]$Url) {
  return Invoke-RestMethod -Method Get -Uri $Url -Headers @{ Accept = "application/json" } -TimeoutSec 90
}

function Invoke-Text([string]$Url) {
  $response = Invoke-WebRequest -UseBasicParsing -Method Get -Uri $Url -TimeoutSec 90
  Assert-Equal "$Url HTTP status" ([int]$response.StatusCode) 200
  return [string]$response.Content
}

function Invoke-JsonPost([string]$Url, $Payload) {
  return Invoke-RestMethod -Method Post -Uri $Url -Headers @{ Accept = "application/json" } -ContentType "application/json" -Body ($Payload | ConvertTo-Json -Depth 10 -Compress) -TimeoutSec 90
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    throw "BaseUrl is required."
  }
  $BaseUrl = $BaseUrl.TrimEnd("/")
  if ((-not $AllowLocalhost) -and ($BaseUrl -notmatch "^https://")) {
    throw "Phase5 active observability rebaseline bundle requires HTTPS unless -AllowLocalhost is set."
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
  Assert-Contains "candidate observability proof link" $candidate "active_observability_rebaseline_bundle_proof: ``docs/release-artifacts/$ReleaseId-active-observability-rebaseline-bundle-20260515.md``"
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

  $proofPath = "docs\release-artifacts\$ReleaseId-active-observability-rebaseline-bundle-20260515.md"
  Assert-True "active observability rebaseline proof exists" (Test-Path -LiteralPath $proofPath)
  $proof = Get-Content -LiteralPath $proofPath -Raw
  foreach ($required in @(
    "Status: ``verified``",
    "release_id: ``$ReleaseId``",
    "source_commit_sha: ``$sourceSha``",
    "immutable_image_commit_sha: ``$immutableSha``",
    "production_rollout_claimed: ``false``",
    "phase5_percent: ``89``",
    "observability_layer_percent: ``99``",
    "changed_horizontal: ``Phase 5 88->89``",
    "changed_vertical: ``none; Observability remains 99 pending hosted Langfuse/Grafana owner endpoint proof``",
    "This proof does not claim a production rollout.",
    "This proof does not claim Observability 100%.",
    "This proof does not claim hosted Langfuse or Grafana ownership.",
    "This proof does not claim live LLM provider calls.",
    "This proof does not claim live MCP writes.",
    "This proof does not claim local model downloads.",
    "This proof does not include secret values."
  )) {
    Assert-Contains "active observability proof artifact" $proof $required
  }
  if ($AllowLocalhost) {
    Assert-Contains "active observability proof local control plane" $proof "local_control_plane_url: ``$BaseUrl``"
  } else {
    Assert-Contains "active observability proof base url" $proof "base_url: ``$BaseUrl``"
  }
  Assert-NotSecretBearing "active observability proof artifact" $proof

  $progress = Invoke-JsonApi "$BaseUrl/api/v1/project/progress"
  Assert-Equal "progress overall" ([int]$progress.overall_percent) 82
  $phase5 = @($progress.horizontal.items | Where-Object { $_.id -eq "phase_5" }) | Select-Object -First 1
  Assert-Equal "progress phase5" ([int]$phase5.percent) 89
  Assert-Contains "phase5 status" $phase5.status "active_observability_rebaseline_bundle_verified"
  $observability = @($progress.vertical.items | Where-Object { $_.id -eq "layer_7" }) | Select-Object -First 1
  Assert-Equal "observability percent remains blocked" ([int]$observability.percent) 99
  Assert-Contains "observability status" $observability.status "active_observability_rebaseline_runtime_verified"
  Assert-NotSecretBearing "progress payload" ($progress | ConvertTo-Json -Depth 30 -Compress)

  $integrity = Invoke-JsonApi "$BaseUrl/api/v1/project/progress/integrity"
  Assert-Equal "progress integrity version" $integrity.contract_version "project-progress-integrity-v1"
  Assert-Equal "progress integrity status" $integrity.status "verified"
  Assert-Equal "progress integrity manifest percent" ([int]$integrity.manifest_overall_percent) 82
  Assert-Equal "progress integrity computed percent" ([int]$integrity.computed_overall_percent) 82
  Assert-Equal "integrity phase5 percent" ([int]$integrity.horizontal_phase_percentages.phase_5) 89
  Assert-Equal "integrity observability percent" ([int]$integrity.vertical_layer_percentages.layer_7) 99
  Assert-True "progress integrity no mismatches" (@($integrity.mismatches).Count -eq 0)

  $completion = Invoke-JsonApi "$BaseUrl/api/v1/project/progress/completion"
  Assert-False "completion all-to-100 remains blocked" $completion.can_set_all_to_100
  Assert-Contains "completion hard blocker still local gaps" ($completion.hard_blockers -join ",") "local_progress_gaps_require_verified_evidence_for_each_phase_and_layer"
  Assert-Contains "completion observability external blocker" ($completion.hard_blockers -join ",") "hosted_langfuse_or_grafana_proof_requires_owner_configured_endpoint"
  $phase5Completion = @($completion.phase_completion | Where-Object { $_.id -eq "phase_5" }) | Select-Object -First 1
  Assert-Equal "phase5 completion percent" ([int]$phase5Completion.current_percent) 89
  $observabilityCompletion = @($completion.layer_completion | Where-Object { $_.id -eq "layer_7" }) | Select-Object -First 1
  Assert-Equal "observability completion percent" ([int]$observabilityCompletion.current_percent) 99
  Assert-Equal "observability completion status" $observabilityCompletion.status "blocked_external_gate"
  Assert-Contains "observability completion blocker" ($observabilityCompletion.blockers -join ",") "hosted_langfuse_or_grafana_proof_requires_owner_configured_endpoint"
  Assert-NotSecretBearing "completion payload" ($completion | ConvertTo-Json -Depth 30 -Compress)

  $health = Invoke-JsonApi "$BaseUrl/api/v1/health"
  Assert-Equal "health status" $health.status "healthy"

  $metrics = Invoke-Text "$BaseUrl/api/v1/metrics"
  Assert-Contains "metrics project progress" $metrics "superbrain_project_progress_percent 82"
  Assert-Contains "metrics audit counter" $metrics "superbrain_audit_events_total"
  Assert-Contains "metrics mcp counter" $metrics "superbrain_mcp_tool_events_total"
  Assert-Contains "metrics checkpoint tables" $metrics "superbrain_checkpoint_tables_total 4"
  Assert-NotSecretBearing "metrics" $metrics

  $activityContract = Invoke-JsonApi "$BaseUrl/api/v1/agent-activity/contract"
  Assert-Equal "agent activity contract" $activityContract.contract_version "agent-activity-trace-v1"
  $activityEvidenceRefs = @($activityContract.evidence_refs.PSObject.Properties.Value)
  Assert-Contains "agent activity evidence" ($activityEvidenceRefs -join ",") "agent_activity_contract_visible"
  Assert-Contains "agent activity trace link evidence" ($activityEvidenceRefs -join ",") "agent_activity_trace_link_template"
  Assert-Contains "agent activity trace access evidence" ($activityEvidenceRefs -join ",") "langfuse_trace_access_visible"
  $activity = Invoke-JsonApi "$BaseUrl/api/v1/agent-activity/recent?limit=20&severity=info"
  Assert-Equal "agent activity mode" $activity.mode "audit_log_backed_filtered_feed"
  Assert-Contains "agent activity feed evidence" $activity.evidence_ref "agent_activity_filtered_feed_visible"
  Assert-True "agent activity events visible" (@($activity.events).Count -ge 1)
  Assert-NotSecretBearing "agent activity payload" ($activity | ConvertTo-Json -Depth 40 -Compress)

  $audit = Invoke-JsonApi "$BaseUrl/api/v1/audit/recent?limit=40"
  Assert-True "audit events visible" (@($audit.events).Count -ge 1)
  Assert-NotSecretBearing "audit payload" ($audit | ConvertTo-Json -Depth 40 -Compress)

  $escalations = Invoke-JsonApi "$BaseUrl/api/v1/escalations/recent?limit=5"
  Assert-True "escalation events visible" (@($escalations.events).Count -ge 1)
  Assert-NotSecretBearing "escalations payload" ($escalations | ConvertTo-Json -Depth 40 -Compress)

  $langfuseContract = Invoke-JsonApi "$BaseUrl/api/v1/observability/langfuse/contract"
  Assert-Equal "langfuse contract" $langfuseContract.contract_version "langfuse-trace-access-v1"
  Assert-Equal "langfuse evidence" $langfuseContract.evidence_ref "langfuse_trace_access_visible"
  Assert-False "langfuse provider trace export" $langfuseContract.provider_trace_export
  Assert-True "langfuse auth proxy required" $langfuseContract.auth_proxy_required

  $traceId = "phase5-observability-rebaseline-" + ([guid]::NewGuid().ToString("N"))
  $requestId = "req-" + $traceId
  $seed = Invoke-JsonPost "$BaseUrl/llm/v1/chat/completions" @{
    model = "deepseek-ai/DeepSeek-V4-Flash:fastest"
    messages = @(@{ role = "user"; content = "phase5 observability rebaseline proof" })
    stream = $false
    metadata = @{
      trace_id = $traceId
      request_id = $requestId
      agent_type = "tester"
    }
  }
  Assert-False "llm seed live provider calls" $seed.live_provider_calls
  Assert-True "llm seed audit persisted" $seed.audit_persisted
  Assert-NotSecretBearing "llm seed payload" ($seed | ConvertTo-Json -Depth 20 -Compress)

  $trace = Invoke-JsonApi "$BaseUrl/api/v1/observability/langfuse/trace/$traceId`?limit=20"
  Assert-Equal "trace contract" $trace.contract_version "langfuse-trace-access-v1"
  Assert-Equal "trace id" $trace.trace_id $traceId
  Assert-Equal "trace evidence" $trace.evidence_ref "langfuse_trace_access_visible"
  Assert-False "trace provider export" $trace.provider_trace_export
  Assert-True "trace auth proxy required" $trace.auth_proxy_required
  Assert-True "trace events visible" (@($trace.events).Count -ge 1)
  Assert-NotSecretBearing "trace payload" ($trace | ConvertTo-Json -Depth 40 -Compress)

  $gatewayContract = Invoke-JsonApi "$BaseUrl/api/v1/security/gateway-correlation/contract"
  Assert-Equal "gateway correlation contract" $gatewayContract.contract_version "gateway-correlation-snapshot-v1"
  Assert-False "gateway contract live provider" $gatewayContract.live_provider_calls_claimed
  Assert-False "gateway contract live mcp" $gatewayContract.live_mcp_writes_claimed
  $gatewaySnapshot = Invoke-JsonApi "$BaseUrl/api/v1/security/gateway-correlation/snapshot?limit=40"
  Assert-Equal "gateway snapshot contract" $gatewaySnapshot.contract_version "gateway-correlation-snapshot-v1"
  Assert-Equal "gateway snapshot evidence" $gatewaySnapshot.evidence_ref "gateway_correlation_snapshot_visible"
  Assert-False "gateway snapshot live provider" $gatewaySnapshot.live_provider_calls_claimed
  Assert-False "gateway snapshot live mcp" $gatewaySnapshot.live_mcp_writes_claimed
  Assert-Equal "gateway snapshot forbidden hits" ([int]$gatewaySnapshot.forbidden_pattern_hits) 0
  $gatewayRisk = Invoke-JsonApi "$BaseUrl/api/v1/security/gateway-correlation/risk-rollup?limit=40"
  Assert-Equal "gateway risk contract" $gatewayRisk.contract_version "gateway-correlation-risk-rollup-v1"
  Assert-Equal "gateway risk evidence" $gatewayRisk.evidence_ref "gateway_correlation_risk_rollup_visible"
  $gatewayTimeline = Invoke-JsonApi "$BaseUrl/api/v1/security/gateway-correlation/timeline?limit=40"
  Assert-Equal "gateway timeline contract" $gatewayTimeline.contract_version "gateway-correlation-timeline-v1"
  Assert-Equal "gateway timeline evidence" $gatewayTimeline.evidence_ref "gateway_correlation_timeline_visible"
  Assert-NotSecretBearing "gateway snapshot payload" ($gatewaySnapshot | ConvertTo-Json -Depth 40 -Compress)
  Assert-NotSecretBearing "gateway risk payload" ($gatewayRisk | ConvertTo-Json -Depth 40 -Compress)
  Assert-NotSecretBearing "gateway timeline payload" ($gatewayTimeline | ConvertTo-Json -Depth 40 -Compress)

  $homepage = Invoke-Text "$BaseUrl/"
  foreach ($marker in @(
    "active_observability_rebaseline_bundle_visible",
    "Progress Integrity",
    "Agent Activity",
    "Langfuse Trace Access",
    "Gateway Correlation"
  )) {
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
    phase5_percent = 89
    observability_layer_percent = 99
    changed_horizontal = "Phase 5 88->89"
    changed_vertical = "none; Observability remains 99 pending hosted Langfuse/Grafana owner endpoint proof"
    policy = [ordered]@{
      mutates_production = $false
      deploys_production = $false
      claims_rollout = $false
      claims_observability_100 = $false
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
    Write-Host "[phase5-active-observability-rebaseline-bundle] verified"
    Write-Host "[phase5-active-observability-rebaseline-bundle] release_id=$ReleaseId"
    Write-Host "[phase5-active-observability-rebaseline-bundle] changed_horizontal=$($summary.changed_horizontal)"
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
      Write-Host "[phase5-active-observability-rebaseline-bundle] failed"
      Write-Host "[phase5-active-observability-rebaseline-bundle] error=$($_.Exception.Message)"
    }
    exit 0
  }
  throw
} finally {
  Pop-Location
}

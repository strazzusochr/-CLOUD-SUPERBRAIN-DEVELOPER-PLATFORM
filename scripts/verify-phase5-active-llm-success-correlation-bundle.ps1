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
    throw "Phase5 active LLM success correlation bundle verification failed: $Label expected '$Expected' but got '$Actual'."
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase5 active LLM success correlation bundle verification failed: $Label"
  }
}

function Assert-False($Label, $Value) {
  if ([bool]$Value) {
    throw "Phase5 active LLM success correlation bundle verification failed: $Label expected false."
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Phase5 active LLM success correlation bundle verification failed: $Label missing '$Expected'."
  }
}

function Assert-Sha($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[0-9a-f]{40}$') {
    throw "Phase5 active LLM success correlation bundle verification failed: $Label is not a lowercase 40-character SHA."
  }
}

function Assert-ReleaseId($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^prod-candidate-[0-9]{4}-[0-9]{2}-[0-9]{2}-rc[0-9]+$') {
    throw "Phase5 active LLM success correlation bundle verification failed: $Label is not a valid release candidate id."
  }
}

function Assert-NotSecretBearing($Label, $Value) {
  $text = ($Value | Out-String)
  $forbiddenPattern = "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Bearer [A-Za-z0-9_.-]{16,}|Cookie:|Set-Cookie:|BEGIN PRIVATE KEY|private key|raw_file_contents|redaction-proof-value"
  if ($text -match $forbiddenPattern) {
    throw "Phase5 active LLM success correlation bundle verification failed: $Label contained a forbidden secret/raw-payload pattern."
  }
}

function Invoke-JsonApi([string]$Url, [string]$Method = "GET", [string]$Body = $null) {
  $headers = @{ Accept = "application/json" }
  if (-not [string]::IsNullOrEmpty($Body)) {
    return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers -ContentType "application/json" -Body $Body -TimeoutSec 90
  }
  return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers -TimeoutSec 90
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

function Invoke-LlmSuccessCorrelationProbe([string]$BaseUrl) {
  $sessionId = [guid]::NewGuid().ToString()
  $traceId = "phase5-llm-success-" + [guid]::NewGuid().ToString("N")
  $requestId = "req-phase5-llm-success-" + [guid]::NewGuid().ToString("N")
  $model = "Qwen/Qwen3-Coder-Next:fastest"

  $body = @{
    model = $model
    input = "Phase5 LLM success correlation deterministic dry-run proof."
    max_output_tokens = 64
    metadata = @{
      agent_type = "tester"
      session_id = $sessionId
      trace_id = $traceId
      request_id = $requestId
      live_provider_calls_allowed = $false
    }
  } | ConvertTo-Json -Depth 8 -Compress

  $result = Invoke-JsonApi "$BaseUrl/llm/v1/responses" "POST" $body
  Assert-Equal "responses object" ([string]$result.object) "response"
  Assert-Equal "responses status" ([string]$result.status) "completed"
  Assert-Equal "responses mode" ([string]$result.gateway_mode) "deterministic_dry_run"
  Assert-Equal "responses provider" ([string]$result.provider_name) "deterministic-dry-run"
  Assert-False "responses live provider calls" $result.live_provider_calls
  Assert-False "responses model downloads" $result.model_downloads
  Assert-True "responses audit persisted" ([bool]$result.audit_persisted)
  Assert-Contains "responses output text" $result.output_text "LLM gateway deterministic dry-run response"
  Assert-NotSecretBearing "llm responses result" ($result | ConvertTo-Json -Depth 30 -Compress)

  Start-Sleep -Milliseconds 500

  $llmAudit = Invoke-JsonApi "$BaseUrl/api/v1/audit/llm?limit=100"
  $llmMatch = @($llmAudit.events) | Where-Object { $_.trace_id -eq $traceId } | Select-Object -First 1
  Assert-True "llm audit match visible" ($null -ne $llmMatch)
  Assert-Equal "llm audit request id" ([string]$llmMatch.request_id) $requestId
  Assert-Equal "llm audit trace id" ([string]$llmMatch.trace_id) $traceId
  Assert-Equal "llm audit session id" ([string]$llmMatch.session_id) $sessionId
  Assert-Equal "llm audit status" ([string]$llmMatch.status) "success"
  Assert-Equal "llm audit provider" ([string]$llmMatch.provider_name) "deterministic-dry-run"
  Assert-Equal "llm audit evidence" ([string]$llmMatch.evidence_ref) "llm_audit_feed_visible"
  Assert-Equal "llm audit feed ref" ([string]$llmMatch.audit_feed_evidence_ref) "llm_audit_feed_event_visible"
  Assert-Equal "llm audit correlation ref" ([string]$llmMatch.correlation_evidence_ref) "request_id_audit_correlation"
  Assert-Equal "llm audit detail request id" ([string]$llmMatch.details.request_id) $requestId
  Assert-Equal "llm audit detail session id" ([string]$llmMatch.details.session_id) $sessionId
  Assert-False "llm audit live provider calls" $llmMatch.live_provider_calls
  Assert-False "llm audit prompt stored" $llmMatch.prompt_body_stored
  Assert-NotSecretBearing "llm audit match" ($llmMatch | ConvertTo-Json -Depth 30 -Compress)

  $snapshot = Invoke-JsonApi "$BaseUrl/api/v1/audit/llm/snapshot?limit=100"
  Assert-Equal "llm snapshot mode" ([string]$snapshot.mode) "read_only_llm_audit_redaction_snapshot"
  Assert-Equal "llm snapshot evidence" ([string]$snapshot.snapshot_evidence_ref) "llm_audit_snapshot_visible"
  Assert-Equal "llm snapshot redaction evidence" ([string]$snapshot.redaction_evidence_ref) "llm_audit_redaction_enforced"
  Assert-True "llm snapshot read only" ([bool]$snapshot.read_only)
  Assert-False "llm snapshot live provider calls claimed" $snapshot.live_provider_calls_claimed
  Assert-False "llm snapshot prompt bodies" $snapshot.prompt_bodies_returned
  Assert-False "llm snapshot provider credentials" $snapshot.provider_credentials_returned
  Assert-Equal "llm snapshot forbidden hits" ([int]$snapshot.forbidden_pattern_hits) 0
  Assert-Equal "llm snapshot redaction clear" ([string]$snapshot.redaction_status) "clear"
  Assert-True "llm snapshot success count" ([int]$snapshot.status_counts.success -ge 1)
  Assert-Equal "llm snapshot live provider count" ([int]$snapshot.live_provider_call_count) 0
  Assert-NotSecretBearing "llm snapshot" ($snapshot | ConvertTo-Json -Depth 30 -Compress)

  $recentAudit = Invoke-JsonApi "$BaseUrl/api/v1/audit/recent?limit=100"
  $recentMatch = @($recentAudit.events) | Where-Object { $_.trace_id -eq $traceId } | Select-Object -First 1
  Assert-True "recent audit match visible" ($null -ne $recentMatch)
  Assert-Equal "recent audit request id" ([string]$recentMatch.request_id) $requestId
  Assert-Equal "recent audit trace id" ([string]$recentMatch.trace_id) $traceId
  Assert-Equal "recent audit session id" ([string]$recentMatch.session_id) $sessionId
  Assert-Equal "recent audit correlation ref" ([string]$recentMatch.correlation_evidence_ref) "request_id_audit_correlation"
  Assert-NotSecretBearing "recent audit match" ($recentMatch | ConvertTo-Json -Depth 30 -Compress)

  $activity = Invoke-JsonApi "$BaseUrl/api/v1/agent-activity/recent?limit=100&event_type=llm_gateway_request&trace_id=$traceId"
  $activityMatch = @($activity.events) | Where-Object { $_.trace_id -eq $traceId } | Select-Object -First 1
  Assert-True "agent activity match visible" ($null -ne $activityMatch)
  Assert-Equal "agent activity request id" ([string]$activityMatch.request_id) $requestId
  Assert-Equal "agent activity trace id" ([string]$activityMatch.trace_id) $traceId
  Assert-Equal "agent activity session id" ([string]$activityMatch.session_id) $sessionId
  Assert-Equal "agent activity correlation ref" ([string]$activityMatch.correlation_evidence_ref) "request_id_audit_correlation"
  Assert-Equal "agent activity feed ref" ([string]$activityMatch.audit_feed_evidence_ref) "request_id_audit_feed_visible"
  Assert-NotSecretBearing "agent activity match" ($activityMatch | ConvertTo-Json -Depth 30 -Compress)

  $timeline = Invoke-JsonApi "$BaseUrl/api/v1/security/gateway-correlation/timeline?limit=80"
  $timelineMatch = @($timeline.timeline) | Where-Object { $_.trace_id -eq $traceId -and $_.event_type -eq "llm_gateway_request" } | Select-Object -First 1
  Assert-True "gateway timeline llm leg visible" ($null -ne $timelineMatch)
  Assert-Equal "gateway timeline contract" ([string]$timeline.contract_version) "gateway-correlation-timeline-v1"
  Assert-Equal "gateway timeline leg" ([string]$timelineMatch.timeline_leg) "llm_audit"
  Assert-Equal "gateway timeline request id" ([string]$timelineMatch.request_id) $requestId
  Assert-Equal "gateway timeline session id" ([string]$timelineMatch.session_id) $sessionId
  Assert-Equal "gateway timeline status" ([string]$timelineMatch.status) "success"
  Assert-Equal "gateway timeline evidence" ([string]$timelineMatch.evidence_ref) "llm_audit_feed_visible"
  Assert-False "gateway timeline live provider" $timelineMatch.live_provider_calls
  Assert-False "gateway timeline live mcp" $timelineMatch.live_mcp_writes
  Assert-NotSecretBearing "gateway timeline match" ($timelineMatch | ConvertTo-Json -Depth 30 -Compress)

  return [ordered]@{
    response_id = [string]$result.id
    request_id_visible = [bool]($llmMatch.request_id -eq $requestId)
    trace_id_visible = [bool]($llmMatch.trace_id -eq $traceId)
    session_id_visible = [bool]($llmMatch.session_id -eq $sessionId)
    audit_evidence_ref = [string]$llmMatch.evidence_ref
    activity_evidence_ref = [string]$activityMatch.audit_feed_evidence_ref
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
    throw "Phase5 active LLM success correlation bundle requires HTTPS unless -AllowLocalhost is set."
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
  Assert-Contains "candidate LLM success correlation proof" $candidate "active_llm_success_correlation_bundle_proof: ``docs/release-artifacts/$ReleaseId-active-llm-success-correlation-bundle-20260515.md``"
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

  $proofPath = "docs\release-artifacts\$ReleaseId-active-llm-success-correlation-bundle-20260515.md"
  Assert-True "active LLM success correlation proof exists" (Test-Path -LiteralPath $proofPath)
  $proof = Get-Content -LiteralPath $proofPath -Raw
  foreach ($required in @(
    "Status: ``verified``",
    "release_id: ``$ReleaseId``",
    "source_commit_sha: ``$sourceSha``",
    "immutable_image_commit_sha: ``$immutableSha``",
    "base_url: ``https://188-34-191-140.sslip.io``",
    "production_rollout_claimed: ``false``",
    "llm_success_gate_count: ``7``",
    "changed_horizontal: ``Phase 5 83->84``",
    "changed_vertical: ``LLM Gateway 65->66``",
    "This proof does not claim a production rollout.",
    "This proof does not claim release promotion.",
    "This proof does not claim live LLM provider calls.",
    "This proof does not claim live MCP writes.",
    "This proof does not claim local model downloads.",
    "This proof does not include secret values."
  )) {
    Assert-Contains "active LLM success correlation proof artifact" $proof $required
  }
  Assert-NotSecretBearing "active LLM success correlation proof artifact" $proof

  $progress = Invoke-JsonApi "$BaseUrl/api/v1/project/progress"
  Assert-Equal "progress overall" ([int]$progress.overall_percent) 82
  $phase5 = @($progress.horizontal.items | Where-Object { $_.id -eq "phase_5" }) | Select-Object -First 1
  Assert-Equal "progress phase5" ([int]$phase5.percent) 87
  Assert-Contains "phase5 status" $phase5.status "active_llm_success_correlation_bundle_verified"
  $llmGateway = @($progress.vertical.items | Where-Object { $_.id -eq "layer_4" }) | Select-Object -First 1
  Assert-Equal "LLM Gateway percent" ([int]$llmGateway.percent) 67
  Assert-Contains "LLM Gateway status" $llmGateway.status "active_llm_success_correlation_runtime_verified"
  Assert-NotSecretBearing "progress payload" ($progress | ConvertTo-Json -Depth 20 -Compress)

  $probe = Invoke-LlmSuccessCorrelationProbe $BaseUrl
  Invoke-RepoScript "evidence-artifact-safety" "scripts\verify-evidence-artifact-safety.ps1" @() | Out-Null

  $summary = [ordered]@{
    status = "passed"
    passed = $true
    release_id = $ReleaseId
    base_url = $BaseUrl
    source_commit_sha = $sourceSha
    immutable_image_commit_sha = $immutableSha
    production_rollout_claimed = $false
    llm_success_gate_count = 7
    changed_horizontal = "Phase 5 83->84"
    changed_vertical = "LLM Gateway 65->66"
    llm_success_correlation = $probe
    gates = @(
      "llm-responses-success",
      "llm-audit-feed-correlation",
      "llm-audit-snapshot-redaction",
      "recent-audit-correlation",
      "agent-activity-correlation",
      "gateway-correlation-timeline-llm-success-leg",
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
    Write-Host "[phase5-active-llm-success-correlation-bundle] verified"
    Write-Host "[phase5-active-llm-success-correlation-bundle] release_id=$ReleaseId"
    Write-Host "[phase5-active-llm-success-correlation-bundle] llm_success_gate_count=$($summary.llm_success_gate_count)"
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
      Write-Host "[phase5-active-llm-success-correlation-bundle] failed"
      Write-Host "[phase5-active-llm-success-correlation-bundle] error=$($_.Exception.Message)"
    }
    exit 0
  }
  throw
} finally {
  Pop-Location
}

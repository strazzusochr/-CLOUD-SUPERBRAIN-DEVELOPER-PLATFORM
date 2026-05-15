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
    throw "Phase5 active LLM guard correlation bundle verification failed: $Label expected '$Expected' but got '$Actual'."
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase5 active LLM guard correlation bundle verification failed: $Label"
  }
}

function Assert-False($Label, $Value) {
  if ([bool]$Value) {
    throw "Phase5 active LLM guard correlation bundle verification failed: $Label expected false."
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Phase5 active LLM guard correlation bundle verification failed: $Label missing '$Expected'."
  }
}

function Assert-Sha($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[0-9a-f]{40}$') {
    throw "Phase5 active LLM guard correlation bundle verification failed: $Label is not a lowercase 40-character SHA."
  }
}

function Assert-ReleaseId($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^prod-candidate-[0-9]{4}-[0-9]{2}-[0-9]{2}-rc[0-9]+$') {
    throw "Phase5 active LLM guard correlation bundle verification failed: $Label is not a valid release candidate id."
  }
}

function Assert-NotSecretBearing($Label, $Value) {
  $text = ($Value | Out-String)
  $forbiddenPattern = "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Bearer [A-Za-z0-9_.-]{16,}|Cookie:|Set-Cookie:|BEGIN PRIVATE KEY|private key|raw_file_contents|redaction-proof-value"
  if ($text -match $forbiddenPattern) {
    throw "Phase5 active LLM guard correlation bundle verification failed: $Label contained a forbidden secret/raw-payload pattern."
  }
}

function Invoke-JsonApi([string]$Url, [string]$Method = "GET", [string]$Body = $null) {
  $headers = @{ Accept = "application/json" }
  if (-not [string]::IsNullOrEmpty($Body)) {
    return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers -ContentType "application/json" -Body $Body -TimeoutSec 90
  }
  return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers -TimeoutSec 90
}

function Read-ErrorResponseText($Response) {
  if ($null -eq $Response) {
    return ""
  }
  if ($Response.Content -and $Response.Content.ReadAsStringAsync) {
    return $Response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
  }
  $stream = $Response.GetResponseStream()
  if ($null -eq $stream) {
    return ""
  }
  $reader = [System.IO.StreamReader]::new($stream)
  try {
    return $reader.ReadToEnd()
  } finally {
    $reader.Dispose()
  }
}

function Invoke-JsonExpectHttpError([string]$Url, [string]$Body, [int]$ExpectedStatus) {
  try {
    $null = Invoke-JsonApi $Url "POST" $Body
    throw "Expected HTTP $ExpectedStatus but request succeeded."
  } catch {
    $response = $_.Exception.Response
    if ($null -eq $response) {
      throw
    }
    $status = [int]$response.StatusCode
    Assert-Equal "http status" $status $ExpectedStatus
    $text = [string]$_.ErrorDetails.Message
    if ([string]::IsNullOrWhiteSpace($text)) {
      $text = Read-ErrorResponseText $response
    }
    Assert-NotSecretBearing "error response" $text
    return [pscustomobject]@{
      status_code = $status
      body = ($text | ConvertFrom-Json)
      raw = $text
    }
  }
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

function New-GuardCaseBody($Case, [string]$SessionId, [string]$TraceId, [string]$RequestId) {
  $metadata = @{
    agent_type = "tester"
    session_id = $SessionId
    trace_id = $TraceId
    request_id = $RequestId
    live_provider_calls_allowed = $false
  }
  foreach ($key in @($Case.metadata.Keys)) {
    $metadata[$key] = $Case.metadata[$key]
  }
  return @{
    model = $Case.model
    input = "Phase5 LLM guard correlation deterministic blocked proof."
    max_output_tokens = $Case.max_output_tokens
    metadata = $metadata
  } | ConvertTo-Json -Depth 8 -Compress
}

function Assert-GuardAuditCorrelation([string]$BaseUrl, $Case, [string]$SessionId, [string]$TraceId, [string]$RequestId) {
  Start-Sleep -Milliseconds 500

  $llmAudit = Invoke-JsonApi "$BaseUrl/api/v1/audit/llm?limit=100"
  $llmMatch = @($llmAudit.events) | Where-Object { $_.trace_id -eq $TraceId } | Select-Object -First 1
  Assert-True "$($Case.name) llm audit match visible" ($null -ne $llmMatch)
  Assert-Equal "$($Case.name) llm audit request id" ([string]$llmMatch.request_id) $RequestId
  Assert-Equal "$($Case.name) llm audit session id" ([string]$llmMatch.session_id) $SessionId
  Assert-Equal "$($Case.name) llm audit status" ([string]$llmMatch.status) "blocked"
  Assert-Equal "$($Case.name) llm audit provider" ([string]$llmMatch.provider_name) "deterministic-guard"
  Assert-Equal "$($Case.name) llm audit guard evidence" ([string]$llmMatch.details.guard_evidence_ref) $Case.code
  Assert-Equal "$($Case.name) llm guard correlation evidence" ([string]$llmMatch.details.llm_guard_correlation_evidence_ref) "llm_guard_correlation_audit_visible"
  Assert-Equal "$($Case.name) llm audit http status" ([int]$llmMatch.details.http_status) $Case.expected_status
  Assert-False "$($Case.name) llm audit live provider calls" $llmMatch.live_provider_calls
  Assert-False "$($Case.name) llm audit prompt stored" $llmMatch.prompt_body_stored
  Assert-NotSecretBearing "$($Case.name) llm audit match" ($llmMatch | ConvertTo-Json -Depth 30 -Compress)

  $recentAudit = Invoke-JsonApi "$BaseUrl/api/v1/audit/recent?limit=100"
  $recentMatch = @($recentAudit.events) | Where-Object { $_.trace_id -eq $TraceId } | Select-Object -First 1
  Assert-True "$($Case.name) recent audit match visible" ($null -ne $recentMatch)
  Assert-Equal "$($Case.name) recent audit request id" ([string]$recentMatch.request_id) $RequestId
  Assert-Equal "$($Case.name) recent audit correlation ref" ([string]$recentMatch.correlation_evidence_ref) "request_id_audit_correlation"

  $activity = Invoke-JsonApi "$BaseUrl/api/v1/agent-activity/recent?limit=100&event_type=llm_gateway_request&trace_id=$TraceId"
  $activityMatch = @($activity.events) | Where-Object { $_.trace_id -eq $TraceId } | Select-Object -First 1
  Assert-True "$($Case.name) agent activity match visible" ($null -ne $activityMatch)
  Assert-Equal "$($Case.name) agent activity request id" ([string]$activityMatch.request_id) $RequestId
  Assert-Equal "$($Case.name) agent activity feed ref" ([string]$activityMatch.audit_feed_evidence_ref) "request_id_audit_feed_visible"

  $timeline = Invoke-JsonApi "$BaseUrl/api/v1/security/gateway-correlation/timeline?limit=80"
  $timelineMatch = @($timeline.timeline) | Where-Object { $_.trace_id -eq $TraceId -and $_.event_type -eq "llm_gateway_request" } | Select-Object -First 1
  Assert-True "$($Case.name) gateway timeline llm leg visible" ($null -ne $timelineMatch)
  Assert-Equal "$($Case.name) gateway timeline leg" ([string]$timelineMatch.timeline_leg) "llm_audit"
  Assert-Equal "$($Case.name) gateway timeline status" ([string]$timelineMatch.status) "blocked"
  Assert-Equal "$($Case.name) gateway timeline request id" ([string]$timelineMatch.request_id) $RequestId
  Assert-False "$($Case.name) gateway timeline live provider" $timelineMatch.live_provider_calls
  Assert-False "$($Case.name) gateway timeline live mcp" $timelineMatch.live_mcp_writes

  return [ordered]@{
    name = [string]$Case.name
    trace_id_visible = [bool]($llmMatch.trace_id -eq $TraceId)
    request_id_visible = [bool]($llmMatch.request_id -eq $RequestId)
    guard_evidence_ref = [string]$llmMatch.details.guard_evidence_ref
    audit_status = [string]$llmMatch.status
    timeline_status = [string]$timelineMatch.status
  }
}

function Invoke-LlmGuardCorrelationProbe([string]$BaseUrl) {
  $cases = @(
    [pscustomobject]@{
      name = "direct-provider-block"
      model = "https://provider.invalid/v1/models/direct"
      max_output_tokens = 64
      metadata = @{ direct_provider_url = "https://provider.invalid/v1" }
      expected_status = 403
      code = "llm_routing_policy_direct_provider_blocked"
    },
    [pscustomobject]@{
      name = "unknown-model-block"
      model = "unknown/phase5-guard-model"
      max_output_tokens = 64
      metadata = @{}
      expected_status = 422
      code = "llm_routing_policy_unknown_model_blocked"
    },
    [pscustomobject]@{
      name = "output-budget-block"
      model = "Qwen/Qwen3-Coder-Next:fastest"
      max_output_tokens = 999999
      metadata = @{ agent_type = "coder" }
      expected_status = 422
      code = "llm_output_token_budget_guard"
    }
  )

  $results = [System.Collections.Generic.List[object]]::new()
  foreach ($case in $cases) {
    $sessionId = [guid]::NewGuid().ToString()
    $traceId = "phase5-llm-guard-" + [guid]::NewGuid().ToString("N")
    $requestId = "req-phase5-llm-guard-" + [guid]::NewGuid().ToString("N")
    $body = New-GuardCaseBody $case $sessionId $traceId $requestId
    $errorResult = Invoke-JsonExpectHttpError "$BaseUrl/llm/v1/responses" $body $case.expected_status
    Assert-Equal "$($case.name) error code" ([string]$errorResult.body.detail.code) $case.code
    Assert-Equal "$($case.name) error evidence" ([string]$errorResult.body.detail.evidence_ref) $case.code
    Assert-False "$($case.name) live provider calls" $errorResult.body.detail.live_provider_calls
    Assert-False "$($case.name) model downloads" $errorResult.body.detail.model_downloads
    $results.Add((Assert-GuardAuditCorrelation $BaseUrl $case $sessionId $traceId $requestId)) | Out-Null
  }

  $snapshot = Invoke-JsonApi "$BaseUrl/api/v1/audit/llm/snapshot?limit=100"
  Assert-True "llm snapshot blocked count" ([int]$snapshot.status_counts.blocked -ge 3)
  Assert-Equal "llm snapshot live provider count" ([int]$snapshot.live_provider_call_count) 0
  Assert-Equal "llm snapshot forbidden hits" ([int]$snapshot.forbidden_pattern_hits) 0
  Assert-NotSecretBearing "llm snapshot" ($snapshot | ConvertTo-Json -Depth 30 -Compress)

  return @($results)
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    throw "BaseUrl is required."
  }
  $BaseUrl = $BaseUrl.TrimEnd("/")
  if ((-not $AllowLocalhost) -and ($BaseUrl -notmatch "^https://")) {
    throw "Phase5 active LLM guard correlation bundle requires HTTPS unless -AllowLocalhost is set."
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
  Assert-Contains "candidate LLM guard correlation proof" $candidate "active_llm_guard_correlation_bundle_proof: ``docs/release-artifacts/$ReleaseId-active-llm-guard-correlation-bundle-20260515.md``"
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

  $proofPath = "docs\release-artifacts\$ReleaseId-active-llm-guard-correlation-bundle-20260515.md"
  Assert-True "active LLM guard correlation proof exists" (Test-Path -LiteralPath $proofPath)
  $proof = Get-Content -LiteralPath $proofPath -Raw
  foreach ($required in @(
    "Status: ``verified``",
    "release_id: ``$ReleaseId``",
    "source_commit_sha: ``$sourceSha``",
    "immutable_image_commit_sha: ``$immutableSha``",
    "production_rollout_claimed: ``false``",
    "llm_guard_gate_count: ``8``",
    "changed_horizontal: ``Phase 5 86->87``",
    "changed_vertical: ``LLM Gateway 66->67``",
    "This proof does not claim a production rollout.",
    "This proof does not claim release promotion.",
    "This proof does not claim live LLM provider calls.",
    "This proof does not claim live MCP writes.",
    "This proof does not claim local model downloads.",
    "This proof does not include secret values."
  )) {
    Assert-Contains "active LLM guard correlation proof artifact" $proof $required
  }
  if ($AllowLocalhost) {
    Assert-Contains "active LLM guard correlation proof local base" $proof "local_control_plane_url: ``$BaseUrl``"
  } else {
    Assert-Contains "active LLM guard correlation proof base url" $proof "base_url: ``$BaseUrl``"
  }
  Assert-NotSecretBearing "active LLM guard correlation proof artifact" $proof

  $progress = Invoke-JsonApi "$BaseUrl/api/v1/project/progress"
  Assert-Equal "progress overall" ([int]$progress.overall_percent) 82
  $phase5 = @($progress.horizontal.items | Where-Object { $_.id -eq "phase_5" }) | Select-Object -First 1
  Assert-Equal "progress phase5" ([int]$phase5.percent) 88
  Assert-Contains "phase5 status" $phase5.status "active_llm_guard_correlation_bundle_verified"
  $llmGateway = @($progress.vertical.items | Where-Object { $_.id -eq "layer_4" }) | Select-Object -First 1
  Assert-Equal "LLM Gateway percent" ([int]$llmGateway.percent) 67
  Assert-Contains "LLM Gateway status" $llmGateway.status "active_llm_guard_correlation_runtime_verified"
  Assert-NotSecretBearing "progress payload" ($progress | ConvertTo-Json -Depth 20 -Compress)

  $probe = Invoke-LlmGuardCorrelationProbe $BaseUrl
  Invoke-RepoScript "evidence-artifact-safety" "scripts\verify-evidence-artifact-safety.ps1" @() | Out-Null

  $summary = [ordered]@{
    status = "passed"
    passed = $true
    release_id = $ReleaseId
    base_url = $BaseUrl
    source_commit_sha = $sourceSha
    immutable_image_commit_sha = $immutableSha
    production_rollout_claimed = $false
    llm_guard_gate_count = 8
    changed_horizontal = "Phase 5 86->87"
    changed_vertical = "LLM Gateway 66->67"
    llm_guard_correlation = $probe
    gates = @(
      "llm-direct-provider-block-audit-correlation",
      "llm-unknown-model-block-audit-correlation",
      "llm-output-budget-block-audit-correlation",
      "llm-audit-feed-blocked-guard-evidence",
      "recent-audit-correlation",
      "agent-activity-correlation",
      "gateway-correlation-timeline-llm-guard-leg",
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
    Write-Host "[phase5-active-llm-guard-correlation-bundle] verified"
    Write-Host "[phase5-active-llm-guard-correlation-bundle] release_id=$ReleaseId"
    Write-Host "[phase5-active-llm-guard-correlation-bundle] llm_guard_gate_count=$($summary.llm_guard_gate_count)"
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
      Write-Host "[phase5-active-llm-guard-correlation-bundle] failed"
      Write-Host "[phase5-active-llm-guard-correlation-bundle] error=$($_.Exception.Message)"
    }
    exit 0
  }
  throw
} finally {
  Pop-Location
}

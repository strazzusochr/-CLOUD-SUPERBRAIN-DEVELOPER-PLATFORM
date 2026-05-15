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
    throw "Phase5 active MCP guard correlation bundle verification failed: $Label expected '$Expected' but got '$Actual'."
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase5 active MCP guard correlation bundle verification failed: $Label"
  }
}

function Assert-False($Label, $Value) {
  if ([bool]$Value) {
    throw "Phase5 active MCP guard correlation bundle verification failed: $Label expected false."
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Phase5 active MCP guard correlation bundle verification failed: $Label missing '$Expected'."
  }
}

function Assert-Sha($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[0-9a-f]{40}$') {
    throw "Phase5 active MCP guard correlation bundle verification failed: $Label is not a lowercase 40-character SHA."
  }
}

function Assert-ReleaseId($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^prod-candidate-[0-9]{4}-[0-9]{2}-[0-9]{2}-rc[0-9]+$') {
    throw "Phase5 active MCP guard correlation bundle verification failed: $Label is not a valid release candidate id."
  }
}

function Assert-NotSecretBearing($Label, $Value) {
  $text = ($Value | Out-String)
  $forbiddenPattern = "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Bearer [A-Za-z0-9_.-]{16,}|Cookie:|Set-Cookie:|BEGIN PRIVATE KEY|private key|raw_file_contents|redaction-proof-value"
  if ($text -match $forbiddenPattern) {
    throw "Phase5 active MCP guard correlation bundle verification failed: $Label contained a forbidden secret/raw-payload pattern."
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

function New-McpGuardCaseBody($Case, [string]$SessionId, [string]$TraceId, [string]$RequestId, [string]$ToolRequestId) {
  return @{
    tool_request_id = $ToolRequestId
    run_id = "phase5-mcp-guard-correlation"
    session_id = $SessionId
    trace_id = $TraceId
    request_id = $RequestId
    agent_role = $Case.agent_role
    toolset = $Case.toolset
    capability = $Case.capability
    intent_summary = "prove active MCP guard-path audit correlation without live write"
    input_ref = "{}"
    allowed_scope = $Case.allowed_scope
    timeout_ms = 1000
    retry_budget = 0
    idempotency_key = $ToolRequestId
    audit_tags = @("phase5", "mcp-guard-correlation")
    redaction_required = $true
    expected_output_type = "tool_result"
  } | ConvertTo-Json -Depth 8 -Compress
}

function Assert-McpGuardAuditCorrelation([string]$BaseUrl, $Case, [string]$SessionId, [string]$TraceId, [string]$RequestId, [string]$ToolRequestId) {
  Start-Sleep -Milliseconds 500

  $mcpAudit = Invoke-JsonApi "$BaseUrl/api/v1/audit/mcp?limit=100"
  $mcpMatch = @($mcpAudit.events) | Where-Object { $_.details.tool_request_id -eq $ToolRequestId } | Select-Object -First 1
  Assert-True "$($Case.name) mcp audit match visible" ($null -ne $mcpMatch)
  Assert-Equal "$($Case.name) mcp audit request id" ([string]$mcpMatch.request_id) $RequestId
  Assert-Equal "$($Case.name) mcp audit trace id" ([string]$mcpMatch.trace_id) $TraceId
  Assert-Equal "$($Case.name) mcp audit session id" ([string]$mcpMatch.session_id) $SessionId
  Assert-Equal "$($Case.name) mcp audit status" ([string]$mcpMatch.details.status) "blocked"
  Assert-Equal "$($Case.name) mcp audit evidence" ([string]$mcpMatch.details.evidence_ref) $Case.evidence_ref
  Assert-Equal "$($Case.name) mcp guard evidence" ([string]$mcpMatch.details.guard_evidence_ref) $Case.evidence_ref
  Assert-Equal "$($Case.name) mcp guard correlation evidence" ([string]$mcpMatch.details.mcp_guard_correlation_evidence_ref) "mcp_guard_correlation_audit_visible"
  Assert-Equal "$($Case.name) mcp denied correlation" ([string]$mcpMatch.details.denied_tool_correlation_evidence_ref) "mcp_denied_tool_audit_correlation"
  Assert-Equal "$($Case.name) mcp audit correlation ref" ([string]$mcpMatch.correlation_evidence_ref) "request_id_audit_correlation"
  Assert-Equal "$($Case.name) mcp audit feed ref" ([string]$mcpMatch.audit_feed_evidence_ref) "request_id_audit_feed_visible"
  Assert-True "$($Case.name) mcp audit session bound" ([bool]$mcpMatch.details.session_bound)
  Assert-False "$($Case.name) input ref stored" $mcpMatch.details.input_ref_stored
  Assert-NotSecretBearing "$($Case.name) mcp audit match" ($mcpMatch | ConvertTo-Json -Depth 30 -Compress)

  $recentAudit = Invoke-JsonApi "$BaseUrl/api/v1/audit/recent?limit=100"
  $recentMatch = @($recentAudit.events) | Where-Object { $_.details.tool_request_id -eq $ToolRequestId } | Select-Object -First 1
  Assert-True "$($Case.name) recent audit match visible" ($null -ne $recentMatch)
  Assert-Equal "$($Case.name) recent audit request id" ([string]$recentMatch.request_id) $RequestId
  Assert-Equal "$($Case.name) recent audit trace id" ([string]$recentMatch.trace_id) $TraceId
  Assert-Equal "$($Case.name) recent audit correlation ref" ([string]$recentMatch.correlation_evidence_ref) "request_id_audit_correlation"

  $activity = Invoke-JsonApi "$BaseUrl/api/v1/agent-activity/recent?limit=100&event_type=mcp_tool_executed&trace_id=$TraceId"
  $activityMatch = @($activity.events) | Where-Object { $_.details.tool_request_id -eq $ToolRequestId } | Select-Object -First 1
  Assert-True "$($Case.name) agent activity match visible" ($null -ne $activityMatch)
  Assert-Equal "$($Case.name) agent activity request id" ([string]$activityMatch.request_id) $RequestId
  Assert-Equal "$($Case.name) agent activity feed ref" ([string]$activityMatch.audit_feed_evidence_ref) "request_id_audit_feed_visible"

  $timeline = Invoke-JsonApi "$BaseUrl/api/v1/security/gateway-correlation/timeline?limit=80"
  $timelineMatch = @($timeline.timeline) | Where-Object { $_.trace_id -eq $TraceId -and $_.event_type -eq "mcp_tool_executed" } | Select-Object -First 1
  Assert-True "$($Case.name) gateway timeline mcp leg visible" ($null -ne $timelineMatch)
  Assert-Equal "$($Case.name) gateway timeline leg" ([string]$timelineMatch.timeline_leg) "mcp_audit"
  Assert-Equal "$($Case.name) gateway timeline status" ([string]$timelineMatch.status) "blocked"
  Assert-Equal "$($Case.name) gateway timeline request id" ([string]$timelineMatch.request_id) $RequestId
  Assert-False "$($Case.name) gateway timeline live provider" $timelineMatch.live_provider_calls
  Assert-False "$($Case.name) gateway timeline live mcp" $timelineMatch.live_mcp_writes

  return [ordered]@{
    name = [string]$Case.name
    trace_id_visible = [bool]($mcpMatch.trace_id -eq $TraceId)
    request_id_visible = [bool]($mcpMatch.request_id -eq $RequestId)
    guard_evidence_ref = [string]$mcpMatch.details.guard_evidence_ref
    audit_status = [string]$mcpMatch.details.status
    timeline_status = [string]$timelineMatch.status
  }
}

function Invoke-McpGuardCorrelationProbe([string]$BaseUrl) {
  $cases = @(
    [pscustomobject]@{
      name = "unsupported-toolset-block"
      agent_role = "tester"
      toolset = "puppeteer"
      capability = "launch_browser"
      allowed_scope = "browser-proof-public-staging"
      error_class = "unsupported_toolset"
      evidence_ref = "mcp_unsupported_toolset_guard"
    },
    [pscustomobject]@{
      name = "scope-guard-block"
      agent_role = "devops"
      toolset = "postgresql"
      capability = "update_row"
      allowed_scope = "project-context-readonly"
      error_class = "postgres_write_violation"
      evidence_ref = "mcp_scope_guard"
    },
    [pscustomobject]@{
      name = "unsupported-capability-block"
      agent_role = "devops"
      toolset = "github"
      capability = "delete_branch"
      allowed_scope = "feature/mcp-guard-correlation"
      error_class = "unsupported_capability"
      evidence_ref = "mcp_unsupported_capability_guard"
    }
  )

  $results = [System.Collections.Generic.List[object]]::new()
  foreach ($case in $cases) {
    $sessionId = [guid]::NewGuid().ToString()
    $traceId = "phase5-mcp-guard-" + [guid]::NewGuid().ToString("N")
    $requestId = "req-phase5-mcp-guard-" + [guid]::NewGuid().ToString("N")
    $toolRequestId = "mcp-guard-" + [guid]::NewGuid().ToString("N")
    $body = New-McpGuardCaseBody $case $sessionId $traceId $requestId $toolRequestId
    $result = Invoke-JsonApi "$BaseUrl/mcp/api/v1/tools/execute" "POST" $body
    Assert-Equal "$($case.name) result status" ([string]$result.status) "blocked"
    Assert-Equal "$($case.name) result error" ([string]$result.error_class) $case.error_class
    Assert-Equal "$($case.name) result evidence" ([string]$result.evidence_ref) $case.evidence_ref
    Assert-True "$($case.name) audit persisted" ([bool]$result.audit_persisted)
    Assert-NotSecretBearing "$($case.name) result" ($result | ConvertTo-Json -Depth 30 -Compress)
    $results.Add((Assert-McpGuardAuditCorrelation $BaseUrl $case $sessionId $traceId $requestId $toolRequestId)) | Out-Null
  }

  $snapshot = Invoke-JsonApi "$BaseUrl/api/v1/audit/mcp/snapshot?limit=100"
  Assert-True "mcp snapshot blocked count" ([int]$snapshot.blocked_count -ge 3)
  Assert-True "mcp snapshot denied correlation count" ([int]$snapshot.denied_tool_correlation_count -ge 3)
  Assert-Equal "mcp snapshot live write count" ([int]$snapshot.live_mcp_write_count) 0
  Assert-Equal "mcp snapshot forbidden hits" ([int]$snapshot.forbidden_pattern_hits) 0
  Assert-NotSecretBearing "mcp snapshot" ($snapshot | ConvertTo-Json -Depth 30 -Compress)

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
    throw "Phase5 active MCP guard correlation bundle requires HTTPS unless -AllowLocalhost is set."
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
  Assert-Contains "candidate MCP guard correlation proof" $candidate "active_mcp_guard_correlation_bundle_proof: ``docs/release-artifacts/$ReleaseId-active-mcp-guard-correlation-bundle-20260515.md``"
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

  $proofPath = "docs\release-artifacts\$ReleaseId-active-mcp-guard-correlation-bundle-20260515.md"
  Assert-True "active MCP guard correlation proof exists" (Test-Path -LiteralPath $proofPath)
  $proof = Get-Content -LiteralPath $proofPath -Raw
  foreach ($required in @(
    "Status: ``verified``",
    "release_id: ``$ReleaseId``",
    "source_commit_sha: ``$sourceSha``",
    "immutable_image_commit_sha: ``$immutableSha``",
    "base_url: ``https://188-34-191-140.sslip.io``",
    "production_rollout_claimed: ``false``",
    "mcp_guard_gate_count: ``8``",
    "changed_horizontal: ``Phase 5 87->88``",
    "changed_vertical: ``MCP Gateway 67->68``",
    "This proof does not claim a production rollout.",
    "This proof does not claim release promotion.",
    "This proof does not claim live LLM provider calls.",
    "This proof does not claim live MCP writes.",
    "This proof does not claim local model downloads.",
    "This proof does not include secret values."
  )) {
    Assert-Contains "active MCP guard correlation proof artifact" $proof $required
  }
  Assert-NotSecretBearing "active MCP guard correlation proof artifact" $proof

  $progress = Invoke-JsonApi "$BaseUrl/api/v1/project/progress"
  Assert-Equal "progress overall" ([int]$progress.overall_percent) 82
  $phase5 = @($progress.horizontal.items | Where-Object { $_.id -eq "phase_5" }) | Select-Object -First 1
  Assert-Equal "progress phase5" ([int]$phase5.percent) 89
  Assert-Contains "phase5 status" $phase5.status "active_mcp_guard_correlation_bundle_verified"
  $mcpGateway = @($progress.vertical.items | Where-Object { $_.id -eq "layer_5" }) | Select-Object -First 1
  Assert-Equal "MCP Gateway percent" ([int]$mcpGateway.percent) 68
  Assert-Contains "MCP Gateway status" $mcpGateway.status "active_mcp_guard_correlation_runtime_verified"
  Assert-NotSecretBearing "progress payload" ($progress | ConvertTo-Json -Depth 20 -Compress)

  $probe = Invoke-McpGuardCorrelationProbe $BaseUrl
  Invoke-RepoScript "evidence-artifact-safety" "scripts\verify-evidence-artifact-safety.ps1" @() | Out-Null

  $summary = [ordered]@{
    status = "passed"
    passed = $true
    release_id = $ReleaseId
    base_url = $BaseUrl
    source_commit_sha = $sourceSha
    immutable_image_commit_sha = $immutableSha
    production_rollout_claimed = $false
    mcp_guard_gate_count = 8
    changed_horizontal = "Phase 5 87->88"
    changed_vertical = "MCP Gateway 67->68"
    mcp_guard_correlation = $probe
    gates = @(
      "mcp-unsupported-toolset-block",
      "mcp-scope-guard-block",
      "mcp-unsupported-capability-block",
      "mcp-audit-feed-correlation",
      "global-audit-correlation",
      "agent-activity-correlation",
      "gateway-correlation-timeline",
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
    Write-Host "[phase5-active-mcp-guard-correlation-bundle] verified"
    Write-Host "[phase5-active-mcp-guard-correlation-bundle] release_id=$ReleaseId"
    Write-Host "[phase5-active-mcp-guard-correlation-bundle] mcp_guard_gate_count=$($summary.mcp_guard_gate_count)"
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
      Write-Host "[phase5-active-mcp-guard-correlation-bundle] failed"
      Write-Host "[phase5-active-mcp-guard-correlation-bundle] error=$($_.Exception.Message)"
    }
    exit 0
  }
  throw
} finally {
  Pop-Location
}

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
    throw "Phase5 active MCP success correlation bundle verification failed: $Label expected '$Expected' but got '$Actual'."
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase5 active MCP success correlation bundle verification failed: $Label"
  }
}

function Assert-False($Label, $Value) {
  if ([bool]$Value) {
    throw "Phase5 active MCP success correlation bundle verification failed: $Label expected false."
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Phase5 active MCP success correlation bundle verification failed: $Label missing '$Expected'."
  }
}

function Assert-Sha($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[0-9a-f]{40}$') {
    throw "Phase5 active MCP success correlation bundle verification failed: $Label is not a lowercase 40-character SHA."
  }
}

function Assert-ReleaseId($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^prod-candidate-[0-9]{4}-[0-9]{2}-[0-9]{2}-rc[0-9]+$') {
    throw "Phase5 active MCP success correlation bundle verification failed: $Label is not a valid release candidate id."
  }
}

function Assert-NotSecretBearing($Label, $Value) {
  $text = ($Value | Out-String)
  $forbiddenPattern = "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Bearer [A-Za-z0-9_.-]{16,}|Cookie:|Set-Cookie:|BEGIN PRIVATE KEY|private key|raw_file_contents|redaction-proof-value"
  if ($text -match $forbiddenPattern) {
    throw "Phase5 active MCP success correlation bundle verification failed: $Label contained a forbidden secret/raw-payload pattern."
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

function Invoke-McpSuccessCorrelationProbe([string]$BaseUrl) {
  $sessionId = [guid]::NewGuid().ToString()
  $traceId = "phase5-mcp-success-" + [guid]::NewGuid().ToString("N")
  $requestId = "req-phase5-mcp-success-" + [guid]::NewGuid().ToString("N")
  $toolRequestId = "mcp-success-" + [guid]::NewGuid().ToString("N")
  $branchName = "feature/agent-mcp-success-" + $toolRequestId.Substring($toolRequestId.Length - 8)

  $inputRef = @{
    branch = $branchName
    title = "Phase5 MCP success correlation proof"
    base = "main"
    body = "Verifier proves MCP success-path request, trace, and session correlation without live GitHub mutation."
  } | ConvertTo-Json -Compress

  $body = @{
    tool_request_id = $toolRequestId
    run_id = "phase5-mcp-success-correlation"
    session_id = $sessionId
    trace_id = $traceId
    request_id = $requestId
    agent_role = "devops"
    toolset = "github"
    capability = "plan_branch_pr"
    intent_summary = "prove active MCP success-path audit correlation without live write"
    input_ref = $inputRef
    allowed_scope = $branchName
    timeout_ms = 1000
    retry_budget = 0
    idempotency_key = $toolRequestId
    audit_tags = @("phase5", "mcp-success-correlation")
    redaction_required = $true
    expected_output_type = "github_plan"
  } | ConvertTo-Json -Depth 8 -Compress

  $result = Invoke-JsonApi "$BaseUrl/mcp/api/v1/tools/execute" "POST" $body
  Assert-Equal "mcp result status" ([string]$result.status) "success"
  Assert-Equal "mcp result evidence" ([string]$result.evidence_ref) "github_branch_pr_plan"
  Assert-True "mcp result audit persisted" ([bool]$result.audit_persisted)
  Assert-Equal "github plan contract version" ([string]$result.github_plan.contract_version) "github-branch-pr-plan-v1"
  Assert-False "github plan live call" $result.github_plan.live_github_call
  Assert-Equal "github plan allowed branch" ([string]$result.github_plan.allowed_branch) $branchName
  Assert-Equal "github plan pr head" ([string]$result.github_plan.pull_request_payload.head) $branchName
  Assert-Equal "github plan pr base" ([string]$result.github_plan.pull_request_payload.base) "main"
  Assert-True "github plan draft pr" ([bool]$result.github_plan.pull_request_payload.draft)
  Assert-NotSecretBearing "mcp success result" ($result | ConvertTo-Json -Depth 30 -Compress)

  Start-Sleep -Milliseconds 500

  $mcpAudit = Invoke-JsonApi "$BaseUrl/api/v1/audit/mcp?limit=80"
  $mcpMatch = @($mcpAudit.events) | Where-Object { $_.details.tool_request_id -eq $toolRequestId } | Select-Object -First 1
  Assert-True "mcp audit match visible" ($null -ne $mcpMatch)
  Assert-Equal "mcp audit request id" ([string]$mcpMatch.request_id) $requestId
  Assert-Equal "mcp audit trace id" ([string]$mcpMatch.trace_id) $traceId
  Assert-Equal "mcp audit correlation ref" ([string]$mcpMatch.correlation_evidence_ref) "request_id_audit_correlation"
  Assert-Equal "mcp audit feed ref" ([string]$mcpMatch.audit_feed_evidence_ref) "request_id_audit_feed_visible"
  Assert-Equal "mcp audit status" ([string]$mcpMatch.details.status) "success"
  Assert-Equal "mcp audit evidence" ([string]$mcpMatch.details.evidence_ref) "github_branch_pr_plan"
  Assert-Equal "mcp audit redaction ref" ([string]$mcpMatch.details.redaction_evidence_ref) "mcp_audit_redaction_enforced"
  Assert-True "mcp audit session bound" ([bool]$mcpMatch.details.session_bound)
  Assert-False "mcp audit input ref stored" $mcpMatch.details.input_ref_stored
  Assert-True "mcp audit denied ref absent on success" ([string]::IsNullOrWhiteSpace([string]$mcpMatch.details.denied_tool_correlation_evidence_ref))
  Assert-NotSecretBearing "mcp audit match" ($mcpMatch | ConvertTo-Json -Depth 30 -Compress)

  $snapshot = Invoke-JsonApi "$BaseUrl/api/v1/audit/mcp/snapshot?limit=80"
  Assert-Equal "mcp snapshot mode" ([string]$snapshot.mode) "read_only_mcp_audit_redaction_snapshot"
  Assert-Equal "mcp snapshot evidence" ([string]$snapshot.snapshot_evidence_ref) "mcp_audit_snapshot_visible"
  Assert-Equal "mcp snapshot redaction evidence" ([string]$snapshot.redaction_evidence_ref) "mcp_audit_redaction_enforced"
  Assert-True "mcp snapshot read only" ([bool]$snapshot.read_only)
  Assert-False "mcp snapshot live writes" $snapshot.live_mcp_writes_claimed
  Assert-False "mcp snapshot input refs" $snapshot.input_refs_returned
  Assert-Equal "mcp snapshot forbidden hits" ([int]$snapshot.forbidden_pattern_hits) 0
  Assert-Equal "mcp snapshot redaction clear" ([string]$snapshot.redaction_status) "clear"
  Assert-True "mcp snapshot success count" ([int]$snapshot.status_counts.success -ge 1)
  Assert-True "mcp snapshot session bound count" ([int]$snapshot.session_bound_count -ge 1)
  Assert-NotSecretBearing "mcp snapshot" ($snapshot | ConvertTo-Json -Depth 30 -Compress)

  $recentAudit = Invoke-JsonApi "$BaseUrl/api/v1/audit/recent?limit=80"
  $recentMatch = @($recentAudit.events) | Where-Object { $_.details.tool_request_id -eq $toolRequestId } | Select-Object -First 1
  Assert-True "recent audit match visible" ($null -ne $recentMatch)
  Assert-Equal "recent audit request id" ([string]$recentMatch.request_id) $requestId
  Assert-Equal "recent audit trace id" ([string]$recentMatch.trace_id) $traceId
  Assert-Equal "recent audit correlation ref" ([string]$recentMatch.correlation_evidence_ref) "request_id_audit_correlation"
  Assert-NotSecretBearing "recent audit match" ($recentMatch | ConvertTo-Json -Depth 30 -Compress)

  $activity = Invoke-JsonApi "$BaseUrl/api/v1/agent-activity/recent?limit=80&event_type=mcp_tool_executed&trace_id=$traceId"
  $activityMatch = @($activity.events) | Where-Object { $_.details.tool_request_id -eq $toolRequestId } | Select-Object -First 1
  Assert-True "agent activity match visible" ($null -ne $activityMatch)
  Assert-Equal "agent activity request id" ([string]$activityMatch.request_id) $requestId
  Assert-Equal "agent activity trace id" ([string]$activityMatch.trace_id) $traceId
  Assert-Equal "agent activity correlation ref" ([string]$activityMatch.correlation_evidence_ref) "request_id_audit_correlation"
  Assert-Equal "agent activity feed ref" ([string]$activityMatch.audit_feed_evidence_ref) "request_id_audit_feed_visible"
  Assert-NotSecretBearing "agent activity match" ($activityMatch | ConvertTo-Json -Depth 30 -Compress)

  $timeline = Invoke-JsonApi "$BaseUrl/api/v1/security/gateway-correlation/timeline?limit=80"
  $timelineMatch = @($timeline.timeline) | Where-Object { $_.trace_id -eq $traceId -and $_.event_type -eq "mcp_tool_executed" } | Select-Object -First 1
  Assert-True "gateway timeline mcp success leg visible" ($null -ne $timelineMatch)
  Assert-Equal "gateway timeline contract" ([string]$timeline.contract_version) "gateway-correlation-timeline-v1"
  Assert-Equal "gateway timeline leg" ([string]$timelineMatch.timeline_leg) "mcp_audit"
  Assert-Equal "gateway timeline status" ([string]$timelineMatch.status) "success"
  Assert-Equal "gateway timeline evidence" ([string]$timelineMatch.evidence_ref) "github_branch_pr_plan"
  Assert-False "gateway timeline live provider" $timelineMatch.live_provider_calls
  Assert-False "gateway timeline live mcp" $timelineMatch.live_mcp_writes
  Assert-NotSecretBearing "gateway timeline match" ($timelineMatch | ConvertTo-Json -Depth 30 -Compress)

  return [ordered]@{
    tool_request_id = $toolRequestId
    session_bound = [bool]$mcpMatch.details.session_bound
    trace_id_visible = [bool]($mcpMatch.trace_id -eq $traceId)
    request_id_visible = [bool]($mcpMatch.request_id -eq $requestId)
    mcp_audit_evidence_ref = [string]$mcpMatch.details.evidence_ref
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
    throw "Phase5 active MCP success correlation bundle requires HTTPS unless -AllowLocalhost is set."
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
  Assert-Contains "candidate MCP success correlation proof" $candidate "active_mcp_success_correlation_bundle_proof: ``docs/release-artifacts/$ReleaseId-active-mcp-success-correlation-bundle-20260515.md``"
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

  $proofPath = "docs\release-artifacts\$ReleaseId-active-mcp-success-correlation-bundle-20260515.md"
  Assert-True "active MCP success correlation proof exists" (Test-Path -LiteralPath $proofPath)
  $proof = Get-Content -LiteralPath $proofPath -Raw
  foreach ($required in @(
    "Status: ``verified``",
    "release_id: ``$ReleaseId``",
    "source_commit_sha: ``$sourceSha``",
    "immutable_image_commit_sha: ``$immutableSha``",
    "base_url: ``https://188-34-191-140.sslip.io``",
    "production_rollout_claimed: ``false``",
    "mcp_success_gate_count: ``7``",
    "changed_horizontal: ``Phase 5 82->83``",
    "changed_vertical: ``MCP Gateway 66->67``",
    "This proof does not claim a production rollout.",
    "This proof does not claim release promotion.",
    "This proof does not claim live LLM provider calls.",
    "This proof does not claim live MCP writes.",
    "This proof does not claim local model downloads.",
    "This proof does not include secret values."
  )) {
    Assert-Contains "active MCP success correlation proof artifact" $proof $required
  }
  Assert-NotSecretBearing "active MCP success correlation proof artifact" $proof

  $progress = Invoke-JsonApi "$BaseUrl/api/v1/project/progress"
  Assert-Equal "progress overall" ([int]$progress.overall_percent) 81
  $phase5 = @($progress.horizontal.items | Where-Object { $_.id -eq "phase_5" }) | Select-Object -First 1
  Assert-Equal "progress phase5" ([int]$phase5.percent) 83
  Assert-Contains "phase5 status" $phase5.status "active_mcp_success_correlation_bundle_verified"
  $mcpGateway = @($progress.vertical.items | Where-Object { $_.id -eq "layer_5" }) | Select-Object -First 1
  Assert-Equal "MCP Gateway percent" ([int]$mcpGateway.percent) 67
  Assert-Contains "MCP Gateway status" $mcpGateway.status "active_mcp_success_correlation_runtime_verified"
  Assert-NotSecretBearing "progress payload" ($progress | ConvertTo-Json -Depth 20 -Compress)

  $probe = Invoke-McpSuccessCorrelationProbe $BaseUrl
  Invoke-RepoScript "evidence-artifact-safety" "scripts\verify-evidence-artifact-safety.ps1" @() | Out-Null

  $summary = [ordered]@{
    status = "passed"
    passed = $true
    release_id = $ReleaseId
    base_url = $BaseUrl
    source_commit_sha = $sourceSha
    immutable_image_commit_sha = $immutableSha
    production_rollout_claimed = $false
    mcp_success_gate_count = 7
    changed_horizontal = "Phase 5 82->83"
    changed_vertical = "MCP Gateway 66->67"
    mcp_success_correlation = $probe
    gates = @(
      "mcp-success-execute",
      "mcp-audit-feed-correlation",
      "recent-audit-correlation",
      "agent-activity-correlation",
      "mcp-audit-snapshot-redaction",
      "gateway-correlation-timeline-mcp-success-leg",
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
    Write-Host "[phase5-active-mcp-success-correlation-bundle] verified"
    Write-Host "[phase5-active-mcp-success-correlation-bundle] release_id=$ReleaseId"
    Write-Host "[phase5-active-mcp-success-correlation-bundle] mcp_success_gate_count=$($summary.mcp_success_gate_count)"
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
      Write-Host "[phase5-active-mcp-success-correlation-bundle] failed"
      Write-Host "[phase5-active-mcp-success-correlation-bundle] error=$($_.Exception.Message)"
    }
    exit 0
  }
  throw
} finally {
  Pop-Location
}

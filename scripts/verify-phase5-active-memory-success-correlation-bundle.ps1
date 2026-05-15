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
    throw "Phase5 active memory success correlation bundle verification failed: $Label expected '$Expected' but got '$Actual'."
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase5 active memory success correlation bundle verification failed: $Label"
  }
}

function Assert-False($Label, $Value) {
  if ([bool]$Value) {
    throw "Phase5 active memory success correlation bundle verification failed: $Label expected false."
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Phase5 active memory success correlation bundle verification failed: $Label missing '$Expected'."
  }
}

function Assert-Sha($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[0-9a-f]{40}$') {
    throw "Phase5 active memory success correlation bundle verification failed: $Label is not a lowercase 40-character SHA."
  }
}

function Assert-ReleaseId($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^prod-candidate-[0-9]{4}-[0-9]{2}-[0-9]{2}-rc[0-9]+$') {
    throw "Phase5 active memory success correlation bundle verification failed: $Label is not a valid release candidate id."
  }
}

function Assert-NotSecretBearing($Label, $Value) {
  $text = ($Value | Out-String)
  $forbiddenPattern = "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Bearer [A-Za-z0-9_.-]{16,}|Cookie:|Set-Cookie:|BEGIN PRIVATE KEY|private key|raw_file_contents|redaction-proof-value"
  if ($text -match $forbiddenPattern) {
    throw "Phase5 active memory success correlation bundle verification failed: $Label contained a forbidden secret/raw-payload pattern."
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

function Invoke-MemorySuccessCorrelationProbe([string]$BaseUrl) {
  $sessionId = [guid]::NewGuid().ToString()
  $projectId = "phase5-memory-success-" + [guid]::NewGuid().ToString("N")
  $traceId = "phase5-memory-success-" + [guid]::NewGuid().ToString("N")
  $requestId = "req-phase5-memory-success-" + [guid]::NewGuid().ToString("N")
  $needle = "phase5 memory success correlation " + [guid]::NewGuid().ToString("N")
  $headers = @{ "X-Request-Id" = $requestId; "X-Trace-Id" = $traceId }
  $body = @{
    project_id = $projectId
    session_id = $sessionId
    prompt = $needle
    stream = $false
    trace_id = $traceId
    request_id = $requestId
  } | ConvertTo-Json -Depth 8 -Compress

  $prompt = Invoke-JsonApi "$BaseUrl/api/v1/prompt" "POST" $body $headers
  Assert-Equal "prompt session id" ([string]$prompt.session_id) $sessionId
  Assert-Equal "prompt trace id" ([string]$prompt.trace_id) $traceId
  Assert-Equal "prompt request id" ([string]$prompt.request_id) $requestId
  Assert-Equal "prompt correlation ref" ([string]$prompt.correlation_evidence_ref) "request_id_audit_correlation"
  Assert-Equal "prompt memory success ref" ([string]$prompt.memory_success_evidence_ref) "memory_success_correlation_runtime_visible"
  Assert-True "prompt memory id" (-not [string]::IsNullOrWhiteSpace([string]$prompt.memory_id))
  Assert-NotSecretBearing "prompt response" ($prompt | ConvertTo-Json -Depth 30 -Compress)
  $memoryId = [string]$prompt.memory_id

  $encodedNeedle = [uri]::EscapeDataString($needle)
  $encodedProject = [uri]::EscapeDataString($projectId)
  $search = Invoke-JsonApi "$BaseUrl/api/v1/memory/search?q=$encodedNeedle&project_id=$encodedProject&limit=5&threshold=0.0"
  Assert-Equal "search evidence" ([string]$search.evidence_ref) "memory_search_contract_runtime_visible"
  $searchMatch = @($search.results) | Where-Object { $_.id -eq $memoryId } | Select-Object -First 1
  Assert-True "search result correlated memory visible" ($null -ne $searchMatch)
  Assert-Equal "search result session id" ([string]$searchMatch.session_id) $sessionId
  Assert-Equal "search result trace id" ([string]$searchMatch.trace_id) $traceId
  Assert-Equal "search result request id" ([string]$searchMatch.request_id) $requestId
  Assert-Equal "search result correlation ref" ([string]$searchMatch.correlation_evidence_ref) "request_id_audit_correlation"
  Assert-Equal "search result feed ref" ([string]$searchMatch.audit_feed_evidence_ref) "request_id_audit_feed_visible"
  Assert-Equal "search result memory ref" ([string]$searchMatch.memory_success_evidence_ref) "memory_success_correlation_runtime_visible"
  Assert-Contains "search result content" $searchMatch.content $needle
  Assert-NotSecretBearing "memory search result" ($search | ConvertTo-Json -Depth 30 -Compress)

  $audit = Invoke-JsonApi "$BaseUrl/api/v1/audit/recent?limit=100"
  $auditMatch = @($audit.events) | Where-Object { $_.event_type -eq "memory_entry_written" -and $_.details.memory_id -eq $memoryId } | Select-Object -First 1
  Assert-True "memory audit event visible" ($null -ne $auditMatch)
  Assert-Equal "audit request id" ([string]$auditMatch.request_id) $requestId
  Assert-Equal "audit trace id" ([string]$auditMatch.trace_id) $traceId
  Assert-Equal "audit session id" ([string]$auditMatch.session_id) $sessionId
  Assert-Equal "audit evidence" ([string]$auditMatch.details.evidence_ref) "memory_success_correlation_runtime_visible"
  Assert-Equal "audit correlation ref" ([string]$auditMatch.correlation_evidence_ref) "request_id_audit_correlation"
  Assert-False "audit live embedding provider" $auditMatch.details.live_embedding_provider_calls
  Assert-False "audit live provider" $auditMatch.details.live_provider_calls
  Assert-False "audit live mcp" $auditMatch.details.live_mcp_writes
  Assert-NotSecretBearing "memory audit event" ($auditMatch | ConvertTo-Json -Depth 30 -Compress)

  $activity = Invoke-JsonApi "$BaseUrl/api/v1/agent-activity/recent?limit=100&event_type=memory_entry_written&trace_id=$traceId"
  $activityMatch = @($activity.events) | Where-Object { $_.details.memory_id -eq $memoryId } | Select-Object -First 1
  Assert-True "memory activity event visible" ($null -ne $activityMatch)
  Assert-Equal "activity request id" ([string]$activityMatch.request_id) $requestId
  Assert-Equal "activity trace id" ([string]$activityMatch.trace_id) $traceId
  Assert-Equal "activity session id" ([string]$activityMatch.session_id) $sessionId
  Assert-Equal "activity correlation ref" ([string]$activityMatch.correlation_evidence_ref) "request_id_audit_correlation"
  Assert-Equal "activity feed ref" ([string]$activityMatch.audit_feed_evidence_ref) "request_id_audit_feed_visible"
  Assert-NotSecretBearing "memory activity event" ($activityMatch | ConvertTo-Json -Depth 30 -Compress)

  $history = Invoke-JsonApi "$BaseUrl/api/v1/sessions/$sessionId/history?audit_limit=50"
  $historyMatch = @($history.audit_events) | Where-Object { $_.event_type -eq "memory_entry_written" -and $_.details.memory_id -eq $memoryId } | Select-Object -First 1
  Assert-True "session history memory audit visible" ($null -ne $historyMatch)
  Assert-Equal "history request id" ([string]$historyMatch.request_id) $requestId
  Assert-Equal "history trace id" ([string]$historyMatch.trace_id) $traceId
  Assert-NotSecretBearing "session history memory event" ($historyMatch | ConvertTo-Json -Depth 30 -Compress)

  return [ordered]@{
    project_id = $projectId
    session_id = $sessionId
    memory_id = $memoryId
    trace_id_visible = $true
    request_id_visible = $true
    search_result_correlated = $true
    audit_feed_correlated = $true
    agent_activity_correlated = $true
    session_history_correlated = $true
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
    throw "Phase5 active memory success correlation bundle requires HTTPS unless -AllowLocalhost is set."
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
  Assert-Contains "candidate memory success correlation proof" $candidate "active_memory_success_correlation_bundle_proof: ``docs/release-artifacts/$ReleaseId-active-memory-success-correlation-bundle-20260515.md``"
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

  $proofPath = "docs\release-artifacts\$ReleaseId-active-memory-success-correlation-bundle-20260515.md"
  Assert-True "active memory success correlation proof exists" (Test-Path -LiteralPath $proofPath)
  $proof = Get-Content -LiteralPath $proofPath -Raw
  foreach ($required in @(
    "Status: ``verified``",
    "release_id: ``$ReleaseId``",
    "source_commit_sha: ``$sourceSha``",
    "immutable_image_commit_sha: ``$immutableSha``",
    "base_url: ``https://188-34-191-140.sslip.io``",
    "production_rollout_claimed: ``false``",
    "memory_success_gate_count: ``6``",
    "changed_horizontal: ``Phase 5 85->86``",
    "changed_vertical: ``Memory 73->74``",
    "This proof does not claim a production rollout.",
    "This proof does not claim release promotion.",
    "This proof does not claim live embedding provider calls.",
    "This proof does not claim live MCP writes.",
    "This proof does not claim local model downloads.",
    "This proof does not include secret values."
  )) {
    Assert-Contains "active memory success correlation proof artifact" $proof $required
  }
  Assert-NotSecretBearing "active memory success correlation proof artifact" $proof

  $progress = Invoke-JsonApi "$BaseUrl/api/v1/project/progress"
  Assert-Equal "progress overall" ([int]$progress.overall_percent) 82
  $phase5 = @($progress.horizontal.items | Where-Object { $_.id -eq "phase_5" }) | Select-Object -First 1
  Assert-Equal "progress phase5" ([int]$phase5.percent) 89
  Assert-Contains "phase5 status" $phase5.status "active_memory_success_correlation_bundle_verified"
  $memory = @($progress.vertical.items | Where-Object { $_.id -eq "layer_6" }) | Select-Object -First 1
  Assert-Equal "Memory percent" ([int]$memory.percent) 74
  Assert-Contains "Memory status" $memory.status "active_memory_success_correlation_runtime_verified"
  Assert-NotSecretBearing "progress payload" ($progress | ConvertTo-Json -Depth 20 -Compress)

  $probe = Invoke-MemorySuccessCorrelationProbe $BaseUrl
  Invoke-RepoScript "evidence-artifact-safety" "scripts\verify-evidence-artifact-safety.ps1" @() | Out-Null

  $summary = [ordered]@{
    status = "passed"
    passed = $true
    release_id = $ReleaseId
    base_url = $BaseUrl
    source_commit_sha = $sourceSha
    immutable_image_commit_sha = $immutableSha
    production_rollout_claimed = $false
    memory_success_gate_count = 6
    changed_horizontal = "Phase 5 85->86"
    changed_vertical = "Memory 73->74"
    memory_success_correlation = $probe
    gates = @(
      "prompt-memory-write-correlation",
      "memory-search-request-correlation",
      "audit-feed-memory-correlation",
      "agent-activity-memory-correlation",
      "session-history-memory-correlation",
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
      live_embedding_provider_calls_claimed = $false
      local_model_downloads = $false
    }
  }
  Assert-NotSecretBearing "summary" ($summary | ConvertTo-Json -Depth 8 -Compress)

  if ($JsonOnly) {
    $summary | ConvertTo-Json -Depth 8
  } else {
    Write-Host "[phase5-active-memory-success-correlation-bundle] verified"
    Write-Host "[phase5-active-memory-success-correlation-bundle] release_id=$ReleaseId"
    Write-Host "[phase5-active-memory-success-correlation-bundle] memory_success_gate_count=$($summary.memory_success_gate_count)"
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
      Write-Host "[phase5-active-memory-success-correlation-bundle] failed"
      Write-Host "[phase5-active-memory-success-correlation-bundle] error=$($_.Exception.Message)"
    }
    exit 0
  }
  throw
} finally {
  Pop-Location
}

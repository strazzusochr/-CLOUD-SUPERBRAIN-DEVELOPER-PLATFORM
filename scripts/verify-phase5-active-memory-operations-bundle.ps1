param(
  [string]$ReleaseId = "",
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [string]$KeyPath = "",
  [switch]$AllowLocalhost,
  [switch]$ReportOnly,
  [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"

function Assert-Equal($Label, $Actual, $Expected) {
  if ($Actual -ne $Expected) {
    throw "Phase5 active memory operations bundle verification failed: $Label expected '$Expected' but got '$Actual'."
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase5 active memory operations bundle verification failed: $Label"
  }
}

function Assert-False($Label, $Value) {
  if ([bool]$Value) {
    throw "Phase5 active memory operations bundle verification failed: $Label expected false."
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Phase5 active memory operations bundle verification failed: $Label missing '$Expected'."
  }
}

function Assert-Sha($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[0-9a-f]{40}$') {
    throw "Phase5 active memory operations bundle verification failed: $Label is not a lowercase 40-character SHA."
  }
}

function Assert-ReleaseId($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^prod-candidate-[0-9]{4}-[0-9]{2}-[0-9]{2}-rc[0-9]+$') {
    throw "Phase5 active memory operations bundle verification failed: $Label is not a valid release candidate id."
  }
}

function Assert-NotSecretBearing($Label, $Value) {
  $text = ($Value | Out-String)
  $forbiddenPattern = "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Bearer [A-Za-z0-9_.-]{16,}|Cookie:|Set-Cookie:|BEGIN PRIVATE KEY|private key|raw_file_contents|redaction-proof-value"
  if ($text -match $forbiddenPattern) {
    throw "Phase5 active memory operations bundle verification failed: $Label contained a forbidden secret/raw-payload pattern."
  }
}

function Invoke-JsonApi([string]$Url, [string]$Method = "GET", $Body = $null) {
  $args = @{
    Method = $Method
    Uri = $Url
    Headers = @{ Accept = "application/json" }
    TimeoutSec = 90
  }
  if ($null -ne $Body) {
    $args.ContentType = "application/json"
    $args.Body = ($Body | ConvertTo-Json -Depth 8 -Compress)
  }
  return Invoke-RestMethod @args
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

function Invoke-MemoryRuntimeProbe([string]$BaseUrl) {
  $projectId = "phase5-active-memory-" + [Guid]::NewGuid().ToString("N")
  $needle = "phase5 active memory operations " + [Guid]::NewGuid().ToString("N")

  $embedding = Invoke-JsonApi "$BaseUrl/api/v1/memory/embedding-consistency/contract"
  Assert-Equal "embedding contract version" ([string]$embedding.contract_version) "memory-embedding-consistency-v1"
  Assert-Equal "embedding status" ([string]$embedding.status) "verified"
  Assert-False "live embedding provider calls" $embedding.current_embedding.live_embedding_provider_calls
  Assert-Equal "search mode" ([string]$embedding.current_embedding.search_mode) "lexical_fallback"

  $searchContract = Invoke-JsonApi "$BaseUrl/api/v1/memory/search/contract"
  Assert-Equal "search contract version" ([string]$searchContract.contract_version) "memory-search-runtime-v1"
  Assert-Equal "search contract mode" ([string]$searchContract.search_mode) "lexical_fallback"

  $consolidation = Invoke-JsonApi "$BaseUrl/api/v1/memory/consolidation/contract"
  Assert-Equal "consolidation contract version" ([string]$consolidation.contract_version) "memory-consolidation-feed-v1"
  Assert-False "consolidation live embedding provider calls" ($consolidation.non_claims -notcontains "No live embedding provider call is made by this feed.")

  $purgeContract = Invoke-JsonApi "$BaseUrl/api/v1/memory/purge/contract"
  Assert-Equal "purge contract version" ([string]$purgeContract.contract_version) "memory-dsgvo-purge-v1"
  Assert-Equal "purge job endpoint" ([string]$purgeContract.job_status_endpoint) "GET /api/v1/memory/purge/jobs/{job_id}"
  Assert-Contains "purge non-claims" $purgeContract.non_claims "This local proof does not delete Langfuse traces because Langfuse is not yet live-wired in this stack."

  $prompt = Invoke-JsonApi "$BaseUrl/api/v1/prompt" "POST" @{
    project_id = $projectId
    prompt = $needle
    stream = $false
  }
  Assert-True "prompt session id returned" (-not [string]::IsNullOrWhiteSpace([string]$prompt.session_id))
  Assert-True "prompt memory id returned" (-not [string]::IsNullOrWhiteSpace([string]$prompt.memory_id))

  $encodedNeedle = [uri]::EscapeDataString($needle)
  $encodedProject = [uri]::EscapeDataString($projectId)
  $search = Invoke-JsonApi "$BaseUrl/api/v1/memory/search?q=$encodedNeedle&project_id=$encodedProject&limit=5&threshold=0.0"
  Assert-Equal "runtime search mode" ([string]$search.search_mode) "lexical_fallback"
  $first = @($search.results) | Select-Object -First 1
  Assert-True "runtime search result visible" ($null -ne $first)
  Assert-Contains "runtime search result content" $first.content $needle

  $reason = [uri]::EscapeDataString("phase5_active_memory_operations_bundle")
  $traceId = [uri]::EscapeDataString("phase5-active-memory-operations")
  $purge = Invoke-JsonApi "$BaseUrl/api/v1/memory?project_id=$encodedProject&confirm=true&reason=$reason&trace_id=$traceId" "DELETE"
  Assert-Equal "purge evidence" ([string]$purge.evidence_ref) "memory_purge_completed"
  Assert-True "purge job id returned" (-not [string]::IsNullOrWhiteSpace([string]$purge.job_id))

  $job = Invoke-JsonApi "$BaseUrl/api/v1/memory/purge/jobs/$($purge.job_id)"
  Assert-Equal "purge job evidence" ([string]$job.evidence_ref) "memory_purge_job_status_visible"
  Assert-Equal "purge job project" ([string]$job.project_id) $projectId

  $feed = Invoke-JsonApi "$BaseUrl/api/v1/memory/consolidation/recent?limit=10"
  Assert-True "consolidation feed events present" ($null -ne $feed.events)

  return [ordered]@{
    project_id = $projectId
    session_id = [string]$prompt.session_id
    memory_id = [string]$prompt.memory_id
    purge_job_id = [string]$purge.job_id
    search_mode = [string]$search.search_mode
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
    throw "Phase5 active memory operations bundle requires HTTPS unless -AllowLocalhost is set."
  }

  if (-not $AllowLocalhost -and [string]::IsNullOrWhiteSpace($KeyPath)) {
    $KeyPath = [Environment]::GetEnvironmentVariable("STAGING_SSH_KEY_PATH")
    if ([string]::IsNullOrWhiteSpace($KeyPath)) {
      $KeyPath = Join-Path $HOME ".ssh\oracle_key"
    }
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
  Assert-Contains "candidate memory operations proof" $candidate "active_memory_operations_bundle_proof: ``docs/release-artifacts/$ReleaseId-active-memory-operations-bundle-20260515.md``"
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

  $proofPath = "docs\release-artifacts\$ReleaseId-active-memory-operations-bundle-20260515.md"
  Assert-True "active memory operations proof exists" (Test-Path -LiteralPath $proofPath)
  $proof = Get-Content -LiteralPath $proofPath -Raw
  foreach ($required in @(
    "Status: ``verified``",
    "release_id: ``$ReleaseId``",
    "source_commit_sha: ``$sourceSha``",
    "immutable_image_commit_sha: ``$immutableSha``",
    "base_url: ``https://188-34-191-140.sslip.io``",
    "production_rollout_claimed: ``false``",
    "memory_gate_count: ``8``",
    "changed_horizontal: ``Phase 5 78->79``",
    "changed_vertical: ``Memory 72->73``",
    "This proof does not claim a production rollout.",
    "This proof does not claim release promotion.",
    "This proof does not claim live embedding provider calls.",
    "This proof does not claim local model downloads.",
    "This proof does not include secret values."
  )) {
    Assert-Contains "active memory operations proof artifact" $proof $required
  }
  Assert-NotSecretBearing "active memory operations proof artifact" $proof

  $progress = Invoke-JsonApi "$BaseUrl/api/v1/project/progress"
  Assert-Equal "progress overall" ([int]$progress.overall_percent) 81
  $phase5 = @($progress.horizontal.items | Where-Object { $_.id -eq "phase_5" }) | Select-Object -First 1
  Assert-Equal "progress phase5" ([int]$phase5.percent) 86
  Assert-Contains "phase5 status" $phase5.status "active_memory_operations_bundle_verified"
  $memory = @($progress.vertical.items | Where-Object { $_.id -eq "layer_6" }) | Select-Object -First 1
  Assert-Equal "memory percent" ([int]$memory.percent) 74
  Assert-Contains "memory status" $memory.status "active_memory_operations_runtime_verified"
  Assert-NotSecretBearing "progress payload" ($progress | ConvertTo-Json -Depth 20 -Compress)

  $gates = [System.Collections.Generic.List[string]]::new()
  $probe = Invoke-MemoryRuntimeProbe $BaseUrl
  $gates.Add("memory-runtime-probe") | Out-Null
  $gates.Add("memory-purge-job-status") | Out-Null
  $gates.Add("memory-search-runtime") | Out-Null
  $gates.Add("memory-contract-surface") | Out-Null

  if ($AllowLocalhost) {
    Invoke-RepoScript "browser-contract" "scripts\verify-browser-contract.ps1" @("-BaseUrl", $BaseUrl, "-AllowLocalhost") | Out-Null
    $gates.Add("browser-contract") | Out-Null
  } else {
    Invoke-RepoScript "phase4-session-memory-parity-hosted" "scripts\verify-phase4-session-memory-parity-hosted.ps1" @("-BaseUrl", $BaseUrl, "-KeyPath", $KeyPath) | Out-Null
    $gates.Add("phase4-session-memory-parity-hosted") | Out-Null
    Invoke-RepoScript "phase4-memory-embedding-consistency-hosted" "scripts\verify-phase4-memory-embedding-consistency-hosted.ps1" @("-BaseUrl", $BaseUrl) | Out-Null
    $gates.Add("phase4-memory-embedding-consistency-hosted") | Out-Null
    Invoke-RepoScript "hosted-staging-smoke" "scripts\verify-hosted-staging-smoke.ps1" @("-BaseUrl", $BaseUrl) | Out-Null
    $gates.Add("hosted-staging-smoke") | Out-Null
  }

  Invoke-RepoScript "evidence-artifact-safety" "scripts\verify-evidence-artifact-safety.ps1" @() | Out-Null
  $gates.Add("evidence-artifact-safety") | Out-Null
  if ($AllowLocalhost) {
    Assert-Equal "local memory gate count" $gates.Count 6
  } else {
    Assert-Equal "hosted memory gate count" $gates.Count 8
  }

  $summary = [ordered]@{
    status = "passed"
    passed = $true
    release_id = $ReleaseId
    base_url = $BaseUrl
    source_commit_sha = $sourceSha
    immutable_image_commit_sha = $immutableSha
    production_rollout_claimed = $false
    memory_gate_count = $gates.Count
    changed_horizontal = "Phase 5 78->79"
    changed_vertical = "Memory 72->73"
    gates = @($gates)
    runtime_probe = $probe
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
    Write-Host "[phase5-active-memory-operations-bundle] verified"
    Write-Host "[phase5-active-memory-operations-bundle] release_id=$ReleaseId"
    Write-Host "[phase5-active-memory-operations-bundle] memory_gate_count=$($summary.memory_gate_count)"
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
      Write-Host "[phase5-active-memory-operations-bundle] failed"
      Write-Host "[phase5-active-memory-operations-bundle] error=$($_.Exception.Message)"
    }
    exit 0
  }
  throw
} finally {
  Pop-Location
}

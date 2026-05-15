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
    throw "Phase5 active LLM operations bundle verification failed: $Label expected '$Expected' but got '$Actual'."
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase5 active LLM operations bundle verification failed: $Label"
  }
}

function Assert-False($Label, $Value) {
  if ([bool]$Value) {
    throw "Phase5 active LLM operations bundle verification failed: $Label expected false."
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Phase5 active LLM operations bundle verification failed: $Label missing '$Expected'."
  }
}

function Assert-Sha($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[0-9a-f]{40}$') {
    throw "Phase5 active LLM operations bundle verification failed: $Label is not a lowercase 40-character SHA."
  }
}

function Assert-ReleaseId($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^prod-candidate-[0-9]{4}-[0-9]{2}-[0-9]{2}-rc[0-9]+$') {
    throw "Phase5 active LLM operations bundle verification failed: $Label is not a valid release candidate id."
  }
}

function Assert-NotSecretBearing($Label, $Value) {
  $text = ($Value | Out-String)
  $forbiddenPattern = "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Bearer [A-Za-z0-9_.-]{16,}|Cookie:|Set-Cookie:|BEGIN PRIVATE KEY|private key|raw_file_contents|redaction-proof-value"
  if ($text -match $forbiddenPattern) {
    throw "Phase5 active LLM operations bundle verification failed: $Label contained a forbidden secret/raw-payload pattern."
  }
}

function Invoke-JsonApi([string]$Url) {
  return Invoke-RestMethod -Method Get -Uri $Url -Headers @{ Accept = "application/json" } -TimeoutSec 90
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

function Get-BaseUrlArgs([string]$BaseUrl, [bool]$AllowLocalhost) {
  $arguments = @("-BaseUrl", $BaseUrl)
  if ($AllowLocalhost) {
    $arguments += "-AllowLocalhost"
  }
  return ,$arguments
}

function Invoke-LlmRuntimeProbe([string]$BaseUrl) {
  $health = Invoke-JsonApi "$BaseUrl/llm/api/v1/health"
  Assert-Equal "llm health status" ([string]$health.status) "healthy"
  Assert-Equal "llm health service" ([string]$health.service) "llm-gateway"
  Assert-Equal "llm health mode" ([string]$health.mode) "deterministic_dry_run"
  Assert-False "llm health live provider calls" $health.live_provider_calls
  Assert-False "llm health model downloads" $health.model_downloads
  Assert-True "llm health open source first" ([bool]$health.open_source_first)
  Assert-True "llm health OpenAI-compatible wire" ([bool]$health.openai_compatible)
  Assert-Equal "llm health catalog version" ([string]$health.model_catalog_contract_version) "llm-model-catalog-v1"

  $catalog = Invoke-JsonApi "$BaseUrl/llm/api/v1/models/catalog"
  Assert-Equal "catalog contract version" ([string]$catalog.contract_version) "llm-model-catalog-v1"
  Assert-Equal "catalog status" ([string]$catalog.status) "verified"
  Assert-False "catalog live provider calls" $catalog.live_provider_calls
  Assert-False "catalog model downloads" $catalog.model_downloads
  Assert-False "catalog local downloads" $catalog.local_model_downloads_allowed
  Assert-True "catalog api inference only" ([bool]$catalog.api_inference_only)
  Assert-True "catalog open source first" ([bool]$catalog.open_source_first)
  Assert-True "catalog route count" ([int]$catalog.route_count -ge 5)
  Assert-True "catalog configured model count" ([int]$catalog.configured_model_count -ge 10)

  $runtimeGuard = Invoke-JsonApi "$BaseUrl/llm/api/v1/runtime/guard-parity"
  Assert-Equal "runtime guard contract" ([string]$runtimeGuard.contract_version) "llm-runtime-guard-parity-v1"
  Assert-Equal "runtime guard status" ([string]$runtimeGuard.status) "verified"
  Assert-Equal "runtime guard evidence" ([string]$runtimeGuard.evidence_ref) "llm_runtime_guard_parity_visible"
  Assert-False "runtime guard live provider calls" $runtimeGuard.live_provider_calls
  Assert-False "runtime guard model downloads" $runtimeGuard.model_downloads

  $streaming = Invoke-JsonApi "$BaseUrl/llm/api/v1/streaming/contract"
  Assert-Equal "streaming mode" ([string]$streaming.mode) "deterministic_dry_run"
  Assert-Equal "streaming protocol" ([string]$streaming.protocol) "openai_compatible_sse"
  Assert-False "streaming live provider calls" $streaming.live_provider_calls

  $agentStreaming = Invoke-JsonApi "$BaseUrl/api/v1/agents/llm-streaming-contract"
  Assert-Equal "agent streaming contract version" ([string]$agentStreaming.contract_version) "agent-llm-streaming-contract-v1"
  Assert-Equal "agent streaming evidence" ([string]$agentStreaming.evidence_ref) "agent_llm_streaming_contract_visible"
  Assert-Contains "agent streaming non-claim" $agentStreaming.non_claims "No live provider stream is opened by this contract."

  $llmAudit = Invoke-JsonApi "$BaseUrl/api/v1/audit/llm/contract"
  Assert-Equal "llm audit contract version" ([string]$llmAudit.contract_version) "llm-audit-feed-v1"
  Assert-Equal "llm audit export version" ([string]$llmAudit.export_contract_version) "llm-audit-export-v1"
  Assert-False "llm audit live provider calls claimed" $llmAudit.live_provider_calls_claimed
  Assert-False "llm audit prompt bodies returned" $llmAudit.prompt_bodies_returned
  Assert-False "llm audit provider credentials returned" $llmAudit.provider_credentials_returned

  Assert-NotSecretBearing "llm runtime probe" (@($health, $catalog, $runtimeGuard, $streaming, $agentStreaming, $llmAudit) | ConvertTo-Json -Depth 30 -Compress)
  return [ordered]@{
    provider = [string]$health.provider
    route_count = [int]$catalog.route_count
    configured_model_count = [int]$catalog.configured_model_count
    runtime_guard = [string]$runtimeGuard.evidence_ref
    audit_contract = [string]$llmAudit.contract_version
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
    throw "Phase5 active LLM operations bundle requires HTTPS unless -AllowLocalhost is set."
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
  Assert-Contains "candidate LLM operations proof" $candidate "active_llm_operations_bundle_proof: ``docs/release-artifacts/$ReleaseId-active-llm-operations-bundle-20260515.md``"
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

  $proofPath = "docs\release-artifacts\$ReleaseId-active-llm-operations-bundle-20260515.md"
  Assert-True "active LLM operations proof exists" (Test-Path -LiteralPath $proofPath)
  $proof = Get-Content -LiteralPath $proofPath -Raw
  foreach ($required in @(
    "Status: ``verified``",
    "release_id: ``$ReleaseId``",
    "source_commit_sha: ``$sourceSha``",
    "immutable_image_commit_sha: ``$immutableSha``",
    "base_url: ``https://188-34-191-140.sslip.io``",
    "production_rollout_claimed: ``false``",
    "llm_gate_count: ``8``",
    "changed_horizontal: ``Phase 5 80->81``",
    "changed_vertical: ``LLM Gateway 64->65``",
    "This proof does not claim a production rollout.",
    "This proof does not claim release promotion.",
    "This proof does not claim live LLM provider calls.",
    "This proof does not claim live MCP writes.",
    "This proof does not claim local model downloads.",
    "This proof does not include secret values."
  )) {
    Assert-Contains "active LLM operations proof artifact" $proof $required
  }
  Assert-NotSecretBearing "active LLM operations proof artifact" $proof

  $progress = Invoke-JsonApi "$BaseUrl/api/v1/project/progress"
  Assert-Equal "progress overall" ([int]$progress.overall_percent) 82
  $phase5 = @($progress.horizontal.items | Where-Object { $_.id -eq "phase_5" }) | Select-Object -First 1
  Assert-Equal "progress phase5" ([int]$phase5.percent) 89
  Assert-Contains "phase5 status" $phase5.status "active_llm_operations_bundle_verified"
  $llmGateway = @($progress.vertical.items | Where-Object { $_.id -eq "layer_4" }) | Select-Object -First 1
  Assert-Equal "LLM Gateway percent" ([int]$llmGateway.percent) 67
  Assert-Contains "LLM Gateway status" $llmGateway.status "active_llm_operations_runtime_verified"
  Assert-NotSecretBearing "progress payload" ($progress | ConvertTo-Json -Depth 20 -Compress)

  $gates = [System.Collections.Generic.List[string]]::new()
  $probe = Invoke-LlmRuntimeProbe $BaseUrl
  $gates.Add("llm-runtime-probe") | Out-Null
  $gates.Add("llm-audit-contract") | Out-Null
  $baseUrlArgs = Get-BaseUrlArgs $BaseUrl ([bool]$AllowLocalhost)

  Invoke-RepoScript "phase4-llm-model-catalog" "scripts\verify-phase4-llm-model-catalog.ps1" $baseUrlArgs | Out-Null
  $gates.Add("phase4-llm-model-catalog") | Out-Null
  Invoke-RepoScript "phase4-llm-live-provider-guard" "scripts\verify-phase4-llm-live-provider-guard.ps1" $baseUrlArgs | Out-Null
  $gates.Add("phase4-llm-live-provider-guard") | Out-Null
  Invoke-RepoScript "phase3-llm-audit-feed" "scripts\verify-phase3-llm-audit-feed.ps1" $baseUrlArgs | Out-Null
  $gates.Add("phase3-llm-audit-feed") | Out-Null
  Invoke-RepoScript "phase3-llm-audit-export" "scripts\verify-phase3-llm-audit-export.ps1" $baseUrlArgs | Out-Null
  $gates.Add("phase3-llm-audit-export") | Out-Null
  Invoke-RepoScript "phase4-agent-llm-streaming-contract-runtime-hosted" "scripts\verify-phase4-agent-llm-streaming-contract-runtime-hosted.ps1" $baseUrlArgs | Out-Null
  $gates.Add("phase4-agent-llm-streaming-contract-runtime-hosted") | Out-Null
  Invoke-RepoScript "evidence-artifact-safety" "scripts\verify-evidence-artifact-safety.ps1" @() | Out-Null
  $gates.Add("evidence-artifact-safety") | Out-Null

  Assert-Equal "LLM gate count" $gates.Count 8

  $summary = [ordered]@{
    status = "passed"
    passed = $true
    release_id = $ReleaseId
    base_url = $BaseUrl
    source_commit_sha = $sourceSha
    immutable_image_commit_sha = $immutableSha
    production_rollout_claimed = $false
    llm_gate_count = $gates.Count
    changed_horizontal = "Phase 5 80->81"
    changed_vertical = "LLM Gateway 64->65"
    llm_runtime = $probe
    gates = @($gates)
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
    Write-Host "[phase5-active-llm-operations-bundle] verified"
    Write-Host "[phase5-active-llm-operations-bundle] release_id=$ReleaseId"
    Write-Host "[phase5-active-llm-operations-bundle] llm_gate_count=$($summary.llm_gate_count)"
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
      Write-Host "[phase5-active-llm-operations-bundle] failed"
      Write-Host "[phase5-active-llm-operations-bundle] error=$($_.Exception.Message)"
    }
    exit 0
  }
  throw
} finally {
  Pop-Location
}

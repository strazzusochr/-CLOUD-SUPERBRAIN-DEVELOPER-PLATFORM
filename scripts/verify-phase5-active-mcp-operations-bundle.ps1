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
    throw "Phase5 active MCP operations bundle verification failed: $Label expected '$Expected' but got '$Actual'."
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase5 active MCP operations bundle verification failed: $Label"
  }
}

function Assert-False($Label, $Value) {
  if ([bool]$Value) {
    throw "Phase5 active MCP operations bundle verification failed: $Label expected false."
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Phase5 active MCP operations bundle verification failed: $Label missing '$Expected'."
  }
}

function Assert-Sha($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[0-9a-f]{40}$') {
    throw "Phase5 active MCP operations bundle verification failed: $Label is not a lowercase 40-character SHA."
  }
}

function Assert-ReleaseId($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^prod-candidate-[0-9]{4}-[0-9]{2}-[0-9]{2}-rc[0-9]+$') {
    throw "Phase5 active MCP operations bundle verification failed: $Label is not a valid release candidate id."
  }
}

function Assert-NotSecretBearing($Label, $Value) {
  $text = ($Value | Out-String)
  $forbiddenPattern = "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Bearer [A-Za-z0-9_.-]{16,}|Cookie:|Set-Cookie:|BEGIN PRIVATE KEY|private key|raw_file_contents|redaction-proof-value"
  if ($text -match $forbiddenPattern) {
    throw "Phase5 active MCP operations bundle verification failed: $Label contained a forbidden secret/raw-payload pattern."
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

function Get-BaseUrlArgs([string]$BaseUrl, [bool]$AllowLocalhost) {
  $arguments = @("-BaseUrl", $BaseUrl)
  if ($AllowLocalhost) {
    $arguments += "-AllowLocalhost"
  }
  return ,$arguments
}

function Invoke-McpRuntimeProbe([string]$BaseUrl) {
  $health = Invoke-JsonApi "$BaseUrl/mcp/api/v1/health"
  Assert-Equal "mcp health status" ([string]$health.status) "healthy"
  Assert-Equal "mcp health service" ([string]$health.service) "mcp-gateway"
  Assert-Equal "mcp health catalog version" ([string]$health.capability_catalog_contract_version) "mcp-capability-catalog-v1"
  Assert-False "mcp health live writes" $health.live_mcp_writes

  $catalog = Invoke-JsonApi "$BaseUrl/mcp/api/v1/capabilities/catalog"
  Assert-Equal "catalog contract version" ([string]$catalog.contract_version) "mcp-capability-catalog-v1"
  Assert-Equal "catalog status" ([string]$catalog.status) "verified"
  Assert-False "catalog live mcp writes" $catalog.live_mcp_writes
  Assert-False "catalog live mutations" $catalog.live_mutations
  Assert-False "catalog external server calls" $catalog.external_mcp_server_calls
  Assert-True "catalog toolset count" ([int]$catalog.toolset_count -ge 6)
  Assert-True "catalog capability count" ([int]$catalog.capability_count -ge 6)
  Assert-Equal "catalog unsupported toolset guard" ([string]$catalog.guards.unsupported_toolset) "mcp_unsupported_toolset_guard"
  Assert-Equal "catalog redaction guard" ([string]$catalog.guards.secret_redaction) "mcp_secret_redaction_guard"

  $versionContract = Invoke-JsonApi "$BaseUrl/mcp/api/v1/version-pinning/contract"
  Assert-Equal "version pinning contract" ([string]$versionContract.contract_version) "mcp-version-pinning-v1"
  Assert-Equal "version pinning evidence" ([string]$versionContract.evidence_ref) "mcp_version_pinning_contract_visible"
  Assert-Contains "version pinning evidence refs" $versionContract.evidence_refs "mcp_capability_catalog_visible"
  Assert-Contains "version pinning no-live non-claim" $versionContract.non_claims "No live MCP write is enabled by this version-pinning contract."
  Assert-True "pinned tool contract count" (@($versionContract.pinned_tool_contracts).Count -ge 5)

  $auditContract = Invoke-JsonApi "$BaseUrl/api/v1/audit/mcp/contract"
  Assert-Equal "audit contract version" ([string]$auditContract.contract_version) "mcp-audit-feed-v1"
  Assert-Equal "audit snapshot evidence" ([string]$auditContract.snapshot_evidence_ref) "mcp_audit_snapshot_visible"
  Assert-Equal "audit redaction evidence" ([string]$auditContract.redaction_evidence_ref) "mcp_audit_redaction_enforced"
  Assert-False "audit live mcp writes claimed" $auditContract.live_mcp_writes_claimed

  $toolRequestId = "phase5-mcp-ops-block-" + [Guid]::NewGuid().ToString("N")
  $body = @{
    tool_request_id = $toolRequestId
    run_id = "phase5-mcp-ops"
    agent_role = "devops"
    toolset = "github"
    capability = "delete_branch"
    intent_summary = "prove active MCP operations block unsafe capability"
    input_ref = "{}"
    allowed_scope = "feature/mcp-operations"
    timeout_ms = 1000
    retry_budget = 0
    idempotency_key = $toolRequestId
    audit_tags = @("phase5", "mcp-operations")
    redaction_required = $true
    expected_output_type = "tool_result"
  } | ConvertTo-Json -Compress
  $blocked = Invoke-JsonApi "$BaseUrl/mcp/api/v1/tools/execute" "POST" $body
  Assert-Equal "blocked tool status" ([string]$blocked.status) "blocked"
  Assert-Equal "blocked tool error" ([string]$blocked.error_class) "unsupported_capability"
  Assert-Equal "blocked tool evidence" ([string]$blocked.evidence_ref) "mcp_unsupported_capability_guard"
  Assert-True "blocked tool audit persisted" ([bool]$blocked.audit_persisted)

  Assert-NotSecretBearing "mcp runtime probe" (@($health, $catalog, $versionContract, $auditContract, $blocked) | ConvertTo-Json -Depth 30 -Compress)
  return [ordered]@{
    toolset_count = [int]$catalog.toolset_count
    capability_count = [int]$catalog.capability_count
    version_contract = [string]$versionContract.contract_version
    audit_contract = [string]$auditContract.contract_version
    blocked_evidence = [string]$blocked.evidence_ref
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
    throw "Phase5 active MCP operations bundle requires HTTPS unless -AllowLocalhost is set."
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
  Assert-Contains "candidate MCP operations proof" $candidate "active_mcp_operations_bundle_proof: ``docs/release-artifacts/$ReleaseId-active-mcp-operations-bundle-20260515.md``"
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

  $proofPath = "docs\release-artifacts\$ReleaseId-active-mcp-operations-bundle-20260515.md"
  Assert-True "active MCP operations proof exists" (Test-Path -LiteralPath $proofPath)
  $proof = Get-Content -LiteralPath $proofPath -Raw
  foreach ($required in @(
    "Status: ``verified``",
    "release_id: ``$ReleaseId``",
    "source_commit_sha: ``$sourceSha``",
    "immutable_image_commit_sha: ``$immutableSha``",
    "base_url: ``https://188-34-191-140.sslip.io``",
    "production_rollout_claimed: ``false``",
    "mcp_gate_count: ``9``",
    "changed_horizontal: ``Phase 5 81->82``",
    "changed_vertical: ``MCP Gateway 65->66``",
    "This proof does not claim a production rollout.",
    "This proof does not claim release promotion.",
    "This proof does not claim live LLM provider calls.",
    "This proof does not claim live MCP writes.",
    "This proof does not claim local model downloads.",
    "This proof does not include secret values."
  )) {
    Assert-Contains "active MCP operations proof artifact" $proof $required
  }
  Assert-NotSecretBearing "active MCP operations proof artifact" $proof

  $progress = Invoke-JsonApi "$BaseUrl/api/v1/project/progress"
  Assert-Equal "progress overall" ([int]$progress.overall_percent) 82
  $phase5 = @($progress.horizontal.items | Where-Object { $_.id -eq "phase_5" }) | Select-Object -First 1
  Assert-Equal "progress phase5" ([int]$phase5.percent) 89
  Assert-Contains "phase5 status" $phase5.status "active_mcp_operations_bundle_verified"
  $mcpGateway = @($progress.vertical.items | Where-Object { $_.id -eq "layer_5" }) | Select-Object -First 1
  Assert-Equal "MCP Gateway percent" ([int]$mcpGateway.percent) 68
  Assert-Contains "MCP Gateway status" $mcpGateway.status "active_mcp_operations_runtime_verified"
  Assert-NotSecretBearing "progress payload" ($progress | ConvertTo-Json -Depth 20 -Compress)

  $gates = [System.Collections.Generic.List[string]]::new()
  $probe = Invoke-McpRuntimeProbe $BaseUrl
  $gates.Add("mcp-runtime-probe") | Out-Null
  $gates.Add("mcp-audit-contract") | Out-Null
  $baseUrlArgs = Get-BaseUrlArgs $BaseUrl ([bool]$AllowLocalhost)

  Invoke-RepoScript "phase4-mcp-capability-catalog" "scripts\verify-phase4-mcp-capability-catalog.ps1" $baseUrlArgs | Out-Null
  $gates.Add("phase4-mcp-capability-catalog") | Out-Null
  Invoke-RepoScript "phase4-mcp-security-guard" "scripts\verify-phase4-mcp-security-guard.ps1" $baseUrlArgs | Out-Null
  $gates.Add("phase4-mcp-security-guard") | Out-Null
  Invoke-RepoScript "phase4-mcp-devops-hosted" "scripts\verify-phase4-mcp-devops-hosted.ps1" $baseUrlArgs | Out-Null
  $gates.Add("phase4-mcp-devops-hosted") | Out-Null
  if (-not $AllowLocalhost) {
    Invoke-RepoScript "phase4-mcp-audit-feed-contract-runtime-hosted" "scripts\verify-phase4-mcp-audit-feed-contract-runtime-hosted.ps1" $baseUrlArgs | Out-Null
    $gates.Add("phase4-mcp-audit-feed-contract-runtime-hosted") | Out-Null
  }
  Invoke-RepoScript "phase3-mcp-deny-audit-correlation" "scripts\verify-phase3-mcp-deny-audit-correlation.ps1" $baseUrlArgs | Out-Null
  $gates.Add("phase3-mcp-deny-audit-correlation") | Out-Null
  Invoke-RepoScript "phase3-mcp-audit-export" "scripts\verify-phase3-mcp-audit-export.ps1" $baseUrlArgs | Out-Null
  $gates.Add("phase3-mcp-audit-export") | Out-Null
  Invoke-RepoScript "evidence-artifact-safety" "scripts\verify-evidence-artifact-safety.ps1" @() | Out-Null
  $gates.Add("evidence-artifact-safety") | Out-Null

  $expectedGateCount = if ($AllowLocalhost) { 8 } else { 9 }
  Assert-Equal "MCP gate count" $gates.Count $expectedGateCount

  $summary = [ordered]@{
    status = "passed"
    passed = $true
    release_id = $ReleaseId
    base_url = $BaseUrl
    source_commit_sha = $sourceSha
    immutable_image_commit_sha = $immutableSha
    production_rollout_claimed = $false
    mcp_gate_count = $gates.Count
    changed_horizontal = "Phase 5 81->82"
    changed_vertical = "MCP Gateway 65->66"
    mcp_runtime = $probe
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
    Write-Host "[phase5-active-mcp-operations-bundle] verified"
    Write-Host "[phase5-active-mcp-operations-bundle] release_id=$ReleaseId"
    Write-Host "[phase5-active-mcp-operations-bundle] mcp_gate_count=$($summary.mcp_gate_count)"
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
      Write-Host "[phase5-active-mcp-operations-bundle] failed"
      Write-Host "[phase5-active-mcp-operations-bundle] error=$($_.Exception.Message)"
    }
    exit 0
  }
  throw
} finally {
  Pop-Location
}

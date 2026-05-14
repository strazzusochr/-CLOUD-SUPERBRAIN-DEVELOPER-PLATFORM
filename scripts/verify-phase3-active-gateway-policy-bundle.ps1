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
    throw "Phase3 active gateway policy bundle verification failed: $Label expected '$Expected' but got '$Actual'."
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase3 active gateway policy bundle verification failed: $Label"
  }
}

function Assert-False($Label, $Value) {
  if ([bool]$Value) {
    throw "Phase3 active gateway policy bundle verification failed: $Label expected false."
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Phase3 active gateway policy bundle verification failed: $Label missing '$Expected'."
  }
}

function Assert-NotSecretBearing($Label, $Value) {
  $text = ($Value | Out-String)
  $forbiddenPattern = "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Bearer [A-Za-z0-9_.-]{16,}|Cookie:|Set-Cookie:|BEGIN PRIVATE KEY|private key|raw_file_contents|redaction-proof-value|provider_credentials_returned"":true|input_refs_returned"":true|prompt_bodies_returned"":true"
  if ($text -match $forbiddenPattern) {
    throw "Phase3 active gateway policy bundle verification failed: $Label contained a forbidden secret/raw-payload pattern."
  }
}

function Assert-Sha($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[0-9a-f]{40}$') {
    throw "Phase3 active gateway policy bundle verification failed: $Label is not a lowercase 40-character SHA."
  }
}

function Assert-ReleaseId($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^prod-candidate-[0-9]{4}-[0-9]{2}-[0-9]{2}-rc[0-9]+$') {
    throw "Phase3 active gateway policy bundle verification failed: $Label is not a valid release candidate id."
  }
}

function Invoke-JsonApi([string]$Url) {
  return Invoke-RestMethod -Method Get -Uri $Url -Headers @{ Accept = "application/json" } -TimeoutSec 90
}

function Assert-RequiredRefs($Label, $Refs, [string[]]$RequiredRefs) {
  $visibleRefs = @($Refs | ForEach-Object { [string]$_ })
  foreach ($ref in $RequiredRefs) {
    Assert-True "$Label $ref" ($visibleRefs -contains $ref)
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
    throw "Phase3 active gateway policy bundle requires HTTPS unless -AllowLocalhost is set."
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
  Assert-Contains "candidate gateway policy bundle proof" $candidate "active_gateway_policy_bundle_proof: ``docs/release-artifacts/$ReleaseId-active-gateway-policy-bundle-20260514.md``"
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

  $proofPath = "docs\release-artifacts\$ReleaseId-active-gateway-policy-bundle-20260514.md"
  Assert-True "active gateway policy proof exists" (Test-Path -LiteralPath $proofPath)
  $proof = Get-Content -LiteralPath $proofPath -Raw
  foreach ($required in @(
    "Status: ``verified``",
    "release_id: ``$ReleaseId``",
    "source_commit_sha: ``$sourceSha``",
    "immutable_image_commit_sha: ``$immutableSha``",
    "production_rollout_claimed: ``false``",
    "gateway_policy_surface_count: ``14``",
    "changed_horizontal: ``Phase 3 94->95, overall 79->80``",
    "changed_vertical: ``LLM Gateway 63->64, MCP Gateway 64->65``",
    "This proof does not claim a production rollout.",
    "This proof does not claim live LLM provider calls.",
    "This proof does not claim live MCP writes.",
    "This proof does not claim local model downloads.",
    "This proof does not include secret values."
  )) {
    Assert-Contains "active gateway policy proof artifact" $proof $required
  }
  if ($AllowLocalhost) {
    Assert-Contains "active gateway policy proof local command" $proof "scripts\verify-phase3-active-gateway-policy-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost"
  } else {
    Assert-Contains "active gateway policy proof base url" $proof "base_url: ``$BaseUrl``"
  }
  Assert-NotSecretBearing "active gateway policy proof artifact" $proof

  $llmHealth = Invoke-JsonApi "$BaseUrl/llm/api/v1/health"
  Assert-Equal "llm health status" $llmHealth.status "healthy"
  Assert-Equal "llm health service" $llmHealth.service "llm-gateway"
  Assert-Equal "llm health mode" $llmHealth.mode "deterministic_dry_run"
  Assert-False "llm health live provider calls" $llmHealth.live_provider_calls
  Assert-False "llm health model downloads" $llmHealth.model_downloads
  Assert-True "llm health open source first" $llmHealth.open_source_first
  Assert-Equal "llm model catalog version" $llmHealth.model_catalog_contract_version "llm-model-catalog-v1"
  Assert-Equal "llm model catalog evidence" $llmHealth.model_catalog_evidence_ref "llm_model_catalog_visible"

  $llmCatalog = Invoke-JsonApi "$BaseUrl/llm/api/v1/models/catalog"
  Assert-Equal "llm catalog version" $llmCatalog.contract_version "llm-model-catalog-v1"
  Assert-Equal "llm catalog status" $llmCatalog.status "verified"
  Assert-Equal "llm catalog evidence" $llmCatalog.evidence_ref "llm_model_catalog_visible"
  Assert-False "llm catalog live provider calls" $llmCatalog.live_provider_calls
  Assert-False "llm catalog model downloads" $llmCatalog.model_downloads
  Assert-False "llm catalog local model downloads" $llmCatalog.local_model_downloads_allowed
  Assert-True "llm catalog api inference only" $llmCatalog.api_inference_only
  Assert-True "llm catalog open source first" $llmCatalog.open_source_first
  Assert-True "llm catalog route count" ([int]$llmCatalog.route_count -ge 5)
  Assert-True "llm catalog configured models" ([int]$llmCatalog.configured_model_count -ge 10)
  Assert-Equal "llm direct provider guard" $llmCatalog.evidence_refs.direct_provider_blocked "llm_routing_policy_direct_provider_blocked"
  Assert-Equal "llm unknown model guard" $llmCatalog.evidence_refs.unknown_model_blocked "llm_routing_policy_unknown_model_blocked"
  foreach ($role in @("planner", "coder", "tester", "devops", "research")) {
    $route = @($llmCatalog.routes | Where-Object { [string]$_.agent_type -eq $role }) | Select-Object -First 1
    Assert-True "llm route $role visible" ($null -ne $route)
    Assert-True "llm route $role api only" $route.api_inference_only
    Assert-False "llm route $role no downloads" $route.model_downloads
    Assert-True "llm route $role open source first" $route.open_source_first
    Assert-True "llm route $role provider chain" (@($route.provider_chain) -contains "huggingface_inference_router")
  }
  Assert-NotSecretBearing "llm catalog" ($llmCatalog | ConvertTo-Json -Depth 30 -Compress)

  $llmAuditContract = Invoke-JsonApi "$BaseUrl/api/v1/audit/llm/contract"
  Assert-Equal "llm audit contract version" $llmAuditContract.contract_version "llm-audit-feed-v1"
  Assert-Equal "llm audit source event" $llmAuditContract.source_event_type "llm_gateway_request"
  Assert-Equal "llm audit redaction evidence" $llmAuditContract.redaction_evidence_ref "llm_audit_redaction_enforced"
  Assert-False "llm audit live provider claimed" $llmAuditContract.live_provider_calls_claimed
  Assert-True "llm audit read only" $llmAuditContract.read_only

  $llmAudit = Invoke-JsonApi "$BaseUrl/api/v1/audit/llm?limit=20"
  Assert-Equal "llm audit feed version" $llmAudit.contract_version "llm-audit-feed-v1"
  Assert-Equal "llm audit feed source event" $llmAudit.source_event_type "llm_gateway_request"
  Assert-True "llm audit events visible" (@($llmAudit.events).Count -ge 1)
  foreach ($event in @($llmAudit.events | Select-Object -First 5)) {
    Assert-False "llm audit event live provider calls" $event.details.live_provider_calls
  }
  Assert-NotSecretBearing "llm audit feed" ($llmAudit | ConvertTo-Json -Depth 30 -Compress)

  $llmSnapshot = Invoke-JsonApi "$BaseUrl/api/v1/audit/llm/snapshot?limit=50"
  Assert-Equal "llm snapshot version" $llmSnapshot.contract_version "llm-audit-feed-v1"
  Assert-Equal "llm snapshot mode" $llmSnapshot.mode "read_only_llm_audit_redaction_snapshot"
  Assert-Equal "llm snapshot evidence" $llmSnapshot.snapshot_evidence_ref "llm_audit_snapshot_visible"
  Assert-False "llm snapshot live provider claimed" $llmSnapshot.live_provider_calls_claimed
  Assert-False "llm snapshot prompt bodies returned" $llmSnapshot.prompt_bodies_returned
  Assert-False "llm snapshot provider credentials returned" $llmSnapshot.provider_credentials_returned
  Assert-Equal "llm snapshot forbidden hits" ([int]$llmSnapshot.forbidden_pattern_hits) 0

  $mcpHealth = Invoke-JsonApi "$BaseUrl/mcp/api/v1/health"
  Assert-Equal "mcp health status" $mcpHealth.status "healthy"
  Assert-Equal "mcp health service" $mcpHealth.service "mcp-gateway"
  Assert-False "mcp health live writes" $mcpHealth.live_mcp_writes
  Assert-Equal "mcp catalog version" $mcpHealth.capability_catalog_contract_version "mcp-capability-catalog-v1"
  Assert-Equal "mcp catalog evidence" $mcpHealth.capability_catalog_evidence_ref "mcp_capability_catalog_visible"

  $mcpCatalog = Invoke-JsonApi "$BaseUrl/mcp/api/v1/capabilities/catalog"
  Assert-Equal "mcp catalog contract version" $mcpCatalog.contract_version "mcp-capability-catalog-v1"
  Assert-Equal "mcp catalog status" $mcpCatalog.status "verified"
  Assert-Equal "mcp catalog mode" $mcpCatalog.mode "deterministic_mcp_capability_catalog"
  Assert-Equal "mcp catalog evidence" $mcpCatalog.evidence_ref "mcp_capability_catalog_visible"
  Assert-False "mcp catalog live writes" $mcpCatalog.live_mcp_writes
  Assert-False "mcp catalog live mutations" $mcpCatalog.live_mutations
  Assert-False "mcp catalog external server calls" $mcpCatalog.external_mcp_server_calls
  Assert-True "mcp catalog toolsets" ([int]$mcpCatalog.toolset_count -ge 6)
  Assert-True "mcp catalog capabilities" ([int]$mcpCatalog.capability_count -ge 6)
  $toolsetNames = @($mcpCatalog.toolsets | ForEach-Object { [string]$_.toolset })
  foreach ($toolset in @("github", "postgresql", "filesystem", "playwright", "e2b", "puppeteer")) {
    Assert-True "mcp toolset $toolset visible" ($toolsetNames -contains $toolset)
  }
  foreach ($toolset in @($mcpCatalog.toolsets)) {
    Assert-False "mcp toolset $($toolset.toolset) live writes" $toolset.live_mcp_writes
    Assert-False "mcp toolset $($toolset.toolset) live mutation" $toolset.live_mutation
    Assert-True "mcp toolset $($toolset.toolset) audit required" $toolset.requires_audit
    Assert-Equal "mcp toolset $($toolset.toolset) unsupported guard" $toolset.unsupported_capability_guard "mcp_unsupported_capability_guard"
  }
  Assert-Equal "mcp guard unsupported toolset" $mcpCatalog.guards.unsupported_toolset "mcp_unsupported_toolset_guard"
  Assert-Equal "mcp guard unsupported capability" $mcpCatalog.guards.unsupported_capability "mcp_unsupported_capability_guard"
  Assert-NotSecretBearing "mcp catalog" ($mcpCatalog | ConvertTo-Json -Depth 30 -Compress)

  $mcpAuditContract = Invoke-JsonApi "$BaseUrl/api/v1/audit/mcp/contract"
  Assert-Equal "mcp audit contract version" $mcpAuditContract.contract_version "mcp-audit-feed-v1"
  Assert-Equal "mcp audit source event" $mcpAuditContract.source_event_type "mcp_tool_executed"
  Assert-Equal "mcp audit redaction evidence" $mcpAuditContract.redaction_evidence_ref "mcp_audit_redaction_enforced"
  Assert-False "mcp audit live writes claimed" $mcpAuditContract.live_mcp_writes_claimed
  Assert-True "mcp audit read only" $mcpAuditContract.read_only

  $mcpAudit = Invoke-JsonApi "$BaseUrl/api/v1/audit/mcp?limit=20"
  Assert-Equal "mcp audit feed version" $mcpAudit.contract_version "mcp-audit-feed-v1"
  Assert-Equal "mcp audit feed source event" $mcpAudit.source_event_type "mcp_tool_executed"
  Assert-True "mcp audit events visible" (@($mcpAudit.events).Count -ge 1)
  foreach ($event in @($mcpAudit.events | Select-Object -First 5)) {
    Assert-False "mcp audit event input stored" $event.details.input_ref_stored
  }
  Assert-NotSecretBearing "mcp audit feed" ($mcpAudit | ConvertTo-Json -Depth 30 -Compress)

  $mcpSnapshot = Invoke-JsonApi "$BaseUrl/api/v1/audit/mcp/snapshot?limit=50"
  Assert-Equal "mcp snapshot version" $mcpSnapshot.contract_version "mcp-audit-feed-v1"
  Assert-Equal "mcp snapshot mode" $mcpSnapshot.mode "read_only_mcp_audit_redaction_snapshot"
  Assert-Equal "mcp snapshot evidence" $mcpSnapshot.snapshot_evidence_ref "mcp_audit_snapshot_visible"
  Assert-False "mcp snapshot live writes claimed" $mcpSnapshot.live_mcp_writes_claimed
  Assert-False "mcp snapshot input refs returned" $mcpSnapshot.input_refs_returned
  Assert-False "mcp snapshot provider credentials returned" $mcpSnapshot.provider_credentials_returned
  Assert-Equal "mcp snapshot forbidden hits" ([int]$mcpSnapshot.forbidden_pattern_hits) 0

  $gatewayContract = Invoke-JsonApi "$BaseUrl/api/v1/security/gateway-correlation/contract"
  Assert-Equal "gateway contract version" $gatewayContract.contract_version "gateway-correlation-snapshot-v1"
  Assert-True "gateway contract read only" $gatewayContract.read_only
  Assert-False "gateway contract live provider claimed" $gatewayContract.live_provider_calls_claimed
  Assert-False "gateway contract live mcp writes claimed" $gatewayContract.live_mcp_writes_claimed
  Assert-RequiredRefs "gateway source event types" $gatewayContract.source_event_types @("task_completed", "llm_gateway_request", "mcp_tool_executed")

  $gatewaySnapshot = Invoke-JsonApi "$BaseUrl/api/v1/security/gateway-correlation/snapshot?limit=80"
  Assert-Equal "gateway snapshot version" $gatewaySnapshot.contract_version "gateway-correlation-snapshot-v1"
  Assert-False "gateway snapshot prompt bodies" $gatewaySnapshot.prompt_bodies_returned
  Assert-False "gateway snapshot input refs" $gatewaySnapshot.tool_input_refs_returned
  Assert-False "gateway snapshot provider credentials" $gatewaySnapshot.provider_credentials_returned
  Assert-Equal "gateway snapshot forbidden hits" ([int]$gatewaySnapshot.forbidden_pattern_hits) 0
  Assert-True "gateway snapshot groups visible" (@($gatewaySnapshot.groups).Count -ge 1)

  $gatewayRollup = Invoke-JsonApi "$BaseUrl/api/v1/security/gateway-correlation/risk-rollup?limit=80"
  Assert-Equal "gateway rollup version" $gatewayRollup.contract_version "gateway-correlation-risk-rollup-v1"
  Assert-False "gateway rollup production rollout" $gatewayRollup.production_rollout_claimed
  Assert-False "gateway rollup live provider calls" $gatewayRollup.live_provider_calls_claimed
  Assert-False "gateway rollup live mcp writes" $gatewayRollup.live_mcp_writes_claimed

  $gatewayTimeline = Invoke-JsonApi "$BaseUrl/api/v1/security/gateway-correlation/timeline?limit=80"
  Assert-Equal "gateway timeline version" $gatewayTimeline.contract_version "gateway-correlation-timeline-v1"
  Assert-False "gateway timeline production rollout" $gatewayTimeline.production_rollout_claimed
  Assert-False "gateway timeline live provider calls" $gatewayTimeline.live_provider_calls_claimed
  Assert-False "gateway timeline live mcp writes" $gatewayTimeline.live_mcp_writes_claimed
  Assert-True "gateway timeline events visible" (@($gatewayTimeline.events).Count -ge 1)

  $summary = [ordered]@{
    status = "passed"
    passed = $true
    release_id = $ReleaseId
    base_url = $BaseUrl
    source_commit_sha = $sourceSha
    immutable_image_commit_sha = $immutableSha
    production_rollout_claimed = $false
    gateway_policy_surface_count = 14
    changed_horizontal = "Phase 3 94->95, overall 79->80"
    changed_vertical = "LLM Gateway 63->64, MCP Gateway 64->65"
    surfaces = @(
      "llm-health",
      "llm-model-catalog",
      "llm-audit-feed",
      "llm-audit-snapshot",
      "mcp-health",
      "mcp-capability-catalog",
      "mcp-audit-feed",
      "mcp-audit-snapshot",
      "gateway-correlation-risk-rollup",
      "gateway-correlation-timeline"
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
    Write-Host "[phase3-active-gateway-policy-bundle] verified"
    Write-Host "[phase3-active-gateway-policy-bundle] release_id=$ReleaseId"
    Write-Host "[phase3-active-gateway-policy-bundle] gateway_policy_surface_count=$($summary.gateway_policy_surface_count)"
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
      Write-Host "[phase3-active-gateway-policy-bundle] failed"
      Write-Host "[phase3-active-gateway-policy-bundle] error=$($_.Exception.Message)"
    }
    exit 0
  }
  throw
} finally {
  Pop-Location
}

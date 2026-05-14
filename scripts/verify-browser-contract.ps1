param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [switch]$SeedMemoryConsolidation
)

$ErrorActionPreference = "Stop"

$progressManifestPath = Join-Path $PSScriptRoot "..\docs\project-progress.manifest.json"
$progressManifest = Get-Content -Path $progressManifestPath -Raw | ConvertFrom-Json
$expectedOverallPercent = [int]$progressManifest.overall_percent

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Browser contract verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Browser contract verification failed: $label"
  }
}

function Assert-ArrayEquivalent($label, $actual, $expected) {
  $actualItems = @($actual | ForEach-Object { [string]$_ })
  $expectedItems = @($expected | ForEach-Object { [string]$_ })
  if ($actualItems.Count -ne $expectedItems.Count) {
    throw "Browser contract verification failed: $label count mismatch. Actual: $($actualItems -join ', ') Expected: $($expectedItems -join ', ')"
  }
  foreach ($item in $expectedItems) {
    if (-not ($actualItems -contains $item)) {
      throw "Browser contract verification failed: $label missing expected '$item'. Actual: $($actualItems -join ', ')"
    }
  }
  foreach ($item in $actualItems) {
    if (-not ($expectedItems -contains $item)) {
      throw "Browser contract verification failed: $label had unexpected '$item'. Expected: $($expectedItems -join ', ')"
    }
  }
}

function Invoke-Text($url) {
  $python = @'
import sys
import urllib.request

url = sys.argv[1]
with urllib.request.urlopen(url, timeout=10) as response:
    sys.stdout.write(response.read().decode("utf-8", errors="replace"))
'@
  return ($python | py -3 - $url)
}

function Invoke-StatusCode($url) {
  $python = @'
import sys
import urllib.error
import urllib.request

url = sys.argv[1]
try:
    with urllib.request.urlopen(url, timeout=30) as response:
        sys.stdout.write(str(response.status))
except urllib.error.HTTPError as error:
    sys.stdout.write(str(error.code))
'@
  return ($python | py -3 - $url)
}

function Invoke-JsonApi(
  [string]$Url,
  [string]$Method = "GET",
  [string]$Body = "",
  [string]$ContentType = "application/json",
  [int]$TimeoutSeconds = 15
) {
  $payload = [ordered]@{
    url = $Url
    method = $Method
    timeout_seconds = $TimeoutSeconds
  }
  if ($Body) {
    $payload.body_b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Body))
  }
  if ($ContentType) {
    $payload.content_type = $ContentType
  }
  $payloadJson = $payload | ConvertTo-Json -Compress -Depth 6
  $payloadFile = Join-Path $env:TEMP ("browser-contract-json-" + [Guid]::NewGuid().ToString("N") + ".json")
  $pythonFile = Join-Path $env:TEMP ("browser-contract-json-" + [Guid]::NewGuid().ToString("N") + ".py")
  try {
    Set-Content -LiteralPath $payloadFile -Value $payloadJson -NoNewline -Encoding utf8
    $pythonScript = @'
import base64
import json
import sys
import urllib.request

with open(sys.argv[1], "r", encoding="utf-8-sig") as handle:
    payload = json.load(handle)

data = None
if payload.get("body_b64"):
    data = base64.b64decode(payload["body_b64"])

headers = {}
if payload.get("content_type"):
    headers["Content-Type"] = payload["content_type"]

request = urllib.request.Request(
    payload["url"],
    data=data,
    headers=headers,
    method=payload.get("method", "GET"),
)

try:
    with urllib.request.urlopen(request, timeout=payload.get("timeout_seconds", 15)) as response:
        body = response.read().decode("utf-8")
    print(body)
except urllib.error.HTTPError as exc:
    print(exc.read().decode("utf-8"))
    sys.exit(exc.code)
'@
    Set-Content -LiteralPath $pythonFile -Value $pythonScript -NoNewline -Encoding utf8
    $output = py -3 $pythonFile $payloadFile 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
      throw $output.Trim()
    }
    return $output
  } finally {
    if (Test-Path $payloadFile) {
      Remove-Item -LiteralPath $payloadFile -Force
    }
    if (Test-Path $pythonFile) {
      Remove-Item -LiteralPath $pythonFile -Force
    }
  }
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ((-not $AllowLocalhost) -and ($BaseUrl -match "localhost|127\.0\.0\.1|\[::1\]")) {
  throw "Browser contract proof refuses localhost unless -AllowLocalhost is set"
}

Write-Host "[browser-contract] base url: $BaseUrl"

Write-Host "[browser-contract] frontend markers"
$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "frontend title" $frontendHtml "Cloud Superbrain"
Assert-Contains "langgraph progress panel" $frontendHtml "LangGraph Progress"
Assert-Contains "phase2 runtime button" $frontendHtml "Start Phase 2 Runtime"
Assert-Contains "phase2 runtime contract text" $frontendHtml "Phase 2 Runtime Contract"
Assert-Contains "phase2 runtime pending marker" $frontendHtml "Runtime Evidence"
Assert-Contains "phase2 runtime runs marker" $frontendHtml "Runtime Runs"
Assert-Contains "phase2 runtime status marker" $frontendHtml "Latest Runtime Status"
Assert-Contains "phase2 runtime role summaries marker" $frontendHtml "Role Summaries"
Assert-Contains "phase2 runtime sse contract marker" $frontendHtml "SSE Event Contract"
Assert-Contains "phase2 runtime sse evidence marker" $frontendHtml "phase2_sse_event_contract_proof"
Assert-Contains "phase2 runtime run status evidence marker" $frontendHtml "phase2_runtime_run_status_visible"
Assert-Contains "external gate mirror panel" $frontendHtml "External Gate Mirror"
Assert-Contains "external gate mirror evidence marker" $frontendHtml "external_gate_mirror_proof"
Assert-Contains "branch protection mirror marker" $frontendHtml "branch_protection_verify_contract"
Assert-Contains "cloud inventory panel" $frontendHtml "Cloud Inventory"
Assert-Contains "cloud inventory evidence marker" $frontendHtml "cloud_provider_inventory_visible"
Assert-Contains "cloud inventory endpoint marker" $frontendHtml "GET /api/v1/clouds"
Assert-Contains "cloud layer readiness panel" $frontendHtml "Cloud 7-Layer Readiness"
Assert-Contains "cloud layer readiness evidence marker" $frontendHtml "cloud_layer_readiness_visible"
Assert-Contains "cloud layer readiness endpoint marker" $frontendHtml "GET /api/v1/clouds/layers"
Assert-Contains "cloud render offload panel" $frontendHtml "Cloud Render Offload"
Assert-Contains "cloud render offload evidence marker" $frontendHtml "cloud_render_offload_contract_visible"
Assert-Contains "cloud render offload endpoint marker" $frontendHtml "GET /api/v1/clouds/render-offload/contract"
Assert-Contains "cloud deployment preflight panel" $frontendHtml "Cloud Deployment Preflight"
Assert-Contains "cloud deployment preflight evidence marker" $frontendHtml "cloud_deployment_preflight_visible"
Assert-Contains "cloud deployment preflight endpoint marker" $frontendHtml "GET /api/v1/clouds/deployment-preflight/contract"
Assert-Contains "auth contract panel" $frontendHtml "Auth Contract"
Assert-Contains "system fallback panel" $frontendHtml "System Unavailable Fallback"
Assert-Contains "layer interface contract panel" $frontendHtml "Layer Interface Contracts"
Assert-Contains "layer interface evidence marker" $frontendHtml "layer_interface_contracts_visible"
Assert-Contains "task assignment contract panel" $frontendHtml "Task Assignment Queue Contract"
Assert-Contains "task assignment evidence marker" $frontendHtml "task_assignment_queue_contract_visible"
Assert-Contains "task assignment priority routing marker" $frontendHtml "Priority Routing"
Assert-Contains "agent llm streaming contract panel" $frontendHtml "Agent LLM Streaming Contract"
Assert-Contains "agent llm streaming evidence marker" $frontendHtml "agent_llm_streaming_contract_visible"
Assert-Contains "llm runtime guard panel" $frontendHtml "Runtime Guard"
Assert-Contains "llm runtime guard contract marker" $frontendHtml "llm-runtime-guard-parity-v1"
Assert-Contains "llm runtime guard evidence marker" $frontendHtml "llm_runtime_guard_parity_visible"
Assert-Contains "llm model catalog panel" $frontendHtml "Model Catalog"
Assert-Contains "llm model catalog contract marker" $frontendHtml "llm-model-catalog-v1"
Assert-Contains "llm model catalog evidence marker" $frontendHtml "llm_model_catalog_visible"
Assert-Contains "llm model catalog endpoint marker" $frontendHtml "GET /llm/api/v1/models/catalog"
Assert-Contains "llm audit feed panel" $frontendHtml "LLM Audit Feed"
Assert-Contains "llm audit feed contract marker" $frontendHtml "llm-audit-feed-v1"
Assert-Contains "llm audit feed evidence marker" $frontendHtml "llm_audit_feed_visible"
Assert-Contains "llm audit feed endpoint marker" $frontendHtml "GET /api/v1/audit/llm"
Assert-Contains "langfuse trace access panel" $frontendHtml "Langfuse Trace Access"
Assert-Contains "langfuse trace access contract marker" $frontendHtml "langfuse-trace-access-v1"
Assert-Contains "langfuse trace access evidence marker" $frontendHtml "langfuse_trace_access_visible"
Assert-Contains "langfuse trace access endpoint marker" $frontendHtml "GET /api/v1/observability/langfuse/trace/{trace_id}"
Assert-Contains "live agent control panel" $frontendHtml "Live Agent Control"
Assert-Contains "live agent ui evidence marker" $frontendHtml "live_agent_steering_ui_visible"
Assert-Contains "live agent history evidence marker" $frontendHtml "live_agent_steering_history_visible"
Assert-Contains "live agent audit evidence marker" $frontendHtml "live_agent_steering_audit_persisted"
Assert-Contains "live agent metadata guard marker" $frontendHtml "live_agent_metadata_guard_enforced"
Assert-Contains "live agent steer endpoint marker" $frontendHtml "POST /api/v1/live-agents/steer"
Assert-Contains "live agent history endpoint marker" $frontendHtml "GET /api/v1/live-agents/history"
Assert-Contains "autonomous coding team panel" $frontendHtml "Autonomous Coding Team"
Assert-Contains "autonomous dispatch objective marker" $frontendHtml "Dispatch Objective"
Assert-Contains "autonomous dispatch endpoint marker" $frontendHtml "POST /api/v1/task/dispatch"
Assert-Contains "autonomous dispatch ui evidence marker" $frontendHtml "autonomous_team_dispatch_ui_visible"
Assert-Contains "autonomous dispatch evidence marker" $frontendHtml "autonomous_team_dispatch_visible"
Assert-Contains "autonomous dispatch status evidence marker" $frontendHtml "autonomous_team_dispatch_status_visible"
Assert-Contains "mcp version pinning contract panel" $frontendHtml "MCP Version Pinning Contract"
Assert-Contains "mcp version pinning evidence marker" $frontendHtml "mcp_version_pinning_contract_visible"
Assert-Contains "mcp capability catalog panel" $frontendHtml "MCP Capability Catalog"
Assert-Contains "mcp capability catalog contract marker" $frontendHtml "mcp-capability-catalog-v1"
Assert-Contains "mcp capability catalog evidence marker" $frontendHtml "mcp_capability_catalog_visible"
Assert-Contains "mcp capability catalog endpoint marker" $frontendHtml "GET /mcp/api/v1/capabilities/catalog"
Assert-Contains "memory embedding consistency contract panel" $frontendHtml "Memory Embedding Consistency Contract"
Assert-Contains "memory embedding consistency evidence marker" $frontendHtml "memory_embedding_consistency_contract_visible"
Assert-Contains "memory consolidation panel" $frontendHtml "Memory Consolidation"
Assert-Contains "memory consolidation refresh button" $frontendHtml "Refresh"
Assert-Contains "project progress panel" $frontendHtml "Project Progress"
Assert-Contains "project progress completion contract panel" $frontendHtml "100% Contract"
Assert-Contains "project progress completion evidence marker" $frontendHtml "project_progress_100_percent_gate_contract"
Assert-Contains "agent activity per-role summaries ui" $frontendHtml "Per-role Summaries"
Assert-Contains "agent activity per-role css" $frontendHtml "perRoleSummary"
Assert-Contains "memory purge contract panel" $frontendHtml "Memory Purge Contract"
Assert-Contains "cost export contract panel" $frontendHtml "CSV Export"
Assert-Contains "rate limit guard panel" $frontendHtml "Rate Limit Guard"
Assert-Contains "session limit guard panel" $frontendHtml "Session Limit Guard"
Assert-Contains "error response contract panel" $frontendHtml "Error Response Contract"
Assert-Contains "security headers contract panel" $frontendHtml "Security Headers Contract"
Assert-Contains "csp report contract panel" $frontendHtml "CSP Report Contract"
Assert-Contains "csp report evidence marker" $frontendHtml "csp_report_contract_visible"
Assert-Contains "security audit surface panel" $frontendHtml "Security Audit Surface"
Assert-Contains "security audit surface contract marker" $frontendHtml "security-audit-surface-v1"
Assert-Contains "security audit surface evidence marker" $frontendHtml "security_audit_surface_visible"
Assert-Contains "security audit surface event evidence marker" $frontendHtml "security_audit_event_visible"
Assert-Contains "security audit surface endpoint marker" $frontendHtml "GET /api/v1/security/events"
Assert-Contains "security review queue panel" $frontendHtml "Security Review Queue"
Assert-Contains "security review queue contract marker" $frontendHtml "security-review-queue-v1"
Assert-Contains "security review queue evidence marker" $frontendHtml "security_review_queue_visible"
Assert-Contains "security review queue item evidence marker" $frontendHtml "security_review_item_visible"
Assert-Contains "security review queue redaction marker" $frontendHtml "security_review_redaction_enforced"
Assert-Contains "security review queue mutation marker" $frontendHtml "security_review_mutation_blocked"
Assert-Contains "security review queue filter marker" $frontendHtml "security_review_filter_state_visible"
Assert-Contains "security review queue decision marker" $frontendHtml "security_review_decision_history_visible"
Assert-Contains "security review queue snapshot marker" $frontendHtml "security_review_evidence_snapshot_visible"
Assert-Contains "security review queue endpoint marker" $frontendHtml "GET /api/v1/security/review-queue"
Assert-Contains "trace id contract panel" $frontendHtml "Trace ID Contract"
Assert-Contains "cache control contract panel" $frontendHtml "Cache Control Contract"
Assert-Contains "request id contract panel" $frontendHtml "Request ID Contract"
Assert-Contains "request id audit feed marker" $frontendHtml "request_id_audit_feed_visible"
Assert-Contains "agent activity panel" $frontendHtml "Agent Activity"
Assert-Contains "agent activity filtered feed marker" $frontendHtml "agent_activity_filtered_feed_visible"
Assert-Contains "agent activity filter controls" $frontendHtml "activityFilterBar"

Write-Host "[browser-contract] favicon"
$faviconStatus = Invoke-StatusCode "$BaseUrl/favicon.ico"
Assert-True "favicon status 200" ($faviconStatus -eq "200")

Write-Host "[browser-contract] project progress"
$projectProgress = Invoke-Text "$BaseUrl/api/v1/project/progress"
Assert-Contains "project progress overall" $projectProgress ('"overall_percent":{0}' -f $expectedOverallPercent)
Assert-Contains "project progress phase2" $projectProgress '"id":"phase_2"'
Assert-Contains "project progress layer frontend" $projectProgress '"id":"layer_1"'
Assert-Contains "project progress worker status regression" $projectProgress "worker-status-regression-harness"

Write-Host "[browser-contract] project progress integrity"
$projectProgressIntegrity = Invoke-Text "$BaseUrl/api/v1/project/progress/integrity"
Assert-Contains "project progress integrity version" $projectProgressIntegrity '"contract_version":"project-progress-integrity-v1"'
Assert-Contains "project progress integrity verified" $projectProgressIntegrity '"status":"verified"'
Assert-Contains "project progress integrity evidence" $projectProgressIntegrity '"evidence_ref":"project_progress_integrity_runtime_proof"'
Assert-Contains "project progress integrity computed" $projectProgressIntegrity ('"computed_overall_percent":{0}' -f $expectedOverallPercent)
Assert-Contains "project progress integrity manifest" $projectProgressIntegrity ('"manifest_overall_percent":{0}' -f $expectedOverallPercent)

Write-Host "[browser-contract] project progress completion contract"
$projectProgressCompletion = Invoke-Text "$BaseUrl/api/v1/project/progress/completion"
Assert-Contains "project progress completion version" $projectProgressCompletion '"contract_version":"project-progress-100-percent-contract-v1"'
Assert-Contains "project progress completion status" $projectProgressCompletion '"status":"blocked_external_gates"'
Assert-Contains "project progress completion evidence" $projectProgressCompletion '"evidence_ref":"project_progress_100_percent_gate_contract"'
Assert-Contains "project progress completion cannot set all to 100" $projectProgressCompletion '"can_set_all_to_100":false'
Assert-Contains "project progress completion external gates cleared" $projectProgressCompletion '"missing_external_gates":[]'
Assert-Contains "project progress completion local gap blocker" $projectProgressCompletion "local_progress_gaps_require_verified_evidence_for_each_phase_and_layer"

Write-Host "[browser-contract] layer interface contracts"
$layerInterfaceContract = Invoke-Text "$BaseUrl/api/v1/layer-interfaces/contract"
Assert-Contains "layer interface contract version" $layerInterfaceContract '"contract_version":"layer-interface-contracts-v1"'
Assert-Contains "layer interface evidence" $layerInterfaceContract '"evidence_ref":"layer_interface_contracts_visible"'
Assert-Contains "layer interface l1" $layerInterfaceContract '"id":"L1-L2"'
Assert-Contains "layer interface mcp" $layerInterfaceContract '"id":"L2-L5"'
Assert-Contains "layer interface observability" $layerInterfaceContract '"id":"L7-OBS"'

Write-Host "[browser-contract] cloud provider inventory"
$cloudProviderInventory = Invoke-Text "$BaseUrl/api/v1/clouds"
Assert-Contains "cloud provider contract version" $cloudProviderInventory '"contract_version":"cloud-provider-inventory-v1"'
Assert-Contains "cloud provider evidence" $cloudProviderInventory '"evidence_ref":"cloud_provider_inventory_visible"'
Assert-Contains "cloud provider hetzner" $cloudProviderInventory '"id":"hetzner_cloud"'
Assert-Contains "cloud provider gitkraken" $cloudProviderInventory '"id":"gitkraken_identity"'
Assert-Contains "cloud provider seven layer mapping" $cloudProviderInventory '"seven_layer_mapping"'
$cloudLayerReadiness = Invoke-Text "$BaseUrl/api/v1/clouds/layers"
Assert-Contains "cloud layer readiness contract version" $cloudLayerReadiness '"contract_version":"cloud-layer-readiness-v1"'
Assert-Contains "cloud layer readiness evidence" $cloudLayerReadiness '"evidence_ref":"cloud_layer_readiness_visible"'
Assert-Contains "cloud layer readiness layer 7" $cloudLayerReadiness '"layer_id":"layer_7"'
Assert-Contains "cloud layer readiness gitkraken" $cloudLayerReadiness 'gitkraken_identity'
$cloudRenderOffloadContract = Invoke-Text "$BaseUrl/api/v1/clouds/render-offload/contract"
Assert-Contains "cloud render offload contract version" $cloudRenderOffloadContract '"contract_version":"cloud-render-offload-surface-v1"'
Assert-Contains "cloud render offload contract evidence" $cloudRenderOffloadContract '"evidence_ref":"cloud_render_offload_contract_runtime_visible"'
Assert-Contains "cloud render offload contract endpoint" $cloudRenderOffloadContract '"endpoint":"GET /api/v1/clouds/render-offload/contract"'
Assert-Contains "cloud render offload runtime endpoint" $cloudRenderOffloadContract '"runtime_endpoint":"GET /api/v1/clouds/render-offload"'
$cloudRenderOffloadRuntime = Invoke-Text "$BaseUrl/api/v1/clouds/render-offload"
Assert-Contains "cloud render offload runtime version" $cloudRenderOffloadRuntime '"contract_version":"cloud-render-offload-v1"'
Assert-Contains "cloud render offload runtime evidence" $cloudRenderOffloadRuntime '"evidence_ref":"cloud_render_offload_contract_visible"'
Assert-Contains "cloud render offload local block" $cloudRenderOffloadRuntime '"localhost_heavy_render_allowed":false'
$cloudRenderOffloadRuntimeJson = $cloudRenderOffloadRuntime | ConvertFrom-Json
$cloudRenderOffloadMissingRequired = @($cloudRenderOffloadRuntimeJson.missing_required_env | ForEach-Object { [string]$_ })
$cloudRenderOffloadExpectedBlockers = @($cloudRenderOffloadMissingRequired | ForEach-Object { "cloud_render_offload_requires_{0}" -f $_ })
$cloudRenderOffloadActualBlockers = @($cloudRenderOffloadRuntimeJson.blockers | ForEach-Object { [string]$_ })
Assert-True "cloud render offload missing required env visible" ($null -ne $cloudRenderOffloadRuntimeJson.missing_required_env)
Assert-True "cloud render offload blockers visible" ($null -ne $cloudRenderOffloadRuntimeJson.blockers)
Assert-True "cloud render offload status supported" (@("cloud_runtime_ready", "action_required") -contains [string]$cloudRenderOffloadRuntimeJson.status)
if ($cloudRenderOffloadExpectedBlockers.Count -eq 0) {
  Assert-True "cloud render offload ready when no blockers remain" ([string]$cloudRenderOffloadRuntimeJson.status -eq "cloud_runtime_ready")
} else {
  Assert-True "cloud render offload action required when blockers remain" ([string]$cloudRenderOffloadRuntimeJson.status -eq "action_required")
}
Assert-ArrayEquivalent "cloud render offload blocker set" $cloudRenderOffloadActualBlockers $cloudRenderOffloadExpectedBlockers
$cloudDeploymentPreflightContract = Invoke-Text "$BaseUrl/api/v1/clouds/deployment-preflight/contract"
Assert-Contains "cloud deployment preflight contract version" $cloudDeploymentPreflightContract '"contract_version":"cloud-deployment-preflight-surface-v1"'
Assert-Contains "cloud deployment preflight contract evidence" $cloudDeploymentPreflightContract '"evidence_ref":"cloud_deployment_preflight_contract_runtime_visible"'
Assert-Contains "cloud deployment preflight contract endpoint" $cloudDeploymentPreflightContract '"endpoint":"GET /api/v1/clouds/deployment-preflight/contract"'
Assert-Contains "cloud deployment preflight runtime endpoint" $cloudDeploymentPreflightContract '"runtime_endpoint":"GET /api/v1/clouds/deployment-preflight"'
$cloudDeploymentPreflightRuntime = Invoke-Text "$BaseUrl/api/v1/clouds/deployment-preflight"
Assert-Contains "cloud deployment preflight runtime version" $cloudDeploymentPreflightRuntime '"contract_version":"cloud-deployment-preflight-v1"'
Assert-Contains "cloud deployment preflight runtime evidence" $cloudDeploymentPreflightRuntime '"evidence_ref":"cloud_deployment_preflight_visible"'
Assert-Contains "cloud deployment preflight status" $cloudDeploymentPreflightRuntime '"status":"verified"'
Assert-Contains "cloud deployment preflight cloud claim allowed" $cloudDeploymentPreflightRuntime '"cloud_deploy_claim_allowed":true'
Assert-Contains "cloud deployment preflight production allowed" $cloudDeploymentPreflightRuntime '"production_deploy_claim_allowed":true'
Assert-Contains "cloud deployment preflight no blocked gates" $cloudDeploymentPreflightRuntime '"missing_or_blocked_gates":[]'
Assert-Contains "cloud deployment preflight ghcr sequence" $cloudDeploymentPreflightRuntime "publish_ghcr_images"
Assert-Contains "cloud deployment preflight hosted origins" $cloudDeploymentPreflightRuntime "hosted_backend_origins"
Assert-Contains "cloud deployment preflight branch token" $cloudDeploymentPreflightRuntime "BRANCH_PROTECTION_TOKEN"
Assert-Contains "cloud deployment preflight cloud compose" $cloudDeploymentPreflightRuntime "docker-compose.cloud.yml"
Assert-Contains "cloud deployment preflight owner review" $cloudDeploymentPreflightRuntime "owner_review_before_production"

Write-Host "[browser-contract] auth contract"
$authContract = Invoke-Text "$BaseUrl/api/v1/auth/contract"
Assert-Contains "auth contract version" $authContract '"contract_version":"auth-github-jwt-refresh-v1"'
Assert-Contains "auth contract evidence" $authContract '"contract":"auth_contract_visible"'
Assert-Contains "auth contract no live oauth" $authContract '"live_github_oauth_call":false'
Assert-Contains "auth contract access ttl" $authContract '"access_token_ttl_seconds":900'
Assert-Contains "auth contract refresh ttl" $authContract '"ttl_seconds":604800'
Assert-Contains "auth contract rotation" $authContract '"rotation_required":true'
Assert-Contains "auth contract redis blacklist" $authContract '"blacklist_store":"redis"'
Assert-Contains "auth contract same site" $authContract '"SameSite":"Strict"'
$authGithub = Invoke-Text "$BaseUrl/api/v1/auth/github"
Assert-Contains "auth github contract version" $authGithub '"contract_version":"auth-github-jwt-refresh-v1"'
Assert-Contains "auth github no live oauth" $authGithub '"live_github_oauth_call":false'
Assert-Contains "auth github authorize url" $authGithub "github.com/login/oauth/authorize"
$authCallback = Invoke-JsonApi -Url "$BaseUrl/api/v1/auth/callback?code=browser-auth-code&state=browser-auth-state" -Method "GET" -ContentType ""
Assert-Contains "auth callback authenticated" $authCallback '"status":"authenticated"'
Assert-Contains "auth callback no live oauth" $authCallback '"live_github_oauth_call":false'
Assert-Contains "auth callback same site strict" $authCallback '"SameSite":"Strict"'
$authRefreshToken = "browser-refresh-token-" + [Guid]::NewGuid().ToString("N")
$authRefreshBody = @{ refresh_token = $authRefreshToken; trace_id = "browser-auth-refresh-rotated" } | ConvertTo-Json -Compress
$authRefresh = Invoke-JsonApi -Url "$BaseUrl/api/v1/auth/refresh" -Method "POST" -Body $authRefreshBody -ContentType "application/json"
Assert-Contains "auth refresh rotated status" $authRefresh '"status":"rotated"'
Assert-Contains "auth refresh rotated flag" $authRefresh '"refresh_token_rotated":true'
Assert-Contains "auth refresh blacklist flag" $authRefresh '"old_refresh_token_blacklisted":true'
$authReuseOutput = ""
$authReuseFailed = $false
try {
  $authReuseOutput = Invoke-JsonApi -Url "$BaseUrl/api/v1/auth/refresh" -Method "POST" -Body $authRefreshBody -ContentType "application/json"
} catch {
  $authReuseFailed = $true
  $authReuseOutput = $_.Exception.Message
}
Assert-True "auth refresh reuse blocked with non-2xx" $authReuseFailed
Assert-Contains "auth refresh reuse blocked" $authReuseOutput "refresh_token_invalid"
$authLogoutBody = @{ refresh_token = ("browser-logout-token-" + [Guid]::NewGuid().ToString("N")); trace_id = "browser-auth-logout-revoked" } | ConvertTo-Json -Compress
$authLogout = Invoke-JsonApi -Url "$BaseUrl/api/v1/auth/logout" -Method "POST" -Body $authLogoutBody -ContentType "application/json"
Assert-Contains "auth logout status" $authLogout '"status":"logged_out"'
Assert-Contains "auth logout revoked" $authLogout '"refresh_token_revoked":true'
$authAudit = Invoke-Text "$BaseUrl/api/v1/audit/recent?limit=60"
Assert-Contains "auth audit refresh rotated" $authAudit "auth_refresh_rotated"
Assert-Contains "auth audit refresh reuse blocked" $authAudit "auth_refresh_reuse_blocked"
Assert-Contains "auth audit logout revoked" $authAudit "auth_logout_revoked"

Write-Host "[browser-contract] system unavailable fallback contract"
$systemFallbackContract = Invoke-Text "$BaseUrl/api/v1/system/fallback/contract"
Assert-Contains "system fallback version" $systemFallbackContract '"contract_version":"system-unavailable-fallback-v1"'
Assert-Contains "system fallback evidence" $systemFallbackContract '"contract_visible":"system_fallback_contract_visible"'
Assert-Contains "system fallback mode" $systemFallbackContract '"mode":"frontend_error_recovery_contract"'
Assert-Contains "system fallback ui state" $systemFallbackContract '"ui_state":"System Unavailable"'
Assert-Contains "system fallback retry action" $systemFallbackContract '"keep retry button visible"'

Write-Host "[browser-contract] phase3 product surface contracts"
$memoryPurgeContract = Invoke-Text "$BaseUrl/api/v1/memory/purge/contract"
Assert-Contains "memory purge contract version" $memoryPurgeContract '"contract_version":"memory-dsgvo-purge-v1"'
Assert-Contains "memory purge job status endpoint" $memoryPurgeContract 'GET /api/v1/memory/purge/jobs/{job_id}'
Assert-Contains "memory purge evidence visible" $memoryPurgeContract "memory_purge_job_status_visible"
$costExportContract = Invoke-Text "$BaseUrl/api/v1/costs/export/contract"
Assert-Contains "cost export contract version" $costExportContract '"contract_version":"cost-monitor-export-v1"'
Assert-Contains "cost export csv support" $costExportContract '"supported_formats":["csv"]'
Assert-Contains "cost export evidence visible" $costExportContract "cost_export_csv_generated"
$rateLimitContract = Invoke-Text "$BaseUrl/api/v1/rate-limit/contract"
Assert-Contains "rate limit contract version" $rateLimitContract '"contract_version":"rate-limit-guard-v1"'
Assert-Contains "rate limit 429 evidence" $rateLimitContract "rate_limit_429_enforced"
$rateLimitProjectId = "browser-rate-limit-" + [Guid]::NewGuid().ToString("N")
$rateLimitStatus = Invoke-Text "$BaseUrl/api/v1/rate-limit/status?project_id=$rateLimitProjectId"
Assert-Contains "rate limit status contract" $rateLimitStatus '"contract_version":"rate-limit-guard-v1"'
Assert-Contains "rate limit status evidence" $rateLimitStatus '"evidence_ref":"rate_limit_status_visible"'
$sessionLimitContract = Invoke-Text "$BaseUrl/api/v1/session-limits/contract"
Assert-Contains "session limit contract version" $sessionLimitContract '"contract_version":"session-llm-call-limit-v1"'
Assert-Contains "session limit 429 evidence" $sessionLimitContract "session_limit_429_enforced"
$sessionLimitId = "browser-session-limit-" + [Guid]::NewGuid().ToString("N")
$sessionLimitStatus = Invoke-Text "$BaseUrl/api/v1/session-limits/status?session_id=$sessionLimitId"
Assert-Contains "session limit status contract" $sessionLimitStatus '"contract_version":"session-llm-call-limit-v1"'
Assert-Contains "session limit status evidence" $sessionLimitStatus '"evidence_ref":"session_limit_status_visible"'
$errorContract = Invoke-Text "$BaseUrl/api/v1/errors/contract"
Assert-Contains "error contract version" $errorContract '"contract_version":"error-response-contract-v1"'
Assert-Contains "error contract envelope evidence" $errorContract "error_response_envelope_enforced"
$securityHeadersContract = Invoke-Text "$BaseUrl/api/v1/security/headers/contract"
Assert-Contains "security headers contract version" $securityHeadersContract '"contract_version":"security-headers-v1"'
Assert-Contains "security headers evidence" $securityHeadersContract "security_headers_enforced"
Assert-Contains "security csp report endpoint" $securityHeadersContract "POST /api/v1/security/csp/report"
$cspReportContract = Invoke-Text "$BaseUrl/api/v1/security/csp/contract"
Assert-Contains "csp report contract version" $cspReportContract '"contract_version":"csp-report-contract-v1"'
Assert-Contains "csp report evidence" $cspReportContract "csp_report_contract_visible"
Assert-Contains "csp report audit evidence" $cspReportContract "csp_report_audit_persisted"
$securityAuditContract = Invoke-Text "$BaseUrl/api/v1/security/events/contract"
Assert-Contains "security audit contract version" $securityAuditContract '"contract_version":"security-audit-surface-v1"'
Assert-Contains "security audit endpoint" $securityAuditContract "GET /api/v1/security/events"
Assert-Contains "security audit source table" $securityAuditContract "audit_log"
Assert-Contains "security audit surface evidence" $securityAuditContract "security_audit_surface_visible"
Assert-Contains "security audit event evidence" $securityAuditContract "security_audit_event_visible"
Assert-Contains "security audit read only" $securityAuditContract '"read_only":true'
$securityAuditFeed = Invoke-Text "$BaseUrl/api/v1/security/events?limit=5"
Assert-Contains "security audit feed contract" $securityAuditFeed '"contract_version":"security-audit-surface-v1"'
Assert-Contains "security audit feed evidence" $securityAuditFeed "security_audit_surface_visible"
Assert-Contains "security audit feed event evidence" $securityAuditFeed "security_audit_event_visible"

$securityReviewContract = Invoke-Text "$BaseUrl/api/v1/security/review-queue/contract"
Assert-Contains "security review contract version" $securityReviewContract '"contract_version":"security-review-queue-v1"'
Assert-Contains "security review endpoint" $securityReviewContract "GET /api/v1/security/review-queue"
Assert-Contains "security review read only" $securityReviewContract '"read_only":true'
Assert-Contains "security review queue evidence" $securityReviewContract "security_review_queue_visible"
Assert-Contains "security review item evidence" $securityReviewContract "security_review_item_visible"
Assert-Contains "security review redaction evidence" $securityReviewContract "security_review_redaction_enforced"
Assert-Contains "security review mutation evidence" $securityReviewContract "security_review_mutation_blocked"

$securityReviewQueue = Invoke-Text "$BaseUrl/api/v1/security/review-queue?limit=5"
Assert-Contains "security review queue contract" $securityReviewQueue '"contract_version":"security-review-queue-v1"'
Assert-Contains "security review queue evidence" $securityReviewQueue "security_review_queue_visible"
Assert-Contains "security review queue item evidence" $securityReviewQueue "security_review_item_visible"
$traceContract = Invoke-Text "$BaseUrl/api/v1/trace/contract"
Assert-Contains "trace contract version" $traceContract '"contract_version":"trace-id-propagation-v1"'
Assert-Contains "trace contract evidence" $traceContract "trace_id_header_roundtrip"
$cacheControlContract = Invoke-Text "$BaseUrl/api/v1/cache/contract"
Assert-Contains "cache control contract version" $cacheControlContract '"contract_version":"cache-control-no-store-v1"'
Assert-Contains "cache control evidence" $cacheControlContract "cache_control_headers_enforced"
$requestIdContract = Invoke-Text "$BaseUrl/api/v1/request/contract"
Assert-Contains "request id contract version" $requestIdContract '"contract_version":"request-id-correlation-v1"'
Assert-Contains "request id evidence" $requestIdContract "request_id_audit_correlation"
$agentActivityContract = Invoke-Text "$BaseUrl/api/v1/agent-activity/contract"
Assert-Contains "agent activity contract version" $agentActivityContract '"contract_version":"agent-activity-trace-v1"'
Assert-Contains "agent activity filtered feed evidence" $agentActivityContract "agent_activity_filtered_feed_visible"
$agentActivityFeed = Invoke-Text "$BaseUrl/api/v1/agent-activity/recent?limit=5&severity=info"
Assert-Contains "agent activity feed contract" $agentActivityFeed '"contract_version":"agent-activity-trace-v1"'
Assert-Contains "agent activity feed mode" $agentActivityFeed '"mode":"audit_log_backed_filtered_feed"'

Write-Host "[browser-contract] langfuse trace access"
$langfuseTraceContract = Invoke-Text "$BaseUrl/api/v1/observability/langfuse/contract"
Assert-Contains "langfuse trace contract version" $langfuseTraceContract '"contract_version":"langfuse-trace-access-v1"'
Assert-Contains "langfuse trace endpoint" $langfuseTraceContract "GET /api/v1/observability/langfuse/trace/{trace_id}"
Assert-Contains "langfuse trace source" $langfuseTraceContract "audit_log"
Assert-Contains "langfuse trace evidence" $langfuseTraceContract "langfuse_trace_access_visible"
Assert-Contains "langfuse trace event evidence" $langfuseTraceContract "langfuse_trace_event_visible"
Assert-Contains "langfuse trace read only" $langfuseTraceContract '"read_only":true'
Assert-Contains "langfuse trace provider export false" $langfuseTraceContract '"provider_trace_export":false'

Write-Host "[browser-contract] llm audit feed"
$llmAuditContract = Invoke-Text "$BaseUrl/api/v1/audit/llm/contract"
Assert-Contains "llm audit contract version" $llmAuditContract '"contract_version":"llm-audit-feed-v1"'
Assert-Contains "llm audit endpoint" $llmAuditContract "GET /api/v1/audit/llm"
Assert-Contains "llm audit source" $llmAuditContract "llm_gateway_request"
Assert-Contains "llm audit evidence" $llmAuditContract "llm_audit_feed_visible"
Assert-Contains "llm audit event evidence" $llmAuditContract "llm_audit_feed_event_visible"
$llmAuditFeed = Invoke-Text "$BaseUrl/api/v1/audit/llm?limit=5"
Assert-Contains "llm audit feed contract" $llmAuditFeed '"contract_version":"llm-audit-feed-v1"'
Assert-Contains "llm audit feed source" $llmAuditFeed '"source_event_type":"llm_gateway_request"'
Assert-Contains "llm audit feed evidence" $llmAuditFeed "llm_audit_feed_visible"

Write-Host "[browser-contract] task assignment queue contract"
$taskAssignmentContract = Invoke-Text "$BaseUrl/api/v1/tasks/assignment-contract"
Assert-Contains "task assignment contract version" $taskAssignmentContract '"contract_version":"task-assignment-queue-contract-v1"'
Assert-Contains "task assignment evidence" $taskAssignmentContract '"evidence_ref":"task_assignment_queue_contract_visible"'
Assert-Contains "task assignment gap" $taskAssignmentContract '"audit_gap":"L-06"'
Assert-Contains "task assignment queue key" $taskAssignmentContract '"queue_key":"tasks:agent:queue"'
Assert-Contains "task assignment high priority queue" $taskAssignmentContract '"high":"tasks:agent:queue:high"'
Assert-Contains "task assignment low priority queue" $taskAssignmentContract '"low":"tasks:agent:queue:low"'
Assert-Contains "task assignment priority order" $taskAssignmentContract '"priority_order":["high","mid","low"]'
Assert-Contains "task assignment priority consumption" $taskAssignmentContract "high before mid before low"
Assert-Contains "task assignment status key" $taskAssignmentContract '"status_key_pattern":"task:status:{task_id}"'
Assert-Contains "task assignment backpressure" $taskAssignmentContract "stale_queue_rescue"

Write-Host "[browser-contract] agent llm streaming contract"
$agentLlmStreamingContract = Invoke-Text "$BaseUrl/api/v1/agents/llm-streaming-contract"
Assert-Contains "agent llm streaming version" $agentLlmStreamingContract '"contract_version":"agent-llm-streaming-contract-v1"'
Assert-Contains "agent llm streaming evidence" $agentLlmStreamingContract '"evidence_ref":"agent_llm_streaming_contract_visible"'
Assert-Contains "agent llm streaming gap" $agentLlmStreamingContract '"audit_gap":"L-07"'
Assert-Contains "agent llm streaming protocol" $agentLlmStreamingContract "openai_compatible_sse"
Assert-Contains "agent llm streaming done" $agentLlmStreamingContract "data: [DONE]"
Assert-Contains "agent llm streaming parser" $agentLlmStreamingContract "parse_llm_gateway_sse_line"
Assert-Contains "agent llm streaming state" $agentLlmStreamingContract "stream_done_seen"
Assert-Contains "agent llm streaming no live" $agentLlmStreamingContract "No live provider stream"

Write-Host "[browser-contract] mcp version pinning contract"
$mcpVersionPinningContract = Invoke-Text "$BaseUrl/mcp/api/v1/version-pinning/contract"
Assert-Contains "mcp version pinning contract version" $mcpVersionPinningContract '"contract_version":"mcp-version-pinning-v1"'
Assert-Contains "mcp version pinning evidence" $mcpVersionPinningContract '"evidence_ref":"mcp_version_pinning_contract_visible"'
Assert-Contains "mcp version pinning gap" $mcpVersionPinningContract '"audit_gap":"L-08"'
Assert-Contains "mcp version pinning fastapi" $mcpVersionPinningContract "fastapi==0.115.8"
Assert-Contains "mcp version pinning uvicorn" $mcpVersionPinningContract "uvicorn[standard]==0.34.0"
Assert-Contains "mcp version pinning pydantic" $mcpVersionPinningContract "pydantic==2.10.6"
Assert-Contains "mcp version pinning github contract" $mcpVersionPinningContract "github-branch-pr-plan-v1"
Assert-Contains "mcp version pinning e2b contract" $mcpVersionPinningContract "e2b-sandbox-lifecycle-v1"
Assert-Contains "mcp version pinning drift policy" $mcpVersionPinningContract "exact == pinning"
Assert-Contains "mcp version pinning no live write" $mcpVersionPinningContract "No live MCP write"

Write-Host "[browser-contract] memory embedding consistency contract"
$memoryEmbeddingConsistencyContract = Invoke-Text "$BaseUrl/api/v1/memory/embedding-consistency/contract"
Assert-Contains "memory embedding consistency version" $memoryEmbeddingConsistencyContract '"contract_version":"memory-embedding-consistency-v1"'
Assert-Contains "memory embedding consistency status" $memoryEmbeddingConsistencyContract '"status":"verified"'
Assert-Contains "memory embedding consistency evidence" $memoryEmbeddingConsistencyContract '"evidence_ref":"memory_embedding_consistency_contract_visible"'
Assert-Contains "memory embedding consistency gap" $memoryEmbeddingConsistencyContract '"audit_gap":"L-09"'
Assert-Contains "memory embedding consistency column" $memoryEmbeddingConsistencyContract '"embedding_model_version"'
Assert-Contains "memory embedding consistency vector" $memoryEmbeddingConsistencyContract "vector(1536)"
Assert-Contains "memory embedding consistency fallback" $memoryEmbeddingConsistencyContract "lexical_fallback"
Assert-Contains "memory embedding consistency no live provider" $memoryEmbeddingConsistencyContract "No live embedding provider call"

Write-Host "[browser-contract] phase2 runtime contract"
$runtimeContract = Invoke-Text "$BaseUrl/api/v1/phase2/runtime/contract"
Assert-Contains "runtime contract version" $runtimeContract '"contract_version":"phase2-runtime-v1"'
Assert-Contains "runtime start endpoint" $runtimeContract "POST /api/v1/phase2/runtime/start"
Assert-Contains "runtime stream endpoint" $runtimeContract "POST /api/v1/orchestrator/dry-run/stream"
Assert-Contains "runtime runs endpoint" $runtimeContract "GET /api/v1/phase2/runtime/runs"
Assert-Contains "runtime sse contract" $runtimeContract "phase2-sse-event-contract-v1"
Assert-Contains "runtime sse evidence" $runtimeContract "phase2_sse_event_contract_proof"
Assert-Contains "runtime sse heartbeat event" $runtimeContract "heartbeat"
Assert-Contains "runtime sse agent status event" $runtimeContract "agent_status"
Assert-Contains "runtime sse error event" $runtimeContract "error"
Assert-Contains "runtime sse done event" $runtimeContract "done"
Assert-Contains "runtime mcp timeout evidence" $runtimeContract "langgraph_mcp_timeout_controlled"
Assert-Contains "runtime no live provider calls" $runtimeContract '"live_provider_calls":false'
Assert-Contains "runtime postgres checkpointing" $runtimeContract '"checkpointing":"postgres"'

Write-Host "[browser-contract] external gate mirror"
$externalGates = Invoke-Text "$BaseUrl/api/v1/external-gates"
Assert-Contains "external gates contract" $externalGates '"contract_version":"external-gates-state-v1"'
Assert-Contains "external gates endpoint" $externalGates '"endpoint":"GET /api/v1/external-gates"'
Assert-Contains "external gates evidence" $externalGates '"evidence_ref":"external_gates_state_visible"'
Assert-Contains "external gates aligned with preflight" $externalGates '"aligned_with_deployment_preflight":true'
Assert-Contains "external gates blocked ghcr" $externalGates '"ghcr_images"'
Assert-Contains "external gates blocked hosted origins" $externalGates '"hosted_backend_origins"'
Assert-Contains "external gates branch alias" $externalGates '"preflight_gate_id":"branch_protection"'
Assert-Contains "external gates evidence alias" $externalGates '"evidence_ref":"ghcr_image_digest_proof"'
$externalGateMirror = Invoke-Text "$BaseUrl/api/v1/external-gates/mirror"
Assert-Contains "external gate mirror contract" $externalGateMirror '"contract_version":"external-gate-mirror-v1"'
Assert-Contains "external gate mirror status" $externalGateMirror '"status":"verified"'
Assert-Contains "external gate mirror evidence" $externalGateMirror '"evidence_ref":"external_gate_mirror_proof"'
Assert-Contains "external gate mirror hosted allowed" $externalGateMirror '"hosted_staging_claim_allowed":true'
Assert-Contains "external gate mirror branch protection allowed" $externalGateMirror '"branch_protection_claim_allowed":true'
Assert-Contains "external gate mirror branch protection evidence" $externalGateMirror '"branch_protection_evidence_ref":"branch_protection_verify_contract"'
Assert-Contains "external gate mirror branch protection workflow" $externalGateMirror ".github/workflows/branch-protection.yml"
Assert-Contains "external gate mirror branch protection verifier" $externalGateMirror "scripts/apply_github_branch_protection.py --verify-only"
Assert-Contains "external gate mirror production allowed" $externalGateMirror '"production_deploy_claim_allowed":true'
Assert-Contains "external gate mirror sse contract" $externalGateMirror "phase2-sse-event-contract-v1"
Assert-Contains "external gate mirror project progress proof" $externalGateMirror "project_progress_manifest_proof"

Write-Host "[browser-contract] phase2 runtime start"
$phase2RuntimeThreadId = "browser-contract-phase2-runtime-" + [Guid]::NewGuid().ToString("N")
$phase2RuntimeBody = @{
  project_id = "browser-contract-project"
  prompt = "browser contract phase2 runtime button proof"
  session_id = $phase2RuntimeThreadId
} | ConvertTo-Json -Compress
$phase2RuntimeRun = (Invoke-JsonApi -Url "$BaseUrl/api/v1/phase2/runtime/start" -Method "POST" -Body $phase2RuntimeBody -ContentType "application/json" -TimeoutSeconds 120) | ConvertFrom-Json
Assert-True "phase2 runtime status started" ($phase2RuntimeRun.status -eq "started")
Assert-True "phase2 runtime contract version" ($phase2RuntimeRun.contract_version -eq "phase2-runtime-v1")
Assert-True "phase2 runtime engine langgraph" ($phase2RuntimeRun.engine -eq "langgraph")
Assert-True "phase2 runtime no live provider calls" ($phase2RuntimeRun.live_provider_calls -eq $false)
Assert-True "phase2 runtime postgres checkpointing" ($phase2RuntimeRun.checkpointing -eq "postgres")
Assert-True "phase2 runtime completed node" ($phase2RuntimeRun.state.node_name -eq "completed")
Assert-True "phase2 runtime evidence ref" ($phase2RuntimeRun.state.evidence_refs -contains "phase2_runtime_graph_started")
$expectedAgentRoles = @("planner", "coder", "tester", "devops")
$runtimeAssignments = @($phase2RuntimeRun.state.task_assignments)
$runtimeAgentResults = @($phase2RuntimeRun.state.agent_results)
$runtimeMcpCalls = @($phase2RuntimeRun.state.mcp_tool_calls)
$runtimeLlmCalls = @($phase2RuntimeRun.state.llm_gateway_calls)
$runtimePerRoleResults = @($phase2RuntimeRun.state.result.per_role_results)
Assert-True "phase2 runtime assignment count" ($runtimeAssignments.Count -ge 4)
Assert-True "phase2 runtime agent result count" ($runtimeAgentResults.Count -ge 4)
Assert-True "phase2 runtime mcp call count" ($runtimeMcpCalls.Count -ge 4)
Assert-True "phase2 runtime llm call count" ($runtimeLlmCalls.Count -ge 4)
Assert-True "phase2 runtime per-role result count" ($runtimePerRoleResults.Count -ge 4)
Assert-True "phase2 runtime aggregation complete" ($phase2RuntimeRun.state.result.partial_failure -eq $false)
Assert-True "phase2 runtime aggregation evidence" ($phase2RuntimeRun.state.result.verification_evidence -contains "agent_result_aggregation_complete")
foreach ($role in $expectedAgentRoles) {
  $assignment = $runtimeAssignments | Where-Object { $_.agent_type -eq $role } | Select-Object -First 1
  Assert-True "phase2 runtime assignment for $role" ($null -ne $assignment)
  Assert-True "phase2 runtime assignment completed for $role" ($assignment.status -eq "completed")
  Assert-True "phase2 runtime done validation logged for $role" ($assignment.done_validation.logged -eq $true)
  Assert-True "phase2 runtime push_main block for $role" ($assignment.blocked_actions -contains "push_main")
  $agentResult = $runtimeAgentResults | Where-Object { $_.owner_role -eq $role } | Select-Object -First 1
  Assert-True "phase2 runtime agent result for $role" ($null -ne $agentResult)
  Assert-True "phase2 runtime role evidence for $role" ($agentResult.verification_evidence -contains "agent_role_$($role)_executed")
  $mcpCall = $runtimeMcpCalls | Where-Object { $_.agent_role -eq $role } | Select-Object -First 1
  Assert-True "phase2 runtime mcp call for $role" ($null -ne $mcpCall)
  Assert-True "phase2 runtime mcp success for $role" ($mcpCall.status -eq "success")
  $roleSummary = $runtimePerRoleResults | Where-Object { $_.role -eq $role } | Select-Object -First 1
  Assert-True "phase2 runtime per-role summary for $role" ($null -ne $roleSummary)
  Assert-True "phase2 runtime per-role summary completed for $role" ($roleSummary.status -eq "completed")
  Assert-True "phase2 runtime per-role mcp success for $role" ($roleSummary.mcp_status -eq "success")
  Assert-True "phase2 runtime per-role evidence for $role" ($roleSummary.mcp_evidence_ref)
}
$runtimeCheckpoint = Invoke-Text "$BaseUrl/api/v1/orchestrator/checkpoints/$($phase2RuntimeRun.thread_id)"
Assert-Contains "phase2 runtime checkpoint evidence" $runtimeCheckpoint "phase2_runtime_graph_started"
$runtimeAudit = Invoke-Text "$BaseUrl/api/v1/audit/recent?limit=60"
Assert-Contains "phase2 runtime audit evidence" $runtimeAudit "phase2_runtime_graph_started"
Assert-Contains "phase2 runtime audit contract" $runtimeAudit "phase2-runtime-v1"
$agentActivityRecent = (Invoke-JsonApi -Url "$BaseUrl/api/v1/agent-activity/recent?event_type=phase2_runtime_graph_started&limit=20" -Method "GET" -ContentType "" -TimeoutSeconds 30) | ConvertFrom-Json
$agentActivityRuntimeEvent = @($agentActivityRecent.events) | Where-Object { $_.trace_id -eq $phase2RuntimeRun.thread_id -or $_.session_id -eq $phase2RuntimeRun.thread_id } | Select-Object -First 1
Assert-True "agent activity runtime event visible" ($null -ne $agentActivityRuntimeEvent)
Assert-True "agent activity per-role count visible" ($agentActivityRuntimeEvent.role_summary_count -ge 4)
Assert-True "agent activity partial failure false" ($agentActivityRuntimeEvent.partial_failure -eq $false)
Assert-True "agent activity aggregation evidence visible" ($agentActivityRuntimeEvent.aggregation_evidence_ref -eq "agent_result_aggregation_complete")
foreach ($role in $expectedAgentRoles) {
  $activityRoleSummary = @($agentActivityRuntimeEvent.per_role_results) | Where-Object { $_.role -eq $role } | Select-Object -First 1
  Assert-True "agent activity per-role summary for $role" ($null -ne $activityRoleSummary)
  Assert-True "agent activity per-role completed for $role" ($activityRoleSummary.status -eq "completed")
}
$phase2RuntimeRuns = (Invoke-JsonApi -Url "$BaseUrl/api/v1/phase2/runtime/runs?limit=10" -Method "GET" -ContentType "" -TimeoutSeconds 30) | ConvertFrom-Json
Assert-True "phase2 runtime runs contract version" ($phase2RuntimeRuns.contract_version -eq "phase2-runtime-v1")
Assert-True "phase2 runtime runs evidence ref" ($phase2RuntimeRuns.evidence_ref -eq "phase2_runtime_run_status_visible")
$phase2RuntimeRunStatus = @($phase2RuntimeRuns.runs) | Where-Object { $_.thread_id -eq $phase2RuntimeRun.thread_id -or $_.session_id -eq $phase2RuntimeRun.thread_id } | Select-Object -First 1
Assert-True "phase2 runtime run status visible" ($null -ne $phase2RuntimeRunStatus)
Assert-True "phase2 runtime run status completed" ($phase2RuntimeRunStatus.status -eq "completed")
Assert-True "phase2 runtime run status role summaries" ($phase2RuntimeRunStatus.role_summary_count -ge 4)
Assert-True "phase2 runtime run status aggregation evidence" ($phase2RuntimeRunStatus.aggregation_evidence_ref -eq "agent_result_aggregation_complete")
Assert-True "phase2 runtime run status no live provider calls" ($phase2RuntimeRunStatus.live_provider_calls -eq $false)
Assert-True "phase2 runtime run status no live mcp writes" ($phase2RuntimeRunStatus.live_mcp_writes -eq $false)
Assert-True "phase2 runtime run status no production deploy" ($phase2RuntimeRunStatus.production_deploy -eq $false)

Write-Host "[browser-contract] session history opens"
$sessionHistory = (Invoke-JsonApi -Url "$BaseUrl/api/v1/sessions/$($phase2RuntimeRun.thread_id)/history" -Method "GET" -ContentType "" -TimeoutSeconds 30) | ConvertFrom-Json
Assert-True "session history contract version" ($sessionHistory.contract_version -eq "session-history-v1")
Assert-True "session history evidence ref" ($sessionHistory.evidence_ref -eq "session_history_openable_project_state")
Assert-True "session history session id" ($sessionHistory.session.session_id -eq $phase2RuntimeRun.thread_id)
Assert-True "session history messages visible" (@($sessionHistory.messages).Count -ge 4)
Assert-True "session history tasks visible" (@($sessionHistory.tasks).Count -ge 4)
Assert-True "session history audit events visible" (@($sessionHistory.audit_events).Count -ge 4)
Assert-True "session history project progress visible" ($sessionHistory.project_progress.overall_percent -eq $expectedOverallPercent)
Assert-True "session history integrity verified" ($sessionHistory.project_progress_integrity.status -eq "verified")
Assert-True "session history integrity evidence" ($sessionHistory.project_progress_integrity.evidence_ref -eq "project_progress_integrity_runtime_proof")

if ($SeedMemoryConsolidation) {
  Write-Host "[browser-contract] seed memory consolidation"
  $memoryNeedle = "browser contract memory consolidation " + [Guid]::NewGuid().ToString("N")
  $memoryIdempotencyKey = "browser-contract-memory-consolidation-" + [Guid]::NewGuid().ToString("N")
  $seedOutput = docker exec cloud-superbrain-phase1-dev-agent-api-1 python -c "import json, os, redis; client=redis.Redis.from_url(os.environ['REDIS_URL']); payload={'project_id':'browser-contract-project','session_id':'$($phase2RuntimeRun.thread_id)','content_text':'$memoryNeedle','metadata':{'source':'browser_contract_harness'},'idempotency_key':'$memoryIdempotencyKey'}; client.set('memory:working:$memoryIdempotencyKey', json.dumps(payload), ex=300); print(client.ttl('memory:working:$memoryIdempotencyKey'))"
  Assert-Contains "seeded working memory ttl" $seedOutput "300"
  $consolidationRun = docker exec cloud-superbrain-phase1-dev-memory-worker-1 python -m app.worker --once
  if (-not (($consolidationRun | Out-String).Contains('"consolidated": 1'))) {
    Write-Host "[browser-contract] memory-worker one-shot did not claim the key; checking public feed because daemon may have consumed it first"
  }
  $consolidationFeed = Invoke-Text "$BaseUrl/api/v1/memory/consolidation/recent?limit=20"
  Assert-Contains "memory consolidation feed event" $consolidationFeed "memory_consolidated"
  Assert-Contains "memory consolidation feed idempotency" $consolidationFeed $memoryIdempotencyKey
  Assert-Contains "memory consolidation feed redis key" $consolidationFeed "memory:working:$memoryIdempotencyKey"
} else {
  Write-Host "[browser-contract] memory consolidation feed shape"
  $consolidationFeed = Invoke-Text "$BaseUrl/api/v1/memory/consolidation/recent?limit=8"
  Assert-Contains "memory consolidation feed shape" $consolidationFeed '"events"'
  Assert-Contains "memory consolidation summary shape" $consolidationFeed '"summary"'
}

Write-Host "[browser-contract] checks completed"

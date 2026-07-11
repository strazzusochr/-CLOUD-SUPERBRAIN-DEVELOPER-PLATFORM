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
  $normalizedText = ($text -replace '\s+', ' ').Trim()
  $normalizedExpected = (($expected | Out-String) -replace '\s+', ' ').Trim()
  if (-not $normalizedText.Contains($normalizedExpected)) {
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

sys.stdout.reconfigure(encoding="utf-8")
url = sys.argv[1]
with urllib.request.urlopen(url, timeout=30) as response:
    sys.stdout.write(response.read().decode("utf-8", errors="replace"))
'@
  $env:PYTHONIOENCODING = "utf-8"
  return ($python | py -3 -X utf8 - $url)
}

function Invoke-StatusCode($url) {
  $python = @'
import sys
import urllib.error
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")
url = sys.argv[1]
try:
    with urllib.request.urlopen(url, timeout=30) as response:
        sys.stdout.write(str(response.status))
except urllib.error.HTTPError as error:
    sys.stdout.write(str(error.code))
'@
  $env:PYTHONIOENCODING = "utf-8"
  return ($python | py -3 -X utf8 - $url)
}

function Remove-TempFileWithRetry([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    return
  }
  for ($attempt = 1; $attempt -le 5; $attempt += 1) {
    try {
      Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
      return
    } catch {
      if ($attempt -eq 5) {
        Write-Warning "Could not remove temporary verifier file: $Path"
        return
      }
      Start-Sleep -Milliseconds (100 * $attempt)
    }
  }
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

sys.stdout.reconfigure(encoding="utf-8")
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
    $env:PYTHONIOENCODING = "utf-8"
    $output = py -3 -X utf8 $pythonFile $payloadFile 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
      throw $output.Trim()
    }
    return $output
  } finally {
    Remove-TempFileWithRetry $payloadFile
    Remove-TempFileWithRetry $pythonFile
  }
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
$isLocalProof = $BaseUrl -match "localhost|127\.0\.0\.1|\[::1\]"
if ((-not $AllowLocalhost) -and $isLocalProof) {
  throw "Browser contract proof refuses localhost unless -AllowLocalhost is set"
}

Write-Host "[browser-contract] base url: $BaseUrl"

Write-Host "[browser-contract] frontend markers"
$landingHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "landing title" $landingHtml "Cloud Superbrain"
Assert-Contains "landing open workbench" $landingHtml "Open Workbench"
Assert-Contains "landing canonical spec marker" $landingHtml "Canonical platform specification"
$homeHtml = Invoke-Text "$BaseUrl/home"
Assert-Contains "home product marker" $homeHtml "Developer Platform"
Assert-Contains "home evidence wiring marker" $homeHtml "Evidence"
Assert-Contains "home diagnostics wiring marker" $homeHtml "Diagnostics"
Assert-True "home does not surface recent projects" (-not $homeHtml.Contains("Letzte Projekte"))
Assert-True "home does not surface project workspace status" (-not $homeHtml.Contains("Projektstand"))
$workbenchHtml = Invoke-Text "$BaseUrl/workbench"
Assert-Contains "workbench studio marker" $workbenchHtml "workbench-studio"
Assert-Contains "workbench explorer marker" $workbenchHtml "Explorer"
Assert-Contains "workbench preview marker" $workbenchHtml "Vorschau"
Assert-Contains "workbench build log marker" $workbenchHtml "Build-Log"
Assert-True "workbench does not surface session list" (-not $workbenchHtml.Contains("Sessions"))
Assert-True "workbench does not surface completion gate" (-not $workbenchHtml.Contains("Completion-Gate"))
Assert-True "workbench does not surface workspace status wall" (-not $workbenchHtml.Contains("Workspace-Surfaces"))
Assert-True "workbench budget hidden without paid option" (-not $workbenchHtml.Contains("Metered Budget"))
$workbenchPaidHtml = Invoke-Text "$BaseUrl/workbench?capability=paid_llm"
Assert-True "workbench budget remains hidden when no paid option exists" (-not $workbenchPaidHtml.Contains("Metered Budget"))
Assert-True "workbench paid capability marker remains hidden when no paid option exists" (-not $workbenchPaidHtml.Contains("paid/metered Capability"))

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
$projectProgressCompletionJson = $projectProgressCompletion | ConvertFrom-Json
$projectProgressCompletionMissingGates = @($projectProgressCompletionJson.missing_external_gates | ForEach-Object { [string]$_ })
Assert-True "project progress completion missing fly gate" ($projectProgressCompletionMissingGates -contains "fly_api_token")
Assert-Contains "project progress completion fly blocker" $projectProgressCompletion "live_infra_budget_refresh_requires_FLY_API_TOKEN"
if ($isLocalProof) {
  Assert-True "project progress completion missing local vercel backend origins gate" ($projectProgressCompletionMissingGates -contains "vercel_backend_origins")
  Assert-Contains "project progress completion local vercel origins blocker" $projectProgressCompletion "vercel_backend_origins"
} else {
  Assert-True "project progress completion hosted vercel backend origins gate closed" (-not ($projectProgressCompletionMissingGates -contains "vercel_backend_origins"))
}
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
Assert-Contains "cloud provider Fly.io" $cloudProviderInventory '"id":"fly_io"'
Assert-Contains "cloud provider grafana" $cloudProviderInventory '"id":"grafana_cloud"'
Assert-Contains "cloud provider seven layer mapping" $cloudProviderInventory '"seven_layer_mapping"'
$cloudLayerReadiness = Invoke-Text "$BaseUrl/api/v1/clouds/layers"
Assert-Contains "cloud layer readiness contract version" $cloudLayerReadiness '"contract_version":"cloud-layer-readiness-v1"'
Assert-Contains "cloud layer readiness evidence" $cloudLayerReadiness '"evidence_ref":"cloud_layer_readiness_visible"'
Assert-Contains "cloud layer readiness layer 7" $cloudLayerReadiness '"layer_id":"layer_7"'
Assert-Contains "cloud layer readiness grafana" $cloudLayerReadiness 'grafana_cloud'
$platformVerify = Invoke-Text "$BaseUrl/api/v1/platform/verify"
Assert-Contains "platform verify contract version" $platformVerify '"contract_version":"platform-verify-readiness-v1"'
Assert-Contains "platform verify source" $platformVerify '"source":"agent-api"'
Assert-Contains "platform verify endpoint" $platformVerify '"/api/v1/platform/verify"'
Assert-Contains "platform verify total" $platformVerify '"total":7'
Assert-Contains "platform verify dev-only non claim" $platformVerify "Localhost remains DEV-ONLY"
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
Assert-Contains "cloud deployment preflight status" $cloudDeploymentPreflightRuntime '"status":"action_required"'
Assert-Contains "cloud deployment preflight cloud claim blocked" $cloudDeploymentPreflightRuntime '"cloud_deploy_claim_allowed":false'
Assert-Contains "cloud deployment preflight production blocked" $cloudDeploymentPreflightRuntime '"production_deploy_claim_allowed":false'
$cloudDeploymentPreflightRuntimeJson = $cloudDeploymentPreflightRuntime | ConvertFrom-Json
$cloudDeploymentPreflightBlockedGates = @($cloudDeploymentPreflightRuntimeJson.missing_or_blocked_gates | ForEach-Object { [string]$_ })
Assert-True "cloud deployment preflight missing fly cloud stack" ($cloudDeploymentPreflightBlockedGates -contains "fly_cloud_stack")
Assert-True "cloud deployment preflight missing hosted backend origins gate" ($cloudDeploymentPreflightBlockedGates -contains "hosted_backend_origins")
Assert-Contains "cloud deployment preflight ghcr sequence" $cloudDeploymentPreflightRuntime "publish_ghcr_images"
Assert-Contains "cloud deployment preflight hosted origins" $cloudDeploymentPreflightRuntime "hosted_backend_origins"
Assert-Contains "cloud deployment preflight branch token" $cloudDeploymentPreflightRuntime "BRANCH_PROTECTION_TOKEN"
Assert-Contains "cloud deployment preflight cloud compose" $cloudDeploymentPreflightRuntime "docker-compose.cloud.yml"
Assert-Contains "cloud deployment preflight owner review" $cloudDeploymentPreflightRuntime "owner_review_before_production"

Write-Host "[browser-contract] go-live readiness"
$goLiveReadinessContract = Invoke-Text "$BaseUrl/api/v1/clouds/go-live-readiness/contract"
Assert-Contains "go-live readiness contract version" $goLiveReadinessContract '"contract_version":"go-live-readiness-surface-v1"'
Assert-Contains "go-live readiness runtime endpoint" $goLiveReadinessContract '"runtime_endpoint":"GET /api/v1/clouds/go-live-readiness"'
Assert-Contains "go-live readiness external verifier" $goLiveReadinessContract "scripts/verify-external-gates.ps1"
$goLiveReadinessRuntime = Invoke-Text "$BaseUrl/api/v1/clouds/go-live-readiness"
Assert-Contains "go-live readiness runtime version" $goLiveReadinessRuntime '"contract_version":"go-live-readiness-v1"'
Assert-Contains "go-live readiness evidence" $goLiveReadinessRuntime '"evidence_ref":"go_live_readiness_contract_visible"'
Assert-Contains "go-live readiness workspace count" $goLiveReadinessRuntime '"workspace_page_count":22'
Assert-Contains "go-live readiness cloud layers" $goLiveReadinessRuntime '"cloud_layer_total_count":7'
if ($AllowLocalhost) {
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-go-live-readiness.ps1 -BaseUrl $BaseUrl -AllowLocalhost
} else {
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-go-live-readiness.ps1 -BaseUrl $BaseUrl
}
if ($LASTEXITCODE -ne 0) {
  throw "Browser contract verification failed: go-live readiness verifier"
}

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
if ($isLocalProof) {
  Assert-Contains "agent activity feed contract" $agentActivityFeed '"contract_version":"agent-activity-trace-v1"'
  Assert-Contains "agent activity feed mode" $agentActivityFeed '"mode":"audit_log_backed_filtered_feed"'
} else {
  Assert-Contains "hosted agent activity projection contract" $agentActivityFeed '"contract_version":"agent-activity-github-audit-projection-v1"'
  Assert-Contains "hosted agent activity projection source" $agentActivityFeed '"source":"github-store"'
  Assert-Contains "hosted agent activity projection read-only" $agentActivityFeed '"read_only":true'
  Assert-Contains "hosted agent activity projection non-live" $agentActivityFeed '"live_backend":false'
}

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

Write-Host "[browser-contract] llm responses adapter contract"
$llmResponsesContract = Invoke-Text "$BaseUrl/llm/api/v1/responses/contract"
Assert-Contains "llm responses adapter version" $llmResponsesContract '"contract_version":"llm-responses-adapter-contract-v1"'
Assert-Contains "llm responses adapter evidence" $llmResponsesContract '"evidence_ref":"llm_responses_adapter_contract_visible"'
Assert-Contains "llm responses adapter runtime endpoint" $llmResponsesContract "POST /llm/v1/responses"
& (Join-Path $PSScriptRoot "verify-llm-responses-contract.ps1") -BaseUrl $BaseUrl -AllowLocalhost:$AllowLocalhost

Write-Host "[browser-contract] live agent steering contract"
$liveAgentSteeringContract = Invoke-Text "$BaseUrl/api/v1/live-agents/contract"
Assert-Contains "live agent steering version" $liveAgentSteeringContract '"contract_version":"live-agent-steering-v1"'
Assert-Contains "live agent steering evidence" $liveAgentSteeringContract "live_agent_steering_contract_visible"
Assert-Contains "live agent steering llm adapter" $liveAgentSteeringContract "llm-responses-adapter-contract-v1"
Assert-Contains "live agent steering response no-live" $liveAgentSteeringContract "live_provider_calls"
Assert-Contains "live agent steering response audit" $liveAgentSteeringContract "audit_persisted"
if ($isLocalProof) {
  & (Join-Path $PSScriptRoot "verify-live-agent-steering-contract.ps1") -BaseUrl $BaseUrl -AllowLocalhost:$AllowLocalhost
} else {
  $hostedLiveAgentStatus = Invoke-Text "$BaseUrl/api/v1/live-agents/status"
  Assert-Contains "hosted live agent status degraded" $hostedLiveAgentStatus '"status":"degraded"'
  Assert-Contains "hosted live agent status non-live" $hostedLiveAgentStatus '"live_backend":false'
  Assert-Contains "hosted live agent status empty" $hostedLiveAgentStatus '"agents":[]'
  Assert-Contains "hosted live agent owner precondition" $hostedLiveAgentStatus "Fly runtime approval or a separately approved Neon/Upstash architecture expansion"
}

Write-Host "[browser-contract] mcp version pinning contract"
$mcpVersionPinningContract = Invoke-Text "$BaseUrl/mcp/api/v1/version-pinning/contract"
Assert-Contains "mcp version pinning contract version" $mcpVersionPinningContract '"contract_version":"mcp-version-pinning-v1"'
Assert-Contains "mcp version pinning evidence" $mcpVersionPinningContract '"evidence_ref":"mcp_version_pinning_contract_visible"'
Assert-Contains "mcp version pinning gap" $mcpVersionPinningContract '"audit_gap":"L-08"'
Assert-Contains "mcp version pinning fastapi" $mcpVersionPinningContract "fastapi==0.136.3"
Assert-Contains "mcp version pinning uvicorn" $mcpVersionPinningContract "uvicorn[standard]==0.49.0"
Assert-Contains "mcp version pinning pydantic" $mcpVersionPinningContract "pydantic==2.13.4"
Assert-Contains "mcp version pinning github contract" $mcpVersionPinningContract "github-branch-pr-plan-v1"
Assert-Contains "mcp version pinning e2b contract" $mcpVersionPinningContract "e2b-sandbox-lifecycle-v1"
Assert-Contains "mcp version pinning drift policy" $mcpVersionPinningContract "exact == pinning"
Assert-Contains "mcp version pinning no live write" $mcpVersionPinningContract "No live MCP write"

Write-Host "[browser-contract] memory embedding consistency contract"
$memoryEmbeddingConsistencyContract = Invoke-Text "$BaseUrl/api/v1/memory/embedding-consistency/contract"
Assert-Contains "memory embedding consistency version" $memoryEmbeddingConsistencyContract '"contract_version":"memory-embedding-consistency-v1"'
if ($isLocalProof) {
  Assert-Contains "memory embedding consistency status" $memoryEmbeddingConsistencyContract '"status":"verified"'
  Assert-Contains "memory embedding consistency gap" $memoryEmbeddingConsistencyContract '"audit_gap":"L-09"'
  Assert-Contains "memory embedding consistency column" $memoryEmbeddingConsistencyContract '"embedding_model_version"'
  Assert-Contains "memory embedding consistency vector" $memoryEmbeddingConsistencyContract "vector(1536)"
  Assert-Contains "memory embedding consistency fallback" $memoryEmbeddingConsistencyContract "lexical_fallback"
  Assert-Contains "memory embedding consistency no live provider" $memoryEmbeddingConsistencyContract "No live embedding provider call"
} else {
  Assert-Contains "hosted memory embedding consistency verified" $memoryEmbeddingConsistencyContract '"status":"verified"'
  Assert-Contains "hosted memory embedding model" $memoryEmbeddingConsistencyContract '"model_version":"@cf/baai/bge-base-en-v1.5"'
  Assert-Contains "hosted memory embedding dimensions" $memoryEmbeddingConsistencyContract '"dimensions":768'
  Assert-Contains "hosted memory embedding vector" $memoryEmbeddingConsistencyContract "vector(768)"
  Assert-Contains "hosted memory semantic search" $memoryEmbeddingConsistencyContract '"search_mode":"semantic_cosine"'
  Assert-Contains "hosted memory contract no provider call" $memoryEmbeddingConsistencyContract "This GET contract does not call Workers AI"
}
Assert-Contains "memory embedding consistency evidence" $memoryEmbeddingConsistencyContract '"evidence_ref":"memory_embedding_consistency_contract_visible"'

Write-Host "[browser-contract] Phase 2 Runtime Contract"
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

Write-Host "[browser-contract] organism contracts"
$organismContract = Invoke-Text "$BaseUrl/api/v1/organism/contract"
Assert-Contains "organism contract version" $organismContract '"contract_version":"organism-surface-v1"'
Assert-Contains "organism contract topology related" $organismContract '"/api/v1/organism/topology"'
Assert-Contains "organism contract safety related" $organismContract '"/api/v1/organism/safety"'
Assert-Contains "organism contract workspace wiring related" $organismContract '"/api/v1/workspace/wiring"'
Assert-Contains "organism contract workspace page count" $organismContract '"workspace_page_count":22'
$organismTopology = Invoke-Text "$BaseUrl/api/v1/organism/topology"
Assert-Contains "organism topology version" $organismTopology '"contract_version":"organism-topology-v1"'
Assert-Contains "organism topology layer node" $organismTopology '"id":"layer:FE"'
Assert-Contains "organism topology agent node" $organismTopology '"id":"agent:planner"'
Assert-Contains "organism topology tool node" $organismTopology '"id":"tool:mcp_gateway"'
Assert-Contains "organism topology gate node" $organismTopology '"kind":"safety_gate"'
Assert-Contains "organism topology page brain edges" $organismTopology '"kind":"page_to_brain_region"'
Assert-Contains "organism topology page data edges" $organismTopology '"kind":"page_to_data_source"'
Assert-Contains "organism topology page verifier edges" $organismTopology '"kind":"page_to_verifier"'
if ($AllowLocalhost) {
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-organism-topology.ps1 -BaseUrl $BaseUrl -AllowLocalhost
} else {
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-organism-topology.ps1 -BaseUrl $BaseUrl
}
if ($LASTEXITCODE -ne 0) {
  throw "Browser contract verification failed: organism topology"
}
$workspaceWiring = Invoke-Text "$BaseUrl/api/v1/workspace/wiring"
Assert-Contains "workspace wiring version" $workspaceWiring '"contract_version":"workspace-surface-wiring-v1"'
Assert-Contains "workspace wiring evidence" $workspaceWiring '"evidence_ref":"workspace_surface_wiring_visible"'
Assert-Contains "workspace wiring page count" $workspaceWiring '"page_count":22'
Assert-Contains "workspace wiring home surface" $workspaceWiring '"pageId":"home"'
Assert-Contains "workspace wiring workbench surface" $workspaceWiring '"pageId":"workbench"'
Assert-Contains "workspace wiring organism surface" $workspaceWiring '"pageId":"organism"'
Assert-Contains "workspace wiring open source surface" $workspaceWiring '"pageId":"open-source"'
Assert-Contains "workspace wiring no writes" $workspaceWiring '"writes":false'
Assert-Contains "workspace wiring no live" $workspaceWiring '"live":false'
Write-Host "[browser-contract] workspace vertical stack"
if ($AllowLocalhost) {
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-workspace-vertical-stack.ps1 -BaseUrl $BaseUrl -AllowLocalhost
} else {
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-workspace-vertical-stack.ps1 -BaseUrl $BaseUrl
}
if ($LASTEXITCODE -ne 0) {
  throw "Browser contract verification failed: workspace vertical stack"
}
Write-Host "[browser-contract] workspace data sources"
if ($AllowLocalhost) {
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-workspace-data-sources.ps1 -BaseUrl $BaseUrl -AllowLocalhost
} else {
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-workspace-data-sources.ps1 -BaseUrl $BaseUrl
}
if ($LASTEXITCODE -ne 0) {
  throw "Browser contract verification failed: workspace data sources"
}
Write-Host "[browser-contract] platform UI status boundary"
if ($AllowLocalhost) {
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-platform-ui-status-boundary.ps1 -BaseUrl $BaseUrl -AllowLocalhost
} else {
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-platform-ui-status-boundary.ps1 -BaseUrl $BaseUrl
}
if ($LASTEXITCODE -ne 0) {
  throw "Browser contract verification failed: platform UI status boundary"
}
Write-Host "[browser-contract] reference design contract"
$referenceDesignContract = Invoke-Text "$BaseUrl/api/v1/design/reference-contract"
Assert-Contains "reference design version" $referenceDesignContract '"contract_version":"reference-design-conformance-v1"'
Assert-Contains "reference design evidence" $referenceDesignContract '"evidence_ref":"reference_design_conformance_visible"'
Assert-Contains "reference design endpoint" $referenceDesignContract '"/api/v1/design/reference-contract"'
Assert-Contains "reference design expected page count" $referenceDesignContract '"expected_page_count":22'
Assert-Contains "reference design page count" $referenceDesignContract '"page_count":22'
Assert-Contains "reference design visual language" $referenceDesignContract "industrial-developer-workbench"
Assert-Contains "reference design root" $referenceDesignContract "docs/reference"
Assert-Contains "reference design no fake live" $referenceDesignContract '"no_fake_live":true'
Assert-Contains "reference design non claim" $referenceDesignContract "This contract does not claim pixel-perfect visual completion"
Assert-Contains "reference design dev-only non claim" $referenceDesignContract "Local evidence remains DEV-ONLY"
if ($AllowLocalhost) {
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-reference-design-browser.ps1 -BaseUrl $BaseUrl -AllowLocalhost
} else {
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-reference-design-browser.ps1 -BaseUrl $BaseUrl
}
if ($LASTEXITCODE -ne 0) {
  throw "Browser contract verification failed: reference design browser proof"
}
Write-Host "[browser-contract] workspace pages browser proof"
if ($AllowLocalhost) {
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-workspace-pages-browser.ps1 -BaseUrl $BaseUrl -AllowLocalhost
} else {
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-workspace-pages-browser.ps1 -BaseUrl $BaseUrl
}
if ($LASTEXITCODE -ne 0) {
  throw "Browser contract verification failed: workspace pages browser proof"
}
$organismLiveState = Invoke-Text "$BaseUrl/api/v1/organism/live-state"
Assert-Contains "organism live-state version" $organismLiveState '"contract_version":"organism-live-state-v1"'
Assert-Contains "organism live-state no secret" $organismLiveState '"gates_closed"'
$organismEvents = Invoke-Text "$BaseUrl/api/v1/organism/events"
Assert-Contains "organism events version" $organismEvents '"contract_version":"organism-events-v1"'
Assert-Contains "organism events no secret output" $organismEvents '"secret_output":false'
$organismReplay = Invoke-Text "$BaseUrl/api/v1/organism/replay"
Assert-Contains "organism replay version" $organismReplay '"contract_version":"organism-replay-v1"'
Assert-Contains "organism replay availability" $organismReplay '"replay_available":'
$organismRegions = Invoke-Text "$BaseUrl/api/v1/organism/regions"
Assert-Contains "organism regions version" $organismRegions '"contract_version":"organism-regions-v1"'
Assert-Contains "organism regions callosum" $organismRegions '"id":"callosum"'
$organismSafety = Invoke-Text "$BaseUrl/api/v1/organism/safety"
Assert-Contains "organism safety version" $organismSafety '"contract_version":"organism-safety-v1"'
Assert-Contains "organism safety no fake live" $organismSafety '"no_fake_live":true'
Assert-Contains "organism safety no writes" $organismSafety '"writes":false'

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
Assert-Contains "external gate mirror status" $externalGateMirror '"status":"local_mirror_ready_hosted_blocked"'
Assert-Contains "external gate mirror evidence" $externalGateMirror '"evidence_ref":"external_gate_mirror_proof"'
Assert-Contains "external gate mirror hosted allowed" $externalGateMirror '"hosted_staging_claim_allowed":true'
Assert-Contains "external gate mirror branch protection allowed" $externalGateMirror '"branch_protection_claim_allowed":true'
Assert-Contains "external gate mirror branch protection evidence" $externalGateMirror '"branch_protection_evidence_ref":"branch_protection_verify_contract"'
Assert-Contains "external gate mirror branch protection workflow" $externalGateMirror ".github/workflows/branch-protection.yml"
Assert-Contains "external gate mirror branch protection verifier" $externalGateMirror "scripts/apply_github_branch_protection.py --verify-only"
Assert-Contains "external gate mirror production blocked" $externalGateMirror '"production_deploy_claim_allowed":false'
Assert-Contains "external gate mirror sse contract" $externalGateMirror "phase2-sse-event-contract-v1"
Assert-Contains "external gate mirror project progress proof" $externalGateMirror "project_progress_manifest_proof"

if ($isLocalProof) {
Write-Host "[browser-contract] Start Phase 2 Runtime"
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

Write-Host "[browser-contract] Organism Runtime Event Projection"
& (Join-Path $PSScriptRoot "verify-organism-runtime-events.ps1") -BaseUrl $BaseUrl -AllowLocalhost:$AllowLocalhost -RunId $phase2RuntimeRun.thread_id

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
} else {
  Write-Host "[browser-contract] Hosted Phase 2 Runtime mutation skipped (stateless read-only contract origin)"
  $hostedPhase2RuntimeContract = Invoke-Text "$BaseUrl/api/v1/phase2/runtime/contract"
  Assert-Contains "hosted phase2 runtime contract version" $hostedPhase2RuntimeContract '"contract_version":"phase2-runtime-v1"'
  Assert-Contains "hosted phase2 runtime no live provider" $hostedPhase2RuntimeContract '"live_provider_calls":false'
}

if ($SeedMemoryConsolidation) {
  Write-Host "[browser-contract] Memory Consolidation: seed memory consolidation"
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
  Write-Host "[browser-contract] Memory Consolidation: feed shape"
  $consolidationFeed = Invoke-Text "$BaseUrl/api/v1/memory/consolidation/recent?limit=8"
  Assert-Contains "memory consolidation feed shape" $consolidationFeed '"events"'
  Assert-Contains "memory consolidation summary shape" $consolidationFeed '"summary"'
}

Write-Host "[browser-contract] checks completed"


param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase4 hosted cloud-surface verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted cloud-surface verification failed: $label"
  }
}

function Invoke-Text($url) {
  $python = @'
import sys
import urllib.request

with urllib.request.urlopen(sys.argv[1], timeout=20) as response:
    sys.stdout.write(response.read().decode("utf-8", errors="replace"))
'@
  return ($python | py -3 - $url)
}

function Invoke-WebResponse($url, $method = "GET", $body = $null, [hashtable]$headers = $null, $contentType = $null, $timeoutSeconds = 30) {
  $bodyBase64 = $null
  if ($null -ne $body) {
    $bodyBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$body))
  }
  $payload = [pscustomobject]@{
    url = $url
    method = $method
    bodyBase64 = $bodyBase64
    headers = $headers
    contentType = $contentType
    timeoutSeconds = $timeoutSeconds
  } | ConvertTo-Json -Depth 8 -Compress
  $python = @'
import base64
import json
import sys
import urllib.error
import urllib.request

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)
body_base64 = payload.get("bodyBase64")
data = None
if body_base64 is not None:
    data = base64.b64decode(body_base64.encode("ascii"))
headers = payload.get("headers") or {}
content_type = payload.get("contentType")
if content_type and "Content-Type" not in headers and "content-type" not in headers:
    headers["Content-Type"] = content_type
request = urllib.request.Request(
    payload["url"],
    data=data,
    headers=headers,
    method=payload["method"],
)
try:
    with urllib.request.urlopen(request, timeout=payload.get("timeoutSeconds", 30)) as response:
        result = {
            "status_code": response.getcode(),
            "content": response.read().decode("utf-8", errors="replace"),
            "headers": dict(response.headers.items()),
        }
except urllib.error.HTTPError as error:
    result = {
        "status_code": error.code,
        "content": error.read().decode("utf-8", errors="replace"),
        "headers": dict(error.headers.items()),
    }
print(json.dumps(result))
'@
  $payloadFile = Join-Path $env:TEMP ("phase4-cloud-surface-response-" + [Guid]::NewGuid().ToString("N") + ".json")
  try {
    Set-Content -LiteralPath $payloadFile -Value $payload -NoNewline
    $raw = $python | py -3 - $payloadFile
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
  }
  $parsed = $raw | ConvertFrom-Json
  return [pscustomobject]@{
    StatusCode = [int]$parsed.status_code
    Content = [string]$parsed.content
    Headers = $parsed.headers
  }
}

function Invoke-JsonApi($url, $method = "GET", $body = $null, [hashtable]$headers = $null, $contentType = "application/json", $timeoutSeconds = 30) {
  $response = Invoke-WebResponse -url $url -method $method -body $body -headers $headers -contentType $contentType -timeoutSeconds $timeoutSeconds
  if ([int]$response.StatusCode -ge 400) {
    throw "Phase4 hosted cloud-surface verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") {
  throw "Phase4 hosted cloud-surface proof requires HTTPS"
}

Write-Host "[phase4-hosted-cloud-surfaces] base url: $BaseUrl"

$frontendHtml = Invoke-Text "$BaseUrl/"
foreach ($needle in @(
  "Cloud Inventory",
  "Cloud 7-Layer Readiness",
  "Cloud Render Offload",
  "Cloud Deployment Preflight",
  "External Gate Mirror"
)) {
  Assert-Contains "frontend marker $needle" $frontendHtml $needle
}

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

$cloudRenderOffloadContract = Invoke-Text "$BaseUrl/api/v1/clouds/render-offload/contract"
Assert-Contains "cloud render offload contract version" $cloudRenderOffloadContract '"contract_version":"cloud-render-offload-surface-v1"'
Assert-Contains "cloud render offload contract evidence" $cloudRenderOffloadContract '"evidence_ref":"cloud_render_offload_contract_runtime_visible"'
Assert-Contains "cloud render offload contract endpoint" $cloudRenderOffloadContract '"endpoint":"GET /api/v1/clouds/render-offload/contract"'
Assert-Contains "cloud render offload runtime endpoint" $cloudRenderOffloadContract '"runtime_endpoint":"GET /api/v1/clouds/render-offload"'
$cloudRenderOffloadRuntime = Invoke-Text "$BaseUrl/api/v1/clouds/render-offload"
Assert-Contains "cloud render offload runtime version" $cloudRenderOffloadRuntime '"contract_version":"cloud-render-offload-v1"'
Assert-Contains "cloud render offload runtime evidence" $cloudRenderOffloadRuntime '"evidence_ref":"cloud_render_offload_contract_visible"'
Assert-Contains "cloud render offload local block" $cloudRenderOffloadRuntime '"localhost_heavy_render_allowed":false'
Assert-Contains "cloud render offload staging blocker" $cloudRenderOffloadRuntime "cloud_render_offload_requires_STAGING_BASE_URL"

$cloudDeploymentPreflightContract = Invoke-Text "$BaseUrl/api/v1/clouds/deployment-preflight/contract"
Assert-Contains "cloud deployment preflight contract version" $cloudDeploymentPreflightContract '"contract_version":"cloud-deployment-preflight-surface-v1"'
Assert-Contains "cloud deployment preflight contract evidence" $cloudDeploymentPreflightContract '"evidence_ref":"cloud_deployment_preflight_contract_runtime_visible"'
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

$externalGates = Invoke-Text "$BaseUrl/api/v1/external-gates"
Assert-Contains "external gates contract" $externalGates '"contract_version":"external-gates-state-v1"'
Assert-Contains "external gates evidence" $externalGates '"evidence_ref":"external_gates_state_visible"'
Assert-Contains "external gates status" $externalGates '"status":"verified"'
Assert-Contains "external gates no blocked release gates" $externalGates '"blocked_release_gates":[]'

$externalGateMirror = Invoke-Text "$BaseUrl/api/v1/external-gates/mirror"
Assert-Contains "external gate mirror contract" $externalGateMirror '"contract_version":"external-gate-mirror-v1"'
Assert-Contains "external gate mirror evidence" $externalGateMirror '"evidence_ref":"external_gate_mirror_proof"'
Assert-Contains "external gate mirror branch protection evidence" $externalGateMirror '"branch_protection_evidence_ref":"branch_protection_verify_contract"'
Assert-Contains "external gate mirror status" $externalGateMirror '"status":"verified"'
Assert-Contains "external gate mirror hosted allowed" $externalGateMirror '"hosted_staging_claim_allowed":true'
Assert-Contains "external gate mirror branch protection allowed" $externalGateMirror '"branch_protection_claim_allowed":true'
Assert-Contains "external gate mirror production allowed" $externalGateMirror '"production_deploy_claim_allowed":true'

$projectCompletion = Invoke-Text "$BaseUrl/api/v1/project/progress/completion"
Assert-Contains "project completion blocked state" $projectCompletion '"status":"blocked_external_gates"'
Assert-Contains "project completion no external gates missing" $projectCompletion '"missing_external_gates":[]'
Assert-Contains "project completion local blockers only" $projectCompletion "local_progress_gaps_require_verified_evidence_for_each_phase_and_layer"

Write-Host "[phase4-hosted-cloud-surfaces] checks completed"


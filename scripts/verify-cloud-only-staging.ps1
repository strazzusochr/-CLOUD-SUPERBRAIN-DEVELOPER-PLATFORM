param(
  [string]$BaseUrl = $env:STAGING_BASE_URL,
  [string]$ArtifactDir = ".phase1-artifacts"
)

$ErrorActionPreference = "Stop"

function New-Probe([string]$Id, [string]$Url, [bool]$Required, [string]$ExpectedText = "") {
  $result = [ordered]@{
    id = $Id
    url = $Url
    required = $Required
    status = "not_run"
    http_status = 0
    claim_allowed = $false
    expected_text = $ExpectedText
    error = ""
  }
  try {
    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 30
    $result.http_status = [int]$response.StatusCode
    $body = [string]$response.Content
    if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300 -and (($ExpectedText -eq "") -or $body.Contains($ExpectedText))) {
      $result.status = "verified"
      $result.claim_allowed = $true
    } else {
      $result.status = "failed"
      $result.error = "Expected HTTP 2xx and marker '$ExpectedText'"
    }
  } catch {
    $result.status = "failed"
    $result.error = $_.Exception.Message
  }
  return [pscustomobject]$result
}

if (-not $BaseUrl) {
  throw "STAGING_BASE_URL or -BaseUrl is required for cloud-only staging proof"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -match "localhost|127\.0\.0\.1|\[::1\]|0\.0\.0\.0|host\.docker\.internal") {
  throw "Cloud-only staging proof refuses localhost and private dev loopback targets"
}
if ($BaseUrl -notmatch "^https://") {
  throw "Cloud-only staging proof requires HTTPS"
}

New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null

$probes = @(
  (New-Probe "cloud_frontend_root" "$BaseUrl/" $true "Cloud Superbrain"),
  (New-Probe "cloud_frontend_health" "$BaseUrl/health" $true "ok"),
  (New-Probe "cloud_frontend_api_health" "$BaseUrl/api/health" $true '"service":"frontend"'),
  (New-Probe "cloud_agent_api_health" "$BaseUrl/api/v1/health" $true '"service":"agent-api"'),
  (New-Probe "cloud_provider_inventory" "$BaseUrl/api/v1/clouds" $true "cloud-provider-inventory-v1"),
  (New-Probe "cloud_layer_readiness" "$BaseUrl/api/v1/clouds/layers" $true "cloud-layer-readiness-v1"),
  (New-Probe "cloud_render_offload_contract" "$BaseUrl/api/v1/clouds/render-offload/contract" $true "cloud-render-offload-v1"),
  (New-Probe "cloud_deployment_preflight_contract" "$BaseUrl/api/v1/clouds/deployment-preflight/contract" $true "cloud-deployment-preflight-v1"),
  (New-Probe "cloud_mcp_gateway_health" "$BaseUrl/mcp/api/v1/health" $true '"service":"mcp-gateway"'),
  (New-Probe "cloud_llm_gateway_health" "$BaseUrl/llm/api/v1/health" $true '"service":"llm-gateway"')
)

$missing = @($probes | Where-Object { $_.required -and -not $_.claim_allowed } | ForEach-Object { $_.id })
$summary = [ordered]@{
  contract_version = "cloud-only-staging-proof-v1"
  status = $(if ($missing.Count -eq 0) { "verified" } else { "action_required" })
  base_url = $BaseUrl
  localhost_allowed = $false
  hosted_staging_claim_allowed = $missing.Count -eq 0
  production_deploy_claim_allowed = $false
  required_backend_env = @("AGENT_API_BASE_URL", "MCP_GATEWAY_BASE_URL", "LLM_GATEWAY_BASE_URL")
  missing_or_failed_gates = $missing
  probes = $probes
  non_claims = @(
    "Cloud-only staging proof does not allow localhost.",
    "Frontend-only Vercel success is not hosted Agent API success.",
    "Production deployment remains blocked without branch protection, live budget, secret scan, and owner review."
  )
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$artifact = Join-Path $ArtifactDir "cloud-only-staging-proof-$stamp.json"
$summary | ConvertTo-Json -Depth 8 | Set-Content -Path $artifact -Encoding utf8

Write-Host "[cloud-only] artifact=$artifact"
Write-Host "[cloud-only] status=$($summary.status)"
Write-Host "[cloud-only] hosted_staging_claim_allowed=$($summary.hosted_staging_claim_allowed)"
if ($missing.Count -gt 0) {
  Write-Host "[cloud-only] missing_or_failed_gates=$($missing -join ',')"
  throw "Cloud-only staging proof failed"
}

Write-Host "[cloud-only] checks completed"

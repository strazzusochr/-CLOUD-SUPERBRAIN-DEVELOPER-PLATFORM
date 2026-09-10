param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "LLM model catalog verification failed: $label"
  }
}

function Invoke-Text($url) {
  $python = @'
import sys
import urllib.request

with urllib.request.urlopen(sys.argv[1], timeout=30) as response:
    sys.stdout.write(response.read().decode("utf-8", errors="replace"))
'@
  return ($python | py -3 - $url)
}

function Invoke-JsonApi($url) {
  return (Invoke-Text $url | ConvertFrom-Json)
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ((-not $AllowLocalhost) -and ($BaseUrl -match "localhost|127\.0\.0\.1|\[::1\]")) {
  throw "LLM model catalog proof refuses localhost unless -AllowLocalhost is set"
}

Write-Host "[phase4-llm-model-catalog] base url: $BaseUrl"

$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-True "frontend exposes model catalog panel" ($frontendHtml.Contains("Model Catalog"))
Assert-True "frontend exposes catalog contract version" ($frontendHtml.Contains("llm-model-catalog-v1"))
Assert-True "frontend exposes catalog evidence" ($frontendHtml.Contains("llm_model_catalog_visible"))
Assert-True "frontend exposes catalog endpoint" ($frontendHtml.Contains("GET /llm/api/v1/models/catalog"))
Assert-True "frontend exposes api-only non-download claim" ($frontendHtml.Contains("API-only / no downloads"))

$health = Invoke-JsonApi "$BaseUrl/llm/api/v1/health"
Assert-True "health catalog version" ($health.model_catalog_contract_version -eq "llm-model-catalog-v1")
Assert-True "health catalog endpoint" ($health.model_catalog_endpoint -eq "GET /llm/api/v1/models/catalog")
Assert-True "health catalog evidence" ($health.model_catalog_evidence_ref -eq "llm_model_catalog_visible")
Assert-True "health no live calls" ($health.live_provider_calls -eq $false)
Assert-True "health no model downloads" ($health.model_downloads -eq $false)
Assert-True "health open source first" ($health.open_source_first -eq $true)

$catalog = Invoke-JsonApi "$BaseUrl/llm/api/v1/models/catalog"
Assert-True "catalog contract version" ($catalog.contract_version -eq "llm-model-catalog-v1")
Assert-True "catalog status" ($catalog.status -eq "verified")
Assert-True "catalog evidence" ($catalog.evidence_ref -eq "llm_model_catalog_visible")
Assert-True "catalog no live calls" ($catalog.live_provider_calls -eq $false)
Assert-True "catalog no model downloads" ($catalog.model_downloads -eq $false)
Assert-True "catalog local downloads blocked" ($catalog.local_model_downloads_allowed -eq $false)
Assert-True "catalog api inference only" ($catalog.api_inference_only -eq $true)
Assert-True "catalog open source first" ($catalog.open_source_first -eq $true)
Assert-True "catalog route count" ([int]$catalog.route_count -ge 5)
Assert-True "catalog configured model count" ([int]$catalog.configured_model_count -ge 10)
Assert-True "catalog alias count" ([int]$catalog.alias_count -ge 4)
Assert-True "catalog evidence refs direct provider" ($catalog.evidence_refs.direct_provider_blocked -eq "llm_routing_policy_direct_provider_blocked")
Assert-True "catalog evidence refs unknown model" ($catalog.evidence_refs.unknown_model_blocked -eq "llm_routing_policy_unknown_model_blocked")
Assert-True "catalog evidence refs output budget" ($catalog.evidence_refs.output_token_budget_blocked -eq "llm_output_token_budget_guard")

$agentTypes = @($catalog.routes | ForEach-Object { [string]$_.agent_type })
foreach ($required in @("planner", "coder", "tester", "devops", "research")) {
  Assert-True "catalog route $required" ($agentTypes -contains $required)
}

foreach ($route in @($catalog.routes)) {
  Assert-True "route $($route.agent_type) primary" ([string]$route.primary)
  Assert-True "route $($route.agent_type) fallback count" (@($route.fallbacks).Count -ge 2)
  Assert-True "route $($route.agent_type) provider chain" (@($route.provider_chain) -contains "huggingface_inference_router")
  Assert-True "route $($route.agent_type) api only" ($route.api_inference_only -eq $true)
  Assert-True "route $($route.agent_type) no downloads" ($route.model_downloads -eq $false)
  Assert-True "route $($route.agent_type) open source first" ($route.open_source_first -eq $true)
  Assert-True "route $($route.agent_type) token budget" ([int]$route.max_output_tokens -gt 0)
}

$models = Invoke-JsonApi "$BaseUrl/llm/v1/models"
Assert-True "models list object" ($models.object -eq "list")
Assert-True "models no live calls" ($models.live_provider_calls -eq $false)
Assert-True "models no downloads" ($models.model_downloads -eq $false)
Assert-True "models provider" ($models.provider -eq "huggingface_inference_router")
Assert-True "models configured route visible" (@($models.data | Where-Object { $_.configured_route -eq $true }).Count -ge 10)
foreach ($model in @($models.data | Where-Object { $_.configured_route -eq $true })) {
  Assert-True "model $($model.id) api only" ($model.api_inference_only -eq $true)
  Assert-True "model $($model.id) no downloads" ($model.model_downloads -eq $false)
  Assert-True "model $($model.id) provider" ($model.provider -eq "huggingface_inference_router")
}

Write-Host "status=verified"
Write-Host "contract_version=$($catalog.contract_version)"
Write-Host "evidence_ref=$($catalog.evidence_ref)"
Write-Host "route_count=$($catalog.route_count)"

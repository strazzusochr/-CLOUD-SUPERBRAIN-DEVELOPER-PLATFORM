param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "LLM provider readiness verification failed: $label"
  }
}

function Assert-Contains($label, $text, $expected) {
  if (-not ($text -like "*$expected*")) {
    throw "LLM provider readiness verification failed: $label missing '$expected'"
  }
}

function Invoke-Text($url) {
  (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 30).Content
}

function Invoke-Json($url) {
  (Invoke-Text $url) | ConvertFrom-Json
}

$isLocalhost = $BaseUrl -match "^http://(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\])(:|/|$)"
if ($isLocalhost -and -not $AllowLocalhost) {
  throw "Localhost verification requires -AllowLocalhost and remains DEV-ONLY"
}
if (($BaseUrl -notmatch "^https://") -and -not $AllowLocalhost) {
  throw "Non-HTTPS verification requires -AllowLocalhost"
}

$contract = Invoke-Json "$BaseUrl/llm/api/v1/providers/readiness/contract"
Assert-True "contract version" ($contract.contract_version -eq "llm-provider-readiness-contract-v1")
Assert-True "status verified" ($contract.status -eq "verified")
Assert-True "evidence ref" ($contract.evidence_ref -eq "llm_provider_readiness_contract_visible")
Assert-True "public endpoint" ($contract.public_endpoint -eq "GET /llm/api/v1/providers/readiness/contract")
Assert-True "no live provider calls" ($contract.live_provider_calls -eq $false)
Assert-True "no external probe" ($contract.external_probe_performed -eq $false)
Assert-True "no model downloads" ($contract.model_downloads -eq $false)
Assert-True "no local model downloads" ($contract.local_model_downloads_allowed -eq $false)
Assert-True "provider token not returned" ($contract.provider_token_returned -eq $false)
Assert-True "deterministic default" ($contract.default_generation_decision -eq "deterministic_dry_run")
Assert-True "route count" ([int]$contract.route_count -ge 5)
Assert-True "configured model count" ([int]$contract.configured_model_count -ge 10)
Assert-True "direct provider keys blocked" (@($contract.direct_provider_metadata_keys_blocked) -contains "direct_provider_url")
Assert-True "no live generation non-claim" (@($contract.non_claims) -contains "No live provider generation call is made by this contract.")
Assert-True "no upstream probe non-claim" (@($contract.non_claims) -contains "No upstream model-list probe is made by this contract.")

$health = Invoke-Text "$BaseUrl/llm/api/v1/health"
Assert-Contains "health readiness version" $health '"provider_readiness_contract_version":"llm-provider-readiness-contract-v1"'
Assert-Contains "health readiness evidence" $health '"provider_readiness_evidence_ref":"llm_provider_readiness_contract_visible"'
Assert-Contains "health readiness endpoint" $health "GET /llm/api/v1/providers/readiness/contract"

$frontendSource = Get-Content -Path "apps\frontend\app\page.tsx" -Raw
foreach ($required in @("Provider Readiness Contract", "llm-provider-readiness-contract-v1", "llm_provider_readiness_contract_visible", "/llm/api/v1/providers/readiness/contract", "external_probe_performed")) {
  Assert-Contains "frontend source $required" $frontendSource $required
}

$gatewaySource = Get-Content -Path "services\llm-gateway\app\main.py" -Raw
foreach ($required in @("LLM_PROVIDER_READINESS_CONTRACT_VERSION", "llm-provider-readiness-contract-v1", "llm_provider_readiness_contract_visible", "provider_readiness_contract_snapshot", "/api/v1/providers/readiness/contract", "external_probe_performed")) {
  Assert-Contains "gateway source $required" $gatewaySource $required
}

$doc = Get-Content -Path "docs\runtime-contracts\llm-provider-readiness-contract.md" -Raw
foreach ($required in @("llm-provider-readiness-contract-v1", "llm_provider_readiness_contract_visible", "GET /llm/api/v1/providers/readiness/contract", "external_probe_performed=false", "No live provider generation call")) {
  Assert-Contains "contract doc $required" $doc $required
}

Write-Host "[llm-provider-readiness] base_url=$BaseUrl"
Write-Host "[llm-provider-readiness] result=verified"

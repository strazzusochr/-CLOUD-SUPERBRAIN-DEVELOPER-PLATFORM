param(
  [string]$BaseUrl = $(if ($env:STAGING_BASE_URL) { $env:STAGING_BASE_URL } else { "" })
)

$ErrorActionPreference = "Stop"

function Assert-HostedBaseUrlConfigured {
  if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    throw "Hosted verifier requires -BaseUrl or env:STAGING_BASE_URL (HTTPS, non-localhost)."
  }
  if ($BaseUrl -notmatch '^https://') {
    throw "Hosted verifier requires an HTTPS BaseUrl."
  }
  if ($BaseUrl -match 'localhost|127\.0\.0\.1|\[::1\]|0\.0\.0\.0|host\.docker\.internal') {
    throw "Hosted verifier refuses localhost and loopback BaseUrl values."
  }
}
Assert-HostedBaseUrlConfigured


function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted cloud-inventory-contract verification failed: $label"
  }
}

function Invoke-WebResponse($url, $timeoutSeconds = 20) {
  $python = @'
import json
import sys
import urllib.error
import urllib.request

try:
    with urllib.request.urlopen(sys.argv[1], timeout=int(sys.argv[2])) as response:
        result = {"status_code": response.getcode(), "content": response.read().decode("utf-8", errors="replace")}
except urllib.error.HTTPError as error:
    result = {"status_code": error.code, "content": error.read().decode("utf-8", errors="replace")}
print(json.dumps(result))
'@
  $raw = $python | py -3 - $url $timeoutSeconds
  return ($raw | ConvertFrom-Json)
}

function Invoke-JsonApi($url) {
  $response = Invoke-WebResponse -url $url
  if ([int]$response.status_code -ge 400) {
    throw "Phase4 hosted cloud-inventory-contract verification failed: GET $url returned HTTP $($response.status_code). Value: $($response.content)"
  }
  return ($response.content | ConvertFrom-Json)
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted cloud-inventory-contract proof requires HTTPS" }

Write-Host "[phase4-cloud-inventory-contract-runtime] base_url=$BaseUrl"

$contract = Invoke-JsonApi "$BaseUrl/api/v1/clouds/contract"
$runtime = Invoke-JsonApi "$BaseUrl/api/v1/clouds"

Assert-True "contract version" ($contract.contract_version -eq "cloud-provider-surface-v1")
Assert-True "runtime endpoint" ($contract.runtime_endpoint -eq "GET /api/v1/clouds")
Assert-True "runtime contract version parity" ($runtime.contract_version -eq $contract.expected_runtime_contract_version)
Assert-True "runtime endpoint parity" ($runtime.endpoint -eq $contract.expected_runtime_endpoint)
Assert-True "status supported" ($contract.supported_statuses -contains $runtime.status)

foreach ($field in @($contract.required_top_level_fields)) {
  Assert-True "top-level field $field present" ($null -ne $runtime.$field)
}

$runtimeProviderIds = @($runtime.providers | ForEach-Object { [string]$_.id })
$runtimeLayerIds = @($runtime.seven_layer_mapping | ForEach-Object { [string]$_.layer_id })

foreach ($providerId in @($contract.required_provider_ids)) {
  Assert-True "provider id $providerId present" ($runtimeProviderIds -contains [string]$providerId)
}
foreach ($layerId in @($contract.required_layer_ids)) {
  Assert-True "layer id $layerId present" ($runtimeLayerIds -contains [string]$layerId)
}

foreach ($provider in @($runtime.providers)) {
  foreach ($field in @($contract.required_provider_fields)) {
    Assert-True "provider field $field present for $($provider.id)" ($null -ne $provider.$field)
  }
  Assert-True "provider status supported for $($provider.id)" ($contract.supported_provider_statuses -contains $provider.status)
}

foreach ($mapping in @($runtime.seven_layer_mapping)) {
  foreach ($field in @($contract.required_layer_mapping_fields)) {
    Assert-True "layer mapping field $field present for $($mapping.layer_id)" ($null -ne $mapping.$field)
  }
}

Assert-True "evidence ref" ($contract.evidence_ref -eq "cloud_inventory_contract_runtime_visible")

Write-Host "[phase4-cloud-inventory-contract-runtime] result=verified"

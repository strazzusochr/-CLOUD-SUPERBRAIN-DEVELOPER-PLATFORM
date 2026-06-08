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
    throw "Phase4 hosted health-contract verification failed: $label"
  }
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
request = urllib.request.Request(payload["url"], data=data, headers=headers, method=payload["method"])
try:
    with urllib.request.urlopen(request, timeout=payload.get("timeoutSeconds", 30)) as response:
        result = {"status_code": response.getcode(), "content": response.read().decode("utf-8", errors="replace")}
except urllib.error.HTTPError as error:
    result = {"status_code": error.code, "content": error.read().decode("utf-8", errors="replace")}
print(json.dumps(result))
'@
  $payloadFile = Join-Path $env:TEMP ("phase4-health-contract-" + [Guid]::NewGuid().ToString("N") + ".json")
  try {
    Set-Content -LiteralPath $payloadFile -Value $payload -NoNewline
    $raw = $python | py -3 - $payloadFile
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
  }
  return ($raw | ConvertFrom-Json)
}

function Invoke-JsonApi($url) {
  $response = Invoke-WebResponse -url $url
  if ([int]$response.status_code -ge 400) {
    throw "Phase4 hosted health-contract verification failed: GET $url returned HTTP $($response.status_code). Value: $($response.content)"
  }
  return ($response.content | ConvertFrom-Json)
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted health-contract proof requires HTTPS" }

Write-Host "[phase4-health-contract-runtime] base_url=$BaseUrl"

$contract = Invoke-JsonApi "$BaseUrl/api/v1/health/contract"
$runtime = Invoke-JsonApi "$BaseUrl/api/v1/health"

Assert-True "contract version" ($contract.contract_version -eq "health-surface-v1")
Assert-True "runtime endpoint" ($contract.runtime_endpoint -eq "GET /api/v1/health")
foreach ($field in $contract.required_top_level_fields) {
  Assert-True "top-level field $field present" ($null -ne $runtime.$field)
}
Assert-True "service name" ($runtime.service -eq "agent-api")
Assert-True "status supported" ($contract.supported_statuses -contains $runtime.status)

foreach ($serviceKey in $contract.required_service_keys) {
  Assert-True "service key $serviceKey present" ($null -ne $runtime.services.$serviceKey)
  Assert-True "service $serviceKey status present" ($null -ne $runtime.services.$serviceKey.status)
}

foreach ($field in $contract.required_budget_fields) {
  Assert-True "budget field $field present" ($null -ne $runtime.budget.$field)
}
Assert-True "budget limit parity" ($runtime.budget.budget_limit_cents -eq $contract.budget_limit_cents)

foreach ($field in $contract.required_infra_budget_fields) {
  Assert-True "infra budget field $field present" ($null -ne $runtime.infra_budget.$field)
}
Assert-True "infra budget limit parity" ($runtime.infra_budget.budget_limit_cents -eq $contract.infra_budget_limit_cents)
Assert-True "infra source supported" ($contract.infra_supported_sources -contains $runtime.infra_budget.source)

foreach ($field in $contract.required_external_gate_fields) {
  Assert-True "external gate field $field present" ($null -ne $runtime.external_gates.$field)
}
Assert-True "external gate status supported" ($contract.supported_gate_statuses -contains $runtime.external_gates.status)
Assert-True "external gate status parity" ($runtime.external_gates.status -eq $contract.expected_external_gate_status)
Assert-True "evidence ref" ($contract.evidence_ref -eq "health_contract_runtime_visible")

Write-Host "[phase4-health-contract-runtime] result=verified"

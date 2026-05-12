param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted budget-contract verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-budget-contracts-" + [Guid]::NewGuid().ToString("N") + ".json")
  try {
    Set-Content -LiteralPath $payloadFile -Value $payload -NoNewline
    $raw = $python | py -3 - $payloadFile
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
  }
  return ($raw | ConvertFrom-Json)
}

function Invoke-JsonApi($url, $method = "GET", $body = $null, $contentType = "application/json") {
  $response = Invoke-WebResponse -url $url -method $method -body $body -contentType $contentType
  if ([int]$response.status_code -ge 400) {
    throw "Phase4 hosted budget-contract verification failed: $method $url returned HTTP $($response.status_code). Value: $($response.content)"
  }
  return ($response.content | ConvertFrom-Json)
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted budget-contract proof requires HTTPS" }

Write-Host "[phase4-budget-contracts-runtime] base_url=$BaseUrl"

$budgetContract = Invoke-JsonApi "$BaseUrl/api/v1/budget/contract"
$budgetRuntime = Invoke-JsonApi "$BaseUrl/api/v1/budget"
$infraContract = Invoke-JsonApi "$BaseUrl/api/v1/infra/budget/contract"
$infraRuntime = Invoke-JsonApi "$BaseUrl/api/v1/infra/budget"

Assert-True "budget contract version" ($budgetContract.contract_version -eq "budget-surface-v1")
Assert-True "budget runtime endpoint" ($budgetContract.runtime_endpoint -eq "GET /api/v1/budget")
foreach ($field in $budgetContract.required_top_level_fields) {
  Assert-True "budget field $field present" ($null -ne $budgetRuntime.$field)
}
Assert-True "budget level supported" ($budgetContract.supported_levels -contains $budgetRuntime.level)
Assert-True "budget limit matches contract" ($budgetRuntime.budget_limit_cents -eq $budgetContract.budget_limit_cents)
Assert-True "budget evidence ref declared" ($budgetContract.evidence_ref -eq "budget_contract_runtime_visible")

Assert-True "infra contract version" ($infraContract.contract_version -eq "infra-budget-surface-v1")
Assert-True "infra runtime endpoint" ($infraContract.runtime_endpoint -eq "GET /api/v1/infra/budget")
foreach ($field in $infraContract.required_top_level_fields) {
  Assert-True "infra field $field present" ($null -ne $infraRuntime.$field)
}
Assert-True "infra level supported" ($infraContract.supported_levels -contains $infraRuntime.level)
Assert-True "infra source supported" ($infraContract.supported_sources -contains $infraRuntime.source)
Assert-True "infra budget limit matches contract" ($infraRuntime.budget_limit_cents -eq $infraContract.budget_limit_cents)
Assert-True "infra warning limit matches contract" ($infraRuntime.warning_limit_cents -eq $infraContract.warning_limit_cents)
Assert-True "infra items array present" ($infraRuntime.items -is [System.Collections.IEnumerable])
foreach ($item in @($infraRuntime.items)) {
  foreach ($field in $infraContract.required_item_fields) {
    Assert-True "infra item field $field present" ($null -ne $item.$field)
  }
}
Assert-True "infra evidence ref declared" ($infraContract.evidence_ref -eq "infra_budget_contract_runtime_visible")

Write-Host "[phase4-budget-contracts-runtime] result=verified"

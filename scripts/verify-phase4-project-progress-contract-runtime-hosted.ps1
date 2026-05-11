param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted project-progress-contract verification failed: $label"
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
import ssl
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
context = ssl._create_unverified_context() if payload["url"].startswith("https://") else None
try:
    with urllib.request.urlopen(request, timeout=payload.get("timeoutSeconds", 30), context=context) as response:
        result = {"status_code": response.getcode(), "content": response.read().decode("utf-8", errors="replace")}
except urllib.error.HTTPError as error:
    result = {"status_code": error.code, "content": error.read().decode("utf-8", errors="replace")}
print(json.dumps(result))
'@
  $payloadFile = Join-Path $env:TEMP ("phase4-project-progress-contract-" + [Guid]::NewGuid().ToString("N") + ".json")
  try {
    Set-Content -LiteralPath $payloadFile -Value $payload -NoNewline
    $raw = $python | py -3 - $payloadFile
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
  }
  $parsed = $raw | ConvertFrom-Json
  return [pscustomobject]@{ StatusCode = [int]$parsed.status_code; Content = [string]$parsed.content }
}

function Invoke-JsonApi($url, $method = "GET", $body = $null, [hashtable]$headers = $null, $contentType = "application/json", $timeoutSeconds = 30) {
  $response = Invoke-WebResponse -url $url -method $method -body $body -headers $headers -contentType $contentType -timeoutSeconds $timeoutSeconds
  if ([int]$response.StatusCode -ge 400) {
    throw "Phase4 hosted project-progress-contract verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted project-progress-contract proof requires HTTPS" }

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/project/progress/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "contract version" ($contract.contract_version -eq "project-progress-surface-v1")
Assert-True "endpoint parity" ($contract.endpoint -eq "GET /api/v1/project/progress")
Assert-True "guarded endpoint parity" ($contract.guarded_endpoint -eq "GET /api/v1/project/progress/integrity")
Assert-True "overall field required" (@($contract.required_top_level_fields) -contains "overall_percent")
Assert-True "horizontal field required" (@($contract.required_top_level_fields) -contains "horizontal")
Assert-True "vertical field required" (@($contract.required_top_level_fields) -contains "vertical")
Assert-True "item field status required" (@($contract.required_progress_item_fields) -contains "status")
Assert-True "phase count declared" ([int]$contract.expected_phase_count -eq 7)
Assert-True "layer count declared" ([int]$contract.expected_layer_count -eq 7)
Assert-True "progress source declared" ([string]$contract.expected_progress_source -eq "docs/project-progress.manifest.json")

$progress = Invoke-JsonApi -url "$BaseUrl/api/v1/project/progress" -method "GET" -contentType $null -timeoutSeconds 20
$integrity = Invoke-JsonApi -url "$BaseUrl/api/v1/project/progress/integrity" -method "GET" -contentType $null -timeoutSeconds 20

Assert-True "integrity verified" ($integrity.status -eq "verified")
Assert-True "progress source parity" ([string]$progress.progress_source -eq [string]$contract.expected_progress_source)
Assert-True "binding document parity" ([string]$progress.binding_document -eq [string]$contract.expected_binding_document)
Assert-True "horizontal label visible" (-not [string]::IsNullOrWhiteSpace([string]$progress.horizontal.label))
Assert-True "vertical label visible" (-not [string]::IsNullOrWhiteSpace([string]$progress.vertical.label))
Assert-True "phase count parity" (@($progress.horizontal.items).Count -eq [int]$contract.expected_phase_count)
Assert-True "layer count parity" (@($progress.vertical.items).Count -eq [int]$contract.expected_layer_count)
Assert-True "integrity manifest overall parity" ([int]$integrity.manifest_overall_percent -eq [int]$progress.overall_percent)
Assert-True "integrity computed overall parity" ([int]$integrity.computed_overall_percent -eq [int]$progress.overall_percent)

$phase4 = @($progress.horizontal.items) | Where-Object { $_.id -eq "phase_4" } | Select-Object -First 1
$layer2 = @($progress.vertical.items) | Where-Object { $_.id -eq "layer_2" } | Select-Object -First 1
Assert-True "phase4 visible" ($null -ne $phase4)
Assert-True "layer2 visible" ($null -ne $layer2)
Assert-True "phase4 status visible" (-not [string]::IsNullOrWhiteSpace([string]$phase4.status))
Assert-True "layer2 status visible" (-not [string]::IsNullOrWhiteSpace([string]$layer2.status))

Write-Host "[phase4-project-progress-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-project-progress-contract-runtime] result=verified"

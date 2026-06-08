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
    throw "Phase4 hosted project-progress-layers-contract verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-project-progress-layers-contract-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted project-progress-layers-contract verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted project-progress-layers-contract proof requires HTTPS" }

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/project/progress/layers/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "contract version" ($contract.contract_version -eq "project-progress-layers-surface-v1")
Assert-True "endpoint parity" ($contract.endpoint -eq "GET /api/v1/project/progress/layers")
Assert-True "guarded progress endpoint" (@($contract.guarded_endpoints) -contains "GET /api/v1/project/progress")
Assert-True "guarded integrity endpoint" (@($contract.guarded_endpoints) -contains "GET /api/v1/project/progress/integrity")
Assert-True "items field required" (@($contract.required_top_level_fields) -contains "items")
Assert-True "required item status field" (@($contract.required_item_fields) -contains "status")
Assert-True "expected count declared" ([int]$contract.expected_count -eq 7)
Assert-True "expected ids declared" (@($contract.expected_ids).Count -eq 7)

$layers = Invoke-JsonApi -url "$BaseUrl/api/v1/project/progress/layers" -method "GET" -contentType $null -timeoutSeconds 20
$progress = Invoke-JsonApi -url "$BaseUrl/api/v1/project/progress" -method "GET" -contentType $null -timeoutSeconds 20
$integrity = Invoke-JsonApi -url "$BaseUrl/api/v1/project/progress/integrity" -method "GET" -contentType $null -timeoutSeconds 20

Assert-True "integrity verified" ($integrity.status -eq "verified")
Assert-True "layers contract version runtime parity" ([string]$layers.contract_version -eq [string]$contract.contract_version)
Assert-True "layers endpoint runtime parity" ([string]$layers.endpoint -eq [string]$contract.endpoint)
Assert-True "overall percent parity" ([int]$layers.overall_percent -eq [int]$progress.overall_percent)
Assert-True "progress source parity" ([string]$layers.progress_source -eq [string]$progress.progress_source)
Assert-True "binding document parity" ([string]$layers.binding_document -eq [string]$progress.binding_document)
Assert-True "count parity" ([int]$layers.count -eq @($progress.vertical.items).Count)
Assert-True "label parity" ([string]$layers.label -eq [string]$progress.vertical.label)

$runtimeIds = @($layers.items | ForEach-Object { [string]$_.id })
$expectedIds = @($contract.expected_ids | ForEach-Object { [string]$_ })
foreach ($id in $expectedIds) {
  Assert-True "expected layer id $id present" ($runtimeIds -contains $id)
}

$layer6Layers = @($layers.items) | Where-Object { $_.id -eq "layer_6" } | Select-Object -First 1
$layer6Progress = @($progress.vertical.items) | Where-Object { $_.id -eq "layer_6" } | Select-Object -First 1
Assert-True "layer6 visible in layers" ($null -ne $layer6Layers)
Assert-True "layer6 visible in progress" ($null -ne $layer6Progress)
Assert-True "layer6 percent parity" ([int]$layer6Layers.percent -eq [int]$layer6Progress.percent)
Assert-True "layer6 status visible" (-not [string]::IsNullOrWhiteSpace([string]$layer6Layers.status))

Write-Host "[phase4-project-progress-layers-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-project-progress-layers-contract-runtime] result=verified"

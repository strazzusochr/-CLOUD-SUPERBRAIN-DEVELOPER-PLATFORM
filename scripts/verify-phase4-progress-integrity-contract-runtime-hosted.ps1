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
    throw "Phase4 hosted progress-integrity-contract verification failed: $label"
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
import base64, json, ssl, sys, urllib.error, urllib.request
with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)
body_base64 = payload.get("bodyBase64")
data = None if body_base64 is None else base64.b64decode(body_base64.encode("ascii"))
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
  $payloadFile = Join-Path $env:TEMP ("phase4-progress-integrity-contract-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted progress-integrity-contract verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted progress-integrity-contract proof requires HTTPS" }

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/project/progress/integrity/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "contract version" ($contract.contract_version -eq "project-progress-integrity-surface-v1")
Assert-True "endpoint parity" ($contract.endpoint -eq "GET /api/v1/project/progress/integrity")
Assert-True "guarded endpoint parity" ($contract.guarded_endpoint -eq "GET /api/v1/project/progress")
Assert-True "runtime contract version parity" ($contract.runtime_contract_version -eq "project-progress-integrity-v1")
Assert-True "required manifest field" (@($contract.required_top_level_fields) -contains "manifest_overall_percent")
Assert-True "required mismatches field" (@($contract.required_top_level_fields) -contains "mismatches")
Assert-True "expected verified status" (@($contract.expected_statuses) -contains "verified")
Assert-True "required hard rules visible" (@($contract.required_hard_rules).Count -ge 3)

$progress = Invoke-JsonApi -url "$BaseUrl/api/v1/project/progress" -method "GET" -contentType $null -timeoutSeconds 20
$integrity = Invoke-JsonApi -url "$BaseUrl/api/v1/project/progress/integrity" -method "GET" -contentType $null -timeoutSeconds 20

Assert-True "integrity verified" ($integrity.status -eq "verified")
Assert-True "integrity contract version runtime" ($integrity.contract_version -eq "project-progress-integrity-v1")
Assert-True "manifest overall parity" ([int]$integrity.manifest_overall_percent -eq [int]$progress.overall_percent)
Assert-True "computed overall parity" ([int]$integrity.computed_overall_percent -eq [int]$progress.overall_percent)
Assert-True "phase count parity" ([int]$integrity.horizontal_phase_count -eq @($progress.horizontal.items).Count)
Assert-True "layer count parity" ([int]$integrity.vertical_layer_count -eq @($progress.vertical.items).Count)
Assert-True "no mismatches" (@($integrity.mismatches).Count -eq 0)
Assert-True "phase4 parity" ([int]$integrity.horizontal_phase_percentages.phase_4 -eq (@($progress.horizontal.items) | Where-Object { $_.id -eq 'phase_4' } | Select-Object -First 1).percent)
Assert-True "layer6 parity" ([int]$integrity.vertical_layer_percentages.layer_6 -eq (@($progress.vertical.items) | Where-Object { $_.id -eq 'layer_6' } | Select-Object -First 1).percent)

Write-Host "[phase4-progress-integrity-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-progress-integrity-contract-runtime] result=verified"

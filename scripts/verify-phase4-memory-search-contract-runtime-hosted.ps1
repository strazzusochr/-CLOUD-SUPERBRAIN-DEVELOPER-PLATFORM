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
    throw "Phase4 hosted memory-search-contract runtime verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-memory-search-contract-runtime-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted memory-search-contract runtime verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
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
  throw "Phase4 hosted memory-search-contract proof requires HTTPS"
}

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/memory/search/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "contract version" ($contract.contract_version -eq "memory-search-runtime-v1")
Assert-True "results section visible" (@($contract.top_level_sections) -contains "results")
Assert-True "search mode parity" ($contract.search_mode -eq "lexical_fallback")
Assert-True "result field relevance_score visible" (@($contract.result_fields) -contains "relevance_score")

$embedding = Invoke-JsonApi -url "$BaseUrl/api/v1/memory/embedding-consistency/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "embedding contract search mode parity" ($embedding.current_embedding.search_mode -eq $contract.search_mode)

$projectId = "hosted-phase4-memory-search-contract-" + [Guid]::NewGuid().ToString("N")
$needle = "phase4 hosted memory search " + [Guid]::NewGuid().ToString("N")
$promptBody = @{
  project_id = $projectId
  prompt = $needle
  stream = $false
} | ConvertTo-Json -Compress
$created = Invoke-JsonApi -url "$BaseUrl/api/v1/prompt" -method "POST" -body $promptBody -contentType "application/json" -timeoutSeconds 20
Assert-True "session id returned" (-not [string]::IsNullOrWhiteSpace($created.session_id))
$sessionId = [string]$created.session_id

$encodedNeedle = [uri]::EscapeDataString([string]$needle)
$search = Invoke-JsonApi -url "$BaseUrl/api/v1/memory/search?q=$encodedNeedle&project_id=$projectId&limit=5&threshold=0.0" -method "GET" -contentType $null -timeoutSeconds 20
foreach ($section in @($contract.top_level_sections)) {
  Assert-True "top level section visible $section" ($search.PSObject.Properties.Name -contains [string]$section)
}
Assert-True "runtime search mode parity" ($search.search_mode -eq $contract.search_mode)

$result = @($search.results) | Select-Object -First 1
Assert-True "search result visible" ($null -ne $result)
foreach ($field in @($contract.result_fields)) {
  Assert-True "result field visible $field" ($result.PSObject.Properties.Name -contains [string]$field)
}
Assert-True "needle found" (($result.content | Out-String).Contains($needle))
Assert-True "session parity" ($result.session_id -eq $sessionId)
Assert-True "relevance score threshold parity" ([double]$result.relevance_score -ge 0.0)

Write-Host "[phase4-memory-search-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-memory-search-contract-runtime] result=verified"

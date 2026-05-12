param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted memory-consolidation-contract runtime verification failed: $label"
  }
}

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase4 hosted memory-consolidation-contract runtime verification failed: $label did not contain '$expected'. Value: $text"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-memory-consolidation-contract-runtime-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted memory-consolidation-contract runtime verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
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
  throw "Phase4 hosted memory-consolidation-contract proof requires HTTPS"
}

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/memory/consolidation/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "contract version" ($contract.contract_version -eq "memory-consolidation-feed-v1")
Assert-True "events section visible" (@($contract.top_level_sections) -contains "events")
Assert-True "summary section visible" (@($contract.top_level_sections) -contains "summary")
Assert-True "memory_consolidated supported" (@($contract.supported_event_types) -contains "memory_consolidated")

$feed = Invoke-JsonApi -url "$BaseUrl/api/v1/memory/consolidation/recent?limit=20" -method "GET" -contentType $null -timeoutSeconds 20
foreach ($section in @($contract.top_level_sections)) {
  Assert-True "top level section visible $section" ($feed.PSObject.Properties.Name -contains [string]$section)
}

$event = @($feed.events) | Where-Object { $_.event_type -eq "memory_consolidated" } | Select-Object -First 1
Assert-True "consolidation event visible" ($null -ne $event)
foreach ($field in @($contract.event_fields)) {
  Assert-True "event field visible $field" ($event.PSObject.Properties.Name -contains [string]$field)
}
Assert-True "event type parity" ($event.event_type -eq "memory_consolidated")
Assert-True "event has session id" (-not [string]::IsNullOrWhiteSpace([string]$event.session_id))
Assert-True "detail memory id visible" (-not [string]::IsNullOrWhiteSpace([string]$event.details.memory_id))
Assert-True "detail redis key visible" (-not [string]::IsNullOrWhiteSpace([string]$event.details.redis_key))
Assert-True "detail project id visible" (-not [string]::IsNullOrWhiteSpace([string]$event.details.project_id))
Assert-True "detail ttl visible" ([int]$event.details.ttl_seconds -ge 0)
Assert-True "detail idempotency visible" (-not [string]::IsNullOrWhiteSpace([string]$event.details.idempotency_key))
Assert-True "detail transaction id visible" (-not [string]::IsNullOrWhiteSpace([string]$event.details.memory_transaction_id))

$summary = @($feed.summary) | Where-Object { $_.event_type -eq "memory_consolidated" -and $_.severity -eq "info" } | Select-Object -First 1
Assert-True "summary row visible" ($null -ne $summary)
foreach ($field in @($contract.summary_fields)) {
  Assert-True "summary field visible $field" ($summary.PSObject.Properties.Name -contains [string]$field)
}

$metrics = Invoke-WebResponse -url "$BaseUrl/api/v1/metrics" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "metrics http 200" ($metrics.StatusCode -eq 200)
Assert-Contains "metrics consolidation counter" $metrics.Content 'superbrain_memory_consolidation_events_total{event_type="memory_consolidated",reason="none",severity="info"}'

Write-Host "[phase4-memory-consolidation-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-memory-consolidation-contract-runtime] result=verified"

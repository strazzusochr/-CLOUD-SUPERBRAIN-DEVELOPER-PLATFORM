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
    throw "Phase4 hosted rotation-events contract verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-rotation-events-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted rotation-events contract verification failed: $method $url returned HTTP $($response.status_code). Value: $($response.content)"
  }
  return ($response.content | ConvertFrom-Json)
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted rotation-events proof requires HTTPS" }

Write-Host "[phase4-rotation-events-contract-runtime] base_url=$BaseUrl"

$contract = Invoke-JsonApi "$BaseUrl/api/v1/rotation/events/contract"
$runtimeBefore = Invoke-JsonApi "$BaseUrl/api/v1/rotation/events?limit=20"

Assert-True "contract version" ($contract.contract_version -eq "rotation-events-feed-v1")
Assert-True "event contract version" ($contract.event_contract_version -eq "provider-fallback-event-v1")
foreach ($field in $contract.required_top_level_fields) {
  Assert-True "top-level field $field present" ($null -ne $runtimeBefore.$field)
}

$sessionId = [guid]::NewGuid().ToString()
$traceId = "rotation-events-proof-" + ([guid]::NewGuid().ToString("N"))
$eventBody = @{
  session_id = $sessionId
  from_provider = "huggingface_inference_router"
  to_provider = "huggingface_inference_router"
  from_model = "deepseek-ai/DeepSeek-V4-Flash:fastest"
  to_model = "Qwen/Qwen3.6-35B-A3B:fastest"
  reason = "timeout"
  agent = "devops"
  trace_id = $traceId
  fallback_index = 1
  routing_policy_decision = "allow_fallback"
  input_tokens = 256
  output_tokens = 32
  estimated_cost_cents = 4
  budget_level = "ok"
} | ConvertTo-Json -Compress

$created = Invoke-JsonApi "$BaseUrl/internal/rotation/events" "POST" $eventBody
Assert-True "created event type" ($created.event_type -eq "provider_rotated")
Assert-True "created contract version" ($created.contract_version -eq "provider-fallback-event-v1")

$runtime = Invoke-JsonApi "$BaseUrl/api/v1/rotation/events?limit=20"
$match = $runtime.events | Where-Object { $_.session_id -eq $sessionId } | Select-Object -First 1
Assert-True "rotation event visible" ($null -ne $match)
foreach ($field in $contract.required_event_top_level_fields) {
  Assert-True "event top-level field $field present" ($null -ne $match.$field)
}
foreach ($field in $contract.required_event_detail_fields) {
  Assert-True "event detail field $field present" ($null -ne $match.details.$field)
}
Assert-True "event evidence ref" ($match.details.evidence_ref -eq "provider_fallback_structured_event")
Assert-True "event trace id roundtrip" ($match.details.trace_id -eq $traceId)

Write-Host "[phase4-rotation-events-contract-runtime] result=verified"

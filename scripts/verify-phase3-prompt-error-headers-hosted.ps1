param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase3 hosted prompt/error/header verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Invoke-WebResponse(
  [string]$Url,
  [string]$Method = "GET",
  [string]$Body = "",
  [hashtable]$Headers = $null,
  [string]$ContentType = "",
  [int]$TimeoutSeconds = 15
) {
  $payload = [ordered]@{
    url = $Url
    method = $Method
    timeout_seconds = $TimeoutSeconds
    headers = $Headers
  }
  if ($Body) {
    $payload.body_b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Body))
  }
  if ($ContentType) {
    $payload.content_type = $ContentType
  }
  $payloadJson = $payload | ConvertTo-Json -Compress -Depth 6
  $payloadFile = Join-Path $env:TEMP ("phase3-hosted-headers-" + [Guid]::NewGuid().ToString("N") + ".json")
  $pythonFile = Join-Path $env:TEMP ("phase3-hosted-headers-" + [Guid]::NewGuid().ToString("N") + ".py")
  try {
    Set-Content -LiteralPath $payloadFile -Value $payloadJson -NoNewline -Encoding utf8
    $pythonScript = @'
import base64
import json
import sys
import urllib.error
import urllib.request

with open(sys.argv[1], "r", encoding="utf-8-sig") as handle:
    payload = json.load(handle)

data = None
if payload.get("body_b64"):
    data = base64.b64decode(payload["body_b64"])

headers = payload.get("headers") or {}
if payload.get("content_type"):
    headers["Content-Type"] = payload["content_type"]

request = urllib.request.Request(
    payload["url"],
    data=data,
    headers=headers,
    method=payload.get("method", "GET"),
)

try:
    with urllib.request.urlopen(request, timeout=payload.get("timeout_seconds", 15)) as response:
        body = response.read().decode("utf-8", errors="replace")
        result = {
            "status_code": response.getcode(),
            "body": body,
            "headers": dict(response.headers.items()),
        }
except urllib.error.HTTPError as exc:
    result = {
        "status_code": exc.code,
        "body": exc.read().decode("utf-8", errors="replace"),
        "headers": dict(exc.headers.items()),
    }
print(json.dumps(result))
'@
    Set-Content -LiteralPath $pythonFile -Value $pythonScript -NoNewline -Encoding utf8
    $raw = py -3 $pythonFile $payloadFile 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
      throw $raw.Trim()
    }
    return ($raw | ConvertFrom-Json)
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
    if (Test-Path $pythonFile) { Remove-Item -LiteralPath $pythonFile -Force }
  }
}

function Invoke-Text($url) {
  return (Invoke-WebResponse -Url $url -Method "GET").body
}

function Invoke-HeadersText($url, [hashtable]$headers = $null) {
  $response = Invoke-WebResponse -Url $url -Method "GET" -Headers $headers
  $lines = @()
  foreach ($header in $response.headers.PSObject.Properties) {
    $value = $header.Value
    if ($value -is [System.Array]) {
      $value = $value -join ", "
    }
    $lines += ("{0}: {1}" -f $header.Name.ToLowerInvariant(), $value)
  }
  return ($lines -join "`n")
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") {
  throw "Phase3 hosted prompt/error/header proof requires HTTPS"
}

Write-Host "[phase3-hosted-prompt-error-headers] base url: $BaseUrl"

$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "frontend prompt input guard" $frontendHtml "Prompt Input Guard"
Assert-Contains "frontend prompt counter evidence" $frontendHtml "prompt_input_counter_visible"
Assert-Contains "frontend error response contract" $frontendHtml "Error Response Contract"
Assert-Contains "frontend error response evidence" $frontendHtml "error_response_ui_state_visible"
Assert-Contains "frontend security headers contract" $frontendHtml "Security Headers Contract"
Assert-Contains "frontend trace id contract" $frontendHtml "Trace ID Contract"
Assert-Contains "frontend cache control contract" $frontendHtml "Cache Control Contract"
Assert-Contains "frontend request id contract" $frontendHtml "Request ID Contract"

$promptContract = Invoke-Text "$BaseUrl/api/v1/prompt/contract"
Assert-Contains "prompt contract version" $promptContract '"contract_version":"prompt-input-contract-v1"'
Assert-Contains "prompt contract endpoint" $promptContract "POST /api/v1/prompt"
Assert-Contains "prompt max chars" $promptContract '"max_prompt_chars":10000'
Assert-Contains "prompt visible evidence" $promptContract "prompt_input_contract_visible"
Assert-Contains "prompt counter evidence" $promptContract "prompt_input_counter_visible"
Assert-Contains "prompt 422 evidence" $promptContract "prompt_input_422_enforced"

$promptOverflowProjectId = "hosted-prompt-overflow-" + [Guid]::NewGuid().ToString("N")
$promptOverflowRequestId = "hosted-request-error-" + [Guid]::NewGuid().ToString("N")
$promptOverflowBody = @{
  project_id = $promptOverflowProjectId
  prompt = ("x" * 10001)
  stream = $true
} | ConvertTo-Json -Compress
$promptOverflowResponse = Invoke-WebResponse -Url "$BaseUrl/api/v1/prompt" -Method "POST" -Body $promptOverflowBody -Headers @{ "x-request-id" = $promptOverflowRequestId } -ContentType "application/json" -TimeoutSeconds 12
if ([int]$promptOverflowResponse.status_code -ne 422) {
  throw "Phase3 hosted prompt/error/header verification failed: prompt overflow returned HTTP $($promptOverflowResponse.status_code)"
}
Assert-Contains "prompt overflow error type" $promptOverflowResponse.body "string_too_long"
Assert-Contains "prompt overflow request id" $promptOverflowResponse.body $promptOverflowRequestId

$errorContract = Invoke-Text "$BaseUrl/api/v1/errors/contract"
Assert-Contains "error contract version" $errorContract '"contract_version":"error-response-contract-v1"'
Assert-Contains "error envelope evidence" $errorContract "error_response_envelope_enforced"

$securityHeadersContract = Invoke-Text "$BaseUrl/api/v1/security/headers/contract"
Assert-Contains "security headers contract version" $securityHeadersContract '"contract_version":"security-headers-v1"'
Assert-Contains "security headers evidence" $securityHeadersContract "security_headers_enforced"
$securityHeaderProbe = Invoke-HeadersText "$BaseUrl/api/v1/health"
Assert-Contains "security header csp" $securityHeaderProbe "content-security-policy:"
Assert-Contains "security header frame options" $securityHeaderProbe "x-frame-options: DENY"
Assert-Contains "security header content type nosniff" $securityHeaderProbe "x-content-type-options: nosniff"
Assert-Contains "security header referrer" $securityHeaderProbe "referrer-policy: no-referrer"
Assert-Contains "security header contract marker" $securityHeaderProbe "x-superbrain-security-contract: security-headers-v1"

$traceContract = Invoke-Text "$BaseUrl/api/v1/trace/contract"
Assert-Contains "trace contract version" $traceContract '"contract_version":"trace-id-propagation-v1"'
Assert-Contains "trace roundtrip evidence" $traceContract "trace_id_header_roundtrip"
$traceProbeId = "hosted-trace-proof-" + [Guid]::NewGuid().ToString("N")
$traceHeaderProbe = Invoke-HeadersText -url "$BaseUrl/api/v1/health" -headers @{ "x-trace-id" = $traceProbeId }
Assert-Contains "trace id response header roundtrip" $traceHeaderProbe "x-trace-id: $traceProbeId"
Assert-Contains "trace contract marker" $traceHeaderProbe "x-superbrain-trace-contract: trace-id-propagation-v1"

$cacheControlContract = Invoke-Text "$BaseUrl/api/v1/cache/contract"
Assert-Contains "cache control contract version" $cacheControlContract '"contract_version":"cache-control-no-store-v1"'
Assert-Contains "cache control evidence" $cacheControlContract "cache_control_headers_enforced"
$cacheHeaderProbe = Invoke-HeadersText "$BaseUrl/api/v1/costs"
Assert-Contains "cache header no-store" $cacheHeaderProbe "cache-control: no-store"
Assert-Contains "cache header pragma" $cacheHeaderProbe "pragma: no-cache"
Assert-Contains "cache header expires" $cacheHeaderProbe "expires: 0"
Assert-Contains "cache contract marker" $cacheHeaderProbe "x-superbrain-cache-contract: cache-control-no-store-v1"

$requestContract = Invoke-Text "$BaseUrl/api/v1/request/contract"
Assert-Contains "request id contract version" $requestContract '"contract_version":"request-id-correlation-v1"'
Assert-Contains "request roundtrip evidence" $requestContract "request_id_header_roundtrip"
Assert-Contains "request audit evidence" $requestContract "request_id_audit_correlation"
$requestProbeId = "hosted-request-proof-" + [Guid]::NewGuid().ToString("N")
$requestHeaderProbe = Invoke-HeadersText -url "$BaseUrl/api/v1/health" -headers @{ "x-request-id" = $requestProbeId }
Assert-Contains "request id response header roundtrip" $requestHeaderProbe "x-request-id: $requestProbeId"
Assert-Contains "request contract marker" $requestHeaderProbe "x-superbrain-request-contract: request-id-correlation-v1"

Write-Host "[phase3-hosted-prompt-error-headers] checks completed"

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


function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase3 hosted auth verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase3 hosted auth verification failed: $label"
  }
}

function Invoke-JsonApi(
  [string]$Url,
  [string]$Method = "GET",
  [string]$Body = "",
  [string]$ContentType = "application/json",
  [int]$TimeoutSeconds = 15
) {
  $payload = [ordered]@{
    url = $Url
    method = $Method
    timeout_seconds = $TimeoutSeconds
  }
  if ($Body) {
    $payload.body_b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Body))
  }
  if ($ContentType) {
    $payload.content_type = $ContentType
  }
  $payloadJson = $payload | ConvertTo-Json -Compress -Depth 6
  $payloadFile = Join-Path $env:TEMP ("phase3-hosted-auth-" + [Guid]::NewGuid().ToString("N") + ".json")
  $pythonFile = Join-Path $env:TEMP ("phase3-hosted-auth-" + [Guid]::NewGuid().ToString("N") + ".py")
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

headers = {}
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
        body = response.read().decode("utf-8")
        print(body)
except urllib.error.HTTPError as exc:
    print(exc.read().decode("utf-8"))
    sys.exit(exc.code)
'@
    Set-Content -LiteralPath $pythonFile -Value $pythonScript -NoNewline -Encoding utf8
    $output = py -3 $pythonFile $payloadFile 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
      throw $output.Trim()
    }
    return $output
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
    if (Test-Path $pythonFile) { Remove-Item -LiteralPath $pythonFile -Force }
  }
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") {
  throw "Phase3 hosted auth proof requires HTTPS"
}

Write-Host "[phase3-hosted-auth] base url: $BaseUrl"

$frontendHtml = Invoke-JsonApi -Url "$BaseUrl/"
Assert-Contains "frontend auth panel" $frontendHtml "Auth Contract"
Assert-Contains "frontend fallback panel" $frontendHtml "System Unavailable Fallback"

powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-phase3-auth-fail-closed.ps1 -BaseUrl $BaseUrl
if ($LASTEXITCODE -ne 0) { throw "Phase3 hosted auth verification failed: credential issuance fail-closed verifier" }

$systemFallbackContract = Invoke-JsonApi -Url "$BaseUrl/api/v1/system/fallback/contract"
Assert-Contains "system fallback version" $systemFallbackContract '"contract_version":"system-unavailable-fallback-v1"'
Assert-Contains "system fallback ui state" $systemFallbackContract '"ui_state":"System Unavailable"'
Assert-Contains "system fallback no fake healthy policy" $systemFallbackContract "no_fake_healthy_claim"

Write-Host "[phase3-hosted-auth] checks completed"

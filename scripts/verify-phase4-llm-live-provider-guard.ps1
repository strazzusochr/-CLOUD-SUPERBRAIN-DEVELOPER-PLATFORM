param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "LLM live provider guard verification failed: $label"
  }
}

function Invoke-RawHttp($Url, $Method = "GET", $Body = $null) {
  $payload = [ordered]@{
    url = $Url
    method = $Method
  }
  if ($null -ne $Body) {
    $payload.body_b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes([string]$Body))
  }
  $payloadFile = Join-Path $env:TEMP ("llm-guard-http-" + [Guid]::NewGuid().ToString("N") + ".json")
  $pythonFile = Join-Path $env:TEMP ("llm-guard-http-" + [Guid]::NewGuid().ToString("N") + ".py")
  try {
    Set-Content -LiteralPath $payloadFile -Value ($payload | ConvertTo-Json -Compress -Depth 5) -NoNewline -Encoding utf8
    $pythonScript = @'
import base64
import json
import sys
import urllib.error
import urllib.request

with open(sys.argv[1], "r", encoding="utf-8-sig") as handle:
    payload = json.load(handle)

data = None
headers = {}
if payload.get("body_b64"):
    data = base64.b64decode(payload["body_b64"])
    headers["Content-Type"] = "application/json"

request = urllib.request.Request(payload["url"], data=data, headers=headers, method=payload.get("method", "GET"))
try:
    with urllib.request.urlopen(request, timeout=60) as response:
        content = response.read().decode("utf-8", errors="replace")
        print(json.dumps({"StatusCode": response.status, "Content": content}))
except urllib.error.HTTPError as exc:
    content = exc.read().decode("utf-8", errors="replace")
    print(json.dumps({"StatusCode": exc.code, "Content": content}))
'@
    Set-Content -LiteralPath $pythonFile -Value $pythonScript -NoNewline -Encoding utf8
    $output = py -3 $pythonFile $payloadFile
    if ($LASTEXITCODE -ne 0) {
      throw ($output | Out-String)
    }
    return ($output | ConvertFrom-Json)
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
    if (Test-Path $pythonFile) { Remove-Item -LiteralPath $pythonFile -Force }
  }
}

function Invoke-JsonApi($url, $method = "GET", $body = $null) {
  $response = Invoke-RawHttp -Url $url -Method $method -Body $body
  if ([int]$response.StatusCode -ge 400) {
    throw "$method $url returned HTTP $($response.StatusCode): $($response.Content)"
  }
  return ($response.Content | ConvertFrom-Json)
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ((-not $AllowLocalhost) -and ($BaseUrl -match "localhost|127\.0\.0\.1|\[::1\]")) {
  throw "LLM live provider guard proof refuses localhost unless -AllowLocalhost is set"
}

Write-Host "[phase4-llm-live-provider-guard] base url: $BaseUrl"

$providers = Invoke-JsonApi "$BaseUrl/llm/api/v1/providers/status"
Assert-True "providers policy exposes override guard" ($providers.policy.request_live_provider_override_enabled -eq $false)
Assert-True "providers policy explains metadata guard" ([string]$providers.policy.requires_request_metadata -match "LLM_ALLOW_REQUEST_LIVE_PROVIDER_OVERRIDE=true")

$chatBody = @{
  model = "deepseek-ai/DeepSeek-V4-Flash:fastest"
  stream = $false
  messages = @(
    @{ role = "user"; content = "Return a deterministic dry-run proof." }
  )
  metadata = @{
    live_provider_calls_allowed = $true
    source = "phase4-live-provider-guard"
  }
} | ConvertTo-Json -Compress -Depth 6

$chat = Invoke-JsonApi "$BaseUrl/llm/v1/chat/completions" "POST" $chatBody
Assert-True "chat remains deterministic" ($chat.live_provider_calls -eq $false)
Assert-True "chat proof text" ([string]$chat.choices[0].message.content -match "live_provider_calls=false")

$responsesBody = @{
  model = "deepseek-ai/DeepSeek-V4-Flash:fastest"
  input = "Return a deterministic responses proof."
  metadata = @{
    live_provider_calls_allowed = $true
    source = "phase4-live-provider-guard"
  }
} | ConvertTo-Json -Compress -Depth 6

$responses = Invoke-JsonApi "$BaseUrl/llm/v1/responses" "POST" $responsesBody
Assert-True "responses remains deterministic" ($responses.live_provider_calls -eq $false)
Assert-True "responses proof text" ([string]$responses.output_text -match "live_provider_calls=false")
Assert-True "responses audit persisted flag present" ($null -ne $responses.audit_persisted)

Write-Host "[phase4-llm-live-provider-guard] ok"

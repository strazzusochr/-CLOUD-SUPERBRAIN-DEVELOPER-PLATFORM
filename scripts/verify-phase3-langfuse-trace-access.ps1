param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase3 Langfuse trace access verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase3 Langfuse trace access verification failed: $label"
  }
}

function Invoke-WebResponse(
  [string]$Url,
  [string]$Method = "GET",
  [string]$Body = "",
  [string]$ContentType = "application/json",
  [int]$TimeoutSeconds = 30
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
  $payloadFile = Join-Path $env:TEMP ("phase3-langfuse-trace-" + [Guid]::NewGuid().ToString("N") + ".json")
  $pythonFile = Join-Path $env:TEMP ("phase3-langfuse-trace-" + [Guid]::NewGuid().ToString("N") + ".py")
  try {
    Set-Content -LiteralPath $payloadFile -Value ($payload | ConvertTo-Json -Compress -Depth 6) -NoNewline -Encoding utf8
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

request = urllib.request.Request(payload["url"], data=data, headers=headers, method=payload.get("method", "GET"))
try:
    with urllib.request.urlopen(request, timeout=payload.get("timeout_seconds", 30)) as response:
        body = response.read().decode("utf-8", errors="replace")
        print(json.dumps({"status_code": response.getcode(), "body": body, "headers": dict(response.headers.items())}))
except urllib.error.HTTPError as exc:
    print(json.dumps({"status_code": exc.code, "body": exc.read().decode("utf-8", errors="replace"), "headers": dict(exc.headers.items())}))
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

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ((-not $AllowLocalhost) -and ($BaseUrl -match "localhost|127\.0\.0\.1|\[::1\]")) {
  throw "Phase3 Langfuse trace access proof refuses localhost unless -AllowLocalhost is set"
}

Write-Host "[phase3-langfuse-trace-access] base url: $BaseUrl"

$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "frontend agent activity panel" $frontendHtml "Agent Activity"
Assert-Contains "frontend trace access panel" $frontendHtml "Langfuse Trace Access"
Assert-Contains "frontend contract marker" $frontendHtml "langfuse-trace-access-v1"
Assert-Contains "frontend evidence marker" $frontendHtml "langfuse_trace_access_visible"
Assert-Contains "frontend event evidence marker" $frontendHtml "langfuse_trace_event_visible"
Assert-Contains "frontend endpoint marker" $frontendHtml "GET /api/v1/observability/langfuse/trace/{trace_id}"

$contract = Invoke-Text "$BaseUrl/api/v1/observability/langfuse/contract"
Assert-Contains "contract version" $contract '"contract_version":"langfuse-trace-access-v1"'
Assert-Contains "contract endpoint" $contract "GET /api/v1/observability/langfuse/trace/{trace_id}"
Assert-Contains "contract evidence" $contract "langfuse_trace_access_visible"
Assert-Contains "contract event evidence" $contract "langfuse_trace_event_visible"
Assert-Contains "contract read only" $contract '"read_only":true'
Assert-Contains "contract provider export false" $contract '"provider_trace_export":false'
Assert-Contains "contract auth proxy" $contract '"auth_proxy_required":true'

$traceId = "phase3-langfuse-trace-" + [Guid]::NewGuid().ToString("N")
$body = @{
  model = "deepseek-ai/DeepSeek-V4-Flash:fastest"
  messages = @(@{ role = "user"; content = "phase3 langfuse trace access proof" })
  stream = $false
  metadata = @{
    trace_id = $traceId
    agent_type = "tester"
  }
} | ConvertTo-Json -Compress -Depth 8

$seed = Invoke-WebResponse -Url "$BaseUrl/llm/v1/chat/completions" -Method "POST" -Body $body -ContentType "application/json"
Assert-True "llm dry-run accepted" ([int]$seed.status_code -eq 200)
Assert-Contains "llm dry-run no live call" $seed.body '"live_provider_calls":false'
Assert-Contains "llm dry-run audit persisted" $seed.body '"audit_persisted":true'

$trace = Invoke-Text "$BaseUrl/api/v1/observability/langfuse/trace/${traceId}?limit=20"
Assert-Contains "trace contract" $trace '"contract_version":"langfuse-trace-access-v1"'
Assert-Contains "trace id visible" $trace $traceId
Assert-Contains "trace event source" $trace "llm_gateway_request"
Assert-Contains "trace model visible" $trace "deepseek-ai/DeepSeek-V4-Flash:fastest"
Assert-Contains "trace evidence" $trace "langfuse_trace_access_visible"
Assert-Contains "trace event evidence" $trace "langfuse_trace_event_visible"
Assert-Contains "trace provider export false" $trace '"provider_trace_export":false'
Assert-Contains "trace auth proxy" $trace '"auth_proxy_required":true'
Assert-Contains "trace read only" $trace '"read_only":true'

Write-Host "status=verified"
Write-Host "contract_version=langfuse-trace-access-v1"
Write-Host "evidence_ref=langfuse_trace_access_visible"

param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase3 LLM audit feed verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase3 LLM audit feed verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase3-llm-audit-" + [Guid]::NewGuid().ToString("N") + ".json")
  $pythonFile = Join-Path $env:TEMP ("phase3-llm-audit-" + [Guid]::NewGuid().ToString("N") + ".py")
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
  throw "Phase3 LLM audit feed proof refuses localhost unless -AllowLocalhost is set"
}

Write-Host "[phase3-llm-audit-feed] base url: $BaseUrl"

$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "frontend llm audit feed panel" $frontendHtml "LLM Audit Feed"
Assert-Contains "frontend llm audit contract" $frontendHtml "llm-audit-feed-v1"
Assert-Contains "frontend llm audit evidence" $frontendHtml "llm_audit_feed_visible"
Assert-Contains "frontend llm audit endpoint" $frontendHtml "GET /api/v1/audit/llm"

$contract = Invoke-Text "$BaseUrl/api/v1/audit/llm/contract"
Assert-Contains "contract version" $contract '"contract_version":"llm-audit-feed-v1"'
Assert-Contains "contract endpoint" $contract "GET /api/v1/audit/llm"
Assert-Contains "contract source" $contract '"source_event_type":"llm_gateway_request"'
Assert-Contains "contract evidence" $contract "llm_audit_feed_visible"
Assert-Contains "contract event evidence" $contract "llm_audit_feed_event_visible"
Assert-Contains "contract read only" $contract '"read_only":true'
Assert-Contains "contract no live claim" $contract '"live_provider_calls_claimed":false'

$traceId = "phase3-llm-audit-" + [Guid]::NewGuid().ToString("N")
$body = @{
  model = "deepseek-ai/DeepSeek-V4-Flash:fastest"
  messages = @(@{ role = "user"; content = "phase3 llm audit feed proof" })
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
Assert-Contains "llm dry-run provider" $seed.body '"provider_name":"deterministic-dry-run"'

$feed = Invoke-Text "$BaseUrl/api/v1/audit/llm?limit=30"
Assert-Contains "feed contract" $feed '"contract_version":"llm-audit-feed-v1"'
Assert-Contains "feed source" $feed '"source_event_type":"llm_gateway_request"'
Assert-Contains "feed read only" $feed '"read_only":true'
Assert-Contains "feed no live claim" $feed '"live_provider_calls_claimed":false'
Assert-Contains "feed trace visible" $feed $traceId
Assert-Contains "feed model visible" $feed "deepseek-ai/DeepSeek-V4-Flash:fastest"
Assert-Contains "feed provider visible" $feed "deterministic-dry-run"
Assert-Contains "feed live false" $feed '"live_provider_calls":false'
Assert-Contains "feed cost zero" $feed '"cost_cents":0'
Assert-Contains "feed evidence" $feed "llm_audit_feed_visible"
Assert-Contains "feed event evidence" $feed "llm_audit_feed_event_visible"

Write-Host "status=verified"
Write-Host "contract_version=llm-audit-feed-v1"
Write-Host "evidence_ref=llm_audit_feed_visible"

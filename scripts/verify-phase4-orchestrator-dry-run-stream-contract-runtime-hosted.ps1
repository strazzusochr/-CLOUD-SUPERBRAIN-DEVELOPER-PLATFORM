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
    throw "Phase4 hosted orchestrator-dry-run-stream-contract verification failed: $label"
  }
}

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase4 hosted orchestrator-dry-run-stream-contract verification failed: $label did not contain '$expected'. Value: $text"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-orchestrator-dry-run-stream-contract-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted orchestrator-dry-run-stream-contract verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) { return $null }
  return ($response.Content | ConvertFrom-Json)
}

function Invoke-SseText($url, $body, [hashtable]$headers = $null, $maxTime = 20) {
  $bodyBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$body))
  $payload = [pscustomobject]@{
    url = $url
    bodyBase64 = $bodyBase64
    headers = $headers
    maxTime = $maxTime
  } | ConvertTo-Json -Depth 8 -Compress
  $python = @'
import base64, json, ssl, sys, time, urllib.request
with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)
data = base64.b64decode(payload["bodyBase64"].encode("ascii"))
headers = payload.get("headers") or {}
headers["Content-Type"] = "application/json"
request = urllib.request.Request(payload["url"], data=data, headers=headers, method="POST")
context = ssl._create_unverified_context() if payload["url"].startswith("https://") else None
deadline = time.time() + payload.get("maxTime", 20)
chunks = []
with urllib.request.urlopen(request, timeout=5, context=context) as response:
    while time.time() < deadline:
        line = response.readline()
        if not line:
            break
        text = line.decode("utf-8", errors="replace")
        chunks.append(text)
        if text.startswith("event: done"):
            break
print("".join(chunks))
'@
  $payloadFile = Join-Path $env:TEMP ("phase4-orchestrator-dry-run-stream-sse-" + [Guid]::NewGuid().ToString("N") + ".json")
  try {
    Set-Content -LiteralPath $payloadFile -Value $payload -NoNewline
    return ($python | py -3 - $payloadFile)
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
  }
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted orchestrator-dry-run-stream-contract proof requires HTTPS" }

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/orchestrator/dry-run/stream/contract" -method "GET" -contentType $null -timeoutSeconds 20
$body = @{
  project_id = "hosted-phase4-orchestrator-dry-run-stream-" + [Guid]::NewGuid().ToString("N")
  prompt = "hosted phase4 orchestrator dry run stream contract verifier"
  session_id = [Guid]::NewGuid().ToString()
} | ConvertTo-Json -Compress
$stream = Invoke-SseText -url "$BaseUrl/api/v1/orchestrator/dry-run/stream" -body $body -maxTime 20
$replay = Invoke-SseText -url "$BaseUrl/api/v1/orchestrator/dry-run/stream" -body $body -headers @{ "Last-Event-ID" = "0" } -maxTime 10

Assert-True "surface contract version" ($contract.contract_version -eq "orchestrator-dry-run-stream-surface-v1")
Assert-True "endpoint parity" ($contract.endpoint -eq "GET /api/v1/orchestrator/dry-run/stream/contract")
Assert-True "runtime endpoint parity" ($contract.runtime_endpoint -eq "POST /api/v1/orchestrator/dry-run/stream")
Assert-True "content type parity" ($contract.content_type -eq "text/event-stream")
Assert-True "replay header parity" ($contract.replay_header -eq "Last-Event-ID")
Assert-True "required done event" (@($contract.required_event_types) -contains "done")

Assert-Contains "stream heartbeat" $stream "event: heartbeat"
Assert-Contains "stream agent status" $stream "event: agent_status"
Assert-Contains "stream done" $stream "event: done"
Assert-Contains "stream contract version" $stream "phase2-sse-event-contract-v1"
Assert-Contains "stream evidence ref" $stream "phase2_sse_event_contract_proof"
Assert-Contains "stream live provider false" $stream '"live_provider_calls":false'
Assert-Contains "replay flag" $replay '"replay":true'

Write-Host "[phase4-orchestrator-dry-run-stream-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-orchestrator-dry-run-stream-contract-runtime] result=verified"

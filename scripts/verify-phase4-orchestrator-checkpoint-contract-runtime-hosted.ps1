param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted orchestrator-checkpoint-contract verification failed: $label"
  }
}

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase4 hosted orchestrator-checkpoint-contract verification failed: $label did not contain '$expected'. Value: $text"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-orchestrator-checkpoint-contract-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted orchestrator-checkpoint-contract verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

function Invoke-SseText($url, $body, $maxTime = 20) {
  $payload = $body
  $bodyBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$payload))
  $json = [pscustomobject]@{
    url = $url
    method = "POST"
    bodyBase64 = $bodyBase64
    headers = @{}
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
  $payloadFile = Join-Path $env:TEMP ("phase4-orchestrator-checkpoint-sse-" + [Guid]::NewGuid().ToString("N") + ".json")
  try {
    Set-Content -LiteralPath $payloadFile -Value $json -NoNewline
    return ($python | py -3 - $payloadFile)
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
  }
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted orchestrator-checkpoint-contract proof requires HTTPS" }

$threadId = [Guid]::NewGuid().ToString()
$body = @{
  project_id = "hosted-phase4-orchestrator-checkpoint-contract-" + [Guid]::NewGuid().ToString("N")
  prompt = "hosted phase4 orchestrator checkpoint contract runtime verifier"
  session_id = $threadId
} | ConvertTo-Json -Compress

$stream = Invoke-SseText -url "$BaseUrl/api/v1/orchestrator/dry-run/stream" -body $body -maxTime 20
Assert-Contains "stream done" $stream "event: done"
Assert-Contains "stream checkpoint evidence" $stream "last_stable_checkpoint"

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/orchestrator/checkpoints/contract" -method "GET" -contentType $null -timeoutSeconds 20
$runtime = Invoke-JsonApi -url "$BaseUrl/api/v1/orchestrator/checkpoints/$threadId" -method "GET" -contentType $null -timeoutSeconds 20

Assert-True "surface contract version" ($contract.contract_version -eq "orchestrator-checkpoint-surface-v1")
Assert-True "endpoint parity" ($contract.endpoint -eq "GET /api/v1/orchestrator/checkpoints/contract")
Assert-True "runtime endpoint template parity" ($contract.runtime_endpoint_template -eq "GET /api/v1/orchestrator/checkpoints/{thread_id}")
Assert-True "required snapshot fields include values" (@($contract.required_snapshot_fields) -contains "values")
Assert-True "expected engine" ($contract.expected_engine -eq "langgraph")
Assert-True "expected checkpointing" ($contract.expected_checkpointing -eq "postgres")

Assert-True "runtime engine" ($runtime.engine -eq "langgraph")
Assert-True "runtime checkpointing" ($runtime.checkpointing -eq "postgres")
Assert-True "snapshot found" ([bool]$runtime.snapshot.found -eq $true)
Assert-True "thread id parity" ([string]$runtime.snapshot.thread_id -eq $threadId)
Assert-True "node name present" (-not [string]::IsNullOrWhiteSpace([string]$runtime.snapshot.values.node_name))

$runtimeText = $runtime | ConvertTo-Json -Depth 12 -Compress
Assert-Contains "snapshot stable checkpoint evidence" $runtimeText "last_stable_checkpoint"
Assert-Contains "snapshot aggregation evidence" $runtimeText "agent_result_aggregation_complete"
Assert-Contains "snapshot memory update evidence" $runtimeText "memory_update_persisted"

Write-Host "[phase4-orchestrator-checkpoint-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-orchestrator-checkpoint-contract-runtime] result=verified"

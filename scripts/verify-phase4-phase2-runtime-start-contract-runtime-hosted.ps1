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
    throw "Phase4 hosted phase2-runtime-start-contract verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-phase2-runtime-start-contract-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted phase2-runtime-start-contract verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) { return $null }
  return ($response.Content | ConvertFrom-Json)
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted phase2-runtime-start-contract proof requires HTTPS" }

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/phase2/runtime/start/contract" -method "GET" -contentType $null -timeoutSeconds 20
$body = @{
  project_id = "hosted-phase4-phase2-start-" + [Guid]::NewGuid().ToString("N")
  prompt = "hosted phase4 phase2 runtime start contract verifier"
  session_id = [Guid]::NewGuid().ToString()
} | ConvertTo-Json -Compress
$runtime = Invoke-JsonApi -url "$BaseUrl/api/v1/phase2/runtime/start" -method "POST" -body $body -contentType "application/json" -timeoutSeconds 30

Assert-True "surface contract version" ($contract.contract_version -eq "phase2-runtime-start-surface-v1")
Assert-True "endpoint parity" ($contract.endpoint -eq "GET /api/v1/phase2/runtime/start/contract")
Assert-True "runtime endpoint parity" ($contract.runtime_endpoint -eq "POST /api/v1/phase2/runtime/start")
Assert-True "runtime contract version parity" ($contract.runtime_contract_version -eq "phase2-runtime-v1")

Assert-True "runtime contract version" ($runtime.contract_version -eq "phase2-runtime-v1")
Assert-True "runtime status started" ($runtime.status -eq "started")
Assert-True "runtime engine" ($runtime.engine -eq "langgraph")
Assert-True "runtime mode" ($runtime.mode -eq "deterministic_local_runtime")
Assert-True "runtime checkpointing" ($runtime.checkpointing -eq "postgres")
Assert-True "runtime live provider false" ($runtime.live_provider_calls -eq $false)
Assert-True "runtime live mcp false" ($runtime.live_mcp_writes -eq $false)
Assert-True "runtime production false" ($runtime.production_deploy -eq $false)
Assert-True "runtime evidence ref" ($runtime.evidence_ref -eq "phase2_runtime_graph_started")
Assert-True "thread id visible" (-not [string]::IsNullOrWhiteSpace([string]$runtime.thread_id))
Assert-True "run id visible" (-not [string]::IsNullOrWhiteSpace([string]$runtime.run_id))
Assert-True "state node completed" ($runtime.state.node_name -eq "completed")
Assert-True "state evidence phase2 graph started" (@($runtime.state.evidence_refs) -contains "phase2_runtime_graph_started")
Assert-True "state evidence task assignment" (@($runtime.state.evidence_refs) -contains "task_assignment_completed")
Assert-True "state evidence memory update" (@($runtime.state.evidence_refs) -contains "memory_update_persisted")

Write-Host "[phase4-phase2-runtime-start-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-phase2-runtime-start-contract-runtime] result=verified"

param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted orchestrator-dry-run-contract verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-orchestrator-dry-run-contract-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted orchestrator-dry-run-contract verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) { return $null }
  return ($response.Content | ConvertFrom-Json)
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted orchestrator-dry-run-contract proof requires HTTPS" }

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/orchestrator/dry-run/contract" -method "GET" -contentType $null -timeoutSeconds 20
$body = @{
  project_id = "hosted-phase4-orchestrator-dry-run-" + [Guid]::NewGuid().ToString("N")
  prompt = "hosted phase4 orchestrator dry run contract verifier"
  session_id = [Guid]::NewGuid().ToString()
} | ConvertTo-Json -Compress
$runtime = Invoke-JsonApi -url "$BaseUrl/api/v1/orchestrator/dry-run" -method "POST" -body $body -contentType "application/json" -timeoutSeconds 30

Assert-True "surface contract version" ($contract.contract_version -eq "orchestrator-dry-run-surface-v1")
Assert-True "endpoint parity" ($contract.endpoint -eq "GET /api/v1/orchestrator/dry-run/contract")
Assert-True "runtime endpoint parity" ($contract.runtime_endpoint -eq "POST /api/v1/orchestrator/dry-run")
Assert-True "expected engine" ($contract.expected_engine -eq "langgraph")
Assert-True "expected mode" ($contract.expected_mode -eq "deterministic_dry_run")

Assert-True "runtime engine" ($runtime.engine -eq "langgraph")
Assert-True "runtime mode" ($runtime.mode -eq "deterministic_dry_run")
Assert-True "runtime live provider false" ($runtime.live_provider_calls -eq $false)
Assert-True "runtime checkpointing" ($runtime.checkpointing -eq "postgres")
Assert-True "runtime contract version anchor" ($runtime.contract_version -eq "phase2-runtime-v1")
Assert-True "runtime evidence ref anchor" ($runtime.evidence_ref -eq "orchestrator_dry_run_surface_contract_visible")
Assert-True "runtime thread id visible" (-not [string]::IsNullOrWhiteSpace([string]$runtime.thread_id))
Assert-True "state completed" ($runtime.state.node_name -eq "completed")
Assert-True "state llm gateway calls visible" (@($runtime.state.llm_gateway_calls).Count -ge 1)
Assert-True "state task assignments visible" (@($runtime.state.task_assignments).Count -ge 1)
Assert-True "state evidence llm stream" (@($runtime.state.evidence_refs) -contains "llm_gateway_streaming_dry_run")
Assert-True "state evidence task assignment" (@($runtime.state.evidence_refs) -contains "task_assignment_completed")

Write-Host "[phase4-orchestrator-dry-run-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-orchestrator-dry-run-contract-runtime] result=verified"

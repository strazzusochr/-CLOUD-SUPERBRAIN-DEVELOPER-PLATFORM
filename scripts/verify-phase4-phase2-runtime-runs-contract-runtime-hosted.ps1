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
    throw "Phase4 hosted phase2-runtime-runs-contract verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-phase2-runtime-runs-contract-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted phase2-runtime-runs-contract verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted phase2-runtime-runs-contract proof requires HTTPS" }

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/phase2/runtime/runs/contract" -method "GET" -contentType $null -timeoutSeconds 20
$runs = Invoke-JsonApi -url "$BaseUrl/api/v1/phase2/runtime/runs?limit=3" -method "GET" -contentType $null -timeoutSeconds 20

Assert-True "surface contract version" ($contract.contract_version -eq "phase2-runtime-runs-surface-v1")
Assert-True "endpoint parity" ($contract.endpoint -eq "GET /api/v1/phase2/runtime/runs/contract")
Assert-True "runtime endpoint parity" ($contract.runtime_endpoint -eq "GET /api/v1/phase2/runtime/runs")
Assert-True "runtime contract version parity" ($contract.runtime_contract_version -eq "phase2-runtime-v1")
Assert-True "required runs field" (@($contract.required_top_level_fields) -contains "runs")
Assert-True "required run checkpointing field" (@($contract.required_run_fields) -contains "checkpointing")
Assert-True "expected mode" ($contract.expected_mode -eq "audit_log_backed_phase2_runtime_runs")

Assert-True "runtime contract version" ($runs.contract_version -eq "phase2-runtime-v1")
Assert-True "runtime mode" ($runs.mode -eq $contract.expected_mode)
Assert-True "runtime source event type" ($runs.source_event_type -eq $contract.expected_source_event_type)
Assert-True "runtime evidence ref" ($runs.evidence_ref -eq "phase2_runtime_run_status_visible")
Assert-True "runs count positive" (@($runs.runs).Count -ge 1)

$latest = @($runs.runs)[0]
Assert-True "latest status allowed" (@($contract.expected_statuses) -contains [string]$latest.status)
Assert-True "latest checkpointing postgres" ($latest.checkpointing -eq "postgres")
Assert-True "latest no live provider calls" (-not [bool]$latest.live_provider_calls)
Assert-True "latest no live mcp writes" (-not [bool]$latest.live_mcp_writes)
Assert-True "latest no production deploy" (-not [bool]$latest.production_deploy)
Assert-True "latest thread id present" (-not [string]::IsNullOrWhiteSpace([string]$latest.thread_id))
Assert-True "latest run id present" (-not [string]::IsNullOrWhiteSpace([string]$latest.run_id))
Assert-True "latest run evidence" ($latest.evidence_ref -eq "phase2_runtime_run_status_visible")
Assert-True "latest aggregation evidence" ($latest.aggregation_evidence_ref -eq "agent_result_aggregation_complete")
Assert-True "latest required graph evidence present" (@($latest.evidence_refs) -contains "phase2_runtime_graph_started")
Assert-True "latest required memory evidence present" (@($latest.evidence_refs) -contains "memory_update_persisted")

Write-Host "[phase4-phase2-runtime-runs-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-phase2-runtime-runs-contract-runtime] result=verified"

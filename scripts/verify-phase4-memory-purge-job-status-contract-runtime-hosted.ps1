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
    throw "Phase4 hosted memory-purge-job-status-contract verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-memory-purge-job-status-contract-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted memory-purge-job-status-contract verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted memory-purge-job-status-contract proof requires HTTPS" }

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/memory/purge/jobs/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "surface contract version" ($contract.contract_version -eq "memory-purge-job-status-surface-v1")
Assert-True "endpoint parity" ($contract.endpoint -eq "GET /api/v1/memory/purge/jobs/contract")
Assert-True "runtime endpoint parity" ($contract.runtime_endpoint -eq "GET /api/v1/memory/purge/jobs/{job_id}")
Assert-True "trigger endpoint parity" ($contract.trigger_endpoint -eq "DELETE /api/v1/memory?project_id={id}&confirm=true")
Assert-True "runtime contract version parity" ($contract.runtime_contract_version -eq "memory-dsgvo-purge-v1")

$projectId = "hosted-phase4-memory-purge-job-status-" + [Guid]::NewGuid().ToString("N")
$traceId = "hosted-memory-purge-job-status-" + [Guid]::NewGuid().ToString("N")
$purge = Invoke-JsonApi -url "$BaseUrl/api/v1/memory?project_id=$projectId&confirm=true&reason=hosted_phase4_memory_purge_job_status_contract&trace_id=$traceId" -method "DELETE" -contentType $null -timeoutSeconds 20
Assert-True "purge status completed" ($purge.status -eq "completed")
Assert-True "purge contract version" ($purge.contract_version -eq "memory-dsgvo-purge-v1")
Assert-True "purge job id visible" (-not [string]::IsNullOrWhiteSpace([string]$purge.job_id))

$runtime = Invoke-JsonApi -url "$BaseUrl/api/v1/memory/purge/jobs/$($purge.job_id)" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "runtime status completed" ($runtime.status -eq "completed")
Assert-True "runtime evidence ref" ($runtime.evidence_ref -eq "memory_purge_job_status_visible")
Assert-True "runtime trace id parity" ($runtime.trace_id -eq $traceId)
Assert-True "runtime project id parity" ($runtime.project_id -eq $projectId)
Assert-True "runtime deleted counts redis key" ($null -ne $runtime.deleted_counts.redis_keys)
Assert-True "runtime deleted counts memory entries" ($null -ne $runtime.deleted_counts.memory_entries)
Assert-True "runtime deleted counts agent messages" ($null -ne $runtime.deleted_counts.agent_messages)
Assert-True "runtime deleted counts agent sessions" ($null -ne $runtime.deleted_counts.agent_sessions)
Assert-True "runtime audit id present" (-not [string]::IsNullOrWhiteSpace([string]$runtime.audit_event_id))
Assert-True "runtime severity warning" ($runtime.severity -eq "warning")

Write-Host "[phase4-memory-purge-job-status-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-memory-purge-job-status-contract-runtime] result=verified"

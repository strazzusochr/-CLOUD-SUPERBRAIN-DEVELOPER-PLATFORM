param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted request-contract surface-registry verification failed: $label"
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
import base64
import json
import ssl
import sys
import urllib.error
import urllib.request

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)
body_base64 = payload.get("bodyBase64")
data = None
if body_base64 is not None:
    data = base64.b64decode(body_base64.encode("ascii"))
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
  $payloadFile = Join-Path $env:TEMP ("phase4-request-contract-surface-registry-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted request-contract surface-registry verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/request/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "contract version" ($contract.contract_version -eq "request-id-correlation-v1")
Assert-True "public surface registry visible" ($null -ne $contract.public_surface_registry)

$registry = @($contract.public_surface_registry)
$expectedPaths = @(
  "/api/v1/agents/status",
  "/api/v1/agent-activity/recent",
  "/api/v1/tasks/recent",
  "/api/v1/sessions/recent",
  "/api/v1/sessions/{session_id}/history",
  "/api/v1/audit/recent",
  "/api/v1/escalations/recent"
)

foreach ($path in $expectedPaths) {
  $row = $registry | Where-Object { $_.path -eq $path } | Select-Object -First 1
  Assert-True "registry path visible $path" ($null -ne $row)
  Assert-True "registry request field $path" (($row.request_field | Out-String).Trim().Length -gt 0)
  Assert-True "registry trace field $path" (($row.trace_field | Out-String).Trim().Length -gt 0)
  Assert-True "registry correlation field $path" (($row.correlation_field | Out-String).Trim().Length -gt 0)
  Assert-True "registry audit field $path" (($row.audit_feed_field | Out-String).Trim().Length -gt 0)
}

$progress = Invoke-JsonApi -url "$BaseUrl/api/v1/project/progress" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "phase4 at least 50" ([int]$((@($progress.horizontal.items) | Where-Object { $_.id -eq 'phase_4' } | Select-Object -First 1).percent) -ge 50)

Write-Host "[phase4-request-contract-surface-registry] base_url=$BaseUrl"
Write-Host "[phase4-request-contract-surface-registry] registered_paths=$($expectedPaths.Count)"
Write-Host "[phase4-request-contract-surface-registry] result=verified"

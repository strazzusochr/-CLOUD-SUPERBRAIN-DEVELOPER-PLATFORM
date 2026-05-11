param(
  [string]$BaseUrl = "http://localhost:8081"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Autonomous agent roster verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("autonomous-agent-roster-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Autonomous agent roster verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/team/roster/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "contract version" ($contract.contract_version -eq "autonomous-agent-roster-v1")
Assert-True "runtime endpoint" ($contract.runtime_endpoint -eq "GET /api/v1/team/roster")
Assert-True "status endpoint" ($contract.status_endpoint -eq "GET /api/v1/team/status")
Assert-True "required docs include roster" (@($contract.required_documents) -contains "docs/codex-integration/autonomous-agent-roster.json")
Assert-True "runtime binding keys include langgraph" (@($contract.required_runtime_binding_keys) -contains "langgraph")
Assert-True "runtime binding keys include external adapter" (@($contract.required_runtime_binding_keys) -contains "external_adapter")

$roster = Invoke-JsonApi -url "$BaseUrl/api/v1/team/roster" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "roster contract version" ($roster.contract_version -eq "autonomous-agent-roster-v1")
Assert-True "roster status loaded" ($roster.status -eq "loaded")
Assert-True "source document" ($roster.source_document -eq "docs/codex-integration/autonomous-agent-roster.json")
Assert-True "role count >= 5" ([int]$roster.role_count -ge 5)
Assert-True "langgraph active" ($roster.runtime_bindings.langgraph.status -eq "active")
Assert-True "prometheus surface available" ($roster.runtime_bindings.prometheus.status -eq "metrics_surface_available")
Assert-True "crewai non-claim status visible" (-not [string]::IsNullOrWhiteSpace([string]$roster.runtime_bindings.crewai.status))
Assert-True "validated startable visible" (@($roster.launcher_status.validated_startable).Count -ge 1)

$homepage = Invoke-WebResponse -url "$BaseUrl/" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "homepage returns 200" ($homepage.StatusCode -eq 200)
Assert-True "homepage persisted agent roster marker" ($homepage.Content.Contains("Persisted Agent Roster"))

Write-Host "[autonomous-agent-roster] base_url=$BaseUrl"
Write-Host "[autonomous-agent-roster] role_count=$($roster.role_count)"
Write-Host "[autonomous-agent-roster] result=verified"

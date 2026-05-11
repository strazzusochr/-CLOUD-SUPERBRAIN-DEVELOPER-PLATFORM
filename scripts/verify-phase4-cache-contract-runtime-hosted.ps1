param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted cache-contract verification failed: $label"
  }
}

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase4 hosted cache-contract verification failed: $label did not contain '$expected'. Value: $text"
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
        result = {
            "status_code": response.getcode(),
            "content": response.read().decode("utf-8", errors="replace"),
            "headers": dict(response.headers.items()),
        }
except urllib.error.HTTPError as error:
    result = {
        "status_code": error.code,
        "content": error.read().decode("utf-8", errors="replace"),
        "headers": dict(error.headers.items()),
    }
print(json.dumps(result))
'@
  $payloadFile = Join-Path $env:TEMP ("phase4-cache-contract-runtime-" + [Guid]::NewGuid().ToString("N") + ".json")
  try {
    Set-Content -LiteralPath $payloadFile -Value $payload -NoNewline
    $raw = $python | py -3 - $payloadFile
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
  }
  $parsed = $raw | ConvertFrom-Json
  return [pscustomobject]@{
    StatusCode = [int]$parsed.status_code
    Content = [string]$parsed.content
    Headers = $parsed.headers
  }
}

function Invoke-JsonApi($url, $method = "GET", $body = $null, [hashtable]$headers = $null, $contentType = "application/json", $timeoutSeconds = 30) {
  $response = Invoke-WebResponse -url $url -method $method -body $body -headers $headers -contentType $contentType -timeoutSeconds $timeoutSeconds
  if ([int]$response.StatusCode -ge 400) {
    throw "Phase4 hosted cache-contract verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) { return $null }
  return ($response.Content | ConvertFrom-Json)
}

function Assert-NoStoreHeaders($label, $response) {
  $headers = $response.Headers
  Assert-True "$label status ok" ([int]$response.StatusCode -lt 500)
  Assert-True "$label cache-control present" ($headers.PSObject.Properties.Name -contains "Cache-Control")
  Assert-True "$label pragma present" ($headers.PSObject.Properties.Name -contains "Pragma")
  Assert-True "$label expires present" ($headers.PSObject.Properties.Name -contains "Expires")
  Assert-True "$label cache-control parity" ($headers."Cache-Control" -eq "no-store, no-cache, must-revalidate, max-age=0")
  Assert-True "$label pragma parity" ($headers."Pragma" -eq "no-cache")
  Assert-True "$label expires parity" ($headers."Expires" -eq "0")
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted cache-contract proof requires HTTPS" }

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/cache/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "contract version" ($contract.contract_version -eq "cache-control-no-store-v1")
Assert-True "contract applies to all responses" ($contract.applies_to -match "all Agent API HTTP responses")
Assert-True "contract visible evidence ref" ($contract.evidence_refs.contract_visible -eq "cache_control_contract_visible")

$health = Invoke-WebResponse -url "$BaseUrl/api/v1/health" -method "GET" -contentType $null -timeoutSeconds 20
$progress = Invoke-WebResponse -url "$BaseUrl/api/v1/project/progress" -method "GET" -contentType $null -timeoutSeconds 20
$errorsContract = Invoke-WebResponse -url "$BaseUrl/api/v1/errors/contract" -method "GET" -contentType $null -timeoutSeconds 20

$tooLong = "x" * 10001
$invalidPromptBody = @{
  project_id = "hosted-phase4-cache-contract-" + [Guid]::NewGuid().ToString("N")
  prompt = $tooLong
} | ConvertTo-Json -Compress
$invalidPrompt = Invoke-WebResponse -url "$BaseUrl/api/v1/prompt" -method "POST" -body $invalidPromptBody -contentType "application/json" -timeoutSeconds 20

Assert-True "invalid prompt 422" ($invalidPrompt.StatusCode -eq 422)
Assert-NoStoreHeaders "health" $health
Assert-NoStoreHeaders "progress" $progress
Assert-NoStoreHeaders "errors contract" $errorsContract
Assert-NoStoreHeaders "invalid prompt" $invalidPrompt

Assert-Contains "invalid prompt envelope" $invalidPrompt.Content "string_too_long"
Assert-Contains "progress body" $progress.Content '"overall_percent"'
Assert-Contains "health body" $health.Content '"status"'

Write-Host "[phase4-cache-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-cache-contract-runtime] result=verified"

param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted devops-workflow-validate-contract verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-devops-workflow-validate-contract-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted devops-workflow-validate-contract verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted devops-workflow-validate-contract proof requires HTTPS" }

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/devops/workflow-dispatch/validate/contract" -method "GET" -contentType $null -timeoutSeconds 20
$stagingBody = @{
  workflow_id = "main-deploy.yml"
  ref = "main"
  environment = "staging"
  action = "deploy"
  image_tag = "ghcr.io/repo/agent-api:sha-placeholder"
  reason = "hosted validate contract runtime verifier"
  trace_id = "hosted-devops-validate-contract-staging"
  human_review_approved = $false
  dry_run = $true
} | ConvertTo-Json -Compress
$productionBody = @{
  workflow_id = "main-deploy.yml"
  ref = "main"
  environment = "production"
  action = "deploy"
  image_tag = "ghcr.io/repo/agent-api:sha-placeholder"
  reason = "hosted validate contract runtime verifier"
  trace_id = "hosted-devops-validate-contract-production"
  human_review_approved = $false
  dry_run = $true
} | ConvertTo-Json -Compress

$staging = Invoke-JsonApi -url "$BaseUrl/api/v1/devops/workflow-dispatch/validate" -method "POST" -body $stagingBody -contentType "application/json" -timeoutSeconds 20
$production = Invoke-WebResponse -url "$BaseUrl/api/v1/devops/workflow-dispatch/validate" -method "POST" -body $productionBody -contentType "application/json" -timeoutSeconds 20
$productionJson = $production.Content | ConvertFrom-Json

Assert-True "surface contract version" ($contract.contract_version -eq "devops-workflow-dispatch-validate-surface-v1")
Assert-True "endpoint parity" ($contract.endpoint -eq "GET /api/v1/devops/workflow-dispatch/validate/contract")
Assert-True "runtime endpoint parity" ($contract.runtime_endpoint -eq "POST /api/v1/devops/workflow-dispatch/validate")
Assert-True "runtime contract version parity" ($contract.runtime_contract_version -eq "devops-workflow-dispatch-v1")
Assert-True "supported ready status" (@($contract.supported_statuses) -contains "ready")
Assert-True "supported blocked status" (@($contract.supported_statuses) -contains "blocked")
Assert-True "blocked detail code" ($contract.blocked_case.detail_code -eq "workflow_dispatch_blocked")

Assert-True "staging status ready" ($staging.status -eq "ready")
Assert-True "staging runtime contract" ($staging.contract_version -eq "devops-workflow-dispatch-v1")
Assert-True "staging live github false" ($staging.live_github_call -eq $false)
Assert-True "staging environment parity" ($staging.payload.inputs.environment -eq "staging")

Assert-True "production http 403" ($production.StatusCode -eq 403)
Assert-True "production detail code" ($productionJson.detail.code -eq "workflow_dispatch_blocked")
Assert-True "production contract status blocked" ($productionJson.detail.contract.status -eq "blocked")
Assert-True "production violation visible" (@($productionJson.detail.contract.violations) -contains "production workflow dispatch requires human_review_approved=true")

Write-Host "[phase4-devops-workflow-validate-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-devops-workflow-validate-contract-runtime] result=verified"

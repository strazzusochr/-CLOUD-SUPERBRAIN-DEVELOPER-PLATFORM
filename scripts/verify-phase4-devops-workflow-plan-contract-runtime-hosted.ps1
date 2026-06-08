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
    throw "Phase4 hosted devops-workflow-plan-contract verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-devops-workflow-plan-contract-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted devops-workflow-plan-contract verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted devops-workflow-plan-contract proof requires HTTPS" }

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/devops/workflow-dispatch/plan/contract" -method "GET" -contentType $null -timeoutSeconds 20
$runtime = Invoke-JsonApi -url "$BaseUrl/api/v1/devops/workflow-dispatch/plan" -method "GET" -contentType $null -timeoutSeconds 20
$stagingValidateBody = @{
  workflow_id = "main-deploy.yml"
  ref = "main"
  environment = "staging"
  action = "deploy"
  image_tag = "ghcr.io/repo/agent-api:sha-placeholder"
  reason = "hosted plan contract runtime verifier"
  trace_id = "hosted-devops-plan-contract-staging"
  human_review_approved = $false
  dry_run = $true
} | ConvertTo-Json -Compress
$productionValidate = Invoke-WebResponse -url "$BaseUrl/api/v1/devops/workflow-dispatch/validate" -method "POST" -body (@{
  workflow_id = "main-deploy.yml"
  ref = "main"
  environment = "production"
  action = "deploy"
  image_tag = "ghcr.io/repo/agent-api:sha-placeholder"
  reason = "hosted plan contract runtime verifier"
  trace_id = "hosted-devops-plan-contract-production"
  human_review_approved = $false
  dry_run = $true
} | ConvertTo-Json -Compress) -contentType "application/json" -timeoutSeconds 20
$stagingValidate = Invoke-JsonApi -url "$BaseUrl/api/v1/devops/workflow-dispatch/validate" -method "POST" -body $stagingValidateBody -contentType "application/json" -timeoutSeconds 20

Assert-True "surface contract version" ($contract.contract_version -eq "devops-workflow-dispatch-plan-surface-v1")
Assert-True "endpoint parity" ($contract.endpoint -eq "GET /api/v1/devops/workflow-dispatch/plan/contract")
Assert-True "runtime endpoint parity" ($contract.runtime_endpoint -eq "GET /api/v1/devops/workflow-dispatch/plan")
Assert-True "runtime contract version parity" ($contract.runtime_contract_version -eq "devops-workflow-dispatch-v1")
Assert-True "required github api field" (@($contract.required_github_api_fields) -contains "required_permission")
Assert-True "required input field" (@($contract.required_input_fields) -contains "dry_run")
Assert-True "expected live github call false" ($contract.expected_live_github_call -eq $false)

Assert-True "runtime contract version" ($runtime.contract_version -eq "devops-workflow-dispatch-v1")
Assert-True "runtime status ready" ($runtime.status -eq "ready")
Assert-True "runtime mode" ($runtime.mode -eq $contract.expected_mode)
Assert-True "runtime live github false" ($runtime.live_github_call -eq $false)
Assert-True "runtime github method post" ($runtime.github_api.method -eq "POST")
Assert-True "runtime permission actions write" ($runtime.github_api.required_permission -eq "actions:write")
Assert-True "runtime payload staging" ($runtime.payload.inputs.environment -eq "staging")
Assert-True "runtime payload dry run" ($runtime.payload.inputs.dry_run -eq "true")
Assert-True "staging validate ready" ($stagingValidate.status -eq "ready")
Assert-True "production validate blocked" ($productionValidate.StatusCode -eq 403)
Assert-True "production block code present" (($productionValidate.Content | ConvertFrom-Json).detail.code -eq "workflow_dispatch_blocked")

Write-Host "[phase4-devops-workflow-plan-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-devops-workflow-plan-contract-runtime] result=verified"

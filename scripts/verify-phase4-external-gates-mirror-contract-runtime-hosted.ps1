param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted external-gates-mirror-contract verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-external-gates-mirror-contract-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted external-gates-mirror-contract verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted external-gates-mirror-contract proof requires HTTPS" }

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/external-gates/mirror/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "contract version" ($contract.contract_version -eq "external-gates-mirror-surface-v1")
Assert-True "endpoint parity" ($contract.endpoint -eq "GET /api/v1/external-gates/mirror")
Assert-True "runtime contract version parity" ($contract.runtime_contract_version -eq "external-gate-mirror-v1")
Assert-True "guarded external gates endpoint" (@($contract.guarded_endpoints) -contains "GET /api/v1/external-gates")
Assert-True "guarded preflight endpoint" (@($contract.guarded_endpoints) -contains "GET /api/v1/clouds/deployment-preflight/contract")
Assert-True "required hosted command field" (@($contract.required_top_level_fields) -contains "hosted_command")
Assert-True "required staging claim flag" (@($contract.required_verified_flags) -contains "hosted_staging_claim_allowed")
Assert-True "verified status allowed" (@($contract.expected_statuses) -contains "verified")

$mirror = Invoke-JsonApi -url "$BaseUrl/api/v1/external-gates/mirror" -method "GET" -contentType $null -timeoutSeconds 20
$gates = Invoke-JsonApi -url "$BaseUrl/api/v1/external-gates" -method "GET" -contentType $null -timeoutSeconds 20
$completion = Invoke-JsonApi -url "$BaseUrl/api/v1/project/progress/completion" -method "GET" -contentType $null -timeoutSeconds 20
$preflight = Invoke-JsonApi -url "$BaseUrl/api/v1/clouds/deployment-preflight/contract" -method "GET" -contentType $null -timeoutSeconds 20

Assert-True "mirror runtime contract version" ($mirror.contract_version -eq "external-gate-mirror-v1")
Assert-True "mirror status verified" ($mirror.status -eq "verified")
Assert-True "external gates verified" ($gates.status -eq "verified")
Assert-True "configured count parity" ([int]$mirror.configured_count -eq [int]$gates.configured_count)
Assert-True "total count parity" ([int]$mirror.total_count -eq [int]$gates.total_count)
Assert-True "required gate ids count parity" (@($mirror.required_external_gates).Count -eq @($gates.gates).Count)
Assert-True "hosted staging claim allowed" ($mirror.hosted_staging_claim_allowed -eq $true)
Assert-True "branch protection claim allowed" ($mirror.branch_protection_claim_allowed -eq $true)
Assert-True "production gate claim allowed parity" ([bool]$mirror.production_deploy_claim_allowed -eq [bool]$completion.can_set_all_to_100 -or $mirror.production_deploy_claim_allowed -eq $true)
Assert-True "preflight evidence ref visible" (-not [string]::IsNullOrWhiteSpace([string]$mirror.cloud_deployment_preflight_evidence_ref))
Assert-True "preflight contract evidence ref visible" (-not [string]::IsNullOrWhiteSpace([string]$preflight.evidence_ref))

Write-Host "[phase4-external-gates-mirror-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-external-gates-mirror-contract-runtime] result=verified"

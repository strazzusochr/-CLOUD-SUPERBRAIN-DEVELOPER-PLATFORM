param(
  [string]$BaseUrl = "http://localhost:8081"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Autonomous master plan verification failed: $label"
  }
}

function Get-HtmlElementByTestId($html, $testId) {
  $pattern = '(?is)<[^>]*\bdata-testid\s*=\s*["'']' + [Regex]::Escape([string]$testId) + '["''][^>]*>'
  $match = [Regex]::Match([string]$html, $pattern)
  Assert-True "agents page element $testId visible" $match.Success
  return $match.Value
}

function Assert-HtmlAttribute($label, $element, $name, $expected) {
  $pattern = '(?is)\b' + [Regex]::Escape([string]$name) + '\s*=\s*["'']' + [Regex]::Escape([string]$expected) + '["'']'
  Assert-True $label ([Regex]::IsMatch([string]$element, $pattern))
}

function Assert-DevOnlyUiBoundaries($html) {
  foreach ($required in @(
    "DEV-ONLY; hosted proof still blocked",
    "live_provider_calls=false",
    "live_mcp_writes=false",
    "production_deploy=false",
    "secret_output=false"
  )) {
    Assert-True "agents page boundary $required visible" ([string]$html).Contains($required)
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
  $payloadFile = Join-Path $env:TEMP ("autonomous-master-plan-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Autonomous master plan verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
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

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/team/master-plan/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "contract version" ($contract.contract_version -eq "autonomous-master-plan-v1")
Assert-True "runtime endpoint" ($contract.runtime_endpoint -eq "GET /api/v1/team/master-plan")
Assert-True "status endpoint" ($contract.status_endpoint -eq "GET /api/v1/team/status")
Assert-True "logical roles" (@($contract.required_logical_roles) -join "," -eq "supervisor,planner,explorer,coder,tester")
Assert-True "required docs include project state" (@($contract.required_documents) -contains "PROJECT_STATE.md")

$plan = Invoke-JsonApi -url "$BaseUrl/api/v1/team/master-plan" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "plan contract version" ($plan.contract_version -eq "autonomous-master-plan-v1")
Assert-True "plan status" ($plan.status -eq "loaded")
Assert-True "source document" ($plan.source_document -eq "PROJECT_STATE.md")
Assert-True "binding document" ($plan.binding_document -eq "docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md")
Assert-True "progress manifest" ($plan.progress_manifest -eq "docs/project-progress.manifest.json")
Assert-True "overall percent visible" ([int]$plan.overall_percent -ge 0)
Assert-True "integrity visible" (-not [string]::IsNullOrWhiteSpace([string]$plan.integrity_status))
Assert-True "phase 4 visible" ($null -ne $plan.phase_percentages.phase_4)
Assert-True "phase 5 visible" ($null -ne $plan.phase_percentages.phase_5)
Assert-True "next steps visible" (@($plan.next_concrete_steps).Count -ge 1)
Assert-True "constraints visible" (@($plan.hard_constraints).Count -ge 3)
Assert-True "containers visible" (@($plan.running_containers).Count -ge 1)
Assert-True "dispatch endpoints visible" (@($plan.dispatch_endpoints).Count -ge 3)

$agentsPage = Invoke-WebResponse -url "$BaseUrl/agents" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "agents page returns 200" ($agentsPage.StatusCode -eq 200)
$masterPlanElement = Get-HtmlElementByTestId -html $agentsPage.Content -testId "autonomous-master-plan"
Assert-HtmlAttribute "agents page master-plan contract parity" $masterPlanElement "data-contract-version" $plan.contract_version
Assert-HtmlAttribute "agents page master-plan integrity parity" $masterPlanElement "data-integrity-status" $plan.integrity_status
Assert-HtmlAttribute "agents page master-plan source parity" $masterPlanElement "data-source-document" $plan.source_document
Assert-HtmlAttribute "agents page master-plan overall parity" $masterPlanElement "data-overall-percent" ([string][int]$plan.overall_percent)
Assert-HtmlAttribute "agents page master-plan role-count parity" $masterPlanElement "data-logical-role-count" ([string](@($plan.logical_roles).Count))
Assert-DevOnlyUiBoundaries $agentsPage.Content

Write-Host "[autonomous-master-plan] base_url=$BaseUrl"
Write-Host "[autonomous-master-plan] overall=$($plan.overall_percent)"
Write-Host "[autonomous-master-plan] evidence_scope=DEV-ONLY"
Write-Host "[autonomous-master-plan] hosted_proof=false"
Write-Host "[autonomous-master-plan] production_deploy=false"
Write-Host "[autonomous-master-plan] result=verified"

param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted task-policy contract verification failed: $label"
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
request = urllib.request.Request(
    payload["url"],
    data=data,
    headers=headers,
    method=payload["method"],
)
try:
    with urllib.request.urlopen(request, timeout=payload.get("timeoutSeconds", 30)) as response:
        result = {
            "status_code": response.getcode(),
            "content": response.read().decode("utf-8", errors="replace"),
        }
except urllib.error.HTTPError as error:
    result = {
        "status_code": error.code,
        "content": error.read().decode("utf-8", errors="replace"),
    }
print(json.dumps(result))
'@
  $payloadFile = Join-Path $env:TEMP ("phase4-task-policy-" + [Guid]::NewGuid().ToString("N") + ".json")
  try {
    Set-Content -LiteralPath $payloadFile -Value $payload -NoNewline
    $raw = $python | py -3 - $payloadFile
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
  }
  return ($raw | ConvertFrom-Json)
}

function Invoke-JsonApi($url, $method = "GET", $body = $null, [hashtable]$headers = $null, $contentType = "application/json", $timeoutSeconds = 30) {
  $response = Invoke-WebResponse -url $url -method $method -body $body -headers $headers -contentType $contentType -timeoutSeconds $timeoutSeconds
  if ([int]$response.status_code -ge 400) {
    throw "Phase4 hosted task-policy contract verification failed: $method $url returned HTTP $($response.status_code). Value: $($response.content)"
  }
  if (-not ($response.content | Out-String).Trim()) {
    return $null
  }
  return ($response.content | ConvertFrom-Json)
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") {
  throw "Phase4 hosted task-policy contract proof requires HTTPS"
}

Write-Host "[phase4-task-policy-contract-runtime] base_url=$BaseUrl"

$contract = Invoke-JsonApi "$BaseUrl/api/v1/tasks/policy/contract"
$runtime = Invoke-JsonApi "$BaseUrl/api/v1/tasks/policy"

Assert-True "contract version" ($contract.contract_version -eq "task-policy-contract-v1")
Assert-True "runtime policy version" ($runtime.policy_version -eq "task-policy-v1")
Assert-True "contract policy version mirrors runtime" ($contract.policy_version -eq $runtime.policy_version)
Assert-True "profile contract version mirrors runtime" ($contract.profile_contract_version -eq $runtime.profile_contract_version)
Assert-True "mode mirrors runtime" ($runtime.mode -eq "fail_closed_before_enqueue")

foreach ($field in @(
  "required_blocked_actions",
  "allowed_tools",
  "write_tools",
  "profile_gates",
  "write_scope_required_for",
  "devops_human_gate"
)) {
  Assert-True "runtime field $field present" ($null -ne $runtime.$field)
}

$violationBody = @{
  project_id = "browser-workspace"
  session_id = "11111111-1111-1111-1111-111111111111"
  agent_type = "coder"
  task_type = "implement"
  task_description = "write production deploy patch without scope"
  allowed_tools = @("filesystem")
  blocked_actions = @("delete_prod_data")
  acceptance_criteria = @("result_envelope", "done_validation", "audit_log")
  max_retries = 1
  priority = 5
  human_review_required = $false
} | ConvertTo-Json -Compress

$violation = Invoke-WebResponse -url "$BaseUrl/api/v1/tasks/policy/validate" -method "POST" -body $violationBody -contentType "application/json" -timeoutSeconds 30
Assert-True "policy validate returns 403" ([int]$violation.status_code -eq 403)
$violationJson = $violation.content | ConvertFrom-Json
Assert-True "policy violation code" ($violationJson.detail.code -eq "task_policy_violation")
Assert-True "policy detail present" ($null -ne $violationJson.detail.policy)
Assert-True "policy detail mirrors version" ($violationJson.detail.policy.policy_version -eq $runtime.policy_version)

Write-Host "[phase4-task-policy-contract-runtime] result=verified"

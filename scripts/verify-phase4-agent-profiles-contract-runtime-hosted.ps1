param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted agent-profiles contract verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("phase4-agent-profiles-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Phase4 hosted agent-profiles contract verification failed: $method $url returned HTTP $($response.status_code). Value: $($response.content)"
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
  throw "Phase4 hosted agent-profiles contract proof requires HTTPS"
}

Write-Host "[phase4-agent-profiles-contract-runtime] base_url=$BaseUrl"

$contract = Invoke-JsonApi "$BaseUrl/api/v1/agents/profiles/contract"
$runtime = Invoke-JsonApi "$BaseUrl/api/v1/agents/profiles"

Assert-True "contract version" ($contract.contract_version -eq "agent-profiles-contract-v1")
Assert-True "runtime contract version" ($runtime.profile_contract_version -eq "agent-profiles-v1")
Assert-True "profile version mirrors runtime" ($contract.profile_contract_version -eq $runtime.profile_contract_version)
Assert-True "max retry mirrors runtime" ([int]$contract.max_retry_global -eq [int]$runtime.max_retry_global)

$requiredAgentTypes = @("planner", "coder", "tester", "devops")
$runtimeTypes = @($runtime.profiles | ForEach-Object { $_.agent_type })
foreach ($agentType in $requiredAgentTypes) {
  Assert-True "runtime profile $agentType present" ($runtimeTypes -contains $agentType)
}

foreach ($profile in $runtime.profiles) {
  foreach ($field in @("agent_type", "allowed_tools", "blocked_actions", "human_review_required_actions", "max_retries", "max_execution_seconds")) {
    Assert-True "profile field $field present for $($profile.agent_type)" ($null -ne $profile.$field)
  }
}

Assert-True "done validation set mirrors runtime" (($contract.done_validation_required | ConvertTo-Json -Compress) -eq ($runtime.done_validation_required | ConvertTo-Json -Compress))
Assert-True "non claims mirror runtime" (($contract.non_claims | ConvertTo-Json -Compress) -eq ($runtime.non_claims | ConvertTo-Json -Compress))

Write-Host "[phase4-agent-profiles-contract-runtime] result=verified"

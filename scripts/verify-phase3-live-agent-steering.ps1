param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Live agent steering verification failed: $label"
  }
}

function Invoke-RawHttp($Url, $Method = "GET", $Body = $null) {
  $payload = [ordered]@{
    url = $Url
    method = $Method
  }
  if ($null -ne $Body) {
    $payload.body_b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes([string]$Body))
  }
  $payloadFile = Join-Path $env:TEMP ("live-agent-http-" + [Guid]::NewGuid().ToString("N") + ".json")
  $pythonFile = Join-Path $env:TEMP ("live-agent-http-" + [Guid]::NewGuid().ToString("N") + ".py")
  try {
    Set-Content -LiteralPath $payloadFile -Value ($payload | ConvertTo-Json -Compress -Depth 5) -NoNewline -Encoding utf8
    $pythonScript = @'
import base64
import json
import sys
import urllib.error
import urllib.request

with open(sys.argv[1], "r", encoding="utf-8-sig") as handle:
    payload = json.load(handle)

data = None
headers = {}
if payload.get("body_b64"):
    data = base64.b64decode(payload["body_b64"])
    headers["Content-Type"] = "application/json"

request = urllib.request.Request(payload["url"], data=data, headers=headers, method=payload.get("method", "GET"))
try:
    with urllib.request.urlopen(request, timeout=60) as response:
        content = response.read().decode("utf-8", errors="replace")
        print(json.dumps({"StatusCode": response.status, "Content": content}))
except urllib.error.HTTPError as exc:
    content = exc.read().decode("utf-8", errors="replace")
    print(json.dumps({"StatusCode": exc.code, "Content": content}))
'@
    Set-Content -LiteralPath $pythonFile -Value $pythonScript -NoNewline -Encoding utf8
    $output = py -3 $pythonFile $payloadFile
    if ($LASTEXITCODE -ne 0) {
      throw ($output | Out-String)
    }
    return ($output | ConvertFrom-Json)
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
    if (Test-Path $pythonFile) { Remove-Item -LiteralPath $pythonFile -Force }
  }
}

function Invoke-Text($url) {
  $response = Invoke-RawHttp -Url $url -Method "GET"
  if ([int]$response.StatusCode -ge 400) {
    throw "GET $url returned HTTP $($response.StatusCode)"
  }
  return [string]$response.Content
}

function Invoke-JsonApi($url, $method = "GET", $body = $null) {
  $response = Invoke-RawHttp -Url $url -Method $method -Body $body
  if ([int]$response.StatusCode -ge 400) {
    throw "$method $url returned HTTP $($response.StatusCode): $($response.Content)"
  }
  return ($response.Content | ConvertFrom-Json)
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ((-not $AllowLocalhost) -and ($BaseUrl -match "localhost|127\.0\.0\.1|\[::1\]")) {
  throw "Live agent steering proof refuses localhost unless -AllowLocalhost is set"
}

Write-Host "[phase3-live-agent] base url: $BaseUrl"

$homepage = Invoke-Text "$BaseUrl/"
Assert-True "homepage shows live agent control" ($homepage.Contains("Live Agent Control"))
Assert-True "homepage exposes live agent UI evidence" ($homepage.Contains("live_agent_steering_ui_visible"))
Assert-True "homepage exposes metadata guard evidence" ($homepage.Contains("live_agent_metadata_guard_enforced"))
Assert-True "homepage exposes steering endpoint" ($homepage.Contains("POST /api/v1/live-agents/steer"))

$contract = Invoke-JsonApi "$BaseUrl/api/v1/live-agents/contract"
Assert-True "contract version" ($contract.contract_version -eq "live-agent-steering-v1")
Assert-True "status endpoint" ($contract.status_endpoint -eq "GET /api/v1/live-agents/status")
Assert-True "steer endpoint" ($contract.steer_endpoint -eq "POST /api/v1/live-agents/steer")
Assert-True "compatibility endpoint" ($contract.compatibility_endpoint -eq "POST /api/steer-agent")
Assert-True "metadata policy blocks live providers" ($contract.metadata_policy.live_provider_calls_allowed -eq $false)
Assert-True "metadata policy system wins" ($contract.metadata_policy.system_metadata_wins -eq $true)
Assert-True "metadata guard evidence" ($contract.evidence_refs.security_guard -eq "live_agent_metadata_guard_enforced")
Assert-True "ui evidence" ($contract.evidence_refs.ui_visible -eq "live_agent_steering_ui_visible")

$status = Invoke-JsonApi "$BaseUrl/api/v1/live-agents/status"
Assert-True "status available" ($status.status -eq "available")
Assert-True "status version" ($status.contract_version -eq "live-agent-steering-v1")
Assert-True "status agent count" ([int]$status.agent_count -ge 5)
Assert-True "status evidence" ($status.evidence_ref -eq "live_agent_steering_contract_visible")

$projectId = "phase3-live-agent-" + [Guid]::NewGuid().ToString("N")
$body = @{
  agentId = "supervisor"
  projectId = $projectId
  message = "Return one concise dry-run proof that live provider calls are disabled."
  resetHistory = $true
  metadata = @{
    source = "phase3-live-agent-verifier"
    live_provider_calls_allowed = $true
    trace_id = "malicious-trace-override"
    agent_type = "malicious-agent-override"
    project_id = "malicious-project-override"
  }
} | ConvertTo-Json -Compress -Depth 6

$steer = Invoke-JsonApi "$BaseUrl/api/v1/live-agents/steer" "POST" $body
Assert-True "steer contract version" ($steer.contract_version -eq "live-agent-steering-v1")
Assert-True "steer response id shape" (-not [string]::IsNullOrWhiteSpace([string]$steer.response_id))
Assert-True "steer runtime source" ($steer.runtime_source -eq "openai_responses_via_llm_gateway")
Assert-True "steer agent id" ($steer.agent_id -eq "supervisor")
Assert-True "steer execution role" ($steer.execution_role -eq "planner")
Assert-True "steer project id not overridden" ($steer.project_id -eq $projectId)
Assert-True "steer provider disabled" ($steer.metadata_policy.live_provider_calls_allowed -eq $false)
Assert-True "steer metadata guard evidence" ($steer.metadata_policy.evidence_ref -eq "live_agent_metadata_guard_enforced")
Assert-True "steer forwards safe metadata" (@($steer.metadata_policy.user_metadata_fields_forwarded) -contains "source")
Assert-True "steer strips live provider override" (-not (@($steer.metadata_policy.user_metadata_fields_forwarded) -contains "live_provider_calls_allowed"))
Assert-True "steer strips trace override" (-not (@($steer.metadata_policy.user_metadata_fields_forwarded) -contains "trace_id"))
Assert-True "steer text dry-run proof" ([string]$steer.text -match "live_provider_calls=false")

$reset = Invoke-JsonApi "$BaseUrl/api/v1/live-agents/supervisor/reset" "POST"
Assert-True "reset status" ($reset.status -eq "reset")
Assert-True "reset version" ($reset.contract_version -eq "live-agent-steering-v1")

Write-Host "[phase3-live-agent] ok"

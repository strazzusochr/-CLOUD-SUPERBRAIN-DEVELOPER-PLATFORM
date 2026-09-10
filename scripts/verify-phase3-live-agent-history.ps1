param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Live agent history verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("live-agent-history-http-" + [Guid]::NewGuid().ToString("N") + ".json")
  $pythonFile = Join-Path $env:TEMP ("live-agent-history-http-" + [Guid]::NewGuid().ToString("N") + ".py")
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
  throw "Live agent history proof refuses localhost unless -AllowLocalhost is set"
}

Write-Host "[phase3-live-agent-history] base url: $BaseUrl"

$homepage = Invoke-Text "$BaseUrl/"
Assert-True "homepage shows live agent control" ($homepage.Contains("Live Agent Control"))
Assert-True "homepage exposes history evidence" ($homepage.Contains("live_agent_steering_history_visible"))
Assert-True "homepage exposes history endpoint" ($homepage.Contains("GET /api/v1/live-agents/history"))

$contract = Invoke-JsonApi "$BaseUrl/api/v1/live-agents/contract"
Assert-True "contract version" ($contract.contract_version -eq "live-agent-steering-v1")
Assert-True "contract history endpoint" ($contract.history_endpoint -eq "GET /api/v1/live-agents/history")
Assert-True "contract history evidence" ($contract.evidence_refs.history_visible -eq "live_agent_steering_history_visible")

$projectId = "phase3-live-agent-history-" + [Guid]::NewGuid().ToString("N")
$body = @{
  agentId = "supervisor"
  projectId = $projectId
  message = "Return one concise history proof with live_provider_calls=false."
  resetHistory = $true
  metadata = @{
    source = "phase3-live-agent-history-verifier"
  }
} | ConvertTo-Json -Compress -Depth 6

$steer = Invoke-JsonApi "$BaseUrl/api/v1/live-agents/steer" "POST" $body
Assert-True "steer response id" (-not [string]::IsNullOrWhiteSpace([string]$steer.response_id))
Assert-True "steer trace id" (-not [string]::IsNullOrWhiteSpace([string]$steer.trace_id))
Assert-True "steer audit persisted" ($steer.audit_persisted -eq $true)

$coderBody = @{
  agentId = "coder"
  projectId = $projectId
  message = "Return one concise sibling history proof with live_provider_calls=false."
  resetHistory = $true
  metadata = @{
    source = "phase3-live-agent-history-verifier"
  }
} | ConvertTo-Json -Compress -Depth 6

$coderSteer = Invoke-JsonApi "$BaseUrl/api/v1/live-agents/steer" "POST" $coderBody
Assert-True "coder steer response id" (-not [string]::IsNullOrWhiteSpace([string]$coderSteer.response_id))

$history = Invoke-JsonApi "$BaseUrl/api/v1/live-agents/history?agent_id=supervisor&project_id=$projectId&limit=10"
Assert-True "history status" ($history.status -eq "available")
Assert-True "history mode" ($history.mode -eq "audit_log_backed_live_agent_history")
Assert-True "history endpoint" ($history.history_endpoint -eq "GET /api/v1/live-agents/history")
Assert-True "history evidence" ($history.evidence_ref -eq "live_agent_steering_history_visible")

$historyEvent = @($history.events | Where-Object { $_.response_id -eq $steer.response_id } | Select-Object -First 1)
Assert-True "history event visible" ($null -ne $historyEvent)
foreach ($event in @($history.events)) {
  Assert-True "history filter scoped to supervisor" ($event.agent_id -eq "supervisor")
  Assert-True "history filter scoped to project" ($event.project_id -eq $projectId)
}
Assert-True "history excludes same-project coder event" (-not (@($history.events).response_id -contains $coderSteer.response_id))
Assert-True "history event agent" ($historyEvent.agent_id -eq "supervisor")
Assert-True "history event role" ($historyEvent.execution_role -eq "planner")
Assert-True "history event trace" ($historyEvent.trace_id -eq $steer.trace_id)
Assert-True "history event request" (-not [string]::IsNullOrWhiteSpace([string]$historyEvent.request_id))
Assert-True "history event response preview" (-not [string]::IsNullOrWhiteSpace([string]$historyEvent.response_preview))
Assert-True "history event provider nonclaim" ($historyEvent.live_provider_calls -eq $false)
Assert-True "history event audit persisted" ($historyEvent.audit_persisted -eq $true)
Assert-True "history event evidence" ($historyEvent.evidence_ref -eq "live_agent_steering_audit_persisted")

$unfilteredHistory = Invoke-JsonApi "$BaseUrl/api/v1/live-agents/history?limit=10"
Assert-True "unfiltered history count" ([int]$unfilteredHistory.history_count -ge [int]$history.history_count)

$projectHistory = Invoke-JsonApi "$BaseUrl/api/v1/live-agents/history?project_id=$projectId&limit=10"
foreach ($event in @($projectHistory.events)) {
  Assert-True "project history scoped to project" ($event.project_id -eq $projectId)
}
Assert-True "project history includes supervisor event" (@($projectHistory.events).response_id -contains $steer.response_id)
Assert-True "project history includes coder event" (@($projectHistory.events).response_id -contains $coderSteer.response_id)

$reset = Invoke-JsonApi "$BaseUrl/api/v1/live-agents/supervisor/reset" "POST"
Assert-True "reset status" ($reset.status -eq "reset")
$coderReset = Invoke-JsonApi "$BaseUrl/api/v1/live-agents/coder/reset" "POST"
Assert-True "coder reset status" ($coderReset.status -eq "reset")

Write-Host "[phase3-live-agent-history] ok"

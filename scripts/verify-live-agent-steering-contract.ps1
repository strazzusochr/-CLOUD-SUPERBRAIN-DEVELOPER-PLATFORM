param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) {
    throw "Live agent steering contract verification failed: $Label"
  }
}

function Assert-Equal([string]$Label, $Actual, $Expected) {
  if ($Actual -ne $Expected) {
    throw "Live agent steering contract verification failed: $Label expected '$Expected', got '$Actual'."
  }
}

function Assert-Contains([string]$Label, [string]$Text, [string]$Needle) {
  if (-not $Text.Contains($Needle)) {
    throw "Live agent steering contract verification failed: $Label missing '$Needle'."
  }
}

function Assert-NotContains([string]$Label, [string]$Text, [string]$Needle) {
  if ($Text.Contains($Needle)) {
    throw "Live agent steering contract verification failed: $Label contains forbidden '$Needle'."
  }
}

function Normalize-BaseUrl([string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value)) {
    throw "BaseUrl is required"
  }
  return $Value.Trim().TrimEnd("/")
}

function Assert-BaseUrlAllowed([string]$Url, [bool]$AllowLocal) {
  $uri = [System.Uri]$Url
  $isLocal = $uri.Host -in @("localhost", "127.0.0.1", "::1")
  if ($isLocal -and -not $AllowLocal) {
    throw "Live agent steering proof refuses localhost unless -AllowLocalhost is set"
  }
  if (-not $isLocal -and $uri.Scheme -ne "https") {
    throw "Hosted live agent steering proof requires HTTPS"
  }
}

function Invoke-JsonGet([string]$Url) {
  try {
    return Invoke-RestMethod -Method Get -Uri $Url -TimeoutSec 30 -ErrorAction Stop
  } catch {
    throw "Failed to fetch JSON from ${Url}: $($_.Exception.Message)"
  }
}

function Invoke-JsonPost([string]$Url, $Body) {
  $json = $Body | ConvertTo-Json -Depth 16
  try {
    return Invoke-RestMethod -Method Post -Uri $Url -ContentType "application/json" -Body $json -TimeoutSec 90 -ErrorAction Stop
  } catch {
    throw "Failed to POST JSON to ${Url}: $($_.Exception.Message)"
  }
}

function Invoke-StatusPost([string]$Url, $Body) {
  $json = $Body | ConvertTo-Json -Depth 16
  try {
    $response = Invoke-WebRequest -Method Post -Uri $Url -ContentType "application/json" -Body $json -TimeoutSec 30 -ErrorAction Stop
    return [int]$response.StatusCode
  } catch {
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
      return [int]$_.Exception.Response.StatusCode
    }
    throw
  }
}

function Get-AgentState($StatusPayload, [string]$AgentId) {
  foreach ($agent in @($StatusPayload.agents)) {
    if ([string]$agent.agent_id -eq $AgentId) {
      return $agent
    }
  }
  return $null
}

$base = Normalize-BaseUrl $BaseUrl
Assert-BaseUrlAllowed $base ([bool]$AllowLocalhost)

$repoRoot = Split-Path $PSScriptRoot -Parent
$agentApiPath = Join-Path $repoRoot "services\agent-api\app\main.py"
$llmGatewayPath = Join-Path $repoRoot "services\llm-gateway\app\main.py"

Assert-True "agent api source exists" (Test-Path -LiteralPath $agentApiPath)
Assert-True "llm gateway source exists" (Test-Path -LiteralPath $llmGatewayPath)

$agentSource = Get-Content -LiteralPath $agentApiPath -Raw
$llmSource = Get-Content -LiteralPath $llmGatewayPath -Raw

foreach ($required in @(
  "LIVE_AGENT_STEERING_CONTRACT_VERSION",
  "live-agent-steering-v1",
  "live_agent_steering_contract_visible",
  '@app.get("/api/v1/live-agents/contract")',
  '@app.post("/api/v1/live-agents/steer")',
  '@app.post("/api/steer-agent")',
  '@app.post("/api/v1/live-agents/{agent_id}/reset")',
  "call_llm_gateway_responses",
  "POST /llm/v1/responses",
  "GET /llm/api/v1/responses/contract",
  "llm_gateway_contract_version",
  "llm_gateway_evidence_ref",
  "live_provider_calls",
  "model_downloads",
  "audit_persisted",
  "secret_output"
)) {
  Assert-Contains "agent api source" $agentSource $required
}

foreach ($required in @(
  "LLM_RESPONSES_ADAPTER_CONTRACT_VERSION",
  "llm-responses-adapter-contract-v1",
  '@app.post("/v1/responses")',
  "responses_adapter_payload",
  "audit_responses_event"
)) {
  Assert-Contains "llm gateway source" $llmSource $required
}

foreach ($forbidden in @("api.openai.com", "OPENAI_API_KEY", "ANTHROPIC_API_KEY", '"live_provider_calls": True', '"model_downloads": True', '"secret_output": True')) {
  Assert-NotContains "agent api source forbidden $forbidden" $agentSource $forbidden
}

Write-Host "[live-agent-steering] contract"
$contract = Invoke-JsonGet "$base/api/v1/live-agents/contract"
Assert-Equal "contract version" $contract.contract_version "live-agent-steering-v1"
Assert-Equal "mode" $contract.mode "openai_responses_via_llm_gateway"
Assert-Equal "evidence ref" $contract.evidence_refs.contract_visible "live_agent_steering_contract_visible"
Assert-Equal "llm gateway endpoint" $contract.llm_gateway_endpoint "POST /llm/v1/responses"
Assert-Equal "llm gateway contract version" $contract.llm_gateway_contract_version "llm-responses-adapter-contract-v1"
Assert-True "response fields include trace id" (@($contract.response_fields) -contains "trace_id")
Assert-True "response fields include no-live-provider flag" (@($contract.response_fields) -contains "live_provider_calls")
Assert-True "response fields include audit flag" (@($contract.response_fields) -contains "audit_persisted")
Assert-True "response fields include secret flag" (@($contract.response_fields) -contains "secret_output")
Assert-True "required llm fields include output text" (@($contract.required_llm_response_fields) -contains "output_text")
Assert-True "agents include coder" (@($contract.agents | ForEach-Object { [string]$_.agent_id }) -contains "coder")

$llmContract = Invoke-JsonGet "$base/llm/api/v1/responses/contract"
Assert-Equal "llm contract version" $llmContract.contract_version "llm-responses-adapter-contract-v1"
Assert-True "llm contract no live provider default" ($llmContract.live_provider_calls -eq $false)
Assert-True "llm contract no model downloads" ($llmContract.model_downloads -eq $false)

Write-Host "[live-agent-steering] reset and steer"
$reset = Invoke-JsonPost "$base/api/v1/live-agents/coder/reset" @{}
Assert-Equal "reset status" $reset.status "reset"
Assert-Equal "reset contract version" $reset.contract_version "live-agent-steering-v1"

$traceId = "live-agent-steering-contract-" + [Guid]::NewGuid().ToString("N")
$steer = Invoke-JsonPost "$base/api/v1/live-agents/steer" @{
  agent_id = "coder"
  message = "verify live agent steering contract"
  project_id = "live-agent-steering-contract"
  reset_history = $true
  metadata = @{
    trace_id = $traceId
    verifier = "live-agent-steering-contract"
  }
}

Assert-Equal "steer contract version" $steer.contract_version "live-agent-steering-v1"
Assert-Equal "steer runtime source" $steer.runtime_source "openai_responses_via_llm_gateway"
Assert-Equal "steer agent id" $steer.agent_id "coder"
Assert-Equal "steer trace id" $steer.trace_id $traceId
Assert-Equal "steer llm contract version" $steer.llm_gateway_contract_version "llm-responses-adapter-contract-v1"
Assert-Equal "steer llm evidence ref" $steer.llm_gateway_evidence_ref "llm_responses_adapter_contract_visible"
Assert-Equal "steer evidence ref" $steer.evidence_ref "live_agent_steering_contract_visible"
Assert-True "steer response id present" (-not [string]::IsNullOrWhiteSpace([string]$steer.response_id))
Assert-True "steer responseId present" (-not [string]::IsNullOrWhiteSpace([string]$steer.responseId))
Assert-True "steer text present" (-not [string]::IsNullOrWhiteSpace([string]$steer.text))
Assert-Equal "steer status" $steer.status "completed"
Assert-True "steer no live provider call" ($steer.live_provider_calls -eq $false)
Assert-True "steer no model downloads" ($steer.model_downloads -eq $false)
Assert-True "steer audit persisted" ($steer.audit_persisted -eq $true)
Assert-True "steer no secret output" ($steer.secret_output -eq $false)
Assert-True "steer usage visible" ([int]$steer.usage.total_tokens -gt 0)

$status = Invoke-JsonGet "$base/api/v1/live-agents/status"
Assert-Equal "status contract version" $status.contract_version "live-agent-steering-v1"
Assert-Equal "status runtime source" $status.runtime_source "openai_responses_via_llm_gateway"
$coder = Get-AgentState $status "coder"
Assert-True "coder status present" ($null -ne $coder)
Assert-True "coder has session" ($coder.has_session -eq $true)
Assert-Equal "coder previous response id" $coder.previous_response_id $steer.response_id
Assert-Equal "coder execution role" $coder.execution_role "coder"

$audit = Invoke-JsonGet "$base/api/v1/audit/recent?limit=100"
$auditJson = $audit | ConvertTo-Json -Depth 24
Assert-Contains "audit contains trace id" $auditJson $traceId
Assert-Contains "audit contains llm event" $auditJson "llm_gateway_request"

Write-Host "[live-agent-steering] compatibility route"
$compatTraceId = "live-agent-compat-contract-" + [Guid]::NewGuid().ToString("N")
$compat = Invoke-JsonPost "$base/api/steer-agent" @{
  agentId = "tester"
  message = "verify compatibility steering contract"
  metadata = @{
    trace_id = $compatTraceId
    verifier = "live-agent-steering-contract"
  }
}
Assert-Equal "compat contract version" $compat.contract_version "live-agent-steering-v1"
Assert-Equal "compat agent id" $compat.agent_id "tester"
Assert-True "compat responseId present" (-not [string]::IsNullOrWhiteSpace([string]$compat.responseId))
Assert-True "compat text present" (-not [string]::IsNullOrWhiteSpace([string]$compat.text))
Assert-Equal "compat trace id" $compat.trace_id $compatTraceId
Assert-True "compat no live provider call" ($compat.live_provider_calls -eq $false)

Write-Host "[live-agent-steering] negative cases"
$unknownStatus = Invoke-StatusPost "$base/api/v1/live-agents/steer" @{
  agent_id = "missing-agent"
  message = "unknown agent should fail"
}
Assert-Equal "unknown agent rejected" $unknownStatus 404

$emptyMessageStatus = Invoke-StatusPost "$base/api/v1/live-agents/steer" @{
  agent_id = "coder"
  message = ""
}
Assert-Equal "empty message rejected" $emptyMessageStatus 422

Write-Host "[live-agent-steering] reset after proof"
$finalReset = Invoke-JsonPost "$base/api/v1/live-agents/coder/reset" @{}
Assert-Equal "final reset status" $finalReset.status "reset"
$finalStatus = Invoke-JsonGet "$base/api/v1/live-agents/status"
$coderAfterReset = Get-AgentState $finalStatus "coder"
Assert-True "coder session cleared" ($coderAfterReset.has_session -eq $false)

Write-Host "[live-agent-steering] trace=$traceId"
Write-Host "[live-agent-steering] checks completed"

param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) {
    throw "LLM responses contract verification failed: $Label"
  }
}

function Assert-Equal([string]$Label, $Actual, $Expected) {
  if ($Actual -ne $Expected) {
    throw "LLM responses contract verification failed: $Label expected '$Expected', got '$Actual'."
  }
}

function Assert-Contains([string]$Label, [string]$Text, [string]$Needle) {
  if (-not $Text.Contains($Needle)) {
    throw "LLM responses contract verification failed: $Label missing '$Needle'."
  }
}

function Assert-NotContains([string]$Label, [string]$Text, [string]$Needle) {
  if ($Text.Contains($Needle)) {
    throw "LLM responses contract verification failed: $Label contains forbidden '$Needle'."
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
    throw "LLM responses contract proof refuses localhost unless -AllowLocalhost is set"
  }
  if (-not $isLocal -and $uri.Scheme -ne "https") {
    throw "Hosted LLM responses contract proof requires HTTPS"
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
    return Invoke-RestMethod -Method Post -Uri $Url -ContentType "application/json" -Body $json -TimeoutSec 60 -ErrorAction Stop
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

$base = Normalize-BaseUrl $BaseUrl
Assert-BaseUrlAllowed $base ([bool]$AllowLocalhost)

$repoRoot = Split-Path $PSScriptRoot -Parent
$llmGatewayPath = Join-Path $repoRoot "services\llm-gateway\app\main.py"
$agentApiPath = Join-Path $repoRoot "services\agent-api\app\main.py"

Assert-True "llm gateway source exists" (Test-Path -LiteralPath $llmGatewayPath)
Assert-True "agent api source exists" (Test-Path -LiteralPath $agentApiPath)

$llmSource = Get-Content -LiteralPath $llmGatewayPath -Raw
$agentSource = Get-Content -LiteralPath $agentApiPath -Raw

foreach ($required in @(
  "LLM_RESPONSES_ADAPTER_CONTRACT_VERSION",
  "llm-responses-adapter-contract-v1",
  "llm_responses_adapter_contract_visible",
  '@app.get("/api/v1/responses/contract")',
  '@app.post("/v1/responses")',
  "audit_responses_event",
  "metadata must be an object",
  "stream=true is not supported on this /v1/responses proxy",
  '"model_downloads": False',
  '"secret_output": False'
)) {
  Assert-Contains "llm gateway source" $llmSource $required
}

foreach ($required in @(
  "LLM_RESPONSES_ADAPTER_CONTRACT_VERSION",
  "llm-responses-adapter-contract-v1",
  "llm_responses_adapter_contract_visible",
  "GET /llm/api/v1/responses/contract",
  "POST /llm/v1/responses",
  "call_llm_gateway_responses",
  "No direct provider URL is called by the Agent API"
)) {
  Assert-Contains "agent api source" $agentSource $required
}

foreach ($forbidden in @("OPENAI_API_KEY", "api.openai.com", '"live_provider_calls": True', '"secret_output": True')) {
  Assert-NotContains "responses adapter source forbidden $forbidden" $llmSource $forbidden
}

# `"model_downloads": True` is permitted ONLY inside the local llama.cpp (open-source, local-CPU)
# provider/model-listing context, where pulling a local GGUF model is legitimate and accurately
# declared. It must never appear on the hosted/responses-adapter or HF-router paths.
$llmLines = $llmSource -split "`n"
for ($i = 0; $i -lt $llmLines.Count; $i++) {
  if ($llmLines[$i] -match '"model_downloads"\s*:\s*True') {
    $windowStart = [Math]::Max(0, $i - 14)
    $context = ($llmLines[$windowStart..$i] -join "`n")
    Assert-True "model_downloads True confined to local llama context (line $($i + 1))" `
      ($context -match "local_llama_cpp|LOCAL_LLM_MODEL|not_applicable_local_mode")
  }
}

Write-Host "[llm-responses] contract"
$contract = Invoke-JsonGet "$base/llm/api/v1/responses/contract"
Assert-Equal "contract version" $contract.contract_version "llm-responses-adapter-contract-v1"
Assert-Equal "evidence ref" $contract.evidence_ref "llm_responses_adapter_contract_visible"
Assert-Equal "runtime endpoint" $contract.runtime_endpoint "POST /llm/v1/responses"
Assert-Equal "service runtime route" $contract.service_runtime_route "POST /v1/responses"
Assert-True "contract live provider calls false" ($contract.live_provider_calls -eq $false)
Assert-True "contract model downloads false" ($contract.model_downloads -eq $false)
Assert-True "contract production deploy false" ($contract.production_deploy -eq $false)
Assert-True "contract secret output false" ($contract.secret_output -eq $false)
Assert-True "contract negative cases present" (@($contract.negative_cases).Count -ge 2)

$liveAgentContract = Invoke-JsonGet "$base/api/v1/live-agents/contract"
Assert-Equal "live agent contract version" $liveAgentContract.contract_version "live-agent-steering-v1"
Assert-Equal "live agent llm contract version" $liveAgentContract.llm_gateway_contract_version "llm-responses-adapter-contract-v1"
Assert-Equal "live agent llm contract endpoint" $liveAgentContract.llm_gateway_contract_endpoint "GET /llm/api/v1/responses/contract"
Assert-True "live agent required output_text" (@($liveAgentContract.required_llm_response_fields) -contains "output_text")
Assert-True "live agent required audit" (@($liveAgentContract.required_llm_response_fields) -contains "audit_persisted")

Write-Host "[llm-responses] runtime dry-run"
$traceId = "llm-responses-contract-" + [Guid]::NewGuid().ToString("N")
$responsePayload = Invoke-JsonPost "$base/llm/v1/responses" @{
  model = "Qwen/Qwen3-Coder-Next:fastest"
  input = "verify llm responses adapter contract"
  store = $true
  metadata = @{
    trace_id = $traceId
    agent_type = "coder"
    run_id = $traceId
  }
  stream = $false
}

Assert-Equal "response object" $responsePayload.object "response"
Assert-Equal "response status" $responsePayload.status "completed"
Assert-Equal "response contract version" $responsePayload.contract_version "llm-responses-adapter-contract-v1"
Assert-Equal "response evidence ref" $responsePayload.evidence_ref "llm_responses_adapter_contract_visible"
Assert-Equal "response trace id" $responsePayload.trace_id $traceId
Assert-True "response output text present" (-not [string]::IsNullOrWhiteSpace([string]$responsePayload.output_text))
Assert-True "response output array present" (@($responsePayload.output).Count -ge 1)
Assert-True "response live provider calls false" ($responsePayload.live_provider_calls -eq $false)
Assert-True "response model downloads false" ($responsePayload.model_downloads -eq $false)
Assert-True "response audit persisted" ($responsePayload.audit_persisted -eq $true)
Assert-True "response usage visible" ([int]$responsePayload.usage.total_tokens -gt 0)

$audit = Invoke-JsonGet "$base/api/v1/audit/recent?limit=100"
$auditJson = $audit | ConvertTo-Json -Depth 24
Assert-Contains "audit contains trace id" $auditJson $traceId
Assert-Contains "audit contains llm event" $auditJson "llm_gateway_request"

Write-Host "[llm-responses] negative cases"
$streamStatus = Invoke-StatusPost "$base/llm/v1/responses" @{
  model = "Qwen/Qwen3-Coder-Next:fastest"
  input = "stream should be rejected"
  metadata = @{ trace_id = "$traceId-stream"; agent_type = "tester" }
  stream = $true
}
Assert-Equal "stream true rejected" $streamStatus 501

$metadataStatus = Invoke-StatusPost "$base/llm/v1/responses" @{
  model = "Qwen/Qwen3-Coder-Next:fastest"
  input = "metadata should be structured"
  metadata = "not-an-object"
  stream = $false
}
Assert-Equal "metadata object required" $metadataStatus 422

Write-Host "[llm-responses] trace=$traceId"
Write-Host "[llm-responses] checks completed"

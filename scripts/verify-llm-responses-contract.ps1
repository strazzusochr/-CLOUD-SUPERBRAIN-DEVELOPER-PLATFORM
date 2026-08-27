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

function Invoke-JsonPostResult([string]$Url, $Body) {
  Add-Type -AssemblyName System.Net.Http
  $handler = New-Object System.Net.Http.HttpClientHandler
  $client = New-Object System.Net.Http.HttpClient($handler)
  $client.Timeout = [TimeSpan]::FromSeconds(60)
  $request = New-Object System.Net.Http.HttpRequestMessage(
    [System.Net.Http.HttpMethod]::Post,
    $Url
  )
  $response = $null
  try {
    $json = $Body | ConvertTo-Json -Depth 16
    $request.Content = New-Object System.Net.Http.StringContent(
      $json,
      [System.Text.Encoding]::UTF8,
      "application/json"
    )
    $response = $client.SendAsync($request).GetAwaiter().GetResult()
    $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    $payload = $null
    if (-not [string]::IsNullOrWhiteSpace($content)) {
      try {
        $payload = $content | ConvertFrom-Json
      } catch {
        throw "POST $Url returned non-JSON content: $content"
      }
    }
    return [pscustomobject]@{
      StatusCode = [int]$response.StatusCode
      Content = $content
      Payload = $payload
    }
  } finally {
    if ($null -ne $response) { $response.Dispose() }
    $request.Dispose()
    $client.Dispose()
    $handler.Dispose()
  }
}

function Get-HttpHeader($Response, [string]$Name) {
  $values = $null
  if ($Response.Headers.TryGetValues($Name, [ref]$values)) {
    return (@($values) -join ",")
  }
  $values = $null
  if ($Response.Content.Headers.TryGetValues($Name, [ref]$values)) {
    return (@($values) -join ",")
  }
  return ""
}

function Invoke-SsePost([string]$Url, $Body) {
  Add-Type -AssemblyName System.Net.Http
  $handler = New-Object System.Net.Http.HttpClientHandler
  $client = New-Object System.Net.Http.HttpClient($handler)
  $client.Timeout = [TimeSpan]::FromSeconds(60)
  $request = New-Object System.Net.Http.HttpRequestMessage(
    [System.Net.Http.HttpMethod]::Post,
    $Url
  )
  $response = $null
  $stream = $null
  $reader = $null
  try {
    $json = $Body | ConvertTo-Json -Depth 16
    $request.Content = New-Object System.Net.Http.StringContent(
      $json,
      [System.Text.Encoding]::UTF8,
      "application/json"
    )
    $response = $client.SendAsync(
      $request,
      [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead
    ).GetAwaiter().GetResult()
    if (-not $response.IsSuccessStatusCode) {
      $errorContent = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
      throw "SSE POST $Url returned HTTP $([int]$response.StatusCode): $errorContent"
    }

    $contentType = [string]$response.Content.Headers.ContentType.MediaType
    $cacheControl = Get-HttpHeader $response "Cache-Control"
    $accelBuffering = Get-HttpHeader $response "X-Accel-Buffering"
    $events = New-Object 'System.Collections.Generic.List[object]'
    $currentEvent = ""
    $dataLines = New-Object 'System.Collections.Generic.List[string]'
    $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
    $reader = New-Object System.IO.StreamReader($stream)

    while (-not $reader.EndOfStream) {
      $line = $reader.ReadLine()
      if ([string]::IsNullOrEmpty($line)) {
        if ($dataLines.Count -gt 0) {
          $dataText = $dataLines -join "`n"
          $eventPayload = $dataText
          if ($dataText -ne "[DONE]") {
            try {
              $eventPayload = $dataText | ConvertFrom-Json
            } catch {
              throw "SSE event '$currentEvent' returned non-JSON data: $dataText"
            }
          }
          $events.Add([pscustomobject]@{
            Name = $currentEvent
            Data = $eventPayload
            RawData = $dataText
          }) | Out-Null
        }
        $currentEvent = ""
        $dataLines = New-Object 'System.Collections.Generic.List[string]'
        continue
      }
      if ($line.StartsWith("event:")) {
        $currentEvent = $line.Substring(6).Trim()
        continue
      }
      if ($line.StartsWith("data:")) {
        $dataLines.Add($line.Substring(5).TrimStart()) | Out-Null
      }
    }
    if ($dataLines.Count -gt 0) {
      $dataText = $dataLines -join "`n"
      $eventPayload = $dataText
      if ($dataText -ne "[DONE]") {
        try {
          $eventPayload = $dataText | ConvertFrom-Json
        } catch {
          throw "SSE event '$currentEvent' returned non-JSON data: $dataText"
        }
      }
      $events.Add([pscustomobject]@{
        Name = $currentEvent
        Data = $eventPayload
        RawData = $dataText
      }) | Out-Null
    }

    return [pscustomobject]@{
      StatusCode = [int]$response.StatusCode
      ContentType = $contentType
      CacheControl = $cacheControl
      AccelBuffering = $accelBuffering
      Events = $events.ToArray()
    }
  } finally {
    if ($null -ne $reader) { $reader.Dispose() }
    elseif ($null -ne $stream) { $stream.Dispose() }
    if ($null -ne $response) { $response.Dispose() }
    $request.Dispose()
    $client.Dispose()
    $handler.Dispose()
  }
}

$base = Normalize-BaseUrl $BaseUrl
Assert-BaseUrlAllowed $base ([bool]$AllowLocalhost)
$baseUri = [System.Uri]$base
$isLocalProof = $baseUri.Host -in @("localhost", "127.0.0.1", "::1")

$repoRoot = Split-Path $PSScriptRoot -Parent
$llmGatewayPath = Join-Path $repoRoot "services\llm-gateway\app\main.py"
$llmGatewayTestPath = Join-Path $repoRoot "services\llm-gateway\tests\test_responses_streaming.py"
$agentApiPath = Join-Path $repoRoot "services\agent-api\app\main.py"
$nginxDevPath = Join-Path $repoRoot "infrastructure\nginx\dev.conf"
$nginxCloudPath = Join-Path $repoRoot "infrastructure\nginx\cloud.conf"

Assert-True "llm gateway source exists" (Test-Path -LiteralPath $llmGatewayPath)
Assert-True "llm gateway Responses tests exist" (Test-Path -LiteralPath $llmGatewayTestPath)
Assert-True "agent api source exists" (Test-Path -LiteralPath $agentApiPath)
Assert-True "dev nginx source exists" (Test-Path -LiteralPath $nginxDevPath)
Assert-True "cloud nginx source exists" (Test-Path -LiteralPath $nginxCloudPath)

$llmSource = Get-Content -LiteralPath $llmGatewayPath -Raw
$llmTestSource = Get-Content -LiteralPath $llmGatewayTestPath -Raw
$agentSource = Get-Content -LiteralPath $agentApiPath -Raw
$nginxDevSource = Get-Content -LiteralPath $nginxDevPath -Raw
$nginxCloudSource = Get-Content -LiteralPath $nginxCloudPath -Raw

foreach ($required in @(
  "LLM_RESPONSES_ADAPTER_CONTRACT_VERSION",
  "llm-responses-adapter-contract-v2",
  "llm_responses_adapter_contract_visible",
  "RESPONSES_STREAMING_PROTOCOL",
  "openai-responses-sse-v1",
  '@app.get("/api/v1/responses/contract")',
  '@app.post("/v1/responses")',
  "responses_stream_events",
  "audit_responses_event",
  "metadata must be an object",
  "stream must be a boolean",
  "MAX_RESPONSES_OUTPUT_TOKENS",
  "MAX_RESPONSES_INSTRUCTIONS_CHARS",
  "store_responses_context",
  "load_responses_context",
  "Responses stream audit persistence failed before emission",
  "max_output_tokens must be an integer between 1 and",
  '"model_downloads": False',
  '"secret_output": False'
)) {
  Assert-Contains "llm gateway source" $llmSource $required
}

foreach ($required in @(
  "LLM_RESPONSES_ADAPTER_CONTRACT_VERSION",
  "llm-responses-adapter-contract-v2",
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

foreach ($required in @(
  "test_stream_endpoint_refuses_to_emit_when_audit_persistence_fails",
  "test_instructions_and_previous_response_are_applied_to_gateway_messages",
  "test_unknown_previous_response_id_is_rejected"
)) {
  Assert-Contains "llm gateway Responses tests" $llmTestSource $required
}

foreach ($entry in @(
  [pscustomobject]@{ Label = "dev nginx"; Source = $nginxDevSource },
  [pscustomobject]@{ Label = "cloud nginx"; Source = $nginxCloudSource }
)) {
  foreach ($required in @("location /llm/", "proxy_buffering off", "proxy_cache off", "proxy_pass_header X-Accel-Buffering")) {
    Assert-Contains "$($entry.Label) Responses streaming boundary" $entry.Source $required
  }
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
Assert-Equal "contract version" $contract.contract_version "llm-responses-adapter-contract-v2"
Assert-Equal "evidence ref" $contract.evidence_ref "llm_responses_adapter_contract_visible"
Assert-Equal "runtime endpoint" $contract.runtime_endpoint "POST /llm/v1/responses"
Assert-Equal "service runtime route" $contract.service_runtime_route "POST /v1/responses"
Assert-Contains "streaming protocol" ($contract | ConvertTo-Json -Depth 24) "openai-responses-sse-v1"
Assert-True "contract live provider calls false" ($contract.live_provider_calls -eq $false)
Assert-True "contract model downloads false" ($contract.model_downloads -eq $false)
Assert-True "contract production deploy false" ($contract.production_deploy -eq $false)
Assert-True "contract secret output false" ($contract.secret_output -eq $false)
Assert-True "contract negative cases present" (@($contract.negative_cases).Count -ge 2)
Assert-True "contract audit failure case present" (
  @($contract.failure_cases | Where-Object { [string]$_.condition -like "stream audit persistence*" -and [int]$_.expected_status -eq 503 }).Count -eq 1
)
Assert-Equal "contract output-token limit" $contract.streaming_schema.limits.output_tokens 8192
Assert-Equal "contract instruction limit" $contract.streaming_schema.limits.instructions_chars 8192
Assert-Equal "contract context-store limit" $contract.streaming_schema.limits.stored_contexts 64
Assert-True "contract process-local continuity" ($contract.adapter.stateful_sessions_supported -eq $true)
Assert-Equal "contract continuity scope" $contract.adapter.stateful_session_scope "bounded_process_local_context_store"

$liveAgentContract = Invoke-JsonGet "$base/api/v1/live-agents/contract"
Assert-Equal "live agent contract version" $liveAgentContract.contract_version "live-agent-steering-v1"
Assert-Equal "live agent llm contract version" $liveAgentContract.llm_gateway_contract_version "llm-responses-adapter-contract-v2"
Assert-Equal "live agent llm contract endpoint" $liveAgentContract.llm_gateway_contract_endpoint "GET /llm/api/v1/responses/contract"
Assert-True "live agent required output_text" (@($liveAgentContract.required_llm_response_fields) -contains "output_text")
Assert-True "live agent required audit" (@($liveAgentContract.required_llm_response_fields) -contains "audit_persisted")

if ($isLocalProof) {
  Write-Host "[llm-responses] local runtime dry-run"
  $traceId = "llm-responses-contract-" + [Guid]::NewGuid().ToString("N")
  $responsePayload = Invoke-JsonPost "$base/llm/v1/responses" @{
    model = "qwen3.7-plus"
    input = "verify llm responses adapter contract"
    store = $true
    metadata = @{
      trace_id = $traceId
      agent_type = "coder"
      run_id = $traceId
      deterministic_dry_run = $true
      live_provider_calls_allowed = $false
    }
    stream = $false
  }

  Assert-Equal "response object" $responsePayload.object "response"
  Assert-Equal "response status" $responsePayload.status "completed"
  Assert-Equal "response contract version" $responsePayload.contract_version "llm-responses-adapter-contract-v2"
  Assert-Equal "response evidence ref" $responsePayload.evidence_ref "llm_responses_adapter_contract_visible"
  Assert-Equal "response trace id" $responsePayload.trace_id $traceId
  Assert-True "response output text present" (-not [string]::IsNullOrWhiteSpace([string]$responsePayload.output_text))
  Assert-True "response output array present" (@($responsePayload.output).Count -ge 1)
  Assert-True "response live provider calls false" ($responsePayload.live_provider_calls -eq $false)
  Assert-True "response local model calls false" ($responsePayload.local_model_calls -eq $false)
  Assert-True "response model downloads false" ($responsePayload.model_downloads -eq $false)
  Assert-True "response secret output false" ($responsePayload.secret_output -eq $false)
  Assert-True "response audit persisted" ($responsePayload.audit_persisted -eq $true)
  Assert-True "response usage visible" ([int]$responsePayload.usage.total_tokens -gt 0)

  $audit = Invoke-JsonGet "$base/api/v1/audit/recent?limit=100"
  $auditJson = $audit | ConvertTo-Json -Depth 24
  Assert-Contains "audit contains trace id" $auditJson $traceId
  Assert-Contains "audit contains llm event" $auditJson "llm_gateway_request"

  Write-Host "[llm-responses] bounded instructions and previous-response continuity"
  $continuityInstructions = "Apply the trusted bounded continuity instructions."
  $continuityInput = "verify previous response context is applied"
  $continuityTraceId = "llm-responses-continuity-" + [Guid]::NewGuid().ToString("N")
  $continuity = Invoke-JsonPost "$base/llm/v1/responses" @{
    model = "qwen3.7-plus"
    instructions = $continuityInstructions
    input = $continuityInput
    previous_response_id = $responsePayload.id
    store = $false
    metadata = @{
      trace_id = $continuityTraceId
      agent_type = "coder"
      deterministic_dry_run = $true
      live_provider_calls_allowed = $false
    }
    stream = $false
  }
  $digestMaterial = $continuityInstructions + "|verify llm responses adapter contract|" + [string]$responsePayload.output_text + "|" + $continuityInput + "qwen3.7-plus"
  $digestBytes = [System.Text.Encoding]::UTF8.GetBytes($digestMaterial)
  $digestHash = [System.BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($digestBytes)).Replace("-", "").ToLowerInvariant().Substring(0, 12)
  Assert-Contains "continuity applied to gateway messages" ([string]$continuity.output_text) "llm-dry-run:$digestHash"
  Assert-Equal "continuity trace id" $continuity.trace_id $continuityTraceId
  Assert-True "continuity audit persisted" ($continuity.audit_persisted -eq $true)

  Write-Host "[llm-responses] deterministic Responses SSE"
  $streamTraceId = "llm-responses-stream-contract-" + [Guid]::NewGuid().ToString("N")
  $streamResult = Invoke-SsePost "$base/llm/v1/responses" @{
    model = "qwen3.7-plus"
    input = "verify deterministic Responses streaming with ordered auditable events"
    store = $true
    metadata = @{
      trace_id = $streamTraceId
      agent_type = "tester"
      run_id = $streamTraceId
      deterministic_dry_run = $true
      live_provider_calls_allowed = $false
    }
    stream = $true
  }

  Assert-Equal "stream status" $streamResult.StatusCode 200
  Assert-Equal "stream content type" $streamResult.ContentType "text/event-stream"
  Assert-Contains "stream cache control" $streamResult.CacheControl "no-store"
  Assert-Equal "stream proxy buffering disabled" $streamResult.AccelBuffering.ToLowerInvariant() "no"
  Assert-True "stream events present" (@($streamResult.Events).Count -ge 10)
  Assert-True "stream omits chat-completions done sentinel" (
    @($streamResult.Events | Where-Object { [string]$_.RawData -eq "[DONE]" }).Count -eq 0
  )

  $streamEvents = @($streamResult.Events)
  $deltaEvents = @($streamEvents | Where-Object { [string]$_.Data.type -eq "response.output_text.delta" })
  Assert-True "stream has at least two text deltas" ($deltaEvents.Count -ge 2)
  $expectedTypes = @(
    "response.created",
    "response.in_progress",
    "response.output_item.added",
    "response.content_part.added"
  )
  for ($i = 0; $i -lt $deltaEvents.Count; $i++) {
    $expectedTypes += "response.output_text.delta"
  }
  $expectedTypes += @(
    "response.output_text.done",
    "response.content_part.done",
    "response.output_item.done",
    "response.completed"
  )
  $actualTypes = @($streamEvents | ForEach-Object { [string]$_.Data.type })
  Assert-Equal "stream exact event order count" $actualTypes.Count $expectedTypes.Count
  for ($i = 0; $i -lt $expectedTypes.Count; $i++) {
    Assert-Equal "stream exact event order index $i" $actualTypes[$i] $expectedTypes[$i]
    Assert-Equal "stream event envelope index $i" ([string]$streamEvents[$i].Name) $expectedTypes[$i]
  }

  $previousSequence = -1
  foreach ($event in $streamEvents) {
    $sequence = [int]$event.Data.sequence_number
    Assert-True "stream sequence monotonic at $sequence" ($sequence -gt $previousSequence)
    $previousSequence = $sequence
  }

  $createdEvent = $streamEvents[0].Data
  $inProgressEvent = $streamEvents[1].Data
  $outputItemAdded = ($streamEvents | Where-Object { [string]$_.Data.type -eq "response.output_item.added" } | Select-Object -First 1).Data
  $contentPartAdded = ($streamEvents | Where-Object { [string]$_.Data.type -eq "response.content_part.added" } | Select-Object -First 1).Data
  $textDone = ($streamEvents | Where-Object { [string]$_.Data.type -eq "response.output_text.done" } | Select-Object -First 1).Data
  $contentPartDone = ($streamEvents | Where-Object { [string]$_.Data.type -eq "response.content_part.done" } | Select-Object -First 1).Data
  $outputItemDone = ($streamEvents | Where-Object { [string]$_.Data.type -eq "response.output_item.done" } | Select-Object -First 1).Data
  $completed = ($streamEvents | Where-Object { [string]$_.Data.type -eq "response.completed" } | Select-Object -First 1).Data
  $completedResponse = $completed.response
  $completedItem = @($completedResponse.output)[0]
  $responseId = [string]$completedResponse.id
  $itemId = [string]$completedItem.id
  Assert-True "stream response id present" (-not [string]::IsNullOrWhiteSpace($responseId))
  Assert-True "stream item id present" (-not [string]::IsNullOrWhiteSpace($itemId))
  Assert-Equal "stream created response id stable" $createdEvent.response.id $responseId
  Assert-Equal "stream in-progress response id stable" $inProgressEvent.response.id $responseId
  Assert-Equal "stream output item added id stable" $outputItemAdded.item.id $itemId
  Assert-Equal "stream content part added item id stable" $contentPartAdded.item_id $itemId
  Assert-Equal "stream text done item id stable" $textDone.item_id $itemId
  Assert-Equal "stream content part done item id stable" $contentPartDone.item_id $itemId
  Assert-Equal "stream output item done id stable" $outputItemDone.item.id $itemId
  foreach ($deltaEvent in $deltaEvents) {
    Assert-Equal "stream delta item id stable" $deltaEvent.Data.item_id $itemId
  }

  $reconstructedText = (@($deltaEvents | ForEach-Object { [string]$_.Data.delta }) -join "")
  Assert-True "stream delta reconstruction non-empty" (-not [string]::IsNullOrWhiteSpace($reconstructedText))
  Assert-Equal "stream delta reconstruction equals text done" $reconstructedText ([string]$textDone.text)
  Assert-Equal "stream delta reconstruction equals content part done" $reconstructedText ([string]$contentPartDone.part.text)
  Assert-Equal "stream delta reconstruction equals output item done" $reconstructedText ([string]$outputItemDone.item.content[0].text)
  Assert-Equal "stream delta reconstruction equals completed output_text" $reconstructedText ([string]$completedResponse.output_text)
  Assert-Equal "stream completed contract version" $completedResponse.contract_version "llm-responses-adapter-contract-v2"
  Assert-Equal "stream completed trace id" $completedResponse.trace_id $streamTraceId
  Assert-True "stream terminal audit persisted" ($completedResponse.audit_persisted -eq $true)
  Assert-True "stream terminal live provider calls false" ($completedResponse.live_provider_calls -eq $false)
  Assert-True "stream terminal local model calls false" ($completedResponse.local_model_calls -eq $false)
  Assert-True "stream terminal model downloads false" ($completedResponse.model_downloads -eq $false)
  Assert-True "stream terminal secret output false" ($completedResponse.secret_output -eq $false)

  $streamAudit = Invoke-JsonGet "$base/api/v1/audit/recent?limit=100"
  $streamAuditJson = $streamAudit | ConvertTo-Json -Depth 24
  Assert-Contains "stream audit contains trace id" $streamAuditJson $streamTraceId
  Assert-Contains "stream audit contains llm event" $streamAuditJson "llm_gateway_request"

  Write-Host "[llm-responses] local negative cases"
  $liveStreamStatus = Invoke-StatusPost "$base/llm/v1/responses" @{
    model = "qwen3.7-plus"
    input = "live provider streaming must remain closed"
    metadata = @{
      trace_id = "$traceId-live-stream"
      agent_type = "tester"
      live_provider_calls_allowed = $true
    }
    stream = $true
  }
  Assert-Equal "live provider stream rejected" $liveStreamStatus 403

  $metadataStatus = Invoke-StatusPost "$base/llm/v1/responses" @{
    model = "qwen3.7-plus"
    input = "metadata should be structured"
    metadata = "not-an-object"
    stream = $false
  }
  Assert-Equal "metadata object required" $metadataStatus 422

  $streamTypeStatus = Invoke-StatusPost "$base/llm/v1/responses" @{
    model = "qwen3.7-plus"
    input = "stream must be typed"
    metadata = @{ trace_id = "$traceId-stream-type"; agent_type = "tester" }
    stream = "true"
  }
  Assert-Equal "stream boolean required" $streamTypeStatus 422

  $emptyInputStatus = Invoke-StatusPost "$base/llm/v1/responses" @{
    model = "qwen3.7-plus"
    input = ""
    metadata = @{ trace_id = "$traceId-empty"; agent_type = "tester" }
    stream = $true
  }
  Assert-Equal "non-empty input required" $emptyInputStatus 422

  $outputTokenStatus = Invoke-StatusPost "$base/llm/v1/responses" @{
    model = "qwen3.7-plus"
    input = "requested output tokens must remain bounded"
    max_output_tokens = 8193
    metadata = @{ trace_id = "$traceId-output-token-limit"; agent_type = "tester" }
    stream = $true
  }
  Assert-Equal "bounded output tokens required" $outputTokenStatus 422

  $instructionsStatus = Invoke-StatusPost "$base/llm/v1/responses" @{
    model = "qwen3.7-plus"
    instructions = "x" * 8193
    input = "instructions must remain bounded"
    metadata = @{ trace_id = "$traceId-instruction-limit"; agent_type = "tester" }
    stream = $false
  }
  Assert-Equal "bounded instructions required" $instructionsStatus 422

  $previousResponseStatus = Invoke-StatusPost "$base/llm/v1/responses" @{
    model = "qwen3.7-plus"
    input = "previous response ids must be adapter-issued"
    previous_response_id = "not-a-response-id"
    metadata = @{ trace_id = "$traceId-previous-response-format"; agent_type = "tester" }
    stream = $false
  }
  Assert-Equal "previous response id format required" $previousResponseStatus 422
} else {
  Write-Host "[llm-responses] hosted read-only boundary"
  $traceId = "llm-responses-hosted-boundary-" + [Guid]::NewGuid().ToString("N")
  $blocked = Invoke-JsonPostResult "$base/llm/v1/responses" @{
    model = "qwen3.7-plus"
    input = "verify hosted read-only LLM boundary"
    store = $true
    metadata = @{ trace_id = $traceId; agent_type = "tester" }
    stream = $false
  }
  Assert-Equal "hosted response blocked status" $blocked.StatusCode 503
  Assert-True "hosted response JSON present" ($null -ne $blocked.Payload)
  Assert-Equal "hosted response state" $blocked.Payload.status "blocked"
  Assert-True "hosted response reason" (
    [string]$blocked.Payload.reason -in @(
      "stateless_contract_origin_read_only",
      "configured_boundary_unavailable"
    )
  )
  Assert-True "hosted response not accepted" ($blocked.Payload.accepted -eq $false)
  Assert-True "hosted response not persisted" ($blocked.Payload.persisted -eq $false)
  Assert-True "hosted response audit not persisted" ($blocked.Payload.audit_persisted -eq $false)
  Assert-True "hosted response no direct provider" ($blocked.Payload.direct_provider_calls -eq $false)
  Assert-True "hosted response no live provider" ($blocked.Payload.live_provider_calls -eq $false)
  Assert-True "hosted response no secret output" ($blocked.Payload.secret_output -eq $false)
  Assert-NotContains "hosted response no completion claim" $blocked.Content '"status":"completed"'
  Assert-NotContains "hosted response no audit claim" $blocked.Content '"audit_persisted":true'
}

Write-Host "[llm-responses] trace=$traceId"
Write-Host "[llm-responses] checks completed"

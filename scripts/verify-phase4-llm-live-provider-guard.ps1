param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "LLM live provider guard verification failed: $label"
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
  $payloadFile = Join-Path $env:TEMP ("llm-guard-http-" + [Guid]::NewGuid().ToString("N") + ".json")
  $pythonFile = Join-Path $env:TEMP ("llm-guard-http-" + [Guid]::NewGuid().ToString("N") + ".py")
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

function Invoke-JsonApi($url, $method = "GET", $body = $null) {
  $response = Invoke-RawHttp -Url $url -Method $method -Body $body
  if ([int]$response.StatusCode -ge 400) {
    throw "$method $url returned HTTP $($response.StatusCode): $($response.Content)"
  }
  return ($response.Content | ConvertFrom-Json)
}

function Assert-BlockedDirectProvider($label, $response) {
  Assert-True "$label status" ([int]$response.StatusCode -eq 403)
  $payload = $response.Content | ConvertFrom-Json
  Assert-True "$label code" ($payload.detail.code -eq "llm_routing_policy_direct_provider_blocked")
  Assert-True "$label evidence" ($payload.detail.evidence_ref -eq "llm_routing_policy_direct_provider_blocked")
  Assert-True "$label no live call" ($payload.detail.live_provider_calls -eq $false)
}

function Assert-BlockedLlmPolicy($label, $response, $statusCode, $code) {
  Assert-True "$label status" ([int]$response.StatusCode -eq $statusCode)
  $payload = $response.Content | ConvertFrom-Json
  Assert-True "$label code" ($payload.detail.code -eq $code)
  Assert-True "$label evidence" ($payload.detail.evidence_ref -eq $code)
  Assert-True "$label no live call" ($payload.detail.live_provider_calls -eq $false)
  Assert-True "$label no model download" ($payload.detail.model_downloads -eq $false)
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ((-not $AllowLocalhost) -and ($BaseUrl -match "localhost|127\.0\.0\.1|\[::1\]")) {
  throw "LLM live provider guard proof refuses localhost unless -AllowLocalhost is set"
}

Write-Host "[phase4-llm-live-provider-guard] base url: $BaseUrl"

$fakeProviderRefPrefix = "sec" + "ret://"

$providers = Invoke-JsonApi "$BaseUrl/llm/api/v1/providers/status"
Assert-True "providers policy exposes override guard" ($providers.policy.request_live_provider_override_enabled -eq $false)
Assert-True "providers policy explains metadata guard" ([string]$providers.policy.requires_request_metadata -match "LLM_ALLOW_REQUEST_LIVE_PROVIDER_OVERRIDE=true")
Assert-True "providers policy blocks direct metadata" (@($providers.policy.direct_provider_metadata_keys_blocked) -contains "direct_provider_url")
Assert-True "providers policy blocks provider key refs" (@($providers.policy.direct_provider_metadata_keys_blocked) -contains "provider_api_key_ref")
Assert-True "providers policy blocks url-like models" ($providers.policy.url_like_model_ids_blocked -eq $true)
Assert-True "providers policy blocks unknown models" ($providers.policy.unknown_model_ids_blocked -eq $true)
Assert-True "providers policy exposes output guard" ($providers.policy.output_token_budget_guard.evidence_ref -eq "llm_output_token_budget_guard")

$chatBody = @{
  model = "deepseek-ai/DeepSeek-V4-Flash:fastest"
  stream = $false
  messages = @(
    @{ role = "user"; content = "Return a deterministic dry-run proof." }
  )
  metadata = @{
    live_provider_calls_allowed = $true
    source = "phase4-live-provider-guard"
  }
} | ConvertTo-Json -Compress -Depth 6

$chat = Invoke-JsonApi "$BaseUrl/llm/v1/chat/completions" "POST" $chatBody
Assert-True "chat remains deterministic" ($chat.live_provider_calls -eq $false)
Assert-True "chat proof text" ([string]$chat.choices[0].message.content -match "live_provider_calls=false")

$responsesBody = @{
  model = "deepseek-ai/DeepSeek-V4-Flash:fastest"
  input = "Return a deterministic responses proof."
  metadata = @{
    live_provider_calls_allowed = $true
    source = "phase4-live-provider-guard"
  }
} | ConvertTo-Json -Compress -Depth 6

$responses = Invoke-JsonApi "$BaseUrl/llm/v1/responses" "POST" $responsesBody
Assert-True "responses remains deterministic" ($responses.live_provider_calls -eq $false)
Assert-True "responses proof text" ([string]$responses.output_text -match "live_provider_calls=false")
Assert-True "responses audit persisted flag present" ($null -ne $responses.audit_persisted)

$directChatBody = @{
  model = "https://provider.example/v1/chat/completions"
  stream = $false
  messages = @(
    @{ role = "user"; content = "This must be blocked before routing." }
  )
  metadata = @{
    live_provider_calls_allowed = $true
    direct_provider_url = "https://provider.example/v1"
    provider_api_key_ref = $fakeProviderRefPrefix + "provider-key"
  }
} | ConvertTo-Json -Compress -Depth 6

$directChat = Invoke-RawHttp -Url "$BaseUrl/llm/v1/chat/completions" -Method "POST" -Body $directChatBody
Assert-BlockedDirectProvider "chat direct provider blocked" $directChat

$directResponsesBody = @{
  model = "deepseek-ai/DeepSeek-V4-Flash:fastest"
  input = "This direct provider metadata must be blocked."
  metadata = @{
    direct_provider_key_ref = $fakeProviderRefPrefix + "direct-provider"
  }
} | ConvertTo-Json -Compress -Depth 6

$directResponses = Invoke-RawHttp -Url "$BaseUrl/llm/v1/responses" -Method "POST" -Body $directResponsesBody
Assert-BlockedDirectProvider "responses direct provider blocked" $directResponses

$oversizedChatBody = @{
  model = "deepseek-ai/DeepSeek-V4-Flash:fastest"
  max_tokens = 1000000
  messages = @(
    @{ role = "user"; content = "This must be blocked by the output token guard." }
  )
  metadata = @{
    source = "phase4-output-token-guard"
  }
} | ConvertTo-Json -Compress -Depth 6

$oversizedChat = Invoke-RawHttp -Url "$BaseUrl/llm/v1/chat/completions" -Method "POST" -Body $oversizedChatBody
Assert-BlockedLlmPolicy "chat oversized output blocked" $oversizedChat 422 "llm_output_token_budget_guard"

$oversizedResponsesBody = @{
  model = "deepseek-ai/DeepSeek-V4-Flash:fastest"
  input = "This must be blocked by the responses output token guard."
  max_output_tokens = 1000000
  metadata = @{
    source = "phase4-output-token-guard"
  }
} | ConvertTo-Json -Compress -Depth 6

$oversizedResponses = Invoke-RawHttp -Url "$BaseUrl/llm/v1/responses" -Method "POST" -Body $oversizedResponsesBody
Assert-BlockedLlmPolicy "responses oversized output blocked" $oversizedResponses 422 "llm_output_token_budget_guard"

$zeroChatBody = @{
  model = "deepseek-ai/DeepSeek-V4-Flash:fastest"
  max_tokens = 0
  messages = @(
    @{ role = "user"; content = "This zero token request must be blocked." }
  )
  metadata = @{
    source = "phase4-output-token-guard"
  }
} | ConvertTo-Json -Compress -Depth 6

$zeroChat = Invoke-RawHttp -Url "$BaseUrl/llm/v1/chat/completions" -Method "POST" -Body $zeroChatBody
Assert-BlockedLlmPolicy "chat zero output blocked" $zeroChat 422 "llm_output_token_budget_guard"

$zeroResponsesBody = @{
  model = "deepseek-ai/DeepSeek-V4-Flash:fastest"
  input = "This zero responses output token request must be blocked."
  max_output_tokens = 0
  metadata = @{
    source = "phase4-output-token-guard"
  }
} | ConvertTo-Json -Compress -Depth 6

$zeroResponses = Invoke-RawHttp -Url "$BaseUrl/llm/v1/responses" -Method "POST" -Body $zeroResponsesBody
Assert-BlockedLlmPolicy "responses zero output blocked" $zeroResponses 422 "llm_output_token_budget_guard"

$stringTokenResponsesBody = @{
  model = "deepseek-ai/DeepSeek-V4-Flash:fastest"
  input = "This string responses output token request must be blocked."
  max_output_tokens = "1000000"
  metadata = @{
    source = "phase4-output-token-guard"
  }
} | ConvertTo-Json -Compress -Depth 6

$stringTokenResponses = Invoke-RawHttp -Url "$BaseUrl/llm/v1/responses" -Method "POST" -Body $stringTokenResponsesBody
Assert-BlockedLlmPolicy "responses string output blocked" $stringTokenResponses 422 "llm_output_token_budget_guard"

$boolTokenResponsesBody = @{
  model = "deepseek-ai/DeepSeek-V4-Flash:fastest"
  input = "This boolean responses output token request must be blocked."
  max_output_tokens = $true
  metadata = @{
    source = "phase4-output-token-guard"
  }
} | ConvertTo-Json -Compress -Depth 6

$boolTokenResponses = Invoke-RawHttp -Url "$BaseUrl/llm/v1/responses" -Method "POST" -Body $boolTokenResponsesBody
Assert-BlockedLlmPolicy "responses bool output blocked" $boolTokenResponses 422 "llm_output_token_budget_guard"

$unknownModelBody = @{
  model = "not-configured/example-model"
  messages = @(
    @{ role = "user"; content = "This unknown model must be blocked before routing." }
  )
  metadata = @{
    source = "phase4-unknown-model-guard"
  }
} | ConvertTo-Json -Compress -Depth 6

$unknownModel = Invoke-RawHttp -Url "$BaseUrl/llm/v1/chat/completions" -Method "POST" -Body $unknownModelBody
Assert-BlockedLlmPolicy "chat unknown model blocked" $unknownModel 422 "llm_routing_policy_unknown_model_blocked"

Write-Host "[phase4-llm-live-provider-guard] ok"

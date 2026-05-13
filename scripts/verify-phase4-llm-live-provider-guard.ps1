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

function Invoke-JsonApi($url, $method = "GET", $body = $null) {
  $params = @{
    Uri = $url
    Method = $method
    TimeoutSec = 60
  }
  if ($null -ne $body) {
    $params.Body = $body
    $params.ContentType = "application/json"
  }
  $response = Invoke-WebRequest @params
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
  throw "LLM live provider guard proof refuses localhost unless -AllowLocalhost is set"
}

Write-Host "[phase4-llm-live-provider-guard] base url: $BaseUrl"

$providers = Invoke-JsonApi "$BaseUrl/llm/api/v1/providers/status"
Assert-True "providers policy exposes override guard" ($providers.policy.request_live_provider_override_enabled -eq $false)
Assert-True "providers policy explains metadata guard" ([string]$providers.policy.requires_request_metadata -match "LLM_ALLOW_REQUEST_LIVE_PROVIDER_OVERRIDE=true")

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

Write-Host "[phase4-llm-live-provider-guard] ok"

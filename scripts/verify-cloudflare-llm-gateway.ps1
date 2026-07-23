param(
  [string]$BaseUrl = "",
  [switch]$StaticOnly,
  [string]$EvidencePath = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Assert-Equal($Actual, $Expected, [string]$Label) {
  if ($Actual -ne $Expected) { throw "$Label expected=$Expected actual=$Actual" }
}

function Assert-Contains([string]$Label, [string]$Content, [string]$Needle) {
  if (-not $Content.Contains($Needle)) { throw "$Label missing marker: $Needle" }
}

$workerRoot = Join-Path $repoRoot "services\cloudflare-llm-gateway"
$requiredFiles = @(
  "package.json",
  "wrangler.jsonc",
  "src\index.js",
  "test\index.test.js"
)
foreach ($relative in $requiredFiles) {
  Assert-True (Test-Path -LiteralPath (Join-Path $workerRoot $relative)) "Cloudflare LLM Gateway missing $relative"
}

$package = Get-Content -LiteralPath (Join-Path $workerRoot "package.json") -Raw | ConvertFrom-Json
$config = Get-Content -LiteralPath (Join-Path $workerRoot "wrangler.jsonc") -Raw | ConvertFrom-Json
$source = Get-Content -LiteralPath (Join-Path $workerRoot "src\index.js") -Raw
$testSource = Get-Content -LiteralPath (Join-Path $workerRoot "test\index.test.js") -Raw
$boundarySource = Get-Content -LiteralPath "apps\frontend\lib\frontendBoundary.ts" -Raw
$buildSource = Get-Content -LiteralPath "apps\frontend\app\api\v1\build\route.ts" -Raw
$workbenchSource = Get-Content -LiteralPath "apps\frontend\components\workbench-studio.tsx" -Raw

Assert-Equal ([string]$package.devDependencies.wrangler) "4.112.0" "pinned Wrangler version"
Assert-Equal ([string]$config.name) "cloud-superbrain-llm-gateway" "Worker name"
Assert-Equal ([string]$config.main) "src/index.js" "Worker entrypoint"
Assert-Equal ([string]$config.ai.binding) "AI" "Production Workers AI binding"
Assert-Equal ([string]$config.env.preview.name) "cloud-superbrain-llm-gateway-preview" "Preview Worker name"
Assert-Equal ([string]$config.env.preview.ai.binding) "AI" "Preview Workers AI binding"
Assert-True ([bool]$config.workers_dev) "Worker must expose a free workers.dev HTTPS origin"

foreach ($marker in @(
  'cloudflare-workers-ai-llm-gateway-v1',
  'env.AI.run',
  'GATEWAY_AUTH_TOKEN',
  'x-superbrain-gateway-token',
  '/api/v1/health',
  '/v1/chat/completions',
  'SOURCE_COMMIT_SHA',
  'SOURCE_ARCHIVE_SHA256',
  '@cf/qwen/qwen2.5-coder-32b-instruct',
  '@cf/meta/llama-3.1-8b-instruct',
  'MAX_BODY_BYTES',
  'MAX_INPUT_CHARS',
  'MAX_OUTPUT_TOKENS',
  'stream_not_supported',
  'live_provider_calls: true',
  'direct_provider_calls: false',
  'secret_output: false'
)) {
  Assert-Contains "Worker source" $source $marker
}
Assert-True (-not $source.Contains("CLOUDFLARE_API_TOKEN")) "Worker runtime must use the AI binding, not a provider API token"
Assert-True (-not $source.Contains("api.cloudflare.com/client/v4")) "Worker runtime must not bypass the Workers AI binding"

foreach ($marker in @(
  'LLM_GATEWAY_AUTH_TOKEN',
  'x-superbrain-gateway-token',
  'headers.set(config.authHeaderName, gatewayToken)'
)) {
  Assert-Contains "Frontend boundary" $boundarySource $marker
}
Assert-True (-not $boundarySource.Contains("CLOUDFLARE_API_TOKEN")) "Frontend boundary cannot contain a Cloudflare provider token"

foreach ($marker in @(
  'proxyToBoundary(gatewayRequest, "llm-gateway", "/v1/chat/completions"',
  'live_provider_calls: liveProviderCalls',
  'gateway_provider: String(provider ?? "unknown")',
  'gateway_provider: persistedBuild.gateway_provider',
  'live_provider_calls: persistedBuild.live_provider_calls === true',
  'const models: Array<[string, number]> = [["@cf/qwen/qwen2.5-coder-32b-instruct", 50000]]'
)) {
  Assert-Contains "Frontend build route" $buildSource $marker
}
Assert-True (-not $buildSource.Contains("env.AI.run")) "Frontend build route cannot call Workers AI directly"
Assert-True (-not $buildSource.Contains("CLOUDFLARE_API_TOKEN")) "Frontend build route cannot contain a provider token"
Assert-Contains "Workbench live-call truth" $workbenchSource '"live_provider_calls=true" : "live_provider_calls=false"'

foreach ($marker in @(
  'requires the dedicated server-side gateway token',
  'invokes an allowlisted Workers AI model once',
  'fail closed before inference',
  'assert.equal(calls.length, 1)'
)) {
  Assert-Contains "Worker tests" $testSource $marker
}

& npm.cmd run check --prefix $workerRoot
Assert-True ($LASTEXITCODE -eq 0) "Cloudflare LLM Gateway syntax check failed"
& npm.cmd test --prefix $workerRoot
Assert-True ($LASTEXITCODE -eq 0) "Cloudflare LLM Gateway unit tests failed"

$evidence = [ordered]@{
  contract_version = "cloudflare-workers-ai-llm-gateway-static-proof-v1"
  status = "verified"
  checked_at = [DateTime]::UtcNow.ToString("o")
  worker_name = [string]$config.name
  preview_worker_name = [string]$config.env.preview.name
  workers_ai_binding = [string]$config.ai.binding
  wrangler_version = [string]$package.devDependencies.wrangler
  unit_tests_verified = $true
  direct_frontend_provider_calls = $false
  secret_output = $false
  live_provider_call_executed = $false
}

if (-not $StaticOnly) {
  Assert-True (-not [string]::IsNullOrWhiteSpace($BaseUrl)) "BaseUrl is required unless -StaticOnly is used"
  $uri = [Uri]$BaseUrl
  Assert-Equal $uri.Scheme "https" "Hosted Worker URL scheme"
  Assert-True (-not @("localhost", "127.0.0.1", "::1").Contains($uri.Host)) "Hosted Worker proof cannot use localhost"
  $normalized = $BaseUrl.TrimEnd("/")
  $health = Invoke-RestMethod -Method Get -Uri "$normalized/api/v1/health" -TimeoutSec 30
  Assert-Equal ([string]$health.contract_version) "cloudflare-workers-ai-llm-gateway-v1" "Hosted health contract"
  Assert-Equal ([string]$health.status) "healthy" "Hosted health status"
  Assert-Equal ([string]$health.service) "llm-gateway" "Hosted service marker"
  Assert-True ([bool]$health.live_provider_calls_available) "Hosted Workers AI path must be available"
  Assert-True (-not [bool]$health.live_provider_calls) "Health probe cannot execute inference"
  $models = Invoke-RestMethod -Method Get -Uri "$normalized/v1/models" -TimeoutSec 30
  Assert-Equal @($models.data).Count 2 "Hosted allowlisted model count"
  $evidence.contract_version = "cloudflare-workers-ai-llm-gateway-hosted-proof-v1"
  $evidence.base_url = $normalized
  $evidence.health_status = [string]$health.status
  $evidence.live_provider_calls_available = [bool]$health.live_provider_calls_available
  $evidence.model_count = @($models.data).Count
}

if (-not [string]::IsNullOrWhiteSpace($EvidencePath)) {
  $resolvedEvidence = if ([IO.Path]::IsPathRooted($EvidencePath)) { $EvidencePath } else { Join-Path $repoRoot $EvidencePath }
  $parent = Split-Path -Parent $resolvedEvidence
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  $evidence | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $resolvedEvidence -Encoding utf8
}

Write-Host "[cloudflare-llm-gateway] status=verified static=$([bool]$StaticOnly) live_provider_calls=0"

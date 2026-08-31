param(
  [string]$BaseUrl = "",
  [switch]$StaticOnly,
  [string]$EvidencePath = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot
$sanctionedPreviewBaseUrl = "https://cloud-superbrain-llm-gateway-preview.strazzusochr.workers.dev"

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Assert-Equal($Actual, $Expected, [string]$Label) {
  if ($Actual -ne $Expected) { throw "$Label expected=$Expected actual=$Actual" }
}

function Assert-Contains([string]$Label, [string]$Content, [string]$Needle) {
  if (-not $Content.Contains($Needle)) { throw "$Label missing marker: $Needle" }
}

function Invoke-NoRedirectJson([string]$Uri) {
  try {
    $response = Invoke-WebRequest -Method Get -Uri $Uri -TimeoutSec 30 -UseBasicParsing -SkipHttpErrorCheck -MaximumRedirection 0
  } catch {
    throw "Sanctioned Preview Worker request failed without redirects"
  }
  Assert-True ([int]$response.StatusCode -lt 300 -or [int]$response.StatusCode -ge 400) "Redirect responses are forbidden"
  Assert-Equal ([int]$response.StatusCode) 200 "Sanctioned Preview Worker response status"
  try { return ([string]$response.Content | ConvertFrom-Json -ErrorAction Stop) }
  catch { throw "Sanctioned Preview Worker response was not valid JSON" }
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
Assert-Equal ([string]$config.vars.AI_GATEWAY_ID) "cloud-superbrain-llm-gateway" "Production AI Gateway ID"
Assert-Equal ([string]$config.env.preview.vars.AI_GATEWAY_ID) "cloud-superbrain-llm-gateway-preview" "Preview AI Gateway ID"
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
  '@cf/meta/llama-3.1-8b-instruct-fast',
  'MAX_BODY_BYTES',
  'MAX_INPUT_CHARS',
  'MAX_OUTPUT_TOKENS',
  'text/event-stream; charset=utf-8',
  'id: env.AI_GATEWAY_ID',
  'skipCache: true',
  'collectLog: true',
  'cf-aig-collect-log-payload',
  'metadata: gatewayMetadata',
  'env.AI.aiGatewayLogId',
  'env.AI.gateway',
  '.getLog(',
  'providerStream instanceof ReadableStream',
  'chat.completion.chunk',
  'provider_stream_not_openai_chunk',
  '/api/v1/evidence',
  'llm-gateway-independent-evidence-v1',
  'gateway_log_readback_verified',
  'source_binding_configured',
  'requestTimeoutMs: timeoutMs',
  'retries: { maxAttempts: 1 }',
  'live_provider_calls: true',
  'direct_provider_calls: false',
  'secret_output: false'
)) {
  Assert-Contains "Worker source" $source $marker
}
Assert-True (-not $source.Contains("CLOUDFLARE_API_TOKEN")) "Worker runtime must use the AI binding, not a provider API token"
Assert-True (-not $source.Contains("api.cloudflare.com/client/v4")) "Worker runtime must not bypass the Workers AI binding"
Assert-True (-not $source.Contains("function sseResponse(")) "Worker runtime cannot synthesize buffered provider SSE"
Assert-True (-not $source.Contains("terminal: true")) "Worker runtime cannot emit a fake full-completion terminal frame"

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
  'const WORKBENCH_LLM_MODEL = process.env.WORKBENCH_LLM_MODEL?.trim()',
  '|| "@cf/qwen/qwen2.5-coder-32b-instruct"',
  'const models: Array<[string, number]> = [[WORKBENCH_LLM_MODEL, 100000]]',
  'process.env.PRODUCT_ACCEPTANCE_LIVE_PROVIDER_APPROVED',
  'live_provider_calls_allowed: LIVE_PROVIDER_APPROVED'
)) {
  Assert-Contains "Frontend build route" $buildSource $marker
}
Assert-True (-not $buildSource.Contains("env.AI.run")) "Frontend build route cannot call Workers AI directly"
Assert-True (-not $buildSource.Contains("CLOUDFLARE_API_TOKEN")) "Frontend build route cannot contain a provider token"
Assert-Contains "Workbench live-call truth" $workbenchSource '"live_provider_calls=true" : "live_provider_calls=false"'

foreach ($marker in @(
  'health advertises configuration only',
  'non-stream completion uses the actual gateway path',
  'stream mode forwards only real provider chat.completion.chunk frames',
  'gateway-log model, provider, success, or metadata mismatch blocks completion',
  'per-attempt deadline aborts best-effort',
  'trace proof derives correlation from AI Gateway log metadata and D1 readback',
  'independent evidence readback is authenticated'
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
  Assert-True ($BaseUrl -ceq $sanctionedPreviewBaseUrl) "BaseUrl must exactly equal the sanctioned Preview Worker origin"
  $normalized = $sanctionedPreviewBaseUrl
  $health = Invoke-NoRedirectJson "$normalized/api/v1/health"
  Assert-Equal ([string]$health.contract_version) "cloudflare-workers-ai-llm-gateway-v1" "Hosted health contract"
  Assert-Equal ([string]$health.status) "healthy" "Hosted health status"
  Assert-Equal ([string]$health.service) "llm-gateway" "Hosted service marker"
  Assert-True ([bool]$health.live_provider_calls_available) "Hosted Workers AI path must be available"
  Assert-True (-not [bool]$health.live_provider_calls) "Health probe cannot execute inference"
  $models = Invoke-NoRedirectJson "$normalized/v1/models"
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

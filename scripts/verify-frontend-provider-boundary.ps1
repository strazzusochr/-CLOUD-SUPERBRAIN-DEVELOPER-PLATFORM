$ErrorActionPreference = "Stop"

function Assert-Contains([string]$Label, [string]$Text, [string]$Needle) {
  if (-not $Text.Contains($Needle)) {
    throw "Frontend provider boundary verification failed: $Label missing '$Needle'."
  }
}

function Assert-NotContains([string]$Label, [string]$Text, [string]$Needle) {
  if ($Text.Contains($Needle)) {
    throw "Frontend provider boundary verification failed: $Label contains forbidden '$Needle'."
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$frontendRoot = Join-Path $repoRoot "apps\frontend"
$sourceRoots = @(
  (Join-Path $frontendRoot "app"),
  (Join-Path $frontendRoot "components"),
  (Join-Path $frontendRoot "lib")
)
$sourceFiles = @(Get-ChildItem -LiteralPath $sourceRoots -Recurse -File | Where-Object {
  $_.Extension -in @(".ts", ".tsx", ".mjs")
}) + @(Get-Item -LiteralPath (Join-Path $frontendRoot "next.config.mjs"))
$source = ($sourceFiles | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"

$retiredModules = @(
  "lib\neon.ts",
  "lib\cfBackend.ts",
  "lib\cfWorkersAi.ts",
  "lib\ghStore.ts",
  "lib\agentChain.ts"
)
foreach ($module in $retiredModules) {
  if (Test-Path -LiteralPath (Join-Path $frontendRoot $module)) {
    throw "Frontend provider boundary verification failed: retired direct-provider module still exists: $module"
  }
}

$forbiddenMarkers = @(
  "@neondatabase/serverless",
  "DATABASE_URL",
  "CF_WORKERS_AI_TOKEN",
  "CF_BACKEND_TOKEN",
  "CF_D1_DATABASE_ID",
  "CF_VECTORIZE_INDEX",
  "CLOUDFLARE_API_TOKEN",
  "GH_STORE_TOKEN",
  "GH_STORE_REPO",
  "GITHUB_TOKEN",
  "https://api.cloudflare.com",
  "https://api.github.com",
  "vector(768)"
)
foreach ($marker in $forbiddenMarkers) {
  Assert-NotContains "active frontend source" $source $marker
}

$package = Get-Content -LiteralPath (Join-Path $frontendRoot "package.json") -Raw
Assert-NotContains "frontend package" $package "@neondatabase/serverless"

$boundaryPath = Join-Path $frontendRoot "lib\frontendBoundary.ts"
if (-not (Test-Path -LiteralPath $boundaryPath)) {
  throw "Frontend provider boundary verification failed: missing lib/frontendBoundary.ts"
}
$boundary = Get-Content -LiteralPath $boundaryPath -Raw
foreach ($required in @(
  '"agent-api"',
  '"llm-gateway"',
  '"mcp-gateway"',
  "AGENT_API_BASE_URL",
  "AGENT_API_INTERNAL_URL",
  "LLM_GATEWAY_BASE_URL",
  "MCP_GATEWAY_BASE_URL",
  "proxyReadToBoundary",
  "configured_boundary_unavailable",
  "accepted: false",
  "persisted: false",
  "direct_provider_calls: false",
  "live_provider_calls: false",
  "live_mcp_writes: false",
  "production_deploy: false"
)) {
  Assert-Contains "frontend boundary helper" $boundary $required
}

$actionRoutes = @(
  "app\api\v1\prompt\route.ts",
  "app\api\v1\agent-run\route.ts",
  "app\api\v1\workspace\artifacts\route.ts",
  "app\api\v1\memory\search\route.ts",
  "app\api\v1\tools\read-only\execute\route.ts",
  "app\api\v1\build\route.ts",
  "app\api\steer-agent\route.ts"
)
foreach ($relative in $actionRoutes) {
  $path = Join-Path $frontendRoot $relative
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Frontend provider boundary verification failed: missing action route $relative"
  }
  $route = Get-Content -LiteralPath $path -Raw
  Assert-Contains "$relative gateway proxy" $route "proxyToBoundary"
  Assert-Contains "$relative fail closed" $route "boundaryUnavailable"
}

$readProjectionRoutes = @(
  "app\api\v1\[...slug]\route.ts",
  "app\api\v1\agent-activity\recent\route.ts",
  "app\api\v1\audit\mcp\route.ts",
  "app\api\v1\audit\recent\route.ts",
  "app\api\v1\builds\route.ts",
  "app\api\v1\escalations\recent\route.ts",
  "app\api\v1\health\route.ts",
  "app\api\v1\memory\consolidation\recent\route.ts",
  "app\api\v1\memory\embedding-consistency\contract\route.ts",
  "app\api\v1\memory\search\route.ts",
  "app\api\v1\rotation\events\route.ts",
  "app\api\v1\sessions\recent\route.ts",
  "app\api\v1\workspace\artifacts\route.ts"
)
foreach ($relative in $readProjectionRoutes) {
  $path = Join-Path $frontendRoot $relative
  $route = Get-Content -LiteralPath $path -Raw
  Assert-Contains "$relative successful read boundary" $route "proxyReadToBoundary"
}

$buildItemRelative = "app\api\v1\build\[id]\route.ts"
$buildItemPath = Join-Path $frontendRoot $buildItemRelative
if (-not (Test-Path -LiteralPath $buildItemPath)) {
  throw "Frontend provider boundary verification failed: missing build item route $buildItemRelative"
}
$buildItemRoute = Get-Content -LiteralPath $buildItemPath -Raw
$buildItemGetStart = $buildItemRoute.IndexOf("export async function GET", [StringComparison]::Ordinal)
$buildItemDeleteStart = $buildItemRoute.IndexOf("export async function DELETE", [StringComparison]::Ordinal)
if ($buildItemGetStart -lt 0 -or $buildItemDeleteStart -le $buildItemGetStart) {
  throw "Frontend provider boundary verification failed: build item route GET/DELETE sections are missing or out of order."
}
$buildItemGet = $buildItemRoute.Substring($buildItemGetStart, $buildItemDeleteStart - $buildItemGetStart)
$buildItemDelete = $buildItemRoute.Substring($buildItemDeleteStart)

foreach ($required in @(
  'proxyToBoundary(req, "agent-api", `/api/v1/build/${clean}`, 30_000)',
  'response ?? Response.json',
  'status: "degraded"',
  'accepted: false',
  'persisted: false',
  'live_backend: false',
  'direct_provider_calls: false',
  'live_provider_calls: false',
  'secret_output: false',
  '"cache-control": "no-store"',
  '"x-superbrain-source": "frontend-boundary-degraded"',
  '{ status: 503'
)) {
  Assert-Contains "build item GET boundary" $buildItemGet $required
}
foreach ($forbidden in @("proxyReadToBoundary", "serviceAuth")) {
  Assert-NotContains "build item GET boundary" $buildItemGet $forbidden
}
$buildItemGetIdRead = $buildItemGet.IndexOf("const clean = safeId((await ctx.params).id)", [StringComparison]::Ordinal)
$buildItemGetProxy = $buildItemGet.IndexOf('proxyToBoundary(req, "agent-api", `/api/v1/build/${clean}`, 30_000)', [StringComparison]::Ordinal)
if ($buildItemGetIdRead -lt 0 -or $buildItemGetProxy -le $buildItemGetIdRead) {
  throw "Frontend provider boundary verification failed: build item GET must sanitize the route id before constructing the exact Agent API upstream path."
}

foreach ($required in @(
  'const writeBlock = authorizeBoundaryWrite(req)',
  'if (writeBlock) return writeBlock',
  'contract_version: "stateful-build-delete-guard-v1"',
  'error: "build_delete_owner_identity_required"',
  'accepted: false',
  'persisted: false',
  'deleted: false',
  'resource_unchanged: true',
  'owner_identity_verified: false',
  'service_auth_forwarded: false',
  'direct_provider_calls: false',
  'secret_output: false',
  '{ status: 403'
)) {
  Assert-Contains "build item DELETE owner guard" $buildItemDelete $required
}
foreach ($forbidden in @("proxyToBoundary", "proxyReadToBoundary", "serviceAuth", "fetch(")) {
  Assert-NotContains "build item DELETE owner guard" $buildItemDelete $forbidden
}
$buildItemDeleteBodyMarker = "): Promise<Response> {"
$buildItemDeleteGuardStatement = "const writeBlock = authorizeBoundaryWrite(req);"
$buildItemDeleteGuardReturnStatement = "if (writeBlock) return writeBlock;"
$buildItemDeleteBodyStart = $buildItemDelete.IndexOf($buildItemDeleteBodyMarker, [StringComparison]::Ordinal)
$buildItemDeleteGuard = $buildItemDelete.IndexOf($buildItemDeleteGuardStatement, [StringComparison]::Ordinal)
$buildItemDeleteGuardReturn = $buildItemDelete.IndexOf($buildItemDeleteGuardReturnStatement, [StringComparison]::Ordinal)
$buildItemDeleteIdRead = $buildItemDelete.IndexOf("const clean = safeId((await ctx.params).id)", [StringComparison]::Ordinal)
$buildItemDeletePreamble = if ($buildItemDeleteBodyStart -ge 0 -and $buildItemDeleteGuard -gt $buildItemDeleteBodyStart) {
  $start = $buildItemDeleteBodyStart + $buildItemDeleteBodyMarker.Length
  $buildItemDelete.Substring($start, $buildItemDeleteGuard - $start)
} else { "invalid" }
$buildItemDeleteBetweenGuardStatements = if ($buildItemDeleteGuard -ge 0 -and $buildItemDeleteGuardReturn -gt $buildItemDeleteGuard) {
  $start = $buildItemDeleteGuard + $buildItemDeleteGuardStatement.Length
  $buildItemDelete.Substring($start, $buildItemDeleteGuardReturn - $start)
} else { "invalid" }
if (
  $buildItemDeleteBodyStart -lt 0 -or
  -not [string]::IsNullOrWhiteSpace($buildItemDeletePreamble) -or
  -not [string]::IsNullOrWhiteSpace($buildItemDeleteBetweenGuardStatements) -or
  $buildItemDeleteIdRead -le ($buildItemDeleteGuardReturn + $buildItemDeleteGuardReturnStatement.Length)
) {
  throw "Frontend provider boundary verification failed: build item DELETE authorization must be the first operation and return before resource lookup or response projection."
}

$memoryContract = Get-Content -LiteralPath (Join-Path $frontendRoot "app\api\v1\memory\embedding-consistency\contract\route.ts") -Raw
foreach ($required in @(
  'status: "action_required"',
  "vector(1536)",
  "dimensions: 1536",
  'search_mode: "lexical_fallback"',
  "frontend_schema_creation_allowed: false",
  "No live embedding provider call is performed"
)) {
  Assert-Contains "frontend memory contract" $memoryContract $required
}

$buildRoute = Get-Content -LiteralPath (Join-Path $frontendRoot "app\api\v1\build\route.ts") -Raw
foreach ($required in @(
  "llm_gateway_generation_unavailable",
  "llm_gateway_did_not_return_complete_html",
  "accepted: false",
  "persisted: false",
  "direct_provider_calls: false",
  "live_provider_calls: false",
  "secret_output: false"
)) {
  Assert-Contains "frontend build fail-closed envelope" $buildRoute $required
}

$defaults = Get-Content -LiteralPath (Join-Path $frontendRoot "lib\endpointDefaults.ts") -Raw
foreach ($forbidden in @(
  "audit_persisted: true",
  'status: "completed"',
  "accepted: true",
  "Deterministic frontend projection response",
  "Deterministic frontend projection steering response"
)) {
  Assert-NotContains "frontend stateless projection" $defaults $forbidden
}
foreach ($required in @(
  "frontend-provider-boundary-v1",
  "configured_boundary_unavailable",
  "accepted: false",
  "audit_persisted: false"
)) {
  Assert-Contains "frontend stateless projection" $defaults $required
}

foreach ($staleClaim in @(
  "GitHub-Store · echt",
  "echt · Workers AI",
  "echte Vektorsuche mit kostenlosen Embeddings",
  "echtes Code-Modell · deine App läuft gleich live"
)) {
  Assert-NotContains "active frontend provider claim" $source $staleClaim
}

foreach ($relative in @("api\index.py", "api\llm.py", "api\mcp.py")) {
  $wrapper = Get-Content -LiteralPath (Join-Path $repoRoot $relative) -Raw
  foreach ($required in @(
    "stateless-contract-origin-v1",
    "stateless_contract_origin_read_only",
    '"accepted": False',
    '"persisted": False',
    '"audit_persisted": False',
    '"direct_provider_calls": False',
    '"production_deploy": False',
    '"secret_output": False'
  )) {
    Assert-Contains "$relative read-only wrapper" $wrapper $required
  }
}
Assert-Contains "agent API wrapper blocks mutating callback GET" `
  (Get-Content -LiteralPath (Join-Path $repoRoot "api\index.py") -Raw) `
  '"/api/v1/auth/callback"'

$compose = Get-Content -LiteralPath (Join-Path $repoRoot "docker-compose.dev.yml") -Raw
Assert-Contains "frontend local Agent API boundary" $compose "AGENT_API_INTERNAL_URL: http://agent-api:8000"
Assert-Contains "frontend local LLM Gateway boundary" $compose "LLM_GATEWAY_BASE_URL: http://llm-gateway:4000"
Assert-Contains "frontend local MCP Gateway boundary" $compose "MCP_GATEWAY_BASE_URL: http://mcp-gateway:9000"

$nginx = Get-Content -LiteralPath (Join-Path $repoRoot "infrastructure\nginx\dev.conf") -Raw
Assert-Contains "frontend build POST route" $nginx "location = /api/v1/build {"
Assert-Contains "frontend build artifact route" $nginx "location ^~ /api/v1/build/ {"
Assert-Contains "frontend build registry projection route" $nginx "location = /api/v1/builds {"

$progressManifestPath = Join-Path $repoRoot "docs\project-progress.manifest.json"
if (-not (Test-Path -LiteralPath $progressManifestPath)) {
  throw "Frontend provider boundary verification failed: missing canonical project progress manifest."
}
$progressManifest = Get-Content -LiteralPath $progressManifestPath -Raw | ConvertFrom-Json
$currentOverallPercent = [int]$progressManifest.overall_percent
if ($currentOverallPercent -lt 0 -or $currentOverallPercent -gt 100) {
  throw "Frontend provider boundary verification failed: canonical overall progress is outside 0..100."
}

$reportPath = Join-Path $repoRoot ".codex\runs\CURRENT\master-goal\t4\frontend-provider-boundary\report.json"
$report = [ordered]@{
  contract_version = "frontend-provider-boundary-proof-v1"
  status = "verified"
  generated_at = [DateTimeOffset]::UtcNow.ToString("o")
  source_file_count = @($sourceFiles).Count
  retired_module_count = @($retiredModules).Count
  forbidden_marker_count = @($forbiddenMarkers).Count
  guarded_action_route_count = @($actionRoutes).Count
  guarded_read_projection_route_count = @($readProjectionRoutes).Count
  dedicated_build_item_route_count = 1
  hosted_wrapper_count = 3
  direct_provider_paths_absent = $true
  mutations_fail_closed = $true
  hosted_wrappers_read_only = $true
  canonical_memory_contract_preserved = $true
  local_boundary_wiring_verified = $true
  direct_provider_calls = $false
  live_provider_calls = $false
  live_mcp_writes = $false
  production_deploy = $false
  secret_output = $false
  overall_percent_before = $currentOverallPercent
  overall_percent_after = $currentOverallPercent
  progress_source = "docs/project-progress.manifest.json"
  proof_scope = "static_source_and_local_boundary_contract"
  non_claims = @(
    "This static proof does not establish hosted deployment parity.",
    "This proof does not activate a live LLM provider or MCP write path.",
    "This proof does not establish a stateful hosted backend or production release."
  )
}
$reportDirectory = Split-Path $reportPath -Parent
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reportPath -Encoding utf8

Write-Host "[frontend-provider-boundary] direct provider paths absent"
Write-Host "[frontend-provider-boundary] mutations fail closed"
Write-Host "[frontend-provider-boundary] hosted wrappers fail closed"
Write-Host "[frontend-provider-boundary] canonical memory contract preserved"
Write-Host "[frontend-provider-boundary] report=$($reportPath.Substring($repoRoot.Length + 1))"
Write-Host "[frontend-provider-boundary] checks completed"

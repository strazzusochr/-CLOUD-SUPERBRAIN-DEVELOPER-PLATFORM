param(
  [string]$BaseUrl = "",
  [switch]$StaticOnly,
  [switch]$AllowLocalhost,
  [switch]$AllowHostedWrites,
  [string]$SeedReportPath = "",
  [string]$EvidencePath = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot
Add-Type -AssemblyName System.Web.Extensions
$jsonSerializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$jsonSerializer.MaxJsonLength = 1024 * 1024

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Assert-Equal($Actual, $Expected, [string]$Label) {
  if ($Actual -ne $Expected) { throw "$Label expected=$Expected actual=$Actual" }
}

function Assert-Contains([string]$Label, [string]$Content, [string]$Needle) {
  if (-not $Content.Contains($Needle)) { throw "$Label missing marker: $Needle" }
}

function Get-SourceSection([string]$Content, [string]$StartMarker, [string]$EndMarker, [string]$Label) {
  $start = $Content.IndexOf($StartMarker, [StringComparison]::Ordinal)
  Assert-True ($start -ge 0) "$Label missing start marker: $StartMarker"
  $end = $Content.IndexOf($EndMarker, $start + $StartMarker.Length, [StringComparison]::Ordinal)
  Assert-True ($end -gt $start) "$Label missing end marker: $EndMarker"
  return $Content.Substring($start, $end - $start)
}

function Assert-JsonBoolean($Object, [string]$PropertyName, [bool]$Expected, [string]$Label) {
  Assert-True ($null -ne $Object) "$Label payload is missing"
  $property = $Object.PSObject.Properties[$PropertyName]
  Assert-True ($null -ne $property) "$Label missing boolean property: $PropertyName"
  Assert-True ($property.Value -is [bool]) "$Label property $PropertyName must be boolean"
  Assert-Equal ([bool]$property.Value) $Expected "$Label property $PropertyName"
}

function Resolve-RepoScopedPath([string]$Candidate, [string]$Label, [bool]$MustExist = $false) {
  Assert-True (-not [string]::IsNullOrWhiteSpace($Candidate)) "$Label path is empty"
  $resolved = if ([IO.Path]::IsPathRooted($Candidate)) {
    [IO.Path]::GetFullPath($Candidate)
  } else {
    [IO.Path]::GetFullPath((Join-Path $repoRoot $Candidate))
  }
  $root = [IO.Path]::GetFullPath($repoRoot).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  Assert-True $resolved.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) "$Label path must stay inside the repository"
  if ($MustExist) { Assert-True (Test-Path -LiteralPath $resolved) "$Label not found: $Candidate" }
  return $resolved
}

function Get-Sha256([string]$Text) {
  $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
  $hash = [Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
  return ([BitConverter]::ToString($hash)).Replace("-", "").ToLowerInvariant()
}

function ConvertTo-ClrJsonValue([object]$Value) {
  if ($null -eq $Value -or $Value -is [string] -or $Value -is [ValueType]) { return $Value }
  if ($Value -is [Collections.IDictionary]) {
    $dictionary = New-Object "Collections.Generic.Dictionary[string,object]"
    foreach ($key in $Value.Keys) {
      $dictionary.Add([string]$key, [object](ConvertTo-ClrJsonValue $Value[$key]))
    }
    return (, $dictionary)
  }
  if ($Value -is [Collections.IEnumerable]) {
    $list = New-Object "Collections.Generic.List[object]"
    foreach ($item in $Value) { $list.Add([object](ConvertTo-ClrJsonValue $item)) }
    return (, $list)
  }
  return [string]$Value
}

function Invoke-JsonRequest(
  [string]$Method,
  [string]$Uri,
  [hashtable]$Headers = @{},
  [object]$Body = $null
) {
  $targetUri = [Uri]$Uri
  $safePath = $targetUri.AbsolutePath
  $request = [Net.HttpWebRequest][Net.WebRequest]::Create($targetUri)
  $request.Method = $Method
  $request.Timeout = 30000
  $request.ReadWriteTimeout = 30000
  $request.AllowAutoRedirect = $false
  $request.KeepAlive = $false
  $request.ServicePoint.Expect100Continue = $false
  if ($targetUri.IsLoopback) { $request.Proxy = $null }
  foreach ($name in $Headers.Keys) {
    if ([string]$name -ieq "Accept") {
      $request.Accept = [string]$Headers[$name]
    } else {
      $request.Headers[[string]$name] = [string]$Headers[$name]
    }
  }
  if ($null -ne $Body) {
    # Windows PowerShell 5.1 can spend minutes serializing a large string in a
    # PowerShell dictionary. A CLR-only object graph avoids that serializer bug.
    $jsonBody = $jsonSerializer.Serialize((ConvertTo-ClrJsonValue $Body))
    $bodyBytes = [Text.Encoding]::UTF8.GetBytes($jsonBody)
    $request.ContentType = "application/json; charset=utf-8"
    $request.ContentLength = $bodyBytes.Length
    $requestStream = $request.GetRequestStream()
    try { $requestStream.Write($bodyBytes, 0, $bodyBytes.Length) } finally { $requestStream.Dispose() }
  }
  $response = $null
  try {
    try {
      $response = [Net.HttpWebResponse]$request.GetResponse()
    } catch [Net.WebException] {
      if ($null -eq $_.Exception.Response) { throw }
      $response = [Net.HttpWebResponse]$_.Exception.Response
    }
    $reader = [IO.StreamReader]::new($response.GetResponseStream(), [Text.Encoding]::UTF8)
    try { $content = $reader.ReadToEnd() } finally { $reader.Dispose() }
    $status = [int]$response.StatusCode
    Write-Host "[cloudflare-stateful-runtime] method=$Method path=$safePath status=$status"
    return [pscustomobject]@{
      status = $status
      headers = $response.Headers
      payload = if ($content) { $content | ConvertFrom-Json } else { $null }
    }
  } finally {
    if ($null -ne $response) { $response.Dispose() }
    $request.Abort()
  }
}

$workerRoot = Join-Path $repoRoot "services\cloudflare-stateful-runtime"
$requiredFiles = @(
  "package.json",
  "package-lock.json",
  "wrangler.jsonc",
  "migrations\0001_foundation.sql",
  "migrations\0002_build_prompt_redaction.sql",
  "src\index.js",
  "test\index.test.js"
)
foreach ($relative in $requiredFiles) {
  Assert-True (Test-Path -LiteralPath (Join-Path $workerRoot $relative)) "Cloudflare stateful runtime missing $relative"
}

$package = Get-Content -LiteralPath (Join-Path $workerRoot "package.json") -Raw | ConvertFrom-Json
$config = Get-Content -LiteralPath (Join-Path $workerRoot "wrangler.jsonc") -Raw | ConvertFrom-Json
$source = Get-Content -LiteralPath (Join-Path $workerRoot "src\index.js") -Raw
$migration = Get-Content -LiteralPath (Join-Path $workerRoot "migrations\0001_foundation.sql") -Raw
$promptMigration = Get-Content -LiteralPath (Join-Path $workerRoot "migrations\0002_build_prompt_redaction.sql") -Raw
$testSource = Get-Content -LiteralPath (Join-Path $workerRoot "test\index.test.js") -Raw
$boundarySource = Get-Content -LiteralPath "apps\frontend\lib\frontendBoundary.ts" -Raw
$buildSource = Get-Content -LiteralPath "apps\frontend\app\api\v1\build\route.ts" -Raw
$buildReadSource = Get-Content -LiteralPath "apps\frontend\app\api\v1\build\[id]\route.ts" -Raw
$artifactRouteSource = Get-Content -LiteralPath "apps\frontend\app\api\v1\workspace\artifacts\route.ts" -Raw
$gallerySource = Get-Content -LiteralPath "apps\frontend\components\builds-gallery.tsx" -Raw
$runSource = Get-Content -LiteralPath "apps\frontend\components\run-build.tsx" -Raw
$browserProofSource = Get-Content -LiteralPath "scripts\verify-stateful-build-browser.cjs" -Raw

Assert-Equal ([string]$package.devDependencies.wrangler) "4.112.0" "pinned Wrangler version"
Assert-Equal ([string]$package.dependencies.'@langchain/langgraph') "1.4.8" "pinned LangGraph version"
Assert-Equal ([string]$package.dependencies.'@langchain/core') "1.1.48" "pinned LangChain Core version"
Assert-Equal ([string]$package.dependencies.zod) "4.2.0" "pinned Zod version"
Assert-Equal ([string]$config.name) "cloud-superbrain-stateful-runtime" "Production Worker name"
Assert-Equal ([string]$config.env.preview.name) "cloud-superbrain-stateful-runtime-preview" "Preview Worker name"
Assert-Equal ([string]$config.main) "src/index.js" "Worker entrypoint"
Assert-True ([bool]$config.workers_dev) "Worker must expose a free workers.dev HTTPS origin"
Assert-Equal @($config.d1_databases).Count 1 "Production D1 binding count"
Assert-Equal ([string]$config.d1_databases[0].binding) "DB" "Production D1 binding"
Assert-Equal ([string]$config.d1_databases[0].database_name) "cloud-superbrain-state-prod" "Production D1 database name"
Assert-Equal @($config.env.preview.d1_databases).Count 1 "Preview D1 binding count"
Assert-Equal ([string]$config.env.preview.d1_databases[0].binding) "DB" "Preview D1 binding"
Assert-Equal ([string]$config.env.preview.d1_databases[0].database_name) "cloud-superbrain-state-preview" "Preview D1 database name"

foreach ($marker in @(
  'cloudflare-d1-stateful-runtime-v1',
  'x-superbrain-agent-token',
  'AGENT_API_AUTH_TOKEN',
  'env.DB.prepare',
  '/api/v1/builds',
  'const buildMatch = url.pathname.match',
  '/api/v1/workspace/artifacts',
  'cloudflare-d1',
  'MAX_BODY_BYTES',
  'MAX_HTML_BYTES',
  'SOURCE_COMMIT_SHA',
  'SOURCE_ARCHIVE_SHA256',
  'StateGraph(RuntimeState)',
  'cloudflare-d1-langgraph-runtime-v1',
  '/api/v1/phase2/runtime/start',
  'env.DB.batch(statements)',
  'prompt_sha256',
  'live_provider_calls: false',
  'direct_provider_calls: false',
  'secret_output: false'
)) {
  Assert-Contains "Worker source" $source $marker
}
Assert-True (-not $source.Contains("CLOUDFLARE_API_TOKEN")) "Worker cannot contain a Cloudflare management token"
Assert-True (-not $source.Contains("DATABASE_URL")) "D1 Worker must use its binding, not an exposed database URL"

$buildCreateSection = Get-SourceSection $source "async function createBuild" "async function listBuilds" "Worker build create"
foreach ($marker in @(
  "containsSecretMaterial",
  "secret_material_rejected",
  "REDACTED_PROMPT",
  "promptSha256",
  "env.DB.batch([",
  "INSERT INTO audit_events",
  "cloudflare_d1_build_created",
  "audit_persisted: true",
  "build_persistence_failed"
)) {
  Assert-Contains "Worker build create" $buildCreateSection $marker
}
$buildListSection = Get-SourceSection $source "async function listBuilds" "async function getBuild" "Worker build list"
Assert-Contains "Worker build list" $buildListSection "prompt_sha256"
Assert-True (-not $buildListSection.Contains(" title, prompt,")) "Public build list cannot select raw prompts"
$buildReadSection = Get-SourceSection $source "async function getBuild" "async function deleteBuild" "Worker build read"
Assert-Contains "Worker build read" $buildReadSection "build_secret_material_quarantined"
$buildProjectionSection = Get-SourceSection $source "function buildFromRow" "function artifactFromRow" "Worker build projection"
Assert-Contains "Worker build projection" $buildProjectionSection "prompt_sha256"
Assert-Contains "Worker build projection" $buildProjectionSection "redactText(row.title)"
Assert-True (-not $buildProjectionSection.Contains("prompt: String(row.prompt)")) "Public build projection cannot expose raw prompts"
$artifactCreateSection = Get-SourceSection $source "async function createArtifact" "async function listArtifacts" "Worker artifact create"
foreach ($marker in @(
  "containsSecretMaterial",
  "env.DB.batch([",
  "INSERT INTO audit_events",
  "cloudflare_d1_workspace_artifact_created",
  "audit_persisted: true",
  "artifact_persistence_failed"
)) {
  Assert-Contains "Worker artifact create" $artifactCreateSection $marker
}

foreach ($table in @("builds", "workspace_artifacts", "runtime_runs", "agent_tasks", "memory_entries", "audit_events")) {
  Assert-True ($migration -match "CREATE TABLE IF NOT EXISTS $table") "D1 migration missing table $table"
}
Assert-Contains "D1 migration" $migration "PRAGMA foreign_keys = ON"
Assert-Contains "D1 prompt migration" $promptMigration "ALTER TABLE builds ADD COLUMN prompt_sha256 TEXT"
Assert-Contains "D1 prompt migration" $promptMigration "SET prompt = '[REDACTED]'"

foreach ($marker in @(
  'authEnvName: "AGENT_API_AUTH_TOKEN"',
  'authHeaderName: "x-superbrain-agent-token"',
  'headers.set(config.authHeaderName, gatewayToken)',
  'export function authorizeBoundaryWrite',
  'frontend-boundary-write-guard-v1',
  'verifySignedAuthSession',
  'service_auth_forwarded: false',
  'const attachConfiguredAuth = kind !== "agent-api" || options.serviceAuth === true',
  'if (kind === "agent-api" && options.serviceAuth === true)',
  'headers.delete("authorization")',
  'headers.delete("cookie")',
  'headers.delete("x-csrf-token")'
)) {
  Assert-Contains "Frontend boundary" $boundarySource $marker
}
Assert-True (-not $boundarySource.Contains("CLOUDFLARE_API_TOKEN")) "Frontend boundary cannot contain a Cloudflare management token"
Assert-True (-not $boundarySource.Contains("NEXT_PUBLIC_AGENT_API_AUTH_TOKEN")) "Agent API write token cannot be exposed to browser bundles"
$copiedHeaderSection = Get-SourceSection $boundarySource "function copyRequestHeaders" "function copyResponseHeaders" "Frontend copied headers"
Assert-True (-not $copiedHeaderSection.Contains("x-superbrain-agent-token")) "Browser-supplied Agent API write tokens cannot be forwarded"

foreach ($marker in @(
  'persistBuild(req, buildRecord)',
  '"/api/v1/builds",',
  '{ serviceAuth: true }',
  'const writeBlock = authorizeBoundaryWrite(req)',
  'if (writeBlock) return writeBlock',
  'payload.audit_persisted === true',
  'build_persistence_unavailable',
  'persisted ? `/run/${id}` : null',
  'direct_provider_calls: false',
  'secret_output: false'
)) {
  Assert-Contains "Frontend build route" $buildSource $marker
}
$buildPostStart = $buildSource.IndexOf("export async function POST", [StringComparison]::Ordinal)
$buildGuardIndex = $buildSource.IndexOf("const writeBlock = authorizeBoundaryWrite(req)", $buildPostStart, [StringComparison]::Ordinal)
$buildGenerateIndex = $buildSource.IndexOf("const generated = await generate", $buildPostStart, [StringComparison]::Ordinal)
Assert-True ($buildPostStart -ge 0 -and $buildGuardIndex -gt $buildPostStart -and $buildGenerateIndex -gt $buildGuardIndex) "Frontend build write guard must run before generation or persistence"

foreach ($marker in @(
  'const writeBlock = authorizeBoundaryWrite(req)',
  'build_delete_owner_identity_required',
  'service_auth_forwarded: false'
)) {
  Assert-Contains "Frontend build delete route" $buildReadSource $marker
}
$frontendBuildGetSection = Get-SourceSection $buildReadSource "export async function GET" "export async function DELETE" "Frontend build read route"
Assert-True (-not $frontendBuildGetSection.Contains("serviceAuth")) "Public build reads cannot request Agent API service auth"
$frontendBuildDeleteSection = $buildReadSource.Substring($buildReadSource.IndexOf("export async function DELETE", [StringComparison]::Ordinal))
Assert-True (-not $frontendBuildDeleteSection.Contains("proxyToBoundary")) "Browser build delete must remain owner-blocked without proxying"
Assert-True (-not $frontendBuildDeleteSection.Contains("serviceAuth: true")) "Browser build delete cannot forward Agent API service auth"
foreach ($marker in @(
  'export async function GET',
  'proxyReadToBoundary(req, "agent-api", "/api/v1/workspace/artifacts")',
  'const writeBlock = authorizeBoundaryWrite(req)',
  '{ serviceAuth: true }'
)) {
  Assert-Contains "Frontend workspace artifact route" $artifactRouteSource $marker
}
$frontendArtifactGetSection = Get-SourceSection $artifactRouteSource "export async function GET" "export async function POST" "Frontend workspace artifact read route"
Assert-True (-not $frontendArtifactGetSection.Contains("serviceAuth")) "Public workspace artifact reads cannot request Agent API service auth"
$artifactPostStart = $artifactRouteSource.IndexOf("export async function POST", [StringComparison]::Ordinal)
$artifactGuardIndex = $artifactRouteSource.IndexOf("const writeBlock = authorizeBoundaryWrite(req)", $artifactPostStart, [StringComparison]::Ordinal)
$artifactProxyIndex = $artifactRouteSource.IndexOf('proxyToBoundary(req, "agent-api"', $artifactPostStart, [StringComparison]::Ordinal)
Assert-True ($artifactPostStart -ge 0 -and $artifactGuardIndex -gt $artifactPostStart -and $artifactProxyIndex -gt $artifactGuardIndex) "Frontend artifact write guard must run before service-auth proxying"
Assert-Contains "Apps gallery" $gallerySource 'fetch("/api/v1/builds?limit=24"'
Assert-Contains "Run view" $runSource 'fetch(`/api/v1/build/${encodeURIComponent(id)}`'
Assert-Contains "Run view" $runSource 'data-testid="persisted-build-frame"'
foreach ($marker in @(
  'stateful-build-browser-proof-v1',
  'persisted-build-frame',
  'run_to_done_interaction',
  'seed_live_provider_calls: true',
  'verifier_live_provider_calls: false',
  'unexpected_requests: 0',
  'frontend_unauthenticated_write_guards',
  '--allow-local-write-guard-probes',
  'horizontal_overflow'
)) {
  Assert-Contains "Stateful build browser verifier" $browserProofSource $marker
}

foreach ($marker in @(
  'writes require the dedicated server-side agent token',
  'survives the create-list-read-delete registry roundtrip',
  'build and audit persistence fail atomically without returning generated output',
  'known secret forms are rejected before build persistence and never echoed',
  'public build reads redact legacy titles and never expose raw prompts',
  'workspace artifacts use the same authenticated D1 boundary',
  'workspace artifact persistence rolls back when its audit write fails',
  'workspace artifacts reject nested secret metadata without echoing it',
  'LangGraph executes four roles and persists run, tasks, checkpoint, memory, and audit'
)) {
  Assert-Contains "Worker tests" $testSource $marker
}

& npm.cmd run check --prefix $workerRoot
Assert-True ($LASTEXITCODE -eq 0) "Cloudflare stateful runtime syntax check failed"
& npm.cmd test --prefix $workerRoot
Assert-True ($LASTEXITCODE -eq 0) "Cloudflare stateful runtime unit tests failed"

$evidence = [ordered]@{
  contract_version = "cloudflare-d1-stateful-runtime-static-proof-v1"
  status = "verified"
  checked_at = [DateTime]::UtcNow.ToString("o")
  worker_name = [string]$config.name
  preview_worker_name = [string]$config.env.preview.name
  wrangler_version = [string]$package.devDependencies.wrangler
  langgraph_version = [string]$package.dependencies.'@langchain/langgraph'
  schema_tables = @("builds", "workspace_artifacts", "runtime_runs", "agent_tasks", "memory_entries", "audit_events")
  unit_tests_verified = $true
  frontend_server_boundary_verified = $true
  live_provider_call_executed = $false
  management_token_output = $false
  secret_output = $false
}

if (-not $StaticOnly) {
  Assert-True (-not [string]::IsNullOrWhiteSpace($BaseUrl)) "BaseUrl is required unless -StaticOnly is used"
  Assert-True (-not [string]::IsNullOrWhiteSpace($env:AGENT_API_AUTH_TOKEN)) "AGENT_API_AUTH_TOKEN must be loaded process-only for the hosted write proof"
  Assert-True ($env:AGENT_API_AUTH_TOKEN.Length -ge 32) "AGENT_API_AUTH_TOKEN must be at least 32 characters"
  Assert-True (-not ($env:AGENT_API_AUTH_TOKEN -match '\s')) "AGENT_API_AUTH_TOKEN cannot contain whitespace"
  $uri = $null
  Assert-True ([Uri]::TryCreate($BaseUrl, [UriKind]::Absolute, [ref]$uri)) "BaseUrl must be an absolute URL"
  Assert-True ([string]::IsNullOrEmpty($uri.UserInfo)) "BaseUrl cannot contain credentials"
  Assert-True ([string]::IsNullOrEmpty($uri.Query)) "BaseUrl cannot contain a query"
  Assert-True ([string]::IsNullOrEmpty($uri.Fragment)) "BaseUrl cannot contain a fragment"
  Assert-Equal $uri.AbsolutePath "/" "BaseUrl path"
  $isLocalhost = @("localhost", "127.0.0.1", "::1").Contains($uri.Host)
  if ($isLocalhost) {
    Assert-True ([bool]$AllowLocalhost) "Localhost requires -AllowLocalhost and remains DEV-ONLY"
    Assert-Equal $uri.Scheme "http" "DEV-ONLY Worker URL scheme"
  } else {
    Assert-True ([bool]$AllowHostedWrites) "Hosted mutation proof requires explicit -AllowHostedWrites owner gate"
    Assert-Equal $uri.Scheme "https" "Hosted Worker URL scheme"
  }
  $normalized = $uri.GetLeftPart([UriPartial]::Authority)

  $health = Invoke-JsonRequest -Method GET -Uri "$normalized/api/v1/health"
  Assert-Equal $health.status 200 "Hosted D1 health HTTP"
  Assert-Equal ([string]$health.payload.contract_version) "cloudflare-d1-stateful-runtime-v1" "Hosted D1 health contract"
  Assert-Equal ([string]$health.payload.status) "healthy" "Hosted D1 health status"
  Assert-JsonBoolean $health.payload "d1_read_verified" $true "Hosted D1 health"
  Assert-JsonBoolean $health.payload "auth_required_for_writes" $true "Hosted D1 health"
  Assert-JsonBoolean $health.payload "live_provider_calls" $false "Hosted D1 health"
  Assert-JsonBoolean $health.payload "direct_provider_calls" $false "Hosted D1 health"
  Assert-JsonBoolean $health.payload "secret_output" $false "Hosted D1 health"

  $probeId = "state-probe-" + [Guid]::NewGuid().ToString("N").Substring(0, 16)
  $probeProjectId = "state-probe-" + [Guid]::NewGuid().ToString("N").Substring(0, 16)
  $secretProbe = ("gh" + "p_") + ("z" * 36)
  $probeHtml = "<!doctype html><html><body><h1>D1 state probe</h1></body></html>"
  $probeBuild = [ordered]@{
    id = $probeId
    project_id = $probeProjectId
    title = "D1 state probe"
    prompt = "Deterministic verifier fixture; no provider call"
    model = "verifier/static"
    html = $probeHtml
    gateway_mode = "verifier_no_inference"
    gateway_provider = "none"
    live_provider_calls = $false
  }

  $unauthorized = Invoke-JsonRequest -Method POST -Uri "$normalized/api/v1/builds" -Body $probeBuild
  Assert-Equal $unauthorized.status 401 "Unauthenticated hosted write"
  Assert-Equal ([string]$unauthorized.payload.error) "stateful_runtime_authentication_required" "Unauthenticated hosted write guard"

  $unauthorizedDelete = Invoke-JsonRequest -Method DELETE -Uri "$normalized/api/v1/build/$probeId"
  Assert-Equal $unauthorizedDelete.status 401 "Unauthenticated build delete"
  Assert-Equal ([string]$unauthorizedDelete.payload.error) "stateful_runtime_authentication_required" "Unauthenticated build delete guard"

  $artifactProjectId = "state-probe-" + [Guid]::NewGuid().ToString("N").Substring(0, 16)
  $artifactProbe = [ordered]@{
    project_id = $artifactProjectId
    source_page = "verifier"
    artifact_type = "document"
    title = "D1 state probe"
    summary = "Deterministic verifier fixture; no provider call"
    status = "created"
    metadata = @{ format = "md"; verifier = "cloudflare-d1" }
  }
  $unauthorizedArtifact = Invoke-JsonRequest -Method POST -Uri "$normalized/api/v1/workspace/artifacts" -Body $artifactProbe
  Assert-Equal $unauthorizedArtifact.status 401 "Unauthenticated workspace artifact write"
  Assert-Equal ([string]$unauthorizedArtifact.payload.error) "stateful_runtime_authentication_required" "Unauthenticated workspace artifact guard"

  $publicBuildList = Invoke-JsonRequest -Method GET -Uri "$normalized/api/v1/builds?project_id=$artifactProjectId&limit=1"
  Assert-Equal $publicBuildList.status 200 "Public build list read"
  Assert-JsonBoolean $publicBuildList.payload "persisted" $true "Public build list"
  Assert-JsonBoolean $publicBuildList.payload "live_provider_calls" $false "Public build list"
  Assert-JsonBoolean $publicBuildList.payload "direct_provider_calls" $false "Public build list"
  Assert-JsonBoolean $publicBuildList.payload "secret_output" $false "Public build list"
  $publicArtifactList = Invoke-JsonRequest -Method GET -Uri "$normalized/api/v1/workspace/artifacts?project_id=$artifactProjectId&limit=1"
  Assert-Equal $publicArtifactList.status 200 "Public workspace artifact list read"
  Assert-JsonBoolean $publicArtifactList.payload "persisted" $true "Public workspace artifact list"
  Assert-JsonBoolean $publicArtifactList.payload "live_provider_calls" $false "Public workspace artifact list"
  Assert-JsonBoolean $publicArtifactList.payload "direct_provider_calls" $false "Public workspace artifact list"
  Assert-JsonBoolean $publicArtifactList.payload "secret_output" $false "Public workspace artifact list"

  $runtimeContract = Invoke-JsonRequest -Method GET -Uri "$normalized/api/v1/phase2/runtime/contract"
  Assert-Equal $runtimeContract.status 200 "Public LangGraph contract read"
  Assert-Equal ([string]$runtimeContract.payload.contract_version) "cloudflare-d1-langgraph-runtime-v1" "Public LangGraph contract"
  Assert-Equal (@($runtimeContract.payload.graph_nodes) -join ",") "planner,coder,tester,devops" "Public LangGraph role contract"
  Assert-JsonBoolean $runtimeContract.payload "write_auth_required" $true "Public LangGraph contract"
  Assert-JsonBoolean $runtimeContract.payload "live_provider_calls" $false "Public LangGraph contract"
  Assert-JsonBoolean $runtimeContract.payload "direct_provider_calls" $false "Public LangGraph contract"
  Assert-JsonBoolean $runtimeContract.payload "secret_output" $false "Public LangGraph contract"

  $unauthorizedRuntime = Invoke-JsonRequest -Method POST -Uri "$normalized/api/v1/phase2/runtime/start" -Body ([ordered]@{
    project_id = $artifactProjectId
    prompt = "Deterministic unauthenticated guard probe; no provider call"
  })
  Assert-Equal $unauthorizedRuntime.status 401 "Unauthenticated LangGraph start"
  Assert-Equal ([string]$unauthorizedRuntime.payload.error) "stateful_runtime_authentication_required" "Unauthenticated LangGraph start guard"

  $authHeaders = @{ "x-superbrain-agent-token" = $env:AGENT_API_AUTH_TOKEN; Accept = "application/json" }
  $secretProbeId = "secret-probe-" + [Guid]::NewGuid().ToString("N").Substring(0, 16)
  $secretProbeBuild = [ordered]@{
    id = $secretProbeId
    project_id = $probeProjectId
    title = "D1 rejected probe $secretProbe"
    prompt = "Synthetic secret rejection probe $secretProbe"
    model = "verifier/static"
    html = $probeHtml
    gateway_mode = "verifier_no_inference"
    gateway_provider = "none"
    live_provider_calls = $false
  }
  $secretRejected = Invoke-JsonRequest -Method POST -Uri "$normalized/api/v1/builds" -Headers $authHeaders -Body $secretProbeBuild
  Assert-Equal $secretRejected.status 400 "Synthetic secret build rejection"
  Assert-Equal ([string]$secretRejected.payload.error) "secret_material_rejected" "Synthetic secret build rejection code"
  Assert-JsonBoolean $secretRejected.payload "accepted" $false "Synthetic secret build rejection"
  Assert-JsonBoolean $secretRejected.payload "persisted" $false "Synthetic secret build rejection"
  Assert-JsonBoolean $secretRejected.payload "secret_output" $false "Synthetic secret build rejection"
  Assert-True (-not (($secretRejected.payload | ConvertTo-Json -Depth 8 -Compress).Contains($secretProbe))) "Synthetic secret rejection echoed the marker"
  $secretRead = Invoke-JsonRequest -Method GET -Uri "$normalized/api/v1/build/$secretProbeId"
  Assert-Equal $secretRead.status 404 "Rejected secret build read"
  Assert-JsonBoolean $secretRead.payload "persisted" $false "Rejected secret build read"
  Assert-JsonBoolean $secretRead.payload "secret_output" $false "Rejected secret build read"

  $probeCreated = $false
  try {
    $created = Invoke-JsonRequest -Method POST -Uri "$normalized/api/v1/builds" -Headers $authHeaders -Body $probeBuild
    Assert-Equal $created.status 201 "Hosted probe create"
    $probeCreated = $true
    Assert-JsonBoolean $created.payload "persisted" $true "Hosted probe create"
    Assert-JsonBoolean $created.payload "live_provider_calls" $false "Hosted probe create"
    Assert-JsonBoolean $created.payload "direct_provider_calls" $false "Hosted probe create"
    Assert-JsonBoolean $created.payload "secret_output" $false "Hosted probe create"
    Assert-JsonBoolean $created.payload "audit_persisted" $true "Hosted probe create"
    Assert-True ($null -eq $created.payload.PSObject.Properties["prompt"]) "Hosted probe create cannot expose the raw prompt"
    Assert-True ([string]$created.payload.prompt_sha256 -match '^[a-f0-9]{64}$') "Hosted probe create prompt hash is invalid"
    Assert-True (-not (($created.payload | ConvertTo-Json -Depth 8 -Compress).Contains($secretProbe))) "Hosted probe create leaked a synthetic secret marker"
    $read = Invoke-JsonRequest -Method GET -Uri "$normalized/api/v1/build/$probeId"
    Assert-Equal $read.status 200 "Hosted probe read"
    Assert-Equal (Get-Sha256 ([string]$read.payload.html)) (Get-Sha256 $probeHtml) "Hosted probe HTML hash"
    Assert-True ($null -eq $read.payload.PSObject.Properties["prompt"]) "Hosted probe read cannot expose the raw prompt"
    Assert-Equal ([string]$read.payload.prompt_sha256) ([string]$created.payload.prompt_sha256) "Hosted probe prompt hash"
    Assert-True (-not (($read.payload | ConvertTo-Json -Depth 8 -Compress).Contains($secretProbe))) "Hosted probe read leaked a synthetic secret marker"
    $listed = Invoke-JsonRequest -Method GET -Uri "$normalized/api/v1/builds?project_id=$probeProjectId&limit=10"
    Assert-True (@($listed.payload.builds | Where-Object { $_.id -eq $probeId }).Count -eq 1) "Hosted probe must appear in build list"
    Assert-True (@($listed.payload.builds | Where-Object { $null -ne $_.PSObject.Properties["prompt"] }).Count -eq 0) "Hosted build list cannot expose raw prompts"
    Assert-True (-not (($listed.payload | ConvertTo-Json -Depth 8 -Compress).Contains($secretProbe))) "Hosted probe list leaked a synthetic secret marker"
    $deleted = Invoke-JsonRequest -Method DELETE -Uri "$normalized/api/v1/build/$probeId" -Headers $authHeaders
    Assert-Equal $deleted.status 200 "Hosted probe delete"
    $probeCreated = $false
    $afterDelete = Invoke-JsonRequest -Method GET -Uri "$normalized/api/v1/build/$probeId"
    Assert-Equal $afterDelete.status 404 "Hosted probe must disappear after delete"
  } finally {
    if ($probeCreated) {
      $cleanup = Invoke-JsonRequest -Method DELETE -Uri "$normalized/api/v1/build/$probeId" -Headers $authHeaders
      Assert-True (@(200, 404).Contains([int]$cleanup.status)) "Hosted probe cleanup failed"
    }
  }

  $artifactCreated = Invoke-JsonRequest -Method POST -Uri "$normalized/api/v1/workspace/artifacts" -Headers $authHeaders -Body $artifactProbe
  Assert-Equal $artifactCreated.status 201 "Workspace artifact probe create"
  Assert-JsonBoolean $artifactCreated.payload.artifact "persisted" $true "Workspace artifact probe"
  Assert-Equal ([string]$artifactCreated.payload.artifact.project_id) $artifactProjectId "Workspace artifact project"
  Assert-Equal ([string]$artifactCreated.payload.artifact.metadata.format) "md" "Workspace artifact metadata"
  Assert-JsonBoolean $artifactCreated.payload "live_provider_calls" $false "Workspace artifact probe create"
  Assert-JsonBoolean $artifactCreated.payload "live_mcp_writes" $false "Workspace artifact probe create"
  Assert-JsonBoolean $artifactCreated.payload "secret_output" $false "Workspace artifact probe create"
  Assert-JsonBoolean $artifactCreated.payload "audit_persisted" $true "Workspace artifact probe create"
  $artifactId = [string]$artifactCreated.payload.artifact.id
  $artifactListed = Invoke-JsonRequest -Method GET -Uri "$normalized/api/v1/workspace/artifacts?project_id=$artifactProjectId&limit=10"
  Assert-Equal $artifactListed.status 200 "Workspace artifact probe list"
  Assert-True (@($artifactListed.payload.artifacts | Where-Object { $_.id -eq $artifactId }).Count -eq 1) "Workspace artifact probe must appear exactly once"

  $runtimeStart = Invoke-JsonRequest -Method POST -Uri "$normalized/api/v1/phase2/runtime/start" -Headers $authHeaders -Body ([ordered]@{
    project_id = "default"
    prompt = "Deterministic hosted LangGraph and D1 proof; no provider call"
  })
  Assert-Equal $runtimeStart.status 201 "Hosted LangGraph start"
  Assert-Equal ([string]$runtimeStart.payload.contract_version) "cloudflare-d1-langgraph-runtime-v1" "Hosted LangGraph contract"
  Assert-Equal ([string]$runtimeStart.payload.status) "completed" "Hosted LangGraph terminal status"
  Assert-Equal ([string]$runtimeStart.payload.engine) "langgraph-js" "Hosted LangGraph engine"
  Assert-Equal ([string]$runtimeStart.payload.checkpointing) "cloudflare-d1" "Hosted LangGraph checkpointing"
  Assert-Equal @($runtimeStart.payload.role_results).Count 4 "Hosted LangGraph role count"
  Assert-Equal (@($runtimeStart.payload.role_results | ForEach-Object { [string]$_.role }) -join ",") "planner,coder,tester,devops" "Hosted LangGraph role order"
  Assert-True (@($runtimeStart.payload.role_results | Where-Object { $_.status -ne "completed" }).Count -eq 0) "Hosted LangGraph roles must all complete"
  Assert-JsonBoolean $runtimeStart.payload "memory_persisted" $true "Hosted LangGraph start"
  Assert-JsonBoolean $runtimeStart.payload "live_provider_calls" $false "Hosted LangGraph start"
  Assert-JsonBoolean $runtimeStart.payload "direct_provider_calls" $false "Hosted LangGraph start"
  Assert-JsonBoolean $runtimeStart.payload "secret_output" $false "Hosted LangGraph start"
  $runtimeId = [string]$runtimeStart.payload.run_id
  $runtimeRead = Invoke-JsonRequest -Method GET -Uri "$normalized/api/v1/phase2/runtime/runs/$runtimeId"
  Assert-Equal $runtimeRead.status 200 "Hosted LangGraph state read"
  Assert-Equal @($runtimeRead.payload.tasks).Count 4 "Hosted persisted task count"
  Assert-Equal (@($runtimeRead.payload.tasks | ForEach-Object { [string]$_.agent_role }) -join ",") "planner,coder,tester,devops" "Hosted persisted task roles"
  Assert-Equal @($runtimeRead.payload.memory_records).Count 1 "Hosted persisted memory count"
  Assert-True (-not (($runtimeRead.payload | ConvertTo-Json -Depth 8) -match 'Deterministic hosted LangGraph')) "Hosted runtime read must not expose the raw prompt"

  $seedId = $null
  $seedHash = $null
  $seedHtmlRef = $null
  if (-not [string]::IsNullOrWhiteSpace($SeedReportPath)) {
    $resolvedSeed = Resolve-RepoScopedPath $SeedReportPath "Seed report" $true
    $seed = Get-Content -LiteralPath $resolvedSeed -Raw | ConvertFrom-Json
    Assert-Equal ([string]$seed.contract_version) "t2-hosted-workers-ai-build-browser-proof-v1" "Seed report contract"
    Assert-Equal ([string]$seed.status) "verified" "Seed report status"
    Assert-JsonBoolean $seed "live_provider_calls" $true "Seed report"
    Assert-Equal ([int]$seed.live_provider_call_count_upper_bound) 1 "Seed report provider-call upper bound"
    Assert-JsonBoolean $seed "direct_provider_calls" $false "Seed report"
    Assert-JsonBoolean $seed "secret_output" $false "Seed report"
    Assert-Equal ([string]$seed.gateway_mode) "cloudflare_workers_ai_live" "Seed report gateway mode"
    Assert-Equal ([string]$seed.gateway_provider) "cloudflare-workers-ai" "Seed report gateway provider"
    $generatedHtmlRef = [string]$seed.generated_html
    if ($generatedHtmlRef -match '^\s*<!doctype html') {
      $generatedHtml = $generatedHtmlRef
      $seedHtmlRef = "inline"
    } else {
      Assert-True (-not [IO.Path]::IsPathRooted($generatedHtmlRef)) "Seed HTML reference must be relative to the report directory"
      $seedDirectory = [IO.Path]::GetFullPath((Split-Path -Parent $resolvedSeed))
      $resolvedHtml = [IO.Path]::GetFullPath((Join-Path $seedDirectory $generatedHtmlRef))
      Assert-True $resolvedHtml.StartsWith($seedDirectory + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) "Seed HTML reference escapes the report directory"
      Assert-True (Test-Path -LiteralPath $resolvedHtml) "Seed HTML artifact not found: $generatedHtmlRef"
      $generatedHtml = Get-Content -LiteralPath $resolvedHtml -Raw
      $seedHtmlRef = $generatedHtmlRef
    }
    Assert-True ($generatedHtml -match '^\s*<!doctype html') "Seed report generated HTML is incomplete"
    $seedHash = Get-Sha256 $generatedHtml
    Assert-Equal $seedHash ([string]$seed.html_sha256) "Seed report HTML hash"
    $seedId = "t2-live-proof-" + $seedHash.Substring(0, 12) + "-" + [Guid]::NewGuid().ToString("N").Substring(0, 8)
    $seedBuild = [ordered]@{
      id = $seedId
      project_id = "default"
      title = "T2 LIVE PROOF"
      prompt = "T2 persisted output from the single approved hosted inference proof"
      model = [string]$seed.model
      html = $generatedHtml
      gateway_mode = [string]$seed.gateway_mode
      gateway_provider = [string]$seed.gateway_provider
      live_provider_calls = $true
    }
    $seedCreate = Invoke-JsonRequest -Method POST -Uri "$normalized/api/v1/builds" -Headers $authHeaders -Body $seedBuild
    Assert-Equal $seedCreate.status 201 "Seed build create"
    Assert-JsonBoolean $seedCreate.payload "persisted" $true "Seed build create"
    Assert-JsonBoolean $seedCreate.payload "audit_persisted" $true "Seed build create"
    Assert-JsonBoolean $seedCreate.payload "live_provider_calls" $true "Seed build create"
    Assert-JsonBoolean $seedCreate.payload "direct_provider_calls" $false "Seed build create"
    Assert-JsonBoolean $seedCreate.payload "secret_output" $false "Seed build create"
    $seedRead = Invoke-JsonRequest -Method GET -Uri "$normalized/api/v1/build/$seedId"
    Assert-Equal $seedRead.status 200 "Seed build read"
    Assert-JsonBoolean $seedRead.payload "persisted" $true "Seed build read"
    Assert-JsonBoolean $seedRead.payload "live_provider_calls" $true "Seed build read"
    Assert-JsonBoolean $seedRead.payload "direct_provider_calls" $false "Seed build read"
    Assert-JsonBoolean $seedRead.payload "secret_output" $false "Seed build read"
    Assert-Equal (Get-Sha256 ([string]$seedRead.payload.html)) $seedHash "Seed build hosted HTML hash"
    $seedList = Invoke-JsonRequest -Method GET -Uri "$normalized/api/v1/builds?project_id=default&limit=100"
    Assert-True (@($seedList.payload.builds | Where-Object { $_.id -eq $seedId }).Count -eq 1) "Seed build must appear in hosted gallery feed"
  }

  $evidence.contract_version = if ($isLocalhost) { "cloudflare-d1-stateful-runtime-local-proof-v1" } else { "cloudflare-d1-stateful-runtime-hosted-proof-v1" }
  $evidence.base_url = $normalized
  $evidence.dev_only = $isLocalhost
  $evidence.hosted_proof = -not $isLocalhost
  $evidence.health_status = [string]$health.payload.status
  $evidence.d1_read_verified = [bool]$health.payload.d1_read_verified
  $evidence.unauthenticated_write_status = $unauthorized.status
  $evidence.unauthenticated_delete_status = $unauthorizedDelete.status
  $evidence.unauthenticated_artifact_write_status = $unauthorizedArtifact.status
  $evidence.unauthenticated_runtime_write_status = $unauthorizedRuntime.status
  $evidence.public_reads_verified = $true
  $evidence.secret_material_rejection_verified = $true
  $evidence.raw_build_prompt_output = $false
  $evidence.create_read_list_delete_roundtrip = $true
  $evidence.workspace_artifact_roundtrip = $true
  $evidence.langgraph_engine = [string]$runtimeStart.payload.engine
  $evidence.langgraph_run_id = $runtimeId
  $evidence.langgraph_role_count = @($runtimeStart.payload.role_results).Count
  $evidence.d1_checkpoint_persisted = ([string]$runtimeStart.payload.checkpointing -eq "cloudflare-d1")
  $evidence.d1_memory_persisted = [bool]$runtimeStart.payload.memory_persisted
  $evidence.raw_prompt_output = $false
  $evidence.seed_build_id = $seedId
  $evidence.seed_html_sha256 = $seedHash
  $evidence.seed_html_ref = $seedHtmlRef
  $evidence.seed_persisted = -not [string]::IsNullOrWhiteSpace($seedId)
  $evidence.seed_audit_persisted = -not [string]::IsNullOrWhiteSpace($seedId)
}

if (-not [string]::IsNullOrWhiteSpace($EvidencePath)) {
  $resolvedEvidence = Resolve-RepoScopedPath $EvidencePath "Evidence" $false
  $parent = Split-Path -Parent $resolvedEvidence
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  $evidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resolvedEvidence -Encoding utf8
}

$transport = if (-not $StaticOnly -and $isLocalhost) { "DEV-ONLY" } elseif ($StaticOnly) { "static" } else { "hosted" }
Write-Host "[cloudflare-stateful-runtime] status=verified transport=$transport live_provider_calls=0 secret_output=false"

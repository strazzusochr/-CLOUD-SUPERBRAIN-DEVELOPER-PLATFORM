param(
  [string]$ConfigPath = "docs\runtime-state\backend-hosted-current.json",
  [switch]$StaticOnly
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Assert-Equal($Actual, $Expected, [string]$Label) {
  if ($Actual -ne $Expected) { throw "$Label expected '$Expected' but got '$Actual'" }
}

function Invoke-Http([string]$Method, [string]$Uri) {
  Add-Type -AssemblyName System.Net.Http
  $handler = New-Object System.Net.Http.HttpClientHandler
  $handler.AllowAutoRedirect = $false
  $client = New-Object System.Net.Http.HttpClient($handler)
  $client.Timeout = [TimeSpan]::FromSeconds(30)
  try {
    $request = New-Object System.Net.Http.HttpRequestMessage(
      [System.Net.Http.HttpMethod]::new($Method),
      $Uri
    )
    if ($Method -eq "POST") {
      $request.Content = New-Object System.Net.Http.StringContent(
        '{}',
        [Text.Encoding]::UTF8,
        'application/json'
      )
    }
    $response = $client.SendAsync($request).GetAwaiter().GetResult()
    $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    return [pscustomobject]@{
      StatusCode = [int]$response.StatusCode
      Content = $content
      Location = [string]$response.Headers.Location
    }
  } finally {
    $client.Dispose()
    $handler.Dispose()
  }
}

function Get-JsonResponse([string]$BaseUrl, [string]$Path) {
  $response = Invoke-Http "GET" "$BaseUrl$Path"
  Assert-Equal ([int]$response.StatusCode) 200 "GET $BaseUrl$Path"
  return [pscustomobject]@{
    Content = $response.Content
    Json = ($response.Content | ConvertFrom-Json)
  }
}

try {
  Assert-True (Test-Path -LiteralPath $ConfigPath) "Hosted backend proof config missing: $ConfigPath"
  $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
  Assert-Equal ([string]$config.contract_version) "backend-hosted-current-proof-v1" "config contract"
  Assert-Equal ([string]$config.status) "verified" "config status"
  Assert-True ([string]$config.source_commit_sha -match '^[0-9a-f]{40}$') "Invalid hosted backend source SHA"
  Assert-True ([string]$config.source_archive_sha256 -match '^[0-9a-f]{64}$') "Invalid hosted backend archive SHA-256"
  Assert-True ([string]$config.deployment_id -match '^dpl_[A-Za-z0-9]+$') "Invalid Vercel deployment id"
  Assert-True ([string]$config.immutable_deployment_url -match '^https://[^/]+\.vercel\.app$') "Invalid immutable deployment URL"
  Assert-True ([string]$config.production_alias -match '^https://[^/]+\.vercel\.app$') "Invalid production alias"
  Assert-True ([string]$config.immutable_deployment_url -notmatch 'localhost|127\.0\.0\.1') "Hosted proof cannot use localhost"
  Assert-Equal ([string]$config.vercel_target) "production" "Vercel target"
  Assert-Equal ([string]$config.vercel_scope) "strazzusochrs-projects" "Vercel scope"
  Assert-Equal ([int]$config.overall_percent) 84 "configured overall percent"
  Assert-Equal ([int]$config.phase_4_percent) 100 "configured Phase 4 percent"
  Assert-Equal ([string]$config.integrity_status) "verified" "configured integrity"
  Assert-Equal ([string]$config.external_gates_status) "verified" "configured external gates"
  Assert-Equal ([int]$config.external_gates_verified_count) 6 "configured verified gate count"
  Assert-Equal ([int]$config.external_gates_total_count) 6 "configured total gate count"
  Assert-True ([bool]$config.read_only_contract_origin) "Hosted backend proof must remain read-only"
  Assert-True ([bool]$config.immutable_deployment_protected) "Immutable deployment must remain protected"
  Assert-True ([bool]$config.deployment_metadata_verified) "Deployment metadata must be verified"
  Assert-True (-not [bool]$config.deployment_alias_content_parity) "Protected immutable content parity cannot be claimed"
  Assert-True (-not [bool]$config.stateful_backend_verified) "Hosted contract origin cannot claim the stateful backend"
  Assert-True (-not [bool]$config.production_release_claimed) "Hosted contract origin cannot claim a platform production release"

  git cat-file -e "$($config.source_commit_sha)^{commit}" 2>$null
  Assert-True ($LASTEXITCODE -eq 0) "Hosted backend source commit is unavailable locally"
  git merge-base --is-ancestor ([string]$config.source_commit_sha) HEAD
  Assert-True ($LASTEXITCODE -eq 0) "Hosted backend source commit is not an ancestor of HEAD"

  $manifest = Get-Content -LiteralPath "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
  $manifestPhase4 = $manifest.horizontal.items | Where-Object { $_.id -eq "phase_4" } | Select-Object -First 1
  Assert-Equal ([int]$manifest.overall_percent) ([int]$config.overall_percent) "manifest/config overall parity"
  Assert-Equal ([int]$manifestPhase4.percent) ([int]$config.phase_4_percent) "manifest/config Phase 4 parity"

  if ($StaticOnly) {
    Write-Host "[backend-hosted-current] static checks completed"
    exit 0
  }

  $previousErrorAction = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $deploymentRaw = & vercel.cmd api "/v13/deployments/$($config.deployment_id)" `
      --scope ([string]$config.vercel_scope) --raw 2>$null
    $deploymentLookupExit = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorAction
  }
  Assert-True ($deploymentLookupExit -eq 0) "Authenticated Vercel deployment metadata lookup failed"
  $deployment = ($deploymentRaw -join "`n") | ConvertFrom-Json
  Assert-Equal ([string]$deployment.readyState) "READY" "Vercel deployment state"
  Assert-Equal ([string]$deployment.target) "production" "Vercel deployment target"
  Assert-Equal ([string]$deployment.meta.sourceCommitSha) ([string]$config.source_commit_sha) "Vercel source SHA"
  Assert-Equal ([string]$deployment.meta.sourceArchiveSha256) ([string]$config.source_archive_sha256) "Vercel archive SHA-256"
  Assert-True (@($deployment.alias) -contains ([Uri]$config.production_alias).Host) "Production Alias is not assigned to the deployment"

  $immutableProbe = Invoke-Http "GET" "$($config.immutable_deployment_url)/api/v1/health"
  Assert-Equal ([int]$immutableProbe.StatusCode) 302 "protected immutable deployment response"
  Assert-True ([string]$immutableProbe.Location -match '^https://vercel\.com/') "Immutable deployment did not redirect to Vercel protection"

  $base = [string]$config.production_alias
  $root = Invoke-Http "GET" "$base/"
  Assert-Equal ([int]$root.StatusCode) 200 "GET $base/"
  $health = Get-JsonResponse $base "/api/v1/health"
  $progress = Get-JsonResponse $base "/api/v1/project/progress"
  $integrity = Get-JsonResponse $base "/api/v1/project/progress/integrity"
  $gates = Get-JsonResponse $base "/api/v1/external-gates"
  $mcp = Get-JsonResponse $base "/mcp/api/v1/health"
  $llm = Get-JsonResponse $base "/llm/api/v1/health"
  $phase4 = $progress.Json.horizontal.items | Where-Object { $_.id -eq "phase_4" } | Select-Object -First 1

  Assert-Equal ([string]$health.Json.service) "agent-api" "Agent API service marker"
  Assert-Equal ([string]$health.Json.status) "degraded" "stateless Agent API health"
  Assert-Equal ([string]$health.Json.services.postgres.reason) "not_configured" "stateless PostgreSQL boundary"
  Assert-Equal ([string]$health.Json.services.redis.reason) "not_configured" "stateless Redis boundary"
  Assert-Equal ([int]$progress.Json.overall_percent) ([int]$config.overall_percent) "hosted overall progress"
  Assert-Equal ([int]$phase4.percent) ([int]$config.phase_4_percent) "hosted Phase 4 progress"
  Assert-Equal ([string]$integrity.Json.status) "verified" "hosted progress integrity"
  Assert-Equal ([string]$gates.Json.status) "verified" "hosted external gates"
  Assert-Equal ([int]$gates.Json.verified_count) 6 "hosted verified gate count"
  Assert-Equal ([int]$gates.Json.total_count) 6 "hosted total gate count"
  Assert-Equal @($gates.Json.blocked_release_gates).Count 0 "hosted blocked release gate count"
  Assert-Equal ([string]$mcp.Json.status) "healthy" "hosted MCP health"
  Assert-Equal ([string]$llm.Json.status) "healthy" "hosted LLM health"

  $writeProbe = Invoke-Http "POST" "$base/api/v1/prompt"
  Assert-Equal ([int]$writeProbe.StatusCode) 503 "read-only POST boundary"
  $writePayload = $writeProbe.Content | ConvertFrom-Json
  Assert-Equal ([string]$writePayload.reason) "stateless_contract_origin_read_only" "read-only POST reason"
  Assert-True (-not [bool]$writePayload.live) "read-only POST cannot claim live execution"

  $verificationPath = Join-Path $repoRoot ([string]$config.verification_artifact)
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $verificationPath) | Out-Null
  [ordered]@{
    contract_version = "backend-hosted-current-verification-v1"
    status = "verified"
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    source_commit_sha = [string]$config.source_commit_sha
    source_archive_sha256 = [string]$config.source_archive_sha256
    deployment_id = [string]$config.deployment_id
    immutable_deployment_url = [string]$config.immutable_deployment_url
    production_alias = [string]$config.production_alias
    overall_percent = [int]$config.overall_percent
    phase_4_percent = [int]$config.phase_4_percent
    integrity_status = "verified"
    external_gates_status = "verified"
    external_gates_verified_count = 6
    external_gates_total_count = 6
    agent_health_status = "degraded"
    mcp_health_status = "healthy"
    llm_health_status = "healthy"
    read_only_post_boundary_http = 503
    immutable_deployment_protected = $true
    deployment_metadata_verified = $true
    deployment_alias_content_parity = $false
    stateful_backend_verified = $false
    production_release_claimed = $false
  } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $verificationPath -Encoding utf8

  Write-Host "[backend-hosted-current] status=verified overall=$($config.overall_percent) phase4=$($config.phase_4_percent) gates=6/6 read_only_post=503"
} finally {
  Pop-Location
}

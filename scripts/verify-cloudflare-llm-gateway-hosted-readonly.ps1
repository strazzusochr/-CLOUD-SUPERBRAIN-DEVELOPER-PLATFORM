param(
  [string]$BaseUrl = "https://cloud-superbrain-llm-gateway-preview.strazzusochr.workers.dev",
  [string]$OutDir = ".codex\runs\CURRENT\llm-gateway\cloudflare-hosted-readonly"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) { throw "Hosted Cloudflare LLM read-only verification failed: $Label" }
  Write-Host "[llm-hosted-readonly] $Label"
}

function Assert-Equal([string]$Label, $Actual, $Expected) {
  Assert-True $Label ($Actual -eq $Expected)
}

function Assert-FalseField([string]$Label, $Payload, [string]$Field) {
  $property = $Payload.PSObject.Properties[$Field]
  Assert-True "$Label $Field=false" ($null -ne $property -and $property.Value -is [bool] -and -not [bool]$property.Value)
}

function Assert-TrueField([string]$Label, $Payload, [string]$Field) {
  $property = $Payload.PSObject.Properties[$Field]
  Assert-True "$Label $Field=true" ($null -ne $property -and $property.Value -is [bool] -and [bool]$property.Value)
}

function Get-TextSha256([string]$Value) {
  $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
  $sha256 = [Security.Cryptography.SHA256]::Create()
  try {
    $hash = $sha256.ComputeHash($bytes)
    return (($hash | ForEach-Object { $_.ToString("x2") }) -join "")
  } finally {
    $sha256.Dispose()
  }
}

function Invoke-JsonGet([string]$Uri) {
  $response = Invoke-WebRequest -UseBasicParsing -Uri $Uri -Method Get -TimeoutSec 30
  Assert-Equal "GET $Uri HTTP status" ([int]$response.StatusCode) 200
  Assert-True "GET $Uri JSON content type" ([string]$response.Headers["Content-Type"] -match "^application/json")
  Assert-Equal "GET $Uri source header" ([string]$response.Headers["x-superbrain-source"]) "cloudflare-workers-ai-llm-gateway"
  Assert-True "GET $Uri no-store" ([string]$response.Headers["Cache-Control"] -match "(^|,)\s*no-store\s*(,|$)")
  Assert-Equal "GET $Uri nosniff" ([string]$response.Headers["x-content-type-options"]) "nosniff"
  return [ordered]@{
    payload = ($response.Content | ConvertFrom-Json)
    content_sha256 = Get-TextSha256 ([string]$response.Content)
  }
}

function Invoke-GitLine([string[]]$Arguments) {
  $result = & git @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed" }
  return (($result | Out-String).Trim())
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
  $base = $BaseUrl.Trim().TrimEnd("/")
  $expectedBase = "https://cloud-superbrain-llm-gateway-preview.strazzusochr.workers.dev"
  Assert-Equal "fixed public Preview origin" $base $expectedBase

  Write-Host "[llm-hosted-readonly] health"
  $healthRead = Invoke-JsonGet "$base/api/v1/health"
  $health = $healthRead.payload
  Assert-Equal "health contract" ([string]$health.contract_version) "cloudflare-workers-ai-llm-gateway-v1"
  Assert-Equal "health status" ([string]$health.status) "healthy"
  Assert-Equal "health service" ([string]$health.service) "llm-gateway"
  Assert-Equal "health provider" ([string]$health.provider) "cloudflare-workers-ai"
  Assert-Equal "health mode" ([string]$health.mode) "cloudflare_workers_ai_live"
  Assert-True "health source commit shape" ([string]$health.source_commit_sha -match "^[0-9a-f]{40}$")
  Assert-True "health source archive hash shape" ([string]$health.source_archive_sha256 -match "^[0-9a-f]{64}$")
  Assert-TrueField "health" $health "ai_binding_configured"
  Assert-TrueField "health" $health "gateway_auth_configured"
  Assert-TrueField "health" $health "auth_required"
  Assert-TrueField "health" $health "live_provider_calls_available"
  Assert-FalseField "health" $health "live_provider_calls"
  Assert-FalseField "health" $health "direct_provider_calls"
  Assert-FalseField "health" $health "secret_output"

  Write-Host "[llm-hosted-readonly] models"
  $modelsRead = Invoke-JsonGet "$base/v1/models"
  $models = $modelsRead.payload
  Assert-Equal "models contract" ([string]$models.contract_version) "cloudflare-workers-ai-llm-gateway-v1"
  Assert-Equal "models object" ([string]$models.object) "list"
  Assert-FalseField "models" $models "live_provider_calls"
  $expectedModels = @(
    "@cf/meta/llama-3.1-8b-instruct-fast",
    "@cf/qwen/qwen2.5-coder-32b-instruct"
  )
  $observedModels = @($models.data | ForEach-Object { [string]$_.id } | Sort-Object)
  Assert-Equal "exact hosted model allowlist" ($observedModels -join "|") (($expectedModels | Sort-Object) -join "|")
  foreach ($model in @($models.data)) {
    Assert-Equal "model $($model.id) object" ([string]$model.object) "model"
    Assert-Equal "model $($model.id) owner" ([string]$model.owned_by) "cloudflare"
  }

  Write-Host "[llm-hosted-readonly] source parity"
  $sourceCommit = [string]$health.source_commit_sha
  & git cat-file -e "$sourceCommit^{commit}" 2>$null
  Assert-True "deployed source commit exists" ($LASTEXITCODE -eq 0)
  & git merge-base --is-ancestor $sourceCommit HEAD
  Assert-True "deployed source is an ancestor of HEAD" ($LASTEXITCODE -eq 0)

  $expectedSourcePaths = @(
    "services/cloudflare-llm-gateway/.gitignore",
    "services/cloudflare-llm-gateway/package-lock.json",
    "services/cloudflare-llm-gateway/package.json",
    "services/cloudflare-llm-gateway/src/index.js",
    "services/cloudflare-llm-gateway/test/index.test.js",
    "services/cloudflare-llm-gateway/wrangler.jsonc"
  )
  $deployedSourcePaths = @(& git ls-tree -r --name-only $sourceCommit -- services/cloudflare-llm-gateway)
  Assert-True "deployed source inventory command" ($LASTEXITCODE -eq 0)
  Assert-Equal "deployed source inventory" (($deployedSourcePaths | Sort-Object) -join "|") (($expectedSourcePaths | Sort-Object) -join "|")

  $sourceBlobs = [ordered]@{}
  foreach ($path in $expectedSourcePaths) {
    $deployedBlob = Invoke-GitLine @("rev-parse", "$sourceCommit`:$path")
    $currentBlob = Invoke-GitLine @("rev-parse", "HEAD:$path")
    Assert-True "deployed source unchanged: $path" ($deployedBlob -eq $currentBlob -and $deployedBlob -match "^[0-9a-f]{40}$")
    $sourceBlobs[$path] = $deployedBlob
  }
  $deployedTree = Invoke-GitLine @("rev-parse", "$sourceCommit`:services/cloudflare-llm-gateway")
  $currentTree = Invoke-GitLine @("rev-parse", "HEAD:services/cloudflare-llm-gateway")
  Assert-Equal "deployed source tree matches HEAD" $deployedTree $currentTree
  & git diff --quiet -- services/cloudflare-llm-gateway
  Assert-True "current source worktree is clean" ($LASTEXITCODE -eq 0)

  if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
  }
  $reportPath = Join-Path $OutDir "report.json"
  $report = [ordered]@{
    contract_version = "cloudflare-llm-gateway-hosted-readonly-v1"
    status = "verified"
    evidence_ref = "cloudflare_workers_ai_llm_gateway_preview_readonly_source_parity_verified"
    checked_at = [DateTime]::UtcNow.ToString("o")
    transport = "public_https_get_only"
    base_url = $base
    source = [ordered]@{
      deployed_commit_sha = $sourceCommit
      deployed_archive_sha256 = [string]$health.source_archive_sha256
      deployed_tree_sha = $deployedTree
      current_head_sha = Invoke-GitLine @("rev-parse", "HEAD")
      current_tree_sha = $currentTree
      blob_parity = $true
      worktree_clean = $true
      blobs = $sourceBlobs
    }
    health = [ordered]@{
      path = "/api/v1/health"
      http_status = 200
      response_sha256 = [string]$healthRead.content_sha256
      status = [string]$health.status
      provider = [string]$health.provider
      ai_binding_configured = $true
      gateway_auth_configured = $true
      live_provider_calls_available = $true
      live_provider_calls = $false
      direct_provider_calls = $false
      secret_output = $false
    }
    models = [ordered]@{
      path = "/v1/models"
      http_status = 200
      response_sha256 = [string]$modelsRead.content_sha256
      ids = @($observedModels)
      live_provider_calls = $false
    }
    token_used = $false
    inference_executed = $false
    provider_write = $false
    production_deploy = $false
    release_promotion = $false
    secret_output = $false
    non_claims = @(
      "The proof reads the public Preview Worker only and does not claim a Production Worker deployment.",
      "Workers AI availability is configuration evidence; no inference request is sent.",
      "No authentication token, provider mutation, release action, or production deployment is performed."
    )
  }
  $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reportPath -Encoding utf8
  Write-Host "[llm-hosted-readonly] status=verified source_parity=true model_count=2 live_provider_calls=false token_used=false report=$reportPath"
} finally {
  Pop-Location
}

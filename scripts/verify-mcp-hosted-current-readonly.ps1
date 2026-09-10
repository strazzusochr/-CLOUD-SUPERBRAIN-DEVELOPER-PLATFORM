param(
  [string]$BaseUrl = "https://cloud-superbrain-developer-platform.vercel.app",
  [string]$ConfigPath = "docs\runtime-state\backend-hosted-current.json",
  [string]$OutDir = ".codex\runs\CURRENT\mcp-gateway\hosted-readonly-contract"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) { throw "Current hosted MCP read-only verification failed: $Label" }
  Write-Host "[mcp-hosted-readonly] $Label"
}

function Assert-SetEqual([string]$Label, [string[]]$Actual, [string[]]$Expected) {
  $actualKey = (($Actual | Sort-Object -Unique) -join ",")
  $expectedKey = (($Expected | Sort-Object -Unique) -join ",")
  Assert-True $Label ($actualKey -eq $expectedKey)
}

function Assert-FalseField([string]$Label, $Payload, [string]$Field) {
  $property = $Payload.PSObject.Properties[$Field]
  Assert-True "$Label $Field=false" ($null -ne $property -and $property.Value -is [bool] -and -not [bool]$property.Value)
}

function Invoke-JsonGet([string]$Uri) {
  $response = Invoke-WebRequest -UseBasicParsing -Uri $Uri -Method Get -TimeoutSec 30
  Assert-True "GET $Uri returns HTTP 200" ([int]$response.StatusCode -eq 200)
  return $response.Content | ConvertFrom-Json
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
  Assert-True "public HTTPS base URL" ($base -match "^https://" -and $base -notmatch "localhost|127\.0\.0\.1|0\.0\.0\.0")
  Assert-True "hosted proof config exists" (Test-Path -LiteralPath $ConfigPath)

  $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
  Assert-True "hosted config verified" ([string]$config.contract_version -eq "backend-hosted-current-proof-v1" -and [string]$config.status -eq "verified")
  Assert-True "base URL matches production alias" ([string]$config.production_alias -eq $base)
  Assert-True "deployment target production" ([string]$config.vercel_target -eq "production")
  Assert-True "read-only contract origin" ([bool]$config.read_only_contract_origin)
  Assert-True "deployment metadata verified" ([bool]$config.deployment_metadata_verified)
  Assert-True "MCP health snapshot healthy" ([string]$config.mcp_health_status -eq "healthy")
  Assert-True "stateful backend remains unclaimed" (-not [bool]$config.stateful_backend_verified)
  Assert-True "production release remains unclaimed" (-not [bool]$config.production_release_claimed)
  Assert-True "source commit shape" ([string]$config.source_commit_sha -match "^[0-9a-f]{40}$")
  Assert-True "source archive hash shape" ([string]$config.source_archive_sha256 -match "^[0-9a-f]{64}$")

  $verificationArtifact = [string]$config.verification_artifact
  Assert-True "source-bound backend verification artifact exists" (Test-Path -LiteralPath $verificationArtifact)
  $deploymentEvidence = Get-Content -LiteralPath $verificationArtifact -Raw | ConvertFrom-Json
  Assert-True "deployment evidence verified" ([string]$deploymentEvidence.contract_version -eq "backend-hosted-current-verification-v1" -and [string]$deploymentEvidence.status -eq "verified")
  foreach ($field in @("source_commit_sha", "source_archive_sha256", "deployment_id", "production_alias", "vercel_target")) {
    Assert-True "deployment identity $field matches config" ([string]$deploymentEvidence.$field -eq [string]$config.$field)
  }
  Assert-True "recorded read-only POST boundary is HTTP 503" ([int]$deploymentEvidence.read_only_post_boundary_http -eq 503)
  Assert-True "recorded MCP health is healthy" ([string]$deploymentEvidence.mcp_health_status -eq "healthy")
  Assert-True "recorded release remains false" (-not [bool]$deploymentEvidence.production_release_claimed)

  Write-Host "[mcp-hosted-readonly] source identity"
  $sourcePaths = @(
    "api/mcp.py",
    "vercel.json",
    "requirements.txt",
    "services/mcp-gateway/.dockerignore",
    "services/mcp-gateway/Dockerfile",
    "services/mcp-gateway/app/main.py",
    "services/mcp-gateway/requirements.txt"
  )
  $sourceBlobs = [ordered]@{}
  foreach ($path in $sourcePaths) {
    $deployedBlob = Invoke-GitLine @("rev-parse", "$($config.source_commit_sha):$path")
    $currentBlob = Invoke-GitLine @("rev-parse", "HEAD:$path")
    Assert-True "deployed MCP source unchanged: $path" ($deployedBlob -eq $currentBlob -and $deployedBlob -match "^[0-9a-f]{40}$")
    $sourceBlobs[$path] = $deployedBlob
  }
  & git diff --quiet -- @sourcePaths
  Assert-True "MCP deployment source paths clean in worktree" ($LASTEXITCODE -eq 0)

  Write-Host "[mcp-hosted-readonly] health"
  $health = Invoke-JsonGet "$base/mcp/api/v1/health"
  Assert-True "live MCP health healthy" ([string]$health.status -eq "healthy" -and [string]$health.service -eq "mcp-gateway")
  Assert-True "GitHub availability honestly false" ($health.toolsets.github -is [bool] -and -not [bool]$health.toolsets.github)
  Assert-True "E2B availability honestly false" ($health.toolsets.e2b -is [bool] -and -not [bool]$health.toolsets.e2b)
  Assert-True "PostgreSQL availability honestly false" ($health.toolsets.postgres_readonly -is [bool] -and -not [bool]$health.toolsets.postgres_readonly)
  Assert-True "Playwright contract availability true" ($health.toolsets.playwright -is [bool] -and [bool]$health.toolsets.playwright)
  Assert-True "filesystem root remains scoped" ([string]$health.toolsets.filesystem_root -eq "/tmp/agent-workspace")

  Write-Host "[mcp-hosted-readonly] dry-run contracts"
  $contractSpecs = @(
    [ordered]@{ name = "github"; path = "/mcp/api/v1/github/branch-pr/contract"; version = "github-branch-pr-plan-v1"; live_field = "live_github_call" },
    [ordered]@{ name = "postgresql"; path = "/mcp/api/v1/postgresql/readonly-query/contract"; version = "postgresql-readonly-query-v1"; live_field = "live_database_call" },
    [ordered]@{ name = "filesystem"; path = "/mcp/api/v1/filesystem/workspace-scope/contract"; version = "filesystem-workspace-scope-v1"; live_field = "live_filesystem_call" },
    [ordered]@{ name = "playwright"; path = "/mcp/api/v1/playwright/browser-proof/contract"; version = "playwright-browser-proof-v1"; live_field = "live_browser_call" },
    [ordered]@{ name = "e2b"; path = "/mcp/api/v1/e2b/sandbox-lifecycle/contract"; version = "e2b-sandbox-lifecycle-v1"; live_field = "live_e2b_call" }
  )
  $contractEvidence = @()
  foreach ($spec in $contractSpecs) {
    $payload = Invoke-JsonGet "$base$($spec.path)"
    Assert-True "$($spec.name) contract version" ([string]$payload.contract_version -eq [string]$spec.version)
    Assert-True "$($spec.name) contract remains dry-run" ([string]$payload.mode -eq "dry_run_contract_only")
    Assert-FalseField $spec.name $payload ([string]$spec.live_field)
    $contractEvidence += [ordered]@{
      name = [string]$spec.name
      path = [string]$spec.path
      contract_version = [string]$payload.contract_version
      mode = [string]$payload.mode
      live_field = [string]$spec.live_field
      live_value = $false
      http_status = 200
    }
  }

  Write-Host "[mcp-hosted-readonly] version pinning"
  $versionContract = Invoke-JsonGet "$base/mcp/api/v1/version-pinning/contract"
  Assert-True "version-pinning contract" ([string]$versionContract.contract_version -eq "mcp-version-pinning-v1")
  Assert-True "version-pinning evidence" ([string]$versionContract.evidence_ref -eq "mcp_version_pinning_contract_visible")
  Assert-True "exact dependency pin policy" ([string]$versionContract.gateway.dependency_pin_policy -eq "exact_version_required")
  $expectedPins = @(Get-Content -LiteralPath "services\mcp-gateway\requirements.txt" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  $observedPins = @($versionContract.pinned_dependencies | ForEach-Object { [string]$_.pin })
  Assert-SetEqual "hosted dependency pins match current source" $observedPins $expectedPins
  Assert-True "five pinned tool contracts" (@($versionContract.pinned_tool_contracts).Count -eq 5)
  foreach ($toolContract in @($versionContract.pinned_tool_contracts)) {
    Assert-True "pinned $($toolContract.toolset) mutation false" ($toolContract.live_mutation -is [bool] -and -not [bool]$toolContract.live_mutation)
  }
  $versionNonClaims = (@($versionContract.non_claims) -join " ")
  Assert-True "version contract retains no-live-write nonclaim" ($versionNonClaims.Contains("No live MCP write"))

  Write-Host "[mcp-hosted-readonly] audit contract"
  $auditContract = Invoke-JsonGet "$base/api/v1/audit/mcp/contract"
  Assert-True "MCP audit contract" ([string]$auditContract.contract_version -eq "mcp-audit-feed-v1")
  Assert-True "MCP audit mode" ([string]$auditContract.mode -eq "mcp_tool_audit_runtime_feed")
  Assert-SetEqual "MCP audit statuses" @($auditContract.supported_statuses | ForEach-Object { [string]$_ }) @("success", "blocked", "timeout", "degraded")
  Assert-SetEqual "MCP audit toolsets" @($auditContract.supported_toolsets | ForEach-Object { [string]$_ }) @("github", "e2b", "playwright", "filesystem", "postgresql", "puppeteer")
  foreach ($field in @("tool_request_id", "run_id", "trace_id", "agent_role", "toolset", "capability", "status", "duration_ms", "session_bound", "audit_evidence_ref")) {
    Assert-True "MCP audit detail field $field" (@($auditContract.required_detail_fields) -contains $field)
  }
  Assert-True "MCP audit runtime evidence ref" ([string]$auditContract.evidence_refs.runtime_visible -eq "hosted_mcp_audit_feed_contract_runtime_parity_proof")
  $auditNonClaims = (@($auditContract.non_claims) -join " ")
  Assert-True "audit contract retains no-live-write nonclaim" ($auditNonClaims.Contains("does not claim live MCP writes"))

  if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
  }
  $artifactHash = (Get-FileHash -LiteralPath $verificationArtifact -Algorithm SHA256).Hash
  $reportPath = Join-Path $OutDir "report.json"
  $report = [ordered]@{
    contract_version = "mcp-hosted-current-readonly-v1"
    status = "verified"
    evidence_ref = "mcp_current_hosted_readonly_contract_parity_verified"
    transport = "https_get_only"
    base_url = $base
    deployment = [ordered]@{
      id = [string]$config.deployment_id
      source_commit_sha = [string]$config.source_commit_sha
      source_archive_sha256 = [string]$config.source_archive_sha256
      verification_artifact = $verificationArtifact.Replace("\", "/")
      verification_artifact_sha256 = $artifactHash
      read_only_post_boundary_http = [int]$deploymentEvidence.read_only_post_boundary_http
      source_blobs = $sourceBlobs
    }
    health = [ordered]@{
      status = [string]$health.status
      service = [string]$health.service
      github_available = [bool]$health.toolsets.github
      e2b_available = [bool]$health.toolsets.e2b
      postgres_readonly_available = [bool]$health.toolsets.postgres_readonly
      playwright_contract_available = [bool]$health.toolsets.playwright
      filesystem_root = [string]$health.toolsets.filesystem_root
    }
    dry_run_contracts = $contractEvidence
    version_pinning = [ordered]@{
      contract_version = [string]$versionContract.contract_version
      dependency_pins = $observedPins
      tool_contract_count = @($versionContract.pinned_tool_contracts).Count
    }
    audit_contract = [ordered]@{
      contract_version = [string]$auditContract.contract_version
      mode = [string]$auditContract.mode
      runtime_evidence_ref = [string]$auditContract.evidence_refs.runtime_visible
    }
    paid_provider = $false
    token_used = $false
    provider_write = $false
    live_mcp_writes = $false
    stateful_backend_verified = $false
    production_release_claimed = $false
    verified_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    non_claims = @(
      "This proof validates public read-only contract parity on the source-bound Vercel Contract Origin.",
      "It does not prove GitHub, E2B, or PostgreSQL tool availability; hosted health reports those unavailable.",
      "It does not execute an MCP tool, persist an audit event, use a token, mutate a provider, prove a stateful backend, or authorize a release."
    )
  }
  $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $reportPath -Encoding utf8
  Write-Host "[mcp-hosted-readonly] report=$reportPath"
  Write-Host "[mcp-hosted-readonly] checks completed"
} finally {
  Pop-Location
}

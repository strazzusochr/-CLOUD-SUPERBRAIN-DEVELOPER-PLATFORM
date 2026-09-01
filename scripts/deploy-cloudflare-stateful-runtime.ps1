<#
.SYNOPSIS
  Deploys the Cloudflare stateful runtime worker with a mandatory source binding.

.DESCRIPTION
  wrangler replaces the whole plain_text var set with the `vars` block of
  wrangler.jsonc on every deploy. SOURCE_COMMIT_SHA and SOURCE_ARCHIVE_SHA256 are
  intentionally NOT stored in that file, because they change per candidate. A plain
  `wrangler deploy` therefore silently wipes them and the hosted source parity check
  in scripts/verify-cloudflare-stateful-runtime.ps1 fails closed.

  This script is the only sanctioned deploy path. It validates the public OAuth
  routing contract without reading secret values, recomputes both source values from
  the given commit, and binds production-auth Owner authority only from that commit's
  tracked capability-gate state. It passes the derived values explicitly so neither
  source binding nor Owner authority can drift with a dirty working tree.

  Regression this guards: 2026-08-30, a deploy without these vars left the hosted
  worker reporting source_commit_sha=null.
#>
param(
  [string]$CommitSha = "HEAD",
  [switch]$DryRun,
  [switch]$ValidateOnly,
  [string]$CandidateFrontendOrigin = "",
  [switch]$EnableHostedMcpWrites,
  [string]$CandidateBranch = "",
  [string]$LayerCreditRubricApprovalSha = "",
  [string]$HostedMcpOwnerGrantCommitSha = "",
  [string]$CandidateFrontendEvidenceCommitSha = "",
  [switch]$DeployLlmGateway
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) { throw "Worker deploy precondition failed: $Label" }
  Write-Host "[worker-deploy] $Label"
}

function Get-PlainTextVar([object]$Vars, [string]$Name) {
  $property = $Vars.PSObject.Properties[$Name]
  if ($null -eq $property -or $property.Value -isnot [string]) { return "" }
  return ([string]$property.Value).Trim()
}

function Get-CanonicalVercelOrigin([string]$Label, [string]$Value) {
  Assert-True "$Label is present and bounded" (
    -not [string]::IsNullOrWhiteSpace($Value) -and
    $Value.Length -le 256 -and
    $Value -ceq $Value.Trim()
  )
  $parsed = $null
  $parsedOk = [System.Uri]::TryCreate($Value, [System.UriKind]::Absolute, [ref]$parsed)
  Assert-True "$Label is an absolute URI" $parsedOk
  Assert-True "$Label is a canonical HTTPS Vercel origin" (
    $parsed.Scheme -ceq "https" -and
    [string]::IsNullOrEmpty($parsed.UserInfo) -and
    $parsed.IsDefaultPort -and
    $parsed.AbsolutePath -ceq "/" -and
    [string]::IsNullOrEmpty($parsed.Query) -and
    [string]::IsNullOrEmpty($parsed.Fragment) -and
    $parsed.DnsSafeHost -cmatch "^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.vercel\.app$"
  )
  $canonical = "https://$($parsed.DnsSafeHost)"
  Assert-True "$Label contains no explicit port, path, query, fragment, credentials, or case drift" ($Value -ceq $canonical)
  return $canonical
}

function Get-GitArchiveSha256([string]$RepositoryRoot, [string]$ResolvedCommit) {
  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = "git"
  $startInfo.WorkingDirectory = $RepositoryRoot
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  [void]$startInfo.ArgumentList.Add("archive")
  [void]$startInfo.ArgumentList.Add("--format=tar")
  [void]$startInfo.ArgumentList.Add($ResolvedCommit)
  $process = [System.Diagnostics.Process]::Start($startInfo)
  $stderrTask = $process.StandardError.ReadToEndAsync()
  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  try {
    $digest = $sha256.ComputeHash($process.StandardOutput.BaseStream)
  } finally {
    $sha256.Dispose()
  }
  $process.WaitForExit()
  $null = $stderrTask.GetAwaiter().GetResult()
  $archiveExitCode = $process.ExitCode
  $process.Dispose()
  Assert-True "source archive stream completed" ($archiveExitCode -eq 0)
  return [System.Convert]::ToHexString($digest).ToLowerInvariant()
}

function Get-GitBlobSha256([string]$RepositoryRoot, [string]$ObjectSpec) {
  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = "git"
  $startInfo.WorkingDirectory = $RepositoryRoot
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  [void]$startInfo.ArgumentList.Add("cat-file")
  [void]$startInfo.ArgumentList.Add("blob")
  [void]$startInfo.ArgumentList.Add($ObjectSpec)
  $process = [System.Diagnostics.Process]::Start($startInfo)
  $stderrTask = $process.StandardError.ReadToEndAsync()
  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  try {
    $digest = $sha256.ComputeHash($process.StandardOutput.BaseStream)
  } finally {
    $sha256.Dispose()
  }
  $process.WaitForExit()
  $null = $stderrTask.GetAwaiter().GetResult()
  $exitCode = $process.ExitCode
  $process.Dispose()
  Assert-True "tracked blob loaded for immutable binding" ($exitCode -eq 0)
  return [System.Convert]::ToHexString($digest).ToLowerInvariant()
}

function Get-ManifestSha256([hashtable]$Entries) {
  $lines = @(
    $Entries.GetEnumerator() |
      Sort-Object Key |
      ForEach-Object { "$($_.Key.Replace('\', '/'))`t$($_.Value)" }
  )
  Assert-True "immutable manifest contains entries" ($lines.Count -gt 0)
  $bytes = [System.Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
  return [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Remove-TransientMaterialization([string]$Path) {
  $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
  )
  $resolvedPath = [System.IO.Path]::GetFullPath($Path).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
  )
  $leaf = [System.IO.Path]::GetFileName($resolvedPath)
  $safePrefix = $tempRoot + [System.IO.Path]::DirectorySeparatorChar
  Assert-True "transient source materialization cleanup target is bounded" (
    $resolvedPath.StartsWith($safePrefix, [System.StringComparison]::OrdinalIgnoreCase) -and
    $leaf -match "^cloud-superbrain-worker-deploy-[0-9a-f]{32}$"
  )
  if (Test-Path -LiteralPath $resolvedPath) {
    Remove-Item -LiteralPath $resolvedPath -Recurse -Force
  }
  Write-Host "[worker-deploy] transient source materialization removed"
}

function Invoke-LlmGatewayCandidateDeploy(
  [string]$RepositoryRoot,
  [string]$SelectedCommit,
  [bool]$IsDryRun,
  [bool]$IsValidateOnly
) {
  $relativeServiceRoot = "services/cloudflare-llm-gateway"
  $previewName = "cloud-superbrain-llm-gateway-preview"
  $previewHealthUrl = "https://$previewName.strazzusochr.workers.dev/api/v1/health"
  $resolved = (& git rev-parse --verify "$SelectedCommit^{commit}" 2>$null).Trim()
  Assert-True "LLM candidate commit resolved ($resolved)" (
    $LASTEXITCODE -eq 0 -and $resolved -match "^[0-9a-f]{40}$"
  )
  $archiveSha = Get-GitArchiveSha256 $RepositoryRoot $resolved
  Assert-True "LLM candidate source archive SHA-256 computed" ($archiveSha -match "^[0-9a-f]{64}$")

  $materializationRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    "cloud-superbrain-worker-deploy-" + [Guid]::NewGuid().ToString("N")
  )
  $materializedServiceDir = Join-Path $materializationRoot "worker"
  $serviceArchive = Join-Path $materializationRoot "worker-source.tar"
  New-Item -ItemType Directory -Path $materializedServiceDir -Force | Out-Null
  try {
    & git archive --format=tar "--output=$serviceArchive" $resolved -- $relativeServiceRoot
    Assert-True "selected LLM gateway source archive created" ($LASTEXITCODE -eq 0)
    $null = & tar -xf $serviceArchive -C $materializedServiceDir --strip-components=2 2>&1
    Assert-True "selected LLM gateway source archive materialized" ($LASTEXITCODE -eq 0)
    foreach ($requiredPath in @("package.json", "package-lock.json", "wrangler.jsonc", "src/index.js")) {
      Assert-True "selected LLM gateway materialization contains $requiredPath" (
        Test-Path -LiteralPath (Join-Path $materializedServiceDir $requiredPath) -PathType Leaf
      )
    }

    $materializedConfigPath = Join-Path $materializedServiceDir "wrangler.jsonc"
    try {
      $config = Get-Content -LiteralPath $materializedConfigPath -Raw | ConvertFrom-Json
    } catch {
      throw "Worker deploy precondition failed: selected LLM gateway wrangler config is invalid"
    }
    $preview = $config.env.PSObject.Properties["preview"].Value
    Assert-True "LLM candidate deploy targets the dedicated preview Worker" (
      $null -ne $preview -and [string]$preview.name -ceq $previewName
    )
    $previewDatabases = @($preview.d1_databases)
    Assert-True "LLM candidate uses the isolated preview D1 binding" (
      $previewDatabases.Count -eq 1 -and
      [string]$previewDatabases[0].binding -ceq "DB" -and
      [string]$previewDatabases[0].database_name -ceq "cloud-superbrain-state-preview"
    )
    $topVars = $config.vars
    $previewVars = $preview.vars
    Assert-True "LLM preview gateway mode is explicit" (
      (Get-PlainTextVar $previewVars "GATEWAY_MODE") -ceq "cloudflare_workers_ai_live"
    )
    Assert-True "LLM preview AI Gateway id is explicit" (
      (Get-PlainTextVar $previewVars "AI_GATEWAY_ID") -ceq $previewName
    )
    foreach ($secretName in @("GATEWAY_AUTH_TOKEN")) {
      Assert-True "LLM $secretName remains outside plain-text vars" (
        $null -eq $topVars.PSObject.Properties[$secretName] -and
        $null -eq $previewVars.PSObject.Properties[$secretName]
      )
    }
    foreach ($derivedName in @("SOURCE_COMMIT_SHA", "SOURCE_ARCHIVE_SHA256")) {
      Assert-True "LLM $derivedName remains candidate-derived" (
        $null -eq $topVars.PSObject.Properties[$derivedName] -and
        $null -eq $previewVars.PSObject.Properties[$derivedName]
      )
    }
    if ($IsValidateOnly) {
      Write-Host "[worker-deploy] LLM validation complete; nothing was published"
      return
    }

    try {
      $lock = Get-Content -LiteralPath (Join-Path $materializedServiceDir "package-lock.json") -Raw | ConvertFrom-Json -AsHashtable
    } catch {
      throw "Worker deploy precondition failed: selected LLM gateway package lock is invalid"
    }
    $lockedWranglerVersion = [string]$lock["packages"]["node_modules/wrangler"]["version"]
    Assert-True "selected LLM gateway package lock pins Wrangler" (
      $lockedWranglerVersion -match "^[0-9]+\.[0-9]+\.[0-9]+$"
    )
    Push-Location $materializedServiceDir
    try {
      $null = & npm ci --ignore-scripts --prefer-offline --no-audit --no-fund 2>&1
      $npmCiExitCode = $LASTEXITCODE
    } finally { Pop-Location }
    Assert-True "fresh LLM gateway dependency tree installed from the selected lock" ($npmCiExitCode -eq 0)
    $wrangler = Join-Path $materializedServiceDir "node_modules/wrangler/bin/wrangler.js"
    Assert-True "materialized LLM Wrangler present" (Test-Path -LiteralPath $wrangler -PathType Leaf)
    $installedWranglerVersion = ((& node $wrangler --version 2>$null) -join "").Trim()
    Assert-True "materialized LLM Wrangler matches the selected lock" (
      $LASTEXITCODE -eq 0 -and $installedWranglerVersion -ceq $lockedWranglerVersion
    )

    $bindingArgs = @(
      "--var", "GATEWAY_MODE:cloudflare_workers_ai_live",
      "--var", "AI_GATEWAY_ID:$previewName",
      "--var", "SOURCE_COMMIT_SHA:$resolved",
      "--var", "SOURCE_ARCHIVE_SHA256:$archiveSha"
    )
    $preflightOutputDir = Join-Path $materializationRoot "preflight-output"
    $preflightMetafile = Join-Path $materializationRoot "bundle-preflight-meta.json"
    $preflightArgs = @($wrangler, "deploy", "--env", "preview") + $bindingArgs + @(
      "--dry-run", "--outdir", $preflightOutputDir, "--metafile", $preflightMetafile
    )
    Push-Location $materializedServiceDir
    try {
      $null = & node @preflightArgs 2>&1
      $preflightExitCode = $LASTEXITCODE
    } finally { Pop-Location }
    Assert-True "selected-source LLM Wrangler preflight exit code 0" ($preflightExitCode -eq 0)
    $preflightScripts = @(Get-ChildItem -LiteralPath $preflightOutputDir -File -Filter "*.js")
    Assert-True "selected-source LLM Wrangler emitted exactly one JavaScript upload bundle" (
      $preflightScripts.Count -eq 1 -and $preflightScripts[0].Name -ceq "index.js"
    )
    Assert-True "LLM preflight bundle metafile created" (
      Test-Path -LiteralPath $preflightMetafile -PathType Leaf
    )
    try {
      $preflightMetadata = Get-Content -LiteralPath $preflightMetafile -Raw | ConvertFrom-Json
    } catch {
      throw "Worker deploy precondition failed: LLM preflight bundle metafile is invalid"
    }
    $materializedRootFull = [System.IO.Path]::GetFullPath($materializedServiceDir).TrimEnd(
      [System.IO.Path]::DirectorySeparatorChar
    )
    foreach ($inputName in @($preflightMetadata.inputs.PSObject.Properties.Name)) {
      $inputFull = if ([System.IO.Path]::IsPathRooted([string]$inputName)) {
        [System.IO.Path]::GetFullPath([string]$inputName)
      } else {
        [System.IO.Path]::GetFullPath((Join-Path $materializedServiceDir ([string]$inputName)))
      }
      Assert-True "LLM preflight input is confined to the selected source materialization" (
        $inputFull.StartsWith(
          $materializedRootFull + [System.IO.Path]::DirectorySeparatorChar,
          [System.StringComparison]::OrdinalIgnoreCase
        )
      )
    }
    $preflightBundleFile = $preflightScripts[0].FullName
    $sourceBundleSha = (Get-FileHash -LiteralPath $preflightBundleFile -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-True "exact LLM upload bundle SHA-256 computed" ($sourceBundleSha -match "^[0-9a-f]{64}$")
    if ($IsDryRun) {
      Write-Host "[worker-deploy] LLM dry-run complete; nothing was published"
      return
    }

    $deployArgs = @(
      $wrangler, "deploy", $preflightBundleFile,
      "--no-bundle", "--config", $materializedConfigPath,
      "--env", "preview"
    ) + $bindingArgs
    Push-Location $materializedServiceDir
    try {
      $null = & node @deployArgs 2>&1
      $deployExitCode = $LASTEXITCODE
    } finally { Pop-Location }
    Assert-True "LLM Wrangler deploy exit code 0; command output suppressed" ($deployExitCode -eq 0)
    $health = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 30 -Uri $previewHealthUrl).Content | ConvertFrom-Json
    Assert-True "LLM preview reports healthy" ([string]$health.status -ceq "healthy")
    Assert-True "LLM preview source_commit_sha rebound" ([string]$health.source_commit_sha -ceq $resolved)
    Assert-True "LLM preview source_archive_sha256 rebound" ([string]$health.source_archive_sha256 -ceq $archiveSha)
    Assert-True "LLM preview source binding configured" ($health.source_binding_configured -is [bool] -and $health.source_binding_configured)
    Assert-True "LLM preview gateway auth configured" ($health.gateway_auth_configured -is [bool] -and $health.gateway_auth_configured)
    Write-Host "[worker-deploy] LLM preview commit, archive, auth, and exact uploaded bundle verified"
  } finally {
    Remove-TransientMaterialization $materializationRoot
  }
}

$canonicalPostLoginRedirect = "/workbench"
$previewWorkerHostname = "cloud-superbrain-stateful-runtime-preview.strazzusochr.workers.dev"
$previewWorkerHealthUrl = "https://$previewWorkerHostname/api/v1/health"
$previewWorkerMcpHealthUrl = "https://$previewWorkerHostname/mcp/api/v1/health"
$hostedMcpDeploymentEnvironment = "candidate_preview"

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
  Assert-True "DryRun and ValidateOnly are mutually exclusive" (-not ($DryRun -and $ValidateOnly))

  if ($DeployLlmGateway) {
    Assert-True "LLM deploy mode excludes stateful-runtime-only arguments" (
      -not $EnableHostedMcpWrites -and
      [string]::IsNullOrWhiteSpace($CandidateFrontendOrigin) -and
      [string]::IsNullOrWhiteSpace($CandidateBranch) -and
      [string]::IsNullOrWhiteSpace($LayerCreditRubricApprovalSha) -and
      [string]::IsNullOrWhiteSpace($HostedMcpOwnerGrantCommitSha) -and
      [string]::IsNullOrWhiteSpace($CandidateFrontendEvidenceCommitSha)
    )
    Invoke-LlmGatewayCandidateDeploy $repoRoot $CommitSha $DryRun.IsPresent $ValidateOnly.IsPresent
    return
  }

  $workerDir = Join-Path $repoRoot "services/cloudflare-stateful-runtime"
  $wranglerConfigPath = Join-Path $workerDir "wrangler.jsonc"
  Assert-True "wrangler config present" (Test-Path -LiteralPath $wranglerConfigPath -PathType Leaf)
  try {
    $wranglerConfig = Get-Content -LiteralPath $wranglerConfigPath -Raw | ConvertFrom-Json
  } catch {
    throw "Worker deploy precondition failed: wrangler config is not valid JSONC without comments"
  }
  $plainVarsProperty = $wranglerConfig.PSObject.Properties["vars"]
  Assert-True "top-level public vars configured" ($null -ne $plainVarsProperty -and $null -ne $plainVarsProperty.Value)
  $plainVars = $plainVarsProperty.Value
  $previewEnvironmentProperty = $wranglerConfig.env.PSObject.Properties["preview"]
  Assert-True "candidate deploy targets the dedicated preview Worker" (
    $null -ne $previewEnvironmentProperty -and
    $null -ne $previewEnvironmentProperty.Value -and
    [string]$previewEnvironmentProperty.Value.name -ceq "cloud-superbrain-stateful-runtime-preview"
  )

  $oauthClientId = Get-PlainTextVar $plainVars "GITHUB_OAUTH_CLIENT_ID"
  $oauthOwnerIds = Get-PlainTextVar $plainVars "GITHUB_OAUTH_OWNER_IDS"
  $postLoginRedirect = Get-PlainTextVar $plainVars "POST_LOGIN_REDIRECT"
  $memoryEmbeddingModel = Get-PlainTextVar $plainVars "MEMORY_EMBEDDING_MODEL"

  Assert-True "public OAuth client id configured" ($oauthClientId -match "^(?:[A-Za-z0-9]{20}|[IO]v1\.[A-Fa-f0-9]{16})$")
  Assert-True "public OAuth owner allowlist configured" ($oauthOwnerIds -match "^[1-9][0-9]*(,[1-9][0-9]*)*$")
  Assert-True "post-login redirect is the canonical frontend path" ($postLoginRedirect -ceq $canonicalPostLoginRedirect)
  Assert-True "memory embedding model is an explicit Cloudflare model id" (
    $memoryEmbeddingModel -match "^@cf/[a-z0-9][a-z0-9._/-]{1,180}$" -and
    $memoryEmbeddingModel -notmatch "\.\."
  )

  foreach ($secretName in @("GITHUB_OAUTH_CLIENT_SECRET", "JWT_SIGNING_SECRET", "AGENT_API_AUTH_TOKEN")) {
    Assert-True "$secretName remains outside plain-text vars" ($null -eq $plainVars.PSObject.Properties[$secretName])
  }
  foreach ($derivedName in @(
    "SOURCE_COMMIT_SHA",
    "SOURCE_ARCHIVE_SHA256",
    "SOURCE_BUNDLE_SHA256",
    "PRODUCTION_AUTH_OWNER_GRANTED",
    "PRODUCTION_AUTH_OWNER_GRANT_REF",
    "HOSTED_MCP_WRITE_AUTHORIZED",
    "HOSTED_MCP_WRITE_OWNER_GRANT_REF",
    "HOSTED_MCP_WRITE_OWNER_GRANT_COMMIT_SHA",
    "LAYER_CREDIT_RUBRIC_APPROVAL_SHA",
    "LIVE_MCP_WRITES_ENABLED",
    "HOSTED_MCP_DEPLOYMENT_ENVIRONMENT",
    "HOSTED_MCP_PREVIEW_HOSTNAME",
    "HOSTED_MCP_WRITE_BRANCH",
    "HOSTED_MCP_VERIFIER_BLOB_SHA256",
    "HOSTED_MCP_RUNTIME_BLOB_SHA256",
    "HOSTED_MCP_RUBRIC_BLOB_SHA256",
    "HOSTED_MCP_CAPABILITY_GATE_BLOB_SHA256"
  )) {
    Assert-True "$derivedName remains candidate-derived" ($null -eq $plainVars.PSObject.Properties[$derivedName])
  }

  $resolved = (& git rev-parse --verify "$CommitSha^{commit}").Trim()
  Assert-True "commit resolved ($resolved)" ($LASTEXITCODE -eq 0 -and $resolved -match "^[0-9a-f]{40}$")

  $archiveSha = Get-GitArchiveSha256 $repoRoot $resolved
  Assert-True "source archive SHA-256 computed without a retained archive" ($archiveSha -match "^[0-9a-f]{64}$")

  $frontendEvidenceCommit = $resolved
  if (-not [string]::IsNullOrWhiteSpace($CandidateFrontendEvidenceCommitSha)) {
    Assert-True "frontend evidence control commit SHA is lowercase" (
      $CandidateFrontendEvidenceCommitSha -match "^[0-9a-f]{40}$"
    )
    $frontendEvidenceCommit = (& git rev-parse --verify "$CandidateFrontendEvidenceCommitSha^{commit}" 2>$null).Trim()
    Assert-True "frontend evidence control commit resolved exactly" (
      $LASTEXITCODE -eq 0 -and $frontendEvidenceCommit -ceq $CandidateFrontendEvidenceCommitSha
    )
  }
  & git merge-base --is-ancestor $resolved $frontendEvidenceCommit 2>$null
  Assert-True "frontend evidence control commit is an ancestor-descendant continuation of the selected source" (
    $LASTEXITCODE -eq 0
  )

  $frontendEvidencePath = "docs/runtime-state/frontend-hosted-current.json"
  $trackedFrontendEvidence = @(& git show "$frontendEvidenceCommit`:$frontendEvidencePath" 2>$null)
  Assert-True "tracked frontend hosted evidence loaded from the evidence control commit" (
    $LASTEXITCODE -eq 0 -and $trackedFrontendEvidence.Count -gt 0
  )
  try {
    $frontendEvidence = ($trackedFrontendEvidence -join "`n") | ConvertFrom-Json
  } catch {
    throw "Worker deploy precondition failed: frontend evidence control commit is not valid JSON"
  }
  Assert-True "tracked frontend hosted evidence contract is supported" (
    [string]$frontendEvidence.contract_version -ceq "frontend-hosted-current-proof-v1" -and
    [string]$frontendEvidence.status -ceq "verified"
  )
  $trackedImmutableFrontendOrigin = Get-CanonicalVercelOrigin `
    "tracked immutable frontend deployment URL" ([string]$frontendEvidence.immutable_deployment_url)
  $trackedProductionAlias = Get-CanonicalVercelOrigin `
    "tracked frontend production alias" ([string]$frontendEvidence.production_alias)
  $trackedFrontendSourceSha = if ($frontendEvidence.source_commit_sha -is [string]) {
    ([string]$frontendEvidence.source_commit_sha).Trim()
  } else { "" }
  Assert-True "tracked frontend evidence has a lowercase source commit" ($trackedFrontendSourceSha -match "^[0-9a-f]{40}$")
  & git cat-file -e "$trackedFrontendSourceSha^{commit}" 2>$null
  Assert-True "tracked frontend source commit is available" ($LASTEXITCODE -eq 0)
  & git merge-base --is-ancestor $resolved $trackedFrontendSourceSha 2>$null
  Assert-True "tracked frontend source is the selected source or its qualification descendant" (
    $LASTEXITCODE -eq 0
  )
  $allowedFrontendQualificationTruthPaths = @(
    "apps/frontend/lib/endpoint-snapshot.json",
    "apps/frontend/lib/platform.ts"
  )
  $frontendRuntimeDelta = @(
    & git diff --name-only --diff-filter=ACDMRTUXB $resolved $trackedFrontendSourceSha -- apps/frontend
  )
  Assert-True "frontend runtime delta scan completed" ($LASTEXITCODE -eq 0)
  $unexpectedFrontendRuntimeDelta = @(
    $frontendRuntimeDelta |
      ForEach-Object { ([string]$_).Replace("\", "/") } |
      Where-Object { $allowedFrontendQualificationTruthPaths -notcontains $_ }
  )
  Assert-True "frontend runtime delta is limited to qualification truth paths" (
    $unexpectedFrontendRuntimeDelta.Count -eq 0
  )
  $computedFrontendArchiveSha = Get-GitArchiveSha256 $repoRoot $trackedFrontendSourceSha
  Assert-True "tracked frontend source archive SHA-256 computed" (
    $computedFrontendArchiveSha -match "^[0-9a-f]{64}$"
  )
  $trackedFrontendArchiveSha = if ($frontendEvidence.source_archive_sha256 -is [string]) {
    ([string]$frontendEvidence.source_archive_sha256).Trim()
  } else { "" }

  $candidateOriginRequired = -not $ValidateOnly
  Assert-True "candidate frontend origin is required for dry-run or publish" (
    -not $candidateOriginRequired -or -not [string]::IsNullOrWhiteSpace($CandidateFrontendOrigin)
  )
  $candidateFrontendOriginCanonical = ""
  if (-not [string]::IsNullOrWhiteSpace($CandidateFrontendOrigin)) {
    $candidateFrontendOriginCanonical = Get-CanonicalVercelOrigin `
      "candidate frontend origin" $CandidateFrontendOrigin
    Assert-True "candidate frontend origin is not the tracked production alias" (
      -not $candidateFrontendOriginCanonical.Equals($trackedProductionAlias, [System.StringComparison]::OrdinalIgnoreCase)
    )
    Assert-True "candidate frontend origin is the tracked immutable deployment URL" (
      $candidateFrontendOriginCanonical -ceq $trackedImmutableFrontendOrigin
    )
    Assert-True "tracked immutable frontend deployment is bound to the selected source lineage" (
      $unexpectedFrontendRuntimeDelta.Count -eq 0
    )
    Assert-True "candidate frontend evidence target is preview" (
      [string]$frontendEvidence.vercel_target -ceq "preview"
    )
    Assert-True "candidate frontend evidence archive matches the tracked frontend source" (
      $trackedFrontendArchiveSha -match "^[0-9a-f]{64}$" -and
      $trackedFrontendArchiveSha -ceq $computedFrontendArchiveSha
    )
    Assert-True "candidate frontend evidence metadata is verified" (
      $frontendEvidence.deployment_metadata_verified -is [bool] -and
      $frontendEvidence.deployment_metadata_verified -eq $true
    )
    Assert-True "candidate frontend evidence carries no production alias parity claim" (
      $frontendEvidence.deployment_alias_content_parity -is [bool] -and
      $frontendEvidence.deployment_alias_content_parity -eq $false
    )
    Assert-True "candidate frontend evidence carries no production deploy claim" (
      $frontendEvidence.production_operational_deploy_verified -is [bool] -and
      $frontendEvidence.production_operational_deploy_verified -eq $false
    )
    Assert-True "candidate frontend evidence carries no production release claim" (
      $frontendEvidence.production_release_claimed -is [bool] -and
      $frontendEvidence.production_release_claimed -eq $false
    )
  }
  $candidateOAuthCallback = if ($candidateFrontendOriginCanonical) {
    "$candidateFrontendOriginCanonical/api/v1/auth/callback"
  } else { "" }
  if ($candidateFrontendOriginCanonical) {
    Assert-True "OAuth callback uses the canonical frontend origin" (
      $candidateOAuthCallback -ceq "$candidateFrontendOriginCanonical/api/v1/auth/callback"
    )
    Assert-True "OAuth callback is not deployed directly on the Worker origin" (
      -not $candidateOAuthCallback.StartsWith("https://$previewWorkerHostname/", [System.StringComparison]::OrdinalIgnoreCase)
    )
  }

  $capabilityStatePath = "docs/runtime-state/capability-gates.json"
  $trackedCapabilityState = @(& git show "$resolved`:$capabilityStatePath" 2>$null)
  Assert-True "tracked capability gate state loaded from the selected commit" ($LASTEXITCODE -eq 0 -and $trackedCapabilityState.Count -gt 0)
  try {
    $capabilityState = ($trackedCapabilityState -join "`n") | ConvertFrom-Json
  } catch {
    throw "Worker deploy precondition failed: selected commit capability gate state is not valid JSON"
  }
  Assert-True "tracked capability gate contract is supported" ([string]$capabilityState.contract_version -ceq "capability-gate-state-v1")
  $gatesProperty = $capabilityState.PSObject.Properties["gates"]
  Assert-True "tracked capability gate map is present" ($null -ne $gatesProperty -and $null -ne $gatesProperty.Value)
  $productionAuthProperty = $gatesProperty.Value.PSObject.Properties["production_auth_identity"]
  Assert-True "tracked production auth gate is present" ($null -ne $productionAuthProperty -and $null -ne $productionAuthProperty.Value)
  $productionAuthGate = $productionAuthProperty.Value
  $ownerGrantedProperty = $productionAuthGate.PSObject.Properties["owner_granted"]
  $ownerGrantRefProperty = $productionAuthGate.PSObject.Properties["owner_grant_ref"]
  $ownerGrantedFromCommit = (
    $null -ne $ownerGrantedProperty -and
    $ownerGrantedProperty.Value -is [bool] -and
    $ownerGrantedProperty.Value -eq $true
  )
  $ownerGrantRef = if ($null -ne $ownerGrantRefProperty -and $ownerGrantRefProperty.Value -is [string]) {
    ([string]$ownerGrantRefProperty.Value).Trim()
  } else {
    ""
  }
  $ownerGrantRefIsSafe = (
    -not [string]::IsNullOrWhiteSpace($ownerGrantRef) -and
    $ownerGrantRef.Length -le 256 -and
    $ownerGrantRef -notmatch "[\x00-\x1f\x7f]"
  )
  $bindProductionAuthOwnerGrant = $ownerGrantedFromCommit -and $ownerGrantRefIsSafe
  Assert-True "tracked production auth owner gate validated without live-state synthesis" ($null -ne $productionAuthGate.PSObject.Properties["live_verified"])

  $mcpBindingArgs = @(
    "--var", "HOSTED_MCP_WRITE_AUTHORIZED:false",
    "--var", "LIVE_MCP_WRITES_ENABLED:false"
  )
  if (-not $EnableHostedMcpWrites) {
    Assert-True "hosted MCP authority inputs are absent while activation is disabled" (
      [string]::IsNullOrWhiteSpace($CandidateBranch) -and
      [string]::IsNullOrWhiteSpace($LayerCreditRubricApprovalSha) -and
      [string]::IsNullOrWhiteSpace($HostedMcpOwnerGrantCommitSha)
    )
  } else {
    Assert-True "hosted MCP candidate branch is canonical and non-protected" (
      $CandidateBranch -match "^[A-Za-z0-9._/-]{1,160}$" -and
      $CandidateBranch -notmatch "//|(^|/)\.\.(/|$)" -and
      $CandidateBranch -notmatch "^(?i:refs/heads/|origin/)" -and
      $CandidateBranch.ToLowerInvariant() -notin @("main", "master", "default", "trunk", "production", "prod")
    )
    Assert-True "hosted MCP rubric approval SHA is lowercase" ($LayerCreditRubricApprovalSha -match "^[0-9a-f]{40}$")
    Assert-True "hosted MCP Owner grant SHA is lowercase" ($HostedMcpOwnerGrantCommitSha -match "^[0-9a-f]{40}$")

    $remoteCandidateRef = "refs/remotes/origin/$CandidateBranch"
    $remoteCandidateSha = (& git rev-parse --verify "$remoteCandidateRef^{commit}" 2>$null).Trim()
    Assert-True "hosted MCP candidate branch is pushed at the selected commit" (
      $LASTEXITCODE -eq 0 -and $remoteCandidateSha -ceq $resolved
    )
    foreach ($authoritySha in @($LayerCreditRubricApprovalSha, $HostedMcpOwnerGrantCommitSha)) {
      & git merge-base --is-ancestor $authoritySha $resolved 2>$null
      Assert-True "hosted MCP authority commit is an ancestor of the candidate" ($LASTEXITCODE -eq 0)
    }

    $mcpGateProperty = $gatesProperty.Value.PSObject.Properties["live_mcp_writes"]
    Assert-True "selected candidate contains the live MCP write gate" ($null -ne $mcpGateProperty -and $null -ne $mcpGateProperty.Value)
    $selectedMcpGate = $mcpGateProperty.Value
    $mcpOwnerGrantRef = if ($selectedMcpGate.owner_grant_ref -is [string]) {
      ([string]$selectedMcpGate.owner_grant_ref).Trim()
    } else { "" }
    Assert-True "selected candidate preserves an explicit bounded MCP Owner grant" (
      $selectedMcpGate.owner_granted -is [bool] -and
      $selectedMcpGate.owner_granted -eq $true -and
      $mcpOwnerGrantRef.Length -ge 8 -and
      $mcpOwnerGrantRef.Length -le 512 -and
      $mcpOwnerGrantRef -notmatch "[\x00-\x1f\x7f]"
    )

    $grantStateText = @(& git show "$HostedMcpOwnerGrantCommitSha`:$capabilityStatePath" 2>$null)
    Assert-True "Owner grant commit contains tracked capability state" ($LASTEXITCODE -eq 0 -and $grantStateText.Count -gt 0)
    try { $grantState = ($grantStateText -join "`n") | ConvertFrom-Json }
    catch { throw "Worker deploy precondition failed: Owner grant capability state is not valid JSON" }
    $grantGate = $grantState.gates.live_mcp_writes
    Assert-True "Owner grant commit authorizes the exact selected MCP scope" (
      $grantState.contract_version -ceq "capability-gate-state-v1" -and
      $grantGate.owner_granted -is [bool] -and
      $grantGate.owner_granted -eq $true -and
      $grantGate.owner_grant_ref -is [string] -and
      ([string]$grantGate.owner_grant_ref).Trim() -ceq $mcpOwnerGrantRef
    )

    $rubricPath = "docs/runtime-contracts/layer-credit-rubric.md"
    $approvedRubric = (& git show "$LayerCreditRubricApprovalSha`:$rubricPath" 2>$null | Out-String)
    Assert-True "approved layer rubric is present at the named approval commit" ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($approvedRubric))
    Assert-True "named layer rubric commit is explicitly Owner-approved" (
      $approvedRubric -match '(?m)^Status:\s*`APPROVED`\s*$' -and
      $approvedRubric -match '(?m)^Credit-Anwendung erlaubt:\s*`true`\s*$'
    )
    foreach ($verifierName in @(
      "verify-mcp-hosted-write.ps1",
      "verify-mcp-hosted-auth-scope.ps1",
      "verify-mcp-hosted-timeout-idempotency.ps1",
      "verify-mcp-hosted-audit-readback-rollback.ps1",
      "verify-mcp-candidate-sbom.ps1"
    )) {
      Assert-True "approved layer rubric names every hosted MCP verifier" ($approvedRubric.Contains($verifierName))
    }
    $approvalRubricBlob = (& git rev-parse "$LayerCreditRubricApprovalSha`:$rubricPath" 2>$null).Trim()
    $candidateRubricBlob = (& git rev-parse "$resolved`:$rubricPath" 2>$null).Trim()
    Assert-True "candidate uses the exact approved layer rubric blob" (
      $LASTEXITCODE -eq 0 -and $approvalRubricBlob -match "^[0-9a-f]{40}$" -and $approvalRubricBlob -ceq $candidateRubricBlob
    )

    $mcpVerifierPaths = @(
      "scripts/verify-mcp-hosted-write.ps1",
      "scripts/verify-mcp-hosted-auth-scope.ps1",
      "scripts/verify-mcp-hosted-timeout-idempotency.ps1",
      "scripts/verify-mcp-hosted-audit-readback-rollback.ps1",
      "scripts/verify-mcp-candidate-sbom.ps1"
    )
    $mcpVerifierDigests = @{}
    foreach ($verifierPath in $mcpVerifierPaths) {
      $mcpVerifierDigests[$verifierPath] = Get-GitBlobSha256 $repoRoot "$resolved`:$verifierPath"
    }
    $mcpVerifierManifestSha = Get-ManifestSha256 $mcpVerifierDigests
    $mcpRuntimeBlobSha = Get-GitBlobSha256 $repoRoot "$resolved`:services/cloudflare-stateful-runtime/src/mcp-hosted.js"
    $mcpRubricBlobSha = Get-GitBlobSha256 $repoRoot "$resolved`:$rubricPath"
    $mcpCapabilityGateBlobSha = Get-GitBlobSha256 $repoRoot "$resolved`:$capabilityStatePath"
    foreach ($digest in @($mcpVerifierManifestSha, $mcpRuntimeBlobSha, $mcpRubricBlobSha, $mcpCapabilityGateBlobSha)) {
      Assert-True "hosted MCP immutable blob SHA-256 is valid" ($digest -match "^[0-9a-f]{64}$")
    }
    $mcpBindingArgs = @(
      "--var", "HOSTED_MCP_WRITE_AUTHORIZED:true",
      "--var", "LIVE_MCP_WRITES_ENABLED:true",
      "--var", "HOSTED_MCP_WRITE_OWNER_GRANT_REF:$mcpOwnerGrantRef",
      "--var", "HOSTED_MCP_WRITE_OWNER_GRANT_COMMIT_SHA:$HostedMcpOwnerGrantCommitSha",
      "--var", "LAYER_CREDIT_RUBRIC_APPROVAL_SHA:$LayerCreditRubricApprovalSha",
      "--var", "HOSTED_MCP_WRITE_BRANCH:$CandidateBranch",
      "--var", "HOSTED_MCP_VERIFIER_BLOB_SHA256:$mcpVerifierManifestSha",
      "--var", "HOSTED_MCP_RUNTIME_BLOB_SHA256:$mcpRuntimeBlobSha",
      "--var", "HOSTED_MCP_RUBRIC_BLOB_SHA256:$mcpRubricBlobSha",
      "--var", "HOSTED_MCP_CAPABILITY_GATE_BLOB_SHA256:$mcpCapabilityGateBlobSha"
    )
  }

  $workerDiff = & git diff --name-only $resolved -- services/cloudflare-stateful-runtime
  Assert-True "worker tracked-diff scan completed" ($LASTEXITCODE -eq 0)
  Assert-True "worker tree matches the deployed commit" ([string]::IsNullOrWhiteSpace(($workerDiff -join "")))

  $untrackedWorkerEntries = @(& git ls-files --others --exclude-standard -- services/cloudflare-stateful-runtime)
  Assert-True "worker untracked-file scan completed" ($LASTEXITCODE -eq 0)
  Assert-True "worker tree has no untracked files" ($untrackedWorkerEntries.Count -eq 0)

  $ignoredWorkerEntries = @(& git ls-files --others --ignored --exclude-standard --directory -- services/cloudflare-stateful-runtime)
  Assert-True "worker ignored-file scan completed" ($LASTEXITCODE -eq 0)
  $allowedIgnoredWorkerRoots = @(
    "services/cloudflare-stateful-runtime/node_modules/",
    "services/cloudflare-stateful-runtime/.wrangler/"
  )
  $runtimeRelevantIgnoredEntries = @(
    $ignoredWorkerEntries | Where-Object { $allowedIgnoredWorkerRoots -notcontains ([string]$_).Replace("\", "/") }
  )
  Assert-True "worker tree has no runtime-relevant ignored files" ($runtimeRelevantIgnoredEntries.Count -eq 0)

  foreach ($pinnedPath in @(
    "services/cloudflare-stateful-runtime/package.json",
    "services/cloudflare-stateful-runtime/package-lock.json"
  )) {
    $null = & git cat-file -e "$resolved`:$pinnedPath" 2>$null
    Assert-True "selected commit contains pinned Worker package metadata" ($LASTEXITCODE -eq 0)
  }

  $trackedPackageLockText = @(& git show "$resolved`:services/cloudflare-stateful-runtime/package-lock.json" 2>$null)
  Assert-True "selected commit package lock loaded" ($LASTEXITCODE -eq 0 -and $trackedPackageLockText.Count -gt 0)
  try {
    # npm lockfiles legitimately contain the empty-string root package key. PowerShell 7
    # rejects that JSON as a PSCustomObject, so parse it as an exact hashtable instead.
    $trackedPackageLock = ($trackedPackageLockText -join "`n") | ConvertFrom-Json -AsHashtable
  } catch {
    throw "Worker deploy precondition failed: selected commit package lock is not valid JSON"
  }
  $lockPackages = $trackedPackageLock["packages"]
  $lockedWrangler = if ($lockPackages -is [System.Collections.IDictionary]) {
    $lockPackages["node_modules/wrangler"]
  } else { $null }
  $lockedWranglerVersion = if ($lockedWrangler -is [System.Collections.IDictionary]) {
    [string]$lockedWrangler["version"]
  } else { "" }
  Assert-True "selected package lock pins Wrangler" (
    $lockedWranglerVersion -match "^[0-9]+\.[0-9]+\.[0-9]+$"
  )
  $materializationRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    "cloud-superbrain-worker-deploy-" + [Guid]::NewGuid().ToString("N")
  )
  $materializedWorkerDir = Join-Path $materializationRoot "worker"
  $workerArchive = Join-Path $materializationRoot "worker-source.tar"
  New-Item -ItemType Directory -Path $materializedWorkerDir -Force | Out-Null
  try {
    & git archive --format=tar "--output=$workerArchive" $resolved -- services/cloudflare-stateful-runtime
    Assert-True "selected Worker source archive created" ($LASTEXITCODE -eq 0)
    $null = & tar -xf $workerArchive -C $materializedWorkerDir --strip-components=2 2>&1
    Assert-True "selected Worker source archive materialized" ($LASTEXITCODE -eq 0)
    foreach ($requiredMaterializedPath in @("package.json", "package-lock.json", "wrangler.jsonc", "src/index.js")) {
      Assert-True "selected Worker materialization contains required source" (
        Test-Path -LiteralPath (Join-Path $materializedWorkerDir $requiredMaterializedPath) -PathType Leaf
      )
    }
    if ($ValidateOnly) {
      Write-Host "[worker-deploy] validation complete; nothing was published"
      return
    }

    Push-Location $materializedWorkerDir
    try {
      $null = & npm ci --ignore-scripts --prefer-offline --no-audit --no-fund 2>&1
      $npmCiExitCode = $LASTEXITCODE
    } finally { Pop-Location }
    Assert-True "fresh dependency tree installed from the selected integrity-pinned lock" ($npmCiExitCode -eq 0)
    $wrangler = Join-Path $materializedWorkerDir "node_modules/wrangler/bin/wrangler.js"
    Assert-True "materialized Wrangler present" (Test-Path -LiteralPath $wrangler -PathType Leaf)
    $installedWranglerVersion = ((& node $wrangler --version 2>$null) -join "").Trim()
    Assert-True "materialized Wrangler matches the selected pinned lock" (
      $LASTEXITCODE -eq 0 -and
      $installedWranglerVersion -ceq $lockedWranglerVersion
    )

    $bindingArgs = @(
      "--var", "RUNTIME_MODE:cloudflare_native_hosted_candidate",
      "--var", "CONTRACT_ORIGIN:$candidateFrontendOriginCanonical",
      "--var", "OAUTH_PUBLIC_ORIGIN:$candidateFrontendOriginCanonical",
      "--var", "GITHUB_OAUTH_REDIRECT_URI:$candidateOAuthCallback",
      "--var", "GITHUB_OAUTH_CLIENT_ID:$oauthClientId",
      "--var", "GITHUB_OAUTH_OWNER_IDS:$oauthOwnerIds",
      "--var", "POST_LOGIN_REDIRECT:$postLoginRedirect",
      "--var", "MEMORY_EMBEDDING_MODEL:$memoryEmbeddingModel",
      "--var", "SOURCE_COMMIT_SHA:$resolved",
      "--var", "SOURCE_ARCHIVE_SHA256:$archiveSha",
      "--var", "PRODUCTION_AUTH_OWNER_GRANTED:false"
    )
    if ($bindProductionAuthOwnerGrant) {
      $bindingArgs[-1] = "PRODUCTION_AUTH_OWNER_GRANTED:true"
      $bindingArgs += @("--var", "PRODUCTION_AUTH_OWNER_GRANT_REF:$ownerGrantRef")
    }
    $bindingArgs += @(
      "--var", "HOSTED_MCP_DEPLOYMENT_ENVIRONMENT:$hostedMcpDeploymentEnvironment",
      "--var", "HOSTED_MCP_PREVIEW_HOSTNAME:$previewWorkerHostname"
    )
    $bindingArgs += $mcpBindingArgs

    # Wrangler's --outfile is the complete multipart upload body, not a
    # JavaScript entrypoint.  Hash and re-upload the deterministic entrypoint
    # emitted by --outdir instead; otherwise --no-bundle tries to parse MIME
    # headers as JavaScript.
    $preflightOutputDir = Join-Path $materializationRoot "preflight-output"
    $preflightBundleFile = Join-Path $preflightOutputDir "index.js"
    $preflightMetafile = Join-Path $materializationRoot "bundle-preflight-meta.json"
    $preflightArgs = @(
      $wrangler, "deploy", "--env", "preview"
    ) + $bindingArgs + @(
      "--dry-run",
      "--outdir", $preflightOutputDir,
      "--metafile", $preflightMetafile
    )
    Push-Location $materializedWorkerDir
    try {
      $null = & node @preflightArgs 2>&1
      $preflightExitCode = $LASTEXITCODE
    } finally { Pop-Location }
    Assert-True "selected-source Wrangler preflight exit code 0; command output suppressed" ($preflightExitCode -eq 0)
    $preflightScriptFiles = @(Get-ChildItem -LiteralPath $preflightOutputDir -File -Filter "*.js")
    Assert-True "selected-source Wrangler emitted exactly one JavaScript upload bundle" (
      $preflightScriptFiles.Count -eq 1 -and
      $preflightScriptFiles[0].FullName -ceq $preflightBundleFile
    )
    Assert-True "preflight bundle metafile created" (Test-Path -LiteralPath $preflightMetafile -PathType Leaf)
    try {
      $preflightMetadata = Get-Content -LiteralPath $preflightMetafile -Raw | ConvertFrom-Json
    } catch {
      throw "Worker deploy precondition failed: preflight bundle metafile is not valid JSON"
    }
    $preflightInputs = @($preflightMetadata.inputs.PSObject.Properties.Name)
    Assert-True "preflight bundle records source inputs" ($preflightInputs.Count -gt 0)
    $materializedRootFull = [System.IO.Path]::GetFullPath($materializedWorkerDir).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    $allInputsBounded = $true
    foreach ($inputName in $preflightInputs) {
      $inputFull = if ([System.IO.Path]::IsPathRooted([string]$inputName)) {
        [System.IO.Path]::GetFullPath([string]$inputName)
      } else {
        [System.IO.Path]::GetFullPath((Join-Path $materializedWorkerDir ([string]$inputName)))
      }
      $insideMaterialization = $inputFull.StartsWith(
        $materializedRootFull + [System.IO.Path]::DirectorySeparatorChar,
        [System.StringComparison]::OrdinalIgnoreCase
      )
      if (-not $insideMaterialization) {
        $allInputsBounded = $false
        break
      }
    }
    Assert-True "preflight bundle inputs are confined to the selected source materialization" $allInputsBounded
    $sourceBundleSha = (Get-FileHash -LiteralPath $preflightBundleFile -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-True "exact upload bundle SHA-256 computed" ($sourceBundleSha -match "^[0-9a-f]{64}$")

    if ($DryRun) {
      Write-Host "[worker-deploy] dry-run complete; nothing was published"
      return
    }

    $materializedWranglerConfigPath = Join-Path $materializedWorkerDir "wrangler.jsonc"
    $deployArgs = @(
      $wrangler, "deploy", $preflightBundleFile,
      "--no-bundle", "--config", $materializedWranglerConfigPath,
      "--env", "preview"
    ) + $bindingArgs + @(
      "--var", "SOURCE_BUNDLE_SHA256:$sourceBundleSha"
    )
    Push-Location $materializedWorkerDir
    try {
      $null = & node @deployArgs 2>&1
      $wranglerExitCode = $LASTEXITCODE
      Assert-True "wrangler deploy exit code 0; command output suppressed" ($wranglerExitCode -eq 0)
    } finally { Pop-Location }

    $health = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 30 `
      -Uri $previewWorkerHealthUrl).Content | ConvertFrom-Json
    Assert-True "preview source_commit_sha rebound"    ([string]$health.source_commit_sha    -eq $resolved)
    Assert-True "preview source_archive_sha256 rebound" ([string]$health.source_archive_sha256 -eq $archiveSha)
    Assert-True "preview source_bundle_sha256 rebound" ([string]$health.source_bundle_sha256 -eq $sourceBundleSha)
    Assert-True "preview runtime mode rebound" ([string]$health.mode -ceq "cloudflare_native_hosted_candidate")
    $mcpHealth = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 30 `
      -Uri $previewWorkerMcpHealthUrl).Content | ConvertFrom-Json
    Assert-True "preview MCP health reports healthy" (
      [string]$mcpHealth.contract_version -ceq "mcp-hosted-health-v1" -and
      [string]$mcpHealth.status -ceq "healthy" -and
      [string]$mcpHealth.service -ceq "mcp-gateway"
    )
    Assert-True "preview MCP health source_commit_sha rebound" ([string]$mcpHealth.source_commit_sha -ceq $resolved)
    Assert-True "preview MCP health source_archive_sha256 rebound" ([string]$mcpHealth.source_archive_sha256 -ceq $archiveSha)
    Assert-True "preview MCP health source_bundle_sha256 rebound" ([string]$mcpHealth.source_bundle_sha256 -ceq $sourceBundleSha)
    Assert-True "preview MCP health D1 read verified" (
      $mcpHealth.d1_binding_configured -is [bool] -and $mcpHealth.d1_binding_configured -and
      $mcpHealth.d1_read_verified -is [bool] -and $mcpHealth.d1_read_verified -and
      $mcpHealth.persisted -is [bool] -and $mcpHealth.persisted
    )
    Assert-True "preview MCP health is non-mutating" (
      $mcpHealth.provider_writes -is [bool] -and -not $mcpHealth.provider_writes -and
      $mcpHealth.live_mcp_writes -is [bool] -and -not $mcpHealth.live_mcp_writes -and
      $mcpHealth.live_provider_calls -is [bool] -and -not $mcpHealth.live_provider_calls -and
      $mcpHealth.production_deploy -is [bool] -and -not $mcpHealth.production_deploy -and
      $mcpHealth.secret_output -is [bool] -and -not $mcpHealth.secret_output
    )
    Write-Host "[worker-deploy] preview commit, archive, exact uploaded bundle, runtime mode, and MCP health binding verified"
  } finally {
    Remove-TransientMaterialization $materializationRoot
  }
} finally { Pop-Location }

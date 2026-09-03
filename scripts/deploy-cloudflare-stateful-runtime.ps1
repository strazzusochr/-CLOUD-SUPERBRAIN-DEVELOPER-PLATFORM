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
  [switch]$DeployLlmGateway,
  [switch]$Phase6Production,
  [string]$Phase6ControlCommitSha = "",
  [switch]$Phase6PreviewLoopGuard,
  [switch]$UseCandidateCloudflareToken
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

function Assert-ExactPropertyNames(
  [object]$Value,
  [string[]]$ExpectedNames,
  [string]$Label
) {
  Assert-True "$Label is present" ($null -ne $Value)
  $actualNames = @($Value.PSObject.Properties.Name | Sort-Object -CaseSensitive)
  $expectedSorted = @($ExpectedNames | Sort-Object -CaseSensitive)
  $namesAreExact = $actualNames.Count -eq $expectedSorted.Count
  if ($namesAreExact) {
    for ($index = 0; $index -lt $actualNames.Count; $index++) {
      if ([string]$actualNames[$index] -cne [string]$expectedSorted[$index]) {
        $namesAreExact = $false
        break
      }
    }
  }
  Assert-True "$Label has exactly the approved fields" $namesAreExact
}

function Assert-Phase6WranglerConfigShape([object]$Config) {
  Assert-ExactPropertyNames $Config @(
    '$schema',
    'name',
    'main',
    'compatibility_date',
    'workers_dev',
    'observability',
    'migrations',
    'durable_objects',
    'queues',
    'd1_databases',
    'vectorize',
    'ai',
    'vars',
    'env'
  ) "phase6 top-level wrangler config"
  Assert-ExactPropertyNames $Config.observability @('enabled', 'head_sampling_rate') `
    "phase6 top-level observability config"
  Assert-True "phase6 top-level migration count is exact" (@($Config.migrations).Count -eq 1)
  Assert-ExactPropertyNames $Config.migrations[0] @('tag', 'new_sqlite_classes') `
    "phase6 top-level migration"
  Assert-ExactPropertyNames $Config.durable_objects @('bindings') `
    "phase6 top-level Durable Object container"
  Assert-True "phase6 top-level Durable Object count is exact" (
    @($Config.durable_objects.bindings).Count -eq 1
  )
  Assert-ExactPropertyNames $Config.durable_objects.bindings[0] @('name', 'class_name') `
    "phase6 top-level Durable Object binding"
  Assert-ExactPropertyNames $Config.queues @('producers', 'consumers') `
    "phase6 top-level queue container"
  Assert-True "phase6 top-level queue counts are exact" (
    @($Config.queues.producers).Count -eq 1 -and @($Config.queues.consumers).Count -eq 1
  )
  Assert-ExactPropertyNames $Config.queues.producers[0] @('binding', 'queue') `
    "phase6 top-level queue producer"
  Assert-ExactPropertyNames $Config.queues.consumers[0] @(
    'queue', 'max_batch_size', 'max_batch_timeout', 'max_retries'
  ) "phase6 top-level queue consumer"
  Assert-True "phase6 top-level D1 count is exact" (@($Config.d1_databases).Count -eq 1)
  Assert-ExactPropertyNames $Config.d1_databases[0] @(
    'binding', 'database_name', 'database_id', 'migrations_dir'
  ) "phase6 top-level D1 binding"
  Assert-True "phase6 top-level Vectorize count is exact" (@($Config.vectorize).Count -eq 1)
  Assert-ExactPropertyNames $Config.vectorize[0] @('binding', 'index_name') `
    "phase6 top-level Vectorize binding"
  Assert-ExactPropertyNames $Config.ai @('binding') "phase6 top-level Workers AI binding"
  Assert-ExactPropertyNames $Config.vars @(
    'RUNTIME_MODE',
    'CONTRACT_ORIGIN',
    'MEMORY_EMBEDDING_MODEL',
    'GITHUB_OAUTH_CLIENT_ID',
    'OAUTH_PUBLIC_ORIGIN',
    'GITHUB_OAUTH_REDIRECT_URI',
    'GITHUB_OAUTH_OWNER_IDS',
    'POST_LOGIN_REDIRECT'
  ) "phase6 top-level public vars"
  Assert-ExactPropertyNames $Config.env @('preview') "phase6 environment map"

  $preview = $Config.env.preview
  Assert-ExactPropertyNames $preview @(
    'name',
    'workers_dev',
    'durable_objects',
    'queues',
    'd1_databases',
    'vectorize',
    'ai',
    'vars'
  ) "phase6 preview wrangler config"
  Assert-ExactPropertyNames $preview.durable_objects @('bindings') `
    "phase6 preview Durable Object container"
  Assert-True "phase6 preview Durable Object count is exact" (
    @($preview.durable_objects.bindings).Count -eq 1
  )
  Assert-ExactPropertyNames $preview.durable_objects.bindings[0] @('name', 'class_name') `
    "phase6 preview Durable Object binding"
  Assert-ExactPropertyNames $preview.queues @('producers', 'consumers') `
    "phase6 preview queue container"
  Assert-True "phase6 preview queue counts are exact" (
    @($preview.queues.producers).Count -eq 1 -and @($preview.queues.consumers).Count -eq 1
  )
  Assert-ExactPropertyNames $preview.queues.producers[0] @('binding', 'queue') `
    "phase6 preview queue producer"
  Assert-ExactPropertyNames $preview.queues.consumers[0] @(
    'queue', 'max_batch_size', 'max_batch_timeout', 'max_retries'
  ) "phase6 preview queue consumer"
  Assert-True "phase6 preview D1 count is exact" (@($preview.d1_databases).Count -eq 1)
  Assert-ExactPropertyNames $preview.d1_databases[0] @(
    'binding', 'database_name', 'migrations_dir'
  ) "phase6 preview D1 binding"
  Assert-True "phase6 preview Vectorize count is exact" (@($preview.vectorize).Count -eq 1)
  Assert-ExactPropertyNames $preview.vectorize[0] @('binding', 'index_name') `
    "phase6 preview Vectorize binding"
  Assert-ExactPropertyNames $preview.ai @('binding') "phase6 preview Workers AI binding"
  Assert-ExactPropertyNames $preview.vars @('RUNTIME_MODE', 'MEMORY_EMBEDDING_MODEL') `
    "phase6 preview public vars"
}

function Get-CandidateCloudflareCredentialSet(
  [string]$Path = "C:\Users\immer\.codex\secrets\cloud-superbrain.local.env",
  [switch]$AllowTestPath
) {
  $fixedPath = "C:\Users\immer\.codex\secrets\cloud-superbrain.local.env"
  $resolvedFixedPath = [System.IO.Path]::GetFullPath($fixedPath)
  $resolvedRequestedPath = [System.IO.Path]::GetFullPath($Path)
  Assert-True "candidate Cloudflare token path is the fixed private path or an explicit test path" (
    $AllowTestPath.IsPresent -or
    $resolvedRequestedPath.Equals($resolvedFixedPath, [System.StringComparison]::OrdinalIgnoreCase)
  )
  Assert-True "candidate Cloudflare token file exists" (
    Test-Path -LiteralPath $resolvedRequestedPath -PathType Leaf
  )
  $tokenFile = Get-Item -LiteralPath $resolvedRequestedPath -Force
  Assert-True "candidate Cloudflare token file is bounded and not a reparse point" (
    $tokenFile.Length -gt 0 -and
    $tokenFile.Length -le 65536 -and
    ($tokenFile.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0
  )
  $tokenFileText = [System.IO.File]::ReadAllText($resolvedRequestedPath)
  if ($tokenFileText.StartsWith([string][char]0xFEFF, [System.StringComparison]::Ordinal)) {
    $tokenFileText = $tokenFileText.Substring(1)
  }
  Assert-True "candidate Cloudflare token file contains no NUL byte" (-not $tokenFileText.Contains([char]0))
  $cloudflareAssignments = @{
    CLOUDFLARE_ACCOUNT_ID = @()
    CLOUDFLARE_API_TOKEN = @()
    CLOUDFLARE_API_TOKEN_CANDIDATE = @()
  }
  foreach ($line in ($tokenFileText -split "`r?`n")) {
    $trimmedLine = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmedLine) -or $trimmedLine.StartsWith("#")) { continue }
    $assignmentMatch = [regex]::Match(
      $trimmedLine,
      "^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$",
      [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    if (-not $assignmentMatch.Success) {
      Assert-True "candidate Cloudflare token assignment syntax is valid" (
        -not $trimmedLine.StartsWith(
          "CLOUDFLARE_API_TOKEN_CANDIDATE",
          [System.StringComparison]::Ordinal
        )
      )
      continue
    }
    $assignmentName = $assignmentMatch.Groups[1].Value
    if ($cloudflareAssignments.ContainsKey($assignmentName)) {
      $cloudflareAssignments[$assignmentName] += $assignmentMatch.Groups[2].Value
    }
  }
  Assert-True "candidate Cloudflare token file has exactly one account assignment" (
    @($cloudflareAssignments.CLOUDFLARE_ACCOUNT_ID).Count -eq 1
  )
  Assert-True "candidate Cloudflare token file has exactly one active token assignment" (
    @($cloudflareAssignments.CLOUDFLARE_API_TOKEN).Count -eq 1
  )
  Assert-True "candidate Cloudflare token file has exactly one candidate token assignment" (
    @($cloudflareAssignments.CLOUDFLARE_API_TOKEN_CANDIDATE).Count -eq 1
  )

  $normalizedValues = @{}
  foreach ($assignmentName in $cloudflareAssignments.Keys) {
    $assignmentValue = ([string]$cloudflareAssignments[$assignmentName][0]).Trim()
    if (
      $assignmentValue.Length -ge 2 -and
      (($assignmentValue.StartsWith('"') -and $assignmentValue.EndsWith('"')) -or
        ($assignmentValue.StartsWith("'") -and $assignmentValue.EndsWith("'")))
    ) {
      $assignmentValue = $assignmentValue.Substring(1, $assignmentValue.Length - 2)
    }
    $normalizedValues[$assignmentName] = $assignmentValue
  }
  Assert-True "candidate Cloudflare account ID has an exact lowercase shape" (
    [string]$normalizedValues.CLOUDFLARE_ACCOUNT_ID -cmatch "^[0-9a-f]{32}$"
  )
  Assert-True "active Cloudflare token has a bounded token-only shape" (
    [string]$normalizedValues.CLOUDFLARE_API_TOKEN -cmatch "^[A-Za-z0-9_-]{32,256}$"
  )
  Assert-True "candidate Cloudflare token has a bounded token-only shape" (
    [string]$normalizedValues.CLOUDFLARE_API_TOKEN_CANDIDATE -cmatch "^[A-Za-z0-9_-]{32,256}$"
  )
  Assert-True "candidate Cloudflare token is distinct from the active token" (
    [string]$normalizedValues.CLOUDFLARE_API_TOKEN_CANDIDATE -cne
      [string]$normalizedValues.CLOUDFLARE_API_TOKEN
  )
  return [pscustomobject]@{
    AccountId = [string]$normalizedValues.CLOUDFLARE_ACCOUNT_ID
    ActiveToken = [string]$normalizedValues.CLOUDFLARE_API_TOKEN
    CandidateToken = [string]$normalizedValues.CLOUDFLARE_API_TOKEN_CANDIDATE
  }
}

function Clear-CandidateCloudflareCredentialSet([object]$Credentials) {
  if ($null -eq $Credentials) { return }
  foreach ($propertyName in @("AccountId", "ActiveToken", "CandidateToken")) {
    $property = $Credentials.PSObject.Properties[$propertyName]
    if ($null -ne $property) { $property.Value = $null }
  }
}

function Invoke-CandidateWranglerChild(
  [string]$WranglerPath,
  [string[]]$Arguments,
  [object]$Credentials,
  [string]$WorkingDirectory,
  [string]$Label
) {
  Assert-True "$Label uses loaded candidate Cloudflare credentials" (
    $null -ne $Credentials -and
    [string]$Credentials.AccountId -cmatch "^[0-9a-f]{32}$" -and
    [string]$Credentials.CandidateToken -cmatch "^[A-Za-z0-9_-]{32,256}$"
  )
  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = "node"
  $startInfo.WorkingDirectory = $WorkingDirectory
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  [void]$startInfo.ArgumentList.Add($WranglerPath)
  foreach ($argument in $Arguments) { [void]$startInfo.ArgumentList.Add($argument) }
  $startInfo.Environment["CLOUDFLARE_API_TOKEN"] = [string]$Credentials.CandidateToken
  $startInfo.Environment["CLOUDFLARE_ACCOUNT_ID"] = [string]$Credentials.AccountId
  [void]$startInfo.Environment.Remove("CLOUDFLARE_API_TOKEN_CANDIDATE")
  [void]$startInfo.Environment.Remove("CLOUDFLARE_API_KEY")
  [void]$startInfo.Environment.Remove("CLOUDFLARE_EMAIL")

  $process = [System.Diagnostics.Process]::Start($startInfo)
  $stdoutTask = $process.StandardOutput.ReadToEndAsync()
  $stderrTask = $process.StandardError.ReadToEndAsync()
  $process.WaitForExit()
  $stdout = $stdoutTask.GetAwaiter().GetResult()
  $stderr = $stderrTask.GetAwaiter().GetResult()
  $exitCode = $process.ExitCode
  $process.Dispose()
  Assert-True "$Label stdout is bounded" ($stdout.Length -le 1048576)
  Assert-True "$Label stderr is bounded and suppressed" ($stderr.Length -le 1048576)
  Assert-True "$Label emitted no Cloudflare token material" (
    -not $stdout.Contains([string]$Credentials.CandidateToken) -and
    -not $stderr.Contains([string]$Credentials.CandidateToken) -and
    -not $stdout.Contains([string]$Credentials.ActiveToken) -and
    -not $stderr.Contains([string]$Credentials.ActiveToken)
  )
  $stderr = $null
  return [pscustomobject]@{
    ExitCode = $exitCode
    Stdout = $stdout
  }
}

function Invoke-ScrubbedWranglerChild(
  [string]$WranglerPath,
  [string[]]$Arguments,
  [string]$WorkingDirectory,
  [string]$Label
) {
  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = "node"
  $startInfo.WorkingDirectory = $WorkingDirectory
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  [void]$startInfo.ArgumentList.Add($WranglerPath)
  foreach ($argument in $Arguments) { [void]$startInfo.ArgumentList.Add($argument) }

  # Phase-6 may use the active scoped API token inherited from the caller, but it
  # must never fall back to deprecated global-key/email authentication or consume
  # the staged candidate value outside the explicit candidate-token path.
  [void]$startInfo.Environment.Remove("CLOUDFLARE_API_TOKEN_CANDIDATE")
  [void]$startInfo.Environment.Remove("CLOUDFLARE_API_KEY")
  [void]$startInfo.Environment.Remove("CLOUDFLARE_EMAIL")

  $process = [System.Diagnostics.Process]::Start($startInfo)
  $stdoutTask = $process.StandardOutput.ReadToEndAsync()
  $stderrTask = $process.StandardError.ReadToEndAsync()
  $process.WaitForExit()
  $stdout = $stdoutTask.GetAwaiter().GetResult()
  $stderr = $stderrTask.GetAwaiter().GetResult()
  $exitCode = $process.ExitCode
  $process.Dispose()
  Assert-True "$Label stdout is bounded" ($stdout.Length -le 1048576)
  Assert-True "$Label stderr is bounded and suppressed" ($stderr.Length -le 1048576)
  return [pscustomobject]@{
    ExitCode = $exitCode
    Stdout = $stdout
  }
}

function Invoke-Phase6PreviewLoopGuardDeploy(
  [string]$RepositoryRoot,
  [string]$SelectedSourceCommit,
  [bool]$IsDryRun,
  [bool]$IsValidateOnly,
  [object]$CandidateCloudflareCredentials
) {
  $relativeWorkerRoot = "services/cloudflare-stateful-runtime"
  $repositoryConfigPath = Join-Path $RepositoryRoot "$relativeWorkerRoot/wrangler.jsonc"
  $loopGuardCommit = "c24b7bfddc37cfa0c16d1ebc7f70829417ac4080"
  $productionWorkerName = "cloud-superbrain-stateful-runtime"
  $previewWorkerName = "cloud-superbrain-stateful-runtime-preview"
  $previewDatabaseName = "cloud-superbrain-state-preview"
  $previewQueueName = "cloud-superbrain-runtime-candidate-preview"
  $previewBaseUrl = "https://cloud-superbrain-stateful-runtime-preview.strazzusochr.workers.dev"

  Assert-True "phase6 preview loop-guard source SHA is an explicit lowercase commit" (
    $SelectedSourceCommit -cmatch "^[0-9a-f]{40}$"
  )
  $resolvedSource = (& git rev-parse --verify "$SelectedSourceCommit^{commit}" 2>$null).Trim()
  Assert-True "phase6 preview loop-guard source commit resolved exactly" (
    $LASTEXITCODE -eq 0 -and $resolvedSource -ceq $SelectedSourceCommit
  )
  & git merge-base --is-ancestor $loopGuardCommit $resolvedSource 2>$null
  Assert-True "phase6 preview loop-guard source contains the cross-origin bounce-loop fix" (
    $LASTEXITCODE -eq 0
  )

  $workerDiff = @(& git diff --name-only $resolvedSource -- $relativeWorkerRoot)
  Assert-True "phase6 preview loop-guard Worker tracked-diff scan completed" ($LASTEXITCODE -eq 0)
  Assert-True "phase6 preview loop-guard Worker tree matches the source commit" ($workerDiff.Count -eq 0)
  $untrackedWorkerEntries = @(& git ls-files --others --exclude-standard -- $relativeWorkerRoot)
  Assert-True "phase6 preview loop-guard Worker untracked-file scan completed" ($LASTEXITCODE -eq 0)
  Assert-True "phase6 preview loop-guard Worker tree has no untracked files" (
    $untrackedWorkerEntries.Count -eq 0
  )
  $ignoredWorkerEntries = @(
    & git ls-files --others --ignored --exclude-standard --directory -- $relativeWorkerRoot
  )
  Assert-True "phase6 preview loop-guard Worker ignored-file scan completed" ($LASTEXITCODE -eq 0)
  $allowedIgnoredWorkerRoots = @(
    "services/cloudflare-stateful-runtime/node_modules/",
    "services/cloudflare-stateful-runtime/.wrangler/"
  )
  $runtimeRelevantIgnoredEntries = @(
    $ignoredWorkerEntries |
      Where-Object { $allowedIgnoredWorkerRoots -notcontains ([string]$_).Replace("\", "/") }
  )
  Assert-True "phase6 preview loop-guard Worker tree has no runtime-relevant ignored files" (
    $runtimeRelevantIgnoredEntries.Count -eq 0
  )

  Assert-True "phase6 preview loop-guard repository wrangler config exists" (
    Test-Path -LiteralPath $repositoryConfigPath -PathType Leaf
  )
  $repositoryConfigShaBefore = (
    Get-FileHash -LiteralPath $repositoryConfigPath -Algorithm SHA256
  ).Hash.ToLowerInvariant()
  $archiveSha = Get-GitArchiveSha256 $RepositoryRoot $resolvedSource
  Assert-True "phase6 preview loop-guard source archive SHA-256 computed" (
    $archiveSha -match "^[0-9a-f]{64}$"
  )

  $materializationRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    "cloud-superbrain-worker-deploy-" + [Guid]::NewGuid().ToString("N")
  )
  $materializedWorkerDir = Join-Path $materializationRoot "worker"
  $workerArchive = Join-Path $materializationRoot "worker-source.tar"
  $deployResult = $null
  New-Item -ItemType Directory -Path $materializedWorkerDir -Force | Out-Null
  try {
    & git archive --format=tar "--output=$workerArchive" $resolvedSource -- $relativeWorkerRoot
    Assert-True "phase6 preview loop-guard selected Worker source archive created" ($LASTEXITCODE -eq 0)
    $null = & tar -xf $workerArchive -C $materializedWorkerDir --strip-components=2 2>&1
    Assert-True "phase6 preview loop-guard selected Worker source materialized" ($LASTEXITCODE -eq 0)
    foreach ($requiredPath in @("package.json", "package-lock.json", "wrangler.jsonc", "src/index.js")) {
      Assert-True "phase6 preview loop-guard materialization contains $requiredPath" (
        Test-Path -LiteralPath (Join-Path $materializedWorkerDir $requiredPath) -PathType Leaf
      )
    }

    $materializedConfigPath = Join-Path $materializedWorkerDir "wrangler.jsonc"
    try {
      $config = Get-Content -LiteralPath $materializedConfigPath -Raw | ConvertFrom-Json
    } catch {
      throw "Worker deploy precondition failed: phase6 preview loop-guard wrangler config is invalid"
    }
    Assert-Phase6WranglerConfigShape $config

    $preview = $config.env.preview
    Assert-True "phase6 preview loop-guard Worker binding is exact and isolated" (
      [string]$config.name -ceq $productionWorkerName -and
      [string]$config.main -ceq "src/index.js" -and
      $config.workers_dev -is [bool] -and $config.workers_dev -and
      [string]$preview.name -ceq $previewWorkerName -and
      [string]$preview.name -cne [string]$config.name -and
      $preview.workers_dev -is [bool] -and $preview.workers_dev
    )

    $productionDatabases = @($config.d1_databases)
    $previewDatabases = @($preview.d1_databases)
    Assert-True "phase6 preview loop-guard D1 declaration is exact and isolated" (
      $productionDatabases.Count -eq 1 -and
      [string]$productionDatabases[0].binding -ceq "DB" -and
      [string]$productionDatabases[0].database_name -ceq "cloud-superbrain-state-prod" -and
      [string]$productionDatabases[0].database_id -ceq "91520f43-5d38-4a31-9d5a-6fca890e1dd6" -and
      [string]$productionDatabases[0].migrations_dir -ceq "migrations" -and
      $previewDatabases.Count -eq 1 -and
      [string]$previewDatabases[0].binding -ceq "DB" -and
      [string]$previewDatabases[0].database_name -ceq $previewDatabaseName -and
      [string]$previewDatabases[0].database_name -cne [string]$productionDatabases[0].database_name -and
      [string]$previewDatabases[0].migrations_dir -ceq "migrations" -and
      $null -eq $previewDatabases[0].PSObject.Properties["database_id"]
    )

    $productionQueueProducers = @($config.queues.producers)
    $productionQueueConsumers = @($config.queues.consumers)
    $previewQueueProducers = @($preview.queues.producers)
    $previewQueueConsumers = @($preview.queues.consumers)
    Assert-True "phase6 preview loop-guard queue binding is exact and isolated" (
      $productionQueueProducers.Count -eq 1 -and
      [string]$productionQueueProducers[0].binding -ceq "RUNTIME_QUEUE" -and
      [string]$productionQueueProducers[0].queue -ceq "cloud-superbrain-runtime-candidate" -and
      $productionQueueConsumers.Count -eq 1 -and
      [string]$productionQueueConsumers[0].queue -ceq "cloud-superbrain-runtime-candidate" -and
      [int]$productionQueueConsumers[0].max_batch_size -eq 10 -and
      [int]$productionQueueConsumers[0].max_batch_timeout -eq 1 -and
      [int]$productionQueueConsumers[0].max_retries -eq 3 -and
      $previewQueueProducers.Count -eq 1 -and
      [string]$previewQueueProducers[0].binding -ceq "RUNTIME_QUEUE" -and
      [string]$previewQueueProducers[0].queue -ceq $previewQueueName -and
      [string]$previewQueueProducers[0].queue -cne [string]$productionQueueProducers[0].queue -and
      $previewQueueConsumers.Count -eq 1 -and
      [string]$previewQueueConsumers[0].queue -ceq $previewQueueName -and
      [int]$previewQueueConsumers[0].max_batch_size -eq 10 -and
      [int]$previewQueueConsumers[0].max_batch_timeout -eq 1 -and
      [int]$previewQueueConsumers[0].max_retries -eq 3
    )

    $productionDurableObjects = @($config.durable_objects.bindings)
    $previewDurableObjects = @($preview.durable_objects.bindings)
    Assert-True "phase6 preview loop-guard Durable Object binding is exact" (
      $productionDurableObjects.Count -eq 1 -and
      [string]$productionDurableObjects[0].name -ceq "RUNTIME_COORDINATOR" -and
      [string]$productionDurableObjects[0].class_name -ceq "RuntimeCoordinator" -and
      $previewDurableObjects.Count -eq 1 -and
      [string]$previewDurableObjects[0].name -ceq "RUNTIME_COORDINATOR" -and
      [string]$previewDurableObjects[0].class_name -ceq "RuntimeCoordinator"
    )
    $productionMigrations = @($config.migrations)
    Assert-True "phase6 preview loop-guard migration is exact" (
      $productionMigrations.Count -eq 1 -and
      [string]$productionMigrations[0].tag -ceq "v1-cloudflare-native-coordinator" -and
      @($productionMigrations[0].new_sqlite_classes).Count -eq 1 -and
      [string]$productionMigrations[0].new_sqlite_classes[0] -ceq "RuntimeCoordinator"
    )

    $productionVectorize = @($config.vectorize)
    $previewVectorize = @($preview.vectorize)
    Assert-True "phase6 preview loop-guard Vectorize binding is exact" (
      $productionVectorize.Count -eq 1 -and
      [string]$productionVectorize[0].binding -ceq "VECTORIZE" -and
      [string]$productionVectorize[0].index_name -ceq "cloud-superbrain-memory-v1" -and
      $previewVectorize.Count -eq 1 -and
      [string]$previewVectorize[0].binding -ceq "VECTORIZE" -and
      [string]$previewVectorize[0].index_name -ceq "cloud-superbrain-memory-v1"
    )
    Assert-True "phase6 preview loop-guard Workers AI binding is exact" (
      [string]$config.ai.binding -ceq "AI" -and
      [string]$preview.ai.binding -ceq "AI"
    )

    $previewVars = $preview.vars
    Assert-True "phase6 preview loop-guard public vars are exact" (
      (Get-PlainTextVar $previewVars "RUNTIME_MODE") -ceq "cloudflare_native_hosted_candidate" -and
      (Get-PlainTextVar $previewVars "MEMORY_EMBEDDING_MODEL") -ceq "@cf/baai/bge-base-en-v1.5"
    )
    foreach ($vars in @($config.vars, $previewVars)) {
      foreach ($forbiddenVarName in @(
        "GITHUB_OAUTH_CLIENT_SECRET",
        "JWT_SIGNING_SECRET",
        "AGENT_API_AUTH_TOKEN",
        "SOURCE_COMMIT_SHA",
        "SOURCE_ARCHIVE_SHA256",
        "SOURCE_BUNDLE_SHA256",
        "HOSTED_MCP_WRITE_AUTHORIZED",
        "LIVE_MCP_WRITES_ENABLED"
      )) {
        Assert-True "phase6 preview loop-guard source does not bind $forbiddenVarName" (
          $null -eq $vars.PSObject.Properties[$forbiddenVarName]
        )
      }
    }

    try {
      $trackedPackageLock = Get-Content -LiteralPath (Join-Path $materializedWorkerDir "package-lock.json") `
        -Raw | ConvertFrom-Json -AsHashtable
    } catch {
      throw "Worker deploy precondition failed: phase6 preview loop-guard package lock is invalid"
    }
    $lockedWrangler = $trackedPackageLock["packages"]["node_modules/wrangler"]
    $lockedWranglerVersion = if ($lockedWrangler -is [System.Collections.IDictionary]) {
      [string]$lockedWrangler["version"]
    } else { "" }
    Assert-True "phase6 preview loop-guard package lock pins Wrangler" (
      $lockedWranglerVersion -match "^[0-9]+\.[0-9]+\.[0-9]+$"
    )

    if ($IsValidateOnly) {
      Write-Host "[worker-deploy] phase6 preview loop-guard validation complete; nothing was published"
      return
    }

    Push-Location $materializedWorkerDir
    try {
      $null = & npm ci --ignore-scripts --prefer-offline --no-audit --no-fund 2>&1
      $npmCiExitCode = $LASTEXITCODE
    } finally { Pop-Location }
    Assert-True "phase6 preview loop-guard dependency tree installed from the selected lock" (
      $npmCiExitCode -eq 0
    )
    $wrangler = Join-Path $materializedWorkerDir "node_modules/wrangler/bin/wrangler.js"
    Assert-True "phase6 preview loop-guard materialized Wrangler is present" (
      Test-Path -LiteralPath $wrangler -PathType Leaf
    )
    $installedWranglerVersion = ((& node $wrangler --version 2>$null) -join "").Trim()
    Assert-True "phase6 preview loop-guard Wrangler matches the selected lock" (
      $LASTEXITCODE -eq 0 -and $installedWranglerVersion -ceq $lockedWranglerVersion
    )

    $d1ListArgs = @(
      "d1", "list",
      "--json",
      "--config", $materializedConfigPath
    )
    if ($null -ne $CandidateCloudflareCredentials) {
      $d1ListExecution = Invoke-CandidateWranglerChild `
        $wrangler $d1ListArgs $CandidateCloudflareCredentials $materializedWorkerDir `
        "phase6 preview loop-guard D1 list"
      $d1ListOutput = @($d1ListExecution.Stdout)
      $d1ListExitCode = [int]$d1ListExecution.ExitCode
      $d1ListExecution.Stdout = $null
    } else {
      $d1ListExecution = Invoke-ScrubbedWranglerChild `
        $wrangler $d1ListArgs $materializedWorkerDir `
        "phase6 preview loop-guard D1 list"
      $d1ListOutput = @($d1ListExecution.Stdout)
      $d1ListExitCode = [int]$d1ListExecution.ExitCode
      $d1ListExecution.Stdout = $null
    }
    Assert-True "phase6 preview loop-guard D1 list control-plane read exit code 0" (
      $d1ListExitCode -eq 0
    )
    $d1ListText = (($d1ListOutput | ForEach-Object { [string]$_ }) -join "`n").Trim()
    Assert-True "phase6 preview loop-guard D1 list output is bounded" (
      -not [string]::IsNullOrWhiteSpace($d1ListText) -and $d1ListText.Length -le 1048576
    )
    try {
      $d1Databases = @($d1ListText | ConvertFrom-Json)
    } catch {
      throw "Worker deploy precondition failed: phase6 preview loop-guard D1 list output is invalid JSON"
    }
    $matchingPreviewDatabases = @(
      $d1Databases | Where-Object { [string]$_.name -ceq $previewDatabaseName }
    )
    Assert-True "phase6 preview loop-guard resolves exactly one existing preview D1 database" (
      $matchingPreviewDatabases.Count -eq 1
    )
    $uuid = "[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}"
    $previewDatabaseId = if ($matchingPreviewDatabases[0].uuid -is [string]) {
      ([string]$matchingPreviewDatabases[0].uuid).Trim().ToLowerInvariant()
    } else { "" }
    Assert-True "phase6 preview loop-guard existing D1 database ID is a UUID" (
      $previewDatabaseId -cmatch "^$uuid$"
    )

    $previewDatabase = $config.env.preview.d1_databases[0]
    $previewDatabase | Add-Member -NotePropertyName "database_id" -NotePropertyValue $previewDatabaseId
    $config | ConvertTo-Json -Depth 100 | Set-Content `
      -LiteralPath $materializedConfigPath -Encoding utf8NoBOM
    try {
      $materializedConfigWithId = Get-Content -LiteralPath $materializedConfigPath -Raw | ConvertFrom-Json
    } catch {
      throw "Worker deploy precondition failed: phase6 preview loop-guard transient config is invalid"
    }
    Assert-True "phase6 preview loop-guard transient D1 binding uses the resolved existing database" (
      [string]$materializedConfigWithId.env.preview.d1_databases[0].database_id -ceq $previewDatabaseId
    )

    $bindingArgs = @(
      "--var", "SOURCE_COMMIT_SHA:$resolvedSource",
      "--var", "SOURCE_ARCHIVE_SHA256:$archiveSha",
      "--var", "HOSTED_MCP_WRITE_AUTHORIZED:false",
      "--var", "LIVE_MCP_WRITES_ENABLED:false"
    )
    $preflightOutputDir = Join-Path $materializationRoot "preflight-output"
    $preflightBundleFile = Join-Path $preflightOutputDir "index.js"
    $preflightMetafile = Join-Path $materializationRoot "bundle-preflight-meta.json"
    $preflightArgs = @(
      "deploy",
      "--config", $materializedConfigPath,
      "--env", "preview",
      "--keep-vars",
      "--no-experimental-auto-create"
    ) + $bindingArgs + @(
      "--dry-run",
      "--outdir", $preflightOutputDir,
      "--metafile", $preflightMetafile
    )
    if ($null -ne $CandidateCloudflareCredentials) {
      $preflightExecution = Invoke-CandidateWranglerChild `
        $wrangler $preflightArgs $CandidateCloudflareCredentials $materializedWorkerDir `
        "phase6 preview loop-guard Wrangler preflight"
      $preflightExitCode = [int]$preflightExecution.ExitCode
      $preflightExecution.Stdout = $null
    } else {
      $preflightExecution = Invoke-ScrubbedWranglerChild `
        $wrangler $preflightArgs $materializedWorkerDir `
        "phase6 preview loop-guard Wrangler preflight"
      $preflightExitCode = [int]$preflightExecution.ExitCode
      $preflightExecution.Stdout = $null
    }
    Assert-True "phase6 preview loop-guard selected-source Wrangler preflight exit code 0" (
      $preflightExitCode -eq 0
    )
    $preflightScripts = @(Get-ChildItem -LiteralPath $preflightOutputDir -File -Filter "*.js")
    Assert-True "phase6 preview loop-guard preflight emitted exactly one JavaScript bundle" (
      $preflightScripts.Count -eq 1 -and $preflightScripts[0].FullName -ceq $preflightBundleFile
    )
    Assert-True "phase6 preview loop-guard preflight metafile exists" (
      Test-Path -LiteralPath $preflightMetafile -PathType Leaf
    )
    try {
      $preflightMetadata = Get-Content -LiteralPath $preflightMetafile -Raw | ConvertFrom-Json
    } catch {
      throw "Worker deploy precondition failed: phase6 preview loop-guard preflight metafile is invalid"
    }
    $preflightInputs = @($preflightMetadata.inputs.PSObject.Properties.Name)
    Assert-True "phase6 preview loop-guard preflight records source inputs" ($preflightInputs.Count -gt 0)
    $materializedRootFull = [System.IO.Path]::GetFullPath($materializedWorkerDir).TrimEnd(
      [System.IO.Path]::DirectorySeparatorChar
    )
    $allInputsBounded = $true
    foreach ($inputName in $preflightInputs) {
      $inputFull = if ([System.IO.Path]::IsPathRooted([string]$inputName)) {
        [System.IO.Path]::GetFullPath([string]$inputName)
      } else {
        [System.IO.Path]::GetFullPath((Join-Path $materializedWorkerDir ([string]$inputName)))
      }
      if (-not $inputFull.StartsWith(
        $materializedRootFull + [System.IO.Path]::DirectorySeparatorChar,
        [System.StringComparison]::OrdinalIgnoreCase
      )) {
        $allInputsBounded = $false
        break
      }
    }
    Assert-True "phase6 preview loop-guard preflight inputs are source-confined" $allInputsBounded
    $sourceBundleSha = (
      Get-FileHash -LiteralPath $preflightBundleFile -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    Assert-True "phase6 preview loop-guard exact upload bundle SHA-256 computed" (
      $sourceBundleSha -match "^[0-9a-f]{64}$"
    )

    if ($IsDryRun) {
      Write-Host "[worker-deploy] phase6 preview loop-guard dry-run complete; nothing was published"
      return
    }

    $deployArgs = @(
      "deploy", $preflightBundleFile,
      "--no-bundle", "--config", $materializedConfigPath,
      "--env", "preview",
      "--keep-vars",
      "--no-experimental-auto-create"
    ) + $bindingArgs + @(
      "--var", "SOURCE_BUNDLE_SHA256:$sourceBundleSha"
    )
    if ($null -ne $CandidateCloudflareCredentials) {
      $deployExecution = Invoke-CandidateWranglerChild `
        $wrangler $deployArgs $CandidateCloudflareCredentials $materializedWorkerDir `
        "phase6 preview loop-guard Wrangler deploy"
      $deployOutput = @($deployExecution.Stdout)
      $deployExitCode = [int]$deployExecution.ExitCode
      $deployExecution.Stdout = $null
    } else {
      $deployExecution = Invoke-ScrubbedWranglerChild `
        $wrangler $deployArgs $materializedWorkerDir `
        "phase6 preview loop-guard Wrangler deploy"
      $deployOutput = @($deployExecution.Stdout)
      $deployExitCode = [int]$deployExecution.ExitCode
      $deployExecution.Stdout = $null
    }
    Assert-True "phase6 preview loop-guard Wrangler deploy exit code 0; command output suppressed" (
      $deployExitCode -eq 0
    )
    $deployOutputText = (($deployOutput | ForEach-Object { [string]$_ }) -join "`n").Trim()
    Assert-True "phase6 preview loop-guard deploy metadata is bounded" (
      $deployOutputText.Length -le 1048576
    )
    $deployOutputText = [regex]::Replace($deployOutputText, "\x1b\[[0-9;?]*[ -/]*[@-~]", "")
    $versionMatches = [regex]::Matches(
      $deployOutputText,
      "(?im)^\s*Current Version ID\s*:\s*($uuid)\s*$"
    )
    Assert-True "phase6 preview loop-guard Wrangler output has exactly one Current Version ID" (
      $versionMatches.Count -eq 1
    )
    $workerVersionId = $versionMatches[0].Groups[1].Value.ToLowerInvariant()

    $deploymentStatusArgs = @(
      "deployments", "status",
      "--env", "preview",
      "--name", $previewWorkerName,
      "--config", $materializedConfigPath,
      "--json"
    )
    if ($null -ne $CandidateCloudflareCredentials) {
      $deploymentStatusExecution = Invoke-CandidateWranglerChild `
        $wrangler $deploymentStatusArgs $CandidateCloudflareCredentials $materializedWorkerDir `
        "phase6 preview loop-guard deployment status"
      $deploymentStatusOutput = @($deploymentStatusExecution.Stdout)
      $deploymentStatusExitCode = [int]$deploymentStatusExecution.ExitCode
      $deploymentStatusExecution.Stdout = $null
    } else {
      $deploymentStatusExecution = Invoke-ScrubbedWranglerChild `
        $wrangler $deploymentStatusArgs $materializedWorkerDir `
        "phase6 preview loop-guard deployment status"
      $deploymentStatusOutput = @($deploymentStatusExecution.Stdout)
      $deploymentStatusExitCode = [int]$deploymentStatusExecution.ExitCode
      $deploymentStatusExecution.Stdout = $null
    }
    Assert-True "phase6 preview loop-guard deployment status control-plane read exit code 0" (
      $deploymentStatusExitCode -eq 0
    )
    $deploymentStatusText = (($deploymentStatusOutput | ForEach-Object { [string]$_ }) -join "`n").Trim()
    Assert-True "phase6 preview loop-guard deployment status output is bounded" (
      -not [string]::IsNullOrWhiteSpace($deploymentStatusText) -and
      $deploymentStatusText.Length -le 1048576
    )
    try {
      $deploymentStatus = $deploymentStatusText | ConvertFrom-Json
    } catch {
      throw "Worker deploy precondition failed: phase6 preview loop-guard deployment status is invalid JSON"
    }
    $deploymentId = if ($deploymentStatus.id -is [string]) {
      ([string]$deploymentStatus.id).Trim().ToLowerInvariant()
    } else { "" }
    $deploymentVersions = @($deploymentStatus.versions)
    Assert-True "phase6 preview loop-guard latest deployment ID is a UUID" (
      $deploymentId -cmatch "^$uuid$"
    )
    Assert-True "phase6 preview loop-guard latest deployment is the uploaded version at 100 percent" (
      $deploymentVersions.Count -eq 1 -and
      ([string]$deploymentVersions[0].version_id).Trim().ToLowerInvariant() -ceq $workerVersionId -and
      [double]$deploymentVersions[0].percentage -eq 100
    )
    Assert-True "phase6 preview loop-guard deployment and Worker version IDs are distinct" (
      $deploymentId -cne $workerVersionId
    )

    $deployResult = [ordered]@{
      contract_version = "cloudflare-phase6-preview-guard-deploy-result-v1"
      base_url = $previewBaseUrl
      verified_at_utc = [DateTimeOffset]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
      source_commit_sha = $resolvedSource
      source_archive_sha256 = $archiveSha
      source_bundle_sha256 = $sourceBundleSha
      worker_version_id = $workerVersionId
      deployment_id = $deploymentId
      control_plane_verified = $true
      worker_request_count = 0
      secret_output = $false
    }
  } finally {
    try {
      Remove-TransientMaterialization $materializationRoot
      $repositoryConfigShaAfter = (
        Get-FileHash -LiteralPath $repositoryConfigPath -Algorithm SHA256
      ).Hash.ToLowerInvariant()
      Assert-True "phase6 preview loop-guard repository wrangler config remains byte-identical" (
        $repositoryConfigShaAfter -ceq $repositoryConfigShaBefore
      )
    } finally {
      Clear-CandidateCloudflareCredentialSet $CandidateCloudflareCredentials
    }
  }
  Assert-True "phase6 preview loop-guard result is ready after successful cleanup" ($null -ne $deployResult)
  Write-Output ($deployResult | ConvertTo-Json -Compress)
}

function Invoke-Phase6ProductionDeploy(
  [string]$RepositoryRoot,
  [string]$SelectedSourceCommit,
  [string]$SelectedControlCommit,
  [bool]$IsDryRun,
  [bool]$IsValidateOnly,
  [object]$CandidateCloudflareCredentials
) {
  $relativeWorkerRoot = "services/cloudflare-stateful-runtime"
  $capabilityStatePath = "docs/runtime-state/capability-gates.json"
  $loopGuardCommit = "c24b7bfddc37cfa0c16d1ebc7f70829417ac4080"
  $productionWorkerName = "cloud-superbrain-stateful-runtime"
  $productionBaseUrl = "https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev"
  $productionHealthUrl = "https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev/api/v1/health"

  Assert-True "phase6 production source SHA is an explicit lowercase commit" (
    $SelectedSourceCommit -cmatch "^[0-9a-f]{40}$"
  )
  Assert-True "phase6 production control SHA is an explicit lowercase commit" (
    $SelectedControlCommit -cmatch "^[0-9a-f]{40}$"
  )
  $resolvedSource = (& git rev-parse --verify "$SelectedSourceCommit^{commit}" 2>$null).Trim()
  Assert-True "phase6 production source commit resolved exactly" (
    $LASTEXITCODE -eq 0 -and $resolvedSource -ceq $SelectedSourceCommit
  )
  & git merge-base --is-ancestor $loopGuardCommit $resolvedSource 2>$null
  Assert-True "phase6 production source contains the cross-origin bounce-loop fix" (
    $LASTEXITCODE -eq 0
  )
  $resolvedControl = (& git rev-parse --verify "$SelectedControlCommit^{commit}" 2>$null).Trim()
  Assert-True "phase6 production control commit resolved exactly" (
    $LASTEXITCODE -eq 0 -and $resolvedControl -ceq $SelectedControlCommit
  )
  & git merge-base --is-ancestor $resolvedSource $resolvedControl 2>$null
  Assert-True "phase6 production control commit descends from the source commit" ($LASTEXITCODE -eq 0)

  $trackedCapabilityState = @(& git show "$resolvedControl`:$capabilityStatePath" 2>$null)
  Assert-True "phase6 production capability state is committed at the control commit" (
    $LASTEXITCODE -eq 0 -and $trackedCapabilityState.Count -gt 0
  )
  try {
    $capabilityState = ($trackedCapabilityState -join "`n") | ConvertFrom-Json
  } catch {
    throw "Worker deploy precondition failed: phase6 production capability state is not valid JSON"
  }
  $phase6GateProperty = $capabilityState.gates.PSObject.Properties["phase6_scale_runtime"]
  Assert-True "phase6 production capability contract and gate are present" (
    [string]$capabilityState.contract_version -ceq "capability-gate-state-v1" -and
    $null -ne $phase6GateProperty -and
    $null -ne $phase6GateProperty.Value
  )
  $phase6Gate = $phase6GateProperty.Value
  $phase6OwnerGrantRef = if ($phase6Gate.owner_grant_ref -is [string]) {
    ([string]$phase6Gate.owner_grant_ref).Trim()
  } else { "" }
  Assert-True "phase6 production gate is Owner-granted but not yet live-verified" (
    $phase6Gate.owner_granted -is [bool] -and
    $phase6Gate.owner_granted -eq $true -and
    $phase6Gate.live_verified -is [bool] -and
    $phase6Gate.live_verified -eq $false
  )
  Assert-True "phase6 production Owner grant reference is safe" (
    ([string]$phase6Gate.owner_grant_ref) -ceq $phase6OwnerGrantRef -and
    $phase6OwnerGrantRef.Length -ge 8 -and
    $phase6OwnerGrantRef.Length -le 256 -and
    $phase6OwnerGrantRef -cmatch "^[A-Za-z0-9_.:-]+$"
  )
  Assert-True "phase6 production gate is non-paid" (
    $phase6Gate.paid_provider -is [bool] -and $phase6Gate.paid_provider -eq $false
  )

  $workerDiff = @(& git diff --name-only $resolvedSource -- $relativeWorkerRoot)
  Assert-True "phase6 production Worker tracked-diff scan completed" ($LASTEXITCODE -eq 0)
  Assert-True "phase6 production Worker tree matches the source commit" ($workerDiff.Count -eq 0)
  $untrackedWorkerEntries = @(& git ls-files --others --exclude-standard -- $relativeWorkerRoot)
  Assert-True "phase6 production Worker untracked-file scan completed" ($LASTEXITCODE -eq 0)
  Assert-True "phase6 production Worker tree has no untracked files" ($untrackedWorkerEntries.Count -eq 0)
  $ignoredWorkerEntries = @(
    & git ls-files --others --ignored --exclude-standard --directory -- $relativeWorkerRoot
  )
  Assert-True "phase6 production Worker ignored-file scan completed" ($LASTEXITCODE -eq 0)
  $allowedIgnoredWorkerRoots = @(
    "services/cloudflare-stateful-runtime/node_modules/",
    "services/cloudflare-stateful-runtime/.wrangler/"
  )
  $runtimeRelevantIgnoredEntries = @(
    $ignoredWorkerEntries |
      Where-Object { $allowedIgnoredWorkerRoots -notcontains ([string]$_).Replace("\", "/") }
  )
  Assert-True "phase6 production Worker tree has no runtime-relevant ignored files" (
    $runtimeRelevantIgnoredEntries.Count -eq 0
  )

  $archiveSha = Get-GitArchiveSha256 $RepositoryRoot $resolvedSource
  Assert-True "phase6 production source archive SHA-256 computed" ($archiveSha -match "^[0-9a-f]{64}$")

  $materializationRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    "cloud-superbrain-worker-deploy-" + [Guid]::NewGuid().ToString("N")
  )
  $materializedWorkerDir = Join-Path $materializationRoot "worker"
  $workerArchive = Join-Path $materializationRoot "worker-source.tar"
  $deployResult = $null
  New-Item -ItemType Directory -Path $materializedWorkerDir -Force | Out-Null
  try {
    & git archive --format=tar "--output=$workerArchive" $resolvedSource -- $relativeWorkerRoot
    Assert-True "phase6 production selected Worker source archive created" ($LASTEXITCODE -eq 0)
    $null = & tar -xf $workerArchive -C $materializedWorkerDir --strip-components=2 2>&1
    Assert-True "phase6 production selected Worker source materialized" ($LASTEXITCODE -eq 0)
    foreach ($requiredPath in @("package.json", "package-lock.json", "wrangler.jsonc", "src/index.js")) {
      Assert-True "phase6 production materialization contains $requiredPath" (
        Test-Path -LiteralPath (Join-Path $materializedWorkerDir $requiredPath) -PathType Leaf
      )
    }

    $materializedConfigPath = Join-Path $materializedWorkerDir "wrangler.jsonc"
    try {
      $config = Get-Content -LiteralPath $materializedConfigPath -Raw | ConvertFrom-Json
    } catch {
      throw "Worker deploy precondition failed: phase6 production wrangler config is invalid"
    }
    Assert-Phase6WranglerConfigShape $config
    Assert-True "phase6 production targets the canonical top-level Worker" (
      [string]$config.name -ceq $productionWorkerName -and
      [string]$config.main -ceq "src/index.js" -and
      $config.workers_dev -is [bool] -and $config.workers_dev
    )

    $productionDatabases = @($config.d1_databases)
    Assert-True "phase6 production D1 binding is exact" (
      $productionDatabases.Count -eq 1 -and
      [string]$productionDatabases[0].binding -ceq "DB" -and
      [string]$productionDatabases[0].database_name -ceq "cloud-superbrain-state-prod" -and
      [string]$productionDatabases[0].database_id -ceq "91520f43-5d38-4a31-9d5a-6fca890e1dd6" -and
      [string]$productionDatabases[0].migrations_dir -ceq "migrations"
    )
    $productionDurableObjects = @($config.durable_objects.bindings)
    Assert-True "phase6 production Durable Object binding is exact" (
      $productionDurableObjects.Count -eq 1 -and
      [string]$productionDurableObjects[0].name -ceq "RUNTIME_COORDINATOR" -and
      [string]$productionDurableObjects[0].class_name -ceq "RuntimeCoordinator"
    )
    $productionMigrations = @($config.migrations)
    Assert-True "phase6 production migration is exact" (
      $productionMigrations.Count -eq 1 -and
      [string]$productionMigrations[0].tag -ceq "v1-cloudflare-native-coordinator" -and
      @($productionMigrations[0].new_sqlite_classes).Count -eq 1 -and
      [string]$productionMigrations[0].new_sqlite_classes[0] -ceq "RuntimeCoordinator"
    )
    $productionQueueProducers = @($config.queues.producers)
    Assert-True "phase6 production queue producer is exact" (
      $productionQueueProducers.Count -eq 1 -and
      [string]$productionQueueProducers[0].binding -ceq "RUNTIME_QUEUE" -and
      [string]$productionQueueProducers[0].queue -ceq "cloud-superbrain-runtime-candidate"
    )
    $productionQueueConsumers = @($config.queues.consumers)
    Assert-True "phase6 production queue consumer is exact" (
      $productionQueueConsumers.Count -eq 1 -and
      [string]$productionQueueConsumers[0].queue -ceq "cloud-superbrain-runtime-candidate" -and
      [int]$productionQueueConsumers[0].max_batch_size -eq 10 -and
      [int]$productionQueueConsumers[0].max_batch_timeout -eq 1 -and
      [int]$productionQueueConsumers[0].max_retries -eq 3
    )
    $productionVectorize = @($config.vectorize)
    Assert-True "phase6 production Vectorize binding is exact" (
      $productionVectorize.Count -eq 1 -and
      [string]$productionVectorize[0].binding -ceq "VECTORIZE" -and
      [string]$productionVectorize[0].index_name -ceq "cloud-superbrain-memory-v1"
    )
    Assert-True "phase6 production Workers AI binding is exact" (
      [string]$config.ai.binding -ceq "AI" -and
      @($config.ai.PSObject.Properties).Count -eq 1
    )
    $r2Property = $config.PSObject.Properties["r2_buckets"]
    Assert-True "phase6 production has no R2 binding" (
      $null -eq $r2Property -or @($r2Property.Value).Count -eq 0
    )

    $previewProperty = $config.env.PSObject.Properties["preview"]
    Assert-True "phase6 preview Worker is isolated" (
      $null -ne $previewProperty -and
      [string]$previewProperty.Value.name -ceq "cloud-superbrain-stateful-runtime-preview" -and
      [string]$previewProperty.Value.name -cne $productionWorkerName
    )
    $preview = $previewProperty.Value
    $previewDatabases = @($preview.d1_databases)
    Assert-True "phase6 preview D1 binding is isolated" (
      $previewDatabases.Count -eq 1 -and
      [string]$previewDatabases[0].binding -ceq "DB" -and
      [string]$previewDatabases[0].database_name -ceq "cloud-superbrain-state-preview" -and
      [string]$previewDatabases[0].database_name -cne [string]$productionDatabases[0].database_name -and
      $null -eq $previewDatabases[0].PSObject.Properties["database_id"]
    )
    $previewQueueProducers = @($preview.queues.producers)
    $previewQueueConsumers = @($preview.queues.consumers)
    Assert-True "phase6 preview queue is isolated" (
      $previewQueueProducers.Count -eq 1 -and
      [string]$previewQueueProducers[0].binding -ceq "RUNTIME_QUEUE" -and
      [string]$previewQueueProducers[0].queue -ceq "cloud-superbrain-runtime-candidate-preview" -and
      [string]$previewQueueProducers[0].queue -cne [string]$productionQueueProducers[0].queue -and
      $previewQueueConsumers.Count -eq 1 -and
      [string]$previewQueueConsumers[0].queue -ceq "cloud-superbrain-runtime-candidate-preview"
    )
    $previewDurableObjects = @($preview.durable_objects.bindings)
    Assert-True "phase6 preview Durable Object is isolated by the preview Worker" (
      $previewDurableObjects.Count -eq 1 -and
      [string]$previewDurableObjects[0].name -ceq "RUNTIME_COORDINATOR" -and
      [string]$previewDurableObjects[0].class_name -ceq "RuntimeCoordinator"
    )
    $previewVectorize = @($preview.vectorize)
    Assert-True "phase6 preview Vectorize binding is exact" (
      $previewVectorize.Count -eq 1 -and
      [string]$previewVectorize[0].binding -ceq "VECTORIZE" -and
      [string]$previewVectorize[0].index_name -ceq "cloud-superbrain-memory-v1"
    )
    Assert-True "phase6 preview Workers AI binding is exact" (
      [string]$preview.ai.binding -ceq "AI" -and
      @($preview.ai.PSObject.Properties).Count -eq 1
    )
    $previewR2Property = $preview.PSObject.Properties["r2_buckets"]
    Assert-True "phase6 preview has no R2 binding" (
      $null -eq $previewR2Property -or @($previewR2Property.Value).Count -eq 0
    )

    $productionVars = $config.vars
    foreach ($secretName in @("GITHUB_OAUTH_CLIENT_SECRET", "JWT_SIGNING_SECRET", "AGENT_API_AUTH_TOKEN")) {
      Assert-True "phase6 production $secretName remains outside plain-text vars" (
        $null -eq $productionVars.PSObject.Properties[$secretName]
      )
    }
    $sourceBoundProductionAuthVars = @(
      $productionVars.PSObject.Properties.Name | Where-Object { [string]$_ -cmatch "^PRODUCTION_AUTH_" }
    )
    Assert-True "phase6 production source cannot overwrite remote PRODUCTION_AUTH_* values" (
      $sourceBoundProductionAuthVars.Count -eq 0
    )
    foreach ($derivedName in @(
      "SOURCE_COMMIT_SHA",
      "SOURCE_ARCHIVE_SHA256",
      "SOURCE_BUNDLE_SHA256",
      "HOSTED_MCP_WRITE_AUTHORIZED",
      "LIVE_MCP_WRITES_ENABLED"
    )) {
      Assert-True "phase6 production derives $derivedName at deploy time" (
        $null -eq $productionVars.PSObject.Properties[$derivedName]
      )
    }

    try {
      $trackedPackageLock = Get-Content -LiteralPath (Join-Path $materializedWorkerDir "package-lock.json") `
        -Raw | ConvertFrom-Json -AsHashtable
    } catch {
      throw "Worker deploy precondition failed: phase6 production package lock is invalid"
    }
    $lockedWrangler = $trackedPackageLock["packages"]["node_modules/wrangler"]
    $lockedWranglerVersion = if ($lockedWrangler -is [System.Collections.IDictionary]) {
      [string]$lockedWrangler["version"]
    } else { "" }
    Assert-True "phase6 production package lock pins Wrangler" (
      $lockedWranglerVersion -match "^[0-9]+\.[0-9]+\.[0-9]+$"
    )

    if ($IsValidateOnly) {
      Write-Host "[worker-deploy] phase6 production validation complete; nothing was published"
      return
    }

    Push-Location $materializedWorkerDir
    try {
      $null = & npm ci --ignore-scripts --prefer-offline --no-audit --no-fund 2>&1
      $npmCiExitCode = $LASTEXITCODE
    } finally { Pop-Location }
    Assert-True "phase6 production dependency tree installed from the selected lock" ($npmCiExitCode -eq 0)
    $wrangler = Join-Path $materializedWorkerDir "node_modules/wrangler/bin/wrangler.js"
    Assert-True "phase6 production materialized Wrangler is present" (
      Test-Path -LiteralPath $wrangler -PathType Leaf
    )
    $installedWranglerVersion = ((& node $wrangler --version 2>$null) -join "").Trim()
    Assert-True "phase6 production Wrangler matches the selected lock" (
      $LASTEXITCODE -eq 0 -and $installedWranglerVersion -ceq $lockedWranglerVersion
    )

    $runtimeMode = Get-PlainTextVar $productionVars "RUNTIME_MODE"
    $contractOrigin = Get-PlainTextVar $productionVars "CONTRACT_ORIGIN"
    $oauthPublicOrigin = Get-PlainTextVar $productionVars "OAUTH_PUBLIC_ORIGIN"
    $oauthRedirectUri = Get-PlainTextVar $productionVars "GITHUB_OAUTH_REDIRECT_URI"
    $oauthClientId = Get-PlainTextVar $productionVars "GITHUB_OAUTH_CLIENT_ID"
    $oauthOwnerIds = Get-PlainTextVar $productionVars "GITHUB_OAUTH_OWNER_IDS"
    $postLoginRedirect = Get-PlainTextVar $productionVars "POST_LOGIN_REDIRECT"
    $memoryEmbeddingModel = Get-PlainTextVar $productionVars "MEMORY_EMBEDDING_MODEL"
    Assert-True "phase6 production public runtime vars are exact" (
      @($productionVars.PSObject.Properties).Count -eq 8 -and
      $runtimeMode -ceq "cloudflare_native_hosted_candidate" -and
      $contractOrigin -ceq "https://cloud-superbrain-developer-platform.vercel.app" -and
      $oauthPublicOrigin -ceq "https://frontend-seven-psi-78.vercel.app" -and
      $oauthRedirectUri -ceq "https://frontend-seven-psi-78.vercel.app/api/v1/auth/callback" -and
      $oauthClientId -match "^(?:[A-Za-z0-9]{20}|[IO]v1\.[A-Fa-f0-9]{16})$" -and
      $oauthOwnerIds -match "^[1-9][0-9]*(,[1-9][0-9]*)*$" -and
      $postLoginRedirect -ceq "/workbench" -and
      $memoryEmbeddingModel -ceq "@cf/baai/bge-base-en-v1.5"
    )
    $bindingArgs = @(
      "--var", "RUNTIME_MODE:$runtimeMode",
      "--var", "CONTRACT_ORIGIN:$contractOrigin",
      "--var", "OAUTH_PUBLIC_ORIGIN:$oauthPublicOrigin",
      "--var", "GITHUB_OAUTH_REDIRECT_URI:$oauthRedirectUri",
      "--var", "GITHUB_OAUTH_CLIENT_ID:$oauthClientId",
      "--var", "GITHUB_OAUTH_OWNER_IDS:$oauthOwnerIds",
      "--var", "POST_LOGIN_REDIRECT:$postLoginRedirect",
      "--var", "MEMORY_EMBEDDING_MODEL:$memoryEmbeddingModel",
      "--var", "SOURCE_COMMIT_SHA:$resolvedSource",
      "--var", "SOURCE_ARCHIVE_SHA256:$archiveSha",
      "--var", "HOSTED_MCP_WRITE_AUTHORIZED:false",
      "--var", "LIVE_MCP_WRITES_ENABLED:false"
    )
    $preflightOutputDir = Join-Path $materializationRoot "preflight-output"
    $preflightBundleFile = Join-Path $preflightOutputDir "index.js"
    $preflightMetafile = Join-Path $materializationRoot "bundle-preflight-meta.json"
    $preflightArgs = @(
      "deploy",
      "--config", $materializedConfigPath,
      "--keep-vars",
      "--no-experimental-auto-create"
    ) + $bindingArgs + @(
      "--dry-run",
      "--outdir", $preflightOutputDir,
      "--metafile", $preflightMetafile
    )
    if ($null -ne $CandidateCloudflareCredentials) {
      $preflightExecution = Invoke-CandidateWranglerChild `
        $wrangler $preflightArgs $CandidateCloudflareCredentials $materializedWorkerDir `
        "phase6 production Wrangler preflight"
      $preflightExitCode = [int]$preflightExecution.ExitCode
      $preflightExecution.Stdout = $null
    } else {
      $preflightExecution = Invoke-ScrubbedWranglerChild `
        $wrangler $preflightArgs $materializedWorkerDir `
        "phase6 production Wrangler preflight"
      $preflightExitCode = [int]$preflightExecution.ExitCode
      $preflightExecution.Stdout = $null
    }
    Assert-True "phase6 production selected-source Wrangler preflight exit code 0" (
      $preflightExitCode -eq 0
    )
    $preflightScripts = @(Get-ChildItem -LiteralPath $preflightOutputDir -File -Filter "*.js")
    Assert-True "phase6 production preflight emitted exactly one JavaScript bundle" (
      $preflightScripts.Count -eq 1 -and $preflightScripts[0].FullName -ceq $preflightBundleFile
    )
    Assert-True "phase6 production preflight metafile exists" (
      Test-Path -LiteralPath $preflightMetafile -PathType Leaf
    )
    try {
      $preflightMetadata = Get-Content -LiteralPath $preflightMetafile -Raw | ConvertFrom-Json
    } catch {
      throw "Worker deploy precondition failed: phase6 production preflight metafile is invalid"
    }
    $preflightInputs = @($preflightMetadata.inputs.PSObject.Properties.Name)
    Assert-True "phase6 production preflight records source inputs" ($preflightInputs.Count -gt 0)
    $materializedRootFull = [System.IO.Path]::GetFullPath($materializedWorkerDir).TrimEnd(
      [System.IO.Path]::DirectorySeparatorChar
    )
    $allInputsBounded = $true
    foreach ($inputName in $preflightInputs) {
      $inputFull = if ([System.IO.Path]::IsPathRooted([string]$inputName)) {
        [System.IO.Path]::GetFullPath([string]$inputName)
      } else {
        [System.IO.Path]::GetFullPath((Join-Path $materializedWorkerDir ([string]$inputName)))
      }
      if (-not $inputFull.StartsWith(
        $materializedRootFull + [System.IO.Path]::DirectorySeparatorChar,
        [System.StringComparison]::OrdinalIgnoreCase
      )) {
        $allInputsBounded = $false
        break
      }
    }
    Assert-True "phase6 production preflight inputs are source-confined" $allInputsBounded
    $sourceBundleSha = (Get-FileHash -LiteralPath $preflightBundleFile -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-True "phase6 production exact upload bundle SHA-256 computed" (
      $sourceBundleSha -match "^[0-9a-f]{64}$"
    )

    if ($IsDryRun) {
      Write-Host "[worker-deploy] phase6 production dry-run complete; nothing was published"
      return
    }

    $deployArgs = @(
      "deploy", $preflightBundleFile,
      "--no-bundle", "--config", $materializedConfigPath,
      "--keep-vars",
      "--no-experimental-auto-create"
    ) + $bindingArgs + @(
      "--var", "SOURCE_BUNDLE_SHA256:$sourceBundleSha"
    )
    if ($null -ne $CandidateCloudflareCredentials) {
      $deployExecution = Invoke-CandidateWranglerChild `
        $wrangler $deployArgs $CandidateCloudflareCredentials $materializedWorkerDir `
        "phase6 production Wrangler deploy"
      $deployOutput = @($deployExecution.Stdout)
      $deployExitCode = [int]$deployExecution.ExitCode
      $deployExecution.Stdout = $null
    } else {
      $deployExecution = Invoke-ScrubbedWranglerChild `
        $wrangler $deployArgs $materializedWorkerDir `
        "phase6 production Wrangler deploy"
      $deployOutput = @($deployExecution.Stdout)
      $deployExitCode = [int]$deployExecution.ExitCode
      $deployExecution.Stdout = $null
    }
    Assert-True "phase6 production Wrangler deploy exit code 0; command output suppressed" (
      $deployExitCode -eq 0
    )
    $deployOutputText = (($deployOutput | ForEach-Object { [string]$_ }) -join "`n").Trim()
    Assert-True "phase6 production deploy metadata parsed only from bounded Wrangler labels" (
      $deployOutputText.Length -le 1048576
    )
    $uuid = "[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}"
    $deployOutputText = [regex]::Replace($deployOutputText, "\x1b\[[0-9;?]*[ -/]*[@-~]", "")
    $versionMatches = [regex]::Matches(
      $deployOutputText,
      "(?im)^\s*Current Version ID\s*:\s*($uuid)\s*$"
    )
    Assert-True "phase6 production Wrangler output has exactly one Current Version ID" (
      $versionMatches.Count -eq 1
    )
    $workerVersionId = $versionMatches[0].Groups[1].Value.ToLowerInvariant()

    $deploymentStatusArgs = @(
      "deployments", "status",
      "--name", $productionWorkerName,
      "--config", $materializedConfigPath,
      "--json"
    )
    if ($null -ne $CandidateCloudflareCredentials) {
      $deploymentStatusExecution = Invoke-CandidateWranglerChild `
        $wrangler $deploymentStatusArgs $CandidateCloudflareCredentials $materializedWorkerDir `
        "phase6 production deployment status"
      $deploymentStatusOutput = @($deploymentStatusExecution.Stdout)
      $deploymentStatusExitCode = [int]$deploymentStatusExecution.ExitCode
      $deploymentStatusExecution.Stdout = $null
    } else {
      $deploymentStatusExecution = Invoke-ScrubbedWranglerChild `
        $wrangler $deploymentStatusArgs $materializedWorkerDir `
        "phase6 production deployment status"
      $deploymentStatusOutput = @($deploymentStatusExecution.Stdout)
      $deploymentStatusExitCode = [int]$deploymentStatusExecution.ExitCode
      $deploymentStatusExecution.Stdout = $null
    }
    Assert-True "phase6 production deployment status control-plane read exit code 0" (
      $deploymentStatusExitCode -eq 0
    )
    $deploymentStatusText = (($deploymentStatusOutput | ForEach-Object { [string]$_ }) -join "`n").Trim()
    Assert-True "phase6 production deployment status output is bounded" (
      -not [string]::IsNullOrWhiteSpace($deploymentStatusText) -and
      $deploymentStatusText.Length -le 1048576
    )
    try {
      $deploymentStatus = $deploymentStatusText | ConvertFrom-Json
    } catch {
      throw "Worker deploy precondition failed: phase6 production deployment status is invalid JSON"
    }
    $deploymentId = if ($deploymentStatus.id -is [string]) {
      ([string]$deploymentStatus.id).Trim().ToLowerInvariant()
    } else { "" }
    $deploymentVersions = @($deploymentStatus.versions)
    Assert-True "phase6 production latest deployment ID is a UUID" (
      $deploymentId -match "^$uuid$"
    )
    Assert-True "phase6 production latest deployment is exactly the uploaded version at 100 percent" (
      $deploymentVersions.Count -eq 1 -and
      ([string]$deploymentVersions[0].version_id).Trim().ToLowerInvariant() -ceq $workerVersionId -and
      [double]$deploymentVersions[0].percentage -eq 100
    )
    Assert-True "phase6 production deployment and Worker version IDs are distinct" (
      $deploymentId -cne $workerVersionId
    )

    $workerRequestCount = 0
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect = $false
    $client = [System.Net.Http.HttpClient]::new($handler, $true)
    $client.Timeout = [TimeSpan]::FromSeconds(30)
    $request = [System.Net.Http.HttpRequestMessage]::new(
      [System.Net.Http.HttpMethod]::Get,
      $productionHealthUrl
    )
    $response = $null
    $healthBody = ""
    try {
      $workerRequestCount++
      $response = $client.SendAsync(
        $request,
        [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead
      ).GetAwaiter().GetResult()
      Assert-True "phase6 production health status code is 200" (
        [int]$response.StatusCode -eq 200
      )
      $healthBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    } finally {
      if ($null -ne $response) { $response.Dispose() }
      $request.Dispose()
      $client.Dispose()
    }
    try {
      $health = $healthBody | ConvertFrom-Json
    } catch {
      throw "Worker deploy precondition failed: phase6 production health body is invalid JSON"
    }
    Assert-True "phase6 production health reports healthy" (
      [string]$health.status -ceq "healthy"
    )
    Assert-True "phase6 production health verifies D1" (
      $health.d1_binding_configured -is [bool] -and $health.d1_binding_configured -and
      $health.d1_read_verified -is [bool] -and $health.d1_read_verified -and
      $health.persisted -is [bool] -and $health.persisted
    )
    Assert-True "phase6 production health exposes no secret output" (
      $health.secret_output -is [bool] -and $health.secret_output -eq $false
    )
    Assert-True "phase6 production health source_commit_sha rebound" (
      [string]$health.source_commit_sha -ceq $resolvedSource
    )
    Assert-True "phase6 production health source_archive_sha256 rebound" (
      [string]$health.source_archive_sha256 -ceq $archiveSha
    )
    Assert-True "phase6 production health source_bundle_sha256 rebound" (
      [string]$health.source_bundle_sha256 -ceq $sourceBundleSha
    )
    Assert-True "phase6 production issued exactly one Worker request" (
      $workerRequestCount -eq 1
    )
    $deployResult = [ordered]@{
      contract_version = "cloudflare-phase6-production-deploy-result-v1"
      base_url = $productionBaseUrl
      verified_at_utc = [DateTimeOffset]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
      source_commit_sha = $resolvedSource
      source_archive_sha256 = $archiveSha
      source_bundle_sha256 = $sourceBundleSha
      worker_version_id = $workerVersionId
      deployment_id = $deploymentId
      health_status = 200
      d1_read_verified = $true
      worker_request_count = $workerRequestCount
      secret_output = $false
    }
  } finally {
    try {
      Remove-TransientMaterialization $materializationRoot
    } finally {
      Clear-CandidateCloudflareCredentialSet $CandidateCloudflareCredentials
    }
  }
  Assert-True "phase6 production result is ready after successful cleanup" ($null -ne $deployResult)
  Write-Output ($deployResult | ConvertTo-Json -Compress)
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

if ($MyInvocation.InvocationName -eq ".") { return }

$canonicalPostLoginRedirect = "/workbench"
$previewWorkerHostname = "cloud-superbrain-stateful-runtime-preview.strazzusochr.workers.dev"
$previewWorkerHealthUrl = "https://$previewWorkerHostname/api/v1/health"
$previewWorkerMcpHealthUrl = "https://$previewWorkerHostname/mcp/api/v1/health"
$hostedMcpDeploymentEnvironment = "candidate_preview"

$repoRoot = Split-Path -Parent $PSScriptRoot
$candidateCloudflareCredentials = $null
Push-Location $repoRoot
try {
  Assert-True "DryRun and ValidateOnly are mutually exclusive" (-not ($DryRun -and $ValidateOnly))
  if ($UseCandidateCloudflareToken) {
    Assert-True "candidate Cloudflare token is limited to exactly one phase6 deploy mode" (
      $Phase6PreviewLoopGuard.IsPresent -xor $Phase6Production.IsPresent
    )
    Assert-True "candidate Cloudflare token is forbidden in ValidateOnly mode" (-not $ValidateOnly)
    $candidateCloudflareCredentials = Get-CandidateCloudflareCredentialSet
  }

  if ($Phase6PreviewLoopGuard) {
    Assert-True "phase6 preview loop-guard mode excludes production, LLM, and candidate activation arguments" (
      -not $Phase6Production -and
      -not $DeployLlmGateway -and
      -not $EnableHostedMcpWrites -and
      [string]::IsNullOrWhiteSpace($Phase6ControlCommitSha) -and
      [string]::IsNullOrWhiteSpace($CandidateFrontendOrigin) -and
      [string]::IsNullOrWhiteSpace($CandidateFrontendEvidenceCommitSha) -and
      [string]::IsNullOrWhiteSpace($CandidateBranch) -and
      [string]::IsNullOrWhiteSpace($LayerCreditRubricApprovalSha) -and
      [string]::IsNullOrWhiteSpace($HostedMcpOwnerGrantCommitSha)
    )
    Invoke-Phase6PreviewLoopGuardDeploy `
      $repoRoot `
      $CommitSha `
      $DryRun.IsPresent `
      $ValidateOnly.IsPresent `
      $candidateCloudflareCredentials
    return
  }

  if ($Phase6Production) {
    Assert-True "phase6 production mode excludes preview, LLM, and hosted MCP activation arguments" (
      -not $Phase6PreviewLoopGuard -and
      -not $DeployLlmGateway -and
      -not $EnableHostedMcpWrites -and
      [string]::IsNullOrWhiteSpace($CandidateFrontendOrigin) -and
      [string]::IsNullOrWhiteSpace($CandidateFrontendEvidenceCommitSha) -and
      [string]::IsNullOrWhiteSpace($CandidateBranch) -and
      [string]::IsNullOrWhiteSpace($LayerCreditRubricApprovalSha) -and
      [string]::IsNullOrWhiteSpace($HostedMcpOwnerGrantCommitSha)
    )
    Invoke-Phase6ProductionDeploy `
      $repoRoot `
      $CommitSha `
      $Phase6ControlCommitSha `
      $DryRun.IsPresent `
      $ValidateOnly.IsPresent `
      $candidateCloudflareCredentials
    return
  }
  Assert-True "phase6 control commit is absent outside production mode" (
    [string]::IsNullOrWhiteSpace($Phase6ControlCommitSha)
  )

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
} finally {
  Clear-CandidateCloudflareCredentialSet $candidateCloudflareCredentials
  Pop-Location
}

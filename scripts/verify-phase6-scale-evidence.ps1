#Requires -Version 7.0
<#
  Strictly verifies one immutable phase6-scale-evidence-v2 artifact offline.

  Default mode is read-only. Promotion requires -Promote plus the exact current
  capability-state and phase6 gate identity hashes. The Owner grant must already
  exist in canonical capability-gates.json before the live run; this verifier
  never creates, replaces, or derives that grant. No token or provider/Worker HTTP
  is used; anonymous GitHub execution/artifact readback is required in live mode.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$EvidencePath,
  [string]$CriterionPath,
  [string]$HostedStatePath,
  [string]$DeploymentPreflightStatePath,
  [string]$CapabilityStatePath,
  [string]$ExecutionReadbackPath,
  [switch]$Promote,
  [switch]$ValidateOnly,
  [string]$ExpectedCapabilityStateSha256,
  [string]$ExpectedGateIdentitySha256,
  [switch]$AllowTestPaths,
  [switch]$TrustSyntheticGitHubReadbackForTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\', '/')
$artifactRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot '.phase1-artifacts\phase6-scale')).TrimEnd('\', '/')
# -AllowTestPaths is confined to a scratch root so a caller cannot point the fixtures at
# arbitrary files. The root itself must resolve per platform: the workstation pins D:\_sb_tmp,
# but the static contract drives this verifier inside pr-check on ubuntu-latest, where that
# drive does not exist and every fixture would be rejected as "outside" it. The confinement is
# unchanged — only the root it is measured against is now resolved the same way the static
# contract resolves its own scratch directory.
$preferredTestRoot = if (-not [string]::IsNullOrWhiteSpace($env:SUPERBRAIN_TEST_ROOT)) {
  $env:SUPERBRAIN_TEST_ROOT
} elseif (Test-Path -LiteralPath 'D:/_sb_tmp' -PathType Container) {
  'D:/_sb_tmp'
} else {
  [IO.Path]::GetTempPath()
}
$testRoot = [IO.Path]::GetFullPath($preferredTestRoot).TrimEnd('\', '/')
$canonicalCriterion = [IO.Path]::GetFullPath((Join-Path $repoRoot 'docs\runtime-state\phase6-scale-criterion.json'))
$canonicalHostedState = [IO.Path]::GetFullPath((Join-Path $repoRoot 'docs\runtime-state\cloudflare-native-hosted-current.json'))
$canonicalDeploymentPreflightState = [IO.Path]::GetFullPath((Join-Path $repoRoot 'docs\runtime-state\phase6-scale-hosted-current.json'))
$canonicalCapabilityState = [IO.Path]::GetFullPath((Join-Path $repoRoot 'docs\runtime-state\capability-gates.json'))
$canonicalRuntimeVerifier = [IO.Path]::GetFullPath((Join-Path $repoRoot 'scripts\verify-phase6-scale-runtime.ps1'))
$minimumLoopFixCommit = 'c24b7bfddc37cfa0c16d1ebc7f70829417ac4080'
if (-not $CriterionPath) { $CriterionPath = $canonicalCriterion }
if (-not $HostedStatePath) { $HostedStatePath = $canonicalHostedState }
if (-not $DeploymentPreflightStatePath) { $DeploymentPreflightStatePath = $canonicalDeploymentPreflightState }
if (-not $CapabilityStatePath) { $CapabilityStatePath = $canonicalCapabilityState }

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Get-StringSha256([string]$Value) {
  $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
  } finally {
    $sha.Dispose()
  }
}

function Get-FileSha256([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-BytesSha256([byte[]]$Bytes) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return (($sha.ComputeHash($Bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
  } finally {
    $sha.Dispose()
  }
}

function Get-HttpBytes([Net.Http.HttpClient]$Client, [string]$Url, [long]$MaximumBytes, [string]$Label) {
  $request = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Get, $Url)
  try {
    $response = $Client.SendAsync($request, [Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
    try {
      Assert-True ([int]$response.StatusCode -ge 200 -and [int]$response.StatusCode -le 299) "$Label HTTP read failed with status $([int]$response.StatusCode)."
      if ($null -ne $response.Content.Headers.ContentLength) {
        Assert-True ([long]$response.Content.Headers.ContentLength -le $MaximumBytes) "$Label exceeds the maximum download size."
      }
      $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
      $memory = [IO.MemoryStream]::new()
      try {
        $buffer = [byte[]]::new(81920)
        $total = 0L
        while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
          $total += $read
          Assert-True ($total -le $MaximumBytes) "$Label exceeds the maximum download size."
          $memory.Write($buffer, 0, $read)
        }
        return [pscustomobject]@{ bytes = $memory.ToArray(); final_uri = $response.RequestMessage.RequestUri }
      } finally {
        $memory.Dispose()
        $stream.Dispose()
      }
    } finally {
      $response.Dispose()
    }
  } finally {
    $request.Dispose()
  }
}

function Assert-LiveGithubExecutionProvenance(
  $Binding,
  $CapturedReadback,
  [string]$EvidenceFile,
  [string]$EvidenceSidecar,
  [string]$EvidenceDigest,
  [string]$EnvironmentReviewFile,
  [string]$EnvironmentReviewSidecar,
  [string]$EnvironmentReviewDigest,
  [string]$EnvironmentReviewSidecarDigest
) {
  Add-Type -AssemblyName System.Net.Http
  Add-Type -AssemblyName System.IO.Compression
  $handler = [Net.Http.SocketsHttpHandler]::new()
  $handler.AllowAutoRedirect = $true
  $handler.MaxAutomaticRedirections = 5
  $client = [Net.Http.HttpClient]::new($handler)
  $client.Timeout = [TimeSpan]::FromSeconds(60)
  $client.DefaultRequestHeaders.UserAgent.ParseAdd('cloud-superbrain-phase6-evidence-verifier/1.0')
  $client.DefaultRequestHeaders.Accept.ParseAdd('application/vnd.github+json')
  $client.DefaultRequestHeaders.Add('X-GitHub-Api-Version', '2022-11-28')
  try {
    $repository = [string]$Binding.repository
    $runId = [long]$Binding.run_id
    $artifactId = [long]$CapturedReadback.artifact.id
    $runApiUrl = "https://api.github.com/repos/$repository/actions/runs/$runId"
    $artifactApiUrl = "https://api.github.com/repos/$repository/actions/artifacts/$artifactId"
    $queryHeadSha = [Uri]::EscapeDataString([string]$Binding.head_sha)
    $workflowRunsApiUrl = "https://api.github.com/repos/$repository/actions/workflows/phase6-scale-runtime.yml/runs?event=workflow_dispatch&head_sha=$queryHeadSha&per_page=100"
    $approvalsApiUrl = "https://api.github.com/repos/$repository/actions/runs/$runId/approvals"
    $liveRunResponse = Get-HttpBytes $client $runApiUrl 2097152 'GitHub workflow-run API'
    $liveArtifactResponse = Get-HttpBytes $client $artifactApiUrl 2097152 'GitHub artifact API'
    $workflowRunsResponse = Get-HttpBytes $client $workflowRunsApiUrl 4194304 'GitHub one-shot workflow-run API'
    $approvalsResponse = Get-HttpBytes $client $approvalsApiUrl 2097152 'GitHub Environment-review API'
    Assert-True ($liveRunResponse.final_uri.AbsoluteUri -ceq $runApiUrl) 'GitHub workflow-run API redirected unexpectedly.'
    Assert-True ($liveArtifactResponse.final_uri.AbsoluteUri -ceq $artifactApiUrl) 'GitHub artifact API redirected unexpectedly.'
    Assert-True ($workflowRunsResponse.final_uri.AbsoluteUri -ceq $workflowRunsApiUrl) 'GitHub one-shot workflow-run API redirected unexpectedly.'
    Assert-True ($approvalsResponse.final_uri.AbsoluteUri -ceq $approvalsApiUrl) 'GitHub Environment-review API redirected unexpectedly.'
    $liveRun = ([Text.Encoding]::UTF8.GetString($liveRunResponse.bytes) | ConvertFrom-Json -Depth 20)
    $liveArtifact = ([Text.Encoding]::UTF8.GetString($liveArtifactResponse.bytes) | ConvertFrom-Json -Depth 20)
    $workflowRuns = ([Text.Encoding]::UTF8.GetString($workflowRunsResponse.bytes) | ConvertFrom-Json -Depth 20)
    $approvalHistory = @([Text.Encoding]::UTF8.GetString($approvalsResponse.bytes) | ConvertFrom-Json -Depth 20)
    foreach ($field in @('id', 'run_attempt', 'event', 'status', 'conclusion', 'head_branch', 'head_sha', 'html_url', 'created_at', 'updated_at')) {
      Assert-True ([string]$liveRun.$field -ceq [string]$CapturedReadback.run.$field) "Live GitHub run $field differs from the captured readback."
    }
    foreach ($field in @('id', 'name', 'expired', 'digest', 'url', 'archive_download_url', 'created_at', 'updated_at')) {
      Assert-True ([string]$liveArtifact.$field -ceq [string]$CapturedReadback.artifact.$field) "Live GitHub artifact $field differs from the captured readback."
    }
    Assert-True ([string]$liveArtifact.workflow_run.id -ceq [string]$CapturedReadback.artifact.workflow_run.id) 'Live GitHub artifact run ID differs from the captured readback.'
    Assert-True ([string]$liveArtifact.workflow_run.head_sha -ceq [string]$CapturedReadback.artifact.workflow_run.head_sha) 'Live GitHub artifact head SHA differs from the captured readback.'
    Assert-True ([int64]$workflowRuns.total_count -eq 1) 'GitHub post-run one-shot read found more or fewer than one dispatch for the execution-control SHA.'
    $matchingRuns = @($workflowRuns.workflow_runs | Where-Object {
      [long]$_.id -eq $runId -and [int]$_.run_attempt -eq 1 -and
      [string]$_.event -ceq 'workflow_dispatch' -and [string]$_.head_sha -ceq [string]$Binding.head_sha
    })
    Assert-True ($matchingRuns.Count -eq 1) 'GitHub post-run one-shot read does not bind the exact run/attempt/head.'
    $reviewBinding = $Binding.environment_review
    Assert-True ([string]$liveRun.actor.login -ceq [string]$reviewBinding.actor_login) 'Live GitHub run actor differs from the Environment-review binding.'
    Assert-True ([string]$liveRun.triggering_actor.login -ceq [string]$reviewBinding.triggering_actor_login) 'Live GitHub triggering actor differs from the Environment-review binding.'
    $matchingReviews = @($approvalHistory | Where-Object {
      $environments = @($_.environments)
      $environments.Count -eq 1 -and [string]$environments[0].name -ceq [string]$reviewBinding.environment_name
    })
    Assert-True ($matchingReviews.Count -eq 1) 'GitHub review history does not contain exactly one bound Environment review.'
    $matchingReview = $matchingReviews[0]
    $matchingEnvironment = @($matchingReview.environments)[0]
    Assert-True ([string]$matchingReview.state -ceq 'approved') 'GitHub Environment review is not approved.'
    Assert-True ([string]$matchingEnvironment.id -ceq [string]$reviewBinding.environment_id) 'Live GitHub Environment ID differs from the evidence binding.'
    Assert-True ([string]$matchingReview.user.login -ceq [string]$reviewBinding.reviewer_login -and
      [string]$matchingReview.user.id -ceq [string]$reviewBinding.reviewer_id -and
      [string]$matchingReview.user.type -ceq [string]$reviewBinding.reviewer_type) 'Live GitHub reviewer identity differs from the evidence binding.'

    $archiveResponse = Get-HttpBytes $client ([string]$liveArtifact.archive_download_url) 33554432 'GitHub execution artifact'
    $archiveHost = $archiveResponse.final_uri.Host.ToLowerInvariant()
    Assert-True (
      $archiveHost -eq 'api.github.com' -or
      $archiveHost.EndsWith('.actions.githubusercontent.com') -or
      $archiveHost.EndsWith('.githubusercontent.com') -or
      $archiveHost.EndsWith('.blob.core.windows.net')
    ) 'GitHub artifact download redirected to an unexpected host.'
    $archiveSha256 = Get-BytesSha256 $archiveResponse.bytes
    Assert-True ([string]$liveArtifact.digest -ceq "sha256:$archiveSha256") 'Live GitHub artifact digest does not match the downloaded archive.'
    Assert-True ([string]$CapturedReadback.downloaded_archive_sha256 -eq $archiveSha256) 'Captured archive digest differs from the live GitHub download.'

    $archiveStream = [IO.MemoryStream]::new($archiveResponse.bytes, $false)
    try {
      $zip = [IO.Compression.ZipArchive]::new($archiveStream, [IO.Compression.ZipArchiveMode]::Read, $false)
      try {
        $evidenceLeafName = [IO.Path]::GetFileName($EvidenceFile)
        $sidecarLeafName = [IO.Path]::GetFileName($EvidenceSidecar)
        $environmentReviewLeafName = [IO.Path]::GetFileName($EnvironmentReviewFile)
        $environmentReviewSidecarLeafName = [IO.Path]::GetFileName($EnvironmentReviewSidecar)
        $evidenceEntries = @($zip.Entries | Where-Object { [IO.Path]::GetFileName($_.FullName) -ceq $evidenceLeafName })
        $sidecarEntries = @($zip.Entries | Where-Object { [IO.Path]::GetFileName($_.FullName) -ceq $sidecarLeafName })
        $environmentReviewEntries = @($zip.Entries | Where-Object { [IO.Path]::GetFileName($_.FullName) -ceq $environmentReviewLeafName })
        $environmentReviewSidecarEntries = @($zip.Entries | Where-Object { [IO.Path]::GetFileName($_.FullName) -ceq $environmentReviewSidecarLeafName })
        Assert-True ($evidenceEntries.Count -eq 1 -and $sidecarEntries.Count -eq 1 -and
          $environmentReviewEntries.Count -eq 1 -and $environmentReviewSidecarEntries.Count -eq 1) 'GitHub artifact must contain exactly one scale-evidence pair and one Environment-review pair.'
        $downloadedEvidence = [IO.MemoryStream]::new()
        $downloadedSidecar = [IO.MemoryStream]::new()
        $downloadedEnvironmentReview = [IO.MemoryStream]::new()
        $downloadedEnvironmentReviewSidecar = [IO.MemoryStream]::new()
        try {
          $entryStream = $evidenceEntries[0].Open()
          try { $entryStream.CopyTo($downloadedEvidence) } finally { $entryStream.Dispose() }
          $entryStream = $sidecarEntries[0].Open()
          try { $entryStream.CopyTo($downloadedSidecar) } finally { $entryStream.Dispose() }
          $entryStream = $environmentReviewEntries[0].Open()
          try { $entryStream.CopyTo($downloadedEnvironmentReview) } finally { $entryStream.Dispose() }
          $entryStream = $environmentReviewSidecarEntries[0].Open()
          try { $entryStream.CopyTo($downloadedEnvironmentReviewSidecar) } finally { $entryStream.Dispose() }
          Assert-True ((Get-BytesSha256 $downloadedEvidence.ToArray()) -eq $EvidenceDigest) 'Live GitHub artifact evidence bytes differ from the canonical evidence.'
          Assert-True ((Get-BytesSha256 $downloadedSidecar.ToArray()) -eq (Get-FileSha256 $EvidenceSidecar)) 'Live GitHub artifact sidecar bytes differ from the canonical sidecar.'
          Assert-True ((Get-BytesSha256 $downloadedEnvironmentReview.ToArray()) -eq $EnvironmentReviewDigest) 'Live GitHub artifact Environment-review bytes differ from the canonical review.'
          Assert-True ((Get-BytesSha256 $downloadedEnvironmentReviewSidecar.ToArray()) -eq $EnvironmentReviewSidecarDigest) 'Live GitHub artifact Environment-review sidecar bytes differ from the canonical sidecar.'
        } finally {
          $downloadedEvidence.Dispose()
          $downloadedSidecar.Dispose()
          $downloadedEnvironmentReview.Dispose()
          $downloadedEnvironmentReviewSidecar.Dispose()
        }
      } finally {
        $zip.Dispose()
      }
    } finally {
      $archiveStream.Dispose()
    }
  } catch {
    throw "Independent anonymous GitHub execution provenance validation failed closed: $($_.Exception.Message)"
  } finally {
    $client.Dispose()
    $handler.Dispose()
  }
}

function Test-UnderRoot([string]$Path, [string]$Root) {
  return $Path.StartsWith($Root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}

function Resolve-InputFile([string]$Path, [string]$Label, [string]$CanonicalPath = '') {
  $resolved = if ([IO.Path]::IsPathRooted($Path)) {
    [IO.Path]::GetFullPath($Path)
  } else {
    [IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
  }
  Assert-True (Test-Path -LiteralPath $resolved -PathType Leaf) "$Label is missing."
  $item = Get-Item -LiteralPath $resolved -Force
  Assert-True ([string]::IsNullOrEmpty([string]$item.LinkType)) "$Label must not be a symbolic link."
  if ($AllowTestPaths) {
    Assert-True (Test-UnderRoot $resolved $testRoot) "$Label test path is outside the allowed scratch root $testRoot."
  } elseif ($CanonicalPath) {
    Assert-True ($resolved.Equals($CanonicalPath, [StringComparison]::OrdinalIgnoreCase)) "$Label is not the canonical project file."
  } else {
    Assert-True (Test-UnderRoot $resolved $artifactRoot) "$Label is outside the immutable Phase-6 artifact directory."
  }
  return $resolved
}

function Resolve-BoundArtifact([string]$Path, [string]$Label) {
  $resolved = if ([IO.Path]::IsPathRooted($Path)) {
    [IO.Path]::GetFullPath($Path)
  } else {
    [IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
  }
  Assert-True (Test-Path -LiteralPath $resolved -PathType Leaf) "$Label is missing."
  $item = Get-Item -LiteralPath $resolved -Force
  Assert-True ([string]::IsNullOrEmpty([string]$item.LinkType)) "$Label must not be a symbolic link."
  if ($AllowTestPaths) {
    Assert-True (Test-UnderRoot $resolved $testRoot) "$Label test path is outside the allowed scratch root $testRoot."
  } else {
    Assert-True (Test-UnderRoot $resolved $repoRoot) "$Label is outside the repository."
  }
  return $resolved
}

function Read-JsonFile([string]$Path, [string]$Label) {
  try {
    $convertParameters = @{ Depth = 30; ErrorAction = 'Stop' }
    if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) {
      $convertParameters.DateKind = 'String'
    }
    return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json @convertParameters)
  } catch {
    throw "$Label is not valid JSON."
  }
}

function Assert-ExactProperties($Object, [string[]]$Expected, [string]$Label) {
  Assert-True ($null -ne $Object) "$Label is null."
  $actualNames = @($Object.PSObject.Properties.Name | Sort-Object)
  $expectedNames = @($Expected | Sort-Object)
  Assert-True (($actualNames -join '|') -ceq ($expectedNames -join '|')) "$Label property set mismatch."
}

function Get-Property($Object, [string]$Name, [string]$Label) {
  $property = if ($null -ne $Object) { $Object.PSObject.Properties[$Name] } else { $null }
  Assert-True ($null -ne $property) "$Label missing property: $Name"
  return $property.Value
}

function Assert-Boolean($Object, [string]$Name, [bool]$Expected, [string]$Label) {
  $value = Get-Property $Object $Name $Label
  Assert-True ($value -is [bool]) "$Label.$Name must be a boolean."
  Assert-True ([bool]$value -eq $Expected) "$Label.$Name mismatch."
}

function Assert-Integer($Object, [string]$Name, [long]$Expected, [string]$Label) {
  $value = Get-Property $Object $Name $Label
  $integerTypes = @([byte], [sbyte], [int16], [uint16], [int32], [uint32], [int64], [uint64])
  Assert-True (@($integerTypes | Where-Object { $value -is $_ }).Count -gt 0) "$Label.$Name must be an integer."
  Assert-True ([long]$value -eq $Expected) "$Label.$Name mismatch."
}

function Get-NonNegativeInteger($Object, [string]$Name, [string]$Label) {
  $value = Get-Property $Object $Name $Label
  $integerTypes = @([byte], [sbyte], [int16], [uint16], [int32], [uint32], [int64], [uint64])
  Assert-True (@($integerTypes | Where-Object { $value -is $_ }).Count -gt 0) "$Label.$Name must be an integer."
  Assert-True ([decimal]$value -ge 0 -and [decimal]$value -le [long]::MaxValue) "$Label.$Name must be nonnegative and fit Int64."
  return [long]$value
}

function Get-FiniteNonNegativeNumber($Object, [string]$Name, [string]$Label) {
  $value = Get-Property $Object $Name $Label
  Assert-True ($value -is [ValueType] -and $value -isnot [bool]) "$Label.$Name must be numeric."
  $number = [double]$value
  Assert-True (-not [double]::IsNaN($number) -and -not [double]::IsInfinity($number) -and $number -ge 0) "$Label.$Name must be finite and nonnegative."
  return $number
}

function Get-Percentile([double[]]$Values, [double]$Percentile) {
  Assert-True ($Values.Count -gt 0) 'Cannot compute a percentile for an empty series.'
  $sorted = @($Values | Sort-Object)
  $index = [Math]::Ceiling($Percentile * $sorted.Count) - 1
  if ($index -lt 0) { $index = 0 }
  if ($index -ge $sorted.Count) { $index = $sorted.Count - 1 }
  return [Math]::Round([double]$sorted[$index], 1)
}

function Assert-NumberEquals([double]$Actual, [double]$Expected, [string]$Label, [double]$Tolerance = 0.0000001) {
  Assert-True (-not [double]::IsNaN($Actual) -and -not [double]::IsInfinity($Actual)) "$Label must be finite."
  Assert-True ([Math]::Abs($Actual - $Expected) -le $Tolerance) "$Label mismatch."
}

function ConvertTo-UtcTimestamp([object]$Value, [string]$Label) {
  Assert-True ($Value -is [string] -and [string]$Value -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?Z$') "$Label must be an explicit UTC timestamp."
  $parsed = [DateTimeOffset]::MinValue
  Assert-True ([DateTimeOffset]::TryParse(
    [string]$Value,
    [Globalization.CultureInfo]::InvariantCulture,
    [Globalization.DateTimeStyles]::AssumeUniversal,
    [ref]$parsed
  )) "$Label is invalid."
  return $parsed.ToUniversalTime()
}

function Assert-NumberAtMost($Object, [string]$Name, [double]$Maximum, [string]$Label) {
  $value = Get-Property $Object $Name $Label
  Assert-True ($value -is [ValueType] -and $value -isnot [bool]) "$Label.$Name must be numeric."
  Assert-True ([double]$value -ge 0 -and [double]$value -le $Maximum) "$Label.$Name is outside the allowed range."
}

function Assert-EmptyArray($Value, [string]$Label) {
  Assert-True ($null -ne $Value) "$Label is null."
  Assert-True (@($Value).Count -eq 0) "$Label must be empty."
}

function Assert-ExactStringArray($Actual, [string[]]$Expected, [string]$Label) {
  $actualArray = @($Actual)
  Assert-True ($actualArray.Count -eq $Expected.Count) "$Label count mismatch."
  for ($index = 0; $index -lt $Expected.Count; $index++) {
    Assert-True ($actualArray[$index] -is [string] -and [string]$actualArray[$index] -ceq $Expected[$index]) "$Label item $index mismatch."
  }
}

function Assert-BoundedIdentifier([string]$Value, [int]$MaximumLength, [string]$Label) {
  Assert-True (-not [string]::IsNullOrWhiteSpace($Value)) "$Label is empty."
  Assert-True ($Value.Length -le $MaximumLength) "$Label exceeds $MaximumLength characters."
  Assert-True ($Value -match '^[A-Za-z0-9_.:-]+$') "$Label contains forbidden characters."
}

function Assert-BoundedText([string]$Value, [int]$MaximumLength, [string]$Label) {
  Assert-True (-not [string]::IsNullOrWhiteSpace($Value)) "$Label is empty."
  Assert-True ($Value.Length -le $MaximumLength) "$Label exceeds $MaximumLength characters."
  Assert-True ($Value -notmatch '[\x00-\x1f\x7f]') "$Label contains control characters."
}

function Get-RepositoryHeadSha {
  $head = (& git -C $repoRoot rev-parse HEAD 2>$null).Trim()
  Assert-True ($LASTEXITCODE -eq 0 -and $head -match '^[0-9a-f]{40}$') 'Repository HEAD identity is unavailable.'
  return $head
}

function Assert-RepositoryHeadBinding([string]$RecordedSha) {
  Assert-True ($RecordedSha -match '^[0-9a-f]{40}$') 'Repository HEAD binding is invalid.'
  $currentSha = Get-RepositoryHeadSha
  & git -C $repoRoot merge-base --is-ancestor $RecordedSha $currentSha
  Assert-True ($LASTEXITCODE -eq 0) 'Execution-control commit is not an ancestor of the current evidence HEAD.'
}

function Get-GitDelta([string]$FromSha, [string]$ToSha, [string]$Label) {
  foreach ($sha in @($FromSha, $ToSha)) {
    Assert-True ($sha -match '^[0-9a-f]{40}$') "$Label contains an invalid commit SHA."
    & git -C $repoRoot cat-file -e "$sha^{commit}" 2>$null
    Assert-True ($LASTEXITCODE -eq 0) "$Label commit is unavailable: $sha"
  }
  $lines = @(& git -C $repoRoot -c core.quotepath=false diff --no-renames --name-status $FromSha $ToSha --)
  Assert-True ($LASTEXITCODE -eq 0) "$Label cannot be resolved."
  $entries = @()
  foreach ($line in $lines) {
    Assert-True ([string]$line -match '^(?<status>[ACM])\t(?<path>[^\t\r\n]+)$') "$Label contains a deletion, rename, type change, or malformed path: $line"
    $entries += [pscustomobject]@{ status = [string]$matches.status; path = ([string]$matches.path).Replace('\', '/') }
  }
  return @($entries)
}

function Assert-TrackedCleanAgainstHead([string]$RelativePath) {
  & git -C $repoRoot ls-files --error-unmatch -- $RelativePath 2>$null | Out-Null
  Assert-True ($LASTEXITCODE -eq 0) "Canonical truth file is not tracked: $RelativePath"
  & git -C $repoRoot diff --quiet HEAD -- $RelativePath
  Assert-True ($LASTEXITCODE -eq 0) "Canonical truth file is not clean against HEAD: $RelativePath"
}

function Get-GitArchiveSha256([string]$CommitSha) {
  Assert-True ($CommitSha -match '^[0-9a-f]{40}$') 'Git archive source commit is invalid.'
  $temporaryRoot = $testRoot
  New-Item -ItemType Directory -Force -Path $temporaryRoot | Out-Null
  $temporaryPath = Join-Path $temporaryRoot "phase6-evidence-archive-$([Guid]::NewGuid().ToString('N')).tar"
  try {
    & git -C $repoRoot archive --format=tar "--output=$temporaryPath" $CommitSha
    Assert-True ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $temporaryPath -PathType Leaf)) 'Unable to recompute source archive.'
    return (Get-FileSha256 $temporaryPath)
  } finally {
    if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) { Remove-Item -LiteralPath $temporaryPath -Force }
  }
}

function Get-GateIdentity([object]$Gate) {
  $identity = [ordered]@{
    gate_id = 'phase6_scale_runtime'
    owner_granted = [bool](Get-Property $Gate 'owner_granted' 'phase6 gate')
    owner_grant_ref = [string](Get-Property $Gate 'owner_grant_ref' 'phase6 gate')
    paid_provider = [bool](Get-Property $Gate 'paid_provider' 'phase6 gate')
  }
  return ($identity | ConvertTo-Json -Compress)
}

$resolvedEvidence = Resolve-InputFile $EvidencePath 'Scale evidence'
$resolvedCriterion = Resolve-InputFile $CriterionPath 'Scale criterion' $canonicalCriterion
$resolvedHostedState = Resolve-InputFile $HostedStatePath 'Hosted state' $canonicalHostedState
$resolvedDeploymentPreflightState = Resolve-InputFile $DeploymentPreflightStatePath 'Phase6 deployment-preflight state' $canonicalDeploymentPreflightState
$resolvedCapabilityState = Resolve-InputFile $CapabilityStatePath 'Capability state' $canonicalCapabilityState
if ($Promote) {
  Assert-True (-not $AllowTestPaths) 'Promotion is forbidden in test-path mode.'
}
Assert-True (-not ($Promote -and $ValidateOnly)) 'Choose either promotion or non-mutating validation, not both.'
Assert-True (-not $TrustSyntheticGitHubReadbackForTests -or $AllowTestPaths) 'Synthetic GitHub trust is restricted to explicit test-path mode.'
if ($AllowTestPaths) {
  Assert-True ($TrustSyntheticGitHubReadbackForTests) 'Synthetic GitHub readback is untrusted unless the explicit test-only switch is present.'
}

$evidenceLeaf = [IO.Path]::GetFileName($resolvedEvidence)
$namePattern = '^scale-evidence-(?<stamp>[0-9]{8}T[0-9]{9}Z)-(?<run>[0-9a-f]{32})\.json$'
Assert-True ($evidenceLeaf -match $namePattern) 'Evidence filename is not immutable/timestamped.'
$filenameStamp = $matches.stamp
$filenameRunId = $matches.run
$companionPath = "$resolvedEvidence.sha256"
Assert-True (Test-Path -LiteralPath $companionPath -PathType Leaf) 'Evidence SHA-256 companion is missing.'
$companionItem = Get-Item -LiteralPath $companionPath -Force
Assert-True ([string]::IsNullOrEmpty([string]$companionItem.LinkType)) 'Evidence SHA-256 companion must not be a symbolic link.'
$companion = Get-Content -LiteralPath $companionPath -Raw
Assert-True ($companion -match '^([0-9a-fA-F]{64})  ([^\\/\r\n]+)\r?\n?$') 'Evidence SHA-256 companion format is invalid.'
$evidenceSha256 = Get-FileSha256 $resolvedEvidence
Assert-True ($matches[1].ToLowerInvariant() -eq $evidenceSha256) 'Evidence SHA-256 companion digest mismatch.'
Assert-True ($matches[2] -ceq $evidenceLeaf) 'Evidence SHA-256 companion filename mismatch.'
$expectedExecutionReadbackPath = "$resolvedEvidence.execution-readback.json"
if ([string]::IsNullOrWhiteSpace($ExecutionReadbackPath)) { $ExecutionReadbackPath = $expectedExecutionReadbackPath }
$resolvedExecutionReadback = Resolve-InputFile $ExecutionReadbackPath 'GitHub execution readback'
Assert-True ($resolvedExecutionReadback.Equals($expectedExecutionReadbackPath, [StringComparison]::OrdinalIgnoreCase)) 'GitHub execution readback path must be the immutable evidence companion.'
$executionReadbackLeaf = [IO.Path]::GetFileName($resolvedExecutionReadback)
$executionReadbackCompanionPath = "$resolvedExecutionReadback.sha256"
Assert-True (Test-Path -LiteralPath $executionReadbackCompanionPath -PathType Leaf) 'GitHub execution-readback SHA-256 companion is missing.'
$executionReadbackCompanion = Get-Content -LiteralPath $executionReadbackCompanionPath -Raw
Assert-True ($executionReadbackCompanion -match '^([0-9a-fA-F]{64})  ([^\\/\r\n]+)\r?\n?$') 'GitHub execution-readback SHA-256 companion format is invalid.'
$executionReadbackSha256 = Get-FileSha256 $resolvedExecutionReadback
Assert-True ($matches[1].ToLowerInvariant() -eq $executionReadbackSha256) 'GitHub execution-readback SHA-256 companion digest mismatch.'
Assert-True ($matches[2] -ceq $executionReadbackLeaf) 'GitHub execution-readback SHA-256 companion filename mismatch.'
if (-not $AllowTestPaths) {
  foreach ($path in @($resolvedEvidence, $companionPath, $resolvedExecutionReadback, $executionReadbackCompanionPath)) {
    $relative = [IO.Path]::GetRelativePath($repoRoot, $path).Replace('\', '/')
    Assert-TrackedCleanAgainstHead $relative
  }
}

$criterion = Read-JsonFile $resolvedCriterion 'Scale criterion'
$hostedState = Read-JsonFile $resolvedHostedState 'Hosted state'
$deploymentPreflightState = Read-JsonFile $resolvedDeploymentPreflightState 'Phase6 deployment-preflight state'
$capabilityState = Read-JsonFile $resolvedCapabilityState 'Capability state'
$evidenceRaw = Get-Content -LiteralPath $resolvedEvidence -Raw
$evidence = Read-JsonFile $resolvedEvidence 'Scale evidence'
$executionReadback = Read-JsonFile $resolvedExecutionReadback 'GitHub execution readback'

Assert-True ($evidenceRaw -notmatch '(?i)(?:sk-|ghp_|github_pat_|glpat-|cfat_|vck_|hf_)[A-Za-z0-9_-]{12,}') 'Evidence contains secret-shaped material.'
Assert-True ($evidenceRaw -notmatch '(?i)"(?:authorization|cookie|password|private_key|client_secret|token_value|auth_value|credential_value)"\s*:') 'Evidence contains a forbidden credential field.'

Assert-True ([string]$criterion.contract_version -eq 'phase6-scale-criterion-v2') 'Scale criterion contract mismatch.'
Assert-True ([bool]$criterion.declared_before_first_run) 'Scale criterion was not pre-declared.'
Assert-True ([bool]$criterion.declared_before_first_full_write_run) 'Scale criterion v2 was not declared before the first full write run.'
Assert-True ([bool]$criterion.envelope.zero_card) 'Scale criterion is not zero-card.'
Assert-True ([bool]$criterion.envelope.payment_forbidden) 'Scale criterion permits payment.'
Assert-True ([bool]$criterion.envelope.paid_fallback_forbidden) 'Scale criterion permits paid fallback.'
Assert-True ([string]$hostedState.contract_version -eq 'cloudflare-native-hosted-current-v1') 'Canonical hosted-state contract mismatch.'
Assert-True ([string]$hostedState.status -eq 'verified') 'Canonical hosted runtime state is not verified.'
Assert-True ([string]$hostedState.runtime_contract_version -eq 'cloudflare-native-runtime-candidate-v2') 'Canonical hosted runtime contract is invalid.'
Assert-True ([string]$hostedState.base_url -match '^https://[^/]+\.workers\.dev$') 'Canonical hosted runtime origin is invalid.'
Assert-True ([string]$hostedState.source_commit_sha -match '^[0-9a-f]{40}$') 'Canonical hosted source commit SHA is invalid.'
Assert-True ([string]$hostedState.source_archive_sha256 -match '^[0-9a-f]{64}$') 'Canonical hosted source archive SHA-256 is invalid.'
Assert-True ($hostedState.hosted_proof -eq $true -and $hostedState.dev_only -eq $false) 'Canonical hosted runtime is not a non-DEV hosted proof.'
Assert-True ($hostedState.hosted_source_parity_verified -eq $true -and $hostedState.hosted_stateful_roundtrip_verified -eq $true) 'Canonical hosted source/stateful proof is incomplete.'
Assert-True ($hostedState.create_enqueue_queue_do_d1_artifact_roundtrip -eq $true -and $hostedState.d1_artifact_write_read_delete_verified -eq $true) 'Canonical O2Core write/read/delete proof is incomplete.'
Assert-True ($hostedState.zero_card_verified -eq $true -and $hostedState.paid_provider -eq $false -and $hostedState.secret_output -eq $false) 'Canonical hosted proof violates zero-card or secret-output policy.'

Assert-ExactProperties $deploymentPreflightState @(
  'contract_version', 'status', 'verified_at_utc', 'base_url', 'runtime_contract_version',
  'health_contract_version', 'source_commit_sha', 'source_archive_sha256', 'source_bundle_sha256',
  'worker_version_id', 'deployment_id', 'evidence_artifact', 'evidence_sha256', 'health_status',
  'd1_read_verified', 'production_worker_request_count', 'preview_worker_request_count',
  'deployment_preflight_verified', 'health_json_source_binding_verified',
  'preview_guard_verified', 'preview_guard_verified_at_utc', 'preview_worker_version_id', 'preview_deployment_id',
  'hosted_write_read_delete_verified', 'phase6_scale_run_started', 'phase6_scale_run_verified',
  'zero_card_verified', 'paid_provider', 'dev_only', 'secret_output', 'non_claims'
) 'Hosted deployment state'
Assert-True ([string]$deploymentPreflightState.contract_version -eq 'phase6-scale-hosted-deployment-current-v1') 'Hosted deployment state contract mismatch.'
Assert-True ([string]$deploymentPreflightState.status -eq 'preflight_verified' -and $deploymentPreflightState.deployment_preflight_verified -eq $true) 'Hosted deployment preflight is not verified.'
Assert-True ([string]$deploymentPreflightState.runtime_contract_version -eq 'cloudflare-native-runtime-candidate-v2' -and [string]$deploymentPreflightState.health_contract_version -eq 'cloudflare-d1-stateful-runtime-v1') 'Hosted deployment runtime contracts are invalid.'
Assert-True ($deploymentPreflightState.health_status -eq 200 -and $deploymentPreflightState.d1_read_verified -eq $true -and $deploymentPreflightState.health_json_source_binding_verified -eq $true) 'Hosted deployment preflight lacks its single health HTTP 200 binding.'
Assert-Integer $deploymentPreflightState 'production_worker_request_count' 1 'Hosted deployment preflight'
Assert-Integer $deploymentPreflightState 'preview_worker_request_count' 0 'Hosted deployment preflight'
Assert-True ($deploymentPreflightState.preview_guard_verified -eq $true) 'Hosted deployment preflight lacks the zero-request Preview guard.'
Assert-True ($deploymentPreflightState.hosted_write_read_delete_verified -eq $false) 'Hosted deployment preflight must explicitly deny write/read/delete proof.'
Assert-True ($deploymentPreflightState.phase6_scale_run_started -eq $false -and $deploymentPreflightState.phase6_scale_run_verified -eq $false) 'Hosted deployment state falsely claims a Phase6 run.'
Assert-True (-not [bool]$deploymentPreflightState.dev_only) 'Hosted deployment state is DEV-only.'
Assert-True ([bool]$deploymentPreflightState.zero_card_verified -and -not [bool]$deploymentPreflightState.paid_provider) 'Hosted deployment state is not zero-card.'
Assert-True ([string]$deploymentPreflightState.source_commit_sha -match '^[0-9a-f]{40}$') 'Hosted deployment source commit SHA is invalid.'
Assert-True ([string]$deploymentPreflightState.source_archive_sha256 -match '^[0-9a-f]{64}$') 'Hosted deployment source archive SHA-256 is invalid.'
Assert-True ([string]$deploymentPreflightState.source_bundle_sha256 -match '^[0-9a-f]{64}$') 'Hosted deployment source bundle SHA-256 is invalid.'
foreach ($idField in @('worker_version_id', 'deployment_id', 'preview_worker_version_id', 'preview_deployment_id')) {
  Assert-True ([string]$deploymentPreflightState.$idField -match '^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$') "Hosted deployment $idField is invalid."
}
Assert-True ([string]$deploymentPreflightState.preview_worker_version_id -cne [string]$deploymentPreflightState.worker_version_id -and [string]$deploymentPreflightState.preview_deployment_id -cne [string]$deploymentPreflightState.deployment_id) 'Preview and production deployment identities are not isolated.'
Assert-True ([string]$hostedState.source_commit_sha -ceq [string]$deploymentPreflightState.source_commit_sha -and [string]$hostedState.source_archive_sha256 -ceq [string]$deploymentPreflightState.source_archive_sha256) 'Canonical O2Core and Phase6 deployment preflight bind different sources.'
Assert-True ([string]$criterion.target.base_url -eq [string]$hostedState.base_url -and [string]$criterion.target.base_url -eq [string]$deploymentPreflightState.base_url) 'Criterion and hosted states origins differ.'
Assert-True (
  [string]$criterion.control_tier.not_a_pass_criterion -eq
  'This block adds a measurement control only. It changes no threshold in pass_criteria.'
) 'Scale criterion edge control is not attribution-only.'
Assert-True ($criterion.write_tier.http_429_allowed -eq $false) 'Scale criterion permits throttled writes.'
Assert-True ([string]$criterion.write_tier.cleanup_semantics -eq 'soft_delete_then_active_row_absence_and_audit_readback') 'Scale criterion cleanup semantics mismatch.'
Assert-True ([string]$criterion.pass_criteria.http_429_scope -eq 'health_read_tiers_only') 'Scale criterion 429 scope mismatch.'
$canonicalHostedEvidencePath = Resolve-BoundArtifact ([string]$hostedState.evidence_artifact) 'Canonical O2Core hosted evidence'
$canonicalHostedEvidenceRelativePath = [IO.Path]::GetRelativePath($repoRoot, $canonicalHostedEvidencePath).Replace('\', '/')
$canonicalHostedEvidenceSha256 = Get-FileSha256 $canonicalHostedEvidencePath
Assert-True ([string]$hostedState.evidence_sha256 -match '^[0-9a-fA-F]{64}$' -and $canonicalHostedEvidenceSha256 -eq ([string]$hostedState.evidence_sha256).ToLowerInvariant()) 'Canonical O2Core hosted evidence file hash mismatch.'
$canonicalHostedEvidence = Read-JsonFile $canonicalHostedEvidencePath 'Canonical O2Core hosted evidence'
Assert-True ([string]$canonicalHostedEvidence.contract_version -eq 'cloudflare-d1-stateful-runtime-hosted-proof-v1' -and [string]$canonicalHostedEvidence.status -eq 'verified') 'Canonical O2Core hosted evidence contract is invalid.'
Assert-True ([string]$canonicalHostedEvidence.base_url -ceq [string]$hostedState.base_url) 'Canonical O2Core hosted evidence base URL mismatch.'
Assert-True ([string]$canonicalHostedEvidence.source_commit_sha -ceq [string]$hostedState.source_commit_sha -and [string]$canonicalHostedEvidence.source_archive_sha256 -ceq [string]$hostedState.source_archive_sha256) 'Canonical O2Core hosted evidence source mismatch.'
Assert-True ($canonicalHostedEvidence.cloudflare_native_hosted_source_parity_verified -eq $true -and $canonicalHostedEvidence.cloudflare_native_create_enqueue_queue_do_d1_artifact_roundtrip -eq $true -and $canonicalHostedEvidence.cloudflare_native_d1_artifact_write_read_delete -eq $true) 'Canonical O2Core hosted evidence lacks source/W-R-D proof.'
Assert-True ($canonicalHostedEvidence.cloudflare_native_d1_read_verified -eq $true -and $canonicalHostedEvidence.cloudflare_native_zero_card_execution_verified -eq $true -and $canonicalHostedEvidence.cloudflare_native_paid_fallback_used -eq $false -and $canonicalHostedEvidence.secret_output -eq $false) 'Canonical O2Core hosted evidence violates D1, zero-card, or secret-output policy.'
if (-not $AllowTestPaths) {
  Assert-TrackedCleanAgainstHead $canonicalHostedEvidenceRelativePath
}

$deploymentEvidencePath = Resolve-BoundArtifact ([string]$deploymentPreflightState.evidence_artifact) 'Hosted deployment evidence'
$deploymentEvidenceSha256 = Get-FileSha256 $deploymentEvidencePath
Assert-True ([string]$deploymentPreflightState.evidence_sha256 -match '^[0-9a-fA-F]{64}$' -and $deploymentEvidenceSha256 -eq ([string]$deploymentPreflightState.evidence_sha256).ToLowerInvariant()) 'Hosted deployment evidence file hash mismatch.'
$deploymentEvidenceSidecarPath = "$deploymentEvidencePath.sha256"
Assert-True (Test-Path -LiteralPath $deploymentEvidenceSidecarPath -PathType Leaf) 'Hosted deployment evidence digest sidecar is missing.'
$deploymentEvidenceSidecar = Get-Content -LiteralPath $deploymentEvidenceSidecarPath -Raw
Assert-True ($deploymentEvidenceSidecar -match '^([0-9a-fA-F]{64})  ([^\\/\r\n]+)\r?\n?$') 'Hosted deployment evidence digest sidecar format is invalid.'
Assert-True ($matches[1].ToLowerInvariant() -eq $deploymentEvidenceSha256 -and $matches[2] -ceq [IO.Path]::GetFileName($deploymentEvidencePath)) 'Hosted deployment evidence digest sidecar mismatch.'
$deploymentEvidence = Read-JsonFile $deploymentEvidencePath 'Hosted deployment evidence'
Assert-ExactProperties $deploymentEvidence @(
  'contract_version', 'verified_at_utc', 'status', 'purpose', 'base_url', 'source_commit_sha',
  'source_archive_sha256', 'source_bundle_sha256', 'worker_version_id', 'deployment_id', 'health_status',
  'd1_read_verified', 'production_worker_request_count', 'preview_worker_request_count',
  'source_binding_verified', 'health_json_source_binding_verified', 'preview_guard_verified',
  'preview_guard_verified_at_utc', 'preview_worker_version_id', 'preview_deployment_id',
  'hosted_write_read_delete_verified', 'phase6_scale_run_started', 'phase6_scale_run_verified',
  'zero_card', 'paid_provider', 'dev_only', 'secret_output', 'producer', 'writer', 'non_claims'
) 'Hosted deployment preflight evidence'
Assert-True ([string]$deploymentEvidence.contract_version -eq 'phase6-scale-deployment-preflight-evidence-v1') 'Hosted deployment evidence is not the immutable Phase6 preflight contract.'
Assert-True ([string]$deploymentEvidence.status -eq 'verified' -and [string]$deploymentEvidence.purpose -eq 'phase6_scale_single_run_preflight') 'Hosted deployment preflight status or purpose is invalid.'
Assert-True ([string]$deploymentEvidence.base_url -eq [string]$deploymentPreflightState.base_url) 'Hosted deployment base URL mismatch.'
Assert-True ([string]$deploymentEvidence.source_commit_sha -eq [string]$deploymentPreflightState.source_commit_sha) 'Hosted deployment source commit mismatch.'
Assert-True ([string]$deploymentEvidence.source_archive_sha256 -eq [string]$deploymentPreflightState.source_archive_sha256) 'Hosted deployment source archive mismatch.'
Assert-True ([string]$deploymentEvidence.source_bundle_sha256 -eq [string]$deploymentPreflightState.source_bundle_sha256) 'Hosted deployment source bundle mismatch.'
Assert-True ([string]$deploymentEvidence.worker_version_id -eq [string]$deploymentPreflightState.worker_version_id -and [string]$deploymentEvidence.deployment_id -eq [string]$deploymentPreflightState.deployment_id) 'Hosted deployment identity mismatch.'
Assert-True ([string]$deploymentEvidence.preview_worker_version_id -eq [string]$deploymentPreflightState.preview_worker_version_id -and [string]$deploymentEvidence.preview_deployment_id -eq [string]$deploymentPreflightState.preview_deployment_id) 'Preview deployment identity mismatch.'
Assert-True ($deploymentEvidence.health_status -eq 200 -and $deploymentEvidence.d1_read_verified -eq $true) 'Hosted deployment evidence lacks its single health HTTP 200.'
Assert-Integer $deploymentEvidence 'production_worker_request_count' 1 'Hosted deployment evidence'
Assert-Integer $deploymentEvidence 'preview_worker_request_count' 0 'Hosted deployment evidence'
Assert-True ($deploymentEvidence.source_binding_verified -eq $true -and $deploymentEvidence.health_json_source_binding_verified -eq $true -and $deploymentEvidence.preview_guard_verified -eq $true) 'Hosted deployment evidence lacks source-bound Preview/health proof.'
Assert-True ($deploymentEvidence.hosted_write_read_delete_verified -eq $false) 'Hosted deployment preflight must explicitly deny write/read/delete proof.'
Assert-True ($deploymentEvidence.phase6_scale_run_started -eq $false -and $deploymentEvidence.phase6_scale_run_verified -eq $false) 'Hosted deployment preflight falsely claims Phase6 execution.'
Assert-True ($deploymentEvidence.zero_card -eq $true -and $deploymentEvidence.paid_provider -eq $false -and $deploymentEvidence.dev_only -eq $false -and $deploymentEvidence.secret_output -eq $false) 'Hosted deployment evidence violates zero-card, DEV, or secret-output policy.'
Assert-True ([string]$deploymentEvidence.producer -ceq 'scripts/deploy-cloudflare-stateful-runtime.ps1' -and [string]$deploymentEvidence.writer -ceq 'scripts/write-phase6-scale-deployment-preflight.ps1') 'Hosted deployment preflight producer identity is invalid.'
$deploymentTimestampProperty = @('verified_at_utc', 'checked_at') | Where-Object { $null -ne $deploymentEvidence.PSObject.Properties[$_] } | Select-Object -First 1
Assert-True (-not [string]::IsNullOrWhiteSpace([string]$deploymentTimestampProperty)) 'Hosted deployment evidence has no verification timestamp.'
$deploymentVerifiedAt = ConvertTo-UtcTimestamp (Get-Property $deploymentEvidence $deploymentTimestampProperty 'Hosted deployment evidence') 'Hosted deployment evidence timestamp'
$deploymentStateVerifiedAt = ConvertTo-UtcTimestamp $deploymentPreflightState.verified_at_utc 'Deployment-preflight state verification timestamp'
$previewGuardVerifiedAt = ConvertTo-UtcTimestamp $deploymentPreflightState.preview_guard_verified_at_utc 'Preview-guard verification timestamp'
Assert-True ($deploymentVerifiedAt -eq $deploymentStateVerifiedAt) 'Hosted deployment evidence and deployment-preflight state timestamps differ.'
Assert-True ((ConvertTo-UtcTimestamp $deploymentEvidence.preview_guard_verified_at_utc 'Deployment-preflight evidence Preview timestamp') -eq $previewGuardVerifiedAt) 'Preview timestamp differs between state and evidence.'
Assert-True ($previewGuardVerifiedAt -le $deploymentVerifiedAt) 'Preview guard did not precede production deployment verification.'
Assert-True (($deploymentVerifiedAt - $previewGuardVerifiedAt).TotalMinutes -le 10) 'Preview-to-production deployment window exceeded ten minutes.'
if (-not $AllowTestPaths) {
  $deploymentRelativePath = [IO.Path]::GetRelativePath($repoRoot, $deploymentEvidencePath).Replace('\', '/')
  Assert-TrackedCleanAgainstHead $deploymentRelativePath
  Assert-TrackedCleanAgainstHead "$deploymentRelativePath.sha256"
}

$topProperties = @(
  'contract_version', 'generated_at_utc', 'run_id', 'result', 'criterion_binding', 'source_binding',
  'request_budget', 'read_tiers', 'health_validation', 'write_tier', 'cleanup', 'aggregate', 'auth',
  'gate_may_open', 'gate_promotion_performed', 'percentage_credit_awarded', 'non_claims'
)
Assert-ExactProperties $evidence $topProperties 'evidence'
Assert-True ([string]$evidence.contract_version -eq 'phase6-scale-evidence-v2') 'Evidence contract mismatch.'
Assert-True ([string]$evidence.result -eq 'provisional_pending_github_readback') 'Evidence did not preserve its provisional post-run status.'
Assert-True ([string]$evidence.run_id -ceq $filenameRunId) 'Evidence run ID does not match its filename.'
$generatedAt = [DateTimeOffset]::MinValue
Assert-True ([string]$evidence.generated_at_utc -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{7}Z$') 'Evidence timestamp must use the UTC round-trip shape.'
Assert-True ([DateTimeOffset]::TryParse([string]$evidence.generated_at_utc, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$generatedAt)) 'Evidence timestamp is invalid.'
Assert-True ($generatedAt.ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ') -eq $filenameStamp) 'Evidence timestamp does not match its filename.'
$declaredAt = [DateTimeOffset]::Parse([string]$criterion.declared_at_utc, [Globalization.CultureInfo]::InvariantCulture)
Assert-True ($generatedAt -ge $declaredAt) 'Evidence predates the declared criterion.'
$hostedVerifiedAt = ConvertTo-UtcTimestamp $hostedState.verified_at_utc 'Hosted-state verification timestamp'
$canonicalEvidenceCheckedAt = ConvertTo-UtcTimestamp $canonicalHostedEvidence.checked_at 'Canonical O2Core evidence timestamp'
Assert-True ($hostedVerifiedAt -ge $declaredAt -and $canonicalEvidenceCheckedAt -eq $hostedVerifiedAt) 'Canonical O2Core state/evidence timestamp binding is invalid.'
Assert-True ($generatedAt -ge $hostedVerifiedAt -and ($generatedAt - $hostedVerifiedAt).TotalHours -le 24) 'Scale evidence is stale relative to the canonical O2Core proof.'
Assert-True ($generatedAt -ge $deploymentStateVerifiedAt -and ($generatedAt - $deploymentStateVerifiedAt).TotalHours -le 24) 'Scale evidence is stale relative to the deployment preflight.'
Assert-True ($generatedAt -ge $previewGuardVerifiedAt -and ($generatedAt - $previewGuardVerifiedAt).TotalHours -le 24) 'Scale evidence is stale relative to the Preview guard.'
Assert-True ($generatedAt -le [DateTimeOffset]::UtcNow.AddMinutes(5)) 'Evidence timestamp is in the future.'

Assert-ExactProperties $evidence.criterion_binding @('contract_version', 'gate_id', 'file_sha256', 'declared_before_first_run', 'declared_before_first_full_write_run') 'criterion binding'
Assert-True ([string]$evidence.criterion_binding.contract_version -eq [string]$criterion.contract_version) 'Evidence criterion contract binding mismatch.'
Assert-True ([string]$evidence.criterion_binding.gate_id -eq 'phase6_scale_runtime') 'Evidence gate binding mismatch.'
Assert-True ([string]$evidence.criterion_binding.file_sha256 -eq (Get-FileSha256 $resolvedCriterion)) 'Evidence criterion file hash mismatch.'
Assert-Boolean $evidence.criterion_binding 'declared_before_first_run' $true 'criterion binding'
Assert-Boolean $evidence.criterion_binding 'declared_before_first_full_write_run' $true 'criterion binding'

$sourceProperties = @(
  'hosted_state_contract_version', 'hosted_state_file_sha256',
  'hosted_runtime_evidence_artifact', 'hosted_runtime_evidence_sha256',
  'deployment_preflight_state_contract_version', 'deployment_preflight_state_file_sha256',
  'base_url', 'source_commit_sha',
  'source_archive_sha256', 'source_bundle_sha256', 'deployment_evidence_artifact', 'deployment_evidence_sha256',
  'worker_version_id', 'deployment_id', 'preview_guard_verified', 'preview_guard_verified_at_utc',
  'preview_worker_version_id', 'preview_deployment_id', 'verifier_script_sha256', 'repository_head_sha',
  'capability_state_sha256', 'gate_identity_sha256', 'owner_granted', 'owner_grant_ref',
  'health_json_source_binding_verified', 'execution_attestation'
)
Assert-ExactProperties $evidence.source_binding $sourceProperties 'source binding'
Assert-True ([string]$evidence.source_binding.hosted_state_contract_version -eq [string]$hostedState.contract_version) 'Hosted state contract binding mismatch.'
Assert-True ([string]$evidence.source_binding.hosted_state_file_sha256 -eq (Get-FileSha256 $resolvedHostedState)) 'Hosted state file hash mismatch.'
Assert-True ([string]$evidence.source_binding.hosted_runtime_evidence_artifact -eq [string]$hostedState.evidence_artifact) 'Canonical O2Core evidence path binding mismatch.'
Assert-True ([string]$evidence.source_binding.hosted_runtime_evidence_sha256 -ieq $canonicalHostedEvidenceSha256) 'Canonical O2Core evidence hash binding mismatch.'
Assert-True ([string]$evidence.source_binding.deployment_preflight_state_contract_version -eq [string]$deploymentPreflightState.contract_version) 'Deployment-preflight state contract binding mismatch.'
Assert-True ([string]$evidence.source_binding.deployment_preflight_state_file_sha256 -eq (Get-FileSha256 $resolvedDeploymentPreflightState)) 'Deployment-preflight state file hash mismatch.'
Assert-True ([string]$evidence.source_binding.base_url -eq [string]$criterion.target.base_url) 'Evidence base URL mismatch.'
Assert-True ([string]$evidence.source_binding.source_commit_sha -eq [string]$hostedState.source_commit_sha) 'Evidence source commit mismatch.'
Assert-True ([string]$evidence.source_binding.source_archive_sha256 -eq [string]$hostedState.source_archive_sha256) 'Evidence source archive mismatch.'
Assert-True ([string]$evidence.source_binding.source_bundle_sha256 -eq [string]$deploymentPreflightState.source_bundle_sha256) 'Evidence source bundle mismatch.'
Assert-True ([string]$evidence.source_binding.deployment_evidence_artifact -eq [string]$deploymentPreflightState.evidence_artifact) 'Deployment evidence path binding mismatch.'
Assert-True ([string]$evidence.source_binding.deployment_evidence_sha256 -match '^[0-9a-fA-F]{64}$' -and [string]$evidence.source_binding.deployment_evidence_sha256 -ieq [string]$deploymentPreflightState.evidence_sha256) 'Deployment evidence SHA-256 binding mismatch.'
Assert-True ([string]$evidence.source_binding.worker_version_id -match '^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$') 'Worker version ID binding is invalid.'
Assert-True ([string]$evidence.source_binding.deployment_id -match '^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$') 'Deployment ID binding is invalid.'
Assert-True ([string]$evidence.source_binding.worker_version_id -eq [string]$deploymentEvidence.worker_version_id) 'Worker version ID does not match deployment evidence.'
Assert-True ([string]$evidence.source_binding.deployment_id -eq [string]$deploymentEvidence.deployment_id) 'Deployment ID does not match deployment evidence.'
Assert-Boolean $evidence.source_binding 'preview_guard_verified' $true 'source binding'
Assert-True ([string]$evidence.source_binding.preview_guard_verified_at_utc -ceq [string]$deploymentEvidence.preview_guard_verified_at_utc) 'Preview timestamp binding mismatch.'
Assert-True ([string]$evidence.source_binding.preview_worker_version_id -ceq [string]$deploymentEvidence.preview_worker_version_id -and [string]$evidence.source_binding.preview_deployment_id -ceq [string]$deploymentEvidence.preview_deployment_id) 'Preview deployment identity binding mismatch.'
Assert-Boolean $evidence.source_binding 'owner_granted' $true 'source binding'
Assert-BoundedIdentifier ([string]$evidence.source_binding.owner_grant_ref) 256 'Evidence Owner grant reference'
Assert-Boolean $evidence.source_binding 'health_json_source_binding_verified' $true 'source binding'
$executionBinding = $evidence.source_binding.execution_attestation
Assert-ExactProperties $executionBinding @(
  'contract_version', 'status', 'binding_mode', 'github_actions', 'repository', 'run_id', 'run_attempt',
  'run_url', 'event_name', 'ref', 'head_sha', 'workflow', 'workflow_ref', 'job',
  'source_commit_sha', 'control_delta', 'artifact_name', 'environment_review',
  'post_run_api_readback_required', 'verified'
) 'execution attestation binding'
Assert-True ([string]$executionBinding.contract_version -eq 'phase6-scale-execution-provenance-v1') 'Execution-attestation binding contract mismatch.'
Assert-True ([string]$executionBinding.status -eq 'provisional_pending_github_readback') 'Execution-attestation binding status is not provisional.'
Assert-True ([string]$executionBinding.binding_mode -eq 'source_control_allowlist_v1') 'Execution-attestation binding mode mismatch.'
Assert-Boolean $executionBinding 'github_actions' $true 'execution attestation binding'
Assert-Boolean $executionBinding 'post_run_api_readback_required' $true 'execution attestation binding'
Assert-Boolean $executionBinding 'verified' $false 'execution attestation binding'
$executionRunId = Get-NonNegativeInteger $executionBinding 'run_id' 'execution attestation binding'
$executionRunAttempt = Get-NonNegativeInteger $executionBinding 'run_attempt' 'execution attestation binding'
Assert-True ($executionRunId -gt 0 -and $executionRunAttempt -eq 1) 'Execution must be the first and only run attempt.'
Assert-True ([string]$executionBinding.repository -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') 'Execution repository is invalid.'
$expectedRunUrl = "https://github.com/$([string]$executionBinding.repository)/actions/runs/$executionRunId"
Assert-True ([string]$executionBinding.run_url -ceq $expectedRunUrl) 'Execution run URL mismatch.'
Assert-True ([string]$executionBinding.event_name -eq 'workflow_dispatch') 'Scale execution must use an explicit workflow_dispatch run.'
Assert-True ([string]$executionBinding.ref -match '^refs/heads/[^\s]+$') 'Execution ref must be a branch ref.'
Assert-True ([string]$executionBinding.head_sha -eq [string]$evidence.source_binding.repository_head_sha) 'Execution head SHA mismatch.'
Assert-True ([string]$executionBinding.source_commit_sha -eq [string]$hostedState.source_commit_sha) 'Execution deployed-source binding mismatch.'
Assert-True ([string]$executionBinding.head_sha -ne [string]$executionBinding.source_commit_sha) 'Execution control and deployed-source commits must have distinct roles.'
& git -C $repoRoot merge-base --is-ancestor ([string]$executionBinding.source_commit_sha) ([string]$executionBinding.head_sha)
Assert-True ($LASTEXITCODE -eq 0) 'Deployed source is not an ancestor of the execution-control commit.'
$recordedControlDelta = @($executionBinding.control_delta | ForEach-Object { [string]$_ } | Sort-Object -Unique)
$workflowPathMatch = [regex]::Match([string]$executionBinding.workflow_ref, '/(?<path>\.github/workflows/phase6-scale-runtime\.ya?ml)@')
Assert-True ($workflowPathMatch.Success) 'Execution workflow_ref does not identify the dedicated Phase6 scale workflow.'
$allowedControlPaths = @(
  [string]$workflowPathMatch.Groups['path'].Value,
  'docs/runtime-state/phase6-scale-criterion.json',
  'docs/runtime-state/cloudflare-native-hosted-current.json',
  'docs/runtime-state/phase6-scale-hosted-current.json',
  'docs/runtime-state/capability-gates.json',
  ([string]$evidence.source_binding.hosted_runtime_evidence_artifact).Replace('\', '/'),
  ([string]$evidence.source_binding.deployment_evidence_artifact).Replace('\', '/'),
  (([string]$evidence.source_binding.deployment_evidence_artifact).Replace('\', '/') + '.sha256'),
  'scripts/verify-phase6-scale-runtime.ps1',
  'scripts/verify-phase6-scale-runtime-static.ps1',
  'scripts/verify-phase6-scale-evidence.ps1',
  'scripts/verify-phase6-scale-evidence-static.ps1',
  'scripts/collect-phase6-scale-execution-readback.ps1',
  'scripts/write-phase6-scale-deployment-preflight.ps1',
  'scripts/write-phase6-scale-deployment-preflight-static.ps1'
) | Sort-Object -Unique
$controlDeltaPaths = @(if ($AllowTestPaths) {
  @($recordedControlDelta)
} else {
  $controlDeltaEntries = @(Get-GitDelta ([string]$executionBinding.source_commit_sha) ([string]$executionBinding.head_sha) 'Source-to-control delta')
  @($controlDeltaEntries.path | Sort-Object -Unique)
})
Assert-True ($controlDeltaPaths.Count -gt 0 -and ($controlDeltaPaths -join "`n") -ceq ($recordedControlDelta -join "`n")) 'Recorded source-to-control delta mismatch.'
$forbiddenControlPaths = @($controlDeltaPaths | Where-Object { $allowedControlPaths -cnotcontains $_ })
Assert-True ($forbiddenControlPaths.Count -eq 0) "Source-to-control delta contains non-control paths: $($forbiddenControlPaths -join ',')"
Assert-BoundedText ([string]$executionBinding.workflow) 256 'Execution workflow'
Assert-BoundedText ([string]$executionBinding.workflow_ref) 512 'Execution workflow ref'
Assert-BoundedText ([string]$executionBinding.job) 256 'Execution job'
$expectedExecutionArtifactName = "phase6-scale-execution-evidence-$executionRunId-$executionRunAttempt"
Assert-True ([string]$executionBinding.artifact_name -ceq $expectedExecutionArtifactName) 'Execution artifact name mismatch.'

$environmentReviewBinding = $executionBinding.environment_review
Assert-ExactProperties $environmentReviewBinding @(
  'contract_version', 'review_artifact_name', 'review_artifact_sha256', 'review_sidecar_name',
  'review_sidecar_sha256', 'captured_at_utc', 'environment_name', 'environment_id',
  'review_state', 'reviewer_login', 'reviewer_id', 'reviewer_type', 'actor_login',
  'triggering_actor_login', 'human_review_verified'
) 'Environment-review binding'
Assert-True ([string]$environmentReviewBinding.contract_version -ceq 'github-actions-phase6-environment-review-v1') 'Environment-review binding contract mismatch.'
$expectedEnvironmentReviewLeaf = "environment-review-$executionRunId-$executionRunAttempt.json"
Assert-True ([string]$environmentReviewBinding.review_artifact_name -ceq $expectedEnvironmentReviewLeaf) 'Environment-review artifact name mismatch.'
Assert-True ([string]$environmentReviewBinding.review_sidecar_name -ceq "$expectedEnvironmentReviewLeaf.sha256") 'Environment-review sidecar name mismatch.'
foreach ($hashField in @('review_artifact_sha256', 'review_sidecar_sha256')) {
  Assert-True ([string](Get-Property $environmentReviewBinding $hashField 'Environment-review binding') -match '^[0-9a-f]{64}$') "Environment-review binding $hashField is invalid."
}
Assert-Boolean $environmentReviewBinding 'human_review_verified' $true 'Environment-review binding'
Assert-Integer $environmentReviewBinding 'environment_id' ([long]$environmentReviewBinding.environment_id) 'Environment-review binding'
Assert-True ([long]$environmentReviewBinding.environment_id -gt 0) 'Environment-review binding Environment ID is invalid.'
Assert-Integer $environmentReviewBinding 'reviewer_id' ([long]$environmentReviewBinding.reviewer_id) 'Environment-review binding'
Assert-True ([long]$environmentReviewBinding.reviewer_id -gt 0) 'Environment-review binding reviewer ID is invalid.'
Assert-True ([string]$environmentReviewBinding.environment_name -ceq 'phase6-scale-hosted-writes') 'Execution is not bound to the protected Phase6 Environment.'
Assert-True ([string]$environmentReviewBinding.review_state -ceq 'approved' -and [string]$environmentReviewBinding.reviewer_type -ceq 'User') 'Execution lacks an approved human Environment review.'
Assert-True ([string]$environmentReviewBinding.reviewer_login -match '^[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})$' -and [string]$environmentReviewBinding.reviewer_login -notmatch '(?i)\[bot\]$') 'Environment reviewer login is not human-shaped.'
foreach ($actorField in @('actor_login', 'triggering_actor_login')) {
  Assert-True ([string](Get-Property $environmentReviewBinding $actorField 'Environment-review binding') -match '^[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})$') "Environment-review binding $actorField is invalid."
}
$environmentReviewCapturedAt = ConvertTo-UtcTimestamp $environmentReviewBinding.captured_at_utc 'Environment-review binding capture timestamp'
Assert-True ($environmentReviewCapturedAt -le $generatedAt -and ($generatedAt - $environmentReviewCapturedAt).TotalHours -le 1) 'Environment review was not captured immediately before the bounded run.'
$environmentReviewDirectory = Split-Path -Parent $resolvedEvidence
$resolvedEnvironmentReview = Resolve-InputFile (Join-Path $environmentReviewDirectory $expectedEnvironmentReviewLeaf) 'Environment-review artifact'
$resolvedEnvironmentReviewSidecar = Resolve-InputFile "$resolvedEnvironmentReview.sha256" 'Environment-review digest sidecar'
$environmentReviewSha256 = Get-FileSha256 $resolvedEnvironmentReview
$environmentReviewSidecarSha256 = Get-FileSha256 $resolvedEnvironmentReviewSidecar
Assert-True ($environmentReviewSha256 -ceq [string]$environmentReviewBinding.review_artifact_sha256) 'Environment-review artifact SHA-256 mismatch.'
Assert-True ($environmentReviewSidecarSha256 -ceq [string]$environmentReviewBinding.review_sidecar_sha256) 'Environment-review sidecar SHA-256 mismatch.'
$environmentReviewSidecarRaw = Get-Content -LiteralPath $resolvedEnvironmentReviewSidecar -Raw
Assert-True ($environmentReviewSidecarRaw -match '^([0-9a-f]{64})  ([^\\/\r\n]+)\r?\n?$') 'Environment-review digest sidecar format is invalid.'
Assert-True ($matches[1] -ceq $environmentReviewSha256 -and $matches[2] -ceq $expectedEnvironmentReviewLeaf) 'Environment-review digest sidecar does not bind the review bytes.'
$environmentReviewRaw = Get-Content -LiteralPath $resolvedEnvironmentReview -Raw
Assert-True ($environmentReviewRaw -notmatch '(?i)(?:sk-|ghp_|github_pat_|glpat-|cfat_|vck_|hf_)[A-Za-z0-9_-]{12,}') 'Environment-review artifact contains secret-shaped material.'
Assert-True ($environmentReviewRaw -notmatch '(?i)"(?:authorization|cookie|password|private_key|client_secret|token|credential|comment)"\s*:') 'Environment-review artifact contains a forbidden free-text or credential field.'
$environmentReview = Read-JsonFile $resolvedEnvironmentReview 'Environment-review artifact'
Assert-ExactProperties $environmentReview @(
  'contract_version', 'captured_at_utc', 'repository', 'run_id', 'run_attempt', 'head_sha',
  'environment_name', 'environment_id', 'review_state', 'reviewer_login', 'reviewer_id',
  'reviewer_type', 'actor_login', 'triggering_actor_login', 'secret_output'
) 'Environment-review artifact'
foreach ($field in @('contract_version', 'captured_at_utc', 'environment_name', 'environment_id', 'review_state', 'reviewer_login', 'reviewer_id', 'reviewer_type', 'actor_login', 'triggering_actor_login')) {
  Assert-True ([string]$environmentReview.$field -ceq [string]$environmentReviewBinding.$field) "Environment-review artifact/binding mismatch at $field."
}
Assert-True ([string]$environmentReview.repository -ceq [string]$executionBinding.repository -and [string]$environmentReview.head_sha -ceq [string]$executionBinding.head_sha) 'Environment-review artifact repository/head binding mismatch.'
Assert-Integer $environmentReview 'run_id' $executionRunId 'Environment-review artifact'
Assert-Integer $environmentReview 'run_attempt' 1 'Environment-review artifact'
Assert-Boolean $environmentReview 'secret_output' $false 'Environment-review artifact'
if (-not $AllowTestPaths) {
  foreach ($reviewPath in @($resolvedEnvironmentReview, $resolvedEnvironmentReviewSidecar)) {
    Assert-TrackedCleanAgainstHead ([IO.Path]::GetRelativePath($repoRoot, $reviewPath).Replace('\', '/'))
  }
}

Assert-ExactProperties $executionReadback @(
  'contract_version', 'collected_at_utc', 'repository', 'run', 'artifact',
  'downloaded_archive_sha256', 'downloaded_evidence_sha256', 'downloaded_sidecar_sha256',
  'sidecar_declared_evidence_sha256', 'secret_output'
) 'GitHub execution readback'
Assert-True ([string]$executionReadback.contract_version -eq 'github-actions-phase6-scale-execution-readback-v1') 'GitHub execution-readback contract mismatch.'
Assert-True ([string]$executionReadback.repository -ceq [string]$executionBinding.repository) 'GitHub execution-readback repository mismatch.'
Assert-Boolean $executionReadback 'secret_output' $false 'GitHub execution readback'
$collectedAt = ConvertTo-UtcTimestamp $executionReadback.collected_at_utc 'GitHub execution-readback collection timestamp'
Assert-True ($collectedAt -le [DateTimeOffset]::UtcNow.AddMinutes(5)) 'GitHub execution readback was collected in the future.'
Assert-True ($collectedAt -ge $generatedAt -and ($collectedAt - $generatedAt).TotalHours -le 24) 'GitHub execution readback is stale or predates the scale evidence.'

$executionRun = $executionReadback.run
Assert-ExactProperties $executionRun @('id', 'run_attempt', 'event', 'status', 'conclusion', 'head_branch', 'head_sha', 'html_url', 'created_at', 'updated_at') 'GitHub execution run readback'
Assert-Integer $executionRun 'id' $executionRunId 'GitHub execution run readback'
Assert-Integer $executionRun 'run_attempt' $executionRunAttempt 'GitHub execution run readback'
Assert-True ([string]$executionRun.event -eq [string]$executionBinding.event_name) 'GitHub execution event mismatch.'
Assert-True ([string]$executionRun.status -eq 'completed' -and [string]$executionRun.conclusion -eq 'success') 'GitHub execution run did not complete successfully.'
$expectedHeadBranch = ([string]$executionBinding.ref).Substring('refs/heads/'.Length)
Assert-True ([string]$executionRun.head_branch -ceq $expectedHeadBranch) 'GitHub execution head branch mismatch.'
Assert-True ([string]$executionRun.head_sha -eq [string]$executionBinding.head_sha) 'GitHub execution run head SHA mismatch.'
Assert-True ([string]$executionRun.html_url -ceq $expectedRunUrl) 'GitHub execution run URL readback mismatch.'
$runCreatedAt = ConvertTo-UtcTimestamp $executionRun.created_at 'GitHub execution run created_at'
$runUpdatedAt = ConvertTo-UtcTimestamp $executionRun.updated_at 'GitHub execution run updated_at'
Assert-True ($runCreatedAt -le $generatedAt -and $generatedAt -le $runUpdatedAt -and $runUpdatedAt -le $collectedAt) 'Scale evidence time is outside the completed GitHub run window.'

$executionArtifact = $executionReadback.artifact
Assert-ExactProperties $executionArtifact @('id', 'name', 'expired', 'digest', 'url', 'archive_download_url', 'workflow_run', 'created_at', 'updated_at') 'GitHub execution artifact readback'
$artifactId = Get-NonNegativeInteger $executionArtifact 'id' 'GitHub execution artifact readback'
Assert-True ($artifactId -gt 0) 'GitHub execution artifact ID must be positive.'
Assert-True ([string]$executionArtifact.name -ceq $expectedExecutionArtifactName) 'GitHub execution artifact name mismatch.'
Assert-Boolean $executionArtifact 'expired' $false 'GitHub execution artifact readback'
Assert-True ([string]$executionArtifact.digest -match '^sha256:[0-9a-f]{64}$') 'GitHub execution artifact digest is invalid.'
$expectedArtifactApiUrl = "https://api.github.com/repos/$([string]$executionBinding.repository)/actions/artifacts/$artifactId"
Assert-True ([string]$executionArtifact.url -ceq $expectedArtifactApiUrl) 'GitHub execution artifact API URL mismatch.'
Assert-True ([string]$executionArtifact.archive_download_url -ceq "$expectedArtifactApiUrl/zip") 'GitHub execution artifact archive URL mismatch.'
Assert-ExactProperties $executionArtifact.workflow_run @('id', 'head_sha') 'GitHub execution artifact workflow binding'
Assert-Integer $executionArtifact.workflow_run 'id' $executionRunId 'GitHub execution artifact workflow binding'
Assert-True ([string]$executionArtifact.workflow_run.head_sha -eq [string]$executionBinding.head_sha) 'GitHub execution artifact head SHA mismatch.'
$artifactCreatedAt = ConvertTo-UtcTimestamp $executionArtifact.created_at 'GitHub execution artifact created_at'
$artifactUpdatedAt = ConvertTo-UtcTimestamp $executionArtifact.updated_at 'GitHub execution artifact updated_at'
Assert-True ($generatedAt -le $artifactCreatedAt -and $artifactCreatedAt -le $artifactUpdatedAt -and $artifactUpdatedAt -le $collectedAt) 'GitHub execution artifact timestamps are inconsistent.'

foreach ($hashField in @('downloaded_archive_sha256', 'downloaded_evidence_sha256', 'downloaded_sidecar_sha256', 'sidecar_declared_evidence_sha256')) {
  Assert-True ([string](Get-Property $executionReadback $hashField 'GitHub execution readback') -match '^[0-9a-f]{64}$') "GitHub execution readback $hashField is invalid."
}
Assert-True ([string]$executionArtifact.digest -ceq "sha256:$([string]$executionReadback.downloaded_archive_sha256)") 'Downloaded GitHub artifact archive digest mismatch.'
Assert-True ([string]$executionReadback.downloaded_evidence_sha256 -eq $evidenceSha256) 'Downloaded GitHub artifact evidence digest mismatch.'
Assert-True ([string]$executionReadback.downloaded_sidecar_sha256 -eq (Get-FileSha256 $companionPath)) 'Downloaded GitHub artifact sidecar digest mismatch.'
Assert-True ([string]$executionReadback.sidecar_declared_evidence_sha256 -eq $evidenceSha256) 'Downloaded GitHub artifact sidecar declaration mismatch.'
if (-not $AllowTestPaths) {
  Assert-LiveGithubExecutionProvenance $executionBinding $executionReadback $resolvedEvidence $companionPath $evidenceSha256 $resolvedEnvironmentReview $resolvedEnvironmentReviewSidecar $environmentReviewSha256 $environmentReviewSidecarSha256
  $currentEvidenceHead = Get-RepositoryHeadSha
  $evidenceHeadDelta = @(Get-GitDelta ([string]$executionBinding.head_sha) $currentEvidenceHead 'Control-to-evidence delta')
  $evidenceHeadPaths = @($evidenceHeadDelta.path | Sort-Object -Unique)
  $relativeEvidenceForHead = [IO.Path]::GetRelativePath($repoRoot, $resolvedEvidence).Replace('\', '/')
  $relativeSidecarForHead = [IO.Path]::GetRelativePath($repoRoot, $companionPath).Replace('\', '/')
  $relativeReadbackForHead = [IO.Path]::GetRelativePath($repoRoot, $resolvedExecutionReadback).Replace('\', '/')
  $relativeReadbackSidecarForHead = [IO.Path]::GetRelativePath($repoRoot, $executionReadbackCompanionPath).Replace('\', '/')
  $relativeEnvironmentReviewForHead = [IO.Path]::GetRelativePath($repoRoot, $resolvedEnvironmentReview).Replace('\', '/')
  $relativeEnvironmentReviewSidecarForHead = [IO.Path]::GetRelativePath($repoRoot, $resolvedEnvironmentReviewSidecar).Replace('\', '/')
  $requiredEvidenceHeadPaths = @($relativeEvidenceForHead, $relativeSidecarForHead, $relativeReadbackForHead, $relativeReadbackSidecarForHead, $relativeEnvironmentReviewForHead, $relativeEnvironmentReviewSidecarForHead)
  $allowedEvidenceHeadPaths = @($requiredEvidenceHeadPaths + 'docs/runtime-state/capability-gates.json') | Sort-Object -Unique
  $forbiddenEvidenceHeadPaths = @($evidenceHeadPaths | Where-Object { $allowedEvidenceHeadPaths -cnotcontains $_ })
  Assert-True ($forbiddenEvidenceHeadPaths.Count -eq 0) "Control-to-evidence delta contains non-evidence paths: $($forbiddenEvidenceHeadPaths -join ',')"
  foreach ($requiredPath in $requiredEvidenceHeadPaths) {
    Assert-True ($evidenceHeadPaths -ccontains $requiredPath) "Control-to-evidence delta is missing immutable evidence path: $requiredPath"
    & git -C $repoRoot cat-file -e "$([string]$executionBinding.head_sha):$requiredPath" 2>$null
    Assert-True ($LASTEXITCODE -ne 0) "Immutable evidence path already existed at the execution-control commit: $requiredPath"
  }
}
Assert-True ([string]$evidence.source_binding.verifier_script_sha256 -match '^[0-9a-f]{64}$') 'Runtime verifier script SHA-256 binding is invalid.'
Assert-True ([string]$evidence.source_binding.verifier_script_sha256 -eq (Get-FileSha256 $canonicalRuntimeVerifier)) 'Runtime verifier script SHA-256 binding mismatch.'
Assert-RepositoryHeadBinding ([string]$evidence.source_binding.repository_head_sha)
& git -C $repoRoot merge-base --is-ancestor $minimumLoopFixCommit ([string]$hostedState.source_commit_sha)
Assert-True ($LASTEXITCODE -eq 0) 'Deployed source predates the required contract-origin loop fix.'
Assert-True ((Get-GitArchiveSha256 ([string]$hostedState.source_commit_sha)) -eq [string]$hostedState.source_archive_sha256) 'Hosted source archive does not match its Git commit.'
Assert-True ([string]$evidence.source_binding.capability_state_sha256 -match '^[0-9a-f]{64}$') 'Capability-state SHA-256 binding is invalid.'
Assert-True ([string]$evidence.source_binding.capability_state_sha256 -eq (Get-FileSha256 $resolvedCapabilityState)) 'Capability-state SHA-256 binding mismatch.'
$boundGate = $capabilityState.gates.phase6_scale_runtime
Assert-Boolean $boundGate 'owner_granted' $true 'source-bound phase6 gate'
Assert-Boolean $boundGate 'paid_provider' $false 'source-bound phase6 gate'
$boundOwnerGrantRef = [string](Get-Property $boundGate 'owner_grant_ref' 'source-bound phase6 gate')
Assert-BoundedIdentifier $boundOwnerGrantRef 256 'Source-bound Owner grant reference'
Assert-True ([string]$evidence.source_binding.owner_grant_ref -ceq $boundOwnerGrantRef) 'Evidence Owner grant reference binding mismatch.'
$boundGateIdentitySha256 = Get-StringSha256 (Get-GateIdentity $boundGate)
Assert-True ([string]$evidence.source_binding.gate_identity_sha256 -match '^[0-9a-f]{64}$' -and [string]$evidence.source_binding.gate_identity_sha256 -eq $boundGateIdentitySha256) 'Gate identity SHA-256 binding mismatch.'

Assert-ExactProperties $evidence.request_budget @('worker_cap', 'worker_requests_issued', 'read_requests_issued', 'create_requests_issued', 'cleanup_delete_requests_issued', 'control_edge_requests_issued', 'cap_respected', 'exact_plan_executed') 'request budget'
Assert-Integer $evidence.request_budget 'worker_cap' 900 'request budget'
Assert-Integer $evidence.request_budget 'worker_requests_issued' 900 'request budget'
Assert-Integer $evidence.request_budget 'read_requests_issued' 800 'request budget'
Assert-Integer $evidence.request_budget 'create_requests_issued' 50 'request budget'
Assert-Integer $evidence.request_budget 'cleanup_delete_requests_issued' 50 'request budget'
Assert-Integer $evidence.request_budget 'control_edge_requests_issued' 244 'request budget'
Assert-Boolean $evidence.request_budget 'cap_respected' $true 'request budget'
Assert-Boolean $evidence.request_budget 'exact_plan_executed' $true 'request budget'
Assert-True ([int]$criterion.envelope.max_total_requests -eq 900) 'Criterion Worker cap is not 900.'
Assert-True (
  [long]$evidence.request_budget.worker_requests_issued -eq
  ([long]$evidence.request_budget.read_requests_issued + [long]$evidence.request_budget.create_requests_issued + [long]$evidence.request_budget.cleanup_delete_requests_issued)
) 'Request-budget component totals do not equal Worker requests issued.'

$expectedTiers = @(@(1, 60), @(10, 240), @(50, 500))
$tiers = @($evidence.read_tiers)
Assert-True ($tiers.Count -eq 3) 'Read-tier count mismatch.'
$read429 = 0
$validHealth = 0
$edgeControlRequestTotal = 0
$edgeControlFailureTotal = 0
for ($index = 0; $index -lt $expectedTiers.Count; $index++) {
  $tier = $tiers[$index]
  $label = "read tier $index"
  Assert-ExactProperties $tier @('concurrency', 'requests', 'valid_health_200', 'invalid_health_200', 'throttled_429', 'server_5xx', 'transport_fail', 'other_status', 'p50_ms', 'p95_ms', 'p99_ms', 'edge_control_p95_ms', 'worker_share_p95_ms', 'records', 'edge_control_records') $label
  Assert-Integer $tier 'concurrency' $expectedTiers[$index][0] $label
  Assert-Integer $tier 'requests' $expectedTiers[$index][1] $label
  Assert-Integer $tier 'invalid_health_200' 0 $label
  Assert-Integer $tier 'server_5xx' 0 $label
  Assert-Integer $tier 'transport_fail' 0 $label
  Assert-Integer $tier 'other_status' 0 $label
  $tierValid = Get-NonNegativeInteger $tier 'valid_health_200' $label
  $tier429 = Get-NonNegativeInteger $tier 'throttled_429' $label
  $tierRequests = Get-NonNegativeInteger $tier 'requests' $label
  $tierInvalid = Get-NonNegativeInteger $tier 'invalid_health_200' $label
  $tier5xx = Get-NonNegativeInteger $tier 'server_5xx' $label
  $tierTransport = Get-NonNegativeInteger $tier 'transport_fail' $label
  $tierOther = Get-NonNegativeInteger $tier 'other_status' $label
  Assert-True (
    ($tierValid + $tierInvalid + $tier429 + $tier5xx + $tierTransport + $tierOther) -eq $tierRequests
  ) "$label response accounting mismatch."
  $tierP50 = Get-FiniteNonNegativeNumber $tier 'p50_ms' $label
  $tierP95 = Get-FiniteNonNegativeNumber $tier 'p95_ms' $label
  $tierP99 = Get-FiniteNonNegativeNumber $tier 'p99_ms' $label
  $edgeP95 = Get-FiniteNonNegativeNumber $tier 'edge_control_p95_ms' $label
  $workerShareP95 = Get-FiniteNonNegativeNumber $tier 'worker_share_p95_ms' $label
  $tierRecords = @($tier.records)
  Assert-True ($tierRecords.Count -eq $tierRequests) "$label record count mismatch."
  $tierLatencies = @()
  $recomputedValid = 0L
  $recomputedInvalid = 0L
  $recomputed429 = 0L
  $recomputed5xx = 0L
  $recomputedTransport = 0L
  $recomputedOther = 0L
  for ($recordIndex = 0; $recordIndex -lt $tierRecords.Count; $recordIndex++) {
    $readRecord = $tierRecords[$recordIndex]
    $ordinal = $recordIndex + 1
    Assert-ExactProperties $readRecord @('ordinal', 'key', 'status_code', 'latency_ms', 'health_contract_verified', 'validation_errors') "$label record"
    Assert-Integer $readRecord 'ordinal' $ordinal "$label record"
    Assert-True ([string]$readRecord.key -ceq "health-$([long]$tier.concurrency)-$ordinal") "$label record key/ordinal mismatch."
    $statusCode = Get-NonNegativeInteger $readRecord 'status_code' "$label record"
    $tierLatencies += Get-FiniteNonNegativeNumber $readRecord 'latency_ms' "$label record"
    $validationErrors = @($readRecord.validation_errors)
    $healthVerified = Get-Property $readRecord 'health_contract_verified' "$label record"
    Assert-True ($healthVerified -is [bool]) "$label record health_contract_verified must be a boolean."
    if ($statusCode -eq 200 -and $healthVerified -eq $true -and $validationErrors.Count -eq 0) {
      $recomputedValid++
    } elseif ($statusCode -eq 200) {
      $recomputedInvalid++
    } elseif ($statusCode -eq 429) {
      Assert-EmptyArray $validationErrors "$label throttled-record validation errors"
      Assert-True ($healthVerified -eq $false) "$label throttled record cannot claim a verified health contract."
      $recomputed429++
    } elseif ($statusCode -ge 500 -and $statusCode -le 599) {
      $recomputed5xx++
    } elseif ($statusCode -eq 0) {
      $recomputedTransport++
    } else {
      $recomputedOther++
    }
  }
  Assert-True ($tierValid -eq $recomputedValid -and $tierInvalid -eq $recomputedInvalid -and $tier429 -eq $recomputed429 -and $tier5xx -eq $recomputed5xx -and $tierTransport -eq $recomputedTransport -and $tierOther -eq $recomputedOther) "$label counters do not match per-request evidence."
  Assert-NumberEquals $tierP50 (Get-Percentile $tierLatencies 0.50) "$label p50" 0.05
  Assert-NumberEquals $tierP95 (Get-Percentile $tierLatencies 0.95) "$label p95" 0.05
  Assert-NumberEquals $tierP99 (Get-Percentile $tierLatencies 0.99) "$label p99" 0.05

  $controlRecords = @($tier.edge_control_records)
  $expectedControlCount = [long]$tier.concurrency * 4
  Assert-True ($controlRecords.Count -eq $expectedControlCount) "$label edge-control record count mismatch."
  $controlLatencies = @()
  for ($controlIndex = 0; $controlIndex -lt $controlRecords.Count; $controlIndex++) {
    $controlRecord = $controlRecords[$controlIndex]
    $controlOrdinal = $controlIndex + 1
    Assert-ExactProperties $controlRecord @('ordinal', 'key', 'status_code', 'latency_ms', 'response_ok') "$label edge-control record"
    Assert-Integer $controlRecord 'ordinal' $controlOrdinal "$label edge-control record"
    Assert-True ([string]$controlRecord.key -ceq "control-$([long]$tier.concurrency)-$controlOrdinal") "$label edge-control key/ordinal mismatch."
    $controlStatus = Get-NonNegativeInteger $controlRecord 'status_code' "$label edge-control record"
    $controlLatencies += Get-FiniteNonNegativeNumber $controlRecord 'latency_ms' "$label edge-control record"
    $controlOk = Get-Property $controlRecord 'response_ok' "$label edge-control record"
    Assert-True ($controlOk -is [bool] -and $controlOk -eq ($controlStatus -eq 200)) "$label edge-control status/boolean mismatch."
    if (-not $controlOk) { $edgeControlFailureTotal++ }
  }
  Assert-NumberEquals $edgeP95 (Get-Percentile $controlLatencies 0.95) "$label edge-control p95" 0.05
  $edgeControlRequestTotal += $controlRecords.Count
  Assert-True ($tierP50 -le $tierP95 -and $tierP95 -le $tierP99) "$label percentile order is invalid."
  Assert-NumberEquals $workerShareP95 ([Math]::Max(0.0, $tierP95 - $edgeP95)) "$label Worker-share p95"
  Assert-True ($tierP95 -le [double]$criterion.pass_criteria.max_p95_ms) "$label p95 exceeds the criterion."
  $validHealth += $tierValid
  $read429 += $tier429
}
Assert-True (($tiers | ForEach-Object { [long]$_.requests } | Measure-Object -Sum).Sum -eq 800) 'Read-tier request totals do not equal 800.'
Assert-True ($edgeControlRequestTotal -eq [long]$evidence.request_budget.control_edge_requests_issued) 'Edge-control record total does not match the request budget.'

Assert-ExactProperties $evidence.health_validation @('valid_json_count', 'invalid_json_or_contract_count', 'validation_failures') 'health validation'
Assert-Integer $evidence.health_validation 'valid_json_count' $validHealth 'health validation'
Assert-Integer $evidence.health_validation 'invalid_json_or_contract_count' 0 'health validation'
Assert-EmptyArray $evidence.health_validation.validation_failures 'health validation failures'

Assert-ExactProperties $evidence.write_tier @('concurrency', 'records_planned', 'valid_post_insert_readbacks', 'record_loss_count', 'duplicate_count', 'duplicate_request_id_count', 'duplicate_audit_event_id_count', 'field_failure_count', 'hash_failure_count', 'audit_failure_count', 'throttled_429', 'server_5xx', 'transport_fail', 'p50_ms', 'p95_ms', 'p99_ms', 'records') 'write tier'
Assert-Integer $evidence.write_tier 'concurrency' 10 'write tier'
Assert-Integer $evidence.write_tier 'records_planned' 50 'write tier'
Assert-Integer $evidence.write_tier 'valid_post_insert_readbacks' 50 'write tier'
foreach ($field in @('record_loss_count', 'duplicate_count', 'duplicate_request_id_count', 'duplicate_audit_event_id_count', 'field_failure_count', 'hash_failure_count', 'audit_failure_count', 'throttled_429', 'server_5xx', 'transport_fail')) {
  Assert-Integer $evidence.write_tier $field 0 'write tier'
}
$writeP50 = Get-FiniteNonNegativeNumber $evidence.write_tier 'p50_ms' 'write tier'
$writeP95 = Get-FiniteNonNegativeNumber $evidence.write_tier 'p95_ms' 'write tier'
$writeP99 = Get-FiniteNonNegativeNumber $evidence.write_tier 'p99_ms' 'write tier'
Assert-True ($writeP50 -le $writeP95 -and $writeP95 -le $writeP99) 'Write-tier percentile order is invalid.'
Assert-True ($writeP95 -le [double]$criterion.pass_criteria.max_p95_ms) 'Write-tier p95 exceeds the criterion.'
$writeRecords = @($evidence.write_tier.records)
Assert-True ($writeRecords.Count -eq 50) 'Write record evidence count mismatch.'
$writeIds = @()
$requestIds = @()
$auditEventIds = @()
$writeLatencies = @()
for ($recordIndex = 0; $recordIndex -lt $writeRecords.Count; $recordIndex++) {
  $record = $writeRecords[$recordIndex]
  $ordinal = $recordIndex + 1
  $expectedId = "p6s$(([string]$evidence.run_id).Substring(0, 24))$($ordinal.ToString('00'))"
  $expectedRequestId = "phase6-scale-$([string]$evidence.run_id)-$ordinal-create"
  $expectedPrompt = "Phase 6 zero-card scale verification record $ordinal for run $([string]$evidence.run_id)"
  $expectedHtml = "<!doctype html><html><head><meta charset=`"utf-8`"><title>Phase 6 $ordinal</title></head><body><main data-phase6-scale=`"$expectedId`">Scale record $ordinal</main></body></html>"
  Assert-ExactProperties $record @('ordinal', 'id', 'response_id', 'request_id', 'audit_event_id', 'status_code', 'latency_ms', 'response_readback_verified', 'audit_readback_verified', 'prompt_sha256', 'html_sha256', 'created_at_utc', 'updated_at_utc', 'audit_persisted_verified', 'validation_errors') 'write record'
  Assert-Integer $record 'ordinal' $ordinal 'write record'
  Assert-True ([string]$record.id -ceq $expectedId) 'Write record ID/ordinal binding mismatch.'
  Assert-True ([string]$record.response_id -ceq [string]$record.id) 'Write response ID mismatch.'
  Assert-True ([string]$record.request_id -ceq $expectedRequestId) 'Write request ID/ordinal binding mismatch.'
  Assert-True ([string]$record.audit_event_id -match '^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$') 'Write audit event ID is invalid.'
  Assert-Integer $record 'status_code' 201 'write record'
  Assert-Boolean $record 'response_readback_verified' $true 'write record'
  Assert-Boolean $record 'audit_readback_verified' $true 'write record'
  Assert-Boolean $record 'audit_persisted_verified' $true 'write record'
  Assert-True ([string]$record.prompt_sha256 -ceq (Get-StringSha256 $expectedPrompt)) 'Prompt SHA-256 does not match the deterministic ordinal payload.'
  Assert-True ([string]$record.html_sha256 -ceq (Get-StringSha256 $expectedHtml)) 'HTML SHA-256 does not match the deterministic ordinal payload.'
  $createdAt = ConvertTo-UtcTimestamp $record.created_at_utc 'Write record created_at_utc'
  $updatedAt = ConvertTo-UtcTimestamp $record.updated_at_utc 'Write record updated_at_utc'
  Assert-True ($createdAt -eq $updatedAt) 'Write record create/update timestamp parity mismatch.'
  Assert-True ($runCreatedAt -le $createdAt -and $createdAt -le $generatedAt) 'Write record timestamp is outside the GitHub execution window.'
  $writeLatencies += Get-FiniteNonNegativeNumber $record 'latency_ms' 'write record'
  Assert-EmptyArray $record.validation_errors 'write record validation errors'
  $writeIds += [string]$record.id
  $requestIds += [string]$record.request_id
  $auditEventIds += [string]$record.audit_event_id
}
Assert-True (@($writeIds | Select-Object -Unique).Count -eq 50) 'Write evidence contains duplicate IDs.'
Assert-True (@($requestIds | Select-Object -Unique).Count -eq 50) 'Write evidence contains duplicate request IDs.'
Assert-True (@($auditEventIds | Select-Object -Unique).Count -eq 50) 'Write evidence contains duplicate audit event IDs.'
Assert-NumberEquals $writeP50 (Get-Percentile $writeLatencies 0.50) 'Write-tier p50' 0.05
Assert-NumberEquals $writeP95 (Get-Percentile $writeLatencies 0.95) 'Write-tier p95' 0.05
Assert-NumberEquals $writeP99 (Get-Percentile $writeLatencies 0.99) 'Write-tier p99' 0.05

Assert-ExactProperties $evidence.cleanup @('verified_count', 'literal_success_count', 'required_count', 'complete', 'throttled_429', 'unclean_throttle_count', 'server_5xx', 'transport_fail', 'p95_ms', 'records') 'cleanup'
Assert-Integer $evidence.cleanup 'verified_count' 50 'cleanup'
Assert-Integer $evidence.cleanup 'literal_success_count' 50 'cleanup'
Assert-Integer $evidence.cleanup 'required_count' 50 'cleanup'
Assert-Boolean $evidence.cleanup 'complete' $true 'cleanup'
foreach ($field in @('throttled_429', 'unclean_throttle_count', 'server_5xx', 'transport_fail')) {
  Assert-Integer $evidence.cleanup $field 0 'cleanup'
}
Assert-NumberAtMost $evidence.cleanup 'p95_ms' ([double]$criterion.pass_criteria.max_p95_ms) 'cleanup'
$cleanupP95 = Get-FiniteNonNegativeNumber $evidence.cleanup 'p95_ms' 'cleanup'
$cleanupRecords = @($evidence.cleanup.records)
Assert-True ($cleanupRecords.Count -eq 50) 'Cleanup record evidence count mismatch.'
$cleanupLatencies = @()
for ($recordIndex = 0; $recordIndex -lt $cleanupRecords.Count; $recordIndex++) {
  $record = $cleanupRecords[$recordIndex]
  $ordinal = $recordIndex + 1
  $expectedId = "p6s$(([string]$evidence.run_id).Substring(0, 24))$($ordinal.ToString('00'))"
  $expectedRequestId = "phase6-scale-$([string]$evidence.run_id)-$expectedId-delete"
  Assert-ExactProperties $record @('ordinal', 'id', 'request_id', 'audit_event_id', 'status_code', 'latency_ms', 'expected_deleted_record', 'cleanup_verified', 'audit_persisted_verified', 'audit_readback_verified', 'delete_readback_verified', 'validation_errors') 'cleanup record'
  Assert-Integer $record 'ordinal' $ordinal 'cleanup record'
  Assert-True ([string]$record.id -ceq $expectedId) 'Cleanup ID/ordinal binding mismatch.'
  Assert-True ([string]$record.request_id -ceq $expectedRequestId) 'Cleanup request ID/ordinal binding mismatch.'
  Assert-True ([string]$record.audit_event_id -match '^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$') 'Cleanup audit event ID is invalid.'
  Assert-Integer $record 'status_code' 200 'cleanup record'
  Assert-Boolean $record 'expected_deleted_record' $true 'cleanup record'
  Assert-Boolean $record 'cleanup_verified' $true 'cleanup record'
  Assert-Boolean $record 'audit_persisted_verified' $true 'cleanup record'
  Assert-Boolean $record 'audit_readback_verified' $true 'cleanup record'
  Assert-Boolean $record 'delete_readback_verified' $true 'cleanup record'
  $cleanupLatencies += Get-FiniteNonNegativeNumber $record 'latency_ms' 'cleanup record'
  Assert-EmptyArray $record.validation_errors 'cleanup validation errors'
  $requestIds += [string]$record.request_id
  $auditEventIds += [string]$record.audit_event_id
}
Assert-True (@($cleanupRecords.id | Select-Object -Unique).Count -eq 50) 'Cleanup evidence contains duplicate IDs.'
Assert-True (@($requestIds | Select-Object -Unique).Count -eq 100) 'Scale evidence contains duplicate request IDs.'
Assert-True (@($auditEventIds | Select-Object -Unique).Count -eq 100) 'Scale evidence contains duplicate audit event IDs.'
Assert-NumberEquals $cleanupP95 (Get-Percentile $cleanupLatencies 0.95) 'Cleanup p95' 0.05

Assert-ExactProperties $evidence.aggregate @('literal_success_count', 'success_ratio', 'worst_p95_ms', 'throttled_429_total', 'server_5xx_total', 'transport_fail_total', 'edge_control_failure_count', 'http_429_counted_as_success', 'failures', 'criterion_met') 'aggregate'
$expectedLiteralSuccessCount = [long]$validHealth + [long]$evidence.write_tier.valid_post_insert_readbacks + [long]$evidence.cleanup.literal_success_count
Assert-Integer $evidence.aggregate 'literal_success_count' $expectedLiteralSuccessCount 'aggregate'
$aggregateSuccessRatio = Get-FiniteNonNegativeNumber $evidence.aggregate 'success_ratio' 'aggregate'
$recomputedSuccessRatio = [Math]::Round(([double]$expectedLiteralSuccessCount / [double]$evidence.request_budget.worker_requests_issued), 4)
Assert-NumberEquals $aggregateSuccessRatio $recomputedSuccessRatio 'Aggregate literal HTTP success ratio'
Assert-True ($aggregateSuccessRatio -ge [double]$criterion.pass_criteria.min_success_ratio) 'Aggregate literal HTTP success ratio is below threshold.'
Assert-NumberAtMost $evidence.aggregate 'worst_p95_ms' ([double]$criterion.pass_criteria.max_p95_ms) 'aggregate'
$recomputedWorstP95 = [Math]::Max([double](($tiers | Measure-Object -Property p95_ms -Maximum).Maximum), [Math]::Max([double]$evidence.write_tier.p95_ms, [double]$evidence.cleanup.p95_ms))
Assert-True ([Math]::Abs([double]$evidence.aggregate.worst_p95_ms - $recomputedWorstP95) -le 0.1) 'Aggregate worst p95 does not match tier evidence.'
Assert-Integer $evidence.aggregate 'throttled_429_total' ($read429 + [long]$evidence.write_tier.throttled_429 + [long]$evidence.cleanup.throttled_429) 'aggregate'
Assert-Integer $evidence.aggregate 'server_5xx_total' 0 'aggregate'
Assert-Integer $evidence.aggregate 'transport_fail_total' 0 'aggregate'
Assert-Integer $evidence.aggregate 'edge_control_failure_count' $edgeControlFailureTotal 'aggregate'
Assert-Boolean $evidence.aggregate 'http_429_counted_as_success' $false 'aggregate'
Assert-EmptyArray $evidence.aggregate.failures 'aggregate failures'
Assert-Boolean $evidence.aggregate 'criterion_met' $true 'aggregate'

Assert-ExactProperties $evidence.auth @('environment_variable_name', 'value_recorded') 'auth evidence'
Assert-True ([string]$evidence.auth.environment_variable_name -eq 'AGENT_API_AUTH_TOKEN') 'Auth environment-variable name mismatch.'
Assert-Boolean $evidence.auth 'value_recorded' $false 'auth evidence'
Assert-Boolean $evidence 'gate_may_open' $false 'evidence'
Assert-Boolean $evidence 'gate_promotion_performed' $false 'evidence'
Assert-Integer $evidence 'percentage_credit_awarded' 0 'evidence'
$expectedNonClaims = @($criterion.non_claims) + @(
  'This evidence file does not promote phase6_scale_runtime.',
  'This provisional evidence requires an independently downloaded post-run GitHub API and artifact readback before it can verify execution provenance.',
  'The authorization token is neither printed nor persisted.',
  'Control requests use the Cloudflare edge path and are not Worker requests.'
)
Assert-ExactStringArray $evidence.non_claims $expectedNonClaims 'evidence non-claims'

Assert-True ([string]$capabilityState.contract_version -eq 'capability-gate-state-v1') 'Capability-state contract mismatch.'
Assert-True ([string]$capabilityState.status -eq 'configured') 'Capability-state status mismatch.'
$gate = $capabilityState.gates.phase6_scale_runtime
$gateProperties = @('owner_granted', 'owner_grant_ref', 'live_verified', 'evidence_artifact', 'evidence_sha256', 'verified_at_utc', 'provider', 'paid_provider', 'verifier', 'note')
Assert-ExactProperties $gate $gateProperties 'phase6 gate'
Assert-Boolean $gate 'owner_granted' $true 'phase6 gate'
Assert-Boolean $gate 'paid_provider' $false 'phase6 gate'
$ownerGrantRef = [string](Get-Property $gate 'owner_grant_ref' 'phase6 gate')
Assert-BoundedIdentifier $ownerGrantRef 256 'Canonical Owner grant reference'
Assert-True ([string]$evidence.source_binding.owner_grant_ref -ceq $ownerGrantRef) 'Evidence does not bind the exact pre-run canonical Owner grant.'
$capabilityStateSha256 = Get-FileSha256 $resolvedCapabilityState
$gateIdentity = Get-GateIdentity $gate
$gateIdentitySha256 = Get-StringSha256 $gateIdentity

Write-Host "[phase6-scale-evidence] VERIFIED evidence_sha256=$evidenceSha256 result=verified paid_fallback=false secret_output=false"
Write-Host "[phase6-scale-evidence] capability_state_sha256=$capabilityStateSha256 gate_identity_sha256=$gateIdentitySha256"
Write-Host "[phase6-scale-evidence] owner_grant_preexisting=true owner_grant_ref=$ownerGrantRef"

if (-not $Promote) {
  Write-Host '[phase6-scale-evidence] promotion=false read_only=true'
  exit 0
}

Assert-Boolean $gate 'live_verified' $false 'phase6 gate pre-promotion'
foreach ($field in @('evidence_artifact', 'verified_at_utc', 'provider', 'verifier')) {
  Assert-True ([string](Get-Property $gate $field 'phase6 gate pre-promotion') -eq '') "Phase6 gate field must be empty before first promotion: $field"
}
Assert-True ([string]$gate.evidence_sha256 -eq '') 'Phase6 evidence SHA-256 must be empty before first promotion.'
Assert-True ($ExpectedCapabilityStateSha256 -match '^[0-9a-fA-F]{64}$' -and $ExpectedCapabilityStateSha256.ToLowerInvariant() -eq $capabilityStateSha256) 'Current capability-state identity was not supplied or changed.'
Assert-True ($ExpectedGateIdentitySha256 -match '^[0-9a-fA-F]{64}$' -and $ExpectedGateIdentitySha256.ToLowerInvariant() -eq $gateIdentitySha256) 'Current phase6 gate identity was not supplied or changed.'
Assert-True ((Get-FileSha256 $resolvedCapabilityState) -eq $capabilityStateSha256) 'Capability state changed during verification.'
$relativeEvidence = [IO.Path]::GetRelativePath($repoRoot, $resolvedEvidence).Replace('\', '/')
$relativeCompanion = [IO.Path]::GetRelativePath($repoRoot, $companionPath).Replace('\', '/')
$relativeExecutionReadback = [IO.Path]::GetRelativePath($repoRoot, $resolvedExecutionReadback).Replace('\', '/')
$relativeExecutionReadbackCompanion = [IO.Path]::GetRelativePath($repoRoot, $executionReadbackCompanionPath).Replace('\', '/')
$relativeEnvironmentReview = [IO.Path]::GetRelativePath($repoRoot, $resolvedEnvironmentReview).Replace('\', '/')
$relativeEnvironmentReviewCompanion = [IO.Path]::GetRelativePath($repoRoot, $resolvedEnvironmentReviewSidecar).Replace('\', '/')
$relativeDeploymentEvidence = [IO.Path]::GetRelativePath($repoRoot, $deploymentEvidencePath).Replace('\', '/')
foreach ($truthPath in @(
  'docs/runtime-state/phase6-scale-criterion.json',
  'docs/runtime-state/cloudflare-native-hosted-current.json',
  'docs/runtime-state/phase6-scale-hosted-current.json',
  'docs/runtime-state/capability-gates.json',
  'scripts/verify-phase6-scale-runtime.ps1',
  'scripts/verify-phase6-scale-evidence.ps1',
  $canonicalHostedEvidenceRelativePath,
  $relativeDeploymentEvidence,
  "$relativeDeploymentEvidence.sha256",
  $relativeEvidence,
  $relativeCompanion,
  $relativeExecutionReadback,
  $relativeExecutionReadbackCompanion,
  $relativeEnvironmentReview,
  $relativeEnvironmentReviewCompanion
)) {
  Assert-TrackedCleanAgainstHead $truthPath
}
$recordedRepositoryHead = [string]$evidence.source_binding.repository_head_sha
foreach ($boundPath in @(
  'docs/runtime-state/phase6-scale-criterion.json',
  'docs/runtime-state/cloudflare-native-hosted-current.json',
  'docs/runtime-state/phase6-scale-hosted-current.json',
  'docs/runtime-state/capability-gates.json',
  'scripts/verify-phase6-scale-runtime.ps1',
  $canonicalHostedEvidenceRelativePath,
  $relativeDeploymentEvidence,
  "$relativeDeploymentEvidence.sha256"
)) {
  & git -C $repoRoot diff --quiet "$recordedRepositoryHead..HEAD" -- $boundPath
  Assert-True ($LASTEXITCODE -eq 0) "Source-bound file changed after the recorded live-run HEAD: $boundPath"
}
Assert-True ((Get-FileSha256 $deploymentEvidencePath) -eq $deploymentEvidenceSha256) 'Deployment evidence changed during verification.'

$beforeOtherGates = [ordered]@{}
foreach ($property in $capabilityState.gates.PSObject.Properties) {
  if ($property.Name -ne 'phase6_scale_runtime') {
    $beforeOtherGates[$property.Name] = ($property.Value | ConvertTo-Json -Depth 20 -Compress)
  }
}
$candidateJsonForClone = $capabilityState | ConvertTo-Json -Depth 30
$cloneParameters = @{ Depth = 30 }
if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) { $cloneParameters.DateKind = 'String' }
$candidate = $candidateJsonForClone | ConvertFrom-Json @cloneParameters
$candidateGate = $candidate.gates.phase6_scale_runtime
$candidateGate.live_verified = $true
$candidateGate.evidence_artifact = $relativeEvidence
$candidateGate.verified_at_utc = [string]$evidence.generated_at_utc
$candidateGate.provider = 'cloudflare-workers-d1-zero-card'
$candidateGate.paid_provider = $false
$candidateGate.verifier = 'scripts/verify-phase6-scale-evidence.ps1'
$candidateGate.note = "Verified from phase6-scale-evidence-v2; evidence_sha256=$evidenceSha256"
$candidateGate.evidence_sha256 = $evidenceSha256
Assert-Boolean $candidateGate 'owner_granted' $true 'candidate phase6 gate'
Assert-True ([string]$candidateGate.owner_grant_ref -ceq $ownerGrantRef) 'Candidate changed the preexisting Owner grant reference.'

foreach ($property in $candidate.gates.PSObject.Properties) {
  if ($property.Name -ne 'phase6_scale_runtime') {
    Assert-True (($property.Value | ConvertTo-Json -Depth 20 -Compress) -ceq [string]$beforeOtherGates[$property.Name]) "Unrelated capability gate changed: $($property.Name)"
  }
}
Assert-True ([string]$candidate.contract_version -eq [string]$capabilityState.contract_version) 'Candidate changed the top-level contract.'
Assert-True ([string]$candidate.status -eq [string]$capabilityState.status) 'Candidate changed the top-level status.'
Assert-True ([string]$candidate.policy -eq [string]$capabilityState.policy) 'Candidate changed the top-level policy.'
Assert-ExactStringArray $candidate.non_claims @($capabilityState.non_claims) 'candidate capability non-claims'

$temporaryPath = "$resolvedCapabilityState.phase6-scale-candidate-$([Guid]::NewGuid().ToString('N')).tmp"
$backupDir = Join-Path $repoRoot '.phase1-artifacts\phase6-scale'
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$backupPath = Join-Path $backupDir "capability-gates-before-phase6-$((Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ'))-$([Guid]::NewGuid().ToString('N')).json"
$utf8NoBom = [Text.UTF8Encoding]::new($false)
$replacePerformed = $false
$promoted = $null
try {
  $candidateJson = $candidate | ConvertTo-Json -Depth 30
  $stream = [IO.File]::Open($temporaryPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
  try {
    $writer = [IO.StreamWriter]::new($stream, $utf8NoBom)
    try { $writer.Write($candidateJson) } finally { $writer.Dispose() }
  } finally {
    if ($null -ne $stream) { $stream.Dispose() }
  }
  $writtenCandidate = Read-JsonFile $temporaryPath 'Candidate capability state'
  Assert-Boolean $writtenCandidate.gates.phase6_scale_runtime 'owner_granted' $true 'candidate phase6 gate'
  Assert-True ([string]$writtenCandidate.gates.phase6_scale_runtime.owner_grant_ref -ceq $ownerGrantRef) 'Written candidate changed the Owner grant reference.'
  Assert-Boolean $writtenCandidate.gates.phase6_scale_runtime 'live_verified' $true 'candidate phase6 gate'
  Assert-Boolean $writtenCandidate.gates.phase6_scale_runtime 'paid_provider' $false 'candidate phase6 gate'
  Assert-True ([string]$writtenCandidate.gates.phase6_scale_runtime.evidence_artifact -eq $relativeEvidence) 'Candidate evidence path mismatch.'
  Assert-True ([string]$writtenCandidate.gates.phase6_scale_runtime.evidence_sha256 -eq $evidenceSha256) 'Candidate evidence SHA-256 mismatch.'
  Assert-True ([string]$writtenCandidate.gates.phase6_scale_runtime.provider -eq 'cloudflare-workers-d1-zero-card') 'Candidate provider mismatch.'
  Assert-True ([string]$writtenCandidate.gates.phase6_scale_runtime.verifier -eq 'scripts/verify-phase6-scale-evidence.ps1') 'Candidate verifier mismatch.'
  Assert-True ([string]$writtenCandidate.gates.phase6_scale_runtime.note -eq "Verified from phase6-scale-evidence-v2; evidence_sha256=$evidenceSha256") 'Candidate evidence note mismatch.'
  Assert-True ((Get-FileSha256 $resolvedCapabilityState) -eq $capabilityStateSha256) 'Capability state changed before atomic replace.'
  [IO.File]::Replace($temporaryPath, $resolvedCapabilityState, $backupPath, $true)
  $replacePerformed = $true

  $promoted = Read-JsonFile $resolvedCapabilityState 'Promoted capability state'
  Assert-Boolean $promoted.gates.phase6_scale_runtime 'owner_granted' $true 'promoted phase6 gate'
  Assert-Boolean $promoted.gates.phase6_scale_runtime 'live_verified' $true 'promoted phase6 gate'
  Assert-Boolean $promoted.gates.phase6_scale_runtime 'paid_provider' $false 'promoted phase6 gate'
  Assert-True ([string]$promoted.gates.phase6_scale_runtime.owner_grant_ref -ceq $ownerGrantRef) 'Promoted Owner grant reference mismatch.'
  Assert-True ([string]$promoted.gates.phase6_scale_runtime.evidence_artifact -eq $relativeEvidence) 'Promoted evidence path mismatch.'
  Assert-True ([string]$promoted.gates.phase6_scale_runtime.provider -eq 'cloudflare-workers-d1-zero-card') 'Promoted provider mismatch.'
  Assert-True ([string]$promoted.gates.phase6_scale_runtime.verifier -eq 'scripts/verify-phase6-scale-evidence.ps1') 'Promoted verifier mismatch.'
  Assert-True ([string]$promoted.gates.phase6_scale_runtime.note -eq "Verified from phase6-scale-evidence-v2; evidence_sha256=$evidenceSha256") 'Promoted evidence note mismatch.'
  Assert-True ([string]$promoted.gates.phase6_scale_runtime.evidence_sha256 -eq $evidenceSha256) 'Promoted evidence SHA-256 mismatch.'
} catch {
  $promotionFailure = $_
  if ($replacePerformed) {
    $failedPromotionPath = Join-Path $backupDir "capability-gates-failed-phase6-$((Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ'))-$([Guid]::NewGuid().ToString('N')).json"
    try {
      Assert-True (Test-Path -LiteralPath $backupPath -PathType Leaf) 'Automatic rollback backup is missing.'
      [IO.File]::Replace($backupPath, $resolvedCapabilityState, $failedPromotionPath, $true)
      Assert-True ((Get-FileSha256 $resolvedCapabilityState) -eq $capabilityStateSha256) 'Automatic rollback did not restore the original capability state.'
      [IO.File]::Copy($resolvedCapabilityState, $backupPath, $false)
    } catch {
      throw "Phase6 promotion failed and automatic rollback failed: promotion=$($promotionFailure.Exception.Message); rollback=$($_.Exception.Message)"
    }
  }
  throw $promotionFailure
} finally {
  if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
    Remove-Item -LiteralPath $temporaryPath -Force
  }
}
Write-Host "[phase6-scale-evidence] promoted=true rollback_artifact=$backupPath secret_output=false"
exit 0

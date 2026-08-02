#Requires -Version 7.0
<#
  Collects the post-run GitHub API/artifact companion for one provisional
  Phase-6 scale report. This command performs anonymous read-only HTTPS GETs
  only. It never reads a token and never promotes a capability gate.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$EvidencePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\', '/')
$artifactRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot '.phase1-artifacts\phase6-scale')).TrimEnd('\', '/')
$utf8NoBom = [Text.UTF8Encoding]::new($false)

function Require([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Get-BytesSha256([byte[]]$Bytes) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try { return (($sha.ComputeHash($Bytes) | ForEach-Object { $_.ToString('x2') }) -join '') }
  finally { $sha.Dispose() }
}

function Get-FileSha256([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-HttpBytes([Net.Http.HttpClient]$Client, [string]$Url, [long]$MaximumBytes, [string]$Label) {
  $request = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Get, $Url)
  try {
    $response = $Client.SendAsync($request, [Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
    try {
      Require ([int]$response.StatusCode -ge 200 -and [int]$response.StatusCode -le 299) "$Label failed with HTTP $([int]$response.StatusCode). Anonymous access is required; no token fallback is permitted."
      if ($null -ne $response.Content.Headers.ContentLength) {
        Require ([long]$response.Content.Headers.ContentLength -le $MaximumBytes) "$Label exceeds its bounded download size."
      }
      $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
      $memory = [IO.MemoryStream]::new()
      try {
        $buffer = [byte[]]::new(81920)
        $total = 0L
        while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
          $total += $read
          Require ($total -le $MaximumBytes) "$Label exceeds its bounded download size."
          $memory.Write($buffer, 0, $read)
        }
        return [pscustomobject]@{ bytes = $memory.ToArray(); final_uri = $response.RequestMessage.RequestUri }
      } finally {
        $memory.Dispose()
        $stream.Dispose()
      }
    } finally { $response.Dispose() }
  } finally { $request.Dispose() }
}

$resolvedEvidence = if ([IO.Path]::IsPathRooted($EvidencePath)) {
  [IO.Path]::GetFullPath($EvidencePath)
} else {
  [IO.Path]::GetFullPath((Join-Path $repoRoot $EvidencePath))
}
Require ($resolvedEvidence.StartsWith($artifactRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) 'Evidence must be inside the immutable Phase-6 artifact directory.'
Require (Test-Path -LiteralPath $resolvedEvidence -PathType Leaf) 'Evidence file is missing.'
Require ([IO.Path]::GetFileName($resolvedEvidence) -match '^scale-evidence-[0-9]{8}T[0-9]{9}Z-[0-9a-f]{32}\.json$') 'Evidence filename is not an immutable Phase-6 name.'
$sidecarPath = "$resolvedEvidence.sha256"
Require (Test-Path -LiteralPath $sidecarPath -PathType Leaf) 'Evidence digest sidecar is missing.'
$evidenceSha256 = Get-FileSha256 $resolvedEvidence
$sidecarRaw = Get-Content -LiteralPath $sidecarPath -Raw
Require ($sidecarRaw -match '^([0-9a-f]{64})  ([^\\/\r\n]+)\r?\n?$') 'Evidence digest sidecar format is invalid.'
Require ($matches[1] -eq $evidenceSha256 -and $matches[2] -ceq [IO.Path]::GetFileName($resolvedEvidence)) 'Evidence digest sidecar does not bind the evidence bytes.'

$evidence = Get-Content -LiteralPath $resolvedEvidence -Raw | ConvertFrom-Json -Depth 30
Require ([string]$evidence.contract_version -eq 'phase6-scale-evidence-v2') 'Evidence contract is not Phase6 scale v2.'
Require ([string]$evidence.result -eq 'provisional_pending_github_readback') 'Evidence is not awaiting GitHub readback.'
$binding = $evidence.source_binding.execution_attestation
Require ([string]$binding.contract_version -eq 'phase6-scale-execution-provenance-v1') 'Execution-provenance binding is invalid.'
Require ([string]$binding.status -eq 'provisional_pending_github_readback' -and $binding.verified -eq $false) 'Execution-provenance binding is not provisional.'
Require ($binding.github_actions -eq $true -and $binding.post_run_api_readback_required -eq $true) 'Evidence does not require a post-run GitHub readback.'
Require ([string]$binding.repository -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') 'GitHub repository binding is invalid.'
Require ($binding.run_id -is [long] -or $binding.run_id -is [int]) 'GitHub run ID is not an integer.'
Require ([long]$binding.run_id -gt 0 -and [int]$binding.run_attempt -gt 0) 'GitHub run identity is invalid.'
Require ([string]$binding.head_sha -match '^[0-9a-f]{40}$') 'GitHub execution-control SHA is invalid.'
$expectedRunUrl = "https://github.com/$([string]$binding.repository)/actions/runs/$([long]$binding.run_id)"
Require ([string]$binding.run_url -ceq $expectedRunUrl) 'GitHub run URL binding mismatch.'
$expectedArtifactName = "phase6-scale-execution-evidence-$([long]$binding.run_id)-$([int]$binding.run_attempt)"
Require ([string]$binding.artifact_name -ceq $expectedArtifactName) 'GitHub artifact-name binding mismatch.'

Add-Type -AssemblyName System.Net.Http
Add-Type -AssemblyName System.IO.Compression
$handler = [Net.Http.SocketsHttpHandler]::new()
$handler.AllowAutoRedirect = $true
$handler.MaxAutomaticRedirections = 5
$client = [Net.Http.HttpClient]::new($handler)
$client.Timeout = [TimeSpan]::FromSeconds(60)
$client.DefaultRequestHeaders.UserAgent.ParseAdd('cloud-superbrain-phase6-readback-collector/1.0')
$client.DefaultRequestHeaders.Accept.ParseAdd('application/vnd.github+json')
$client.DefaultRequestHeaders.Add('X-GitHub-Api-Version', '2022-11-28')
try {
  $repository = [string]$binding.repository
  $runId = [long]$binding.run_id
  $runApiUrl = "https://api.github.com/repos/$repository/actions/runs/$runId"
  $artifactsApiUrl = "https://api.github.com/repos/$repository/actions/runs/$runId/artifacts?name=$([Uri]::EscapeDataString($expectedArtifactName))&per_page=100"
  $runResponse = Get-HttpBytes $client $runApiUrl 2097152 'GitHub run API readback'
  $artifactListResponse = Get-HttpBytes $client $artifactsApiUrl 4194304 'GitHub artifact-list API readback'
  Require ($runResponse.final_uri.AbsoluteUri -ceq $runApiUrl) 'GitHub run API redirected unexpectedly.'
  Require ($artifactListResponse.final_uri.AbsoluteUri -ceq $artifactsApiUrl) 'GitHub artifact-list API redirected unexpectedly.'
  $run = [Text.Encoding]::UTF8.GetString($runResponse.bytes) | ConvertFrom-Json -Depth 20
  $artifactList = [Text.Encoding]::UTF8.GetString($artifactListResponse.bytes) | ConvertFrom-Json -Depth 20
  $artifacts = @($artifactList.artifacts | Where-Object { [string]$_.name -ceq $expectedArtifactName })
  Require ($artifacts.Count -eq 1) 'GitHub did not return exactly one bound execution artifact.'
  $artifact = $artifacts[0]
  Require ([string]$run.status -eq 'completed' -and [string]$run.conclusion -eq 'success') 'GitHub execution run is not completed/successful.'
  Require ([long]$run.id -eq $runId -and [int]$run.run_attempt -eq [int]$binding.run_attempt) 'GitHub run ID/attempt mismatch.'
  Require ([string]$run.event -eq [string]$binding.event_name -and [string]$run.head_sha -eq [string]$binding.head_sha) 'GitHub run event/head mismatch.'
  Require ([string]$run.html_url -ceq $expectedRunUrl) 'GitHub run HTML URL mismatch.'
  Require ($artifact.expired -eq $false -and [string]$artifact.digest -match '^sha256:[0-9a-f]{64}$') 'GitHub artifact is expired or lacks a digest.'
  Require ([long]$artifact.workflow_run.id -eq $runId -and [string]$artifact.workflow_run.head_sha -eq [string]$binding.head_sha) 'GitHub artifact workflow binding mismatch.'
  $archiveResponse = Get-HttpBytes $client ([string]$artifact.archive_download_url) 33554432 'GitHub execution artifact download'
  $archiveHost = $archiveResponse.final_uri.Host.ToLowerInvariant()
  Require ($archiveHost -eq 'api.github.com' -or $archiveHost.EndsWith('.actions.githubusercontent.com') -or $archiveHost.EndsWith('.githubusercontent.com') -or $archiveHost.EndsWith('.blob.core.windows.net')) 'GitHub artifact redirected to an unexpected host.'
  $archiveSha256 = Get-BytesSha256 $archiveResponse.bytes
  Require ([string]$artifact.digest -ceq "sha256:$archiveSha256") 'GitHub artifact digest differs from the downloaded archive.'

  $archiveStream = [IO.MemoryStream]::new($archiveResponse.bytes, $false)
  try {
    $zip = [IO.Compression.ZipArchive]::new($archiveStream, [IO.Compression.ZipArchiveMode]::Read, $false)
    try {
      $evidenceLeaf = [IO.Path]::GetFileName($resolvedEvidence)
      $sidecarLeaf = [IO.Path]::GetFileName($sidecarPath)
      $evidenceEntries = @($zip.Entries | Where-Object { [IO.Path]::GetFileName($_.FullName) -ceq $evidenceLeaf })
      $sidecarEntries = @($zip.Entries | Where-Object { [IO.Path]::GetFileName($_.FullName) -ceq $sidecarLeaf })
      Require ($evidenceEntries.Count -eq 1 -and $sidecarEntries.Count -eq 1) 'Downloaded artifact lacks an exact evidence/sidecar pair.'
      $downloadedEvidence = [IO.MemoryStream]::new()
      $downloadedSidecar = [IO.MemoryStream]::new()
      try {
        $entry = $evidenceEntries[0].Open(); try { $entry.CopyTo($downloadedEvidence) } finally { $entry.Dispose() }
        $entry = $sidecarEntries[0].Open(); try { $entry.CopyTo($downloadedSidecar) } finally { $entry.Dispose() }
        $downloadedEvidenceSha256 = Get-BytesSha256 $downloadedEvidence.ToArray()
        $downloadedSidecarSha256 = Get-BytesSha256 $downloadedSidecar.ToArray()
      } finally {
        $downloadedEvidence.Dispose(); $downloadedSidecar.Dispose()
      }
    } finally { $zip.Dispose() }
  } finally { $archiveStream.Dispose() }
  Require ($downloadedEvidenceSha256 -eq $evidenceSha256) 'Downloaded artifact evidence differs from the local immutable evidence.'
  Require ($downloadedSidecarSha256 -eq (Get-FileSha256 $sidecarPath)) 'Downloaded artifact sidecar differs from the local immutable sidecar.'

  $readback = [ordered]@{
    contract_version = 'github-actions-phase6-scale-execution-readback-v1'
    collected_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
    repository = $repository
    run = [ordered]@{
      id = [long]$run.id; run_attempt = [int]$run.run_attempt; event = [string]$run.event
      status = [string]$run.status; conclusion = [string]$run.conclusion; head_branch = [string]$run.head_branch
      head_sha = [string]$run.head_sha; html_url = [string]$run.html_url
      created_at = [string]$run.created_at; updated_at = [string]$run.updated_at
    }
    artifact = [ordered]@{
      id = [long]$artifact.id; name = [string]$artifact.name; expired = [bool]$artifact.expired
      digest = [string]$artifact.digest; url = [string]$artifact.url; archive_download_url = [string]$artifact.archive_download_url
      workflow_run = [ordered]@{ id = [long]$artifact.workflow_run.id; head_sha = [string]$artifact.workflow_run.head_sha }
      created_at = [string]$artifact.created_at; updated_at = [string]$artifact.updated_at
    }
    downloaded_archive_sha256 = $archiveSha256
    downloaded_evidence_sha256 = $downloadedEvidenceSha256
    downloaded_sidecar_sha256 = $downloadedSidecarSha256
    sidecar_declared_evidence_sha256 = $evidenceSha256
    secret_output = $false
  }
} finally {
  $client.Dispose(); $handler.Dispose()
}

$readbackPath = "$resolvedEvidence.execution-readback.json"
$readbackSidecarPath = "$readbackPath.sha256"
Require (-not (Test-Path -LiteralPath $readbackPath) -and -not (Test-Path -LiteralPath $readbackSidecarPath)) 'Execution-readback pair already exists; immutable files are never overwritten.'
$readbackJson = $readback | ConvertTo-Json -Depth 20
$readbackBytes = $utf8NoBom.GetBytes($readbackJson)
$readbackSha256 = Get-BytesSha256 $readbackBytes
$readbackSidecarBytes = $utf8NoBom.GetBytes("$readbackSha256  $([IO.Path]::GetFileName($readbackPath))`n")
$sidecarCreated = $false
$readbackCreated = $false
try {
  $sidecarStream = [IO.File]::Open($readbackSidecarPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
  $sidecarCreated = $true
  try { $sidecarStream.Write($readbackSidecarBytes, 0, $readbackSidecarBytes.Length) } finally { $sidecarStream.Dispose() }
  $readbackStream = [IO.File]::Open($readbackPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
  $readbackCreated = $true
  try { $readbackStream.Write($readbackBytes, 0, $readbackBytes.Length) } finally { $readbackStream.Dispose() }
} catch {
  if ($readbackCreated -and (Test-Path -LiteralPath $readbackPath -PathType Leaf)) { Remove-Item -LiteralPath $readbackPath -Force }
  if ($sidecarCreated -and (Test-Path -LiteralPath $readbackSidecarPath -PathType Leaf)) { Remove-Item -LiteralPath $readbackSidecarPath -Force }
  throw
}

Write-Host "[phase6-scale-readback] collected=true evidence_sha256=$evidenceSha256 readback_sha256=$readbackSha256 anonymous_github_api=true token_used=false promotion=false"

#Requires -Version 7.0
<#
  Consumes the sanitized, source-bound success object emitted by the sole
  production deploy wrapper. This writer performs no network or provider call.
  It creates an immutable Phase6 deployment preflight report plus the mutable
  P6-only current-state pointer required by the one authorized 900-request run.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$DeployResultPath,
  [Parameter(Mandatory = $true)]
  [string]$PreviewGuardResultPath,
  [string]$EvidencePath = '',
  [string]$HostedStatePath = '',
  [switch]$AllowTestPaths
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\', '/')
$canonicalHostedStatePath = [IO.Path]::GetFullPath((Join-Path $repoRoot 'docs/runtime-state/phase6-scale-hosted-current.json'))
$canonicalEvidenceRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot '.codex/runs/CURRENT/phase6/deployment-preflight')).TrimEnd('\', '/')
$utf8NoBom = [Text.UTF8Encoding]::new($false)
$canonicalBaseUrl = 'https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev'
$canonicalPreviewBaseUrl = 'https://cloud-superbrain-stateful-runtime-preview.strazzusochr.workers.dev'
$minimumLoopFixCommit = 'c24b7bfddc37cfa0c16d1ebc7f70829417ac4080'

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "Phase6 deployment-preflight writer: $Message" }
}

function Assert-ExactProperties($Value, [string[]]$Expected, [string]$Label) {
  Assert-True ($null -ne $Value) "$Label is missing."
  $actual = @($Value.PSObject.Properties.Name | Sort-Object -Unique)
  $wanted = @($Expected | Sort-Object -Unique)
  $difference = @(Compare-Object -ReferenceObject $wanted -DifferenceObject $actual -CaseSensitive)
  Assert-True ($actual.Count -eq $wanted.Count -and $difference.Count -eq 0) "$Label property set is invalid."
}

function Test-JsonInteger($Value, [Int64]$Expected) {
  if ($Value -is [bool] -or $Value -is [string] -or $Value -is [double] -or $Value -is [single] -or $Value -is [decimal]) { return $false }
  return (($Value -is [byte] -or $Value -is [sbyte] -or $Value -is [int16] -or $Value -is [uint16] -or
    $Value -is [int32] -or $Value -is [uint32] -or $Value -is [int64] -or $Value -is [uint64]) -and [Int64]$Value -eq $Expected)
}

function Assert-UnderRoot([string]$Path, [string]$Root, [string]$Label) {
  $resolved = [IO.Path]::GetFullPath($Path)
  $boundedRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
  Assert-True ($resolved.StartsWith($boundedRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) "$Label escapes its allowed root."
  return $resolved
}

function Get-StrictUtcTimestamp([string]$Value, [string]$Label) {
  Assert-True ($Value -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?Z$') "$Label must be an explicit UTC timestamp."
  $parsed = [DateTimeOffset]::MinValue
  Assert-True ([DateTimeOffset]::TryParse(
    $Value,
    [Globalization.CultureInfo]::InvariantCulture,
    [Globalization.DateTimeStyles]::AssumeUniversal,
    [ref]$parsed
  )) "$Label is invalid."
  Assert-True ($parsed.Offset -eq [TimeSpan]::Zero) "$Label must use UTC."
  return $parsed.ToUniversalTime()
}

function Get-BytesSha256([byte[]]$Bytes) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return (($sha.ComputeHash($Bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
  } finally {
    $sha.Dispose()
  }
}

function Get-GitArchiveSha256([string]$CommitSha) {
  $temporaryPath = [IO.Path]::Combine([IO.Path]::GetTempPath(), "phase6-deploy-preflight-$([Guid]::NewGuid().ToString('N')).tar")
  try {
    & git -C $repoRoot cat-file -e "$CommitSha^{commit}" 2>$null
    Assert-True ($LASTEXITCODE -eq 0) 'Source commit is unavailable in local Git.'
    & git -C $repoRoot archive --format=tar "--output=$temporaryPath" $CommitSha
    Assert-True ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $temporaryPath -PathType Leaf)) 'Source archive could not be recomputed.'
    return (Get-FileHash -LiteralPath $temporaryPath -Algorithm SHA256).Hash.ToLowerInvariant()
  } finally {
    if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
      Remove-Item -LiteralPath $temporaryPath -Force
    }
  }
}

function Read-SanitizedJsonFile([string]$Path, [string]$Label) {
  $resolvedPath = [IO.Path]::GetFullPath($Path)
  Assert-True (Test-Path -LiteralPath $resolvedPath -PathType Leaf) "$Label file is missing."
  $item = Get-Item -LiteralPath $resolvedPath -Force
  Assert-True ([string]::IsNullOrEmpty([string]$item.LinkType)) "$Label file must not be a symbolic link."
  Assert-True ($item.Length -gt 0 -and $item.Length -le 16384) "$Label file size is invalid."
  $raw = Get-Content -LiteralPath $resolvedPath -Raw
  Assert-True ($raw -notmatch '(?i)(?:sk-|ghp_|github_pat_|glpat-|cfat_|vck_|hf_)[A-Za-z0-9_-]{12,}') "$Label contains secret-shaped material."
  Assert-True ($raw -notmatch '(?i)"(?:authorization|cookie|password|private_key|client_secret|token|credential)"\s*:') "$Label contains a forbidden credential field."
  try {
    $convertParameters = @{ Depth = 10; ErrorAction = 'Stop' }
    if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) { $convertParameters.DateKind = 'String' }
    return ($raw | ConvertFrom-Json @convertParameters)
  } catch {
    throw "Phase6 deployment-preflight writer: $Label is not valid JSON."
  }
}

$deployResult = Read-SanitizedJsonFile $DeployResultPath 'Deploy result'
$previewGuardResult = Read-SanitizedJsonFile $PreviewGuardResultPath 'Preview-guard result'

Assert-ExactProperties $deployResult @(
  'contract_version', 'base_url', 'verified_at_utc', 'source_commit_sha', 'source_archive_sha256',
  'source_bundle_sha256', 'worker_version_id', 'deployment_id', 'health_status', 'd1_read_verified',
  'worker_request_count', 'secret_output'
) 'Deploy result'
Assert-True ([string]$deployResult.contract_version -ceq 'cloudflare-phase6-production-deploy-result-v1') 'Deploy result contract is invalid.'
Assert-True ([string]$deployResult.base_url -ceq $canonicalBaseUrl) 'Deploy result is not bound to the canonical production Worker origin.'
Assert-True ([string]$deployResult.source_commit_sha -cmatch '^[0-9a-f]{40}$') 'Source commit SHA is invalid.'
Assert-True ([string]$deployResult.source_archive_sha256 -cmatch '^[0-9a-f]{64}$') 'Source archive SHA-256 is invalid.'
Assert-True ([string]$deployResult.source_bundle_sha256 -cmatch '^[0-9a-f]{64}$') 'Source bundle SHA-256 is invalid.'
Assert-True ([string]$deployResult.worker_version_id -cmatch '^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$') 'Worker version ID is invalid.'
Assert-True ([string]$deployResult.deployment_id -cmatch '^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$') 'Deployment ID is invalid.'
Assert-True (Test-JsonInteger $deployResult.health_status 200) 'The single production health request did not return integer HTTP 200.'
Assert-True ($deployResult.d1_read_verified -is [bool] -and $deployResult.d1_read_verified -eq $true) 'The single production health response did not verify the D1 read.'
Assert-True (Test-JsonInteger $deployResult.worker_request_count 1) 'Production deploy did not attest exactly one Worker request.'
Assert-True ($deployResult.secret_output -is [bool] -and $deployResult.secret_output -eq $false) 'Deploy result declares secret output.'

Assert-ExactProperties $previewGuardResult @(
  'contract_version', 'base_url', 'verified_at_utc', 'source_commit_sha', 'source_archive_sha256',
  'source_bundle_sha256', 'worker_version_id', 'deployment_id', 'control_plane_verified',
  'worker_request_count', 'secret_output'
) 'Preview-guard result'
Assert-True ([string]$previewGuardResult.contract_version -ceq 'cloudflare-phase6-preview-guard-deploy-result-v1') 'Preview-guard result contract is invalid.'
Assert-True ([string]$previewGuardResult.base_url -ceq $canonicalPreviewBaseUrl) 'Preview-guard result is not bound to the isolated Preview Worker origin.'
Assert-True ([string]$previewGuardResult.source_commit_sha -cmatch '^[0-9a-f]{40}$') 'Preview source commit SHA is invalid.'
Assert-True ([string]$previewGuardResult.source_archive_sha256 -cmatch '^[0-9a-f]{64}$') 'Preview source archive SHA-256 is invalid.'
Assert-True ([string]$previewGuardResult.source_bundle_sha256 -cmatch '^[0-9a-f]{64}$') 'Preview source bundle SHA-256 is invalid.'
Assert-True ([string]$previewGuardResult.worker_version_id -cmatch '^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$') 'Preview Worker version ID is invalid.'
Assert-True ([string]$previewGuardResult.deployment_id -cmatch '^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$') 'Preview deployment ID is invalid.'
Assert-True ($previewGuardResult.control_plane_verified -is [bool] -and $previewGuardResult.control_plane_verified -eq $true) 'Preview control-plane verification is not true.'
Assert-True (Test-JsonInteger $previewGuardResult.worker_request_count 0) 'Preview guard did not record integer zero Worker requests.'
Assert-True ($previewGuardResult.secret_output -is [bool] -and $previewGuardResult.secret_output -eq $false) 'Preview-guard result declares secret output.'
foreach ($sourceProperty in @('source_commit_sha', 'source_archive_sha256', 'source_bundle_sha256')) {
  Assert-True ([string]$previewGuardResult.$sourceProperty -ceq [string]$deployResult.$sourceProperty) "Preview and production results differ at $sourceProperty."
}
Assert-True ([string]$previewGuardResult.worker_version_id -cne [string]$deployResult.worker_version_id -and [string]$previewGuardResult.deployment_id -cne [string]$deployResult.deployment_id) 'Preview and production deployment identities are not isolated.'

$verifiedAt = Get-StrictUtcTimestamp ([string]$deployResult.verified_at_utc) 'Deploy verification timestamp'
$previewVerifiedAt = Get-StrictUtcTimestamp ([string]$previewGuardResult.verified_at_utc) 'Preview-guard verification timestamp'
$now = [DateTimeOffset]::UtcNow
Assert-True ($verifiedAt -le $now.AddMinutes(5)) 'Deploy verification timestamp is in the future.'
Assert-True (($now - $verifiedAt).TotalMinutes -le 10) 'Deploy verification result is stale.'
Assert-True ($previewVerifiedAt -le $now.AddMinutes(5)) 'Preview-guard verification timestamp is in the future.'
Assert-True (($now - $previewVerifiedAt).TotalMinutes -le 10) 'Preview-guard result is stale.'
Assert-True ($previewVerifiedAt -le $verifiedAt) 'Preview guard must precede production deployment verification.'
Assert-True (($verifiedAt - $previewVerifiedAt).TotalMinutes -le 10) 'Preview-to-production deployment window exceeded ten minutes.'
$sourceCommitSha = [string]$deployResult.source_commit_sha
$repositoryHeadSha = (& git -C $repoRoot rev-parse HEAD).Trim()
Assert-True ($repositoryHeadSha -cmatch '^[0-9a-f]{40}$') 'Repository HEAD is invalid.'
& git -C $repoRoot merge-base --is-ancestor $sourceCommitSha $repositoryHeadSha
Assert-True ($LASTEXITCODE -eq 0) 'Deployed source is not an ancestor of repository HEAD.'
& git -C $repoRoot merge-base --is-ancestor $minimumLoopFixCommit $sourceCommitSha
Assert-True ($LASTEXITCODE -eq 0) 'Deployed source does not contain the required contract-origin loop fix.'
$recomputedArchiveSha256 = Get-GitArchiveSha256 $sourceCommitSha
Assert-True ($recomputedArchiveSha256 -ceq [string]$deployResult.source_archive_sha256) 'Deploy result source archive does not match the declared Git commit.'

$preferredTestRoot = if (-not [string]::IsNullOrWhiteSpace($env:SUPERBRAIN_TEST_ROOT)) {
  $env:SUPERBRAIN_TEST_ROOT
} elseif (Test-Path -LiteralPath 'D:/_sb_tmp' -PathType Container) {
  'D:/_sb_tmp'
} else {
  [IO.Path]::GetTempPath()
}
$testRoot = [IO.Path]::GetFullPath($preferredTestRoot).TrimEnd('\', '/')

if ([string]::IsNullOrWhiteSpace($HostedStatePath)) {
  $HostedStatePath = $canonicalHostedStatePath
}
$resolvedHostedStatePath = [IO.Path]::GetFullPath($HostedStatePath)
if ([string]::IsNullOrWhiteSpace($EvidencePath)) {
  $stamp = $verifiedAt.ToString('yyyyMMddTHHmmssfffZ')
  $EvidencePath = Join-Path $canonicalEvidenceRoot "$stamp-$([string]$deployResult.deployment_id)/report.json"
}
$resolvedEvidencePath = [IO.Path]::GetFullPath($EvidencePath)

if ($AllowTestPaths) {
  $resolvedHostedStatePath = Assert-UnderRoot $resolvedHostedStatePath $testRoot 'Hosted-state test output'
  $resolvedEvidencePath = Assert-UnderRoot $resolvedEvidencePath $testRoot 'Evidence test output'
} else {
  Assert-True ($resolvedHostedStatePath.Equals($canonicalHostedStatePath, [StringComparison]::OrdinalIgnoreCase)) 'Production hosted-state output must use the canonical P6-only path.'
  $resolvedEvidencePath = Assert-UnderRoot $resolvedEvidencePath $canonicalEvidenceRoot 'Evidence output'
  $deployWrapperPath = 'scripts/deploy-cloudflare-stateful-runtime.ps1'
  & git -C $repoRoot cat-file -e "$sourceCommitSha`:$deployWrapperPath" 2>$null
  Assert-True ($LASTEXITCODE -eq 0) "Deployed source does not contain $deployWrapperPath."
  & git -C $repoRoot diff --quiet HEAD -- $deployWrapperPath
  Assert-True ($LASTEXITCODE -eq 0) "$deployWrapperPath has uncommitted changes."
  & git -C $repoRoot diff --quiet $sourceCommitSha $repositoryHeadSha -- $deployWrapperPath
  Assert-True ($LASTEXITCODE -eq 0) "$deployWrapperPath differs between deployed source and current HEAD."

  $writerRelativePath = 'scripts/write-phase6-scale-deployment-preflight.ps1'
  & git -C $repoRoot ls-files --error-unmatch -- $writerRelativePath 2>$null | Out-Null
  Assert-True ($LASTEXITCODE -eq 0) 'Deployment-preflight writer is not tracked at the control HEAD.'
  & git -C $repoRoot diff --quiet HEAD -- $writerRelativePath
  Assert-True ($LASTEXITCODE -eq 0) 'Deployment-preflight writer has uncommitted changes.'
}

Assert-True (-not (Test-Path -LiteralPath $resolvedEvidencePath)) 'Immutable deployment-preflight evidence path already exists.'
Assert-True (-not (Test-Path -LiteralPath "$resolvedEvidencePath.sha256")) 'Immutable deployment-preflight digest path already exists.'
if (Test-Path -LiteralPath $resolvedHostedStatePath) {
  $hostedStateItem = Get-Item -LiteralPath $resolvedHostedStatePath -Force
  Assert-True ([string]::IsNullOrEmpty([string]$hostedStateItem.LinkType)) 'Hosted-state output must not be a symbolic link.'
}

$nonClaims = @(
  'This preflight proves exactly one Worker request: one HTTP 200 health/source/deployment binding.',
  'The Preview guard used control-plane verification and issued zero Worker requests.',
  'No create, readback, delete, scale, release, or percentage credit is claimed.'
)
$evidence = [ordered]@{
  contract_version = 'phase6-scale-deployment-preflight-evidence-v1'
  verified_at_utc = $verifiedAt.UtcDateTime.ToString('o')
  status = 'verified'
  purpose = 'phase6_scale_single_run_preflight'
  base_url = [string]$deployResult.base_url
  source_commit_sha = $sourceCommitSha
  source_archive_sha256 = [string]$deployResult.source_archive_sha256
  source_bundle_sha256 = [string]$deployResult.source_bundle_sha256
  worker_version_id = [string]$deployResult.worker_version_id
  deployment_id = [string]$deployResult.deployment_id
  health_status = 200
  d1_read_verified = $true
  production_worker_request_count = 1
  preview_worker_request_count = 0
  source_binding_verified = $true
  health_json_source_binding_verified = $true
  preview_guard_verified = $true
  preview_guard_verified_at_utc = $previewVerifiedAt.UtcDateTime.ToString('o')
  preview_worker_version_id = [string]$previewGuardResult.worker_version_id
  preview_deployment_id = [string]$previewGuardResult.deployment_id
  hosted_write_read_delete_verified = $false
  phase6_scale_run_started = $false
  phase6_scale_run_verified = $false
  zero_card = $true
  paid_provider = $false
  dev_only = $false
  secret_output = $false
  producer = 'scripts/deploy-cloudflare-stateful-runtime.ps1'
  writer = 'scripts/write-phase6-scale-deployment-preflight.ps1'
  non_claims = $nonClaims
}
$evidenceJson = ($evidence | ConvertTo-Json -Depth 20) + "`n"
$evidenceBytes = $utf8NoBom.GetBytes($evidenceJson)
$evidenceSha256 = Get-BytesSha256 $evidenceBytes
$evidenceRelativePath = if ($AllowTestPaths) {
  $resolvedEvidencePath
} else {
  [IO.Path]::GetRelativePath($repoRoot, $resolvedEvidencePath).Replace('\', '/')
}
$hostedState = [ordered]@{
  contract_version = 'phase6-scale-hosted-deployment-current-v1'
  status = 'preflight_verified'
  verified_at_utc = $verifiedAt.UtcDateTime.ToString('o')
  base_url = [string]$deployResult.base_url
  runtime_contract_version = 'cloudflare-native-runtime-candidate-v2'
  health_contract_version = 'cloudflare-d1-stateful-runtime-v1'
  source_commit_sha = $sourceCommitSha
  source_archive_sha256 = [string]$deployResult.source_archive_sha256
  source_bundle_sha256 = [string]$deployResult.source_bundle_sha256
  worker_version_id = [string]$deployResult.worker_version_id
  deployment_id = [string]$deployResult.deployment_id
  evidence_artifact = $evidenceRelativePath
  evidence_sha256 = $evidenceSha256
  health_status = 200
  d1_read_verified = $true
  production_worker_request_count = 1
  preview_worker_request_count = 0
  deployment_preflight_verified = $true
  health_json_source_binding_verified = $true
  preview_guard_verified = $true
  preview_guard_verified_at_utc = $previewVerifiedAt.UtcDateTime.ToString('o')
  preview_worker_version_id = [string]$previewGuardResult.worker_version_id
  preview_deployment_id = [string]$previewGuardResult.deployment_id
  hosted_write_read_delete_verified = $false
  phase6_scale_run_started = $false
  phase6_scale_run_verified = $false
  zero_card_verified = $true
  paid_provider = $false
  dev_only = $false
  secret_output = $false
  non_claims = $nonClaims
}
$hostedStateJson = ($hostedState | ConvertTo-Json -Depth 20) + "`n"

$evidenceDirectory = Split-Path -Parent $resolvedEvidencePath
$stateDirectory = Split-Path -Parent $resolvedHostedStatePath
[IO.Directory]::CreateDirectory($evidenceDirectory) | Out-Null
[IO.Directory]::CreateDirectory($stateDirectory) | Out-Null
$sidecarPath = "$resolvedEvidencePath.sha256"
$stateTemporaryPath = "$resolvedHostedStatePath.phase6-$([Guid]::NewGuid().ToString('N')).tmp"
$sidecarCreated = $false
$evidenceCreated = $false
try {
  $sidecarText = "$evidenceSha256  $([IO.Path]::GetFileName($resolvedEvidencePath))`n"
  $sidecarStream = [IO.File]::Open($sidecarPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
  try {
    $sidecarBytes = $utf8NoBom.GetBytes($sidecarText)
    $sidecarStream.Write($sidecarBytes, 0, $sidecarBytes.Length)
    $sidecarStream.Flush($true)
  } finally {
    $sidecarStream.Dispose()
  }
  $sidecarCreated = $true

  $evidenceStream = [IO.File]::Open($resolvedEvidencePath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
  try {
    $evidenceStream.Write($evidenceBytes, 0, $evidenceBytes.Length)
    $evidenceStream.Flush($true)
  } finally {
    $evidenceStream.Dispose()
  }
  $evidenceCreated = $true
  Assert-True ((Get-FileHash -LiteralPath $resolvedEvidencePath -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $evidenceSha256) 'Written evidence digest mismatch.'

  [IO.File]::WriteAllText($stateTemporaryPath, $hostedStateJson, $utf8NoBom)
  [IO.File]::Move($stateTemporaryPath, $resolvedHostedStatePath, $true)
} catch {
  if (Test-Path -LiteralPath $stateTemporaryPath -PathType Leaf) { Remove-Item -LiteralPath $stateTemporaryPath -Force }
  if ($evidenceCreated -and (Test-Path -LiteralPath $resolvedEvidencePath -PathType Leaf)) { Remove-Item -LiteralPath $resolvedEvidencePath -Force }
  if ($sidecarCreated -and (Test-Path -LiteralPath $sidecarPath -PathType Leaf)) { Remove-Item -LiteralPath $sidecarPath -Force }
  throw
}

$result = [ordered]@{
  contract_version = 'phase6-scale-deployment-preflight-write-result-v1'
  hosted_state_path = if ($AllowTestPaths) { $resolvedHostedStatePath } else { [IO.Path]::GetRelativePath($repoRoot, $resolvedHostedStatePath).Replace('\', '/') }
  evidence_artifact = $evidenceRelativePath
  evidence_sha256 = $evidenceSha256
  source_commit_sha = $sourceCommitSha
  hosted_write_read_delete_verified = $false
  preview_guard_verified = $true
  phase6_scale_run_verified = $false
  network_calls = 0
  secret_output = $false
}
Write-Output ($result | ConvertTo-Json -Compress)

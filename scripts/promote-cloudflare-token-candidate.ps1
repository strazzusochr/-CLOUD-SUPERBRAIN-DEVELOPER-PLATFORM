#Requires -Version 7.0
[CmdletBinding()]
param(
  [string]$SecretFile = ([IO.Path]::Combine(
    [Environment]::GetFolderPath('UserProfile'),
    '.codex',
    'secrets',
    'cloud-superbrain.local.env'
  )),
  [string]$HostedEvidencePath = '.codex\runs\CURRENT\master-goal\t3\cloudflare-d1-hosted-v2\report.json',
  [string]$CapabilityStatePath = 'docs\runtime-state\capability-gates.json',
  [switch]$Apply,
  [switch]$OwnerGate,
  [switch]$AllowTestPaths,
  [switch]$SkipManagementProbeForTests
)

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).
  TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
$testRoot = [IO.Path]::GetFullPath('D:\_sb_tmp').
  TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Assert-Boolean($Object, [string]$PropertyName, [bool]$Expected, [string]$Label) {
  $property = $Object.PSObject.Properties[$PropertyName]
  Assert-True ($null -ne $property) "$Label missing boolean: $PropertyName"
  Assert-True ($property.Value -is [bool]) "$Label boolean has wrong type: $PropertyName"
  Assert-True ([bool]$property.Value -eq $Expected) "$Label boolean mismatch: $PropertyName"
}

function Read-EnvMap([string]$Path) {
  $map = [ordered]@{}
  foreach ($line in Get-Content -LiteralPath $Path) {
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=(.*)$') {
      $map[$matches[1]] = $matches[2].Trim().Trim('"')
    }
  }
  return $map
}

function Assert-NoReparseSecretPath([string]$Root, [string]$Path) {
  $resolvedRoot = [IO.Path]::GetFullPath($Root).
    TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  $resolvedPath = [IO.Path]::GetFullPath($Path)
  $resolvedDirectory = [IO.Path]::GetDirectoryName($resolvedPath).
    TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  Assert-True (
    $resolvedDirectory.Equals($resolvedRoot, [StringComparison]::OrdinalIgnoreCase) -or
    $resolvedDirectory.StartsWith(
      $resolvedRoot + [IO.Path]::DirectorySeparatorChar,
      [StringComparison]::OrdinalIgnoreCase
    )
  ) 'Secret directory escaped the approved root.'

  $cursor = $resolvedRoot
  $rootItem = Get-Item -LiteralPath $cursor -Force
  Assert-True (
    $rootItem.PSIsContainer -and
    -not ($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint)
  ) 'Secrets root cannot be a junction or symlink.'

  $relativeDirectory = [IO.Path]::GetRelativePath($resolvedRoot, $resolvedDirectory)
  if ($relativeDirectory -ne '.') {
    foreach ($segment in $relativeDirectory.Split(
      [IO.Path]::DirectorySeparatorChar,
      [StringSplitOptions]::RemoveEmptyEntries
    )) {
      $cursor = [IO.Path]::Combine($cursor, $segment)
      $directoryItem = Get-Item -LiteralPath $cursor -Force
      Assert-True (
        $directoryItem.PSIsContainer -and
        -not ($directoryItem.Attributes -band [IO.FileAttributes]::ReparsePoint)
      ) 'Secret directory cannot contain a junction or symlink segment.'
    }
  }

  $fileItem = Get-Item -LiteralPath $resolvedPath -Force
  Assert-True (
    -not $fileItem.PSIsContainer -and
    -not ($fileItem.Attributes -band [IO.FileAttributes]::ReparsePoint)
  ) 'Secret file must be a normal leaf file.'
}

function Assert-TokenFileStructure(
  [string]$Path,
  [string]$ExpectedActiveToken,
  [string]$ExpectedCandidateToken
) {
  $lines = @(Get-Content -LiteralPath $Path)
  $activePattern = '^\s*CLOUDFLARE_API_TOKEN\s*='
  $candidatePattern = '^\s*CLOUDFLARE_API_TOKEN_CANDIDATE\s*='
  Assert-True (@($lines | Where-Object { $_ -match $activePattern }).Count -eq 1) 'Active Cloudflare token entry must exist exactly once.'
  Assert-True (@($lines | Where-Object { $_ -match $candidatePattern }).Count -eq 1) 'Candidate Cloudflare token entry must exist exactly once.'
  $map = Read-EnvMap $Path
  Assert-True ([string]$map['CLOUDFLARE_API_TOKEN'] -eq $ExpectedActiveToken) 'Active Cloudflare token content changed unexpectedly.'
  Assert-True ([string]$map['CLOUDFLARE_API_TOKEN_CANDIDATE'] -eq $ExpectedCandidateToken) 'Candidate Cloudflare token content changed unexpectedly.'
}

function Assert-TokenFileHash([string]$Path, [string]$ExpectedHash, [string]$Label) {
  $actualHash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
  Assert-True ($actualHash -eq $ExpectedHash) "$Label hash verification failed; no old rollbacks may be deleted."
}

function Remove-SupersededTokenRollbacks(
  [string]$CurrentPath,
  [string]$VerifiedRollbackPath,
  [string]$ExpectedCurrentHash,
  [string]$ExpectedRollbackHash,
  [string]$ExpectedCurrentActiveToken,
  [string]$ExpectedCurrentCandidateToken,
  [string]$ExpectedRollbackActiveToken,
  [string]$ExpectedRollbackCandidateToken
) {
  $resolvedCurrent = [IO.Path]::GetFullPath($CurrentPath)
  $resolvedRollback = [IO.Path]::GetFullPath($VerifiedRollbackPath)
  $secretDirectory = [IO.Path]::GetDirectoryName($resolvedCurrent)
  $secretLeaf = [IO.Path]::GetFileName($resolvedCurrent)
  Assert-True (
    $secretLeaf.Equals('cloud-superbrain.local.env', [StringComparison]::OrdinalIgnoreCase)
  ) 'Rollback retention is allowed only for the exact cloud-superbrain.local.env file.'
  Assert-True (
    [IO.Path]::GetDirectoryName($resolvedRollback).Equals(
      $secretDirectory,
      [StringComparison]::OrdinalIgnoreCase
    )
  ) 'Verified rollback is not in the exact secret directory.'

  $directoryItem = Get-Item -LiteralPath $secretDirectory -Force
  Assert-True (
    $directoryItem.PSIsContainer -and
    -not ($directoryItem.Attributes -band [IO.FileAttributes]::ReparsePoint)
  ) 'Rollback retention cannot follow a junction or symlink directory.'

  $rollbackPrefix = $secretLeaf + '.rollback-'
  $rollbackNamePattern = '^' + [regex]::Escape($rollbackPrefix) + '[A-Za-z0-9][A-Za-z0-9-]*$'
  $rollbackPaths = @(
    [IO.Directory]::EnumerateFiles(
      $secretDirectory,
      $rollbackPrefix + '*',
      [IO.SearchOption]::TopDirectoryOnly
    ) | ForEach-Object { [IO.Path]::GetFullPath($_) }
  )
  Assert-True (
    @($rollbackPaths | Where-Object {
      $_.Equals($resolvedRollback, [StringComparison]::OrdinalIgnoreCase)
    }).Count -gt 0
  ) 'Verified rollback is missing after atomic promotion; old rollbacks must stay in place.'

  foreach ($rollbackPath in $rollbackPaths) {
    Assert-True (
      [IO.Path]::GetDirectoryName($rollbackPath).Equals(
        $secretDirectory,
        [StringComparison]::OrdinalIgnoreCase
      )
    ) 'Rollback retention escaped the exact secret directory.'
    Assert-True (
      [IO.Path]::GetFileName($rollbackPath) -match $rollbackNamePattern
    ) 'Rollback retention found a non-exact rollback leaf name.'
    $rollbackItem = Get-Item -LiteralPath $rollbackPath -Force
    Assert-True (
      -not $rollbackItem.PSIsContainer -and
      -not ($rollbackItem.Attributes -band [IO.FileAttributes]::ReparsePoint)
    ) 'Rollback retention cannot delete a non-leaf or reparse target.'
  }

  $currentItem = Get-Item -LiteralPath $resolvedCurrent -Force
  Assert-True (
    -not $currentItem.PSIsContainer -and
    -not ($currentItem.Attributes -band [IO.FileAttributes]::ReparsePoint)
  ) 'Current secret file must remain a normal leaf file.'
  Assert-TokenFileStructure `
    -Path $resolvedCurrent `
    -ExpectedActiveToken $ExpectedCurrentActiveToken `
    -ExpectedCandidateToken $ExpectedCurrentCandidateToken
  Assert-TokenFileStructure `
    -Path $resolvedRollback `
    -ExpectedActiveToken $ExpectedRollbackActiveToken `
    -ExpectedCandidateToken $ExpectedRollbackCandidateToken
  Assert-TokenFileHash -Path $resolvedCurrent -ExpectedHash $ExpectedCurrentHash -Label 'Current secret file'
  Assert-TokenFileHash -Path $resolvedRollback -ExpectedHash $ExpectedRollbackHash -Label 'Verified rollback'

  foreach ($rollbackPath in $rollbackPaths) {
    if (-not $rollbackPath.Equals($resolvedRollback, [StringComparison]::OrdinalIgnoreCase)) {
      Remove-Item -LiteralPath $rollbackPath -Force
    }
  }
}

function Resolve-SecretPath([string]$Path, [bool]$AllowTest) {
  $resolved = [IO.Path]::GetFullPath($Path)
  $secretRoot = [IO.Path]::GetFullPath([IO.Path]::Combine(
    [Environment]::GetFolderPath('UserProfile'),
    '.codex',
    'secrets'
  )).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  $approved = $resolved.StartsWith(
    $secretRoot + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase
  )
  $testApproved = $AllowTest -and $resolved.StartsWith(
    $testRoot + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase
  )
  Assert-True ($approved -or $testApproved) 'Secret path is outside the approved private directory.'
  Assert-True (
    [IO.Path]::GetFileName($resolved).Equals(
      'cloud-superbrain.local.env',
      [StringComparison]::OrdinalIgnoreCase
    )
  ) 'Secret file name must be exactly cloud-superbrain.local.env.'
  Assert-True (Test-Path -LiteralPath $resolved -PathType Leaf) 'Secret file is missing.'
  $validatedRoot = if ($approved) { $secretRoot } else { $testRoot }
  Assert-NoReparseSecretPath -Root $validatedRoot -Path $resolved
  return $resolved
}

function Resolve-EvidencePath([string]$Path, [string]$Label, [bool]$AllowTest) {
  $resolved = if ([IO.Path]::IsPathRooted($Path)) {
    [IO.Path]::GetFullPath($Path)
  } else {
    [IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
  }
  $repoApproved = $resolved.StartsWith(
    $repoRoot + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase
  )
  $testApproved = $AllowTest -and $resolved.StartsWith(
    $testRoot + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase
  )
  Assert-True ($repoApproved -or $testApproved) "$Label path is outside the approved roots."
  Assert-True (Test-Path -LiteralPath $resolved -PathType Leaf) "$Label is missing."
  return $resolved
}

function Write-ActiveTokenAtomically([string]$Path, [string]$CandidateToken) {
  $lines = @(Get-Content -LiteralPath $Path)
  $originalMap = Read-EnvMap $Path
  $originalActiveToken = [string]$originalMap['CLOUDFLARE_API_TOKEN']
  $originalCandidateToken = [string]$originalMap['CLOUDFLARE_API_TOKEN_CANDIDATE']
  Assert-TokenFileStructure `
    -Path $Path `
    -ExpectedActiveToken $originalActiveToken `
    -ExpectedCandidateToken $originalCandidateToken
  $originalHash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
  $activePattern = '^\s*CLOUDFLARE_API_TOKEN\s*='
  $updated = @(
    foreach ($line in $lines) {
      if ($line -match $activePattern) {
        'CLOUDFLARE_API_TOKEN=' + $CandidateToken
      } else {
        $line
      }
    }
  )
  $temporaryPath = $Path + '.candidate-promotion-' + [Guid]::NewGuid().ToString('N')
  $rollbackPath = $Path + '.rollback-qualified-' + (Get-Date).ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
  try {
    [IO.File]::WriteAllLines($temporaryPath, [string[]]$updated, [Text.UTF8Encoding]::new($false))
    $candidateMap = Read-EnvMap $temporaryPath
    Assert-True ([string]$candidateMap['CLOUDFLARE_API_TOKEN'] -eq $CandidateToken) 'Candidate promotion write verification failed.'
    Assert-True ([string]$candidateMap['CLOUDFLARE_API_TOKEN_CANDIDATE'] -eq $CandidateToken) 'Candidate source changed during promotion.'
    $expectedCurrentHash = (Get-FileHash -LiteralPath $temporaryPath -Algorithm SHA256).Hash.ToUpperInvariant()
    [IO.File]::Replace($temporaryPath, $Path, $rollbackPath, $true)
  } finally {
    if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
      Remove-Item -LiteralPath $temporaryPath -Force
    }
  }
  $written = Read-EnvMap $Path
  Assert-True ([string]$written['CLOUDFLARE_API_TOKEN'] -eq $CandidateToken) 'Promoted active token verification failed.'
  Assert-True ([string]$written['CLOUDFLARE_API_TOKEN_CANDIDATE'] -eq $CandidateToken) 'Promoted candidate verification failed.'
  Remove-SupersededTokenRollbacks `
    -CurrentPath $Path `
    -VerifiedRollbackPath $rollbackPath `
    -ExpectedCurrentHash $expectedCurrentHash `
    -ExpectedRollbackHash $originalHash `
    -ExpectedCurrentActiveToken $CandidateToken `
    -ExpectedCurrentCandidateToken $CandidateToken `
    -ExpectedRollbackActiveToken $originalActiveToken `
    -ExpectedRollbackCandidateToken $originalCandidateToken
  return $rollbackPath
}

$resolvedSecret = Resolve-SecretPath $SecretFile $AllowTestPaths
$resolvedEvidence = Resolve-EvidencePath $HostedEvidencePath 'Hosted evidence' $AllowTestPaths
$resolvedCapability = Resolve-EvidencePath $CapabilityStatePath 'Capability state' $AllowTestPaths
$secrets = Read-EnvMap $resolvedSecret
$activeToken = [string]$secrets['CLOUDFLARE_API_TOKEN']
$candidateToken = [string]$secrets['CLOUDFLARE_API_TOKEN_CANDIDATE']
Assert-True ($activeToken.Length -ge 20 -and $activeToken.Length -le 80 -and $activeToken -notmatch '\s') 'Active token has an invalid shape.'
Assert-True ($candidateToken.Length -ge 20 -and $candidateToken.Length -le 80 -and $candidateToken -notmatch '\s') 'Candidate token has an invalid shape.'

$evidence = Get-Content -LiteralPath $resolvedEvidence -Raw | ConvertFrom-Json
$evidenceHash = (Get-FileHash -LiteralPath $resolvedEvidence -Algorithm SHA256).Hash.ToUpperInvariant()
Assert-True ([string]$evidence.contract_version -eq 'cloudflare-d1-stateful-runtime-hosted-proof-v1') 'Hosted evidence contract mismatch.'
Assert-True ([string]$evidence.status -eq 'verified') 'Hosted evidence is not verified.'
foreach ($propertyName in @(
  'cloudflare_native_hosted_proof',
  'cloudflare_native_runtime_exercised',
  'cloudflare_native_create_enqueue_queue_do_d1_artifact_roundtrip',
  'cloudflare_native_d1_artifact_write_read_delete',
  'cloudflare_native_hosted_source_parity_verified',
  'cloudflare_native_r2_binding_absent',
  'cloudflare_native_zero_card_execution_verified'
)) {
  Assert-Boolean $evidence $propertyName $true 'Hosted evidence'
}
foreach ($propertyName in @(
  'cloudflare_native_dev_only',
  'cloudflare_native_paid_fallback_used',
  'cloudflare_native_live_provider_calls',
  'cloudflare_native_live_mcp_writes',
  'cloudflare_native_production_deploy',
  'secret_output'
)) {
  Assert-Boolean $evidence $propertyName $false 'Hosted evidence'
}
Assert-True ([string]$evidence.source_commit_sha -match '^[0-9a-f]{40}$') 'Hosted evidence source commit is invalid.'
Assert-True ([string]$evidence.source_archive_sha256 -match '^[0-9a-f]{64}$') 'Hosted evidence source archive is invalid.'

$capabilityState = Get-Content -LiteralPath $resolvedCapability -Raw | ConvertFrom-Json
$gate = $capabilityState.gates.cloudflare_native_zero_card_hosted_runtime
Assert-True ($null -ne $gate) 'Cloudflare-native capability gate is missing.'
foreach ($propertyName in @(
  'owner_granted',
  'local_candidate_verified',
  'zero_card_verified',
  'hosted_source_parity_verified',
  'hosted_stateful_roundtrip_verified',
  'live_verified'
)) {
  Assert-Boolean $gate $propertyName $true 'Cloudflare-native capability gate'
}
Assert-Boolean $gate 'r2_enabled' $false 'Cloudflare-native capability gate'
Assert-Boolean $gate 'paid_provider' $false 'Cloudflare-native capability gate'
Assert-True ([string]$gate.artifact_adapter -eq 'cloudflare-d1-bounded-text') 'Cloudflare-native artifact adapter mismatch.'
Assert-True ([string]$gate.r2_status -eq 'historical_only') 'Cloudflare-native R2 state mismatch.'
Assert-True ([string]$gate.evidence_sha256 -eq $evidenceHash) 'Capability evidence hash mismatch.'
Assert-True ([string]$gate.source_commit_sha -eq [string]$evidence.source_commit_sha) 'Capability source commit mismatch.'
Assert-True ([string]$gate.source_archive_sha256 -eq [string]$evidence.source_archive_sha256) 'Capability source archive mismatch.'
$gateEvidencePath = Resolve-EvidencePath ([string]$gate.evidence_artifact) 'Capability evidence artifact' $AllowTestPaths
Assert-True ($gateEvidencePath -eq $resolvedEvidence) 'Capability evidence path mismatch.'

if (-not $SkipManagementProbeForTests) {
  Assert-True (-not $AllowTestPaths) 'Management probe cannot run in test-path mode.'
  $probeScript = Join-Path $PSScriptRoot 'owner-set-cloudflare-token.ps1'
  & pwsh -NoProfile -File $probeScript -SecretFile $resolvedSecret -ProbeOnly -Profile O2Core
  Assert-True ($LASTEXITCODE -eq 0) 'Candidate O2Core management probe failed.'
} else {
  Assert-True ([bool]$AllowTestPaths) 'Management probe bypass is test-path-only.'
}

if (-not $Apply) {
  Write-Host '[cloudflare-token-promotion] eligible=true apply=false secret_output=false'
  exit 0
}
Assert-True ([bool]$OwnerGate) 'Token promotion requires -OwnerGate.'
if ($activeToken -eq $candidateToken) {
  Write-Host '[cloudflare-token-promotion] eligible=true already_active=true secret_output=false'
  exit 0
}

$rollbackPath = Write-ActiveTokenAtomically -Path $resolvedSecret -CandidateToken $candidateToken
Write-Host ("[cloudflare-token-promotion] promoted=true rollback={0} secret_output=false" -f $rollbackPath)
exit 0

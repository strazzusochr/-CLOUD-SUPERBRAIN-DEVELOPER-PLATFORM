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
  Assert-True (Test-Path -LiteralPath $resolved -PathType Leaf) 'Secret file is missing.'
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
  $activePattern = '^\s*CLOUDFLARE_API_TOKEN\s*='
  $candidatePattern = '^\s*CLOUDFLARE_API_TOKEN_CANDIDATE\s*='
  Assert-True (@($lines | Where-Object { $_ -match $activePattern }).Count -eq 1) 'Active Cloudflare token entry must exist exactly once.'
  Assert-True (@($lines | Where-Object { $_ -match $candidatePattern }).Count -eq 1) 'Candidate Cloudflare token entry must exist exactly once.'
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
    [IO.File]::Replace($temporaryPath, $Path, $rollbackPath, $true)
  } finally {
    if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
      Remove-Item -LiteralPath $temporaryPath -Force
    }
  }
  $written = Read-EnvMap $Path
  Assert-True ([string]$written['CLOUDFLARE_API_TOKEN'] -eq $CandidateToken) 'Promoted active token verification failed.'
  Assert-True ([string]$written['CLOUDFLARE_API_TOKEN_CANDIDATE'] -eq $CandidateToken) 'Promoted candidate verification failed.'
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

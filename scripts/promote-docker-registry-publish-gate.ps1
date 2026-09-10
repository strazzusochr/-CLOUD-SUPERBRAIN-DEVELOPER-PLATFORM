[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$EvidencePath,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^prod-candidate-[A-Za-z0-9._-]+$')]
  [string]$ExpectedReleaseId,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[0-9a-f]{40}$')]
  [string]$ExpectedCandidateSha,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[0-9a-f]{40}$')]
  [string]$ExpectedControlSha,

  [string]$CapabilityStatePath = 'docs/runtime-state/capability-gates.json',
  [string]$ExpectedCapabilityStateSha256 = '',
  [string]$ExpectedGateIdentitySha256 = '',
  [switch]$ValidateOnly,
  [switch]$Promote
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$canonicalCapabilityPath = 'docs/runtime-state/capability-gates.json'
$canonicalVerifier = 'scripts/verify_layer5_registry_release_evidence.py'

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

Assert-True ($ValidateOnly -xor $Promote) 'Choose exactly one mode: -ValidateOnly or -Promote.'

function Resolve-RepoFile([string]$Path, [string]$Label) {
  Assert-True (-not [string]::IsNullOrWhiteSpace($Path)) "$Label path is required."
  $rootPrefix = [IO.Path]::GetFullPath($repoRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  $absolute = if ([IO.Path]::IsPathRooted($Path)) {
    [IO.Path]::GetFullPath($Path)
  } else {
    [IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
  }
  Assert-True $absolute.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase) "$Label path escapes the repository."
  Assert-True (Test-Path -LiteralPath $absolute -PathType Leaf) "$Label is missing."
  $relative = [IO.Path]::GetRelativePath($repoRoot, $absolute).Replace('\', '/')
  Assert-True (-not $relative.Split('/').Contains('..')) "$Label path traversal is forbidden."
  return [pscustomobject]@{ absolute = $absolute; relative = $relative }
}

function Assert-TrackedClean([object]$Resolved, [string]$Label) {
  & git -C $repoRoot ls-files --error-unmatch -- $Resolved.relative 2>$null | Out-Null
  Assert-True ($LASTEXITCODE -eq 0) "$Label must be tracked by Git."
  & git -C $repoRoot diff --quiet HEAD -- $Resolved.relative
  Assert-True ($LASTEXITCODE -eq 0) "$Label must be clean relative to HEAD."
}

function Assert-ExactProperties([object]$Object, [string[]]$Expected, [string]$Label) {
  $actual = @($Object.PSObject.Properties.Name)
  Assert-True ($actual.Count -eq $Expected.Count) "$Label property count mismatch."
  foreach ($name in $Expected) { Assert-True ($actual -ccontains $name) "$Label is missing '$name'." }
  foreach ($name in $actual) { Assert-True ($Expected -ccontains $name) "$Label contains unknown '$name'." }
}

function Get-FileSha([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-TextSha([string]$Value) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

function Get-GateIdentity([object]$Gate) {
  $evidenceSha = if ($null -ne $Gate.PSObject.Properties['evidence_sha256']) { [string]$Gate.evidence_sha256 } else { '' }
  return (@(
    [string]$Gate.owner_granted,
    [string]$Gate.owner_grant_ref,
    [string]$Gate.live_verified,
    [string]$Gate.evidence_artifact,
    $evidenceSha,
    [string]$Gate.verified_at_utc,
    [string]$Gate.provider,
    [string]$Gate.paid_provider,
    [string]$Gate.verifier,
    [string]$Gate.note
  ) -join '|')
}

function Write-AtomicJson([string]$TargetPath, [object]$Value) {
  $temporaryPath = "$TargetPath.registry-publish-$([Guid]::NewGuid().ToString('N')).tmp"
  try {
    $json = ($Value | ConvertTo-Json -Depth 40) + "`n"
    $stream = [IO.File]::Open($temporaryPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
      $writer = [IO.StreamWriter]::new($stream, [Text.UTF8Encoding]::new($false))
      try { $writer.Write($json) } finally { $writer.Dispose() }
    } finally { if ($null -ne $stream) { $stream.Dispose() } }
    $null = Get-Content -LiteralPath $temporaryPath -Raw | ConvertFrom-Json
    [IO.File]::Move($temporaryPath, $TargetPath, $true)
  } finally {
    if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) { Remove-Item -LiteralPath $temporaryPath -Force }
  }
}

$evidence = Resolve-RepoFile $EvidencePath 'Layer-5 registry evidence'
$capability = Resolve-RepoFile $CapabilityStatePath 'Capability state'
$verifier = Resolve-RepoFile $canonicalVerifier 'Layer-5 registry verifier'
Assert-True ($capability.relative -ceq $canonicalCapabilityPath) 'CapabilityStatePath must be canonical.'
Assert-TrackedClean $evidence 'Layer-5 registry evidence'
Assert-TrackedClean $capability 'Capability state'
Assert-TrackedClean $verifier 'Layer-5 registry verifier'

foreach ($sha in @($ExpectedCandidateSha, $ExpectedControlSha)) {
  & git -C $repoRoot cat-file -e "$sha^{commit}" 2>$null
  Assert-True ($LASTEXITCODE -eq 0) 'Expected candidate/control commit is unknown.'
}
& git -C $repoRoot merge-base --is-ancestor $ExpectedCandidateSha $ExpectedControlSha
Assert-True ($LASTEXITCODE -eq 0) 'Registry control commit does not descend from candidate source.'
& git -C $repoRoot merge-base --is-ancestor $ExpectedControlSha HEAD
Assert-True ($LASTEXITCODE -eq 0) 'Current HEAD does not descend from registry control commit.'

try { $aggregate = Get-Content -LiteralPath $evidence.absolute -Raw | ConvertFrom-Json } catch { throw 'Layer-5 registry evidence must be valid JSON.' }
Assert-True ([string]$aggregate.release_id -ceq $ExpectedReleaseId) 'Layer-5 registry release id mismatch.'
Assert-True ([string]$aggregate.source_commit_sha -ceq $ExpectedCandidateSha) 'Layer-5 registry candidate SHA mismatch.'
Assert-True ([string]$aggregate.control_commit_sha -ceq $ExpectedControlSha) 'Layer-5 registry control SHA mismatch.'

$python = Get-Command py -ErrorAction SilentlyContinue
$verifyOutput = if ($null -ne $python) {
  @(& $python.Source -3 $verifier.absolute --evidence $evidence.relative --expected-release-id $ExpectedReleaseId --expected-source-sha $ExpectedCandidateSha --expected-control-sha $ExpectedControlSha --validate-only 2>&1)
} else {
  $python = Get-Command python -ErrorAction Stop
  @(& $python.Source $verifier.absolute --evidence $evidence.relative --expected-release-id $ExpectedReleaseId --expected-source-sha $ExpectedCandidateSha --expected-control-sha $ExpectedControlSha --validate-only 2>&1)
}
Assert-True ($LASTEXITCODE -eq 0) 'Layer-5 registry evidence failed its canonical verifier.'
$verifyText = ($verifyOutput | ForEach-Object { [string]$_ }) -join "`n"
Assert-True $verifyText.Contains('[layer5-registry-release-evidence] PASS') 'Layer-5 registry verifier success marker is missing.'

try { $state = Get-Content -LiteralPath $capability.absolute -Raw | ConvertFrom-Json } catch { throw 'Capability state must be valid JSON.' }
Assert-True ([string]$state.contract_version -ceq 'capability-gate-state-v1') 'Capability-state contract mismatch.'
Assert-True ([string]$state.status -ceq 'configured') 'Capability-state status mismatch.'
Assert-True ($null -ne $state.gates.docker_registry_publish) 'docker_registry_publish gate is missing.'
$gate = $state.gates.docker_registry_publish
$gateProperties = @('owner_granted', 'owner_grant_ref', 'live_verified', 'evidence_artifact', 'verified_at_utc', 'provider', 'paid_provider', 'verifier', 'note')
if ($null -ne $gate.PSObject.Properties['evidence_sha256']) {
  $gateProperties = @('owner_granted', 'owner_grant_ref', 'live_verified', 'evidence_artifact', 'evidence_sha256', 'verified_at_utc', 'provider', 'paid_provider', 'verifier', 'note')
}
Assert-ExactProperties $gate $gateProperties 'docker_registry_publish gate'
Assert-True ($gate.owner_granted -is [bool] -and [bool]$gate.owner_granted) 'docker_registry_publish Owner grant is not present.'
Assert-True ($gate.owner_grant_ref -is [string] -and -not [string]::IsNullOrWhiteSpace($gate.owner_grant_ref)) 'docker_registry_publish Owner grant reference is missing.'
Assert-True ($gate.paid_provider -is [bool] -and -not [bool]$gate.paid_provider) 'docker_registry_publish must remain zero-card.'
Assert-True ($gate.live_verified -is [bool]) 'docker_registry_publish live_verified must be a JSON boolean.'

$evidenceSha = Get-FileSha $evidence.absolute
$stateSha = Get-FileSha $capability.absolute
$gateIdentitySha = Get-TextSha (Get-GateIdentity $gate)

if ([bool]$gate.live_verified) {
  Assert-True ([string]$gate.evidence_artifact -ceq $evidence.relative) 'Promoted registry evidence path mismatch.'
  Assert-True ([string]$gate.evidence_sha256 -ceq $evidenceSha) 'Promoted registry evidence hash mismatch.'
  Assert-True ([string]$gate.provider -ceq 'ghcr') 'Promoted registry provider mismatch.'
  Assert-True ([string]$gate.verifier -ceq $canonicalVerifier) 'Promoted registry verifier mismatch.'
  Assert-True (-not $Promote) 'docker_registry_publish is already promoted.'
  Write-Host "[docker-registry-publish-gate] status=verified promoted=true validation_mode=true evidence_sha256=$evidenceSha secret_output=false"
  exit 0
}

foreach ($field in @('evidence_artifact', 'verified_at_utc', 'verifier')) {
  Assert-True ([string]$gate.$field -ceq '') "Registry pre-promotion field must be empty: $field"
}
Assert-True ([string]$gate.provider -ceq 'ghcr') 'Registry pre-promotion provider must remain ghcr.'
if ($null -ne $gate.PSObject.Properties['evidence_sha256']) {
  Assert-True ([string]$gate.evidence_sha256 -ceq '') 'Registry pre-promotion evidence hash must be empty.'
}

if ($ValidateOnly) {
  Write-Host "[docker-registry-publish-gate] status=promotion_ready promoted=false validation_mode=true capability_state_sha256=$stateSha gate_identity_sha256=$gateIdentitySha evidence_sha256=$evidenceSha secret_output=false"
  exit 0
}

Assert-True ($ExpectedCapabilityStateSha256 -match '^[0-9a-fA-F]{64}$' -and $ExpectedCapabilityStateSha256.ToLowerInvariant() -ceq $stateSha) 'Current capability-state identity was not supplied or changed.'
Assert-True ($ExpectedGateIdentitySha256 -match '^[0-9a-fA-F]{64}$' -and $ExpectedGateIdentitySha256.ToLowerInvariant() -ceq $gateIdentitySha) 'Current registry gate identity was not supplied or changed.'
Assert-True ((Get-FileSha $capability.absolute) -ceq $stateSha) 'Capability state changed during validation.'

$beforeOtherGates = [ordered]@{}
foreach ($property in $state.gates.PSObject.Properties) {
  if ($property.Name -cne 'docker_registry_publish') {
    $beforeOtherGates[$property.Name] = $property.Value | ConvertTo-Json -Depth 30 -Compress
  }
}
$clone = ($state | ConvertTo-Json -Depth 40) | ConvertFrom-Json
$candidateGate = $clone.gates.docker_registry_publish
$candidateGate.live_verified = $true
$candidateGate.evidence_artifact = $evidence.relative
if ($null -ne $candidateGate.PSObject.Properties['evidence_sha256']) {
  $candidateGate.evidence_sha256 = $evidenceSha
} else {
  $candidateGate | Add-Member -MemberType NoteProperty -Name evidence_sha256 -Value $evidenceSha
}
$candidateGate.verified_at_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$candidateGate.provider = 'ghcr'
$candidateGate.paid_provider = $false
$candidateGate.verifier = $canonicalVerifier
$candidateGate.note = "Verified from layer5-registry-release-credit-evidence-v1; evidence_sha256=$evidenceSha"

foreach ($property in $clone.gates.PSObject.Properties) {
  if ($property.Name -cne 'docker_registry_publish') {
    Assert-True (($property.Value | ConvertTo-Json -Depth 30 -Compress) -ceq [string]$beforeOtherGates[$property.Name]) "Unrelated capability gate changed: $($property.Name)"
  }
}

$original = Get-Content -LiteralPath $capability.absolute -Raw
try {
  Write-AtomicJson $capability.absolute $clone
  $written = Get-Content -LiteralPath $capability.absolute -Raw | ConvertFrom-Json
  $writtenGate = $written.gates.docker_registry_publish
  Assert-True ([bool]$writtenGate.live_verified) 'Registry promotion did not persist live_verified.'
  Assert-True ([string]$writtenGate.owner_grant_ref -ceq [string]$gate.owner_grant_ref) 'Registry promotion changed the Owner grant reference.'
  Assert-True ([string]$writtenGate.evidence_artifact -ceq $evidence.relative) 'Registry promotion persisted the wrong evidence path.'
  Assert-True ([string]$writtenGate.evidence_sha256 -ceq $evidenceSha) 'Registry promotion persisted the wrong evidence hash.'
  Assert-True ([string]$writtenGate.verifier -ceq $canonicalVerifier) 'Registry promotion persisted the wrong verifier.'
} catch {
  $failure = $_
  $restorePath = "$($capability.absolute).registry-publish-restore-$([Guid]::NewGuid().ToString('N')).tmp"
  try {
    [IO.File]::WriteAllText($restorePath, $original, [Text.UTF8Encoding]::new($false))
    [IO.File]::Move($restorePath, $capability.absolute, $true)
  } finally {
    if (Test-Path -LiteralPath $restorePath -PathType Leaf) { Remove-Item -LiteralPath $restorePath -Force }
  }
  throw $failure
}

Write-Host "[docker-registry-publish-gate] status=promoted promoted=true validation_mode=false evidence_sha256=$evidenceSha backup_created=false secret_output=false"

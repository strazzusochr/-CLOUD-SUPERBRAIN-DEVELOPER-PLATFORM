#requires -Version 7.0
<#
  Revoke stale candidate proof for one explicitly selected gate. Default: read-only
  validation. -Rearm requires the exact state and gate hashes returned by validation.
  NewOwnerGrantRef records the caller's authorization as
  <reference>::<gate-id>::<new-release-id>::<new-source-sha>. It is a provenance
  reference, not authentication or a new permission grant: owner_granted must already
  be true. This tool never verifies a live gate or awards progress credit.
  All tests use temporary repositories; do not run -Rearm as part of verification.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$GateId,

  [Parameter(Mandatory = $true)]
  [string]$OldEvidencePath,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[0-9a-fA-F]{64}$')]
  [string]$OldEvidenceSha256,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^prod-candidate-[A-Za-z0-9._-]+$')]
  [string]$OldReleaseId,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[0-9a-f]{40}$')]
  [string]$OldSourceSha,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[0-9a-f]{40}$')]
  [string]$OldQualificationSha,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^prod-candidate-[A-Za-z0-9._-]+$')]
  [string]$NewReleaseId,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[0-9a-f]{40}$')]
  [string]$NewSourceSha,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[0-9a-f]{40}$')]
  [string]$NewQualificationSha,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[0-9a-fA-F]{64}$')]
  [string]$NewSourceArchiveSha256,

  [Parameter(Mandatory = $true)]
  [string]$NewOwnerGrantRef,

  [string]$CandidatePointerPath = 'docs/release-artifacts/current-release-candidate.json',
  [string]$SourceQualificationControlPath = 'docs/runtime-state/source-qualification-control.json',
  [string]$CapabilityStatePath = 'docs/runtime-state/capability-gates.json',
  [string]$ExpectedCapabilityStateSha256 = '',
  [string]$ExpectedGateIdentitySha256 = '',
  [switch]$Rearm
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$supportedGates = @{
  docker_registry_publish = @{
    oldContract = 'layer5-registry-release-credit-evidence-v1'
    oldVerifier = 'scripts/verify_layer5_registry_release_evidence.py'
    rearmedProvider = 'ghcr'
    oldProvider = 'ghcr'
  }
  phase6_scale_runtime = @{
    oldContract = 'phase6-scale-evidence-v2'
    oldVerifier = 'scripts/verify-phase6-scale-evidence.ps1'
    rearmedProvider = ''
    oldProvider = 'cloudflare-workers-d1-zero-card'
  }
}

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Resolve-RepoFile([string]$Path, [string]$Label) {
  Assert-True (-not [string]::IsNullOrWhiteSpace($Path)) "$Label path is required."
  $root = [IO.Path]::GetFullPath($repoRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  $absolute = if ([IO.Path]::IsPathRooted($Path)) {
    [IO.Path]::GetFullPath($Path)
  } else {
    [IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
  }
  Assert-True $absolute.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) "$Label path escapes repository."
  Assert-True (Test-Path -LiteralPath $absolute -PathType Leaf) "$Label is missing."
  $item = Get-Item -LiteralPath $absolute -Force
  while ($null -ne $item) {
    Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) "$Label must not traverse a symlink, junction, or reparse point."
    if ($item.FullName.TrimEnd('\', '/') -eq $root.TrimEnd('\', '/')) { break }
    $item = Get-Item -LiteralPath (Split-Path -Parent $item.FullName) -Force
  }
  $relative = [IO.Path]::GetRelativePath($repoRoot, $absolute).Replace('\', '/')
  Assert-True (-not $relative.Split('/').Contains('..')) "$Label path traversal is forbidden."
  return [pscustomobject]@{ absolute = $absolute; relative = $relative }
}

function Convert-JsonText([string]$Text) {
  # PowerShell 7.5+ otherwise converts date strings and rewrites unrelated gate data.
  $options = @{}
  if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) { $options.DateKind = 'String' }
  return ConvertFrom-Json -InputObject $Text @options
}

function Read-JsonFile([string]$Path, [string]$Label) {
  try { return Convert-JsonText (Get-Content -LiteralPath $Path -Raw) } catch { throw "$Label must be valid JSON." }
}

function Get-FileSha([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-TextSha([string]$Value) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}

function Assert-ExactProperties([object]$Object, [string[]]$Expected, [string]$Label) {
  $actual = @($Object.PSObject.Properties.Name)
  Assert-True ($actual.Count -eq $Expected.Count) "$Label property count mismatch."
  foreach ($name in $Expected) { Assert-True ($actual -ccontains $name) "$Label is missing '$name'." }
  foreach ($name in $actual) { Assert-True ($Expected -ccontains $name) "$Label contains unknown '$name'." }
}

function Assert-BooleanField([object]$Object, [string]$Name, [bool]$Expected, [string]$Label) {
  $property = $Object.PSObject.Properties[$Name]
  Assert-True ($null -ne $property) "$Label is missing '$Name'."
  Assert-True ($property.Value -is [bool]) "$Label '$Name' must be a JSON boolean."
  Assert-True ([bool]$property.Value -eq $Expected) "$Label '$Name' mismatch."
}

function Test-IsoOrDateTimeValue([object]$Value) {
  $parsed = [datetimeoffset]::MinValue
  return ($Value -is [string] -and $Value -match '^\d{4}-\d{2}-\d{2}T.*(?:Z|[+-]\d{2}:\d{2})$' -and
    [datetimeoffset]::TryParse($Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed))
}

function Assert-TrackedClean([object]$Resolved, [string]$Label) {
  & git -C $repoRoot ls-files --error-unmatch -- $Resolved.relative 2>$null | Out-Null
  Assert-True ($LASTEXITCODE -eq 0) "$Label must be tracked."
  & git -C $repoRoot diff --quiet HEAD -- $Resolved.relative
  Assert-True ($LASTEXITCODE -eq 0) "$Label must be clean relative to HEAD."
}

function Assert-KnownCommit([string]$Sha, [string]$Label) {
  & git -C $repoRoot cat-file -e "$Sha^{commit}" 2>$null
  Assert-True ($LASTEXITCODE -eq 0) "$Label commit is unknown."
}

function Assert-Ancestor([string]$Ancestor, [string]$Descendant, [string]$Message) {
  & git -C $repoRoot merge-base --is-ancestor $Ancestor $Descendant
  Assert-True ($LASTEXITCODE -eq 0) $Message
}

function Assert-DirectChild([string]$Parent, [string]$Child) {
  $parents = @(& git -C $repoRoot show -s --format=%P $Child)
  Assert-True ($LASTEXITCODE -eq 0) 'Unable to inspect new qualification commit.'
  $parentList = @(([string]$parents[0]).Split(' ', [StringSplitOptions]::RemoveEmptyEntries))
  Assert-True ($parentList.Count -eq 1 -and $parentList[0] -ceq $Parent) 'New qualification commit must be the direct child of the new source.'
}

function Get-GitArchiveSha256([string]$CommitSha) {
  $temporaryPath = [IO.Path]::Combine([IO.Path]::GetTempPath(), "candidate-rearm-archive-$([Guid]::NewGuid().ToString('N')).tar")
  try {
    & git -C $repoRoot archive --format=tar --output=$temporaryPath $CommitSha
    Assert-True ($LASTEXITCODE -eq 0) 'Unable to archive new source commit.'
    return Get-FileSha $temporaryPath
  } finally {
    if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) { Remove-Item -LiteralPath $temporaryPath -Force }
  }
}

function Get-GateIdentity([string]$GateName, [object]$Gate) {
  $fields = [ordered]@{
    gate_id = $GateName
    owner_granted = $Gate.owner_granted
    owner_grant_ref = [string]$Gate.owner_grant_ref
    live_verified = $Gate.live_verified
    evidence_artifact = [string]$Gate.evidence_artifact
    evidence_sha256 = if ($null -ne $Gate.PSObject.Properties['evidence_sha256']) { [string]$Gate.evidence_sha256 } else { '' }
    verified_at_utc = [string]$Gate.verified_at_utc
    provider = [string]$Gate.provider
    paid_provider = $Gate.paid_provider
    verifier = [string]$Gate.verifier
    note = [string]$Gate.note
  }
  return ($fields | ConvertTo-Json -Compress)
}

function Assert-OldEvidence([object]$Evidence, [string]$GateName, [hashtable]$Spec) {
  if ($GateName -eq 'docker_registry_publish') {
    Assert-True ([string]$Evidence.contract_version -ceq $Spec.oldContract) 'Old GHCR aggregate evidence contract mismatch.'
    Assert-True ([string]$Evidence.status -ceq 'verified') 'Old GHCR aggregate evidence is not verified.'
    Assert-True ([string]$Evidence.release_id -ceq $OldReleaseId) 'Old GHCR release mismatch.'
    Assert-True ([string]$Evidence.source_commit_sha -ceq $OldSourceSha) 'Old GHCR source mismatch.'
    Assert-True ([string]$Evidence.control_commit_sha -ceq $OldQualificationSha) 'Old GHCR qualification/control mismatch.'
    return
  }

  Assert-True ([string]$Evidence.contract_version -ceq $Spec.oldContract) 'Old Phase6 evidence contract mismatch.'
  Assert-True ([string]$Evidence.result -ceq 'provisional_pending_github_readback') 'Old Phase6 raw evidence must retain provisional status.'
  Assert-True ([string]$Evidence.criterion_binding.gate_id -ceq 'phase6_scale_runtime') 'Old Phase6 gate binding mismatch.'
  Assert-True ([string]$Evidence.source_binding.source_commit_sha -ceq $OldSourceSha) 'Old Phase6 source mismatch.'
  Assert-True ([string]$Evidence.source_binding.release_candidate.active_release_id -ceq $OldReleaseId) 'Old Phase6 release mismatch.'
  Assert-True ([string]$Evidence.source_binding.release_candidate.source_commit_sha -ceq $OldSourceSha) 'Old Phase6 release source mismatch.'
  Assert-True ([string]$Evidence.source_binding.repository_head_sha -ceq $OldQualificationSha) 'Old Phase6 qualification/control mismatch.'
  Assert-True (@($Evidence.non_claims) -contains 'This evidence file does not promote phase6_scale_runtime.') 'Old Phase6 non-promotion contract missing.'
}

function Assert-CandidatePointer([object]$Pointer) {
  Assert-True ([string]$Pointer.active_release_id -ceq $NewReleaseId) 'New candidate pointer release mismatch.'
  Assert-True ([string]$Pointer.source_commit_sha -ceq $NewSourceSha) 'New candidate pointer source mismatch.'
  Assert-BooleanField $Pointer 'production_rollout_claimed' $false 'New candidate pointer'
  if ($null -ne $Pointer.PSObject.Properties['source_archive_sha256']) {
    Assert-True ([string]$Pointer.source_archive_sha256 -match '^[0-9a-fA-F]{64}$') 'New candidate pointer source archive hash invalid.'
    Assert-True ([string]$Pointer.source_archive_sha256 -ieq $NewSourceArchiveSha256) 'New candidate pointer source archive mismatch.'
  }
}

function Assert-SourceQualificationControl([object]$Control) {
  Assert-ExactProperties $Control @('$schema', 'contract_version', 'release_id', 'runtime_candidate_sha', 'source_archive_sha256', 'production_rollout_claimed', 'percentage_credit_awarded', 'secret_output') 'Source qualification control'
  Assert-True ([string]$Control.'$schema' -ceq '../runtime-contracts/source-qualification-control.schema.json') 'Source qualification control schema mismatch.'
  Assert-True ([string]$Control.contract_version -ceq 'source-qualification-control-v1') 'Source qualification control contract mismatch.'
  Assert-True ([string]$Control.release_id -ceq $NewReleaseId) 'Source qualification control release mismatch.'
  Assert-True ([string]$Control.runtime_candidate_sha -ceq $NewSourceSha) 'Source qualification control source mismatch.'
  Assert-True ([string]$Control.source_archive_sha256 -match '^[0-9a-fA-F]{64}$') 'Source qualification control archive hash invalid.'
  Assert-True ([string]$Control.source_archive_sha256 -ieq $NewSourceArchiveSha256) 'Source qualification control archive mismatch.'
  Assert-True (($Control.percentage_credit_awarded -is [int] -or $Control.percentage_credit_awarded -is [long]) -and $Control.percentage_credit_awarded -eq 0) 'Source qualification control credit must be integer zero.'
  Assert-BooleanField $Control 'production_rollout_claimed' $false 'Source qualification control'
  Assert-BooleanField $Control 'secret_output' $false 'Source qualification control'
}

function Write-AtomicJson([string]$TargetPath, [object]$Value, [string]$ExpectedPreReplaceSha, [scriptblock]$ValidateWritten) {
  $temporaryPath = "$TargetPath.rearm-$([Guid]::NewGuid().ToString('N')).tmp"
  $rollbackPath = "$TargetPath.rearm-$([Guid]::NewGuid().ToString('N')).rollback"
  $replaced = $false
  $removeRollback = $false
  $attemptedSha = ''
  try {
    Assert-True ((Get-FileSha $TargetPath) -ceq $ExpectedPreReplaceSha) 'Capability state changed before atomic replace.'
    $json = ($Value | ConvertTo-Json -Depth 60) + "`n"
    $stream = [IO.File]::Open($temporaryPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
      $writer = [IO.StreamWriter]::new($stream, [Text.UTF8Encoding]::new($false))
      try { $writer.Write($json) } finally { $writer.Dispose() }
    } finally {
      if ($null -ne $stream) { $stream.Dispose() }
    }
    $null = Read-JsonFile $temporaryPath 'Temporary capability state'
    $attemptedSha = Get-FileSha $temporaryPath
    Assert-True ((Get-FileSha $TargetPath) -ceq $ExpectedPreReplaceSha) 'Capability state changed before atomic replace.'
    # Replace creates a byte-exact backup of the state present at the rename boundary.
    [IO.File]::Replace($temporaryPath, $TargetPath, $rollbackPath)
    $replaced = $true
    Assert-True ((Get-FileSha $rollbackPath) -ceq $ExpectedPreReplaceSha) 'Capability state changed at atomic replace.'
    Assert-True ((Get-FileSha $TargetPath) -ceq $attemptedSha) 'Capability state changed after atomic replace.'
    $written = Read-JsonFile $TargetPath 'Written capability state'
    & $ValidateWritten $written
    Assert-True ((Get-FileSha $TargetPath) -ceq $attemptedSha) 'Capability state changed during post-write validation.'
    $removeRollback = $true
  } catch {
    $failure = $_
    if ($replaced) {
      if ((Test-Path -LiteralPath $TargetPath -PathType Leaf) -and (Get-FileSha $TargetPath) -ceq $attemptedSha) {
        $rollbackSha = Get-FileSha $rollbackPath
        [IO.File]::Replace($rollbackPath, $TargetPath, [NullString]::Value)
        Assert-True ((Get-FileSha $TargetPath) -ceq $rollbackSha) 'Atomic rollback verification failed.'
      } else {
        # A non-cooperating writer owns the current bytes; keep its state and our backup.
        throw "Concurrent change preserved; original state retained at $rollbackPath. $($failure.Exception.Message)"
      }
    }
    throw $failure
  } finally {
    if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) { Remove-Item -LiteralPath $temporaryPath -Force }
    if ($removeRollback -and (Test-Path -LiteralPath $rollbackPath -PathType Leaf)) { Remove-Item -LiteralPath $rollbackPath -Force }
  }
}

Assert-True ($supportedGates.ContainsKey($GateId)) "Unsupported rearm gate: $GateId"
$grantSuffix = '::{0}::{1}::{2}' -f $GateId, $NewReleaseId, $NewSourceSha
Assert-True ($NewOwnerGrantRef.Length -le 600 -and $NewOwnerGrantRef -cmatch '^[A-Za-z0-9][A-Za-z0-9._:/#-]+$' -and $NewOwnerGrantRef.EndsWith($grantSuffix, [StringComparison]::Ordinal) -and $NewOwnerGrantRef.Length -gt $grantSuffix.Length) 'New owner grant reference must bind the selected gate, release and source.'
Assert-True ($OldReleaseId -cne $NewReleaseId) 'Old and new release ids must differ.'
Assert-True ($OldSourceSha -cne $NewSourceSha) 'Old and new source commits must differ.'

$spec = $supportedGates[$GateId]
$capability = Resolve-RepoFile $CapabilityStatePath 'Capability state'
$oldEvidence = Resolve-RepoFile $OldEvidencePath 'Old evidence'
$candidatePointer = Resolve-RepoFile $CandidatePointerPath 'New candidate pointer'
$sourceQualificationControl = Resolve-RepoFile $SourceQualificationControlPath 'Source qualification control'
& git -C $repoRoot ls-files --error-unmatch -- $capability.relative 2>$null | Out-Null
Assert-True ($LASTEXITCODE -eq 0) 'Capability state must be tracked.'
Assert-TrackedClean $oldEvidence 'Old evidence'
Assert-TrackedClean $candidatePointer 'New candidate pointer'
Assert-TrackedClean $sourceQualificationControl 'Source qualification control'

Assert-KnownCommit $OldSourceSha 'Old source'
Assert-KnownCommit $OldQualificationSha 'Old qualification'
Assert-KnownCommit $NewSourceSha 'New source'
Assert-KnownCommit $NewQualificationSha 'New qualification'
$headSha = (& git -C $repoRoot rev-parse HEAD).Trim()
Assert-True ($LASTEXITCODE -eq 0 -and $headSha -match '^[0-9a-f]{40}$') 'Unable to read HEAD.'
Assert-Ancestor $OldSourceSha $OldQualificationSha 'Old qualification does not descend from old source.'
Assert-Ancestor $OldQualificationSha $headSha 'HEAD does not descend from old qualification.'
Assert-Ancestor $OldSourceSha $NewSourceSha 'New source does not descend from old source.'
Assert-DirectChild $NewSourceSha $NewQualificationSha
Assert-True ($sourceQualificationControl.relative -ceq 'docs/runtime-state/source-qualification-control.json') 'Qualification control path must be canonical.'
$qualificationPaths = @(& git -C $repoRoot diff-tree --no-commit-id --name-only -r $NewQualificationSha)
Assert-True ($LASTEXITCODE -eq 0 -and $qualificationPaths.Count -eq 1 -and $qualificationPaths[0] -ceq $sourceQualificationControl.relative) 'New qualification must change only source-qualification-control.json.'
& git -C $repoRoot diff --quiet $NewQualificationSha HEAD -- $sourceQualificationControl.relative
Assert-True ($LASTEXITCODE -eq 0) 'Qualification control differs from the new qualification commit.'
Assert-Ancestor $NewQualificationSha $headSha 'HEAD does not descend from new qualification.'
Assert-Ancestor $NewSourceSha $NewQualificationSha 'New qualification does not descend from new source.'

$actualArchive = Get-GitArchiveSha256 $NewSourceSha
Assert-True ($actualArchive -ceq $NewSourceArchiveSha256.ToLowerInvariant()) 'New source archive hash does not match git archive.'

$oldEvidenceHash = Get-FileSha $oldEvidence.absolute
Assert-True ($oldEvidenceHash -ceq $OldEvidenceSha256.ToLowerInvariant()) 'Old evidence SHA-256 mismatch.'
$oldEvidenceJson = Read-JsonFile $oldEvidence.absolute 'Old evidence'
Assert-OldEvidence $oldEvidenceJson $GateId $spec

$pointerSha = Get-FileSha $candidatePointer.absolute
$pointer = Read-JsonFile $candidatePointer.absolute 'New candidate pointer'
Assert-CandidatePointer $pointer
$sourceControlSha = Get-FileSha $sourceQualificationControl.absolute
$sourceControl = Read-JsonFile $sourceQualificationControl.absolute 'Source qualification control'
Assert-SourceQualificationControl $sourceControl

$stateSha = Get-FileSha $capability.absolute
$state = Read-JsonFile $capability.absolute 'Capability state'
Assert-True ([string]$state.contract_version -ceq 'capability-gate-state-v1') 'Capability-state contract mismatch.'
Assert-True ([string]$state.status -ceq 'configured') 'Capability-state status mismatch.'
$gateProperty = $state.gates.PSObject.Properties[$GateId]
Assert-True ($null -ne $gateProperty) "Selected gate is missing: $GateId"
$gate = $gateProperty.Value
$gateProperties = @('owner_granted', 'owner_grant_ref', 'live_verified', 'evidence_artifact', 'evidence_sha256', 'verified_at_utc', 'provider', 'paid_provider', 'verifier', 'note')
Assert-ExactProperties $gate $gateProperties "$GateId gate"
Assert-True (-not ($gate.live_verified -is [bool] -and $gate.live_verified -eq $false)) "$GateId is already rearmed or has no verified proof to retire."
Assert-BooleanField $gate 'owner_granted' $true "$GateId gate"
Assert-True (-not [string]::IsNullOrWhiteSpace([string]$gate.owner_grant_ref)) "$GateId old grant reference is missing."
Assert-BooleanField $gate 'live_verified' $true "$GateId gate"
Assert-BooleanField $gate 'paid_provider' $false "$GateId gate"
Assert-True ([string]$gate.evidence_artifact -ceq $oldEvidence.relative) "$GateId old evidence path mismatch."
Assert-True ([string]$gate.evidence_sha256 -ceq $oldEvidenceHash) "$GateId old evidence hash mismatch."
Assert-True (Test-IsoOrDateTimeValue $gate.verified_at_utc) "$GateId old verification time missing."
Assert-True ([string]$gate.provider -ceq $spec.oldProvider) "$GateId old provider mismatch."
Assert-True ([string]$gate.verifier -ceq $spec.oldVerifier) "$GateId old verifier mismatch."

Assert-True ((Get-FileSha $capability.absolute) -ceq $stateSha) 'Capability state changed during validation.'
$relevantPrestate = [ordered]@{
  capability_state_sha256 = $stateSha
  old_evidence_sha256 = $oldEvidenceHash
  candidate_pointer_sha256 = $pointerSha
  source_qualification_control_sha256 = $sourceControlSha
}
$gateIdentity = Get-GateIdentity $GateId $gate
$gateIdentitySha = Get-TextSha $gateIdentity

if ($Rearm -or $ExpectedCapabilityStateSha256) {
  Assert-True ($ExpectedCapabilityStateSha256 -match '^[0-9a-fA-F]{64}$' -and $ExpectedCapabilityStateSha256.ToLowerInvariant() -ceq $stateSha) 'Current capability-state identity was not supplied or changed.'
}
if ($Rearm -or $ExpectedGateIdentitySha256) {
  Assert-True ($ExpectedGateIdentitySha256 -match '^[0-9a-fA-F]{64}$' -and $ExpectedGateIdentitySha256.ToLowerInvariant() -ceq $gateIdentitySha) 'Current selected gate identity was not supplied or changed.'
}

if (-not $Rearm) {
  Write-Host "[candidate-gate-rearm] status=rearm_ready gate=$GateId validation_mode=true capability_state_sha256=$stateSha gate_identity_sha256=$gateIdentitySha old_evidence_sha256=$oldEvidenceHash new_source_archive_sha256=$($NewSourceArchiveSha256.ToLowerInvariant()) live_verified_target=false credit_delta=0 secret_output=false"
  exit 0
}

$lockPath = "$($capability.absolute).rearm.lock"
$lockStream = [IO.FileStream]::new($lockPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None, 4096, [IO.FileOptions]::DeleteOnClose)
try {
  $currentHead = (& git -C $repoRoot rev-parse HEAD).Trim()
  Assert-True ($LASTEXITCODE -eq 0 -and $currentHead -ceq $headSha) 'HEAD changed after validation.'
  foreach ($binding in @($capability, $oldEvidence, $candidatePointer, $sourceQualificationControl)) {
    $null = Resolve-RepoFile $binding.relative 'Rechecked binding'
  }
  Assert-True ((Get-FileSha $capability.absolute) -ceq $stateSha) 'Capability state changed after lock acquisition.'
  Assert-True ((Get-FileSha $oldEvidence.absolute) -ceq [string]$relevantPrestate.old_evidence_sha256) 'Old evidence changed after validation.'
  Assert-True ((Get-FileSha $candidatePointer.absolute) -ceq [string]$relevantPrestate.candidate_pointer_sha256) 'New candidate pointer changed after validation.'
  Assert-True ((Get-FileSha $sourceQualificationControl.absolute) -ceq [string]$relevantPrestate.source_qualification_control_sha256) 'Source qualification control changed after validation.'
  $otherGateIdentities = [ordered]@{}
  foreach ($property in $state.gates.PSObject.Properties) {
    if ($property.Name -cne $GateId) {
      $otherGateIdentities[$property.Name] = $property.Value | ConvertTo-Json -Depth 40 -Compress
    }
  }
  $candidate = Convert-JsonText ($state | ConvertTo-Json -Depth 60)
  $candidateGate = $candidate.gates.PSObject.Properties[$GateId].Value
  $candidateGate.owner_granted = $true
  $candidateGate.owner_grant_ref = $NewOwnerGrantRef
  $candidateGate.live_verified = $false
  $candidateGate.evidence_artifact = ''
  $candidateGate.evidence_sha256 = ''
  $candidateGate.verified_at_utc = ''
  $candidateGate.provider = $spec.rearmedProvider
  $candidateGate.paid_provider = $false
  $candidateGate.verifier = ''
  $candidateGate.note = "Rearmed for $NewReleaseId source $NewSourceSha via direct qualification $NewQualificationSha; old $GateId evidence $oldEvidenceHash retained only as historical provenance; live_verified=false; credit_delta=0."

  foreach ($property in $candidate.gates.PSObject.Properties) {
    if ($property.Name -cne $GateId) {
      Assert-True (($property.Value | ConvertTo-Json -Depth 40 -Compress) -ceq [string]$otherGateIdentities[$property.Name]) "Unrelated capability gate changed: $($property.Name)"
    }
  }

  $validateWritten = {
    param($written)
    Assert-True (($written | ConvertTo-Json -Depth 60 -Compress) -ceq ($candidate | ConvertTo-Json -Depth 60 -Compress)) 'Written state differs from validated candidate.'
    $writtenGate = $written.gates.PSObject.Properties[$GateId].Value
    Assert-BooleanField $writtenGate 'owner_granted' $true "written $GateId gate"
    Assert-BooleanField $writtenGate 'live_verified' $false "written $GateId gate"
    Assert-BooleanField $writtenGate 'paid_provider' $false "written $GateId gate"
    Assert-True ([string]$writtenGate.owner_grant_ref -ceq $NewOwnerGrantRef) 'Written owner grant reference mismatch.'
    Assert-True ([string]$writtenGate.evidence_artifact -ceq '' -and [string]$writtenGate.evidence_sha256 -ceq '' -and [string]$writtenGate.verified_at_utc -ceq '' -and [string]$writtenGate.verifier -ceq '') 'Written rearmed gate retained verification fields.'
    Assert-True ([string]$writtenGate.provider -ceq $spec.rearmedProvider) 'Written rearmed provider mismatch.'
  }
  Write-AtomicJson $capability.absolute $candidate $stateSha $validateWritten
} finally {
  $lockStream.Dispose()
}

Write-Host "[candidate-gate-rearm] status=rearmed gate=$GateId validation_mode=false live_verified=false credit_delta=0 provider='$($spec.rearmedProvider)' old_evidence_sha256=$oldEvidenceHash secret_output=false"

#Requires -Version 7.0
<#
  Strictly verifies one immutable phase6-scale-evidence-v2 artifact offline.

  Default mode is read-only. Promotion requires -Promote plus the exact current
  capability-state and phase6 gate identity hashes. The Owner grant must already
  exist in canonical capability-gates.json before the live run; this verifier
  never creates, replaces, or derives that grant. No token or live HTTP is used.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$EvidencePath,
  [string]$CriterionPath,
  [string]$HostedStatePath,
  [string]$CapabilityStatePath,
  [switch]$Promote,
  [string]$ExpectedCapabilityStateSha256,
  [string]$ExpectedGateIdentitySha256,
  [switch]$AllowTestPaths
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\', '/')
$artifactRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot '.phase1-artifacts\phase6-scale')).TrimEnd('\', '/')
$testRoot = [IO.Path]::GetFullPath('D:\_sb_tmp').TrimEnd('\', '/')
$canonicalCriterion = [IO.Path]::GetFullPath((Join-Path $repoRoot 'docs\runtime-state\phase6-scale-criterion.json'))
$canonicalHostedState = [IO.Path]::GetFullPath((Join-Path $repoRoot 'docs\runtime-state\cloudflare-native-hosted-current.json'))
$canonicalCapabilityState = [IO.Path]::GetFullPath((Join-Path $repoRoot 'docs\runtime-state\capability-gates.json'))
$canonicalRuntimeVerifier = [IO.Path]::GetFullPath((Join-Path $repoRoot 'scripts\verify-phase6-scale-runtime.ps1'))
if (-not $CriterionPath) { $CriterionPath = $canonicalCriterion }
if (-not $HostedStatePath) { $HostedStatePath = $canonicalHostedState }
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
    Assert-True (Test-UnderRoot $resolved $testRoot) "$Label test path is outside D:\_sb_tmp."
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
    Assert-True (Test-UnderRoot $resolved $testRoot) "$Label test path is outside D:\_sb_tmp."
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

function Get-RepositoryHeadSha {
  $head = (& git.exe -C $repoRoot rev-parse HEAD 2>$null).Trim()
  Assert-True ($LASTEXITCODE -eq 0 -and $head -match '^[0-9a-f]{40}$') 'Repository HEAD identity is unavailable.'
  return $head
}

function Assert-RepositoryHeadBinding([string]$RecordedSha) {
  Assert-True ($RecordedSha -match '^[0-9a-f]{40}$') 'Repository HEAD binding is invalid.'
  $currentSha = Get-RepositoryHeadSha
  if ($RecordedSha -eq $currentSha) { return }
  Assert-True (-not $AllowTestPaths) 'Test evidence repository HEAD must equal the current HEAD.'
  & git.exe -C $repoRoot merge-base --is-ancestor $RecordedSha $currentSha
  Assert-True ($LASTEXITCODE -eq 0) 'Recorded repository HEAD is not an ancestor of current HEAD.'
}

function Assert-TrackedCleanAgainstHead([string]$RelativePath) {
  & git.exe -C $repoRoot ls-files --error-unmatch -- $RelativePath 2>$null | Out-Null
  Assert-True ($LASTEXITCODE -eq 0) "Canonical truth file is not tracked: $RelativePath"
  & git.exe -C $repoRoot diff --quiet HEAD -- $RelativePath
  Assert-True ($LASTEXITCODE -eq 0) "Canonical truth file is not clean against HEAD: $RelativePath"
}

function Get-GitArchiveSha256([string]$CommitSha) {
  Assert-True ($CommitSha -match '^[0-9a-f]{40}$') 'Git archive source commit is invalid.'
  $temporaryRoot = [IO.Path]::GetFullPath('D:\_sb_tmp')
  New-Item -ItemType Directory -Force -Path $temporaryRoot | Out-Null
  $temporaryPath = Join-Path $temporaryRoot "phase6-evidence-archive-$([Guid]::NewGuid().ToString('N')).tar"
  try {
    & git.exe -C $repoRoot archive --format=tar "--output=$temporaryPath" $CommitSha
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
$resolvedCapabilityState = Resolve-InputFile $CapabilityStatePath 'Capability state' $canonicalCapabilityState
if ($Promote) {
  Assert-True (-not $AllowTestPaths) 'Promotion is forbidden in test-path mode.'
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

$criterion = Read-JsonFile $resolvedCriterion 'Scale criterion'
$hostedState = Read-JsonFile $resolvedHostedState 'Hosted state'
$capabilityState = Read-JsonFile $resolvedCapabilityState 'Capability state'
$evidenceRaw = Get-Content -LiteralPath $resolvedEvidence -Raw
$evidence = Read-JsonFile $resolvedEvidence 'Scale evidence'

Assert-True ($evidenceRaw -notmatch '(?i)(?:sk-|ghp_|github_pat_|glpat-|cfat_|vck_|hf_)[A-Za-z0-9_-]{12,}') 'Evidence contains secret-shaped material.'
Assert-True ($evidenceRaw -notmatch '(?i)"(?:authorization|cookie|password|private_key|client_secret|token_value|auth_value|credential_value)"\s*:') 'Evidence contains a forbidden credential field.'

Assert-True ([string]$criterion.contract_version -eq 'phase6-scale-criterion-v2') 'Scale criterion contract mismatch.'
Assert-True ([bool]$criterion.declared_before_first_run) 'Scale criterion was not pre-declared.'
Assert-True ([bool]$criterion.declared_before_first_full_write_run) 'Scale criterion v2 was not declared before the first full write run.'
Assert-True ([bool]$criterion.envelope.zero_card) 'Scale criterion is not zero-card.'
Assert-True ([bool]$criterion.envelope.payment_forbidden) 'Scale criterion permits payment.'
Assert-True ([bool]$criterion.envelope.paid_fallback_forbidden) 'Scale criterion permits paid fallback.'
Assert-True ([string]$hostedState.contract_version -eq 'cloudflare-native-hosted-current-v1') 'Hosted state contract mismatch.'
Assert-True ([string]$hostedState.status -eq 'verified') 'Hosted state is not verified.'
Assert-True ([bool]$hostedState.hosted_proof -and -not [bool]$hostedState.dev_only) 'Hosted state is not a real hosted proof.'
Assert-True ([bool]$hostedState.zero_card_verified -and -not [bool]$hostedState.paid_provider) 'Hosted state is not zero-card.'
Assert-True ([string]$hostedState.source_commit_sha -match '^[0-9a-f]{40}$') 'Hosted source commit SHA is invalid.'
Assert-True ([string]$hostedState.source_archive_sha256 -match '^[0-9a-f]{64}$') 'Hosted source archive SHA-256 is invalid.'
Assert-True ([string]$criterion.target.base_url -eq [string]$hostedState.base_url) 'Criterion and hosted state origins differ.'
Assert-True ($criterion.write_tier.http_429_allowed -eq $false) 'Scale criterion permits throttled writes.'
Assert-True ([string]$criterion.write_tier.cleanup_semantics -eq 'soft_delete_then_active_row_absence_and_audit_readback') 'Scale criterion cleanup semantics mismatch.'
Assert-True ([string]$criterion.pass_criteria.http_429_scope -eq 'health_read_tiers_only') 'Scale criterion 429 scope mismatch.'
$deploymentEvidencePath = Resolve-BoundArtifact ([string]$hostedState.evidence_artifact) 'Hosted deployment evidence'
$deploymentEvidenceSha256 = Get-FileSha256 $deploymentEvidencePath
Assert-True ([string]$hostedState.evidence_sha256 -match '^[0-9a-fA-F]{64}$' -and $deploymentEvidenceSha256 -eq ([string]$hostedState.evidence_sha256).ToLowerInvariant()) 'Hosted deployment evidence file hash mismatch.'
$deploymentEvidence = Read-JsonFile $deploymentEvidencePath 'Hosted deployment evidence'
Assert-True ([string]$deploymentEvidence.contract_version -eq 'cloudflare-d1-stateful-runtime-hosted-proof-v2') 'Hosted deployment evidence is not the v2 immutable contract.'
Assert-True ([string]$deploymentEvidence.base_url -eq [string]$hostedState.base_url) 'Hosted deployment base URL mismatch.'
Assert-True ([string]$deploymentEvidence.source_commit_sha -eq [string]$hostedState.source_commit_sha) 'Hosted deployment source commit mismatch.'
Assert-True ([string]$deploymentEvidence.source_archive_sha256 -eq [string]$hostedState.source_archive_sha256) 'Hosted deployment source archive mismatch.'
Assert-True ($deploymentEvidence.source_binding_verified -eq $true -and $deploymentEvidence.hosted_write_read_delete_verified -eq $true) 'Hosted deployment evidence lacks source-bound write/read/delete proof.'
Assert-True ($deploymentEvidence.dev_only -eq $false -and $deploymentEvidence.secret_output -eq $false) 'Hosted deployment evidence is DEV-only or exposes secrets.'

$topProperties = @(
  'contract_version', 'generated_at_utc', 'run_id', 'result', 'criterion_binding', 'source_binding',
  'request_budget', 'read_tiers', 'health_validation', 'write_tier', 'cleanup', 'aggregate', 'auth',
  'gate_may_open', 'gate_promotion_performed', 'percentage_credit_awarded', 'non_claims'
)
Assert-ExactProperties $evidence $topProperties 'evidence'
Assert-True ([string]$evidence.contract_version -eq 'phase6-scale-evidence-v2') 'Evidence contract mismatch.'
Assert-True ([string]$evidence.result -eq 'verified') 'Evidence result is not verified.'
Assert-True ([string]$evidence.run_id -ceq $filenameRunId) 'Evidence run ID does not match its filename.'
$generatedAt = [DateTimeOffset]::MinValue
Assert-True ([string]$evidence.generated_at_utc -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{7}Z$') 'Evidence timestamp must use the UTC round-trip shape.'
Assert-True ([DateTimeOffset]::TryParse([string]$evidence.generated_at_utc, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$generatedAt)) 'Evidence timestamp is invalid.'
Assert-True ($generatedAt.ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ') -eq $filenameStamp) 'Evidence timestamp does not match its filename.'
$declaredAt = [DateTimeOffset]::Parse([string]$criterion.declared_at_utc, [Globalization.CultureInfo]::InvariantCulture)
Assert-True ($generatedAt -ge $declaredAt) 'Evidence predates the declared criterion.'

Assert-ExactProperties $evidence.criterion_binding @('contract_version', 'gate_id', 'file_sha256', 'declared_before_first_run', 'declared_before_first_full_write_run') 'criterion binding'
Assert-True ([string]$evidence.criterion_binding.contract_version -eq [string]$criterion.contract_version) 'Evidence criterion contract binding mismatch.'
Assert-True ([string]$evidence.criterion_binding.gate_id -eq 'phase6_scale_runtime') 'Evidence gate binding mismatch.'
Assert-True ([string]$evidence.criterion_binding.file_sha256 -eq (Get-FileSha256 $resolvedCriterion)) 'Evidence criterion file hash mismatch.'
Assert-Boolean $evidence.criterion_binding 'declared_before_first_run' $true 'criterion binding'
Assert-Boolean $evidence.criterion_binding 'declared_before_first_full_write_run' $true 'criterion binding'

$sourceProperties = @(
  'hosted_state_contract_version', 'hosted_state_file_sha256', 'base_url', 'source_commit_sha',
  'source_archive_sha256', 'deployment_evidence_artifact', 'deployment_evidence_sha256',
  'worker_version_id', 'deployment_id', 'verifier_script_sha256', 'repository_head_sha',
  'capability_state_sha256', 'gate_identity_sha256', 'owner_granted', 'owner_grant_ref',
  'health_json_source_binding_verified'
)
Assert-ExactProperties $evidence.source_binding $sourceProperties 'source binding'
Assert-True ([string]$evidence.source_binding.hosted_state_contract_version -eq [string]$hostedState.contract_version) 'Hosted state contract binding mismatch.'
Assert-True ([string]$evidence.source_binding.hosted_state_file_sha256 -eq (Get-FileSha256 $resolvedHostedState)) 'Hosted state file hash mismatch.'
Assert-True ([string]$evidence.source_binding.base_url -eq [string]$criterion.target.base_url) 'Evidence base URL mismatch.'
Assert-True ([string]$evidence.source_binding.source_commit_sha -eq [string]$hostedState.source_commit_sha) 'Evidence source commit mismatch.'
Assert-True ([string]$evidence.source_binding.source_archive_sha256 -eq [string]$hostedState.source_archive_sha256) 'Evidence source archive mismatch.'
Assert-True ([string]$evidence.source_binding.deployment_evidence_artifact -eq [string]$hostedState.evidence_artifact) 'Deployment evidence path binding mismatch.'
Assert-True ([string]$evidence.source_binding.deployment_evidence_sha256 -match '^[0-9a-fA-F]{64}$' -and [string]$evidence.source_binding.deployment_evidence_sha256 -ieq [string]$hostedState.evidence_sha256) 'Deployment evidence SHA-256 binding mismatch.'
Assert-True ([string]$evidence.source_binding.worker_version_id -match '^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$') 'Worker version ID binding is invalid.'
Assert-True ([string]$evidence.source_binding.deployment_id -match '^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$') 'Deployment ID binding is invalid.'
Assert-True ([string]$evidence.source_binding.worker_version_id -eq [string]$deploymentEvidence.worker_version_id) 'Worker version ID does not match deployment evidence.'
Assert-True ([string]$evidence.source_binding.deployment_id -eq [string]$deploymentEvidence.deployment_id) 'Deployment ID does not match deployment evidence.'
Assert-Boolean $evidence.source_binding 'owner_granted' $true 'source binding'
Assert-BoundedIdentifier ([string]$evidence.source_binding.owner_grant_ref) 256 'Evidence Owner grant reference'
Assert-Boolean $evidence.source_binding 'health_json_source_binding_verified' $true 'source binding'
Assert-True ([string]$evidence.source_binding.verifier_script_sha256 -match '^[0-9a-f]{64}$') 'Runtime verifier script SHA-256 binding is invalid.'
Assert-True ([string]$evidence.source_binding.verifier_script_sha256 -eq (Get-FileSha256 $canonicalRuntimeVerifier)) 'Runtime verifier script SHA-256 binding mismatch.'
Assert-RepositoryHeadBinding ([string]$evidence.source_binding.repository_head_sha)
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

$expectedTiers = @(@(1, 60), @(10, 240), @(50, 500))
$tiers = @($evidence.read_tiers)
Assert-True ($tiers.Count -eq 3) 'Read-tier count mismatch.'
$read429 = 0
$validHealth = 0
for ($index = 0; $index -lt $expectedTiers.Count; $index++) {
  $tier = $tiers[$index]
  $label = "read tier $index"
  Assert-ExactProperties $tier @('concurrency', 'requests', 'valid_health_200', 'invalid_health_200', 'throttled_429', 'server_5xx', 'transport_fail', 'other_status', 'p50_ms', 'p95_ms', 'p99_ms', 'edge_control_p95_ms', 'worker_share_p95_ms') $label
  Assert-Integer $tier 'concurrency' $expectedTiers[$index][0] $label
  Assert-Integer $tier 'requests' $expectedTiers[$index][1] $label
  Assert-Integer $tier 'invalid_health_200' 0 $label
  Assert-Integer $tier 'server_5xx' 0 $label
  Assert-Integer $tier 'transport_fail' 0 $label
  Assert-Integer $tier 'other_status' 0 $label
  $tierValid = [int]$tier.valid_health_200
  $tier429 = [int]$tier.throttled_429
  Assert-True ($tierValid -gt 0 -and ($tierValid + $tier429) -eq [int]$tier.requests) "$label response accounting mismatch."
  Assert-NumberAtMost $tier 'p95_ms' ([double]$criterion.pass_criteria.max_p95_ms) $label
  $validHealth += $tierValid
  $read429 += $tier429
}

Assert-ExactProperties $evidence.health_validation @('valid_json_count', 'invalid_json_or_contract_count', 'validation_failures') 'health validation'
Assert-Integer $evidence.health_validation 'valid_json_count' $validHealth 'health validation'
Assert-Integer $evidence.health_validation 'invalid_json_or_contract_count' 0 'health validation'
Assert-EmptyArray $evidence.health_validation.validation_failures 'health validation failures'

Assert-ExactProperties $evidence.write_tier @('concurrency', 'records_planned', 'valid_post_insert_readbacks', 'record_loss_count', 'duplicate_count', 'field_failure_count', 'hash_failure_count', 'audit_failure_count', 'throttled_429', 'server_5xx', 'transport_fail', 'p50_ms', 'p95_ms', 'p99_ms', 'records') 'write tier'
Assert-Integer $evidence.write_tier 'concurrency' 10 'write tier'
Assert-Integer $evidence.write_tier 'records_planned' 50 'write tier'
Assert-Integer $evidence.write_tier 'valid_post_insert_readbacks' 50 'write tier'
foreach ($field in @('record_loss_count', 'duplicate_count', 'field_failure_count', 'hash_failure_count', 'audit_failure_count', 'throttled_429', 'server_5xx', 'transport_fail')) {
  Assert-Integer $evidence.write_tier $field 0 'write tier'
}
Assert-NumberAtMost $evidence.write_tier 'p95_ms' ([double]$criterion.pass_criteria.max_p95_ms) 'write tier'
$writeRecords = @($evidence.write_tier.records)
Assert-True ($writeRecords.Count -eq 50) 'Write record evidence count mismatch.'
$writeIds = @()
$requestIds = @()
$auditEventIds = @()
foreach ($record in $writeRecords) {
  Assert-ExactProperties $record @('id', 'response_id', 'request_id', 'audit_event_id', 'status_code', 'latency_ms', 'response_readback_verified', 'audit_readback_verified', 'prompt_sha256', 'html_sha256', 'audit_persisted_verified', 'validation_errors') 'write record'
  Assert-True ([string]$record.id -match '^p6s[0-9a-f]{24}[0-9]{2}$') 'Write record ID shape mismatch.'
  Assert-True ([string]$record.response_id -ceq [string]$record.id) 'Write response ID mismatch.'
  Assert-BoundedIdentifier ([string]$record.request_id) 128 'Write request ID'
  Assert-True ([string]$record.audit_event_id -match '^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$') 'Write audit event ID is invalid.'
  Assert-Integer $record 'status_code' 201 'write record'
  Assert-Boolean $record 'response_readback_verified' $true 'write record'
  Assert-Boolean $record 'audit_readback_verified' $true 'write record'
  Assert-Boolean $record 'audit_persisted_verified' $true 'write record'
  Assert-True ([string]$record.prompt_sha256 -match '^[0-9a-f]{64}$') 'Prompt SHA-256 is invalid.'
  Assert-True ([string]$record.html_sha256 -match '^[0-9a-f]{64}$') 'HTML SHA-256 is invalid.'
  Assert-EmptyArray $record.validation_errors 'write record validation errors'
  $writeIds += [string]$record.id
  $requestIds += [string]$record.request_id
  $auditEventIds += [string]$record.audit_event_id
}
Assert-True (@($writeIds | Select-Object -Unique).Count -eq 50) 'Write evidence contains duplicate IDs.'
Assert-True (@($requestIds | Select-Object -Unique).Count -eq 50) 'Write evidence contains duplicate request IDs.'
Assert-True (@($auditEventIds | Select-Object -Unique).Count -eq 50) 'Write evidence contains duplicate audit event IDs.'

Assert-ExactProperties $evidence.cleanup @('verified_count', 'required_count', 'complete', 'throttled_429', 'unclean_throttle_count', 'server_5xx', 'transport_fail', 'p95_ms', 'records') 'cleanup'
Assert-Integer $evidence.cleanup 'verified_count' 50 'cleanup'
Assert-Integer $evidence.cleanup 'required_count' 50 'cleanup'
Assert-Boolean $evidence.cleanup 'complete' $true 'cleanup'
foreach ($field in @('throttled_429', 'unclean_throttle_count', 'server_5xx', 'transport_fail')) {
  Assert-Integer $evidence.cleanup $field 0 'cleanup'
}
Assert-NumberAtMost $evidence.cleanup 'p95_ms' ([double]$criterion.pass_criteria.max_p95_ms) 'cleanup'
$cleanupRecords = @($evidence.cleanup.records)
Assert-True ($cleanupRecords.Count -eq 50) 'Cleanup record evidence count mismatch.'
foreach ($record in $cleanupRecords) {
  Assert-ExactProperties $record @('id', 'request_id', 'audit_event_id', 'status_code', 'latency_ms', 'expected_deleted_record', 'cleanup_verified', 'audit_persisted_verified', 'audit_readback_verified', 'delete_readback_verified', 'validation_errors') 'cleanup record'
  Assert-True ($writeIds -ccontains [string]$record.id) 'Cleanup ID was not present in the write evidence.'
  Assert-BoundedIdentifier ([string]$record.request_id) 128 'Cleanup request ID'
  Assert-True ([string]$record.audit_event_id -match '^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$') 'Cleanup audit event ID is invalid.'
  Assert-Integer $record 'status_code' 200 'cleanup record'
  Assert-Boolean $record 'expected_deleted_record' $true 'cleanup record'
  Assert-Boolean $record 'cleanup_verified' $true 'cleanup record'
  Assert-Boolean $record 'audit_persisted_verified' $true 'cleanup record'
  Assert-Boolean $record 'audit_readback_verified' $true 'cleanup record'
  Assert-Boolean $record 'delete_readback_verified' $true 'cleanup record'
  Assert-EmptyArray $record.validation_errors 'cleanup validation errors'
  $requestIds += [string]$record.request_id
  $auditEventIds += [string]$record.audit_event_id
}
Assert-True (@($cleanupRecords.id | Select-Object -Unique).Count -eq 50) 'Cleanup evidence contains duplicate IDs.'
Assert-True (@($requestIds | Select-Object -Unique).Count -eq 100) 'Scale evidence contains duplicate request IDs.'
Assert-True (@($auditEventIds | Select-Object -Unique).Count -eq 100) 'Scale evidence contains duplicate audit event IDs.'

Assert-ExactProperties $evidence.aggregate @('success_ratio', 'worst_p95_ms', 'throttled_429_total', 'server_5xx_total', 'transport_fail_total', 'failures', 'criterion_met') 'aggregate'
Assert-True ([double]$evidence.aggregate.success_ratio -eq 1.0) 'Aggregate success ratio is not exactly 1.0.'
Assert-True ([double]$evidence.aggregate.success_ratio -ge [double]$criterion.pass_criteria.min_success_ratio) 'Aggregate success ratio is below threshold.'
Assert-NumberAtMost $evidence.aggregate 'worst_p95_ms' ([double]$criterion.pass_criteria.max_p95_ms) 'aggregate'
$recomputedWorstP95 = [Math]::Max([double](($tiers | Measure-Object -Property p95_ms -Maximum).Maximum), [Math]::Max([double]$evidence.write_tier.p95_ms, [double]$evidence.cleanup.p95_ms))
Assert-True ([Math]::Abs([double]$evidence.aggregate.worst_p95_ms - $recomputedWorstP95) -le 0.1) 'Aggregate worst p95 does not match tier evidence.'
Assert-Integer $evidence.aggregate 'throttled_429_total' $read429 'aggregate'
Assert-Integer $evidence.aggregate 'server_5xx_total' 0 'aggregate'
Assert-Integer $evidence.aggregate 'transport_fail_total' 0 'aggregate'
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
  'The authorization token is neither printed nor persisted.',
  'Control requests use the Cloudflare edge path and are not Worker requests.'
)
Assert-ExactStringArray $evidence.non_claims $expectedNonClaims 'evidence non-claims'

Assert-True ([string]$capabilityState.contract_version -eq 'capability-gate-state-v1') 'Capability-state contract mismatch.'
Assert-True ([string]$capabilityState.status -eq 'configured') 'Capability-state status mismatch.'
$gate = $capabilityState.gates.phase6_scale_runtime
$gateProperties = @('owner_granted', 'owner_grant_ref', 'live_verified', 'evidence_artifact', 'verified_at_utc', 'provider', 'paid_provider', 'verifier', 'note')
$gateAllowsEvidenceSha256 = $null -ne $gate.PSObject.Properties['evidence_sha256']
if ($gateAllowsEvidenceSha256) { $gateProperties += 'evidence_sha256' }
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
if ($gateAllowsEvidenceSha256) {
  Assert-True ([string]$gate.evidence_sha256 -eq '') 'Phase6 evidence SHA-256 must be empty before first promotion.'
}
Assert-True ($ExpectedCapabilityStateSha256 -match '^[0-9a-fA-F]{64}$' -and $ExpectedCapabilityStateSha256.ToLowerInvariant() -eq $capabilityStateSha256) 'Current capability-state identity was not supplied or changed.'
Assert-True ($ExpectedGateIdentitySha256 -match '^[0-9a-fA-F]{64}$' -and $ExpectedGateIdentitySha256.ToLowerInvariant() -eq $gateIdentitySha256) 'Current phase6 gate identity was not supplied or changed.'
Assert-True ((Get-FileSha256 $resolvedCapabilityState) -eq $capabilityStateSha256) 'Capability state changed during verification.'
$relativeEvidence = [IO.Path]::GetRelativePath($repoRoot, $resolvedEvidence).Replace('\', '/')
$relativeCompanion = [IO.Path]::GetRelativePath($repoRoot, $companionPath).Replace('\', '/')
$relativeDeploymentEvidence = [IO.Path]::GetRelativePath($repoRoot, $deploymentEvidencePath).Replace('\', '/')
foreach ($truthPath in @(
  'docs/runtime-state/phase6-scale-criterion.json',
  'docs/runtime-state/cloudflare-native-hosted-current.json',
  'docs/runtime-state/capability-gates.json',
  'scripts/verify-phase6-scale-runtime.ps1',
  'scripts/verify-phase6-scale-evidence.ps1',
  $relativeDeploymentEvidence,
  $relativeEvidence,
  $relativeCompanion
)) {
  Assert-TrackedCleanAgainstHead $truthPath
}
$recordedRepositoryHead = [string]$evidence.source_binding.repository_head_sha
foreach ($boundPath in @(
  'docs/runtime-state/phase6-scale-criterion.json',
  'docs/runtime-state/cloudflare-native-hosted-current.json',
  'docs/runtime-state/capability-gates.json',
  'scripts/verify-phase6-scale-runtime.ps1',
  $relativeDeploymentEvidence
)) {
  & git.exe -C $repoRoot diff --quiet "$recordedRepositoryHead..HEAD" -- $boundPath
  Assert-True ($LASTEXITCODE -eq 0) "Source-bound file changed after the recorded live-run HEAD: $boundPath"
}
Assert-True ((Get-FileSha256 $deploymentEvidencePath) -eq $deploymentEvidenceSha256) 'Deployment evidence changed during verification.'
Assert-True ((Get-GitArchiveSha256 ([string]$hostedState.source_commit_sha)) -eq [string]$hostedState.source_archive_sha256) 'Hosted source archive does not match its Git commit.'

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
if ($gateAllowsEvidenceSha256) { $candidateGate.evidence_sha256 = $evidenceSha256 }
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
  Assert-True ([string]$writtenCandidate.gates.phase6_scale_runtime.evidence_artifact -eq $relativeEvidence) 'Candidate evidence path mismatch.'
  if ($gateAllowsEvidenceSha256) {
    Assert-True ([string]$writtenCandidate.gates.phase6_scale_runtime.evidence_sha256 -eq $evidenceSha256) 'Candidate evidence SHA-256 mismatch.'
  }
  Assert-True ((Get-FileSha256 $resolvedCapabilityState) -eq $capabilityStateSha256) 'Capability state changed before atomic replace.'
  [IO.File]::Replace($temporaryPath, $resolvedCapabilityState, $backupPath, $true)
} finally {
  if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
    Remove-Item -LiteralPath $temporaryPath -Force
  }
}

$promoted = Read-JsonFile $resolvedCapabilityState 'Promoted capability state'
Assert-Boolean $promoted.gates.phase6_scale_runtime 'owner_granted' $true 'promoted phase6 gate'
Assert-Boolean $promoted.gates.phase6_scale_runtime 'live_verified' $true 'promoted phase6 gate'
Assert-Boolean $promoted.gates.phase6_scale_runtime 'paid_provider' $false 'promoted phase6 gate'
Assert-True ([string]$promoted.gates.phase6_scale_runtime.owner_grant_ref -ceq $ownerGrantRef) 'Promoted Owner grant reference mismatch.'
Assert-True ([string]$promoted.gates.phase6_scale_runtime.evidence_artifact -eq $relativeEvidence) 'Promoted evidence path mismatch.'
Assert-True ([string]$promoted.gates.phase6_scale_runtime.provider -eq 'cloudflare-workers-d1-zero-card') 'Promoted provider mismatch.'
Assert-True ([string]$promoted.gates.phase6_scale_runtime.verifier -eq 'scripts/verify-phase6-scale-evidence.ps1') 'Promoted verifier mismatch.'
Assert-True ([string]$promoted.gates.phase6_scale_runtime.note -eq "Verified from phase6-scale-evidence-v2; evidence_sha256=$evidenceSha256") 'Promoted evidence note mismatch.'
if ($gateAllowsEvidenceSha256) {
  Assert-True ([string]$promoted.gates.phase6_scale_runtime.evidence_sha256 -eq $evidenceSha256) 'Promoted evidence SHA-256 mismatch.'
}
Write-Host "[phase6-scale-evidence] promoted=true rollback_artifact=$backupPath secret_output=false"
exit 0

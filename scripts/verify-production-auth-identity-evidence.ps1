[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$EvidencePath,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[0-9a-f]{40}$')]
  [string]$ExpectedCandidateSha,

  [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $ValidateOnly) {
  throw "Production auth evidence verification is non-mutating and requires -ValidateOnly."
}

$repoRoot = Split-Path -Parent $PSScriptRoot

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Resolve-RepoScopedFile([string]$RelativePath) {
  if ([string]::IsNullOrWhiteSpace($RelativePath) -or [IO.Path]::IsPathRooted($RelativePath)) {
    return $null
  }
  try {
    $normalized = $RelativePath.Replace('\', '/')
    if ($normalized.Split('/') -contains '..') { return $null }
    $repoPrefix = [IO.Path]::GetFullPath($repoRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $resolved = [IO.Path]::GetFullPath((Join-Path $repoRoot $normalized))
    if (-not $resolved.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)) { return $null }
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { return $null }
    return [pscustomobject]@{ relative = $normalized; absolute = $resolved }
  } catch {
    return $null
  }
}

function Assert-JsonBool([object]$Object, [string]$Name, [bool]$Expected) {
  $property = $Object.PSObject.Properties[$Name]
  Assert-True ($null -ne $property) "Evidence is missing boolean field '$Name'."
  Assert-True ($property.Value -is [bool]) "Evidence field '$Name' must be a JSON boolean."
  Assert-True ($property.Value -eq $Expected) "Evidence field '$Name' must be $($Expected.ToString().ToLowerInvariant())."
}

function Assert-NonEmptyString([object]$Object, [string]$Name) {
  $property = $Object.PSObject.Properties[$Name]
  Assert-True ($null -ne $property) "Evidence is missing string field '$Name'."
  Assert-True ($property.Value -is [string] -and -not [string]::IsNullOrWhiteSpace($property.Value)) `
    "Evidence field '$Name' must be a non-empty string."
}

function Assert-ExactPropertyNames([object]$Object, [string[]]$Expected, [string]$Label) {
  $actual = @($Object.PSObject.Properties.Name)
  Assert-True ($actual.Count -eq $Expected.Count) `
    "$Label must contain exactly $($Expected.Count) properties."
  foreach ($name in $Expected) {
    Assert-True ($actual -ccontains $name) "$Label is missing exact property '$name'."
  }
  foreach ($name in $actual) {
    Assert-True ($Expected -ccontains $name) "$Label contains unknown property '$name'."
  }
}

function Assert-NonLocalHttpsOrigin([string]$Value, [string]$Label) {
  $uri = $null
  Assert-True ([Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri)) "$Label must be an absolute URI."
  Assert-True ($uri.Scheme -eq 'https') "$Label must use HTTPS."
  Assert-True ($uri.IsDefaultPort) "$Label must use the default HTTPS port."
  Assert-True ([string]::IsNullOrEmpty($uri.UserInfo)) "$Label must not contain user information."
  Assert-True ([string]::IsNullOrEmpty($uri.Query) -and [string]::IsNullOrEmpty($uri.Fragment)) `
    "$Label must not contain a query or fragment."
  Assert-True ($uri.AbsolutePath -eq '/') "$Label must be an origin without a path."
  $hostName = $uri.DnsSafeHost.ToLowerInvariant()
  $isLocal = $uri.IsLoopback -or $hostName -eq 'localhost' -or $hostName.EndsWith('.localhost')
  Assert-True (-not $isLocal) "$Label must be non-local."
  return $uri.GetLeftPart([UriPartial]::Authority)
}

function Find-ForbiddenSecretProperties([object]$Value, [string]$Path = 'evidence') {
  $found = New-Object System.Collections.Generic.List[string]
  if ($null -eq $Value -or $Value -is [string] -or $Value -is [ValueType]) { return $found }
  if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [pscustomobject]) {
    $index = 0
    foreach ($item in $Value) {
      foreach ($entry in @(Find-ForbiddenSecretProperties $item "$Path[$index]")) { $found.Add($entry) }
      $index++
    }
    return $found
  }
  $forbidden = @(
    'access_token', 'refresh_token', 'client_secret', 'authorization_code',
    'oauth_state_value', 'cookie_value', 'raw_cookie', 'secret_value',
    'token', 'secret', 'password', 'authorization', 'cookie', 'code', 'oauth_state'
  )
  $allowedSecurityMetadata = @('secret_output', 'secret_scan_verified')
  foreach ($property in $Value.PSObject.Properties) {
    $propertyName = $property.Name.ToLowerInvariant()
    $sensitiveSegment = $propertyName -match '(^|_)(token|secret|password|authorization|cookie|code|oauth_state)(_|$)'
    $booleanVerificationMetadata = $property.Value -is [bool] -and $propertyName.EndsWith('_verified')
    if (
      ($forbidden -contains $propertyName) -or
      ($sensitiveSegment -and -not ($allowedSecurityMetadata -contains $propertyName) -and -not $booleanVerificationMetadata)
    ) {
      $found.Add("$Path.$($property.Name)")
    }
    foreach ($entry in @(Find-ForbiddenSecretProperties $property.Value "$Path.$($property.Name)")) {
      $found.Add($entry)
    }
  }
  return $found
}

$resolvedEvidence = Resolve-RepoScopedFile $EvidencePath
Assert-True ($null -ne $resolvedEvidence) "EvidencePath must resolve to an existing repo-scoped file."

& git -C $repoRoot cat-file -e "$ExpectedCandidateSha^{commit}" 2>$null
Assert-True ($LASTEXITCODE -eq 0) "Expected candidate SHA must resolve to a local commit."
& git -C $repoRoot merge-base --is-ancestor $ExpectedCandidateSha HEAD
Assert-True ($LASTEXITCODE -eq 0) "Expected candidate SHA must be an ancestor of HEAD."

& git -C $repoRoot ls-files --error-unmatch -- $resolvedEvidence.relative 2>$null | Out-Null
Assert-True ($LASTEXITCODE -eq 0) "Evidence must be tracked by Git."
& git -C $repoRoot diff --quiet HEAD -- $resolvedEvidence.relative
Assert-True ($LASTEXITCODE -eq 0) "Evidence must be clean relative to HEAD."

try {
  $evidence = Get-Content -LiteralPath $resolvedEvidence.absolute -Raw | ConvertFrom-Json
} catch {
  throw "Evidence must be valid JSON."
}

$requiredTrueFields = @(
  'hosted_https',
  'real_browser',
  'oauth_start_verified',
  'oauth_scope_exact_read_user_verified',
  'oauth_state_one_time_verified',
  'callback_verified',
  'callback_replay_rejected_verified',
  'session_readback_verified',
  'refresh_verified',
  'refresh_family_replay_rejected_verified',
  'logout_verified',
  'audit_readback_verified',
  'audit_before_credential_verified',
  'refresh_revoked_verified',
  'cookies_cleared_verified',
  'rollback_verified',
  'unauthenticated_me_401_verified',
  'cookie_policy_verified',
  'owner_numeric_id_allowlist_verified',
  'source_parity_verified',
  'request_session_audit_correlation_verified',
  'redaction_verified',
  'branch_protection_verified',
  'secret_scan_verified',
  'live_github_oauth_call'
)
$requiredFalseFields = @(
  'dev_only',
  'secret_output',
  'gate_promotion_performed',
  'verifier_mutations_performed'
)
$expectedTopLevelProperties = @(
  'contract_version',
  'status',
  'oauth_scope',
  'human_flow_verified_steps',
  'source_binding'
) + $requiredTrueFields + $requiredFalseFields
Assert-ExactPropertyNames $evidence $expectedTopLevelProperties 'Production auth evidence'

Assert-True ([string]$evidence.contract_version -ceq 'production-auth-identity-proof-v1') `
  "Evidence contract must be production-auth-identity-proof-v1."
Assert-True ([string]$evidence.status -ceq 'verified') "Evidence status must be verified."

foreach ($field in $requiredTrueFields) {
  Assert-JsonBool $evidence $field $true
}

foreach ($field in $requiredFalseFields) {
  Assert-JsonBool $evidence $field $false
}

Assert-NonEmptyString $evidence 'oauth_scope'
Assert-True ([string]$evidence.oauth_scope -ceq 'read:user') "Evidence oauth_scope must be exactly read:user."

$sourceBindingProperty = $evidence.PSObject.Properties['source_binding']
Assert-True ($null -ne $sourceBindingProperty) "Evidence must contain source_binding."
$sourceBinding = $sourceBindingProperty.Value
Assert-True ($null -ne $sourceBinding) "Evidence source_binding must be an object."
Assert-ExactPropertyNames $sourceBinding @(
  'source_commit_sha',
  'frontend_source_commit_sha',
  'auth_runtime_source_commit_sha',
  'deployment_id',
  'frontend_deployment_id',
  'auth_runtime_deployment_id',
  'immutable_frontend_deployment_verified',
  'immutable_auth_runtime_deployment_verified',
  'frontend_origin_evidence_ref',
  'frontend_origin_evidence_sha256',
  'owner_architecture_decision_ref',
  'owner_architecture_decision_sha256',
  'auth_runtime_evidence_ref',
  'auth_runtime_evidence_sha256',
  'callback_origin',
  'callback_url'
) 'Production auth source_binding'
foreach ($field in @(
  'source_commit_sha',
  'frontend_source_commit_sha',
  'auth_runtime_source_commit_sha'
)) {
  Assert-NonEmptyString $sourceBinding $field
  Assert-True ([string]$sourceBinding.$field -ceq $ExpectedCandidateSha) `
    "source_binding.$field must equal the expected candidate SHA."
}
foreach ($field in @('deployment_id', 'frontend_deployment_id', 'auth_runtime_deployment_id')) {
  Assert-NonEmptyString $sourceBinding $field
}
Assert-True ([string]$sourceBinding.deployment_id -ceq [string]$sourceBinding.auth_runtime_deployment_id) `
  "source_binding.deployment_id must equal auth_runtime_deployment_id."
Assert-JsonBool $sourceBinding 'immutable_frontend_deployment_verified' $true
Assert-JsonBool $sourceBinding 'immutable_auth_runtime_deployment_verified' $true
Assert-NonEmptyString $sourceBinding 'frontend_origin_evidence_ref'
Assert-NonEmptyString $sourceBinding 'frontend_origin_evidence_sha256'
Assert-NonEmptyString $sourceBinding 'owner_architecture_decision_ref'
Assert-NonEmptyString $sourceBinding 'owner_architecture_decision_sha256'
Assert-NonEmptyString $sourceBinding 'auth_runtime_evidence_ref'
Assert-NonEmptyString $sourceBinding 'auth_runtime_evidence_sha256'
Assert-NonEmptyString $sourceBinding 'callback_origin'
Assert-NonEmptyString $sourceBinding 'callback_url'
$callbackOrigin = Assert-NonLocalHttpsOrigin ([string]$sourceBinding.callback_origin) 'source_binding.callback_origin'
$expectedCallbackUrl = $callbackOrigin.TrimEnd('/') + '/api/v1/auth/callback'
Assert-True ([string]$sourceBinding.callback_url -ceq $expectedCallbackUrl) `
  "source_binding.callback_url must be the exact callback endpoint on callback_origin."

$frontendOriginEvidenceRef = [string]$sourceBinding.frontend_origin_evidence_ref
Assert-True ($frontendOriginEvidenceRef -ceq 'docs/runtime-state/frontend-hosted-current.json') `
  "source_binding.frontend_origin_evidence_ref must use the canonical hosted frontend state path."
$resolvedFrontendOriginEvidence = Resolve-RepoScopedFile $frontendOriginEvidenceRef
Assert-True ($null -ne $resolvedFrontendOriginEvidence) `
  "source_binding.frontend_origin_evidence_ref must resolve to an existing repo-scoped file."
& git -C $repoRoot ls-files --error-unmatch -- $resolvedFrontendOriginEvidence.relative 2>$null | Out-Null
Assert-True ($LASTEXITCODE -eq 0) "Frontend-origin evidence must be tracked by Git."
& git -C $repoRoot diff --quiet HEAD -- $resolvedFrontendOriginEvidence.relative
Assert-True ($LASTEXITCODE -eq 0) "Frontend-origin evidence must be clean relative to HEAD."

$expectedFrontendOriginEvidenceSha = [string]$sourceBinding.frontend_origin_evidence_sha256
Assert-True ($expectedFrontendOriginEvidenceSha -cmatch '^[0-9a-f]{64}$') `
  "source_binding.frontend_origin_evidence_sha256 must be a lowercase SHA-256."
$actualFrontendOriginEvidenceSha = (Get-FileHash -LiteralPath $resolvedFrontendOriginEvidence.absolute -Algorithm SHA256).Hash.ToLowerInvariant()
Assert-True ($actualFrontendOriginEvidenceSha -ceq $expectedFrontendOriginEvidenceSha) `
  "Frontend-origin evidence SHA-256 must match source_binding.frontend_origin_evidence_sha256."

try {
  $frontendOriginEvidence = Get-Content -LiteralPath $resolvedFrontendOriginEvidence.absolute -Raw | ConvertFrom-Json
} catch {
  throw "Frontend-origin evidence must be valid JSON."
}

Assert-ExactPropertyNames $frontendOriginEvidence @(
  'contract_version',
  'status',
  'source_commit_sha',
  'source_archive_sha256',
  'deployment_id',
  'immutable_deployment_url',
  'production_alias',
  'vercel_target',
  'vercel_scope',
  'vercel_project_id',
  'vercel_project_name',
  'git_source_type',
  'git_source_repo_id',
  'git_source_ref',
  'proof_artifact',
  'proof_generated_at',
  'browser_channel',
  'browser_version',
  'page_count',
  'viewport_count',
  'click_navigation_count',
  'overflow_failures',
  'overlay_collision_failures',
  'console_errors',
  'read_endpoint_count',
  'former_500_endpoint_count',
  'frontend_progress_before',
  'frontend_progress_after',
  'deployment_metadata_verified',
  'deployment_alias_content_parity',
  'production_operational_deploy_verified',
  'production_release_claimed',
  'non_claims'
) 'Frontend-origin evidence'
$forbiddenFrontendSecretProperties = @(Find-ForbiddenSecretProperties $frontendOriginEvidence 'frontend_origin_evidence')
Assert-True ($forbiddenFrontendSecretProperties.Count -eq 0) `
  "Frontend-origin evidence contains forbidden raw secret properties."

Assert-True ([string]$frontendOriginEvidence.contract_version -ceq 'frontend-hosted-current-proof-v1') `
  "Frontend-origin evidence contract must be frontend-hosted-current-proof-v1."
Assert-True ([string]$frontendOriginEvidence.status -ceq 'verified') `
  "Frontend-origin evidence status must be verified."
foreach ($field in @(
  'source_commit_sha',
  'deployment_id',
  'immutable_deployment_url',
  'production_alias',
  'vercel_target',
  'vercel_scope',
  'vercel_project_id',
  'vercel_project_name'
)) {
  Assert-NonEmptyString $frontendOriginEvidence $field
}
Assert-True ([string]$frontendOriginEvidence.source_commit_sha -ceq $ExpectedCandidateSha) `
  "Frontend-origin evidence source_commit_sha must equal the expected candidate SHA."
Assert-True ([string]$frontendOriginEvidence.deployment_id -ceq [string]$sourceBinding.frontend_deployment_id) `
  "Frontend-origin evidence deployment_id must equal source_binding.frontend_deployment_id."
Assert-True ([string]$frontendOriginEvidence.vercel_target -ceq 'production') `
  "Frontend-origin evidence vercel_target must be production."
Assert-True ([string]$frontendOriginEvidence.vercel_scope -ceq 'strazzusochrs-projects') `
  "Frontend-origin evidence must bind the canonical Vercel scope."
Assert-True ([string]$frontendOriginEvidence.vercel_project_id -ceq 'prj_ZbSNRVz5ijLQ4tQR61liHFw1x5eY') `
  "Frontend-origin evidence must bind the canonical frontend Vercel project id."
Assert-True ([string]$frontendOriginEvidence.vercel_project_name -ceq 'frontend') `
  "Frontend-origin evidence must bind the canonical frontend Vercel project."
Assert-JsonBool $frontendOriginEvidence 'deployment_metadata_verified' $true
Assert-JsonBool $frontendOriginEvidence 'deployment_alias_content_parity' $true
Assert-JsonBool $frontendOriginEvidence 'production_operational_deploy_verified' $true
Assert-JsonBool $frontendOriginEvidence 'production_release_claimed' $false

$frontendOriginVerifierRef = 'scripts/verify-frontend-hosted-current.ps1'
$resolvedFrontendOriginVerifier = Resolve-RepoScopedFile $frontendOriginVerifierRef
Assert-True ($null -ne $resolvedFrontendOriginVerifier) `
  "Canonical hosted frontend verifier is unavailable."
& git -C $repoRoot ls-files --error-unmatch -- $resolvedFrontendOriginVerifier.relative 2>$null | Out-Null
Assert-True ($LASTEXITCODE -eq 0) "Canonical hosted frontend verifier must be tracked by Git."
& git -C $repoRoot diff --quiet HEAD -- $resolvedFrontendOriginVerifier.relative
Assert-True ($LASTEXITCODE -eq 0) "Canonical hosted frontend verifier must be clean relative to HEAD."
$powerShellExecutable = (Get-Process -Id $PID).Path
$frontendOriginVerifierOutput = @(
  & $powerShellExecutable -NoProfile -ExecutionPolicy Bypass `
    -File $resolvedFrontendOriginVerifier.absolute `
    -ConfigPath $frontendOriginEvidenceRef `
    -ValidateOnly 2>&1
)
Assert-True ($LASTEXITCODE -eq 0) `
  "Canonical hosted frontend dynamic validation failed."
$frontendOriginVerifierText = ($frontendOriginVerifierOutput | ForEach-Object { [string]$_ }) -join "`n"
foreach ($marker in @(
  '[frontend-hosted-current] status=verified',
  'full_validation=true',
  'validation_mode=true',
  'browser_skipped=true',
  'verification_written=false'
)) {
  Assert-True ($frontendOriginVerifierText.Contains($marker)) `
    "Canonical hosted frontend dynamic validation is missing marker: $marker"
}

$immutableFrontendOrigin = Assert-NonLocalHttpsOrigin `
  ([string]$frontendOriginEvidence.immutable_deployment_url) `
  'frontend-origin evidence immutable_deployment_url'
$immutableFrontendUri = [Uri]$immutableFrontendOrigin
Assert-True ($immutableFrontendUri.DnsSafeHost.ToLowerInvariant().EndsWith('.vercel.app')) `
  "Frontend-origin evidence immutable_deployment_url must be a Vercel deployment origin."
$canonicalFrontendOrigin = Assert-NonLocalHttpsOrigin `
  ([string]$frontendOriginEvidence.production_alias) `
  'frontend-origin evidence production_alias'
Assert-True ($canonicalFrontendOrigin -cne $immutableFrontendOrigin) `
  "Frontend-origin evidence production_alias must be distinct from its immutable deployment origin."
Assert-True ($callbackOrigin -ceq $canonicalFrontendOrigin) `
  "source_binding.callback_origin must equal the canonical frontend origin bound by frontend-origin evidence."

$architectureDecisionRef = [string]$sourceBinding.owner_architecture_decision_ref
Assert-True ($architectureDecisionRef -ceq 'docs/runtime-state/production-auth-architecture-decision.json') `
  "Owner architecture decision must use the canonical runtime-state path."
$resolvedArchitectureDecision = Resolve-RepoScopedFile $architectureDecisionRef
Assert-True ($null -ne $resolvedArchitectureDecision) `
  "Owner architecture decision is missing; production OAuth remains OWNER_ADR_REQUIRED."
& git -C $repoRoot ls-files --error-unmatch -- $resolvedArchitectureDecision.relative 2>$null | Out-Null
Assert-True ($LASTEXITCODE -eq 0) "Owner architecture decision must be tracked by Git."
& git -C $repoRoot diff --quiet HEAD -- $resolvedArchitectureDecision.relative
Assert-True ($LASTEXITCODE -eq 0) "Owner architecture decision must be clean relative to HEAD."
$expectedArchitectureDecisionSha = [string]$sourceBinding.owner_architecture_decision_sha256
Assert-True ($expectedArchitectureDecisionSha -cmatch '^[0-9a-f]{64}$') `
  "owner_architecture_decision_sha256 must be a lowercase SHA-256."
$actualArchitectureDecisionSha = (Get-FileHash -LiteralPath $resolvedArchitectureDecision.absolute -Algorithm SHA256).Hash.ToLowerInvariant()
Assert-True ($actualArchitectureDecisionSha -ceq $expectedArchitectureDecisionSha) `
  "Owner architecture decision SHA-256 mismatch."
try {
  $architectureDecision = Get-Content -LiteralPath $resolvedArchitectureDecision.absolute -Raw | ConvertFrom-Json
} catch {
  throw "Owner architecture decision must be valid JSON."
}
Assert-ExactPropertyNames $architectureDecision @(
  'contract_version',
  'status',
  'owner_approved',
  'selected_architecture',
  'target',
  'callback_origin',
  'source_commit_sha',
  'auth_runtime_evidence_ref',
  'auth_runtime_verifier_ref',
  'secret_output'
) 'Owner architecture decision'
Assert-True ([string]$architectureDecision.contract_version -ceq 'production-auth-architecture-decision-v1') `
  "Owner architecture decision contract mismatch."
Assert-True ([string]$architectureDecision.status -ceq 'owner_approved') `
  "Owner architecture decision status must be owner_approved."
Assert-JsonBool $architectureDecision 'owner_approved' $true
Assert-JsonBool $architectureDecision 'secret_output' $false
Assert-True ([string]$architectureDecision.target -ceq 'production') `
  "Production auth identity credit requires an explicit production target decision."
Assert-True ([string]$architectureDecision.callback_origin -ceq $canonicalFrontendOrigin) `
  "Owner architecture callback origin must equal the canonical production frontend origin."
Assert-True ([string]$architectureDecision.source_commit_sha -ceq $ExpectedCandidateSha) `
  "Owner architecture decision source_commit_sha must equal the expected candidate SHA."

$architecture = [string]$architectureDecision.selected_architecture
$architectureProfiles = @{
  cloudflare_native = [ordered]@{
    evidence_ref = 'docs/runtime-state/cloudflare-oauth-hosted-current.json'
    verifier_ref = 'scripts/verify-cloudflare-oauth-hosted-current.ps1'
    contract_version = 'cloudflare-oauth-hosted-current-v1'
  }
  hosted_fastapi = [ordered]@{
    evidence_ref = 'docs/runtime-state/fastapi-oauth-hosted-current.json'
    verifier_ref = 'scripts/verify-fastapi-oauth-hosted-current.ps1'
    contract_version = 'fastapi-oauth-hosted-current-v1'
  }
}
Assert-True ($architectureProfiles.ContainsKey($architecture)) `
  "Owner architecture decision must select exactly cloudflare_native or hosted_fastapi."
$architectureProfile = $architectureProfiles[$architecture]
$authRuntimeEvidenceRef = [string]$sourceBinding.auth_runtime_evidence_ref
Assert-True ($authRuntimeEvidenceRef -ceq [string]$architectureProfile.evidence_ref) `
  "Auth runtime evidence path does not match the Owner-selected architecture."
Assert-True ([string]$architectureDecision.auth_runtime_evidence_ref -ceq $authRuntimeEvidenceRef) `
  "Owner architecture decision and source_binding disagree on auth runtime evidence."
Assert-True ([string]$architectureDecision.auth_runtime_verifier_ref -ceq [string]$architectureProfile.verifier_ref) `
  "Owner architecture decision names the wrong architecture verifier."

$resolvedAuthRuntimeEvidence = Resolve-RepoScopedFile $authRuntimeEvidenceRef
Assert-True ($null -ne $resolvedAuthRuntimeEvidence) "Auth runtime evidence is unavailable."
& git -C $repoRoot ls-files --error-unmatch -- $resolvedAuthRuntimeEvidence.relative 2>$null | Out-Null
Assert-True ($LASTEXITCODE -eq 0) "Auth runtime evidence must be tracked by Git."
& git -C $repoRoot diff --quiet HEAD -- $resolvedAuthRuntimeEvidence.relative
Assert-True ($LASTEXITCODE -eq 0) "Auth runtime evidence must be clean relative to HEAD."
$expectedAuthRuntimeEvidenceSha = [string]$sourceBinding.auth_runtime_evidence_sha256
Assert-True ($expectedAuthRuntimeEvidenceSha -cmatch '^[0-9a-f]{64}$') `
  "auth_runtime_evidence_sha256 must be a lowercase SHA-256."
$actualAuthRuntimeEvidenceSha = (Get-FileHash -LiteralPath $resolvedAuthRuntimeEvidence.absolute -Algorithm SHA256).Hash.ToLowerInvariant()
Assert-True ($actualAuthRuntimeEvidenceSha -ceq $expectedAuthRuntimeEvidenceSha) `
  "Auth runtime evidence SHA-256 mismatch."
try {
  $authRuntimeEvidence = Get-Content -LiteralPath $resolvedAuthRuntimeEvidence.absolute -Raw | ConvertFrom-Json
} catch {
  throw "Auth runtime evidence must be valid JSON."
}
Assert-ExactPropertyNames $authRuntimeEvidence @(
  'contract_version',
  'status',
  'architecture',
  'source_commit_sha',
  'deployment_id',
  'runtime_origin',
  'provider_writes',
  'deployment_writes',
  'secret_output'
) 'Auth runtime evidence'
Assert-True ([string]$authRuntimeEvidence.contract_version -ceq [string]$architectureProfile.contract_version) `
  "Auth runtime evidence contract does not match the Owner-selected architecture."
Assert-True ([string]$authRuntimeEvidence.status -ceq 'verified') "Auth runtime evidence status must be verified."
Assert-True ([string]$authRuntimeEvidence.architecture -ceq $architecture) `
  "Auth runtime evidence architecture mismatch."
Assert-True ([string]$authRuntimeEvidence.source_commit_sha -ceq $ExpectedCandidateSha) `
  "Auth runtime evidence source_commit_sha must equal the expected candidate SHA."
Assert-True ([string]$authRuntimeEvidence.deployment_id -ceq [string]$sourceBinding.auth_runtime_deployment_id) `
  "Auth runtime deployment id mismatch."
$null = Assert-NonLocalHttpsOrigin ([string]$authRuntimeEvidence.runtime_origin) 'auth runtime evidence runtime_origin'
Assert-JsonBool $authRuntimeEvidence 'provider_writes' $false
Assert-JsonBool $authRuntimeEvidence 'deployment_writes' $false
Assert-JsonBool $authRuntimeEvidence 'secret_output' $false
$forbiddenAuthRuntimeSecretProperties = @(Find-ForbiddenSecretProperties $authRuntimeEvidence 'auth_runtime_evidence')
Assert-True ($forbiddenAuthRuntimeSecretProperties.Count -eq 0) `
  "Auth runtime evidence contains forbidden raw secret properties."

$resolvedAuthRuntimeVerifier = Resolve-RepoScopedFile ([string]$architectureProfile.verifier_ref)
Assert-True ($null -ne $resolvedAuthRuntimeVerifier) `
  "Owner-selected auth runtime verifier is unavailable."
& git -C $repoRoot ls-files --error-unmatch -- $resolvedAuthRuntimeVerifier.relative 2>$null | Out-Null
Assert-True ($LASTEXITCODE -eq 0) "Auth runtime verifier must be tracked by Git."
& git -C $repoRoot diff --quiet HEAD -- $resolvedAuthRuntimeVerifier.relative
Assert-True ($LASTEXITCODE -eq 0) "Auth runtime verifier must be clean relative to HEAD."
$authRuntimeVerifierOutput = @(
  & $powerShellExecutable -NoProfile -ExecutionPolicy Bypass `
    -File $resolvedAuthRuntimeVerifier.absolute `
    -EvidencePath $authRuntimeEvidenceRef `
    -ExpectedCandidateSha $ExpectedCandidateSha `
    -ValidateOnly 2>&1
)
Assert-True ($LASTEXITCODE -eq 0) "Owner-selected auth runtime dynamic validation failed."
$authRuntimeVerifierText = ($authRuntimeVerifierOutput | ForEach-Object { [string]$_ }) -join "`n"
foreach ($marker in @(
  '[production-auth-runtime] status=verified',
  "architecture=$architecture",
  'validation_mode=true',
  'read_only=true',
  'provider_writes=false',
  'deployment_writes=false',
  'secret_output=false'
)) {
  Assert-True ($authRuntimeVerifierText.Contains($marker)) `
    "Owner-selected auth runtime dynamic validation is missing marker: $marker"
}

$expectedSteps = @(
  'anonymous_login_no_identity',
  'github_start_exact_query',
  'github_cancel_no_credentials',
  'github_authorize_owner_identity',
  'callback_one_time_state',
  'auth_me_verified_identity',
  'reload_session_continuity',
  'refresh_atomic_rotation',
  'old_refresh_replay_rejected',
  'callback_replay_rejected',
  'logout_revocation_audited',
  'post_logout_refresh_rejected'
)
$stepsProperty = $evidence.PSObject.Properties['human_flow_verified_steps']
Assert-True ($null -ne $stepsProperty) "Evidence must contain human_flow_verified_steps."
$actualSteps = @($stepsProperty.Value)
Assert-True ($actualSteps.Count -eq $expectedSteps.Count) `
  "Evidence must contain exactly the 12 canonical human-flow steps."
Assert-True (@($actualSteps | Select-Object -Unique).Count -eq $actualSteps.Count) `
  "Evidence human-flow steps must not contain duplicates."
for ($index = 0; $index -lt $expectedSteps.Count; $index++) {
  Assert-True ($actualSteps[$index] -is [string]) `
    "Evidence human-flow step $index must be a string."
  Assert-True ([string]$actualSteps[$index] -ceq [string]$expectedSteps[$index]) `
    "Evidence human-flow step $index must equal '$($expectedSteps[$index])'."
}

$forbiddenSecretProperties = @(Find-ForbiddenSecretProperties $evidence)
Assert-True ($forbiddenSecretProperties.Count -eq 0) `
  "Evidence contains forbidden raw secret properties."

Write-Host ((
  "[production-auth-evidence] status=verified candidate_sha={0} " +
  "validation_mode=true read_only=true gate_promotion_performed=false secret_output=false " +
  "callback_origin_bound=true owner_architecture_adr_bound=true auth_runtime_bound=true"
) -f $ExpectedCandidateSha)

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

function Assert-NonLocalHttpsOrigin([string]$Value, [string]$Label) {
  $uri = $null
  Assert-True ([Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri)) "$Label must be an absolute URI."
  Assert-True ($uri.Scheme -eq 'https') "$Label must use HTTPS."
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
    'oauth_state_value', 'cookie_value', 'raw_cookie', 'secret_value'
  )
  foreach ($property in $Value.PSObject.Properties) {
    if ($forbidden -contains $property.Name.ToLowerInvariant()) { $found.Add("$Path.$($property.Name)") }
    foreach ($entry in @(Find-ForbiddenSecretProperties $property.Value "$Path.$($property.Name)")) {
      $found.Add($entry)
    }
  }
  return $found
}

$resolvedEvidence = Resolve-RepoScopedFile $EvidencePath
Assert-True ($null -ne $resolvedEvidence) "EvidencePath must resolve to an existing repo-scoped file."

& git -C $repoRoot ls-files --error-unmatch -- $resolvedEvidence.relative 2>$null | Out-Null
Assert-True ($LASTEXITCODE -eq 0) "Evidence must be tracked by Git."
& git -C $repoRoot diff --quiet HEAD -- $resolvedEvidence.relative
Assert-True ($LASTEXITCODE -eq 0) "Evidence must be clean relative to HEAD."

try {
  $evidence = Get-Content -LiteralPath $resolvedEvidence.absolute -Raw | ConvertFrom-Json
} catch {
  throw "Evidence must be valid JSON."
}

Assert-True ([string]$evidence.contract_version -eq 'production-auth-identity-proof-v1') `
  "Evidence contract must be production-auth-identity-proof-v1."
$evidenceVerified = [string]$evidence.status -eq 'verified' -or [string]$evidence.result -eq 'verified'
Assert-True $evidenceVerified "Evidence status must be verified."

foreach ($field in @(
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
)) {
  Assert-JsonBool $evidence $field $true
}

foreach ($field in @(
  'dev_only',
  'secret_output',
  'gate_promotion_performed',
  'verifier_mutations_performed'
)) {
  Assert-JsonBool $evidence $field $false
}

Assert-NonEmptyString $evidence 'oauth_scope'
Assert-True ([string]$evidence.oauth_scope -ceq 'read:user') "Evidence oauth_scope must be exactly read:user."

$sourceBindingProperty = $evidence.PSObject.Properties['source_binding']
Assert-True ($null -ne $sourceBindingProperty) "Evidence must contain source_binding."
$sourceBinding = $sourceBindingProperty.Value
Assert-True ($null -ne $sourceBinding) "Evidence source_binding must be an object."
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
Assert-JsonBool $sourceBinding 'immutable_frontend_deployment_verified' $true
Assert-JsonBool $sourceBinding 'immutable_auth_runtime_deployment_verified' $true
Assert-NonEmptyString $sourceBinding 'callback_origin'
Assert-NonEmptyString $sourceBinding 'callback_url'
$callbackOrigin = Assert-NonLocalHttpsOrigin ([string]$sourceBinding.callback_origin) 'source_binding.callback_origin'
$expectedCallbackUrl = $callbackOrigin.TrimEnd('/') + '/api/v1/auth/callback'
Assert-True ([string]$sourceBinding.callback_url -ceq $expectedCallbackUrl) `
  "source_binding.callback_url must be the exact callback endpoint on callback_origin."

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
foreach ($step in $expectedSteps) {
  Assert-True ($actualSteps -ccontains $step) "Evidence is missing human-flow step '$step'."
}

$forbiddenSecretProperties = @(Find-ForbiddenSecretProperties $evidence)
Assert-True ($forbiddenSecretProperties.Count -eq 0) `
  "Evidence contains forbidden raw secret properties."

Write-Host ((
  "[production-auth-evidence] status=verified candidate_sha={0} " +
  "validation_mode=true read_only=true gate_promotion_performed=false secret_output=false"
) -f $ExpectedCandidateSha)

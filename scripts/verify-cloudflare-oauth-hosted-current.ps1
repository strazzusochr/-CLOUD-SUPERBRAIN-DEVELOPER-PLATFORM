[CmdletBinding()]
param(
  [string]$EvidencePath = "docs/runtime-state/cloudflare-oauth-hosted-current.json",
  [string]$FlowEvidencePath = "docs/runtime-state/cloudflare-oauth-hosted-current-flow.json",
  [Parameter(Mandatory = $true)]
  [string]$ExpectedCandidateSha,
  [switch]$ValidateOnly,
  [switch]$Hosted,
  [string]$HostedBaseUrl,
  [string]$FrontendEvidencePath,
  [string]$OwnerApprovalPath,
  [string]$LiveConsentApprovalPath,
  [string]$FrontendDeploymentId,
  [string]$WorkerDeploymentId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$canonicalRuntimeEvidence = "docs/runtime-state/cloudflare-oauth-hosted-current.json"
$canonicalFlowEvidence = "docs/runtime-state/cloudflare-oauth-hosted-current-flow.json"
$canonicalFrontendEvidence = "docs/runtime-state/frontend-hosted-current.json"
$canonicalOwnerApproval = "docs/runtime-state/cloudflare-oauth-hosted-candidate-architecture-approval.json"
$canonicalConsentApproval = "docs/runtime-state/cloudflare-oauth-hosted-candidate-consent-approval.json"

$expectedStepNames = @(
  "anonymous_login_no_identity",
  "github_start_exact_query",
  "github_cancel_no_credentials",
  "github_authorize_owner_identity",
  "callback_one_time_state",
  "auth_me_verified_identity",
  "reload_session_continuity",
  "refresh_atomic_rotation",
  "old_refresh_replay_rejected",
  "callback_replay_rejected",
  "logout_revocation_audited",
  "post_logout_refresh_rejected"
)

$stepContract = @(
  [ordered]@{ surface = "browser";           action = "navigate_login_and_read_auth_me";              status = 401; outcome = "unauthenticated";                         d1 = $false; credentials = $false; audit = $false },
  [ordered]@{ surface = "browser_d1";        action = "click_github_sign_in";                         status = 303; outcome = "redirected_exact_scope";                  d1 = $true;  credentials = $false; audit = $false },
  [ordered]@{ surface = "browser_d1_audit";  action = "click_github_cancel";                          status = 401; outcome = "denied_no_credentials_state_consumed";    d1 = $true;  credentials = $false; audit = $true  },
  [ordered]@{ surface = "browser";           action = "click_github_authorize";                       status = 200; outcome = "owner_consent_recorded";                  d1 = $false; credentials = $false; audit = $false },
  [ordered]@{ surface = "browser_d1_audit";  action = "follow_callback_redirect";                     status = 303; outcome = "identity_verified_credentials_issued";    d1 = $true;  credentials = $true;  audit = $true  },
  [ordered]@{ surface = "browser";           action = "read_auth_me";                                status = 200; outcome = "identity_readback_verified";             d1 = $false; credentials = $false; audit = $false },
  [ordered]@{ surface = "browser";           action = "reload_authenticated_page";                   status = 200; outcome = "session_continuity_verified";            d1 = $false; credentials = $false; audit = $false },
  [ordered]@{ surface = "browser_d1_audit";  action = "click_refresh_action";                         status = 200; outcome = "refresh_rotated_once";                    d1 = $true;  credentials = $true;  audit = $true  },
  [ordered]@{ surface = "browser_d1_audit";  action = "replay_previous_refresh_via_browser_action";   status = 401; outcome = "replay_401_family_revoked";               d1 = $true;  credentials = $false; audit = $true  },
  [ordered]@{ surface = "browser_d1_audit";  action = "replay_consumed_callback_via_browser_action";  status = 401; outcome = "callback_replay_401_no_credentials";      d1 = $true;  credentials = $false; audit = $true  },
  [ordered]@{ surface = "browser_d1_audit";  action = "click_logout_action";                          status = 200; outcome = "one_active_refresh_revoked_audited";      d1 = $true;  credentials = $false; audit = $true  },
  [ordered]@{ surface = "browser_d1";        action = "click_refresh_after_logout";                   status = 401; outcome = "refresh_401_revoked";                     d1 = $true;  credentials = $false; audit = $false }
)

$auditContract = @(
  [ordered]@{ step = "github_cancel_no_credentials";      event = "auth_github_callback_blocked" },
  [ordered]@{ step = "callback_one_time_state";           event = "auth_github_callback_verified" },
  [ordered]@{ step = "refresh_atomic_rotation";           event = "auth_refresh_rotated" },
  [ordered]@{ step = "old_refresh_replay_rejected";       event = "auth_refresh_reuse_blocked" },
  [ordered]@{ step = "callback_replay_rejected";          event = "auth_github_callback_blocked" },
  [ordered]@{ step = "logout_revocation_audited";         event = "auth_logout_revoked" }
)

$allowedIdentityTargets = @("production")
$factCodesByKind = @{
  browser = @{
    anonymous_login_no_identity = @("human_navigation", "auth_me_http_401", "identity_projection_absent")
    github_start_exact_query = @("human_click", "github_redirect_http_303", "oauth_scope_exact_read_user")
    github_cancel_no_credentials = @("human_click", "provider_cancel_http_401", "credential_issue_count_0")
    github_authorize_owner_identity = @("human_click", "owner_consent_visible", "numeric_identity_only_hashed")
    callback_one_time_state = @("callback_http_303", "one_time_state_consumed", "credential_issue_count_1")
    auth_me_verified_identity = @("auth_me_http_200", "jwt_claims_verified", "numeric_identity_only_hashed")
    reload_session_continuity = @("human_reload", "auth_me_http_200", "session_hash_stable")
    refresh_atomic_rotation = @("human_click", "refresh_http_200", "credential_issue_count_1")
    old_refresh_replay_rejected = @("human_click", "refresh_replay_http_401", "credential_issue_count_0")
    callback_replay_rejected = @("human_click", "callback_replay_http_401", "credential_issue_count_0")
    logout_revocation_audited = @("human_click", "logout_http_200", "credential_issue_count_0")
    post_logout_refresh_rejected = @("human_click", "post_logout_refresh_http_401", "credential_issue_count_0")
  }
  d1_readback = @{
    github_start_exact_query = @("oauth_state_insert_count_1", "pending_state_count_1")
    github_cancel_no_credentials = @("oauth_state_delete_count_1", "credential_row_delta_0")
    callback_one_time_state = @("oauth_state_delete_count_1", "refresh_family_insert_count_1", "audit_before_credential_sequence")
    refresh_atomic_rotation = @("serialized_compare_and_swap", "parallel_attempt_count_2", "rotation_success_count_1", "rotation_reject_count_1", "history_insert_count_1", "active_refresh_count_1")
    old_refresh_replay_rejected = @("family_revocation_count_1", "active_refresh_count_0", "refresh_replay_http_401")
    callback_replay_rejected = @("oauth_state_count_0", "credential_row_delta_0", "callback_replay_http_401")
    logout_revocation_audited = @("active_refresh_count_1_to_0", "revoked_history_insert_count_1")
    post_logout_refresh_rejected = @("active_refresh_count_0", "credential_row_delta_0", "post_logout_refresh_http_401")
  }
  audit_readback = @{}
}
foreach ($auditEntry in $auditContract) {
  $factCodesByKind.audit_readback[[string]$auditEntry.step] = @(
    "audit_row_count_1", "event_type_exact", "request_hash_match",
    "session_hash_match_or_preauth", "sensitive_field_count_0", "persisted_before_credential_boundary"
  )
}

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Assert-ExactPropertyNames([object]$Object, [string[]]$Expected, [string]$Label) {
  Assert-True ($null -ne $Object) "$Label must be an object."
  $actual = @($Object.PSObject.Properties.Name)
  Assert-True ($actual.Count -eq $Expected.Count) `
    "$Label must contain exactly $($Expected.Count) properties."
  foreach ($name in $Expected) {
    Assert-True ($actual -ccontains $name) "$Label is missing property '$name'."
  }
  foreach ($name in $actual) {
    Assert-True ($Expected -ccontains $name) "$Label contains unexpected property '$name'."
  }
}

function Assert-JsonBool([object]$Object, [string]$Name, [bool]$Expected, [string]$Label) {
  $property = $Object.PSObject.Properties[$Name]
  Assert-True ($null -ne $property) "$Label is missing boolean '$Name'."
  Assert-True ($property.Value -is [bool]) "$Label.$Name must be a JSON boolean."
  Assert-True ([bool]$property.Value -eq $Expected) "$Label.$Name must be $($Expected.ToString().ToLowerInvariant())."
}

function Assert-NonEmptyString([object]$Object, [string]$Name, [string]$Label) {
  $property = $Object.PSObject.Properties[$Name]
  Assert-True ($null -ne $property) "$Label is missing string '$Name'."
  Assert-True ($property.Value -is [string]) "$Label.$Name must be a string."
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$property.Value)) "$Label.$Name must not be empty."
}

function Assert-LowerSha256([string]$Value, [string]$Label) {
  Assert-True ($Value -cmatch '^[0-9a-f]{64}$') "$Label must be a lowercase SHA-256."
}

function Assert-LowerGitSha([string]$Value, [string]$Label) {
  Assert-True ($Value -cmatch '^[0-9a-f]{40}$') "$Label must be a lowercase 40-character Git SHA."
}

function Get-StringSha256([string]$Value) {
  $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}

function ConvertTo-RepoRelative([string]$PathValue) {
  $absolute = [IO.Path]::GetFullPath((Join-Path $repoRoot $PathValue))
  $rootPrefix = [IO.Path]::GetFullPath($repoRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  Assert-True ($absolute.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) `
    "Evidence paths must remain inside the repository."
  $relative = [IO.Path]::GetRelativePath($repoRoot, $absolute).Replace('\', '/')
  return [pscustomobject]@{ absolute = $absolute; relative = $relative }
}

function Resolve-TrackedCleanFile([string]$PathValue, [string]$Label) {
  Assert-True (-not [string]::IsNullOrWhiteSpace($PathValue)) "$Label path is required."
  $resolved = ConvertTo-RepoRelative $PathValue
  Assert-True (Test-Path -LiteralPath $resolved.absolute -PathType Leaf) "$Label is missing."
  & git -C $repoRoot ls-files --error-unmatch -- $resolved.relative 2>$null | Out-Null
  Assert-True ($LASTEXITCODE -eq 0) "$Label must be tracked by Git."
  & git -C $repoRoot diff --quiet HEAD -- $resolved.relative
  Assert-True ($LASTEXITCODE -eq 0) "$Label must be clean relative to HEAD."
  return $resolved
}

function Read-JsonFile([object]$Resolved, [string]$Label) {
  $raw = Get-Content -LiteralPath $Resolved.absolute -Raw
  try {
    if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey("DateKind")) {
      $json = ConvertFrom-Json -InputObject $raw -DateKind String
    } else {
      $json = ConvertFrom-Json -InputObject $raw
    }
  } catch {
    throw "$Label must be valid JSON."
  }
  return [pscustomobject]@{ raw = $raw; json = $json }
}

function Assert-FileHash([object]$Resolved, [string]$ExpectedHash, [string]$Label) {
  Assert-LowerSha256 $ExpectedHash "$Label expected hash"
  $actualHash = (Get-FileHash -LiteralPath $Resolved.absolute -Algorithm SHA256).Hash.ToLowerInvariant()
  Assert-True ($actualHash -ceq $ExpectedHash) "$Label SHA-256 mismatch."
}

function Assert-CanonicalPath([object]$Resolved, [string]$Canonical, [string]$Label) {
  Assert-True ($Resolved.relative -ceq $Canonical) "$Label must use canonical path '$Canonical'."
}

function Assert-NonLocalHttpsOrigin([string]$Value, [string]$Label, [string]$HostSuffix) {
  Assert-True (-not [string]::IsNullOrWhiteSpace($Value)) "$Label is required."
  try { $uri = [Uri]$Value } catch { throw "$Label must be an HTTPS origin." }
  Assert-True ($uri.IsAbsoluteUri -and $uri.Scheme -ceq "https") "$Label must use HTTPS."
  Assert-True ($uri.IsDefaultPort) "$Label must use the default HTTPS port."
  Assert-True ($uri.AbsolutePath -ceq "/") "$Label must not contain a path."
  Assert-True ([string]::IsNullOrEmpty($uri.Query)) "$Label must not contain a query."
  Assert-True ([string]::IsNullOrEmpty($uri.Fragment)) "$Label must not contain a fragment."
  $dnsHost = $uri.DnsSafeHost.ToLowerInvariant()
  Assert-True ($dnsHost -notin @("localhost", "127.0.0.1", "::1") -and -not $dnsHost.EndsWith(".localhost")) `
    "$Label must be hosted and non-local."
  Assert-True ($dnsHost.EndsWith($HostSuffix)) "$Label must use host suffix '$HostSuffix'."
  return $Value.TrimEnd('/')
}

function Assert-UtcTimestamp([string]$Value, [string]$Label) {
  Assert-True ($Value -cmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$') `
    "$Label must be a UTC ISO-8601 timestamp."
  try { return [DateTimeOffset]::Parse($Value).ToUniversalTime() } catch { throw "$Label is invalid." }
}

function Assert-NoSensitiveEvidence([object]$Document, [string]$Label) {
  $findings = [Collections.Generic.List[string]]::new()
  $sensitiveKeyPattern = '(?i)^(?:provider_user_id|github_id|github_numeric_id|subject|subject_id|request_id|session_id|audit_id|audit_event_id|oauth_code|oauth_state|access_token|refresh_token|cookie|cookie_value|authorization|client_secret|jwt_signing_secret|code|state)$'
  $visit = $null
  $visit = {
    param([object]$Value, [string]$Path)
    if ($null -eq $Value) { return }
    if ($Value -is [string]) {
      $textValue = [string]$Value
      $allowedRawBindingPath = $Path -cmatch '(?i)\.(?:deployment_id|git_source_repo_id)$'
      $allowedSemanticEnumPath = (
        $Path -cmatch '(?i)\.fact_codes\[\d+\]$' -or
        $Path -cmatch '(?i)\.audit_event_types\[\d+\]$' -or
        $Path -cmatch '(?i)\.(?:artifact_kind|scorer_kind|outcome)$'
      )
      if (-not $allowedRawBindingPath -and -not $allowedSemanticEnumPath -and (
        $textValue -cmatch '(?i)^(?:github:|trace[_:-]|session[_:-]|request[_:-]|audit[_:-]|fam[_:-])' -or
        $textValue -cmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' -or
        $textValue -cmatch '^\d{5,}$'
      )) { [void]$findings.Add($Path) }
      return
    }
    if ($Value -is [ValueType]) {
      if ($Value -isnot [bool] -and $Value -isnot [DateTime] -and $Value -isnot [DateTimeOffset]) {
        try {
          $numericValue = [decimal]$Value
          if ([Math]::Abs($numericValue) -ge 10000 -and $Path -cnotmatch '(?i)\.(?:git_source_repo_id)$') {
            [void]$findings.Add($Path)
          }
        } catch {}
      }
      return
    }
    if ($Value -is [Collections.IDictionary]) {
      foreach ($keyObject in $Value.Keys) {
        $key = [string]$keyObject
        $childPath = "$Path.$key"
        if ($key -cmatch $sensitiveKeyPattern -and $key -cnotmatch '(?i)_sha256s?$') {
          [void]$findings.Add($childPath)
        }
        & $visit $Value[$keyObject] $childPath
      }
      return
    }
    if ($Value -is [Collections.IEnumerable]) {
      $index = 0
      foreach ($item in $Value) {
        & $visit $item "$Path[$index]"
        $index += 1
      }
      return
    }
    foreach ($property in $Value.PSObject.Properties) {
      $key = [string]$property.Name
      $childPath = "$Path.$key"
      if ($key -cmatch $sensitiveKeyPattern -and $key -cnotmatch '(?i)_sha256s?$') {
        [void]$findings.Add($childPath)
      }
      & $visit $property.Value $childPath
    }
  }
  & $visit $Document $Label
  Assert-True ($findings.Count -eq 0) "$Label contains a sensitive evidence key or value that is not SHA256-only."

  $serialized = $Document | ConvertTo-Json -Depth 100 -Compress
  $patterns = @(
    '(?i)github_pat_[A-Za-z0-9_]{8,}',
    '(?i)gh[pousr]_[A-Za-z0-9]{8,}',
    '(?i)csr_[A-Za-z0-9_-]{20,}',
    '(?i)phase3-auth-state-[A-Za-z0-9_-]{8,}',
    '(?i)authorization\s*[:=]\s*bearer\s+[A-Za-z0-9._-]+',
    '(?i)github:\d+',
    '(?i)__Host-[A-Za-z0-9_-]+=[^;\"\s]+'
  )
  foreach ($pattern in $patterns) {
    Assert-True ($serialized -notmatch $pattern) "$Label contains a forbidden raw identity, credential, cookie, state, code, or correlation value."
  }
}

function Assert-StringArrayExact([object]$Value, [string[]]$Expected, [string]$Label) {
  $actual = @($Value)
  Assert-True ($actual.Count -eq $Expected.Count) "$Label must contain exactly $($Expected.Count) entries."
  Assert-True (@($actual | Select-Object -Unique).Count -eq $actual.Count) "$Label must not contain duplicates."
  for ($i = 0; $i -lt $Expected.Count; $i++) {
    Assert-True ($actual[$i] -is [string]) "$Label entry $i must be a string."
    Assert-True ([string]$actual[$i] -ceq $Expected[$i]) "$Label entry $i must equal '$($Expected[$i])'."
  }
}

function Assert-StringSetExact([object]$Value, [string[]]$Expected, [string]$Label) {
  $actual = @($Value)
  Assert-True ($actual.Count -eq $Expected.Count) "$Label must contain exactly $($Expected.Count) entries."
  Assert-True (@($actual | Select-Object -Unique).Count -eq $actual.Count) "$Label must not contain duplicates."
  foreach ($item in $actual) {
    Assert-True ($item -is [string]) "$Label entries must be strings."
    Assert-True ($Expected -ccontains [string]$item) "$Label contains an unexpected entry."
  }
}

function Get-ReadOnlyHttp([string]$Uri) {
  Add-Type -AssemblyName System.Net.Http
  $handler = [Net.Http.HttpClientHandler]::new()
  $handler.AllowAutoRedirect = $false
  $client = [Net.Http.HttpClient]::new($handler)
  $client.Timeout = [TimeSpan]::FromSeconds(30)
  try {
    $response = $client.GetAsync($Uri).GetAwaiter().GetResult()
    $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    return [pscustomobject]@{ status = [int]$response.StatusCode; content = $content }
  } catch {
    throw "Hosted read-only validation failed."
  } finally {
    $client.Dispose()
    $handler.Dispose()
  }
}

Assert-True ($ValidateOnly -xor $Hosted) "Choose exactly one mode: -ValidateOnly or -Hosted."
Assert-LowerGitSha $ExpectedCandidateSha "ExpectedCandidateSha"

& git -C $repoRoot cat-file -e "${ExpectedCandidateSha}^{commit}" 2>$null
Assert-True ($LASTEXITCODE -eq 0) "ExpectedCandidateSha must resolve to a local commit."
& git -C $repoRoot merge-base --is-ancestor $ExpectedCandidateSha HEAD
Assert-True ($LASTEXITCODE -eq 0) "ExpectedCandidateSha must be an ancestor of HEAD."

$runtimeResolved = Resolve-TrackedCleanFile $EvidencePath "Cloudflare OAuth runtime evidence"
Assert-CanonicalPath $runtimeResolved $canonicalRuntimeEvidence "Cloudflare OAuth runtime evidence"
$runtimeDocument = Read-JsonFile $runtimeResolved "Cloudflare OAuth runtime evidence"
$runtime = $runtimeDocument.json
Assert-NoSensitiveEvidence $runtime "Cloudflare OAuth runtime evidence"
Assert-ExactPropertyNames $runtime @(
  "contract_version", "status", "architecture", "source_commit_sha", "deployment_id",
  "runtime_origin", "provider_writes", "deployment_writes", "secret_output"
) "Cloudflare OAuth runtime evidence"
Assert-True ([string]$runtime.contract_version -ceq "cloudflare-oauth-hosted-current-v1") "Runtime evidence contract mismatch."
Assert-True ([string]$runtime.status -ceq "verified") "Runtime evidence status must be verified."
Assert-True ([string]$runtime.architecture -ceq "cloudflare_native") "Runtime evidence architecture must be cloudflare_native."
Assert-True ([string]$runtime.source_commit_sha -ceq $ExpectedCandidateSha) "Runtime evidence source_commit_sha mismatch."
Assert-NonEmptyString $runtime "deployment_id" "Cloudflare OAuth runtime evidence"
$workerOrigin = Assert-NonLocalHttpsOrigin ([string]$runtime.runtime_origin) "Runtime evidence origin" ".workers.dev"
Assert-JsonBool $runtime "provider_writes" $false "Cloudflare OAuth runtime evidence"
Assert-JsonBool $runtime "deployment_writes" $false "Cloudflare OAuth runtime evidence"
Assert-JsonBool $runtime "secret_output" $false "Cloudflare OAuth runtime evidence"

$flowResolved = Resolve-TrackedCleanFile $FlowEvidencePath "Cloudflare OAuth flow evidence"
Assert-CanonicalPath $flowResolved $canonicalFlowEvidence "Cloudflare OAuth flow evidence"
$flowDocument = Read-JsonFile $flowResolved "Cloudflare OAuth flow evidence"
$flow = $flowDocument.json
Assert-NoSensitiveEvidence $flow "Cloudflare OAuth flow evidence"
Assert-ExactPropertyNames $flow @(
  "contract_version", "status", "architecture", "source_binding", "approval_binding", "sensitive_hash_bindings",
  "execution", "human_flow_steps", "token_families", "scorer_outputs", "atomic_replay_evidence", "audit_correlations",
  "redaction", "gate_transition", "non_claims"
) "Cloudflare OAuth flow evidence"
Assert-True ([string]$flow.contract_version -ceq "cloudflare-oauth-hosted-current-flow-v1") "Flow evidence contract mismatch."
Assert-True ([string]$flow.status -ceq "evidence_envelope_complete") `
  "Flow evidence status must describe an evidence envelope, not a full live-proof claim."
Assert-True ([string]$flow.architecture -ceq "cloudflare_native") "Flow evidence architecture must be cloudflare_native."

$sensitiveHashes = $flow.sensitive_hash_bindings
Assert-ExactPropertyNames $sensitiveHashes @(
  "provider_user_id_sha256", "subject_sha256", "oauth_code_sha256", "oauth_state_sha256",
  "access_token_sha256", "refresh_token_before_sha256", "refresh_token_after_sha256", "cookie_bundle_sha256"
) "Flow sensitive_hash_bindings"
foreach ($field in $sensitiveHashes.PSObject.Properties.Name) {
  Assert-LowerSha256 ([string]$sensitiveHashes.$field) "Flow sensitive_hash_bindings.$field"
}
Assert-True (@($sensitiveHashes.PSObject.Properties.Value | Select-Object -Unique).Count -eq 8) `
  "Every sensitive raw value requires a distinct SHA256-only counterpart."

$binding = $flow.source_binding
Assert-ExactPropertyNames $binding @(
  "candidate_source_commit_sha", "frontend_source_commit_sha", "worker_source_commit_sha",
  "worker_source_archive_sha256", "frontend_deployment_id_sha256", "worker_deployment_id_sha256",
  "frontend_origin", "worker_origin", "callback_url", "frontend_evidence_ref",
  "frontend_evidence_sha256", "runtime_evidence_sha256"
) "Flow source_binding"
foreach ($field in @("candidate_source_commit_sha", "worker_source_commit_sha")) {
  Assert-True ([string]$binding.$field -ceq $ExpectedCandidateSha) "source_binding.$field must equal ExpectedCandidateSha."
}
Assert-LowerGitSha ([string]$binding.frontend_source_commit_sha) "source_binding.frontend_source_commit_sha"
& git -C $repoRoot cat-file -e "$([string]$binding.frontend_source_commit_sha)^{commit}" 2>$null
Assert-True ($LASTEXITCODE -eq 0) "Frontend source commit must resolve locally."
& git -C $repoRoot merge-base --is-ancestor ([string]$binding.frontend_source_commit_sha) HEAD
Assert-True ($LASTEXITCODE -eq 0) "Frontend source commit must be an ancestor of the evidence HEAD."
foreach ($field in @(
  "worker_source_archive_sha256", "frontend_deployment_id_sha256", "worker_deployment_id_sha256",
  "frontend_evidence_sha256", "runtime_evidence_sha256"
)) { Assert-LowerSha256 ([string]$binding.$field) "source_binding.$field" }

$boundFrontendOrigin = Assert-NonLocalHttpsOrigin ([string]$binding.frontend_origin) "Bound frontend origin" ".vercel.app"
$boundWorkerOrigin = Assert-NonLocalHttpsOrigin ([string]$binding.worker_origin) "Bound Worker origin" ".workers.dev"
Assert-True ($boundWorkerOrigin -ceq $workerOrigin) "Flow Worker origin must equal runtime evidence origin."
Assert-True ([string]$binding.callback_url -ceq "$boundFrontendOrigin/api/v1/auth/callback") `
  "Callback URL must be the exact callback path on the bound frontend origin."
Assert-True ((Get-StringSha256 ([string]$runtime.deployment_id)) -ceq [string]$binding.worker_deployment_id_sha256) `
  "Worker deployment binding mismatch."
Assert-FileHash $runtimeResolved ([string]$binding.runtime_evidence_sha256) "Runtime evidence"

$frontendResolved = Resolve-TrackedCleanFile ([string]$binding.frontend_evidence_ref) "Hosted frontend evidence"
Assert-CanonicalPath $frontendResolved $canonicalFrontendEvidence "Hosted frontend evidence"
Assert-FileHash $frontendResolved ([string]$binding.frontend_evidence_sha256) "Hosted frontend evidence"
$frontendDocument = Read-JsonFile $frontendResolved "Hosted frontend evidence"
$frontend = $frontendDocument.json
Assert-NoSensitiveEvidence $frontend "Hosted frontend evidence"
foreach ($field in @(
  "contract_version", "status", "source_commit_sha", "deployment_id", "immutable_deployment_url",
  "production_alias", "vercel_target", "deployment_metadata_verified", "deployment_alias_content_parity",
  "production_operational_deploy_verified", "production_release_claimed"
)) { Assert-True ($null -ne $frontend.PSObject.Properties[$field]) "Hosted frontend evidence is missing '$field'." }
Assert-True ([string]$frontend.contract_version -ceq "frontend-hosted-current-proof-v1") "Hosted frontend contract mismatch."
Assert-True ([string]$frontend.status -ceq "verified") "Hosted frontend evidence status must be verified."
Assert-True ([string]$frontend.source_commit_sha -ceq [string]$binding.frontend_source_commit_sha) "Hosted frontend source SHA mismatch."
Assert-True ([string]$frontend.vercel_target -ceq "production") `
  "OAuth identity evidence requires the canonical production frontend target."
$immutableFrontendOrigin = Assert-NonLocalHttpsOrigin ([string]$frontend.immutable_deployment_url) "Immutable frontend origin" ".vercel.app"
$productionFrontendOrigin = Assert-NonLocalHttpsOrigin ([string]$frontend.production_alias) "Production frontend origin" ".vercel.app"
Assert-True ($productionFrontendOrigin -ceq $boundFrontendOrigin) `
  "Bound frontend origin must equal the canonical production alias."
Assert-True ($immutableFrontendOrigin -cne $productionFrontendOrigin) `
  "Production alias must be distinct from its immutable deployment origin."
Assert-True ((Get-StringSha256 ([string]$frontend.deployment_id)) -ceq [string]$binding.frontend_deployment_id_sha256) `
  "Frontend deployment binding mismatch."
Assert-JsonBool $frontend "deployment_metadata_verified" $true "Hosted frontend evidence"
Assert-JsonBool $frontend "deployment_alias_content_parity" $true "Hosted frontend evidence"
Assert-JsonBool $frontend "production_operational_deploy_verified" $true "Hosted frontend evidence"
Assert-JsonBool $frontend "production_release_claimed" $false "Hosted frontend evidence"

$approval = $flow.approval_binding
Assert-ExactPropertyNames $approval @(
  "owner_architecture_decision_ref", "owner_architecture_decision_sha256",
  "live_consent_approval_ref", "live_consent_approval_sha256", "owner_approved_candidate_sha",
  "approved_oauth_scope", "approved_callback_origin", "approved_worker_origin"
) "Flow approval_binding"
Assert-True ([string]$approval.owner_architecture_decision_ref -ceq $canonicalOwnerApproval) `
  "Owner architecture approval must use the canonical path."
Assert-True ([string]$approval.live_consent_approval_ref -ceq $canonicalConsentApproval) `
  "Live consent approval must use the canonical path."
Assert-LowerSha256 ([string]$approval.owner_architecture_decision_sha256) "Owner architecture approval hash"
Assert-LowerSha256 ([string]$approval.live_consent_approval_sha256) "Live consent approval hash"
Assert-True ([string]$approval.owner_approved_candidate_sha -ceq $ExpectedCandidateSha) "Owner-approved candidate SHA mismatch."
Assert-True ([string]$approval.approved_oauth_scope -ceq "read:user") "Approved OAuth scope must be exactly read:user."
Assert-True ([string]$approval.approved_callback_origin -ceq $boundFrontendOrigin) "Approved callback origin mismatch."
Assert-True ([string]$approval.approved_worker_origin -ceq $boundWorkerOrigin) "Approved Worker origin mismatch."

$ownerResolved = Resolve-TrackedCleanFile ([string]$approval.owner_architecture_decision_ref) "Owner architecture decision"
Assert-FileHash $ownerResolved ([string]$approval.owner_architecture_decision_sha256) "Owner architecture decision"
$ownerDocument = Read-JsonFile $ownerResolved "Owner architecture decision"
$owner = $ownerDocument.json
Assert-NoSensitiveEvidence $owner "Owner architecture decision"
Assert-ExactPropertyNames $owner @(
  "contract_version", "status", "owner_approved", "selected_architecture", "target",
  "callback_origin", "source_commit_sha", "auth_runtime_evidence_ref", "auth_runtime_verifier_ref", "secret_output"
) "Owner architecture decision"
Assert-True ([string]$owner.contract_version -ceq "cloudflare-oauth-hosted-candidate-architecture-approval-v1") `
  "Owner candidate architecture decision contract mismatch."
Assert-True ([string]$owner.status -ceq "owner_approved") "Owner architecture decision status must be owner_approved."
Assert-JsonBool $owner "owner_approved" $true "Owner architecture decision"
Assert-True ([string]$owner.selected_architecture -ceq "cloudflare_native") "Owner architecture must select cloudflare_native."
$approvedTarget = [string]$owner.target
Assert-True ($allowedIdentityTargets -ccontains $approvedTarget) `
  "Owner architecture target must be production identity without a release claim."
Assert-True ([string]$owner.callback_origin -ceq $boundFrontendOrigin) "Owner architecture callback origin mismatch."
Assert-True ([string]$owner.source_commit_sha -ceq $ExpectedCandidateSha) "Owner architecture source SHA mismatch."
Assert-True ([string]$owner.auth_runtime_evidence_ref -ceq $canonicalRuntimeEvidence) "Owner architecture runtime evidence ref mismatch."
Assert-True ([string]$owner.auth_runtime_verifier_ref -ceq "scripts/verify-cloudflare-oauth-hosted-current.ps1") `
  "Owner architecture verifier ref mismatch."
Assert-JsonBool $owner "secret_output" $false "Owner architecture decision"

$consentResolved = Resolve-TrackedCleanFile ([string]$approval.live_consent_approval_ref) "Live consent approval"
Assert-FileHash $consentResolved ([string]$approval.live_consent_approval_sha256) "Live consent approval"
$consentDocument = Read-JsonFile $consentResolved "Live consent approval"
$consent = $consentDocument.json
Assert-NoSensitiveEvidence $consent "Live consent approval"
Assert-ExactPropertyNames $consent @(
  "contract_version", "status", "owner_approved", "source_commit_sha", "target", "architecture",
  "oauth_scope", "frontend_origin", "worker_origin", "real_provider_consent_approved", "approved_at", "secret_output"
) "Live consent approval"
Assert-True ([string]$consent.contract_version -ceq "cloudflare-oauth-hosted-candidate-consent-approval-v1") `
  "Hosted-candidate live consent approval contract mismatch."
Assert-True ([string]$consent.status -ceq "owner_approved") "Live consent approval status must be owner_approved."
Assert-JsonBool $consent "owner_approved" $true "Live consent approval"
Assert-JsonBool $consent "real_provider_consent_approved" $true "Live consent approval"
Assert-JsonBool $consent "secret_output" $false "Live consent approval"
Assert-True ([string]$consent.source_commit_sha -ceq $ExpectedCandidateSha) "Live consent source SHA mismatch."
Assert-True ([string]$consent.target -ceq $approvedTarget) `
  "Live consent target must equal the approved production identity target."
Assert-True ([string]$consent.architecture -ceq "cloudflare_native") "Live consent architecture mismatch."
Assert-True ([string]$consent.oauth_scope -ceq "read:user") "Live consent OAuth scope must be exactly read:user."
Assert-True ([string]$consent.frontend_origin -ceq $boundFrontendOrigin) "Live consent frontend origin mismatch."
Assert-True ([string]$consent.worker_origin -ceq $boundWorkerOrigin) "Live consent Worker origin mismatch."
$consentApprovedAt = Assert-UtcTimestamp ([string]$consent.approved_at) "Live consent approved_at"

$execution = $flow.execution
Assert-ExactPropertyNames $execution @(
  "target", "transport", "browser_channel", "browser_execution", "human_click_count",
  "identity_evidence", "oauth_scope", "provider_call_count", "provider_write_count",
  "deployment_write_count", "localhost_transport_count", "owner_interaction", "started_at", "completed_at"
) "Flow execution"
Assert-True ([string]$execution.target -ceq $approvedTarget) `
  "Execution target must equal the approved production identity target."
Assert-True ([string]$execution.transport -ceq "hosted_https") "Flow execution transport must be hosted_https."
Assert-True ([string]$execution.browser_channel -ceq "chrome") "Flow execution browser channel must be chrome."
Assert-True ([string]$execution.browser_execution -ceq "real_chrome") "Flow execution must identify the real browser executor."
Assert-True ([int]$execution.human_click_count -eq 12) "Flow execution must derive exactly 12 human clicks."
Assert-True ([string]$execution.identity_evidence -ceq "numeric_owner_identity_sha256_only") `
  "Identity evidence must be represented only by a SHA256 correlation."
Assert-True ([string]$execution.oauth_scope -ceq "read:user") "Execution OAuth scope must be exactly read:user."
Assert-True ([int]$execution.provider_call_count -eq 2) "Flow execution must derive the bounded token and user provider calls."
foreach ($field in @("provider_write_count", "deployment_write_count", "localhost_transport_count")) {
  Assert-True ([int]$execution.$field -eq 0) "Flow execution $field must be zero."
}
Assert-True ([string]$execution.owner_interaction -ceq "interactive_consent") `
  "Flow execution must bind the Owner's interactive consent action."
$executionStartedAt = Assert-UtcTimestamp ([string]$execution.started_at) "Execution started_at"
$executionCompletedAt = Assert-UtcTimestamp ([string]$execution.completed_at) "Execution completed_at"
Assert-True ($executionCompletedAt -ge $executionStartedAt) "Execution completed_at must not precede started_at."
Assert-True ($executionStartedAt -ge $consentApprovedAt) "Execution must not predate the bound live-consent approval."

$artifactCache = @{}
function Get-SanitizedArtifact([string]$Reference, [string]$Hash, [string]$Kind) {
  Assert-True (-not [string]::IsNullOrWhiteSpace($Reference)) "Sanitized artifact reference is required."
  Assert-LowerSha256 $Hash "Sanitized artifact hash"
  $key = "$Reference|$Hash|$Kind"
  if ($artifactCache.ContainsKey($key)) { return $artifactCache[$key] }
  $resolved = Resolve-TrackedCleanFile $Reference "Sanitized $Kind artifact"
  Assert-FileHash $resolved $Hash "Sanitized $Kind artifact"
  $document = Read-JsonFile $resolved "Sanitized $Kind artifact"
  $artifact = $document.json
  Assert-NoSensitiveEvidence $artifact "Sanitized $Kind artifact"
  Assert-ExactPropertyNames $artifact @(
    "contract_version", "status", "artifact_kind", "candidate_source_commit_sha",
    "frontend_deployment_id_sha256", "worker_deployment_id_sha256", "covered_steps",
    "request_correlation_sha256s", "session_correlation_sha256s", "audit_event_types",
    "generated_at", "raw_capture_sha256", "redaction_manifest_sha256", "sensitive_value_sha256s",
    "observations", "secret_value_count"
  ) "Sanitized $Kind artifact"
  Assert-True ([string]$artifact.contract_version -ceq "cloudflare-oauth-sanitized-observation-artifact-v2") `
    "Sanitized artifact contract mismatch."
  Assert-True ([string]$artifact.status -ceq "raw_derived_sanitized") `
    "Sanitized artifact must describe raw-derived observations without claiming full verification."
  Assert-True ([string]$artifact.artifact_kind -ceq $Kind) "Sanitized artifact kind mismatch."
  Assert-True ([string]$artifact.candidate_source_commit_sha -ceq $ExpectedCandidateSha) "Sanitized artifact source SHA mismatch."
  Assert-True ([string]$artifact.frontend_deployment_id_sha256 -ceq [string]$binding.frontend_deployment_id_sha256) `
    "Sanitized artifact frontend deployment binding mismatch."
  Assert-True ([string]$artifact.worker_deployment_id_sha256 -ceq [string]$binding.worker_deployment_id_sha256) `
    "Sanitized artifact Worker deployment binding mismatch."
  Assert-LowerSha256 ([string]$artifact.raw_capture_sha256) "Sanitized artifact raw-capture binding"
  Assert-LowerSha256 ([string]$artifact.redaction_manifest_sha256) "Sanitized artifact redaction-manifest binding"
  foreach ($sensitiveHash in @($artifact.sensitive_value_sha256s)) {
    Assert-LowerSha256 ([string]$sensitiveHash) "Sanitized artifact sensitive-value binding"
  }
  Assert-True (@($artifact.sensitive_value_sha256s | Select-Object -Unique).Count -eq @($artifact.sensitive_value_sha256s).Count) `
    "Sanitized artifact sensitive-value bindings must be unique."
  Assert-True ([int]$artifact.secret_value_count -eq 0) "Sanitized artifact secret_value_count must be zero."
  $generatedAt = Assert-UtcTimestamp ([string]$artifact.generated_at) "Sanitized artifact generated_at"
  Assert-True ($generatedAt -ge $executionStartedAt -and $generatedAt -le $executionCompletedAt) `
    "Sanitized artifact timestamp must fall inside the approved execution window."
  $result = [pscustomobject]@{ resolved = $resolved; artifact = $artifact; hash = $Hash; reference = $Reference; kind = $Kind }
  $artifactCache[$key] = $result
  return $result
}

function Get-ObservationFactHash([object[]]$Observations) {
  $lines = @(
    foreach ($observation in $Observations) {
      $factCodes = @($observation.fact_codes) -join ','
      $session = if ($null -eq $observation.session_correlation_sha256) { "" } else { [string]$observation.session_correlation_sha256 }
      @(
        [string][int]$observation.sequence,
        [string]$observation.step,
        [string][int]$observation.http_status,
        $factCodes,
        [string]$observation.request_correlation_sha256,
        $session,
        [string]$observation.source_record_sha256
      ) -join '|'
    }
  )
  return Get-StringSha256 ($lines -join "`n")
}

$steps = @($flow.human_flow_steps)
Assert-True ($steps.Count -eq 12) "Flow evidence must contain exactly 12 human/browser/D1 steps."
$stepByName = @{}
$requestHashes = @()
$sessionHashA = $null
$sessionHashB = $null
$artifactByKind = @{}

for ($index = 0; $index -lt 12; $index++) {
  $step = $steps[$index]
  $expected = $stepContract[$index]
  $name = $expectedStepNames[$index]
  $label = "human_flow_steps[$index]"
  Assert-ExactPropertyNames $step @(
    "sequence", "name", "surface", "action", "http_status", "outcome", "human_click_count",
    "d1_readback_match_count", "credential_issue_count", "request_correlation_sha256",
    "session_correlation_sha256", "evidence", "secret_value_count"
  ) $label
  Assert-True ([int]$step.sequence -eq ($index + 1)) "$label sequence mismatch."
  Assert-True ([string]$step.name -ceq $name) "$label name must be '$name'."
  Assert-True ([string]$step.surface -ceq [string]$expected.surface) "$label surface mismatch."
  Assert-True ([string]$step.action -ceq [string]$expected.action) "$label action mismatch."
  Assert-True ([int]$step.http_status -eq [int]$expected.status) "$label HTTP status mismatch."
  Assert-True ([string]$step.outcome -ceq [string]$expected.outcome) "$label outcome mismatch."
  Assert-True ([int]$step.human_click_count -eq 1) "$label human_click_count must equal one."
  Assert-True ([int]$step.d1_readback_match_count -eq $(if ([bool]$expected.d1) { 1 } else { 0 })) `
    "$label d1_readback_match_count mismatch."
  Assert-True ([int]$step.credential_issue_count -eq $(if ([bool]$expected.credentials) { 1 } else { 0 })) `
    "$label credential_issue_count mismatch."
  Assert-True ([int]$step.secret_value_count -eq 0) "$label secret_value_count must be zero."
  Assert-LowerSha256 ([string]$step.request_correlation_sha256) "$label request correlation"
  $requestHashes += [string]$step.request_correlation_sha256
  if ($index -lt 4) {
    Assert-True ($null -eq $step.session_correlation_sha256) "$label must not contain a pre-auth session correlation."
  } else {
    Assert-LowerSha256 ([string]$step.session_correlation_sha256) "$label session correlation"
    if ($index -lt 10) {
      if ($null -eq $sessionHashA) { $sessionHashA = [string]$step.session_correlation_sha256 }
      Assert-True ([string]$step.session_correlation_sha256 -ceq $sessionHashA) `
        "$label must remain bound to refresh-replay family A."
    } else {
      if ($null -eq $sessionHashB) { $sessionHashB = [string]$step.session_correlation_sha256 }
      Assert-True ([string]$step.session_correlation_sha256 -ceq $sessionHashB) `
        "$label must remain bound to logout family B."
    }
  }

  $evidence = $step.evidence
  Assert-ExactPropertyNames $evidence @(
    "browser_ref", "browser_sha256", "d1_ref", "d1_sha256", "audit_ref", "audit_sha256"
  ) "$label.evidence"
  $browserArtifact = Get-SanitizedArtifact ([string]$evidence.browser_ref) ([string]$evidence.browser_sha256) "browser"
  $artifactByKind["browser"] = $browserArtifact
  if ([bool]$expected.d1) {
    $d1Artifact = Get-SanitizedArtifact ([string]$evidence.d1_ref) ([string]$evidence.d1_sha256) "d1_readback"
    $artifactByKind["d1_readback"] = $d1Artifact
  } else {
    Assert-True ($null -eq $evidence.d1_ref -and $null -eq $evidence.d1_sha256) "$label must not claim D1 evidence."
  }
  if ([bool]$expected.audit) {
    $auditArtifact = Get-SanitizedArtifact ([string]$evidence.audit_ref) ([string]$evidence.audit_sha256) "audit_readback"
    $artifactByKind["audit_readback"] = $auditArtifact
  } else {
    Assert-True ($null -eq $evidence.audit_ref -and $null -eq $evidence.audit_sha256) "$label must not claim audit evidence."
  }
  $stepByName[$name] = $step
}

Assert-True (@($requestHashes | Select-Object -Unique).Count -eq 12) "Each human-flow step requires a distinct hashed request correlation."
Assert-True ($null -ne $sessionHashA -and $null -ne $sessionHashB -and $sessionHashA -cne $sessionHashB) `
  "Refresh-replay family A and logout family B require distinct session correlations."
Assert-True ($artifactByKind.Count -eq 3) "Flow evidence must bind exactly browser, D1-readback, and audit-readback artifacts."

$tokenFamilies = $flow.token_families
Assert-ExactPropertyNames $tokenFamilies @(
  "contract_version", "distinct_family_count", "distinct_family_ids_verified", "families", "secret_value_count"
) "Flow token_families"
Assert-True ([string]$tokenFamilies.contract_version -ceq "cloudflare-oauth-token-families-v1") `
  "Token-family contract mismatch."
Assert-True ([int]$tokenFamilies.distinct_family_count -eq 2) "Token-family proof must contain exactly two families."
Assert-JsonBool $tokenFamilies "distinct_family_ids_verified" $true "Flow token_families"
Assert-True ([int]$tokenFamilies.secret_value_count -eq 0) "Flow token_families.secret_value_count must be zero."
$families = @($tokenFamilies.families)
Assert-True ($families.Count -eq 2) "Token-family proof must contain exactly family A and family B."
$familyContract = @(
  [ordered]@{
    label = "family_a"; purpose = "refresh_replay"; session = $sessionHashA;
    issuance = "callback_one_time_state"; terminal = "old_refresh_replay_rejected";
    reason = "token_replay_detected"; status = 401
  },
  [ordered]@{
    label = "family_b"; purpose = "logout"; session = $sessionHashB;
    issuance = "independent_family_b_callback"; terminal = "logout_revocation_audited";
    reason = "user_logout"; status = 200
  }
)
$familyIdHashes = @()
for ($familyIndex = 0; $familyIndex -lt 2; $familyIndex++) {
  $family = $families[$familyIndex]
  $expectedFamily = $familyContract[$familyIndex]
  $familyLabel = "token_families.families[$familyIndex]"
  Assert-ExactPropertyNames $family @(
    "label", "purpose", "family_id_sha256", "session_correlation_sha256", "issuance_evidence_step",
    "terminal_evidence_step", "terminal_reason", "terminal_http_status", "credential_issue_after_terminal_count"
  ) $familyLabel
  Assert-True ([string]$family.label -ceq [string]$expectedFamily.label) "$familyLabel label mismatch."
  Assert-True ([string]$family.purpose -ceq [string]$expectedFamily.purpose) "$familyLabel purpose mismatch."
  Assert-LowerSha256 ([string]$family.family_id_sha256) "$familyLabel family identity"
  $familyIdHashes += [string]$family.family_id_sha256
  Assert-True ([string]$family.session_correlation_sha256 -ceq [string]$expectedFamily.session) `
    "$familyLabel session correlation mismatch."
  Assert-True ([string]$family.issuance_evidence_step -ceq [string]$expectedFamily.issuance) `
    "$familyLabel issuance evidence mismatch."
  Assert-True ([string]$family.terminal_evidence_step -ceq [string]$expectedFamily.terminal) `
    "$familyLabel terminal evidence mismatch."
  Assert-True ([string]$family.terminal_reason -ceq [string]$expectedFamily.reason) `
    "$familyLabel terminal reason mismatch."
  Assert-True ([int]$family.terminal_http_status -eq [int]$expectedFamily.status) `
    "$familyLabel terminal HTTP status mismatch."
  Assert-True ([int]$family.credential_issue_after_terminal_count -eq 0) `
    "$familyLabel must issue no credentials after its terminal security event."
}
Assert-True (@($familyIdHashes | Select-Object -Unique).Count -eq 2) `
  "Refresh-replay family A and logout family B must have distinct family identity hashes."

$browserCovered = @($expectedStepNames)
$d1Covered = @(
  "github_start_exact_query", "github_cancel_no_credentials", "callback_one_time_state",
  "refresh_atomic_rotation", "old_refresh_replay_rejected", "callback_replay_rejected",
  "logout_revocation_audited", "post_logout_refresh_rejected"
)
$auditCovered = @($auditContract | ForEach-Object { [string]$_.step })
$coveredByKind = @{ browser = $browserCovered; d1_readback = $d1Covered; audit_readback = $auditCovered }
$sensitiveByKind = @{
  browser = @($sensitiveHashes.PSObject.Properties.Value | ForEach-Object { [string]$_ })
  d1_readback = @(
    [string]$sensitiveHashes.subject_sha256,
    [string]$sensitiveHashes.oauth_state_sha256,
    [string]$sensitiveHashes.refresh_token_before_sha256,
    [string]$sensitiveHashes.refresh_token_after_sha256
  )
  audit_readback = @(
    [string]$sensitiveHashes.provider_user_id_sha256,
    [string]$sensitiveHashes.subject_sha256
  )
}
$sourceRecordHashes = @()
foreach ($kind in @("browser", "d1_readback", "audit_readback")) {
  $artifact = $artifactByKind[$kind].artifact
  Assert-StringArrayExact $artifact.covered_steps $coveredByKind[$kind] "Sanitized $kind artifact covered_steps"
  $expectedRequests = @($coveredByKind[$kind] | ForEach-Object { [string]$stepByName[$_].request_correlation_sha256 })
  Assert-StringSetExact $artifact.request_correlation_sha256s $expectedRequests "Sanitized $kind artifact request correlations"
  $expectedSessions = @(
    $coveredByKind[$kind] |
      ForEach-Object { $stepByName[$_].session_correlation_sha256 } |
      Where-Object { $null -ne $_ } |
      Select-Object -Unique
  )
  Assert-StringSetExact $artifact.session_correlation_sha256s $expectedSessions `
    "Sanitized $kind artifact session correlations"
  Assert-StringSetExact $artifact.sensitive_value_sha256s $sensitiveByKind[$kind] `
    "Sanitized $kind artifact sensitive-value bindings"
  $observations = @($artifact.observations)
  Assert-True ($observations.Count -eq $coveredByKind[$kind].Count) `
    "Sanitized $kind artifact must contain one raw-derived observation per covered step."
  for ($observationIndex = 0; $observationIndex -lt $observations.Count; $observationIndex++) {
    $observation = $observations[$observationIndex]
    $stepName = [string]$coveredByKind[$kind][$observationIndex]
    $step = $stepByName[$stepName]
    $observationLabel = "Sanitized $kind observation[$observationIndex]"
    Assert-ExactPropertyNames $observation @(
      "sequence", "step", "http_status", "fact_codes", "request_correlation_sha256",
      "session_correlation_sha256", "source_record_sha256"
    ) $observationLabel
    Assert-True ([int]$observation.sequence -eq [int]$step.sequence) "$observationLabel sequence mismatch."
    Assert-True ([string]$observation.step -ceq $stepName) "$observationLabel step mismatch."
    Assert-True ([int]$observation.http_status -eq [int]$step.http_status) "$observationLabel HTTP status mismatch."
    Assert-StringArrayExact $observation.fact_codes $factCodesByKind[$kind][$stepName] `
      "$observationLabel fact codes"
    Assert-True ([string]$observation.request_correlation_sha256 -ceq [string]$step.request_correlation_sha256) `
      "$observationLabel request correlation mismatch."
    if ($null -eq $step.session_correlation_sha256) {
      Assert-True ($null -eq $observation.session_correlation_sha256) `
        "$observationLabel must not invent a session correlation."
    } else {
      Assert-True ([string]$observation.session_correlation_sha256 -ceq [string]$step.session_correlation_sha256) `
        "$observationLabel session correlation mismatch."
    }
    Assert-LowerSha256 ([string]$observation.source_record_sha256) "$observationLabel source-record binding"
    $sourceRecordHashes += [string]$observation.source_record_sha256
  }
}
Assert-True (@($sourceRecordHashes | Select-Object -Unique).Count -eq $sourceRecordHashes.Count) `
  "Every sanitized observation must bind a distinct raw-derived source record."
$expectedAuditEvents = @($auditContract | ForEach-Object { [string]$_.event } | Select-Object -Unique)
Assert-StringSetExact $artifactByKind["audit_readback"].artifact.audit_event_types $expectedAuditEvents `
  "Sanitized audit artifact event types"
Assert-StringArrayExact $artifactByKind["browser"].artifact.audit_event_types @() "Sanitized browser artifact event types"
Assert-StringArrayExact $artifactByKind["d1_readback"].artifact.audit_event_types @() "Sanitized D1 artifact event types"

$scorerOutputs = $flow.scorer_outputs
Assert-ExactPropertyNames $scorerOutputs @("browser", "d1_readback", "audit_readback") "Flow scorer_outputs"
$scorerByKind = @{}
$verifierImplementationSha = (Get-FileHash -LiteralPath $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash.ToLowerInvariant()
foreach ($kind in @("browser", "d1_readback", "audit_readback")) {
  $bindingEntry = $scorerOutputs.$kind
  Assert-ExactPropertyNames $bindingEntry @("ref", "sha256") "Flow $kind scorer binding"
  Assert-LowerSha256 ([string]$bindingEntry.sha256) "Flow $kind scorer hash"
  $scorerResolved = Resolve-TrackedCleanFile ([string]$bindingEntry.ref) "Sanitized $kind scorer output"
  Assert-FileHash $scorerResolved ([string]$bindingEntry.sha256) "Sanitized $kind scorer output"
  $scorerDocument = Read-JsonFile $scorerResolved "Sanitized $kind scorer output"
  $scorer = $scorerDocument.json
  Assert-NoSensitiveEvidence $scorer "Sanitized $kind scorer output"
  Assert-ExactPropertyNames $scorer @(
    "contract_version", "status", "scorer_kind", "candidate_source_commit_sha",
    "input_artifact_ref", "input_artifact_sha256", "scorer_implementation_ref",
    "scorer_implementation_sha256", "computed_fact_sha256", "record_count",
    "failed_record_count", "scored_at", "secret_value_count"
  ) "Sanitized $kind scorer output"
  Assert-True ([string]$scorer.contract_version -ceq "cloudflare-oauth-sanitized-scorer-output-v1") `
    "Sanitized scorer contract mismatch."
  Assert-True ([string]$scorer.status -ceq "computed") `
    "Sanitized scorer status must be computed, not a self-declared verified boolean."
  Assert-True ([string]$scorer.scorer_kind -ceq $kind) "Sanitized scorer kind mismatch."
  Assert-True ([string]$scorer.candidate_source_commit_sha -ceq $ExpectedCandidateSha) `
    "Sanitized scorer source SHA mismatch."
  Assert-True ([string]$scorer.input_artifact_ref -ceq [string]$artifactByKind[$kind].reference) `
    "Sanitized scorer input artifact ref mismatch."
  Assert-True ([string]$scorer.input_artifact_sha256 -ceq [string]$artifactByKind[$kind].hash) `
    "Sanitized scorer input artifact hash mismatch."
  Assert-True ([string]$scorer.scorer_implementation_ref -ceq "scripts/verify-cloudflare-oauth-hosted-current.ps1") `
    "Sanitized scorer implementation ref mismatch."
  Assert-True ([string]$scorer.scorer_implementation_sha256 -ceq $verifierImplementationSha) `
    "Sanitized scorer implementation hash mismatch."
  $computedObservationHash = Get-ObservationFactHash @($artifactByKind[$kind].artifact.observations)
  Assert-True ([string]$scorer.computed_fact_sha256 -ceq $computedObservationHash) `
    "Sanitized scorer computed fact hash mismatch."
  Assert-True ([int]$scorer.record_count -eq $coveredByKind[$kind].Count) `
    "Sanitized scorer record_count mismatch."
  Assert-True ([int]$scorer.failed_record_count -eq 0) "Sanitized scorer failed_record_count must be zero."
  Assert-True ([int]$scorer.secret_value_count -eq 0) "Sanitized scorer secret_value_count must be zero."
  $scoredAt = Assert-UtcTimestamp ([string]$scorer.scored_at) "Sanitized scorer scored_at"
  Assert-True ($scoredAt -ge $executionStartedAt -and $scoredAt -le $executionCompletedAt) `
    "Sanitized scorer timestamp must fall inside the approved execution window."
  $scorerByKind[$kind] = [pscustomobject]@{
    reference = [string]$bindingEntry.ref
    hash = [string]$bindingEntry.sha256
    scorer = $scorer
  }
}

$atomic = $flow.atomic_replay_evidence
Assert-ExactPropertyNames $atomic @(
  "rotation_serialization", "parallel_attempt_count", "successful_rotation_count", "rejected_rotation_count",
  "old_refresh_replay_http_status", "family_revocation_row_count", "replacement_refresh_rejection_count",
  "callback_state_consumption_count", "callback_replay_http_status", "callback_replay_credential_issue_count",
  "cancel_state_consumption_count", "d1_readback_match_count", "evidence_ref", "evidence_sha256",
  "scorer_ref", "scorer_sha256", "secret_value_count"
) "Atomic replay evidence"
Assert-True ([string]$atomic.rotation_serialization -ceq "durable_object_or_d1_transaction") `
  "Atomic replay evidence requires Durable Object serialization or one D1 transaction."
Assert-True ([int]$atomic.parallel_attempt_count -ge 2) "Atomic replay evidence requires at least two parallel attempts."
Assert-True ([int]$atomic.successful_rotation_count -eq 1) "Exactly one parallel refresh rotation may succeed."
Assert-True ([int]$atomic.rejected_rotation_count -eq ([int]$atomic.parallel_attempt_count - 1)) `
  "Every other parallel refresh rotation must be rejected."
Assert-True ([int]$atomic.old_refresh_replay_http_status -eq 401) "Old refresh replay must return HTTP 401."
Assert-True ([int]$atomic.callback_replay_http_status -eq 401) "Callback replay must return HTTP 401."
foreach ($field in @(
  "family_revocation_row_count", "replacement_refresh_rejection_count",
  "callback_state_consumption_count", "cancel_state_consumption_count"
)) { Assert-True ([int]$atomic.$field -eq 1) "Atomic replay evidence $field must equal one." }
Assert-True ([int]$atomic.callback_replay_credential_issue_count -eq 0) `
  "Atomic replay evidence callback_replay_credential_issue_count must be zero."
Assert-True ([int]$atomic.d1_readback_match_count -eq $d1Covered.Count) `
  "Atomic replay evidence d1_readback_match_count mismatch."
Assert-True ([int]$atomic.secret_value_count -eq 0) "Atomic replay evidence secret_value_count must be zero."
Assert-True ([string]$atomic.evidence_ref -ceq [string]$artifactByKind["d1_readback"].reference) `
  "Atomic replay evidence must bind the canonical D1-readback artifact."
Assert-True ([string]$atomic.evidence_sha256 -ceq [string]$artifactByKind["d1_readback"].hash) `
  "Atomic replay evidence hash mismatch."
Assert-True ([string]$atomic.scorer_ref -ceq [string]$scorerByKind["d1_readback"].reference) `
  "Atomic replay evidence must bind the D1 scorer output."
Assert-True ([string]$atomic.scorer_sha256 -ceq [string]$scorerByKind["d1_readback"].hash) `
  "Atomic replay scorer hash mismatch."

$correlations = @($flow.audit_correlations)
Assert-True ($correlations.Count -eq $auditContract.Count) "Audit evidence must contain exactly six canonical correlations."
$auditEventHashes = @()
for ($index = 0; $index -lt $auditContract.Count; $index++) {
  $correlation = $correlations[$index]
  $expected = $auditContract[$index]
  $step = $stepByName[[string]$expected.step]
  $label = "audit_correlations[$index]"
  Assert-ExactPropertyNames $correlation @(
    "step", "event_type", "request_correlation_sha256", "session_correlation_sha256", "audit_event_id_sha256",
    "persisted_row_count", "d1_readback_match_count", "persisted_sequence", "credential_boundary_sequence",
    "evidence_ref", "evidence_sha256", "scorer_ref", "scorer_sha256",
    "sensitive_field_count", "secret_value_count"
  ) $label
  Assert-True ([string]$correlation.step -ceq [string]$expected.step) "$label step mismatch."
  Assert-True ([string]$correlation.event_type -ceq [string]$expected.event) "$label event type mismatch."
  Assert-LowerSha256 ([string]$correlation.audit_event_id_sha256) "$label audit-event identity binding"
  $auditEventHashes += [string]$correlation.audit_event_id_sha256
  Assert-True ([string]$correlation.request_correlation_sha256 -ceq [string]$step.request_correlation_sha256) `
    "$label request correlation mismatch."
  if ($null -eq $step.session_correlation_sha256) {
    Assert-True ($null -eq $correlation.session_correlation_sha256) "$label must not invent a session correlation."
  } else {
    Assert-True ([string]$correlation.session_correlation_sha256 -ceq [string]$step.session_correlation_sha256) `
      "$label session correlation mismatch."
  }
  Assert-True ([int]$correlation.persisted_row_count -eq 1) "$label persisted_row_count must equal one."
  Assert-True ([int]$correlation.d1_readback_match_count -eq 1) "$label d1_readback_match_count must equal one."
  Assert-True ([int]$correlation.persisted_sequence -eq 1) "$label persisted_sequence must equal one."
  Assert-True ([int]$correlation.credential_boundary_sequence -eq 2) `
    "$label credential_boundary_sequence must follow persistence."
  Assert-True ([int]$correlation.sensitive_field_count -eq 0) "$label sensitive_field_count must be zero."
  Assert-True ([int]$correlation.secret_value_count -eq 0) "$label secret_value_count must be zero."
  Assert-True ([string]$correlation.evidence_ref -ceq [string]$artifactByKind["audit_readback"].reference) `
    "$label must bind the canonical audit-readback artifact."
  Assert-True ([string]$correlation.evidence_sha256 -ceq [string]$artifactByKind["audit_readback"].hash) `
    "$label audit evidence hash mismatch."
  Assert-True ([string]$correlation.scorer_ref -ceq [string]$scorerByKind["audit_readback"].reference) `
    "$label must bind the audit scorer output."
  Assert-True ([string]$correlation.scorer_sha256 -ceq [string]$scorerByKind["audit_readback"].hash) `
    "$label audit scorer hash mismatch."
}
Assert-True (@($auditEventHashes | Select-Object -Unique).Count -eq $auditContract.Count) `
  "Every audit correlation requires a distinct SHA256-only audit-event identity."

$redaction = $flow.redaction
Assert-ExactPropertyNames $redaction @(
  "identity_representation", "sensitive_key_count", "sensitive_value_count",
  "artifact_scan_count", "log_scan_finding_count", "secret_scan_finding_count"
) "Flow redaction"
Assert-True ([string]$redaction.identity_representation -ceq "sha256_only") `
  "Flow redaction identity representation must be sha256_only."
Assert-True ([int]$redaction.sensitive_key_count -eq 0) "Flow redaction sensitive_key_count must be zero."
Assert-True ([int]$redaction.sensitive_value_count -eq 0) "Flow redaction sensitive_value_count must be zero."
Assert-True ([int]$redaction.artifact_scan_count -eq 3) "Flow redaction artifact_scan_count must equal three."
Assert-True ([int]$redaction.log_scan_finding_count -eq 0) "Flow redaction log_scan_finding_count must be zero."
Assert-True ([int]$redaction.secret_scan_finding_count -eq 0) "Flow redaction secret_scan_finding_count must be zero."

$gate = $flow.gate_transition
Assert-ExactPropertyNames $gate @(
  "verifier_mutation_count", "gate_promotion_count", "live_verified_mutation_count",
  "percentage_change_count", "production_release_count"
) "Flow gate_transition"
foreach ($field in @(
  "verifier_mutation_count", "gate_promotion_count", "live_verified_mutation_count",
  "percentage_change_count", "production_release_count"
)) {
  Assert-True ([int]$gate.$field -eq 0) "Flow gate_transition $field must be zero."
}
Assert-StringArrayExact $flow.non_claims @(
  "no_gate_promotion", "no_live_verified_mutation", "no_provider_writes", "no_deployment_writes", "no_secret_output",
  "evidence_envelope_not_full_live_replay", "no_production_release"
) "Flow non_claims"

if ($Hosted) {
  foreach ($item in @(
    @{ value = $HostedBaseUrl; label = "HostedBaseUrl" },
    @{ value = $FrontendEvidencePath; label = "FrontendEvidencePath" },
    @{ value = $OwnerApprovalPath; label = "OwnerApprovalPath" },
    @{ value = $LiveConsentApprovalPath; label = "LiveConsentApprovalPath" },
    @{ value = $FrontendDeploymentId; label = "FrontendDeploymentId" },
    @{ value = $WorkerDeploymentId; label = "WorkerDeploymentId" }
  )) { Assert-True (-not [string]::IsNullOrWhiteSpace([string]$item.value)) "Hosted mode requires explicit $($item.label)." }

  $hostedOrigin = Assert-NonLocalHttpsOrigin $HostedBaseUrl "HostedBaseUrl" ".workers.dev"
  Assert-True ($hostedOrigin -ceq $boundWorkerOrigin) "HostedBaseUrl does not match the approved Worker origin."
  Assert-True ((ConvertTo-RepoRelative $FrontendEvidencePath).relative -ceq $canonicalFrontendEvidence) `
    "Hosted FrontendEvidencePath does not match the approved evidence."
  Assert-True ((ConvertTo-RepoRelative $OwnerApprovalPath).relative -ceq $canonicalOwnerApproval) `
    "Hosted OwnerApprovalPath does not match the approved decision."
  Assert-True ((ConvertTo-RepoRelative $LiveConsentApprovalPath).relative -ceq $canonicalConsentApproval) `
    "Hosted LiveConsentApprovalPath does not match the approved consent."
  Assert-True ((Get-StringSha256 $FrontendDeploymentId) -ceq [string]$binding.frontend_deployment_id_sha256) `
    "Explicit frontend deployment id does not match its approved hash binding."
  Assert-True ((Get-StringSha256 $WorkerDeploymentId) -ceq [string]$binding.worker_deployment_id_sha256) `
    "Explicit Worker deployment id does not match its approved hash binding."

  $healthResponse = Get-ReadOnlyHttp "$hostedOrigin/api/v1/health"
  Assert-True ($healthResponse.status -eq 200) "Hosted health must return HTTP 200."
  try { $health = $healthResponse.content | ConvertFrom-Json } catch { throw "Hosted health must return JSON." }
  Assert-True ([string]$health.source_commit_sha -ceq $ExpectedCandidateSha) "Hosted Worker source SHA mismatch."
  Assert-True ([string]$health.source_archive_sha256 -ceq [string]$binding.worker_source_archive_sha256) `
    "Hosted Worker archive SHA-256 mismatch."
  Assert-True ($health.d1_read_verified -is [bool] -and [bool]$health.d1_read_verified) "Hosted Worker D1 readback is not verified."

  $contractResponse = Get-ReadOnlyHttp "$hostedOrigin/api/v1/auth/contract"
  Assert-True ($contractResponse.status -eq 200) "Hosted auth contract must return HTTP 200."
  try { $contract = $contractResponse.content | ConvertFrom-Json } catch { throw "Hosted auth contract must return JSON." }
  Assert-True ([string]$contract.contract_version -ceq "auth-github-jwt-refresh-v1") "Hosted auth contract version mismatch."
  Assert-True ([string]$contract.mode -ceq "verified_identity_fail_closed") "Hosted auth contract mode mismatch."
  foreach ($field in @("github_oauth_configured", "credentials_configured", "owner_activation_granted", "credential_issuance_ready")) {
    Assert-True ($contract.$field -is [bool] -and [bool]$contract.$field) "Hosted auth contract '$field' must be true."
  }
  Assert-True ($contract.live_github_oauth_call -is [bool] -and -not [bool]$contract.live_github_oauth_call) `
    "Read-only auth contract must not claim a live provider call."
  Assert-True ([string]$contract.refresh_token.storage -ceq "hash_only_d1") "Hosted refresh storage contract mismatch."
  Assert-True ([string]$contract.refresh_token.rotation -ceq "atomic") "Hosted refresh rotation contract mismatch."
  Assert-True ([string]$contract.cookie_flags.oauth_state -ceq "__Host-sb_oauth_state; Path=/; Max-Age=600; Secure; HttpOnly; SameSite=Lax") `
    "Hosted OAuth-state cookie policy mismatch."
  Assert-True ([string]$contract.cookie_flags.access -ceq "__Host-sb_access; Path=/; Max-Age=900; Secure; HttpOnly; SameSite=Strict") `
    "Hosted access cookie policy mismatch."
  Assert-True ([string]$contract.cookie_flags.refresh -ceq "__Host-sb_refresh; Path=/; Max-Age=604800; Secure; HttpOnly; SameSite=Strict") `
    "Hosted refresh cookie policy mismatch."

  Write-Host "[production-auth-runtime] status=verified architecture=cloudflare_native validation_mode=false hosted_mode=true read_only=true source_parity=true proof_scope=production_identity exact_human_flow_steps=12 atomic_replay_evidence=scored audit_correlation_evidence=scored hosted_binding_readback=true provider_writes=false deployment_writes=false full_live_proof=false production_release=false gate_promotion_performed=false live_verified_set=false secret_output=false"
  exit 0
}

Write-Host "[production-auth-runtime] status=verified architecture=cloudflare_native validation_mode=true hosted_mode=false read_only=true source_parity=true proof_scope=production_identity exact_human_flow_steps=12 atomic_replay_evidence=scored audit_correlation_evidence=scored hosted_binding_readback=false provider_writes=false deployment_writes=false full_live_proof=false production_release=false gate_promotion_performed=false live_verified_set=false secret_output=false"

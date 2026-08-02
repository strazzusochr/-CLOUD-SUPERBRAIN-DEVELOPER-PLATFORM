<#
  Executes the pre-declared zero-card Phase-6 scale criterion.

  Safety invariants:
    - missing write authorization stops before the first HTTP request;
    - the requested origin must equal both the criterion and hosted-state origin;
    - exactly 800 Worker health reads + 50 creates + 50 cleanup deletes are issued;
    - every successful create is the response of the Worker's post-insert D1 SELECT;
    - evidence is immutable and never contains the write token;
    - this verifier records evidence only; it cannot promote a gate or award credit.
#>
[CmdletBinding()]
param(
  [string]$CriterionPath,
  [string]$HostedStatePath,
  [string]$BaseUrl,
  [switch]$AllowHostedWrites
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$canonicalCriterionPath = Join-Path $repoRoot "docs\runtime-state\phase6-scale-criterion.json"
$canonicalHostedStatePath = Join-Path $repoRoot "docs\runtime-state\cloudflare-native-hosted-current.json"
$capabilityGatesPath = Join-Path $repoRoot "docs\runtime-state\capability-gates.json"
$expectedCriterionSha256 = "edeeac95fac6fefe1dcde5b77a5d8b236685f28adf66f357706aed26971ed85f"
if (-not $CriterionPath) { $CriterionPath = $canonicalCriterionPath }
if (-not $HostedStatePath) { $HostedStatePath = $canonicalHostedStatePath }

function Fail([string]$Message) {
  Write-Host "[phase6-scale] FAIL: $Message"
  exit 1
}

function Blocked([string]$Message) {
  Write-Host "[phase6-scale] BLOCKED: $Message"
  exit 2
}

function Require([bool]$Condition, [string]$Message) {
  if (-not $Condition) { Fail $Message }
}

function Normalize-BaseUrl([string]$Value) {
  $candidate = $Value.Trim().TrimEnd('/')
  $uri = $null
  if (-not [Uri]::TryCreate($candidate, [UriKind]::Absolute, [ref]$uri)) {
    Fail "base url is not an absolute URI"
  }
  if ($uri.Scheme -ne "https" -or -not [string]::IsNullOrEmpty($uri.UserInfo) -or
      $uri.AbsolutePath -ne "/" -or -not [string]::IsNullOrEmpty($uri.Query) -or
      -not [string]::IsNullOrEmpty($uri.Fragment)) {
    Fail "base url must be an HTTPS origin without credentials, path, query, or fragment"
  }
  return $candidate
}

function Get-StringSha256([string]$Value) {
  $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join "")
  } finally {
    $sha.Dispose()
  }
}

function Get-Percentile([double[]]$Values, [double]$Percentile) {
  if ($Values.Count -eq 0) { return 0.0 }
  foreach ($value in $Values) {
    Require (-not [double]::IsNaN($value) -and -not [double]::IsInfinity($value) -and $value -ge 0.0) "latency samples must be finite and non-negative"
  }
  $sorted = @($Values | Sort-Object)
  $index = [Math]::Ceiling($Percentile * $sorted.Count) - 1
  if ($index -lt 0) { $index = 0 }
  if ($index -ge $sorted.Count) { $index = $sorted.Count - 1 }
  return [Math]::Round([double]$sorted[$index], 1)
}

function ConvertFrom-JsonSafe([string]$Value) {
  try {
    return ($Value | ConvertFrom-Json -ErrorAction Stop)
  } catch {
    return $null
  }
}

function Has-Property($Value, [string]$Name) {
  return ($null -ne $Value -and $null -ne $Value.PSObject.Properties[$Name])
}

function Get-OptionalStringProperty($Value, [string]$Name) {
  if (Has-Property $Value $Name) { return [string]$Value.$Name }
  return ""
}

function Get-NonNegativeInteger($Value, [string]$Label) {
  Require ($null -ne $Value -and $Value -isnot [bool]) "$Label must be a non-negative integer"
  $text = [Convert]::ToString($Value, [Globalization.CultureInfo]::InvariantCulture)
  Require ($text -match '^(?:0|[1-9][0-9]*)$') "$Label must be a non-negative integer"
  $parsed = 0L
  Require ([Int64]::TryParse($text, [Globalization.NumberStyles]::None, [Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)) "$Label is outside the Int64 range"
  return $parsed
}

function Get-StrictUtcTimestamp($Value, [string]$Label) {
  $text = [string]$Value
  Require ($text -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?Z$') "$Label must be an explicit UTC timestamp"
  $parsed = [DateTimeOffset]::MinValue
  Require ([DateTimeOffset]::TryParse(
    $text,
    [Globalization.CultureInfo]::InvariantCulture,
    [Globalization.DateTimeStyles]::AssumeUniversal,
    [ref]$parsed
  )) "$Label is invalid"
  Require ($parsed.Offset -eq [TimeSpan]::Zero) "$Label must use UTC"
  return $parsed.ToUniversalTime()
}

function Get-RequiredEnvironment([string]$Name) {
  $value = [Environment]::GetEnvironmentVariable($Name)
  Require (-not [string]::IsNullOrWhiteSpace($value)) "trusted GitHub Actions context is missing $Name"
  return $value.Trim()
}

function Require-BoundedText([string]$Value, [int]$MaximumLength, [string]$Label) {
  Require (-not [string]::IsNullOrWhiteSpace($Value) -and $Value.Length -le $MaximumLength) "$Label is empty or too long"
  Require ($Value -notmatch '[\x00-\x1f\x7f]') "$Label contains control characters"
}

function Assert-TrackedHeadBytes([string]$RelativePath, [string]$Label, [string]$HeadSha) {
  Require (-not [IO.Path]::IsPathRooted($RelativePath)) "$Label must use a repository-relative path"
  $normalized = $RelativePath.Replace('\', '/')
  Require ($normalized -notmatch '(^|/)\.\.(/|$)') "$Label escapes the repository"
  & git.exe -C $repoRoot ls-files --error-unmatch -- $normalized 2>$null | Out-Null
  Require ($LASTEXITCODE -eq 0) "$Label is not tracked"
  & git.exe -C $repoRoot diff --quiet HEAD -- $normalized
  Require ($LASTEXITCODE -eq 0) "$Label has uncommitted changes"
  & git.exe -C $repoRoot cat-file -e "${HeadSha}:$normalized" 2>$null
  Require ($LASTEXITCODE -eq 0) "$Label did not exist at the execution HEAD"
}

function Resolve-RepoScopedPath([string]$Candidate, [string]$Label) {
  Require (-not [string]::IsNullOrWhiteSpace($Candidate)) "$Label path is empty"
  $resolved = if ([IO.Path]::IsPathRooted($Candidate)) {
    [IO.Path]::GetFullPath($Candidate)
  } else {
    [IO.Path]::GetFullPath((Join-Path $repoRoot $Candidate))
  }
  $root = [IO.Path]::GetFullPath($repoRoot).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  Require ($resolved.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) "$Label path must stay inside the repository"
  Require (Test-Path -LiteralPath $resolved -PathType Leaf) "$Label is missing"
  return $resolved
}

function Get-GitArchiveSha256([string]$CommitSha) {
  $temporaryPath = [IO.Path]::Combine([IO.Path]::GetTempPath(), "phase6-scale-source-$([Guid]::NewGuid().ToString('N')).tar")
  try {
    & git.exe -C $repoRoot cat-file -e "$CommitSha^{commit}" 2>$null
    Require ($LASTEXITCODE -eq 0) "hosted source commit is unavailable in local Git"
    & git.exe -C $repoRoot archive --format=tar "--output=$temporaryPath" $CommitSha
    Require ($LASTEXITCODE -eq 0) "unable to create the hosted source archive"
    return (Get-FileHash -LiteralPath $temporaryPath -Algorithm SHA256).Hash.ToLowerInvariant()
  } finally {
    if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
      Remove-Item -LiteralPath $temporaryPath -Force
    }
  }
}

if (-not (Test-Path -LiteralPath $CriterionPath -PathType Leaf)) {
  Fail "criterion file missing: $CriterionPath"
}
if (-not (Test-Path -LiteralPath $HostedStatePath -PathType Leaf)) {
  Fail "hosted state file missing: $HostedStatePath"
}
if (-not (Test-Path -LiteralPath $capabilityGatesPath -PathType Leaf)) {
  Fail "capability gate file missing: $capabilityGatesPath"
}
$resolvedCriterionPath = (Resolve-Path -LiteralPath $CriterionPath).Path
$resolvedHostedStatePath = (Resolve-Path -LiteralPath $HostedStatePath).Path
Require ($resolvedCriterionPath -eq (Resolve-Path -LiteralPath $canonicalCriterionPath).Path) "caller-supplied criterion files are forbidden for a hosted write run"
Require ($resolvedHostedStatePath -eq (Resolve-Path -LiteralPath $canonicalHostedStatePath).Path) "caller-supplied hosted-state files are forbidden for a hosted write run"
foreach ($trackedTruthRelativePath in @(
  "docs/runtime-state/phase6-scale-criterion.json",
  "docs/runtime-state/cloudflare-native-hosted-current.json",
  "docs/runtime-state/capability-gates.json"
)) {
  & git.exe -C $repoRoot ls-files --error-unmatch -- $trackedTruthRelativePath 2>$null | Out-Null
  Require ($LASTEXITCODE -eq 0) "runtime truth file is not tracked: $trackedTruthRelativePath"
  & git.exe -C $repoRoot diff --quiet HEAD -- $trackedTruthRelativePath
  Require ($LASTEXITCODE -eq 0) "runtime truth file has uncommitted changes: $trackedTruthRelativePath"
}
$actualCriterionSha256 = (Get-FileHash -LiteralPath $CriterionPath -Algorithm SHA256).Hash.ToLowerInvariant()
Require ($actualCriterionSha256 -eq $expectedCriterionSha256) "criterion bytes differ from the pre-declared locked criterion"

$criterion = Get-Content -LiteralPath $CriterionPath -Raw | ConvertFrom-Json
$hostedState = Get-Content -LiteralPath $HostedStatePath -Raw | ConvertFrom-Json
$capabilityGates = Get-Content -LiteralPath $capabilityGatesPath -Raw | ConvertFrom-Json

Require ([string]$criterion.contract_version -eq "phase6-scale-criterion-v2") "unexpected criterion contract_version"
Require ([bool]$criterion.declared_before_first_run) "criterion was not declared before the first run"
Require ([bool]$criterion.declared_before_first_full_write_run) "criterion v2 was not declared before the first full write run"
Require ([bool]$criterion.envelope.zero_card) "criterion is not zero-card"
Require ([bool]$criterion.envelope.payment_forbidden) "criterion does not forbid payment"
Require ([bool]$criterion.envelope.paid_fallback_forbidden) "criterion does not forbid paid fallback"
Require ([string]$hostedState.contract_version -eq "cloudflare-native-hosted-current-v1") "unexpected hosted-state contract_version"
Require ([string]$hostedState.status -eq "verified") "hosted state is not verified"
Require ([bool]$hostedState.hosted_proof -and -not [bool]$hostedState.dev_only) "hosted state is not a non-DEV hosted proof"
Require ([string]$hostedState.source_commit_sha -match '^[0-9a-f]{40}$') "hosted source commit SHA is invalid"
Require ([string]$hostedState.source_archive_sha256 -match '^[0-9a-f]{64}$') "hosted source archive SHA-256 is invalid"
Require ([string]$capabilityGates.contract_version -eq "capability-gate-state-v1") "unexpected capability-gate contract_version"
$scaleGate = $capabilityGates.gates.phase6_scale_runtime
if ($null -eq $scaleGate -or $scaleGate.owner_granted -ne $true -or [string]::IsNullOrWhiteSpace([string]$scaleGate.owner_grant_ref)) {
  Blocked "phase6_scale_runtime has no recorded Owner grant; zero HTTP requests issued"
}
Require ($scaleGate.paid_provider -ne $true) "phase6 scale gate declares a paid provider"

$criterionBaseUrl = Normalize-BaseUrl ([string]$criterion.target.base_url)
$hostedBaseUrl = Normalize-BaseUrl ([string]$hostedState.base_url)
Require ($criterionBaseUrl -eq $hostedBaseUrl) "criterion and hosted state do not bind the same origin"
if (-not $BaseUrl) { $BaseUrl = $criterionBaseUrl }
$BaseUrl = Normalize-BaseUrl $BaseUrl
Require ($BaseUrl -eq $criterionBaseUrl -and $BaseUrl -eq $hostedBaseUrl) "requested base url is not bound to criterion and hosted state"

$declaredReadTiers = @($criterion.read_tiers)
Require ($declaredReadTiers.Count -eq 3) "criterion must declare exactly three read tiers"
$lockedReadTiers = @(
  @{ concurrency = 1; requests = 60 },
  @{ concurrency = 10; requests = 240 },
  @{ concurrency = 50; requests = 500 }
)
for ($tierIndex = 0; $tierIndex -lt $lockedReadTiers.Count; $tierIndex++) {
  $declaredConcurrency = Get-NonNegativeInteger $declaredReadTiers[$tierIndex].concurrency "criterion read tier $tierIndex concurrency"
  $declaredRequests = Get-NonNegativeInteger $declaredReadTiers[$tierIndex].requests "criterion read tier $tierIndex requests"
  Require (
    $declaredConcurrency -eq [int]$lockedReadTiers[$tierIndex].concurrency -and
    $declaredRequests -eq [int]$lockedReadTiers[$tierIndex].requests
  ) "criterion read tier $tierIndex differs from the pre-declared 60@c1, 240@c10, 500@c50 plan"
}
$readExpected = [int](($lockedReadTiers | Measure-Object -Property requests -Sum).Sum)
$writeExpected = [int](Get-NonNegativeInteger $criterion.write_tier.records "criterion write record count")
$writeConcurrency = [int](Get-NonNegativeInteger $criterion.write_tier.concurrency "criterion write concurrency")
$maxWorkerRequests = [int](Get-NonNegativeInteger $criterion.envelope.max_total_requests "criterion Worker request cap")
Require ($readExpected -eq 800) "criterion must declare exactly 800 Worker reads"
Require ($writeExpected -eq 50) "criterion must declare exactly 50 write records"
Require ($writeConcurrency -eq 10) "criterion write concurrency must be exactly 10"
Require ($maxWorkerRequests -eq 900) "criterion Worker request cap must be exactly 900"
Require (($readExpected + (2 * $writeExpected)) -eq $maxWorkerRequests) "read/create/delete request plan does not exactly fill the Worker cap"
Require ([bool]$criterion.write_tier.required) "write tier is not required"
Require ([bool]$criterion.write_tier.readback_required) "write tier does not require readback"
Require ([bool]$criterion.write_tier.no_loss_allowed) "write tier permits record loss"
Require ([bool]$criterion.write_tier.no_duplicate_allowed) "write tier permits duplicate records"
Require ($criterion.write_tier.http_429_allowed -eq $false) "criterion permits throttled writes"
Require ([string]$criterion.write_tier.cleanup_semantics -eq "soft_delete_then_active_row_absence_and_audit_readback") "criterion cleanup semantics changed"
Require ([string]$criterion.control_tier.path -eq "/cdn-cgi/trace") "criterion control path changed"
$maxControlRequests = [int](Get-NonNegativeInteger $criterion.control_tier.max_control_requests "criterion control request cap")
Require ($maxControlRequests -eq 500) "criterion control request cap changed"
Require ([double]$criterion.pass_criteria.min_success_ratio -eq 0.99) "criterion success threshold changed"
Require ([double]$criterion.pass_criteria.max_p95_ms -eq 1500) "criterion p95 threshold changed"
$own5xxAllowed = [int](Get-NonNegativeInteger $criterion.pass_criteria.own_5xx_allowed "criterion 5xx allowance")
Require ($own5xxAllowed -eq 0) "criterion 5xx allowance changed"
Require ([bool]$criterion.pass_criteria.throttle_must_fail_closed) "criterion no longer requires fail-closed throttling"
Require ([string]$criterion.pass_criteria.http_429_scope -eq "health_read_tiers_only") "criterion 429 scope changed"
Require ([bool]$criterion.fail_closed.missing_write_auth_is_failure) "criterion no longer fails on missing write authentication"

$hostedEvidenceRelativePath = [string]$hostedState.evidence_artifact
$hostedEvidencePath = Resolve-RepoScopedPath $hostedEvidenceRelativePath "hosted deployment evidence"
& git.exe -C $repoRoot ls-files --error-unmatch -- $hostedEvidenceRelativePath 2>$null | Out-Null
Require ($LASTEXITCODE -eq 0) "hosted deployment evidence is not tracked and immutable"
& git.exe -C $repoRoot diff --quiet HEAD -- $hostedEvidenceRelativePath
Require ($LASTEXITCODE -eq 0) "hosted deployment evidence has uncommitted changes"
$hostedEvidenceSha256 = (Get-FileHash -LiteralPath $hostedEvidencePath -Algorithm SHA256).Hash.ToLowerInvariant()
Require ($hostedEvidenceSha256 -eq ([string]$hostedState.evidence_sha256).ToLowerInvariant()) "hosted deployment evidence SHA-256 mismatch"
$hostedEvidence = Get-Content -LiteralPath $hostedEvidencePath -Raw | ConvertFrom-Json
Require ([string]$hostedEvidence.contract_version -eq "cloudflare-d1-stateful-runtime-hosted-proof-v2") "hosted deployment evidence must be rebound with the v2 immutable deployment contract"
Require ([string]$hostedEvidence.base_url -eq [string]$hostedState.base_url) "hosted deployment evidence base URL mismatch"
Require ([string]$hostedEvidence.source_commit_sha -match '^[0-9a-f]{40}$' -and [string]$hostedEvidence.source_commit_sha -ceq [string]$hostedState.source_commit_sha) "hosted deployment evidence source commit mismatch"
Require ([string]$hostedEvidence.source_archive_sha256 -match '^[0-9a-f]{64}$' -and [string]$hostedEvidence.source_archive_sha256 -ceq [string]$hostedState.source_archive_sha256) "hosted deployment evidence source archive mismatch"
Require ([string]$hostedEvidence.worker_version_id -match '^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$') "hosted deployment evidence Worker version ID is invalid"
Require ([string]$hostedEvidence.deployment_id -match '^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$') "hosted deployment evidence deployment ID is invalid"
Require ($hostedEvidence.source_binding_verified -eq $true -and $hostedEvidence.hosted_write_read_delete_verified -eq $true) "hosted deployment evidence lacks source-bound runtime proof"
Require ($hostedEvidence.dev_only -eq $false -and $hostedEvidence.secret_output -eq $false) "hosted deployment evidence is DEV-only or exposes secret output"
Require ((Get-GitArchiveSha256 ([string]$hostedState.source_commit_sha)) -ceq [string]$hostedState.source_archive_sha256) "hosted source archive does not match the declared Git commit"

$repositoryHeadSha = [string](& git.exe -C $repoRoot rev-parse HEAD)
$repositoryHeadSha = $repositoryHeadSha.Trim()
Require ($repositoryHeadSha -match '^[0-9a-f]{40}$') "repository HEAD SHA is invalid"
& git.exe -C $repoRoot merge-base --is-ancestor ([string]$hostedState.source_commit_sha) $repositoryHeadSha
Require ($LASTEXITCODE -eq 0) "deployed source commit is not an ancestor of the execution control HEAD"

$verifierRelativePath = "scripts/verify-phase6-scale-runtime.ps1"
Assert-TrackedHeadBytes "docs/runtime-state/phase6-scale-criterion.json" "scale criterion" $repositoryHeadSha
Assert-TrackedHeadBytes "docs/runtime-state/cloudflare-native-hosted-current.json" "hosted state" $repositoryHeadSha
Assert-TrackedHeadBytes "docs/runtime-state/capability-gates.json" "capability state" $repositoryHeadSha
Assert-TrackedHeadBytes $hostedEvidenceRelativePath "hosted deployment evidence" $repositoryHeadSha
Assert-TrackedHeadBytes $verifierRelativePath "runtime verifier" $repositoryHeadSha

$criterionDeclaredAt = Get-StrictUtcTimestamp $criterion.declared_at_utc "criterion declaration timestamp"
$hostedVerifiedAt = Get-StrictUtcTimestamp $hostedState.verified_at_utc "hosted-state verification timestamp"
$deploymentTimestampProperties = @("verified_at_utc", "checked_at") | Where-Object { Has-Property $hostedEvidence $_ }
Require ($deploymentTimestampProperties.Count -eq 1) "hosted deployment evidence must expose exactly one verification timestamp"
$deploymentCheckedAt = Get-StrictUtcTimestamp $hostedEvidence.($deploymentTimestampProperties[0]) "hosted deployment evidence timestamp"
$preflightNow = [DateTimeOffset](Get-Date).ToUniversalTime()
$allowedClockSkew = [TimeSpan]::FromMinutes(5)
$maximumDeploymentAge = [TimeSpan]::FromHours(24)
Require ($deploymentCheckedAt -ge $criterionDeclaredAt) "hosted deployment evidence predates the locked scale criterion"
Require ($deploymentCheckedAt -eq $hostedVerifiedAt) "hosted state and deployment evidence timestamps are not identical"
Require ($hostedVerifiedAt -le ($preflightNow + $allowedClockSkew)) "hosted deployment evidence is future-dated"
Require (($preflightNow - $hostedVerifiedAt) -le $maximumDeploymentAge) "hosted deployment evidence is stale"

# The execution itself must happen in a GitHub-hosted workflow context. This is
# only provisional provenance: the completed run and uploaded evidence pair are
# independently rebound from the GitHub API after the run finishes.
Require ((Get-RequiredEnvironment "GITHUB_ACTIONS") -ceq "true") "phase6 scale execution requires GitHub Actions"
$githubRepository = Get-RequiredEnvironment "GITHUB_REPOSITORY"
Require ($githubRepository -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') "GITHUB_REPOSITORY is invalid"
$githubRunId = Get-NonNegativeInteger (Get-RequiredEnvironment "GITHUB_RUN_ID") "GITHUB_RUN_ID"
Require ($githubRunId -gt 0) "GITHUB_RUN_ID must be positive"
$githubRunAttempt = Get-NonNegativeInteger (Get-RequiredEnvironment "GITHUB_RUN_ATTEMPT") "GITHUB_RUN_ATTEMPT"
Require ($githubRunAttempt -gt 0 -and $githubRunAttempt -le [int]::MaxValue) "GITHUB_RUN_ATTEMPT is invalid"
$githubSha = (Get-RequiredEnvironment "GITHUB_SHA").ToLowerInvariant()
Require ($githubSha -match '^[0-9a-f]{40}$' -and $githubSha -ceq $repositoryHeadSha) "GitHub execution SHA is not the exact repository HEAD"
$githubRef = Get-RequiredEnvironment "GITHUB_REF"
Require ($githubRef -match '^refs/heads/[^\s]+$') "phase6 scale execution requires a branch ref"
$githubEventName = Get-RequiredEnvironment "GITHUB_EVENT_NAME"
Require ($githubEventName -ceq "workflow_dispatch") "phase6 scale execution requires an explicit workflow_dispatch"
$githubWorkflow = Get-RequiredEnvironment "GITHUB_WORKFLOW"
$githubWorkflowRef = Get-RequiredEnvironment "GITHUB_WORKFLOW_REF"
Require-BoundedText $githubWorkflow 256 "GITHUB_WORKFLOW"
Require-BoundedText $githubWorkflowRef 512 "GITHUB_WORKFLOW_REF"
Require ($githubWorkflowRef.StartsWith("$githubRepository/.github/workflows/", [StringComparison]::Ordinal) -and $githubWorkflowRef.Contains("@")) "GITHUB_WORKFLOW_REF is not repository-bound"
$workflowSeparator = $githubWorkflowRef.LastIndexOf("@", [StringComparison]::Ordinal)
Require ($workflowSeparator -gt $githubRepository.Length) "GITHUB_WORKFLOW_REF does not contain an exact workflow path"
$githubWorkflowPath = $githubWorkflowRef.Substring($githubRepository.Length + 1, $workflowSeparator - $githubRepository.Length - 1).Replace('\', '/')
Require ($githubWorkflowPath -match '^\.github/workflows/phase6-scale-runtime\.ya?ml$') "phase6 scale execution used an unexpected workflow path"
$githubJob = Get-RequiredEnvironment "GITHUB_JOB"
Require ($githubJob -match '^[A-Za-z0-9_.-]{1,128}$') "GITHUB_JOB is invalid"
$githubServerUrl = Get-RequiredEnvironment "GITHUB_SERVER_URL"
Require ($githubServerUrl -ceq "https://github.com") "GITHUB_SERVER_URL is not the trusted GitHub origin"
$githubRunUrl = "$githubServerUrl/$githubRepository/actions/runs/$githubRunId"
$githubArtifactName = "phase6-scale-execution-evidence-$githubRunId-$githubRunAttempt"

$allowedControlDelta = @(
  $githubWorkflowPath,
  "docs/runtime-state/phase6-scale-criterion.json",
  "docs/runtime-state/cloudflare-native-hosted-current.json",
  "docs/runtime-state/capability-gates.json",
  $hostedEvidenceRelativePath.Replace('\', '/'),
  "scripts/verify-phase6-scale-runtime.ps1",
  "scripts/verify-phase6-scale-runtime-static.ps1",
  "scripts/verify-phase6-scale-evidence.ps1",
  "scripts/verify-phase6-scale-evidence-static.ps1",
  "scripts/collect-phase6-scale-execution-readback.ps1"
) | Sort-Object -Unique
$controlDelta = @(& git.exe -C $repoRoot diff --name-only --diff-filter=ACDMRTUXB ([string]$hostedState.source_commit_sha) $repositoryHeadSha --)
Require ($LASTEXITCODE -eq 0) "source/control delta cannot be resolved"
$safeControlDelta = @(& git.exe -C $repoRoot diff --name-only --diff-filter=ACM ([string]$hostedState.source_commit_sha) $repositoryHeadSha --)
Require ($LASTEXITCODE -eq 0) "source/control safe delta cannot be resolved"
$controlDelta = @($controlDelta | ForEach-Object { ([string]$_).Replace('\', '/') } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
$safeControlDelta = @($safeControlDelta | ForEach-Object { ([string]$_).Replace('\', '/') } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
Require ($controlDelta.Count -gt 0) "source/control delta is empty and cannot contain post-deployment evidence"
Require ($controlDelta.Count -eq $safeControlDelta.Count -and (@(Compare-Object $controlDelta $safeControlDelta -CaseSensitive).Count -eq 0)) "source/control delta contains a delete, rename, type change, or unmerged path"
$unexpectedControlDelta = @($controlDelta | Where-Object { $allowedControlDelta -cnotcontains $_ })
Require ($unexpectedControlDelta.Count -eq 0) "source/control delta contains a non-allowlisted runtime path"

# This authorization preflight intentionally precedes HttpClient construction and
# every call site. A missing token or Owner switch therefore produces zero HTTP.
$authEnvName = [string]$criterion.write_tier.auth_env_name
Require ($authEnvName -eq "AGENT_API_AUTH_TOKEN") "unexpected write auth environment variable"
$authValue = [Environment]::GetEnvironmentVariable($authEnvName)
if ([string]::IsNullOrWhiteSpace($authValue)) {
  Blocked "$authEnvName is missing (the value is never printed); zero HTTP requests issued"
}
if (-not $AllowHostedWrites) {
  Blocked "-AllowHostedWrites is missing; zero HTTP requests issued"
}

$executionStartedAt = [DateTimeOffset](Get-Date).ToUniversalTime()
$script:workerRequestsIssued = 0
$script:controlRequestsIssued = 0

Add-Type -AssemblyName System.Net.Http
$handler = $null
$httpClient = $null
try {
$handler = [Net.Http.SocketsHttpHandler]::new()
$handler.MaxConnectionsPerServer = 128
$handler.PooledConnectionLifetime = [TimeSpan]::FromMinutes(10)
$handler.AllowAutoRedirect = $false
$httpClient = [Net.Http.HttpClient]::new($handler)
$httpClient.Timeout = [TimeSpan]::FromSeconds(30)

function Invoke-HttpBatch([object[]]$Specs, [int]$Concurrency, [bool]$WorkerRequest) {
  $results = [Collections.Generic.List[object]]::new()
  for ($offset = 0; $offset -lt $Specs.Count; $offset += $Concurrency) {
    $waveSize = [Math]::Min($Concurrency, $Specs.Count - $offset)
    $tasks = @()
    $messages = @()
    $watches = @()
    $waveSpecs = @()

    for ($index = 0; $index -lt $waveSize; $index++) {
      $spec = $Specs[$offset + $index]
      if ($WorkerRequest) {
        if ($script:workerRequestsIssued -ge $maxWorkerRequests) {
          Fail "Worker request cap would be exceeded"
        }
        $script:workerRequestsIssued += 1
      } else {
        $script:controlRequestsIssued += 1
      }

      $message = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::new([string]$spec.method), [string]$spec.url)
      if (-not [string]::IsNullOrEmpty([string]$spec.body)) {
        $message.Content = [Net.Http.StringContent]::new([string]$spec.body, [Text.Encoding]::UTF8, "application/json")
      }
      if ($null -ne $spec.headers) {
        foreach ($entry in $spec.headers.GetEnumerator()) {
          [void]$message.Headers.TryAddWithoutValidation([string]$entry.Key, [string]$entry.Value)
        }
      }
      $watch = [Diagnostics.Stopwatch]::StartNew()
      $task = $httpClient.SendAsync($message, [Net.Http.HttpCompletionOption]::ResponseContentRead)
      $waveSpecs += $spec
      $messages += $message
      $watches += $watch
      $tasks += $task
    }

    try { [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]$tasks) } catch { }

    for ($index = 0; $index -lt $waveSize; $index++) {
      $watches[$index].Stop()
      $statusCode = 0
      $responseText = ""
      try {
        $response = $tasks[$index].GetAwaiter().GetResult()
        try {
          $statusCode = [int]$response.StatusCode
          $responseText = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        } finally {
          $response.Dispose()
        }
      } catch {
        $statusCode = 0
        $responseText = ""
      } finally {
        $messages[$index].Dispose()
      }
      $results.Add([pscustomobject]@{
        key = [string]$waveSpecs[$index].key
        ordinal = [int]$waveSpecs[$index].ordinal
        status_code = $statusCode
        latency_ms = [Math]::Round($watches[$index].Elapsed.TotalMilliseconds, 1)
        response_text = $responseText
      })
    }
  }
  return @($results)
}

function Test-HealthBody($Body) {
  $errors = [Collections.Generic.List[string]]::new()
  if ($null -eq $Body) {
    $errors.Add("invalid_json")
    return @($errors)
  }
  $expected = @{
    contract_version = "cloudflare-d1-stateful-runtime-v1"
    status = "healthy"
    service = "agent-api-stateful-runtime"
    provider = "cloudflare-d1"
    source_commit_sha = [string]$hostedState.source_commit_sha
    source_archive_sha256 = [string]$hostedState.source_archive_sha256
  }
  foreach ($entry in $expected.GetEnumerator()) {
    if (-not (Has-Property $Body $entry.Key) -or [string]$Body.($entry.Key) -ne [string]$entry.Value) { $errors.Add("field:$($entry.Key)") }
  }
  foreach ($name in @("d1_binding_configured", "d1_read_verified", "write_auth_configured", "auth_required_for_writes", "free_tier_policy", "persisted")) {
    if (-not (Has-Property $Body $name) -or $Body.$name -ne $true) { $errors.Add("field:$name") }
  }
  foreach ($name in @("direct_provider_calls", "live_mcp_writes", "production_deploy", "secret_output")) {
    if (-not (Has-Property $Body $name) -or $Body.$name -ne $false) { $errors.Add("field:$name") }
  }
  if (-not (Has-Property $Body "cloudflare_native_candidate") -or $null -eq $Body.cloudflare_native_candidate -or
      [string]$Body.cloudflare_native_candidate.contract_version -ne [string]$hostedState.runtime_contract_version) {
    $errors.Add("field:cloudflare_native_candidate.contract_version")
  }
  return @($errors)
}

function Test-CreateBody($Body, $Expected) {
  $errors = [Collections.Generic.List[string]]::new()
  if ($null -eq $Body) {
    $errors.Add("invalid_json")
    return @($errors)
  }
  $expectedFields = @{
    contract_version = "cloudflare-d1-stateful-runtime-v1"
    status = "created"
    source = "cloudflare-d1"
    id = [string]$Expected.id
    project_id = [string]$Expected.project_id
    title = [string]$Expected.title
    model = [string]$Expected.model
    html = [string]$Expected.html
    gateway_mode = [string]$Expected.gateway_mode
    gateway_provider = [string]$Expected.gateway_provider
    share_path = "/run/$($Expected.id)"
  }
  foreach ($entry in $expectedFields.GetEnumerator()) {
    if (-not (Has-Property $Body $entry.Key) -or [string]$Body.($entry.Key) -ne [string]$entry.Value) { $errors.Add("field:$($entry.Key)") }
  }
  if ((Get-OptionalStringProperty $Body "request_id") -cne [string]$Expected.create_request_id) { $errors.Add("field:request_id") }
  if ((Get-OptionalStringProperty $Body "audit_event_id") -cnotmatch '^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$') { $errors.Add("field:audit_event_id") }
  if ((Get-OptionalStringProperty $Body "prompt_sha256") -ne [string]$Expected.prompt_sha256) { $errors.Add("hash:prompt") }
  foreach ($name in @("persisted", "audit_persisted", "audit_readback_verified")) {
    if (-not (Has-Property $Body $name) -or $Body.$name -ne $true) { $errors.Add("field:$name") }
  }
  foreach ($name in @("live_provider_calls", "direct_provider_calls", "live_mcp_writes", "production_deploy", "secret_output")) {
    if (-not (Has-Property $Body $name) -or $Body.$name -ne $false) { $errors.Add("field:$name") }
  }
  if (Has-Property $Body "prompt") { $errors.Add("prompt_not_redacted") }
  if ((Get-StringSha256 (Get-OptionalStringProperty $Body "html")) -ne [string]$Expected.html_sha256) { $errors.Add("hash:html") }
  $createdAt = [DateTimeOffset]::MinValue
  $updatedAt = [DateTimeOffset]::MinValue
  $createdValid = [DateTimeOffset]::TryParse((Get-OptionalStringProperty $Body "created_at"), [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$createdAt)
  $updatedValid = [DateTimeOffset]::TryParse((Get-OptionalStringProperty $Body "updated_at"), [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$updatedAt)
  if (-not $createdValid -or $createdAt.Offset -ne [TimeSpan]::Zero) { $errors.Add("field:created_at") }
  if (-not $updatedValid -or $updatedAt.Offset -ne [TimeSpan]::Zero) { $errors.Add("field:updated_at") }
  if ($createdValid -and $updatedValid) {
    if ($createdAt -ne $updatedAt) { $errors.Add("field:timestamp_parity") }
    if ($createdAt -lt ($executionStartedAt - $allowedClockSkew) -or $createdAt -gt ([DateTimeOffset](Get-Date).ToUniversalTime() + $allowedClockSkew)) {
      $errors.Add("field:timestamp_window")
    }
  }
  return @($errors)
}

function Test-DeleteBody($Body, [string]$ExpectedId, [string]$ExpectedRequestId, [bool]$ExpectDeleted) {
  $errors = [Collections.Generic.List[string]]::new()
  if ($null -eq $Body) {
    $errors.Add("invalid_json")
    return @($errors)
  }
  if ((Get-OptionalStringProperty $Body "contract_version") -ne "cloudflare-d1-stateful-runtime-v1") { $errors.Add("field:contract_version") }
  if ((Get-OptionalStringProperty $Body "id") -cne $ExpectedId) { $errors.Add("field:id") }
  if ((Get-OptionalStringProperty $Body "request_id") -cne $ExpectedRequestId) { $errors.Add("field:request_id") }
  if ((Get-OptionalStringProperty $Body "audit_event_id") -cnotmatch '^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$') { $errors.Add("field:audit_event_id") }
  if ($ExpectDeleted) {
    if ((Get-OptionalStringProperty $Body "status") -ne "deleted") { $errors.Add("field:status") }
    foreach ($name in @("persisted", "deleted", "audit_persisted", "audit_readback_verified", "delete_readback_verified")) {
      if (-not (Has-Property $Body $name) -or $Body.$name -ne $true) { $errors.Add("field:$name") }
    }
  } else {
    if ((Get-OptionalStringProperty $Body "status") -ne "not_found") { $errors.Add("field:status") }
    foreach ($name in @("persisted", "deleted")) {
      if (-not (Has-Property $Body $name) -or $Body.$name -ne $false) { $errors.Add("field:$name") }
    }
    foreach ($name in @("audit_persisted", "audit_readback_verified", "delete_readback_verified")) {
      if (-not (Has-Property $Body $name) -or $Body.$name -ne $true) { $errors.Add("field:$name") }
    }
  }
  if (-not (Has-Property $Body "secret_output") -or $Body.secret_output -ne $false) { $errors.Add("field:secret_output") }
  return @($errors)
}

$criterionFileSha256 = $actualCriterionSha256
$hostedStateFileSha256 = (Get-FileHash -LiteralPath $HostedStatePath -Algorithm SHA256).Hash.ToLowerInvariant()
$capabilityStateFileSha256 = (Get-FileHash -LiteralPath $capabilityGatesPath -Algorithm SHA256).Hash.ToLowerInvariant()
$gateIdentityJson = [ordered]@{
  gate_id = "phase6_scale_runtime"
  owner_granted = [bool]$scaleGate.owner_granted
  owner_grant_ref = [string]$scaleGate.owner_grant_ref
  paid_provider = [bool]$scaleGate.paid_provider
} | ConvertTo-Json -Compress
$gateIdentitySha256 = Get-StringSha256 $gateIdentityJson
$verifierScriptSha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
$runId = [Guid]::NewGuid().ToString("N")
$projectId = "phase6-scale-$($runId.Substring(0, 16))"
$healthUrl = "$BaseUrl/api/v1/health"
$tierResults = @()
$validHealthJsonCount = 0
$invalidHealthJsonCount = 0
$controlFailureCount = 0
$healthValidationFailures = [Collections.Generic.List[string]]::new()

Write-Host "[phase6-scale] source-bound target: $BaseUrl"
Write-Host "[phase6-scale] Worker envelope   : 800 reads + 50 creates + 50 deletes = 900"
Write-Host "[phase6-scale] write auth        : $authEnvName present (value is never printed)"

foreach ($tier in $criterion.read_tiers) {
  $concurrency = [int]$tier.concurrency
  $requestCount = [int]$tier.requests
  $specs = @()
  for ($index = 0; $index -lt $requestCount; $index++) {
    $ordinal = $index + 1
    $specs += [pscustomobject]@{ key = "health-$concurrency-$ordinal"; ordinal = $ordinal; method = "GET"; url = $healthUrl; body = ""; headers = @{} }
  }
  $responses = Invoke-HttpBatch $specs $concurrency $true
  Require ($responses.Count -eq $requestCount) "read tier c=$concurrency response count is not exact"
  $codes = @($responses | ForEach-Object { [int]$_.status_code })
  $latencies = @($responses | ForEach-Object { [double]$_.latency_ms })
  $tierValid = 0
  $tierInvalid = 0
  $tierRecordEvidence = [Collections.Generic.List[object]]::new()
  $seenReadKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($response in $responses) {
    $responseOrdinal = [int]$response.ordinal
    $expectedKey = "health-$concurrency-$responseOrdinal"
    Require ($responseOrdinal -ge 1 -and $responseOrdinal -le $requestCount) "read tier c=$concurrency contains an invalid ordinal"
    Require ([string]$response.key -ceq $expectedKey) "read tier c=$concurrency key/ordinal binding mismatch"
    Require ($seenReadKeys.Add([string]$response.key)) "read tier c=$concurrency contains a duplicate request key"
    Require ([double]$response.latency_ms -ge 0.0 -and -not [double]::IsNaN([double]$response.latency_ms) -and -not [double]::IsInfinity([double]$response.latency_ms)) "read tier contains an invalid latency"
    $errors = @()
    $healthVerified = $false
    if ([int]$response.status_code -eq 200) {
      $body = ConvertFrom-JsonSafe ([string]$response.response_text)
      $errors = @(Test-HealthBody $body)
      if ($errors.Count -eq 0) {
        $healthVerified = $true
        $tierValid += 1
        $validHealthJsonCount += 1
      } else {
        $tierInvalid += 1
        $invalidHealthJsonCount += 1
        foreach ($errorName in $errors) { $healthValidationFailures.Add("c=$concurrency/$errorName") }
      }
    }
    $tierRecordEvidence.Add([pscustomobject]@{
      ordinal = $responseOrdinal
      key = [string]$response.key
      status_code = [int]$response.status_code
      latency_ms = [double]$response.latency_ms
      health_contract_verified = $healthVerified
      validation_errors = @($errors)
    })
  }
  Require ($seenReadKeys.Count -eq $requestCount) "read tier c=$concurrency request identities are incomplete"

  $controlP95 = $null
  $controlRecordEvidence = [Collections.Generic.List[object]]::new()
  $controlRemaining = $maxControlRequests - $script:controlRequestsIssued
  $controlCount = [Math]::Min($concurrency * 4, [Math]::Max(0, $controlRemaining))
  if ($controlCount -gt 0) {
    $controlSpecs = @()
    for ($index = 0; $index -lt $controlCount; $index++) {
      $ordinal = $index + 1
      $controlSpecs += [pscustomobject]@{
        key = "control-$concurrency-$ordinal"
        ordinal = $ordinal
        method = "GET"
        url = "$BaseUrl$([string]$criterion.control_tier.path)"
        body = ""
        headers = @{}
      }
    }
    $controlResponses = Invoke-HttpBatch $controlSpecs $concurrency $false
    Require ($controlResponses.Count -eq $controlCount) "edge-control tier c=$concurrency response count is not exact"
    $seenControlKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($controlResponse in $controlResponses) {
      $controlOrdinal = [int]$controlResponse.ordinal
      $expectedControlKey = "control-$concurrency-$controlOrdinal"
      Require ($controlOrdinal -ge 1 -and $controlOrdinal -le $controlCount) "edge-control tier c=$concurrency contains an invalid ordinal"
      Require ([string]$controlResponse.key -ceq $expectedControlKey) "edge-control tier c=$concurrency key/ordinal binding mismatch"
      Require ($seenControlKeys.Add([string]$controlResponse.key)) "edge-control tier c=$concurrency contains a duplicate request key"
      $controlStatusValid = ([int]$controlResponse.status_code -eq 200)
      if (-not $controlStatusValid) { $controlFailureCount += 1 }
      $controlRecordEvidence.Add([pscustomobject]@{
        ordinal = $controlOrdinal
        key = [string]$controlResponse.key
        status_code = [int]$controlResponse.status_code
        latency_ms = [double]$controlResponse.latency_ms
        response_ok = $controlStatusValid
      })
    }
    Require ($seenControlKeys.Count -eq $controlCount) "edge-control tier c=$concurrency request identities are incomplete"
    $controlP95 = Get-Percentile @($controlRecordEvidence | ForEach-Object { [double]$_.latency_ms }) 0.95
  }

  $tier429 = [int]@($codes | Where-Object { $_ -eq 429 }).Count
  $tier5xx = [int]@($codes | Where-Object { $_ -ge 500 -and $_ -le 599 }).Count
  $tierTransport = [int]@($codes | Where-Object { $_ -eq 0 }).Count
  $tierOther = [int]@($codes | Where-Object { $_ -ne 0 -and $_ -ne 200 -and $_ -ne 429 -and ($_ -lt 500 -or $_ -gt 599) }).Count
  Require (($tierValid + $tierInvalid + $tier429 + $tier5xx + $tierTransport + $tierOther) -eq $requestCount) "read tier c=$concurrency response accounting is not exact"
  $tierP95 = Get-Percentile $latencies 0.95
  $tierResults += [pscustomobject]@{
    concurrency = [int]$concurrency
    requests = [int]$requestCount
    valid_health_200 = [int]$tierValid
    invalid_health_200 = [int]$tierInvalid
    throttled_429 = [int]$tier429
    server_5xx = [int]$tier5xx
    transport_fail = [int]$tierTransport
    other_status = [int]$tierOther
    p50_ms = Get-Percentile $latencies 0.50
    p95_ms = $tierP95
    p99_ms = Get-Percentile $latencies 0.99
    edge_control_p95_ms = $controlP95
    worker_share_p95_ms = if ($null -ne $controlP95) { [Math]::Round([Math]::Max(0.0, $tierP95 - $controlP95), 1) } else { $null }
    records = @($tierRecordEvidence)
    edge_control_records = @($controlRecordEvidence)
  }
  Write-Host ("[phase6-scale] READ c={0,-2} n={1,-3} valid-health={2,-3} 429={3,-3} 5xx={4,-3} transport={5,-3} p95={6}ms" -f `
    $concurrency, $requestCount, $tierValid, $tierResults[-1].throttled_429, $tierResults[-1].server_5xx,
    $tierResults[-1].transport_fail, $tierP95)
}

Require ($script:workerRequestsIssued -eq 800) "read tier did not issue exactly 800 Worker requests"
Require ($script:controlRequestsIssued -eq 244) "edge-control tier did not issue exactly 244 requests"
if ($validHealthJsonCount -eq 0 -or $invalidHealthJsonCount -gt 0 -or
    @($tierResults | Where-Object { $_.valid_health_200 -eq 0 }).Count -gt 0) {
  Fail "health JSON/source binding failed; no hosted writes were issued"
}

$expectedById = @{}
$postSpecs = @()
for ($index = 0; $index -lt $writeExpected; $index++) {
  $ordinal = $index + 1
  $id = "p6s$($runId.Substring(0, 24))$($ordinal.ToString('00'))"
  $createRequestId = "phase6-scale-$runId-$ordinal-create"
  $prompt = "Phase 6 zero-card scale verification record $ordinal for run $runId"
  $html = "<!doctype html><html><head><meta charset=`"utf-8`"><title>Phase 6 $ordinal</title></head><body><main data-phase6-scale=`"$id`">Scale record $ordinal</main></body></html>"
  $expected = [pscustomobject]@{
    ordinal = $ordinal
    id = $id
    project_id = $projectId
    title = "Phase 6 scale record $ordinal"
    prompt_sha256 = Get-StringSha256 $prompt
    model = "phase6-scale-verifier"
    html = $html
    html_sha256 = Get-StringSha256 $html
    gateway_mode = "scale_evidence"
    gateway_provider = "none"
    create_request_id = $createRequestId
  }
  $expectedById[$id] = $expected
  $payload = [ordered]@{
    id = $id
    project_id = $projectId
    title = $expected.title
    prompt = $prompt
    model = $expected.model
    html = $html
    gateway_mode = $expected.gateway_mode
    gateway_provider = $expected.gateway_provider
    live_provider_calls = $false
  } | ConvertTo-Json -Compress
  $postSpecs += [pscustomobject]@{
    key = $id
    ordinal = $ordinal
    method = "POST"
    url = "$BaseUrl/api/v1/builds"
    body = $payload
    headers = @{ "x-superbrain-agent-token" = $authValue; "x-request-id" = $createRequestId }
  }
}

$deleteSpecs = @()
$deleteRequestIdById = @{}
foreach ($id in @($expectedById.Keys | Sort-Object)) {
  $deleteRequestId = "phase6-scale-$runId-$id-delete"
  $deleteRequestIdById[$id] = $deleteRequestId
  $deleteSpecs += [pscustomobject]@{
    key = $id
    ordinal = [int]$expectedById[$id].ordinal
    method = "DELETE"
    url = "$BaseUrl/api/v1/build/$id"
    body = ""
    headers = @{ "x-superbrain-agent-token" = $authValue; "x-request-id" = $deleteRequestId }
  }
}

$postResponses = @()
$deleteResponses = @()
$postEvidence = [Collections.Generic.List[object]]::new()
$validCreatedIds = [Collections.Generic.List[string]]::new()
$createFieldFailureCount = 0
$createHashFailureCount = 0
$createAuditFailureCount = 0
$duplicateCount = 0
$recordLossCount = $writeExpected

# Every planned ID is deleted from a literal finally block. This also covers an
# unexpected local validation exception after one or more POST requests and is
# stronger than relying on the normal happy-path sequence for test cleanup.
try {
  $postResponses = Invoke-HttpBatch $postSpecs $writeConcurrency $true
  Require ($postResponses.Count -eq $writeExpected) "write tier response count is not exact"
  $seenPostKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($response in $postResponses) {
    $id = [string]$response.key
    Require ($expectedById.ContainsKey($id)) "write tier returned an unplanned request identity"
    Require ($seenPostKeys.Add($id)) "write tier returned a duplicate request identity"
    $expected = $expectedById[$id]
    Require ([int]$response.ordinal -eq [int]$expected.ordinal) "write tier ID/ordinal binding mismatch"
    Require ($id -ceq "p6s$($runId.Substring(0, 24))$(([int]$expected.ordinal).ToString('00'))") "write tier ID derivation mismatch"
    $body = ConvertFrom-JsonSafe ([string]$response.response_text)
    $errors = @()
    $readbackVerified = $false
    $responseId = if ($null -ne $body -and (Has-Property $body "id")) { [string]$body.id } else { $null }
    if ([int]$response.status_code -eq 201) {
      $errors = @(Test-CreateBody $body $expected)
      $readbackVerified = ($errors.Count -eq 0)
      if ($readbackVerified) { $validCreatedIds.Add($id) }
      $createFieldFailureCount += @($errors | Where-Object { $_ -like "field:*" -or $_ -eq "invalid_json" -or $_ -eq "prompt_not_redacted" }).Count
      $createHashFailureCount += @($errors | Where-Object { $_ -like "hash:*" }).Count
      $createAuditFailureCount += @($errors | Where-Object {
        $_ -in @("field:audit_persisted", "field:audit_readback_verified", "field:audit_event_id", "field:request_id")
      }).Count
    } elseif ([int]$response.status_code -ne 429) {
      $errors = @("http:$([int]$response.status_code)")
    }
    $responsePromptSha256 = if ($null -ne $body -and (Has-Property $body "prompt_sha256")) { [string]$body.prompt_sha256 } else { "" }
    $responseHtmlSha256 = if ($null -ne $body -and (Has-Property $body "html")) { Get-StringSha256 ([string]$body.html) } else { "" }
    $postEvidence.Add([pscustomobject]@{
      ordinal = [int]$expected.ordinal
      id = $id
      response_id = $responseId
      status_code = [int]$response.status_code
      latency_ms = [double]$response.latency_ms
      response_readback_verified = $readbackVerified
      request_id = Get-OptionalStringProperty $body "request_id"
      audit_event_id = Get-OptionalStringProperty $body "audit_event_id"
      prompt_sha256 = $responsePromptSha256
      html_sha256 = $responseHtmlSha256
      created_at_utc = Get-OptionalStringProperty $body "created_at"
      updated_at_utc = Get-OptionalStringProperty $body "updated_at"
      audit_persisted_verified = ($readbackVerified -and $body.audit_persisted -eq $true)
      audit_readback_verified = ($readbackVerified -and $body.audit_readback_verified -eq $true)
      validation_errors = @($errors)
    })
  }
  Require ($seenPostKeys.Count -eq $writeExpected) "write tier request identities are incomplete"

  $responseIds = @($postEvidence | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.response_id) } | ForEach-Object { $_.response_id })
  $duplicateCount = @($responseIds | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Count - 1 } | Measure-Object -Sum).Sum
  if ($null -eq $duplicateCount) { $duplicateCount = 0 }
  $recordLossCount = $writeExpected - $validCreatedIds.Count
} finally {
  try {
    $deleteResponses = Invoke-HttpBatch $deleteSpecs $writeConcurrency $true
  } finally {
    $postSpecs = $null
    $deleteSpecs = $null
    $authValue = $null
  }
}
$cleanupEvidence = [Collections.Generic.List[object]]::new()
$cleanupVerifiedCount = 0
$uncleanThrottleCount = 0
$seenCleanupKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)

foreach ($response in $deleteResponses) {
  $id = [string]$response.key
  Require ($expectedById.ContainsKey($id)) "cleanup tier returned an unplanned request identity"
  Require ($seenCleanupKeys.Add($id)) "cleanup tier returned a duplicate request identity"
  $create = @($postEvidence | Where-Object { $_.id -eq $id })[0]
  Require ($null -ne $create) "cleanup tier lacks its create correlation"
  Require ([int]$response.ordinal -eq [int]$expectedById[$id].ordinal) "cleanup tier ID/ordinal binding mismatch"
  $body = ConvertFrom-JsonSafe ([string]$response.response_text)
  $expectDeleted = [bool]$create.response_readback_verified
  $errors = @()
  $verified = $false
  if ($expectDeleted -and [int]$response.status_code -eq 200) {
    $errors = @(Test-DeleteBody $body $id ([string]$deleteRequestIdById[$id]) $true)
    $verified = ($errors.Count -eq 0)
  } elseif ([int]$create.status_code -eq 429 -and [int]$response.status_code -eq 404) {
    $errors = @(Test-DeleteBody $body $id ([string]$deleteRequestIdById[$id]) $false)
    $verified = ($errors.Count -eq 0)
    if (-not $verified) { $uncleanThrottleCount += 1 }
  } else {
    $errors = @("cleanup_http:$([int]$response.status_code)")
    if ([int]$create.status_code -eq 429 -or [int]$response.status_code -eq 429) { $uncleanThrottleCount += 1 }
  }
  if ($verified) { $cleanupVerifiedCount += 1 }
  $cleanupEvidence.Add([pscustomobject]@{
    ordinal = [int]$expectedById[$id].ordinal
    id = $id
    status_code = [int]$response.status_code
    latency_ms = [double]$response.latency_ms
    expected_deleted_record = $expectDeleted
    cleanup_verified = $verified
    request_id = Get-OptionalStringProperty $body "request_id"
    audit_event_id = Get-OptionalStringProperty $body "audit_event_id"
    audit_persisted_verified = ($verified -and $body.audit_persisted -eq $true)
    audit_readback_verified = ($verified -and $body.audit_readback_verified -eq $true)
    delete_readback_verified = ($verified -and $body.delete_readback_verified -eq $true)
    validation_errors = @($errors)
  })
}
Require ($seenCleanupKeys.Count -eq $writeExpected) "cleanup tier request identities are incomplete"

Require ($postResponses.Count -eq 50) "write tier did not issue exactly 50 POST requests"
Require ($deleteResponses.Count -eq 50) "cleanup tier did not issue exactly 50 DELETE requests"
Require ($script:workerRequestsIssued -eq $maxWorkerRequests) "Worker request count is not exactly $maxWorkerRequests"

$createRequestIds = @($postEvidence | ForEach-Object { [string]$_.request_id })
$cleanupRequestIds = @($cleanupEvidence | ForEach-Object { [string]$_.request_id })
$allRequestIds = @($createRequestIds + $cleanupRequestIds | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$allAuditEventIds = @(
  @($postEvidence | ForEach-Object { [string]$_.audit_event_id }) +
  @($cleanupEvidence | ForEach-Object { [string]$_.audit_event_id }) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
)
$duplicateRequestIdCount = [int](@($allRequestIds | Group-Object -CaseSensitive | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Count - 1 } | Measure-Object -Sum).Sum)
$duplicateAuditEventIdCount = [int](@($allAuditEventIds | Group-Object -CaseSensitive | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Count - 1 } | Measure-Object -Sum).Sum)
Require ($duplicateRequestIdCount -ge 0 -and $duplicateAuditEventIdCount -ge 0) "correlation duplicate counts must be non-negative integers"
Require ($recordLossCount -ge 0 -and $recordLossCount -le $writeExpected) "write record-loss count is invalid"
Require ($cleanupVerifiedCount -ge 0 -and $cleanupVerifiedCount -le $writeExpected) "cleanup verified count is invalid"

$read429 = [int](($tierResults | Measure-Object -Property throttled_429 -Sum).Sum)
$read5xx = [int](($tierResults | Measure-Object -Property server_5xx -Sum).Sum)
$readTransport = [int](($tierResults | Measure-Object -Property transport_fail -Sum).Sum)
$readOther = [int](($tierResults | Measure-Object -Property other_status -Sum).Sum)
$post201 = [int]@($postResponses | Where-Object { $_.status_code -eq 201 }).Count
$post429 = [int]@($postResponses | Where-Object { $_.status_code -eq 429 }).Count
$post5xx = [int]@($postResponses | Where-Object { $_.status_code -ge 500 -and $_.status_code -le 599 }).Count
$postTransport = [int]@($postResponses | Where-Object { $_.status_code -eq 0 }).Count
$postOther = [int]@($postResponses | Where-Object { $_.status_code -ne 0 -and $_.status_code -ne 201 -and $_.status_code -ne 429 -and ($_.status_code -lt 500 -or $_.status_code -gt 599) }).Count
$delete200 = [int]@($deleteResponses | Where-Object { $_.status_code -eq 200 }).Count
$delete429 = [int]@($deleteResponses | Where-Object { $_.status_code -eq 429 }).Count
$delete5xx = [int]@($deleteResponses | Where-Object { $_.status_code -ge 500 -and $_.status_code -le 599 }).Count
$deleteTransport = [int]@($deleteResponses | Where-Object { $_.status_code -eq 0 }).Count
$deleteOther = [int]@($deleteResponses | Where-Object { $_.status_code -ne 0 -and $_.status_code -ne 200 -and $_.status_code -ne 429 -and ($_.status_code -lt 500 -or $_.status_code -gt 599) }).Count
Require (($post201 + $post429 + $post5xx + $postTransport + $postOther) -eq $writeExpected) "write response status accounting is not exact"
Require (($delete200 + $delete429 + $delete5xx + $deleteTransport + $deleteOther) -eq $writeExpected) "cleanup response status accounting is not exact"
$server5xxTotal = [int]($read5xx + $post5xx + $delete5xx)
$transportTotal = [int]($readTransport + $postTransport + $deleteTransport)
$throttled429Total = $read429 + $post429 + $delete429
$literalCleanupSuccessCount = [int]@($cleanupEvidence | Where-Object { $_.status_code -eq 200 -and $_.cleanup_verified -eq $true }).Count
$literalSuccessCount = [int]($validHealthJsonCount + $validCreatedIds.Count + $literalCleanupSuccessCount)
Require ($literalSuccessCount -ge 0 -and $literalSuccessCount -le $maxWorkerRequests) "literal 2xx success count is invalid"
# 429 is deliberately excluded: only contract-valid health 200, create 201,
# and verified cleanup 200 responses are literal successes.
$successRatio = [Math]::Round(([double]$literalSuccessCount / [double]$maxWorkerRequests), 4)
$worstReadP95 = [double](($tierResults | Measure-Object -Property p95_ms -Maximum).Maximum)
$postLatencies = @($postResponses | ForEach-Object { [double]$_.latency_ms })
$deleteLatencies = @($deleteResponses | ForEach-Object { [double]$_.latency_ms })
$postP95 = Get-Percentile $postLatencies 0.95
$deleteP95 = Get-Percentile $deleteLatencies 0.95
$worstWorkerP95 = [Math]::Max($worstReadP95, [Math]::Max($postP95, $deleteP95))

$failures = [Collections.Generic.List[string]]::new()
if ($successRatio -lt [double]$criterion.pass_criteria.min_success_ratio) { $failures.Add("success_ratio_below_threshold") }
if ($worstWorkerP95 -gt [double]$criterion.pass_criteria.max_p95_ms) { $failures.Add("p95_above_threshold") }
if ($server5xxTotal -gt $own5xxAllowed) { $failures.Add("own_5xx_above_threshold") }
if ($transportTotal -gt 0) { $failures.Add("transport_failure") }
if ($readOther -gt 0) { $failures.Add("unexpected_read_status") }
if ($controlFailureCount -gt 0) { $failures.Add("edge_control_failure") }
if ($invalidHealthJsonCount -gt 0) { $failures.Add("invalid_health_json") }
if ($post429 -gt 0 -or $delete429 -gt 0) { $failures.Add("write_or_cleanup_throttled") }
if ($recordLossCount -gt 0) { $failures.Add("write_record_loss") }
if ([int]$duplicateCount -gt 0) { $failures.Add("duplicate_write_readback") }
if ($duplicateRequestIdCount -gt 0) { $failures.Add("duplicate_request_id") }
if ($duplicateAuditEventIdCount -gt 0) { $failures.Add("duplicate_audit_event_id") }
if ($allRequestIds.Count -ne (2 * $writeExpected)) { $failures.Add("request_id_accounting_incomplete") }
if ($allAuditEventIds.Count -ne (2 * $writeExpected)) { $failures.Add("audit_event_id_accounting_incomplete") }
if ($createFieldFailureCount -gt 0 -or $createHashFailureCount -gt 0 -or $createAuditFailureCount -gt 0) { $failures.Add("write_readback_validation_failed") }
if ($cleanupVerifiedCount -ne $writeExpected) { $failures.Add("cleanup_incomplete") }
if ($uncleanThrottleCount -gt 0) { $failures.Add("throttle_did_not_fail_closed") }

$generatedAt = (Get-Date).ToUniversalTime()
$timestamp = $generatedAt.ToString("yyyyMMddTHHmmssfffZ")
$artifactDir = Join-Path $repoRoot ".phase1-artifacts\phase6-scale"
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
$reportPath = Join-Path $artifactDir "scale-evidence-$timestamp-$runId.json"
$shaPath = "$reportPath.sha256"

$report = [ordered]@{
  contract_version = "phase6-scale-evidence-v2"
  generated_at_utc = $generatedAt.ToString("o")
  run_id = $runId
  result = if ($failures.Count -eq 0) { "provisional_pending_github_readback" } else { "failed" }
  criterion_binding = [ordered]@{
    contract_version = [string]$criterion.contract_version
    gate_id = [string]$criterion.gate_id
    file_sha256 = $criterionFileSha256
    declared_before_first_run = [bool]$criterion.declared_before_first_run
    declared_before_first_full_write_run = [bool]$criterion.declared_before_first_full_write_run
  }
  source_binding = [ordered]@{
    hosted_state_contract_version = [string]$hostedState.contract_version
    hosted_state_file_sha256 = $hostedStateFileSha256
    base_url = $BaseUrl
    source_commit_sha = [string]$hostedState.source_commit_sha
    source_archive_sha256 = [string]$hostedState.source_archive_sha256
    deployment_evidence_artifact = $hostedEvidenceRelativePath
    deployment_evidence_sha256 = $hostedEvidenceSha256
    worker_version_id = [string]$hostedEvidence.worker_version_id
    deployment_id = [string]$hostedEvidence.deployment_id
    verifier_script_sha256 = $verifierScriptSha256
    repository_head_sha = $repositoryHeadSha
    capability_state_sha256 = $capabilityStateFileSha256
    gate_identity_sha256 = $gateIdentitySha256
    owner_granted = [bool]$scaleGate.owner_granted
    owner_grant_ref = [string]$scaleGate.owner_grant_ref
    health_json_source_binding_verified = ($validHealthJsonCount -gt 0 -and $invalidHealthJsonCount -eq 0)
    execution_attestation = [ordered]@{
      contract_version = "phase6-scale-execution-provenance-v1"
      binding_mode = "source_control_allowlist_v1"
      status = "provisional_pending_github_readback"
      github_actions = $true
      repository = $githubRepository
      run_id = [Int64]$githubRunId
      run_attempt = [int]$githubRunAttempt
      run_url = $githubRunUrl
      event_name = $githubEventName
      ref = $githubRef
      head_sha = $githubSha
      source_commit_sha = [string]$hostedState.source_commit_sha
      control_delta = @($controlDelta)
      workflow = $githubWorkflow
      workflow_ref = $githubWorkflowRef
      job = $githubJob
      artifact_name = $githubArtifactName
      post_run_api_readback_required = $true
      verified = $false
    }
  }
  request_budget = [ordered]@{
    worker_cap = [int]$maxWorkerRequests
    worker_requests_issued = [int]$script:workerRequestsIssued
    read_requests_issued = [int]$readExpected
    create_requests_issued = [int]$postResponses.Count
    cleanup_delete_requests_issued = [int]$deleteResponses.Count
    control_edge_requests_issued = [int]$script:controlRequestsIssued
    cap_respected = ($script:workerRequestsIssued -le $maxWorkerRequests)
    exact_plan_executed = ($script:workerRequestsIssued -eq 900)
  }
  read_tiers = @($tierResults)
  health_validation = [ordered]@{
    valid_json_count = [int]$validHealthJsonCount
    invalid_json_or_contract_count = [int]$invalidHealthJsonCount
    validation_failures = @($healthValidationFailures | Select-Object -Unique)
  }
  write_tier = [ordered]@{
    concurrency = $writeConcurrency
    records_planned = $writeExpected
    valid_post_insert_readbacks = [int]$validCreatedIds.Count
    record_loss_count = [int]$recordLossCount
    duplicate_count = [int]$duplicateCount
    duplicate_request_id_count = [int]$duplicateRequestIdCount
    duplicate_audit_event_id_count = [int]$duplicateAuditEventIdCount
    field_failure_count = [int]$createFieldFailureCount
    hash_failure_count = [int]$createHashFailureCount
    audit_failure_count = [int]$createAuditFailureCount
    throttled_429 = [int]$post429
    server_5xx = [int]$post5xx
    transport_fail = [int]$postTransport
    p50_ms = Get-Percentile $postLatencies 0.50
    p95_ms = $postP95
    p99_ms = Get-Percentile $postLatencies 0.99
    records = @($postEvidence)
  }
  cleanup = [ordered]@{
    verified_count = [int]$cleanupVerifiedCount
    literal_success_count = [int]$literalCleanupSuccessCount
    required_count = [int]$writeExpected
    complete = ($cleanupVerifiedCount -eq $writeExpected)
    throttled_429 = [int]$delete429
    unclean_throttle_count = [int]$uncleanThrottleCount
    server_5xx = [int]$delete5xx
    transport_fail = [int]$deleteTransport
    p95_ms = $deleteP95
    records = @($cleanupEvidence)
  }
  aggregate = [ordered]@{
    literal_success_count = [int]$literalSuccessCount
    success_ratio = $successRatio
    worst_p95_ms = $worstWorkerP95
    throttled_429_total = [int]$throttled429Total
    server_5xx_total = [int]$server5xxTotal
    transport_fail_total = [int]$transportTotal
    edge_control_failure_count = [int]$controlFailureCount
    http_429_counted_as_success = $false
    failures = @($failures)
    criterion_met = ($failures.Count -eq 0)
  }
  auth = [ordered]@{
    environment_variable_name = $authEnvName
    value_recorded = $false
  }
  gate_may_open = $false
  gate_promotion_performed = $false
  percentage_credit_awarded = 0
  non_claims = @($criterion.non_claims) + @(
    "This evidence file does not promote phase6_scale_runtime.",
    "This provisional evidence requires an independently downloaded post-run GitHub API and artifact readback before it can verify execution provenance.",
    "The authorization token is neither printed nor persisted.",
    "Control requests use the Cloudflare edge path and are not Worker requests."
  )
}

$json = $report | ConvertTo-Json -Depth 10
$utf8NoBom = [Text.UTF8Encoding]::new($false)
$reportCreated = $false
$sidecarCreated = $false
$reportSha256 = Get-StringSha256 $json
try {
  # The digest sidecar is created first from the exact UTF-8 bytes held in
  # memory. Therefore a sidecar failure can never leave an orphan report.
  $shaStream = [IO.File]::Open($shaPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
  $sidecarCreated = $true
  try {
    $shaWriter = [IO.StreamWriter]::new($shaStream, $utf8NoBom)
    try { $shaWriter.Write("$reportSha256  $([IO.Path]::GetFileName($reportPath))`n") } finally { $shaWriter.Dispose() }
  } finally {
    if ($null -ne $shaStream) { $shaStream.Dispose() }
  }
  $stream = [IO.File]::Open($reportPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
  $reportCreated = $true
  try {
    $writer = [IO.StreamWriter]::new($stream, $utf8NoBom)
    try { $writer.Write($json) } finally { $writer.Dispose() }
  } finally {
    if ($null -ne $stream) { $stream.Dispose() }
  }
  $writtenReportSha256 = (Get-FileHash -LiteralPath $reportPath -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($writtenReportSha256 -cne $reportSha256) { throw "evidence byte digest mismatch" }
} catch {
  if ($reportCreated -and (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    Remove-Item -LiteralPath $reportPath -Force
  }
  if ($sidecarCreated -and (Test-Path -LiteralPath $shaPath -PathType Leaf)) {
    Remove-Item -LiteralPath $shaPath -Force
  }
  Fail "immutable evidence/report sidecar pair could not be created atomically"
}

Write-Host ""
Write-Host "[phase6-scale] Worker requests : $($script:workerRequestsIssued) / $maxWorkerRequests"
Write-Host "[phase6-scale] valid readback  : $($validCreatedIds.Count) / $writeExpected"
Write-Host "[phase6-scale] cleanup         : $cleanupVerifiedCount / $writeExpected"
Write-Host "[phase6-scale] 429 / 5xx / net : $throttled429Total / $server5xxTotal / $transportTotal"
Write-Host "[phase6-scale] worst p95       : ${worstWorkerP95}ms"
Write-Host "[phase6-scale] evidence        : $reportPath"
Write-Host "[phase6-scale] evidence SHA256 : $reportSha256"
Write-Host "[phase6-scale] gate promoted   : false"
Write-Host "[phase6-scale] GitHub artifact : $githubArtifactName"
Write-Host "[phase6-scale] API readback    : pending after completed run"

if ($failures.Count -gt 0) {
  Fail ("criterion failed: " + (@($failures) -join "; "))
}
Write-Host "[phase6-scale] PROVISIONAL: literal criterion met; completed GitHub run/artifact readback is still required"
} finally {
  $authValue = $null
  $postSpecs = $null
  $deleteSpecs = $null
  if ($null -ne $httpClient) { $httpClient.Dispose() }
  if ($null -ne $handler) { $handler.Dispose() }
}
exit 0

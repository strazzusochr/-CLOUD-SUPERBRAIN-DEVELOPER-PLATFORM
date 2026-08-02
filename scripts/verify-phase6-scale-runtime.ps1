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

$readExpected = [int](($criterion.read_tiers | Measure-Object -Property requests -Sum).Sum)
$writeExpected = [int]$criterion.write_tier.records
$writeConcurrency = [int]$criterion.write_tier.concurrency
$maxWorkerRequests = [int]$criterion.envelope.max_total_requests
$declaredReadTiers = @($criterion.read_tiers)
Require ($declaredReadTiers.Count -eq 3) "criterion must declare exactly three read tiers"
$lockedReadTiers = @(
  @{ concurrency = 1; requests = 60 },
  @{ concurrency = 10; requests = 240 },
  @{ concurrency = 50; requests = 500 }
)
for ($tierIndex = 0; $tierIndex -lt $lockedReadTiers.Count; $tierIndex++) {
  Require (
    [int]$declaredReadTiers[$tierIndex].concurrency -eq [int]$lockedReadTiers[$tierIndex].concurrency -and
    [int]$declaredReadTiers[$tierIndex].requests -eq [int]$lockedReadTiers[$tierIndex].requests
  ) "criterion read tier $tierIndex differs from the pre-declared 60@c1, 240@c10, 500@c50 plan"
}
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
Require ([int]$criterion.control_tier.max_control_requests -eq 500) "criterion control request cap changed"
Require ([double]$criterion.pass_criteria.min_success_ratio -eq 0.99) "criterion success threshold changed"
Require ([double]$criterion.pass_criteria.max_p95_ms -eq 1500) "criterion p95 threshold changed"
Require ([int]$criterion.pass_criteria.own_5xx_allowed -eq 0) "criterion 5xx allowance changed"
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
Require ([string]$hostedEvidence.source_commit_sha -eq [string]$hostedState.source_commit_sha) "hosted deployment evidence source commit mismatch"
Require ([string]$hostedEvidence.source_archive_sha256 -eq [string]$hostedState.source_archive_sha256) "hosted deployment evidence source archive mismatch"
Require ([string]$hostedEvidence.worker_version_id -match '^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$') "hosted deployment evidence Worker version ID is invalid"
Require ([string]$hostedEvidence.deployment_id -match '^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$') "hosted deployment evidence deployment ID is invalid"
Require ($hostedEvidence.source_binding_verified -eq $true -and $hostedEvidence.hosted_write_read_delete_verified -eq $true) "hosted deployment evidence lacks source-bound runtime proof"
Require ($hostedEvidence.dev_only -eq $false -and $hostedEvidence.secret_output -eq $false) "hosted deployment evidence is DEV-only or exposes secret output"
Require ((Get-GitArchiveSha256 ([string]$hostedState.source_commit_sha)) -eq [string]$hostedState.source_archive_sha256) "hosted source archive does not match the declared Git commit"

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
    if ([string]$Body.($entry.Key) -ne [string]$entry.Value) { $errors.Add("field:$($entry.Key)") }
  }
  foreach ($name in @("d1_binding_configured", "d1_read_verified", "write_auth_configured", "auth_required_for_writes", "free_tier_policy", "persisted")) {
    if (-not (Has-Property $Body $name) -or $Body.$name -ne $true) { $errors.Add("field:$name") }
  }
  foreach ($name in @("direct_provider_calls", "live_mcp_writes", "production_deploy", "secret_output")) {
    if (-not (Has-Property $Body $name) -or $Body.$name -ne $false) { $errors.Add("field:$name") }
  }
  if (-not (Has-Property $Body "cloudflare_native_candidate") -or
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
    if ([string]$Body.($entry.Key) -ne [string]$entry.Value) { $errors.Add("field:$($entry.Key)") }
  }
  if ([string]$Body.request_id -cne [string]$Expected.create_request_id) { $errors.Add("field:request_id") }
  if ([string]$Body.audit_event_id -cnotmatch '^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$') { $errors.Add("field:audit_event_id") }
  if ([string]$Body.prompt_sha256 -ne [string]$Expected.prompt_sha256) { $errors.Add("hash:prompt") }
  foreach ($name in @("persisted", "audit_persisted", "audit_readback_verified")) {
    if (-not (Has-Property $Body $name) -or $Body.$name -ne $true) { $errors.Add("field:$name") }
  }
  foreach ($name in @("live_provider_calls", "direct_provider_calls", "live_mcp_writes", "production_deploy", "secret_output")) {
    if (-not (Has-Property $Body $name) -or $Body.$name -ne $false) { $errors.Add("field:$name") }
  }
  if (Has-Property $Body "prompt") { $errors.Add("prompt_not_redacted") }
  if ((Get-StringSha256 ([string]$Body.html)) -ne [string]$Expected.html_sha256) { $errors.Add("hash:html") }
  $createdAt = [DateTimeOffset]::MinValue
  $updatedAt = [DateTimeOffset]::MinValue
  if (-not [DateTimeOffset]::TryParse([string]$Body.created_at, [ref]$createdAt)) { $errors.Add("field:created_at") }
  if (-not [DateTimeOffset]::TryParse([string]$Body.updated_at, [ref]$updatedAt)) { $errors.Add("field:updated_at") }
  return @($errors)
}

function Test-DeleteBody($Body, [string]$ExpectedId, [string]$ExpectedRequestId, [bool]$ExpectDeleted) {
  $errors = [Collections.Generic.List[string]]::new()
  if ($null -eq $Body) {
    $errors.Add("invalid_json")
    return @($errors)
  }
  if ([string]$Body.contract_version -ne "cloudflare-d1-stateful-runtime-v1") { $errors.Add("field:contract_version") }
  if ([string]$Body.id -cne $ExpectedId) { $errors.Add("field:id") }
  if ([string]$Body.request_id -cne $ExpectedRequestId) { $errors.Add("field:request_id") }
  if ([string]$Body.audit_event_id -cnotmatch '^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$') { $errors.Add("field:audit_event_id") }
  if ($ExpectDeleted) {
    if ([string]$Body.status -ne "deleted") { $errors.Add("field:status") }
    foreach ($name in @("persisted", "deleted", "audit_persisted", "audit_readback_verified", "delete_readback_verified")) {
      if (-not (Has-Property $Body $name) -or $Body.$name -ne $true) { $errors.Add("field:$name") }
    }
  } else {
    if ([string]$Body.status -ne "not_found") { $errors.Add("field:status") }
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
$repositoryHeadSha = [string](& git.exe -C $repoRoot rev-parse HEAD)
$repositoryHeadSha = $repositoryHeadSha.Trim()
Require ($repositoryHeadSha -match '^[0-9a-f]{40}$') "repository HEAD SHA is invalid"
$runId = [Guid]::NewGuid().ToString("N")
$projectId = "phase6-scale-$($runId.Substring(0, 16))"
$healthUrl = "$BaseUrl/api/v1/health"
$tierResults = @()
$validHealthJsonCount = 0
$invalidHealthJsonCount = 0
$healthValidationFailures = [Collections.Generic.List[string]]::new()

Write-Host "[phase6-scale] source-bound target: $BaseUrl"
Write-Host "[phase6-scale] Worker envelope   : 800 reads + 50 creates + 50 deletes = 900"
Write-Host "[phase6-scale] write auth        : $authEnvName present (value is never printed)"

foreach ($tier in $criterion.read_tiers) {
  $concurrency = [int]$tier.concurrency
  $requestCount = [int]$tier.requests
  $specs = @()
  for ($index = 0; $index -lt $requestCount; $index++) {
    $specs += [pscustomobject]@{ key = "health-$concurrency-$index"; method = "GET"; url = $healthUrl; body = ""; headers = @{} }
  }
  $responses = Invoke-HttpBatch $specs $concurrency $true
  $codes = @($responses | ForEach-Object { [int]$_.status_code })
  $latencies = @($responses | ForEach-Object { [double]$_.latency_ms })
  $tierValid = 0
  $tierInvalid = 0
  foreach ($response in $responses) {
    if ([int]$response.status_code -eq 200) {
      $body = ConvertFrom-JsonSafe ([string]$response.response_text)
      $errors = @(Test-HealthBody $body)
      if ($errors.Count -eq 0) {
        $tierValid += 1
        $validHealthJsonCount += 1
      } else {
        $tierInvalid += 1
        $invalidHealthJsonCount += 1
        foreach ($errorName in $errors) { $healthValidationFailures.Add("c=$concurrency/$errorName") }
      }
    }
  }

  $controlP95 = $null
  $controlRemaining = [int]$criterion.control_tier.max_control_requests - $script:controlRequestsIssued
  $controlCount = [Math]::Min($concurrency * 4, [Math]::Max(0, $controlRemaining))
  if ($controlCount -gt 0) {
    $controlSpecs = @()
    for ($index = 0; $index -lt $controlCount; $index++) {
      $controlSpecs += [pscustomobject]@{
        key = "control-$concurrency-$index"
        method = "GET"
        url = "$BaseUrl$([string]$criterion.control_tier.path)"
        body = ""
        headers = @{}
      }
    }
    $controlResponses = Invoke-HttpBatch $controlSpecs $concurrency $false
    $controlP95 = Get-Percentile @($controlResponses | ForEach-Object { [double]$_.latency_ms }) 0.95
  }

  $tierP95 = Get-Percentile $latencies 0.95
  $tierResults += [pscustomobject]@{
    concurrency = $concurrency
    requests = $requestCount
    valid_health_200 = $tierValid
    invalid_health_200 = $tierInvalid
    throttled_429 = @($codes | Where-Object { $_ -eq 429 }).Count
    server_5xx = @($codes | Where-Object { $_ -ge 500 }).Count
    transport_fail = @($codes | Where-Object { $_ -eq 0 }).Count
    other_status = @($codes | Where-Object { ($_ -ne 0) -and ($_ -ne 200) -and ($_ -ne 429) -and ($_ -lt 500) }).Count
    p50_ms = Get-Percentile $latencies 0.50
    p95_ms = $tierP95
    p99_ms = Get-Percentile $latencies 0.99
    edge_control_p95_ms = $controlP95
    worker_share_p95_ms = if ($null -ne $controlP95) { [Math]::Round($tierP95 - $controlP95, 1) } else { $null }
  }
  Write-Host ("[phase6-scale] READ c={0,-2} n={1,-3} valid-health={2,-3} 429={3,-3} 5xx={4,-3} transport={5,-3} p95={6}ms" -f `
    $concurrency, $requestCount, $tierValid, $tierResults[-1].throttled_429, $tierResults[-1].server_5xx,
    $tierResults[-1].transport_fail, $tierP95)
}

Require ($script:workerRequestsIssued -eq 800) "read tier did not issue exactly 800 Worker requests"
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
  foreach ($response in $postResponses) {
    $id = [string]$response.key
    $body = ConvertFrom-JsonSafe ([string]$response.response_text)
    $errors = @()
    $readbackVerified = $false
    $responseId = if ($null -ne $body -and (Has-Property $body "id")) { [string]$body.id } else { $null }
    if ([int]$response.status_code -eq 201) {
      $errors = @(Test-CreateBody $body $expectedById[$id])
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
    $postEvidence.Add([pscustomobject]@{
      id = $id
      response_id = $responseId
      status_code = [int]$response.status_code
      latency_ms = [double]$response.latency_ms
      response_readback_verified = $readbackVerified
      request_id = if ($null -ne $body) { [string]$body.request_id } else { "" }
      audit_event_id = if ($null -ne $body) { [string]$body.audit_event_id } else { "" }
      prompt_sha256 = [string]$expectedById[$id].prompt_sha256
      html_sha256 = [string]$expectedById[$id].html_sha256
      audit_persisted_verified = ($readbackVerified -and $body.audit_persisted -eq $true)
      audit_readback_verified = ($readbackVerified -and $body.audit_readback_verified -eq $true)
      validation_errors = @($errors)
    })
  }

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

foreach ($response in $deleteResponses) {
  $id = [string]$response.key
  $create = @($postEvidence | Where-Object { $_.id -eq $id })[0]
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
    id = $id
    status_code = [int]$response.status_code
    latency_ms = [double]$response.latency_ms
    expected_deleted_record = $expectDeleted
    cleanup_verified = $verified
    request_id = if ($null -ne $body) { [string]$body.request_id } else { "" }
    audit_event_id = if ($null -ne $body) { [string]$body.audit_event_id } else { "" }
    audit_persisted_verified = ($verified -and $body.audit_persisted -eq $true)
    audit_readback_verified = ($verified -and $body.audit_readback_verified -eq $true)
    delete_readback_verified = ($verified -and $body.delete_readback_verified -eq $true)
    validation_errors = @($errors)
  })
}

Require ($postResponses.Count -eq 50) "write tier did not issue exactly 50 POST requests"
Require ($deleteResponses.Count -eq 50) "cleanup tier did not issue exactly 50 DELETE requests"
Require ($script:workerRequestsIssued -eq $maxWorkerRequests) "Worker request count is not exactly $maxWorkerRequests"

$read429 = [int](($tierResults | Measure-Object -Property throttled_429 -Sum).Sum)
$read5xx = [int](($tierResults | Measure-Object -Property server_5xx -Sum).Sum)
$readTransport = [int](($tierResults | Measure-Object -Property transport_fail -Sum).Sum)
$readOther = [int](($tierResults | Measure-Object -Property other_status -Sum).Sum)
$post429 = @($postResponses | Where-Object { $_.status_code -eq 429 }).Count
$delete429 = @($deleteResponses | Where-Object { $_.status_code -eq 429 }).Count
$server5xxTotal = $read5xx + @($postResponses | Where-Object { $_.status_code -ge 500 }).Count + @($deleteResponses | Where-Object { $_.status_code -ge 500 }).Count
$transportTotal = $readTransport + @($postResponses | Where-Object { $_.status_code -eq 0 }).Count + @($deleteResponses | Where-Object { $_.status_code -eq 0 }).Count
$throttled429Total = $read429 + $post429 + $delete429
$acceptableStatusCount = $validHealthJsonCount + @($postResponses | Where-Object { $_.status_code -ge 200 -and $_.status_code -lt 300 }).Count +
  @($deleteResponses | Where-Object { $_.status_code -ge 200 -and $_.status_code -lt 300 }).Count + $read429
$successRatio = [Math]::Round($acceptableStatusCount / $maxWorkerRequests, 4)
$worstReadP95 = [double](($tierResults | Measure-Object -Property p95_ms -Maximum).Maximum)
$postLatencies = @($postResponses | ForEach-Object { [double]$_.latency_ms })
$deleteLatencies = @($deleteResponses | ForEach-Object { [double]$_.latency_ms })
$postP95 = Get-Percentile $postLatencies 0.95
$deleteP95 = Get-Percentile $deleteLatencies 0.95
$worstWorkerP95 = [Math]::Max($worstReadP95, [Math]::Max($postP95, $deleteP95))

$failures = [Collections.Generic.List[string]]::new()
if ($successRatio -lt [double]$criterion.pass_criteria.min_success_ratio) { $failures.Add("success_ratio_below_threshold") }
if ($worstWorkerP95 -gt [double]$criterion.pass_criteria.max_p95_ms) { $failures.Add("p95_above_threshold") }
if ($server5xxTotal -gt [int]$criterion.pass_criteria.own_5xx_allowed) { $failures.Add("own_5xx_above_threshold") }
if ($transportTotal -gt 0) { $failures.Add("transport_failure") }
if ($readOther -gt 0) { $failures.Add("unexpected_read_status") }
if ($invalidHealthJsonCount -gt 0) { $failures.Add("invalid_health_json") }
if ($post429 -gt 0 -or $delete429 -gt 0) { $failures.Add("write_or_cleanup_throttled") }
if ($recordLossCount -gt 0) { $failures.Add("write_record_loss") }
if ([int]$duplicateCount -gt 0) { $failures.Add("duplicate_write_readback") }
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
  result = if ($failures.Count -eq 0) { "verified" } else { "failed" }
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
  }
  request_budget = [ordered]@{
    worker_cap = $maxWorkerRequests
    worker_requests_issued = $script:workerRequestsIssued
    read_requests_issued = $readExpected
    create_requests_issued = $postResponses.Count
    cleanup_delete_requests_issued = $deleteResponses.Count
    control_edge_requests_issued = $script:controlRequestsIssued
    cap_respected = ($script:workerRequestsIssued -le $maxWorkerRequests)
    exact_plan_executed = ($script:workerRequestsIssued -eq 900)
  }
  read_tiers = @($tierResults)
  health_validation = [ordered]@{
    valid_json_count = $validHealthJsonCount
    invalid_json_or_contract_count = $invalidHealthJsonCount
    validation_failures = @($healthValidationFailures | Select-Object -Unique)
  }
  write_tier = [ordered]@{
    concurrency = $writeConcurrency
    records_planned = $writeExpected
    valid_post_insert_readbacks = $validCreatedIds.Count
    record_loss_count = $recordLossCount
    duplicate_count = [int]$duplicateCount
    field_failure_count = $createFieldFailureCount
    hash_failure_count = $createHashFailureCount
    audit_failure_count = $createAuditFailureCount
    throttled_429 = $post429
    server_5xx = @($postResponses | Where-Object { $_.status_code -ge 500 }).Count
    transport_fail = @($postResponses | Where-Object { $_.status_code -eq 0 }).Count
    p50_ms = Get-Percentile $postLatencies 0.50
    p95_ms = $postP95
    p99_ms = Get-Percentile $postLatencies 0.99
    records = @($postEvidence)
  }
  cleanup = [ordered]@{
    verified_count = $cleanupVerifiedCount
    required_count = $writeExpected
    complete = ($cleanupVerifiedCount -eq $writeExpected)
    throttled_429 = $delete429
    unclean_throttle_count = $uncleanThrottleCount
    server_5xx = @($deleteResponses | Where-Object { $_.status_code -ge 500 }).Count
    transport_fail = @($deleteResponses | Where-Object { $_.status_code -eq 0 }).Count
    p95_ms = $deleteP95
    records = @($cleanupEvidence)
  }
  aggregate = [ordered]@{
    success_ratio = $successRatio
    worst_p95_ms = $worstWorkerP95
    throttled_429_total = $throttled429Total
    server_5xx_total = $server5xxTotal
    transport_fail_total = $transportTotal
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
    "The authorization token is neither printed nor persisted.",
    "Control requests use the Cloudflare edge path and are not Worker requests."
  )
}

$json = $report | ConvertTo-Json -Depth 10
$utf8NoBom = [Text.UTF8Encoding]::new($false)
$stream = [IO.File]::Open($reportPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
try {
  $writer = [IO.StreamWriter]::new($stream, $utf8NoBom)
  try { $writer.Write($json) } finally { $writer.Dispose() }
} finally {
  if ($null -ne $stream) { $stream.Dispose() }
}
$reportSha256 = (Get-FileHash -LiteralPath $reportPath -Algorithm SHA256).Hash.ToLowerInvariant()
$shaStream = [IO.File]::Open($shaPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
try {
  $shaWriter = [IO.StreamWriter]::new($shaStream, $utf8NoBom)
  try { $shaWriter.Write("$reportSha256  $([IO.Path]::GetFileName($reportPath))`n") } finally { $shaWriter.Dispose() }
} finally {
  if ($null -ne $shaStream) { $shaStream.Dispose() }
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

if ($failures.Count -gt 0) {
  Fail ("criterion failed: " + (@($failures) -join "; "))
}
Write-Host "[phase6-scale] VERIFIED: declared zero-card scale criterion met; Owner gate remains unchanged"
} finally {
  $authValue = $null
  $postSpecs = $null
  $deleteSpecs = $null
  if ($null -ne $httpClient) { $httpClient.Dispose() }
  if ($null -ne $handler) { $handler.Dispose() }
}
exit 0

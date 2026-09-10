param(
  [string]$LiveFreeReportPath = ".codex\runs\CURRENT\capability\live-llm-free-provider\report-20260720-224943.json",
  [string]$HostedBuildReportPath = ".codex\runs\CURRENT\master-goal\t2\hosted-build-preview\report.json",
  [string]$SourceParityReportPath = ".codex\runs\CURRENT\llm-gateway\cloudflare-hosted-readonly\report.json",
  [string]$D1ReportPath = ".codex\runs\CURRENT\master-goal\t3\cloudflare-d1-local\report.json",
  [string]$BrowserReportPath = ".codex\runs\CURRENT\master-goal\t3\stateful-build-browser\report.json",
  [string]$CapabilityStatePath = "docs\runtime-state\capability-gates.json",
  [string]$EvidencePath = ".codex\runs\CURRENT\llm-gateway\evidence-chain\report.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "Live LLM evidence-chain verification failed: $Message" }
}

function Assert-Equal($Actual, $Expected, [string]$Label) {
  Assert-True ($Actual -eq $Expected) "$Label expected=$Expected actual=$Actual"
}

function Assert-Boolean($Payload, [string]$Name, [bool]$Expected, [string]$Label) {
  $property = $Payload.PSObject.Properties[$Name]
  Assert-True ($null -ne $property -and $property.Value -is [bool]) "$Label missing boolean $Name"
  Assert-Equal ([bool]$property.Value) $Expected "$Label $Name"
}

function Resolve-RepoPath([string]$Candidate, [string]$Label, [bool]$MustExist = $true) {
  Assert-True (-not [string]::IsNullOrWhiteSpace($Candidate)) "$Label path is empty"
  $resolved = if ([IO.Path]::IsPathRooted($Candidate)) {
    [IO.Path]::GetFullPath($Candidate)
  } else {
    [IO.Path]::GetFullPath((Join-Path $repoRoot $Candidate))
  }
  $root = [IO.Path]::GetFullPath($repoRoot).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  Assert-True $resolved.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) "$Label must stay inside the repository"
  if ($MustExist) { Assert-True (Test-Path -LiteralPath $resolved) "$Label not found: $Candidate" }
  return $resolved
}

function Read-Json([string]$Candidate, [string]$Label) {
  $resolved = Resolve-RepoPath $Candidate $Label $true
  try {
    return [pscustomobject]@{
      path = $resolved
      payload = (Get-Content -LiteralPath $resolved -Raw -Encoding UTF8 | ConvertFrom-Json)
    }
  } catch {
    throw "Live LLM evidence-chain verification failed: $Label is not valid JSON"
  }
}

function Assert-HostedHttps([string]$Value, [string]$Label) {
  try { $uri = [Uri]$Value } catch { throw "Live LLM evidence-chain verification failed: $Label is not a URL" }
  Assert-Equal $uri.Scheme "https" "$Label scheme"
  Assert-True (-not $uri.IsLoopback) "$Label cannot be localhost"
  Assert-True ([string]::IsNullOrWhiteSpace($uri.UserInfo)) "$Label cannot contain credentials"
}

function Get-FileSha256([string]$Path) {
  $stream = [IO.File]::OpenRead($Path)
  $sha256 = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace("-", "").ToLowerInvariant()
  } finally {
    $sha256.Dispose()
    $stream.Dispose()
  }
}

function Invoke-GitLine([string[]]$Arguments) {
  $output = & git @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) { throw "Live LLM evidence-chain verification failed: git $($Arguments -join ' ') failed" }
  return (($output | Out-String).Trim())
}

$liveFreeRead = Read-Json $LiveFreeReportPath "Live free-provider report"
$hostedBuildRead = Read-Json $HostedBuildReportPath "Hosted T2 build report"
$sourceRead = Read-Json $SourceParityReportPath "Hosted source-parity report"
$d1Read = Read-Json $D1ReportPath "D1 local report"
$browserRead = Read-Json $BrowserReportPath "Stateful browser report"
$capabilityRead = Read-Json $CapabilityStatePath "Capability-gate state"

$liveFree = $liveFreeRead.payload
$hostedBuild = $hostedBuildRead.payload
$source = $sourceRead.payload
$d1 = $d1Read.payload
$browser = $browserRead.payload
$capabilityState = $capabilityRead.payload

# Independent free-provider proof. This is not the T2 seed call.
Assert-Equal ([string]$liveFree.contract_version) "live-llm-free-provider-proof-v1" "Live free-provider contract"
Assert-Equal ([string]$liveFree.status) "verified" "Live free-provider status"
Assert-Boolean $liveFree "hosted" $true "Live free-provider report"
Assert-Equal ([string]$liveFree.scope) "hosted_https" "Live free-provider scope"
Assert-HostedHttps ([string]$liveFree.base_url) "Live free-provider base URL"
Assert-True ([string]$liveFree.model -like "@cf/*") "Live free-provider model is not a Cloudflare model"
Assert-Equal ([string]$liveFree.provider) "cloudflare_workers_ai" "Live free-provider provider"
Assert-Boolean $liveFree "paid_provider" $false "Live free-provider report"
Assert-Equal ([int]$liveFree.prompts_used) 1 "Live free-provider prompt count"
Assert-True ([int]$liveFree.html_length -ge 400) "Live free-provider HTML length is too small"
Assert-True (-not [string]::IsNullOrWhiteSpace([string]$liveFree.build_id)) "Live free-provider build ID is missing"

$gate = $capabilityState.gates.live_llm_provider_calls
Assert-Boolean $gate "owner_granted" $true "Live LLM capability gate"
Assert-Boolean $gate "live_verified" $true "Live LLM capability gate"
Assert-Boolean $gate "paid_provider" $false "Live LLM capability gate"
Assert-Equal ([string]$gate.provider) "cloudflare_workers_ai" "Live LLM capability provider"
Assert-Equal ([string]$gate.verifier) "scripts/verify-live-llm-free-provider.ps1" "Live LLM capability verifier"
$gateEvidence = Resolve-RepoPath ([string]$gate.evidence_artifact) "Live LLM capability artifact" $true
Assert-Equal $gateEvidence $liveFreeRead.path "Live LLM capability artifact binding"

# T2 is a separate single-call hosted browser proof and the seed for D1.
Assert-Equal ([string]$hostedBuild.contract_version) "t2-hosted-workers-ai-build-browser-proof-v1" "T2 contract"
Assert-Equal ([string]$hostedBuild.status) "verified" "T2 status"
Assert-HostedHttps ([string]$hostedBuild.base_url) "T2 base URL"
Assert-Equal ([string]$hostedBuild.route) "/workbench" "T2 route"
Assert-Equal ([int]$hostedBuild.build_post_count) 1 "T2 build POST count"
Assert-Equal ([int]$hostedBuild.live_provider_call_count_upper_bound) 1 "T2 provider-call upper bound"
Assert-Equal ([string]$hostedBuild.model) ([string]$liveFree.model) "T2/free-provider model parity"
Assert-Equal ([string]$hostedBuild.response_source) "llm-gateway-boundary" "T2 response source"
Assert-Equal ([string]$hostedBuild.gateway_mode) "cloudflare_workers_ai_live" "T2 gateway mode"
Assert-Equal ([string]$hostedBuild.gateway_provider) "cloudflare-workers-ai" "T2 gateway provider"
Assert-Boolean $hostedBuild "live_provider_calls" $true "T2 report"
Assert-Boolean $hostedBuild "direct_provider_calls" $false "T2 report"
Assert-Boolean $hostedBuild "persisted" $false "T2 report"
Assert-Boolean $hostedBuild "preview_heading_verified" $true "T2 report"
Assert-Boolean $hostedBuild "preview_interaction_verified" $true "T2 report"
Assert-Boolean $hostedBuild "secret_output" $false "T2 report"
Assert-True ([string]$hostedBuild.html_sha256 -match "^[0-9a-f]{64}$") "T2 HTML hash shape is invalid"
Assert-True (@($hostedBuild.console_errors).Count -eq 0 -and @($hostedBuild.page_errors).Count -eq 0) "T2 browser errors are not empty"
Assert-True ([int]$liveFree.html_length -ne [int]$hostedBuild.html_bytes) "Independent live reports unexpectedly describe the same HTML length"
Assert-True ([string]$liveFree.verified_at_utc -ne [string]$hostedBuild.generated_at) "Independent live reports unexpectedly share one timestamp"
$t2Directory = Split-Path -Parent $hostedBuildRead.path
$htmlReference = [string]$hostedBuild.generated_html
Assert-True (-not [IO.Path]::IsPathRooted($htmlReference)) "T2 HTML reference must be relative"
$t2Html = [IO.Path]::GetFullPath((Join-Path $t2Directory $htmlReference))
Assert-True $t2Html.StartsWith($t2Directory + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) "T2 HTML reference escapes its report directory"
Assert-True (Test-Path -LiteralPath $t2Html) "T2 HTML artifact is missing"
Assert-Equal (Get-FileSha256 $t2Html) ([string]$hostedBuild.html_sha256) "T2 HTML artifact hash"
Assert-Equal ([int](Get-Item -LiteralPath $t2Html).Length) ([int]$hostedBuild.html_bytes) "T2 HTML byte count"

# The public Preview Worker source proof is valid on its own. T2 does not name
# its configured gateway origin or deployed source SHA, so exact historical
# T2-to-source attribution must remain false.
Assert-Equal ([string]$source.contract_version) "cloudflare-llm-gateway-hosted-readonly-v1" "Source-parity contract"
Assert-Equal ([string]$source.status) "verified" "Source-parity status"
Assert-Equal ([string]$source.transport) "public_https_get_only" "Source-parity transport"
Assert-HostedHttps ([string]$source.base_url) "Source-parity base URL"
Assert-Boolean $source.source "blob_parity" $true "Source-parity source"
Assert-Boolean $source.source "worktree_clean" $true "Source-parity source"
Assert-True ([string]$source.source.deployed_commit_sha -match "^[0-9a-f]{40}$") "Deployed commit shape is invalid"
Assert-True ([string]$source.source.deployed_archive_sha256 -match "^[0-9a-f]{64}$") "Deployed archive hash shape is invalid"
Assert-Boolean $source.health "ai_binding_configured" $true "Source-parity health"
Assert-Boolean $source.health "gateway_auth_configured" $true "Source-parity health"
Assert-Boolean $source.health "live_provider_calls_available" $true "Source-parity health"
Assert-Boolean $source.health "live_provider_calls" $false "Source-parity health"
Assert-Boolean $source.health "direct_provider_calls" $false "Source-parity health"
Assert-Boolean $source.health "secret_output" $false "Source-parity health"
Assert-Boolean $source "token_used" $false "Source-parity report"
Assert-Boolean $source "inference_executed" $false "Source-parity report"
Assert-Boolean $source "provider_write" $false "Source-parity report"
Assert-Boolean $source "production_deploy" $false "Source-parity report"
Assert-Boolean $source "release_promotion" $false "Source-parity report"
Assert-Boolean $source "secret_output" $false "Source-parity report"
Assert-True (@($source.models.ids) -contains [string]$hostedBuild.model) "T2 model is not in the source-bound allowlist"
$deployedCommit = [string]$source.source.deployed_commit_sha
& git cat-file -e "$deployedCommit^{commit}" 2>$null
Assert-True ($LASTEXITCODE -eq 0) "Deployed source commit is unavailable locally"
& git merge-base --is-ancestor $deployedCommit HEAD
Assert-True ($LASTEXITCODE -eq 0) "Deployed source commit is not an ancestor of HEAD"
$deployedTree = Invoke-GitLine @("rev-parse", "${deployedCommit}:services/cloudflare-llm-gateway")
$currentTree = Invoke-GitLine @("rev-parse", "HEAD:services/cloudflare-llm-gateway")
Assert-Equal $deployedTree ([string]$source.source.deployed_tree_sha) "Deployed source tree"
Assert-Equal $currentTree ([string]$source.source.current_tree_sha) "Current source tree"
Assert-Equal $deployedTree $currentTree "Deployed/current source tree parity"
foreach ($property in @($source.source.blobs.PSObject.Properties)) {
  $path = [string]$property.Name
  Assert-True $path.StartsWith("services/cloudflare-llm-gateway/", [StringComparison]::Ordinal) "Source blob path escapes the LLM service"
  Assert-Equal (Invoke-GitLine @("rev-parse", "HEAD:$path")) ([string]$property.Value) "Source blob $path"
}
& git diff --quiet -- services/cloudflare-llm-gateway
Assert-True ($LASTEXITCODE -eq 0) "Current LLM service worktree is dirty"

# T2 HTML is audit-persisted locally, then rendered and interacted with through
# the exact D1 ID/hash. Neither verifier sends another provider request.
Assert-Equal ([string]$d1.contract_version) "cloudflare-d1-stateful-runtime-local-proof-v1" "D1 contract"
Assert-Equal ([string]$d1.status) "verified" "D1 status"
Assert-Boolean $d1 "dev_only" $true "D1 report"
Assert-Boolean $d1 "hosted_proof" $false "D1 report"
Assert-Boolean $d1 "live_provider_call_executed" $false "D1 report"
Assert-Boolean $d1 "seed_persisted" $true "D1 report"
Assert-Boolean $d1 "seed_audit_persisted" $true "D1 report"
Assert-Boolean $d1 "secret_output" $false "D1 report"
Assert-Boolean $d1 "raw_build_prompt_output" $false "D1 report"
Assert-Boolean $d1 "raw_prompt_output" $false "D1 report"
Assert-Equal ([string]$d1.seed_html_sha256) ([string]$hostedBuild.html_sha256) "T2/D1 HTML hash"
Assert-True ([string]$d1.seed_build_id -match "^[A-Za-z0-9_-]{1,64}$") "D1 seed build ID is invalid"

Assert-Equal ([string]$browser.contract_version) "stateful-build-browser-proof-v1" "Browser contract"
Assert-Equal ([string]$browser.status) "verified" "Browser status"
Assert-Boolean $browser "dev_only" $true "Browser report"
Assert-Boolean $browser "hosted_proof" $false "Browser report"
Assert-Boolean $browser "gallery_visible" $true "Browser report"
Assert-Boolean $browser "persisted_build_rendered" $true "Browser report"
Assert-Boolean $browser "interaction_verified" $true "Browser report"
Assert-Boolean $browser "seed_live_provider_calls" $true "Browser report"
Assert-Boolean $browser "verifier_live_provider_calls" $false "Browser report"
Assert-Boolean $browser "direct_provider_calls" $false "Browser report"
Assert-Boolean $browser "secret_output" $false "Browser report"
Assert-Equal ([int]$browser.profile_count) 2 "Browser profile count"
Assert-Equal ([int]$browser.unexpected_requests) 0 "Browser unexpected request count"
Assert-Equal ([string]$browser.build_id) ([string]$d1.seed_build_id) "D1/browser build ID"
Assert-Equal ([string]$browser.html_sha256) ([string]$d1.seed_html_sha256) "D1/browser HTML hash"
Assert-Boolean $browser.frontend_unauthenticated_write_guards "executed" $true "Browser write guard"
Assert-Boolean $browser.frontend_unauthenticated_write_guards "service_auth_forwarded" $false "Browser write guard"
foreach ($profile in @($browser.profiles)) {
  Assert-Boolean $profile "gallery_visible" $true "Browser profile"
  Assert-Boolean $profile "persisted_frame_visible" $true "Browser profile"
  Assert-Boolean $profile "run_to_done_interaction" $true "Browser profile"
  Assert-Boolean $profile.apps_layout "horizontal_overflow" $false "Browser apps layout"
  Assert-Boolean $profile.run_layout "horizontal_overflow" $false "Browser run layout"
  foreach ($counter in @("console_errors", "page_errors", "failed_requests", "unexpected_requests")) {
    Assert-Equal ([int]$profile.$counter) 0 "Browser profile $counter"
  }
}

# Future revalidation must not reproduce the historical weak verifier behavior.
$liveVerifierSource = Get-Content -LiteralPath "scripts\verify-live-llm-free-provider.ps1" -Raw
foreach ($marker in @(
  "Save-CapabilityState",
  '$gate.live_verified = $false',
  'response proves one live provider call',
  'response rejects direct provider bypass',
  'response crossed the LLM Gateway boundary',
  'response reports no secret output',
  'Does not claim exact deployed-source attribution'
)) {
  Assert-True $liveVerifierSource.Contains($marker) "Hardened live verifier is missing marker: $marker"
}

$evidence = [ordered]@{
  contract_version = "live-llm-bounded-evidence-chain-v1"
  status = "verified_bounded_evidence"
  checked_at = [DateTime]::UtcNow.ToString("o")
  hosted_live_seed_call_verified = $true
  free_provider_policy_verified = $true
  standalone_source_parity_verified = $true
  d1_local_audit_binding_verified = $true
  browser_local_binding_verified = $true
  evidence_reports_conflated = $false
  independent_live_proof_executions = 2
  known_proof_call_upper_bound_sum = 2
  verifier_live_provider_calls = $false
  historical_t2_gateway_origin_attribution_verified = $false
  historical_t2_source_commit_attribution_verified = $false
  full_source_bound_live_call_chain = $false
  progress_credit_recommended = 0
  seed = [ordered]@{
    model = [string]$hostedBuild.model
    html_sha256 = [string]$hostedBuild.html_sha256
    d1_build_id = [string]$d1.seed_build_id
    d1_audit_persisted = $true
    browser_profiles = [int]$browser.profile_count
  }
  source = [ordered]@{
    preview_origin = [string]$source.base_url
    deployed_commit_sha = $deployedCommit
    deployed_archive_sha256 = [string]$source.source.deployed_archive_sha256
    tree_parity = $true
  }
  dev_only_label = "DEV-ONLY; hosted proof still blocked"
  direct_provider_calls = $false
  provider_write = $false
  production_deploy = $false
  release_promotion = $false
  secret_output = $false
  non_claims = @(
    "The free-provider report and T2 seed report are two independent live proof executions and are not one call.",
    "The T2 report does not name its configured gateway origin or deployed source commit, so exact historical source attribution remains unverified.",
    "D1 persistence and the two-profile browser proof are DEV-ONLY; hosted proof still blocked.",
    "This verifier performs no network request, provider call, cloud write, deployment, or release action.",
    "No LLM Gateway percentage increase is recommended from this bounded chain."
  )
}

$resolvedEvidence = Resolve-RepoPath $EvidencePath "Evidence output" $false
$evidenceParent = Split-Path -Parent $resolvedEvidence
New-Item -ItemType Directory -Path $evidenceParent -Force | Out-Null
$evidence | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolvedEvidence -Encoding UTF8
Write-Host "[live-llm-chain] status=verified_bounded_evidence proof_calls=2 new_provider_calls=0 source_bound_chain=false"
Write-Host "[live-llm-chain] DEV-ONLY; hosted proof still blocked"

[CmdletBinding()]
param(
  [string]$BaseUrl = "https://cloud-superbrain-stateful-runtime-preview.strazzusochr.workers.dev",
  [Parameter(Mandatory = $true)][ValidatePattern("^[0-9a-f]{40}$")][string]$ExpectedSourceCommitSha,
  [Parameter(Mandatory = $true)][ValidatePattern("^[0-9a-f]{64}$")][string]$ExpectedSourceArchiveSha256,
  [Parameter(Mandatory = $true)][ValidatePattern("^[0-9a-f]{64}$")][string]$ExpectedSourceBundleSha256,
  [string]$Repository = "strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM",
  [Parameter(Mandatory = $true)][ValidatePattern("^[A-Za-z0-9._/-]+$")][string]$Branch,
  [string]$TokenEnvironmentVariable = "AGENT_API_AUTH_TOKEN",
  [string]$RubricApprovalCommit = $env:LAYER_CREDIT_RUBRIC_APPROVAL_SHA,
  [string]$OwnerGrantRef = $env:HOSTED_MCP_WRITE_OWNER_GRANT_REF,
  [string]$OwnerGrantCommitSha = $env:HOSTED_MCP_WRITE_OWNER_GRANT_COMMIT_SHA,
  [switch]$AuthorizeHostedWrite,
  [string]$OutDir = ".phase1-artifacts/mcp-gateway/hosted-auth-scope"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$rubricPath = "docs/runtime-contracts/layer-credit-rubric.md"
$contractVersion = "o4-live-agent-mcp-write-v1"
$sanctionedBaseUrl = "https://cloud-superbrain-stateful-runtime-preview.strazzusochr.workers.dev"
function Get-RawGitBlobSha256([string]$Commit, [string]$Path) {
  $psi = [Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = "git"
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  foreach ($argument in @("-C", $repoRoot, "cat-file", "blob", "$($Commit):$Path")) { [void]$psi.ArgumentList.Add($argument) }
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $psi
  $stream = [IO.MemoryStream]::new()
  try {
    Assert-True "git_blob_process_start_failed:$Path" ($process.Start())
    $process.StandardOutput.BaseStream.CopyTo($stream)
    $process.WaitForExit()
    Assert-True "git_blob_read_failed:$Path" ($process.ExitCode -eq 0)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream.ToArray()))).Replace("-", "").ToLowerInvariant() }
    finally { $sha.Dispose() }
  } finally { $stream.Dispose(); $process.Dispose() }
}
function Get-CandidateBlobBindings {
  $verifierPaths = @("scripts/verify-mcp-candidate-sbom.ps1","scripts/verify-mcp-hosted-audit-readback-rollback.ps1","scripts/verify-mcp-hosted-auth-scope.ps1","scripts/verify-mcp-hosted-timeout-idempotency.ps1","scripts/verify-mcp-hosted-write.ps1") | Sort-Object
  $lines = @($verifierPaths | ForEach-Object { "$_`t$(Get-RawGitBlobSha256 $ExpectedSourceCommitSha $_)" })
  $bytes = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
  $sha = [Security.Cryptography.SHA256]::Create()
  try { $manifest = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant() }
  finally { $sha.Dispose() }
  return @{
    verifier_blob_sha256 = $manifest
    runtime_blob_sha256 = Get-RawGitBlobSha256 $ExpectedSourceCommitSha "services/cloudflare-stateful-runtime/src/mcp-hosted.js"
    rubric_blob_sha256 = Get-RawGitBlobSha256 $ExpectedSourceCommitSha "docs/runtime-contracts/layer-credit-rubric.md"
    capability_gate_blob_sha256 = Get-RawGitBlobSha256 $ExpectedSourceCommitSha "docs/runtime-state/capability-gates.json"
  }
}


function Assert-True([string]$Label, [bool]$Condition) { if (-not $Condition) { throw $Label } }
function Get-PropertyValue($Object, [string]$Name) {
  if ($null -eq $Object) { return $null }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return $property.Value
}
function Write-TextAtomic([string]$Path, [string]$Text) {
  $full = [IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($full)) | Out-Null
  $temporary = "$full.$([Guid]::NewGuid().ToString('N')).tmp"
  try {
    [IO.File]::WriteAllText($temporary, $Text, (New-Object Text.UTF8Encoding($false)))
    [IO.File]::Move($temporary, $full, $true)
  } finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
}
function Write-Evidence($Value) {
  $path = Join-Path $OutDir "report.json"
  Write-TextAtomic $path (($Value | ConvertTo-Json -Depth 20) + [Environment]::NewLine)
  $full = [IO.Path]::GetFullPath((Join-Path $repoRoot $path))
  $digest = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLowerInvariant()
  Write-TextAtomic (Join-Path $OutDir "report.sha256") ("$digest  report.json$([Environment]::NewLine)")
  return $digest
}
function Invoke-JsonRequest([string]$Method, [string]$Uri, [hashtable]$Headers = @{}, $Body = $null) {
  $parameters = @{ Uri=$Uri; Method=$Method; Headers=$Headers; UseBasicParsing=$true; TimeoutSec=30; SkipHttpErrorCheck=$true; MaximumRedirection=0 }
  if ($null -ne $Body) { $parameters.ContentType="application/json"; $parameters.Body=$Body | ConvertTo-Json -Depth 12 -Compress }
  try { $response = Invoke-WebRequest @parameters } catch { throw "hosted_http_transport_failed" }
  $json = $null
  if (-not [string]::IsNullOrWhiteSpace([string]$response.Content)) {
    try { $json = $response.Content | ConvertFrom-Json } catch { throw "hosted_http_json_invalid" }
  }
  return @{ status=[int]$response.StatusCode; json=$json }
}
function Assert-HostedTarget([string]$Value) {
  $uri = $null
  Assert-True "base_url_invalid" ([Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri))
  Assert-True "hosted_https_required" ($uri.Scheme -eq "https")
  Assert-True "localhost_forbidden" ($uri.DnsSafeHost.ToLowerInvariant() -notin @("localhost", "127.0.0.1", "::1"))
  Assert-True "base_url_credentials_forbidden" ([string]::IsNullOrEmpty($uri.UserInfo))
  Assert-True "sanctioned_worker_hostname_required" ($Value.Trim().TrimEnd("/") -ceq $sanctionedBaseUrl -and $uri.Port -eq 443 -and $uri.AbsolutePath -eq "/" -and [string]::IsNullOrEmpty($uri.Query))
}
function Assert-CandidateBinding {
  Assert-True "token_environment_variable_must_be_exact" ($TokenEnvironmentVariable -ceq "AGENT_API_AUTH_TOKEN")
  Assert-True "head_must_equal_candidate_commit" ((& git -C $repoRoot rev-parse HEAD).Trim() -ceq $ExpectedSourceCommitSha)
  $relevantPaths = @("scripts/verify-mcp-hosted-write.ps1","scripts/verify-mcp-hosted-auth-scope.ps1","scripts/verify-mcp-hosted-timeout-idempotency.ps1","scripts/verify-mcp-hosted-audit-readback-rollback.ps1","scripts/verify-mcp-candidate-sbom.ps1","services/cloudflare-stateful-runtime/src/mcp-hosted.js","services/cloudflare-stateful-runtime/src/index.js","services/cloudflare-stateful-runtime/migrations/0006_hosted_mcp_write.sql","services/cloudflare-stateful-runtime/migrations/0008_hosted_mcp_timeout_effects.sql","docs/runtime-contracts/layer-credit-rubric.md","docs/runtime-state/capability-gates.json")
  Assert-True "candidate_relevant_path_drift_forbidden" ([string]::IsNullOrWhiteSpace((& git -C $repoRoot status --porcelain=v1 --untracked-files=all -- @relevantPaths | Out-String)))
  $script:CandidateBlobBindings = Get-CandidateBlobBindings
  Assert-True "owner_grant_commit_required" ($OwnerGrantCommitSha -match '^[0-9a-f]{40}$')
  & git -C $repoRoot cat-file -e "$OwnerGrantCommitSha^{commit}" 2>$null; Assert-True "owner_grant_commit_unknown" ($LASTEXITCODE -eq 0)
  & git -C $repoRoot merge-base --is-ancestor $OwnerGrantCommitSha $ExpectedSourceCommitSha 2>$null; Assert-True "owner_grant_commit_not_candidate_ancestor" ($LASTEXITCODE -eq 0)
  $ownerGates = (& git -C $repoRoot show "${OwnerGrantCommitSha}:docs/runtime-state/capability-gates.json" 2>$null | Out-String) | ConvertFrom-Json
  Assert-True "owner_grant_capability_mismatch" ($ownerGates.gates.live_mcp_writes.owner_granted -eq $true -and [string]$ownerGates.gates.live_mcp_writes.owner_grant_ref -ceq $OwnerGrantRef)
  $archive = Join-Path ([IO.Path]::GetTempPath()) ("mcp-candidate-{0}.tar" -f [Guid]::NewGuid().ToString("N"))
  try { & git -C $repoRoot archive --format=tar --output=$archive $ExpectedSourceCommitSha; Assert-True "candidate_archive_reconstruction_failed" ($LASTEXITCODE -eq 0); Assert-True "candidate_archive_digest_mismatch" ((Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $ExpectedSourceArchiveSha256) }
  finally { if ([IO.File]::Exists($archive)) { [IO.File]::Delete($archive) } }
}
function Assert-RubricApproval {
  Assert-True "authorize_switch_required" ([bool]$AuthorizeHostedWrite)
  Assert-True "hosted_write_environment_authorization_required" ($env:HOSTED_MCP_WRITE_AUTHORIZED -ceq "true")
  Assert-True "owner_grant_ref_required" (-not [string]::IsNullOrWhiteSpace($OwnerGrantRef))
  Assert-True "rubric_approval_commit_required" ($RubricApprovalCommit -match "^[0-9a-f]{40}$")
  & git -C $repoRoot cat-file -e "$RubricApprovalCommit^{commit}" 2>$null
  Assert-True "rubric_approval_commit_unknown" ($LASTEXITCODE -eq 0)
  & git -C $repoRoot merge-base --is-ancestor $RubricApprovalCommit $ExpectedSourceCommitSha 2>$null
  Assert-True "rubric_approval_commit_not_ancestor" ($LASTEXITCODE -eq 0)
  $rubric = (& git -C $repoRoot show "${RubricApprovalCommit}:$rubricPath" 2>$null | Out-String)
  Assert-True "rubric_not_owner_approved" (
    $rubric -match '(?m)^Status:\s*`APPROVED`\s*$' -and
    $rubric -match '(?m)^Credit-Anwendung erlaubt:\s*`true`\s*$' -and
    $rubric.Contains("scripts/verify-mcp-hosted-auth-scope.ps1")
  )
}
function New-Probe([string]$TargetRepository, [string]$TargetBranch) {
  $suffix = [Guid]::NewGuid().ToString("N")
  return [ordered]@{
    tool_request_id = "o4-runtime-$suffix"
    run_id = "o4-runtime-run-$suffix"
    session_id = [Guid]::NewGuid().ToString()
    agent_role = "coder"
    repository = $TargetRepository
    branch = $TargetBranch
    channel = "runtime"
    idempotency_key = "o4-runtime-$suffix"
    simulate_commit_audit_failure = $false
  }
}

$base = $BaseUrl.Trim().TrimEnd("/")
$token = ""
$reportBase = [ordered]@{
  contract_version = "mcp-hosted-auth-scope-evidence-v2"
  evidence_ref = "hosted_mcp_caller_auth_exact_scope_verified"
  checked_at = [DateTime]::UtcNow.ToString("o")
  base_url = $base
  source_commit_sha = $ExpectedSourceCommitSha
  source_archive_sha256 = $ExpectedSourceArchiveSha256
  source_bundle_sha256 = $ExpectedSourceBundleSha256
  repository = $Repository
  branch = $Branch
  rubric_approval_commit = $RubricApprovalCommit
  owner_grant_ref_present = -not [string]::IsNullOrWhiteSpace($OwnerGrantRef)
  owner_grant_commit_sha = $OwnerGrantCommitSha
  token_environment_variable = $TokenEnvironmentVariable
  token_output = $false
  provider_writes = $false
  production_deploy = $false
  secret_output = $false
}

Push-Location $repoRoot
try {
  Assert-HostedTarget $base
  Assert-RubricApproval
  Assert-CandidateBinding
  $canonicalBranch = $Branch.ToLowerInvariant() -replace '^refs/heads/','' -replace '^origin/',''
  Assert-True "protected_branch_forbidden" ($Branch -ceq $Branch.Trim() -and $Branch -notmatch '//' -and -not (@($Branch.Split("/")) -contains "..") -and $canonicalBranch -notin @("main","master","default","trunk","production","prod"))
  $token = [Environment]::GetEnvironmentVariable($TokenEnvironmentVariable)
  Assert-True "hosted_write_token_required" (-not [string]::IsNullOrWhiteSpace($token))

  $health = Invoke-JsonRequest "GET" "$base/api/v1/health"
  Assert-True "health_http_200_required" ($health.status -eq 200)
  Assert-True "health_source_commit_mismatch" ([string](Get-PropertyValue $health.json "source_commit_sha") -eq $ExpectedSourceCommitSha)
  Assert-True "health_source_archive_mismatch" ([string](Get-PropertyValue $health.json "source_archive_sha256") -eq $ExpectedSourceArchiveSha256)
  Assert-True "health_source_bundle_mismatch" ([string](Get-PropertyValue $health.json "source_bundle_sha256") -eq $ExpectedSourceBundleSha256)
  $contractResponse = Invoke-JsonRequest "GET" "$base/mcp/api/v1/tools/live-write/probe/contract"
  Assert-True "contract_http_200_required" ($contractResponse.status -eq 200)
  $contract = $contractResponse.json
  Assert-True "contract_version_mismatch" ([string](Get-PropertyValue $contract "contract_version") -eq $contractVersion)
  Assert-True "dev_only_contract_rejected" (
    (Get-PropertyValue $contract "hosted") -eq $true -and
    (Get-PropertyValue $contract "DEV_ONLY") -eq $false -and
    [string](Get-PropertyValue $contract "mode") -notmatch '(?i)dev-only|local'
  )
  Assert-True "contract_source_commit_mismatch" ([string](Get-PropertyValue $contract "source_commit_sha") -eq $ExpectedSourceCommitSha)
  Assert-True "contract_source_archive_mismatch" ([string](Get-PropertyValue $contract "source_archive_sha256") -eq $ExpectedSourceArchiveSha256)
  Assert-True "contract_source_bundle_mismatch" ([string](Get-PropertyValue $contract "source_bundle_sha256") -eq $ExpectedSourceBundleSha256)
  Assert-True "contract_rubric_approval_binding_mismatch" ([string](Get-PropertyValue $contract "rubric_approval_sha") -ceq $RubricApprovalCommit)
  Assert-True "contract_owner_grant_binding_mismatch" ([string](Get-PropertyValue $contract "owner_grant_commit_sha") -ceq $OwnerGrantCommitSha)
  foreach ($field in @("verifier_blob_sha256", "runtime_blob_sha256", "rubric_blob_sha256", "capability_gate_blob_sha256")) { Assert-True "contract_${field}_mismatch" ([string](Get-PropertyValue $contract $field) -ceq [string]$script:CandidateBlobBindings[$field]) }
  Assert-True "contract_repository_scope_mismatch" ([string](Get-PropertyValue $contract "repository") -eq $Repository)
  Assert-True "contract_branch_scope_mismatch" ([string](Get-PropertyValue $contract "active_branch") -eq $Branch)
  Assert-True "contract_preview_environment_required" ([string](Get-PropertyValue $contract "deployment_environment") -ceq "candidate_preview")
  Assert-True "contract_preview_hostname_mismatch" ([string](Get-PropertyValue $contract "candidate_preview_hostname") -ceq ([Uri]$sanctionedBaseUrl).DnsSafeHost)
  Assert-True "contract_owner_scope_required" ((Get-PropertyValue $contract "owner_scope_approved") -eq $true)
  Assert-True "main_write_must_be_false" ((Get-PropertyValue $contract "main_write_allowed") -eq $false)
  Assert-True "arbitrary_paths_must_be_false" ((Get-PropertyValue $contract "arbitrary_paths_allowed") -eq $false)
  $capabilities = @((Get-PropertyValue $contract "hosted_verifier_capabilities") | ForEach-Object { [string]$_ })
  foreach ($required in @("caller_auth", "exact_scope", "bounded_write")) {
    Assert-True "hosted_capability_missing_$required" ($capabilities -contains $required)
  }

  $missingAuth = Invoke-JsonRequest "POST" "$base/mcp/api/v1/tools/live-write/probe" @{} (New-Probe $Repository $Branch)
  Assert-True "missing_auth_must_return_401" ($missingAuth.status -eq 401)
  $invalidToken = "l5-invalid-$([Guid]::NewGuid().ToString('N'))"
  $invalidAuth = Invoke-JsonRequest "POST" "$base/mcp/api/v1/tools/live-write/probe" @{ "x-superbrain-agent-token"=$invalidToken } (New-Probe $Repository $Branch)
  $invalidToken = ""
  Assert-True "invalid_auth_must_return_401" ($invalidAuth.status -eq 401)
  foreach ($response in @($missingAuth.json, $invalidAuth.json)) {
    if ($null -ne $response) {
      Assert-True "auth_rejection_must_not_claim_write" ((Get-PropertyValue $response "write_performed") -ne $true)
      Assert-True "auth_rejection_must_not_expose_secret" ((Get-PropertyValue $response "secret_output") -ne $true)
    }
  }

  $scopeDenied = Invoke-JsonRequest "POST" "$base/mcp/api/v1/tools/live-write/probe" @{ "x-superbrain-agent-token"=$token } (New-Probe "$Repository-denied" $Branch)
  Assert-True "off_scope_request_must_return_403" ($scopeDenied.status -eq 403)
  if ($null -ne $scopeDenied.json) {
    Assert-True "scope_rejection_must_not_claim_write" ((Get-PropertyValue $scopeDenied.json "write_performed") -ne $true)
    Assert-True "scope_rejection_must_not_expose_secret" ((Get-PropertyValue $scopeDenied.json "secret_output") -ne $true)
  }

  $allowed = Invoke-JsonRequest "POST" "$base/mcp/api/v1/tools/live-write/probe" @{ "x-superbrain-agent-token"=$token } (New-Probe $Repository $Branch)
  Assert-True "exact_scope_write_http_200_required" ($allowed.status -eq 200)
  Assert-True "exact_scope_source_bundle_mismatch" ([string](Get-PropertyValue $allowed.json "source_bundle_sha256") -eq $ExpectedSourceBundleSha256)
  foreach ($field in @("write_performed", "readback_verified", "immutable_receipt_verified", "channel_state_current", "audit_persisted", "live_mcp_writes")) {
    Assert-True "exact_scope_${field}_required" ((Get-PropertyValue $allowed.json $field) -eq $true)
  }
  foreach ($field in @("live_provider_calls", "direct_provider_calls", "production_deploy", "secret_output", "DEV_ONLY")) {
    Assert-True "exact_scope_${field}_must_be_false" ((Get-PropertyValue $allowed.json $field) -eq $false)
  }

  $success = [ordered]@{} + $reportBase
  $success.status = "verified"
  $success.credit_eligible = $true
  $success.missing_auth_http_status = $missingAuth.status
  $success.invalid_auth_http_status = $invalidAuth.status
  $success.off_scope_http_status = $scopeDenied.status
  $success.exact_scope_http_status = $allowed.status
  $success.caller_authentication_verified = $true
  $success.exact_scope_verified = $true
  $success.write_performed = $true
  $success.live_mcp_writes = $true
  $digest = Write-Evidence $success
  Write-Host "[mcp-hosted-auth-scope] PASS evidence_sha256=$digest secret_output=false"
} catch {
  $blocked = [ordered]@{} + $reportBase
  $blocked.status = "blocked"
  $blocked.credit_eligible = $false
  $blocked.blocker = [string]$_.Exception.Message
  $blocked.write_performed = $false
  $blocked.live_mcp_writes = $false
  $digest = Write-Evidence $blocked
  Write-Error "[mcp-hosted-auth-scope] BLOCKED blocker=$($blocked.blocker) evidence_sha256=$digest secret_output=false"
} finally {
  $token = ""
  Pop-Location
}

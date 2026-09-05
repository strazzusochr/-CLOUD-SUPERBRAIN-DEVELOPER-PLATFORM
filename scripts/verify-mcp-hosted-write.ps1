[CmdletBinding()]
param(
  [string]$BaseUrl = "https://cloud-superbrain-stateful-runtime-preview.strazzusochr.workers.dev",
  [Parameter(Mandatory = $true)]
  [ValidatePattern("^[0-9a-f]{40}$")]
  [string]$ExpectedSourceCommitSha,
  [Parameter(Mandatory = $true)]
  [ValidatePattern("^[0-9a-f]{64}$")]
  [string]$ExpectedSourceArchiveSha256,
  [Parameter(Mandatory = $true)][ValidatePattern("^[0-9a-f]{64}$")][string]$ExpectedSourceBundleSha256,
  [string]$Repository = "strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM",
  [Parameter(Mandatory = $true)]
  [ValidatePattern("^[A-Za-z0-9._/-]+$")]
  [string]$Branch,
  [string]$TokenEnvironmentVariable = "AGENT_API_AUTH_TOKEN",
  [string]$RubricApprovalCommit = $env:LAYER_CREDIT_RUBRIC_APPROVAL_SHA,
  [string]$OwnerGrantRef = $env:HOSTED_MCP_WRITE_OWNER_GRANT_REF,
  [string]$OwnerGrantCommitSha = $env:HOSTED_MCP_WRITE_OWNER_GRANT_COMMIT_SHA,
  [switch]$AuthorizeHostedWrite,
  [string]$OutDir = ".phase1-artifacts/mcp-gateway/hosted-write"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$contractVersion = "o4-live-agent-mcp-write-v1"
$evidenceContract = "mcp-hosted-write-evidence-v2"
$evidenceRef = "hosted_mcp_write_readback_audit_verified"
$rubricPath = "docs/runtime-contracts/layer-credit-rubric.md"
$repoRoot = Split-Path -Parent $PSScriptRoot
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


function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) { throw $Label }
}

function Get-PropertyValue($Object, [string]$Name) {
  if ($null -eq $Object) { return $null }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return $property.Value
}

function Write-TextAtomic([string]$Path, [string]$Text) {
  $fullPath = [IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
  $directory = [IO.Path]::GetDirectoryName($fullPath)
  [IO.Directory]::CreateDirectory($directory) | Out-Null
  $temporary = Join-Path $directory (".{0}.{1}.tmp" -f [IO.Path]::GetFileName($fullPath), [Guid]::NewGuid().ToString("N"))
  $utf8 = New-Object Text.UTF8Encoding($false)
  try {
    [IO.File]::WriteAllText($temporary, $Text, $utf8)
    [IO.File]::Move($temporary, $fullPath, $true)
  } finally {
    if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
  }
}

function Write-Evidence($Value) {
  $reportPath = Join-Path $OutDir "report.json"
  Write-TextAtomic $reportPath (($Value | ConvertTo-Json -Depth 20) + [Environment]::NewLine)
  $resolved = [IO.Path]::GetFullPath((Join-Path $repoRoot $reportPath))
  $digest = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash.ToLowerInvariant()
  Write-TextAtomic (Join-Path $OutDir "report.sha256") ("{0}  report.json{1}" -f $digest, [Environment]::NewLine)
  return @{ path = $reportPath; sha256 = $digest }
}

function Invoke-JsonRequest(
  [string]$Method,
  [string]$Uri,
  [hashtable]$Headers = @{},
  $Body = $null
) {
  $parameters = @{
    Uri = $Uri
    Method = $Method
    Headers = $Headers
    UseBasicParsing = $true
    TimeoutSec = 30
    SkipHttpErrorCheck = $true
    MaximumRedirection = 0
  }
  if ($null -ne $Body) {
    $parameters.ContentType = "application/json"
    $parameters.Body = $Body | ConvertTo-Json -Depth 12 -Compress
  }
  try {
    $response = Invoke-WebRequest @parameters
  } catch {
    throw "hosted_http_transport_failed"
  }
  $json = $null
  if (-not [string]::IsNullOrWhiteSpace([string]$response.Content)) {
    try { $json = $response.Content | ConvertFrom-Json } catch { throw "hosted_http_json_invalid" }
  }
  return @{ status = [int]$response.StatusCode; json = $json }
}

function Assert-HostedTarget([string]$Value) {
  $uri = $null
  Assert-True "base_url_invalid" ([Uri]::TryCreate($Value.Trim().TrimEnd("/"), [UriKind]::Absolute, [ref]$uri))
  Assert-True "hosted_https_required" ($uri.Scheme -eq "https")
  $targetHost = $uri.DnsSafeHost.ToLowerInvariant()
  Assert-True "localhost_forbidden" ($targetHost -notin @("localhost", "127.0.0.1", "::1") -and -not $targetHost.EndsWith(".localhost"))
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
  try {
    & git -C $repoRoot archive --format=tar --output=$archive $ExpectedSourceCommitSha
    Assert-True "candidate_archive_reconstruction_failed" ($LASTEXITCODE -eq 0)
    Assert-True "candidate_archive_digest_mismatch" ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $ExpectedSourceArchiveSha256)
  } finally { if ([IO.File]::Exists($archive)) { [IO.File]::Delete($archive) } }
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
  $approvedRubric = (& git -C $repoRoot show "${RubricApprovalCommit}:$rubricPath" 2>$null | Out-String)
  Assert-True "rubric_not_owner_approved" (
    $approvedRubric -match '(?m)^Status:\s*`APPROVED`\s*$' -and
    $approvedRubric -match '(?m)^Credit-Anwendung erlaubt:\s*`true`\s*$' -and
    $approvedRubric.Contains("scripts/verify-mcp-hosted-write.ps1")
  )
}

function Assert-HostedContract($Contract) {
  Assert-True "hosted_contract_missing" ($null -ne $Contract)
  Assert-True "contract_version_mismatch" ([string](Get-PropertyValue $Contract "contract_version") -eq $contractVersion)
  Assert-True "hosted_contract_not_enabled" ((Get-PropertyValue $Contract "enabled") -eq $true)
  Assert-True "dev_only_contract_rejected" (
    (Get-PropertyValue $Contract "hosted") -eq $true -and
    (Get-PropertyValue $Contract "DEV_ONLY") -eq $false -and
    [string](Get-PropertyValue $Contract "mode") -notmatch '(?i)dev-only|local'
  )
  Assert-True "contract_source_commit_mismatch" ([string](Get-PropertyValue $Contract "source_commit_sha") -eq $ExpectedSourceCommitSha)
  Assert-True "contract_source_archive_mismatch" ([string](Get-PropertyValue $Contract "source_archive_sha256") -eq $ExpectedSourceArchiveSha256)
  Assert-True "contract_source_bundle_mismatch" ([string](Get-PropertyValue $Contract "source_bundle_sha256") -eq $ExpectedSourceBundleSha256)
  Assert-True "contract_rubric_approval_binding_mismatch" ([string](Get-PropertyValue $Contract "rubric_approval_sha") -ceq $RubricApprovalCommit)
  Assert-True "contract_owner_grant_binding_mismatch" ([string](Get-PropertyValue $Contract "owner_grant_commit_sha") -ceq $OwnerGrantCommitSha)
  foreach ($field in @("verifier_blob_sha256", "runtime_blob_sha256", "rubric_blob_sha256", "capability_gate_blob_sha256")) {
    Assert-True "contract_${field}_mismatch" ([string](Get-PropertyValue $Contract $field) -ceq [string]$script:CandidateBlobBindings[$field])
  }
  Assert-True "contract_repository_scope_mismatch" ([string](Get-PropertyValue $Contract "repository") -eq $Repository)
  Assert-True "contract_branch_scope_mismatch" ([string](Get-PropertyValue $Contract "active_branch") -eq $Branch)
  Assert-True "contract_preview_environment_required" ([string](Get-PropertyValue $Contract "deployment_environment") -ceq "candidate_preview")
  Assert-True "contract_preview_hostname_mismatch" ([string](Get-PropertyValue $Contract "candidate_preview_hostname") -ceq ([Uri]$sanctionedBaseUrl).DnsSafeHost)
  Assert-True "owner_scope_not_approved" ((Get-PropertyValue $Contract "owner_scope_approved") -eq $true)
  Assert-True "main_write_must_be_false" ((Get-PropertyValue $Contract "main_write_allowed") -eq $false)
  Assert-True "arbitrary_paths_must_be_false" ((Get-PropertyValue $Contract "arbitrary_paths_allowed") -eq $false)
  $capabilities = @((Get-PropertyValue $Contract "hosted_verifier_capabilities") | ForEach-Object { [string]$_ })
  foreach ($required in @("bounded_write", "server_readback", "audit_prewrite", "audit_postwrite")) {
    Assert-True "hosted_capability_missing_$required" ($capabilities -contains $required)
  }
}

$base = $BaseUrl.Trim().TrimEnd("/")
$token = ""
$reportBase = [ordered]@{
  contract_version = $evidenceContract
  evidence_ref = $evidenceRef
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
  Assert-HostedContract $contractResponse.json

  $suffix = [Guid]::NewGuid().ToString("N")
  $requestId = "o4-runtime-$suffix"
  $payload = [ordered]@{
    tool_request_id = $requestId
    run_id = "o4-runtime-run-$suffix"
    session_id = [Guid]::NewGuid().ToString()
    agent_role = "coder"
    repository = $Repository
    branch = $Branch
    channel = "runtime"
    idempotency_key = $requestId
    simulate_commit_audit_failure = $false
  }
  $write = Invoke-JsonRequest "POST" "$base/mcp/api/v1/tools/live-write/probe" @{ "x-superbrain-agent-token" = $token } $payload
  Assert-True "write_http_200_required" ($write.status -eq 200)
  $result = $write.json
  foreach ($field in @("write_performed", "readback_verified", "immutable_receipt_verified", "channel_state_current", "audit_persisted", "audit_fail_closed", "rollback_on_audit_failure", "live_mcp_writes")) {
    Assert-True "write_result_${field}_required" ((Get-PropertyValue $result $field) -eq $true)
  }
  foreach ($field in @("live_provider_calls", "direct_provider_calls", "production_deploy", "secret_output", "DEV_ONLY")) {
    Assert-True "write_result_${field}_must_be_false" ((Get-PropertyValue $result $field) -eq $false)
  }
  Assert-True "write_status_verified_required" ([string](Get-PropertyValue $result "status") -eq "verified")
  Assert-True "write_source_commit_mismatch" ([string](Get-PropertyValue $result "source_commit_sha") -eq $ExpectedSourceCommitSha)
  Assert-True "write_source_archive_mismatch" ([string](Get-PropertyValue $result "source_archive_sha256") -eq $ExpectedSourceArchiveSha256)
  Assert-True "write_source_bundle_mismatch" ([string](Get-PropertyValue $result "source_bundle_sha256") -eq $ExpectedSourceBundleSha256)
  Assert-True "write_content_digest_invalid" ([string](Get-PropertyValue $result "content_sha256") -match "^[0-9a-f]{64}$")
  foreach ($field in @("prewrite_audit_event_ref", "mcp_audit_event_ref")) {
    Assert-True "write_${field}_invalid" ([string](Get-PropertyValue $result $field) -match '^[0-9a-f]{64}$')
  }

  $success = [ordered]@{} + $reportBase
  $success.status = "verified"
  $success.credit_eligible = $true
  $success.write_performed = $true
  $success.server_readback_verified = $true
  $success.audit_prewrite_persisted = $true
  $success.audit_postwrite_persisted = $true
  $success.content_sha256 = [string](Get-PropertyValue $result "content_sha256")
  $success.prewrite_audit_event_ref = [string](Get-PropertyValue $result "prewrite_audit_event_ref")
  $success.mcp_audit_event_ref = [string](Get-PropertyValue $result "mcp_audit_event_ref")
  $success.live_mcp_writes = $true
  $evidence = Write-Evidence $success
  Write-Host ("[mcp-hosted-write] PASS evidence_sha256={0} secret_output=false" -f $evidence.sha256)
} catch {
  $blocked = [ordered]@{} + $reportBase
  $blocked.status = "blocked"
  $blocked.credit_eligible = $false
  $blocked.blocker = [string]$_.Exception.Message
  $blocked.write_performed = $false
  $blocked.live_mcp_writes = $false
  $evidence = Write-Evidence $blocked
  Write-Error ("[mcp-hosted-write] BLOCKED blocker={0} evidence_sha256={1} secret_output=false" -f $blocked.blocker, $evidence.sha256)
} finally {
  $token = ""
  Pop-Location
}

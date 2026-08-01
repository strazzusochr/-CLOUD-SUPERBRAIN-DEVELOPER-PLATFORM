param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [switch]$RuntimeProof,
  [switch]$PromoteGateOnFullPass,
  [string]$CapabilityStatePath = "docs\runtime-state\capability-gates.json",
  [string]$OwnerManifestPath = "docs\runtime-state\owner-input-manifest.json",
  [string]$ExternalGateSummaryPath = "docs\runtime-state\external-gate-summary.json",
  [string]$RuntimeReportPath = ".phase1-artifacts\o4-live-writes\runtime-proof.json",
  [string]$BrowserReportPath = ".phase1-artifacts\o4-live-writes\browser-proof.json",
  [string]$CombinedReportPath = ".phase1-artifacts\o4-live-writes\proof.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$contractVersion = "o4-live-agent-mcp-write-v1"
$evidenceRef = "o4_live_agent_mcp_write_audit_verified"
$repository = "strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM"
$verifierPath = "scripts/verify-o4-live-writes.ps1"
$provider = "local_mcp_gateway_filesystem"
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) {
    throw "O4 live-write verification failed: $Label"
  }
}

function Read-Json([string]$Path) {
  Assert-True "$Path exists" (Test-Path -LiteralPath $Path -PathType Leaf)
  return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-Sha256([string]$Path) {
  $resolved = (Resolve-Path -LiteralPath $Path).Path
  $stream = [IO.File]::OpenRead($resolved)
  $sha256 = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace("-", "")
  } finally {
    $sha256.Dispose()
    $stream.Dispose()
  }
}

function Write-TextAtomic([string]$Path, [string]$Text) {
  $fullPath = [IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
  $directory = [IO.Path]::GetDirectoryName($fullPath)
  [IO.Directory]::CreateDirectory($directory) | Out-Null
  $temporary = Join-Path $directory (".{0}.{1}.tmp" -f [IO.Path]::GetFileName($fullPath), [Guid]::NewGuid().ToString("N"))
  $backup = Join-Path $directory (".{0}.{1}.bak" -f [IO.Path]::GetFileName($fullPath), [Guid]::NewGuid().ToString("N"))
  $utf8 = New-Object Text.UTF8Encoding($false)
  try {
    [IO.File]::WriteAllText($temporary, $Text, $utf8)
    if ([IO.File]::Exists($fullPath)) {
      [IO.File]::Replace($temporary, $fullPath, $backup)
    } else {
      [IO.File]::Move($temporary, $fullPath)
    }
  } finally {
    if ([IO.File]::Exists($temporary)) {
      [IO.File]::Delete($temporary)
    }
    if ([IO.File]::Exists($backup)) {
      [IO.File]::Delete($backup)
    }
  }
}

function Write-JsonAtomic([string]$Path, $Value) {
  $json = $Value | ConvertTo-Json -Depth 50
  Write-TextAtomic $Path ($json + [Environment]::NewLine)
}

function Set-Property($Object, [string]$Name, $Value) {
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) {
    $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
  } else {
    $property.Value = $Value
  }
}

function Get-CurrentBranch {
  $value = (& git -C $repoRoot branch --show-current | Out-String).Trim()
  Assert-True "active branch is available" (-not [string]::IsNullOrWhiteSpace($value))
  Assert-True "main is forbidden" ($value -ne "main")
  Assert-True "branch traversal is forbidden" (-not (@($value.Split("/")) -contains ".."))
  return $value
}

function Assert-CanonicalRemote {
  $remote = (& git -C $repoRoot remote get-url origin | Out-String).Trim()
  $normalized = $remote -replace '^git@github\.com:', 'https://github.com/'
  $normalized = $normalized -replace '\.git$', ''
  Assert-True "origin repository is allowlisted" (
    $normalized -eq "https://github.com/$repository"
  )
}

function Assert-OwnerScope($OwnerManifest, [string]$Branch) {
  $o4 = @($OwnerManifest.actions | Where-Object { [string]$_.id -eq "O4" }) | Select-Object -First 1
  Assert-True "O4 owner action exists" ($null -ne $o4)
  $decision = $o4.owner_scope_decision
  Assert-True "O4 decision is approved" ([string]$decision.decision -eq "approved_as_proposed")
  Assert-True "O4 records the pre-verifier closed state" ([bool]$decision.gate_state_unchanged)
  Assert-True "O4 repository allowlist is exact" (
    @($decision.repositories_allowed).Count -eq 1 -and
    [string]$decision.repositories_allowed[0] -eq $repository
  )
  Assert-True "O4 excludes all other repositories" (
    [string]$decision.repositories_excluded -match "All other repositories"
  )
  Assert-True "O4 active branch is allowed" (
    [string]$decision.branches_allowed -match "active working branch"
  )
  Assert-True "O4 main is forbidden" (
    [string]$decision.branches_forbidden -match "main" -and
    [string]$decision.branches_forbidden -match "force push"
  )
  Assert-True "O4 filesystem and git writes are the only allowlisted writes" (
    @($decision.mcp_write_allowlist).Count -eq 2 -and
    @($decision.mcp_write_allowlist | Where-Object { [string]$_ -match "^filesystem:" }).Count -eq 1 -and
    @($decision.mcp_write_allowlist | Where-Object { [string]$_ -match "^git:" }).Count -eq 1
  )
  $exclusions = @($decision.mcp_write_explicitly_excluded | ForEach-Object { [string]$_ })
  Assert-True "O4 excludes the Codex configuration directory" (
    @($exclusions | Where-Object { $_ -match [regex]::Escape("C:\Users\immer\.codex") }).Count -eq 1
  )
  Assert-True "O4 excludes the secrets directory" (
    @($exclusions | Where-Object { $_ -match "<SECRETS_DIR>" }).Count -eq 1
  )
  Assert-True "O4 excludes paths outside the working tree" (
    @($exclusions | Where-Object { $_ -match "outside the project working tree" }).Count -eq 1
  )
  $audit = $decision.audit_retention
  Assert-True "O4 persists every write" ([bool]$audit.persist_every_write)
  Assert-True "O4 never records secret values" (-not [bool]$audit.secret_values_recorded)
  Assert-True "O4 audit retention is unlimited" ([string]$audit.retention -eq "unlimited")
  Assert-True "O4 audit failure requires rollback" (
    [string]$audit.fail_closed_rule -match "rolled back"
  )
  Assert-True "active branch remains non-main" ($Branch -ne "main")
  return $o4
}

function Assert-StaticImplementation {
  $mcp = Get-Content -LiteralPath (Join-Path $repoRoot "services\mcp-gateway\app\main.py") -Raw
  $agent = Get-Content -LiteralPath (Join-Path $repoRoot "services\agent-api\app\main.py") -Raw
  $frontend = Get-Content -LiteralPath (Join-Path $repoRoot "apps\frontend\app\api\v1\tools\live-write\probe\route.ts") -Raw
  $compose = Get-Content -LiteralPath (Join-Path $repoRoot "docker-compose.dev.yml") -Raw
  $nginx = Get-Content -LiteralPath (Join-Path $repoRoot "infrastructure\nginx\dev.conf") -Raw
  foreach ($required in @(
    "O4_LIVE_WRITE_CONTRACT_VERSION",
    "execute_o4_live_write",
    "audit_before_write_required",
    "rollback_on_commit_audit_failure",
    "simulate_commit_audit_failure",
    "o4_owner_scope_authorized",
    "O4 internal service authentication required",
    "o4_atomic_write"
  )) {
    Assert-True "MCP implementation contains $required" $mcp.Contains($required)
  }
  foreach ($required in @(
    "LiveToolWriteProbeRequest",
    "assert_o4_live_write_scope",
    "agent_live_tool_write_verified",
    "agent_audit_readback_verified",
    "branch_protection_claim_allowed",
    "O4 service authentication required"
  )) {
    Assert-True "Agent implementation contains $required" $agent.Contains($required)
  }
  foreach ($required in @(
    "authorizeBoundaryWrite",
    "serviceAuth: true",
    "o4-live-agent-mcp-write-v1",
    "o4_live_write_response_validation_failed",
    "main_write_allowed: false",
    "secret_output: false"
  )) {
    Assert-True "Frontend implementation contains $required" $frontend.Contains($required)
  }
  foreach ($required in @(
    'O4_LIVE_WRITE_PROBE_ENABLED: "true"',
    'O4_LIVE_WRITE_NEGATIVE_TEST_ENABLED: "true"',
    './.phase1-artifacts/o4-live-write-workspace:/tmp/agent-workspace',
    './docs/runtime-state/owner-input-manifest.json:/app/progress/owner-input-manifest.json:ro',
    './.git/HEAD:/app/o4-git/HEAD:ro'
  )) {
    Assert-True "Compose O4 binding contains $required" $compose.Contains($required)
  }
  Assert-True "Nginx routes the exact O4 endpoint to the frontend boundary" (
    $nginx -match '(?ms)location = /api/v1/tools/live-write/probe\s*\{.*?proxy_pass \$frontend;'
  )
}

function Assert-ExternalBranchProtection($Summary) {
  Assert-True "external gate summary v2" ([string]$Summary.contract_version -eq "external-gate-summary-v2")
  Assert-True "branch protection claim is verified" ([bool]$Summary.branch_protection_claim_allowed)
  Assert-True "branch protection is not missing" (
    -not (@($Summary.missing_or_failed_gates | ForEach-Object { [string]$_ }) -contains "github_branch_protection_verify")
  )
}

function Invoke-ContainerJsonPost(
  [string]$Container,
  [string]$Url,
  $Payload,
  [bool]$WithToken
) {
  $json = $Payload | ConvertTo-Json -Depth 12 -Compress
  $payloadBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
  $tokenFlag = if ($WithToken) { "1" } else { "0" }
  $python = @'
import base64
import json
import os
import urllib.error
import urllib.request

payload = base64.b64decode(os.environ["O4_PAYLOAD_B64"]).decode("utf-8")
headers = {"Content-Type": "application/json"}
if os.environ.get("O4_USE_TOKEN") == "1":
    headers["x-superbrain-agent-token"] = os.environ.get("AGENT_API_AUTH_TOKEN", "")
request = urllib.request.Request(os.environ["O4_TARGET_URL"], data=payload.encode("utf-8"), headers=headers, method="POST")
try:
    with urllib.request.urlopen(request, timeout=20) as response:
        status = response.status
        text = response.read().decode("utf-8")
except urllib.error.HTTPError as error:
    status = error.code
    text = error.read().decode("utf-8")
try:
    body = json.loads(text)
except json.JSONDecodeError:
    body = None
print(json.dumps({"http_status": status, "body": body}, separators=(",", ":")))
'@
  $output = $python | & docker exec -i `
    -e "O4_PAYLOAD_B64=$payloadBase64" `
    -e "O4_USE_TOKEN=$tokenFlag" `
    -e "O4_TARGET_URL=$Url" `
    $Container python -
  Assert-True "container request exited zero" ($LASTEXITCODE -eq 0)
  return ($output | Out-String).Trim() | ConvertFrom-Json
}

function Test-FileState([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return [ordered]@{ exists = $false; sha256 = "" }
  }
  return [ordered]@{ exists = $true; sha256 = Get-Sha256 $Path }
}

function Assert-FileStateEqual($Before, $After, [string]$Label) {
  Assert-True "$Label existence unchanged" ([bool]$Before.exists -eq [bool]$After.exists)
  Assert-True "$Label content unchanged" ([string]$Before.sha256 -eq [string]$After.sha256)
}

function Assert-LiveResult($Result, [string]$Channel, [string]$Branch) {
  Assert-True "$Channel contract" ([string]$Result.contract_version -eq $contractVersion)
  Assert-True "$Channel status" ([string]$Result.status -eq "verified")
  Assert-True "$Channel evidence" ([string]$Result.evidence_ref -eq $evidenceRef)
  Assert-True "$Channel repository" ([string]$Result.repository -eq $repository)
  Assert-True "$Channel branch" ([string]$Result.branch -eq $Branch)
  Assert-True "$Channel channel" ([string]$Result.channel -eq $Channel)
  Assert-True "$Channel role" ([string]$Result.agent_role -eq "coder")
  Assert-True "$Channel toolset" ([string]$Result.toolset -eq "filesystem")
  Assert-True "$Channel fixed path" (
    [string]$Result.write_path -eq "/tmp/agent-workspace/o4-live-write/$Channel.json"
  )
  foreach ($field in @(
    "write_performed",
    "readback_verified",
    "audit_persisted",
    "audit_fail_closed",
    "rollback_on_audit_failure",
    "agent_audit_readback_verified",
    "live_agent_tool_writes",
    "live_mcp_writes",
    "owner_scope_approved",
    "branch_protection_verified",
    "DEV_ONLY"
  )) {
    Assert-True "$Channel $field=true" ($Result.$field -eq $true)
  }
  foreach ($field in @(
    "main_write",
    "force_push",
    "live_provider_calls",
    "direct_provider_calls",
    "production_deploy",
    "secret_output"
  )) {
    Assert-True "$Channel $field=false" ($Result.$field -eq $false)
  }
  Assert-True "$Channel content SHA-256" ([string]$Result.content_sha256 -match "^[a-f0-9]{64}$")
  foreach ($field in @("prewrite_audit_event_id", "mcp_audit_event_id", "agent_audit_event_id")) {
    Assert-True "$Channel $field UUID" ([string]$Result.$field -match "^[a-f0-9-]{36}$")
  }
}

$proofRuntimePaths = @(
  ".dockerignore",
  "apps/frontend",
  "docker-compose.dev.yml",
  "infrastructure/nginx/dev.conf",
  "services/agent-api",
  "services/mcp-gateway",
  "scripts/start-dev-live.ps1",
  "scripts/verify-o4-live-write-browser.cjs",
  "scripts/verify-o4-live-writes.ps1"
)
$qualificationTruthPaths = @(
  "apps/frontend/lib/endpoint-snapshot.json",
  "apps/frontend/lib/platform.ts"
)

function Assert-ProofReport(
  $Report,
  [string]$Kind,
  [string]$Branch,
  [string]$Head,
  [bool]$RequireCleanWorktree = $false
) {
  Assert-True "$Kind report verified" ([string]$Report.status -eq "verified")
  Assert-True "$Kind report repository" ([string]$Report.repository -eq $repository)
  Assert-True "$Kind report branch" ([string]$Report.branch -eq $Branch)
  Assert-ProofSourceParity ([string]$Report.source_commit) $Kind $Head $RequireCleanWorktree
  foreach ($field in @(
    "write_performed",
    "readback_verified",
    "host_workspace_readback_verified",
    "audit_persisted",
    "audit_fail_closed",
    "live_agent_tool_writes",
    "live_mcp_writes",
    "owner_scope_approved",
    "branch_protection_verified",
    "proof_worktree_clean_verified",
    "DEV_ONLY"
  )) {
    Assert-True "$Kind report $field=true" ($Report.$field -eq $true)
  }
  foreach ($field in @(
    "main_write",
    "force_push",
    "live_provider_calls",
    "direct_provider_calls",
    "production_deploy",
    "secret_output"
  )) {
    Assert-True "$Kind report $field=false" ($Report.$field -eq $false)
  }
  Assert-True "$Kind report content SHA-256" ([string]$Report.content_sha256 -match "^[a-f0-9]{64}$")
}

function Assert-ProofSourceParity(
  [string]$SourceCommit,
  [string]$Kind,
  [string]$Head,
  [bool]$RequireCleanWorktree = $false
) {
  Assert-True "$Kind report source commit format" ($SourceCommit -match "^[a-f0-9]{40}$")
  & git -C $repoRoot cat-file -e "$SourceCommit^{commit}" 2>$null
  Assert-True "$Kind report source commit exists" ($LASTEXITCODE -eq 0)
  & git -C $repoRoot merge-base --is-ancestor $SourceCommit $Head 2>$null
  Assert-True "$Kind report source commit is an ancestor of HEAD" ($LASTEXITCODE -eq 0)

  $diffArgs = @(
    "diff", "--cached", "--name-only", "--diff-filter=ACDMRTUXB", $SourceCommit, "--"
  ) + $proofRuntimePaths
  $changedPaths = @(
    & git -C $repoRoot @diffArgs |
      ForEach-Object { ([string]$_).Trim().Replace("\", "/") } |
      Where-Object { $_ }
  )
  Assert-True "$Kind report runtime-source diff is readable" ($LASTEXITCODE -eq 0)
  $unexpectedPaths = @(
    $changedPaths | Where-Object { $qualificationTruthPaths -notcontains $_ }
  )
  Assert-True "$Kind report runtime-source parity outside qualification truth" ($unexpectedPaths.Count -eq 0)

  if ($RequireCleanWorktree) {
    $worktreeDiffArgs = @(
      "diff", "--name-only", "--diff-filter=ACDMRTUXB", $SourceCommit, "--"
    ) + $proofRuntimePaths
    $worktreeChanges = @(
      & git -C $repoRoot @worktreeDiffArgs |
        ForEach-Object { ([string]$_).Trim().Replace("\", "/") } |
        Where-Object { $_ }
    )
    Assert-True "$Kind proof worktree diff is readable" ($LASTEXITCODE -eq 0)
    Assert-True "$Kind proof tracked runtime worktree is clean" ($worktreeChanges.Count -eq 0)

    $untrackedArgs = @(
      "ls-files", "--others", "--exclude-standard", "--"
    ) + $proofRuntimePaths
    $untrackedPaths = @(
      & git -C $repoRoot @untrackedArgs |
        ForEach-Object { ([string]$_).Trim().Replace("\", "/") } |
        Where-Object { $_ }
    )
    Assert-True "$Kind proof untracked runtime inventory is readable" ($LASTEXITCODE -eq 0)
    Assert-True "$Kind proof has no untracked runtime paths" ($untrackedPaths.Count -eq 0)
  }
}

Assert-True "RuntimeProof and PromoteGateOnFullPass are mutually exclusive" (
  -not ($RuntimeProof -and $PromoteGateOnFullPass)
)
Set-Location -LiteralPath $repoRoot
$branch = Get-CurrentBranch
Assert-CanonicalRemote
$ownerManifest = Read-Json $OwnerManifestPath
$o4Action = Assert-OwnerScope $ownerManifest $branch
$externalSummary = Read-Json $ExternalGateSummaryPath
Assert-ExternalBranchProtection $externalSummary
Assert-StaticImplementation

$workspaceRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot ".phase1-artifacts\o4-live-write-workspace"))
Assert-True "O4 workspace stays inside repo" $workspaceRoot.StartsWith(
  [IO.Path]::GetFullPath($repoRoot).TrimEnd("\") + "\",
  [StringComparison]::OrdinalIgnoreCase
)
Assert-True "O4 workspace is not .codex" (-not $workspaceRoot.Contains("\.codex\"))
Assert-True "O4 workspace is not secrets" (-not $workspaceRoot.Contains("\secrets\"))

if ($RuntimeProof) {
  $runtimeHead = (& git -C $repoRoot rev-parse HEAD | Out-String).Trim()
  Assert-ProofSourceParity $runtimeHead "runtime generation" $runtimeHead $true
  $base = [Uri]$BaseUrl
  Assert-True "runtime proof requires explicit localhost approval" (
    $AllowLocalhost -and
    $base.Scheme -eq "http" -and
    $base.Host -in @("localhost", "127.0.0.1", "::1")
  )
  $mcpContract = Invoke-RestMethod -Method Get -Uri "$BaseUrl/mcp/api/v1/tools/live-write/probe/contract" -TimeoutSec 15
  Assert-True "MCP O4 contract enabled" ($mcpContract.enabled -eq $true)
  Assert-True "MCP O4 contract is fixed-path" ($mcpContract.arbitrary_paths_allowed -eq $false)
  Assert-True "MCP O4 contract forbids main" ($mcpContract.main_write_allowed -eq $false)
  Assert-True "MCP O4 contract is audit fail-closed" ($mcpContract.audit_before_write_required -eq $true -and $mcpContract.audit_after_write_required -eq $true)

  $runtimeTarget = Join-Path $workspaceRoot "o4-live-write\runtime.json"
  $rollbackTarget = Join-Path $workspaceRoot "o4-live-write\rollback.json"
  $runtimeBefore = Test-FileState $runtimeTarget
  $rollbackBefore = Test-FileState $rollbackTarget

  $unauthorizedKey = "o4-runtime-" + [Guid]::NewGuid().ToString("N")
  $unauthorizedPayload = [ordered]@{
    tool_request_id = $unauthorizedKey
    run_id = $unauthorizedKey.Replace("-runtime-", "-runtime-run-")
    session_id = [Guid]::NewGuid().ToString()
    agent_role = "coder"
    repository = $repository
    branch = $branch
    channel = "runtime"
    idempotency_key = $unauthorizedKey
    simulate_commit_audit_failure = $false
  }
  $unauthorized = Invoke-ContainerJsonPost `
    "cloud-superbrain-phase1-dev-mcp-gateway-1" `
    "http://127.0.0.1:9000/api/v1/tools/live-write/probe" `
    $unauthorizedPayload `
    $false
  Assert-True "unauthenticated MCP write is rejected" ([int]$unauthorized.http_status -eq 401)
  Assert-FileStateEqual $runtimeBefore (Test-FileState $runtimeTarget) "unauthenticated probe"

  $mainKey = "o4-runtime-" + [Guid]::NewGuid().ToString("N")
  $mainPayload = [ordered]@{
    tool_request_id = $mainKey
    run_id = $mainKey.Replace("-runtime-", "-runtime-run-")
    session_id = [Guid]::NewGuid().ToString()
    agent_role = "coder"
    repository = $repository
    branch = "main"
    channel = "runtime"
    idempotency_key = $mainKey
    simulate_commit_audit_failure = $false
  }
  $mainRejected = Invoke-ContainerJsonPost `
    "cloud-superbrain-phase1-dev-mcp-gateway-1" `
    "http://127.0.0.1:9000/api/v1/tools/live-write/probe" `
    $mainPayload `
    $true
  Assert-True "main MCP write is rejected" ([int]$mainRejected.http_status -eq 403)
  Assert-FileStateEqual $runtimeBefore (Test-FileState $runtimeTarget) "main probe"

  $rollbackKey = "o4-rollback-" + [Guid]::NewGuid().ToString("N")
  $rollbackPayload = [ordered]@{
    tool_request_id = $rollbackKey
    run_id = $rollbackKey.Replace("-rollback-", "-rollback-run-")
    session_id = [Guid]::NewGuid().ToString()
    agent_role = "coder"
    repository = $repository
    branch = $branch
    channel = "rollback"
    idempotency_key = $rollbackKey
    simulate_commit_audit_failure = $true
  }
  $rollback = Invoke-ContainerJsonPost `
    "cloud-superbrain-phase1-dev-mcp-gateway-1" `
    "http://127.0.0.1:9000/api/v1/tools/live-write/probe" `
    $rollbackPayload `
    $true
  Assert-True "forced audit failure returns 503" ([int]$rollback.http_status -eq 503)
  Assert-True "forced audit failure reports rollback" ($rollback.body.detail.rollback_performed -eq $true)
  Assert-True "forced audit failure persists rollback audit" ($rollback.body.detail.rollback_audit_persisted -eq $true)
  Assert-True "forced audit failure emits no secret" ($rollback.body.detail.secret_output -eq $false)
  Assert-FileStateEqual $rollbackBefore (Test-FileState $rollbackTarget) "audit-failure rollback probe"

  $runtimeKey = "o4-runtime-" + [Guid]::NewGuid().ToString("N")
  $runtimePayload = [ordered]@{
    repository = $repository
    branch = $branch
    channel = "runtime"
    idempotency_key = $runtimeKey
    confirm_owner_scope = $true
  }
  $runtimeResponse = Invoke-ContainerJsonPost `
    "cloud-superbrain-phase1-dev-agent-api-1" `
    "http://127.0.0.1:8000/api/v1/tools/live-write/probe" `
    $runtimePayload `
    $true
  Assert-True "runtime Agent API write returned 200" ([int]$runtimeResponse.http_status -eq 200)
  $result = $runtimeResponse.body
  Assert-LiveResult $result "runtime" $branch

  $runtimeAfter = Test-FileState $runtimeTarget
  Assert-True "runtime host workspace file exists" ([bool]$runtimeAfter.exists)
  Assert-True "runtime host workspace hash matches" (
    [string]$runtimeAfter.sha256 -eq ([string]$result.content_sha256).ToUpperInvariant()
  )
  $runtimeProbe = Read-Json $runtimeTarget
  Assert-True "runtime host workspace idempotency matches" ([string]$runtimeProbe.idempotency_key -eq $runtimeKey)
  Assert-True "runtime host workspace has live write claims" (
    $runtimeProbe.live_agent_tool_writes -eq $true -and $runtimeProbe.live_mcp_writes -eq $true
  )
  Assert-True "runtime host workspace safety claims" (
    $runtimeProbe.production_deploy -eq $false -and $runtimeProbe.secret_output -eq $false
  )

  $mcpAudit = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/v1/audit/mcp?limit=100" -TimeoutSec 15
  $mcpCommit = @($mcpAudit.events | Where-Object { [string]$_.id -eq [string]$result.mcp_audit_event_id }) | Select-Object -First 1
  $mcpRollback = @($mcpAudit.events | Where-Object {
    [string]$_.details.tool_request_id -eq $rollbackKey -and
    [string]$_.details.write_phase -eq "rolled_back"
  }) | Select-Object -First 1
  Assert-True "runtime MCP commit audit is readable" ($null -ne $mcpCommit)
  Assert-True "runtime MCP commit audit fields are exact" (
    [string]$mcpCommit.user_id -eq "coder" -and
    [string]$mcpCommit.details.write_path -eq "/tmp/agent-workspace/o4-live-write/runtime.json" -and
    [string]$mcpCommit.details.branch_ref -eq $branch -and
    [string]$mcpCommit.details.write_result -eq "committed" -and
    $mcpCommit.details.live_mcp_write -eq $true -and
    $mcpCommit.details.secret_output -eq $false
  )
  Assert-True "rollback audit is readable" ($null -ne $mcpRollback)
  Assert-True "rollback audit fields are exact" (
    $mcpRollback.details.rollback_performed -eq $true -and
    [string]$mcpRollback.details.write_result -eq "audit_commit_failed_rolled_back"
  )
  $recentAudit = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/v1/audit/recent?limit=100" -TimeoutSec 15
  $agentAudit = @($recentAudit.events | Where-Object { [string]$_.id -eq [string]$result.agent_audit_event_id }) | Select-Object -First 1
  Assert-True "runtime agent audit is readable" ($null -ne $agentAudit)
  Assert-True "runtime agent audit fields are exact" (
    [string]$agentAudit.event_type -eq "agent_live_tool_write_verified" -and
    [string]$agentAudit.user_id -eq "coder" -and
    [string]$agentAudit.details.branch -eq $branch -and
    [string]$agentAudit.details.path_or_ref -eq "/tmp/agent-workspace/o4-live-write/runtime.json" -and
    $agentAudit.details.live_agent_tool_writes -eq $true -and
    $agentAudit.details.live_mcp_writes -eq $true -and
    $agentAudit.details.secret_output -eq $false
  )

  $head = (& git -C $repoRoot rev-parse HEAD | Out-String).Trim()
  $runtimeReport = [ordered]@{
    contract_version = "o4-live-write-runtime-proof-v1"
    status = "verified"
    evidence_ref = "o4_live_write_runtime_verified"
    verified_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    source_commit = $head
    repository = $repository
    branch = $branch
    transport = "agent-api_to_mcp-gateway_to_repo-workspace"
    channel = "runtime"
    write_performed = $true
    readback_verified = $true
    host_workspace_readback_verified = $true
    audit_persisted = $true
    audit_fail_closed = $true
    unauthenticated_write_blocked = $true
    main_write_blocked = $true
    audit_failure_rollback_verified = $true
    rollback_audit_persisted = $true
    live_agent_tool_writes = $true
    live_mcp_writes = $true
    owner_scope_approved = $true
    branch_protection_verified = $true
    proof_worktree_clean_verified = $true
    main_write = $false
    force_push = $false
    live_provider_calls = $false
    direct_provider_calls = $false
    production_deploy = $false
    secret_output = $false
    DEV_ONLY = $true
    write_path = [string]$result.write_path
    content_sha256 = [string]$result.content_sha256
    prewrite_audit_event_id = [string]$result.prewrite_audit_event_id
    mcp_audit_event_id = [string]$result.mcp_audit_event_id
    agent_audit_event_id = [string]$result.agent_audit_event_id
    rollback_tool_request_id = $rollbackKey
    rollback_audit_event_id = [string]$mcpRollback.id
    owner_manifest_sha256 = Get-Sha256 $OwnerManifestPath
    external_gate_summary_sha256 = Get-Sha256 $ExternalGateSummaryPath
    non_claims = @(
      "DEV-ONLY; hosted proof still blocked.",
      "No main write, force push, provider write, release, production deployment, or secret output occurred."
    )
  }
  Write-JsonAtomic $RuntimeReportPath $runtimeReport
  Write-Host "[o4-write] runtime status=verified audit_fail_closed=true secret_output=false"
  Write-Host "[o4-write] runtime evidence=$RuntimeReportPath"
  exit 0
}

$capabilityState = Read-Json $CapabilityStatePath
$agentGate = $capabilityState.gates.live_agent_tool_writes
$mcpGate = $capabilityState.gates.live_mcp_writes
$agentOpen = $agentGate.live_verified -eq $true
$mcpOpen = $mcpGate.live_verified -eq $true
Assert-True "O4 gates open or close together" ($agentOpen -eq $mcpOpen)

if ($PromoteGateOnFullPass) {
  Assert-True "runtime report exists" (Test-Path -LiteralPath $RuntimeReportPath -PathType Leaf)
  Assert-True "browser report exists" (Test-Path -LiteralPath $BrowserReportPath -PathType Leaf)
  $runtimeReport = Read-Json $RuntimeReportPath
  $browserReport = Read-Json $BrowserReportPath
  $head = (& git -C $repoRoot rev-parse HEAD | Out-String).Trim()
  Assert-ProofReport $runtimeReport "runtime" $branch $head $true
  Assert-ProofReport $browserReport "browser" $branch $head $true
  Assert-True "runtime report contract" ([string]$runtimeReport.contract_version -eq "o4-live-write-runtime-proof-v1")
  Assert-True "browser report contract" ([string]$browserReport.contract_version -eq "o4-live-write-browser-proof-v1")
  Assert-True "runtime negative probes are complete" (
    $runtimeReport.unauthenticated_write_blocked -eq $true -and
    $runtimeReport.main_write_blocked -eq $true -and
    $runtimeReport.audit_failure_rollback_verified -eq $true -and
    $runtimeReport.rollback_audit_persisted -eq $true
  )
  Assert-True "browser used real Chromium" ($browserReport.real_browser -eq $true)
  Assert-True "browser authenticated and blocked unauthenticated write" (
    $browserReport.signed_session_verified -eq $true -and
    $browserReport.unauthenticated_write_blocked -eq $true
  )
  Assert-True "runtime and browser MCP audits differ" (
    [string]$runtimeReport.mcp_audit_event_id -ne [string]$browserReport.mcp_audit_event_id
  )

  $verifiedAt = (Get-Date).ToUniversalTime().ToString("o")
  $combinedReport = [ordered]@{
    contract_version = "o4-live-agent-mcp-write-proof-v1"
    status = "verified"
    evidence_ref = $evidenceRef
    verified_at_utc = $verifiedAt
    source_commit = $head
    runtime_report_source_commit = [string]$runtimeReport.source_commit
    browser_report_source_commit = [string]$browserReport.source_commit
    runtime_source_parity_verified = $true
    browser_source_parity_verified = $true
    proof_worktree_clean_verified = $true
    proof_runtime_source_paths = $proofRuntimePaths
    qualification_truth_paths = $qualificationTruthPaths
    repository = $repository
    branch = $branch
    provider = $provider
    paid_provider = $false
    verifier = $verifierPath
    runtime_report = ($RuntimeReportPath -replace "\\", "/")
    runtime_report_sha256 = Get-Sha256 $RuntimeReportPath
    browser_report = ($BrowserReportPath -replace "\\", "/")
    browser_report_sha256 = Get-Sha256 $BrowserReportPath
    owner_manifest_sha256_before_promotion = Get-Sha256 $OwnerManifestPath
    external_gate_summary_sha256 = Get-Sha256 $ExternalGateSummaryPath
    write_channels = @("runtime", "browser")
    agent_role = "coder"
    toolset = "filesystem"
    write_scope = ".phase1-artifacts/o4-live-write-workspace"
    live_agent_tool_writes = $true
    live_mcp_writes = $true
    runtime_verified = $true
    browser_verified = $true
    owner_scope_approved = $true
    branch_protection_verified = $true
    audit_before_write_verified = $true
    audit_after_write_verified = $true
    audit_readback_verified = $true
    audit_failure_rollback_verified = $true
    audit_retention = "unlimited"
    arbitrary_paths_allowed = $false
    main_write = $false
    force_push = $false
    live_provider_calls = $false
    direct_provider_calls = $false
    production_deploy = $false
    secret_output = $false
    DEV_ONLY = $true
    non_claims = @(
      "DEV-ONLY; hosted proof still blocked.",
      "The proof opens only the bounded live_agent_tool_writes and live_mcp_writes capability gates.",
      "No main write, force push, provider write, release, production deployment, or secret output occurred.",
      "Phase-6 scale and GHCR publication remain separate gates."
    )
  }
  Write-JsonAtomic $CombinedReportPath $combinedReport
  $combinedHash = Get-Sha256 $CombinedReportPath

  $originalCapability = Get-Content -LiteralPath $CapabilityStatePath -Raw -Encoding UTF8
  $originalOwner = Get-Content -LiteralPath $OwnerManifestPath -Raw -Encoding UTF8
  try {
    foreach ($gate in @($agentGate, $mcpGate)) {
      Set-Property $gate "owner_granted" $true
      Set-Property $gate "owner_grant_ref" "docs/runtime-state/owner-input-manifest.json#O4.owner_scope_decision"
      Set-Property $gate "live_verified" $true
      Set-Property $gate "evidence_artifact" ($CombinedReportPath -replace "\\", "/")
      Set-Property $gate "evidence_sha256" $combinedHash
      Set-Property $gate "verified_at_utc" $verifiedAt
      Set-Property $gate "provider" $provider
      Set-Property $gate "paid_provider" $false
      Set-Property $gate "verifier" $verifierPath
      Set-Property $gate "runtime_verified" $true
      Set-Property $gate "browser_verified" $true
      Set-Property $gate "branch_protection_verified" $true
      Set-Property $gate "audit_fail_closed_verified" $true
      Set-Property $gate "note" "Verifier-opened bounded DEV-ONLY Agent-to-MCP filesystem write with persisted pre/post audit, readback, browser proof, and rollback on audit failure."
    }
    Set-Property $o4Action "status" "resolved_verified"
    Set-Property $o4Action "required_owner_action" "None. Owner scope is approved and the bounded runtime/browser write chain is verifier-complete."
    Set-Property $o4Action "resolved_at_utc" $verifiedAt
    Set-Property $o4Action "evidence_refs" @(
      "docs/runtime-state/capability-gates.json#live_agent_tool_writes",
      "docs/runtime-state/capability-gates.json#live_mcp_writes",
      ($CombinedReportPath -replace "\\", "/"),
      ($RuntimeReportPath -replace "\\", "/"),
      ($BrowserReportPath -replace "\\", "/")
    )
    Set-Property $o4Action "percentage_credit" 31
    Set-Property $o4Action "percentage_credit_breakdown" ([ordered]@{
      layer_3 = 31
      layer_5 = 0
      phase_6 = 0
    })
    Set-Property $o4Action "codex_boundary" "Resolved O4 credits Agent Pool 69 -> 100. MCP Gateway and Phase 6 stay below 100 because GHCR publication and paid scale are separate unresolved gates; no double credit."
    Write-JsonAtomic $CapabilityStatePath $capabilityState
    Write-JsonAtomic $OwnerManifestPath $ownerManifest
  } catch {
    Write-TextAtomic $CapabilityStatePath $originalCapability
    Write-TextAtomic $OwnerManifestPath $originalOwner
    throw
  }
  Write-Host "[o4-write] status=verified gates=live_agent_tool_writes,live_mcp_writes"
  Write-Host "[o4-write] evidence=$CombinedReportPath sha256=$combinedHash"
  exit 0
}

if (-not $agentOpen) {
  Assert-True "closed agent gate is not hand-granted" ($agentGate.owner_granted -ne $true)
  Assert-True "closed MCP gate is not hand-granted" ($mcpGate.owner_granted -ne $true)
  Write-Host "[o4-write] status=blocked pending=npm_run_verify_runtime_then_verify_browser"
  exit 0
}

$evidencePath = [string]$agentGate.evidence_artifact
Assert-True "both O4 gates bind the same evidence" (
  $evidencePath -eq [string]$mcpGate.evidence_artifact -and
  -not [string]::IsNullOrWhiteSpace($evidencePath)
)
Assert-True "O4 combined evidence exists" (Test-Path -LiteralPath $evidencePath -PathType Leaf)
$evidenceHash = Get-Sha256 $evidencePath
foreach ($gate in @($agentGate, $mcpGate)) {
  Assert-True "O4 gate owner granted" ($gate.owner_granted -eq $true)
  Assert-True "O4 gate live verified" ($gate.live_verified -eq $true)
  Assert-True "O4 gate evidence SHA-256" (
    [string]$gate.evidence_sha256 -eq $evidenceHash
  )
  Assert-True "O4 gate provider" ([string]$gate.provider -eq $provider)
  Assert-True "O4 gate is free" ($gate.paid_provider -eq $false)
  Assert-True "O4 gate verifier" ([string]$gate.verifier -eq $verifierPath)
  Assert-True "O4 gate runtime/browser proof" (
    $gate.runtime_verified -eq $true -and $gate.browser_verified -eq $true
  )
  Assert-True "O4 gate branch/audit proof" (
    $gate.branch_protection_verified -eq $true -and $gate.audit_fail_closed_verified -eq $true
  )
}
$combined = Read-Json $evidencePath
Assert-True "O4 combined report contract" (
  [string]$combined.contract_version -eq "o4-live-agent-mcp-write-proof-v1"
)
Assert-True "O4 combined report verified" (
  [string]$combined.status -eq "verified" -and
  $combined.live_agent_tool_writes -eq $true -and
  $combined.live_mcp_writes -eq $true -and
  $combined.runtime_verified -eq $true -and
  $combined.browser_verified -eq $true -and
  $combined.runtime_source_parity_verified -eq $true -and
  $combined.browser_source_parity_verified -eq $true -and
  $combined.proof_worktree_clean_verified -eq $true -and
  $combined.audit_failure_rollback_verified -eq $true
)
Assert-True "O4 combined report safety" (
  $combined.arbitrary_paths_allowed -eq $false -and
  $combined.main_write -eq $false -and
  $combined.force_push -eq $false -and
  $combined.production_deploy -eq $false -and
  $combined.secret_output -eq $false
)
$runtimeEvidencePath = [string]$combined.runtime_report
$browserEvidencePath = [string]$combined.browser_report
Assert-True "O4 runtime report exists" (Test-Path -LiteralPath $runtimeEvidencePath -PathType Leaf)
Assert-True "O4 browser report exists" (Test-Path -LiteralPath $browserEvidencePath -PathType Leaf)
Assert-True "O4 runtime report SHA-256" (
  [string]$combined.runtime_report_sha256 -eq (Get-Sha256 $runtimeEvidencePath)
)
Assert-True "O4 browser report SHA-256" (
  [string]$combined.browser_report_sha256 -eq (Get-Sha256 $browserEvidencePath)
)
$runtimeEvidence = Read-Json $runtimeEvidencePath
$browserEvidence = Read-Json $browserEvidencePath
$currentHead = (& git -C $repoRoot rev-parse HEAD | Out-String).Trim()
Assert-ProofReport $runtimeEvidence "runtime" $branch $currentHead
Assert-ProofReport $browserEvidence "browser" $branch $currentHead
Assert-True "O4 combined runtime source commit" (
  [string]$combined.runtime_report_source_commit -eq [string]$runtimeEvidence.source_commit
)
Assert-True "O4 combined browser source commit" (
  [string]$combined.browser_report_source_commit -eq [string]$browserEvidence.source_commit
)
Assert-True "O4 action resolved" ([string]$o4Action.status -eq "resolved_verified")
Assert-True "O4 action credit is exact" (
  [int]$o4Action.percentage_credit -eq 31 -and
  [int]$o4Action.percentage_credit_breakdown.layer_3 -eq 31 -and
  [int]$o4Action.percentage_credit_breakdown.layer_5 -eq 0 -and
  [int]$o4Action.percentage_credit_breakdown.phase_6 -eq 0
)
Write-Host "[o4-write] status=verified gates=2 audit_fail_closed=true secret_output=false"

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$sourcePath = Join-Path $PSScriptRoot "verify-phase6-scale-runtime.ps1"
$tokens = $null
$parseErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile($sourcePath, [ref]$tokens, [ref]$parseErrors)
if (@($parseErrors).Count -gt 0) {
  throw "phase6 scale verifier has PowerShell parse errors: $($parseErrors[0].Message)"
}

$source = Get-Content -LiteralPath $sourcePath -Raw
# Forward slashes: this verifier runs in pr-check on ubuntu-latest, where a backslash is a
# literal character and the path would never resolve. PowerShell accepts "/" on Windows too.
$workflowPath = Join-Path (Split-Path -Parent $PSScriptRoot) '.github/workflows/phase6-scale-runtime.yml'
if (-not (Test-Path -LiteralPath $workflowPath -PathType Leaf)) {
  throw 'dedicated Phase6 scale workflow is missing'
}
$workflowSource = Get-Content -LiteralPath $workflowPath -Raw
function Assert-Contains([string]$Needle, [string]$Label) {
  if (-not $source.Contains($Needle)) { throw "missing source contract: $Label" }
}

Assert-Contains 'Blocked "$authEnvName is missing (the value is never printed); zero HTTP requests issued"' "missing-token zero-request guard"
Assert-Contains 'Blocked "-AllowHostedWrites is missing; zero HTTP requests issued"' "Owner-write zero-request guard"
Assert-Contains 'Blocked "phase6_scale_runtime has no recorded Owner grant; zero HTTP requests issued"' "recorded Owner gate guard"
Assert-Contains '$expectedCriterionSha256 = "edeeac95fac6fefe1dcde5b77a5d8b236685f28adf66f357706aed26971ed85f"' "locked criterion byte hash"
Assert-Contains 'caller-supplied criterion files are forbidden for a hosted write run' "canonical criterion path guard"
Assert-Contains 'caller-supplied hosted-state files are forbidden for a hosted write run' "canonical hosted-state path guard"
Assert-Contains 'git.exe -C $repoRoot diff --quiet HEAD -- $trackedTruthRelativePath' "tracked truth HEAD-byte guard"
Assert-Contains '$handler.AllowAutoRedirect = $false' "cross-origin redirect/token-leak guard"
Assert-Contains 'phase6-scale-hosted-deployment-current-v1' "isolated Phase6 hosted-state contract"
Assert-Contains 'cloudflare-native-hosted-current-v1' "canonical O2Core hosted-state contract"
Assert-Contains 'cloudflare-d1-stateful-runtime-hosted-proof-v1' "canonical O2Core hosted evidence contract"
Assert-Contains 'phase6-scale-deployment-preflight-evidence-v1' "immutable deployment preflight contract"
Assert-Contains 'hostedEvidence.hosted_write_read_delete_verified -eq $false' "truthful pre-run write/read/delete non-claim"
Assert-Contains 'hostedEvidence.health_status -eq 200' "single health-200 preflight binding"
Assert-Contains 'Get-NonNegativeInteger $hostedEvidence.production_worker_request_count' "strict production Worker request parsing"
Assert-Contains 'Get-NonNegativeInteger $hostedEvidence.preview_worker_request_count' "strict Preview Worker request parsing"
Assert-Contains '$evidenceProductionWorkerRequests -eq 1 -and $evidencePreviewWorkerRequests -eq 0' "exactly Production=1 and Preview=0 request binding"
Assert-Contains 'hostedEvidence.health_json_source_binding_verified -eq $true' "health JSON source binding"
Assert-Contains 'hostedEvidence.preview_guard_verified -eq $true' "Preview zero-request guard binding"
Assert-Contains 'hostedEvidence.source_bundle_sha256' "uploaded bundle binding"
Assert-Contains 'Get-GitArchiveSha256' "Git archive source recomputation"
Assert-Contains 'hostedEvidence.worker_version_id' "Worker version binding"
Assert-Contains 'hostedEvidence.deployment_id' "deployment identity binding"
Assert-Contains 'worker_version_id = [string]$hostedEvidence.worker_version_id' "Worker version evidence binding"
Assert-Contains 'deployment_id = [string]$hostedEvidence.deployment_id' "deployment identity evidence binding"
Assert-Contains 'merge-base --is-ancestor' "deployed source ancestor binding"
Assert-Contains 'c24b7bfddc37cfa0c16d1ebc7f70829417ac4080' "contract-origin loop-fix lower bound"
Assert-Contains 'source_control_allowlist_v1' "source/control allowlist binding mode"
Assert-Contains '$unexpectedControlDelta.Count -eq 0' "source/control path allowlist"
Assert-Contains 'scripts/collect-phase6-scale-execution-readback.ps1' "post-run collector control allowlist"
Assert-Contains 'scripts/write-phase6-scale-deployment-preflight.ps1' "deployment-preflight writer control allowlist"
Assert-Contains 'scripts/write-phase6-scale-deployment-preflight-static.ps1' "deployment-preflight writer test control allowlist"
Assert-Contains 'control_delta = @($controlDelta)' "source/control delta evidence"
Assert-Contains 'source_commit_sha = [string]$hostedState.source_commit_sha' "execution provenance source binding"
Assert-Contains 'Assert-TrackedHeadBytes $hostedEvidenceRelativePath' "deployment evidence existed at execution HEAD"
Assert-Contains 'hosted deployment evidence is future-dated' "future deployment evidence rejection"
Assert-Contains 'hosted deployment evidence is stale' "stale deployment evidence rejection"
Assert-Contains '$canonicalEvidenceCheckedAt -eq $canonicalHostedVerifiedAt' "canonical O2Core timestamp parity"
Assert-Contains '$deploymentCheckedAt -eq $deploymentPreflightVerifiedAt' "deployment preflight timestamp parity"
Assert-Contains 'Phase6 Preview-to-production deployment window exceeded ten minutes' "ten-minute deployment window"
Assert-Contains 'canonical O2Core hosted evidence is stale' "canonical O2Core 24-hour freshness"
Assert-Contains 'hosted deployment evidence is stale' "deployment preflight 24-hour freshness"
Assert-Contains '$githubRunAttempt -eq 1' "GitHub rerun rejection"
Assert-Contains 'PHASE6_GITHUB_ENVIRONMENT' "protected GitHub Environment binding"
Assert-Contains 'PHASE6_ENVIRONMENT_REVIEW_PATH' "human Environment-review artifact input"
Assert-Contains 'github-actions-phase6-environment-review-v1' "human Environment-review evidence contract"
Assert-Contains 'human_review_verified = $true' "human Environment review verdict"
Assert-Contains 'review_artifact_sha256' "Environment-review artifact digest binding"
Assert-Contains 'review_sidecar_sha256' "Environment-review sidecar digest binding"
Assert-Contains '$scaleGate.live_verified -eq $false' "unconsumed gate guard"
Assert-Contains '$readExpected -eq 800' "exact 800-read contract"
Assert-Contains '$declaredReadTiers.Count -eq 3' "exact three-tier contract"
Assert-Contains '@{ concurrency = 1; requests = 60 }' "locked c1 read tier"
Assert-Contains '@{ concurrency = 10; requests = 240 }' "locked c10 read tier"
Assert-Contains '@{ concurrency = 50; requests = 500 }' "locked c50 read tier"
Assert-Contains '$writeExpected -eq 50' "exact 50-record contract"
Assert-Contains '$writeConcurrency -eq 10' "write concurrency 10 contract"
Assert-Contains '$maxWorkerRequests -eq 900' "900-Worker-request cap"
Assert-Contains '$httpClient.Timeout = [TimeSpan]::FromSeconds(10)' "fail-fast request timeout within cleanup-safe job budget"
Assert-Contains 'url = "$BaseUrl/api/v1/builds"' "real build POST path"
Assert-Contains 'url = "$BaseUrl/api/v1/build/$id"' "real build DELETE path"
Assert-Contains '} finally {' "literal cleanup finally block"
Assert-Contains '$deleteResponses = Invoke-HttpBatch $deleteSpecs $writeConcurrency $true' "cleanup invoked from finally path"
Assert-Contains 'response_readback_verified' "response readback proof"
Assert-Contains 'audit_persisted_verified' "audit proof"
Assert-Contains 'audit_readback_verified' "audit event readback proof"
Assert-Contains 'delete_readback_verified' "active-row absence proof"
Assert-Contains 'field:request_id' "request correlation validation"
Assert-Contains 'field:audit_event_id' "audit event identity validation"
Assert-Contains 'source_archive_sha256' "archive binding"
Assert-Contains 'verifier_script_sha256' "verifier byte binding"
Assert-Contains 'repository_head_sha' "repository HEAD binding"
Assert-Contains 'capability_state_sha256' "pre-run capability-state binding"
Assert-Contains 'gate_identity_sha256' "pre-run Owner-gate identity binding"
Assert-Contains '[IO.FileMode]::CreateNew' "immutable evidence creation"
Assert-Contains '$shaStream = [IO.File]::Open($shaPath, [IO.FileMode]::CreateNew' "immutable digest sidecar creation"
Assert-Contains '$post429 -gt 0 -or $delete429 -gt 0' "write 429 fail-closed contract"
Assert-Contains '$readOther = [int](($tierResults | Measure-Object -Property other_status -Sum).Sum)' "unexpected read status accounting"
Assert-Contains '$transportTotal -gt 0' "transport failure fail-closed contract"
Assert-Contains '$readOther -gt 0' "unexpected read status fail-closed contract"
Assert-Contains 'criterion edge control must remain attribution-only' "edge control non-pass criterion binding"
if ($source.Contains('$failures.Add("edge_control_failure")')) {
  throw "edge control is attribution-only and must not decide the Worker pass criterion"
}
Assert-Contains 'Get-NonNegativeInteger' "strict non-negative integer parsing"
Assert-Contains 'response accounting is not exact' "exact response accounting"
Assert-Contains '$literalSuccessCount = [int]($validHealthJsonCount + $validCreatedIds.Count + $literalCleanupSuccessCount)' "literal success recomputation"
Assert-Contains 'http_429_counted_as_success = $false' "429 excluded from literal success"
Assert-Contains 'duplicate_audit_event_id' "duplicate audit event rejection"
Assert-Contains 'phase6-scale-execution-provenance-v1' "trusted runner provenance contract"
Assert-Contains 'provisional_pending_github_readback' "post-run readback pending state"
Assert-Contains 'GITHUB_ACTIONS' "GitHub Actions execution guard"
Assert-Contains 'GITHUB_SHA' "GitHub execution SHA binding"
Assert-Contains 'post_run_api_readback_required = $true' "post-run independent readback requirement"
Assert-Contains 'records = @($tierRecordEvidence)' "raw read latency/status evidence"
Assert-Contains 'edge_control_records = @($controlRecordEvidence)' "raw edge-control latency/status evidence"
Assert-Contains 'Remove-Item -LiteralPath $reportPath -Force' "orphan report cleanup on sidecar failure"
Assert-Contains 'gate_promotion_performed = $false' "no gate promotion"
Assert-Contains 'percentage_credit_awarded = 0' "no percentage credit"

$expectedCheckoutPin = 'actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803 # v6'
$expectedUploadPin = 'actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4.6.2'
if (-not $workflowSource.Contains($expectedCheckoutPin) -or -not $workflowSource.Contains($expectedUploadPin)) {
  throw 'Phase6 scale workflow actions are not pinned to the approved immutable SHAs'
}
$workflowUses = @([regex]::Matches($workflowSource, '(?m)^\s*uses:\s*(?<target>\S+)(?:\s+#\s*(?<comment>[^\r\n]+))?\s*$'))
if ($workflowUses.Count -ne 2) { throw 'Phase6 scale workflow must use exactly checkout and upload-artifact' }
foreach ($use in $workflowUses) {
  if ([string]$use.Groups['target'].Value -cnotmatch '^[^@]+@[0-9a-f]{40}$') {
    throw 'Phase6 scale workflow contains an unpinned action reference'
  }
}
foreach ($requiredWorkflowContract in @(
  'workflow_dispatch:',
  'source_sha:',
  'allow_hosted_writes:',
  'permissions:',
  'contents: read',
  'actions: read',
  'environment: phase6-scale-hosted-writes',
  'timeout-minutes: 35',
  'persist-credentials: false',
  'docs/runtime-state/cloudflare-native-hosted-current.json',
  'docs/runtime-state/phase6-scale-hosted-current.json',
  '$preflight.preview_guard_verified -ne $true',
  '$preflight.hosted_write_read_delete_verified -ne $false',
  '$env:GITHUB_RUN_ATTEMPT -cne ''1''',
  '$runs.total_count -ne 1',
  'Phase6 one-shot guard found a rerun or another dispatch',
  'actions/runs/$($env:GITHUB_RUN_ID)/approvals',
  'github-actions-phase6-environment-review-v1',
  'Exactly one approved human review for the protected Phase6 Environment is required.',
  'PHASE6_GITHUB_ENVIRONMENT: phase6-scale-hosted-writes',
  'PHASE6_ENVIRONMENT_REVIEW_PATH: ${{ steps.preflight.outputs.environment_review_path }}',
  '${{ steps.preflight.outputs.environment_review_sidecar_path }}',
  '$gate.live_verified -ne $false',
  'AGENT_API_AUTH_TOKEN: ${{ secrets.AGENT_API_AUTH_TOKEN }}',
  'scripts/verify-phase6-scale-runtime.ps1 -AllowHostedWrites',
  'phase6-scale-execution-evidence-${{ github.run_id }}-${{ github.run_attempt }}',
  'overwrite: false'
)) {
  if (-not $workflowSource.Contains($requiredWorkflowContract)) {
    throw "Phase6 scale workflow is missing contract: $requiredWorkflowContract"
  }
}
$githubApiReads = @([regex]::Matches($workflowSource, '\.GetAsync\(')).Count
if ($githubApiReads -ne 2 -or -not $workflowSource.Contains('$handler.AllowAutoRedirect = $false')) {
  throw 'Phase6 workflow must perform exactly two redirect-free GitHub preflight reads: one-shot runs plus Environment approvals.'
}
foreach ($forbiddenWorkflowContract in @('push:', 'pull_request:', 'schedule:', 'workflow_run:', 'docker login', 'gh auth', 'registry push', 'production deploy', '-Promote')) {
  if ($workflowSource -match "(?im)^\s*$([regex]::Escape($forbiddenWorkflowContract))") {
    throw "Phase6 scale workflow contains forbidden trigger or mutation: $forbiddenWorkflowContract"
  }
}

$authGuardOffset = $source.IndexOf('if ([string]::IsNullOrWhiteSpace($authValue))')
$ownerGuardOffset = $source.IndexOf('if (-not $AllowHostedWrites)')
$recordedOwnerGuardOffset = $source.IndexOf('if ($null -eq $scaleGate -or $scaleGate.owner_granted -ne $true')
$unconsumedGateGuardOffset = $source.IndexOf('$scaleGate.live_verified -eq $false')
$rerunGuardOffset = $source.IndexOf('$githubRunAttempt -eq 1')
$clientOffset = $source.IndexOf('Add-Type -AssemblyName System.Net.Http')
if ($authGuardOffset -lt 0 -or $ownerGuardOffset -lt 0 -or $recordedOwnerGuardOffset -lt 0 -or $unconsumedGateGuardOffset -lt 0 -or $rerunGuardOffset -lt 0 -or $clientOffset -lt 0 -or
    $authGuardOffset -ge $clientOffset -or $ownerGuardOffset -ge $clientOffset -or $recordedOwnerGuardOffset -ge $clientOffset -or $unconsumedGateGuardOffset -ge $clientOffset -or $rerunGuardOffset -ge $clientOffset) {
  throw "authorization guard must precede HttpClient construction"
}

$sidecarCreateOffset = $source.IndexOf('$shaStream = [IO.File]::Open($shaPath, [IO.FileMode]::CreateNew')
$reportCreateOffset = $source.IndexOf('$stream = [IO.File]::Open($reportPath, [IO.FileMode]::CreateNew')
if ($sidecarCreateOffset -lt 0 -or $reportCreateOffset -lt 0 -or $sidecarCreateOffset -ge $reportCreateOffset) {
  throw "digest sidecar must be created before the immutable report"
}

if ($source.Contains('+ $read429') -or $source.Contains('+`n  $read429')) {
  throw "read 429 must never contribute to the literal success numerator"
}

& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'write-phase6-scale-deployment-preflight-static.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Phase6 deployment-preflight writer static contract failed' }

Write-Host "[phase6-scale-static] PASS: parser, truthful deployment-health preflight, zero-request authorization, exact accounting, attribution-only edge control, literal success, source/deployment/time parity, provisional execution provenance, evidence-pair atomicity, and no-promotion contracts"

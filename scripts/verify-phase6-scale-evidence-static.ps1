#Requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\', '/')
$verifierPath = Join-Path $PSScriptRoot 'verify-phase6-scale-evidence.ps1'
$collectorPath = Join-Path $PSScriptRoot 'collect-phase6-scale-execution-readback.ps1'
# The project pins scratch work to D:\_sb_tmp on the Windows workstation, but pr-check runs
# this contract on ubuntu-latest where that drive does not exist: GetFullPath would resolve it
# relative to the working directory and the cleanup guard below would correctly refuse to
# delete the resulting bogus path. Prefer the pinned root when it is actually present, and fall
# back to the platform temp directory otherwise.
$preferredTestRoot = if (-not [string]::IsNullOrWhiteSpace($env:SUPERBRAIN_TEST_ROOT)) {
  $env:SUPERBRAIN_TEST_ROOT
} elseif (Test-Path -LiteralPath 'D:/_sb_tmp' -PathType Container) {
  'D:/_sb_tmp'
} else {
  [IO.Path]::GetTempPath()
}
$testRoot = [IO.Path]::GetFullPath($preferredTestRoot).TrimEnd('\', '/')
$tempRoot = Join-Path $testRoot ('phase6-scale-evidence-static-' + [Guid]::NewGuid().ToString('N'))
$utf8NoBom = [Text.UTF8Encoding]::new($false)

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Write-Json([string]$Path, $Value) {
  [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 30), $utf8NoBom)
}

function Write-Digest([string]$Path) {
  $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
  [IO.File]::WriteAllText("$Path.sha256", "$hash  $([IO.Path]::GetFileName($Path))`n", $utf8NoBom)
}

function Get-StringSha256([string]$Value) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return (($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value)) | ForEach-Object { $_.ToString('x2') }) -join '')
  } finally {
    $sha.Dispose()
  }
}

function Get-GitArchiveSha256([string]$CommitSha) {
  $archivePath = Join-Path $testRoot ("phase6-static-archive-$([Guid]::NewGuid().ToString('N')).tar")
  try {
    & git -C $repoRoot archive --format=tar "--output=$archivePath" $CommitSha
    Assert-True ($LASTEXITCODE -eq 0) 'Unable to build static-fixture source archive.'
    return (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
  } finally {
    if (Test-Path -LiteralPath $archivePath -PathType Leaf) { Remove-Item -LiteralPath $archivePath -Force }
  }
}

function Write-EvidenceBundle([string]$EvidencePath, $Evidence, [string]$ReadbackPath, $Readback) {
  Write-Json $EvidencePath $Evidence
  Write-Digest $EvidencePath
  $Readback.downloaded_evidence_sha256 = (Get-FileHash -LiteralPath $EvidencePath -Algorithm SHA256).Hash.ToLowerInvariant()
  $Readback.downloaded_sidecar_sha256 = (Get-FileHash -LiteralPath "$EvidencePath.sha256" -Algorithm SHA256).Hash.ToLowerInvariant()
  $Readback.sidecar_declared_evidence_sha256 = $Readback.downloaded_evidence_sha256
  Write-Json $ReadbackPath $Readback
  Write-Digest $ReadbackPath
}

function Invoke-ExpectedPass([string]$Evidence, [string]$Criterion, [string]$Hosted, [string]$Capability) {
  $output = @(& pwsh -NoProfile -File $verifierPath `
    -EvidencePath $Evidence `
    -CriterionPath $Criterion `
    -HostedStatePath $Hosted `
    -DeploymentPreflightStatePath $script:deploymentPreflightPath `
    -CapabilityStatePath $Capability `
    -AllowTestPaths `
    -TrustSyntheticGitHubReadbackForTests 2>&1)
  Assert-True ($LASTEXITCODE -eq 0) ("Expected verifier pass, received: " + ($output -join ' | '))
  Assert-True (($output -join "`n") -match 'promotion=false read_only=true') 'Read-only verifier did not report promotion=false.'
}

function Invoke-ExpectedFailure([string]$Evidence, [string]$Criterion, [string]$Hosted, [string]$Capability, [string]$Label) {
  $output = @(& pwsh -NoProfile -File $verifierPath `
    -EvidencePath $Evidence `
    -CriterionPath $Criterion `
    -HostedStatePath $Hosted `
    -DeploymentPreflightStatePath $script:deploymentPreflightPath `
    -CapabilityStatePath $Capability `
    -AllowTestPaths `
    -TrustSyntheticGitHubReadbackForTests 2>&1)
  Assert-True ($LASTEXITCODE -ne 0) "$Label unexpectedly passed."
}

function Invoke-ExpectedUntrustedFailure([string]$Evidence, [string]$Criterion, [string]$Hosted, [string]$Capability) {
  $output = @(& pwsh -NoProfile -File $verifierPath `
    -EvidencePath $Evidence `
    -CriterionPath $Criterion `
    -HostedStatePath $Hosted `
    -DeploymentPreflightStatePath $script:deploymentPreflightPath `
    -CapabilityStatePath $Capability `
    -AllowTestPaths 2>&1)
  Assert-True ($LASTEXITCODE -ne 0) 'A fully self-consistent synthetic GitHub bundle passed without the explicit test-only trust switch.'
}

$tokens = $null
$parseErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile($verifierPath, [ref]$tokens, [ref]$parseErrors)
Assert-True (@($parseErrors).Count -eq 0) 'Evidence verifier has PowerShell parse errors.'
$collectorTokens = $null
$collectorParseErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile($collectorPath, [ref]$collectorTokens, [ref]$collectorParseErrors)
Assert-True (@($collectorParseErrors).Count -eq 0) 'Execution-readback collector has PowerShell parse errors.'
$collectorSource = Get-Content -LiteralPath $collectorPath -Raw
foreach ($collectorContract in @(
  'github-actions-phase6-scale-execution-readback-v1',
  'application/vnd.github+json',
  'downloaded_archive_sha256',
  '[IO.FileMode]::CreateNew',
  'token_used=false promotion=false'
)) {
  Assert-True ($collectorSource.Contains($collectorContract)) "Execution-readback collector is missing contract: $collectorContract"
}
Assert-True ($collectorSource -notmatch '(?i)DefaultRequestHeaders\.Authorization|GITHUB_TOKEN|GH_TOKEN|Bearer\s') 'Execution-readback collector must never read or send a GitHub token.'
$source = Get-Content -LiteralPath $verifierPath -Raw
foreach ($required in @(
  "if (-not `$Promote)",
  'Assert-True (-not $AllowTestPaths)',
  'ExpectedCapabilityStateSha256',
  'ExpectedGateIdentitySha256',
  '[switch]$ValidateOnly',
  "Assert-Boolean `$gate 'owner_granted' `$true",
  'Assert-TrackedCleanAgainstHead',
  '[IO.File]::Replace',
  "`$candidateGate.live_verified = `$true",
  "`$candidateGate.paid_provider = `$false",
  '$candidateGate.evidence_sha256 = $evidenceSha256',
  'phase6-scale-execution-provenance-v1',
  'github-actions-phase6-scale-execution-readback-v1',
  'github-actions-phase6-environment-review-v1',
  'actions/workflows/phase6-scale-runtime.yml/runs?event=workflow_dispatch',
  'actions/runs/$runId/approvals',
  'Execution must be the first and only run attempt.',
  'Preview-to-production deployment window exceeded ten minutes.',
  'docs\runtime-state\cloudflare-native-hosted-current.json',
  'docs\runtime-state\phase6-scale-hosted-current.json',
  'DeploymentPreflightStatePath',
  'cloudflare-d1-stateful-runtime-hosted-proof-v1',
  'hosted_write_read_delete_verified -eq $false',
  'preview_guard_verified -eq $true',
  'c24b7bfddc37cfa0c16d1ebc7f70829417ac4080',
  'Scale criterion edge control is not attribution-only.',
  'Automatic rollback did not restore the original capability state.'
)) {
  Assert-True ($source.Contains($required)) "Missing promotion safety contract: $required"
}
Assert-True ($source.Contains('Assert-LiveGithubExecutionProvenance')) 'Deep verifier lacks independent live GitHub provenance validation.'
Assert-True ($source -notmatch '(?i)DefaultRequestHeaders\.Authorization|Bearer\s|GITHUB_TOKEN|GH_TOKEN') 'Deep verifier must not read or send a GitHub token.'
Assert-True (-not $source.Contains('$candidateGate.owner_granted =')) 'Promoter must not synthesize owner_granted.'
Assert-True (-not $source.Contains('$candidateGate.owner_grant_ref =')) 'Promoter must not synthesize owner_grant_ref.'
$candidateValidationIndex = $source.IndexOf("Assert-True ([string]`$writtenCandidate.gates.phase6_scale_runtime.evidence_sha256")
$promotionReplaceIndex = $source.IndexOf('[IO.File]::Replace($temporaryPath, $resolvedCapabilityState, $backupPath, $true)')
$postPromotionReadIndex = $source.IndexOf("`$promoted = Read-JsonFile `$resolvedCapabilityState")
$rollbackReplaceIndex = $source.IndexOf('[IO.File]::Replace($backupPath, $resolvedCapabilityState, $failedPromotionPath, $true)')
Assert-True ($candidateValidationIndex -ge 0 -and $candidateValidationIndex -lt $promotionReplaceIndex) 'Candidate final validation must precede atomic promotion.'
Assert-True ($promotionReplaceIndex -ge 0 -and $promotionReplaceIndex -lt $postPromotionReadIndex) 'Post-promotion validation must follow atomic promotion.'
Assert-True ($rollbackReplaceIndex -gt $postPromotionReadIndex) 'Automatic rollback must remain reachable after post-promotion validation.'

New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
try {
  $criterionPath = Join-Path $tempRoot 'phase6-scale-criterion.json'
  $hostedPath = Join-Path $tempRoot 'cloudflare-native-hosted-current.json'
  $script:deploymentPreflightPath = Join-Path $tempRoot 'phase6-scale-hosted-current.json'
  $capabilityPath = Join-Path $tempRoot 'capability-gates.json'
  # Forward slashes: pr-check runs this on ubuntu-latest, where a backslash is a literal
  # character and -LiteralPath would look for a file whose name contains it.
  Copy-Item -LiteralPath (Join-Path $repoRoot 'docs/runtime-state/phase6-scale-criterion.json') -Destination $criterionPath
  Copy-Item -LiteralPath (Join-Path $repoRoot 'docs/runtime-state/capability-gates.json') -Destination $capabilityPath
  $criterion = Get-Content -LiteralPath $criterionPath -Raw | ConvertFrom-Json -Depth 30
  $hosted = [ordered]@{
    contract_version = 'phase6-scale-hosted-deployment-current-v1'
    status = 'preflight_verified'
    verified_at_utc = ''
    base_url = [string]$criterion.target.base_url
    runtime_contract_version = 'cloudflare-native-runtime-candidate-v2'
    health_contract_version = 'cloudflare-d1-stateful-runtime-v1'
    source_commit_sha = ''
    source_archive_sha256 = ''
    source_bundle_sha256 = ('3' * 64)
    worker_version_id = ''
    deployment_id = ''
    evidence_artifact = ''
    evidence_sha256 = ''
    health_status = 200
    d1_read_verified = $true
    production_worker_request_count = 1
    preview_worker_request_count = 0
    deployment_preflight_verified = $true
    health_json_source_binding_verified = $true
    preview_guard_verified = $true
    preview_guard_verified_at_utc = ''
    preview_worker_version_id = ''
    preview_deployment_id = ''
    hosted_write_read_delete_verified = $false
    phase6_scale_run_started = $false
    phase6_scale_run_verified = $false
    zero_card_verified = $true
    paid_provider = $false
    dev_only = $false
    secret_output = $false
    non_claims = @(
      'This preflight proves exactly one Worker request: one HTTP 200 health/source/deployment binding.',
      'The Preview guard used control-plane verification and issued zero Worker requests.',
      'No create, readback, delete, scale, release, or percentage credit is claimed.'
    )
  }
  $repositoryHeadSha = (& git -C $repoRoot rev-parse HEAD).Trim()
  $deployedSourceSha = (& git -C $repoRoot rev-parse HEAD^).Trim()
  $sourceArchiveSha256 = Get-GitArchiveSha256 $deployedSourceSha
  $generatedAt = (Get-Date).ToUniversalTime().AddMinutes(-2)
  $hostedVerifiedAt = $generatedAt.AddMinutes(-5)
  $previewVerifiedAt = $hostedVerifiedAt.AddMinutes(-1)
  $runCreatedAt = $generatedAt.AddMinutes(-1)
  $runUpdatedAt = $generatedAt.AddMinutes(1)
  $collectedAt = $generatedAt.AddMinutes(2)
  $githubRepository = 'strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM'
  [long]$githubRunId = 1234567890
  [int]$githubRunAttempt = 1
  $githubRunUrl = "https://github.com/$githubRepository/actions/runs/$githubRunId"
  $githubRef = 'refs/heads/codex/phase6-scale-static-fixture'
  $githubArtifactName = "phase6-scale-execution-evidence-$githubRunId-$githubRunAttempt"
  $githubActor = 'phase6-dispatcher'
  $githubTriggeringActor = 'phase6-dispatcher'
  $githubReviewer = 'phase6-reviewer'
  [long]$githubReviewerId = 7654321
  [long]$githubEnvironmentId = 161088068
  $githubEnvironmentName = 'phase6-scale-hosted-writes'
  $hosted.source_commit_sha = $deployedSourceSha
  $hosted.source_archive_sha256 = $sourceArchiveSha256
  $hosted.verified_at_utc = $hostedVerifiedAt.ToString('o')
  $workerVersionId = '11111111-1111-4111-8111-111111111111'
  $deploymentId = '22222222-2222-4222-8222-222222222222'
  $hosted.worker_version_id = $workerVersionId
  $hosted.deployment_id = $deploymentId
  $hosted.preview_guard_verified_at_utc = $previewVerifiedAt.ToString('o')
  $hosted.preview_worker_version_id = '33333333-3333-4333-8333-333333333333'
  $hosted.preview_deployment_id = '44444444-4444-4444-8444-444444444444'
  $deploymentPath = Join-Path $tempRoot 'phase6-deployment-preflight.json'
  $deployment = [ordered]@{
    contract_version = 'phase6-scale-deployment-preflight-evidence-v1'
    verified_at_utc = $hostedVerifiedAt.ToString('o')
    status = 'verified'
    purpose = 'phase6_scale_single_run_preflight'
    base_url = [string]$hosted.base_url
    source_commit_sha = [string]$hosted.source_commit_sha
    source_archive_sha256 = [string]$hosted.source_archive_sha256
    source_bundle_sha256 = [string]$hosted.source_bundle_sha256
    worker_version_id = $workerVersionId
    deployment_id = $deploymentId
    health_status = 200
    d1_read_verified = $true
    production_worker_request_count = 1
    preview_worker_request_count = 0
    source_binding_verified = $true
    health_json_source_binding_verified = $true
    preview_guard_verified = $true
    preview_guard_verified_at_utc = $previewVerifiedAt.ToString('o')
    preview_worker_version_id = [string]$hosted.preview_worker_version_id
    preview_deployment_id = [string]$hosted.preview_deployment_id
    hosted_write_read_delete_verified = $false
    phase6_scale_run_started = $false
    phase6_scale_run_verified = $false
    zero_card = $true
    paid_provider = $false
    dev_only = $false
    secret_output = $false
    producer = 'scripts/deploy-cloudflare-stateful-runtime.ps1'
    writer = 'scripts/write-phase6-scale-deployment-preflight.ps1'
    non_claims = @(
      'This preflight proves exactly one Worker request: one HTTP 200 health/source/deployment binding.',
      'The Preview guard used control-plane verification and issued zero Worker requests.',
      'No create, readback, delete, scale, release, or percentage credit is claimed.'
    )
  }
  Write-Json $deploymentPath $deployment
  Write-Digest $deploymentPath
  $hosted.evidence_artifact = $deploymentPath
  $hosted.evidence_sha256 = (Get-FileHash -LiteralPath $deploymentPath -Algorithm SHA256).Hash.ToLowerInvariant()
  Write-Json $script:deploymentPreflightPath $hosted

  $canonicalHosted = Get-Content -LiteralPath (Join-Path $repoRoot 'docs/runtime-state/cloudflare-native-hosted-current.json') -Raw | ConvertFrom-Json -Depth 30
  $sourceCanonicalEvidencePath = Join-Path $repoRoot ([string]$canonicalHosted.evidence_artifact)
  $canonicalHostedEvidence = Get-Content -LiteralPath $sourceCanonicalEvidencePath -Raw | ConvertFrom-Json -Depth 30
  $canonicalHostedEvidencePath = Join-Path $tempRoot 'canonical-o2core-hosted-evidence.json'
  $canonicalHostedEvidence.checked_at = $hostedVerifiedAt.ToString('o')
  $canonicalHostedEvidence.base_url = [string]$hosted.base_url
  $canonicalHostedEvidence.source_commit_sha = $deployedSourceSha
  $canonicalHostedEvidence.source_archive_sha256 = $sourceArchiveSha256
  $canonicalHostedEvidence.cloudflare_native_hosted_source_parity_verified = $true
  $canonicalHostedEvidence.cloudflare_native_create_enqueue_queue_do_d1_artifact_roundtrip = $true
  $canonicalHostedEvidence.cloudflare_native_d1_artifact_write_read_delete = $true
  $canonicalHostedEvidence.cloudflare_native_d1_read_verified = $true
  $canonicalHostedEvidence.cloudflare_native_zero_card_execution_verified = $true
  $canonicalHostedEvidence.cloudflare_native_paid_fallback_used = $false
  $canonicalHostedEvidence.secret_output = $false
  Write-Json $canonicalHostedEvidencePath $canonicalHostedEvidence
  $canonicalHosted.contract_version = 'cloudflare-native-hosted-current-v1'
  $canonicalHosted.status = 'verified'
  $canonicalHosted.verified_at_utc = $hostedVerifiedAt.ToString('o')
  $canonicalHosted.base_url = [string]$hosted.base_url
  $canonicalHosted.source_commit_sha = $deployedSourceSha
  $canonicalHosted.source_archive_sha256 = $sourceArchiveSha256
  $canonicalHosted.evidence_artifact = $canonicalHostedEvidencePath
  $canonicalHosted.evidence_sha256 = (Get-FileHash -LiteralPath $canonicalHostedEvidencePath -Algorithm SHA256).Hash.ToLowerInvariant()
  $canonicalHosted.hosted_source_parity_verified = $true
  $canonicalHosted.hosted_stateful_roundtrip_verified = $true
  $canonicalHosted.create_enqueue_queue_do_d1_artifact_roundtrip = $true
  $canonicalHosted.d1_artifact_write_read_delete_verified = $true
  $canonicalHosted.zero_card_verified = $true
  $canonicalHosted.paid_provider = $false
  $canonicalHosted.dev_only = $false
  $canonicalHosted.hosted_proof = $true
  $canonicalHosted.secret_output = $false
  Write-Json $hostedPath $canonicalHosted
  $capability = Get-Content -LiteralPath $capabilityPath -Raw | ConvertFrom-Json -Depth 30
  $ownerGrantRef = 'owner-grant:phase6-scale:pre-live'
  $capability.gates.phase6_scale_runtime.owner_granted = $true
  $capability.gates.phase6_scale_runtime.owner_grant_ref = $ownerGrantRef
  $capability.gates.phase6_scale_runtime.live_verified = $false
  $capability.gates.phase6_scale_runtime.evidence_artifact = ''
  if ($null -eq $capability.gates.phase6_scale_runtime.PSObject.Properties['evidence_sha256']) {
    $capability.gates.phase6_scale_runtime | Add-Member -NotePropertyName evidence_sha256 -NotePropertyValue ''
  } else {
    $capability.gates.phase6_scale_runtime.evidence_sha256 = ''
  }
  $capability.gates.phase6_scale_runtime.verified_at_utc = ''
  $capability.gates.phase6_scale_runtime.provider = ''
  $capability.gates.phase6_scale_runtime.paid_provider = $false
  $capability.gates.phase6_scale_runtime.verifier = ''
  Write-Json $capabilityPath $capability
  $capabilityStateSha256 = (Get-FileHash -LiteralPath $capabilityPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $gateIdentityJson = [ordered]@{
    gate_id = 'phase6_scale_runtime'
    owner_granted = $true
    owner_grant_ref = $ownerGrantRef
    paid_provider = $false
  } | ConvertTo-Json -Compress
  $gateIdentitySha256 = Get-StringSha256 $gateIdentityJson
  $runtimeVerifierSha256 = (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'verify-phase6-scale-runtime.ps1') -Algorithm SHA256).Hash.ToLowerInvariant()
  $stamp = $generatedAt.ToString('yyyyMMddTHHmmssfffZ')
  $runId = [Guid]::NewGuid().ToString('N')
  $evidencePath = Join-Path $tempRoot "scale-evidence-$stamp-$runId.json"
  $environmentReviewCapturedAt = $generatedAt.AddSeconds(-30)
  $environmentReviewPath = Join-Path $tempRoot "environment-review-$githubRunId-$githubRunAttempt.json"
  $environmentReview = [ordered]@{
    contract_version = 'github-actions-phase6-environment-review-v1'
    captured_at_utc = $environmentReviewCapturedAt.ToString('o')
    repository = $githubRepository
    run_id = $githubRunId
    run_attempt = $githubRunAttempt
    head_sha = $repositoryHeadSha
    environment_name = $githubEnvironmentName
    environment_id = $githubEnvironmentId
    review_state = 'approved'
    reviewer_login = $githubReviewer
    reviewer_id = $githubReviewerId
    reviewer_type = 'User'
    actor_login = $githubActor
    triggering_actor_login = $githubTriggeringActor
    secret_output = $false
  }
  Write-Json $environmentReviewPath $environmentReview
  Write-Digest $environmentReviewPath
  $environmentReviewSha256 = (Get-FileHash -LiteralPath $environmentReviewPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $environmentReviewSidecarSha256 = (Get-FileHash -LiteralPath "$environmentReviewPath.sha256" -Algorithm SHA256).Hash.ToLowerInvariant()
  $writeRecords = @()
  $cleanupRecords = @()
  for ($index = 1; $index -le 50; $index++) {
    $id = "p6s$($runId.Substring(0, 24))$($index.ToString('00'))"
    $prompt = "Phase 6 zero-card scale verification record $index for run $runId"
    $html = "<!doctype html><html><head><meta charset=`"utf-8`"><title>Phase 6 $index</title></head><body><main data-phase6-scale=`"$id`">Scale record $index</main></body></html>"
    $writeRecords += [ordered]@{
      ordinal = $index
      id = $id
      response_id = $id
      request_id = "phase6-scale-$runId-$index-create"
      audit_event_id = [Guid]::NewGuid().ToString()
      status_code = 201
      latency_ms = [double](100 + $index)
      response_readback_verified = $true
      audit_readback_verified = $true
      prompt_sha256 = Get-StringSha256 $prompt
      html_sha256 = Get-StringSha256 $html
      created_at_utc = $generatedAt.AddSeconds(-30).ToString('o')
      updated_at_utc = $generatedAt.AddSeconds(-30).ToString('o')
      audit_persisted_verified = $true
      validation_errors = @()
    }
    $cleanupRecords += [ordered]@{
      ordinal = $index
      id = $id
      request_id = "phase6-scale-$runId-$id-delete"
      audit_event_id = [Guid]::NewGuid().ToString()
      status_code = 200
      latency_ms = [double](120 + $index)
      expected_deleted_record = $true
      cleanup_verified = $true
      audit_persisted_verified = $true
      audit_readback_verified = $true
      delete_readback_verified = $true
      validation_errors = @()
    }
  }
  $expectedNonClaims = @($criterion.non_claims) + @(
    'This evidence file does not promote phase6_scale_runtime.',
    'This provisional evidence requires an independently downloaded post-run GitHub API and artifact readback before it can verify execution provenance.',
    'The authorization token is neither printed nor persisted.',
    'Control requests use the Cloudflare edge path and are not Worker requests.'
  )
  $readTierFixtures = @()
  foreach ($plan in @(
    [ordered]@{ concurrency = 1; requests = 60; latency = 100.0; control_latency = 20.0 },
    [ordered]@{ concurrency = 10; requests = 240; latency = 200.0; control_latency = 30.0 },
    [ordered]@{ concurrency = 50; requests = 500; latency = 300.0; control_latency = 40.0 }
  )) {
    $healthRecords = @()
    for ($ordinal = 1; $ordinal -le [int]$plan.requests; $ordinal++) {
      $healthRecords += [ordered]@{
        ordinal = $ordinal
        key = "health-$([int]$plan.concurrency)-$ordinal"
        status_code = 200
        latency_ms = [double]$plan.latency
        health_contract_verified = $true
        validation_errors = @()
      }
    }
    $controlRecords = @()
    for ($ordinal = 1; $ordinal -le ([int]$plan.concurrency * 4); $ordinal++) {
      $controlRecords += [ordered]@{
        ordinal = $ordinal
        key = "control-$([int]$plan.concurrency)-$ordinal"
        status_code = 200
        latency_ms = [double]$plan.control_latency
        response_ok = $true
      }
    }
    $readTierFixtures += [ordered]@{
      concurrency = [int]$plan.concurrency
      requests = [int]$plan.requests
      valid_health_200 = [int]$plan.requests
      invalid_health_200 = 0
      throttled_429 = 0
      server_5xx = 0
      transport_fail = 0
      other_status = 0
      p50_ms = [double]$plan.latency
      p95_ms = [double]$plan.latency
      p99_ms = [double]$plan.latency
      edge_control_p95_ms = [double]$plan.control_latency
      worker_share_p95_ms = [double]($plan.latency - $plan.control_latency)
      records = $healthRecords
      edge_control_records = $controlRecords
    }
  }
  $validEvidence = [ordered]@{
    contract_version = 'phase6-scale-evidence-v2'
    generated_at_utc = $generatedAt.ToString('o')
    run_id = $runId
    result = 'provisional_pending_github_readback'
    criterion_binding = [ordered]@{
      contract_version = [string]$criterion.contract_version
      gate_id = 'phase6_scale_runtime'
      file_sha256 = (Get-FileHash -LiteralPath $criterionPath -Algorithm SHA256).Hash.ToLowerInvariant()
      declared_before_first_run = $true
      declared_before_first_full_write_run = $true
    }
    source_binding = [ordered]@{
      hosted_state_contract_version = [string]$canonicalHosted.contract_version
      hosted_state_file_sha256 = (Get-FileHash -LiteralPath $hostedPath -Algorithm SHA256).Hash.ToLowerInvariant()
      hosted_runtime_evidence_artifact = [string]$canonicalHosted.evidence_artifact
      hosted_runtime_evidence_sha256 = ([string]$canonicalHosted.evidence_sha256).ToLowerInvariant()
      deployment_preflight_state_contract_version = [string]$hosted.contract_version
      deployment_preflight_state_file_sha256 = (Get-FileHash -LiteralPath $script:deploymentPreflightPath -Algorithm SHA256).Hash.ToLowerInvariant()
      base_url = [string]$hosted.base_url
      source_commit_sha = [string]$hosted.source_commit_sha
      source_archive_sha256 = [string]$hosted.source_archive_sha256
      source_bundle_sha256 = [string]$hosted.source_bundle_sha256
      deployment_evidence_artifact = [string]$hosted.evidence_artifact
      deployment_evidence_sha256 = ([string]$hosted.evidence_sha256).ToLowerInvariant()
      worker_version_id = $workerVersionId
      deployment_id = $deploymentId
      preview_guard_verified = $true
      preview_guard_verified_at_utc = $previewVerifiedAt.ToString('o')
      preview_worker_version_id = [string]$hosted.preview_worker_version_id
      preview_deployment_id = [string]$hosted.preview_deployment_id
      verifier_script_sha256 = $runtimeVerifierSha256
      repository_head_sha = $repositoryHeadSha
      capability_state_sha256 = $capabilityStateSha256
      gate_identity_sha256 = $gateIdentitySha256
      owner_granted = $true
      owner_grant_ref = $ownerGrantRef
      health_json_source_binding_verified = $true
      execution_attestation = [ordered]@{
        contract_version = 'phase6-scale-execution-provenance-v1'
        status = 'provisional_pending_github_readback'
        binding_mode = 'source_control_allowlist_v1'
        github_actions = $true
        repository = $githubRepository
        run_id = $githubRunId
        run_attempt = $githubRunAttempt
        run_url = $githubRunUrl
        event_name = 'workflow_dispatch'
        ref = $githubRef
        head_sha = $repositoryHeadSha
        workflow = 'Phase6 scale runtime'
        workflow_ref = "$githubRepository/.github/workflows/phase6-scale-runtime.yml@$githubRef"
        job = 'scale-runtime'
        source_commit_sha = $deployedSourceSha
        control_delta = @('scripts/verify-phase6-scale-runtime.ps1')
        artifact_name = $githubArtifactName
        environment_review = [ordered]@{
          contract_version = 'github-actions-phase6-environment-review-v1'
          review_artifact_name = [IO.Path]::GetFileName($environmentReviewPath)
          review_artifact_sha256 = $environmentReviewSha256
          review_sidecar_name = [IO.Path]::GetFileName("$environmentReviewPath.sha256")
          review_sidecar_sha256 = $environmentReviewSidecarSha256
          captured_at_utc = $environmentReviewCapturedAt.ToString('o')
          environment_name = $githubEnvironmentName
          environment_id = $githubEnvironmentId
          review_state = 'approved'
          reviewer_login = $githubReviewer
          reviewer_id = $githubReviewerId
          reviewer_type = 'User'
          actor_login = $githubActor
          triggering_actor_login = $githubTriggeringActor
          human_review_verified = $true
        }
        post_run_api_readback_required = $true
        verified = $false
      }
    }
    request_budget = [ordered]@{
      worker_cap = 900
      worker_requests_issued = 900
      read_requests_issued = 800
      create_requests_issued = 50
      cleanup_delete_requests_issued = 50
      control_edge_requests_issued = 244
      cap_respected = $true
      exact_plan_executed = $true
    }
    read_tiers = $readTierFixtures
    health_validation = [ordered]@{ valid_json_count = 800; invalid_json_or_contract_count = 0; validation_failures = @() }
    write_tier = [ordered]@{
      concurrency = 10
      records_planned = 50
      valid_post_insert_readbacks = 50
      record_loss_count = 0
      duplicate_count = 0
      duplicate_request_id_count = 0
      duplicate_audit_event_id_count = 0
      field_failure_count = 0
      hash_failure_count = 0
      audit_failure_count = 0
      throttled_429 = 0
      server_5xx = 0
      transport_fail = 0
      p50_ms = 125.0
      p95_ms = 148.0
      p99_ms = 150.0
      records = $writeRecords
    }
    cleanup = [ordered]@{
      verified_count = 50
      literal_success_count = 50
      required_count = 50
      complete = $true
      throttled_429 = 0
      unclean_throttle_count = 0
      server_5xx = 0
      transport_fail = 0
      p95_ms = 168.0
      records = $cleanupRecords
    }
    aggregate = [ordered]@{
      literal_success_count = 900
      success_ratio = 1.0
      worst_p95_ms = 300.0
      throttled_429_total = 0
      server_5xx_total = 0
      transport_fail_total = 0
      edge_control_failure_count = 0
      http_429_counted_as_success = $false
      failures = @()
      criterion_met = $true
    }
    auth = [ordered]@{ environment_variable_name = 'AGENT_API_AUTH_TOKEN'; value_recorded = $false }
    gate_may_open = $false
    gate_promotion_performed = $false
    percentage_credit_awarded = 0
    non_claims = $expectedNonClaims
  }

  $executionReadbackPath = "$evidencePath.execution-readback.json"
  $githubArtifactId = 987654321
  $downloadedArchiveSha256 = ('c' * 64)
  $executionReadback = [ordered]@{
    contract_version = 'github-actions-phase6-scale-execution-readback-v1'
    collected_at_utc = $collectedAt.ToString('o')
    repository = $githubRepository
    run = [ordered]@{
      id = $githubRunId
      run_attempt = $githubRunAttempt
      event = 'workflow_dispatch'
      status = 'completed'
      conclusion = 'success'
      head_branch = $githubRef.Substring('refs/heads/'.Length)
      head_sha = $repositoryHeadSha
      html_url = $githubRunUrl
      created_at = $runCreatedAt.ToString('o')
      updated_at = $runUpdatedAt.ToString('o')
    }
    artifact = [ordered]@{
      id = $githubArtifactId
      name = $githubArtifactName
      expired = $false
      digest = "sha256:$downloadedArchiveSha256"
      url = "https://api.github.com/repos/$githubRepository/actions/artifacts/$githubArtifactId"
      archive_download_url = "https://api.github.com/repos/$githubRepository/actions/artifacts/$githubArtifactId/zip"
      workflow_run = [ordered]@{ id = $githubRunId; head_sha = $repositoryHeadSha }
      created_at = $generatedAt.AddSeconds(10).ToString('o')
      updated_at = $generatedAt.AddSeconds(20).ToString('o')
    }
    downloaded_archive_sha256 = $downloadedArchiveSha256
    downloaded_evidence_sha256 = ''
    downloaded_sidecar_sha256 = ''
    sidecar_declared_evidence_sha256 = ''
    secret_output = $false
  }

  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedUntrustedFailure $evidencePath $criterionPath $hostedPath $capabilityPath
  $capabilityHashBefore = (Get-FileHash -LiteralPath $capabilityPath -Algorithm SHA256).Hash
  Invoke-ExpectedPass $evidencePath $criterionPath $hostedPath $capabilityPath
  $capabilityHashAfter = (Get-FileHash -LiteralPath $capabilityPath -Algorithm SHA256).Hash
  Assert-True ($capabilityHashBefore -eq $capabilityHashAfter) 'Read-only verification mutated capability state.'

  $validEvidence.source_binding.execution_attestation.run_attempt = 2
  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'GitHub rerun attempt'
  $validEvidence.source_binding.execution_attestation.run_attempt = 1

  $environmentReview.review_state = 'rejected'
  Write-Json $environmentReviewPath $environmentReview
  Write-Digest $environmentReviewPath
  $validEvidence.source_binding.execution_attestation.environment_review.review_state = 'rejected'
  $validEvidence.source_binding.execution_attestation.environment_review.review_artifact_sha256 = (Get-FileHash -LiteralPath $environmentReviewPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $validEvidence.source_binding.execution_attestation.environment_review.review_sidecar_sha256 = (Get-FileHash -LiteralPath "$environmentReviewPath.sha256" -Algorithm SHA256).Hash.ToLowerInvariant()
  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'rejected GitHub Environment review'
  $environmentReview.review_state = 'approved'
  Write-Json $environmentReviewPath $environmentReview
  Write-Digest $environmentReviewPath
  $validEvidence.source_binding.execution_attestation.environment_review.review_state = 'approved'
  $validEvidence.source_binding.execution_attestation.environment_review.review_artifact_sha256 = (Get-FileHash -LiteralPath $environmentReviewPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $validEvidence.source_binding.execution_attestation.environment_review.review_sidecar_sha256 = (Get-FileHash -LiteralPath "$environmentReviewPath.sha256" -Algorithm SHA256).Hash.ToLowerInvariant()

  $validEvidence.source_binding.execution_attestation.environment_review.review_artifact_sha256 = ('0' * 64)
  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'Environment-review artifact digest tamper'
  $validEvidence.source_binding.execution_attestation.environment_review.review_artifact_sha256 = (Get-FileHash -LiteralPath $environmentReviewPath -Algorithm SHA256).Hash.ToLowerInvariant()

  $hosted.hosted_write_read_delete_verified = $true
  Write-Json $script:deploymentPreflightPath $hosted
  $validEvidence.source_binding.deployment_preflight_state_file_sha256 = (Get-FileHash -LiteralPath $script:deploymentPreflightPath -Algorithm SHA256).Hash.ToLowerInvariant()
  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'false pre-run write/read/delete claim'
  $hosted.hosted_write_read_delete_verified = $false
  Write-Json $script:deploymentPreflightPath $hosted
  $validEvidence.source_binding.deployment_preflight_state_file_sha256 = (Get-FileHash -LiteralPath $script:deploymentPreflightPath -Algorithm SHA256).Hash.ToLowerInvariant()

  $longWindowPreviewAt = $hostedVerifiedAt.AddMinutes(-11)
  $deployment.preview_guard_verified_at_utc = $longWindowPreviewAt.ToString('o')
  Write-Json $deploymentPath $deployment
  Write-Digest $deploymentPath
  $hosted.preview_guard_verified_at_utc = $longWindowPreviewAt.ToString('o')
  $hosted.evidence_sha256 = (Get-FileHash -LiteralPath $deploymentPath -Algorithm SHA256).Hash.ToLowerInvariant()
  Write-Json $script:deploymentPreflightPath $hosted
  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'Preview-to-production deployment window over ten minutes'
  $deployment.preview_guard_verified_at_utc = $previewVerifiedAt.ToString('o')
  Write-Json $deploymentPath $deployment
  Write-Digest $deploymentPath
  $hosted.preview_guard_verified_at_utc = $previewVerifiedAt.ToString('o')
  $hosted.evidence_sha256 = (Get-FileHash -LiteralPath $deploymentPath -Algorithm SHA256).Hash.ToLowerInvariant()
  Write-Json $script:deploymentPreflightPath $hosted
  $validEvidence.source_binding.preview_guard_verified_at_utc = $previewVerifiedAt.ToString('o')
  $validEvidence.source_binding.deployment_evidence_sha256 = ([string]$hosted.evidence_sha256).ToLowerInvariant()
  $validEvidence.source_binding.deployment_preflight_state_file_sha256 = (Get-FileHash -LiteralPath $script:deploymentPreflightPath -Algorithm SHA256).Hash.ToLowerInvariant()

  # /cdn-cgi/trace is an attribution control, not a Worker pass criterion.
  # Preserve and recompute a failed control sample while the Worker evidence stays green.
  $validEvidence.read_tiers[0].edge_control_records[0].status_code = 503
  $validEvidence.read_tiers[0].edge_control_records[0].response_ok = $false
  $validEvidence.aggregate.edge_control_failure_count = 1
  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedPass $evidencePath $criterionPath $hostedPath $capabilityPath
  $validEvidence.read_tiers[0].edge_control_records[0].status_code = 200
  $validEvidence.read_tiers[0].edge_control_records[0].response_ok = $true
  $validEvidence.aggregate.edge_control_failure_count = 0

  [IO.File]::WriteAllText("$evidencePath.sha256", "$('0' * 64)  $([IO.Path]::GetFileName($evidencePath))`n", $utf8NoBom)
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'tampered companion digest'

  $validEvidence.read_tiers[0].valid_health_200 = 59
  $validEvidence.read_tiers[0].throttled_429 = 1
  $validEvidence.read_tiers[0].records[0].status_code = 429
  $validEvidence.read_tiers[0].records[0].health_contract_verified = $false
  $validEvidence.health_validation.valid_json_count = 799
  $validEvidence.aggregate.throttled_429_total = 1
  $validEvidence.aggregate.literal_success_count = 899
  $validEvidence.aggregate.success_ratio = 0.9989
  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedPass $evidencePath $criterionPath $hostedPath $capabilityPath
  $validEvidence.aggregate.success_ratio = 1.0
  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath '429 counted as literal HTTP success'
  $validEvidence.read_tiers[0].valid_health_200 = 60
  $validEvidence.read_tiers[0].throttled_429 = 0
  $validEvidence.read_tiers[0].records[0].status_code = 200
  $validEvidence.read_tiers[0].records[0].health_contract_verified = $true
  $validEvidence.health_validation.valid_json_count = 800
  $validEvidence.aggregate.throttled_429_total = 0
  $validEvidence.aggregate.literal_success_count = 900
  $validEvidence.aggregate.success_ratio = 1.0

  $validEvidence.read_tiers[0].valid_health_200 = 59.5
  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'fractional response count'
  $validEvidence.read_tiers[0].valid_health_200 = 60

  $validEvidence.read_tiers[0].throttled_429 = -1
  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'negative response count'
  $validEvidence.read_tiers[0].throttled_429 = 0

  $savedId = [string]$validEvidence.write_tier.records[0].id
  $validEvidence.write_tier.records[0].id = [string]$validEvidence.write_tier.records[1].id
  $validEvidence.write_tier.records[0].response_id = [string]$validEvidence.write_tier.records[0].id
  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'record ordinal ID substitution'
  $validEvidence.write_tier.records[0].id = $savedId
  $validEvidence.write_tier.records[0].response_id = $savedId

  $savedPromptHash = [string]$validEvidence.write_tier.records[0].prompt_sha256
  $validEvidence.write_tier.records[0].prompt_sha256 = ('a' * 64)
  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'deterministic prompt hash substitution'
  $validEvidence.write_tier.records[0].prompt_sha256 = $savedPromptHash

  $savedWriteP95 = [double]$validEvidence.write_tier.p95_ms
  $validEvidence.write_tier.p95_ms = 147.0
  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'unrecomputed write latency percentile'
  $validEvidence.write_tier.p95_ms = $savedWriteP95

  $savedAuditEventId = [string]$validEvidence.cleanup.records[0].audit_event_id
  $validEvidence.cleanup.records[0].audit_event_id = [string]$validEvidence.write_tier.records[0].audit_event_id
  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'duplicate create-delete audit event ID'
  $validEvidence.cleanup.records[0].audit_event_id = $savedAuditEventId

  $executionReadback.run.conclusion = 'failure'
  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'unsuccessful GitHub execution readback'
  $executionReadback.run.conclusion = 'success'

  $executionReadback.collected_at_utc = [DateTimeOffset]::UtcNow.AddHours(1).ToString('o')
  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'future GitHub execution readback'
  $executionReadback.collected_at_utc = $collectedAt.ToString('o')

  $executionReadback.collected_at_utc = $generatedAt.AddHours(25).ToString('o')
  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'GitHub execution readback after 24 hours'
  $executionReadback.collected_at_utc = $collectedAt.ToString('o')

  $validEvidence.result = 'verified'
  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'legacy pre-readback verified result'
  $validEvidence.result = 'provisional_pending_github_readback'

  $validEvidence.write_tier.record_loss_count = 1
  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'semantic record-loss tamper'
  $validEvidence.write_tier.record_loss_count = 0

  [void]$validEvidence.write_tier.records[0].Remove('audit_readback_verified')
  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'legacy self-attestation-only create record'
  $validEvidence.write_tier.records[0].audit_readback_verified = $true

  $savedRequestId = [string]$validEvidence.write_tier.records[0].request_id
  $validEvidence.write_tier.records[0].request_id = ''
  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'empty create request ID'
  $validEvidence.write_tier.records[0].request_id = $savedRequestId

  $validEvidence.cleanup.records[0].delete_readback_verified = $false
  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'missing delete readback proof'
  $validEvidence.cleanup.records[0].delete_readback_verified = $true

  $savedVerifierSha = [string]$validEvidence.source_binding.verifier_script_sha256
  $validEvidence.source_binding.verifier_script_sha256 = ('f' * 64)
  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'runtime verifier hash tamper'
  $validEvidence.source_binding.verifier_script_sha256 = $savedVerifierSha

  $validEvidence.Add('token_value', 'synthetic-forbidden-value')
  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'credential-field injection'
  $validEvidence.Remove('token_value')

  $validCapabilityJson = Get-Content -LiteralPath $capabilityPath -Raw
  $forgedCapability = $validCapabilityJson | ConvertFrom-Json -Depth 30
  $forgedCapability.gates.phase6_scale_runtime.owner_granted = $false
  $forgedCapability.gates.phase6_scale_runtime.owner_grant_ref = ''
  Write-Json $capabilityPath $forgedCapability
  $validEvidence.source_binding.capability_state_sha256 = (Get-FileHash -LiteralPath $capabilityPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $forgedGateIdentity = [ordered]@{ gate_id = 'phase6_scale_runtime'; owner_granted = $false; owner_grant_ref = ''; paid_provider = $false } | ConvertTo-Json -Compress
  $validEvidence.source_binding.gate_identity_sha256 = Get-StringSha256 $forgedGateIdentity
  $validEvidence.source_binding.owner_granted = $false
  $validEvidence.source_binding.owner_grant_ref = ''
  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'missing pre-run canonical Owner grant'
  [IO.File]::WriteAllText($capabilityPath, $validCapabilityJson, $utf8NoBom)
  $validEvidence.source_binding.capability_state_sha256 = $capabilityStateSha256
  $validEvidence.source_binding.gate_identity_sha256 = $gateIdentitySha256
  $validEvidence.source_binding.owner_granted = $true
  $validEvidence.source_binding.owner_grant_ref = $ownerGrantRef

  Write-EvidenceBundle $evidencePath $validEvidence $executionReadbackPath $executionReadback
  $capability = Get-Content -LiteralPath $capabilityPath -Raw | ConvertFrom-Json -Depth 30
  $capability.status = 'tampered'
  Write-Json $capabilityPath $capability
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'capability-state identity tamper'

  Write-Host '[phase6-scale-evidence-static] PASS: v2 parser, one-shot GitHub run, protected Environment human review, artifact/readback within 24 hours, ten-minute deployment window, literal-success/count/ordinal/hash/latency/audit/source tamper rejection, read-only proof, and rollback-safe promotion guards'
} finally {
  $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
  Assert-True ($resolvedTemp.StartsWith($testRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) 'Refusing unsafe temp cleanup.'
  if (Test-Path -LiteralPath $resolvedTemp) {
    Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
  }
}

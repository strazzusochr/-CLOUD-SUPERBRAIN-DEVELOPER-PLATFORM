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
  $capabilityPath = Join-Path $tempRoot 'capability-gates.json'
  # Forward slashes: pr-check runs this on ubuntu-latest, where a backslash is a literal
  # character and -LiteralPath would look for a file whose name contains it.
  Copy-Item -LiteralPath (Join-Path $repoRoot 'docs/runtime-state/phase6-scale-criterion.json') -Destination $criterionPath
  Copy-Item -LiteralPath (Join-Path $repoRoot 'docs/runtime-state/cloudflare-native-hosted-current.json') -Destination $hostedPath
  Copy-Item -LiteralPath (Join-Path $repoRoot 'docs/runtime-state/capability-gates.json') -Destination $capabilityPath
  $criterion = Get-Content -LiteralPath $criterionPath -Raw | ConvertFrom-Json -Depth 30
  $hosted = Get-Content -LiteralPath $hostedPath -Raw | ConvertFrom-Json -Depth 30
  $repositoryHeadSha = (& git -C $repoRoot rev-parse HEAD).Trim()
  $deployedSourceSha = (& git -C $repoRoot rev-parse HEAD^).Trim()
  $sourceArchiveSha256 = Get-GitArchiveSha256 $deployedSourceSha
  $generatedAt = (Get-Date).ToUniversalTime().AddMinutes(-2)
  $hostedVerifiedAt = $generatedAt.AddMinutes(-5)
  $runCreatedAt = $generatedAt.AddMinutes(-1)
  $runUpdatedAt = $generatedAt.AddMinutes(1)
  $collectedAt = $generatedAt.AddMinutes(2)
  $githubRepository = 'strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM'
  [long]$githubRunId = 1234567890
  [int]$githubRunAttempt = 1
  $githubRunUrl = "https://github.com/$githubRepository/actions/runs/$githubRunId"
  $githubRef = 'refs/heads/codex/phase6-scale-static-fixture'
  $githubArtifactName = "phase6-scale-execution-evidence-$githubRunId-$githubRunAttempt"
  $hosted.source_commit_sha = $deployedSourceSha
  $hosted.source_archive_sha256 = $sourceArchiveSha256
  $hosted.verified_at_utc = $hostedVerifiedAt.ToString('o')
  $workerVersionId = '11111111-1111-4111-8111-111111111111'
  $deploymentId = '22222222-2222-4222-8222-222222222222'
  $deploymentPath = Join-Path $tempRoot 'cloudflare-deployment-v2.json'
  $deployment = [ordered]@{
    contract_version = 'cloudflare-d1-stateful-runtime-hosted-proof-v2'
    verified_at_utc = $hostedVerifiedAt.ToString('o')
    base_url = [string]$hosted.base_url
    source_commit_sha = [string]$hosted.source_commit_sha
    source_archive_sha256 = [string]$hosted.source_archive_sha256
    worker_version_id = $workerVersionId
    deployment_id = $deploymentId
    source_binding_verified = $true
    hosted_write_read_delete_verified = $true
    dev_only = $false
    secret_output = $false
  }
  Write-Json $deploymentPath $deployment
  $hosted.evidence_artifact = $deploymentPath
  $hosted.evidence_sha256 = (Get-FileHash -LiteralPath $deploymentPath -Algorithm SHA256).Hash.ToLowerInvariant()
  Write-Json $hostedPath $hosted
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
      hosted_state_contract_version = [string]$hosted.contract_version
      hosted_state_file_sha256 = (Get-FileHash -LiteralPath $hostedPath -Algorithm SHA256).Hash.ToLowerInvariant()
      base_url = [string]$hosted.base_url
      source_commit_sha = [string]$hosted.source_commit_sha
      source_archive_sha256 = [string]$hosted.source_archive_sha256
      deployment_evidence_artifact = [string]$hosted.evidence_artifact
      deployment_evidence_sha256 = ([string]$hosted.evidence_sha256).ToLowerInvariant()
      worker_version_id = $workerVersionId
      deployment_id = $deploymentId
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

  Write-Host '[phase6-scale-evidence-static] PASS: v2 parser, GitHub execution readback, literal-success/count/ordinal/hash/latency/audit/source tamper rejection, read-only proof, and rollback-safe promotion guards'
} finally {
  $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
  Assert-True ($resolvedTemp.StartsWith($testRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) 'Refusing unsafe temp cleanup.'
  if (Test-Path -LiteralPath $resolvedTemp) {
    Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
  }
}

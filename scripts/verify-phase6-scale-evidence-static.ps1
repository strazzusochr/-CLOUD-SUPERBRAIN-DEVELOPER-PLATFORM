#Requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\', '/')
$verifierPath = Join-Path $PSScriptRoot 'verify-phase6-scale-evidence.ps1'
$testRoot = [IO.Path]::GetFullPath('D:\_sb_tmp').TrimEnd('\', '/')
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

function Invoke-ExpectedPass([string]$Evidence, [string]$Criterion, [string]$Hosted, [string]$Capability) {
  $output = @(& pwsh -NoProfile -File $verifierPath `
    -EvidencePath $Evidence `
    -CriterionPath $Criterion `
    -HostedStatePath $Hosted `
    -CapabilityStatePath $Capability `
    -AllowTestPaths 2>&1)
  Assert-True ($LASTEXITCODE -eq 0) ("Expected verifier pass, received: " + ($output -join ' | '))
  Assert-True (($output -join "`n") -match 'promotion=false read_only=true') 'Read-only verifier did not report promotion=false.'
}

function Invoke-ExpectedFailure([string]$Evidence, [string]$Criterion, [string]$Hosted, [string]$Capability, [string]$Label) {
  $output = @(& pwsh -NoProfile -File $verifierPath `
    -EvidencePath $Evidence `
    -CriterionPath $Criterion `
    -HostedStatePath $Hosted `
    -CapabilityStatePath $Capability `
    -AllowTestPaths 2>&1)
  Assert-True ($LASTEXITCODE -ne 0) "$Label unexpectedly passed."
}

$tokens = $null
$parseErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile($verifierPath, [ref]$tokens, [ref]$parseErrors)
Assert-True (@($parseErrors).Count -eq 0) 'Evidence verifier has PowerShell parse errors.'
$source = Get-Content -LiteralPath $verifierPath -Raw
foreach ($required in @(
  "if (-not `$Promote)",
  'Assert-True (-not $AllowTestPaths)',
  'ExpectedCapabilityStateSha256',
  'ExpectedGateIdentitySha256',
  "Assert-Boolean `$gate 'owner_granted' `$true",
  'Assert-TrackedCleanAgainstHead',
  '[IO.File]::Replace',
  "`$candidateGate.live_verified = `$true",
  "`$candidateGate.paid_provider = `$false"
)) {
  Assert-True ($source.Contains($required)) "Missing promotion safety contract: $required"
}
Assert-True ($source -notmatch '(?i)Invoke-WebRequest|Invoke-RestMethod|HttpClient|curl\.exe') 'Offline evidence verifier contains a live HTTP client.'
Assert-True (-not $source.Contains('$candidateGate.owner_granted =')) 'Promoter must not synthesize owner_granted.'
Assert-True (-not $source.Contains('$candidateGate.owner_grant_ref =')) 'Promoter must not synthesize owner_grant_ref.'

New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
try {
  $criterionPath = Join-Path $tempRoot 'phase6-scale-criterion.json'
  $hostedPath = Join-Path $tempRoot 'cloudflare-native-hosted-current.json'
  $capabilityPath = Join-Path $tempRoot 'capability-gates.json'
  Copy-Item -LiteralPath (Join-Path $repoRoot 'docs\runtime-state\phase6-scale-criterion.json') -Destination $criterionPath
  Copy-Item -LiteralPath (Join-Path $repoRoot 'docs\runtime-state\cloudflare-native-hosted-current.json') -Destination $hostedPath
  Copy-Item -LiteralPath (Join-Path $repoRoot 'docs\runtime-state\capability-gates.json') -Destination $capabilityPath
  $criterion = Get-Content -LiteralPath $criterionPath -Raw | ConvertFrom-Json -Depth 30
  $hosted = Get-Content -LiteralPath $hostedPath -Raw | ConvertFrom-Json -Depth 30
  $workerVersionId = '11111111-1111-4111-8111-111111111111'
  $deploymentId = '22222222-2222-4222-8222-222222222222'
  $deploymentPath = Join-Path $tempRoot 'cloudflare-deployment-v2.json'
  $deployment = [ordered]@{
    contract_version = 'cloudflare-d1-stateful-runtime-hosted-proof-v2'
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
  $repositoryHeadSha = (& git.exe -C $repoRoot rev-parse HEAD).Trim()

  $generatedAt = (Get-Date).ToUniversalTime()
  $stamp = $generatedAt.ToString('yyyyMMddTHHmmssfffZ')
  $runId = [Guid]::NewGuid().ToString('N')
  $evidencePath = Join-Path $tempRoot "scale-evidence-$stamp-$runId.json"
  $writeRecords = @()
  $cleanupRecords = @()
  for ($index = 1; $index -le 50; $index++) {
    $id = "p6s$($runId.Substring(0, 24))$($index.ToString('00'))"
    $writeRecords += [ordered]@{
      id = $id
      response_id = $id
      request_id = "phase6-scale-$runId-$index-create"
      audit_event_id = [Guid]::NewGuid().ToString()
      status_code = 201
      latency_ms = [double](100 + $index)
      response_readback_verified = $true
      audit_readback_verified = $true
      prompt_sha256 = ('a' * 64)
      html_sha256 = ('b' * 64)
      audit_persisted_verified = $true
      validation_errors = @()
    }
    $cleanupRecords += [ordered]@{
      id = $id
      request_id = "phase6-scale-$runId-$index-delete"
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
    'The authorization token is neither printed nor persisted.',
    'Control requests use the Cloudflare edge path and are not Worker requests.'
  )
  $validEvidence = [ordered]@{
    contract_version = 'phase6-scale-evidence-v2'
    generated_at_utc = $generatedAt.ToString('o')
    run_id = $runId
    result = 'verified'
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
    read_tiers = @(
      [ordered]@{ concurrency = 1; requests = 60; valid_health_200 = 60; invalid_health_200 = 0; throttled_429 = 0; server_5xx = 0; transport_fail = 0; other_status = 0; p50_ms = 50.0; p95_ms = 100.0; p99_ms = 110.0; edge_control_p95_ms = 20.0; worker_share_p95_ms = 80.0 },
      [ordered]@{ concurrency = 10; requests = 240; valid_health_200 = 240; invalid_health_200 = 0; throttled_429 = 0; server_5xx = 0; transport_fail = 0; other_status = 0; p50_ms = 75.0; p95_ms = 200.0; p99_ms = 220.0; edge_control_p95_ms = 30.0; worker_share_p95_ms = 170.0 },
      [ordered]@{ concurrency = 50; requests = 500; valid_health_200 = 500; invalid_health_200 = 0; throttled_429 = 0; server_5xx = 0; transport_fail = 0; other_status = 0; p50_ms = 100.0; p95_ms = 300.0; p99_ms = 330.0; edge_control_p95_ms = 40.0; worker_share_p95_ms = 260.0 }
    )
    health_validation = [ordered]@{ valid_json_count = 800; invalid_json_or_contract_count = 0; validation_failures = @() }
    write_tier = [ordered]@{
      concurrency = 10
      records_planned = 50
      valid_post_insert_readbacks = 50
      record_loss_count = 0
      duplicate_count = 0
      field_failure_count = 0
      hash_failure_count = 0
      audit_failure_count = 0
      throttled_429 = 0
      server_5xx = 0
      transport_fail = 0
      p50_ms = 300.0
      p95_ms = 400.0
      p99_ms = 450.0
      records = $writeRecords
    }
    cleanup = [ordered]@{
      verified_count = 50
      required_count = 50
      complete = $true
      throttled_429 = 0
      unclean_throttle_count = 0
      server_5xx = 0
      transport_fail = 0
      p95_ms = 500.0
      records = $cleanupRecords
    }
    aggregate = [ordered]@{
      success_ratio = 1.0
      worst_p95_ms = 500.0
      throttled_429_total = 0
      server_5xx_total = 0
      transport_fail_total = 0
      failures = @()
      criterion_met = $true
    }
    auth = [ordered]@{ environment_variable_name = 'AGENT_API_AUTH_TOKEN'; value_recorded = $false }
    gate_may_open = $false
    gate_promotion_performed = $false
    percentage_credit_awarded = 0
    non_claims = $expectedNonClaims
  }

  Write-Json $evidencePath $validEvidence
  Write-Digest $evidencePath
  $capabilityHashBefore = (Get-FileHash -LiteralPath $capabilityPath -Algorithm SHA256).Hash
  Invoke-ExpectedPass $evidencePath $criterionPath $hostedPath $capabilityPath
  $capabilityHashAfter = (Get-FileHash -LiteralPath $capabilityPath -Algorithm SHA256).Hash
  Assert-True ($capabilityHashBefore -eq $capabilityHashAfter) 'Read-only verification mutated capability state.'

  [IO.File]::WriteAllText("$evidencePath.sha256", "$('0' * 64)  $([IO.Path]::GetFileName($evidencePath))`n", $utf8NoBom)
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'tampered companion digest'

  $validEvidence.write_tier.record_loss_count = 1
  Write-Json $evidencePath $validEvidence
  Write-Digest $evidencePath
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'semantic record-loss tamper'
  $validEvidence.write_tier.record_loss_count = 0

  [void]$validEvidence.write_tier.records[0].Remove('audit_readback_verified')
  Write-Json $evidencePath $validEvidence
  Write-Digest $evidencePath
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'legacy self-attestation-only create record'
  $validEvidence.write_tier.records[0].audit_readback_verified = $true

  $savedRequestId = [string]$validEvidence.write_tier.records[0].request_id
  $validEvidence.write_tier.records[0].request_id = ''
  Write-Json $evidencePath $validEvidence
  Write-Digest $evidencePath
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'empty create request ID'
  $validEvidence.write_tier.records[0].request_id = $savedRequestId

  $validEvidence.cleanup.records[0].delete_readback_verified = $false
  Write-Json $evidencePath $validEvidence
  Write-Digest $evidencePath
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'missing delete readback proof'
  $validEvidence.cleanup.records[0].delete_readback_verified = $true

  $savedVerifierSha = [string]$validEvidence.source_binding.verifier_script_sha256
  $validEvidence.source_binding.verifier_script_sha256 = ('f' * 64)
  Write-Json $evidencePath $validEvidence
  Write-Digest $evidencePath
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'runtime verifier hash tamper'
  $validEvidence.source_binding.verifier_script_sha256 = $savedVerifierSha

  $validEvidence.Add('token_value', 'synthetic-forbidden-value')
  Write-Json $evidencePath $validEvidence
  Write-Digest $evidencePath
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
  Write-Json $evidencePath $validEvidence
  Write-Digest $evidencePath
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'missing pre-run canonical Owner grant'
  [IO.File]::WriteAllText($capabilityPath, $validCapabilityJson, $utf8NoBom)
  $validEvidence.source_binding.capability_state_sha256 = $capabilityStateSha256
  $validEvidence.source_binding.gate_identity_sha256 = $gateIdentitySha256
  $validEvidence.source_binding.owner_granted = $true
  $validEvidence.source_binding.owner_grant_ref = $ownerGrantRef

  Write-Json $evidencePath $validEvidence
  Write-Digest $evidencePath
  $capability = Get-Content -LiteralPath $capabilityPath -Raw | ConvertFrom-Json -Depth 30
  $capability.status = 'tampered'
  Write-Json $capabilityPath $capability
  Invoke-ExpectedFailure $evidencePath $criterionPath $hostedPath $capabilityPath 'capability-state identity tamper'

  Write-Host '[phase6-scale-evidence-static] PASS: v2 parser/read-only proof, digest/loss/legacy/request/audit/delete/source/Owner/capability tamper rejection, no-HTTP, and promotion guards'
} finally {
  $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
  Assert-True ($resolvedTemp.StartsWith($testRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) 'Refusing unsafe temp cleanup.'
  if (Test-Path -LiteralPath $resolvedTemp) {
    Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
  }
}

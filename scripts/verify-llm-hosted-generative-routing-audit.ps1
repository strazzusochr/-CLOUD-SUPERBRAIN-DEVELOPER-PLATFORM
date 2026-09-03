param(
  [string]$BaseUrl = "https://cloud-superbrain-llm-gateway-preview.strazzusochr.workers.dev",
  [string]$ExpectedSourceCommitSha = "",
  [string]$ExpectedSourceArchiveSha256 = "",
  [string]$RubricApprovalCommit = "",
  [switch]$OwnerApprovedGatewayCredentialUse,
  [switch]$OwnerApprovedLiveProviderCalls,
  [switch]$OwnerApprovedHostedAuditWrites,
  [string]$Model = "@cf/meta/llama-3.1-8b-instruct-fast",
  [string]$OutDir = ".phase1-artifacts/llm-gateway/hosted-current-evidence-chain"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$script:Prefix = "[llm-hosted-current-chain]"
$script:SanctionedBaseUrl = "https://cloud-superbrain-llm-gateway-preview.strazzusochr.workers.dev"
$script:GatewayTokenEnvName = "CLOUD_SUPERBRAIN_LLM_GATEWAY_TOKEN"
$script:VerifierPath = "scripts/verify-live-llm-evidence-chain.ps1"
$script:ImplementationPath = "scripts/verify-llm-hosted-generative-routing-audit.ps1"
$script:RuntimePath = "services/cloudflare-llm-gateway/src/index.js"
$script:WranglerPath = "services/cloudflare-llm-gateway/wrangler.jsonc"
$script:GatewayTreePath = "services/cloudflare-llm-gateway"
$script:RubricPath = "docs/runtime-contracts/layer-credit-rubric.md"
$script:CapabilityPath = "docs/runtime-state/capability-gates.json"
$script:ApprovedModels = @(
  "@cf/qwen/qwen2.5-coder-32b-instruct",
  "@cf/meta/llama-3.1-8b-instruct-fast"
)

function Stop-Blocked([string]$Code, [string]$Detail) {
  throw "blocker=$Code detail=$Detail"
}

function Require([bool]$Condition, [string]$Code, [string]$Detail) {
  if (-not $Condition) { Stop-Blocked $Code $Detail }
}

function Get-TextSha256([string]$Value) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return (($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value)) | ForEach-Object { $_.ToString("x2") }) -join "")
  } finally {
    $sha.Dispose()
  }
}

function Get-HeaderValue($Response, [string]$Name) {
  $value = $Response.Headers[$Name]
  if ($null -eq $value) { return "" }
  if ($value -is [array]) { return [string]$value[0] }
  return [string]$value
}

function Read-JsonResponse($Response, [string]$Label) {
  try {
    return ([string]$Response.Content | ConvertFrom-Json -ErrorAction Stop)
  } catch {
    Stop-Blocked "${Label}_invalid_json" "Hosted response was not valid JSON."
  }
}

function Invoke-CapturedRequest(
  [string]$Uri,
  [string]$Method = "GET",
  [hashtable]$Headers = @{},
  [string]$Body = ""
) {
  $parameters = @{
    Uri = $Uri
    Method = $Method
    Headers = $Headers
    TimeoutSec = 120
    UseBasicParsing = $true
    SkipHttpErrorCheck = $true
    MaximumRedirection = 0
  }
  if ($Method -ne "GET") {
    $parameters.ContentType = "application/json"
    $parameters.Body = $Body
  }
  try {
    $response = Invoke-WebRequest @parameters
  } catch {
    Stop-Blocked "hosted_transport_failed" "The sanctioned Preview request did not complete without redirect."
  }
  Require (
    [int]$response.StatusCode -lt 300 -or [int]$response.StatusCode -ge 400
  ) "hosted_redirect_forbidden" "Redirect responses are forbidden for credential-bearing hosted verification."
  return $response
}

function Invoke-Git([string[]]$Arguments, [string]$Blocker) {
  $output = & git @Arguments 2>$null
  if ($LASTEXITCODE -ne 0) {
    Stop-Blocked $Blocker "Git could not validate the immutable candidate binding."
  }
  return (($output | Out-String).Trim())
}

function Get-GitArchiveSha256([string]$CommitSha) {
  $start = [Diagnostics.ProcessStartInfo]::new()
  $start.FileName = "git"
  $start.WorkingDirectory = (Get-Location).Path
  $start.UseShellExecute = $false
  $start.CreateNoWindow = $true
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  [void]$start.ArgumentList.Add("archive")
  [void]$start.ArgumentList.Add("--format=tar")
  [void]$start.ArgumentList.Add($CommitSha)
  $process = [Diagnostics.Process]::Start($start)
  $stderrTask = $process.StandardError.ReadToEndAsync()
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $digest = $sha.ComputeHash($process.StandardOutput.BaseStream)
  } finally {
    $sha.Dispose()
  }
  $process.WaitForExit()
  $null = $stderrTask.GetAwaiter().GetResult()
  Require ($process.ExitCode -eq 0) "source_archive_reconstruction_failed" "git archive could not reconstruct the candidate source."
  return (($digest | ForEach-Object { $_.ToString("x2") }) -join "")
}

function Assert-BooleanField($Payload, [string]$Field, [bool]$Expected, [string]$Code) {
  $property = $Payload.PSObject.Properties[$Field]
  Require (
    $null -ne $property -and $property.Value -is [bool] -and [bool]$property.Value -eq $Expected
  ) $Code "$Field must be the JSON boolean $($Expected.ToString().ToLowerInvariant())."
}

function Assert-SanctionedTarget([string]$Value) {
  Require (
    $Value -ceq $script:SanctionedBaseUrl
  ) "unsanctioned_preview_host" "BaseUrl must exactly equal the sanctioned Preview Worker origin; alternate hosts, paths, ports, queries, fragments, and userinfo are forbidden."
}

function Assert-CandidateClosure {
  Require ($ExpectedSourceCommitSha -match "^[0-9a-f]{40}$") "expected_source_commit_sha_required" "Pass the exact lowercase candidate commit SHA."
  Require ($ExpectedSourceArchiveSha256 -match "^[0-9a-f]{64}$") "expected_source_archive_sha256_required" "Pass the exact lowercase candidate archive SHA-256."
  Require (
    (Invoke-Git @("rev-parse", "HEAD") "head_unavailable") -ceq $ExpectedSourceCommitSha
  ) "candidate_head_mismatch" "HEAD must equal the exact hosted candidate commit before any HTTP request."

  $boundPaths = @(
    $script:VerifierPath,
    $script:ImplementationPath,
    $script:RuntimePath,
    $script:WranglerPath,
    $script:RubricPath,
    $script:CapabilityPath
  )
  $blobs = [ordered]@{}
  foreach ($path in $boundPaths) {
    [void](Invoke-Git @("show", "$ExpectedSourceCommitSha`:$path") "candidate_blob_missing")
    $candidateBlob = Invoke-Git @("rev-parse", "$ExpectedSourceCommitSha`:$path") "candidate_blob_missing"
    $worktreeBlob = Invoke-Git @("hash-object", "--", $path) "worktree_blob_missing"
    Require ($candidateBlob -ceq $worktreeBlob) "candidate_blob_drift" "Bound path differs from its candidate blob: $path"
    $blobs[$path] = $candidateBlob
  }
  $drift = Invoke-Git @(
    "status", "--porcelain=v1", "--untracked-files=all", "--",
    $script:VerifierPath, $script:ImplementationPath, $script:GatewayTreePath,
    $script:RubricPath, $script:CapabilityPath
  ) "candidate_status_failed"
  Require ([string]::IsNullOrWhiteSpace($drift)) "candidate_worktree_drift" "Staged, unstaged, or untracked drift exists in a bound candidate path."
  Require (
    (Get-GitArchiveSha256 $ExpectedSourceCommitSha) -ceq $ExpectedSourceArchiveSha256
  ) "source_archive_sha_mismatch" "ExpectedSourceArchiveSha256 is not reproducible from git archive of the candidate commit."

  return [ordered]@{
    verifier_blob = $blobs[$script:VerifierPath]
    implementation_blob = $blobs[$script:ImplementationPath]
    runtime_blob = $blobs[$script:RuntimePath]
    wrangler_blob = $blobs[$script:WranglerPath]
    rubric_blob = $blobs[$script:RubricPath]
    capability_blob = $blobs[$script:CapabilityPath]
    gateway_tree = Invoke-Git @("rev-parse", "$ExpectedSourceCommitSha`:$script:GatewayTreePath") "candidate_gateway_tree_missing"
  }
}

function Assert-ApprovedRubric {
  Require ($RubricApprovalCommit -match "^[0-9a-f]{40}$") "rubric_approval_commit_required" "Pass the lowercase SHA of the Owner-approved rubric commit."
  & git merge-base --is-ancestor $RubricApprovalCommit $ExpectedSourceCommitSha 2>$null
  Require ($LASTEXITCODE -eq 0) "rubric_commit_not_in_candidate" "The rubric approval commit is not an ancestor of the candidate."
  $approved = Invoke-Git @("show", "$RubricApprovalCommit`:$script:RubricPath") "rubric_approval_commit_invalid"
  $candidate = Invoke-Git @("show", "$ExpectedSourceCommitSha`:$script:RubricPath") "candidate_rubric_missing"
  foreach ($content in @($approved, $candidate)) {
    Require ($content -match "(?im)^Status:\s*`?(?:OWNER_)?APPROVED`?\s*$") "rubric_not_owner_approved" "The immutable rubric is not marked APPROVED."
    Require ($content -match "(?im)^Credit-Anwendung erlaubt:\s*`?true`?\s*$") "rubric_credit_disabled" "The immutable rubric does not allow credit application."
  }
  Require (
    (Invoke-Git @("rev-parse", "$RubricApprovalCommit`:$script:RubricPath") "rubric_blob_missing") -ceq
    (Invoke-Git @("rev-parse", "$ExpectedSourceCommitSha`:$script:RubricPath") "candidate_rubric_missing")
  ) "rubric_blob_drift" "Candidate rubric differs from the approved blob."
  Require ($candidate -match "(?im)^Owner-Freigabe-Ref:\s*`?[^`\r\n]{8,200}`?\s*$") "rubric_owner_grant_ref_missing" "The approved rubric has no tracked Owner-Freigabe-Ref."
  Require ($candidate -match "(?im)^\|\s*Aktueller Hosted-Gateway ist source-gebunden generativ erreichbar\s*\|\s*10\s*\|\s*Hosted\s*\|") "rubric_generative_criterion_drift" "The approved rubric lacks the exact 10-point hosted-generation row."
  Require ($candidate -match "(?im)^\|\s*Hosted Routing haelt die freigegebene Provider-Allowlist ein\s*\|\s*4\s*\|.*verify-live-llm-evidence-chain\.ps1") "rubric_routing_criterion_drift" "The approved rubric lacks the exact 4-point hosted-routing row."
  Require ($candidate -match "(?im)^\|\s*Hosted Completion-Audit ist persistent und source-gebunden\s*\|\s*4\s*\|.*verify-live-llm-evidence-chain\.ps1") "rubric_audit_criterion_drift" "The approved rubric lacks the exact 4-point hosted-audit row."
}

function Assert-LiveProviderGate {
  try {
    $state = (Invoke-Git @("show", "$ExpectedSourceCommitSha`:$script:CapabilityPath") "candidate_capability_gate_missing") | ConvertFrom-Json -ErrorAction Stop
  } catch {
    Stop-Blocked "capability_gate_invalid_json" "The candidate capability gate is invalid JSON."
  }
  Require ([string]$state.contract_version -eq "capability-gate-state-v1") "capability_gate_contract_mismatch" "Unexpected capability gate contract."
  $gate = $state.gates.live_llm_provider_calls
  Require ($null -ne $gate -and $gate.owner_granted -eq $true -and $gate.live_verified -eq $true) "live_llm_provider_gate_closed" "The tracked live LLM Owner/live gate is not verified."
  Require ($gate.paid_provider -eq $false -and [string]$gate.provider -eq "cloudflare_workers_ai") "live_llm_provider_gate_provider" "The tracked gate does not prove the free Workers AI path."
  Require ([string]$gate.verifier -eq "scripts/verify-live-llm-free-provider.ps1") "live_llm_provider_gate_verifier" "Unexpected tracked gate verifier."
  $grantRef = [string]$gate.owner_grant_ref
  Require (-not [string]::IsNullOrWhiteSpace($grantRef)) "live_llm_owner_grant_ref_missing" "Tracked gate has no Owner grant reference."
  $grantPath = ($grantRef -split "\s+::\s+", 2)[0]
  Require ($grantPath -match "^[A-Za-z0-9_./-]+\.md$") "live_llm_owner_grant_ref_invalid" "Grant reference is not a tracked Markdown path."
  [void](Invoke-Git @("show", "$ExpectedSourceCommitSha`:$grantPath") "live_llm_owner_grant_ref_untracked")
  $evidencePath = [string]$gate.evidence_artifact
  Require ($evidencePath -match "^[A-Za-z0-9_./-]+\.json$") "live_llm_gate_evidence_ref_invalid" "Gate evidence reference is invalid."
  [void](Invoke-Git @("show", "$ExpectedSourceCommitSha`:$evidencePath") "live_llm_gate_evidence_untracked")
  return [ordered]@{
    owner_grant_ref_sha256 = Get-TextSha256 $grantRef
    gate_evidence_path = $evidencePath
    gate_evidence_blob = Invoke-Git @("rev-parse", "$ExpectedSourceCommitSha`:$evidencePath") "live_llm_gate_evidence_untracked"
  }
}

function Assert-SourceBinding($Health) {
  Require ([string]$Health.source_commit_sha -ceq $ExpectedSourceCommitSha) "hosted_source_commit_mismatch" "Health commit mismatch."
  Require ([string]$Health.source_archive_sha256 -ceq $ExpectedSourceArchiveSha256) "hosted_source_archive_mismatch" "Health archive mismatch."
  Assert-BooleanField $Health "source_binding_configured" $true "hosted_source_binding_unconfigured"
}

function Get-RequiredToken {
  Require $OwnerApprovedGatewayCredentialUse.IsPresent "gateway_credential_confirmation_required" "Credential switch is extra confirmation only."
  Require $OwnerApprovedLiveProviderCalls.IsPresent "live_provider_call_confirmation_required" "Live-provider switch is extra confirmation only."
  Require $OwnerApprovedHostedAuditWrites.IsPresent "hosted_audit_write_confirmation_required" "D1 audit-write switch is extra confirmation only."
  $token = [Environment]::GetEnvironmentVariable($script:GatewayTokenEnvName, "Process")
  Require (-not [string]::IsNullOrWhiteSpace($token) -and $token.Length -ge 16) "gateway_token_missing" "The fixed approved gateway token is absent."
  return $token
}

function Get-TraceId($Response) {
  $traceparent = Get-HeaderValue $Response "traceparent"
  Require ($traceparent -match "^00-([0-9a-f]{32})-[0-9a-f]{16}-0[01]$") "response_traceparent_invalid" "Hosted response lacks a valid W3C traceparent."
  return $Matches[1]
}

function Get-IndependentEvidence([string]$Base, [string]$Token, [string]$RequestId, [string]$TraceId) {
  $uri = "$Base/api/v1/evidence?request_id=$([Uri]::EscapeDataString($RequestId))&trace_id=$TraceId"
  $response = Invoke-CapturedRequest $uri "GET" @{ "x-superbrain-gateway-token" = $Token }
  Require ([int]$response.StatusCode -eq 200) "independent_evidence_http_status" "Independent readback did not return 200."
  $proof = Read-JsonResponse $response "independent_evidence"
  Require ([string]$proof.contract_version -eq "llm-gateway-independent-evidence-v1" -and [string]$proof.status -eq "verified") "independent_evidence_contract" "Independent evidence is not verified."
  Require ([string]$proof.request_id -eq $RequestId -and [string]$proof.trace_id -eq $TraceId) "independent_evidence_correlation" "Independent evidence correlation mismatch."
  Require ([string]$proof.source_commit_sha -ceq $ExpectedSourceCommitSha -and [string]$proof.source_archive_sha256 -ceq $ExpectedSourceArchiveSha256) "independent_evidence_source_mismatch" "Independent evidence source mismatch."
  Assert-BooleanField $proof "audit_readback_verified" $true "independent_audit_readback_unverified"
  Assert-BooleanField $proof "direct_provider_calls" $false "independent_direct_provider_call_detected"
  Assert-BooleanField $proof "secret_output" $false "independent_secret_output_unproven"
  return $proof
}

function Write-ImmutableEvidence([hashtable]$Report) {
  $runId = "{0}-{1}-{2}" -f (
    [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ"),
    $ExpectedSourceCommitSha.Substring(0, 12),
    [Guid]::NewGuid().ToString("N").Substring(0, 8)
  )
  $runDir = Join-Path $OutDir $runId
  [void](New-Item -ItemType Directory -Path $runDir -Force:$false)
  $reportPath = Join-Path $runDir "report.json"
  $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($Report | ConvertTo-Json -Depth 24) + "`n")
  $stream = [IO.File]::Open($reportPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
  try {
    $stream.Write($bytes, 0, $bytes.Length)
  } finally {
    $stream.Dispose()
  }
  $digest = (Get-FileHash -LiteralPath $reportPath -Algorithm SHA256).Hash.ToLowerInvariant()
  [IO.File]::WriteAllText((Join-Path $runDir "report.sha256"), "$digest  report.json`n", [Text.UTF8Encoding]::new($false))
  return [ordered]@{ report_path = $reportPath; evidence_sha256 = $digest }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
  Require ($PSVersionTable.PSVersion.Major -ge 7) "powershell_7_required" "PowerShell 7 or newer is required."
  Assert-SanctionedTarget $BaseUrl
  $closure = Assert-CandidateClosure
  Assert-ApprovedRubric
  $gateBinding = Assert-LiveProviderGate
  $base = $script:SanctionedBaseUrl

  $healthResponse = Invoke-CapturedRequest "$base/api/v1/health"
  Require ([int]$healthResponse.StatusCode -eq 200) "health_http_status" "Health must return 200."
  $health = Read-JsonResponse $healthResponse "health"
  Require ([string]$health.status -eq "healthy") "health_not_healthy" "Gateway is not healthy."
  Assert-SourceBinding $health
  Assert-BooleanField $health "live_provider_calls_available" $true "hosted_live_provider_unavailable"
  Assert-BooleanField $health "direct_provider_calls" $false "hosted_direct_provider_overclaim"
  Assert-BooleanField $health "secret_output" $false "hosted_health_secret_output"

  $modelsResponse = Invoke-CapturedRequest "$base/v1/models"
  Require ([int]$modelsResponse.StatusCode -eq 200) "models_http_status" "Models endpoint must return 200."
  $models = Read-JsonResponse $modelsResponse "models"
  Require ([string]$models.object -eq "list") "models_contract_mismatch" "Models response is not an OpenAI-compatible list."
  Assert-BooleanField $models "live_provider_calls" $false "models_unexpected_provider_call"
  Assert-BooleanField $models "direct_provider_calls" $false "models_direct_provider_overclaim"
  Assert-BooleanField $models "secret_output" $false "models_secret_output"
  $modelEntries = @($models.data)
  $modelIds = @($modelEntries | ForEach-Object { [string]$_.id })
  Require ($modelIds.Count -eq $script:ApprovedModels.Count) "hosted_allowlist_count_mismatch" "Hosted model allowlist count differs from the approved verifier allowlist."
  Require (($modelIds | Select-Object -Unique).Count -eq $modelIds.Count) "hosted_allowlist_duplicate" "Hosted model allowlist contains duplicates."
  foreach ($approvedModel in $script:ApprovedModels) {
    Require ($modelIds -ccontains $approvedModel) "hosted_allowlist_model_missing" "Hosted model allowlist is missing an approved model."
  }
  foreach ($entry in $modelEntries) {
    Require ($script:ApprovedModels -ccontains [string]$entry.id) "hosted_allowlist_unapproved_model" "Hosted model allowlist contains an unapproved model."
    Require ([string]$entry.object -eq "model" -and [string]$entry.owned_by -eq "cloudflare") "hosted_allowlist_owner_mismatch" "Hosted model entry is not Cloudflare-owned model metadata."
  }
  Require ($modelIds -ccontains $Model) "requested_model_not_allowlisted" "The requested model is not in the exact hosted allowlist."
  $allowedModelsSha256 = Get-TextSha256 ((@($modelIds | Sort-Object) -join "`n"))

  $token = (Get-RequiredToken)
  $requestId = "l4-current-" + [Guid]::NewGuid().ToString("N")
  $body = [ordered]@{
    model = $Model
    messages = @(@{ role = "user"; content = "Return one short sentence confirming the bounded hosted generation path." })
    max_tokens = 32
    temperature = 0
    stream = $false
  } | ConvertTo-Json -Depth 10 -Compress
  $response = Invoke-CapturedRequest "$base/v1/chat/completions" "POST" @{
    "x-superbrain-gateway-token" = $token
    "x-request-id" = $requestId
  } $body
  Require ([int]$response.StatusCode -eq 200) "generation_http_status" "Current hosted generation did not return 200."
  $traceId = Get-TraceId $response
  $completion = Read-JsonResponse $response "generation"
  Require ([string]$completion.contract_version -eq "cloudflare-workers-ai-llm-gateway-v1") "generation_contract_mismatch" "Completion did not use the source-bound hosted gateway contract."
  Require ([string]$completion.object -eq "chat.completion") "generation_schema_mismatch" "Completion is not an OpenAI chat.completion."
  Require ([string]$completion.model -eq $Model -and -not [string]::IsNullOrWhiteSpace([string]$completion.choices[0].message.content)) "generation_content_missing" "Completion has no allowlisted model output."
  Require ([string]$completion.provider -eq "workers-ai") "generation_provider_mismatch" "Completion did not identify the Workers AI provider boundary."
  Require ([string]$completion.gateway_mode -eq "cloudflare_workers_ai_live") "generation_gateway_mode_mismatch" "Completion did not use live gateway mode."
  Require ([int]$completion.provider_call_count -eq 1) "generation_provider_call_count" "Current hosted generation must use exactly one provider call."
  Assert-BooleanField $completion "live_provider_calls" $true "generation_live_provider_unproven"
  Assert-BooleanField $completion "direct_provider_calls" $false "generation_direct_provider_call_detected"
  Assert-BooleanField $completion "secret_output" $false "generation_secret_output"
  Assert-BooleanField $completion "gateway_log_readback_verified" $true "generation_gateway_log_unverified"
  Assert-BooleanField $completion "audit_persisted" $true "generation_audit_not_persisted"
  Assert-BooleanField $completion "audit_readback_verified" $true "generation_audit_readback_unverified"
  Require ([string]$completion.request_id -eq $requestId -and [string]$completion.trace_id -eq $traceId) "generation_response_correlation" "Completion request/trace correlation mismatch."
  Require ([string]$completion.evidence_ref -match "^d1_audit:[A-Za-z0-9._:-]+$") "generation_evidence_ref_missing" "Completion has no bounded D1 evidence reference."
  Require ($null -eq $completion.PSObject.Properties["fallback"]) "generation_fallback_overlap" "The primary-generation criterion cannot reuse fallback behavior."

  $proof = Get-IndependentEvidence $base $token $requestId $traceId
  Require ([int]$proof.provider_call_count -eq 1 -and @($proof.gateway_attempts).Count -eq 1) "generation_independent_call_count" "Independent evidence does not prove exactly one provider call."
  Assert-BooleanField $proof "live_provider_calls" $true "generation_independent_live_call_unproven"
  Assert-BooleanField $proof.gateway_log_readback "required" $true "generation_gateway_log_not_required"
  Assert-BooleanField $proof.gateway_log_readback "verified" $true "generation_gateway_log_unverified"
  Require ([string]$proof.reason_code -eq "primary_completed" -and -not [bool]$proof.fallback) "generation_route_not_primary" "Independent evidence does not prove the exact primary route."
  Require ([string]$proof.evidence_ref -eq [string]$completion.evidence_ref) "generation_audit_evidence_mismatch" "Completion and independent readback refer to different audit rows."
  $attempt = $proof.gateway_attempts[0]
  Require ([string]$attempt.provider -eq "workers-ai" -and [string]$attempt.model -eq $Model -and $attempt.success -eq $true) "generation_gateway_log_identity" "Independent AI Gateway log provider/model/outcome mismatch."
  Require ([string]$attempt.gateway_log_id -eq [string]$completion.gateway_log_id) "generation_gateway_log_id_mismatch" "Completion and independent evidence name different AI Gateway logs."
  Require ([string]$attempt.metadata.request_id -eq $requestId -and [string]$attempt.metadata.trace_id -eq $traceId -and [int]$attempt.metadata.attempt_index -eq 1 -and [string]$attempt.metadata.verification_probe -eq "none") "generation_gateway_log_metadata" "AI Gateway metadata does not bind request, trace, primary attempt, and non-probe route."
  Assert-BooleanField $attempt "metadata_correlation_verified" $true "generation_metadata_unverified"

  $report = [ordered]@{
    contract_version = "llm-hosted-current-evidence-chain-v2"
    status = "verified"
    evidence_ref = "current_hosted_llm_generative_routing_audit_verified"
    criterion = "L4 current hosted generation, routing allowlist, and completion audit"
    criterion_points = 18
    credit_eligible = $true
    checked_at = [DateTime]::UtcNow.ToString("o")
    rubric_approval_commit = $RubricApprovalCommit
    base_url = $base
    source = [ordered]@{
      commit_sha = $ExpectedSourceCommitSha
      archive_sha256 = $ExpectedSourceArchiveSha256
      gateway_tree_sha = $closure.gateway_tree
      verifier_blob = $closure.verifier_blob
      implementation_blob = $closure.implementation_blob
      runtime_blob = $closure.runtime_blob
      wrangler_blob = $closure.wrangler_blob
      rubric_blob = $closure.rubric_blob
      capability_blob = $closure.capability_blob
    }
    authority = $gateBinding
    criteria = @(
      [ordered]@{ claim_id = "hosted_generative_source_bound"; points = 10 },
      [ordered]@{ claim_id = "hosted_routing_allowlist"; points = 4 },
      [ordered]@{ claim_id = "hosted_completion_audit"; points = 4 }
    )
    generation = [ordered]@{
      model = $Model
      provider = "workers-ai"
      response_sha256 = Get-TextSha256 ([string]$response.Content)
      request_id_sha256 = Get-TextSha256 $requestId
      trace_id_sha256 = Get-TextSha256 $traceId
      gateway_log_id_sha256 = Get-TextSha256 ([string]$attempt.gateway_log_id)
      d1_evidence_ref = [string]$proof.evidence_ref
      source_bound = $true
      gateway_log_readback_verified = $true
    }
    routing = [ordered]@{
      requested_model = $Model
      selected_model = [string]$completion.model
      allowed_models_sha256 = $allowedModelsSha256
      allowed_model_count = $modelIds.Count
      allowlist_verified = $true
      gateway_only = $true
      fallback_used = $false
    }
    audit = [ordered]@{
      persisted = $true
      readback_verified = $true
      source_bound = $true
      provider_call_count = 1
    }
    historical_evidence = [ordered]@{
      contract_version = "live-llm-bounded-evidence-chain-v1"
      progress_credit_recommended = 0
      excluded_from_current_delta = $true
    }
    live_provider_calls = $true
    provider_call_count = 1
    direct_provider_calls = $false
    provider_writes = $false
    hosted_audit_write = $true
    secret_output = $false
    manifest_updated = $false
    delta_ledger_entry_created = $false
    production_deploy = $false
    release_promotion = $false
  }
  $written = Write-ImmutableEvidence $report
  Write-Host "$script:Prefix status=verified candidate_bound=true generation=10 routing_audit=8 provider_calls=1 gateway_log_readback=true d1_readback=true historical_credit_excluded=10 secret_output=false evidence_sha256=$($written.evidence_sha256) report=$($written.report_path)"
} catch {
  Write-Error "$script:Prefix status=blocked $($_.Exception.Message)"
  throw
} finally {
  Pop-Location
}

param(
  [string]$BaseUrl = "https://cloud-superbrain-llm-gateway-preview.strazzusochr.workers.dev",
  [string]$ExpectedSourceCommitSha = "",
  [string]$ExpectedSourceArchiveSha256 = "",
  [string]$RubricApprovalCommit = "",
  [switch]$OwnerApprovedGatewayCredentialUse,
  [switch]$OwnerApprovedLiveProviderCalls,
  [switch]$OwnerApprovedHostedAuditWrites,
  [string]$Model = "@cf/meta/llama-3.1-8b-instruct-fast",
  [string]$OutDir = ".phase1-artifacts/llm-gateway/hosted-stream-parity"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$script:Prefix = "[llm-hosted-stream-parity]"
$script:SanctionedBaseUrl = "https://cloud-superbrain-llm-gateway-preview.strazzusochr.workers.dev"
$script:GatewayTokenEnvName = "CLOUD_SUPERBRAIN_LLM_GATEWAY_TOKEN"
$script:VerifierPath = "scripts/verify-llm-hosted-stream-parity.ps1"
$script:RuntimePath = "services/cloudflare-llm-gateway/src/index.js"
$script:WranglerPath = "services/cloudflare-llm-gateway/wrangler.jsonc"
$script:GatewayTreePath = "services/cloudflare-llm-gateway"
$script:RubricPath = "docs/runtime-contracts/layer-credit-rubric.md"
$script:CapabilityPath = "docs/runtime-state/capability-gates.json"

function Stop-Blocked([string]$Code, [string]$Detail) { throw "blocker=$Code detail=$Detail" }
function Require([bool]$Condition, [string]$Code, [string]$Detail) { if (-not $Condition) { Stop-Blocked $Code $Detail } }
function Get-TextSha256([string]$Value) { $sha = [Security.Cryptography.SHA256]::Create(); try { return (($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value)) | ForEach-Object { $_.ToString("x2") }) -join "") } finally { $sha.Dispose() } }
function Get-HeaderValue($Response, [string]$Name) { $value = $Response.Headers[$Name]; if ($null -eq $value) { return "" }; if ($value -is [array]) { return [string]$value[0] }; return [string]$value }
function Read-JsonResponse($Response, [string]$Label) { try { return ([string]$Response.Content | ConvertFrom-Json -ErrorAction Stop) } catch { Stop-Blocked "${Label}_invalid_json" "Hosted response was not valid JSON." } }
function Invoke-CapturedRequest([string]$Uri, [string]$Method = "GET", [hashtable]$Headers = @{}, [string]$Body = "") {
  $params = @{ Uri = $Uri; Method = $Method; Headers = $Headers; TimeoutSec = 120; UseBasicParsing = $true; SkipHttpErrorCheck = $true; MaximumRedirection = 0 }
  if ($Method -ne "GET") { $params.ContentType = "application/json"; $params.Body = $Body }
  try { $response = Invoke-WebRequest @params } catch { Stop-Blocked "hosted_transport_failed" "The sanctioned Preview request did not complete without redirect." }
  Require ([int]$response.StatusCode -lt 300 -or [int]$response.StatusCode -ge 400) "hosted_redirect_forbidden" "Redirect responses are forbidden for credential-bearing hosted verification."
  return $response
}
function Invoke-Git([string[]]$Arguments, [string]$Blocker) { $output = & git @Arguments 2>$null; if ($LASTEXITCODE -ne 0) { Stop-Blocked $Blocker "Git could not validate the immutable candidate binding." }; return (($output | Out-String).Trim()) }
function Get-GitArchiveSha256([string]$CommitSha) {
  $start = [Diagnostics.ProcessStartInfo]::new(); $start.FileName = "git"; $start.WorkingDirectory = (Get-Location).Path; $start.UseShellExecute = $false; $start.CreateNoWindow = $true; $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true
  [void]$start.ArgumentList.Add("archive"); [void]$start.ArgumentList.Add("--format=tar"); [void]$start.ArgumentList.Add($CommitSha); $process = [Diagnostics.Process]::Start($start); $stderr = $process.StandardError.ReadToEndAsync(); $sha = [Security.Cryptography.SHA256]::Create()
  try { $digest = $sha.ComputeHash($process.StandardOutput.BaseStream) } finally { $sha.Dispose() }; $process.WaitForExit(); $null = $stderr.GetAwaiter().GetResult(); Require ($process.ExitCode -eq 0) "source_archive_reconstruction_failed" "git archive could not reconstruct the candidate source."; return (($digest | ForEach-Object { $_.ToString("x2") }) -join "")
}
function Assert-BooleanField($Payload, [string]$Field, [bool]$Expected, [string]$Code) { $property = $Payload.PSObject.Properties[$Field]; Require ($null -ne $property -and $property.Value -is [bool] -and [bool]$property.Value -eq $Expected) $Code "$Field must be the JSON boolean $($Expected.ToString().ToLowerInvariant())." }
function Assert-SanctionedTarget([string]$Value) { Require ($Value -ceq $script:SanctionedBaseUrl) "unsanctioned_preview_host" "BaseUrl must exactly equal the sanctioned Preview Worker origin; alternate hosts, paths, ports, queries, fragments, and userinfo are forbidden." }

function Assert-CandidateClosure {
  Require ($ExpectedSourceCommitSha -match "^[0-9a-f]{40}$") "expected_source_commit_sha_required" "Pass the exact lowercase candidate commit SHA."; Require ($ExpectedSourceArchiveSha256 -match "^[0-9a-f]{64}$") "expected_source_archive_sha256_required" "Pass the exact lowercase candidate archive SHA-256."
  Require ((Invoke-Git @("rev-parse", "HEAD") "head_unavailable") -ceq $ExpectedSourceCommitSha) "candidate_head_mismatch" "HEAD must equal the exact hosted candidate commit before any HTTP request."
  $paths = @($script:VerifierPath, $script:RuntimePath, $script:WranglerPath, $script:RubricPath, $script:CapabilityPath); $blobs = [ordered]@{}
  foreach ($path in $paths) { [void](Invoke-Git @("show", "$ExpectedSourceCommitSha`:$path") "candidate_blob_missing"); $candidateBlob = Invoke-Git @("rev-parse", "$ExpectedSourceCommitSha`:$path") "candidate_blob_missing"; $worktreeBlob = Invoke-Git @("hash-object", "--", $path) "worktree_blob_missing"; Require ($candidateBlob -ceq $worktreeBlob) "candidate_blob_drift" "Bound path differs from its candidate blob: $path"; $blobs[$path] = $candidateBlob }
  $drift = Invoke-Git @("status", "--porcelain=v1", "--untracked-files=all", "--", $script:VerifierPath, $script:GatewayTreePath, $script:RubricPath, $script:CapabilityPath) "candidate_status_failed"; Require ([string]::IsNullOrWhiteSpace($drift)) "candidate_worktree_drift" "Staged, unstaged, or untracked drift exists in a bound candidate path."
  Require ((Get-GitArchiveSha256 $ExpectedSourceCommitSha) -ceq $ExpectedSourceArchiveSha256) "source_archive_sha_mismatch" "ExpectedSourceArchiveSha256 is not reproducible from git archive of the candidate commit."
  return [ordered]@{ verifier_blob = $blobs[$script:VerifierPath]; runtime_blob = $blobs[$script:RuntimePath]; wrangler_blob = $blobs[$script:WranglerPath]; rubric_blob = $blobs[$script:RubricPath]; capability_blob = $blobs[$script:CapabilityPath]; gateway_tree = Invoke-Git @("rev-parse", "$ExpectedSourceCommitSha`:$script:GatewayTreePath") "candidate_gateway_tree_missing" }
}
function Assert-ApprovedRubric {
  Require ($RubricApprovalCommit -match "^[0-9a-f]{40}$") "rubric_approval_commit_required" "Pass the lowercase SHA of the Owner-approved rubric commit."; & git merge-base --is-ancestor $RubricApprovalCommit $ExpectedSourceCommitSha 2>$null; Require ($LASTEXITCODE -eq 0) "rubric_commit_not_in_candidate" "The rubric approval commit is not an ancestor of the candidate."
  $approved = Invoke-Git @("show", "$RubricApprovalCommit`:$script:RubricPath") "rubric_approval_commit_invalid"; $candidate = Invoke-Git @("show", "$ExpectedSourceCommitSha`:$script:RubricPath") "candidate_rubric_missing"
  foreach ($content in @($approved, $candidate)) { Require ($content -match '(?im)^Status:\s*`?(?:OWNER_)?APPROVED`?\s*$') "rubric_not_owner_approved" "The immutable rubric is not marked APPROVED."; Require ($content -match '(?im)^Credit-Anwendung erlaubt:\s*`?true`?\s*$') "rubric_credit_disabled" "The immutable rubric does not allow credit application." }
  Require ((Invoke-Git @("rev-parse", "$RubricApprovalCommit`:$script:RubricPath") "rubric_blob_missing") -ceq (Invoke-Git @("rev-parse", "$ExpectedSourceCommitSha`:$script:RubricPath") "candidate_rubric_missing")) "rubric_blob_drift" "Candidate rubric differs from the approved blob."; Require ($candidate -match '(?im)^Owner-Freigabe-Ref:\s*`?[^`\r\n]{8,200}`?\s*$') "rubric_owner_grant_ref_missing" "The approved rubric has no tracked Owner-Freigabe-Ref."; Require ($candidate -match '(?im)^\|\s*Hosted Stream und Non-Stream sind semantisch gleich\s*\|\s*10\s*\|.*verify-llm-hosted-stream-parity\.ps1') "rubric_criterion_drift" "The approved rubric lacks the exact 10-point stream-parity row."
}
function Assert-LiveProviderGate {
  try { $state = (Invoke-Git @("show", "$ExpectedSourceCommitSha`:$script:CapabilityPath") "candidate_capability_gate_missing") | ConvertFrom-Json -ErrorAction Stop } catch { Stop-Blocked "capability_gate_invalid_json" "The candidate capability gate is invalid JSON." }; Require ([string]$state.contract_version -eq "capability-gate-state-v1") "capability_gate_contract_mismatch" "Unexpected capability gate contract."; $gate = $state.gates.live_llm_provider_calls
  Require ($null -ne $gate -and $gate.owner_granted -eq $true -and $gate.live_verified -eq $true) "live_llm_provider_gate_closed" "The tracked live LLM Owner/live gate is not verified."; Require ($gate.paid_provider -eq $false -and [string]$gate.provider -eq "cloudflare_workers_ai") "live_llm_provider_gate_provider" "The tracked gate does not prove the free Workers AI path."; Require ([string]$gate.verifier -eq "scripts/verify-live-llm-free-provider.ps1") "live_llm_provider_gate_verifier" "Unexpected tracked gate verifier."
  $grantRef = [string]$gate.owner_grant_ref; Require (-not [string]::IsNullOrWhiteSpace($grantRef)) "live_llm_owner_grant_ref_missing" "Tracked gate has no Owner grant reference."; $grantPath = ($grantRef -split '\s+::\s+', 2)[0]; Require ($grantPath -match '^[A-Za-z0-9_./-]+\.md$') "live_llm_owner_grant_ref_invalid" "Grant reference is not a tracked Markdown path."; [void](Invoke-Git @("show", "$ExpectedSourceCommitSha`:$grantPath") "live_llm_owner_grant_ref_untracked")
  $evidencePath = [string]$gate.evidence_artifact; Require ($evidencePath -match '^[A-Za-z0-9_./-]+\.json$') "live_llm_gate_evidence_ref_invalid" "Gate evidence reference is invalid."; [void](Invoke-Git @("show", "$ExpectedSourceCommitSha`:$evidencePath") "live_llm_gate_evidence_untracked"); return [ordered]@{ owner_grant_ref_sha256 = Get-TextSha256 $grantRef; gate_evidence_path = $evidencePath; gate_evidence_blob = Invoke-Git @("rev-parse", "$ExpectedSourceCommitSha`:$evidencePath") "live_llm_gate_evidence_untracked" }
}
function Assert-SourceBinding($Health) { Require ([string]$Health.source_commit_sha -ceq $ExpectedSourceCommitSha) "hosted_source_commit_mismatch" "Health commit mismatch."; Require ([string]$Health.source_archive_sha256 -ceq $ExpectedSourceArchiveSha256) "hosted_source_archive_mismatch" "Health archive mismatch."; Assert-BooleanField $Health "source_binding_configured" $true "hosted_source_binding_unconfigured" }
function Get-RequiredToken { Require $OwnerApprovedGatewayCredentialUse.IsPresent "gateway_credential_confirmation_required" "Credential switch is extra confirmation only."; Require $OwnerApprovedLiveProviderCalls.IsPresent "live_provider_call_confirmation_required" "Live-provider switch is extra confirmation only."; Require $OwnerApprovedHostedAuditWrites.IsPresent "hosted_audit_write_confirmation_required" "D1 audit-write switch is extra confirmation only."; $token = [Environment]::GetEnvironmentVariable($script:GatewayTokenEnvName, "Process"); Require (-not [string]::IsNullOrWhiteSpace($token) -and $token.Length -ge 16) "gateway_token_missing" "The fixed approved gateway token is absent."; return $token }
function Get-TraceId($Response) { $traceparent = Get-HeaderValue $Response "traceparent"; Require ($traceparent -match '^00-([0-9a-f]{32})-[0-9a-f]{16}-0[01]$') "response_traceparent_invalid" "Hosted response lacks a valid W3C traceparent."; return $Matches[1] }
function Get-IndependentEvidence([string]$Base, [string]$Token, [string]$RequestId, [string]$TraceId) { $uri = "$Base/api/v1/evidence?request_id=$([Uri]::EscapeDataString($RequestId))&trace_id=$TraceId"; $response = Invoke-CapturedRequest $uri "GET" @{ "x-superbrain-gateway-token" = $Token }; Require ([int]$response.StatusCode -eq 200) "independent_evidence_http_status" "Independent readback did not return 200."; $proof = Read-JsonResponse $response "independent_evidence"; Require ([string]$proof.contract_version -eq "llm-gateway-independent-evidence-v1" -and [string]$proof.status -eq "verified") "independent_evidence_contract" "Independent evidence is not verified."; Require ([string]$proof.request_id -eq $RequestId -and [string]$proof.trace_id -eq $TraceId) "independent_evidence_correlation" "Independent evidence correlation mismatch."; Require ([string]$proof.source_commit_sha -ceq $ExpectedSourceCommitSha -and [string]$proof.source_archive_sha256 -ceq $ExpectedSourceArchiveSha256) "independent_evidence_source_mismatch" "Independent evidence source mismatch."; Assert-BooleanField $proof "audit_readback_verified" $true "independent_audit_readback_unverified"; Assert-BooleanField $proof "direct_provider_calls" $false "independent_direct_provider_call_detected"; Assert-BooleanField $proof "secret_output" $false "independent_secret_output_unproven"; return $proof }
function Assert-ParityGatewayAttempt($Attempt, [string]$RequestId, [string]$TraceId) {
  Require ([string]$Attempt.provider -eq "workers-ai" -and [string]$Attempt.model -eq $Model -and $Attempt.success -eq $true) "parity_gateway_log_identity" "Independent log readback does not prove the successful Workers AI model call."
  Assert-BooleanField $Attempt "gateway_log_readback_verified" $true "parity_gateway_log_unverified"
  Assert-BooleanField $Attempt "metadata_correlation_verified" $true "parity_metadata_unverified"
  Require ([string]$Attempt.metadata.request_id -eq $RequestId -and [string]$Attempt.metadata.trace_id -eq $TraceId -and [int]$Attempt.metadata.attempt_index -eq 1 -and [string]$Attempt.metadata.verification_probe -eq "hosted_stream_parity") "parity_gateway_log_metadata" "Independent AI Gateway metadata does not match request, trace, attempt, and probe."
  Require (-not [string]::IsNullOrWhiteSpace([string]$Attempt.gateway_log_id)) "parity_gateway_log_id_missing" "Independent evidence contains no AI Gateway log ID."
}

function Get-ChoiceText($Payload) { $text = [string]$Payload.choices[0].message.content; Require (-not [string]::IsNullOrWhiteSpace($text)) "nonstream_text_missing" "Non-stream completion has no assistant content."; return $text }
function Normalize-Semantic([string]$Text) { return (($Text.Trim().ToLowerInvariant()) -replace '[.!]+$', '') }
function Read-OpenAiSse([string]$Content) {
  $frames = @(); $doneCount = 0; $assembled = [Text.StringBuilder]::new(); $dataLines = @($Content -split '\r?\n' | Where-Object { $_ -like "data:*" })
  Require ($dataLines.Count -gt 1) "stream_frames_missing" "Provider stream has no SSE data frames."
  foreach ($line in $dataLines) {
    $data = ([string]$line).Substring(5).TrimStart()
    if ($data -eq "[DONE]") { $doneCount += 1; continue }
    try { $frame = $data | ConvertFrom-Json -ErrorAction Stop } catch { Stop-Blocked "stream_frame_invalid_json" "Provider SSE frame is not valid JSON." }
    Require ([string]$frame.object -eq "chat.completion.chunk") "stream_frame_not_openai_chunk" "Every provider frame must be chat.completion.chunk."
    Require ($null -eq $frame.PSObject.Properties["terminal"]) "synthetic_terminal_frame_forbidden" "Synthetic terminal evidence frames are forbidden."
    foreach ($choice in @($frame.choices)) {
      Require ($null -ne $choice.delta -and $null -eq $choice.PSObject.Properties["message"]) "stream_frame_not_delta" "Every streamed choice must contain delta and no full message."
      if ($null -ne $choice.delta.PSObject.Properties["content"]) { [void]$assembled.Append([string]$choice.delta.content) }
    }
    $frames += $frame
  }
  Require ($doneCount -eq 1 -and $dataLines[-1].Trim() -eq "data: [DONE]") "stream_done_contract" "The real provider stream must end with exactly one [DONE]."
  Require ($frames.Count -gt 0) "stream_frames_missing" "Provider stream has no OpenAI chunk frames."
  return [ordered]@{ content = $assembled.ToString(); frame_count = $frames.Count; done_count = $doneCount }
}
function Write-ImmutableEvidence([hashtable]$Report) { $runId = "{0}-{1}-{2}" -f ([DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")), $ExpectedSourceCommitSha.Substring(0, 12), ([Guid]::NewGuid().ToString("N").Substring(0, 8)); $runDir = Join-Path $OutDir $runId; [void](New-Item -ItemType Directory -Path $runDir -Force:$false); $reportPath = Join-Path $runDir "report.json"; $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($Report | ConvertTo-Json -Depth 24) + "`n"); $stream = [IO.File]::Open($reportPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None); try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }; $digest = (Get-FileHash -LiteralPath $reportPath -Algorithm SHA256).Hash.ToLowerInvariant(); [IO.File]::WriteAllText((Join-Path $runDir "report.sha256"), "$digest  report.json`n", [Text.UTF8Encoding]::new($false)); return [ordered]@{ report_path = $reportPath; evidence_sha256 = $digest } }

$repoRoot = Split-Path -Parent $PSScriptRoot; Push-Location $repoRoot
try {
  Require ($PSVersionTable.PSVersion.Major -ge 7) "powershell_7_required" "PowerShell 7 or newer is required."; Assert-SanctionedTarget $BaseUrl; $closure = Assert-CandidateClosure; Assert-ApprovedRubric; $gateBinding = Assert-LiveProviderGate; $base = $script:SanctionedBaseUrl
  $healthResponse = Invoke-CapturedRequest "$base/api/v1/health"; Require ([int]$healthResponse.StatusCode -eq 200) "health_http_status" "Health must return 200."; $health = Read-JsonResponse $healthResponse "health"; Require ([string]$health.status -eq "healthy") "health_not_healthy" "Gateway is not healthy."; Assert-SourceBinding $health
  $capability = $health.verification_capabilities.hosted_stream_parity; Require ($null -ne $capability -and [string]$capability.contract_version -eq "llm-hosted-stream-parity-probe-v1") "stream_capability_missing" "Stream-parity capability is missing."; Assert-BooleanField $capability "configured" $true "stream_capability_unconfigured"; Assert-BooleanField $capability "verified" $false "stream_capability_health_overclaim"; Assert-BooleanField $capability "provider_readable_stream_required" $true "provider_stream_capability_unproven"; Assert-BooleanField $capability "gateway_log_readback_verified" $false "stream_capability_health_log_overclaim"; Require ([int]$capability.max_provider_calls_per_request -eq 1) "stream_call_bound" "Each parity request must cap one provider call."
  $token = Get-RequiredToken; $semanticKey = "parity-" + [Guid]::NewGuid().ToString("N"); $metadata = @{ verification_probe = "hosted_stream_parity"; semantic_key = $semanticKey }
  $nonStreamId = "l4-parity-json-" + [Guid]::NewGuid().ToString("N"); $nonStreamBody = [ordered]@{ model = $Model; messages = @(@{ role = "user"; content = "Return exactly the single word verified." }); max_tokens = 16; temperature = 0; stream = $false; metadata = $metadata } | ConvertTo-Json -Depth 10 -Compress
  $nonStreamResponse = Invoke-CapturedRequest "$base/v1/chat/completions" "POST" @{ "x-superbrain-gateway-token" = $token; "x-request-id" = $nonStreamId; "x-superbrain-semantic-key" = $semanticKey } $nonStreamBody; Require ([int]$nonStreamResponse.StatusCode -eq 200) "nonstream_http_status" "Non-stream parity call did not return 200."; $nonStream = Read-JsonResponse $nonStreamResponse "nonstream"; Require ([string]$nonStream.object -eq "chat.completion") "nonstream_schema_invalid" "Non-stream response is not a chat.completion."; $nonStreamText = Get-ChoiceText $nonStream; $nonStreamTrace = Get-TraceId $nonStreamResponse
  $nonStreamProof = Get-IndependentEvidence $base $token $nonStreamId $nonStreamTrace; Require ([int]$nonStreamProof.provider_call_count -eq 1 -and @($nonStreamProof.gateway_attempts).Count -eq 1) "nonstream_independent_call_count" "Non-stream evidence does not prove one provider call."; Assert-BooleanField $nonStreamProof.gateway_log_readback "required" $true "nonstream_gateway_log_not_required"; Assert-BooleanField $nonStreamProof.gateway_log_readback "verified" $true "nonstream_gateway_log_unverified"; Assert-BooleanField $nonStreamProof "semantic_probe_verified" $true "nonstream_semantic_probe_unverified"; Assert-ParityGatewayAttempt $nonStreamProof.gateway_attempts[0] $nonStreamId $nonStreamTrace

  $streamId = "l4-parity-sse-" + [Guid]::NewGuid().ToString("N"); $streamBody = [ordered]@{ model = $Model; messages = @(@{ role = "user"; content = "Return exactly the single word verified." }); max_tokens = 16; temperature = 0; stream = $true; metadata = $metadata } | ConvertTo-Json -Depth 10 -Compress
  $streamResponse = Invoke-CapturedRequest "$base/v1/chat/completions" "POST" @{ "x-superbrain-gateway-token" = $token; "x-request-id" = $streamId; "x-superbrain-semantic-key" = $semanticKey } $streamBody; Require ([int]$streamResponse.StatusCode -eq 200) "stream_http_status" "Stream parity call did not return 200."; Require ((Get-HeaderValue $streamResponse "Content-Type") -match '^text/event-stream') "stream_content_type" "Stream response is not SSE."; $sse = Read-OpenAiSse ([string]$streamResponse.Content); $streamTrace = Get-TraceId $streamResponse
  $streamProof = Get-IndependentEvidence $base $token $streamId $streamTrace; Require ([int]$streamProof.provider_call_count -eq 1 -and @($streamProof.gateway_attempts).Count -eq 1) "stream_independent_call_count" "Stream evidence does not prove one provider call."; Assert-BooleanField $streamProof "stream" $true "stream_evidence_mode"; Assert-BooleanField $streamProof.gateway_log_readback "required" $true "stream_gateway_log_not_required"; Assert-BooleanField $streamProof.gateway_log_readback "verified" $true "stream_gateway_log_unverified"; Assert-BooleanField $streamProof "semantic_probe_verified" $true "stream_semantic_probe_unverified"; Assert-ParityGatewayAttempt $streamProof.gateway_attempts[0] $streamId $streamTrace
  Require ((Normalize-Semantic $nonStreamText) -eq "verified" -and (Normalize-Semantic ([string]$sse.content)) -eq "verified") "stream_semantic_mismatch" "Real provider stream and non-stream completion are not semantically equivalent."
  $nonLog = [string]$nonStreamProof.gateway_attempts[0].gateway_log_id; $streamLog = [string]$streamProof.gateway_attempts[0].gateway_log_id; Require (-not [string]::IsNullOrWhiteSpace($nonLog) -and -not [string]::IsNullOrWhiteSpace($streamLog) -and $nonLog -ne $streamLog) "parity_gateway_log_identity" "Parity requires two distinct independently read AI Gateway logs."

  $report = [ordered]@{
    contract_version = "llm-hosted-stream-parity-evidence-v2"; status = "verified"; criterion = "L4 hosted stream and non-stream are semantically equal"; criterion_points = 10; credit_eligible = $true; checked_at = [DateTime]::UtcNow.ToString("o"); rubric_approval_commit = $RubricApprovalCommit; base_url = $base
    source = [ordered]@{ commit_sha = $ExpectedSourceCommitSha; archive_sha256 = $ExpectedSourceArchiveSha256; gateway_tree_sha = $closure.gateway_tree; verifier_blob = $closure.verifier_blob; runtime_blob = $closure.runtime_blob; wrangler_blob = $closure.wrangler_blob; rubric_blob = $closure.rubric_blob; capability_blob = $closure.capability_blob }; authority = $gateBinding
    nonstream = [ordered]@{ request_id_sha256 = Get-TextSha256 $nonStreamId; trace_id_sha256 = Get-TextSha256 $nonStreamTrace; gateway_log_id_sha256 = Get-TextSha256 $nonLog; d1_evidence_ref = [string]$nonStreamProof.evidence_ref; response_sha256 = Get-TextSha256 ([string]$nonStreamResponse.Content); gateway_log_readback_verified = $true; audit_readback_verified = $true }
    stream = [ordered]@{ request_id_sha256 = Get-TextSha256 $streamId; trace_id_sha256 = Get-TextSha256 $streamTrace; gateway_log_id_sha256 = Get-TextSha256 $streamLog; d1_evidence_ref = [string]$streamProof.evidence_ref; response_sha256 = Get-TextSha256 ([string]$streamResponse.Content); frame_count = [int]$sse.frame_count; done_count = 1; synthetic_terminal_frame = $false; gateway_log_readback_verified = $true; audit_readback_verified = $true }
    semantic_parity = $true; live_provider_calls = $true; provider_call_count = 2; direct_provider_calls = $false; provider_writes = $false; hosted_audit_write = $true; secret_output = $false; manifest_updated = $false; delta_ledger_entry_created = $false; production_deploy = $false; release_promotion = $false
  }
  $written = Write-ImmutableEvidence $report; Write-Host "$script:Prefix status=verified candidate_bound=true real_provider_stream=true semantic_parity=true gateway_logs=2 d1_readback=true redirects=false secret_output=false evidence_sha256=$($written.evidence_sha256) report=$($written.report_path)"
} catch { Write-Error "$script:Prefix status=blocked $($_.Exception.Message)"; throw } finally { Pop-Location }

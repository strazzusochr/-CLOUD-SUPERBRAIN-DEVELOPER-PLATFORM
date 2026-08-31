param(
  [string]$BaseUrl = "https://cloud-superbrain-llm-gateway-preview.strazzusochr.workers.dev",
  [string]$ExpectedSourceCommitSha = "",
  [string]$ExpectedSourceArchiveSha256 = "",
  [string]$RubricApprovalCommit = "",
  [switch]$OwnerApprovedGatewayCredentialUse,
  [switch]$OwnerApprovedHostedAuditWrites,
  [string]$Model = "@cf/meta/llama-3.1-8b-instruct",
  [string]$OutDir = ".phase1-artifacts/llm-gateway/hosted-negative-guards"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$script:Prefix = "[llm-hosted-negative-guards]"
$script:SanctionedBaseUrl = "https://cloud-superbrain-llm-gateway-preview.strazzusochr.workers.dev"
$script:GatewayTokenEnvName = "CLOUD_SUPERBRAIN_LLM_GATEWAY_TOKEN"
$script:VerifierPath = "scripts/verify-llm-hosted-negative-guards.ps1"
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
  $params = @{ Uri = $Uri; Method = $Method; Headers = $Headers; TimeoutSec = 90; UseBasicParsing = $true; SkipHttpErrorCheck = $true; MaximumRedirection = 0 }
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
  Require ($ExpectedSourceCommitSha -match "^[0-9a-f]{40}$") "expected_source_commit_sha_required" "Pass the exact lowercase candidate commit SHA."
  Require ($ExpectedSourceArchiveSha256 -match "^[0-9a-f]{64}$") "expected_source_archive_sha256_required" "Pass the exact lowercase candidate archive SHA-256."
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
  Require ((Invoke-Git @("rev-parse", "$RubricApprovalCommit`:$script:RubricPath") "rubric_blob_missing") -ceq (Invoke-Git @("rev-parse", "$ExpectedSourceCommitSha`:$script:RubricPath") "candidate_rubric_missing")) "rubric_blob_drift" "Candidate rubric differs from the approved blob."
  Require ($candidate -match '(?im)^Owner-Freigabe-Ref:\s*`?[^`\r\n]{8,200}`?\s*$') "rubric_owner_grant_ref_missing" "The approved rubric has no tracked Owner-Freigabe-Ref."
  foreach ($row in @(
    'Hosted fehlende/ungueltige Authentifizierung liefert 401/403\s*\|\s*2',
    'Hosted Oversize-Request liefert fail-closed 422\s*\|\s*2',
    'Hosted Schema-/Policy-Verstoss erreicht keinen Provider\s*\|\s*3'
  )) { Require ($candidate -match "(?im)^\|\s*$row\s*\|.*verify-llm-hosted-negative-guards\.ps1") "rubric_criterion_drift" "The approved rubric lacks an exact negative-guard row." }
}
function Assert-LiveProviderGate {
  try { $state = (Invoke-Git @("show", "$ExpectedSourceCommitSha`:$script:CapabilityPath") "candidate_capability_gate_missing") | ConvertFrom-Json -ErrorAction Stop } catch { Stop-Blocked "capability_gate_invalid_json" "The candidate capability gate is invalid JSON." }
  Require ([string]$state.contract_version -eq "capability-gate-state-v1") "capability_gate_contract_mismatch" "Unexpected capability gate contract."; $gate = $state.gates.live_llm_provider_calls
  Require ($null -ne $gate -and $gate.owner_granted -eq $true -and $gate.live_verified -eq $true) "live_llm_provider_gate_closed" "The tracked live LLM Owner/live gate is not verified."; Require ($gate.paid_provider -eq $false -and [string]$gate.provider -eq "cloudflare_workers_ai") "live_llm_provider_gate_provider" "The tracked gate does not prove the free Workers AI path."; Require ([string]$gate.verifier -eq "scripts/verify-live-llm-free-provider.ps1") "live_llm_provider_gate_verifier" "Unexpected tracked gate verifier."
  $grantRef = [string]$gate.owner_grant_ref; Require (-not [string]::IsNullOrWhiteSpace($grantRef)) "live_llm_owner_grant_ref_missing" "Tracked gate has no Owner grant reference."; $grantPath = ($grantRef -split '\s+::\s+', 2)[0]; Require ($grantPath -match '^[A-Za-z0-9_./-]+\.md$') "live_llm_owner_grant_ref_invalid" "Grant reference is not a tracked Markdown path."; [void](Invoke-Git @("show", "$ExpectedSourceCommitSha`:$grantPath") "live_llm_owner_grant_ref_untracked")
  $evidencePath = [string]$gate.evidence_artifact; Require ($evidencePath -match '^[A-Za-z0-9_./-]+\.json$') "live_llm_gate_evidence_ref_invalid" "Gate evidence reference is invalid."; [void](Invoke-Git @("show", "$ExpectedSourceCommitSha`:$evidencePath") "live_llm_gate_evidence_untracked")
  return [ordered]@{ owner_grant_ref_sha256 = Get-TextSha256 $grantRef; gate_evidence_path = $evidencePath; gate_evidence_blob = Invoke-Git @("rev-parse", "$ExpectedSourceCommitSha`:$evidencePath") "live_llm_gate_evidence_untracked" }
}
function Assert-SourceBinding($Health) { Require ([string]$Health.source_commit_sha -ceq $ExpectedSourceCommitSha) "hosted_source_commit_mismatch" "Health commit mismatch."; Require ([string]$Health.source_archive_sha256 -ceq $ExpectedSourceArchiveSha256) "hosted_source_archive_mismatch" "Health archive mismatch."; Assert-BooleanField $Health "source_binding_configured" $true "hosted_source_binding_unconfigured" }
function Get-RequiredToken { Require $OwnerApprovedGatewayCredentialUse.IsPresent "gateway_credential_confirmation_required" "Credential switch is extra confirmation only."; Require $OwnerApprovedHostedAuditWrites.IsPresent "hosted_audit_write_confirmation_required" "D1 audit-write switch is extra confirmation only."; $token = [Environment]::GetEnvironmentVariable($script:GatewayTokenEnvName, "Process"); Require (-not [string]::IsNullOrWhiteSpace($token) -and $token.Length -ge 16) "gateway_token_missing" "The fixed approved gateway token is absent."; return $token }
function Get-TraceId($Response) { $traceparent = Get-HeaderValue $Response "traceparent"; Require ($traceparent -match '^00-([0-9a-f]{32})-[0-9a-f]{16}-0[01]$') "response_traceparent_invalid" "Hosted response lacks a valid W3C traceparent."; return $Matches[1] }
function Get-IndependentEvidence([string]$Base, [string]$Token, [string]$RequestId, [string]$TraceId) {
  $uri = "$Base/api/v1/evidence?request_id=$([Uri]::EscapeDataString($RequestId))&trace_id=$TraceId"; $response = Invoke-CapturedRequest $uri "GET" @{ "x-superbrain-gateway-token" = $Token }; Require ([int]$response.StatusCode -eq 200) "independent_evidence_http_status" "Independent readback did not return 200."; $proof = Read-JsonResponse $response "independent_evidence"
  Require ([string]$proof.contract_version -eq "llm-gateway-independent-evidence-v1" -and [string]$proof.status -eq "verified") "independent_evidence_contract" "Independent evidence is not verified."; Require ([string]$proof.request_id -eq $RequestId -and [string]$proof.trace_id -eq $TraceId) "independent_evidence_correlation" "Independent evidence correlation mismatch."; Require ([string]$proof.source_commit_sha -ceq $ExpectedSourceCommitSha -and [string]$proof.source_archive_sha256 -ceq $ExpectedSourceArchiveSha256) "independent_evidence_source_mismatch" "Independent evidence source mismatch."; Assert-BooleanField $proof "audit_readback_verified" $true "independent_audit_readback_unverified"; Assert-BooleanField $proof "direct_provider_calls" $false "independent_direct_provider_call_detected"; Assert-BooleanField $proof "secret_output" $false "independent_secret_output_unproven"; return $proof
}
function Assert-ZeroCallGuard($Response, [int]$Status, [string]$ExpectedError, [string]$Label, [string]$Token, [string]$RequestId) {
  Require ([int]$Response.StatusCode -eq $Status) "${Label}_http_status" "$Label returned an unexpected status."; $payload = Read-JsonResponse $Response $Label
  Require ([string]$payload.error -eq $ExpectedError -and [string]$payload.guard_stage -eq "pre_provider" -and [int]$payload.provider_call_count -eq 0) "${Label}_guard_contract" "$Label did not prove the exact pre-provider zero-call error."
  $traceId = Get-TraceId $Response; $proof = Get-IndependentEvidence $script:SanctionedBaseUrl $Token $RequestId $traceId
  Require ([int]$proof.provider_call_count -eq 0 -and @($proof.gateway_attempts).Count -eq 0 -and [string]$proof.reason_code -eq $ExpectedError) "${Label}_independent_zero_call" "$Label D1 readback does not prove zero provider attempts and the exact reason."
  Assert-BooleanField $proof.gateway_log_readback "required" $false "${Label}_gateway_log_unexpected"
  return [ordered]@{ name = $Label; http_status = $Status; error = $ExpectedError; request_id_sha256 = Get-TextSha256 $RequestId; trace_id_sha256 = Get-TextSha256 $traceId; response_sha256 = Get-TextSha256 ([string]$Response.Content); d1_evidence_ref = [string]$proof.evidence_ref }
}
function Write-ImmutableEvidence([hashtable]$Report) { $runId = "{0}-{1}-{2}" -f ([DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")), $ExpectedSourceCommitSha.Substring(0, 12), ([Guid]::NewGuid().ToString("N").Substring(0, 8)); $runDir = Join-Path $OutDir $runId; [void](New-Item -ItemType Directory -Path $runDir -Force:$false); $reportPath = Join-Path $runDir "report.json"; $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($Report | ConvertTo-Json -Depth 24) + "`n"); $stream = [IO.File]::Open($reportPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None); try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }; $digest = (Get-FileHash -LiteralPath $reportPath -Algorithm SHA256).Hash.ToLowerInvariant(); [IO.File]::WriteAllText((Join-Path $runDir "report.sha256"), "$digest  report.json`n", [Text.UTF8Encoding]::new($false)); return [ordered]@{ report_path = $reportPath; evidence_sha256 = $digest } }

$repoRoot = Split-Path -Parent $PSScriptRoot; Push-Location $repoRoot
try {
  Require ($PSVersionTable.PSVersion.Major -ge 7) "powershell_7_required" "PowerShell 7 or newer is required."; Assert-SanctionedTarget $BaseUrl; $closure = Assert-CandidateClosure; Assert-ApprovedRubric; $gateBinding = Assert-LiveProviderGate; $base = $script:SanctionedBaseUrl
  $healthResponse = Invoke-CapturedRequest "$base/api/v1/health"; Require ([int]$healthResponse.StatusCode -eq 200) "health_http_status" "Health must return 200."; $health = Read-JsonResponse $healthResponse "health"; Require ([string]$health.status -eq "healthy") "health_not_healthy" "Gateway is not healthy."; Assert-SourceBinding $health
  $token = Get-RequiredToken
  $baseBody = [ordered]@{ model = $Model; messages = @(@{ role = "user"; content = "Return a bounded response." }); max_tokens = 8; temperature = 0; stream = $false } | ConvertTo-Json -Depth 10 -Compress
  $probes = @()
  $missingId = "l4-negative-missing-" + [Guid]::NewGuid().ToString("N"); $missing = Invoke-CapturedRequest "$base/v1/chat/completions" "POST" @{ "x-request-id" = $missingId } $baseBody; $probes += Assert-ZeroCallGuard $missing 401 "gateway_authentication_required" "missing_auth" $token $missingId
  $invalidId = "l4-negative-invalid-" + [Guid]::NewGuid().ToString("N"); $invalid = Invoke-CapturedRequest "$base/v1/chat/completions" "POST" @{ "x-request-id" = $invalidId; "x-superbrain-gateway-token" = ([Guid]::NewGuid().ToString("N")) } $baseBody; $probes += Assert-ZeroCallGuard $invalid 401 "gateway_authentication_required" "invalid_auth" $token $invalidId
  $oversizeId = "l4-negative-oversize-" + [Guid]::NewGuid().ToString("N"); $oversizeBody = [ordered]@{ model = $Model; messages = @(@{ role = "user"; content = ("x" * 20001) }); max_tokens = 1; temperature = 0; stream = $false } | ConvertTo-Json -Depth 10 -Compress; $oversize = Invoke-CapturedRequest "$base/v1/chat/completions" "POST" @{ "x-request-id" = $oversizeId; "x-superbrain-gateway-token" = $token } $oversizeBody; $probes += Assert-ZeroCallGuard $oversize 422 "input_limit_exceeded" "oversize" $token $oversizeId
  $schemaId = "l4-negative-schema-" + [Guid]::NewGuid().ToString("N"); $schemaBody = [ordered]@{ model = $Model; messages = @(); max_tokens = 1; temperature = 0; stream = $false } | ConvertTo-Json -Depth 10 -Compress; $schema = Invoke-CapturedRequest "$base/v1/chat/completions" "POST" @{ "x-request-id" = $schemaId; "x-superbrain-gateway-token" = $token } $schemaBody; $probes += Assert-ZeroCallGuard $schema 422 "invalid_messages" "schema_violation" $token $schemaId
  $policyId = "l4-negative-policy-" + [Guid]::NewGuid().ToString("N"); $policyBody = [ordered]@{ model = "forbidden/provider-model"; messages = @(@{ role = "user"; content = "blocked" }); max_tokens = 1; temperature = 0; stream = $false } | ConvertTo-Json -Depth 10 -Compress; $policy = Invoke-CapturedRequest "$base/v1/chat/completions" "POST" @{ "x-request-id" = $policyId; "x-superbrain-gateway-token" = $token } $policyBody; $probes += Assert-ZeroCallGuard $policy 403 "model_not_allowed" "policy_violation" $token $policyId
  Require ($probes.Count -eq 5) "negative_probe_count" "Exactly five negative probes are required."
  $report = [ordered]@{
    contract_version = "llm-hosted-negative-guards-evidence-v2"; status = "verified"; criterion = "L4 hosted auth, oversize, schema, and policy guards stop before provider execution"; criterion_points = 7; credit_eligible = $true; checked_at = [DateTime]::UtcNow.ToString("o"); rubric_approval_commit = $RubricApprovalCommit; base_url = $base
    source = [ordered]@{ commit_sha = $ExpectedSourceCommitSha; archive_sha256 = $ExpectedSourceArchiveSha256; gateway_tree_sha = $closure.gateway_tree; verifier_blob = $closure.verifier_blob; runtime_blob = $closure.runtime_blob; wrangler_blob = $closure.wrangler_blob; rubric_blob = $closure.rubric_blob; capability_blob = $closure.capability_blob }; authority = $gateBinding; probes = $probes
    live_provider_calls = $false; provider_call_count = 0; direct_provider_calls = $false; provider_writes = $false; hosted_audit_write = $true; secret_output = $false; manifest_updated = $false; delta_ledger_entry_created = $false; production_deploy = $false; release_promotion = $false
  }
  $written = Write-ImmutableEvidence $report; Write-Host "$script:Prefix status=verified candidate_bound=true auth=401 oversize=422 schema=422 policy=403 provider_calls=0 d1_readback=true redirects=false secret_output=false evidence_sha256=$($written.evidence_sha256) report=$($written.report_path)"
} catch { Write-Error "$script:Prefix status=blocked $($_.Exception.Message)"; throw } finally { Pop-Location }

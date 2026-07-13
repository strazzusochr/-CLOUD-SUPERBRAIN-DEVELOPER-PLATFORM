param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [string]$OutDir = ".codex\runs\CURRENT\orchestrator\completion-local"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) { throw "Orchestrator completion verification failed: $label" }
}
function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) { throw "Orchestrator completion verification failed: $label missing '$expected'" }
}
function Invoke-Text($url) { return (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 45).Content }
function Invoke-Json($url) { return (Invoke-Text $url) | ConvertFrom-Json }
function Get-Sha256($path) {
  $sha = [Security.Cryptography.SHA256]::Create()
  $stream = [IO.File]::OpenRead($path)
  try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace("-", "").ToLowerInvariant() }
  finally { $stream.Dispose(); $sha.Dispose() }
}
function Wait-JsonContains($label, $url, $expected, [int]$attempts = 30) {
  for ($attempt = 1; $attempt -le $attempts; $attempt++) {
    try {
      $value = Invoke-Text $url
      if ($value.Contains($expected)) { return $value | ConvertFrom-Json }
    } catch {
      if ($attempt -eq $attempts) { throw }
    }
    Start-Sleep -Seconds 1
  }
  throw "Orchestrator completion verification failed: $label missing '$expected' after $attempts attempts"
}
function Invoke-DryRun($projectId, $prompt, $sessionId) {
  $body = @{ project_id = $projectId; prompt = $prompt; session_id = $sessionId } | ConvertTo-Json -Compress
  return Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/v1/orchestrator/dry-run" -ContentType "application/json" -Body $body -TimeoutSec 120
}

$BaseUrl = $BaseUrl.TrimEnd("/")
$isLocalhost = $BaseUrl -match "^http://(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\])(:|/|$)"
if ($isLocalhost -and -not $AllowLocalhost) { throw "Localhost verification requires -AllowLocalhost and remains DEV-ONLY" }
if (($BaseUrl -notmatch "^https://") -and -not $AllowLocalhost) { throw "Non-HTTPS verification requires -AllowLocalhost" }
$repoRoot = Split-Path -Parent $PSScriptRoot
$artifactDir = if ([IO.Path]::IsPathRooted($OutDir)) { $OutDir } else { Join-Path $repoRoot $OutDir }
New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null

Write-Host "[orchestrator-completion] contract"
$contract = Invoke-Json "$BaseUrl/api/v1/orchestrator/completion/contract"
Assert-True "contract version" ($contract.contract_version -eq "orchestrator-completion-evidence-v1")
Assert-True "evidence ref" ($contract.evidence_ref -eq "orchestrator_completion_evidence_verified")
Assert-True "endpoint" ($contract.endpoint -eq "GET /api/v1/orchestrator/completion/contract")
Assert-True "layer identity" ($contract.layer_id -eq "layer_2" -and $contract.layer_label -eq "Orchestrator / LangGraph")
Assert-True "progress boundary" ([int]$contract.layer_progress_before_proof -eq 99 -and [int]$contract.layer_progress_after_proof -eq 100)
Assert-True "runtime identity" ($contract.engine -eq "langgraph" -and $contract.mode -eq "deterministic_dry_run" -and $contract.checkpointing -eq "postgres")
Assert-True "runtime evidence semantics" ($contract.scenario_semantics -eq "required_runtime_proofs_not_precomputed_results" -and $contract.runtime_evidence_required -eq $true)
Assert-True "five scenarios" ([int]$contract.scenario_count -eq 5 -and @($contract.scenarios).Count -eq 5)
Assert-True "four roles" ([int]$contract.required_success_role_count -eq 4 -and ((@($contract.required_success_roles) -join ",") -eq "planner,coder,tester,devops"))
Assert-True "retry ceiling" ([int]$contract.max_global_retries -eq 5)
Assert-True "closed live boundaries" ($contract.live_provider_calls -eq $false -and $contract.live_mcp_writes -eq $false -and $contract.production_deploy -eq $false -and $contract.secret_output -eq $false -and $contract.provider_write -eq $false)
Assert-True "browser proof" ($contract.browser_proof.route -eq "/diagnostics" -and $contract.browser_proof.label -eq "Orchestrator Completion Evidence" -and $contract.browser_proof.real_click_required -eq $true -and $contract.browser_proof.screenshot_required -eq $true)
foreach ($scenarioId in @("deterministic_success", "policy_hard_stop", "controlled_mcp_timeout", "postgres_checkpoint_and_audit_correlation", "parent_sse_replay_and_restart_recovery")) {
  Assert-True "scenario $scenarioId" ($null -ne (@($contract.scenarios) | Where-Object id -eq $scenarioId | Select-Object -First 1))
}
foreach ($method in @("POST", "PUT", "DELETE")) {
  $statusCode = curl.exe -sS -o NUL -w "%{http_code}" -X $method "$BaseUrl/api/v1/orchestrator/completion/contract"
  Assert-True "$method read-only boundary" ([string]$statusCode -eq "405")
}

Write-Host "[orchestrator-completion] source and parent-proof guards"
$api = Get-Content (Join-Path $repoRoot "services\agent-api\app\main.py") -Raw
$doc = Get-Content (Join-Path $repoRoot "docs\runtime-contracts\orchestrator-completion-evidence.md") -Raw
$diagnostics = Get-Content (Join-Path $repoRoot "apps\frontend\app\diagnostics\page.tsx") -Raw
$wiring = Get-Content (Join-Path $repoRoot "apps\frontend\lib\workspaceWiring.ts") -Raw
$e2e = Get-Content (Join-Path $repoRoot "apps\frontend\e2e\orchestrator-completion.spec.ts") -Raw
$runtimeVerifier = Get-Content (Join-Path $repoRoot "scripts\verify-phase1-runtime.ps1") -Raw
foreach ($required in @("ORCHESTRATOR_COMPLETION_EVIDENCE_CONTRACT_VERSION", "orchestrator_completion_evidence_contract_payload", "/api/v1/orchestrator/completion/contract")) { Assert-Contains "agent API" $api $required }
foreach ($required in @("orchestrator-completion-evidence-v1", "99%", "100%", "DEV-ONLY", "policy hard-stop", "MCP timeout", "PostgreSQL checkpoint")) { Assert-Contains "completion doc" $doc $required }
Assert-Contains "diagnostics option" $diagnostics "Orchestrator Completion Evidence"
Assert-Contains "diagnostics endpoint" $diagnostics "/api/v1/orchestrator/completion/contract"
Assert-Contains "workspace wiring" $wiring "/api/v1/orchestrator/completion/contract"
Assert-Contains "browser click test" $e2e "diagnostics loads orchestrator completion evidence through a real click"
Assert-Contains "browser screenshot" $e2e "diagnostics-orchestrator-completion-evidence.png"
foreach ($required in @("phase2_sse_event_contract_proof", "Last-Event-ID", "langgraph postgres checkpoint restart recovery", "post-recreate steady-state proof")) { Assert-Contains "parent runtime proof" $runtimeVerifier $required }

$manifest = Get-Content (Join-Path $repoRoot "docs\project-progress.manifest.json") -Raw | ConvertFrom-Json
$layer = @($manifest.vertical.items) | Where-Object id -eq "layer_2" | Select-Object -First 1
Assert-True "manifest orchestrator 100" ($null -ne $layer -and [int]$layer.percent -eq 100)
Assert-True "manifest overall remains evidence-weighted 84" ([int]$manifest.overall_percent -eq 84)
foreach ($marker in @("orchestrator_completion_evidence_verified", "orchestrator_completion_success_runtime_proof", "orchestrator_completion_policy_hard_stop_proof", "orchestrator_completion_mcp_timeout_proof", "orchestrator_completion_checkpoint_audit_proof", "orchestrator_completion_browser_click_proof")) { Assert-Contains "manifest marker" $layer.status $marker }

$projectId = "orchestrator-completion-" + [Guid]::NewGuid().ToString("N")
$successId = [Guid]::NewGuid().ToString()
Write-Host "[orchestrator-completion] deterministic four-role success"
$success = Invoke-DryRun $projectId "orchestrator completion deterministic dry run verifier" $successId
Assert-True "success terminal state" ($success.engine -eq "langgraph" -and $success.checkpointing -eq "postgres" -and $success.live_provider_calls -eq $false -and $success.state.node_name -eq "completed")
Assert-True "success no partial failure" ($success.state.result.partial_failure -eq $false)
Assert-True "success aggregation" ($success.state.result.verification_evidence -contains "agent_result_aggregation_complete")
foreach ($evidence in @("llm_gateway_dry_run", "llm_gateway_streaming_dry_run", "llm_routing_policy_primary_allowed", "memory_context_injected", "memory_update_persisted", "task_assignment_completed", "mcp_tool_success")) { Assert-True "success evidence $evidence" ($success.state.evidence_refs -contains $evidence) }
$successAssignments = @($success.state.task_assignments)
$successResults = @($success.state.agent_results)
$successMcp = @($success.state.mcp_tool_calls)
$successLlm = @($success.state.llm_gateway_calls)
$successSummaries = @($success.state.result.per_role_results)
Assert-True "success four-role envelope counts" ($successAssignments.Count -ge 4 -and $successResults.Count -ge 4 -and $successMcp.Count -ge 4 -and $successLlm.Count -ge 4 -and $successSummaries.Count -ge 4)
foreach ($role in @("planner", "coder", "tester", "devops")) {
  $assignment = $successAssignments | Where-Object agent_type -eq $role | Select-Object -First 1
  $result = $successResults | Where-Object owner_role -eq $role | Select-Object -First 1
  $mcp = $successMcp | Where-Object agent_role -eq $role | Select-Object -First 1
  $llm = $successLlm | Where-Object agent_type -eq $role | Select-Object -First 1
  $summary = $successSummaries | Where-Object role -eq $role | Select-Object -First 1
  Assert-True "$role completed" ($null -ne $assignment -and $assignment.status -eq "completed" -and $null -ne $result -and $null -ne $summary -and $summary.status -eq "completed")
  Assert-True "$role MCP safe" ($null -ne $mcp -and $mcp.status -eq "success" -and $mcp.audit_persisted -eq $true)
  Assert-True "$role LLM dry-run" ($null -ne $llm -and $llm.live_provider_calls -eq $false -and [int]$llm.cost_cents -eq 0 -and $llm.stream_done_seen -eq $true)
}
$successCheckpoint = Wait-JsonContains "success checkpoint" "$BaseUrl/api/v1/orchestrator/checkpoints/$successId" '"checkpointing":"postgres"'
Assert-True "success checkpoint state" ($successCheckpoint.checkpointing -eq "postgres" -and $successCheckpoint.snapshot.values.node_name -eq "completed")
$successAudit = Wait-JsonContains "success audit" "$BaseUrl/api/v1/audit/recent?limit=100" $successId
Assert-Contains "success completed audit" ($successAudit | ConvertTo-Json -Depth 12 -Compress) "langgraph_dry_run_completed"
$mcpAudit = Wait-JsonContains "success MCP audit" "$BaseUrl/api/v1/audit/mcp?limit=100" $successMcp[0].tool_request_id
Assert-Contains "success MCP event" ($mcpAudit | ConvertTo-Json -Depth 12 -Compress) "mcp_tool_executed"

$hardStopId = [Guid]::NewGuid().ToString()
Write-Host "[orchestrator-completion] policy hard-stop"
$hardStop = Invoke-DryRun $projectId "please production deploy and merge main" $hardStopId
Assert-True "hard-stop terminal" ($hardStop.engine -eq "langgraph" -and $hardStop.live_provider_calls -eq $false -and $hardStop.state.node_name -eq "hard_stop")
Assert-True "hard-stop reason" ($hardStop.state.hard_stop_reason -eq "policy_or_budget_guard_rejected")
Assert-True "hard-stop actions" ($hardStop.state.structured_intent.forbidden_actions_detected -contains "production deploy" -and $hardStop.state.structured_intent.forbidden_actions_detected -contains "merge main")
Assert-True "hard-stop no execution" (@($hardStop.state.task_assignments).Count -eq 0 -and @($hardStop.state.mcp_tool_calls).Count -eq 0)
$hardStopCheckpoint = Wait-JsonContains "hard-stop checkpoint" "$BaseUrl/api/v1/orchestrator/checkpoints/$hardStopId" '"node_name":"hard_stop"'
Assert-True "hard-stop persisted" ($hardStopCheckpoint.checkpointing -eq "postgres")
$hardStopAudit = Wait-JsonContains "hard-stop audit" "$BaseUrl/api/v1/audit/recent?limit=100" $hardStopId
Assert-Contains "hard-stop audit event" ($hardStopAudit | ConvertTo-Json -Depth 12 -Compress) "langgraph_dry_run_stopped"

$timeoutId = [Guid]::NewGuid().ToString()
Write-Host "[orchestrator-completion] controlled MCP timeout"
$timeout = Invoke-DryRun $projectId "force_mcp_tool_timeout:tester" $timeoutId
Assert-True "timeout terminal" ($timeout.state.node_name -eq "completed" -and $timeout.live_provider_calls -eq $false -and $timeout.state.result.partial_failure -eq $true)
foreach ($evidence in @("langgraph_mcp_timeout_controlled", "mcp_tool_controlled_error", "agent_result_aggregation_partial_failure_detected")) { Assert-True "timeout evidence $evidence" ($timeout.state.evidence_refs -contains $evidence) }
$timeoutCall = @($timeout.state.mcp_tool_calls) | Where-Object agent_role -eq "tester" | Select-Object -First 1
$timeoutSummary = @($timeout.state.result.per_role_results) | Where-Object role -eq "tester" | Select-Object -First 1
Assert-True "tester timeout call" ($null -ne $timeoutCall -and $timeoutCall.status -eq "timeout" -and $timeoutCall.capability -eq "simulate_timeout" -and $timeoutCall.evidence_ref -eq "mcp_timeout_guard" -and $timeoutCall.audit_persisted -eq $true)
Assert-True "tester timeout summary" ($null -ne $timeoutSummary -and $timeoutSummary.status -eq "partial_failure" -and $timeoutSummary.mcp_status -eq "timeout" -and $timeoutSummary.failure_reasons -contains "mcp_timeout")
$timeoutCheckpoint = Wait-JsonContains "timeout checkpoint" "$BaseUrl/api/v1/orchestrator/checkpoints/$timeoutId" '"node_name":"completed"'
Assert-True "timeout checkpoint persisted" ($timeoutCheckpoint.checkpointing -eq "postgres")
$timeoutAudit = Wait-JsonContains "timeout MCP audit" "$BaseUrl/api/v1/audit/mcp?limit=100" $timeoutCall.tool_request_id
Assert-Contains "timeout audit evidence" ($timeoutAudit | ConvertTo-Json -Depth 12 -Compress) "mcp_timeout_guard"

Write-Host "[orchestrator-completion] Chromium diagnostics click"
$oldBase = $env:ORCHESTRATOR_COMPLETION_BASE_URL
$oldDir = $env:ORCHESTRATOR_COMPLETION_ARTIFACT_DIR
$oldPlaywrightBase = $env:PHASE6_BASE_URL
try {
  $env:ORCHESTRATOR_COMPLETION_BASE_URL = $BaseUrl
  $env:ORCHESTRATOR_COMPLETION_ARTIFACT_DIR = $artifactDir
  $env:PHASE6_BASE_URL = $BaseUrl
  Push-Location (Join-Path $repoRoot "apps\frontend")
  try {
    npx playwright test --grep "diagnostics loads orchestrator completion evidence through a real click" --project=chromium --workers=1 --reporter=line
    if ($LASTEXITCODE -ne 0) { throw "Orchestrator completion Chromium proof failed" }
  } finally { Pop-Location }
} finally {
  $env:ORCHESTRATOR_COMPLETION_BASE_URL = $oldBase
  $env:ORCHESTRATOR_COMPLETION_ARTIFACT_DIR = $oldDir
  $env:PHASE6_BASE_URL = $oldPlaywrightBase
}
$screenshot = Join-Path $artifactDir "diagnostics-orchestrator-completion-evidence.png"
Assert-True "screenshot exists" (Test-Path $screenshot)
$screenshotBytes = (Get-Item $screenshot).Length
Assert-True "screenshot is substantive" ($screenshotBytes -gt 25000)

$sourceHashes = @{}
foreach ($relativePath in @("services\agent-api\app\main.py", "apps\frontend\app\diagnostics\page.tsx", "apps\frontend\e2e\orchestrator-completion.spec.ts", "scripts\verify-orchestrator-completion-evidence.ps1")) {
  $sourceHashes[$relativePath.Replace("\", "/")] = Get-Sha256 (Join-Path $repoRoot $relativePath)
}
$generatedAt = (Get-Date).ToUniversalTime().ToString("o")
$report = @{
  contract_version = "orchestrator-completion-evidence-v1"
  evidence_ref = "orchestrator_completion_evidence_verified"
  status = "verified"
  scope = if ($isLocalhost) { "DEV-ONLY" } else { "hosted_https" }
  scenarios = @{
    deterministic_success = @{ thread_id = $successId; terminal_node = $success.state.node_name; role_count = $successSummaries.Count; partial_failure = $false }
    policy_hard_stop = @{ thread_id = $hardStopId; terminal_node = $hardStop.state.node_name; reason = $hardStop.state.hard_stop_reason }
    controlled_mcp_timeout = @{ thread_id = $timeoutId; terminal_node = $timeout.state.node_name; partial_failure = $true; tester_mcp_status = $timeoutCall.status }
    postgres_checkpoint_and_audit_correlation = @{ verified = $true }
    parent_sse_replay_and_restart_recovery = @{ delegated_to_parent_runtime_verifier = $true; required_markers_verified = $true }
  }
  browser = @{ route = "/diagnostics"; real_click = $true; screenshot = "diagnostics-orchestrator-completion-evidence.png"; screenshot_bytes = $screenshotBytes }
  boundaries = @{ live_provider_calls = $false; live_mcp_writes = $false; production_deploy = $false; provider_write = $false; secret_output = $false }
  source_head = (git -C $repoRoot rev-parse HEAD).Trim()
  source_hashes = $sourceHashes
  generated_at = $generatedAt
}
$report | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $artifactDir "report.json") -Encoding utf8
@"
# Orchestrator Completion Evidence

- Status: verified
- Scope: $(if ($isLocalhost) { "DEV-ONLY" } else { "hosted_https" })
- Generated: $generatedAt
- Deterministic success roles: $($successSummaries.Count)
- Policy hard-stop: $($hardStop.state.hard_stop_reason)
- Controlled MCP timeout: $($timeoutCall.status), partial failure handled
- PostgreSQL checkpoint and audit correlation: verified
- Parent SSE replay and restart-recovery markers: verified; execution remains part of npm run verify:runtime
- Chromium diagnostics click: verified
- Screenshot bytes: $screenshotBytes
- Live provider calls: false
- Live MCP writes: false
- Production deploy: false

This is DEV-ONLY local completion evidence for the Orchestrator / LangGraph layer. It is not hosted staging, live-provider, or production proof.
"@ | Set-Content (Join-Path $artifactDir "report.md") -Encoding utf8
Write-Host "[orchestrator-completion] result=verified"
Write-Host "[orchestrator-completion] scope=$(if ($isLocalhost) { 'DEV-ONLY' } else { 'hosted_https' })"
Write-Host "[orchestrator-completion] screenshot_bytes=$screenshotBytes"

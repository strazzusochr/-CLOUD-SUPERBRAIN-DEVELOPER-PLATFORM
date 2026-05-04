param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [switch]$SeedMemoryConsolidation
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Browser contract verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Browser contract verification failed: $label"
  }
}

function Invoke-Text($url) {
  return curl.exe -sS $url
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ((-not $AllowLocalhost) -and ($BaseUrl -match "localhost|127\.0\.0\.1|\[::1\]")) {
  throw "Browser contract proof refuses localhost unless -AllowLocalhost is set"
}

Write-Host "[browser-contract] base url: $BaseUrl"

Write-Host "[browser-contract] frontend markers"
$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "frontend title" $frontendHtml "Cloud Superbrain"
Assert-Contains "langgraph progress panel" $frontendHtml "LangGraph Progress"
Assert-Contains "phase2 runtime button" $frontendHtml "Start Phase 2 Runtime"
Assert-Contains "phase2 runtime contract text" $frontendHtml "Phase 2 Runtime Contract"
Assert-Contains "phase2 runtime pending marker" $frontendHtml "Runtime Evidence"
Assert-Contains "phase2 runtime runs marker" $frontendHtml "Runtime Runs"
Assert-Contains "phase2 runtime status marker" $frontendHtml "Latest Runtime Status"
Assert-Contains "phase2 runtime role summaries marker" $frontendHtml "Role Summaries"
Assert-Contains "phase2 runtime sse contract marker" $frontendHtml "SSE Event Contract"
Assert-Contains "phase2 runtime sse evidence marker" $frontendHtml "phase2_sse_event_contract_proof"
Assert-Contains "phase2 runtime run status evidence marker" $frontendHtml "phase2_runtime_run_status_visible"
Assert-Contains "external gate mirror panel" $frontendHtml "External Gate Mirror"
Assert-Contains "external gate mirror evidence marker" $frontendHtml "external_gate_mirror_proof"
Assert-Contains "branch protection mirror marker" $frontendHtml "branch_protection_verify_contract"
Assert-Contains "cloud inventory panel" $frontendHtml "Cloud Inventory"
Assert-Contains "cloud inventory evidence marker" $frontendHtml "cloud_provider_inventory_visible"
Assert-Contains "cloud inventory endpoint marker" $frontendHtml "GET /api/v1/clouds"
Assert-Contains "cloud layer readiness panel" $frontendHtml "Cloud 7-Layer Readiness"
Assert-Contains "cloud layer readiness evidence marker" $frontendHtml "cloud_layer_readiness_visible"
Assert-Contains "cloud layer readiness endpoint marker" $frontendHtml "GET /api/v1/clouds/layers"
Assert-Contains "cloud render offload panel" $frontendHtml "Cloud Render Offload"
Assert-Contains "cloud render offload evidence marker" $frontendHtml "cloud_render_offload_contract_visible"
Assert-Contains "cloud render offload endpoint marker" $frontendHtml "GET /api/v1/clouds/render-offload/contract"
Assert-Contains "cloud deployment preflight panel" $frontendHtml "Cloud Deployment Preflight"
Assert-Contains "cloud deployment preflight evidence marker" $frontendHtml "cloud_deployment_preflight_visible"
Assert-Contains "cloud deployment preflight endpoint marker" $frontendHtml "GET /api/v1/clouds/deployment-preflight/contract"
Assert-Contains "layer interface contract panel" $frontendHtml "Layer Interface Contracts"
Assert-Contains "layer interface evidence marker" $frontendHtml "layer_interface_contracts_visible"
Assert-Contains "task assignment contract panel" $frontendHtml "Task Assignment Queue Contract"
Assert-Contains "task assignment evidence marker" $frontendHtml "task_assignment_queue_contract_visible"
Assert-Contains "task assignment priority routing marker" $frontendHtml "Priority Routing"
Assert-Contains "agent llm streaming contract panel" $frontendHtml "Agent LLM Streaming Contract"
Assert-Contains "agent llm streaming evidence marker" $frontendHtml "agent_llm_streaming_contract_visible"
Assert-Contains "mcp version pinning contract panel" $frontendHtml "MCP Version Pinning Contract"
Assert-Contains "mcp version pinning evidence marker" $frontendHtml "mcp_version_pinning_contract_visible"
Assert-Contains "memory embedding consistency contract panel" $frontendHtml "Memory Embedding Consistency Contract"
Assert-Contains "memory embedding consistency evidence marker" $frontendHtml "memory_embedding_consistency_contract_visible"
Assert-Contains "memory consolidation panel" $frontendHtml "Memory Consolidation"
Assert-Contains "memory consolidation refresh button" $frontendHtml "Refresh"
Assert-Contains "project progress panel" $frontendHtml "Project Progress"
Assert-Contains "project progress completion contract panel" $frontendHtml "100% Contract"
Assert-Contains "project progress completion evidence marker" $frontendHtml "project_progress_100_percent_gate_contract"
Assert-Contains "agent activity per-role summaries ui" $frontendHtml "Per-role Summaries"
Assert-Contains "agent activity per-role css" $frontendHtml "perRoleSummary"

Write-Host "[browser-contract] favicon"
$faviconStatus = curl.exe -sS -o NUL -w "%{http_code}" "$BaseUrl/favicon.ico"
Assert-True "favicon status 200" ($faviconStatus -eq "200")

Write-Host "[browser-contract] project progress"
$projectProgress = Invoke-Text "$BaseUrl/api/v1/project/progress"
Assert-Contains "project progress overall" $projectProgress '"overall_percent":47'
Assert-Contains "project progress phase2" $projectProgress '"id":"phase_2"'
Assert-Contains "project progress layer frontend" $projectProgress '"id":"layer_1"'
Assert-Contains "project progress worker status regression" $projectProgress "worker-status-regression-harness"

Write-Host "[browser-contract] project progress integrity"
$projectProgressIntegrity = Invoke-Text "$BaseUrl/api/v1/project/progress/integrity"
Assert-Contains "project progress integrity version" $projectProgressIntegrity '"contract_version":"project-progress-integrity-v1"'
Assert-Contains "project progress integrity verified" $projectProgressIntegrity '"status":"verified"'
Assert-Contains "project progress integrity evidence" $projectProgressIntegrity '"evidence_ref":"project_progress_integrity_runtime_proof"'
Assert-Contains "project progress integrity computed" $projectProgressIntegrity '"computed_overall_percent":47'
Assert-Contains "project progress integrity manifest" $projectProgressIntegrity '"manifest_overall_percent":47'

Write-Host "[browser-contract] project progress completion contract"
$projectProgressCompletion = Invoke-Text "$BaseUrl/api/v1/project/progress/completion"
Assert-Contains "project progress completion version" $projectProgressCompletion '"contract_version":"project-progress-100-percent-contract-v1"'
Assert-Contains "project progress completion status" $projectProgressCompletion '"status":"blocked_external_gates"'
Assert-Contains "project progress completion evidence" $projectProgressCompletion '"evidence_ref":"project_progress_100_percent_gate_contract"'
Assert-Contains "project progress completion cannot set all to 100" $projectProgressCompletion '"can_set_all_to_100":false'
Assert-Contains "project progress completion hosted blocker" $projectProgressCompletion "hosted_staging_proof_requires_STAGING_BASE_URL"
Assert-Contains "project progress completion production blocker" $projectProgressCompletion "production_release_requires_hosted_staging_branch_protection_secret_scan_and_owner_review"
Assert-Contains "project progress completion local gap blocker" $projectProgressCompletion "local_progress_gaps_require_verified_evidence_for_each_phase_and_layer"

Write-Host "[browser-contract] layer interface contracts"
$layerInterfaceContract = Invoke-Text "$BaseUrl/api/v1/layer-interfaces/contract"
Assert-Contains "layer interface contract version" $layerInterfaceContract '"contract_version":"layer-interface-contracts-v1"'
Assert-Contains "layer interface evidence" $layerInterfaceContract '"evidence_ref":"layer_interface_contracts_visible"'
Assert-Contains "layer interface l1" $layerInterfaceContract '"id":"L1-L2"'
Assert-Contains "layer interface mcp" $layerInterfaceContract '"id":"L2-L5"'
Assert-Contains "layer interface observability" $layerInterfaceContract '"id":"L7-OBS"'

Write-Host "[browser-contract] cloud provider inventory"
$cloudProviderInventory = Invoke-Text "$BaseUrl/api/v1/clouds"
Assert-Contains "cloud provider contract version" $cloudProviderInventory '"contract_version":"cloud-provider-inventory-v1"'
Assert-Contains "cloud provider evidence" $cloudProviderInventory '"evidence_ref":"cloud_provider_inventory_visible"'
Assert-Contains "cloud provider hetzner" $cloudProviderInventory '"id":"hetzner_cloud"'
Assert-Contains "cloud provider gitkraken" $cloudProviderInventory '"id":"gitkraken_identity"'
Assert-Contains "cloud provider seven layer mapping" $cloudProviderInventory '"seven_layer_mapping"'
$cloudLayerReadiness = Invoke-Text "$BaseUrl/api/v1/clouds/layers"
Assert-Contains "cloud layer readiness contract version" $cloudLayerReadiness '"contract_version":"cloud-layer-readiness-v1"'
Assert-Contains "cloud layer readiness evidence" $cloudLayerReadiness '"evidence_ref":"cloud_layer_readiness_visible"'
Assert-Contains "cloud layer readiness layer 7" $cloudLayerReadiness '"layer_id":"layer_7"'
Assert-Contains "cloud layer readiness gitkraken" $cloudLayerReadiness 'gitkraken_identity'
$cloudRenderOffload = Invoke-Text "$BaseUrl/api/v1/clouds/render-offload/contract"
Assert-Contains "cloud render offload version" $cloudRenderOffload '"contract_version":"cloud-render-offload-v1"'
Assert-Contains "cloud render offload evidence" $cloudRenderOffload '"evidence_ref":"cloud_render_offload_contract_visible"'
Assert-Contains "cloud render offload endpoint" $cloudRenderOffload '"endpoint":"GET /api/v1/clouds/render-offload/contract"'
Assert-Contains "cloud render offload local block" $cloudRenderOffload '"localhost_heavy_render_allowed":false'
Assert-Contains "cloud render offload staging blocker" $cloudRenderOffload "cloud_render_offload_requires_STAGING_BASE_URL"
$cloudDeploymentPreflight = Invoke-Text "$BaseUrl/api/v1/clouds/deployment-preflight/contract"
Assert-Contains "cloud deployment preflight version" $cloudDeploymentPreflight '"contract_version":"cloud-deployment-preflight-v1"'
Assert-Contains "cloud deployment preflight evidence" $cloudDeploymentPreflight '"evidence_ref":"cloud_deployment_preflight_visible"'
Assert-Contains "cloud deployment preflight endpoint" $cloudDeploymentPreflight '"endpoint":"GET /api/v1/clouds/deployment-preflight/contract"'
Assert-Contains "cloud deployment preflight status" $cloudDeploymentPreflight '"status":"action_required"'
Assert-Contains "cloud deployment preflight cloud claim blocked" $cloudDeploymentPreflight '"cloud_deploy_claim_allowed":false'
Assert-Contains "cloud deployment preflight production blocked" $cloudDeploymentPreflight '"production_deploy_claim_allowed":false'
Assert-Contains "cloud deployment preflight ghcr sequence" $cloudDeploymentPreflight "publish_ghcr_images"
Assert-Contains "cloud deployment preflight hosted origins" $cloudDeploymentPreflight "hosted_backend_origins"
Assert-Contains "cloud deployment preflight branch token" $cloudDeploymentPreflight "BRANCH_PROTECTION_TOKEN"
Assert-Contains "cloud deployment preflight cloud compose" $cloudDeploymentPreflight "docker-compose.cloud.yml"
Assert-Contains "cloud deployment preflight hosted staging blocker" $cloudDeploymentPreflight "hosted_staging_base_url_required"

Write-Host "[browser-contract] task assignment queue contract"
$taskAssignmentContract = Invoke-Text "$BaseUrl/api/v1/tasks/assignment-contract"
Assert-Contains "task assignment contract version" $taskAssignmentContract '"contract_version":"task-assignment-queue-contract-v1"'
Assert-Contains "task assignment evidence" $taskAssignmentContract '"evidence_ref":"task_assignment_queue_contract_visible"'
Assert-Contains "task assignment gap" $taskAssignmentContract '"audit_gap":"L-06"'
Assert-Contains "task assignment queue key" $taskAssignmentContract '"queue_key":"tasks:agent:queue"'
Assert-Contains "task assignment high priority queue" $taskAssignmentContract '"high":"tasks:agent:queue:high"'
Assert-Contains "task assignment low priority queue" $taskAssignmentContract '"low":"tasks:agent:queue:low"'
Assert-Contains "task assignment priority order" $taskAssignmentContract '"priority_order":["high","mid","low"]'
Assert-Contains "task assignment priority consumption" $taskAssignmentContract "high before mid before low"
Assert-Contains "task assignment status key" $taskAssignmentContract '"status_key_pattern":"task:status:{task_id}"'
Assert-Contains "task assignment backpressure" $taskAssignmentContract "stale_queue_rescue"

Write-Host "[browser-contract] agent llm streaming contract"
$agentLlmStreamingContract = Invoke-Text "$BaseUrl/api/v1/agents/llm-streaming-contract"
Assert-Contains "agent llm streaming version" $agentLlmStreamingContract '"contract_version":"agent-llm-streaming-contract-v1"'
Assert-Contains "agent llm streaming evidence" $agentLlmStreamingContract '"evidence_ref":"agent_llm_streaming_contract_visible"'
Assert-Contains "agent llm streaming gap" $agentLlmStreamingContract '"audit_gap":"L-07"'
Assert-Contains "agent llm streaming protocol" $agentLlmStreamingContract "openai_compatible_sse"
Assert-Contains "agent llm streaming done" $agentLlmStreamingContract "data: [DONE]"
Assert-Contains "agent llm streaming parser" $agentLlmStreamingContract "parse_llm_gateway_sse_line"
Assert-Contains "agent llm streaming state" $agentLlmStreamingContract "stream_done_seen"
Assert-Contains "agent llm streaming no live" $agentLlmStreamingContract "No live provider stream"

Write-Host "[browser-contract] mcp version pinning contract"
$mcpVersionPinningContract = Invoke-Text "$BaseUrl/mcp/api/v1/version-pinning/contract"
Assert-Contains "mcp version pinning contract version" $mcpVersionPinningContract '"contract_version":"mcp-version-pinning-v1"'
Assert-Contains "mcp version pinning evidence" $mcpVersionPinningContract '"evidence_ref":"mcp_version_pinning_contract_visible"'
Assert-Contains "mcp version pinning gap" $mcpVersionPinningContract '"audit_gap":"L-08"'
Assert-Contains "mcp version pinning fastapi" $mcpVersionPinningContract "fastapi==0.115.8"
Assert-Contains "mcp version pinning uvicorn" $mcpVersionPinningContract "uvicorn[standard]==0.34.0"
Assert-Contains "mcp version pinning pydantic" $mcpVersionPinningContract "pydantic==2.10.6"
Assert-Contains "mcp version pinning github contract" $mcpVersionPinningContract "github-branch-pr-plan-v1"
Assert-Contains "mcp version pinning e2b contract" $mcpVersionPinningContract "e2b-sandbox-lifecycle-v1"
Assert-Contains "mcp version pinning drift policy" $mcpVersionPinningContract "exact == pinning"
Assert-Contains "mcp version pinning no live write" $mcpVersionPinningContract "No live MCP write"

Write-Host "[browser-contract] memory embedding consistency contract"
$memoryEmbeddingConsistencyContract = Invoke-Text "$BaseUrl/api/v1/memory/embedding-consistency/contract"
Assert-Contains "memory embedding consistency version" $memoryEmbeddingConsistencyContract '"contract_version":"memory-embedding-consistency-v1"'
Assert-Contains "memory embedding consistency status" $memoryEmbeddingConsistencyContract '"status":"verified"'
Assert-Contains "memory embedding consistency evidence" $memoryEmbeddingConsistencyContract '"evidence_ref":"memory_embedding_consistency_contract_visible"'
Assert-Contains "memory embedding consistency gap" $memoryEmbeddingConsistencyContract '"audit_gap":"L-09"'
Assert-Contains "memory embedding consistency column" $memoryEmbeddingConsistencyContract '"embedding_model_version"'
Assert-Contains "memory embedding consistency vector" $memoryEmbeddingConsistencyContract "vector(1536)"
Assert-Contains "memory embedding consistency fallback" $memoryEmbeddingConsistencyContract "lexical_fallback"
Assert-Contains "memory embedding consistency no live provider" $memoryEmbeddingConsistencyContract "No live embedding provider call"

Write-Host "[browser-contract] phase2 runtime contract"
$runtimeContract = Invoke-Text "$BaseUrl/api/v1/phase2/runtime/contract"
Assert-Contains "runtime contract version" $runtimeContract '"contract_version":"phase2-runtime-v1"'
Assert-Contains "runtime start endpoint" $runtimeContract "POST /api/v1/phase2/runtime/start"
Assert-Contains "runtime stream endpoint" $runtimeContract "POST /api/v1/orchestrator/dry-run/stream"
Assert-Contains "runtime runs endpoint" $runtimeContract "GET /api/v1/phase2/runtime/runs"
Assert-Contains "runtime sse contract" $runtimeContract "phase2-sse-event-contract-v1"
Assert-Contains "runtime sse evidence" $runtimeContract "phase2_sse_event_contract_proof"
Assert-Contains "runtime sse heartbeat event" $runtimeContract "heartbeat"
Assert-Contains "runtime sse agent status event" $runtimeContract "agent_status"
Assert-Contains "runtime sse error event" $runtimeContract "error"
Assert-Contains "runtime sse done event" $runtimeContract "done"
Assert-Contains "runtime mcp timeout evidence" $runtimeContract "langgraph_mcp_timeout_controlled"
Assert-Contains "runtime no live provider calls" $runtimeContract '"live_provider_calls":false'
Assert-Contains "runtime postgres checkpointing" $runtimeContract '"checkpointing":"postgres"'

Write-Host "[browser-contract] external gate mirror"
$externalGates = Invoke-Text "$BaseUrl/api/v1/external-gates"
Assert-Contains "external gates contract" $externalGates '"contract_version":"external-gates-state-v1"'
Assert-Contains "external gates endpoint" $externalGates '"endpoint":"GET /api/v1/external-gates"'
Assert-Contains "external gates evidence" $externalGates '"evidence_ref":"external_gates_state_visible"'
Assert-Contains "external gates aligned with preflight" $externalGates '"aligned_with_deployment_preflight":true'
Assert-Contains "external gates blocked ghcr" $externalGates '"ghcr_images"'
Assert-Contains "external gates blocked hosted origins" $externalGates '"hosted_backend_origins"'
Assert-Contains "external gates branch alias" $externalGates '"preflight_gate_id":"branch_protection"'
Assert-Contains "external gates evidence alias" $externalGates '"evidence_ref":"ghcr_image_digest_proof"'
$externalGateMirror = Invoke-Text "$BaseUrl/api/v1/external-gates/mirror"
Assert-Contains "external gate mirror contract" $externalGateMirror '"contract_version":"external-gate-mirror-v1"'
Assert-Contains "external gate mirror status" $externalGateMirror '"status":"local_mirror_ready_hosted_blocked"'
Assert-Contains "external gate mirror evidence" $externalGateMirror '"evidence_ref":"external_gate_mirror_proof"'
Assert-Contains "external gate mirror hosted blocked" $externalGateMirror '"hosted_staging_claim_allowed":false'
Assert-Contains "external gate mirror branch protection blocked" $externalGateMirror '"branch_protection_claim_allowed":false'
Assert-Contains "external gate mirror branch protection evidence" $externalGateMirror '"branch_protection_evidence_ref":"branch_protection_verify_contract"'
Assert-Contains "external gate mirror branch protection workflow" $externalGateMirror ".github/workflows/branch-protection.yml"
Assert-Contains "external gate mirror branch protection verifier" $externalGateMirror "scripts/apply_github_branch_protection.py --verify-only"
Assert-Contains "external gate mirror production blocked" $externalGateMirror '"production_deploy_claim_allowed":false'
Assert-Contains "external gate mirror sse contract" $externalGateMirror "phase2-sse-event-contract-v1"
Assert-Contains "external gate mirror project progress proof" $externalGateMirror "project_progress_manifest_proof"

Write-Host "[browser-contract] phase2 runtime start"
$phase2RuntimeThreadId = "browser-contract-phase2-runtime-" + [Guid]::NewGuid().ToString("N")
$phase2RuntimeBody = @{
  project_id = "browser-contract-project"
  prompt = "browser contract phase2 runtime button proof"
  session_id = $phase2RuntimeThreadId
} | ConvertTo-Json -Compress
$phase2RuntimeRun = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/v1/phase2/runtime/start" -ContentType "application/json" -Body $phase2RuntimeBody
Assert-True "phase2 runtime status started" ($phase2RuntimeRun.status -eq "started")
Assert-True "phase2 runtime contract version" ($phase2RuntimeRun.contract_version -eq "phase2-runtime-v1")
Assert-True "phase2 runtime engine langgraph" ($phase2RuntimeRun.engine -eq "langgraph")
Assert-True "phase2 runtime no live provider calls" ($phase2RuntimeRun.live_provider_calls -eq $false)
Assert-True "phase2 runtime postgres checkpointing" ($phase2RuntimeRun.checkpointing -eq "postgres")
Assert-True "phase2 runtime completed node" ($phase2RuntimeRun.state.node_name -eq "completed")
Assert-True "phase2 runtime evidence ref" ($phase2RuntimeRun.state.evidence_refs -contains "phase2_runtime_graph_started")
$expectedAgentRoles = @("planner", "coder", "tester", "devops")
$runtimeAssignments = @($phase2RuntimeRun.state.task_assignments)
$runtimeAgentResults = @($phase2RuntimeRun.state.agent_results)
$runtimeMcpCalls = @($phase2RuntimeRun.state.mcp_tool_calls)
$runtimeLlmCalls = @($phase2RuntimeRun.state.llm_gateway_calls)
$runtimePerRoleResults = @($phase2RuntimeRun.state.result.per_role_results)
Assert-True "phase2 runtime assignment count" ($runtimeAssignments.Count -ge 4)
Assert-True "phase2 runtime agent result count" ($runtimeAgentResults.Count -ge 4)
Assert-True "phase2 runtime mcp call count" ($runtimeMcpCalls.Count -ge 4)
Assert-True "phase2 runtime llm call count" ($runtimeLlmCalls.Count -ge 4)
Assert-True "phase2 runtime per-role result count" ($runtimePerRoleResults.Count -ge 4)
Assert-True "phase2 runtime aggregation complete" ($phase2RuntimeRun.state.result.partial_failure -eq $false)
Assert-True "phase2 runtime aggregation evidence" ($phase2RuntimeRun.state.result.verification_evidence -contains "agent_result_aggregation_complete")
foreach ($role in $expectedAgentRoles) {
  $assignment = $runtimeAssignments | Where-Object { $_.agent_type -eq $role } | Select-Object -First 1
  Assert-True "phase2 runtime assignment for $role" ($null -ne $assignment)
  Assert-True "phase2 runtime assignment completed for $role" ($assignment.status -eq "completed")
  Assert-True "phase2 runtime done validation logged for $role" ($assignment.done_validation.logged -eq $true)
  Assert-True "phase2 runtime push_main block for $role" ($assignment.blocked_actions -contains "push_main")
  $agentResult = $runtimeAgentResults | Where-Object { $_.owner_role -eq $role } | Select-Object -First 1
  Assert-True "phase2 runtime agent result for $role" ($null -ne $agentResult)
  Assert-True "phase2 runtime role evidence for $role" ($agentResult.verification_evidence -contains "agent_role_$($role)_executed")
  $mcpCall = $runtimeMcpCalls | Where-Object { $_.agent_role -eq $role } | Select-Object -First 1
  Assert-True "phase2 runtime mcp call for $role" ($null -ne $mcpCall)
  Assert-True "phase2 runtime mcp success for $role" ($mcpCall.status -eq "success")
  $roleSummary = $runtimePerRoleResults | Where-Object { $_.role -eq $role } | Select-Object -First 1
  Assert-True "phase2 runtime per-role summary for $role" ($null -ne $roleSummary)
  Assert-True "phase2 runtime per-role summary completed for $role" ($roleSummary.status -eq "completed")
  Assert-True "phase2 runtime per-role mcp success for $role" ($roleSummary.mcp_status -eq "success")
  Assert-True "phase2 runtime per-role evidence for $role" ($roleSummary.mcp_evidence_ref)
}
$runtimeCheckpoint = Invoke-Text "$BaseUrl/api/v1/orchestrator/checkpoints/$($phase2RuntimeRun.thread_id)"
Assert-Contains "phase2 runtime checkpoint evidence" $runtimeCheckpoint "phase2_runtime_graph_started"
$runtimeAudit = Invoke-Text "$BaseUrl/api/v1/audit/recent?limit=60"
Assert-Contains "phase2 runtime audit evidence" $runtimeAudit "phase2_runtime_graph_started"
Assert-Contains "phase2 runtime audit contract" $runtimeAudit "phase2-runtime-v1"
$agentActivityRecent = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/v1/agent-activity/recent?event_type=phase2_runtime_graph_started&limit=20"
$agentActivityRuntimeEvent = @($agentActivityRecent.events) | Where-Object { $_.trace_id -eq $phase2RuntimeRun.thread_id -or $_.session_id -eq $phase2RuntimeRun.thread_id } | Select-Object -First 1
Assert-True "agent activity runtime event visible" ($null -ne $agentActivityRuntimeEvent)
Assert-True "agent activity per-role count visible" ($agentActivityRuntimeEvent.role_summary_count -ge 4)
Assert-True "agent activity partial failure false" ($agentActivityRuntimeEvent.partial_failure -eq $false)
Assert-True "agent activity aggregation evidence visible" ($agentActivityRuntimeEvent.aggregation_evidence_ref -eq "agent_result_aggregation_complete")
foreach ($role in $expectedAgentRoles) {
  $activityRoleSummary = @($agentActivityRuntimeEvent.per_role_results) | Where-Object { $_.role -eq $role } | Select-Object -First 1
  Assert-True "agent activity per-role summary for $role" ($null -ne $activityRoleSummary)
  Assert-True "agent activity per-role completed for $role" ($activityRoleSummary.status -eq "completed")
}
$phase2RuntimeRuns = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/v1/phase2/runtime/runs?limit=10"
Assert-True "phase2 runtime runs contract version" ($phase2RuntimeRuns.contract_version -eq "phase2-runtime-v1")
Assert-True "phase2 runtime runs evidence ref" ($phase2RuntimeRuns.evidence_ref -eq "phase2_runtime_run_status_visible")
$phase2RuntimeRunStatus = @($phase2RuntimeRuns.runs) | Where-Object { $_.thread_id -eq $phase2RuntimeRun.thread_id -or $_.session_id -eq $phase2RuntimeRun.thread_id } | Select-Object -First 1
Assert-True "phase2 runtime run status visible" ($null -ne $phase2RuntimeRunStatus)
Assert-True "phase2 runtime run status completed" ($phase2RuntimeRunStatus.status -eq "completed")
Assert-True "phase2 runtime run status role summaries" ($phase2RuntimeRunStatus.role_summary_count -ge 4)
Assert-True "phase2 runtime run status aggregation evidence" ($phase2RuntimeRunStatus.aggregation_evidence_ref -eq "agent_result_aggregation_complete")
Assert-True "phase2 runtime run status no live provider calls" ($phase2RuntimeRunStatus.live_provider_calls -eq $false)
Assert-True "phase2 runtime run status no live mcp writes" ($phase2RuntimeRunStatus.live_mcp_writes -eq $false)
Assert-True "phase2 runtime run status no production deploy" ($phase2RuntimeRunStatus.production_deploy -eq $false)

Write-Host "[browser-contract] session history opens"
$sessionHistory = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/v1/sessions/$($phase2RuntimeRun.thread_id)/history"
Assert-True "session history contract version" ($sessionHistory.contract_version -eq "session-history-v1")
Assert-True "session history evidence ref" ($sessionHistory.evidence_ref -eq "session_history_openable_project_state")
Assert-True "session history session id" ($sessionHistory.session.session_id -eq $phase2RuntimeRun.thread_id)
Assert-True "session history messages visible" (@($sessionHistory.messages).Count -ge 4)
Assert-True "session history tasks visible" (@($sessionHistory.tasks).Count -ge 4)
Assert-True "session history audit events visible" (@($sessionHistory.audit_events).Count -ge 4)
Assert-True "session history project progress visible" ($sessionHistory.project_progress.overall_percent -eq 47)
Assert-True "session history integrity verified" ($sessionHistory.project_progress_integrity.status -eq "verified")
Assert-True "session history integrity evidence" ($sessionHistory.project_progress_integrity.evidence_ref -eq "project_progress_integrity_runtime_proof")

if ($SeedMemoryConsolidation) {
  Write-Host "[browser-contract] seed memory consolidation"
  $memoryNeedle = "browser contract memory consolidation " + [Guid]::NewGuid().ToString("N")
  $memoryIdempotencyKey = "browser-contract-memory-consolidation-" + [Guid]::NewGuid().ToString("N")
  $seedOutput = docker exec cloud-superbrain-phase1-dev-agent-api-1 python -c "import json, os, redis; client=redis.Redis.from_url(os.environ['REDIS_URL']); payload={'project_id':'browser-contract-project','session_id':'$($phase2RuntimeRun.thread_id)','content_text':'$memoryNeedle','metadata':{'source':'browser_contract_harness'},'idempotency_key':'$memoryIdempotencyKey'}; client.set('memory:working:$memoryIdempotencyKey', json.dumps(payload), ex=300); print(client.ttl('memory:working:$memoryIdempotencyKey'))"
  Assert-Contains "seeded working memory ttl" $seedOutput "300"
  $consolidationRun = docker exec cloud-superbrain-phase1-dev-memory-worker-1 python -m app.worker --once
  if (-not (($consolidationRun | Out-String).Contains('"consolidated": 1'))) {
    Write-Host "[browser-contract] memory-worker one-shot did not claim the key; checking public feed because daemon may have consumed it first"
  }
  $consolidationFeed = Invoke-Text "$BaseUrl/api/v1/memory/consolidation/recent?limit=20"
  Assert-Contains "memory consolidation feed event" $consolidationFeed "memory_consolidated"
  Assert-Contains "memory consolidation feed idempotency" $consolidationFeed $memoryIdempotencyKey
  Assert-Contains "memory consolidation feed redis key" $consolidationFeed "memory:working:$memoryIdempotencyKey"
} else {
  Write-Host "[browser-contract] memory consolidation feed shape"
  $consolidationFeed = Invoke-Text "$BaseUrl/api/v1/memory/consolidation/recent?limit=8"
  Assert-Contains "memory consolidation feed shape" $consolidationFeed '"events"'
  Assert-Contains "memory consolidation summary shape" $consolidationFeed '"summary"'
}

Write-Host "[browser-contract] checks completed"

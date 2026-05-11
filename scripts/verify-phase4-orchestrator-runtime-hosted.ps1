param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase4 hosted orchestrator-runtime verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted orchestrator-runtime verification failed: $label"
  }
}

function Invoke-Text($url) {
  $python = @'
import sys
import urllib.request

with urllib.request.urlopen(sys.argv[1], timeout=20) as response:
    sys.stdout.write(response.read().decode("utf-8", errors="replace"))
'@
  return ($python | py -3 - $url)
}

function Invoke-JsonApi(
  [string]$Url,
  [string]$Method = "GET",
  [string]$Body = "",
  [string]$ContentType = "application/json",
  [int]$TimeoutSeconds = 20
) {
  $payload = [ordered]@{
    url = $Url
    method = $Method
    timeout_seconds = $TimeoutSeconds
  }
  if ($Body) {
    $payload.body_b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Body))
  }
  if ($ContentType) {
    $payload.content_type = $ContentType
  }
  $payloadJson = $payload | ConvertTo-Json -Compress -Depth 8
  $payloadFile = Join-Path $env:TEMP ("phase4-orchestrator-runtime-" + [Guid]::NewGuid().ToString("N") + ".json")
  $pythonFile = Join-Path $env:TEMP ("phase4-orchestrator-runtime-" + [Guid]::NewGuid().ToString("N") + ".py")
  try {
    Set-Content -LiteralPath $payloadFile -Value $payloadJson -NoNewline -Encoding utf8
    $pythonScript = @'
import base64
import json
import sys
import urllib.error
import urllib.request

with open(sys.argv[1], "r", encoding="utf-8-sig") as handle:
    payload = json.load(handle)

data = None
if payload.get("body_b64"):
    data = base64.b64decode(payload["body_b64"])

headers = {}
if payload.get("content_type"):
    headers["Content-Type"] = payload["content_type"]

request = urllib.request.Request(
    payload["url"],
    data=data,
    headers=headers,
    method=payload.get("method", "GET"),
)

try:
    with urllib.request.urlopen(request, timeout=payload.get("timeout_seconds", 20)) as response:
        print(response.read().decode("utf-8"))
except urllib.error.HTTPError as exc:
    print(exc.read().decode("utf-8"))
    sys.exit(exc.code)
'@
    Set-Content -LiteralPath $pythonFile -Value $pythonScript -NoNewline -Encoding utf8
    $output = py -3 $pythonFile $payloadFile 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
      throw $output.Trim()
    }
    return ($output | ConvertFrom-Json)
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
    if (Test-Path $pythonFile) { Remove-Item -LiteralPath $pythonFile -Force }
  }
}

function Wait-UrlContains($label, $url, $expected, $attempts = 45) {
  $last = ""
  for ($i = 0; $i -lt $attempts; $i++) {
    try {
      $response = Invoke-Text $url
      $last = $response
      if (($response | Out-String).Contains($expected)) {
        return $response
      }
    } catch {
      $last = $_.Exception.Message
    }
    Start-Sleep -Seconds 1
  }
  throw "Phase4 hosted orchestrator-runtime verification failed: $label did not contain '$expected'. Value: $last"
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") {
  throw "Phase4 hosted orchestrator-runtime proof requires HTTPS"
}

$projectId = "hosted-phase4-runtime-" + [Guid]::NewGuid().ToString("N")
$sessionId = [Guid]::NewGuid().ToString()
$expectedAgentRoles = @("planner", "coder", "tester", "devops")
$expectedPriorities = @{ planner = 9; coder = 5; tester = 5; devops = 8 }

Write-Host "[phase4-hosted-orchestrator-runtime] base url: $BaseUrl"

$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "frontend langgraph progress panel" $frontendHtml "LangGraph Progress"
Assert-Contains "frontend phase2 runtime contract panel" $frontendHtml "Phase 2 Runtime Contract"
Assert-Contains "frontend task assignment panel" $frontendHtml "Task Assignment Queue Contract"
Assert-Contains "frontend agent llm streaming panel" $frontendHtml "Agent LLM Streaming Contract"
Assert-Contains "frontend memory embedding contract panel" $frontendHtml "Memory Embedding Consistency Contract"

$orchestratorManifest = Invoke-Text "$BaseUrl/api/v1/orchestrator/manifest"
Assert-Contains "orchestrator manifest engine" $orchestratorManifest '"engine":"langgraph"'
Assert-Contains "orchestrator manifest no live calls" $orchestratorManifest '"live_provider_calls":false'
Assert-Contains "orchestrator manifest checkpointing" $orchestratorManifest '"checkpointing":"postgres"'

$orchestratorBody = @{
  project_id = $projectId
  prompt = "hosted phase4 orchestrator runtime parity verifier"
  session_id = $sessionId
} | ConvertTo-Json -Compress
$orchestratorRun = Invoke-JsonApi -Url "$BaseUrl/api/v1/orchestrator/dry-run" -Method "POST" -Body $orchestratorBody -ContentType "application/json"

Assert-True "orchestrator dry-run engine langgraph" ($orchestratorRun.engine -eq "langgraph")
Assert-True "orchestrator dry-run no live provider calls" ($orchestratorRun.live_provider_calls -eq $false)
Assert-True "orchestrator dry-run checkpointing postgres" ($orchestratorRun.checkpointing -eq "postgres")
Assert-True "orchestrator dry-run completed" ($orchestratorRun.state.node_name -eq "completed")
foreach ($evidence in @("llm_gateway_dry_run", "llm_gateway_streaming_dry_run", "llm_routing_policy_primary_allowed", "memory_context_injected", "memory_update_persisted", "task_assignment_completed", "mcp_tool_success")) {
  Assert-True "orchestrator evidence $evidence" (@($orchestratorRun.state.evidence_refs) -contains $evidence)
}

$assignments = @($orchestratorRun.state.task_assignments)
$agentResults = @($orchestratorRun.state.agent_results)
$mcpCalls = @($orchestratorRun.state.mcp_tool_calls)
$llmCalls = @($orchestratorRun.state.llm_gateway_calls)
$perRoleResults = @($orchestratorRun.state.result.per_role_results)

Assert-True "orchestrator assignments count >= 4" ($assignments.Count -ge 4)
Assert-True "orchestrator agent results count >= 4" ($agentResults.Count -ge 4)
Assert-True "orchestrator mcp calls count >= 4" ($mcpCalls.Count -ge 4)
Assert-True "orchestrator llm calls count >= 4" ($llmCalls.Count -ge 4)
Assert-True "orchestrator per-role results count >= 4" ($perRoleResults.Count -ge 4)
Assert-True "orchestrator no partial failure" ($orchestratorRun.state.result.partial_failure -eq $false)
Assert-True "orchestrator aggregation evidence" (@($orchestratorRun.state.result.verification_evidence) -contains "agent_result_aggregation_complete")

foreach ($role in $expectedAgentRoles) {
  $assignment = $assignments | Where-Object { $_.agent_type -eq $role } | Select-Object -First 1
  Assert-True "assignment exists for $role" ($null -ne $assignment)
  Assert-True "assignment completed for $role" ($assignment.status -eq "completed")
  Assert-True "assignment priority for $role" ([int]$assignment.priority -eq [int]$expectedPriorities[$role])
  if ($role -in @("planner", "devops")) {
    Assert-True "manager high priority level for $role" ($assignment.priority_level -eq "high")
    Assert-True "manager high queue for $role" ($assignment.priority_queue -like "*:high")
  }
  Assert-True "done validation logged for $role" ($assignment.done_validation.logged -eq $true)
  Assert-True "push_main blocked for $role" (@($assignment.blocked_actions) -contains "push_main")

  $agentResult = $agentResults | Where-Object { $_.owner_role -eq $role } | Select-Object -First 1
  Assert-True "agent result exists for $role" ($null -ne $agentResult)
  Assert-True "agent result evidence exists for $role" (@($agentResult.verification_evidence) -contains "agent_role_$($role)_executed")

  $mcpCallForRole = $mcpCalls | Where-Object { $_.agent_role -eq $role } | Select-Object -First 1
  Assert-True "mcp call exists for $role" ($null -ne $mcpCallForRole)
  Assert-True "mcp call success for $role" ($mcpCallForRole.status -eq "success")

  $roleSummary = $perRoleResults | Where-Object { $_.role -eq $role } | Select-Object -First 1
  Assert-True "per-role summary exists for $role" ($null -ne $roleSummary)
  Assert-True "per-role summary completed for $role" ($roleSummary.status -eq "completed")
  Assert-True "per-role mcp success for $role" ($roleSummary.mcp_status -eq "success")
  Assert-True "per-role mcp evidence ref exists for $role" (-not [string]::IsNullOrWhiteSpace($roleSummary.mcp_evidence_ref))
}

$plannerMcpCall = $mcpCalls[0]
Assert-True "planner MCP contract" ($plannerMcpCall.contract -eq "McpToolRequest")
Assert-True "planner MCP toolset postgresql" ($plannerMcpCall.toolset -eq "postgresql")
Assert-True "planner MCP evidence readonly plan" ($plannerMcpCall.evidence_ref -eq "postgresql_readonly_query_plan")
Assert-True "planner MCP audit persisted" ($plannerMcpCall.audit_persisted -eq $true)
Assert-True "planner MCP allowed scope readonly" ($plannerMcpCall.allowed_scope -eq "project-context-readonly")

Assert-True "memory update id exists" (-not [string]::IsNullOrWhiteSpace($orchestratorRun.state.memory_update_id))
Assert-True "memory context budget max 30" ($orchestratorRun.state.memory_context_budget.budget_percent_max -eq 30)
Assert-True "memory context search mode lexical fallback" ($orchestratorRun.state.memory_context_budget.search_mode -eq "lexical_fallback")
Assert-True "memory context selected count non-negative" ($orchestratorRun.state.memory_context_budget.selected_count -ge 0)
Assert-True "memory context tokens within budget" ($orchestratorRun.state.memory_context_budget.used_tokens -le $orchestratorRun.state.memory_context_budget.budget_tokens)

$llmCall = $llmCalls[0]
Assert-True "llm no live providers" ($llmCall.live_provider_calls -eq $false)
Assert-True "llm zero cost" ($llmCall.cost_cents -eq 0)
Assert-True "llm audit persisted" ($llmCall.audit_persisted -eq $true)
Assert-True "llm streaming used" ($llmCall.streaming_used -eq $true)
Assert-True "llm streaming protocol" ($llmCall.streaming_protocol -eq "openai_compatible_sse")
Assert-True "llm stream done seen" ($llmCall.stream_done_seen -eq $true)
Assert-True "llm stream chunk count >= 1" ($llmCall.stream_chunk_count -ge 1)
Assert-True "llm memory context budget max 30" ($llmCall.memory_context_budget.budget_percent_max -eq 30)
Assert-True "llm memory context search mode lexical fallback" ($llmCall.memory_context_budget.search_mode -eq "lexical_fallback")
Assert-True "llm memory context count non-negative" ($llmCall.memory_context_count -ge 0)
Assert-True "llm selected model" ($llmCall.routing.selected_model -eq "deepseek-ai/DeepSeek-V4-Pro:fastest")
Assert-True "llm selected provider" ($llmCall.routing.selected_provider -eq "huggingface_inference_router")
Assert-True "llm routing no live provider" ($llmCall.routing.live_provider_calls -eq $false)
Assert-True "llm routing live-verifiable" ($llmCall.routing.configured_only -eq $false)
Assert-True "llm provider health live verified" ($llmCall.routing.provider_health.status -eq "live_verified")
Assert-True "llm routing policy checked" ($llmCall.routing_policy_checked -eq $true)
Assert-True "llm routing policy contract version" ($llmCall.routing_policy_contract_version -eq "llm-routing-policy-v1")
Assert-True "llm routing policy decision allow primary" ($llmCall.routing_policy_decision -eq "allow_primary")
Assert-True "llm routing policy evidence primary allowed" ($llmCall.routing_policy_evidence_ref -eq "llm_routing_policy_primary_allowed")
Assert-True "llm routing policy no live providers" ($llmCall.routing_policy.live_provider_calls -eq $false)

$orchestratorLlmAudit = Invoke-Text "$BaseUrl/api/v1/audit/recent?limit=40"
Assert-Contains "orchestrator llm audit event" $orchestratorLlmAudit "llm_gateway_request"
Assert-Contains "orchestrator llm audit trace" $orchestratorLlmAudit $llmCall.trace_id

$memoryUpdateQuery = [uri]::EscapeDataString("langgraph memory update")
$memorySearch = Invoke-Text "$BaseUrl/api/v1/memory/search?q=$memoryUpdateQuery&project_id=$projectId&limit=10"
Assert-Contains "memory update persisted id" $memorySearch $orchestratorRun.state.memory_update_id
Assert-Contains "memory update persisted text" $memorySearch "langgraph memory update"

$assignedTaskId = $assignments[0].task_id
$recentTasks = Invoke-Text "$BaseUrl/api/v1/tasks/recent?limit=20"
Assert-Contains "assigned task visible" $recentTasks $assignedTaskId
Assert-Contains "assigned task completed" $recentTasks '"status":"completed"'

$mcpAudit = Invoke-Text "$BaseUrl/api/v1/audit/mcp?limit=100"
Assert-Contains "mcp audit executed event" $mcpAudit "mcp_tool_executed"
Assert-Contains "mcp audit request id" $mcpAudit $plannerMcpCall.tool_request_id
Assert-Contains "mcp audit readonly evidence" $mcpAudit "postgresql_readonly_query_plan"
Assert-Contains "mcp audit session bound" $mcpAudit '"session_bound":true'
Assert-Contains "mcp audit session id" $mcpAudit $orchestratorRun.thread_id
Assert-Contains "mcp audit trace evidence" $mcpAudit "mcp_tool_session_bound_audit"

$phase2RuntimeContract = Invoke-Text "$BaseUrl/api/v1/phase2/runtime/contract"
Assert-Contains "phase2 runtime contract version" $phase2RuntimeContract '"contract_version":"phase2-runtime-v1"'
Assert-Contains "phase2 runtime start endpoint" $phase2RuntimeContract "POST /api/v1/phase2/runtime/start"
Assert-Contains "phase2 runtime stream endpoint" $phase2RuntimeContract "POST /api/v1/orchestrator/dry-run/stream"
Assert-Contains "phase2 runtime runs endpoint" $phase2RuntimeContract "GET /api/v1/phase2/runtime/runs"
Assert-Contains "phase2 runtime sse contract" $phase2RuntimeContract "phase2-sse-event-contract-v1"
Assert-Contains "phase2 runtime sse evidence" $phase2RuntimeContract "phase2_sse_event_contract_proof"
Assert-Contains "phase2 runtime no live providers" $phase2RuntimeContract '"live_provider_calls":false'

$phase2ThreadId = [Guid]::NewGuid().ToString()
$phase2Body = @{
  project_id = $projectId
  prompt = "hosted phase4 phase2 runtime parity verifier"
  session_id = $phase2ThreadId
} | ConvertTo-Json -Compress
$phase2Run = Invoke-JsonApi -Url "$BaseUrl/api/v1/phase2/runtime/start" -Method "POST" -Body $phase2Body -ContentType "application/json"

Assert-True "phase2 runtime contract version" ($phase2Run.contract_version -eq "phase2-runtime-v1")
Assert-True "phase2 runtime started" ($phase2Run.status -eq "started")
Assert-True "phase2 runtime engine langgraph" ($phase2Run.engine -eq "langgraph")
Assert-True "phase2 runtime deterministic local" ($phase2Run.mode -eq "deterministic_local_runtime")
Assert-True "phase2 runtime no live providers" ($phase2Run.live_provider_calls -eq $false)
Assert-True "phase2 runtime no live mcp writes" ($phase2Run.live_mcp_writes -eq $false)
Assert-True "phase2 runtime no production deploy" ($phase2Run.production_deploy -eq $false)
Assert-True "phase2 runtime checkpointing postgres" ($phase2Run.checkpointing -eq "postgres")
Assert-True "phase2 runtime completed" ($phase2Run.state.node_name -eq "completed")
Assert-True "phase2 runtime start evidence" (@($phase2Run.state.evidence_refs) -contains "phase2_runtime_graph_started")
Assert-True "phase2 runtime memory evidence" (@($phase2Run.state.evidence_refs) -contains "memory_update_persisted")
Assert-True "phase2 runtime no partial failure" ($phase2Run.state.result.partial_failure -eq $false)
Assert-True "phase2 runtime aggregation evidence" (@($phase2Run.state.result.verification_evidence) -contains "agent_result_aggregation_complete")

$phase2PerRoleResults = @($phase2Run.state.result.per_role_results)
Assert-True "phase2 runtime per-role count >= 4" ($phase2PerRoleResults.Count -ge 4)
foreach ($role in $expectedAgentRoles) {
  $roleSummary = $phase2PerRoleResults | Where-Object { $_.role -eq $role } | Select-Object -First 1
  Assert-True "phase2 role summary exists for $role" ($null -ne $roleSummary)
  Assert-True "phase2 role summary completed for $role" ($roleSummary.status -eq "completed")
  Assert-True "phase2 role summary mcp success for $role" ($roleSummary.mcp_status -eq "success")
}

$phase2Checkpoint = Wait-UrlContains "phase2 checkpoint" "$BaseUrl/api/v1/orchestrator/checkpoints/$($phase2Run.thread_id)" "phase2_runtime_graph_started" 45
Assert-Contains "phase2 checkpoint evidence" $phase2Checkpoint "phase2_runtime_graph_started"

$phase2Audit = Invoke-Text "$BaseUrl/api/v1/audit/recent?limit=40"
Assert-Contains "phase2 audit evidence" $phase2Audit "phase2_runtime_graph_started"
Assert-Contains "phase2 audit contract" $phase2Audit "phase2-runtime-v1"

$phase2AgentActivity = Invoke-JsonApi -Url "$BaseUrl/api/v1/agent-activity/recent?event_type=phase2_runtime_graph_started&limit=20" -Method "GET" -ContentType ""
$phase2Event = @($phase2AgentActivity.events) | Where-Object { $_.trace_id -eq $phase2Run.thread_id -or $_.session_id -eq $phase2Run.thread_id } | Select-Object -First 1
Assert-True "phase2 agent activity event exists" ($null -ne $phase2Event)
Assert-True "phase2 agent activity role summary count >= 4" ($phase2Event.role_summary_count -ge 4)
Assert-True "phase2 agent activity no partial failure" ($phase2Event.partial_failure -eq $false)
Assert-True "phase2 agent activity aggregation evidence" ($phase2Event.aggregation_evidence_ref -eq "agent_result_aggregation_complete")
foreach ($role in $expectedAgentRoles) {
  $roleSummary = @($phase2Event.per_role_results) | Where-Object { $_.role -eq $role } | Select-Object -First 1
  Assert-True "phase2 activity role summary exists for $role" ($null -ne $roleSummary)
  Assert-True "phase2 activity role summary completed for $role" ($roleSummary.status -eq "completed")
}

$phase2Runs = Invoke-JsonApi -Url "$BaseUrl/api/v1/phase2/runtime/runs?limit=10" -Method "GET" -ContentType ""
Assert-True "phase2 runs contract version" ($phase2Runs.contract_version -eq "phase2-runtime-v1")
Assert-True "phase2 runs evidence ref" ($phase2Runs.evidence_ref -eq "phase2_runtime_run_status_visible")
$phase2RunStatus = @($phase2Runs.runs) | Where-Object { $_.thread_id -eq $phase2Run.thread_id -or $_.session_id -eq $phase2Run.thread_id } | Select-Object -First 1
Assert-True "phase2 run status exists" ($null -ne $phase2RunStatus)
Assert-True "phase2 run status completed" ($phase2RunStatus.status -eq "completed")
Assert-True "phase2 run status role summary count >= 4" ($phase2RunStatus.role_summary_count -ge 4)
Assert-True "phase2 run status no partial failure" ($phase2RunStatus.partial_failure -eq $false)
Assert-True "phase2 run status aggregation evidence" ($phase2RunStatus.aggregation_evidence_ref -eq "agent_result_aggregation_complete")
Assert-True "phase2 run status no live providers" ($phase2RunStatus.live_provider_calls -eq $false)
Assert-True "phase2 run status no live mcp writes" ($phase2RunStatus.live_mcp_writes -eq $false)
Assert-True "phase2 run status no production deploy" ($phase2RunStatus.production_deploy -eq $false)

Write-Host "[phase4-hosted-orchestrator-runtime] checks completed"

$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "require-docker-readiness.ps1") -GateName "phase1-runtime compose verification"

$port = if ($env:NGINX_HTTP_PORT) { $env:NGINX_HTTP_PORT } else { "8081" }
$baseUrl = "http://localhost:$port"
$progressManifestPath = Join-Path $PSScriptRoot "..\docs\project-progress.manifest.json"
$progressManifest = Get-Content -Path $progressManifestPath -Raw | ConvertFrom-Json
$expectedOverallPercent = [int]$progressManifest.overall_percent

function Assert-LastExitCode($label) {
  if ($LASTEXITCODE -ne 0) {
    throw "Runtime verification failed: $label"
  }
}

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Runtime verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Wait-UrlContains($label, $url, $expected, $attempts = 30) {
  $last = ""
  for ($i = 0; $i -lt $attempts; $i++) {
    $previousErrorActionPreference = $ErrorActionPreference
    $previousNativeErrorPreference = $PSNativeCommandUseErrorActionPreference
    $ErrorActionPreference = "Continue"
    $PSNativeCommandUseErrorActionPreference = $false
    try {
      $response = curl.exe -sS $url 2>&1
      $curlExitCode = $LASTEXITCODE
    } finally {
      $PSNativeCommandUseErrorActionPreference = $previousNativeErrorPreference
      $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($curlExitCode -eq 0) {
      $last = $response
      if (($last | Out-String).Contains($expected)) {
        return $last
      }
    } else {
      $last = "curl exit code $curlExitCode while waiting for $url"
    }
    Start-Sleep -Seconds 1
  }
  throw "Runtime verification failed: $label did not contain '$expected' after $attempts attempts. Value: $last"
}

function Wait-SseContains($label, $url, $expected, $attempts = 4, $maxTime = 8, $lastEventId = $null) {
  $last = ""
  for ($i = 0; $i -lt $attempts; $i++) {
    $previousErrorActionPreference = $ErrorActionPreference
    $previousNativeErrorPreference = $PSNativeCommandUseErrorActionPreference
    $ErrorActionPreference = "Continue"
    $PSNativeCommandUseErrorActionPreference = $false
    try {
      if ($lastEventId) {
        $response = curl.exe -sN --max-time $maxTime -H "Last-Event-ID: $lastEventId" $url 2>&1
      } else {
        $response = curl.exe -sN --max-time $maxTime $url 2>&1
      }
      $curlExitCode = $LASTEXITCODE
    } finally {
      $PSNativeCommandUseErrorActionPreference = $previousNativeErrorPreference
      $ErrorActionPreference = $previousErrorActionPreference
    }
    $text = ($response | Out-String)
    if ($text.Contains($expected)) {
      return $response
    }
    if ($curlExitCode -eq 0) {
      $last = $text
    } else {
      $last = "curl exit code $curlExitCode while waiting for SSE $url. Output: $text"
    }
    Start-Sleep -Seconds 1
  }
  throw "Runtime verification failed: $label did not contain '$expected' after $attempts SSE attempts. Value: $last"
}

function Wait-TaskCompleted($taskId) {
  for ($i = 0; $i -lt 45; $i++) {
    $taskStatus = docker exec cloud-superbrain-phase1-dev-agent-api-1 python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/api/v1/internal/tasks/$taskId', timeout=5).read().decode())"
    if (($taskStatus | Out-String).Contains('"status":"completed"')) {
      return $taskStatus
    }
    if (($taskStatus | Out-String).Contains('"status":"failed"')) {
      throw "Runtime verification failed: task $taskId failed. Value: $taskStatus"
    }
    Start-Sleep -Seconds 1
  }
  throw "Runtime verification failed: task $taskId was not completed in time after Redis/worker reconnect window"
}

function Wait-TaskEscalated($taskId) {
  $last = ""
  for ($i = 0; $i -lt 90; $i++) {
    $taskStatus = docker exec cloud-superbrain-phase1-dev-agent-api-1 python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/api/v1/internal/tasks/$taskId', timeout=5).read().decode())" 2>&1
    $last = ($taskStatus | Out-String)
    if (($taskStatus | Out-String).Contains('"status":"escalated"')) {
      return $taskStatus
    }
    Start-Sleep -Seconds 1
  }
  throw "Runtime verification failed: task $taskId was not escalated in time after Redis/worker reconnect window. Value: $last"
}

Write-Host "[runtime] compose status"
docker compose -f docker-compose.dev.yml ps
Assert-LastExitCode "compose status"

Write-Host "[runtime] compose resource measurement"
$resourceReport = powershell -ExecutionPolicy Bypass -File scripts\measure-compose-resources.ps1 -JsonOnly
Assert-Contains "resource report project" $resourceReport '"project":"cloud-superbrain-phase1-dev"'
Assert-Contains "resource report upgrade rule" $resourceReport "No Hetzner upgrade without empirical CPU/RAM pressure"
Assert-Contains "resource report agent-api" $resourceReport '"service":"agent-api"'
Assert-Contains "resource report container count" $resourceReport '"container_count":9'
Assert-Contains "resource report agent worker" $resourceReport '"service":"agent-worker"'
Assert-Contains "resource report memory worker" $resourceReport '"service":"memory-worker"'
Assert-Contains "resource report llm gateway" $resourceReport '"service":"llm-gateway"'
Assert-Contains "resource report nginx" $resourceReport '"service":"nginx"'
Assert-Contains "resource report postgres" $resourceReport '"service":"postgres"'

Write-Host "[runtime] postgres backup proof"
$backupProof = powershell -ExecutionPolicy Bypass -File scripts\backup-postgres-phase1.ps1 -OutputDir ".phase1-artifacts\postgres-backups"
Assert-Contains "postgres backup schema mode" $backupProof '"mode":"schema"'
Assert-Contains "postgres backup schema-only" $backupProof '"schema_only":true'
Assert-Contains "postgres backup memory table" $backupProof "memory_entries"
Assert-Contains "postgres backup pgvector" $backupProof "vector"
Assert-Contains "postgres backup checkpoint tables" $backupProof '"checkpoint_tables":4'
Assert-Contains "postgres backup no secrets" $backupProof '"no_secret_material":true'

Write-Host "[runtime] postgres restore proof"
$restoreProof = powershell -ExecutionPolicy Bypass -File scripts\restore-postgres-phase1-proof.ps1 -OutputDir ".phase1-artifacts\postgres-backups"
Assert-Contains "postgres restore schema only" $restoreProof '"schema_only":true'
Assert-Contains "postgres restore app tables" $restoreProof '"restored_required_tables":6'
Assert-Contains "postgres restore checkpoint tables" $restoreProof '"restored_checkpoint_tables":4'
Assert-Contains "postgres restore pgvector" $restoreProof "vector"
Assert-Contains "postgres restore cleanup" $restoreProof '"cleanup_status":"dropped"'
Assert-Contains "postgres restore isolated temp db" $restoreProof '"isolated_temp_database":true'
Assert-Contains "postgres restore no prod mutation" $restoreProof '"no_production_database_mutation":true'

Write-Host "[runtime] redis persistence proof"
$redisProof = powershell -ExecutionPolicy Bypass -File scripts\verify-redis-persistence-phase1.ps1
Assert-Contains "redis persistence appendonly" $redisProof '"appendonly_enabled":true'
Assert-Contains "redis persistence recreate" $redisProof '"forced_container_recreate":true'
Assert-Contains "redis persistence value restored" $redisProof '"restored_value_matches":true'
Assert-Contains "redis persistence cleanup" $redisProof '"cleanup_status":"key_deleted"'
Assert-Contains "redis persistence no secrets" $redisProof '"no_secret_material":true'

Write-Host "[runtime] app containers non-root"
$appContainers = @(
  "cloud-superbrain-phase1-dev-agent-api-1",
  "cloud-superbrain-phase1-dev-agent-worker-1",
  "cloud-superbrain-phase1-dev-memory-worker-1",
  "cloud-superbrain-phase1-dev-mcp-gateway-1",
  "cloud-superbrain-phase1-dev-llm-gateway-1",
  "cloud-superbrain-phase1-dev-nginx-1"
)
foreach ($container in $appContainers) {
  $configuredUser = docker inspect $container --format "{{.Config.User}}"
  if ([string]::IsNullOrWhiteSpace($configuredUser) -or $configuredUser -eq "root" -or $configuredUser -eq "0") {
    throw "Runtime verification failed: $container is not configured with a non-root user"
  }
  $idOutput = docker exec $container id
  if (($idOutput | Out-String).Contains("uid=0(")) {
    throw "Runtime verification failed: $container is running as root. Value: $idOutput"
  }
}

Write-Host "[runtime] app containers security hardening"
foreach ($container in $appContainers) {
  $privileged = docker inspect $container --format "{{.HostConfig.Privileged}}"
  if ($privileged -ne "false") {
    throw "Runtime verification failed: $container is privileged"
  }
  $readOnlyRootfs = docker inspect $container --format "{{.HostConfig.ReadonlyRootfs}}"
  if ($readOnlyRootfs -ne "true") {
    throw "Runtime verification failed: $container root filesystem is not read-only"
  }
  $capDrop = docker inspect $container --format "{{json .HostConfig.CapDrop}}"
  if (-not (($capDrop | Out-String).Contains('"ALL"'))) {
    throw "Runtime verification failed: $container does not drop all Linux capabilities. Value: $capDrop"
  }
  $securityOpt = docker inspect $container --format "{{json .HostConfig.SecurityOpt}}"
  if (-not (($securityOpt | Out-String).Contains("no-new-privileges:true"))) {
    throw "Runtime verification failed: $container does not enforce no-new-privileges. Value: $securityOpt"
  }
}

Write-Host "[runtime] refresh nginx upstream resolution"
$env:NGINX_HTTP_PORT = $port
docker compose -f docker-compose.dev.yml up -d --force-recreate nginx
Assert-LastExitCode "refresh nginx upstream resolution"

Write-Host "[runtime] nginx health"
$nginxHealth = Wait-UrlContains "nginx health" "$baseUrl/health" "ok"

Write-Host "[runtime] frontend root"
$frontendStatus = curl.exe -sS -o NUL -w "%{http_code}" "$baseUrl/"
if ($frontendStatus -ne "200") {
  throw "Runtime verification failed: frontend root returned HTTP $frontendStatus"
}

Write-Host "[runtime] frontend content"
$frontendHtml = curl.exe -sS "$baseUrl/"
Assert-Contains "frontend title" $frontendHtml "Cloud Superbrain"
Assert-Contains "frontend project field" $frontendHtml "Project"
Assert-Contains "frontend stream panel" $frontendHtml "Stream"
Assert-Contains "frontend memory panel" $frontendHtml "Memory"
Assert-Contains "frontend recent runs panel" $frontendHtml "Recent Runs"
Assert-Contains "frontend audit panel" $frontendHtml "Audit"
Assert-Contains "frontend mcp audit panel" $frontendHtml "MCP Audit"
Assert-Contains "frontend agent activity per-role summaries" $frontendHtml "Per-role Summaries"
Assert-Contains "frontend agent activity per-role css" $frontendHtml "perRoleSummary"
Assert-Contains "frontend memory consolidation panel" $frontendHtml "Memory Consolidation"
Assert-Contains "frontend project progress panel" $frontendHtml "Project Progress"
Assert-Contains "frontend project progress completion contract" $frontendHtml "100% Contract"
Assert-Contains "frontend project progress completion evidence" $frontendHtml "project_progress_100_percent_gate_contract"
Assert-Contains "frontend cost monitor panel" $frontendHtml "Cost Monitor"
Assert-Contains "frontend cost export contract visible" $frontendHtml "CSV Export"
Assert-Contains "frontend cost export evidence" $frontendHtml "cost_export_csv_generated"
Assert-Contains "frontend rate limit guard panel" $frontendHtml "Rate Limit Guard"
Assert-Contains "frontend rate limit guard evidence" $frontendHtml "rate_limit_429_enforced"
Assert-Contains "frontend session limit guard panel" $frontendHtml "Session Limit Guard"
Assert-Contains "frontend session limit guard evidence" $frontendHtml "session_limit_429_enforced"
Assert-Contains "frontend prompt input guard" $frontendHtml "Prompt Input Guard"
Assert-Contains "frontend prompt input counter evidence" $frontendHtml "prompt_input_counter_visible"
Assert-Contains "frontend error response contract panel" $frontendHtml "Error Response Contract"
Assert-Contains "frontend error response ui evidence" $frontendHtml "error_response_ui_state_visible"
Assert-Contains "frontend security headers contract panel" $frontendHtml "Security Headers Contract"
Assert-Contains "frontend security headers evidence" $frontendHtml "security_headers_ui_visible"
Assert-Contains "frontend trace id contract panel" $frontendHtml "Trace ID Contract"
Assert-Contains "frontend trace id evidence" $frontendHtml "trace_id_ui_visible"
Assert-Contains "frontend cache control contract panel" $frontendHtml "Cache Control Contract"
Assert-Contains "frontend cache control evidence" $frontendHtml "cache_control_ui_visible"
Assert-Contains "frontend request id contract panel" $frontendHtml "Request ID Contract"
Assert-Contains "frontend request id evidence" $frontendHtml "request_id_ui_visible"
Assert-Contains "frontend request id audit feed evidence" $frontendHtml "request_id_audit_feed_visible"
Assert-Contains "frontend audit request id visible" $frontendHtml "Request ID:"
Assert-Contains "frontend layer interface contract panel" $frontendHtml "Layer Interface Contracts"
Assert-Contains "frontend layer interface evidence" $frontendHtml "layer_interface_contracts_visible"
Assert-Contains "frontend infra budget panel" $frontendHtml "Infra Budget"
Assert-Contains "frontend cloud inventory panel" $frontendHtml "Cloud Inventory"
Assert-Contains "frontend cloud inventory endpoint" $frontendHtml "GET /api/v1/clouds"
Assert-Contains "frontend cloud inventory evidence" $frontendHtml "cloud_provider_inventory_visible"
Assert-Contains "frontend cloud seven layer panel" $frontendHtml "Cloud 7-Layer Readiness"
Assert-Contains "frontend cloud layer endpoint" $frontendHtml "GET /api/v1/clouds/layers"
Assert-Contains "frontend cloud layer evidence" $frontendHtml "cloud_layer_readiness_visible"
Assert-Contains "frontend cloud render offload panel" $frontendHtml "Cloud Render Offload"
Assert-Contains "frontend cloud render offload endpoint" $frontendHtml "GET /api/v1/clouds/render-offload/contract"
Assert-Contains "frontend cloud render offload evidence" $frontendHtml "cloud_render_offload_contract_visible"
Assert-Contains "frontend cloud deployment preflight panel" $frontendHtml "Cloud Deployment Preflight"
Assert-Contains "frontend cloud deployment preflight endpoint" $frontendHtml "GET /api/v1/clouds/deployment-preflight/contract"
Assert-Contains "frontend cloud deployment preflight evidence" $frontendHtml "cloud_deployment_preflight_visible"
Assert-Contains "frontend external gates panel" $frontendHtml "External Gates"
Assert-Contains "frontend auth contract panel" $frontendHtml "Auth Contract"
Assert-Contains "frontend memory purge contract panel" $frontendHtml "Memory Purge Contract"
Assert-Contains "frontend devops workflow dispatch panel" $frontendHtml "DevOps Workflow Dispatch"
Assert-Contains "frontend github branch pr contract panel" $frontendHtml "GitHub Branch/PR Contract"
Assert-Contains "frontend postgresql readonly query contract panel" $frontendHtml "PostgreSQL Readonly Query Contract"
Assert-Contains "frontend filesystem workspace scope contract panel" $frontendHtml "Filesystem Workspace Scope Contract"
Assert-Contains "frontend playwright browser proof contract panel" $frontendHtml "Playwright Browser Proof Contract"
Assert-Contains "frontend e2b sandbox lifecycle contract panel" $frontendHtml "E2B Sandbox Lifecycle Contract"
Assert-Contains "frontend mcp version pinning contract panel" $frontendHtml "MCP Version Pinning Contract"
Assert-Contains "frontend mcp version pinning evidence" $frontendHtml "mcp_version_pinning_contract_visible"
Assert-Contains "frontend memory embedding consistency contract panel" $frontendHtml "Memory Embedding Consistency Contract"
Assert-Contains "frontend memory embedding consistency evidence" $frontendHtml "memory_embedding_consistency_contract_visible"
Assert-Contains "frontend system health panel" $frontendHtml "System Health"
Assert-Contains "frontend system fallback panel" $frontendHtml "System Unavailable Fallback"
Assert-Contains "frontend system fallback evidence" $frontendHtml "system_unavailable_ui_state"
Assert-Contains "frontend agent activity panel" $frontendHtml "Agent Activity"
Assert-Contains "frontend agent activity evidence" $frontendHtml "agent_activity_trace_link_template"
Assert-Contains "frontend agent activity filtered feed" $frontendHtml "agent_activity_filtered_feed_visible"
Assert-Contains "frontend agent activity filters" $frontendHtml "activityFilterBar"
Assert-Contains "frontend task queue panel" $frontendHtml "Task Queue"
Assert-Contains "frontend done validation panel" $frontendHtml "Done Validation"
Assert-Contains "frontend task policy panel" $frontendHtml "Task Policy Gate"
Assert-Contains "frontend task assignment contract panel" $frontendHtml "Task Assignment Queue Contract"
Assert-Contains "frontend task assignment evidence" $frontendHtml "task_assignment_queue_contract_visible"
Assert-Contains "frontend task assignment priority routing" $frontendHtml "Priority Routing"
Assert-Contains "frontend agent llm streaming contract panel" $frontendHtml "Agent LLM Streaming Contract"
Assert-Contains "frontend agent llm streaming evidence" $frontendHtml "agent_llm_streaming_contract_visible"
Assert-Contains "frontend escalations panel" $frontendHtml "Escalations"
Assert-Contains "frontend rotation events panel" $frontendHtml "Rotation Events"
Assert-Contains "frontend model matrix panel" $frontendHtml "Model Matrix"
Assert-Contains "frontend llm gateway panel" $frontendHtml "LLM Gateway"
Assert-Contains "frontend llm routing resolver" $frontendHtml "Routing Resolver"
Assert-Contains "frontend llm provider health" $frontendHtml "Provider Health"
Assert-Contains "frontend llm streaming contract" $frontendHtml "Streaming Contract"
Assert-Contains "frontend llm routing policy" $frontendHtml "Routing Policy"
Assert-Contains "frontend llm routing policy evidence" $frontendHtml "llm_routing_policy_contract_visible"
Assert-Contains "frontend langgraph progress panel" $frontendHtml "LangGraph Progress"

Write-Host "[runtime] agent-api health"
$apiHealth = Wait-UrlContains "agent-api health" "$baseUrl/api/v1/health" '"status":"healthy"'
Assert-Contains "agent-api postgres health" $apiHealth '"postgres":{"status":"healthy"'
Assert-Contains "agent-api required tables" $apiHealth '"required_tables":6'
Assert-Contains "agent-api checkpoint tables" $apiHealth '"checkpoint_tables":4'
Assert-Contains "agent-api budget" $apiHealth '"allow_new_calls":true'
Assert-Contains "agent-api redis health" $apiHealth '"redis":{"status":"healthy"'
Assert-Contains "agent-api agent worker health" $apiHealth '"agent_worker":{"status":"healthy"'
Assert-Contains "agent-api memory worker health" $apiHealth '"memory_worker":{"status":"healthy"'
Assert-Contains "agent-api mcp health matrix" $apiHealth '"mcp_gateway":{"status":"healthy"'
Assert-Contains "agent-api llm gateway health matrix" $apiHealth '"llm_gateway":{"status":"healthy"'

Write-Host "[runtime] project progress"
$projectProgress = curl.exe -sS "$baseUrl/api/v1/project/progress"
Assert-Contains "project progress overall" $projectProgress ('"overall_percent":{0}' -f $expectedOverallPercent)
Assert-Contains "project progress source" $projectProgress '"progress_source":"docs/project-progress.manifest.json"'
Assert-Contains "project progress horizontal" $projectProgress '"horizontal"'
Assert-Contains "project progress vertical" $projectProgress '"vertical"'
Assert-Contains "project progress truth policy" $projectProgress "Evidence-based only"
Assert-Contains "project progress worker status regression" $projectProgress "worker-status-regression-harness"

Write-Host "[runtime] project progress integrity"
$projectProgressIntegrity = curl.exe -sS "$baseUrl/api/v1/project/progress/integrity"
Assert-Contains "project progress integrity version" $projectProgressIntegrity '"contract_version":"project-progress-integrity-v1"'
Assert-Contains "project progress integrity verified" $projectProgressIntegrity '"status":"verified"'
Assert-Contains "project progress integrity evidence" $projectProgressIntegrity '"evidence_ref":"project_progress_integrity_runtime_proof"'
Assert-Contains "project progress integrity computed" $projectProgressIntegrity ('"computed_overall_percent":{0}' -f $expectedOverallPercent)
Assert-Contains "project progress integrity manifest" $projectProgressIntegrity ('"manifest_overall_percent":{0}' -f $expectedOverallPercent)

Write-Host "[runtime] project progress completion contract"
$projectProgressCompletion = curl.exe -sS "$baseUrl/api/v1/project/progress/completion"
Assert-Contains "project progress completion version" $projectProgressCompletion '"contract_version":"project-progress-100-percent-contract-v1"'
Assert-Contains "project progress completion status" $projectProgressCompletion '"status":"blocked_external_gates"'
Assert-Contains "project progress completion evidence" $projectProgressCompletion '"evidence_ref":"project_progress_100_percent_gate_contract"'
Assert-Contains "project progress completion cannot set all to 100" $projectProgressCompletion '"can_set_all_to_100":false'
Assert-Contains "project progress completion external gates cleared" $projectProgressCompletion '"missing_external_gates":[]'
Assert-Contains "project progress completion local gap blocker" $projectProgressCompletion "local_progress_gaps_require_verified_evidence_for_each_phase_and_layer"

Write-Host "[runtime] layer interface contracts"
$layerInterfaceContract = curl.exe -sS "$baseUrl/api/v1/layer-interfaces/contract"
Assert-Contains "layer interface contract version" $layerInterfaceContract '"contract_version":"layer-interface-contracts-v1"'
Assert-Contains "layer interface evidence" $layerInterfaceContract '"evidence_ref":"layer_interface_contracts_visible"'
Assert-Contains "layer interface l1" $layerInterfaceContract '"id":"L1-L2"'
Assert-Contains "layer interface mcp" $layerInterfaceContract '"id":"L2-L5"'
Assert-Contains "layer interface observability" $layerInterfaceContract '"id":"L7-OBS"'
Assert-Contains "layer interface request schema" $layerInterfaceContract '"request_schema":'
Assert-Contains "layer interface response schema" $layerInterfaceContract '"response_schema":'

Write-Host "[runtime] cloud provider inventory"
$cloudProviderInventory = curl.exe -sS "$baseUrl/api/v1/clouds"
Assert-Contains "cloud provider contract version" $cloudProviderInventory '"contract_version":"cloud-provider-inventory-v1"'
Assert-Contains "cloud provider evidence" $cloudProviderInventory '"evidence_ref":"cloud_provider_inventory_visible"'
Assert-Contains "cloud provider endpoint" $cloudProviderInventory '"endpoint":"GET /api/v1/clouds"'
Assert-Contains "cloud provider hetzner" $cloudProviderInventory '"id":"hetzner_cloud"'
Assert-Contains "cloud provider gitkraken" $cloudProviderInventory '"id":"gitkraken_identity"'
Assert-Contains "cloud provider seven layer mapping" $cloudProviderInventory '"seven_layer_mapping"'
$cloudLayerReadiness = curl.exe -sS "$baseUrl/api/v1/clouds/layers"
Assert-Contains "cloud layer readiness contract version" $cloudLayerReadiness '"contract_version":"cloud-layer-readiness-v1"'
Assert-Contains "cloud layer readiness evidence" $cloudLayerReadiness '"evidence_ref":"cloud_layer_readiness_visible"'
Assert-Contains "cloud layer readiness endpoint" $cloudLayerReadiness '"endpoint":"GET /api/v1/clouds/layers"'
Assert-Contains "cloud layer readiness layer 7" $cloudLayerReadiness '"layer_id":"layer_7"'
Assert-Contains "cloud layer readiness gitkraken" $cloudLayerReadiness 'gitkraken_identity'
$cloudRenderOffloadContract = curl.exe -sS "$baseUrl/api/v1/clouds/render-offload/contract"
Assert-Contains "cloud render offload contract version" $cloudRenderOffloadContract '"contract_version":"cloud-render-offload-surface-v1"'
Assert-Contains "cloud render offload contract evidence" $cloudRenderOffloadContract '"evidence_ref":"cloud_render_offload_contract_runtime_visible"'
Assert-Contains "cloud render offload contract endpoint" $cloudRenderOffloadContract '"endpoint":"GET /api/v1/clouds/render-offload/contract"'
Assert-Contains "cloud render offload runtime endpoint" $cloudRenderOffloadContract '"runtime_endpoint":"GET /api/v1/clouds/render-offload"'
$cloudRenderOffloadRuntime = curl.exe -sS "$baseUrl/api/v1/clouds/render-offload"
Assert-Contains "cloud render offload runtime version" $cloudRenderOffloadRuntime '"contract_version":"cloud-render-offload-v1"'
Assert-Contains "cloud render offload runtime evidence" $cloudRenderOffloadRuntime '"evidence_ref":"cloud_render_offload_contract_visible"'
Assert-Contains "cloud render offload local block" $cloudRenderOffloadRuntime '"localhost_heavy_render_allowed":false'
Assert-Contains "cloud render offload staging blocker" $cloudRenderOffloadRuntime "cloud_render_offload_requires_STAGING_BASE_URL"
$cloudDeploymentPreflightContract = curl.exe -sS "$baseUrl/api/v1/clouds/deployment-preflight/contract"
Assert-Contains "cloud deployment preflight contract version" $cloudDeploymentPreflightContract '"contract_version":"cloud-deployment-preflight-surface-v1"'
Assert-Contains "cloud deployment preflight contract evidence" $cloudDeploymentPreflightContract '"evidence_ref":"cloud_deployment_preflight_contract_runtime_visible"'
Assert-Contains "cloud deployment preflight contract endpoint" $cloudDeploymentPreflightContract '"endpoint":"GET /api/v1/clouds/deployment-preflight/contract"'
Assert-Contains "cloud deployment preflight runtime endpoint" $cloudDeploymentPreflightContract '"runtime_endpoint":"GET /api/v1/clouds/deployment-preflight"'
$cloudDeploymentPreflightRuntime = curl.exe -sS "$baseUrl/api/v1/clouds/deployment-preflight"
Assert-Contains "cloud deployment preflight runtime version" $cloudDeploymentPreflightRuntime '"contract_version":"cloud-deployment-preflight-v1"'
Assert-Contains "cloud deployment preflight runtime evidence" $cloudDeploymentPreflightRuntime '"evidence_ref":"cloud_deployment_preflight_visible"'
Assert-Contains "cloud deployment preflight status" $cloudDeploymentPreflightRuntime '"status":"verified"'
Assert-Contains "cloud deployment preflight cloud claim allowed" $cloudDeploymentPreflightRuntime '"cloud_deploy_claim_allowed":true'
Assert-Contains "cloud deployment preflight production allowed" $cloudDeploymentPreflightRuntime '"production_deploy_claim_allowed":true'
Assert-Contains "cloud deployment preflight no blocked gates" $cloudDeploymentPreflightRuntime '"missing_or_blocked_gates":[]'
Assert-Contains "cloud deployment preflight ghcr sequence" $cloudDeploymentPreflightRuntime "publish_ghcr_images"
Assert-Contains "cloud deployment preflight hosted origins" $cloudDeploymentPreflightRuntime "hosted_backend_origins"
Assert-Contains "cloud deployment preflight branch token" $cloudDeploymentPreflightRuntime "BRANCH_PROTECTION_TOKEN"
Assert-Contains "cloud deployment preflight secret scan" $cloudDeploymentPreflightRuntime "canonical_secret_scan"

Write-Host "[runtime] task assignment queue contract"
$taskAssignmentContract = curl.exe -sS "$baseUrl/api/v1/tasks/assignment-contract"
Assert-Contains "task assignment contract version" $taskAssignmentContract '"contract_version":"task-assignment-queue-contract-v1"'
Assert-Contains "task assignment contract evidence" $taskAssignmentContract '"evidence_ref":"task_assignment_queue_contract_visible"'
Assert-Contains "task assignment gap" $taskAssignmentContract '"audit_gap":"L-06"'
Assert-Contains "task assignment intake" $taskAssignmentContract '"/api/v1/internal/tasks"'
Assert-Contains "task assignment queue key" $taskAssignmentContract '"queue_key":"tasks:agent:queue"'
Assert-Contains "task assignment high priority queue" $taskAssignmentContract '"high":"tasks:agent:queue:high"'
Assert-Contains "task assignment mid priority queue" $taskAssignmentContract '"mid":"tasks:agent:queue"'
Assert-Contains "task assignment low priority queue" $taskAssignmentContract '"low":"tasks:agent:queue:low"'
Assert-Contains "task assignment priority order" $taskAssignmentContract '"priority_order":["high","mid","low"]'
Assert-Contains "task assignment priority consumption" $taskAssignmentContract "high before mid before low"
Assert-Contains "task assignment status key" $taskAssignmentContract '"status_key_pattern":"task:status:{task_id}"'
Assert-Contains "task assignment uuid guard" $taskAssignmentContract "session_id"
Assert-Contains "task assignment backpressure" $taskAssignmentContract "stale_queue_rescue"
Assert-Contains "task assignment metrics" $taskAssignmentContract "superbrain_task_queue_depth"
Assert-Contains "task assignment worker evidence" $taskAssignmentContract "worker_stale_queued_finalized"

Write-Host "[runtime] agent llm streaming contract"
$agentLlmStreamingContract = curl.exe -sS "$baseUrl/api/v1/agents/llm-streaming-contract"
Assert-Contains "agent llm streaming version" $agentLlmStreamingContract '"contract_version":"agent-llm-streaming-contract-v1"'
Assert-Contains "agent llm streaming evidence" $agentLlmStreamingContract '"evidence_ref":"agent_llm_streaming_contract_visible"'
Assert-Contains "agent llm streaming gap" $agentLlmStreamingContract '"audit_gap":"L-07"'
Assert-Contains "agent llm streaming protocol" $agentLlmStreamingContract "openai_compatible_sse"
Assert-Contains "agent llm streaming done" $agentLlmStreamingContract "data: [DONE]"
Assert-Contains "agent llm streaming parser" $agentLlmStreamingContract "parse_llm_gateway_sse_line"
Assert-Contains "agent llm streaming state" $agentLlmStreamingContract "stream_done_seen"
Assert-Contains "agent llm streaming no live" $agentLlmStreamingContract "No live provider stream"

Write-Host "[runtime] autopilot mode harness"
$autopilotMode = powershell -ExecutionPolicy Bypass -File scripts\verify-autopilot-mode.ps1 -BaseUrl $baseUrl -StreamUrl "$baseUrl/api/stream" -AllowLocalhost
Assert-Contains "autopilot mode proof" $autopilotMode '"autopilot_mode_proof":true'
Assert-Contains "autopilot mode stream proof" $autopilotMode "autopilot-mode-stream-proof"
Assert-Contains "autopilot mode no live provider calls" $autopilotMode '"live_provider_calls":false'

Write-Host "[runtime] worker status regression harness"
$workerStatusRegression = powershell -ExecutionPolicy Bypass -File scripts\verify-worker-status-regression.ps1 -BaseUrl $baseUrl -AllowLocalhost
Assert-Contains "worker status regression completed" $workerStatusRegression "[worker-status] regression checks completed"

Write-Host "[runtime] mcp health"
$mcpHealth = curl.exe -sS "$baseUrl/mcp/api/v1/health"
Assert-Contains "mcp health" $mcpHealth '"service":"mcp-gateway"'
$githubBranchContract = curl.exe -sS "$baseUrl/mcp/api/v1/github/branch-pr/contract"
Assert-Contains "github branch contract version" $githubBranchContract '"contract_version":"github-branch-pr-plan-v1"'
Assert-Contains "github branch contract mode" $githubBranchContract '"mode":"dry_run_contract_only"'
Assert-Contains "github branch contract no live call" $githubBranchContract '"live_github_call":false'
Assert-Contains "github branch contract allowed pattern" $githubBranchContract "feature/agent-*"
Assert-Contains "github branch contract accepted evidence" $githubBranchContract "github_branch_pr_plan"
Assert-Contains "github branch contract blocked evidence" $githubBranchContract "github_branch_pr_policy"
Assert-Contains "github branch contract merge forbidden" $githubBranchContract "merge_pull_request"
Assert-Contains "github branch contract no branch claim" $githubBranchContract "No GitHub branch is created"
$postgresqlReadonlyContract = curl.exe -sS "$baseUrl/mcp/api/v1/postgresql/readonly-query/contract"
Assert-Contains "postgresql readonly contract version" $postgresqlReadonlyContract '"contract_version":"postgresql-readonly-query-v1"'
Assert-Contains "postgresql readonly contract mode" $postgresqlReadonlyContract '"mode":"dry_run_contract_only"'
Assert-Contains "postgresql readonly no live db call" $postgresqlReadonlyContract '"live_database_call":false'
Assert-Contains "postgresql readonly allowed scope" $postgresqlReadonlyContract "project-context-readonly"
Assert-Contains "postgresql readonly select only" $postgresqlReadonlyContract "SELECT only"
Assert-Contains "postgresql readonly accepted evidence" $postgresqlReadonlyContract "postgresql_readonly_query_plan"
Assert-Contains "postgresql readonly blocked evidence" $postgresqlReadonlyContract "postgresql_write_policy"
Assert-Contains "postgresql readonly write forbidden" $postgresqlReadonlyContract "UPDATE"
$filesystemWorkspaceContract = curl.exe -sS "$baseUrl/mcp/api/v1/filesystem/workspace-scope/contract"
Assert-Contains "filesystem workspace contract version" $filesystemWorkspaceContract '"contract_version":"filesystem-workspace-scope-v1"'
Assert-Contains "filesystem workspace contract mode" $filesystemWorkspaceContract '"mode":"dry_run_contract_only"'
Assert-Contains "filesystem workspace no live call" $filesystemWorkspaceContract '"live_filesystem_call":false'
Assert-Contains "filesystem workspace root" $filesystemWorkspaceContract "/tmp/agent-workspace"
Assert-Contains "filesystem workspace allowed read" $filesystemWorkspaceContract "read_file"
Assert-Contains "filesystem workspace accepted evidence" $filesystemWorkspaceContract "filesystem_workspace_access_plan"
Assert-Contains "filesystem workspace blocked evidence" $filesystemWorkspaceContract "filesystem_scope_policy"
Assert-Contains "filesystem workspace traversal block" $filesystemWorkspaceContract "path traversal is forbidden"
$playwrightBrowserContract = curl.exe -sS "$baseUrl/mcp/api/v1/playwright/browser-proof/contract"
Assert-Contains "playwright browser contract version" $playwrightBrowserContract '"contract_version":"playwright-browser-proof-v1"'
Assert-Contains "playwright browser contract mode" $playwrightBrowserContract '"mode":"dry_run_contract_only"'
Assert-Contains "playwright browser no live call" $playwrightBrowserContract '"live_browser_call":false'
Assert-Contains "playwright browser localhost target" $playwrightBrowserContract "http://localhost:8081"
Assert-Contains "playwright browser screenshot action" $playwrightBrowserContract "take_screenshot"
Assert-Contains "playwright browser accepted evidence" $playwrightBrowserContract "playwright_browser_proof_plan"
Assert-Contains "playwright browser blocked evidence" $playwrightBrowserContract "playwright_browser_policy"
Assert-Contains "playwright browser forbidden target" $playwrightBrowserContract "file://"
$e2bSandboxContract = curl.exe -sS "$baseUrl/mcp/api/v1/e2b/sandbox-lifecycle/contract"
Assert-Contains "e2b sandbox contract version" $e2bSandboxContract '"contract_version":"e2b-sandbox-lifecycle-v1"'
Assert-Contains "e2b sandbox contract mode" $e2bSandboxContract '"mode":"dry_run_contract_only"'
Assert-Contains "e2b sandbox no live call" $e2bSandboxContract '"live_e2b_call":false'
Assert-Contains "e2b sandbox close required" $e2bSandboxContract '"close_required":true'
Assert-Contains "e2b sandbox timeout cap" $e2bSandboxContract '"max_session_timeout_ms":1800000'
Assert-Contains "e2b sandbox accepted evidence" $e2bSandboxContract "e2b_sandbox_lifecycle_plan"
Assert-Contains "e2b sandbox blocked evidence" $e2bSandboxContract "e2b_sandbox_policy"
Assert-Contains "e2b sandbox degraded evidence" $e2bSandboxContract "mcp_degraded_missing_e2b_credentials"
$mcpVersionPinningContract = curl.exe -sS "$baseUrl/mcp/api/v1/version-pinning/contract"
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

Write-Host "[runtime] memory embedding consistency contract"
$memoryEmbeddingConsistencyContract = curl.exe -sS "$baseUrl/api/v1/memory/embedding-consistency/contract"
Assert-Contains "memory embedding consistency version" $memoryEmbeddingConsistencyContract '"contract_version":"memory-embedding-consistency-v1"'
Assert-Contains "memory embedding consistency status" $memoryEmbeddingConsistencyContract '"status":"verified"'
Assert-Contains "memory embedding consistency evidence" $memoryEmbeddingConsistencyContract '"evidence_ref":"memory_embedding_consistency_contract_visible"'
Assert-Contains "memory embedding consistency gap" $memoryEmbeddingConsistencyContract '"audit_gap":"L-09"'
Assert-Contains "memory embedding consistency column" $memoryEmbeddingConsistencyContract '"embedding_model_version"'
Assert-Contains "memory embedding consistency vector" $memoryEmbeddingConsistencyContract "vector(1536)"
Assert-Contains "memory embedding consistency fallback" $memoryEmbeddingConsistencyContract "lexical_fallback"
Assert-Contains "memory embedding consistency no live provider" $memoryEmbeddingConsistencyContract "No live embedding provider call"

Write-Host "[runtime] llm gateway dry-run"
$llmHealth = curl.exe -sS "$baseUrl/llm/api/v1/health"
Assert-Contains "llm health service" $llmHealth '"service":"llm-gateway"'
Assert-Contains "llm health mode" $llmHealth '"mode":"deterministic_dry_run"'
Assert-Contains "llm health no live calls" $llmHealth '"live_provider_calls":false'
Assert-Contains "llm health streaming" $llmHealth '"streaming_sse":true'
$llmStreamingContract = curl.exe -sS "$baseUrl/llm/api/v1/streaming/contract"
Assert-Contains "llm streaming protocol" $llmStreamingContract '"protocol":"openai_compatible_sse"'
Assert-Contains "llm streaming content type" $llmStreamingContract '"content_type":"text/event-stream"'
Assert-Contains "llm streaming done frame" $llmStreamingContract 'data: [DONE]'
Assert-Contains "llm streaming no live calls" $llmStreamingContract '"live_provider_calls":false'
$llmRoutingPolicyContract = curl.exe -sS "$baseUrl/llm/api/v1/routing/policy/contract"
Assert-Contains "llm routing policy contract version" $llmRoutingPolicyContract '"contract_version":"llm-routing-policy-v1"'
Assert-Contains "llm routing policy endpoint" $llmRoutingPolicyContract "POST /api/v1/routing/policy/evaluate"
Assert-Contains "llm routing policy direct provider evidence" $llmRoutingPolicyContract "llm_routing_policy_direct_provider_blocked"
Assert-Contains "llm routing policy fallback evidence" $llmRoutingPolicyContract "llm_routing_policy_fallback_limit_blocked"
Assert-Contains "llm routing policy retry evidence" $llmRoutingPolicyContract "llm_routing_policy_retry_limit_blocked"
Assert-Contains "llm routing policy sensitive cache evidence" $llmRoutingPolicyContract "llm_routing_policy_sensitive_cache_blocked"
function Assert-LlmPolicyDecision {
  param(
    [string]$Name,
    [hashtable]$Overrides,
    [string]$ExpectedDecision
  )
  $body = @{
    run_id = "runtime-$Name"
    agent_slot = "planner"
    model_slot = "planner_primary"
    task_class = "runtime_policy"
    sensitivity = "internal"
    max_output_tokens = 4096
    retry_index = 0
    fallback_index = 0
    trace_correlation_id = "runtime-$Name"
  }
  foreach ($key in $Overrides.Keys) {
    $body[$key] = $Overrides[$key]
  }
  $policy = Invoke-RestMethod -Method Post -Uri "$baseUrl/llm/api/v1/routing/policy/evaluate" -ContentType "application/json" -Body ($body | ConvertTo-Json -Compress)
  if ($policy.decision -ne $ExpectedDecision) { throw "Runtime verification failed: LLM routing policy $Name expected $ExpectedDecision but got $($policy.decision)" }
  if ($policy.live_provider_calls -ne $false) { throw "Runtime verification failed: LLM routing policy $Name attempted live provider calls" }
  if ($policy.contract_version -ne "llm-routing-policy-v1") { throw "Runtime verification failed: LLM routing policy $Name returned wrong contract version" }
}
Assert-LlmPolicyDecision "allow-primary" @{} "allow_primary"
Assert-LlmPolicyDecision "allow-fallback" @{ fallback_index = 1 } "allow_fallback"
Assert-LlmPolicyDecision "deny-direct-provider" @{ direct_provider_url = "https://api.provider.example/v1/chat/completions" } "deny_direct_provider"
Assert-LlmPolicyDecision "deny-slot-disabled" @{ model_slot = "unknown_slot" } "deny_slot_disabled"
Assert-LlmPolicyDecision "deny-cost-tier" @{ requested_cost_tier = "Tier-P" } "deny_cost_tier"
Assert-LlmPolicyDecision "deny-fallback-limit" @{ fallback_index = 3 } "deny_fallback_limit"
Assert-LlmPolicyDecision "deny-retry-limit" @{ retry_index = 5 } "deny_retry_limit"
Assert-LlmPolicyDecision "deny-budget-or-rate" @{ budget_allow_new_calls = $false } "deny_budget_or_rate"
Assert-LlmPolicyDecision "deny-sensitive-cache" @{ sensitivity = "sensitive"; cache_requested = $true } "deny_sensitive_cache"
$llmModels = curl.exe -sS "$baseUrl/llm/v1/models"
Assert-Contains "llm models openai list" $llmModels '"object":"list"'
Assert-Contains "llm models deepseek" $llmModels "deepseek-chat"
Assert-Contains "llm models no live calls" $llmModels '"live_provider_calls":false'
$llmProviders = curl.exe -sS "$baseUrl/llm/api/v1/providers/status"
Assert-Contains "llm providers huggingface router" $llmProviders '"provider":"huggingface_inference_router"'
Assert-Contains "llm providers router verified" $llmProviders '"status":"live_verified"'
Assert-Contains "llm providers no live calls" $llmProviders '"live_provider_calls":false'
Assert-Contains "llm providers backoff" $llmProviders '"rotation_backoff_seconds":[30,60,120,300]'
$llmRouteBody = @{
  agent_type = "planner"
  task_type = "runtime_route_resolve"
  requires_streaming = $true
  budget_level = "ok"
} | ConvertTo-Json -Compress
$llmRoute = Invoke-RestMethod -Method Post -Uri "$baseUrl/llm/api/v1/routing/resolve" -ContentType "application/json" -Body $llmRouteBody
if ($llmRoute.selected_model -ne "deepseek-ai/DeepSeek-V4-Pro:fastest") { throw "Runtime verification failed: LLM routing selected unexpected model" }
if ($llmRoute.selected_provider -ne "huggingface_inference_router") { throw "Runtime verification failed: LLM routing selected unexpected provider" }
if ($llmRoute.live_provider_calls -ne $false) { throw "Runtime verification failed: LLM routing attempted live provider calls" }
if ($llmRoute.configured_only -ne $false) { throw "Runtime verification failed: LLM routing should be live-verifiable through HF router" }
if (-not ($llmRoute.fallback_chain -contains "moonshotai/Kimi-K2.6:fastest")) { throw "Runtime verification failed: LLM routing fallback chain missing open-source emergency fallback" }
if (-not ($llmRoute.provider_chain -contains "huggingface_inference_router")) { throw "Runtime verification failed: LLM routing provider chain missing HF router provider" }
if ($llmRoute.provider_health.status -ne "live_verified") { throw "Runtime verification failed: LLM routing provider health status wrong" }
$llmTraceId = "runtime-llm-dry-run-" + [Guid]::NewGuid().ToString("N")
$llmChatBody = @{
  model = "deepseek-chat"
  messages = @(@{ role = "user"; content = "runtime llm dry run proof" })
  stream = $false
  metadata = @{ trace_id = $llmTraceId; agent_type = "coder" }
} | ConvertTo-Json -Depth 6 -Compress
$llmChat = Invoke-RestMethod -Method Post -Uri "$baseUrl/llm/v1/chat/completions" -ContentType "application/json" -Body $llmChatBody
if ($llmChat.live_provider_calls -ne $false) { throw "Runtime verification failed: LLM gateway attempted live provider calls" }
if ($llmChat.cost_cents -ne 0) { throw "Runtime verification failed: LLM gateway dry-run cost was not zero" }
if ($llmChat.audit_persisted -ne $true) { throw "Runtime verification failed: LLM gateway audit was not persisted" }
if (-not (($llmChat.choices[0].message.content | Out-String).Contains("deterministic dry-run response"))) { throw "Runtime verification failed: LLM gateway dry-run content missing" }
$llmStreamTraceId = "runtime-llm-stream-" + [Guid]::NewGuid().ToString("N")
$llmStreamBody = @{
  model = "deepseek-chat"
  messages = @(@{ role = "user"; content = "runtime llm streaming dry run proof" })
  stream = $true
  metadata = @{ trace_id = $llmStreamTraceId; agent_type = "coder" }
} | ConvertTo-Json -Depth 6 -Compress
$llmStreamBodyFile = Join-Path $env:TEMP ("llm-stream-" + [Guid]::NewGuid().ToString("N") + ".json")
try {
  Set-Content -LiteralPath $llmStreamBodyFile -Value $llmStreamBody -NoNewline
  $llmStream = curl.exe -sS -N -X POST -H "Content-Type: application/json" --data-binary "@$llmStreamBodyFile" "$baseUrl/llm/v1/chat/completions"
} finally {
  if (Test-Path $llmStreamBodyFile) { Remove-Item -LiteralPath $llmStreamBodyFile -Force }
}
Assert-Contains "llm stream chunk" $llmStream '"object":"chat.completion.chunk"'
Assert-Contains "llm stream content" $llmStream "deterministic dry-run response"
Assert-Contains "llm stream no live calls" $llmStream '"live_provider_calls":false'
Assert-Contains "llm stream audit" $llmStream '"audit_persisted":true'
Assert-Contains "llm stream done" $llmStream 'data: [DONE]'
$llmAudit = curl.exe -sS "$baseUrl/api/v1/audit/recent?limit=30"
Assert-Contains "llm audit event" $llmAudit "llm_gateway_request"
Assert-Contains "llm audit trace" $llmAudit $llmTraceId
Assert-Contains "llm stream audit trace" $llmAudit $llmStreamTraceId
Assert-Contains "llm audit no live calls" $llmAudit '"live_provider_calls":false'

Write-Host "[runtime] mcp tool timeout/degraded paths"
$mcpRunId = "runtime-mcp-proof-" + [Guid]::NewGuid().ToString("N")
$mcpTimeoutBody = @{
  tool_request_id = "runtime-timeout-proof"
  run_id = $mcpRunId
  agent_role = "tester"
  toolset = "e2b"
  capability = "simulate_timeout"
  intent_summary = "prove timeout envelope"
  input_ref = "none"
  allowed_scope = "sandbox:test"
  timeout_ms = 25
  retry_budget = 1
  idempotency_key = "runtime-timeout-proof"
  audit_tags = @("runtime", "timeout")
  redaction_required = $true
  expected_output_type = "tool_result"
} | ConvertTo-Json -Compress
$mcpTimeout = Invoke-RestMethod -Method Post -Uri "$baseUrl/mcp/api/v1/tools/execute" -ContentType "application/json" -Body $mcpTimeoutBody
if ($mcpTimeout.status -ne "timeout") { throw "Runtime verification failed: MCP timeout path did not return timeout" }
if ($mcpTimeout.error_class -ne "timeout") { throw "Runtime verification failed: MCP timeout path missing timeout error_class" }
if ($mcpTimeout.audit_persisted -ne $true) { throw "Runtime verification failed: MCP timeout path was not audit-persisted" }

$mcpBlockedBody = @{
  tool_request_id = "runtime-main-block-proof"
  run_id = $mcpRunId
  agent_role = "coder"
  toolset = "github"
  capability = "write_branch"
  intent_summary = "prove main branch block"
  input_ref = "none"
  allowed_scope = "refs/heads/main"
  timeout_ms = 1000
  retry_budget = 0
  idempotency_key = "runtime-main-block-proof"
  audit_tags = @("runtime", "scope")
  redaction_required = $true
  expected_output_type = "tool_result"
} | ConvertTo-Json -Compress
$mcpBlocked = Invoke-RestMethod -Method Post -Uri "$baseUrl/mcp/api/v1/tools/execute" -ContentType "application/json" -Body $mcpBlockedBody
if ($mcpBlocked.status -ne "blocked") { throw "Runtime verification failed: MCP main branch scope path did not return blocked" }
if ($mcpBlocked.error_class -ne "github_scope_violation") { throw "Runtime verification failed: MCP main branch scope path missing github_scope_violation" }
if ($mcpBlocked.audit_persisted -ne $true) { throw "Runtime verification failed: MCP blocked path was not audit-persisted" }

$mcpBranchPlanInput = @{
  branch = "feature/agent-coder-runtime-proof"
  title = "Runtime dry-run PR proof"
  base = "main"
  body = "Runtime verifier proves GitHub Branch/PR dry-run contract without mutation."
} | ConvertTo-Json -Compress
$mcpBranchPlanBody = @{
  tool_request_id = "runtime-github-branch-pr-plan"
  run_id = $mcpRunId
  agent_role = "coder"
  toolset = "github"
  capability = "plan_branch_pr"
  intent_summary = "prove branch and pull request dry-run plan"
  input_ref = $mcpBranchPlanInput
  allowed_scope = "feature/agent-coder-runtime-proof"
  timeout_ms = 1000
  retry_budget = 0
  idempotency_key = "runtime-github-branch-pr-plan"
  audit_tags = @("runtime", "github", "branch-pr")
  redaction_required = $true
  expected_output_type = "github_plan"
} | ConvertTo-Json -Compress
$mcpBranchPlan = Invoke-RestMethod -Method Post -Uri "$baseUrl/mcp/api/v1/tools/execute" -ContentType "application/json" -Body $mcpBranchPlanBody
if ($mcpBranchPlan.status -ne "success") { throw "Runtime verification failed: MCP GitHub branch/PR plan was not accepted" }
if ($mcpBranchPlan.evidence_ref -ne "github_branch_pr_plan") { throw "Runtime verification failed: MCP GitHub branch/PR plan evidence mismatch" }
if ($mcpBranchPlan.audit_persisted -ne $true) { throw "Runtime verification failed: MCP GitHub branch/PR plan was not audit-persisted" }
if ($mcpBranchPlan.github_plan.contract_version -ne "github-branch-pr-plan-v1") { throw "Runtime verification failed: MCP GitHub branch/PR plan contract version mismatch" }
if ($mcpBranchPlan.github_plan.live_github_call -ne $false) { throw "Runtime verification failed: MCP GitHub branch/PR plan attempted a live GitHub call" }
if ($mcpBranchPlan.github_plan.allowed_branch -ne "feature/agent-coder-runtime-proof") { throw "Runtime verification failed: MCP GitHub branch/PR plan allowed branch mismatch" }
if ($mcpBranchPlan.github_plan.pull_request_payload.head -ne "feature/agent-coder-runtime-proof") { throw "Runtime verification failed: MCP GitHub branch/PR plan PR head mismatch" }
if ($mcpBranchPlan.github_plan.pull_request_payload.base -ne "main") { throw "Runtime verification failed: MCP GitHub branch/PR plan PR base mismatch" }
if ($mcpBranchPlan.github_plan.pull_request_payload.draft -ne $true) { throw "Runtime verification failed: MCP GitHub branch/PR plan PR was not draft" }

$mcpBranchBlockedInput = @{
  branch = "main"
  title = "Forbidden main branch proof"
  base = "main"
  body = "Runtime verifier proves main branch plans are blocked."
} | ConvertTo-Json -Compress
$mcpBranchBlockedBody = @{
  tool_request_id = "runtime-github-branch-pr-block"
  run_id = $mcpRunId
  agent_role = "coder"
  toolset = "github"
  capability = "plan_branch_pr"
  intent_summary = "prove branch plan policy block"
  input_ref = $mcpBranchBlockedInput
  allowed_scope = "main"
  timeout_ms = 1000
  retry_budget = 0
  idempotency_key = "runtime-github-branch-pr-block"
  audit_tags = @("runtime", "github", "branch-pr-block")
  redaction_required = $true
  expected_output_type = "tool_result"
} | ConvertTo-Json -Compress
$mcpBranchBlocked = Invoke-RestMethod -Method Post -Uri "$baseUrl/mcp/api/v1/tools/execute" -ContentType "application/json" -Body $mcpBranchBlockedBody
if ($mcpBranchBlocked.status -ne "blocked") { throw "Runtime verification failed: MCP GitHub main branch/PR plan was not blocked" }
if ($mcpBranchBlocked.error_class -ne "github_branch_policy_violation") { throw "Runtime verification failed: MCP GitHub main branch/PR plan missing github_branch_policy_violation" }
if ($mcpBranchBlocked.evidence_ref -ne "github_branch_pr_policy") { throw "Runtime verification failed: MCP GitHub main branch/PR block evidence mismatch" }
if ($mcpBranchBlocked.audit_persisted -ne $true) { throw "Runtime verification failed: MCP GitHub branch/PR block was not audit-persisted" }

$mcpPostgresqlPlanInput = @{
  sql = "SELECT id, name FROM projects LIMIT 5"
  parameters = @()
} | ConvertTo-Json -Compress
$mcpPostgresqlPlanBody = @{
  tool_request_id = "runtime-postgresql-readonly-plan"
  run_id = $mcpRunId
  agent_role = "planner"
  toolset = "postgresql"
  capability = "query_readonly"
  intent_summary = "prove postgresql readonly query plan"
  input_ref = $mcpPostgresqlPlanInput
  allowed_scope = "project-context-readonly"
  timeout_ms = 1000
  retry_budget = 0
  idempotency_key = "runtime-postgresql-readonly-plan"
  audit_tags = @("runtime", "postgresql", "readonly")
  redaction_required = $true
  expected_output_type = "postgresql_plan"
} | ConvertTo-Json -Compress
$mcpPostgresqlPlan = Invoke-RestMethod -Method Post -Uri "$baseUrl/mcp/api/v1/tools/execute" -ContentType "application/json" -Body $mcpPostgresqlPlanBody
if ($mcpPostgresqlPlan.status -ne "success") { throw "Runtime verification failed: MCP PostgreSQL readonly plan was not accepted" }
if ($mcpPostgresqlPlan.evidence_ref -ne "postgresql_readonly_query_plan") { throw "Runtime verification failed: MCP PostgreSQL readonly plan evidence mismatch" }
if ($mcpPostgresqlPlan.audit_persisted -ne $true) { throw "Runtime verification failed: MCP PostgreSQL readonly plan was not audit-persisted" }
if ($mcpPostgresqlPlan.postgresql_plan.contract_version -ne "postgresql-readonly-query-v1") { throw "Runtime verification failed: MCP PostgreSQL readonly plan contract mismatch" }
if ($mcpPostgresqlPlan.postgresql_plan.live_database_call -ne $false) { throw "Runtime verification failed: MCP PostgreSQL readonly plan attempted a live database call" }
if ($mcpPostgresqlPlan.postgresql_plan.readonly -ne $true) { throw "Runtime verification failed: MCP PostgreSQL readonly plan did not mark readonly true" }
if ($mcpPostgresqlPlan.postgresql_plan.allowed_scope -ne "project-context-readonly") { throw "Runtime verification failed: MCP PostgreSQL readonly plan scope mismatch" }

$mcpPostgresqlBlockedInput = @{
  sql = "UPDATE projects SET name = 'blocked'"
  parameters = @()
} | ConvertTo-Json -Compress
$mcpPostgresqlBlockedBody = @{
  tool_request_id = "runtime-postgresql-write-block"
  run_id = $mcpRunId
  agent_role = "planner"
  toolset = "postgresql"
  capability = "query_readonly"
  intent_summary = "prove postgresql write policy block"
  input_ref = $mcpPostgresqlBlockedInput
  allowed_scope = "project-context-readonly"
  timeout_ms = 1000
  retry_budget = 0
  idempotency_key = "runtime-postgresql-write-block"
  audit_tags = @("runtime", "postgresql", "write-block")
  redaction_required = $true
  expected_output_type = "tool_result"
} | ConvertTo-Json -Compress
$mcpPostgresqlBlocked = Invoke-RestMethod -Method Post -Uri "$baseUrl/mcp/api/v1/tools/execute" -ContentType "application/json" -Body $mcpPostgresqlBlockedBody
if ($mcpPostgresqlBlocked.status -ne "blocked") { throw "Runtime verification failed: MCP PostgreSQL write query was not blocked" }
if ($mcpPostgresqlBlocked.error_class -ne "postgresql_write_policy_violation") { throw "Runtime verification failed: MCP PostgreSQL write block error mismatch" }
if ($mcpPostgresqlBlocked.evidence_ref -ne "postgresql_write_policy") { throw "Runtime verification failed: MCP PostgreSQL write block evidence mismatch" }
if ($mcpPostgresqlBlocked.audit_persisted -ne $true) { throw "Runtime verification failed: MCP PostgreSQL write block was not audit-persisted" }

$mcpFilesystemPlanInput = @{
  operation = "read_file"
  path = "/tmp/agent-workspace/context/task.md"
} | ConvertTo-Json -Compress
$mcpFilesystemPlanBody = @{
  tool_request_id = "runtime-filesystem-workspace-plan"
  run_id = $mcpRunId
  agent_role = "coder"
  toolset = "filesystem"
  capability = "plan_workspace_access"
  intent_summary = "prove filesystem workspace scope plan"
  input_ref = $mcpFilesystemPlanInput
  allowed_scope = "/tmp/agent-workspace/context"
  timeout_ms = 1000
  retry_budget = 0
  idempotency_key = "runtime-filesystem-workspace-plan"
  audit_tags = @("runtime", "filesystem", "workspace")
  redaction_required = $true
  expected_output_type = "filesystem_plan"
} | ConvertTo-Json -Compress
$mcpFilesystemPlan = Invoke-RestMethod -Method Post -Uri "$baseUrl/mcp/api/v1/tools/execute" -ContentType "application/json" -Body $mcpFilesystemPlanBody
if ($mcpFilesystemPlan.status -ne "success") { throw "Runtime verification failed: MCP Filesystem workspace plan was not accepted" }
if ($mcpFilesystemPlan.evidence_ref -ne "filesystem_workspace_access_plan") { throw "Runtime verification failed: MCP Filesystem workspace plan evidence mismatch" }
if ($mcpFilesystemPlan.audit_persisted -ne $true) { throw "Runtime verification failed: MCP Filesystem workspace plan was not audit-persisted" }
if ($mcpFilesystemPlan.filesystem_plan.contract_version -ne "filesystem-workspace-scope-v1") { throw "Runtime verification failed: MCP Filesystem workspace plan contract mismatch" }
if ($mcpFilesystemPlan.filesystem_plan.live_filesystem_call -ne $false) { throw "Runtime verification failed: MCP Filesystem workspace plan attempted a live filesystem call" }
if ($mcpFilesystemPlan.filesystem_plan.workspace_root -ne "/tmp/agent-workspace") { throw "Runtime verification failed: MCP Filesystem workspace root mismatch" }

$mcpFilesystemBlockedInput = @{
  operation = "read_file"
  path = "/etc/passwd"
} | ConvertTo-Json -Compress
$mcpFilesystemBlockedBody = @{
  tool_request_id = "runtime-filesystem-scope-block"
  run_id = $mcpRunId
  agent_role = "coder"
  toolset = "filesystem"
  capability = "plan_workspace_access"
  intent_summary = "prove filesystem host path block"
  input_ref = $mcpFilesystemBlockedInput
  allowed_scope = "/etc"
  timeout_ms = 1000
  retry_budget = 0
  idempotency_key = "runtime-filesystem-scope-block"
  audit_tags = @("runtime", "filesystem", "scope-block")
  redaction_required = $true
  expected_output_type = "tool_result"
} | ConvertTo-Json -Compress
$mcpFilesystemBlocked = Invoke-RestMethod -Method Post -Uri "$baseUrl/mcp/api/v1/tools/execute" -ContentType "application/json" -Body $mcpFilesystemBlockedBody
if ($mcpFilesystemBlocked.status -ne "blocked") { throw "Runtime verification failed: MCP Filesystem host path was not blocked" }
if ($mcpFilesystemBlocked.error_class -ne "filesystem_scope_policy_violation") { throw "Runtime verification failed: MCP Filesystem scope block error mismatch" }
if ($mcpFilesystemBlocked.evidence_ref -ne "filesystem_scope_policy") { throw "Runtime verification failed: MCP Filesystem scope block evidence mismatch" }
if ($mcpFilesystemBlocked.audit_persisted -ne $true) { throw "Runtime verification failed: MCP Filesystem scope block was not audit-persisted" }

$mcpPlaywrightPlanInput = @{
  action = "take_screenshot"
  target_url = "http://localhost:8081"
} | ConvertTo-Json -Compress
$mcpPlaywrightPlanBody = @{
  tool_request_id = "runtime-playwright-browser-proof-plan"
  run_id = $mcpRunId
  agent_role = "tester"
  toolset = "playwright"
  capability = "plan_browser_proof"
  intent_summary = "prove playwright browser proof plan"
  input_ref = $mcpPlaywrightPlanInput
  allowed_scope = "browser-proof-localhost"
  timeout_ms = 120000
  retry_budget = 0
  idempotency_key = "runtime-playwright-browser-proof-plan"
  audit_tags = @("runtime", "playwright", "browser-proof")
  redaction_required = $true
  expected_output_type = "playwright_plan"
} | ConvertTo-Json -Compress
$mcpPlaywrightPlan = Invoke-RestMethod -Method Post -Uri "$baseUrl/mcp/api/v1/tools/execute" -ContentType "application/json" -Body $mcpPlaywrightPlanBody
if ($mcpPlaywrightPlan.status -ne "success") { throw "Runtime verification failed: MCP Playwright browser proof plan was not accepted" }
if ($mcpPlaywrightPlan.evidence_ref -ne "playwright_browser_proof_plan") { throw "Runtime verification failed: MCP Playwright browser proof plan evidence mismatch" }
if ($mcpPlaywrightPlan.audit_persisted -ne $true) { throw "Runtime verification failed: MCP Playwright browser proof plan was not audit-persisted" }
if ($mcpPlaywrightPlan.playwright_plan.contract_version -ne "playwright-browser-proof-v1") { throw "Runtime verification failed: MCP Playwright browser proof plan contract mismatch" }
if ($mcpPlaywrightPlan.playwright_plan.live_browser_call -ne $false) { throw "Runtime verification failed: MCP Playwright browser proof plan attempted a live browser call" }

$mcpPlaywrightBlockedInput = @{
  action = "navigate_to_url"
  target_url = "file:///etc/passwd"
} | ConvertTo-Json -Compress
$mcpPlaywrightBlockedBody = @{
  tool_request_id = "runtime-playwright-browser-policy-block"
  run_id = $mcpRunId
  agent_role = "tester"
  toolset = "playwright"
  capability = "plan_browser_proof"
  intent_summary = "prove playwright forbidden target block"
  input_ref = $mcpPlaywrightBlockedInput
  allowed_scope = "browser-proof-localhost"
  timeout_ms = 1000
  retry_budget = 0
  idempotency_key = "runtime-playwright-browser-policy-block"
  audit_tags = @("runtime", "playwright", "policy-block")
  redaction_required = $true
  expected_output_type = "tool_result"
} | ConvertTo-Json -Compress
$mcpPlaywrightBlocked = Invoke-RestMethod -Method Post -Uri "$baseUrl/mcp/api/v1/tools/execute" -ContentType "application/json" -Body $mcpPlaywrightBlockedBody
if ($mcpPlaywrightBlocked.status -ne "blocked") { throw "Runtime verification failed: MCP Playwright forbidden target was not blocked" }
if ($mcpPlaywrightBlocked.error_class -ne "playwright_browser_policy_violation") { throw "Runtime verification failed: MCP Playwright policy block error mismatch" }
if ($mcpPlaywrightBlocked.evidence_ref -ne "playwright_browser_policy") { throw "Runtime verification failed: MCP Playwright policy block evidence mismatch" }
if ($mcpPlaywrightBlocked.audit_persisted -ne $true) { throw "Runtime verification failed: MCP Playwright policy block was not audit-persisted" }

$mcpE2bPlanInput = @{
  action = "execute_code"
  code = "pytest -q"
  close_sandbox_finally = $true
} | ConvertTo-Json -Compress
$mcpE2bPlanBody = @{
  tool_request_id = "runtime-e2b-sandbox-lifecycle-plan"
  run_id = $mcpRunId
  agent_role = "tester"
  toolset = "e2b"
  capability = "plan_sandbox_lifecycle"
  intent_summary = "prove e2b sandbox lifecycle plan"
  input_ref = $mcpE2bPlanInput
  allowed_scope = "sandbox:test"
  timeout_ms = 1800000
  retry_budget = 0
  idempotency_key = "runtime-e2b-sandbox-lifecycle-plan"
  audit_tags = @("runtime", "e2b", "sandbox-lifecycle")
  redaction_required = $true
  expected_output_type = "e2b_plan"
} | ConvertTo-Json -Compress
$mcpE2bPlan = Invoke-RestMethod -Method Post -Uri "$baseUrl/mcp/api/v1/tools/execute" -ContentType "application/json" -Body $mcpE2bPlanBody
if ($mcpE2bPlan.status -ne "success") { throw "Runtime verification failed: MCP E2B sandbox lifecycle plan was not accepted" }
if ($mcpE2bPlan.evidence_ref -ne "e2b_sandbox_lifecycle_plan") { throw "Runtime verification failed: MCP E2B sandbox lifecycle plan evidence mismatch" }
if ($mcpE2bPlan.audit_persisted -ne $true) { throw "Runtime verification failed: MCP E2B sandbox lifecycle plan was not audit-persisted" }
if ($mcpE2bPlan.e2b_plan.contract_version -ne "e2b-sandbox-lifecycle-v1") { throw "Runtime verification failed: MCP E2B sandbox lifecycle plan contract mismatch" }
if ($mcpE2bPlan.e2b_plan.live_e2b_call -ne $false) { throw "Runtime verification failed: MCP E2B sandbox lifecycle plan attempted a live E2B call" }
if ($mcpE2bPlan.e2b_plan.close_sandbox_finally -ne $true) { throw "Runtime verification failed: MCP E2B sandbox lifecycle plan did not require finally close" }

$mcpE2bBlockedInput = @{
  action = "execute_code"
  code = "pytest -q"
  close_sandbox_finally = $false
} | ConvertTo-Json -Compress
$mcpE2bBlockedBody = @{
  tool_request_id = "runtime-e2b-sandbox-policy-block"
  run_id = $mcpRunId
  agent_role = "tester"
  toolset = "e2b"
  capability = "plan_sandbox_lifecycle"
  intent_summary = "prove e2b missing finally close block"
  input_ref = $mcpE2bBlockedInput
  allowed_scope = "sandbox:test"
  timeout_ms = 120000
  retry_budget = 0
  idempotency_key = "runtime-e2b-sandbox-policy-block"
  audit_tags = @("runtime", "e2b", "policy-block")
  redaction_required = $true
  expected_output_type = "tool_result"
} | ConvertTo-Json -Compress
$mcpE2bBlocked = Invoke-RestMethod -Method Post -Uri "$baseUrl/mcp/api/v1/tools/execute" -ContentType "application/json" -Body $mcpE2bBlockedBody
if ($mcpE2bBlocked.status -ne "blocked") { throw "Runtime verification failed: MCP E2B missing finally close was not blocked" }
if ($mcpE2bBlocked.error_class -ne "e2b_sandbox_policy_violation") { throw "Runtime verification failed: MCP E2B policy block error mismatch" }
if ($mcpE2bBlocked.evidence_ref -ne "e2b_sandbox_policy") { throw "Runtime verification failed: MCP E2B policy block evidence mismatch" }
if ($mcpE2bBlocked.audit_persisted -ne $true) { throw "Runtime verification failed: MCP E2B policy block was not audit-persisted" }

$mcpDegradedBody = @{
  tool_request_id = "runtime-e2b-degraded-proof"
  run_id = $mcpRunId
  agent_role = "tester"
  toolset = "e2b"
  capability = "create_sandbox"
  intent_summary = "prove degraded missing e2b credentials"
  input_ref = "none"
  allowed_scope = "sandbox:test"
  timeout_ms = 1000
  retry_budget = 0
  idempotency_key = "runtime-e2b-degraded-proof"
  audit_tags = @("runtime", "degraded")
  redaction_required = $true
  expected_output_type = "tool_result"
} | ConvertTo-Json -Compress
$mcpDegraded = Invoke-RestMethod -Method Post -Uri "$baseUrl/mcp/api/v1/tools/execute" -ContentType "application/json" -Body $mcpDegradedBody
if ($mcpDegraded.status -ne "degraded") { throw "Runtime verification failed: MCP E2B missing credentials path did not return degraded" }
if ($mcpDegraded.error_class -ne "missing_credentials") { throw "Runtime verification failed: MCP E2B degraded path missing missing_credentials" }
if ($mcpDegraded.audit_persisted -ne $true) { throw "Runtime verification failed: MCP degraded path was not audit-persisted" }
$mcpAuditEvents = curl.exe -sS "$baseUrl/api/v1/audit/recent?limit=20"
Assert-Contains "mcp audit event type" $mcpAuditEvents "mcp_tool_executed"
Assert-Contains "mcp audit timeout id" $mcpAuditEvents "runtime-timeout-proof"
Assert-Contains "mcp audit blocked id" $mcpAuditEvents "runtime-main-block-proof"
Assert-Contains "mcp audit branch plan id" $mcpAuditEvents "runtime-github-branch-pr-plan"
Assert-Contains "mcp audit branch block id" $mcpAuditEvents "runtime-github-branch-pr-block"
Assert-Contains "mcp audit postgresql readonly plan id" $mcpAuditEvents "runtime-postgresql-readonly-plan"
Assert-Contains "mcp audit postgresql write block id" $mcpAuditEvents "runtime-postgresql-write-block"
Assert-Contains "mcp audit filesystem workspace plan id" $mcpAuditEvents "runtime-filesystem-workspace-plan"
Assert-Contains "mcp audit filesystem scope block id" $mcpAuditEvents "runtime-filesystem-scope-block"
Assert-Contains "mcp audit playwright browser plan id" $mcpAuditEvents "runtime-playwright-browser-proof-plan"
Assert-Contains "mcp audit playwright browser block id" $mcpAuditEvents "runtime-playwright-browser-policy-block"
Assert-Contains "mcp audit e2b sandbox plan id" $mcpAuditEvents "runtime-e2b-sandbox-lifecycle-plan"
Assert-Contains "mcp audit e2b sandbox block id" $mcpAuditEvents "runtime-e2b-sandbox-policy-block"
Assert-Contains "mcp audit degraded id" $mcpAuditEvents "runtime-e2b-degraded-proof"
$mcpAuditFeed = curl.exe -sS "$baseUrl/api/v1/audit/mcp?limit=40"
Assert-Contains "mcp audit feed event type" $mcpAuditFeed "mcp_tool_executed"
Assert-Contains "mcp audit feed timeout id" $mcpAuditFeed "runtime-timeout-proof"
Assert-Contains "mcp audit feed blocked id" $mcpAuditFeed "runtime-main-block-proof"
Assert-Contains "mcp audit feed branch plan id" $mcpAuditFeed "runtime-github-branch-pr-plan"
Assert-Contains "mcp audit feed branch plan evidence" $mcpAuditFeed "github_branch_pr_plan"
Assert-Contains "mcp audit feed branch block id" $mcpAuditFeed "runtime-github-branch-pr-block"
Assert-Contains "mcp audit feed branch block evidence" $mcpAuditFeed "github_branch_pr_policy"
Assert-Contains "mcp audit feed postgresql readonly plan id" $mcpAuditFeed "runtime-postgresql-readonly-plan"
Assert-Contains "mcp audit feed postgresql readonly evidence" $mcpAuditFeed "postgresql_readonly_query_plan"
Assert-Contains "mcp audit feed postgresql write block id" $mcpAuditFeed "runtime-postgresql-write-block"
Assert-Contains "mcp audit feed postgresql write block evidence" $mcpAuditFeed "postgresql_write_policy"
Assert-Contains "mcp audit feed filesystem workspace plan id" $mcpAuditFeed "runtime-filesystem-workspace-plan"
Assert-Contains "mcp audit feed filesystem workspace evidence" $mcpAuditFeed "filesystem_workspace_access_plan"
Assert-Contains "mcp audit feed filesystem scope block id" $mcpAuditFeed "runtime-filesystem-scope-block"
Assert-Contains "mcp audit feed filesystem scope evidence" $mcpAuditFeed "filesystem_scope_policy"
Assert-Contains "mcp audit feed playwright browser plan id" $mcpAuditFeed "runtime-playwright-browser-proof-plan"
Assert-Contains "mcp audit feed playwright browser evidence" $mcpAuditFeed "playwright_browser_proof_plan"
Assert-Contains "mcp audit feed playwright browser block id" $mcpAuditFeed "runtime-playwright-browser-policy-block"
Assert-Contains "mcp audit feed playwright browser block evidence" $mcpAuditFeed "playwright_browser_policy"
Assert-Contains "mcp audit feed e2b sandbox plan id" $mcpAuditFeed "runtime-e2b-sandbox-lifecycle-plan"
Assert-Contains "mcp audit feed e2b sandbox evidence" $mcpAuditFeed "e2b_sandbox_lifecycle_plan"
Assert-Contains "mcp audit feed e2b sandbox block id" $mcpAuditFeed "runtime-e2b-sandbox-policy-block"
Assert-Contains "mcp audit feed e2b sandbox block evidence" $mcpAuditFeed "e2b_sandbox_policy"
Assert-Contains "mcp audit feed degraded id" $mcpAuditFeed "runtime-e2b-degraded-proof"

Write-Host "[runtime] migration table"
$migration = docker exec cloud-superbrain-phase1-dev-postgres-1 psql -U superbrain -d superbrain_prod -tAc "SELECT version FROM schema_migrations WHERE version='001_foundation_schema';"
Assert-Contains "migration table" $migration "001_foundation_schema"

Write-Host "[runtime] rate limit guard"
$rateLimitContract = curl.exe -sS "$baseUrl/api/v1/rate-limit/contract"
Assert-Contains "rate limit contract version" $rateLimitContract '"contract_version":"rate-limit-guard-v1"'
Assert-Contains "rate limit protected endpoint" $rateLimitContract "POST /api/v1/prompt"
Assert-Contains "rate limit status endpoint" $rateLimitContract "GET /api/v1/rate-limit/status?project_id={id}"
Assert-Contains "rate limit evidence visible" $rateLimitContract "rate_limit_contract_visible"
Assert-Contains "rate limit 429 evidence" $rateLimitContract "rate_limit_429_enforced"
$rateLimitProjectId = "runtime-rate-limit-" + [Guid]::NewGuid().ToString("N")
$rateLimitStatus = Invoke-RestMethod -Method Get -Uri "$baseUrl/api/v1/rate-limit/status?project_id=$rateLimitProjectId"
if ($rateLimitStatus.contract_version -ne "rate-limit-guard-v1") { throw "Runtime verification failed: rate limit status contract mismatch" }
if ($rateLimitStatus.evidence_ref -ne "rate_limit_status_visible") { throw "Runtime verification failed: rate limit status evidence mismatch" }
if ([int]$rateLimitStatus.remaining -ne [int]$rateLimitStatus.limit) { throw "Runtime verification failed: fresh rate limit status not fully available" }
$rateLimitKey = [string]$rateLimitStatus.key
try {
  docker exec cloud-superbrain-phase1-dev-redis-1 redis-cli SETEX $rateLimitKey 120 $rateLimitStatus.limit | Out-Null
  $blockedRateBody = @{ project_id = $rateLimitProjectId; prompt = "runtime rate limit proof"; stream = $true } | ConvertTo-Json -Compress
  $blockedRateBodyFile = Join-Path $env:TEMP ("runtime-rate-limit-" + [Guid]::NewGuid().ToString("N") + ".json")
  try {
    Set-Content -LiteralPath $blockedRateBodyFile -Value $blockedRateBody -NoNewline
    $blockedRate = curl.exe -sS -w "`n%{http_code}" -X POST -H "Content-Type: application/json" --data-binary "@$blockedRateBodyFile" "$baseUrl/api/v1/prompt"
  } finally {
    if (Test-Path $blockedRateBodyFile) { Remove-Item -LiteralPath $blockedRateBodyFile -Force }
  }
  Assert-Contains "rate limit blocked detail" $blockedRate "prompt rate limit exceeded"
  Assert-Contains "rate limit blocked http status" $blockedRate "429"
  Assert-Contains "rate limit blocked error envelope" $blockedRate '"contract_version":"error-response-contract-v1"'
  Assert-Contains "rate limit blocked envelope status" $blockedRate '"status_code":429'
  Assert-Contains "rate limit blocked envelope evidence" $blockedRate "error_response_429_visible"
} finally {
  docker exec cloud-superbrain-phase1-dev-redis-1 redis-cli DEL $rateLimitKey | Out-Null
}

Write-Host "[runtime] session limit guard"
$sessionLimitContract = curl.exe -sS "$baseUrl/api/v1/session-limits/contract"
Assert-Contains "session limit contract version" $sessionLimitContract '"contract_version":"session-llm-call-limit-v1"'
Assert-Contains "session limit protected endpoint" $sessionLimitContract "POST /api/v1/prompt"
Assert-Contains "session limit status endpoint" $sessionLimitContract "GET /api/v1/session-limits/status?session_id={id}"
Assert-Contains "session limit contract evidence" $sessionLimitContract "session_limit_contract_visible"
Assert-Contains "session limit status evidence" $sessionLimitContract "session_limit_status_visible"
Assert-Contains "session limit 429 evidence" $sessionLimitContract "session_limit_429_enforced"
$sessionLimitProjectId = "runtime-session-limit-" + [Guid]::NewGuid().ToString("N")
$sessionLimitId = "runtime-session-limit-" + [Guid]::NewGuid().ToString("N")
$sessionLimitStatus = Invoke-RestMethod -Method Get -Uri "$baseUrl/api/v1/session-limits/status?session_id=$sessionLimitId"
if ($sessionLimitStatus.contract_version -ne "session-llm-call-limit-v1") { throw "Runtime verification failed: session limit status contract mismatch" }
if ($sessionLimitStatus.evidence_ref -ne "session_limit_status_visible") { throw "Runtime verification failed: session limit status evidence mismatch" }
if ([int]$sessionLimitStatus.remaining -ne [int]$sessionLimitStatus.limit) { throw "Runtime verification failed: fresh session limit should have full remaining capacity" }
$sessionLimitKey = [string]$sessionLimitStatus.key
try {
  docker exec cloud-superbrain-phase1-dev-redis-1 redis-cli SETEX $sessionLimitKey 120 $sessionLimitStatus.limit | Out-Null
  $blockedSessionBody = @{
    project_id = $sessionLimitProjectId
    session_id = $sessionLimitId
    prompt = "runtime session limit proof"
    stream = $true
  } | ConvertTo-Json -Compress
  $blockedSessionBodyFile = Join-Path $env:TEMP ("runtime-session-limit-" + [Guid]::NewGuid().ToString("N") + ".json")
  try {
    Set-Content -LiteralPath $blockedSessionBodyFile -Value $blockedSessionBody -NoNewline
    $blockedSession = curl.exe -sS -w "`n%{http_code}" -X POST -H "Content-Type: application/json" --data-binary "@$blockedSessionBodyFile" "$baseUrl/api/v1/prompt"
  } finally {
    if (Test-Path $blockedSessionBodyFile) { Remove-Item -LiteralPath $blockedSessionBodyFile -Force }
  }
  Assert-Contains "session limit blocked detail" $blockedSession "session LLM call limit exceeded"
  Assert-Contains "session limit blocked http status" $blockedSession "429"
  Assert-Contains "session limit blocked error envelope" $blockedSession '"contract_version":"error-response-contract-v1"'
  Assert-Contains "session limit blocked envelope status" $blockedSession '"status_code":429'
  Assert-Contains "session limit blocked envelope evidence" $blockedSession "error_response_429_visible"
} finally {
  docker exec cloud-superbrain-phase1-dev-redis-1 redis-cli DEL $sessionLimitKey | Out-Null
}

Write-Host "[runtime] prompt input guard"
$promptContract = curl.exe -sS "$baseUrl/api/v1/prompt/contract"
Assert-Contains "prompt contract version" $promptContract '"contract_version":"prompt-input-contract-v1"'
Assert-Contains "prompt contract endpoint" $promptContract "POST /api/v1/prompt"
Assert-Contains "prompt contract max chars" $promptContract '"max_prompt_chars":10000'
Assert-Contains "prompt contract evidence visible" $promptContract "prompt_input_contract_visible"
Assert-Contains "prompt counter evidence" $promptContract "prompt_input_counter_visible"
Assert-Contains "prompt 422 evidence" $promptContract "prompt_input_422_enforced"
$promptOverflowProjectId = "runtime-prompt-overflow-" + [Guid]::NewGuid().ToString("N")
$promptOverflowBody = @{
  project_id = $promptOverflowProjectId
  prompt = ("x" * 10001)
  stream = $true
} | ConvertTo-Json -Compress
$promptOverflowBodyFile = Join-Path $env:TEMP ("runtime-prompt-overflow-" + [Guid]::NewGuid().ToString("N") + ".json")
$promptOverflowRequestId = "runtime-request-error-" + [Guid]::NewGuid().ToString("N")
try {
  Set-Content -LiteralPath $promptOverflowBodyFile -Value $promptOverflowBody -NoNewline
  $promptOverflow = curl.exe -sS -w "`n%{http_code}" -X POST -H "Content-Type: application/json" -H "x-request-id: $promptOverflowRequestId" --data-binary "@$promptOverflowBodyFile" "$baseUrl/api/v1/prompt"
} finally {
  if (Test-Path $promptOverflowBodyFile) { Remove-Item -LiteralPath $promptOverflowBodyFile -Force }
}
Assert-Contains "prompt overflow validation type" $promptOverflow "string_too_long"
Assert-Contains "prompt overflow http status" $promptOverflow "422"
Assert-Contains "prompt overflow error envelope" $promptOverflow '"contract_version":"error-response-contract-v1"'
Assert-Contains "prompt overflow envelope status" $promptOverflow '"status_code":422'
Assert-Contains "prompt overflow envelope error" $promptOverflow '"error":"validation_error"'
Assert-Contains "prompt overflow envelope evidence" $promptOverflow "error_response_422_visible"
Assert-Contains "prompt overflow request id field" $promptOverflow '"request_id":'
Assert-Contains "prompt overflow request id value" $promptOverflow $promptOverflowRequestId
Assert-Contains "prompt overflow trace id field" $promptOverflow '"trace_id":'
Assert-Contains "prompt overflow request correlation evidence" $promptOverflow "request_id_error_envelope_correlation"

Write-Host "[runtime] error response contract"
$errorContract = curl.exe -sS "$baseUrl/api/v1/errors/contract"
Assert-Contains "error contract version" $errorContract '"contract_version":"error-response-contract-v1"'
Assert-Contains "error contract mode" $errorContract "structured_http_error_contract"
Assert-Contains "error contract 422 evidence" $errorContract "error_response_422_visible"
Assert-Contains "error contract 429 evidence" $errorContract "error_response_429_visible"
Assert-Contains "error contract ui evidence" $errorContract "error_response_ui_state_visible"
Assert-Contains "error contract envelope evidence" $errorContract "error_response_envelope_enforced"
Assert-Contains "error contract envelope handler" $errorContract "validation_exception_envelope_handler"
Assert-Contains "error contract 503 status" $errorContract "503"

Write-Host "[runtime] security headers contract"
$securityHeadersContract = curl.exe -sS "$baseUrl/api/v1/security/headers/contract"
Assert-Contains "security headers contract version" $securityHeadersContract '"contract_version":"security-headers-v1"'
Assert-Contains "security headers contract middleware" $securityHeadersContract "security_headers_middleware"
Assert-Contains "security headers contract x content type" $securityHeadersContract "X-Content-Type-Options"
Assert-Contains "security headers contract csp" $securityHeadersContract "Content-Security-Policy"
Assert-Contains "security headers contract evidence" $securityHeadersContract "security_headers_enforced"
$securityHeaderProbe = curl.exe -sS -D - -o NUL "$baseUrl/api/v1/health"
Assert-Contains "security header nosniff" $securityHeaderProbe "x-content-type-options: nosniff"
Assert-Contains "security header frame deny" $securityHeaderProbe "x-frame-options: DENY"
Assert-Contains "security header referrer" $securityHeaderProbe "referrer-policy: no-referrer"
Assert-Contains "security header contract marker" $securityHeaderProbe "x-superbrain-security-contract: security-headers-v1"

Write-Host "[runtime] trace id propagation contract"
$traceContract = curl.exe -sS "$baseUrl/api/v1/trace/contract"
Assert-Contains "trace id contract version" $traceContract '"contract_version":"trace-id-propagation-v1"'
Assert-Contains "trace id contract middleware" $traceContract "trace_id_middleware"
Assert-Contains "trace id request header" $traceContract '"request_header":"x-trace-id"'
Assert-Contains "trace id response header" $traceContract '"response_header":"x-trace-id"'
Assert-Contains "trace id roundtrip evidence" $traceContract "trace_id_header_roundtrip"
$traceProbeId = "runtime-trace-proof-" + [Guid]::NewGuid().ToString("N")
$traceHeaderProbe = curl.exe -sS -D - -o NUL -H "x-trace-id: $traceProbeId" "$baseUrl/api/v1/health"
Assert-Contains "trace id response header roundtrip" $traceHeaderProbe "x-trace-id: $traceProbeId"
Assert-Contains "trace id response contract marker" $traceHeaderProbe "x-superbrain-trace-contract: trace-id-propagation-v1"

Write-Host "[runtime] cache control no-store contract"
$cacheControlContract = curl.exe -sS "$baseUrl/api/v1/cache/contract"
Assert-Contains "cache control contract version" $cacheControlContract '"contract_version":"cache-control-no-store-v1"'
Assert-Contains "cache control contract middleware" $cacheControlContract "cache_control_middleware"
Assert-Contains "cache control contract cache header" $cacheControlContract "Cache-Control"
Assert-Contains "cache control contract pragma" $cacheControlContract "Pragma"
Assert-Contains "cache control contract evidence" $cacheControlContract "cache_control_headers_enforced"
$cacheHeaderProbe = curl.exe -sS -D - -o NUL "$baseUrl/api/v1/costs"
Assert-Contains "cache header no-store" $cacheHeaderProbe "cache-control: no-store"
Assert-Contains "cache header pragma" $cacheHeaderProbe "pragma: no-cache"
Assert-Contains "cache header expires" $cacheHeaderProbe "expires: 0"
Assert-Contains "cache header contract marker" $cacheHeaderProbe "x-superbrain-cache-contract: cache-control-no-store-v1"

Write-Host "[runtime] request id correlation contract"
$requestContract = curl.exe -sS "$baseUrl/api/v1/request/contract"
Assert-Contains "request id contract version" $requestContract '"contract_version":"request-id-correlation-v1"'
Assert-Contains "request id contract middleware" $requestContract "request_id_middleware"
Assert-Contains "request id request header" $requestContract '"request_header":"x-request-id"'
Assert-Contains "request id response header" $requestContract '"response_header":"x-request-id"'
Assert-Contains "request id roundtrip evidence" $requestContract "request_id_header_roundtrip"
Assert-Contains "request id audit evidence" $requestContract "request_id_audit_correlation"
$requestProbeId = "runtime-request-proof-" + [Guid]::NewGuid().ToString("N")
$requestHeaderProbe = curl.exe -sS -D - -o NUL -H "x-request-id: $requestProbeId" "$baseUrl/api/v1/health"
Assert-Contains "request id response header roundtrip" $requestHeaderProbe "x-request-id: $requestProbeId"
Assert-Contains "request id response contract marker" $requestHeaderProbe "x-superbrain-request-contract: request-id-correlation-v1"

Write-Host "[runtime] prompt persistence and auto-task"
$projectId = "runtime-proof-" + [Guid]::NewGuid().ToString("N")
$prompt = "runtime verifier postgres write"
$body = @{ project_id = $projectId; prompt = $prompt; stream = $true } | ConvertTo-Json -Compress
$response = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/v1/prompt" -ContentType "application/json" -Body $body
if (-not $response.session_id) { throw "Runtime verification failed: prompt response missing session_id" }
if (-not $response.task_id) { throw "Runtime verification failed: prompt response missing task_id" }
if (-not $response.memory_id) { throw "Runtime verification failed: prompt response missing memory_id" }
if (-not $response.budget -or $response.budget.level -ne "ok") { throw "Runtime verification failed: prompt response missing budget ok metadata" }
if (-not $response.rate_limit) { throw "Runtime verification failed: prompt response missing rate_limit metadata" }

$projectCount = docker exec cloud-superbrain-phase1-dev-postgres-1 psql -U superbrain -d superbrain_prod -tAc "SELECT COUNT(*) FROM projects WHERE metadata->>'external_id'='$projectId';"
Assert-Contains "project persistence" $projectCount "1"
$messageCount = docker exec cloud-superbrain-phase1-dev-postgres-1 psql -U superbrain -d superbrain_prod -tAc "SELECT COUNT(*) FROM agent_messages WHERE session_id='$($response.session_id)' AND content_short='$prompt';"
Assert-Contains "message persistence" $messageCount "1"

Write-Host "[runtime] memory search"
$memoryQuery = [uri]::EscapeDataString("postgres write")
$memorySearch = curl.exe -sS "$baseUrl/api/v1/memory/search?q=$memoryQuery&project_id=$projectId&limit=5"
Assert-Contains "memory search mode" $memorySearch '"search_mode":"lexical_fallback"'
Assert-Contains "memory search content" $memorySearch $prompt
$memoryDeleteProjectId = "runtime-memory-entry-delete-" + [Guid]::NewGuid().ToString("N")
$memoryDeletePrompt = "runtime memory entry delete proof " + [Guid]::NewGuid().ToString("N")
$memoryDeletePromptBody = @{ project_id = $memoryDeleteProjectId; prompt = $memoryDeletePrompt; stream = $true } | ConvertTo-Json -Compress
$memoryDeletePromptResponse = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/v1/prompt" -ContentType "application/json" -Body $memoryDeletePromptBody
$memoryDeleteQuery = [uri]::EscapeDataString("runtime memory entry delete proof")
$memoryDeleteSearchBefore = curl.exe -sS "$baseUrl/api/v1/memory/search?q=$memoryDeleteQuery&project_id=$memoryDeleteProjectId&limit=5"
Assert-Contains "memory entry delete precondition content" $memoryDeleteSearchBefore $memoryDeletePrompt
$memoryDeleteBlocked = curl.exe -sS -w "`n%{http_code}" -X DELETE "$baseUrl/api/v1/memory/$($memoryDeletePromptResponse.memory_id)?project_id=$memoryDeleteProjectId&confirm=false"
Assert-Contains "memory entry delete confirmation required" $memoryDeleteBlocked "memory_entry_delete_confirmation_required"
Assert-Contains "memory entry delete confirmation required status" $memoryDeleteBlocked "400"
$memoryDeleteResult = Invoke-RestMethod -Method Delete -Uri "$baseUrl/api/v1/memory/$($memoryDeletePromptResponse.memory_id)?project_id=$memoryDeleteProjectId&confirm=true&reason=runtime_single_entry_delete_proof&trace_id=runtime-memory-entry-delete-completed"
if ($memoryDeleteResult.status -ne "deleted") { throw "Runtime verification failed: memory entry delete did not return deleted status" }
if ($memoryDeleteResult.evidence_ref -ne "memory_entry_delete_completed") { throw "Runtime verification failed: memory entry delete evidence ref mismatch" }
$memorySearchAfterDelete = curl.exe -sS "$baseUrl/api/v1/memory/search?q=$memoryDeleteQuery&project_id=$memoryDeleteProjectId&limit=5"
if (($memorySearchAfterDelete | Out-String).Contains($memoryDeletePrompt)) {
  throw "Runtime verification failed: memory entry delete search still returned deleted prompt"
}
$memoryDeleteAudit = curl.exe -sS "$baseUrl/api/v1/audit/recent?limit=80"
Assert-Contains "memory entry delete audit event" $memoryDeleteAudit "memory_entry_deleted"
Assert-Contains "memory entry delete audit trace" $memoryDeleteAudit "runtime-memory-entry-delete-completed"

Write-Host "[runtime] memory purge contract"
$purgeProjectId = "runtime-memory-purge-" + [Guid]::NewGuid().ToString("N")
$purgePrompt = "runtime memory purge proof " + [Guid]::NewGuid().ToString("N")
$purgePromptBody = @{ project_id = $purgeProjectId; prompt = $purgePrompt; stream = $true } | ConvertTo-Json -Compress
$purgePromptResponse = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/v1/prompt" -ContentType "application/json" -Body $purgePromptBody
if (-not $purgePromptResponse.session_id) { throw "Runtime verification failed: memory purge prompt response missing session_id" }
$purgeSearchQuery = [uri]::EscapeDataString($purgePrompt)
$purgeSearchBefore = curl.exe -sS "$baseUrl/api/v1/memory/search?q=$purgeSearchQuery&project_id=$purgeProjectId&limit=5"
Assert-Contains "memory purge precondition content" $purgeSearchBefore $purgePrompt
$purgeContract = curl.exe -sS "$baseUrl/api/v1/memory/purge/contract"
Assert-Contains "memory purge contract version" $purgeContract '"contract_version":"memory-dsgvo-purge-v1"'
Assert-Contains "memory purge contract endpoint" $purgeContract 'DELETE /api/v1/memory?project_id={id}&confirm=true'
Assert-Contains "memory purge job status endpoint" $purgeContract 'GET /api/v1/memory/purge/jobs/{job_id}'
Assert-Contains "memory purge evidence completed" $purgeContract "memory_purge_completed"
Assert-Contains "memory purge job status evidence" $purgeContract "memory_purge_job_status_visible"
Assert-Contains "memory purge evidence blocked" $purgeContract "memory_purge_confirmation_required"
Assert-Contains "memory purge nonclaim langfuse" $purgeContract "does not delete Langfuse traces"
$purgeBlocked = curl.exe -sS -w "`n%{http_code}" -X DELETE "$baseUrl/api/v1/memory?project_id=$purgeProjectId&confirm=false"
Assert-Contains "memory purge confirmation required" $purgeBlocked "confirmation_required"
Assert-Contains "memory purge confirmation required status" $purgeBlocked "400"
$purgeResult = Invoke-RestMethod -Method Delete -Uri "$baseUrl/api/v1/memory?project_id=$purgeProjectId&confirm=true&reason=runtime_purge_proof&trace_id=runtime-memory-purge-completed"
if ($purgeResult.status -ne "completed") { throw "Runtime verification failed: memory purge did not complete" }
if ($purgeResult.project_found -ne $true) { throw "Runtime verification failed: memory purge did not find scoped project" }
if ($purgeResult.evidence_ref -ne "memory_purge_completed") { throw "Runtime verification failed: memory purge evidence ref mismatch" }
if (-not $purgeResult.job_id) { throw "Runtime verification failed: memory purge result missing job_id" }
if (-not $purgeResult.job_status_url) { throw "Runtime verification failed: memory purge result missing job_status_url" }
if ([int]$purgeResult.deleted_counts.memory_entries -lt 1) { throw "Runtime verification failed: memory purge deleted no memory entries" }
if ([int]$purgeResult.deleted_counts.agent_sessions -lt 1) { throw "Runtime verification failed: memory purge deleted no agent sessions" }
$purgeJobStatus = Invoke-RestMethod -Method Get -Uri "$baseUrl/api/v1/memory/purge/jobs/$($purgeResult.job_id)"
if ($purgeJobStatus.status -ne "completed") { throw "Runtime verification failed: memory purge job status was not completed" }
if ($purgeJobStatus.evidence_ref -ne "memory_purge_job_status_visible") { throw "Runtime verification failed: memory purge job status evidence mismatch" }
if ([int]$purgeJobStatus.deleted_counts.memory_entries -lt 1) { throw "Runtime verification failed: memory purge job status missing deleted memory count" }
$purgeSearchAfter = curl.exe -sS "$baseUrl/api/v1/memory/search?q=$purgeSearchQuery&project_id=$purgeProjectId&limit=5"
if (($purgeSearchAfter | Out-String).Contains($purgePrompt)) {
  throw "Runtime verification failed: memory purge search still returned purged prompt"
}
$purgeAudit = curl.exe -sS "$baseUrl/api/v1/audit/recent?limit=80"
Assert-Contains "memory purge audit completed" $purgeAudit "memory_purge_completed"
Assert-Contains "memory purge audit trace" $purgeAudit "runtime-memory-purge-completed"

Write-Host "[runtime] secret redaction persistence"
$secretProjectId = "runtime-secret-redaction-" + [Guid]::NewGuid().ToString("N")
$fakeSecret = "sk-" + "runtimeproof1234567890abcdef"
$secretPrompt = "runtime secret redaction proof $fakeSecret"
$secretBody = @{ project_id = $secretProjectId; prompt = $secretPrompt; stream = $true } | ConvertTo-Json -Compress
$secretResponse = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/v1/prompt" -ContentType "application/json" -Body $secretBody
if (-not $secretResponse.session_id) { throw "Runtime verification failed: secret redaction response missing session_id" }
$rawSecretMessageCount = docker exec cloud-superbrain-phase1-dev-postgres-1 psql -U superbrain -d superbrain_prod -tAc "SELECT COUNT(*) FROM agent_messages WHERE session_id='$($secretResponse.session_id)' AND content_short LIKE '%$fakeSecret%';"
Assert-Contains "raw secret absent from messages" $rawSecretMessageCount "0"
$maskedSecretMessageCount = docker exec cloud-superbrain-phase1-dev-postgres-1 psql -U superbrain -d superbrain_prod -tAc "SELECT COUNT(*) FROM agent_messages WHERE session_id='$($secretResponse.session_id)' AND content_short LIKE '%***MASKED_SECRET***%';"
Assert-Contains "masked secret present in messages" $maskedSecretMessageCount "1"
$rawSecretMemoryCount = docker exec cloud-superbrain-phase1-dev-postgres-1 psql -U superbrain -d superbrain_prod -tAc "SELECT COUNT(*) FROM memory_entries WHERE session_id='$($secretResponse.session_id)' AND content_text LIKE '%$fakeSecret%';"
Assert-Contains "raw secret absent from memory" $rawSecretMemoryCount "0"
$maskedSecretMemoryCount = docker exec cloud-superbrain-phase1-dev-postgres-1 psql -U superbrain -d superbrain_prod -tAc "SELECT COUNT(*) FROM memory_entries WHERE session_id='$($secretResponse.session_id)' AND content_text LIKE '%***MASKED_SECRET***%';"
Assert-Contains "masked secret present in memory" $maskedSecretMemoryCount "1"
$secretMemorySearch = curl.exe -sS "$baseUrl/api/v1/memory/search?q=runtime%20secret%20redaction&project_id=$secretProjectId&limit=5"
Assert-Contains "secret memory search masked" $secretMemorySearch "***MASKED_SECRET***"
if (($secretMemorySearch | Out-String).Contains($fakeSecret)) {
  throw "Runtime verification failed: memory search leaked raw fake secret"
}

Write-Host "[runtime] agent-worker auto-task completion"
$autoTask = Wait-TaskCompleted $response.task_id
Assert-Contains "auto task completed" $autoTask '"status":"completed"'
Assert-Contains "auto task result envelope" $autoTask '"result_envelope"'
Assert-Contains "auto task envelope evidence" $autoTask "agent-worker:deterministic-completion"
Assert-Contains "auto task done validation implemented" $autoTask '"implemented":true'
Assert-Contains "auto task done validation tested" $autoTask '"tested":true'
Assert-Contains "auto task done validation integrated" $autoTask '"integrated":true'
Assert-Contains "auto task done validation reported" $autoTask '"reported":true'
Assert-Contains "auto task done validation logged" $autoTask '"logged":true'
$workerMessageCount = docker exec cloud-superbrain-phase1-dev-postgres-1 psql -U superbrain -d superbrain_prod -tAc "SELECT COUNT(*) FROM agent_messages WHERE metadata->>'task_id'='$($response.task_id)' AND agent_type='planner' AND role='assistant';"
Assert-Contains "worker message persistence" $workerMessageCount "1"
$workerAuditCount = docker exec cloud-superbrain-phase1-dev-postgres-1 psql -U superbrain -d superbrain_prod -tAc "SELECT COUNT(*) FROM audit_log WHERE event_type='task_completed' AND details->>'task_id'='$($response.task_id)';"
Assert-Contains "worker audit persistence" $workerAuditCount "1"
$workerDoneValidationCount = docker exec cloud-superbrain-phase1-dev-postgres-1 psql -U superbrain -d superbrain_prod -tAc "SELECT COUNT(*) FROM audit_log WHERE event_type='task_completed' AND details->>'task_id'='$($response.task_id)' AND details->'done_validation'->>'implemented'='true' AND details->'done_validation'->>'tested'='true' AND details->'done_validation'->>'integrated'='true' AND details->'done_validation'->>'reported'='true' AND details->'done_validation'->>'logged'='true';"
Assert-Contains "worker done validation audit persistence" $workerDoneValidationCount "1"
$agentStatus = curl.exe -sS "$baseUrl/api/v1/agents/status"
Assert-Contains "agent status planner" $agentStatus '"type":"planner"'
Assert-Contains "agent status profile contract" $agentStatus '"profile_contract_version":"agent-profiles-v1"'
Assert-Contains "agent status coder profile" $agentStatus '"type":"coder"'
Assert-Contains "agent status coder max execution" $agentStatus '"max_execution_seconds":300'
Assert-Contains "agent status tester degradation" $agentStatus "If E2B is unavailable"
Assert-Contains "agent status devops human gate" $agentStatus "workflow_dispatch_production"
Assert-Contains "agent status queue depth" $agentStatus '"queue_depth"'
$agentProfiles = curl.exe -sS "$baseUrl/api/v1/agents/profiles"
Assert-Contains "agent profiles contract" $agentProfiles '"profile_contract_version":"agent-profiles-v1"'
Assert-Contains "agent profiles max retry" $agentProfiles '"max_retry_global":5'
Assert-Contains "agent profiles planner" $agentProfiles '"agent_type":"planner"'
Assert-Contains "agent profiles coder output" $agentProfiles '"max_output_tokens":8192'
Assert-Contains "agent profiles tester execution" $agentProfiles '"max_execution_seconds":600'
Assert-Contains "agent profiles devops execution" $agentProfiles '"max_execution_seconds":120'
Assert-Contains "agent profiles done validation" $agentProfiles '"done_validation_required":["implemented","tested","integrated","reported","logged"]'
Assert-Contains "agent profiles blocked main" $agentProfiles "push_main"
$recentTasks = curl.exe -sS "$baseUrl/api/v1/tasks/recent?limit=10"
Assert-Contains "recent tasks id" $recentTasks $response.task_id
Assert-Contains "recent tasks status" $recentTasks '"status":"completed"'
Assert-Contains "recent tasks result envelope" $recentTasks '"result_envelope"'
Assert-Contains "recent tasks done validation" $recentTasks '"done_validation"'
Assert-Contains "recent tasks queue depth" $recentTasks '"queue_depth"'
$recentSessions = curl.exe -sS "$baseUrl/api/v1/sessions/recent?limit=5"
Assert-Contains "recent sessions id" $recentSessions $response.session_id
Assert-Contains "recent sessions task" $recentSessions $response.task_id
Assert-Contains "recent sessions worker result" $recentSessions "Phase-1 worker completed deterministic execution without LLM calls"
$auditEvents = curl.exe -sS "$baseUrl/api/v1/audit/recent?limit=10"
Assert-Contains "audit event type" $auditEvents "task_completed"
Assert-Contains "audit task id" $auditEvents $response.task_id
Assert-Contains "audit severity" $auditEvents '"severity":"info"'

Write-Host "[runtime] sse stream"
$sseUrl = "$baseUrl$($response.stream_url)"
$sse = Wait-SseContains "sse event id" $sseUrl "id: " 4 10
Assert-Contains "sse event id" $sse "id: "
Assert-Contains "sse heartbeat" $sse "event: heartbeat"
Assert-Contains "sse worker token" $sse "Phase-1 worker completed deterministic execution without LLM calls"
Assert-Contains "sse task id" $sse $response.task_id
Assert-Contains "sse done" $sse "event: done"

Write-Host "[runtime] sse replay"
$sseReplay = Wait-SseContains "sse replay flag" $sseUrl '"replay":true' 4 8 "0"
Assert-Contains "sse replay flag" $sseReplay '"replay":true'
Assert-Contains "sse replay task id" $sseReplay $response.task_id
Assert-Contains "sse replay token" $sseReplay "Phase-1 worker completed deterministic execution without LLM calls"
Assert-Contains "sse replay done" $sseReplay "event: done"

Write-Host "[runtime] internal memory"
$internalMemory = docker exec cloud-superbrain-phase1-dev-agent-api-1 python -c "import json, urllib.parse, urllib.request; data=json.dumps({'project_id':'$projectId','session_id':None,'content_text':'internal memory verifier needle','metadata':{'source':'runtime'}}).encode(); req=urllib.request.Request('http://127.0.0.1:8000/internal/memory', data=data, headers={'Content-Type':'application/json'}, method='POST'); print(urllib.request.urlopen(req, timeout=5).read().decode()); print(urllib.request.urlopen('http://127.0.0.1:8000/api/v1/memory/search?q=' + urllib.parse.quote('verifier needle') + '&project_id=$projectId&limit=5', timeout=5).read().decode())"
Assert-Contains "internal memory write" $internalMemory '"memory_id"'
Assert-Contains "internal memory search" $internalMemory 'internal memory verifier needle'

Write-Host "[runtime] memory consolidation worker"
$memoryConsolidationNeedle = "working memory consolidation verifier " + [Guid]::NewGuid().ToString("N")
$memoryIdempotencyKey = "runtime-memory-consolidation-" + [Guid]::NewGuid().ToString("N")
docker exec cloud-superbrain-phase1-dev-agent-api-1 python -c "import json, os, redis; client=redis.Redis.from_url(os.environ['REDIS_URL']); payload={'project_id':'$projectId','session_id':'$($response.session_id)','content_text':'$memoryConsolidationNeedle','metadata':{'source':'runtime_consolidation_verifier'},'idempotency_key':'$memoryIdempotencyKey'}; client.set('memory:working:$memoryIdempotencyKey', json.dumps(payload), ex=300); print(client.ttl('memory:working:$memoryIdempotencyKey'))"
Assert-LastExitCode "seed working memory redis key"
$consolidationRun = docker exec cloud-superbrain-phase1-dev-memory-worker-1 python -m app.worker --once
if (-not (($consolidationRun | Out-String).Contains('"consolidated": 1'))) {
  Write-Host "[runtime] memory worker one-shot did not claim the key; checking DB/audit truth in case the daemon consumed it first"
}
$consolidatedMemoryCount = docker exec cloud-superbrain-phase1-dev-postgres-1 psql -U superbrain -d superbrain_prod -tAc "SELECT COUNT(*) FROM memory_entries WHERE metadata->>'idempotency_key'='$memoryIdempotencyKey' AND content_text='$memoryConsolidationNeedle' AND consolidation_status='consolidated';"
Assert-Contains "memory consolidation persistence" $consolidatedMemoryCount "1"
$consolidationAuditCount = docker exec cloud-superbrain-phase1-dev-postgres-1 psql -U superbrain -d superbrain_prod -tAc "SELECT COUNT(*) FROM audit_log WHERE event_type='memory_consolidated' AND details->>'idempotency_key'='$memoryIdempotencyKey';"
Assert-Contains "memory consolidation audit" $consolidationAuditCount "1"
$memoryConsolidationSearchQuery = [uri]::EscapeDataString($memoryConsolidationNeedle)
$memoryConsolidationSearch = curl.exe -sS "$baseUrl/api/v1/memory/search?q=$memoryConsolidationSearchQuery&project_id=$projectId&limit=5"
Assert-Contains "memory consolidation search" $memoryConsolidationSearch $memoryConsolidationNeedle
$memoryConsolidationFeed = curl.exe -sS "$baseUrl/api/v1/memory/consolidation/recent?limit=20"
Assert-Contains "memory consolidation feed event" $memoryConsolidationFeed "memory_consolidated"
Assert-Contains "memory consolidation feed idempotency" $memoryConsolidationFeed $memoryIdempotencyKey

Write-Host "[runtime] internal task queue"
$manualTask = docker exec cloud-superbrain-phase1-dev-agent-api-1 python -c "import json, urllib.request; data=json.dumps({'project_id':'runtime-task','session_id':'$($response.session_id)','agent_type':'planner','task_type':'runtime_smoke','task_description':'runtime internal task smoke','priority':5,'max_retries':5}).encode(); req=urllib.request.Request('http://127.0.0.1:8000/api/v1/internal/tasks', data=data, headers={'Content-Type':'application/json'}, method='POST'); print(urllib.request.urlopen(req, timeout=5).read().decode())"
Assert-Contains "internal task queue depth" $manualTask '"queue_depth"'
Assert-Contains "manual internal task" $manualTask '"status":"queued"'
Assert-Contains "manual internal task id" $manualTask '"task_id"'
$manualTaskJson = ($manualTask | Out-String).Trim()
$manualTaskObject = $manualTaskJson | ConvertFrom-Json
$manualTaskId = $manualTaskObject.task.task_id
if (-not $manualTaskId) {
  throw "Runtime verification failed: manual task response missing parsed task_id. Value: $manualTaskJson"
}
$manualTaskCompleted = Wait-TaskCompleted $manualTaskId
Assert-Contains "manual task completed" $manualTaskCompleted '"status":"completed"'

Write-Host "[runtime] task policy gate"
$taskPolicy = curl.exe -sS "$baseUrl/api/v1/tasks/policy"
Assert-Contains "task policy fail closed" $taskPolicy '"mode":"fail_closed_before_enqueue"'
Assert-Contains "task policy profile contract" $taskPolicy '"profile_contract_version":"agent-profiles-v1"'
Assert-Contains "task policy profile gates" $taskPolicy '"profile_gates"'
Assert-Contains "task policy devops profile gate" $taskPolicy '"agent_type":"devops"'
Assert-Contains "task policy required push block" $taskPolicy "push_main"
Assert-Contains "task policy write scope rule" $taskPolicy "write_scope_required_for"
$acceptedPolicyBody = @{
  project_id = "runtime-policy-accepted"
  session_id = $response.session_id
  agent_type = "coder"
  task_type = "implementation"
  task_description = "implement scoped file change"
  priority = 5
  max_retries = 5
  allowed_tools = @("memory_read", "filesystem_mcp")
  write_scope = @("services/agent-api/app/tasks.py")
  blocked_actions = @("push_main", "prod_deploy", "secret_change", "live_provider_call", "force_push", "production_db_write")
  acceptance_criteria = @("result_envelope", "done_validation", "audit_log")
  human_review_required = $true
} | ConvertTo-Json -Compress
$acceptedPolicy = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/v1/tasks/policy/validate" -ContentType "application/json" -Body $acceptedPolicyBody
if ($acceptedPolicy.status -ne "accepted") { throw "Runtime verification failed: profile-valid task policy was not accepted" }
if ($acceptedPolicy.policy.profile_contract_version -ne "agent-profiles-v1") { throw "Runtime verification failed: accepted policy missing profile contract version" }
$blockedPolicyBody = @{
  project_id = "runtime-policy-block"
  session_id = $response.session_id
  agent_type = "coder"
  task_type = "implementation"
  task_description = "implement unsafe file write without scope"
  priority = 5
  max_retries = 5
  allowed_tools = @("filesystem_mcp")
  write_scope = @()
  blocked_actions = @("push_main", "prod_deploy", "secret_change", "live_provider_call", "force_push", "production_db_write")
  acceptance_criteria = @("result_envelope", "done_validation", "audit_log")
  human_review_required = $true
} | ConvertTo-Json -Compress
$blockedBodyFile = Join-Path $env:TEMP ("task-policy-block-" + [Guid]::NewGuid().ToString("N") + ".json")
$blockedOutFile = Join-Path $env:TEMP ("task-policy-block-out-" + [Guid]::NewGuid().ToString("N") + ".json")
try {
  Set-Content -Path $blockedBodyFile -Value $blockedPolicyBody -NoNewline -Encoding utf8
  $blockedStatus = curl.exe -sS -o $blockedOutFile -w "%{http_code}" -X POST -H "Content-Type: application/json" --data-binary "@$blockedBodyFile" "$baseUrl/api/v1/tasks/policy/validate"
  if ($blockedStatus -ne "403") {
    $blockedUnexpected = Get-Content -Path $blockedOutFile -Raw
    throw "Runtime verification failed: policy validate expected 403 but got $blockedStatus. Value: $blockedUnexpected"
  }
  $blockedOut = Get-Content -Path $blockedOutFile -Raw
} finally {
  if (Test-Path $blockedBodyFile) { Remove-Item -LiteralPath $blockedBodyFile -Force }
  if (Test-Path $blockedOutFile) { Remove-Item -LiteralPath $blockedOutFile -Force }
}
Assert-Contains "task policy block code" $blockedOut "task_policy_violation"
Assert-Contains "task policy block write scope" $blockedOut "write_scope"
$profileBlockedBody = @{
  project_id = "runtime-policy-profile-block"
  session_id = $response.session_id
  agent_type = "planner"
  task_type = "planning"
  task_description = "plan task but request github write tool"
  priority = 5
  max_retries = 5
  allowed_tools = @("github_mcp")
  write_scope = @()
  blocked_actions = @("push_main", "prod_deploy", "secret_change", "live_provider_call", "force_push", "production_db_write")
  acceptance_criteria = @("result_envelope", "done_validation", "audit_log")
  human_review_required = $true
} | ConvertTo-Json -Compress
$profileBlockedBodyFile = Join-Path $env:TEMP ("runtime-task-policy-profile-block-" + [Guid]::NewGuid().ToString("N") + ".json")
$profileBlockedOutFile = Join-Path $env:TEMP ("runtime-task-policy-profile-block-out-" + [Guid]::NewGuid().ToString("N") + ".json")
try {
  Set-Content -Path $profileBlockedBodyFile -Value $profileBlockedBody -NoNewline -Encoding utf8
  $profileBlockedStatus = curl.exe -sS -o $profileBlockedOutFile -w "%{http_code}" -X POST -H "Content-Type: application/json" --data-binary "@$profileBlockedBodyFile" "$baseUrl/api/v1/tasks/policy/validate"
  if ($profileBlockedStatus -ne "403") {
    $profileBlockedUnexpected = Get-Content -Path $profileBlockedOutFile -Raw
    throw "Runtime verification failed: profile gate expected 403 but got $profileBlockedStatus. Value: $profileBlockedUnexpected"
  }
  $profileBlockedOut = Get-Content -Path $profileBlockedOutFile -Raw
} finally {
  if (Test-Path $profileBlockedBodyFile) { Remove-Item -LiteralPath $profileBlockedBodyFile -Force }
  if (Test-Path $profileBlockedOutFile) { Remove-Item -LiteralPath $profileBlockedOutFile -Force }
}
Assert-Contains "task policy profile block code" $profileBlockedOut "task_policy_violation"
Assert-Contains "task policy profile block tool gate" $profileBlockedOut "profile does not allow tools"
$blockedInternal = docker exec cloud-superbrain-phase1-dev-agent-api-1 python -c "import json, urllib.error, urllib.request; data=json.dumps({'project_id':'runtime-policy-block','session_id':'$($response.session_id)','agent_type':'coder','task_type':'implementation','task_description':'implement unsafe file write without scope','priority':5,'max_retries':5,'allowed_tools':['filesystem_mcp'],'write_scope':[],'blocked_actions':['push_main','prod_deploy','secret_change','live_provider_call','force_push','production_db_write'],'acceptance_criteria':['result_envelope','done_validation','audit_log'],'human_review_required':True}).encode(); req=urllib.request.Request('http://127.0.0.1:8000/api/v1/internal/tasks', data=data, headers={'Content-Type':'application/json'}, method='POST');`ntry:`n print(urllib.request.urlopen(req, timeout=5).read().decode())`nexcept urllib.error.HTTPError as exc:`n print(str(exc.code) + ':' + exc.read().decode())"
Assert-Contains "internal task policy block status" $blockedInternal "403:"
Assert-Contains "internal task policy block code" $blockedInternal "task_policy_violation"
$policyAudit = curl.exe -sS "$baseUrl/api/v1/audit/recent?limit=30"
Assert-Contains "task policy audit event" $policyAudit "task_policy_blocked"
Assert-Contains "task policy audit severity" $policyAudit '"severity":"critical"'

Write-Host "[runtime] task session UUID fail-closed"
$invalidTaskOut = docker exec cloud-superbrain-phase1-dev-agent-api-1 python -c "import json, urllib.error, urllib.request; data=json.dumps({'project_id':'runtime-invalid-session','session_id':'not-a-uuid','agent_type':'planner','task_type':'runtime_invalid_session','task_description':'runtime task session UUID fail-closed smoke','priority':5,'max_retries':2}).encode(); req=urllib.request.Request('http://127.0.0.1:8000/api/v1/internal/tasks', data=data, headers={'Content-Type':'application/json'}, method='POST');`ntry:`n print(urllib.request.urlopen(req, timeout=5).read().decode())`nexcept urllib.error.HTTPError as exc:`n print(str(exc.code) + ':' + exc.read().decode())"
Assert-Contains "invalid task session status" $invalidTaskOut "422:"
Assert-Contains "invalid task session uuid error" $invalidTaskOut "session_id must be a valid UUID"

Write-Host "[runtime] budget endpoint"
$budget = curl.exe -sS "$baseUrl/api/v1/budget"
Assert-Contains "budget endpoint" $budget '"level":"ok"'
Assert-Contains "budget endpoint limit" $budget '"budget_limit_cents":20000'

Write-Host "[runtime] infrastructure budget endpoint"
$infraBudget = curl.exe -sS "$baseUrl/api/v1/infra/budget"
Assert-Contains "infra budget level" $infraBudget '"level":"ok"'
Assert-Contains "infra budget projected" $infraBudget '"projected_cost_cents":900'
Assert-Contains "infra budget limit" $infraBudget '"budget_limit_cents":2000'
Assert-Contains "infra budget source" $infraBudget '"source":"configured_phase1_projection"'
Assert-Contains "infra budget live verified false" $infraBudget '"live_verified":false'
Assert-Contains "infra budget production item" $infraBudget "hetzner-production-cx21"

Write-Host "[runtime] external gates endpoint"
$externalGates = curl.exe -sS "$baseUrl/api/v1/external-gates"
Assert-Contains "external gates contract" $externalGates '"contract_version":"external-gates-state-v1"'
Assert-Contains "external gates endpoint" $externalGates '"endpoint":"GET /api/v1/external-gates"'
Assert-Contains "external gates evidence" $externalGates '"evidence_ref":"external_gates_state_visible"'
Assert-Contains "external gates aligned with preflight" $externalGates '"aligned_with_deployment_preflight":true'
Assert-Contains "external gates status" $externalGates '"status":"verified"'
Assert-Contains "external gates local allowed" $externalGates '"local_execution_allowed":true'
Assert-Contains "external gates branch token" $externalGates '"id":"branch_protection_token"'
Assert-Contains "external gates staging url" $externalGates '"id":"staging_base_url"'
Assert-Contains "external gates hetzner token" $externalGates '"id":"hetzner_api_token"'
Assert-Contains "external gates ghcr digest" $externalGates '"id":"ghcr_image_digest_proof"'
Assert-Contains "external gates vercel origins" $externalGates '"id":"vercel_backend_origins"'
Assert-Contains "external gates gitleaks" $externalGates '"id":"gitleaks_binary"'
Assert-Contains "external gates blocked ghcr" $externalGates '"ghcr_images"'
Assert-Contains "external gates blocked hosted origins" $externalGates '"hosted_backend_origins"'
$externalGateMirror = curl.exe -sS "$baseUrl/api/v1/external-gates/mirror"
Assert-Contains "external gate mirror contract" $externalGateMirror '"contract_version":"external-gate-mirror-v1"'
Assert-Contains "external gate mirror status" $externalGateMirror '"status":"verified"'
Assert-Contains "external gate mirror evidence" $externalGateMirror '"evidence_ref":"external_gate_mirror_proof"'
Assert-Contains "external gate mirror hosted allowed" $externalGateMirror '"hosted_staging_claim_allowed":true'
Assert-Contains "external gate mirror branch protection allowed" $externalGateMirror '"branch_protection_claim_allowed":true'
Assert-Contains "external gate mirror branch protection evidence" $externalGateMirror '"branch_protection_evidence_ref":"branch_protection_verify_contract"'
Assert-Contains "external gate mirror branch protection workflow" $externalGateMirror ".github/workflows/branch-protection.yml"
Assert-Contains "external gate mirror branch protection verifier" $externalGateMirror "scripts/apply_github_branch_protection.py --verify-only"
Assert-Contains "external gate mirror production allowed" $externalGateMirror '"production_deploy_claim_allowed":true'
Assert-Contains "external gate mirror workflow" $externalGateMirror ".github/workflows/hosted-staging-proof.yml"
Assert-Contains "external gate mirror phase2 runtime" $externalGateMirror "phase2-runtime-v1"
Assert-Contains "external gate mirror phase2 sse" $externalGateMirror "phase2-sse-event-contract-v1"
Assert-Contains "external gate mirror project progress proof" $externalGateMirror "project_progress_manifest_proof"

Write-Host "[runtime] auth contract and refresh rotation"
$authContract = curl.exe -sS "$baseUrl/api/v1/auth/contract"
Assert-Contains "auth contract version" $authContract '"contract_version":"auth-github-jwt-refresh-v1"'
Assert-Contains "auth contract no live oauth" $authContract '"live_github_oauth_call":false'
Assert-Contains "auth contract access ttl" $authContract '"access_token_ttl_seconds":900'
Assert-Contains "auth contract refresh ttl" $authContract '"ttl_seconds":604800'
Assert-Contains "auth contract rotation" $authContract '"rotation_required":true'
Assert-Contains "auth contract redis blacklist" $authContract '"blacklist_store":"redis"'
Assert-Contains "auth contract httponly" $authContract '"HttpOnly":true'
Assert-Contains "auth contract secure" $authContract '"Secure":true'
Assert-Contains "auth contract same site" $authContract '"SameSite":"Strict"'
$authGithub = curl.exe -sS "$baseUrl/api/v1/auth/github"
Assert-Contains "auth github contract version" $authGithub '"contract_version":"auth-github-jwt-refresh-v1"'
Assert-Contains "auth github no live oauth" $authGithub '"live_github_oauth_call":false'
Assert-Contains "auth github authorize url" $authGithub "github.com/login/oauth/authorize"
$authCallback = Invoke-RestMethod -Method Get -Uri "$baseUrl/api/v1/auth/callback?code=runtime-auth-code&state=runtime-auth-state"
if ($authCallback.status -ne "authenticated") { throw "Runtime verification failed: auth callback did not authenticate" }
if ($authCallback.live_github_oauth_call -ne $false) { throw "Runtime verification failed: auth callback attempted live GitHub OAuth" }
if ($authCallback.cookie_flags.SameSite -ne "Strict") { throw "Runtime verification failed: auth callback cookie SameSite was not Strict" }
$authRefreshToken = "runtime-refresh-token-" + [Guid]::NewGuid().ToString("N")
$authRefreshBody = @{ refresh_token = $authRefreshToken; trace_id = "runtime-auth-refresh-rotated" } | ConvertTo-Json -Compress
$authRefresh = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/v1/auth/refresh" -ContentType "application/json" -Body $authRefreshBody
if ($authRefresh.status -ne "rotated") { throw "Runtime verification failed: auth refresh did not rotate" }
if ($authRefresh.refresh_token_rotated -ne $true) { throw "Runtime verification failed: auth refresh did not mark rotation true" }
if ($authRefresh.old_refresh_token_blacklisted -ne $true) { throw "Runtime verification failed: auth refresh did not blacklist old token" }
$authReuseFile = Join-Path $env:TEMP ("auth-refresh-reuse-" + [Guid]::NewGuid().ToString("N") + ".json")
$authReuseOutFile = Join-Path $env:TEMP ("auth-refresh-reuse-out-" + [Guid]::NewGuid().ToString("N") + ".json")
try {
  Set-Content -LiteralPath $authReuseFile -Value $authRefreshBody -NoNewline -Encoding utf8
  $authReuseStatus = curl.exe -sS -o $authReuseOutFile -w "%{http_code}" -X POST -H "Content-Type: application/json" --data-binary "@$authReuseFile" "$baseUrl/api/v1/auth/refresh"
  if ($authReuseStatus -ne "401") {
    $authReuseUnexpected = Get-Content -Path $authReuseOutFile -Raw
    throw "Runtime verification failed: auth refresh reuse expected 401 but got $authReuseStatus. Value: $authReuseUnexpected"
  }
  $authReuseOut = Get-Content -Path $authReuseOutFile -Raw
} finally {
  if (Test-Path $authReuseFile) { Remove-Item -LiteralPath $authReuseFile -Force }
  if (Test-Path $authReuseOutFile) { Remove-Item -LiteralPath $authReuseOutFile -Force }
}
Assert-Contains "auth refresh reuse blocked" $authReuseOut "refresh_token_invalid"
$authLogoutBody = @{ refresh_token = ("runtime-logout-token-" + [Guid]::NewGuid().ToString("N")); trace_id = "runtime-auth-logout-revoked" } | ConvertTo-Json -Compress
$authLogout = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/v1/auth/logout" -ContentType "application/json" -Body $authLogoutBody
if ($authLogout.status -ne "logged_out") { throw "Runtime verification failed: auth logout did not complete" }
if ($authLogout.refresh_token_revoked -ne $true) { throw "Runtime verification failed: auth logout did not revoke refresh token" }
$authAudit = curl.exe -sS "$baseUrl/api/v1/audit/recent?limit=60"
Assert-Contains "auth audit refresh rotated" $authAudit "auth_refresh_rotated"
Assert-Contains "auth audit refresh reuse blocked" $authAudit "auth_refresh_reuse_blocked"
Assert-Contains "auth audit logout revoked" $authAudit "auth_logout_revoked"

Write-Host "[runtime] devops workflow dispatch contract"
$workflowPlan = curl.exe -sS "$baseUrl/api/v1/devops/workflow-dispatch/plan"
Assert-Contains "workflow dispatch contract version" $workflowPlan '"contract_version":"devops-workflow-dispatch-v1"'
Assert-Contains "workflow dispatch dry mode" $workflowPlan '"mode":"dry_run_contract_only"'
Assert-Contains "workflow dispatch no live call" $workflowPlan '"live_github_call":false'
Assert-Contains "workflow dispatch github endpoint" $workflowPlan "/actions/workflows/main-deploy.yml/dispatches"
Assert-Contains "workflow dispatch actions permission" $workflowPlan '"required_permission":"actions:write"'
$workflowReadyBody = @{
  workflow_id = "main-deploy.yml"
  ref = "main"
  environment = "staging"
  action = "deploy"
  image_tag = "ghcr.io/repo/agent-api:runtime-proof"
  reason = "runtime staging dispatch proof"
  trace_id = "runtime-devops-dispatch-ready"
  human_review_approved = $false
  dry_run = $true
} | ConvertTo-Json -Compress
$workflowReady = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/v1/devops/workflow-dispatch/validate" -ContentType "application/json" -Body $workflowReadyBody
if ($workflowReady.status -ne "ready") { throw "Runtime verification failed: staging workflow dispatch contract was not ready" }
if ($workflowReady.live_github_call -ne $false) { throw "Runtime verification failed: workflow dispatch attempted live GitHub call" }
if ($workflowReady.payload.inputs.environment -ne "staging") { throw "Runtime verification failed: workflow dispatch ready payload wrong environment" }
$workflowBlockedBody = @{
  workflow_id = "main-deploy.yml"
  ref = "main"
  environment = "production"
  action = "deploy"
  image_tag = "ghcr.io/repo/agent-api:runtime-proof"
  reason = "runtime production block proof"
  trace_id = "runtime-devops-dispatch-blocked"
  human_review_approved = $false
  dry_run = $true
} | ConvertTo-Json -Compress
$workflowBlockedFile = Join-Path $env:TEMP ("workflow-dispatch-block-" + [Guid]::NewGuid().ToString("N") + ".json")
$workflowBlockedOutFile = Join-Path $env:TEMP ("workflow-dispatch-block-out-" + [Guid]::NewGuid().ToString("N") + ".json")
try {
  Set-Content -Path $workflowBlockedFile -Value $workflowBlockedBody -NoNewline -Encoding utf8
  $workflowBlockedStatus = curl.exe -sS -o $workflowBlockedOutFile -w "%{http_code}" -X POST -H "Content-Type: application/json" --data-binary "@$workflowBlockedFile" "$baseUrl/api/v1/devops/workflow-dispatch/validate"
  if ($workflowBlockedStatus -ne "403") {
    $workflowBlockedUnexpected = Get-Content -Path $workflowBlockedOutFile -Raw
    throw "Runtime verification failed: production workflow dispatch expected 403 but got $workflowBlockedStatus. Value: $workflowBlockedUnexpected"
  }
  $workflowBlockedOut = Get-Content -Path $workflowBlockedOutFile -Raw
} finally {
  if (Test-Path $workflowBlockedFile) { Remove-Item -LiteralPath $workflowBlockedFile -Force }
  if (Test-Path $workflowBlockedOutFile) { Remove-Item -LiteralPath $workflowBlockedOutFile -Force }
}
Assert-Contains "workflow dispatch blocked code" $workflowBlockedOut "workflow_dispatch_blocked"
Assert-Contains "workflow dispatch production human gate" $workflowBlockedOut "production workflow dispatch requires human_review_approved=true"
$workflowAudit = curl.exe -sS "$baseUrl/api/v1/audit/recent?limit=40"
Assert-Contains "workflow dispatch audit event" $workflowAudit "devops_workflow_dispatch_contract"
Assert-Contains "workflow dispatch audit ready trace" $workflowAudit "runtime-devops-dispatch-ready"
Assert-Contains "workflow dispatch audit blocked trace" $workflowAudit "runtime-devops-dispatch-blocked"

Write-Host "[runtime] budget warning threshold"
$budgetWarningTrace = "runtime-budget-warning-proof"
try {
  docker exec cloud-superbrain-phase1-dev-postgres-1 psql -U superbrain -d superbrain_prod -tAc "DELETE FROM cost_tracking WHERE trace_id='$budgetWarningTrace'; INSERT INTO cost_tracking(agent_type, model_name, provider_name, input_tokens, output_tokens, cost_cents, trace_id) VALUES ('tester', 'budget-warning-proof', 'runtime', 0, 0, 16000, '$budgetWarningTrace');"
  Assert-LastExitCode "insert budget warning proof row"
  $budgetWarning = curl.exe -sS "$baseUrl/api/v1/budget"
  Assert-Contains "budget warning level" $budgetWarning '"level":"warning"'
  Assert-Contains "budget warning percentage" $budgetWarning '"budget_spent_percentage":80.0'
  Assert-Contains "budget warning allows calls" $budgetWarning '"allow_new_calls":true'
  $warningPromptBody = @{ project_id = $projectId; prompt = "budget warning still allows prompt"; stream = $true } | ConvertTo-Json -Compress
  $warningPrompt = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/v1/prompt" -ContentType "application/json" -Body $warningPromptBody
  if ($warningPrompt.budget.level -ne "warning") {
    throw "Runtime verification failed: prompt response did not carry warning budget level"
  }
  $budgetWarningMetrics = curl.exe -sS "$baseUrl/api/v1/metrics"
  Assert-Contains "budget warning metrics percentage" $budgetWarningMetrics "superbrain_budget_spent_percentage 80.0"
  Assert-Contains "budget warning metrics label" $budgetWarningMetrics 'superbrain_budget_allow_new_calls{level="warning"} 1'
} finally {
  docker exec cloud-superbrain-phase1-dev-postgres-1 psql -U superbrain -d superbrain_prod -tAc "DELETE FROM cost_tracking WHERE trace_id='$budgetWarningTrace';" | Out-Null
}
$budgetAfterWarning = curl.exe -sS "$baseUrl/api/v1/budget"
Assert-Contains "budget warning cleanup" $budgetAfterWarning '"level":"ok"'

Write-Host "[runtime] budget hard-stop threshold"
$budgetHardStopTrace = "runtime-budget-hard-stop-proof"
$budgetHardStopPromptFile = Join-Path $env:TEMP ("runtime-budget-hard-stop-" + [Guid]::NewGuid().ToString("N") + ".json")
$budgetHardStopOutFile = Join-Path $env:TEMP ("runtime-budget-hard-stop-out-" + [Guid]::NewGuid().ToString("N") + ".json")
try {
  docker exec cloud-superbrain-phase1-dev-postgres-1 psql -U superbrain -d superbrain_prod -tAc "DELETE FROM cost_tracking WHERE trace_id='$budgetHardStopTrace'; INSERT INTO cost_tracking(agent_type, model_name, provider_name, input_tokens, output_tokens, cost_cents, trace_id) VALUES ('tester', 'budget-hard-stop-proof', 'runtime', 0, 0, 20000, '$budgetHardStopTrace');"
  Assert-LastExitCode "insert budget hard-stop proof row"
  $budgetHardStop = curl.exe -sS "$baseUrl/api/v1/budget"
  Assert-Contains "budget hard-stop level" $budgetHardStop '"level":"critical"'
  Assert-Contains "budget hard-stop blocks calls" $budgetHardStop '"allow_new_calls":false'
  $budgetHardStopMetrics = curl.exe -sS "$baseUrl/api/v1/metrics"
  Assert-Contains "budget hard-stop metrics label" $budgetHardStopMetrics 'superbrain_budget_allow_new_calls{level="critical"} 0'

  $budgetHardStopPromptBody = @{ project_id = $projectId; prompt = "budget hard stop must block prompt"; stream = $true } | ConvertTo-Json -Compress
  Set-Content -LiteralPath $budgetHardStopPromptFile -Value $budgetHardStopPromptBody -NoNewline -Encoding utf8
  $budgetHardStopStatus = curl.exe -sS -o $budgetHardStopOutFile -w "%{http_code}" -X POST -H "Content-Type: application/json" --data-binary "@$budgetHardStopPromptFile" "$baseUrl/api/v1/prompt"
  if ($budgetHardStopStatus -ne "402") {
    $budgetHardStopUnexpected = Get-Content -Path $budgetHardStopOutFile -Raw
    throw "Runtime verification failed: budget hard-stop expected HTTP 402 but got $budgetHardStopStatus. Value: $budgetHardStopUnexpected"
  }
  $budgetHardStopOut = Get-Content -Path $budgetHardStopOutFile -Raw
  Assert-Contains "budget hard-stop prompt detail" $budgetHardStopOut "LLM budget hard limit reached"
  Assert-Contains "budget hard-stop prompt envelope" $budgetHardStopOut '"status_code":402'

  $budgetHardStopThreadId = [Guid]::NewGuid().ToString()
  $budgetHardStopGraphBody = @{ project_id = $projectId; prompt = "budget guard hard stop proof"; session_id = $budgetHardStopThreadId } | ConvertTo-Json -Compress
  $budgetHardStopGraph = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/v1/orchestrator/dry-run" -ContentType "application/json" -Body $budgetHardStopGraphBody
  if ($budgetHardStopGraph.engine -ne "langgraph") { throw "Runtime verification failed: budget hard-stop graph engine was not langgraph" }
  if ($budgetHardStopGraph.live_provider_calls -ne $false) { throw "Runtime verification failed: budget hard-stop graph attempted live provider calls" }
  if ($budgetHardStopGraph.checkpointing -ne "postgres") { throw "Runtime verification failed: budget hard-stop graph did not use postgres checkpointing" }
  if ($budgetHardStopGraph.state.node_name -ne "hard_stop") { throw "Runtime verification failed: budget hard-stop graph did not hard stop" }
  if ($budgetHardStopGraph.state.hard_stop_reason -ne "budget_guard_rejected") { throw "Runtime verification failed: budget hard-stop graph wrong hard stop reason" }
  if (-not ($budgetHardStopGraph.state.budget_decisions.Count -gt 0)) { throw "Runtime verification failed: budget hard-stop graph missing budget decision" }
  if ($budgetHardStopGraph.state.budget_decisions[-1].allow_new_calls -ne $false) { throw "Runtime verification failed: budget hard-stop graph did not record blocked budget decision" }
  $budgetHardStopCheckpoint = Wait-UrlContains "budget hard-stop checkpoint" "$baseUrl/api/v1/orchestrator/checkpoints/$budgetHardStopThreadId" '"checkpointing":"postgres"' 45
  Assert-Contains "budget hard-stop checkpoint hard stop" $budgetHardStopCheckpoint '"node_name":"hard_stop"'
  Assert-Contains "budget hard-stop checkpoint reason" $budgetHardStopCheckpoint '"hard_stop_reason":"budget_guard_rejected"'
  $budgetHardStopAudit = curl.exe -sS "$baseUrl/api/v1/audit/recent?limit=30"
  Assert-Contains "budget hard-stop audit event" $budgetHardStopAudit "langgraph_dry_run_stopped"
  Assert-Contains "budget hard-stop audit thread" $budgetHardStopAudit $budgetHardStopThreadId
} finally {
  if (Test-Path $budgetHardStopPromptFile) { Remove-Item -LiteralPath $budgetHardStopPromptFile -Force }
  if (Test-Path $budgetHardStopOutFile) { Remove-Item -LiteralPath $budgetHardStopOutFile -Force }
  docker exec cloud-superbrain-phase1-dev-postgres-1 psql -U superbrain -d superbrain_prod -tAc "DELETE FROM cost_tracking WHERE trace_id='$budgetHardStopTrace';" | Out-Null
}
$budgetAfterHardStop = curl.exe -sS "$baseUrl/api/v1/budget"
Assert-Contains "budget hard-stop cleanup" $budgetAfterHardStop '"level":"ok"'

Write-Host "[runtime] costs endpoint"
$costs = curl.exe -sS "$baseUrl/api/v1/costs"
Assert-Contains "costs endpoint" $costs '"budget_limit_cents":20000'
Assert-Contains "costs endpoint breakdown" $costs '"breakdown"'
Assert-Contains "costs endpoint gate" $costs '"allow_new_calls":true'
$costExportContract = curl.exe -sS "$baseUrl/api/v1/costs/export/contract"
Assert-Contains "cost export contract version" $costExportContract '"contract_version":"cost-monitor-export-v1"'
Assert-Contains "cost export contract csv" $costExportContract '"supported_formats":["csv"]'
Assert-Contains "cost export contract group agent" $costExportContract "agent"
Assert-Contains "cost export contract evidence" $costExportContract "cost_export_csv_generated"
$costExportCsv = curl.exe -sS "$baseUrl/api/v1/costs/export?format=csv&group_by=agent&trace_id=runtime-cost-export-proof&request_id=runtime-cost-export-request-proof"
Assert-Contains "cost export csv header" $costExportCsv "group_by,agent_type,model_name,provider_name,session_id,input_tokens,output_tokens,cost_cents,from_cache,row_count"
$costExportAudit = curl.exe -sS "$baseUrl/api/v1/audit/recent?limit=80"
Assert-Contains "cost export audit event" $costExportAudit "cost_export_generated"
Assert-Contains "cost export audit trace" $costExportAudit "runtime-cost-export-proof"
Assert-Contains "cost export audit request id" $costExportAudit "runtime-cost-export-request-proof"
Assert-Contains "cost export audit feed evidence" $costExportAudit "request_id_audit_feed_visible"
Assert-Contains "cost export audit top-level request id" $costExportAudit '"request_id":"runtime-cost-export-request-proof"'
$systemFallbackContract = curl.exe -sS "$baseUrl/api/v1/system/fallback/contract"
Assert-Contains "system fallback contract version" $systemFallbackContract '"contract_version":"system-unavailable-fallback-v1"'
Assert-Contains "system fallback contract endpoint" $systemFallbackContract '"health_endpoint":"GET /api/v1/health"'
Assert-Contains "system fallback unavailable evidence" $systemFallbackContract "system_unavailable_ui_state"
Assert-Contains "system fallback no fake healthy policy" $systemFallbackContract "no_fake_healthy_claim"
$agentActivityContract = curl.exe -sS "$baseUrl/api/v1/agent-activity/contract"
Assert-Contains "agent activity contract version" $agentActivityContract '"contract_version":"agent-activity-trace-v1"'
Assert-Contains "agent activity source filtered feed" $agentActivityContract "GET /api/v1/agent-activity/recent?limit=50"
Assert-Contains "agent activity source audit" $agentActivityContract "GET /api/v1/audit/recent?limit=50"
Assert-Contains "agent activity langfuse proxy" $agentActivityContract "langfuse_auth_proxy_required"
Assert-Contains "agent activity filtered evidence" $agentActivityContract "agent_activity_filtered_feed_visible"
Assert-Contains "agent activity no public langfuse" $agentActivityContract "no_public_langfuse_without_auth"
$agentActivityFeed = curl.exe -sS "$baseUrl/api/v1/agent-activity/recent?limit=5&severity=info"
Assert-Contains "agent activity feed contract" $agentActivityFeed '"contract_version":"agent-activity-trace-v1"'
Assert-Contains "agent activity feed mode" $agentActivityFeed '"mode":"audit_log_backed_filtered_feed"'
Assert-Contains "agent activity feed filter" $agentActivityFeed '"severity":"info"'
Assert-Contains "agent activity feed evidence" $agentActivityFeed "agent_activity_filtered_feed_visible"

Write-Host "[runtime] prometheus metrics"
$metrics = curl.exe -sS "$baseUrl/api/v1/metrics"
Assert-Contains "metrics budget percentage" $metrics "superbrain_budget_spent_percentage"
Assert-Contains "metrics project progress" $metrics ("superbrain_project_progress_percent {0}" -f $expectedOverallPercent)
Assert-Contains "metrics rate limit capacity" $metrics "superbrain_prompt_rate_limit_capacity"
Assert-Contains "metrics rate limit remaining" $metrics "superbrain_prompt_rate_limit_remaining"
Assert-Contains "metrics rate limit used" $metrics "superbrain_prompt_rate_limit_used"
Assert-Contains "metrics session limit capacity" $metrics "superbrain_session_llm_call_limit"
Assert-Contains "metrics session limit remaining" $metrics "superbrain_session_llm_call_remaining"
Assert-Contains "metrics session limit used" $metrics "superbrain_session_llm_call_used"
Assert-Contains "metrics infra budget percentage" $metrics "superbrain_infra_budget_spent_percentage"
Assert-Contains "metrics infra budget projected" $metrics "superbrain_infra_budget_projected_cost_cents"
Assert-Contains "metrics infra budget allow" $metrics "superbrain_infra_budget_allow_new"
Assert-Contains "metrics external gates" $metrics "superbrain_external_gate_configured"
Assert-Contains "metrics queue depth" $metrics "superbrain_task_queue_depth"
Assert-Contains "metrics service health" $metrics "superbrain_service_health"
Assert-Contains "metrics agent worker service" $metrics 'service="agent_worker"'
Assert-Contains "metrics memory worker service" $metrics 'service="memory_worker"'
Assert-Contains "metrics llm gateway service" $metrics 'service="llm_gateway"'
Assert-Contains "metrics audit counter" $metrics "superbrain_audit_events_total"
Assert-Contains "metrics mcp tool counter" $metrics "superbrain_mcp_tool_events_total"
Assert-Contains "metrics mcp blocked counter" $metrics 'status="blocked"'
Assert-Contains "metrics mcp timeout counter" $metrics 'status="timeout"'
Assert-Contains "metrics mcp degraded counter" $metrics 'status="degraded"'
Assert-Contains "metrics memory entries" $metrics "superbrain_memory_entries_total"
Assert-Contains "metrics memory consolidation counter" $metrics "superbrain_memory_consolidation_events_total"
Assert-Contains "metrics memory consolidated event" $metrics 'event_type="memory_consolidated"'
Assert-Contains "metrics checkpoint tables" $metrics "superbrain_checkpoint_tables_total 4"

Write-Host "[runtime] langgraph orchestrator dry-run"
$orchestratorManifest = curl.exe -sS "$baseUrl/api/v1/orchestrator/manifest"
Assert-Contains "orchestrator engine" $orchestratorManifest '"engine":"langgraph"'
Assert-Contains "orchestrator node" $orchestratorManifest "budget_guard"
Assert-Contains "orchestrator no live calls" $orchestratorManifest '"live_provider_calls":false'
Assert-Contains "orchestrator postgres checkpointing" $orchestratorManifest '"checkpointing":"postgres"'
$orchestratorBody = @{ project_id = $projectId; prompt = "phase2 langgraph dry run verifier postgres write"; session_id = $response.session_id } | ConvertTo-Json -Compress
$orchestratorRun = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/v1/orchestrator/dry-run" -ContentType "application/json" -Body $orchestratorBody
if ($orchestratorRun.engine -ne "langgraph") { throw "Runtime verification failed: orchestrator engine was not langgraph" }
if ($orchestratorRun.live_provider_calls -ne $false) { throw "Runtime verification failed: orchestrator dry-run attempted live provider calls" }
if ($orchestratorRun.checkpointing -ne "postgres") { throw "Runtime verification failed: orchestrator dry-run did not use postgres checkpointing" }
if ($orchestratorRun.state.node_name -ne "completed") { throw "Runtime verification failed: orchestrator dry-run did not complete. Value: $($orchestratorRun | ConvertTo-Json -Depth 12)" }
if (-not ($orchestratorRun.state.evidence_refs -contains "langgraph_dry_run")) { throw "Runtime verification failed: orchestrator dry-run missing evidence ref" }
if (-not ($orchestratorRun.state.evidence_refs -contains "llm_gateway_dry_run")) { throw "Runtime verification failed: orchestrator dry-run missing llm gateway evidence ref" }
if (-not ($orchestratorRun.state.evidence_refs -contains "llm_gateway_streaming_dry_run")) { throw "Runtime verification failed: orchestrator dry-run missing llm gateway streaming evidence ref" }
if (-not ($orchestratorRun.state.evidence_refs -contains "llm_routing_policy_primary_allowed")) { throw "Runtime verification failed: orchestrator dry-run missing llm routing policy evidence ref" }
if (-not ($orchestratorRun.state.evidence_refs -contains "memory_context_injected")) { throw "Runtime verification failed: orchestrator dry-run missing memory context evidence ref" }
if (-not ($orchestratorRun.state.evidence_refs -contains "memory_update_persisted")) { throw "Runtime verification failed: orchestrator dry-run missing persisted memory update evidence ref" }
if (-not ($orchestratorRun.state.evidence_refs -contains "task_assignment_completed")) { throw "Runtime verification failed: orchestrator dry-run missing task assignment evidence ref" }
if (-not ($orchestratorRun.state.evidence_refs -contains "mcp_tool_success")) { throw "Runtime verification failed: orchestrator dry-run missing MCP tool evidence ref" }
if (-not ($orchestratorRun.state.budget_decisions.Count -gt 0)) { throw "Runtime verification failed: orchestrator dry-run missing budget decision" }
if (-not ($orchestratorRun.state.llm_gateway_calls.Count -gt 0)) { throw "Runtime verification failed: orchestrator dry-run missing llm gateway call" }
if (-not ($orchestratorRun.state.task_assignments.Count -gt 0)) { throw "Runtime verification failed: orchestrator dry-run missing task assignment" }
if (-not ($orchestratorRun.state.mcp_tool_calls.Count -gt 0)) { throw "Runtime verification failed: orchestrator dry-run missing MCP tool call" }
$expectedAgentRoles = @("planner", "coder", "tester", "devops")
$orchestratorAssignments = @($orchestratorRun.state.task_assignments)
$orchestratorAgentResults = @($orchestratorRun.state.agent_results)
$orchestratorMcpCalls = @($orchestratorRun.state.mcp_tool_calls)
$orchestratorLlmCalls = @($orchestratorRun.state.llm_gateway_calls)
$orchestratorPerRoleResults = @($orchestratorRun.state.result.per_role_results)
if ($orchestratorAssignments.Count -lt 4) { throw "Runtime verification failed: orchestrator did not execute all four agent roles" }
if ($orchestratorAgentResults.Count -lt 4) { throw "Runtime verification failed: orchestrator missing multi-agent result envelopes" }
if ($orchestratorMcpCalls.Count -lt 4) { throw "Runtime verification failed: orchestrator missing multi-agent MCP tool calls" }
if ($orchestratorLlmCalls.Count -lt 4) { throw "Runtime verification failed: orchestrator missing multi-agent LLM dry-run calls" }
if ($orchestratorPerRoleResults.Count -lt 4) { throw "Runtime verification failed: orchestrator missing per-role result summaries" }
if ($orchestratorRun.state.result.partial_failure -ne $false) { throw "Runtime verification failed: orchestrator reported partial failure" }
if (-not ($orchestratorRun.state.result.verification_evidence -contains "agent_result_aggregation_complete")) { throw "Runtime verification failed: orchestrator missing aggregation evidence" }
$expectedPriorities = @{ planner = 9; coder = 5; tester = 5; devops = 8 }
foreach ($role in $expectedAgentRoles) {
  $assignment = $orchestratorAssignments | Where-Object { $_.agent_type -eq $role } | Select-Object -First 1
  if (-not $assignment) { throw "Runtime verification failed: missing task assignment for $role" }
  if ($assignment.status -ne "completed") { throw "Runtime verification failed: task assignment for $role did not complete" }
  if ([int]$assignment.priority -ne [int]$expectedPriorities[$role]) { throw "Runtime verification failed: $role assignment priority mismatch" }
  if ($role -in @("planner", "devops") -and $assignment.priority_level -ne "high") { throw "Runtime verification failed: $role manager assignment was not high priority" }
  if ($role -in @("planner", "devops") -and -not ($assignment.priority_queue -like "*:high")) { throw "Runtime verification failed: $role manager assignment was not routed to high priority queue" }
  if ($assignment.done_validation.logged -ne $true) { throw "Runtime verification failed: done validation for $role did not log" }
  if (-not ($assignment.blocked_actions -contains "push_main")) { throw "Runtime verification failed: $role assignment missing push_main block" }
  $agentResult = $orchestratorAgentResults | Where-Object { $_.owner_role -eq $role } | Select-Object -First 1
  if (-not $agentResult) { throw "Runtime verification failed: missing agent result for $role" }
  if (-not ($agentResult.verification_evidence -contains "agent_role_$($role)_executed")) { throw "Runtime verification failed: missing role evidence for $role" }
  $mcpCallForRole = $orchestratorMcpCalls | Where-Object { $_.agent_role -eq $role } | Select-Object -First 1
  if (-not $mcpCallForRole) { throw "Runtime verification failed: missing MCP call for $role" }
  if ($mcpCallForRole.status -ne "success") { throw "Runtime verification failed: MCP call for $role was not successful" }
  $roleSummary = $orchestratorPerRoleResults | Where-Object { $_.role -eq $role } | Select-Object -First 1
  if (-not $roleSummary) { throw "Runtime verification failed: missing per-role result summary for $role" }
  if ($roleSummary.status -ne "completed") { throw "Runtime verification failed: per-role summary for $role did not complete" }
  if ($roleSummary.mcp_status -ne "success") { throw "Runtime verification failed: per-role summary for $role missing MCP success" }
  if (-not $roleSummary.mcp_evidence_ref) { throw "Runtime verification failed: per-role summary for $role missing MCP evidence" }
}
if ($orchestratorRun.state.task_assignments[0].contract -ne "TaskAssignment") { throw "Runtime verification failed: orchestrator task assignment contract mismatch" }
if ($orchestratorRun.state.task_assignments[0].status -ne "completed") { throw "Runtime verification failed: orchestrator task assignment did not complete" }
if ($orchestratorRun.state.task_assignments[0].done_validation.logged -ne $true) { throw "Runtime verification failed: orchestrator task assignment done validation did not log" }
if (-not ($orchestratorRun.state.task_assignments[0].blocked_actions -contains "push_main")) { throw "Runtime verification failed: orchestrator task assignment missing push_main block" }
if ($orchestratorRun.state.mcp_tool_calls[0].contract -ne "McpToolRequest") { throw "Runtime verification failed: orchestrator MCP tool contract mismatch" }
if ($orchestratorRun.state.mcp_tool_calls[0].status -ne "success") { throw "Runtime verification failed: orchestrator MCP tool call was not successful" }
if ($orchestratorRun.state.mcp_tool_calls[0].toolset -ne "postgresql") { throw "Runtime verification failed: orchestrator planner MCP toolset was not postgresql" }
if ($orchestratorRun.state.mcp_tool_calls[0].evidence_ref -ne "postgresql_readonly_query_plan") { throw "Runtime verification failed: orchestrator planner MCP evidence ref mismatch" }
if ($orchestratorRun.state.mcp_tool_calls[0].audit_persisted -ne $true) { throw "Runtime verification failed: orchestrator MCP audit was not persisted" }
if ($orchestratorRun.state.mcp_tool_calls[0].allowed_scope -ne "project-context-readonly") { throw "Runtime verification failed: orchestrator planner MCP allowed scope mismatch" }
if (-not $orchestratorRun.state.memory_update_id) { throw "Runtime verification failed: orchestrator dry-run missing memory_update_id" }
if ($orchestratorRun.state.memory_context_budget.budget_percent_max -ne 30) { throw "Runtime verification failed: orchestrator memory context budget percent was not 30" }
if ($orchestratorRun.state.memory_context_budget.selected_count -lt 1) { throw "Runtime verification failed: orchestrator did not inject memory context" }
if ($orchestratorRun.state.memory_context_budget.used_tokens -gt $orchestratorRun.state.memory_context_budget.budget_tokens) { throw "Runtime verification failed: orchestrator memory context exceeded budget" }
$orchestratorLlmCall = $orchestratorRun.state.llm_gateway_calls[0]
if ($orchestratorLlmCall.live_provider_calls -ne $false) { throw "Runtime verification failed: orchestrator llm gateway call attempted live provider calls" }
if ($orchestratorLlmCall.cost_cents -ne 0) { throw "Runtime verification failed: orchestrator llm gateway call cost was not zero" }
if ($orchestratorLlmCall.audit_persisted -ne $true) { throw "Runtime verification failed: orchestrator llm gateway audit was not persisted" }
if ($orchestratorLlmCall.streaming_used -ne $true) { throw "Runtime verification failed: orchestrator did not consume LLM gateway stream" }
if ($orchestratorLlmCall.streaming_protocol -ne "openai_compatible_sse") { throw "Runtime verification failed: orchestrator streaming protocol was not OpenAI-compatible SSE" }
if ($orchestratorLlmCall.stream_done_seen -ne $true) { throw "Runtime verification failed: orchestrator did not see LLM gateway stream DONE frame" }
if ($orchestratorLlmCall.stream_chunk_count -lt 1) { throw "Runtime verification failed: orchestrator stream chunk count was empty" }
if ($orchestratorLlmCall.memory_context_injected -ne $true) { throw "Runtime verification failed: orchestrator LLM call did not mark memory context injected" }
if ($orchestratorLlmCall.memory_context_count -lt 1) { throw "Runtime verification failed: orchestrator LLM call memory context count was empty" }
if ($orchestratorLlmCall.memory_context_budget.budget_percent_max -ne 30) { throw "Runtime verification failed: orchestrator LLM call memory context budget percent was not 30" }
if ($orchestratorLlmCall.routing.selected_model -ne "deepseek-ai/DeepSeek-V4-Pro:fastest") { throw "Runtime verification failed: orchestrator did not use gateway routing resolver selected model" }
if ($orchestratorLlmCall.routing.selected_provider -ne "huggingface_inference_router") { throw "Runtime verification failed: orchestrator did not retain gateway selected provider" }
if ($orchestratorLlmCall.routing.live_provider_calls -ne $false) { throw "Runtime verification failed: orchestrator gateway routing attempted live provider calls" }
if ($orchestratorLlmCall.routing.configured_only -ne $false) { throw "Runtime verification failed: orchestrator gateway routing should be HF-live-verifiable" }
if ($orchestratorLlmCall.routing.provider_health.status -ne "live_verified") { throw "Runtime verification failed: orchestrator gateway provider health status wrong" }
if ($orchestratorLlmCall.routing_policy_checked -ne $true) { throw "Runtime verification failed: orchestrator did not check LLM routing policy before gateway call" }
if ($orchestratorLlmCall.routing_policy_contract_version -ne "llm-routing-policy-v1") { throw "Runtime verification failed: orchestrator LLM routing policy contract version mismatch" }
if ($orchestratorLlmCall.routing_policy_decision -ne "allow_primary") { throw "Runtime verification failed: orchestrator LLM routing policy did not allow primary route" }
if ($orchestratorLlmCall.routing_policy_evidence_ref -ne "llm_routing_policy_primary_allowed") { throw "Runtime verification failed: orchestrator LLM routing policy evidence mismatch" }
if ($orchestratorLlmCall.routing_policy.live_provider_calls -ne $false) { throw "Runtime verification failed: orchestrator LLM routing policy attempted live provider calls" }
$orchestratorLlmAudit = curl.exe -sS "$baseUrl/api/v1/audit/recent?limit=40"
Assert-Contains "orchestrator llm audit event" $orchestratorLlmAudit "llm_gateway_request"
Assert-Contains "orchestrator llm audit trace" $orchestratorLlmAudit $orchestratorLlmCall.trace_id
Assert-Contains "orchestrator llm audit no live calls" $orchestratorLlmAudit '"live_provider_calls":false'
$memoryUpdateQuery = [uri]::EscapeDataString("langgraph memory update")
$orchestratorMemoryUpdateSearch = curl.exe -sS "$baseUrl/api/v1/memory/search?q=$memoryUpdateQuery&project_id=$projectId&limit=10"
Assert-Contains "orchestrator memory update persisted id" $orchestratorMemoryUpdateSearch $orchestratorRun.state.memory_update_id
Assert-Contains "orchestrator memory update persisted text" $orchestratorMemoryUpdateSearch "langgraph memory update"
$orchestratorAssignedTaskId = $orchestratorRun.state.task_assignments[0].task_id
$orchestratorAssignedTask = curl.exe -sS "$baseUrl/api/v1/tasks/recent?limit=20"
Assert-Contains "orchestrator assigned task visible" $orchestratorAssignedTask $orchestratorAssignedTaskId
Assert-Contains "orchestrator assigned task completed" $orchestratorAssignedTask '"status":"completed"'
$orchestratorMcpCall = $orchestratorRun.state.mcp_tool_calls[0]
$orchestratorMcpAudit = curl.exe -sS "$baseUrl/api/v1/audit/mcp?limit=40"
Assert-Contains "orchestrator mcp audit event" $orchestratorMcpAudit "mcp_tool_executed"
Assert-Contains "orchestrator mcp audit request" $orchestratorMcpAudit $orchestratorMcpCall.tool_request_id
Assert-Contains "orchestrator mcp audit readonly evidence" $orchestratorMcpAudit "postgresql_readonly_query_plan"
Assert-Contains "orchestrator mcp audit session bound" $orchestratorMcpAudit '"session_bound":true'
Assert-Contains "orchestrator mcp audit session id" $orchestratorMcpAudit $orchestratorRun.thread_id
Assert-Contains "orchestrator mcp audit trace evidence" $orchestratorMcpAudit "mcp_tool_session_bound_audit"
$threadId = $orchestratorRun.thread_id

Write-Host "[runtime] langgraph mcp timeout controlled proof"
$mcpTimeoutThreadId = [Guid]::NewGuid().ToString()
$mcpTimeoutBody = @{ project_id = $projectId; prompt = "force_mcp_tool_timeout:tester"; session_id = $mcpTimeoutThreadId } | ConvertTo-Json -Compress
$mcpTimeoutRun = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/v1/orchestrator/dry-run" -ContentType "application/json" -Body $mcpTimeoutBody
if ($mcpTimeoutRun.state.node_name -ne "completed") { throw "Runtime verification failed: MCP timeout graph did not complete" }
if ($mcpTimeoutRun.live_provider_calls -ne $false) { throw "Runtime verification failed: MCP timeout graph attempted live provider calls" }
if ($mcpTimeoutRun.state.result.partial_failure -ne $true) { throw "Runtime verification failed: MCP timeout graph did not report controlled partial failure" }
if (-not ($mcpTimeoutRun.state.evidence_refs -contains "langgraph_mcp_timeout_controlled")) { throw "Runtime verification failed: MCP timeout graph missing orchestrator timeout evidence" }
if (-not ($mcpTimeoutRun.state.evidence_refs -contains "mcp_tool_controlled_error")) { throw "Runtime verification failed: MCP timeout graph missing controlled MCP error evidence" }
if (-not ($mcpTimeoutRun.state.evidence_refs -contains "agent_result_aggregation_partial_failure_detected")) { throw "Runtime verification failed: MCP timeout graph missing partial-failure aggregation evidence" }
$mcpTimeoutCalls = @($mcpTimeoutRun.state.mcp_tool_calls)
$testerTimeoutCall = $mcpTimeoutCalls | Where-Object { $_.agent_role -eq "tester" } | Select-Object -First 1
if (-not $testerTimeoutCall) { throw "Runtime verification failed: MCP timeout graph missing tester MCP call" }
if ($testerTimeoutCall.status -ne "timeout") { throw "Runtime verification failed: tester MCP call did not time out" }
if ($testerTimeoutCall.capability -ne "simulate_timeout") { throw "Runtime verification failed: tester MCP timeout did not use simulate_timeout" }
if ($testerTimeoutCall.evidence_ref -ne "mcp_timeout_guard") { throw "Runtime verification failed: tester MCP timeout missing gateway timeout evidence" }
if ($testerTimeoutCall.orchestrator_evidence_ref -ne "langgraph_mcp_timeout_controlled") { throw "Runtime verification failed: tester MCP timeout missing LangGraph timeout evidence" }
if ($testerTimeoutCall.audit_persisted -ne $true) { throw "Runtime verification failed: tester MCP timeout audit was not persisted" }
$testerTimeoutSummary = @($mcpTimeoutRun.state.result.per_role_results) | Where-Object { $_.role -eq "tester" } | Select-Object -First 1
if (-not $testerTimeoutSummary) { throw "Runtime verification failed: MCP timeout graph missing tester summary" }
if ($testerTimeoutSummary.status -ne "partial_failure") { throw "Runtime verification failed: tester summary did not report partial failure" }
if ($testerTimeoutSummary.mcp_status -ne "timeout") { throw "Runtime verification failed: tester summary missing MCP timeout status" }
if (-not ($testerTimeoutSummary.failure_reasons -contains "mcp_timeout")) { throw "Runtime verification failed: tester summary missing mcp_timeout failure reason" }
$mcpTimeoutAudit = curl.exe -sS "$baseUrl/api/v1/audit/mcp?limit=60"
Assert-Contains "orchestrator MCP timeout audit request" $mcpTimeoutAudit $testerTimeoutCall.tool_request_id
Assert-Contains "orchestrator MCP timeout audit evidence" $mcpTimeoutAudit "mcp_timeout_guard"
Assert-Contains "orchestrator MCP timeout audit session id" $mcpTimeoutAudit $mcpTimeoutRun.thread_id
Assert-Contains "orchestrator MCP timeout audit session bound" $mcpTimeoutAudit '"session_bound":true'

$mcpTimeoutStreamThreadId = [Guid]::NewGuid().ToString()
$mcpTimeoutStreamBody = @{ project_id = $projectId; prompt = "force_mcp_tool_timeout:tester"; session_id = $mcpTimeoutStreamThreadId } | ConvertTo-Json -Compress
$mcpTimeoutStreamBodyFile = Join-Path $env:TEMP ("orchestrator-mcp-timeout-stream-" + [Guid]::NewGuid().ToString("N") + ".json")
try {
  Set-Content -Path $mcpTimeoutStreamBodyFile -Value $mcpTimeoutStreamBody -NoNewline -Encoding utf8
  $mcpTimeoutStream = curl.exe -sN --max-time 25 -X POST -H "Content-Type: application/json" --data-binary "@$mcpTimeoutStreamBodyFile" "$baseUrl/api/v1/orchestrator/dry-run/stream"
} finally {
  Remove-Item -Path $mcpTimeoutStreamBodyFile -ErrorAction SilentlyContinue
}
Assert-Contains "orchestrator MCP timeout stream done" $mcpTimeoutStream "event: done"
Assert-Contains "orchestrator MCP timeout stream evidence" $mcpTimeoutStream "langgraph_mcp_timeout_controlled"
Assert-Contains "orchestrator MCP timeout stream gateway evidence" $mcpTimeoutStream "mcp_timeout_guard"
Assert-Contains "orchestrator MCP timeout stream partial failure" $mcpTimeoutStream '"partial_failure":true'
Assert-Contains "orchestrator MCP timeout stream terminal" $mcpTimeoutStream '"status":"completed"'

Write-Host "[runtime] phase2 runtime graph start"
$phase2RuntimeContract = curl.exe -sS "$baseUrl/api/v1/phase2/runtime/contract"
Assert-Contains "phase2 runtime contract version" $phase2RuntimeContract '"contract_version":"phase2-runtime-v1"'
Assert-Contains "phase2 runtime start endpoint" $phase2RuntimeContract "POST /api/v1/phase2/runtime/start"
Assert-Contains "phase2 runtime runs endpoint" $phase2RuntimeContract "GET /api/v1/phase2/runtime/runs"
Assert-Contains "phase2 runtime mcp timeout contract" $phase2RuntimeContract "langgraph_mcp_timeout_controlled"
Assert-Contains "phase2 runtime mcp timeout probe" $phase2RuntimeContract "force_mcp_tool_timeout:tester"
Assert-Contains "phase2 runtime no live providers" $phase2RuntimeContract '"live_provider_calls":false'
$phase2RuntimeThreadId = "runtime-phase2-runtime-" + [Guid]::NewGuid().ToString("N")
$phase2RuntimeBody = @{ project_id = $projectId; prompt = "phase2 runtime graph start verifier"; session_id = $phase2RuntimeThreadId } | ConvertTo-Json -Compress
$phase2RuntimeRun = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/v1/phase2/runtime/start" -ContentType "application/json" -Body $phase2RuntimeBody
if ($phase2RuntimeRun.contract_version -ne "phase2-runtime-v1") { throw "Runtime verification failed: phase2 runtime contract version mismatch" }
if ($phase2RuntimeRun.status -ne "started") { throw "Runtime verification failed: phase2 runtime did not start" }
if ($phase2RuntimeRun.engine -ne "langgraph") { throw "Runtime verification failed: phase2 runtime engine was not langgraph" }
if ($phase2RuntimeRun.mode -ne "deterministic_local_runtime") { throw "Runtime verification failed: phase2 runtime mode mismatch" }
if ($phase2RuntimeRun.live_provider_calls -ne $false) { throw "Runtime verification failed: phase2 runtime attempted live provider calls" }
if ($phase2RuntimeRun.live_mcp_writes -ne $false) { throw "Runtime verification failed: phase2 runtime attempted live MCP writes" }
if ($phase2RuntimeRun.production_deploy -ne $false) { throw "Runtime verification failed: phase2 runtime attempted production deploy" }
if ($phase2RuntimeRun.checkpointing -ne "postgres") { throw "Runtime verification failed: phase2 runtime did not use postgres checkpointing" }
if ($phase2RuntimeRun.state.node_name -ne "completed") { throw "Runtime verification failed: phase2 runtime graph did not complete" }
if (-not ($phase2RuntimeRun.state.evidence_refs -contains "phase2_runtime_graph_started")) { throw "Runtime verification failed: phase2 runtime missing start evidence" }
if (-not ($phase2RuntimeRun.state.evidence_refs -contains "memory_update_persisted")) { throw "Runtime verification failed: phase2 runtime missing memory update evidence" }
$phase2RuntimePerRoleResults = @($phase2RuntimeRun.state.result.per_role_results)
if ($phase2RuntimePerRoleResults.Count -lt 4) { throw "Runtime verification failed: phase2 runtime missing per-role result summaries" }
if ($phase2RuntimeRun.state.result.partial_failure -ne $false) { throw "Runtime verification failed: phase2 runtime reported partial failure" }
if (-not ($phase2RuntimeRun.state.result.verification_evidence -contains "agent_result_aggregation_complete")) { throw "Runtime verification failed: phase2 runtime missing aggregation evidence" }
foreach ($role in $expectedAgentRoles) {
  $roleSummary = $phase2RuntimePerRoleResults | Where-Object { $_.role -eq $role } | Select-Object -First 1
  if (-not $roleSummary) { throw "Runtime verification failed: phase2 runtime missing per-role result summary for $role" }
  if ($roleSummary.status -ne "completed") { throw "Runtime verification failed: phase2 runtime per-role summary for $role did not complete" }
  if ($roleSummary.mcp_status -ne "success") { throw "Runtime verification failed: phase2 runtime per-role summary for $role missing MCP success" }
}
$phase2RuntimeCheckpoint = curl.exe -sS "$baseUrl/api/v1/orchestrator/checkpoints/$($phase2RuntimeRun.thread_id)"
Assert-Contains "phase2 runtime checkpoint evidence" $phase2RuntimeCheckpoint "phase2_runtime_graph_started"
$phase2RuntimeAudit = curl.exe -sS "$baseUrl/api/v1/audit/recent?limit=40"
Assert-Contains "phase2 runtime audit evidence" $phase2RuntimeAudit "phase2_runtime_graph_started"
Assert-Contains "phase2 runtime audit contract" $phase2RuntimeAudit "phase2-runtime-v1"
$phase2AgentActivity = Invoke-RestMethod -Method Get -Uri "$baseUrl/api/v1/agent-activity/recent?event_type=phase2_runtime_graph_started&limit=20"
$phase2AgentActivityEvent = @($phase2AgentActivity.events) | Where-Object { $_.trace_id -eq $phase2RuntimeRun.thread_id -or $_.session_id -eq $phase2RuntimeRun.thread_id } | Select-Object -First 1
if (-not $phase2AgentActivityEvent) { throw "Runtime verification failed: phase2 runtime missing agent activity feed event" }
if ($phase2AgentActivityEvent.role_summary_count -lt 4) { throw "Runtime verification failed: phase2 runtime agent activity missing per-role summaries" }
if ($phase2AgentActivityEvent.partial_failure -ne $false) { throw "Runtime verification failed: phase2 runtime agent activity reported partial failure" }
if ($phase2AgentActivityEvent.aggregation_evidence_ref -ne "agent_result_aggregation_complete") { throw "Runtime verification failed: phase2 runtime agent activity aggregation evidence mismatch" }
foreach ($role in $expectedAgentRoles) {
  $activityRoleSummary = @($phase2AgentActivityEvent.per_role_results) | Where-Object { $_.role -eq $role } | Select-Object -First 1
  if (-not $activityRoleSummary) { throw "Runtime verification failed: phase2 runtime agent activity missing per-role summary for $role" }
  if ($activityRoleSummary.status -ne "completed") { throw "Runtime verification failed: phase2 runtime agent activity per-role summary for $role did not complete" }
}
$phase2RuntimeRuns = Invoke-RestMethod -Method Get -Uri "$baseUrl/api/v1/phase2/runtime/runs?limit=10"
if ($phase2RuntimeRuns.contract_version -ne "phase2-runtime-v1") { throw "Runtime verification failed: phase2 runtime runs contract version mismatch" }
if ($phase2RuntimeRuns.evidence_ref -ne "phase2_runtime_run_status_visible") { throw "Runtime verification failed: phase2 runtime runs evidence ref mismatch" }
$phase2RuntimeRunStatus = @($phase2RuntimeRuns.runs) | Where-Object { $_.thread_id -eq $phase2RuntimeRun.thread_id -or $_.session_id -eq $phase2RuntimeRun.thread_id } | Select-Object -First 1
if (-not $phase2RuntimeRunStatus) { throw "Runtime verification failed: phase2 runtime run status missing" }
if ($phase2RuntimeRunStatus.status -ne "completed") { throw "Runtime verification failed: phase2 runtime run status did not complete" }
if ($phase2RuntimeRunStatus.role_summary_count -lt 4) { throw "Runtime verification failed: phase2 runtime run status missing role summaries" }
if ($phase2RuntimeRunStatus.partial_failure -ne $false) { throw "Runtime verification failed: phase2 runtime run status reported partial failure" }
if ($phase2RuntimeRunStatus.aggregation_evidence_ref -ne "agent_result_aggregation_complete") { throw "Runtime verification failed: phase2 runtime run status aggregation evidence mismatch" }
if ($phase2RuntimeRunStatus.live_provider_calls -ne $false) { throw "Runtime verification failed: phase2 runtime run status claimed live provider calls" }
if ($phase2RuntimeRunStatus.live_mcp_writes -ne $false) { throw "Runtime verification failed: phase2 runtime run status claimed live MCP writes" }
if ($phase2RuntimeRunStatus.production_deploy -ne $false) { throw "Runtime verification failed: phase2 runtime run status claimed production deploy" }

Write-Host "[runtime] langgraph policy hard-stop dry-run"
$blockedThreadId = [Guid]::NewGuid().ToString()
$blockedOrchestratorBody = @{ project_id = $projectId; prompt = "please production deploy and merge main"; session_id = $blockedThreadId } | ConvertTo-Json -Compress
$blockedOrchestratorRun = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/v1/orchestrator/dry-run" -ContentType "application/json" -Body $blockedOrchestratorBody
if ($blockedOrchestratorRun.engine -ne "langgraph") { throw "Runtime verification failed: blocked orchestrator engine was not langgraph" }
if ($blockedOrchestratorRun.live_provider_calls -ne $false) { throw "Runtime verification failed: blocked orchestrator attempted live provider calls" }
if ($blockedOrchestratorRun.checkpointing -ne "postgres") { throw "Runtime verification failed: blocked orchestrator did not use postgres checkpointing" }
if ($blockedOrchestratorRun.state.node_name -ne "hard_stop") { throw "Runtime verification failed: blocked orchestrator did not hard stop. Value: $($blockedOrchestratorRun | ConvertTo-Json -Depth 12)" }
if ($blockedOrchestratorRun.state.hard_stop_reason -ne "policy_or_budget_guard_rejected") { throw "Runtime verification failed: blocked orchestrator wrong hard stop reason" }
if ($blockedOrchestratorRun.state.retry_counters.global -lt 1) { throw "Runtime verification failed: blocked orchestrator did not increment retry counter" }
if (-not ($blockedOrchestratorRun.state.structured_intent.forbidden_actions_detected -contains "production deploy")) { throw "Runtime verification failed: blocked orchestrator did not detect production deploy" }
if (-not ($blockedOrchestratorRun.state.structured_intent.forbidden_actions_detected -contains "merge main")) { throw "Runtime verification failed: blocked orchestrator did not detect merge main" }
$blockedCheckpoint = Wait-UrlContains "blocked orchestrator checkpoint" "$baseUrl/api/v1/orchestrator/checkpoints/$blockedThreadId" '"checkpointing":"postgres"' 45
Assert-Contains "blocked orchestrator checkpoint" $blockedCheckpoint '"checkpointing":"postgres"'
Assert-Contains "blocked orchestrator checkpoint hard stop" $blockedCheckpoint '"node_name":"hard_stop"'
Assert-Contains "blocked orchestrator checkpoint thread" $blockedCheckpoint $blockedThreadId
$blockedAudit = curl.exe -sS "$baseUrl/api/v1/audit/recent?limit=30"
Assert-Contains "blocked orchestrator audit event" $blockedAudit "langgraph_dry_run_stopped"
Assert-Contains "blocked orchestrator audit thread" $blockedAudit $blockedThreadId
Assert-Contains "blocked orchestrator audit severity" $blockedAudit '"severity":"warning"'

Write-Host "[runtime] langgraph global retry limit hard-stop"
$retryLimitThreadId = [Guid]::NewGuid().ToString()
$retryLimitBody = @{ project_id = $projectId; prompt = "force_langgraph_global_retry_limit"; session_id = $retryLimitThreadId } | ConvertTo-Json -Compress
$retryLimitRun = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/v1/orchestrator/dry-run" -ContentType "application/json" -Body $retryLimitBody
if ($retryLimitRun.engine -ne "langgraph") { throw "Runtime verification failed: retry-limit orchestrator engine was not langgraph" }
if ($retryLimitRun.live_provider_calls -ne $false) { throw "Runtime verification failed: retry-limit orchestrator attempted live provider calls" }
if ($retryLimitRun.checkpointing -ne "postgres") { throw "Runtime verification failed: retry-limit orchestrator did not use postgres checkpointing" }
if ($retryLimitRun.state.node_name -ne "hard_stop") { throw "Runtime verification failed: retry-limit orchestrator did not hard stop" }
if ($retryLimitRun.state.hard_stop_reason -ne "global_retry_limit_reached") { throw "Runtime verification failed: retry-limit orchestrator wrong hard stop reason" }
if ($retryLimitRun.state.retry_counters.global -ne 5) { throw "Runtime verification failed: retry-limit orchestrator did not cap global retries at 5" }
if ($retryLimitRun.state.structured_intent.retry_limit_probe -ne $true) { throw "Runtime verification failed: retry-limit probe was not recorded in intent" }
if ($retryLimitRun.state.structured_intent.max_global_retry_cycles -ne 5) { throw "Runtime verification failed: max global retry cycles mismatch" }
if (-not ($retryLimitRun.state.evidence_refs -contains "langgraph_global_retry_limit_enforced")) { throw "Runtime verification failed: retry-limit evidence missing from state" }
$retryLimitCheckpoint = Wait-UrlContains "retry-limit checkpoint" "$baseUrl/api/v1/orchestrator/checkpoints/$retryLimitThreadId" '"checkpointing":"postgres"' 45
Assert-Contains "retry-limit checkpoint" $retryLimitCheckpoint '"checkpointing":"postgres"'
Assert-Contains "retry-limit checkpoint hard stop" $retryLimitCheckpoint '"node_name":"hard_stop"'
Assert-Contains "retry-limit checkpoint reason" $retryLimitCheckpoint '"hard_stop_reason":"global_retry_limit_reached"'
Assert-Contains "retry-limit checkpoint evidence" $retryLimitCheckpoint "langgraph_global_retry_limit_enforced"
$retryLimitAudit = curl.exe -sS "$baseUrl/api/v1/audit/recent?limit=40"
Assert-Contains "retry-limit audit event" $retryLimitAudit "langgraph_dry_run_stopped"
Assert-Contains "retry-limit audit thread" $retryLimitAudit $retryLimitThreadId
Assert-Contains "retry-limit audit evidence" $retryLimitAudit "langgraph_global_retry_limit_enforced"

Write-Host "[runtime] langgraph node retry bounded failure probes"
$retryProtectedNodes = @("intent_parser", "budget_guard", "task_router", "agent_executor", "result_aggregator", "memory_updater")
foreach ($nodeName in $retryProtectedNodes) {
  $nodeFailureThreadId = [Guid]::NewGuid().ToString()
  $nodeFailureBody = @{ project_id = $projectId; prompt = "force_langgraph_node_failure:$nodeName"; session_id = $nodeFailureThreadId } | ConvertTo-Json -Compress
  $nodeFailureRun = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/v1/orchestrator/dry-run" -ContentType "application/json" -Body $nodeFailureBody
  if ($nodeFailureRun.engine -ne "langgraph") { throw "Runtime verification failed: node failure $nodeName engine was not langgraph" }
  if ($nodeFailureRun.live_provider_calls -ne $false) { throw "Runtime verification failed: node failure $nodeName attempted live provider calls" }
  if ($nodeFailureRun.checkpointing -ne "postgres") { throw "Runtime verification failed: node failure $nodeName did not use postgres checkpointing" }
  if ($nodeFailureRun.state.node_name -ne "hard_stop") { throw "Runtime verification failed: node failure $nodeName did not hard stop" }
  if ($nodeFailureRun.state.hard_stop_reason -ne "${nodeName}_retry_limit_reached") { throw "Runtime verification failed: node failure $nodeName wrong hard stop reason" }
  $nodeRetryCounter = $nodeFailureRun.state.retry_counters.PSObject.Properties[$nodeName].Value
  if ($nodeRetryCounter -ne 5) { throw "Runtime verification failed: node failure $nodeName did not cap node retries at 5" }
  if ($nodeFailureRun.state.retry_counters.global -ne 5) { throw "Runtime verification failed: node failure $nodeName did not cap global retries at 5" }
  if (-not ($nodeFailureRun.state.evidence_refs -contains "langgraph_node_failure_bounded")) { throw "Runtime verification failed: node failure $nodeName missing generic evidence" }
  if (-not ($nodeFailureRun.state.evidence_refs -contains "langgraph_${nodeName}_failure_bounded")) { throw "Runtime verification failed: node failure $nodeName missing node evidence" }
  $nodeFailureCheckpoint = Wait-UrlContains "node failure $nodeName checkpoint" "$baseUrl/api/v1/orchestrator/checkpoints/$nodeFailureThreadId" '"checkpointing":"postgres"' 45
  Assert-Contains "node failure $nodeName checkpoint" $nodeFailureCheckpoint '"checkpointing":"postgres"'
  Assert-Contains "node failure $nodeName checkpoint hard stop" $nodeFailureCheckpoint '"node_name":"hard_stop"'
  Assert-Contains "node failure $nodeName checkpoint reason" $nodeFailureCheckpoint "`"hard_stop_reason`":`"${nodeName}_retry_limit_reached`""
  Assert-Contains "node failure $nodeName checkpoint evidence" $nodeFailureCheckpoint "langgraph_${nodeName}_failure_bounded"
  $nodeFailureAudit = curl.exe -sS "$baseUrl/api/v1/audit/recent?limit=100"
  Assert-Contains "node failure $nodeName audit event" $nodeFailureAudit "langgraph_dry_run_stopped"
  Assert-Contains "node failure $nodeName audit thread" $nodeFailureAudit $nodeFailureThreadId
  Assert-Contains "node failure $nodeName audit evidence" $nodeFailureAudit "langgraph_${nodeName}_failure_bounded"
}

Write-Host "[runtime] langgraph llm routing policy deny hard-stop"
$llmPolicyBlockedThreadId = [Guid]::NewGuid().ToString()
$llmPolicyBlockedBody = @{ project_id = $projectId; prompt = "force_llm_routing_policy_deny_sensitive_cache"; session_id = $llmPolicyBlockedThreadId } | ConvertTo-Json -Compress
$llmPolicyBlockedRun = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/v1/orchestrator/dry-run" -ContentType "application/json" -Body $llmPolicyBlockedBody
if ($llmPolicyBlockedRun.engine -ne "langgraph") { throw "Runtime verification failed: llm policy blocked orchestrator engine was not langgraph" }
if ($llmPolicyBlockedRun.live_provider_calls -ne $false) { throw "Runtime verification failed: llm policy blocked orchestrator attempted live provider calls" }
if ($llmPolicyBlockedRun.checkpointing -ne "postgres") { throw "Runtime verification failed: llm policy blocked orchestrator did not use postgres checkpointing" }
if ($llmPolicyBlockedRun.state.node_name -ne "hard_stop") { throw "Runtime verification failed: llm policy blocked orchestrator did not hard stop. Value: $($llmPolicyBlockedRun | ConvertTo-Json -Depth 12)" }
if ($llmPolicyBlockedRun.state.hard_stop_reason -ne "llm_routing_policy_rejected") { throw "Runtime verification failed: llm policy blocked orchestrator wrong hard stop reason" }
if (-not ($llmPolicyBlockedRun.state.llm_gateway_calls.Count -gt 0)) { throw "Runtime verification failed: llm policy blocked orchestrator missing llm gateway call" }
$blockedPolicyCall = $llmPolicyBlockedRun.state.llm_gateway_calls[0]
if ($blockedPolicyCall.status -ne "policy_blocked") { throw "Runtime verification failed: llm policy blocked call status mismatch" }
if ($blockedPolicyCall.routing_policy_decision -ne "deny_sensitive_cache") { throw "Runtime verification failed: llm policy blocked decision mismatch" }
if ($blockedPolicyCall.routing_policy_contract_version -ne "llm-routing-policy-v1") { throw "Runtime verification failed: llm policy blocked contract version mismatch" }
if ($blockedPolicyCall.routing_policy_evidence_ref -ne "llm_routing_policy_sensitive_cache_blocked") { throw "Runtime verification failed: llm policy blocked evidence mismatch" }
if ($blockedPolicyCall.routing_policy.live_provider_calls -ne $false) { throw "Runtime verification failed: llm policy blocked policy attempted live provider calls" }
if ($blockedPolicyCall.live_provider_calls -ne $false) { throw "Runtime verification failed: llm policy blocked gateway call attempted live provider calls" }
if ($blockedPolicyCall.cost_cents -ne 0) { throw "Runtime verification failed: llm policy blocked call cost was not zero" }
if ($llmPolicyBlockedRun.state.task_assignments.Count -ne 0) { throw "Runtime verification failed: llm policy blocked orchestrator enqueued a task" }
if ($llmPolicyBlockedRun.state.mcp_tool_calls.Count -ne 0) { throw "Runtime verification failed: llm policy blocked orchestrator called MCP" }
if (-not ($llmPolicyBlockedRun.state.evidence_refs -contains "llm_routing_policy_sensitive_cache_blocked")) { throw "Runtime verification failed: llm policy blocked evidence ref missing from state" }
$llmPolicyBlockedCheckpoint = Wait-UrlContains "llm policy blocked checkpoint" "$baseUrl/api/v1/orchestrator/checkpoints/$llmPolicyBlockedThreadId" '"checkpointing":"postgres"' 45
Assert-Contains "llm policy blocked checkpoint" $llmPolicyBlockedCheckpoint '"checkpointing":"postgres"'
Assert-Contains "llm policy blocked checkpoint hard stop" $llmPolicyBlockedCheckpoint '"node_name":"hard_stop"'
Assert-Contains "llm policy blocked checkpoint reason" $llmPolicyBlockedCheckpoint '"hard_stop_reason":"llm_routing_policy_rejected"'
Assert-Contains "llm policy blocked checkpoint evidence" $llmPolicyBlockedCheckpoint "llm_routing_policy_sensitive_cache_blocked"

Write-Host "[runtime] langgraph policy hard-stop sse dry-run stream"
$blockedOrchestratorBodyFile = Join-Path $env:TEMP ("orchestrator-hard-stop-stream-" + [Guid]::NewGuid().ToString("N") + ".json")
try {
  Set-Content -Path $blockedOrchestratorBodyFile -Value $blockedOrchestratorBody -NoNewline -Encoding utf8
  $blockedOrchestratorStream = curl.exe -sN --max-time 25 -X POST -H "Content-Type: application/json" --data-binary "@$blockedOrchestratorBodyFile" "$baseUrl/api/v1/orchestrator/dry-run/stream"
} finally {
  if (Test-Path $blockedOrchestratorBodyFile) { Remove-Item -LiteralPath $blockedOrchestratorBodyFile -Force }
}
Assert-Contains "blocked orchestrator stream start" $blockedOrchestratorStream "event: graph_status"
Assert-Contains "blocked orchestrator stream event id" $blockedOrchestratorStream "id: "
Assert-Contains "blocked orchestrator stream heartbeat" $blockedOrchestratorStream "event: heartbeat"
Assert-Contains "blocked orchestrator stream agent status" $blockedOrchestratorStream "event: agent_status"
Assert-Contains "blocked orchestrator stream sse contract" $blockedOrchestratorStream "phase2-sse-event-contract-v1"
Assert-Contains "blocked orchestrator stream sse evidence" $blockedOrchestratorStream "phase2_sse_event_contract_proof"
Assert-Contains "blocked orchestrator stream error handler" $blockedOrchestratorStream "error_handler"
Assert-Contains "blocked orchestrator stream hard stop" $blockedOrchestratorStream '"node_name":"hard_stop"'
Assert-Contains "blocked orchestrator stream stopped" $blockedOrchestratorStream '"status":"stopped"'
Assert-Contains "blocked orchestrator stream done" $blockedOrchestratorStream "event: done"
$blockedOrchestratorReplayBodyFile = Join-Path $env:TEMP ("orchestrator-hard-stop-replay-" + [Guid]::NewGuid().ToString("N") + ".json")
try {
  Set-Content -Path $blockedOrchestratorReplayBodyFile -Value $blockedOrchestratorBody -NoNewline -Encoding utf8
  $blockedOrchestratorReplay = curl.exe -sN --max-time 15 -H "Last-Event-ID: 0" -X POST -H "Content-Type: application/json" --data-binary "@$blockedOrchestratorReplayBodyFile" "$baseUrl/api/v1/orchestrator/dry-run/stream"
} finally {
  if (Test-Path $blockedOrchestratorReplayBodyFile) { Remove-Item -LiteralPath $blockedOrchestratorReplayBodyFile -Force }
}
Assert-Contains "blocked orchestrator replay flag" $blockedOrchestratorReplay '"replay":true'
Assert-Contains "blocked orchestrator replay hard stop" $blockedOrchestratorReplay '"node_name":"hard_stop"'
Assert-Contains "blocked orchestrator replay stopped" $blockedOrchestratorReplay '"status":"stopped"'
Assert-Contains "blocked orchestrator replay done" $blockedOrchestratorReplay "event: done"

Write-Host "[runtime] langgraph orchestrator sse dry-run stream"
$orchestratorBodyFile = Join-Path $env:TEMP ("orchestrator-stream-" + [Guid]::NewGuid().ToString("N") + ".json")
try {
  Set-Content -Path $orchestratorBodyFile -Value $orchestratorBody -NoNewline -Encoding utf8
  $orchestratorStream = curl.exe -sN --max-time 25 -X POST -H "Content-Type: application/json" --data-binary "@$orchestratorBodyFile" "$baseUrl/api/v1/orchestrator/dry-run/stream"
} finally {
  if (Test-Path $orchestratorBodyFile) { Remove-Item -LiteralPath $orchestratorBodyFile -Force }
}
Assert-Contains "orchestrator stream start" $orchestratorStream "event: graph_status"
Assert-Contains "orchestrator stream event id" $orchestratorStream "id: "
Assert-Contains "orchestrator stream heartbeat" $orchestratorStream "event: heartbeat"
Assert-Contains "orchestrator stream agent status" $orchestratorStream "event: agent_status"
Assert-Contains "orchestrator stream sse contract" $orchestratorStream "phase2-sse-event-contract-v1"
Assert-Contains "orchestrator stream sse evidence" $orchestratorStream "phase2_sse_event_contract_proof"
Assert-Contains "orchestrator stream required heartbeat" $orchestratorStream "heartbeat"
Assert-Contains "orchestrator stream required error" $orchestratorStream "error"
Assert-Contains "orchestrator stream node event" $orchestratorStream "event: graph_node"
Assert-Contains "orchestrator stream intent parser" $orchestratorStream "intent_parser"
Assert-Contains "orchestrator stream budget guard" $orchestratorStream "budget_guard"
Assert-Contains "orchestrator stream memory updater" $orchestratorStream "memory_updater"
Assert-Contains "orchestrator stream llm gateway evidence" $orchestratorStream "llm_gateway_dry_run"
Assert-Contains "orchestrator stream llm gateway streaming evidence" $orchestratorStream "llm_gateway_streaming_dry_run"
Assert-Contains "orchestrator stream llm routing policy evidence" $orchestratorStream "llm_routing_policy_primary_allowed"
Assert-Contains "orchestrator stream llm routing policy decision" $orchestratorStream '"routing_policy_decision":"allow_primary"'
Assert-Contains "orchestrator stream consumed llm gateway stream" $orchestratorStream '"streaming_used":true'
Assert-Contains "orchestrator stream memory context evidence" $orchestratorStream "memory_context_injected"
Assert-Contains "orchestrator stream memory context budget" $orchestratorStream "memory_context_budget"
Assert-Contains "orchestrator stream persisted memory update evidence" $orchestratorStream "memory_update_persisted"
Assert-Contains "orchestrator stream persisted memory update id" $orchestratorStream "memory_update_id"
Assert-Contains "orchestrator stream task assignment evidence" $orchestratorStream "task_assignment_completed"
Assert-Contains "orchestrator stream task assignments" $orchestratorStream "task_assignments"
Assert-Contains "orchestrator stream mcp evidence" $orchestratorStream "mcp_tool_success"
Assert-Contains "orchestrator stream mcp tool calls" $orchestratorStream "mcp_tool_calls"
Assert-Contains "orchestrator stream mcp safe envelope" $orchestratorStream "mcp_safe_envelope"
Assert-Contains "orchestrator stream done" $orchestratorStream "event: done"
Assert-Contains "orchestrator stream postgres checkpointing" $orchestratorStream '"checkpointing":"postgres"'
$orchestratorReplayBodyFile = Join-Path $env:TEMP ("orchestrator-replay-" + [Guid]::NewGuid().ToString("N") + ".json")
try {
  Set-Content -Path $orchestratorReplayBodyFile -Value $orchestratorBody -NoNewline -Encoding utf8
  $orchestratorReplay = curl.exe -sN --max-time 15 -H "Last-Event-ID: 0" -X POST -H "Content-Type: application/json" --data-binary "@$orchestratorReplayBodyFile" "$baseUrl/api/v1/orchestrator/dry-run/stream"
} finally {
  if (Test-Path $orchestratorReplayBodyFile) { Remove-Item -LiteralPath $orchestratorReplayBodyFile -Force }
}
Assert-Contains "orchestrator replay flag" $orchestratorReplay '"replay":true'
Assert-Contains "orchestrator replay intent parser" $orchestratorReplay "intent_parser"
Assert-Contains "orchestrator replay llm gateway evidence" $orchestratorReplay "llm_gateway_dry_run"
Assert-Contains "orchestrator replay llm gateway streaming evidence" $orchestratorReplay "llm_gateway_streaming_dry_run"
Assert-Contains "orchestrator replay llm routing policy evidence" $orchestratorReplay "llm_routing_policy_primary_allowed"
Assert-Contains "orchestrator replay llm routing policy decision" $orchestratorReplay '"routing_policy_decision":"allow_primary"'
Assert-Contains "orchestrator replay memory context evidence" $orchestratorReplay "memory_context_injected"
Assert-Contains "orchestrator replay persisted memory update evidence" $orchestratorReplay "memory_update_persisted"
Assert-Contains "orchestrator replay task assignment evidence" $orchestratorReplay "task_assignment_completed"
Assert-Contains "orchestrator replay mcp evidence" $orchestratorReplay "mcp_tool_success"
Assert-Contains "orchestrator replay mcp safe envelope" $orchestratorReplay "mcp_safe_envelope"
Assert-Contains "orchestrator replay completed" $orchestratorReplay '"status":"completed"'
Assert-Contains "orchestrator replay done" $orchestratorReplay "event: done"

Write-Host "[runtime] langgraph orchestrator sse error event contract"
$orchestratorErrorThreadId = [Guid]::NewGuid().ToString()
$orchestratorErrorBody = @{
  project_id = $projectId
  prompt = "force_phase2_sse_error_event"
  session_id = $orchestratorErrorThreadId
} | ConvertTo-Json -Compress
$orchestratorErrorBodyFile = Join-Path $env:TEMP ("orchestrator-sse-error-" + [Guid]::NewGuid().ToString("N") + ".json")
try {
  Set-Content -Path $orchestratorErrorBodyFile -Value $orchestratorErrorBody -NoNewline -Encoding utf8
  $orchestratorErrorStream = curl.exe -sN --max-time 10 -X POST -H "Content-Type: application/json" --data-binary "@$orchestratorErrorBodyFile" "$baseUrl/api/v1/orchestrator/dry-run/stream"
} finally {
  if (Test-Path $orchestratorErrorBodyFile) { Remove-Item -LiteralPath $orchestratorErrorBodyFile -Force }
}
Assert-Contains "orchestrator error stream heartbeat" $orchestratorErrorStream "event: heartbeat"
Assert-Contains "orchestrator error stream agent status" $orchestratorErrorStream "event: agent_status"
Assert-Contains "orchestrator error stream error event" $orchestratorErrorStream "event: error"
Assert-Contains "orchestrator error stream done event" $orchestratorErrorStream "event: done"
Assert-Contains "orchestrator error stream contract" $orchestratorErrorStream "phase2-sse-event-contract-v1"
Assert-Contains "orchestrator error stream evidence" $orchestratorErrorStream "phase2_sse_event_contract_proof"
Assert-Contains "orchestrator error stream code" $orchestratorErrorStream "forced_phase2_sse_error_event"
Assert-Contains "orchestrator error stream terminal status" $orchestratorErrorStream '"status":"error"'
Assert-Contains "orchestrator error stream no live provider" $orchestratorErrorStream '"live_provider_calls":false'

$checkpointBefore = curl.exe -sS "$baseUrl/api/v1/orchestrator/checkpoints/$threadId"
Assert-Contains "orchestrator checkpoint before restart" $checkpointBefore '"checkpointing":"postgres"'
Assert-Contains "orchestrator checkpoint completed before restart" $checkpointBefore '"node_name":"completed"'

Write-Host "[runtime] langgraph postgres checkpoint restart recovery"
$env:NGINX_HTTP_PORT = $port
docker compose -f docker-compose.dev.yml up -d --force-recreate agent-api nginx
Assert-LastExitCode "restart agent-api for checkpoint recovery"
$healthAfterRestart = Wait-UrlContains "agent-api health after checkpoint restart" "$baseUrl/api/v1/health" '"status":"healthy"' 45
$checkpointAfter = curl.exe -sS "$baseUrl/api/v1/orchestrator/checkpoints/$threadId"
Assert-Contains "orchestrator checkpoint after restart" $checkpointAfter '"checkpointing":"postgres"'
Assert-Contains "orchestrator checkpoint completed after restart" $checkpointAfter '"node_name":"completed"'
Assert-Contains "orchestrator checkpoint thread after restart" $checkpointAfter $threadId

Write-Host "[runtime] model capability matrix"
$modelCapabilities = curl.exe -sS "$baseUrl/api/v1/models/capabilities"
Assert-Contains "model planner route" $modelCapabilities '"agent_type":"planner"'
Assert-Contains "model coder output budget" $modelCapabilities '"max_output_tokens":8192'
Assert-Contains "model devops route" $modelCapabilities '"agent_type":"devops"'
Assert-Contains "model agent profiles embedded" $modelCapabilities '"agent_profiles"'
Assert-Contains "model memory budget" $modelCapabilities '"memory_injection_budget_percent_max":30'
Assert-Contains "model configured only note" $modelCapabilities '"configured_only":true'

Write-Host "[runtime] rotation policy"
$rotationPolicy = curl.exe -sS "$baseUrl/api/v1/rotation/policy"
Assert-Contains "rotation backoff" $rotationPolicy '"backoff_seconds":[30,60,120,300]'
Assert-Contains "rotation budget guard" $rotationPolicy '"budget_guard_required_before_rotation":true'
Assert-Contains "rotation log format" $rotationPolicy '"rotation_log_format"'
Assert-Contains "rotation provider fallback contract" $rotationPolicy "provider-fallback-event-v1"
Assert-Contains "rotation provider fallback evidence" $rotationPolicy "provider_fallback_structured_event"
Assert-Contains "rotation cost metadata format" $rotationPolicy "cost_metadata"

Write-Host "[runtime] rotation event audit"
$rotationEvent = docker exec cloud-superbrain-phase1-dev-agent-api-1 python -c "import json, urllib.request; data=json.dumps({'from_provider':'huggingface_inference_router','to_provider':'huggingface_inference_router','from_model':'deepseek-ai/DeepSeek-V4-Pro:fastest','to_model':'Qwen/Qwen3.6-35B-A3B:fastest','fallback_index':1,'routing_policy_decision':'allow_fallback','reason':'rate_limited','agent':'planner','session_id':'$($response.session_id)','trace_id':'runtime-rotation-proof','input_tokens':321,'output_tokens':123,'estimated_cost_cents':0,'budget_level':'ok'}).encode(); req=urllib.request.Request('http://127.0.0.1:8000/internal/rotation/events', data=data, headers={'Content-Type':'application/json'}, method='POST'); print(urllib.request.urlopen(req, timeout=5).read().decode())"
Assert-Contains "rotation event id" $rotationEvent '"event_id"'
Assert-Contains "rotation event type" $rotationEvent '"event_type":"provider_rotated"'
Assert-Contains "rotation event contract" $rotationEvent '"contract_version":"provider-fallback-event-v1"'
Assert-Contains "rotation event evidence" $rotationEvent '"evidence_ref":"provider_fallback_structured_event"'
Assert-Contains "rotation event live provider false" $rotationEvent '"live_provider_calls":false'
Assert-Contains "rotation event fallback index" $rotationEvent '"fallback_index":1'
Assert-Contains "rotation event cost metadata" $rotationEvent '"cost_metadata"'
Assert-Contains "rotation event estimated cost" $rotationEvent '"estimated_cost_cents":0'
$rotationEvents = curl.exe -sS "$baseUrl/api/v1/rotation/events?limit=10"
Assert-Contains "rotation events contract" $rotationEvents '"contract_version":"provider-fallback-event-v1"'
Assert-Contains "rotation events evidence" $rotationEvents '"evidence_ref":"provider_fallback_structured_event"'
Assert-Contains "rotation events trace" $rotationEvents "runtime-rotation-proof"
Assert-Contains "rotation events reason" $rotationEvents '"reason":"rate_limited"'
Assert-Contains "rotation events provider" $rotationEvents '"to_provider":"huggingface_inference_router"'
Assert-Contains "rotation events model" $rotationEvents '"to_model":"Qwen/Qwen3.6-35B-A3B:fastest"'
Assert-Contains "rotation events cost metadata" $rotationEvents '"cost_metadata"'

Write-Host "[runtime] post-recreate steady-state proof"
$steadyHealth = Wait-UrlContains "post-recreate health" "$baseUrl/api/v1/health" '"status":"healthy"' 45
Assert-Contains "post-recreate agent worker health" $steadyHealth '"agent_worker":{"status":"healthy"'
Assert-Contains "post-recreate memory worker health" $steadyHealth '"memory_worker":{"status":"healthy"'
$steadyProgressIntegrity = Wait-UrlContains "post-recreate project progress integrity" "$baseUrl/api/v1/project/progress/integrity" '"status":"verified"' 45
Assert-Contains "post-recreate project progress integrity computed" $steadyProgressIntegrity ('"computed_overall_percent":{0}' -f $expectedOverallPercent)
Assert-Contains "post-recreate project progress integrity manifest" $steadyProgressIntegrity ('"manifest_overall_percent":{0}' -f $expectedOverallPercent)
$steadyMcpVersionPinning = Wait-UrlContains "post-recreate mcp version pinning" "$baseUrl/mcp/api/v1/version-pinning/contract" '"contract_version":"mcp-version-pinning-v1"' 45
Assert-Contains "post-recreate mcp version pinning evidence" $steadyMcpVersionPinning "mcp_version_pinning_contract_visible"
$steadyMemoryEmbeddingConsistency = Wait-UrlContains "post-recreate memory embedding consistency" "$baseUrl/api/v1/memory/embedding-consistency/contract" '"contract_version":"memory-embedding-consistency-v1"' 45
Assert-Contains "post-recreate memory embedding consistency evidence" $steadyMemoryEmbeddingConsistency "memory_embedding_consistency_contract_visible"
$steadyFaviconStatus = curl.exe -sS -o NUL -w "%{http_code}" "$baseUrl/favicon.ico" 2>$null
if ($LASTEXITCODE -ne 0 -or $steadyFaviconStatus -ne "200") {
  throw "Runtime verification failed: post-recreate favicon returned HTTP $steadyFaviconStatus"
}

Write-Host "[runtime] phase1 runtime checks completed"

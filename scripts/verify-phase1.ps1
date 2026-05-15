$ErrorActionPreference = "Stop"

function Assert-LastExitCode($label) {
  if ($LASTEXITCODE -ne 0) {
    throw "Verification failed: $label"
  }
}

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Assert-RegexContains($label, $value, $pattern) {
  $text = ($value | Out-String)
  if (-not [regex]::IsMatch($text, $pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)) {
    throw "Verification failed: $label did not match pattern '$pattern'. Value: $text"
  }
}

Write-Host "[verify] docker compose config"
docker compose -f docker-compose.dev.yml config | Out-Null
Assert-LastExitCode "docker compose config"
docker compose -f docker-compose.cloud.yml config | Out-Null
Assert-LastExitCode "docker compose cloud config"

Write-Host "[verify] forbidden compose terms"
$forbidden = Select-String -Path "docker-compose.dev.yml" -Pattern "qdrant|latest|CPX51|Supabase" -CaseSensitive:$false
if ($forbidden) {
  $forbidden | ForEach-Object { Write-Error $_.Line }
  throw "Forbidden compose term found"
}

Write-Host "[verify] governance drift guards"
if (Test-Path ".github\workflows\supabase-keepalive.yml") {
  throw "Supabase keepalive workflow must not exist after ADR-007"
}
$agentsText = Get-Content -Path "AGENTS.md" -Raw
foreach ($forbiddenAgentTerm in @(
  "Supabase (PostgreSQL) / LanceDB",
  "Google Colab + Puppeteer",
  "Use Railway as the backend runtime",
  "HuggingFace Spaces as production runtime",
  "Ollama as active MVP runtime"
)) {
  if ($agentsText.Contains($forbiddenAgentTerm)) {
    throw "AGENTS.md contains superseded active stack term: $forbiddenAgentTerm"
  }
}
foreach ($requiredAgentTerm in @(
  'docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md',
  'PostgreSQL/pgvector',
  'No Qdrant in Phase 1-5',
  'No Supabase, LanceDB, Ollama, Railway, or HuggingFace Spaces',
  'Overall percent from `docs/project-progress.manifest.json`'
)) {
  if (-not $agentsText.Contains($requiredAgentTerm)) {
    throw "AGENTS.md missing active governance guard: $requiredAgentTerm"
  }
}
$docsMemorySchema = Get-Content -Path "docs\memory\schema.md" -Raw
foreach ($forbiddenMemoryTerm in @("qdrant_point_id", "Qdrant ist im MVP", "Qdrant darf speichern", "Wechsel der DB-Strategie aus ADR-004")) {
  if ($docsMemorySchema.Contains($forbiddenMemoryTerm)) {
    throw "docs/memory/schema.md contains superseded memory drift term: $forbiddenMemoryTerm"
  }
}
$codexSkillMaster = Get-Content -Path "docs\codex-integration\CODEX_AGENT_SKILL_MASTER.md" -Raw
foreach ($forbiddenCodexTerm in @("MVP-Embeddings:  Supabase Free Tier", "supabase-keepalive", "CPX31 (~10", "Embeddings→Supabase")) {
  if ($codexSkillMaster.Contains($forbiddenCodexTerm)) {
    throw "Codex skill master contains superseded governance term: $forbiddenCodexTerm"
  }
}
$secretStrategy = Get-Content -Path "docs\secrets-strategy.md" -Raw
foreach ($forbiddenSecretTerm in @("SUPABASE_SERVICE_ROLE_KEY", "NEXT_PUBLIC_SUPABASE_URL", "NEXT_PUBLIC_SUPABASE_ANON_KEY", "VECTOR_STORE_API_KEY")) {
  if ($secretStrategy.Contains($forbiddenSecretTerm)) {
    throw "Secrets strategy contains superseded Supabase/vector-store term: $forbiddenSecretTerm"
  }
}

Write-Host "[verify] python syntax"
py -3 -m py_compile `
  services\agent-api\app\main.py `
  services\agent-api\app\db.py `
  services\agent-api\app\security.py `
  services\agent-api\app\clouds.py `
  services\agent-api\app\orchestrator.py `
  services\agent-api\app\budget.py `
  services\agent-api\app\tasks.py `
  services\agent-api\app\memory.py `
  services\agent-api\app\models.py `
  services\llm-gateway\app\main.py `
  services\agent-worker\app\worker.py `
  services\mcp-gateway\app\main.py
Assert-LastExitCode "python syntax"

Write-Host "[verify] migration files"
if (-not (Test-Path "services\agent-api\app\migrations\001_foundation_schema.sql")) {
  throw "Missing foundation schema migration"
}
$foundationMigration = Get-Content -Path "services\agent-api\app\migrations\001_foundation_schema.sql" -Raw
foreach ($required in @("content_embedding vector(1536)", "embedding_model_version VARCHAR(100)", "idx_memory_embedding_model_version")) {
  if (-not $foundationMigration.Contains($required)) {
    throw "Foundation migration missing embedding consistency guard: $required"
  }
}

Write-Host "[verify] audit ADR coverage"
foreach ($adrFile in @(
  "docs\adr\ADR-008-single-tenant-assumption.md",
  "docs\adr\ADR-009-auth-design.md"
)) {
  if (-not (Test-Path $adrFile)) {
    throw "Missing audit ADR coverage file: $adrFile"
  }
}
$adrIndex = Get-Content -Path "docs\adr\README.md" -Raw
foreach ($required in @(
  "ADR-008",
  "Single-Tenant Assumption Through Phase 5",
  "ADR-009",
  "Auth Design For Owner-Gated Runtime",
  "Audit Mapping"
)) {
  if (-not $adrIndex.Contains($required)) {
    throw "ADR index missing audit coverage marker: $required"
  }
}

Write-Host "[verify] frontend package json"
node -e "JSON.parse(require('fs').readFileSync('apps/frontend/package.json','utf8'))"
Assert-LastExitCode "frontend package json"
if (-not (Test-Path "apps\frontend\app\favicon.ico\route.ts")) {
  throw "Missing frontend favicon route for browser console clean proof"
}

Write-Host "[verify] app dockerfiles non-root"
$dockerfiles = @(
  "apps\frontend\Dockerfile",
  "services\agent-api\Dockerfile",
  "services\llm-gateway\Dockerfile",
  "services\agent-worker\Dockerfile",
  "services\memory-worker\Dockerfile",
  "services\mcp-gateway\Dockerfile"
)
foreach ($dockerfile in $dockerfiles) {
  $content = Get-Content -Path $dockerfile -Raw
  if (-not $content.Contains("USER appuser")) {
    throw "Dockerfile must set USER appuser: $dockerfile"
  }
}

Write-Host "[verify] app compose security hardening"
$composeText = Get-Content -Path "docker-compose.dev.yml" -Raw
foreach ($service in @("frontend", "agent-api", "agent-worker", "memory-worker", "mcp-gateway", "llm-gateway")) {
  $pattern = "(?ms)^\s{2}${service}:\s.*?(?=^\s{2}[a-zA-Z0-9_-]+:|\z)"
  $match = [regex]::Match($composeText, $pattern)
  if (-not $match.Success) {
    throw "Missing compose service: $service"
  }
  $block = $match.Value
  foreach ($required in @("cap_drop:", "- ALL", "security_opt:", "no-new-privileges:true", "read_only: true", "tmpfs:", "- /tmp")) {
    if (-not $block.Contains($required)) {
      throw "Compose service $service missing security hardening: $required"
    }
  }
}

Write-Host "[verify] cloud compose pull-based substrate"
if (-not (Test-Path "docker-compose.cloud.yml")) {
  throw "Missing cloud pull-based compose file"
}
if (-not (Test-Path "infrastructure\nginx\cloud.conf")) {
  throw "Missing cloud Nginx config"
}
$cloudComposeText = Get-Content -Path "docker-compose.cloud.yml" -Raw
foreach ($required in @(
  "GHCR_IMAGE_NAMESPACE",
  "cloud-superbrain-developer-platform",
  "pull_policy: always",
  "agent-api",
  "agent-worker",
  "memory-worker",
  "mcp-gateway",
  "llm-gateway",
  "frontend",
  "postgres",
  "redis",
  "nginx",
  "infrastructure/nginx/cloud.conf",
  "PROJECT_PROGRESS_MANIFEST_PATH",
  "HETZNER_API_TOKEN",
  "CLOUDFLARE_API_TOKEN",
  "VERCEL_TOKEN",
  "GITHUB_TOKEN",
  "GHCR_TOKEN",
  "HF_TOKEN",
  "GITLAB_TOKEN",
  "LLM_GATEWAY_URL",
  "MCP_GATEWAY_URL"
)) {
  if (-not $cloudComposeText.Contains($required)) {
    throw "Cloud compose missing deployment guard: $required"
  }
}
if (
  -not $cloudComposeText.Contains("docs/project-progress.manifest.json") -and
  -not $cloudComposeText.Contains("progress/project-progress.manifest.json")
) {
  throw "Cloud compose missing deployment guard: project progress manifest mount"
}
$envExample = Get-Content -Path ".env.example" -Raw
foreach ($required in @("GHCR_IMAGE_NAMESPACE", "IMAGE_TAG", "AGENT_API_BASE_URL", "MCP_GATEWAY_BASE_URL", "LLM_GATEWAY_BASE_URL")) {
  if (-not $envExample.Contains($required)) {
    throw ".env.example missing cloud deployment variable: $required"
  }
}
$cloudNginx = Get-Content -Path "infrastructure\nginx\cloud.conf" -Raw
foreach ($required in @('proxy_pass $agent_api', 'proxy_pass $mcp_gateway', 'proxy_pass $llm_gateway', 'proxy_pass $frontend', 'X-Forwarded-Host')) {
  if (-not $cloudNginx.Contains($required)) {
    throw "Cloud Nginx config missing route guard: $required"
  }
}

Write-Host "[verify] frontend npm audit"
npm audit --audit-level=moderate --prefix apps/frontend
Assert-LastExitCode "frontend npm audit"

Write-Host "[verify] ci budget script"
py -3 -m py_compile scripts\check_hetzner_infra_budget.py
Assert-LastExitCode "ci budget script"

Write-Host "[verify] project progress manifest"
py -3 -m py_compile scripts\verify_project_progress_manifest.py
Assert-LastExitCode "project progress manifest syntax"
py -3 scripts\verify_project_progress_manifest.py
Assert-LastExitCode "project progress manifest"
$projectProgressManifest = Get-Content -Path "docs\project-progress.manifest.json" -Raw
if (-not $projectProgressManifest.Contains("runtime-post-recreate-steady-state-proof")) {
  throw "Project progress manifest missing runtime post-recreate steady-state proof marker"
}
$projectProgress = $projectProgressManifest | ConvertFrom-Json
$horizontalById = @{}
foreach ($item in $projectProgress.horizontal.items) {
  $horizontalById[$item.id] = [int]$item.percent
}
$verticalByLabel = @{}
foreach ($item in $projectProgress.vertical.items) {
  $verticalByLabel[$item.label] = [int]$item.percent
}
$currentOverall = [int]$projectProgress.overall_percent
$currentPhase1 = $horizontalById["phase_1"]
$currentPhase2 = $horizontalById["phase_2"]
$currentPhase4 = $horizontalById["phase_4"]
$currentFrontend = $verticalByLabel["Frontend / Next.js"]
$currentAgentPool = $verticalByLabel["Agent Pool"]
$currentLlmGateway = $verticalByLabel["LLM Gateway"]
$currentMcpGateway = $verticalByLabel["MCP Gateway"]
$currentMemory = $verticalByLabel["Memory"]
$currentObservability = $verticalByLabel["Observability"]

Write-Host "[verify] browser MCP evidence register"
$verificationRegister = Get-Content -Path "docs\verification-register.md" -Raw
foreach ($forbiddenBrowserMcpTerm in @(
  "Playwright bridge is still not installed",
  "Chrome remote debugging is still not listening on 9222",
  "fallback Puppeteer browser proof is now captured"
)) {
  if ($verificationRegister.Contains($forbiddenBrowserMcpTerm)) {
    throw "Verification register contains stale Browser MCP evidence note: $forbiddenBrowserMcpTerm"
  }
}
foreach ($requiredBrowserMcpTerm in @(
  'Playwright MCP AI-browser proof',
  'fresh-page console sample of `0 errors/warnings`',
  'Progress Integrity',
  'project_progress_integrity_runtime_proof',
  'superbrain-ai-browser-clean-proof-2026-04-29.png',
  'superbrain-live-ui-proof',
  'No progress percentage changes'
)) {
  if (-not $verificationRegister.Contains($requiredBrowserMcpTerm)) {
    throw "Verification register missing current Browser MCP evidence marker: $requiredBrowserMcpTerm"
  }
}
foreach ($forbiddenProgressRegisterTerm in @(
  'visible dashboard still exposes `Total Project 45%`',
  '`Phase 2 - Core Runtime 81%`',
  '`Agent Pool 59%`, `Frontend / Next.js 96%`',
  'Phase 4 `11%`, Frontend `97%`, and Agent Pool `61%`'
)) {
  if ($verificationRegister.Contains($forbiddenProgressRegisterTerm)) {
    throw "Verification register contains stale active progress proof: $forbiddenProgressRegisterTerm"
  }
}
foreach ($requiredProgressRegisterTerm in @(
  'Current Progress Authority',
  'Current progress claims are authoritative only when they match `docs/project-progress.manifest.json`, `GET /api/v1/project/progress`, and `GET /api/v1/project/progress/integrity`',
  'Historical milestone notes below may mention older then-current percentages, but they are not current progress claims',
  "Current verified progress is total ``$currentOverall%``",
  "Phase 1 ``$currentPhase1%``",
  "Phase 2 ``$currentPhase2%``",
  "Phase 4 ``$currentPhase4%``",
  "Frontend ``$currentFrontend%``",
  "Agent Pool ``$currentAgentPool%``",
  "LLM Gateway ``$currentLlmGateway%``",
  "MCP Gateway ``$currentMcpGateway%``",
  "Memory ``$currentMemory%``",
  "Observability ``$currentObservability%``",
  'Historical compact UI readability snapshot',
  'current Playwright MCP AI-browser proof now confirms',
  'reports total'
)) {
  if (-not $verificationRegister.Contains($requiredProgressRegisterTerm)) {
    throw "Verification register missing current progress proof marker: $requiredProgressRegisterTerm"
  }
}

Write-Host "[verify] project state progress drift"
$projectState = Get-Content -Path "PROJECT_STATE.md" -Raw
foreach ($forbiddenProjectStateTerm in @(
  'Der Harness beweist Health, Projektfortschritt `46%`',
  'Frontend `96%`, Agent Pool `59%`',
  'Gesamtstand `46%`, horizontale',
  'Browser-Proof bestaetigt `Phase 2 82%`, `Agent Pool 59%`',
  'Fortschritt bleibt Gesamt `46%`',
  'Fortschritt steigt evidenzbasiert auf Gesamt `46%`'
)) {
  if ($projectState.Contains($forbiddenProjectStateTerm)) {
    throw "PROJECT_STATE.md contains stale active progress claim: $forbiddenProjectStateTerm"
  }
}
foreach ($requiredProjectStateTerm in @(
  "AKTUELLER FORTSCHRITT: $currentOverall%",
  '| P1   |',
  '| P2   |',
  '| P4   |',
  '| Memory        |'
)) {
  if (-not $projectState.Contains($requiredProjectStateTerm)) {
    throw "PROJECT_STATE.md missing current progress marker: $requiredProjectStateTerm"
  }
}
Assert-RegexContains "PROJECT_STATE.md phase 1 row" $projectState "\|\s*P1\s*\|\s*$currentPhase1%\s*\|"
Assert-RegexContains "PROJECT_STATE.md phase 2 row" $projectState "\|\s*P2\s*\|\s*$currentPhase2%\s*\|"
Assert-RegexContains "PROJECT_STATE.md phase 4 row" $projectState "\|\s*P4\s*\|\s*$currentPhase4%\s*\|"
Assert-RegexContains "PROJECT_STATE.md frontend row" $projectState "\|\s*Frontend\s*\|\s*$currentFrontend%\s*\|"
Assert-RegexContains "PROJECT_STATE.md agent pool row" $projectState "\|\s*Agent Pool\s*\|\s*$currentAgentPool%\s*\|"
Assert-RegexContains "PROJECT_STATE.md memory row" $projectState "\|\s*Memory\s*\|\s*$currentMemory%\s*\|"

Write-Host "[verify] AI handoff progress drift"
$aiHandoff = Get-Content -Path "AI_HANDOFF.md" -Raw
foreach ($forbiddenAiHandoffTerm in @(
  'This raised Phase 4 from `7%` to `8%`. Overall remained `46%`.',
  'This raised Phase 4 from `8%` to `9%`, Agent Pool from `59%` to `60%`, MCP Gateway from `51%` to `52%`, and Overall from `46%` to `47%`.',
  'This raised Phase 4 from `9%` to `10%` and Frontend from `96%` to `97%`. Overall remains `47%`.'
)) {
  if ($aiHandoff.Contains($forbiddenAiHandoffTerm)) {
    throw "AI_HANDOFF.md contains stale active progress phrasing: $forbiddenAiHandoffTerm"
  }
}
foreach ($requiredAiHandoffTerm in @(
  'Current Verified Progress',
  "Overall: ``$currentOverall%``",
  "- P1: ``$currentPhase1%``",
  "- P2: ``$currentPhase2%``",
  "- P4: ``$currentPhase4%``",
  "- Frontend / Next.js: ``$currentFrontend%``",
  "- Agent Pool: ``$currentAgentPool%``",
  "- Memory: ``$currentMemory%``",
  'Older percentage lines below are historical proof points only',
  'current verified progress remains defined by the `Current Verified Progress` section above'
)) {
  if (-not $aiHandoff.Contains($requiredAiHandoffTerm)) {
    throw "AI_HANDOFF.md missing current progress marker: $requiredAiHandoffTerm"
  }
}
py -3 -m py_compile scripts\verify-phase-transition-gate.py
Assert-LastExitCode "phase transition gate syntax"
py -3 scripts\verify-phase-transition-gate.py
Assert-LastExitCode "phase transition gate"

Write-Host "[verify] task policy gate source"
$taskPolicySource = Get-Content -Path "services\agent-api\app\tasks.py" -Raw
if (-not $taskPolicySource.Contains("REQUIRED_BLOCKED_ACTIONS")) { throw "Missing task policy blocked-action registry" }
if (-not $taskPolicySource.Contains("validate_task_policy")) { throw "Missing task policy validator" }
if (-not $taskPolicySource.Contains("fail_closed_before_enqueue")) { throw "Missing fail-closed task policy manifest" }
if (-not $taskPolicySource.Contains("PROFILE_BY_AGENT")) { throw "Missing agent profile task policy registry" }
if (-not $taskPolicySource.Contains("profile_gates")) { throw "Missing profile-gated task policy manifest" }
if (-not $taskPolicySource.Contains("profile does not allow tools")) { throw "Missing profile-specific tool gate" }
if (-not $taskPolicySource.Contains("deployment-like tasks must be routed to devops profile")) { throw "Missing deployment profile routing gate" }
$apiTaskPolicySource = Get-Content -Path "services\agent-api\app\main.py" -Raw
if (-not $apiTaskPolicySource.Contains("task_policy_blocked")) { throw "Missing task policy audit event" }
if (-not $apiTaskPolicySource.Contains("/api/v1/tasks/policy/validate")) { throw "Missing public task policy validation endpoint" }
$cloudProviderSource = Get-Content -Path "services\agent-api\app\clouds.py" -Raw
foreach ($required in @("cloud-provider-inventory-v1", "cloud_provider_inventory_visible", "cloud-layer-readiness-v1", "cloud_layer_readiness_visible", "GET /api/v1/clouds", "GET /api/v1/clouds/layers", "seven_layer_mapping", "cloud_layer_readiness_state", "HETZNER_API_TOKEN", "hetzner_api_readonly", "CLOUDFLARE_API_TOKEN", "cloudflare_api_readonly", "CLOUDFLARE_DASHBOARD_URL", "VERCEL_TOKEN", "vercel_api_readonly", "GITHUB_TOKEN", "github_api_readonly", "GHCR_TOKEN", "ghcr_api_readonly", "HF_TOKEN", "huggingface_api_readonly", "GITLAB_TOKEN", "gitlab_api_readonly", "GITKRAKEN_API_TOKEN", "gitkraken_api_readonly", "No secret values", "mask_ip", "vercel_frontend", "cloudflare_edge", "github_actions", "ghcr_registry", "huggingface_identity", "gitlab_identity", "gitkraken_identity")) {
  if (-not $cloudProviderSource.Contains($required)) {
    throw "Missing cloud provider inventory source guard: $required"
  }
}
foreach ($required in @("cloud_provider_state", "cloud_layer_readiness_state", "/api/v1/clouds", "/api/v1/clouds/layers", "cloud-render-offload-v1", "cloud_render_offload_contract_visible", "/api/v1/clouds/render-offload/contract", "localhost_heavy_render_allowed", "cloud_render_offload_requires_STAGING_BASE_URL")) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing cloud provider inventory API guard: $required"
  }
}
foreach ($required in @(
  "AuthRefreshRequest",
  "auth_contract_payload",
  "/api/v1/auth/contract",
  "/api/v1/auth/github",
  "/api/v1/auth/callback",
  "/api/v1/auth/refresh",
  "/api/v1/auth/logout",
  "auth-github-jwt-refresh-v1",
  "auth_refresh_rotated",
  "auth_refresh_reuse_blocked",
  "auth_logout_revoked",
  "AUTH_BLACKLIST_PREFIX",
  "SameSite"
)) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing Auth JWT refresh contract guard: $required"
  }
}
foreach ($required in @(
  "MemoryPurgeRequest",
  "memory_purge_contract_payload",
  "execute_memory_purge",
  "get_memory_purge_job_status",
  "/api/v1/memory/purge/contract",
  "/api/v1/memory/purge/jobs/{job_id}",
  "@app.delete(`"/api/v1/memory`"",
  "memory-dsgvo-purge-v1",
  "memory_purge_completed",
  "memory_purge_job_status_visible",
  "memory_purge_confirmation_required",
  "DSGVO_PURGE_CONTRACT_VERSION"
)) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing Memory Purge DSGVO contract guard: $required"
  }
}
foreach ($required in @(
  "MemoryEntryDeleteRequest",
  "execute_memory_entry_delete",
  "/api/v1/memory/{memory_id}",
  "memory_entry_deleted",
  "memory_entry_delete_completed",
  "memory_entry_delete_confirmation_required",
  "soft_delete_status_deleted"
)) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing single memory entry delete guard: $required"
  }
}
foreach ($required in @(
  "COST_EXPORT_CONTRACT_VERSION",
  "cost_export_contract_payload",
  "cost_export_rows",
  "build_cost_export_csv",
  "persist_cost_export_audit",
  "/api/v1/costs/export/contract",
  "/api/v1/costs/export",
  "cost-monitor-export-v1",
  "cost_export_csv_generated",
  "cost_export_audit_persisted",
  "cost_export_generated"
)) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing Cost Monitor export contract guard: $required"
  }
}
foreach ($required in @(
  "RATE_LIMIT_CONTRACT_VERSION",
  "rate_limit_contract_payload",
  "/api/v1/rate-limit/contract",
  "/api/v1/rate-limit/status",
  "rate-limit-guard-v1",
  "rate_limit_contract_visible",
  "rate_limit_status_visible",
  "rate_limit_429_enforced",
  "superbrain_prompt_rate_limit_remaining"
)) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing Rate Limit guard API contract: $required"
  }
}
foreach ($required in @(
  "SESSION_LIMIT_CONTRACT_VERSION",
  "session_limit_contract_payload",
  "/api/v1/session-limits/contract",
  "/api/v1/session-limits/status",
  "session-llm-call-limit-v1",
  "session_limit_contract_visible",
  "session_limit_status_visible",
  "session_limit_429_enforced",
  "superbrain_session_llm_call_remaining"
)) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing Session Limit guard API contract: $required"
  }
}
foreach ($required in @(
  "PROMPT_INPUT_CONTRACT_VERSION",
  "prompt_contract_payload",
  "/api/v1/prompt/contract",
  "prompt-input-contract-v1",
  "max_prompt_chars",
  "prompt_input_contract_visible",
  "prompt_input_counter_visible",
  "prompt_input_422_enforced"
)) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing Prompt Input guard API contract: $required"
  }
}
foreach ($required in @(
  "ERROR_RESPONSE_CONTRACT_VERSION",
  "http_exception_envelope_handler",
  "validation_exception_envelope_handler",
  "error_envelope",
  "error_response_contract_payload",
  "/api/v1/errors/contract",
  "error-response-contract-v1",
  "structured_http_error_contract",
  "error_response_contract_visible",
  "error_response_422_visible",
  "error_response_429_visible",
  "error_response_ui_state_visible",
  "error_response_envelope_enforced"
)) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing Error Response contract guard: $required"
  }
}
foreach ($required in @(
  "SECURITY_HEADERS_CONTRACT_VERSION",
  "SECURITY_HEADERS",
  "security_headers_middleware",
  "security_headers_contract_payload",
  "/api/v1/security/headers/contract",
  "security-headers-v1",
  "X-Content-Type-Options",
  "X-Frame-Options",
  "Referrer-Policy",
  "Content-Security-Policy",
  "security_headers_enforced"
)) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing Security Headers contract guard: $required"
  }
}
foreach ($required in @(
  "TRACE_ID_CONTRACT_VERSION",
  "trace_id_middleware",
  "trace_id_contract_payload",
  "/api/v1/trace/contract",
  "trace-id-propagation-v1",
  "X-Trace-Id",
  "X-Superbrain-Trace-Contract",
  "trace_id_header_roundtrip",
  "trace_id_generated_visible"
)) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing Trace ID propagation contract guard: $required"
  }
}
foreach ($required in @(
  "CACHE_CONTROL_CONTRACT_VERSION",
  "CACHE_CONTROL_HEADERS",
  "cache_control_middleware",
  "cache_control_contract_payload",
  "/api/v1/cache/contract",
  "cache-control-no-store-v1",
  "Cache-Control",
  "Pragma",
  "Expires",
  "cache_control_headers_enforced",
  "cache_control_sensitive_payload_no_store"
)) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing Cache Control contract guard: $required"
  }
}
foreach ($required in @(
  "REQUEST_ID_CONTRACT_VERSION",
  "request_id_middleware",
  "request_id_contract_payload",
  "/api/v1/request/contract",
  "request-id-correlation-v1",
  "X-Request-Id",
  "X-Superbrain-Request-Contract",
  "request_id_header_roundtrip",
  "request_id_error_envelope_correlation",
  "request_id_audit_correlation",
  "request_id_audit_feed_visible"
)) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing Request ID correlation contract guard: $required"
  }
}
foreach ($required in @(
  "SYSTEM_FALLBACK_CONTRACT_VERSION",
  "system_fallback_contract_payload",
  "/api/v1/system/fallback/contract",
  "system-unavailable-fallback-v1",
  "system_fallback_contract_visible",
  "system_unavailable_ui_state",
  "system_degraded_service_visible",
  "no_fake_healthy_claim",
  "manual_retry_available"
)) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing system unavailable fallback contract guard: $required"
  }
}
foreach ($required in @(
  "AGENT_ACTIVITY_CONTRACT_VERSION",
  "agent_activity_contract_payload",
  "/api/v1/agent-activity/contract",
  "agent-activity-trace-v1",
  "agent_activity_contract_visible",
  "agent_activity_trace_link_template",
  "langfuse_auth_proxy_required",
  "agent_activity_filtered_feed_visible",
  "/api/v1/agent-activity/recent",
  "recent_agent_activity",
  "no_public_langfuse_without_auth"
)) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing agent activity trace contract guard: $required"
  }
}
foreach ($required in @(
  "WorkflowDispatchRequest",
  "workflow_dispatch_contract",
  "/api/v1/devops/workflow-dispatch/plan",
  "/api/v1/devops/workflow-dispatch/validate",
  "devops-workflow-dispatch-v1",
  "workflow_dispatch_blocked",
  "devops_workflow_dispatch_contract",
  "live_github_call"
)) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing DevOps workflow dispatch contract guard: $required"
  }
}
$frontendSource = Get-Content -Path "apps\frontend\app\page.tsx" -Raw
foreach ($required in @("Auth Contract", "loadAuthContract", "AuthContract", "/api/v1/auth/contract", "auth_refresh_rotated", "auth_refresh_reuse_blocked", "SameSite")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing Auth Contract UI guard: $required"
  }
}
foreach ($required in @("Memory Purge Contract", "loadMemoryPurgeContract", "MemoryPurgeContract", "/api/v1/memory/purge/contract", "GET /api/v1/memory/purge/jobs/{job_id}", "Job Status", "DELETE /api/v1/memory", "memory_purge_completed", "memory_purge_job_status_visible", "memory_purge_confirmation_required")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing Memory Purge Contract UI guard: $required"
  }
}
foreach ($required in @("deleteMemoryEntry", "memoryDeleteStatus", "DELETE /api/v1/memory/", "memory_entry_delete_completed", "memory_entry_delete_confirmation_required", "dangerButton")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing single memory entry delete UI guard: $required"
  }
}
foreach ($required in @("CostExportContract", "loadCostExportContract", "/api/v1/costs/export/contract", "/api/v1/costs/export?format=csv", "cost_export_contract_visible", "cost_export_csv_generated", "cost_export_audit_persisted", "CSV Export")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing Cost Monitor Export UI guard: $required"
  }
}
foreach ($required in @("RateLimitContract", "RateLimitStatus", "Rate Limit Guard", "loadRateLimitContract", "loadRateLimitStatus", "/api/v1/rate-limit/contract", "/api/v1/rate-limit/status", "rate_limit_contract_visible", "rate_limit_status_visible", "rate_limit_429_enforced")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing Rate Limit Guard UI guard: $required"
  }
}
foreach ($required in @("SessionLimitContract", "SessionLimitStatus", "Session Limit Guard", "loadSessionLimitContract", "loadSessionLimitStatus", "/api/v1/session-limits/contract", "/api/v1/session-limits/status", "session_limit_contract_visible", "session_limit_status_visible", "session_limit_429_enforced")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing Session Limit Guard UI guard: $required"
  }
}
foreach ($required in @("PromptContract", "Prompt Input Guard", "loadPromptContract", "/api/v1/prompt/contract", "maxLength", "prompt_input_contract_visible", "prompt_input_counter_visible", "prompt_input_422_enforced")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing Prompt Input Guard UI guard: $required"
  }
}
foreach ($required in @("ErrorResponseContract", "Error Response Contract", "loadErrorResponseContract", "/api/v1/errors/contract", "error_response_contract_visible", "error_response_422_visible", "error_response_429_visible", "error_response_ui_state_visible", "error_response_envelope_enforced")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing Error Response Contract UI guard: $required"
  }
}
foreach ($required in @("SecurityHeadersContract", "Security Headers Contract", "loadSecurityHeadersContract", "/api/v1/security/headers/contract", "security_headers_contract_visible", "security_headers_enforced", "security_headers_same_origin_policy", "security_headers_ui_visible")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing Security Headers Contract UI guard: $required"
  }
}
foreach ($required in @("TraceIdContract", "Trace ID Contract", "loadTraceIdContract", "/api/v1/trace/contract", "trace_id_contract_visible", "trace_id_header_roundtrip", "trace_id_generated_visible", "trace_id_ui_visible")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing Trace ID Contract UI guard: $required"
  }
}
foreach ($required in @("CacheControlContract", "Cache Control Contract", "loadCacheControlContract", "/api/v1/cache/contract", "cache_control_contract_visible", "cache_control_headers_enforced", "cache_control_sensitive_payload_no_store", "cache_control_ui_visible")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing Cache Control Contract UI guard: $required"
  }
}
foreach ($required in @("RequestIdContract", "Request ID Contract", "loadRequestIdContract", "/api/v1/request/contract", "request_id_contract_visible", "request_id_header_roundtrip", "request_id_error_envelope_correlation", "request_id_audit_correlation", "request_id_audit_feed_visible", "Request ID:", "Trace ID:", "request_id_ui_visible")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing Request ID Contract UI guard: $required"
  }
}
foreach ($required in @("SystemFallbackContract", "loadSystemFallbackContract", "/api/v1/system/fallback/contract", "System Unavailable Fallback", "system_fallback_contract_visible", "system_unavailable_ui_state", "system_degraded_service_visible", "Retry Health")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing system unavailable fallback UI guard: $required"
  }
}
foreach ($required in @("AgentActivityContract", "AgentActivityEvent", "loadAgentActivityContract", "loadAgentActivityEvents", "/api/v1/agent-activity/contract", "/api/v1/agent-activity/recent", "Agent Activity", "agent_activity_contract_visible", "agent_activity_trace_link_template", "agent_activity_filtered_feed_visible", "langfuse_auth_proxy_required", "Trace Deep-Link", "activityFilterBar")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing agent activity trace UI guard: $required"
  }
}
foreach ($required in @("DevOps Workflow Dispatch", "loadWorkflowDispatch", "WorkflowDispatchPlan", "live_github_call")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing DevOps workflow dispatch UI guard: $required"
  }
}
foreach ($required in @("GitHub Branch/PR Contract", "loadGithubBranchPrContract", "GithubBranchPrContract", "/mcp/api/v1/github/branch-pr/contract", "github_branch_pr_plan", "github_branch_pr_policy")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing GitHub Branch/PR Contract UI guard: $required"
  }
}
foreach ($required in @("PostgreSQL Readonly Query Contract", "loadPostgresqlReadonlyContract", "PostgresqlReadonlyContract", "/mcp/api/v1/postgresql/readonly-query/contract", "postgresql_readonly_query_plan", "postgresql_write_policy")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing PostgreSQL Readonly Query Contract UI guard: $required"
  }
}
foreach ($required in @("Filesystem Workspace Scope Contract", "loadFilesystemWorkspaceContract", "FilesystemWorkspaceContract", "/mcp/api/v1/filesystem/workspace-scope/contract", "filesystem_workspace_access_plan", "filesystem_scope_policy")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing Filesystem Workspace Scope Contract UI guard: $required"
  }
}
foreach ($required in @("Playwright Browser Proof Contract", "loadPlaywrightBrowserProofContract", "PlaywrightBrowserProofContract", "/mcp/api/v1/playwright/browser-proof/contract", "playwright_browser_proof_plan", "playwright_browser_policy")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing Playwright Browser Proof Contract UI guard: $required"
  }
}
foreach ($required in @("E2B Sandbox Lifecycle Contract", "loadE2bSandboxLifecycleContract", "E2bSandboxLifecycleContract", "/mcp/api/v1/e2b/sandbox-lifecycle/contract", "e2b_sandbox_lifecycle_plan", "e2b_sandbox_policy")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing E2B Sandbox Lifecycle Contract UI guard: $required"
  }
}
foreach ($required in @("MCP Version Pinning Contract", "loadMcpVersionPinningContract", "McpVersionPinningContract", "/mcp/api/v1/version-pinning/contract", "mcp-version-pinning-v1", "mcp_version_pinning_contract_visible", "exact_version_required")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing MCP Version Pinning Contract UI guard: $required"
  }
}
foreach ($required in @("Memory Embedding Consistency Contract", "loadMemoryEmbeddingConsistencyContract", "MemoryEmbeddingConsistencyContract", "/api/v1/memory/embedding-consistency/contract", "memory-embedding-consistency-v1", "memory_embedding_consistency_contract_visible", "embedding_model_version", "reembedding_policy")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing Memory Embedding Consistency Contract UI guard: $required"
  }
}
foreach ($required in @("Memory Worker Health Contract", "loadMemoryWorkerHealthContract", "MemoryWorkerHealthContract", "/api/v1/memory/worker-health/contract", "memory-worker-health-contract-v1", "memory_worker_health_contract_visible", "python -m app.worker --healthcheck", "stale_heartbeat")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing Memory Worker Health Contract UI guard: $required"
  }
}
foreach ($required in @("Progress Integrity", "loadProjectProgressIntegrity", "ProjectProgressIntegrity", "/api/v1/project/progress/integrity", "project-progress-integrity-v1", "project_progress_integrity_runtime_proof")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing project progress integrity UI guard: $required"
  }
}
foreach ($required in @("ProjectProgressCompletion", "loadProjectProgressCompletion", "/api/v1/project/progress/completion", "project-progress-100-percent-contract-v1", "project_progress_100_percent_gate_contract", "100% Contract", "can_set_all_to_100")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing project progress completion UI guard: $required"
  }
}
foreach ($required in @("CloudProviderState", "CloudLayerReadinessState", "Cloud Inventory", "Cloud 7-Layer Readiness", "loadClouds", "loadCloudLayers", "/api/v1/clouds", "/api/v1/clouds/layers", "cloud-provider-inventory-v1", "cloud_provider_inventory_visible", "cloud-layer-readiness-v1", "cloud_layer_readiness_visible", "7 Layer Map", "No secret values")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing cloud provider inventory UI guard: $required"
  }
}
foreach ($required in @("CloudDeploymentPreflightContract", "CloudDeploymentPreflightGate", "loadCloudDeploymentPreflight", "Cloud Deployment Preflight", "/api/v1/clouds/deployment-preflight/contract", "cloud-deployment-preflight-v1", "cloud_deployment_preflight_visible", "publish_ghcr_images", "hosted_backend_origins", "Cloud deploy claim")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing cloud deployment preflight UI guard: $required"
  }
}
foreach ($required in @("External Gates", "external-gates-state-v1", "external_gates_state_visible", "/api/v1/external-gates", "deployment_preflight_endpoint", "blocked_release_gates", "preflight_gate_id", "required_env", "evidence_ref")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing external gates alignment UI guard: $required"
  }
}
foreach ($required in @("LlmRoutingPolicyContract", "Routing Policy", "Policy Decisions", "llm-routing-policy-v1", "llm_routing_policy_contract_visible", "llm_routing_policy_direct_provider_blocked", "llm_routing_policy_fallback_limit_blocked", "llm_routing_policy_retry_limit_blocked", "llm_routing_policy_sensitive_cache_blocked")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing LLM routing policy UI guard: $required"
  }
}
foreach ($required in @("RotationEvent", "Rotation Events", "provider_fallback_structured_event", "fallback_index", "routing_policy_decision", "cost_metadata", "live_provider_calls")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing provider fallback UI guard: $required"
  }
}
foreach ($required in @("Start Phase 2 Runtime", "loadPhase2RuntimeContract", "loadPhase2RuntimeRuns", "/api/v1/phase2/runtime/contract", "/api/v1/phase2/runtime/start", "/api/v1/phase2/runtime/runs", "/api/v1/orchestrator/dry-run/stream", "phase2-runtime-v1", "phase2_runtime_graph_started", "phase2_runtime_run_status_visible", "phase2-sse-event-contract-v1", "phase2_sse_event_contract_proof", "required_event_types", "SSE Event Contract", "Runtime Runs", "Latest Runtime Status", "Role Summaries", "External Gate Mirror", "external_gate_mirror_proof", "branch_protection_verify_contract", "branch_protection_claim_allowed", "/api/v1/external-gates/mirror", "external-gate-mirror-v1", "Layer Interface Contracts", "loadLayerInterfaceContract", "/api/v1/layer-interfaces/contract", "layer_interface_contracts_visible", "Task Assignment Queue Contract", "TaskAssignmentContract", "loadTaskAssignmentContract", "/api/v1/tasks/assignment-contract", "task_assignment_queue_contract_visible", "Agent LLM Streaming Contract", "AgentLlmStreamingContract", "loadAgentLlmStreamingContract", "/api/v1/agents/llm-streaming-contract", "agent_llm_streaming_contract_visible")) {
  if (-not $frontendSource.Contains($required)) {
    throw "Missing Phase 2 runtime UI guard: $required"
  }
}
foreach ($required in @("SSE_BUFFER_LIMIT = 50", "Last-Event-ID", "record_sse_event", "replay_sse_events")) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing SSE replay guard: $required"
  }
}
foreach ($required in @("PHASE2_RUNTIME_CONTRACT_VERSION", "phase2-runtime-v1", "phase2_runtime_graph_started", "phase2_runtime_run_status_visible", "/api/v1/phase2/runtime/contract", "/api/v1/phase2/runtime/start", "/api/v1/phase2/runtime/runs", "persist_phase2_runtime_audit", "phase2_runtime_run_from_audit_row", "phase2_runtime_runs", "audit_log_backed_phase2_runtime_runs", "deterministic_local_runtime", "mcp_timeout_contract", "MCP_TIMEOUT_PROBE_PREFIX", "LANGGRAPH_MCP_TIMEOUT_EVIDENCE_REF")) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing Phase 2 runtime API guard: $required"
  }
}
foreach ($required in @("AutopilotStreamRequest", "/api/stream", "autopilot-mode-stream-proof", "Agent gestartet", "LLM wird aufgerufen", "LLM gateway deterministic dry-run response", "deterministic_autopilot_stream")) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing Autopilot stream API guard: $required"
  }
}
foreach ($required in @("persist_langgraph_dry_run_audit", "langgraph_dry_run_stopped", "orchestrator_sse_key", "Last-Event-ID", "live_provider_calls", "checkpointing")) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing LangGraph hard-stop audit guard: $required"
  }
}
$orchestratorSource = Get-Content -Path "services\agent-api\app\orchestrator.py" -Raw
foreach ($required in @("hard_stop", "retry_counters", "policy_or_budget_guard_rejected", "forbidden_actions_detected", "error_handler", "MAX_GLOBAL_RETRY_CYCLES = 5", "force_langgraph_global_retry_limit", "global_retry_limit_reached", "langgraph_global_retry_limit_enforced", "RETRY_PROTECTED_NODES", "force_langgraph_node_failure:", "bounded_node_failure_state", "langgraph_node_failure_bounded", "_retry_limit_reached", "route_after_task_router", "route_after_result_aggregator", "phase2-sse-event-contract-v1", "phase2_sse_event_contract_proof", "PHASE2_SSE_REQUIRED_EVENTS", "force_phase2_sse_error_event", "MCP_TIMEOUT_PROBE_PREFIX", "force_mcp_tool_timeout:", "LANGGRAPH_MCP_TIMEOUT_EVIDENCE_REF", "langgraph_mcp_timeout_controlled", "mcp_tool_controlled_error", '"event": "heartbeat"', '"event": "agent_status"', '"event": "error"', '"event": "done"')) {
  if (-not $orchestratorSource.Contains($required)) {
    throw "Missing LangGraph hard-stop source guard: $required"
  }
}
foreach ($required in @("call_llm_gateway_for_task", "llm_gateway_url", "/api/v1/routing/resolve", "/api/v1/routing/policy/evaluate", "/v1/chat/completions", "parse_llm_gateway_sse_line", "streaming_used", "stream_done_seen", "openai_compatible_sse", "selected_model", "routing_policy_checked", "routing_policy_decision", "llm-routing-policy-v1", "llm_routing_policy_primary_allowed", "force_llm_routing_policy_deny_sensitive_cache", "llm_routing_policy_sensitive_cache_blocked", "llm_routing_policy_rejected", "policy_blocked", "route_after_agent_executor", "phase2_runtime_graph_started", "phase2_runtime_evidence_refs", "llm_gateway_dry_run", "llm_gateway_streaming_dry_run", "live_provider_calls", "live_provider_calls_proven_false", "llm_gateway_live_provider_non_claim_unproven", "llm_gateway_stream_done_missing", "search_memory", "store_memory", "MemoryWriteRequest", "TaskAssignment", "enqueue_task", "get_task", "redact_text", "priority_queue_key_for_value", "priority_level_for_value", "AGENT_TASK_COMPLETION_TIMEOUT_SECONDS", "enqueue_agent_pool_task", "task_assignment_completed", "task_assignment_incomplete", "task_assignment_partial_failure_detected", "mcp_gateway_url", "MCP_TOOL_TIMEOUT_MS", "call_mcp_gateway_for_task", "mcp_tool_calls", "mcp_tool_success", "mcp_tool_controlled_error", "simulate_timeout", "mcp_timeout_guard", "mcp_safe_envelope", "MEMORY_CONTEXT_BUDGET_PERCENT_MAX = 30", "load_memory_context", "memory_context_injected", "memory_context_budget", "memory_update_persisted", "build_memory_update_text")) {
  if (-not $orchestratorSource.Contains($required)) {
    throw "Missing LangGraph LLM gateway integration guard: $required"
  }
}
$workerSource = Get-Content -Path "services\agent-worker\app\worker.py" -Raw
foreach ($required in @("RedisConnectionError", "redis_reconnect", "redis_reconnected", "redis_client()", "TASK_PRIORITY_QUEUES", "TASK_QUEUE_KEYS_IN_PRIORITY_ORDER", "client.blpop(TASK_QUEUE_KEYS_IN_PRIORITY_ORDER", "priority_queue_key_for_task", "task_dequeued")) {
  if (-not $workerSource.Contains($required)) {
    throw "Missing Agent Worker Redis reconnect guard: $required"
  }
}
$securitySource = Get-Content -Path "services\agent-api\app\security.py" -Raw
foreach ($required in @("SECRET_PATTERNS", "redact_text", "redact_json", "***MASKED_SECRET***")) {
  if (-not $securitySource.Contains($required)) {
    throw "Missing runtime redaction guard: $required"
  }
}
$memorySource = Get-Content -Path "services\agent-api\app\memory.py" -Raw
if (-not $memorySource.Contains("redact_text(content_text)")) { throw "Memory writes must redact content_text before persistence" }
foreach ($required in @("DEFAULT_EMBEDDING_MODEL_VERSION", "DEFAULT_EMBEDDING_DIMENSIONS", "EMBEDDING_SEARCH_MODE", "current_embedding_model_version", "current_embedding_dimensions", "embedding_model_version")) {
  if (-not $memorySource.Contains($required)) {
    throw "Memory source missing embedding consistency guard: $required"
  }
}
$llmGatewaySource = Get-Content -Path "services\llm-gateway\app\main.py" -Raw
foreach ($required in @("LIVE_PROVIDER_CALLS = False", "/v1/chat/completions", "/v1/models", "/api/v1/routing/resolve", "/api/v1/providers/status", "/api/v1/streaming/contract", "/api/v1/routing/policy/contract", "/api/v1/routing/policy/evaluate", "provider_status_snapshot", "streaming_contract_snapshot", "ROUTING_POLICY_CONTRACT_VERSION", "llm-routing-policy-v1", "STREAMING_PROTOCOL", "text/event-stream", "data: [DONE]", "provider_for_model", "resolve_route", "evaluate_routing_policy", "deny_direct_provider", "deny_fallback_limit", "deny_retry_limit", "deny_sensitive_cache", "deny_budget_or_rate", "deterministic_dry_run", "audit_persisted")) {
  if (-not $llmGatewaySource.Contains($required)) {
    throw "Missing LLM gateway dry-run guard: $required"
  }
}
$modelSource = Get-Content -Path "services\agent-api\app\models.py" -Raw
foreach ($required in @("AgentProfile", "AGENT_PROFILES", "agent_profile_registry", "agent-profiles-v1", "max_execution_seconds=300", "max_execution_seconds=600", "max_execution_seconds=120", "graceful_degradation", "workflow_dispatch_production")) {
  if (-not $modelSource.Contains($required)) {
    throw "Missing Agent Profile runtime contract guard: $required"
  }
}
foreach ($required in @("provider-fallback-event-v1", "provider_fallback_structured_event", "cost_metadata", "routing_policy_decision", "live_provider_calls")) {
  if (-not $modelSource.Contains($required)) {
    throw "Missing provider fallback rotation policy guard: $required"
  }
}
foreach ($required in @("provider-fallback-event-v1", "provider_fallback_structured_event", "cost_metadata", "estimated_cost_cents", "fallback_index", "routing_policy_decision", "live_provider_calls", "/api/v1/rotation/events", "/internal/rotation/events")) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing provider fallback event API guard: $required"
  }
}
foreach ($required in @("PHASE2_SSE_EVENT_CONTRACT_VERSION", "PHASE2_SSE_EVENT_EVIDENCE_REF", "PHASE2_SSE_REQUIRED_EVENTS", "sse_event_contract", "POST /api/v1/orchestrator/dry-run/stream", "force_phase2_sse_error_event")) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing Phase 2 SSE event contract API guard: $required"
  }
}
foreach ($required in @("EXTERNAL_GATE_MIRROR_CONTRACT_VERSION", "external-gate-mirror-v1", "EXTERNAL_GATE_MIRROR_EVIDENCE_REF", "external_gate_mirror_proof", "BRANCH_PROTECTION_VERIFY_EVIDENCE_REF", "branch_protection_verify_contract", "/api/v1/external-gates/mirror", "hosted_staging_claim_allowed", "branch_protection_claim_allowed", "production_deploy_claim_allowed", "project_progress_manifest_proof", ".github/workflows/hosted-staging-proof.yml", ".github/workflows/branch-protection.yml", "scripts/apply_github_branch_protection.py --verify-only")) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing external gate mirror API guard: $required"
  }
}
foreach ($required in @("PROGRESS_INTEGRITY_CONTRACT_VERSION", "project-progress-integrity-v1", "PROGRESS_INTEGRITY_EVIDENCE_REF", "project_progress_integrity_runtime_proof", "/api/v1/project/progress/integrity", "computed_overall_percent", "manifest_overall_percent", "overall_percent_mismatch")) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing project progress integrity API guard: $required"
  }
}
foreach ($required in @("PROGRESS_COMPLETION_CONTRACT_VERSION", "project-progress-100-percent-contract-v1", "PROGRESS_COMPLETION_EVIDENCE_REF", "project_progress_100_percent_gate_contract", "/api/v1/project/progress/completion", "can_set_all_to_100", "blocked_external_gates", "missing_external_gate_blockers", "local_progress_gaps_require_verified_evidence_for_each_phase_and_layer")) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing project progress completion API guard: $required"
  }
}
if ($apiTaskPolicySource.Contains("blocked_unverified_progress_gaps")) {
  throw "Obsolete project progress completion status still present in agent API source: blocked_unverified_progress_gaps"
}
foreach ($required in @("CLOUD_RENDER_OFFLOAD_CONTRACT_VERSION", "cloud-render-offload-v1", "CLOUD_RENDER_OFFLOAD_EVIDENCE_REF", "cloud_render_offload_contract_visible", "/api/v1/clouds/render-offload/contract", "home_pc_protection", "localhost_heavy_render_allowed", "webgl_3d_rendering_requires_hosted_cloud_runtime")) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing cloud render offload API guard: $required"
  }
}
foreach ($required in @("CLOUD_DEPLOYMENT_PREFLIGHT_CONTRACT_VERSION", "cloud-deployment-preflight-v1", "CLOUD_DEPLOYMENT_PREFLIGHT_EVIDENCE_REF", "cloud_deployment_preflight_visible", "/api/v1/clouds/deployment-preflight/contract", "environment_configured", "verified", "manual_external_actions", "claim_policy", "publish_ghcr_images", "hosted_backend_origins", "cloud_deploy_claim_allowed", "production_deploy_claim_allowed", "owner_review_before_production", "canonical_secret_scan")) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing cloud deployment preflight API guard: $required"
  }
}
foreach ($required in @("EXTERNAL_GATES_CONTRACT_VERSION", "external-gates-state-v1", "EXTERNAL_GATES_EVIDENCE_REF", "external_gates_state_visible", "/api/v1/external-gates", "aligned_with_deployment_preflight", "deployment_preflight_endpoint", "blocked_release_gates", "preflight_gate_id", "ghcr_image_digest_proof", "vercel_backend_origins", "canonical_gitleaks_scan")) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing external gates alignment API guard: $required"
  }
}
foreach ($required in @("LAYER_INTERFACE_CONTRACT_VERSION", "layer-interface-contracts-v1", "LAYER_INTERFACE_EVIDENCE_REF", "layer_interface_contracts_visible", "/api/v1/layer-interfaces/contract", "seven_layer_boundary_interface_register", "L1-L2", "L2-L5", "L7-OBS", "request_schema", "response_schema")) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing layer interface contract API guard: $required"
  }
}
foreach ($required in @("TASK_ASSIGNMENT_CONTRACT_VERSION", "task-assignment-queue-contract-v1", "TASK_ASSIGNMENT_EVIDENCE_REF", "task_assignment_queue_contract_visible", "/api/v1/tasks/assignment-contract", "layer_2_to_3_task_assignment_queue_contract", "TASK_QUEUE_KEY", "TASK_PRIORITY_QUEUES", "priority_order", "priority_consumption", "queue_depth_by_priority", "TASK_STATUS_PREFIX", "TASK_TTL_SECONDS", "fail_closed_before_enqueue", "worker_stale_queued_finalized", "superbrain_task_queue_depth")) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing task assignment queue contract API guard: $required"
  }
}
foreach ($required in @("AGENT_LLM_STREAMING_CONTRACT_VERSION", "agent-llm-streaming-contract-v1", "AGENT_LLM_STREAMING_EVIDENCE_REF", "agent_llm_streaming_contract_visible", "/api/v1/agents/llm-streaming-contract", "layer_3_to_4_agent_llm_gateway_streaming_contract", "parse_llm_gateway_sse_line", "stream_done_seen", "openai_compatible_sse", "data: [DONE]", "No live provider stream")) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing agent LLM streaming contract API guard: $required"
  }
}
foreach ($required in @("MEMORY_EMBEDDING_CONSISTENCY_CONTRACT_VERSION", "memory-embedding-consistency-v1", "MEMORY_EMBEDDING_CONSISTENCY_EVIDENCE_REF", "memory_embedding_consistency_contract_visible", "/api/v1/memory/embedding-consistency/contract", "embedding_model_version", "vector(1536)", "reembedding_strategy_fail_closed", "No live embedding provider call")) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing memory embedding consistency contract API guard: $required"
  }
}
if (-not (Test-Path "docs\runtime-contracts\layer-interface-contracts.md")) {
  throw "Missing L-05 layer interface contract document"
}
$layerInterfaceDoc = Get-Content -Path "docs\runtime-contracts\layer-interface-contracts.md" -Raw
foreach ($required in @("L-05", "layer_interface_contracts_visible", "/api/v1/layer-interfaces/contract", "L1-L2", "L2-L5", "L7-OBS")) {
  if (-not $layerInterfaceDoc.Contains($required)) {
    throw "Layer interface contract document missing guard: $required"
  }
}
if (-not (Test-Path "docs\runtime-contracts\task-assignment-queue-contract.md")) {
  throw "Missing L-06 task assignment queue contract document"
}
$taskAssignmentDoc = Get-Content -Path "docs\runtime-contracts\task-assignment-queue-contract.md" -Raw
foreach ($required in @("L-06", "task_assignment_queue_contract_visible", "/api/v1/tasks/assignment-contract", "tasks:agent:queue", "tasks:agent:queue:high", "tasks:agent:queue:low", '`high` -> `mid` -> `low`', "task:status:{task_id}", "worker_stale_queued_finalized", "superbrain_task_queue_depth")) {
  if (-not $taskAssignmentDoc.Contains($required)) {
    throw "Task assignment queue contract document missing guard: $required"
  }
}
if (-not (Test-Path "docs\runtime-contracts\agent-llm-streaming-contract.md")) {
  throw "Missing L-07 agent LLM streaming contract document"
}
$agentLlmStreamingDoc = Get-Content -Path "docs\runtime-contracts\agent-llm-streaming-contract.md" -Raw
foreach ($required in @("L-07", "agent_llm_streaming_contract_visible", "/api/v1/agents/llm-streaming-contract", "openai_compatible_sse", "data: [DONE]", "stream_done_seen", "parse_llm_gateway_sse_line")) {
  if (-not $agentLlmStreamingDoc.Contains($required)) {
    throw "Agent LLM streaming contract document missing guard: $required"
  }
}
if (-not (Test-Path "docs\runtime-contracts\memory-embedding-consistency-contract.md")) {
  throw "Missing memory embedding consistency contract document"
}
$memoryEmbeddingConsistencyDoc = Get-Content -Path "docs\runtime-contracts\memory-embedding-consistency-contract.md" -Raw
foreach ($required in @("Audit L-09", "memory_embedding_consistency_contract_visible", "/api/v1/memory/embedding-consistency/contract", "memory-embedding-consistency-v1", "embedding_model_version", "vector(1536)", "lexical_fallback", "No live embedding provider call")) {
  if (-not $memoryEmbeddingConsistencyDoc.Contains($required)) {
    throw "Memory embedding consistency contract document missing guard: $required"
  }
}
foreach ($required in @('"agent_type": "devops"', '"primary": "deepseek-ai/DeepSeek-V4-Flash:fastest"', '"fallbacks": ["Qwen/Qwen3.6-35B-A3B:fastest", "google/gemma-4-31B-it:fastest"]')) {
  if (-not $llmGatewaySource.Contains($required)) {
    throw "Missing LLM gateway DevOps route guard: $required"
  }
}
$runtimeVerifier = Get-Content -Path "scripts\verify-phase1-runtime.ps1" -Raw
foreach ($required in @(
  "runtime-budget-warning-proof",
  "runtime-budget-hard-stop-proof",
  "budget hard-stop expected HTTP 402",
  "LLM budget hard limit reached",
  "budget_guard_rejected",
  "superbrain_budget_allow_new_calls{level=`"critical`"} 0"
)) {
  if (-not $runtimeVerifier.Contains($required)) {
    throw "Runtime verifier missing budget guard proof marker: $required"
  }
}
foreach ($required in @(
  "langgraph mcp timeout controlled proof",
  "force_mcp_tool_timeout:tester",
  "langgraph_mcp_timeout_controlled",
  "mcp_timeout_guard",
  "mcp_tool_controlled_error",
  "task session UUID fail-closed",
  "session_id must be a valid UUID",
  "mcp_tool_session_bound_audit",
  '"session_bound":true',
  '"partial_failure":true'
)) {
  if (-not $runtimeVerifier.Contains($required)) {
    throw "Runtime verifier missing LangGraph MCP timeout proof marker: $required"
  }
}
foreach ($required in @("external-gate-mirror-v1", "external_gate_mirror_proof", "/api/v1/external-gates/mirror", "hosted_staging_claim_allowed", "production_deploy_claim_allowed", "project_progress_manifest_proof")) {
  if (-not $runtimeVerifier.Contains($required)) {
    throw "Runtime verifier missing external gate mirror proof marker: $required"
  }
}
foreach ($required in @(
  "project-progress-integrity-v1",
  "project_progress_integrity_runtime_proof",
  "/api/v1/project/progress/integrity",
  '''"computed_overall_percent":{0}'' -f $expectedOverallPercent',
  '''"manifest_overall_percent":{0}'' -f $expectedOverallPercent'
)) {
  if (-not $runtimeVerifier.Contains($required)) {
    throw "Runtime verifier missing project progress integrity proof marker: $required"
  }
}
foreach ($required in @(
  "project-progress-100-percent-contract-v1",
  "project_progress_100_percent_gate_contract",
  "/api/v1/project/progress/completion",
  '"status":"blocked_external_gates"',
  '"can_set_all_to_100":false',
  '"missing_external_gates":[]',
  "local_progress_gaps_require_verified_evidence_for_each_phase_and_layer"
)) {
  if (-not $runtimeVerifier.Contains($required)) {
    throw "Runtime verifier missing project progress completion proof marker: $required"
  }
}
foreach ($required in @("cloud-render-offload-v1", "cloud_render_offload_contract_visible", "/api/v1/clouds/render-offload/contract", '"localhost_heavy_render_allowed":false', "cloud_render_offload_requires_STAGING_BASE_URL")) {
  if (-not $runtimeVerifier.Contains($required)) {
    throw "Runtime verifier missing cloud render offload proof marker: $required"
  }
}
foreach ($required in @(
  "cloud-deployment-preflight-v1",
  "cloud_deployment_preflight_visible",
  "/api/v1/clouds/deployment-preflight/contract",
  '"status":"verified"',
  '"cloud_deploy_claim_allowed":true',
  '"production_deploy_claim_allowed":true',
  '"missing_or_blocked_gates":[]',
  "publish_ghcr_images",
  "hosted_backend_origins",
  "BRANCH_PROTECTION_TOKEN",
  "canonical_secret_scan"
)) {
  if (-not $runtimeVerifier.Contains($required)) {
    throw "Runtime verifier missing cloud deployment preflight proof marker: $required"
  }
}
foreach ($required in @("memory-embedding-consistency-v1", "memory_embedding_consistency_contract_visible", "/api/v1/memory/embedding-consistency/contract", '"status":"verified"', "embedding_model_version", "vector(1536)", "lexical_fallback", "No live embedding provider call")) {
  if (-not $runtimeVerifier.Contains($required)) {
    throw "Runtime verifier missing memory embedding consistency proof marker: $required"
  }
}
foreach ($required in @("post-recreate steady-state proof", "agent-api health after checkpoint restart", "post-recreate health", "post-recreate project progress integrity", "post-recreate mcp version pinning", "post-recreate favicon")) {
  if (-not $runtimeVerifier.Contains($required)) {
    throw "Runtime verifier missing post-recreate steady-state proof marker: $required"
  }
}
foreach ($required in @("Wait-SseContains", 'after $attempts SSE attempts', 'Last-Event-ID: $lastEventId')) {
  if (-not $runtimeVerifier.Contains($required)) {
    throw "Runtime verifier missing retry-safe SSE proof marker: $required"
  }
}
$hostedVerifier = Get-Content -Path "scripts\verify-hosted-staging.ps1" -Raw
foreach ($required in @("Wait-SseContains", 'after $effectiveAttempts SSE attempts', '$headers["Last-Event-ID"] = $lastEventId')) {
  if (-not $hostedVerifier.Contains($required)) {
    throw "Hosted verifier missing retry-safe SSE proof marker: $required"
  }
}
foreach ($required in @(
  "project-progress-100-percent-contract-v1",
  "project_progress_100_percent_gate_contract",
  "/api/v1/project/progress/completion",
  '"status":"blocked_external_gates"',
  '"can_set_all_to_100":false',
  '"missing_external_gates":[]',
  "local_progress_gaps_require_verified_evidence_for_each_phase_and_layer"
)) {
  if (-not $hostedVerifier.Contains($required)) {
    throw "Hosted verifier missing project progress completion proof marker: $required"
  }
}
foreach ($required in @("memory-embedding-consistency-v1", "memory_embedding_consistency_contract_visible", "/api/v1/memory/embedding-consistency/contract", '"status":"verified"', "embedding_model_version", "vector(1536)", "lexical_fallback", "No live embedding provider call")) {
  if (-not $hostedVerifier.Contains($required)) {
    throw "Hosted verifier missing memory embedding consistency proof marker: $required"
  }
}
foreach ($required in @(
  "cloud-deployment-preflight-v1",
  "cloud_deployment_preflight_visible",
  "/api/v1/clouds/deployment-preflight/contract",
  '"status":"verified"',
  '"cloud_deploy_claim_allowed":true',
  '"production_deploy_claim_allowed":true',
  '"missing_or_blocked_gates":[]',
  "hosted_backend_origins",
  "BRANCH_PROTECTION_TOKEN",
  "owner_review_before_production"
)) {
  if (-not $hostedVerifier.Contains($required)) {
    throw "Hosted verifier missing cloud deployment preflight proof marker: $required"
  }
}
$mcpGatewaySource = Get-Content -Path "services\mcp-gateway\app\main.py" -Raw
$mcpRequirements = Get-Content -Path "services\mcp-gateway\requirements.txt" -Raw
foreach ($required in @("fastapi==0.115.8", "uvicorn[standard]==0.34.0", "pydantic==2.10.6")) {
  if (-not $mcpRequirements.Contains($required)) {
    throw "Missing exact MCP dependency pin: $required"
  }
}
foreach ($line in (Get-Content -Path "services\mcp-gateway\requirements.txt")) {
  if ($line.Trim() -and -not $line.Trim().Contains("==")) {
    throw "MCP dependency is not exact-pinned: $line"
  }
}
foreach ($required in @(
  "MCP_VERSION_PINNING_CONTRACT_VERSION",
  "mcp-version-pinning-v1",
  "MCP_VERSION_PINNING_EVIDENCE_REF",
  "mcp_version_pinning_contract_visible",
  "/api/v1/version-pinning/contract",
  "deterministic_local_mcp_version_pinning_contract",
  "exact_version_required",
  "fastapi==0.115.8",
  "uvicorn[standard]==0.34.0",
  "pydantic==2.10.6",
  "github-branch-pr-plan-v1",
  "postgresql-readonly-query-v1",
  "filesystem-workspace-scope-v1",
  "playwright-browser-proof-v1",
  "e2b-sandbox-lifecycle-v1",
  "No live MCP write"
)) {
  if (-not $mcpGatewaySource.Contains($required)) {
    throw "Missing MCP version pinning contract guard: $required"
  }
}
foreach ($required in @(
  "session_id",
  "trace_id",
  "post_audit_event",
  "/internal/audit/mcp-tool-events"
)) {
  if (-not $mcpGatewaySource.Contains($required)) {
    throw "Missing MCP session/trace audit binding guard: $required"
  }
}
foreach ($required in @(
  "McpToolAuditRequest",
  "session_bound",
  "mcp_tool_session_bound_audit",
  "INSERT INTO audit_log(event_type, user_id, session_id, details, severity)",
  '"trace_id"'
)) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing Agent API MCP audit session binding guard: $required"
  }
}
foreach ($required in @(
  '"session_id": state["session_id"]',
  'trace_id = f"langgraph-',
  '"trace_id": trace_id',
  "call_mcp_gateway_for_task"
)) {
  if (-not $orchestratorSource.Contains($required)) {
    throw "Missing Orchestrator MCP session/trace binding guard: $required"
  }
}
$mcpRuntimeContract = Get-Content -Path "docs\runtime-contracts\mcp-toolsets.md" -Raw
foreach ($required in @(
  "mcp_tool_session_bound_audit",
  "session_id",
  "trace_id",
  "audit_evidence_ref"
)) {
  if (-not $mcpRuntimeContract.Contains($required)) {
    throw "MCP runtime contract missing session audit marker: $required"
  }
}
foreach ($required in @(
  "github_branch_pr_plan",
  "github_branch_pr_contract",
  "/api/v1/github/branch-pr/contract",
  "github-branch-pr-plan-v1",
  "feature/agent-",
  "github_branch_policy_violation",
  "live_github_call",
  "No GitHub branch was created by this dry-run plan.",
  "No pull request was opened by this dry-run plan.",
  "merge_pull_request",
  "force_push"
)) {
  if (-not $mcpGatewaySource.Contains($required)) {
    throw "Missing MCP GitHub branch/PR dry-run contract guard: $required"
  }
}
foreach ($required in @(
  "postgresql_readonly_query_plan",
  "postgresql_readonly_query_contract",
  "/api/v1/postgresql/readonly-query/contract",
  "postgresql-readonly-query-v1",
  "query_readonly",
  "live_database_call",
  "postgresql_write_policy_violation",
  "postgresql_write_policy",
  "POSTGRESQL_FORBIDDEN_SQL",
  "SELECT or WITH ... SELECT only"
)) {
  if (-not $mcpGatewaySource.Contains($required)) {
    throw "Missing MCP PostgreSQL readonly dry-run contract guard: $required"
  }
}
foreach ($required in @(
  "filesystem_workspace_scope_plan",
  "filesystem_workspace_scope_contract",
  "/api/v1/filesystem/workspace-scope/contract",
  "filesystem-workspace-scope-v1",
  "plan_workspace_access",
  "live_filesystem_call",
  "filesystem_scope_policy_violation",
  "filesystem_workspace_access_plan",
  "filesystem_scope_policy",
  "FILESYSTEM_WORKSPACE_ROOT",
  "/tmp/agent-workspace",
  "path traversal is forbidden"
)) {
  if (-not $mcpGatewaySource.Contains($required)) {
    throw "Missing MCP Filesystem workspace-scope dry-run contract guard: $required"
  }
}
foreach ($required in @(
  "playwright_browser_proof_plan",
  "playwright_browser_proof_contract",
  "/api/v1/playwright/browser-proof/contract",
  "playwright-browser-proof-v1",
  "plan_browser_proof",
  "live_browser_call",
  "playwright_browser_policy_violation",
  "playwright_browser_proof_plan",
  "playwright_browser_policy",
  "file/data/javascript browser targets are forbidden",
  "browser-proof-localhost"
)) {
  if (-not $mcpGatewaySource.Contains($required)) {
    throw "Missing MCP Playwright browser-proof dry-run contract guard: $required"
  }
}
foreach ($required in @(
  "e2b_sandbox_lifecycle_plan",
  "e2b_sandbox_lifecycle_contract",
  "/api/v1/e2b/sandbox-lifecycle/contract",
  "e2b-sandbox-lifecycle-v1",
  "plan_sandbox_lifecycle",
  "live_e2b_call",
  "e2b_sandbox_policy_violation",
  "e2b_sandbox_lifecycle_plan",
  "e2b_sandbox_policy",
  "close_sandbox_finally=true is required",
  "E2B_MAX_SESSION_TIMEOUT_MS = 1_800_000"
)) {
  if (-not $mcpGatewaySource.Contains($required)) {
    throw "Missing MCP E2B sandbox-lifecycle dry-run contract guard: $required"
  }
}
if (-not (Test-Path "docs\runtime-contracts\mcp-version-pinning-contract.md")) {
  throw "Missing L-08 MCP version pinning contract document"
}
$mcpVersionPinningDoc = Get-Content -Path "docs\runtime-contracts\mcp-version-pinning-contract.md" -Raw
foreach ($required in @("L-08", "mcp_version_pinning_contract_visible", "/mcp/api/v1/version-pinning/contract", "mcp-version-pinning-v1", "fastapi==0.115.8", "uvicorn[standard]==0.34.0", "pydantic==2.10.6", "github-branch-pr-plan-v1", "No live MCP write")) {
  if (-not $mcpVersionPinningDoc.Contains($required)) {
    throw "MCP version pinning contract document missing guard: $required"
  }
}
if (-not (Test-Path "docs\runtime-contracts\project-progress-integrity-contract.md")) {
  throw "Missing L-09 project progress integrity contract document"
}
$progressIntegrityDoc = Get-Content -Path "docs\runtime-contracts\project-progress-integrity-contract.md" -Raw
foreach ($required in @("L-09", "project_progress_integrity_runtime_proof", "/api/v1/project/progress/integrity", "project-progress-integrity-v1", "computed_overall_percent", "manifest_overall_percent", "No live provider")) {
  if (-not $progressIntegrityDoc.Contains($required)) {
    throw "Project progress integrity contract document missing guard: $required"
  }
}
if (-not (Test-Path "docs\runtime-contracts\project-progress-completion-contract.md")) {
  throw "Missing project progress 100 percent completion contract document"
}
$progressCompletionDoc = Get-Content -Path "docs\runtime-contracts\project-progress-completion-contract.md" -Raw
foreach ($required in @("project_progress_100_percent_gate_contract", "/api/v1/project/progress/completion", "project-progress-100-percent-contract-v1", "can_set_all_to_100", "blocked_external_gates", "hosted_staging_proof_requires_STAGING_BASE_URL", "production_release_requires_hosted_staging_branch_protection_secret_scan_and_owner_review", "No production deployment")) {
  if (-not $progressCompletionDoc.Contains($required)) {
    throw "Project progress completion contract document missing guard: $required"
  }
}

Write-Host "[verify] branch protection script"
py -3 -m py_compile scripts\apply_github_branch_protection.py
Assert-LastExitCode "branch protection script"

Write-Host "[verify] branch protection dry run"
$branchProtectionDryRun = py -3 scripts\apply_github_branch_protection.py --dry-run --repo strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM --branch chore/repo-bootstrap
Assert-LastExitCode "branch protection dry run"
Assert-Contains "branch protection dry run evidence" $branchProtectionDryRun "branch_protection_verify_contract"
Assert-Contains "branch protection dry run verify command" $branchProtectionDryRun "--verify-only"
Assert-Contains "branch protection default branch" $branchProtectionDryRun "chore/repo-bootstrap"

Write-Host "[verify] branch protection self test"
py -3 scripts\apply_github_branch_protection.py --self-test | Out-Null
Assert-LastExitCode "branch protection self test"

Write-Host "[verify] fallback secret scan syntax"
py -3 -m py_compile scripts\secret_scan_fallback.py
Assert-LastExitCode "fallback secret scan syntax"

Write-Host "[verify] workflow artifacts"
$workflowArtifacts = Select-String -Path ".github\workflows\*.yml" -Pattern "\\n"
if ($workflowArtifacts) {
  $workflowArtifacts | ForEach-Object { Write-Error $_.Line }
  throw "Workflow artifact contains literal backslash-n"
}
$branchProtectionWorkflow = Get-Content -Path ".github\workflows\branch-protection.yml" -Raw
foreach ($required in @("Apply and verify default branch protection", "BRANCH_PROTECTION_TOKEN", "BRANCH_NAME", "python scripts/apply_github_branch_protection.py --branch")) {
  if (-not $branchProtectionWorkflow.Contains($required)) {
    throw "Branch protection workflow missing verify guard: $required"
  }
}
$prCheckWorkflow = Get-Content -Path ".github\workflows\pr-check.yml" -Raw
Assert-Contains "pr-check default branch" $prCheckWorkflow "chore/repo-bootstrap"
$mainDeployWorkflow = Get-Content -Path ".github\workflows\main-deploy.yml" -Raw
Assert-Contains "main-deploy default branch" $mainDeployWorkflow "chore/repo-bootstrap"
foreach ($required in @(
  'IMAGE_NAMESPACE: ghcr.io/${{ github.repository_owner }}/cloud-superbrain-developer-platform',
  'agent-api',
  'agent-worker',
  'memory-worker',
  'mcp-gateway',
  'llm-gateway',
  'frontend',
  '${{ env.IMAGE_NAMESPACE }}/${{ matrix.name }}:${{ github.sha }}',
  '${{ env.IMAGE_NAMESPACE }}/${{ matrix.name }}:${{ github.event.inputs.deploy_environment || ''staging'' }}'
)) {
  if (-not $mainDeployWorkflow.Contains($required)) {
    throw "main-deploy workflow missing GHCR cloud image guard: $required"
  }
}
if ($mainDeployWorkflow.Contains('ghcr.io/${{ github.repository }}/')) {
  throw "main-deploy workflow must not use github.repository for GHCR image paths because this repo name is not a stable lowercase image namespace"
}

Write-Host "[verify] external gate audit contract"
if (-not (Test-Path "scripts\verify-external-gates.ps1")) {
  throw "Missing external gate audit verifier"
}
if (-not (Test-Path "docs\runtime-contracts\external-gate-audit-contract.md")) {
  throw "Missing external gate audit contract document"
}
$externalGateAuditScript = Get-Content -Path "scripts\verify-external-gates.ps1" -Raw
foreach ($required in @("external-gate-audit-v1", "external_gate_audit_proof", "hosted_staging_claim_allowed", "frontend_preview_claim_allowed", "production_deploy_claim_allowed", "Assert-HostedBaseUrlSafe", "External gate hosted proof requires HTTPS", "hosted_cloud_deployment_preflight", "cloud_deployment_preflight_visible", "ghcr_image_digest_verify", "ghcr_image_digest_proof", "vercel_backend_origin_health_required", "hosted_agent_api_health", "cloud-provider-inventory-v1", "cloud_provider_inventory_visible", "cloud-layer-readiness-v1", "cloud_layer_readiness_visible", "github_branch_protection_verify", "canonical_gitleaks_scan", "hetzner_live_budget_check", "gitlab_identity_claim_allowed", "huggingface_identity_claim_allowed", "gitkraken_identity_claim_allowed", "GITLAB_TOKEN", "HF_TOKEN", "GITKRAKEN_API_TOKEN")) {
  if (-not $externalGateAuditScript.Contains($required)) {
    throw "External gate audit verifier missing guard: $required"
  }
}
$externalGateAuditDoc = Get-Content -Path "docs\runtime-contracts\external-gate-audit-contract.md" -Raw
foreach ($required in @("external-gate-audit-v1", "cloud-only-staging-proof-v1", "Frontend preview reachability is not hosted staging", "hosted_staging_claim_allowed", "production_deploy_claim_allowed", "No secret values", "Optional GitLab identity", "Optional Hugging Face identity", "Optional GitKraken identity", "never the token")) {
  if (-not $externalGateAuditDoc.Contains($required)) {
    throw "External gate audit contract document missing guard: $required"
  }
}
if (-not (Test-Path "scripts\verify-cloud-only-staging.ps1")) {
  throw "Missing cloud-only staging verifier"
}
$cloudOnlyVerifier = Get-Content -Path "scripts\verify-cloud-only-staging.ps1" -Raw
foreach ($required in @("cloud-only-staging-proof-v1", "localhost_allowed", "Cloud-only staging proof refuses localhost", "AGENT_API_BASE_URL", "cloud_agent_api_health", "cloud_provider_inventory", "cloud_render_offload_contract", "cloud_deployment_preflight_contract", "cloud-deployment-preflight-v1", "cloud_mcp_gateway_health", "cloud_llm_gateway_health")) {
  if (-not $cloudOnlyVerifier.Contains($required)) {
    throw "Cloud-only staging verifier missing guard: $required"
  }
}
if (-not (Test-Path "docs\runtime-contracts\cloud-provider-inventory-contract.md")) {
  throw "Missing cloud provider inventory contract document"
}
$cloudProviderInventoryDoc = Get-Content -Path "docs\runtime-contracts\cloud-provider-inventory-contract.md" -Raw
foreach ($required in @("cloud-provider-inventory-v1", "cloud_provider_inventory_visible", "cloud-layer-readiness-v1", "cloud_layer_readiness_visible", "GET /api/v1/clouds", "GET /api/v1/clouds/layers", "Seven-Layer Mapping", "Cloud Layer Readiness", "No secret values", "Vercel Live Read", "Hetzner Live Read", "Cloudflare Live Read", "GitHub Live Read", "GHCR Live Read", "Hugging Face Live Read", "GitLab Live Read", "GitKraken Live Read", "HETZNER_API_TOKEN", "CLOUDFLARE_API_TOKEN", "VERCEL_TOKEN", "GITHUB_TOKEN", "GHCR_TOKEN", "HF_TOKEN", "GITLAB_TOKEN", "GITKRAKEN_API_TOKEN", "vercel_frontend", "ghcr_registry", "gitkraken_identity")) {
  if (-not $cloudProviderInventoryDoc.Contains($required)) {
    throw "Cloud provider inventory contract document missing guard: $required"
  }
}
if (-not (Test-Path "docs\runtime-contracts\cloud-render-offload-contract.md")) {
  throw "Missing cloud render offload contract document"
}
$cloudRenderOffloadDoc = Get-Content -Path "docs\runtime-contracts\cloud-render-offload-contract.md" -Raw
foreach ($required in @("cloud-render-offload-v1", "cloud_render_offload_contract_visible", "GET /api/v1/clouds/render-offload/contract", "localhost_heavy_render_allowed", "STAGING_BASE_URL", "HETZNER_API_TOKEN", "webgl_3d_rendering", "control_plane")) {
  if (-not $cloudRenderOffloadDoc.Contains($required)) {
    throw "Cloud render offload contract document missing guard: $required"
  }
}
if (-not (Test-Path "docs\runtime-contracts\cloud-deployment-preflight-contract.md")) {
  throw "Missing cloud deployment preflight contract document"
}
$cloudDeploymentPreflightDoc = Get-Content -Path "docs\runtime-contracts\cloud-deployment-preflight-contract.md" -Raw
foreach ($required in @("cloud-deployment-preflight-v1", "cloud_deployment_preflight_visible", "GET /api/v1/clouds/deployment-preflight/contract", "publish_ghcr_images", "GITHUB_TOKEN", "GHCR_TOKEN", "HETZNER_API_TOKEN", "AGENT_API_BASE_URL", "BRANCH_PROTECTION_TOKEN", "cloud_deploy_claim_allowed", "production_deploy_claim_allowed", "manual_external_actions")) {
  if (-not $cloudDeploymentPreflightDoc.Contains($required)) {
    throw "Cloud deployment preflight contract document missing guard: $required"
  }
}
$externalGateAuditParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\verify-external-gates.ps1",
  [ref]$null,
  [ref]$externalGateAuditParseErrors
) | Out-Null
if ($externalGateAuditParseErrors) {
  $externalGateAuditParseErrors | ForEach-Object { Write-Error $_.Message }
  throw "External gate audit verifier has parse errors"
}

Write-Host "[verify] hosted staging verifier syntax"
if (-not (Test-Path "scripts\verify-hosted-staging.ps1")) {
  throw "Missing hosted staging verifier"
}
if (-not (Test-Path "scripts\verify-browser-contract.ps1")) {
  throw "Missing browser contract verifier"
}
if (-not (Test-Path "scripts\verify-autopilot-mode.ps1")) {
  throw "Missing autopilot mode verifier"
}
$browserContractParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\verify-browser-contract.ps1",
  [ref]$null,
  [ref]$browserContractParseErrors
) | Out-Null
if ($browserContractParseErrors -and $browserContractParseErrors.Count -gt 0) {
  $browserContractParseErrors | ForEach-Object { Write-Error $_.Message }
  throw "Browser contract verifier syntax failed"
}
$browserContractScript = Get-Content -Path "scripts\verify-browser-contract.ps1" -Raw
foreach ($required in @(
  "Start Phase 2 Runtime",
  "Phase 2 Runtime Contract",
  "/api/v1/phase2/runtime/start",
  "/api/v1/phase2/runtime/runs",
  "phase2_runtime_graph_started",
  "phase2_runtime_run_status_visible",
  "/api/v1/sessions/",
  "session-history-v1",
  "session_history_openable_project_state",
  "Memory Consolidation",
  "/api/v1/memory/consolidation/recent",
  "/api/v1/memory/worker-health/contract",
  "memory-worker-health-contract-v1",
  "memory_worker_health_contract_visible",
  "SeedMemoryConsolidation",
  "browser_contract_harness",
  "/api/v1/memory/embedding-consistency/contract",
  "memory-embedding-consistency-v1",
  "memory_embedding_consistency_contract_visible",
  "/api/v1/project/progress/completion",
  "project-progress-100-percent-contract-v1",
  "project_progress_100_percent_gate_contract",
  '"can_set_all_to_100":false'
)) {
  if (-not $browserContractScript.Contains($required)) {
    throw "Browser contract verifier missing required guard: $required"
  }
}

$memoryWorkerSource = Get-Content -Path "services\memory-worker\app\worker.py" -Raw
foreach ($required in @("MEMORY_WORKER_HEALTH_CONTRACT_VERSION", "memory-worker-health-contract-v1", "memory_worker_health_contract_visible", "--healthcheck", "max_heartbeat_age_seconds")) {
  if (-not $memoryWorkerSource.Contains($required)) {
    throw "Memory worker source missing health contract guard: $required"
  }
}

$agentDbSource = Get-Content -Path "services\agent-api\app\db.py" -Raw
foreach ($required in @("max_heartbeat_age_seconds", "stale_heartbeat", "heartbeat_stale_or_unhealthy", "heartbeat_status")) {
  if (-not $agentDbSource.Contains($required)) {
    throw "Agent API DB health source missing memory worker heartbeat guard: $required"
  }
}

$agentApiSource = Get-Content -Path "services\agent-api\app\main.py" -Raw
foreach ($required in @("memory_worker_health_contract_payload", "/api/v1/memory/worker-health/contract", "memory-worker-health-contract-v1", "memory_worker_health_contract_visible", "python -m app.worker --healthcheck", "docker_healthcheck_timeout_seconds")) {
  if (-not $agentApiSource.Contains($required)) {
    throw "Agent API source missing memory worker health contract guard: $required"
  }
}

foreach ($composePath in @("docker-compose.dev.yml", "docker-compose.cloud.yml")) {
  $composeSource = Get-Content -Path $composePath -Raw
  foreach ($required in @('"python", "-m", "app.worker", "--healthcheck"', "MEMORY_WORKER_MAX_BATCH_SECONDS", "MEMORY_WORKER_HEALTH_MAX_AGE_SECONDS", "timeout: 15s")) {
    if (-not $composeSource.Contains($required)) {
      throw "$composePath missing memory worker healthcheck guard: $required"
    }
  }
}

if (-not (Test-Path "docs\runtime-contracts\memory-worker-health-contract.md")) {
  throw "Missing memory worker health contract document"
}
$memoryWorkerHealthDoc = Get-Content -Path "docs\runtime-contracts\memory-worker-health-contract.md" -Raw
foreach ($required in @("memory-worker-health-contract-v1", "memory_worker_health_contract_visible", "GET /api/v1/memory/worker-health/contract", "python -m app.worker --healthcheck", "No live embedding provider call")) {
  if (-not $memoryWorkerHealthDoc.Contains($required)) {
    throw "Memory worker health contract document missing guard: $required"
  }
}
$autopilotParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\verify-autopilot-mode.ps1",
  [ref]$null,
  [ref]$autopilotParseErrors
) | Out-Null
if ($autopilotParseErrors -and $autopilotParseErrors.Count -gt 0) {
  $autopilotParseErrors | ForEach-Object { Write-Error $_.Message }
  throw "Autopilot mode verifier syntax failed"
}
$autopilotScript = Get-Content -Path "scripts\verify-autopilot-mode.ps1" -Raw
foreach ($required in @(
  '$StreamUrl = "$BaseUrl/api/stream"',
  "autopilot-mode-stream-proof",
  "live_provider_calls=false",
  "LLM gateway deterministic dry-run response",
  "Evidence-based only",
  '$progress.overall_percent -eq $expectedOverallPercent',
  '$phase2.percent -eq $expectedPhase2Percent',
  '$phase4.percent -eq $expectedPhase4Percent',
  "project_progress_integrity_runtime_proof",
  '$frontend.percent -eq $expectedFrontendPercent',
  '$agentPool.percent -eq $expectedAgentPoolPercent',
  '$progressIntegrity.computed_overall_percent -eq $expectedOverallPercent',
  '$progressIntegrity.manifest_overall_percent -eq $expectedOverallPercent'
)) {
  if (-not $autopilotScript.Contains($required)) {
    throw "Autopilot mode verifier missing required guard: $required"
  }
}

if (-not (Test-Path "docs\runbooks\hetzner-live-budget-proof-2026-04-29.md")) {
  throw "Missing Hetzner live budget proof document"
}
$hetznerBudgetProof = Get-Content -Path "docs\runbooks\hetzner-live-budget-proof-2026-04-29.md" -Raw
foreach ($required in @("EUR 19.03", "EUR 16.00", "EUR 20.00", "cax31", "under hard budget", "above warning threshold", "token is not persisted")) {
  if (-not $hetznerBudgetProof.Contains($required)) {
    throw "Hetzner live budget proof document missing guard: $required"
  }
}
$backupParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\backup-postgres-phase1.ps1",
  [ref]$null,
  [ref]$backupParseErrors
) | Out-Null
if ($backupParseErrors -and $backupParseErrors.Count -gt 0) {
  $backupParseErrors | ForEach-Object { Write-Error $_.Message }
  throw "PostgreSQL backup proof script syntax failed"
}
$backupScript = Get-Content -Path "scripts\backup-postgres-phase1.ps1" -Raw
foreach ($required in @("pg_dump", "--schema-only", "CREATE TABLE public.memory_entries", "checkpoint_tables", "no_secret_material")) {
  if (-not $backupScript.Contains($required)) {
    throw "PostgreSQL backup proof script missing required guard: $required"
  }
}
if (-not ((Get-Content -Path ".gitignore" -Raw).Contains(".phase1-artifacts/"))) {
  throw "Local phase1 backup artifacts must be gitignored"
}
$restoreParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\restore-postgres-phase1-proof.ps1",
  [ref]$null,
  [ref]$restoreParseErrors
) | Out-Null
if ($restoreParseErrors -and $restoreParseErrors.Count -gt 0) {
  $restoreParseErrors | ForEach-Object { Write-Error $_.Message }
  throw "PostgreSQL restore proof script syntax failed"
}
$restoreScript = Get-Content -Path "scripts\restore-postgres-phase1-proof.ps1" -Raw
foreach ($required in @("CREATE DATABASE", "DROP DATABASE IF EXISTS", "schema-only backup", "no_production_database_mutation", "restored_checkpoint_tables")) {
  if (-not $restoreScript.Contains($required)) {
    throw "PostgreSQL restore proof script missing required guard: $required"
  }
}
$redisParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\verify-redis-persistence-phase1.ps1",
  [ref]$null,
  [ref]$redisParseErrors
) | Out-Null
if ($redisParseErrors -and $redisParseErrors.Count -gt 0) {
  $redisParseErrors | ForEach-Object { Write-Error $_.Message }
  throw "Redis persistence proof script syntax failed"
}
$redisScript = Get-Content -Path "scripts\verify-redis-persistence-phase1.ps1" -Raw
foreach ($required in @("appendonly", "SAVE", "--force-recreate", "restored_value_matches", "no_secret_material")) {
  if (-not $redisScript.Contains($required)) {
    throw "Redis persistence proof script missing required guard: $required"
  }
}
$resourceParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\measure-compose-resources.ps1",
  [ref]$null,
  [ref]$resourceParseErrors
) | Out-Null
if ($resourceParseErrors -and $resourceParseErrors.Count -gt 0) {
  $resourceParseErrors | ForEach-Object { Write-Error $_.Message }
  throw "Resource measurement script syntax failed"
}

Write-Host "[verify] git diff whitespace"
git diff --check
Assert-LastExitCode "git diff whitespace"

$repoLocalGitleaks = Join-Path ".tools\gitleaks" "gitleaks.exe"
$gitleaksCommand = Get-Command gitleaks -ErrorAction SilentlyContinue
if ($gitleaksCommand -or (Test-Path $repoLocalGitleaks)) {
  Write-Host "[verify] gitleaks scan"
  $gitleaksExecutable = if ($gitleaksCommand) { "gitleaks" } else { $repoLocalGitleaks }
  & $gitleaksExecutable detect --no-git --source . --config .gitleaks.toml --redact
  Assert-LastExitCode "gitleaks scan"
} else {
  Write-Host "[verify] fallback secret scan"
  py -3 scripts\secret_scan_fallback.py
  Assert-LastExitCode "fallback secret scan"
}

Write-Host "[verify] phase1 checks completed"

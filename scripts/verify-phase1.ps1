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

Write-Host "[verify] supply-chain pins"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-supply-chain-pins.ps1
Assert-LastExitCode "supply-chain pins"

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
foreach ($forbiddenCodexTerm in @("MVP-Embeddings:  Supabase Free Tier", "supabase-keepalive", "CPX31 (~10", "Embeddingsâ†’Supabase")) {
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

Write-Host "[verify] Grafana Cloud real-read regression tests"
py -3 scripts\verify-grafana-cloud-live-read.py
Assert-LastExitCode "Grafana Cloud real-read regression tests"

Write-Host "[verify] llm responses adapter contract guard"
if (-not (Test-Path "scripts\verify-llm-responses-contract.ps1")) {
  throw "Missing LLM responses adapter verifier"
}
$llmResponsesParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\verify-llm-responses-contract.ps1",
  [ref]$null,
  [ref]$llmResponsesParseErrors
) | Out-Null
if ($llmResponsesParseErrors -and $llmResponsesParseErrors.Count -gt 0) {
  $llmResponsesParseErrors | ForEach-Object { Write-Error $_.Message }
  throw "LLM responses adapter verifier has parse errors"
}
$llmResponsesVerifier = Get-Content -Path "scripts\verify-llm-responses-contract.ps1" -Raw
$llmGatewaySource = Get-Content -Path "services\llm-gateway\app\main.py" -Raw
$agentApiSourceForLlmResponses = Get-Content -Path "services\agent-api\app\main.py" -Raw
foreach ($required in @(
  "llm-responses-adapter-contract-v1",
  "llm_responses_adapter_contract_visible",
  "POST /llm/v1/responses",
  "GET /llm/api/v1/responses/contract",
  "audit_persisted",
  "stream true rejected",
  "metadata object required",
  "No direct provider URL is called by the Agent API"
)) {
  if (-not $llmResponsesVerifier.Contains($required)) {
    throw "LLM responses verifier missing required guard: $required"
  }
}
foreach ($required in @(
  "LLM_RESPONSES_ADAPTER_CONTRACT_VERSION",
  "responses_adapter_contract_snapshot",
  '@app.get("/api/v1/responses/contract")',
  '@app.post("/v1/responses")',
  "stream=true is not supported on this /v1/responses proxy",
  "metadata must be an object",
  '"secret_output": False'
)) {
  if (-not $llmGatewaySource.Contains($required)) {
    throw "LLM gateway source missing responses adapter guard: $required"
  }
}
foreach ($required in @(
  "LLM_RESPONSES_ADAPTER_CONTRACT_VERSION",
  "GET /llm/api/v1/responses/contract",
  "POST /llm/v1/responses",
  "required_llm_response_fields",
  "No direct provider URL is called by the Agent API"
)) {
  if (-not $agentApiSourceForLlmResponses.Contains($required)) {
    throw "Agent API source missing responses adapter guard: $required"
  }
}

Write-Host "[verify] live agent steering contract guard"
if (-not (Test-Path "scripts\verify-live-agent-steering-contract.ps1")) {
  throw "Missing live agent steering verifier"
}
$liveAgentSteeringParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\verify-live-agent-steering-contract.ps1",
  [ref]$null,
  [ref]$liveAgentSteeringParseErrors
) | Out-Null
if ($liveAgentSteeringParseErrors -and $liveAgentSteeringParseErrors.Count -gt 0) {
  $liveAgentSteeringParseErrors | ForEach-Object { Write-Error $_.Message }
  throw "Live agent steering verifier has parse errors"
}
$liveAgentSteeringVerifier = Get-Content -Path "scripts\verify-live-agent-steering-contract.ps1" -Raw
$agentApiSourceForLiveAgentSteering = Get-Content -Path "services\agent-api\app\main.py" -Raw
foreach ($required in @(
  "live-agent-steering-v1",
  "live_agent_steering_contract_visible",
  "POST /llm/v1/responses",
  "GET /llm/api/v1/responses/contract",
  "llm-responses-adapter-contract-v1",
  "live_provider_calls",
  "model_downloads",
  "audit_persisted",
  "secret_output",
  "unknown agent rejected",
  "empty message rejected",
  "compatibility route"
)) {
  if (-not $liveAgentSteeringVerifier.Contains($required)) {
    throw "Live agent steering verifier missing required guard: $required"
  }
}
foreach ($required in @(
  "LIVE_AGENT_STEERING_CONTRACT_VERSION",
  '@app.get("/api/v1/live-agents/contract")',
  '@app.post("/api/v1/live-agents/steer")',
  '@app.post("/api/steer-agent")',
  '@app.post("/api/v1/live-agents/{agent_id}/reset")',
  "call_llm_gateway_responses",
  "llm_gateway_contract_version",
  "llm_gateway_evidence_ref",
  "live_provider_calls",
  "model_downloads",
  "audit_persisted",
  "secret_output"
)) {
  if (-not $agentApiSourceForLiveAgentSteering.Contains($required)) {
    throw "Agent API source missing live agent steering guard: $required"
  }
}

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
if (-not (Test-Path "scripts\verify-frontend-cloud-rewrites.ps1")) {
  throw "Missing frontend cloud rewrite verifier"
}
$frontendNextConfig = Get-Content -Path "apps\frontend\next.config.mjs" -Raw
foreach ($required in @("resolveBaseUrl", "AGENT_API_BASE_URL", "MCP_GATEWAY_BASE_URL", "LLM_GATEWAY_BASE_URL", "STAGING_BASE_URL", "isSafeHttpsOrigin", "hostedRewriteFallbackFor")) {
  if (-not $frontendNextConfig.Contains($required)) {
    throw "Frontend Next.js config missing hosted origin rewrite guard: $required"
  }
}
foreach ($forbiddenActiveFlyMarker in @("convertFlyAppNameToBaseUrl", "FLY_APP_AGENT_API", "FLY_APP_MCP_GATEWAY", "FLY_APP_LLM_GATEWAY")) {
  if ($frontendNextConfig.Contains($forbiddenActiveFlyMarker)) {
    throw "Frontend Next.js config must not retain active Fly fallback: $forbiddenActiveFlyMarker"
  }
}

Write-Host "[verify] frontend cloud rewrites"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-frontend-cloud-rewrites.ps1
Assert-LastExitCode "frontend cloud rewrites"

Write-Host "[verify] frontend provider boundary"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-frontend-provider-boundary.ps1
Assert-LastExitCode "frontend provider boundary"

Write-Host "[verify] workspace pages layer map"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-workspace-pages-layer-map.ps1
Assert-LastExitCode "workspace pages layer map"

Write-Host "[verify] workspace vertical stack guard"
if (-not (Test-Path "scripts\verify-workspace-vertical-stack.ps1")) {
  throw "Missing workspace vertical stack verifier"
}
if (-not (Test-Path "apps\frontend\lib\workspaceVerticalStack.ts")) {
  throw "Missing workspace vertical stack contract source"
}
if (-not (Test-Path "apps\frontend\app\api\v1\workspace\vertical-stack\route.ts")) {
  throw "Missing workspace vertical stack frontend route"
}
$workspaceVerticalStackParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\verify-workspace-vertical-stack.ps1",
  [ref]$null,
  [ref]$workspaceVerticalStackParseErrors
) | Out-Null
if ($workspaceVerticalStackParseErrors -and $workspaceVerticalStackParseErrors.Count -gt 0) {
  $workspaceVerticalStackParseErrors | ForEach-Object { Write-Error $_.Message }
  throw "Workspace vertical stack verifier has parse errors"
}
$workspaceVerticalSource = Get-Content -Path "apps\frontend\lib\workspaceVerticalStack.ts" -Raw
$workspaceVerticalRoute = Get-Content -Path "apps\frontend\app\api\v1\workspace\vertical-stack\route.ts" -Raw
$workspaceVerticalVerifier = Get-Content -Path "scripts\verify-workspace-vertical-stack.ps1" -Raw
$workspaceVerticalAgentApi = Get-Content -Path "services\agent-api\app\main.py" -Raw
foreach ($required in @(
  "workspace-vertical-stack-v1",
  "workspace_vertical_stack_visible",
  "expected_page_count: 22",
  "layers_required: 7",
  "ui",
  "api",
  "data",
  "verification",
  "deploy",
  "safety",
  "blocked_external_gates",
  "productionDeployClaimAllowed: false",
  "Localhost evidence remains DEV-ONLY"
)) {
  if (-not $workspaceVerticalSource.Contains($required)) {
    throw "Workspace vertical stack source missing guard: $required"
  }
}
foreach ($required in @("workspaceVerticalStackContract", "/api/v1/workspace/vertical-stack")) {
  if (-not (($workspaceVerticalRoute.Contains($required)) -or ($workspaceVerticalSource.Contains($required)))) {
    throw "Workspace vertical stack route/source missing guard: $required"
  }
}
foreach ($required in @(
  "workspace-vertical-stack-v1",
  "workspace_vertical_stack_visible",
  "page_count) 22",
  "layers_required) 7",
  "directProviderCalls",
  "hostedProofRequiredForRelease",
  "cloudflare-stateful-runtime",
  "cloudflare-llm-gateway",
  "vercel-hosted-backend-origin-contracts",
  "retired active backend target absent",
  "ghcr",
  "Hetzner",
  "GitKraken",
  "Oracle"
)) {
  if (-not $workspaceVerticalVerifier.Contains($required)) {
    throw "Workspace vertical stack verifier missing guard: $required"
  }
}
foreach ($required in @(
  "WORKSPACE_VERTICAL_STACK_CONTRACT_VERSION",
  "WORKSPACE_VERTICAL_STACK_EVIDENCE_REF",
  "workspace_vertical_stack_payload",
  '@app.get("/api/v1/workspace/vertical-stack")',
  "GET /api/v1/workspace/vertical-stack",
  "/api/v1/workspace/vertical-stack"
)) {
  if (-not $workspaceVerticalAgentApi.Contains($required)) {
    throw "Agent API missing workspace vertical stack guard: $required"
  }
}

Write-Host "[verify] workspace data source integrity guard"
if (-not (Test-Path "scripts\verify-workspace-data-sources.ps1")) {
  throw "Missing workspace data source verifier"
}
$workspaceDataSourceParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\verify-workspace-data-sources.ps1",
  [ref]$null,
  [ref]$workspaceDataSourceParseErrors
) | Out-Null
if ($workspaceDataSourceParseErrors -and $workspaceDataSourceParseErrors.Count -gt 0) {
  $workspaceDataSourceParseErrors | ForEach-Object { Write-Error $_.Message }
  throw "Workspace data source verifier has parse errors"
}
$workspaceDataSourceVerifier = Get-Content -Path "scripts\verify-workspace-data-sources.ps1" -Raw
$workspaceDataSourceWiring = Get-Content -Path "apps\frontend\lib\workspaceWiring.ts" -Raw
$workspaceDataSourceAgentApi = Get-Content -Path "services\agent-api\app\main.py" -Raw
foreach ($required in @(
  "local-files-readonly-contract-v1",
  "/api/v1/models/capabilities",
  "/api/v1/files/local/contract",
  "api_refs=$",
  "host_filesystem_mounted",
  "live_filesystem_reads",
  "Test-AgentApiRoute",
  "Workspace data source proof refuses localhost unless -AllowLocalhost"
)) {
  if (-not $workspaceDataSourceVerifier.Contains($required)) {
    throw "Workspace data source verifier missing guard: $required"
  }
}
foreach ($required in @(
  "/api/v1/models/capabilities",
  "/api/v1/files/local/contract"
)) {
  if (-not $workspaceDataSourceWiring.Contains($required)) {
    throw "Workspace wiring missing data source guard: $required"
  }
}
if ($workspaceDataSourceWiring.Contains("/api/v1/model-capabilities")) {
  throw "Workspace wiring contains stale singular model-capabilities data source"
}
foreach ($required in @(
  "local-files-readonly-contract-v1",
  "local_files_readonly_contract_payload",
  '@app.get("/api/v1/files/local/contract")',
  '@app.get("/api/v1/models/capabilities")',
  "host_filesystem_mounted",
  "live_filesystem_reads",
  "GET /mcp/api/v1/filesystem/workspace-scope/contract"
)) {
  if (-not $workspaceDataSourceAgentApi.Contains($required)) {
    throw "Agent API missing workspace data source guard: $required"
  }
}
if ($workspaceDataSourceAgentApi.Contains("/api/v1/model-capabilities")) {
  throw "Agent API contains stale singular model-capabilities data source"
}

Write-Host "[verify] platform UI status boundary guard"
if (-not (Test-Path "scripts\verify-platform-ui-status-boundary.ps1")) {
  throw "Missing platform UI status boundary verifier"
}
$platformUiBoundaryParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\verify-platform-ui-status-boundary.ps1",
  [ref]$null,
  [ref]$platformUiBoundaryParseErrors
) | Out-Null
if ($platformUiBoundaryParseErrors -and $platformUiBoundaryParseErrors.Count -gt 0) {
  $platformUiBoundaryParseErrors | ForEach-Object { Write-Error $_.Message }
  throw "Platform UI status boundary verifier has parse errors"
}
$platformUiBoundaryVerifier = Get-Content -Path "scripts\verify-platform-ui-status-boundary.ps1" -Raw
foreach ($required in @(
  "fetchProgress",
  "fetchMasterPlan",
  "fetchCompletionGate",
  "MANIFEST",
  "/api/v1/project/progress",
  "Project Progress",
  "Projektstand",
  "Completion-Gate",
  "Workspace-Surfaces",
  "Gate-Matrix",
  "Recovery-Historie",
  "product_surfaces=$",
  "Platform UI status boundary proof refuses localhost unless -AllowLocalhost"
)) {
  if (-not $platformUiBoundaryVerifier.Contains($required)) {
    throw "Platform UI status boundary verifier missing guard: $required"
  }
}
foreach ($productSurface in @(
  "apps\frontend\app\home\page.tsx",
  "apps\frontend\app\workbench\page.tsx",
  "apps\frontend\app\games\page.tsx",
  "apps\frontend\app\apps\page.tsx",
  "apps\frontend\app\media\page.tsx",
  "apps\frontend\app\docs-output\page.tsx",
  "apps\frontend\components\shell\AppShell.tsx"
)) {
  $productSource = Get-Content -Path $productSurface -Raw
  foreach ($forbidden in @(
    "fetchProgress",
    "fetchMasterPlan",
    "fetchCompletionGate",
    "MANIFEST",
    "/api/v1/project/progress",
    "overall_percent",
    "Project Progress",
    "Projektstand",
    "Completion-Gate",
    "Workspace-Surfaces",
    "Gate-Matrix",
    "Recovery-Historie",
    "go-live-readiness"
  )) {
    if ($productSource.Contains($forbidden)) {
      throw "Product platform surface $productSurface contains project-status boundary leak: $forbidden"
    }
  }
}

Write-Host "[verify] organism topology integrity guard"
if (-not (Test-Path "scripts\verify-organism-topology.ps1")) {
  throw "Missing organism topology verifier"
}
$organismTopologyParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\verify-organism-topology.ps1",
  [ref]$null,
  [ref]$organismTopologyParseErrors
) | Out-Null
if ($organismTopologyParseErrors -and $organismTopologyParseErrors.Count -gt 0) {
  $organismTopologyParseErrors | ForEach-Object { Write-Error $_.Message }
  throw "Organism topology verifier has parse errors"
}
$organismTopologyVerifier = Get-Content -Path "scripts\verify-organism-topology.ps1" -Raw
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-organism-topology.ps1 -StaticOnly
Assert-LastExitCode "organism topology static surface"
$organismTopologyFrontend = Get-Content -Path "apps\frontend\app\api\v1\organism\topology\route.ts" -Raw
$organismTopologyContract = Get-Content -Path "apps\frontend\app\api\v1\organism\contract\route.ts" -Raw
$organismPlatformSource = Get-Content -Path "apps\frontend\lib\platform.ts" -Raw
$organismAgentApiSource = Get-Content -Path "services\agent-api\app\main.py" -Raw
foreach ($required in @(
  "organism-topology-v1",
  "organism_topology_visible",
  "workspace-surface-wiring-v1",
  "workspace-vertical-stack-v1",
  "StaticOnly",
  "OrganismTopologyMap.tsx",
  "organism map page",
  "OrganismView",
  "isTopologyPayload",
  "organism-topology-map",
  "organism-topology-kind-filter",
  "organism-topology-adjacency",
  "node kind count",
  "edge from exists",
  "edge to exists",
  "agent_to_tool",
  "agent_to_model",
  "page_to_data_source",
  "page_to_verifier",
  "layer_to_provider",
  "gate_to_security_region",
  "Localhost topology proof requires -AllowLocalhost and remains DEV-ONLY"
)) {
  if (-not $organismTopologyVerifier.Contains($required)) {
    throw "Organism topology verifier missing guard: $required"
  }
}
foreach ($required in @(
  "organism-topology-v1",
  "organism_topology_visible",
  "workspace_data_source",
  "workspace_verifier",
  "page_to_data_source",
  "page_to_verifier",
  "layer_to_provider",
  "secret_output: false",
  "writes: false"
)) {
  if (-not $organismTopologyFrontend.Contains($required)) {
    throw "Frontend organism topology source missing guard: $required"
  }
}
foreach ($required in @(
  "workspace_page_count",
  "Topology edges must reference existing layer, region, hub, agent, tool, model, skill, provider, and gate nodes.",
  "/api/v1/workspace/vertical-stack"
)) {
  if (-not $organismTopologyContract.Contains($required)) {
    throw "Frontend organism contract source missing guard: $required"
  }
}
foreach ($required in @(
  'overall: 86',
  '{ name: "Frontend", layer: 1, pct: 100 }',
  '{ name: "Orchestrator", layer: 2, pct: 100 }',
  '{ name: "Memory", layer: 6, pct: 100 }',
  '{ id: "P2", pct: 100 }',
  '{ id: "P3", pct: 44 }',
  '{ id: "P4", pct: 100 }',
  '{ id: "P5", pct: 68 }',
  '{ id: "P6", pct: 90 }',
  "AGENTS",
  "MCP_TOOLS",
  "MODELS",
  "SKILLS",
  "CLOSED_GATES"
)) {
  if (-not $organismPlatformSource.Contains($required)) {
    throw "Platform source missing manifest/topology guard: $required"
  }
}
foreach ($required in @(
  "def organism_topology_payload",
  "organism-topology-v1",
  "organism_topology_visible",
  '"kind": "agent_to_tool"',
  '"kind": "page_to_verifier"',
  '"kind": "layer_to_provider"',
  '@app.get("/api/v1/organism/topology")'
)) {
  if (-not $organismAgentApiSource.Contains($required)) {
    throw "Agent API organism topology source missing guard: $required"
  }
}

Write-Host "[verify] technology runtime view"
if (-not (Test-Path "scripts\verify-technology-runtime-view.ps1")) {
  throw "Missing technology runtime view verifier"
}
$technologyRuntimeParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\verify-technology-runtime-view.ps1",
  [ref]$null,
  [ref]$technologyRuntimeParseErrors
) | Out-Null
if ($technologyRuntimeParseErrors -and $technologyRuntimeParseErrors.Count -gt 0) {
  $technologyRuntimeParseErrors | ForEach-Object { Write-Error $_.Message }
  throw "Technology runtime view verifier has parse errors"
}
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-technology-runtime-view.ps1 -StaticOnly
Assert-LastExitCode "technology runtime view static surface"
$technologyRuntimeVerifier = Get-Content -Path "scripts\verify-technology-runtime-view.ps1" -Raw
foreach ($required in @(
  "technology runtime contracts expose working filters layer selection and refresh",
  "cloud-provider-inventory-v1",
  "cloud_provider_inventory_visible",
  "cloud-layer-readiness-v1",
  "cloud_layer_readiness_visible",
  "cloud-deployment-preflight-v1",
  "cloud_deployment_preflight_visible",
  "agent-api-boundary",
  "project-state-projection",
  "frontend-projection",
  "technology-runtime-view",
  "technology-runtime-refresh",
  "technology-runtime-retry",
  "technology-provider-filter",
  "technology-layer-select",
  "historical_only",
  "cloudflare_edge",
  "Localhost technology runtime proof requires -AllowLocalhost and remains DEV-ONLY"
)) {
  if (-not $technologyRuntimeVerifier.Contains($required)) {
    throw "Technology runtime view verifier missing guard: $required"
  }
}

Write-Host "[verify] reference design contract"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-reference-design-contract.ps1
Assert-LastExitCode "reference design contract"
if (-not (Test-Path "scripts\verify-workspace-pages-browser.ps1")) {
  throw "Missing workspace pages browser verifier wrapper"
}
if (-not (Test-Path "scripts\verify-workspace-pages-browser.cjs")) {
  throw "Missing workspace pages browser verifier runner"
}
$workspacePagesBrowserParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\verify-workspace-pages-browser.ps1",
  [ref]$null,
  [ref]$workspacePagesBrowserParseErrors
) | Out-Null
if ($workspacePagesBrowserParseErrors -and $workspacePagesBrowserParseErrors.Count -gt 0) {
  $workspacePagesBrowserParseErrors | ForEach-Object { Write-Error $_.Message }
  throw "Workspace pages browser verifier has parse errors"
}
$workspacePagesBrowserRunner = Get-Content -Path "scripts\verify-workspace-pages-browser.cjs" -Raw
foreach ($required in @(
  "workspace-pages-browser-proof-v1",
  "workspace-pages-browser-proof-latest.json",
  "workspace-surface-wiring-v1",
  "reference-design-conformance-v1",
  "page_count === 22",
  "gotoWorkspaceRoute",
  '"502", "503", "504"',
  "Browser console errors on",
  "screenshots_dir",
  "activeRail",
  "maxLargePanelRadius",
  "retiredProvidersHidden",
  "projectStatusWallHidden",
  "unpaidBudgetHidden",
  "Hetzner|GitKraken|Oracle",
  "Localhost proof remains DEV-ONLY",
  "No cloud mutation, deploy, live provider call, MCP write, or secret output"
)) {
  if (-not $workspacePagesBrowserRunner.Contains($required)) {
    throw "Workspace pages browser runner missing guard: $required"
  }
}
if (-not (Test-Path "scripts\verify-workspace-responsive-browser.cjs")) {
  throw "Missing workspace responsive browser verifier runner"
}
$workspaceResponsiveRunner = Get-Content -Path "scripts\verify-workspace-responsive-browser.cjs" -Raw
foreach ($required in @(
  "frontend-22-page-responsive-browser-v1",
  "frontend_22_page_responsive_click_proof",
  "Expected 22 routes",
  "click_navigation_count: 44",
  "overflow_failures: 0",
  "console_errors: 0",
  'width: 1440, height: 960',
  'width: 390, height: 844',
  "Suchen oder Befehl ausführen",
  'waitUntil: "commit"',
  "Localhost evidence remains DEV-ONLY"
)) {
  if (-not $workspaceResponsiveRunner.Contains($required)) {
    throw "Workspace responsive browser runner missing guard: $required"
  }
}
$browserContractSource = Get-Content -Path "scripts\verify-browser-contract.ps1" -Raw
foreach ($required in @(
  "verify-workspace-responsive-browser.cjs",
  "workspace responsive browser proof",
  "--allow-localhost"
)) {
  if (-not $browserContractSource.Contains($required)) {
    throw "Browser contract missing responsive integration guard: $required"
  }
}
if (-not (Test-Path "scripts\verify-reference-design-browser.ps1")) {
  throw "Missing reference design browser verifier wrapper"
}
if (-not (Test-Path "scripts\verify-reference-design-browser.cjs")) {
  throw "Missing reference design browser verifier runner"
}
$referenceDesignBrowserParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\verify-reference-design-browser.ps1",
  [ref]$null,
  [ref]$referenceDesignBrowserParseErrors
) | Out-Null
if ($referenceDesignBrowserParseErrors -and $referenceDesignBrowserParseErrors.Count -gt 0) {
  $referenceDesignBrowserParseErrors | ForEach-Object { Write-Error $_.Message }
  throw "Reference design browser verifier has parse errors"
}
$referenceDesignBrowserRunner = Get-Content -Path "scripts\verify-reference-design-browser.cjs" -Raw
foreach ($required in @(
  "reference-design-browser-proof-v1",
  "reference-design-workbench.png",
  "reference-design-organism.png",
  "reference-design-browser-proof-latest.json",
  "industrial-developer-workbench",
  "waitForBodyText",
  "Workspace-Surfaces",
  "Metered Budget",
  "readPixels",
  "pngVisualStats",
  "uniqueColorBuckets",
  "accentPixels",
  "no_fake_live",
  "Localhost proof remains DEV-ONLY",
  "No cloud mutation, live provider call, MCP write, or secret output"
)) {
  if (-not $referenceDesignBrowserRunner.Contains($required)) {
    throw "Reference design browser runner missing guard: $required"
  }
}
$referenceDesignAgentApiSource = Get-Content -Path "services\agent-api\app\main.py" -Raw
foreach ($required in @(
  "platform_verify_payload",
  'platform-verify-readiness-v1',
  '@app.get("/api/v1/platform/verify")',
  "cloud_layer_readiness_state",
  "Localhost remains DEV-ONLY"
)) {
  if (-not $referenceDesignAgentApiSource.Contains($required)) {
    throw "Agent API missing platform verify mirror guard: $required"
  }
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

Write-Host "[verify] memory worker metadata secret guard"
& (Join-Path $PSScriptRoot "verify-memory-worker-secret-guard.ps1") -StaticOnly
Assert-LastExitCode "memory worker metadata secret guard"

Write-Host "[verify] O5 live vector memory search chain"
# capability-gates.json reserved this exact path long before the file existed, so the owner input
# manifest pointed at a verifier that was never written. It reports the semantic-retrieval chain and
# stays read-only: a missing precondition is `blocked` and passes, an incoherent claim fails.
$liveVectorSearchVerifierPath = Join-Path $PSScriptRoot "verify-live-vector-memory-search.ps1"
if (-not (Test-Path -LiteralPath $liveVectorSearchVerifierPath -PathType Leaf)) {
  throw "Missing live vector memory search verifier reserved by capability-gates.json"
}
& powershell -NoProfile -ExecutionPolicy Bypass -File $liveVectorSearchVerifierPath
Assert-LastExitCode "O5 live vector memory search chain"

Write-Host "[verify] fail-closed vector memory capability gate"
$vectorMemoryVerifierPath = Join-Path $PSScriptRoot "verify-vector-memory-gate.ps1"
if (-not (Test-Path -LiteralPath $vectorMemoryVerifierPath -PathType Leaf)) {
  throw "Missing vector memory gate verifier"
}
$vectorMemoryParseErrors = $null
[Management.Automation.Language.Parser]::ParseFile(
  $vectorMemoryVerifierPath,
  [ref]$null,
  [ref]$vectorMemoryParseErrors
) | Out-Null
if ($vectorMemoryParseErrors) {
  $vectorMemoryParseErrors | ForEach-Object { Write-Error $_.Message }
  throw "Vector memory gate verifier parse errors"
}
& $vectorMemoryVerifierPath
Assert-LastExitCode "fail-closed vector memory capability gate"

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
  "CLOUDFLARE_API_TOKEN",
  "CLOUDFLARE_ACCOUNT_ID",
  "CLOUDFLARE_STATEFUL_BASE_URL",
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
foreach ($required in @("GHCR_IMAGE_NAMESPACE", "IMAGE_TAG", "AGENT_API_BASE_URL", "MCP_GATEWAY_BASE_URL", "LLM_GATEWAY_BASE_URL", "CLOUDFLARE_STATEFUL_BASE_URL", "CLOUDFLARE_ACCOUNT_ID", "CLOUDFLARE_API_TOKEN")) {
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

Write-Host "[verify] active cloud path excludes retired Fly requirements"
if ($cloudComposeText.Contains("FLY_API_TOKEN")) {
  throw "Cloud compose must not keep FLY_API_TOKEN in the active Cloudflare-native path"
}

Write-Host "[verify] project progress manifest"
node scripts\verify-phase6-frontend.mjs --source-only
Assert-LastExitCode "phase6 frontend source markers"
py -3 -m py_compile scripts\verify_project_progress_manifest.py
Assert-LastExitCode "project progress manifest syntax"
py -3 scripts\verify_project_progress_manifest.py
Assert-LastExitCode "project progress manifest"
$projectProgressManifest = Get-Content -Path "docs\project-progress.manifest.json" -Raw
if (-not $projectProgressManifest.Contains("runtime-post-recreate-steady-state-proof")) {
  throw "Project progress manifest missing runtime post-recreate steady-state proof marker"
}
if (-not $projectProgressManifest.Contains("langgraph-postgres-checkpoint-restart-recovery-proof")) {
  throw "Project progress manifest missing Phase 2 checkpoint restart recovery proof marker"
}
if (-not $projectProgressManifest.Contains("hosted_cloudflare_d1_four_role_agent_pool_readback_proof")) {
  throw "Project progress manifest missing hosted Agent Pool D1 readback proof marker"
}
if (-not $projectProgressManifest.Contains("mcp_current_hosted_readonly_contract_parity_verified")) {
  throw "Project progress manifest missing current hosted MCP read-only parity proof marker"
}
if (-not $projectProgressManifest.Contains("cloudflare_workers_ai_llm_gateway_preview_readonly_source_parity_verified")) {
  throw "Project progress manifest missing hosted Cloudflare LLM read-only parity proof marker"
}
foreach ($marker in @("auth_credential_issuance_fail_closed", "oauth_state_one_time_enforced", "refresh_token_registry_enforced")) {
  if (-not $projectProgressManifest.Contains($marker)) {
    throw "Project progress manifest missing Phase 3 auth fail-closed marker: $marker"
  }
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
$currentPhase3 = $horizontalById["phase_3"]
$currentPhase4 = $horizontalById["phase_4"]
$currentPhase5 = $horizontalById["phase_5"]
$currentPhase6 = $horizontalById["phase_6"]
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
foreach ($requiredHostedBoundaryTerm in @(
  'Current Hosted Boundary',
  'historical provenance only',
  'Current frontend truth is `frontend-hosted-current-proof-v1`',
  'current external truth is `external-gate-audit-v2` plus `external-gate-summary-v2`',
  'Neither one proves a stateful full-backend rollout, release promotion, or full-platform production release'
)) {
  if (-not $verificationRegister.Contains($requiredHostedBoundaryTerm)) {
    throw "Verification register missing current hosted boundary marker: $requiredHostedBoundaryTerm"
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
  "Phase 3 ``$currentPhase3%``",
  "Phase 4 ``$currentPhase4%``",
  "Phase 5 ``$currentPhase5%``",
  "Phase 6 ``$currentPhase6%``",
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
  '| P3   |',
  '| P4   |',
  '| P5   |',
  '| P6   |',
  '| Memory        |'
)) {
  if (-not $projectState.Contains($requiredProjectStateTerm)) {
    throw "PROJECT_STATE.md missing current progress marker: $requiredProjectStateTerm"
  }
}
Assert-RegexContains "PROJECT_STATE.md phase 1 row" $projectState "\|\s*P1\s*\|\s*$currentPhase1%\s*\|"
Assert-RegexContains "PROJECT_STATE.md phase 2 row" $projectState "\|\s*P2\s*\|\s*$currentPhase2%\s*\|"
Assert-RegexContains "PROJECT_STATE.md phase 3 row" $projectState "\|\s*P3\s*\|\s*$currentPhase3%\s*\|"
Assert-RegexContains "PROJECT_STATE.md phase 4 row" $projectState "\|\s*P4\s*\|\s*$currentPhase4%\s*\|"
Assert-RegexContains "PROJECT_STATE.md phase 5 row" $projectState "\|\s*P5\s*\|\s*$currentPhase5%\s*\|"
Assert-RegexContains "PROJECT_STATE.md phase 6 row" $projectState "\|\s*P6\s*\|\s*$currentPhase6%\s*\|"
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
  "- P3: ``$currentPhase3%``",
  "- P4: ``$currentPhase4%``",
  "- P5: ``$currentPhase5%``",
  "- P6: ``$currentPhase6%``",
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
Write-Host "[verify] current truth mirror external gate v2 alignment"
$candidateAuditName = "external-gate-audit-20260713-125413.json"
$masterGoal = Get-Content -Path "CODEX_MASTER_GOAL_FINALE.md" -Raw
$externalGateSummary = Get-Content -Path "docs\runtime-state\external-gate-summary.json" -Raw | ConvertFrom-Json
if ([string]$externalGateSummary.contract_version -ne "external-gate-summary-v2") {
  throw "Canonical external gate summary must use external-gate-summary-v2"
}
if ([string]$externalGateSummary.source_contract_version -ne "external-gate-audit-v2") {
  throw "Canonical external gate summary must source external-gate-audit-v2"
}
if ([string]$externalGateSummary.active_target_gate -ne "cloudflare_native_zero_card_hosted_runtime") {
  throw "Canonical external gate summary must target cloudflare_native_zero_card_hosted_runtime"
}
$currentAuditPath = ([string]$externalGateSummary.source_artifact).Replace("\", "/")
if ($currentAuditPath -ne "docs/runtime-state/external-gate-audit-v2.json") {
  throw "Canonical external gate summary must dynamically reference the durable v2 audit"
}
if (-not (Test-Path -LiteralPath $currentAuditPath)) {
  throw "Canonical external gate v2 audit is missing: $currentAuditPath"
}
$trackedCurrentAudit = git ls-files --error-unmatch -- $currentAuditPath 2>$null
if ($LASTEXITCODE -ne 0 -or @($trackedCurrentAudit).Count -ne 1) {
  throw "Canonical external gate v2 audit must be tracked: $currentAuditPath"
}
$currentAudit = Get-Content -LiteralPath $currentAuditPath -Raw | ConvertFrom-Json
if ([string]$currentAudit.contract_version -ne "external-gate-audit-v2") {
  throw "Canonical external gate audit contract must be external-gate-audit-v2"
}
if ([string]$currentAudit.active_target_gate -ne "cloudflare_native_zero_card_hosted_runtime") {
  throw "Canonical external gate audit must target cloudflare_native_zero_card_hosted_runtime"
}
if (
  [string]$externalGateSummary.status -ne [string]$currentAudit.status -or
  [string]$externalGateSummary.generated_at_utc -ne [string]$currentAudit.generated_at_utc -or
  [bool]$externalGateSummary.production_deploy_claim_allowed -ne [bool]$currentAudit.production_deploy_claim_allowed
) {
  throw "Canonical external gate summary and durable v2 audit are out of parity"
}
$currentAuditName = [System.IO.Path]::GetFileName($currentAuditPath)
$currentTruthMirrors = @(
  @{ name = "PROJECT_STATE.md"; content = $projectState },
  @{ name = "AI_HANDOFF.md"; content = $aiHandoff },
  @{ name = "docs/verification-register.md"; content = $verificationRegister },
  @{ name = "CODEX_MASTER_GOAL_FINALE.md"; content = $masterGoal }
)
foreach ($mirror in $currentTruthMirrors) {
  foreach ($requiredTruthMarker in @(
    $currentAuditName,
    "external-gate-summary-v2",
    "cloudflare_native_zero_card_hosted_runtime"
  )) {
    if (-not $mirror.content.Contains($requiredTruthMarker)) {
      throw "$($mirror.name) missing current external gate v2 truth marker: $requiredTruthMarker"
    }
  }
}
if (-not $masterGoal.Contains("``overall=$currentOverall``")) {
  throw "CODEX_MASTER_GOAL_FINALE.md missing current overall=$currentOverall marker"
}
if (([string]$externalGateSummary.source_artifact).Contains($candidateAuditName)) {
  throw "Historical owner-assisted candidate $candidateAuditName must never be the canonical summary source"
}
if ([string]$externalGateSummary.status -ne "blocked" -or [bool]$externalGateSummary.production_deploy_claim_allowed) {
  throw "Canonical external gate summary must stay blocked with production_deploy_claim_allowed=false while release gates remain open"
}
$actualMissingExternalGates = @($externalGateSummary.missing_or_failed_gates | ForEach-Object { [string]$_ })
# Branch protection was listed as missing only because the probe had no branch to ask about: the
# `$Branch` default was empty and this repository has no `main` at all. Once the probe resolves the real
# default branch, protection verifies with zero mismatches. The assertion is therefore bound to the
# claim flag instead of to a fixed count, so a regression in either direction still fails closed.
if (-not [bool]$externalGateSummary.cloudflare_native_zero_card_hosted_runtime_claim_allowed) {
  throw "Canonical external gate summary must keep the O2Core claim allowed"
}
if ($actualMissingExternalGates -notcontains "ghcr_image_digest_verify") {
  throw "Canonical external gate summary must still list the unpublished GHCR digest as missing"
}
if ([bool]$externalGateSummary.branch_protection_claim_allowed) {
  if ($actualMissingExternalGates -contains "github_branch_protection_current_verify") {
    throw "Branch protection is claimed verified but is still listed as a missing external gate"
  }
  if ($actualMissingExternalGates.Count -ne 1) {
    throw "With branch protection verified, only the GHCR digest may remain missing"
  }
} else {
  if ($actualMissingExternalGates -notcontains "github_branch_protection_current_verify") {
    throw "Branch protection is not claimed verified, so it must be listed as a missing external gate"
  }
  if ($actualMissingExternalGates.Count -ne 2) {
    throw "Canonical external gate summary must list only Branch Protection plus GHCR digest as missing"
  }
}
if (
  $externalGateSummary.PSObject.Properties.Name -contains "fly_live_budget_claim_allowed" -or
  $actualMissingExternalGates -contains "fly_live_budget_check"
) {
  throw "Retired Fly gate semantics must not remain active in external-gate-summary-v2"
}
if (
  [string]$externalGateSummary.legacy_provenance.status -ne "historical_only" -or
  [string]$externalGateSummary.legacy_provenance.retired_gate_id -ne "fly_live_budget_check"
) {
  throw "Retired Fly evidence must be explicit historical provenance"
}
# The older token/origin-injected run may exist only as historical, non-current evidence.
$candidateSummaryPath = "docs\runtime-state\external-gate-summary.candidate-125413.json"
if (-not (Test-Path $candidateSummaryPath)) {
  throw "Missing owner-assisted candidate summary for $candidateAuditName (R0 candidate-only evidence)"
}
$candidateSummary = Get-Content -Path $candidateSummaryPath -Raw | ConvertFrom-Json
if (-not ([string]$candidateSummary.source_artifact).Contains($candidateAuditName)) {
  throw "Owner-assisted candidate summary must reference $candidateAuditName"
}
if ([bool]$candidateSummary.is_current -or -not [bool]$candidateSummary.owner_assisted_candidate) {
  throw "R0 violation: 125413 candidate must be labeled is_current=false and owner_assisted_candidate=true"
}
if ([bool]$candidateSummary.supersedes_canonical) {
  throw "Historical owner-assisted candidate must not supersede the canonical v2 summary"
}

$capabilityGateState = Get-Content -Path "docs\runtime-state\capability-gates.json" -Raw | ConvertFrom-Json
Write-Host "[verify] current Cloudflare-native hosted runtime truth"
$cloudflareHostedState = Get-Content -Path "docs\runtime-state\cloudflare-native-hosted-current.json" -Raw | ConvertFrom-Json
$cloudflareHostedGate = $capabilityGateState.gates.cloudflare_native_zero_card_hosted_runtime
if (
  [string]$cloudflareHostedState.contract_version -ne "cloudflare-native-hosted-current-v1" -or
  [string]$cloudflareHostedState.status -ne "verified" -or
  [string]$cloudflareHostedState.runtime_contract_version -ne "cloudflare-native-runtime-candidate-v2" -or
  [string]$cloudflareHostedState.artifact_adapter -ne "cloudflare-d1-bounded-text" -or
  [int]$cloudflareHostedState.artifact_content_max_bytes -ne 32768 -or
  [string]$cloudflareHostedState.r2_status -ne "historical_only" -or
  [bool]$cloudflareHostedState.r2_enabled -or
  [bool]$cloudflareHostedState.paid_provider -or
  [bool]$cloudflareHostedState.dev_only -or
  -not [bool]$cloudflareHostedState.hosted_proof -or
  -not [bool]$cloudflareHostedState.hosted_source_parity_verified -or
  -not [bool]$cloudflareHostedState.hosted_stateful_roundtrip_verified -or
  -not [bool]$cloudflareHostedState.create_enqueue_queue_do_d1_artifact_roundtrip -or
  -not [bool]$cloudflareHostedState.d1_artifact_write_read_delete_verified -or
  -not [bool]$cloudflareHostedState.zero_card_verified -or
  [bool]$cloudflareHostedState.live_provider_calls -or
  [bool]$cloudflareHostedState.direct_provider_calls -or
  [bool]$cloudflareHostedState.live_mcp_writes -or
  [bool]$cloudflareHostedState.production_deploy -or
  [bool]$cloudflareHostedState.production_release_claimed -or
  [bool]$cloudflareHostedState.secret_output -or
  [int]$cloudflareHostedState.percentage_credit -ne 0
) {
  throw "Current Cloudflare-native hosted runtime truth violates its verified zero-card/non-claim contract"
}
if (
  [string]$cloudflareHostedState.base_url -notmatch '^https://[^/]+\.workers\.dev$' -or
  [string]$cloudflareHostedState.source_commit_sha -notmatch '^[0-9a-f]{40}$' -or
  [string]$cloudflareHostedState.source_archive_sha256 -notmatch '^[0-9a-f]{64}$' -or
  [string]$cloudflareHostedState.evidence_sha256 -notmatch '^[A-F0-9]{64}$' -or
  ((@($cloudflareHostedState.bindings) | Sort-Object) -join ',') -ne 'DB,RUNTIME_COORDINATOR,RUNTIME_QUEUE'
) {
  throw "Current Cloudflare-native hosted runtime truth has invalid source, evidence, URL, or binding identity"
}

# Hosted product acceptance and the hosted 22-page matrix used to be forbidden here, because at the
# time this guard was written the Worker proof was the only hosted evidence and neither acceptance
# report existed. Both now exist as source-bound hosted artefacts, so a blanket "must be false" would
# force the truth file to under-report a real proof. The claim is therefore bound to its evidence
# instead of banned: false means nothing may be claimed, true means the artefact, its SHA-256, its
# source commit and its deployment identity must all hold. verify-market-ready.ps1 asserts the same
# pair from the opposite direction, so drifting one file alone now fails both gates.
function Get-HostedAcceptanceSha256([string]$Path) {
  $stream = [IO.File]::OpenRead($Path)
  try {
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
      return (($sha256.ComputeHash($stream) | ForEach-Object { $_.ToString("X2") }) -join "")
    } finally {
      $sha256.Dispose()
    }
  } finally {
    $stream.Dispose()
  }
}
foreach ($hostedAcceptance in @(
  @{ Label = "product acceptance"; Flag = "product_acceptance_hosted_proof"; Prefix = "product_acceptance" },
  @{ Label = "22-page action matrix"; Flag = "workspace_22_page_hosted_proof"; Prefix = "workspace_22_page" }
)) {
  $acceptanceClaimed = [bool]$cloudflareHostedState.($hostedAcceptance.Flag)
  $acceptanceArtifact = [string]$cloudflareHostedState."$($hostedAcceptance.Prefix)_evidence_artifact"
  $acceptanceSha = [string]$cloudflareHostedState."$($hostedAcceptance.Prefix)_evidence_sha256"
  $acceptanceCommit = [string]$cloudflareHostedState."$($hostedAcceptance.Prefix)_source_commit_sha"
  $acceptanceDeployment = [string]$cloudflareHostedState."$($hostedAcceptance.Prefix)_deployment_id"
  $acceptanceBaseUrl = [string]$cloudflareHostedState."$($hostedAcceptance.Prefix)_base_url"

  if (-not $acceptanceClaimed) {
    if (
      -not [string]::IsNullOrWhiteSpace($acceptanceArtifact) -or
      -not [string]::IsNullOrWhiteSpace($acceptanceSha) -or
      -not [string]::IsNullOrWhiteSpace($acceptanceCommit) -or
      -not [string]::IsNullOrWhiteSpace($acceptanceDeployment)
    ) {
      throw "Unclaimed hosted $($hostedAcceptance.Label) must not carry evidence, source, or deployment fields"
    }
    continue
  }

  if (-not (Test-Path -LiteralPath $acceptanceArtifact -PathType Leaf)) {
    throw "Hosted $($hostedAcceptance.Label) claims proof but its evidence artefact is missing: $acceptanceArtifact"
  }
  $acceptanceActualSha = Get-HostedAcceptanceSha256 (Resolve-Path -LiteralPath $acceptanceArtifact).Path
  if ($acceptanceSha -ne $acceptanceActualSha) {
    throw "Hosted $($hostedAcceptance.Label) evidence SHA-256 does not match its recorded value"
  }
  if (
    $acceptanceCommit -notmatch '^[0-9a-f]{40}$' -or
    [string]::IsNullOrWhiteSpace($acceptanceDeployment) -or
    $acceptanceBaseUrl -notmatch '^https://'
  ) {
    throw "Hosted $($hostedAcceptance.Label) must be bound to a full commit sha, a deployment id, and an https base url"
  }
  git cat-file -e "$acceptanceCommit^{commit}" 2>$null
  Assert-LastExitCode "hosted $($hostedAcceptance.Label) source commit"
  git merge-base --is-ancestor $acceptanceCommit HEAD
  Assert-LastExitCode "hosted $($hostedAcceptance.Label) source ancestry"

  $acceptanceReport = Get-Content -LiteralPath $acceptanceArtifact -Raw | ConvertFrom-Json
  if (
    [string]$acceptanceReport.status -ne "verified" -or
    -not [bool]$acceptanceReport.hosted_proof -or
    [bool]$acceptanceReport.dev_only -or
    [string]$acceptanceReport.proof_scope -ne "hosted_https" -or
    [bool]$acceptanceReport.secret_output -or
    [string]$acceptanceReport.source_binding.source_commit_sha -ne $acceptanceCommit -or
    [string]$acceptanceReport.source_binding.deployment_id -ne $acceptanceDeployment
  ) {
    throw "Hosted $($hostedAcceptance.Label) artefact contradicts the truth file it is bound to"
  }
}

if (
  -not [bool]$cloudflareHostedGate.owner_granted -or
  -not [bool]$cloudflareHostedGate.live_verified -or
  -not [bool]$cloudflareHostedGate.zero_card_verified -or
  -not [bool]$cloudflareHostedGate.hosted_source_parity_verified -or
  -not [bool]$cloudflareHostedGate.hosted_stateful_roundtrip_verified -or
  [bool]$cloudflareHostedGate.r2_enabled -or
  [bool]$cloudflareHostedGate.paid_provider -or
  [string]$cloudflareHostedGate.evidence_sha256 -ne [string]$cloudflareHostedState.evidence_sha256 -or
  [string]$cloudflareHostedGate.source_commit_sha -ne [string]$cloudflareHostedState.source_commit_sha -or
  [string]$cloudflareHostedGate.source_archive_sha256 -ne [string]$cloudflareHostedState.source_archive_sha256 -or
  [string]$cloudflareHostedGate.hosted_base_url -ne [string]$cloudflareHostedState.base_url -or
  -not [bool]$externalGateSummary.cloudflare_native_zero_card_hosted_runtime_claim_allowed
) {
  throw "Current Cloudflare-native hosted runtime truth is not bound to the verifier-opened capability and external-gate mirrors"
}
git cat-file -e "$($cloudflareHostedState.source_commit_sha)^{commit}" 2>$null
Assert-LastExitCode "current Cloudflare-native hosted source commit"
git merge-base --is-ancestor ([string]$cloudflareHostedState.source_commit_sha) HEAD
Assert-LastExitCode "current Cloudflare-native hosted source ancestry"
git diff --quiet ([string]$cloudflareHostedState.source_commit_sha) -- services/cloudflare-stateful-runtime
Assert-LastExitCode "current Cloudflare-native hosted Worker source parity"

Write-Host "[verify] O6 bounded live LLM resolution truth"
$liveLlmCapability = $capabilityGateState.gates.live_llm_provider_calls
if (
  -not [bool]$liveLlmCapability.owner_granted -or
  -not [bool]$liveLlmCapability.live_verified -or
  [bool]$liveLlmCapability.paid_provider -or
  [string]::IsNullOrWhiteSpace([string]$liveLlmCapability.evidence_artifact)
) {
  throw "O6 bounded live LLM capability must remain owner_granted, free, and verifier-backed"
}
$ownerInputManifest = Get-Content -Path "docs\runtime-state\owner-input-manifest.json" -Raw | ConvertFrom-Json
if ([string]$ownerInputManifest.contract_version -ne "owner-input-manifest-v2") {
  throw "Owner input manifest must use owner-input-manifest-v2"
}
$o6OwnerAction = @($ownerInputManifest.actions | Where-Object { [string]$_.id -eq "O6" })
if ($o6OwnerAction.Count -ne 1 -or [string]$o6OwnerAction[0].status -ne "resolved_verified") {
  throw "O6 must be resolved_verified and must not remain Owner-required"
}
if (-not ([string]$o6OwnerAction[0].required_owner_action).StartsWith("None")) {
  throw "O6 must not request a new Owner action"
}
$layer4Progress = @($projectProgress.vertical.items | Where-Object { [string]$_.id -eq "layer_4" })
if ($layer4Progress.Count -ne 1 -or [int]$layer4Progress[0].percent -ge 100) {
  throw "Bounded O6 resolution must not hand-set Layer 4 to 100"
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
foreach ($required in @("cloud-provider-inventory-v1", "cloud_provider_inventory_visible", "cloud-layer-readiness-v1", "cloud_layer_readiness_visible", "GET /api/v1/clouds", "GET /api/v1/clouds/layers", "seven_layer_mapping", "cloud_layer_readiness_state", "historical_only", "cannot satisfy active Layer 2, 3, 6", "CLOUDFLARE_STATEFUL_BASE_URL", "CLOUDFLARE_ACCOUNT_ID", "CLOUDFLARE_API_TOKEN", "cloudflare_api_readonly", "CLOUDFLARE_DASHBOARD_URL", "VERCEL_TOKEN", "vercel_api_readonly", "GITHUB_TOKEN", "github_api_readonly", "GHCR_TOKEN", "ghcr_api_readonly", "HF_TOKEN", "huggingface_api_readonly", "GITLAB_TOKEN", "gitlab_api_readonly", "GRAFANA_CLOUD_API_KEY", "GRAFANA_CLOUD_API_URL", "/api/v1/accesspolicies", "/api/access-control/user/permissions", "grafana_api_readonly", "real read-only provider API request", "No secret values", "mask_ip", "vercel_frontend", "cloudflare_edge", "github_actions", "ghcr_registry", "huggingface_identity", "gitlab_identity", "grafana_cloud")) {
  if (-not $cloudProviderSource.Contains($required)) {
    throw "Missing cloud provider inventory source guard: $required"
  }
}
foreach ($required in @("cloud_provider_state", "cloud_layer_readiness_state", "/api/v1/clouds", "/api/v1/clouds/layers", "cloud-render-offload-v1", "cloud_render_offload_contract_visible", "/api/v1/clouds/render-offload/contract", "localhost_heavy_render_allowed", "cloud_render_offload_requires_STAGING_BASE_URL")) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing cloud provider inventory API guard: $required"
  }
}
$cloudProviderLiveReadVerifier = Get-Content -Path "scripts\verify-cloud-provider-live-read.ps1" -Raw
foreach ($required in @("cloud-provider-live-read-proof-v1", "RequireT3ProviderSet", "DEV-ONLY; hosted proof still blocked.", "CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "GHCR_TOKEN", "GRAFANA_CLOUD_API_KEY", "artifact contains secret material")) {
  if (-not $cloudProviderLiveReadVerifier.Contains($required)) {
    throw "Missing cloud provider live-read verifier guard: $required"
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
  "AUTH_REFRESH_ACTIVE_PREFIX",
  "AUTH_OAUTH_STATE_PREFIX",
  "AUTH_OAUTH_STATE_PATTERN",
  "AUTH_SIGNING_SECRET_PATTERN",
  "auth_signing_secret_is_strong",
  "auth_credential_issuance_fail_closed",
  "oauth_state_one_time_enforced",
  "refresh_token_registry_enforced",
  "refresh_token_body_not_allowed",
  "oauth_state_invalid",
  "oauth_callback_parameters_invalid",
  "oauth_provider_denied",
  "auth_configuration_required",
  "auth_audit_unavailable",
  "credential_issuance_requires_persistence",
  "auth_logout_no_active_token",
  "oauth_state_cookie_clear_headers",
  "RedirectResponse",
  "SameSite"
)) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing Auth JWT refresh contract guard: $required"
  }
}
foreach ($forbidden in @(
  'create_access_jwt("github:local-contract-user"',
  'supplied_token = (request.refresh_token if request else None) or refresh_token_cookie',
  '"blacklist_key": blacklist_key',
  'phase3-local-dry-run-signing-secret',
  '"authorize_url": authorize_url',
  '"scope": "read:user user:email"',
  '"mode": "local_contract"',
  'jwt_signing_configured = len(signing_secret.encode("utf-8")) >= 32'
)) {
  if ($apiTaskPolicySource.Contains($forbidden)) {
    throw "Unsafe Auth credential-issuance source marker remains: $forbidden"
  }
}
$agentApiDockerfile = Get-Content -LiteralPath "services\agent-api\Dockerfile" -Raw
if (-not $agentApiDockerfile.Contains('"--no-access-log"')) {
  throw "Agent API must disable raw Uvicorn access logging for OAuth callback query safety"
}
foreach ($nginxPath in @("infrastructure\nginx\dev.conf", "infrastructure\nginx\cloud.conf")) {
  $authSafeNginx = Get-Content -LiteralPath $nginxPath -Raw
  if (-not $authSafeNginx.Contains("log_format superbrain_path_only") -or
      -not $authSafeNginx.Contains('$request_method $uri $server_protocol')) {
    throw "Nginx auth-safe path-only access log missing: $nginxPath"
  }
  if ($authSafeNginx -match '(?m)^\s*log_format\s+superbrain_path_only[^;]*\$request(?:\s|''|"|;)') {
    throw "Nginx auth-safe access log must not include raw request arguments: $nginxPath"
  }
}
Write-Host "[verify] Phase 3 auth credential issuance fail-closed"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-phase3-auth-fail-closed.ps1 -StaticOnly
Assert-LastExitCode "Phase 3 auth credential issuance fail-closed"
Write-Host "[verify] Phase 5 historical auth supersession"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-phase5-auth-gate-recheck.ps1 -StaticOnly
Assert-LastExitCode "Phase 5 historical auth supersession"
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
$navSource = Get-Content -Path "apps\frontend\lib\nav.tsx" -Raw
foreach ($required in @("Route registry", "canonical 22 pages", "/workbench", "/organism", "/tools", "/marketplace", "/observe", "/evidence", "/diagnostics")) {
  if (-not $navSource.Contains($required)) {
    throw "Missing nav registry guard: $required"
  }
}
$landingSource = Get-Content -Path "apps\frontend\app\page.tsx" -Raw
foreach ($required in @("Canonical platform specification", "not live runtime metrics", "never printed")) {
  if (-not $landingSource.Contains($required)) {
    throw "Missing landing non-claim guard: $required"
  }
}
$homeSource = Get-Content -Path "apps\frontend\app\home\page.tsx" -Raw
foreach ($required in @("Entwicklerplattform", "Produktfläche", "Nachweise", "Diagnose", "Organismus", "Studio-Modi", "Kernseiten", "Live-Aussagen")) {
  if (-not $homeSource.Contains($required)) {
    throw "Missing clean home product-surface guard: $required"
  }
}
foreach ($forbidden in @("fetchRecentTasks", "fetchRecentSessions", "fetchAuditRecent", "fetchLiveAgents", "fetchLayers", "Letzte Projekte", "Projektstand", "Gate-Matrix", "Recovery-Historie")) {
  if ($homeSource.Contains($forbidden)) {
    throw "Home must not surface project workspace state: $forbidden"
  }
}
# The workbench surface is split between the route wrapper (page.tsx) and the studio component
# (workbench-studio.tsx). Validate the combined surface so the guard tracks the real layout.
$workbenchSource = Get-Content -Path "apps\frontend\app\workbench\page.tsx" -Raw
$workbenchStudioSource = Get-Content -Path "apps\frontend\components\workbench-studio.tsx" -Raw
$workbenchSurface = $workbenchSource + "`n" + $workbenchStudioSource
foreach ($required in @("WorkbenchStudio", "workbench-studio", "wb-composer", "/api/v1/build", "Dateien", "Vorschau", "Build-Protokoll", "terminal-feed", "ws-frame")) {
  if (-not $workbenchSurface.Contains($required)) {
    throw "Missing clean workbench platform guard: $required"
  }
}
foreach ($forbidden in @("fetchMasterPlan", "Master Plan (live)", "Dispatch endpoints", "fetchCompletionGate", "fetchRecentTasks", "fetchRecentSessions", "fetchAuditRecent", "fetchLiveAgents", "Completion-Gate", "Workspace-Surfaces (22)", "Fail-closed by design", "Gate-Matrix", "Recovery-Historie")) {
  if ($workbenchSurface.Contains($forbidden)) {
    throw "Workbench must not surface project-plan dashboard elements: $forbidden"
  }
}
foreach ($required in @(
  "CSP_REPORT_CONTRACT_VERSION",
  "CSP_REPORT_EVIDENCE_REF",
  "CSP_REPORT_AUDIT_EVIDENCE_REF",
  "CSP_REPORT_MAX_BODY_BYTES",
  "CSP_REPORT_CONTENT_TYPES",
  "sanitize_csp_report",
  "persist_csp_report_audit",
  "/api/v1/security/csp/contract",
  "/api/v1/security/csp/report",
  "csp-report-contract-v1",
  "csp_report_contract_visible",
  "csp_report_audit_persisted",
  "security_csp_violation_reported",
  "csp_report_too_large",
  "unsupported_csp_report_content_type",
  "uri_query_and_fragment_persisted",
  "live_external_report_forwarding"
)) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing CSP report audit contract guard: $required"
  }
}
foreach ($required in @(
  "CSRF_ORIGIN_CONTRACT_VERSION",
  "CSRF_ORIGIN_EVIDENCE_REF",
  "CSRF_ORIGIN_AUDIT_EVIDENCE_REF",
  "csrf_origin_guard_middleware",
  "persist_csrf_rejection_audit",
  "/api/v1/security/csrf/contract",
  "/api/v1/security/csrf/probe",
  "csrf-origin-guard-v1",
  "csrf_origin_guard_visible",
  "csrf_origin_rejection_audited",
  "security_csrf_request_rejected",
  "fetch_metadata_cross_site",
  "invalid_or_null_origin",
  "origin_mismatch"
)) {
  if (-not $apiTaskPolicySource.Contains($required)) { throw "Missing CSRF origin guard: $required" }
}
foreach ($required in @(
  "PHASE6_3D_CAMERA_LIGHTING_CONTRACT_VERSION",
  "PHASE6_3D_CAMERA_LIGHTING_EVIDENCE_REF",
  "phase6_3d_camera_lighting_runtime_contract_payload",
  "/api/v1/phase6/3d-camera-lighting/contract",
  "phase6-3d-camera-lighting-runtime-v1",
  "phase6_3d_camera_lighting_runtime_visible",
  "local_camera_rig_lighting_profile_state",
  "camera_preset_switch_visible",
  "fov_step_control_visible",
  "lighting_profile_switch_visible",
  "safe_exposure_bounds_visible",
  "applied_runtime_state_attributes_required",
  "network_calls_required"
)) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing Phase 6 camera and lighting contract guard: $required"
  }
}
foreach ($required in @(
  "PHASE6_3D_GAMEPLAY_STATE_CONTRACT_VERSION",
  "PHASE6_3D_GAMEPLAY_STATE_EVIDENCE_REF",
  "phase6_3d_gameplay_state_runtime_contract_payload",
  "/api/v1/phase6/3d-gameplay-state/contract",
  "phase6-3d-gameplay-state-runtime-v1",
  "phase6_3d_gameplay_state_runtime_visible",
  "local_objective_score_checkpoint_state_machine",
  "deterministic_gameplay_state_machine",
  "pause_safe_game_loop_state",
  "applied_runtime_state_attributes_required",
  "network_calls_required"
)) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing Phase 6 gameplay state contract guard: $required"
  }
}
foreach ($required in @(
  "PHASE6_3D_ASSET_POLICY_CONTRACT_VERSION",
  "PHASE6_3D_ASSET_POLICY_EVIDENCE_REF",
  "phase6_3d_asset_policy_runtime_contract_payload",
  "/api/v1/phase6/3d-asset-policy/contract",
  "phase6-3d-asset-policy-runtime-v1",
  "phase6_3d_asset_policy_runtime_visible",
  "local_procedural_primitive_asset_catalog",
  "procedural_asset_catalog_visible",
  "asset_profile_switch_visible",
  "material_policy_variant_visible",
  "external_asset_fetch_allowed",
  "binary_asset_upload_allowed"
)) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing Phase 6 asset policy contract guard: $required"
  }
}
foreach ($required in @(
  "PHASE6_3D_SAVE_LOAD_CONTRACT_VERSION",
  "PHASE6_3D_SAVE_LOAD_EVIDENCE_REF",
  "phase6_3d_save_load_runtime_contract_payload",
  "/api/v1/phase6/3d-save-load/contract",
  "phase6-3d-save-load-runtime-v1",
  "phase6_3d_save_load_runtime_visible",
  "typed_allowlisted_react_state_snapshot",
  "scene_snapshot_capture_visible",
  "scene_snapshot_restore_visible",
  "persistent_browser_storage_blocked",
  "cloud_save_sync_allowed",
  "server_snapshot_write_allowed"
)) {
  if (-not $apiTaskPolicySource.Contains($required)) {
    throw "Missing Phase 6 save and load contract guard: $required"
  }
}
foreach ($required in @("PHASE6_3D_ACCESSIBILITY_CONTRACT_VERSION","PHASE6_3D_ACCESSIBILITY_EVIDENCE_REF","phase6_3d_accessibility_runtime_contract_payload","/api/v1/phase6/3d-accessibility/contract","phase6-3d-accessibility-runtime-v1","phase6_3d_accessibility_runtime_visible","system_aware_reduced_motion_semantic_keyboard_fallback","keyboard_fallback_navigation_visible","accessibility_telemetry_export_allowed")) {
  if (-not $apiTaskPolicySource.Contains($required)) { throw "Missing Phase 6 accessibility contract guard: $required" }
}
foreach ($required in @("PHASE6_3D_NETCODE_CONTRACT_VERSION","PHASE6_3D_NETCODE_EVIDENCE_REF","phase6_3d_netcode_loopback_runtime_contract_payload","/api/v1/phase6/3d-netcode/contract","phase6-3d-netcode-loopback-runtime-v1","phase6_3d_netcode_loopback_runtime_visible","two_peer_manual_lockstep_browser_loopback","remote_transport_boundary_closed","websocket_allowed","server_authoritative_sync_allowed")) {
  if (-not $apiTaskPolicySource.Contains($required)) { throw "Missing Phase 6 netcode loopback contract guard: $required" }
}
foreach ($required in @("PHASE6_LOCAL_SCOREBOARD_CONTRACT_VERSION","PHASE6_LOCAL_SCOREBOARD_EVIDENCE_REF","phase6_local_scoreboard_performance_runtime_contract_payload","/api/v1/phase6/local-scoreboard-performance/contract","phase6-local-scoreboard-performance-runtime-v1","phase6_local_scoreboard_performance_runtime_visible","volatile_top_three_runs_visible","bounded_frame_sample_visible","leaderboard_sync_allowed","persistent_storage_allowed","scale_capacity_claim_allowed")) {
  if (-not $apiTaskPolicySource.Contains($required)) { throw "Missing Phase 6 local scoreboard/performance contract guard: $required" }
}
foreach ($required in @("ORCHESTRATOR_COMPLETION_EVIDENCE_CONTRACT_VERSION","ORCHESTRATOR_COMPLETION_EVIDENCE_REF","orchestrator_completion_evidence_contract_payload","/api/v1/orchestrator/completion/contract","orchestrator-completion-evidence-v1","orchestrator_completion_evidence_verified","required_runtime_proofs_not_precomputed_results","parent_sse_replay_and_restart_recovery")) {
  if (-not $apiTaskPolicySource.Contains($required)) { throw "Missing Orchestrator completion contract guard: $required" }
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
  "missing_external_gates",
  "project progress completion missing external gate parity",
  "project progress completion hard blocker present",
  "live_llm_provider_calls_require_owner_gate_and_budget_guard",
  "production_auth_identity_requires_owner_configured_oauth_and_hosted_url",
  "docker_registry_publish_requires_owner_release_gate",
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
foreach ($required in @("phase6-3d-camera-lighting-runtime-v1", "phase6_3d_camera_lighting_runtime_visible", "/api/v1/phase6/3d-camera-lighting/contract", '"safe_exposure_range":{"min":0.72,"max":1.18,"step":0.02}', '"all_scenarios_pass":true')) {
  if (-not $runtimeVerifier.Contains($required)) {
    throw "Runtime verifier missing Phase 6 camera and lighting proof marker: $required"
  }
}
foreach ($required in @("phase6-3d-gameplay-state-runtime-v1", "phase6_3d_gameplay_state_runtime_visible", "/api/v1/phase6/3d-gameplay-state/contract", '"objectives":["collect","checkpoint","survive"]', '"pause_safe_loop_required":true')) {
  if (-not $runtimeVerifier.Contains($required)) {
    throw "Runtime verifier missing Phase 6 gameplay state proof marker: $required"
  }
}
foreach ($required in @("phase6-3d-asset-policy-runtime-v1", "phase6_3d_asset_policy_runtime_visible", "/api/v1/phase6/3d-asset-policy/contract", '"asset_catalog_count":3', '"external_asset_fetch_allowed":false')) {
  if (-not $runtimeVerifier.Contains($required)) {
    throw "Runtime verifier missing Phase 6 asset policy proof marker: $required"
  }
}
foreach ($required in @("phase6-3d-save-load-runtime-v1", "phase6_3d_save_load_runtime_visible", "/api/v1/phase6/3d-save-load/contract", '"snapshot_field_count":15', '"cloud_save_sync_allowed":false')) {
  if (-not $runtimeVerifier.Contains($required)) {
    throw "Runtime verifier missing Phase 6 save and load proof marker: $required"
  }
}
foreach ($required in @("phase6-3d-accessibility-runtime-v1","phase6_3d_accessibility_runtime_visible","/api/v1/phase6/3d-accessibility/contract",'"accessible_item_count":10','"accessibility_telemetry_export_allowed":false')) {
  if (-not $runtimeVerifier.Contains($required)) { throw "Runtime verifier missing Phase 6 accessibility marker: $required" }
}
foreach ($required in @("phase6-3d-netcode-loopback-runtime-v1","phase6_3d_netcode_loopback_runtime_visible","/api/v1/phase6/3d-netcode/contract",'"maximum_peers":2','"websocket_allowed":false','"server_authoritative_sync_allowed":false')) {
  if (-not $runtimeVerifier.Contains($required)) { throw "Runtime verifier missing Phase 6 netcode loopback marker: $required" }
}
foreach ($required in @("phase6-local-scoreboard-performance-runtime-v1","phase6_local_scoreboard_performance_runtime_visible","/api/v1/phase6/local-scoreboard-performance/contract",'"leaderboard_maximum_entries":3','"performance_sample_count":12','"leaderboard_sync_allowed":false','"persistent_storage_allowed":false','"scale_capacity_claim_allowed":false')) {
  if (-not $runtimeVerifier.Contains($required)) { throw "Runtime verifier missing Phase 6 local scoreboard/performance marker: $required" }
}
$scoreboardPerformanceVerifier = Get-Content -Path "scripts\verify-phase6-local-scoreboard-performance-runtime.ps1" -Raw
foreach ($required in @("performance_timeout_seconds -eq 20", "observed twelve samples", "observed finite positive samples")) {
  if (-not $scoreboardPerformanceVerifier.Contains($required)) { throw "Scoreboard/performance verifier missing bounded sample guard: $required" }
}
foreach ($required in @("orchestrator-completion-evidence-v1","orchestrator_completion_evidence_verified","/api/v1/orchestrator/completion/contract",'"layer_progress_after_proof":100','"live_provider_calls":false','"live_mcp_writes":false','"production_deploy":false')) {
  if (-not $runtimeVerifier.Contains($required)) { throw "Runtime verifier missing Orchestrator completion marker: $required" }
}
foreach ($required in @(
  "cloud-deployment-preflight-v1",
  "cloud_deployment_preflight_visible",
  "/api/v1/clouds/deployment-preflight/contract",
  "canonicalExternalGateSummary",
  "expectedExternalGateClaims",
  "expectedExternalGateStatus",
  "expectedProductionDeployClaim",
  "cloud deployment preflight status follows canonical summary",
  "cloud deployment preflight blocker parity",
  "external gates status follows canonical summary",
  "external gate mirror status follows canonical summary",
  "canonical_summary_status",
  "missing_or_blocked_gates",
  "cloudflare_native_zero_card_hosted_runtime",
  "publish_ghcr_images",
  "hosted_backend_origins",
  "CLOUDFLARE_STATEFUL_BASE_URL",
  "CLOUDFLARE_ACCOUNT_ID",
  "CLOUDFLARE_API_TOKEN",
  "cloud deployment preflight required owner scope",
  "cloudflare_zero_card_projection",
  "BRANCH_PROTECTION_TOKEN",
  "canonical_secret_scan",
  "This endpoint does not create, mutate, deploy, or delete cloud resources."
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
  "missing_external_gates",
  "project progress completion missing external gate parity",
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
  "canonicalExternalGateSummary",
  "expectedExternalGateClaims",
  "expectedExternalGateStatus",
  "expectedProductionDeployClaim",
  "cloud deployment preflight status follows canonical summary",
  "cloud deployment preflight blocker parity",
  "external gates status follows canonical summary",
  "external gate mirror status follows canonical summary",
  "canonical_summary_status",
  "missing_or_blocked_gates",
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
foreach ($required in @("fastapi==0.136.3", "uvicorn[standard]==0.49.0", "pydantic==2.13.4")) {
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
  "fastapi==0.136.3",
  "uvicorn[standard]==0.49.0",
  "pydantic==2.13.4",
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
foreach ($required in @("L-08", "mcp_version_pinning_contract_visible", "/mcp/api/v1/version-pinning/contract", "mcp-version-pinning-v1", "fastapi==0.136.3", "uvicorn[standard]==0.49.0", "pydantic==2.13.4", "github-branch-pr-plan-v1", "No live MCP write")) {
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
if (-not (Test-Path "docs\runtime-contracts\security-csp-report-contract.md")) {
  throw "Missing Phase 3 CSP report audit contract document"
}
$cspReportContractDoc = Get-Content -Path "docs\runtime-contracts\security-csp-report-contract.md" -Raw
foreach ($required in @(
  "csp-report-contract-v1",
  "csp_report_contract_visible",
  "csp_report_audit_persisted",
  "security_csp_violation_reported",
  "/api/v1/security/csp/report",
  "16384",
  "Query strings and fragments are removed",
  "DEV-ONLY",
  "No live provider call",
  "No production incident-response workflow is claimed"
)) {
  if (-not $cspReportContractDoc.Contains($required)) {
    throw "CSP report audit contract document missing guard: $required"
  }
}
if (-not (Test-Path "scripts\verify-phase3-csp-report-contract.ps1")) {
  throw "Missing Phase 3 CSP report audit verifier"
}
$cspVerifierParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\verify-phase3-csp-report-contract.ps1",
  [ref]$null,
  [ref]$cspVerifierParseErrors
) | Out-Null
if ($cspVerifierParseErrors -and $cspVerifierParseErrors.Count -gt 0) {
  $cspVerifierParseErrors | ForEach-Object { Write-Error $_.Message }
  throw "Phase 3 CSP report audit verifier has parse errors"
}
$cspVerifierSource = Get-Content -Path "scripts\verify-phase3-csp-report-contract.ps1" -Raw
foreach ($required in @(
  "application/csp-report",
  "csp_report_too_large",
  "unsupported_csp_report_content_type",
  "must-not-persist",
  "security_csp_violation_reported",
  "csp_report_audit_persisted",
  "proof_scope=DEV-ONLY",
  "use -ReadOnly for non-local targets"
)) {
  if (-not $cspVerifierSource.Contains($required)) {
    throw "Phase 3 CSP report audit verifier missing guard: $required"
  }
}
$cspDiagnosticsSource = Get-Content -Path "apps\frontend\app\diagnostics\page.tsx" -Raw
foreach ($required in @("CSP Report Contract", "/api/v1/security/csp/contract")) {
  if (-not $cspDiagnosticsSource.Contains($required)) {
    throw "Diagnostics CSP report surface missing guard: $required"
  }
}
if (-not (Test-Path "apps\frontend\e2e\phase3-csp-report.spec.ts")) {
  throw "Missing Phase 3 CSP report browser click proof"
}
$cspBrowserProof = Get-Content -Path "apps\frontend\e2e\phase3-csp-report.spec.ts" -Raw
foreach ($required in @("/diagnostics", "selectOption", "live-console-load", "200 OK", "csp_report_contract_visible", "csp_report_audit_persisted")) {
  if (-not $cspBrowserProof.Contains($required)) {
    throw "Phase 3 CSP report browser click proof missing guard: $required"
  }
}
if (-not (Test-Path "docs\runtime-contracts\security-csrf-origin-guard.md")) { throw "Missing Phase 3 CSRF origin guard document" }
$csrfOriginDoc = Get-Content -Path "docs\runtime-contracts\security-csrf-origin-guard.md" -Raw
foreach ($required in @("csrf-origin-guard-v1","csrf_origin_guard_visible","csrf_origin_rejection_audited","security_csrf_request_rejected","/api/v1/security/csrf/probe","Raw Origin values","DEV-ONLY")) {
  if (-not $csrfOriginDoc.Contains($required)) { throw "CSRF origin guard document missing: $required" }
}
if (-not (Test-Path "scripts\verify-phase3-csrf-origin-guard.ps1")) { throw "Missing Phase 3 CSRF origin verifier" }
$csrfOriginParseErrors=$null
[System.Management.Automation.Language.Parser]::ParseFile("scripts\verify-phase3-csrf-origin-guard.ps1",[ref]$null,[ref]$csrfOriginParseErrors)|Out-Null
if($csrfOriginParseErrors){$csrfOriginParseErrors|ForEach-Object{Write-Error $_.Message};throw "CSRF origin verifier parse errors"}
$csrfOriginVerifier=Get-Content -Path "scripts\verify-phase3-csrf-origin-guard.ps1" -Raw
foreach($required in @("manifest phase3 at least 42","fetch_metadata_cross_site","invalid_or_null_origin","origin_mismatch","diagnostics-csrf-origin-guard.png","raw attacker origin absent")) {
  if(-not $csrfOriginVerifier.Contains($required)){throw "CSRF origin verifier missing: $required"}
}
foreach($required in @("CSRF Origin Guard","/api/v1/security/csrf/contract")){if(-not $cspDiagnosticsSource.Contains($required)){throw "Diagnostics CSRF surface missing: $required"}}
if(-not(Test-Path "apps\frontend\e2e\phase3-csrf-origin.spec.ts")){throw "Missing Phase 3 CSRF browser click proof"}
$csrfOriginBrowser=Get-Content -Path "apps\frontend\e2e\phase3-csrf-origin.spec.ts" -Raw
foreach($required in @("/diagnostics","selectOption","same-origin browser POST","csrf_origin_guard_visible","x-superbrain-csrf-contract")){if(-not $csrfOriginBrowser.Contains($required)){throw "CSRF browser proof missing: $required"}}
if (-not (Test-Path "docs\runtime-contracts\security-cross-origin-response-guard.md")) { throw "Missing Phase 3 cross-origin response guard document" }
$crossOriginDoc = Get-Content -Path "docs\runtime-contracts\security-cross-origin-response-guard.md" -Raw
foreach ($required in @("cross-origin-response-guard-v1", "cross_origin_response_guard_visible", "Cross-Origin-Opener-Policy", "reflected attacker origins", "DEV-ONLY")) {
  if (-not $crossOriginDoc.Contains($required)) { throw "Cross-origin response guard document missing: $required" }
}
if (-not (Test-Path "scripts\verify-phase3-cross-origin-response-guard.ps1")) { throw "Missing Phase 3 cross-origin response verifier" }
$crossOriginParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile("scripts\verify-phase3-cross-origin-response-guard.ps1", [ref]$null, [ref]$crossOriginParseErrors) | Out-Null
if ($crossOriginParseErrors) { $crossOriginParseErrors | ForEach-Object { Write-Error $_.Message }; throw "Cross-origin response verifier parse errors" }
$crossOriginVerifier = Get-Content -Path "scripts\verify-phase3-cross-origin-response-guard.ps1" -Raw
foreach ($required in @("manifest phase3 at least 43", "attacker origin not reflected", "diagnostics-cross-origin-response-guard.png", "cross-origin-resource-policy: same-origin")) {
  if (-not $crossOriginVerifier.Contains($required)) { throw "Cross-origin response verifier missing: $required" }
}
foreach ($required in @("Cross-Origin Response Guard", "/api/v1/security/cross-origin/contract")) {
  if (-not $cspDiagnosticsSource.Contains($required)) { throw "Diagnostics cross-origin surface missing: $required" }
}
if (-not (Test-Path "apps\frontend\e2e\phase3-cross-origin-response.spec.ts")) { throw "Missing Phase 3 cross-origin browser click proof" }
$crossOriginBrowser = Get-Content -Path "apps\frontend\e2e\phase3-cross-origin-response.spec.ts" -Raw
foreach ($required in @("/diagnostics", "selectOption", "real click", "cross-origin-response-guard-v1", "attacker_origin_reflected")) {
  if (-not $crossOriginBrowser.Contains($required)) { throw "Cross-origin browser proof missing: $required" }
}
if (-not (Test-Path "docs\runtime-contracts\auth-session-integrity.md")) { throw "Missing Phase 3 auth-session integrity document" }
$authSessionDoc = Get-Content -Path "docs\runtime-contracts\auth-session-integrity.md" -Raw
foreach ($required in @("auth-session-integrity-v1", "HMAC-SHA256", "AUTH_SESSION_SECRET", "DEV-ONLY")) {
  if (-not $authSessionDoc.Contains($required)) { throw "Auth-session integrity document missing: $required" }
}
if (-not (Test-Path "scripts\verify-phase3-auth-session-integrity.ps1")) { throw "Missing Phase 3 auth-session integrity verifier" }
$authSessionParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile("scripts\verify-phase3-auth-session-integrity.ps1", [ref]$null, [ref]$authSessionParseErrors) | Out-Null
if ($authSessionParseErrors) { $authSessionParseErrors | ForEach-Object { Write-Error $_.Message }; throw "Auth-session integrity verifier parse errors" }
$authSessionVerifier = Get-Content -Path "scripts\verify-phase3-auth-session-integrity.ps1" -Raw
foreach ($required in @("deterministic token unit tests", "tampered_cookie_rejected", "unsupported_provider_rejected", "login-auth-session-integrity.png")) {
  if (-not $authSessionVerifier.Contains($required)) { throw "Auth-session integrity verifier missing: $required" }
}
if (-not (Test-Path "scripts\verify-auth-session-http.mjs")) { throw "Missing auth-session token-safe HTTP probe" }
$authSessionHttpProbe = Get-Content -Path "scripts\verify-auth-session-http.mjs" -Raw
foreach ($required in @("valid_cookie_accepted", "tampered_cookie_rejected", "unsupported_provider_rejected", "token_output")) {
  if (-not $authSessionHttpProbe.Contains($required)) { throw "Auth-session HTTP probe missing: $required" }
}
$authSessionHelper = Get-Content -Path "apps\frontend\lib\authSession.ts" -Raw
foreach ($required in @("createHmac", "timingSafeEqual", "AUTH_SESSION_TTL_SECONDS", "verifySignedAuthSession")) {
  if (-not $authSessionHelper.Contains($required)) { throw "Auth-session integrity helper missing: $required" }
}
$authSessionRoute = Get-Content -Path "apps\frontend\app\api\v1\auth\session\route.ts" -Raw
foreach ($required in @("AUTH_SESSION_COOKIE", "external_provider_write: false", "jar.delete(AUTH_SESSION_COOKIE)")) {
  if (-not $authSessionRoute.Contains($required)) { throw "Auth-session route missing: $required" }
}
if ($authSessionRoute.Contains("ghStore")) { throw "Auth-session route must not contain a GitHub write path" }
if (-not (Test-Path "apps\frontend\e2e\phase3-auth-session-integrity.spec.ts")) { throw "Missing auth-session Chromium proof" }
$authSessionBrowser = Get-Content -Path "apps\frontend\e2e\phase3-auth-session-integrity.spec.ts" -Raw
foreach ($required in @("signed session", "tampered cookie", "session_invalidated", "external_provider_write")) {
  if (-not $authSessionBrowser.Contains($required)) { throw "Auth-session Chromium proof missing: $required" }
}
if (-not (Test-Path "docs\runtime-contracts\phase6-3d-camera-lighting-runtime.md")) {
  throw "Missing Phase 6 3D camera and lighting contract document"
}
$phase6CameraLightingDoc = Get-Content -Path "docs\runtime-contracts\phase6-3d-camera-lighting-runtime.md" -Raw
foreach ($required in @(
  "phase6-3d-camera-lighting-runtime-v1",
  "phase6_3d_camera_lighting_runtime_visible",
  "/api/v1/phase6/3d-camera-lighting/contract",
  "camera_preset_switch_visible",
  "fov_step_control_visible",
  "lighting_profile_switch_visible",
  "safe_exposure_bounds_visible",
  "local_camera_lighting_state_only",
  'Phase 6 to move from `32%` to `40%`',
  "DEV-ONLY",
  "No shader hotload"
)) {
  if (-not $phase6CameraLightingDoc.Contains($required)) {
    throw "Phase 6 camera and lighting document missing guard: $required"
  }
}
if (-not (Test-Path "scripts\verify-phase6-3d-camera-lighting-runtime.ps1")) {
  throw "Missing Phase 6 camera and lighting verifier"
}
$phase6CameraLightingParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\verify-phase6-3d-camera-lighting-runtime.ps1",
  [ref]$null,
  [ref]$phase6CameraLightingParseErrors
) | Out-Null
if ($phase6CameraLightingParseErrors -and $phase6CameraLightingParseErrors.Count -gt 0) {
  $phase6CameraLightingParseErrors | ForEach-Object { Write-Error $_.Message }
  throw "Phase 6 camera and lighting verifier has parse errors"
}
$phase6CameraLightingVerifier = Get-Content -Path "scripts\verify-phase6-3d-camera-lighting-runtime.ps1" -Raw
foreach ($required in @(
  "phase6-3d-camera-lighting-runtime-v1",
  "camera_preset_switch_visible",
  "lighting_profile_switch_visible",
  "safe exposure min",
  "manifest phase6 40",
  "Phase-6 camera and lighting controls",
  "phase6-camera-lighting.png"
)) {
  if (-not $phase6CameraLightingVerifier.Contains($required)) {
    throw "Phase 6 camera and lighting verifier missing guard: $required"
  }
}
if (-not (Test-Path "docs\runtime-contracts\phase6-3d-gameplay-state-runtime.md")) {
  throw "Missing Phase 6 3D gameplay state contract document"
}
$phase6GameplayStateDoc = Get-Content -Path "docs\runtime-contracts\phase6-3d-gameplay-state-runtime.md" -Raw
foreach ($required in @(
  "phase6-3d-gameplay-state-runtime-v1",
  "phase6_3d_gameplay_state_runtime_visible",
  "/api/v1/phase6/3d-gameplay-state/contract",
  "objective_state_overlay_visible",
  "deterministic_gameplay_state_machine",
  "pause_safe_game_loop_state",
  'Phase 6 may move from `40%` to `48%`',
  "DEV-ONLY",
  "No multiplayer or netcode"
)) {
  if (-not $phase6GameplayStateDoc.Contains($required)) {
    throw "Phase 6 gameplay state document missing guard: $required"
  }
}
if (-not (Test-Path "scripts\verify-phase6-3d-gameplay-state-runtime.ps1")) {
  throw "Missing Phase 6 gameplay state verifier"
}
$phase6GameplayStateParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\verify-phase6-3d-gameplay-state-runtime.ps1",
  [ref]$null,
  [ref]$phase6GameplayStateParseErrors
) | Out-Null
if ($phase6GameplayStateParseErrors -and $phase6GameplayStateParseErrors.Count -gt 0) {
  $phase6GameplayStateParseErrors | ForEach-Object { Write-Error $_.Message }
  throw "Phase 6 gameplay state verifier has parse errors"
}
$phase6GameplayStateVerifier = Get-Content -Path "scripts\verify-phase6-3d-gameplay-state-runtime.ps1" -Raw
foreach ($required in @(
  "phase6-3d-gameplay-state-runtime-v1",
  "deterministic_gameplay_state_machine",
  "pause_safe_game_loop_state",
  "manifest phase6 48",
  "Phase-6 gameplay state is deterministic",
  "phase6-gameplay-state.png"
)) {
  if (-not $phase6GameplayStateVerifier.Contains($required)) {
    throw "Phase 6 gameplay state verifier missing guard: $required"
  }
}
if (-not (Test-Path "docs\runtime-contracts\phase6-3d-asset-policy-runtime.md")) {
  throw "Missing Phase 6 3D asset policy contract document"
}
$phase6AssetPolicyDoc = Get-Content -Path "docs\runtime-contracts\phase6-3d-asset-policy-runtime.md" -Raw
foreach ($required in @(
  "phase6-3d-asset-policy-runtime-v1",
  "phase6_3d_asset_policy_runtime_visible",
  "/api/v1/phase6/3d-asset-policy/contract",
  "procedural_asset_catalog_visible",
  "asset_profile_switch_visible",
  "material_policy_variant_visible",
  'Phase 6 may move from `48%` to `56%`',
  "DEV-ONLY",
  "No external asset fetch"
)) {
  if (-not $phase6AssetPolicyDoc.Contains($required)) {
    throw "Phase 6 asset policy document missing guard: $required"
  }
}
if (-not (Test-Path "scripts\verify-phase6-3d-asset-policy-runtime.ps1")) {
  throw "Missing Phase 6 asset policy verifier"
}
$phase6AssetPolicyParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\verify-phase6-3d-asset-policy-runtime.ps1",
  [ref]$null,
  [ref]$phase6AssetPolicyParseErrors
) | Out-Null
if ($phase6AssetPolicyParseErrors -and $phase6AssetPolicyParseErrors.Count -gt 0) {
  $phase6AssetPolicyParseErrors | ForEach-Object { Write-Error $_.Message }
  throw "Phase 6 asset policy verifier has parse errors"
}
$phase6AssetPolicyVerifier = Get-Content -Path "scripts\verify-phase6-3d-asset-policy-runtime.ps1" -Raw
foreach ($required in @(
  "phase6-3d-asset-policy-runtime-v1",
  "procedural_asset_catalog_visible",
  "external_asset_fetch_blocked",
  "manifest phase6 56",
  "Phase-6 asset policy applies procedural profiles",
  "phase6-asset-policy.png"
)) {
  if (-not $phase6AssetPolicyVerifier.Contains($required)) {
    throw "Phase 6 asset policy verifier missing guard: $required"
  }
}
if (-not (Test-Path "docs\runtime-contracts\phase6-3d-save-load-runtime.md")) {
  throw "Missing Phase 6 3D save and load contract document"
}
$phase6SaveLoadDoc = Get-Content -Path "docs\runtime-contracts\phase6-3d-save-load-runtime.md" -Raw
foreach ($required in @(
  "phase6-3d-save-load-runtime-v1",
  "phase6_3d_save_load_runtime_visible",
  "/api/v1/phase6/3d-save-load/contract",
  "scene_snapshot_capture_visible",
  "scene_snapshot_restore_visible",
  "persistent_browser_storage_blocked",
  'Phase 6 may move from `56%` to `64%`',
  "DEV-ONLY",
  "No persistent browser storage"
)) {
  if (-not $phase6SaveLoadDoc.Contains($required)) {
    throw "Phase 6 save and load document missing guard: $required"
  }
}
if (-not (Test-Path "scripts\verify-phase6-3d-save-load-runtime.ps1")) {
  throw "Missing Phase 6 save and load verifier"
}
$phase6SaveLoadParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\verify-phase6-3d-save-load-runtime.ps1",
  [ref]$null,
  [ref]$phase6SaveLoadParseErrors
) | Out-Null
if ($phase6SaveLoadParseErrors -and $phase6SaveLoadParseErrors.Count -gt 0) {
  $phase6SaveLoadParseErrors | ForEach-Object { Write-Error $_.Message }
  throw "Phase 6 save and load verifier has parse errors"
}
$phase6SaveLoadVerifier = Get-Content -Path "scripts\verify-phase6-3d-save-load-runtime.ps1" -Raw
foreach ($required in @(
  "phase6-3d-save-load-runtime-v1",
  "scene_snapshot_restore_visible",
  "persistent_browser_storage_blocked",
  "manifest phase6 64",
  "Phase-6 save and load restores",
  "phase6-save-load.png"
)) {
  if (-not $phase6SaveLoadVerifier.Contains($required)) {
    throw "Phase 6 save and load verifier missing guard: $required"
  }
}
$phase6OrganismView = Get-Content -Path "apps\frontend\components\organism\OrganismView.tsx" -Raw
$phase6FallbackSource = Get-Content -Path "apps\frontend\components\organism\CortexCanvas.tsx" -Raw
$phase6CanvasSource = Get-Content -Path "apps\frontend\components\organism\CortexCanvas3D.tsx" -Raw
$phase6OrganismTest = Get-Content -Path "apps\frontend\e2e\organism.spec.ts" -Raw
foreach ($required in @("phase6-camera-lighting-controls", 'id: "top"', 'id: "sunrise"', 'phase6-camera-preset-${preset.id}', 'phase6-lighting-profile-${profile.id}', "phase6-camera-fov", "phase6-lighting-exposure", "local_state_only=true")) {
  if (-not $phase6OrganismView.Contains($required)) {
    throw "Phase 6 camera and lighting UI missing guard: $required"
  }
}
foreach ($required in @("PerspectiveCamera", "ACESFilmicToneMapping", "data-camera-position", "data-tone-exposure", "CAMERA_PRESETS", "LIGHTING_PROFILES")) {
  if (-not $phase6CanvasSource.Contains($required)) {
    throw "Phase 6 camera and lighting Three.js source missing guard: $required"
  }
}
foreach ($required in @("Phase-6 camera and lighting controls", "0.72", "1.18", "browser-local", "phase6-camera-lighting.png")) {
  if (-not $phase6OrganismTest.Contains($required)) {
    throw "Phase 6 camera and lighting browser proof missing guard: $required"
  }
}
foreach ($required in @("phase6-gameplay-state-controls", "GAMEPLAY_OBJECTIVES", "completeGameplayObjective", "KeyG", "gameplayTicks", "local_state_only=true")) {
  if (-not $phase6OrganismView.Contains($required)) {
    throw "Phase 6 gameplay state UI missing guard: $required"
  }
}
foreach ($required in @("GAMEPLAY_BEACONS", "GameplayBeacon", "data-gameplay-objective", "data-gameplay-paused", "data-gameplay-local-only")) {
  if (-not $phase6CanvasSource.Contains($required)) {
    throw "Phase 6 gameplay state Three.js source missing guard: $required"
  }
}
foreach ($required in @("Phase-6 gameplay state is deterministic", "data-gameplay-ticks", "gameplay controls remain browser-local", "phase6-gameplay-state.png")) {
  if (-not $phase6OrganismTest.Contains($required)) {
    throw "Phase 6 gameplay state browser proof missing guard: $required"
  }
}
foreach ($required in @("phase6-asset-policy-controls", "ASSET_PROFILES", "MATERIAL_VARIANTS", "selectAssetProfile", "selectMaterialVariant", "remote_assets=0", "binary_upload=false")) {
  if (-not $phase6OrganismView.Contains($required)) {
    throw "Phase 6 asset policy UI missing guard: $required"
  }
}
foreach ($required in @("AssetPolicyPreview", "boxGeometry", "coneGeometry", "torusGeometry", "data-asset-profile", "data-binary-asset-upload", "data-asset-policy-local-only")) {
  if (-not $phase6CanvasSource.Contains($required)) {
    throw "Phase 6 asset policy Three.js source missing guard: $required"
  }
}
foreach ($required in @("Phase-6 asset policy applies procedural profiles", "data-remote-asset-count", "asset policy controls remain browser-local", "phase6-asset-policy.png")) {
  if (-not $phase6OrganismTest.Contains($required)) {
    throw "Phase 6 asset policy browser proof missing guard: $required"
  }
}
foreach ($required in @("phase6-save-load-controls", "Phase6SceneSnapshot", "savedSnapshot", "saveSceneSnapshot", "loadSceneSnapshot", "clearSceneSnapshot", "storage=react_state", "reload_persistence=false")) {
  if (-not $phase6OrganismView.Contains($required)) {
    throw "Phase 6 save and load UI missing guard: $required"
  }
}
foreach ($required in @("Phase-6 save and load restores", "snapshot_status=restored", "save load controls remain browser-local", "phase6-save-load.png")) {
  if (-not $phase6OrganismTest.Contains($required)) {
    throw "Phase 6 save and load browser proof missing guard: $required"
  }
}
if (-not (Test-Path "docs\runtime-contracts\phase6-3d-accessibility-runtime.md")) { throw "Missing Phase 6 accessibility document" }
$phase6AccessibilityDoc = Get-Content "docs\runtime-contracts\phase6-3d-accessibility-runtime.md" -Raw
foreach ($required in @("phase6-3d-accessibility-runtime-v1","phase6_3d_accessibility_runtime_visible",'Phase 6 may move from `64%` to `72%`',"DEV-ONLY")) { if(-not $phase6AccessibilityDoc.Contains($required)){throw "Accessibility document missing: $required"} }
if (-not (Test-Path "scripts\verify-phase6-3d-accessibility-runtime.ps1")) { throw "Missing Phase 6 accessibility verifier" }
$phase6AccessibilityParseErrors=$null; [Management.Automation.Language.Parser]::ParseFile("scripts\verify-phase6-3d-accessibility-runtime.ps1",[ref]$null,[ref]$phase6AccessibilityParseErrors)|Out-Null
if($phase6AccessibilityParseErrors){$phase6AccessibilityParseErrors|%{Write-Error $_.Message};throw "Accessibility verifier parse errors"}
$phase6AccessibilityVerifier=Get-Content "scripts\verify-phase6-3d-accessibility-runtime.ps1" -Raw
foreach($required in @("manifest phase6 minimum 72","Phase-6 accessibility honors","phase6-accessibility.png")){if(-not $phase6AccessibilityVerifier.Contains($required)){throw "Accessibility verifier missing: $required"}}
foreach($required in @("phase6-accessibility-controls","systemReducedMotion","focusCortexSurface",'role="status"')){if(-not $phase6OrganismView.Contains($required)){throw "Accessibility UI missing: $required"}}
foreach($required in @("phase6-reduced-motion-fallback","handleFallbackKeyDown","aria-current")){if(-not $phase6FallbackSource.Contains($required)){throw "Accessibility fallback missing: $required"}}
foreach($required in @("Phase-6 accessibility honors",'reducedMotion: "reduce"',"accessibility controls remain browser-local")){if(-not $phase6OrganismTest.Contains($required)){throw "Accessibility test missing: $required"}}
if (-not (Test-Path "docs\runtime-contracts\phase6-3d-netcode-loopback-runtime.md")) { throw "Missing Phase 6 netcode loopback document" }
$phase6NetcodeDoc = Get-Content "docs\runtime-contracts\phase6-3d-netcode-loopback-runtime.md" -Raw
foreach ($required in @("phase6-3d-netcode-loopback-runtime-v1","phase6_3d_netcode_loopback_runtime_visible",'Phase 6 may move from `72%` to `80%`',"WebSocket","server-authoritative","DEV-ONLY")) { if(-not $phase6NetcodeDoc.Contains($required)){throw "Netcode loopback document missing: $required"} }
if (-not (Test-Path "scripts\verify-phase6-3d-netcode-loopback-runtime.ps1")) { throw "Missing Phase 6 netcode loopback verifier" }
$phase6NetcodeParseErrors=$null; [Management.Automation.Language.Parser]::ParseFile("scripts\verify-phase6-3d-netcode-loopback-runtime.ps1",[ref]$null,[ref]$phase6NetcodeParseErrors)|Out-Null
if($phase6NetcodeParseErrors){$phase6NetcodeParseErrors|%{Write-Error $_.Message};throw "Netcode loopback verifier parse errors"}
$phase6NetcodeVerifier=Get-Content "scripts\verify-phase6-3d-netcode-loopback-runtime.ps1" -Raw
foreach($required in @("manifest phase6 minimum 80","manifest overall minimum 82","Phase-6 netcode loopback enforces","phase6-netcode-loopback.png")){if(-not $phase6NetcodeVerifier.Contains($required)){throw "Netcode loopback verifier missing: $required"}}
foreach($required in @("phase6-netcode-controls","netcodeSessionActive","startLoopbackLockstep","advanceLoopbackTick","websocket=false","server_sync=false")){if(-not $phase6OrganismView.Contains($required)){throw "Netcode loopback UI missing: $required"}}
foreach($required in @("function LoopbackPeer","data-netcode-transport","data-netcode-guest-connected","data-netcode-sequence","data-netcode-websocket")){if(-not $phase6CanvasSource.Contains($required)){throw "Netcode loopback Three.js source missing: $required"}}
foreach($required in @("Phase-6 netcode loopback enforces","packets=5","sequence=5","phase6-netcode-loopback.png","websocket_allowed")){if(-not $phase6OrganismTest.Contains($required)){throw "Netcode loopback test missing: $required"}}
if (-not (Test-Path "docs\runtime-contracts\phase6-local-scoreboard-performance-runtime.md")) { throw "Missing Phase 6 local scoreboard/performance document" }
$phase6ScoreboardDoc = Get-Content "docs\runtime-contracts\phase6-local-scoreboard-performance-runtime.md" -Raw
foreach ($required in @("phase6-local-scoreboard-performance-runtime-v1","phase6_local_scoreboard_performance_runtime_visible",'Phase 6 may move from `80%` to `90%`',"twelve-sample","DEV-ONLY")) { if(-not $phase6ScoreboardDoc.Contains($required)){throw "Local scoreboard/performance document missing: $required"} }
if (-not (Test-Path "scripts\verify-phase6-local-scoreboard-performance-runtime.ps1")) { throw "Missing Phase 6 local scoreboard/performance verifier" }
$phase6ScoreboardParseErrors=$null; [Management.Automation.Language.Parser]::ParseFile("scripts\verify-phase6-local-scoreboard-performance-runtime.ps1",[ref]$null,[ref]$phase6ScoreboardParseErrors)|Out-Null
if($phase6ScoreboardParseErrors){$phase6ScoreboardParseErrors|%{Write-Error $_.Message};throw "Local scoreboard/performance verifier parse errors"}
$phase6ScoreboardVerifier=Get-Content "scripts\verify-phase6-local-scoreboard-performance-runtime.ps1" -Raw
foreach($required in @("manifest phase6 90","manifest overall equals rounded horizontal phase average","MidpointRounding","Phase-6 local scoreboard and performance sample stay browser-local","phase6-local-scoreboard-performance.png")){if(-not $phase6ScoreboardVerifier.Contains($required)){throw "Local scoreboard/performance verifier missing: $required"}}
foreach($required in @("phase6-scoreboard-performance-controls","phase6-leaderboard-capture","phase6-leaderboard-reset","phase6-performance-start","local_only=true","sync=false","storage=false","network=false")){if(-not $phase6OrganismView.Contains($required)){throw "Local scoreboard/performance UI missing: $required"}}
foreach($required in @("Phase-6 local scoreboard and performance sample stay browser-local","phase6-local-scoreboard-performance.png","localStorage","indexedDB")){if(-not $phase6OrganismTest.Contains($required)){throw "Local scoreboard/performance test missing: $required"}}

if (-not (Test-Path "docs\runtime-contracts\orchestrator-completion-evidence.md")) { throw "Missing Orchestrator completion evidence document" }
$orchestratorCompletionDoc = Get-Content "docs\runtime-contracts\orchestrator-completion-evidence.md" -Raw
foreach ($required in @("orchestrator-completion-evidence-v1","orchestrator_completion_evidence_verified","99%","100%","MCP timeout","DEV-ONLY")) { if(-not $orchestratorCompletionDoc.Contains($required)){throw "Orchestrator completion document missing: $required"} }
if (-not (Test-Path "scripts\verify-orchestrator-completion-evidence.ps1")) { throw "Missing Orchestrator completion evidence verifier" }
$orchestratorCompletionParseErrors=$null; [Management.Automation.Language.Parser]::ParseFile("scripts\verify-orchestrator-completion-evidence.ps1",[ref]$null,[ref]$orchestratorCompletionParseErrors)|Out-Null
if($orchestratorCompletionParseErrors){$orchestratorCompletionParseErrors|%{Write-Error $_.Message};throw "Orchestrator completion verifier parse errors"}
$orchestratorCompletionVerifier=Get-Content "scripts\verify-orchestrator-completion-evidence.ps1" -Raw
foreach($required in @("manifest orchestrator 100","deterministic four-role success","policy hard-stop","controlled MCP timeout","Chromium diagnostics click","diagnostics-orchestrator-completion-evidence.png","parent_sse_replay_and_restart_recovery")){if(-not $orchestratorCompletionVerifier.Contains($required)){throw "Orchestrator completion verifier missing: $required"}}
$orchestratorCompletionTest=Get-Content "apps\frontend\e2e\orchestrator-completion.spec.ts" -Raw
foreach($required in @("diagnostics loads orchestrator completion evidence through a real click","orchestrator-completion-evidence-v1","layer_progress_after_proof","diagnostics-orchestrator-completion-evidence.png")){if(-not $orchestratorCompletionTest.Contains($required)){throw "Orchestrator completion browser test missing: $required"}}
$diagnosticsPage=Get-Content "apps\frontend\app\diagnostics\page.tsx" -Raw
foreach($required in @("Orchestrator Completion Evidence","/api/v1/orchestrator/completion/contract")){if(-not $diagnosticsPage.Contains($required)){throw "Diagnostics Orchestrator completion wiring missing: $required"}}

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
foreach ($required in @("Apply and verify default branch protection", "BRANCH_PROTECTION_TOKEN", "BRANCH_NAME", "python scripts/apply_github_branch_protection.py --apply --branch")) {
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
foreach ($service in @("agent-api", "agent-worker", "memory-worker", "mcp-gateway", "llm-gateway")) {
  $rootContextPattern = "(?ms)- name: $([regex]::Escape($service))\s+context: \.\s+dockerfile: services/$([regex]::Escape($service))/Dockerfile"
  if ($mainDeployWorkflow -notmatch $rootContextPattern) {
    throw "main-deploy workflow must build $service from repository-root context"
  }
}
if ($mainDeployWorkflow -notmatch '(?ms)- name: frontend\s+context: apps/frontend\s+dockerfile: apps/frontend/Dockerfile') {
  throw "main-deploy workflow must build frontend from apps/frontend context"
}
$infraCostWorkflow = Get-Content -Path ".github\workflows\infra-cost-check.yml" -Raw
foreach ($required in @("CLOUDFLARE_PROJECTED_MONTHLY_EUR", "Cloudflare zero-card target must remain EUR 0.00", "paid fallback is forbidden")) {
  if (-not $infraCostWorkflow.Contains($required)) {
    throw "Infra cost workflow missing Cloudflare zero-card guard: $required"
  }
}
foreach ($forbidden in @("FLY_PROJECTED_MONTHLY_EUR", '"Fly.io":')) {
  if ($infraCostWorkflow.Contains($forbidden)) {
    throw "Infra cost workflow still contains active Fly budget input: $forbidden"
  }
}
$budgetSource = Get-Content -Path "services\agent-api\app\budget.py" -Raw
foreach ($required in @("cloudflare-native-zero-card-hosted-runtime", "cloudflare_zero_card_projection", "allow_new_infra=False")) {
  if (-not $budgetSource.Contains($required)) {
    throw "Budget source missing fail-closed Cloudflare projection guard: $required"
  }
}
foreach ($forbidden in @("fly-production-shared-cpu", "fly-staging-shared-cpu", "fly_live_budget_items", "FLY_API_TOKEN")) {
  if ($budgetSource.Contains($forbidden)) {
    throw "Budget source still contains active Fly planning marker: $forbidden"
  }
}

Write-Host "[verify] external gate audit contract"
if (-not (Test-Path "scripts\verify-external-gates.ps1")) {
  throw "Missing external gate audit verifier"
}
if (-not (Test-Path "docs\runtime-contracts\external-gate-audit-contract.md")) {
  throw "Missing external gate audit contract document"
}
if (-not (Test-Path "scripts\verify-all-gates-with-tokens.ps1")) {
  throw "Missing private env external gate runner"
}
$externalGateAuditScript = Get-Content -Path "scripts\verify-external-gates.ps1" -Raw
foreach ($required in @("external-gate-audit-v2", "external-gate-summary-v2", "external_gate_audit_proof", "active_target_gate", "cloudflare_native_zero_card_hosted_runtime", "cloudflare_native_zero_card_hosted_runtime_claim_allowed", "Get-CloudflareNativeGateProbe", "DurableAuditPath", "docs\runtime-state\external-gate-audit-v2.json", "local_run_artifact", "hosted_staging_claim_allowed", "frontend_preview_claim_allowed", "production_deploy_claim_allowed", "Assert-HostedBaseUrlSafe", "External gate hosted proof requires HTTPS", "Test-RetiredHostedBaseUrl", "retired_provider_url", "network_classification", "elapsed_ms", "response_url", "failed_hosted_required_probe_ids", "failed_vercel_origin_probe_ids", "hosted_cloud_deployment_preflight", "cloud_deployment_preflight_visible", "ghcr_image_digest_verify", "ghcr_image_digest_proof", "Invoke-BoundedNativeCommand", "WaitForExit", "EXTERNAL_GATE_HTTP_TIMEOUT_MS", "EXTERNAL_GATE_GITLEAKS_TIMEOUT_SECONDS", "EXTERNAL_GATE_DOCKER_TIMEOUT_SECONDS", '"timeout"', "dockerExitCode", "vercel_backend_origin_required", "vercel_backend_origin_health", "hosted_agent_api_health", "hosted_agent_api_health_required", "cloud-provider-inventory-v1", "cloud_provider_inventory_visible", "cloud-layer-readiness-v1", "cloud_layer_readiness_visible", "github_branch_protection_verify", "canonical_gitleaks_scan", "root_health", "prefixed_health", "Join-OriginProbeUrl", "gitlab_identity_claim_allowed", "huggingface_identity_claim_allowed", "grafana_cloud_claim_allowed", "Invoke-RestMethod", "GITLAB_TOKEN", "HF_TOKEN", "GRAFANA_CLOUD_API_KEY", "Invoke-PublicBranchProtectionProbe", "public_anonymous_subset", "publicBackendOrigin", "cloud-superbrain-developer-platform.vercel.app", "historical_only", "percentage credit")) {
  if (-not $externalGateAuditScript.Contains($required)) {
    throw "External gate audit verifier missing guard: $required"
  }
}
if ($externalGateAuditScript -match '\$missing\s*\+=\s*["'']fly_live_budget_check["'']') {
  throw "External gate audit verifier must not keep fly_live_budget_check in the active missing gate set"
}
$privateGateRunner = Get-Content -Path "scripts\verify-all-gates-with-tokens.ps1" -Raw
foreach ($required in @("verify-external-gates.ps1", "CLOUDFLARE_STATEFUL_BASE_URL", "CLOUDFLARE_ACCOUNT_ID", "CLOUDFLARE_API_TOKEN")) {
  if (-not $privateGateRunner.Contains($required)) {
    throw "Private env external gate runner missing Cloudflare-native guard: $required"
  }
}
foreach ($forbiddenActiveFlyMarker in @("Convert-FlyAppNameToBaseUrl", "Get-FlyAppNameOrDefault", "FLY_APP_AGENT_API", "FLY_APP_MCP_GATEWAY", "FLY_APP_LLM_GATEWAY")) {
  if ($privateGateRunner.Contains($forbiddenActiveFlyMarker)) {
    throw "Private env external gate runner still contains active Fly derivation: $forbiddenActiveFlyMarker"
  }
}
$externalGateAuditDoc = Get-Content -Path "docs\runtime-contracts\external-gate-audit-contract.md" -Raw
foreach ($required in @("external-gate-audit-v2", "external-gate-summary-v2", "cloud-only-staging-proof-v1", "Frontend preview reachability is not hosted staging", "hosted_staging_claim_allowed", "production_deploy_claim_allowed", "cloudflare_native_zero_card_hosted_runtime", "CLOUDFLARE_STATEFUL_BASE_URL", "No secret values", "Optional GitLab identity", "Optional Hugging Face identity", "Optional grafana identity", "historical_only", "never the token")) {
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
foreach ($required in @("cloud-provider-inventory-v1", "cloud_provider_inventory_visible", "cloud-layer-readiness-v1", "cloud_layer_readiness_visible", "GET /api/v1/clouds", "GET /api/v1/clouds/layers", "Seven-Layer Mapping", "Cloud Layer Readiness", "No secret values", "Vercel Live Read", "Cloudflare Live Read", "GitHub Live Read", "GHCR Live Read", "Hugging Face Live Read", "GitLab Live Read", "Grafana Cloud Live Read", "Cloudflare-native stateful runtime", "historical_only", "CLOUDFLARE_STATEFUL_BASE_URL", "CLOUDFLARE_ACCOUNT_ID", "CLOUDFLARE_API_TOKEN", "VERCEL_TOKEN", "GITHUB_TOKEN", "GHCR_TOKEN", "HF_TOKEN", "GITLAB_TOKEN", "GRAFANA_CLOUD_API_KEY", "vercel_frontend", "ghcr_registry", "grafana_cloud")) {
  if (-not $cloudProviderInventoryDoc.Contains($required)) {
    throw "Cloud provider inventory contract document missing guard: $required"
  }
}
if (-not (Test-Path "docs\runtime-contracts\cloud-render-offload-contract.md")) {
  throw "Missing cloud render offload contract document"
}
$cloudRenderOffloadDoc = Get-Content -Path "docs\runtime-contracts\cloud-render-offload-contract.md" -Raw
foreach ($required in @("cloud-render-offload-v1", "cloud_render_offload_contract_visible", "GET /api/v1/clouds/render-offload/contract", "localhost_heavy_render_allowed", "STAGING_BASE_URL", "CLOUDFLARE_STATEFUL_BASE_URL", "CLOUDFLARE_ACCOUNT_ID", "CLOUDFLARE_API_TOKEN", "webgl_3d_rendering", "control_plane")) {
  if (-not $cloudRenderOffloadDoc.Contains($required)) {
    throw "Cloud render offload contract document missing guard: $required"
  }
}
if (-not (Test-Path "docs\runtime-contracts\cloud-deployment-preflight-contract.md")) {
  throw "Missing cloud deployment preflight contract document"
}
$cloudDeploymentPreflightDoc = Get-Content -Path "docs\runtime-contracts\cloud-deployment-preflight-contract.md" -Raw
foreach ($required in @("cloud-deployment-preflight-v1", "cloud_deployment_preflight_visible", "GET /api/v1/clouds/deployment-preflight/contract", "publish_ghcr_images", "cloudflare_native_zero_card_hosted_runtime", "CLOUDFLARE_STATEFUL_BASE_URL", "CLOUDFLARE_ACCOUNT_ID", "CLOUDFLARE_API_TOKEN", "workers_scripts_edit", "d1_edit", "durable_objects_edit", "queues_edit", "historical_only", "GITHUB_TOKEN", "GHCR_TOKEN", "BRANCH_PROTECTION_TOKEN", "cloud_deploy_claim_allowed", "production_deploy_claim_allowed", "manual_external_actions")) {
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

Write-Host "[verify] owner cloud gate activation guard"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-owner-cloud-gate-activation.ps1
Assert-LastExitCode "owner cloud gate activation guard"

Write-Host "[verify] owner Cloudflare token helper"
pwsh -NoProfile -File scripts\verify-owner-set-cloudflare-token.ps1
Assert-LastExitCode "owner Cloudflare token helper"

Write-Host "[verify] qualified Cloudflare token promotion"
pwsh -NoProfile -File scripts\verify-promote-cloudflare-token-candidate.ps1
Assert-LastExitCode "qualified Cloudflare token promotion"

Write-Host "[verify] Agent Research read-only source binding"
pwsh -NoProfile -File scripts\verify-agent-research-source-binding.ps1
Assert-LastExitCode "Agent Research read-only source binding"

Write-Host "[verify] retired Fly rollout paths fail closed"
$retiredRolloutScript = Get-Content -Path "scripts\owner-production-rollout.ps1" -Raw
foreach ($required in @("RETIRED_HISTORICAL_DO_NOT_EXECUTE", "owner-cloud-gate-activation.ps1", "PlanOnly")) {
  if (-not $retiredRolloutScript.Contains($required)) {
    throw "Retired production rollout script missing fail-closed marker: $required"
  }
}
foreach ($forbidden in @("FLY_API_TOKEN", "fly deploy", "gh workflow run", "vercel deploy")) {
  if ($retiredRolloutScript.Contains($forbidden)) {
    throw "Retired production rollout script still contains executable legacy path: $forbidden"
  }
}
$retiredTraePrompt = Get-Content -Path "TRAE_DEPLOY_PROMPT.md" -Raw
foreach ($required in @("RETIRED_HISTORICAL_DO_NOT_EXECUTE", "cloudflare_native_zero_card_hosted_runtime", "owner-cloud-gate-activation.ps1")) {
  if (-not $retiredTraePrompt.Contains($required)) {
    throw "Retired deployment prompt missing current gate marker: $required"
  }
}
foreach ($forbidden in @("fly deploy", "gh workflow run", "vercel deploy")) {
  if ($retiredTraePrompt.Contains($forbidden)) {
    throw "Retired deployment prompt still contains copyable legacy action: $forbidden"
  }
}
$ownerGoLiveChecklist = Get-Content -Path "docs\runbooks\OWNER_GO_LIVE_CHECKLIST.md" -Raw
foreach ($required in @("OWNER_BLOCKED_AUTONOMOUS_COMPLETE", "cloudflare_native_zero_card_hosted_runtime", "O2Core 4/4", "O5 1/1", "R2 is historical-only", "O6", "resolved_verified", "PlanOnly")) {
  if (-not $ownerGoLiveChecklist.Contains($required)) {
    throw "Owner go-live checklist missing current truth marker: $required"
  }
}
$gateOpeningAnalysis = Get-Content -Path "docs\audit\gate-opening-analysis.md" -Raw
foreach ($required in @("external-gate-audit-v2.json", "cloudflare_native_zero_card_hosted_runtime", "cloudflare-native-hosted-current.json", "FEEE5D40E14E547C9B8EB5903B993E61BC324E2C2CAD64ECF8C7DF3BA9049D0B", "github_branch_protection_current_verify", "ghcr_image_digest_verify", "O2Core 4/4", "O5 1/1", "historical_only", "production_deploy_claim_allowed=false")) {
  if (-not $gateOpeningAnalysis.Contains($required)) {
    throw "Gate-opening analysis missing current truth marker: $required"
  }
}
$toolingReadinessSource = Get-Content -Path "scripts\verify-tooling-readiness.ps1" -Raw
foreach ($required in @("fly_io_historical", "historical_only", "cloudflare-owner-scope-readiness-v1", "o2_prime_scope_ready", "CLOUDFLARE_STATEFUL_BASE_URL")) {
  if (-not $toolingReadinessSource.Contains($required)) {
    throw "Tooling readiness missing Cloudflare-native guard: $required"
  }
}
foreach ($forbidden in @("KnownFlyTokenPath", 'fetch("https://api.fly.io/graphql"', '"fly_io" @("FLY_API_TOKEN")')) {
  if ($toolingReadinessSource.Contains($forbidden)) {
    throw "Tooling readiness still contains active Fly readiness path: $forbidden"
  }
}

Write-Host "[verify] go-live readiness guard"
if (-not (Test-Path "scripts\verify-go-live-readiness.ps1")) {
  throw "Missing go-live readiness verifier"
}
$goLiveVerifier = Get-Content -Path "scripts\verify-go-live-readiness.ps1" -Raw
foreach ($required in @(
  "go-live-readiness-v1",
  "go-live-readiness-surface-v1",
  "external-gate-audit-v2",
  "external-gate-summary-v2",
  "cloudflare_native_zero_card_hosted_runtime",
  "cloudflare_native_zero_card_hosted_runtime_claim_allowed",
  "hosted_agent_api_contracts",
  "github_branch_protection_current_verify",
  "vercel_backend_origin_health",
  "STAGING_BASE_URL",
  "CLOUDFLARE_STATEFUL_BASE_URL",
  "CLOUDFLARE_ACCOUNT_ID",
  "CLOUDFLARE_API_TOKEN",
  "workers_scripts_edit",
  "d1_edit",
  "durable_objects_edit",
  "queues_edit",
  "BRANCH_PROTECTION_TOKEN",
  "AGENT_API_BASE_URL",
  "MCP_GATEWAY_BASE_URL",
  "LLM_GATEWAY_BASE_URL",
  "external_audit_missing_or_failed_gates",
  "production_deploy_claim_allowed",
  "Assert-NoSecretPattern",
  "AllowLocalhost"
)) {
  if (-not $goLiveVerifier.Contains($required)) {
    throw "Go-live readiness verifier missing guard: $required"
  }
}
$goLiveParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\verify-go-live-readiness.ps1",
  [ref]$null,
  [ref]$goLiveParseErrors
) | Out-Null
if ($goLiveParseErrors -and $goLiveParseErrors.Count -gt 0) {
  $goLiveParseErrors | ForEach-Object { Write-Error $_.Message }
  throw "Go-live readiness verifier has parse errors"
}
$goLiveAgentApi = Get-Content -Path "services\agent-api\app\main.py" -Raw
foreach ($required in @(
  "EXTERNAL_GATE_SUMMARY_PATH",
  "external_gate_summary_state",
  "external-gate-summary-v2",
  "cloudflare_native_runtime",
  "cloudflare_native_zero_card_hosted_runtime",
  "required_owner_scopes",
  "external_audit_summary_status",
  "external_audit_missing_or_failed_gates",
  "github_branch_protection_current_verify",
  "vercel_backend_origin_health"
)) {
  if (-not $goLiveAgentApi.Contains($required)) {
    throw "Go-live readiness Agent API missing guard: $required"
  }
}
if (-not (Test-Path "docs\runtime-state\external-gate-summary.json")) {
  throw "Missing sanitized external gate summary"
}
$externalGateSummary = Get-Content -Path "docs\runtime-state\external-gate-summary.json" -Raw
foreach ($required in @(
  "external-gate-summary-v2",
  "external-gate-audit-v2",
  "docs\\runtime-state\\external-gate-audit-v2.json",
  "cloudflare_native_zero_card_hosted_runtime",
  "hosted_agent_api_contracts",
  "github_branch_protection_current_verify",
  "vercel_backend_origin_health",
  "historical_only",
  "Probe snippets",
  "token values"
)) {
  if (-not $externalGateSummary.Contains($required)) {
    throw "Sanitized external gate summary missing guard: $required"
  }
}
foreach ($composePath in @("docker-compose.dev.yml", "docker-compose.cloud.yml")) {
  $composeWithSummary = Get-Content -Path $composePath -Raw
  foreach ($required in @("EXTERNAL_GATE_SUMMARY_PATH", "external-gate-summary.json", "docs/runtime-state/external-gate-summary.json")) {
    if (-not $composeWithSummary.Contains($required)) {
      throw "$composePath missing external gate summary mount/env: $required"
    }
  }
}

Write-Host "[verify] Superbrain go-live runbook guard"
if (-not (Test-Path "scripts\verify-superbrain-go-live-runbook.ps1")) {
  throw "Missing Superbrain go-live runbook verifier"
}
$goLiveRunbookParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\verify-superbrain-go-live-runbook.ps1",
  [ref]$null,
  [ref]$goLiveRunbookParseErrors
) | Out-Null
if ($goLiveRunbookParseErrors -and $goLiveRunbookParseErrors.Count -gt 0) {
  $goLiveRunbookParseErrors | ForEach-Object { Write-Error $_.Message }
  throw "Superbrain go-live runbook verifier has parse errors"
}
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-superbrain-go-live-runbook.ps1
Assert-LastExitCode "Superbrain go-live runbook guard"

Write-Host "[verify] retired hosted boundary guard"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-retired-hosted-boundary.ps1
Assert-LastExitCode "retired hosted boundary guard"

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
  "SeedMemoryConsolidation",
  "browser_contract_harness",
  "llm responses adapter contract",
  "verify-llm-responses-contract.ps1",
  "llm-responses-adapter-contract-v1",
  "live agent steering contract",
  "verify-live-agent-steering-contract.ps1",
  "live-agent-steering-v1",
  "/api/v1/memory/embedding-consistency/contract",
  "memory-embedding-consistency-v1",
  "memory_embedding_consistency_contract_visible",
  "/api/v1/project/progress/completion",
  "project-progress-100-percent-contract-v1",
  "project_progress_100_percent_gate_contract",
  "external-gate-summary-v2",
  "external-gate-audit-v2",
  "cloudflare_native_zero_card_hosted_runtime",
  "bounded O6 live LLM capability is open",
  "O6 is resolved and not Owner-required",
  "Layer 4 equal 100",
  "CSP report audit contract",
  "verify-phase3-csp-report-contract.ps1",
  "csp-report-contract-v1",
  "csp_report_audit_persisted",
  "CSRF origin guard contract",
  "verify-phase3-csrf-origin-guard.ps1",
  "csrf-origin-guard-v1",
  "csrf_origin_rejection_audited",
  "signed auth-session integrity",
  "verify-phase3-auth-session-integrity.ps1",
  "auth-session-integrity-v1",
  "auth_session_integrity_visible",
  "Phase 6 3D camera and lighting controls",
  "verify-phase6-3d-camera-lighting-runtime.ps1",
  "phase6-3d-camera-lighting-runtime-v1",
  "phase6_3d_camera_lighting_runtime_visible",
  "Phase 6 3D gameplay state controls",
  "verify-phase6-3d-gameplay-state-runtime.ps1",
  "phase6-3d-gameplay-state-runtime-v1",
  "phase6_3d_gameplay_state_runtime_visible",
  "Phase 6 3D asset policy controls",
  "verify-phase6-3d-asset-policy-runtime.ps1",
  "phase6-3d-asset-policy-runtime-v1",
  "phase6_3d_asset_policy_runtime_visible",
  "Phase 6 3D save and load controls",
  "verify-phase6-3d-save-load-runtime.ps1",
  "phase6-3d-save-load-runtime-v1",
  "phase6_3d_save_load_runtime_visible",
  "Phase 6 3D accessibility controls",
  "verify-phase6-3d-accessibility-runtime.ps1",
  "phase6-3d-accessibility-runtime-v1",
  "phase6_3d_accessibility_runtime_visible",
  "Phase 6 3D netcode loopback controls",
  "verify-phase6-3d-netcode-loopback-runtime.ps1",
  "phase6-3d-netcode-loopback-runtime-v1",
  "phase6_3d_netcode_loopback_runtime_visible",
  "Phase 6 local scoreboard and performance controls",
  "verify-phase6-local-scoreboard-performance-runtime.ps1",
  "phase6-local-scoreboard-performance-runtime-v1",
  "phase6_local_scoreboard_performance_runtime_visible",
  "orchestrator completion evidence",
  "verify-orchestrator-completion-evidence.ps1",
  "orchestrator-completion-evidence-v1",
  "orchestrator_completion_evidence_verified",
  '"can_set_all_to_100":false'
)) {
  if (-not $browserContractScript.Contains($required)) {
    throw "Browser contract verifier missing required guard: $required"
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

if (-not (Test-Path "docs\runbooks\fly-live-budget-proof-2026-06-08.md")) {
  throw "Missing historical Fly budget provenance document"
}
$flyBudgetProof = Get-Content -Path "docs\runbooks\fly-live-budget-proof-2026-06-08.md" -Raw
foreach ($required in @("historical_only", "external-gate-audit-v2", "Projected Fly.io monthly server cost", "token is not persisted")) {
  if (-not $flyBudgetProof.Contains($required)) {
    throw "Historical Fly budget provenance document missing guard: $required"
  }
}
if ($flyBudgetProof.Contains("Active infrastructure baseline: Vercel/Fly.io/GHCR/Grafana Cloud.")) {
  throw "Historical Fly budget provenance must not declare the active infrastructure baseline"
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

Write-Host "[verify] phase5 local production candidate contract"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-phase5-production-candidate-local.ps1 -StaticOnly -AllowNonCandidateHead
Assert-LastExitCode "phase5 local production candidate static contract"
$phase5LocalCandidateVerifier = Get-Content -Path "scripts\verify-phase5-production-candidate-local.ps1" -Raw
foreach ($required in @(
  'verification-runtime.json',
  'verification_scope',
  'runtime_without_browser',
  'full_with_browser',
  'AllowNonCandidateHead',
  'candidate runtime source matches HEAD',
  'progress_credit_claimed',
  'candidate_runtime_source_parity_verified'
)) {
  if (-not $phase5LocalCandidateVerifier.Contains($required)) {
    throw "Phase5 local candidate verifier missing artifact-isolation guard: $required"
  }
}
$currentReleaseCandidateVerifier = Get-Content -Path "scripts\verify-current-release-candidate.ps1" -Raw
foreach ($required in @(
  'docs\runtime-state\external-gate-summary.json',
  'docs\runtime-state\backend-hosted-current.json',
  '/api/v1/external-gates/mirror',
  'candidate_technical=true',
  'promotion_eligible=',
  'canonical_read_only_contract_origin',
  'read_only_contract_origin',
  'stateful_backend_verified',
  'production_release_claimed',
  'external_gates_snapshot_scope',
  'external_gates_deployment_snapshot_source_artifact',
  'embedded_at_source_commit',
  'active release candidate has committed runtime-source drift from HEAD',
  'backendState.overall_percent',
  'runtime_source_parity=true',
  'snapshot_stale='
)) {
  if (-not $currentReleaseCandidateVerifier.Contains($required)) {
    throw "Current release candidate verifier missing canonical gate classification: $required"
  }
}
$phase5ImmutableParityVerifier = Get-Content -Path "scripts\manual\verify-phase5-staging-immutable-parity.ps1" -Raw
foreach ($required in @(
  '"-StagingIp"',
  '"plan-only"',
  '"-StagingHostname"',
  '"plan-only.invalid"',
  '"-StagingBaseUrl"',
  '"https://plan-only.invalid"'
)) {
  if (-not $phase5ImmutableParityVerifier.Contains($required)) {
    throw "Phase5 immutable parity verifier missing isolated plan-only boundary: $required"
  }
}

Write-Host "[verify] market-ready hosted proof classification"
$marketReadyParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "scripts\verify-market-ready.ps1",
  [ref]$null,
  [ref]$marketReadyParseErrors
) | Out-Null
if ($marketReadyParseErrors -and $marketReadyParseErrors.Count -gt 0) {
  $marketReadyParseErrors | ForEach-Object { Write-Error $_.Message }
  throw "Market-ready verifier syntax failed"
}
$marketReadyScript = Get-Content -Path "scripts\verify-market-ready.ps1" -Raw
foreach ($required in @(
  'verify:frontend-hosted-current',
  'verify:backend-hosted-current',
  'verify:current-release-candidate',
  'requires owner-gated stateful hosted runtime',
  '^B\d+-|owner[-_ ]gated|owner[-_ ]gate'
)) {
  if (-not $marketReadyScript.Contains($required)) {
    throw "Market-ready verifier missing current gate guard: $required"
  }
}

Write-Host "[verify] current hosted MCP read-only verifier"
if (-not (Test-Path "scripts\verify-mcp-hosted-current-readonly.ps1")) { throw "Missing current hosted MCP read-only verifier" }
$hostedMcpReadOnlyParseErrors = $null
[Management.Automation.Language.Parser]::ParseFile("scripts\verify-mcp-hosted-current-readonly.ps1", [ref]$null, [ref]$hostedMcpReadOnlyParseErrors) | Out-Null
if ($hostedMcpReadOnlyParseErrors) { $hostedMcpReadOnlyParseErrors | ForEach-Object { Write-Error $_.Message }; throw "Current hosted MCP read-only verifier parse errors" }
$hostedMcpReadOnlyVerifier = Get-Content "scripts\verify-mcp-hosted-current-readonly.ps1" -Raw
foreach ($required in @("mcp-hosted-current-readonly-v1", "mcp_current_hosted_readonly_contract_parity_verified", "/mcp/api/v1/version-pinning/contract", "/api/v1/audit/mcp/contract", "source-bound backend verification artifact exists", "token_used = `$false", "provider_write = `$false")) {
  if (-not $hostedMcpReadOnlyVerifier.Contains($required)) { throw "Current hosted MCP read-only verifier missing: $required" }
}
foreach ($forbidden in @("x-superbrain-agent-token", "-Method Post", "-Method Put", "-Method Patch", "-Method Delete", "Bearer ")) {
  if ($hostedMcpReadOnlyVerifier.Contains($forbidden)) { throw "Current hosted MCP read-only verifier contains write/auth marker: $forbidden" }
}

Write-Host "[verify] hosted Cloudflare LLM read-only verifier"
if (-not (Test-Path "scripts\verify-cloudflare-llm-gateway-hosted-readonly.ps1")) { throw "Missing hosted Cloudflare LLM read-only verifier" }
$hostedCloudflareLlmReadOnlyParseErrors = $null
[Management.Automation.Language.Parser]::ParseFile("scripts\verify-cloudflare-llm-gateway-hosted-readonly.ps1", [ref]$null, [ref]$hostedCloudflareLlmReadOnlyParseErrors) | Out-Null
if ($hostedCloudflareLlmReadOnlyParseErrors) { $hostedCloudflareLlmReadOnlyParseErrors | ForEach-Object { Write-Error $_.Message }; throw "Hosted Cloudflare LLM read-only verifier parse errors" }
$hostedCloudflareLlmReadOnlyVerifier = Get-Content "scripts\verify-cloudflare-llm-gateway-hosted-readonly.ps1" -Raw
foreach ($required in @("cloudflare-llm-gateway-hosted-readonly-v1", "cloudflare_workers_ai_llm_gateway_preview_readonly_source_parity_verified", "/api/v1/health", "/v1/models", "deployed source tree matches HEAD", "token_used = `$false", "inference_executed = `$false", "provider_write = `$false")) {
  if (-not $hostedCloudflareLlmReadOnlyVerifier.Contains($required)) { throw "Hosted Cloudflare LLM read-only verifier missing: $required" }
}
foreach ($forbidden in @("x-superbrain-gateway-token", "GATEWAY_AUTH_TOKEN", "-Method Post", "-Method Put", "-Method Patch", "-Method Delete", "Bearer ")) {
  if ($hostedCloudflareLlmReadOnlyVerifier.Contains($forbidden)) { throw "Hosted Cloudflare LLM read-only verifier contains write/auth marker: $forbidden" }
}

Write-Host "[verify] hosted Agent Pool read-only verifier"
if (-not (Test-Path "scripts\verify-agent-pool-hosted-readonly.ps1")) { throw "Missing hosted Agent Pool read-only verifier" }
$hostedAgentPoolReadOnlyParseErrors = $null
[Management.Automation.Language.Parser]::ParseFile("scripts\verify-agent-pool-hosted-readonly.ps1", [ref]$null, [ref]$hostedAgentPoolReadOnlyParseErrors) | Out-Null
if ($hostedAgentPoolReadOnlyParseErrors) { $hostedAgentPoolReadOnlyParseErrors | ForEach-Object { Write-Error $_.Message }; throw "Hosted Agent Pool read-only verifier parse errors" }
$hostedAgentPoolReadOnlyVerifier = Get-Content "scripts\verify-agent-pool-hosted-readonly.ps1" -Raw
foreach ($required in @("hosted-agent-pool-readonly-v1", "hosted_cloudflare_d1_four_role_agent_pool_readback_proof", "/api/v1/phase2/runtime/contract", "/api/v1/phase2/runtime/runs", "exactly four persisted tasks", "token_used = `$false", "provider_write = `$false")) {
  if (-not $hostedAgentPoolReadOnlyVerifier.Contains($required)) { throw "Hosted Agent Pool read-only verifier missing: $required" }
}
foreach ($forbidden in @("x-superbrain-agent-token", "-Method Post", "-Method Put", "-Method Patch", "-Method Delete")) {
  if ($hostedAgentPoolReadOnlyVerifier.Contains($forbidden)) { throw "Hosted Agent Pool read-only verifier contains write/auth marker: $forbidden" }
}

Write-Host "[verify] Cloudflare Workers AI LLM Gateway static contract"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-cloudflare-llm-gateway.ps1 -StaticOnly
Assert-LastExitCode "Cloudflare Workers AI LLM Gateway static contract"

Write-Host "[verify] Cloudflare D1 stateful runtime static contract"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-cloudflare-stateful-runtime.ps1 -StaticOnly
Assert-LastExitCode "Cloudflare D1 stateful runtime static contract"

Write-Host "[verify] bounded live LLM evidence chain"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-live-llm-evidence-chain.ps1
Assert-LastExitCode "bounded live LLM evidence chain"

Write-Host "[verify] current hosted frontend proof"
$frontendHostedVerifierSource = Get-Content -Path "scripts\verify-frontend-hosted-current.ps1" -Raw
foreach ($required in @(
  'former500Paths',
  'requiredReadPaths',
  'hosted read endpoint inventory',
  'production_operational_deploy_verified',
  'browserBaseUrl'
)) {
  if (-not $frontendHostedVerifierSource.Contains($required)) {
    throw "Current hosted frontend verifier missing T1 Production guard: $required"
  }
}
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-frontend-hosted-current.ps1 -StaticOnly
Assert-LastExitCode "current hosted frontend static proof"

Write-Host "[verify] current hosted backend contract-origin proof"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-backend-hosted-current.ps1 -StaticOnly
Assert-LastExitCode "current hosted backend contract-origin static proof"

Write-Host "[verify] git diff whitespace"
$prevEap = $ErrorActionPreference
$prevNative = $PSNativeCommandUseErrorActionPreference
$ErrorActionPreference = "Continue"
$PSNativeCommandUseErrorActionPreference = $false
try {
  $gitDiffWhitespace = git diff --check 2>&1
} finally {
  $PSNativeCommandUseErrorActionPreference = $prevNative
  $ErrorActionPreference = $prevEap
}
$meaningfulWhitespaceIssues = @($gitDiffWhitespace | Where-Object {
  $_ -and
  ($_ -notmatch "new blank line at EOF") -and
  ($_ -notmatch "^warning: in the working copy of ")
})
if ($meaningfulWhitespaceIssues.Count -gt 0) {
  $meaningfulWhitespaceIssues | ForEach-Object { Write-Host $_ }
  throw "Verification failed: git diff whitespace"
}

$repoLocalGitleaks = Join-Path ".tools\gitleaks" "gitleaks.exe"
$gitleaksCommand = Get-Command gitleaks -ErrorAction SilentlyContinue
if ($gitleaksCommand -or (Test-Path $repoLocalGitleaks)) {
  Write-Host "[verify] gitleaks scan"
  $gitleaksExecutable = if ($gitleaksCommand) { "gitleaks" } else { $repoLocalGitleaks }
  $repoRoot = (Resolve-Path ".").Path
  $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
  $gitleaksScanRoot = Join-Path $tempRoot ("superbrain-gitleaks-scan-" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $gitleaksScanRoot | Out-Null
  try {
    $trackedAndUntrackedFiles = git ls-files -z --cached --others --exclude-standard
    Assert-LastExitCode "git ls-files for gitleaks scan"
    $scanFileCount = 0
    foreach ($relativePath in ($trackedAndUntrackedFiles -split "`0")) {
      if ([string]::IsNullOrWhiteSpace($relativePath)) { continue }
      $sourcePath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $relativePath))
      if (-not $sourcePath.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Verification failed: gitleaks source escaped repo root: $relativePath"
      }
      if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { continue }
      $targetPath = [System.IO.Path]::GetFullPath((Join-Path $gitleaksScanRoot $relativePath))
      if (-not $targetPath.StartsWith($gitleaksScanRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Verification failed: gitleaks target escaped scan root: $relativePath"
      }
      $targetParent = Split-Path -Parent $targetPath
      if (-not (Test-Path -LiteralPath $targetParent)) {
        New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
      }
      Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
      $scanFileCount += 1
    }
    if ($scanFileCount -lt 100) {
      throw "Verification failed: gitleaks scan mirror unexpectedly small: $scanFileCount files"
    }
    Write-Host "[verify] gitleaks scan files=$scanFileCount"
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & $gitleaksExecutable detect --no-git --source $gitleaksScanRoot --config .gitleaks.toml --redact --timeout 600
    $gitleaksExit = $LASTEXITCODE; $ErrorActionPreference = $prevEap
    if ($gitleaksExit -ne 0) { throw "Verification failed: gitleaks scan exited $gitleaksExit" }
  } finally {
    if (Test-Path -LiteralPath $gitleaksScanRoot) {
      $resolvedScanRoot = (Resolve-Path -LiteralPath $gitleaksScanRoot).Path
      if (-not $resolvedScanRoot.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove non-temp gitleaks scan root: $resolvedScanRoot"
      }
      Remove-Item -LiteralPath $resolvedScanRoot -Recurse -Force
    }
  }
} else {
  Write-Host "[verify] fallback secret scan"
  py -3 scripts\secret_scan_fallback.py
  Assert-LastExitCode "fallback secret scan"
}

Write-Host "[verify] phase1 checks completed"

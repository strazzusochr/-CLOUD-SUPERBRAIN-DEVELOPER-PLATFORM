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
foreach ($required in @("convertFlyAppNameToBaseUrl", "resolveBaseUrl", "FLY_APP_AGENT_API", "FLY_APP_MCP_GATEWAY", "FLY_APP_LLM_GATEWAY", "cloud-superbrain-agent-api", "cloud-superbrain-mcp-gateway", "cloud-superbrain-llm-gateway", "hostedRewriteFallbackFor")) {
  if (-not $frontendNextConfig.Contains($required)) {
    throw "Frontend Next.js config missing Fly rewrite guard: $required"
  }
}

Write-Host "[verify] frontend cloud rewrites"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-frontend-cloud-rewrites.ps1
Assert-LastExitCode "frontend cloud rewrites"

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
  "fly-agent-api",
  "fly-mcp-gateway",
  "fly-llm-gateway",
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
$organismTopologyFrontend = Get-Content -Path "apps\frontend\app\api\v1\organism\topology\route.ts" -Raw
$organismTopologyContract = Get-Content -Path "apps\frontend\app\api\v1\organism\contract\route.ts" -Raw
$organismPlatformSource = Get-Content -Path "apps\frontend\lib\platform.ts" -Raw
$organismAgentApiSource = Get-Content -Path "services\agent-api\app\main.py" -Raw
foreach ($required in @(
  "organism-topology-v1",
  "workspace-surface-wiring-v1",
  "workspace-vertical-stack-v1",
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
  '{ id: "P4", pct: 99 }',
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
  '"kind": "agent_to_tool"',
  '"kind": "page_to_verifier"',
  '"kind": "layer_to_provider"',
  '@app.get("/api/v1/organism/topology")'
)) {
  if (-not $organismAgentApiSource.Contains($required)) {
    throw "Agent API organism topology source missing guard: $required"
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
  "FLY_API_TOKEN",
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
py -3 -m py_compile scripts\check_fly_infra_budget.py
Assert-LastExitCode "ci budget script"

Write-Host "[verify] fly origin configs"
$flyOriginConfigs = @(
  @{ path = "fly.agent-api.toml"; app = "cloud-superbrain-agent-api"; dockerfile = "services/agent-api/Dockerfile"; port = "8000"; memory = "1gb" },
  @{ path = "fly.mcp-gateway.toml"; app = "cloud-superbrain-mcp-gateway"; dockerfile = "services/mcp-gateway/Dockerfile"; port = "9000"; memory = "512mb" },
  @{ path = "fly.llm-gateway.toml"; app = "cloud-superbrain-llm-gateway"; dockerfile = "services/llm-gateway/Dockerfile"; port = "4000"; memory = "512mb" }
)
foreach ($config in $flyOriginConfigs) {
  if (-not (Test-Path $config.path)) {
    throw "Missing Fly.io origin config: $($config.path)"
  }
  $flyConfig = Get-Content -Path $config.path -Raw
  foreach ($required in @(
    "app = `"$($config.app)`"",
    "primary_region = `"fra`"",
    "dockerfile = `"$($config.dockerfile)`"",
    "internal_port = $($config.port)",
    "force_https = true",
    "size = `"shared-cpu-1x`"",
    "memory = `"$($config.memory)`""
  )) {
    if (-not $flyConfig.Contains($required)) {
      throw "Fly.io origin config $($config.path) missing guard: $required"
    }
  }
}

Write-Host "[verify] fly source-build context"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-fly-build-context.ps1
Assert-LastExitCode "fly source-build context"

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
foreach ($requiredHostedBoundaryTerm in @(
  'Current Hosted Boundary',
  'historical provenance only',
  'Current hosted gate truth is the latest `external-gate-audit-*` artifact plus a future real Vercel HTTPS `STAGING_BASE_URL` and reachable Fly origins'
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
foreach ($required in @("cloud-provider-inventory-v1", "cloud_provider_inventory_visible", "cloud-layer-readiness-v1", "cloud_layer_readiness_visible", "GET /api/v1/clouds", "GET /api/v1/clouds/layers", "seven_layer_mapping", "cloud_layer_readiness_state", "FLY_API_TOKEN", "fly_api_readonly", "CLOUDFLARE_API_TOKEN", "cloudflare_api_readonly", "CLOUDFLARE_DASHBOARD_URL", "VERCEL_TOKEN", "vercel_api_readonly", "GITHUB_TOKEN", "github_api_readonly", "GHCR_TOKEN", "ghcr_api_readonly", "HF_TOKEN", "huggingface_api_readonly", "GITLAB_TOKEN", "gitlab_api_readonly", "GRAFANA_CLOUD_API_KEY", "grafana_api_readonly", "No secret values", "mask_ip", "vercel_frontend", "cloudflare_edge", "github_actions", "ghcr_registry", "huggingface_identity", "gitlab_identity", "grafana_cloud")) {
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
foreach ($required in @("Developer Platform", "Produktfläche", "Evidence", "Diagnostics", "Organism", "Studio-Modi", "Core Pages", "Live Claims")) {
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
foreach ($required in @("WorkbenchStudio", "workbench-studio", "wb-composer", "/api/v1/build", "Explorer", "Vorschau", "Build-Log", "terminal-feed", "ws-frame")) {
  if (-not $workbenchSurface.Contains($required)) {
    throw "Missing clean workbench platform guard: $required"
  }
}
foreach ($forbidden in @("fetchMasterPlan", "Master Plan (live)", "Dispatch endpoints", "fetchCompletionGate", "fetchRecentTasks", "fetchRecentSessions", "fetchAuditRecent", "fetchLiveAgents", "Completion-Gate", "Workspace-Surfaces (22)", "Fail-closed by design", "Gate-Matrix", "Recovery-Historie")) {
  if ($workbenchSurface.Contains($forbidden)) {
    throw "Workbench must not surface project-plan dashboard elements: $forbidden"
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
  "missing_external_gates",
  "fly_api_token",
  "vercel_backend_origins",
  "live_infra_budget_refresh_requires_FLY_API_TOKEN",
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
  '"status":"action_required"',
  '"cloud_deploy_claim_allowed":false',
  '"production_deploy_claim_allowed":false',
  "missing_or_blocked_gates",
  "fly_cloud_stack",
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
if (-not (Test-Path "scripts\verify-all-gates-with-tokens.ps1")) {
  throw "Missing private env external gate runner"
}
$externalGateAuditScript = Get-Content -Path "scripts\verify-external-gates.ps1" -Raw
foreach ($required in @("external-gate-audit-v1", "external_gate_audit_proof", "hosted_staging_claim_allowed", "frontend_preview_claim_allowed", "production_deploy_claim_allowed", "Assert-HostedBaseUrlSafe", "External gate hosted proof requires HTTPS", "Test-RetiredHostedBaseUrl", "retired_provider_url", "network_classification", "elapsed_ms", "response_url", "failed_hosted_required_probe_ids", "failed_vercel_origin_probe_ids", "hosted_cloud_deployment_preflight", "cloud_deployment_preflight_visible", "ghcr_image_digest_verify", "ghcr_image_digest_proof", "Invoke-BoundedNativeCommand", "WaitForExit", "EXTERNAL_GATE_HTTP_TIMEOUT_MS", "EXTERNAL_GATE_GITLEAKS_TIMEOUT_SECONDS", "EXTERNAL_GATE_DOCKER_TIMEOUT_SECONDS", '"timeout"', "dockerExitCode", "vercel_backend_origin_required", "vercel_backend_origin_health", "hosted_agent_api_health", "hosted_agent_api_health_required", "cloud-provider-inventory-v1", "cloud_provider_inventory_visible", "cloud-layer-readiness-v1", "cloud_layer_readiness_visible", "github_branch_protection_verify", "canonical_gitleaks_scan", "fly_live_budget_check", "root_health", "prefixed_health", "Join-OriginProbeUrl", "gitlab_identity_claim_allowed", "huggingface_identity_claim_allowed", "grafana_cloud_claim_allowed", "Invoke-RestMethod", "GITLAB_TOKEN", "HF_TOKEN", "GRAFANA_CLOUD_API_KEY")) {
  if (-not $externalGateAuditScript.Contains($required)) {
    throw "External gate audit verifier missing guard: $required"
  }
}
$privateGateRunner = Get-Content -Path "scripts\verify-all-gates-with-tokens.ps1" -Raw
foreach ($required in @("Convert-FlyAppNameToBaseUrl", "Resolve-OriginEnv", "Test-HostedRewriteFallbackValue", "Get-FlyAppNameOrDefault", "FLY_APP_AGENT_API", "FLY_APP_MCP_GATEWAY", "FLY_APP_LLM_GATEWAY", "cloud-superbrain-agent-api", "cloud-superbrain-mcp-gateway", "cloud-superbrain-llm-gateway", ".fly.dev")) {
  if (-not $privateGateRunner.Contains($required)) {
    throw "Private env external gate runner missing Fly origin derivation guard: $required"
  }
}
$externalGateAuditDoc = Get-Content -Path "docs\runtime-contracts\external-gate-audit-contract.md" -Raw
foreach ($required in @("external-gate-audit-v1", "cloud-only-staging-proof-v1", "Frontend preview reachability is not hosted staging", "hosted_staging_claim_allowed", "production_deploy_claim_allowed", "No secret values", "Optional GitLab identity", "Optional Hugging Face identity", "Optional grafana identity", "Fly app names", "never the token")) {
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
foreach ($required in @("cloud-provider-inventory-v1", "cloud_provider_inventory_visible", "cloud-layer-readiness-v1", "cloud_layer_readiness_visible", "GET /api/v1/clouds", "GET /api/v1/clouds/layers", "Seven-Layer Mapping", "Cloud Layer Readiness", "No secret values", "Vercel Live Read", "Fly.io Live Read", "Cloudflare Live Read", "GitHub Live Read", "GHCR Live Read", "Hugging Face Live Read", "GitLab Live Read", "Grafana Cloud Live Read", "FLY_API_TOKEN", "CLOUDFLARE_API_TOKEN", "VERCEL_TOKEN", "GITHUB_TOKEN", "GHCR_TOKEN", "HF_TOKEN", "GITLAB_TOKEN", "GRAFANA_CLOUD_API_KEY", "vercel_frontend", "ghcr_registry", "grafana_cloud")) {
  if (-not $cloudProviderInventoryDoc.Contains($required)) {
    throw "Cloud provider inventory contract document missing guard: $required"
  }
}
if (-not (Test-Path "docs\runtime-contracts\cloud-render-offload-contract.md")) {
  throw "Missing cloud render offload contract document"
}
$cloudRenderOffloadDoc = Get-Content -Path "docs\runtime-contracts\cloud-render-offload-contract.md" -Raw
foreach ($required in @("cloud-render-offload-v1", "cloud_render_offload_contract_visible", "GET /api/v1/clouds/render-offload/contract", "localhost_heavy_render_allowed", "STAGING_BASE_URL", "FLY_API_TOKEN", "webgl_3d_rendering", "control_plane")) {
  if (-not $cloudRenderOffloadDoc.Contains($required)) {
    throw "Cloud render offload contract document missing guard: $required"
  }
}
if (-not (Test-Path "docs\runtime-contracts\cloud-deployment-preflight-contract.md")) {
  throw "Missing cloud deployment preflight contract document"
}
$cloudDeploymentPreflightDoc = Get-Content -Path "docs\runtime-contracts\cloud-deployment-preflight-contract.md" -Raw
foreach ($required in @("cloud-deployment-preflight-v1", "cloud_deployment_preflight_visible", "GET /api/v1/clouds/deployment-preflight/contract", "publish_ghcr_images", "GITHUB_TOKEN", "GHCR_TOKEN", "FLY_API_TOKEN", "AGENT_API_BASE_URL", "BRANCH_PROTECTION_TOKEN", "cloud_deploy_claim_allowed", "production_deploy_claim_allowed", "manual_external_actions")) {
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

Write-Host "[verify] go-live readiness guard"
if (-not (Test-Path "scripts\verify-go-live-readiness.ps1")) {
  throw "Missing go-live readiness verifier"
}
$goLiveVerifier = Get-Content -Path "scripts\verify-go-live-readiness.ps1" -Raw
foreach ($required in @(
  "go-live-readiness-v1",
  "go-live-readiness-surface-v1",
  "external-gate-audit-v1",
  "hosted_agent_api_contracts",
  "github_branch_protection_current_verify",
  "vercel_backend_origin_health",
  "fly_live_budget_check",
  "FLY_API_TOKEN",
  "STAGING_BASE_URL",
  "BRANCH_PROTECTION_TOKEN",
  "AGENT_API_BASE_URL",
  "MCP_GATEWAY_BASE_URL",
  "LLM_GATEWAY_BASE_URL",
  "external-gate-summary-v1",
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
  "external-gate-summary-v1",
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
  "external-gate-summary-v1",
  "external-gate-audit-v1",
  "hosted_agent_api_contracts",
  "github_branch_protection_current_verify",
  "vercel_backend_origin_health",
  "fly_live_budget_check",
  "Probe snippets, URLs, logs, and token values are not included"
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
  throw "Missing Fly.io/Vercel/GHCR/Grafana budget proof document"
}
$flyBudgetProof = Get-Content -Path "docs\runbooks\fly-live-budget-proof-2026-06-08.md" -Raw
foreach ($required in @("Projected Fly.io monthly server cost", "EUR 9.00", "EUR 16.00", "EUR 20.00", "Live Fly.io token probe: external-gated", "under warning threshold", "token is not persisted", "Vercel/Fly.io/GHCR/Grafana Cloud")) {
  if (-not $flyBudgetProof.Contains($required)) {
    throw "Fly.io/Vercel/GHCR/Grafana budget proof document missing guard: $required"
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


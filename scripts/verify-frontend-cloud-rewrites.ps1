$ErrorActionPreference = "Stop"

function Assert-LastExitCode($label) {
  if ($LASTEXITCODE -ne 0) {
    throw "Verification failed: $label"
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$nextConfigPath = Join-Path $repoRoot "apps\frontend\next.config.mjs"
$snapshotRefreshPath = Join-Path $repoRoot "scripts\refresh-endpoint-snapshot.mjs"

if (-not (Test-Path -LiteralPath $nextConfigPath)) {
  throw "Missing frontend Next.js config: $nextConfigPath"
}
if (-not (Test-Path -LiteralPath $snapshotRefreshPath)) {
  throw "Missing endpoint snapshot refresh script: $snapshotRefreshPath"
}
$snapshotRefreshSource = Get-Content -LiteralPath $snapshotRefreshPath -Raw
foreach ($required in @(
  "Endpoint snapshot refresh is DEV-ONLY",
  '["localhost", "127.0.0.1", "::1"]',
  "sanitizePayload",
  "secretPatterns",
  "configured_count: 0",
  "writeFileSync"
)) {
  if (-not $snapshotRefreshSource.Contains($required)) {
    throw "Endpoint snapshot refresh script missing guard: $required"
  }
}

$nodeScript = @'
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const repoRoot = path.resolve(process.argv[2]);
const configPath = path.join(repoRoot, "apps/frontend/next.config.mjs");
const catchAllPath = path.join(repoRoot, "apps/frontend/app/api/v1/[...slug]/route.ts");
const llmRoutePath = path.join(repoRoot, "apps/frontend/app/llm/[...slug]/route.ts");
const mcpRoutePath = path.join(repoRoot, "apps/frontend/app/mcp/[...slug]/route.ts");
const gatewayProxyPath = path.join(repoRoot, "apps/frontend/lib/gatewayProxy.ts");
const frontendBoundaryPath = path.join(repoRoot, "apps/frontend/lib/frontendBoundary.ts");
const endpointSnapshotPath = path.join(repoRoot, "apps/frontend/lib/endpoint-snapshot.json");
const progressManifestPath = path.join(repoRoot, "docs/project-progress.manifest.json");

const read = (file) => fs.readFileSync(file, "utf8");
const nextConfigSource = read(configPath);
const catchAllSource = read(catchAllPath);
const llmRouteSource = read(llmRoutePath);
const mcpRouteSource = read(mcpRoutePath);
const gatewayProxySource = read(gatewayProxyPath);
const frontendBoundarySource = read(frontendBoundaryPath);
const endpointSnapshot = JSON.parse(read(endpointSnapshotPath));
const progressManifest = JSON.parse(read(progressManifestPath));

const assertIncludes = (label, source, expected) => {
  if (!source.includes(expected)) {
    throw new Error(`${label}: missing ${expected}`);
  }
};

const assertNotIncludes = (label, source, forbidden) => {
  if (source.includes(forbidden)) {
    throw new Error(`${label}: forbidden ${forbidden}`);
  }
};

const configModule = await import(`${pathToFileURL(configPath).href}?verify=${Date.now()}`);
const config = configModule.default;

if (!config || typeof config !== "object") {
  throw new Error("next.config.mjs must export a config object");
}

if (typeof config.rewrites === "function") {
  const result = await config.rewrites();
  const beforeFiles = Array.isArray(result?.beforeFiles) ? result.beforeFiles : [];
  for (const rewrite of beforeFiles) {
    const source = String(rewrite?.source ?? "");
    if (["/api/v1/:path*", "/api/stream", "/mcp/:path*", "/llm/:path*"].includes(source)) {
      throw new Error(`edge rewrite for ${source} must stay disabled; route handlers own cloud routing`);
    }
  }
}

for (const expected of [
  "edge rewrites to external backend origins are intentionally disabled",
  "AGENT_API_BASE_URL",
  "MCP_GATEWAY_BASE_URL",
  "LLM_GATEWAY_BASE_URL",
  "STAGING_REWRITES_ENABLED",
  "cloudRewrite",
  "void cloudRewrite",
]) {
  assertIncludes("next config cloud routing guard", nextConfigSource, expected);
}
for (const forbidden of [
  "convertFlyAppNameToBaseUrl",
  "getFlyAppNameOrDefault",
  "FLY_APP_AGENT_API",
  "FLY_APP_MCP_GATEWAY",
  "FLY_APP_LLM_GATEWAY",
  ".fly.dev",
]) {
  assertNotIncludes("next config active cloud routing guard", nextConfigSource, forbidden);
}

for (const expected of [
  "proxyToBoundary",
  '"agent-api"',
  "boundaryUnavailable",
  "x-superbrain-source",
  "project-state-projection",
  "frontend-projection",
  "endpoint-snapshot.json",
  "genericDefault",
  "proxyOAuthGetToBoundary",
  "proxyAuthSessionToBoundary",
  '"/api/v1/auth/me"',
  '"/api/v1/auth/refresh"',
  '"/api/v1/auth/logout"',
  "secret_output: false",
]) {
  assertIncludes("agent-api catch-all route", catchAllSource, expected);
}
for (const forbidden of [
  "process.env.GITHUB_OAUTH_CLIENT_SECRET",
  "process.env.JWT_SIGNING_SECRET",
  "process.env.AGENT_API_AUTH_TOKEN",
  "ghp_",
  "sk-proj-",
  "BEGIN PRIVATE KEY",
]) {
  assertNotIncludes("agent-api catch-all secret-value boundary", catchAllSource, forbidden);
}

for (const expected of [
  "gatewayHandle",
  "\"/llm\"",
  "\"LLM_GATEWAY_BASE_URL\"",
]) {
  assertIncludes("llm route handler", llmRouteSource, expected);
}

for (const expected of [
  "gatewayHandle",
  "\"/mcp\"",
  "\"MCP_GATEWAY_BASE_URL\"",
]) {
  assertIncludes("mcp route handler", mcpRouteSource, expected);
}

for (const expected of [
  "proxyToBoundary",
  "boundaryUnavailable",
  "llm-gateway",
  "mcp-gateway",
  "frontend-projection",
  "direct_provider_calls",
]) {
  assertIncludes("gateway proxy", gatewayProxySource, expected);
}

for (const expected of [
  "AGENT_API_BASE_URL",
  "AGENT_API_INTERNAL_URL",
  "MCP_GATEWAY_BASE_URL",
  "LLM_GATEWAY_BASE_URL",
  "configured_boundary_unavailable",
  "direct_provider_calls: false",
]) {
  assertIncludes("frontend boundary", frontendBoundarySource, expected);
}

for (const forbidden of [
  "cfWorkersAi",
  "cloudflare-workers-ai",
  "api.cloudflare.com",
  "api.github.com",
  "@neondatabase/serverless",
]) {
  assertNotIncludes("frontend gateway boundary sources", gatewayProxySource + frontendBoundarySource, forbidden);
}

for (const forbidden of [
  "localhost:8000",
  "127.0.0.1",
  "host.docker.internal",
]) {
  assertNotIncludes("frontend cloud routing sources", nextConfigSource + catchAllSource + llmRouteSource + mcpRouteSource, forbidden);
}

const snapshotExternalGates = endpointSnapshot["/api/v1/external-gates"];
const snapshotClouds = endpointSnapshot["/api/v1/clouds"];
const snapshotPreflight = endpointSnapshot["/api/v1/clouds/deployment-preflight"];
const snapshotGoLive = endpointSnapshot["/api/v1/clouds/go-live-readiness"];
const snapshotLayers = endpointSnapshot["/api/v1/clouds/layers"];
const snapshotRender = endpointSnapshot["/api/v1/clouds/render-offload"];
const snapshotCompletion = endpointSnapshot["/api/v1/project/progress/completion"];
const snapshotProgress = endpointSnapshot["/api/v1/project/progress"];
const snapshotWiring = endpointSnapshot["/api/v1/workspace/wiring"];
const snapshotVertical = endpointSnapshot["/api/v1/workspace/vertical-stack"];
const snapshotOrganism = endpointSnapshot["/api/v1/organism/contract"];
const snapshotTopology = endpointSnapshot["/api/v1/organism/topology"];
const snapshotInventory = endpointSnapshot["/api/v1/platform/inventory"];
for (const [name, value] of Object.entries({
  externalGates: snapshotExternalGates,
  clouds: snapshotClouds,
  preflight: snapshotPreflight,
  goLive: snapshotGoLive,
  layers: snapshotLayers,
  render: snapshotRender,
  completion: snapshotCompletion,
  progress: snapshotProgress,
  wiring: snapshotWiring,
  vertical: snapshotVertical,
  organism: snapshotOrganism,
  topology: snapshotTopology,
  inventory: snapshotInventory,
})) {
  if (!value || typeof value !== "object") {
    throw new Error(`endpoint snapshot missing current payload: ${name}`);
  }
}
const loginWiring = (snapshotWiring.surfaces || []).find((item) => item?.pageId === "login");
const settingsWiring = (snapshotWiring.surfaces || []).find((item) => item?.pageId === "settings");
const loginVertical = (snapshotVertical.stacks || []).find((item) => item?.pageId === "login");
const settingsVertical = (snapshotVertical.stacks || []).find((item) => item?.pageId === "settings");
const requireSources = (label, actual, expected) => {
  for (const source of expected) {
    if (!Array.isArray(actual) || !actual.includes(source)) {
      throw new Error(`${label}: missing ${source}`);
    }
  }
};
const loginAuthSources = [
  "/api/v1/auth/contract",
  "/api/v1/auth/github",
  "/api/v1/auth/callback",
  "/api/v1/auth/me",
  "/api/v1/auth/refresh",
  "/api/v1/auth/logout",
];
const settingsAuthSources = [
  "/api/v1/auth/contract",
  "/api/v1/auth/callback",
  "/api/v1/auth/me",
  "/api/v1/auth/refresh",
  "/api/v1/auth/logout",
];
requireSources("snapshot login wiring", loginWiring?.dataSources, loginAuthSources);
requireSources("snapshot settings wiring", settingsWiring?.dataSources, settingsAuthSources);
requireSources("snapshot login vertical API", loginVertical?.api?.contracts, loginAuthSources);
requireSources("snapshot login vertical data", loginVertical?.data?.sources, loginAuthSources);
requireSources("snapshot settings vertical API", settingsVertical?.api?.contracts, settingsAuthSources);
requireSources("snapshot settings vertical data", settingsVertical?.data?.sources, settingsAuthSources);
const authMeNode = (snapshotTopology.nodes || []).find((item) => item?.id === "source:api_v1_auth_me");
const authMePages = (snapshotTopology.edges || [])
  .filter((item) => item?.kind === "page_to_data_source" && item?.to === "source:api_v1_auth_me")
  .map((item) => item.from)
  .sort();
if (
  !authMeNode ||
  Number((snapshotTopology.nodes || []).length) !== 246 ||
  Number((snapshotTopology.edges || []).length) !== 500 ||
  JSON.stringify(authMePages) !== JSON.stringify(["page:login", "page:settings"])
) {
  throw new Error("endpoint snapshot topology is stale for the auth/me page wiring");
}
if (!JSON.stringify(snapshotOrganism).includes("/api/v1/auth/me")) {
  throw new Error("endpoint snapshot organism contract is stale for auth/me");
}
if (Number(snapshotInventory?.backend?.agent_api_routes) !== 180) {
  throw new Error("endpoint snapshot Agent API route inventory is stale");
}
if (
  String(snapshotExternalGates.canonical_summary_source_artifact || "").replaceAll("\\", "/")
    !== "docs/runtime-state/external-gate-audit-v2.json"
) {
  throw new Error("endpoint snapshot external gates must reference durable audit v2");
}
if (Number(snapshotProgress.overall_percent) !== Number(progressManifest.overall_percent)) {
  throw new Error("endpoint snapshot progress is stale against the canonical manifest");
}
const flyProvider = (snapshotClouds.providers || []).find((item) => item?.id === "fly_io");
const cloudflareProvider = (snapshotClouds.providers || []).find((item) => item?.id === "cloudflare_edge");
if (!flyProvider?.historical_only || (flyProvider.layers || []).length !== 0) {
  throw new Error("endpoint snapshot must keep Fly inventory historical with no active layers");
}
if (
  Number(snapshotClouds.configured_count) !== 0 ||
  Number(snapshotClouds.live_verified_count) !== 0 ||
  (snapshotClouds.providers || []).some(
    (item) =>
      item?.configured ||
      item?.live_verified ||
      (item?.resources || []).length !== 0 ||
      item?.error ||
      (item?.env_status || []).some((entry) => entry?.configured),
  )
) {
  throw new Error("endpoint snapshot provider inventory must redact ephemeral live metadata");
}
assertNotIncludes(
  "endpoint snapshot provider inventory",
  JSON.stringify(snapshotClouds),
  ".sslip.io",
);
for (const layerId of ["layer_2", "layer_3", "layer_4", "layer_6", "layer_7"]) {
  if (!(cloudflareProvider?.layers || []).includes(layerId)) {
    throw new Error(`endpoint snapshot Cloudflare provider missing ${layerId}`);
  }
}
for (const [name, value] of Object.entries({
  externalGates: snapshotExternalGates,
  preflight: snapshotPreflight,
  goLive: snapshotGoLive,
  render: snapshotRender,
})) {
  const activeText = JSON.stringify(value, (key, nested) =>
    key === "legacy_provenance" ? undefined : nested,
  );
  assertIncludes(
    `endpoint snapshot ${name}`,
    activeText,
    "cloudflare_native_zero_card_hosted_runtime",
  );
  for (const forbidden of ["fly_cloud_stack", "fly_live_budget_check"]) {
    assertNotIncludes(`endpoint snapshot ${name} active truth`, activeText, forbidden);
  }
}
const completionActiveText = JSON.stringify(snapshotCompletion, (key, nested) =>
  key === "legacy_provenance" ? undefined : nested,
);
assertIncludes(
  "endpoint snapshot completion current blockers",
  completionActiveText,
  "ghcr_image_digest_proof",
);
const completionBlockerText = JSON.stringify({
  missing_external_gates: snapshotCompletion.missing_external_gates || [],
  missing_external_gate_blockers: snapshotCompletion.missing_external_gate_blockers || [],
  hard_blockers: snapshotCompletion.hard_blockers || [],
});
const branchProtectionGate = (snapshotExternalGates.gates || []).find(
  (item) => item?.id === "branch_protection_token",
);
if (!branchProtectionGate || typeof branchProtectionGate.verified !== "boolean") {
  throw new Error("endpoint snapshot branch protection gate must be explicit");
}
if (branchProtectionGate.verified) {
  assertNotIncludes(
    "endpoint snapshot verified branch protection blockers",
    completionBlockerText,
    "branch_protection_token",
  );
} else {
  assertIncludes(
    "endpoint snapshot unverified branch protection blockers",
    completionBlockerText,
    "branch_protection_token",
  );
}
assertNotIncludes(
  "endpoint snapshot completion current blockers",
  completionBlockerText,
  "cloudflare_native_zero_card_hosted_runtime",
);
for (const forbidden of ["fly_cloud_stack", "fly_live_budget_check"]) {
  assertNotIncludes("endpoint snapshot completion active truth", completionActiveText, forbidden);
}
const activeLayersText = JSON.stringify(snapshotLayers, (key, nested) =>
  key === "legacy_provenance" ? undefined : nested,
);
assertIncludes("endpoint snapshot layers active truth", activeLayersText, "cloudflare_edge");
const memoryLayer = (snapshotLayers.layers || []).find((item) => item?.layer_id === "layer_6");
if (
  memoryLayer?.status !== "live_verified" ||
  !(memoryLayer.configured_providers || []).includes("cloudflare_edge") ||
  !(memoryLayer.live_verified_providers || []).includes("cloudflare_edge") ||
  (memoryLayer.blockers || []).length !== 0
) {
  throw new Error("endpoint snapshot memory layer must carry verified Cloudflare stateful truth");
}
for (const forbidden of ["fly_cloud_stack", "fly_live_budget_check"]) {
  assertNotIncludes("endpoint snapshot layers active truth", activeLayersText, forbidden);
}

console.log("[frontend-cloud-rewrites] route-handler cloud routing checks completed");
'@

$tempScript = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), ".mjs")
try {
  Set-Content -LiteralPath $tempScript -Value $nodeScript -Encoding utf8
  node $tempScript $repoRoot
  Assert-LastExitCode "frontend cloud route-handler routing"
} finally {
  Remove-Item -LiteralPath $tempScript -Force -ErrorAction SilentlyContinue
}

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
  "SNAPSHOT_METADATA_KEY",
  "GATE_RELEVANT_PATHS",
  "gate_refresh_atomic",
  "current = fullRefresh && candidateSourceParity",
  "runtime_source_unattested_prequalification",
  "candidate_source_parity",
  "sanitizePayload",
  "secretPatterns",
  "configured_count: 0",
  "writeSnapshotAtomic",
  "renameSync"
)) {
  if (-not $snapshotRefreshSource.Contains($required)) {
    throw "Endpoint snapshot refresh script missing guard: $required"
  }
}

$nodeScript = @'
import crypto from "node:crypto";
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
const currentCandidatePath = path.join(
  repoRoot,
  "docs/release-artifacts/current-release-candidate.json",
);
const externalGateSummaryPath = path.join(
  repoRoot,
  "docs/runtime-state/external-gate-summary.json",
);

const read = (file) => fs.readFileSync(file, "utf8");
const nextConfigSource = read(configPath);
const catchAllSource = read(catchAllPath);
const llmRouteSource = read(llmRoutePath);
const mcpRouteSource = read(mcpRoutePath);
const gatewayProxySource = read(gatewayProxyPath);
const frontendBoundarySource = read(frontendBoundaryPath);
const endpointSnapshotText = read(endpointSnapshotPath);
const progressManifestText = read(progressManifestPath);
const currentCandidateText = read(currentCandidatePath);
const externalGateSummaryText = read(externalGateSummaryPath);
const endpointSnapshot = JSON.parse(endpointSnapshotText);
const progressManifest = JSON.parse(progressManifestText);
const currentCandidate = JSON.parse(currentCandidateText);

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

const snapshotMetadataKey = "__snapshot_metadata";
const expectedMetadataKeys = [
  "active_release_id",
  "candidate_source_commit_sha",
  "candidate_source_parity",
  "contract_version",
  "current",
  "current_reason",
  "current_release_candidate_sha256",
  "endpoint_count",
  "external_gate_summary_sha256",
  "gate_refresh_atomic",
  "gate_relevant_paths",
  "generated_at_utc",
  "payload_epoch_complete",
  "project_progress_manifest_sha256",
  "qualification_state",
  "refresh_scope",
  "refreshed_endpoint_count",
  "refreshed_paths",
  "release_candidate_artifact_sha256",
  "runtime_source_attested",
  "runtime_source_commit_sha",
  "source_scope",
  "target_scope",
].sort();
const gateRelevantPaths = [
  "/api/v1/clouds",
  "/api/v1/clouds/deployment-preflight",
  "/api/v1/clouds/go-live-readiness",
  "/api/v1/clouds/layers",
  "/api/v1/external-gates",
  "/api/v1/project/progress",
  "/api/v1/project/progress/completion",
].sort();
const snapshotKeys = Object.keys(endpointSnapshot);
const invalidSnapshotKeys = snapshotKeys.filter(
  (key) => key !== snapshotMetadataKey && !key.startsWith("/api/v1/"),
);
if (invalidSnapshotKeys.length > 0) {
  throw new Error(`endpoint snapshot has non-endpoint keys: ${invalidSnapshotKeys.sort().join(",")}`);
}
const snapshotEndpointPaths = snapshotKeys.filter((key) => key.startsWith("/api/v1/")).sort();
if (snapshotEndpointPaths.length < 30) {
  throw new Error("endpoint snapshot does not contain the canonical endpoint set");
}
const snapshotMetadata = endpointSnapshot[snapshotMetadataKey];
if (!snapshotMetadata || typeof snapshotMetadata !== "object" || Array.isArray(snapshotMetadata)) {
  throw new Error("endpoint snapshot is missing reserved __snapshot_metadata");
}
if (
  JSON.stringify(Object.keys(snapshotMetadata).sort()) !== JSON.stringify(expectedMetadataKeys)
) {
  throw new Error("endpoint snapshot metadata schema is not exact");
}
const canonicalGeneratedAt = new Date(snapshotMetadata.generated_at_utc).toISOString();
if (canonicalGeneratedAt !== snapshotMetadata.generated_at_utc) {
  throw new Error("endpoint snapshot generated_at_utc is not canonical ISO-8601 UTC");
}
if (
  snapshotMetadata.contract_version !== "endpoint-snapshot-metadata-v1" ||
  snapshotMetadata.refresh_scope !== "full" ||
  snapshotMetadata.payload_epoch_complete !== true ||
  snapshotMetadata.current !== false ||
  snapshotMetadata.current_reason !== "runtime_source_unattested_prequalification" ||
  snapshotMetadata.qualification_state !== "prequalification" ||
  snapshotMetadata.runtime_source_attested !== false ||
  snapshotMetadata.runtime_source_commit_sha !== null ||
  snapshotMetadata.candidate_source_parity !== false ||
  snapshotMetadata.source_scope !== "DEV-ONLY" ||
  snapshotMetadata.target_scope !== "localhost_only" ||
  snapshotMetadata.gate_refresh_atomic !== true
) {
  throw new Error("endpoint snapshot metadata does not prove an honest full DEV-ONLY prequalification refresh");
}
if (
  Number(snapshotMetadata.endpoint_count) !== snapshotEndpointPaths.length ||
  Number(snapshotMetadata.refreshed_endpoint_count) !== snapshotEndpointPaths.length ||
  JSON.stringify(snapshotMetadata.refreshed_paths) !== JSON.stringify(snapshotEndpointPaths) ||
  JSON.stringify(snapshotMetadata.gate_relevant_paths) !== JSON.stringify(gateRelevantPaths)
) {
  throw new Error("endpoint snapshot metadata does not bind the exact refreshed endpoint set");
}
for (const gatePath of gateRelevantPaths) {
  if (!snapshotEndpointPaths.includes(gatePath)) {
    throw new Error(`endpoint snapshot is missing gate-relevant endpoint: ${gatePath}`);
  }
}

const activeReleaseId = String(currentCandidate.active_release_id || "");
if (!/^[a-z0-9][a-z0-9._-]+$/.test(activeReleaseId)) {
  throw new Error("current release candidate has an invalid active_release_id");
}
if (currentCandidate.production_rollout_claimed !== false) {
  throw new Error("current release candidate must keep production_rollout_claimed=false");
}
const releaseCandidateArtifactPath = path.join(
  repoRoot,
  "docs/release-artifacts",
  `${activeReleaseId}.md`,
);
const releaseCandidateArtifactText = read(releaseCandidateArtifactPath);
const releaseIdMatch = releaseCandidateArtifactText.match(/^release_id:\s*`([^`]+)`\s*$/m);
const sourceCommitMatch = releaseCandidateArtifactText.match(
  /^source_commit_sha:\s*`([0-9a-f]{40})`\s*$/m,
);
if (releaseIdMatch?.[1] !== activeReleaseId || !sourceCommitMatch) {
  throw new Error("active release candidate artifact is not source-bound to its pointer");
}
if (
  !/^[0-9a-f]{40}$/.test(String(currentCandidate.source_commit_sha || "")) ||
  currentCandidate.source_commit_sha !== sourceCommitMatch[1]
) {
  throw new Error("current release candidate pointer source_commit_sha does not match its artifact");
}
const sha256 = (value) => crypto.createHash("sha256").update(value).digest("hex");
const canonicalTextSha256 = (value) => sha256(value.replace(/\r\n?/g, "\n"));
const expectedMetadataBindings = {
  active_release_id: activeReleaseId,
  candidate_source_commit_sha: currentCandidate.source_commit_sha,
  current_release_candidate_sha256: canonicalTextSha256(currentCandidateText),
  release_candidate_artifact_sha256: canonicalTextSha256(releaseCandidateArtifactText),
  project_progress_manifest_sha256: canonicalTextSha256(progressManifestText),
  external_gate_summary_sha256: canonicalTextSha256(externalGateSummaryText),
};
for (const [field, expected] of Object.entries(expectedMetadataBindings)) {
  if (snapshotMetadata[field] !== expected) {
    throw new Error(`endpoint snapshot metadata binding mismatch: ${field}`);
  }
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

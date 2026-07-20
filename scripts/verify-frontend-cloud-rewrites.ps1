$ErrorActionPreference = "Stop"

function Assert-LastExitCode($label) {
  if ($LASTEXITCODE -ne 0) {
    throw "Verification failed: $label"
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$nextConfigPath = Join-Path $repoRoot "apps\frontend\next.config.mjs"

if (-not (Test-Path -LiteralPath $nextConfigPath)) {
  throw "Missing frontend Next.js config: $nextConfigPath"
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

const read = (file) => fs.readFileSync(file, "utf8");
const nextConfigSource = read(configPath);
const catchAllSource = read(catchAllPath);
const llmRouteSource = read(llmRoutePath);
const mcpRouteSource = read(mcpRoutePath);
const gatewayProxySource = read(gatewayProxyPath);
const frontendBoundarySource = read(frontendBoundaryPath);

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

for (const expected of [
  "proxyToBoundary",
  '"agent-api"',
  "boundaryUnavailable",
  "x-superbrain-source",
  "project-state-projection",
  "frontend-projection",
  "endpoint-snapshot.json",
  "genericDefault",
]) {
  assertIncludes("agent-api catch-all route", catchAllSource, expected);
}
assertNotIncludes("agent-api catch-all route", catchAllSource, "secret");

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

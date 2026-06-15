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
import path from "node:path";
import { pathToFileURL } from "node:url";

const configPath = path.resolve(process.argv[2]);
const configModule = await import(`${pathToFileURL(configPath).href}?verify=${Date.now()}`);
const config = configModule.default;

if (!config || typeof config.rewrites !== "function") {
  throw new Error("next.config.mjs must export rewrites()");
}

const relevantKeys = [
  "STAGING_REWRITES_ENABLED",
  "STAGING_BASE_URL",
  "AGENT_API_BASE_URL",
  "MCP_GATEWAY_BASE_URL",
  "LLM_GATEWAY_BASE_URL",
  "FLY_APP_AGENT_API",
  "FLY_APP_MCP_GATEWAY",
  "FLY_APP_LLM_GATEWAY",
];

const originalEnv = Object.fromEntries(relevantKeys.map((key) => [key, process.env[key]]));

const resetEnv = (overrides = {}) => {
  for (const key of relevantKeys) {
    delete process.env[key];
  }
  Object.assign(process.env, overrides);
};

const restoreEnv = () => {
  for (const key of relevantKeys) {
    delete process.env[key];
    if (originalEnv[key] !== undefined) {
      process.env[key] = originalEnv[key];
    }
  }
};

const loadRewrites = async (overrides) => {
  resetEnv(overrides);
  const result = await config.rewrites();
  if (!result || !Array.isArray(result.beforeFiles)) {
    throw new Error("rewrites() must return { beforeFiles: [...] }");
  }
  return result.beforeFiles;
};

const destinationFor = (rewrites, source) => {
  const match = rewrites.find((rewrite) => rewrite.source === source);
  if (!match) {
    throw new Error(`Missing rewrite source: ${source}`);
  }
  return match.destination;
};

const assertNoRewrite = (label, rewrites, source) => {
  const match = rewrites.find((rewrite) => rewrite.source === source);
  if (match) {
    throw new Error(`${label}: expected no rewrite for ${source}, got ${match.destination}`);
  }
};

const assertEqual = (label, actual, expected) => {
  if (actual !== expected) {
    throw new Error(`${label}: expected ${expected}, got ${actual}`);
  }
};

try {
  let rewrites = await loadRewrites({});
  assertNoRewrite("plain local agent rewrite disabled", rewrites, "/api/v1/:path*");
  assertNoRewrite("plain local stream rewrite disabled", rewrites, "/api/stream");
  assertNoRewrite("plain local mcp rewrite disabled", rewrites, "/mcp/:path*");
  assertNoRewrite("plain local llm rewrite disabled", rewrites, "/llm/:path*");

  rewrites = await loadRewrites({
    STAGING_REWRITES_ENABLED: "true",
    STAGING_BASE_URL: "https://old-hosted-rewrite.example.invalid",
  });
  assertEqual("default agent origin", destinationFor(rewrites, "/api/v1/:path*"), "https://cloud-superbrain-agent-api.fly.dev/api/v1/:path*");
  assertEqual("default mcp origin", destinationFor(rewrites, "/mcp/:path*"), "https://cloud-superbrain-mcp-gateway.fly.dev/:path*");
  assertEqual("default llm origin", destinationFor(rewrites, "/llm/:path*"), "https://cloud-superbrain-llm-gateway.fly.dev/:path*");

  rewrites = await loadRewrites({
    STAGING_REWRITES_ENABLED: "true",
    STAGING_BASE_URL: "https://old-hosted-rewrite.example.invalid",
    AGENT_API_BASE_URL: "https://agent.example.com",
    MCP_GATEWAY_BASE_URL: "https://mcp.example.com",
    LLM_GATEWAY_BASE_URL: "https://llm.example.com",
  });
  assertEqual("explicit agent origin", destinationFor(rewrites, "/api/v1/:path*"), "https://agent.example.com/api/v1/:path*");
  assertEqual("explicit mcp origin", destinationFor(rewrites, "/mcp/:path*"), "https://mcp.example.com/:path*");
  assertEqual("explicit llm origin", destinationFor(rewrites, "/llm/:path*"), "https://llm.example.com/:path*");

  rewrites = await loadRewrites({
    STAGING_REWRITES_ENABLED: "true",
    STAGING_BASE_URL: "https://old-hosted-rewrite.example.invalid",
    AGENT_API_BASE_URL: "https://old-hosted-rewrite.example.invalid",
    MCP_GATEWAY_BASE_URL: "https://old-hosted-rewrite.example.invalid/mcp",
    LLM_GATEWAY_BASE_URL: "https://old-hosted-rewrite.example.invalid/llm",
  });
  assertEqual("stale hosted agent fallback bypassed", destinationFor(rewrites, "/api/v1/:path*"), "https://cloud-superbrain-agent-api.fly.dev/api/v1/:path*");
  assertEqual("stale hosted mcp fallback bypassed", destinationFor(rewrites, "/mcp/:path*"), "https://cloud-superbrain-mcp-gateway.fly.dev/:path*");
  assertEqual("stale hosted llm fallback bypassed", destinationFor(rewrites, "/llm/:path*"), "https://cloud-superbrain-llm-gateway.fly.dev/:path*");

  rewrites = await loadRewrites({
    AGENT_API_BASE_URL: "http://localhost:8000",
    MCP_GATEWAY_BASE_URL: "https://<placeholder>",
    LLM_GATEWAY_BASE_URL: "http://llm.example.com",
  });
  assertNoRewrite("unsafe local agent origin rejected", rewrites, "/api/v1/:path*");
  assertNoRewrite("unsafe placeholder mcp origin rejected", rewrites, "/mcp/:path*");
  assertNoRewrite("unsafe http llm origin rejected", rewrites, "/llm/:path*");

  rewrites = await loadRewrites({
    STAGING_REWRITES_ENABLED: "true",
    AGENT_API_BASE_URL: "http://localhost:8000",
    MCP_GATEWAY_BASE_URL: "https://<placeholder>",
    LLM_GATEWAY_BASE_URL: "http://llm.example.com",
  });
  assertEqual("unsafe cloud-mode agent origin falls back", destinationFor(rewrites, "/api/v1/:path*"), "https://cloud-superbrain-agent-api.fly.dev/api/v1/:path*");
  assertEqual("unsafe cloud-mode mcp origin falls back", destinationFor(rewrites, "/mcp/:path*"), "https://cloud-superbrain-mcp-gateway.fly.dev/:path*");
  assertEqual("unsafe cloud-mode llm origin falls back", destinationFor(rewrites, "/llm/:path*"), "https://cloud-superbrain-llm-gateway.fly.dev/:path*");

  rewrites = await loadRewrites({
    FLY_APP_AGENT_API: "custom-agent-api",
    FLY_APP_MCP_GATEWAY: "custom-mcp-gateway",
    FLY_APP_LLM_GATEWAY: "custom-llm-gateway",
  });
  assertEqual("custom fly agent origin", destinationFor(rewrites, "/api/v1/:path*"), "https://custom-agent-api.fly.dev/api/v1/:path*");
  assertEqual("custom fly mcp origin", destinationFor(rewrites, "/mcp/:path*"), "https://custom-mcp-gateway.fly.dev/:path*");
  assertEqual("custom fly llm origin", destinationFor(rewrites, "/llm/:path*"), "https://custom-llm-gateway.fly.dev/:path*");

  console.log("[frontend-cloud-rewrites] checks completed");
} finally {
  restoreEnv();
}
'@

$tempScript = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), ".mjs")
try {
  Set-Content -LiteralPath $tempScript -Value $nodeScript -Encoding utf8
  node $tempScript $nextConfigPath
  Assert-LastExitCode "frontend cloud rewrites"
} finally {
  Remove-Item -LiteralPath $tempScript -Force -ErrorAction SilentlyContinue
}

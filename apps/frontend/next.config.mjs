/** @type {import('next').NextConfig} */
const nextConfig = {};

if (!process.env.VERCEL) {
  nextConfig.outputFileTracingRoot = new URL("../..", import.meta.url).pathname;
}

const flyOriginAppDefaults = {
  FLY_APP_AGENT_API: "cloud-superbrain-agent-api",
  FLY_APP_MCP_GATEWAY: "cloud-superbrain-mcp-gateway",
  FLY_APP_LLM_GATEWAY: "cloud-superbrain-llm-gateway",
};

const originEnvToFlyAppEnv = {
  AGENT_API_BASE_URL: "FLY_APP_AGENT_API",
  MCP_GATEWAY_BASE_URL: "FLY_APP_MCP_GATEWAY",
  LLM_GATEWAY_BASE_URL: "FLY_APP_LLM_GATEWAY",
};

const normalizeBaseUrl = (value) => {
  if (!value || typeof value !== "string") return null;
  return value.trim().replace(/\/$/, "");
};

const hasPlaceholder = (value) => {
  if (!value) return true;
  return value.includes("<") || value.includes(">") || value.includes("${");
};

const isSafeHttpsOrigin = (value) => {
  const normalized = normalizeBaseUrl(value);
  if (!normalized || hasPlaceholder(normalized)) return false;
  if (!normalized.startsWith("https://")) return false;
  return !/(localhost|127\.0\.0\.1|\[::1\]|0\.0\.0\.0|host\.docker\.internal)/i.test(normalized);
};

const convertFlyAppNameToBaseUrl = (value) => {
  const trimmed = normalizeBaseUrl(value);
  if (!trimmed || hasPlaceholder(trimmed)) return null;
  if (/^https:\/\/[A-Za-z0-9.-]+(\.fly\.dev)?$/.test(trimmed)) return trimmed;
  if (/^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$/.test(trimmed)) {
    return `https://${trimmed}.fly.dev`;
  }
  return null;
};

const getFlyAppNameOrDefault = (flyAppEnvKey) => {
  return process.env[flyAppEnvKey] || flyOriginAppDefaults[flyAppEnvKey] || "";
};

const hostedRewriteFallbackFor = (envKey, stagingBaseUrl) => {
  const staging = normalizeBaseUrl(stagingBaseUrl);
  if (!staging) return null;
  if (envKey === "AGENT_API_BASE_URL") return staging;
  if (envKey === "MCP_GATEWAY_BASE_URL") return `${staging}/mcp`;
  if (envKey === "LLM_GATEWAY_BASE_URL") return `${staging}/llm`;
  return null;
};

const isHostedRewriteFallback = (envKey, value, stagingBaseUrl) => {
  const normalized = normalizeBaseUrl(value);
  const fallback = hostedRewriteFallbackFor(envKey, stagingBaseUrl);
  return !!normalized && !!fallback && normalized.toLowerCase() === fallback.toLowerCase();
};

const resolveBaseUrl = (envKey) => {
  const direct = normalizeBaseUrl(process.env[envKey]);
  if (
    isSafeHttpsOrigin(direct) &&
    !isHostedRewriteFallback(envKey, direct, process.env.STAGING_BASE_URL)
  ) {
    return direct;
  }

  const flyAppEnvKey = originEnvToFlyAppEnv[envKey];
  const flyOrigin = flyAppEnvKey ? convertFlyAppNameToBaseUrl(getFlyAppNameOrDefault(flyAppEnvKey)) : null;
  if (flyOrigin) return flyOrigin;

  const stagingFallbackEnabled = (process.env.STAGING_REWRITES_ENABLED || "").toLowerCase() === "true";
  if (!stagingFallbackEnabled) return null;
  const fallback = hostedRewriteFallbackFor(envKey, process.env.STAGING_BASE_URL);
  return isSafeHttpsOrigin(fallback) ? fallback : null;
};

const cloudRewrite = (source, envKey, pathPrefix = "") => {
  const baseUrl = resolveBaseUrl(envKey);
  if (!baseUrl) {
    return null;
  }
  const hasPathStar = source.includes(":path*");
  const suffix = hasPathStar ? "/:path*" : "";
  return {
    source,
    destination: `${baseUrl.replace(/\/$/, "")}${pathPrefix}${suffix}`,
  };
};

nextConfig.rewrites = async () => {
  const rewrites = [
    cloudRewrite("/api/v1/:path*", "AGENT_API_BASE_URL", "/api/v1"),
    cloudRewrite("/api/stream", "AGENT_API_BASE_URL", "/api/stream"),
    cloudRewrite("/mcp/:path*", "MCP_GATEWAY_BASE_URL"),
    cloudRewrite("/llm/:path*", "LLM_GATEWAY_BASE_URL"),
  ].filter(Boolean);

  return {
    beforeFiles: rewrites,
  };
};

export default nextConfig;

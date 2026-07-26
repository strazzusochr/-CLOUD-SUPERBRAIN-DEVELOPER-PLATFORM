/** @type {import('next').NextConfig} */
const nextConfig = {};

if (!process.env.VERCEL) {
  nextConfig.outputFileTracingRoot = new URL("../..", import.meta.url).pathname;
}

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

const isStagingRewritesEnabled = () => {
  return /^(1|true|yes|on)$/i.test(process.env.STAGING_REWRITES_ENABLED || "");
};

const hostedRewriteFallbackFor = (envKey, stagingBaseUrl) => {
  const staging = normalizeBaseUrl(stagingBaseUrl);
  if (!staging) return null;
  if (envKey === "AGENT_API_BASE_URL") return staging;
  if (envKey === "MCP_GATEWAY_BASE_URL") return `${staging}/mcp`;
  if (envKey === "LLM_GATEWAY_BASE_URL") return `${staging}/llm`;
  return null;
};

const resolveBaseUrl = (envKey) => {
  const direct = normalizeBaseUrl(process.env[envKey]);
  if (isSafeHttpsOrigin(direct)) return direct;

  if (!isStagingRewritesEnabled()) return null;
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

// NOTE: edge rewrites to external backend origins are intentionally disabled.
// The app's own route handlers (app/api/v1/[...slug], app/llm, app/mcp) own these
// paths now: they serve read-only project-state contract projections and forward
// runtime requests only through AGENT_API_BASE_URL / MCP_GATEWAY_BASE_URL /
// LLM_GATEWAY_BASE_URL when those point to a reachable approved origin. A
// beforeFiles rewrite would intercept at the edge before the handler runs and
// hard-502 on a dead origin, so fail-closed routing stays in the handlers.
// `cloudRewrite` and the origin resolvers above are retained for reference.
void cloudRewrite;

export default nextConfig;

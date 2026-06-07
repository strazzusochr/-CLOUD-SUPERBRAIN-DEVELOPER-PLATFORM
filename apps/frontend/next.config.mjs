/** @type {import('next').NextConfig} */
const nextConfig = {};

if (!process.env.VERCEL) {
  nextConfig.outputFileTracingRoot = new URL("../..", import.meta.url).pathname;
}

const resolveBaseUrl = (envKey) => {
  const direct = process.env[envKey];
  if (direct) return direct;
  const stagingFallbackEnabled = (process.env.STAGING_REWRITES_ENABLED || "").toLowerCase() === "true";
  if (!stagingFallbackEnabled) return null;
  const staging = process.env.STAGING_BASE_URL;
  if (!staging) return null;
  if (envKey === "AGENT_API_BASE_URL") return staging;
  if (envKey === "MCP_GATEWAY_BASE_URL") return `${staging.replace(/\/$/, "")}/mcp`;
  if (envKey === "LLM_GATEWAY_BASE_URL") return `${staging.replace(/\/$/, "")}/llm`;
  return null;
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

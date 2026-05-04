/** @type {import('next').NextConfig} */
const nextConfig = {};

if (!process.env.VERCEL) {
  nextConfig.outputFileTracingRoot = new URL("../..", import.meta.url).pathname;
}

const cloudRewrite = (source, envKey, pathPrefix = "") => {
  const baseUrl = process.env[envKey];
  if (!baseUrl) {
    return null;
  }
  return {
    source,
    destination: `${baseUrl.replace(/\/$/, "")}${pathPrefix}/:path*`,
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

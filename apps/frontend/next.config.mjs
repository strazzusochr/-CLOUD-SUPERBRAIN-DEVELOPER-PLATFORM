import { dirname } from "node:path";
import { fileURLToPath } from "node:url";

const appRoot = dirname(fileURLToPath(import.meta.url));

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  turbopack: {
    root: appRoot,
  },
};

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
    cloudRewrite("/api/steer-agent", "AGENT_API_BASE_URL", "/api/steer-agent"),
    cloudRewrite("/mcp/:path*", "MCP_GATEWAY_BASE_URL"),
    cloudRewrite("/llm/:path*", "LLM_GATEWAY_BASE_URL"),
  ].filter(Boolean);

  return {
    beforeFiles: rewrites,
  };
};

export default nextConfig;

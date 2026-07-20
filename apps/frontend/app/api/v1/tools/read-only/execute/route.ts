import { boundaryUnavailable, proxyToBoundary } from "../../../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";
export const maxDuration = 30;

export async function POST(req: Request): Promise<Response> {
  const response = await proxyToBoundary(req, "agent-api", "/api/v1/tools/read-only/execute", 30_000);
  return response ?? boundaryUnavailable(
    "POST /api/v1/tools/read-only/execute",
    "agent-api",
    "Tool execution requires the Agent API and MCP Gateway policy envelope; no frontend fetch or provider call was attempted.",
  );
}

import { boundaryUnavailable, proxyToBoundary } from "../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";
export const maxDuration = 60;

export async function POST(req: Request): Promise<Response> {
  const response = await proxyToBoundary(req, "agent-api", "/api/v1/agent-run", 60_000);
  return response ?? boundaryUnavailable(
    "POST /api/v1/agent-run",
    "agent-api",
    "Multi-agent execution must run through the Agent API and its LLM Gateway; no frontend provider call was attempted.",
  );
}

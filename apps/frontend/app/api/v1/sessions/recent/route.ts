import { projectionResponse, proxyReadToBoundary } from "../../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";

export async function GET(req: Request): Promise<Response> {
  const response = await proxyReadToBoundary(req, "agent-api", "/api/v1/sessions/recent");
  return response ?? projectionResponse({
    status: "degraded",
    sessions: [],
    persisted: false,
    note: "No Agent API session store is reachable; no sessions are claimed.",
  });
}

import { projectionResponse, proxyReadToBoundary } from "../../../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";

export async function GET(req: Request): Promise<Response> {
  const response = await proxyReadToBoundary(req, "agent-api", "/api/v1/memory/consolidation/recent");
  return response ?? projectionResponse({
    contract_version: "memory-consolidation-feed-v1",
    status: "degraded",
    read_only: true,
    events: [],
    summary: [],
    audit_persisted: false,
    note: "No Agent API memory worker feed is reachable; no consolidations are claimed.",
  });
}

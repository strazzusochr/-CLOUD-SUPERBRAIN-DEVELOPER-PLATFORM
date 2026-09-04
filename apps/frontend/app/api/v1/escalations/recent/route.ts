import { projectionResponse, proxyReadToBoundary } from "../../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";

export async function GET(req: Request): Promise<Response> {
  const response = await proxyReadToBoundary(req, "agent-api", "/api/v1/escalations/recent");
  return response ?? projectionResponse({
    contract_version: "escalation-feed-v1",
    status: "degraded",
    read_only: true,
    events: [],
    escalations: [],
    audit_persisted: false,
    note: "No Agent API escalation feed is reachable; no escalations are claimed.",
  });
}

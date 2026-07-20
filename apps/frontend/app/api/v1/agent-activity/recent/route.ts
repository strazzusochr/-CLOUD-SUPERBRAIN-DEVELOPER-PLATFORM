import { projectionResponse, proxyToBoundary } from "../../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";

export async function GET(req: Request): Promise<Response> {
  const response = await proxyToBoundary(req, "agent-api", "/api/v1/agent-activity/recent");
  return response ?? projectionResponse({
    contract_version: "agent-activity-trace-v1",
    status: "degraded",
    read_only: true,
    events: [],
    audit_persisted: false,
    note: "No Agent API audit feed is reachable; no agent activity is claimed.",
  });
}

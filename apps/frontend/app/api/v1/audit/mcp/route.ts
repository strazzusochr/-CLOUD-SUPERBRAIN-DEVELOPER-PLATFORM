import { projectionResponse, proxyReadToBoundary } from "../../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";

export async function GET(req: Request): Promise<Response> {
  const response = await proxyReadToBoundary(req, "agent-api", "/api/v1/audit/mcp");
  return response ?? projectionResponse({
    contract_version: "mcp-audit-feed-v1",
    status: "degraded",
    read_only: true,
    events: [],
    audit_persisted: false,
    note: "No Agent API MCP audit feed is reachable; no MCP events are claimed.",
  });
}

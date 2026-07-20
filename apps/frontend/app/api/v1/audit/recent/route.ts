import { projectedAuditEvents } from "../../../../../lib/endpointDefaults";
import { projectionResponse, proxyToBoundary } from "../../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";

export async function GET(req: Request): Promise<Response> {
  const response = await proxyToBoundary(req, "agent-api", "/api/v1/audit/recent");
  return response ?? projectionResponse({
    status: "degraded",
    events: projectedAuditEvents(),
    audit_persisted: false,
    note: "No Agent API audit store is reachable; projected contract markers are not persisted audit rows.",
  });
}

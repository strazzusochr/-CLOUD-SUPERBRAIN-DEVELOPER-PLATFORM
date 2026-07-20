import { projectionResponse, proxyToBoundary } from "../../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";

export async function GET(req: Request): Promise<Response> {
  const response = await proxyToBoundary(req, "agent-api", "/api/v1/rotation/events");
  return response ?? projectionResponse({
    contract_version: "provider-fallback-event-v1",
    evidence_ref: "provider_rotation_feed_unavailable",
    status: "degraded",
    read_only: true,
    events: [],
    audit_persisted: false,
    note: "No Agent API rotation audit feed is reachable; no provider rotation is claimed.",
  });
}

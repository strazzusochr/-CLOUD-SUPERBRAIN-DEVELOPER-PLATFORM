import { projectionResponse, proxyReadToBoundary } from "../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";

export async function GET(req: Request): Promise<Response> {
  const response = await proxyReadToBoundary(req, "agent-api", "/api/v1/builds");
  if (response) return response;
  return projectionResponse({
    status: "degraded",
    builds: [],
    persisted: false,
    reason: "agent_api_build_registry_unavailable_or_not_implemented",
    note: "No Agent API build registry is reachable; no builds are claimed.",
  });
}

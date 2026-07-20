import { projectionResponse, proxyToBoundary } from "../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";

export async function GET(req: Request): Promise<Response> {
  const response = await proxyToBoundary(req, "agent-api", "/api/v1/builds");
  if (response && response.status !== 404) return response;
  return projectionResponse({
    status: "degraded",
    builds: [],
    persisted: false,
    reason: response?.status === 404 ? "agent_api_build_registry_not_implemented" : "agent_api_unavailable",
    note: "No Agent API build registry is reachable; no builds are claimed.",
  });
}

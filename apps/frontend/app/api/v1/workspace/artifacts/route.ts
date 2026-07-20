import { boundaryUnavailable, projectionResponse, proxyToBoundary } from "../../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";

export async function GET(req: Request): Promise<Response> {
  const response = await proxyToBoundary(req, "agent-api", "/api/v1/workspace/artifacts");
  return response ?? projectionResponse({
    contract_version: "workspace-artifact-registry-v1",
    status: "degraded",
    artifacts: [],
    count: 0,
    persisted: false,
    note: "No Agent API artifact registry is reachable; no artifacts are claimed.",
  });
}

export async function POST(req: Request): Promise<Response> {
  const response = await proxyToBoundary(req, "agent-api", "/api/v1/workspace/artifacts");
  return response ?? boundaryUnavailable("POST /api/v1/workspace/artifacts", "agent-api");
}

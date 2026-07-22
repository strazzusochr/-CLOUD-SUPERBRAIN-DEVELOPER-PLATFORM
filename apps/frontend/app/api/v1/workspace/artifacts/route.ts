import { authorizeBoundaryWrite, boundaryUnavailable, projectionResponse, proxyReadToBoundary, proxyToBoundary } from "../../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";

export async function GET(req: Request): Promise<Response> {
  const response = await proxyReadToBoundary(req, "agent-api", "/api/v1/workspace/artifacts");
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
  const writeBlock = authorizeBoundaryWrite(req);
  if (writeBlock) return writeBlock;
  const response = await proxyToBoundary(req, "agent-api", "/api/v1/workspace/artifacts", 8_000, { serviceAuth: true });
  return response ?? boundaryUnavailable("POST /api/v1/workspace/artifacts", "agent-api");
}

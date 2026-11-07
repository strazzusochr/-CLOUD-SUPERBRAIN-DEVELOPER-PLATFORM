import { authorizeBoundaryWrite, boundaryUnavailable, projectionResponse, proxyReadToBoundary, proxyWorkspaceToBoundary, requireWorkspaceIdentity } from "../../../../../lib/frontendBoundary";

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
  const writeBlock = await authorizeBoundaryWrite(req);
  if (writeBlock) return writeBlock;
  const identity = await requireWorkspaceIdentity(req);
  if (identity instanceof Response) return identity;
  const response = await proxyWorkspaceToBoundary(req, "/api/v1/workspace/artifacts", identity);
  return response ?? boundaryUnavailable("POST /api/v1/workspace/artifacts", "agent-api");
}

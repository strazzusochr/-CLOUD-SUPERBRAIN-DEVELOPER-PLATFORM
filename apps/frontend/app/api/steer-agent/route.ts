import { authorizeBoundaryWrite, boundaryUnavailable, proxyToBoundary } from "../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";

export async function POST(req: Request): Promise<Response> {
  const writeBlock = await authorizeBoundaryWrite(req);
  if (writeBlock) return writeBlock;
  const response = await proxyToBoundary(req, "agent-api", "/api/steer-agent", 60_000, { serviceAuth: true });
  return response ?? boundaryUnavailable("POST /api/steer-agent", "agent-api");
}

import { authorizeBoundaryWrite, boundaryUnavailable, proxyToBoundary } from "../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";
export const maxDuration = 60;

export async function POST(req: Request): Promise<Response> {
  const writeBlock = await authorizeBoundaryWrite(req);
  if (writeBlock) return writeBlock;
  const response = await proxyToBoundary(req, "agent-api", "/api/v1/prompt", 60_000, { serviceAuth: true });
  return response ?? boundaryUnavailable("POST /api/v1/prompt", "agent-api");
}

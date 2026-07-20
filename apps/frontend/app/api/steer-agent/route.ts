import { boundaryUnavailable, proxyToBoundary } from "../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";

export async function POST(req: Request): Promise<Response> {
  const response = await proxyToBoundary(req, "agent-api", "/api/steer-agent", 60_000);
  return response ?? boundaryUnavailable("POST /api/steer-agent", "agent-api");
}

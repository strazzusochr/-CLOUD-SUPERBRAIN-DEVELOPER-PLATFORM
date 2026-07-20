import { boundaryUnavailable, proxyToBoundary } from "../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";
export const maxDuration = 60;

export async function POST(req: Request): Promise<Response> {
  const response = await proxyToBoundary(req, "agent-api", "/api/v1/prompt", 60_000);
  return response ?? boundaryUnavailable("POST /api/v1/prompt", "agent-api");
}

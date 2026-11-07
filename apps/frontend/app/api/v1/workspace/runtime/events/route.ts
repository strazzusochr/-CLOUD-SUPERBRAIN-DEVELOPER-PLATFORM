import {
  boundaryUnavailable,
  proxyWorkspaceToBoundary,
  requireWorkspaceIdentity,
} from "../../../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(req: Request): Promise<Response> {
  const identity = await requireWorkspaceIdentity(req);
  if (identity instanceof Response) return identity;
  const response = await proxyWorkspaceToBoundary(req, "/api/v1/workspace/runtime/events", identity);
  return response ?? boundaryUnavailable(
    "GET /api/v1/workspace/runtime/events",
    "agent-api",
    "The personal runtime event boundary is unavailable; no shared activity feed was substituted.",
  );
}

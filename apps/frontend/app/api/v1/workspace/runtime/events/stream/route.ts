import {
  boundaryUnavailable,
  proxyWorkspaceToBoundary,
  requireWorkspaceIdentity,
} from "../../../../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(req: Request): Promise<Response> {
  const identity = await requireWorkspaceIdentity(req);
  if (identity instanceof Response) return identity;
  const query = new URL(req.url).search;
  const response = await proxyWorkspaceToBoundary(req, `/api/v1/workspace/runtime/events/stream${query}`, identity);
  return response ?? boundaryUnavailable(
    "GET /api/v1/workspace/runtime/events/stream",
    "agent-api",
    "The personal runtime event stream boundary is unavailable; no shared stream was substituted.",
  );
}

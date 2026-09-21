import {
  boundaryUnavailable,
  proxyWorkspaceToBoundary,
  requireWorkspaceIdentity,
} from "../../../../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(req: Request, { params }: { params: Promise<{ eventId: string }> }): Promise<Response> {
  const identity = await requireWorkspaceIdentity(req);
  if (identity instanceof Response) return identity;
  const { eventId } = await params;
  const response = await proxyWorkspaceToBoundary(
    req,
    `/api/v1/workspace/runtime/events/${encodeURIComponent(eventId)}`,
    identity,
  );
  return response ?? boundaryUnavailable(
    "GET /api/v1/workspace/runtime/events/:eventId",
    "agent-api",
    "The personal runtime event detail boundary is unavailable; no shared event was substituted.",
  );
}

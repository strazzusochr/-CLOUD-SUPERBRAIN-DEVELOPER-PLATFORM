import {
  boundaryUnavailable,
  proxyWorkspaceToBoundary,
  requireWorkspaceIdentity,
} from "../../../../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(req: Request, { params }: { params: Promise<{ traceId: string }> }): Promise<Response> {
  const identity = await requireWorkspaceIdentity(req);
  if (identity instanceof Response) return identity;
  const { traceId } = await params;
  const response = await proxyWorkspaceToBoundary(
    req,
    `/api/v1/workspace/runtime/traces/${encodeURIComponent(traceId)}`,
    identity,
  );
  return response ?? boundaryUnavailable(
    "GET /api/v1/workspace/runtime/traces/:traceId",
    "agent-api",
    "The personal runtime trace boundary is unavailable; no shared trace was substituted.",
  );
}

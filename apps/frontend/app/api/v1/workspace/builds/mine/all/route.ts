import {
  boundaryUnavailable,
  proxyWorkspaceToBoundary,
  requireWorkspaceIdentity,
} from "../../../../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

/** Cursorable owner-only continuation list; identity is always session-derived. */
export async function GET(req: Request): Promise<Response> {
  const identity = await requireWorkspaceIdentity(req);
  if (identity instanceof Response) return identity;
  const url = new URL(req.url);
  const path = `/api/v1/workspace/builds/mine/all${url.search}`;
  return (await proxyWorkspaceToBoundary(req, path, identity)) ?? boundaryUnavailable(
    "GET /api/v1/workspace/builds/mine/all",
    "agent-api",
    "The complete personal workspace list is unavailable; no shared build list was substituted.",
  );
}

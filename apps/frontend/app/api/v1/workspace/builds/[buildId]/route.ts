import {
  authorizePublicSecurityProbe,
  boundaryUnavailable,
  proxyWorkspaceToBoundary,
  requireWorkspaceIdentity,
} from "../../../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

type Ctx = { params: Promise<{ buildId: string }> };

export async function GET(req: Request, ctx: Ctx): Promise<Response> {
  const { buildId } = await ctx.params;
  if (!/^[A-Za-z0-9_-]{1,64}$/.test(buildId)) {
    return Response.json({ status: "not_found", persisted: false, secret_output: false }, { status: 404 });
  }
  const identity = await requireWorkspaceIdentity(req);
  if (identity instanceof Response) return identity;
  const response = await proxyWorkspaceToBoundary(
    req,
    `/api/v1/workspace/builds/${encodeURIComponent(buildId)}`,
    identity,
  );
  return response ?? boundaryUnavailable(
    "GET /api/v1/workspace/builds/:id",
    "agent-api",
    "The personal workspace boundary is unavailable; no shared build was substituted.",
  );
}

export async function DELETE(req: Request, ctx: Ctx): Promise<Response> {
  const { buildId } = await ctx.params;
  if (!/^[A-Za-z0-9_-]{1,64}$/.test(buildId)) {
    return Response.json({ status: "not_found", persisted: false, secret_output: false }, { status: 404 });
  }
  const originBlock = authorizePublicSecurityProbe(req);
  if (originBlock) return originBlock;
  const identity = await requireWorkspaceIdentity(req);
  if (identity instanceof Response) return identity;
  const response = await proxyWorkspaceToBoundary(
    req,
    `/api/v1/workspace/builds/${encodeURIComponent(buildId)}`,
    identity,
  );
  return response ?? boundaryUnavailable(
    "DELETE /api/v1/workspace/builds/:id",
    "agent-api",
    "The personal workspace boundary is unavailable; no build was deleted.",
  );
}

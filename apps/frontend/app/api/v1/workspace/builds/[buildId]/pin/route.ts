import {
  authorizePublicSecurityProbe,
  boundaryUnavailable,
  proxyWorkspaceToBoundary,
  requireWorkspaceIdentity,
} from "../../../../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

type Ctx = { params: Promise<{ buildId: string }> };

async function mutate(req: Request, ctx: Ctx, method: "PUT" | "DELETE"): Promise<Response> {
  const { buildId } = await ctx.params;
  if (!/^[A-Za-z0-9_-]{1,64}$/.test(buildId)) {
    return Response.json({ status: "not_found", persisted: false, secret_output: false }, { status: 404 });
  }
  const originBlock = authorizePublicSecurityProbe(req);
  if (originBlock) return originBlock;
  const identity = await requireWorkspaceIdentity(req);
  if (identity instanceof Response) return identity;
  const request = new Request(req.url, { method, headers: req.headers });
  const response = await proxyWorkspaceToBoundary(
    request,
    `/api/v1/workspace/builds/${encodeURIComponent(buildId)}/pin`,
    identity,
  );
  return response ?? boundaryUnavailable(
    `${method} /api/v1/workspace/builds/:id/pin`,
    "agent-api",
    "The personal workspace boundary is unavailable; pin state was not changed.",
  );
}

export async function PUT(req: Request, ctx: Ctx): Promise<Response> {
  return mutate(req, ctx, "PUT");
}

export async function DELETE(req: Request, ctx: Ctx): Promise<Response> {
  return mutate(req, ctx, "DELETE");
}

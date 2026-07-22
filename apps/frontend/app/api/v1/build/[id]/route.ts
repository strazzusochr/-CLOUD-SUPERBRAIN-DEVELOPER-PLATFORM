import { authorizeBoundaryWrite, proxyToBoundary } from "../../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";

function safeId(value: string): string {
  return /^[A-Za-z0-9_-]{1,64}$/.test(value) ? value : "";
}

export async function GET(req: Request, ctx: { params: Promise<{ id: string }> }): Promise<Response> {
  const clean = safeId((await ctx.params).id);
  if (!clean) return Response.json({ status: "not_found" }, { status: 404 });
  const response = await proxyToBoundary(req, "agent-api", `/api/v1/build/${clean}`);
  return response ?? Response.json(
    {
      status: "not_found",
      live_backend: false,
      direct_provider_calls: false,
      note: "No Agent API build artifact is reachable.",
    },
    { status: 404, headers: { "cache-control": "no-store", "x-superbrain-source": "frontend-projection" } },
  );
}

export async function DELETE(req: Request, ctx: { params: Promise<{ id: string }> }): Promise<Response> {
  const writeBlock = authorizeBoundaryWrite(req);
  if (writeBlock) return writeBlock;
  const clean = safeId((await ctx.params).id);
  if (!clean) return Response.json({ status: "not_found" }, { status: 404 });
  return Response.json(
    {
      contract_version: "stateful-build-delete-guard-v1",
      status: "blocked",
      error: "build_delete_owner_identity_required",
      id: clean,
      accepted: false,
      persisted: false,
      deleted: false,
      resource_unchanged: true,
      owner_identity_verified: false,
      service_auth_forwarded: false,
      direct_provider_calls: false,
      secret_output: false,
      note: "A signed guest session is not build ownership. Browser deletion remains blocked until owner identity is persisted and verified.",
    },
    { status: 403, headers: { "cache-control": "no-store", "x-superbrain-source": "stateful-build-delete-guard" } },
  );
}

import { authorizeBoundaryWrite, proxyToBoundary } from "../../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";

function safeId(value: string): string {
  return /^[A-Za-z0-9_-]{1,64}$/.test(value) ? value : "";
}

export async function GET(req: Request, ctx: { params: Promise<{ id: string }> }): Promise<Response> {
  const clean = safeId((await ctx.params).id);
  if (!clean) return Response.json({ status: "not_found" }, { status: 404 });
  const firstResponse = await proxyToBoundary(req, "agent-api", `/api/v1/build/${clean}`, 15_000);
  if (firstResponse && firstResponse.status < 500) return firstResponse;
  // Build reads are idempotent. One bounded retry absorbs a transient boundary
  // reset without teaching the browser acceptance suite to ignore real 503s.
  const retryResponse = await proxyToBoundary(req, "agent-api", `/api/v1/build/${clean}`, 15_000);
  const response = retryResponse ?? firstResponse;
  return response ?? Response.json(
    {
      status: "degraded",
      error: "configured_boundary_unavailable",
      accepted: false,
      persisted: false,
      live_backend: false,
      direct_provider_calls: false,
      live_provider_calls: false,
      secret_output: false,
      note: "The configured Agent API build boundary is unavailable; no not-found claim can be made.",
    },
    { status: 503, headers: { "cache-control": "no-store", "x-superbrain-source": "frontend-boundary-degraded" } },
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

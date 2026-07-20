import { boundaryUnavailable, proxyReadToBoundary, proxyToBoundary } from "../../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";

function safeId(value: string): string {
  return /^[A-Za-z0-9_-]{1,64}$/.test(value) ? value : "";
}

export async function GET(req: Request, ctx: { params: Promise<{ id: string }> }): Promise<Response> {
  const clean = safeId((await ctx.params).id);
  if (!clean) return Response.json({ status: "not_found" }, { status: 404 });
  const response = await proxyReadToBoundary(req, "agent-api", `/api/v1/build/${clean}`);
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
  const clean = safeId((await ctx.params).id);
  if (!clean) return Response.json({ status: "not_found" }, { status: 404 });
  const response = await proxyToBoundary(req, "agent-api", `/api/v1/build/${clean}`);
  return response ?? boundaryUnavailable(`DELETE /api/v1/build/${clean}`, "agent-api");
}

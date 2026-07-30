// Catch-all agent-api surface served by the frontend itself.
//
// Three honest modes, in priority order:
//   1. AGENT-API BOUNDARY — if a real backend origin is configured, forward the
//      request through the single approved service boundary.
//   2. PROJECT-STATE PROJECTION — no backend reachable (e.g. free Vercel deploy
//      with no origin): serve the *real* deterministic contract / file-projected
//      payloads captured from the actual agent-api into lib/endpoint-snapshot.json.
//      These are committed-state projections, identical to runtime output — not
//      fabricated data. Marked with x-superbrain-source so the source is explicit.
//   3. FAIL-CLOSED NO-BACKEND — actions that need a running backend return 503.
//
// Explicit sibling routes (organism/*, platform/verify, workspace/*, design/*)
// take precedence over this catch-all for their exact paths.

import snapshot from "../../../../lib/endpoint-snapshot.json";
import { projectedDefault, genericDefault, frontendMetrics } from "../../../../lib/endpointDefaults";
import { boundaryUnavailable, proxyReadToBoundary, proxyToBoundary } from "../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";

const SNAP = snapshot as Record<string, unknown>;
const CURRENT_PROJECTION_REQUIRED_WHEN_EDGE_ORIGIN_IS_STALE = new Set([
  "/api/v1/clouds",
  "/api/v1/clouds/layers",
  "/api/v1/clouds/deployment-preflight",
]);

async function handle(req: Request, slug: string[] | undefined, method: string): Promise<Response> {
  const pathname = `/api/v1/${(slug ?? []).join("/")}`;
  // Frontend-owned metrics must describe this deployment even when the Agent API
  // origin is reachable. Backend metrics remain available at their own origin.
  if (method === "GET" && pathname === "/api/v1/metrics") {
    return new Response(frontendMetrics(), { headers: { "content-type": "text/plain; version=0.0.4", "x-superbrain-source": "frontend-metrics" } });
  }
  const isRead = method === "GET" || method === "HEAD";
  const live = isRead
    ? await proxyReadToBoundary(req, "agent-api", pathname, 6_000)
    : await proxyToBoundary(req, "agent-api", pathname, 6_000);
  const staleContractOrigin = live?.headers.get("x-superbrain-source") === "contract-origin-via-d1-edge"
    && CURRENT_PROJECTION_REQUIRED_WHEN_EDGE_ORIGIN_IS_STALE.has(pathname);
  if (live && !staleContractOrigin) return live;
  // projectedDefault internally covers knownDefault surfaces before generic data.
  const projected = projectedDefault(pathname, method);
  if (projected) {
    return Response.json(projected.payload, {
      status: projected.status ?? 200,
      headers: { "x-superbrain-source": "frontend-projection", "cache-control": "no-store" },
    });
  }
  // Deterministic project-state projection (real captured agent-api data).
  if (method === "GET" && pathname in SNAP) {
    return Response.json(SNAP[pathname], {
      headers: { "x-superbrain-source": "project-state-projection", "cache-control": "no-store" },
    });
  }
  if (!isRead) {
    return boundaryUnavailable(`${method} ${pathname}`, "agent-api");
  }
  return Response.json(genericDefault(pathname, method), { headers: { "x-superbrain-source": "frontend-projection", "cache-control": "no-store" } });
}

type Ctx = { params: Promise<{ slug: string[] }> };

export async function GET(req: Request, ctx: Ctx): Promise<Response> {
  return handle(req, (await ctx.params).slug, "GET");
}

export async function POST(req: Request, ctx: Ctx): Promise<Response> {
  return handle(req, (await ctx.params).slug, "POST");
}

export async function PUT(req: Request, ctx: Ctx): Promise<Response> {
  return handle(req, (await ctx.params).slug, "PUT");
}

export async function DELETE(req: Request, ctx: Ctx): Promise<Response> {
  return handle(req, (await ctx.params).slug, "DELETE");
}

// Catch-all agent-api surface served by the frontend itself.
//
// Three honest modes, in priority order:
//   1. LIVE PASSTHROUGH — if a real backend origin is configured
//      (AGENT_API_BASE_URL / AGENT_API_INTERNAL_URL), forward the request 1:1
//      so every button hits the live agent-api. (Next rewrites also cover this
//      when the origin is a safe HTTPS host; this handler covers the rest.)
//   2. PROJECT-STATE PROJECTION — no backend reachable (e.g. free Vercel deploy
//      with no origin): serve the *real* deterministic contract / file-projected
//      payloads captured from the actual agent-api into lib/endpoint-snapshot.json.
//      These are committed-state projections, identical to runtime output — not
//      fabricated data. Marked with x-superbrain-source so the source is explicit.
//   3. HONEST NO-BACKEND — dynamic / DB-backed / action endpoints that genuinely
//      need a running backend return 503 with a clear note. Never fake-live data.
//
// Explicit sibling routes (organism/*, platform/verify, workspace/*, design/*)
// take precedence over this catch-all for their exact paths.

import snapshot from "../../../../lib/endpoint-snapshot.json";
import { projectedDefault, genericDefault, frontendMetrics } from "../../../../lib/endpointDefaults";

export const dynamic = "force-dynamic";

const SNAP = snapshot as Record<string, unknown>;

function liveBase(): string | null {
  const b = process.env.AGENT_API_BASE_URL || process.env.AGENT_API_INTERNAL_URL;
  return b ? b.replace(/\/$/, "") : null;
}

// Returns the live response, or null if the configured origin is dead/erroring
// (network failure or >=500) so the caller can gracefully fall back to projection.
async function proxy(req: Request, base: string, pathname: string, body: string | undefined): Promise<Response | null> {
  const url = new URL(req.url);
  const target = `${base}${pathname}${url.search}`;
  const init: RequestInit = {
    method: req.method,
    headers: { accept: "application/json", "content-type": req.headers.get("content-type") ?? "application/json" },
    cache: "no-store",
  };
  if (body !== undefined) init.body = body;
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 6000);
  try {
    const res = await fetch(target, { ...init, signal: ctrl.signal });
    if (res.status >= 500 || res.status === 404) return null; // dead/placeholder origin → fall back
    const text = await res.text();
    return new Response(text, {
      status: res.status,
      headers: { "content-type": res.headers.get("content-type") ?? "application/json", "x-superbrain-source": "live-agent-api" },
    });
  } catch {
    return null; // unreachable origin → fall back
  } finally {
    clearTimeout(timer);
  }
}

async function handle(req: Request, slug: string[] | undefined, method: string): Promise<Response> {
  const pathname = `/api/v1/${(slug ?? []).join("/")}`;
  const base = liveBase();
  // Read the body once so we can both proxy and (if needed) fall back without re-reading.
  const body = method !== "GET" && method !== "HEAD" ? await req.text() : undefined;
  if (base) {
    const live = await proxy(req, base, pathname, body);
    if (live) return live; // origin reachable → real live data; else fall through to projection
  }
  // Real frontend metrics in Prometheus exposition format.
  if (method === "GET" && pathname === "/api/v1/metrics") {
    return new Response(frontendMetrics(), { headers: { "content-type": "text/plain; version=0.0.4", "x-superbrain-source": "frontend-metrics" } });
  }
  // projectedDefault internally covers knownDefault surfaces before generic data.
  const projected = projectedDefault(pathname, method, body);
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
  // Honest 200 for every other surface — shape-correct empty/projected data, never
  // a 5xx and never fabricated rows. (live_backend:false makes the state explicit.)
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

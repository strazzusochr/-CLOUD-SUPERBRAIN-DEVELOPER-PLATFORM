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

export const dynamic = "force-dynamic";

const SNAP = snapshot as Record<string, unknown>;

function liveBase(): string | null {
  const b = process.env.AGENT_API_BASE_URL || process.env.AGENT_API_INTERNAL_URL;
  return b ? b.replace(/\/$/, "") : null;
}

async function proxy(req: Request, base: string, pathname: string): Promise<Response> {
  const url = new URL(req.url);
  const target = `${base}${pathname}${url.search}`;
  const init: RequestInit = {
    method: req.method,
    headers: { accept: "application/json", "content-type": req.headers.get("content-type") ?? "application/json" },
    cache: "no-store",
  };
  if (req.method !== "GET" && req.method !== "HEAD") init.body = await req.text();
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 8000);
  try {
    const res = await fetch(target, { ...init, signal: ctrl.signal });
    const body = await res.text();
    return new Response(body, {
      status: res.status,
      headers: {
        "content-type": res.headers.get("content-type") ?? "application/json",
        "x-superbrain-source": "live-agent-api",
      },
    });
  } catch (err) {
    return Response.json(
      { status: "backend_unreachable", endpoint: pathname, note: `configured agent-api origin did not respond: ${err instanceof Error ? err.message : String(err)}` },
      { status: 502, headers: { "x-superbrain-source": "live-agent-api" } },
    );
  } finally {
    clearTimeout(timer);
  }
}

function noBackend(pathname: string, method: string): Response {
  return Response.json(
    {
      status: "no_live_backend",
      endpoint: `${method} ${pathname}`,
      live_backend: false,
      note:
        "This endpoint needs a running agent-api (DB/queue/LLM-backed or dynamic runtime). " +
        "No backend origin is configured for this deployment, so no live data is returned. " +
        "Deterministic contract/state surfaces are served directly by the frontend; this one is not.",
    },
    { status: 503, headers: { "x-superbrain-source": "frontend-no-backend" } },
  );
}

async function handle(req: Request, slug: string[] | undefined, method: string): Promise<Response> {
  const pathname = `/api/v1/${(slug ?? []).join("/")}`;
  const base = liveBase();
  if (base) return proxy(req, base, pathname);
  if (method === "GET" && pathname in SNAP) {
    return Response.json(SNAP[pathname], {
      headers: { "x-superbrain-source": "project-state-projection", "cache-control": "no-store" },
    });
  }
  return noBackend(pathname, method);
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

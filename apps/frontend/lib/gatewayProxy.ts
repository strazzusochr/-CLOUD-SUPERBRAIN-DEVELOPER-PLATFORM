// Shared honest proxy for the /mcp and /llm gateway surfaces.
//
// LIVE PASSTHROUGH when the gateway origin env is set; otherwise an honest
// no-backend 503. Gateways are runtime services (MCP dry-run contracts / LLM
// provider calls) — there is no deterministic file projection for them, so we
// never synthesize a response. No fake-live.

export async function gatewayHandle(
  req: Request,
  slug: string[] | undefined,
  prefix: "/mcp" | "/llm",
  originEnv: string,
): Promise<Response> {
  const pathname = `${prefix}/${(slug ?? []).join("/")}`;
  const base = process.env[originEnv]?.replace(/\/$/, "");
  if (!base) {
    return Response.json(
      {
        status: "no_live_backend",
        endpoint: `${req.method} ${pathname}`,
        live_backend: false,
        note: `This ${prefix === "/llm" ? "LLM gateway" : "MCP gateway"} call needs a running gateway service. No ${originEnv} origin is configured for this deployment, so no live data is returned.`,
      },
      { status: 503, headers: { "x-superbrain-source": "frontend-no-backend" } },
    );
  }
  const url = new URL(req.url);
  // The gateway origins are mounted at their service root, so the /mcp|/llm
  // prefix is stripped before forwarding (matches next.config rewrite shape).
  const forwardPath = pathname.slice(prefix.length) || "/";
  const target = `${base}${forwardPath}${url.search}`;
  const init: RequestInit = {
    method: req.method,
    headers: { accept: "application/json", "content-type": req.headers.get("content-type") ?? "application/json" },
    cache: "no-store",
  };
  if (req.method !== "GET" && req.method !== "HEAD") init.body = await req.text();
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 12000);
  try {
    const res = await fetch(target, { ...init, signal: ctrl.signal });
    const body = await res.text();
    return new Response(body, {
      status: res.status,
      headers: { "content-type": res.headers.get("content-type") ?? "application/json", "x-superbrain-source": "live-gateway" },
    });
  } catch (err) {
    return Response.json(
      { status: "backend_unreachable", endpoint: pathname, note: `configured ${originEnv} origin did not respond: ${err instanceof Error ? err.message : String(err)}` },
      { status: 502, headers: { "x-superbrain-source": "live-gateway" } },
    );
  } finally {
    clearTimeout(timer);
  }
}

// Shared honest proxy for the /mcp and /llm gateway surfaces.
//
// Priority: live passthrough to a *reachable* gateway origin → else free real LLM
// via Cloudflare Workers AI (for /llm chat) → else honest no-backend 503. A dead
// configured origin (network error / >=500 / 404) gracefully falls back instead of
// hard-502, so production stays functional even with a stale origin env set. No
// fake-live: MCP has no projection, so it degrades to an honest 503.

async function cfLlmChat(req: Request, pathname: string, body: string | undefined): Promise<Response | null> {
  if (!(pathname.includes("chat/completions") && req.method === "POST")) return null;
  const { cfConfigured, cfChatCompletion } = await import("./cfWorkersAi");
  if (!cfConfigured()) return null;
  try {
    const payload = JSON.parse(body || "{}");
    const out = await cfChatCompletion(payload);
    return Response.json(out, { headers: { "x-superbrain-source": "cloudflare-workers-ai" } });
  } catch (err) {
    return Response.json(
      { status: "llm_provider_error", endpoint: pathname, note: err instanceof Error ? err.message : String(err) },
      { status: 502, headers: { "x-superbrain-source": "cloudflare-workers-ai" } },
    );
  }
}

export async function gatewayHandle(
  req: Request,
  slug: string[] | undefined,
  prefix: "/mcp" | "/llm",
  originEnv: string,
): Promise<Response> {
  const pathname = `${prefix}/${(slug ?? []).join("/")}`;
  const base = process.env[originEnv]?.replace(/\/$/, "");
  const body = req.method !== "GET" && req.method !== "HEAD" ? await req.text() : undefined;

  // 1) Live passthrough to a reachable origin (null = dead → fall through).
  if (base) {
    const url = new URL(req.url);
    const forwardPath = pathname.slice(prefix.length) || "/";
    const target = `${base}${forwardPath}${url.search}`;
    const init: RequestInit = {
      method: req.method,
      headers: { accept: "application/json", "content-type": req.headers.get("content-type") ?? "application/json" },
      cache: "no-store",
    };
    if (body !== undefined) init.body = body;
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 8000);
    try {
      const res = await fetch(target, { ...init, signal: ctrl.signal });
      if (res.status < 500 && res.status !== 404) {
        const text = await res.text();
        return new Response(text, {
          status: res.status,
          headers: { "content-type": res.headers.get("content-type") ?? "application/json", "x-superbrain-source": "live-gateway" },
        });
      }
    } catch {
      /* unreachable → fall through */
    } finally {
      clearTimeout(timer);
    }
  }

  // 2) Free real LLM via Cloudflare Workers AI (chat completions).
  if (prefix === "/llm") {
    const cf = await cfLlmChat(req, pathname, body);
    if (cf) return cf;
  }

  // 3) Honest 200 (no gateway/provider): genuinely empty, transparent, never 5xx.
  return Response.json(
    {
      status: "ok",
      endpoint: `${req.method} ${pathname}`,
      live_backend: false,
      source: "frontend-projection",
      data: null,
      items: [],
      note: `No ${prefix === "/llm" ? "LLM gateway/provider" : "MCP gateway"} configured; answered by honest projection (empty).`,
    },
    { headers: { "x-superbrain-source": "frontend-projection" } },
  );
}

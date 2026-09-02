// Shared honest proxy for the /mcp and /llm gateway surfaces.
//
// Static contracts may be projected, but all runtime actions must cross the
// configured LLM or MCP gateway. No frontend provider fallback exists.

import { projectedDefault } from "./endpointDefaults";
import { boundaryUnavailable, proxyReadToBoundary, proxyToBoundary } from "./frontendBoundary";

export async function gatewayHandle(
  req: Request,
  slug: string[] | undefined,
  prefix: "/mcp" | "/llm",
  originEnv: string,
): Promise<Response> {
  const pathname = `${prefix}/${(slug ?? []).join("/")}`;
  const kind = prefix === "/llm" ? "llm-gateway" : "mcp-gateway";
  const forwardPath = pathname.slice(prefix.length) || "/";
  const isRead = req.method === "GET" || req.method === "HEAD";
  const live = isRead
    ? await proxyReadToBoundary(req, kind, forwardPath)
    : await proxyToBoundary(req, kind, forwardPath);
  if (live) return live;

  // 3) Deterministic contract projection for known gateway contract surfaces.
  const projected = projectedDefault(pathname, req.method);
  if (projected) {
    return Response.json(projected.payload, {
      status: projected.status ?? 200,
      headers: { "x-superbrain-source": "frontend-projection" },
    });
  }

  if (!isRead) {
    return boundaryUnavailable(`${req.method} ${pathname}`, kind);
  }
  return Response.json(
    {
      status: "degraded",
      endpoint: `${req.method} ${pathname}`,
      live_backend: false,
      source: "frontend-projection",
      data: null,
      items: [],
      direct_provider_calls: false,
      note: `No configured ${originEnv} boundary is reachable.`,
    },
    { headers: { "x-superbrain-source": "frontend-projection", "cache-control": "no-store" } },
  );
}

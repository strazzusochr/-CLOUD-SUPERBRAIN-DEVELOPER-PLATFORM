type BoundaryKind = "agent-api" | "llm-gateway" | "mcp-gateway";

type BoundaryConfig = {
  envNames: string[];
  responseSource: string;
};

const BOUNDARIES: Record<BoundaryKind, BoundaryConfig> = {
  "agent-api": {
    envNames: ["AGENT_API_BASE_URL", "AGENT_API_INTERNAL_URL"],
    responseSource: "agent-api-boundary",
  },
  "llm-gateway": {
    envNames: ["LLM_GATEWAY_BASE_URL"],
    responseSource: "llm-gateway-boundary",
  },
  "mcp-gateway": {
    envNames: ["MCP_GATEWAY_BASE_URL"],
    responseSource: "mcp-gateway-boundary",
  },
};

function configuredOrigin(kind: BoundaryKind): string | null {
  const config = BOUNDARIES[kind];
  for (const envName of config.envNames) {
    const raw = process.env[envName]?.trim();
    if (!raw) continue;
    try {
      const url = new URL(raw);
      const isInternal = envName.endsWith("_INTERNAL_URL");
      const isLocalHost = ["localhost", "127.0.0.1", "::1"].includes(url.hostname);
      const isDockerService = !url.hostname.includes(".") && /^[a-z0-9-]+$/i.test(url.hostname);
      const protocolAllowed = url.protocol === "https:" || (url.protocol === "http:" && (isInternal || isLocalHost || isDockerService));
      if (!protocolAllowed || url.username || url.password || url.search || url.hash) continue;
      return raw.replace(/\/$/, "");
    } catch {
      continue;
    }
  }
  return null;
}

function copyRequestHeaders(req: Request): Headers {
  const headers = new Headers({ accept: req.headers.get("accept") ?? "application/json" });
  for (const name of ["content-type", "authorization", "cookie", "x-csrf-token", "x-request-id", "traceparent"]) {
    const value = req.headers.get(name);
    if (value) headers.set(name, value);
  }
  return headers;
}

function copyResponseHeaders(response: Response, source: string): Headers {
  const headers = new Headers({
    "content-type": response.headers.get("content-type") ?? "application/json",
    "cache-control": response.headers.get("cache-control") ?? "no-store",
    "x-superbrain-boundary": source,
    "x-superbrain-source": response.headers.get("x-superbrain-source") ?? source,
  });
  for (const name of ["set-cookie", "www-authenticate", "retry-after"]) {
    const value = response.headers.get(name);
    if (value) headers.set(name, value);
  }
  return headers;
}

export async function proxyToBoundary(
  req: Request,
  kind: BoundaryKind,
  targetPath: string,
  timeoutMs = 8_000,
): Promise<Response | null> {
  const base = configuredOrigin(kind);
  if (!base) return null;

  const incoming = new URL(req.url);
  const target = new URL(`${base}${targetPath.startsWith("/") ? targetPath : `/${targetPath}`}${incoming.search}`);
  if (target.origin === incoming.origin) return null;

  const method = req.method.toUpperCase();
  const body = method === "GET" || method === "HEAD" ? undefined : await req.text();
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(target, {
      method,
      headers: copyRequestHeaders(req),
      body,
      cache: "no-store",
      redirect: "manual",
      signal: controller.signal,
    });
    return new Response(await response.arrayBuffer(), {
      status: response.status,
      headers: copyResponseHeaders(response, BOUNDARIES[kind].responseSource),
    });
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

export function boundaryUnavailable(
  endpoint: string,
  kind: BoundaryKind,
  note = "The configured service boundary is unavailable; no action was accepted.",
  status = 503,
): Response {
  return Response.json(
    {
      contract_version: "frontend-provider-boundary-v1",
      status: "blocked",
      error: "configured_boundary_unavailable",
      endpoint,
      required_boundary: kind,
      required_env: BOUNDARIES[kind].envNames,
      accepted: false,
      persisted: false,
      live_backend: false,
      direct_provider_calls: false,
      live_provider_calls: false,
      live_mcp_writes: false,
      production_deploy: false,
      secret_output: false,
      note,
    },
    {
      status,
      headers: {
        "cache-control": "no-store",
        "x-superbrain-boundary": BOUNDARIES[kind].responseSource,
        "x-superbrain-source": "frontend-boundary-blocked",
      },
    },
  );
}

export function projectionResponse(payload: Record<string, unknown>): Response {
  return Response.json(
    {
      ...payload,
      source: "frontend-projection",
      live_backend: false,
      direct_provider_calls: false,
      live_provider_calls: false,
      live_mcp_writes: false,
      production_deploy: false,
      secret_output: false,
    },
    { headers: { "cache-control": "no-store", "x-superbrain-source": "frontend-projection" } },
  );
}

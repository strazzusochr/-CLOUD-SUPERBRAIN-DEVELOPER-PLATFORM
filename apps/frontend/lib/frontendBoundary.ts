import {
  AUTH_SESSION_COOKIE,
  type AuthSessionClaims,
  type HostedAuthSessionCreation,
  isHostedAuthSessionInvalid,
  isHostedAuthSessionRevocation,
  isHostedAuthSessionToken,
  parseHostedAuthSessionCreation,
  parseHostedAuthSessionVerification,
  verifySignedAuthSession,
} from "./authSession";

type BoundaryKind = "agent-api" | "llm-gateway" | "mcp-gateway";

type BoundaryProxyOptions = {
  serviceAuth?: boolean;
};

export type HostedAuthSessionLookup =
  | { status: "valid"; claims: AuthSessionClaims }
  | { status: "invalid" }
  | { status: "unavailable" };

type BoundaryConfig = {
  envNames: string[];
  responseSource: string;
  authEnvName?: string;
  authHeaderName?: string;
};

const BOUNDARIES: Record<BoundaryKind, BoundaryConfig> = {
  "agent-api": {
    envNames: ["AGENT_API_BASE_URL", "AGENT_API_INTERNAL_URL"],
    responseSource: "agent-api-boundary",
    authEnvName: "AGENT_API_AUTH_TOKEN",
    authHeaderName: "x-superbrain-agent-token",
  },
  "llm-gateway": {
    envNames: ["LLM_GATEWAY_BASE_URL"],
    responseSource: "llm-gateway-boundary",
    authEnvName: "LLM_GATEWAY_AUTH_TOKEN",
    authHeaderName: "x-superbrain-gateway-token",
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

function cookieValue(header: string | null, name: string): string | null {
  if (!header) return null;
  for (const entry of header.split(";")) {
    const separator = entry.indexOf("=");
    if (separator < 1 || entry.slice(0, separator).trim() !== name) continue;
    const value = entry.slice(separator + 1).trim();
    return value || null;
  }
  return null;
}

function normalizedOrigin(value: string): string | null {
  const text = value.trim();
  if (!text || text.toLowerCase() === "null") return null;
  try {
    const url = new URL(text);
    if ((url.protocol !== "http:" && url.protocol !== "https:") || url.username || url.password) return null;
    if ((url.pathname !== "/" && url.pathname !== "") || url.search || url.hash) return null;
    return url.origin.toLowerCase();
  } catch {
    return null;
  }
}

function firstForwarded(value: string | null): string {
  return (value ?? "").split(",", 1)[0].trim();
}

function publicRequestOrigin(req: Request): string | null {
  const incoming = new URL(req.url);
  const forwardedProtocol = firstForwarded(req.headers.get("x-forwarded-proto"));
  const forwardedHost = firstForwarded(req.headers.get("x-forwarded-host"));
  const host = forwardedHost || firstForwarded(req.headers.get("host")) || incoming.host;
  const protocol = forwardedProtocol || incoming.protocol.replace(":", "");
  return normalizedOrigin(`${protocol}://${host}`);
}

export function isLocalDevelopmentRequest(req: Request): boolean {
  if (process.env.VERCEL === "1") return false;
  const origin = publicRequestOrigin(req);
  if (!origin) return false;
  const publicHostname = new URL(origin).hostname.toLowerCase();
  const requestHostname = new URL(req.url).hostname.toLowerCase();
  const localHostname = (hostname: string) =>
    hostname === "localhost" || hostname === "127.0.0.1" || hostname === "::1";
  return localHostname(publicHostname) && localHostname(requestHostname);
}

function writeBlocked(status: 401 | 403 | 503, error: string, reason: string): Response {
  return Response.json(
    {
      contract_version: "frontend-boundary-write-guard-v1",
      status: "blocked",
      error,
      reason,
      accepted: false,
      persisted: false,
      session_required: true,
      csrf_policy: "fetch_metadata_and_same_origin_guard",
      service_auth_forwarded: false,
      direct_provider_calls: false,
      live_mcp_writes: false,
      production_deploy: false,
      secret_output: false,
    },
    {
      status,
      headers: {
        "cache-control": "no-store",
        "x-superbrain-source": "frontend-boundary-write-guard",
        "x-superbrain-write-guard": "frontend-boundary-write-guard-v1",
      },
    },
  );
}

const MAX_HOSTED_SESSION_RESPONSE_BYTES = 16 * 1024;

async function readHostedSessionPayload(response: Response, forbiddenValue?: string): Promise<unknown | null> {
  const declaredLength = Number(response.headers.get("content-length") || 0);
  if (declaredLength > MAX_HOSTED_SESSION_RESPONSE_BYTES) return null;
  const bytes = new Uint8Array(await response.arrayBuffer());
  if (bytes.byteLength > MAX_HOSTED_SESSION_RESPONSE_BYTES) return null;
  const text = new TextDecoder().decode(bytes);
  if (forbiddenValue && text.includes(forbiddenValue)) return null;
  try {
    return JSON.parse(text) as unknown;
  } catch {
    return null;
  }
}

async function hostedSessionRequest(
  req: Request,
  path: "/api/v1/auth/sessions" | "/api/v1/auth/sessions/verify" | "/api/v1/auth/sessions/revoke",
  payload: Record<string, unknown>,
  forbiddenResponseValue?: string,
): Promise<{ status: number; payload: unknown } | null> {
  const target = new URL(path, req.url);
  const requestId = req.headers.get("x-request-id");
  const headers = new Headers({ "content-type": "application/json", accept: "application/json" });
  if (requestId) headers.set("x-request-id", requestId);
  const serviceRequest = new Request(target, {
    method: "POST",
    headers,
    body: JSON.stringify(payload),
  });
  const response = await proxyToBoundary(serviceRequest, "agent-api", path, 8_000, { serviceAuth: true });
  if (!response) return null;
  const responsePayload = await readHostedSessionPayload(response, forbiddenResponseValue);
  return responsePayload === null ? null : { status: response.status, payload: responsePayload };
}

export async function createHostedAuthSessionAtBoundary(
  req: Request,
  identity: { provider: "guest" | "name"; name: string },
): Promise<HostedAuthSessionCreation | null> {
  const result = await hostedSessionRequest(req, "/api/v1/auth/sessions", identity);
  return result?.status === 201 ? parseHostedAuthSessionCreation(result.payload) : null;
}

export async function verifyHostedAuthSessionAtBoundary(
  req: Request,
  token: string | null | undefined,
): Promise<HostedAuthSessionLookup> {
  if (!isHostedAuthSessionToken(token)) return { status: "invalid" };
  const result = await hostedSessionRequest(
    req,
    "/api/v1/auth/sessions/verify",
    { session_token: token },
    token,
  );
  if (!result || result.status !== 200) return { status: "unavailable" };
  const claims = parseHostedAuthSessionVerification(result.payload);
  if (claims) return { status: "valid", claims };
  return isHostedAuthSessionInvalid(result.payload) ? { status: "invalid" } : { status: "unavailable" };
}

export async function revokeHostedAuthSessionAtBoundary(
  req: Request,
  token: string | null | undefined,
): Promise<"processed" | "invalid" | "unavailable"> {
  if (!isHostedAuthSessionToken(token)) return "invalid";
  const result = await hostedSessionRequest(
    req,
    "/api/v1/auth/sessions/revoke",
    { session_token: token },
    token,
  );
  if (!result || result.status !== 200) return "unavailable";
  return isHostedAuthSessionRevocation(result.payload) ? "processed" : "unavailable";
}

/**
 * Reuses either the local signed session or the hosted opaque D1 session and
 * the Agent API's same-origin CSRF semantics before a browser request may
 * borrow a server-only service token. The service token itself is never
 * accepted from or returned to the browser.
 */
export async function authorizeBoundaryWrite(req: Request): Promise<Response | null> {
  const fetchSite = (req.headers.get("sec-fetch-site") ?? "").trim().toLowerCase();
  const suppliedOrigin = req.headers.get("origin");
  const actualOrigin = suppliedOrigin ? normalizedOrigin(suppliedOrigin) : null;
  const expectedOrigin = publicRequestOrigin(req);

  if (fetchSite === "cross-site") {
    return writeBlocked(403, "csrf_origin_rejected", "fetch_metadata_cross_site");
  }
  if (suppliedOrigin && !actualOrigin) {
    return writeBlocked(403, "csrf_origin_rejected", "invalid_or_null_origin");
  }
  if (!expectedOrigin) {
    return writeBlocked(403, "csrf_origin_rejected", "request_origin_unavailable");
  }
  if (actualOrigin && actualOrigin !== expectedOrigin) {
    return writeBlocked(403, "csrf_origin_rejected", "origin_mismatch");
  }

  const token = cookieValue(req.headers.get("cookie"), AUTH_SESSION_COOKIE);
  const session = verifySignedAuthSession(token);
  if (session.valid) return null;
  if (isHostedAuthSessionToken(token)) {
    const hostedSession = await verifyHostedAuthSessionAtBoundary(req, token);
    if (hostedSession.status === "valid") return null;
    if (hostedSession.status === "unavailable") {
      return writeBlocked(503, "write_session_verification_unavailable", "stateful_session_boundary_unavailable");
    }
    return writeBlocked(401, "write_session_required", "session_stateful_invalid");
  }
  if (!session.valid) {
    return writeBlocked(401, "write_session_required", `session_${session.reason}`);
  }
  return writeBlocked(401, "write_session_required", "session_invalid");
}

export async function proxyToBoundary(
  req: Request,
  kind: BoundaryKind,
  targetPath: string,
  timeoutMs = 8_000,
  options: BoundaryProxyOptions = {},
): Promise<Response | null> {
  const base = configuredOrigin(kind);
  if (!base) return null;

  const incoming = new URL(req.url);
  const target = new URL(`${base}${targetPath.startsWith("/") ? targetPath : `/${targetPath}`}${incoming.search}`);
  if (target.origin === incoming.origin) return null;

  const method = req.method.toUpperCase();
  const body = method === "GET" || method === "HEAD" ? undefined : await req.text();
  const headers = copyRequestHeaders(req);
  const config = BOUNDARIES[kind];
  const gatewayToken = config.authEnvName ? process.env[config.authEnvName]?.trim() : "";
  const attachConfiguredAuth = kind !== "agent-api" || options.serviceAuth === true;
  if (kind === "agent-api" && options.serviceAuth === true) {
    headers.delete("authorization");
    headers.delete("cookie");
    headers.delete("x-csrf-token");
  }
  if (attachConfiguredAuth && gatewayToken && config.authHeaderName) headers.set(config.authHeaderName, gatewayToken);
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(target, {
      method,
      headers,
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

export async function proxyReadToBoundary(
  req: Request,
  kind: BoundaryKind,
  targetPath: string,
  timeoutMs = 8_000,
): Promise<Response | null> {
  const method = req.method.toUpperCase();
  if (method !== "GET" && method !== "HEAD") return null;
  const response = await proxyToBoundary(req, kind, targetPath, timeoutMs);
  return response?.ok ? response : null;
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

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
  oauthRedirectPolicy?: "github-start" | "same-origin-callback";
  authSessionPolicy?: "identity" | "refresh" | "logout";
  forwardCsrfMetadata?: boolean;
};

const OAUTH_STATE_COOKIE = "__Host-sb_oauth_state";
const OAUTH_ACCESS_COOKIE = "__Host-sb_access";
const OAUTH_REFRESH_COOKIE = "__Host-sb_refresh";
const OAUTH_STATE_PATTERN = /^phase3-auth-state-[A-Za-z0-9_-]{32}$/;

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

type OrdinaryRequestHeaderPolicy = "public-read" | "public-json" | "service-json" | "gateway-json";

const ORDINARY_REQUEST_HEADER_ALLOWLISTS: Record<OrdinaryRequestHeaderPolicy, readonly string[]> = {
  "public-read": ["accept", "x-request-id", "traceparent"],
  "public-json": ["accept", "content-type", "x-request-id", "traceparent"],
  "service-json": ["accept", "content-type", "x-request-id", "traceparent"],
  "gateway-json": ["accept", "content-type", "x-request-id", "traceparent"],
};

function ordinaryRequestHeaderPolicy(
  kind: BoundaryKind,
  method: string,
  options: BoundaryProxyOptions,
): OrdinaryRequestHeaderPolicy {
  if (kind === "llm-gateway" || kind === "mcp-gateway") return "gateway-json";
  if (options.serviceAuth === true) return "service-json";
  return method === "GET" || method === "HEAD" ? "public-read" : "public-json";
}

function copyRequestHeaders(req: Request, policy: OrdinaryRequestHeaderPolicy): Headers {
  const headers = new Headers();
  for (const name of ORDINARY_REQUEST_HEADER_ALLOWLISTS[policy]) {
    const value = req.headers.get(name);
    if (value) headers.set(name, value);
  }
  if (!headers.has("accept")) headers.set("accept", "application/json");
  return headers;
}

function copyOAuthRequestHeaders(
  req: Request,
  policy: NonNullable<BoundaryProxyOptions["oauthRedirectPolicy"]>,
): Headers {
  const headers = new Headers({ accept: req.headers.get("accept") ?? "text/html" });
  for (const name of ["x-request-id", "traceparent"]) {
    const value = req.headers.get(name);
    if (value) headers.set(name, value);
  }
  if (policy === "same-origin-callback") {
    const state = cookieValue(req.headers.get("cookie"), OAUTH_STATE_COOKIE);
    if (state && OAUTH_STATE_PATTERN.test(state)) headers.set("cookie", `${OAUTH_STATE_COOKIE}=${state}`);
  }
  return headers;
}

function copyAuthSessionRequestHeaders(
  req: Request,
  policy: NonNullable<BoundaryProxyOptions["authSessionPolicy"]>,
): Headers {
  const headers = new Headers({ accept: req.headers.get("accept") ?? "application/json" });
  for (const name of ["x-request-id", "traceparent"]) {
    const value = req.headers.get(name);
    if (value) headers.set(name, value);
  }
  if (policy !== "identity") {
    const contentType = req.headers.get("content-type");
    if (contentType?.toLowerCase().startsWith("application/json")) headers.set("content-type", contentType);
  }
  const cookieName = policy === "identity" ? OAUTH_ACCESS_COOKIE : OAUTH_REFRESH_COOKIE;
  const value = cookieValue(req.headers.get("cookie"), cookieName);
  if (value) headers.set("cookie", `${cookieName}=${value}`);
  return headers;
}

function responseSetCookieHeaders(headers: Headers): string[] | null {
  const extended = headers as Headers & {
    getSetCookie?: () => string[];
    raw?: () => Record<string, string[]>;
  };
  if (typeof extended.getSetCookie === "function") {
    return extended.getSetCookie().filter(Boolean);
  }
  if (typeof extended.raw === "function") {
    return (extended.raw()["set-cookie"] ?? []).filter(Boolean);
  }
  // A combined Set-Cookie header cannot be split safely because Expires and
  // extension attributes may contain commas. Drop/deny it unless the runtime
  // exposes an enumerating API.
  return headers.has("set-cookie") ? null : [];
}

function copyResponseHeaders(response: Response, source: string): Headers {
  const headers = new Headers({
    "content-type": response.headers.get("content-type") ?? "application/json",
    "cache-control": response.headers.get("cache-control") ?? "no-store",
    "x-superbrain-boundary": source,
    "x-superbrain-source": response.headers.get("x-superbrain-source") ?? source,
  });
  for (const name of ["www-authenticate", "retry-after"]) {
    const value = response.headers.get(name);
    if (value) headers.set(name, value);
  }
  return headers;
}

type ParsedSetCookie = {
  name: string;
  value: string;
  attributes: ReadonlyMap<string, string | true>;
};

function parseSetCookie(value: string): ParsedSetCookie | null {
  if (!value || /[\r\n]/.test(value)) return null;
  const segments = value.split(";").map((segment) => segment.trim());
  const first = segments.shift() ?? "";
  const separator = first.indexOf("=");
  if (separator < 1) return null;
  const name = first.slice(0, separator);
  const rawValue = first.slice(separator + 1);
  if (!/^[!#$%&'*+.^_`|~0-9A-Za-z-]+$/.test(name)) return null;
  const cookieValue = rawValue.length >= 2 && rawValue.startsWith('"') && rawValue.endsWith('"')
    ? rawValue.slice(1, -1)
    : rawValue;
  if (/[;\u0000-\u001f\u007f]/.test(cookieValue)) return null;
  const attributes = new Map<string, string | true>();
  for (const segment of segments) {
    if (!segment) continue;
    const index = segment.indexOf("=");
    const key = (index < 0 ? segment : segment.slice(0, index)).trim().toLowerCase();
    const attributeValue = index < 0 ? true : segment.slice(index + 1).trim();
    if (!key || attributes.has(key)) return null;
    attributes.set(key, attributeValue);
  }
  return { name, value: cookieValue, attributes };
}

function validHostCookieShape(cookie: ParsedSetCookie, sameSite: "lax" | "strict"): boolean {
  const allowedAttributes = new Set(["path", "secure", "httponly", "samesite", "max-age", "expires"]);
  if ([...cookie.attributes.keys()].some((key) => !allowedAttributes.has(key))) return false;
  if (cookie.attributes.has("domain")) return false;
  return cookie.name.startsWith("__Host-")
    && cookie.attributes.get("secure") === true
    && cookie.attributes.get("httponly") === true
    && cookie.attributes.get("path") === "/"
    && String(cookie.attributes.get("samesite") ?? "").toLowerCase() === sameSite;
}

function validOAuthCookie(
  cookie: ParsedSetCookie,
  expectedState: string | null,
  mustClearState: boolean,
): boolean {
  if (cookie.name === OAUTH_STATE_COOKIE) {
    if (!validHostCookieShape(cookie, "lax")) return false;
    if (mustClearState) return cookie.value === "" && cookie.attributes.get("max-age") === "0";
    return expectedState !== null
      && cookie.value === expectedState
      && OAUTH_STATE_PATTERN.test(cookie.value)
      && cookie.attributes.get("max-age") === "600";
  }
  if (cookie.name === OAUTH_ACCESS_COOKIE) {
    return validHostCookieShape(cookie, "strict")
      && /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(cookie.value)
      && cookie.attributes.get("max-age") === "900";
  }
  if (cookie.name === OAUTH_REFRESH_COOKIE) {
    return validHostCookieShape(cookie, "strict")
      && /^csr_[A-Za-z0-9_-]{32,128}$/.test(cookie.value)
      && cookie.attributes.get("max-age") === "604800";
  }
  return false;
}

function validatedOAuthSetCookieHeaders(
  response: Response,
  policy: NonNullable<BoundaryProxyOptions["oauthRedirectPolicy"]>,
  safeLocation: string | null,
): string[] | null {
  const rawCookies = responseSetCookieHeaders(response.headers);
  if (rawCookies === null) return null;
  const parsed = rawCookies.map(parseSetCookie);
  if (parsed.some((cookie) => cookie === null)) return null;
  const cookies = parsed as ParsedSetCookie[];
  if (new Set(cookies.map((cookie) => cookie.name)).size !== cookies.length) return null;

  if (policy === "github-start") {
    if (safeLocation) {
      const state = new URL(safeLocation).searchParams.get("state");
      return cookies.length === 1 && validOAuthCookie(cookies[0], state, false) ? rawCookies : null;
    }
    return cookies.length === 0
      || (cookies.length === 1 && cookies[0].name === OAUTH_STATE_COOKIE && validOAuthCookie(cookies[0], null, true))
      ? rawCookies
      : null;
  }

  const authenticated = response.status === 200 || safeLocation === "/workbench";
  if (authenticated) {
    const expectedNames = new Set([OAUTH_STATE_COOKIE, OAUTH_ACCESS_COOKIE, OAUTH_REFRESH_COOKIE]);
    if (cookies.length !== expectedNames.size || cookies.some((cookie) => !expectedNames.has(cookie.name))) return null;
    return cookies.every((cookie) => validOAuthCookie(cookie, null, cookie.name === OAUTH_STATE_COOKIE))
      ? rawCookies
      : null;
  }
  if (cookies.length === 0) return rawCookies;
  return cookies.length === 1
    && cookies[0].name === OAUTH_STATE_COOKIE
    && validOAuthCookie(cookies[0], null, true)
    ? rawCookies
    : null;
}

function validClearedAuthCookie(cookie: ParsedSetCookie, name: string): boolean {
  const expires = cookie.attributes.get("expires");
  const expiresAt = typeof expires === "string" ? Date.parse(expires) : Number.NaN;
  return cookie.name === name
    && validHostCookieShape(cookie, "strict")
    && cookie.value === ""
    && cookie.attributes.get("max-age") === "0"
    && Number.isFinite(expiresAt)
    && expiresAt <= 0
    && new Date(expiresAt).toUTCString() === expires;
}

function validatedAuthSessionSetCookieHeaders(
  response: Response,
  policy: NonNullable<BoundaryProxyOptions["authSessionPolicy"]>,
): string[] | null {
  const rawCookies = responseSetCookieHeaders(response.headers);
  if (rawCookies === null) return null;
  const parsed = rawCookies.map(parseSetCookie);
  if (parsed.some((cookie) => cookie === null)) return null;
  const cookies = parsed as ParsedSetCookie[];
  if (new Set(cookies.map((cookie) => cookie.name)).size !== cookies.length) return null;

  if (policy === "identity") {
    if (response.status === 200) return cookies.length === 0 ? rawCookies : null;
    return cookies.length === 0
      || (cookies.length === 1 && validClearedAuthCookie(cookies[0], OAUTH_ACCESS_COOKIE))
      ? rawCookies
      : null;
  }
  if (policy === "refresh") {
    const expected = new Set([OAUTH_ACCESS_COOKIE, OAUTH_REFRESH_COOKIE]);
    if (response.status !== 200) {
      const canonicalClearStatuses = new Set([400, 401, 403, 503]);
      if (!canonicalClearStatuses.has(response.status)) return cookies.length === 0 ? rawCookies : null;
      return cookies.length === 2
        && cookies.every((cookie) => expected.has(cookie.name) && validClearedAuthCookie(cookie, cookie.name))
        ? rawCookies
        : null;
    }
    return cookies.length === 2
      && cookies.every((cookie) => expected.has(cookie.name) && validOAuthCookie(cookie, null, false))
      ? rawCookies
      : null;
  }

  if (response.status !== 200 && response.status !== 503) return cookies.length === 0 ? rawCookies : null;
  const expected = new Set([OAUTH_ACCESS_COOKIE, OAUTH_REFRESH_COOKIE]);
  return cookies.length === 2
    && cookies.every((cookie) => expected.has(cookie.name) && validClearedAuthCookie(cookie, cookie.name))
    ? rawCookies
    : null;
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

function safeOAuthRedirectLocation(
  req: Request,
  rawLocation: string | null,
  policy: NonNullable<BoundaryProxyOptions["oauthRedirectPolicy"]>,
): string | null {
  if (!rawLocation) return null;
  const publicOrigin = publicRequestOrigin(req);
  if (!publicOrigin) return null;
  try {
    const location = new URL(rawLocation, publicOrigin);
    if (location.username || location.password || location.hash) return null;
    if (policy === "github-start") {
      if (
        location.protocol !== "https:"
        || location.hostname.toLowerCase() !== "github.com"
        || location.port
        || location.pathname !== "/login/oauth/authorize"
      ) {
        return null;
      }
      const clientIds = location.searchParams.getAll("client_id");
      const redirectUris = location.searchParams.getAll("redirect_uri");
      const scopes = location.searchParams.getAll("scope");
      const states = location.searchParams.getAll("state");
      const queryKeys = [...location.searchParams.keys()].sort();
      if (
        queryKeys.join("|") !== "client_id|redirect_uri|scope|state"
        || location.searchParams.size !== 4
        || clientIds.length !== 1
        || !/^[A-Za-z0-9_-]{1,128}$/.test(clientIds[0])
        || redirectUris.length !== 1
        || scopes.length !== 1
        || scopes[0] !== "read:user"
        || states.length !== 1
        || !/^phase3-auth-state-[A-Za-z0-9_-]{32}$/.test(states[0])
      ) {
        return null;
      }
      const redirectUri = new URL(redirectUris[0]);
      if (
        redirectUri.origin.toLowerCase() !== publicOrigin
        || redirectUri.pathname !== "/api/v1/auth/callback"
        || redirectUri.search
        || redirectUri.hash
        || redirectUri.username
        || redirectUri.password
      ) {
        return null;
      }
      return location.toString();
    }
    if (location.origin.toLowerCase() !== publicOrigin) return null;
    if (location.pathname !== "/login" && location.pathname !== "/workbench") return null;
    if (location.search) return null;
    return location.pathname;
  } catch {
    return null;
  }
}

function blockedOAuthRedirect(): Response {
  return Response.json(
    {
      contract_version: "frontend-oauth-redirect-guard-v1",
      status: "blocked",
      error: "oauth_redirect_rejected",
      credentials_issued: false,
      secret_output: false,
    },
    {
      status: 502,
      headers: {
        "cache-control": "no-store",
        "referrer-policy": "no-referrer",
        "x-content-type-options": "nosniff",
        "x-superbrain-boundary": BOUNDARIES["agent-api"].responseSource,
        "x-superbrain-source": "frontend-oauth-redirect-guard",
      },
    },
  );
}

function validIncomingOAuthQuery(req: Request, targetPath: "/api/v1/auth/github" | "/api/v1/auth/callback"): boolean {
  const url = new URL(req.url);
  if (targetPath === "/api/v1/auth/github") return url.search === "";
  const keys = [...url.searchParams.keys()].sort();
  const keyShape = keys.join("|");
  if (url.searchParams.size !== 2 || (keyShape !== "code|state" && keyShape !== "error|state")) return false;
  const states = url.searchParams.getAll("state");
  if (states.length !== 1 || !OAUTH_STATE_PATTERN.test(states[0])) return false;
  const cookieState = cookieValue(req.headers.get("cookie"), OAUTH_STATE_COOKIE);
  if (cookieState !== states[0]) return false;
  if (keyShape === "code|state") {
    const codes = url.searchParams.getAll("code");
    return codes.length === 1 && codes[0].length >= 1 && codes[0].length <= 255 && !/[\u0000-\u001f\u007f]/.test(codes[0]);
  }
  const errors = url.searchParams.getAll("error");
  return errors.length === 1 && /^[A-Za-z0-9_.-]{1,64}$/.test(errors[0]);
}

export function isLocalDevelopmentRequest(req: Request): boolean {
  if (process.env.VERCEL === "1" || process.env.NODE_ENV !== "development") return false;
  const origin = publicRequestOrigin(req);
  if (!origin) return false;
  const publicHostname = new URL(origin).hostname.toLowerCase();
  const requestHostname = new URL(req.url).hostname.toLowerCase();
  const localHostname = (hostname: string) =>
    hostname === "localhost" || hostname === "127.0.0.1" || hostname === "::1" || hostname === "0.0.0.0";
  const forwardedHost = firstForwarded(req.headers.get("x-forwarded-host"));
  const trustedDevProxy = requestHostname === "frontend" && forwardedHost.length > 0;
  return localHostname(publicHostname) && (localHostname(requestHostname) || trustedDevProxy);
}

function writeBlocked(
  status: 401 | 403 | 503,
  error: string,
  reason: string,
  authResponse?: Response,
): Response {
  const blocked = Response.json(
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
  if (authResponse) {
    const clearedCookies = responseSetCookieHeaders(authResponse.headers);
    for (const cookie of clearedCookies ?? []) blocked.headers.append("set-cookie", cookie);
    const retryAfter = authResponse.headers.get("retry-after");
    if (retryAfter) blocked.headers.set("retry-after", retryAfter);
  }
  return blocked;
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

function isVerifiedOwnerIdentity(payload: unknown): boolean {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) return false;
  const envelope = payload as Record<string, unknown>;
  const identity = envelope.identity;
  if (!identity || typeof identity !== "object" || Array.isArray(identity)) return false;
  const claims = identity as Record<string, unknown>;
  const providerUserId = claims.provider_user_id;
  return envelope.status === "authenticated"
    && envelope.contract_version === "auth-github-jwt-refresh-v1"
    && envelope.owner_activation_granted === true
    && envelope.identity_verified === true
    && envelope.jwt_signature_verified === true
    && envelope.jwt_claims_verified === true
    && envelope.token_returned === false
    && envelope.cookie_returned === false
    && envelope.secret_output === false
    && envelope.live_github_oauth_call === false
    && claims.provider === "github"
    && Number.isSafeInteger(providerUserId)
    && Number(providerUserId) > 0
    && claims.subject === `github:${providerUserId}`;
}

async function authorizeHostedOwnerWrite(req: Request): Promise<Response | null> {
  const identityRequest = new Request(new URL("/api/v1/auth/me", req.url), {
    method: "GET",
    headers: req.headers,
  });
  const identityResponse = await proxyAuthSessionToBoundary(identityRequest, "/api/v1/auth/me", 8_000);
  if (!identityResponse) {
    return writeBlocked(503, "write_owner_identity_unavailable", "owner_identity_boundary_unavailable");
  }
  if (identityResponse.status === 401) {
    return writeBlocked(401, "write_owner_identity_required", "github_owner_identity_missing_or_invalid", identityResponse);
  }
  if (identityResponse.status === 403) {
    return writeBlocked(403, "write_owner_identity_forbidden", "github_owner_identity_not_allowed", identityResponse);
  }
  if (identityResponse.status !== 200) {
    return writeBlocked(503, "write_owner_identity_unavailable", "owner_identity_boundary_rejected", identityResponse);
  }
  const incomingAccessToken = cookieValue(req.headers.get("cookie"), OAUTH_ACCESS_COOKIE);
  const payload = await readHostedSessionPayload(identityResponse, incomingAccessToken ?? undefined);
  if (!isVerifiedOwnerIdentity(payload)) {
    return writeBlocked(503, "write_owner_identity_unavailable", "owner_identity_contract_invalid");
  }
  return null;
}

/**
 * Local guest/name sessions may authorize writes only for an explicit
 * DEV-ONLY request. Hosted requests must prove the allowlisted GitHub Owner
 * identity through /auth/me before a browser request may borrow a server-only
 * service token. The service token itself is never accepted from or returned
 * to the browser.
 */
export async function authorizeBoundaryWrite(req: Request): Promise<Response | null> {
  const originBlock = authorizePublicSecurityProbe(req);
  if (originBlock) return originBlock;

  if (!isLocalDevelopmentRequest(req)) return authorizeHostedOwnerWrite(req);

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

export function authorizePublicSecurityProbe(req: Request): Response | null {
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
  return null;
}

function authMutationOriginBlock(req: Request): Response | null {
  const expectedOrigin = publicRequestOrigin(req);
  const suppliedOrigin = req.headers.get("origin");
  const actualOrigin = suppliedOrigin ? normalizedOrigin(suppliedOrigin) : null;
  const fetchSite = (req.headers.get("sec-fetch-site") ?? "").trim().toLowerCase();
  let reason = "";
  if (!expectedOrigin) reason = "request_origin_unavailable";
  else if (!suppliedOrigin || !actualOrigin) reason = "exact_origin_required";
  else if (actualOrigin !== expectedOrigin) reason = "origin_mismatch";
  else if (fetchSite && fetchSite !== "same-origin") reason = "fetch_metadata_not_same_origin";
  if (!reason) return null;
  return Response.json(
    {
      contract_version: "frontend-auth-session-boundary-v1",
      status: "blocked",
      error: "csrf_origin_rejected",
      reason,
      accepted: false,
      credentials_issued: false,
      secret_output: false,
    },
    {
      status: 403,
      headers: {
        "cache-control": "no-store",
        "referrer-policy": "no-referrer",
        "x-content-type-options": "nosniff",
        "x-superbrain-source": "frontend-auth-session-guard",
      },
    },
  );
}

function blockedAuthSessionResponse(): Response {
  return Response.json(
    {
      contract_version: "frontend-auth-session-boundary-v1",
      status: "blocked",
      error: "auth_session_response_rejected",
      accepted: false,
      credentials_issued: false,
      secret_output: false,
    },
    {
      status: 502,
      headers: {
        "cache-control": "no-store",
        "referrer-policy": "no-referrer",
        "x-content-type-options": "nosniff",
        "x-superbrain-source": "frontend-auth-session-guard",
      },
    },
  );
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
  const headers = options.oauthRedirectPolicy
    ? copyOAuthRequestHeaders(req, options.oauthRedirectPolicy)
    : options.authSessionPolicy
      ? copyAuthSessionRequestHeaders(req, options.authSessionPolicy)
      : copyRequestHeaders(req, ordinaryRequestHeaderPolicy(kind, method, options));
  if (options.forwardCsrfMetadata === true) {
    const origin = req.headers.get("origin");
    const fetchSite = (req.headers.get("sec-fetch-site") ?? "").trim().toLowerCase();
    if (origin) headers.set("origin", origin);
    if (["same-origin", "same-site", "cross-site", "none"].includes(fetchSite)) {
      headers.set("sec-fetch-site", fetchSite);
    }
  }
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
    const responseHeaders = copyResponseHeaders(response, BOUNDARIES[kind].responseSource);
    let safeOAuthLocation: string | null = null;
    if (options.oauthRedirectPolicy || options.authSessionPolicy) {
      responseHeaders.set("cache-control", "no-store");
      responseHeaders.set("referrer-policy", "no-referrer");
      responseHeaders.set("x-content-type-options", "nosniff");
    }
    if (response.status >= 300 && response.status < 400 && options.oauthRedirectPolicy) {
      safeOAuthLocation = safeOAuthRedirectLocation(req, response.headers.get("location"), options.oauthRedirectPolicy);
      if (!safeOAuthLocation || (response.status !== 302 && response.status !== 303)) return blockedOAuthRedirect();
      responseHeaders.set("location", safeOAuthLocation);
    }
    // Set-Cookie is deny-by-default. Only the exact OAuth/auth-session wrappers
    // below may opt in, and each validates cookie name, value, flags and count.
    const setCookies = options.oauthRedirectPolicy
      ? validatedOAuthSetCookieHeaders(response, options.oauthRedirectPolicy, safeOAuthLocation)
      : options.authSessionPolicy
        ? validatedAuthSessionSetCookieHeaders(response, options.authSessionPolicy)
        : [];
    if (options.oauthRedirectPolicy && setCookies === null) return blockedOAuthRedirect();
    if (options.authSessionPolicy && setCookies === null) return blockedAuthSessionResponse();
    for (const cookie of setCookies ?? []) {
      responseHeaders.append("set-cookie", cookie);
    }
    return new Response(await response.arrayBuffer(), {
      status: response.status,
      headers: responseHeaders,
    });
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

export async function proxyOAuthGetToBoundary(
  req: Request,
  targetPath: "/api/v1/auth/github" | "/api/v1/auth/callback",
  timeoutMs = 8_000,
): Promise<Response | null> {
  const method = req.method.toUpperCase();
  if (method !== "GET") return null;
  if (!validIncomingOAuthQuery(req, targetPath)) return blockedOAuthRedirect();
  return proxyToBoundary(req, "agent-api", targetPath, timeoutMs, {
    oauthRedirectPolicy: targetPath === "/api/v1/auth/github" ? "github-start" : "same-origin-callback",
  });
}

export async function proxyAuthSessionToBoundary(
  req: Request,
  targetPath: "/api/v1/auth/me" | "/api/v1/auth/refresh" | "/api/v1/auth/logout",
  timeoutMs = 8_000,
): Promise<Response | null> {
  const method = req.method.toUpperCase();
  const policy = targetPath === "/api/v1/auth/me"
    ? "identity"
    : targetPath === "/api/v1/auth/refresh"
      ? "refresh"
      : "logout";
  if ((policy === "identity" && method !== "GET") || (policy !== "identity" && method !== "POST")) return null;
  if (policy !== "identity") {
    const blocked = authMutationOriginBlock(req);
    if (blocked) return blocked;
  }
  return proxyToBoundary(req, "agent-api", targetPath, timeoutMs, { authSessionPolicy: policy });
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
        "referrer-policy": "no-referrer",
        "x-content-type-options": "nosniff",
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

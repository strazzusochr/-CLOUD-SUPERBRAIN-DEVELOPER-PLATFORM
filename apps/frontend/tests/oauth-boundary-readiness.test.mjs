import assert from "node:assert/strict";
import fs from "node:fs";
import { createRequire } from "node:module";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import vm from "node:vm";
import ts from "typescript";

const require = createRequire(import.meta.url);
const boundarySource = fs.readFileSync(new URL("../lib/frontendBoundary.ts", import.meta.url), "utf8");
const catchAllRouteSource = fs.readFileSync(new URL("../app/api/v1/[...slug]/route.ts", import.meta.url), "utf8");
const actionMatrixSource = fs.readFileSync(new URL("../lib/actionMatrix.ts", import.meta.url), "utf8");
const authSessionRouteSource = fs.readFileSync(new URL("../app/api/v1/auth/session/route.ts", import.meta.url), "utf8");
const realLoginSource = fs.readFileSync(new URL("../components/real-login.tsx", import.meta.url), "utf8");
const startDevLiveSource = fs.readFileSync(new URL("../../../scripts/start-dev-live.ps1", import.meta.url), "utf8");
const agentApiSource = fs.readFileSync(new URL("../../../services/agent-api/app/main.py", import.meta.url), "utf8");
const devComposeSource = fs.readFileSync(new URL("../../../docker-compose.dev.yml", import.meta.url), "utf8");
const cloudComposeSource = fs.readFileSync(new URL("../../../docker-compose.cloud.yml", import.meta.url), "utf8");
const apiRouteRoot = fileURLToPath(new URL("../app/api/", import.meta.url));
const compiledBoundary = ts.transpileModule(boundarySource, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const boundaryModule = { exports: {} };
const loadBoundary = new vm.Script(`(function (require, module, exports) { ${compiledBoundary}\n})`)
  .runInThisContext();
loadBoundary((specifier) => {
  if (specifier === "./authSession") {
    return {
      AUTH_SESSION_COOKIE: "__Host-sb_session",
      isHostedAuthSessionInvalid: () => false,
      isHostedAuthSessionRevocation: () => false,
      isHostedAuthSessionToken: (token) => token === "hosted-dev-session",
      parseHostedAuthSessionCreation: () => null,
      parseHostedAuthSessionVerification: () => null,
      verifySignedAuthSession: (token) => token === "signed-dev-session"
        ? {
            valid: true,
            claims: {
              v: 1,
              id: "00000000-0000-4000-8000-000000000001",
              provider: "guest",
              name: "DEV Guest",
              iat: 1,
              exp: 2,
            },
          }
        : { valid: false, reason: token ? "signature" : "missing" },
    };
  }
  return require(specifier);
}, boundaryModule, boundaryModule.exports);

const {
  authorizeBoundaryWrite,
  proxyAuthSessionToBoundary,
  proxyOAuthGetToBoundary,
  proxyReadToBoundary,
  proxyToBoundary,
} = boundaryModule.exports;

const originalFetch = globalThis.fetch;
const originalAgentApiBaseUrl = process.env.AGENT_API_BASE_URL;
const originalLlmGatewayBaseUrl = process.env.LLM_GATEWAY_BASE_URL;
const originalLlmGatewayAuthToken = process.env.LLM_GATEWAY_AUTH_TOKEN;
const originalAgentApiAuthToken = process.env.AGENT_API_AUTH_TOKEN;
const originalNodeEnv = process.env.NODE_ENV;
const originalVercel = process.env.VERCEL;

function restoreEnvironment() {
  globalThis.fetch = originalFetch;
  if (originalAgentApiBaseUrl === undefined) delete process.env.AGENT_API_BASE_URL;
  else process.env.AGENT_API_BASE_URL = originalAgentApiBaseUrl;
  if (originalLlmGatewayBaseUrl === undefined) delete process.env.LLM_GATEWAY_BASE_URL;
  else process.env.LLM_GATEWAY_BASE_URL = originalLlmGatewayBaseUrl;
  if (originalLlmGatewayAuthToken === undefined) delete process.env.LLM_GATEWAY_AUTH_TOKEN;
  else process.env.LLM_GATEWAY_AUTH_TOKEN = originalLlmGatewayAuthToken;
  if (originalAgentApiAuthToken === undefined) delete process.env.AGENT_API_AUTH_TOKEN;
  else process.env.AGENT_API_AUTH_TOKEN = originalAgentApiAuthToken;
  if (originalNodeEnv === undefined) delete process.env.NODE_ENV;
  else process.env.NODE_ENV = originalNodeEnv;
  if (originalVercel === undefined) delete process.env.VERCEL;
  else process.env.VERCEL = originalVercel;
}

test.afterEach(restoreEnvironment);
test.after(restoreEnvironment);

test("DEV-LIVE loads all five fail-closed OAuth configuration values", () => {
  const declaration = startDevLiveSource.match(/\$oauthKeys\s*=\s*@\(([^)]*)\)/s)?.[1] ?? "";
  const keys = [...declaration.matchAll(/'([A-Z][A-Z0-9_]*)'/g)].map((match) => match[1]);
  assert.deepEqual(keys, [
    "GITHUB_OAUTH_CLIENT_ID",
    "GITHUB_OAUTH_CLIENT_SECRET",
    "GITHUB_OAUTH_REDIRECT_URI",
    "GITHUB_OAUTH_OWNER_IDS",
    "JWT_SIGNING_SECRET",
  ]);
  assert.match(startDevLiveSource, /O1-Konfiguration vollstaendig \(5\/5, Werte nicht angezeigt\)\./);
  assert.doesNotMatch(startDevLiveSource, /O1-Konfiguration vollstaendig \(4\/4/);
});

test("both Compose modes wire the same five OAuth configuration values", () => {
  const keys = [
    "GITHUB_OAUTH_CLIENT_ID",
    "GITHUB_OAUTH_CLIENT_SECRET",
    "GITHUB_OAUTH_REDIRECT_URI",
    "GITHUB_OAUTH_OWNER_IDS",
    "JWT_SIGNING_SECRET",
  ];
  for (const source of [devComposeSource, cloudComposeSource]) {
    for (const key of keys) {
      const marker = `${key}: ` + "${" + `${key}:-}`;
      assert.ok(source.includes(marker), `missing Compose OAuth marker: ${marker}`);
    }
  }
  assert.match(devComposeSource, /ausschliesslich aus diesen fuenf Werten/);
  assert.doesNotMatch(devComposeSource, /ausschliesslich aus diesen vier Werten/);
});

test("OAuth callback timing remains monotonic across the backend and frontend boundary", () => {
  assert.match(agentApiSource, /httpx\.Client\(timeout=10\.0, follow_redirects=False\)/);
  assert.match(catchAllRouteSource, /export const maxDuration = 30;/);
  assert.match(catchAllRouteSource, /const OAUTH_START_BOUNDARY_TIMEOUT_MS = 8_000;/);
  assert.match(catchAllRouteSource, /const OAUTH_CALLBACK_BOUNDARY_TIMEOUT_MS = 25_000;/);
  assert.match(
    catchAllRouteSource,
    /pathname === "\/api\/v1\/auth\/callback"\s*\? OAUTH_CALLBACK_BOUNDARY_TIMEOUT_MS\s*:\s*OAUTH_START_BOUNDARY_TIMEOUT_MS/,
  );
  assert.doesNotMatch(catchAllRouteSource, /proxyOAuthGetToBoundary\(req, pathname, 6_000\)/);
});

function request(path, extraHeaders = {}, init = {}) {
  return new Request(`https://frontend.example.test${path}`, {
    ...init,
    headers: {
      host: "frontend.example.test",
      "x-forwarded-host": "frontend.example.test",
      "x-forwarded-proto": "https",
      ...extraHeaders,
    },
  });
}

const OAUTH_STATE = `phase3-auth-state-${"A".repeat(32)}`;
const ACCESS_TOKEN = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJnaXRodWI6MSJ9.signature";
const REFRESH_TOKEN = `csr_${"R".repeat(32)}`;

function oauthStateCookie(value = OAUTH_STATE) {
  return `__Host-sb_oauth_state=${value}; Path=/; Max-Age=600; Secure; HttpOnly; SameSite=Lax`;
}

function oauthStateClearCookie() {
  return "__Host-sb_oauth_state=\"\"; Path=/; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Secure; HttpOnly; SameSite=Lax";
}

function accessCookie() {
  return `__Host-sb_access=${ACCESS_TOKEN}; Path=/; Max-Age=900; Secure; HttpOnly; SameSite=Strict`;
}

function refreshCookie() {
  return `__Host-sb_refresh=${REFRESH_TOKEN}; Path=/; Max-Age=604800; Secure; HttpOnly; SameSite=Strict`;
}

function clearedCookie(name) {
  return `${name}=""; Path=/; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Secure; HttpOnly; SameSite=Strict`;
}

function githubLocation(overrides = {}) {
  const query = new URLSearchParams({
    client_id: "client-id",
    redirect_uri: "https://frontend.example.test/api/v1/auth/callback",
    scope: "read:user",
    state: OAUTH_STATE,
    ...overrides,
  });
  return `https://github.com/login/oauth/authorize?${query}`;
}

function verifiedOwnerIdentity(overrides = {}) {
  const providerUserId = 123456;
  return {
    status: "authenticated",
    contract_version: "auth-github-jwt-refresh-v1",
    identity: {
      provider: "github",
      provider_user_id: providerUserId,
      subject: `github:${providerUserId}`,
    },
    owner_activation_granted: true,
    identity_verified: true,
    jwt_signature_verified: true,
    jwt_claims_verified: true,
    token_returned: false,
    cookie_returned: false,
    secret_output: false,
    live_github_oauth_call: false,
    ...overrides,
  };
}

// Returns the body of each POST/PUT/PATCH/DELETE handler in a route module. Assertions about
// mutation behaviour must not read a GET reader that happens to live in the same file.
function mutationHandlerBodies(source) {
  const handlerStart = /export\s+async\s+function\s+(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\b/g;
  const boundaries = [];
  let match;
  while ((match = handlerStart.exec(source)) !== null) {
    boundaries.push({ method: match[1], start: match.index });
  }
  return boundaries
    .filter((entry) => ["POST", "PUT", "PATCH", "DELETE"].includes(entry.method))
    .map((entry) => {
      const position = boundaries.findIndex((candidate) => candidate.start === entry.start);
      const next = boundaries[position + 1];
      return source.slice(entry.start, next ? next.start : source.length);
    });
}

function apiMutationRouteSources(directory = apiRouteRoot) {
  const entries = fs.readdirSync(directory, { withFileTypes: true });
  return entries.flatMap((entry) => {
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) return apiMutationRouteSources(absolute);
    if (!entry.isFile() || entry.name !== "route.ts") return [];
    const source = fs.readFileSync(absolute, "utf8");
    const methods = [...source.matchAll(/\bexport\s+async\s+function\s+(POST|PUT|PATCH|DELETE)\b/g)]
      .map((match) => match[1]);
    return methods.length === 0
      ? []
      : [{ relative: path.relative(apiRouteRoot, absolute).replaceAll("\\", "/"), source, methods }];
  });
}

test("OAuth GET preserves an allowlisted GitHub redirect and its state-bound cookie", async () => {
  process.env.AGENT_API_BASE_URL = "https://agent-api.example.test";
  globalThis.fetch = async (_url, init) => {
    assert.equal(init.headers.get("authorization"), null);
    assert.equal(init.headers.get("cookie"), null);
    const headers = new Headers({ location: githubLocation(), "cache-control": "no-store" });
    headers.append("set-cookie", oauthStateCookie());
    return new Response(null, { status: 303, headers });
  };

  const response = await proxyOAuthGetToBoundary(request("/api/v1/auth/github"), "/api/v1/auth/github");
  assert.equal(response?.status, 303);
  assert.equal(response?.headers.get("location"), githubLocation());
  assert.equal(response?.headers.get("referrer-policy"), "no-referrer");
  assert.equal(response?.headers.get("x-content-type-options"), "nosniff");
  assert.deepEqual(response?.headers.getSetCookie().map((value) => value.split("=", 1)[0]), ["__Host-sb_oauth_state"]);
});

test("OAuth start rejects an unexpected cookie or extra GitHub parameter", async () => {
  process.env.AGENT_API_BASE_URL = "https://agent-api.example.test";
  for (const variant of ["cookie", "parameter"]) {
    globalThis.fetch = async () => {
      const headers = new Headers({ location: githubLocation(variant === "parameter" ? { login: "unexpected" } : {}) });
      headers.append("set-cookie", oauthStateCookie());
      if (variant === "cookie") {
        headers.append("set-cookie", "__Host-sb_aux=unexpected; Path=/; Secure; HttpOnly; SameSite=Strict");
      }
      return new Response(null, { status: 303, headers });
    };
    const response = await proxyOAuthGetToBoundary(request("/api/v1/auth/github"), "/api/v1/auth/github");
    assert.equal(response?.status, 502);
    assert.deepEqual(response?.headers.getSetCookie(), []);
  }
});

test("OAuth callback forwards only the bounded state cookie and preserves the exact success cookie set", async () => {
  process.env.AGENT_API_BASE_URL = "https://agent-api.example.test";
  let outboundHeaders;
  globalThis.fetch = async (_url, init) => {
    outboundHeaders = init.headers;
    const headers = new Headers({ location: "/workbench" });
    headers.append("set-cookie", oauthStateClearCookie());
    headers.append("set-cookie", accessCookie());
    headers.append("set-cookie", refreshCookie());
    return new Response(null, { status: 303, headers });
  };

  const response = await proxyOAuthGetToBoundary(
    request(`/api/v1/auth/callback?code=opaque&state=${OAUTH_STATE}`, {
      accept: "text/html",
      authorization: "Bearer must-not-cross",
      cookie: `${oauthStateCookie().split(";", 1)[0]}; __Host-sb_session=must-not-cross; arbitrary=must-not-cross`,
      "x-request-id": "oauth-test-request",
      traceparent: "00-0123456789abcdef0123456789abcdef-0123456789abcdef-01",
    }),
    "/api/v1/auth/callback",
  );
  assert.equal(response?.status, 303);
  assert.equal(response?.headers.get("location"), "/workbench");
  assert.deepEqual(response?.headers.getSetCookie().map((value) => value.split("=", 1)[0]).sort(), [
    "__Host-sb_access",
    "__Host-sb_oauth_state",
    "__Host-sb_refresh",
  ]);
  assert.equal(outboundHeaders.get("authorization"), null);
  assert.equal(outboundHeaders.get("cookie"), `__Host-sb_oauth_state=${OAUTH_STATE}`);
  assert.equal(outboundHeaders.get("x-request-id"), "oauth-test-request");
});

test("OAuth GET rejects external redirects without forwarding their cookies", async () => {
  process.env.AGENT_API_BASE_URL = "https://agent-api.example.test";
  globalThis.fetch = async () => new Response(null, {
    status: 303,
    headers: {
      location: "https://example.invalid/login",
      "set-cookie": "__Host-leak=must-not-pass; Path=/; Secure; HttpOnly",
    },
  });

  const response = await proxyOAuthGetToBoundary(request("/api/v1/auth/github"), "/api/v1/auth/github");
  assert.equal(response?.status, 502);
  assert.equal(response?.headers.get("location"), null);
  assert.deepEqual(response?.headers.getSetCookie(), []);
  assert.equal(response?.headers.get("referrer-policy"), "no-referrer");
  assert.equal((await response?.json()).error, "oauth_redirect_rejected");
});

test("callback redirects reject query-bearing same-origin handoffs", async () => {
  process.env.AGENT_API_BASE_URL = "https://agent-api.example.test";
  globalThis.fetch = async () => new Response(null, {
    status: 303,
    headers: {
      location: "https://frontend.example.test/workbench?code=must-not-propagate",
      "set-cookie": "__Host-leak=must-not-pass; Path=/; Secure; HttpOnly",
    },
  });

  const response = await proxyOAuthGetToBoundary(
    request(`/api/v1/auth/callback?code=opaque&state=${OAUTH_STATE}`, {
      cookie: `__Host-sb_oauth_state=${OAUTH_STATE}`,
    }),
    "/api/v1/auth/callback",
  );
  assert.equal(response?.status, 502);
  assert.equal(response?.headers.get("location"), null);
  assert.deepEqual(response?.headers.getSetCookie(), []);
});

test("ordinary read proxy still refuses every redirect", async () => {
  process.env.AGENT_API_BASE_URL = "https://agent-api.example.test";
  globalThis.fetch = async () => new Response(null, {
    status: 303,
    headers: { location: githubLocation() },
  });

  const response = await proxyReadToBoundary(request("/api/v1/health"), "agent-api", "/api/v1/health");
  assert.equal(response, null);
});

test("ordinary endpoints forward only their bounded headers and drop every upstream cookie", async () => {
  process.env.AGENT_API_BASE_URL = "https://agent-api.example.test";
  let outboundHeaders;
  globalThis.fetch = async (_url, init) => {
    outboundHeaders = init.headers;
    const headers = new Headers({ "content-type": "application/json" });
    headers.append("set-cookie", "__Host-sb_session=must-not-pass; Path=/; Secure; HttpOnly; SameSite=Strict");
    headers.append("set-cookie", "arbitrary=must-not-pass; Path=/; Secure; HttpOnly");
    return new Response(JSON.stringify({ status: "ok" }), { status: 200, headers });
  };

  const response = await proxyToBoundary(
    request("/api/v1/prompt", {
      accept: "application/json",
      "content-type": "application/json",
      authorization: "Bearer browser-credential-must-not-cross",
      cookie: "__Host-sb_session=must-not-cross; arbitrary=must-not-cross",
      "x-csrf-token": "must-not-cross",
      "x-request-id": "ordinary-test-request",
      traceparent: "00-0123456789abcdef0123456789abcdef-0123456789abcdef-01",
    }, { method: "POST", body: "{}" }),
    "agent-api",
    "/api/v1/prompt",
  );

  assert.equal(response?.status, 200);
  assert.equal(outboundHeaders.get("accept"), "application/json");
  assert.equal(outboundHeaders.get("content-type"), "application/json");
  assert.equal(outboundHeaders.get("x-request-id"), "ordinary-test-request");
  assert.equal(outboundHeaders.get("authorization"), null);
  assert.equal(outboundHeaders.get("cookie"), null);
  assert.equal(outboundHeaders.get("x-csrf-token"), null);
  assert.deepEqual(response?.headers.getSetCookie(), []);
});

test("gateway endpoint policy replaces browser credentials with only configured service auth", async () => {
  process.env.LLM_GATEWAY_BASE_URL = "https://llm-gateway.example.test";
  process.env.LLM_GATEWAY_AUTH_TOKEN = "configured-test-service-auth";
  globalThis.fetch = async (_url, init) => {
    assert.equal(init.headers.get("authorization"), null);
    assert.equal(init.headers.get("cookie"), null);
    assert.equal(init.headers.get("x-csrf-token"), null);
    assert.equal(init.headers.get("x-superbrain-gateway-token"), "configured-test-service-auth");
    return Response.json({ status: "ok" });
  };

  const response = await proxyToBoundary(
    request("/llm/api/v1/chat", {
      authorization: "Bearer browser-credential-must-not-cross",
      cookie: "arbitrary=must-not-cross",
      "x-csrf-token": "must-not-cross",
      "content-type": "application/json",
    }, { method: "POST", body: "{}" }),
    "llm-gateway",
    "/api/v1/chat",
  );
  assert.equal(response?.status, 200);
});

test("OAuth callback rejects duplicate or extra incoming query fields before fetch", async () => {
  process.env.AGENT_API_BASE_URL = "https://agent-api.example.test";
  let calls = 0;
  globalThis.fetch = async () => { calls += 1; throw new Error("must not fetch malformed callback"); };
  for (const suffix of [
    `code=opaque&state=${OAUTH_STATE}&state=${OAUTH_STATE}`,
    `code=opaque&state=${OAUTH_STATE}&next=%2Fworkbench`,
    `code=opaque&state=phase3-auth-state-${"B".repeat(32)}`,
  ]) {
    const response = await proxyOAuthGetToBoundary(
      request(`/api/v1/auth/callback?${suffix}`, { cookie: `__Host-sb_oauth_state=${OAUTH_STATE}` }),
      "/api/v1/auth/callback",
    );
    assert.equal(response?.status, 502);
  }
  assert.equal(calls, 0);
});

test("identity proxy forwards only the access cookie and preserves a fail-closed 401 clear", async () => {
  process.env.AGENT_API_BASE_URL = "https://agent-api.example.test";
  globalThis.fetch = async (_url, init) => {
    assert.equal(init.method, "GET");
    assert.equal(init.headers.get("authorization"), null);
    assert.equal(init.headers.get("cookie"), `__Host-sb_access=${ACCESS_TOKEN}`);
    const headers = new Headers({ "content-type": "application/json" });
    headers.append("set-cookie", clearedCookie("__Host-sb_access"));
    return new Response(JSON.stringify({ error: "access_token_invalid", authenticated: false }), { status: 401, headers });
  };

  const response = await proxyAuthSessionToBoundary(
    request("/api/v1/auth/me", {
      authorization: "Bearer must-not-cross",
      cookie: `__Host-sb_access=${ACCESS_TOKEN}; __Host-sb_refresh=${REFRESH_TOKEN}; __Host-sb_session=must-not-cross; arbitrary=must-not-cross`,
    }),
    "/api/v1/auth/me",
  );
  assert.equal(response?.status, 401);
  assert.deepEqual(response?.headers.getSetCookie().map((value) => value.split("=", 1)[0]), ["__Host-sb_access"]);
  assert.equal(response?.headers.get("referrer-policy"), "no-referrer");
});

test("refresh proxy requires exact same origin and forwards only the refresh cookie", async () => {
  process.env.AGENT_API_BASE_URL = "https://agent-api.example.test";
  globalThis.fetch = async (_url, init) => {
    assert.equal(init.method, "POST");
    assert.equal(init.headers.get("authorization"), null);
    assert.equal(init.headers.get("cookie"), `__Host-sb_refresh=${REFRESH_TOKEN}`);
    assert.equal(init.headers.get("content-type"), "application/json");
    const headers = new Headers({ "content-type": "application/json" });
    headers.append("set-cookie", accessCookie());
    headers.append("set-cookie", refreshCookie());
    return new Response(JSON.stringify({ status: "rotated", audit_persisted: true }), { status: 200, headers });
  };

  const response = await proxyAuthSessionToBoundary(
    request("/api/v1/auth/refresh", {
      origin: "https://frontend.example.test",
      "sec-fetch-site": "same-origin",
      "content-type": "application/json",
      authorization: "Bearer must-not-cross",
      cookie: `__Host-sb_access=${ACCESS_TOKEN}; __Host-sb_refresh=${REFRESH_TOKEN}; __Host-sb_session=must-not-cross`,
    }, { method: "POST", body: "{}" }),
    "/api/v1/auth/refresh",
  );
  assert.equal(response?.status, 200);
  assert.deepEqual(response?.headers.getSetCookie().map((value) => value.split("=", 1)[0]).sort(), [
    "__Host-sb_access",
    "__Host-sb_refresh",
  ]);
});

test("refresh errors preserve only the canonical two-cookie clear contract", async () => {
  process.env.AGENT_API_BASE_URL = "https://agent-api.example.test";
  for (const status of [400, 401, 403, 503]) {
    globalThis.fetch = async () => {
      const headers = new Headers({ "content-type": "application/json" });
      headers.append("set-cookie", clearedCookie("__Host-sb_access"));
      headers.append("set-cookie", clearedCookie("__Host-sb_refresh"));
      return new Response(JSON.stringify({ error: `refresh_rejected_${status}` }), { status, headers });
    };
    const response = await proxyAuthSessionToBoundary(
      request("/api/v1/auth/refresh", {
        origin: "https://frontend.example.test",
        "sec-fetch-site": "same-origin",
        "content-type": "application/json",
        cookie: `__Host-sb_refresh=${REFRESH_TOKEN}`,
      }, { method: "POST", body: "{}" }),
      "/api/v1/auth/refresh",
    );
    assert.equal(response?.status, status);
    assert.deepEqual(response?.headers.getSetCookie().map((value) => value.split("=", 1)[0]).sort(), [
      "__Host-sb_access",
      "__Host-sb_refresh",
    ]);
  }
});

test("refresh errors reject issuance, partial, extra, malformed, and status-inappropriate cookies", async () => {
  process.env.AGENT_API_BASE_URL = "https://agent-api.example.test";
  const missingExpiresClear = '__Host-sb_refresh=""; Path=/; Max-Age=0; Secure; HttpOnly; SameSite=Strict';
  const futureExpiresClear = '__Host-sb_refresh=""; Path=/; Max-Age=0; Expires=Fri, 01 Jan 2100 00:00:00 GMT; Secure; HttpOnly; SameSite=Strict';
  const duplicateExpiresClear = '__Host-sb_refresh=""; Path=/; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Secure; HttpOnly; SameSite=Strict';
  const variants = [
    { status: 401, cookies: [accessCookie(), refreshCookie()] },
    { status: 401, cookies: [clearedCookie("__Host-sb_access")] },
    {
      status: 401,
      cookies: [
        clearedCookie("__Host-sb_access"),
        clearedCookie("__Host-sb_refresh"),
        "__Host-sb_aux=unexpected; Path=/; Secure; HttpOnly; SameSite=Strict",
      ],
    },
    { status: 401, cookies: [clearedCookie("__Host-sb_access"), missingExpiresClear] },
    { status: 401, cookies: [clearedCookie("__Host-sb_access"), futureExpiresClear] },
    { status: 401, cookies: [clearedCookie("__Host-sb_access"), duplicateExpiresClear] },
    { status: 418, cookies: [clearedCookie("__Host-sb_access"), clearedCookie("__Host-sb_refresh")] },
  ];
  for (const variant of variants) {
    globalThis.fetch = async () => {
      const headers = new Headers({ "content-type": "application/json" });
      for (const cookie of variant.cookies) headers.append("set-cookie", cookie);
      return new Response(JSON.stringify({ error: "adversarial_refresh_response" }), {
        status: variant.status,
        headers,
      });
    };
    const response = await proxyAuthSessionToBoundary(
      request("/api/v1/auth/refresh", {
        origin: "https://frontend.example.test",
        "sec-fetch-site": "same-origin",
        cookie: `__Host-sb_refresh=${REFRESH_TOKEN}`,
      }, { method: "POST", body: "{}" }),
      "/api/v1/auth/refresh",
    );
    assert.equal(response?.status, 502);
    assert.deepEqual(response?.headers.getSetCookie(), []);
  }
});

test("logout blocks cross-site requests before fetch and accepts only two exact clear cookies", async () => {
  process.env.AGENT_API_BASE_URL = "https://agent-api.example.test";
  let calls = 0;
  globalThis.fetch = async () => { calls += 1; throw new Error("must not fetch cross-site"); };
  const blocked = await proxyAuthSessionToBoundary(
    request("/api/v1/auth/logout", {
      origin: "https://attacker.example.invalid",
      "sec-fetch-site": "cross-site",
      cookie: `__Host-sb_refresh=${REFRESH_TOKEN}`,
    }, { method: "POST" }),
    "/api/v1/auth/logout",
  );
  assert.equal(blocked?.status, 403);
  assert.equal(calls, 0);

  globalThis.fetch = async (_url, init) => {
    calls += 1;
    assert.equal(init.headers.get("cookie"), `__Host-sb_refresh=${REFRESH_TOKEN}`);
    const headers = new Headers({ "content-type": "application/json" });
    headers.append("set-cookie", clearedCookie("__Host-sb_access"));
    headers.append("set-cookie", clearedCookie("__Host-sb_refresh"));
    return new Response(JSON.stringify({ status: "logged_out", audit_persisted: true, active_refresh_token_absent: true }), { status: 200, headers });
  };
  const accepted = await proxyAuthSessionToBoundary(
    request("/api/v1/auth/logout", {
      origin: "https://frontend.example.test",
      "sec-fetch-site": "same-origin",
      cookie: `__Host-sb_refresh=${REFRESH_TOKEN}; arbitrary=must-not-cross`,
    }, { method: "POST" }),
    "/api/v1/auth/logout",
  );
  assert.equal(accepted?.status, 200);
  assert.equal(calls, 1);
  assert.deepEqual(accepted?.headers.getSetCookie().map((value) => value.split("=", 1)[0]).sort(), [
    "__Host-sb_access",
    "__Host-sb_refresh",
  ]);
});

test("only explicit localhost development may authorize a guest session without OAuth", async () => {
  process.env.NODE_ENV = "development";
  delete process.env.VERCEL;
  let calls = 0;
  globalThis.fetch = async () => { calls += 1; throw new Error("local guest auth must not call the hosted identity boundary"); };
  const localRequest = new Request("http://localhost:8081/api/v1/prompt", {
    method: "POST",
    headers: {
      host: "localhost:8081",
      "x-forwarded-host": "localhost:8081",
      "x-forwarded-proto": "http",
      origin: "http://localhost:8081",
      "sec-fetch-site": "same-origin",
      cookie: "__Host-sb_session=signed-dev-session",
    },
    body: "{}",
  });
  assert.equal(await authorizeBoundaryWrite(localRequest), null);
  assert.equal(calls, 0);
});

test("production ignores local and hosted guest sessions and preserves an exact owner rejection clear", async () => {
  process.env.NODE_ENV = "production";
  process.env.AGENT_API_BASE_URL = "https://agent-api.example.test";
  process.env.AGENT_API_AUTH_TOKEN = "configured-test-agent-service-auth";
  for (const [sessionToken, status] of [["signed-dev-session", 401], ["hosted-dev-session", 403]]) {
    let calls = 0;
    globalThis.fetch = async (url, init) => {
      calls += 1;
      assert.equal(new URL(url).pathname, "/api/v1/auth/me");
      assert.equal(init.headers.get("x-superbrain-agent-token"), null);
      assert.equal(init.headers.get("cookie"), null);
      const headers = new Headers({ "content-type": "application/json" });
      headers.append("set-cookie", clearedCookie("__Host-sb_access"));
      return new Response(JSON.stringify({ error: "owner_identity_rejected" }), { status, headers });
    };
    const blocked = await authorizeBoundaryWrite(request("/api/v1/prompt", {
      origin: "https://frontend.example.test",
      "sec-fetch-site": "same-origin",
      cookie: `__Host-sb_session=${sessionToken}`,
    }, { method: "POST", body: "{}" }));
    assert.equal(blocked?.status, status);
    assert.equal((await blocked?.json()).accepted, false);
    assert.deepEqual(blocked?.headers.getSetCookie().map((value) => value.split("=", 1)[0]), ["__Host-sb_access"]);
    assert.equal(calls, 1);
  }
});

test("production write authorization requires the exact verified Owner identity contract", async () => {
  process.env.NODE_ENV = "production";
  process.env.AGENT_API_BASE_URL = "https://agent-api.example.test";
  process.env.AGENT_API_AUTH_TOKEN = "configured-test-agent-service-auth";
  globalThis.fetch = async (url, init) => {
    assert.equal(new URL(url).pathname, "/api/v1/auth/me");
    assert.equal(init.headers.get("authorization"), null);
    assert.equal(init.headers.get("x-superbrain-agent-token"), null);
    assert.equal(init.headers.get("cookie"), `__Host-sb_access=${ACCESS_TOKEN}`);
    return Response.json(verifiedOwnerIdentity());
  };
  const allowed = await authorizeBoundaryWrite(request("/api/v1/prompt", {
    origin: "https://frontend.example.test",
    "sec-fetch-site": "same-origin",
    authorization: "Bearer browser-credential-must-not-cross",
    cookie: `__Host-sb_access=${ACCESS_TOKEN}; __Host-sb_refresh=${REFRESH_TOKEN}; __Host-sb_session=signed-dev-session`,
  }, { method: "POST", body: "{}" }));
  assert.equal(allowed, null);
});

test("production write authorization rejects malformed or weakened Owner identity claims", async () => {
  process.env.NODE_ENV = "production";
  process.env.AGENT_API_BASE_URL = "https://agent-api.example.test";
  const variants = [
    verifiedOwnerIdentity({ owner_activation_granted: false }),
    verifiedOwnerIdentity({ jwt_claims_verified: false }),
    verifiedOwnerIdentity({ token_returned: true }),
    verifiedOwnerIdentity({
      identity: { provider: "github", provider_user_id: 123456, subject: "github:654321" },
    }),
  ];
  for (const payload of variants) {
    globalThis.fetch = async () => Response.json(payload);
    const blocked = await authorizeBoundaryWrite(request("/api/v1/prompt", {
      origin: "https://frontend.example.test",
      "sec-fetch-site": "same-origin",
      cookie: `__Host-sb_access=${ACCESS_TOKEN}; __Host-sb_session=signed-dev-session`,
    }, { method: "POST", body: "{}" }));
    assert.equal(blocked?.status, 503);
    assert.equal((await blocked?.json()).reason, "owner_identity_contract_invalid");
  }
});

test("auth-session proxy rejects unexpected response cookies without forwarding them", async () => {
  process.env.AGENT_API_BASE_URL = "https://agent-api.example.test";
  globalThis.fetch = async () => {
    const headers = new Headers({ "content-type": "application/json" });
    headers.append("set-cookie", accessCookie());
    headers.append("set-cookie", refreshCookie());
    headers.append("set-cookie", "__Host-sb_aux=unexpected; Path=/; Secure; HttpOnly; SameSite=Strict");
    return new Response(JSON.stringify({ status: "rotated" }), { status: 200, headers });
  };
  const response = await proxyAuthSessionToBoundary(
    request("/api/v1/auth/refresh", {
      origin: "https://frontend.example.test",
      "sec-fetch-site": "same-origin",
      cookie: `__Host-sb_refresh=${REFRESH_TOKEN}`,
    }, { method: "POST" }),
    "/api/v1/auth/refresh",
  );
  assert.equal(response?.status, 502);
  assert.deepEqual(response?.headers.getSetCookie(), []);
});

test("OAuth catch-all paths are single-attempt and the mounted control is gate-registered", () => {
  assert.match(catchAllRouteSource, /OAuth boundary did not produce a definitive response; no retry was attempted/);
  assert.match(catchAllRouteSource, /if \(pathname === "\/api\/v1\/auth\/github" \|\| pathname === "\/api\/v1\/auth\/callback"\)/);
  assert.match(catchAllRouteSource, /if \(method !== "GET"\)/);
  assert.match(catchAllRouteSource, /status: 405/);
  assert.match(catchAllRouteSource, /allow: "GET"/);
  assert.match(catchAllRouteSource, /export async function HEAD/);
  assert.match(catchAllRouteSource, /proxyAuthSessionToBoundary/);
  assert.match(catchAllRouteSource, /no retry or projection was attempted/);
  assert.match(boundarySource, /if \(method !== "GET"\) return null/);
  assert.match(boundarySource, /"referrer-policy": "no-referrer"/);
  assert.match(actionMatrixSource, /member\("login-github"[^\n]+`\[data-testid="rl-github-signin"\]`[^\n]+"provider_gated"\)/);
  assert.doesNotMatch(actionMatrixSource, /id: "external-oauth"/);
});

test("every Next mutation proxy is owner-write guarded with only exact auth and CSP-report exceptions", () => {
  const mutationRoutes = apiMutationRouteSources();
  assert.ok(mutationRoutes.length > 0);
  const exactRouteExceptions = new Set(["v1/auth/session/route.ts"]);
  for (const route of mutationRoutes) {
    if (exactRouteExceptions.has(route.relative)) continue;
    assert.match(route.source, /\bauthorizeBoundaryWrite\b/, `${route.relative} must import the write guard`);
    const guardIndex = route.source.indexOf("await authorizeBoundaryWrite(req)");
    assert.ok(guardIndex >= 0, `${route.relative} must execute the write guard`);
    assert.match(route.source, /if \(writeBlock\) return writeBlock;/, `${route.relative} must stop on a failed write guard`);
    if (route.relative !== "v1/[...slug]/route.ts") {
      // Count only inside the mutation handlers. Scanning the whole file also caught GET
      // readers, which would have forced the service token onto read traffic — more token
      // exposure for no gain. v1/build/[id] is the case that exposed it: two proxied reads in
      // GET, and a DELETE that never proxies at all because it fails closed on owner identity.
      const mutationBodies = mutationHandlerBodies(route.source);
      const agentProxyCallCount = mutationBodies.reduce(
        (total, body) => total + (body.match(/\bproxyToBoundary\s*\([\s\S]{0,240}?"agent-api"/g) ?? []).length,
        0,
      );
      const serviceAuthCount = mutationBodies.reduce(
        (total, body) => total + (body.match(/\{\s*serviceAuth:\s*true\s*\}/g) ?? []).length,
        0,
      );
      assert.equal(
        serviceAuthCount,
        agentProxyCallCount,
        `${route.relative} must bind service auth to every Agent API mutation proxy call`,
      );
    }
  }
  assert.deepEqual(
    mutationRoutes.filter((route) => exactRouteExceptions.has(route.relative)).map((route) => route.relative),
    ["v1/auth/session/route.ts"],
  );
  assert.match(catchAllRouteSource, /pathname === "\/api\/v1\/auth\/refresh"/);
  assert.match(catchAllRouteSource, /pathname === "\/api\/v1\/auth\/logout"/);
  assert.match(catchAllRouteSource, /if \(pathname === "\/api\/v1\/security\/csp\/report"\)/);
  assert.match(
    catchAllRouteSource,
    /const report = await proxyToBoundary\(req, "agent-api", pathname, 6_000\);/,
    "CSP browser reports remain the one exact unauthenticated catch-all POST",
  );
  assert.ok(
    catchAllRouteSource.indexOf('if (pathname === "/api/v1/security/csp/report")')
      < catchAllRouteSource.indexOf("await authorizeBoundaryWrite(req)"),
    "the exact CSP report exception must be resolved before the generic mutation guard",
  );
});

test("local and OAuth session lifecycle wiring is fail-closed and browser-clearable", () => {
  assert.match(authSessionRouteSource, /jar\.set\(AUTH_SESSION_COOKIE, "", \{/);
  for (const attribute of [
    /httpOnly: true/,
    /secure: true/,
    /sameSite: "strict"/,
    /path: "\/"/,
    /maxAge: 0/,
    /expires: new Date\(0\)/,
  ]) {
    assert.match(authSessionRouteSource, attribute);
  }
  assert.doesNotMatch(authSessionRouteSource, /jar\.delete\(AUTH_SESSION_COOKIE\)/);
  assert.match(realLoginSource, /async function oauthIdentityWithRefresh/);
  assert.match(realLoginSource, /fetch\("\/api\/v1\/auth\/refresh"/);
  assert.match(realLoginSource, /const \[oauthRevoked, localRevoked\] = await Promise\.all/);
  assert.match(realLoginSource, /if \(!oauthRevoked \|\| !localRevoked\) throw new Error\("session_revoke_incomplete"\)/);
  assert.doesNotMatch(realLoginSource, /fetch\("\/api\/v1\/auth\/session", \{ method: "DELETE" \}\)\.catch/);
});

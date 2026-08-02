import assert from "node:assert/strict";
import fs from "node:fs";
import { createRequire } from "node:module";
import test from "node:test";
import vm from "node:vm";
import ts from "typescript";

const require = createRequire(import.meta.url);
const boundarySource = fs.readFileSync(new URL("../lib/frontendBoundary.ts", import.meta.url), "utf8");
const catchAllRouteSource = fs.readFileSync(new URL("../app/api/v1/[...slug]/route.ts", import.meta.url), "utf8");
const actionMatrixSource = fs.readFileSync(new URL("../lib/actionMatrix.ts", import.meta.url), "utf8");
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
      isHostedAuthSessionToken: () => false,
      parseHostedAuthSessionCreation: () => null,
      parseHostedAuthSessionVerification: () => null,
      verifySignedAuthSession: () => ({ valid: false, reason: "missing" }),
    };
  }
  return require(specifier);
}, boundaryModule, boundaryModule.exports);

const { proxyAuthSessionToBoundary, proxyOAuthGetToBoundary, proxyReadToBoundary } = boundaryModule.exports;

const originalFetch = globalThis.fetch;
const originalAgentApiBaseUrl = process.env.AGENT_API_BASE_URL;

function restoreEnvironment() {
  globalThis.fetch = originalFetch;
  if (originalAgentApiBaseUrl === undefined) delete process.env.AGENT_API_BASE_URL;
  else process.env.AGENT_API_BASE_URL = originalAgentApiBaseUrl;
}

test.afterEach(restoreEnvironment);
test.after(restoreEnvironment);

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

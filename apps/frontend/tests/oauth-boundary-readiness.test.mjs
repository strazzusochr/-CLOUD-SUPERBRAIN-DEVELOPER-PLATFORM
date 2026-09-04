import assert from "node:assert/strict";
import fs from "node:fs";
import { createRequire } from "node:module";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import vm from "node:vm";
import ts from "typescript";

import statefulWorker from "../../../services/cloudflare-stateful-runtime/src/index.js";
import nextConfig from "../next.config.mjs";

const require = createRequire(import.meta.url);
const boundarySource = fs.readFileSync(new URL("../lib/frontendBoundary.ts", import.meta.url), "utf8");
const catchAllRouteSource = fs.readFileSync(new URL("../app/api/v1/[...slug]/route.ts", import.meta.url), "utf8");
const endpointDefaultsSource = fs.readFileSync(new URL("../lib/endpointDefaults.ts", import.meta.url), "utf8");
const gatewayProxySource = fs.readFileSync(new URL("../lib/gatewayProxy.ts", import.meta.url), "utf8");
const actionMatrixSource = fs.readFileSync(new URL("../lib/actionMatrix.ts", import.meta.url), "utf8");
const authSessionRouteSource = fs.readFileSync(new URL("../app/api/v1/auth/session/route.ts", import.meta.url), "utf8");
const realLoginSource = fs.readFileSync(new URL("../components/real-login.tsx", import.meta.url), "utf8");
const startDevLiveSource = fs.readFileSync(new URL("../../../scripts/start-dev-live.ps1", import.meta.url), "utf8");
const agentApiSource = fs.readFileSync(new URL("../../../services/agent-api/app/main.py", import.meta.url), "utf8");
const devComposeSource = fs.readFileSync(new URL("../../../docker-compose.dev.yml", import.meta.url), "utf8");
const cloudComposeSource = fs.readFileSync(new URL("../../../docker-compose.cloud.yml", import.meta.url), "utf8");
const statefulWorkerConfigSource = fs.readFileSync(
  new URL("../../../services/cloudflare-stateful-runtime/wrangler.jsonc", import.meta.url),
  "utf8",
);
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

const compiledEndpointDefaults = ts.transpileModule(endpointDefaultsSource, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const endpointDefaultsModule = { exports: {} };
new vm.Script(`(function (require, module, exports) { ${compiledEndpointDefaults}\n})`)
  .runInThisContext()(require, endpointDefaultsModule, endpointDefaultsModule.exports);

const {
  authorizeBoundaryWrite,
  proxyAuthSessionToBoundary,
  proxyOAuthGetToBoundary,
  proxyReadToBoundary,
  proxyToBoundary,
} = boundaryModule.exports;
const compiledGatewayProxy = ts.transpileModule(gatewayProxySource, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const gatewayProxyModule = { exports: {} };
new vm.Script(`(function (require, module, exports) { ${compiledGatewayProxy}\n})`)
  .runInThisContext()((specifier) => {
    if (specifier === "./endpointDefaults") return endpointDefaultsModule.exports;
    if (specifier === "./frontendBoundary") return boundaryModule.exports;
    return require(specifier);
  }, gatewayProxyModule, gatewayProxyModule.exports);
const { gatewayHandle } = gatewayProxyModule.exports;

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

test("Next API responses carry the complete security-header contract", async () => {
  assert.equal(typeof nextConfig.headers, "function");
  const rules = await nextConfig.headers();
  const apiRule = rules.find((rule) => rule.source === "/api/:path*");
  assert.ok(apiRule);
  const headers = Object.fromEntries(apiRule.headers.map(({ key, value }) => [key.toLowerCase(), value]));
  assert.equal(headers["x-content-type-options"], "nosniff");
  assert.equal(headers["x-frame-options"], "DENY");
  assert.equal(headers["referrer-policy"], "no-referrer");
  assert.equal(headers["permissions-policy"], "camera=(), microphone=(), geolocation=()");
  assert.equal(headers["cross-origin-opener-policy"], "same-origin");
  assert.equal(headers["cross-origin-resource-policy"], "same-origin");
  assert.equal(headers["x-permitted-cross-domain-policies"], "none");
  assert.equal(headers["x-superbrain-security-contract"], "security-headers-v1");
  assert.match(headers["content-security-policy"], /report-uri \/api\/v1\/security\/csp\/report/);
});

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

test("DEV-LIVE loads existing Workers AI credentials only for the explicit live path", () => {
  const declaration = startDevLiveSource.match(/\$providerCredentialKeys\s*=\s*@\(([^)]*)\)/s)?.[1] ?? "";
  const keys = [...declaration.matchAll(/'([A-Z][A-Z0-9_]*)'/g)].map((match) => match[1]);
  assert.deepEqual(keys, ["CF_WORKERS_AI_TOKEN", "CLOUDFLARE_ACCOUNT_ID"]);
  assert.match(startDevLiveSource, /if \(-not \$DryRun -and \(Test-Path -LiteralPath \$secretsPath\)\)/);
  assert.match(startDevLiveSource, /Set-Item -Path "env:\$providerCredentialKey" -Value \$providerCredentials\[\$providerCredentialKey\]/);
  assert.match(startDevLiveSource, /Live-Provider-Credentials aus lokaler Secrets-Datei geladen \(Werte nicht angezeigt\)\./);
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

test("the production Worker binds OAuth to the canonical browser-visible frontend callback", () => {
  assert.ok(
    statefulWorkerConfigSource.includes(
      `"GITHUB_OAUTH_REDIRECT_URI": "${CANONICAL_FRONTEND_CALLBACK}"`,
    ),
    "the Worker redirect_uri must be the canonical frontend callback, not a backend or Worker origin",
  );
});

test("the frontend auth projection names all five missing OAuth values", () => {
  const projected = endpointDefaultsModule.exports.projectedDefault("/api/v1/auth/contract", "GET");
  assert.deepEqual(projected?.payload.missing_configuration, [
    "GITHUB_OAUTH_CLIENT_ID",
    "GITHUB_OAUTH_CLIENT_SECRET",
    "GITHUB_OAUTH_REDIRECT_URI",
    "GITHUB_OAUTH_OWNER_IDS",
    "JWT_SIGNING_SECRET_BASE64URL_256_BIT_MINIMUM",
  ]);
  assert.deepEqual(projected?.payload.cookie_flags, {
    SameSite: "Strict",
    HttpOnly: true,
    Secure: true,
    host_prefix: true,
  });
});

test("the frontend security projections preserve the CSP, CSRF, and cross-origin contracts", () => {
  const security = endpointDefaultsModule.exports.projectedDefault("/api/v1/security/headers/contract", "GET")?.payload;
  assert.equal(security?.csp_report_contract.contract_version, "csp-report-contract-v1");
  assert.equal(security?.csp_report_contract.evidence_ref, "csp_report_contract_visible");
  assert.equal(security?.csrf_origin_contract.contract_version, "csrf-origin-guard-v1");
  assert.equal(security?.cross_origin_response_contract.contract_version, "cross-origin-response-guard-v1");

  const csrf = endpointDefaultsModule.exports.projectedDefault("/api/v1/security/csrf/contract", "GET")?.payload;
  assert.equal(csrf?.phase3_progress_after_proof, 42);
  assert.equal(csrf?.cookie_or_authorization_value_persisted, false);

  const crossOrigin = endpointDefaultsModule.exports.projectedDefault("/api/v1/security/cross-origin/contract", "GET")?.payload;
  assert.equal(crossOrigin?.phase3_progress_after_proof, 43);
  assert.equal(crossOrigin?.headers["Cross-Origin-Opener-Policy"], "same-origin");
  assert.equal(crossOrigin?.cors_policy.attacker_origin_reflected, false);
  assert.equal(crossOrigin?.cors_policy.credentials_allowed_cross_origin, false);
  assert.equal(crossOrigin?.provider_write, false);
  assert.equal(crossOrigin?.production_deploy, false);
});

test("the frontend preserves the remaining deterministic browser-contract projections", () => {
  const orchestrator = endpointDefaultsModule.exports.projectedDefault("/api/v1/orchestrator/completion/contract", "GET")?.payload;
  assert.equal(orchestrator?.contract_version, "orchestrator-completion-evidence-v1");
  assert.equal(orchestrator?.layer_progress_after_proof, 100);
  assert.equal(orchestrator?.live_provider_calls, false);
  assert.equal(orchestrator?.live_mcp_writes, false);

  const candidate = endpointDefaultsModule.exports.projectedDefault("/api/v1/release-candidate/local/contract", "GET")?.payload;
  assert.equal(candidate?.contract_version, "phase5-production-candidate-local-v1");
  assert.equal(candidate?.service_count, 6);
  assert.equal(candidate?.registry_publish, false);
  assert.equal(candidate?.hosted_staging_parity, false);

  const scoreboard = endpointDefaultsModule.exports.projectedDefault("/api/v1/phase6/local-scoreboard-performance/contract", "GET")?.payload;
  assert.equal(scoreboard?.contract_version, "phase6-local-scoreboard-performance-runtime-v1");
  assert.equal(scoreboard?.leaderboard_maximum_entries, 3);
  assert.equal(scoreboard?.performance_sample_count, 12);
  assert.equal(scoreboard?.scale_capacity_claim_allowed, false);

  const gameplay = endpointDefaultsModule.exports.projectedDefault("/api/v1/phase6/3d-gameplay-state/contract", "GET")?.payload;
  assert.deepEqual(gameplay?.objective_transitions, {
    collect: { next: "checkpoint", score_delta: 10, checkpoint_delta: 0 },
    checkpoint: { next: "survive", score_delta: 0, checkpoint_delta: 1 },
    survive: { next: "collect", score_delta: 10, checkpoint_delta: 0 },
  });
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
const CANONICAL_FRONTEND_ORIGIN = "https://frontend-seven-psi-78.vercel.app";
const CANONICAL_FRONTEND_CALLBACK = `${CANONICAL_FRONTEND_ORIGIN}/api/v1/auth/callback`;

function oauthStateCookie(value = OAUTH_STATE) {
  return `__Host-sb_oauth_state=${value}; Path=/; Max-Age=600; Secure; HttpOnly; SameSite=Lax`;
}

function oauthStateClearCookie() {
  return "__Host-sb_oauth_state=\"\"; Path=/; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Secure; HttpOnly; SameSite=Lax";
}

function accessCookie() {
  return `__Host-sb_access=${ACCESS_TOKEN}; Path=/; Max-Age=900; Secure; HttpOnly; SameSite=Strict`;
}

function refreshCookie(maxAge = 604800) {
  return `__Host-sb_refresh=${REFRESH_TOKEN}; Path=/; Max-Age=${maxAge}; Secure; HttpOnly; SameSite=Strict`;
}

function clearedCookie(name) {
  return `${name}=""; Path=/; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Secure; HttpOnly; SameSite=Strict`;
}

function githubLocation(overrides = {}) {
  const query = new URLSearchParams({
    client_id: "0123456789ABCDEFGHIJ",
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

class OAuthContractStatement {
  constructor(db, sql) {
    this.db = db;
    this.sql = sql.replace(/\s+/g, " ").trim();
    this.values = [];
  }

  bind(...values) {
    this.values = values;
    return this;
  }

  async run() {
    if (this.sql.startsWith("INSERT INTO oauth_states")) {
      const [state, createdAt, expiresAt] = this.values;
      this.db.oauthStates.set(state, { state, created_at: createdAt, expires_at: expiresAt });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("DELETE FROM oauth_states")) {
      const [state, nowIso] = this.values;
      const row = this.db.oauthStates.get(state);
      if (!row || (nowIso && row.expires_at <= nowIso)) return { meta: { changes: 0 } };
      return { meta: { changes: this.db.oauthStates.delete(state) ? 1 : 0 } };
    }
    if (this.sql.startsWith("INSERT INTO refresh_token_families")) {
      const [familyId, subject, activeTokenHash, createdAt, updatedAt, expiresAt] = this.values;
      if (Date.parse(expiresAt) - Date.parse(createdAt) !== 604800000) {
        throw new Error("refresh family expiry invariant failed");
      }
      if ([...this.db.refreshFamilies.values()].some((family) => family.active_token_hash === activeTokenHash)) {
        throw new Error("UNIQUE constraint failed: refresh_token_families.active_token_hash");
      }
      this.db.refreshFamilies.set(familyId, {
        family_id: familyId,
        subject,
        active_token_hash: activeTokenHash,
        created_at: createdAt,
        updated_at: updatedAt,
        expires_at: expiresAt,
        revoked_at: null,
        revocation_reason: null,
      });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("INSERT INTO refresh_token_history")) {
      const tokenHash = this.values[0];
      let familyId = this.values[1];
      let consumedAt = this.values[2];
      if (this.sql.includes("SELECT family_id FROM refresh_token_families")) {
        const expectedActiveHash = this.values[2];
        const expectedExpiry = this.values[3];
        const hasExpiryThreshold = this.sql.includes("expires_at > ?");
        const nowIso = hasExpiryThreshold ? this.values[4] : null;
        consumedAt = this.values[hasExpiryThreshold ? 5 : 4];
        const family = this.db.refreshFamilies.get(familyId);
        const expiryMatches = this.sql.includes("COALESCE(expires_at")
          ? String(family?.expires_at || "") === String(expectedExpiry)
          : family?.expires_at === expectedExpiry;
        if (!family
          || family.active_token_hash !== expectedActiveHash
          || family.revoked_at
          || !expiryMatches
          || (hasExpiryThreshold && family.expires_at <= nowIso)) {
          throw new Error("NOT NULL constraint failed: refresh_token_history.family_id");
        }
      }
      if (this.db.refreshHistory.has(tokenHash)) {
        throw new Error("UNIQUE constraint failed: refresh_token_history.token_hash");
      }
      const status = this.sql.match(/,\s*'(rotated|revoked|blacklisted)'\s*\)$/i)?.[1] ?? this.values[3] ?? null;
      this.db.refreshHistory.set(tokenHash, {
        token_hash: tokenHash,
        family_id: familyId,
        consumed_at: consumedAt,
        status,
      });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("UPDATE refresh_token_families SET active_token_hash")) {
      const [newHash, updatedAt, familyId, oldHash, expectedExpiry, nowIso] = this.values;
      const family = this.db.refreshFamilies.get(familyId);
      if (!family
        || family.active_token_hash !== oldHash
        || family.revoked_at
        || (this.sql.includes("expires_at = ?") && family.expires_at !== expectedExpiry)
        || (this.sql.includes("expires_at > ?") && family.expires_at <= nowIso)) {
        return { meta: { changes: 0 } };
      }
      if ([...this.db.refreshFamilies.values()].some((entry) => entry.family_id !== familyId && entry.active_token_hash === newHash)) {
        throw new Error("UNIQUE constraint failed: refresh_token_families.active_token_hash");
      }
      family.active_token_hash = newHash;
      family.updated_at = updatedAt;
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("UPDATE refresh_token_families SET revoked_at")) {
      const reason = this.sql.match(/revocation_reason\s*=\s*'([^']+)'/)?.[1] ?? "revoked";
      const [revokedAt] = this.values;
      const matchFamilyId = this.sql.includes("WHERE family_id = ?");
      const hasUpdatedAt = this.sql.includes("updated_at = ?");
      const needle = matchFamilyId ? this.values[hasUpdatedAt ? 2 : 1] : this.values.at(-1);
      const family = matchFamilyId
        ? this.db.refreshFamilies.get(needle)
        : [...this.db.refreshFamilies.values()].find((entry) => entry.active_token_hash === needle);
      if (!family) return { meta: { changes: 0 } };
      if (this.sql.includes("revoked_at IS NULL") && family.revoked_at) return { meta: { changes: 0 } };
      const activeTokenHash = matchFamilyId ? this.values[hasUpdatedAt ? 3 : 2] : null;
      const expectedExpiry = hasUpdatedAt ? this.values[4] : null;
      const nowIso = hasUpdatedAt ? this.values[5] : null;
      if (activeTokenHash && family.active_token_hash !== activeTokenHash) return { meta: { changes: 0 } };
      if (hasUpdatedAt && this.sql.includes("COALESCE(expires_at") && String(family.expires_at || "") !== String(expectedExpiry)) return { meta: { changes: 0 } };
      if (hasUpdatedAt && !this.sql.includes("COALESCE(expires_at") && family.expires_at !== expectedExpiry) return { meta: { changes: 0 } };
      if (this.sql.includes("expires_at > ?") && family.expires_at <= nowIso) return { meta: { changes: 0 } };
      family.revoked_at = revokedAt;
      if (hasUpdatedAt) family.updated_at = this.values[1];
      family.revocation_reason = reason;
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("UPDATE refresh_token_history SET status")) {
      const [tokenHash, familyId] = this.values;
      const history = this.db.refreshHistory.get(tokenHash);
      if (!history || history.family_id !== familyId) return { meta: { changes: 0 } };
      history.status = this.sql.match(/SET status = '([^']+)'/)?.[1] ?? history.status;
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("INSERT INTO audit_events")) {
      const [id, eventType, traceId, subjectId, detailsJson, createdAt] = this.values;
      this.db.audit.push({
        id,
        event_type: eventType,
        trace_id: traceId,
        subject_id: subjectId,
        details_json: detailsJson,
        created_at: createdAt,
      });
      return { meta: { changes: 1 } };
    }
    throw new Error(`Unhandled OAuth integration run SQL: ${this.sql}`);
  }

  async first() {
    if (this.sql.startsWith("SELECT state FROM oauth_states")) {
      const [state, nowIso] = this.values;
      const row = this.db.oauthStates.get(state);
      return row && row.expires_at > nowIso ? { state } : null;
    }
    if (this.sql.startsWith("SELECT family_id, status FROM refresh_token_history")) {
      const row = this.db.refreshHistory.get(this.values[0]);
      return row ? { family_id: row.family_id, status: row.status } : null;
    }
    if (this.sql.startsWith("SELECT family_id, subject, active_token_hash, created_at, updated_at, expires_at, revoked_at, revocation_reason FROM refresh_token_families")) {
      const needle = this.values[0];
      const family = this.sql.includes("WHERE family_id = ?")
        ? this.db.refreshFamilies.get(needle)
        : [...this.db.refreshFamilies.values()].find((entry) => entry.active_token_hash === needle);
      return family ? { ...family } : null;
    }
    if (this.sql.startsWith("SELECT family_id, subject, active_token_hash, revoked_at FROM refresh_token_families")) {
      const needle = this.values[0];
      const family = this.sql.includes("WHERE family_id = ?")
        ? this.db.refreshFamilies.get(needle)
        : [...this.db.refreshFamilies.values()].find((entry) => entry.active_token_hash === needle);
      return family ? { ...family } : null;
    }
    if (this.sql.startsWith("SELECT family_id, subject, active_token_hash, revoked_at, revocation_reason FROM refresh_token_families")) {
      const needle = this.values[0];
      const family = this.sql.includes("WHERE family_id = ?")
        ? this.db.refreshFamilies.get(needle)
        : [...this.db.refreshFamilies.values()].find((entry) => entry.active_token_hash === needle);
      return family ? { ...family } : null;
    }
    if (this.sql.startsWith("SELECT family_id FROM refresh_token_families")) {
      const activeHash = this.values[0];
      const family = [...this.db.refreshFamilies.values()]
        .find((entry) => entry.active_token_hash === activeHash);
      return family ? { family_id: family.family_id } : null;
    }
    if (this.sql.startsWith("SELECT id, event_type, trace_id, subject_id, details_json, created_at FROM audit_events")) {
      const [id, eventType, traceId, subjectId] = this.values;
      const audit = this.db.audit.find((entry) => entry.id === id
        && entry.event_type === eventType
        && entry.trace_id === traceId
        && entry.subject_id === subjectId);
      return audit ? { ...audit } : null;
    }
    throw new Error(`Unhandled OAuth integration first SQL: ${this.sql}`);
  }
}

class OAuthContractD1 {
  constructor() {
    this.oauthStates = new Map();
    this.refreshFamilies = new Map();
    this.refreshHistory = new Map();
    this.audit = [];
  }

  prepare(sql) {
    return new OAuthContractStatement(this, sql);
  }

  async batch(statements) {
    const results = [];
    for (const statement of statements) results.push(await statement.run());
    return results;
  }
}

function canonicalFrontendRequest(pathname, extraHeaders = {}, init = {}) {
  const url = new URL(pathname, CANONICAL_FRONTEND_ORIGIN);
  return new Request(url, {
    ...init,
    headers: {
      host: url.host,
      "x-forwarded-host": url.host,
      "x-forwarded-proto": "https",
      ...extraHeaders,
    },
  });
}

function responseSetCookies(response) {
  return typeof response.headers.getSetCookie === "function"
    ? response.headers.getSetCookie()
    : [response.headers.get("set-cookie")].filter(Boolean);
}

function responseCookieValue(response, name) {
  const prefix = `${name}=`;
  const header = responseSetCookies(response).find((value) => value.startsWith(prefix));
  return header?.slice(prefix.length).split(";", 1)[0] ?? null;
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

test("gateway reads fall back to deterministic contracts when the configured boundary is unavailable", async () => {
  process.env.LLM_GATEWAY_BASE_URL = "https://llm-gateway.example.test";
  globalThis.fetch = async () => new Response("error code: 1027", {
    status: 429,
    headers: { "content-type": "text/plain" },
  });

  const response = await gatewayHandle(
    request("/llm/api/v1/responses/contract"),
    ["api", "v1", "responses", "contract"],
    "/llm",
    "LLM_GATEWAY_BASE_URL",
  );
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("x-superbrain-source"), "frontend-projection");
  const payload = await response.json();
  assert.equal(payload.contract_version, "llm-responses-adapter-contract-v2");
  assert.equal(payload.live_backend, false);
  assert.equal(payload.live_provider_calls, false);
});

test("gateway writes preserve upstream application failures and never project success", async () => {
  process.env.LLM_GATEWAY_BASE_URL = "https://llm-gateway.example.test";
  globalThis.fetch = async () => Response.json({ error: "rate_limited" }, { status: 429 });

  const response = await gatewayHandle(
    request("/llm/v1/responses", { "content-type": "application/json" }, { method: "POST", body: "{}" }),
    ["v1", "responses"],
    "/llm",
    "LLM_GATEWAY_BASE_URL",
  );
  assert.equal(response.status, 429);
  assert.equal((await response.json()).error, "rate_limited");
});

test("gateway writes replace non-contract upstream errors with fail-closed JSON", async () => {
  process.env.LLM_GATEWAY_BASE_URL = "https://llm-gateway.example.test";
  globalThis.fetch = async () => new Response("error code: 1027", {
    status: 429,
    headers: { "content-type": "text/html; charset=UTF-8" },
  });

  const response = await gatewayHandle(
    request("/llm/v1/responses", { "content-type": "application/json" }, { method: "POST", body: "{}" }),
    ["v1", "responses"],
    "/llm",
    "LLM_GATEWAY_BASE_URL",
  );
  assert.equal(response.status, 503);
  assert.equal(response.headers.get("x-superbrain-source"), "frontend-boundary-blocked");
  const payload = await response.json();
  assert.equal(payload.error, "configured_boundary_unavailable");
  assert.equal(payload.reason, "configured_boundary_unavailable");
  assert.equal(payload.accepted, false);
  assert.equal(payload.persisted, false);
  assert.equal(payload.audit_persisted, false);
  assert.equal(payload.live_provider_calls, false);
  assert.equal(payload.secret_output, false);
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

test("refresh proxy accepts a shrinking fixed-family TTL but rejects any extension", async () => {
  process.env.AGENT_API_BASE_URL = "https://agent-api.example.test";
  let refreshMaxAge = 604799;
  globalThis.fetch = async () => {
    const headers = new Headers({ "content-type": "application/json" });
    headers.append("set-cookie", accessCookie());
    headers.append("set-cookie", refreshCookie(refreshMaxAge));
    return new Response(JSON.stringify({ status: "rotated", audit_persisted: true }), { status: 200, headers });
  };
  const invoke = () => proxyAuthSessionToBoundary(
    request("/api/v1/auth/refresh", {
      origin: "https://frontend.example.test",
      "sec-fetch-site": "same-origin",
      "content-type": "application/json",
      cookie: `__Host-sb_refresh=${REFRESH_TOKEN}`,
    }, { method: "POST", body: "{}" }),
    "/api/v1/auth/refresh",
  );
  assert.equal((await invoke())?.status, 200);
  refreshMaxAge = 604801;
  assert.equal((await invoke())?.status, 502);
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

test("the real Worker contract completes the canonical frontend OAuth lifecycle through the Next boundary", async () => {
  process.env.AGENT_API_BASE_URL = "https://agent-api.example.test";
  const db = new OAuthContractD1();
  const workerEnv = {
    DB: db,
    GITHUB_OAUTH_CLIENT_ID: "Iv1.8a61f9b3a7aba766",
    GITHUB_OAUTH_CLIENT_SECRET: "0123456789abcdef0123456789abcdef01234567",
    OAUTH_PUBLIC_ORIGIN: CANONICAL_FRONTEND_ORIGIN,
    GITHUB_OAUTH_REDIRECT_URI: CANONICAL_FRONTEND_CALLBACK,
    GITHUB_OAUTH_OWNER_IDS: "123456",
    JWT_SIGNING_SECRET: "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY",
    PRODUCTION_AUTH_OWNER_GRANTED: "true",
    PRODUCTION_AUTH_OWNER_GRANT_REF: "test-only-owner-grant-ref",
  };
  let exchangeCount = 0;

  globalThis.fetch = async (input, init = {}) => {
    const target = new URL(input instanceof Request ? input.url : input.toString());
    if (target.origin === "https://agent-api.example.test") {
      const body = init.body === undefined || init.body === null ? undefined : init.body;
      const workerRequest = new Request(
        new URL(`${target.pathname}${target.search}`, "https://stateful-runtime.example.test"),
        {
          method: init.method ?? "GET",
          headers: init.headers,
          body,
        },
      );
      return statefulWorker.fetch(workerRequest, workerEnv);
    }
    if (target.href === "https://github.com/login/oauth/access_token") {
      exchangeCount += 1;
      const payload = JSON.parse(String(init.body));
      assert.equal(payload.redirect_uri, CANONICAL_FRONTEND_CALLBACK);
      assert.equal(payload.code, "opaque-integration-code");
      return Response.json({
        access_token: "integration-provider-access",
        token_type: "bearer",
        scope: "read:user",
      });
    }
    if (target.href === "https://api.github.com/user") {
      assert.equal(new Headers(init.headers).get("authorization"), "Bearer integration-provider-access");
      return Response.json({ id: 123456, login: "integration-owner" });
    }
    throw new Error(`Unexpected OAuth integration fetch target: ${target.origin}${target.pathname}`);
  };

  const start = await proxyOAuthGetToBoundary(
    canonicalFrontendRequest("/api/v1/auth/github", { accept: "text/html" }),
    "/api/v1/auth/github",
  );
  assert.equal(start?.status, 303, JSON.stringify(await start?.clone().json().catch(() => null)));
  const authorizeLocation = new URL(start.headers.get("location"));
  assert.equal(authorizeLocation.origin, "https://github.com");
  assert.equal(authorizeLocation.pathname, "/login/oauth/authorize");
  assert.equal(authorizeLocation.searchParams.get("redirect_uri"), CANONICAL_FRONTEND_CALLBACK);
  assert.equal(authorizeLocation.searchParams.get("scope"), "read:user");
  assert.deepEqual([...authorizeLocation.searchParams.keys()].sort(), ["client_id", "redirect_uri", "scope", "state"]);
  const state = authorizeLocation.searchParams.get("state");
  assert.match(state, /^phase3-auth-state-[A-Za-z0-9_-]{32}$/);
  assert.equal(responseCookieValue(start, "__Host-sb_oauth_state"), state);
  assert.deepEqual(responseSetCookies(start).map((value) => value.split("=", 1)[0]), ["__Host-sb_oauth_state"]);

  const callbackPath = `/api/v1/auth/callback?code=opaque-integration-code&state=${encodeURIComponent(state)}`;
  const callback = await proxyOAuthGetToBoundary(
    canonicalFrontendRequest(callbackPath, {
      accept: "text/html,application/xhtml+xml",
      cookie: `__Host-sb_oauth_state=${state}`,
      "x-request-id": "oauth-worker-next-integration",
    }),
    "/api/v1/auth/callback",
  );
  assert.equal(callback?.status, 303);
  assert.equal(callback.headers.get("location"), "/workbench");
  assert.deepEqual(responseSetCookies(callback).map((value) => value.split("=", 1)[0]).sort(), [
    "__Host-sb_access",
    "__Host-sb_oauth_state",
    "__Host-sb_refresh",
  ]);
  const accessToken = responseCookieValue(callback, "__Host-sb_access");
  const initialRefreshToken = responseCookieValue(callback, "__Host-sb_refresh");
  assert.match(accessToken, /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/);
  assert.match(initialRefreshToken, /^csr_[A-Za-z0-9_-]{32}$/);
  assert.equal(exchangeCount, 1);

  const me = await proxyAuthSessionToBoundary(
    canonicalFrontendRequest("/api/v1/auth/me", {
      cookie: `__Host-sb_access=${accessToken}; __Host-sb_refresh=${initialRefreshToken}`,
    }),
    "/api/v1/auth/me",
  );
  assert.equal(me?.status, 200);
  const meBody = await me.json();
  assert.equal(meBody.status, "authenticated");
  assert.equal(meBody.contract_version, "auth-github-jwt-refresh-v1");
  assert.deepEqual(meBody.identity, {
    provider: "github",
    provider_user_id: 123456,
    subject: "github:123456",
  });
  for (const field of [
    "owner_activation_granted",
    "identity_verified",
    "jwt_signature_verified",
    "jwt_claims_verified",
  ]) {
    assert.equal(meBody[field], true, `/auth/me must affirm ${field}`);
  }
  assert.equal(meBody.token_returned, false);
  assert.equal(meBody.cookie_returned, false);
  assert.equal(meBody.secret_output, false);
  assert.equal(meBody.live_github_oauth_call, false);
  assert.equal(responseSetCookies(me).length, 0);

  const refresh = await proxyAuthSessionToBoundary(
    canonicalFrontendRequest("/api/v1/auth/refresh", {
      origin: CANONICAL_FRONTEND_ORIGIN,
      "sec-fetch-site": "same-origin",
      "content-type": "application/json",
      cookie: `__Host-sb_refresh=${initialRefreshToken}`,
    }, { method: "POST", body: "{}" }),
    "/api/v1/auth/refresh",
  );
  assert.equal(refresh?.status, 200, JSON.stringify(await refresh?.clone().json().catch(() => null)));
  const refreshBody = await refresh.json();
  assert.equal(refreshBody.status, "rotated");
  assert.equal(refreshBody.contract_version, "auth-github-jwt-refresh-v1");
  for (const field of [
    "access_token_issued",
    "refresh_token_rotated",
    "old_refresh_token_blacklisted",
    "active_registry_verified",
    "audit_persisted",
  ]) {
    assert.equal(refreshBody[field], true, `/auth/refresh must affirm ${field}`);
  }
  assert.equal(refreshBody.access_token_expires_in, 900);
  assert.ok(refreshBody.refresh_token_expires_in >= 604790 && refreshBody.refresh_token_expires_in <= 604800);
  assert.match(refreshBody.trace_id, /^(?:auth-refresh-)?[0-9a-f-]{36}$/);
  assert.deepEqual(responseSetCookies(refresh).map((value) => value.split("=", 1)[0]).sort(), [
    "__Host-sb_access",
    "__Host-sb_refresh",
  ]);
  assert.match(
    responseSetCookies(refresh).find((value) => value.startsWith("__Host-sb_refresh=")),
    new RegExp(`(?:^|; )Max-Age=${refreshBody.refresh_token_expires_in}(?:;|$)`),
  );
  const rotatedAccessToken = responseCookieValue(refresh, "__Host-sb_access");
  const rotatedRefreshToken = responseCookieValue(refresh, "__Host-sb_refresh");
  assert.notEqual(rotatedAccessToken, accessToken);
  assert.notEqual(rotatedRefreshToken, initialRefreshToken);

  const logout = await proxyAuthSessionToBoundary(
    canonicalFrontendRequest("/api/v1/auth/logout", {
      origin: CANONICAL_FRONTEND_ORIGIN,
      "sec-fetch-site": "same-origin",
      cookie: `__Host-sb_refresh=${rotatedRefreshToken}`,
    }, { method: "POST" }),
    "/api/v1/auth/logout",
  );
  assert.equal(logout?.status, 200);
  const logoutBody = await logout.json();
  assert.equal(logoutBody.status, "logged_out");
  assert.equal(logoutBody.contract_version, "auth-github-jwt-refresh-v1");
  assert.equal(logoutBody.refresh_token_revoked, true);
  assert.equal(logoutBody.body_token_accepted, false);
  assert.equal(logoutBody.cookies_cleared, true);
  assert.equal(logoutBody.active_refresh_token_absent, true);
  assert.equal(logoutBody.audit_persisted, true);
  assert.match(logoutBody.trace_id, /^(?:auth-logout-)?[0-9a-f-]{36}$/);
  assert.deepEqual(responseSetCookies(logout).map((value) => value.split("=", 1)[0]).sort(), [
    "__Host-sb_access",
    "__Host-sb_refresh",
  ]);

  const postLogoutMe = await proxyAuthSessionToBoundary(
    canonicalFrontendRequest("/api/v1/auth/me"),
    "/api/v1/auth/me",
  );
  assert.equal(postLogoutMe?.status, 401);
  assert.deepEqual(await postLogoutMe.json(), {
    error: "access_token_invalid",
    authenticated: false,
    identity_verified: false,
    token_returned: false,
    cookie_returned: false,
    secret_output: false,
  });

  for (const candidate of [initialRefreshToken, rotatedRefreshToken]) {
    const rejected = await proxyAuthSessionToBoundary(
      canonicalFrontendRequest("/api/v1/auth/refresh", {
        origin: CANONICAL_FRONTEND_ORIGIN,
        "sec-fetch-site": "same-origin",
        cookie: `__Host-sb_refresh=${candidate}`,
      }, { method: "POST", body: "{}" }),
      "/api/v1/auth/refresh",
    );
    assert.equal(rejected?.status, 401);
    assert.equal((await rejected.json()).error, "refresh_token_invalid");
  }

  const callbackReplay = await proxyOAuthGetToBoundary(
    canonicalFrontendRequest(callbackPath, {
      accept: "text/html",
      cookie: `__Host-sb_oauth_state=${state}`,
    }),
    "/api/v1/auth/callback",
  );
  assert.equal(callbackReplay?.status, 401);
  assert.equal((await callbackReplay.json()).error, "oauth_state_invalid");
  assert.equal(exchangeCount, 1, "a consumed callback state must never reach the provider twice");
  assert.ok(db.audit.some((entry) => entry.event_type === "auth_github_callback_verified"));
  assert.ok(db.audit.some((entry) => entry.event_type === "auth_refresh_rotated"));
  assert.ok(db.audit.some((entry) => entry.event_type === "auth_logout_revoked"));
  assert.ok(db.audit.filter((entry) => entry.event_type === "auth_refresh_rejected"
    && JSON.parse(entry.details_json).reason === "revoked").length >= 2);
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

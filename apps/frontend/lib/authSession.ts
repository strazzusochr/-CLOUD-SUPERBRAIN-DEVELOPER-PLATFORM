import { createHmac, randomBytes, timingSafeEqual } from "node:crypto";

export const AUTH_SESSION_COOKIE = "__Host-sb_session";
export const AUTH_SESSION_TTL_SECONDS = 30 * 24 * 60 * 60;
export const AUTH_SESSION_CONTRACT_VERSION = "auth-session-integrity-v1";

const configuredSecret = process.env.AUTH_SESSION_SECRET?.trim();
const hasValidConfiguredSecret = Boolean(configuredSecret && Buffer.byteLength(configuredSecret, "utf8") >= 32);
const sessionSecret = hasValidConfiguredSecret
  ? configuredSecret as string
  : randomBytes(32).toString("base64url");

export type AuthSessionClaims = {
  v: 1;
  id: string;
  provider: "guest" | "name";
  name: string;
  iat: number;
  exp: number;
};

export type AuthSessionVerification =
  | { valid: true; claims: AuthSessionClaims }
  | { valid: false; reason: "missing" | "malformed" | "signature" | "claims" | "expired" };

function sign(encodedPayload: string): string {
  return createHmac("sha256", sessionSecret).update(encodedPayload, "utf8").digest("base64url");
}

function signaturesMatch(actual: string, expected: string): boolean {
  if (!/^[A-Za-z0-9_-]{43}$/.test(actual)) return false;
  const actualBytes = Buffer.from(actual, "ascii");
  const expectedBytes = Buffer.from(expected, "ascii");
  return actualBytes.length === expectedBytes.length && timingSafeEqual(actualBytes, expectedBytes);
}

export function normalizeAuthIdentity(input: { provider?: unknown; name?: unknown }): {
  provider: "guest" | "name";
  name: string;
} | null {
  const provider = String(input.provider ?? "guest");
  if (provider !== "guest" && provider !== "name") return null;
  const normalizedName = String(input.name ?? "").trim().replace(/\s+/g, " ").slice(0, 40);
  if (provider === "name" && !normalizedName) return null;
  return { provider, name: normalizedName || "Gast" };
}

export function createSignedAuthSession(
  identity: { provider: "guest" | "name"; name: string },
  id: string,
  nowSeconds = Math.floor(Date.now() / 1000),
): { token: string; claims: AuthSessionClaims } {
  const claims: AuthSessionClaims = {
    v: 1,
    id,
    provider: identity.provider,
    name: identity.name,
    iat: nowSeconds,
    exp: nowSeconds + AUTH_SESSION_TTL_SECONDS,
  };
  const encodedPayload = Buffer.from(JSON.stringify(claims), "utf8").toString("base64url");
  return { token: `${encodedPayload}.${sign(encodedPayload)}`, claims };
}

export function verifySignedAuthSession(
  token: string | null | undefined,
  nowSeconds = Math.floor(Date.now() / 1000),
): AuthSessionVerification {
  if (!token) return { valid: false, reason: "missing" };
  if (token.length > 2048) return { valid: false, reason: "malformed" };
  const parts = token.split(".");
  if (parts.length !== 2 || !parts[0] || !parts[1]) return { valid: false, reason: "malformed" };
  const [encodedPayload, actualSignature] = parts;
  if (!signaturesMatch(actualSignature, sign(encodedPayload))) return { valid: false, reason: "signature" };

  let claims: Partial<AuthSessionClaims>;
  try {
    claims = JSON.parse(Buffer.from(encodedPayload, "base64url").toString("utf8")) as Partial<AuthSessionClaims>;
  } catch {
    return { valid: false, reason: "claims" };
  }
  const validClaims = claims.v === 1
    && typeof claims.id === "string" && /^[0-9a-f-]{36}$/.test(claims.id)
    && (claims.provider === "guest" || claims.provider === "name")
    && typeof claims.name === "string" && claims.name.length > 0 && claims.name.length <= 40
    && Number.isInteger(claims.iat) && Number.isInteger(claims.exp)
    && (claims.iat as number) <= nowSeconds + 60
    && (claims.exp as number) === (claims.iat as number) + AUTH_SESSION_TTL_SECONDS;
  if (!validClaims) return { valid: false, reason: "claims" };
  if ((claims.exp as number) <= nowSeconds) return { valid: false, reason: "expired" };
  return { valid: true, claims: claims as AuthSessionClaims };
}

export function authSessionContract() {
  return {
    contract_version: AUTH_SESSION_CONTRACT_VERSION,
    status: "verified_contract",
    endpoint: "/api/v1/auth/session",
    evidence_ref: "auth_session_integrity_visible",
    cookie: {
      name: AUTH_SESSION_COOKIE,
      HttpOnly: true,
      Secure: true,
      SameSite: "Strict",
      path: "/",
      ttl_seconds: AUTH_SESSION_TTL_SECONDS,
    },
    integrity: {
      algorithm: "HMAC-SHA256",
      constant_time_signature_check: true,
      expiry_enforced: true,
      future_issued_at_rejected: true,
      malformed_cookie_rejected: true,
      tampered_cookie_rejected: true,
      configured_secret_minimum_bytes: 32,
      secret_source: hasValidConfiguredSecret ? "environment" : "ephemeral_process",
      restart_invalidates_session_without_configured_secret: !hasValidConfiguredSecret,
    },
    allowed_providers: ["guest", "name"],
    persistence: "signed_http_only_cookie",
    external_provider_write: false,
    live_oauth_call: false,
    production_identity_claimed: false,
    non_claims: [
      "This local session contract does not prove external OAuth identity ownership.",
      "Without AUTH_SESSION_SECRET, sessions are intentionally process-local and expire on restart.",
      "No GitHub, cloud, database, provider, or MCP write is performed.",
    ],
  };
}

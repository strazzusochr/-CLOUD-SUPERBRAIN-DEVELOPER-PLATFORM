// Adversarial cases for the signed frontend session (auth-session-integrity-v1).
// Complements auth-session-integrity.test.mjs: every forged or reshaped token must be
// rejected without trusting the attacker-controlled payload.
import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import test from "node:test";
import {
  AUTH_SESSION_TTL_SECONDS,
  createSignedAuthSession,
  verifySignedAuthSession,
} from "../lib/authSession.ts";

const identity = { provider: "guest", name: "Gast" };
const sessionId = "123e4567-e89b-12d3-a456-426614174000";
const now = 1_000;
const b64 = (value) => Buffer.from(JSON.stringify(value), "utf8").toString("base64url");
const claimsOf = (token) => JSON.parse(Buffer.from(token.split(".")[0], "base64url").toString("utf8"));

test("payload tampering with the original signature is rejected", () => {
  const issued = createSignedAuthSession(identity, sessionId, now);
  const signature = issued.token.split(".")[1];
  for (const patch of [{ name: "Admin" }, { provider: "name" }, { id: "00000000-0000-0000-0000-000000000000" }, { exp: now + 10 * AUTH_SESSION_TTL_SECONDS }]) {
    const forged = `${b64({ ...claimsOf(issued.token), ...patch })}.${signature}`;
    assert.deepEqual(verifySignedAuthSession(forged, now + 1), { valid: false, reason: "signature" }, JSON.stringify(patch));
  }
});

test("tokens signed with guessable secrets are rejected", () => {
  const payload = b64({ v: 1, id: sessionId, provider: "guest", name: "Gast", iat: now, exp: now + AUTH_SESSION_TTL_SECONDS });
  for (const secret of ["", "secret", "changeme", "0".repeat(32)]) {
    const signature = createHmac("sha256", secret).update(payload, "utf8").digest("base64url");
    assert.deepEqual(verifySignedAuthSession(`${payload}.${signature}`, now + 1), { valid: false, reason: "signature" }, secret);
  }
});

test("unsigned, reshaped and oversized tokens are rejected as malformed or signature", () => {
  const issued = createSignedAuthSession(identity, sessionId, now);
  const [payload, signature] = issued.token.split(".");
  const cases = {
    unsigned: `${payload}.`,
    noneAlgorithm: `${payload}.none`,
    extraSegment: `${payload}.${signature}.x`,
    signatureOnly: `.${signature}`,
    oversized: `${"A".repeat(2049)}.${signature}`,
    unicodeSignature: `${payload}.${"ä".repeat(43)}`,
    whitespace: ` ${issued.token}`,
  };
  for (const [name, token] of Object.entries(cases)) {
    const result = verifySignedAuthSession(token, now + 1);
    assert.equal(result.valid, false, name);
    assert.ok(["malformed", "signature"].includes(result.reason), `${name}: ${result.reason}`);
  }
  assert.deepEqual(verifySignedAuthSession("", now), { valid: false, reason: "missing" });
  assert.deepEqual(verifySignedAuthSession(undefined, now), { valid: false, reason: "missing" });
});

test("expiry is enforced exactly at the boundary and future issuance is rejected", () => {
  const issued = createSignedAuthSession(identity, sessionId, now);
  assert.equal(verifySignedAuthSession(issued.token, now + AUTH_SESSION_TTL_SECONDS - 1).valid, true);
  assert.deepEqual(verifySignedAuthSession(issued.token, now + AUTH_SESSION_TTL_SECONDS), { valid: false, reason: "expired" });
  const future = createSignedAuthSession(identity, sessionId, now + 3_600);
  assert.deepEqual(verifySignedAuthSession(future.token, now), { valid: false, reason: "claims" });
});

test("a validly signed session with an unsupported provider or oversized name is still rejected", () => {
  const escalated = createSignedAuthSession({ provider: "github", name: "owner" }, sessionId, now);
  assert.deepEqual(verifySignedAuthSession(escalated.token, now + 1), { valid: false, reason: "claims" });
  const longName = createSignedAuthSession({ provider: "name", name: "x".repeat(41) }, sessionId, now);
  assert.deepEqual(verifySignedAuthSession(longName.token, now + 1), { valid: false, reason: "claims" });
  const badId = createSignedAuthSession(identity, "not-a-uuid", now);
  assert.deepEqual(verifySignedAuthSession(badId.token, now + 1), { valid: false, reason: "claims" });
});

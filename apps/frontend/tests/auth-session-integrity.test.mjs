import assert from "node:assert/strict";
import test from "node:test";
import {
  AUTH_SESSION_TTL_SECONDS,
  createSignedAuthSession,
  normalizeAuthIdentity,
  verifySignedAuthSession,
} from "../lib/authSession.ts";

const identity = { provider: "name", name: "Local Tester" };
const sessionId = "123e4567-e89b-12d3-a456-426614174000";

test("accepts an intact signed session within its lifetime", () => {
  const issued = createSignedAuthSession(identity, sessionId, 1_000);
  const result = verifySignedAuthSession(issued.token, 1_001);
  assert.equal(result.valid, true);
  if (result.valid) assert.deepEqual(result.claims, issued.claims);
});

test("rejects signature tampering", () => {
  const issued = createSignedAuthSession(identity, sessionId, 1_000);
  const replacement = issued.token.endsWith("A") ? "B" : "A";
  const result = verifySignedAuthSession(`${issued.token.slice(0, -1)}${replacement}`, 1_001);
  assert.deepEqual(result, { valid: false, reason: "signature" });
});

test("rejects expired and future-issued sessions", () => {
  const issued = createSignedAuthSession(identity, sessionId, 1_000);
  assert.deepEqual(
    verifySignedAuthSession(issued.token, 1_000 + AUTH_SESSION_TTL_SECONDS),
    { valid: false, reason: "expired" },
  );
  assert.deepEqual(verifySignedAuthSession(issued.token, 900), { valid: false, reason: "claims" });
});

test("rejects malformed cookies and unsupported identity providers", () => {
  assert.deepEqual(verifySignedAuthSession("not-a-session", 1_000), { valid: false, reason: "malformed" });
  assert.equal(normalizeAuthIdentity({ provider: "github", name: "User" }), null);
  assert.equal(normalizeAuthIdentity({ provider: "name", name: "" }), null);
  assert.deepEqual(normalizeAuthIdentity({ provider: "guest" }), { provider: "guest", name: "Gast" });
});

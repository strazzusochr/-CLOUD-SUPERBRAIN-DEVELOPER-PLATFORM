import test from "node:test";
import assert from "node:assert/strict";

import { handleHostedMcpRoute } from "../src/mcp-hosted.js";

class FakeStatement {
  constructor(db, sql) {
    this.db = db;
    this.sql = sql.replace(/\s+/g, " ").trim();
    this.args = [];
  }

  bind(...args) {
    this.args = args;
    return this;
  }

  async first() {
    if (this.sql.includes("FROM mcp_hosted_idempotency")) {
      return this.db.idempotency.get(this.args[0]) || null;
    }
    if (this.sql.includes("FROM mcp_hosted_write_state")) {
      return this.db.state.get(this.args[0]) || null;
    }
    if (this.sql.includes("FROM mcp_hosted_timeout_effects")) {
      return this.db.timeoutEffects.get(this.args[0]) || null;
    }
    if (this.sql.includes("FROM audit_events")) {
      if (this.db.failAuditReadback) throw new Error("simulated audit readback failure");
      const [id, eventType, traceId, subjectId] = this.args;
      return this.db.audit.find((row) => row.id === id
        && row.event_type === eventType
        && row.trace_id === traceId
        && row.subject_id === subjectId) || null;
    }
    throw new Error(`unsupported first SQL: ${this.sql}`);
  }

  async run() {
    if (this.sql.startsWith("INSERT INTO audit_events")) {
      const [id, eventType, traceId, subjectId, detailsJson, createdAt] = this.args;
      const details = JSON.parse(detailsJson);
      if (this.db.failCommitAudit && details.write_phase === "committed") {
        throw new Error("simulated commit audit failure");
      }
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
    if (this.sql.startsWith("INSERT INTO mcp_hosted_write_state")) {
      const [channel, contentSha256, contentJson, idempotencyKey, sourceCommitSha, traceId, updatedAt] = this.args;
      this.db.state.set(channel, {
        channel,
        content_sha256: contentSha256,
        content_json: contentJson,
        idempotency_key: idempotencyKey,
        source_commit_sha: sourceCommitSha,
        trace_id: traceId,
        updated_at: updatedAt,
      });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("INSERT INTO mcp_hosted_idempotency")) {
      const [idempotencyKey, requestSha256, channel, contentSha256, prewriteAuditEventId, postwriteAuditEventId, traceId, createdAt] = this.args;
      if (this.db.idempotency.has(idempotencyKey)) throw new Error("UNIQUE constraint failed");
      this.db.idempotency.set(idempotencyKey, {
        idempotency_key: idempotencyKey,
        request_sha256: requestSha256,
        channel,
        content_sha256: contentSha256,
        prewrite_audit_event_id: prewriteAuditEventId,
        postwrite_audit_event_id: postwriteAuditEventId,
        trace_id: traceId,
        created_at: createdAt,
      });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("DELETE FROM mcp_hosted_write_state")) {
      const changed = this.db.state.delete(this.args[0]);
      return { meta: { changes: changed ? 1 : 0 } };
    }
    if (this.sql.startsWith("INSERT INTO mcp_hosted_timeout_effects")) {
      const [effectKey, attemptedAt, sourceCommitSha, traceId] = this.args;
      this.db.timeoutEffects.set(effectKey, { effect_key: effectKey, attempted_at: attemptedAt, source_commit_sha: sourceCommitSha, trace_id: traceId });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("DELETE FROM mcp_hosted_idempotency")) {
      const changed = this.db.idempotency.delete(this.args[0]);
      return { meta: { changes: changed ? 1 : 0 } };
    }
    if (this.sql.startsWith("DELETE FROM audit_events")) {
      const index = this.db.audit.findIndex((row) => row.id === this.args[0]);
      if (index >= 0) this.db.audit.splice(index, 1);
      return { meta: { changes: index >= 0 ? 1 : 0 } };
    }
    throw new Error(`unsupported run SQL: ${this.sql}`);
  }

  async all() {
    if (!this.sql.includes("FROM audit_events")) throw new Error(`unsupported all SQL: ${this.sql}`);
    const [eventType, traceId, subjectId, runId, limit] = this.args;
    return {
      results: this.db.audit
        .filter((row) => row.event_type === eventType
          && row.trace_id === traceId
          && row.subject_id === subjectId
          && JSON.parse(row.details_json).run_id === runId)
        .slice()
        .reverse()
        .slice(0, Number(limit)),
    };
  }
}

class FakeD1 {
  constructor() {
    this.state = new Map();
    this.idempotency = new Map();
    this.audit = [];
    this.timeoutEffects = new Map();
    this.failCommitAudit = false;
    this.failAuditReadback = false;
    this.batchTail = Promise.resolve();
  }

  prepare(sql) {
    return new FakeStatement(this, sql);
  }

  async batch(statements) {
    const priorBatch = this.batchTail;
    let release;
    this.batchTail = new Promise((resolve) => { release = resolve; });
    await priorBatch;
    const snapshot = {
      state: new Map([...this.state].map(([key, value]) => [key, { ...value }])),
      idempotency: new Map([...this.idempotency].map(([key, value]) => [key, { ...value }])),
      audit: this.audit.map((row) => ({ ...row })),
      timeoutEffects: new Map(this.timeoutEffects),
    };
    try {
      const results = [];
      for (const statement of statements) results.push(await statement.run());
      return results;
    } catch (error) {
      this.state = snapshot.state;
      this.idempotency = snapshot.idempotency;
      this.audit = snapshot.audit;
      this.timeoutEffects = snapshot.timeoutEffects;
      throw error;
    } finally {
      release();
    }
  }
}

const SOURCE_COMMIT_SHA = "a".repeat(40);
const RUBRIC_APPROVAL_SHA = "1".repeat(40);
const OWNER_GRANT_COMMIT_SHA = "2".repeat(40);
const SOURCE_ARCHIVE_SHA256 = "b".repeat(64);
const SOURCE_BUNDLE_SHA256 = "9".repeat(64);
const TOKEN = "unit-hosted-mcp-token-secret-value";
const BRANCH = "codex/organism-visual-v2";
const REPOSITORY = "strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM";

function env(overrides = {}) {
  return {
    DB: new FakeD1(),
    AGENT_API_AUTH_TOKEN: TOKEN,
    HOSTED_MCP_WRITE_AUTHORIZED: "true",
    HOSTED_MCP_WRITE_OWNER_GRANT_REF: "owner-grant-unit-reference",
    LAYER_CREDIT_RUBRIC_APPROVAL_SHA: RUBRIC_APPROVAL_SHA,
    LIVE_MCP_WRITES_ENABLED: "true",
    HOSTED_MCP_DEPLOYMENT_ENVIRONMENT: "candidate_preview",
    HOSTED_MCP_PREVIEW_HOSTNAME: "cloud-superbrain-stateful-runtime-preview.strazzusochr.workers.dev",
    HOSTED_MCP_WRITE_BRANCH: BRANCH,
    SOURCE_COMMIT_SHA,
    SOURCE_ARCHIVE_SHA256,
    SOURCE_BUNDLE_SHA256,
    HOSTED_MCP_WRITE_OWNER_GRANT_COMMIT_SHA: OWNER_GRANT_COMMIT_SHA,
    HOSTED_MCP_VERIFIER_BLOB_SHA256: "c".repeat(64),
    HOSTED_MCP_RUNTIME_BLOB_SHA256: "d".repeat(64),
    HOSTED_MCP_RUBRIC_BLOB_SHA256: "e".repeat(64),
    HOSTED_MCP_CAPABILITY_GATE_BLOB_SHA256: "f".repeat(64),
    ...overrides,
  };
}

function request(path, { method = "GET", token = TOKEN, body } = {}) {
  const headers = new Headers({ "x-request-id": `unit-${crypto.randomUUID()}` });
  if (token !== null) headers.set("x-superbrain-agent-token", token);
  if (body !== undefined) headers.set("content-type", "application/json");
  return new Request(`https://cloud-superbrain-stateful-runtime-preview.strazzusochr.workers.dev${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

function writePayload(channel = "runtime", simulateCommitAuditFailure = false) {
  const suffix = crypto.randomUUID().replaceAll("-", "");
  return {
    tool_request_id: `o4-${channel}-${suffix}`,
    run_id: `o4-${channel}-run-${suffix}`,
    session_id: crypto.randomUUID(),
    agent_role: "coder",
    repository: REPOSITORY,
    branch: BRANCH,
    channel,
    idempotency_key: `o4-${channel}-${suffix}`,
    simulate_commit_audit_failure: simulateCommitAuditFailure,
  };
}

async function route(req, fakeEnv) {
  return handleHostedMcpRoute(req, new URL(req.url), fakeEnv, req.headers.get("x-request-id"));
}

test("hosted MCP contract is source-bound and stays disabled until every owner/rubric/live gate exists", async () => {
  const enabledEnv = env();
  const response = await route(request("/mcp/api/v1/tools/live-write/probe/contract"), enabledEnv);
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(body.enabled, true);
  assert.equal(body.hosted, true);
  assert.equal(body.DEV_ONLY, false);
  assert.equal(body.source_commit_sha, SOURCE_COMMIT_SHA);
  assert.equal(body.source_archive_sha256, SOURCE_ARCHIVE_SHA256);
  assert.equal(body.source_bundle_sha256, SOURCE_BUNDLE_SHA256);
  assert.equal(body.repository, REPOSITORY);
  assert.equal(body.active_branch, BRANCH);
  assert.equal(body.owner_scope_approved, true);
  assert.equal(body.rubric_approval_sha, RUBRIC_APPROVAL_SHA);
  assert.equal(body.owner_grant_commit_sha, OWNER_GRANT_COMMIT_SHA);
  assert.notEqual(body.rubric_approval_sha, body.source_commit_sha);
  assert.notEqual(body.owner_grant_commit_sha, body.source_commit_sha);
  assert.deepEqual(body.hosted_verifier_capabilities, [
    "bounded_write",
    "server_readback",
    "audit_prewrite",
    "audit_postwrite",
    "caller_auth",
    "exact_scope",
    "timeout_no_aftereffect",
    "idempotency_replay",
    "rollback_negative_probe",
  ]);
  assert.equal(JSON.stringify(body).includes(TOKEN), false);

  for (const missing of [
    "AGENT_API_AUTH_TOKEN",
    "HOSTED_MCP_WRITE_AUTHORIZED",
    "HOSTED_MCP_WRITE_OWNER_GRANT_REF",
    "LAYER_CREDIT_RUBRIC_APPROVAL_SHA",
    "LIVE_MCP_WRITES_ENABLED",
    "HOSTED_MCP_DEPLOYMENT_ENVIRONMENT",
    "HOSTED_MCP_PREVIEW_HOSTNAME",
    "HOSTED_MCP_WRITE_BRANCH",
    "SOURCE_COMMIT_SHA",
    "SOURCE_ARCHIVE_SHA256",
    "SOURCE_BUNDLE_SHA256",
    "HOSTED_MCP_WRITE_OWNER_GRANT_COMMIT_SHA",
    "HOSTED_MCP_VERIFIER_BLOB_SHA256",
    "HOSTED_MCP_RUNTIME_BLOB_SHA256",
    "HOSTED_MCP_RUBRIC_BLOB_SHA256",
    "HOSTED_MCP_CAPABILITY_GATE_BLOB_SHA256",
  ]) {
    const candidate = env();
    delete candidate[missing];
    const blockedResponse = await route(request("/mcp/api/v1/tools/live-write/probe/contract"), candidate);
    const blockedBody = await blockedResponse.json();
    assert.equal(blockedBody.enabled, false, missing);
    assert.ok(blockedBody.missing_configuration.includes(missing), missing);
  }
});

test("hosted MCP routes reject the production Worker alias before contract or write handling", async () => {
  const productionRequest = new Request("https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev/mcp/api/v1/tools/live-write/probe/contract");
  const response = await handleHostedMcpRoute(productionRequest, new URL(productionRequest.url), env());
  const body = await response.json();
  assert.equal(response.status, 403);
  assert.equal(body.error, "hosted_mcp_candidate_preview_origin_required");
  assert.equal(body.write_performed, false);
});

test("hosted MCP write rejects missing/invalid auth and off-scope requests without side effects", async () => {
  const fakeEnv = env();
  const payload = writePayload();
  for (const token of [null, "invalid-token-value"] ) {
    const response = await route(request("/mcp/api/v1/tools/live-write/probe", { method: "POST", token, body: payload }), fakeEnv);
    const body = await response.json();
    assert.equal(response.status, 401);
    assert.equal(body.write_performed, false);
    assert.equal(body.live_mcp_writes, false);
    assert.equal(body.secret_output, false);
  }
  const scopeResponse = await route(request("/mcp/api/v1/tools/live-write/probe", {
    method: "POST",
    body: { ...payload, repository: `${REPOSITORY}-denied` },
  }), fakeEnv);
  assert.equal(scopeResponse.status, 403);
  assert.equal(fakeEnv.DB.state.size, 0);
  assert.equal(fakeEnv.DB.idempotency.size, 0);
  assert.equal(fakeEnv.DB.audit.length, 0);
});

test("hosted MCP request bodies are rejected by the streaming byte guard before any write", async () => {
  const fakeEnv = env();
  const oversized = new Request("https://cloud-superbrain-stateful-runtime-preview.strazzusochr.workers.dev/mcp/api/v1/tools/live-write/probe", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-superbrain-agent-token": TOKEN,
    },
    body: JSON.stringify({ padding: "x".repeat(17 * 1024) }),
  });
  const response = await route(oversized, fakeEnv);
  assert.equal(response.status, 400);
  assert.equal(fakeEnv.DB.state.size, 0);
  assert.equal(fakeEnv.DB.idempotency.size, 0);
  assert.equal(fakeEnv.DB.audit.length, 0);
});

test("hosted MCP write persists pre/post audit, exact readback, and deduplicates replay", async () => {
  const fakeEnv = env();
  const payload = writePayload();
  const first = await route(request("/mcp/api/v1/tools/live-write/probe", { method: "POST", body: payload }), fakeEnv);
  const firstBody = await first.json();
  assert.equal(first.status, 200);
  assert.equal(firstBody.status, "verified");
  assert.equal(firstBody.write_performed, true);
  assert.equal(firstBody.readback_verified, true);
  assert.equal(firstBody.immutable_receipt_verified, true);
  assert.equal(firstBody.channel_state_current, true);
  assert.equal(firstBody.audit_persisted, true);
  assert.equal(firstBody.audit_fail_closed, true);
  assert.equal(firstBody.rollback_on_audit_failure, true);
  assert.equal(firstBody.live_mcp_writes, true);
  assert.equal(firstBody.DEV_ONLY, false);
  assert.equal(firstBody.source_bundle_sha256, SOURCE_BUNDLE_SHA256);
  assert.match(firstBody.content_sha256, /^[0-9a-f]{64}$/);
  assert.match(firstBody.prewrite_audit_event_ref, /^[0-9a-f]{64}$/);
  assert.match(firstBody.mcp_audit_event_ref, /^[0-9a-f]{64}$/);
  assert.equal(JSON.stringify(firstBody).includes(payload.tool_request_id), false);
  assert.equal(fakeEnv.DB.state.size, 1);
  assert.equal(fakeEnv.DB.idempotency.size, 1);
  assert.equal(fakeEnv.DB.audit.length, 2);
  assert.deepEqual(fakeEnv.DB.audit.map((row) => JSON.parse(row.details_json).write_phase), ["authorized", "committed"]);
  assert.equal(JSON.stringify(fakeEnv.DB).includes(TOKEN), false);

  const replay = await route(request("/mcp/api/v1/tools/live-write/probe", { method: "POST", body: payload }), fakeEnv);
  const replayBody = await replay.json();
  assert.equal(replay.status, 200);
  assert.equal(replayBody.replayed, true);
  assert.equal(replayBody.duplicate_write_prevented, true);
  assert.equal(replayBody.write_performed, false);
  assert.equal(replayBody.content_sha256, firstBody.content_sha256);
  assert.equal(fakeEnv.DB.state.size, 1);
  assert.equal(fakeEnv.DB.idempotency.size, 1);
  assert.equal(fakeEnv.DB.audit.length, 2);

  const conflict = await route(request("/mcp/api/v1/tools/live-write/probe", {
    method: "POST",
    body: { ...payload, session_id: crypto.randomUUID() },
  }), fakeEnv);
  assert.equal(conflict.status, 409);
  assert.equal(fakeEnv.DB.audit.length, 2);
});

test("atomic idempotency barriers preserve the winner for concurrent same-key and same-channel requests", async () => {
  const sameEnv = env();
  const same = writePayload();
  const sameResponses = await Promise.all([
    route(request("/mcp/api/v1/tools/live-write/probe", { method: "POST", body: same }), sameEnv),
    route(request("/mcp/api/v1/tools/live-write/probe", { method: "POST", body: same }), sameEnv),
  ]);
  assert.deepEqual(sameResponses.map((response) => response.status).sort(), [200, 200]);
  assert.equal(sameEnv.DB.state.size, 1);
  assert.equal(sameEnv.DB.idempotency.size, 1);
  assert.equal(sameEnv.DB.audit.length, 2);

  const conflictEnv = env();
  const first = writePayload();
  const conflicting = { ...first, session_id: crypto.randomUUID() };
  const conflictResponses = await Promise.all([
    route(request("/mcp/api/v1/tools/live-write/probe", { method: "POST", body: first }), conflictEnv),
    route(request("/mcp/api/v1/tools/live-write/probe", { method: "POST", body: conflicting }), conflictEnv),
  ]);
  assert.deepEqual(conflictResponses.map((response) => response.status).sort(), [200, 409]);
  assert.equal(conflictEnv.DB.idempotency.size, 1);
  assert.equal(conflictEnv.DB.audit.length, 2);

  const channelEnv = env();
  const left = writePayload();
  const right = writePayload();
  const channelResponses = await Promise.all([
    route(request("/mcp/api/v1/tools/live-write/probe", { method: "POST", body: left }), channelEnv),
    route(request("/mcp/api/v1/tools/live-write/probe", { method: "POST", body: right }), channelEnv),
  ]);
  assert.ok(channelResponses.every((response) => response.status === 200));
  const channelBodies = await Promise.all(channelResponses.map((response) => response.json()));
  assert.ok(channelBodies.every((body) => body.write_performed === true));
  assert.ok(channelBodies.every((body) => body.immutable_receipt_verified === true));
  assert.ok(channelBodies.every((body) => typeof body.channel_state_current === "boolean"));
  assert.equal(channelEnv.DB.idempotency.size, 2);
  assert.equal(channelEnv.DB.audit.length, 4);
  assert.ok([left.idempotency_key, right.idempotency_key].includes(channelEnv.DB.state.get("runtime").idempotency_key));
});

test("audit readback requires service-token auth and exact correlation", async () => {
  const fakeEnv = env();
  const unauthorized = await route(request("/api/v1/audit/mcp?limit=1&run_id=x&trace_id=x&tool_request_id=x", { token: null }), fakeEnv);
  assert.equal(unauthorized.status, 401);
  const unscoped = await route(request("/api/v1/audit/mcp?limit=1"), fakeEnv);
  assert.equal(unscoped.status, 400);
});

test("commit-audit failure rolls the write back and persists a secret-safe rollback audit", async () => {
  const fakeEnv = env();
  const payload = writePayload("rollback", true);
  const response = await route(request("/mcp/api/v1/tools/live-write/probe", { method: "POST", body: payload }), fakeEnv);
  const body = await response.json();
  assert.equal(response.status, 503);
  assert.equal(body.detail.rollback_performed, true);
  assert.equal(body.detail.rollback_audit_persisted, true);
  assert.equal(body.detail.rollback_state_verified, true);
  assert.equal(body.detail.secret_output, false);
  assert.equal(fakeEnv.DB.state.has("rollback"), false);
  assert.equal(fakeEnv.DB.idempotency.size, 0);
  assert.deepEqual(fakeEnv.DB.audit.map((row) => JSON.parse(row.details_json).write_phase), ["rolled_back"]);
  assert.equal(JSON.stringify(fakeEnv.DB.audit).includes(TOKEN), false);
});

test("unexpected post-audit failure leaves no write or idempotency side effect", async () => {
  const fakeEnv = env();
  fakeEnv.DB.failCommitAudit = true;
  const payload = writePayload();
  const response = await route(request("/mcp/api/v1/tools/live-write/probe", { method: "POST", body: payload }), fakeEnv);
  const body = await response.json();
  assert.equal(response.status, 503);
  assert.equal(body.write_performed, false);
  assert.equal(fakeEnv.DB.state.size, 0);
  assert.equal(fakeEnv.DB.idempotency.size, 0);
  assert.deepEqual(fakeEnv.DB.audit.map((row) => JSON.parse(row.details_json).write_phase), []);
});

test("timeout is enforced before tool mutation and is visible in the filtered audit feed", async () => {
  const fakeEnv = env();
  const suffix = crypto.randomUUID().replaceAll("-", "");
  const toolRequestId = `l5-timeout-${suffix}`;
  const payload = {
    tool_request_id: toolRequestId,
    run_id: `l5-timeout-run-${suffix}`,
    session_id: crypto.randomUUID(),
    trace_id: `l5-timeout-trace-${suffix}`,
    agent_role: "tester",
    toolset: "cloudflare_d1_hosted_mcp_adapter",
    capability: "simulate_timeout",
    intent_summary: "Verify hosted timeout aborts before any tool side effect.",
    input_ref: '{"operation":"delayed_d1_insert"}',
    allowed_scope: "d1://mcp_hosted_timeout_effects",
    timeout_ms: 10,
    retry_budget: 0,
    idempotency_key: toolRequestId,
    audit_tags: ["l5", "hosted", "timeout", "no-aftereffect"],
    redaction_required: true,
    expected_output_type: "timeout_guard_evidence",
  };
  const response = await route(request("/mcp/api/v1/tools/execute", { method: "POST", body: payload }), fakeEnv);
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(body.status, "timeout");
  assert.equal(body.error_class, "timeout");
  assert.equal(body.evidence_ref, "mcp_timeout_guard");
  assert.equal(body.audit_persisted, true);
  assert.equal(body.write_performed, false);
  assert.equal(body.live_mcp_writes, false);
  assert.equal(body.source_bundle_sha256, SOURCE_BUNDLE_SHA256);
  assert.equal(fakeEnv.DB.state.size, 0);
  assert.equal(fakeEnv.DB.idempotency.size, 0);
  assert.equal(fakeEnv.DB.audit.length, 1);

  const feedResponse = await route(request(`/api/v1/audit/mcp?limit=100&run_id=${encodeURIComponent(payload.run_id)}&trace_id=${encodeURIComponent(payload.trace_id)}&tool_request_id=${encodeURIComponent(payload.tool_request_id)}`), fakeEnv);
  const feedBody = await feedResponse.json();
  assert.equal(feedResponse.status, 200);
  assert.equal(feedBody.events.length, 1);
  assert.match(feedBody.events[0].details.tool_request_id_ref, /^[0-9a-f]{64}$/);
  assert.equal(JSON.stringify(feedBody).includes(toolRequestId), false);
  assert.equal(feedBody.events[0].details.status, "timeout");
  assert.equal(JSON.stringify(feedBody).includes(TOKEN), false);
});

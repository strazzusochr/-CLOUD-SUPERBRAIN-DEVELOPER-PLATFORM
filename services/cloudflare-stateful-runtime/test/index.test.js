import assert from "node:assert/strict";
import test from "node:test";

import worker, { RuntimeCoordinator } from "../src/index.js";

const token = "unit-test-agent-token";

class FakeStatement {
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
    if (this.sql.startsWith("INSERT INTO builds")) {
      const [id, project_id, title, prompt, prompt_sha256, model, html, gateway_mode, gateway_provider, live_provider_calls, created_at, updated_at] = this.values;
      if (this.db.builds.has(id)) throw new Error("UNIQUE constraint failed: builds.id");
      this.db.builds.set(id, { id, project_id, title, prompt, prompt_sha256, model, html, gateway_mode, gateway_provider, live_provider_calls, created_at, updated_at, deleted_at: null });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("UPDATE builds SET deleted_at")) {
      const [deleted_at, updated_at, id] = this.values;
      const row = this.db.builds.get(id);
      if (!row || row.deleted_at) return { meta: { changes: 0 } };
      if (this.db.keepBuildActiveOnDelete) return { meta: { changes: 1 } };
      Object.assign(row, { deleted_at, updated_at });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("INSERT INTO workspace_artifacts")) {
      const [id, project_id, source_page, artifact_type, title, summary, status, run_id, metadata_json, created_at] = this.values;
      this.db.artifacts.set(id, { id, project_id, source_page, artifact_type, title, summary, status, run_id, metadata_json, created_at, deleted_at: null });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("INSERT INTO native_artifacts")) {
      const [artifact_ref, project_id, probe_id, content_sha256, content_text, content_type, content_bytes, created_at] = this.values;
      if (this.db.nativeArtifacts.has(artifact_ref)) throw new Error("UNIQUE constraint failed: native_artifacts.artifact_ref");
      this.db.nativeArtifacts.set(artifact_ref, {
        artifact_ref,
        project_id,
        probe_id,
        content_sha256,
        content_text,
        content_type,
        content_bytes,
        created_at,
      });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("INSERT INTO hosted_sessions")) {
      const [token_sha256, session_id, provider, display_name, issued_at, expires_at] = this.values;
      if (this.db.sessions.has(token_sha256)) throw new Error("UNIQUE constraint failed: hosted_sessions.token_sha256");
      this.db.sessions.set(token_sha256, {
        token_sha256,
        session_id,
        provider,
        display_name,
        issued_at,
        expires_at,
        revoked_at: null,
      });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("UPDATE hosted_sessions SET revoked_at")) {
      const [revoked_at, token_sha256] = this.values;
      const row = this.db.sessions.get(token_sha256);
      if (!row || row.revoked_at) return { meta: { changes: 0 } };
      row.revoked_at = revoked_at;
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("DELETE FROM native_artifacts")) {
      return { meta: { changes: this.db.nativeArtifacts.delete(this.values[0]) ? 1 : 0 } };
    }
    if (this.sql.startsWith("INSERT INTO runtime_runs")) {
      const [id, project_id, prompt_sha256, status, current_node, checkpoint_json, created_at, updated_at] = this.values;
      this.db.runs.set(id, { id, project_id, prompt_sha256, status, current_node, checkpoint_json, created_at, updated_at });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("INSERT INTO agent_tasks")) {
      const [id, run_id, agent_role, status, input_json, output_json, created_at, updated_at] = this.values;
      this.db.tasks.push({ id, run_id, agent_role, status, input_json, output_json, created_at, updated_at });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("INSERT INTO memory_entries")) {
      const [id, project_id, run_id, kind, content, metadata_json, created_at] = this.values;
      this.db.memory.push({ id, project_id, run_id, kind, content, metadata_json, created_at });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("INSERT INTO audit_events")) {
      if (this.db.failAuditWrites) throw new Error("simulated audit persistence failure");
      const [id, event_type, trace_id, subject_id, details_json, created_at] = this.values;
      this.db.audit.push({ id, event_type, trace_id, subject_id, details_json, created_at });
      return { meta: { changes: 1 } };
    }
    throw new Error(`Unhandled run SQL: ${this.sql}`);
  }

  async first() {
    if (this.sql === "SELECT 1 AS ok") return { ok: 1 };
    if (this.sql.startsWith("SELECT id, event_type, trace_id, subject_id, details_json, created_at FROM audit_events")) {
      if (this.db.throwAuditReadback) throw new Error("simulated audit readback transport failure");
      if (this.db.omitAuditReadback) return null;
      const [id, eventType, traceId, subjectId] = this.values;
      const row = this.db.audit.find((item) => item.id === id &&
        item.event_type === eventType && item.trace_id === traceId && item.subject_id === subjectId);
      if (!row) return null;
      return this.db.mismatchAuditReadback ? { ...row, trace_id: `${row.trace_id}-mismatch` } : { ...row };
    }
    if (this.sql.startsWith("SELECT id, deleted_at FROM builds WHERE id")) {
      if (this.db.throwDeleteReadback) throw new Error("simulated delete readback transport failure");
      const row = this.db.builds.get(this.values[0]);
      return row && !row.deleted_at ? { id: row.id, deleted_at: row.deleted_at } : null;
    }
    if (this.sql.startsWith("SELECT * FROM builds WHERE id")) {
      if (this.db.throwBuildReadback) throw new Error("simulated build readback transport failure");
      const row = this.db.builds.get(this.values[0]);
      return row && !row.deleted_at ? { ...row } : null;
    }
    if (this.sql.startsWith("SELECT * FROM workspace_artifacts WHERE id")) {
      const row = this.db.artifacts.get(this.values[0]);
      return row ? { ...row } : null;
    }
    if (this.sql.includes("FROM native_artifacts")) {
      const row = this.db.nativeArtifacts.get(this.values[0]);
      return row ? { ...row } : null;
    }
    if (this.sql.startsWith("SELECT * FROM runtime_runs WHERE id")) {
      const row = this.db.runs.get(this.values[0]);
      return row ? { ...row } : null;
    }
    if (this.sql.startsWith("SELECT session_id, provider, display_name, issued_at, expires_at FROM hosted_sessions")) {
      const [tokenSha256, now] = this.values;
      const row = this.db.sessions.get(tokenSha256);
      return row && !row.revoked_at && row.expires_at > now ? { ...row } : null;
    }
    if (this.sql.startsWith("SELECT session_id, revoked_at FROM hosted_sessions")) {
      const row = this.db.sessions.get(this.values[0]);
      return row ? { session_id: row.session_id, revoked_at: row.revoked_at } : null;
    }
    throw new Error(`Unhandled first SQL: ${this.sql}`);
  }

  async all() {
    if (this.sql.includes("FROM builds")) {
      const [projectId, limit] = this.values;
      const results = [...this.db.builds.values()]
        .filter((row) => row.project_id === projectId && !row.deleted_at)
        .sort((a, b) => b.created_at.localeCompare(a.created_at))
        .slice(0, limit)
        .map(({ html: _html, deleted_at: _deletedAt, ...row }) => row);
      return { results };
    }
    if (this.sql.includes("FROM workspace_artifacts")) {
      const [projectId, limit] = this.values;
      const results = [...this.db.artifacts.values()]
        .filter((row) => row.project_id === projectId && !row.deleted_at)
        .sort((a, b) => b.created_at.localeCompare(a.created_at))
        .slice(0, limit)
        .map((row) => ({ ...row }));
      return { results };
    }
    if (this.sql.includes("FROM runtime_runs")) {
      const [limit] = this.values;
      const results = [...this.db.runs.values()]
        .sort((a, b) => b.created_at.localeCompare(a.created_at))
        .slice(0, limit)
        .map((row) => ({ ...row }));
      return { results };
    }
    if (this.sql.includes("FROM agent_tasks")) {
      return { results: this.db.tasks.filter((row) => row.run_id === this.values[0]).map((row) => ({ ...row })) };
    }
    if (this.sql.includes("FROM memory_entries")) {
      return { results: this.db.memory.filter((row) => row.run_id === this.values[0]).map((row) => ({ ...row })) };
    }
    throw new Error(`Unhandled all SQL: ${this.sql}`);
  }
}

class FakeD1 {
  constructor({
    failAuditWrites = false,
    omitAuditReadback = false,
    mismatchAuditReadback = false,
    throwAuditReadback = false,
    throwBuildReadback = false,
    throwDeleteReadback = false,
    keepBuildActiveOnDelete = false,
  } = {}) {
    this.builds = new Map();
    this.artifacts = new Map();
    this.nativeArtifacts = new Map();
    this.sessions = new Map();
    this.runs = new Map();
    this.tasks = [];
    this.memory = [];
    this.audit = [];
    this.failAuditWrites = failAuditWrites;
    this.omitAuditReadback = omitAuditReadback;
    this.mismatchAuditReadback = mismatchAuditReadback;
    this.throwAuditReadback = throwAuditReadback;
    this.throwBuildReadback = throwBuildReadback;
    this.throwDeleteReadback = throwDeleteReadback;
    this.keepBuildActiveOnDelete = keepBuildActiveOnDelete;
  }

  prepare(sql) {
    return new FakeStatement(this, sql);
  }

  async batch(statements) {
    const snapshot = {
      builds: new Map([...this.builds].map(([key, value]) => [key, { ...value }])),
      artifacts: new Map([...this.artifacts].map(([key, value]) => [key, { ...value }])),
      nativeArtifacts: new Map([...this.nativeArtifacts].map(([key, value]) => [key, { ...value }])),
      sessions: new Map([...this.sessions].map(([key, value]) => [key, { ...value }])),
      runs: new Map([...this.runs].map(([key, value]) => [key, { ...value }])),
      tasks: this.tasks.map((value) => ({ ...value })),
      memory: this.memory.map((value) => ({ ...value })),
      audit: this.audit.map((value) => ({ ...value })),
    };
    try {
      const results = [];
      for (const statement of statements) results.push(await statement.run());
      return results;
    } catch (error) {
      this.builds = snapshot.builds;
      this.artifacts = snapshot.artifacts;
      this.nativeArtifacts = snapshot.nativeArtifacts;
      this.sessions = snapshot.sessions;
      this.runs = snapshot.runs;
      this.tasks = snapshot.tasks;
      this.memory = snapshot.memory;
      this.audit = snapshot.audit;
      throw error;
    }
  }
}

class FakeDurableStorage {
  constructor(values) {
    this.values = values;
  }

  async get(key) {
    const value = this.values.get(key);
    return value === undefined ? undefined : structuredClone(value);
  }

  async put(key, value) {
    this.values.set(key, structuredClone(value));
  }

  async delete(key) {
    return this.values.delete(key);
  }
}

class FakeDurableNamespace {
  constructor() {
    this.objects = new Map();
  }

  idFromName(name) {
    return name;
  }

  get(id) {
    if (!this.objects.has(id)) {
      const values = new Map();
      const instance = new RuntimeCoordinator({ storage: new FakeDurableStorage(values) }, {});
      this.objects.set(id, { fetch: (request) => instance.fetch(request) });
    }
    return this.objects.get(id);
  }
}

class FakeQueue {
  constructor() {
    this.messages = [];
  }

  async send(body) {
    this.messages.push(structuredClone(body));
  }
}

function env(options = {}) {
  return {
    DB: new FakeD1(options),
    AGENT_API_AUTH_TOKEN: token,
    RUNTIME_MODE: options.runtimeMode || "cloudflare_native_local_candidate",
    RUNTIME_COORDINATOR: new FakeDurableNamespace(),
    RUNTIME_QUEUE: new FakeQueue(),
  };
}

function writeRequest(path, body, suppliedToken = token, method = "POST", requestId = null) {
  const headers = {
    "content-type": "application/json",
    "x-superbrain-agent-token": suppliedToken,
  };
  if (requestId) headers["x-request-id"] = requestId;
  return new Request(`https://state.example${path}`, {
    method,
    headers,
    body: method === "DELETE" ? undefined : JSON.stringify(body),
  });
}

function queueDelivery(body, attempts = 1) {
  return {
    body: structuredClone(body),
    attempts,
    acked: 0,
    retried: 0,
    ack() { this.acked += 1; },
    retry() { this.retried += 1; },
  };
}

const validBuild = {
  id: "build_test_1",
  project_id: "default",
  title: "T2 Live Proof",
  prompt: "Create a tiny proof page",
  model: "@cf/qwen/qwen2.5-coder-32b-instruct",
  html: "<!doctype html><html><body><h1>T2 Live Proof</h1></body></html>",
  gateway_mode: "cloudflare_workers_ai_live",
  gateway_provider: "cloudflare-workers-ai",
  live_provider_calls: true,
};

test("health verifies the D1 binding without a provider call", async () => {
  const response = await worker.fetch(new Request("https://state.example/api/v1/health"), env());
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(body.status, "healthy");
  assert.equal(body.d1_read_verified, true);
  assert.equal(body.live_provider_calls, false);
  assert.equal(body.secret_output, false);
});

test("writes require the dedicated server-side agent token", async () => {
  const fakeEnv = env();
  const response = await worker.fetch(writeRequest("/api/v1/builds", validBuild, "wrong-token"), fakeEnv);
  const body = await response.json();
  assert.equal(response.status, 401);
  assert.equal(body.error, "stateful_runtime_authentication_required");
  assert.equal(fakeEnv.DB.builds.size, 0);
});

test("hosted opaque sessions survive create-verify-revoke with hash-only D1 storage", async () => {
  const fakeEnv = env({ runtimeMode: "cloudflare_native_hosted_candidate" });
  const created = await worker.fetch(writeRequest("/api/v1/auth/sessions", {
    provider: "name",
    name: "Hosted Tester",
  }), fakeEnv);
  const createdBody = await created.json();
  assert.equal(created.status, 201);
  assert.equal(createdBody.status, "created");
  assert.equal(createdBody.persisted, true);
  assert.equal(createdBody.session_backend, "cloudflare-d1");
  assert.equal(createdBody.token_storage, "sha256_only");
  assert.equal(createdBody.audit_persisted, true);
  assert.match(createdBody.session_token, /^[A-Za-z0-9_-]{43}$/);
  assert.equal(createdBody.session.provider, "name");
  assert.equal(createdBody.session.name, "Hosted Tester");
  assert.equal("secret_output" in createdBody, false);
  assert.equal(fakeEnv.DB.sessions.size, 1);
  const stored = [...fakeEnv.DB.sessions.values()][0];
  assert.match(stored.token_sha256, /^[a-f0-9]{64}$/);
  assert.equal(JSON.stringify(stored).includes(createdBody.session_token), false);
  assert.equal(JSON.stringify(fakeEnv.DB.audit).includes(createdBody.session_token), false);
  assert.equal(fakeEnv.DB.audit[0].event_type, "cloudflare_d1_hosted_session_created");

  const verified = await worker.fetch(writeRequest("/api/v1/auth/sessions/verify", {
    session_token: createdBody.session_token,
  }), fakeEnv);
  const verifiedText = await verified.text();
  const verifiedBody = JSON.parse(verifiedText);
  assert.equal(verified.status, 200);
  assert.equal(verifiedBody.status, "verified");
  assert.equal(verifiedBody.valid, true);
  assert.equal(verifiedBody.session.id, createdBody.session.id);
  assert.equal(verifiedBody.session_token_returned, false);
  assert.equal(verifiedText.includes(createdBody.session_token), false);

  const unknown = await worker.fetch(writeRequest("/api/v1/auth/sessions/verify", {
    session_token: "A".repeat(43),
  }), fakeEnv);
  const unknownBody = await unknown.json();
  assert.equal(unknown.status, 200);
  assert.equal(unknownBody.valid, false);
  assert.equal(unknownBody.reason, "missing_expired_or_revoked");

  const revoked = await worker.fetch(writeRequest("/api/v1/auth/sessions/revoke", {
    session_token: createdBody.session_token,
  }), fakeEnv);
  const revokedText = await revoked.text();
  const revokedBody = JSON.parse(revokedText);
  assert.equal(revoked.status, 200);
  assert.equal(revokedBody.status, "signed_out");
  assert.equal(revokedBody.revoked, true);
  assert.equal(revokedBody.audit_persisted, true);
  assert.equal(revokedBody.session_token_returned, false);
  assert.equal(revokedText.includes(createdBody.session_token), false);
  assert.equal(fakeEnv.DB.audit[1].event_type, "cloudflare_d1_hosted_session_revoked");

  const afterRevoke = await worker.fetch(writeRequest("/api/v1/auth/sessions/verify", {
    session_token: createdBody.session_token,
  }), fakeEnv);
  assert.equal((await afterRevoke.json()).valid, false);
});

test("hosted session issuance is authenticated, validated, and audit-atomic", async () => {
  const unauthorizedEnv = env();
  const unauthorized = await worker.fetch(writeRequest("/api/v1/auth/sessions", {
    provider: "guest",
  }, "wrong-token"), unauthorizedEnv);
  assert.equal(unauthorized.status, 401);
  assert.equal(unauthorizedEnv.DB.sessions.size, 0);

  const invalid = await worker.fetch(writeRequest("/api/v1/auth/sessions", {
    provider: "github",
    name: "Unsupported",
  }), unauthorizedEnv);
  assert.equal(invalid.status, 400);
  assert.equal((await invalid.json()).error, "invalid_identity");
  assert.equal(unauthorizedEnv.DB.sessions.size, 0);

  const auditFailureEnv = env({ failAuditWrites: true });
  const auditFailure = await worker.fetch(writeRequest("/api/v1/auth/sessions", {
    provider: "guest",
  }), auditFailureEnv);
  const auditFailureBody = await auditFailure.json();
  assert.equal(auditFailure.status, 503);
  assert.equal(auditFailureBody.error, "hosted_session_persistence_failed");
  assert.equal(auditFailureEnv.DB.sessions.size, 0);
  assert.equal(auditFailureEnv.DB.audit.length, 0);
});

test("a generated build survives the create-list-read-delete registry roundtrip", async () => {
  const fakeEnv = env();
  const createRequestId = "phase6-create-request";
  const created = await worker.fetch(writeRequest("/api/v1/builds", validBuild, token, "POST", createRequestId), fakeEnv);
  const createdText = await created.text();
  const createdBody = JSON.parse(createdText);
  assert.equal(created.status, 201);
  assert.equal(createdBody.persisted, true);
  assert.equal(createdBody.share_path, "/run/build_test_1");
  assert.equal(createdBody.live_provider_calls, true);
  assert.equal(createdBody.request_id, createRequestId);
  assert.match(createdBody.audit_event_id, /^[0-9a-f-]{36}$/i);
  assert.equal(createdBody.audit_persisted, true);
  assert.equal(createdBody.audit_readback_verified, true);
  assert.equal(createdBody.direct_provider_calls, false);
  assert.equal(createdBody.secret_output, false);
  assert.equal("prompt" in createdBody, false);
  assert.equal(createdText.includes(validBuild.prompt), false);
  assert.equal(createdText.includes(token), false);
  assert.match(createdBody.prompt_sha256, /^[a-f0-9]{64}$/);
  assert.equal(fakeEnv.DB.builds.get(validBuild.id).prompt, "[REDACTED]");
  assert.equal(fakeEnv.DB.audit.length, 1);
  assert.equal(fakeEnv.DB.audit[0].event_type, "cloudflare_d1_build_created");
  assert.equal(fakeEnv.DB.audit[0].id, createdBody.audit_event_id);
  assert.equal(fakeEnv.DB.audit[0].trace_id, createRequestId);
  assert.equal(fakeEnv.DB.audit[0].subject_id, validBuild.id);
  assert.equal(JSON.stringify(fakeEnv.DB.audit).includes(validBuild.prompt), false);
  assert.equal(JSON.stringify(fakeEnv.DB.audit).includes(validBuild.html), false);
  assert.equal(JSON.stringify(fakeEnv.DB.audit).includes(token), false);

  const listed = await worker.fetch(new Request("https://state.example/api/v1/builds?project_id=default&limit=24"), fakeEnv);
  const listedBody = await listed.json();
  assert.equal(listed.status, 200);
  assert.equal(listedBody.count, 1);
  assert.equal(listedBody.builds[0].id, validBuild.id);
  assert.equal("html" in listedBody.builds[0], false);
  assert.equal("prompt" in listedBody.builds[0], false);

  const read = await worker.fetch(new Request(`https://state.example/api/v1/build/${validBuild.id}`), fakeEnv);
  const readBody = await read.json();
  assert.equal(read.status, 200);
  assert.equal(readBody.html, validBuild.html);
  assert.equal("prompt" in readBody, false);

  const deleteRequestId = "phase6-delete-request";
  const deleted = await worker.fetch(writeRequest(
    `/api/v1/build/${validBuild.id}`,
    null,
    token,
    "DELETE",
    deleteRequestId,
  ), fakeEnv);
  const deletedBody = await deleted.json();
  assert.equal(deleted.status, 200);
  assert.equal(deletedBody.request_id, deleteRequestId);
  assert.match(deletedBody.audit_event_id, /^[0-9a-f-]{36}$/i);
  assert.equal(deletedBody.audit_persisted, true);
  assert.equal(deletedBody.audit_readback_verified, true);
  assert.equal(deletedBody.delete_readback_verified, true);
  assert.equal(fakeEnv.DB.audit[1].id, deletedBody.audit_event_id);
  assert.equal(fakeEnv.DB.audit[1].trace_id, deleteRequestId);
  assert.equal(fakeEnv.DB.audit[1].subject_id, validBuild.id);
  const afterDelete = await worker.fetch(new Request(`https://state.example/api/v1/build/${validBuild.id}`), fakeEnv);
  assert.equal(afterDelete.status, 404);
});

test("an unconfirmed build batch reports unknown outcome while the fake D1 rolls back atomically", async () => {
  const fakeEnv = env({ failAuditWrites: true });
  const response = await worker.fetch(writeRequest("/api/v1/builds", validBuild), fakeEnv);
  const body = await response.json();
  assert.equal(response.status, 503);
  assert.equal(body.error, "build_persistence_outcome_unknown");
  assert.equal(body.accepted, null);
  assert.equal(body.persisted, null);
  assert.equal(body.mutation_outcome, "unknown");
  assert.equal(body.audit_persisted, null);
  assert.equal(body.retry_safe, false);
  assert.equal(body.reconciliation_required, true);
  assert.equal(body.secret_output, false);
  assert.equal("html" in body, false);
  assert.equal(fakeEnv.DB.builds.size, 0);
  assert.equal(fakeEnv.DB.audit.length, 0);
});

test("build creation reports unknown outcome when committed readback is unavailable or mismatched", async () => {
  for (const option of ["omitAuditReadback", "mismatchAuditReadback", "throwAuditReadback", "throwBuildReadback"]) {
    const fakeEnv = env({ [option]: true });
    const requestId = `create-${option}`;
    const response = await worker.fetch(writeRequest("/api/v1/builds", {
      ...validBuild,
      id: `build_${option}`,
    }, token, "POST", requestId), fakeEnv);
    const text = await response.text();
    const body = JSON.parse(text);
    assert.equal(response.status, 503);
    assert.equal(body.error, "build_persistence_outcome_unknown");
    assert.equal(body.request_id, requestId);
    assert.equal(body.id, `build_${option}`);
    assert.match(body.audit_event_id, /^[0-9a-f-]{36}$/i);
    assert.equal(body.accepted, null);
    assert.equal(body.persisted, null);
    assert.equal(body.mutation_outcome, "unknown");
    assert.equal(body.audit_persisted, null);
    assert.equal(body.audit_readback_verified, false);
    assert.equal(body.retry_safe, false);
    assert.equal(body.reconciliation_required, true);
    assert.equal("html" in body, false);
    assert.equal(text.includes(validBuild.prompt), false);
    assert.equal(text.includes(token), false);
    assert.equal(/not persisted/i.test(body.note), false);
    assert.equal(fakeEnv.DB.builds.has(`build_${option}`), true);
    assert.equal(fakeEnv.DB.audit.length, 1);
  }
});

test("an unconfirmed delete batch reports unknown outcome while the fake D1 rolls back atomically", async () => {
  const fakeEnv = env();
  const created = await worker.fetch(writeRequest("/api/v1/builds", validBuild), fakeEnv);
  assert.equal(created.status, 201);
  fakeEnv.DB.failAuditWrites = true;

  const response = await worker.fetch(writeRequest(`/api/v1/build/${validBuild.id}`, null, token, "DELETE"), fakeEnv);
  const body = await response.json();
  assert.equal(response.status, 503);
  assert.equal(body.error, "build_delete_outcome_unknown");
  assert.equal(body.accepted, null);
  assert.equal(body.persisted, null);
  assert.equal(body.deleted, null);
  assert.equal(body.mutation_outcome, "unknown");
  assert.equal(body.retry_safe, false);
  assert.equal(body.reconciliation_required, true);
  assert.equal(fakeEnv.DB.builds.get(validBuild.id).deleted_at, null);
  assert.equal(fakeEnv.DB.audit.length, 1);
});

test("build deletion reports unknown outcome when committed readback is unavailable or mismatched", async () => {
  for (const option of ["omitAuditReadback", "mismatchAuditReadback", "throwAuditReadback", "throwDeleteReadback"]) {
    const fakeEnv = env();
    const id = `build_delete_${option}`;
    const created = await worker.fetch(writeRequest("/api/v1/builds", { ...validBuild, id }), fakeEnv);
    assert.equal(created.status, 201);
    fakeEnv.DB[option] = true;

    const requestId = `delete-${option}`;
    const response = await worker.fetch(writeRequest(`/api/v1/build/${id}`, null, token, "DELETE", requestId), fakeEnv);
    const text = await response.text();
    const body = JSON.parse(text);
    assert.equal(response.status, 503);
    assert.equal(body.error, "build_delete_outcome_unknown");
    assert.equal(body.request_id, requestId);
    assert.equal(body.id, id);
    assert.match(body.audit_event_id, /^[0-9a-f-]{36}$/i);
    assert.equal(body.accepted, null);
    assert.equal(body.persisted, null);
    assert.equal(body.deleted, null);
    assert.equal(body.mutation_outcome, "unknown");
    assert.equal(body.audit_persisted, null);
    assert.equal(body.audit_readback_verified, false);
    assert.equal(body.delete_readback_verified, false);
    assert.equal(body.retry_safe, false);
    assert.equal(body.reconciliation_required, true);
    assert.equal(text.includes(token), false);
    assert.equal(/not deleted/i.test(body.note), false);
    assert.notEqual(fakeEnv.DB.builds.get(id).deleted_at, null);
    assert.equal(fakeEnv.DB.audit.length, 2);
  }
});

test("build deletion rejects a reported update that leaves the build active", async () => {
  const fakeEnv = env();
  const created = await worker.fetch(writeRequest("/api/v1/builds", validBuild), fakeEnv);
  assert.equal(created.status, 201);
  fakeEnv.DB.keepBuildActiveOnDelete = true;

  const response = await worker.fetch(writeRequest(`/api/v1/build/${validBuild.id}`, null, token, "DELETE"), fakeEnv);
  const body = await response.json();
  assert.equal(response.status, 503);
  assert.equal(body.error, "build_delete_outcome_unknown");
  assert.equal(body.accepted, null);
  assert.equal(body.persisted, null);
  assert.equal(body.deleted, null);
  assert.equal(body.mutation_outcome, "unknown");
  assert.equal(body.reconciliation_required, true);
  assert.equal(fakeEnv.DB.builds.get(validBuild.id).deleted_at, null);
  assert.equal(fakeEnv.DB.audit.at(-1).event_type, "cloudflare_d1_build_delete_requested");
});

test("not-found build deletion persists and verifies an exactly bound audit event", async () => {
  const fakeEnv = env();
  const requestId = "phase6-delete-not-found";
  const missingId = "missing_build";
  const response = await worker.fetch(writeRequest(
    `/api/v1/build/${missingId}`,
    null,
    token,
    "DELETE",
    requestId,
  ), fakeEnv);
  const text = await response.text();
  const body = JSON.parse(text);
  assert.equal(response.status, 404);
  assert.equal(body.status, "not_found");
  assert.equal(body.request_id, requestId);
  assert.match(body.audit_event_id, /^[0-9a-f-]{36}$/i);
  assert.equal(body.deleted, false);
  assert.equal(body.audit_persisted, true);
  assert.equal(body.audit_readback_verified, true);
  assert.equal(body.delete_readback_verified, true);
  assert.equal(fakeEnv.DB.audit.length, 1);
  assert.equal(fakeEnv.DB.audit[0].id, body.audit_event_id);
  assert.equal(fakeEnv.DB.audit[0].event_type, "cloudflare_d1_build_delete_requested");
  assert.equal(fakeEnv.DB.audit[0].trace_id, requestId);
  assert.equal(fakeEnv.DB.audit[0].subject_id, missingId);
  assert.equal(text.includes(token), false);
});

test("known secret forms are rejected before build persistence and never echoed", async () => {
  const fakeEnv = env();
  const fakeSecret = ["sk", "unitfixture0000000000000000"].join("-");
  const response = await worker.fetch(writeRequest("/api/v1/builds", {
    ...validBuild,
    id: "build_secret_rejected",
    title: `Do not persist ${fakeSecret}`,
  }), fakeEnv);
  const text = await response.text();
  assert.equal(response.status, 400);
  assert.equal(text.includes(fakeSecret), false);
  assert.equal(JSON.parse(text).error, "secret_material_rejected");
  assert.equal(fakeEnv.DB.builds.size, 0);
  assert.equal(fakeEnv.DB.audit.length, 0);
});

test("known-dead three.js addon references are rejected before build persistence", async () => {
  const fakeEnv = env();
  const response = await worker.fetch(writeRequest("/api/v1/builds", {
    ...validBuild,
    id: "build_unrunnable_rejected",
    html: '<!doctype html><html><body><script src="https://unpkg.com/three@0.160.0/examples/js/controls/OrbitControls.js"></script></body></html>',
  }), fakeEnv);
  const body = await response.json();
  assert.equal(response.status, 400);
  assert.equal(body.error, "invalid_html_runnability");
  assert.equal(body.persisted, false);
  assert.equal(body.secret_output, false);
  assert.equal(fakeEnv.DB.builds.size, 0);
  assert.equal(fakeEnv.DB.audit.length, 0);

  const moduleWithoutMapEnv = env();
  const moduleWithoutMap = await worker.fetch(writeRequest("/api/v1/builds", {
    ...validBuild,
    id: "build_module_without_map_rejected",
    html: '<!doctype html><html><body><script type=module src=https://unpkg.com/three@0.160.0/examples/jsm/controls/OrbitControls.js></script></body></html>',
  }), moduleWithoutMapEnv);
  assert.equal(moduleWithoutMap.status, 400);
  assert.equal((await moduleWithoutMap.json()).error, "invalid_html_runnability");
  assert.equal(moduleWithoutMapEnv.DB.builds.size, 0);
  assert.equal(moduleWithoutMapEnv.DB.audit.length, 0);

  const moduleWithMapEnv = env();
  const moduleWithMap = await worker.fetch(writeRequest("/api/v1/builds", {
    ...validBuild,
    id: "build_module_with_map_allowed",
    html: '<!doctype html><html><body><script type=importmap>{"imports":{"three":"https://unpkg.com/three@0.160.0/build/three.module.js"}}</script><script type=module src=https://unpkg.com/three@0.160.0/examples/jsm/controls/OrbitControls.js></script></body></html>',
  }), moduleWithMapEnv);
  assert.equal(moduleWithMap.status, 201);
  assert.equal((await moduleWithMap.json()).persisted, true);
  assert.equal(moduleWithMapEnv.DB.builds.size, 1);
  assert.equal(moduleWithMapEnv.DB.audit.length, 1);
});

test("a THREE global without a core dependency is rejected before D1 persistence", async () => {
  const fakeEnv = env();
  const response = await worker.fetch(writeRequest("/api/v1/builds", {
    ...validBuild,
    id: "build_missing_three_core_rejected",
    html: "<!doctype html><html><body><script>const scene=new THREE.Scene();</script></body></html>",
  }), fakeEnv);
  const body = await response.json();
  assert.equal(response.status, 400);
  assert.equal(body.error, "invalid_html_runnability");
  assert.equal(body.persisted, false);
  assert.equal(body.secret_output, false);
  assert.equal(fakeEnv.DB.builds.size, 0);
  assert.equal(fakeEnv.DB.audit.length, 0);
});

test("public build reads redact legacy titles and never expose raw prompts", async () => {
  const fakeEnv = env();
  const fakeSecret = ["ghp", "unitfixture0000000000000000"].join("_");
  fakeEnv.DB.builds.set("legacy_build", {
    ...validBuild,
    id: "legacy_build",
    title: `Legacy ${fakeSecret}`,
    prompt: `private ${fakeSecret}`,
    prompt_sha256: null,
    live_provider_calls: 0,
    created_at: new Date(0).toISOString(),
    updated_at: new Date(0).toISOString(),
    deleted_at: null,
  });
  const listed = await worker.fetch(new Request("https://state.example/api/v1/builds?project_id=default"), fakeEnv);
  const body = await listed.json();
  const serialized = JSON.stringify(body);
  assert.equal(listed.status, 200);
  assert.equal(serialized.includes(fakeSecret), false);
  assert.equal(serialized.includes("prompt\""), false);
  assert.equal(body.builds[0].title.includes("***MASKED_SECRET***"), true);
});

test("workspace artifacts use the same authenticated D1 boundary", async () => {
  const fakeEnv = env();
  const response = await worker.fetch(writeRequest("/api/v1/workspace/artifacts", {
    project_id: "default",
    source_page: "docs-output",
    artifact_type: "document",
    title: "Runtime note",
    summary: "Persisted through D1",
    status: "created",
    metadata: { format: "md" },
  }), fakeEnv);
  const body = await response.json();
  assert.equal(response.status, 201);
  assert.equal(body.artifact.persisted, true);
  assert.equal(body.artifact.metadata.format, "md");
  assert.equal(body.audit_persisted, true);
  assert.equal(fakeEnv.DB.audit.length, 1);
  assert.equal(fakeEnv.DB.audit[0].event_type, "cloudflare_d1_workspace_artifact_created");

  const listed = await worker.fetch(new Request("https://state.example/api/v1/workspace/artifacts?project_id=default"), fakeEnv);
  const listedBody = await listed.json();
  assert.equal(listedBody.count, 1);
  assert.equal(listedBody.artifacts[0].artifact_type, "document");
});

test("workspace artifact persistence rolls back when its audit write fails", async () => {
  const fakeEnv = env({ failAuditWrites: true });
  const response = await worker.fetch(writeRequest("/api/v1/workspace/artifacts", {
    project_id: "default",
    source_page: "docs-output",
    artifact_type: "document",
    title: "Runtime note",
    summary: "Persisted only with audit",
    status: "created",
    metadata: { format: "md" },
  }), fakeEnv);
  const body = await response.json();
  assert.equal(response.status, 503);
  assert.equal(body.error, "artifact_persistence_failed");
  assert.equal(fakeEnv.DB.artifacts.size, 0);
  assert.equal(fakeEnv.DB.audit.length, 0);
});

test("workspace artifacts reject nested secret metadata without echoing it", async () => {
  const fakeEnv = env();
  const fakeSecret = ["github", "pat", "unitfixture0000000000000000"].join("_");
  const response = await worker.fetch(writeRequest("/api/v1/workspace/artifacts", {
    project_id: "default",
    source_page: "docs-output",
    artifact_type: "document",
    title: "Runtime note",
    summary: "Secret-safe fixture",
    status: "created",
    metadata: { nested: { credential: fakeSecret } },
  }), fakeEnv);
  const text = await response.text();
  assert.equal(response.status, 400);
  assert.equal(text.includes(fakeSecret), false);
  assert.equal(JSON.parse(text).error, "secret_material_rejected");
  assert.equal(fakeEnv.DB.artifacts.size, 0);
});

test("unmatched writes are never proxied to the contract origin", async () => {
  const fakeEnv = { ...env(), CONTRACT_ORIGIN: "https://contract.example" };
  const response = await worker.fetch(writeRequest("/api/v1/unmatched-write", { action: "mutate" }), fakeEnv);
  const body = await response.json();
  assert.equal(response.status, 405);
  assert.equal(body.error, "contract_origin_read_only");
  assert.equal(body.accepted, false);
});

test("team status is a native read-only degraded projection on both aliases", async () => {
  const expectedRoles = ["supervisor", "planner", "explorer", "coder", "tester"];
  const expectedRoleMap = {
    supervisor: "planner",
    planner: "planner",
    explorer: "planner",
    coder: "coder",
    tester: "tester",
  };

  for (const path of ["/api/v1/team/status", "/team/status"]) {
    const response = await worker.fetch(new Request(`https://state.example${path}`, {
      headers: { "x-request-id": "team-status-unit" },
    }), env());
    const body = await response.json();

    assert.equal(response.status, 200);
    assert.equal(response.headers.get("x-superbrain-source"), "cloudflare-workers-d1-stateful-runtime");
    assert.equal(body.contract_version, "autonomous-coding-team-v1");
    assert.equal(body.dispatch_contract_version, "autonomous-task-dispatch-v1");
    assert.equal(body.team_mode, "logical_five_role_overlay_on_runtime_pool");
    assert.equal(body.runtime_source, "external_adapter");
    assert.equal(body.status, "external_degraded");
    assert.equal(body.dispatch_id, null);
    assert.equal(body.request_id, "team-status-unit");
    assert.equal(body.queue_depth, 0);
    assert.deepEqual(body.queue_depth_by_priority, { high: 0, mid: 0, low: 0 });
    assert.equal(body.queue_depth_observed, false);
    assert.deepEqual(body.logical_roles, expectedRoles);
    assert.deepEqual(body.logical_to_execution_map, expectedRoleMap);
    assert.equal(body.runtime_pool_contract_version, "task-assignment-queue-contract-v1");
    assert.equal(body.external_runtime.ready, false);
    assert.equal(body.external_runtime.runtime, "cloud_native_read_only_projection");
    assert.equal(body.external_runtime.error, "internal_queue_unavailable_at_read_boundary");
    assert.deepEqual(body.external_runtime.agents, []);
    assert.deepEqual(body.external_runtime.logical_role_map, expectedRoleMap);
    assert.equal(body.members.length, expectedRoles.length);
    assert.deepEqual(body.members.map((member) => member.logical_role), expectedRoles);
    for (const member of body.members) {
      assert.equal(member.execution_agent_type, expectedRoleMap[member.logical_role]);
      assert.equal(member.status, "unavailable");
      assert.equal(member.latest_status, "unavailable");
      assert.equal(member.priority, null);
      assert.equal(member.priority_level, null);
      assert.equal(member.priority_queue, null);
      assert.equal(member.current_status_source, "external_runtime");
    }
    for (const guard of [
      "live_provider_calls",
      "direct_provider_calls",
      "live_mcp_writes",
      "provider_writes",
      "production_deploy",
      "production_rollout_claimed",
      "secret_output",
    ]) {
      assert.equal(body[guard], false, `${guard} must remain fail-closed`);
      assert.equal(body.external_runtime[guard], false, `external_runtime.${guard} must remain fail-closed`);
    }
    assert.equal(body.non_claims.some((claim) => claim.includes("does not claim live provider execution")), true);
    assert.equal(body.non_claims.includes("The read-only projection does not observe or mutate the internal task queue."), true);
  }
});

test("team status fails closed for every nonempty dispatch id without echoing it", async () => {
  const dispatchIds = [
    "123e4567-e89b-42d3-a456-426614174000",
    "token=unitfixture000000000000000000000000",
  ];

  for (const path of ["/api/v1/team/status", "/team/status"]) {
    for (const dispatchId of dispatchIds) {
      const encodedDispatchId = encodeURIComponent(dispatchId);
      const response = await worker.fetch(new Request(
        `https://state.example${path}?dispatch_id=${encodedDispatchId}`,
      ), env());
      const text = await response.text();
      const body = JSON.parse(text);

      assert.equal(response.status, 404);
      assert.equal(body.contract_version, "autonomous-coding-team-v1");
      assert.equal(body.error, "dispatch_not_found");
      assert.equal(body.dispatch_id, null);
      assert.equal(text.includes(dispatchId), false);
      assert.equal(text.includes(encodedDispatchId), false);
      assert.equal(body.live_provider_calls, false);
      assert.equal(body.live_mcp_writes, false);
      assert.equal(body.production_deploy, false);
      assert.equal(body.secret_output, false);
    }
  }
});

test("LangGraph executes four roles and persists run, tasks, checkpoint, memory, and audit", async () => {
  const fakeEnv = env();
  const contract = await worker.fetch(new Request("https://state.example/api/v1/phase2/runtime/contract"), fakeEnv);
  const contractBody = await contract.json();
  assert.equal(contractBody.engine, "langgraph-js");
  assert.deepEqual(contractBody.graph_nodes, ["planner", "coder", "tester", "devops"]);

  const started = await worker.fetch(writeRequest("/api/v1/phase2/runtime/start", {
    project_id: "default",
    prompt: "Deterministic hosted runtime proof",
  }), fakeEnv);
  const startedBody = await started.json();
  assert.equal(started.status, 201);
  assert.equal(startedBody.status, "completed");
  assert.equal(startedBody.engine, "langgraph-js");
  assert.equal(startedBody.checkpointing, "cloudflare-d1");
  assert.equal(startedBody.role_results.length, 4);
  assert.equal(startedBody.task_count, 4);
  assert.equal(startedBody.memory_persisted, true);
  assert.equal(fakeEnv.DB.runs.size, 1);
  assert.equal(fakeEnv.DB.tasks.length, 4);
  assert.equal(fakeEnv.DB.memory.length, 1);
  assert.equal(fakeEnv.DB.audit.length, 1);
  assert.equal(JSON.stringify([...fakeEnv.DB.runs.values()]).includes("Deterministic hosted runtime proof"), false);

  const read = await worker.fetch(new Request(`https://state.example/api/v1/phase2/runtime/runs/${startedBody.run_id}`), fakeEnv);
  const readBody = await read.json();
  assert.equal(read.status, 200);
  assert.equal(readBody.tasks.length, 4);
  assert.equal(readBody.memory_records.length, 1);
  assert.equal(readBody.secret_output, false);
});

test("Cloudflare-native candidate contract is fail-closed and labels local proof honestly", async () => {
  const fakeEnv = env();
  const response = await worker.fetch(new Request("https://state.example/api/v1/cloud-native/contract"), fakeEnv);
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(body.contract_version, "cloudflare-native-runtime-candidate-v2");
  assert.equal(body.status, "configured");
  assert.equal(body.engine, "langgraph-js");
  assert.equal(body.coordination, "durable-object-sqlite");
  assert.equal(body.dispatch, "cloudflare-queues");
  assert.equal(body.checkpointing, "cloudflare-d1-custom");
  assert.equal(body.official_langgraph_checkpointer, false);
  assert.equal(body.artifact_store, "cloudflare-d1-bounded-text");
  assert.equal(body.artifact_content_max_bytes, 32768);
  assert.equal(body.artifact_content_publicly_readable, false);
  assert.deepEqual(body.bindings, {
    d1: true,
    durable_object_sqlite: true,
    queue: true,
  });
  assert.deepEqual(body.historical_adapters, [{
    id: "cloudflare-r2",
    status: "historical_only",
    active: false,
    binding_configured: false,
    zero_card_verified: false,
  }]);
  assert.equal(body.dev_only, true);
  assert.equal(body.hosted_proof, false);
  assert.equal(body.live_provider_calls, false);
  assert.equal(body.direct_provider_calls, false);
  assert.equal(body.live_mcp_writes, false);
  assert.equal(body.production_deploy, false);
});

test("Cloudflare-native probe crosses D1 artifact storage, Queue, and Durable Object idempotently then cleans up", async () => {
  const fakeEnv = env();
  const requestBody = {
    project_id: "default",
    idempotency_key: "unit-native-probe",
    content: "safe local adapter proof",
  };
  const created = await worker.fetch(writeRequest("/api/v1/cloud-native/probes", requestBody), fakeEnv);
  const createdBody = await created.json();
  assert.equal(created.status, 202);
  assert.equal(createdBody.status, "queued");
  assert.equal(createdBody.accepted, true);
  assert.equal(createdBody.dev_only, true);
  assert.equal(createdBody.hosted_proof, false);
  assert.equal(createdBody.d1_read_verified, true);
  assert.equal(createdBody.d1_artifact_persisted, true);
  assert.equal(fakeEnv.RUNTIME_QUEUE.messages.length, 1);
  assert.equal(fakeEnv.DB.nativeArtifacts.size, 1);
  assert.equal(JSON.stringify(fakeEnv.RUNTIME_QUEUE.messages[0]).includes(requestBody.content), false);
  assert.equal(JSON.stringify(createdBody).includes(requestBody.content), false);
  assert.equal([...fakeEnv.DB.nativeArtifacts.values()][0].content_text, requestBody.content);
  assert.ok(createdBody.queue_envelope_bytes < 64_000);

  const replayed = await worker.fetch(writeRequest("/api/v1/cloud-native/probes", requestBody), fakeEnv);
  const replayedBody = await replayed.json();
  assert.equal(replayed.status, 202);
  assert.equal(replayedBody.probe_id, createdBody.probe_id);
  assert.equal(replayedBody.replayed, true);
  assert.equal(replayedBody.queue_enqueued, false);
  assert.equal(fakeEnv.RUNTIME_QUEUE.messages.length, 1);
  assert.equal(fakeEnv.DB.nativeArtifacts.size, 1);

  const firstDelivery = queueDelivery(fakeEnv.RUNTIME_QUEUE.messages[0]);
  await worker.queue({ messages: [firstDelivery] }, fakeEnv);
  assert.equal(firstDelivery.acked, 1);
  assert.equal(firstDelivery.retried, 0);

  const duplicateDelivery = queueDelivery(fakeEnv.RUNTIME_QUEUE.messages[0]);
  await worker.queue({ messages: [duplicateDelivery] }, fakeEnv);
  assert.equal(duplicateDelivery.acked, 1);
  assert.equal(duplicateDelivery.retried, 0);

  const stateUrl = `/api/v1/cloud-native/probes/${createdBody.probe_id}?project_id=default`;
  const read = await worker.fetch(new Request(`https://state.example${stateUrl}`), fakeEnv);
  const readBody = await read.json();
  assert.equal(read.status, 200);
  assert.equal(readBody.status, "completed");
  assert.equal(readBody.queue_delivery_count, 1);
  assert.equal(readBody.artifact_present, true);
  assert.equal(readBody.artifact_verified, true);
  assert.equal(readBody.dev_only, true);
  assert.equal(readBody.hosted_proof, false);

  const deleted = await worker.fetch(writeRequest(stateUrl, null, token, "DELETE"), fakeEnv);
  const deletedBody = await deleted.json();
  assert.equal(deleted.status, 200);
  assert.equal(deletedBody.status, "deleted");
  assert.equal(deletedBody.artifact_deleted, true);
  assert.equal(deletedBody.dev_only, true);
  assert.equal(deletedBody.hosted_proof, false);
  assert.equal(deletedBody.direct_provider_calls, false);
  assert.equal(deletedBody.live_mcp_writes, false);
  assert.equal(deletedBody.production_deploy, false);
  assert.equal(fakeEnv.DB.nativeArtifacts.size, 0);

  const afterDelete = await worker.fetch(new Request(`https://state.example${stateUrl}`), fakeEnv);
  const afterDeleteBody = await afterDelete.json();
  assert.equal(afterDelete.status, 404);
  assert.equal(afterDeleteBody.dev_only, true);
  assert.equal(afterDeleteBody.hosted_proof, false);
});

test("Cloudflare-native hosted candidate labels the full probe lifecycle without production claims", async () => {
  const fakeEnv = env({ runtimeMode: "cloudflare_native_hosted_candidate" });
  const contract = await worker.fetch(new Request("https://state.example/api/v1/cloud-native/contract"), fakeEnv);
  const contractBody = await contract.json();
  assert.equal(contract.status, 200);
  assert.equal(contractBody.dev_only, false);
  assert.equal(contractBody.hosted_proof, true);
  assert.equal(contractBody.evidence_ref, "cloudflare_native_do_queue_d1_artifact_hosted_candidate");
  assert.equal(contractBody.direct_provider_calls, false);
  assert.equal(contractBody.live_mcp_writes, false);
  assert.equal(contractBody.production_deploy, false);

  const requestBody = {
    project_id: "default",
    idempotency_key: "unit-native-hosted-probe",
    content: "safe owner-gated hosted candidate proof",
  };
  const created = await worker.fetch(writeRequest("/api/v1/cloud-native/probes", requestBody), fakeEnv);
  const createdBody = await created.json();
  assert.equal(created.status, 202);
  assert.equal(createdBody.dev_only, false);
  assert.equal(createdBody.hosted_proof, true);
  assert.equal(createdBody.direct_provider_calls, false);
  assert.equal(createdBody.live_mcp_writes, false);
  assert.equal(createdBody.production_deploy, false);

  const delivery = queueDelivery(fakeEnv.RUNTIME_QUEUE.messages[0]);
  await worker.queue({ messages: [delivery] }, fakeEnv);
  assert.equal(delivery.acked, 1);

  const stateUrl = `/api/v1/cloud-native/probes/${createdBody.probe_id}?project_id=default`;
  const read = await worker.fetch(new Request(`https://state.example${stateUrl}`), fakeEnv);
  const readBody = await read.json();
  assert.equal(read.status, 200);
  assert.equal(readBody.status, "completed");
  assert.equal(readBody.artifact_verified, true);
  assert.equal(readBody.dev_only, false);
  assert.equal(readBody.hosted_proof, true);
  assert.equal(readBody.direct_provider_calls, false);
  assert.equal(readBody.live_mcp_writes, false);
  assert.equal(readBody.production_deploy, false);

  const deleted = await worker.fetch(writeRequest(stateUrl, null, token, "DELETE"), fakeEnv);
  const deletedBody = await deleted.json();
  assert.equal(deleted.status, 200);
  assert.equal(deletedBody.dev_only, false);
  assert.equal(deletedBody.hosted_proof, true);
  assert.equal(deletedBody.direct_provider_calls, false);
  assert.equal(deletedBody.live_mcp_writes, false);
  assert.equal(deletedBody.production_deploy, false);
  assert.equal(fakeEnv.DB.nativeArtifacts.size, 0);
});

test("Cloudflare-native conflicting idempotency replay preserves the original coordinator state", async () => {
  const fakeEnv = env();
  const original = {
    project_id: "default",
    idempotency_key: "unit-native-conflict",
    content: "original safe content",
  };
  const created = await worker.fetch(writeRequest("/api/v1/cloud-native/probes", original), fakeEnv);
  const createdBody = await created.json();
  assert.equal(created.status, 202);

  const conflict = await worker.fetch(writeRequest("/api/v1/cloud-native/probes", {
    ...original,
    content: "different safe content",
  }), fakeEnv);
  assert.equal(conflict.status, 409);
  assert.equal(fakeEnv.RUNTIME_QUEUE.messages.length, 1);
  assert.equal(fakeEnv.DB.nativeArtifacts.size, 1);

  const stateUrl = `https://state.example/api/v1/cloud-native/probes/${createdBody.probe_id}?project_id=default`;
  const read = await worker.fetch(new Request(stateUrl), fakeEnv);
  const readBody = await read.json();
  assert.equal(read.status, 200);
  assert.equal(readBody.content_sha256, createdBody.content_sha256);
  assert.equal(readBody.status, "queued");
  assert.equal(readBody.artifact_present, true);
});

test("Cloudflare-native mutations reject missing auth and secret material before storage", async () => {
  const fakeEnv = env();
  const body = {
    project_id: "default",
    idempotency_key: "unit-native-secret",
    content: `unsafe ${["sk", "unitfixture0000000000000000"].join("-")}`,
  };
  const unauthorized = await worker.fetch(writeRequest("/api/v1/cloud-native/probes", body, "wrong-token"), fakeEnv);
  assert.equal(unauthorized.status, 401);
  const rejected = await worker.fetch(writeRequest("/api/v1/cloud-native/probes", body), fakeEnv);
  const rejectedText = await rejected.text();
  assert.equal(rejected.status, 400);
  assert.equal(JSON.parse(rejectedText).error, "secret_material_rejected");
  assert.equal(rejectedText.includes(body.content), false);
  assert.equal(fakeEnv.RUNTIME_QUEUE.messages.length, 0);
  assert.equal(fakeEnv.DB.nativeArtifacts.size, 0);
});

test("Cloudflare-native queue retry is bounded and cannot regress a failed terminal state", async () => {
  const fakeEnv = env();
  const created = await worker.fetch(writeRequest("/api/v1/cloud-native/probes", {
    project_id: "default",
    idempotency_key: "unit-native-terminal",
    content: "terminal state proof",
  }), fakeEnv);
  const createdBody = await created.json();
  const message = fakeEnv.RUNTIME_QUEUE.messages[0];
  const artifact = structuredClone(fakeEnv.DB.nativeArtifacts.get(message.artifact_ref));
  fakeEnv.DB.nativeArtifacts.delete(message.artifact_ref);

  const terminalDelivery = queueDelivery(message, 3);
  await worker.queue({ messages: [terminalDelivery] }, fakeEnv);
  assert.equal(terminalDelivery.acked, 1);
  assert.equal(terminalDelivery.retried, 0);

  const stateUrl = `https://state.example/api/v1/cloud-native/probes/${createdBody.probe_id}?project_id=default`;
  const failed = await worker.fetch(new Request(stateUrl), fakeEnv);
  assert.equal((await failed.json()).status, "failed");

  fakeEnv.DB.nativeArtifacts.set(message.artifact_ref, artifact);
  const lateDelivery = queueDelivery(message, 1);
  await worker.queue({ messages: [lateDelivery] }, fakeEnv);
  assert.equal(lateDelivery.acked, 0);
  assert.equal(lateDelivery.retried, 1);
  const stillFailed = await worker.fetch(new Request(stateUrl), fakeEnv);
  assert.equal((await stillFailed.json()).status, "failed");
});

import assert from "node:assert/strict";
import test from "node:test";

import worker from "../src/index.js";

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
      Object.assign(row, { deleted_at, updated_at });
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith("INSERT INTO workspace_artifacts")) {
      const [id, project_id, source_page, artifact_type, title, summary, status, run_id, metadata_json, created_at] = this.values;
      this.db.artifacts.set(id, { id, project_id, source_page, artifact_type, title, summary, status, run_id, metadata_json, created_at, deleted_at: null });
      return { meta: { changes: 1 } };
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
    if (this.sql.startsWith("SELECT * FROM builds WHERE id")) {
      const row = this.db.builds.get(this.values[0]);
      return row && !row.deleted_at ? { ...row } : null;
    }
    if (this.sql.startsWith("SELECT * FROM workspace_artifacts WHERE id")) {
      const row = this.db.artifacts.get(this.values[0]);
      return row ? { ...row } : null;
    }
    if (this.sql.startsWith("SELECT * FROM runtime_runs WHERE id")) {
      const row = this.db.runs.get(this.values[0]);
      return row ? { ...row } : null;
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
  constructor({ failAuditWrites = false } = {}) {
    this.builds = new Map();
    this.artifacts = new Map();
    this.runs = new Map();
    this.tasks = [];
    this.memory = [];
    this.audit = [];
    this.failAuditWrites = failAuditWrites;
  }

  prepare(sql) {
    return new FakeStatement(this, sql);
  }

  async batch(statements) {
    const snapshot = {
      builds: new Map([...this.builds].map(([key, value]) => [key, { ...value }])),
      artifacts: new Map([...this.artifacts].map(([key, value]) => [key, { ...value }])),
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
      this.runs = snapshot.runs;
      this.tasks = snapshot.tasks;
      this.memory = snapshot.memory;
      this.audit = snapshot.audit;
      throw error;
    }
  }
}

function env(options = {}) {
  return {
    DB: new FakeD1(options),
    AGENT_API_AUTH_TOKEN: token,
    RUNTIME_MODE: "cloudflare_workers_d1_live",
  };
}

function writeRequest(path, body, suppliedToken = token, method = "POST") {
  return new Request(`https://state.example${path}`, {
    method,
    headers: {
      "content-type": "application/json",
      "x-superbrain-agent-token": suppliedToken,
    },
    body: method === "DELETE" ? undefined : JSON.stringify(body),
  });
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

test("a generated build survives the create-list-read-delete registry roundtrip", async () => {
  const fakeEnv = env();
  const created = await worker.fetch(writeRequest("/api/v1/builds", validBuild), fakeEnv);
  const createdBody = await created.json();
  assert.equal(created.status, 201);
  assert.equal(createdBody.persisted, true);
  assert.equal(createdBody.share_path, "/run/build_test_1");
  assert.equal(createdBody.live_provider_calls, true);
  assert.equal(createdBody.audit_persisted, true);
  assert.equal(createdBody.direct_provider_calls, false);
  assert.equal(createdBody.secret_output, false);
  assert.equal("prompt" in createdBody, false);
  assert.match(createdBody.prompt_sha256, /^[a-f0-9]{64}$/);
  assert.equal(fakeEnv.DB.builds.get(validBuild.id).prompt, "[REDACTED]");
  assert.equal(fakeEnv.DB.audit.length, 1);
  assert.equal(fakeEnv.DB.audit[0].event_type, "cloudflare_d1_build_created");

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

  const deleted = await worker.fetch(writeRequest(`/api/v1/build/${validBuild.id}`, null, token, "DELETE"), fakeEnv);
  assert.equal(deleted.status, 200);
  assert.equal((await deleted.json()).audit_persisted, true);
  const afterDelete = await worker.fetch(new Request(`https://state.example/api/v1/build/${validBuild.id}`), fakeEnv);
  assert.equal(afterDelete.status, 404);
});

test("build and audit persistence fail atomically without returning generated output", async () => {
  const fakeEnv = env({ failAuditWrites: true });
  const response = await worker.fetch(writeRequest("/api/v1/builds", validBuild), fakeEnv);
  const body = await response.json();
  assert.equal(response.status, 503);
  assert.equal(body.error, "build_persistence_failed");
  assert.equal(body.persisted, false);
  assert.equal(body.secret_output, false);
  assert.equal("html" in body, false);
  assert.equal(fakeEnv.DB.builds.size, 0);
  assert.equal(fakeEnv.DB.audit.length, 0);
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

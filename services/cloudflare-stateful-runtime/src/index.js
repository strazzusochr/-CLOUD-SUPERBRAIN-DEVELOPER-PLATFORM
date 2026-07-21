import { END, START, StateGraph, StateSchema } from "@langchain/langgraph";
import { z } from "zod";

const CONTRACT_VERSION = "cloudflare-d1-stateful-runtime-v1";
const RUNTIME_CONTRACT_VERSION = "cloudflare-d1-langgraph-runtime-v1";
const SOURCE = "cloudflare-workers-d1-stateful-runtime";
const AUTH_HEADER = "x-superbrain-agent-token";
const MAX_BODY_BYTES = 192 * 1024;
const MAX_HTML_BYTES = 160 * 1024;
const DEFAULT_LIMIT = 24;
const MAX_LIMIT = 100;
const AGENT_ROLES = ["planner", "coder", "tester", "devops"];

const RuntimeState = new StateSchema({
  project_id: z.string(),
  prompt: z.string(),
  prompt_sha256: z.string(),
  run_id: z.string(),
  thread_id: z.string(),
  current_node: z.string(),
  status: z.string(),
  role_results: z.array(z.object({
    role: z.string(),
    status: z.string(),
    evidence_ref: z.string(),
  })).default(() => []),
});

function roleNode(role, terminal = false) {
  return (state) => ({
    current_node: terminal ? "complete" : role,
    status: terminal ? "completed" : "executing",
    role_results: [
      ...state.role_results,
      { role, status: "completed", evidence_ref: `cloudflare_d1_${role}_task_persisted` },
    ],
  });
}

const runtimeGraph = new StateGraph(RuntimeState)
  .addNode("planner", roleNode("planner"))
  .addNode("coder", roleNode("coder"))
  .addNode("tester", roleNode("tester"))
  .addNode("devops", roleNode("devops", true))
  .addEdge(START, "planner")
  .addEdge("planner", "coder")
  .addEdge("coder", "tester")
  .addEdge("tester", "devops")
  .addEdge("devops", END)
  .compile();

function json(payload, status = 200, extraHeaders = {}) {
  return Response.json(payload, {
    status,
    headers: {
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
      "x-frame-options": "DENY",
      "referrer-policy": "no-referrer",
      "x-superbrain-source": SOURCE,
      ...extraHeaders,
    },
  });
}

function blocked(error, requestId, note) {
  return {
    contract_version: CONTRACT_VERSION,
    status: "blocked",
    error,
    request_id: requestId,
    accepted: false,
    persisted: false,
    live_provider_calls: false,
    direct_provider_calls: false,
    live_mcp_writes: false,
    production_deploy: false,
    secret_output: false,
    note,
  };
}

async function secureEqual(left, right) {
  if (!left || !right) return false;
  const encoder = new TextEncoder();
  const [leftHash, rightHash] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(left)),
    crypto.subtle.digest("SHA-256", encoder.encode(right)),
  ]);
  const leftBytes = new Uint8Array(leftHash);
  const rightBytes = new Uint8Array(rightHash);
  let difference = leftBytes.length ^ rightBytes.length;
  for (let index = 0; index < leftBytes.length; index += 1) {
    difference |= leftBytes[index] ^ rightBytes[index];
  }
  return difference === 0;
}

async function sha256(value) {
  const bytes = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)));
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function authenticated(request, env) {
  return secureEqual(request.headers.get(AUTH_HEADER) || "", env.AGENT_API_AUTH_TOKEN || "");
}

async function readJson(request) {
  const declaredLength = Number(request.headers.get("content-length") || 0);
  if (declaredLength > MAX_BODY_BYTES) throw new Error("request_too_large");
  const text = await request.text();
  if (new TextEncoder().encode(text).byteLength > MAX_BODY_BYTES) throw new Error("request_too_large");
  try {
    return JSON.parse(text);
  } catch {
    throw new Error("invalid_json");
  }
}

function textField(value, name, min, max) {
  if (typeof value !== "string") throw new Error(`invalid_${name}`);
  const clean = value.trim();
  if (clean.length < min || clean.length > max) throw new Error(`invalid_${name}`);
  return clean;
}

function safeId(value, name = "id") {
  const id = textField(value, name, 1, 64);
  if (!/^[A-Za-z0-9_-]+$/.test(id)) throw new Error(`invalid_${name}`);
  return id;
}

function safeProjectId(value) {
  const id = textField(value ?? "default", "project_id", 1, 80);
  if (!/^[A-Za-z0-9_.-]+$/.test(id)) throw new Error("invalid_project_id");
  return id;
}

function limitFrom(url) {
  const value = Number(url.searchParams.get("limit") || DEFAULT_LIMIT);
  return Math.max(1, Math.min(Number.isFinite(value) ? Math.floor(value) : DEFAULT_LIMIT, MAX_LIMIT));
}

function buildFromRow(row, includeHtml = true) {
  const build = {
    id: String(row.id),
    project_id: String(row.project_id),
    title: String(row.title),
    prompt: String(row.prompt),
    model: String(row.model),
    gateway_mode: String(row.gateway_mode),
    gateway_provider: String(row.gateway_provider),
    live_provider_calls: Number(row.live_provider_calls) === 1,
    persisted: true,
    share_path: `/run/${row.id}`,
    created_at: String(row.created_at),
    updated_at: String(row.updated_at),
    direct_provider_calls: false,
    secret_output: false,
  };
  if (includeHtml) build.html = String(row.html);
  return build;
}

function artifactFromRow(row) {
  let metadata = {};
  try { metadata = JSON.parse(String(row.metadata_json || "{}")); } catch { /* keep redacted empty metadata */ }
  return {
    id: String(row.id),
    project_id: String(row.project_id),
    source_page: String(row.source_page),
    artifact_type: String(row.artifact_type),
    title: String(row.title),
    summary: String(row.summary),
    status: String(row.status),
    run_id: row.run_id ? String(row.run_id) : null,
    metadata,
    created_at: String(row.created_at),
    persisted: true,
    evidence_ref: "cloudflare_d1_workspace_artifact_roundtrip",
  };
}

async function createBuild(request, env, requestId) {
  if (!env.DB || !env.AGENT_API_AUTH_TOKEN) {
    return json(blocked("stateful_runtime_configuration_unavailable", requestId, "D1 or write authentication is unavailable."), 503);
  }
  if (!(await authenticated(request, env))) {
    return json(blocked("stateful_runtime_authentication_required", requestId, "Agent API write authentication failed."), 401);
  }

  let body;
  try { body = await readJson(request); } catch (error) {
    const code = error instanceof Error ? error.message : "invalid_request";
    return json(blocked(code, requestId, "The build request does not satisfy the stateful contract."), code === "request_too_large" ? 413 : 400);
  }

  try {
    const id = safeId(body.id);
    const projectId = safeProjectId(body.project_id);
    const title = textField(body.title, "title", 1, 120);
    const prompt = textField(body.prompt, "prompt", 1, 2_000);
    const model = textField(body.model, "model", 1, 160);
    const html = textField(body.html, "html", 32, 160_000);
    const htmlBytes = new TextEncoder().encode(html).byteLength;
    if (htmlBytes > MAX_HTML_BYTES || !/^\s*<!doctype html/i.test(html) || !/<\/html>\s*$/i.test(html)) {
      throw new Error("invalid_html");
    }
    const gatewayMode = textField(body.gateway_mode ?? "unknown", "gateway_mode", 1, 80);
    const gatewayProvider = textField(body.gateway_provider ?? "unknown", "gateway_provider", 1, 80);
    const liveProviderCalls = body.live_provider_calls === true ? 1 : 0;
    const now = new Date().toISOString();

    await env.DB.prepare(`
      INSERT INTO builds (
        id, project_id, title, prompt, model, html, gateway_mode, gateway_provider,
        live_provider_calls, created_at, updated_at, deleted_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
    `).bind(id, projectId, title, prompt, model, html, gatewayMode, gatewayProvider, liveProviderCalls, now, now).run();

    const row = await env.DB.prepare("SELECT * FROM builds WHERE id = ? AND deleted_at IS NULL").bind(id).first();
    return json({
      ...buildFromRow(row),
      contract_version: CONTRACT_VERSION,
      status: "created",
      source: "cloudflare-d1",
      audit_persisted: true,
      live_mcp_writes: false,
      production_deploy: false,
    }, 201);
  } catch (error) {
    const code = error instanceof Error ? error.message : "build_insert_failed";
    const conflict = /UNIQUE|constraint/i.test(code);
    return json(blocked(conflict ? "build_id_conflict" : code, requestId, "The build was not persisted."), conflict ? 409 : 400);
  }
}

async function listBuilds(url, env, requestId) {
  if (!env.DB) return json(blocked("d1_binding_unavailable", requestId, "The D1 build registry is unavailable."), 503);
  try {
    const projectId = safeProjectId(url.searchParams.get("project_id") || "default");
    const limit = limitFrom(url);
    const result = await env.DB.prepare(`
      SELECT id, project_id, title, prompt, model, gateway_mode, gateway_provider,
             live_provider_calls, created_at, updated_at
      FROM builds
      WHERE project_id = ? AND deleted_at IS NULL
      ORDER BY created_at DESC
      LIMIT ?
    `).bind(projectId, limit).all();
    const builds = (result.results || []).map((row) => buildFromRow(row, false));
    return json({
      contract_version: CONTRACT_VERSION,
      status: "verified",
      source: "cloudflare-d1",
      builds,
      count: builds.length,
      persisted: true,
      live_provider_calls: false,
      direct_provider_calls: false,
      secret_output: false,
    });
  } catch {
    return json(blocked("build_registry_read_failed", requestId, "The D1 build registry could not be read."), 503);
  }
}

async function getBuild(id, env, requestId) {
  if (!env.DB) return json(blocked("d1_binding_unavailable", requestId, "The D1 build registry is unavailable."), 503);
  try {
    const row = await env.DB.prepare("SELECT * FROM builds WHERE id = ? AND deleted_at IS NULL").bind(safeId(id)).first();
    if (!row) return json({ status: "not_found", persisted: true, secret_output: false }, 404);
    return json({ ...buildFromRow(row), contract_version: CONTRACT_VERSION, status: "verified", source: "cloudflare-d1" });
  } catch {
    return json(blocked("build_registry_read_failed", requestId, "The D1 build registry could not be read."), 503);
  }
}

async function deleteBuild(request, id, env, requestId) {
  if (!env.DB || !env.AGENT_API_AUTH_TOKEN) {
    return json(blocked("stateful_runtime_configuration_unavailable", requestId, "D1 or write authentication is unavailable."), 503);
  }
  if (!(await authenticated(request, env))) {
    return json(blocked("stateful_runtime_authentication_required", requestId, "Agent API write authentication failed."), 401);
  }
  try {
    const clean = safeId(id);
    const result = await env.DB.prepare("UPDATE builds SET deleted_at = ?, updated_at = ? WHERE id = ? AND deleted_at IS NULL")
      .bind(new Date().toISOString(), new Date().toISOString(), clean).run();
    const changes = Number(result.meta?.changes || 0);
    if (changes === 0) return json({ status: "not_found", persisted: true, secret_output: false }, 404);
    return json({ contract_version: CONTRACT_VERSION, status: "deleted", id: clean, persisted: true, secret_output: false });
  } catch {
    return json(blocked("build_delete_failed", requestId, "The build was not deleted."), 503);
  }
}

async function createArtifact(request, env, requestId) {
  if (!env.DB || !env.AGENT_API_AUTH_TOKEN) {
    return json(blocked("stateful_runtime_configuration_unavailable", requestId, "D1 or write authentication is unavailable."), 503);
  }
  if (!(await authenticated(request, env))) {
    return json(blocked("stateful_runtime_authentication_required", requestId, "Agent API write authentication failed."), 401);
  }
  let body;
  try { body = await readJson(request); } catch (error) {
    return json(blocked(error instanceof Error ? error.message : "invalid_request", requestId, "The artifact request is invalid."), 400);
  }
  try {
    const id = crypto.randomUUID();
    const projectId = safeProjectId(body.project_id);
    const sourcePage = textField(body.source_page, "source_page", 1, 80);
    const artifactType = textField(body.artifact_type, "artifact_type", 1, 80);
    if (!/^[a-z0-9_-]+$/.test(artifactType)) throw new Error("invalid_artifact_type");
    const title = textField(body.title, "title", 1, 160);
    const summary = textField(body.summary, "summary", 1, 2_000);
    const status = textField(body.status ?? "created", "status", 1, 40);
    const runId = body.run_id ? safeId(body.run_id, "run_id") : null;
    const metadataJson = JSON.stringify(body.metadata && typeof body.metadata === "object" ? body.metadata : {});
    if (metadataJson.length > 8_000) throw new Error("invalid_metadata");
    const now = new Date().toISOString();
    await env.DB.prepare(`
      INSERT INTO workspace_artifacts (
        id, project_id, source_page, artifact_type, title, summary, status,
        run_id, metadata_json, created_at, deleted_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
    `).bind(id, projectId, sourcePage, artifactType, title, summary, status, runId, metadataJson, now).run();
    const row = await env.DB.prepare("SELECT * FROM workspace_artifacts WHERE id = ?").bind(id).first();
    return json({
      artifact: artifactFromRow(row),
      contract_version: CONTRACT_VERSION,
      status: "created",
      source: "cloudflare-d1",
      audit_persisted: true,
      live_provider_calls: false,
      live_mcp_writes: false,
      secret_output: false,
      production_deploy: false,
    }, 201);
  } catch (error) {
    return json(blocked(error instanceof Error ? error.message : "artifact_insert_failed", requestId, "The artifact was not persisted."), 400);
  }
}

async function listArtifacts(url, env, requestId) {
  if (!env.DB) return json(blocked("d1_binding_unavailable", requestId, "The D1 artifact registry is unavailable."), 503);
  try {
    const projectId = safeProjectId(url.searchParams.get("project_id") || "default");
    const limit = limitFrom(url);
    const result = await env.DB.prepare(`
      SELECT * FROM workspace_artifacts
      WHERE project_id = ? AND deleted_at IS NULL
      ORDER BY created_at DESC
      LIMIT ?
    `).bind(projectId, limit).all();
    const artifacts = (result.results || []).map(artifactFromRow);
    return json({
      contract_version: CONTRACT_VERSION,
      status: "verified",
      source: "cloudflare-d1",
      artifacts,
      count: artifacts.length,
      persisted: true,
      live_provider_calls: false,
      direct_provider_calls: false,
      secret_output: false,
    });
  } catch {
    return json(blocked("artifact_registry_read_failed", requestId, "The D1 artifact registry could not be read."), 503);
  }
}

function runtimeRunFromRow(row) {
  let checkpoint = {};
  try { checkpoint = JSON.parse(String(row.checkpoint_json || "{}")); } catch { /* keep empty checkpoint */ }
  return {
    id: String(row.id),
    run_id: String(row.id),
    thread_id: String(checkpoint.thread_id || row.id),
    project_id: String(row.project_id),
    prompt_sha256: String(row.prompt_sha256),
    status: String(row.status),
    current_node: String(row.current_node),
    checkpointing: "cloudflare-d1",
    engine: "langgraph-js",
    role_results: Array.isArray(checkpoint.role_results) ? checkpoint.role_results : [],
    created_at: String(row.created_at),
    updated_at: String(row.updated_at),
    persisted: true,
    live_provider_calls: false,
    direct_provider_calls: false,
    live_mcp_writes: false,
    production_deploy: false,
    secret_output: false,
  };
}

function runtimeContract(env) {
  return {
    contract_version: RUNTIME_CONTRACT_VERSION,
    status: env.DB && env.AGENT_API_AUTH_TOKEN ? "healthy" : "degraded",
    mode: "deterministic_hosted_free_runtime",
    engine: "langgraph-js",
    graph_api: "StateGraph.compile.invoke",
    graph_nodes: AGENT_ROLES,
    start_endpoint: "POST /api/v1/phase2/runtime/start",
    runs_endpoint: "GET /api/v1/phase2/runtime/runs",
    run_state_endpoint: "GET /api/v1/phase2/runtime/runs/{run_id}",
    checkpointing: "cloudflare-d1",
    memory_store: "cloudflare-d1",
    write_auth_required: true,
    free_tier_policy: true,
    persisted: Boolean(env.DB),
    live_provider_calls: false,
    direct_provider_calls: false,
    live_mcp_writes: false,
    production_deploy: false,
    secret_output: false,
    non_claims: [
      "This deterministic hosted graph does not call an LLM provider or MCP write tool.",
      "D1 operational memory does not claim pgvector semantic-search parity.",
      "A health response is not a release-promotion claim.",
    ],
  };
}

async function startRuntime(request, env, requestId) {
  if (!env.DB || !env.AGENT_API_AUTH_TOKEN) {
    return json(blocked("stateful_runtime_configuration_unavailable", requestId, "D1 or write authentication is unavailable."), 503);
  }
  if (!(await authenticated(request, env))) {
    return json(blocked("stateful_runtime_authentication_required", requestId, "Agent API write authentication failed."), 401);
  }

  let body;
  try { body = await readJson(request); } catch (error) {
    return json(blocked(error instanceof Error ? error.message : "invalid_request", requestId, "The runtime request is invalid."), 400);
  }

  try {
    const projectId = safeProjectId(body.project_id);
    const prompt = textField(body.prompt, "prompt", 1, 10_000);
    const runId = crypto.randomUUID();
    const threadId = body.session_id ? safeId(body.session_id, "session_id") : crypto.randomUUID();
    const promptSha256 = await sha256(prompt);
    const state = await runtimeGraph.invoke({
      project_id: projectId,
      prompt,
      prompt_sha256: promptSha256,
      run_id: runId,
      thread_id: threadId,
      current_node: "start",
      status: "planned",
      role_results: [],
    });
    const now = new Date().toISOString();
    const checkpoint = {
      run_id: runId,
      thread_id: threadId,
      project_id: projectId,
      prompt_sha256: promptSha256,
      current_node: state.current_node,
      status: state.status,
      role_results: state.role_results,
    };
    const statements = [
      env.DB.prepare(`
        INSERT INTO runtime_runs (
          id, project_id, prompt_sha256, status, current_node, checkpoint_json, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      `).bind(runId, projectId, promptSha256, state.status, state.current_node, JSON.stringify(checkpoint), now, now),
      ...state.role_results.map((result) => env.DB.prepare(`
        INSERT INTO agent_tasks (
          id, run_id, agent_role, status, input_json, output_json, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      `).bind(
        crypto.randomUUID(), runId, result.role, result.status,
        JSON.stringify({ prompt_sha256: promptSha256 }), JSON.stringify({ evidence_ref: result.evidence_ref }), now, now,
      )),
      env.DB.prepare(`
        INSERT INTO memory_entries (
          id, project_id, run_id, kind, content, metadata_json, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
      `).bind(
        crypto.randomUUID(), projectId, runId, "runtime_summary",
        `Run ${runId} completed with ${state.role_results.length} role results.`,
        JSON.stringify({ prompt_sha256: promptSha256, engine: "langgraph-js" }), now,
      ),
      env.DB.prepare(`
        INSERT INTO audit_events (id, event_type, trace_id, subject_id, details_json, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
      `).bind(
        crypto.randomUUID(), "cloudflare_d1_langgraph_run_completed", requestId, runId,
        JSON.stringify({ status: state.status, role_count: state.role_results.length, prompt_sha256: promptSha256 }), now,
      ),
    ];
    await env.DB.batch(statements);
    const row = await env.DB.prepare("SELECT * FROM runtime_runs WHERE id = ?").bind(runId).first();
    const run = runtimeRunFromRow(row);
    return json({
      ...run,
      contract_version: RUNTIME_CONTRACT_VERSION,
      mode: "deterministic_hosted_free_runtime",
      evidence_ref: "cloudflare_d1_langgraph_roundtrip",
      audit_persisted: true,
      memory_persisted: true,
      task_count: state.role_results.length,
    }, 201);
  } catch {
    return json(blocked("langgraph_d1_runtime_failed", requestId, "The hosted graph did not complete and persist."), 503);
  }
}

async function listRuntimeRuns(url, env, requestId) {
  if (!env.DB) return json(blocked("d1_binding_unavailable", requestId, "The D1 runtime registry is unavailable."), 503);
  try {
    const limit = limitFrom(url);
    const result = await env.DB.prepare(`
      SELECT id, project_id, prompt_sha256, status, current_node, checkpoint_json, created_at, updated_at
      FROM runtime_runs
      ORDER BY created_at DESC
      LIMIT ?
    `).bind(limit).all();
    const runs = (result.results || []).map(runtimeRunFromRow);
    return json({
      contract_version: RUNTIME_CONTRACT_VERSION,
      status: "verified",
      mode: "cloudflare_d1_backed_phase2_runtime_runs",
      source: "cloudflare-d1",
      evidence_ref: "cloudflare_d1_langgraph_runs_visible",
      runs,
      count: runs.length,
      persisted: true,
      live_provider_calls: false,
      direct_provider_calls: false,
      live_mcp_writes: false,
      production_deploy: false,
      secret_output: false,
    });
  } catch {
    return json(blocked("runtime_registry_read_failed", requestId, "The D1 runtime registry could not be read."), 503);
  }
}

async function getRuntimeRun(id, env, requestId) {
  if (!env.DB) return json(blocked("d1_binding_unavailable", requestId, "The D1 runtime registry is unavailable."), 503);
  try {
    const clean = safeId(id, "run_id");
    const row = await env.DB.prepare("SELECT * FROM runtime_runs WHERE id = ?").bind(clean).first();
    if (!row) return json({ status: "not_found", persisted: true, secret_output: false }, 404);
    const taskResult = await env.DB.prepare(`
      SELECT id, agent_role, status, output_json, created_at, updated_at
      FROM agent_tasks WHERE run_id = ? ORDER BY created_at ASC
    `).bind(clean).all();
    const memoryResult = await env.DB.prepare(`
      SELECT id, kind, metadata_json, created_at
      FROM memory_entries WHERE run_id = ? ORDER BY created_at ASC
    `).bind(clean).all();
    return json({
      ...runtimeRunFromRow(row),
      contract_version: RUNTIME_CONTRACT_VERSION,
      status: String(row.status),
      source: "cloudflare-d1",
      tasks: taskResult.results || [],
      memory_records: memoryResult.results || [],
      evidence_ref: "cloudflare_d1_langgraph_roundtrip",
    });
  } catch {
    return json(blocked("runtime_registry_read_failed", requestId, "The D1 runtime registry could not be read."), 503);
  }
}

async function health(env, requestId) {
  if (!env.DB || !env.AGENT_API_AUTH_TOKEN) {
    return json({
      ...blocked("stateful_runtime_configuration_unavailable", requestId, "D1 or write authentication is unavailable."),
      service: "agent-api-stateful-runtime",
      d1_binding_configured: Boolean(env.DB),
      write_auth_configured: Boolean(env.AGENT_API_AUTH_TOKEN),
    }, 503);
  }
  try {
    const probe = await env.DB.prepare("SELECT 1 AS ok").first();
    const healthy = Number(probe?.ok) === 1;
    return json({
      contract_version: CONTRACT_VERSION,
      status: healthy ? "healthy" : "degraded",
      service: "agent-api-stateful-runtime",
      provider: "cloudflare-d1",
      mode: env.RUNTIME_MODE || "cloudflare_workers_d1_live",
      source_commit_sha: env.SOURCE_COMMIT_SHA || null,
      source_archive_sha256: env.SOURCE_ARCHIVE_SHA256 || null,
      d1_binding_configured: true,
      d1_read_verified: healthy,
      write_auth_configured: true,
      auth_required_for_writes: true,
      free_tier_policy: true,
      persisted: healthy,
      live_provider_calls: false,
      direct_provider_calls: false,
      live_mcp_writes: false,
      production_deploy: false,
      secret_output: false,
    }, healthy ? 200 : 503);
  } catch {
    return json(blocked("d1_health_probe_failed", requestId, "The D1 health query failed."), 503);
  }
}

async function proxyContractOrigin(request, env, requestId) {
  let origin;
  try {
    origin = new URL(env.CONTRACT_ORIGIN || "");
    if (origin.protocol !== "https:") throw new Error("invalid origin");
  } catch {
    return json(blocked("route_not_found", requestId, "The requested stateful route does not exist."), 404);
  }
  const incoming = new URL(request.url);
  if (origin.origin === incoming.origin) return json(blocked("proxy_loop_blocked", requestId, "Contract-origin loop blocked."), 508);
  const target = new URL(`${origin.origin}${incoming.pathname}${incoming.search}`);
  const headers = new Headers();
  for (const name of ["accept", "content-type", "authorization", "cookie", "x-csrf-token", "x-request-id", "traceparent"]) {
    const value = request.headers.get(name);
    if (value) headers.set(name, value);
  }
  const method = request.method.toUpperCase();
  const body = method === "GET" || method === "HEAD" ? undefined : await request.arrayBuffer();
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 8_000);
  try {
    const response = await fetch(target, { method, headers, body, redirect: "manual", signal: controller.signal });
    const responseHeaders = new Headers({
      "content-type": response.headers.get("content-type") || "application/json",
      "cache-control": "no-store",
      "x-superbrain-source": response.headers.get("x-superbrain-source") || "contract-origin-via-d1-edge",
      "x-superbrain-boundary": SOURCE,
    });
    return new Response(await response.arrayBuffer(), { status: response.status, headers: responseHeaders });
  } catch {
    return json(blocked("contract_origin_unavailable", requestId, "The upstream read-only contract origin is unavailable."), 503);
  } finally {
    clearTimeout(timer);
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const requestId = request.headers.get("x-request-id") || crypto.randomUUID();
    const buildMatch = url.pathname.match(/^\/api\/v1\/build\/([A-Za-z0-9_-]{1,64})$/);
    const runtimeRunMatch = url.pathname.match(/^\/api\/v1\/phase2\/runtime\/runs\/([A-Za-z0-9_-]{1,64})$/);

    if (request.method === "GET" && url.pathname === "/api/v1/health") return health(env, requestId);
    if (request.method === "GET" && url.pathname === "/api/v1/phase2/runtime/contract") return json(runtimeContract(env));
    if (request.method === "POST" && url.pathname === "/api/v1/phase2/runtime/start") return startRuntime(request, env, requestId);
    if (request.method === "GET" && url.pathname === "/api/v1/phase2/runtime/runs") return listRuntimeRuns(url, env, requestId);
    if (request.method === "GET" && runtimeRunMatch) return getRuntimeRun(runtimeRunMatch[1], env, requestId);
    if (request.method === "POST" && url.pathname === "/api/v1/builds") return createBuild(request, env, requestId);
    if (request.method === "GET" && url.pathname === "/api/v1/builds") return listBuilds(url, env, requestId);
    if (request.method === "GET" && buildMatch) return getBuild(buildMatch[1], env, requestId);
    if (request.method === "DELETE" && buildMatch) return deleteBuild(request, buildMatch[1], env, requestId);
    if (request.method === "POST" && url.pathname === "/api/v1/workspace/artifacts") return createArtifact(request, env, requestId);
    if (request.method === "GET" && url.pathname === "/api/v1/workspace/artifacts") return listArtifacts(url, env, requestId);

    return proxyContractOrigin(request, env, requestId);
  },
};

import { END, START, StateGraph, StateSchema } from "@langchain/langgraph";
import { z } from "zod";

const CONTRACT_VERSION = "cloudflare-d1-stateful-runtime-v1";
const RUNTIME_CONTRACT_VERSION = "cloudflare-d1-langgraph-runtime-v1";
const NATIVE_CONTRACT_VERSION = "cloudflare-native-runtime-candidate-v2";
const NATIVE_MESSAGE_VERSION = "cloudflare-native-probe-message-v2";
const NATIVE_ARTIFACT_CONTENT_TYPE = "text/plain; charset=utf-8";
const HOSTED_SESSION_CONTRACT_VERSION = "cloudflare-d1-hosted-session-v1";
const HOSTED_SESSION_TTL_SECONDS = 30 * 24 * 60 * 60;
const HOSTED_SESSION_TOKEN_BYTES = 32;
const SOURCE = "cloudflare-workers-d1-stateful-runtime";
const AUTH_HEADER = "x-superbrain-agent-token";
const MAX_BODY_BYTES = 192 * 1024;
const MAX_HTML_BYTES = 160 * 1024;
const MAX_METADATA_BYTES = 8 * 1024;
const MAX_NATIVE_CONTENT_BYTES = 32 * 1024;
const DEFAULT_LIMIT = 24;
const MAX_LIMIT = 100;
const AGENT_ROLES = ["planner", "coder", "tester", "devops"];
const REDACTED_PROMPT = "[REDACTED]";
const MASKED_SECRET = "***MASKED_SECRET***";
const SECRET_PATTERN_SOURCES = [
  [String.raw`\bsk-[A-Za-z0-9_-]{16,}\b`, ""],
  [String.raw`\bghp_[A-Za-z0-9_]{16,}\b`, ""],
  [String.raw`\bgithub_pat_[A-Za-z0-9_]{16,}\b`, ""],
  [String.raw`\b(?:E2B|cfat|vck|hf)_[A-Za-z0-9_-]{16,}\b`, ""],
  [String.raw`\bglpat-[A-Za-z0-9_.-]{20,}\b`, ""],
  [String.raw`\b(?:api[_-]?key|secret|token|password)\s*[:=]\s*(?:"[^"\r\n]{8,}"|'[^'\r\n]{8,}'|[A-Za-z0-9_+=/-]{24,})`, "i"],
];

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

function mutationOutcomeUnknown(error, requestId, note, details = {}) {
  return {
    contract_version: CONTRACT_VERSION,
    status: "blocked",
    error,
    request_id: requestId,
    ...details,
    accepted: null,
    persisted: null,
    mutation_outcome: "unknown",
    audit_persisted: null,
    audit_readback_verified: false,
    retry_safe: false,
    reconciliation_required: true,
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

function containsSecretMaterial(value) {
  if (typeof value === "string") {
    return SECRET_PATTERN_SOURCES.some(([source, flags]) => new RegExp(source, flags).test(value));
  }
  if (Array.isArray(value)) return value.some(containsSecretMaterial);
  if (value && typeof value === "object") {
    return Object.entries(value).some(([key, item]) => containsSecretMaterial(key) || containsSecretMaterial(item));
  }
  return false;
}

function containsKnownUnrunnableHtmlReference(html) {
  const executableMarkup = String(html).replace(/<!--[\s\S]*?-->/g, "");
  const scriptBlocks = [...executableMarkup.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)];
  const hasThreeImportMap = scriptBlocks
    .some(([, attributes, body]) => {
      const typeMatch = attributes.match(/\btype\s*=\s*(?:"([^"]+)"|'([^']+)'|([^\s"'=<>`]+))/i);
      const scriptType = String(typeMatch?.[1] ?? typeMatch?.[2] ?? typeMatch?.[3] ?? "").toLowerCase();
      if (scriptType !== "importmap") return false;
      try {
        const parsed = JSON.parse(body);
        return typeof parsed?.imports?.three === "string" && parsed.imports.three.trim().length > 0;
      } catch {
        return false;
      }
    });
  for (const match of executableMarkup.matchAll(/<script\b([^>]*)>/gi)) {
    const attributes = match[1];
    const typeMatch = attributes.match(/\btype\s*=\s*(?:"([^"]+)"|'([^']+)'|([^\s"'=<>`]+))/i);
    const scriptType = String(typeMatch?.[1] ?? typeMatch?.[2] ?? typeMatch?.[3] ?? "").toLowerCase();
    const srcMatch = attributes.match(/\bsrc\s*=\s*(?:"([^"]+)"|'([^']+)'|([^\s"'=<>`]+))/i);
    const src = srcMatch?.[1] ?? srcMatch?.[2] ?? srcMatch?.[3] ?? "";
    if (/\/three(?:@[^/]*)?\/examples\/js\//i.test(src)) return true;
    if (!(scriptType === "module" && hasThreeImportMap) && /\/three(?:@[^/]*)?\/examples\/jsm\//i.test(src)) return true;
  }
  let threeGlobalUsed = false;
  let threeDependencyReady = false;
  for (const [, attributes, body] of scriptBlocks) {
    const typeMatch = attributes.match(/\btype\s*=\s*(?:"([^"]+)"|'([^']+)'|([^\s"'=<>`]+))/i);
    const scriptType = String(typeMatch?.[1] ?? typeMatch?.[2] ?? typeMatch?.[3] ?? "").toLowerCase();
    const srcMatch = attributes.match(/\bsrc\s*=\s*(?:"([^"]+)"|'([^']+)'|([^\s"'=<>`]+))/i);
    const src = srcMatch?.[1] ?? srcMatch?.[2] ?? srcMatch?.[3] ?? "";
    if (
      src
      && scriptType !== "module"
      && /(?:\/three(?:@[^/]*)?\/build\/three(?:\.min)?\.js|\/three(?:\.min)?\.js)(?:[?#]|$)/i.test(src)
    ) {
      threeDependencyReady = true;
    }
    if (scriptType === "importmap" || !/\b(?:new\s+)?THREE\s*\./.test(body)) continue;
    threeGlobalUsed = true;
    if (/\b(?:const|let|var)\s+THREE\b|\b(?:window|globalThis)\.THREE\s*=/.test(body)) {
      threeDependencyReady = true;
    }
    if (scriptType === "module") {
      const namespaceImport = body.match(/\bimport\s+\*\s+as\s+THREE\s+from\s*(?:"([^"]+)"|'([^']+)')/);
      const specifier = namespaceImport?.[1] ?? namespaceImport?.[2] ?? "";
      if (specifier === "three" && hasThreeImportMap) threeDependencyReady = true;
      if (/(?:\/three(?:@[^/]*)?\/build\/three\.module(?:\.min)?\.js|\/three\.module(?:\.min)?\.js)(?:[?#]|$)/i.test(specifier)) {
        threeDependencyReady = true;
      }
    }
  }
  return threeGlobalUsed && !threeDependencyReady;
}

function redactText(value) {
  let redacted = String(value);
  for (const [source, flags] of SECRET_PATTERN_SOURCES) {
    redacted = redacted.replace(new RegExp(source, `${flags}g`), MASKED_SECRET);
  }
  return redacted;
}

function redactJson(value, depth = 0) {
  if (depth > 12) return "[REDACTED_DEPTH]";
  if (typeof value === "string") return redactText(value);
  if (Array.isArray(value)) return value.map((item) => redactJson(item, depth + 1));
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [redactText(key), redactJson(item, depth + 1)]));
  }
  return value;
}

function safeRequestId(value) {
  const candidate = typeof value === "string" ? value.trim() : "";
  return /^[A-Za-z0-9_.:-]{1,128}$/.test(candidate) ? candidate : crypto.randomUUID();
}

function validationCode(error, fallback = "invalid_request") {
  const code = error instanceof Error ? error.message : fallback;
  return /^(?:invalid_[a-z0-9_]+|request_too_large|secret_material_rejected)$/.test(code) ? code : fallback;
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

function randomHostedSessionToken() {
  const bytes = crypto.getRandomValues(new Uint8Array(HOSTED_SESSION_TOKEN_BYTES));
  const binary = String.fromCharCode(...bytes);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function hostedSessionToken(value) {
  const token = typeof value === "string" ? value : "";
  if (!/^[A-Za-z0-9_-]{43}$/.test(token)) throw new Error("invalid_session_token");
  return token;
}

function hostedIdentity(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("invalid_identity");
  const provider = String(value.provider ?? "guest");
  if (provider !== "guest" && provider !== "name") throw new Error("invalid_identity");
  const suppliedName = String(value.name ?? "").trim().replace(/\s+/g, " ").slice(0, 40);
  if (provider === "name" && !suppliedName) throw new Error("invalid_identity");
  const identity = { provider, name: provider === "guest" ? "Gast" : suppliedName };
  if (containsSecretMaterial(identity)) throw new Error("secret_material_rejected");
  return identity;
}

function hostedSessionClaimsFromRow(row, nowSeconds = Math.floor(Date.now() / 1000)) {
  if (!row || typeof row !== "object") return null;
  const id = String(row.session_id ?? "");
  const provider = String(row.provider ?? "");
  const name = String(row.display_name ?? "");
  const issuedMilliseconds = Date.parse(String(row.issued_at ?? ""));
  const expiresMilliseconds = Date.parse(String(row.expires_at ?? ""));
  const issuedAt = Math.floor(issuedMilliseconds / 1000);
  const expiresAt = Math.floor(expiresMilliseconds / 1000);
  const valid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id)
    && (provider === "guest" || provider === "name")
    && name.length > 0 && name.length <= 40
    && Number.isInteger(issuedAt) && Number.isInteger(expiresAt)
    && issuedAt <= nowSeconds + 60
    && expiresAt === issuedAt + HOSTED_SESSION_TTL_SECONDS
    && expiresAt > nowSeconds;
  if (!valid) return null;
  return { v: 1, id, provider, name, iat: issuedAt, exp: expiresAt };
}

function limitFrom(url) {
  const value = Number(url.searchParams.get("limit") || DEFAULT_LIMIT);
  return Math.max(1, Math.min(Number.isFinite(value) ? Math.floor(value) : DEFAULT_LIMIT, MAX_LIMIT));
}

function nativeArtifactRef(projectId, probeId, contentSha256) {
  return `cloud-native/${projectId}/${probeId}/${contentSha256}`;
}

function nativeMessage(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("invalid_native_message");
  const projectId = safeProjectId(value.project_id);
  const probeId = safeId(value.probe_id, "probe_id");
  const contentSha256 = textField(value.content_sha256, "content_sha256", 64, 64);
  if (!/^[a-f0-9]{64}$/.test(contentSha256)) throw new Error("invalid_content_sha256");
  if (value.contract_version !== NATIVE_MESSAGE_VERSION || Number(value.sequence) !== 1) {
    throw new Error("invalid_native_message");
  }
  const artifactRef = nativeArtifactRef(projectId, probeId, contentSha256);
  if (value.artifact_ref !== artifactRef) throw new Error("invalid_artifact_ref");
  const clean = {
    contract_version: NATIVE_MESSAGE_VERSION,
    project_id: projectId,
    probe_id: probeId,
    content_sha256: contentSha256,
    artifact_ref: artifactRef,
    sequence: 1,
  };
  if (new TextEncoder().encode(JSON.stringify(clean)).byteLength >= 64_000) {
    throw new Error("native_message_too_large");
  }
  return clean;
}

function nativeCoordinator(env, projectId, probeId) {
  if (!env.RUNTIME_COORDINATOR) throw new Error("native_coordinator_unavailable");
  const objectId = env.RUNTIME_COORDINATOR.idFromName(`${projectId}:${probeId}`);
  return env.RUNTIME_COORDINATOR.get(objectId);
}

async function nativeCoordinatorCall(env, projectId, probeId, method, payload) {
  const stub = nativeCoordinator(env, projectId, probeId);
  const response = await stub.fetch(new Request("https://runtime-coordinator/state", {
    method,
    headers: payload ? { "content-type": "application/json" } : undefined,
    body: payload ? JSON.stringify(payload) : undefined,
  }));
  const body = await response.json();
  if (!response.ok) {
    throw new Error(response.status === 409 ? "native_coordinator_conflict" : "native_coordinator_rejected");
  }
  return body;
}

async function nativeArtifactState(env, state) {
  const row = await env.DB.prepare(`
    SELECT artifact_ref, project_id, probe_id, content_sha256, content_text, content_type, content_bytes
    FROM native_artifacts
    WHERE artifact_ref = ?
  `).bind(state.artifact_ref).first();
  if (!row) return { present: false, verified: false };
  const content = String(row.content_text);
  const contentBytes = new TextEncoder().encode(content).byteLength;
  const verified = String(row.artifact_ref) === state.artifact_ref &&
    String(row.project_id) === state.project_id &&
    String(row.probe_id) === state.probe_id &&
    String(row.content_sha256) === state.content_sha256 &&
    String(row.content_type) === NATIVE_ARTIFACT_CONTENT_TYPE &&
    Number(row.content_bytes) === contentBytes &&
    contentBytes > 0 &&
    contentBytes <= MAX_NATIVE_CONTENT_BYTES &&
    !containsSecretMaterial(content) &&
    await sha256(content) === state.content_sha256;
  return { present: true, verified };
}

async function persistNativeArtifact(env, artifact, requestId) {
  await env.DB.batch([
    env.DB.prepare(`
      INSERT INTO native_artifacts (
        artifact_ref, project_id, probe_id, content_sha256, content_text,
        content_type, content_bytes, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).bind(
      artifact.artifactRef,
      artifact.projectId,
      artifact.probeId,
      artifact.contentSha256,
      artifact.content,
      NATIVE_ARTIFACT_CONTENT_TYPE,
      artifact.contentBytes,
      artifact.createdAt,
    ),
    env.DB.prepare(`
      INSERT INTO audit_events (id, event_type, trace_id, subject_id, details_json, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
    `).bind(
      crypto.randomUUID(),
      "cloudflare_d1_native_artifact_created",
      requestId,
      artifact.probeId,
      JSON.stringify({
        artifact_ref: artifact.artifactRef,
        content_sha256: artifact.contentSha256,
        content_bytes: artifact.contentBytes,
      }),
      artifact.createdAt,
    ),
  ]);
}

async function deleteNativeArtifact(env, state, requestId, eventType = "cloudflare_d1_native_artifact_deleted") {
  const now = new Date().toISOString();
  await env.DB.batch([
    env.DB.prepare("DELETE FROM native_artifacts WHERE artifact_ref = ?").bind(state.artifact_ref),
    env.DB.prepare(`
      INSERT INTO audit_events (id, event_type, trace_id, subject_id, details_json, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
    `).bind(
      crypto.randomUUID(),
      eventType,
      requestId,
      state.probe_id,
      JSON.stringify({ artifact_ref: state.artifact_ref, content_sha256: state.content_sha256 }),
      now,
    ),
  ]);
  return !(await nativeArtifactState(env, state)).present;
}

function nativeRuntimeTruth(env) {
  const hostedCandidate = env.RUNTIME_MODE === "cloudflare_native_hosted_candidate";
  return {
    dev_only: !hostedCandidate,
    hosted_proof: hostedCandidate,
    evidence_ref: hostedCandidate
      ? "cloudflare_native_do_queue_d1_artifact_hosted_candidate"
      : "cloudflare_native_do_queue_d1_artifact_local_candidate",
    live_provider_calls: false,
    direct_provider_calls: false,
    live_mcp_writes: false,
    production_deploy: false,
    secret_output: false,
  };
}

function nativeContract(env) {
  const bindings = {
    d1: Boolean(env.DB),
    durable_object_sqlite: Boolean(env.RUNTIME_COORDINATOR),
    queue: Boolean(env.RUNTIME_QUEUE),
  };
  const runtimeTruth = nativeRuntimeTruth(env);
  return {
    contract_version: NATIVE_CONTRACT_VERSION,
    status: Object.values(bindings).every(Boolean) ? "configured" : "blocked",
    engine: "langgraph-js",
    coordination: "durable-object-sqlite",
    dispatch: "cloudflare-queues",
    checkpointing: "cloudflare-d1-custom",
    official_langgraph_checkpointer: false,
    artifact_store: "cloudflare-d1-bounded-text",
    artifact_content_max_bytes: MAX_NATIVE_CONTENT_BYTES,
    artifact_content_publicly_readable: false,
    bindings,
    create_endpoint: "POST /api/v1/cloud-native/probes",
    state_endpoint: "GET /api/v1/cloud-native/probes/{probe_id}?project_id={project_id}",
    cleanup_endpoint: "DELETE /api/v1/cloud-native/probes/{probe_id}?project_id={project_id}",
    write_auth_required: true,
    queue_envelope_contains_raw_prompt: false,
    historical_adapters: [
      {
        id: "cloudflare-r2",
        status: "historical_only",
        active: false,
        binding_configured: false,
        zero_card_verified: false,
      },
    ],
    vectorize: "owner_gate_required",
    workers_ai: "owner_gate_required",
    ...runtimeTruth,
    non_claims: [
      runtimeTruth.hosted_proof
        ? "Hosted candidate mode does not claim production deployment or release readiness."
        : "Local bindings do not prove hosted Cloudflare resource activation.",
      "R2 remains disabled and historical-only because zero-card activation is unavailable.",
      "D1 stores bounded text artifacts only; binary and large-object parity is not claimed.",
      "D1 custom persistence is not an official LangGraph checkpointer.",
    ],
  };
}

export class RuntimeCoordinator {
  constructor(state, env) {
    this.state = state;
    this.env = env;
  }

  async fetch(request) {
    try {
      if (request.method === "GET") {
        const current = await this.state.storage.get("probe");
        return current ? json(current) : json({ status: "not_found", secret_output: false }, 404);
      }
      if (request.method === "DELETE") {
        await this.state.storage.delete("probe");
        return json({ status: "deleted", persisted: false, secret_output: false });
      }
      if (request.method !== "POST") return json({ status: "method_not_allowed", secret_output: false }, 405);

      const body = await request.json();
      const message = nativeMessage(body.message);
      const action = body.action;
      const current = await this.state.storage.get("probe");
      const now = new Date().toISOString();

      if (action === "initialize") {
        if (current) {
          const same = current.project_id === message.project_id &&
            current.probe_id === message.probe_id &&
            current.content_sha256 === message.content_sha256 &&
            current.artifact_ref === message.artifact_ref;
          return same
            ? json({ ...current, replayed: true })
            : json({ status: "conflict", secret_output: false }, 409);
        }
        const created = {
          contract_version: NATIVE_CONTRACT_VERSION,
          project_id: message.project_id,
          probe_id: message.probe_id,
          content_sha256: message.content_sha256,
          artifact_ref: message.artifact_ref,
          sequence: 1,
          status: "queued",
          queue_delivery_count: 0,
          created_at: now,
          updated_at: now,
          persisted: true,
          replayed: false,
          live_provider_calls: false,
          live_mcp_writes: false,
          production_deploy: false,
          secret_output: false,
        };
        await this.state.storage.put("probe", created);
        return json(created, 201);
      }

      if (!current) return json({ status: "not_found", secret_output: false }, 404);
      const same = current.project_id === message.project_id &&
        current.probe_id === message.probe_id &&
        current.content_sha256 === message.content_sha256 &&
        current.artifact_ref === message.artifact_ref;
      if (!same) return json({ status: "conflict", secret_output: false }, 409);

      if (action === "complete") {
        if (current.status === "completed") return json({ ...current, replayed: true });
        if (current.status === "failed") return json({ status: "terminal_state_conflict", secret_output: false }, 409);
        const completed = {
          ...current,
          status: "completed",
          queue_delivery_count: Number(current.queue_delivery_count || 0) + 1,
          updated_at: now,
          replayed: false,
        };
        await this.state.storage.put("probe", completed);
        return json(completed);
      }

      if (action === "fail") {
        if (current.status === "completed" || current.status === "failed") {
          return json({ ...current, replayed: true });
        }
        const failed = {
          ...current,
          status: "failed",
          queue_delivery_count: Number(current.queue_delivery_count || 0) + 1,
          updated_at: now,
          replayed: false,
        };
        await this.state.storage.put("probe", failed);
        return json(failed);
      }
      return json({ status: "invalid_action", secret_output: false }, 400);
    } catch {
      return json({ status: "blocked", error: "coordinator_request_failed", secret_output: false }, 400);
    }
  }
}

function buildFromRow(row, includeHtml = true) {
  const build = {
    id: String(row.id),
    project_id: String(row.project_id),
    title: redactText(row.title),
    prompt_sha256: row.prompt_sha256 ? String(row.prompt_sha256) : null,
    model: redactText(row.model),
    gateway_mode: redactText(row.gateway_mode),
    gateway_provider: redactText(row.gateway_provider),
    live_provider_calls: Number(row.live_provider_calls) === 1,
    persisted: true,
    share_path: `/run/${row.id}`,
    created_at: String(row.created_at),
    updated_at: String(row.updated_at),
    direct_provider_calls: false,
    live_mcp_writes: false,
    production_deploy: false,
    secret_output: false,
  };
  if (includeHtml) build.html = String(row.html);
  return build;
}

function auditReadbackMatches(row, expected) {
  return Boolean(row) &&
    String(row.id) === expected.id &&
    String(row.event_type) === expected.eventType &&
    String(row.trace_id) === expected.requestId &&
    String(row.subject_id) === expected.subjectId &&
    String(row.details_json) === expected.detailsJson &&
    String(row.created_at) === expected.createdAt;
}

function buildCreateReadbackMatches(row, build, createdAt) {
  return Boolean(row) &&
    String(row.id) === build.id &&
    String(row.project_id) === build.projectId &&
    String(row.title) === build.title &&
    String(row.prompt) === REDACTED_PROMPT &&
    String(row.prompt_sha256) === build.promptSha256 &&
    String(row.model) === build.model &&
    String(row.html) === build.html &&
    String(row.gateway_mode) === build.gatewayMode &&
    String(row.gateway_provider) === build.gatewayProvider &&
    Number(row.live_provider_calls) === build.liveProviderCalls &&
    String(row.created_at) === createdAt &&
    String(row.updated_at) === createdAt &&
    (row.deleted_at === null || row.deleted_at === undefined);
}

function artifactFromRow(row) {
  let metadata = {};
  try { metadata = JSON.parse(String(row.metadata_json || "{}")); } catch { /* keep redacted empty metadata */ }
  return {
    id: String(row.id),
    project_id: String(row.project_id),
    source_page: redactText(row.source_page),
    artifact_type: redactText(row.artifact_type),
    title: redactText(row.title),
    summary: redactText(row.summary),
    status: redactText(row.status),
    run_id: row.run_id ? String(row.run_id) : null,
    metadata: redactJson(metadata),
    created_at: String(row.created_at),
    persisted: true,
    evidence_ref: "cloudflare_d1_workspace_artifact_roundtrip",
  };
}

function hostedSessionBlocked(error, requestId, note) {
  return {
    ...blocked(error, requestId, note),
    contract_version: HOSTED_SESSION_CONTRACT_VERSION,
    session_backend: "cloudflare-d1",
    external_provider_write: false,
  };
}

async function createHostedSession(request, env, requestId) {
  if (!env.DB || !env.AGENT_API_AUTH_TOKEN) {
    return json(hostedSessionBlocked(
      "hosted_session_configuration_unavailable",
      requestId,
      "D1 or trusted frontend authentication is unavailable.",
    ), 503);
  }
  if (!(await authenticated(request, env))) {
    return json(hostedSessionBlocked(
      "hosted_session_authentication_required",
      requestId,
      "Trusted frontend authentication failed.",
    ), 401);
  }

  let body;
  try {
    body = await readJson(request);
  } catch (error) {
    const code = validationCode(error);
    return json(hostedSessionBlocked(code, requestId, "The session request is invalid."), code === "request_too_large" ? 413 : 400);
  }

  let identity;
  try {
    identity = hostedIdentity(body);
  } catch (error) {
    return json(hostedSessionBlocked(validationCode(error, "invalid_identity"), requestId, "The session identity is invalid."), 400);
  }

  const nowSeconds = Math.floor(Date.now() / 1000);
  const issuedAt = new Date(nowSeconds * 1000).toISOString();
  const expiresAt = new Date((nowSeconds + HOSTED_SESSION_TTL_SECONDS) * 1000).toISOString();
  const sessionId = crypto.randomUUID();
  const sessionToken = randomHostedSessionToken();
  const tokenSha256 = await sha256(sessionToken);

  try {
    await env.DB.batch([
      env.DB.prepare(`
        INSERT INTO hosted_sessions (
          token_sha256, session_id, provider, display_name, issued_at, expires_at, revoked_at
        ) VALUES (?, ?, ?, ?, ?, ?, NULL)
      `).bind(tokenSha256, sessionId, identity.provider, identity.name, issuedAt, expiresAt),
      env.DB.prepare(`
        INSERT INTO audit_events (id, event_type, trace_id, subject_id, details_json, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
      `).bind(
        crypto.randomUUID(),
        "cloudflare_d1_hosted_session_created",
        requestId,
        sessionId,
        JSON.stringify({
          provider: identity.provider,
          session_backend: "cloudflare-d1",
          token_storage: "sha256_only",
          expires_at: expiresAt,
          external_provider_write: false,
          secret_output: false,
        }),
        issuedAt,
      ),
    ]);
    const row = await env.DB.prepare(`
      SELECT session_id, provider, display_name, issued_at, expires_at
      FROM hosted_sessions
      WHERE token_sha256 = ? AND revoked_at IS NULL AND expires_at > ?
      LIMIT 1
    `).bind(tokenSha256, issuedAt).first();
    const session = hostedSessionClaimsFromRow(row, nowSeconds);
    if (!session) throw new Error("hosted_session_readback_failed");
    return json({
      contract_version: HOSTED_SESSION_CONTRACT_VERSION,
      status: "created",
      session_token: sessionToken,
      session,
      persisted: true,
      session_backend: "cloudflare-d1",
      token_storage: "sha256_only",
      credential_delivery: "authenticated_frontend_service",
      audit_persisted: true,
      external_provider_write: false,
      direct_provider_calls: false,
      live_provider_calls: false,
      live_mcp_writes: false,
      production_deploy: false,
    }, 201);
  } catch {
    return json(hostedSessionBlocked(
      "hosted_session_persistence_failed",
      requestId,
      "The session and its audit event were not persisted.",
    ), 503);
  }
}

async function verifyHostedSession(request, env, requestId) {
  if (!env.DB || !env.AGENT_API_AUTH_TOKEN) {
    return json(hostedSessionBlocked(
      "hosted_session_configuration_unavailable",
      requestId,
      "D1 or trusted frontend authentication is unavailable.",
    ), 503);
  }
  if (!(await authenticated(request, env))) {
    return json(hostedSessionBlocked(
      "hosted_session_authentication_required",
      requestId,
      "Trusted frontend authentication failed.",
    ), 401);
  }

  let sessionToken;
  try {
    const body = await readJson(request);
    if (!body || typeof body !== "object" || Array.isArray(body)) throw new Error("invalid_request");
    sessionToken = hostedSessionToken(body.session_token);
  } catch (error) {
    const code = validationCode(error);
    return json(hostedSessionBlocked(code, requestId, "The session credential is invalid."), code === "request_too_large" ? 413 : 400);
  }

  const nowSeconds = Math.floor(Date.now() / 1000);
  const now = new Date(nowSeconds * 1000).toISOString();
  try {
    const tokenSha256 = await sha256(sessionToken);
    const row = await env.DB.prepare(`
      SELECT session_id, provider, display_name, issued_at, expires_at
      FROM hosted_sessions
      WHERE token_sha256 = ? AND revoked_at IS NULL AND expires_at > ?
      LIMIT 1
    `).bind(tokenSha256, now).first();
    const session = hostedSessionClaimsFromRow(row, nowSeconds);
    if (!session) {
      return json({
        contract_version: HOSTED_SESSION_CONTRACT_VERSION,
        status: "invalid",
        valid: false,
        reason: "missing_expired_or_revoked",
        session_backend: "cloudflare-d1",
        session_token_returned: false,
        external_provider_write: false,
        secret_output: false,
      });
    }
    return json({
      contract_version: HOSTED_SESSION_CONTRACT_VERSION,
      status: "verified",
      valid: true,
      session,
      session_backend: "cloudflare-d1",
      token_storage: "sha256_only",
      session_token_returned: false,
      external_provider_write: false,
      secret_output: false,
    });
  } catch {
    return json(hostedSessionBlocked(
      "hosted_session_verification_failed",
      requestId,
      "The session registry could not be read.",
    ), 503);
  }
}

async function revokeHostedSession(request, env, requestId) {
  if (!env.DB || !env.AGENT_API_AUTH_TOKEN) {
    return json(hostedSessionBlocked(
      "hosted_session_configuration_unavailable",
      requestId,
      "D1 or trusted frontend authentication is unavailable.",
    ), 503);
  }
  if (!(await authenticated(request, env))) {
    return json(hostedSessionBlocked(
      "hosted_session_authentication_required",
      requestId,
      "Trusted frontend authentication failed.",
    ), 401);
  }

  let sessionToken;
  try {
    const body = await readJson(request);
    if (!body || typeof body !== "object" || Array.isArray(body)) throw new Error("invalid_request");
    sessionToken = hostedSessionToken(body.session_token);
  } catch (error) {
    const code = validationCode(error);
    return json(hostedSessionBlocked(code, requestId, "The session credential is invalid."), code === "request_too_large" ? 413 : 400);
  }

  const now = new Date().toISOString();
  try {
    const tokenSha256 = await sha256(sessionToken);
    const existing = await env.DB.prepare(`
      SELECT session_id, revoked_at
      FROM hosted_sessions
      WHERE token_sha256 = ?
      LIMIT 1
    `).bind(tokenSha256).first();
    if (!existing || existing.revoked_at) {
      return json({
        contract_version: HOSTED_SESSION_CONTRACT_VERSION,
        status: "signed_out",
        revoked: false,
        session_backend: "cloudflare-d1",
        session_token_returned: false,
        audit_persisted: false,
        external_provider_write: false,
        secret_output: false,
      });
    }
    const results = await env.DB.batch([
      env.DB.prepare(`
        UPDATE hosted_sessions
        SET revoked_at = ?
        WHERE token_sha256 = ? AND revoked_at IS NULL
      `).bind(now, tokenSha256),
      env.DB.prepare(`
        INSERT INTO audit_events (id, event_type, trace_id, subject_id, details_json, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
      `).bind(
        crypto.randomUUID(),
        "cloudflare_d1_hosted_session_revoked",
        requestId,
        String(existing.session_id),
        JSON.stringify({
          session_backend: "cloudflare-d1",
          token_storage: "sha256_only",
          external_provider_write: false,
          secret_output: false,
        }),
        now,
      ),
    ]);
    if (Number(results[0]?.meta?.changes || 0) !== 1) throw new Error("hosted_session_revoke_race");
    return json({
      contract_version: HOSTED_SESSION_CONTRACT_VERSION,
      status: "signed_out",
      revoked: true,
      session_backend: "cloudflare-d1",
      session_token_returned: false,
      audit_persisted: true,
      external_provider_write: false,
      secret_output: false,
    });
  } catch {
    return json(hostedSessionBlocked(
      "hosted_session_revoke_failed",
      requestId,
      "The session revocation and its audit event were not persisted.",
    ), 503);
  }
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

  let build;
  try {
    if (!body || typeof body !== "object" || Array.isArray(body)) throw new Error("invalid_request");
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
    if (containsKnownUnrunnableHtmlReference(html)) throw new Error("invalid_html_runnability");
    const gatewayMode = textField(body.gateway_mode ?? "unknown", "gateway_mode", 1, 80);
    const gatewayProvider = textField(body.gateway_provider ?? "unknown", "gateway_provider", 1, 80);
    const liveProviderCalls = body.live_provider_calls === true ? 1 : 0;
    if (containsSecretMaterial({ title, prompt, model, html, gatewayMode, gatewayProvider })) {
      throw new Error("secret_material_rejected");
    }
    build = {
      id,
      projectId,
      title,
      promptSha256: await sha256(prompt),
      model,
      html,
      gatewayMode,
      gatewayProvider,
      liveProviderCalls,
    };
  } catch (error) {
    return json(blocked(validationCode(error), requestId, "The build request does not satisfy the stateful contract."), 400);
  }

  const now = new Date().toISOString();
  const auditEventId = crypto.randomUUID();
  const auditDetailsJson = JSON.stringify({
    project_id: build.projectId,
    prompt_sha256: build.promptSha256,
    model: build.model,
    gateway_mode: build.gatewayMode,
    gateway_provider: build.gatewayProvider,
    live_provider_calls: build.liveProviderCalls === 1,
    secret_output: false,
  });
  try {
    await env.DB.batch([
      env.DB.prepare(`
        INSERT INTO builds (
          id, project_id, title, prompt, prompt_sha256, model, html, gateway_mode, gateway_provider,
          live_provider_calls, created_at, updated_at, deleted_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
      `).bind(
        build.id,
        build.projectId,
        build.title,
        REDACTED_PROMPT,
        build.promptSha256,
        build.model,
        build.html,
        build.gatewayMode,
        build.gatewayProvider,
        build.liveProviderCalls,
        now,
        now,
      ),
      env.DB.prepare(`
        INSERT INTO audit_events (id, event_type, trace_id, subject_id, details_json, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
      `).bind(
        auditEventId,
        "cloudflare_d1_build_created",
        requestId,
        build.id,
        auditDetailsJson,
        now,
      ),
    ]);
  } catch (error) {
    const code = error instanceof Error ? error.message : "build_insert_failed";
    const conflict = /UNIQUE|constraint/i.test(code);
    if (conflict) {
      return json(blocked("build_id_conflict", requestId, "The conflicting build and audit event were not persisted."), 409);
    }
    return json(mutationOutcomeUnknown(
      "build_persistence_outcome_unknown",
      requestId,
      "The D1 batch outcome could not be confirmed. Reconcile the returned build and audit correlation identifiers before retrying.",
      { id: build.id, audit_event_id: auditEventId, operation: "create" },
    ), 503);
  }

  try {
    const row = await env.DB.prepare("SELECT * FROM builds WHERE id = ? AND deleted_at IS NULL").bind(build.id).first();
    const auditRow = await env.DB.prepare(`
      SELECT id, event_type, trace_id, subject_id, details_json, created_at
      FROM audit_events
      WHERE id = ? AND event_type = ? AND trace_id = ? AND subject_id = ?
      LIMIT 1
    `).bind(auditEventId, "cloudflare_d1_build_created", requestId, build.id).first();
    if (!buildCreateReadbackMatches(row, build, now)) throw new Error("build_readback_failed");
    if (!auditReadbackMatches(auditRow, {
      id: auditEventId,
      eventType: "cloudflare_d1_build_created",
      requestId,
      subjectId: build.id,
      detailsJson: auditDetailsJson,
      createdAt: now,
    })) throw new Error("build_audit_readback_failed");
    return json({
      ...buildFromRow(row),
      contract_version: CONTRACT_VERSION,
      status: "created",
      source: "cloudflare-d1",
      request_id: requestId,
      audit_event_id: auditEventId,
      audit_persisted: true,
      audit_readback_verified: true,
      live_mcp_writes: false,
      production_deploy: false,
    }, 201);
  } catch {
    return json(mutationOutcomeUnknown(
      "build_persistence_outcome_unknown",
      requestId,
      "The D1 batch completed but exact build and audit readback could not be verified. Reconcile the returned build and audit correlation identifiers before retrying.",
      { id: build.id, audit_event_id: auditEventId, operation: "create" },
    ), 503);
  }
}

async function listBuilds(url, env, requestId) {
  if (!env.DB) return json(blocked("d1_binding_unavailable", requestId, "The D1 build registry is unavailable."), 503);
  try {
    const projectId = safeProjectId(url.searchParams.get("project_id") || "default");
    const limit = limitFrom(url);
    const result = await env.DB.prepare(`
      SELECT id, project_id, title, prompt_sha256, model, gateway_mode, gateway_provider,
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
    if (!row) return json({ status: "not_found", persisted: false, secret_output: false }, 404);
    if (containsSecretMaterial(row.html)) {
      return json(blocked("build_secret_material_quarantined", requestId, "The persisted build is unavailable."), 410);
    }
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
  const clean = safeId(id);
  const now = new Date().toISOString();
  const auditEventId = crypto.randomUUID();
  const auditDetailsJson = JSON.stringify({ build_id: clean, secret_output: false });
  let results;
  try {
    results = await env.DB.batch([
      env.DB.prepare("UPDATE builds SET deleted_at = ?, updated_at = ? WHERE id = ? AND deleted_at IS NULL")
        .bind(now, now, clean),
      env.DB.prepare(`
        INSERT INTO audit_events (id, event_type, trace_id, subject_id, details_json, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
      `).bind(
        auditEventId,
        "cloudflare_d1_build_delete_requested",
        requestId,
        clean,
        auditDetailsJson,
        now,
      ),
    ]);
  } catch {
    return json(mutationOutcomeUnknown(
      "build_delete_outcome_unknown",
      requestId,
      "The D1 delete batch outcome could not be confirmed. Reconcile the returned build and audit correlation identifiers before retrying.",
      { id: clean, audit_event_id: auditEventId, operation: "delete", deleted: null, delete_readback_verified: false },
    ), 503);
  }

  try {
    const changes = Number(results[0]?.meta?.changes || 0);
    if (changes !== 0 && changes !== 1) throw new Error("build_delete_change_count_invalid");
    const auditRow = await env.DB.prepare(`
      SELECT id, event_type, trace_id, subject_id, details_json, created_at
      FROM audit_events
      WHERE id = ? AND event_type = ? AND trace_id = ? AND subject_id = ?
      LIMIT 1
    `).bind(auditEventId, "cloudflare_d1_build_delete_requested", requestId, clean).first();
    const activeRow = await env.DB.prepare(`
      SELECT id, deleted_at
      FROM builds
      WHERE id = ? AND deleted_at IS NULL
      LIMIT 1
    `).bind(clean).first();
    if (!auditReadbackMatches(auditRow, {
      id: auditEventId,
      eventType: "cloudflare_d1_build_delete_requested",
      requestId,
      subjectId: clean,
      detailsJson: auditDetailsJson,
      createdAt: now,
    })) throw new Error("build_delete_audit_readback_failed");
    if (activeRow) throw new Error("build_delete_readback_failed");
    if (changes === 0) {
      return json({
        contract_version: CONTRACT_VERSION,
        status: "not_found",
        id: clean,
        request_id: requestId,
        audit_event_id: auditEventId,
        persisted: false,
        deleted: false,
        audit_persisted: true,
        audit_readback_verified: true,
        delete_readback_verified: true,
        secret_output: false,
      }, 404);
    }
    return json({
      contract_version: CONTRACT_VERSION,
      status: "deleted",
      id: clean,
      request_id: requestId,
      audit_event_id: auditEventId,
      persisted: true,
      deleted: true,
      audit_persisted: true,
      audit_readback_verified: true,
      delete_readback_verified: true,
      secret_output: false,
    });
  } catch {
    return json(mutationOutcomeUnknown(
      "build_delete_outcome_unknown",
      requestId,
      "The D1 delete batch completed but exact build and audit readback could not be verified. Reconcile the returned build and audit correlation identifiers before retrying.",
      { id: clean, audit_event_id: auditEventId, operation: "delete", deleted: null, delete_readback_verified: false },
    ), 503);
  }
}

// --- O5 semantic memory -------------------------------------------------------------------------
// This is the first path in this Worker that performs real semantic retrieval. It is deliberately
// separate from the D1 lexical memory: D1 answers "does this string occur", Vectorize answers "what
// is close in meaning". The two must never be conflated as evidence for one another.
const SEMANTIC_MAX_TEXT_BYTES = 8_000;
const SEMANTIC_DEFAULT_TOP_K = 5;

function embeddingModel(env) {
  return env.MEMORY_EMBEDDING_MODEL || "@cf/baai/bge-base-en-v1.5";
}

async function embedText(env, text) {
  const result = await env.AI.run(embeddingModel(env), { text: [text] });
  const vector = result && Array.isArray(result.data) ? result.data[0] : null;
  if (!Array.isArray(vector) || vector.length === 0) throw new Error("embedding_failed");
  return vector;
}

async function upsertSemanticMemory(request, env, requestId) {
  if (!env.VECTORIZE || !env.AI || !env.AGENT_API_AUTH_TOKEN) {
    return json(blocked("semantic_memory_configuration_unavailable", requestId, "Vectorize, Workers AI, or write authentication is unavailable."), 503);
  }
  if (!(await authenticated(request, env))) {
    return json(blocked("stateful_runtime_authentication_required", requestId, "Agent API write authentication failed."), 401);
  }
  let body;
  try { body = await readJson(request); } catch (error) {
    return json(blocked(error instanceof Error ? error.message : "invalid_request", requestId, "The semantic memory request is invalid."), 400);
  }
  try {
    if (!body || typeof body !== "object" || Array.isArray(body)) throw new Error("invalid_request");
    const projectId = safeProjectId(body.project_id);
    const text = textField(body.text, "text", 1, SEMANTIC_MAX_TEXT_BYTES);
    if (containsSecretMaterial({ text, projectId })) throw new Error("secret_material_rejected");

    const id = crypto.randomUUID();
    const values = await embedText(env, text);
    await env.VECTORIZE.upsert([{ id, values, metadata: { project_id: projectId, text } }]);

    return json({
      contract_version: "cloudflare-semantic-memory-v1",
      request_id: requestId,
      status: "stored",
      id,
      project_id: projectId,
      dimensions: values.length,
      model: embeddingModel(env),
      lexical_evidence_reused: false,
      secret_output: false,
    }, 201);
  } catch (error) {
    const reason = error instanceof Error ? error.message : "invalid_request";
    const status = reason === "embedding_failed" ? 502 : 400;
    return json(blocked(reason, requestId, "The semantic memory write was rejected."), status);
  }
}

async function searchSemanticMemory(request, url, env, requestId) {
  if (!env.VECTORIZE || !env.AI) {
    return json(blocked("semantic_memory_configuration_unavailable", requestId, "Vectorize or Workers AI is unavailable."), 503);
  }
  if (!(await authenticated(request, env))) {
    return json(blocked("stateful_runtime_authentication_required", requestId, "Agent API read authentication failed."), 401);
  }
  try {
    const query = textField(url.searchParams.get("q"), "q", 1, SEMANTIC_MAX_TEXT_BYTES);
    const requestedTopK = Number(url.searchParams.get("top_k") ?? SEMANTIC_DEFAULT_TOP_K);
    const topK = Number.isFinite(requestedTopK) ? Math.min(Math.max(Math.trunc(requestedTopK), 1), 20) : SEMANTIC_DEFAULT_TOP_K;
    if (containsSecretMaterial({ query })) throw new Error("secret_material_rejected");

    const values = await embedText(env, query);
    const result = await env.VECTORIZE.query(values, { topK, returnMetadata: "all" });
    const matches = Array.isArray(result && result.matches) ? result.matches : [];

    return json({
      contract_version: "cloudflare-semantic-memory-v1",
      request_id: requestId,
      status: "verified",
      // `semantic_retrieval` is the whole point of this route: the score comes from cosine distance
      // over embeddings, not from substring matching. This is what the lexical D1 path cannot do.
      retrieval_mode: "semantic_vector_cosine",
      lexical_fallback_used: false,
      model: embeddingModel(env),
      dimensions: values.length,
      match_count: matches.length,
      matches: matches.map((match) => ({
        id: match.id,
        score: match.score,
        project_id: match.metadata ? match.metadata.project_id : null,
        text: match.metadata ? match.metadata.text : null,
      })),
      secret_output: false,
    });
  } catch (error) {
    const reason = error instanceof Error ? error.message : "invalid_request";
    const status = reason === "embedding_failed" ? 502 : 400;
    return json(blocked(reason, requestId, "The semantic memory search was rejected."), status);
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
  let artifact;
  try {
    if (!body || typeof body !== "object" || Array.isArray(body)) throw new Error("invalid_request");
    const id = crypto.randomUUID();
    const projectId = safeProjectId(body.project_id);
    const sourcePage = textField(body.source_page, "source_page", 1, 80);
    const artifactType = textField(body.artifact_type, "artifact_type", 1, 80);
    if (!/^[a-z0-9_-]+$/.test(artifactType)) throw new Error("invalid_artifact_type");
    const title = textField(body.title, "title", 1, 160);
    const summary = textField(body.summary, "summary", 1, 2_000);
    const status = textField(body.status ?? "created", "status", 1, 40);
    const runId = body.run_id ? safeId(body.run_id, "run_id") : null;
    const metadata = body.metadata === undefined ? {} : body.metadata;
    if (!metadata || typeof metadata !== "object" || Array.isArray(metadata)) throw new Error("invalid_metadata");
    const metadataJson = JSON.stringify(metadata);
    if (new TextEncoder().encode(metadataJson).byteLength > MAX_METADATA_BYTES) throw new Error("invalid_metadata");
    if (containsSecretMaterial({ sourcePage, artifactType, title, summary, status, metadata })) {
      throw new Error("secret_material_rejected");
    }
    artifact = { id, projectId, sourcePage, artifactType, title, summary, status, runId, metadataJson };
  } catch (error) {
    return json(blocked(validationCode(error), requestId, "The artifact request is invalid."), 400);
  }

  const now = new Date().toISOString();
  try {
    await env.DB.batch([
      env.DB.prepare(`
        INSERT INTO workspace_artifacts (
          id, project_id, source_page, artifact_type, title, summary, status,
          run_id, metadata_json, created_at, deleted_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
      `).bind(
        artifact.id,
        artifact.projectId,
        artifact.sourcePage,
        artifact.artifactType,
        artifact.title,
        artifact.summary,
        artifact.status,
        artifact.runId,
        artifact.metadataJson,
        now,
      ),
      env.DB.prepare(`
        INSERT INTO audit_events (id, event_type, trace_id, subject_id, details_json, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
      `).bind(
        crypto.randomUUID(),
        "cloudflare_d1_workspace_artifact_created",
        requestId,
        artifact.id,
        JSON.stringify({
          project_id: artifact.projectId,
          source_page: artifact.sourcePage,
          artifact_type: artifact.artifactType,
          run_id: artifact.runId,
          secret_output: false,
        }),
        now,
      ),
    ]);
    const row = await env.DB.prepare("SELECT * FROM workspace_artifacts WHERE id = ?").bind(artifact.id).first();
    if (!row) throw new Error("artifact_readback_failed");
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
  } catch {
    return json(blocked("artifact_persistence_failed", requestId, "The artifact and its audit event were not persisted."), 503);
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

async function createNativeProbe(request, env, requestId) {
  const contract = nativeContract(env);
  if (contract.status !== "configured" || !env.AGENT_API_AUTH_TOKEN) {
    return json(blocked("cloudflare_native_configuration_unavailable", requestId, "The Cloudflare-native bindings are unavailable."), 503);
  }
  if (!(await authenticated(request, env))) {
    return json(blocked("stateful_runtime_authentication_required", requestId, "Agent API write authentication failed."), 401);
  }

  let body;
  try { body = await readJson(request); } catch (error) {
    return json(blocked(validationCode(error), requestId, "The Cloudflare-native probe request is invalid."), 400);
  }

  let projectId;
  let idempotencyKey;
  let content;
  try {
    projectId = safeProjectId(body.project_id);
    idempotencyKey = body.idempotency_key
      ? safeId(body.idempotency_key, "idempotency_key")
      : crypto.randomUUID();
    content = textField(body.content, "content", 1, 16_000);
    if (new TextEncoder().encode(content).byteLength > MAX_NATIVE_CONTENT_BYTES) throw new Error("request_too_large");
    if (containsSecretMaterial(content) || containsSecretMaterial(idempotencyKey)) {
      throw new Error("secret_material_rejected");
    }
  } catch (error) {
    return json(blocked(validationCode(error), requestId, "The Cloudflare-native probe request was rejected before persistence."), 400);
  }

  const contentSha256 = await sha256(content);
  const idempotencySha256 = await sha256(`${projectId}:${idempotencyKey}`);
  const probeId = `probe-${idempotencySha256.slice(0, 40)}`;
  const artifactRef = nativeArtifactRef(projectId, probeId, contentSha256);
  const message = nativeMessage({
    contract_version: NATIVE_MESSAGE_VERSION,
    project_id: projectId,
    probe_id: probeId,
    content_sha256: contentSha256,
    artifact_ref: artifactRef,
    sequence: 1,
  });
  const artifact = {
    artifactRef,
    projectId,
    probeId,
    contentSha256,
    content,
    contentBytes: new TextEncoder().encode(content).byteLength,
    createdAt: new Date().toISOString(),
  };

  let coordinatorCreated = false;
  let artifactPersisted = false;
  try {
    const d1Probe = await env.DB.prepare("SELECT 1 AS ok").first();
    if (Number(d1Probe?.ok) !== 1) throw new Error("d1_probe_failed");
    const coordinator = await nativeCoordinatorCall(env, projectId, probeId, "POST", {
      action: "initialize",
      message,
    });
    coordinatorCreated = !coordinator.replayed;
    if (coordinatorCreated) {
      await persistNativeArtifact(env, artifact, requestId);
      artifactPersisted = true;
      await env.RUNTIME_QUEUE.send(message);
    } else {
      const artifactState = await nativeArtifactState(env, coordinator);
      if (!artifactState.verified) throw new Error("native_artifact_replay_invalid");
      artifactPersisted = true;
    }
    return json({
      ...contract,
      status: "queued",
      accepted: true,
      persisted: true,
      probe_id: probeId,
      project_id: projectId,
      content_sha256: contentSha256,
      artifact_ref: artifactRef,
      coordinator_status: coordinator.status,
      replayed: Boolean(coordinator.replayed),
      queue_enqueued: coordinatorCreated,
      d1_read_verified: true,
      d1_artifact_persisted: artifactPersisted,
      queue_envelope_bytes: new TextEncoder().encode(JSON.stringify(message)).byteLength,
    }, 202);
  } catch (error) {
    if (artifactPersisted && coordinatorCreated) {
      try {
        await deleteNativeArtifact(env, message, requestId, "cloudflare_d1_native_artifact_rollback");
      } catch { /* best-effort bounded rollback */ }
    }
    if (coordinatorCreated) {
      try { await nativeCoordinatorCall(env, projectId, probeId, "DELETE"); } catch { /* best-effort bounded rollback */ }
    }
    if (error instanceof Error && error.message === "native_coordinator_conflict") {
      return json(blocked("native_idempotency_conflict", requestId, "The idempotency key is already bound to different content."), 409);
    }
    return json(blocked("cloudflare_native_probe_failed", requestId, "The Cloudflare-native probe could not be queued safely."), 503);
  }
}

async function getNativeProbe(url, probeId, env, requestId) {
  if (nativeContract(env).status !== "configured") {
    return json(blocked("cloudflare_native_configuration_unavailable", requestId, "The Cloudflare-native bindings are unavailable."), 503);
  }
  try {
    const projectId = safeProjectId(url.searchParams.get("project_id"));
    const cleanProbeId = safeId(probeId, "probe_id");
    const state = await nativeCoordinatorCall(env, projectId, cleanProbeId, "GET");
    const artifact = await nativeArtifactState(env, state);
    return json({
      ...state,
      contract_version: NATIVE_CONTRACT_VERSION,
      artifact_present: artifact.present,
      artifact_verified: artifact.verified,
      ...nativeRuntimeTruth(env),
    });
  } catch {
    return json({
      contract_version: NATIVE_CONTRACT_VERSION,
      status: "not_found",
      persisted: false,
      ...nativeRuntimeTruth(env),
    }, 404);
  }
}

async function deleteNativeProbe(request, url, probeId, env, requestId) {
  if (nativeContract(env).status !== "configured" || !env.AGENT_API_AUTH_TOKEN) {
    return json(blocked("cloudflare_native_configuration_unavailable", requestId, "The Cloudflare-native bindings are unavailable."), 503);
  }
  if (!(await authenticated(request, env))) {
    return json(blocked("stateful_runtime_authentication_required", requestId, "Agent API write authentication failed."), 401);
  }
  try {
    const projectId = safeProjectId(url.searchParams.get("project_id"));
    const cleanProbeId = safeId(probeId, "probe_id");
    const state = await nativeCoordinatorCall(env, projectId, cleanProbeId, "GET");
    const artifactDeleted = await deleteNativeArtifact(env, state, requestId);
    await nativeCoordinatorCall(env, projectId, cleanProbeId, "DELETE");
    return json({
      contract_version: NATIVE_CONTRACT_VERSION,
      status: "deleted",
      probe_id: cleanProbeId,
      project_id: projectId,
      artifact_deleted: artifactDeleted,
      persisted: false,
      ...nativeRuntimeTruth(env),
    });
  } catch {
    return json(blocked("cloudflare_native_cleanup_failed", requestId, "The Cloudflare-native probe cleanup failed."), 404);
  }
}

async function consumeNativeQueue(batch, env) {
  for (const queueMessage of batch.messages || []) {
    let message;
    try {
      const body = typeof queueMessage.body === "string" ? JSON.parse(queueMessage.body) : queueMessage.body;
      message = nativeMessage(body);
      const artifact = await nativeArtifactState(env, message);
      if (!artifact.present) throw new Error("native_artifact_missing");
      if (!artifact.verified) throw new Error("native_artifact_invalid");
      await nativeCoordinatorCall(env, message.project_id, message.probe_id, "POST", {
        action: "complete",
        message,
      });
      queueMessage.ack();
    } catch {
      const attempts = Number(queueMessage.attempts || 1);
      if (message && attempts >= 3) {
        try {
          await nativeCoordinatorCall(env, message.project_id, message.probe_id, "POST", {
            action: "fail",
            message,
          });
        } catch { /* fail closed without raw error output */ }
        queueMessage.ack();
      } else {
        queueMessage.retry({ delaySeconds: 1 });
      }
    }
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
      cloudflare_native_candidate: nativeContract(env),
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
  const method = request.method.toUpperCase();
  if (method !== "GET" && method !== "HEAD") {
    return json(blocked("contract_origin_read_only", requestId, "Unmatched stateful writes are never proxied."), 405);
  }
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
  for (const name of ["accept", "x-request-id", "traceparent"]) {
    const value = request.headers.get(name);
    if (value) headers.set(name, value);
  }
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 8_000);
  try {
    const response = await fetch(target, { method, headers, redirect: "manual", signal: controller.signal });
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
    const requestId = safeRequestId(request.headers.get("x-request-id"));
    const buildMatch = url.pathname.match(/^\/api\/v1\/build\/([A-Za-z0-9_-]{1,64})$/);
    const runtimeRunMatch = url.pathname.match(/^\/api\/v1\/phase2\/runtime\/runs\/([A-Za-z0-9_-]{1,64})$/);
    const nativeProbeMatch = url.pathname.match(/^\/api\/v1\/cloud-native\/probes\/([A-Za-z0-9_-]{1,64})$/);

    if (request.method === "GET" && url.pathname === "/api/v1/health") return health(env, requestId);
    if (request.method === "POST" && url.pathname === "/api/v1/auth/sessions") return createHostedSession(request, env, requestId);
    if (request.method === "POST" && url.pathname === "/api/v1/auth/sessions/verify") return verifyHostedSession(request, env, requestId);
    if (request.method === "POST" && url.pathname === "/api/v1/auth/sessions/revoke") return revokeHostedSession(request, env, requestId);
    if (request.method === "GET" && url.pathname === "/api/v1/cloud-native/contract") return json(nativeContract(env));
    if (request.method === "POST" && url.pathname === "/api/v1/cloud-native/probes") return createNativeProbe(request, env, requestId);
    if (request.method === "GET" && nativeProbeMatch) return getNativeProbe(url, nativeProbeMatch[1], env, requestId);
    if (request.method === "DELETE" && nativeProbeMatch) {
      return deleteNativeProbe(request, url, nativeProbeMatch[1], env, requestId);
    }
    if (request.method === "GET" && url.pathname === "/api/v1/phase2/runtime/contract") return json(runtimeContract(env));
    if (request.method === "POST" && url.pathname === "/api/v1/phase2/runtime/start") return startRuntime(request, env, requestId);
    if (request.method === "GET" && url.pathname === "/api/v1/phase2/runtime/runs") return listRuntimeRuns(url, env, requestId);
    if (request.method === "GET" && runtimeRunMatch) return getRuntimeRun(runtimeRunMatch[1], env, requestId);
    if (request.method === "POST" && url.pathname === "/api/v1/builds") return createBuild(request, env, requestId);
    if (request.method === "GET" && url.pathname === "/api/v1/builds") return listBuilds(url, env, requestId);
    if (request.method === "GET" && buildMatch) return getBuild(buildMatch[1], env, requestId);
    if (request.method === "DELETE" && buildMatch) return deleteBuild(request, buildMatch[1], env, requestId);
    if (request.method === "POST" && url.pathname === "/api/v1/memory/semantic") return upsertSemanticMemory(request, env, requestId);
    if (request.method === "GET" && url.pathname === "/api/v1/memory/semantic/search") return searchSemanticMemory(request, url, env, requestId);
    if (request.method === "POST" && url.pathname === "/api/v1/workspace/artifacts") return createArtifact(request, env, requestId);
    if (request.method === "GET" && url.pathname === "/api/v1/workspace/artifacts") return listArtifacts(url, env, requestId);

    return proxyContractOrigin(request, env, requestId);
  },
  async queue(batch, env) {
    await consumeNativeQueue(batch, env);
  },
};

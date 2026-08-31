const CONTRACT_VERSION = "o4-live-agent-mcp-write-v1";
const EVIDENCE_REF = "hosted_mcp_write_readback_audit_verified";
const SOURCE = "cloudflare-workers-hosted-mcp-runtime";
const AUTH_HEADER = "x-superbrain-agent-token";
const REPOSITORY = "strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM";
const WRITE_PATH_PREFIX = "d1://mcp_hosted_write_state";
const TOOLSET = "cloudflare_d1_hosted_mcp_adapter";
const CANDIDATE_PREVIEW_HOSTNAME = "cloud-superbrain-stateful-runtime-preview.strazzusochr.workers.dev";
const MAX_BODY_BYTES = 16 * 1024;
const MAX_AUDIT_LIMIT = 100;
const HOSTED_CAPABILITIES = Object.freeze([
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
const WRITE_KEYS = Object.freeze([
  "agent_role",
  "branch",
  "channel",
  "idempotency_key",
  "repository",
  "run_id",
  "session_id",
  "simulate_commit_audit_failure",
  "tool_request_id",
]);
const TIMEOUT_KEYS = Object.freeze([
  "agent_role",
  "allowed_scope",
  "audit_tags",
  "capability",
  "expected_output_type",
  "idempotency_key",
  "input_ref",
  "intent_summary",
  "redaction_required",
  "retry_budget",
  "run_id",
  "session_id",
  "timeout_ms",
  "tool_request_id",
  "toolset",
  "trace_id",
]);

function json(payload, status = 200) {
  return Response.json(payload, {
    status,
    headers: {
      "cache-control": "no-store",
      "content-security-policy": "default-src 'none'; frame-ancestors 'none'",
      "x-content-type-options": "nosniff",
      "x-frame-options": "DENY",
      "referrer-policy": "no-referrer",
      "x-superbrain-source": SOURCE,
    },
  });
}

function rejection(error, status) {
  return json({
    contract_version: CONTRACT_VERSION,
    status: "blocked",
    error,
    write_performed: false,
    live_mcp_writes: false,
    live_provider_calls: false,
    direct_provider_calls: false,
    production_deploy: false,
    secret_output: false,
    DEV_ONLY: false,
  }, status);
}

function propertySetIsExact(value, expected) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return false;
  const actual = Object.keys(value).sort();
  const required = [...expected].sort();
  return actual.length === required.length && actual.every((item, index) => item === required[index]);
}

function validUuid(value) {
  return typeof value === "string"
    && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function validBranch(value) {
  if (typeof value !== "string" || !/^[A-Za-z0-9._/-]{1,160}$/.test(value)) return false;
  if (value !== value.trim() || value.includes("//") || value.split("/").includes("..")) return false;
  const canonical = value.toLowerCase().replace(/^refs\/heads\//, "").replace(/^origin\//, "");
  return !["main", "master", "default", "trunk", "production", "prod"].includes(canonical);
}

function isSha(value, length) {
  return typeof value === "string" && new RegExp(`^[0-9a-f]{${length}}$`).test(value);
}

async function sha256(value) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function constantTimeEqual(left, right) {
  const [leftHash, rightHash] = await Promise.all([sha256(left || ""), sha256(right || "")]);
  let difference = 0;
  for (let index = 0; index < leftHash.length; index += 1) {
    difference |= leftHash.charCodeAt(index) ^ rightHash.charCodeAt(index);
  }
  return difference === 0;
}

function gateState(env) {
  const checks = {
    DB: Boolean(env.DB),
    AGENT_API_AUTH_TOKEN: typeof env.AGENT_API_AUTH_TOKEN === "string"
      && env.AGENT_API_AUTH_TOKEN.length >= 32
      && env.AGENT_API_AUTH_TOKEN.length <= 512
      && !/[\u0000-\u001f\u007f]/.test(env.AGENT_API_AUTH_TOKEN),
    HOSTED_MCP_WRITE_AUTHORIZED: env.HOSTED_MCP_WRITE_AUTHORIZED === "true",
    HOSTED_MCP_WRITE_OWNER_GRANT_REF: typeof env.HOSTED_MCP_WRITE_OWNER_GRANT_REF === "string"
      && env.HOSTED_MCP_WRITE_OWNER_GRANT_REF.length >= 8,
    LAYER_CREDIT_RUBRIC_APPROVAL_SHA: isSha(env.LAYER_CREDIT_RUBRIC_APPROVAL_SHA, 40),
    LIVE_MCP_WRITES_ENABLED: env.LIVE_MCP_WRITES_ENABLED === "true",
    HOSTED_MCP_DEPLOYMENT_ENVIRONMENT: env.HOSTED_MCP_DEPLOYMENT_ENVIRONMENT === "candidate_preview",
    HOSTED_MCP_PREVIEW_HOSTNAME: env.HOSTED_MCP_PREVIEW_HOSTNAME === CANDIDATE_PREVIEW_HOSTNAME,
    HOSTED_MCP_WRITE_BRANCH: validBranch(env.HOSTED_MCP_WRITE_BRANCH),
    SOURCE_COMMIT_SHA: isSha(env.SOURCE_COMMIT_SHA, 40),
    SOURCE_ARCHIVE_SHA256: isSha(env.SOURCE_ARCHIVE_SHA256, 64),
    SOURCE_BUNDLE_SHA256: isSha(env.SOURCE_BUNDLE_SHA256, 64),
    HOSTED_MCP_WRITE_OWNER_GRANT_COMMIT_SHA: isSha(env.HOSTED_MCP_WRITE_OWNER_GRANT_COMMIT_SHA, 40),
    LAYER_CREDIT_RUBRIC_APPROVAL_BOUND: isSha(env.LAYER_CREDIT_RUBRIC_APPROVAL_SHA, 40),
    HOSTED_MCP_VERIFIER_BLOB_SHA256: isSha(env.HOSTED_MCP_VERIFIER_BLOB_SHA256, 64),
    HOSTED_MCP_RUNTIME_BLOB_SHA256: isSha(env.HOSTED_MCP_RUNTIME_BLOB_SHA256, 64),
    HOSTED_MCP_RUBRIC_BLOB_SHA256: isSha(env.HOSTED_MCP_RUBRIC_BLOB_SHA256, 64),
    HOSTED_MCP_CAPABILITY_GATE_BLOB_SHA256: isSha(env.HOSTED_MCP_CAPABILITY_GATE_BLOB_SHA256, 64),
  };
  const missing = Object.entries(checks).filter(([, present]) => !present).map(([name]) => name);
  return { enabled: missing.length === 0, missing };
}

function contract(env) {
  const gates = gateState(env);
  return {
    contract_version: CONTRACT_VERSION,
    endpoint: "POST /mcp/api/v1/tools/live-write/probe",
    mode: "HOSTED bounded verifier probe",
    enabled: gates.enabled,
    hosted: true,
    DEV_ONLY: false,
    missing_configuration: gates.missing,
    source_commit_sha: env.SOURCE_COMMIT_SHA || null,
    source_archive_sha256: env.SOURCE_ARCHIVE_SHA256 || null,
    source_bundle_sha256: env.SOURCE_BUNDLE_SHA256 || null,
    repository: REPOSITORY,
    active_branch: env.HOSTED_MCP_WRITE_BRANCH || null,
    deployment_environment: env.HOSTED_MCP_DEPLOYMENT_ENVIRONMENT || null,
    candidate_preview_hostname: env.HOSTED_MCP_PREVIEW_HOSTNAME || null,
    owner_scope_approved: gates.enabled,
    rubric_approval_sha: isSha(env.LAYER_CREDIT_RUBRIC_APPROVAL_SHA, 40)
      ? env.LAYER_CREDIT_RUBRIC_APPROVAL_SHA
      : null,
    owner_grant_commit_sha: env.HOSTED_MCP_WRITE_OWNER_GRANT_COMMIT_SHA || null,
    verifier_blob_sha256: env.HOSTED_MCP_VERIFIER_BLOB_SHA256 || null,
    runtime_blob_sha256: env.HOSTED_MCP_RUNTIME_BLOB_SHA256 || null,
    rubric_blob_sha256: env.HOSTED_MCP_RUBRIC_BLOB_SHA256 || null,
    capability_gate_blob_sha256: env.HOSTED_MCP_CAPABILITY_GATE_BLOB_SHA256 || null,
    toolset: TOOLSET,
    caller_auth_type: "service_token",
    caller_scope: "hosted:mcp:verify",
    fixed_probe_resource: WRITE_PATH_PREFIX,
    arbitrary_paths_allowed: false,
    main_write_allowed: false,
    audit_fail_closed: true,
    rollback_on_audit_failure: true,
    hosted_verifier_capabilities: [...HOSTED_CAPABILITIES],
    live_mcp_writes_enabled: gates.enabled,
    live_mcp_writes: false,
    live_provider_calls: false,
    direct_provider_calls: false,
    production_deploy: false,
    secret_output: false,
  };
}

async function authorize(request, env) {
  const supplied = request.headers.get(AUTH_HEADER) || "";
  if (!(await constantTimeEqual(supplied, env.AGENT_API_AUTH_TOKEN || "")) || !supplied) {
    return rejection("hosted_mcp_authentication_required", 401);
  }
  if (!gateState(env).enabled) return rejection("hosted_mcp_owner_rubric_or_live_gate_closed", 403);
  return null;
}

async function readBoundedJson(request) {
  const declaredLength = Number(request.headers.get("content-length") || 0);
  if (Number.isFinite(declaredLength) && declaredLength > MAX_BODY_BYTES) throw new Error("body_too_large");
  if (!request.body) throw new Error("body_invalid");
  const reader = request.body.getReader();
  const chunks = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      if (!(value instanceof Uint8Array)) throw new Error("body_invalid");
      total += value.byteLength;
      if (total > MAX_BODY_BYTES) {
        await reader.cancel("body_too_large");
        throw new Error("body_too_large");
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  const text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  const body = JSON.parse(text);
  if (!body || typeof body !== "object" || Array.isArray(body)) throw new Error("body_invalid");
  return body;
}

function validateWritePayload(body, env) {
  if (!propertySetIsExact(body, WRITE_KEYS)) return { error: "hosted_mcp_write_shape_invalid", status: 400 };
  if (body.repository !== REPOSITORY || body.branch !== env.HOSTED_MCP_WRITE_BRANCH) {
    return { error: "hosted_mcp_exact_scope_rejected", status: 403 };
  }
  if (!validBranch(body.branch)
    || body.agent_role !== "coder"
    || !["runtime", "rollback"].includes(body.channel)
    || typeof body.simulate_commit_audit_failure !== "boolean"
    || !validUuid(body.session_id)) {
    return { error: "hosted_mcp_write_shape_invalid", status: 400 };
  }
  const suffixPattern = /^[0-9a-f]{32}$/;
  const requestPrefix = `o4-${body.channel}-`;
  const runPrefix = `o4-${body.channel}-run-`;
  const suffix = body.tool_request_id.slice(requestPrefix.length);
  if (!body.tool_request_id.startsWith(requestPrefix)
    || !suffixPattern.test(body.tool_request_id.slice(requestPrefix.length))
    || !body.run_id.startsWith(runPrefix)
    || !suffixPattern.test(body.run_id.slice(runPrefix.length))
    || body.run_id.slice(runPrefix.length) !== suffix
    || body.idempotency_key !== body.tool_request_id) {
    return { error: "hosted_mcp_idempotency_or_trace_binding_invalid", status: 400 };
  }
  if (body.simulate_commit_audit_failure && body.channel !== "rollback") {
    return { error: "hosted_mcp_rollback_probe_scope_rejected", status: 403 };
  }
  return null;
}

function canonicalWriteRequest(body) {
  return JSON.stringify({
    agent_role: body.agent_role,
    branch: body.branch,
    channel: body.channel,
    idempotency_key: body.idempotency_key,
    repository: body.repository,
    run_id: body.run_id,
    session_id: body.session_id,
    simulate_commit_audit_failure: body.simulate_commit_audit_failure,
    tool_request_id: body.tool_request_id,
  });
}

function writeContent(body, env) {
  return JSON.stringify({
    contract_version: CONTRACT_VERSION,
    evidence_ref: EVIDENCE_REF,
    repository: REPOSITORY,
    branch: env.HOSTED_MCP_WRITE_BRANCH,
    channel: body.channel,
    idempotency_key: body.idempotency_key,
    source_commit_sha: env.SOURCE_COMMIT_SHA,
    source_archive_sha256: env.SOURCE_ARCHIVE_SHA256,
    source_bundle_sha256: env.SOURCE_BUNDLE_SHA256,
    agent_role: "coder",
    toolset: TOOLSET,
    live_mcp_writes: true,
    live_provider_calls: false,
    direct_provider_calls: false,
    production_deploy: false,
    secret_output: false,
    DEV_ONLY: false,
  });
}

function safeAuditDetails(value) {
  const allowed = [
    "tool_request_id", "run_id", "trace_id", "session_id", "toolset", "capability",
    "status", "error_class", "evidence_ref", "write_phase", "write_path", "branch_ref", "write_result",
    "content_sha256", "live_mcp_write", "rollback_performed", "source_commit_sha", "source_archive_sha256", "source_bundle_sha256",
    "secret_output",
  ];
  const result = {};
  if (!value || typeof value !== "object" || Array.isArray(value)) return result;
  for (const key of allowed) {
    if (["string", "number", "boolean"].includes(typeof value[key]) || value[key] === null) result[key] = value[key];
  }
  return result;
}

function auditRecord(body, env, phase, options = {}) {
  const id = crypto.randomUUID();
  const traceId = body.trace_id || body.run_id;
  const contentSha256 = options.contentSha256 || "";
  const details = {
    tool_request_id: body.tool_request_id,
    run_id: body.run_id,
    trace_id: traceId,
    session_id: body.session_id,
    agent_role: body.agent_role,
    toolset: options.toolset || TOOLSET,
    capability: options.capability || "hosted_bounded_write",
    status: options.status || "success",
    error_class: options.errorClass || "none",
    evidence_ref: options.evidenceRef || EVIDENCE_REF,
    write_phase: phase,
    write_path: options.writePath || `${WRITE_PATH_PREFIX}/${body.channel || "timeout"}.json`,
    branch_ref: env.HOSTED_MCP_WRITE_BRANCH,
    write_result: options.writeResult || phase,
    content_sha256: contentSha256,
    live_mcp_write: options.liveMcpWrite === true,
    rollback_performed: options.rollbackPerformed === true,
    source_commit_sha: env.SOURCE_COMMIT_SHA,
    source_archive_sha256: env.SOURCE_ARCHIVE_SHA256,
    source_bundle_sha256: env.SOURCE_BUNDLE_SHA256,
    secret_output: false,
  };
  return {
    id,
    eventType: "mcp_tool_executed",
    traceId,
    subjectId: body.tool_request_id,
    details,
    detailsJson: JSON.stringify(details),
    createdAt: new Date().toISOString(),
  };
}

function auditStatement(env, record) {
  return env.DB.prepare(`
    INSERT INTO audit_events (id, event_type, trace_id, subject_id, details_json, created_at)
    VALUES (?, ?, ?, ?, ?, ?)
  `).bind(record.id, record.eventType, record.traceId, record.subjectId, record.detailsJson, record.createdAt);
}

async function readAudit(env, record) {
  const row = await env.DB.prepare(`
    SELECT id, event_type, trace_id, subject_id, details_json, created_at
    FROM audit_events
    WHERE id = ? AND event_type = ? AND trace_id = ? AND subject_id = ?
  `).bind(record.id, record.eventType, record.traceId, record.subjectId).first();
  return Boolean(row
    && row.id === record.id
    && row.event_type === record.eventType
    && row.trace_id === record.traceId
    && row.subject_id === record.subjectId
    && row.details_json === record.detailsJson);
}

async function persistAudit(env, record) {
  const result = await auditStatement(env, record).run();
  return Number(result?.meta?.changes || 0) === 1 && await readAudit(env, record);
}

async function readState(env, channel) {
  return env.DB.prepare(`
    SELECT channel, content_sha256, content_json, idempotency_key, source_commit_sha, trace_id, updated_at
    FROM mcp_hosted_write_state
    WHERE channel = ?
  `).bind(channel).first();
}

function stateStatement(env, value) {
  return env.DB.prepare(`
    INSERT INTO mcp_hosted_write_state
      (channel, content_sha256, content_json, idempotency_key, source_commit_sha, trace_id, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(channel) DO UPDATE SET
      content_sha256 = excluded.content_sha256,
      content_json = excluded.content_json,
      idempotency_key = excluded.idempotency_key,
      source_commit_sha = excluded.source_commit_sha,
      trace_id = excluded.trace_id,
      updated_at = excluded.updated_at
  `).bind(
    value.channel,
    value.content_sha256,
    value.content_json,
    value.idempotency_key,
    value.source_commit_sha,
    value.trace_id,
    value.updated_at,
  );
}

async function readIdempotency(env, key) {
  return env.DB.prepare(`
    SELECT idempotency_key, request_sha256, channel, content_sha256,
           prewrite_audit_event_id, postwrite_audit_event_id, trace_id, created_at
    FROM mcp_hosted_idempotency
    WHERE idempotency_key = ?
  `).bind(key).first();
}

function idempotencyStatement(env, value) {
  return env.DB.prepare(`
    INSERT INTO mcp_hosted_idempotency
      (idempotency_key, request_sha256, channel, content_sha256,
       prewrite_audit_event_id, postwrite_audit_event_id, trace_id, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `).bind(
    value.idempotency_key,
    value.request_sha256,
    value.channel,
    value.content_sha256,
    value.prewrite_audit_event_id,
    value.postwrite_audit_event_id,
    value.trace_id,
    value.created_at,
  );
}

function stateMatches(row, expected) {
  return Boolean(row
    && row.channel === expected.channel
    && row.content_sha256 === expected.content_sha256
    && row.content_json === expected.content_json
    && row.idempotency_key === expected.idempotency_key
    && row.source_commit_sha === expected.source_commit_sha
    && row.trace_id === expected.trace_id);
}

async function replayResponse(env, row, requestSha256) {
  if (!row || row.request_sha256 !== requestSha256) return null;
  const [prewrite, postwrite] = await Promise.all([
    env.DB.prepare("SELECT id, event_type, trace_id, subject_id, details_json, created_at FROM audit_events WHERE id = ? AND event_type = ? AND trace_id = ? AND subject_id = ?")
      .bind(row.prewrite_audit_event_id, "mcp_tool_executed", row.trace_id, row.idempotency_key).first(),
    env.DB.prepare("SELECT id, event_type, trace_id, subject_id, details_json, created_at FROM audit_events WHERE id = ? AND event_type = ? AND trace_id = ? AND subject_id = ?")
      .bind(row.postwrite_audit_event_id, "mcp_tool_executed", row.trace_id, row.idempotency_key).first(),
  ]);
  if (!prewrite || !postwrite) return rejection("hosted_mcp_replay_audit_readback_failed", 503);
  return json({
    contract_version: CONTRACT_VERSION,
    status: "verified",
    evidence_ref: EVIDENCE_REF,
    source_commit_sha: env.SOURCE_COMMIT_SHA,
    source_archive_sha256: env.SOURCE_ARCHIVE_SHA256,
    source_bundle_sha256: env.SOURCE_BUNDLE_SHA256,
    replayed: true,
    duplicate_write_prevented: true,
    write_performed: false,
    readback_verified: true,
    content_sha256: row.content_sha256,
    prewrite_audit_event_ref: await sha256(`audit:${row.prewrite_audit_event_id}`),
    mcp_audit_event_ref: await sha256(`audit:${row.postwrite_audit_event_id}`),
    audit_persisted: true,
    live_mcp_writes: true,
    live_provider_calls: false,
    direct_provider_calls: false,
    production_deploy: false,
    secret_output: false,
    DEV_ONLY: false,
  });
}

async function hostedWrite(request, env) {
  const denied = await authorize(request, env);
  if (denied) return denied;
  let body;
  try {
    body = await readBoundedJson(request);
  } catch {
    return rejection("hosted_mcp_write_body_invalid", 400);
  }
  const invalid = validateWritePayload(body, env);
  if (invalid) return rejection(invalid.error, invalid.status);

  const requestSha256 = await sha256(canonicalWriteRequest(body));
  const existing = await readIdempotency(env, body.idempotency_key);
  if (existing) {
    if (existing.request_sha256 !== requestSha256) return rejection("hosted_mcp_idempotency_conflict", 409);
    return replayResponse(env, existing, requestSha256);
  }

  const contentJson = writeContent(body, env);
  const contentSha256 = await sha256(contentJson);
  const writePath = `${WRITE_PATH_PREFIX}/${body.channel}.json`;
  const prewriteAudit = auditRecord(body, env, "authorized", {
    contentSha256,
    writePath,
    writeResult: "authorized",
  });
  const now = new Date().toISOString();
  const state = {
    channel: body.channel,
    content_sha256: contentSha256,
    content_json: contentJson,
    idempotency_key: body.idempotency_key,
    source_commit_sha: env.SOURCE_COMMIT_SHA,
    trace_id: body.run_id,
    updated_at: now,
  };
  const postwriteAudit = auditRecord(body, env, "committed", {
    contentSha256,
    writePath,
    writeResult: "committed",
    liveMcpWrite: true,
  });
  const idempotency = {
    idempotency_key: body.idempotency_key,
    request_sha256: requestSha256,
    channel: body.channel,
    content_sha256: contentSha256,
    prewrite_audit_event_id: prewriteAudit.id,
    postwrite_audit_event_id: postwriteAudit.id,
    trace_id: body.run_id,
    created_at: now,
  };
  let channelStateCurrent = false;

  try {
    const statements = [
      auditStatement(env, prewriteAudit),
      stateStatement(env, state),
      auditStatement(env, postwriteAudit),
      idempotencyStatement(env, idempotency),
    ];
    if (body.simulate_commit_audit_failure) statements.push(idempotencyStatement(env, idempotency));
    await env.DB.batch(statements);
    const [stateReadback, auditVerified, idempotencyReadback] = await Promise.all([
      readState(env, body.channel),
      readAudit(env, postwriteAudit),
      readIdempotency(env, body.idempotency_key),
    ]);
    channelStateCurrent = stateMatches(stateReadback, state);
    if (!auditVerified
      || !idempotencyReadback
      || idempotencyReadback.request_sha256 !== requestSha256
      || idempotencyReadback.content_sha256 !== contentSha256
      || idempotencyReadback.channel !== body.channel
      || idempotencyReadback.trace_id !== body.run_id) {
      return rejection("hosted_mcp_immutable_receipt_readback_failed", 503);
    }
  } catch {
    const winner = await readIdempotency(env, body.idempotency_key).catch(() => null);
    if (winner?.request_sha256 === requestSha256) return replayResponse(env, winner, requestSha256);
    if (winner) return rejection("hosted_mcp_idempotency_conflict", 409);
    if (body.simulate_commit_audit_failure) {
      const rollbackAudit = auditRecord(body, env, "rolled_back", {
        contentSha256,
        status: "degraded",
        errorClass: "commit_audit_failed",
        writeResult: "atomic_batch_rejected_no_side_effect",
        rollbackPerformed: true,
      });
      const auditPersisted = await persistAudit(env, rollbackAudit).catch(() => false);
      return json({
        source_commit_sha: env.SOURCE_COMMIT_SHA,
        source_archive_sha256: env.SOURCE_ARCHIVE_SHA256,
        source_bundle_sha256: env.SOURCE_BUNDLE_SHA256,
        detail: {
        error: "hosted_mcp_write_commit_failed",
        rollback_performed: true,
        rollback_audit_persisted: auditPersisted,
        rollback_state_verified: !(await readIdempotency(env, body.idempotency_key).catch(() => true)),
        live_mcp_writes: false,
        secret_output: false,
        },
      }, 503);
    }
    return rejection("hosted_mcp_atomic_write_failed", 503);
  }

  return json({
    contract_version: CONTRACT_VERSION,
    status: "verified",
    evidence_ref: EVIDENCE_REF,
    source_commit_sha: env.SOURCE_COMMIT_SHA,
    source_archive_sha256: env.SOURCE_ARCHIVE_SHA256,
    source_bundle_sha256: env.SOURCE_BUNDLE_SHA256,
    repository: REPOSITORY,
    branch: env.HOSTED_MCP_WRITE_BRANCH,
    channel: body.channel,
    caller_auth_type: "service_token",
    caller_scope: "hosted:mcp:verify",
    toolset: TOOLSET,
    write_path: writePath,
    write_performed: true,
    readback_verified: true,
    immutable_receipt_verified: true,
    channel_state_current: channelStateCurrent,
    content_sha256: contentSha256,
    prewrite_audit_event_ref: await sha256(`audit:${prewriteAudit.id}`),
    mcp_audit_event_ref: await sha256(`audit:${postwriteAudit.id}`),
    audit_persisted: true,
    audit_fail_closed: true,
    rollback_on_audit_failure: true,
    live_mcp_writes: true,
    live_provider_calls: false,
    direct_provider_calls: false,
    production_deploy: false,
    secret_output: false,
    DEV_ONLY: false,
  });
}

function validateTimeoutPayload(body) {
  return propertySetIsExact(body, TIMEOUT_KEYS)
    && typeof body.tool_request_id === "string"
    && /^l5-timeout-[0-9a-f]{32}$/.test(body.tool_request_id)
    && typeof body.run_id === "string"
    && /^l5-timeout-run-[0-9a-f]{32}$/.test(body.run_id)
    && validUuid(body.session_id)
    && typeof body.trace_id === "string"
    && /^l5-timeout-trace-[0-9a-f]{32}$/.test(body.trace_id)
    && body.agent_role === "tester"
    && body.toolset === TOOLSET
    && body.capability === "simulate_timeout"
    && body.allowed_scope === "d1://mcp_hosted_timeout_effects"
    && Number.isInteger(body.timeout_ms)
    && body.timeout_ms >= 1
    && body.timeout_ms <= 5_000
    && body.retry_budget === 0
    && body.idempotency_key === body.tool_request_id
    && Array.isArray(body.audit_tags)
    && body.audit_tags.length <= 8
    && body.audit_tags.every((value) => typeof value === "string" && value.length <= 40)
    && body.redaction_required === true
    && body.expected_output_type === "timeout_guard_evidence"
    && typeof body.intent_summary === "string"
    && body.intent_summary.length <= 500
    && body.input_ref === '{"operation":"delayed_d1_insert"}';
}

function abortableDelay(milliseconds, signal) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(resolve, milliseconds);
    signal.addEventListener("abort", () => {
      clearTimeout(timer);
      reject(new DOMException("deadline exceeded", "AbortError"));
    }, { once: true });
  });
}

async function delayedD1Attempt(env, body, signal) {
  await abortableDelay(body.timeout_ms + 50, signal);
  if (signal.aborted) throw new DOMException("deadline exceeded", "AbortError");
  return env.DB.prepare(`
    INSERT INTO mcp_hosted_timeout_effects (effect_key, attempted_at, source_commit_sha, trace_id)
    VALUES (?, ?, ?, ?)
  `).bind(body.idempotency_key, new Date().toISOString(), env.SOURCE_COMMIT_SHA, body.trace_id).run();
}

async function deadlineTriggered(env, body) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), body.timeout_ms);
  try {
    await delayedD1Attempt(env, body, controller.signal);
    return false;
  } catch (error) {
    return error?.name === "AbortError";
  } finally {
    clearTimeout(timer);
  }
}

async function hostedTimeout(request, env) {
  const denied = await authorize(request, env);
  if (denied) return denied;
  let body;
  try {
    body = await readBoundedJson(request);
  } catch {
    return rejection("hosted_mcp_timeout_body_invalid", 400);
  }
  if (!validateTimeoutPayload(body)) return rejection("hosted_mcp_timeout_shape_invalid", 400);
  if (!(await deadlineTriggered(env, body))) return rejection("hosted_mcp_timeout_not_enforced", 500);
  await abortableDelay(body.timeout_ms + 60, new AbortController().signal);
  const afterEffect = await env.DB.prepare(`
    SELECT effect_key FROM mcp_hosted_timeout_effects WHERE effect_key = ?
  `).bind(body.idempotency_key).first();
  if (afterEffect) return rejection("hosted_mcp_timeout_after_effect_detected", 503);

  const timeoutAudit = auditRecord(body, env, "timeout", {
    status: "timeout",
    errorClass: "timeout",
    evidenceRef: "mcp_timeout_guard",
    capability: "simulate_timeout",
    writeResult: "aborted_before_tool_side_effect",
  });
  if (!(await persistAudit(env, timeoutAudit))) return rejection("hosted_mcp_timeout_audit_unavailable", 503);
  return json({
    contract_version: CONTRACT_VERSION,
    status: "timeout",
    source_commit_sha: env.SOURCE_COMMIT_SHA,
    source_archive_sha256: env.SOURCE_ARCHIVE_SHA256,
    source_bundle_sha256: env.SOURCE_BUNDLE_SHA256,
    result_ref: `mcp-result:${await sha256(`request:${body.tool_request_id}`)}`,
    audit_event_ref: await sha256(`audit:${timeoutAudit.id}`),
    error_class: "timeout",
    retry_after_ms: Math.min(body.timeout_ms, 5_000),
    rollback_note: "A cancellable delayed D1 adapter attempt was aborted; delayed readback proved no after-effect.",
    delayed_readback_verified: true,
    evidence_ref: "mcp_timeout_guard",
    audit_persisted: true,
    timeout_enforced: true,
    write_performed: false,
    live_mcp_writes: false,
    live_provider_calls: false,
    direct_provider_calls: false,
    production_deploy: false,
    secret_output: false,
    DEV_ONLY: false,
  });
}

async function auditFeed(request, url, env) {
  const denied = await authorize(request, env);
  if (denied) return denied;
  if (!env.DB) return rejection("hosted_mcp_audit_storage_unavailable", 503);
  const allowedParams = new Set(["limit", "run_id", "trace_id", "tool_request_id"]);
  if ([...url.searchParams.keys()].some((key) => !allowedParams.has(key))) return rejection("hosted_mcp_audit_scope_invalid", 400);
  const runId = url.searchParams.get("run_id") || "";
  const traceId = url.searchParams.get("trace_id") || "";
  const toolRequestId = url.searchParams.get("tool_request_id") || "";
  if (!runId || !traceId || !toolRequestId) return rejection("hosted_mcp_audit_correlation_required", 400);
  const requested = Number(url.searchParams.get("limit") || 20);
  const limit = Number.isInteger(requested) && requested >= 1 ? Math.min(requested, MAX_AUDIT_LIMIT) : 20;
  try {
    const result = await env.DB.prepare(`
      SELECT id, event_type, trace_id, subject_id, details_json, created_at
      FROM audit_events
      WHERE event_type = ? AND trace_id = ? AND subject_id = ?
        AND json_extract(details_json, '$.run_id') = ?
      ORDER BY created_at DESC
      LIMIT ?
    `).bind("mcp_tool_executed", traceId, toolRequestId, runId, limit).all();
    const events = [];
    for (const row of result.results || []) {
      let details;
      try { details = safeAuditDetails(JSON.parse(row.details_json || "{}")); } catch { continue; }
      for (const key of ["tool_request_id", "run_id", "trace_id", "session_id"]) {
        if (details[key]) details[`${key}_ref`] = await sha256(`${key}:${details[key]}`);
        delete details[key];
      }
      events.push({
        event_ref: await sha256(`audit:${row.id}`),
        event_type: row.event_type,
        caller_auth_type: "service_token",
        caller_scope: "hosted:mcp:verify",
        correlation_ref: await sha256(`trace:${row.trace_id}`),
        details,
        created_at: row.created_at,
        severity: details.status === "timeout" || details.status === "degraded" ? "warning" : "info",
      });
    }
    return json({
      contract_version: "mcp-hosted-audit-feed-v1",
      status: "verified",
      source_commit_sha: env.SOURCE_COMMIT_SHA || null,
      source_archive_sha256: env.SOURCE_ARCHIVE_SHA256 || null,
      source_bundle_sha256: env.SOURCE_BUNDLE_SHA256 || null,
      events,
      secret_output: false,
    });
  } catch {
    return rejection("hosted_mcp_audit_readback_failed", 503);
  }
}

export async function handleHostedMcpRoute(request, url, env) {
  const isHostedMcpPath = url.pathname.startsWith("/mcp/api/v1/") || url.pathname === "/api/v1/audit/mcp";
  if (isHostedMcpPath && (url.protocol !== "https:" || url.hostname !== CANDIDATE_PREVIEW_HOSTNAME)) {
    return rejection("hosted_mcp_candidate_preview_origin_required", 403);
  }
  if (request.method === "GET" && url.pathname === "/mcp/api/v1/tools/live-write/probe/contract") {
    return json(contract(env));
  }
  if (request.method === "POST" && url.pathname === "/mcp/api/v1/tools/live-write/probe") {
    return hostedWrite(request, env);
  }
  if (request.method === "POST" && url.pathname === "/mcp/api/v1/tools/execute") {
    return hostedTimeout(request, env);
  }
  if (request.method === "GET" && url.pathname === "/api/v1/audit/mcp") {
    return auditFeed(request, url, env);
  }
  return null;
}

const CONTRACT_VERSION = "cloudflare-workers-ai-llm-gateway-v1";
const EVIDENCE_CONTRACT_VERSION = "llm-gateway-independent-evidence-v1";
const GATEWAY_SOURCE = "cloudflare-workers-ai-llm-gateway";
const AUTH_HEADER = "x-superbrain-gateway-token";
const VERIFICATION_HEADER = "x-superbrain-verification-probe";
const MAX_BODY_BYTES = 64 * 1024;
const MAX_STREAM_BYTES = 2 * 1024 * 1024;
const MAX_STREAM_FRAME_BYTES = 64 * 1024;
const MAX_MESSAGES = 16;
const MAX_INPUT_CHARS = 20_000;
const MAX_OUTPUT_TOKENS = 2_048;
const DEFAULT_ATTEMPT_TIMEOUT_MS = 25_000;
const MIN_ATTEMPT_TIMEOUT_MS = 10;
const MAX_ATTEMPT_TIMEOUT_MS = 30_000;
const GATEWAY_LOG_READBACK_TIMEOUT_MS = 5_000;
const GATEWAY_LOG_POLL_MS = 100;
const PROVIDER_ROTATION_BACKOFF_SECONDS = Object.freeze([30, 60, 120, 300]);
const PROVIDER_RESET_AFTER_SECONDS = 900;
const ALLOWED_MODELS = Object.freeze([
  "@cf/qwen/qwen2.5-coder-32b-instruct",
  "@cf/meta/llama-3.1-8b-instruct-fast",
]);
const ALLOWED_MODEL_SET = new Set(ALLOWED_MODELS);
const TRACEPARENT_PATTERN = /^00-([0-9a-f]{32})-([0-9a-f]{16})-(0[01])$/;
const TRACE_ID_PATTERN = /^[0-9a-f]{32}$/;
const SAFE_REQUEST_ID_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/;
const SAFE_SEMANTIC_KEY_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$/;
const SAFE_GATEWAY_ID_PATTERN = /^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$/;
const SAFE_LOG_ID_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._:-]{2,159}$/;
const SUPPORTED_VERIFICATION_PROBES = new Set([
  "hosted_stream_parity",
  "bounded_fallback",
  "trace_correlation",
]);

class GatewayFault extends Error {
  constructor(code, status, note, facts = {}) {
    super(code);
    this.code = code;
    this.status = status;
    this.note = note;
    this.facts = facts;
  }
}

function randomHex(byteLength) {
  const bytes = new Uint8Array(byteLength);
  crypto.getRandomValues(bytes);
  return [...bytes].map((value) => value.toString(16).padStart(2, "0")).join("");
}

function safeRequestId(value) {
  return typeof value === "string" && SAFE_REQUEST_ID_PATTERN.test(value)
    ? value
    : `gateway-${crypto.randomUUID()}`;
}

function traceContext(request, requestId) {
  const supplied = request.headers.get("traceparent");
  if (!supplied) {
    return {
      valid: true,
      supplied: false,
      traceId: randomHex(16),
      requestSpanId: randomHex(8),
      responseSpanId: randomHex(8),
      flags: "01",
      requestId,
    };
  }
  const match = TRACEPARENT_PATTERN.exec(supplied);
  const valid = Boolean(match && match[1] !== "0".repeat(32) && match[2] !== "0".repeat(16));
  if (!valid) {
    return {
      valid: false,
      supplied: true,
      traceId: randomHex(16),
      requestSpanId: randomHex(8),
      responseSpanId: randomHex(8),
      flags: "01",
      requestId,
    };
  }
  return {
    valid: true,
    supplied: true,
    traceId: match[1],
    requestSpanId: match[2],
    responseSpanId: randomHex(8),
    flags: match[3],
    requestId,
  };
}

function responseTraceparent(context) {
  return `00-${context.traceId}-${context.responseSpanId}-${context.flags}`;
}

function baseHeaders(context, extraHeaders = {}) {
  return {
    "cache-control": "no-store",
    "x-content-type-options": "nosniff",
    "x-superbrain-source": GATEWAY_SOURCE,
    ...(context ? { "x-request-id": context.requestId, traceparent: responseTraceparent(context) } : {}),
    ...extraHeaders,
  };
}

function json(payload, status = 200, context = null, extraHeaders = {}) {
  return Response.json(payload, { status, headers: baseHeaders(context, extraHeaders) });
}

function errorPayload(code, context, note, facts = {}) {
  return {
    contract_version: CONTRACT_VERSION,
    status: "blocked",
    error: code,
    request_id: context.requestId,
    trace_id: context.traceId,
    provider_call_count: 0,
    guard_stage: "pre_provider",
    audit_persisted: false,
    audit_readback_verified: false,
    gateway_log_readback_verified: false,
    live_provider_calls: false,
    direct_provider_calls: false,
    secret_output: false,
    note,
    ...facts,
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
  for (let index = 0; index < leftBytes.length; index += 1) difference |= leftBytes[index] ^ rightBytes[index];
  return difference === 0;
}

async function readBoundedBody(request) {
  const declared = request.headers.get("content-length");
  if (declared !== null) {
    const declaredLength = Number(declared);
    if (Number.isFinite(declaredLength) && declaredLength > MAX_BODY_BYTES) {
      throw new GatewayFault("request_too_large", 422, "The bounded request body exceeds 64 KiB.", { max_body_bytes: MAX_BODY_BYTES });
    }
  }
  if (!request.body) return "";
  const reader = request.body.getReader();
  const chunks = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      if (!(value instanceof Uint8Array)) {
        throw new GatewayFault("invalid_request_body", 422, "The request body stream is invalid.");
      }
      total += value.byteLength;
      if (total > MAX_BODY_BYTES) {
        try { await reader.cancel("request body limit exceeded"); } catch { /* best effort */ }
        throw new GatewayFault("request_too_large", 422, "The bounded request body exceeds 64 KiB.", { max_body_bytes: MAX_BODY_BYTES });
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
  try {
    return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch {
    throw new GatewayFault("invalid_utf8", 422, "The request body is not valid UTF-8.");
  }
}

async function readJson(request) {
  const text = await readBoundedBody(request);
  try {
    const parsed = JSON.parse(text);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new GatewayFault("invalid_json_object", 422, "The request body must be a JSON object.");
    }
    return parsed;
  } catch (error) {
    if (error instanceof GatewayFault) throw error;
    throw new GatewayFault("invalid_json", 422, "The request body is not valid JSON.");
  }
}

function validateMessages(value) {
  if (!Array.isArray(value) || value.length === 0 || value.length > MAX_MESSAGES) {
    throw new GatewayFault("invalid_messages", 422, "Messages must contain between one and sixteen items.", { max_messages: MAX_MESSAGES });
  }
  let inputChars = 0;
  const messages = value.map((message) => {
    if (!message || typeof message !== "object" || Array.isArray(message)) {
      throw new GatewayFault("invalid_messages", 422, "Each message must be an object.");
    }
    const role = String(message.role || "");
    if (!["system", "user", "assistant"].includes(role)) {
      throw new GatewayFault("invalid_message_role", 422, "A message role is outside the gateway schema.");
    }
    if (typeof message.content !== "string") {
      throw new GatewayFault("invalid_message_content", 422, "Message content must be bounded text.");
    }
    inputChars += message.content.length;
    return { role, content: message.content };
  });
  if (inputChars === 0) {
    throw new GatewayFault("invalid_messages", 422, "At least one non-empty message is required.", { request_input_chars: inputChars, max_input_chars: MAX_INPUT_CHARS });
  }
  if (inputChars > MAX_INPUT_CHARS) {
    throw new GatewayFault("input_limit_exceeded", 422, "The input character budget was exceeded before the provider boundary.", { request_input_chars: inputChars, max_input_chars: MAX_INPUT_CHARS });
  }
  return { messages, inputChars };
}

function usagePayload(result) {
  const usage = result && typeof result.usage === "object" ? result.usage : {};
  const promptTokens = Number(usage.prompt_tokens || 0);
  const completionTokens = Number(usage.completion_tokens || 0);
  return {
    prompt_tokens: Number.isFinite(promptTokens) ? promptTokens : 0,
    completion_tokens: Number.isFinite(completionTokens) ? completionTokens : 0,
    total_tokens: Number.isFinite(Number(usage.total_tokens)) ? Number(usage.total_tokens) : promptTokens + completionTokens,
  };
}

function safeAuditText(value, fallback = "none") {
  const text = typeof value === "string" ? value : fallback;
  return /^[A-Za-z0-9@][A-Za-z0-9._:@/-]{0,159}$/.test(text) ? text : fallback;
}

function safeOptionalLogId(value) {
  return typeof value === "string" && SAFE_LOG_ID_PATTERN.test(value) ? value : null;
}

function hasAuditBinding(env) {
  return Boolean(env.DB && typeof env.DB.prepare === "function");
}

function hasAiBinding(env) {
  return Boolean(env.AI && typeof env.AI.run === "function" && typeof env.AI.gateway === "function");
}

function validGatewayId(value) {
  return typeof value === "string" && SAFE_GATEWAY_ID_PATTERN.test(value);
}

function attemptTimeoutMs(env) {
  const parsed = Number(env.PROVIDER_ATTEMPT_TIMEOUT_MS ?? DEFAULT_ATTEMPT_TIMEOUT_MS);
  if (!Number.isFinite(parsed)) return DEFAULT_ATTEMPT_TIMEOUT_MS;
  return Math.max(MIN_ATTEMPT_TIMEOUT_MS, Math.min(MAX_ATTEMPT_TIMEOUT_MS, Math.trunc(parsed)));
}

function sanitizedAttempt(attempt) {
  return {
    attempt_index: Number.isInteger(attempt.attempt_index) ? attempt.attempt_index : 0,
    gateway_log_id: safeOptionalLogId(attempt.gateway_log_id),
    provider: safeAuditText(attempt.provider),
    model: safeAuditText(attempt.model),
    success: attempt.success === true,
    gateway_log_readback_verified: attempt.gateway_log_readback_verified === true,
    metadata_correlation_verified: attempt.metadata_correlation_verified === true,
    metadata: {
      request_id: safeAuditText(attempt.metadata?.request_id),
      trace_id: safeAuditText(attempt.metadata?.trace_id),
      attempt_index: Number.isInteger(attempt.metadata?.attempt_index) ? attempt.metadata.attempt_index : 0,
      verification_probe: safeAuditText(attempt.metadata?.verification_probe),
    },
    failure_reason: safeAuditText(attempt.failure_reason),
    cancellation_requested: attempt.cancellation_requested === true,
    cancellation_guaranteed: false,
  };
}

function sanitizedAuditDetails(env, context, details) {
  const gatewayAttempts = Array.isArray(details.gateway_attempts)
    ? details.gateway_attempts.slice(0, 2).map(sanitizedAttempt)
    : [];
  const fallback = details.fallback && typeof details.fallback === "object"
    ? {
        used: details.fallback.used === true,
        bounded: details.fallback.bounded === true,
        reason_code: safeAuditText(details.fallback.reason_code),
        primary_model: safeAuditText(details.fallback.primary_model),
        selected_model: safeAuditText(details.fallback.selected_model),
        provider_attempt_count: Number.isInteger(details.fallback.provider_attempt_count) ? details.fallback.provider_attempt_count : 0,
      }
    : null;
  return {
    contract_version: CONTRACT_VERSION,
    request_id: context.requestId,
    trace_id: context.traceId,
    outcome: safeAuditText(details.outcome),
    model: safeAuditText(details.model),
    selected_model: safeAuditText(details.selected_model),
    verification_probe: safeAuditText(details.verification_probe),
    reason_code: safeAuditText(details.reason_code),
    provider_call_count: Number.isInteger(details.provider_call_count) ? details.provider_call_count : 0,
    guard_stage: details.guard_stage === "post_provider" ? "post_provider" : "pre_provider",
    stream: details.stream === true,
    fallback_used: details.fallback_used === true,
    fallback,
    semantic_probe_verified: details.semantic_probe_verified === true,
    provider_stream_terminal_mode: safeAuditText(details.provider_stream_terminal_mode),
    provider_finish_reason: safeAuditText(details.provider_finish_reason),
    gateway_attempts: gatewayAttempts,
    gateway_log_readback_verified: details.gateway_log_readback_verified === true,
    live_provider_calls: details.live_provider_calls === true,
    cancellation_requested: details.cancellation_requested === true,
    cancellation_guaranteed: false,
    direct_provider_calls: false,
    secret_output: false,
    ai_gateway_id: safeAuditText(env.AI_GATEWAY_ID),
    source_commit_sha: safeAuditText(env.SOURCE_COMMIT_SHA),
  };
}

async function persistAudit(env, context, eventType, details) {
  if (!hasAuditBinding(env)) return { persisted: false, evidenceRef: null, details: null };
  const auditId = `llm-audit-${crypto.randomUUID()}`;
  const createdAt = new Date().toISOString();
  const safeDetails = sanitizedAuditDetails(env, context, details);
  const detailsJson = JSON.stringify(safeDetails);
  try {
    const writeResult = await env.DB.prepare(
      "INSERT INTO audit_events (id, event_type, trace_id, subject_id, details_json, created_at) VALUES (?, ?, ?, ?, ?, ?)",
    ).bind(auditId, eventType, context.traceId, null, detailsJson, createdAt).run();
    if (!writeResult || writeResult.success !== true) return { persisted: false, evidenceRef: null, details: null };
    const row = await env.DB.prepare(
      "SELECT id, event_type, trace_id, details_json FROM audit_events WHERE id = ? LIMIT 1",
    ).bind(auditId).first();
    const persisted = Boolean(row && row.id === auditId && row.event_type === eventType && row.trace_id === context.traceId && row.details_json === detailsJson);
    return {
      persisted,
      evidenceRef: persisted ? `d1_audit:${auditId}` : null,
      details: persisted ? safeDetails : null,
    };
  } catch {
    return { persisted: false, evidenceRef: null, details: null };
  }
}

async function readAuditByTrace(env, traceId) {
  if (!hasAuditBinding(env)) return null;
  try {
    return await env.DB.prepare(
      "SELECT id, event_type, trace_id, details_json FROM audit_events WHERE trace_id = ? ORDER BY created_at DESC LIMIT 1",
    ).bind(traceId).first();
  } catch {
    return null;
  }
}

async function auditedGuard(env, context, fault) {
  const audit = await persistAudit(env, context, "llm.gateway.guard.blocked", {
    outcome: "blocked",
    reason_code: fault.code,
    provider_call_count: 0,
    guard_stage: "pre_provider",
    live_provider_calls: false,
    stream: false,
    fallback_used: false,
    gateway_attempts: [],
    gateway_log_readback_verified: false,
  });
  if (hasAuditBinding(env) && !audit.persisted) {
    return json(errorPayload("audit_persistence_unavailable", context, "The guard fired but its audit row could not be persisted and read back.", { original_error: fault.code }), 503, context);
  }
  return json(errorPayload(fault.code, context, fault.note, {
    ...fault.facts,
    audit_persisted: audit.persisted,
    audit_readback_verified: audit.persisted,
    evidence_ref: audit.evidenceRef,
  }), fault.status, context);
}

function directProviderBypassRequested(body) {
  const forbiddenKeys = new Set(["api_key", "authorization", "base_url", "direct_provider_key_ref", "direct_provider_url", "provider_url"]);
  if (Object.keys(body).some((key) => forbiddenKeys.has(key))) return true;
  if (!body.metadata || typeof body.metadata !== "object" || Array.isArray(body.metadata)) return false;
  return Object.keys(body.metadata).some((key) => forbiddenKeys.has(key));
}

function validateMetadata(body, context, request) {
  if (body.metadata !== undefined && (!body.metadata || typeof body.metadata !== "object" || Array.isArray(body.metadata))) {
    throw new GatewayFault("invalid_metadata", 422, "Metadata must be a JSON object.");
  }
  const metadata = body.metadata || {};
  const probe = metadata.verification_probe === undefined ? null : String(metadata.verification_probe);
  if (probe && !SUPPORTED_VERIFICATION_PROBES.has(probe)) {
    throw new GatewayFault("verification_probe_not_allowed", 403, "The requested verification probe is outside the allowlist.");
  }
  if (metadata.trace_id !== undefined && String(metadata.trace_id) !== context.traceId) {
    throw new GatewayFault("trace_id_mismatch", 422, "The metadata trace ID does not match traceparent.");
  }
  if (probe === "trace_correlation" && !context.supplied) {
    throw new GatewayFault("traceparent_required", 422, "The trace-correlation probe requires a valid caller traceparent.");
  }
  if (probe === "hosted_stream_parity") {
    const headerKey = request.headers.get("x-superbrain-semantic-key") || "";
    const metadataKey = String(metadata.semantic_key || "");
    if (!SAFE_SEMANTIC_KEY_PATTERN.test(headerKey) || headerKey !== metadataKey) {
      throw new GatewayFault("semantic_key_mismatch", 403, "The stream-parity semantic key is missing or mismatched.");
    }
  }
  if (probe === "bounded_fallback") {
    if (request.headers.get(VERIFICATION_HEADER) !== "bounded-fallback-v1" || String(metadata.verification_probe_version || "") !== "llm-hosted-fallback-probe-v1") {
      throw new GatewayFault("fallback_probe_contract_invalid", 403, "The bounded fallback probe header and body contract do not match.");
    }
    if (body.stream === true) {
      throw new GatewayFault("fallback_stream_not_supported", 422, "The bounded fallback verification contract is non-streaming to avoid mixed partial streams.");
    }
  }
  return { metadata, probe };
}

function canonicalProbeContent(content, probe) {
  if (probe !== "hosted_stream_parity") return content;
  const normalized = content.trim().toLowerCase().replace(/[.!]+$/g, "");
  if (normalized !== "verified") {
    throw new GatewayFault("provider_verification_semantics_mismatch", 502, "The provider did not satisfy the bounded single-word semantic probe.", { guard_stage: "post_provider" });
  }
  return "verified";
}

function providerInput(messages, maxTokens, temperature, stream) {
  return { messages, max_tokens: maxTokens, temperature, stream };
}

function gatewayMetadata(context, attemptIndex, probe) {
  return {
    contract: "superbrain-llm-v1",
    request_id: context.requestId,
    trace_id: context.traceId,
    attempt_index: attemptIndex,
    verification_probe: probe || "none",
  };
}

function providerOptions(env, context, attemptIndex, probe, signal, timeoutMs) {
  return {
    signal,
    extraHeaders: {
      "cf-aig-collect-log-payload": "false",
    },
    gateway: {
      id: env.AI_GATEWAY_ID,
      skipCache: true,
      collectLog: true,
      metadata: gatewayMetadata(context, attemptIndex, probe),
      requestTimeoutMs: timeoutMs,
      retries: { maxAttempts: 1 },
    },
  };
}

function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function raceReadbackDeadline(promise, timeoutMs) {
  let timer = null;
  const timeout = new Promise((resolve, reject) => {
    timer = setTimeout(() => reject(new GatewayFault(
      "gateway_log_readback_unavailable",
      503,
      "AI Gateway log readback did not complete within the bounded deadline.",
    )), timeoutMs);
  });
  try {
    return await Promise.race([promise, timeout]);
  } finally {
    if (timer !== null) clearTimeout(timer);
  }
}

async function raceDeadline(promise, controller, timeoutMs) {
  let timer = null;
  const timeout = new Promise((resolve, reject) => {
    timer = setTimeout(() => {
      controller.abort("provider attempt deadline exceeded");
      reject(new GatewayFault("provider_attempt_deadline_exceeded", 502, "The bounded provider attempt exceeded its deadline.", {
        cancellation_requested: true,
        cancellation_guaranteed: false,
      }));
    }, timeoutMs);
  });
  try {
    return await Promise.race([promise, timeout]);
  } finally {
    if (timer !== null) clearTimeout(timer);
  }
}

function gatewayLogFacts(log, expected) {
  const metadata = log && typeof log.metadata === "object" && log.metadata ? log.metadata : {};
  const metadataVerified = Object.entries(expected.metadata).every(([key, value]) => String(metadata[key]) === String(value));
  const statusCode = Number(log?.status_code);
  const successStatus = Number.isFinite(statusCode) && statusCode >= 200 && statusCode < 300;
  const failureStatus = Number.isFinite(statusCode) && statusCode >= 400;
  const verified = Boolean(
    log
      && log.id === expected.logId
      && log.provider === "workers-ai"
      && log.model === expected.model
      && log.success === expected.success
      && (expected.success ? successStatus : failureStatus)
      && metadataVerified,
  );
  if (!verified) {
    throw new GatewayFault("gateway_log_readback_unverified", 503, "AI Gateway log readback did not match provider, model, outcome, and correlation metadata.");
  }
  return {
    attempt_index: expected.attemptIndex,
    gateway_log_id: expected.logId,
    provider: log.provider,
    model: log.model,
    success: log.success === true,
    gateway_log_readback_verified: true,
    metadata_correlation_verified: true,
    metadata: {
      request_id: String(metadata.request_id),
      trace_id: String(metadata.trace_id),
      attempt_index: Number(metadata.attempt_index),
      verification_probe: String(metadata.verification_probe),
    },
    failure_reason: expected.failureReason || "none",
    cancellation_requested: expected.cancellationRequested === true,
    cancellation_guaranteed: false,
  };
}

function gatewayLogShapeComplete(log) {
  return Boolean(
    log
      && typeof log.id === "string"
      && typeof log.provider === "string"
      && typeof log.model === "string"
      && typeof log.success === "boolean"
      && Number.isFinite(Number(log.status_code))
      && log.metadata
      && typeof log.metadata === "object",
  );
}

async function readGatewayLog(env, expected) {
  if (!safeOptionalLogId(expected.logId)) {
    throw new GatewayFault("gateway_log_id_missing", 503, "The Workers AI binding did not expose a fresh AI Gateway log ID.");
  }
  const gateway = env.AI.gateway(env.AI_GATEWAY_ID);
  const deadline = Date.now() + GATEWAY_LOG_READBACK_TIMEOUT_MS;
  let lastError = null;
  while (Date.now() <= deadline) {
    let log = null;
    try {
      const remaining = Math.max(1, deadline - Date.now());
      log = await raceReadbackDeadline(Promise.resolve().then(() => gateway.getLog(expected.logId)), remaining);
      return gatewayLogFacts(log, expected);
    } catch (error) {
      if (error instanceof GatewayFault && error.code === "gateway_log_readback_unverified" && gatewayLogShapeComplete(log)) throw error;
      lastError = error;
      if (Date.now() + GATEWAY_LOG_POLL_MS > deadline) break;
      await delay(GATEWAY_LOG_POLL_MS);
    }
  }
  if (lastError instanceof GatewayFault && lastError.code === "gateway_log_readback_unverified") throw lastError;
  throw new GatewayFault("gateway_log_readback_unavailable", 503, "AI Gateway log readback was unavailable within the bounded deadline.");
}

async function runNonStreamAttempt(env, model, input, context, attemptIndex, probe) {
  const timeoutMs = attemptTimeoutMs(env);
  const abortController = new AbortController();
  const metadata = gatewayMetadata(context, attemptIndex, probe);
  const previousLogId = env.AI.aiGatewayLogId;
  let result;
  let fault = null;
  try {
    result = await raceDeadline(
      Promise.resolve().then(() => env.AI.run(model, input, providerOptions(env, context, attemptIndex, probe, abortController.signal, timeoutMs))),
      abortController,
      timeoutMs,
    );
  } catch (error) {
    fault = error instanceof GatewayFault
      ? error
      : new GatewayFault("provider_generation_failed", 502, "The provider attempt failed without exposing provider details.");
  }
  const logId = env.AI.aiGatewayLogId;
  if (!safeOptionalLogId(logId) || logId === previousLogId) {
    return {
      ok: false,
      fatal: true,
      reasonCode: "gateway_log_id_missing",
      fault: new GatewayFault("gateway_log_id_missing", 503, "The Workers AI binding did not expose a fresh AI Gateway log ID."),
      attempt: {
        attempt_index: attemptIndex,
        gateway_log_id: null,
        provider: "none",
        model,
        success: false,
        gateway_log_readback_verified: false,
        metadata_correlation_verified: false,
        metadata,
        failure_reason: fault?.code || "gateway_log_id_missing",
        cancellation_requested: fault?.facts?.cancellation_requested === true,
        cancellation_guaranteed: false,
      },
    };
  }
  const expectedSuccess = fault === null;
  let attempt;
  try {
    attempt = await readGatewayLog(env, {
      logId,
      model,
      success: expectedSuccess,
      metadata,
      attemptIndex,
      failureReason: fault?.code || "none",
      cancellationRequested: fault?.facts?.cancellation_requested === true,
    });
  } catch (logError) {
    return { ok: false, fatal: true, reasonCode: logError.code, fault: logError, attempt: null };
  }
  if (fault) {
    return { ok: false, fatal: false, reasonCode: fault.code, fault, attempt };
  }
  const content = typeof result?.response === "string" ? result.response.trim() : "";
  if (!content) {
    return {
      ok: false,
      fatal: false,
      reasonCode: "provider_returned_empty_content",
      fault: new GatewayFault("provider_returned_empty_content", 502, "The provider returned no bounded text completion."),
      attempt,
    };
  }
  return { ok: true, result, content, attempt };
}

function fallbackModel(primaryModel) {
  return ALLOWED_MODELS.find((candidate) => candidate !== primaryModel) || null;
}

function traceCorrelation(context, attempt, evidenceRef) {
  return {
    input_trace_id: context.traceId,
    gateway_trace_id: attempt.metadata.trace_id,
    provider_trace_id: attempt.metadata.trace_id,
    evidence_trace_id: context.traceId,
    gateway_log_id: attempt.gateway_log_id,
    evidence_ref: evidenceRef,
    gateway_log_readback_verified: attempt.gateway_log_readback_verified,
    audit_readback_verified: true,
  };
}

function completionPayload({ context, model, content, usage, env, audit, selectedAttempt, providerCallCount, fallback }) {
  return {
    id: `chatcmpl_${context.requestId}`,
    object: "chat.completion",
    created: Math.floor(Date.now() / 1000),
    model,
    choices: [{ index: 0, message: { role: "assistant", content }, finish_reason: "stop" }],
    usage,
    contract_version: CONTRACT_VERSION,
    gateway_mode: env.GATEWAY_MODE || "cloudflare_workers_ai_live",
    provider: selectedAttempt.provider,
    provider_call_count: providerCallCount,
    live_provider_calls: true,
    direct_provider_calls: false,
    secret_output: false,
    gateway_log_readback_verified: true,
    gateway_log_id: selectedAttempt.gateway_log_id,
    audit_persisted: true,
    audit_readback_verified: true,
    evidence_ref: audit.evidenceRef,
    request_id: context.requestId,
    trace_id: context.traceId,
    trace_correlation: traceCorrelation(context, selectedAttempt, audit.evidenceRef),
    ...(fallback ? { fallback } : {}),
  };
}

async function providerFailureResponse(env, context, details) {
  const audit = await persistAudit(env, context, "llm.gateway.completion.failed", {
    outcome: "provider_failed",
    model: details.primaryModel,
    selected_model: details.selectedModel,
    verification_probe: details.probe,
    reason_code: details.reasonCode,
    provider_call_count: details.providerCallCount,
    guard_stage: "post_provider",
    stream: details.stream,
    fallback_used: details.providerCallCount > 1,
    fallback: details.fallback,
    live_provider_calls: true,
    gateway_attempts: details.attempts,
    gateway_log_readback_verified: details.attempts.length === details.providerCallCount && details.attempts.every((attempt) => attempt?.gateway_log_readback_verified),
    cancellation_requested: details.cancellationRequested === true,
  });
  const code = audit.persisted ? details.reasonCode : "audit_persistence_unavailable";
  const status = audit.persisted ? (details.status || 502) : 503;
  return json(errorPayload(code, context, audit.persisted
    ? "The bounded provider chain failed without exposing provider details."
    : "The provider boundary was reached but its audit row could not be persisted and read back.", {
    original_error: details.reasonCode,
    provider_call_count: details.providerCallCount,
    guard_stage: "post_provider",
    audit_persisted: audit.persisted,
    audit_readback_verified: audit.persisted,
    evidence_ref: audit.evidenceRef,
    live_provider_calls: true,
    cancellation_requested: details.cancellationRequested === true,
    cancellation_guaranteed: false,
  }), status, context);
}

function nextSseEvent(buffer) {
  const lfIndex = buffer.indexOf("\n\n");
  const crlfIndex = buffer.indexOf("\r\n\r\n");
  let index = -1;
  let delimiterLength = 0;
  if (lfIndex >= 0 && (crlfIndex < 0 || lfIndex < crlfIndex)) {
    index = lfIndex;
    delimiterLength = 2;
  } else if (crlfIndex >= 0) {
    index = crlfIndex;
    delimiterLength = 4;
  }
  if (index < 0) return null;
  return {
    body: buffer.slice(0, index),
    raw: buffer.slice(0, index + delimiterLength),
    rest: buffer.slice(index + delimiterLength),
  };
}

function validateSseEvent(eventBody) {
  const data = eventBody.split(/\r?\n/)
    .filter((line) => line.startsWith("data:"))
    .map((line) => line.slice(5).replace(/^ /, ""))
    .join("\n");
  if (!data) throw new GatewayFault("provider_stream_invalid_sse", 502, "The provider stream contained an SSE event without data.");
  if (data === "[DONE]") return { done: true, content: "", finishReason: null };
  let payload;
  try { payload = JSON.parse(data); } catch {
    throw new GatewayFault("provider_stream_invalid_json", 502, "The provider stream contained invalid JSON.");
  }
  if (!payload || payload.object !== "chat.completion.chunk" || !Array.isArray(payload.choices) || payload.choices.length === 0 || payload.terminal === true) {
    throw new GatewayFault("provider_stream_not_openai_chunk", 502, "The provider stream did not return OpenAI-compatible chat.completion.chunk frames.");
  }
  let content = "";
  let finishReason = null;
  for (const choice of payload.choices) {
    if (!choice || typeof choice !== "object" || !choice.delta || typeof choice.delta !== "object" || Object.hasOwn(choice, "message")) {
      throw new GatewayFault("provider_stream_not_openai_delta", 502, "The provider stream contained a non-delta completion frame.");
    }
    if (choice.delta.content !== undefined) {
      if (typeof choice.delta.content !== "string") {
        throw new GatewayFault("provider_stream_invalid_delta", 502, "The provider stream contained a non-text delta.");
      }
      content += choice.delta.content;
    }
    if (choice.finish_reason !== undefined && choice.finish_reason !== null) {
      if (
        typeof choice.finish_reason !== "string"
        || choice.finish_reason.length < 1
        || choice.finish_reason.length > 64
        || /[^A-Za-z0-9_.:-]/.test(choice.finish_reason)
        || finishReason !== null
      ) {
        throw new GatewayFault("provider_stream_invalid_finish_reason", 502, "The provider stream contained an invalid or repeated finish reason.");
      }
      finishReason = choice.finish_reason;
    }
  }
  return { done: false, content, finishReason };
}

async function readWithDeadline(reader, abortController, deadlineAt) {
  const remaining = deadlineAt - Date.now();
  if (remaining <= 0) {
    abortController.abort("provider stream deadline exceeded");
    throw new GatewayFault("provider_attempt_deadline_exceeded", 502, "The bounded provider stream exceeded its deadline.", { cancellation_requested: true, cancellation_guaranteed: false });
  }
  let timer = null;
  const timeout = new Promise((resolve, reject) => {
    timer = setTimeout(() => {
      abortController.abort("provider stream deadline exceeded");
      reject(new GatewayFault("provider_attempt_deadline_exceeded", 502, "The bounded provider stream exceeded its deadline.", { cancellation_requested: true, cancellation_guaranteed: false }));
    }, remaining);
  });
  try {
    return await Promise.race([reader.read(), timeout]);
  } finally {
    if (timer !== null) clearTimeout(timer);
  }
}

async function startStreamAttempt(env, model, input, context, probe) {
  const timeoutMs = attemptTimeoutMs(env);
  const deadlineAt = Date.now() + timeoutMs;
  const abortController = new AbortController();
  const previousLogId = env.AI.aiGatewayLogId;
  let providerStream;
  try {
    providerStream = await raceDeadline(
      Promise.resolve().then(() => env.AI.run(model, input, providerOptions(env, context, 1, probe, abortController.signal, timeoutMs))),
      abortController,
      timeoutMs,
    );
  } catch (error) {
    const fault = error instanceof GatewayFault ? error : new GatewayFault("provider_generation_failed", 502, "The provider stream could not be opened.");
    return { ok: false, fault, abortController, providerCallCount: 1, logId: env.AI.aiGatewayLogId };
  }
  const logId = env.AI.aiGatewayLogId;
  if (!safeOptionalLogId(logId) || logId === previousLogId) {
    return { ok: false, fault: new GatewayFault("gateway_log_id_missing", 503, "The Workers AI binding did not expose a fresh AI Gateway log ID."), abortController, providerCallCount: 1, logId: null };
  }
  if (!(providerStream instanceof ReadableStream)) {
    return { ok: false, fault: new GatewayFault("provider_stream_missing", 502, "The Workers AI binding did not return a provider ReadableStream."), abortController, providerCallCount: 1, logId };
  }
  return { ok: true, providerStream, abortController, deadlineAt, logId, metadata: gatewayMetadata(context, 1, probe) };
}

function providerStreamResponse(env, context, model, probe, started) {
  const encoder = new TextEncoder();
  const stream = new ReadableStream({
    async start(controller) {
      const reader = started.providerStream.getReader();
      const decoder = new TextDecoder("utf-8", { fatal: true });
      let buffer = "";
      let totalBytes = 0;
      let terminalRaw = null;
      let terminalSeen = false;
      let finishReason = null;
      let terminalMode = null;
      let content = "";
      let attempt = null;
      let fault = null;
      try {
        while (true) {
          const { done, value } = await readWithDeadline(reader, started.abortController, started.deadlineAt);
          if (done) break;
          if (!(value instanceof Uint8Array)) throw new GatewayFault("provider_stream_invalid_chunk", 502, "The provider stream emitted an invalid binary chunk.");
          totalBytes += value.byteLength;
          if (totalBytes > MAX_STREAM_BYTES) throw new GatewayFault("provider_stream_limit_exceeded", 502, "The provider stream exceeded the bounded response limit.");
          buffer += decoder.decode(value, { stream: true });
          if (new TextEncoder().encode(buffer).byteLength > MAX_STREAM_FRAME_BYTES && !nextSseEvent(buffer)) {
            throw new GatewayFault("provider_stream_frame_limit_exceeded", 502, "The provider stream contained an oversized SSE frame.");
          }
          while (true) {
            const event = nextSseEvent(buffer);
            if (!event) break;
            buffer = event.rest;
            if (new TextEncoder().encode(event.raw).byteLength > MAX_STREAM_FRAME_BYTES) {
              throw new GatewayFault("provider_stream_frame_limit_exceeded", 502, "The provider stream contained an oversized SSE frame.");
            }
            const validated = validateSseEvent(event.body);
            if (terminalSeen) throw new GatewayFault("provider_stream_data_after_done", 502, "The provider stream emitted data after its terminal marker.");
            if (validated.done) {
              terminalSeen = true;
              terminalRaw = "data: [DONE]\n\n";
              terminalMode = "provider_done_marker";
            } else {
              if (finishReason !== null) {
                throw new GatewayFault("provider_stream_data_after_finish", 502, "The provider stream emitted data after its finish reason.");
              }
              content += validated.content;
              controller.enqueue(encoder.encode(event.raw));
              if (validated.finishReason !== null) finishReason = validated.finishReason;
            }
          }
        }
        buffer += decoder.decode();
        if (buffer.trim() !== "") throw new GatewayFault("provider_stream_incomplete_frame", 502, "The provider stream ended with an incomplete SSE frame.");
        if (!terminalSeen) {
          if (finishReason === null) {
            throw new GatewayFault("provider_stream_done_missing", 502, "The provider stream ended without [DONE] or an explicit finish reason.");
          }
          terminalRaw = "data: [DONE]\n\n";
          terminalMode = "finish_reason_eof";
        }
        if (!terminalRaw || !terminalMode) throw new GatewayFault("provider_stream_done_missing", 502, "The provider stream has no verified terminal marker.");
        canonicalProbeContent(content, probe);
        attempt = await readGatewayLog(env, {
          logId: started.logId,
          model,
          success: true,
          metadata: started.metadata,
          attemptIndex: 1,
          failureReason: "none",
          cancellationRequested: false,
        });
        const audit = await persistAudit(env, context, "llm.gateway.completion.succeeded", {
          outcome: "completed",
          model,
          selected_model: model,
          verification_probe: probe,
          reason_code: "primary_completed",
          provider_call_count: 1,
          guard_stage: "post_provider",
          stream: true,
          fallback_used: false,
          semantic_probe_verified: probe === "hosted_stream_parity",
          provider_stream_terminal_mode: terminalMode,
          provider_finish_reason: finishReason,
          live_provider_calls: true,
          gateway_attempts: [attempt],
          gateway_log_readback_verified: true,
        });
        if (!audit.persisted) throw new GatewayFault("audit_persistence_unavailable", 503, "The provider stream completed but its audit row could not be persisted and read back.");
        controller.enqueue(encoder.encode(terminalRaw));
        controller.close();
      } catch (error) {
        fault = error instanceof GatewayFault ? error : new GatewayFault("provider_stream_failed", 502, "The provider stream failed closed.");
        started.abortController.abort("provider stream failed closed");
        try { await reader.cancel("provider stream failed closed"); } catch { /* best effort */ }
        await persistAudit(env, context, "llm.gateway.completion.failed", {
          outcome: "provider_failed",
          model,
          selected_model: model,
          verification_probe: probe,
          reason_code: fault.code,
          provider_call_count: 1,
          guard_stage: "post_provider",
          stream: true,
          fallback_used: false,
          live_provider_calls: true,
          gateway_attempts: attempt ? [attempt] : [],
          gateway_log_readback_verified: false,
          cancellation_requested: true,
        });
        controller.error(new Error(fault.code));
      } finally {
        reader.releaseLock();
      }
    },
  });
  return new Response(stream, {
    status: 200,
    headers: baseHeaders(context, {
      "content-type": "text/event-stream; charset=utf-8",
      "x-accel-buffering": "no",
    }),
  });
}

async function handleNonStream(env, context, model, input, verification) {
  const attempts = [];
  const primary = await runNonStreamAttempt(env, model, input, context, 1, verification.probe);
  if (primary.attempt) attempts.push(primary.attempt);
  if (primary.fatal) {
    return providerFailureResponse(env, context, {
      primaryModel: model,
      selectedModel: model,
      probe: verification.probe,
      reasonCode: primary.reasonCode,
      providerCallCount: 1,
      stream: false,
      attempts,
      cancellationRequested: primary.fault?.facts?.cancellation_requested === true,
      status: primary.fault?.status,
    });
  }

  let selectedModel = model;
  let selected = primary;
  let fallback = null;
  const forcedFallback = verification.probe === "bounded_fallback";
  if (!primary.ok || forcedFallback) {
    const selectedFallbackModel = fallbackModel(model);
    if (!selectedFallbackModel) {
      return providerFailureResponse(env, context, {
        primaryModel: model,
        selectedModel: model,
        probe: verification.probe,
        reasonCode: primary.reasonCode || "fallback_target_unavailable",
        providerCallCount: 1,
        stream: false,
        attempts,
      });
    }
    const fallbackReason = primary.ok
      ? "verification_probe_forced_primary_rejection_after_provider_response"
      : primary.reasonCode;
    const fallbackAttempt = await runNonStreamAttempt(env, selectedFallbackModel, input, context, 2, verification.probe);
    if (fallbackAttempt.attempt) attempts.push(fallbackAttempt.attempt);
    if (!fallbackAttempt.ok) {
      return providerFailureResponse(env, context, {
        primaryModel: model,
        selectedModel: selectedFallbackModel,
        probe: verification.probe,
        reasonCode: fallbackAttempt.reasonCode || "provider_generation_failed",
        providerCallCount: 2,
        stream: false,
        attempts,
        cancellationRequested: fallbackAttempt.fault?.facts?.cancellation_requested === true,
        status: fallbackAttempt.fault?.status,
      });
    }
    selectedModel = selectedFallbackModel;
    selected = fallbackAttempt;
    fallback = {
      used: true,
      bounded: true,
      index: 1,
      provider_attempt_count: 2,
      reason_code: fallbackReason,
      primary_model: model,
      selected_model: selectedFallbackModel,
      audit_persisted: false,
    };
  }

  let content;
  try {
    content = canonicalProbeContent(selected.content, verification.probe);
  } catch (error) {
    const fault = error instanceof GatewayFault ? error : new GatewayFault("provider_generation_failed", 502, "Provider output is invalid.");
    return providerFailureResponse(env, context, {
      primaryModel: model,
      selectedModel,
      probe: verification.probe,
      reasonCode: fault.code,
      providerCallCount: attempts.length,
      stream: false,
      attempts,
      status: fault.status,
    });
  }

  const audit = await persistAudit(env, context, "llm.gateway.completion.succeeded", {
    outcome: "completed",
    model,
    selected_model: selectedModel,
    verification_probe: verification.probe,
    reason_code: fallback?.reason_code || "primary_completed",
    provider_call_count: attempts.length,
    guard_stage: "post_provider",
    stream: false,
    fallback_used: Boolean(fallback),
    fallback,
    semantic_probe_verified: verification.probe === "hosted_stream_parity",
    live_provider_calls: true,
    gateway_attempts: attempts,
    gateway_log_readback_verified: attempts.length > 0 && attempts.every((attempt) => attempt.gateway_log_readback_verified),
  });
  if (!audit.persisted) {
    return json(errorPayload("audit_persistence_unavailable", context, "The provider completed but its audit row could not be persisted and read back.", {
      provider_call_count: attempts.length,
      guard_stage: "post_provider",
      live_provider_calls: true,
    }), 503, context);
  }
  if (fallback) fallback.audit_persisted = true;
  const completion = completionPayload({
    context,
    model: selectedModel,
    content,
    usage: usagePayload(selected.result),
    env,
    audit,
    selectedAttempt: selected.attempt,
    providerCallCount: attempts.length,
    fallback,
  });
  return json(completion, 200, context);
}

async function handleChatCompletion(request, env, context) {
  if (!hasAiBinding(env) || !env.GATEWAY_AUTH_TOKEN || !validGatewayId(env.AI_GATEWAY_ID)) {
    return json(errorPayload("gateway_configuration_unavailable", context, "The AI binding, explicit AI Gateway ID, or gateway authentication is unavailable."), 503, context);
  }
  const suppliedToken = request.headers.get(AUTH_HEADER) || "";
  if (!(await secureEqual(suppliedToken, env.GATEWAY_AUTH_TOKEN))) {
    return auditedGuard(env, context, new GatewayFault("gateway_authentication_required", 401, "Gateway authentication failed."));
  }
  if (!context.valid) {
    return auditedGuard(env, context, new GatewayFault("invalid_traceparent", 422, "traceparent must be a valid W3C version-00 context."));
  }

  let body;
  try { body = await readJson(request); } catch (error) {
    return auditedGuard(env, context, error instanceof GatewayFault ? error : new GatewayFault("invalid_request", 422, "The request is invalid."));
  }
  if (directProviderBypassRequested(body)) {
    return auditedGuard(env, context, new GatewayFault("direct_provider_bypass_forbidden", 403, "Direct provider URLs and credentials are forbidden at the gateway boundary."));
  }
  const model = String(body.model || "");
  if (!ALLOWED_MODEL_SET.has(model)) {
    return auditedGuard(env, context, new GatewayFault("model_not_allowed", 403, "The requested model is outside the hosted allowlist."));
  }

  let validated;
  let verification;
  try {
    validated = validateMessages(body.messages);
    if (body.stream !== undefined && typeof body.stream !== "boolean") throw new GatewayFault("invalid_stream_flag", 422, "stream must be a JSON boolean.");
    verification = validateMetadata(body, context, request);
  } catch (error) {
    return auditedGuard(env, context, error instanceof GatewayFault ? error : new GatewayFault("invalid_request", 422, "The request is invalid."));
  }
  if (!hasAuditBinding(env)) {
    return json(errorPayload("audit_persistence_unavailable", context, "The D1 audit binding is required before any provider call."), 503, context);
  }

  const requestedTokens = Number(body.max_tokens ?? MAX_OUTPUT_TOKENS);
  const maxTokens = Math.max(1, Math.min(Number.isFinite(requestedTokens) ? Math.floor(requestedTokens) : MAX_OUTPUT_TOKENS, MAX_OUTPUT_TOKENS));
  const requestedTemperature = Number(body.temperature ?? 0.3);
  const temperature = Math.max(0, Math.min(Number.isFinite(requestedTemperature) ? requestedTemperature : 0.3, 1));
  const streamRequested = body.stream === true;
  const input = providerInput(validated.messages, maxTokens, temperature, streamRequested);
  if (!streamRequested) return handleNonStream(env, context, model, input, verification);

  const started = await startStreamAttempt(env, model, input, context, verification.probe);
  if (!started.ok) {
    return providerFailureResponse(env, context, {
      primaryModel: model,
      selectedModel: model,
      probe: verification.probe,
      reasonCode: started.fault.code,
      providerCallCount: 1,
      stream: true,
      attempts: [],
      cancellationRequested: started.fault.facts?.cancellation_requested === true,
      status: started.fault.status,
    });
  }
  return providerStreamResponse(env, context, model, verification.probe, started);
}

async function handleEvidenceReadback(request, env, context, url) {
  if (!hasAiBinding(env) || !hasAuditBinding(env) || !env.GATEWAY_AUTH_TOKEN || !validGatewayId(env.AI_GATEWAY_ID)) {
    return json(errorPayload("gateway_configuration_unavailable", context, "Independent evidence readback is not configured."), 503, context);
  }
  const token = request.headers.get(AUTH_HEADER) || "";
  if (!(await secureEqual(token, env.GATEWAY_AUTH_TOKEN))) {
    return json(errorPayload("gateway_authentication_required", context, "Gateway authentication failed."), 401, context);
  }
  const requestId = url.searchParams.get("request_id") || "";
  const traceId = url.searchParams.get("trace_id") || "";
  if (!SAFE_REQUEST_ID_PATTERN.test(requestId) || !TRACE_ID_PATTERN.test(traceId) || [...url.searchParams.keys()].some((key) => !["request_id", "trace_id"].includes(key))) {
    return json(errorPayload("invalid_evidence_query", context, "Evidence readback requires one bounded request_id and trace_id."), 422, context);
  }
  const row = await readAuditByTrace(env, traceId);
  if (!row || row.trace_id !== traceId || typeof row.details_json !== "string") {
    return json(errorPayload("evidence_not_found", context, "No persisted audit evidence was found for the requested trace."), 404, context);
  }
  let details;
  try { details = JSON.parse(row.details_json); } catch {
    return json(errorPayload("audit_readback_invalid", context, "The persisted audit evidence could not be decoded."), 503, context);
  }
  if (details.request_id !== requestId || details.trace_id !== traceId || !Array.isArray(details.gateway_attempts)) {
    return json(errorPayload("audit_readback_mismatch", context, "The persisted audit evidence does not match the requested correlation."), 503, context);
  }
  const expectedCount = Number(details.provider_call_count);
  if (!Number.isInteger(expectedCount) || expectedCount < 0 || expectedCount > 2 || details.gateway_attempts.length !== expectedCount) {
    return json(errorPayload("audit_provider_count_mismatch", context, "The persisted provider attempt count is inconsistent."), 503, context);
  }
  const verifiedAttempts = [];
  try {
    for (const attempt of details.gateway_attempts) {
      verifiedAttempts.push(await readGatewayLog(env, {
        logId: attempt.gateway_log_id,
        model: attempt.model,
        success: attempt.success === true,
        metadata: attempt.metadata,
        attemptIndex: attempt.attempt_index,
        failureReason: attempt.failure_reason,
        cancellationRequested: attempt.cancellation_requested === true,
      }));
    }
  } catch (error) {
    const fault = error instanceof GatewayFault ? error : new GatewayFault("gateway_log_readback_unverified", 503, "Independent AI Gateway log readback failed.");
    return json(errorPayload(fault.code, context, fault.note, { provider_call_count: expectedCount, guard_stage: expectedCount > 0 ? "post_provider" : "pre_provider" }), fault.status, context);
  }
  const gatewayReadbackRequired = expectedCount > 0;
  return json({
    contract_version: EVIDENCE_CONTRACT_VERSION,
    status: "verified",
    request_id: requestId,
    trace_id: traceId,
    source_commit_sha: env.SOURCE_COMMIT_SHA || null,
    source_archive_sha256: env.SOURCE_ARCHIVE_SHA256 || null,
    audit_persisted: true,
    audit_readback_verified: true,
    evidence_ref: `d1_audit:${row.id}`,
    provider_call_count: expectedCount,
    stream: details.stream === true,
    semantic_probe_verified: details.semantic_probe_verified === true,
    provider_stream_terminal_mode: details.provider_stream_terminal_mode,
    provider_finish_reason: details.provider_finish_reason,
    reason_code: details.reason_code,
    fallback: details.fallback,
    gateway_log_readback: {
      required: gatewayReadbackRequired,
      verified: gatewayReadbackRequired ? verifiedAttempts.length === expectedCount : false,
      ai_gateway_id: env.AI_GATEWAY_ID,
    },
    gateway_attempts: verifiedAttempts,
    live_provider_calls: expectedCount > 0,
    direct_provider_calls: false,
    secret_output: false,
  }, 200, context);
}

function verificationCapabilities(configured) {
  return {
    hosted_stream_parity: {
      contract_version: "llm-hosted-stream-parity-probe-v1",
      configured,
      verified: false,
      audit_persisted: false,
      gateway_log_readback_verified: false,
      provider_readable_stream_required: true,
      max_provider_calls_per_request: 1,
    },
    bounded_fallback: {
      contract_version: "llm-hosted-fallback-probe-v1",
      configured,
      verified: false,
      audit_persisted: false,
      gateway_log_readback_verified: false,
      failure_injection: "post_provider_response_verification_rejection",
      max_provider_calls: 2,
    },
    trace_correlation: {
      contract_version: "llm-hosted-trace-correlation-probe-v1",
      configured,
      verified: false,
      audit_persisted: false,
      gateway_log_readback_verified: false,
      provider_correlation_configured: configured,
      evidence_correlation_configured: configured,
      max_provider_calls: 1,
    },
  };
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const requestId = safeRequestId(request.headers.get("x-request-id"));
    const context = traceContext(request, requestId);
    const sourceConfigured = /^[0-9a-f]{40}$/.test(env.SOURCE_COMMIT_SHA || "") && /^[0-9a-f]{64}$/.test(env.SOURCE_ARCHIVE_SHA256 || "");
    const configured = Boolean(
      hasAiBinding(env)
      && env.GATEWAY_AUTH_TOKEN
      && validGatewayId(env.AI_GATEWAY_ID)
      && hasAuditBinding(env)
      && sourceConfigured,
    );

    if (request.method === "GET" && url.pathname === "/api/v1/health") {
      return json({
        contract_version: CONTRACT_VERSION,
        status: configured ? "healthy" : "degraded",
        service: "llm-gateway",
        provider: "cloudflare-workers-ai",
        mode: env.GATEWAY_MODE || "cloudflare_workers_ai_live",
        source_commit_sha: env.SOURCE_COMMIT_SHA || null,
        source_archive_sha256: env.SOURCE_ARCHIVE_SHA256 || null,
        ai_binding_configured: hasAiBinding(env),
        ai_gateway_configured: validGatewayId(env.AI_GATEWAY_ID),
        gateway_auth_configured: Boolean(env.GATEWAY_AUTH_TOKEN),
        audit_binding_configured: hasAuditBinding(env),
        source_binding_configured: sourceConfigured,
        provider_attempt_timeout_ms: attemptTimeoutMs(env),
        auth_required: true,
        live_provider_calls: false,
        live_provider_calls_available: configured,
        direct_provider_calls: false,
        secret_output: false,
        verification_capabilities: verificationCapabilities(configured),
      }, configured ? 200 : 503, context);
    }

    if (request.method === "GET" && url.pathname === "/api/v1/providers/status") {
      return json({
        contract_version: "llm-provider-status-v1",
        status: configured ? "configured" : "blocked",
        mode: env.GATEWAY_MODE || "cloudflare_workers_ai_live",
        source_commit_sha: env.SOURCE_COMMIT_SHA || null,
        source_archive_sha256: env.SOURCE_ARCHIVE_SHA256 || null,
        live_provider_calls: false,
        live_provider_calls_available: configured,
        live_verified: false,
        policy: {
          rotation_backoff_seconds: PROVIDER_ROTATION_BACKOFF_SECONDS,
          reset_after_seconds: PROVIDER_RESET_AFTER_SECONDS,
          never_break_budget: true,
          external_provider_calls_disabled_by_default: !configured,
          requires_request_metadata: "metadata.live_provider_calls_allowed=true",
          requires_owner_environment_gate: "GATEWAY_AUTH_TOKEN configured",
        },
        providers: [{
          provider: "cloudflare_workers_ai",
          status: configured ? "configured" : "blocked",
          live_verified: false,
          live_provider_calls: false,
          live_provider_calls_available: configured,
          model_count_visible: ALLOWED_MODELS.length,
          configured_models: ALLOWED_MODELS,
          visible_models_sample: ALLOWED_MODELS,
          backoff_seconds: PROVIDER_ROTATION_BACKOFF_SECONDS,
          reset_after_seconds: PROVIDER_RESET_AFTER_SECONDS,
          gateway_only: true,
          direct_provider_calls: false,
          secret_output: false,
        }],
        direct_provider_calls: false,
        secret_output: false,
      }, configured ? 200 : 503, context);
    }

    if (request.method === "GET" && url.pathname === "/v1/models") {
      return json({
        object: "list",
        data: ALLOWED_MODELS.map((id) => ({ id, object: "model", owned_by: "cloudflare" })),
        contract_version: CONTRACT_VERSION,
        live_provider_calls: false,
        direct_provider_calls: false,
        secret_output: false,
      }, 200, context);
    }

    if (request.method === "POST" && url.pathname === "/v1/chat/completions") {
      return handleChatCompletion(request, env, context);
    }

    if (request.method === "GET" && url.pathname === "/api/v1/evidence") {
      return handleEvidenceReadback(request, env, context, url);
    }

    return json(errorPayload("route_not_found", context, "The requested gateway route does not exist."), 404, context);
  },
};

import assert from "node:assert/strict";
import test from "node:test";

import worker from "../src/index.js";

const gatewayToken = "unit-test-gateway-token";
const gatewayId = "cloud-superbrain-llm-gateway-preview";
const primaryModel = "@cf/meta/llama-3.1-8b-instruct-fast";
const fallbackModel = "@cf/qwen/qwen2.5-coder-32b-instruct";

function auditDb({ failWrite = false, failRead = false } = {}) {
  const rows = new Map();
  const writes = [];
  return {
    rows,
    writes,
    prepare(sql) {
      return {
        bind(...values) {
          return {
            async run() {
              assert.match(sql, /^INSERT INTO audit_events/);
              if (failWrite) return { success: false };
              const [id, eventType, traceId, subjectId, detailsJson, createdAt] = values;
              const row = { id, event_type: eventType, trace_id: traceId, subject_id: subjectId, details_json: detailsJson, created_at: createdAt };
              rows.set(id, row);
              writes.push(row);
              return { success: true };
            },
            async first() {
              if (failRead) return null;
              if (/WHERE id = \?/.test(sql)) return rows.get(values[0]) || null;
              if (/WHERE trace_id = \?/.test(sql)) {
                const traceId = values[0];
                return [...rows.values()]
                  .filter((row) => row.trace_id === traceId)
                  .sort((left, right) => right.created_at.localeCompare(left.created_at))[0] || null;
              }
              throw new Error(`unexpected D1 read: ${sql}`);
            },
          };
        },
      };
    },
  };
}

function openAiSse(content = "verified") {
  const base = { id: "chatcmpl-provider-stream", object: "chat.completion.chunk", created: 1_788_000_000, model: primaryModel };
  return [
    `data: ${JSON.stringify({ ...base, choices: [{ index: 0, delta: { role: "assistant" }, finish_reason: null }] })}\n\n`,
    `data: ${JSON.stringify({ ...base, choices: [{ index: 0, delta: { content }, finish_reason: null }] })}\n\n`,
    `data: ${JSON.stringify({ ...base, choices: [{ index: 0, delta: {}, finish_reason: "stop" }] })}\n\n`,
    "data: [DONE]\n\n",
  ];
}

function openAiSseWithFinishReasonEof(content = "verified") {
  return openAiSse(content).slice(0, -1);
}

function streamFrom(parts, { failAfter = null } = {}) {
  const encoder = new TextEncoder();
  return new ReadableStream({
    start(controller) {
      for (const [index, part] of parts.entries()) {
        if (failAfter === index) {
          controller.error(new Error("redacted upstream stream failure"));
          return;
        }
        controller.enqueue(typeof part === "string" ? encoder.encode(part) : part);
      }
      controller.close();
    },
  });
}

function aiBinding(plans = []) {
  const calls = [];
  const logs = new Map();
  const getLogCalls = [];
  const AI = {
    aiGatewayLogId: null,
    calls,
    logs,
    getLogCalls,
    async run(model, input, options) {
      const index = calls.length;
      const plan = plans[index] || {};
      const logId = plan.logId || `gateway-log-${index + 1}`;
      calls.push({ model, input, options, logId });
      AI.aiGatewayLogId = plan.omitLogId ? null : logId;
      const metadata = options?.gateway?.metadata || {};
      logs.set(logId, {
        id: logId,
        provider: plan.provider || "workers-ai",
        model: plan.logModel || model,
        status_code: plan.statusCode ?? (plan.error || plan.never ? 503 : 200),
        success: plan.logSuccess ?? !(plan.error || plan.never),
        cached: false,
        metadata: plan.logMetadata || metadata,
        request_size: 64,
        request_head_complete: true,
        response_size: 64,
        response_head_complete: true,
        duration: 10,
        path: "/ai/run",
        created_at: new Date(),
      });
      if (plan.never) {
        return new Promise((resolve, reject) => {
          options.signal.addEventListener("abort", () => reject(new DOMException("aborted", "AbortError")), { once: true });
        });
      }
      if (plan.error) throw new Error("redacted provider failure");
      if (input.stream === true) return plan.stream || streamFrom(openAiSse(plan.content));
      return plan.result || { response: plan.content || "safe completion", usage: { prompt_tokens: 2, completion_tokens: 1, total_tokens: 3 } };
    },
    gateway(id) {
      assert.equal(id, gatewayId);
      return {
        async getLog(logId) {
          getLogCalls.push(logId);
          const log = logs.get(logId);
          if (!log) throw new Error("log not found");
          return log;
        },
      };
    },
  };
  return AI;
}

function runtimeEnv(AI = aiBinding(), options = {}) {
  return {
    AI,
    DB: options.DB === undefined ? auditDb() : options.DB,
    GATEWAY_AUTH_TOKEN: options.GATEWAY_AUTH_TOKEN ?? gatewayToken,
    AI_GATEWAY_ID: options.AI_GATEWAY_ID ?? gatewayId,
    PROVIDER_ATTEMPT_TIMEOUT_MS: options.PROVIDER_ATTEMPT_TIMEOUT_MS ?? "25000",
    GATEWAY_MODE: "cloudflare_workers_ai_live",
    SOURCE_COMMIT_SHA: "a".repeat(40),
    SOURCE_ARCHIVE_SHA256: "b".repeat(64),
  };
}

function chatRequest(body, { token = gatewayToken, headers = {}, rawBody = null } = {}) {
  const requestHeaders = new Headers({ "content-type": "application/json", ...headers });
  if (token !== null) requestHeaders.set("x-superbrain-gateway-token", token);
  return new Request("https://gateway.example/v1/chat/completions", {
    method: "POST",
    headers: requestHeaders,
    body: rawBody ?? JSON.stringify(body),
  });
}

function completionBody(overrides = {}) {
  return {
    model: primaryModel,
    messages: [{ role: "user", content: "Return exactly verified." }],
    max_tokens: 16,
    temperature: 0,
    stream: false,
    ...overrides,
  };
}

function responseTraceId(response) {
  return response.headers.get("traceparent").split("-")[1];
}

async function evidenceReadback(environment, requestId, traceId, token = gatewayToken) {
  const url = new URL("https://gateway.example/api/v1/evidence");
  url.searchParams.set("request_id", requestId);
  url.searchParams.set("trace_id", traceId);
  const headers = {};
  if (token !== null) headers["x-superbrain-gateway-token"] = token;
  return worker.fetch(new Request(url, { headers }), environment);
}

async function readSse(response) {
  const text = await response.text();
  const data = text.split(/\r?\n/).filter((line) => line.startsWith("data: ")).map((line) => line.slice(6));
  return { text, data, frames: data.filter((value) => value !== "[DONE]").map((value) => JSON.parse(value)) };
}

function assertGatewayOptions(call, attemptIndex, traceId, probe = "none") {
  assert.equal(call.options.gateway.id, gatewayId);
  assert.equal(call.options.gateway.skipCache, true);
  assert.equal(call.options.gateway.collectLog, true);
  assert.equal(call.options.gateway.retries.maxAttempts, 1);
  assert.equal(call.options.extraHeaders["cf-aig-collect-log-payload"], "false");
  assert.equal(call.options.gateway.metadata.trace_id, traceId);
  assert.equal(call.options.gateway.metadata.attempt_index, attemptIndex);
  assert.equal(call.options.gateway.metadata.verification_probe, probe);
  assert.ok(call.options.signal instanceof AbortSignal);
}

test("health advertises configuration only and never claims provider, log, or audit verification", async () => {
  const AI = aiBinding();
  const DB = auditDb();
  const response = await worker.fetch(new Request("https://gateway.example/api/v1/health", { headers: { "x-request-id": "health-test" } }), runtimeEnv(AI, { DB }));
  const payload = await response.json();
  assert.equal(response.status, 200);
  assert.equal(payload.status, "healthy");
  assert.equal(payload.ai_gateway_configured, true);
  assert.equal(payload.verification_capabilities.hosted_stream_parity.configured, true);
  assert.equal(payload.verification_capabilities.hosted_stream_parity.verified, false);
  assert.equal(payload.verification_capabilities.bounded_fallback.audit_persisted, false);
  assert.equal(payload.verification_capabilities.trace_correlation.gateway_log_readback_verified, false);
  assert.equal(payload.live_provider_calls, false);
  assert.equal(AI.calls.length, 0);
  assert.equal(AI.getLogCalls.length, 0);
  assert.equal(DB.writes.length, 0);
});

test("health degrades when the explicit AI Gateway ID or D1 binding is absent", async () => {
  for (const options of [{ AI_GATEWAY_ID: "" }, { DB: null }]) {
    const response = await worker.fetch(new Request("https://gateway.example/api/v1/health"), runtimeEnv(aiBinding(), options));
    const payload = await response.json();
    assert.equal(response.status, 503);
    assert.equal(payload.status, "degraded");
    assert.equal(payload.verification_capabilities.hosted_stream_parity.configured, false);
  }
});

test("the request stream is hard-limited without trusting Content-Length", async () => {
  const AI = aiBinding();
  const body = streamFrom([new Uint8Array(40_000), new Uint8Array(30_000)]);
  const response = await worker.fetch(new Request("https://gateway.example/v1/chat/completions", {
    method: "POST",
    headers: { "content-type": "application/json", "x-superbrain-gateway-token": gatewayToken, "x-request-id": "stream-body-limit-test" },
    body,
    duplex: "half",
  }), runtimeEnv(AI));
  const payload = await response.json();
  assert.equal(response.status, 422);
  assert.equal(payload.error, "request_too_large");
  assert.equal(payload.provider_call_count, 0);
  assert.equal(AI.calls.length, 0);
});

test("auth, 20,001-char budget, schema, policy, and bypass guards stay pre-provider and independently D1-readable", async () => {
  const AI = aiBinding();
  const DB = auditDb();
  const environment = runtimeEnv(AI, { DB });
  const cases = [
    { id: "missing-auth", token: null, body: completionBody(), status: 401, error: "gateway_authentication_required" },
    { id: "oversize", body: completionBody({ messages: [{ role: "user", content: "x".repeat(20_001) }] }), status: 422, error: "input_limit_exceeded" },
    { id: "schema", body: completionBody({ messages: [] }), status: 422, error: "invalid_messages" },
    { id: "policy", body: completionBody({ model: "provider/model" }), status: 403, error: "model_not_allowed" },
    { id: "bypass", body: completionBody({ provider_url: "https://provider.example" }), status: 403, error: "direct_provider_bypass_forbidden" },
  ];
  for (const entry of cases) {
    const response = await worker.fetch(chatRequest(entry.body, { token: entry.token === undefined ? gatewayToken : entry.token, headers: { "x-request-id": entry.id } }), environment);
    const payload = await response.json();
    assert.equal(response.status, entry.status);
    assert.equal(payload.error, entry.error);
    assert.equal(payload.provider_call_count, 0);
    assert.equal(payload.guard_stage, "pre_provider");
    const evidence = await evidenceReadback(environment, entry.id, payload.trace_id);
    const proof = await evidence.json();
    assert.equal(evidence.status, 200);
    assert.equal(proof.audit_readback_verified, true);
    assert.equal(proof.provider_call_count, 0);
    assert.deepEqual(proof.gateway_attempts, []);
    assert.equal(proof.gateway_log_readback.required, false);
  }
  assert.equal(AI.calls.length, 0);
  assert.equal(AI.getLogCalls.length, 0);
});

test("non-stream completion uses the actual gateway path and binds gateway-log plus D1 readback", async () => {
  const AI = aiBinding([{ content: "safe completion" }]);
  const DB = auditDb();
  const environment = runtimeEnv(AI, { DB });
  const traceId = "1".repeat(32);
  const response = await worker.fetch(chatRequest(completionBody({ max_tokens: 9999, temperature: 2 }), {
    headers: { "x-request-id": "nonstream-test", traceparent: `00-${traceId}-${"2".repeat(16)}-01` },
  }), environment);
  const payload = await response.json();
  assert.equal(response.status, 200);
  assert.equal(payload.object, "chat.completion");
  assert.equal(payload.choices[0].message.content, "safe completion");
  assert.equal(payload.gateway_log_readback_verified, true);
  assert.equal(payload.audit_readback_verified, true);
  assert.equal(AI.calls.length, 1);
  assert.equal(AI.calls[0].input.stream, false);
  assert.equal(AI.calls[0].input.max_tokens, 2048);
  assert.equal(AI.calls[0].input.temperature, 1);
  assertGatewayOptions(AI.calls[0], 1, traceId);
  assert.deepEqual(AI.getLogCalls, ["gateway-log-1"]);
  const evidence = await evidenceReadback(environment, "nonstream-test", traceId);
  const proof = await evidence.json();
  assert.equal(evidence.status, 200);
  assert.equal(proof.gateway_log_readback.required, true);
  assert.equal(proof.gateway_log_readback.verified, true);
  assert.equal(proof.gateway_attempts[0].gateway_log_id, "gateway-log-1");
  assert.equal(proof.gateway_attempts[0].metadata_correlation_verified, true);
  assert.doesNotMatch(DB.writes[0].details_json, /safe completion|Return exactly|unit-test-gateway-token/);
});

test("gateway-log model, provider, success, or metadata mismatch blocks completion before credit", async () => {
  const plans = [{ provider: "unexpected-provider" }, { logModel: fallbackModel }, { logSuccess: false }, { logMetadata: { trace_id: "wrong" } }];
  for (const plan of plans) {
    const response = await worker.fetch(chatRequest(completionBody()), runtimeEnv(aiBinding([plan])));
    const payload = await response.json();
    assert.equal(response.status, 503);
    assert.equal(payload.error, "gateway_log_readback_unverified");
    assert.equal(payload.choices, undefined);
  }
});

test("stream mode forwards only real provider chat.completion.chunk frames and withholds DONE until log plus D1 readback", async () => {
  const upstream = openAiSse("streamed completion");
  const AI = aiBinding([{ stream: streamFrom(upstream) }]);
  const DB = auditDb();
  const environment = runtimeEnv(AI, { DB });
  const response = await worker.fetch(chatRequest(completionBody({ stream: true }), { headers: { "x-request-id": "stream-test" } }), environment);
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type"), /^text\/event-stream/);
  const sse = await readSse(response);
  assert.deepEqual(sse.data, upstream.map((frame) => frame.match(/^data: (.*)\n\n$/s)[1]));
  assert.equal(sse.data.at(-1), "[DONE]");
  assert.ok(sse.frames.every((frame) => frame.object === "chat.completion.chunk"));
  assert.ok(sse.frames.every((frame) => frame.choices.every((choice) => choice.delta && !choice.message)));
  assert.equal(sse.frames.some((frame) => frame.terminal === true), false);
  assert.equal(AI.calls[0].input.stream, true);
  assertGatewayOptions(AI.calls[0], 1, responseTraceId(response));
  assert.equal(DB.writes.length, 1);
  const proofResponse = await evidenceReadback(environment, "stream-test", responseTraceId(response));
  const proof = await proofResponse.json();
  assert.equal(proofResponse.status, 200);
  assert.equal(proof.stream, true);
  assert.equal(proof.gateway_log_readback.verified, true);
  assert.equal(proof.audit_readback_verified, true);
  assert.equal(proof.provider_stream_terminal_mode, "provider_done_marker");
  assert.equal(proof.provider_finish_reason, "stop");
});

test("stream canonicalizes provider finish_reason EOF to one DONE after log plus D1 readback", async () => {
  const upstream = openAiSseWithFinishReasonEof("streamed completion");
  const AI = aiBinding([{ stream: streamFrom(upstream) }]);
  const DB = auditDb();
  const environment = runtimeEnv(AI, { DB });
  const response = await worker.fetch(chatRequest(completionBody({ stream: true }), { headers: { "x-request-id": "stream-finish-eof-test" } }), environment);
  const sse = await readSse(response);
  assert.deepEqual(sse.data.slice(0, -1), upstream.map((frame) => frame.match(/^data: (.*)\n\n$/s)[1]));
  assert.equal(sse.data.filter((value) => value === "[DONE]").length, 1);
  assert.equal(sse.data.at(-1), "[DONE]");
  assert.equal(DB.writes.length, 1);
  const proofResponse = await evidenceReadback(environment, "stream-finish-eof-test", responseTraceId(response));
  const proof = await proofResponse.json();
  assert.equal(proofResponse.status, 200);
  assert.equal(proof.provider_stream_terminal_mode, "finish_reason_eof");
  assert.equal(proof.provider_finish_reason, "stop");
  assert.equal(proof.gateway_log_readback.verified, true);
  assert.equal(proof.audit_readback_verified, true);
});

test("stream rejects synthetic full-completion frames, missing terminal evidence, and post-DONE frames without credit evidence", async () => {
  const fullCompletion = `data: ${JSON.stringify({ object: "chat.completion", choices: [{ message: { content: "fake" } }] })}\n\n`;
  const noTerminalEvidence = openAiSse("partial").slice(0, -2);
  const malformedStreams = [
    streamFrom([fullCompletion, "data: [DONE]\n\n"]),
    streamFrom(noTerminalEvidence),
    streamFrom([...openAiSse("done"), openAiSse("late")[0]]),
    streamFrom([...openAiSseWithFinishReasonEof("done"), openAiSse("late")[0]]),
  ];
  for (const [index, upstream] of malformedStreams.entries()) {
    const DB = auditDb();
    const response = await worker.fetch(chatRequest(completionBody({ stream: true }), { headers: { "x-request-id": `bad-stream-${index}` } }), runtimeEnv(aiBinding([{ stream: upstream }]), { DB }));
    await assert.rejects(response.text());
    assert.equal(DB.writes.some((row) => JSON.parse(row.details_json).outcome === "completed"), false);
  }
});

test("stream-parity probe preserves real frames while proving equivalent semantics through independent evidence", async () => {
  const semanticKey = "stream-parity-unit-test";
  const metadata = { verification_probe: "hosted_stream_parity", semantic_key: semanticKey };
  const AI = aiBinding([{ content: "Verified." }, { stream: streamFrom(openAiSse("verified!")) }]);
  const environment = runtimeEnv(AI);
  const nonStream = await worker.fetch(chatRequest(completionBody({ metadata }), { headers: { "x-request-id": "parity-json", "x-superbrain-semantic-key": semanticKey } }), environment);
  const nonStreamPayload = await nonStream.json();
  assert.equal(nonStreamPayload.choices[0].message.content, "verified");
  const stream = await worker.fetch(chatRequest(completionBody({ metadata, stream: true }), { headers: { "x-request-id": "parity-sse", "x-superbrain-semantic-key": semanticKey } }), environment);
  const sse = await readSse(stream);
  const streamedText = sse.frames.map((frame) => frame.choices[0]?.delta?.content || "").join("");
  assert.equal(streamedText.toLowerCase().replace(/[.!]+$/, ""), "verified");
  assert.equal(AI.calls.length, 2);
  assert.equal(AI.calls[0].input.stream, false);
  assert.equal(AI.calls[1].input.stream, true);
  for (const [requestId, traceId] of [["parity-json", responseTraceId(nonStream)], ["parity-sse", responseTraceId(stream)]]) {
    const proof = await (await evidenceReadback(environment, requestId, traceId)).json();
    assert.equal(proof.semantic_probe_verified, true);
    assert.equal(proof.gateway_log_readback.verified, true);
  }
});

test("forced fallback uses exactly two independently read gateway logs and an honest forced reason", async () => {
  const AI = aiBinding([{ content: "primary" }, { content: "fallback" }]);
  const environment = runtimeEnv(AI);
  const response = await worker.fetch(chatRequest(completionBody({ metadata: { verification_probe: "bounded_fallback", verification_probe_version: "llm-hosted-fallback-probe-v1" } }), {
    headers: { "x-request-id": "forced-fallback", "x-superbrain-verification-probe": "bounded-fallback-v1" },
  }), environment);
  const payload = await response.json();
  assert.equal(response.status, 200);
  assert.equal(payload.provider_call_count, 2);
  assert.equal(payload.fallback.reason_code, "verification_probe_forced_primary_rejection_after_provider_response");
  assert.equal(AI.calls.length, 2);
  assert.deepEqual(AI.getLogCalls, ["gateway-log-1", "gateway-log-2"]);
  const proof = await (await evidenceReadback(environment, "forced-fallback", responseTraceId(response))).json();
  assert.equal(proof.gateway_attempts.length, 2);
  assert.equal(proof.fallback.reason_code, payload.fallback.reason_code);
});

test("true primary failure never masquerades as forced rejection and remains bounded", async () => {
  const AI = aiBinding([{ error: true, logSuccess: false }, { content: "fallback recovered" }]);
  const response = await worker.fetch(chatRequest(completionBody({ metadata: { verification_probe: "bounded_fallback", verification_probe_version: "llm-hosted-fallback-probe-v1" } }), {
    headers: { "x-request-id": "true-primary-failure", "x-superbrain-verification-probe": "bounded-fallback-v1" },
  }), runtimeEnv(AI));
  const payload = await response.json();
  assert.equal(response.status, 200);
  assert.equal(payload.fallback.reason_code, "provider_generation_failed");
  assert.notEqual(payload.fallback.reason_code, "verification_probe_forced_primary_rejection_after_provider_response");
  assert.equal(AI.calls.length, 2);
});

test("per-attempt deadline aborts best-effort, stops at two, and reports non-guaranteed cancellation honestly", async () => {
  const AI = aiBinding([{ never: true }, { never: true }]);
  const response = await worker.fetch(chatRequest(completionBody()), runtimeEnv(AI, { PROVIDER_ATTEMPT_TIMEOUT_MS: "20" }));
  const payload = await response.json();
  assert.equal(response.status, 502);
  assert.equal(payload.error, "provider_attempt_deadline_exceeded");
  assert.equal(payload.provider_call_count, 2);
  assert.equal(payload.cancellation_requested, true);
  assert.equal(payload.cancellation_guaranteed, false);
  assert.equal(AI.calls.length, 2);
  assert.ok(AI.calls.every((call) => call.options.signal.aborted));
});

test("trace proof derives correlation from AI Gateway log metadata and D1 readback, not local UUID claims", async () => {
  const AI = aiBinding([{ content: "trace verified", logId: "real-gateway-log-id" }]);
  const environment = runtimeEnv(AI);
  const traceId = "c".repeat(32);
  const response = await worker.fetch(chatRequest(completionBody({ metadata: { verification_probe: "trace_correlation", trace_id: traceId } }), {
    headers: { "x-request-id": "trace-proof", traceparent: `00-${traceId}-${"d".repeat(16)}-01` },
  }), environment);
  const payload = await response.json();
  assert.equal(response.status, 200);
  assert.equal(payload.trace_correlation.gateway_log_id, "real-gateway-log-id");
  assert.equal(payload.trace_correlation.provider_trace_id, traceId);
  assert.equal(payload.trace_correlation.gateway_log_readback_verified, true);
  const proof = await (await evidenceReadback(environment, "trace-proof", traceId)).json();
  assert.equal(proof.gateway_attempts[0].gateway_log_id, "real-gateway-log-id");
  assert.equal(proof.gateway_attempts[0].metadata.trace_id, traceId);
  assert.equal(proof.gateway_attempts[0].metadata.request_id, "trace-proof");
  assert.equal(proof.audit_readback_verified, true);
});

test("D1 write/readback failure blocks non-stream completion and stream terminal", async () => {
  for (const DB of [auditDb({ failWrite: true }), auditDb({ failRead: true })]) {
    const response = await worker.fetch(chatRequest(completionBody()), runtimeEnv(aiBinding([{ content: "hidden" }]), { DB }));
    const payload = await response.json();
    assert.equal(response.status, 503);
    assert.equal(payload.error, "audit_persistence_unavailable");
    assert.equal(payload.choices, undefined);
    const stream = await worker.fetch(chatRequest(completionBody({ stream: true })), runtimeEnv(aiBinding([{ stream: streamFrom(openAiSse()) }]), { DB }));
    await assert.rejects(stream.text());
  }
});

test("independent evidence readback is authenticated, input-bounded, and never calls a provider", async () => {
  const AI = aiBinding();
  const environment = runtimeEnv(AI);
  const missingAuth = await evidenceReadback(environment, "request-1", "1".repeat(32), null);
  assert.equal(missingAuth.status, 401);
  const invalid = await worker.fetch(new Request("https://gateway.example/api/v1/evidence?request_id=x&trace_id=bad", { headers: { "x-superbrain-gateway-token": gatewayToken } }), environment);
  assert.equal(invalid.status, 422);
  assert.equal(AI.calls.length, 0);
});

test("route misses remain redacted and never touch AI Gateway, getLog, or D1", async () => {
  const AI = aiBinding();
  const DB = auditDb();
  const response = await worker.fetch(new Request("https://gateway.example/not-found"), runtimeEnv(AI, { DB }));
  const payload = await response.json();
  assert.equal(response.status, 404);
  assert.equal(payload.provider_call_count, 0);
  assert.equal(payload.secret_output, false);
  assert.equal(AI.calls.length, 0);
  assert.equal(AI.getLogCalls.length, 0);
  assert.equal(DB.writes.length, 0);
});

const CONTRACT_VERSION = "cloudflare-workers-ai-llm-gateway-v1";
const GATEWAY_SOURCE = "cloudflare-workers-ai-llm-gateway";
const AUTH_HEADER = "x-superbrain-gateway-token";
const MAX_BODY_BYTES = 64 * 1024;
const MAX_MESSAGES = 16;
const MAX_INPUT_CHARS = 20_000;
const MAX_OUTPUT_TOKENS = 2_048;
const ALLOWED_MODELS = new Set([
  "@cf/qwen/qwen2.5-coder-32b-instruct",
  "@cf/meta/llama-3.1-8b-instruct",
]);

function json(payload, status = 200, extraHeaders = {}) {
  return Response.json(payload, {
    status,
    headers: {
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
      "x-superbrain-source": GATEWAY_SOURCE,
      ...extraHeaders,
    },
  });
}

function errorPayload(code, requestId, note) {
  return {
    contract_version: CONTRACT_VERSION,
    status: "blocked",
    error: code,
    request_id: requestId,
    live_provider_calls: false,
    direct_provider_calls: false,
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

function validateMessages(value) {
  if (!Array.isArray(value) || value.length === 0 || value.length > MAX_MESSAGES) {
    throw new Error("invalid_messages");
  }
  let inputChars = 0;
  const messages = value.map((message) => {
    if (!message || typeof message !== "object") throw new Error("invalid_messages");
    const role = String(message.role || "");
    if (!new Set(["system", "user", "assistant"]).has(role)) throw new Error("invalid_message_role");
    if (typeof message.content !== "string") throw new Error("invalid_message_content");
    inputChars += message.content.length;
    return { role, content: message.content };
  });
  if (inputChars === 0 || inputChars > MAX_INPUT_CHARS) throw new Error("input_limit_exceeded");
  return messages;
}

function usagePayload(result) {
  const usage = result && typeof result.usage === "object" ? result.usage : {};
  const promptTokens = Number(usage.prompt_tokens || 0);
  const completionTokens = Number(usage.completion_tokens || 0);
  return {
    prompt_tokens: Number.isFinite(promptTokens) ? promptTokens : 0,
    completion_tokens: Number.isFinite(completionTokens) ? completionTokens : 0,
    total_tokens: Number.isFinite(Number(usage.total_tokens))
      ? Number(usage.total_tokens)
      : promptTokens + completionTokens,
  };
}

async function handleChatCompletion(request, env, requestId) {
  if (!env.AI || !env.GATEWAY_AUTH_TOKEN) {
    return json(errorPayload("gateway_configuration_unavailable", requestId, "The AI binding or gateway authentication is unavailable."), 503);
  }

  const suppliedToken = request.headers.get(AUTH_HEADER) || "";
  if (!(await secureEqual(suppliedToken, env.GATEWAY_AUTH_TOKEN))) {
    return json(errorPayload("gateway_authentication_required", requestId, "Gateway authentication failed."), 401);
  }

  let body;
  try {
    body = await readJson(request);
  } catch (error) {
    const code = error instanceof Error ? error.message : "invalid_request";
    const status = code === "request_too_large" ? 413 : 400;
    return json(errorPayload(code, requestId, "The request body does not satisfy the gateway contract."), status);
  }

  if (body.stream === true) {
    return json(errorPayload("stream_not_supported", requestId, "The hosted Workers AI slice accepts stream=false only."), 501);
  }

  const model = String(body.model || "");
  if (!ALLOWED_MODELS.has(model)) {
    return json(errorPayload("model_not_allowed", requestId, "The requested model is outside the free hosted allowlist."), 400);
  }

  let messages;
  try {
    messages = validateMessages(body.messages);
  } catch (error) {
    return json(errorPayload(error instanceof Error ? error.message : "invalid_messages", requestId, "The messages do not satisfy the gateway contract."), 400);
  }

  const requestedTokens = Number(body.max_tokens || MAX_OUTPUT_TOKENS);
  const maxTokens = Math.max(1, Math.min(Number.isFinite(requestedTokens) ? Math.floor(requestedTokens) : MAX_OUTPUT_TOKENS, MAX_OUTPUT_TOKENS));
  const requestedTemperature = Number(body.temperature ?? 0.3);
  const temperature = Math.max(0, Math.min(Number.isFinite(requestedTemperature) ? requestedTemperature : 0.3, 1));

  try {
    const result = await env.AI.run(model, {
      messages,
      max_tokens: maxTokens,
      temperature,
      stream: false,
    });
    const content = typeof result?.response === "string" ? result.response.trim() : "";
    if (!content) {
      return json(errorPayload("provider_returned_empty_content", requestId, "Workers AI returned no text content."), 502);
    }
    return json({
      id: `chatcmpl_${requestId}`,
      object: "chat.completion",
      created: Math.floor(Date.now() / 1000),
      model,
      choices: [{ index: 0, message: { role: "assistant", content }, finish_reason: "stop" }],
      usage: usagePayload(result),
      contract_version: CONTRACT_VERSION,
      gateway_mode: env.GATEWAY_MODE || "cloudflare_workers_ai_live",
      provider: "cloudflare-workers-ai",
      live_provider_calls: true,
      direct_provider_calls: false,
      secret_output: false,
      request_id: requestId,
    });
  } catch {
    return json(errorPayload("provider_generation_failed", requestId, "Workers AI generation failed without exposing provider details."), 502);
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const requestId = request.headers.get("x-request-id") || crypto.randomUUID();
    const configured = Boolean(env.AI && env.GATEWAY_AUTH_TOKEN);

    if (request.method === "GET" && url.pathname === "/api/v1/health") {
      return json({
        contract_version: CONTRACT_VERSION,
        status: configured ? "healthy" : "degraded",
        service: "llm-gateway",
        provider: "cloudflare-workers-ai",
        mode: env.GATEWAY_MODE || "cloudflare_workers_ai_live",
        source_commit_sha: env.SOURCE_COMMIT_SHA || null,
        source_archive_sha256: env.SOURCE_ARCHIVE_SHA256 || null,
        ai_binding_configured: Boolean(env.AI),
        gateway_auth_configured: Boolean(env.GATEWAY_AUTH_TOKEN),
        auth_required: true,
        live_provider_calls: false,
        live_provider_calls_available: configured,
        direct_provider_calls: false,
        secret_output: false,
      }, configured ? 200 : 503);
    }

    if (request.method === "GET" && url.pathname === "/v1/models") {
      return json({
        object: "list",
        data: [...ALLOWED_MODELS].map((id) => ({ id, object: "model", owned_by: "cloudflare" })),
        contract_version: CONTRACT_VERSION,
        live_provider_calls: false,
      });
    }

    if (request.method === "POST" && url.pathname === "/v1/chat/completions") {
      return handleChatCompletion(request, env, requestId);
    }

    return json(errorPayload("route_not_found", requestId, "The requested gateway route does not exist."), 404);
  },
};

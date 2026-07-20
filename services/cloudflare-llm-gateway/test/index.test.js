import assert from "node:assert/strict";
import test from "node:test";

import worker from "../src/index.js";

const gatewayToken = "unit-test-gateway-token";

function env(run) {
  return {
    AI: { run },
    GATEWAY_AUTH_TOKEN: gatewayToken,
    GATEWAY_MODE: "cloudflare_workers_ai_live",
  };
}

function chatRequest(body, token = gatewayToken) {
  return new Request("https://gateway.example/v1/chat/completions", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-superbrain-gateway-token": token,
    },
    body: JSON.stringify(body),
  });
}

test("health reports an authenticated Workers AI boundary without inference", async () => {
  let calls = 0;
  const response = await worker.fetch(
    new Request("https://gateway.example/api/v1/health"),
    env(async () => { calls += 1; }),
  );
  const payload = await response.json();
  assert.equal(response.status, 200);
  assert.equal(payload.status, "healthy");
  assert.equal(payload.live_provider_calls, false);
  assert.equal(payload.live_provider_calls_available, true);
  assert.equal(calls, 0);
});

test("chat completion requires the dedicated server-side gateway token", async () => {
  let calls = 0;
  const response = await worker.fetch(
    chatRequest({ model: "@cf/meta/llama-3.1-8b-instruct", messages: [{ role: "user", content: "test" }] }, "wrong"),
    env(async () => { calls += 1; }),
  );
  const payload = await response.json();
  assert.equal(response.status, 401);
  assert.equal(payload.error, "gateway_authentication_required");
  assert.equal(payload.secret_output, false);
  assert.equal(calls, 0);
});

test("chat completion invokes an allowlisted Workers AI model once", async () => {
  const calls = [];
  const response = await worker.fetch(
    chatRequest({
      model: "@cf/qwen/qwen2.5-coder-32b-instruct",
      messages: [{ role: "user", content: "Return a tiny HTML page." }],
      max_tokens: 9999,
      temperature: 2,
      stream: false,
    }),
    env(async (model, input) => {
      calls.push({ model, input });
      return {
        response: "<!doctype html><html><body>ok</body></html>",
        usage: { prompt_tokens: 8, completion_tokens: 12, total_tokens: 20 },
      };
    }),
  );
  const payload = await response.json();
  assert.equal(response.status, 200);
  assert.equal(payload.live_provider_calls, true);
  assert.equal(payload.direct_provider_calls, false);
  assert.match(payload.choices[0].message.content, /^<!doctype html>/i);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].model, "@cf/qwen/qwen2.5-coder-32b-instruct");
  assert.equal(calls[0].input.max_tokens, 2048);
  assert.equal(calls[0].input.temperature, 1);
});

test("streaming and unapproved models fail closed before inference", async () => {
  let calls = 0;
  const fakeEnv = env(async () => { calls += 1; });
  const streaming = await worker.fetch(
    chatRequest({ model: "@cf/meta/llama-3.1-8b-instruct", messages: [{ role: "user", content: "test" }], stream: true }),
    fakeEnv,
  );
  const unapproved = await worker.fetch(
    chatRequest({ model: "provider/paid-model", messages: [{ role: "user", content: "test" }] }),
    fakeEnv,
  );
  assert.equal(streaming.status, 501);
  assert.equal(unapproved.status, 400);
  assert.equal(calls, 0);
});

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import worker from "../src/index.js";

const productionNamespace = "superbrain-memory-production-v1";
const previewNamespace = "superbrain-memory-preview-v1";

// The shared index models Vectorize's documented pre-search namespace filtering.
// All vectors are equally close, so an unscoped query exposes every environment.
function sharedMemory() {
  const vectors = new Map();
  const calls = { embeddings: 0, upserts: [], queries: [] };
  const VECTORIZE = {
    async upsert(batch) {
      calls.upserts.push(batch);
      for (const vector of batch) vectors.set(vector.id, structuredClone(vector));
    },
    async query(values, options) {
      calls.queries.push(options);
      return { matches: [...vectors.values()]
        .filter((vector) => options.namespace === undefined || vector.namespace === options.namespace)
        .slice(0, options.topK)
        .map((vector) => ({ ...vector, score: 1 })) };
    },
  };
  const environment = (namespace, token) => ({
    AGENT_API_AUTH_TOKEN: token,
    MEMORY_VECTOR_NAMESPACE: namespace,
    VECTORIZE,
    AI: { async run() { calls.embeddings += 1; return { data: [[1, 0, 0]] }; } },
  });
  return { vectors, calls, environment };
}

function write(env, project, text, extra = {}, token = env.AGENT_API_AUTH_TOKEN) {
  return worker.fetch(new Request("https://worker.example/api/v1/memory/semantic", {
    method: "POST",
    headers: { "content-type": "application/json", "x-superbrain-agent-token": token },
    body: JSON.stringify({ project_id: project, text, ...extra }),
  }), env);
}

function search(env, extra = "", token = env.AGENT_API_AUTH_TOKEN) {
  return worker.fetch(new Request(`https://worker.example/api/v1/memory/semantic/search?q=shared%20topic&top_k=20${extra}`, {
    headers: { "x-superbrain-agent-token": token },
  }), env);
}

test("semantic memory isolates production and preview while retaining same-environment cross-project recall", async () => {
  const { vectors, calls, environment } = sharedMemory();
  const production = environment(productionNamespace, "unit-production-token");
  const preview = environment(previewNamespace, "unit-preview-token");
  vectors.set("legacy", { id: "legacy", values: [1, 0, 0], metadata: { project_id: "legacy", text: "legacy unscoped document" } });
  assert.equal((await write(production, "production-one", "production first document")).status, 201);
  assert.equal((await write(production, "production-two", "production second document")).status, 201);
  assert.equal((await write(preview, "preview-one", "preview only document")).status, 201);

  const previewResponse = await search(preview);
  assert.equal(previewResponse.status, 200);
  const previewResult = await previewResponse.json();
  assert.deepEqual(previewResult.matches.map((match) => match.text), ["preview only document"]);
  const productionResponse = await search(production);
  assert.equal(productionResponse.status, 200);
  const productionResult = await productionResponse.json();
  assert.deepEqual(productionResult.matches.map((match) => match.project_id), ["production-one", "production-two"]);
  assert.equal(productionResult.lexical_fallback_used, false);
  assert.equal(productionResult.retrieval_mode, "semantic_vector_cosine");
  assert.deepEqual(calls.upserts.map(([vector]) => vector.namespace), [productionNamespace, productionNamespace, previewNamespace]);
  assert.deepEqual(calls.queries.map((options) => options.namespace), [previewNamespace, productionNamespace]);
  assert.equal(vectors.get("legacy").namespace, undefined, "legacy data is retained without migration");
});

test("caller-supplied namespace and project filters cannot override server environment scope", async () => {
  const { calls, environment } = sharedMemory();
  const production = environment(productionNamespace, "unit-production-token");
  const preview = environment(previewNamespace, "unit-preview-token");
  const productionWrite = await write(production, "production-one", "production only document");
  const productionId = (await productionWrite.json()).id;
  const response = await write(preview, "preview-one", "preview scoped document", {
    id: productionId,
    namespace: productionNamespace,
    MEMORY_VECTOR_NAMESPACE: productionNamespace,
    metadata: { namespace: productionNamespace },
  });
  assert.equal(response.status, 201);
  assert.notEqual((await response.json()).id, productionId, "caller cannot overwrite a production vector by ID");
  const result = await (await search(preview, `&namespace=${productionNamespace}&MEMORY_VECTOR_NAMESPACE=${productionNamespace}&project_id=production-one&filter=%7B%22namespace%22%3A%22${productionNamespace}%22%7D`)).json();
  assert.deepEqual(result.matches.map((match) => match.text), ["preview scoped document"]);
  assert.equal(calls.upserts.at(-1)[0].namespace, previewNamespace);
  assert.equal(calls.queries.at(-1).namespace, previewNamespace);
  const productionResult = await (await search(production)).json();
  assert.deepEqual(productionResult.matches.map((match) => match.text), ["production only document"]);
});

test("missing or invalid server namespace fails closed before any embedding or index call", async () => {
  for (const namespace of [undefined, null, "", " ", "production", "default", "shared", `${previewNamespace} `, previewNamespace.toUpperCase(), "x".repeat(65), 1, {}, [previewNamespace]]) {
    const { calls, environment } = sharedMemory();
    const env = environment(namespace, "unit-preview-token");
    for (const response of [await write(env, "preview-one", "document"), await search(env)]) {
      assert.equal(response.status, 503, `namespace ${JSON.stringify(namespace)} must fail closed`);
      assert.equal((await response.json()).error, "semantic_memory_configuration_unavailable");
    }
    assert.equal(calls.embeddings, 0);
    assert.deepEqual(calls.upserts, []);
    assert.deepEqual(calls.queries, []);
  }
});

test("semantic memory rejects missing and other-environment tokens before provider calls", async () => {
  const { calls, environment } = sharedMemory();
  const env = environment(previewNamespace, "unit-preview-token");
  for (const token of ["", "unit-production-token"]) {
    assert.equal((await write(env, "preview-one", "document", {}, token)).status, 401);
    assert.equal((await search(env, "", token)).status, 401);
  }
  assert.equal(calls.embeddings, 0);
  assert.deepEqual(calls.upserts, []);
  assert.deepEqual(calls.queries, []);
});

test("Wrangler pins distinct production and preview semantic namespaces", () => {
  const config = JSON.parse(readFileSync(new URL("../wrangler.jsonc", import.meta.url), "utf8"));
  assert.equal(config.vars.MEMORY_VECTOR_NAMESPACE, productionNamespace);
  assert.equal(config.env.preview.vars.MEMORY_VECTOR_NAMESPACE, previewNamespace);
});

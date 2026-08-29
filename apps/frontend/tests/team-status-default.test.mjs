import assert from "node:assert/strict";
import fs from "node:fs";
import { createRequire } from "node:module";
import test from "node:test";
import vm from "node:vm";
import ts from "typescript";

const require = createRequire(import.meta.url);
const endpointDefaultsSource = fs.readFileSync(new URL("../lib/endpointDefaults.ts", import.meta.url), "utf8");
const agentApiSource = fs.readFileSync(new URL("../lib/agentApi.ts", import.meta.url), "utf8");
const catchAllRouteSource = fs.readFileSync(new URL("../app/api/v1/[...slug]/route.ts", import.meta.url), "utf8");

function compileCommonJs(source) {
  return ts.transpileModule(source, {
    compilerOptions: {
      esModuleInterop: true,
      module: ts.ModuleKind.CommonJS,
      resolveJsonModule: true,
      target: ts.ScriptTarget.ES2022,
    },
  }).outputText;
}

function loadCommonJs(source, localRequire = require) {
  const compiled = compileCommonJs(source);
  const loaded = { exports: {} };
  const evaluate = new vm.Script(`(function (require, module, exports) { ${compiled}\n})`).runInThisContext();
  evaluate(localRequire, loaded, loaded.exports);
  return loaded.exports;
}

const endpointDefaults = loadCommonJs(endpointDefaultsSource);
const agentApi = loadCommonJs(agentApiSource);
let readProxyCalls = 0;
const boundaryStub = {
  authorizeBoundaryWrite: async () => null,
  authorizePublicSecurityProbe: () => null,
  boundaryUnavailable: (endpoint, boundary, detail, status = 503) => Response.json({
    contract_version: "frontend-boundary-unavailable-v1",
    status: "blocked",
    endpoint,
    boundary,
    detail,
    secret_output: false,
  }, { status }),
  proxyAuthSessionToBoundary: async () => null,
  proxyOAuthGetToBoundary: async () => null,
  proxyReadToBoundary: async () => {
    readProxyCalls += 1;
    return null;
  },
  proxyToBoundary: async () => null,
};
const route = loadCommonJs(catchAllRouteSource, (specifier) => {
  if (specifier === "../../../../lib/endpoint-snapshot.json") return {};
  if (specifier === "../../../../lib/endpointDefaults") return endpointDefaults;
  if (specifier === "../../../../lib/frontendBoundary") return boundaryStub;
  return require(specifier);
});

const LOGICAL_ROLES = ["supervisor", "planner", "explorer", "coder", "tester"];
const ROLE_MAP = {
  supervisor: "planner",
  planner: "planner",
  explorer: "planner",
  coder: "coder",
  tester: "tester",
};
const originalFetch = globalThis.fetch;
const originalAgentApiInternalUrl = process.env.AGENT_API_INTERNAL_URL;

test.afterEach(() => {
  readProxyCalls = 0;
  globalThis.fetch = originalFetch;
  if (originalAgentApiInternalUrl === undefined) delete process.env.AGENT_API_INTERNAL_URL;
  else process.env.AGENT_API_INTERNAL_URL = originalAgentApiInternalUrl;
});

function assertExternalDegradedTeam(payload) {
  assert.equal(payload.contract_version, "autonomous-coding-team-v1");
  assert.equal(payload.dispatch_contract_version, "autonomous-task-dispatch-v1");
  assert.equal(payload.team_mode, "logical_five_role_overlay_on_runtime_pool");
  assert.equal(payload.runtime_source, "external_adapter");
  assert.equal(payload.status, "external_degraded");
  assert.equal(payload.dispatch_id, null);
  assert.equal(payload.queue_depth, 0);
  assert.deepEqual(payload.queue_depth_by_priority, { high: 0, mid: 0, low: 0 });
  assert.equal(payload.queue_depth_observed, false);
  assert.deepEqual(payload.logical_roles, LOGICAL_ROLES);
  assert.deepEqual(payload.logical_to_execution_map, ROLE_MAP);
  assert.equal(payload.runtime_pool_contract_version, "task-assignment-queue-contract-v1");
  assert.equal(payload.live_provider_calls, false);
  assert.equal(payload.direct_provider_calls, false);
  assert.equal(payload.live_mcp_writes, false);
  assert.equal(payload.provider_writes, false);
  assert.equal(payload.production_deploy, false);
  assert.equal(payload.production_rollout_claimed, false);
  assert.equal(payload.secret_output, false);
  assert.ok(Array.isArray(payload.non_claims) && payload.non_claims.length > 0);

  assert.equal(payload.external_runtime?.configured, false);
  assert.equal(payload.external_runtime?.ready, false);
  assert.equal(payload.external_runtime?.runtime, "cloud_native_read_only_projection");
  assert.deepEqual(payload.external_runtime?.agents, []);
  assert.deepEqual(payload.external_runtime?.logical_role_map, ROLE_MAP);
  assert.equal(payload.external_runtime?.direct_provider_calls, false);
  assert.equal(payload.external_runtime?.production_rollout_claimed, false);

  assert.equal(payload.members?.length, LOGICAL_ROLES.length);
  for (const [index, member] of payload.members.entries()) {
    const logicalRole = LOGICAL_ROLES[index];
    assert.equal(member.logical_role, logicalRole);
    assert.equal(member.execution_agent_type, ROLE_MAP[logicalRole]);
    assert.equal(member.status, "unavailable");
    assert.equal(member.latest_status, "unavailable");
    assert.equal(member.task_id, null);
    assert.equal(member.latest_task_id, null);
    assert.equal(member.priority, null);
    assert.equal(member.priority_level, null);
    assert.equal(member.priority_queue, null);
    assert.deepEqual(member.allowed_tools, []);
    assert.deepEqual(member.write_scope, []);
    assert.equal(member.human_review_required, true);
  }
}

test("the known team-status projection is a full parser-compatible degraded contract", () => {
  const projected = endpointDefaults.projectedDefault("/api/v1/team/status", "GET");
  assert.ok(projected);
  assert.equal(projected.status ?? 200, 200);
  assertExternalDegradedTeam(projected.payload);
});

test("the production team-status parser accepts the projected payload", async () => {
  const projected = endpointDefaults.projectedDefault("/api/v1/team/status", "GET");
  process.env.AGENT_API_INTERNAL_URL = "https://agent-api.example";
  globalThis.fetch = async () => Response.json(projected.payload);
  const parsed = await agentApi.fetchCodingTeam();
  assert.deepEqual(parsed, {
    contractVersion: "autonomous-coding-team-v1",
    status: "external_degraded",
    teamMode: "logical_five_role_overlay_on_runtime_pool",
    runtimeSource: "external_adapter",
    dispatchId: null,
    queueDepth: 0,
    queueDepthByPriority: { high: 0, mid: 0, low: 0 },
    members: LOGICAL_ROLES.map((logicalRole) => ({
      logicalRole,
      executionAgentType: ROLE_MAP[logicalRole],
      status: "unavailable",
      priorityLevel: null,
      priorityQueue: null,
    })),
  });
});

test("the catch-all serves the same honest no-dispatch projection when the backend is unavailable", async () => {
  readProxyCalls = 0;
  const response = await route.GET(
    new Request("https://frontend.example/api/v1/team/status"),
    { params: Promise.resolve({ slug: ["team", "status"] }) },
  );
  assert.equal(response.status, 200);
  assert.equal(readProxyCalls, 1);
  assert.equal(response.headers.get("x-superbrain-source"), "frontend-projection");
  assertExternalDegradedTeam(await response.json());
});

test("a nonempty dispatch_id fails closed without reflecting untrusted input", async () => {
  const untrustedDispatchId = "owner-secret-token-do-not-reflect";
  readProxyCalls = 0;
  const response = await route.GET(
    new Request(`https://frontend.example/api/v1/team/status?dispatch_id=${untrustedDispatchId}`),
    { params: Promise.resolve({ slug: ["team", "status"] }) },
  );
  const text = await response.text();
  assert.equal(response.status, 404);
  assert.equal(readProxyCalls, 0, "an unsafe dispatch identifier must never reach the service boundary");
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.doesNotMatch(text, new RegExp(untrustedDispatchId));
  const payload = JSON.parse(text);
  assert.equal(payload.contract_version, "autonomous-coding-team-v1");
  assert.equal(payload.status, "blocked");
  assert.equal(payload.error, "dispatch_not_found");
  assert.equal(payload.dispatch_id, null);
  assert.equal(payload.request_id, null);
  assert.equal(payload.persisted, false);
  assert.equal(payload.live_provider_calls, false);
  assert.equal(payload.live_mcp_writes, false);
  assert.equal(payload.provider_writes, false);
  assert.equal(payload.production_deploy, false);
  assert.equal(payload.secret_output, false);
});

test("a valid dispatch_id reaches the read boundary, then fails closed if the backend is unavailable", async () => {
  const validDispatchId = "123e4567-e89b-42d3-a456-426614174000";
  readProxyCalls = 0;
  const response = await route.GET(
    new Request(`https://frontend.example/api/v1/team/status?dispatch_id=${validDispatchId}`),
    { params: Promise.resolve({ slug: ["team", "status"] }) },
  );
  const text = await response.text();
  assert.equal(readProxyCalls, 1);
  assert.equal(response.status, 404);
  assert.doesNotMatch(text, new RegExp(validDispatchId));
  assert.equal(JSON.parse(text).error, "dispatch_not_found");
});

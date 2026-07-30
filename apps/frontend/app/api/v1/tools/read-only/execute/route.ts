import { randomUUID } from "node:crypto";
import {
  authorizeBoundaryWrite,
  boundaryUnavailable,
  proxyReadToBoundary,
  proxyToBoundary,
} from "../../../../../../lib/frontendBoundary";
import {
  readBoundedJsonRequest,
  readBoundedJsonResponse,
  safeBoundedText,
  safeProjectId,
  sha256Text,
} from "../../../../../../lib/hostedO2Actions";

export const dynamic = "force-dynamic";
export const maxDuration = 30;

type JsonRecord = Record<string, unknown>;
type ToolId = "memory_read" | "task_router";

const ROLE_ORDER = ["planner", "coder", "tester", "devops"] as const;

function isRecord(value: unknown): value is JsonRecord {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function toolBlocked(status: 400 | 503, error: string): Response {
  return Response.json(
    {
      contract_version: "goal-b-readonly-tool-execute-v1",
      status: "blocked",
      error,
      accepted: false,
      persisted: false,
      audit_persisted: false,
      read_only: true,
      direct_provider_calls: false,
      live_provider_calls: false,
      live_mcp_writes: false,
      production_deploy: false,
      secret_output: false,
    },
    {
      status,
      headers: {
        "cache-control": "no-store",
        "x-superbrain-source": "frontend-readonly-tool-guard",
      },
    },
  );
}

function runtimeReadRequest(req: Request, requestId: string, search = ""): Request {
  const url = new URL(req.url);
  url.search = search;
  return new Request(url, {
    method: "GET",
    headers: { accept: "application/json", "x-request-id": requestId },
  });
}

function safeRuntimeEntries(payload: JsonRecord, projectId: string): JsonRecord[] {
  if (
    payload.contract_version !== "cloudflare-d1-langgraph-runtime-v1"
    || payload.status !== "verified"
    || payload.mode !== "cloudflare_d1_backed_phase2_runtime_runs"
    || payload.source !== "cloudflare-d1"
    || payload.persisted !== true
    || payload.live_provider_calls !== false
    || payload.direct_provider_calls !== false
    || payload.live_mcp_writes !== false
    || payload.production_deploy !== false
    || payload.secret_output !== false
    || !Array.isArray(payload.runs)
    || payload.runs.length > 50
  ) {
    throw new Error("invalid_runtime_memory_response");
  }
  return payload.runs
    .filter(isRecord)
    .filter((run) => run.project_id === projectId)
    .slice(0, 5)
    .map((run) => {
      if (
        typeof run.run_id !== "string"
        || !/^[A-Za-z0-9_-]{1,64}$/.test(run.run_id)
        || typeof run.prompt_sha256 !== "string"
        || !/^[a-f0-9]{64}$/.test(run.prompt_sha256)
        || typeof run.status !== "string"
        || !/^[a-z_]{1,40}$/.test(run.status)
        || typeof run.current_node !== "string"
        || !/^[a-z_]{1,40}$/.test(run.current_node)
        || typeof run.created_at !== "string"
        || run.created_at.length > 64
        || !Array.isArray(run.role_results)
        || run.role_results.length > ROLE_ORDER.length
      ) {
        throw new Error("invalid_runtime_memory_entry");
      }
      return {
        run_id: run.run_id,
        prompt_sha256: run.prompt_sha256,
        status: run.status,
        current_node: run.current_node,
        created_at: run.created_at,
        role_count: run.role_results.length,
        persisted: run.persisted === true,
      };
    });
}

function routedRole(payload: JsonRecord, query: string): JsonRecord {
  if (
    payload.contract_version !== "cloudflare-d1-langgraph-runtime-v1"
    || payload.status !== "healthy"
    || payload.mode !== "deterministic_hosted_free_runtime"
    || payload.engine !== "langgraph-js"
    || payload.checkpointing !== "cloudflare-d1"
    || payload.persisted !== true
    || payload.live_provider_calls !== false
    || payload.direct_provider_calls !== false
    || payload.live_mcp_writes !== false
    || payload.production_deploy !== false
    || payload.secret_output !== false
    || !Array.isArray(payload.graph_nodes)
    || payload.graph_nodes.join(",") !== ROLE_ORDER.join(",")
  ) {
    throw new Error("invalid_runtime_router_response");
  }
  const normalized = query.toLocaleLowerCase("de-DE");
  const rules: Array<{ role: typeof ROLE_ORDER[number]; terms: string[] }> = [
    { role: "tester", terms: ["test", "prüf", "verify", "fehler", "quality"] },
    { role: "devops", terms: ["deploy", "cloud", "runtime", "betrieb", "infra"] },
    { role: "coder", terms: ["code", "implement", "fix", "frontend", "backend"] },
    { role: "planner", terms: ["plan", "architektur", "ziel", "scope"] },
  ];
  const matched = rules.find((rule) => rule.terms.some((term) => normalized.includes(term)));
  return {
    mode: "cloudflare_native_contract_router",
    selected_role: matched?.role ?? "planner",
    route_reason: matched ? "bounded_keyword_match" : "deterministic_planner_default",
    graph_nodes: [...ROLE_ORDER],
    engine: "langgraph-js",
    checkpointing: "cloudflare-d1",
  };
}

export async function POST(req: Request): Promise<Response> {
  const writeBlock = await authorizeBoundaryWrite(req);
  if (writeBlock) return writeBlock;

  let projectId: string;
  let toolId: ToolId;
  let query: string;
  try {
    const body = await readBoundedJsonRequest(req);
    projectId = safeProjectId(body.project_id);
    if (body.tool_id !== "memory_read" && body.tool_id !== "task_router") {
      throw new Error("invalid_tool_id");
    }
    toolId = body.tool_id;
    query = safeBoundedText(body.query, "query", 1, 500);
  } catch {
    return toolBlocked(400, "invalid_readonly_tool_request");
  }

  const requestId = randomUUID();
  const querySha256 = sha256Text(query);
  let result: JsonRecord;
  let resultCount: number;
  try {
    if (toolId === "memory_read") {
      const response = await proxyReadToBoundary(
        runtimeReadRequest(req, requestId, "?limit=20"),
        "agent-api",
        "/api/v1/phase2/runtime/runs",
        8_000,
      );
      if (!response) throw new Error("runtime_memory_unavailable");
      const entries = safeRuntimeEntries(await readBoundedJsonResponse(response), projectId);
      resultCount = entries.length;
      result = {
        mode: "cloudflare_d1_runtime_memory_read",
        query_sha256: querySha256,
        entries,
        count: entries.length,
        project_scoped: true,
      };
    } else {
      const response = await proxyReadToBoundary(
        runtimeReadRequest(req, requestId),
        "agent-api",
        "/api/v1/phase2/runtime/contract",
        8_000,
      );
      if (!response) throw new Error("runtime_router_unavailable");
      result = {
        ...routedRole(await readBoundedJsonResponse(response), query),
        query_sha256: querySha256,
      };
      resultCount = 1;
    }
  } catch {
    return toolBlocked(503, "readonly_tool_runtime_unavailable");
  }

  const auditRequest = new Request(req.url, {
    method: "POST",
    headers: {
      accept: "application/json",
      "content-type": "application/json",
      "x-request-id": requestId,
    },
    body: JSON.stringify({
      project_id: projectId,
      source_page: "tools",
      artifact_type: "readonly_tool_audit",
      title: `Read-only tool audit: ${toolId}`,
      summary: `Executed ${toolId} against the hosted Cloudflare runtime with ${resultCount} bounded result item(s).`,
      status: "verified",
      metadata: {
        contract_version: "hosted-readonly-tool-audit-v1",
        tool_id: toolId,
        query_sha256: querySha256,
        result_count: resultCount,
        read_only: true,
        provider_calls: false,
        mcp_writes: false,
      },
    }),
  });
  const auditResponse = await proxyToBoundary(
    auditRequest,
    "agent-api",
    "/api/v1/workspace/artifacts",
    8_000,
    { serviceAuth: true },
  );
  if (!auditResponse || auditResponse.status !== 201) {
    return boundaryUnavailable(
      "POST /api/v1/workspace/artifacts",
      "agent-api",
      "The read-only result was not returned because its required hosted audit could not be persisted.",
    );
  }

  try {
    const audit = await readBoundedJsonResponse(auditResponse);
    const artifact = isRecord(audit.artifact) ? audit.artifact : null;
    if (
      audit.contract_version !== "cloudflare-stateful-runtime-v1"
      || audit.status !== "created"
      || audit.source !== "cloudflare-d1"
      || audit.audit_persisted !== true
      || audit.live_provider_calls !== false
      || audit.live_mcp_writes !== false
      || audit.production_deploy !== false
      || audit.secret_output !== false
      || !artifact
      || typeof artifact.id !== "string"
      || !/^[A-Za-z0-9_-]{1,64}$/.test(artifact.id)
      || artifact.project_id !== projectId
    ) {
      throw new Error("invalid_tool_audit_response");
    }
    return Response.json(
      {
        contract_version: "goal-b-readonly-tool-execute-v1",
        evidence_ref: "goal_b_readonly_tool_result_visible",
        status: "success",
        tool_id: toolId,
        project_id: projectId,
        result,
        audit_event_id: artifact.id,
        audit_persisted: true,
        persisted: true,
        read_only: true,
        source: "cloudflare-d1",
        direct_provider_calls: false,
        live_provider_calls: false,
        live_mcp_writes: false,
        production_deploy: false,
        secret_output: false,
      },
      {
        status: 200,
        headers: {
          "cache-control": "no-store",
          "x-superbrain-boundary": "agent-api-boundary",
          "x-superbrain-source": "cloudflare-d1-readonly-tool",
        },
      },
    );
  } catch {
    return toolBlocked(503, "readonly_tool_audit_validation_failed");
  }
}

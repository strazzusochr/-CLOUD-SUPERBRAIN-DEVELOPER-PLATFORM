import { fetchActivityKinds, mapKind } from "../agentApi";

export const dynamic = "force-dynamic";
export const revalidate = 0;

function safeTraceId(value: string | null): string | null {
  if (!value) return null;
  const trimmed = value.trim();
  return /^[A-Za-z0-9_.:-]{1,96}$/.test(trimmed) ? trimmed : null;
}

/** Deterministic spec-only event feed — used whenever no agent-api is reachable. */
function specOnlyFeed(runId: string | null) {
  return {
    contract_version: "organism-events-v1",
    source: "spec_only",
    source_kind: "spec_only",
    live: false,
    run_id: runId,
    note: "Spec-only event contract — no reachable agent-api. Never a live provider call.",
    events: [
      { seq: 1, offset_s: 0.0, page_id: "workbench", route: "/workbench", user_action: "prompt_submitted", kind: "plan_created", hub: "workbench", regions: ["prefrontal", "thalamus", "callosum"], run_state: "planning", source_kind: "spec_only", evidence_files: [], secret_output: false, writes: false },
      { seq: 2, offset_s: 1.2, page_id: "agents", route: "/agents", agent: "planner", kind: "agent_dispatched", hub: "agents", regions: ["basal", "motor", "callosum"], run_state: "executing", source_kind: "spec_only", evidence_files: [], secret_output: false, writes: false },
      { seq: 3, offset_s: 2.6, page_id: "tools", route: "/tools", tool: "mcp_gateway", kind: "tool_call", hub: "tools", regions: ["basal", "sensory", "motor", "callosum"], run_state: "executing", source_kind: "spec_only", evidence_files: [], secret_output: false, writes: false },
      { seq: 4, offset_s: 3.9, page_id: "files", route: "/files", kind: "memory_read", hub: "memory", regions: ["hippocampus", "callosum"], run_state: "executing", source_kind: "spec_only", evidence_files: [], secret_output: false, writes: false },
      { seq: 5, offset_s: 5.1, page_id: "marketplace", route: "/marketplace", model: "llm_gateway", kind: "model_route", hub: "models", regions: ["basal", "thalamus", "callosum"], run_state: "executing", source_kind: "spec_only", evidence_files: [], secret_output: false, writes: false },
      { seq: 6, offset_s: 6.4, page_id: "observe", route: "/observe", kind: "verify", hub: "observe", regions: ["cerebellum", "sensory", "callosum"], run_state: "verifying", source_kind: "spec_only", evidence_files: [], secret_output: false, writes: false },
      { seq: 7, offset_s: 7.8, page_id: "evidence", route: "/evidence", kind: "checks_passed", hub: "observe", regions: ["cerebellum", "autonomic", "callosum"], run_state: "idle", source_kind: "spec_only", evidence_files: [], secret_output: false, writes: false },
    ],
    non_claims: ["spec-only data, never a live provider call", "no secret values"],
  };
}

/** GET /api/v1/organism/events — derived from the agent-api activity trace
 *  (`agent-activity-trace-v1`, event_type only) when reachable, else spec-only. */
export async function GET(request: Request) {
  const runId = safeTraceId(new URL(request.url).searchParams.get("run_id"));
  const kinds = await fetchActivityKinds(12, runId);
  if (!kinds) return Response.json(specOnlyFeed(runId));
  const events = kinds.map((kind, i) => {
    const { hub, run_state, regions } = mapKind(kind);
    return {
      seq: i + 1,
      offset_s: +(i * 1.2).toFixed(1),
      page_id: hub,
      route: hub === "models" ? "/marketplace" : hub === "observe" ? "/observe" : `/${hub}`,
      user_action: null,
      kind,
      hub,
      regions,
      run_state,
      source_kind: "agent_api_redacted",
      evidence_files: [],
      secret_output: false,
      writes: false,
    };
  });
  return Response.json({
    contract_version: "organism-events-v1",
    source: "agent-api",
    source_kind: "agent_api_redacted",
    live: true,
    run_id: runId,
    note: "Derived from configured agent-api /api/v1/agent-activity/recent (agent-activity-trace-v1; event_type only, no session/user identifiers).",
    events,
    non_claims: ["redacted runtime events only, no live provider call", "no secret values"],
  });
}

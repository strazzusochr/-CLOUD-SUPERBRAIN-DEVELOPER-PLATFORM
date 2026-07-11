import { fetchActivityKinds, fetchOrganismProjection, mapKind } from "../agentApi";
import * as gh from "../../../../../lib/ghStore";

export const dynamic = "force-dynamic";
export const revalidate = 0;

// Map real audit events → organism hubs/brain-regions so genuine platform activity
// (building apps, running prompts, storing memory, sessions) lights up the cortex.
const AUDIT_MAP: Record<string, { hub: string; regions: string[]; run_state: string }> = {
  app_built: { hub: "workbench", regions: ["prefrontal", "motor", "callosum"], run_state: "executing" },
  artifact_created: { hub: "workbench", regions: ["motor", "callosum"], run_state: "executing" },
  app_deleted: { hub: "workbench", regions: ["motor"], run_state: "idle" },
  prompt_completed: { hub: "agents", regions: ["prefrontal", "thalamus", "callosum"], run_state: "executing" },
  prompt_failed: { hub: "agents", regions: ["basal"], run_state: "blocked" },
  session_started: { hub: "memory", regions: ["hippocampus", "callosum"], run_state: "idle" },
};

async function realAuditFeed(runId: string | null) {
  if (!gh.ghConfigured()) return null;
  try {
    const rows = (await gh.list("audit.json", 14)) as Array<Record<string, unknown>>;
    if (!rows.length) return null;
    const events = rows.map((r, i) => {
      const kind = String(r.event_type ?? "event");
      const m = AUDIT_MAP[kind] ?? { hub: "observe", regions: ["cerebellum", "callosum"], run_state: "idle" };
      return {
        seq: i + 1, offset_s: +(i * 1.2).toFixed(1), kind, event_type: kind, hub: m.hub,
        route: `/${m.hub}`, regions: m.regions, run_state: m.run_state, source_kind: "platform_audit",
        severity: "info", occurred_at: r.occurred_at ?? null, evidence_files: [], secret_output: false, writes: false,
      };
    });
    return {
      contract_version: "organism-events-v1", source: "platform-audit", source_kind: "platform_audit",
      live: true, run_id: runId, note: "Echte Plattform-Aktivität aus dem Audit-Log (Builds, Prompts, Memory, Sessions).",
      events, non_claims: ["read-only audit projection", "no secret values"],
    };
  } catch {
    return null;
  }
}

function safeTraceId(value: string | null): string | null {
  if (!value) return null;
  const trimmed = value.trim();
  return /^[A-Za-z0-9_.:-]{1,96}$/.test(trimmed) ? trimmed : null;
}

function projectedRuntimeFeed(runId: string | null) {
  if (!runId?.startsWith("frontend-projection")) return null;
  const events = [
    { seq: 1, offset_s: 0.0, kind: "phase2_runtime_graph_started", hub: "workbench", regions: ["prefrontal", "callosum"], run_state: "planning", source_kind: "frontend_projection", evidence_files: [], secret_output: false, writes: false },
    { seq: 2, offset_s: 1.2, kind: "agent_result_aggregation_complete", hub: "agents", regions: ["motor", "callosum"], run_state: "executing", source_kind: "frontend_projection", evidence_files: [], secret_output: false, writes: false },
    { seq: 3, offset_s: 2.4, kind: "memory_update_persisted", hub: "memory", regions: ["hippocampus", "callosum"], run_state: "verifying", source_kind: "frontend_projection", evidence_files: [], secret_output: false, writes: false },
  ];
  return {
    contract_version: "organism-events-v1",
    source: "frontend-projection",
    source_kind: "frontend_projection",
    live: false,
    run_id: runId,
    note: "Deterministic frontend projection of the Phase-2 runtime event contract; no agent-api involved.",
    events,
    non_claims: ["frontend projection only, no agent-api call", "no live provider call", "no secret values"],
  };
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
  const projectedRuntime = projectedRuntimeFeed(runId);
  if (projectedRuntime) return Response.json(projectedRuntime);
  const projection = await fetchOrganismProjection("events", runId);
  if (
    projection?.contract_version === "organism-events-v1" &&
    Array.isArray(projection.events) &&
    projection.live === true
  ) {
    return Response.json(projection);
  }
  const kinds = await fetchActivityKinds(12, runId);
  if (!kinds) {
    // Prefer REAL platform activity from the audit log; spec-only is the last resort.
    const audit = await realAuditFeed(runId);
    return Response.json(audit ?? specOnlyFeed(runId));
  }
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
    non_claims: ["redacted runtime events only, no live provider call", "no secret values", "read-only audit projection"],
  });
}

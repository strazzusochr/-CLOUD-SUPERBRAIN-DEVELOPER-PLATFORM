import { fetchActivityKinds, mapKind } from "../agentApi";

export const dynamic = "force-dynamic";
export const revalidate = 0;

/** Deterministic mock event feed — used whenever no agent-api is reachable. */
function mockFeed() {
  return {
    contract_version: "organism-events-v1",
    source: "mock",
    live: false,
    note: "Deterministic mock — no reachable agent-api. Never a live provider call.",
    events: [
      { seq: 1, offset_s: 0.0, kind: "plan_created", hub: "workbench", run_state: "planning" },
      { seq: 2, offset_s: 1.2, kind: "agent_dispatched", hub: "agents", run_state: "executing" },
      { seq: 3, offset_s: 2.6, kind: "tool_call", hub: "tools", run_state: "executing" },
      { seq: 4, offset_s: 3.9, kind: "memory_read", hub: "memory", run_state: "executing" },
      { seq: 5, offset_s: 5.1, kind: "model_route", hub: "models", run_state: "executing" },
      { seq: 6, offset_s: 6.4, kind: "verify", hub: "observe", run_state: "verifying" },
      { seq: 7, offset_s: 7.8, kind: "checks_passed", hub: "observe", run_state: "idle" },
    ],
    non_claims: ["mock data, never a live provider call", "no secret values"],
  };
}

/** GET /api/v1/organism/events — derived from the agent-api activity trace
 *  (`agent-activity-trace-v1`, event_type only) when reachable, else the mock. */
export async function GET() {
  const kinds = await fetchActivityKinds(12);
  if (!kinds) return Response.json(mockFeed());
  const events = kinds.map((kind, i) => {
    const { hub, run_state } = mapKind(kind);
    return { seq: i + 1, offset_s: +(i * 1.2).toFixed(1), kind, hub, run_state };
  });
  return Response.json({
    contract_version: "organism-events-v1",
    source: "agent-api",
    live: true,
    note: "Derived from agent-api /api/v1/agent-activity/recent (agent-activity-trace-v1; local dry-run, event_type only — no session/user identifiers).",
    events,
    non_claims: ["local dry-run runtime, no live provider call", "no secret values"],
  });
}

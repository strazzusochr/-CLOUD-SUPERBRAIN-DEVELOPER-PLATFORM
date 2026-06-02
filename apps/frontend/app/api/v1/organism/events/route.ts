export const dynamic = "force-static";

/** GET /api/v1/organism/events — MOCK event feed (no hosted backend here). */
export function GET() {
  return Response.json({
    contract_version: "organism-events-v1",
    source: "mock",
    live: false,
    note: "Deterministic mock until the hosted agent-api serves /api/v1/organism/events.",
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
  });
}

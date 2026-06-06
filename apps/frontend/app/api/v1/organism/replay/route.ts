import { fetchActivityKinds, mapKind } from "../agentApi";

export const dynamic = "force-dynamic";
export const revalidate = 0;

/** Deterministic mock replay timeline — used whenever no agent-api is reachable. */
function mockReplay() {
  return {
    contract_version: "organism-replay-v1",
    source: "mock",
    live: false,
    note: "Deterministic mock — no reachable agent-api. Never a live provider call.",
    duration_s: 8,
    fps: 30,
    frames: [
      { t: 0.0, run_state: "planning", active: ["workbench"] },
      { t: 2.0, run_state: "executing", active: ["agents", "tools"] },
      { t: 4.0, run_state: "executing", active: ["models", "memory"] },
      { t: 6.0, run_state: "verifying", active: ["observe"] },
      { t: 8.0, run_state: "idle", active: [] },
    ],
    non_claims: ["mock data, never a live provider call", "no secret values"],
  };
}

/** GET /api/v1/organism/replay — a timeline reconstructed from the agent-api
 *  activity trace (event_type → hub/run_state) when reachable, else the mock. */
export async function GET() {
  const kinds = await fetchActivityKinds(8);
  if (!kinds) return Response.json(mockReplay());
  const step = 1.2;
  const frames = kinds.map((kind, i) => {
    const { hub, run_state } = mapKind(kind);
    return { t: +(i * step).toFixed(1), run_state, active: [hub] };
  });
  return Response.json({
    contract_version: "organism-replay-v1",
    source: "agent-api",
    live: true,
    note: "Reconstructed from agent-api /api/v1/agent-activity/recent (agent-activity-trace-v1; local dry-run, event_type only — no session/user identifiers).",
    duration_s: +(kinds.length * step).toFixed(1),
    fps: 30,
    frames,
    non_claims: ["local dry-run runtime, no live provider call", "no secret values"],
  });
}

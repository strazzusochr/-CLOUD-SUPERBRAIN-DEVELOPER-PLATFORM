import { fetchActivityKinds, fetchOrganismProjection, mapKind } from "../agentApi";

export const dynamic = "force-dynamic";
export const revalidate = 0;

function safeTraceId(value: string | null): string | null {
  if (!value) return null;
  const trimmed = value.trim();
  return /^[A-Za-z0-9_.:-]{1,96}$/.test(trimmed) ? trimmed : null;
}

/** Deterministic spec-only replay timeline — used whenever no agent-api is reachable. */
function specOnlyReplay(runId: string | null) {
  return {
    contract_version: "organism-replay-v1",
    source: "spec_only",
    source_kind: "spec_only",
    live: false,
    run_id: runId,
    replay_available: false,
    note: "Spec-only replay contract — no reachable agent-api. Never a live provider call.",
    duration_s: 8,
    fps: 30,
    frames: [
      { t: 0.0, run_state: "planning", active: ["workbench"] },
      { t: 2.0, run_state: "executing", active: ["agents", "tools"] },
      { t: 4.0, run_state: "executing", active: ["models", "memory"] },
      { t: 6.0, run_state: "verifying", active: ["observe"] },
      { t: 8.0, run_state: "idle", active: [] },
    ],
    non_claims: ["spec-only data, never a live provider call", "no secret values"],
  };
}

/** GET /api/v1/organism/replay — a timeline reconstructed from the agent-api
 *  activity trace (event_type → hub/run_state) when reachable, else spec-only. */
export async function GET(request: Request) {
  const runId = safeTraceId(new URL(request.url).searchParams.get("run_id"));
  const projection = await fetchOrganismProjection("replay", runId);
  if (
    projection?.contract_version === "organism-replay-v1" &&
    Array.isArray(projection.frames) &&
    projection.live === true
  ) {
    return Response.json(projection);
  }
  const kinds = await fetchActivityKinds(8, runId);
  if (!kinds) return Response.json(specOnlyReplay(runId));
  const step = 1.2;
  const frames = kinds.map((kind, i) => {
    const { hub, run_state, regions } = mapKind(kind);
    return { t: +(i * step).toFixed(1), run_state, active: [hub], regions, source_kind: "agent_api_redacted" };
  });
  return Response.json({
    contract_version: "organism-replay-v1",
    source: "agent-api",
    source_kind: "agent_api_redacted",
    live: true,
    run_id: runId,
    replay_available: true,
    note: "Reconstructed from configured agent-api /api/v1/agent-activity/recent (agent-activity-trace-v1; event_type only, no session/user identifiers).",
    duration_s: +(kinds.length * step).toFixed(1),
    fps: 30,
    frames,
    non_claims: ["redacted runtime replay only, no live provider call", "no secret values", "read-only audit projection"],
  });
}

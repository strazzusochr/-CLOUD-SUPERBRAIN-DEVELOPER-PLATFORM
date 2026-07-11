import { fetchActivityKinds, fetchOrganismProjection, mapKind } from "../agentApi";
import * as gh from "../../../../../lib/ghStore";

export const dynamic = "force-dynamic";
export const revalidate = 0;

function organismResponse<T>(payload: T): Response {
  const record = payload as Record<string, unknown>;
  const source = String(record.source_kind ?? record.source ?? "unknown");
  return Response.json(payload, {
    headers: { "x-superbrain-source": source, "cache-control": "no-store" },
  });
}

function safeTraceId(value: string | null): string | null {
  if (!value) return null;
  const trimmed = value.trim();
  return /^[A-Za-z0-9_.:-]{1,96}$/.test(trimmed) ? trimmed : null;
}

function projectedRuntimeReplay(runId: string | null) {
  if (!runId?.startsWith("frontend-projection")) return null;
  return {
    contract_version: "organism-replay-v1",
    source: "frontend-projection",
    source_kind: "frontend_projection",
    live: false,
    run_id: runId,
    replay_available: true,
    note: "Deterministic frontend projection of the Phase-2 runtime replay contract; no agent-api involved.",
    duration_s: 3.6,
    fps: 30,
    frames: [
      { t: 0.0, run_state: "planning", active: ["workbench"], regions: ["prefrontal", "callosum"], source_kind: "frontend_projection" },
      { t: 1.2, run_state: "executing", active: ["agents"], regions: ["motor", "callosum"], source_kind: "frontend_projection" },
      { t: 2.4, run_state: "verifying", active: ["memory"], regions: ["hippocampus", "callosum"], source_kind: "frontend_projection" },
    ],
    non_claims: ["frontend projection only, no agent-api call", "no live provider call", "no secret values"],
  };
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

async function realAuditReplay(runId: string | null) {
  if (!gh.ghConfigured()) return null;
  try {
    const rows = await gh.list("audit.json", 14);
    if (!rows.length) return null;
    const step = 1.2;
    const frames = rows.map((row, index) => {
      const { hub, run_state, regions } = mapKind(String(row.event_type ?? "event"));
      return { t: +(index * step).toFixed(1), run_state, active: [hub], regions, source_kind: "platform_audit" };
    });
    return {
      contract_version: "organism-replay-v1",
      source: "platform-audit",
      source_kind: "platform_audit",
      live: true,
      run_id: runId,
      replay_available: true,
      note: "Redacted replay reconstructed from persisted platform audit event types.",
      duration_s: +(frames.length * step).toFixed(1),
      fps: 30,
      frames,
      non_claims: ["read-only audit projection", "no prompt or user identifiers", "no secret values"],
    };
  } catch {
    return null;
  }
}

/** GET /api/v1/organism/replay — a timeline reconstructed from the agent-api
 *  activity trace (event_type → hub/run_state) when reachable, else spec-only. */
export async function GET(request: Request) {
  const runId = safeTraceId(new URL(request.url).searchParams.get("run_id"));
  const projectedRuntime = projectedRuntimeReplay(runId);
  if (projectedRuntime) return organismResponse(projectedRuntime);
  const projection = await fetchOrganismProjection("replay", runId);
  if (
    projection?.contract_version === "organism-replay-v1" &&
    Array.isArray(projection.frames) &&
    projection.live === true
  ) {
    return organismResponse(projection);
  }
  const kinds = await fetchActivityKinds(8, runId);
  if (!kinds) return organismResponse((await realAuditReplay(runId)) ?? specOnlyReplay(runId));
  const step = 1.2;
  const frames = kinds.map((kind, i) => {
    const { hub, run_state, regions } = mapKind(kind);
    return { t: +(i * step).toFixed(1), run_state, active: [hub], regions, source_kind: "agent_api_redacted" };
  });
  return organismResponse({
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

import { HUBS } from "../../../../../components/organism/regionMap";

// Live when a backend is reachable, honest deterministic mock otherwise.
export const dynamic = "force-dynamic";
export const revalidate = 0;

/** Capability-hub architecture layer → agent-api cloud-layer id. */
const LAYER_TO_ID: Record<string, string> = {
  FE: "layer_1",
  ORC: "layer_2",
  AP: "layer_3",
  LLM: "layer_4",
  MCP: "layer_5",
  MEM: "layer_6",
  OBS: "layer_7",
};

const GATES = ["production_deploy", "provider_writes", "secret_output", "main_push"];

/** Deterministic mock — used on Vercel / whenever no agent-api is reachable. */
function mockSnapshot() {
  const active = new Set(["workbench", "agents", "memory"]);
  return {
    contract_version: "organism-live-state-v1",
    source: "mock",
    live: false,
    note: "Deterministic mock — no reachable agent-api (AGENT_API_INTERNAL_URL unset or down). Never a live provider call.",
    run_state: "planning",
    core: { pulse_hz: 1.7, intensity: 0.86 },
    hubs: HUBS.map((h, i) => ({
      id: h.id,
      layer: h.layer,
      status: active.has(h.id) ? "active" : "idle",
      throughput_pct: 18 + ((i * 11) % 70),
    })),
    gates_closed: GATES,
    non_claims: ["mock data, never a live provider call", "no secret values"],
  };
}

/** GET /api/v1/organism/live-state — derives hub state from the local agent-api
 *  `cloud-layer-readiness` contract when reachable, else returns the mock. */
export async function GET() {
  const base = process.env.AGENT_API_INTERNAL_URL?.replace(/\/$/, "");
  if (!base) return Response.json(mockSnapshot());
  try {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 1500);
    const res = await fetch(`${base}/api/v1/clouds/layers`, { cache: "no-store", signal: ctrl.signal });
    clearTimeout(timer);
    if (!res.ok) return Response.json(mockSnapshot());
    const body = (await res.json()) as unknown;
    const list = (Array.isArray(body) ? body : (body as { layers?: unknown[] })?.layers ?? []) as Array<{
      layer_id?: string;
      label?: string;
      status?: string;
    }>;
    if (!list.length) return Response.json(mockSnapshot());
    const statusOf = new Map(list.map((l) => [l.layer_id, l.status] as const));
    const verified = (code: string) => statusOf.get(LAYER_TO_ID[code]) === "live_verified";
    const allLive = list.every((l) => l.status === "live_verified");
    return Response.json({
      contract_version: "organism-live-state-v1",
      source: "agent-api",
      live: true,
      note: "Hub state derived from agent-api /api/v1/clouds/layers (local docker-compose runtime; LLM deterministic dry-run, no live provider calls).",
      run_state: allLive ? "executing" : "verifying",
      core: { pulse_hz: 1.7, intensity: 0.86 },
      hubs: HUBS.map((h, i) => ({
        id: h.id,
        layer: h.layer,
        status: verified(h.layer) ? "active" : "idle",
        throughput_pct: 18 + ((i * 11) % 70),
      })),
      layers: list.map((l) => ({ id: l.layer_id, label: l.label, status: l.status })),
      gates_closed: GATES,
      non_claims: ["local dry-run runtime, no live provider call", "no secret values"],
    });
  } catch {
    return Response.json(mockSnapshot());
  }
}

import { HUBS, LAYERS, REGIONS } from "../../../../../components/organism/regionMap";

export const dynamic = "force-static";

const regionSignals: Record<string, string[]> = {
  prefrontal: ["planning", "architecture", "goal_selection"],
  thalamus: ["routing", "approval", "context_switch"],
  hippocampus: ["memory_read", "memory_write", "resume"],
  amygdala: ["blocked", "risk", "secret_guard"],
  basal: ["tool_selection", "model_selection", "skill_selection"],
  cerebellum: ["verifying", "self_correction", "checks_passed"],
  motor: ["executing", "cli_action", "cloud_action"],
  sensory: ["file_read", "provider_status", "logs"],
  autonomic: ["health", "retry", "watchdog"],
  callosum: ["event_bus", "cross_agent_sync", "replay"],
};

export function GET() {
  return Response.json({
    contract_version: "organism-regions-v1",
    endpoint: "/api/v1/organism/regions",
    source: "static_runtime_contract",
    live: false,
    regions: REGIONS.map((region) => ({
      ...region,
      layer_no: LAYERS.find((layer) => layer.code === region.layer)?.no ?? null,
      signals: regionSignals[region.id] ?? [],
      hubs: HUBS.filter((hub) => hub.layer === region.layer).map((hub) => hub.id),
      secret_output: false,
      writes: false,
    })),
    non_claims: ["region definitions only", "no provider calls", "no secret values"],
  });
}

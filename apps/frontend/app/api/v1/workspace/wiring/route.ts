import {
  WORKSPACE_WIRING_CONTRACT_VERSION,
  WORKSPACE_WIRING_EVIDENCE_REF,
  workspaceWiringSurfaces,
} from "../../../../../lib/workspaceWiring";

export const dynamic = "force-static";

export function GET() {
  const surfaces = workspaceWiringSurfaces();

  return Response.json({
    contract_version: WORKSPACE_WIRING_CONTRACT_VERSION,
    endpoint: "/api/v1/workspace/wiring",
    evidence_ref: WORKSPACE_WIRING_EVIDENCE_REF,
    source: "static_runtime_contract",
    live: false,
    page_count: surfaces.length,
    surfaces,
    policy_checks: [
      "Each canonical workspace page maps to one architecture layer, one brain region, and one capability hub.",
      "Every page exposes deterministic data source and verifier references.",
      "All entries are read-only: writes=false, live=false, secretOutput=false.",
      "Topology edges must reference existing page, layer, region, hub, data-source, and verifier nodes.",
    ],
    non_claims: [
      "This endpoint does not execute verifier commands.",
      "This endpoint does not call live providers, mutate cloud state, or expose secrets.",
      "Local evidence remains DEV-ONLY and cannot close hosted staging or production gates.",
    ],
  });
}

import { WORKSPACE_PAGES } from "./nav";

export const REFERENCE_DESIGN_CONTRACT_VERSION = "reference-design-conformance-v1";
export const REFERENCE_DESIGN_EVIDENCE_REF = "reference_design_conformance_visible";

export const REFERENCE_ASSET_REQUIREMENTS = {
  rootImagesMin: 3,
  currentDesignScreenshotsMin: 15,
  motionVideosMin: 1,
} as const;

export const REFERENCE_DESIGN_RULES = {
  visualLanguage: "industrial-developer-workbench",
  cornerRadiusMaxPx: 16,
  cardRadiusMaxPx: 12,
  typography: ["Geist/Inter UI", "JetBrains Mono telemetry"],
  requiredSurfaces: ["22 canonical pages", "central workbench", "3D organism", "replay", "topology", "evidence"],
  forbidden: [
    "project-status-wall-on-workbench",
    "fake-live-data",
    "secret-output",
    "cartoon-bubble-cards",
    "retired-provider-defaults",
  ],
} as const;

export function referenceDesignContract() {
  return {
    contract_version: REFERENCE_DESIGN_CONTRACT_VERSION,
    endpoint: "/api/v1/design/reference-contract",
    evidence_ref: REFERENCE_DESIGN_EVIDENCE_REF,
    source: "static_runtime_contract",
    live: false,
    reference_roots: ["docs/reference", "docs/reference/aktuell desin"],
    required_asset_inventory: REFERENCE_ASSET_REQUIREMENTS,
    design_rules: REFERENCE_DESIGN_RULES,
    page_count: WORKSPACE_PAGES.length,
    expected_page_count: 22,
    pages: WORKSPACE_PAGES.map((page) => ({
      id: page.id,
      no: page.no,
      route: page.route,
      layer: page.layer,
    })),
    organism_requirements: {
      canvas: "real-time 3D cognitive organism",
      regions: ["prefrontal", "thalamus", "hippocampus", "amygdala", "basal", "cerebellum", "motor", "sensory", "autonomic", "callosum"],
      event_kinds: ["planning", "executing", "tool_call", "llm_call", "memory_read", "memory_write", "verifying", "blocked"],
      replay_required: true,
      no_fake_live: true,
    },
    non_claims: [
      "This contract does not claim pixel-perfect visual completion.",
      "This contract does not execute browser screenshots or image comparison.",
      "This contract does not mutate cloud state, call live providers, or expose secrets.",
      "Local evidence remains DEV-ONLY until hosted staging verification exists.",
    ],
  };
}

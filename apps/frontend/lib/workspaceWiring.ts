import { HUBS, REGIONS } from "../components/organism/regionMap";
import { WORKSPACE_PAGES, type NavItem } from "./nav";

export const WORKSPACE_WIRING_CONTRACT_VERSION = "workspace-surface-wiring-v1";
export const WORKSPACE_WIRING_EVIDENCE_REF = "workspace_surface_wiring_visible";

type PageId = NavItem["id"];
type LayerCode = NavItem["layer"];
type BrainRegionId = (typeof REGIONS)[number]["id"];
type HubId = (typeof HUBS)[number]["id"];

export type WorkspaceSurfaceWiring = {
  pageId: PageId;
  brainRegion: BrainRegionId;
  hub: HubId;
  primaryMode: "navigate" | "create" | "inspect" | "verify" | "govern";
  dataSources: string[];
  verifierRefs: string[];
  eventKinds: Array<"planning" | "executing" | "tool_call" | "llm_call" | "memory_read" | "memory_write" | "verifying" | "blocked">;
  live: false;
  writes: false;
  secretOutput: false;
};

const commonVerifierRefs = [
  "scripts/verify-workspace-pages-layer-map.ps1",
  "scripts/verify-browser-contract.ps1",
] as const;

export const WORKSPACE_WIRING: WorkspaceSurfaceWiring[] = [
  {
    pageId: "home",
    brainRegion: "sensory",
    hub: "workbench",
    primaryMode: "navigate",
    dataSources: ["WORKSPACE_PAGES", "/api/v1/clouds", "/api/v1/project/progress/integrity"],
    verifierRefs: [...commonVerifierRefs],
    eventKinds: ["planning", "blocked"],
    live: false,
    writes: false,
    secretOutput: false,
  },
  {
    pageId: "login",
    brainRegion: "amygdala",
    hub: "workbench",
    primaryMode: "govern",
    dataSources: ["/api/v1/auth/contract", "/api/v1/auth/github", "/api/v1/audit/recent"],
    verifierRefs: [...commonVerifierRefs, "scripts/verify-phase1-runtime.ps1"],
    eventKinds: ["verifying", "blocked"],
    live: false,
    writes: false,
    secretOutput: false,
  },
  {
    pageId: "workbench",
    brainRegion: "prefrontal",
    hub: "workbench",
    primaryMode: "create",
    dataSources: ["/api/v1/phase2/runtime/contract", "/api/v1/orchestrator/manifest/contract", "/api/v1/platform/verify"],
    verifierRefs: [...commonVerifierRefs, "apps/frontend/e2e/organism.spec.ts"],
    eventKinds: ["planning", "executing", "verifying"],
    live: false,
    writes: false,
    secretOutput: false,
  },
  {
    pageId: "organism",
    brainRegion: "callosum",
    hub: "workbench",
    primaryMode: "inspect",
    dataSources: ["/api/v1/organism/contract", "/api/v1/organism/live-state", "/organism/core.glb"],
    verifierRefs: [...commonVerifierRefs, "apps/frontend/e2e/organism.spec.ts"],
    eventKinds: ["planning", "executing", "tool_call", "llm_call", "memory_read", "memory_write", "verifying", "blocked"],
    live: false,
    writes: false,
    secretOutput: false,
  },
  {
    pageId: "organism-replay",
    brainRegion: "hippocampus",
    hub: "observe",
    primaryMode: "inspect",
    dataSources: ["/api/v1/organism/replay", "/api/v1/organism/events"],
    verifierRefs: [...commonVerifierRefs, "apps/frontend/e2e/organism.spec.ts"],
    eventKinds: ["memory_read", "verifying", "blocked"],
    live: false,
    writes: false,
    secretOutput: false,
  },
  {
    pageId: "organism-map",
    brainRegion: "thalamus",
    hub: "cloud",
    primaryMode: "inspect",
    dataSources: ["/api/v1/organism/topology", "/api/v1/organism/regions", "/api/v1/organism/safety"],
    verifierRefs: [...commonVerifierRefs, "apps/frontend/e2e/organism.spec.ts"],
    eventKinds: ["planning", "verifying", "blocked"],
    live: false,
    writes: false,
    secretOutput: false,
  },
  {
    pageId: "agents",
    brainRegion: "motor",
    hub: "agents",
    primaryMode: "inspect",
    dataSources: ["/api/v1/agents/status", "/api/v1/agent-activity/recent", "/api/v1/tasks/assignment-contract"],
    verifierRefs: [...commonVerifierRefs, "scripts/verify-phase1-runtime.ps1"],
    eventKinds: ["planning", "executing", "verifying", "blocked"],
    live: false,
    writes: false,
    secretOutput: false,
  },
  {
    pageId: "files",
    brainRegion: "hippocampus",
    hub: "memory",
    primaryMode: "inspect",
    dataSources: ["/api/v1/memory/search", "/api/v1/memory/consolidation/recent", "/api/v1/memory/embedding-consistency/contract"],
    verifierRefs: [...commonVerifierRefs, "scripts/verify-phase1-runtime.ps1"],
    eventKinds: ["memory_read", "memory_write", "verifying"],
    live: false,
    writes: false,
    secretOutput: false,
  },
  {
    pageId: "files-local",
    brainRegion: "sensory",
    hub: "memory",
    primaryMode: "inspect",
    dataSources: ["/api/v1/files/local/contract", "filesystem_workspace_scope_contract", "read_only_file_tree"],
    verifierRefs: [...commonVerifierRefs, "scripts/verify-phase1.ps1"],
    eventKinds: ["memory_read", "tool_call", "blocked"],
    live: false,
    writes: false,
    secretOutput: false,
  },
  {
    pageId: "tools",
    brainRegion: "basal",
    hub: "tools",
    primaryMode: "inspect",
    dataSources: ["/mcp/api/v1/version-pinning/contract", "/api/v1/audit/mcp", "MCP_TOOLS"],
    verifierRefs: [...commonVerifierRefs, "scripts/verify-phase1-runtime.ps1"],
    eventKinds: ["tool_call", "verifying", "blocked"],
    live: false,
    writes: false,
    secretOutput: false,
  },
  {
    pageId: "marketplace",
    brainRegion: "basal",
    hub: "models",
    primaryMode: "inspect",
    dataSources: ["MODELS", "SKILLS", "/api/v1/models/capabilities"],
    verifierRefs: [...commonVerifierRefs, "scripts/verify-phase1-runtime.ps1"],
    eventKinds: ["llm_call", "tool_call", "blocked"],
    live: false,
    writes: false,
    secretOutput: false,
  },
  {
    pageId: "observe",
    brainRegion: "autonomic",
    hub: "observe",
    primaryMode: "inspect",
    dataSources: ["/api/v1/metrics", "/api/v1/health", "/api/v1/clouds/layers"],
    verifierRefs: [...commonVerifierRefs, "scripts/verify-phase1-runtime.ps1"],
    eventKinds: ["verifying", "blocked"],
    live: false,
    writes: false,
    secretOutput: false,
  },
  {
    pageId: "games",
    brainRegion: "motor",
    hub: "workbench",
    primaryMode: "create",
    dataSources: ["/workbench", "/organism/core.glb", "game_preview_mode"],
    verifierRefs: [...commonVerifierRefs, "npm run test:e2e --prefix apps/frontend"],
    eventKinds: ["planning", "executing", "tool_call", "verifying"],
    live: false,
    writes: false,
    secretOutput: false,
  },
  {
    pageId: "apps",
    brainRegion: "motor",
    hub: "workbench",
    primaryMode: "create",
    dataSources: ["/workbench", "app_preview_mode", "/api/v1/platform/verify"],
    verifierRefs: [...commonVerifierRefs, "npm run test:e2e --prefix apps/frontend"],
    eventKinds: ["planning", "executing", "tool_call", "verifying"],
    live: false,
    writes: false,
    secretOutput: false,
  },
  {
    pageId: "media",
    brainRegion: "sensory",
    hub: "models",
    primaryMode: "create",
    dataSources: ["media_preview_mode", "MODELS", "/api/v1/models/capabilities"],
    verifierRefs: [...commonVerifierRefs, "npm run test:e2e --prefix apps/frontend"],
    eventKinds: ["llm_call", "executing", "verifying", "blocked"],
    live: false,
    writes: false,
    secretOutput: false,
  },
  {
    pageId: "docs-output",
    brainRegion: "hippocampus",
    hub: "memory",
    primaryMode: "create",
    dataSources: ["docs_output_mode", "/api/v1/memory/search", "/api/v1/sessions/recent"],
    verifierRefs: [...commonVerifierRefs, "npm run test:e2e --prefix apps/frontend"],
    eventKinds: ["memory_read", "memory_write", "executing", "verifying"],
    live: false,
    writes: false,
    secretOutput: false,
  },
  {
    pageId: "evidence",
    brainRegion: "cerebellum",
    hub: "observe",
    primaryMode: "verify",
    dataSources: ["/api/v1/external-gates", "/api/v1/project/progress/integrity", "docs/verification-register.md"],
    verifierRefs: [...commonVerifierRefs, "scripts/verify-phase1.ps1", "gitleaks detect --no-git --source ."],
    eventKinds: ["verifying", "blocked"],
    live: false,
    writes: false,
    secretOutput: false,
  },
  {
    pageId: "diagnostics",
    brainRegion: "amygdala",
    hub: "observe",
    primaryMode: "verify",
    dataSources: ["/api/v1/audit/recent", "/api/v1/escalations/recent", ".phase1-artifacts"],
    verifierRefs: [...commonVerifierRefs, "scripts/verify-retired-hosted-boundary.ps1"],
    eventKinds: ["verifying", "blocked"],
    live: false,
    writes: false,
    secretOutput: false,
  },
  {
    pageId: "design-system",
    brainRegion: "sensory",
    hub: "workbench",
    primaryMode: "inspect",
    dataSources: ["apps/frontend/app/styles.css", "WORKSPACE_PAGES", "NeuroGlass tokens"],
    verifierRefs: [...commonVerifierRefs, "npm run lint --prefix apps/frontend"],
    eventKinds: ["planning", "verifying"],
    live: false,
    writes: false,
    secretOutput: false,
  },
  {
    pageId: "stack",
    brainRegion: "thalamus",
    hub: "cloud",
    primaryMode: "inspect",
    dataSources: ["docs/system-architecture.md", "/api/v1/clouds", "/api/v1/clouds/deployment-preflight"],
    verifierRefs: [...commonVerifierRefs, "scripts/verify-phase1.ps1"],
    eventKinds: ["planning", "verifying", "blocked"],
    live: false,
    writes: false,
    secretOutput: false,
  },
  {
    pageId: "settings",
    brainRegion: "amygdala",
    hub: "tools",
    primaryMode: "govern",
    dataSources: ["/api/v1/clouds/deployment-preflight", "/api/v1/auth/contract", "CLOSED_GATES"],
    verifierRefs: [...commonVerifierRefs, "scripts/verify-owner-cloud-gate-activation.ps1"],
    eventKinds: ["blocked", "verifying"],
    live: false,
    writes: false,
    secretOutput: false,
  },
  {
    pageId: "open-source",
    brainRegion: "callosum",
    hub: "cloud",
    primaryMode: "navigate",
    dataSources: ["package.json", "LICENSE", "docs/verification-register.md"],
    verifierRefs: [...commonVerifierRefs, "scripts/verify-phase1.ps1"],
    eventKinds: ["planning", "verifying"],
    live: false,
    writes: false,
    secretOutput: false,
  },
];

const pageById = new Map(WORKSPACE_PAGES.map((page) => [page.id, page]));
const regionIds = new Set(REGIONS.map((region) => region.id));
const hubIds = new Set(HUBS.map((hub) => hub.id));

export function workspaceWiringSurfaces() {
  return WORKSPACE_WIRING.map((wiring) => {
    const page = pageById.get(wiring.pageId);
    if (!page) {
      throw new Error(`Workspace wiring references unknown page '${wiring.pageId}'.`);
    }
    if (!regionIds.has(wiring.brainRegion)) {
      throw new Error(`Workspace wiring references unknown brain region '${wiring.brainRegion}'.`);
    }
    if (!hubIds.has(wiring.hub)) {
      throw new Error(`Workspace wiring references unknown hub '${wiring.hub}'.`);
    }
    return {
      ...wiring,
      no: page.no,
      label: page.label,
      route: page.route,
      layer: page.layer as LayerCode,
      evidenceRef: WORKSPACE_WIRING_EVIDENCE_REF,
    };
  }).sort((a, b) => a.no - b.no);
}

export function workspaceWiringForPage(pageId: PageId) {
  return workspaceWiringSurfaces().find((surface) => surface.pageId === pageId) ?? null;
}

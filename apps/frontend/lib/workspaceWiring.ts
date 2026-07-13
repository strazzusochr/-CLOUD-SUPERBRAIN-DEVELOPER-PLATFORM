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
    dataSources: ["/api/v1/phase2/runtime/contract", "/api/v1/orchestrator/manifest/contract", "/api/v1/platform/verify", "/api/v1/orchestrator/checkpoints/contract", "/api/v1/orchestrator/dry-run", "/api/v1/orchestrator/dry-run/contract", "/api/v1/orchestrator/dry-run/stream", "/api/v1/orchestrator/dry-run/stream/contract", "/api/v1/orchestrator/manifest", "/api/v1/phase2/runtime/runs", "/api/v1/phase2/runtime/runs/contract", "/api/v1/phase2/runtime/start", "/api/v1/phase2/runtime/start/contract", "/api/v1/trace/contract"],
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
    dataSources: ["/api/v1/organism/contract", "/api/v1/organism/live-state", "/api/v1/phase6/3d-camera-lighting/contract", "/api/v1/phase6/3d-gameplay-state/contract", "/api/v1/phase6/3d-asset-policy/contract", "/api/v1/phase6/3d-save-load/contract", "/api/v1/phase6/3d-accessibility/contract", "/api/v1/phase6/3d-netcode/contract", "/api/v1/phase6/local-scoreboard-performance/contract", "/organism/core.glb"],
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
    dataSources: ["/api/v1/agents/status", "/api/v1/agent-activity/recent", "/api/v1/tasks/assignment-contract", "/api/v1/agent-activity/contract", "/api/v1/agents/llm-streaming-contract", "/api/v1/agents/profiles", "/api/v1/agents/profiles/contract", "/api/v1/live-agents/contract", "/api/v1/live-agents/status", "/api/v1/live-agents/steer", "/api/v1/task/dispatch/contract", "/api/v1/task/dispatches/recent", "/api/v1/tasks/policy", "/api/v1/tasks/policy/contract", "/api/v1/tasks/policy/validate", "/api/v1/tasks/recent", "/api/v1/tasks/recent/contract", "/api/v1/team/master-plan", "/api/v1/team/master-plan/contract", "/api/v1/team/roster", "/api/v1/team/roster/contract", "/api/v1/team/status", "/api/v1/team/status/contract"],
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
    dataSources: ["/api/v1/memory/search", "/api/v1/memory/consolidation/recent", "/api/v1/memory/embedding-consistency/contract", "/api/v1/cache/contract", "/api/v1/memory/consolidation/contract", "/api/v1/memory/purge/contract", "/api/v1/memory/purge/jobs/contract", "/api/v1/session-limits/contract", "/api/v1/session-limits/status", "/api/v1/session/stream/contract", "/api/v1/sessions/history/contract"],
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
    dataSources: ["/mcp/api/v1/version-pinning/contract", "/api/v1/audit/mcp", "MCP_TOOLS", "/api/v1/prompt/contract", "/api/v1/tools/read-only/execute", "/api/v1/tools/read-only/execute/contract"],
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
    dataSources: ["/api/v1/metrics", "/api/v1/health", "/api/v1/clouds/layers", "/api/v1/budget", "/api/v1/budget/contract", "/api/v1/costs", "/api/v1/costs/contract", "/api/v1/costs/export", "/api/v1/costs/export/contract", "/api/v1/infra/budget", "/api/v1/infra/budget/contract", "/api/v1/rate-limit/contract", "/api/v1/rate-limit/status", "/api/v1/rotation/events", "/api/v1/rotation/events/contract", "/api/v1/rotation/policy", "/api/v1/rotation/policy/contract", "/api/v1/system/fallback/contract"],
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
    dataSources: ["/api/v1/audit/recent", "/api/v1/escalations/recent", ".phase1-artifacts", "/api/v1/errors/contract", "/api/v1/escalations/contract", "/api/v1/layer-interfaces/contract", "/api/v1/orchestrator/completion/contract", "/api/v1/release-candidate/local/contract", "/api/v1/request/contract", "/api/v1/security/headers/contract", "/api/v1/security/csp/contract", "/api/v1/security/csrf/contract", "/api/v1/security/cross-origin/contract", "/api/v1/workspace/artifacts", "/api/v1/workspace/artifacts/contract", "/api/v1/workspace/vertical-stack", "/api/v1/workspace/wiring", "/api/v1/platform/inventory"],
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
    dataSources: ["apps/frontend/app/styles.css", "WORKSPACE_PAGES", "NeuroGlass tokens", "/api/v1/design/reference-contract"],
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
    dataSources: ["docs/system-architecture.md", "/api/v1/clouds", "/api/v1/clouds/deployment-preflight", "/api/v1/devops/workflow-dispatch/plan", "/api/v1/devops/workflow-dispatch/plan/contract", "/api/v1/devops/workflow-dispatch/validate", "/api/v1/devops/workflow-dispatch/validate/contract", "/api/v1/project/progress", "/api/v1/project/progress/completion", "/api/v1/project/progress/completion/contract", "/api/v1/project/progress/contract", "/api/v1/project/progress/layers", "/api/v1/project/progress/layers/contract"],
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
    dataSources: ["/api/v1/clouds/deployment-preflight", "/api/v1/auth/contract", "CLOSED_GATES", "/api/v1/auth/callback", "/api/v1/auth/logout", "/api/v1/auth/refresh"],
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

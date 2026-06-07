/* ------------------------------------------------------------------
 * Real platform data, mirrored from the backend truth so the UI shows
 * actual structure instead of mock content.
 *   - Agents:    services/agent-api/app/models.py  (AGENT_PROFILES, agent-profiles-v1)
 *   - Services:  PROJECT_STATE.md  (cloud-superbrain-phase1-dev containers)
 *   - Surfaces:  services/agent-api/app/main.py  (@app.get/@app.post routes)
 * Live values come from these endpoints at runtime; this module carries the
 * deterministic contract shape only — never secrets, never fake-live numbers.
 * ------------------------------------------------------------------ */

export interface AgentProfile {
  type: string;
  role: string;
  model: string;
  fallbacks: string[];
  tools: string[];
  maxExecSec: number;
  maxOutTokens: number;
  maxRetries: number;
  humanReview: string[];
  escalation: string[];
  degradation: string;
}

/** The 4 deterministic agent profiles (agent-profiles-v1). */
export const AGENTS: AgentProfile[] = [
  {
    type: "planner",
    role: "Task decomposition, intent classification, and safe route planning.",
    model: "deepseek-ai/DeepSeek-V4-Pro",
    fallbacks: ["Qwen3.6-35B-A3B", "moonshotai/Kimi-K2.6"],
    tools: ["memory_read", "task_router", "langgraph"],
    maxExecSec: 60,
    maxOutTokens: 4096,
    maxRetries: 5,
    humanReview: ["architecture_change", "budget_limit_change"],
    escalation: ["architecture_decision_required", "budget_guard_rejected", "forbidden_intent_detected"],
    degradation: "If routing is uncertain, stop with explicit uncertainty and request human review.",
  },
  {
    type: "coder",
    role: "Feature implementation on scoped branches with no direct main writes.",
    model: "Qwen/Qwen3-Coder-Next",
    fallbacks: ["DeepSeek-V4-Flash", "gemma-4-31B-it"],
    tools: ["memory_read", "github_mcp", "filesystem_mcp", "mcp_gateway"],
    maxExecSec: 300,
    maxOutTokens: 8192,
    maxRetries: 5,
    humanReview: ["merge_main", "production_deploy", "schema_change"],
    escalation: ["write_scope_missing", "branch_policy_violation", "three_same_failures"],
    degradation: "If GitHub/filesystem scope is unavailable, return a patch plan and do not claim implementation.",
  },
  {
    type: "tester",
    role: "Verification, deterministic runtime checks, and E2B-gated sandbox proof when available.",
    model: "google/gemma-4-26B-A4B-it",
    fallbacks: ["Qwen3.5-9B", "Llama-3.1-8B-Instruct"],
    tools: ["memory_read", "e2b_mcp", "playwright_mcp", "filesystem_mcp", "mcp_gateway"],
    maxExecSec: 600,
    maxOutTokens: 4096,
    maxRetries: 5,
    humanReview: ["release_approval", "security_exception"],
    escalation: ["test_failed_after_retry", "e2b_unavailable_for_required_sandbox", "missing_runtime_evidence"],
    degradation: "If E2B is unavailable, disable sandbox-only tests, warn, and continue deterministic Docker/browser checks.",
  },
  {
    type: "devops",
    role: "CI/CD, Docker, deployment runbooks, and GitHub Actions dispatch without direct production SSH.",
    model: "deepseek-ai/DeepSeek-V4-Flash",
    fallbacks: ["Qwen3.6-35B-A3B", "gemma-4-31B-it"],
    tools: ["memory_read", "github_mcp", "mcp_gateway"],
    maxExecSec: 120,
    maxOutTokens: 4096,
    maxRetries: 5,
    humanReview: ["workflow_dispatch_production", "rollback_production", "resource_limit_increase"],
    escalation: ["production_deploy_requested", "missing_branch_protection_token", "rollback_not_tested"],
    degradation: "If GitHub Actions dispatch is unavailable, emit the exact workflow payload and keep deployment blocked.",
  },
];

export interface McpTool {
  id: string;
  label: string;
  layer: number;
  scope: "read" | "scoped_write" | "gated";
}

/** MCP tools the agent profiles are allowed to use (allowed_tools). */
export const MCP_TOOLS: McpTool[] = [
  { id: "memory_read", label: "Memory Read", layer: 6, scope: "read" },
  { id: "task_router", label: "Task Router", layer: 2, scope: "read" },
  { id: "langgraph", label: "LangGraph", layer: 2, scope: "read" },
  { id: "mcp_gateway", label: "MCP Gateway", layer: 5, scope: "gated" },
  { id: "github_mcp", label: "GitHub MCP", layer: 5, scope: "scoped_write" },
  { id: "filesystem_mcp", label: "Filesystem MCP", layer: 5, scope: "scoped_write" },
  { id: "playwright_mcp", label: "Playwright MCP", layer: 5, scope: "gated" },
  { id: "e2b_mcp", label: "E2B Sandbox MCP", layer: 5, scope: "gated" },
];

export interface Service {
  name: string;
  layer: number;
}

/** Runtime containers (cloud-superbrain-phase1-dev). */
export const SERVICES: Service[] = [
  { name: "nginx", layer: 1 },
  { name: "frontend", layer: 1 },
  { name: "agent-api", layer: 2 },
  { name: "agent-worker", layer: 3 },
  { name: "llm-gateway", layer: 4 },
  { name: "mcp-gateway", layer: 5 },
  { name: "memory-worker", layer: 6 },
  { name: "postgres", layer: 6 },
  { name: "redis", layer: 6 },
];

export interface SurfaceGroup {
  group: string;
  endpoints: string[];
}

/** Real backend API surfaces (GET unless noted), grouped by concern. */
export const API_SURFACES: SurfaceGroup[] = [
  { group: "Health & Run State", endpoints: ["/api/v1/health", "/api/v1/agents/status", "/api/v1/tasks/recent", "/api/v1/sessions/recent", "POST /api/v1/prompt", "/api/v1/session/{id}/stream"] },
  { group: "Project Progress", endpoints: ["/api/v1/project/progress", "/api/v1/project/progress/layers", "/api/v1/project/progress/integrity", "/api/v1/project/progress/completion"] },
  { group: "Cloud", endpoints: ["/api/v1/clouds", "/api/v1/clouds/layers", "/api/v1/clouds/render-offload", "/api/v1/clouds/deployment-preflight"] },
  { group: "Gates", endpoints: ["/api/v1/external-gates", "/api/v1/external-gates/mirror"] },
  { group: "Observability", endpoints: ["/api/v1/metrics/contract", "/api/v1/costs", "/api/v1/budget", "/api/v1/audit/recent", "/api/v1/audit/mcp", "/api/v1/escalations/recent", "/api/v1/trace/contract", "/api/v1/rate-limit/status"] },
  { group: "Memory", endpoints: ["/api/v1/memory/search", "/api/v1/memory/consolidation/recent", "/api/v1/memory/purge/jobs/{id}"] },
];

/* ------------------------------------------------------------------
 * Project manifest snapshot (PROJECT_STATE.md / docs/project-progress.manifest.json,
 * dated 2026-05-07). Live values come from GET /api/v1/project/progress and
 * /api/v1/project/progress/layers — these are the dated manifest figures, shown
 * only on /diagnostics (never on Home/Workbench as a hero).
 * ------------------------------------------------------------------ */
export const MANIFEST = {
  snapshot: "2026-05-07",
  overall: 70,
  integrity: "verified",
  modules: [
    { name: "Frontend", layer: 1, pct: 97 },
    { name: "Orchestrator", layer: 2, pct: 99 },
    { name: "Agent Pool", layer: 3, pct: 68 },
    { name: "LLM Gateway", layer: 4, pct: 54 },
    { name: "MCP Gateway", layer: 5, pct: 55 },
    { name: "Memory", layer: 6, pct: 72 },
    { name: "Observability", layer: 7, pct: 99 },
  ],
  phases: [
    { id: "P0", pct: 100 },
    { id: "P1", pct: 100 },
    { id: "P2", pct: 86 },
    { id: "P3", pct: 40 },
    { id: "P4", pct: 100 },
    { id: "P5", pct: 67 },
    { id: "P6", pct: 0 },
  ],
} as const;

/** Real verifier scripts in the repo (scripts/*). */
export const VERIFIERS = [
  "scripts/verify-phase1.ps1",
  "scripts/verify-phase5-candidate.ps1",
  "scripts/verify_project_progress_manifest.py",
  "scripts/verify-external-gates.ps1",
  "scripts/verify-browser-contract.ps1",
];

/** The dangerous gates that stay closed by default (settings governance). */
export const CLOSED_GATES = [
  "Production deploy",
  "Release promotion",
  "Provider writes",
  "Main push",
  "Registry push",
  "Live MCP write",
  "Live LLM call",
  "Secret output",
];

/** Platform skills (deterministic capabilities the agents compose). */
export const SKILLS = [
  { id: "strict-project-gate", purpose: "Path gate — no project write without an explicit gate." },
  { id: "product-ux-guardian", purpose: "Home/Workbench stay product surfaces, not an audit hero." },
  { id: "live-3d-organism-architect", purpose: "Cortex canvas, brain regions, synapse flows." },
  { id: "r3f-three-engineer", purpose: "R3F/three.js: canvas, GLB loader, instancing, bloom." },
  { id: "blender-gltf-pipeline", purpose: "Blender → GLB → glTF Transform → gltfjsx." },
  { id: "mcp-safety-auditor", purpose: "MCP servers, scopes, secrets and writes review." },
  { id: "visual-verifier", purpose: "Playwright screenshots, visual diff, responsive checks." },
  { id: "accessibility-reduced-motion", purpose: "A11y, reduced motion, keyboard, contrast." },
  { id: "telemetry-binding-engineer", purpose: "OpenTelemetry → cortex visual signals." },
  { id: "opa-gate-engineer", purpose: "can_write / can_deploy / can_push local policy gates." },
];

/** Models pinned by the agent profiles (primary, per agent). */
export const MODELS = [
  { id: "deepseek-ai/DeepSeek-V4-Pro", role: "Planner primary" },
  { id: "Qwen/Qwen3-Coder-Next", role: "Coder primary" },
  { id: "google/gemma-4-26B-A4B-it", role: "Tester primary" },
  { id: "deepseek-ai/DeepSeek-V4-Flash", role: "DevOps primary" },
];

/** Read-only scoped roots for the local files surface. */
export const FILE_ROOTS = ["project", "workspace", "documents", "codex_runs", "codex_skills"];

/** Spec top-level project tree (read-only intent; runtime wiring may be unavailable). */
export const PROJECT_TREE: { d: number; name: string; folder?: boolean }[] = [
  { d: 0, name: "-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM", folder: true },
  { d: 1, name: "apps", folder: true },
  { d: 2, name: "frontend", folder: true },
  { d: 1, name: "services", folder: true },
  { d: 2, name: "agent-api", folder: true },
  { d: 1, name: "docs", folder: true },
  { d: 1, name: "scripts", folder: true },
  { d: 1, name: "AGENTS.md" },
  { d: 1, name: "PROJECT_STATE.md" },
  { d: 1, name: "README.md" },
  { d: 1, name: "docker-compose.cloud.yml" },
];

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

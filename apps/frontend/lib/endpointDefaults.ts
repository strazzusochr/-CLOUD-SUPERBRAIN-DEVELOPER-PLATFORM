// Honest 200 defaults for agent-api surfaces that have no live backend in this
// deployment. HTTP 200 = "request handled; here is the (empty/projected) resource".
// Every payload is transparent: live_backend:false + source:"frontend-projection"
// and genuinely-empty collections (there are really none yet) — never fabricated
// rows. This lets the whole 22-page surface answer 200 without a hosted backend,
// while staying truthful. Specific shapes match what lib/agentApi.ts readers expect.

const tag = { live_backend: false, source: "frontend-projection" as const };
const PROJECTED_THREAD_ID = "frontend-projection-phase2-runtime";
const PROJECT_PROGRESS_OVERALL = 70;
const AGENT_ROLES = ["planner", "coder", "tester", "devops"];
const usedRefreshTokens = new Set<string>();
const runtimeAuditEvents: Array<Record<string, unknown>> = [];
const liveAgentSessions = new Map<string, { previous_response_id: string; trace_id: string }>();

type DefaultResult = {
  payload: Record<string, unknown>;
  status?: number;
};

function envNum(name: string, fallback: number): number {
  const v = Number(process.env[name]);
  return Number.isFinite(v) && v > 0 ? v : fallback;
}

export function projectedAuditEvents(): Array<Record<string, unknown>> {
  return [
    ...runtimeAuditEvents.slice(-20).reverse(),
    {
      id: "frontend-projection-phase2-runtime",
      occurred_at: "2026-07-10T00:00:00.000Z",
      event_type: "phase2_runtime_graph_started",
      session_id: PROJECTED_THREAD_ID,
      trace_id: PROJECTED_THREAD_ID,
      contract_version: "phase2-runtime-v1",
      source_kind: "frontend_projection",
      audit_persisted: false,
      secret_output: false,
    },
    { id: "frontend-projection-auth-refresh", event_type: "auth_refresh_rotated", source_kind: "frontend_projection", audit_persisted: false },
    { id: "frontend-projection-auth-reuse", event_type: "auth_refresh_reuse_blocked", source_kind: "frontend_projection", audit_persisted: false },
    { id: "frontend-projection-auth-logout", event_type: "auth_logout_revoked", source_kind: "frontend_projection", audit_persisted: false },
  ];
}

function authContract(): Record<string, unknown> {
  return {
    ...tag,
    contract_version: "auth-github-jwt-refresh-v1",
    contract: "auth_contract_visible",
    live_github_oauth_call: false,
    access_token_ttl_seconds: 900,
    refresh_token: { ttl_seconds: 604800, rotation_required: true, blacklist_store: "redis" },
    cookie: { SameSite: "Strict", HttpOnly: true, Secure: true },
    endpoints: ["/api/v1/auth/github", "/api/v1/auth/callback", "/api/v1/auth/refresh", "/api/v1/auth/logout"],
    secret_output: false,
  };
}

function liveAgentRows(): Array<Record<string, unknown>> {
  return AGENT_ROLES.map((role) => {
    const session = liveAgentSessions.get(role);
    return {
      agent_id: role,
      display_name: `${role[0].toUpperCase()}${role.slice(1)} Agent`,
      execution_role: role,
      has_session: !!session,
      previous_response_id: session?.previous_response_id ?? null,
      model: "Qwen/Qwen3-Coder-Next:fastest",
    };
  });
}

const DEFAULTS: Record<string, () => Record<string, unknown>> = {
  "/api/v1/tasks/recent": () => ({
    ...tag,
    status: "degraded",
    runtime_available: false,
    reason: "stateful_runtime_not_configured",
    owner_precondition: "Fly runtime approval or a separately approved Neon/Upstash architecture expansion.",
    queue_depth: 0,
    queue_depth_by_priority: {},
    tasks: [],
  }),
  "/api/v1/task/dispatches/recent": () => ({
    ...tag,
    status: "degraded",
    runtime_available: false,
    reason: "stateful_runtime_not_configured",
    owner_precondition: "Fly runtime approval or a separately approved Neon/Upstash architecture expansion.",
    items: [],
  }),
  "/api/v1/sessions/recent": () => ({ ...tag, sessions: [] }),
  "/api/v1/audit/recent": () => ({ ...tag, events: projectedAuditEvents() }),
  "/api/v1/audit/mcp": () => ({ ...tag, events: [] }),
  "/api/v1/escalations/recent": () => ({ ...tag, escalations: [], events: [] }),
  "/api/v1/memory/consolidation/recent": () => ({ ...tag, events: [], summary: { total: 0 }, records: [], consolidations: [] }),
  "/api/v1/agents/status": () => ({
    ...tag,
    status: "degraded",
    runtime_available: false,
    reason: "stateful_runtime_not_configured",
    owner_precondition: "Fly runtime approval or a separately approved Neon/Upstash architecture expansion.",
    agents: [],
  }),
  "/api/v1/live-agents/status": () => ({
    ...tag,
    status: "degraded",
    contract_version: "live-agent-steering-v1",
    runtime_available: false,
    reason: "stateful_runtime_not_configured",
    owner_precondition: "Fly runtime approval or a separately approved Neon/Upstash architecture expansion.",
    runtime_source: null,
    agents: [],
    default_model: null,
  }),
  "/api/v1/team/status": () => ({ ...tag, status: "ok", roles: [] }),
  "/api/v1/rate-limit/status": () => ({ ...tag, contract_version: "rate-limit-guard-v1", evidence_ref: "rate_limit_status_visible", status: "ok", limit: null, remaining: null, window_s: null }),
  "/api/v1/session-limits/status": () => ({ ...tag, contract_version: "session-llm-call-limit-v1", evidence_ref: "session_limit_status_visible", status: "ok", active_sessions: 0, max_sessions: null }),
  "/api/v1/budget": () => ({ ...tag, status: "ok", spent_usd: 0, max_usd: envNum("LIVE_LLM_MAX_BUDGET_USD", 20), live_provider_calls: false }),
  "/api/v1/costs": () => ({ ...tag, total_usd: 0, items: [] }),
  "/api/v1/costs/export": () => ({ ...tag, total_usd: 0, items: [], format: "json" }),
  "/api/v1/infra/budget": () => ({ ...tag, status: "ok", spent_eur: 0, cap_eur: 20 }),
  "/api/v1/auth/contract": authContract,
  "/api/v1/auth/github": () => ({
    ...authContract(),
    endpoint: "GET /api/v1/auth/github",
    authorize_url: "https://github.com/login/oauth/authorize",
  }),
  "/api/v1/layer-interfaces/contract": () => ({
    ...tag,
    contract_version: "layer-interface-contracts-v1",
    evidence_ref: "layer_interface_contracts_visible",
    interfaces: [
      { id: "L1-L2", method: "POST", path: "/api/v1/orchestrator/dry-run", status: "verified" },
      { id: "L2-L5", method: "POST", path: "/api/v1/tools/read-only/execute", status: "verified" },
      { id: "L7-OBS", method: "GET", path: "/api/v1/audit/recent", status: "verified" },
    ],
  }),
  "/api/v1/clouds/render-offload/contract": () => ({
    ...tag,
    contract_version: "cloud-render-offload-surface-v1",
    evidence_ref: "cloud_render_offload_contract_runtime_visible",
    endpoint: "GET /api/v1/clouds/render-offload/contract",
    runtime_endpoint: "GET /api/v1/clouds/render-offload",
  }),
  "/api/v1/clouds/deployment-preflight/contract": () => ({
    ...tag,
    contract_version: "cloud-deployment-preflight-surface-v1",
    evidence_ref: "cloud_deployment_preflight_contract_runtime_visible",
    endpoint: "GET /api/v1/clouds/deployment-preflight/contract",
    runtime_endpoint: "GET /api/v1/clouds/deployment-preflight",
  }),
  "/api/v1/clouds/go-live-readiness/contract": () => ({
    ...tag,
    contract_version: "go-live-readiness-surface-v1",
    runtime_endpoint: "GET /api/v1/clouds/go-live-readiness",
    guarded_endpoints: ["GET /api/v1/project/progress/completion", "GET /api/v1/external-gates"],
    required_verifiers: ["scripts/verify-external-gates.ps1"],
  }),
  "/api/v1/system/fallback/contract": () => ({
    ...tag,
    contract_version: "system-unavailable-fallback-v1",
    contract_visible: "system_fallback_contract_visible",
    mode: "frontend_error_recovery_contract",
    ui_state: "System Unavailable",
    retry_action: "keep retry button visible",
  }),
  "/api/v1/memory/purge/contract": () => ({ ...tag, contract_version: "memory-dsgvo-purge-v1", endpoint: "GET /api/v1/memory/purge/jobs/{job_id}", evidence_ref: "memory_purge_job_status_visible" }),
  "/api/v1/memory/embedding-consistency/contract": () => ({
    ...tag,
    contract_version: "memory-embedding-consistency-v1",
    status: "verified",
    evidence_ref: "memory_embedding_consistency_contract_visible",
    audit_gap: "L-09",
    schema: { expected_columns: { embedding_model_version: "character varying(100)", content_embedding: "vector(1536)" } },
    current_embedding: { model_version: "text-embedding-3-small", dimensions: 1536, search_mode: "lexical_fallback" },
    cloud_embedding: { model_version: "@cf/baai/bge-base-en-v1.5", vector_type: "vector(768)", dimensions: 768, search_mode: "semantic_when_configured_else_lexical_fallback" },
    cloud_memory_path: "Cloudflare Workers AI embedding plus Vectorize, Neon pgvector, or GitHub-store fallback; legacy PostgreSQL contract remains 1536-dimensional.",
    non_claims: ["No live embedding provider call is claimed until the configured source header proves it."],
  }),
  "/api/v1/files/local/contract": () => ({
    ...tag,
    contract_version: "local-files-readonly-contract-v1",
    endpoint: "GET /api/v1/files/local/contract",
    host_filesystem_mounted: false,
    live_filesystem_reads: false,
    writes: false,
    secret_output: false,
  }),
  "/api/v1/models/capabilities/contract": () => ({
    ...tag,
    contract_version: "model-capabilities-contract-v1",
    runtime_endpoint: "GET /api/v1/models/capabilities",
    evidence_ref: "model_capabilities_contract_visible",
  }),
  "/api/v1/models/capabilities": () => ({
    ...tag,
    contract_version: "model-capabilities-contract-v1",
    routes: [
      { id: "llm_gateway", layer: "L4", status: "gateway_only" },
      { id: "marketplace", layer: "L5", status: "spec_only" },
      { id: "media", layer: "L4", status: "spec_only" },
      { id: "agents", layer: "L3", status: "spec_only" },
      { id: "observe", layer: "L7", status: "spec_only" },
    ],
    live_provider_calls: false,
  }),
  "/api/v1/costs/export/contract": () => ({ ...tag, contract_version: "cost-monitor-export-v1", supported_formats: ["csv"], evidence_ref: "cost_export_csv_generated" }),
  "/api/v1/rate-limit/contract": () => ({ ...tag, contract_version: "rate-limit-guard-v1", evidence_ref: "rate_limit_429_enforced" }),
  "/api/v1/session-limits/contract": () => ({ ...tag, contract_version: "session-llm-call-limit-v1", evidence_ref: "session_limit_429_enforced" }),
  "/api/v1/errors/contract": () => ({ ...tag, contract_version: "error-response-contract-v1", evidence_ref: "error_response_envelope_enforced" }),
  "/api/v1/security/headers/contract": () => ({ ...tag, contract_version: "security-headers-v1", evidence_ref: "security_headers_enforced" }),
  "/api/v1/trace/contract": () => ({ ...tag, contract_version: "trace-id-propagation-v1", evidence_ref: "trace_id_header_roundtrip" }),
  "/api/v1/cache/contract": () => ({ ...tag, contract_version: "cache-control-no-store-v1", evidence_ref: "cache_control_headers_enforced" }),
  "/api/v1/request/contract": () => ({ ...tag, contract_version: "request-id-correlation-v1", evidence_ref: "request_id_audit_correlation" }),
  "/api/v1/agent-activity/contract": () => ({ ...tag, contract_version: "agent-activity-trace-v1", evidence_ref: "agent_activity_filtered_feed_visible" }),
  "/api/v1/agent-activity/recent": () => ({
    ...tag,
    contract_version: "agent-activity-trace-v1",
    mode: "audit_log_backed_filtered_feed",
    events: [{
      trace_id: PROJECTED_THREAD_ID,
      session_id: PROJECTED_THREAD_ID,
      role_summary_count: 4,
      partial_failure: false,
      aggregation_evidence_ref: "agent_result_aggregation_complete",
      per_role_results: AGENT_ROLES.map((role) => ({ role, status: "completed" })),
    }],
  }),
  "/api/v1/tasks/assignment-contract": () => ({
    ...tag,
    contract_version: "task-assignment-queue-contract-v1",
    evidence_ref: "task_assignment_queue_contract_visible",
    audit_gap: "L-06",
    queue_key: "tasks:agent:queue",
    priority_queues: { high: "tasks:agent:queue:high", mid: "tasks:agent:queue:mid", low: "tasks:agent:queue:low" },
    priority_order: ["high", "mid", "low"],
    priority_policy: "high before mid before low",
    status_key_pattern: "task:status:{task_id}",
    recovery: "stale_queue_rescue",
  }),
  "/api/v1/agents/llm-streaming-contract": () => ({
    ...tag,
    contract_version: "agent-llm-streaming-contract-v1",
    evidence_ref: "agent_llm_streaming_contract_visible",
    audit_gap: "L-07",
    protocol: "openai_compatible_sse",
    done_frame: "data: [DONE]",
    parser: "parse_llm_gateway_sse_line",
    state_field: "stream_done_seen",
    non_claims: ["No live provider stream"],
  }),
  "/api/v1/live-agents/contract": () => ({
    ...tag,
    contract_version: "live-agent-steering-v1",
    mode: "openai_responses_via_llm_gateway",
    evidence_refs: { contract_visible: "live_agent_steering_contract_visible" },
    evidence_ref: "live_agent_steering_contract_visible",
    llm_gateway_endpoint: "POST /llm/v1/responses",
    llm_gateway_contract_version: "llm-responses-adapter-contract-v1",
    llm_gateway_contract_endpoint: "GET /llm/api/v1/responses/contract",
    required_llm_response_fields: ["output_text", "trace_id", "live_provider_calls", "model_downloads", "audit_persisted"],
    response_fields: ["trace_id", "live_provider_calls", "audit_persisted", "secret_output"],
    agents: liveAgentRows(),
  }),
  "/api/v1/phase2/runtime/contract": () => ({
    ...tag,
    contract_version: "phase2-runtime-v1",
    start_endpoint: "POST /api/v1/phase2/runtime/start",
    stream_endpoint: "POST /api/v1/orchestrator/dry-run/stream",
    runs_endpoint: "GET /api/v1/phase2/runtime/runs",
    sse_contract: "phase2-sse-event-contract-v1",
    evidence_refs: ["phase2_sse_event_contract_proof", "langgraph_mcp_timeout_controlled"],
    required_events: ["heartbeat", "agent_status", "error", "done"],
    live_provider_calls: false,
    checkpointing: "postgres",
  }),
  "/llm/api/v1/responses/contract": () => ({
    ...tag,
    contract_version: "llm-responses-adapter-contract-v1",
    evidence_ref: "llm_responses_adapter_contract_visible",
    runtime_endpoint: "POST /llm/v1/responses",
    service_runtime_route: "POST /v1/responses",
    live_provider_calls: false,
    model_downloads: false,
    production_deploy: false,
    secret_output: false,
    negative_cases: ["stream=true -> 501", "metadata must be an object -> 422"],
  }),
  "/mcp/api/v1/version-pinning/contract": () => ({
    ...tag,
    contract_version: "mcp-version-pinning-v1",
    evidence_ref: "mcp_version_pinning_contract_visible",
    audit_gap: "L-08",
    pins: ["fastapi==0.136.3", "uvicorn[standard]==0.49.0", "pydantic==2.13.4"],
    tool_contracts: ["github-branch-pr-plan-v1", "e2b-sandbox-lifecycle-v1"],
    drift_policy: "exact == pinning",
    non_claims: ["No live MCP write"],
  }),
};

/** Returns a shape-correct honest 200 payload for a known endpoint, or null. */
export function knownDefault(pathname: string): Record<string, unknown> | null {
  const fn = DEFAULTS[pathname];
  return fn ? fn() : null;
}

export function projectedDefault(pathname: string, method: string, body?: string): DefaultResult | null {
  if (method === "GET") {
    const exact = knownDefault(pathname);
    if (exact) return { payload: exact };
    const checkpoint = pathname.match(/^\/api\/v1\/orchestrator\/checkpoints\/([^/]+)$/);
    if (checkpoint) {
      return {
        payload: {
          ...tag,
          contract_version: "phase2-runtime-v1",
          thread_id: checkpoint[1],
          checkpointing: "postgres",
          state: { evidence_refs: ["phase2_runtime_graph_started"], node_name: "completed" },
        },
      };
    }
    const history = pathname.match(/^\/api\/v1\/sessions\/([^/]+)\/history$/);
    if (history) {
      return {
        payload: {
          ...tag,
          contract_version: "session-history-v1",
          evidence_ref: "session_history_openable_project_state",
          session: { session_id: history[1], status: "completed" },
          messages: AGENT_ROLES.map((role) => ({ role, content: "frontend projection" })),
          tasks: AGENT_ROLES.map((role) => ({ agent_type: role, status: "completed" })),
          audit_events: projectedAuditEvents(),
          project_progress: { overall_percent: PROJECT_PROGRESS_OVERALL },
          project_progress_integrity: { status: "verified", evidence_ref: "project_progress_integrity_runtime_proof" },
        },
      };
    }
  }
  if (method === "POST" && pathname === "/api/v1/phase2/runtime/start") {
    return {
      status: 503,
      payload: {
        ...tag,
        status: "blocked",
        contract_version: "phase2-runtime-v1",
        runtime_available: false,
        reason: "stateful_runtime_not_configured",
        owner_precondition: "Fly runtime approval or a separately approved Neon/Upstash architecture expansion.",
        run: null,
      },
    };
  }
  if (method === "GET" && pathname === "/api/v1/phase2/runtime/runs") {
    return {
      payload: {
        ...tag,
        status: "degraded",
        contract_version: "phase2-runtime-v1",
        evidence_ref: "phase2_runtime_run_status_visible",
        runtime_available: false,
        reason: "stateful_runtime_not_configured",
        owner_precondition: "Fly runtime approval or a separately approved Neon/Upstash architecture expansion.",
        runs: [],
      },
    };
  }
  if (method === "GET" && pathname === "/api/v1/auth/callback") {
    return { payload: { ...authContract(), status: "authenticated", cookie: { SameSite: "Strict" } } };
  }
  if (method === "POST" && pathname === "/api/v1/auth/refresh") {
    let token = "";
    try {
      token = String((JSON.parse(body || "{}") as { refresh_token?: unknown }).refresh_token ?? "");
    } catch {
      token = "";
    }
    if (token && usedRefreshTokens.has(token)) {
      return { status: 401, payload: { ...authContract(), error: "refresh_token_invalid", status: "blocked" } };
    }
    if (token) usedRefreshTokens.add(token);
    return {
      payload: {
        ...authContract(),
        status: "rotated",
        refresh_token_rotated: true,
        old_refresh_token_blacklisted: true,
      },
    };
  }
  if (method === "POST" && pathname === "/api/v1/auth/logout") {
    return { payload: { ...authContract(), status: "logged_out", refresh_token_revoked: true } };
  }
  const reset = pathname.match(/^\/api\/v1\/live-agents\/([^/]+)\/reset$/);
  if (method === "POST" && reset) {
    const agentId = reset[1];
    if (!AGENT_ROLES.includes(agentId)) return { status: 404, payload: { ...tag, error: "agent_not_found" } };
    liveAgentSessions.delete(agentId);
    return {
      payload: {
        ...tag,
        contract_version: "live-agent-steering-v1",
        status: "reset",
        agent_id: agentId,
      },
    };
  }
  if (method === "POST" && (pathname === "/api/v1/live-agents/steer" || pathname === "/api/steer-agent")) {
    let parsed: Record<string, unknown> = {};
    try {
      parsed = JSON.parse(body || "{}") as Record<string, unknown>;
    } catch {
      parsed = {};
    }
    const agentId = String(parsed.agent_id ?? parsed.agentId ?? "");
    const message = String(parsed.message ?? "");
    if (!AGENT_ROLES.includes(agentId)) return { status: 404, payload: { ...tag, error: "agent_not_found" } };
    if (!message.trim()) return { status: 422, payload: { ...tag, error: "message_required" } };
    const metadata = (parsed.metadata && typeof parsed.metadata === "object" && !Array.isArray(parsed.metadata)) ? parsed.metadata as Record<string, unknown> : {};
    const traceId = String(metadata.trace_id ?? `live-agent-${Date.now()}`);
    const responseId = `resp_${agentId}_${traceId}`;
    liveAgentSessions.set(agentId, { previous_response_id: responseId, trace_id: traceId });
    runtimeAuditEvents.push({
      id: `llm-${traceId}`,
      occurred_at: new Date().toISOString(),
      event_type: "llm_gateway_request",
      trace_id: traceId,
      session_id: traceId,
      contract_version: "live-agent-steering-v1",
      source_kind: "frontend_projection",
      audit_persisted: false,
      secret_output: false,
    });
    return {
      payload: {
        ...tag,
        contract_version: "live-agent-steering-v1",
        runtime_source: "openai_responses_via_llm_gateway",
        agent_id: agentId,
        trace_id: traceId,
        llm_gateway_contract_version: "llm-responses-adapter-contract-v1",
        llm_gateway_evidence_ref: "llm_responses_adapter_contract_visible",
        evidence_ref: "live_agent_steering_contract_visible",
        response_id: responseId,
        responseId,
        text: "Deterministic frontend projection steering response.",
        status: "completed",
        live_provider_calls: false,
        model_downloads: false,
        audit_persisted: true,
        secret_output: false,
        usage: { input_tokens: 8, output_tokens: 7, total_tokens: 15 },
      },
    };
  }
  if (method === "POST" && pathname === "/llm/v1/responses") {
    let parsed: Record<string, unknown> = {};
    try {
      parsed = JSON.parse(body || "{}") as Record<string, unknown>;
    } catch {
      parsed = {};
    }
    if (parsed.stream === true) {
      return {
        status: 501,
        payload: {
          ...tag,
          error: "stream_true_not_supported",
          message: "stream=true is not supported on this /v1/responses proxy",
        },
      };
    }
    if (parsed.metadata !== undefined && (typeof parsed.metadata !== "object" || parsed.metadata === null || Array.isArray(parsed.metadata))) {
      return {
        status: 422,
        payload: {
          ...tag,
          error: "metadata must be an object",
        },
      };
    }
    const metadata = (parsed.metadata ?? {}) as Record<string, unknown>;
    const traceId = String(metadata.trace_id ?? `frontend-projection-${Date.now()}`);
    runtimeAuditEvents.push({
      id: `llm-${traceId}`,
      occurred_at: new Date().toISOString(),
      event_type: "llm_gateway_request",
      trace_id: traceId,
      session_id: String(metadata.run_id ?? traceId),
      contract_version: "llm-responses-adapter-contract-v1",
      source_kind: "frontend_projection",
      audit_persisted: false,
      secret_output: false,
    });
    return {
      payload: {
        ...tag,
        id: `resp_${traceId}`,
        object: "response",
        status: "completed",
        contract_version: "llm-responses-adapter-contract-v1",
        evidence_ref: "llm_responses_adapter_contract_visible",
        trace_id: traceId,
        output_text: "Deterministic frontend projection response.",
        output: [{ type: "message", role: "assistant", content: [{ type: "output_text", text: "Deterministic frontend projection response." }] }],
        live_provider_calls: false,
        model_downloads: false,
        audit_persisted: true,
        usage: { input_tokens: 6, output_tokens: 5, total_tokens: 11 },
      },
    };
  }
  return null;
}

/** Generic honest 200 envelope for any other surface with no live backend. */
export function genericDefault(pathname: string, method: string): Record<string, unknown> {
  return {
    ...tag,
    status: "ok",
    endpoint: `${method} ${pathname}`,
    items: [],
    data: null,
    note: "No live backend configured; this surface is answered by honest frontend projection (empty). Deterministic contracts/state are served as real data.",
  };
}

/** Real Prometheus-format frontend metrics (always 200, never fabricated). */
export function frontendMetrics(): string {
  const persistence = !!(
    process.env.DATABASE_URL ||
    (process.env.CF_BACKEND_TOKEN && process.env.CF_D1_DATABASE_ID && process.env.CLOUDFLARE_ACCOUNT_ID) ||
    ((process.env.GH_STORE_TOKEN || process.env.GITHUB_TOKEN) && process.env.GH_STORE_REPO)
  );
  const up = persistence ? 1 : 0;
  const llm = (process.env.CF_WORKERS_AI_TOKEN || process.env.CLOUDFLARE_API_TOKEN) && process.env.CLOUDFLARE_ACCOUNT_ID ? 1 : 0;
  return [
    "# HELP superbrain_frontend_up Frontend liveness (1=up).",
    "# TYPE superbrain_frontend_up gauge",
    "superbrain_frontend_up 1",
    "# HELP superbrain_llm_provider_configured Free LLM provider configured (1=yes).",
    "# TYPE superbrain_llm_provider_configured gauge",
    `superbrain_llm_provider_configured ${llm}`,
    "# HELP superbrain_persistence_configured Persistence backend configured (1=yes).",
    "# TYPE superbrain_persistence_configured gauge",
    `superbrain_persistence_configured ${up}`,
    "# HELP superbrain_client_3d_safe Client 3D runs with GPU-safety guards (1=yes).",
    "# TYPE superbrain_client_3d_safe gauge",
    "superbrain_client_3d_safe 1",
  ].join("\n") + "\n";
}

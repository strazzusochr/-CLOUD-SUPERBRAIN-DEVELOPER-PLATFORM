// Server-only readers for the local agent-api. Every reader returns null when
// AGENT_API_INTERNAL_URL is unset/unreachable (e.g. on Vercel) so pages fall back
// to honest, clearly-labelled spec data. No secret/token value is ever read here.

const base = () => process.env.AGENT_API_INTERNAL_URL?.replace(/\/$/, "");

async function get(path: string): Promise<Response | null> {
  const b = base();
  if (!b) return null;
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 2500);
  try {
    const res = await fetch(`${b}${path}`, { cache: "no-store", signal: ctrl.signal });
    return res.ok ? res : null;
  } catch (err) {
    if (process.env.NODE_ENV !== "production") console.error(`agent-api ${path} unreachable:`, err);
    return null;
  } finally {
    clearTimeout(timer);
  }
}

export type CloudLayer = { id: string; label: string; status: string; verified: boolean };

/** The 7-layer cloud-layer-readiness contract (GET /api/v1/clouds/layers). */
export async function fetchLayers(): Promise<CloudLayer[] | null> {
  const res = await get("/api/v1/clouds/layers");
  if (!res) return null;
  try {
    const body = (await res.json()) as unknown;
    const list = (Array.isArray(body) ? body : (body as { layers?: unknown[] })?.layers ?? []) as Array<{
      layer_id?: string;
      label?: string;
      status?: string;
    }>;
    if (!list.length) return null;
    return list.map((l) => ({
      id: String(l.layer_id ?? ""),
      label: String(l.label ?? l.layer_id ?? ""),
      status: String(l.status ?? "unknown"),
      verified: String(l.status ?? "") === "live_verified",
    }));
  } catch (err) {
    if (process.env.NODE_ENV !== "production") console.error("agent-api response parse failed:", err);
    return null;
  }
}

export type Metrics = {
  scalars: Record<string, number>;
  services: { name: string; up: boolean }[];
  gates: { name: string; status: string; ok: boolean }[];
};

/** Parse the Prometheus text exposition into a small structured form. */
export async function fetchMetrics(): Promise<Metrics | null> {
  const res = await get("/api/v1/metrics");
  if (!res) return null;
  const txt = await res.text();
  const scalars: Record<string, number> = {};
  const services: { name: string; up: boolean }[] = [];
  const gates: { name: string; status: string; ok: boolean }[] = [];
  for (const line of txt.split("\n")) {
    if (!line || line[0] === "#") continue;
    const svc = line.match(/^superbrain_service_health\{service="([^"]+)"\}\s+([0-9.]+)/);
    if (svc) {
      services.push({ name: svc[1], up: Number(svc[2]) >= 1 });
      continue;
    }
    const gate = line.match(/^superbrain_external_gate_configured\{gate="([^"]+)",status="([^"]+)"\}\s+([0-9.]+)/);
    if (gate) {
      gates.push({ name: gate[1], status: gate[2], ok: Number(gate[3]) >= 1 });
      continue;
    }
    const sc = line.match(/^(superbrain_[a-z0-9_]+)\s+([0-9.eE+-]+)$/);
    if (sc && !(sc[1] in scalars)) scalars[sc[1]] = Number(sc[2]);
  }
  return Object.keys(scalars).length || services.length ? { scalars, services, gates } : null;
}

export type PlanItem = { id: string; label: string; status: string; percent: number };
export type Progress = {
  overall_percent?: number;
  last_verified?: string;
  progress_source?: string;
  binding_document?: string;
  truth_policy?: string;
  phases: PlanItem[];
  layers: PlanItem[];
};

type RawProgress = {
  overall_percent?: number;
  last_verified?: string;
  progress_source?: string;
  binding_document?: string;
  truth_policy?: string;
  horizontal?: { items?: unknown[] };
  vertical?: { items?: unknown[] };
};

/** Long verifier-marker status strings collapse to a clean badge label. */
function cleanStatus(raw: unknown, percent: number): string {
  if (percent >= 100) return "verified";
  const first = String(raw ?? "").split("-")[0].trim();
  return /^(verified|completed|complete|prepared|in_progress|active|pending)$/.test(first) ? first : "in progress";
}

function planItems(items: unknown[] | undefined): PlanItem[] {
  if (!Array.isArray(items)) return [];
  return items.map((raw) => {
    const it = (raw ?? {}) as { id?: string; label?: string; title?: string; status?: string; percent?: number };
    const percent = typeof it.percent === "number" ? it.percent : 0;
    return {
      id: String(it.id ?? ""),
      label: String(it.label ?? it.title ?? it.id ?? ""),
      status: cleanStatus(it.status, percent),
      percent,
    };
  });
}

/** Project-progress manifest projection (evidence-based, never fabricated). */
export async function fetchProgress(): Promise<Progress | null> {
  const res = await get("/api/v1/project/progress");
  if (!res) return null;
  try {
    const d = (await res.json()) as RawProgress;
    return {
      overall_percent: d.overall_percent,
      last_verified: d.last_verified,
      progress_source: d.progress_source,
      binding_document: d.binding_document,
      truth_policy: d.truth_policy,
      phases: planItems(d.horizontal?.items),
      layers: planItems(d.vertical?.items),
    };
  } catch (err) {
    if (process.env.NODE_ENV !== "production") console.error("agent-api response parse failed:", err);
    return null;
  }
}

export type CloudProvider = { id: string; label: string; status: string; configured: boolean; liveVerified: boolean; layers: string[] };
export type CloudReadiness = { providers: CloudProvider[]; liveCount: number; total: number };

/** Cloud provider readiness from GET /api/v1/clouds. Exposes only status metadata —
 *  never `required_env` names or any token value. Null → caller shows the static inventory. */
export async function fetchProviders(): Promise<CloudReadiness | null> {
  const res = await get("/api/v1/clouds");
  if (!res) return null;
  try {
    const d = (await res.json()) as {
      live_verified_count?: number;
      total_count?: number;
      providers?: Array<{ id?: string; label?: string; status?: string; configured?: boolean; live_verified?: boolean; layers?: string[] }>;
    };
    const raw = Array.isArray(d.providers) ? d.providers : [];
    if (!raw.length) return null;
    return {
      providers: raw.map((p) => ({
        id: String(p.id ?? ""),
        label: String(p.label ?? p.id ?? ""),
        status: String(p.status ?? "unknown"),
        configured: !!p.configured,
        liveVerified: !!p.live_verified,
        layers: Array.isArray(p.layers) ? p.layers.map(String) : [],
      })),
      liveCount: Number(d.live_verified_count ?? 0),
      total: Number(d.total_count ?? raw.length),
    };
  } catch (err) {
    if (process.env.NODE_ENV !== "production") console.error("agent-api response parse failed:", err);
    return null;
  }
}

export type LiveAgent = { id: string; name: string; role: string; hasSession: boolean; model: string | null };
export type LiveRoster = { agents: LiveAgent[]; defaultModel: string | null; runtimeSource: string | null };

/** Live agent-pool roster (agent-pool layer). Exposes only non-secret role metadata
 *  — no session ids, no tokens. Returns null → caller shows the static profile spec. */
export async function fetchLiveAgents(): Promise<LiveRoster | null> {
  const res = await get("/api/v1/live-agents/status");
  if (!res) return null;
  try {
    const d = (await res.json()) as {
      agents?: Array<{ agent_id?: string; display_name?: string; execution_role?: string; has_session?: boolean; model?: string | null }>;
      default_model?: string;
      runtime_source?: string;
    };
    const raw = Array.isArray(d.agents) ? d.agents : [];
    if (!raw.length) return null;
    return {
      agents: raw.map((a) => ({
        id: String(a.agent_id ?? ""),
        name: String(a.display_name ?? a.agent_id ?? ""),
        role: String(a.execution_role ?? ""),
        hasSession: !!a.has_session,
        model: a.model ?? null,
      })),
      defaultModel: d.default_model ?? null,
      runtimeSource: d.runtime_source ?? null,
    };
  } catch (err) {
    if (process.env.NODE_ENV !== "production") console.error("agent-api response parse failed:", err);
    return null;
  }
}

export type RecentTask = {
  id: string;
  projectId: string;
  sessionId: string | null;
  agentType: string;
  taskType: string;
  description: string;
  status: string;
  priority: number;
  createdAt: string | null;
};

export type RecentTasks = {
  queueDepth: number;
  queueDepthByPriority: Record<string, number>;
  tasks: RecentTask[];
};

export async function fetchRecentTasks(): Promise<RecentTasks | null> {
  const res = await get("/api/v1/tasks/recent");
  if (!res) return null;
  try {
    const d = (await res.json()) as {
      queue_depth?: number;
      queue_depth_by_priority?: Record<string, number>;
      tasks?: Array<{
        task_id?: string;
        project_id?: string;
        session_id?: string | null;
        agent_type?: string;
        task_type?: string;
        task_description?: string;
        status?: string;
        priority?: number;
        created_at?: string;
      }>;
    };
    const raw = Array.isArray(d.tasks) ? d.tasks : [];
    return {
      queueDepth: Number(d.queue_depth ?? 0),
      queueDepthByPriority: typeof d.queue_depth_by_priority === "object" && d.queue_depth_by_priority ? d.queue_depth_by_priority : {},
      tasks: raw.map((t) => ({
        id: String(t.task_id ?? ""),
        projectId: String(t.project_id ?? ""),
        sessionId: t.session_id ?? null,
        agentType: String(t.agent_type ?? ""),
        taskType: String(t.task_type ?? ""),
        description: String(t.task_description ?? ""),
        status: String(t.status ?? ""),
        priority: Number(t.priority ?? 0),
        createdAt: t.created_at ?? null,
      })),
    };
  } catch (err) {
    if (process.env.NODE_ENV !== "production") console.error("agent-api response parse failed:", err);
    return null;
  }
}

export type RecentSession = {
  id: string;
  projectId: string;
  startedAt: string | null;
  status: string;
  latestTaskId: string | null;
  latestTaskStatus: string | null;
  latestError: string | null;
  assistantResult: string | null;
};

export async function fetchRecentSessions(): Promise<RecentSession[] | null> {
  const res = await get("/api/v1/sessions/recent");
  if (!res) return null;
  try {
    const d = (await res.json()) as { sessions?: Array<Record<string, unknown>> };
    const raw = Array.isArray(d.sessions) ? d.sessions : [];
    if (!raw.length) return [];
    return raw.map((s) => ({
      id: String(s.session_id ?? ""),
      projectId: String(s.project_id ?? ""),
      startedAt: (s.started_at as string | undefined) ?? null,
      status: String(s.status ?? ""),
      latestTaskId: (s.latest_task_id as string | undefined) ?? null,
      latestTaskStatus: (s.latest_task_status as string | undefined) ?? null,
      latestError: (s.latest_error as string | undefined) ?? null,
      assistantResult: (s.assistant_result as string | undefined) ?? null,
    }));
  } catch (err) {
    if (process.env.NODE_ENV !== "production") console.error("agent-api response parse failed:", err);
    return null;
  }
}

export type AuditEvent = { id: string; type: string; sessionId: string | null; occurredAt: string | null };

export async function fetchAuditRecent(): Promise<AuditEvent[] | null> {
  const res = await get("/api/v1/audit/recent");
  if (!res) return null;
  try {
    const d = (await res.json()) as { events?: Array<Record<string, unknown>> };
    const raw = Array.isArray(d.events) ? d.events : [];
    return raw.map((e) => ({
      id: String(e.id ?? ""),
      type: String(e.event_type ?? ""),
      sessionId: (e.session_id as string | undefined) ?? null,
      occurredAt: (e.occurred_at as string | undefined) ?? null,
    }));
  } catch (err) {
    if (process.env.NODE_ENV !== "production") console.error("agent-api response parse failed:", err);
    return null;
  }
}

const AUTONOMOUS_MASTER_PLAN_CONTRACT = "autonomous-master-plan-v1";
const AUTONOMOUS_AGENT_ROSTER_CONTRACT = "autonomous-agent-roster-v1";
const AUTONOMOUS_CODING_TEAM_CONTRACT = "autonomous-coding-team-v1";
const AUTONOMOUS_TASK_DISPATCH_CONTRACT = "autonomous-task-dispatch-v1";
const AUTONOMOUS_TEAM_MODE = "logical_five_role_overlay_on_runtime_pool";
const AUTONOMOUS_LOGICAL_ROLES = ["supervisor", "planner", "explorer", "coder", "tester"] as const;
const MASTER_PLAN_PHASES = ["phase_0", "phase_1", "phase_2", "phase_3", "phase_4", "phase_5", "phase_6"] as const;
const MASTER_PLAN_LAYERS = ["layer_1", "layer_2", "layer_3", "layer_4", "layer_5", "layer_6", "layer_7"] as const;
const SAFE_AGENT_ID = /^[a-z][a-z0-9_]{0,63}$/;
const SAFE_DISPATCH_ID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function jsonObject(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function exactStringList(value: unknown, expected: readonly string[]): value is string[] {
  return Array.isArray(value)
    && value.length === expected.length
    && value.every((item, index) => item === expected[index]);
}

function safeStringList(value: unknown): string[] | null {
  if (!Array.isArray(value) || !value.every((item) => typeof item === "string" && SAFE_AGENT_ID.test(item))) {
    return null;
  }
  return value;
}

function exactPercentageMap(value: unknown, expectedKeys: readonly string[]): Record<string, number> | null {
  const record = jsonObject(value);
  if (!record || Object.keys(record).length !== expectedKeys.length) return null;
  const result: Record<string, number> = {};
  for (const key of expectedKeys) {
    const percent = record[key];
    if (typeof percent !== "number" || !Number.isInteger(percent) || percent < 0 || percent > 100) return null;
    result[key] = percent;
  }
  return result;
}

function exactQueueDepths(value: unknown): Record<"high" | "mid" | "low", number> | null {
  const record = jsonObject(value);
  if (!record || Object.keys(record).length !== 3) return null;
  const result = { high: 0, mid: 0, low: 0 };
  for (const priority of ["high", "mid", "low"] as const) {
    const depth = record[priority];
    if (typeof depth !== "number" || !Number.isInteger(depth) || depth < 0) return null;
    result[priority] = depth;
  }
  return result;
}

export type MasterPlan = {
  contractVersion: string;
  status: string;
  overallPercent: number;
  integrityStatus: string;
  phasePercentages: Record<string, number>;
  layerPercentages: Record<string, number>;
  logicalRoles: string[];
  dispatchEndpoints: string[];
  sourceDocument: string | null;
  progressManifest: string | null;
  bindingDocument: string | null;
  runtimeSource: string | null;
  evidenceRef: string;
};

export async function fetchMasterPlan(): Promise<MasterPlan | null> {
  const res = await get("/api/v1/team/master-plan");
  if (!res) return null;
  try {
    const d = (await res.json()) as Record<string, unknown>;
    const overallPercent = d.overall_percent;
    const phasePercentages = exactPercentageMap(d.phase_percentages, MASTER_PLAN_PHASES);
    const layerPercentages = exactPercentageMap(d.layer_percentages, MASTER_PLAN_LAYERS);
    const runtimeSource = d.runtime_source;
    if (
      d.contract_version !== AUTONOMOUS_MASTER_PLAN_CONTRACT
      || d.status !== "loaded"
      || d.source_document !== "PROJECT_STATE.md"
      || d.progress_manifest !== "docs/project-progress.manifest.json"
      || d.binding_document !== "docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md"
      || d.integrity_status !== "verified"
      || d.evidence_ref !== "autonomous_master_plan_runtime_visible"
      || typeof overallPercent !== "number"
      || !Number.isInteger(overallPercent)
      || overallPercent < 0
      || overallPercent > 100
      || !phasePercentages
      || !layerPercentages
      || !exactStringList(d.logical_roles, AUTONOMOUS_LOGICAL_ROLES)
      || !exactStringList(d.dispatch_endpoints, [
        "GET /api/v1/team/status",
        "POST /api/v1/task/dispatch",
        "GET /api/v1/task/dispatches/recent",
      ])
      || (runtimeSource !== "internal_queue" && runtimeSource !== "external_adapter")
    ) {
      return null;
    }
    return {
      contractVersion: AUTONOMOUS_MASTER_PLAN_CONTRACT,
      status: "loaded",
      overallPercent,
      integrityStatus: "verified",
      phasePercentages,
      layerPercentages,
      logicalRoles: [...AUTONOMOUS_LOGICAL_ROLES],
      dispatchEndpoints: d.dispatch_endpoints,
      sourceDocument: d.source_document,
      progressManifest: d.progress_manifest,
      bindingDocument: d.binding_document,
      runtimeSource,
      evidenceRef: d.evidence_ref,
    };
  } catch (err) {
    if (process.env.NODE_ENV !== "production") console.error("agent-api response parse failed:", err);
    return null;
  }
}

export type AgentRosterRoleSummary = {
  id: string;
  status: "launcher-blocked" | "launcher-unstable" | "launch-validated";
  fallbackAgentTypes: string[];
};

export type AgentRosterSummary = {
  contractVersion: string;
  status: string;
  roleCount: number;
  runtimeSource: string | null;
  sourceDocument: string | null;
  validatedAgentTypes: string[];
  langGraphStatus: string;
  metricsStatus: string;
  roles: AgentRosterRoleSummary[];
  evidenceRef: string;
};

export async function fetchAgentRoster(): Promise<AgentRosterSummary | null> {
  const res = await get("/api/v1/team/roster");
  if (!res) return null;
  try {
    const d = (await res.json()) as Record<string, unknown>;
    const launcher = jsonObject(d.launcher_status);
    const bindings = jsonObject(d.runtime_bindings);
    const langgraph = jsonObject(bindings?.langgraph);
    const prometheus = jsonObject(bindings?.prometheus);
    const validatedAgentTypes = safeStringList(launcher?.validated_startable);
    const rawRoles = Array.isArray(d.roles) ? d.roles : null;
    const roles: AgentRosterRoleSummary[] = [];
    const seenRoleIds = new Set<string>();
    if (!rawRoles) return null;
    for (const rawRole of rawRoles) {
      const role = jsonObject(rawRole);
      const id = role?.id;
      const status = role?.status;
      const fallbackAgentTypes = safeStringList(role?.fallback_agent_types);
      if (
        typeof id !== "string"
        || !SAFE_AGENT_ID.test(id)
        || seenRoleIds.has(id)
        || (status !== "launcher-blocked" && status !== "launcher-unstable" && status !== "launch-validated")
        || !fallbackAgentTypes
      ) {
        return null;
      }
      seenRoleIds.add(id);
      roles.push({ id, status, fallbackAgentTypes });
    }
    const roleCount = d.role_count;
    const runtimeSource = d.runtime_source;
    if (
      d.contract_version !== AUTONOMOUS_AGENT_ROSTER_CONTRACT
      || d.status !== "loaded"
      || d.source_document !== "docs/codex-integration/autonomous-agent-roster.json"
      || d.evidence_ref !== "autonomous_agent_roster_runtime_visible"
      || typeof roleCount !== "number"
      || !Number.isInteger(roleCount)
      || roleCount !== roles.length
      || roleCount < AUTONOMOUS_LOGICAL_ROLES.length
      || !validatedAgentTypes
      || validatedAgentTypes.length < 1
      || langgraph?.status !== "active"
      || prometheus?.status !== "metrics_surface_available"
      || (runtimeSource !== "internal_queue" && runtimeSource !== "external_adapter")
    ) {
      return null;
    }
    return {
      contractVersion: AUTONOMOUS_AGENT_ROSTER_CONTRACT,
      status: "loaded",
      roleCount,
      runtimeSource,
      sourceDocument: d.source_document,
      validatedAgentTypes,
      langGraphStatus: "active",
      metricsStatus: "metrics_surface_available",
      roles,
      evidenceRef: d.evidence_ref,
    };
  } catch (err) {
    if (process.env.NODE_ENV !== "production") console.error("agent-api response parse failed:", err);
    return null;
  }
}

export type TeamMemberSummary = {
  logicalRole: string;
  executionAgentType: string;
  status: string;
  priorityLevel: "high" | "mid" | "low" | null;
  priorityQueue: string | null;
};

export type CodingTeamSummary = {
  contractVersion: string;
  status: string;
  teamMode: string;
  runtimeSource: string | null;
  dispatchId: string | null;
  queueDepth: number;
  queueDepthByPriority: Record<"high" | "mid" | "low", number>;
  members: TeamMemberSummary[];
};

export async function fetchCodingTeam(dispatchId?: string | null): Promise<CodingTeamSummary | null> {
  if (dispatchId === null || (dispatchId !== undefined && !SAFE_DISPATCH_ID.test(dispatchId))) return null;
  const path = dispatchId
    ? `/api/v1/team/status?dispatch_id=${encodeURIComponent(dispatchId)}`
    : "/api/v1/team/status";
  const res = await get(path);
  if (!res) return null;
  try {
    const d = (await res.json()) as Record<string, unknown>;
    const runtimeSource = d.runtime_source;
    const responseDispatchId = d.dispatch_id;
    const teamStatus = d.status;
    const queueDepth = d.queue_depth;
    const queueDepthByPriority = exactQueueDepths(d.queue_depth_by_priority);
    const logicalToExecution = jsonObject(d.logical_to_execution_map);
    const noDispatchStatuses = new Set(["idle", "external_ready", "external_degraded"]);
    const dispatchStatuses = new Set(["queued", "active", "completed", "attention", "failed"]);
    if (
      d.contract_version !== AUTONOMOUS_CODING_TEAM_CONTRACT
      || d.dispatch_contract_version !== AUTONOMOUS_TASK_DISPATCH_CONTRACT
      || d.team_mode !== AUTONOMOUS_TEAM_MODE
      || (runtimeSource !== "internal_queue" && runtimeSource !== "external_adapter")
      || !exactStringList(d.logical_roles, AUTONOMOUS_LOGICAL_ROLES)
      || !logicalToExecution
      || typeof teamStatus !== "string"
      || typeof queueDepth !== "number"
      || !Number.isInteger(queueDepth)
      || queueDepth < 0
      || !queueDepthByPriority
      || (responseDispatchId !== null && (typeof responseDispatchId !== "string" || !SAFE_DISPATCH_ID.test(responseDispatchId)))
      || (dispatchId !== undefined && responseDispatchId !== dispatchId)
      || (responseDispatchId === null && !noDispatchStatuses.has(teamStatus))
      || (responseDispatchId !== null && !dispatchStatuses.has(teamStatus))
    ) {
      return null;
    }
    const rawMembers = Array.isArray(d.members) ? d.members : null;
    if (!rawMembers || rawMembers.length !== AUTONOMOUS_LOGICAL_ROLES.length) return null;
    const memberByRole = new Map<string, TeamMemberSummary>();
    const memberStatuses = new Set([
      "idle",
      "ready",
      "unavailable",
      "queued",
      "running",
      "completed",
      "failed",
      "escalated",
      "abandoned_after_queue_drain",
    ]);
    for (const rawMember of rawMembers) {
      const member = jsonObject(rawMember);
      const logicalRole = member?.logical_role;
      const executionAgentType = member?.execution_agent_type;
      const status = member?.status;
      const priorityLevel = member?.priority_level;
      const priorityQueue = member?.priority_queue;
      if (
        typeof logicalRole !== "string"
        || !AUTONOMOUS_LOGICAL_ROLES.includes(logicalRole as (typeof AUTONOMOUS_LOGICAL_ROLES)[number])
        || memberByRole.has(logicalRole)
        || typeof executionAgentType !== "string"
        || !SAFE_AGENT_ID.test(executionAgentType)
        || logicalToExecution[logicalRole] !== executionAgentType
        || typeof status !== "string"
        || !memberStatuses.has(status)
        || (priorityLevel !== null && priorityLevel !== "high" && priorityLevel !== "mid" && priorityLevel !== "low")
        || (priorityQueue !== null && typeof priorityQueue !== "string")
        || (priorityLevel === null && priorityQueue !== null)
        || (priorityLevel !== null && priorityQueue !== {
          high: "tasks:agent:queue:high",
          mid: "tasks:agent:queue",
          low: "tasks:agent:queue:low",
        }[priorityLevel])
        || (responseDispatchId === null && priorityLevel !== null)
        || (responseDispatchId !== null && priorityLevel === null)
      ) {
        return null;
      }
      memberByRole.set(logicalRole, {
        logicalRole,
        executionAgentType,
        status,
        priorityLevel,
        priorityQueue,
      });
    }
    const members = AUTONOMOUS_LOGICAL_ROLES.map((role) => memberByRole.get(role)).filter(
      (member): member is TeamMemberSummary => member !== undefined,
    );
    if (members.length !== AUTONOMOUS_LOGICAL_ROLES.length) return null;
    return {
      contractVersion: AUTONOMOUS_CODING_TEAM_CONTRACT,
      status: teamStatus,
      teamMode: AUTONOMOUS_TEAM_MODE,
      runtimeSource,
      dispatchId: responseDispatchId,
      queueDepth,
      queueDepthByPriority,
      members,
    };
  } catch (err) {
    if (process.env.NODE_ENV !== "production") console.error("agent-api response parse failed:", err);
    return null;
  }
}

export type CompletionGate = { canSetAllTo100: boolean; reason: string | null };

export async function fetchCompletionGate(): Promise<CompletionGate | null> {
  const res = await get("/api/v1/project/progress/completion");
  if (!res) return null;
  try {
    const d = (await res.json()) as Record<string, unknown>;
    return {
      canSetAllTo100: !!d.can_set_all_to_100,
      reason: (d.reason as string | undefined) ?? null,
    };
  } catch (err) {
    if (process.env.NODE_ENV !== "production") console.error("agent-api response parse failed:", err);
    return null;
  }
}

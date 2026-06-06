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

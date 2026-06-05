// Server-only readers for the local agent-api. Every reader returns null when
// AGENT_API_INTERNAL_URL is unset/unreachable (e.g. on Vercel) so pages fall back
// to honest, clearly-labelled spec data. No secret/token value is ever read here.

const base = () => process.env.AGENT_API_INTERNAL_URL?.replace(/\/$/, "");

async function get(path: string): Promise<Response | null> {
  const b = base();
  if (!b) return null;
  try {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 1500);
    const res = await fetch(`${b}${path}`, { cache: "no-store", signal: ctrl.signal });
    clearTimeout(timer);
    return res.ok ? res : null;
  } catch {
    return null;
  }
}

export type Metrics = {
  scalars: Record<string, number>;
  services: { name: string; up: boolean }[];
};

/** Parse the Prometheus text exposition into a small structured form. */
export async function fetchMetrics(): Promise<Metrics | null> {
  const res = await get("/api/v1/metrics");
  if (!res) return null;
  const txt = await res.text();
  const scalars: Record<string, number> = {};
  const services: { name: string; up: boolean }[] = [];
  for (const line of txt.split("\n")) {
    if (!line || line[0] === "#") continue;
    const svc = line.match(/^superbrain_service_health\{service="([^"]+)"\}\s+([0-9.]+)/);
    if (svc) {
      services.push({ name: svc[1], up: Number(svc[2]) >= 1 });
      continue;
    }
    const sc = line.match(/^(superbrain_[a-z0-9_]+)\s+([0-9.eE+-]+)$/);
    if (sc && !(sc[1] in scalars)) scalars[sc[1]] = Number(sc[2]);
  }
  return Object.keys(scalars).length || services.length ? { scalars, services } : null;
}

export type Progress = {
  overall_percent?: number;
  last_verified?: string;
  progress_source?: string;
  horizontal?: { items?: Array<{ id?: string; label?: string; status?: string; percent?: number }> };
};

/** Project-progress manifest projection (evidence-based, never fabricated). */
export async function fetchProgress(): Promise<Progress | null> {
  const res = await get("/api/v1/project/progress");
  if (!res) return null;
  try {
    return (await res.json()) as Progress;
  } catch {
    return null;
  }
}

import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge, SpecModeBadge, Metric, StatusDot } from "../../components/ui";
import { SERVICES, API_SURFACES } from "../../lib/platform";
import { LAYERS } from "../../components/organism/regionMap";
import { fetchMetrics } from "../../lib/agentApi";

export const dynamic = "force-dynamic";
export const metadata = { title: "Observe / Monitoring — Cloud Superbrain" };

const OBS = API_SURFACES.find((g) => g.group === "Observability") ?? { group: "Observability", endpoints: [] };
const HEALTH = API_SURFACES.find((g) => g.group === "Health & Run State") ?? { group: "Health & Run State", endpoints: [] };
const STREAM_SURFACE = HEALTH.endpoints[5] ?? "/api/v1/session/{id}/stream";

const BARS = [40, 62, 48, 70, 55, 80, 60, 74, 52, 66, 90, 58];
const fmt = (n: number | undefined) => (typeof n === "number" ? n.toLocaleString("en-US") : "—");

export default async function ObservePage() {
  const metrics = await fetchMetrics();
  const live = !!metrics;
  const s = metrics?.scalars ?? {};
  const services = metrics?.services.length ? metrics.services : SERVICES.map((x) => ({ name: x.name, up: true }));

  return (
    <AppShell crumb="Observe" runState="executing">
      <div className="page-wide">
        <PageHeader
          eyebrow="Observe / Monitoring"
          title="Runtime signals"
          subtitle="Health, runs, latency, traces and logs bound to the real backend surfaces. Headline numbers project live from GET /api/v1/metrics when the runtime is reachable; the traffic chart stays spec-only until an OTel collector is wired."
          actions={
            <>
              {live ? <Badge tone="green">● Live · /api/v1/metrics</Badge> : <SpecModeBadge mode="spec_only" />}
              <Link href="/evidence" className="btn btn-sm">Open run →</Link>
            </>
          }
        />

        <div className="grid cols-3" style={{ marginBottom: 16 }}>
          <Metric label="Projects" value={live ? fmt(s.superbrain_projects_total) : "—"} foot={live ? "live" : "unavailable"} />
          <Metric label="Agent sessions" value={live ? fmt(s.superbrain_agent_sessions_total) : "—"} foot={live ? "live" : "unavailable"} />
          <Metric label="Agent messages" value={live ? fmt(s.superbrain_agent_messages_total) : "—"} foot={live ? "live" : "unavailable"} />
          <Metric label="Memory entries" value={live ? fmt(s.superbrain_memory_entries_total) : "—"} foot="pgvector" />
          <Metric label="Task queue depth" value={live ? fmt(s.superbrain_task_queue_depth) : "—"} foot={live ? "live" : "unavailable"} />
          <Metric label="LLM budget spent" value={live ? `${s.superbrain_budget_spent_percentage ?? 0}%` : "—"} foot="dry-run · no live call" />
        </div>

        <div className="grid cols-2">
          <Panel title="Runtime service health" actions={live ? <Badge tone="green">● live</Badge> : <SpecModeBadge mode="spec_only" />}>
            <div className="wb-pad stack" style={{ gap: 9 }}>
              {services.map((svc, i) => {
                const norm = (n: string) => n.replace(/[-_]/g, "");
                const meta = SERVICES.find((x) => norm(x.name) === norm(svc.name)) ?? SERVICES[i];
                const layer = meta ? LAYERS[meta.layer - 1] : LAYERS[0];
                return (
                  <div key={svc.name} className="svc-row">
                    <StatusDot tone={svc.up ? "green" : "red"} pulse={svc.up} />
                    <span className="mono" style={{ fontSize: 13 }}>{svc.name}</span>
                    <span className="svc-meta">{svc.up ? "healthy" : "down"} · {layer.label}</span>
                  </div>
                );
              })}
              <p style={{ fontSize: 11.5, color: "var(--text-dim)", marginTop: 4 }}>
                Health projects from <span className="mono">GET /api/v1/health</span> · <span className="mono">/metrics</span>.
              </p>
            </div>
          </Panel>

          <Panel title="Observability surfaces">
            <div className="wb-pad stack" style={{ gap: 6 }}>
              {OBS.endpoints.map((e) => (
                <div key={e} className="surface-row">
                  <span className="mono" style={{ fontSize: 12.5 }}>{e}</span>
                  <Badge tone="cyan">read-only</Badge>
                </div>
              ))}
            </div>
          </Panel>
        </div>

        <Panel title="Traffic (OpenTelemetry)" style={{ marginTop: 16 }} pad>
          <SpecModeBadge mode="spec_only" />
          <svg viewBox="0 0 320 120" width="100%" height="120" style={{ marginTop: 10 }} role="img" aria-label="Traffic chart (spec-only)">
            {BARS.map((b, i) => (
              <rect key={i} x={i * 26 + 6} y={120 - b} width="16" height={b} rx="3" fill="url(#g11)" opacity="0.85" />
            ))}
            <defs>
              <linearGradient id="g11" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="var(--cyan)" />
                <stop offset="100%" stopColor="var(--blue)" />
              </linearGradient>
            </defs>
          </svg>
          <p style={{ fontSize: 12, color: "var(--text-dim)", marginTop: 6 }}>
            Spec-only time series. Bind a live OTel collector to replace it with real traffic; run state
            and traces correlate via <span className="mono">{STREAM_SURFACE}</span>.
          </p>
        </Panel>
      </div>
    </AppShell>
  );
}

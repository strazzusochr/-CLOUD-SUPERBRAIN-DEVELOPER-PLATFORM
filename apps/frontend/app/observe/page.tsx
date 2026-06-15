import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge, SpecModeBadge, Metric, StatusDot } from "../../components/ui";
import { SERVICES, API_SURFACES } from "../../lib/platform";
import { LAYERS } from "../../components/organism/regionMap";
import { fetchMetrics } from "../../lib/agentApi";
import { paidCapabilityVisible } from "../../lib/paidCapabilities";
import { ObserveRuntimeProbe } from "../../components/batch4-actions";

export const dynamic = "force-dynamic";
export const metadata = { title: "Beobachten / Monitoring — Cloud Superbrain" };

const OBS = API_SURFACES.find((g) => g.group === "Observability") ?? { group: "Observability", endpoints: [] };
const HEALTH = API_SURFACES.find((g) => g.group === "Health & Run State") ?? { group: "Health & Run State", endpoints: [] };
const STREAM_SURFACE = HEALTH.endpoints[5] ?? "/api/v1/session/{id}/stream";

const BARS = [40, 62, 48, 70, 55, 80, 60, 74, 52, 66, 90, 58];
const fmt = (n: number | undefined) => (typeof n === "number" ? n.toLocaleString("de-DE") : "—");

type SearchParams = Record<string, string | string[] | undefined>;
type ObservePageProps = {
  searchParams?: Promise<SearchParams>;
};

async function resolveSearchParams(searchParams: ObservePageProps["searchParams"]): Promise<SearchParams> {
  if (!searchParams) return {};
  return searchParams;
}

export default async function ObservePage({ searchParams }: ObservePageProps) {
  const resolvedSearchParams = await resolveSearchParams(searchParams);
  const showBudget = paidCapabilityVisible(resolvedSearchParams);
  const metrics = await fetchMetrics();
  const live = !!metrics;
  const s = metrics?.scalars ?? {};
  const services = metrics?.services.length ? metrics.services : SERVICES.map((x) => ({ name: x.name, up: true }));
  const observabilityEndpoints = showBudget
    ? OBS.endpoints
    : OBS.endpoints.filter((endpoint) => !/\/api\/v1\/(budget|costs)/.test(endpoint));

  return (
    <AppShell crumb="Observe" runState="executing">
      <div className="page-wide">
        <PageHeader
          eyebrow="Beobachten / Monitoring"
          title="Runtime-Signale"
          subtitle="Health, Runs, Latenz, Traces und Logs: verdrahtet an echte Backend-Surfaces. Headline-Zahlen kommen live aus GET /api/v1/metrics; Traffic bleibt spec-only bis OTel verdrahtet ist."
          actions={
            <>
              {live ? <Badge tone="green">● Live · /api/v1/metrics</Badge> : <SpecModeBadge mode="spec_only" />}
              <Link href="/evidence" className="btn btn-sm">Nachweise →</Link>
            </>
          }
        />

        <div className="grid cols-3" style={{ marginBottom: 16 }}>
          <Metric label="Projekte" value={live ? fmt(s.superbrain_projects_total) : "—"} foot={live ? "live" : "nicht verfügbar"} />
          <Metric label="Agent-Sessions" value={live ? fmt(s.superbrain_agent_sessions_total) : "—"} foot={live ? "live" : "nicht verfügbar"} />
          <Metric label="Agent-Messages" value={live ? fmt(s.superbrain_agent_messages_total) : "—"} foot={live ? "live" : "nicht verfügbar"} />
          <Metric label="Memory-Einträge" value={live ? fmt(s.superbrain_memory_entries_total) : "—"} foot="pgvector" />
          <Metric label="Task-Queue Tiefe" value={live ? fmt(s.superbrain_task_queue_depth) : "—"} foot={live ? "live" : "nicht verfügbar"} />
          {showBudget ? (
            <Metric label="LLM Budget (spent)" value={live ? `${s.superbrain_budget_spent_percentage ?? 0}%` : "—"} foot="paid capability" />
          ) : null}
        </div>

        <div className="grid cols-2">
          <Panel title="Runtime-Service Health" actions={live ? <Badge tone="green">● live</Badge> : <SpecModeBadge mode="spec_only" />}>
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
                Health kommt aus <span className="mono">GET /api/v1/health</span> · <span className="mono">/metrics</span>.
              </p>
            </div>
          </Panel>

          <Panel title="Observability-Surfaces">
            <div className="wb-pad stack" style={{ gap: 6 }}>
              {observabilityEndpoints.map((e) => (
                <div key={e} className="surface-row">
                  <span className="mono" style={{ fontSize: 12.5 }}>{e}</span>
                  <Badge tone="cyan">nur lesen</Badge>
                </div>
              ))}
            </div>
          </Panel>
        </div>

        <Panel title="Traffic (OpenTelemetry)" style={{ marginTop: 16 }} pad>
          <SpecModeBadge mode="spec_only" />
          <div style={{ marginTop: 10, marginBottom: 10 }}>
            <ObserveRuntimeProbe />
          </div>
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
            Spec-only Zeitreihe. Verdrahte einen live OTel-Collector, um echte Traffic-Daten zu sehen; Run-State
            und Traces korrelieren über <span className="mono">{STREAM_SURFACE}</span>.
          </p>
        </Panel>
      </div>
    </AppShell>
  );
}

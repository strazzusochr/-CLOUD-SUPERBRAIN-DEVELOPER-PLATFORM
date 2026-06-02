import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge, SpecModeBadge } from "../../components/ui";
import { SERVICES, API_SURFACES } from "../../lib/platform";
import { LAYERS } from "../../components/organism/regionMap";

export const metadata = { title: "Observe / Monitoring — Cloud Superbrain" };

const OBS = API_SURFACES.find((g) => g.group === "Observability") ?? { group: "Observability", endpoints: [] };
const HEALTH = API_SURFACES.find((g) => g.group === "Health & Run State") ?? { group: "Health & Run State", endpoints: [] };
const STREAM_SURFACE = HEALTH.endpoints[5] ?? "/api/v1/session/{id}/stream";

const BARS = [40, 62, 48, 70, 55, 80, 60, 74, 52, 66, 90, 58];

export default function ObservePage() {
  return (
    <AppShell crumb="Observe" runState="executing">
      <div className="page-wide">
        <PageHeader
          eyebrow="Observe / Monitoring"
          title="Runtime signals"
          subtitle="Health, runs, latency, traces and logs bound to the real backend surfaces. Live numbers project from the endpoints below; the charts are spec-only until an OTel collector is wired."
          actions={
            <>
              <SpecModeBadge mode="spec_only" />
              <Link href="/evidence" className="btn btn-sm">Open run →</Link>
            </>
          }
        />

        <div className="grid cols-2">
          <Panel title="Runtime services (cloud-superbrain-phase1-dev)">
            <div className="wb-pad stack" style={{ gap: 9 }}>
              {SERVICES.map((s) => {
                const layer = LAYERS[s.layer - 1];
                return (
                  <div key={s.name} className="svc-row">
                    <span className="layer-tag" style={{ background: layer.color, padding: "2px 7px", fontSize: 10.5 }}>L{s.layer}</span>
                    <span className="mono" style={{ fontSize: 13 }}>{s.name}</span>
                    <span className="svc-meta">{layer.label}</span>
                  </div>
                );
              })}
              <p style={{ fontSize: 11.5, color: "var(--text-dim)", marginTop: 4 }}>
                Health projects from <span className="mono">GET /api/v1/health</span>.
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
                <stop offset="0%" stopColor="#00e5ff" />
                <stop offset="100%" stopColor="#3b82f6" />
              </linearGradient>
            </defs>
          </svg>
          <p style={{ fontSize: 12, color: "var(--text-dim)", marginTop: 6 }}>
            Spec-only series. Bind a live OTel collector + <span className="mono">/api/v1/metrics</span> to
            replace it with real traffic; run state and traces correlate via{" "}
            <span className="mono">{STREAM_SURFACE}</span>.
          </p>
        </Panel>
      </div>
    </AppShell>
  );
}

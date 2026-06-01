import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Metric, Badge, Bar, SpecModeBadge } from "../../components/ui";

export const metadata = { title: "Observe / Monitoring — Cloud Superbrain" };

const SERVICES = [
  { name: "agent-api", health: 99 },
  { name: "mcp-gateway", health: 97 },
  { name: "llm-gateway", health: 94 },
  { name: "memory / pgvector", health: 99 },
  { name: "orchestrator", health: 96 },
];

const LOGS = [
  { lvl: "INFO", tone: "cyan" as const, msg: "Run plan created", t: "12:45:10" },
  { lvl: "INFO", tone: "cyan" as const, msg: "Agent started", t: "12:45:18" },
  { lvl: "WARN", tone: "amber" as const, msg: "Rate limit approaching", t: "12:45:24" },
  { lvl: "INFO", tone: "green" as const, msg: "Checks passed", t: "12:45:32" },
];

const BARS = [40, 62, 48, 70, 55, 80, 60, 74, 52, 66, 90, 58];

export default function ObservePage() {
  return (
    <AppShell crumb="Observe" runState="executing">
      <div className="page-wide">
        <PageHeader
          eyebrow="Observe / Monitoring"
          title="Runtime signals"
          subtitle="Health, runs, latency, traces and logs. Open a run to inspect its trace and evidence."
          actions={
            <>
              <SpecModeBadge mode="spec_only" />
              <Link href="/evidence" className="btn btn-sm">Open run →</Link>
            </>
          }
        />

        <div className="grid cols-3" style={{ marginBottom: 16 }}>
          <Metric label="Requests / min" value="1,287" foot={<Badge tone="green">+12.5%</Badge>} />
          <Metric label="Error rate" value="0.38%" foot={<Badge tone="green">−2.1%</Badge>} />
          <Metric label="Latency p95" value="243ms" foot={<Badge tone="amber">+8.7%</Badge>} />
        </div>

        <div className="grid cols-2">
          <Panel title="Traffic (OpenTelemetry)" pad>
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
              Bind a live OTel collector to replace this spec-only series.
            </p>
          </Panel>

          <Panel title="Services health">
            <div className="wb-pad stack" style={{ gap: 12 }}>
              {SERVICES.map((s) => (
                <div key={s.name} style={{ display: "flex", alignItems: "center", gap: 12 }}>
                  <span style={{ fontSize: 13, minWidth: 150 }} className="mono">{s.name}</span>
                  <Bar pct={s.health} />
                  <span style={{ fontSize: 11, color: "var(--text-mut)", minWidth: 34, textAlign: "right" }}>{s.health}%</span>
                </div>
              ))}
            </div>
          </Panel>
        </div>

        <Panel title="Logs" style={{ marginTop: 16 }}>
          <div className="list">
            {LOGS.map((l, i) => (
              <div key={i} className="lrow mono" style={{ fontSize: 12.5 }}>
                <Badge tone={l.tone}>{l.lvl}</Badge>
                <span>{l.msg}</span>
                <span className="meta">{l.t}</span>
              </div>
            ))}
          </div>
        </Panel>
      </div>
    </AppShell>
  );
}

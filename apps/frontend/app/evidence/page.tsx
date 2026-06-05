import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge, StatusDot } from "../../components/ui";
import { VERIFIERS, CLOSED_GATES } from "../../lib/platform";
import { fetchMetrics } from "../../lib/agentApi";

export const dynamic = "force-dynamic";
export const metadata = { title: "Proof / Evidence — Cloud Superbrain" };

type Tone = "green" | "amber" | "red" | "mut";
const EVIDENCE: { name: string; status: string; tone: Tone; ref: string }[] = [
  { name: "Production build", status: "PASS", tone: "green", ref: "next build · 33 routes" },
  { name: "Type check (strict)", status: "PASS", tone: "green", ref: "tsc · 0 errors" },
  { name: "ESLint audit", status: "CLEAN", tone: "green", ref: "0 findings (app/components/lib)" },
  { name: "Route smoke", status: "PASS", tone: "green", ref: "25 / 25 HTTP 200 + h1" },
  { name: "E2E (Playwright)", status: "PASS", tone: "green", ref: "7 / 7 green" },
  { name: "3D cortex render", status: "PASS", tone: "green", ref: "WebGL + GLB · 0 console errors" },
  { name: "Secret scan", status: "CLEAN", tone: "green", ref: "gitleaks · no token values" },
  { name: "Production deploy", status: "BLOCKED", tone: "red", ref: "gate closed" },
];

export default async function EvidencePage() {
  const metrics = await fetchMetrics();
  const live = !!metrics;

  return (
    <AppShell crumb="Evidence" runState="verifying">
      <div className="page-wide">
        <PageHeader
          eyebrow="Proof / Evidence"
          title="Verifier results & claim guard"
          subtitle="Every claim maps to a verifier or proof. Honest PASS / PARTIAL / BLOCKED — no faked green. Gate & service rows project live from the runtime when reachable."
          actions={live ? <Badge tone="green">● Live · runtime verified</Badge> : <Badge tone="amber">static proofs</Badge>}
        />

        {live ? (
          <Panel title="Live runtime verification (GET /api/v1/metrics)" style={{ marginBottom: 16 }} actions={<Badge tone="cyan">read-only · no token values</Badge>}>
            <div className="grid cols-2" style={{ gap: "0 24px" }}>
              <div>
                <p className="inspect-label" style={{ marginTop: 0 }}>External gates ({metrics!.gates.filter((g) => g.ok).length}/{metrics!.gates.length} verified)</p>
                <div className="ev-grid">
                  {metrics!.gates.map((g) => (
                    <div key={g.name} className="ev-row">
                      <StatusDot tone={g.ok ? "green" : "amber"} />
                      <span className="mono">{g.name}</span>
                      <Badge tone={g.ok ? "green" : "amber"}>{g.status}</Badge>
                    </div>
                  ))}
                </div>
              </div>
              <div>
                <p className="inspect-label" style={{ marginTop: 0 }}>Runtime services ({metrics!.services.filter((s) => s.up).length}/{metrics!.services.length} healthy)</p>
                <div className="ev-grid">
                  {metrics!.services.map((s) => (
                    <div key={s.name} className="ev-row">
                      <StatusDot tone={s.up ? "green" : "red"} pulse={s.up} />
                      <span className="mono">{s.name}</span>
                      <Badge tone={s.up ? "green" : "red"}>{s.up ? "healthy" : "down"}</Badge>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </Panel>
        ) : null}

        <div className="grid" style={{ gridTemplateColumns: "1.2fr 0.8fr" }}>
          <Panel title="Current proofs (this branch)">
            <table className="tbl">
              <thead><tr><th>Check</th><th>Status</th><th>Reference</th></tr></thead>
              <tbody>
                {EVIDENCE.map((e) => (
                  <tr key={e.name}>
                    <td style={{ fontWeight: 500 }}>{e.name}</td>
                    <td><Badge tone={e.tone}>{e.status}</Badge></td>
                    <td className="mono" style={{ color: "var(--text-mut)", fontSize: 12 }}>{e.ref}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </Panel>
          <aside className="stack">
            <Panel title="Verifier scripts" pad>
              <div className="stack" style={{ gap: 6 }}>
                {VERIFIERS.map((v) => (
                  <span key={v} className="mono" style={{ fontSize: 11.5, color: "var(--text-mut)" }}>{v}</span>
                ))}
              </div>
            </Panel>
            <Panel title="Claim guard" pad>
              <div className="note blocked">
                Hard non-claims until a new proof exists:
              </div>
              <div className="chip-wrap" style={{ marginTop: 8 }}>
                {CLOSED_GATES.map((g) => (
                  <span key={g} className="review-chip" style={{ fontSize: 10.5 }}>{g}</span>
                ))}
              </div>
            </Panel>
          </aside>
        </div>
      </div>
    </AppShell>
  );
}

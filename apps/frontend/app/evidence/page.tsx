import AppShell from "../../components/shell/AppShell";
import SevenLayerBar from "../../components/shell/SevenLayerBar";
import { PageHeader, Panel, Badge, StatusDot } from "../../components/ui";
import { VERIFIERS, CLOSED_GATES } from "../../lib/platform";
import { fetchMetrics, fetchProgress } from "../../lib/agentApi";

export const dynamic = "force-dynamic";
export const metadata = { title: "Proof / Evidence — Cloud Superbrain" };

export default async function EvidencePage() {
  const [metrics, progress] = await Promise.all([fetchMetrics(), fetchProgress()]);
  const live = !!metrics;
  const overall = typeof progress?.overall_percent === "number" ? progress.overall_percent : null;

  return (
    <AppShell crumb="Evidence" runState="verifying">
      <div className="page-wide">
        <PageHeader
          eyebrow="Proof / Evidence"
          title="Verifier results & claim guard"
          subtitle="Every claim must map to a verifier or runtime evidence. This UI shows live runtime signals when reachable and stays unverified for local-only checks until a verifier run exists."
          actions={
            <>
              {live ? <Badge tone="green">● Live · runtime metrics</Badge> : <Badge tone="mut">offline</Badge>}
              {typeof overall === "number" ? <Badge tone="cyan">{overall}% progress</Badge> : null}
              {progress?.last_verified ? <Badge tone="mut">last verified {progress.last_verified}</Badge> : null}
            </>
          }
        />

        <SevenLayerBar title="Every claim verified across 7 cloud layers" />

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
          <Panel title="Verifier scripts (not executed by this UI)">
            <table className="tbl">
              <thead><tr><th>Script</th><th>Status</th></tr></thead>
              <tbody>
                {VERIFIERS.map((v) => (
                  <tr key={v}>
                    <td className="mono" style={{ fontSize: 12 }}>{v}</td>
                    <td><Badge tone="mut">unverified</Badge></td>
                  </tr>
                ))}
              </tbody>
            </table>
            <div className="wb-pad" style={{ paddingTop: 10 }}>
              <span style={{ fontSize: 12, color: "var(--text-dim)" }}>
                Run verifiers locally to generate evidence artifacts. This page does not claim PASS without a run.
              </span>
            </div>
          </Panel>
          <aside className="stack">
            <Panel title="Progress snapshot" pad>
              <div className="stack" style={{ gap: 6 }}>
                <div className="row" style={{ justifyContent: "space-between" }}>
                  <span style={{ color: "var(--text-mut)" }}>Overall</span>
                  <span className="mono">{typeof overall === "number" ? `${overall}%` : "—"}</span>
                </div>
                <div className="row" style={{ justifyContent: "space-between" }}>
                  <span style={{ color: "var(--text-mut)" }}>Source</span>
                  <span className="mono">{progress?.progress_source ?? "—"}</span>
                </div>
                <div className="row" style={{ justifyContent: "space-between" }}>
                  <span style={{ color: "var(--text-mut)" }}>Integrity</span>
                  <span className="mono">{progress ? "manifest-backed" : "—"}</span>
                </div>
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

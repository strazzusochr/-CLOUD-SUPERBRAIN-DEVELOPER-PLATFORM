import AppShell from "../../components/shell/AppShell";
import SevenLayerBar from "../../components/shell/SevenLayerBar";
import { PageHeader, Panel, Badge, StatusDot } from "../../components/ui";
import { VERIFIERS, CLOSED_GATES } from "../../lib/platform";
import { fetchMetrics } from "../../lib/agentApi";
import { EvidenceVerifierProbe } from "../../components/batch4-actions";

export const dynamic = "force-dynamic";
export const metadata = { title: "Nachweise — Cloud Superbrain" };

export default async function EvidencePage() {
  const metrics = await fetchMetrics();
  const live = !!metrics;

  return (
    <AppShell crumb="Evidence" runState="verifying">
      <div className="page-wide">
        <PageHeader
          eyebrow="Nachweise"
          title="Verifier-Ergebnisse & Claim-Guard"
          subtitle="Jede Aussage muss durch Verifier oder Runtime-Evidence belegt sein. Wenn die Runtime erreichbar ist, zeigt diese Seite live Signale; sonst bleibt alles ehrlich unverified."
          actions={
            <>
              {live ? <Badge tone="green">● Live · Runtime-Metriken</Badge> : <Badge tone="mut">offline</Badge>}
            </>
          }
        />

        <SevenLayerBar title="Jeder Claim: verifiziert über 7 Cloud-Layer" />

        <Panel title="Read-only Verifier Probe" style={{ marginBottom: 16 }} pad>
          <EvidenceVerifierProbe />
        </Panel>

        {live ? (
          <Panel title="Live Runtime-Verification (GET /api/v1/metrics)" style={{ marginBottom: 16 }} actions={<Badge tone="cyan">read-only · keine Token-Werte</Badge>}>
            <div className="grid cols-2" style={{ gap: "0 24px" }}>
              <div>
                <p className="inspect-label" style={{ marginTop: 0 }}>Externe Gates ({metrics!.gates.filter((g) => g.ok).length}/{metrics!.gates.length} verifiziert)</p>
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
                <p className="inspect-label" style={{ marginTop: 0 }}>Runtime-Services ({metrics!.services.filter((s) => s.up).length}/{metrics!.services.length} healthy)</p>
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
          <Panel title="Verifier-Skripte (werden nicht von dieser UI ausgeführt)">
            <table className="tbl">
              <thead><tr><th>Skript</th><th>Status</th></tr></thead>
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
                Verifier lokal ausführen, um Evidence-Artefakte zu erzeugen. Diese Seite claimt kein PASS ohne Run.
              </span>
            </div>
          </Panel>
          <aside className="stack">
            <Panel title="Claim-Guard" pad>
              <div className="note blocked">
                Hard Non-Claims bis neue Proofs existieren:
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

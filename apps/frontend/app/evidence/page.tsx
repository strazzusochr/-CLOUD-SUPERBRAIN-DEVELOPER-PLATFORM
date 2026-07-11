import AppShell from "../../components/shell/AppShell";
import { LiveConsole } from "../../components/live-console";
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
    <AppShell crumb="Nachweise" runState="verifying">
      <div className="page-wide">
        <PageHeader
          eyebrow="Nachweise"
          title="Prüfergebnisse und Aussage-Schutz"
          subtitle="Jede Aussage muss durch einen Verifier oder einen Laufzeitnachweis belegt sein. Wenn die Laufzeit erreichbar ist, zeigt diese Seite Live-Signale; andernfalls bleibt alles ehrlich unverifiziert."
          actions={
            <>
              {live ? <Badge tone="green">● Live · Runtime-Metriken</Badge> : <Badge tone="mut">offline</Badge>}
            </>
          }
        />
        <Panel title="Live-Daten" className="mb-16" actions={<Badge tone="cyan">interaktiv</Badge>}>
          <div className="wb-pad">
            <LiveConsole endpoints={[{ label: "Externe Gates", path: "/api/v1/external-gates" }, { label: "Fortschrittsintegrität", path: "/api/v1/project/progress/integrity" }]} />
          </div>
        </Panel>

        <Panel title="Nur lesende Verifier-Prüfung" className="mb-16" pad>
          <EvidenceVerifierProbe />
        </Panel>

        {live ? (
          <Panel title="Live-Laufzeitprüfung (GET /api/v1/metrics)" className="mb-16" actions={<Badge tone="cyan">nur lesend · keine Token-Werte</Badge>}>
            <div className="grid cols-2 ev-split">
              <div>
                <p className="inspect-label mt-0">Externe Gates ({metrics!.gates.filter((g) => g.ok).length}/{metrics!.gates.length} verifiziert)</p>
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
                <p className="inspect-label mt-0">Laufzeitdienste ({metrics!.services.filter((s) => s.up).length}/{metrics!.services.length} gesund)</p>
                <div className="ev-grid">
                  {metrics!.services.map((s) => (
                    <div key={s.name} className="ev-row">
                      <StatusDot tone={s.up ? "green" : "red"} pulse={s.up} />
                      <span className="mono">{s.name}</span>
                      <Badge tone={s.up ? "green" : "red"}>{s.up ? "gesund" : "nicht erreichbar"}</Badge>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </Panel>
        ) : null}

        <div className="grid grid-evidence">
          <Panel title="Verifier-Skripte (werden nicht von dieser UI ausgeführt)">
            <table className="tbl">
              <thead><tr><th>Skript</th><th>Status</th></tr></thead>
              <tbody>
                {VERIFIERS.map((v) => (
                  <tr key={v}>
                    <td className="mono tbl-mono-sm">{v}</td>
                    <td><Badge tone="mut">unverifiziert</Badge></td>
                  </tr>
                ))}
              </tbody>
            </table>
            <div className="wb-pad pt-10">
              <span className="text-12 text-dim">
                Verifier lokal ausführen, um Nachweisartefakte zu erzeugen. Diese Seite meldet ohne Lauf kein PASS.
              </span>
            </div>
          </Panel>
          <aside className="stack">
            <Panel title="Aussage-Schutz" pad>
              <div className="note blocked">
                Harte Nichtaussagen, bis neue Nachweise existieren:
              </div>
              <div className="chip-wrap mt-8">
                {CLOSED_GATES.map((g) => (
                  <span key={g} className="review-chip">{g}</span>
                ))}
              </div>
            </Panel>
          </aside>
        </div>
      </div>
    </AppShell>
  );
}

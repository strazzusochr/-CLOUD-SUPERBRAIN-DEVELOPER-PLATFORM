import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import SevenLayerBar from "../../components/shell/SevenLayerBar";
import { PageHeader, Panel, Metric, Badge, StatusDot } from "../../components/ui";
import { Icon } from "../../lib/nav";
import { fetchCompletionGate, fetchLayers, fetchLiveAgents, fetchRecentSessions } from "../../lib/agentApi";

export const dynamic = "force-dynamic";
export const metadata = { title: "Home — Cloud Superbrain" };

export default async function HomePage() {
  const [roster, sessions, layers, completion] = await Promise.all([
    fetchLiveAgents(),
    fetchRecentSessions(),
    fetchLayers(),
    fetchCompletionGate(),
  ]);
  const live = !!layers;

  const activeSessions = roster ? roster.agents.filter((a) => a.hasSession).length : 0;
  const agentValue = roster ? `${activeSessions} / ${roster.agents.length}` : "—";
  const projectCount = sessions ? new Set(sessions.map((s) => s.projectId).filter(Boolean)).size : null;
  const layersVerified = layers ? layers.filter((l) => l.verified).length : null;
  const layersTotal = layers ? layers.length : null;
  const gatesValue = completion ? (completion.canSetAllTo100 ? "OFFEN" : "GESCHLOSSEN") : "GESCHLOSSEN";

  return (
    <AppShell crumb="Home" runState="idle">
      <div className="page">
        <PageHeader
          eyebrow="Übersicht"
          title="Willkommen zurück"
          subtitle="Mach da weiter, wo du aufgehört hast: letztes Projekt öffnen oder einen neuen Lauf in der Werkbank starten."
          actions={
            <Link href="/workbench" className="btn btn-primary">
              {Icon.workbench({ size: 16 })} Werkbank öffnen
            </Link>
          }
        />

        <div className="grid cols-4" style={{ marginBottom: 16 }}>
          <Metric
            label="Letzte Projekte"
            value={typeof projectCount === "number" ? String(projectCount) : "—"}
            foot={sessions ? <><StatusDot tone="green" pulse /> live · Sessions</> : <><StatusDot tone="mut" /> nicht verfügbar</>}
          />
          <Metric
            label="Agenten aktiv"
            value={agentValue}
            foot={roster ? <><StatusDot tone="green" pulse /> live · Roster</> : <><StatusDot tone="mut" /> nicht verfügbar</>}
          />
          <Metric
            label="Cloud-Layer"
            value={typeof layersVerified === "number" && typeof layersTotal === "number" ? `${layersVerified}/${layersTotal}` : "—"}
            foot={layers ? <><StatusDot tone="green" pulse /> live · Layer</> : <><StatusDot tone="mut" /> nicht verfügbar</>}
          />
          <Metric
            label="Gates"
            value={gatesValue}
            foot={completion ? <><StatusDot tone={completion.canSetAllTo100 ? "red" : "green"} pulse={!completion.canSetAllTo100} /> Completion-Gate</> : <><StatusDot tone="green" /> safe by default</>}
          />
        </div>

        <div className="grid cols-2">
          <Panel
            title="Letzte Projekte"
            actions={<Link href="/apps" className="btn btn-sm btn-ghost">Alle →</Link>}
          >
            <div className="list">
              {sessions?.length ? sessions.slice(0, 6).map((s) => (
                <Link key={s.id} href="/workbench" className="lrow">
                  {Icon.files({ size: 16 })}
                  <span style={{ fontWeight: 500 }}>{s.projectId || "project"}</span>
                  <Badge tone={s.status === "active" ? "green" : "mut"}>{s.status}</Badge>
                  <span className="meta">{s.startedAt ? s.startedAt.slice(0, 19).replace("T", " ") : ""}</span>
                </Link>
              )) : (
                <div className="lrow" style={{ color: "var(--text-mut)" }}>
                  {Icon.files({ size: 16 })}
                  <span style={{ fontWeight: 500 }}>Keine Sessions gefunden</span>
                  <Badge tone="mut">{live ? "live" : "offline"}</Badge>
                  <span className="meta">Starte in der Werkbank</span>
                </div>
              )}
            </div>
          </Panel>

          <Panel title="Nächster sicherer Schritt" pad>
            <div className="stack">
              <div className="note">{live ? "Runtime erreichbar. Gates bleiben geschlossen; zuerst read-only prüfen." : "Runtime nicht erreichbar. Die UI bleibt read-only (kein Fake-Live)."} </div>
              <div className="row" style={{ gap: 10 }}>
                <Link href="/workbench" className="btn btn-primary">In der Werkbank fortsetzen</Link>
                <Link href="/organism" className="btn">Cortex ansehen</Link>
                <Link href="/evidence" className="btn btn-ghost">Nachweise öffnen</Link>
              </div>
              <div>
                <span className="panel-title" style={{ display: "block", marginBottom: 8 }}>
                  Output-Shortcuts
                </span>
                <div className="chips">
                  <Link href="/games" className="chip">Spiele</Link>
                  <Link href="/apps" className="chip">Apps</Link>
                  <Link href="/media" className="chip">Medien</Link>
                  <Link href="/docs-output" className="chip">Dokumente</Link>
                </div>
              </div>
            </div>
          </Panel>
        </div>

        <div style={{ marginTop: 16 }}>
          <SevenLayerBar />
        </div>
      </div>
    </AppShell>
  );
}

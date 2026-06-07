import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, EmptyState, Badge } from "../../components/ui";
import { fetchRecentTasks } from "../../lib/agentApi";

export const metadata = { title: "Media Workflow — Cloud Superbrain" };
export const dynamic = "force-dynamic";

export default async function MediaPage() {
  const tasks = await fetchRecentTasks();
  const live = !!tasks;
  const list = tasks?.tasks ?? [];
  const filtered = list.filter((t) => /(media|image|video|audio|voice|speech|music)/i.test(`${t.taskType} ${t.description}`));
  return (
    <AppShell crumb="Media" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Medien"
          title="Images · Video · Audio"
          subtitle="Medien-orientierter Arbeitsbereich. Read-only: zeigt media-nahe Tasks, wenn vorhanden, sonst bleibt es leer."
          actions={
            <>
              {live ? <Badge tone="green">● Live</Badge> : <Badge tone="mut">offline</Badge>}
              {tasks ? <Badge tone="mut">queue {tasks.queueDepth}</Badge> : null}
            </>
          }
        />
        <div className="grid" style={{ gridTemplateColumns: "240px 1fr 300px" }}>
          <Panel title="Storyboard">
            <div className="wb-pad stack" style={{ gap: 8 }}>
              {filtered.length ? filtered.slice(0, 6).map((t) => (
                <div key={t.id} className="frame-body" style={{ borderRadius: 8, border: "1px solid var(--border)", padding: 10 }}>
                  <div className="row" style={{ gap: 8, flexWrap: "wrap" }}>
                    <Badge tone={t.status === "completed" ? "green" : t.status === "failed" ? "red" : "mut"}>{t.status}</Badge>
                    <span className="mono" style={{ fontSize: 11.5, color: "var(--text-dim)" }}>{t.taskType}</span>
                  </div>
                  <div style={{ marginTop: 6, fontSize: 12.5, color: "var(--text-mut)" }}>{t.description}</div>
                </div>
              )) : (
                <div className="frame-body" style={{ height: 64, borderRadius: 8, border: "1px solid var(--border)", display: "flex", alignItems: "center", padding: 10, color: "var(--text-mut)" }}>
                  Noch keine Medien-Tasks
                </div>
              )}
            </div>
          </Panel>
          <Panel title="Media stage">
            <div className="wb-pad">
              <div className="chips" style={{ marginBottom: 12 }}>
                <span className="chip active">Bild</span>
                <span className="chip">Video</span>
                <span className="chip">Audio</span>
              </div>
              <EmptyState
                title={filtered.length ? "Medien-Tasks vorhanden" : "Noch keine Medien generiert"}
                body={filtered.length ? "Erzeuge Output über die Werkbank; diese Seite projiziert nur Task-Metadaten." : "Starte ein Briefing in der Werkbank mit mode=Media. Diese Seite erfindet keine Previews."}
                action={<Link href="/workbench" className="btn btn-sm btn-primary">Werkbank öffnen</Link>}
              />
            </div>
          </Panel>
          <Panel title="Prompt-Brief">
            <div className="wb-pad">
              <p style={{ fontSize: 13, color: "var(--text-mut)" }}>
                Beschreibe das Bild/Video/Audio. Imports und Previews erscheinen hier zuerst.
              </p>
            </div>
          </Panel>
        </div>
      </div>
    </AppShell>
  );
}

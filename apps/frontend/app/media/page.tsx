import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { LiveConsole } from "../../components/live-console";
import { PageHeader, Panel, EmptyState, Badge } from "../../components/ui";
import { fetchRecentTasks } from "../../lib/agentApi";
import { WorkspaceModeActionPanel } from "../../components/goal-b-actions";

export const metadata = { title: "Media Workflow — Cloud Superbrain" };
export const dynamic = "force-dynamic";

type SearchParams = Record<string, string | string[] | undefined>;
type MediaPageProps = {
  searchParams?: Promise<SearchParams>;
};
async function resolveSearchParams(searchParams: MediaPageProps["searchParams"]): Promise<SearchParams> {
  if (!searchParams) return {};
  return searchParams;
}

export default async function MediaPage({ searchParams }: MediaPageProps) {
  const resolvedSearchParams = await resolveSearchParams(searchParams);
  const tasks = await fetchRecentTasks();
  const live = !!tasks;
  const list = tasks?.tasks ?? [];
  const filtered = list.filter((t) => /(media|image|video|audio|voice|speech|music)/i.test(`${t.taskType} ${t.description}`));
  const typeRaw = resolvedSearchParams.type;
  const type = (Array.isArray(typeRaw) ? typeRaw[0] : typeRaw) ?? "image";
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
        <div className="grid grid-games">
          <Panel title="Live console" className="mb-16" actions={<Badge tone="cyan">interaktiv</Badge>}>
            <div className="wb-pad">
              <LiveConsole endpoints={[{ label: "Model capabilities", path: "/api/v1/models/capabilities" }]} />
            </div>
          </Panel>
          <Panel title="Storyboard">
            <div className="wb-pad stack gap-8">
              {filtered.length ? filtered.slice(0, 6).map((t) => (
                <div key={t.id} className="frame-body frame-card">
                  <div className="row gap-8 wrap">
                    <Badge tone={t.status === "completed" ? "green" : t.status === "failed" ? "red" : "mut"}>{t.status}</Badge>
                    <span className="mono text-115 text-dim">{t.taskType}</span>
                  </div>
                  <div className="agent-role mt-8">{t.description}</div>
                </div>
              )) : (
                <div className="frame-body frame-card frame-empty">
                  Noch keine Medien-Tasks
                </div>
              )}
            </div>
          </Panel>
          <Panel title="Media stage">
            <div className="wb-pad">
              <div className="chips mb-12">
                <Link href="/media?type=image" className={`chip${type === "image" ? " active" : ""}`}>Bild</Link>
                <Link href="/media?type=video" className={`chip${type === "video" ? " active" : ""}`}>Video</Link>
                <Link href="/media?type=audio" className={`chip${type === "audio" ? " active" : ""}`}>Audio</Link>
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
              <WorkspaceModeActionPanel mode="media" label="Media" />
              <p className="text-13 text-mut">
                Beschreibe das Bild/Video/Audio. Imports und Previews erscheinen hier zuerst.
              </p>
            </div>
          </Panel>
        </div>
      </div>
    </AppShell>
  );
}

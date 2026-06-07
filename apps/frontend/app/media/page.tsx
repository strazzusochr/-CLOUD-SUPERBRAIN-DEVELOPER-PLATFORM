import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, EmptyState, Badge } from "../../components/ui";
import { fetchMasterPlan, fetchRecentTasks } from "../../lib/agentApi";

export const metadata = { title: "Media Workflow — Cloud Superbrain" };
export const dynamic = "force-dynamic";

export default async function MediaPage() {
  const [master, tasks] = await Promise.all([fetchMasterPlan(), fetchRecentTasks()]);
  const live = !!master;
  const list = tasks?.tasks ?? [];
  const filtered = list.filter((t) => /(media|image|video|audio|voice|speech|music)/i.test(`${t.taskType} ${t.description}`));
  return (
    <AppShell crumb="Media" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Media Workflow"
          title="Images · Video · Audio"
          subtitle="Media-oriented work area. This surface is read-only: it shows media-related tasks when present and stays empty otherwise."
          actions={
            <>
              {live ? <Badge tone="green">● Live · {master!.overallPercent}%</Badge> : <Badge tone="mut">offline</Badge>}
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
                  No media tasks yet
                </div>
              )}
            </div>
          </Panel>
          <Panel title="Media stage">
            <div className="wb-pad">
              <div className="chips" style={{ marginBottom: 12 }}>
                <span className="chip active">Image</span>
                <span className="chip">Video</span>
                <span className="chip">Audio</span>
              </div>
              <EmptyState
                title={filtered.length ? "Media tasks exist" : "No media generated yet"}
                body={filtered.length ? "Create output through the Workbench; this page only projects task metadata." : "Start a brief from the Workbench with mode=Media. This page does not fabricate previews."}
                action={<Link href="/workbench" className="btn btn-sm btn-primary">Open Workbench</Link>}
              />
            </div>
          </Panel>
          <Panel title="Prompt brief">
            <div className="wb-pad">
              <p style={{ fontSize: 13, color: "var(--text-mut)" }}>
                Describe the image, video or audio you want. Imports and previews appear here first.
              </p>
            </div>
          </Panel>
        </div>
      </div>
    </AppShell>
  );
}

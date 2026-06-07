import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge, EmptyState } from "../../components/ui";
import { Icon } from "../../lib/nav";
import { fetchMasterPlan, fetchRecentTasks } from "../../lib/agentApi";

export const metadata = { title: "Games Workflow — Cloud Superbrain" };
export const dynamic = "force-dynamic";

const TEMPLATES = ["Top-down", "Platformer", "Third-person", "Puzzle"];

export default async function GamesPage() {
  const [master, tasks] = await Promise.all([fetchMasterPlan(), fetchRecentTasks()]);
  const live = !!master;
  const list = tasks?.tasks ?? [];
  const filtered = list.filter((t) => /(game|r3f|three|webgl|scene|physics)/i.test(`${t.taskType} ${t.description}`));
  return (
    <AppShell crumb="Games" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Games Workflow"
          title="Game projects"
          subtitle="Game-oriented work area. When the runtime is reachable, the panels project recent game-related tasks from the queue; otherwise they stay offline."
          actions={
            <>
              {live ? <Badge tone="green">● Live · {master!.overallPercent}%</Badge> : <Badge tone="mut">offline</Badge>}
              {tasks ? <Badge tone="mut">queue {tasks.queueDepth}</Badge> : null}
              <Link href="/workbench" className="btn btn-sm">Open in Workbench</Link>
            </>
          }
        />
        <div className="grid" style={{ gridTemplateColumns: "240px 1fr 300px" }}>
          <Panel title="Templates">
            <div className="list">
              {TEMPLATES.map((t, i) => (
                <div key={t} className={`lrow${i === 2 ? "" : ""}`} style={{ fontSize: 13 }}>{t}</div>
              ))}
            </div>
          </Panel>
          <Panel title="Scene preview · superbrain-game-engine">
            <div className="wb-pad">
              {filtered.length ? (
                <div className="stack" style={{ gap: 10 }}>
                  {filtered.slice(0, 6).map((t) => (
                    <div key={t.id} className="svc-row">
                      <Badge tone={t.status === "completed" ? "green" : t.status === "failed" ? "red" : "mut"}>{t.status}</Badge>
                      <span className="mono" style={{ fontSize: 11.5, color: "var(--text-dim)" }}>{t.taskType}</span>
                      <span style={{ color: "var(--text-mut)", fontSize: 12 }}>{t.description}</span>
                    </div>
                  ))}
                  <div className="row" style={{ gap: 8 }}>
                    <Link href="/workbench" className="btn btn-sm btn-primary">{Icon.play({ size: 13 })} Open Workbench</Link>
                    <Link href="/organism" className="btn btn-sm btn-ghost">Cortex</Link>
                  </div>
                </div>
              ) : (
                <EmptyState
                  title="No game tasks yet"
                  body="Create a game task from the Workbench. This surface stays read-only and does not fabricate previews."
                  action={<Link href="/workbench" className="btn btn-sm btn-primary">Open Workbench</Link>}
                />
              )}
            </div>
          </Panel>
          <Panel title="Assets">
            <div className="wb-pad">
              <EmptyState
                title="No assets indexed here"
                body="Asset inventory is not wired in this build. Use Files & Knowledge for the memory-backed view."
                action={<Link href="/files" className="btn btn-sm btn-ghost">Open Files</Link>}
              />
            </div>
          </Panel>
        </div>
      </div>
    </AppShell>
  );
}

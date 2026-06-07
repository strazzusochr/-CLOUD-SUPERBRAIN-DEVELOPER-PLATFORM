import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { PageHeader, Badge, EmptyState } from "../../components/ui";
import { fetchRecentTasks, fetchRecentSessions } from "../../lib/agentApi";

export const metadata = { title: "Apps / Generated Output — Cloud Superbrain" };
export const dynamic = "force-dynamic";

function appHint(t: { taskType: string; description: string }) {
  const text = `${t.taskType} ${t.description}`.toLowerCase();
  if (/(game|r3f|three|webgl|scene)/.test(text)) return { kind: "Game", tone: "violet" as const };
  if (/(doc|markdown|writeup|report|spec)/.test(text)) return { kind: "Doc", tone: "amber" as const };
  if (/(tool|mcp|gateway|infra|deploy)/.test(text)) return { kind: "Tool", tone: "cyan" as const };
  return { kind: "App", tone: "green" as const };
}

export default async function AppsPage() {
  const [tasks, sessions] = await Promise.all([fetchRecentTasks(), fetchRecentSessions()]);
  const live = !!tasks || !!sessions;
  const list = tasks?.tasks ?? [];
  const filtered = list.filter((t) => /(app|ui|dashboard|frontend|next|react)/i.test(`${t.taskType} ${t.description}`));
  const shown = (filtered.length ? filtered : list).slice(0, 12);
  return (
    <AppShell crumb="Apps" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Apps / Output"
          title="Generierte Apps"
          subtitle="Read-only Output-Index aus echten Tasks/Sessions. Keine Fake-Karten: wenn nichts existiert, bleibt die Liste leer."
          actions={
            <>
              {live ? <Badge tone="green">● Live</Badge> : <Badge tone="mut">offline</Badge>}
              {tasks ? <Badge tone="mut">queue {tasks.queueDepth}</Badge> : null}
              {sessions ? <Badge tone="violet">{sessions.length} sessions</Badge> : null}
              <Link href="/workbench" className="btn btn-sm btn-primary">Neu in der Werkbank</Link>
            </>
          }
        />
        <div className="card-grid">
          {shown.length ? shown.map((t) => {
            const hint = appHint(t);
            return (
              <div key={t.id} className="gcard">
                <div className="preview"><Badge tone={hint.tone}>{hint.kind}</Badge></div>
                <div className="body">
                  <h3 className="mono" style={{ fontSize: 13.5 }}>{t.taskType}</h3>
                  <div className="sub" style={{ minHeight: 32 }}>{t.description}</div>
                  <div className="actions" style={{ gap: 6 }}>
                    <Badge tone={t.status === "completed" ? "green" : t.status === "failed" ? "red" : "mut"}>{t.status}</Badge>
                    <Badge tone="mut">{t.agentType}</Badge>
                  </div>
                  <div className="actions">
                    <Link href="/workbench" className="btn btn-sm btn-primary">Öffnen</Link>
                    <Link href="/evidence" className="btn btn-sm btn-ghost">Review</Link>
                  </div>
                </div>
              </div>
            );
          }) : (
            <div className="panel panel-pad" style={{ gridColumn: "1 / -1" }}>
              <EmptyState
                title="Noch keine App-Outputs"
                body="Starte in der Werkbank. Diese Surface listet nur echte Tasks/Sessions."
                action={<Link href="/workbench" className="btn btn-sm btn-primary">Werkbank öffnen</Link>}
              />
            </div>
          )}
        </div>
      </div>
    </AppShell>
  );
}

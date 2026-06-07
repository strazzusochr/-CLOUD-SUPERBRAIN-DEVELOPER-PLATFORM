import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge, EmptyState } from "../../components/ui";
import { Icon } from "../../lib/nav";
import { fetchMasterPlan, fetchRecentSessions } from "../../lib/agentApi";

export const metadata = { title: "Documents Workflow — Cloud Superbrain" };
export const dynamic = "force-dynamic";

function previewText(raw: string) {
  const trimmed = raw.trim();
  if (trimmed.length <= 2400) return trimmed;
  return `${trimmed.slice(0, 2400)}\n\n… (truncated)`;
}

export default async function DocsOutputPage() {
  const [master, sessions] = await Promise.all([fetchMasterPlan(), fetchRecentSessions()]);
  const live = !!master;
  const withOutput = sessions?.filter((s) => !!(s.assistantResult && String(s.assistantResult).trim())).slice(0, 12) ?? [];
  const selected = withOutput.length ? withOutput[0] : null;
  return (
    <AppShell crumb="Documents" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Documents Workflow"
          title="Markdown & document output"
          subtitle="Run output projection (assistant results). This surface shows what the runtime produced; file export stays gated."
          actions={
            <>
              {live ? <Badge tone="green">● Live · {master!.overallPercent}%</Badge> : <Badge tone="mut">offline</Badge>}
              {sessions ? <Badge tone="violet">{sessions.length} sessions</Badge> : null}
              <Link href="/workbench" className="btn btn-sm btn-primary">Open Workbench</Link>
            </>
          }
        />
        <div className="grid" style={{ gridTemplateColumns: "240px 1fr 300px" }}>
          <Panel title="Documents">
            <div className="list">
              {withOutput.length ? withOutput.map((s, i) => (
                <div key={s.id} className={`tnode${i === 0 ? " sel" : ""}`} style={{ padding: "8px 12px", display: "flex", alignItems: "center", gap: 8 }}>
                  {Icon.docs({ size: 14 })}
                  <span className="mono" style={{ fontSize: 11.5 }}>{s.projectId || "project"}</span>
                  <span className="meta" style={{ marginLeft: "auto" }}>{s.startedAt ? s.startedAt.slice(0, 19).replace("T", " ") : ""}</span>
                </div>
              )) : (
                <div className="tnode" style={{ padding: "8px 12px", color: "var(--text-mut)" }}>
                  {Icon.docs({ size: 14 })} No document outputs yet
                </div>
              )}
            </div>
          </Panel>
          <Panel title={selected ? "Preview · latest run output" : "Preview"}>
            <div className="wb-pad">
              {selected?.assistantResult ? (
                <pre className="code" style={{ whiteSpace: "pre-wrap" }}>{previewText(String(selected.assistantResult))}</pre>
              ) : (
                <EmptyState
                  title="Nothing to preview"
                  body="Start a run from the Workbench. This page only shows real session outputs."
                  action={<Link href="/workbench" className="btn btn-sm btn-primary">Open Workbench</Link>}
                />
              )}
            </div>
          </Panel>
          <Panel title="Cite · Export">
            <div className="wb-pad stack" style={{ gap: 10 }}>
              <button className="btn btn-sm">Export PDF <Badge tone="violet">planned</Badge></button>
              <button className="btn btn-sm">Export MD</button>
              <p style={{ fontSize: 12, color: "var(--text-dim)" }}>Source collector and citations appear here.</p>
            </div>
          </Panel>
        </div>
      </div>
    </AppShell>
  );
}

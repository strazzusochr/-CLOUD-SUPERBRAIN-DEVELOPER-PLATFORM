import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge, EmptyState } from "../../components/ui";
import { Icon } from "../../lib/nav";
import { fetchRecentSessions } from "../../lib/agentApi";
import { WorkspaceModeActionPanel, DocsExportPanel } from "../../components/goal-b-actions";

export const metadata = { title: "Documents Workflow — Cloud Superbrain" };
export const dynamic = "force-dynamic";

function previewText(raw: string) {
  const trimmed = raw.trim();
  if (trimmed.length <= 2400) return trimmed;
  return `${trimmed.slice(0, 2400)}\n\n… (truncated)`;
}

export default async function DocsOutputPage() {
  const sessions = await fetchRecentSessions();
  const live = !!sessions;
  const withOutput = sessions?.filter((s) => !!(s.assistantResult && String(s.assistantResult).trim())).slice(0, 12) ?? [];
  const selected = withOutput.length ? withOutput[0] : null;
  const exportTitle = selected ? `${selected.projectId || "project"}-${selected.id.slice(0, 8)}` : "cloud-superbrain-export";
  const exportContent = selected?.assistantResult ? String(selected.assistantResult) : "";
  return (
    <AppShell crumb="Documents" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Dokumente"
          title="Markdown- & Dokument-Output"
          subtitle="Projection von echten Run-Outputs (assistant results) mit lokalem Markdown-/PDF-Export."
          actions={
            <>
              {live ? <Badge tone="green">● Live</Badge> : <Badge tone="mut">offline</Badge>}
              {sessions ? <Badge tone="violet">{sessions.length} sessions</Badge> : null}
              <Link href="/workbench" className="btn btn-sm btn-primary">Werkbank öffnen</Link>
            </>
          }
        />
        <div className="grid docs-output-grid">
          <Panel title="Dokumente">
            <div className="list">
              {withOutput.length ? withOutput.map((s, i) => (
                <div key={s.id} className={`tnode docs-output-node${i === 0 ? " sel" : ""}`}>
                  {Icon.docs({ size: 14 })}
                  <span className="mono docs-output-project">{s.projectId || "project"}</span>
                  <span className="meta docs-output-meta">{s.startedAt ? s.startedAt.slice(0, 19).replace("T", " ") : ""}</span>
                </div>
              )) : (
                <div className="tnode docs-output-empty">
                  {Icon.docs({ size: 14 })} Noch keine Dokument-Outputs
                </div>
              )}
            </div>
          </Panel>
          <Panel title={selected ? "Preview · letzter Run-Output" : "Preview"}>
            <div className="wb-pad">
              {selected?.assistantResult ? (
                <pre className="code code-prewrap">{previewText(String(selected.assistantResult))}</pre>
              ) : (
                <EmptyState
                  title="Nichts zum Anzeigen"
                  body="Starte einen Run in der Werkbank. Diese Seite zeigt nur echte Session-Outputs."
                  action={<Link href="/workbench" className="btn btn-sm btn-primary">Werkbank öffnen</Link>}
                />
              )}
            </div>
          </Panel>
          <Panel title="Zitate · Export">
            <div className="wb-pad stack stack-gap-10">
              <WorkspaceModeActionPanel mode="docs-output" label="Document" />
              <DocsExportPanel
                exportTitle={exportTitle}
                exportContent={exportContent}
                projectId={selected?.projectId ?? "goal-b-local"}
                sessionId={selected?.id ?? null}
              />
              <p className="helper-copy">
                Ohne Session-Output faellt der Export ehrlich auf die lokale End-Ziel-Spec zurueck.
              </p>
            </div>
          </Panel>
        </div>
      </div>
    </AppShell>
  );
}

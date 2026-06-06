import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge, SpecModeBadge } from "../../components/ui";

export const metadata = { title: "Documents Workflow — Cloud Superbrain" };

const DOCS = ["platform-architecture.md", "character_ability.md", "release-notes.md"];

export default function DocsOutputPage() {
  return (
    <AppShell crumb="Documents" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Documents Workflow"
          title="Markdown & document output"
          subtitle="Preview, citations and export. Markdown preview is live from local files; PDF/DOCX export is planned."
          actions={<SpecModeBadge mode="local_files" />}
        />
        <div className="grid" style={{ gridTemplateColumns: "240px 1fr 300px" }}>
          <Panel title="Documents">
            <div className="list">
              {DOCS.map((d, i) => (
                <div key={d} className={`tnode${i === 0 ? " sel" : ""}`} style={{ padding: "8px 12px" }}>{d}</div>
              ))}
            </div>
          </Panel>
          <Panel title="Preview · platform-architecture.md">
            <div className="wb-pad prose">
              <h2 style={{ marginTop: 0 }}>Cloud Superbrain Architecture</h2>
              <p>
                The platform is organised into seven cooperating layers — FE, ORC, AP, LLM, MCP, MEM
                and OBS — mapped onto a living cortex of ten regions. Each agent action is a synapse;
                each event a travelling pulse.
              </p>
              <h2>Run flow</h2>
              <p>Prompt → canonical run → traces / files / evidence → cortex, workbench and observe surfaces.</p>
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

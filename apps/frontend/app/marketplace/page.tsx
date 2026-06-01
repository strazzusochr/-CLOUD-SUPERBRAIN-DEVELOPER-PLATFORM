import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge } from "../../components/ui";

export const metadata = { title: "Marketplace — Cloud Superbrain" };

const ITEMS = [
  { name: "Unreal Engine Starter", kind: "Template", rating: "4.9", lic: "MIT" },
  { name: "Neuro UI Kit", kind: "Template", rating: "4.8", lic: "MIT" },
  { name: "AI Image Pipeline", kind: "Workflow", rating: "4.7", lic: "Apache-2.0" },
  { name: "Character Controller", kind: "Skill", rating: "4.6", lic: "MIT" },
  { name: "Verifier Suite", kind: "Skill", rating: "4.8", lic: "MIT" },
  { name: "LangGraph Orchestrator", kind: "Agent", rating: "4.5", lic: "MIT" },
  { name: "pgvector RAG", kind: "MCP", rating: "4.7", lic: "PostgreSQL" },
  { name: "Terraform Module Pack", kind: "Workflow", rating: "4.4", lic: "MPL-2.0" },
];

export default function MarketplacePage() {
  return (
    <AppShell crumb="Marketplace" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Marketplace"
          title="Skills, agents, models & templates"
          subtitle="Browse and install community building blocks. Trust and licence are shown per item; install is a dry-run until approved."
        />
        <div className="chips" style={{ marginBottom: 16 }}>
          <span className="chip active">All</span>
          <span className="chip">Templates</span>
          <span className="chip">Skills</span>
          <span className="chip">Agents</span>
          <span className="chip">Models</span>
          <span className="chip">MCP</span>
          <span className="chip">Workflows</span>
        </div>
        <div className="card-grid">
          {ITEMS.map((it) => (
            <div key={it.name} className="gcard">
              <div className="preview">{it.kind}</div>
              <div className="body">
                <h3>{it.name}</h3>
                <div className="sub">★ {it.rating} · <span className="mono">{it.lic}</span></div>
                <div className="actions">
                  <button className="btn btn-sm btn-primary">Install</button>
                  <button className="btn btn-sm btn-ghost">Details</button>
                </div>
              </div>
            </div>
          ))}
        </div>
        <p style={{ fontSize: 12, color: "var(--text-dim)", marginTop: 12 }}>
          <Badge tone="amber">dry-run</Badge> Installs are simulated until the owner gate is opened.
        </p>
      </div>
    </AppShell>
  );
}

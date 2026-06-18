import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge } from "../../components/ui";
import { AGENTS } from "../../lib/platform";
import { AgentRun } from "../../components/agent-run";

export const dynamic = "force-dynamic";
export const metadata = { title: "Agenten — Cloud Superbrain" };

// Multi-agent deep research: a goal is split across roles (Planner → Researcher →
// Writer), each a real LLM step, with real web sources. Plus the agent team.
export default function AgentsPage() {
  return (
    <AppShell crumb="Agenten" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Agenten"
          title="Multi-Agent Deep-Research"
          subtitle="Gib ein Ziel ein — mehrere Agenten arbeiten zusammen (Planner → Researcher → Writer) und liefern eine fundierte, mit Quellen belegte Antwort."
        />

        <Panel title="Deep-Research starten" className="mb-16" actions={<Badge tone="green">echt · live LLM</Badge>}>
          <div className="wb-pad">
            <AgentRun />
          </div>
        </Panel>

        <Panel title="Das Agenten-Team" actions={<Badge tone="cyan">{AGENTS.length} Rollen</Badge>}>
          <div className="grid cols-2">
            {AGENTS.map((a) => (
              <div key={a.type} className="agent-team-card">
                <div className="agent-head">
                  <span className="agent-type">{a.type}</span>
                  <span className="agent-model mono text-12 text-mut">{a.model}</span>
                </div>
                <p className="agent-role">{a.role}</p>
              </div>
            ))}
          </div>
        </Panel>
      </div>
    </AppShell>
  );
}

import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge } from "../../components/ui";
import { AGENTS } from "../../lib/platform";
import { AgentRun } from "../../components/agent-run";

export const dynamic = "force-dynamic";
export const metadata = { title: "Agenten — Cloud Superbrain" };

// Multi-agent research through the Agent API and LLM Gateway boundaries.
export default function AgentsPage() {
  return (
    <AppShell crumb="Agenten" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Agenten"
          title="Tiefenrecherche mit mehreren Agenten"
          subtitle="Gib ein Ziel ein. Bei erreichbarer Agent API arbeiten Planner, Researcher und Writer zusammen; ohne Laufzeit bleibt der Auftrag fail-closed."
        />

        <Panel title="Tiefenrecherche starten" className="mb-16" actions={<Badge tone="cyan">Agent API · gated</Badge>}>
          <div className="wb-pad">
            <AgentRun />
          </div>
        </Panel>

        <Panel title="Das Agenten-Team (Zielarchitektur)" actions={<Badge tone="cyan">{AGENTS.length} Rollen · Plan</Badge>}>
          <div className="grid cols-2">
            {AGENTS.map((a) => (
              <div key={a.type} className="agent-team-card">
                <div className="agent-head">
                  <span className="agent-type">{a.type}</span>
                  <span className="agent-model mono text-12 text-mut" title="Ziel-Modell laut Orchestrator-Plan — nicht der aktuell aktive Provider">Ziel: {a.model}</span>
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

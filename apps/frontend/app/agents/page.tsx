import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge, Note, StatusDot } from "../../components/ui";
import { AGENTS } from "../../lib/platform";
import { fetchLiveAgents } from "../../lib/agentApi";

export const dynamic = "force-dynamic";
export const metadata = { title: "Agent Control Center — Cloud Superbrain" };

export default async function AgentsPage() {
  const roster = await fetchLiveAgents();
  const live = !!roster;
  return (
    <AppShell crumb="Agents" runState="planning">
      <div className="page-wide">
        <PageHeader
          eyebrow="Agent Control Center"
          title={`${AGENTS.length} deterministic agent profiles`}
          subtitle="Real role pool from the backend contract agent-profiles-v1. Each profile pins its model, fallbacks, allowed MCP tools, execution limits and human-review actions. The live roster below projects from GET /api/v1/live-agents/status when the runtime is reachable."
          actions={live ? <Badge tone="green">● Live · {roster!.agents.length} agents</Badge> : <Badge tone="cyan">agent-profiles-v1</Badge>}
        />

        {live ? (
          <Panel title={`Live agent roster (runtime)`} actions={<Badge tone="green">● {roster!.runtimeSource ?? "live-agent-steering-v1"}</Badge>} style={{ marginBottom: 16 }}>
            <div className="roster">
              {roster!.agents.map((a) => (
                <div key={a.id} className="roster-row">
                  <StatusDot tone={a.hasSession ? "green" : "mut"} pulse={a.hasSession} />
                  <span className="roster-name">{a.name}</span>
                  <Badge tone="violet">{a.role}</Badge>
                  <span className="roster-model mono">{a.model ?? roster!.defaultModel ?? "default"}</span>
                  <span className="roster-sess">{a.hasSession ? "session" : "idle"}</span>
                </div>
              ))}
            </div>
          </Panel>
        ) : null}
        <div className="grid cols-2">
          {AGENTS.map((a) => (
            <Panel key={a.type} pad>
              <div className="agent-head">
                <span className="agent-type">{a.type}</span>
                <Badge tone="mut">{a.maxExecSec}s · {a.maxOutTokens} tok · ≤{a.maxRetries} retries</Badge>
              </div>
              <p className="agent-role">{a.role}</p>

              <p className="inspect-label">Model · fallbacks</p>
              <p className="agent-model mono">{a.model}</p>
              <p className="agent-fallbacks">↳ {a.fallbacks.join(" · ")}</p>

              <p className="inspect-label">Allowed MCP tools</p>
              <div className="chip-wrap">
                {a.tools.map((t) => (
                  <span key={t} className="tool-chip mono">{t}</span>
                ))}
              </div>

              <p className="inspect-label">Human-review required</p>
              <div className="chip-wrap">
                {a.humanReview.map((h) => (
                  <span key={h} className="review-chip mono">{h}</span>
                ))}
              </div>
            </Panel>
          ))}
        </div>

        <Note>
          Profiles are deterministic runtime contracts — they do not imply live provider credentials
          are configured, and production-deploy actions stay human-review gated. All four agents run
          on Layer 3 (Agent Pool · Hetzner); global max-retry is 5.
        </Note>
      </div>
    </AppShell>
  );
}

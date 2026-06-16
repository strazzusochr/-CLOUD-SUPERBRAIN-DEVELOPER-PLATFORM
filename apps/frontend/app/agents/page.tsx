import AppShell from "../../components/shell/AppShell";
import { LiveConsole } from "../../components/live-console";
import { PageHeader, Panel, Badge, Note, StatusDot } from "../../components/ui";
import { AGENTS } from "../../lib/platform";
import { fetchLiveAgents } from "../../lib/agentApi";
import { AgentSteeringPanel } from "../../components/goal-b-actions";
import { AgentRun } from "../../components/agent-run";

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
          title={`${AGENTS.length} local agent profiles`}
          subtitle="Real role pool from the backend contract agent-profiles-v1. Each profile pins its model, fallbacks, allowed MCP tools, execution limits and human-review actions. The live roster below projects from GET /api/v1/live-agents/status and now exposes the latest local result path/command when a role was actually run."
          actions={live ? <Badge tone="green">● Live · {roster!.agents.length} agents</Badge> : <Badge tone="cyan">agent-profiles-v1</Badge>}
        />

        <Panel title="Multi-Agent Deep-Research · live LLM" className="mb-16" actions={<Badge tone="green">echt · CF Workers AI</Badge>}>
          <div className="wb-pad">
            <AgentRun />
          </div>
        </Panel>

        <Panel title="Live agent API" className="mb-16" actions={<Badge tone="cyan">interaktiv · read-only</Badge>}>
          <div className="wb-pad">
            <LiveConsole
              label="Agents"
              endpoints={[
                { label: "Health", path: "/api/v1/health" },
                { label: "Agents status", path: "/api/v1/agents/status" },
                { label: "Live agents status", path: "/api/v1/live-agents/status" },
                { label: "Recent tasks", path: "/api/v1/tasks/recent" },
              ]}
            />
          </div>
        </Panel>

        {live ? (
          <Panel title={`Live agent roster (runtime)`} actions={<Badge tone="green">● {roster!.runtimeSource ?? "live-agent-steering-v1"}</Badge>} className="mb-16">
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
        <Panel title="Goal B live-agent steering (local real run)" actions={<Badge tone="green">local_model_calls=true</Badge>} className="mb-16">
          <div className="wb-pad">
            <AgentSteeringPanel agents={(roster?.agents ?? []).map((a) => ({ id: a.id, name: a.name, role: a.role }))} />
          </div>
        </Panel>
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
          Profiles are runtime contracts backed by the local LLM path. External providers remain closed,
          production-deploy actions stay human-review gated, and all four agents run on Layer 3
          (Agent Pool). DEV-ONLY; hosted proof still blocked.
        </Note>
      </div>
    </AppShell>
  );
}

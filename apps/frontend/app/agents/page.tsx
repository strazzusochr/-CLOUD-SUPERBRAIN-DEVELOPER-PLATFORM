import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge, StatusDot, Bar } from "../../components/ui";

export const metadata = { title: "Agent Control Center — Cloud Superbrain" };

type Tone = "cyan" | "green" | "amber" | "red" | "mut";
const AGENTS: { name: string; role: string; state: string; tone: Tone; health: number; task: string }[] = [
  { name: "Supervisor", role: "Gate control", state: "active", tone: "green", health: 98, task: "Guarding write gates" },
  { name: "Architect", role: "Plan + design", state: "planning", tone: "cyan", health: 87, task: "Combat system design" },
  { name: "Coder", role: "Build + edit", state: "idle", tone: "mut", health: 100, task: "—" },
  { name: "Reviewer", role: "Review + diff", state: "idle", tone: "mut", health: 96, task: "—" },
  { name: "Tester", role: "Verifier", state: "verifying", tone: "amber", health: 71, task: "test_health_ratio.py" },
  { name: "Security", role: "Risk + secrets", state: "active", tone: "green", health: 99, task: "Secret scan" },
  { name: "DevOps", role: "CLI / cloud", state: "blocked", tone: "red", health: 60, task: "Provider write closed" },
  { name: "Monitor", role: "Telemetry", state: "active", tone: "cyan", health: 92, task: "Trace ingest" },
  { name: "Watchdog", role: "Health + retries", state: "active", tone: "green", health: 95, task: "Heartbeat" },
];

export default function AgentsPage() {
  return (
    <AppShell crumb="Agents" runState="planning">
      <div className="page-wide">
        <PageHeader
          eyebrow="Agent Control Center"
          title="Agent roster"
          subtitle="State, task, health and skills per agent. Collect, watchdog and handoff visibility — not a decorative grid."
          actions={<Badge tone="green"><StatusDot tone="green" /> 6 active</Badge>}
        />
        <div className="grid cols-3">
          {AGENTS.map((a) => (
            <Panel key={a.name} pad>
              <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 8 }}>
                <StatusDot tone={a.tone} pulse={a.tone !== "mut"} />
                <strong style={{ fontSize: 14 }}>{a.name}</strong>
                <Badge tone={a.tone === "mut" ? "mut" : a.tone}>{a.state}</Badge>
              </div>
              <p style={{ fontSize: 12.5, color: "var(--text-mut)" }}>{a.role}</p>
              <p style={{ fontSize: 12, color: "var(--text-dim)", margin: "8px 0" }}>{a.task}</p>
              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <Bar pct={a.health} />
                <span style={{ fontSize: 11, color: "var(--text-mut)", minWidth: 34, textAlign: "right" }}>{a.health}%</span>
              </div>
            </Panel>
          ))}
        </div>
      </div>
    </AppShell>
  );
}

import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge } from "../../components/ui";
import { SettingsGatePlanPanel } from "../../components/goal-b-actions";

export const metadata = { title: "Settings / Governance — Cloud Superbrain" };

const GATES = [
  "Production deploy",
  "Release promotion",
  "Provider writes",
  "Main push",
  "Registry push",
  "Live MCP write",
  "Live LLM call",
  "Secret output",
];

const ROLES = [
  { role: "Admin", scope: "Full governance" },
  { role: "Architect", scope: "Plan + design" },
  { role: "Developer", scope: "Build + run" },
  { role: "Viewer", scope: "Read-only" },
];

export default function SettingsPage() {
  return (
    <AppShell crumb="Settings" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Settings / Governance"
          title="Profile, gates & policies"
          subtitle="Local API, providers, accessibility and the security gate matrix. All dangerous gates are closed by default."
        />
        <div className="grid grid-settings">
          <Panel title="Settings">
            <div className="list">
              {["General", "Security", "Local API", "Providers", "Accessibility", "Team policies"].map((s) => (
                <div key={s} className="lrow text-13">{s}</div>
              ))}
            </div>
          </Panel>

          <Panel title="Security gates">
            <table className="tbl">
              <thead><tr><th>Gate</th><th>State</th></tr></thead>
              <tbody>
                {GATES.map((g) => (
                  <tr key={g}>
                    <td>{g}</td>
                    <td><Badge tone="red">closed · false</Badge></td>
                  </tr>
                ))}
              </tbody>
            </table>
            <div className="wb-pad">
              <SettingsGatePlanPanel />
            </div>
          </Panel>

          <Panel title="Role management">
            <div className="list">
              {ROLES.map((r) => (
                <div key={r.role} className="lrow">
                  <span className="lrow-title">{r.role}</span>
                  <span className="meta">{r.scope}</span>
                </div>
              ))}
            </div>
            <div className="wb-pad">
              <p className="text-12 text-dim">
                Tokens live under <span className="mono">.codex/secrets</span> — status only, never
                shown.
              </p>
            </div>
          </Panel>
        </div>
      </div>
    </AppShell>
  );
}

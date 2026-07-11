import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge } from "../../components/ui";
import { SettingsGatePlanPanel } from "../../components/goal-b-actions";

export const metadata = { title: "Einstellungen / Governance — Cloud Superbrain" };

const GATES = [
  "Produktionsbereitstellung",
  "Release-Freigabe",
  "Provider-Schreibzugriffe",
  "Push auf Main",
  "Push in die Registry",
  "Live-MCP-Schreibzugriff",
  "Live-LLM-Aufruf",
  "Ausgabe von Secrets",
];

const ROLES = [
  { role: "Administration", scope: "Vollständige Governance" },
  { role: "Architektur", scope: "Planung und Design" },
  { role: "Entwicklung", scope: "Bauen und ausführen" },
  { role: "Betrachtung", scope: "Nur lesend" },
];

export default function SettingsPage() {
  return (
    <AppShell crumb="Einstellungen" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Einstellungen / Governance"
          title="Profile, Gates und Richtlinien"
          subtitle="Lokale API, Provider, Barrierefreiheit und Sicherheits-Gate-Matrix. Alle gefährlichen Gates sind standardmäßig geschlossen."
        />
        <div className="grid grid-settings">
          <Panel title="Einstellungen">
            <div className="list">
              {["Allgemein", "Sicherheit", "Lokale API", "Provider", "Barrierefreiheit", "Teamrichtlinien"].map((s) => (
                <div key={s} className="lrow text-13">{s}</div>
              ))}
            </div>
          </Panel>

          <Panel title="Sicherheits-Gates">
            <table className="tbl">
              <thead><tr><th>Gate</th><th>Status</th></tr></thead>
              <tbody>
                {GATES.map((g) => (
                  <tr key={g}>
                    <td>{g}</td>
                    <td><Badge tone="red">geschlossen · false</Badge></td>
                  </tr>
                ))}
              </tbody>
            </table>
            <div className="wb-pad">
              <SettingsGatePlanPanel />
            </div>
          </Panel>

          <Panel title="Rollenverwaltung">
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
                Tokens liegen unter <span className="mono">.codex/secrets</span> — es wird nur ihr Status angezeigt, niemals ihr Wert.
              </p>
            </div>
          </Panel>
        </div>
      </div>
    </AppShell>
  );
}

import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge } from "../../components/ui";
import { MCP_TOOLS } from "../../lib/platform";
import { PROVIDERS, LAYERS } from "../../components/organism/regionMap";

export const metadata = { title: "MCP / Tools / Cloud Hub — Cloud Superbrain" };

const SCOPE_TONE = { read: "green", scoped_write: "amber", gated: "violet" } as const;
const SCOPE_LABEL = { read: "read-only", scoped_write: "scoped write", gated: "gated" } as const;

export default function ToolsPage() {
  return (
    <AppShell crumb="Tools" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="MCP / Tools / Cloud Hub"
          title="MCP tools & cloud providers"
          subtitle="The real MCP tools the agent profiles are allowed to use, and the cloud providers behind the 7 layers. Write scopes stay gated; provider status projects from GET /api/v1/clouds — tokens never printed."
          actions={<Link href="/marketplace" className="btn btn-sm btn-ghost">More in Marketplace →</Link>}
        />

        <Panel title="MCP tools (agent allowed_tools)" style={{ marginBottom: 16 }}>
          <table className="tbl">
            <thead>
              <tr><th>Tool</th><th>Layer</th><th>Scope</th></tr>
            </thead>
            <tbody>
              {MCP_TOOLS.map((m) => {
                const layer = LAYERS[m.layer - 1];
                return (
                  <tr key={m.id}>
                    <td className="mono">{m.id}</td>
                    <td>
                      <span className="layer-tag" style={{ background: layer.color, padding: "2px 7px", fontSize: 10.5 }}>L{m.layer}</span>{" "}
                      <span style={{ fontSize: 12, color: "var(--text-mut)" }}>{layer.label}</span>
                    </td>
                    <td><Badge tone={SCOPE_TONE[m.scope]}>{SCOPE_LABEL[m.scope]}</Badge></td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </Panel>

        <Panel title={`Cloud providers (${PROVIDERS.length})`}>
          <div className="wb-pad">
            <div className="card-grid">
              {PROVIDERS.map((p) => (
                <div key={p.id} className="panel panel-pad" style={{ display: "flex", flexDirection: "column", gap: 7 }}>
                  <div style={{ display: "flex", alignItems: "center", gap: 7 }}>
                    <span className="prov-dot" style={{ background: p.color }} />
                    <strong style={{ fontSize: 13.5 }}>{p.label}</strong>
                  </div>
                  <span style={{ fontSize: 11.5, color: "var(--text-mut)", minHeight: 30 }}>{p.role}</span>
                  <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
                    <Badge tone={p.optional ? "violet" : "green"}>{p.optional ? "optional" : "core"}</Badge>
                    <span className="mono" style={{ fontSize: 10.5, color: "var(--text-dim)" }}>{p.api}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </Panel>
      </div>
    </AppShell>
  );
}

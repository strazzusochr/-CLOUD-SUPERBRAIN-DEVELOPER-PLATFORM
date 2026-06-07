import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge, StatusDot } from "../../components/ui";
import { MCP_TOOLS } from "../../lib/platform";
import { PROVIDERS, LAYERS } from "../../components/organism/regionMap";
import { fetchProviders } from "../../lib/agentApi";

export const dynamic = "force-dynamic";
export const metadata = { title: "Tools / Cloud-Hub — Cloud Superbrain" };

const SCOPE_TONE = { read: "green", scoped_write: "amber", gated: "violet" } as const;
const SCOPE_LABEL = { read: "nur lesen", scoped_write: "scoped write", gated: "gated" } as const;

type Tone = "green" | "amber" | "violet";
function statusTone(s: string): Tone {
  if (/live_verified|^verified|integration/.test(s)) return "green";
  if (/partial|configured/.test(s)) return "amber";
  return "violet";
}

export default async function ToolsPage() {
  const readiness = await fetchProviders();
  const live = !!readiness;
  const stagingEnabled = process.env.STAGING_REWRITES_ENABLED === "true";
  const hasStagingBase = !!process.env.STAGING_BASE_URL;
  const hasAgentApi = !!process.env.AGENT_API_BASE_URL;
  const hasMcp = !!process.env.MCP_GATEWAY_BASE_URL;
  const hasLlm = !!process.env.LLM_GATEWAY_BASE_URL;
  return (
    <AppShell crumb="Tools" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Tools / Cloud-Hub"
          title="MCP-Tools & Cloud-Provider"
          subtitle="Nur Verdrahtung (read-only): echte MCP-Tools und Provider hinter den 7 Layern. Write-Scopes bleiben gated; Provider-Status kommt aus GET /api/v1/clouds — Token-Werte werden nie angezeigt."
          actions={
            <>
              {live ? <Badge tone="green">● Live · {readiness!.liveCount}/{readiness!.total} verifiziert</Badge> : null}
              <Link href="/marketplace" className="btn btn-sm btn-ghost">Mehr im Marktplatz →</Link>
            </>
          }
        />

        <Panel
          title="Cloud-Verdrahtung (Frontend → Runtime)"
          style={{ marginBottom: 16 }}
          actions={<Badge tone={stagingEnabled ? "green" : "amber"}>{stagingEnabled ? "aktiv" : "inaktiv"}</Badge>}
        >
          <div className="wb-pad">
            <div className="readiness">
              <div className="rd-row">
                <StatusDot tone={stagingEnabled ? "green" : "amber"} pulse={stagingEnabled} />
                <span className="rd-name">Rewrites aktiv</span>
                <span className="rd-layers mono">STAGING_REWRITES_ENABLED</span>
                <Badge tone={stagingEnabled ? "green" : "amber"}>{stagingEnabled ? "true" : "false"}</Badge>
              </div>
              <div className="rd-row">
                <StatusDot tone={hasStagingBase ? "green" : "violet"} pulse={hasStagingBase} />
                <span className="rd-name">Staging Base</span>
                <span className="rd-layers mono">STAGING_BASE_URL</span>
                <Badge tone={hasStagingBase ? "green" : "violet"}>{hasStagingBase ? "gesetzt" : "fehlt"}</Badge>
              </div>
              <div className="rd-row">
                <StatusDot tone={hasAgentApi ? "green" : "violet"} pulse={hasAgentApi} />
                <span className="rd-name">Agent API</span>
                <span className="rd-layers mono">AGENT_API_BASE_URL</span>
                <Badge tone={hasAgentApi ? "green" : "violet"}>{hasAgentApi ? "gesetzt" : "fehlt"}</Badge>
              </div>
              <div className="rd-row">
                <StatusDot tone={hasMcp ? "green" : "violet"} pulse={hasMcp} />
                <span className="rd-name">MCP Gateway</span>
                <span className="rd-layers mono">MCP_GATEWAY_BASE_URL</span>
                <Badge tone={hasMcp ? "green" : "violet"}>{hasMcp ? "gesetzt" : "fehlt"}</Badge>
              </div>
              <div className="rd-row">
                <StatusDot tone={hasLlm ? "green" : "violet"} pulse={hasLlm} />
                <span className="rd-name">LLM Gateway</span>
                <span className="rd-layers mono">LLM_GATEWAY_BASE_URL</span>
                <Badge tone={hasLlm ? "green" : "violet"}>{hasLlm ? "gesetzt" : "fehlt"}</Badge>
              </div>
            </div>
            <p style={{ fontSize: 12, color: "var(--text-dim)", marginTop: 10 }}>
              Hinweis: Das sind reine Verdrahtungs-Flags/URLs (Status only). Gefährliche Write/Deploy-Gates bleiben separat geschlossen.
            </p>
          </div>
        </Panel>

        {live ? (
          <Panel title="Live Cloud-Readiness (GET /api/v1/clouds)" style={{ marginBottom: 16 }} actions={<Badge tone="cyan">read-only · keine Token-Werte</Badge>}>
            <div className="readiness">
              {readiness!.providers.map((p) => (
                <div key={p.id} className="rd-row">
                  <StatusDot tone={statusTone(p.status)} pulse={p.liveVerified} />
                  <span className="rd-name">{p.label}</span>
                  <span className="rd-layers mono">{p.layers.map((l) => l.replace("layer_", "L")).join(" ")}</span>
                  <Badge tone={statusTone(p.status)}>{p.status.replace(/_/g, " ")}</Badge>
                </div>
              ))}
            </div>
          </Panel>
        ) : null}

        <Panel title="MCP-Tools (agent allowed_tools)" style={{ marginBottom: 16 }}>
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

        <Panel title={`Cloud-Provider (${PROVIDERS.length})`}>
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
                    <Badge tone={p.optional ? "violet" : "green"}>{p.optional ? "optional" : "kern"}</Badge>
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

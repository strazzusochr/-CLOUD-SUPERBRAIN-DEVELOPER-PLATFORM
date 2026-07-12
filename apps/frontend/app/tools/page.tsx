import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge, StatusDot } from "../../components/ui";
import { MCP_TOOLS } from "../../lib/platform";
import { PROVIDERS, LAYERS } from "../../components/organism/regionMap";
import { fetchProviders } from "../../lib/agentApi";
import { ToolsReadOnlyPanel } from "../../components/goal-b-actions";

export const dynamic = "force-dynamic";
export const metadata = { title: "Werkzeuge / Cloud-Zentrum — Cloud Superbrain" };

const SCOPE_TONE = { read: "green", scoped_write: "amber", gated: "violet" } as const;
const SCOPE_LABEL = { read: "nur lesen", scoped_write: "begrenztes Schreiben", gated: "durch Gate geschützt" } as const;

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
    <AppShell crumb="Werkzeuge" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Werkzeuge / Cloud-Zentrum"
          title="MCP-Werkzeuge und Cloud-Provider"
          subtitle="Nur lesende Verdrahtung: echte MCP-Werkzeuge und Provider hinter den sieben Schichten. Schreibbereiche bleiben durch Gates geschützt; der Provider-Status kommt aus GET /api/v1/clouds — Token-Werte werden nie angezeigt."
          actions={
            <>
              {live ? <Badge tone="green">● Live · {readiness!.liveCount}/{readiness!.total} verifiziert</Badge> : null}
              <Link href="/marketplace" className="btn btn-sm btn-ghost">Mehr im Marktplatz →</Link>
            </>
          }
        />

        <Panel
          title="Cloud-Verdrahtung (Frontend → Laufzeit)"
          className="mb-16"
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
                <span className="rd-name">Staging-Basis</span>
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
                <span className="rd-name">MCP-Gateway</span>
                <span className="rd-layers mono">MCP_GATEWAY_BASE_URL</span>
                <Badge tone={hasMcp ? "green" : "violet"}>{hasMcp ? "gesetzt" : "fehlt"}</Badge>
              </div>
              <div className="rd-row">
                <StatusDot tone={hasLlm ? "green" : "violet"} pulse={hasLlm} />
                <span className="rd-name">LLM-Gateway</span>
                <span className="rd-layers mono">LLM_GATEWAY_BASE_URL</span>
                <Badge tone={hasLlm ? "green" : "violet"}>{hasLlm ? "gesetzt" : "fehlt"}</Badge>
              </div>
            </div>
            <p className="text-12 text-dim mt-10">
              Hinweis: Das sind reine Verdrahtungs-Flags und URLs; angezeigt wird nur der Status. Gefährliche Schreib- und Bereitstellungs-Gates bleiben getrennt geschlossen.
            </p>
          </div>
        </Panel>

        {live ? (
          <Panel title="Live-Cloud-Bereitschaft (GET /api/v1/clouds)" className="mb-16" actions={<Badge tone="cyan">nur lesend · keine Token-Werte</Badge>}>
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

        <Panel title="Werkzeuge sicher ausführen (nur lesend)" className="mb-16" actions={<Badge tone="green">memory_read / task_router</Badge>}>
          <div className="wb-pad">
            <ToolsReadOnlyPanel />
          </div>
        </Panel>

        <Panel title="MCP-Werkzeuge (erlaubte Agentenwerkzeuge)" className="mb-16">
          <div className="table-scroll">
            <table className="tbl">
              <thead>
                <tr><th>Werkzeug</th><th>Schicht</th><th>Bereich</th></tr>
              </thead>
              <tbody>
                {MCP_TOOLS.map((m) => {
                  const layer = LAYERS[m.layer - 1];
                  return (
                    <tr key={m.id}>
                      <td className="mono">{m.id}</td>
                      <td>
                        <span className={`layer-tag layer-tag-${m.layer}`}>L{m.layer}</span>{" "}
                        <span className="layer-sub">{layer.label}</span>
                      </td>
                      <td><Badge tone={SCOPE_TONE[m.scope]}>{SCOPE_LABEL[m.scope]}</Badge></td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </Panel>

        <Panel title={`Cloud-Provider (${PROVIDERS.length})`}>
          <div className="wb-pad">
            <div className="card-grid">
              {PROVIDERS.map((p) => (
                <div key={p.id} className="prov-card">
                  <div className="prov-head">
                    <span className={`prov-dot prov-${p.id}`} />
                    <h3>{p.label}</h3>
                    <Badge tone={p.optional ? "violet" : "green"}>{p.optional ? "optional" : "kern"}</Badge>
                  </div>
                  <div className="prov-role">{p.role}</div>
                  <div className="prov-layers">
                    {p.layers.map((l) => (
                      <span key={l} className={`prov-layer layer-tag-${l}`}>L{l}</span>
                    ))}
                  </div>
                  <div className="mono prov-api">{p.api}</div>
                </div>
              ))}
            </div>
          </div>
        </Panel>
      </div>
    </AppShell>
  );
}

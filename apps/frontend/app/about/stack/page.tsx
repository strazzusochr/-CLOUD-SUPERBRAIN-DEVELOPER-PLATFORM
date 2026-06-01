import AppShell from "../../../components/shell/AppShell";
import { PageHeader, Panel, Badge, Note } from "../../../components/ui";
import { LAYERS, PROVIDERS, providersForLayer } from "../../../components/organism/regionMap";

export const metadata = { title: "Cloud Architecture — 7 Layers × 8 Providers — Cloud Superbrain" };

const RUNTIME: { group: string; items: string[] }[] = [
  { group: "Frontend", items: ["Next.js 15 · App Router", "React 19", "Canvas Cortex (+ R3F/WebGPU path)"] },
  { group: "Orchestration", items: ["LangGraph", "PostgreSQL checkpointer", "Agent role pool"] },
  { group: "AI / Gateway", items: ["LiteLLM", "Cloudflare AI Gateway", "Langfuse traces"] },
  { group: "Data / Memory", items: ["PostgreSQL", "pgvector", "Redis"] },
  { group: "Delivery / Gates", items: ["Docker", "GHCR images", "GitHub Actions", "OPA / gitleaks"] },
];

export default function StackPage() {
  return (
    <AppShell crumb="Cloud Architecture" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Architecture"
          title={`7 Layers × ${PROVIDERS.length} Cloud Providers`}
          subtitle="The seven architecture layers and the real cloud providers that back each one. The mapping mirrors the backend cloud inventory (GET /api/v1/clouds); every provider read is read-only and token-gated, and tokens under .codex/secrets are surfaced as status only — never printed."
        />

        <Panel title="Seven-layer cloud stack">
          <div className="stack-list">
            {LAYERS.map((l) => (
              <div key={l.code} className="layer-row layer-row-flat">
                <span className="layer-tag" style={{ background: l.color }}>L{l.no}</span>
                <span className="layer-name">
                  {l.label}{" "}
                  <span className="mono" style={{ color: "var(--text-dim)" }}>· {l.code}</span>
                </span>
                <span className="layer-providers">
                  {providersForLayer(l.no).map((p) => (
                    <span
                      key={p.id}
                      className="layer-chip"
                      style={{ color: p.color, borderColor: p.color }}
                      title={p.role}
                    >
                      {p.label}
                    </span>
                  ))}
                </span>
              </div>
            ))}
          </div>
        </Panel>

        <div className="page-head" style={{ margin: "22px 0 12px" }}>
          <div>
            <div className="eyebrow">Cloud provider inventory</div>
            <h2 style={{ fontSize: 17 }}>{PROVIDERS.length} non-secret provider surfaces</h2>
          </div>
          <Badge tone="cyan">read-only · token-gated</Badge>
        </div>
        <div className="grid cols-4">
          {PROVIDERS.map((p) => (
            <div key={p.id} className="prov-card">
              <div className="prov-head">
                <span className="prov-dot" style={{ background: p.color }} />
                <h3>{p.label}</h3>
                <Badge tone={p.optional ? "violet" : "green"}>{p.optional ? "optional" : "core"}</Badge>
              </div>
              <p className="prov-role">{p.role}</p>
              <div className="prov-layers">
                {p.layers.map((n) => (
                  <span key={n} className="prov-layer" style={{ borderColor: LAYERS[n - 1].color, color: LAYERS[n - 1].color }}>
                    L{n}
                  </span>
                ))}
              </div>
              <p className="prov-api">
                <span className="mono">{p.api}</span>
              </p>
            </div>
          ))}
        </div>

        <Note>
          Live provider status (<span className="mono">live_verified</span> /{" "}
          <span className="mono">configured</span> / <span className="mono">action_required</span>) is
          projected by the backend cloud inventory at <span className="mono">GET /api/v1/clouds</span>.
          No token value is ever returned; production deploy, registry push and provider writes stay
          gate-closed.
        </Note>

        <div className="page-head" style={{ margin: "22px 0 12px" }}>
          <div>
            <div className="eyebrow">Runtime technologies</div>
            <h2 style={{ fontSize: 17 }}>What actually runs in this repo</h2>
          </div>
        </div>
        <div className="grid cols-3">
          {RUNTIME.map((g) => (
            <Panel key={g.group} title={g.group}>
              <div className="list">
                {g.items.map((name) => (
                  <div key={name} className="lrow">
                    <span style={{ fontSize: 13 }}>{name}</span>
                  </div>
                ))}
              </div>
            </Panel>
          ))}
        </div>
      </div>
    </AppShell>
  );
}

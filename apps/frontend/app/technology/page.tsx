import AppShell from "../../components/shell/AppShell";
import SevenLayerBar from "../../components/shell/SevenLayerBar";
import { PageHeader, Panel, Badge, Note } from "../../components/ui";
import { LAYERS, PROVIDERS, providersForLayer } from "../../components/organism/regionMap";

export const dynamic = "force-dynamic";
export const metadata = { title: "Technology — 7 Layers × 8 Providers — Cloud Superbrain" };

const RUNTIME: { group: string; items: string[] }[] = [
  { group: "Frontend", items: ["Next.js 15 · App Router", "React 19", "Canvas Cortex (R3F / three.js)"] },
  { group: "Orchestration", items: ["LangGraph", "PostgreSQL checkpointer", "Agent role pool"] },
  { group: "AI / Gateway", items: ["LLM gateway (dry-run default)", "Cloudflare AI Gateway", "Langfuse traces"] },
  { group: "Data / Memory", items: ["PostgreSQL", "pgvector", "Redis"] },
  { group: "Delivery / Gates", items: ["Docker", "GHCR images", "GitHub Actions", "OPA / gitleaks"] },
];

/** The real toolstack that backs the platform, grouped by capability. */
const TOOLSTACK: { group: string; items: string[] }[] = [
  { group: "3D / WebGL", items: ["three.js", "@react-three/fiber", "@react-three/drei", "postprocessing", "glTF / GLB", "Draco / meshopt"] },
  { group: "Frontend", items: ["Next.js App Router", "React 19", "TypeScript (strict)", "CSS design tokens", "GSAP / motion"] },
  { group: "Backend / API", items: ["FastAPI", "Uvicorn", "Pydantic v2", "LangGraph", "httpx"] },
  { group: "Data", items: ["PostgreSQL 16", "pgvector 0.8", "Redis 7", "langgraph-checkpoint-postgres"] },
  { group: "Observability", items: ["OpenTelemetry", "Prometheus", "Grafana", "Langfuse", "Sentry"] },
  { group: "Testing / Proof", items: ["Playwright", "WebGL render proof", "axe-core (a11y)", "Lighthouse"] },
  { group: "Security / Gates", items: ["OPA / Conftest", "gitleaks", "Trivy", "Secret scanning"] },
  { group: "Delivery", items: ["Docker / Compose", "GHCR", "GitHub Actions", "Vercel"] },
];

export default function TechnologyPage() {
  return (
    <AppShell crumb="Technology" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Architecture"
          title={`7 Layers × ${PROVIDERS.length} Cloud Providers`}
          subtitle="The seven architecture layers and the real cloud providers that back each one. The mapping mirrors the backend cloud inventory (GET /api/v1/clouds); every provider read is read-only and token-gated, and tokens under .codex/secrets are surfaced as status only — never printed."
          actions={<Badge tone="green">layers live_verified · local runtime</Badge>}
        />

        <SevenLayerBar />

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
                    <span key={p.id} className="layer-chip" style={{ color: p.color, borderColor: p.color }} title={p.role}>
                      {p.label}
                    </span>
                  ))}
                </span>
              </div>
            ))}
          </div>
        </Panel>

        <Note>
          Live provider status (<span className="mono">live_verified</span> /{" "}
          <span className="mono">configured</span> / <span className="mono">action_required</span>) is
          projected by the backend cloud inventory at <span className="mono">GET /api/v1/clouds/layers</span>.
          In the local docker-compose runtime all seven layers report{" "}
          <span className="mono">live_verified</span> (dry-run, no live provider call). No token value
          is ever returned; production deploy, registry push and provider writes stay gate-closed.
        </Note>

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

        <div className="page-head" style={{ margin: "22px 0 12px" }}>
          <div>
            <div className="eyebrow">Runtime technologies</div>
            <h2 style={{ fontSize: 17 }}>What actually runs in this repo</h2>
          </div>
        </div>
        <div className="grid cols-3" style={{ marginBottom: 22 }}>
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

        <div className="page-head" style={{ margin: "22px 0 12px" }}>
          <div>
            <div className="eyebrow">Toolstack</div>
            <h2 style={{ fontSize: 17 }}>Capabilities by category</h2>
          </div>
        </div>
        <div className="grid cols-4">
          {TOOLSTACK.map((cat) => (
            <Panel key={cat.group} title={cat.group}>
              <div className="chip-wrap" style={{ padding: "2px 4px 6px" }}>
                {cat.items.map((t) => (
                  <span key={t} className="tool-chip mono">{t}</span>
                ))}
              </div>
            </Panel>
          ))}
        </div>
      </div>
    </AppShell>
  );
}

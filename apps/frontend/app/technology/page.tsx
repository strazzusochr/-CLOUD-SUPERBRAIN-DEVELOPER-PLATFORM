import AppShell from "../../components/shell/AppShell";
import SevenLayerBar from "../../components/shell/SevenLayerBar";
import { PageHeader, Panel, Badge, Note } from "../../components/ui";
import { TechnologyProbe } from "../../components/batch5-actions";
import { LAYERS, PROVIDERS, providersForLayer } from "../../components/organism/regionMap";

export const dynamic = "force-dynamic";
export const metadata = { title: "Technology — 7 Layers × 8 Providers — Cloud Superbrain" };

const RUNTIME: { group: string; items: string[] }[] = [
  { group: "Frontend", items: ["Next.js 16 · App Router", "React 19", "Canvas Cortex (R3F / three.js)"] },
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
    <AppShell crumb="Technologie" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Architektur"
          title={`7 Layer × ${PROVIDERS.length} Cloud-Provider`}
          subtitle="Die sieben Architektur-Layer und die realen Provider dahinter. Mapping spiegelt das Backend-Inventar (GET /api/v1/clouds). Provider-Reads sind read-only; es werden nur Status-Metadaten angezeigt (keine Token-Werte)."
          actions={<Badge tone="amber">Layer action_required · read-only</Badge>}
        />

        <SevenLayerBar />
        <div style={{ marginTop: 16, marginBottom: 16 }}>
          <TechnologyProbe />
        </div>

        <Panel title="7-Layer Cloud-Stack">
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
          Cloud Provider-Status (<span className="mono">live_verified</span> /{" "}
          <span className="mono">configured</span> / <span className="mono">action_required</span>) kommt aus{" "}
          <span className="mono">GET /api/v1/clouds/layers</span>. Localhost ist nur DEV-ONLY:
          ohne Owner-Tokens und HTTPS-Staging melden die Layer <span className="mono">action_required</span>.
          Token-Werte werden nie zurückgegeben; Deploy/Registry/Provider-Writes bleiben gate-closed.
        </Note>

        <div className="page-head" style={{ margin: "22px 0 12px" }}>
          <div>
            <div className="eyebrow">Cloud-Provider Inventar</div>
            <h2 style={{ fontSize: 17 }}>{PROVIDERS.length} Provider-Surfaces (ohne Secrets)</h2>
          </div>
          <Badge tone="cyan">read-only · token-gated</Badge>
        </div>
        <div className="grid cols-4">
          {PROVIDERS.map((p) => (
            <div key={p.id} className="prov-card">
              <div className="prov-head">
                <span className="prov-dot" style={{ background: p.color }} />
                <h3>{p.label}</h3>
                <Badge tone={p.optional ? "violet" : "green"}>{p.optional ? "optional" : "kern"}</Badge>
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
            <div className="eyebrow">Runtime-Technologien</div>
            <h2 style={{ fontSize: 17 }}>Was hier wirklich läuft</h2>
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
            <h2 style={{ fontSize: 17 }}>Fähigkeiten nach Kategorie</h2>
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

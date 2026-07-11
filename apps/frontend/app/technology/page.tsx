import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge, Note } from "../../components/ui";
import { LAYERS, PROVIDERS, providersForLayer } from "../../components/organism/regionMap";

export const dynamic = "force-dynamic";
export const metadata = { title: "Technologie — 7 Schichten × 8 Provider — Cloud Superbrain" };

const RUNTIME: { group: string; items: string[] }[] = [
  { group: "Frontend", items: ["Next.js 16 · App Router", "React 19", "Canvas Cortex (R3F / three.js)"] },
  { group: "Orchestrierung", items: ["LangGraph", "PostgreSQL-Checkpointer", "Agenten-Rollenpool"] },
  { group: "KI / Gateway", items: ["LLM-Gateway (Dry-Run als Standard)", "Cloudflare AI Gateway", "Langfuse-Traces"] },
  { group: "Daten / Gedächtnis", items: ["PostgreSQL", "pgvector", "Redis"] },
  { group: "Bereitstellung / Gates", items: ["Docker", "GHCR-Images", "GitHub Actions", "OPA / gitleaks"] },
];

/** The real toolstack that backs the platform, grouped by capability. */
const TOOLSTACK: { group: string; items: string[] }[] = [
  { group: "3D / WebGL", items: ["three.js", "@react-three/fiber", "@react-three/drei", "postprocessing", "glTF / GLB", "Draco / meshopt"] },
  { group: "Frontend", items: ["Next.js App Router", "React 19", "TypeScript (strict)", "CSS design tokens", "GSAP / motion"] },
  { group: "Backend / API", items: ["FastAPI", "Uvicorn", "Pydantic v2", "LangGraph", "httpx"] },
  { group: "Daten", items: ["PostgreSQL 16", "pgvector 0.8", "Redis 7", "langgraph-checkpoint-postgres"] },
  { group: "Observability", items: ["OpenTelemetry", "Prometheus", "Grafana", "Langfuse", "Sentry"] },
  { group: "Tests / Nachweise", items: ["Playwright", "WebGL-Rendernachweis", "axe-core (Barrierefreiheit)", "Lighthouse"] },
  { group: "Sicherheit / Gates", items: ["OPA / Conftest", "gitleaks", "Trivy", "Secret-Prüfung"] },
  { group: "Bereitstellung", items: ["Docker / Compose", "GHCR", "GitHub Actions", "Vercel"] },
];

export default function TechnologyPage() {
  return (
    <AppShell crumb="Technologie" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Architektur"
          title={`7 Schichten × ${PROVIDERS.length} Cloud-Provider`}
          subtitle="Die sieben Architekturschichten und die realen Provider dahinter. Die Zuordnung spiegelt das Backend-Inventar (GET /api/v1/clouds). Provider-Lesezugriffe sind nur lesend; angezeigt werden ausschließlich Status-Metadaten ohne Token-Werte."
          actions={<Badge tone="amber">Schicht: Aktion erforderlich · nur lesend</Badge>}
        />
        <Panel title="7-Schichten-Cloud-Stack">
          <div className="stack-list">
            {LAYERS.map((l) => (
              <div key={l.code} className="layer-row layer-row-flat">
                <span className={`layer-tag layer-tag-${l.no}`}>L{l.no}</span>
                <span className="layer-name">
                  {l.label}{" "}
                  <span className="mono text-dim">· {l.code}</span>
                </span>
                <span className="layer-providers">
                  {providersForLayer(l.no).map((p) => (
                    <span key={p.id} className={`layer-chip chip-${p.id}`} title={p.role}>
                      {p.label}
                    </span>
                  ))}
                </span>
              </div>
            ))}
          </div>
        </Panel>

        <Note>
          Der Status der Cloud-Provider (<span className="mono">live_verified</span> /{" "}
          <span className="mono">configured</span> / <span className="mono">action_required</span>) kommt aus{" "}
          <span className="mono">GET /api/v1/clouds/layers</span>. Localhost ist nur DEV-ONLY:
          ohne Owner-Tokens und HTTPS-Staging melden die Schichten <span className="mono">action_required</span>.
          Token-Werte werden nie zurückgegeben; Bereitstellung, Registry und Provider-Schreibzugriffe bleiben durch Gates geschlossen.
        </Note>

        <div className="page-head section-head">
          <div>
            <div className="eyebrow">Cloud-Provider-Inventar</div>
            <h2 className="section-h2">{PROVIDERS.length} Provider-Oberflächen (ohne Secrets)</h2>
          </div>
          <Badge tone="cyan">nur lesend · Token-gesteuert</Badge>
        </div>
        <div className="grid cols-4">
          {PROVIDERS.map((p) => (
            <div key={p.id} className="prov-card">
              <div className="prov-head">
                <span className={`prov-dot prov-${p.id}`} />
                <h3>{p.label}</h3>
                <Badge tone={p.optional ? "violet" : "green"}>{p.optional ? "optional" : "kern"}</Badge>
              </div>
              <p className="prov-role">{p.role}</p>
              <div className="prov-layers">
                {p.layers.map((n) => (
                  <span key={n} className={`prov-layer layer-tag-${n}`}>
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

        <div className="page-head section-head">
          <div>
            <div className="eyebrow">Runtime-Technologien</div>
            <h2 className="section-h2">Was hier wirklich läuft</h2>
          </div>
        </div>
        <div className="grid cols-3 mb-22">
          {RUNTIME.map((g) => (
            <Panel key={g.group} title={g.group}>
              <div className="list">
                {g.items.map((name) => (
                  <div key={name} className="lrow">
                    <span className="text-13">{name}</span>
                  </div>
                ))}
              </div>
            </Panel>
          ))}
        </div>

        <div className="page-head section-head">
          <div>
            <div className="eyebrow">Toolstack</div>
            <h2 className="section-h2">Fähigkeiten nach Kategorie</h2>
          </div>
        </div>
        <div className="grid cols-4">
          {TOOLSTACK.map((cat) => (
            <Panel key={cat.group} title={cat.group}>
              <div className="chip-wrap chip-pad">
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

import AppShell from "../../components/shell/AppShell";
import { LiveConsole } from "../../components/live-console";
import { PageHeader, Panel, Badge, Note } from "../../components/ui";
import { Icon } from "../../lib/nav";

export const metadata = { title: "Open Source — Cloud Superbrain" };

const PRINCIPLES = [
  { icon: "shield" as const, title: "Self-Hostable", body: "Run on your own machine or cloud. Your workflow, your infrastructure — no lock-in." },
  { icon: "tools" as const, title: "Extensible", body: "Compose skills, tools, agents and integrations. Plug in anything via MCP." },
  { icon: "agents" as const, title: "Community Powered", body: "Built together, made for everyone. Transparent, auditable, evidence-first." },
];

/** Real open-source components the platform is built on, with their licenses. */
const OSS: { name: string; license: string; role: string }[] = [
  { name: "Next.js", license: "MIT", role: "App Router frontend framework" },
  { name: "React", license: "MIT", role: "UI runtime (v19)" },
  { name: "three.js", license: "MIT", role: "WebGL 3D engine for the cortex" },
  { name: "@react-three/fiber", license: "MIT", role: "React renderer for three.js" },
  { name: "@react-three/drei", license: "MIT", role: "R3F helpers (Environment, Html…)" },
  { name: "postprocessing", license: "MIT", role: "Bloom / vignette effect composer" },
  { name: "FastAPI", license: "MIT", role: "Python API framework" },
  { name: "LangGraph", license: "MIT", role: "Agent orchestration graph" },
  { name: "PostgreSQL", license: "PostgreSQL", role: "Primary datastore" },
  { name: "pgvector", license: "PostgreSQL", role: "Vector memory / embeddings" },
  { name: "Redis", license: "RSALv2 / SSPL", role: "Queues + working memory" },
  { name: "Playwright", license: "Apache-2.0", role: "E2E + WebGL render proof" },
  { name: "OpenPolicyAgent", license: "Apache-2.0", role: "Gate policies (can_write…)" },
  { name: "gitleaks", license: "MIT", role: "Secret scanning" },
];

export default function OpenSourcePage() {
  return (
    <AppShell crumb="Open Source" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Open by Design"
          title="Open Source First"
          subtitle="Cloud Superbrain is open-source, independent and free-first. Use it, fork it, self-host it, and own your workflow end to end."
          actions={<Badge tone="green">no vendor lock-in</Badge>}
        />


        <Panel title="Live-Daten" className="mb-16" actions={<Badge tone="cyan">interaktiv</Badge>}>
          <div className="wb-pad">
            <LiveConsole
              endpoints={[
                { label: "Workspace wiring", path: "/api/v1/workspace/wiring" },
                { label: "Platform inventory", path: "/api/v1/platform/inventory" },
              ]}
            />
          </div>
        </Panel>

        <div className="grid cols-3">
          {PRINCIPLES.map((p) => (
            <Panel key={p.title} pad>
              <div className="feature feature-plain">
                <div className="ico">{Icon[p.icon]({ size: 18 })}</div>
                <h3>{p.title}</h3>
                <p>{p.body}</p>
              </div>
            </Panel>
          ))}
        </div>

        <div className="page-head open-source-subhead">
          <div>
            <div className="eyebrow">Built on open source</div>
            <h2 className="open-source-h2">{OSS.length} core components &amp; their licenses</h2>
          </div>
          <Badge tone="cyan">licenses respected</Badge>
        </div>
        <Panel>
          <div className="oss-table">
            <div className="oss-row oss-head">
              <span>Component</span>
              <span>License</span>
              <span>Role</span>
            </div>
            {OSS.map((o) => (
              <div key={o.name} className="oss-row">
                <span className="mono oss-name">{o.name}</span>
                <span><Badge tone="violet">{o.license}</Badge></span>
                <span className="oss-role">{o.role}</span>
              </div>
            ))}
          </div>
        </Panel>

        <Note>
          Every dependency keeps its upstream license; this page lists them for transparency. No
          bundled component is relicensed. Provider tokens and secrets are never part of the
          open-source surface — they stay in <span className="mono">.codex/secrets</span> as status only.
        </Note>

        <div className="footer-slogan">
          <span>Build anything.</span>
          <span>Automate everything.</span>
          <span>Own your workflow.</span>
        </div>
      </div>
    </AppShell>
  );
}

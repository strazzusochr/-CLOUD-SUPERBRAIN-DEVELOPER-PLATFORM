import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge, Note } from "../../components/ui";
import { Icon } from "../../lib/nav";

export const metadata = { title: "Open Source — Cloud Superbrain" };

const PRINCIPLES = [
  { icon: "shield" as const, title: "Selbst hostbar", body: "Läuft auf deiner eigenen Maschine oder in deiner Cloud. Dein Arbeitsablauf, deine Infrastruktur — ohne Bindung." },
  { icon: "tools" as const, title: "Erweiterbar", body: "Stelle Skills, Werkzeuge, Agenten und Integrationen zusammen. Über MCP lässt sich alles anbinden." },
  { icon: "agents" as const, title: "Von der Gemeinschaft getragen", body: "Gemeinsam gebaut und für alle gemacht. Transparent, prüfbar und nachweisorientiert." },
];

/** Real open-source components the platform is built on, with their licenses. */
const OSS: { name: string; license: string; role: string }[] = [
  { name: "Next.js", license: "MIT", role: "Frontend-Framework mit App Router" },
  { name: "React", license: "MIT", role: "UI-Laufzeit (v19)" },
  { name: "three.js", license: "MIT", role: "WebGL-3D-Engine für den Cortex" },
  { name: "@react-three/fiber", license: "MIT", role: "React-Renderer für three.js" },
  { name: "@react-three/drei", license: "MIT", role: "R3F-Helfer (Environment, Html…)" },
  { name: "postprocessing", license: "MIT", role: "Komposition von Bloom- und Vignetteneffekten" },
  { name: "FastAPI", license: "MIT", role: "Python-API-Framework" },
  { name: "LangGraph", license: "MIT", role: "Orchestrierungsgraph für Agenten" },
  { name: "PostgreSQL", license: "PostgreSQL", role: "Primärer Datenspeicher" },
  { name: "pgvector", license: "PostgreSQL", role: "Vektorgedächtnis und Embeddings" },
  { name: "Redis", license: "RSALv2 / SSPL", role: "Warteschlangen und Arbeitsgedächtnis" },
  { name: "Playwright", license: "Apache-2.0", role: "E2E- und WebGL-Rendernachweis" },
  { name: "OpenPolicyAgent", license: "Apache-2.0", role: "Gate-Richtlinien (can_write…)" },
  { name: "gitleaks", license: "MIT", role: "Secret-Prüfung" },
];

export default function OpenSourcePage() {
  return (
    <AppShell crumb="Open Source" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Offen entwickelt"
          title="Open Source zuerst"
          subtitle="Cloud Superbrain ist Open Source, unabhängig und auf kostenlose Nutzung ausgerichtet. Nutze, forke und hoste es selbst — dein Arbeitsablauf gehört dir vollständig."
          actions={<Badge tone="green">keine Herstellerbindung</Badge>}
        />


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
            <div className="eyebrow">Auf Open Source aufgebaut</div>
            <h2 className="open-source-h2">{OSS.length} Kernkomponenten und ihre Lizenzen</h2>
          </div>
          <Badge tone="cyan">Lizenzen eingehalten</Badge>
        </div>
        <Panel>
          <div className="oss-table">
            <div className="oss-row oss-head">
              <span>Komponente</span>
              <span>Lizenz</span>
              <span>Rolle</span>
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
          Jede Abhängigkeit behält ihre ursprüngliche Lizenz; diese Seite listet sie transparent auf. Keine
          gebündelte Komponente wird neu lizenziert. Provider-Tokens und Secrets gehören nie zur
          Open-Source-Oberfläche — unter <span className="mono">.codex/secrets</span> wird nur ihr Status geführt.
        </Note>

        <div className="footer-slogan">
          <span>Baue alles.</span>
          <span>Automatisiere alles.</span>
          <span>Dein Arbeitsablauf gehört dir.</span>
        </div>
      </div>
    </AppShell>
  );
}

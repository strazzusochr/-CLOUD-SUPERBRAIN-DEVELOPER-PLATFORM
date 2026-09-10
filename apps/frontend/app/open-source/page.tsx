import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge, Note } from "../../components/ui";
import { Icon } from "../../lib/nav";

export const metadata = { title: "Open Source — Cloud Superbrain" };

const PRINCIPLES = [
  { icon: "shield" as const, title: "Technisch selbst hostbar", body: "Die Entwicklungs-Laufzeit kann auf eigener Infrastruktur betrieben werden. Hosted- und Produktionsfreigaben bleiben getrennt gegated." },
  { icon: "tools" as const, title: "Vertraglich erweiterbar", body: "Skills, Werkzeuge, Agenten und Integrationen besitzen begrenzte Verträge. Externe MCP-Wirkung bleibt scope- und owner-gegatet." },
  { icon: "agents" as const, title: "Prüfbar", body: "Quellcode, Verträge und lokale Nachweise sind einsehbar. Eine Projektlizenz und die rechtliche Freigabe stehen noch aus." },
];

/** Declared upstream licenses; this inventory is not a project-license grant. */
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
  { name: "gitleaks", license: "MIT", role: "Secret-Prüfung" },
];

export default function OpenSourcePage() {
  return (
    <AppShell crumb="Open Source" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Quellcode einsehbar"
          title="Projektlizenz noch offen"
          subtitle="Der Quellcode ist im Repository einsehbar, aber es liegt keine Root-LICENSE und damit noch keine ausdrückliche Projektlizenz vor. Nutzung, Fork und Weitergabe werden erst nach der Owner-Lizenzentscheidung als erlaubt behauptet."
          actions={<Badge tone="amber">OWNER-BLOCKED · Lizenzwahl</Badge>}
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
            <div className="eyebrow">Upstream-Inventar</div>
            <h2 className="open-source-h2">{OSS.length} Kernkomponenten und deklarierte Lizenzen</h2>
          </div>
          <Badge tone="amber">SBOM-/Lizenzprüfung offen</Badge>
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
          Die Tabelle ist eine handgepflegte Upstream-Inventur, kein automatischer SBOM- oder Compliance-Beweis.
          Ohne Root-<span className="mono">LICENSE</span> wird keine Projektlizenz behauptet. Provider-Tokens und
          Secrets gehören nie zu dieser Oberfläche; unter <span className="mono">.codex/secrets</span> wird nur ihr
          Status geführt.
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

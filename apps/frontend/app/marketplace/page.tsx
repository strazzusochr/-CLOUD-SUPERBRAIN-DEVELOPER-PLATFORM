import AppShell from "../../components/shell/AppShell";
import { PageHeader, Badge, StatusDot } from "../../components/ui";
import { SKILLS, MODELS, AGENTS, MCP_TOOLS } from "../../lib/platform";
import { fetchProviders } from "../../lib/agentApi";
import { MarketplaceActionPanel, MarketplaceCardGrid } from "../../components/goal-b-actions";

export const dynamic = "force-dynamic";
export const metadata = { title: "Marktplatz — Cloud Superbrain" };

type Kind = "Skill" | "Agent" | "MCP" | "Modell";

const SKILL_DESCRIPTIONS: Record<string, string> = {
  "strict-project-gate": "Pfad-Gate: Projektänderungen nur nach ausdrücklicher Freigabe.",
  "product-ux-guardian": "Start und Werkbank bleiben echte Produktflächen statt Audit-Ansichten.",
  "live-3d-organism-architect": "Cortex-Ansicht, Gehirnregionen und Synapsenflüsse.",
  "r3f-three-engineer": "R3F und three.js: Canvas, GLB-Lader, Instanzen und Bloom.",
  "blender-gltf-pipeline": "Blender → GLB → glTF Transform → gltfjsx.",
  "mcp-safety-auditor": "Prüft MCP-Server, Bereiche, Secrets und Schreibzugriffe.",
  "visual-verifier": "Playwright-Screenshots, visuelle Vergleiche und responsive Prüfungen.",
  "accessibility-reduced-motion": "Barrierefreiheit, weniger Bewegung, Tastatur und Kontrast.",
  "telemetry-binding-engineer": "Bindet OpenTelemetry an visuelle Cortex-Signale.",
  "opa-gate-engineer": "Lokale Richtlinien-Gates für Schreiben, Bereitstellen und Pushen.",
};

const AGENT_DESCRIPTIONS: Record<string, string> = {
  planner: "Zerlegt Aufgaben, klassifiziert Absichten und plant sichere Wege.",
  coder: "Implementiert Funktionen auf begrenzten Branches ohne direkten Main-Schreibzugriff.",
  tester: "Prüft deterministisch und nutzt Sandbox-Nachweise nur hinter Gates.",
  devops: "Verantwortet CI/CD, Docker und Bereitstellungsabläufe ohne direkten Produktionszugriff.",
};

const MODEL_DESCRIPTIONS: Record<string, string> = {
  "deepseek-ai/DeepSeek-V4-Pro": "Primärmodell für Planung.",
  "qwen3.7-plus": "Primärmodell für Code-Erstellung über das LLM Gateway und Alibaba Model Studio.",
  "google/gemma-4-26B-A4B-it": "Primärmodell für Tests.",
  "deepseek-ai/DeepSeek-V4-Flash": "Primärmodell für DevOps.",
};

const MCP_SCOPE_DESCRIPTIONS = {
  read: "nur lesend",
  scoped_write: "begrenztes Schreiben",
  gated: "durch Gate geschützt",
} as const;

const ITEMS: { name: string; kind: Kind; desc: string }[] = [
  ...SKILLS.map((s) => ({ name: s.id, kind: "Skill" as const, desc: SKILL_DESCRIPTIONS[s.id] ?? s.purpose })),
  ...AGENTS.map((a) => ({ name: a.type, kind: "Agent" as const, desc: AGENT_DESCRIPTIONS[a.type] ?? a.role })),
  ...MCP_TOOLS.map((t) => ({ name: t.id, kind: "MCP" as const, desc: `Schicht ${t.layer} · ${MCP_SCOPE_DESCRIPTIONS[t.scope]}` })),
  ...MODELS.map((m) => ({ name: m.id, kind: "Modell" as const, desc: MODEL_DESCRIPTIONS[m.id] ?? m.role })),
];

export default async function MarketplacePage() {
  const counts = { Skill: SKILLS.length, Agent: AGENTS.length, MCP: MCP_TOOLS.length, Modell: MODELS.length };
  const readiness = await fetchProviders();
  const live = !!readiness;
  return (
    <AppShell crumb="Marktplatz" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Marktplatz"
          title="Skills, Agenten, MCP-Tools und Modelle"
          subtitle="Die Bausteine, aus denen du die Plattform zusammenstellst: Skills, Agentenprofile, MCP-Tools und Modelle. Die Cloud-Provider unten decken die Verfügbarkeit von Modellen und MCP ab (L4/L5)."
          actions={live ? <Badge tone="green">● Live · {readiness!.liveCount}/{readiness!.total} Provider verifiziert</Badge> : <Badge tone="cyan">Katalog</Badge>}
        />

        {live ? (
          <div className="readiness mb-16">
            {readiness!.providers.map((p) => (
              <div key={p.id} className="rd-row">
                <StatusDot tone={/verified|live/.test(p.status) ? "green" : /partial|configured/.test(p.status) ? "amber" : "violet"} pulse={p.liveVerified} />
                <span className="rd-name">{p.label}</span>
                <span className="rd-layers mono">{p.layers.map((l) => l.replace("layer_", "L")).join(" ")}</span>
                <Badge tone={/verified|live/.test(p.status) ? "green" : "amber"}>{p.status.replace(/_/g, " ")}</Badge>
              </div>
            ))}
          </div>
        ) : null}
        <div className="chips mb-16">
          <span className="chip active">Alle ({ITEMS.length})</span>
          <span className="chip">Skills ({counts.Skill})</span>
          <span className="chip">Agenten ({counts.Agent})</span>
          <span className="chip">MCP ({counts.MCP})</span>
          <span className="chip">Modelle ({counts.Modell})</span>
        </div>
        <div className="mb-16">
          <MarketplaceActionPanel itemNames={ITEMS.map((it) => `${it.kind}:${it.name}`)} />
        </div>
        <MarketplaceCardGrid items={ITEMS} />
        <p className="login-foot mt-12">
          <Badge tone="cyan">Agent API</Badge> „Installieren“ registriert nur bei erreichbarer Laufzeit ein Artefakt; ohne Registry bleibt die Aktion fail-closed.
        </p>
      </div>
    </AppShell>
  );
}

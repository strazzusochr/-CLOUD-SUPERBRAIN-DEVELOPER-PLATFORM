import AppShell from "../../components/shell/AppShell";
import { PageHeader, Badge, StatusDot } from "../../components/ui";
import { SKILLS, MODELS, AGENTS, MCP_TOOLS } from "../../lib/platform";
import { fetchProviders } from "../../lib/agentApi";
import { MarketplaceActionPanel, MarketplaceCardGrid } from "../../components/goal-b-actions";

export const dynamic = "force-dynamic";
export const metadata = { title: "Marketplace — Cloud Superbrain" };

type Kind = "Skill" | "Agent" | "MCP" | "Model";

const ITEMS: { name: string; kind: Kind; desc: string }[] = [
  ...SKILLS.map((s) => ({ name: s.id, kind: "Skill" as const, desc: s.purpose })),
  ...AGENTS.map((a) => ({ name: a.type, kind: "Agent" as const, desc: a.role })),
  ...MCP_TOOLS.map((t) => ({ name: t.id, kind: "MCP" as const, desc: `Layer ${t.layer} · ${t.scope.replace("_", " ")}` })),
  ...MODELS.map((m) => ({ name: m.id, kind: "Model" as const, desc: m.role })),
];

export default async function MarketplacePage() {
  const counts = { Skill: SKILLS.length, Agent: AGENTS.length, MCP: MCP_TOOLS.length, Model: MODELS.length };
  const readiness = await fetchProviders();
  const live = !!readiness;
  return (
    <AppShell crumb="Marketplace" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Marketplace"
          title="Skills, agents, MCP tools & models"
          subtitle="Die Bausteine, aus denen die Plattform komponiert — Skills, Agent-Profile, MCP-Tools und Modelle. Modell-/MCP-Verfügbarkeit ist von den Cloud-Providern unten gedeckt (L4/L5)."
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
          <span className="chip active">All ({ITEMS.length})</span>
          <span className="chip">Skills ({counts.Skill})</span>
          <span className="chip">Agents ({counts.Agent})</span>
          <span className="chip">MCP ({counts.MCP})</span>
          <span className="chip">Models ({counts.Model})</span>
        </div>
        <div className="mb-16">
          <MarketplaceActionPanel itemNames={ITEMS.map((it) => `${it.kind}:${it.name}`)} />
        </div>
        <MarketplaceCardGrid items={ITEMS} />
        <p className="login-foot mt-12">
          <Badge tone="green">echt</Badge> „Installieren" legt ein echtes, persistiertes Artefakt an — keine externen Provider-Writes.
        </p>
      </div>
    </AppShell>
  );
}

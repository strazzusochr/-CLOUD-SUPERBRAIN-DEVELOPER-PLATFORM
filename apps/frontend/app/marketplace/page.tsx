import AppShell from "../../components/shell/AppShell";
import { PageHeader, Badge, StatusDot } from "../../components/ui";
import { SKILLS, MODELS, AGENTS, MCP_TOOLS } from "../../lib/platform";
import { fetchProviders } from "../../lib/agentApi";

export const dynamic = "force-dynamic";
export const metadata = { title: "Marketplace — Cloud Superbrain" };

type Kind = "Skill" | "Agent" | "MCP" | "Model";
const TONE: Record<Kind, "cyan" | "violet" | "amber" | "green"> = {
  Skill: "cyan",
  Agent: "violet",
  MCP: "amber",
  Model: "green",
};

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
          subtitle="The real building blocks this platform composes — deterministic skills, agent profiles, MCP tools and pinned models. Model & MCP availability is backed by the cloud providers below (L4/L5); install is a dry-run until the owner gate is opened."
          actions={live ? <Badge tone="green">● Live · {readiness!.liveCount}/{readiness!.total} providers verified</Badge> : <Badge tone="amber">dry-run · spec catalog</Badge>}
        />

        {live ? (
          <div className="readiness" style={{ marginBottom: 16 }}>
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
        <div className="chips" style={{ marginBottom: 16 }}>
          <span className="chip active">All ({ITEMS.length})</span>
          <span className="chip">Skills ({counts.Skill})</span>
          <span className="chip">Agents ({counts.Agent})</span>
          <span className="chip">MCP ({counts.MCP})</span>
          <span className="chip">Models ({counts.Model})</span>
        </div>
        <div className="card-grid">
          {ITEMS.map((it) => (
            <div key={`${it.kind}-${it.name}`} className="gcard">
              <div className="preview">
                <Badge tone={TONE[it.kind]}>{it.kind}</Badge>
              </div>
              <div className="body">
                <h3 className="mono" style={{ fontSize: 13.5 }}>{it.name}</h3>
                <div className="sub" style={{ minHeight: 32 }}>{it.desc}</div>
                <div className="actions">
                  <button className="btn btn-sm btn-primary">Install</button>
                  <button className="btn btn-sm btn-ghost">Details</button>
                </div>
              </div>
            </div>
          ))}
        </div>
        <p style={{ fontSize: 12, color: "var(--text-dim)", marginTop: 12 }}>
          <Badge tone="amber">dry-run</Badge> Installs are simulated until the owner gate is opened —
          no provider write, no registry pull.
        </p>
      </div>
    </AppShell>
  );
}

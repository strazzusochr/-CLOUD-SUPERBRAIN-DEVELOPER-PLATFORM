import AppShell from "../../../components/shell/AppShell";
import { PageHeader, Panel } from "../../../components/ui";
import { Icon } from "../../../lib/nav";

export const metadata = { title: "Open by Design — Cloud Superbrain" };

const PRINCIPLES = [
  { icon: "shield" as const, title: "Self-Hostable", body: "Run on your own machine or cloud. Your workflow, your infrastructure." },
  { icon: "tools" as const, title: "Extensible", body: "Build with skills, tools, agents and integrations. Plug in anything." },
  { icon: "agents" as const, title: "Community Powered", body: "Built together, made for everyone. Transparent and auditable." },
];

export default function OpenSourcePage() {
  return (
    <AppShell crumb="Open by Design" runState="idle">
      <div className="page">
        <PageHeader eyebrow="Open by Design" title="Open Source First" />
        <div className="prose">
          <p>
            Cloud Superbrain is open-source, independent and free-first. There is no vendor lock-in:
            use it, fork it, self-host it, and own your workflow end to end. The platform is a living
            AI developer organism — agents, memory, tools and models that evolve with your work.
          </p>
        </div>
        <div className="grid cols-3" style={{ marginTop: 20 }}>
          {PRINCIPLES.map((p) => (
            <Panel key={p.title} pad>
              <div className="feature" style={{ border: "none", padding: 0, background: "transparent" }}>
                <div className="ico">{Icon[p.icon]({ size: 18 })}</div>
                <h3>{p.title}</h3>
                <p>{p.body}</p>
              </div>
            </Panel>
          ))}
        </div>
        <div className="footer-slogan">
          <span>Build anything.</span>
          <span>Automate everything.</span>
          <span>Own your workflow.</span>
        </div>
      </div>
    </AppShell>
  );
}

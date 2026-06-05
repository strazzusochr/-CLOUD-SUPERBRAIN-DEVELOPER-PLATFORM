import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Metric, Badge, StatusDot } from "../../components/ui";
import { Icon } from "../../lib/nav";
import { fetchLiveAgents } from "../../lib/agentApi";

export const dynamic = "force-dynamic";
export const metadata = { title: "Home — Cloud Superbrain" };

const RECENT = [
  { name: "superbrain-game-engine", kind: "Game", route: "/games", when: "2m ago" },
  { name: "crisis-dashboard", kind: "App", route: "/apps", when: "1h ago" },
  { name: "platform-architecture.md", kind: "Doc", route: "/docs-output", when: "3h ago" },
];

export default async function HomePage() {
  const roster = await fetchLiveAgents();
  const live = !!roster;
  const sessions = roster ? roster.agents.filter((a) => a.hasSession).length : 0;
  const agentValue = live ? `${sessions} / ${roster!.agents.length}` : "0 / 4";

  return (
    <AppShell crumb="Home" runState="idle">
      <div className="page">
        <PageHeader
          eyebrow="Overview"
          title="Welcome back"
          subtitle="Continue where you left off. Pick up a recent project or start a new run from the Workbench."
          actions={
            <Link href="/workbench" className="btn btn-primary">
              {Icon.workbench({ size: 16 })} Open Workbench
            </Link>
          }
        />

        <div className="grid cols-4" style={{ marginBottom: 16 }}>
          <Metric label="Recent projects" value="3" foot={<><StatusDot tone="cyan" /> local</>} />
          <Metric
            label="Agents active"
            value={agentValue}
            foot={live ? <><StatusDot tone="green" pulse /> live roster</> : <><StatusDot tone="mut" /> planner/coder/tester/devops</>}
          />
          <Metric label="Cloud layers" value="7" foot={<>8 providers</>} />
          <Metric label="Gates" value="CLOSED" foot={<><StatusDot tone="green" /> safe by default</>} />
        </div>

        <div className="grid cols-2">
          <Panel
            title="Recent projects"
            actions={<Link href="/apps" className="btn btn-sm btn-ghost">All →</Link>}
          >
            <div className="list">
              {RECENT.map((r) => (
                <Link key={r.name} href={r.route} className="lrow">
                  {Icon.files({ size: 16 })}
                  <span style={{ fontWeight: 500 }}>{r.name}</span>
                  <Badge tone="mut">{r.kind}</Badge>
                  <span className="meta">{r.when}</span>
                </Link>
              ))}
            </div>
          </Panel>

          <Panel title="Next safe action" pad>
            <div className="stack">
              <div className="note">
                Your last slice landed. The next safe step is a dry-run eligibility check before any
                local apply — no writes, owner gate stays closed.
              </div>
              <div className="row" style={{ gap: 10 }}>
                <Link href="/workbench" className="btn btn-primary">Continue run</Link>
                <Link href="/organism" className="btn">View cortex</Link>
                <Link href="/evidence" className="btn btn-ghost">Open evidence</Link>
              </div>
              <div>
                <span className="panel-title" style={{ display: "block", marginBottom: 8 }}>
                  Output shortcuts
                </span>
                <div className="chips">
                  <Link href="/games" className="chip">Games</Link>
                  <Link href="/apps" className="chip">Apps</Link>
                  <Link href="/media" className="chip">Media</Link>
                  <Link href="/docs-output" className="chip">Documents</Link>
                </div>
              </div>
            </div>
          </Panel>
        </div>
      </div>
    </AppShell>
  );
}

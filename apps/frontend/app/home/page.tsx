import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Metric, Badge, StatusDot } from "../../components/ui";
import { Icon } from "../../lib/nav";

export const dynamic = "force-dynamic";
export const metadata = { title: "Home — Cloud Superbrain" };

export default async function HomePage() {
  return (
    <AppShell crumb="Home" runState="idle">
      <div className="page">
        <PageHeader
          eyebrow="Cloud Superbrain"
          title="Developer Platform"
          subtitle="Saubere Produktfläche für Games, Apps, Media und Docs. Nachweise, Verifier und externe Laufdaten bleiben getrennt in Evidence, Diagnostics und Organism verdrahtet."
          actions={
            <Link href="/workbench" className="btn btn-primary">
              {Icon.workbench({ size: 16 })} Werkbank öffnen
            </Link>
          }
        />

        <div className="grid cols-4" style={{ marginBottom: 16 }}>
          <Metric
            label="Studio-Modi"
            value="4"
            foot={<><StatusDot tone="cyan" /> Game · App · Media · Docs</>}
          />
          <Metric
            label="Core Pages"
            value="22"
            foot={<><StatusDot tone="green" /> 7-Layer Navigation</>}
          />
          <Metric
            label="Cloud-Layer"
            value="7"
            foot={<><StatusDot tone="cyan" /> Vercel · Fly · GHCR · Grafana</>}
          />
          <Metric
            label="Live Claims"
            value="0"
            foot={<><StatusDot tone="amber" /> nur mit Datenquelle</>}
          />
        </div>

        <div className="grid cols-2">
          <Panel
            title="Produktflächen"
            actions={<Link href="/workbench" className="btn btn-sm btn-ghost">Öffnen →</Link>}
          >
            <div className="list">
              <Link href="/games" className="lrow">
                {Icon.games({ size: 16 })}
                <span style={{ fontWeight: 500 }}>Games</span>
                <Badge tone="cyan">Workbench</Badge>
                <span className="meta">Code · Preview · Assets</span>
              </Link>
              <Link href="/apps" className="lrow">
                {Icon.apps({ size: 16 })}
                <span style={{ fontWeight: 500 }}>Apps</span>
                <Badge tone="cyan">Workbench</Badge>
                <span className="meta">UI · API · Deploy</span>
              </Link>
              <Link href="/media" className="lrow">
                {Icon.media({ size: 16 })}
                <span style={{ fontWeight: 500 }}>Media</span>
                <Badge tone="cyan">Workbench</Badge>
                <span className="meta">Video · Bild · Audio</span>
              </Link>
              <Link href="/docs-output" className="lrow">
                {Icon.docs({ size: 16 })}
                <span style={{ fontWeight: 500 }}>Docs</span>
                <Badge tone="cyan">Workbench</Badge>
                <span className="meta">Specs · Guides · Evidence Links</span>
              </Link>
            </div>
          </Panel>

          <Panel title="Verdrahtung" pad>
            <div className="stack">
              <div className="note">Die Plattform bleibt produktklar. Laufdaten, Verifier und externe Blocker erscheinen nur in den dedizierten Nachweisflächen.</div>
              <div className="row" style={{ gap: 10 }}>
                <Link href="/workbench" className="btn btn-primary">Werkbank öffnen</Link>
                <Link href="/organism" className="btn">Cortex ansehen</Link>
                <Link href="/evidence" className="btn btn-ghost">Nachweise öffnen</Link>
              </div>
              <div>
                <span className="panel-title" style={{ display: "block", marginBottom: 8 }}>
                  Output-Shortcuts
                </span>
                <div className="chips">
                  <Link href="/games" className="chip">Spiele</Link>
                  <Link href="/apps" className="chip">Apps</Link>
                  <Link href="/media" className="chip">Medien</Link>
                  <Link href="/docs-output" className="chip">Dokumente</Link>
                </div>
              </div>
            </div>
          </Panel>
        </div>
      </div>
    </AppShell>
  );
}

import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge } from "../../components/ui";
import { Icon } from "../../lib/nav";
import { HomeCortexHero } from "../../components/batch4-actions";
import { HomeWorkspace } from "../../components/home-workspace";
import { HomeRuntimeMonitor } from "../../components/home-runtime-monitor";

export const dynamic = "force-dynamic";
export const metadata = { title: "Start — Cloud Superbrain" };

export default async function HomePage() {
  return (
    <AppShell crumb="Start" runState="idle">
      <div className="page">
        <div className="home-hero-shell">
          <div className="home-hero-copy">
            <PageHeader
              eyebrow="Cloud Superbrain"
              title="Dein nächster Arbeitsstand"
              subtitle="Öffne die Workbench, um ein Projekt zu bauen oder einen gespeicherten Arbeitsstand weiterzuentwickeln."
              actions={
                <Link href="/workbench" className="btn btn-primary">
                  {Icon.workbench({ size: 16 })} Werkbank öffnen
                </Link>
              }
            />
          </div>
          <HomeCortexHero />
        </div>

        <HomeRuntimeMonitor />

        <div className="grid cols-2 home-content-grid">
          <HomeWorkspace />

          <Panel
            title="Produktflächen"
            className="home-product-panel"
            actions={<Link href="/workbench" className="btn btn-sm btn-ghost">Öffnen →</Link>}
          >
            <div className="list">
              <Link href="/games" className="lrow">
                {Icon.games({ size: 16 })}
                <span className="lrow-title">Spiele</span>
                <Badge tone="cyan">Werkbank</Badge>
                <span className="meta">Code · Vorschau · Assets</span>
              </Link>
              <Link href="/apps" className="lrow">
                {Icon.apps({ size: 16 })}
                <span className="lrow-title">Apps</span>
                <Badge tone="cyan">Werkbank</Badge>
                <span className="meta">UI · API · Bereitstellung</span>
              </Link>
              <Link href="/media" className="lrow">
                {Icon.media({ size: 16 })}
                <span className="lrow-title">Medien</span>
                <Badge tone="cyan">Werkbank</Badge>
                <span className="meta">Video · Bild · Audio</span>
              </Link>
              <Link href="/docs-output" className="lrow">
                {Icon.docs({ size: 16 })}
                <span className="lrow-title">Dokumente</span>
                <Badge tone="cyan">Werkbank</Badge>
                <span className="meta">Spezifikationen · Leitfäden · Nachweislinks</span>
              </Link>
            </div>
          </Panel>

        </div>
      </div>
    </AppShell>
  );
}

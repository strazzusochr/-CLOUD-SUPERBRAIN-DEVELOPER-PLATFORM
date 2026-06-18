import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { LiveConsole } from "../../components/live-console";
import { PageHeader, Panel, Metric, Badge, StatusDot } from "../../components/ui";
import { Icon } from "../../lib/nav";
import { HomeCortexHero, HomeHeroProofPanel } from "../../components/batch4-actions";
import { AiBuilder } from "../../components/ai-builder";

export const dynamic = "force-dynamic";
export const metadata = { title: "Home — Cloud Superbrain" };

export default async function HomePage() {
  return (
    <AppShell crumb="Home" runState="idle">
      <div className="page">
        <div className="build-hero">
          <h1 className="build-hero-title">Beschreibe es. Die KI baut es. Es läuft sofort.</h1>
          <p className="build-hero-sub">
            Cloud Superbrain ist eine KI-Entwickler-Plattform: Sag, welche App oder welches Spiel du willst —
            ein echtes Code-Modell baut es, und es läuft live in der Vorschau. Teilbar per Link, kostenlos.
          </p>
          <AiBuilder />
        </div>

        <div className="home-hero-shell">
          <div className="home-hero-copy">
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
            <HomeHeroProofPanel />
          </div>
          <HomeCortexHero />
        </div>

        <div className="grid cols-4 mb-16">
          <Metric
            label="Studio-Modi"
            value="4"
            foot={<><StatusDot tone="cyan" /> Produkt-Konstante</>}
          />
          <Metric
            label="Core Pages"
            value="22"
            foot={<><StatusDot tone="green" /> kanonische Navigation</>}
          />
          <Metric
            label="Cloud-Layer"
            value="7"
            foot={<><StatusDot tone="cyan" /> Architektur-Konstante</>}
          />
          <Metric
            label="Live Claims"
            value="0"
            foot={<><StatusDot tone="amber" /> nur mit Datenquelle</>}
          />
        </div>

        <div className="grid cols-2">
          <Panel title="Live console" className="mb-16" actions={<Badge tone="cyan">interaktiv</Badge>}>
            <div className="wb-pad">
              <LiveConsole
                endpoints={[
                  { label: "Health", path: "/api/v1/health" },
                  { label: "Clouds", path: "/api/v1/clouds" },
                  { label: "Platform verify", path: "/api/v1/platform/verify" },
                ]}
              />
            </div>
          </Panel>
          <Panel
            title="Produktflächen"
            actions={<Link href="/workbench" className="btn btn-sm btn-ghost">Öffnen →</Link>}
          >
            <div className="list">
              <Link href="/games" className="lrow">
                {Icon.games({ size: 16 })}
                <span className="lrow-title">Games</span>
                <Badge tone="cyan">Workbench</Badge>
                <span className="meta">Code · Preview · Assets</span>
              </Link>
              <Link href="/apps" className="lrow">
                {Icon.apps({ size: 16 })}
                <span className="lrow-title">Apps</span>
                <Badge tone="cyan">Workbench</Badge>
                <span className="meta">UI · API · Deploy</span>
              </Link>
              <Link href="/media" className="lrow">
                {Icon.media({ size: 16 })}
                <span className="lrow-title">Media</span>
                <Badge tone="cyan">Workbench</Badge>
                <span className="meta">Video · Bild · Audio</span>
              </Link>
              <Link href="/docs-output" className="lrow">
                {Icon.docs({ size: 16 })}
                <span className="lrow-title">Docs</span>
                <Badge tone="cyan">Workbench</Badge>
                <span className="meta">Specs · Guides · Evidence Links</span>
              </Link>
            </div>
          </Panel>

          <Panel title="Verdrahtung" pad>
            <div className="stack">
              <div className="note">Die Plattform bleibt produktklar. Laufdaten, Verifier und externe Blocker erscheinen nur in den dedizierten Nachweisflächen.</div>
              <div className="row gap-10">
                <Link href="/workbench" className="btn btn-primary">Werkbank öffnen</Link>
                <Link href="/organism" className="btn">Cortex ansehen</Link>
                <Link href="/evidence" className="btn btn-ghost">Nachweise öffnen</Link>
              </div>
              <div>
                <div className="panel-title mb-8">Output-Shortcuts</div>
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

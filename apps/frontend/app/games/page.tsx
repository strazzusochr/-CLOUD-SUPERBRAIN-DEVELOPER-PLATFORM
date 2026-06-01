import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge, SpecModeBadge } from "../../components/ui";
import { Icon } from "../../lib/nav";

export const metadata = { title: "Games Workflow — Cloud Superbrain" };

const TEMPLATES = ["Top-down", "Platformer", "Third-person", "Puzzle"];

export default function GamesPage() {
  return (
    <AppShell crumb="Games" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Games Workflow"
          title="Game projects"
          subtitle="Templates, scene preview, asset slots and playable routes. Existing local previews are wired; generators are labelled honestly."
          actions={<Link href="/workbench" className="btn btn-sm">Open in Workbench</Link>}
        />
        <div className="grid" style={{ gridTemplateColumns: "240px 1fr 300px" }}>
          <Panel title="Templates">
            <div className="list">
              {TEMPLATES.map((t, i) => (
                <div key={t} className={`lrow${i === 2 ? "" : ""}`} style={{ fontSize: 13 }}>{t}</div>
              ))}
            </div>
          </Panel>
          <Panel title="Scene preview · superbrain-game-engine">
            <div className="wb-pad">
              <div className="gcard" style={{ border: "none" }}>
                <div className="preview" style={{ height: 220 }}>Game view (local preview)</div>
              </div>
              <div className="row" style={{ gap: 8, marginTop: 12 }}>
                <button className="btn btn-sm btn-primary">{Icon.play({ size: 13 })} Play</button>
                <Link href="/workbench" className="btn btn-sm">Open in Workbench</Link>
                <SpecModeBadge mode="demo" />
              </div>
            </div>
          </Panel>
          <Panel title="Assets">
            <div className="wb-pad">
              <div className="assets">
                <div className="asset"><div className="thumb">GLB</div><span className="nm">character</span></div>
                <div className="asset"><div className="thumb">FBX</div><span className="nm">weapon</span></div>
                <div className="asset"><div className="thumb">EXR</div><span className="nm">env</span></div>
                <div className="asset"><div className="thumb">PNG</div><span className="nm">hud</span></div>
              </div>
              <p style={{ fontSize: 12, color: "var(--text-dim)", marginTop: 12 }}>
                <Badge tone="cyan">route</Badge> /games/pocket-hopper-gb (when present)
              </p>
            </div>
          </Panel>
        </div>
      </div>
    </AppShell>
  );
}

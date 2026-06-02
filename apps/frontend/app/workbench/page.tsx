import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import CortexCanvas from "../../components/organism/CortexCanvas";
import { Panel, Badge, StatusDot, Note } from "../../components/ui";
import { Icon } from "../../lib/nav";

export const metadata = { title: "Workbench — Cloud Superbrain" };

const TREE = [
  { d: 0, name: "superbrain-game-engine", folder: true },
  { d: 1, name: "assets", folder: true },
  { d: 1, name: "src", folder: true },
  { d: 2, name: "player.py", sel: true },
  { d: 2, name: "enemy.py" },
  { d: 2, name: "world.py" },
  { d: 1, name: "README.md" },
];

export default function WorkbenchPage() {
  return (
    <AppShell crumb="Workbench" runState="planning">
      <div className="page-wide">
        {/* Project sub-bar */}
        <div className="panel panel-head" style={{ marginBottom: 16, borderRadius: 14 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <Badge tone="cyan">{Icon.workbench({ size: 13 })} superbrain-game-engine</Badge>
            <Badge tone="mut">main</Badge>
            <button className="btn btn-sm">{Icon.play({ size: 13 })} Run</button>
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
            <Link href="/organism?run_id=active" className="btn btn-sm btn-ghost">
              {Icon.organism({ size: 14 })} Open cortex
            </Link>
            <Badge tone="green">Invite</Badge>
          </div>
        </div>

        <div className="wb">
          {/* Explorer */}
          <aside className="panel" style={{ overflow: "hidden" }}>
            <div className="panel-head">
              <span className="panel-title">Explorer</span>
            </div>
            <div className="wb-pad tree">
              {TREE.map((n, i) => (
                <div
                  key={i}
                  className={`tnode${n.sel ? " sel" : ""}`}
                  style={{ paddingLeft: 8 + n.d * 14 }}
                >
                  {n.folder ? Icon.files({ size: 13 }) : Icon.docs({ size: 13 })}
                  <span>{n.name}</span>
                </div>
              ))}
            </div>
          </aside>

          {/* Editor */}
          <main className="panel" style={{ overflow: "hidden", display: "flex", flexDirection: "column" }}>
            <div className="panel-head">
              <span className="panel-title">player.py</span>
              <Badge tone="mut">Python</Badge>
            </div>
            <div className="wb-pad" style={{ flex: 1 }}>
              <pre className="code" style={{ height: "100%", border: "none", background: "transparent", padding: 0 }}>
{`class `}<span className="fn">Player</span>{`(Character):
    `}<span className="k">def</span>{` `}<span className="fn">__init__</span>{`(self, cfg):
        super().__init__(cfg)
        self.health = cfg.get(`}<span className="s">&quot;health&quot;</span>{`, `}<span className="n">100</span>{`)

    `}<span className="k">def</span>{` `}<span className="fn">update</span>{`(self, dt):
        self.apply_gravity(dt)
        self.handle_input()
        self.update_animation(dt)`}
              </pre>
            </div>
          </main>

          {/* Inspector — preview + mini cortex */}
          <aside className="inspector panel" style={{ overflow: "hidden", display: "flex", flexDirection: "column" }}>
            <div className="panel-head">
              <span className="panel-title">Preview · Mini-Cortex</span>
            </div>
            <div className="wb-pad" style={{ display: "flex", flexDirection: "column", gap: 12 }}>
              <div style={{ aspectRatio: "16 / 11" }}>
                <CortexCanvas runState="planning" nodeCount={260} interactive={false} showRegions={false} />
              </div>
              <Link href="/organism?run_id=active" className="btn btn-sm btn-ghost" style={{ justifyContent: "center" }}>
                Open full organism →
              </Link>
              <div className="assets">
                <div className="asset"><div className="thumb">GLB</div><span className="nm">character</span></div>
                <div className="asset"><div className="thumb">FBX</div><span className="nm">weapon</span></div>
                <div className="asset"><div className="thumb">PNG</div><span className="nm">ui_hud</span></div>
              </div>
            </div>
          </aside>
        </div>

        {/* Bottom dock */}
        <div className="wb-dock">
          <Panel title="Prompt Composer">
            <div className="wb-pad">
              <p style={{ fontSize: 14, lineHeight: 1.5 }}>
                Create a third-person combat system with dash, parry and combo moves.
              </p>
              <div className="chips" style={{ margin: "10px 0" }}>
                <span className="chip active">Code</span>
                <span className="chip">Game</span>
                <span className="chip">App</span>
                <span className="chip">Docs</span>
                <span className="chip">Media</span>
              </div>
              <div className="row" style={{ gap: 8 }}>
                <input
                  aria-label="Prompt context or notes"
                  placeholder="Add context or notes…"
                  style={{ flex: 1, background: "var(--surface-2)", border: "1px solid var(--border)", borderRadius: 9, padding: "8px 12px", fontSize: 13 }}
                />
                <button className="btn btn-primary btn-sm" aria-label="Send prompt">
                  {Icon.send({ size: 15 })}
                </button>
              </div>
            </div>
          </Panel>

          <Panel title="Agent Assistance">
            <div className="wb-pad">
              <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 10 }}>
                <StatusDot tone="cyan" pulse />
                <strong style={{ fontSize: 13.5 }}>Architect Agent</strong>
                <Badge tone="green">Planning</Badge>
              </div>
              <div className="steps">
                <div className="step done">{Icon.evidence({ size: 14 })} Analyze requirements</div>
                <div className="step done">{Icon.evidence({ size: 14 })} Design system behavior</div>
                <div className="step">{Icon.organism({ size: 14 })} Implement core systems</div>
                <div className="step">{Icon.docs({ size: 14 })} Add tests &amp; docs</div>
              </div>
            </div>
          </Panel>

          <Panel title="Local Apply Eligibility · Dry-Run">
            <div className="wb-pad">
              <Note>
                Summarizes every apply prerequisite. <b>Dry-run only</b> — no writes, no approval
                persistence, owner gate closed.
              </Note>
              <div className="list" style={{ marginTop: 10 }}>
                <div className="lrow" style={{ padding: "7px 0" }}>Diff approval <span className="meta"><Badge tone="green">ready</Badge></span></div>
                <div className="lrow" style={{ padding: "7px 0" }}>File preflight <span className="meta"><Badge tone="green">ready</Badge></span></div>
                <div className="lrow" style={{ padding: "7px 0" }}>Owner apply gate <span className="meta"><Badge tone="red">closed</Badge></span></div>
                <div className="lrow" style={{ padding: "7px 0" }}>Apply allowed <span className="meta"><Badge tone="amber">false</Badge></span></div>
              </div>
            </div>
          </Panel>
        </div>
      </div>
    </AppShell>
  );
}

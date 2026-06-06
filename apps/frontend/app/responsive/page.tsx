import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge, Note } from "../../components/ui";

export const metadata = { title: "Responsive — Cloud Superbrain" };

const FRAMES = [
  { label: "Desktop", w: "1440+", note: "Full multi-panel + right inspector", cls: "fr-desktop" },
  { label: "Laptop", w: "1024", note: "Collapsible right inspector", cls: "fr-laptop" },
  { label: "Tablet", w: "768", note: "Tabbed side panels", cls: "fr-tablet" },
  { label: "Mobile", w: "375", note: "Single column, primary action first", cls: "fr-mobile" },
];

const BREAKPOINTS: { bp: string; rail: string; grid: string; cortex: string }[] = [
  { bp: "≥ 1440", rail: "expanded", grid: "4 cols", cortex: "full 3D" },
  { bp: "1280–1439", rail: "expanded", grid: "3 cols", cortex: "full 3D" },
  { bp: "1024–1279", rail: "icons", grid: "2 cols", cortex: "3D, inspector collapses" },
  { bp: "768–1023", rail: "icons", grid: "2 cols", cortex: "3D, side panels tab" },
  { bp: "< 768", rail: "hidden", grid: "1 col", cortex: "2D topology (reduced motion)" },
];

export default function ResponsivePage() {
  return (
    <AppShell crumb="Responsive" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Responsive"
          title="Breakpoint behavior"
          subtitle="Desktop / laptop / tablet / mobile collapse rules, reduced-motion fallback, and accessibility behaviour across the six breakpoints."
          actions={<Badge tone="cyan">375 → 1920+</Badge>}
        />

        <div className="frames">
          {FRAMES.map((f) => (
            <div key={f.label} className={`frame ${f.cls}`}>
              <div className="frame-bar">
                {f.label} · <span className="mono">{f.w}</span>
              </div>
              <div className="frame-body">
                <div className="frame-skeleton" aria-hidden="true">
                  <span className="fs-rail" />
                  <span className="fs-main" />
                  <span className="fs-aside" />
                </div>
                <span className="frame-note">{f.note}</span>
              </div>
            </div>
          ))}
        </div>

        <div className="page-head" style={{ margin: "22px 0 12px" }}>
          <div>
            <div className="eyebrow">Breakpoint matrix</div>
            <h2 style={{ fontSize: 17 }}>How the shell adapts</h2>
          </div>
        </div>
        <Panel>
          <div className="bp-table">
            <div className="bp-row bp-head">
              <span>Width (px)</span>
              <span>Primary rail</span>
              <span>Content grid</span>
              <span>Cortex</span>
            </div>
            {BREAKPOINTS.map((b) => (
              <div key={b.bp} className="bp-row">
                <span className="mono" style={{ color: "var(--text-pri)" }}>{b.bp}</span>
                <span>{b.rail}</span>
                <span>{b.grid}</span>
                <span style={{ color: "var(--text-mut)" }}>{b.cortex}</span>
              </div>
            ))}
          </div>
        </Panel>

        <div className="grid cols-2" style={{ marginTop: 16 }}>
          <Panel title="Collapse rules" pad>
            <ul className="rule-list">
              <li>&lt; 1280px — right inspector collapses, grids fold to 2 columns.</li>
              <li>&lt; 900px — primary rail hides behind a menu, single-column stack.</li>
              <li>Command palette hides under 900px; search moves into the top bar.</li>
              <li>Organism canvas keeps aspect ratio; never overflows its panel.</li>
            </ul>
          </Panel>
          <Panel title="Accessibility & reduced motion" pad>
            <ul className="rule-list">
              <li><span className="mono">prefers-reduced-motion</span> → cortex swaps to a static 2D topology.</li>
              <li>3D and monitoring surfaces always provide a list fallback.</li>
              <li>No color-only status — every badge carries an icon + text.</li>
              <li>Focus-visible rings, keyboard nav, and AA contrast across breakpoints.</li>
            </ul>
          </Panel>
        </div>

        <Note>
          Breakpoints: 375 · 768 · 1024 · 1280 · 1440 · 1920+. The same component tree renders at every
          width — no separate mobile build — so behaviour is verifiable with Playwright viewport snapshots.
        </Note>
      </div>
    </AppShell>
  );
}

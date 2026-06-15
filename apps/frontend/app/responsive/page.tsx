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
          title="Breakpoint-Verhalten"
          subtitle="Regeln für Desktop/Laptop/Tablet/Mobile, Reduced-Motion-Fallback und Accessibility über sechs Breakpoints."
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

        <div className="page-head section-head">
          <div>
            <div className="eyebrow">Breakpoint-Matrix</div>
            <h2 className="section-h2">Wie sich die Shell anpasst</h2>
          </div>
        </div>
        <Panel>
          <div className="bp-table">
            <div className="bp-row bp-head">
              <span>Breite (px)</span>
              <span>Primäre Rail</span>
              <span>Content-Grid</span>
              <span>Cortex</span>
            </div>
            {BREAKPOINTS.map((b) => (
              <div key={b.bp} className="bp-row">
                <span className="mono">{b.bp}</span>
                <span>{b.rail}</span>
                <span>{b.grid}</span>
                <span className="text-mut">{b.cortex}</span>
              </div>
            ))}
          </div>
        </Panel>

        <div className="grid cols-2 mt-16">
          <Panel title="Collapse-Regeln" pad>
            <ul className="rule-list">
              <li>&lt; 1280px — rechter Inspector klappt ein, Grids auf 2 Spalten.</li>
              <li>&lt; 900px — primäre Rail hinter Menü, Single-Column Stack.</li>
              <li>Command-Palette verschwindet unter 900px; Suche wandert in die Topbar.</li>
              <li>Organismus-Canvas hält Aspect Ratio; overflowt nie das Panel.</li>
            </ul>
          </Panel>
          <Panel title="Accessibility & Reduced Motion" pad>
            <ul className="rule-list">
              <li><span className="mono">prefers-reduced-motion</span> → Cortex wechselt auf statische 2D-Topologie.</li>
              <li>3D- und Monitoring-Surfaces haben immer eine Listen-Fallback.</li>
              <li>Kein Status nur per Farbe — jedes Badge hat Icon + Text.</li>
              <li>Focus-visible, Keyboard-Navigation und AA-Kontrast über Breakpoints.</li>
            </ul>
          </Panel>
        </div>

        <Note>
          Breakpoints: 375 · 768 · 1024 · 1280 · 1440 · 1920+. Der gleiche Component-Tree rendert bei jeder
          Breite — kein separater Mobile-Build — dadurch ist das Verhalten mit Playwright-Viewport-Snapshots verifizierbar.
        </Note>
      </div>
    </AppShell>
  );
}

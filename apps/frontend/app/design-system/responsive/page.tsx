import AppShell from "../../../components/shell/AppShell";
import { PageHeader, Panel, Note } from "../../../components/ui";

export const metadata = { title: "Responsive Preview — Cloud Superbrain" };

const FRAMES = [
  { label: "Desktop · 1440+", note: "Full multi-panel" },
  { label: "Laptop · 1024", note: "Collapsible right inspector" },
  { label: "Tablet · 768", note: "Tabbed side panels" },
  { label: "Mobile · 375", note: "Single column, primary action first" },
];

export default function ResponsivePage() {
  return (
    <AppShell crumb="Responsive Preview" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Responsive Preview"
          title="Breakpoint behavior"
          subtitle="Desktop / laptop / tablet / mobile collapse rules, reduced-motion fallback, and accessibility snapshots."
        />
        <div className="frames">
          {FRAMES.map((f) => (
            <div key={f.label} className="frame">
              <div className="frame-bar">{f.label}</div>
              <div className="frame-body">{f.note}</div>
            </div>
          ))}
        </div>
        <Note>
          Breakpoints: 375 · 768 · 1024 · 1280 · 1440 · 1920+. 3D and monitoring surfaces always
          provide a list fallback; reduced-motion swaps the cortex for a static topology.
        </Note>
        <Panel title="Collapse rules" style={{ marginTop: 16 }}>
          <div className="wb-pad">
            <ul style={{ color: "var(--text-mut)", fontSize: 13, lineHeight: 1.8, paddingLeft: 18 }}>
              <li>&lt; 1280px — right inspector collapses, grids fold to 2 columns.</li>
              <li>&lt; 900px — primary rail hides, single-column stack, command palette hidden.</li>
              <li>Organism — canvas keeps aspect ratio; reduced-motion → 2D topology list.</li>
            </ul>
          </div>
        </Panel>
      </div>
    </AppShell>
  );
}

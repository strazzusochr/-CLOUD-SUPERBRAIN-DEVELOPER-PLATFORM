import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, EmptyState, SpecModeBadge } from "../../components/ui";

export const metadata = { title: "Media Workflow — Cloud Superbrain" };

export default function MediaPage() {
  return (
    <AppShell crumb="Media" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Media Workflow"
          title="Images · Video · Audio"
          subtitle="Storyboard, media stage and prompt brief. Generators are preview-first and spec-only until a provider is wired."
          actions={<SpecModeBadge mode="spec_only" />}
        />
        <div className="grid" style={{ gridTemplateColumns: "240px 1fr 300px" }}>
          <Panel title="Storyboard">
            <div className="wb-pad stack" style={{ gap: 8 }}>
              {[1, 2, 3].map((i) => (
                <div key={i} className="frame-body" style={{ height: 64, borderRadius: 8, border: "1px solid var(--border)" }}>
                  Scene {i}
                </div>
              ))}
            </div>
          </Panel>
          <Panel title="Media stage">
            <div className="wb-pad">
              <div className="chips" style={{ marginBottom: 12 }}>
                <span className="chip active">Image</span>
                <span className="chip">Video</span>
                <span className="chip">Audio</span>
              </div>
              <EmptyState
                title="No media generated yet"
                body="Media generation is spec-only in this build. Start a brief from the Workbench with mode=Media."
                action={<a href="/workbench" className="btn btn-sm btn-primary">Open Workbench</a>}
              />
            </div>
          </Panel>
          <Panel title="Prompt brief">
            <div className="wb-pad">
              <p style={{ fontSize: 13, color: "var(--text-mut)" }}>
                Describe the image, video or audio you want. Imports and previews appear here first.
              </p>
            </div>
          </Panel>
        </div>
      </div>
    </AppShell>
  );
}

import AppShell from "../../components/shell/AppShell";
import { LiveConsole } from "../../components/live-console";
import { AiBuilder } from "../../components/ai-builder";
import { BuildsGallery } from "../../components/builds-gallery";
import { Panel, Badge } from "../../components/ui";

export const metadata = { title: "Workbench — Cloud Superbrain" };
export const dynamic = "force-dynamic";

// The Workbench is the real build surface: describe an app/game → it is generated
// by a real code model and runs live in the preview → iterate, download, share.
// (The previous fake IDE mockup was removed — no fake editor/terminal/file tree.)
export default function WorkbenchPage() {
  return (
    <AppShell crumb="Bauen" runState="idle">
      <div className="page-wide">
        <Panel title="Bauen mit KI · beschreibe es, es läuft sofort" className="mb-16" actions={<Badge tone="green">echt · live</Badge>}>
          <div className="wb-pad">
            <AiBuilder />
          </div>
        </Panel>

        <Panel title="Meine Apps · gebaut & teilbar" className="mb-16" actions={<Badge tone="cyan">persistiert</Badge>}>
          <BuildsGallery />
        </Panel>

        <Panel title="Plattform-Status" actions={<Badge tone="cyan">live</Badge>}>
          <div className="wb-pad">
            <LiveConsole
              label="Plattform"
              endpoints={[
                { label: "Health", path: "/api/v1/health" },
                { label: "Gebaute Apps", path: "/api/v1/builds?limit=5" },
                { label: "Letzte Sitzungen", path: "/api/v1/sessions/recent" },
              ]}
            />
          </div>
        </Panel>
      </div>
    </AppShell>
  );
}

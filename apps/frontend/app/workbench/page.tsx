import AppShell from "../../components/shell/AppShell";
import { WorkbenchStudio } from "../../components/workbench-studio";
import { BuildsGallery } from "../../components/builds-gallery";
import { Panel, Badge } from "../../components/ui";

export const metadata = { title: "Bauen — Cloud Superbrain" };
export const dynamic = "force-dynamic";

// IDE-style build studio: composer + Explorer (real generated files) + Editor/
// Live-Preview + real build log. Then your built apps.
export default function WorkbenchPage() {
  return (
    <AppShell crumb="Bauen" runState="idle">
      <div className="page-wide">
        <Panel title="Studio · beschreibe es, es läuft sofort" className="mb-16" actions={<Badge tone="green">echt · live</Badge>}>
          <div className="wb-pad">
            <WorkbenchStudio />
          </div>
        </Panel>

        <Panel title="Meine Apps" actions={<Badge tone="cyan">gebaut & teilbar</Badge>}>
          <BuildsGallery />
        </Panel>
      </div>
    </AppShell>
  );
}

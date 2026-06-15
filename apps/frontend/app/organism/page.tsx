import AppShell from "../../components/shell/AppShell";
import { LiveConsole } from "../../components/live-console";
import SevenLayerBar from "../../components/shell/SevenLayerBar";
import OrganismView from "../../components/organism/OrganismView";
import { Panel, Badge } from "../../components/ui";

export const dynamic = "force-dynamic";
export const metadata = { title: "Organism / Cortex Canvas — Cloud Superbrain" };

export default function OrganismPage() {
  return (
    <AppShell crumb="Organism" runState="planning">
      <div className="page-wide">
        <SevenLayerBar title="Organism state verified across 7 cloud layers" />
        <Panel title="Live organism endpoints" className="mb-16" actions={<Badge tone="cyan">interaktiv · read-only</Badge>}>
          <div className="wb-pad">
            <LiveConsole
              label="Organism"
              endpoints={[
                { label: "Live state", path: "/api/v1/organism/live-state" },
                { label: "Events", path: "/api/v1/organism/events" },
                { label: "Replay", path: "/api/v1/organism/replay" },
              ]}
            />
          </div>
        </Panel>
      </div>
      <OrganismView mode="live" />
    </AppShell>
  );
}

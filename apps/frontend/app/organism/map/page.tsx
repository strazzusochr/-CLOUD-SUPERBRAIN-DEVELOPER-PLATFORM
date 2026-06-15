import Link from "next/link";
import AppShell from "../../../components/shell/AppShell";
import { LiveConsole } from "../../../components/live-console";
import OrganismView from "../../../components/organism/OrganismView";
import { PageHeader, Panel, Badge } from "../../../components/ui";

export const metadata = { title: "Organism · Map — Cloud Superbrain" };

export default function OrganismMapPage() {
  return (
    <AppShell crumb="Organism · Map" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Organism"
          title="Cortex Map"
          subtitle="Interaktive Topologie-Ansicht des Organism. Buttons und Live-Endpoints sind read-only."
          actions={
            <>
              <Link href="/organism" className="btn btn-sm btn-ghost">Live</Link>
              <Link href="/organism/replay" className="btn btn-sm btn-ghost">Replay</Link>
            </>
          }
        />
        <Panel title="Live endpoints" className="mb-16" actions={<Badge tone="cyan">interaktiv · read-only</Badge>}>
          <div className="wb-pad">
            <LiveConsole
              label="Organism map"
              endpoints={[
                { label: "Live state", path: "/api/v1/organism/live-state" },
                { label: "Map events", path: "/api/v1/organism/events" },
                { label: "Health", path: "/api/v1/health" },
              ]}
            />
          </div>
        </Panel>
      </div>
      <OrganismView mode="map" />
    </AppShell>
  );
}

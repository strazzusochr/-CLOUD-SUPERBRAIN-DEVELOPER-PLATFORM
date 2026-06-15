import Link from "next/link";
import AppShell from "../../../components/shell/AppShell";
import { LiveConsole } from "../../../components/live-console";
import OrganismView from "../../../components/organism/OrganismView";
import { PageHeader, Panel, Badge } from "../../../components/ui";

export const metadata = { title: "Organism · Replay — Cloud Superbrain" };

export default function OrganismReplayPage() {
  return (
    <AppShell crumb="Organism · Replay" runState="verifying">
      <div className="page-wide">
        <PageHeader
          eyebrow="Organism"
          title="Replay"
          subtitle="Interaktive Replay-Ansicht mit Run-ID Auswahl im Canvas. Endpoints sind read-only."
          actions={
            <>
              <Link href="/organism" className="btn btn-sm btn-ghost">Live</Link>
              <Link href="/organism/map" className="btn btn-sm btn-ghost">Map</Link>
            </>
          }
        />
        <Panel title="Live endpoints" className="mb-16" actions={<Badge tone="cyan">interaktiv · read-only</Badge>}>
          <div className="wb-pad">
            <LiveConsole
              label="Organism replay"
              endpoints={[
                { label: "Replay", path: "/api/v1/organism/replay" },
                { label: "Events", path: "/api/v1/organism/events" },
                { label: "Health", path: "/api/v1/health" },
              ]}
            />
          </div>
        </Panel>
      </div>
      <OrganismView mode="replay" />
    </AppShell>
  );
}

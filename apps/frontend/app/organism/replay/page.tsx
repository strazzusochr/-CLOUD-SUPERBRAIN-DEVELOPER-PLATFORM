import Link from "next/link";
import AppShell from "../../../components/shell/AppShell";
import { LiveConsole } from "../../../components/live-console";
import OrganismView from "../../../components/organism/OrganismView";
import { PageHeader, Panel, Badge } from "../../../components/ui";

export const metadata = { title: "Organismus · Wiedergabe — Cloud Superbrain" };

export default function OrganismReplayPage() {
  return (
    <AppShell crumb="Organismus · Wiedergabe" runState="verifying">
      <div className="page-wide">
        <PageHeader
          eyebrow="Organismus"
          title="Wiedergabe"
          subtitle="Interaktive Wiedergabe mit Auswahl der Run-ID in der Ansicht. Die Endpunkte sind nur lesend."
          actions={
            <>
              <Link href="/organism" className="btn btn-sm btn-ghost">Live</Link>
              <Link href="/organism/map" className="btn btn-sm btn-ghost">Karte</Link>
            </>
          }
        />
        <Panel title="Live-Endpunkte" className="mb-16" actions={<Badge tone="cyan">interaktiv · nur lesend</Badge>}>
          <div className="wb-pad">
            <LiveConsole
              label="Organismus-Wiedergabe"
              endpoints={[
                { label: "Wiedergabe", path: "/api/v1/organism/replay" },
                { label: "Ereignisse", path: "/api/v1/organism/events" },
                { label: "Systemzustand", path: "/api/v1/health" },
              ]}
            />
          </div>
        </Panel>
      </div>
      <OrganismView mode="replay" />
    </AppShell>
  );
}

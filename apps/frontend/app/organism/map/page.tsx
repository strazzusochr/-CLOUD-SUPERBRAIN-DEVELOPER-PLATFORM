import Link from "next/link";
import AppShell from "../../../components/shell/AppShell";
import { LiveConsole } from "../../../components/live-console";
import OrganismView from "../../../components/organism/OrganismView";
import { PageHeader, Panel, Badge } from "../../../components/ui";

export const metadata = { title: "Organismus · Karte — Cloud Superbrain" };

export default function OrganismMapPage() {
  return (
    <AppShell crumb="Organismus · Karte" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Organismus"
          title="Cortex-Karte"
          subtitle="Interaktive Topologieansicht des Organismus. Schaltflächen und Live-Endpunkte sind nur lesend."
          actions={
            <>
              <Link href="/organism" className="btn btn-sm btn-ghost">Live</Link>
              <Link href="/organism/replay" className="btn btn-sm btn-ghost">Wiedergabe</Link>
            </>
          }
        />
        <Panel title="Live-Endpunkte" className="mb-16" actions={<Badge tone="cyan">interaktiv · nur lesend</Badge>}>
          <div className="wb-pad">
            <LiveConsole
              label="Organismus-Karte"
              endpoints={[
                { label: "Live-Status", path: "/api/v1/organism/live-state" },
                { label: "Kartenereignisse", path: "/api/v1/organism/events" },
                { label: "Systemzustand", path: "/api/v1/health" },
              ]}
            />
          </div>
        </Panel>
      </div>
      <OrganismView mode="map" />
    </AppShell>
  );
}

import Link from "next/link";
import AppShell from "../../../components/shell/AppShell";
import { LiveConsole } from "../../../components/live-console";
import OrganismTopologyMap from "../../../components/organism/OrganismTopologyMap";
import { PageHeader, Panel, Badge } from "../../../components/ui";

export const metadata = { title: "Organismus · Karte — Cloud Superbrain" };

export default function OrganismMapPage() {
  return (
    <AppShell crumb="Organismus · Karte" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Organismus"
          title="Cortex-Karte"
          subtitle="Vertragsgebundene Topologie mit Knotenfiltern und gerichteter Nachbarschaft. Alle Endpunkte sind nur lesend."
          actions={
            <>
              <Link href="/organism" className="btn btn-sm btn-ghost">Live</Link>
              <Link href="/organism/replay" className="btn btn-sm btn-ghost">Wiedergabe</Link>
            </>
          }
        />
        <OrganismTopologyMap />
        <Panel title="Live-Endpunkte" className="mb-16" actions={<Badge tone="cyan">interaktiv · nur lesend</Badge>}>
          <div className="wb-pad">
            <LiveConsole
              label="Organismus-Karte"
              endpoints={[
                { label: "Regionen", path: "/api/v1/organism/regions" },
                { label: "Sicherheit", path: "/api/v1/organism/safety" },
                { label: "Topologie", path: "/api/v1/organism/topology" },
              ]}
            />
          </div>
        </Panel>
      </div>
    </AppShell>
  );
}

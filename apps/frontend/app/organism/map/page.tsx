import AppShell from "../../../components/shell/AppShell";
import OrganismView from "../../../components/organism/OrganismView";

export const metadata = { title: "Organism · Map — Cloud Superbrain" };

export default function OrganismMapPage() {
  return (
    <AppShell crumb="Organism · Map" runState="idle">
      <OrganismView mode="map" />
    </AppShell>
  );
}

import AppShell from "../../../components/shell/AppShell";
import OrganismView from "../../../components/organism/OrganismView";

export const metadata = { title: "Organism · Live — Cloud Superbrain" };

export default function OrganismLivePage() {
  return (
    <AppShell crumb="Organism · Live" runState="executing">
      <OrganismView mode="live" />
    </AppShell>
  );
}

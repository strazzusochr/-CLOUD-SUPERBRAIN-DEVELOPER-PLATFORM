import AppShell from "../../components/shell/AppShell";
import OrganismView from "../../components/organism/OrganismView";

export const metadata = { title: "Organism / Cortex Canvas — Cloud Superbrain" };

export default function OrganismPage() {
  return (
    <AppShell crumb="Organism" runState="planning">
      <OrganismView mode="live" />
    </AppShell>
  );
}

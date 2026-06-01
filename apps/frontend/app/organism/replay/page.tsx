import AppShell from "../../../components/shell/AppShell";
import OrganismView from "../../../components/organism/OrganismView";

export const metadata = { title: "Organism · Replay — Cloud Superbrain" };

export default function OrganismReplayPage() {
  return (
    <AppShell crumb="Organism · Replay" runState="verifying">
      <OrganismView mode="replay" />
    </AppShell>
  );
}

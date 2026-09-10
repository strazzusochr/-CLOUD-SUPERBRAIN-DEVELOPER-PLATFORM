import AppShell from "../../components/shell/AppShell";
import OrganismView from "../../components/organism/OrganismView";

export const dynamic = "force-dynamic";
export const metadata = { title: "Cortex — Cloud Superbrain" };

// The living cortex: a 3D map of the platform's cognitive organism — capability
// hubs in orbit around a neural core, with a live activity feed driven by real
// platform events (builds, prompts, memory, agents).
export default function OrganismPage() {
  return (
    <AppShell crumb="Cortex" runState="idle">
      <OrganismView mode="live" />
    </AppShell>
  );
}

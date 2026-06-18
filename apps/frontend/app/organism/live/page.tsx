import AppShell from "../../../components/shell/AppShell";
import OrganismView from "../../../components/organism/OrganismView";

export const dynamic = "force-dynamic";
export const metadata = { title: "Organism · Live — Cloud Superbrain" };

export default function OrganismLivePage() {
  return (
    <AppShell crumb="Organism · Live" runState="planning">
      <div className="page-wide pb-0">
      </div>
      <OrganismView mode="live" />
    </AppShell>
  );
}

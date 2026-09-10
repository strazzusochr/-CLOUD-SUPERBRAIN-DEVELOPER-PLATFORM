import AppShell from "../../components/shell/AppShell";
import { Panel, Badge } from "../../components/ui";
import { RealGame } from "../../components/real-game";
import { WorkbenchStudio } from "../../components/workbench-studio";
import { BuildsGallery } from "../../components/builds-gallery";

export const metadata = { title: "Spiele — Cloud Superbrain" };
export const dynamic = "force-dynamic";

// Game build studio (same IDE as the Workbench, game-tuned) + a playable demo.
export default function GamesPage() {
  return (
    <AppShell crumb="Spiele" runState="idle">
      <div className="page-wide">
        <WorkbenchStudio
          placeholder="Beschreibe dein Spiel — z. B. „ein 3D-Asteroiden-Spiel mit Maus-Steuerung und Punktestand“"
          examples={[
            "Ein 3D-Asteroiden-Spiel mit Maus-Steuerung und Punktestand",
            "Ein Snake-Spiel mit Neon-Design und steigender Geschwindigkeit",
            "Ein Plattformer mit springender Figur und Hindernissen",
            "Ein Flappy-Bird-Klon mit Highscore",
          ]}
        />
        <Panel title="Demo · spielbares 3D-Arena-Game" className="mt-16" actions={<Badge tone="green">sofort spielbar</Badge>}>
          <div className="wb-pad">
            <RealGame />
          </div>
        </Panel>

        <Panel title="Build-Verlauf" className="mt-16" actions={<Badge tone="cyan">Agent API · Registry</Badge>}>
          <div className="wb-pad">
            <BuildsGallery />
          </div>
        </Panel>
      </div>
    </AppShell>
  );
}

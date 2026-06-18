import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge } from "../../components/ui";
import { RealGame } from "../../components/real-game";
import { WorkbenchStudio } from "../../components/workbench-studio";
import { BuildsGallery } from "../../components/builds-gallery";

export const metadata = { title: "Spiele — Cloud Superbrain" };
export const dynamic = "force-dynamic";

// Same IDE studio as the Workbench, tuned for games — build a game by describing
// it, see its files + live preview, iterate. Plus a built-in playable demo.
export default function GamesPage() {
  return (
    <AppShell crumb="Spiele" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Spiele"
          title="Spiele bauen"
          subtitle="Beschreibe ein Spiel — ein echtes Code-Modell baut es und es läuft sofort spielbar in der Vorschau."
        />
        <Panel title="Studio · Spiel beschreiben, sofort spielen" className="mb-16" actions={<Badge tone="green">echt · live</Badge>}>
          <div className="wb-pad">
            <WorkbenchStudio
              placeholder="Beschreibe dein Spiel — z. B. „ein 3D-Asteroiden-Spiel mit Maus-Steuerung und Punktestand“"
              examples={[
                "Ein 3D-Asteroiden-Spiel mit Maus-Steuerung und Punktestand",
                "Ein Snake-Spiel mit Neon-Design und steigender Geschwindigkeit",
                "Ein Plattformer mit springender Figur und Hindernissen",
                "Ein Flappy-Bird-Klon mit Highscore",
              ]}
            />
          </div>
        </Panel>

        <Panel title="Meine Spiele" className="mb-16" actions={<Badge tone="cyan">gebaut & teilbar</Badge>}>
          <BuildsGallery />
        </Panel>

        <Panel title="Demo · spielbares 3D-Arena-Game" actions={<Badge tone="green">sofort spielbar</Badge>}>
          <div className="wb-pad">
            <RealGame />
          </div>
        </Panel>
      </div>
    </AppShell>
  );
}

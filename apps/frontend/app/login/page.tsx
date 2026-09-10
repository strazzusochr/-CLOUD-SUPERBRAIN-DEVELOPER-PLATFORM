import Link from "next/link";
import { Badge, SafetyBadgeRow } from "../../components/ui";
import { RealLogin } from "../../components/real-login";

export const metadata = { title: "Anmeldung / Einstieg — Cloud Superbrain" };

export default function LoginPage() {
  return (
    <div className="app-shell marketing">
      <header className="topbar marketing-topbar">
        <Link href="/" className="brandmark">
          <span className="glyph" />
          Cloud Superbrain
        </Link>
        <div className="grow" />
        <Link href="/home" className="btn btn-ghost btn-sm">
          Zum Start
        </Link>
      </header>

      <main className="main">
        <div className="page login-page">
          <div className="grid cols-2 login-grid">
            <section className="panel panel-pad login-panel">
              <div>
                <div className="eyebrow">Willkommen zurück</div>
                <h1 className="login-h1">Am Arbeitsbereich anmelden</h1>
              </div>

              <RealLogin />

              <p className="login-foot">
                Signierte Sitzung mit HttpOnly-Cookie und Ablaufprüfung. Externe OAuth-Provider bleiben separat freigabepflichtig.
              </p>
            </section>

            <section className="panel panel-pad login-panel">
              <span className="panel-title">Bereitschaft des Arbeitsbereichs</span>
              <div className="list login-readiness-list">
                <div className="lrow">
                  Selbst gehostet oder Cloud <span className="meta"><Badge tone="green">bereit</Badge></span>
                </div>
                <div className="lrow">
                  API für lokale Dateien <span className="meta"><Badge tone="cyan">nur lesend</Badge></span>
                </div>
                <div className="lrow">
                  Provider-Schreibzugriffe <span className="meta"><Badge tone="red">Gate geschlossen</Badge></span>
                </div>
                <div className="lrow">
                  Lizenz für Open Source <span className="meta"><Badge tone="violet">kostenlos zuerst</Badge></span>
                </div>
              </div>
              <div>
                <span className="panel-title login-panel-title">Sicherheit</span>
                <SafetyBadgeRow />
              </div>
              <p className="login-foot login-foot-spacer">
                Dein Arbeitsablauf gehört dir. Baue alles. Automatisiere alles.
              </p>
            </section>
          </div>
        </div>
      </main>
    </div>
  );
}

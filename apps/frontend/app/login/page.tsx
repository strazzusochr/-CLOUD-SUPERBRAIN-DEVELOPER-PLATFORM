import Link from "next/link";
import { Badge, SafetyBadgeRow } from "../../components/ui";
import { LoginDryRunPanel } from "../../components/batch4-actions";

export const metadata = { title: "Login / Onboarding — Cloud Superbrain" };

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
          Skip to Home
        </Link>
      </header>

      <main className="main">
        <div className="page login-page">
          <div className="grid cols-2 login-grid">
            <section className="panel panel-pad login-panel">
              <div>
                <div className="eyebrow">Welcome back</div>
                <h1 className="login-h1">Sign in to your workspace</h1>
              </div>

              <LoginDryRunPanel />

              <Link href="/workbench" className="btn btn-primary login-center">
                Open Workbench after dry-run
              </Link>
              <p className="login-foot">
                OAuth and email providers stay dry-run in this proof. No live provider write, no secret output.
              </p>
            </section>

            <section className="panel panel-pad login-panel">
              <span className="panel-title">Workspace readiness</span>
              <div className="list login-readiness-list">
                <div className="lrow">
                  Self-host or Cloud <span className="meta"><Badge tone="green">ready</Badge></span>
                </div>
                <div className="lrow">
                  Local Files API <span className="meta"><Badge tone="cyan">read-only</Badge></span>
                </div>
                <div className="lrow">
                  Provider writes <span className="meta"><Badge tone="red">closed gate</Badge></span>
                </div>
                <div className="lrow">
                  Open-source license <span className="meta"><Badge tone="violet">free-first</Badge></span>
                </div>
              </div>
              <div>
                <span className="panel-title login-panel-title">Safety</span>
                <SafetyBadgeRow />
              </div>
              <p className="login-foot login-foot-spacer">
                You own your workflow. Build anything. Automate everything.
              </p>
            </section>
          </div>
        </div>
      </main>
    </div>
  );
}

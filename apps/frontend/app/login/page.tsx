import Link from "next/link";
import { Badge, SafetyBadgeRow } from "../../components/ui";
import { Icon } from "../../lib/nav";

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
        <div className="page" style={{ maxWidth: 880, paddingTop: 24 }}>
          <div className="grid cols-2" style={{ alignItems: "stretch" }}>
            <section className="panel panel-pad" style={{ display: "flex", flexDirection: "column", gap: 14 }}>
              <div>
                <div className="eyebrow">Welcome back</div>
                <h1 style={{ fontSize: 24, marginTop: 6 }}>Sign in to your workspace</h1>
              </div>

              <div className="stack" style={{ gap: 10 }}>
                <Link href="/home" className="btn" style={{ justifyContent: "center" }}>
                  {Icon.open({ size: 16 })} Continue with GitHub
                </Link>
                <Link href="/home" className="btn" style={{ justifyContent: "center" }}>
                  Continue with Google
                </Link>
                <Link href="/home" className="btn" style={{ justifyContent: "center" }}>
                  Continue with Email
                </Link>
              </div>

              <div style={{ display: "flex", alignItems: "center", gap: 12, color: "var(--text-dim)", fontSize: 12 }}>
                <span style={{ flex: 1, height: 1, background: "var(--border)" }} />
                or
                <span style={{ flex: 1, height: 1, background: "var(--border)" }} />
              </div>

              <Link href="/workbench" className="btn btn-primary" style={{ justifyContent: "center" }}>
                Continue as Guest → Start Workbench
              </Link>
              <p style={{ fontSize: 12, color: "var(--text-dim)" }}>
                Guest mode runs fully local. No account required to use the Workbench.
              </p>
            </section>

            <section className="panel panel-pad" style={{ display: "flex", flexDirection: "column", gap: 14 }}>
              <span className="panel-title">Workspace readiness</span>
              <div className="list" style={{ border: "1px solid var(--border)", borderRadius: 10 }}>
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
                <span className="panel-title" style={{ display: "block", marginBottom: 8 }}>Safety</span>
                <SafetyBadgeRow />
              </div>
              <p style={{ fontSize: 12, color: "var(--text-dim)", marginTop: "auto" }}>
                You own your workflow. Build anything. Automate everything.
              </p>
            </section>
          </div>
        </div>
      </main>
    </div>
  );
}

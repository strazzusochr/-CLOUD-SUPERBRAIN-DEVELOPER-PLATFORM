// Shareable "running app" page: renders a previously built app full-screen in a
// sandboxed iframe. The link /run/<id> can be shared — anyone who opens it sees
// the app actually run. The HTML is read from the persistent store server-side.

import * as gh from "../../../lib/ghStore";

export const dynamic = "force-dynamic";

function safeId(v: string): string {
  return /^[A-Za-z0-9_-]{1,64}$/.test(v) ? v : "";
}

export default async function RunPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const clean = safeId(id);
  let html: string | null = null;
  if (clean && gh.ghConfigured()) {
    try {
      html = await gh.getRaw(`builds/${clean}.html`);
    } catch {
      html = null;
    }
  }

  if (!html) {
    return (
      <div style={{ minHeight: "100vh", display: "grid", placeItems: "center", background: "#05060f", color: "#9fb3c8", fontFamily: "system-ui" }}>
        <div style={{ textAlign: "center" }}>
          <h1 style={{ color: "#e8f0fb" }}>App nicht gefunden</h1>
          <p>Diese gebaute App existiert nicht (mehr) oder der Speicher ist nicht verbunden.</p>
          <a href="/workbench" style={{ color: "#2bd1fe" }}>← Neue App bauen</a>
        </div>
      </div>
    );
  }

  return (
    <div style={{ height: "100vh", display: "flex", flexDirection: "column", background: "#05060f" }}>
      <div style={{ display: "flex", alignItems: "center", gap: 12, padding: "8px 14px", borderBottom: "1px solid rgba(43,209,254,0.18)", color: "#cfe0f5", fontFamily: "system-ui", fontSize: 13 }}>
        <a href="/workbench" style={{ color: "#2bd1fe", textDecoration: "none" }}>← Workbench</a>
        <span style={{ opacity: 0.6 }}>Cloud Superbrain · gebaute App</span>
        <span style={{ marginLeft: "auto", opacity: 0.6, fontFamily: "monospace" }}>{clean.slice(0, 8)}</span>
      </div>
      <iframe
        title="app"
        srcDoc={html}
        sandbox="allow-scripts allow-pointer-lock allow-popups allow-modals"
        style={{ flex: 1, width: "100%", border: "none", background: "#0b1020" }}
      />
    </div>
  );
}

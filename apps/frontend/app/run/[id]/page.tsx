export const dynamic = "force-dynamic";

function safeId(value: string): string {
  return /^[A-Za-z0-9_-]{1,64}$/.test(value) ? value : "";
}

export default async function RunPage({ params }: { params: Promise<{ id: string }> }) {
  const clean = safeId((await params).id);
  return (
    <div style={{ minHeight: "100vh", display: "grid", placeItems: "center", background: "#05060f", color: "#9fb3c8", fontFamily: "system-ui" }}>
      <div style={{ maxWidth: 560, padding: 24, textAlign: "center" }}>
        <h1 style={{ color: "#e8f0fb" }}>App nicht verfügbar</h1>
        <p>Freigegebene Builds werden ausschließlich über das Agent-API-Artefaktregister geladen. Für diesen Build ist derzeit kein erreichbarer Eintrag vorhanden.</p>
        {clean ? <p style={{ fontFamily: "monospace", fontSize: 12, opacity: 0.7 }}>Build {clean.slice(0, 8)}</p> : null}
        <a href="/workbench" style={{ color: "#2bd1fe" }}>Zur Workbench</a>
      </div>
    </div>
  );
}

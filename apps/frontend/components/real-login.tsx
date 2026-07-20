"use client";

import { useEffect, useState } from "react";

type User = { name: string; provider: string } | null;

// Real session sign-in: creates a genuine persisted session + httpOnly cookie.
export function RealLogin() {
  const [user, setUser] = useState<User>(null);
  const [name, setName] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const r = await fetch("/api/v1/auth/session", { cache: "no-store" });
        const d = await r.json();
        if (alive && d.user) setUser(d.user);
      } catch {
        if (alive) setError("Sitzungsstatus ist momentan nicht erreichbar.");
      }
    })();
    return () => { alive = false; };
  }, []);

  async function signIn(provider: string) {
    if (busy) return;
    setBusy(true);
    setError("");
    try {
      const r = await fetch("/api/v1/auth/session", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ provider, name: name || undefined }),
      });
      const d = await r.json();
      if (!r.ok || !d.user) throw new Error("sign_in_failed");
      setUser(d.user);
    } catch {
      setError("Anmeldung konnte nicht abgeschlossen werden.");
    } finally { setBusy(false); }
  }

  async function signOut() {
    setBusy(true);
    setError("");
    try {
      const response = await fetch("/api/v1/auth/session", { method: "DELETE" });
      if (!response.ok) throw new Error("sign_out_failed");
      setUser(null);
    } catch {
      setError("Abmeldung konnte nicht abgeschlossen werden.");
    } finally { setBusy(false); }
  }

  if (user) {
    return (
      <div className="real-login" data-testid="real-login">
        <div className="rl-signed">✓ Angemeldet als <b>{user.name}</b> <span className="text-12 text-mut">({user.provider})</span></div>
        <div className="rl-row">
          <a href="/workbench" className="btn btn-primary btn-sm">In die Werkbank →</a>
          <button type="button" className="btn btn-sm" onClick={signOut} disabled={busy} data-testid="rl-signout">Abmelden</button>
        </div>
        {error ? <p className="text-12 status bad" role="alert">{error}</p> : null}
      </div>
    );
  }

  return (
    <div className="real-login" data-testid="real-login">
      <input
        className="rl-input"
        placeholder="Dein Name (optional)"
        value={name}
        onChange={(e) => setName(e.target.value)}
        onKeyDown={(e) => { if (e.key === "Enter") signIn(name ? "name" : "guest"); }}
        aria-label="Name"
        disabled={busy}
      />
      <div className="rl-row">
        <button type="button" className="btn btn-primary btn-sm" onClick={() => signIn(name ? "name" : "guest")} disabled={busy} data-testid="rl-signin">
          {busy ? "…" : name ? `Anmelden als ${name}` : "Als Gast fortfahren"}
        </button>
      </div>
      {error ? <p className="text-12 status bad" role="alert">{error}</p> : null}
      <p className="text-12 text-mut">Signierte HttpOnly-Sitzung ohne externe Schreibzugriffe. OAuth-Provider sind erst nach separater Freigabe aktiv.</p>
    </div>
  );
}

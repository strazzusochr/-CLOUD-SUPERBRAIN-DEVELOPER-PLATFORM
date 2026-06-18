"use client";

import { useEffect, useState } from "react";

type User = { name: string; provider: string } | null;

// Real session sign-in: creates a genuine persisted session + httpOnly cookie.
export function RealLogin() {
  const [user, setUser] = useState<User>(null);
  const [name, setName] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const r = await fetch("/api/v1/auth/session", { cache: "no-store" });
        const d = await r.json();
        if (alive && d.user) setUser(d.user);
      } catch { /* ignore */ }
    })();
    return () => { alive = false; };
  }, []);

  async function signIn(provider: string) {
    if (busy) return;
    setBusy(true);
    try {
      const r = await fetch("/api/v1/auth/session", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ provider, name: name || undefined }),
      });
      const d = await r.json();
      if (d.user) setUser(d.user);
    } catch { /* ignore */ } finally { setBusy(false); }
  }

  async function signOut() {
    setBusy(true);
    try { await fetch("/api/v1/auth/session", { method: "DELETE" }); setUser(null); } finally { setBusy(false); }
  }

  if (user) {
    return (
      <div className="real-login" data-testid="real-login">
        <div className="rl-signed">✓ Angemeldet als <b>{user.name}</b> <span className="text-12 text-mut">({user.provider})</span></div>
        <div className="rl-row">
          <a href="/workbench" className="btn btn-primary btn-sm">In die Werkbank →</a>
          <button type="button" className="btn btn-sm" onClick={signOut} disabled={busy} data-testid="rl-signout">Abmelden</button>
        </div>
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
      <p className="text-12 text-mut">Echte Sitzung (Cookie + persistiert). Externe OAuth-Provider brauchen eine OAuth-App und sind in diesem freien Stack nicht aktiv.</p>
    </div>
  );
}

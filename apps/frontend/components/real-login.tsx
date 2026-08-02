"use client";

import { useEffect, useRef, useState } from "react";

type User = { name: string; provider: string } | null;

// Real session sign-in: creates a genuine persisted session + httpOnly cookie.
export function RealLogin() {
  const [user, setUser] = useState<User>(null);
  const [name, setName] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [oauthReady, setOauthReady] = useState(false);
  const rootRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    rootRef.current?.setAttribute("data-hydrated", "true");
    let alive = true;
    (async () => {
      let oauthBoundaryReady = false;
      try {
        const response = await fetch("/api/v1/auth/contract", { cache: "no-store" });
        const contract = await response.json();
        oauthBoundaryReady = (
          response.ok
          && contract?.credential_issuance_ready === true
          && contract?.owner_activation_granted === true
        );
      } catch {
        oauthBoundaryReady = false;
      }
      if (!alive) return;
      setOauthReady(oauthBoundaryReady);

      if (oauthBoundaryReady) {
        try {
          const identityResponse = await fetch("/api/v1/auth/me", { cache: "no-store" });
          const identity = await identityResponse.json().catch(() => null);
          if (
            alive
            && identityResponse.ok
            && identity?.status === "authenticated"
            && identity?.identity_verified === true
            && identity?.jwt_signature_verified === true
            && identity?.identity?.provider === "github"
            && Number.isInteger(identity?.identity?.provider_user_id)
            && identity.identity.provider_user_id > 0
          ) {
            setUser({ name: `GitHub #${identity.identity.provider_user_id}`, provider: "github" });
            return;
          }
        } catch {
          // The independent local signed session remains available without claiming OAuth identity.
        }
      }

      try {
        const sessionResponse = await fetch("/api/v1/auth/session", { cache: "no-store" });
        const session = await sessionResponse.json();
        if (alive && sessionResponse.ok && session.user) setUser(session.user);
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
      if (user?.provider === "github") {
        const response = await fetch("/api/v1/auth/logout", { method: "POST" });
        const payload = await response.json().catch(() => null);
        if (
          !response.ok
          || payload?.status !== "logged_out"
          || payload?.cookies_cleared !== true
          || payload?.active_refresh_token_absent !== true
          || payload?.audit_persisted !== true
        ) {
          throw new Error("oauth_sign_out_failed");
        }
        await fetch("/api/v1/auth/session", { method: "DELETE" }).catch(() => null);
      } else {
        const response = await fetch("/api/v1/auth/session", { method: "DELETE" });
        if (!response.ok) throw new Error("sign_out_failed");
      }
      setUser(null);
    } catch {
      setError("Abmeldung konnte nicht abgeschlossen werden.");
    } finally { setBusy(false); }
  }

  if (user) {
    return (
      <div ref={rootRef} className="real-login" data-testid="real-login">
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
    <div ref={rootRef} className="real-login" data-testid="real-login">
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
        <form action="/api/v1/auth/github" method="get">
          <button
            type="submit"
            className="btn btn-sm"
            aria-describedby="rl-oauth-note"
            data-testid="rl-github-signin"
            disabled={busy || !oauthReady}
          >
            Mit GitHub anmelden
          </button>
        </form>
      </div>
      {error ? <p className="text-12 status bad" role="alert">{error}</p> : null}
      <p id="rl-oauth-note" className="text-12 text-mut">Signierte HttpOnly-Sitzung ohne externe Schreibzugriffe. GitHub OAuth ist nur bei konfigurierter und Owner-freigegebener Auth-Grenze aktiv{oauthReady ? "." : "; aktuell gesperrt."}</p>
    </div>
  );
}

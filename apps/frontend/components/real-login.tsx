"use client";

import { useEffect, useRef, useState } from "react";

type User = { name: string; provider: string } | null;

function githubUser(payload: unknown): User {
  if (
    payload
    && typeof payload === "object"
    && "status" in payload
    && payload.status === "authenticated"
    && "identity_verified" in payload
    && payload.identity_verified === true
    && "jwt_signature_verified" in payload
    && payload.jwt_signature_verified === true
    && "identity" in payload
    && payload.identity
    && typeof payload.identity === "object"
    && "provider" in payload.identity
    && payload.identity.provider === "github"
    && "provider_user_id" in payload.identity
    && Number.isInteger(payload.identity.provider_user_id)
    && Number(payload.identity.provider_user_id) > 0
  ) {
    return { name: `GitHub #${payload.identity.provider_user_id}`, provider: "github" };
  }
  return null;
}

async function oauthIdentityWithRefresh(): Promise<User> {
  const identityResponse = await fetch("/api/v1/auth/me", { cache: "no-store" });
  const identity = await identityResponse.json().catch(() => null);
  if (identityResponse.ok) return githubUser(identity);
  if (identityResponse.status !== 401) return null;

  const refreshResponse = await fetch("/api/v1/auth/refresh", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: "{}",
    cache: "no-store",
  });
  const refresh = await refreshResponse.json().catch(() => null);
  if (
    !refreshResponse.ok
    || refresh?.status !== "rotated"
    || refresh?.access_token_issued !== true
    || refresh?.refresh_token_rotated !== true
    || refresh?.old_refresh_token_blacklisted !== true
    || refresh?.active_registry_verified !== true
    || refresh?.audit_persisted !== true
  ) {
    return null;
  }

  const retriedResponse = await fetch("/api/v1/auth/me", { cache: "no-store" });
  const retriedIdentity = await retriedResponse.json().catch(() => null);
  return retriedResponse.ok ? githubUser(retriedIdentity) : null;
}

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
          const githubIdentity = await oauthIdentityWithRefresh();
          if (alive && githubIdentity) {
            setUser(githubIdentity);
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
      const oauthApplicable = oauthReady || user?.provider === "github";
      const oauthRevoke = oauthApplicable
        ? (async () => {
            const response = await fetch("/api/v1/auth/logout", { method: "POST", cache: "no-store" });
            const payload = await response.json().catch(() => null);
            return response.ok
              && payload?.status === "logged_out"
              && payload?.cookies_cleared === true
              && payload?.active_refresh_token_absent === true
              && payload?.audit_persisted === true;
          })()
        : Promise.resolve(true);
      const localRevoke = (async () => {
        const response = await fetch("/api/v1/auth/session", { method: "DELETE", cache: "no-store" });
        const payload = await response.json().catch(() => null);
        return response.ok
          && payload?.status === "signed_out"
          && payload?.cookies_cleared === true;
      })();
      const [oauthRevoked, localRevoked] = await Promise.all([oauthRevoke, localRevoke]);
      if (!oauthRevoked || !localRevoked) throw new Error("session_revoke_incomplete");
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

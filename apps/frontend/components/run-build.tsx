"use client";

import { useEffect, useState } from "react";

type Build = {
  id: string;
  title: string;
  html: string;
  model?: string;
  persisted?: boolean;
  direct_provider_calls?: boolean;
  live_mcp_writes?: boolean;
  secret_output?: boolean;
};

const VALID_BUILD_ID = /^[A-Za-z0-9_-]{1,64}$/;

function isPersistedBuild(payload: Partial<Build>, id: string): payload is Build {
  return payload.persisted === true
    && payload.id === id
    && typeof payload.title === "string"
    && payload.title.trim().length > 0
    && typeof payload.html === "string"
    && /^\s*<!doctype html/i.test(payload.html)
    && /<\/html>\s*$/i.test(payload.html)
    && (payload.model === undefined || typeof payload.model === "string")
    && payload.direct_provider_calls === false
    && payload.live_mcp_writes === false
    && payload.secret_output === false;
}

export function RunBuild({ id }: { id: string }) {
  const [build, setBuild] = useState<Build | null>(null);
  const [failed, setFailed] = useState(!VALID_BUILD_ID.test(id));

  useEffect(() => {
    if (!VALID_BUILD_ID.test(id)) {
      setBuild(null);
      setFailed(true);
      return;
    }
    let active = true;
    setBuild(null);
    setFailed(false);
    (async () => {
      try {
        const response = await fetch(`/api/v1/build/${encodeURIComponent(id)}`, { cache: "no-store" });
        const payload = (await response.json()) as Partial<Build>;
        if (!response.ok || !isPersistedBuild(payload, id)) throw new Error("build unavailable");
        if (active) setBuild(payload);
      } catch {
        if (active) setFailed(true);
      }
    })();
    return () => { active = false; };
  }, [id]);

  if (build) {
    return (
      <main style={{ minHeight: "100vh", display: "grid", gridTemplateRows: "44px minmax(0, 1fr)", background: "#05060f", color: "#e8f0fb", fontFamily: "system-ui" }}>
        <header style={{ display: "flex", alignItems: "center", gap: 12, padding: "0 14px", borderBottom: "1px solid #253148", minWidth: 0 }}>
          <a href="/apps" style={{ color: "#2bd1fe", textDecoration: "none" }}>Apps</a>
          <strong style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{build.title}</strong>
          <span style={{ marginLeft: "auto", color: "#8aa0b8", fontFamily: "monospace", fontSize: 12 }}>{build.model?.replace("@cf/", "")}</span>
        </header>
        <iframe
          title={build.title}
          srcDoc={build.html}
          sandbox="allow-scripts allow-pointer-lock allow-popups allow-modals"
          referrerPolicy="no-referrer"
          style={{ width: "100%", height: "100%", border: 0, background: "#05060f" }}
          data-testid="persisted-build-frame"
        />
      </main>
    );
  }

  return (
    <main style={{ minHeight: "100vh", display: "grid", placeItems: "center", background: "#05060f", color: "#9fb3c8", fontFamily: "system-ui" }}>
      <div style={{ maxWidth: 560, padding: 24, textAlign: "center" }}>
        <h1 style={{ color: "#e8f0fb" }}>{failed ? "App nicht verfügbar" : "App wird geladen"}</h1>
        <p>{failed ? "Für diesen Build ist derzeit kein persistierter Agent-API-Eintrag erreichbar." : "Der persistierte Build wird aus dem Agent-API-Register geladen."}</p>
        {id ? <p style={{ fontFamily: "monospace", fontSize: 12, opacity: 0.7 }}>Build {id.slice(0, 8)}</p> : null}
        <a href={failed ? "/workbench" : "/apps"} style={{ color: "#2bd1fe" }}>{failed ? "Zur Workbench" : "Zu meinen Apps"}</a>
      </div>
    </main>
  );
}

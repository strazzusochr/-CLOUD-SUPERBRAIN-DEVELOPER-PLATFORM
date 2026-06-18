"use client";

import { useEffect, useState } from "react";

type Build = { id: string; title: string; prompt?: string; model?: string; created_at?: string };

// "Meine Apps" — every app built on the platform, persisted and re-openable.
export function BuildsGallery() {
  const [builds, setBuilds] = useState<Build[] | null>(null);

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const res = await fetch("/api/v1/builds?limit=24", { cache: "no-store" });
        const body = await res.json();
        if (alive) setBuilds(Array.isArray(body.builds) ? body.builds : []);
      } catch {
        if (alive) setBuilds([]);
      }
    })();
    return () => { alive = false; };
  }, []);

  if (builds === null) return <div className="text-13 text-mut wb-pad">Lädt…</div>;
  if (!builds.length) return <div className="text-13 text-mut wb-pad">Noch keine Apps gebaut — oben beschreiben und „Bauen“.</div>;

  return (
    <div className="builds-gallery" data-testid="builds-gallery">
      {builds.map((b) => (
        <a key={b.id} className="bg-card" href={`/run/${b.id}`} target="_blank" rel="noopener noreferrer">
          <span className="bg-title">{b.title || "App"}</span>
          {b.model ? <span className="bg-model mono">{String(b.model).replace("@cf/", "")}</span> : null}
          <span className="bg-open">▶ Öffnen</span>
        </a>
      ))}
    </div>
  );
}

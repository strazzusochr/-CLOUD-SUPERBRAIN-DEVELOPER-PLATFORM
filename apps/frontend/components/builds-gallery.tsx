"use client";

import { useEffect, useState } from "react";

type Build = { id: string; title: string; prompt?: string; model?: string; created_at?: string };

// Curated card data derived ONLY from real build fields (no fabrication):
// cleaned title, full prompt as tooltip, readable date, duplicate-prompt grouping.
type CardBuild = Build & { cleanTitle: string; dateLabel: string | null; olderVersions: number };

function cleanTitle(raw: string | undefined): string {
  const first = (raw ?? "").trim().split(/\r?\n/)[0].trim();
  if (!first) return "App";
  if (first.length <= 64) return first;
  const cut = first.slice(0, 64);
  const atWord = cut.lastIndexOf(" ") > 40 ? cut.slice(0, cut.lastIndexOf(" ")) : cut;
  return `${atWord.trimEnd()}…`;
}

function dateLabel(iso: string | undefined): string | null {
  if (!iso) return null;
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return null;
  return d.toLocaleDateString("de-DE", { day: "2-digit", month: "2-digit", year: "numeric" });
}

// Group builds that share the same prompt text: keep the newest card and count
// the rest as older versions (the API returns newest first).
function curate(builds: Build[]): CardBuild[] {
  const seen = new Map<string, CardBuild>();
  const order: CardBuild[] = [];
  for (const b of builds) {
    const key = (b.prompt ?? b.title ?? b.id).trim().toLowerCase();
    const existing = seen.get(key);
    if (existing) {
      existing.olderVersions += 1;
      continue;
    }
    const card: CardBuild = { ...b, cleanTitle: cleanTitle(b.title || b.prompt), dateLabel: dateLabel(b.created_at), olderVersions: 0 };
    seen.set(key, card);
    order.push(card);
  }
  return order;
}

// "Meine Apps" — persisted builds returned by the Agent API registry.
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

  async function remove(id: string) {
    if (!confirm("Diese App wirklich löschen?")) return;
    setBuilds((prev) => (prev ? prev.filter((b) => b.id !== id) : prev));
    try { await fetch(`/api/v1/build/${id}`, { method: "DELETE" }); } catch { /* ignore */ }
  }

  if (builds === null) return <div className="text-13 text-mut wb-pad">Lädt…</div>;
  if (!builds.length) return <div className="text-13 text-mut wb-pad">Noch keine Apps gebaut — oben beschreiben und „Bauen“.</div>;

  const cards = curate(builds);

  return (
    <div className="builds-gallery" data-testid="builds-gallery">
      {cards.map((b) => (
        <div key={b.id} className="bg-card" title={b.prompt || b.title}>
          <span className="bg-title">{b.cleanTitle}</span>
          <span className="bg-meta mono">
            {b.model ? <span className="bg-model">{String(b.model).replace("@cf/", "")}</span> : null}
            {b.dateLabel ? <span className="bg-date">{b.dateLabel}</span> : null}
            {b.olderVersions > 0 ? <span className="bg-versions" title={`${b.olderVersions} ältere Version(en) mit gleichem Prompt`}>+{b.olderVersions} Versionen</span> : null}
          </span>
          <span className="bg-links">
            <a className="bg-open" href={`/run/${b.id}`} target="_blank" rel="noopener noreferrer">▶ Öffnen</a>
            <a className="bg-edit" href={`/workbench?build=${b.id}`}>✎ Bearbeiten</a>
            <button type="button" className="bg-del" onClick={() => remove(b.id)} title="Löschen">🗑</button>
          </span>
        </div>
      ))}
    </div>
  );
}

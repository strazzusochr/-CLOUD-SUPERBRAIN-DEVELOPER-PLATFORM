"use client";

import { useEffect, useState } from "react";

type Artifact = {
  id: string;
  title?: string;
  artifact_type?: string;
  created_at?: string;
  source_page?: string;
  status?: string;
};

// Registry-backed library: lists only artifacts returned by the Agent API.
// An unavailable or empty registry renders an honest empty state.
export function ArtifactLibrary({ types, emptyText, testId }: { types?: string[]; emptyText: string; testId: string }) {
  const [items, setItems] = useState<Artifact[] | null>(null);
  const typeFilterKey = (types ?? []).map((type) => type.toLowerCase()).sort().join("|");

  useEffect(() => {
    let alive = true;
    const allowedTypes = typeFilterKey ? new Set(typeFilterKey.split("|")) : null;
    (async () => {
      try {
        const res = await fetch("/api/v1/workspace/artifacts?project_id=default&limit=50", { cache: "no-store" });
        const body = await res.json();
        const all: Artifact[] = Array.isArray(body.artifacts) ? body.artifacts : [];
        const filtered = allowedTypes
          ? all.filter((a) => allowedTypes.has(String(a.artifact_type ?? "").toLowerCase()))
          : all;
        if (alive) setItems(filtered);
      } catch {
        if (alive) setItems([]);
      }
    })();
    return () => { alive = false; };
  }, [typeFilterKey]);

  if (items === null) return <div className="text-13 text-mut wb-pad">Lädt…</div>;
  if (!items.length) return <div className="text-13 text-mut wb-pad" data-testid={`${testId}-empty`}>{emptyText}</div>;

  return (
    <div className="artifact-library" data-testid={testId}>
      {items.map((a) => (
        <div key={a.id} className="al-row">
          <span className="al-type mono">{a.artifact_type ?? "artefakt"}</span>
          <span className="al-title">{a.title || a.id}</span>
          <span className="al-meta mono">
            {a.source_page ? <span>{a.source_page}</span> : null}
            {a.created_at ? <span>{new Date(a.created_at).toLocaleDateString("de-DE")}</span> : null}
            {a.status ? <span className="al-status">{a.status}</span> : null}
          </span>
        </div>
      ))}
    </div>
  );
}

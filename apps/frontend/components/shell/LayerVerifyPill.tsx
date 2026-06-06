"use client";

import { useEffect, useState } from "react";

type Verify = {
  live: boolean;
  verified: number;
  total: number;
  layers?: Array<{ label: string; verified: boolean }>;
};

/** Global "N/7 layers verified" pill shown in the shell topbar on every page.
 *  Projects GET /api/v1/platform/verify (→ runtime cloud-layer-readiness) live, or
 *  an honest "7 layers · spec" when the runtime is unreachable (e.g. on Vercel). */
export default function LayerVerifyPill() {
  const [v, setV] = useState<Verify | null>(null);

  useEffect(() => {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 2500);
    fetch("/api/v1/platform/verify", { cache: "no-store", signal: ctrl.signal })
      .then((r) => (r.ok ? r.json() : null))
      .then((d: Verify | null) => d && setV(d))
      .catch(() => {})
      .finally(() => clearTimeout(timer));
    return () => ctrl.abort();
  }, []);

  if (!v) return null;
  const allVerified = v.live && v.verified === v.total;
  const title = (v.layers ?? []).map((l) => `${l.label}: ${l.verified ? "verified" : "spec"}`).join(" · ");

  return (
    <span
      className={`verifypill ${allVerified ? "ok" : "spec"}`}
      title={title || "7-layer verification"}
      role="img"
      aria-label={v.live ? `${v.verified} of ${v.total} cloud layers verified` : "Seven layers, spec fallback"}
    >
      <span className="vp-dot" aria-hidden="true" />
      {v.live ? `${v.verified}/${v.total} layers verified` : "7 layers · spec"}
    </span>
  );
}

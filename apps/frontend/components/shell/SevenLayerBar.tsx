import { fetchLayers } from "../../lib/agentApi";
import { LAYERS } from "../organism/regionMap";
import { Badge } from "../ui";

/** Compact "verified across all 7 layers" strip. Projects the live
 *  cloud-layer-readiness contract (GET /api/v1/clouds/layers) when the runtime is
 *  reachable, else the static 7-layer architecture spec — always honestly labelled. */
export default async function SevenLayerBar({ title = "Verified across 7 cloud layers" }: { title?: string }) {
  const live = await fetchLayers();
  const rows = live
    ? live.map((l, i) => ({ no: i + 1, code: LAYERS[i]?.code ?? l.id, label: LAYERS[i]?.label ?? l.label, color: LAYERS[i]?.color ?? "#00e5ff", status: l.status, verified: l.verified }))
    : LAYERS.map((l) => ({ no: l.no, code: l.code, label: l.label, color: l.color, status: "spec", verified: false }));
  const verifiedCount = rows.filter((r) => r.verified).length;

  return (
    <section className="layerbar" aria-label={title}>
      <div className="layerbar-head">
        <span className="layerbar-title">{title}</span>
        {live ? (
          <Badge tone="green">● Live · {verifiedCount}/{rows.length} live_verified</Badge>
        ) : (
          <Badge tone="amber">spec · /api/v1/clouds/layers when reachable</Badge>
        )}
      </div>
      <div className="layerbar-row">
        {rows.map((r) => (
          <div key={r.no} className={`layerbar-cell${r.verified ? " on" : ""}`} title={`${r.label} — ${r.status}`}>
            <span className="layerbar-tag" style={{ background: r.color }}>L{r.no}</span>
            <span className="layerbar-code">{r.code}</span>
            <span className={`layerbar-dot ${r.verified ? "ok" : "spec"}`} aria-hidden="true" />
          </div>
        ))}
      </div>
    </section>
  );
}

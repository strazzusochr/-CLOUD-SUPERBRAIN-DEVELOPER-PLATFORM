"use client";

/*
 * Cloud Superbrain — Living Cortex (connective organism)
 *
 * Dependency-free pseudo-3D: a brain-shaped neural point cloud is rotated with
 * real 3x rotation math, projected with perspective, depth-sorted, and drawn to
 * a 2D canvas. Synapses connect near neighbours; signal pulses travel along them;
 * a glowing core + 10 labelled brain regions sit on top. Colours/animation are
 * driven by `runState` and `activeRegion` (data contract, never fake-live).
 *
 * Reduced motion → static 2D topology list (same data contract).
 * This is the in-repo runtime; the React-Three-Fiber variant (CortexCanvas3D)
 * is documented as the optional GPU path once the 3D packages are installed.
 */

import { useEffect, useMemo, useRef, useState } from "react";
import { REGIONS, STATE_COLOR, STATE_LABEL, type RunState } from "./regionMap";

type Vec3 = { x: number; y: number; z: number };

function seededUnit(seed: number) {
  const value = Math.sin(seed * 12.9898) * 43758.5453;
  return value - Math.floor(value);
}

function hexToRgb(hex: string): [number, number, number] {
  const n = parseInt(hex.replace("#", ""), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

function useBrain(nodeCount: number) {
  return useMemo(() => {
    const pts: Vec3[] = [];
    const colors: [number, number, number][] = [];
    const sizes: number[] = [];
    const cyan = hexToRgb("#00e5ff");
    const violet = hexToRgb("#8b5cf6");
    const golden = Math.PI * (3 - Math.sqrt(5));
    for (let i = 0; i < nodeCount; i++) {
      const y = 1 - (i / (nodeCount - 1)) * 2;
      const r = Math.sqrt(1 - y * y);
      const th = golden * i;
      let x = Math.cos(th) * r;
      let z = Math.sin(th) * r;
      let yy = y;
      x *= 1.15;
      yy *= 0.92;
      z *= 0.95;
      x += x > 0 ? 0.08 : -0.08; // hemisphere gap
      const noise = (Math.sin(x * 6) + Math.cos(z * 5) + Math.sin(yy * 7)) * 0.04;
      pts.push({ x: x * (1 + noise), y: yy * (1 + noise) + 0.12, z: z * (1 + noise) });
      const t = (yy + 1) / 2.2;
      colors.push([
        Math.round(cyan[0] + (violet[0] - cyan[0]) * t),
        Math.round(cyan[1] + (violet[1] - cyan[1]) * t),
        Math.round(cyan[2] + (violet[2] - cyan[2]) * t),
      ]);
      sizes.push(0.7 + ((i * 9301 + 49297) % 233280) / 233280);
    }
    // synapse segments to nearby neighbours (cap connections)
    const segs: [number, number][] = [];
    for (let i = 0; i < pts.length; i++) {
      let conn = 0;
      for (let j = i + 1; j < pts.length && conn < 3; j++) {
        const dx = pts[i].x - pts[j].x;
        const dy = pts[i].y - pts[j].y;
        const dz = pts[i].z - pts[j].z;
        if (dx * dx + dy * dy + dz * dz < 0.05) {
          segs.push([i, j]);
          conn++;
        }
      }
    }
    const pulses = Array.from({ length: 54 }, (_, i) => ({
      seg: Math.floor(seededUnit(i + 1) * Math.max(1, segs.length)),
      t: seededUnit(i + 101),
      speed: 0.4 + seededUnit(i + 201) * 0.8,
    }));
    return { pts, colors, sizes, segs, pulses };
  }, [nodeCount]);
}

export default function CortexCanvas({
  runState = "planning",
  nodeCount = 460,
  activeRegion,
  onSelectRegion,
  interactive = true,
  showRegions = true,
  sourceLabel = "SPEC · ORGANISM",
  className,
}: {
  runState?: RunState;
  nodeCount?: number;
  activeRegion?: string;
  onSelectRegion?: (id: string) => void;
  interactive?: boolean;
  showRegions?: boolean;
  sourceLabel?: string;
  className?: string;
}) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const wrapRef = useRef<HTMLDivElement>(null);
  const brain = useBrain(nodeCount);
  const [reduced, setReduced] = useState(() => typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches);
  const stateRef = useRef(runState);
  const activeRef = useRef(activeRegion);
  const hoverRef = useRef<string | null>(null);
  const regionScreen = useRef<{ id: string; x: number; y: number }[]>([]);

  useEffect(() => {
    stateRef.current = runState;
  }, [runState]);

  useEffect(() => {
    activeRef.current = activeRegion;
  }, [activeRegion]);

  useEffect(() => {
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    const on = () => setReduced(mq.matches);
    mq.addEventListener("change", on);
    return () => mq.removeEventListener("change", on);
  }, []);

  useEffect(() => {
    if (reduced) return;
    const canvas = canvasRef.current;
    const wrap = wrapRef.current;
    if (!canvas || !wrap) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    let dpr = Math.min(window.devicePixelRatio || 1, 2);
    let W = 0;
    let H = 0;
    const resize = () => {
      const rect = wrap.getBoundingClientRect();
      dpr = Math.min(window.devicePixelRatio || 1, 2);
      const newW = Math.max(1, rect.width);
      const newH = Math.max(1, rect.height);
      const bw = Math.floor(newW * dpr);
      const bh = Math.floor(newH * dpr);
      // Assigning canvas.width/height CLEARS the canvas. A ResizeObserver can
      // fire every frame (sub-pixel layout churn), so only touch the backing
      // store when the integer size truly changes — otherwise each rendered
      // frame gets wiped immediately and the cortex shows up blank. Sizing is
      // handled in CSS (absolute inset:0), so no inline style writes here.
      if (bw === canvas.width && bh === canvas.height) return;
      W = newW;
      H = newH;
      canvas.width = bw;
      canvas.height = bh;
    };
    resize();
    const ro = new ResizeObserver(resize);
    ro.observe(wrap);

    let raf = 0;
    let t0 = performance.now();
    let rot = 0;

    const projected = new Array(brain.pts.length).fill(null).map(() => ({ sx: 0, sy: 0, d: 0 }));

    const frame = (now: number) => {
      const dt = Math.min((now - t0) / 1000, 0.05);
      t0 = now;
      rot += dt * 0.18;
      const t = now / 1000;

      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, W, H);

      const cx = W / 2;
      const cy = H / 2;
      const scaleBase = Math.min(W, H) * 0.46;
      const camZ = 3.4;
      const tilt = -0.22;
      const cosT = Math.cos(tilt);
      const sinT = Math.sin(tilt);
      const cosR = Math.cos(rot);
      const sinR = Math.sin(rot);
      const col = hexToRgb(STATE_COLOR[stateRef.current]);

      const project = (p: Vec3) => {
        // rotate Y then tilt X
        const xr = p.x * cosR + p.z * sinR;
        let zr = -p.x * sinR + p.z * cosR;
        const yr = p.y * cosT - zr * sinT;
        zr = p.y * sinT + zr * cosT;
        const persp = scaleBase / (camZ - zr * 1.15);
        return { sx: cx + xr * persp, sy: cy - yr * persp, d: zr, persp };
      };

      for (let i = 0; i < brain.pts.length; i++) {
        const pr = project(brain.pts[i]);
        projected[i].sx = pr.sx;
        projected[i].sy = pr.sy;
        projected[i].d = pr.d;
      }

      // synapses (additive)
      ctx.globalCompositeOperation = "lighter";
      ctx.lineWidth = 1;
      for (let s = 0; s < brain.segs.length; s++) {
        const [a, b] = brain.segs[s];
        const pa = projected[a];
        const pb = projected[b];
        const depth = (pa.d + pb.d) / 2;
        const alpha = 0.05 + Math.max(0, depth + 1) * 0.07;
        const c = brain.colors[a];
        ctx.strokeStyle = `rgba(${c[0]},${c[1]},${c[2]},${alpha})`;
        ctx.beginPath();
        ctx.moveTo(pa.sx, pa.sy);
        ctx.lineTo(pb.sx, pb.sy);
        ctx.stroke();
      }

      // pulses
      for (let i = 0; i < brain.pulses.length; i++) {
        const pd = brain.pulses[i];
        pd.t += pd.speed * dt;
        if (pd.t > 1) {
          pd.t = 0;
          pd.seg = (pd.seg + 17 + i) % Math.max(1, brain.segs.length);
        }
        const seg = brain.segs[pd.seg];
        if (!seg) continue;
        const pa = projected[seg[0]];
        const pb = projected[seg[1]];
        const x = pa.sx + (pb.sx - pa.sx) * pd.t;
        const y = pa.sy + (pb.sy - pa.sy) * pd.t;
        ctx.fillStyle = `rgba(${col[0]},${col[1]},${col[2]},0.95)`;
        ctx.beginPath();
        ctx.arc(x, y, 1.7, 0, Math.PI * 2);
        ctx.fill();
      }

      // nodes — depth sorted back-to-front
      const order = projected.map((_, i) => i).sort((i, j) => projected[i].d - projected[j].d);
      for (const i of order) {
        const p = projected[i];
        const c = brain.colors[i];
        const alpha = 0.35 + Math.max(0, p.d + 1) * 0.4;
        ctx.fillStyle = `rgba(${c[0]},${c[1]},${c[2]},${alpha})`;
        ctx.beginPath();
        ctx.arc(p.sx, p.sy, brain.sizes[i] * 1.3, 0, Math.PI * 2);
        ctx.fill();
      }

      // glowing core
      const pulseScale = 1 + Math.sin(t * 2) * 0.12;
      const coreR = scaleBase * 0.14 * pulseScale;
      const grad = ctx.createRadialGradient(cx, cy + 6, 0, cx, cy + 6, coreR * 2.4);
      grad.addColorStop(0, `rgba(${col[0]},${col[1]},${col[2]},0.55)`);
      grad.addColorStop(0.4, `rgba(${col[0]},${col[1]},${col[2]},0.16)`);
      grad.addColorStop(1, "rgba(0,0,0,0)");
      ctx.fillStyle = grad;
      ctx.beginPath();
      ctx.arc(cx, cy + 6, coreR * 2.4, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "rgba(255,255,255,0.92)";
      ctx.beginPath();
      ctx.arc(cx, cy + 6, coreR * 0.5, 0, Math.PI * 2);
      ctx.fill();

      // regions
      regionScreen.current = [];
      ctx.globalCompositeOperation = "source-over";
      if (showRegions) {
        for (const rg of REGIONS) {
          const pr = project({ x: rg.pos[0], y: rg.pos[1] + 0.1, z: rg.pos[2] });
          regionScreen.current.push({ id: rg.id, x: pr.sx, y: pr.sy });
          const isActive = activeRef.current === rg.id || hoverRef.current === rg.id;
          const rc = hexToRgb(rg.color);
          const ringR = isActive ? 8 + Math.sin(t * 4) * 2 : 5;
          ctx.fillStyle = `rgba(${rc[0]},${rc[1]},${rc[2]},${isActive ? 0.35 : 0.18})`;
          ctx.beginPath();
          ctx.arc(pr.sx, pr.sy, ringR + 6, 0, Math.PI * 2);
          ctx.fill();
          ctx.fillStyle = rg.color;
          ctx.beginPath();
          ctx.arc(pr.sx, pr.sy, isActive ? 4.5 : 3.2, 0, Math.PI * 2);
          ctx.fill();
          if (isActive) {
            ctx.font = "600 11px Inter, system-ui, sans-serif";
            const label = rg.name;
            const tw = ctx.measureText(label).width;
            const bx = pr.sx - tw / 2 - 7;
            const by = pr.sy - 30;
            ctx.fillStyle = "rgba(11,16,32,0.92)";
            ctx.strokeStyle = `rgba(${rc[0]},${rc[1]},${rc[2]},0.5)`;
            ctx.lineWidth = 1;
            const rr = 6;
            const bw = tw + 14;
            const bh = 20;
            ctx.beginPath();
            ctx.moveTo(bx + rr, by);
            ctx.arcTo(bx + bw, by, bx + bw, by + bh, rr);
            ctx.arcTo(bx + bw, by + bh, bx, by + bh, rr);
            ctx.arcTo(bx, by + bh, bx, by, rr);
            ctx.arcTo(bx, by, bx + bw, by, rr);
            ctx.fill();
            ctx.stroke();
            ctx.fillStyle = "#eaf2ff";
            ctx.textBaseline = "middle";
            ctx.fillText(label, pr.sx - tw / 2, by + bh / 2 + 0.5);
          }
        }
      }

      raf = requestAnimationFrame(frame);
    };
    raf = requestAnimationFrame(frame);

    return () => {
      cancelAnimationFrame(raf);
      ro.disconnect();
    };
  }, [brain, reduced, showRegions]);

  const handlePointer = (e: React.PointerEvent) => {
    if (!interactive || !onSelectRegion) return;
    const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
    const mx = e.clientX - rect.left;
    const my = e.clientY - rect.top;
    let best: { id: string; dist: number } | null = null;
    for (const r of regionScreen.current) {
      const d = Math.hypot(r.x - mx, r.y - my);
      if (d < 18 && (!best || d < best.dist)) best = { id: r.id, dist: d };
    }
    if (best) onSelectRegion(best.id);
  };

  const handleMove = (e: React.PointerEvent) => {
    if (!interactive) return;
    const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
    const mx = e.clientX - rect.left;
    const my = e.clientY - rect.top;
    let best: { id: string; dist: number } | null = null;
    for (const r of regionScreen.current) {
      const d = Math.hypot(r.x - mx, r.y - my);
      if (d < 18 && (!best || d < best.dist)) best = { id: r.id, dist: d };
    }
    hoverRef.current = best ? best.id : null;
  };

  if (reduced) {
    return (
      <div ref={wrapRef} className={`cortex-wrap ${className ?? ""}`}>
        <span className="cortex-badge">{sourceLabel} · REDUCED MOTION</span>
        <div className="cortex-fallback cortex-fallback-stretch">
          <ul className="cortex-fallback-list">
            {REGIONS.map((rg) => (
              <li key={rg.id}>
                <button
                  type="button"
                  className={`lg-row${activeRegion === rg.id ? " active" : ""}`}
                  disabled={!interactive || !onSelectRegion}
                  onClick={() => onSelectRegion?.(rg.id)}
                >
                  <span className={`lg-dot rg-${rg.id}`} />
                  <strong>{rg.name}</strong>
                  <span className="lg-cap ml-auto">{rg.cap}</span>
                </button>
              </li>
            ))}
          </ul>
        </div>
      </div>
    );
  }

  return (
    <div ref={wrapRef} className={`cortex-wrap ${className ?? ""}`}>
      <canvas
        ref={canvasRef}
        className={`cortex-canvas${interactive ? " interactive" : ""}`}
        onPointerDown={handlePointer}
        onPointerMove={handleMove}
        role="img"
        aria-label={`Living cortex organism, run state ${runState}`}
      />
      <span className="cortex-badge">{sourceLabel}</span>
      <span className="cortex-state">
        <span className={`dot dot-state-${runState}`} />
        {STATE_LABEL[runState]}
      </span>
    </div>
  );
}

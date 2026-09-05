"use client";

import { useCallback, useRef, useState } from "react";

// GPU-load watchdog for the platform's 3D game runtime.
//
// Any 3D game built/previewed/run ON the platform should call `sample(now)` once
// per frame. The guard tracks the real frame interval and, when the machine is
// clearly struggling to keep up (the GPU is pinned and can't hit the target),
// it escalates: throttles the recommended FPS cap down and raises a visible
// warning level. This is the safety net that stops a heavy or poorly-built game
// from silently burning a normal graphics card — the exact failure the platform
// must never inflict on a developer or player.
//
// Levels: "ok" → normal. "warn" → sustained heavy load, auto-throttled to 30.
// "critical" → still overloaded at 30; throttle to 20 and tell the user to stop.

export type GpuLoadLevel = "ok" | "warn" | "critical";

export type GpuGuard = {
  /** Call once per rendered frame with the measured frame WORK time in ms
   *  (time spent updating + rendering). Returns the FPS cap to honor. */
  sample: (frameMs: number) => number;
  level: GpuLoadLevel;
  fps: number;
  /** Max sustainable FPS implied by measured work time, for display. */
  measuredFps: number;
  reset: () => void;
};

const WINDOW = 60; // frames of history

export function useGpuGuard(targetFps = 60): GpuGuard {
  const [level, setLevel] = useState<GpuLoadLevel>("ok");
  const [fps, setFps] = useState(targetFps);
  const [measuredFps, setMeasuredFps] = useState(targetFps);

  const samples = useRef<number[]>([]);
  const capRef = useRef(targetFps);

  const reset = useCallback(() => {
    samples.current = [];
    capRef.current = targetFps;
    setLevel("ok");
    setFps(targetFps);
    setMeasuredFps(targetFps);
  }, [targetFps]);

  const sample = useCallback((frameMs: number): number => {
    if (frameMs > 0 && frameMs < 1000) {
      const arr = samples.current;
      arr.push(frameMs);
      if (arr.length > WINDOW) arr.shift();
    }

    const arr = samples.current;
    if (arr.length >= WINDOW) {
      // median frame work time (robust to spikes) → max sustainable FPS
      const sorted = [...arr].sort((a, b) => a - b);
      const median = sorted[Math.floor(sorted.length / 2)] || 1;
      const realFps = Math.round(1000 / median);
      setMeasuredFps(realFps);

      // Decide escalation against the *current* cap: if the machine can't even
      // sustain the cap, the GPU is the bottleneck → throttle + warn.
      const cap = capRef.current;
      const struggling = realFps < cap - 6; // missing the cap by a clear margin
      if (struggling) {
        if (cap > 30) {
          capRef.current = 30;
          setFps(30);
          setLevel("warn");
        } else if (cap > 20 && realFps < 24) {
          capRef.current = 20;
          setFps(20);
          setLevel("critical");
        }
        samples.current = []; // re-measure under the new cap before escalating again
      }
    }
    return capRef.current;
  }, []);

  return { sample, level, fps, measuredFps, reset };
}

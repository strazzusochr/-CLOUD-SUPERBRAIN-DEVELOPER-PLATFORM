"use client";

import { useEffect, useRef, useState, type RefObject } from "react";

// GPU-safety gate for any continuous canvas/3D render loop.
// Returns `active` = true only when the tab is visible AND the target element is
// in the viewport. Used to stop rendering (and stop hammering the GPU/fans) when
// the user isn't actually looking at the scene — e.g. background tab or scrolled
// away. Prevents the "fans scream / GPU pinned at 100% on a page I'm not viewing"
// problem. Combine with a frame-rate cap for full safety.
export function useRenderActive(ref: RefObject<HTMLElement | null>): boolean {
  const [visible, setVisible] = useState(true);
  const [onScreen, setOnScreen] = useState(true);
  const reduceRef = useRef(false);

  useEffect(() => {
    const onVis = () => setVisible(!document.hidden);
    onVis();
    document.addEventListener("visibilitychange", onVis);
    return () => document.removeEventListener("visibilitychange", onVis);
  }, []);

  useEffect(() => {
    const el = ref.current;
    if (!el || typeof IntersectionObserver === "undefined") return;
    const io = new IntersectionObserver(
      (entries) => setOnScreen(entries.some((e) => e.isIntersecting)),
      { threshold: 0.01 },
    );
    io.observe(el);
    return () => io.disconnect();
  }, [ref]);

  // Hard pause also when the OS/browser signals reduced data/motion at runtime.
  useEffect(() => {
    if (typeof window === "undefined" || !window.matchMedia) return;
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    reduceRef.current = mq.matches;
  }, []);

  return visible && onScreen;
}

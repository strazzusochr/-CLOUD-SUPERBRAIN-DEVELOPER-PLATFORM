"use client";

import { useEffect, useRef, useState } from "react";
import * as THREE from "three";
import { useGpuGuard } from "../lib/useGpuGuard";

// A real, playable in-browser 3D game — no backend, no LLM, no network.
// Top-down neon arena: move the orb with WASD / arrow keys, collect the glowing
// pickups before the timer runs out. Genuine three.js runtime: scene, lighting,
// per-frame physics, collision, scoring, win/lose. This is an actually-executable
// action surfaced on the /games page, not a spec placeholder.

type Phase = "idle" | "playing" | "over";

const ARENA = 18; // half-extent of the play field
const PLAYER_R = 0.8;
const ORB_R = 0.55;
const GAME_SECONDS = 45;

export function RealGame() {
  const mountRef = useRef<HTMLDivElement | null>(null);
  const [phase, setPhase] = useState<Phase>("idle");
  const [score, setScore] = useState(0);
  const [time, setTime] = useState(GAME_SECONDS);
  const [best, setBest] = useState(0);
  // GPU-load watchdog: auto-throttles + warns if a game overloads the graphics card.
  const guard = useGpuGuard(30);

  // Mutable game state shared with the animation loop (avoids re-renders per frame).
  const api = useRef<{ start: () => void; stop: () => void } | null>(null);
  // phaseRef mirrors `phase` for the rAF loop; updated in start()/game-over, not during render.
  const phaseRef = useRef<Phase>("idle");

  useEffect(() => {
    // Defer out of the synchronous effect body (lint: no set-state-in-effect)
    queueMicrotask(() => {
      try {
        setBest(Number(localStorage.getItem("superbrain-game-best") || "0"));
      } catch {}
    });
  }, []);

  useEffect(() => {
    const mount = mountRef.current;
    if (!mount) return;

    const width = mount.clientWidth || 640;
    const height = 380;

    let renderer: THREE.WebGLRenderer;
    try {
      // GPU-safety: prefer the low-power GPU so a normal/integrated card is not
      // pushed onto the discrete GPU at full tilt.
      renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: "low-power" });
    } catch {
      return; // no WebGL — the page still works, the game just won't mount
    }
    renderer.setSize(width, height);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    mount.appendChild(renderer.domElement);
    renderer.domElement.style.borderRadius = "12px";
    renderer.domElement.style.display = "block";

    const scene = new THREE.Scene();
    scene.fog = new THREE.FogExp2(0x05060f, 0.018);

    const camera = new THREE.PerspectiveCamera(55, width / height, 0.1, 200);
    camera.position.set(0, 26, 18);
    camera.lookAt(0, 0, 0);

    scene.add(new THREE.AmbientLight(0x335577, 1.2));
    const key = new THREE.PointLight(0x66e0ff, 1.6, 120);
    key.position.set(0, 30, 10);
    scene.add(key);

    // Floor grid
    const grid = new THREE.GridHelper(ARENA * 2, 24, 0x2bd1fe, 0x16304a);
    (grid.material as THREE.Material).transparent = true;
    (grid.material as THREE.Material).opacity = 0.5;
    scene.add(grid);

    const floor = new THREE.Mesh(
      new THREE.PlaneGeometry(ARENA * 2, ARENA * 2),
      new THREE.MeshStandardMaterial({ color: 0x070a16, roughness: 0.9, metalness: 0.1 }),
    );
    floor.rotation.x = -Math.PI / 2;
    floor.position.y = -0.01;
    scene.add(floor);

    // Player
    const player = new THREE.Mesh(
      new THREE.SphereGeometry(PLAYER_R, 32, 32),
      new THREE.MeshStandardMaterial({ color: 0x9b6bff, emissive: 0x5a2bff, emissiveIntensity: 0.7, roughness: 0.3 }),
    );
    player.position.set(0, PLAYER_R, 0);
    scene.add(player);
    const trail = new THREE.PointLight(0x9b6bff, 1.1, 14);
    scene.add(trail);

    // Orb (pickup)
    const orb = new THREE.Mesh(
      new THREE.IcosahedronGeometry(ORB_R, 1),
      new THREE.MeshStandardMaterial({ color: 0x37f5b5, emissive: 0x10c98a, emissiveIntensity: 1.1, roughness: 0.2 }),
    );
    scene.add(orb);

    const placeOrb = () => {
      orb.position.set((Math.random() * 2 - 1) * (ARENA - 2), ORB_R, (Math.random() * 2 - 1) * (ARENA - 2));
    };
    placeOrb();

    const keys: Record<string, boolean> = {};
    const onDown = (e: KeyboardEvent) => {
      if (["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", " "].includes(e.key)) e.preventDefault();
      keys[e.key.toLowerCase()] = true;
    };
    const onUp = (e: KeyboardEvent) => { keys[e.key.toLowerCase()] = false; };

    const vel = new THREE.Vector3();
    const sampleLoad = guard.sample;
    let capFps = 30;
    let raf = 0;
    let last = performance.now();
    let countdown = GAME_SECONDS;
    let localScore = 0;
    let acc = 0;

    const reset = () => {
      player.position.set(0, PLAYER_R, 0);
      vel.set(0, 0, 0);
      countdown = GAME_SECONDS;
      localScore = 0;
      acc = 0;
      placeOrb();
      setScore(0);
      setTime(GAME_SECONDS);
    };

    const loop = () => {
      raf = requestAnimationFrame(loop);
      const now = performance.now();
      // GPU-safety: pause in a hidden/background tab; honor the watchdog's adaptive
      // FPS cap (drops to 30→20 if the GPU can't keep up) instead of a fixed rate.
      if (document.hidden || now - last < 1000 / capFps) return;
      const dt = Math.min((now - last) / 1000, 0.05);
      last = now;
      const workStart = now;

      const playing = phaseRef.current === "playing";

      // Input → acceleration
      const accel = 46;
      if (playing) {
        if (keys["w"] || keys["arrowup"]) vel.z -= accel * dt;
        if (keys["s"] || keys["arrowdown"]) vel.z += accel * dt;
        if (keys["a"] || keys["arrowleft"]) vel.x -= accel * dt;
        if (keys["d"] || keys["arrowright"]) vel.x += accel * dt;
      }
      vel.multiplyScalar(0.9); // friction
      player.position.x += vel.x * dt;
      player.position.z += vel.z * dt;

      // Walls
      const lim = ARENA - PLAYER_R;
      player.position.x = Math.max(-lim, Math.min(lim, player.position.x));
      player.position.z = Math.max(-lim, Math.min(lim, player.position.z));
      player.position.y = PLAYER_R + Math.sin(now / 200) * 0.08;
      trail.position.copy(player.position);

      // Orb animation + collision
      orb.rotation.y += dt * 1.6;
      orb.rotation.x += dt * 0.8;
      orb.position.y = ORB_R + Math.sin(now / 260) * 0.25;
      if (playing && player.position.distanceTo(orb.position) < PLAYER_R + ORB_R) {
        localScore += 1;
        setScore(localScore);
        placeOrb();
        key.color.setHex(0x37f5b5);
        setTimeout(() => key.color.setHex(0x66e0ff), 90);
      }

      // Timer
      if (playing) {
        acc += dt;
        if (acc >= 1) {
          acc -= 1;
          countdown -= 1;
          setTime(Math.max(0, countdown));
          if (countdown <= 0) {
            phaseRef.current = "over";
            setPhase("over");
            try {
              const prevBest = Number(localStorage.getItem("superbrain-game-best") || "0");
              if (localScore > prevBest) {
                localStorage.setItem("superbrain-game-best", String(localScore));
                setBest(localScore);
              }
            } catch {}
          }
        }
      }

      camera.position.lerp(new THREE.Vector3(player.position.x * 0.4, 26, player.position.z * 0.4 + 18), 0.05);
      camera.lookAt(player.position.x * 0.3, 0, player.position.z * 0.3);
      renderer.render(scene, camera);
      // Measure this frame's work time and let the watchdog adapt the cap.
      capFps = sampleLoad(performance.now() - workStart);
    };

    window.addEventListener("keydown", onDown);
    window.addEventListener("keyup", onUp);
    const onResize = () => {
      const w = mount.clientWidth || width;
      renderer.setSize(w, height);
      camera.aspect = w / height;
      camera.updateProjectionMatrix();
    };
    window.addEventListener("resize", onResize);

    api.current = { start: reset, stop: () => {} };
    loop();

    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener("keydown", onDown);
      window.removeEventListener("keyup", onUp);
      window.removeEventListener("resize", onResize);
      renderer.dispose();
      if (renderer.domElement.parentNode === mount) mount.removeChild(renderer.domElement);
    };
  }, []);

  const start = () => {
    guard.reset();
    api.current?.start();
    phaseRef.current = "playing";
    setPhase("playing");
  };

  const stop = () => {
    phaseRef.current = "over";
    setPhase("over");
  };

  return (
    <div className="real-game" data-testid="real-game">
      <div className="rg-hud mono">
        <span>Score <b data-testid="rg-score">{score}</b></span>
        <span>Zeit <b>{time}s</b></span>
        <span>Best <b>{best}</b></span>
        <span className="rg-state">{phase === "playing" ? "● läuft" : phase === "over" ? "Game Over" : "bereit"}</span>
      </div>
      {guard.level !== "ok" ? (
        <div className={`rg-gpuwarn rg-gpuwarn-${guard.level}`} role="alert" data-testid="rg-gpuwarn">
          <span>
            ⚠ Hohe GPU-Last erkannt (~{guard.measuredFps} FPS möglich) — automatisch auf {guard.fps} FPS gedrosselt, um deine Grafikkarte zu schützen.
            {guard.level === "critical" ? " Empfehlung: Spiel stoppen." : ""}
          </span>
          <button type="button" className="btn btn-sm" onClick={stop} data-testid="rg-gpustop">■ Stoppen</button>
        </div>
      ) : null}
      <div ref={mountRef} className="rg-canvas" />
      <div className="rg-controls">
        <button type="button" className="btn btn-sm btn-primary" onClick={start} data-testid="rg-start">
          {phase === "idle" ? "▶ Spiel starten" : phase === "over" ? "↻ Nochmal" : "↻ Neustart"}
        </button>
        <span className="rg-hint text-12 text-mut">Steuerung: WASD / Pfeiltasten · sammle die grünen Orbs · 3D läuft auf deiner GPU (30 FPS-Limit, pausiert im Hintergrund)</span>
      </div>
    </div>
  );
}

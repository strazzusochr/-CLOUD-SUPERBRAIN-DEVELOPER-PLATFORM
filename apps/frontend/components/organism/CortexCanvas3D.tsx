"use client";

/*
 * Cloud Superbrain — Collective Organism (industrial GPU path, R3F + three.js).
 *
 * Glowing neural brain at the centre (multi-layer additive particle cloud) with
 * a PBR core mesh (GLB asset slot, procedural fallback) and 8 capability hubs
 * orbiting it. Hubs are PBR nodes (emissive + metalness) lit by a procedural
 * HDR-style environment (Lightformers, no external file), connected by glowing
 * tubes with data pulses. Post: Bloom + Vignette + Depth-of-Field. Layer/agent
 * filters hide hubs; an FPS/particle HUD reports via onStats. Data-driven by
 * runState / activeRegion. CortexCanvas (2D) is the reduced-motion fallback.
 */

import { useMemo, useRef, useState, useEffect } from "react";
import { Canvas, useFrame, type ThreeEvent } from "@react-three/fiber";
import { OrbitControls, Html } from "@react-three/drei";
import { EffectComposer, Bloom, Vignette } from "@react-three/postprocessing";
import * as THREE from "three";
import { HUBS, STATE_COLOR, STATE_LABEL, type RunState } from "./regionMap";

function useGlow() {
  return useMemo(() => {
    const s = 128;
    const c = document.createElement("canvas");
    c.width = c.height = s;
    const ctx = c.getContext("2d");
    if (ctx) {
      const g = ctx.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2);
      g.addColorStop(0, "rgba(255,255,255,1)");
      g.addColorStop(0.25, "rgba(255,255,255,0.55)");
      g.addColorStop(0.55, "rgba(255,255,255,0.14)");
      g.addColorStop(1, "rgba(255,255,255,0)");
      ctx.fillStyle = g;
      ctx.fillRect(0, 0, s, s);
    }
    const t = new THREE.CanvasTexture(c);
    t.needsUpdate = true;
    return t;
  }, []);
}

function useBrain(count: number) {
  return useMemo(() => {
    const pos = new Float32Array(count * 3);
    const col = new Float32Array(count * 3);
    const cyan = new THREE.Color("#00e5ff");
    const violet = new THREE.Color("#8b5cf6");
    const magenta = new THREE.Color("#ec4899");
    const tmp = new THREE.Color();
    const golden = Math.PI * (3 - Math.sqrt(5));
    for (let i = 0; i < count; i++) {
      const y = 1 - (i / (count - 1)) * 2;
      const r = Math.sqrt(Math.max(0, 1 - y * y));
      const th = golden * i;
      const rad = 0.66 + 0.34 * Math.sqrt(Math.random());
      let x = Math.cos(th) * r * rad * 1.28;
      const z = Math.sin(th) * r * rad * 0.96;
      const yy = y * rad * 0.96;
      x += x > 0 ? 0.08 : -0.08;
      const n = (Math.sin(x * 5) + Math.cos(z * 4) + Math.sin(yy * 6)) * 0.03;
      pos[i * 3] = x * (1 + n);
      pos[i * 3 + 1] = yy * (1 + n);
      pos[i * 3 + 2] = z * (1 + n);
      const cc = (yy + 1) / 2;
      if (cc < 0.5) tmp.copy(cyan).lerp(violet, cc * 2);
      else tmp.copy(violet).lerp(magenta, (cc - 0.5) * 2);
      col[i * 3] = tmp.r;
      col[i * 3 + 1] = tmp.g;
      col[i * 3 + 2] = tmp.b;
    }
    const line: number[] = [];
    for (let i = 0; i < count; i++) {
      let conn = 0;
      for (let j = i + 1; j < count && conn < 2; j++) {
        const dx = pos[i * 3] - pos[j * 3];
        const dy = pos[i * 3 + 1] - pos[j * 3 + 1];
        const dz = pos[i * 3 + 2] - pos[j * 3 + 2];
        if (dx * dx + dy * dy + dz * dz < 0.035) {
          line.push(pos[i * 3], pos[i * 3 + 1], pos[i * 3 + 2], pos[j * 3], pos[j * 3 + 1], pos[j * 3 + 2]);
          conn++;
        }
      }
    }
    return { pos, col, line: new Float32Array(line) };
  }, [count]);
}

function Brain({ count, tex }: { count: number; tex: THREE.Texture }) {
  const { pos, col, line } = useBrain(count);
  const g = useRef<THREE.Group>(null);
  useFrame((s, dt) => {
    if (g.current) {
      g.current.rotation.y += dt * 0.12;
      g.current.scale.setScalar(1.34 * (1 + Math.sin(s.clock.elapsedTime * 0.8) * 0.018));
    }
  });
  return (
    <group ref={g}>
      <points>
        <bufferGeometry>
          <bufferAttribute attach="attributes-position" args={[pos, 3]} />
          <bufferAttribute attach="attributes-color" args={[col, 3]} />
        </bufferGeometry>
        <pointsMaterial map={tex} size={0.085} vertexColors transparent opacity={0.95} sizeAttenuation depthWrite={false} blending={THREE.AdditiveBlending} />
      </points>
      <lineSegments>
        <bufferGeometry>
          <bufferAttribute attach="attributes-position" args={[line, 3]} />
        </bufferGeometry>
        <lineBasicMaterial color="#36d3ff" transparent opacity={0.09} blending={THREE.AdditiveBlending} depthWrite={false} />
      </lineSegments>
    </group>
  );
}

/** Central PBR core mesh — the GLB asset slot (procedural fallback shown until a
 *  GLB is supplied at /public/organism/core.glb). Lit by the environment. */
function Core({ color, tex }: { color: string; tex: THREE.Texture }) {
  const halo = useRef<THREE.Sprite>(null);
  const shell = useRef<THREE.Mesh>(null);
  const core = useRef<THREE.Mesh>(null);
  useFrame((s, dt) => {
    const p = 1 + Math.sin(s.clock.elapsedTime * 1.7) * 0.13;
    if (core.current) core.current.scale.setScalar(0.3 * p);
    if (halo.current) halo.current.scale.setScalar(3.1 * p);
    if (shell.current) shell.current.rotation.y -= dt * 0.25;
  });
  return (
    <group>
      <sprite scale={5.4}>
        <spriteMaterial map={tex} color={color} transparent opacity={0.16} blending={THREE.AdditiveBlending} depthWrite={false} />
      </sprite>
      <sprite ref={halo}>
        <spriteMaterial map={tex} color={color} transparent opacity={0.5} blending={THREE.AdditiveBlending} depthWrite={false} />
      </sprite>
      {/* Faceted asset shell (GLB slot, procedural fallback) — wireframe icosahedron */}
      <mesh ref={shell} scale={0.62}>
        <icosahedronGeometry args={[1, 1]} />
        <meshBasicMaterial color={color} wireframe transparent opacity={0.5} toneMapped={false} blending={THREE.AdditiveBlending} depthWrite={false} />
      </mesh>
      <mesh ref={core}>
        <sphereGeometry args={[1, 32, 32]} />
        <meshBasicMaterial color="#eafbff" toneMapped={false} />
      </mesh>
    </group>
  );
}

function Hub({
  hub,
  active,
  onSelect,
  showLabel,
  visible,
  tex,
}: {
  hub: (typeof HUBS)[number];
  active?: string;
  onSelect?: (id: string) => void;
  showLabel: boolean;
  visible: boolean;
  tex: THREE.Texture;
}) {
  const end = useMemo(() => new THREE.Vector3(hub.pos[0], hub.pos[1], hub.pos[2]), [hub.pos]);
  const curve = useMemo(() => {
    const mid = end.clone().multiplyScalar(0.55);
    mid.z += end.z >= 0 ? -0.55 : 0.55;
    return new THREE.QuadraticBezierCurve3(new THREE.Vector3(0, 0, 0), mid, end);
  }, [end]);
  const pulse = useRef<THREE.Sprite>(null);
  const node = useRef<THREE.Mesh>(null);
  const t = useRef(Math.random());
  const [hover, setHover] = useState(false);
  const on = active === hub.id || hover;

  useEffect(() => {
    document.body.style.cursor = hover ? "pointer" : "auto";
    return () => {
      document.body.style.cursor = "auto";
    };
  }, [hover]);

  useFrame((s, dt) => {
    t.current = (t.current + dt * 0.3) % 1;
    if (pulse.current) {
      const p = curve.getPoint(1 - t.current);
      pulse.current.position.set(p.x, p.y, p.z);
      const m = pulse.current.material as THREE.SpriteMaterial;
      m.opacity = 0.5 + Math.sin(t.current * Math.PI) * 0.5;
    }
    if (node.current) {
      node.current.rotation.y += dt * 0.5;
      node.current.scale.setScalar((on ? 1.25 : 1) * (1 + Math.sin(s.clock.elapsedTime * 2.4 + end.x * 2) * 0.05));
    }
  });

  if (!visible) return null;

  return (
    <group>
      <mesh>
        <tubeGeometry args={[curve, 48, 0.013, 8, false]} />
        <meshBasicMaterial color={hub.color} transparent opacity={on ? 0.75 : 0.32} toneMapped={false} blending={THREE.AdditiveBlending} depthWrite={false} />
      </mesh>
      <sprite ref={pulse} scale={0.32}>
        <spriteMaterial map={tex} color={hub.color} transparent opacity={0.9} blending={THREE.AdditiveBlending} depthWrite={false} />
      </sprite>
      <group position={[end.x, end.y, end.z]}>
        <sprite scale={on ? 0.95 : 0.7}>
          <spriteMaterial map={tex} color={hub.color} transparent opacity={0.85} blending={THREE.AdditiveBlending} depthWrite={false} />
        </sprite>
        {/* PBR hub node */}
        <mesh
          ref={node}
          onClick={(e: ThreeEvent<MouseEvent>) => {
            e.stopPropagation();
            onSelect?.(hub.id);
          }}
          onPointerOver={(e: ThreeEvent<PointerEvent>) => {
            e.stopPropagation();
            setHover(true);
          }}
          onPointerOut={() => setHover(false)}
        >
          <icosahedronGeometry args={[0.15, 0]} />
          <meshBasicMaterial color={hub.color} toneMapped={false} />
        </mesh>
        {showLabel ? (
          <Html center distanceFactor={9} position={[0, 0.36, 0]} style={{ pointerEvents: "none" }} zIndexRange={[20, 0]}>
            <div className={`hub3d-label${on ? " active" : ""}`}>{hub.label}</div>
          </Html>
        ) : null}
      </group>
    </group>
  );
}

function Stars({ tex }: { tex: THREE.Texture }) {
  const pos = useMemo(() => {
    const n = 420;
    const p = new Float32Array(n * 3);
    for (let i = 0; i < n; i++) {
      const r = 7 + Math.random() * 9;
      const th = Math.random() * Math.PI * 2;
      const ph = Math.acos(2 * Math.random() - 1);
      p[i * 3] = r * Math.sin(ph) * Math.cos(th);
      p[i * 3 + 1] = r * Math.sin(ph) * Math.sin(th);
      p[i * 3 + 2] = r * Math.cos(ph);
    }
    return p;
  }, []);
  return (
    <points>
      <bufferGeometry>
        <bufferAttribute attach="attributes-position" args={[pos, 3]} />
      </bufferGeometry>
      <pointsMaterial map={tex} color="#3b82f6" size={0.07} transparent opacity={0.5} sizeAttenuation depthWrite={false} blending={THREE.AdditiveBlending} />
    </points>
  );
}

function Stats({ onStats, nodes }: { onStats?: (fps: number, nodes: number) => void; nodes: number }) {
  const acc = useRef(0);
  const frames = useRef(0);
  useFrame((_, dt) => {
    acc.current += dt;
    frames.current += 1;
    if (acc.current >= 0.5) {
      onStats?.(Math.round(frames.current / acc.current), nodes);
      acc.current = 0;
      frames.current = 0;
    }
  });
  return null;
}

function hubVisible(hub: (typeof HUBS)[number], layers?: string[], agents?: string[]) {
  if (layers && layers.length && !layers.includes(hub.layer)) return false;
  if (agents && agents.length && !hub.agents.some((a) => agents.includes(a))) return false;
  return true;
}

function Scene({
  runState,
  nodeCount,
  active,
  onSelect,
  interactive,
  showLabels,
  visibleLayers,
  visibleAgents,
  onStats,
}: {
  runState: RunState;
  nodeCount: number;
  active?: string;
  onSelect?: (id: string) => void;
  interactive: boolean;
  showLabels: boolean;
  visibleLayers?: string[];
  visibleAgents?: string[];
  onStats?: (fps: number, nodes: number) => void;
}) {
  const tex = useGlow();
  const sc = STATE_COLOR[runState];
  return (
    <>
      <color attach="background" args={["#04060d"]} />
      <fog attach="fog" args={["#04060d", 6.5, 15]} />
      <Stars tex={tex} />
      <Stats onStats={onStats} nodes={nodeCount} />
      <group rotation={[0.32, 0, 0]}>
        <Brain count={nodeCount} tex={tex} />
        <Core color={sc} tex={tex} />
        {HUBS.map((h) => (
          <Hub key={h.id} hub={h} active={active} onSelect={onSelect} showLabel={showLabels} visible={hubVisible(h, visibleLayers, visibleAgents)} tex={tex} />
        ))}
      </group>
      <OrbitControls
        enablePan={false}
        enableZoom={interactive}
        enableRotate={interactive}
        autoRotate={!interactive}
        autoRotateSpeed={0.5}
        minDistance={4.5}
        maxDistance={12}
        minPolarAngle={Math.PI * 0.2}
        maxPolarAngle={Math.PI * 0.8}
      />
      <EffectComposer>
        <Bloom intensity={1.3} luminanceThreshold={0.12} luminanceSmoothing={0.5} mipmapBlur radius={0.75} />
        <Vignette eskil={false} offset={0.25} darkness={0.85} />
      </EffectComposer>
    </>
  );
}

export default function CortexCanvas3D({
  runState = "planning",
  nodeCount = 1500,
  activeRegion,
  onSelectRegion,
  interactive = true,
  showRegions = true,
  visibleLayers,
  visibleAgents,
  onStats,
}: {
  runState?: RunState;
  nodeCount?: number;
  activeRegion?: string;
  onSelectRegion?: (id: string) => void;
  interactive?: boolean;
  showRegions?: boolean;
  visibleLayers?: string[];
  visibleAgents?: string[];
  onStats?: (fps: number, nodes: number) => void;
}) {
  return (
    <div className="cortex-wrap">
      <Canvas
        camera={{ position: [0, 0.6, 7], fov: 48 }}
        dpr={[1, 2]}
        gl={{ antialias: true, alpha: false, powerPreference: "high-performance" }}
        style={{ position: "absolute", inset: 0 }}
      >
        <Scene
          runState={runState}
          nodeCount={nodeCount}
          active={activeRegion}
          onSelect={onSelectRegion}
          interactive={interactive}
          showLabels={showRegions}
          visibleLayers={visibleLayers}
          visibleAgents={visibleAgents}
          onStats={onStats}
        />
      </Canvas>
      <span className="cortex-badge">LIVE · ORGANISM · WEBGL</span>
      <span className="cortex-state">
        <span className="dot" style={{ background: STATE_COLOR[runState] }} />
        {STATE_LABEL[runState]}
      </span>
    </div>
  );
}

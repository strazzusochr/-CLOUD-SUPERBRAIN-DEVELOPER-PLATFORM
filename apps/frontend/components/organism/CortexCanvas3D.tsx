"use client";

/*
 * Cloud Superbrain — Living Cortex, real GPU path (React Three Fiber + three.js).
 *
 * WebGL2 point-cloud brain + synapse lines + glowing core + 10 clickable brain
 * regions, auto-rotating with OrbitControls for mechanical interaction and a
 * Bloom post-process for the "living" glow. Colours/animation are data-driven
 * by runState / activeRegion (never fake-live). This is the primary 3D surface;
 * CortexCanvas (dependency-free 2D) stays the universal/reduced-motion fallback.
 */

import { useMemo, useRef, useState, useEffect } from "react";
import { Canvas, useFrame, type ThreeEvent } from "@react-three/fiber";
import { OrbitControls, Html } from "@react-three/drei";
import { EffectComposer, Bloom } from "@react-three/postprocessing";
import * as THREE from "three";
import { REGIONS, STATE_COLOR, STATE_LABEL, type RunState } from "./regionMap";

function useBrain(count: number) {
  return useMemo(() => {
    const positions = new Float32Array(count * 3);
    const colors = new Float32Array(count * 3);
    const cyan = new THREE.Color("#00e5ff");
    const violet = new THREE.Color("#8b5cf6");
    const golden = Math.PI * (3 - Math.sqrt(5));
    const tmp = new THREE.Color();
    for (let i = 0; i < count; i++) {
      const y = 1 - (i / (count - 1)) * 2;
      const r = Math.sqrt(Math.max(0, 1 - y * y));
      const th = golden * i;
      const x = Math.cos(th) * r * 1.18 + (Math.cos(th) > 0 ? 0.06 : -0.06);
      const z = Math.sin(th) * r * 0.96;
      const yy = y * 0.92;
      positions[i * 3] = x;
      positions[i * 3 + 1] = yy;
      positions[i * 3 + 2] = z;
      tmp.copy(cyan).lerp(violet, (yy + 1) / 2);
      colors[i * 3] = tmp.r;
      colors[i * 3 + 1] = tmp.g;
      colors[i * 3 + 2] = tmp.b;
    }
    const line: number[] = [];
    for (let i = 0; i < count; i++) {
      let conn = 0;
      for (let j = i + 1; j < count && conn < 2; j++) {
        const dx = positions[i * 3] - positions[j * 3];
        const dy = positions[i * 3 + 1] - positions[j * 3 + 1];
        const dz = positions[i * 3 + 2] - positions[j * 3 + 2];
        if (dx * dx + dy * dy + dz * dz < 0.05) {
          line.push(positions[i * 3], positions[i * 3 + 1], positions[i * 3 + 2]);
          line.push(positions[j * 3], positions[j * 3 + 1], positions[j * 3 + 2]);
          conn++;
        }
      }
    }
    return { positions, colors, linePositions: new Float32Array(line) };
  }, [count]);
}

function Brain({ count }: { count: number }) {
  const { positions, colors, linePositions } = useBrain(count);
  return (
    <group>
      <points>
        <bufferGeometry>
          <bufferAttribute attach="attributes-position" args={[positions, 3]} />
          <bufferAttribute attach="attributes-color" args={[colors, 3]} />
        </bufferGeometry>
        <pointsMaterial size={0.045} vertexColors transparent opacity={0.95} sizeAttenuation depthWrite={false} />
      </points>
      <lineSegments>
        <bufferGeometry>
          <bufferAttribute attach="attributes-position" args={[linePositions, 3]} />
        </bufferGeometry>
        <lineBasicMaterial color="#2bd6ff" transparent opacity={0.12} depthWrite={false} />
      </lineSegments>
    </group>
  );
}

function Core({ color }: { color: string }) {
  const ref = useRef<THREE.Mesh>(null);
  useFrame((state) => {
    if (!ref.current) return;
    const s = 1 + Math.sin(state.clock.elapsedTime * 2) * 0.08;
    ref.current.scale.setScalar(s);
  });
  return (
    <mesh ref={ref}>
      <sphereGeometry args={[0.16, 32, 32]} />
      <meshBasicMaterial color={color} toneMapped={false} />
    </mesh>
  );
}

function Regions({
  active,
  onSelect,
}: {
  active?: string;
  onSelect?: (id: string) => void;
}) {
  const [hover, setHover] = useState<string | null>(null);
  useEffect(() => {
    document.body.style.cursor = hover ? "pointer" : "auto";
    return () => {
      document.body.style.cursor = "auto";
    };
  }, [hover]);
  return (
    <group>
      {REGIONS.map((rg) => {
        const isActive = active === rg.id || hover === rg.id;
        return (
          <group key={rg.id} position={[rg.pos[0] * 1.05, rg.pos[1] * 1.05, rg.pos[2] * 1.05]}>
            <mesh
              onClick={(e: ThreeEvent<MouseEvent>) => {
                e.stopPropagation();
                onSelect?.(rg.id);
              }}
              onPointerOver={(e: ThreeEvent<PointerEvent>) => {
                e.stopPropagation();
                setHover(rg.id);
              }}
              onPointerOut={() => setHover((h) => (h === rg.id ? null : h))}
            >
              <sphereGeometry args={[isActive ? 0.06 : 0.04, 16, 16]} />
              <meshBasicMaterial color={rg.color} toneMapped={false} />
            </mesh>
            {isActive ? (
              <Html center distanceFactor={8} style={{ pointerEvents: "none" }}>
                <div className="cortex3d-label">{rg.name}</div>
              </Html>
            ) : null}
          </group>
        );
      })}
    </group>
  );
}

function Scene({
  runState,
  nodeCount,
  active,
  onSelect,
  interactive,
}: {
  runState: RunState;
  nodeCount: number;
  active?: string;
  onSelect?: (id: string) => void;
  interactive: boolean;
}) {
  const group = useRef<THREE.Group>(null);
  useFrame((_, delta) => {
    if (group.current) group.current.rotation.y += delta * 0.16;
  });
  const color = STATE_COLOR[runState];
  return (
    <>
      <color attach="background" args={["#05070d"]} />
      <fog attach="fog" args={["#05070d", 5, 11]} />
      <group ref={group}>
        <Brain count={nodeCount} />
        <Core color={color} />
        <Regions active={active} onSelect={onSelect} />
        <pointLight position={[0, 0, 0]} intensity={6} distance={6} color={color} />
      </group>
      <OrbitControls
        enablePan={false}
        enableZoom={interactive}
        enableRotate={interactive}
        autoRotate={false}
        minDistance={2.4}
        maxDistance={6}
      />
      <EffectComposer>
        <Bloom intensity={0.9} luminanceThreshold={0.2} luminanceSmoothing={0.4} mipmapBlur />
      </EffectComposer>
    </>
  );
}

export default function CortexCanvas3D({
  runState = "planning",
  nodeCount = 620,
  activeRegion,
  onSelectRegion,
  interactive = true,
}: {
  runState?: RunState;
  nodeCount?: number;
  activeRegion?: string;
  onSelectRegion?: (id: string) => void;
  interactive?: boolean;
}) {
  return (
    <div className="cortex-wrap">
      <Canvas
        camera={{ position: [0, 0.2, 3.6], fov: 50 }}
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

#!/usr/bin/env node
/*
 * gen-core-glb.js — generates apps/frontend/public/organism/core.glb
 *
 * Self-contained (no deps): builds a faceted crystalline icosphere with flat
 * per-face normals and a PBR material (metallic, low roughness, emissive), then
 * writes a valid binary glTF (GLB) container. Deterministic — same output every run.
 *
 * This is the real organism core asset slot; CortexCanvas3D loads it via useGLTF
 * and renders it with the basic emissive material in software GL (verifiable) and
 * full PBR + IBL on hardware GPUs.
 */
const fs = require("fs");
const path = require("path");

/* ---------- geometry: faceted, displaced icosphere ---------- */
function normalize(v) {
  const l = Math.hypot(v[0], v[1], v[2]) || 1;
  return [v[0] / l, v[1] / l, v[2] / l];
}
const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];

function icosphere(subdiv, radius) {
  const t = (1 + Math.sqrt(5)) / 2;
  let verts = [
    [-1, t, 0], [1, t, 0], [-1, -t, 0], [1, -t, 0],
    [0, -1, t], [0, 1, t], [0, -1, -t], [0, 1, -t],
    [t, 0, -1], [t, 0, 1], [-t, 0, -1], [-t, 0, 1],
  ].map(normalize);
  let faces = [
    [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
    [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
    [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
    [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
  ];
  for (let s = 0; s < subdiv; s++) {
    const cache = {};
    const mid = (a, b) => {
      const key = a < b ? `${a}_${b}` : `${b}_${a}`;
      if (cache[key] !== undefined) return cache[key];
      const m = normalize([
        (verts[a][0] + verts[b][0]) / 2,
        (verts[a][1] + verts[b][1]) / 2,
        (verts[a][2] + verts[b][2]) / 2,
      ]);
      verts.push(m);
      cache[key] = verts.length - 1;
      return cache[key];
    };
    const nf = [];
    for (const [a, b, c] of faces) {
      const ab = mid(a, b), bc = mid(b, c), ca = mid(c, a);
      nf.push([a, ab, ca], [b, bc, ab], [c, ca, bc], [ab, bc, ca]);
    }
    faces = nf;
  }
  // subtle multi-frequency radial displacement → crystalline, not a perfect ball
  const displaced = verts.map((v) => {
    const n = 1 + 0.05 * Math.sin(v[0] * 5.0) * Math.cos(v[1] * 4.0) + 0.035 * Math.sin(v[2] * 6.0 + 1.3);
    return [v[0] * radius * n, v[1] * radius * n, v[2] * radius * n];
  });
  // flat-shaded, non-indexed (each face gets its own 3 verts + face normal)
  const pos = [], nrm = [];
  for (const [a, b, c] of faces) {
    const A = displaced[a], B = displaced[b], C = displaced[c];
    const fn = normalize(cross(sub(B, A), sub(C, A)));
    pos.push(...A, ...B, ...C);
    nrm.push(...fn, ...fn, ...fn);
  }
  return { pos: new Float32Array(pos), nrm: new Float32Array(nrm), faceCount: faces.length };
}

/* ---------- GLB assembly ---------- */
function pad4(n) { return (n + 3) & ~3; }

function buildGLB({ pos, nrm }) {
  const posBytes = Buffer.from(pos.buffer, pos.byteOffset, pos.byteLength);
  const nrmBytes = Buffer.from(nrm.buffer, nrm.byteOffset, nrm.byteLength);
  const bin = Buffer.concat([posBytes, nrmBytes]);

  let min = [Infinity, Infinity, Infinity], max = [-Infinity, -Infinity, -Infinity];
  for (let i = 0; i < pos.length; i += 3) {
    for (let k = 0; k < 3; k++) {
      min[k] = Math.min(min[k], pos[i + k]);
      max[k] = Math.max(max[k], pos[i + k]);
    }
  }
  const count = pos.length / 3;

  const gltf = {
    asset: { version: "2.0", generator: "cloud-superbrain gen-core-glb" },
    scene: 0,
    scenes: [{ name: "OrganismCore", nodes: [0] }],
    nodes: [{ name: "Core", mesh: 0 }],
    meshes: [{
      name: "CoreCrystal",
      primitives: [{ attributes: { POSITION: 0, NORMAL: 1 }, material: 0, mode: 4 }],
    }],
    materials: [{
      name: "CoreCrystalPBR",
      pbrMetallicRoughness: {
        baseColorFactor: [0.82, 0.95, 1.0, 1.0],
        metallicFactor: 0.6,
        roughnessFactor: 0.18,
      },
      emissiveFactor: [0.18, 0.55, 0.75],
      doubleSided: false,
    }],
    accessors: [
      { bufferView: 0, componentType: 5126, count, type: "VEC3", min, max },
      { bufferView: 1, componentType: 5126, count, type: "VEC3" },
    ],
    bufferViews: [
      { buffer: 0, byteOffset: 0, byteLength: posBytes.length, target: 34962 },
      { buffer: 0, byteOffset: posBytes.length, byteLength: nrmBytes.length, target: 34962 },
    ],
    buffers: [{ byteLength: bin.length }],
  };

  let json = Buffer.from(JSON.stringify(gltf), "utf8");
  const jsonPad = pad4(json.length) - json.length;
  if (jsonPad) json = Buffer.concat([json, Buffer.alloc(jsonPad, 0x20)]); // pad with spaces
  const binPad = pad4(bin.length) - bin.length;
  const binChunk = binPad ? Buffer.concat([bin, Buffer.alloc(binPad, 0)]) : bin;

  const header = Buffer.alloc(12);
  header.writeUInt32LE(0x46546c67, 0); // 'glTF'
  header.writeUInt32LE(2, 4);
  header.writeUInt32LE(12 + 8 + json.length + 8 + binChunk.length, 8);

  const jsonHeader = Buffer.alloc(8);
  jsonHeader.writeUInt32LE(json.length, 0);
  jsonHeader.writeUInt32LE(0x4e4f534a, 4); // 'JSON'

  const binHeader = Buffer.alloc(8);
  binHeader.writeUInt32LE(binChunk.length, 0);
  binHeader.writeUInt32LE(0x004e4942, 4); // 'BIN\0'

  return Buffer.concat([header, jsonHeader, json, binHeader, binChunk]);
}

const geo = icosphere(3, 1.0); // 3 subdivisions = 1280 faceted faces
const glb = buildGLB(geo);
const out = path.resolve(__dirname, "../apps/frontend/public/organism/core.glb");
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, glb);
console.log(`core.glb written: ${geo.faceCount} faces, ${(glb.length / 1024).toFixed(1)} KB → ${out}`);

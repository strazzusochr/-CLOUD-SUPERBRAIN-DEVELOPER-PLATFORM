// Regression guard for the workbench build path.
//
// Observed 2026-08-28 on a live Cloudflare Workers AI generation: the model emitted
//   <script src="https://unpkg.com/three@0.160.0/examples/js/controls/OrbitControls.js">
//   <script src="https://unpkg.com/three@0.160.0/examples/js/postprocessing/EffectComposer.js">
// Both return HTTP 404 — three.js removed examples/js in r150 — and the generated code then
// called `new THREE.EffectComposer(renderer)` on its third statement. That throws before any
// geometry exists, so the persisted "game" rendered a black canvas.
//
// The generator must not be allowed to persist a document that cannot run. These tests bind
// the validator to that exact failure and to a control document that does run.

import assert from "node:assert/strict";
import fs from "node:fs";
import module from "node:module";
import test from "node:test";
import vm from "node:vm";
import ts from "typescript";

const source = fs.readFileSync(new URL("../lib/generatedHtml.ts", import.meta.url), "utf8");
const compiled = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const sandbox = { exports: {}, module: { exports: {} }, require: module.createRequire(import.meta.url) };
sandbox.module.exports = sandbox.exports;
vm.runInNewContext(compiled, sandbox);
const { findUnrunnableReferences, isRunnableGeneratedHtml } = sandbox.module.exports;

const DOC = (body) => `<!doctype html><html><head></head><body>${body}</body></html>`;

test("the exact dead three.js addon paths that broke a live build are rejected", () => {
  const html = DOC(
    '<script src="https://unpkg.com/three@0.160.0/build/three.min.js"></script>'
    + '<script src="https://unpkg.com/three@0.160.0/examples/js/controls/OrbitControls.js"></script>'
    + '<script src="https://unpkg.com/three@0.160.0/examples/js/postprocessing/EffectComposer.js"></script>',
  );
  const reasons = findUnrunnableReferences(html);
  assert.equal(isRunnableGeneratedHtml(html), false);
  assert.ok(
    reasons.some((reason) => reason.includes("examples/js")),
    `expected an examples/js rejection, got ${JSON.stringify(reasons)}`,
  );
});

test("every examples/js subpath is rejected, not just the two that were observed", () => {
  for (const sub of ["controls/OrbitControls.js", "shaders/CopyShader.js", "loaders/GLTFLoader.js"]) {
    const html = DOC(`<script src="https://unpkg.com/three@0.160.0/examples/js/${sub}"></script>`);
    assert.equal(isRunnableGeneratedHtml(html), false, `${sub} should be rejected`);
  }
});

test("the modern addon path is rejected too when loaded as a classic script", () => {
  // examples/jsm is ESM. A plain <script src> tag cannot execute it, so THREE.X stays undefined
  // and the document fails the same way as examples/js did.
  const html = DOC(
    '<script src="https://unpkg.com/three@0.160.0/examples/jsm/controls/OrbitControls.js"></script>',
  );
  assert.equal(isRunnableGeneratedHtml(html), false);
});

test("examples/jsm inside a module script or an import map stays allowed", () => {
  const importMap = DOC(
    '<script type="importmap">{"imports":{"three/addons/":"https://unpkg.com/three@0.160.0/examples/jsm/"}}</script>'
    + '<script type="module">import { OrbitControls } from "three/addons/controls/OrbitControls.js";</script>',
  );
  assert.deepEqual(findUnrunnableReferences(importMap), []);
  assert.equal(isRunnableGeneratedHtml(importMap), true);
});

test("a core-only three.js document is accepted", () => {
  const html = DOC(
    '<script src="https://unpkg.com/three@0.160.0/build/three.min.js"></script>'
    + "<script>const s=new THREE.Scene();</script>",
  );
  assert.deepEqual(findUnrunnableReferences(html), []);
  assert.equal(isRunnableGeneratedHtml(html), true);
});

test("a document with no external scripts at all is accepted", () => {
  assert.equal(isRunnableGeneratedHtml(DOC("<script>console.log(1)</script>")), true);
});

test("the rejection reason names the offending URL so the boundary can report it", () => {
  const html = DOC('<script src="https://unpkg.com/three@0.160.0/examples/js/controls/OrbitControls.js"></script>');
  const [reason] = findUnrunnableReferences(html);
  assert.ok(reason.includes("OrbitControls.js"), `reason should name the file, got ${reason}`);
});

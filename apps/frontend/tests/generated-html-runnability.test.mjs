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
// Evaluated in this realm on purpose: a new vm context would hand back arrays from a different
// realm, and deepEqual would then reject two structurally identical empty arrays.
const load = vm.runInThisContext(`(function (exports, module, require) { ${compiled}\n})`);
const moduleShim = { exports: {} };
load(moduleShim.exports, moduleShim, module.createRequire(import.meta.url));
const {
  ensureGeneratedHtmlDependencies,
  ensureGeneratedHtmlRuntimeOrder,
  findUnrunnableReferences,
  isRunnableGeneratedHtml,
} = moduleShim.exports;

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

test("unquoted and unversioned classic addon URLs cannot bypass the guard", () => {
  const html = DOC(
    '<script src=https://unpkg.com/three/examples/js/controls/OrbitControls.js></script>'
    + '<script src=https://cdn.jsdelivr.net/npm/three@0.160.0/examples/jsm/loaders/GLTFLoader.js></script>',
  );
  assert.equal(findUnrunnableReferences(html).length, 2);
  assert.equal(isRunnableGeneratedHtml(html), false);
});

test("a module tag cannot revive the removed examples/js directory", () => {
  const html = DOC(
    '<script type=module src=https://unpkg.com/three@0.160.0/examples/js/controls/OrbitControls.js></script>',
  );
  assert.equal(isRunnableGeneratedHtml(html), false);
});

test("an external examples/jsm module needs a three import map", () => {
  const withoutMap = DOC(
    '<script type=module src=https://unpkg.com/three@0.160.0/examples/jsm/controls/OrbitControls.js></script>',
  );
  assert.equal(isRunnableGeneratedHtml(withoutMap), false);

  const withMap = DOC(
    '<script type=importmap>{"imports":{"three":"https://unpkg.com/three@0.160.0/build/three.module.js"}}</script>'
    + '<script type=module src=https://unpkg.com/three@0.160.0/examples/jsm/controls/OrbitControls.js></script>',
  );
  assert.equal(isRunnableGeneratedHtml(withMap), true);

  const withInvalidMap = DOC(
    '<script type=importmap>{"imports":{"three":}}</script>'
    + '<script type=module src=https://unpkg.com/three@0.160.0/examples/jsm/controls/OrbitControls.js></script>',
  );
  assert.equal(isRunnableGeneratedHtml(withInvalidMap), false);
});

test("commented legacy snippets are not treated as executable references", () => {
  const html = DOC(
    '<!-- <script src="https://unpkg.com/three@0.160.0/examples/js/controls/OrbitControls.js"></script> -->'
    + '<script type=importmap>{"imports":{"three":"https://unpkg.com/three@0.160.0/build/three.module.js"}}</script>'
    + '<script type=module src=https://unpkg.com/three@0.160.0/examples/jsm/controls/OrbitControls.js></script>',
  );
  assert.deepEqual(findUnrunnableReferences(html), []);
  assert.equal(isRunnableGeneratedHtml(html), true);
});

test("a core-only three.js document is accepted", () => {
  const html = DOC(
    '<script src="https://unpkg.com/three@0.160.0/build/three.min.js"></script>'
    + "<script>const s=new THREE.Scene();</script>",
  );
  assert.deepEqual(findUnrunnableReferences(html), []);
  assert.equal(isRunnableGeneratedHtml(html), true);
});

test("a live-style THREE global without any core dependency is rejected", () => {
  const html = DOC(
    "<script>const scene=new THREE.Scene();const renderer=new THREE.WebGLRenderer();</script>",
  );
  const reasons = findUnrunnableReferences(html);
  assert.equal(isRunnableGeneratedHtml(html), false);
  assert.ok(
    reasons.some((reason) => reason.includes("THREE is referenced")),
    `expected a missing THREE dependency rejection, got ${JSON.stringify(reasons)}`,
  );
});

test("the generation boundary can add the pinned core before the first THREE use", () => {
  const broken = DOC("<script>const scene=new THREE.Scene();</script>");
  const repaired = ensureGeneratedHtmlDependencies(broken);
  assert.match(repaired, /three@0\.160\.0\/build\/three\.min\.js/);
  assert.ok(
    repaired.indexOf("three.min.js") < repaired.indexOf("new THREE.Scene"),
    "the dependency must execute before the generated app",
  );
  assert.equal(isRunnableGeneratedHtml(repaired), true);
  assert.equal(ensureGeneratedHtmlDependencies(repaired), repaired, "repair must be idempotent");
});

test("a document with no external scripts at all is accepted", () => {
  assert.equal(isRunnableGeneratedHtml(DOC("<script>console.log(1)</script>")), true);
});

test("a live animation cannot start before its lexical keyboard state is initialized", () => {
  const broken = DOC(`<script>
    function animate() {
      requestAnimationFrame(animate);
      if (keys['ArrowUp']) player.position.z -= 1;
    }
    animate();
    const keys = {};
    document.addEventListener('keydown', (event) => { keys[event.key] = true; });
  </script>`);
  const reasons = findUnrunnableReferences(broken);
  assert.equal(isRunnableGeneratedHtml(broken), false);
  assert.ok(
    reasons.some((reason) => reason.includes("before lexical keyboard state 'keys'")),
    `expected a keyboard TDZ rejection, got ${JSON.stringify(reasons)}`,
  );

  const repaired = ensureGeneratedHtmlRuntimeOrder(broken);
  assert.ok(
    repaired.indexOf("const keys = {}") < repaired.indexOf("animate();", repaired.indexOf("const keys = {}")),
    "the animation must start only after keyboard state initialization",
  );
  assert.equal(isRunnableGeneratedHtml(repaired), true);
  assert.equal(ensureGeneratedHtmlRuntimeOrder(repaired), repaired, "runtime-order repair must be idempotent");
});

test("runtime-order repair does not move an animation that never reads keyboard state", () => {
  const valid = DOC(`<script>
    function animate() { requestAnimationFrame(animate); }
    animate();
    const keys = {};
  </script>`);
  assert.equal(isRunnableGeneratedHtml(valid), true);
  assert.equal(ensureGeneratedHtmlRuntimeOrder(valid), valid);
});

test("runtime-order detection binds keys usage to the animation body", () => {
  const valid = DOC(`<script>
    function animate() { requestAnimationFrame(animate); }
    function unrelated() { if (keys['ArrowUp']) console.log('up'); }
    animate();
    const keys = {};
  </script>`);
  assert.equal(isRunnableGeneratedHtml(valid), true);
  assert.equal(ensureGeneratedHtmlRuntimeOrder(valid), valid);
});

test("runtime-order repair moves the external start call but preserves recursion", () => {
  const broken = DOC(`<script>
    function animate() {
      if (keys['ArrowUp']) player.position.z -= 1;
      animate();
    }
    animate();
    const keys = {};
  </script>`);
  const repaired = ensureGeneratedHtmlRuntimeOrder(broken);
  const functionSource = repaired.slice(repaired.indexOf("function animate"), repaired.indexOf("const keys"));
  assert.match(functionSource, /animate\(\);/, "the recursive call inside the function must remain");
  assert.equal(isRunnableGeneratedHtml(repaired), true);
  assert.ok(repaired.indexOf("const keys = {}") < repaired.lastIndexOf("animate();"));
});

test("multiple early keyboard consumers remain fail-closed after one narrow repair", () => {
  const ambiguous = DOC(`<script>
    function animate() { if (keys['ArrowUp']) player.position.z -= 1; }
    function pollInput() { if (keys['ArrowDown']) player.position.z += 1; }
    animate();
    pollInput();
    const keys = {};
  </script>`);
  const onceRepaired = ensureGeneratedHtmlRuntimeOrder(ambiguous);
  assert.equal(isRunnableGeneratedHtml(onceRepaired), false);
  assert.ok(findUnrunnableReferences(onceRepaired).some((reason) => reason.startsWith("pollInput()")));
});

test("runtime-order repair preserves the original script tag", () => {
  const broken = DOC(`<SCRIPT data-runtime="generated">
    function animate() {
      if (keys['ArrowUp']) player.position.z -= 1;
    }
    animate();
    const keys = {};
  </SCRIPT>`);
  const repaired = ensureGeneratedHtmlRuntimeOrder(broken);
  assert.match(repaired, /<SCRIPT data-runtime="generated">/);
  assert.match(repaired, /<\/SCRIPT>/);
  assert.equal(isRunnableGeneratedHtml(repaired), true);
});

test("the rejection reason names the offending URL so the boundary can report it", () => {
  const html = DOC('<script src="https://unpkg.com/three@0.160.0/examples/js/controls/OrbitControls.js"></script>');
  const [reason] = findUnrunnableReferences(html);
  assert.ok(reason.includes("OrbitControls.js"), `reason should name the file, got ${reason}`);
});

test("the production build route applies the runnability guard before persistence", () => {
  const route = fs.readFileSync(new URL("../app/api/v1/build/route.ts", import.meta.url), "utf8");
  assert.match(route, /ensureGeneratedHtmlDependencies/);
  assert.match(route, /ensureGeneratedHtmlRuntimeOrder/);
  assert.match(route, /isRunnableGeneratedHtml\(value\)/);
  assert.match(route, /unrunnable_html/);
  assert.match(route, /!structurallyCompletePersistableHtml\(baseHtml\)/);
  assert.ok(
    route.indexOf("ensureGeneratedHtmlDependencies(extractHtml(rawContent))")
      < route.indexOf("findUnrunnableReferences(html)"),
    "known missing dependencies must be repaired before the fail-closed verdict",
  );
  assert.ok(
    route.indexOf("ensureGeneratedHtmlRuntimeOrder(") < route.indexOf("findUnrunnableReferences(html)"),
    "known runtime-order defects must be repaired before the fail-closed verdict",
  );
  assert.ok(
    route.indexOf("findUnrunnableReferences(html)") < route.indexOf("persistBuild(req, buildRecord)"),
    "runnability must be checked before the persistence call",
  );
});

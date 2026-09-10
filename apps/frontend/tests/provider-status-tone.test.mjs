// Guard against a retired provider being painted as verified.
//
// Observed 2026-08-28 on /marketplace: the status tone was chosen with
// /verified|live/.test(status). Cloudflare's inventory reports Fly.io as
// `historical_read_verified` — a provider the contract itself calls
// "historical_only ... not an active runtime target". That substring contains
// "verified", so the retired provider rendered with a green dot and a green
// badge, indistinguishable from the genuinely live Cloudflare runtime.
//
// A product surface that shows a retired provider as verified is exactly the
// Fake-Live the project forbids. These tests bind the classification.

import assert from "node:assert/strict";
import fs from "node:fs";
import module from "node:module";
import test from "node:test";
import vm from "node:vm";
import ts from "typescript";

const source = fs.readFileSync(new URL("../lib/providerStatus.ts", import.meta.url), "utf8");
const compiled = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const load = vm.runInThisContext(`(function (exports, module, require) { ${compiled}\n})`);
const shim = { exports: {} };
load(shim.exports, shim, module.createRequire(import.meta.url));
const { providerStatusTone } = shim.exports;

test("a retired provider is never painted as verified", () => {
  assert.notEqual(
    providerStatusTone("historical_read_verified"),
    "green",
    "historical_read_verified is a retired provider and must not read as verified",
  );
});

test("genuinely verified providers stay green", () => {
  assert.equal(providerStatusTone("live_verified"), "green");
  assert.equal(providerStatusTone("verified"), "green");
});

test("unverified provider states are not green", () => {
  for (const status of ["action_required", "api_error", "metadata_only", "historical_only"]) {
    assert.notEqual(providerStatusTone(status), "green", `${status} must not read as verified`);
  }
});

test("the marketplace surface uses the shared classifier, not an inline regex", () => {
  const page = fs.readFileSync(new URL("../app/marketplace/page.tsx", import.meta.url), "utf8");
  assert.match(page, /providerStatusTone/, "marketplace must use the shared classifier");
  assert.doesNotMatch(
    page,
    /\/verified\|live\/\.test/,
    "the substring regex re-introduces the retired-provider bug",
  );
});

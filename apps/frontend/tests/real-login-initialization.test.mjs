import assert from "node:assert/strict";
import fs from "node:fs";
import { createRequire } from "node:module";
import test from "node:test";
import vm from "node:vm";
import ts from "typescript";

const require = createRequire(import.meta.url);
const source = fs.readFileSync(new URL("../components/real-login.tsx", import.meta.url), "utf8");
const compiled = ts.transpileModule(source, {
  compilerOptions: {
    esModuleInterop: true,
    jsx: ts.JsxEmit.ReactJSX,
    module: ts.ModuleKind.CommonJS,
    target: ts.ScriptTarget.ES2022,
  },
}).outputText;
const loaded = { exports: {} };
new vm.Script(`(function (require, module, exports) { ${compiled}\n})`).runInThisContext()(
  (specifier) => {
    if (specifier === "react") {
      return {
        useEffect: () => {},
        useRef: (current) => ({ current }),
        useState: (initial) => [initial, () => {}],
      };
    }
    if (specifier === "react/jsx-runtime") {
      return { Fragment: Symbol("Fragment"), jsx: () => null, jsxs: () => null };
    }
    return require(specifier);
  },
  loaded,
  loaded.exports,
);

const { readOauthBoundaryReady, sharedOauthBoundaryReady } = loaded.exports;

function response(payload, { ok = true } = {}) {
  return {
    ok,
    async json() { return payload; },
  };
}

test("StrictMode effect subscribers share one parsed boundary read", async () => {
  let requestCount = 0;
  let resolveRequest;
  const deferred = new Promise((resolve) => { resolveRequest = resolve; });
  const fetcher = async () => {
    requestCount += 1;
    await deferred;
    return response({ credential_issuance_ready: true, owner_activation_granted: true });
  };
  const componentRef = { current: null };

  const firstSubscriber = sharedOauthBoundaryReady(componentRef, fetcher);
  const replaySubscriber = sharedOauthBoundaryReady(componentRef, fetcher);
  assert.strictEqual(firstSubscriber, replaySubscriber);
  assert.equal(requestCount, 1);

  resolveRequest();
  assert.deepEqual(await Promise.all([firstSubscriber, replaySubscriber]), [true, true]);
  assert.equal(requestCount, 1);
});

test("a genuine remount gets a fresh boundary read", async () => {
  let requestCount = 0;
  const fetcher = async () => {
    requestCount += 1;
    return response({ credential_issuance_ready: true, owner_activation_granted: true });
  };

  assert.equal(await sharedOauthBoundaryReady({ current: null }, fetcher), true);
  assert.equal(await sharedOauthBoundaryReady({ current: null }, fetcher), true);
  assert.equal(requestCount, 2);
});

test("the boundary stays closed for incomplete, malformed, non-OK, and failed reads", async () => {
  const cases = [
    async () => response({ credential_issuance_ready: true, owner_activation_granted: false }),
    async () => response({ credential_issuance_ready: false, owner_activation_granted: true }),
    async () => ({ ok: true, async json() { throw new SyntaxError("invalid json"); } }),
    async () => response({}, { ok: false }),
    async () => { throw new Error("network unavailable"); },
  ];

  for (const fetcher of cases) {
    assert.equal(await readOauthBoundaryReady(fetcher), false);
  }
});

test("only two explicit true flags open the OAuth boundary", async () => {
  assert.equal(await readOauthBoundaryReady(async (url, init) => {
    assert.equal(url, "/api/v1/auth/contract");
    assert.deepEqual(init, { cache: "no-store" });
    return response({ credential_issuance_ready: true, owner_activation_granted: true });
  }), true);
});

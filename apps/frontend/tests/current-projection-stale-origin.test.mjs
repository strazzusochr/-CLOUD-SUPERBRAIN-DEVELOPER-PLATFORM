import assert from "node:assert/strict";
import fs from "node:fs";
import { createRequire } from "node:module";
import test from "node:test";
import vm from "node:vm";
import ts from "typescript";

const require = createRequire(import.meta.url);
const routeSource = fs.readFileSync(
  new URL("../app/api/v1/[...slug]/route.ts", import.meta.url),
  "utf8",
);

const progressProjection = {
  "/api/v1/project/progress": { contract_version: "project-progress-v1", overall_percent: 89 },
  "/api/v1/project/progress/layers": { contract_version: "project-progress-layers-v1", layers: [] },
  "/api/v1/project/progress/integrity": { contract_version: "project-progress-integrity-v1", snapshot_stale: false },
  "/api/v1/project/progress/completion": { contract_version: "project-progress-100-percent-contract-v1", market_ready: false },
};

let readResponseFactory = () => Response.json(
  { contract_version: "project-progress-v1", overall_percent: 84 },
  { headers: { "x-superbrain-source": "contract-origin-via-d1-edge" } },
);

const boundaryStub = {
  authorizeBoundaryWrite: async () => null,
  authorizePublicSecurityProbe: () => null,
  boundaryUnavailable: () => Response.json({ status: "blocked" }, { status: 503 }),
  proxyAuthSessionToBoundary: async () => null,
  proxyOAuthGetToBoundary: async () => null,
  proxyReadToBoundary: async () => readResponseFactory(),
  proxyToBoundary: async () => null,
};

const compiled = ts.transpileModule(routeSource, {
  compilerOptions: {
    esModuleInterop: true,
    module: ts.ModuleKind.CommonJS,
    resolveJsonModule: true,
    target: ts.ScriptTarget.ES2022,
  },
}).outputText;
const routeModule = { exports: {} };
new vm.Script(`(function (require, module, exports) { ${compiled}\n})`)
  .runInThisContext()((specifier) => {
    if (specifier === "../../../../lib/endpoint-snapshot.json") return progressProjection;
    if (specifier === "../../../../lib/endpointDefaults") {
      return {
        projectedDefault: () => null,
        genericDefault: () => ({ status: "degraded" }),
        frontendMetrics: () => "",
      };
    }
    if (specifier === "../../../../lib/frontendBoundary") return boundaryStub;
    return require(specifier);
  }, routeModule, routeModule.exports);

function slugFor(pathname) {
  return pathname.replace(/^\/api\/v1\//, "").split("/");
}

test.afterEach(() => {
  readResponseFactory = () => Response.json(
    { contract_version: "project-progress-v1", overall_percent: 84 },
    { headers: { "x-superbrain-source": "contract-origin-via-d1-edge" } },
  );
});

for (const [pathname, expected] of Object.entries(progressProjection)) {
  test(`stale contract origin yields the current projection for ${pathname}`, async () => {
    const response = await routeModule.exports.GET(
      new Request(`https://frontend.example.test${pathname}`),
      { params: Promise.resolve({ slug: slugFor(pathname) }) },
    );

    assert.equal(response.status, 200);
    assert.equal(response.headers.get("x-superbrain-source"), "project-state-projection");
    assert.deepEqual(await response.json(), expected);
  });
}

test("a current live project-progress response remains authoritative", async () => {
  readResponseFactory = () => Response.json(
    { contract_version: "project-progress-v1", overall_percent: 89 },
    { headers: { "x-superbrain-source": "agent-api-boundary" } },
  );
  const pathname = "/api/v1/project/progress";
  const response = await routeModule.exports.GET(
    new Request(`https://frontend.example.test${pathname}`),
    { params: Promise.resolve({ slug: slugFor(pathname) }) },
  );

  assert.equal(response.headers.get("x-superbrain-source"), "agent-api-boundary");
  assert.equal((await response.json()).overall_percent, 89);
});

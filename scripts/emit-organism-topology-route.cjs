const fs = require("node:fs");
const path = require("node:path");
const ts = require(path.resolve("apps/frontend/node_modules/typescript"));

for (const extension of [".ts", ".tsx"]) {
  require.extensions[extension] = (module, filename) => {
    const source = fs.readFileSync(filename, "utf8");
    const result = ts.transpileModule(source, {
      compilerOptions: {
        module: ts.ModuleKind.CommonJS,
        target: ts.ScriptTarget.ES2022,
        jsx: ts.JsxEmit.ReactJSX,
        esModuleInterop: true,
      },
      fileName: filename,
      reportDiagnostics: true,
    });
    const errors = (result.diagnostics ?? []).filter(
      (diagnostic) => diagnostic.category === ts.DiagnosticCategory.Error,
    );
    if (errors.length > 0) {
      throw new Error(ts.formatDiagnostics(errors, {
        getCanonicalFileName: (fileName) => fileName,
        getCurrentDirectory: () => process.cwd(),
        getNewLine: () => "\n",
      }));
    }
    module._compile(result.outputText, filename);
  };
}

async function main() {
  const routePath = path.resolve("apps/frontend/app/api/v1/organism/topology/route.ts");
  const { GET } = require(routePath);
  const response = await GET();
  if (!(response instanceof Response) || !response.ok) {
    throw new Error("Frontend topology route did not return a successful Response.");
  }
  process.stdout.write(JSON.stringify(await response.json()));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

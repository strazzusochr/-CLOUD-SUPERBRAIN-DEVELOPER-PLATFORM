import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import test from "node:test";

const root = resolve(import.meta.dirname, "..", "..");
const verifier = resolve(root, "scripts", "verify-five-axis-substance-audit.mjs");
const canonicalReport = resolve(root, ".codex", "runs", "CURRENT", "22-page-actions", "report.json");

function runWithReport(reportPath) {
  return spawnSync(process.execPath, [verifier], {
    cwd: root,
    encoding: "utf8",
    env: {
      ...process.env,
      FIVE_AXIS_BROWSER_REPORT: reportPath,
    },
  });
}

test("fails on a tampered browser-evidence status through the explicit evidence boundary", () => {
  const fixtureDir = mkdtempSync(join(tmpdir(), "five-axis-audit-"));
  try {
    const fixturePath = join(fixtureDir, "browser-report.json");
    const fixture = JSON.parse(readFileSync(canonicalReport, "utf8"));
    fixture.status = "tampered";
    writeFileSync(fixturePath, `${JSON.stringify(fixture, null, 2)}\n`, "utf8");

    const result = runWithReport(fixturePath);
    const output = `${result.stdout}\n${result.stderr}`;
    assert.notEqual(result.status, 0, output);
    assert.match(output, /\[five-axis-audit\] browser report is not verified/);
  } finally {
    rmSync(fixtureDir, { recursive: true, force: true });
  }
});

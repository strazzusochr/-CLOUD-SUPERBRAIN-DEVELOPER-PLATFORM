import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import test from "node:test";

const root = resolve(import.meta.dirname, "..", "..");
const verifier = resolve(root, "scripts", "verify-five-axis-substance-audit.mjs");
const canonicalLedger = resolve(root, "docs", "runtime-state", "project-progress-delta-ledger.json");
const canonicalManifest = resolve(root, "docs", "project-progress.manifest.json");

function runLedgerOnly(ledgerPath = canonicalLedger) {
  return spawnSync(process.execPath, [verifier], {
    cwd: root,
    encoding: "utf8",
    env: {
      ...process.env,
      FIVE_AXIS_LEDGER_ONLY: "1",
      PROJECT_PROGRESS_DELTA_LEDGER_PATH: ledgerPath,
    },
  });
}

test("accepts the canonical source-bound v2 delta ledger without browser evidence", () => {
  const result = runLedgerOnly();
  const output = `${result.stdout}\n${result.stderr}`;
  assert.equal(result.status, 0, output);
  assert.match(output, /\[five-axis-audit\] DELTA-LEDGER PASS/);
  const ledger = JSON.parse(readFileSync(canonicalLedger, "utf8"));
  const manifest = JSON.parse(readFileSync(canonicalManifest, "utf8"));
  const layer4 = manifest.vertical.items.find((item) => item.id === "layer_4");
  const layer5 = manifest.vertical.items.find((item) => item.id === "layer_5");
  assert.ok(layer4 && layer5, "canonical manifest must contain L4 and L5");
  assert.match(
    output,
    new RegExp(`L4=${layer4.percent} L5=${layer5.percent} deltas=${ledger.entries.length}`),
  );
});

test("rejects the retired v1 permanent-empty ledger contract without browser evidence", () => {
  const fixtureDir = mkdtempSync(join(tmpdir(), "five-axis-ledger-v1-"));
  try {
    const fixturePath = join(fixtureDir, "delta-ledger.json");
    const fixture = JSON.parse(readFileSync(canonicalLedger, "utf8"));
    fixture.contract_version = "project-progress-delta-ledger-v1";
    writeFileSync(fixturePath, `${JSON.stringify(fixture, null, 2)}\n`, "utf8");

    const result = runLedgerOnly(fixturePath);
    const output = `${result.stdout}\n${result.stderr}`;
    assert.notEqual(result.status, 0, output);
    assert.match(output, /\[five-axis-audit\] progress delta ledger contract drift/);
    assert.doesNotMatch(output, /DELTA-LEDGER PASS/);
  } finally {
    rmSync(fixtureDir, { recursive: true, force: true });
  }
});

test("rejects a structurally typed but unauthenticated v2 ledger entry", () => {
  const fixtureDir = mkdtempSync(join(tmpdir(), "five-axis-ledger-fake-"));
  try {
    const fixturePath = join(fixtureDir, "delta-ledger.json");
    const fixture = JSON.parse(readFileSync(canonicalLedger, "utf8"));
    fixture.entries = [
      {
        entry_id: "synthetic-p3-44-to-45",
        scope: "horizontal",
        cell_id: "phase_3",
        old_percent: 44,
        new_percent: 45,
        overall_percent: 89,
        previous_projection_sha256: "a".repeat(64),
        projection_sha256: "b".repeat(64),
        source_sha: "c".repeat(40),
        verifier_command: "python scripts/fabricated.py",
        artifact_path: ".phase1-artifacts/project-progress/fabricated.json",
        artifact_sha256: "d".repeat(64),
      },
    ];
    writeFileSync(fixturePath, `${JSON.stringify(fixture, null, 2)}\n`, "utf8");

    const result = runLedgerOnly(fixturePath);
    const output = `${result.stdout}\n${result.stderr}`;
    assert.notEqual(result.status, 0, output);
    assert.match(output, /\[five-axis-audit\] project progress verifier failed via/);
    assert.match(output, /\[project-progress\] progress delta ledger entry\[0\]/);
    assert.doesNotMatch(output, /DELTA-LEDGER PASS/);
  } finally {
    rmSync(fixtureDir, { recursive: true, force: true });
  }
});

test("keeps future evidence-backed vertical deltas reachable", () => {
  const source = readFileSync(verifier, "utf8");
  assert.doesNotMatch(source, /L4 must remain verifier-locked at 55%/);
  assert.doesNotMatch(source, /L5 must remain verifier-locked at 56%/);
  assert.match(source, /verifyDeltaLedgerSurface\(\)/);
  assert.match(source, /verifyProjectProgress\(deltaLedgerPath\)/);
});

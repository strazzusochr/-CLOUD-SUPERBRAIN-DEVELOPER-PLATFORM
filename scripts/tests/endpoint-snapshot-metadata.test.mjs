import assert from "node:assert/strict";
import test from "node:test";

import {
  GATE_RELEVANT_PATHS,
  buildSnapshotMetadata,
  canonicalTextSha256,
  endpointPathsFromSnapshot,
} from "../refresh-endpoint-snapshot.mjs";

const allEndpoints = [
  ...GATE_RELEVANT_PATHS,
  "/api/v1/health",
  "/api/v1/platform/inventory",
].sort();

const bindings = {
  activeReleaseId: "prod-candidate-test-rc1",
  sourceCommitSha: "a".repeat(40),
  currentReleaseCandidateSha256: "b".repeat(64),
  releaseCandidateArtifactSha256: "c".repeat(64),
  projectProgressManifestSha256: "d".repeat(64),
  externalGateSummarySha256: "e".repeat(64),
};

test("reserved metadata is not treated as an endpoint", () => {
  const snapshot = Object.fromEntries(allEndpoints.map((path) => [path, {}]));
  snapshot.__snapshot_metadata = { contract_version: "endpoint-snapshot-metadata-v1" };
  assert.deepEqual(endpointPathsFromSnapshot(snapshot), allEndpoints);
});

test("non-reserved non-endpoint keys fail closed", () => {
  assert.throws(
    () => endpointPathsFromSnapshot({ "/api/v1/health": {}, stray: {} }),
    /Unexpected endpoint snapshot key/,
  );
});

test("text binding hashes are stable across LF and CRLF checkouts", () => {
  assert.equal(canonicalTextSha256("a\r\nb\r\n"), canonicalTextSha256("a\nb\n"));
});

test("full refresh without runtime source attestation remains prequalification", () => {
  const metadata = buildSnapshotMetadata({
    allEndpointPaths: allEndpoints,
    selectedPaths: allEndpoints,
    bindings,
    generatedAtUtc: "2026-08-29T12:34:56.000Z",
  });

  assert.equal(metadata.contract_version, "endpoint-snapshot-metadata-v1");
  assert.equal(metadata.refresh_scope, "full");
  assert.equal(metadata.payload_epoch_complete, true);
  assert.equal(metadata.current, false);
  assert.equal(metadata.gate_refresh_atomic, true);
  assert.equal(metadata.candidate_source_commit_sha, "a".repeat(40));
  assert.equal(metadata.runtime_source_commit_sha, null);
  assert.equal(metadata.runtime_source_attested, false);
  assert.equal(metadata.candidate_source_parity, false);
  assert.equal(metadata.qualification_state, "prequalification");
  assert.equal(metadata.current_reason, "runtime_source_unattested_prequalification");
  assert.deepEqual(metadata.refreshed_paths, allEndpoints);
});

test("full refresh becomes current only with matching runtime source attestation", () => {
  const metadata = buildSnapshotMetadata({
    allEndpointPaths: allEndpoints,
    selectedPaths: allEndpoints,
    bindings,
    runtimeSourceAttestation: {
      verified: true,
      sourceCommitSha: "a".repeat(40),
    },
    generatedAtUtc: "2026-08-29T12:34:56.000Z",
  });

  assert.equal(metadata.current, true);
  assert.equal(metadata.runtime_source_attested, true);
  assert.equal(metadata.candidate_source_parity, true);
  assert.equal(metadata.qualification_state, "candidate_source_attested");
  assert.equal(
    metadata.current_reason,
    "all_endpoint_payloads_refreshed_with_candidate_source_parity",
  );
});

test("mismatched runtime source attestation remains non-current", () => {
  const metadata = buildSnapshotMetadata({
    allEndpointPaths: allEndpoints,
    selectedPaths: allEndpoints,
    bindings,
    runtimeSourceAttestation: {
      verified: true,
      sourceCommitSha: "f".repeat(40),
    },
    generatedAtUtc: "2026-08-29T12:34:56.000Z",
  });

  assert.equal(metadata.current, false);
  assert.equal(metadata.runtime_source_attested, true);
  assert.equal(metadata.candidate_source_parity, false);
  assert.equal(metadata.current_reason, "runtime_source_candidate_mismatch");
});

test("partial gate refresh is explicitly non-current and non-atomic", () => {
  const metadata = buildSnapshotMetadata({
    allEndpointPaths: allEndpoints,
    selectedPaths: [GATE_RELEVANT_PATHS[0]],
    bindings,
    generatedAtUtc: "2026-08-29T12:34:56.000Z",
  });

  assert.equal(metadata.refresh_scope, "partial");
  assert.equal(metadata.current, false);
  assert.equal(metadata.gate_refresh_atomic, false);
  assert.equal(metadata.current_reason, "partial_gate_refresh_non_atomic");
});

test("atomic gate set remains non-current when other endpoints are stale", () => {
  const metadata = buildSnapshotMetadata({
    allEndpointPaths: allEndpoints,
    selectedPaths: GATE_RELEVANT_PATHS,
    bindings,
    generatedAtUtc: "2026-08-29T12:34:56.000Z",
  });

  assert.equal(metadata.refresh_scope, "gate_atomic");
  assert.equal(metadata.current, false);
  assert.equal(metadata.gate_refresh_atomic, true);
  assert.equal(metadata.current_reason, "partial_refresh_mixed_epoch");
});

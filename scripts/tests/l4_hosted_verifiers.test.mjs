import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const root = resolve(import.meta.dirname, "..", "..");
const scripts = [
  "verify-llm-hosted-stream-parity.ps1",
  "verify-llm-hosted-fallback.ps1",
  "verify-llm-hosted-budget-guard.ps1",
  "verify-llm-hosted-trace-correlation.ps1",
  "verify-llm-hosted-negative-guards.ps1",
];
const sourceByName = new Map(scripts.map((name) => [name, readFileSync(resolve(root, "scripts", name), "utf8")]));

test("verifiers parse and fail before transport when immutable candidate input is absent", () => {
  for (const name of scripts) {
    const result = spawnSync("pwsh", ["-NoProfile", "-File", resolve(root, "scripts", name)], {
      cwd: root,
      encoding: "utf8",
      env: { ...process.env, CLOUD_SUPERBRAIN_LLM_GATEWAY_TOKEN: "" },
    });
    const output = `${result.stdout ?? ""}\n${result.stderr ?? ""}`;
    assert.notEqual(result.status, 0, `${name} unexpectedly passed without candidate inputs`);
    assert.match(output, /blocker=expected_source_commit_sha_required/, name);
    assert.doesNotMatch(output, /hosted_transport_failed/, `${name} attempted transport before candidate validation`);
  }
});

test("every verifier pins the exact Preview host, fixed token env, and forbids redirects", () => {
  for (const [name, source] of sourceByName) {
    assert.match(source, /SanctionedBaseUrl = "https:\/\/cloud-superbrain-llm-gateway-preview\.strazzusochr\.workers\.dev"/, name);
    assert.match(source, /GatewayTokenEnvName = "CLOUD_SUPERBRAIN_LLM_GATEWAY_TOKEN"/, name);
    assert.doesNotMatch(source, /\[string\]\$GatewayTokenEnvName/, name);
    assert.match(source, /MaximumRedirection\s*=\s*0/, name);
    assert.match(source, /hosted_redirect_forbidden/, name);
    assert.match(source, /unsanctioned_preview_host/, name);
  }
});

test("every verifier binds its own blob, runtime, Wrangler, rubric, gates, HEAD, clean status, and reconstructed archive", () => {
  for (const [name, source] of sourceByName) {
    assert.match(source, /VerifierPath/, name);
    assert.match(source, /RuntimePath/, name);
    assert.match(source, /WranglerPath/, name);
    assert.match(source, /CapabilityPath/, name);
    assert.match(source, /git archive|ArgumentList\.Add\("archive"\)|ArgumentList\.Add\('archive'\)/, name);
    assert.match(source, /source_archive_sha_mismatch/, name);
    assert.match(source, /candidate_head_mismatch/, name);
    assert.match(source, /--porcelain=v1/, name);
    assert.match(source, /--untracked-files=all/, name);
    assert.match(source, /candidate_worktree_drift/, name);
    assert.match(source, /candidate_blob_drift/, name);
  }
});

test("Owner switches are extra confirmations behind tracked live gate and approved rubric authority", () => {
  for (const [name, source] of sourceByName) {
    assert.match(source, /live_llm_provider_calls/, name);
    assert.match(source, /owner_granted/, name);
    assert.match(source, /live_verified/, name);
    assert.match(source, /paid_provider/, name);
    assert.match(source, /owner_grant_ref/, name);
    assert.match(source, /live_llm_owner_grant_ref_untracked/, name);
    assert.match(source, /live_llm_gate_evidence_untracked/, name);
    assert.match(source, /rubric_not_owner_approved/, name);
    assert.match(source, /rubric_owner_grant_ref_missing/, name);
    assert.match(source, /confirmation_required/, name);
  }
});

test("every verifier requires independent D1 evidence and refuses self-declared credit", () => {
  for (const [name, source] of sourceByName) {
    assert.match(source, /\/api\/v1\/evidence\?request_id=/, name);
    assert.match(source, /llm-gateway-independent-evidence-v1/, name);
    assert.match(source, /audit_readback_verified/, name);
    assert.match(source, /independent_evidence_source_mismatch/, name);
    assert.match(source, /source_binding_configured/, name);
    assert.match(source, /FileMode\]::CreateNew/, name);
    assert.match(source, /secret_output/, name);
  }
});

test("provider-call verifiers require independently read real AI Gateway logs", () => {
  for (const name of [
    "verify-llm-hosted-stream-parity.ps1",
    "verify-llm-hosted-fallback.ps1",
    "verify-llm-hosted-trace-correlation.ps1",
  ]) {
    const source = sourceByName.get(name);
    assert.match(source, /OwnerApprovedLiveProviderCalls/, name);
    assert.match(source, /gateway_log_readback/, name);
    assert.match(source, /gateway_log_id/, name);
    assert.match(source, /provider_call_count/, name);
  }
});

test("stream verifier accepts only real OpenAI chunks, deltas, one DONE, and no synthetic terminal", () => {
  const source = sourceByName.get("verify-llm-hosted-stream-parity.ps1");
  assert.match(source, /chat\.completion\.chunk/);
  assert.match(source, /synthetic_terminal_frame_forbidden/);
  assert.match(source, /stream_frame_not_delta/);
  assert.match(source, /doneCount -eq 1/);
  assert.match(source, /real_provider_stream=true/);
  assert.doesNotMatch(source, /terminal evidence object/);
});

test("fallback proves two distinct successful allowlisted gateway logs and the forced reason", () => {
  const source = sourceByName.get("verify-llm-hosted-fallback.ps1");
  assert.match(source, /verification_probe_forced_primary_rejection_after_provider_response/);
  assert.match(source, /fallback_independent_attempt_count/);
  assert.match(source, /fallback_gateway_log_reused/);
  assert.match(source, /provider_call_count = 2/);
});

test("budget and negative guards independently prove exact zero-call contracts", () => {
  const budget = sourceByName.get("verify-llm-hosted-budget-guard.ps1");
  assert.match(budget, /StatusCode -eq 422/);
  assert.match(budget, /input_limit_exceeded/);
  assert.match(budget, /request_input_chars -eq \$inputLength/);
  assert.match(budget, /gateway_log_readback.*required/);

  const negative = sourceByName.get("verify-llm-hosted-negative-guards.ps1");
  assert.match(negative, /Assert-ZeroCallGuard \$missing 401/);
  assert.match(negative, /Assert-ZeroCallGuard \$oversize 422 "input_limit_exceeded"/);
  assert.match(negative, /Assert-ZeroCallGuard \$schema 422 "invalid_messages"/);
  assert.match(negative, /Assert-ZeroCallGuard \$policy 403 "model_not_allowed"/);
});

test("trace verifier derives correlation from gateway-log metadata plus D1 readback", () => {
  const source = sourceByName.get("verify-llm-hosted-trace-correlation.ps1");
  assert.match(source, /metadata\.trace_id/);
  assert.match(source, /metadata\.request_id/);
  assert.match(source, /metadata_correlation_verified/);
  assert.match(source, /gateway_log_id_sha256/);
  assert.match(source, /d1_evidence_ref/);
});

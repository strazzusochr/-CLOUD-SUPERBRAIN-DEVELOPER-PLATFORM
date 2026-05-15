# Active Verifier Sweep Bundle Proof

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
environment: `production-candidate`
source_commit_sha: `5abca83a7680ea680a65a8e3e8f70a368ed79db7`
immutable_image_commit_sha: `5abca83a7680ea680a65a8e3e8f70a368ed79db7`
base_url: `https://188-34-191-140.sslip.io`
production_rollout_claimed: `false`
verifier_gate_count: `18`
changed_horizontal: `Phase 2 88->89; Phase 5 84->86`
changed_vertical: `Agent Pool 75->76; Memory 73->74`

## Verified Gates

- `current-release-candidate`
- `active-release-candidate-bundle`
- `hosted-staging-smoke`
- `phase3-active-gateway-policy-bundle`
- `phase5-active-runtime-guard-matrix-bundle`
- `phase5-active-gateway-execution-bundle`
- `phase5-active-memory-operations-bundle`
- `phase5-active-memory-success-correlation-bundle`
- `phase5-active-agent-operations-bundle`
- `phase5-active-agent-success-correlation-bundle`
- `phase5-active-llm-operations-bundle`
- `phase5-active-llm-success-correlation-bundle`
- `phase5-active-mcp-operations-bundle`
- `phase5-active-mcp-success-correlation-bundle`
- `phase4-llm-model-catalog`
- `phase4-mcp-capability-catalog`
- `security`
- `evidence-artifact-safety`

## Verification Commands

- `scripts\verify-phase5-active-verifier-sweep-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase5-suite-active-candidate-plan.ps1`

## Non-Claims

- This proof does not claim a production rollout.
- This proof does not claim release promotion.
- This proof does not claim live LLM provider calls.
- This proof does not claim live MCP writes.
- This proof does not claim local model downloads.
- This proof does not include secret values.

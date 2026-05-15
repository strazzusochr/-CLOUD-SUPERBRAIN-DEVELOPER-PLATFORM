# Active Verifier Sweep Bundle Proof

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
environment: `production-candidate`
source_commit_sha: `b9734ad55dc6488a56acca693b50ec9019bab01b`
immutable_image_commit_sha: `b9734ad55dc6488a56acca693b50ec9019bab01b`
base_url: `https://188-34-191-140.sslip.io`
production_rollout_claimed: `false`
verifier_gate_count: `14`
changed_horizontal: `Phase 5 81->82`
changed_vertical: `MCP Gateway 65->66`

## Verified Gates

- `current-release-candidate`
- `active-release-candidate-bundle`
- `hosted-staging-smoke`
- `phase3-active-gateway-policy-bundle`
- `phase5-active-runtime-guard-matrix-bundle`
- `phase5-active-gateway-execution-bundle`
- `phase5-active-memory-operations-bundle`
- `phase5-active-agent-operations-bundle`
- `phase5-active-llm-operations-bundle`
- `phase5-active-mcp-operations-bundle`
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

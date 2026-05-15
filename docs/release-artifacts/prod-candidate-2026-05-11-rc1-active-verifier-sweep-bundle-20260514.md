# Active Verifier Sweep Bundle Proof

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
environment: `production-candidate`
source_commit_sha: `5abca83a7680ea680a65a8e3e8f70a368ed79db7`
immutable_image_commit_sha: `5abca83a7680ea680a65a8e3e8f70a368ed79db7`
base_url: `https://188-34-191-140.sslip.io`
production_rollout_claimed: `false`
verifier_gate_count: `8`
changed_horizontal: `Phase 5 74->75`
changed_vertical: `none`

## Verified Gates

- `scripts\verify-current-release-candidate.ps1 -BaseUrl https://188-34-191-140.sslip.io -ReleaseId prod-candidate-2026-05-11-rc1`
- `scripts\verify-active-release-candidate-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io -ReportOnly -JsonOnly`
- `scripts\verify-hosted-staging-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase3-active-gateway-policy-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase4-llm-model-catalog.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase4-mcp-capability-catalog.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-security.ps1`
- `scripts\verify-evidence-artifact-safety.ps1`

## Evidence Bound

- Active release-candidate status: `prod-candidate-2026-05-11-rc1`, `production_rollout_claimed=false`, active bundle `status=passed`, `gate_count=3`
- Hosted staging status: root/API smoke remains HTTP `200`, project progress is `80%`, Phase 5 is `77%`, and immutable selector remains `5abca83a7680ea680a65a8e3e8f70a368ed79db7`
- Gateway policy status: Active Gateway Policy Bundle remains verified with LLM/MCP catalogs, audit snapshots, gateway-correlation policy surfaces, and no live provider/MCP writes
- Safety status: security scan and evidence-artifact-safety pass without adding secret values or raw payload material

## Non-Claims

- This proof does not claim a production rollout.
- This proof does not claim release promotion.
- This proof does not claim live LLM provider calls.
- This proof does not claim live MCP writes.
- This proof does not claim local model downloads.
- This proof does not claim provider billing proof.
- This proof does not include secret values.

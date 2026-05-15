# Active Runtime Guard Matrix Bundle

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
environment: `production-candidate`
source_commit_sha: `984254f78c3f9fe0363ac2e8f3468f4b1c49ab05`
immutable_image_commit_sha: `984254f78c3f9fe0363ac2e8f3468f4b1c49ab05`
base_url: `https://188-34-191-140.sslip.io`
local_control_plane_url: `http://localhost:8081`
production_rollout_claimed: `false`
runtime_guard_gate_count: `6`
changed_horizontal: `none`
changed_vertical: `none`

## Bound Runtime Guards

- Live Agent Control metadata guard: `live_agent_metadata_guard_enforced`
- Live Agent history surface: `live_agent_steering_history_visible`
- LLM runtime guard parity: `llm_runtime_guard_parity_visible`
- LLM responses guard path: `POST /llm/v1/responses`
- MCP unsupported toolset guard: `mcp_unsupported_toolset_guard`
- MCP secret redaction guard: `mcp_secret_redaction_guard`

## Verification Commands

- `scripts\verify-phase5-active-runtime-guard-matrix-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-phase5-active-runtime-guard-matrix-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase3-live-agent-steering.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase3-live-agent-history.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase4-llm-live-provider-guard.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-phase4-mcp-security-guard.ps1 -BaseUrl https://188-34-191-140.sslip.io`

## Guarantees

- The active RC1 now binds the hosted candidate to live-agent steering/history runtime guards plus LLM/MCP gateway guard surfaces.
- Current progress authority remains enforced at `overall=80`, `phase_3=95`, `phase_5=79`, `agent_pool=74`, `llm_gateway=64`, and `mcp_gateway=65`.
- This proof does not claim a production rollout.
- This proof does not claim release promotion.
- This proof does not claim live LLM provider calls.
- This proof does not claim live MCP writes.
- This proof does not claim local model downloads.
- This proof does not include secret values.

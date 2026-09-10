# Gateway Correlation Snapshot Immutable Staging Proof

Release ID: `prod-candidate-2026-05-11-rc1`
Status: `verified`
Candidate SHA: `10df3ea48627e6f11787587e3c984b72107e78f5`
Environment: `hetzner-staging`
Production rollout claimed: `false`
Promotion allowed: `false`

## Machine Contract

release_id: `prod-candidate-2026-05-11-rc1`
candidate_sha: `10df3ea48627e6f11787587e3c984b72107e78f5`
production_rollout_claimed: `false`
hosted_selector_observed: `IMAGE_TAG=10df3ea48627e6f11787587e3c984b72107e78f5`
image_pattern: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:10df3ea48627e6f11787587e3c984b72107e78f5`
parity_verifier: `scripts\verify-current-immutable-staging-parity.ps1 -RequireVerified`

## Scope

This proof binds the Phase 3 Agent/LLM/MCP Gateway Correlation Snapshot to the active immutable staging candidate. It is a read-only audit-log projection and does not enable live provider calls, live MCP writes, production rollout, or release promotion.

## Runtime Evidence

- Contract endpoint: `GET /api/v1/security/gateway-correlation/contract`
- Snapshot endpoint: `GET /api/v1/security/gateway-correlation/snapshot`
- Evidence refs: `gateway_correlation_snapshot_visible`, `gateway_correlation_redaction_enforced`, `gateway_correlation_no_live_write_guard`
- Source event types: `task_completed`, `autonomous_team_dispatch`, `langgraph_dry_run_completed`, `langgraph_dry_run_stopped`, `llm_gateway_request`, `mcp_tool_executed`
- Snapshot fields: `prompt_bodies_returned=false`, `tool_input_refs_returned=false`, `provider_credentials_returned=false`, `forbidden_pattern_hits=0`, `live_provider_calls_claimed=false`, `live_mcp_writes_claimed=false`
- Correlation proof: the verifier seeds one deterministic agent task, one LLM Gateway dry-run audit row, and one denied MCP audit row under the same trace id, then requires an `agent_llm_mcp_correlated` group with zero live provider calls and zero live MCP writes.

## Verification

- Local compile: `py -3 -m py_compile services\agent-api\app\main.py`
- Frontend build: `npm run build` in `apps/frontend`
- Local verifier: `scripts\verify-phase3-gateway-correlation-snapshot.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Local browser contract: `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Manifest verifier: `py -3 scripts\verify_project_progress_manifest.py`
- GHCR build/push: `scripts\build-and-push.ps1 -Tag 10df3ea48627e6f11787587e3c984b72107e78f5 -Platforms linux/arm64 -Builder codex-multiarch`
- Hetzner deploy: `scripts\deploy-to-staging.ps1 -UseImageFilesystem -ImageTag 10df3ea48627e6f11787587e3c984b72107e78f5`
- Hosted verifier: `scripts\verify-phase3-gateway-correlation-snapshot.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Hosted Phase 3 suite: `scripts\verify.ps1 -Suite phase3 -BaseUrl https://188-34-191-140.sslip.io -FailFast`
- Hosted browser contract: `scripts\verify-browser-contract.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Hosted smoke: `scripts\verify-hosted-staging-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`

## Progress Impact

- Overall: `77%`
- Phase 3 - Product Surface & Security: `74%`
- Agent Pool: `73%`
- LLM Gateway: `61%`
- MCP Gateway: `61%`
- Memory: unchanged at `72%`
- Observability: unchanged at `99%`

## Non-Claims

- No production rollout.
- No production promotion.
- No live provider call.
- No live MCP write.
- No provider billing proof.
- No external SOC/SIEM completeness claim.
- No secret exposure clearance beyond the verifier-scoped redaction snapshot.

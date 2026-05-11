# Executed Candidate Smoke Recheck

Status: `verified`
release_id: `prod-candidate-2026-05-05-rc1`
environment: `production-candidate`
base_url: `https://188-34-191-140.sslip.io`
executed_at_utc: `2026-05-07T09:10:00Z`
overall_percent: `70`
phase_4_percent: `100`
phase_5_percent: `67`
integrity_status: `verified`
external_gates_status: `verified`
owner_decision: `no-release`

## Goal

Record one fresh candidate-scoped hosted smoke recheck against the current truth after the newer Phase-5 evidence chain, without overwriting the older historical smoke artifact.

## Executed Sequence

1. Re-check hosted root title.
2. Re-check hosted Agent API, MCP, and LLM health endpoints.
3. Re-check hosted project progress, integrity, completion, external gates, and gate mirror.
4. Re-check hosted deployment preflight contract.

## Results

- Root title marker: `Cloud Superbrain`
- Current progress carried in smoke recheck: `overall=70`, `phase5=67`
- Hosted integrity remained `verified`
- Completion remained fail-closed with `can_set_all_to_100=false`
- External gates and mirror remained `verified`
- Candidate decision remained `no-release`

## Non-Claims

- This is not a production rollout proof.
- This does not claim all phases are complete.
- This does not override the current `no-release` decision.

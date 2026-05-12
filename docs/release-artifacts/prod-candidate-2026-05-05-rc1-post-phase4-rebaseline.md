# Executed Candidate Post-Phase4 Rebaseline

Status: `verified`
release_id: `prod-candidate-2026-05-05-rc1`
environment: `production-candidate`
base_url: `https://188-34-191-140.sslip.io`
executed_at_utc: `2026-05-07T05:20:00Z`
overall_percent: `70`
phase_4_percent: `100`
phase_5_percent: `67`
integrity_status: `verified`
external_gates_status: `verified`
completion_can_set_all_to_100: `false`
owner_decision: `no-release`

## Goal

Record one fresh candidate-scoped rebaseline after the full hosted Phase-4 contract/runtime closure so Release Readiness continues from the current real hosted truth rather than from older partial integration totals.

## Hosted Truth Recheck

- `GET /api/v1/health` remains healthy on the hosted candidate.
- `GET /api/v1/project/progress` now exposes:
  - overall `69`
  - `phase_4=100`
  - `phase_5=63`
- `GET /api/v1/project/progress/integrity` remains `verified`.
- `GET /api/v1/project/progress/completion` remains fail-closed with `can_set_all_to_100=false`.
- `GET /api/v1/external-gates` remains `verified`.

## Candidate Binding

- The candidate remains a `production-candidate`, not a production rollout.
- The current `owner_decision` remains `no-release`.
- The fresh rebaseline is anchored after the completed hosted Phase-4 system-fallback proof:
  - `.phase1-artifacts/phase4-system-fallback-contract-runtime-hosted-proof-20260507.md`

## Non-Claims

- This is not a production rollout proof.
- This does not claim live external provider execution.
- This does not override the current `no-release` decision.

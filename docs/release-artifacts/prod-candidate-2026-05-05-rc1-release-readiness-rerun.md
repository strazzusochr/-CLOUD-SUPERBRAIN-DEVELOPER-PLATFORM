# Release Readiness Rerun

Status: `verified`
release_id: `prod-candidate-2026-05-05-rc1`
environment: `production-candidate`
base_url: `https://188-34-191-140.sslip.io`
executed_at_utc: `2026-05-07T14:30:00Z`
overall_percent: `70`
phase_4_percent: `100`
phase_5_percent: `67`
integrity_status: `verified`
external_gates_status: `verified`
owner_decision: `no-release`

## Goal

Re-run one candidate-scoped release-readiness pass against the current hosted truth after the latest browser, rollback-lane, and truth-mirror repairs.

## Executed Sequence

1. Re-check the active candidate artifact and required linked proofs.
2. Re-check the release checklist and the active runbooks.
3. Re-check hosted health, project progress, integrity, completion, and external gates.
4. Re-check that current browser evidence remains active candidate evidence.

## Results

- Active candidate artifact remained linked to the current proof chain.
- Release checklist and active runbooks remained applicable.
- Hosted health remained healthy and hosted truth remained `overall=70`, `phase5=67`.
- Hosted integrity remained `verified`.
- Hosted completion remained fail-closed with `can_set_all_to_100=false`.
- Browser evidence remained active candidate evidence.
- Candidate decision remained `no-release`.

## Non-Claims

- This is not a production rollout proof.
- This does not approve a release.
- This does not override the current `no-release` decision.

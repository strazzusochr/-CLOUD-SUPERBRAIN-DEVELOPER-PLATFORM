# Post-Rollback Requalification Rerun

Status: `verified`
Candidate: `prod-candidate-2026-05-05-rc1`
Hosted URL: `https://188-34-191-140.sslip.io`
Executed at UTC: `2026-05-07T14:25:00Z`
overall_percent: `70`
phase_4_percent: `100`
phase_5_percent: `67`
integrity_status: `verified`
external_gates_status: `verified`
Hosted selector after requalification: `IMAGE_TAG=staging`
owner_decision: `no-release`

## Goal

Re-run the candidate-scoped post-rollback requalification lane against the current hosted truth after the later browser and completion-truth repairs.

## Executed Sequence

1. Re-check the existing executed rollback proof and the original requalification proof.
2. Re-check the hosted selector on Hetzner and confirm it is still `IMAGE_TAG=staging`.
3. Re-check hosted root, Agent API, MCP, and LLM health endpoints.
4. Re-check hosted progress, integrity, completion, and external-gate truth.

## Results

- Hosted selector remained `IMAGE_TAG=staging`.
- Hosted root, Agent API, MCP, and LLM endpoints remained `200`.
- Hosted progress remained manifest-backed at `overall=70`, `phase5=67`.
- Hosted integrity remained `verified`.
- Hosted completion remained fail-closed with `can_set_all_to_100=false`.
- Hosted external gates remained `verified`.
- Candidate decision remained `no-release`.

## Non-Claims

- This is not a production rollout proof.
- This does not approve a release.
- This does not override the current fail-closed completion gate.

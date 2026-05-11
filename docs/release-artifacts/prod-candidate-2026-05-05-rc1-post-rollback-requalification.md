# Release Artifact

Status: `verified`
Candidate: `prod-candidate-2026-05-05-rc1`
Scope: `post-rollback candidate requalification on hosted staging`
Hosted URL: `https://188-34-191-140.sslip.io`
Executed rollback proof: `.phase1-artifacts/phase5-executed-rollback-prod-candidate-20260505-rc1.md`
Hosted selector after requalification: `IMAGE_TAG=staging`
Hosted root status: `200`
Hosted Agent API status: `200`
Hosted MCP status: `200`
Hosted LLM status: `200`
Hosted progress remained manifest-backed: `yes`
Hosted integrity remained verified: `yes`
External gates remained verified: `yes`
Completion contract remained fail-closed: `yes`
Production rollout claim introduced: `no`

## Requalification Scope

- Confirm the host returned to the mutable candidate selector after the executed immutable rollback proof
- Re-check hosted root, Agent API, MCP Gateway, and LLM Gateway health
- Re-check hosted project progress, integrity, completion, and external-gate truth
- Preserve the current `no-release` decision

## Decision

- Candidate remains valid as a production-candidate artifact
- Candidate remains blocked from rollout by explicit `no-release`
- Executed rollback proof is now followed by a successful hosted requalification pass

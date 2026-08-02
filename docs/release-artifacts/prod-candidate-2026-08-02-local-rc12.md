# Release Artifact

release_id: `prod-candidate-2026-08-02-local-rc12`
scope: `Session 16 completion-transition slice: portable CI contracts, diagnosable build boundary, and a six-service candidate rebound to the frozen source`
environment: `production-candidate`
source_branch: `claude/cloud-superbrain-analysis-127d2e`
source_commit_sha: `44c69506d78f4b6f0043a2719efbe7200eb07cd9`
source_commit_semantics: `frozen completion-transition source: six platform fixes that made the Phase-6 CI contracts executable on ubuntu-latest, two hardened runtime assertions, a diagnosable generation boundary, and the untracked TypeScript build cache removed`
immutable_image_commit_sha: `44c69506d78f4b6f0043a2719efbe7200eb07cd9`
workflow_run_url: `pending-source-checkout-attestation`
pipeline_status: `pending: pr-check must run with candidate_sha=44c69506d78f4b6f0043a2719efbe7200eb07cd9 and source_prequalification=true so the source-checkout attestation binds this candidate`
smoke_result: `passed DEV-ONLY; six-service candidate images verified, runtime chain 86 checks, browser chain green including 22 routes and 161 page-local actions; hosted proof still blocked`
observability_check: `present`
rollback_note: `local rollback target is RC11 source bae3cdc1692e1e99e7f546f72664a3c747958b8c; no hosted rollback is authorized or executed`
rollback_target_commit_sha: `bae3cdc1692e1e99e7f546f72664a3c747958b8c`
immutable_tag_set: `ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:44c69506d78f4b6f0043a2719efbe7200eb07cd9`
immutable_tag_publish_status: `unpublished`
rollback_drill_proof: `docs/runbooks/rollback-deploy.md`
executed_rollback_rerun_proof: `docs/release-artifacts/prod-candidate-2026-08-02-local-rc12-readiness.json`
owner_decision_proof: `docs/runtime-state/owner-input-manifest.json`
budget_review_proof: `docs/release-artifacts/prod-candidate-2026-08-02-local-rc12-readiness.json`
open_questions_acceptance_proof: `docs/release-artifacts/prod-candidate-2026-08-02-local-rc12-readiness.json`
risk_review_recheck_proof: `docs/release-artifacts/prod-candidate-2026-08-02-local-rc12-readiness.json`
provenance_review_proof: `docs/release-artifacts/prod-candidate-2026-08-02-local-rc12-readiness.json`
smoke_recheck_proof: `docs/release-artifacts/prod-candidate-2026-08-02-local-rc12-readiness.json`
observability_recheck_proof: `docs/release-artifacts/prod-candidate-2026-08-02-local-rc12-readiness.json`
browser_evidence_reactivation_proof: `docs/release-artifacts/prod-candidate-2026-08-02-local-rc12-readiness.json`
browser_proof: `docs/release-artifacts/prod-candidate-2026-08-02-local-rc12-readiness.json`
post_rollback_browser_revalidation_proof: `not-applicable-retired-rc1-boundary`
final_browser_e2e_recheck_proof: `docs/release-artifacts/prod-candidate-2026-08-02-local-rc12-readiness.json`
full_verifier_sweep_proof: `docs/release-artifacts/prod-candidate-2026-08-02-local-rc12-readiness.json`
truth_mirror_rebaseline_proof: `docs/runtime-state/phase5-credit-itemization.json`
release_readiness_rerun_proof: `docs/release-artifacts/prod-candidate-2026-08-02-local-rc12-readiness.json`
browser_rerun_status: `passed DEV-ONLY on 2026-08-02; browser contract, product acceptance with a real Cloudflare Workers AI generation, 22-page actions, and the O4 write proof all green against this exact source`
review_gate: `pending`
owner_decision: `no-release`
hosted_staging_parity: `false`
production_rollout_claimed: `false`
checklist_verified_count: `17`
checklist_blocked_count: `2`
phase5_computed_percent: `89`

## Phase-5 Readiness Checklist

| ID | JA/NEIN | Beleg |
| --- | --- | --- |
| C1 | JA | Source-gebundener GitHub-Actions-Lauf in der Readiness-Evidenz, gebunden ueber die Source-Checkout-Attestation. |
| C2 | JA | Runtime, Browser, Security, Candidate-Images und Candidate-Runtime sind gruen und gehasht. |
| C3 | JA | Manifest, State, Handoff, Register und Release-Dokumente sind synchronisiert. |
| C4 | JA | Der Current-Candidate-Verifier erlaubt nur den exakten vierteiligen Post-Proof-Wahrheitsuebergang; sonstigen Runtime-Drift verweigert er. |
| C5 | JA | npm audit und kanonischer Secret-Scan sind kandidatenbezogen gruen. |
| I1 | NEIN | Kein non-local HTTPS-Hosted-Stack ist exakt an RC12 gebunden. |
| I2 | JA | Sechs Clean-Archive-Images sind lokal content-addressed verifiziert; GHCR bleibt Post-Market. |
| I3 | JA | RC11-Source ist als unveraenderter lokaler Rollbackanker benannt. |
| I4 | JA | Kein neuer Provider, Paid-Tier, Kartenbedarf oder wiederkehrender Betrag. |
| I5 | NEIN | `production_auth_identity` bleibt ohne Owner-OAuth-Einwilligung geschlossen. |
| V1 | JA | Health-, Metrics- und Audit-Pfade sind unten exakt benannt. |
| V2 | JA | Error-, Rate-, Session-, Request- und Trace-Vertraege sind gebunden. |
| V3 | JA | CI-, Verifier-, Browser-, Image- und Truth-Artefakte sind verlinkt. |
| V4 | JA | Incident-Eskalation und Stop-Gates sind gebunden. |
| O1 | JA | Immutable Rollback-Runbook ist auf RC11 als Ziel anwendbar. |
| O2 | JA | Incident-Response- und Secret-Rotation-Runbooks sind vorhanden. |
| O3 | JA | Review bleibt pending; no-release ist explizit und fail-closed. |
| O4 | JA | Die zwei bekannten Restfragen sind unter no-release explizit akzeptiert. |
| O5 | JA | Production, Promotion, Registry-Publikation und Rollout bleiben false. |

## Candidate-Bound Observability

- Health: `/api/v1/health`, `/mcp/api/v1/health`, `/llm/api/v1/health`.
- Metrics: `/api/v1/metrics`.
- Audit: `/api/v1/audit/recent`, `/api/v1/audit/mcp`.
- Contracts: `/api/v1/errors/contract`, `/api/v1/rate-limit/contract`,
  `/api/v1/sessions/history/contract`, `/api/v1/request/contract`,
  `/api/v1/trace/contract`.
- Escalation: `docs/runbooks/incident-response.md`.

## Budget Review

- New recurring infrastructure: none.
- Paid provider/tier: none.
- Card/payment action: none.
- Existing ceiling: maximum 20 EUR/month; unchanged.
- GHCR publication: Post-Market Owner action, not executed and not credited.

## Open Questions Accepted Under No-Release

1. I1 stays `NEIN` until a non-local HTTPS surface is source-bound to RC12.
2. I5 stays `NEIN` until the Owner completes production OAuth and the hosted
   fail-closed verifier passes.

There is no unknown autonomous checklist work. Both known gaps remain zero
credit and block a `100%` Phase-5 claim.

## What This Candidate Changes Against RC11

RC11 qualified a source in which the Phase-6 scale contracts could not execute in CI at all:
the npm entry point handed pwsh a Windows path, so the step printed PowerShell's help text and
thirteen later steps were skipped without ever running. RC12 freezes a source in which that
step, its dedicated dispatch-only workflow, and the deep evidence verifier all execute on
ubuntu-latest. It also carries two runtime assertions that were rewritten to match hardened API
behaviour instead of the leaked pre-hardening responses, and a generation boundary that can now
report why a build failed instead of collapsing every cause into one opaque message.

## Guardrails / Non-Claims

- DEV-ONLY; hosted proof still blocked.
- Local Docker image IDs are not registry digests.
- GHCR publication is Post-Market under E3 and remains unexecuted.
- `docker_registry_publish` remains owner-granted false and live-verified false.
- This artifact does not claim a production rollout.
- Production deployment still requires the release-candidate gate bundle and a separate rollout proof.
- No registry push, provider write, production deploy, release promotion,
  Owner approval, payment, or secret output is performed.

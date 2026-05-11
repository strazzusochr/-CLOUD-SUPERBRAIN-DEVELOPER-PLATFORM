# Release Artifact Template

release_id: `<set-me>`
scope: `<components-or-features>`
environment: `staging|production-candidate|production`
source_branch: `<branch-name>`
source_commit_sha: `<git-sha>`
workflow_run_url: `<github-actions-run-url>`
pipeline_status: `<link-or-proof>`
smoke_result: `passed|blocked`
observability_check: `present|missing`
rollback_note: `<short-rollback-path>`
immutable_tag_set: `<immutable-tag-or-digest-set>`
rollback_drill_proof: `<artifact-path>`
executed_rollback_rerun_proof: `<artifact-path>`
owner_decision_proof: `<artifact-path>`
budget_review_proof: `<artifact-path>`
open_questions_acceptance_proof: `<artifact-path>`
risk_review_recheck_proof: `<artifact-path>`
provenance_review_proof: `<artifact-path>`
smoke_recheck_proof: `<artifact-path>`
observability_recheck_proof: `<artifact-path>`
browser_evidence_reactivation_proof: `<artifact-path>`
browser_proof: `<artifact-path>`
post_rollback_browser_revalidation_proof: `<artifact-path>`
final_browser_e2e_recheck_proof: `<artifact-path>`
full_verifier_sweep_proof: `<artifact-path>`
truth_mirror_rebaseline_proof: `<artifact-path>`
release_readiness_rerun_proof: `<artifact-path>`
browser_rerun_status: `<current-browser-evidence-state>`
review_gate: `reviewed|pending`
owner_decision: `approved|blocked|no-release|pending`

## Code Readiness

- [ ] CI/CD successful
- [ ] Smoke successful
- [ ] Integration plan documented
- [ ] Docs/registers aligned
- [ ] No unexplained critical/high blocker

## Infrastructure Readiness

- [ ] Hosted staging verified
- [ ] GHCR candidate images verified
- [ ] Rollback path named
- [ ] Budget impact reviewed
- [ ] No unresolved branch/secret/auth gate

## Observability Readiness

- [ ] Health paths named
- [ ] Metrics paths named
- [ ] Audit paths named
- [ ] Evidence artifacts linked
- [ ] Escalation path named

## Operations Readiness

- [ ] Rollback runbook applicable
- [ ] Incident response runbook present
- [ ] Secret rotation runbook present
- [ ] Owner review documented
- [ ] Release-relevant open questions explicitly accepted for this candidate
- [ ] Production non-claim preserved until rollout proof exists

## Notes

- Add exact links to hosted proof artifacts and workflow runs here.
- Name the immutable rollback target here; do not rely only on mutable tags like `:staging`.
- Add candidate-scoped budget, open-question, provenance, smoke-recheck, observability-recheck, browser rerun, verifier-sweep, and truth-mirror proofs here once they exist.

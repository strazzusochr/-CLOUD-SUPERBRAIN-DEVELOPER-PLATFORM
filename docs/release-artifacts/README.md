# Release Artifacts

Stand: 2026-05-05
Status: Active baseline for Phase 5

## Zweck

Dieses Verzeichnis enthaelt ausgefuellte Release-Kandidaten-Artefakte.
Jeder Release-Kandidat bekommt genau eine eigene Markdown-Datei.

## Namensregel

- `docs/release-artifacts/<release_id>.md`

Beispiele:

- `docs/release-artifacts/staging-2026-05-05.md`
- `docs/release-artifacts/prod-candidate-2026-05-05.md`

## Pflicht

1. Das Artefakt muss auf `docs/release-checklist.md` basieren.
2. Owner-Review muss sichtbar sein.
3. Workflow-Run und Commit-SHA fuer den Candidate muessen sichtbar sein.
4. Rollback-Note muss sichtbar sein und einen immutable GHCR-Tag oder Digest als Ruecksprungziel nennen.
5. Production darf nicht als erfolgreich behauptet werden, solange der Rollout nicht separat verifiziert wurde.
6. Aktive Kandidaten muessen candidate-scoped Budget-, Open-Questions-, Provenance-, Smoke-Recheck- und Observability-Recheck-Belege fuehren, sobald die neueren Hosted-Truth-Rechecks vorliegen.
7. Aktive Kandidaten muessen ausserdem die aktuelle Decision-/Rerun-Kette sichtbar fuehren:
   - `owner_decision_proof`
   - `executed_rollback_rerun_proof`
   - `browser_evidence_reactivation_proof`
   - `browser_proof`
   - `post_rollback_browser_revalidation_proof`
   - `final_browser_e2e_recheck_proof`
   - `full_verifier_sweep_proof`
   - `truth_mirror_rebaseline_proof`
   - `release_readiness_rerun_proof`
   - `browser_rerun_status`

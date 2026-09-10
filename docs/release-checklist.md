# Release Checklist

Stand: 2026-07-31
Status: Active baseline for Phase 5
Bezug: `TEIL 0`, `TEIL 10`, Phase 5 Release-Readiness
Rubrik: `phase5-release-readiness-19-v2`

## 1. Zweck

Diese Checkliste ist die verbindliche Mindestpruefung vor jedem Release.
Sie ist als Git-Artefakt zu fuehren und darf nicht still uebersprungen werden.
Ein Release ist nicht release-ready, solange diese Checkliste nicht als konkretes Artefakt fuer genau einen Release-Kandidaten ausgefuellt wurde.

## 2. Pflichtstruktur

Die Release-Checkliste besteht aus genau vier Sektionen:

1. Code Readiness
2. Infrastructure Readiness
3. Observability Readiness
4. Operations Readiness

Alle Items werden als `JA/NEIN` gefuehrt.
Vage Aussagen sind nicht zulaessig.

Die 19 Pflichtitems sind gleichgewichtete binaere Einheiten. Der Phase-5-Wert
ist `round(JA / 19 * 100)`. Ein `NEIN` bleibt ohne Teilcredit. Damit ist der
historische Stand `13/19 = 68%` und die damalige Luecke `6/19 = 32%`
reproduzierbar. Die sechs eingefrorenen RC1/sslip.io-Historienmarker sind keine
Rubrikitems und erhalten keinen Credit.

Phase 5 misst Release-Candidate-Readiness. Nach Ruling E3 ist die
GHCR-Publikation ein Post-Market-Schritt: Item I2 prueft die lokale,
content-addressed Verifizierbarkeit der sechs Kandidaten-Images. Es oeffnet
keinen Registry-Gate, ersetzt keinen Digest und autorisiert keinen Push.

## 3. Code Readiness

- [ ] C1: CI/CD-Pipeline fuer den Zielstand ist erfolgreich durchgelaufen.
- [ ] C2: Release-relevante Tests und Smoke-Probes sind dokumentiert und gruen.
- [ ] C3: Relevante ADRs, Register und Handoff-Dokumente sind aktuell oder bewusst unveraendert.
- [ ] C4: Kein unerklaerter Drift zwischen Manifest, Runtime und Verification Register.
- [ ] C5: Kein offener Critical/High-Befund ohne explizite Owner-Entscheidung.

## 4. Infrastructure Readiness

- [ ] I1: Hosted Staging ist fuer den Kandidaten ueber non-local HTTPS verifiziert.
- [ ] I2: Sechs content-addressed Kandidaten-Images sind lokal verifiziert; GHCR-Publikation bleibt Post-Market.
- [ ] I3: Rollback-Zielbild ist fuer den Release-Kandidaten benannt.
- [ ] I4: Kosten-/Budget-Auswirkung ist bewertet und dokumentiert.
- [ ] I5: Keine offene Secret-, Auth- oder Branch-Protection-Luecke ohne Owner-Freigabe.

## 5. Observability Readiness

- [ ] V1: Health-, Metrics- und Audit-Pfade fuer den Releaseumfang sind benannt.
- [ ] V2: Relevante Fehler-, Rate-, Session-, Request- und Trace-Contracts sind sichtbar.
- [ ] V3: Release-relevante Dashboards oder Proof-Artefakte sind verlinkt.
- [ ] V4: Alarm-/Eskalationspfad fuer den Releaseumfang ist dokumentiert.

## 6. Operations Readiness

- [ ] O1: Rollback-Runbook ist fuer diesen Release-Kandidaten anwendbar.
- [ ] O2: Incident-Response- und Secret-Rotation-Runbooks sind vorhanden.
- [ ] O3: Owner-Review-Gate ist dokumentiert.
- [ ] O4: Release-relevante offene Fragen sind geklaert oder explizit akzeptiert.
- [ ] O5: Production-Deploy wird nicht behauptet, solange kein owner-reviewed Rollout erfolgt ist.

## 7. Git-Artefakt

Jeder Release-Kandidat muss ein ausgefuelltes Artefakt unter diesem Pfad erhalten:

- `docs/release-artifacts/<release_id>.md`

Pflichtfelder:

| Feld | Inhalt |
| --- | --- |
| `release_id` | eindeutige Build-, Tag- oder Candidate-Referenz |
| `scope` | betroffene Komponenten oder Features |
| `environment` | staging / production-candidate / production |
| `source_branch` | Quell-Branch des aktiven Candidates |
| `source_commit_sha` | commit-genauer Candidate-SHA |
| `workflow_run_url` | bindender Workflow-Run fuer den Candidate |
| `pipeline_status` | Link oder Nachweis des erfolgreichen Laufs |
| `smoke_result` | passed / blocked |
| `observability_check` | present / missing |
| `rollback_note` | kurzer Ruecksetzpfad |
| `immutable_tag_set` | geplanter immutable GHCR-Tag plus lokaler content-addressed Image-Beleg; Publikation bleibt Post-Market |
| `review_gate` | reviewed / pending |
| `owner_decision` | approved / blocked / no-release / pending |
| `owner_decision_proof` | expliziter Owner-Decision-Beleg |
| `budget_review_proof` | candidate-scoped Budget-Beleg |
| `open_questions_acceptance_proof` | candidate-scoped Open-Questions-Beleg |
| `provenance_review_proof` | candidate-scoped Provenance-Beleg |
| `smoke_recheck_proof` | candidate-scoped Smoke-Recheck-Beleg |
| `observability_recheck_proof` | candidate-scoped Observability-Recheck-Beleg |
| `executed_rollback_rerun_proof` | aktueller Executed-Rollback-Rerun-Beleg |
| `browser_evidence_reactivation_proof` | aktueller Browser-Reaktivierungs-Beleg |
| `final_browser_e2e_recheck_proof` | finaler Browser-E2E-Beleg |
| `full_verifier_sweep_proof` | kompletter Phase-5-Sweep-Beleg |
| `truth_mirror_rebaseline_proof` | Truth-Mirror-Rebaseline-Beleg |
| `release_readiness_rerun_proof` | aktueller Release-Readiness-Rerun-Beleg |

## 8. Stop-Gates

Ein Release ist blockiert, wenn:

1. die Pipeline rot oder unvollstaendig ist,
2. kein Hosted-/Infra-Nachweis existiert; dies laesst I1 auf `NEIN`, ohne lokale Kandidatenbeweise zu faelschen,
3. kein Observability-Nachweis existiert,
4. Smoke-Test oder Integrationsplan fehlen,
5. Main-Merge oder Production-Deploy ohne Human-/Owner-Review erfolgen soll,
6. Production- oder Secret-Themen nicht freigegeben sind,
7. Rollback-Pfad oder Eskalationspfad fehlen.

## 9. Verifikation

Diese Checkliste gilt als Phase-5-Baseline nur wenn:

1. die vier Sektionen explizit vorhanden sind,
2. alle Items als `JA/NEIN` fuehrbar sind,
3. der Git-Artefakt-Pfad benannt ist,
4. Stop-Gates explizit genannt sind,
5. kein Production-Claim daraus abgeleitet wird.

## 10. Non-Claims

- Diese Datei ist kein Production-Deploy-Nachweis.
- Diese Datei ist kein Owner-Approval.
- Diese Datei ist kein Ersatz fuer ein ausgefuelltes Release-Artefakt.

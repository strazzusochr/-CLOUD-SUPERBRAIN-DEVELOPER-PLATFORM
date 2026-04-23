# Phase 2 Verification Harness Runtime Contract

Stand: 2026-04-23
Status: Prepared, not implemented
Phase: Phase 2 / WP-07
Owner-Schicht: Cross-layer verification, led by Schicht 7 Observability with inputs from Schicht 2-6

## Zweck

Dieser Vertrag definiert den verbindlichen Verification-Harness fuer Phase 2. Er verhindert Fake-Completeness, indem jede Runtime-Behauptung erst mit nachvollziehbaren Evidence-Artefakten, Pass/Fail-Semantik, Secret-Redaction, Budgetbezug und Rollback-Hinweis akzeptiert wird.

WP-07 ist kein Runtime-Code, kein Deployment und keine Freigabe fuer Live-Secrets. Der Vertrag beschreibt, welche Beweise vorliegen muessen, bevor Phase-2-Komponenten als implementiert, integriert oder release-ready bezeichnet werden duerfen.

## Verbindliche Quellen

- [../CLOUD_SUPERBRAIN_ULTIMATUM_FINALE.md](../CLOUD_SUPERBRAIN_ULTIMATUM_FINALE.md), insbesondere Teil 0, Teil 1 und Teil 2.
- [../system-architecture.md](../system-architecture.md).
- [../phase-2-readiness-matrix.md](../phase-2-readiness-matrix.md).
- [README.md](README.md).
- [../verification-register.md](../verification-register.md).
- [../release-checklist.md](../release-checklist.md).

## Scope

In scope:
- Evidence Envelope fuer Phase-2-Pruefungen.
- Test-IDs `P2-RT-001` bis `P2-RT-006`.
- Pass/Fail/Blocked/Skipped-Klassifikation.
- Secret-Redaction- und Audit-Anforderungen.
- Stop-Gates fuer Docker, Secrets, DB, Provider, Production und Main.
- Rollback-Notiz pro pruefbarem Arbeitspaket.

Out of scope:
- Runtime-Implementierung.
- Live-Provider-Calls.
- Live-MCP-Schreibzugriff.
- Docker-Image-Push oder Registry-Publish.
- Production-Deployment.
- Direkter Schreibzugriff auf `main`.
- Secret-Provisioning.
- DB-Migrationen oder Production-DB-Writes.

## Evidence Envelope

Jeder Phase-2-Harness-Lauf MUSS ein Evidence Envelope erzeugen oder referenzieren. Fehlende Felder machen den Lauf `blocked`, nicht `pass`.

Pflichtfelder:
- `evidence_id`: stabile ID fuer das Artefakt.
- `run_id`: eindeutige Lauf-ID.
- `test_id`: eine der definierten `P2-RT-*` IDs.
- `work_package`: zugehoeriges Arbeitspaket, z. B. `WP-03`.
- `layer`: betroffene technische Schicht aus Teil 2.
- `status`: `pass`, `fail`, `blocked` oder `skipped`.
- `command_or_probe_ref`: Referenz auf ausgefuehrten Befehl, Probe oder Testdefinition.
- `artifact_ref`: Pfad oder URL zum Evidence-Artefakt.
- `started_at`: ISO-8601 Startzeit.
- `finished_at`: ISO-8601 Endzeit.
- `duration_ms`: Laufzeit in Millisekunden.
- `secret_scan_result`: Ergebnis der Secret-Pruefung.
- `cost_event_ref`: Kostenereignis oder `not_applicable`.
- `audit_event_ref`: Audit-Referenz oder `not_applicable`.
- `rollback_note`: konkrete Rueckroll-Anweisung oder begruendetes `not_applicable`.
- `reviewer_gate_required`: `true` oder `false`.
- `sanitized_summary`: redaktionell bereinigte Kurzfassung ohne Secrets.

## Required Test Map

| Test ID | Zweck | Mindestnachweis | Aktueller Gate-Bezug |
| --- | --- | --- | --- |
| `P2-RT-001` | Budgetwarnung bei 80 Prozent Verbrauch | Budget-Event, Alert-Status, kein Secret im Log | WP-01 |
| `P2-RT-002` | Orchestrator-Node mit Retry-Counter und bounded failure | Retry-Zaehler, Abbruchstatus, Trace-Referenz | WP-03 |
| `P2-RT-003` | Globaler Retry-Loop stoppt spaetestens nach 5 Zyklen | Loop-Counter, finaler Fehlerstatus, Recovery-Hinweis | WP-03 |
| `P2-RT-004` | Checkpointer-Recovery nach Neustart | gespeicherter State, Wiederaufnahme, Konsistenznachweis | Gate B |
| `P2-RT-005` | LLM-Fallback-Routing mit Provider-, Reason- und Cost-Event | Providerwechsel, Kostenereignis, Audit-Referenz | Gate A / Gate D |
| `P2-RT-006` | MCP-Tool-Timeout bricht kontrolliert ab | Timeout-Status, Audit-Eintrag, kein unkontrollierter Loop | Gate D |

## Harness Execution Rules

- Pro Transition Package ist maximal ein Harness-Lauf erlaubt, ausser ein fehlgeschlagener Check wird gezielt repariert.
- Fuer dieselbe Fehlerklasse sind maximal drei Wiederholungen erlaubt.
- Fehlende Konfiguration, fehlende Redaction, fehlende Artefakte oder fehlender Rollback-Hinweis fuehren zu `blocked`.
- Secret-Werte duerfen niemals in Logs, Evidence-Artefakten oder Zusammenfassungen erscheinen.
- Docker Desktop mit WSL2 darf nur als lokale Entwicklungs-Ausfuehrungsumgebung dokumentiert werden. Daraus entsteht kein Cloud-Ready-, Production- oder No-Localhost-Architekturclaim.
- Jeder `blocked` oder `skipped` Test muss explizit begruendet werden.
- Ein Feature darf nicht als fertig markiert werden, wenn der zugehoerige Harness-Status `fail`, `blocked` oder unbelegt ist.
- Jede strukturelle Abweichung von Teil 2 braucht einen ADR-Eintrag vor Implementierung.

## Pass/Fail Semantics

- `pass`: Alle Pflichtfelder liegen vor, der Test hat sein erwartetes Verhalten gezeigt, Secret-Scan ist sauber, Rollback-Notiz existiert und kein Stop-Gate wurde verletzt.
- `fail`: Der Test wurde ausgefuehrt, aber erwartetes Verhalten, Sicherheit, Budgetgrenze, Observability oder Recovery-Anforderung wurde verletzt.
- `blocked`: Der Test konnte nicht valide ausgefuehrt werden, z. B. wegen fehlender Secrets, fehlender DB-Entscheidung, fehlender Observability-Grenze oder fehlendem Artefakt.
- `skipped`: Der Test ist fuer das aktuelle Transition Package nicht einschlaegig und die Begruendung ist dokumentiert.

## Required Artifacts

Ein vollstaendiger WP-07-Nachweis besteht mindestens aus:
- Phase-2-Harness-Report mit Evidence Envelope.
- Sanitized Command- oder Probe-Zusammenfassung.
- Secret-Scan-Ergebnis fuer betroffene Dateien und Artefakte.
- Diff- oder Testnachweis fuer die gepruefte Aenderung.
- Rollback-Hinweis.
- Aktualisierter Eintrag in [../verification-register.md](../verification-register.md).

## Stop-Gates

Der Harness darf folgende Aktionen nicht automatisch ausloesen:
- Merge oder direkter Schreibzugriff auf `main`.
- Production-Deployment.
- Docker-Image-Push oder Registry-Publish.
- Secret-, Auth- oder Token-Provisioning.
- DB-Migrationen, Production-DB-Writes oder Memory-Purge.
- Aktivierung kostenpflichtiger Provider.
- Architekturwechsel ohne ADR und Owner-Freigabe.

## Non-Claims

Dieser Vertrag behauptet nicht, dass Phase 2 implementiert ist.

Dieser Vertrag behauptet nicht, dass ein Runtime-Harness existiert oder ausgefuehrt wurde.

Dieser Vertrag behauptet nicht, dass Docker, Provider, Secrets, Datenbanken, MCP-Tools oder Production-Deployments einsatzbereit sind.

Dieser Vertrag markiert nur die Beweisanforderungen, die vor solchen Claims erfuellt werden muessen.

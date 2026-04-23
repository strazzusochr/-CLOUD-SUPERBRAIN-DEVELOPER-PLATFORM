# Phase 1.5 Autonomous Handoff

Stand: 2026-04-23
Status: Prepared, owner gates still active

## Zweck

Dieses Handoff definiert den naechsten logisch sicheren Arbeitsmodus zwischen `PHASE 1` und `PHASE 2`.
Es erlaubt autonome Vorbereitung, ohne die offenen Architektur-Gates still zu entscheiden.

Dieses Dokument ist kein Owner-Approval, kein Deploy-Claim und kein Runtime-Claim.

## Bindende Quellen

1. `TEIL 0` aus `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE.md`
2. `TEIL 1` aus `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE.md`
3. `TEIL 2` aus `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE.md`
4. `docs/system-architecture.md`
5. `docs/PHASE_1_FOUNDATION_PACKAGE.md`
6. `docs/PHASE_1_5_GATE_DECISION_PACKAGE.md`
7. `docs/adr/ADR-004-mvp-db-strategy.md`
8. `docs/adr/ADR-006-observability-stack-boundary.md`

## Gate-Status

| Gate | Status | Wirkung |
| --- | --- | --- |
| Observability-Grenze | `owner-review-pending` | keine Langfuse-Runtime im Main-App-Compose implementieren |
| MVP-DB-Aktivierung | `controlled by ADR-004` | Supabase bleibt aktive MVP-Planungsbasis, self-hosted Postgres nur Ziel- und Migrationspfad |
| Production Deployment | `blocked` | kein Deployment ohne CI/CD, Staging, Rollback und Human-Review |
| Main-Branch-Schreibzugriff | `blocked` | keine direkten Agent-Commits nach `main` |
| Secrets/Auth | `blocked` | keine Secret-Rotation, keine Auth-Aenderung, keine echten Secrets im Repo |

## Autonom Erlaubt

Diese Arbeiten duerfen ohne weiteres Owner-Gate vorbereitet werden:

1. Dokumentierte Work-Pakete fuer Phase 2 erstellen und schaerfen
2. Runtime-Kontrakte als Designartefakte vorbereiten
3. Schnittstellen- und Event-Schemas beschreiben, solange keine produktive Persistenz aktiviert wird
4. Testplaene, Smoke-Checklisten und Verifikationsregister erweitern
5. Budget-, Retry-, Timeout- und Audit-Regeln als Akzeptanzkriterien formulieren
6. Supabase-kompatible SQL- und Datenzugriffsregeln planen, ohne Self-Hosted-Cutover
7. Observability-Interfaces beschreiben, ohne Langfuse in den Main-App-Stack zu mischen

## Autonom Gesperrt

Diese Arbeiten bleiben harte Stop-Gates:

1. `ADR-006` auf `accepted` setzen
2. Langfuse/ClickHouse/S3/Blob/Redis als aktive Runtime deployen
3. Self-hosted PostgreSQL als aktive MVP-DB einschalten
4. Produktions- oder Staging-Deployment ausloesen
5. Branch-Schutz, Secrets, Auth oder Token-Konfiguration veraendern
6. Provider- oder Budgetpolitik still aendern
7. Ergebnisse als `release-ready` oder `done` markieren, solange Runtime-Tests fehlen

## Empfohlene Owner-Entscheidung

Empfehlung fuer Gate A:
`ADR-006` akzeptieren und Observability als separate Stack-Grenze fuehren.

Empfehlung fuer Gate B:
`ADR-004` unveraendert aktiv lassen. Supabase bleibt MVP-Startpunkt, Hetzner PostgreSQL plus pgvector bleibt Phase-4-Migrationsziel.

## Sicherer Phase-2-Vorlauf

Bis zur Owner-Entscheidung wird Phase 2 in nicht-invasive Pakete zerlegt:

1. Budget- und Rate-Control-Kontrakt
2. LLM-Gateway-Routingmatrix und Fallback-Events
3. LangGraph-Graphvertrag ohne produktiven Checkpointer
4. Vier Agentenprofile mit Toolrechten und Stop-Regeln
5. Memory-Konsolidierungsvertrag mit Datenschutz- und Retention-Regeln
6. MCP-Toolset-Vertrag mit Timeout- und Audit-Pflicht
7. Verifikationsplan fuer Budget, Retry, Recovery und Tool-Failures

## Definition of Ready fuer Runtime-Arbeit

Runtime-Arbeit darf erst starten, wenn diese Punkte nachweisbar sind:

1. Owner-Entscheidung zu Gate A dokumentiert
2. DB-Aktivierungspfad mit `ADR-004` abgeglichen
3. keine Abweichung von `TEIL 2` ohne ADR
4. konkrete Testkommandos oder Smoke-Checks definiert
5. Rollback-Notiz fuer betroffene Runtime-Komponenten vorhanden
6. Secrets-Strategie unverletzt
7. Budgetwirkung unter `20 EUR` Infrastruktur-Monatslimit erklaert

## Nicht-Behauptungen

Dieses Handoff behauptet nicht:

1. dass Phase 2 gestartet wurde
2. dass Langfuse laeuft
3. dass ein Checkpointer produktiv persistiert
4. dass MCP-Server verbunden sind
5. dass ein Deployment stattgefunden hat
6. dass offene Owner-Gates freigegeben wurden

## Naechster Arbeitsmodus

Der autonome Arbeitsmodus ist ab jetzt:

1. vor jeder Arbeit Goal-Lock und Stop-Gates pruefen
2. nur das kleinste sichere Work-Paket bearbeiten
3. Unsicherheit explizit markieren
4. Verifikationsartefakt oder Testnachweis ergaenzen
5. bei Stop-Gate abbrechen und Owner-Entscheidung anfordern


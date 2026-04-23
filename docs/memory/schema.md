# Memory Schema Contract

Status: Prepared, not implemented
Datum: 2026-04-23
Phase: Phase 2 / WP-05
Owner-Schicht: Schicht 6 - Memory-Schicht

## Zweck

Dieses Dokument definiert den logischen MVP-Schema-Vertrag fuer die dreischichtige Memory-Schicht der Cloud Superbrain Developer Platform. Es ist ein Planungs- und Schnittstellenartefakt fuer spaetere Migrationen, Tests und Runtime-Implementierung.

Dieses Dokument aktiviert keine Datenbank, keine Migration, keine Embeddings, keine Retrieval-Runtime und keine produktiven Writes.

## Verbindliche Quellen

- `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE.md`
- `docs/system-architecture.md`
- `docs/adr/ADR-004-mvp-db-strategy.md`
- `docs/runtime-contracts/memory-consolidation-job.md`
- `docs/verification-register.md`

## Scope

In Scope:

- Logische relationale MVP-Tabellen fuer Memory-Metadaten.
- Qdrant-Rolle als semantischer Retrieval-Index.
- Source-, Evidence-, Idempotency-, Redaction- und Retention-Regeln.
- Migration-freundliche Namenskonventionen fuer spaetere DB-Artefakte.

Out of Scope:

- SQL-Migrationen.
- Supabase-, Hetzner-, Qdrant- oder Neo4j-Deployment.
- Live-DB-Verbindungen.
- Embedding-Erzeugung.
- Runtime-Retrieval.
- Production-Writes.

## Pflicht-Tabellen

Der MVP-Memory-Core besteht aus genau diesen fuenf Pflicht-Tabellen. Erweiterungen sind erlaubt, aber nicht ohne ADR, wenn sie Verantwortlichkeiten, Retention, Security oder Runtime-Fluss aendern.

### `memory_sessions`

Zweck: Gruppiert Memory-relevante Artefakte pro Run, Phase oder Konsolidierungsfenster.

Pflichtfelder:

- `session_id`
- `project_id`
- `run_id`
- `phase`
- `started_at`
- `completed_at`
- `status`
- `summary`
- `source_ref`
- `cost_snapshot_ref`
- `audit_ref`
- `created_at`
- `updated_at`

### `memory_items`

Zweck: Speichert atomare, belegte Memory-Einheiten, die fuer spaetere Agenten-Kontexte nutzbar sind.

Pflichtfelder:

- `memory_item_id`
- `session_id`
- `project_id`
- `run_id`
- `item_type`
- `content_summary`
- `source_ref`
- `classification`
- `redaction_status`
- `retention_policy`
- `evidence_status`
- `embedding_eligible`
- `qdrant_point_id`
- `status`
- `created_at`
- `updated_at`

Erlaubte `item_type`-Werte im MVP:

- `fact`
- `session_summary`
- `follow_up`
- `retrieval_key`

### `memory_decisions`

Zweck: Bewahrt explizite Owner-, Architektur- und Implementierungsentscheidungen mit Quellenbezug.

Pflichtfelder:

- `decision_id`
- `session_id`
- `project_id`
- `run_id`
- `decision_title`
- `decision_summary`
- `decision_owner`
- `adr_ref`
- `source_ref`
- `effective_from`
- `replaces_decision_id`
- `classification`
- `redaction_status`
- `retention_policy`
- `evidence_status`
- `status`
- `created_at`
- `updated_at`

### `memory_blockers`

Zweck: Macht Blocker sichtbar, klassifiziert sie und verbindet sie mit einem naechsten sicheren Schritt.

Pflichtfelder:

- `blocker_id`
- `session_id`
- `project_id`
- `run_id`
- `blocker_title`
- `blocker_summary`
- `severity`
- `owner_layer`
- `next_step`
- `source_ref`
- `escalation_ref`
- `classification`
- `redaction_status`
- `retention_policy`
- `evidence_status`
- `status`
- `created_at`
- `updated_at`

### `memory_evidence`

Zweck: Verknuepft Memory-Eintraege mit konkreten Belegen, Tests, Artefakten und Rollback-Hinweisen.

Pflichtfelder:

- `evidence_id`
- `session_id`
- `project_id`
- `run_id`
- `artifact_ref`
- `test_id`
- `status`
- `sanitized_summary`
- `rollback_note`
- `linked_memory_item_id`
- `source_ref`
- `classification`
- `redaction_status`
- `retention_policy`
- `created_at`
- `updated_at`

## Gemeinsame Pflichtfelder

Jede persistierbare Memory-Entitaet braucht mindestens:

- Eindeutige ID.
- `project_id`.
- `run_id`.
- `source_ref`.
- `classification`.
- `redaction_status`.
- `retention_policy`.
- `evidence_status`, wenn die Entitaet eine Completion-, Entscheidungs- oder Testaussage stuetzt.
- `created_at`.
- `updated_at`.

## Optionale Support-Tabellen

Diese Tabellen duerfen spaeter ergaenzt werden, sind aber nicht Teil des Pflicht-MVP:

- `memory_follow_ups`
- `memory_audit_events`
- `memory_retention_policies`

Eine optionale Tabelle darf keine produktive Pflichtabhaengigkeit werden, bevor Migration, Tests und ADR-/Review-Gates abgeschlossen sind.

## Qdrant-Rolle

Qdrant ist im MVP ein semantischer Retrieval-Index, nicht die Quelle der Wahrheit. Die relationale Memory-Schicht bleibt authoritative.

Qdrant darf speichern:

- Vektor fuer erlaubte, belegte Memory-Zusammenfassungen.
- `memory_item_id`
- `project_id`
- `source_ref`
- `classification`
- `retention_policy`
- `redaction_status`

Qdrant darf nicht speichern:

- Secrets, Tokens, Keys oder Credentials.
- Raw Logs.
- Vollstaendige Tool-Ausgaben.
- Ungepruefte Spekulation.
- PII ohne explizite Rechtsgrundlage und Redaction-Status.
- Grosse Diffs oder Build-Artefakte.

## Schreib- und Validierungsregeln

- Kein Memory-Element ohne `source_ref`.
- Kein Completion-Claim ohne `memory_evidence` oder externes Evidence-Artefakt.
- Idempotency-Key wird aus `run_id`, Phase und Artefakt-Hash gebildet.
- `embedding_eligible` ist standardmaessig `false`.
- Embedding-Freigabe folgt `docs/runtime-contracts/memory-consolidation-job.md`.
- Secret-, Token-, Credential- und Private-Key-Muster muessen vor Persistenz blockiert werden.
- PII muss klassifiziert, redigiert oder abgelehnt werden.
- Vector-Write-Fehler markieren den Konsolidierungslauf als `degraded`, nicht als `complete`.
- SQL-Migrationen duerfen nur per PR, CI und Review-Gate aktiviert werden.

## Stop-Gates

Folgende Aktionen stoppen die autonome Ausfuehrung und brauchen Owner-/Review-Freigabe:

- Aktivierung von Supabase-, Hetzner-, Qdrant- oder Neo4j-Persistenz.
- Aenderung der Pflicht-Tabellen, Retention-Regeln oder Security-Klassifikation.
- Speicherung von PII, Secrets, Tokens oder Credentials.
- Production-DB-Writes.
- Ausfuehrung oder Aenderung produktiver Migrationen.
- Wechsel der DB-Strategie aus ADR-004.
- Neo4j-/Knowledge-Graph-Aktivierung.

## Akzeptanzchecks

- Dieses Dokument existiert unter `docs/memory/schema.md`.
- Die fuenf Pflicht-Tabellen sind dokumentiert.
- Die Qdrant-Rolle ist als Index, nicht als Source of Truth, dokumentiert.
- Secret-/PII-Verbote sind dokumentiert.
- Runtime-Aktivierung bleibt blockiert, bis Migration, CI, Security-/Data-Review und DB-/Checkpointer-Gate abgeschlossen sind.

## Nicht-Behauptungen

- Keine Datenbank ist verbunden.
- Keine Migration ist implementiert.
- Kein produktives Schema ist verifiziert.
- Keine Embeddings sind erzeugt.
- Kein Retrieval ist getestet.
- Kein Memory-Runtime-Job ist aktiviert.

# Memory Schema Contract

Status: Phase 1 PostgreSQL/pgvector runtime verified, live embeddings gated
Datum: 2026-04-26
Phase: Phase 2 / WP-05
Owner-Schicht: Schicht 6 - Memory-Schicht

## Zweck

Dieses Dokument definiert den logischen MVP-Schema-Vertrag fuer die dreischichtige Memory-Schicht der Cloud Superbrain Developer Platform. Die Phase-1-Runtime nutzt die sechs Foundation-Tabellen aus `services/agent-api/app/migrations/001_foundation_schema.sql`; die erweiterten Memory-Detailtabellen in diesem Dokument bleiben ein Phase-2+ Schemaausbau.

Dieses Dokument aktiviert keine Live-Embeddings, keine externen Memory-Ziele, keine DSGVO-Purge-Runtime und keine produktiven Writes.

## Verbindliche Quellen

- `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE.md`
- `docs/system-architecture.md`
- `docs/adr/ADR-004-mvp-db-strategy.md`
- `docs/runtime-contracts/memory-consolidation-job.md`
- `docs/verification-register.md`

## Scope

In Scope:

- Logische relationale MVP-Tabellen fuer Memory-Metadaten.
- pgvector-Rolle als semantischer Retrieval-Index. Qdrant ist Phase-6-Option und nicht Phase-1-5 Source of Truth.
- Source-, Evidence-, Idempotency-, Redaction- und Retention-Regeln.
- Migration-freundliche Namenskonventionen fuer spaetere DB-Artefakte.

Out of Scope:

- Externe SQL-Migrationen ausserhalb der verifizierten Phase-1-Foundation-Migration.
- Supabase-, Qdrant- oder Neo4j-Deployment.
- Embedding-Erzeugung.
- Providerbasierte semantische Runtime-Retrievals.
- Production-Writes.

## Pflicht-Tabellen

Der verifizierte Phase-1-Core besteht aus sechs Foundation-Tabellen: `projects`, `agent_sessions`, `agent_messages`, `memory_entries`, `cost_tracking` und `audit_log`. Der folgende erweiterte Memory-Core beschreibt Phase-2+-Detailtabellen fuer feinere Konsolidierungs- und Retention-Fluesse. Erweiterungen sind erlaubt, aber nicht ohne ADR, wenn sie Verantwortlichkeiten, Retention, Security oder Runtime-Fluss aendern.

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
- `pgvector_ref`
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

## Vektor-Rolle

PostgreSQL/pgvector ist in Phase 1-5 der einzige zulaessige semantische Retrieval-Index. Die relationale Memory-Schicht bleibt authoritative; `content_embedding vector(...)` und `pgvector_ref` duerfen nur auf PostgreSQL/pgvector-Daten zeigen.

Die verifizierte Foundation-Tabelle `memory_entries` muss fuer Embedding-Kompatibilitaet mindestens `content_embedding vector(1536)` und `embedding_model_version varchar(100)` enthalten. Der Runtime-Vertrag `GET /api/v1/memory/embedding-consistency/contract` veroeffentlicht `memory-embedding-consistency-v1`, `memory_embedding_consistency_contract_visible`, die aktive Dimension, den aktiven Modellversionsnamen und die Re-Embedding-Policy.

Wenn `MEMORY_EMBEDDING_MODEL_VERSION` oder die Dimension geaendert wird, bleibt `lexical_fallback` der sichere Suchmodus, bis ein begrenzter Re-Embedding-Job mit Audit-Evidence abgeschlossen ist. Zukuenftige Vector-Search darf alte und neue Vektoren nicht mischen und muss nach `embedding_model_version` filtern.

pgvector darf speichern:

- Vektor fuer erlaubte, belegte Memory-Zusammenfassungen.
- `memory_item_id`
- `project_id`
- `source_ref`
- `classification`
- `retention_policy`
- `redaction_status`

pgvector darf nicht speichern:

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

- Aktivierung von Supabase-, Qdrant-, LanceDB-, Neo4j- oder anderen neuen Persistenzzielen ausserhalb der verifizierten Phase-1-PostgreSQL/pgvector-Runtime.
- Aenderung der Pflicht-Tabellen, Retention-Regeln oder Security-Klassifikation.
- Speicherung von PII, Secrets, Tokens oder Credentials.
- Production-DB-Writes.
- Ausfuehrung oder Aenderung produktiver Migrationen.
- Wechsel der DB-Strategie aus ADR-007.
- Neo4j-/Knowledge-Graph-Aktivierung.

## Akzeptanzchecks

- Dieses Dokument existiert unter `docs/memory/schema.md`.
- Die sechs Pflicht-Tabellen sind dokumentiert.
- Die pgvector-Rolle ist als einziger Phase-1-5-Vektorindex dokumentiert.
- Secret-/PII-Verbote sind dokumentiert.
- Runtime-Aktivierung fuer PostgreSQL/pgvector ist per Phase-1-Verifier erfolgt; Live-Embeddings, externe Memory-Ziele und Purge-Jobs bleiben bis Security-/Data-Review blockiert.

## Nicht-Behauptungen

- Keine Live-Embedding-Pipeline ist verbunden.
- Keine Supabase-, Qdrant- oder Neo4j-Runtime ist aktiviert.
- Kein DSGVO-Purge-Job ist implementiert.
- Keine Embeddings sind erzeugt.
- Kein semantisches Vector-Retrieval mit Provider-Embeddings ist getestet.

# Memory Consolidation Job Contract

Status: Phase 1 Redis-to-PostgreSQL consolidation worker implemented and verified
Datum: 2026-04-26
Phase: Phase 2 / WP-05
Owner-Schicht: Schicht 6 - Memory-Schicht

## Zweck

Dieser Vertrag definiert, wie abgeschlossene Runs, Agentenberichte, Evidence-Artefakte, Kosteninformationen und Owner-Entscheidungen in kontrollierte Memory-Updates verdichtet werden.

Dieser Vertrag ist in Phase 1 fuer Redis-Working-Memory nach PostgreSQL/pgvector-Memory aktiviert. Er erzeugt keine Embeddings und nutzt keinen externen Provider. Die aktive Runtime ist ein deterministischer Worker mit TTL-Schwelle, Idempotency-Key, Secret-Blocker und Audit-Events.

## Phase-1-Runtime-Surface

Implementiert:

1. Docker-Compose-Service `memory-worker`.
2. Worker-Entrypoint `python -m app.worker`.
3. Testbarer One-Shot-Modus `python -m app.worker --once`.
4. Redis-Scan-Pattern `memory:working:*`.
5. Intervall: `MEMORY_CONSOLIDATION_INTERVAL_SECONDS=300` Sekunden.
6. TTL-Schwelle: `MEMORY_CONSOLIDATION_TTL_THRESHOLD_SECONDS=480` Sekunden.
7. PostgreSQL-Write nach `memory_entries` mit `consolidation_status='consolidated'`.
8. Idempotency ueber `metadata.idempotency_key`.
9. Audit-Events: `memory_consolidated`, `memory_consolidation_skipped`, `memory_consolidation_blocked`.
10. Secret-Pattern-Blocker vor Persistenz.
11. Runtime-Beweis in `scripts/verify-phase1-runtime.ps1`: Redis-Working-Memory-Key wird gesetzt, Worker `--once` konsolidiert, `memory_entries`, `audit_log`, Memory-Suche, gefilterte Consolidation-API und Prometheus-Metric werden geprueft.
12. Public Feed: `GET /api/v1/memory/consolidation/recent`.
13. Prometheus: `superbrain_memory_consolidation_events_total`.
14. Frontend-Panel: `Memory Consolidation`.
15. Redis-Heartbeat: `memory-worker:heartbeat`, ausgewertet durch `/api/v1/health` und `superbrain_service_health{service="memory_worker"}`.

Nicht implementiert:

1. Live-Embeddings.
2. Provider-basierte semantische Vektoren.
3. DSGVO-Purge-Job.
4. Neo4j Knowledge Graph.
5. Qdrant.

## Verbindliche Quellen

- `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE.md`
- `docs/PHASE_2_IMPLEMENTATION_PLAN.md`
- `docs/memory/schema.md`
- `docs/runtime-contracts/langgraph-orchestrator.md`
- `docs/runtime-contracts/core-agent-profiles.md`
- `docs/runtime-contracts/budget-rate-control.md`
- `docs/runtime-contracts/llm-gateway-routing.md`
- `docs/secrets-strategy.md`
- `docs/cost-policy.md`
- `docs/provider-rotation-register.md`

## Markierte Unsicherheit

Das relationale Phase-1-Schema ist ueber `services/agent-api/app/migrations/001_foundation_schema.sql` aktiv und per Runtime-Verifier geprueft. Embedding- und DSGVO-Purge-Anteile bleiben Gate-Arbeit.

## Scope

In Scope:

- Input- und Output-Envelopes fuer Memory-Konsolidierung
- Trennung von facts, decisions, blockers, evidence und follow-ups
- Pflicht zu Quellreferenzen fuer jedes persistierte Memory-Element
- Idempotente Write-Planung mit Transaktionskennung
- Retry-, Timeout- und Eskalationsregeln
- Embedding-Eignung fuer retrieval-relevante Inhalte
- Retention-, Datenschutz- und Secret-Filter

Out of Scope:

- Redis-, Supabase-, Qdrant-, Neo4j- oder Cloud-Deployment
- Datenbankmigrationen oder produktive Schema-Aenderungen
- Live-Embeddings oder produktive Retrieval-Tests
- Memory-Purge oder Loeschjobs
- Direkte Production-DB-Writes

## Memory-Tiers

| Tier | Ziel | Status | Regel |
| --- | --- | --- | --- |
| Working Memory | Redis, TTL 30 Minuten | Phase-1 aktiv | Nur fluechtiger Run-Kontext, keine Secrets |
| Long-Term Memory | Fly.io PostgreSQL/pgvector Ziel, lokal via Docker | Phase-1 aktiv ohne Embeddings | Nur validierte, referenzierte und konsolidierte Inhalte |
| Retrieval Index | pgvector, Embeddings spaeter | Phase-1 lexical fallback | Nur retrieval-relevante Inhalte, keine Rohlogs |
| Knowledge Graph | Neo4j optional | Nicht Phase-2-aktiv | Nur nach ADR und Owner-Freigabe |

## Inputs

| Input | Quelle | Pflicht |
| --- | --- | --- |
| `run_summary` | Orchestrator Result-Aggregator | Ja |
| `agent_output_envelopes` | Planner, Coder, Tester, DevOps | Ja |
| `test_and_error_artifacts` | Tester-Agent, CI, Smoke-Checks | Ja, wenn vorhanden |
| `cost_and_tool_usage` | LLM-Gateway, MCP-Schicht, Budget-Guard | Ja |
| `owner_decisions` | Human Review Gate, ADRs | Ja, wenn relevant |
| `orchestrator_state` | LangGraph State | Ja |
| `rollback_notes` | DevOps-Agent oder Release-Check | Ja, wenn relevant |

## Outputs

| Output | Zweck |
| --- | --- |
| `session_summary` | Kompakter Rueckblick auf den Run |
| `project_facts_update` | Stabile, belegte Projektfakten |
| `decision_records` | Owner-Entscheidungen und ADR-Verweise |
| `blocker_register_update` | Offene Blocker mit naechsten Schritten |
| `evidence_index` | Verweise auf Tests, Logs und Artefakte |
| `follow_up_queue` | Geordnete naechste Arbeitspakete |
| `retrieval_keys` | Suchschluessel fuer spaetere Prompts |
| `audit_event` | Nachvollziehbare Memory-Aktion ohne Secrets |

## Konsolidierungsprozess

1. Abgeschlossene Run-Ereignisse einsammeln.
2. Pflichtfelder und Quellreferenzen validieren.
3. Secrets, Credentials und sensible personenbezogene Daten vor jeder weiteren Verarbeitung herausfiltern.
4. Inhalte in facts, decisions, blockers, evidence und follow-ups klassifizieren.
5. Redundante oder irrelevante Details deterministisch markieren.
6. Relationale Metadaten als atomaren Batch vorbereiten.
7. Vector-Embeddings nur fuer retrieval-relevante Inhalte vormerken.
8. Retention- und Datenschutzregeln anwenden.
9. Audit-Event mit Transaktionskennung erzeugen.

## Write-Vertrag

- Keine stillen Teilwrites.
- Jeder Batch braucht eine `memory_transaction_id`.
- Jeder Batch braucht einen stabilen Idempotency-Key aus Run-ID, Phase und Artefakt-Hash.
- Wenn ein Metadata-Write erfolgreich ist, aber ein Vector-Write fehlschlaegt, wird der Batch als `degraded` markiert und nicht als vollstaendig gemeldet.
- Nach einem Persistenzfehler ist nur sauberer Retry oder Eskalation erlaubt.
- Kein Memory-Element darf ohne Quellreferenz persistiert werden.

## Embedding-Eignung

Embedding-erlaubt:

- stabile Projektfakten
- Owner-Entscheidungen und ADR-Verweise
- bestaetigte Blocker
- kompakte Evidence-Zusammenfassungen
- kompakte Run-Zusammenfassungen

Embedding-verboten:

- Rohlogs
- Secrets, Tokens, Credentials oder asymmetrische Schluesselmaterialien
- unbewiesene Spekulation
- grosse Diffs oder Build-Ausgaben
- temporaere Tool-Ausgaben ohne spaeteren Retrieval-Wert
- personenbezogene Daten ohne dokumentierte Rechtsgrundlage

## Retry-, Timeout- und Eskalationsregeln

- Zielintervall fuer Runtime: alle 5 Minuten.
- TTL-Schwelle: konsolidiere Working-Memory-Entries mit `remaining_ttl <= 8 Minuten`.
- Maximaldauer pro Batch: 120 Sekunden.
- Maximal 2 Retries pro Batch.
- Backoff: 30 Sekunden, danach 120 Sekunden.
- Nach Ausschoepfung der Retries wird ein Blocker erzeugt.
- Datenschutz-, Secret- oder Schema-Konflikte werden nicht automatisch wiederholt, sondern eskaliert.

## Sicherheits- und Datenschutzregeln

- Redaction passiert vor Klassifikation, Persistenz und Embedding.
- `memory_worker_metadata_secret_guard_verified`: Der Memory Worker prueft `content_text`
  sowie Schluessel und Werte beliebig tief verschachtelter nested metadata rekursiv.
  Ein Treffer persistiert keinen Memory-Eintrag, konsumiert den Working-Memory-Key und
  schreibt nur ein redigiertes `memory_consolidation_blocked`-Audit mit generischem
  Grund und sicherem Fundbereich.
- Secrets duerfen weder in Memory noch in Logs gespeichert werden.
- Memory-Purge braucht Owner-Bestaetigung.
- Retention-Regeln duerfen nicht still geaendert werden.
- Audit-Events duerfen keine sensitiven Nutzdaten enthalten.
- Production-Memory darf nicht mit lokalen Testdaten vermischt werden.

## Integrationspunkte

| System | Integration | Status |
| --- | --- | --- |
| LangGraph Orchestrator | `memory_updater` liefert Run-Kontext | Vertraglich vorbereitet |
| Core Agents | `memory_write` aus Agent-Output-Envelope | Vertraglich vorbereitet |
| LLM Gateway | Embedding-Calls nur ueber Gateway und Budget-Guard | Vertraglich vorbereitet |
| MCP-Schicht | Persistenz nur ueber erlaubte Toolrechte | Vertraglich vorbereitet |
| Observability | Audit- und Degraded-Events ohne Secrets | Vertraglich vorbereitet |

## Akzeptanztests

| Test-ID | Erwartung |
| --- | --- |
| MEM-001 | Ein Memory-Element ohne Quellreferenz wird abgelehnt. |
| MEM-002 | Teilwrites werden nicht als vollstaendig gemeldet. |
| MEM-003 | facts, decisions, blockers, evidence und follow-ups bleiben getrennt. |
| MEM-004 | Dedupe ist deterministisch fuer denselben Input. |
| MEM-005 | Rohlogs, Secrets und Credentials sind nicht embedding-geeignet. |
| MEM-006 | Retention-Regeln blockieren verbotene Daten. |
| MEM-007 | Retry stoppt nach maximal 2 Versuchen und erzeugt einen Blocker. |
| MEM-008 | Fehlendes, ungeklaertes oder nicht per Migration verifiziertes Memory-Schema blockiert Runtime-Aktivierung. |
| MEM-009 | Embedding- oder LLM-Calls ohne Gateway und Budget-Guard werden blockiert. |
| MEM-010 | Jede erfolgreiche Konsolidierung erzeugt ein Audit-Event. |

## Stop-Gates

Sofort stoppen bei:

- fehlendem, geaendertem oder nicht per Migration verifiziertem Memory-Schema vor Runtime-Aktivierung
- Aktivierung eines neuen oder externen Persistenzziels ausserhalb der verifizierten Phase-1-PostgreSQL-Runtime
- Memory-Purge, Retention-Aenderung oder Datenloeschung
- Secret-, Token-, Credential- oder PII-Fund im Memory-Input
- unverschluesseltem Speichern sensitiver Daten
- Aktivierung von Embedding-Modellen oder Provider-Zugriffen
- Production-DB-Writes
- Aktivierung von Neo4j oder Knowledge-Graph-Persistenz
- Aenderung der Memory-Tier-Architektur ohne ADR

## Nicht-Behauptungen

- Kein Live-Embedding-Provider ist aktiviert.
- Keine providerbasierte semantische Vektorsuche ist verifiziert.
- Kein DSGVO-Purge-Job ist implementiert.
- Kein Neo4j Knowledge Graph ist aktiviert.
- Kein Production-Deployment dieser Memory-Runtime ist erfolgt.

## Naechster sicherer Schritt

Naechster sicherer Schritt fuer Memory-Runtime: Browser-Automation-Beweis fuer das `Memory Consolidation` Panel, sobald Browser MCP verfuegbar ist. Live-Embeddings, DSGVO-Purge und Knowledge-Graph bleiben hinter Gate D plus explizitem Review.

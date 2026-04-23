# PHASE 0 AUDIT

Stand: 2026-04-23
Geltungsbereich: `TEIL 0`, `PHASE 0` und `TEIL 10 - PFLICHT-ARTEFAKTE` aus `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE.md`

## 1. Ziel dieses Audits

Dieses Dokument ist die operative Bestandsaufnahme fuer den Projektstart. Es legt fest:

- welche Pflichtartefakte bereits existieren,
- welche Artefakte fuer `PHASE 0` noch fehlen,
- welche langfristigen Governance-Artefakte vorbereitet werden muessen,
- und welche Stop-Gates den Uebergang nach `PHASE 1` blockieren.

## 2. Bereits vorhanden

| Artefakt | Pfad | Status | Hinweis |
| --- | --- | --- | --- |
| Projektverfassung | `AGENTS.md` | vorhanden | Repo-Governance verankert, inklusive Goal-Lock-Verweis |
| Master Skill | `docs/CODEX_AGENT_SKILL_MASTER.md` | vorhanden | inhaltlich importiert und als Arbeitsstandard uebernommen |
| Gesamt-Masterplan | `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE.md` | vorhanden | `TEIL 0` ist der hoechste inhaltliche Projektanker |

## 3. Pflichtartefakte fuer PHASE 0

Die folgenden Artefakte sind fuer einen sauberen Projektstart verbindlich und inzwischen im Repo verankert:

| Artefakt | Zielpfad | Status |
| --- | --- | --- |
| Monorepo-Struktur-Dokument | `docs/monorepo-structure.md` | vorhanden |
| ADR-001 LangGraph als Haupt-Orchestrator | `docs/adr/ADR-001-langgraph-orchestrator.md` | vorhanden |
| ADR-002 LiteLLM als LLM-Gateway | `docs/adr/ADR-002-litellm-gateway.md` | vorhanden |
| ADR-003 Kein AutoGen vor Phase 6 | `docs/adr/ADR-003-no-autogen-before-phase-6.md` | vorhanden |
| ADR-004 Supabase fuer MVP, spaeter Hetzner PostgreSQL | `docs/adr/ADR-004-mvp-db-strategy.md` | vorhanden |
| ADR-005 Clientseitiges WebGPU mit WebGL-Fallback | `docs/adr/ADR-005-webgpu-webgl-fallback.md` | vorhanden |
| Secrets-Strategie | `docs/secrets-strategy.md` | vorhanden |
| Kostenrichtlinie | `docs/cost-policy.md` | vorhanden |
| Codex-Integration Master Skill im Zielordner | `docs/codex-integration/CODEX_AGENT_SKILL_MASTER.md` | vorhanden |
| Codex Loader Prompt | `docs/codex-integration/CODEX_LOADER_PROMPT.txt` | vorhanden |

## 4. Pflichtartefakte aus TEIL 10

Diese Artefakte muessen frueh strukturiert angelegt werden, damit Governance, Nachvollziehbarkeit und Betrieb nicht spaeter improvisiert werden. Der aktuelle Repo-Stand ist unten festgehalten:

| Artefakt | Zielpfad | Status |
| --- | --- | --- |
| Architecture Map | `docs/architecture-map.md` | vorhanden |
| 7-Layer Ownership Map | `docs/ownership-map.md` | vorhanden |
| Interface Contract Register | `docs/interface-contract-register.md` | vorhanden |
| ADR Log Index | `docs/adr/README.md` | vorhanden |
| Verification Register | `docs/verification-register.md` | vorhanden |
| Release Checklist | `docs/release-checklist.md` | vorhanden |
| Assumption Log | `docs/assumption-log.md` | vorhanden |
| Open Questions Log | `docs/open-questions-log.md` | vorhanden |
| Technical Debt Log | `docs/technical-debt-log.md` | vorhanden |
| Design Spec Sheet Register | `docs/design-spec-register.md` | vorhanden |
| Screen Inventory | `docs/screen-inventory.md` | vorhanden |
| UI State Matrix | `docs/ui-state-matrix.md` | vorhanden |
| Provider Rotation Register | `docs/provider-rotation-register.md` | vorhanden |
| Limit History Register | `docs/limit-history-register.md` | vorhanden |
| Runbooks | `docs/runbooks/README.md` | vorhanden |

## 5. Kritische Konsistenzbeobachtung

`PHASE 0` nennt an einer Stelle "7 Dokumente", zaehlt in Summe aber mehr konkrete Pflichtartefakte auf. Fuer die operative Arbeit gilt deshalb:

- Verbindlich ist nicht die Zahl `7`, sondern die vollstaendige, explizit aufgelistete Artefaktmenge.
- `PHASE 1` bleibt blockiert, bis alle explizit genannten `PHASE 0`-Artefakte vorhanden, inhaltlich ausgefuellt und vom Owner bestaetigt sind.
- Die Zielartefakte unter `docs/codex-integration/` sind vorhanden; die Drift-Sicherung wird jetzt ueber `docs/codex-integration/MIRROR_SYNC_POLICY.md` geregelt.

## 6. Aktive Stop-Gates

Folgende Gates sind ab sofort fuer den Projektstart aktiv:

1. Kein Einstieg in `PHASE 1`, bevor die `PHASE 0`-Dokumente vollstaendig sind.
2. Kein Deployment ohne CI/CD-Nachweis.
3. Kein Feature ohne Observability-Integration.
4. Kein Abschluss-Claim ohne dokumentierte Verifikation.
5. Kein Architekturwechsel ohne ADR.
6. Kein Main-Merge ohne Human-Review.
7. Keine Secrets in Code, Docs, Commits oder Logs.

## 7. Definition of Done fuer PHASE 0

`PHASE 0` gilt erst dann als abgeschlossen, wenn alle folgenden Punkte gleichzeitig wahr sind:

1. Alle in Abschnitt 3 gelisteten Artefakte existieren im Repo.
2. Jede ADR enthaelt mindestens: Kontext, Entscheidung, Begruendung, Alternativen, Konsequenzen.
3. Die Monorepo-Struktur deckt alle 7 Schichten ab: `frontend`, `backend`, `agents`, `mcp`, `infrastructure`, `memory`, `observability`.
4. Die Secrets-Strategie weist jedem Secret genau einen Speicherort zu.
5. Die Kostenrichtlinie enthaelt konkrete Zahlen, Alerts, Limits und Modellzuordnung.
6. Die Codex-Integration unter `docs/codex-integration/` ist vollstaendig.
7. Der Owner bestaetigt die Phase-0-Dokumente explizit.

## 8. Naechster operativer Schritt

Der naechste sinnvolle Schritt ist jetzt nicht mehr das Anlegen fehlender Artefakte, sondern der kontrollierte Abschluss von `PHASE 0` in dieser Reihenfolge:

1. Owner-Review-Paket gegenlesen und Freigabeentscheidung vorbereiten
2. Offene Fragen aus dem Review bewusst fuer `PHASE 1` oder spaetere ADRs einsortieren
3. `PHASE 1` erst nach expliziter Owner-Bestaetigung starten

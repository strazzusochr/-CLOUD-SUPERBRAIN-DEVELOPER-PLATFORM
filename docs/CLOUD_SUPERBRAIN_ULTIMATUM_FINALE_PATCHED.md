# ████████████████████████████████████████████████████████████████████
# -CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM
# ULTIMATUM FINALE — SUPREME GODMODE SYNTHESIS 2026 (PATCHED)
# ████████████████████████████████████████████████████████████████████

Dieses Dokument ist das EINZIGE GÜLTIGE GESETZ für die Plattform. Alle vorigen Dokumente (Teil 1 und Teil 2) sind hiermit logisch verschmolzen und in der folgenden Architektur-Wahrheit festgehalten.

## 1. PROJECT GOAL LOCK & BUDGET (RD-01)
- **Budgetkonformer Start (Phase 1):** Es wird in Phase 1 klein gestartet. KEIN CPX51 in Phase 1!
- **Infrastruktur-Basis:** CX21 (oder vergleichbarer kleiner Hetzner-Start).
- **Upgrade-Regel:** Upgrades auf größere Server-Typen erfolgen NUR nach empirisch gemessenen und belegten Ressourcen-Limits (Messwerten). Das Infrastruktur-Limit von 20€/Monat ist strikt einzuhalten.

## 2. DATENBANK & MEMORY ARCHITEKTUR (RD-02, RD-03)
- **Shared PostgreSQL:** Es wird exakt EINE PostgreSQL-Instanz als primäre Single-Source-of-Truth betrieben.
- **Getrennte Databases:** Innerhalb dieser Instanz existieren physisch getrennte Databases: eine für `superbrain_prod` (Main State) und eine isolierte Datei/Datenbank für `langfuse` (Observability).
- **Vector Store:** Qdrant ist in Phase 1-5 STRIKT AUSGESCHLOSSEN. Erst ab Phase 6 evaluieren.
- **Pgvector:** Die Extension `pgvector` in PostgreSQL ist die primäre und einzige Vektor-Lösung in Phase 1-5.

## 3. ORCHESTRIERUNG & AGENTEN-FRAMEWORK (RD-04)
- **LangGraph als Kern-State-Machine:** Die gesamte Agenten-Orchestrierung, State-Machine-Logik und das Routing MUSS über LangGraph gesteuert werden.
- **CrewAI Beschränkung:** CrewAI darf niemals globale Prozesse orchestrieren. Es darf ausschließlich *lokal gekapselt innerhalb* eines ausführenden LangGraph Agent-Executor-Knotens verwendet werden.

## 4. LAUFZEIT-VERTRÄGE & SICHERHEIT (L-01 bis L-33 Konsolidiert)
Die identifizierten Architektur-Lücken (L-01 bis L-33) sind mit folgenden System-Verträgen geschlossen:
- **5-Minuten-Memory-Konsolidierung:** Der State muss spätestens alle 5 Minuten asynchron verkleinert/gesichert werden (Context Limits, Token Costs).
- **Budget-Guard-Node:** Ein dedizierter Guard-Node validiert vor API-Calls die kumulierten Kosten.
- **SSE/API-Verträge:** Frontend zu AI-Backend-Kommunikation zwingend über vertragsbasierte Server-Sent-Events (SSE-Streams).
- **Rollback:** Für jedes Systemmodul ist ein Rollback-Verfahren definiert.
- **Branch Protection & Gitleaks:** Hard-Block Protection. `gitleaks` zwingend aktiv, um API-Keys/Secrets vor Repositories zu schützen.

## 5. AUDIT & REPO STATE
- Teil 1 (`CLOUD_SUPERBRAIN_ULTIMATUM_FINALE teil 1...`) und Teil 2 (`...teil 2...`) verbleiben als Historien-Dokumente.
- Echte Service-Codebasen für Agent-API, Frontend und MCP-Gateway werden nun auf Basis dieses Patches initialisiert.

---
**ENDE PHASE 0.**
REBOOT UND AUDIT SIND ABGESCHLOSSEN. SYSTEM GEHT IN PHASE 1 (EXECUTION) ÜBER.

# L1-L7 Layer Matrix (kanonisch)

Stand: 2026-08-02

Diese Matrix verwendet das verbindliche Mapping aus `AGENTS.md`,
`docs/system-architecture.md` und `docs/project-progress.manifest.json`.
Lokale Beweise sind `DEV-ONLY`; sie ersetzen keinen source-identischen Hosted-
oder Release-Beweis.

| Layer | Aktive Implementierung | Aktueller Wahrheitsrand |
| --- | --- | --- |
| **L1 Frontend / Next.js** | Next.js 16.2.11, React 19, 22 kanonische Workspace-Routen, R3F/three.js-Cortex, Same-Origin-Proxies | 100 % im Manifest; lokale Browserabnahme ist DEV-ONLY. Hosted Source-Parität muss je Kandidat erneut belegt werden. |
| **L2 Orchestrator / LangGraph** | FastAPI, LangGraph-StateGraph, PostgreSQL-Checkpointer, SSE/Replay, Policy-, Budget-, Retry- und Evidence-Gates | 100 % im Manifest. Die kanonische lokale Ausführung bleibt für viele Pfade deterministisch; Cloudflare-stateful ist ein getrennt source-gebundener Hosted-Pfad. |
| **L3 Agent Pool** | Planner, Coder, Tester, DevOps; Redis-Queue, Worker, Heartbeats, Ergebnis-Envelopes; begrenzter O4 Agent→MCP-Dateiwrite mit Audit/Readback/Rollback | 100 % im Manifest für den itemisierten Vertrag. Keine Behauptung einer allgemeinen autonomen Softwarelieferung oder beliebiger Tool-Writes. |
| **L4 LLM Gateway** | OpenAI-kompatible Chat-/Responses-Verträge, Routing-/Policy-/Fallback-/Budget-Grenzen, begrenzter Cloudflare-Workers-AI-Livepfad | 55 % im Manifest. Standardmodus ist `deterministic_dry_run`; vollständige Live-Flotte, dynamisches Routing und Responses-Streaming sind nicht belegt. |
| **L5 MCP Gateway / Tools** | Safe-Envelopes mit Scope, Timeout, Audit und Versionspins; interne Read-only-Tools; begrenzter O4-Dateiwrite | 56 % im Manifest. Allgemeine GitHub-/PostgreSQL-/Filesystem-/Playwright-/E2B-Adapter bleiben contract/dry-run; Writes bleiben allowlist- und owner-gegatet. |
| **L6 Memory** | Redis Working Memory, PostgreSQL/pgvector, Konsolidierung/Purge, Cloudflare D1 Persistenz und begrenzter Vectorize-Semantikbeweis | 100 % im Manifest für den itemisierten Vertrag. Beweise bleiben an ihren jeweiligen lokalen bzw. Hosted-Scope gebunden. |
| **L7 Observability** | Audit-Feed, Request-/Trace-Korrelation, Metriken, Evidenzartefakte und begrenzte Hosted-OTLP-Ingestion | 100 % im Manifest. Keine Behauptung vollständiger Grafana-/Langfuse-Dashboards, Alerts oder Trace-UX. |

## Vertikale Verbindung

1. **L1 → L2:** Same-Origin HTTP/SSE aus den Workspace-Flächen an den Orchestrator.
2. **L2 → L3:** LangGraph erzeugt policy-gegatete Task-Envelopes für die vier Rollen.
3. **L3 → L4/L5:** Agenten beziehen Modellantworten ausschließlich über L4 und Tools ausschließlich über L5.
4. **L2/L3/L4/L5 → L6:** Checkpoints, Arbeitsgedächtnis und Langzeitgedächtnis speichern nur über die gebundenen Adapter.
5. **Alle Layer → L7:** Request-ID, Trace-ID, Audit und Evidence korrelieren jeden zulässigen Effekt.

## Horizontale Ausführung

`Prompt → Orchestrator → Agent Pool → LLM/MCP → Memory → Audit/Evidence → UI-Projektion`

## Stop-Gates

Production-Deploy, Release-Promotion, Registry-Push, Default-Branch-Write,
Secret-/Scope-Erweiterung, allgemeine Live-MCP-Writes und Live-Provider-
Aktivierung benötigen die in `AGENTS.md` festgelegte Owner-/Review-Freigabe.

`MARKET_READY:false`; DEV-ONLY, hosted proof still blocked.

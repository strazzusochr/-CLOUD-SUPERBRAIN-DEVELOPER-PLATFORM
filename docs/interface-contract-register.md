# Interface Contract Register

Stand: 2026-04-23
Status: Active architecture contract register
Bezug: `docs/monorepo-structure.md`, `docs/architecture-map.md`, `docs/system-architecture.md`

## 1. Zweck

Dieses Register macht die erwarteten Schnittstellen zwischen den Hauptschichten sichtbar, bevor Implementierung beginnt. Es ist kein API-Schemaersatz, sondern ein Governance-Register fuer Verantwortungen und Grenzen.

## 2. Register

| Vertrag | Von | Nach | Zweck | Mindestgarantien | Offene Punkte |
| --- | --- | --- | --- | --- | --- |
| `IF-001` | `Schicht 1 Frontend` | `Schicht 2 Orchestrierung` | Prompt-, Session- und Streaming-Kommunikation via REST/SSE | Auth-pruefbar, streamingfaehig, keine Secrets im Client, keine direkten LLM- oder DB-Calls | Transportformat und Fehlerstandard |
| `IF-002` | `Schicht 2 Orchestrierung` | `Schicht 3 Agent-Pool` | Aufgabenstart, Rollensteuerung, Ergebnisaggregation | Iterationslimit, Abbruchgrund, strukturierte Resultate, kein direkter Main-Pfad | Squad-Task-Schema |
| `IF-003` | `Schicht 3 Agent-Pool` | `Schicht 4 LLM-Gateway` | generische LLM-Anfragen ueber LiteLLM und Provider-Rotation | Rate-Limit, Cost-Tracking, Fallback-Grund, kein direkter Provider-Call | konkrete Cost-Event-Felder |
| `IF-004` | `Schicht 3 Agent-Pool` | `Schicht 5 Tool-MCP-Schicht` | Werkzeugzugriff fuer GitHub, Browser, E2B, PostgreSQL und Filesystem | Timeout, Request-Logging, Fehlermodus, Tool-Scopes, Branch-Schutz | feinere Tool-Scopes |
| `IF-005` | `Schicht 2/3 Orchestrierung und Agenten` | `Schicht 6 Memory` | Speichern, Abrufen und Verdichten von Kontext | Retention-Regel, Zugriffspfad, keine Secrets, keine unendliche Akkumulation, keine Memory-Purge ohne User-Bestaetigung | konkrete Supabase/Qdrant/pgvector Runtime-Grenze |
| `IF-006` | `alle Runtime-Schichten` | `Schicht 7 Observability` | Traces, Metriken, Kosten, Audit- und Evidence-Signale | korrelierbare Runs, Kostenfelder, Gate-relevante Events, keine Secrets in Logs | Langfuse-Stack-Grenze aus Gate A |
| `IF-007` | `Infrastructure` | `Vercel/Hetzner/Cloudflare` | Deployment- und Runtime-Konfiguration | kein Localhost-Pfad, Secret-Injektion nur zur Laufzeit, interne Kommunikation ueber Docker-Netzwerk | konkrete Hosting-Verteilung pro Phase |
| `IF-008` | `Schicht 5 Tool-MCP-Schicht` | `GitHub / CI-CD` | PR-, Pipeline- und Release-Integration | Human-Review vor Main, Branch-Schutz, kein Release ohne Pipeline | GitHub-App-Detaildesign |
| `IF-009` | `Schicht 1 Frontend` | `Schicht 7 Observability` | UI-relevante Status-, Budget- und Fehleranzeige aus freigegebenen Events | keine Rohtraces oder Secrets in Main-App-UI, Observability bleibt separates System | exakte Dashboard-/Banner-Feldliste |

## 3. Pflege-Regeln

1. Neue systemrelevante Schnittstelle bedeutet neuer Registereintrag.
2. Architektur- oder Sicherheitsrelevante Vertragsaenderung verlangt ADR oder Verweis auf bestaetigte Entscheidung.
3. Offene Punkte duerfen nicht still aus dem Register verschwinden.

## 4. Verifikation

Dieses Register gilt fuer Phase 0 als ausreichend, wenn:

1. alle Kernfluesse zwischen den Hauptschichten erfasst sind,
2. jeder Vertrag einen klaren Zweck und Mindestgarantien hat,
3. offene Punkte explizit markiert sind,
4. keine Schnittstelle lokale Betriebsannahmen oder Secret-Leaks voraussetzt.

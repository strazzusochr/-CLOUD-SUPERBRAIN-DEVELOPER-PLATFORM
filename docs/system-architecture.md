# System Architecture

Stand: 2026-04-23
Status: Binding architecture anchor from `TEIL 2`
Bezug: `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE.md`, Abschnitt `TEIL 2`

## 1. Zweck

Dieses Dokument macht `TEIL 2 - VOLLSTAENDIGE SYSTEM-ARCHITEKTUR` als operatives Architektur-Artefakt im Repo nutzbar.
Es ersetzt den Masterplan nicht, sondern dient als schnelle, verbindliche Arbeitskarte fuer Planung, Implementierung, Review und Verifikation.

Keine Schicht darf still Verantwortung, Schnittstellen, Budgetgrenzen oder verbotene Aktionen aendern. Jede strukturelle Abweichung braucht Owner-Freigabe und einen ADR.

## 2. Sieben technische Systemschichten

| Schicht | Besitzer | Input | Output | Aufgabe | Verboten |
| --- | --- | --- | --- | --- | --- |
| `1 - Eingabe / Frontend` | Vercel, Next.js, shadcn/ui | User-Prompt in natuerlicher Sprache | strukturierter Request an Orchestrierung via REST/SSE | Prompt empfangen, Streaming anzeigen, Agent-Status visualisieren, Memory-Viewer und Budget-Banner bereitstellen | direkte LLM-Calls, direkte DB-Calls, Secrets, technische Rohdaten in der Hauptoberflaeche |
| `2 - Orchestrierung` | Hetzner CPX51, LangGraph, FastAPI | strukturierter Request vom Frontend | Streaming-Events an Frontend, Task-Assignments an Agenten | Intent parsen, Task-Plan erstellen, Agenten auswaehlen, State verwalten, Ergebnisse aggregieren, Error-Handling | LLM-Training, DB-Schema-Aenderungen ohne Migration, direkte Tool-Calls ohne MCP-Layer |
| `3 - Agent-Pool` | Hetzner Docker-Container, einer pro Agent-Typ | Task-Assignment vom Orchestrator | Ergebnis-Report an Orchestrator, State-Update an Memory | spezialisierte Tasks fuer Code, Test, Research, Deploy, Docs und Security ausfuehren | direkter Zugriff auf andere Agenten, Schreiben in `main`, Code-Ausfuehrung ausserhalb E2B-Sandboxes, Direct-DB-Write in Production |
| `4 - LLM-Gateway` | LiteLLM auf Hetzner plus Cloudflare AI Gateway fuer Caching | generischer LLM-Request von Agenten | LLM-Response vom gewaehlten Provider | Routing, Rate-Limiting, Cost-Tracking, Modell-Selektion, Fallback-Rotation, Provider-Rotation-Logging | direkte Provider-Calls ohne Gateway, Caching sensitiver Prompts, Budget-Ueberschreitung ohne Alert |
| `5 - Tool-MCP-Schicht` | Hetzner MCP-Server-Container, mindestens 2 Instanzen fuer kritische Tools | Tool-Request von Agenten | Tool-Ergebnis an Agenten | GitHub, Browser, E2B, Datenbank und Filesystem standardisiert bereitstellen | Tool-Calls ohne Request-Logging, Tool-Calls ohne Timeout-Schutz, GitHub-Push ohne Branch-Schutz |
| `6 - Memory-Schicht` | Redis, Supabase/pgvector zu Hetzner pgvector, optional Neo4j | Kontextdaten und Suchanfragen von Agenten | historischer Kontext und semantische Suchergebnisse | Kontext ueber Sessions bewahren, semantische Suche, Wissensgraph, Konsolidierung alle `30 Minuten` | unverschluesseltes Speichern von Secrets, Memory-Purge ohne User-Bestaetigung, In-Memory-Checkpointing in Production |
| `7 - Observability` | Langfuse self-hosted, Prometheus/Grafana, Helicone free tier | Events von allen anderen Schichten ueber definierte Logging-Interfaces | Dashboards, Alerts, Traces, Cost-Reports | Aktionen sichtbar machen, Kosten tracken, Fehler erkennen, Rotationshistorie und Audit-Log pflegen | Traces fuer schnelle Tests ueberspringen, Mischen mit Main-App-UI, Secrets in Logs speichern |

## 3. Deployment-Targets

| Target | Rolle | Explizite Grenzen | Kostenannahme |
| --- | --- | --- | --- |
| `Vercel` | ausschliesslich Frontend, Next.js App Router, kurze Edge-Calls, Streaming-Interface | keine Datenbankverbindungen, keine Langzeitprozesse, keine Agent-Logik | `0 EUR` Free Tier bis Phase 6 angenommen |
| `Hetzner CPX51` | LangGraph-Orchestrator, Agent-Container, MCP-Server, Redis, LiteLLM, Observability-Stacks, Nginx-Proxy | interne Service-Kommunikation nur ueber Docker-Netzwerk, nicht ueber oeffentliches Internet | Spannbreite aus Masterplan `6-42 EUR/Monat`; harte Projektgrenze bleibt `20 EUR/Monat` ohne Owner-Freigabe |
| `Cloudflare Free Tier` | DNS, DDoS-Schutz, CDN, AI Gateway Caching, Browser Run fuer Agent-Browser-Steuerung | keine Datenbankverbindungen | Free Tier |

## 4. Vollstaendiger Datenfluss

```text
User-Prompt (Vercel Frontend / Next.js)
  -> REST/SSE
FastAPI Orchestrator (Hetzner)
  -> LangGraph Graph
  -> Intent-Parser -> Task-Router
  -> Task-Assignment
  -> Agent-Executor (4x isolierte Docker-Container)
     -> LiteLLM Gateway (Hetzner) -> Cloudflare AI Gateway Cache
        -> LLM Provider (HF Inference / Groq / Together.ai / Anthropic)
     -> MCP-Server (Hetzner)
        -> GitHub Tool -> feature/agent-* Branch only
        -> E2B Sandbox -> Code Execution isolated
        -> Playwright-MCP -> Browser Automation
        -> PostgreSQL-MCP -> read-only Projekt-Kontext
        -> Filesystem-MCP -> Temp-Workspace only
     -> Memory-Schicht
        -> Redis Working Memory, TTL 30 Minuten
        -> Konsolidierung alle 30 Minuten
        -> Supabase pgvector fuer Long-Term Embeddings
        -> Phase 4+: Hetzner pgvector Migration aus Supabase
  -> Result-Aggregator -> Memory-Updater
  -> Streaming-Events (SSE)
Vercel Frontend

Parallel:
  -> Langfuse self-hosted fuer Traces
  -> Prometheus/Grafana fuer System-Metriken
  -> Helicone fuer LLM-Kosten pro Agent
```

## 5. Open-Source-Standard-Stack

| Bereich | Verbindlicher Standard | Abweichungsregel |
| --- | --- | --- |
| Orchestrierung | LangGraph OSS, ergaenzt durch CrewAI OSS fuer rollenbasierte 4er-Squads | ADR und Owner-Freigabe |
| LLM-Gateway | LiteLLM OSS auf Hetzner plus Cloudflare AI Gateway Caching | ADR und Owner-Freigabe |
| LLM-Anbieter | Hugging Face Serverless Inference, Groq, Together.ai, Anthropic/OpenAI nur gezielt pro Rolle | GPT-4o niemals Default fuer alle Agenten |
| Tools | MCP-Server OSS, Playwright-MCP, Puppeteer-MCP, GitHub-MCP, PostgreSQL-MCP, Filesystem-MCP, E2B fuer Code-Ausfuehrung | Tool-Scopes, Logging und Timeouts sind Pflicht |
| Datenbank MVP | Supabase free tier plus pgvector | Migration zu Hetzner PostgreSQL/pgvector erst Phase 4 oder per neuem ADR |
| Vector-DB | Qdrant OSS self-hosted auf Hetzner fuer semantische Memory-Schicht | Budget- und Betriebsnachweis |
| Observability Agents | Langfuse OSS self-hosted | separater Stack gemaess Gate A / ADR-006 |
| Observability System | Prometheus und Grafana OSS self-hosted | nicht in Main-App mischen |
| LLM-Kosten | Helicone free tier | keine Kostenblindheit bei produktiven Claims |
| Frontend | Next.js App Router, shadcn/ui, Tailwind | keine direkte Provider- oder DB-Bindung |
| Backend Hosting | Hetzner CPX51 | innerhalb `20 EUR/Monat` oder Owner-Freigabe |
| Edge/CDN | Cloudflare Free Tier | keine DB-Verbindungen |
| Container-Management | Docker Compose Phase 1-5, K3s erst Phase 6 bei Bedarf | kein volles Kubernetes vor Phase 6 |
| CI/CD | GitHub Actions free fuer OSS | kein Deployment ohne Pipeline |
| 3D Rendering | Three.js oder Babylon.js, WebGPU plus WebGL-Fallback im Browser | kein Server-Side-Rendering Phase 1-5 |
| 3D Asset Storage | Cloudflare R2 free tier fuer kleine Volumen | Budgetpruefung vor Wachstum |

## 6. Sekundaere Optionen nur mit Owner-Freigabe

Diese Optionen sind nicht Standard:

1. AutoGen vor Phase 6
2. SuperAGI als Basis
3. GPT-4o als Standard fuer alle Agenten
4. vollstaendiges Kubernetes statt K3s
5. LangSmith hosted statt Langfuse
6. Hetzner GPU-Server vor Phase 6

## 7. Aktive Architektur-Gates

Diese Punkte duerfen nicht still als geloest behandelt werden:

1. `Gate A - Observability`: Langfuse self-hosted bleibt Zielbild, aber der operative Stack muss separat vom Main-App-Compose gefuehrt oder per ADR anders entschieden werden.
2. `Gate B - Datenbank`: `ADR-004` bleibt aktiv; Supabase ist MVP-Startdatenbank. Hetzner PostgreSQL/pgvector ist Zielbild ab Phase 4 oder per neuem ADR.
3. `Budget-Gate`: Hetzner CPX51 wird nur innerhalb des harten `20 EUR/Monat` Infrastrukturrahmens oder nach expliziter Owner-Freigabe aktiviert.
4. `Release-Gate`: kein Deployment ohne CI/CD-Pipeline, Observability-Integration und Release-Checkliste als Git-Artefakt.

## 8. Verifikation dieses Artefakts

Dieses Dokument ist verifiziert, wenn:

1. alle sieben Schichten aus `TEIL 2` mit Besitzer, Input, Output, Aufgabe und Verboten erfasst sind,
2. die drei Deployment-Targets mit Grenzen und Kostenannahmen dokumentiert sind,
3. der Datenfluss Frontend -> Orchestrator -> Agenten -> Gateway/MCP/Memory -> Frontend plus parallele Observability abgebildet ist,
4. der Open-Source-Standard-Stack sichtbar ist,
5. offene Gate-Konflikte nicht als erledigt behauptet werden.

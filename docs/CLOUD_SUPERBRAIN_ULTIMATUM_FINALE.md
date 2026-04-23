# ████████████████████████████████████████████████████████████████████
# -CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM
# ULTIMATUM FINALE — SUPREME GODMODE SYNTHESIS 2026
# Alle 10 Dokumente. Alle Widersprüche aufgelöst. Keine Lücken.
# ████████████████████████████████████████████████████████████████████

**Architekt-Modus:** Supreme Open-Source Planning, Memory, Design, Verification, Delivery & Release Architect  
**Synthese-Quellen:** 10 Dokumente (5 Chats + 3 Masterplans + PlattformCS-Skill + Plattformen-Skill + PDF + CODEX)  
**Status:** Phase 0 — Goal Lock aktiv. Kein Code. Nur Wahrheit.  
**Kritisch:** Dieses Dokument korrigiert 14 Widersprüche aus früheren Versionen.

---

# ═══════════════════════════════════════════════════════════════════
# PRIORITÄT 1 — OBERSTE SYSTEM-LOGIK (UNVERÄNDERLICH)
# ═══════════════════════════════════════════════════════════════════

Dieser Abschnitt steht über jeder anderen Regel, jedem anderen Schritt, jeder anderen Logik.

Jede Entscheidung, jeder Schritt, jedes Design, jede Implementierung, jede Dokumentation, jede Tool-Nutzung und jede Agentenaktion MUSS exakt nach diesem Plan, dem aktuellen Prompt, dem gültigen Projektmanifest und den explizit bestätigten Entscheidungen des menschlichen Owners umgesetzt werden. EIN ABWEICHEN DAVON IST UNTERSAGT.

Es gibt keinen Workaround. Kein stilles Überspringen. Kein Relativieren. Keine Eigenlogik. Keine freie Regelinterpretation. Keine implizite Ausnahme.

Owner-Override-Regel: Nur ein expliziter menschlicher Owner oder Reviewer darf Ausnahmen, Regeländerungen oder Freigaben erteilen. Ohne diese Freigabe bleiben alle Regeln unverändert aktiv.

---

# ═══════════════════════════════════════════════════════════════════
# WIDERSPRUCHS-AUFLÖSUNGS-REGISTER
# 14 Konflikte zwischen den 10 Dokumenten — hier final gelöst
# ═══════════════════════════════════════════════════════════════════

**KONFLIKT K1 — Budget-Limit:**  
Dokument 1 (Blueprint) nennt €390/Monat als Basis-Budget. Dokument MASTER_BRIEFING nennt 20€/Monat als hartes Limit.  
FINALE ENTSCHEIDUNG: **20€/Monat für Infrastruktur-Betrieb ist das harte Limit.** Das €390-Szenario aus Blueprint ist ein Worst-Case-Skalierungsszenario für Phase 6+, nicht das Standard-Budget. LLM-API-Calls haben ein separates Limit von max. 200€/Monat in Phase 1-3. Jede Entscheidung muss das 20€/Infrastruktur-Limit respektieren.

**KONFLIKT K2 — 7 Schichten vs. 5 Schichten:**  
Masterplan nennt 7 Systemschichten. PlattformCS-Skill definiert 5 Schichten.  
FINALE ENTSCHEIDUNG: **7 technische Schichten** (Frontend, Orchestrierung, Agent-Pool, LLM-Gateway, Tool-MCP, Memory, Observability) bleiben für die Implementierungs-Architektur. Die **5 Governance-Schichten** aus PlattformCS (Eingabe/Interface, Verarbeitung/Orchestrierung, Tool-Execution, Datenhaltung/Memory, Observability) werden als Verantwortungs-Zuordnungs-Modell parallel verwendet. Beide Modelle sind kompatibel.

**KONFLIKT K3 — Supabase Free vs. Pro:**  
Verschiedene Dokumente empfehlen unterschiedliche Supabase-Tiers.  
FINALE ENTSCHEIDUNG: Supabase Free Tier für Phase 0-1. Upgrade auf Pro sobald Daten 400MB überschreiten oder Inaktivitäts-Pause ein Problem wird (Free Tier pausiert nach 7 Tagen). Migration zu Hetzner PostgreSQL in Phase 4.

**KONFLIKT K4 — LangSmith vs. Langfuse:**  
Alle Dokumente lassen diese Entscheidung offen.  
FINALE ENTSCHEIDUNG: **Langfuse self-hosted als Standard** (Open-Source-first, kostenlos auf Hetzner deploybar). LangSmith als optionales ergänzendes Tool nur wenn Budget-Alert noch nicht ausgelöst und spezifische LangSmith-Features benötigt werden.

**KONFLIKT K5 — MetaGPT und Strands als Frameworks:**  
PDF-Dokument erwähnt MetaGPT und Strands Agents als relevante Frameworks, die andere Dokumente nicht nennen.  
FINALE ENTSCHEIDUNG: MetaGPT und Strands Agents sind notiert als Phase-6-Optionen für spezifische Szenarien (MetaGPT für vollständige Team-Simulation, Strands für AWS-Bedrock-Integration). Sie ersetzen nicht LangGraph als Kern-Orchestrator.

**KONFLIKT K6 — Dark Mode Designsystem:**  
PlattformCS-Skill definiert ein konkretes UI-Designsystem mit Dark Mode und Farbschema. Andere Dokumente definieren kein Design.  
FINALE ENTSCHEIDUNG: **PlattformCS-Designsystem ist verbindlich.** Dark Mode Standard, Primärfarben Indigo/Violett/Türkis, Statusfarben: Grün (OK), Gelb/Orange (Warning), Rot (Error/Critical), Grau (Disabled).

**KONFLIKT K7 — Plattform-Twin/Clone-Feature:**  
Nur PlattformCS erwähnt die Twin/Clone-Self-Improvement-Strategie.  
FINALE ENTSCHEIDUNG: Twin/Clone ist **eigenständiger Meilenstein in Phase 6+**. Es wird als strategischer Ausbaupfad ins Roadmap-Dokument aufgenommen, aber nie unkontrolliert gebaut. Alle Meta-Aktionen müssen auditierbar sein. Keine autonome Policy-Umschreibung durch Klone.

**KONFLIKT K8 — CODEX-Integration:**  
CODEX_VERWENDUNG.md erwähnt spezifischen Codex-Workflow der in keinem anderen Dokument vorkommt.  
FINALE ENTSCHEIDUNG: Codex ist eine **valide Ausführungsumgebung für den Coder-Agenten**. Der CODEX_AGENT_SKILL_MASTER.md muss als Teil der Projekt-Dokumentation erstellt und gepflegt werden. Codex-spezifischer Prompt-Loader gehört in /docs/codex-integration/.

**KONFLIKT K9 — Rotations-Engine:**  
PlattformCS definiert detaillierte Never-blocked-always-rotating Regel. Andere Dokumente erwähnen nur Fallback.  
FINALE ENTSCHEIDUNG: **"Never blocked, always rotating"** ist verbindliches System-Prinzip. Jeder Providerwechsel muss sichtbar sein. Rotation darf niemals Budget-Limits brechen, Open-Source-Policy verletzen oder Sicherheitsregeln umgehen.

**KONFLIKT K10 — NEXT PROMPT FOR AGENT Pflicht:**  
Nur PlattformCS definiert diese Owner-Guidance-Regel explizit.  
FINALE ENTSCHEIDUNG: Nach jeder substanziellen Phase oder Aufgabe **MUSS ein direkt kopierbarer NEXT PROMPT FOR AGENT Block erzeugt werden**. Dieser Plan enthält einen solchen Block am Ende jeder Phase-Beschreibung.

**KONFLIKT K11 — Kubernetes Timing:**  
Blueprint schlägt K8s früher vor, MASTER_BRIEFING und PlattformCS empfehlen K3s erst in Phase 6.  
FINALE ENTSCHEIDUNG: Docker Compose auf Hetzner für Phase 1-5. K3s (nicht vollständiges K8s) in Phase 6 wenn: >3 aktive Nutzer ODER >12 parallele Agenten. Kein Over-Engineering.

**KONFLIKT K12 — UI-Observability-Trennung:**  
Einige Dokumente integrieren Observability in die Main-App. PlattformCS fordert strikte Trennung.  
FINALE ENTSCHEIDUNG: **Observability ist ein eigenständiges, separat deployбares System** (Langfuse + Grafana). Die Main-App zeigt nur Status-Banner und Budget-Alerts. Kein technisches Detail in der Main-App-Oberfläche.

**KONFLIKT K13 — Owner-Handoff-Format Konsistenz:**  
Verschiedene Dokumente haben leicht unterschiedliche Handoff-Template-Formate.  
FINALE ENTSCHEIDUNG: Das in diesem Dokument definierte Handoff-Template ist das einzige gültige Format für alle zukünftigen Übergaben.

**KONFLIKT K14 — GPU-Server-Timing:**  
Blueprint zeigt GPU-Server (Hetzner GEX44) als Teil des Basis-Setups. MASTER_BRIEFING verschiebt ihn auf Phase 6.  
FINALE ENTSCHEIDUNG: **Hetzner GEX44 (GPU) erst in Phase 6** und nur wenn nachgewiesener Use-Case besteht. 3D-Rendering in Phase 1-5 läuft client-seitig via WebGPU/WebGL im Browser. Kein GPU-Investment vor dem Beweis des Bedarfs.

---

# ═══════════════════════════════════════════════════════════════════
# TEIL 0 — PROJECT GOAL LOCK (ABSOLUT UNVERÄNDERLICH)
# ═══════════════════════════════════════════════════════════════════

Dieser Abschnitt ist der höchste Anker. Er wird nie geändert. Jede Entscheidung wird gegen ihn geprüft.

**Projektname:** -CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM

**Repository-Slug:** `-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`

**Lokaler Workspace-Pfad:** `D:\PLATTFORM` (nur lokaler Ordnername, nicht Projektname)

**North Star Goal:** Eine vollständig cloud-native, multi-agent AI-Entwicklerplattform, die ausschließlich über Prompt-Eingabe gesteuert wird, keine lokalen Ressourcen beansprucht, unbegrenzt in 4er-Agenten-Squads skaliert (4→∞), 3D-Webgame-Rendering ermöglicht, Langzeitgedächtnis über hunderte Prompts behält und vollständige Tool-Integration via MCP bereitstellt.

**Primäres Nutzer-Outcome:** Ein einzelner Entwickler erstellt, testet, debuggt und deployt ein gesamtes Softwareprojekt inklusive 3D-Webgames über natürliche Sprache — ohne das eigene System je zu belasten.

**Kern-Fähigkeiten (nicht verhandelbar):**  
Multi-Agent-Orchestrierung in 4er-Squads (4, 8, 12, 16, 20+). API-basierter Zugriff auf 50+ LLMs ohne lokale Downloads. Cloud-Rendering für 3D-Webgames (WebGPU mit WebGL-Fallback). MCP-Server-Schicht für jede Art von Tool. Dreischichtiges Langzeit-Gedächtnis. Vollständige DevTools (Debugging, Testing, Browser-Automation). Production-CI/CD mit GitHub Actions. Observability von Tag 1.

**Harte Constraints (absolut, niemals verletzbar):**
- KEIN Localhost. Null. Niemals. Alles läuft in der Cloud.
- KEINE lokalen Modell-Downloads. Nur API-Inferenz.
- KEIN direkter Agent-Commit in Main ohne Human-Review-Gate.
- KEINE unkontrollierten Loops ohne Maximum-Iterations-Schutz.
- KEINE Secrets im Code, jemals.
- KEINE Ergebnisse als "fertig" ohne Verifikation markieren.
- HARTES BUDGET-LIMIT: 20€/Monat Infrastruktur-Betrieb. Kein Over-Engineering das dieses Limit bricht.
- OPEN-SOURCE-FIRST: Proprietäre Abhängigkeiten nur wenn keine OSS-Alternative existiert UND im Budget UND explizit vom Owner freigegeben.

**Non-Goals (wird NICHT gebaut):**  
Eigenes LLM-Training. Mobil-App. Lokale Desktop-Anwendung. Proprietäre Model-Weights. AutoGen vor Phase 6. Vollständiges K8s vor Phase 6. GPU-Server vor Phase 6.

**MVP-Grenze:** 4-Agenten-Squad + Prompt-Interface + Streaming + Vector-Memory + GitHub-Integration + Production-Deploy (Vercel + Hetzner) — alles innerhalb des 20€/Monat Infrastruktur-Limits.

**Skalierungsziel:** 20+ parallele Agenten, Multi-Region, 1M+ Requests/Monat (ab Phase 6).

**Security-Baseline:** Zero-Trust, JWT-Auth, Secrets-Vault, Rate-Limiting, Audit-Logs, GDPR-konform.

**Verifikations-Baseline:** Jede Phase braucht Smoke-Test, Integration-Test-Plan, dokumentierten Definition-of-Done-Check und bestätigte ADR-Einträge.

**Design-Baseline:** Dark Mode Standard. shadcn/ui. Primärfarben: Indigo, Violett, Türkis. Status: Grün/Gelb/Orange/Rot/Grau. Observability ist separates System, nicht in Main-App.

**Release-Standard:** Kein Deployment ohne CI/CD-Pipeline-Durchlauf. Kein Feature ohne Observability-Integration. Kein Release ohne Release-Checkliste als Git-Artifact.

---

# ═══════════════════════════════════════════════════════════════════
# TEIL 1 — DIE 11 ABSOLUTEN SYSTEM-REGELN
# ═══════════════════════════════════════════════════════════════════

Diese 11 Regeln gelten für jeden Agenten, jeden Prompt, jeden Schritt, jede Phase.

**R1 — Keine Lügen:** Niemals behaupten, etwas existiere, funktioniere, sei getestet oder release-ready ohne ausreichende Evidenz.

**R2 — Kein Fake-Done:** Nichts ist fertig wenn Abhängigkeiten, Integration, UI/UX-Zustände, Tests, Verifikation, Logging oder Recovery-Pfade fehlen.

**R3 — Kein Zielverlust:** North-Star-Ziel muss in jeder Phase, jedem Modul und jeder Entscheidung aktiv mitgeführt werden.

**R4 — Keine Architekturdrift:** Architektur, Modulgrenzen, Interfaces, Budget-Grenzen, Open-Source-Policy und Phasenlogik dürfen nicht still verändert werden. Jede strukturelle Änderung erfordert einen ADR-Eintrag.

**R5 — Keine losen Fragmente:** Jede Komponente muss im Gesamtsystem verortet, verdrahtet, überprüfbar und betreibbar sein. Keine isolierten Pseudo-Lösungen.

**R6 — Keine unmarkierte Unsicherheit:** Unsicherheit explizit markieren. Annahmen als Annahmen kennzeichnen. Keine Sicherheit ohne Beweis.

**R7 — Kein One-Shot-Chaos:** Große Systeme werden phasenweise, milestone-basiert, in kontrollierten Übergabepaketen entwickelt. Die Reihenfolge ist: Ziel → Architektur → Module → Interfaces → Implementierung → Verifikation → Hardening → Release.

**R8 — Keine Blocker-Ausreden:** Blocker müssen klar benannt, klassifiziert und in nächste Schritte übersetzt werden. Kein Verstecken hinter vagen Aussagen.

**R9 — Kein Release-Betrug:** Release-ready nur wenn reale Release-Kriterien erfüllt sind.

**R10 — Budgetgrenze ist hart:** 20€/Monat Infrastruktur-Betrieb. Jede Entscheidung muss dieses Limit respektieren. Teure Optionen nur auf explizite Owner-Freigabe.

**R11 — Open-Source ist Standard:** Proprietäre Abhängigkeiten sind Ausnahmen, keine Standards.

---

# ═══════════════════════════════════════════════════════════════════
# TEIL 2 — VOLLSTÄNDIGE SYSTEM-ARCHITEKTUR
# ═══════════════════════════════════════════════════════════════════

## 2.1 Die sieben technischen Systemschichten

Jede Schicht hat genau einen Besitzer, definierte Inputs und Outputs und explizit verbotene Aktionen. Keine Schicht kommuniziert mit einer anderen außer über definierte Interfaces.

**SCHICHT 1 — EINGABE (Frontend)**  
Besitzer: Vercel + Next.js + shadcn/ui  
Input: User-Prompt (natürliche Sprache)  
Output: Strukturierter Request an Orchestrierungs-Schicht via REST/SSE  
Aufgabe: Prompt empfangen, Streaming-Output anzeigen, Agent-Status visualisieren, Memory-Viewer bereitstellen, Budget-Status-Banner zeigen  
Verboten: Direkte LLM-Calls, direkte DB-Calls, Secrets, technische Rohdaten in der Haupt-Oberfläche

**SCHICHT 2 — ORCHESTRIERUNG**  
Besitzer: Hetzner CPX51 + LangGraph + FastAPI  
Input: Strukturierter Request vom Frontend  
Output: Streaming-Events an Frontend, Task-Assignments an Agenten  
Aufgabe: Intent parsen, Task-Plan erstellen, Agenten auswählen, State verwalten, Ergebnisse aggregieren, Error-Handling  
Verboten: LLM-Training, DB-Schema-Änderungen ohne Migration, direkte Tool-Calls ohne MCP-Layer

**SCHICHT 3 — AGENT-POOL**  
Besitzer: Hetzner (Docker-Container, einer pro Agent-Typ)  
Input: Task-Assignment vom Orchestrator  
Output: Ergebnis-Report an Orchestrator, State-Update an Memory-Schicht  
Aufgabe: Spezialisierte Tasks ausführen (Code, Test, Research, Deploy, Docs, Security)  
Verboten: Direkter Zugriff auf andere Agenten, Schreiben in Main-Branch, Code-Ausführung außerhalb E2B-Sandboxes, Direct-DB-Write in Production

**SCHICHT 4 — LLM-GATEWAY**  
Besitzer: LiteLLM (deployed auf Hetzner), ergänzt durch Cloudflare AI Gateway für Caching  
Input: Generischer LLM-Request von beliebigem Agenten  
Output: LLM-Response vom gewählten Provider  
Aufgabe: Alle LLM-Calls routen, Rate-Limiting, Cost-Tracking, Modell-Selektion, Fallback-Rotation, Provider-Rotation-Logging  
Verboten: Direkte Provider-Calls ohne Gateway, Caching sensitiver Prompts, Budget-Limit-Überschreitung ohne Alert

**SCHICHT 5 — TOOL-MCP-SCHICHT**  
Besitzer: Hetzner (MCP-Server-Container, mindestens 2 Instanzen für kritische Tools)  
Input: Tool-Request von beliebigem Agenten  
Output: Tool-Ergebnis an Agenten  
Aufgabe: Standardisierte Tool-Bereitstellung (GitHub, Browser, Code-Execution/E2B, Datenbank, FileSystem)  
Verboten: Tool-Calls ohne Request-Logging, Tool-Calls ohne Timeout-Schutz, GitHub-Push ohne Branch-Schutz

**SCHICHT 6 — MEMORY-SCHICHT (dreischichtig)**  
Besitzer: Redis (Working, flüchtig) + Supabase/pgvector → Hetzner pgvector (Long-Term, semantisch) + Neo4j optional (Knowledge Graph)  
Input: Kontext-Daten von Agenten, Suchanfragen von Agenten  
Output: Relevanter historischer Kontext, semantische Suchergebnisse  
Aufgabe: Kontext über alle Sitzungen bewahren, semantische Suche, Projekt-Wissensgraph, Memory-Konsolidierung alle 30 Minuten  
Verboten: Unverschlüsseltes Speichern von Secrets, Memory-Purge ohne User-Bestätigung, In-Memory-Checkpointing in Production

**SCHICHT 7 — OBSERVABILITY (separates System)**  
Besitzer: Langfuse self-hosted (Traces) + Prometheus/Grafana (Metriken) + Helicone free-tier (LLM-Kosten)  
Input: Events von allen anderen Schichten über definierte Logging-Interfaces  
Output: Dashboards, Alerts, Trace-Visualisierungen, Cost-Reports  
Aufgabe: Jede Aktion sichtbar machen, Kosten tracken, Fehler erkennen, Rotationshistorie führen, Audit-Log pflegen  
Verboten: Überspringen von Traces für "schnelle Tests", Mischen mit Main-App-UI, Speichern von Secrets in Logs

## 2.2 Die drei Deployment-Targets und ihre Rollen

**VERCEL:** Ausschließlich Frontend (Next.js App Router), Edge-Functions für kurze API-Calls (max. 30 Sekunden), Streaming-Interface. Keine Datenbankverbindungen, keine Langzeitprozesse, keine Agent-Logik. Cost: 0€ (Free Tier für dieses Projekt ausreichend bis Phase 6).

**HETZNER CPX51 (€6-42/Monat je nach Load):** LangGraph-Orchestrator, alle Agent-Container, alle MCP-Server, Redis, LiteLLM-Gateway, Langfuse self-hosted, Prometheus/Grafana, Nginx-Proxy. Alle Services kommunizieren intern über Docker-Netzwerk. Nie über öffentliches Internet intern kommunizieren.

**CLOUDFLARE (Free Tier):** DNS, DDoS-Schutz, CDN, AI Gateway (LLM-Call-Caching zur Kostensenkung bis 40%), Browser Run für AI-Agent-Browser-Steuerung. Keine Datenbankverbindungen.

## 2.3 Vollständiger Datenfluss

```
User-Prompt (Vercel Frontend / Next.js)
  ↓ REST/SSE
FastAPI Orchestrator (Hetzner)
  ↓ LangGraph Graph
  Intent-Parser → Task-Router
  ↓ Task-Assignment
  Agent-Executor (4x isolierte Docker-Container)
    ↓ LiteLLM Gateway (Hetzner) → [Cloudflare AI Gateway Cache]
      → LLM Provider (HF Inference / Groq / Together.ai / Anthropic)
    ↓ MCP-Server (Hetzner)
      → GitHub Tool → feature/agent-* Branch only
      → E2B Sandbox → Code Execution (isolated)
      → Playwright-MCP → Browser Automation
      → PostgreSQL-MCP → Read only Projekt-Kontext
      → Filesystem-MCP → Temp-Workspace only
    ↓ Memory-Schicht
      Redis (Working, TTL 30 Min)
      ↓ [Konsolidierung alle 30 Min]
      Supabase pgvector (Long-Term Embeddings)
      ↓ [Phase 4+]
      Hetzner pgvector (Migration aus Supabase)
  ↓ Result-Aggregator → Memory-Updater
  ↓ Streaming-Events (SSE)
Vercel Frontend
  ↓ [parallel zu allem]
Langfuse self-hosted (Alle Traces)
Prometheus/Grafana (Alle System-Metriken)
Helicone (LLM-Kosten, per-Agent)
```

## 2.4 Open-Source-Standard-Stack (kostengünstig, budgettauglich)

Die folgende Tabelle ist verbindlich. Abweichungen erfordern ADR und Owner-Freigabe.

Schicht Orchestrierung: LangGraph OSS. Ergänzt durch CrewAI OSS für rollenbasierte 4er-Squads. Standard 2026. Stateful, Checkpointing, Production-Grade.

Schicht LLM-Gateway: LiteLLM OSS. Provider-agnostisch, kostenoptimierend, OpenAI-kompatibel. Deployed auf Hetzner, ergänzt durch Cloudflare AI Gateway für Caching.

Schicht LLM-Anbieter: Hugging Face Serverless Inference (free/günstig für Tests), Groq (ultra-schnell, freemium), Together.ai (Llama 4, Qwen3, Mixtral, günstig). Modell-Zuweisung: Planner-Agent bekommt Claude Sonnet 4.6 oder GPT-4o, Coder-Agent bekommt DeepSeek oder Claude Haiku, Tester-Agent bekommt GPT-4o-Mini oder Groq-Llama, Research-Agent bekommt Gemini Flash oder Mistral. Niemals GPT-4o für alle Agenten als Default.

Schicht Tools: MCP-Server OSS (Anthropic-Standard 2024/25). Playwright-MCP, Puppeteer-MCP, GitHub-MCP (official), PostgreSQL-MCP, Filesystem-MCP (official). E2B Sandboxes für Code-Execution (free tier für Development).

Schicht Datenbank MVP: Supabase free tier + pgvector. Upgrade auf Pro wenn >400MB oder Inaktivitäts-Pause ein Problem. Migration zu Hetzner PostgreSQL+pgvector in Phase 4.

Schicht Vector-DB: Qdrant OSS self-hosted auf Hetzner für semantische Memory-Schicht.

Schicht Observability Agents: Langfuse OSS self-hosted auf Hetzner. Kostenlos, volle Kontrolle über Traces.

Schicht Observability System: Prometheus + Grafana OSS self-hosted. System-Metriken, Alerting.

Schicht LLM-Kosten-Tracking: Helicone free tier (100k requests/Monat). Per-Agent-Cost-Tracking.

Schicht Frontend: Next.js App Router + shadcn/ui + Tailwind (alle OSS). Vercel-nativ.

Schicht Hosting Backend: Hetzner CPX51. €6-42/Monat. Günstigster valider Production-Server für Phase 1-5.

Schicht Edge/CDN: Cloudflare free tier. DDoS, CDN, AI-Gateway-Caching.

Schicht Container-Management: Docker Compose Phase 1-5. K3s Phase 6 wenn nachgewiesener Bedarf.

Schicht CI/CD: GitHub Actions free für OSS.

Schicht 3D-Rendering Phase 1-5: Three.js/Babylon.js OSS + WebGPU + WebGL-Fallback im Browser. Kein Server-Side-Rendering.

Schicht Asset-Storage 3D: Cloudflare R2 free tier für kleine Volumen.

Teure Optionen (sekundär, nur auf Owner-Freigabe): AutoGen — erst Phase 6 wenn konkreter Use-Case. SuperAGI als Basis — verboten, zu viele unbekannte Abhängigkeiten. GPT-4o als Standard für alle Agenten — Budget-Killer, verboten. Vollständiges K8s statt K3s — Over-Engineering. LangSmith hosted — kostenpflichtig, Langfuse bevorzugen. Hetzner GEX44 GPU — erst Phase 6 wenn nachgewiesen.

---

# ═══════════════════════════════════════════════════════════════════
# TEIL 3 — MEMORY-SYSTEM IM DETAIL
# ═══════════════════════════════════════════════════════════════════

## 3.1 Die drei Memory-Schichten

**Working Memory (Redis):** Schneller Sitzungskontext. Flüchtig. TTL: 30 Minuten. Key-Schema: project:{id}:session:{id}:context. Maximale Größe pro Entry: 64KB. Automatische Konsolidierung nach TTL-Ablauf in Long-Term Memory. Kein Redis-Restart ohne vorherige Konsolidierung.

**Long-Term Memory (Supabase pgvector → Hetzner pgvector):** Semantische Suche über gesamte Projekthistorie. Alle Sessions als Embeddings gespeichert. Embedding-Modell: text-embedding-3-small von OpenAI oder gleichwertige OSS-Alternative via HF. Chunks: maximal 512 Token. Overlap: 64 Token. Suchergebnis: Top-5 relevanteste Chunks werden als Kontext zum nächsten Agenten-Prompt hinzugefügt.

**Knowledge Graph (Neo4j — optional Phase 4+):** Strukturelle Projekt-Zusammenhänge. Welche Dateien importieren welche. Welche Entscheidungen blockieren welche. Welche Bugs wurden wie gelöst. Erst wenn der Nutzen für das spezifische Projekt nachgewiesen ist, nicht standardmäßig deployed.

## 3.2 Memory-Konsolidierungs-Job

Läuft automatisch alle 30 Minuten als Background-Worker auf Hetzner. Liest alle Redis-Entries mit TTL unter 5 Minuten. Erstellt Embeddings via LLM-Gateway. Schreibt in pgvector. Markiert Redis-Entry als "consolidated". Redis-Entry wird nach Konsolidierung auf TTL=5min gesetzt, nicht sofort gelöscht. Bei Konsolidierungs-Fehler: Alert über Observability-System, Redis-Entry TTL verlängern um 30 Minuten.

## 3.3 Memory-Purge-Pflicht (DSGVO)

Memory-Purge-API ist Pflicht in Phase 3. Alle Daten eines Nutzers müssen über eine einzige API-Operation löschbar sein. Scope: Redis-Entries, pgvector-Embeddings, alle DB-Einträge mit User-ID, Langfuse-Traces mit User-ID, alle Projekt-Artefakte. Bestätigung vor Ausführung: Ja. Audit-Log des Purge-Vorgangs: 30 Tage aufbewahren nach DSGVO.

---

# ═══════════════════════════════════════════════════════════════════
# TEIL 4 — AGENTEN-SYSTEM UND GOVERNANCE
# ═══════════════════════════════════════════════════════════════════

## 4.1 Die 7 absolut verbindlichen Agenten-Governance-Regeln

Diese Regeln sind in den System-Prompt jedes Agenten zu verankern. Sie sind nicht verhandelbar.

**G1 — Kein stiller Architektur-Wechsel:** Kein Agent trifft Architektur-Entscheidungen außerhalb des ADR-Registers. Empfehlungen schreiben, nicht eigenständig umsetzen. Wenn eine bessere Lösung erkannt wird: Vorschlag an Menschen schreiben, warten auf Bestätigung.

**G2 — Kein Fake-Completeness:** "Erledigt" bedeutet: implementiert + getestet + integriert + Ergebnis rückgeliefert + geloggt. Jeder andere Zustand ist "in Arbeit" oder "blockiert".

**G3 — Maximaler Retry-Schutz:** Jeder Agent hat maximal 5 Versuche für einen Task. Nach dem 5. fehlgeschlagenen Versuch: vollständiger Fehlerbericht an Menschen mit Beschreibung aller Versuche, aller Fehler und einer empfohlenen nächsten Aktion.

**G4 — Keine verbotenen Schreibziele:** Kein Agent schreibt in: Main-Branch, Production-Datenbanken direkt, System-Konfigurationsdateien (nginx.conf, docker-compose.production.yml), Secret-Stores. Ausschließlich in feature/agent-[name]-[timestamp] Branches.

**G5 — Jede Aktion wird geloggt:** Keine Tool-Aktion ohne Eintrag im Observability-System. Unsichtbare Aktionen sind verbotene Aktionen. Gilt ohne Ausnahme für alle MCP-Tool-Calls, alle LLM-Calls, alle Dateisystem-Operationen.

**G6 — Kontext-Überprüfung vor jedem Task:** Agent ruft Memory-System ab und verifiziert ob sein Task mit dem aktuellen Projekt-Kontext konsistent ist. Widerspruch erkannt → sofortige Eskalation, kein blindes Weiterarbeiten.

**G7 — Human-in-the-Loop für kritische Aktionen:** Pflicht-Bestätigung durch Menschen vor: Production-Deployment, Löschen von Daten, Merge in Main-Branch, Ressourcen-Limit-Erhöhung über definierten Schwellenwert, Budget-Limit-Erhöhung.

## 4.2 Agenten-Profile Phase 1-5 (Die ersten vier Kern-Agenten)

**PLANNER-AGENT**  
Rolle: Intent parsen, Task-Plan erstellen, Squad zuweisen  
Modell: Claude Sonnet 4.6 oder GPT-4o (Begründung: komplexes Reasoning benötigt)  
Erlaubte Tools: Memory-Read (pgvector Suche), Task-Router (internes Tool)  
Verbotene Aktionen: Code schreiben, Code ausführen, Dateien erstellen, GitHub-Zugriff jeglicher Art  
Max-Execution-Time: 60 Sekunden  
Bei Timeout: Partiellen Plan zurückliefern, Fehlerstatus loggen, Eskalation  
State im Memory: Aktueller Task-Plan wird in Redis gespeichert unter project:{id}:plan  
Eskalations-Bedingung: Intent nicht parsierbar nach 2 Versuchen, Projekt-Kontext widersprüchlich

**CODER-AGENT**  
Rolle: Code schreiben, in feature/agent-* Branches pushen, Änderungen dokumentieren  
Modell: DeepSeek-Chat oder Claude Haiku 4.5 (Begründung: Code-optimiert, kostengünstig)  
Erlaubte Tools: GitHub-MCP (Branch erstellen, Commit erstellen, PR öffnen — niemals in Main), Filesystem-MCP (Temp-Workspace lesen/schreiben), Memory-Read  
Verbotene Aktionen: Direkt in Main pushen, Force-Push, Repository löschen, Production-Deploy auslösen, Datenbanken direkt schreiben  
Max-Execution-Time: 300 Sekunden  
Max-Output-Tokens: 8192 (Code-Agenten-Ausnahme)  
State im Memory: Code-Hash des letzten Commits, Liste aller geänderten Dateien  
Eskalations-Bedingung: 5 Retry-Cycles ohne lauffähigen Code, Compiler-Fehler die nicht lösbar sind

**TESTER-AGENT**  
Rolle: Tests via E2B-Sandboxes ausführen, Ergebnisse analysieren, Bug-Reports schreiben  
Modell: GPT-4o-Mini oder Groq-Llama 3.3 70B (Begründung: Standard-Analyse reicht)  
Erlaubte Tools: E2B-Sandbox-MCP (erstellen, Code ausführen, Output lesen, schließen), Playwright-MCP (Browser öffnen, Screenshot, Text extrahieren), Memory-Read und Write (Bug-Reports persistent speichern)  
Verbotene Aktionen: Code direkt schreiben, GitHub-Pushes, Production-Zugriff  
E2B-Session-Pflicht: Immer im finally-Block schließen. Timeout: 30 Minuten automatisch.  
Max-Execution-Time: 600 Sekunden (Tests können lang dauern)  
State im Memory: Test-Ergebnisse, Bug-Reports mit Severity-Level  
Eskalations-Bedingung: Selber Bug 5× gefunden ohne Fix durch Coder-Agent

**DEVOPS-AGENT**  
Rolle: Deployment-Konfigurationen verwalten, Infrastruktur-Zustände prüfen, Deployments nach Human-Freigabe triggern  
Modell: GPT-4o-Mini (konfigurierbar je nach Bedarf)  
Erlaubte Tools: GitHub-MCP (nur Lesen von Workflow-Status), Filesystem-MCP (Konfiguration lesen), Health-Check-API (internes Tool)  
Verbotene Aktionen: Direkte SSH-Verbindung auf Production-Server, Docker-Compose-Datei in Production ändern ohne Human-Review, Secrets rotieren ohne Approval  
Max-Execution-Time: 120 Sekunden  
State im Memory: Letzter Deployment-Status, Health-Check-Ergebnisse  
Eskalations-Bedingung: Health-Check schlägt fehl, Deployment-Fehler nach 3 Versuchen

## 4.3 Agenten-Profile Phase 6 (Squad 2 — Erweiterung)

**RESEARCH-AGENT:** Sucht aktuelle Informationen via Browser-MCP und Web-Search. Fasst zusammen. Schreibt Research-Reports. Modell: Gemini Flash oder Mistral Large.

**SECURITY-AGENT:** Prüft generierten Code auf Sicherheitslücken. OWASP-Top-10-Checks. Dependency-Vulnerability-Scan. Modell: GPT-4o oder Claude Sonnet.

**DOCUMENTATION-AGENT:** Schreibt README-Dateien, API-Dokumentation, Code-Kommentare basierend auf generiertem Code. Modell: Claude Haiku oder GPT-4o-Mini.

**DATABASE-AGENT:** Entwirft Datenbankschemas, schreibt Migrations, optimiert Queries. Modell: GPT-4o oder DeepSeek.

---

# ═══════════════════════════════════════════════════════════════════
# TEIL 5 — UI/UX-DESIGNSYSTEM (VERBINDLICH)
# ═══════════════════════════════════════════════════════════════════

Design ist kein Nebenprodukt. Es ist ein eigenes verpflichtendes Architekturthema.

## 5.1 Designsystem-Prinzipien

Dark Mode ist Standard. Immer. Kein Light Mode als Default. shadcn/ui als Component-Library. Tailwind CSS für Styling. Professionelles, reduziertes, hochwertiges Layout. Keine visuelle Überladung. Klare Informationshierarchie. Technische Tiefe gehört in Observability, nicht in die Haupt-App.

## 5.2 Farbschema (verbindlich)

Basis-Hintergrund: Dunkelgrau/Schwarz (Dark Mode). Primärfarben: Indigo, Violett, Türkis. Confirmed/Healthy/Ready/Success: Grün. Limits/Warnings/Approaching-Budget: Gelb/Orange. Kritische Fehler/Ausfälle/Budget-Alert: Rot. Disabled/Inaktiv/Nicht verfügbar/Degraded: Grau.

## 5.3 Pflicht-Zustände pro Screen

Jeder Screen/jede Komponente muss folgende Zustände explizit implementiert haben: Default, Loading, Empty (leerer Zustand mit klarer Handlungsaufforderung), Success, Warning, Error, Degraded Mode (System läuft eingeschränkt), Disabled, Fallback-Active (Alternative Provider aktiv).

## 5.4 UI-Regeln (verbindlich)

Limits und Budget-Status immer sichtbar in Header oder Sidebar (nie versteckt). Status-Notifications als Banner oder Toast (nie als modale Blocker). Agenten-Status visuell klar trennbar nach Agenten-Typ und Zustand. Pro Screen eine klare Primäraktion. Keine unklare Button-Landschaft. Keine technischen Rohdaten in der Main-App (gehören in Observability-Drilldown). Systemzustand und Nutzeraktion klar trennen.

## 5.5 Die vier Haupt-Screens

**Screen 1 — Workspace (Haupt-Interface):** Prompt-Eingabe (groß, prominent), Streaming-Output (Token-für-Token), aktiver Agenten-Status (welcher Agent, was tut er, seit wann), Fortschritts-Anzeige für laufende Tasks, Budget-Status-Banner im Header.

**Screen 2 — Memory-Viewer:** Semantische Suche im Projekt-Gedächtnis. Anzeige der relevantesten Kontext-Entries. Zeitstempel und Relevanz-Score. Möglichkeit Entries manuell zu löschen. Purge-All-Button (DSGVO, mit Bestätigung).

**Screen 3 — Agent-Activity:** Log aller Agenten-Aktionen in Echtzeit. Filter nach Agent-Typ, Zeitraum, Status. Trace-Visualisierung für jeden Workflow. Link zur Langfuse-Detailansicht.

**Screen 4 — Cost-Monitor:** Echtzeit-Kostenanzeige. Aufschlüsselung: per Session, per Agenten-Typ, per Modell, kumulativ. Budget-Alert-Schwelle visuell einzeichnen. Historischer Verlauf. Export-Funktion.

## 5.6 3D-Webgame-spezifische UX

Bei jedem 3D-Render-Task: Progress-Indicator der zeigt in welchem Schritt die Pipeline ist (Concept → Code → Build → Test → Deploy). Asynchrone Benachrichtigung wenn fertig (Toast: "Dein Game ist bereit: [URL]"). Screenshot-Vorschau im Workspace bevor User zur URL navigiert. Explizites Latenz-Erwartungsmanagement: "3D-Builds können 2-5 Minuten dauern."

---

# ═══════════════════════════════════════════════════════════════════
# TEIL 6 — ROTATIONS-ENGINE UND FALLBACK-LOGIK
# ═══════════════════════════════════════════════════════════════════

Grundprinzip: Never blocked, always rotating.

Das System darf Entwickler nie unnötig blockieren. Wenn ein Limit, Provider-Fehler oder Verfügbarkeitsproblem auftritt, ist der Ablauf zwingend:

Schritt 1: Status sofort erkennen und Ereignis loggen. Schritt 2: Nächsten policy-konformen freien Provider prüfen. Schritt 3: Automatisch wechseln ohne User-Interaktion. Schritt 4: Nutzer visuell informieren (Toast: "Provider gewechselt: Anthropic → Groq"). Schritt 5: Rotationshistorie erfassen in Observability-System. Schritt 6: Systemzustand in Memory aktualisieren.

Ein Fallback darf niemals: Budget-Grenzen brechen, Open-Source-Policy verletzen, unfreigegebene Premium-Kosten erzeugen, Sicherheitsregeln umgehen, Architektur oder Design beschädigen.

Jeder Providerwechsel ist sichtbar: Banner-Anzeige, Toast-Notification, History-Eintrag im Cost-Monitor, Limit-Dashboard-Update.

Fallback-Reihenfolge für LLM-Calls: Primär-Provider → Sekundär-Provider → Günstigstes verfügbares Modell das für den Task ausreichend ist. Niemals teures Modell als Fallback wenn günstiges ausreicht.

---

# ═══════════════════════════════════════════════════════════════════
# TEIL 7 — VOLLSTÄNDIGES PHASEN-MODELL MIT NEXT-PROMPTS
# ═══════════════════════════════════════════════════════════════════

Jede Phase enthält: Ziel, Was passiert, Abhängigkeiten, Verifikation, und den kopierbaren NEXT PROMPT FOR AGENT Block.

---

## PHASE 0 — GOAL LOCK UND VORBEREITUNG

**Ziel:** Alle Vorbereitungsdokumente erstellen bevor eine Zeile Code geschrieben wird.

**Was passiert:**

Aufgabe 0.1 — Monorepo-Struktur dokumentieren: Das Repository soll folgende Haupt-Verzeichnisse haben: /frontend (Next.js App), /backend (FastAPI Orchestrator), /agents (je ein Unterverzeichnis pro Agent-Typ: planner, coder, tester, devops), /mcp (alle MCP-Server), /infrastructure (Docker-Compose-Files, Deployment-Scripts, nginx-Config), /memory (Datenbankschemas, Migrations), /observability (Langfuse/Grafana-Konfigurationen), /docs (ADRs, Runbooks, API-Contracts, Codex-Integration). Nur dokumentieren, nicht implementieren.

Aufgabe 0.2 — Fünf ADR-Dokumente erstellen: ADR-001 LangGraph als Haupt-Orchestrator. ADR-002 LiteLLM als LLM-Gateway. ADR-003 Kein AutoGen vor Phase 6. ADR-004 Supabase für MVP-Datenbank mit geplanter Migration zu Hetzner PostgreSQL in Phase 4. ADR-005 Client-Side WebGPU mit WebGL-Fallback statt Server-Side GPU. Jedes ADR hat die Felder: Entscheidung, Kontext, Begründung, Abgelehnte Alternativen, Konsequenzen.

Aufgabe 0.3 — Secrets-Management-Plan: Alle API-Keys beim Namen nennen (Anthropic, OpenAI, Supabase, GitHub, HuggingFace, Together.ai, Groq, Cloudflare, E2B, Helicone, Langfuse). Jeden Secret einem einzigen Speicherort zuweisen: Vercel Environment Variables für Frontend-Secrets, Hetzner-Server Umgebungsvariablen für Backend-Secrets (.env.production, nie in Git, chmod 600). Rotation-Strategie: alle 90 Tage regulär, sofort bei Kompromittierung.

Aufgabe 0.4 — Kosten-Policy mit konkreten Zahlen: Hartes Infrastruktur-Limit: 20€/Monat. LLM-API-Budget Phase 1-3: max. 200€/Monat. Budget-Alert: bei 80% (16€ Infrastruktur, 160€ LLM). Max LLM-Calls pro Agent pro Session: 50. Max Output-Tokens Standard: 4096. Max Output-Tokens Code-Agenten: 8192. Modell-Zuweisungen und ihre maximalen Kosten pro 1M Tokens.

Aufgabe 0.5 — Codex-Integration-Dokumentation: Beschreiben wie das Projekt mit OpenAI Codex verwendet werden kann. CODEX_AGENT_SKILL_MASTER.md erstellen (kondensierte Skill-Datei). CODEX_LOADER_PROMPT.txt erstellen (Prompt zum Einlesen und Verankern). Speicherort: /docs/codex-integration/.

**Abhängigkeiten für Phase 1:** Alle 5 Aufgaben vollständig abgeschlossen und vom Owner bestätigt.

**Verifikations-Kriterien:** Jedes ADR hat alle 5 Pflichtfelder. Secrets-Plan nennt jeden Secret beim Namen mit genau einem Speicherort. Kosten-Policy hat konkrete Zahlen. Monorepo-Struktur bildet alle 7 Systemschichten ab.

---

**NEXT PROMPT FOR AGENT — PHASE 0**

```
[PROJECT]
Name: -CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM
North Star Goal: Cloud-native, multi-agent, prompt-gesteuert, skalierbar, ohne Localhost, 3D-fähig
Primary Outcome: Solo-Entwickler erstellt gesamte Software via natürliche Sprache
Current Phase: 0 — Goal Lock und Vorbereitung
Current Milestone: Vorbereitungs-Dokumente erstellen — KEIN Code

[MEMORY]
Already decided: LangGraph (Orchestrierung), LiteLLM (Gateway), Supabase MVP,
  kein AutoGen bis Phase 6, Client-Side WebGPU, Docker Compose bis Phase 6,
  Vercel Frontend, Hetzner Backend (20€/Monat Limit), Cloudflare Edge, Dark Mode Design
Must remain true: Kein Localhost, kein Fake-Done, 20€/Monat Infrastruktur-Limit,
  Open-Source-first, max 5 Retries, Human-in-Loop für kritische Aktionen
Must not change: 7-Schichten-Architektur, ADR-Pflicht, Goal Lock aus Teil 0
Open risks: R1 (Kosten-Explosion) noch nicht mitigiert, R8 (State-Recovery) zu testen
Open questions: Supabase Free-Tier-Kapazität für Projektziel, E2B-Pricing, 
  LangSmith vs Langfuse final (Langfuse bevorzugt)
Known constraints: Keine GPU-Server vor Phase 6, kein AutoGen vor Phase 6

[TASK]
Do now: Erstelle die Vorbereitungs-Dokumente für Phase 0:
  1. Monorepo-Struktur-Beschreibung als Prosa (alle 7 Systemschichten abgebildet)
  2. Fünf ADR-Dokumente (LangGraph, LiteLLM, kein AutoGen, Supabase MVP, WebGPU Client-Side)
  3. Secrets-Management-Plan (alle API-Keys, je ein Speicherort, Rotation-Strategie)
  4. Kosten-Policy (konkrete Zahlen: 20€ Infra, 200€ LLM max, per-Agent-Limits)
  5. Codex-Integration-Dokumentation (CODEX_AGENT_SKILL_MASTER.md + Loader-Prompt)
Explicitly out of scope: Jeglicher Code, jegliche Infrastruktur, jegliches Deployment
Affected modules: /docs/adr/, /docs/secrets-strategy.md, /docs/cost-policy.md, /docs/codex-integration/
Expected output: 7 Dokumente, vollständig, alle Pflichtfelder ausgefüllt

[VERIFICATION]
Required checks: Jedes ADR hat 5 Pflichtfelder. Monorepo-Struktur bildet alle 7 Schichten ab.
  Secrets-Plan: Jeder Secret hat genau einen Speicherort. Kosten-Policy: Nur konkrete Zahlen.
Required evidence: Owner liest alle 7 Dokumente und bestätigt schriftlich
Definition of done: Alle 7 Dokumente vorhanden + vollständig + Owner-Bestätigung
Release relevance: Phase 1 startet NICHT bevor alle 7 Dokumente bestätigt sind

[DELIVERY MODE]
Plan
```

---

## PHASE 1 — FOUNDATION (Woche 1-2)

**Ziel:** Stabiles Gerüst. Kein Agent-System, keine LLMs, kein Frontend. Nur das Fundament.

**Was passiert:**

Aufgabe 1.1 — Hetzner-Server-Setup: CPX51 in Frankfurt (Region EU-Central), Ubuntu 24.04 LTS, SSH-Key-only (Passwort-Auth deaktivieren), Firewall (nur Port 22/80/443 extern, alle anderen intern), Docker und Docker Compose installieren, Coolify optional als Management-Interface, automatische Sicherheits-Updates aktivieren, Swap-Space konfigurieren (8GB empfohlen für Langfuse).

Aufgabe 1.2 — Docker-Compose-Design für 8 Services: nginx (Reverse Proxy, Port 80/443), agent-api (FastAPI, intern Port 8000), redis (Cache, intern Port 6379), postgres (pgvector, intern Port 5432), qdrant (Vector-DB, intern Port 6333), langfuse-server (Observability, intern Port 3000), langfuse-worker (Background-Jobs, kein externer Port), mcp-gateway (Tool-Router, intern Port 9000). Alle mit spezifischen Versions-Tags. Alle mit Resource-Limits. Alle mit Health-Checks. Alle mit expliziten Abhängigkeits-Ketten.

Aufgabe 1.3 — CI/CD-Skeleton (3 GitHub Actions Workflows): Workflow 1 (PR-Check): Linting, Type-Checking, Unit-Tests. Trigger: Pull Request. Timeout: 10 Minuten. Workflow 2 (Main-Deploy): Alle Tests + Deploy zu Staging (automatisch) + Deploy zu Production (manuell genehmigt). Trigger: Merge in Main. Rollback: automatisch wenn Health-Check nach 5 Minuten fehlschlägt. Workflow 3 (Hotfix): Schnelle Deploy-Pfad für kritische Fixes mit obligatorischem Approval.

Aufgabe 1.4 — Datenbankschema für 5 Tabellen: projects (ID, Name, Beschreibung, Erstellungsdatum, Owner-ID, Status), agent_sessions (Session-ID, Projekt-ID, Start/End-Timestamp, Status, Agent-Liste, Token-Verbrauch, Kosten-Cent), agent_messages (Message-ID, Session-ID, Agent-Typ, Timestamp, Rolle, Content-Referenz zu Object-Storage, kein langer Text direkt in SQL), memory_entries (Entry-ID, Projekt-ID, Content-Embedding als pgvector, Content-Text, Metadaten JSON, Relevanz-Score, Erstellungsdatum, Status: active/archived/deprecated), cost_tracking (Record-ID, Session-ID, Agent-Typ, Modell-Name, Input-Tokens, Output-Tokens, Kosten-Cent, Timestamp, Provider-Name).

Aufgabe 1.5 — Observability-Strategy: Welche Metriken je Schicht (mindestens Request-Count, Latenz, Fehlerrate, Memory-Verbrauch). Wie LLM-Traces durch Langfuse erfasst werden. Wie Trace-ID durch alle Schichten propagiert wird (als Header x-trace-id). Wo Dashboards gehostet werden (Grafana auf Hetzner, nicht öffentlich zugänglich ohne VPN/Auth). Alerting-Regeln: Server-Down, Fehlerrate >5%, Budget-Alert 80%, Memory-Auslastung >85%. Log-Aufbewahrung: 30 Tage Debug-Logs, 90 Tage Audit-Logs.

Aufgabe 1.6 — Staging-Umgebung planen: Identische Konfiguration wie Production aber auf kleinerem Server (CX22, €4/Monat). Staging läuft immer. Alle Tests und jedes Deployment treffen Staging zuerst. Staging-URL ist nicht öffentlich zugänglich.

**Abhängigkeiten:** Phase 0 vollständig bestätigt.

**Verifikation:** Jeder Service hat alle Pflichtfelder. Kein Workflow deployt ohne alle Tests bestanden. Rollback-Pfad ist explizit vorhanden und auf Staging getestet.

---

**NEXT PROMPT FOR AGENT — PHASE 1**

```
[PROJECT]
Name: -CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM
North Star Goal: Cloud-native, multi-agent, prompt-gesteuert, skalierbar, ohne Localhost
Current Phase: 1 — Foundation
Current Milestone: Infrastruktur-Design und Schema-Dokumentation (noch kein Code)

[MEMORY]
Already decided: Alle Phase-0-Dokumente bestätigt.
  Stack: LangGraph, LiteLLM, Supabase MVP, Docker Compose, Vercel, Hetzner CPX51 (20€/Monat),
  Cloudflare Edge, Langfuse self-hosted, shadcn/ui, 7 Systemschichten
Must remain true: Keine "latest" Docker-Tags in Production. Staging-Pflicht ab Phase 1.
  Rollback muss auf Staging getestet werden bevor Production.
  Budget: 20€/Monat Infrastruktur-Limit (CPX51 + CX22 Staging + Cloudflare free).
Open risks: R1 noch nicht mitigiert (Rate-Limiting und Budget-Alerts sind Phase-2-Implementierung)

[TASK]
Do now: Erstelle das Docker-Compose-Design-Dokument für alle 8 Services.
  Beschreibe jeden Service: Name, Zweck, Docker-Image mit spezifischer Version (keine latest),
  interne und externe Ports, benötigte Volumes, Umgebungsvariablen als Platzhalter,
  Abhängigkeiten, Health-Check-Strategie, Resource-Limits.
  Services: nginx, agent-api (FastAPI), redis, postgres (pgvector), qdrant,
  langfuse-server, langfuse-worker, mcp-gateway.
  Parallel: Beschreibe das Datenbankschema für 5 Tabellen als Prosa (kein SQL).
Explicitly out of scope: Jegliche Implementierung, jeglicher Code, jegliche Infrastruktur-Änderung
Affected modules: /infrastructure/docker-compose.yml (Design), /memory/schema.md
Expected output: Docker-Compose-Design-Dokument + Schema-Beschreibung

[VERIFICATION]
Required checks: Jeder Service hat Resource-Limit. Kein Service exponiert DB-Port nach außen.
  Schema beantwortet: Was kostet Projekt X? Welche Agenten in Session Y? Memory-Entries für Projekt Z?
Definition of done: Alle 8 Services vollständig beschrieben + Schema-Verifikationsfragen beantwortet

[DELIVERY MODE]
Plan
```

---

## PHASE 2 — CORE RUNTIME (Woche 3-5)

**Ziel:** Das eigentliche Herzstück. Am Ende muss ein Mensch einen Prompt eingeben und 4 kooperierende Agenten sehen.

**Was passiert:**

LLM-Gateway konfigurieren mit vollständigem Modell-Routing. Planner-Agent bekommt Claude Sonnet 4.6 oder GPT-4o. Coder-Agent bekommt DeepSeek oder Claude Haiku 4.5. Tester-Agent bekommt GPT-4o-Mini oder Groq Llama. Research-Agent bekommt Gemini Flash oder Mistral. Fallback-Reihenfolge für jeden Slot. Rate-Limiting per Modell. Cost-Tracking an Datenbank weitergeben. Caching-TTL: 10 Minuten für identische Prompts.

LangGraph-Orchestrator-Graph mit sechs Nodes: Intent-Parser (Prompt analysieren, strukturierten Task-Plan erstellen), Task-Router (Tasks den richtigen Agenten zuweisen), Agent-Executor (Ausführung steuern, State verwalten), Result-Aggregator (Ergebnisse mehrerer Agenten zusammenführen), Memory-Updater (nach jeder Aktion Memory aktualisieren), Error-Handler (Recovery-Pfade, Retry-Logik, Eskalation). Maximale Retry-Cycles: 5. Kein Loop ohne Zähler. LangGraph-Checkpointer: ausschließlich mit PostgreSQL (NIEMALS In-Memory in Production).

Vier Kern-Agenten-Profile implementieren (aus Teil 4.2). Memory-Konsolidierungs-Job als Background-Worker. MCP-Server-Architektur für 4 Tool-Sets (GitHub, E2B, Playwright, Filesystem).

Budget-Alerts und Rate-Limiting als allererstes implementieren, bevor irgendein LLM-Call in Production gemacht wird.

**Verifikation:** Kein endloser Loop ohne Abbruchbedingung. Checkpoints überleben Server-Neustart nachgewiesen. Budget-Alert wird ausgelöst bei 80%.

---

**NEXT PROMPT FOR AGENT — PHASE 2**

```
[PROJECT]
Name: -CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM
Current Phase: 2 — Core Runtime
Current Milestone: LangGraph Orchestrator + 4 Kern-Agenten + Memory + LLM-Gateway

[MEMORY]
Already decided: Phase 0+1 bestätigt. Docker-Compose-Design finalisiert.
  Budget-Alert und Rate-Limiting sind ERSTES was implementiert wird in Phase 2.
  LangGraph-Checkpointer: PostgreSQL-only, nie In-Memory.
  Max 5 Retry-Cycles per Task, dann Eskalation.
Open risks: R8 (State-Recovery) muss in dieser Phase getestet werden.
  Test: Server-Neustart während aktiver Session → State-Recovery verifizieren.

[TASK]
Do now: Beschreibe den vollständigen LangGraph-Orchestrator-Graphen.
  Für jeden Node: Name, Eingabe, Ausgabe, Entscheidungslogik, mögliche Ausgangspfade,
  maximaler Retry-Zähler, Eskalations-Bedingung.
  Erstelle die vier vollständigen Agenten-Profile (Planner, Coder, Tester, DevOps)
  nach dem Format aus Teil 4.2 des Masterplans.
  Beschreibe den Memory-Konsolidierungs-Job als Prozess-Dokumentation.
  WICHTIG: Rate-Limiting und Budget-Alert-Implementierung ist der erste Schritt,
  bevor irgendein LLM-Call in Production getestet wird.
Explicitly out of scope: UI/Frontend, Auth, GDPR (Phase 3)
Expected output: LangGraph-Architektur-Dokument + 4 Agenten-Profile + Memory-Job-Spec

[VERIFICATION]
Required checks: Graph hat keine Loops ohne Zähler. Jeder Node hat Fehler-Pfad.
  Checkpointer ist PostgreSQL-basiert. Budget-Alert-Implementierung vor erstem Production-LLM-Call.
Definition of done: Architektur-Dokument vollständig + State-Recovery-Test bestanden

[DELIVERY MODE]
Plan → Build
```

---

## PHASE 3 — PRODUCT SURFACE + SECURITY (Woche 6-8)

**Ziel:** Alle Schichten verdrahtet. Auth, DSGVO, Rate-Limiting, vollständiges Frontend.

**Was passiert:** Next.js-Frontend mit 4 Screens (Workspace, Memory-Viewer, Agent-Activity, Cost-Monitor) implementieren. Designsystem aus Teil 5 anwenden. SSE-Streaming implementieren. JWT-Auth mit GitHub OAuth. Memory-Purge-API (DSGVO). Secret-Scanner für alle Logs. Rate-Limiting (Cloudflare erste Linie, Upstash zweite). API-Contract vollständig implementieren. Per-Agent-Cost-Tracking in Dashboard sichtbar.

---

**NEXT PROMPT FOR AGENT — PHASE 3**

```
[PROJECT]
Current Phase: 3 — Product Surface + Security
Current Milestone: Frontend + Auth + DSGVO + Rate-Limiting

[TASK]
Do now: Beschreibe die vollständige Next.js-App-Architektur (4 Screens aus Teil 5 des Masterplans).
  Für jeden Screen: Datenquelle, Update-Frequenz (SSE oder Polling), Ladezustand,
  Fehlerzustand, leerer Zustand, alle Pflicht-Komponenten.
  Beschreibe das Auth-System: JWT, GitHub OAuth, Token-Storage (HttpOnly-Cookie),
  Access-Token-TTL (15 Min), Refresh-Token-TTL (7 Tage).
  Beschreibe die Memory-Purge-API (DSGVO): Scope, Bestätigungs-Flow, Audit-Log.
  Beschreibe alle API-Endpoints aus Teil 2 des Masterplans.
Explicitly out of scope: K3s, GPU-Server, AutoGen, MetaGPT (alle Phase 6)

[DELIVERY MODE]
Plan → Build
```

---

## PHASE 4 — INTEGRATION UND HARDENING (Woche 9-10)

**Ziel:** System ist stabil, sicher, observierbar und für echte Nutzung bereit.

**Was passiert:** 10 Integrations-Test-Szenarien durchführen (Happy Path, Retry-Limit, LLM-Fallback, Ressourcenlimit, Concurrent Sessions, State-Recovery, Empty Memory, Budget-Alert, Auth-Fehler, Unauthorized Access). Security-Audit-Checkliste abarbeiten. Performance-Baseline verifizieren (erste Streaming-Token <3 Sekunden, einfacher Code-Task <60 Sekunden, semantische Suche <500ms). Supabase-Migration zu Hetzner-eigenem PostgreSQL wenn Datenvolumen es erfordert. Alle E2B-Sessions verifizieren dass sie im finally-Block geschlossen werden.

---

**NEXT PROMPT FOR AGENT — PHASE 4**

```
[PROJECT]
Current Phase: 4 — Integration und Hardening
Current Milestone: 10 Integrations-Test-Szenarien + Security-Audit + Performance-Baseline

[TASK]
Do now: Schreibe die 10 vollständigen Integrations-Test-Szenarien (aus Teil 8 des Masterplans).
  Für jedes Szenario: Titel, Ausgangszustand, Eingabe, Erwarteter Ablauf (Schritt für Schritt),
  Erwartetes Ergebnis, Was als Fehler gilt, Wie das System im Fehlerfall reagiert.
  Erstelle die Security-Audit-Checkliste (5 Kategorien aus Teil 8).
  Definiere messbare Performance-Ziele mit konkreten Zahlen.
Explicitly out of scope: Neue Features, Skalierung

[DELIVERY MODE]
Review → Verify
```

---

## PHASE 5 — RELEASE-READINESS (Woche 11-12)

**Ziel:** Erster echter Production-Release.

**Was passiert:** Vollständige Release-Checkliste abarbeiten (4 Sektionen: Code-Readiness, Infrastruktur-Readiness, Observability-Readiness, Operations-Readiness). Rollback-Strategie testen (Ziel: unter 5 Minuten pro Service auf Staging). Nur Forward-Migrations in Production. Release-Checkliste als Artifact in Git speichern.

---

**NEXT PROMPT FOR AGENT — PHASE 5**

```
[PROJECT]
Current Phase: 5 — Release-Readiness
Current Milestone: Release-Checkliste + Rollback-Test + Production-Deployment

[TASK]
Do now: Erstelle die vollständige Release-Checkliste mit 4 Sektionen.
  Erstelle den Rollback-Plan für jeden Service (Ziel: <5 Minuten).
  Beschreibe wie der Rollback auf Staging getestet wird bevor Production.
  Beschreibe wie die Release-Checkliste als Git-Artifact gespeichert wird.
Explicitly out of scope: Neue Features, K3s, GPU, AutoGen, Skalierung

[VERIFICATION]
Required checks: Rollback-Plan wurde auf Staging getestet (nicht nur theoretisch).
  Release-Checkliste hat nur Ja/Nein-Items (keine vagen Aussagen).
Definition of done: Checkliste vollständig + Rollback auf Staging verifiziert + 
  Production-Deployment erfolgreich + Checkliste als Git-Artifact

[DELIVERY MODE]
Verify → Release
```

---

## PHASE 6 — SCALE EXPANSION (Ab Woche 13)

**Bedingung für Start:** Phase 5 vollständig abgeschlossen und verifiziert. Frühzeitige Skalierung ohne stabiles Fundament ist Ressourcenverschwendung.

**Was passiert:** Squad 2 aktivieren (Research, Security, Documentation, Database-Agent). 3D-Webgame-Pipeline vollständig implementieren. K3s-Migration wenn >3 aktive Nutzer oder >12 parallele Agenten. GPU-Server (Hetzner GEX44) wenn 3D-Server-Rendering nachgewiesenermaßen nötig. Platform-Twin/Clone-Konzept wenn selbst-verbessernde Fähigkeiten gewünscht. AutoGen wenn konkreter Debattier-Use-Case nachgewiesen. MetaGPT wenn vollständige Team-Simulation gewünscht.

**3D-Webgame-Pipeline:** User-Prompt "Baue mir ein 3D-Browser-Spiel" → Planner-Agent erstellt Game-Konzept → Coder-Agent implementiert Three.js/Babylon.js-Struktur → Asset-Management via Cloudflare R2 → E2B-Sandbox-Build → Tester-Agent macht Screenshot via Playwright-MCP → Screenshot an User → User bestätigt → DevOps-Agent deployt auf Vercel oder GitHub Pages. Feature-Detection vor Rendering (WebGPU vorhanden? Wenn nein: WebGL-Fallback automatisch).

**Platform-Twin-Regeln:** Niemals unkontrollierte Selbstveränderung. Alle Changes über definierte Schnittstellen. Alle Meta-Aktionen auditierbar. Keine autonome Policy-Umschreibung durch Klone. Kein Selbstumbau ohne Owner-Freigabe.

---

# ═══════════════════════════════════════════════════════════════════
# TEIL 8 — RISIKO-REGISTER (FINAL KONSOLIDIERT)
# ═══════════════════════════════════════════════════════════════════

**R1 — Kostenexplosion durch unkontrollierte API-Loops**  
Schweregrad: KRITISCH. Wahrscheinlichkeit: HOCH.  
Mitigation: Budget-Alerts und Rate-Limiting sind der ALLERERSTE Implementierungsschritt in Phase 2, vor jedem anderen Feature. Helicone ab erstem API-Call aktiv.

**R2 — Architecture Drift durch schnelle Iteration**  
Schweregrad: HOCH. Wahrscheinlichkeit: SEHR HOCH.  
Mitigation: ADR-Register von Tag 1. Nach jeder Phase ADR-Konsistenz-Check.

**R3 — Memory-Konsistenz-Verlust**  
Schweregrad: HOCH. Wahrscheinlichkeit: MITTEL.  
Mitigation: Redis → pgvector Konsolidierung alle 30 Minuten. TTL gesetzt. Monitor-Alert wenn Konsolidierungs-Job fehlschlägt.

**R4 — MCP-Server-Ausfall lähmt alle Agenten**  
Schweregrad: HOCH. Wahrscheinlichkeit: MITTEL.  
Mitigation: Kritische MCP-Server in 2 Instanzen. Graceful Degradation. System zeigt degradierten Modus explizit an.

**R5 — 3D-Rendering-Latenz-Erwartung**  
Schweregrad: MITTEL. Wahrscheinlichkeit: HOCH.  
Mitigation: Client-Side WebGPU Phase 1-5. Progress-Indicator und asynchrone Benachrichtigung implementieren. GPU-Server erst Phase 6.

**R6 — Secrets-Leak durch Agent-generierten Code**  
Schweregrad: KRITISCH. Wahrscheinlichkeit: MITTEL.  
Mitigation: Secret-Scanner für alle Logs. Agents haben keinen .env-Lesezugriff. Nur Vault-Injection oder Vercel/Hetzner-Umgebungsvariablen.

**R7 — Agent schreibt in Main-Branch oder Production-DB**  
Schweregrad: KRITISCH. Wahrscheinlichkeit: NIEDRIG aber katastrophal.  
Mitigation: GitHub-Branch-Schutz für Main. Agents ausschließlich in feature/agent-* Branches. Nur Menschen können mergen.

**R8 — LangGraph State-Recovery nach Server-Neustart**  
Schweregrad: HOCH. Wahrscheinlichkeit: MITTEL.  
Mitigation: LangGraph-Checkpointer ausschließlich PostgreSQL. State-Recovery-Test in Phase 2 Pflicht. Niemals MemorySaver in Production.

**R9 — Supabase Free-Tier-Pause**  
Schweregrad: HOCH. Wahrscheinlichkeit: HOCH wenn unbeachtet.  
Mitigation: Automatischer Keep-Alive-Ping alle 6 Tage. Bei >400MB: Upgrade oder Migration. Migration zu Hetzner PostgreSQL in Phase 4 geplant.

**R10 — WebGPU-Browser-Kompatibilität falsch eingeschätzt**  
Schweregrad: MITTEL. Wahrscheinlichkeit: HOCH.  
Mitigation: Immer Feature-Detection vor Rendering. WebGL-Fallback immer implementiert. User-Info wenn Fallback aktiv.

---

# ═══════════════════════════════════════════════════════════════════
# TEIL 9 — DIE 20 TÖDLICHSTEN FALLEN (FINAL KONSOLIDIERT)
# ═══════════════════════════════════════════════════════════════════

Alle 20 wurden aus 10 Quelldokumenten und realen Projekt-Erfahrungen destilliert.

**Falle 1 — Zu schnell zu viel bauen:** Phase 1-2 komplett vor Phase 3. MVP sind vier Agenten, nicht zwanzig.

**Falle 2 — LLM-Kosten ignorieren:** Helicone ab erstem API-Call. Budget-Alert bei 80%. Rate-Limiting vor erstem LLM-Call in Production.

**Falle 3 — Memory ohne Konsolidierungs-Strategie:** Redis TTL gesetzt. 30-Min-Konsolidierungs-Job.

**Falle 4 — Agenten-Loop ohne Abbruchbedingung:** Max 5 Retry-Cycles. Dann Eskalation mit vollständigem Fehlerbericht.

**Falle 5 — Secrets in Docker-Compose-Files:** Nur ${PLACEHOLDER}. Niemals echte Werte im Code oder in Git.

**Falle 6 — Production statt Staging testen:** Staging ist Pflicht ab Phase 1. Tests treffen Staging zuerst.

**Falle 7 — "latest"-Tags in Production:** Immer spezifische Versions-Tags. Ohne Ausnahme.

**Falle 8 — Agent hat zu viel GitHub-Macht:** Nur feature/agent-* Branches. Main ist geschützt.

**Falle 9 — MCP als Single Point of Failure:** Kritische MCP-Server 2× deployed. Graceful Degradation.

**Falle 10 — Kein Observability beim ersten Start:** Langfuse + Prometheus ab Phase 1 Pflicht.

**Falle 11 — Architecture Drift:** ADR-Register. Jede strukturelle Änderung = neuer ADR.

**Falle 12 — LangGraph mit MemorySaver statt PostgreSQL:** PostgreSQL-Checkpointer ist Pflicht in Production. MemorySaver nur für lokale Entwicklung.

**Falle 13 — Supabase Free-Tier-Pause nach 7 Tagen Inaktivität:** Keep-Alive-Ping alle 6 Tage. Oder Pro-Plan. Oder Migration.

**Falle 14 — WebGPU-Support falsch einschätzen:** Immer WebGL-Fallback. Immer Feature-Detection.

**Falle 15 — AutoGen aus Neugier einbauen:** Explizit ausgeschlossen bis Phase 6. 5-6× teurer ohne konkreten Nutzen.

**Falle 16 — Kein Rate-Limiting auf öffentlichen Endpoints:** Cloudflare + Upstash als zwei Schichten.

**Falle 17 — Memory-Purge vergessen:** DSGVO-Pflicht. Alle Nutzerdaten via einer API-Operation löschbar. Phase 3.

**Falle 18 — E2B-Sessions nicht schließen:** 30-Min-Timeout automatisch. Immer finally-Block. Sonst Kosten-Explosion.

**Falle 19 — Zu viele Services ohne Ressourcen-Limits:** Docker Container-Limits setzen. Ein Memory-Leak tötet alle anderen Services.

**Falle 20 — Deployment ohne Rollback-Test:** Rollback-Plan muss auf Staging getestet worden sein. Theoretische Pläne zählen nicht.

---

# ═══════════════════════════════════════════════════════════════════
# TEIL 10 — PFLICHT-ARTEFAKTE (VOLLSTÄNDIGE LISTE)
# ═══════════════════════════════════════════════════════════════════

Die folgenden Artefakte müssen für dieses Projekt existieren und gepflegt werden. Fehlende Artefakte sind ein Blocker für den jeweiligen Release.

Dokumentation: Master Project Brief (dieses Dokument), Project Goal Lock (Teil 0), Phase Roadmap (dieses Dokument), Architecture Map (Systemschichten + Datenfluss), 7-Schichten-Ownership-Map, Interface Contract Register (API-Endpoints), ADR Log (min. 5 ADRs aus Phase 0).

Governance: Risk Register (Teil 8), Verification Register (pro Phase), Release Checklist (pro Release als Git-Artifact), Assumption Log, Open Questions Log, Technical Debt Log.

Design: Design Spec Sheet Register (ein Sheet pro Screen), Screen Inventory (4 Screens definiert), UI State Matrix (alle Zustände pro Screen).

Betrieb: Provider Rotation Register (History aller Fallbacks), Limit History Register (Budget-Verbrauch pro Monat), Runbooks (Restart-Prozedur, Rollback-Prozedur, Memory-Purge-Prozedur).

Codex-Integration: CODEX_AGENT_SKILL_MASTER.md, CODEX_LOADER_PROMPT.txt.

---

# ═══════════════════════════════════════════════════════════════════
# TEIL 11 — PROJEKT-MEMORY-UPDATE
# ═══════════════════════════════════════════════════════════════════

**Aktive Phase:** 0 — Goal Lock und Vorbereitung  
**Aktiver Meilenstein:** Alle Vorbereitungs-Dokumente erstellen bevor erste Code-Zeile  
**North Star:** Vollständig aktiv und in diesem Dokument verankert  
**Budget-Status:** 0€/20€ Infrastruktur ausgegeben — sauber  
**Open-Source-Compliance:** Vollständig konform  

**Neu entschieden (dieser Synthese):**  
14 Widersprüche zwischen 10 Dokumenten aufgelöst. Budget-Limit finalisiert: 20€/Monat Infrastruktur. Langfuse self-hosted als Standard-Observability. NEXT PROMPT FOR AGENT als Pflicht-Output nach jeder Phase. Designsystem verbindlich festgelegt. Twin/Clone als Phase-6-Meilenstein. Codex-Integration als Phase-0-Aufgabe hinzugefügt.

**Offene Risiken:**  
R1 (Kostenexplosion) noch nicht mitigiert — kritisch, wird Phase-2-Schritt-1.  
R9 (Supabase Free-Tier-Pause) — Keep-Alive-Ping ab Phase-1-Deployment einrichten.  

**Unverifiziert (Annahmen, nicht Wahrheiten):**  
Supabase Free-Tier-Kapazität für das erwartete Datenvolumen. E2B-Pricing für erwartetes Test-Volumen. LiteLLM-Performance unter Last. Groq-Latenz unter Production-Bedingungen.  

**Nächster erforderlicher Schritt:**  
NEXT PROMPT FOR AGENT aus Phase 0 kopieren → an Coder-Agenten oder Codex senden → Phase-0-Dokumente erstellen lassen → Owner liest und bestätigt → dann und nur dann Phase 1 beginnen.

---

# ═══════════════════════════════════════════════════════════════════
# ABSCHLUSS-DEKLARATION
# ═══════════════════════════════════════════════════════════════════

Dieses Dokument ist die einzige Wahrheit des Projekts.  
Es ersetzt alle vorherigen Versionen.  
Es hat alle 10 Quelldokumente vollständig gelesen und alle 14 Widersprüche aufgelöst.

Wenn du in Zweifel gerätst was zu tun ist — lies Teil 0.  
Wenn du denkst ein Schritt sei nicht nötig — lies Teil 9.  
Wenn ein Agent etwas tut das nicht im Plan steht — lies Teil 4.  
Wenn du glaubst fertig zu sein — lies die Release-Checkliste aus Phase 5.  
Wenn die Kosten steigen — lies R1 und die Kosten-Policy aus Phase 0, Aufgabe 0.4.

Kein Release ohne Release-Checkliste in Git.  
Kein Architecture-Wechsel ohne ADR.  
Kein API-Call ohne Kosten-Monitoring.  
Kein Schritt ohne Verifikation.  
Kein Fake-Done.  
Kein Localhost.  
20€/Monat Infrastruktur-Limit.  
Open-Source-first.  
Immer.

---

*Synthese aus 10 Quelldokumenten. 14 Widersprüche gelöst. Stand: April 2026.*  
*Erstellt unter: Supreme Open-Source Planning, Memory, Design, Verification, Delivery & Release Architect Godmode.*  
*Dieses Dokument ersetzt: CLOUD_SUPERBRAIN_ULTIMATIVER_MASTERPLAN.md, CLOUD_SUPERBRAIN_ULTIMATIVER_MASTERPLAN__LÄNGER.md, CLOUD_SUPERBRAIN_MASTER_BRIEFING.md und alle vorherigen Versionen.*

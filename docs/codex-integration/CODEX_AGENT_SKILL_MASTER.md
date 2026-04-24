---
name: codex-superbrain-agent-squad
description: "Ultimativer Autonomer Multi-Agent Squad für -CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM. Startet bei JEDEM Chat-Beginn sofort den Squad, weist Rollen zu, arbeitet mit Supervisor-Überwachung und baut echten Code — keine Meta-Dokumente, keine Sandbox-Loops, kein Fake-Done."
---

# ╔══════════════════════════════════════════════════════════════════╗
# ║  CODEX SUPERBRAIN — ULTIMATE AUTONOMOUS AGENT SQUAD SKILL       ║
# ║  Projekt: -CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM                  ║
# ║  Modus: VOLLAUTONOMER SQUAD-START · SUPERVISOR-ÜBERWACHT        ║
# ║  Kein Localhost. Kein lokales Modell. 20€/Monat Infra-Limit.    ║
# ╚══════════════════════════════════════════════════════════════════╝

---

## 0. CHAT-START-PROTOKOLL — WIRD IMMER ZUERST AUSGEFÜHRT

**Bei JEDEM neuen Chat oder Aufgabe führe SOFORT diese 4 Schritte aus, bevor du irgendetwas anderes tust:**

### SCHRITT 0.1 — REPO-ZUSTAND LESEN (max. 60 Sekunden)
```bash
# Lese diese Dateien in genau dieser Reihenfolge:
cat AGENTS.md                                          # Projekt-Verfassung
cat docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE.md | head -200  # Goal Lock + Regeln
cat docs/phase-2-readiness-matrix.md                  # Aktueller Phasen-Status
cat docs/verification-register.md | tail -50           # Was ist fertig, was nicht
```
**Wenn eine Datei fehlt: NICHT STOPPEN. Notiere Lücke, fahre fort.**

### SCHRITT 0.2 — AUFGABE KLASSIFIZIEREN (30 Sekunden)
Ordne die aktuelle Aufgabe einer dieser Kategorien zu:
- `CODE`: Echter Implementierungs-Task (Priorität: HOCH)
- `INFRA`: Docker/CI/CD/Hetzner-Setup (Priorität: HOCH)
- `DOC`: Dokumentation die Runtime-Arbeit freigibt (Priorität: MITTEL)
- `FIX`: Bug-Fix, Fehler-Behebung (Priorität: HOCH)
- `AUDIT`: Vollständige Projekt-Prüfung (Priorität: MITTEL)

**VERBOTEN:** Reine Meta-Dokumentation ohne Runtime-Fortschritt. Kein Dokument über Dokumente.

### SCHRITT 0.3 — SQUAD INSTANZIIEREN

Erstelle sofort den minimalen Squad für die aktuelle Aufgabe:

```
SQUAD-MANIFEST:
═══════════════════════════════════════════════
SUPERVISOR: [Codex selbst — überwacht ALLE Agenten live]
PLANNER:    [Analyse, Planung, ADR-Entscheidungen]
CODER:      [Implementation, Git, Docker]
TESTER:     [Verifikation, Health-Checks, Logs]
DEVOPS:     [CI/CD, Hetzner, Deployment]  ← nur wenn infra-relevant
SECURITY:   [Secret-Scan, Permission-Check] ← nur wenn sicherheitsrelevant
═══════════════════════════════════════════════
Aktiver Squad für diese Aufgabe: [liste nur die nötigen]
```

### SCHRITT 0.4 — SUPERVISOR AKTIVIEREN

Der Supervisor (Codex selbst) überwacht jeden Agenten-Schritt live nach diesem Schema:

```
[SUPERVISOR-CHECK nach jedem Agenten-Output]
✅ Output ist architektur-konform?
✅ Kein Secret im Output?
✅ Kein direkter Main-Branch-Zugriff?
✅ Kein Endless-Loop-Risiko?
✅ Fortschritt messbar?
→ Falls NEIN bei einem Punkt: SOFORTIGER STOPP + Korrektur vor nächstem Schritt
```

---

## 1. ABSOLUT VERBOTENE MUSTER (LOOP-KILLER)

Diese Muster haben das Projekt 2 Tage blockiert. Sie sind hiermit für immer verboten:

### 1.1 — VERBOTENE AKTIONEN
```
❌ E2B Sandbox für einfache Code-Tests → DOCKER DESKTOP STATTDESSEN
❌ "Lass mich das Dokument lesen um ein anderes Dokument zu schreiben"
❌ Gate-A-Minipaket schreiben → Gate-A-Review schreiben → Gate-A-Reconciliation schreiben
❌ "NEXT PROMPT FOR AGENT" als Endlosschleife benutzen
❌ Mehr als 3 Versuche für denselben Fehler ohne neue Hypothese
❌ Token-Budget durch Meta-Wiederholung aufbrauchen
❌ "Phase X ist bereit" ohne lauffähige Runtime-Evidenz
❌ Sandbox starten wenn Docker Desktop verfügbar ist
```

### 1.2 — LOOP-ERKENNUNG (SUPERVISOR prüft nach jedem Schritt)
```python
# Pseudo-Code den der Supervisor mental ausführt:
if current_output.contains("Gate") and last_3_outputs.all_contain("Gate"):
    STOP("Meta-Schleife erkannt — sofort zu echter Implementierung wechseln")

if same_error_occurred(times=3):
    ESCALATE("Neuer Ansatz notwendig — beschreibe Problem präzise")

if no_file_was_changed(last_5_steps=True):
    STOP("Keine echte Änderung — was genau wurde gebaut?")
```

---

## 2. AUSFÜHRUNGSUMGEBUNG — DOCKER DESKTOP (KEIN E2B SANDBOX)

### 2.1 — LOKALE AUSFÜHRUNG
Du hast Docker Desktop auf Windows. Nutze es:

```bash
# Code testen:
docker run --rm -v $(pwd):/app python:3.11-slim python /app/script.py

# FastAPI testen:
docker compose -f docker-compose.dev.yml up -d agent-api
curl http://localhost:8000/api/v1/health

# PostgreSQL testen:
docker compose exec postgres psql -U superbrain -d superbrain_prod -c "SELECT 1"

# Redis testen:
docker compose exec redis redis-cli ping

# Logs prüfen:
docker compose logs --tail=50 agent-api
```

### 2.2 — DOCKER COMPOSE FÜR DEV (Datei: docker-compose.dev.yml)
Jede Komponente muss in dev lokal testbar sein. Nutze Named Volumes, nie Bind-Mounts für DBs.

### 2.3 — KEIN LOCALHOST ALS PRODUCTION-ZIEL
Docker Desktop = nur für lokale Tests und Entwicklung.
Production = Hetzner Cloud. Kein Localhost in Deployments.

---

## 3. PROJEKT-IDENTITÄT UND CONSTRAINTS (UNVERÄNDERLICH)

```
PROJEKT:     -CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM
REPO:        https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM.git
NORTH STAR:  Cloud-native, prompt-gesteuerte, multi-agentische Entwicklerplattform
INFRA-LIMIT: 20 EUR/Monat (HART — keine Ausnahmen)
LLM-BUDGET:  200 EUR/Monat (Phase 1-5)
MODELL-RULE: NUR API-Inferenz — niemals lokale Modelle downloaden
DEPLOYMENT:  Vercel (Frontend) + Hetzner (Backend) + Cloudflare (Edge/Cache)
BRANCH:      feature/agent-* für alle Agenten-Commits. NIEMALS direkt in main.
SECRETS:     Niemals in Code, Logs, Commits oder generierten Dateien
DONE-REGEL:  Implementiert + Getestet + Integriert + Geloggt = DONE. Sonst: IN PROGRESS.
```

### 3.1 — TECH-STACK (OSS-ONLY, API-ONLY)
```
Orchestrierung:  LangGraph (OSS)
LLM-Gateway:     LiteLLM (OSS) → Cloudflare AI Gateway (Cache)
Agenten:         LangGraph-Nodes mit CrewAI-Rollen
Frontend:        Next.js + shadcn/ui (OSS), Vercel Deploy
Datenbank:       PostgreSQL + pgvector auf Hetzner (OSS)
MVP-Embeddings:  Supabase Free Tier (Phase 1-3), dann Hetzner pgvector
Observability:   Langfuse self-hosted + Prometheus + Grafana (alle OSS)
Tools/MCP:       GitHub-MCP, Playwright-MCP, Filesystem-MCP (alle OSS)
Secrets:         Hetzner-Umgebungsvariablen + GitHub Secrets
CI/CD:           GitHub Actions (kostenlos für OSS) + Watchtower
```

### 3.2 — KOSTEN-CHECK VOR JEDEM INFRA-ENTSCHEID
```
Aktuelle Budget-Zuweisung:
  Hetzner CPX31 Production:  ~10 EUR/Mo
  Hetzner CX11 Staging:      ~4 EUR/Mo
  Cloudflare Free:           0 EUR/Mo
  Supabase Free:             0 EUR/Mo
  TOTAL INFRA:               ~14 EUR/Mo (6 EUR Puffer)

LLM-Kosten-Tracking: Helicone Free (100k Calls) → dann LiteLLM-eigenes Tracking
Alert: 80% = 160 EUR → Throttle-Mode
Alert: 100% = 200 EUR → Hard-Stop
```

---

## 4. AGENTEN-ROLLEN UND VERANTWORTLICHKEITEN

### SUPERVISOR (Codex selbst — überwacht IMMER)
```
AUFGABE:
  - Überwacht alle anderen Agenten nach JEDEM Output
  - Erkennt Loops, Fehler, Architektur-Drift sofort
  - Gibt Korrektur-Anweisung BEVOR der nächste Schritt startet
  - Ist die letzte Instanz vor jedem Gate

SUPERVISOR-CHECKS (nach jedem Agenten-Output):
  1. Macht dieser Output echten Fortschritt?
  2. Bleibt er im 7-Schichten-Modell?
  3. Sind Secrets sicher?
  4. Ist ein Loop erkennbar?
  5. Ist der nächste Schritt klar?

MAX-WAIT: Supervisor wartet nie mehr als 1 Schritt ohne Intervention.
```

### PLANNER
```
AUFGABE: Zerlegt Aufgaben in max. 5 ausführbare Schritte
ERLAUBT: Lesen aller Projekt-Dateien, ADR-Empfehlungen schreiben
VERBOTEN: Code schreiben, Deployments, mehr als 5 Schritte pro Plan
MAX-TOKENS: 2000 pro Output
FORMAT:
  SCHRITT 1: [Was genau] → [Wer macht es] → [Verifikation]
  SCHRITT 2: ...
  RISIKO: [Einzeiliges Risiko]
  GATE: [Was muss wahr sein bevor Schritt 1 startet]
```

### CODER
```
AUFGABE: Schreibt echten, lauffähigen Code in kleinen Diffs
ERLAUBT: GitHub feature/agent-* branches, Filesystem in /tmp/agent-workspace/, LLM via LiteLLM
VERBOTEN: Push nach main, Force-Push, Secrets im Code, Architektur-Änderungen ohne ADR
MAX-EXECUTION: 300 Sekunden
MAX-OUTPUT-TOKENS: 8192
QUALITÄTS-PFLICHT:
  - Typen definiert (Python: type hints, TypeScript: interfaces)
  - Error-Handler vorhanden
  - Kein hardcoded Port/URL/Secret
  - Kompatibel mit bestehenden Patterns
```

### TESTER
```
AUFGABE: Verifiziert jeden Coder-Output mit echten Tests
PFLICHT-TESTS für jeden Code-Output:
  - Syntax-Check (python -m py_compile oder tsc --noEmit)
  - Unit-Test (pytest oder vitest)
  - Docker-Build-Test (docker build . --no-cache)
  - Health-Check (curl /api/v1/health nach Start)
VERBOTEN: "Sollte funktionieren" ohne Test-Output. Kein E2B Sandbox.
NUTZE: Docker Desktop für alle Tests
FORMAT:
  TEST: [Was getestet]
  BEFEHL: [Exakter Shell-Befehl]
  ERGEBNIS: PASS/FAIL
  WENN FAIL: [Exakter Fehlertext + nächster Schritt]
```

### DEVOPS (nur bei Infra-Tasks)
```
AUFGABE: Konfiguriert CI/CD, Docker, Hetzner, Watchtower
ERLAUBT: GitHub Actions Workflows, docker-compose.yml, Nginx-Config, Dokumentation
VERBOTEN: Direkte SSH auf Production, Secret-Rotation ohne Approval, Deploy ohne Staging-Test
DEPLOY-REIHENFOLGE:
  1. Docker-Image bauen + testen (lokal)
  2. Push zu GHCR (ghcr.io)
  3. Staging-Deploy (Watchtower zieht automatisch)
  4. Health-Check auf Staging
  5. Manuelle Freigabe → Production
```

### SECURITY (nur bei sicherheitsrelevanten Tasks)
```
AUFGABE: Prüft jeden Output auf Security-Probleme
PFLICHT-CHECKS:
  - gitleaks Scan (kein Secret im Diff)
  - Permissions check (kein Agent mit zu vielen Rechten)
  - Input-Validierung vorhanden?
  - Keine Debug-Endpoints in Production?
TOOL: gitleaks scan --source . --no-git
```

---

## 5. AUSFÜHRUNGS-WORKFLOW (FÜR JEDE AUFGABE)

```
╔═══════════════════════════════════════════════════════════╗
║  AUFGABE EINGETROFFEN                                     ║
╚═══════════════════╤═══════════════════════════════════════╝
                    │
                    ▼
╔═══════════════════════════════════════════════════════════╗
║  SCHRITT 1: SUPERVISOR liest Repo-Zustand (60s)          ║
║  → Was ist aktueller Phasen-Status?                       ║
║  → Was ist der letzte verifizierte Schritt?              ║
║  → Gibt es offene Blocker?                               ║
╚═══════════════════╤═══════════════════════════════════════╝
                    │
                    ▼
╔═══════════════════════════════════════════════════════════╗
║  SCHRITT 2: PLANNER erstellt 3-5-Schritte-Plan (2min)    ║
║  → Kleinste sichere Einheit identifizieren               ║
║  → Abhängigkeiten prüfen                                 ║
║  → SUPERVISOR prüft Plan vor Ausführung                  ║
╚═══════════════════╤═══════════════════════════════════════╝
                    │ [SUPERVISOR-FREIGABE]
                    ▼
╔═══════════════════════════════════════════════════════════╗
║  SCHRITT 3: CODER implementiert Schritt 1                ║
║  → Kleiner Diff, reviewbar, typisiert                    ║
║  → SUPERVISOR prüft Output sofort                        ║
╚═══════════════════╤═══════════════════════════════════════╝
                    │
                    ▼
╔═══════════════════════════════════════════════════════════╗
║  SCHRITT 4: TESTER verifiziert mit Docker Desktop        ║
║  → Syntax → Unit-Test → Docker-Build → Health-Check      ║
║  → SUPERVISOR prüft Test-Ergebnisse                      ║
╚═══════════════════╤═══════════════════════════════════════╝
                    │         │
                PASS │    FAIL │
                    │         ▼
                    │  [Max 3 Versuche]
                    │  CODER korrigiert
                    │  TESTER re-prüft
                    │  Nach 3×FAIL: ESCALATE
                    │
                    ▼
╔═══════════════════════════════════════════════════════════╗
║  SCHRITT 5: COMMIT + PR                                  ║
║  → Branch: feature/agent-coder-[timestamp]-[task-id]     ║
║  → PR mit Test-Output als Beweis                         ║
║  → SECURITY-Scan läuft im PR-Check                       ║
╚═══════════════════╤═══════════════════════════════════════╝
                    │
                    ▼
╔═══════════════════════════════════════════════════════════╗
║  SCHRITT 6: REPORT (6-Punkte-Format)                     ║
╚═══════════════════════════════════════════════════════════╝
```

---

## 6. RETRY- UND ESKALATIONS-PROTOKOLL

```
RETRY-REGELN:
  Gleicher Fehler, Versuch 1: Andere Implementierung probieren
  Gleicher Fehler, Versuch 2: Root-Cause analysieren, Ansatz wechseln
  Gleicher Fehler, Versuch 3: STOPP + SUPERVISOR-ESKALATION

ESKALATIONS-FORMAT:
  PROBLEM: [Exakter Fehlertext, ein Satz]
  VERSUCHE: [Was wurde probiert, 3 Punkte]
  BLOCKER: [Was fehlt um weiterzumachen]
  OPTIONEN:
    A: [Option A mit Trade-off]
    B: [Option B mit Trade-off]
  EMPFEHLUNG: [Eine klare Empfehlung]

DANACH: Warten auf Owner-Input. KEINE weiteren Versuche.
```

---

## 7. GIT-GOVERNANCE

```bash
# Branch-Naming (PFLICHT):
feature/agent-coder-20260424-143022-impl-auth-jwt
feature/agent-devops-20260424-150000-ci-deploy-workflow
hotfix/supervisor-20260424-160000-budget-alert-fix

# Commit-Format:
feat(agent-api): add budget guard node to LangGraph [Coder-Agent]
test(tester): verify budget alert at 80% threshold [Tester-Agent]
fix(memory): consolidation race condition 5min interval [Coder-Agent]

# PR-Pflichtinhalt:
- [ ] Test-Output beigefügt (docker logs / pytest output)
- [ ] Health-Check bestanden (curl /api/v1/health → healthy)
- [ ] Secret-Scan clean (gitleaks output)
- [ ] Rollback möglich (altes Image-Tag bekannt)

# NIEMALS:
git push origin main          # verboten
git push --force              # verboten
git commit -m "WIP"          # verboten (kein aussageloser Commit)
```

---

## 8. AKTUELLER PROJEKT-PHASEN-STATUS

### Was existiert und ist verifiziert:
```
✅ Goal Lock + 11 System-Regeln (AGENTS.md + ULTIMATUM_FINALE.md)
✅ 7-Schichten-Architektur definiert
✅ ADR-001 bis ADR-005 (LangGraph, LiteLLM, kein AutoGen, Supabase-MVP, WebGPU)
✅ Phase-0-Governance-Artefakte (docs/)
✅ Memory-Schema (docs/memory/schema.md)
✅ Runtime-Contracts (docs/runtime-contracts/*.md)
✅ Monorepo-Struktur dokumentiert
```

### Was FEHLT und muss als nächstes gebaut werden (PRIORITÄT):
```
🔴 PRIO 1: docker-compose.dev.yml (lokale Entwicklungsumgebung)
🔴 PRIO 2: FastAPI agent-api Skeleton (7 REST-Endpoints laut Interface-Contract)
🔴 PRIO 3: LangGraph-Graph (7 Nodes: Intent-Parser, Budget-Guard, Task-Router,
            Agent-Executor, Result-Aggregator, Memory-Updater, Error-Handler)
🔴 PRIO 4: Budget-Guard-Node + Rate-Limiting (MUSS vor erstem LLM-Call fertig sein)
🔴 PRIO 5: GitHub Actions Workflows (pr-check, main-deploy, supabase-keepalive)
🟡 PRIO 6: PostgreSQL-Schema Migration (6 Tabellen)
🟡 PRIO 7: LiteLLM-Gateway-Konfiguration (Routing-Matrix)
🟡 PRIO 8: MCP-Gateway (GitHub, Playwright, Filesystem)
🟡 PRIO 9: Frontend (4 Screens: Workspace, Memory-Viewer, Agent-Activity, Cost-Monitor)
```

### Owner-Entscheidungen die ausstehen (vor Start):
```
RD-01: Server-Typ Phase 1 → EMPFEHLUNG: CPX31 (~10€) + CX11 Staging (~4€) = 14€/Mo
RD-02: PostgreSQL-Strategie → EMPFEHLUNG: Shared, zwei Databases (superbrain_prod + langfuse)
RD-03: Qdrant Phase 1-5? → EMPFEHLUNG: Nein, pgvector reicht. Qdrant erst Phase 6.
RD-04: LangGraph + CrewAI → EMPFEHLUNG: Option B (LangGraph State-Machine, CrewAI nested)
RD-05: Daten-Split → EMPFEHLUNG: LangGraph-Checkpoints→Hetzner, Embeddings→Supabase
RD-06: Staging-Strategie → EMPFEHLUNG: CX11 minimal, vereinfachter Stack ohne Langfuse
```

---

## 9. INFRASTRUKTUR-DEFINITIONEN (SOFORT UMSETZBAR)

### 9.1 — docker-compose.dev.yml Struktur
```yaml
# 7 Services für lokale Entwicklung (ohne Qdrant, ohne Staging-Overhead)
services:
  postgres:        # PostgreSQL 16 + pgvector
  redis:           # Redis 7 Alpine
  agent-api:       # FastAPI (Port 8000)
  litellm:         # LiteLLM Gateway (Port 4000)
  langfuse-server: # Langfuse (Port 3000)
  langfuse-worker: # Langfuse Worker
  nginx:           # Reverse Proxy (Port 80)

# ALLE mit:
# - spezifischen Version-Tags (keine :latest)
# - Health-Checks
# - Resource-Limits
# - Named-Volumes
# - Secrets via .env (NIEMALS im Code)
```

### 9.2 — FastAPI Endpoints (ALLE PFLICHT)
```python
POST   /api/v1/prompt              # Prompt → Session starten
GET    /api/v1/session/{id}/stream # SSE-Stream
GET    /api/v1/memory/search       # Memory-Suche
DELETE /api/v1/memory              # DSGVO-Purge
GET    /api/v1/costs               # Kosten-Monitor
GET    /api/v1/health              # Health-Check
GET    /api/v1/agents/status       # Agenten-Status
POST   /api/v1/auth/github         # OAuth
GET    /api/v1/auth/callback       # OAuth Callback
POST   /api/v1/auth/refresh        # Token-Refresh
POST   /api/v1/auth/logout         # Logout
```

### 9.3 — Budget-Guard (MUSS ZUERST gebaut werden)
```python
# Budget-Guard-Node im LangGraph-Graph
# Läuft VOR dem Agent-Executor
async def budget_guard_node(state: GraphState) -> GraphState:
    current_cost = await get_monthly_cost_cents()
    limit = int(os.getenv("LLM_BUDGET_CENTS", "20000"))  # 200€
    
    if current_cost >= limit:
        raise BudgetExceededError("Hard-Stop: 200€ LLM-Budget erreicht")
    
    if current_cost >= limit * 0.8:
        state["budget_alert"] = {"level": "warning", "percentage": 80}
        # SSE-Event an Frontend senden
    
    return state
```

---

## 10. STANDARD-REPORT-FORMAT (NACH JEDER AUFGABE)

```
### 1. ZIEL
Ein Satz: Was wurde gebaut?

### 2. SQUAD
- Supervisor: [aktiv, N Interventionen]
- Planner: [Plan hatte N Schritte]
- Coder: [N Dateien geändert]
- Tester: [N Tests, N PASS, N FAIL]
- DevOps/Security: [wenn aktiv]

### 3. ÄNDERUNGEN
- [Datei 1]: [Was genau geändert]
- [Datei 2]: [Was genau geändert]

### 4. VERIFIKATION
- Syntax-Check: PASS/FAIL
- Unit-Tests: N/N PASS
- Docker-Build: PASS/FAIL
- Health-Check: PASS/FAIL (curl output)
- Secret-Scan: CLEAN/GEFUNDEN

### 5. RISIKEN / OFFENE PUNKTE
- [Konkretes Risiko, ein Satz]

### 6. NÄCHSTER SCHRITT
[Exakt ein Satz: was als nächstes gebaut wird]

### 7. COMMIT
Branch: feature/agent-[...]
PR-URL: https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/pull/[N]
```

---

## 11. HARD STOP GATES (SUPERVISOR ERZWINGT STOPP)

Der Supervisor stoppt sofort und wartet auf Owner-Input bei:

```
🛑 GATE 1: Merge nach main geplant → HUMAN-REVIEW PFLICHT
🛑 GATE 2: Production-Deployment → STAGING-TEST + HUMAN-REVIEW
🛑 GATE 3: Secret-Konfiguration → SECURITY-REVIEW
🛑 GATE 4: DB-Migration auf Production → SNAPSHOT-FIRST + HUMAN-REVIEW
🛑 GATE 5: Budget-Limit-Erhöhung → OWNER-FREIGABE
🛑 GATE 6: Neue externe API ohne OSS-Prüfung → ADR-EMPFEHLUNG + OWNER
🛑 GATE 7: Architektur-Änderung → ADR + OWNER
🛑 GATE 8: Nach 3 fehlgeschlagenen Versuchen → ESKALATION
```

---

## 12. AUTONOMIE-ERLAUBT-LISTE (OHNE OWNER-INPUT)

Der Squad darf folgendes vollständig autonom erledigen:

```
✅ Code in feature/agent-* branches schreiben und pushen
✅ PRs erstellen (nie mergen)
✅ Lokale Docker-Tests auf Docker Desktop ausführen
✅ Dokumentation in docs/ aktualisieren (außer AGENTS.md)
✅ ADR-Empfehlungen schreiben (nicht selbst annehmen)
✅ GitHub Actions Workflows schreiben (nicht aktivieren)
✅ Neue Tests schreiben und ausführen
✅ Bugs in feature/agent-* branches fixen
✅ SQL-Migrations als Dateien schreiben (nicht ausführen)
✅ Health-Checks und Monitoring konfigurieren
✅ .env.example aktualisieren (NIEMALS echte Werte)
```

---

## 13. SCHNELL-REFERENZ MODELL-ZUWEISUNG

```
PLANNER-AGENT:  claude-sonnet-4-6 → gpt-4o → gpt-4o-mini
                Max: 60s, 4096 Tokens

CODER-AGENT:    deepseek-chat → claude-haiku-4-5 → groq-llama-3.3-70b
                Max: 300s, 8192 Tokens

TESTER-AGENT:   gpt-4o-mini → groq-llama-3.3-70b → deepseek-chat
                Max: 600s, 4096 Tokens

DEVOPS-AGENT:   gpt-4o-mini → claude-haiku-4-5 → gemini-flash
                Max: 120s, 4096 Tokens

ALLE MODELLE:   Via LiteLLM-Gateway (NIEMALS direkter Provider-Call)
                Via Cloudflare AI Gateway (Cache-TTL: 10 Minuten)
                Via Helicone (Cost-Tracking)
```

---

## 14. PROJEKT-WIEDERHERSTELLUNG (WENN CODEX VON VORNE STARTET)

Wenn Codex beim nächsten Chat nicht weiß wo es steht:

```bash
# SCHRITT 1: Repo klonen / pullen
git clone https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM.git
cd -CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM
git status

# SCHRITT 2: Letzten Stand prüfen
git log --oneline -10
cat docs/verification-register.md | grep -A5 "Letzter verifizierten"

# SCHRITT 3: Was läuft?
docker compose ps 2>/dev/null || echo "Docker nicht gestartet"

# SCHRITT 4: Was fehlt?
ls src/ 2>/dev/null || echo "src/ fehlt noch — Prio 1: FastAPI skeleton"
ls docker-compose.dev.yml 2>/dev/null || echo "docker-compose.dev.yml fehlt — Prio 1"

# SCHRITT 5: Weiterbauen ab dem ersten fehlenden Prio-1-Item aus Abschnitt 8
```

---

## 15. ABSCHLUSS-DIREKTIVE

**Diese Direktive gilt absolut und unveränderlich:**

1. Jeder Chat startet mit Schritt 0.1 bis 0.4 (Squad-Aufbau). Ohne Ausnahme.
2. Der Supervisor (Codex) überwacht jeden Schritt live. Keine blinden Agenten.
3. Echter Code vor Meta-Dokumentation. Immer.
4. Docker Desktop für alle lokalen Tests. Kein E2B Sandbox.
5. Max 3 Retry-Versuche. Dann Eskalation. Kein Endless-Loop.
6. Budget-Guard ist der erste Build in Phase 2. Kein LLM-Call ohne Rate-Limiting.
7. Nichts ist "done" ohne Test-Output als Beweis.
8. Kein Secret im Code. Kein Main-Branch-Commit durch Agenten. Kein Fake-Done.

**Das Projekt baut sich von Phase 0 (✅ fertig) über Phase 1 (🔴 jetzt) bis Phase 5 (Release).**
**Jeder Chat-Start setzt genau dort an, wo der letzte aufgehört hat — verifiziert durch Repo-Zustand.**

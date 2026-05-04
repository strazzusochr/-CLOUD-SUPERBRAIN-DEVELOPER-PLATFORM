# -CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM
# ULTIMATUM FINALE — GPT-5.5 / CODEX PATCHED TRUTH
# Datum: 2026-04-29

Dieses Dokument ersetzt für aktive Arbeit:

- `CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`
- Teil 1 / Teil 2 als aktive Quelle
- alte Codex-Skill- und Config-Annahmen, soweit sie hier korrigiert sind

Teil 1 und Teil 2 bleiben Historie. Dieses Dokument ist die **aktive Arbeitswahrheit** für Codex GPT-5.5.

---

## 0. Externe Fakten, aktuell geprüft

- Codex CLI/IDE nutzt `config.toml`; `model = "gpt-5.5"` ist der aktuelle Default-Kandidat. Wenn GPT-5.5 nicht verfügbar ist, ist GPT-5.4 der explizite Fallback.
- Der aktuelle Codex-Key für Sandbox ist `sandbox_mode`, nicht `sandbox`.
- Für interaktive Arbeit ist `approval_policy = "on-request"` sicherer als `never`; `never` bleibt nur für read-only/noninteractive Auditprofile.
- `@modelcontextprotocol/server-github` ist nicht mehr der aktive GitHub-MCP-Standard; der offizielle GitHub MCP Server läuft über `ghcr.io/github/github-mcp-server` oder GitHubs hosted MCP.
- Hetzner hat zum 01.04.2026 Preisänderungen vorgenommen. Budgetentscheidungen müssen deshalb nicht aus alten Blueprint-Zahlen, sondern aus aktueller Preiskalkulation oder realer Rechnung abgeleitet werden.

---

## 1. Project Goal Lock

**Projekt:** `-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`

**North Star:** Eine cloud-native, prompt-gesteuerte Multi-Agent-AI-Developer-Platform, die Softwareprojekte inklusive 3D-Webgames über natürliche Sprache erstellt, testet und deployt, ohne lokale Produktionslast und ohne lokale Modell-Downloads.

**MVP:** 4-Agenten-Squad, Prompt-Interface, Streaming, pgvector Memory, GitHub-Integration, CI/CD, Hosted Staging, Observability.

**Budget:** Infrastruktur maximal 20 EUR/Monat. LLM-Budget Phase 1-5 maximal 200 EUR/Monat, live erst nach Gate.

---

## 2. Korrigierte harte Regeln

1. Kein Produktions-Localhost. Localhost ist nur `DEV-ONLY` für Docker-/Browser-Smoke-Tests erlaubt.
2. Kein lokaler Model-Download.
3. Kein direkter Main-Commit durch Agenten.
4. Kein Live-Provider-Call ohne LLM-Gateway und Budget-Guard.
5. Kein Live-MCP-Write ohne Owner-Gate.
6. Keine Secrets in Code, Logs, Konfigurationsbeispielen oder Antworten.
7. Kein Fake-Done: Done = implementiert + getestet + integriert + geloggt + verifiziert.
8. Keine Supabase/Qdrant/LanceDB/Ollama/Railway/HuggingFace-Spaces als Phase-1-5 Runtime-Default.
9. Keine CPX51/CPX31/GPU-Server vor Phase-Gate und ADR.
10. Kein deprecated GitHub npm MCP; nur offizieller GitHub MCP Server.

---

## 3. Aktive Architektur-Locks

| Schicht | Entscheidung |
| --- | --- |
| Frontend | Next.js/React, shadcn/ui, Dark Mode |
| Orchestrator | FastAPI + LangGraph |
| Agent Pool | Planner, Coder, Tester, DevOps über LangGraph Task Envelopes |
| LLM Gateway | LiteLLM-kompatibler Gateway-Vertrag; dry-run bis Live-Gate |
| Tool/MCP | Gateway mit Scopes, Timeouts, Audit, Write-Gates |
| Memory | Redis Working Memory + PostgreSQL/pgvector Long-Term Memory |
| Observability | Audit/metrics lokal; Langfuse/Grafana gated/self-hosted |

---

## 4. Phase-1 Infrastruktur

**Startklasse:** Hetzner CX22/CX23 oder vergleichbar kleiner Shared-vCPU-Server. Kein CPX51. Kein zusätzlicher Staging-Server ohne Budgetbeweis.

**Datenbank:** eine PostgreSQL-Instanz; getrennte DB/Schemas für App-State und Langfuse. pgvector ist Vektorstandard Phase 1-5.

**Hosted Proof:** Eine echte `STAGING_BASE_URL` ist Pflicht, bevor Cloud-native Gates geschlossen werden.

---

## 5. Codex GPT-5.5 Setup

Aktive Dateien:

- `AGENTS.md`
- `.codex/config.toml` oder `~/.codex/config.toml`
- `docs/codex-integration/CODEX_AGENT_SKILL_MASTER.md`

Aktive Profile:

- `superbrain-gpt55-safe`: interaktiv, workspace-write, approval on request
- `superbrain-gpt54-fallback`: expliziter Fallback
- `superbrain-noninteractive-audit`: read-only, approval never

Verboten:

- `sandbox = "danger-full-access"` als Root-Key
- `approval_policy = "never"` kombiniert mit voller Schreibmacht
- deprecated `@modelcontextprotocol/server-github`
- localhost-CDP als Default-MCP

---

## 6. Offene Gates nach diesem Patch

Dieses Dokument und die beigefügten Fix-Dateien korrigieren Dokument-/Konfigurationsfehler. Sie öffnen keine externen Gates.

Weiterhin blockiert:

1. Hosted Staging URL fehlt.
2. GitHub Branch Protection muss real gesetzt und geprüft werden.
3. Hetzner-Kosten müssen über echte Rechnung/API oder aktuellen Kalkulator verifiziert werden.
4. gitleaks muss als echter Secret-Scanner in CI und lokal nachweisbar laufen.
5. Live LLM Provider bleiben geschlossen, bis Budget-Guard + Audit + Owner-Gate aktiv sind.

---

## 7. Next Safe Step für Codex

```text
NEXT PROMPT FOR CODEX GPT-5.5

Lies AGENTS.md, PROJECT_STATE.md und docs/CLOUD_SUPERBRAIN_ULTIMATUM_GPT55_PATCHED_2026-04-29.md.
Prüfe, ob .codex/config.toml dem gepatchten config.fixed.toml entspricht.
Führe keine Live-Provider-Calls, keine MCP-Writes, keine Docker-Pushes und keine Production-Aktionen aus.
Erzeuge zuerst einen Verifikationslauf:
1. TOML parse check
2. grep auf deprecated @modelcontextprotocol/server-github
3. grep auf sandbox = "danger-full-access"
4. grep auf Supabase/Qdrant als aktive Runtime-Defaults
5. gitleaks detect --no-git --source . falls gitleaks installiert ist
Berichte nur verifizierte Ergebnisse.
```

# MARKET-READY PROTOKOLLBERICHT — CLOUD SUPERBRAIN DEVELOPER PLATFORM

**Erstellt:** 2026-09-10 (17:18–18:35 CEST)
**Auditor:** Claude Opus 5 (Claude Code, autonomer Tiefenaudit-Lauf)
**Audit-HEAD:** `f6178cec2c9dbdcce02937893bb17d038b01ae47`
**Branch:** `claude/cloud-superbrain-deep-analysis-e36c04`
**Arbeitsverzeichnis:** `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM\.claude\worktrees\gallant-sutherland-d0e1c6`

> **Ehrlichkeitsklausel.** Kein Prozentwert wurde erhöht. Kein Gate wurde geöffnet.
> `MARKET_READY` bleibt **false** — belegt durch den projekteigenen Verifier, nicht behauptet.
> Jeder Beweis unten ist ein **neu ausgeführter** Befehl mit Exitcode und Zeitpunkt,
> sofern nicht ausdrücklich als „übernommen“ markiert.

---

## A. ENDSTATUS

| Größe | Wert | Quelle | Neu geprüft |
|---|---|---|---|
| **Overall** | **90 %** | `docs/project-progress.manifest.json` + Hosted-API | ja |
| **MARKET_READY** | **false** | `verify-market-ready.ps1` → `AGGREGATE_STATE: INVALID` | ja |
| Phase 0 / 1 / 2 | 100 / 100 / 100 | Manifest | ja |
| **Phase 3** | **44** | Manifest | ja |
| Phase 4 | 100 | Manifest | ja |
| **Phase 5** | **89** | Manifest | ja |
| Phase 6 | 100 | Manifest | ja |
| Layer 1–7 | je 100 | Manifest (`vertical`) | ja |
| Lokale Release-Reife | **grün** (Build + Lint + Runtime + Browser) | siehe D | ja |
| Hosted-Reife | **teilweise** — Frontend/Backend live, Kernfunktion blockiert | siehe H-1 | ja |
| Produktionsreife | **nein** | externes Gate `ghcr_images` offen | ja |

### Widerlegte Ausgangsannahmen des Auftrags

Der Auftrag nannte Werte, die **nicht mehr gelten**. Alle wurden neu abgeleitet:

| Annahme im Auftrag | Realer Wert | Urteil |
|---|---|---|
| Overall 84 % | **90 %** | veraltet |
| Phase 2 = 86 | **100** | veraltet |
| Phase 3 = 44 | 44 | **korrekt** |
| Phase 5 = 68 | **89** | veraltet |
| Phase 6 = 90 | **100** | veraltet |
| 22 Routen | **26 Seiten-Routen** | unvollständig |
| 10 Container healthy | 10/10 healthy | **korrekt** |
| 21/21 Seiten im Build | 21/21 statisch prerendert | **korrekt** |
| 44 Browser-Interaktionen | **88** (bei 52 Seitenaufrufen) | überholt |
| `MARKET_READY:false` | false | **korrekt** |
| Blocker `vercel_backend_origin_health` | **aufgelöst** — Gate `vercel_backend_origins` ist configured+verified | **falsch/veraltet** |
| HMAC-SHA256 Session-Integrität | lokal verifiziert, hosted fail-closed | **korrekt** |
| `raw_secret_persisted=false` | `False` (frisch nachgemessen) | **korrekt** |
| Remote-Pushes erfolgreich | `da3a338` + `0555b0b` auf `origin` vorhanden | **korrekt** |

---

## B. DOKUMENTENPRÜFUNG UND ARCHIVIERUNG

### Archivauftrag (kopieren, nichts löschen) — ERLEDIGT

Ziel: `D:\PLATTFORM\CLOUD_SUPERBRAIN_COMPLETE_DOCUMENT_ARCHIVE_2026-08-01\11_DEEP_AUDIT_2026-09-10\`

| Quelle | Dateien |
|---|---|
| `A_MAIN_CHECKOUT\_TOPLEVEL_DOCS` | 81 |
| `A_MAIN_CHECKOUT\docs` | 571 |
| `A_MAIN_CHECKOUT\codex_runs_CURRENT` | 2026 |
| `B_SERVING_TREE_rc101\_TOPLEVEL_DOCS` | 57 |
| `B_SERVING_TREE_rc101\docs` | 1229 |
| `B_SERVING_TREE_rc101\codex_runs_CURRENT` | 126 |
| `B_SERVING_TREE_rc101\phase1-artifacts` | 88 |
| `C_WORKTREE_AUDIT_BRANCH\_TOPLEVEL_DOCS` | 46 |
| **Summe neu** | **4.291 Dateien / 449,4 MB** |
| **Archiv gesamt danach** | **9.527 Dateien / 4.054 MB** |

- **Nichts gelöscht.** Robocopy ohne `/MIR`, rein additiv.
- **Integrität:** Quelle 2026 Dateien = Ziel 2026 Dateien, **Differenz 0**.
  Ein `rc=9` betraf ausschließlich einen Zeitstempel auf einem leeren Verzeichnis
  (`goal-d3\evidence\`) — kein Datenverlust.
- **10/10 kritische Dokumente per SHA-256 Hash gegengeprüft** (alle MATCH), u. a.
  `CODEX_UEBERGABE_NEUER_CHAT_2026-09-10.md`, `CODEX_ZIEL_CHECKPOINT_2026-09-10.md`,
  `AUDIT_LOG_2026-09-02_CLAUDE.md`, `PROJECT_STATE.md`.

### Befund B-1 — 25 Owner-Dokumente existieren nur auf Platte, nicht in Git

Der Hauptordner enthält **66** Top-Level-`.md`, git-verfolgt sind **41**.
Rund **25 Dokumente erreichen keinen Push** und wären bei Verlust des Laufwerks weg,
darunter `AUDIT_LOG_2026-09-02_CLAUDE.md`, `BERICHTSPROTOKOLL_2026-09-02_CLAUDE.md`,
`OWNER_AI_PROMPT_2026-09-02.md`, `MASTER_PROJECT_ROADMAP.md`, `SUPERBRAIN_MASTER_PROMPT.md`,
`HANDOFF_TO_GPT_AGENT.md`, `CLAUDE_MESSBEFUND_2026-08-29-HOSTED-OAUTH-P6.md`.
**Durch diese Archivierung sind sie jetzt gesichert.**

### Befund B-2 — Die zwei neuesten Statusdokumente lagen nur im Serving-Tree

`CODEX_UEBERGABE_NEUER_CHAT_2026-09-10.md` und `CODEX_ZIEL_CHECKPOINT_2026-09-10.md`
(beide 2026-09-10 09:51) existierten **ausschließlich untracked** in
`D:\_sb_tmp\rc101-generated-sphere-repair`. Jetzt archiviert.

### Dokumenten-Inventar (git-verfolgt, Audit-HEAD)

2.016 verfolgte Dateien; davon `.md` 332, `.json` 583, `.ps1` 299, `.txt` 198,
`.mjs` 25, `.yml` 14, `.toml` 8, `.cjs` 7.

---

## C. SEITENPRÜFUNG — ALLE 26 ROUTEN, DESKTOP + MOBILE

### Befund C-1 (zentral) — Es sind 26 Routen, nicht 22

- **Dateisystem:** 26 `page.tsx` unter `apps/frontend/app`.
- **Produktions-Build bestätigt** dieselben 26 Seiten-Routen (plus 4 Route-Handler
  `/health`, `/exports/docs`, `/llm/[...slug]`, `/mcp/[...slug]`).
- **Live-Registry** `/api/v1/workspace/wiring` liefert nur **22** Surfaces.
- `scripts/verify-workspace-responsive-browser.cjs:268` erzwingt hart
  `assert(surfaces.length === 22)`.

**Die 4 nicht registrierten Routen sind echte, gerenderte Seiten (alle HTTP 200):**

| Route | Art | Status |
|---|---|---|
| `/` | echte Landing-Page mit `CortexLive`-3D | 200 — **kein Redirect** |
| `/organism/live` | echte Produktfläche (`OrganismView mode="live"`) | 200 |
| `/responsive` | echte Doku-/Breakpoint-Seite | 200 |
| `/run/[id]` | dynamische Build-Ergebnisseite | 200 |

**Bewertung:** Die Aussage „22/22 Seiten geprüft" in `PROJECT_STATE.md` ist für die
registrierten Surfaces korrekt, **beschreibt aber nicht die Gesamtfläche**. `/organism/live`
ist eine reale Produktseite ohne Responsive-Vertragsdeckung. Zusätzlich ist die harte
`=== 22`-Assertion **spröde**: Wer die fehlenden Surfaces korrekt registriert, lässt den
Verifier fehlschlagen.

### Ergebnis des neuen Voll-Sweeps (26 × 2 = 52 Aufrufe)

Werkzeug: `scripts/audit-26-route-responsive-sweep.cjs` (neu, in diesem Lauf erstellt)
Desktop 1440×900, Mobile 390×844, Chromium.

| Kennzahl | Ergebnis |
|---|---|
| Seitenaufrufe | **52 / 52 HTTP 200** |
| Fehlgeschlagene Aufrufe | **0** |
| **JavaScript-Ausnahmen (pageerror)** | **0** |
| **Horizontales Scrollen auf Mobile** | **0** — bestätigt `mobile_390_overflow_zero` |
| **Doppelte DOM-IDs** | **0** |
| Ausgeführte Interaktionen | **88** |
| Screenshots | **52** (Desktop + Mobile je Route) |
| Seiten mit Konsolenfehlern | 4 |
| Seiten mit fehlgeschlagenen Requests | 10 |

**Beweispfad:** `.codex/runs/CURRENT/master-goal/evidence/browser-26/`
(`report.json`, `progress.ndjson`, `sweep.log`, 52 PNG)

### Einordnung der 4 Konsolenfehler / 10 Request-Fehler — kein Produktdefekt

| Vorkommen | Ursache | Urteil |
|---|---|---|
| `/login` (Desktop+Mobile): HTTP 401 auf `/api/v1/auth/me`, `/api/v1/auth/refresh` | Nicht angemeldeter Besucher | **korrektes Fail-closed** |
| `/run/[id]`: HTTP 404 auf `/api/v1/build/audit-probe` | Meine synthetische Test-ID existiert nicht | **Artefakt der Prüfung** |
| `/organism*`: `ERR_ABORTED` auf `live-state`, `events`, `replay` | SSE-/Streaming-Verbindungen beim Seitenschluss abgebrochen | **erwartetes Streaming-Verhalten** |

### Befund C-2 — Die `/organism`-Familie überschreitet das 60-s-Automationsbudget

8 von 52 Aufrufen (`/organism`, `/organism/live`, `/organism/map`, `/organism/replay`
je Desktop+Mobile) liefen in das 60-Sekunden-Budget. Alle liefern **HTTP 200** und
rendern (Screenshots vorhanden), aber die Interaktionsphase kommt nicht zum Abschluss.
`/organism/map` meldet **279 interaktive Elemente**, `/organism*` je ~49–51.

Ein erster Sweep-Lauf **blieb an genau dieser Stelle vollständig hängen** und musste
abgebrochen werden. Erst nach Härtung (Routen-Budget, Klick-Deckel, Dialog-Handler)
lief der Sweep durch.

**Bewertung:** Die 3D-Cortex-Seiten sättigen den Main-Thread so stark, dass
Automatisierung nicht in 60 s durchläuft. Für menschliche Nutzung ist die Seite
erreichbar und schnell ausgeliefert (TTFB 0,089–0,106 s), aber dies ist ein **realer
Performance- und Testbarkeitsbefund**, kein grüner Punkt.

### Per-Route-Performance (lokal, HTTP, neu gemessen)

Alle 26 Routen **HTTP 200**. TTFB-Spanne **0,069 s – 0,722 s**.

| Schnellste | s | Langsamste | s |
|---|---|---|---|
| `/technology` | 0,070 | `/evidence` | **0,722** |
| `/login` | 0,071 | `/agents` | **0,558** |
| `/media` | 0,078 | `/observe` | **0,505** |
| `/responsive` | 0,079 | `/tools` | 0,279 |

Größte Nutzlasten: `/marketplace` 61 KB, `/tools` 59 KB, `/agents` 55 KB.
**Bewertung: gut.** Keine Route über 1 s. `/evidence`, `/agents`, `/observe` sind die
sinnvollen Optimierungskandidaten (5–10× langsamer als der Median).

Rohdaten: `.codex/runs/CURRENT/master-goal/evidence/route-performance.csv`

### Interaktionstiefe — ehrliche Einschränkung

Der Sweep klickte pro Seite im Mittel 2 von teils 21–279 gefundenen Steuerelementen.
Ursache: Nach den ersten Klicks verdecken Overlays/Paletten weitere Elemente, und
gefährliche Aktionen (löschen, deploy, rotate, purge, logout …) sind bewusst
ausgeschlossen. **Es ist damit kein vollständiger Klick-Durchlauf jeder Fläche.**
Die Werkbank wurde dafür separat und vollständig funktional geprüft (Abschnitt D-4).

---

## D. TESTMATRIX — ALLE BEFEHLE NEU AUSGEFÜHRT

Alle Läufe gegen Audit-HEAD `f6178cec`, 2026-09-10.

| # | Befehl | Exit | Dauer | Ergebnis |
|---|---|---|---|---|
| D-1 | `npm run build` (Produktions-Build) | **0** | ~4 min | **Compiled successfully in 46s**, 21/21 statische Seiten |
| D-2 | `npm run lint` | **0** | 76,2 s | **0 Warnungen** |
| D-3 | `npm run verify:market-ready:unit` | **0** | 666,3 s | 19 Python-Module + 13 Node-Tests, fail 0 |
| D-4 | Werkbank-Livebuild (Browser, echter Klick) | — | 35 s | **App generiert, persistiert** |
| D-5 | `npm run verify:auth-session` | **0** | 15,6 s | `status=verified browser_click_verified=True` |
| D-6 | `npm run verify:memory-secret-guard` | **0** | 17,8 s | `status=verified raw_secret_persisted=False` |
| D-7 | `npm run verify:market-ready:static` | **2** | 37,5 s | **`MARKET_READY: false`** (erwartet, s. H) |
| D-8 | 26-Routen-Sweep Desktop+Mobile | 0 | ~28 min | 52/52 · 0 JS-Fehler · 0 Overflow |
| D-9 | API-Sweep 141 GET-Endpunkte | 0 | ~3 min | 133×200, 8 erklärbar |
| D-10 | Routen-Performance 26× | 0 | ~1 min | alle 200, TTFB < 0,73 s |

### D-4 — Der entscheidende Produktbeweis: die Werkbank baut wirklich

Echter Klick auf „✨ Bauen" in `http://localhost:8081/workbench`:

```
Build-Protokoll
qwen/qwen2.5-coder-32b-instruct
▸ Anfrage an das LLM-Gateway…
✓ 5.285 Bytes in 35s generiert
✓ 3 Datei(en) · GPU-Schutz injiziert
✓ Build-ID f1ca1360-7679-4347-a107-bbcc87d1bd7e
✓ LLM-Gateway cloudflare-workers-ai · live_provider_calls=true
✓ Live-Vorschau bereit
✓ Persistiert · /run/f1ca1360-7679-4347-a107-bbcc87d1bd7e
```

**Unabhängig über HTTP gegengeprüft** (nicht nur UI-Text):
`GET /api/v1/build/f1ca1360-…` → **HTTP 200**, und der Datensatz meldet
`status: "verified"`, `model: "@cf/qwen/qwen2.5-coder-32b-instruct"`,
`live_provider_calls: true`, `persisted: true`,
`direct_provider_calls/live_mcp_writes/production_deploy/secret_output` sämtlich als
Grenzflags gesetzt. `GET /run/<id>` → **HTTP 200**.

**Das ist ein echter Live-LLM-Aufruf, keine Mock-Antwort.** Die Kernfunktion
Prompt → Code → Vorschau → Persistenz funktioniert lokal Ende-zu-Ende.

### D-9 — API-Vertragslage (141 parameterlose GET-Endpunkte)

133 × HTTP 200. Die 8 Abweichungen sind **alle korrektes Verhalten**:

| Endpunkt | Code | Warum korrekt |
|---|---|---|
| `/api/v1/auth/me`, `/api/v1/auth/callback` | 401 | Fail-closed ohne Session |
| `/api/v1/auth/github` | 303 | OAuth-Redirect |
| `/api/v1/memory/search`, `/rate-limit/status`, `/session-limits/status` | 422 | Pflichtparameter fehlt → saubere Validierung |
| `/internal/tasks`, `/team/status` | 404 | interne Routen bewusst nicht über nginx exponiert |

**Kein einziger API-Defekt gefunden.** Backend-Fläche: 174 Pfade laut OpenAPI.

---

## E. SIEBEN-LAYER-MATRIX

| Layer | Geprüft mit | Ergebnis | Offener Punkt |
|---|---|---|---|
| **L1 Frontend** | 52 Browseraufrufe, Build, Lint, Performance | **grün** — 0 JS-Fehler, 0 Overflow, 0 doppelte IDs | `/organism*` Automationsbudget (C-2); 4 Routen ohne Vertragsdeckung (C-1) |
| **L2 Orchestrator** | 141 GET-Endpunkte, Contract-Endpunkte | **grün** — Contracts vorhanden und antwortend | — |
| **L3 Agent Pool** | `/api/v1/agents/status`, `/agents/profiles`, `/team/roster` | **grün** (200) | Rollen-Tiefenprüfung nicht Teil dieses Laufs |
| **L4 LLM Gateway** | **echter Livebuild D-4** | **grün** — `live_provider_calls=true`, Modell `@cf/qwen/qwen2.5-coder-32b-instruct` | hosted blockiert (H-1) |
| **L5 MCP Gateway** | `/api/v1/audit/mcp`, `/tools/read-only/execute`, `/tools/live-write/probe` | **grün** (200) | `live_mcp_writes=false` im Build-Envelope — Grenze wird eingehalten |
| **L6 Memory** | `verify:memory-secret-guard` **neu ausgeführt** | **grün** — `raw_secret_persisted=False`, verschachtelte Metadaten geprüft | — |
| **L7 Observability** | `/health`, `/metrics`, `/budget`, `/external-gates`, Container-Health | **grün** — 10/10 Container healthy | — |

**Container (neu geprüft, nicht übernommen):** 10/10 `healthy` — frontend, agent-api,
llm-gateway, nginx, redis, agent-worker, mcp-gateway, memory-worker, postgres, local-llm.

### Befund E-1 — Die laufende Plattform stammt nicht aus dem Hauptcheckout

`localhost:8081` wird **nicht** aus `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`
bedient, sondern aus **`D:\_sb_tmp\rc101-generated-sphere-repair`**
(Branch `codex/rc103-final-gate-contracts`, HEAD `e72e6b98`, 8 Dateien dirty),
mit Live-Bind-Mounts auf `apps/frontend/{app,components,lib}`.

**Beweis-Integritätsprüfung:** Ich habe den Serving-Tree gegen den Audit-HEAD diffed.
`components/` und `lib/` sind **byteidentisch**. Es unterscheidet sich **genau eine Datei**:
`app/layout.tsx` — der Audit-HEAD ergänzt `<Analytics />` von `@vercel/analytics`.
Diese Differenz verändert kein Seiten-Markup.

**Konsequenz — ehrlich benannt:** Die Browserbeweise in Abschnitt C sind
quellgebunden an `e72e6b98` + Working-Delta, **nicht** an `f6178cec`. Sie sind wegen
der Byte-Identität von `components/`+`lib/` übertragbar, aber sie sind **kein** Beweis
für das `@vercel/analytics`-Verhalten des Audit-HEAD. Der Produktions-Build (D-1) und
der Lint (D-2) sind dagegen **direkt** an `f6178cec` gebunden.

---

## F. EXTERNE GATES UND HOSTED-ZUSTAND

### Hosted ist live und echt

| Fläche | Ergebnis |
|---|---|
| `https://frontend-seven-psi-78.vercel.app` | `/`, `/home`, `/workbench`, `/organism` → **200** (0,28–1,44 s) |
| `https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev` | `/`, `/api/v1/health` → **200**; `/api/v1/auth/me` → **401** (fail-closed) |
| Hosted `overall_percent` | **90** — identisch mit lokal |

**Befund F-1 — Der Hosted-Backend ist keine Attrappe mehr.** `/api/v1/health` liefert
`contract_version: cloudflare-d1-stateful-runtime-v1`, `d1_binding_configured: true`,
`d1_read_verified: true`, `persisted: true`, `write_auth_configured: true`,
`source_commit_sha: e949cc1a…`. Vercel liefert **dieselbe** Nutzlast.
Frühere Notizen „Vercel ist nur Projektion, `live_backend:false`" sind damit **überholt**.

### Capability-Gates: 9 von 10 `live_verified: true`

Offen: **`production_auth_identity`** (`owner_granted: true`, `live_verified: false`).

### Externe Gates: 5 von 6 verifiziert

| Gate | Status |
|---|---|
| `branch_protection_token` | configured ✔ verified ✔ |
| `staging_base_url` | configured ✔ verified ✔ |
| `cloudflare_native_zero_card_hosted_runtime` | configured ✔ verified ✔ |
| **`ghcr_image_digest_proof`** | **configured ✘ verified ✘** |
| `vercel_backend_origins` | configured ✔ verified ✔ |
| `gitleaks_binary` | configured ✔ verified ✔ |

`blocked_release_gates: ["ghcr_images"]`, `canonical_summary_status: blocked`.

**Der im Auftrag genannte Blocker `vercel_backend_origin_health` existiert nicht mehr.**
Der einzige verbleibende externe Blocker ist die **GHCR-Image-Digest-Publikation**
(benötigt `GITHUB_TOKEN` / `GHCR_TOKEN`).

---

## G. GIT- UND REMOTE-MATRIX

### Befund G-1 — Es gibt nur einen Remote

Der Auftrag erwartete ggf. GitHub, Hugging Face Space und GitLab.
**Tatsächlich konfiguriert ist ausschließlich:**

| Remote | URL | Zielbranch |
|---|---|---|
| `origin` | `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM.git` | `chore/repo-bootstrap` (Default) |

**Kein Hugging-Face-Remote, kein GitLab-Remote.** Eine Aussage „überall gepusht"
kann sich daher nur auf `origin` beziehen. Tags: 0. Submodule: keine.

### Verifikation der im Auftrag genannten Commits

| Commit | Existiert | Inhalt wie behauptet | Auf `origin` |
|---|---|---|---|
| `da3a338` `fix(auth): enforce signed frontend sessions` | **ja** (`da3a338e`) | **ja** — 22 Dateien, u. a. `lib/authSession.ts` (+130), `verify-phase3-auth-session-integrity.ps1` (+65) | **ja** |
| `0555b0b` `fix(memory): block secrets in nested metadata` | **ja** (`0555b0bd`) | **ja** — 12 Dateien, u. a. `services/memory-worker/app/worker.py` (+48/-…), `verify-memory-worker-secret-guard.ps1` (+138) | **ja** |

Beide liegen u. a. auf `origin/chore/repo-bootstrap` (Default-Branch).
**Die Behauptungen aus Abschnitt 3 des Auftrags sind zutreffend.**

---

## H. VERBLEIBENDE BLOCKER

### H-1 (KRITISCH, produktwirksam) — Hosted-Kernfunktion ist ausgefallen

**Symptom, im Browser reproduziert** auf `https://frontend-seven-psi-78.vercel.app/workbench`:

```
▸ Anfrage an das LLM-Gateway…
✗ Sichere Gast-Sitzung nicht verfügbar.
```

**Ursache, isoliert:**

| Umgebung | `POST /api/v1/auth/session` |
|---|---|
| **Lokal** `:8081` | **200** — setzt `__Host-sb_session`, HMAC-SHA256, `Secure`, `HttpOnly`, `SameSite=strict`, TTL 30 d |
| **Hosted** Vercel | **503** `{"status":"blocked","error":"hosted_session_boundary_unavailable"}` |

Der Session-Contract meldet hosted `"secret_source": "ephemeral_process"` und
`restart_invalidates_session_without_configured_secret: true`.
**Das konfigurierte Signing-Secret (`AUTH_SESSION_SECRET`) fehlt in der Hosted-Umgebung.**

**Doppelte Bewertung — beides ist wahr:**
- **Sicherheitsseitig korrekt.** Der Endpunkt fällt *fail-closed* aus und gibt
  **keine** unsignierte Session aus. Das erfüllt exakt das Marktreife-Kriterium
  „fehlendes Secret führt nicht zu unsicherem Fallback".
- **Produktseitig ein Totalausfall.** Ein hosted Besucher kann die Kernfunktion
  („Bauen") **nicht** benutzen.

**Betroffene Phase:** 3 (44 %) · **Gate:** `production_auth_identity` (`live_verified:false`)
**Nötige Handlung:** `AUTH_SESSION_SECRET` (≥ 32 Byte) in der Hosted-Umgebung setzen,
danach Hosted-Session und Werkbank-Build erneut beweisen. **Owner-Aktion, kein Codefehler.**

### H-2 (extern) — GHCR-Image-Digest-Proof
`configured:false`. Braucht `GITHUB_TOKEN`/`GHCR_TOKEN`. Blockiert `blocked_release_gates`
und damit `MARKET_READY`. **Owner-Aktion.**

### H-3 (real, lokal) — Phase-5-Credit ist ungültig
`py -3 scripts/verify_project_progress_manifest.py` → **Exit 1**:
```
[phase5-credit] active candidate has committed or staged runtime-source drift
                outside the exact post-qualification or no-credit requalification truth transition
[project-progress] Phase-5 credit itemization is invalid
```
Der Audit-HEAD `f6178cec` (Merge PR #106, `ui/interactivity-vercel`) driftet gegenüber
der Source-Bindung des aktiven Kandidaten. **Das ist der Grund, warum
`manifest-integrity` im Market-Ready-Lauf FAIL meldet.** Auflösung nur über eine
saubere Neuqualifikation des Kandidaten auf diesen HEAD — bewusst **nicht** von mir
vorgenommen, da das Credit-Vergabe wäre.

### H-4 (Verifier-Qualität) — `lint-zero-warnings` misst das Falsche
`verify-market-ready.ps1` meldete `lint-zero-warnings FAIL exit=2`.
**Der Lint ist aber sauber:** nach `npm install` läuft `npm run lint` mit **Exit 0 und
0 Warnungen**. Der vorherige Exit 2 war ausschließlich
`Cannot find package 'eslint-config-next'` — also **fehlende Abhängigkeiten**, kein
Lint-Verstoß. Der Verifier kann „Lint rot" und „deps nicht installiert" nicht
unterscheiden und erzeugt so einen **falschen Defektbefund**.

### H-5 (Hygiene) — Node-Engine außerhalb des deklarierten Bereichs
`cloud-superbrain-frontend` verlangt `node >=20.9 <26`, installiert ist **v26.8.1**
(`npm warn EBADENGINE`). Build und Lint laufen trotzdem grün, aber die Umgebung liegt
außerhalb der unterstützten Spanne.

### H-6 (Testbarkeit/Performance) — `/organism`-Familie, siehe C-2

### H-7 (Vertragsdeckung) — 4 Routen ohne Responsive-Vertrag, spröde `=== 22`, siehe C-1

---

## I. GEÄNDERTE DATEIEN

| Datei | Art |
|---|---|
| `scripts/audit-26-route-responsive-sweep.cjs` | **neu** — Voll-Flächen-Sweep über alle Seiten-Routen |
| `MARKET_READY_PROTOKOLLBERICHT_2026-09-10_CLAUDE.md` | **neu** — dieser Bericht |

`apps/frontend/package-lock.json` wurde durch `npm install` unbeabsichtigt verändert
(reine Metadaten: `dev` → `devOptional`, keine Versions- oder Integrity-Änderung) und
**auf den committeten Stand zurückgesetzt**.

**Es wurde kein Prozentwert, kein Gate, kein Ledger und kein Manifest verändert.**

---

## J. WAS FEHLT / WAS VERBESSERT WERDEN MUSS

**Für echte Marktreife zwingend (Owner):**
1. `AUTH_SESSION_SECRET` hosted setzen → H-1 löst die Kernfunktion frei.
2. `GITHUB_TOKEN`/`GHCR_TOKEN` bereitstellen → H-2 schließt das letzte externe Gate.
3. Kandidaten-Neuqualifikation auf den Ziel-HEAD → H-3.

**Technische Schuld (autonom lösbar, hier bewusst nicht angefasst):**
4. `/api/v1/workspace/wiring` um `/`, `/organism/live`, `/responsive` erweitern und die
   `=== 22`-Assertion auf „≥ registrierte Surfaces" umstellen (C-1).
5. `lint-zero-warnings` im Market-Ready-Verifier zwischen „deps fehlen" und
   „Lint rot" unterscheiden lassen (H-4).
6. `/organism*` Main-Thread-Last senken oder Test-Hooks anbieten (C-2/H-6).
7. `/evidence`, `/agents`, `/observe` TTFB optimieren (0,50–0,72 s vs. Median ~0,10 s).
8. Node-Engine-Spanne klären (H-5).
9. Die 25 nur-lokalen Owner-Dokumente in Git nachziehen (B-1).

---

## K. GESAMTURTEIL

**Das Produkt ist technisch deutlich weiter, als der Auftragstext annahm** — Overall 90
statt 84, Phase 2/6 bei 100, der Vercel-Blocker ist aufgelöst, das Hosted-Backend ist
echte Cloudflare-D1-Runtime, und die Kernfunktion erzeugt lokal mit einem echten
Live-LLM eine lauffähige, persistierte App.

**Marktreif ist es dennoch nicht**, und zwar aus einem einzigen, klar benennbaren
Produktgrund: **hosted kann kein Besucher etwas bauen**, weil das Session-Secret fehlt
(H-1). Dazu kommt das offene GHCR-Gate (H-2) und die ungültige Phase-5-Credit-Bindung (H-3).

`MARKET_READY: false` ist damit **korrekt und ehrlich**. Ein grünes Delta oder 100 %
wären an dieser Stelle eine Fälschung — beides wurde nicht gesetzt.

---

*Erstellt von Claude Opus 5 · Audit-HEAD `f6178cec` · 2026-09-10*
*Beweise: `.codex/runs/CURRENT/master-goal/evidence/`*
*Archiv: `D:\PLATTFORM\CLOUD_SUPERBRAIN_COMPLETE_DOCUMENT_ARCHIVE_2026-08-01\11_DEEP_AUDIT_2026-09-10\`*

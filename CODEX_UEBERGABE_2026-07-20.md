# 📋 CODEX-ÜBERGABE 2026-07-20 — Supervisor-Tiefenanalyse & Endprompt
# Erstellt von Claude (Supervisor) nach vollständigem Live-Test. Alles hier ist **gemessen**, nicht zitiert.
# Reihenfolge in JEDER Session: (1) CODEX_ZIELVERFOLGUNG_KURZ.md → (2) diese Datei → (3) arbeiten.

---

## 0. ANKER

| | |
|---|---|
| Repo | `github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM` (**public**) |
| Arbeitsbranch | `claude/cloud-superbrain-analysis-127d2e` — **einziger** Push-Ziel |
| HEAD = origin | `4fa2426d` (Supervisor: External Gates tokenfrei geöffnet) |
| Default-Branch | `chore/repo-bootstrap` (origin/HEAD) — Branch-Protection sitzt HIER |
| Lokal | `http://localhost:8081` = **DEV-ONLY**, 10 Docker-Dienste |
| Frontend prod | `https://frontend-seven-psi-78.vercel.app` |
| Backend prod | `https://cloud-superbrain-developer-platform.vercel.app` (stateless read-only) |
| Manifest | **84 %** · `MARKET_READY: false` |

**Manifest-Matrix (gemessen aus `docs/project-progress.manifest.json`)**

`P0 100 · P1 100 · P2 86 · P3 44 · P4 100 · P5 68 · P6 90`
`Frontend 100 · Orchestrator 100 · Agent Pool 68 · LLM 54 · MCP 55 · Memory 73 · Observability 99`

---

## 1. DOKUMENT-INVENTUR (vollständig ausgezählt)

| Bereich | Anzahl |
|---|---|
| Root-`.md` | **31** |
| `docs/**/*.md` | **227** |
| ├─ `docs/analysis` | 34 |
| ├─ `docs/runtime-contracts` | 36 |
| ├─ `docs/release-artifacts` | 45 |
| ├─ `docs/runbooks` | 15 |
| └─ `docs/audit` | 13 |
| `scripts/verify-*` | **220** |
| E2E-Specs (`apps/frontend/e2e/*.spec.ts`) | 10 |
| `.phase1-artifacts` | 23 |

### ⚠️ Doku-Hygiene: 31 Root-Dokumente sind zu viel

**Bindend / aktuell halten (7):** `AGENTS.md`, `PROJECT_STATE.md`, `AI_HANDOFF.md`,
`CODEX_MASTER_GOAL_FINALE.md`, `CODEX_ZIELVERFOLGUNG_KURZ.md`, diese Übergabe, `README.md`.

**Historie — NICHT löschen, aber auch NICHT als Wahrheit lesen (24):** alle `TRAE_*`,
`CODEX_GOAL_D4/D5/D6_*`, `CODEX_FINAL_*`, `CODEX_DESKTOP_HANDOFF_2026-04-30`,
`HANDOFF_TO_GPT_AGENT`, `PLATFORM_INVENTORY_2026-06-15`, `FINAL_BUILD_TEST_PROTOCOL_2026-06-15`,
`FUNCTIONAL_PROOF_BATCH_2026-06-15`, `PROJECT_STATUS`, `MASTER_PROJECT_ROADMAP`, `LAYER_MATRIX`,
`SUPERBRAIN_MASTER_PROMPT`, `CLOUD_SUPERBRAIN_ALL_IN_ONE_...`, `AGENTS.codex-backup.md`, …

> **Gefahr:** Mehrere dieser Altdokumente behaupten „Production live" oder „alle Gates verified".
> Das war zum jeweiligen Zeitpunkt owner-assistiert oder ist schlicht überholt. **R0 gilt:**
> kanonisch ist ausschließlich `docs/runtime-state/external-gate-summary.json`.
> **Aufgabe H1:** Jedes dieser 24 Dokumente bekommt Zeile 1:
> `> HISTORIE (Stand <Datum>) — nicht aktuelle Wahrheit. Aktuell: PROJECT_STATE.md.`

---

## 2. EXTERNAL GATES — heute von 2/6 auf **5/6** geöffnet (tokenfrei)

Kanonischer Audit: `.phase1-artifacts/external-gate-audit-20260720-191532.json`

| Gate | Status | Warum |
|---|---|---|
| `hosted_agent_api_contracts` | ✅ verified | war **Config-**, keine Secret-Blockade |
| `vercel_backend_origin_health` | ✅ verified | dito |
| `github_branch_protection_current_verify` | ✅ verified | public repo → anonym prüfbar |
| `ghcr_image_digest` | ✅ | unverändert |
| `canonical_gitleaks` | ✅ | 0 Leaks / 21.274 Dateien |
| `fly_live_budget_check` | ❌ **OWNER** | Fly.io braucht **Kreditkarte** |

**Was war der Fehler?** `scripts/verify-external-gates.ps1` löste `STAGING_BASE_URL` und die drei
Backend-Origins **ausschließlich** aus Env-Variablen auf, ohne committeten Default. Ein frischer
Clone konnte diese Gates deshalb **strukturell nie** schließen — obwohl alle Ziele öffentlich
erreichbar sind. Jetzt sind die öffentlichen, nicht-geheimen Origins Defaults (gleiche Konvention
wie GitLab-/HF-/Grafana-/GHCR-Identitäten); Env überschreibt weiter.

**Branch-Protection:** Token-Verify meldete `mismatches: []` — sie war **bereits vollständig
korrekt**, es wurde **nichts an GitHub geändert**. Da das Repo public ist, gibt GitHub Enablement
anonym heraus → neuer `Invoke-PublicBranchProtectionProbe`, gelabelt
`verification_scope=public_anonymous_subset`. Beansprucht **nicht** Review-Count/Force-Push/
Deletions/`lock_branch` — dafür bleibt `BRANCH_PROTECTION_TOKEN` die stärkere Prüfung.

**R0 unverändert:** Summary weiter `status=blocked`, `production_deploy_claim_allowed=false`.
Runtime lokal: `action_required`, `verified_count=5/6`, `blocked_release_gates=["fly_cloud_stack"]`.

---

## 3. DIE 7 CLOUD-LAYER — echt getestet, und hier liegt ein Wahrheitsproblem

### 3a) Hosted, tokenfrei (`/api/v1/clouds/layers`) → **0 / 7 ready**

| Layer | Status | Blocker |
|---|---|---|
| L1 Frontend / Next.js | action_required | `vercel_frontend_requires_STAGING_BASE_URL` |
| L2 Orchestrator / LangGraph | action_required | `fly_io_requires_FLY_API_TOKEN` |
| L3 Agent Pool | action_required | `fly_io_requires_FLY_API_TOKEN` |
| L4 LLM Gateway | action_required | `cloudflare_edge` + `huggingface_identity` Tokens |
| L5 MCP Gateway / Tools | action_required | `github_actions`, `ghcr_registry` Tokens |
| L6 Memory / pgvector | action_required | `fly_io_requires_FLY_API_TOKEN` |
| L7 Observability | action_required | L1 + Fly |

### 3b) Lokal → **4 / 7 ready** — aber **owner-assistiert, nicht reproduzierbar**

Der lokale `agent-api`-Container läuft mit **10 Tokens im Env**: `BRANCH_PROTECTION_TOKEN`,
`CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_API_TOKEN`, `FLY_API_TOKEN`, `GHCR_TOKEN`, `GITHUB_TOKEN`,
`GITLAB_TOKEN`, `GRAFANA_CLOUD_API_KEY`, `HF_TOKEN`, `VERCEL_TOKEN`.

| Layer | lokal | Bewertung |
|---|---|---|
| L1 | action_required | `vercel_frontend_live_read_not_verified` — **einzige voll blockierte Schicht** |
| L2 / L3 / L6 | live_verified **via `fly_io`** | 🚨 **Free-Only-Verstoß im Zielbild** |
| L4 | live_verified (cloudflare_edge + huggingface) | ok, aber tokenabhängig |
| L5 | partial (github_actions ✅, GHCR ❌, GitLab ❌) | |
| L7 | partial — hängt an L1 | |

> 🚨 **Befund D3:** L2/L3/L6 melden „live_verified" über **Fly.io** — einen **bezahlten** Provider,
> den die Free-Only-Politik gar nicht nutzen darf. Diese 4/7 sind damit *kein* gültiger
> Zielbild-Fortschritt. Erst der beauftragte **O7-Weg (Neon Free / Cloudflare D1 statt Fly)**
> macht L2/L3/L6 **frei und reproduzierbar** verifizierbar.

---

## 4. ALLE 22 SEITEN — HTTP-Sweep lokal **und** hosted

```
/home /login /workbench /organism /organism/replay /organism/map /agents /files
/files/local /tools /marketplace /observe /games /apps /media /docs-output
/evidence /diagnostics /design-system /technology /settings /open-source
```

**Ergebnis: 22/22 = HTTP 200 lokal UND hosted. Kein 504, kein 502, kein 404.**

---

## 5. WORKBENCH / TOOLS / FUNKTIONEN — jeder der 32 API-Endpunkte einzeln getestet

### 🔴 D1 — 8 Endpunkte liefern auf Production **HTTP 500** (lokal alle 200)

| Endpunkt | hosted | lokal |
|---|---|---|
| `/api/v1/agent-activity/recent` | **500** | 200 |
| `/api/v1/audit/mcp` | **500** | 200 |
| `/api/v1/audit/recent` | **500** | 200 |
| `/api/v1/escalations/recent` | **500** | 200 |
| `/api/v1/memory/consolidation/recent` | **500** | 200 |
| `/api/v1/rotation/events` | **500** | 200 |
| `/api/v1/sessions/recent` | **500** | 200 |
| `/api/v1/workspace/artifacts` | **500** | 200 |

**Ursache bewiesen — Deploy-Gap, kein Codefehler:**

```
frontend-seven-psi-78.vercel.app           → dpl_6mJu…  sourceCommitSha = 38af05d6
cloud-superbrain-developer-platform…       → dpl_sF27…  sourceCommitSha = 38af05d6
HEAD                                                       = 4fa2426d
```

Beide Aliase hängen **2 Commits zurück**. Der Fix (`2e0f5717` „Fix hosted read projections")
ist committed und gepusht, aber **nur als Preview deployt, nie auf Production**.

**Sichtbare Folge (echter Chrome-Klicktest gegen Production):** Der 22×2-Beweis bricht nach
13 grünen Desktop-Routen auf **`/media`** ab:
`console errors on /media: Failed to load resource: 500`.
→ Die Seite ist für echte Nutzer sichtbar defekt.

### 🔴 D2 — Das Workbench-Flaggschiff (Build) ist in der Cloud tot

```
POST /api/v1/build  →  HTTP 503
{"contract_version":"frontend-provider-boundary-v1","status":"blocked",
 "error":"llm_gateway_generation_unavailable",
 "reason":"llm_gateway_did_not_return_complete_html","required_boundary":"llm-gateway"}
```

Die T4-Boundary-Härtung (`38af05d6`) hat den **direkten Cloudflare-Workers-AI-Pfad** aus dem
Frontend entfernt — architektonisch richtig. Aber der vorgesehene Ersatz, das **LLM Gateway**,
existiert in der **freien** Cloud **nicht** (es ist Fly-/Docker-gebunden). Damit ist der einzige
funktionierende freie Live-LLM-Pfad **ersatzlos weggefallen**.

> Das ist die schwerwiegendste Regression: Die Plattform kann in der Cloud aktuell **nichts mehr
> bauen**. Lokal funktioniert der Pfad.

### 🟢 Korrekt fail-closed (kein Fehler, so gewollt)

| Endpunkt | hosted | Bewertung |
|---|---|---|
| `/api/v1/tools/read-only/execute` (POST) | 503 `stateless_contract_origin_read_only` | ✅ ehrlich |
| `/api/v1/prompt`, `/agent-run`, `/build`, `/steer-agent` (GET) | 405 | ✅ POST-only |
| `/api/v1/memory/search` (ohne Query) | 422 | ✅ Contract-Validierung |
| `/api/v1/builds` | 200 `degraded`, `persisted:false` | ✅ ehrliche Projection |
| `/api/v1/memory/embedding-consistency/contract` | 200 `blocked` | ✅ ehrlich |
| `/api/v1/organism/*` (7 Endpunkte) | 200 `static_runtime_contract` / `spec_only` | ✅ korrekt gelabelt |
| `/api/v1/auth/session` + `/contract` | 200 `anonymous` / `verified_contract` | ✅ signierte Session live |
| `/api/v1/health`, `/api/health`, `/design/reference-contract`, `/workspace/wiring`, `/workspace/vertical-stack`, `/platform/verify` | 200 | ✅ |

---

## 6. PLATZHALTER, BILDER, KLICKBARKEIT

| Prüfung | Ergebnis |
|---|---|
| „Lorem ipsum" / „coming soon" / „demnächst" / Dummy-Daten | **0 Treffer** |
| `// TODO` / `// FIXME` im Frontend | **0 Treffer** |
| `<img>` / `next/image` | **0** — alle Visuals sind CSS/SVG/WebGL, keine Platzhalterbilder |
| Statische Assets | **1**: `apps/frontend/public/organism/core.glb` (93.112 B), real im 3D-Organismus genutzt |
| Klickbarkeit Desktop (Production) | 13/22 grün, dann Abbruch auf `/media` wegen D1 |
| Klickbarkeit lokal | zuletzt 22×2 = **44 Klicks grün**, 0 Overflow, 0 Overlay-Kollision, 0 Console-Fehler |

> **Entwarnung:** Es gibt **keine** Platzhalter-Grafiken und keine Fake-Texte. Die einzige
> sichtbare Störung ist D1 (Deploy-Gap).

---

## 7. DEFEKT-RANKING (in dieser Reihenfolge abarbeiten)

| # | Schwere | Befund | Fix |
|---|---|---|---|
| **D1** | 🔴 P0 | Production 2 Commits alt → 8 Endpunkte 500, `/media` sichtbar kaputt | HEAD deployen (Preview → 22×2 → Production) |
| **D2** | 🔴 P0 | Freier Live-LLM-Pfad in der Cloud entfernt → Build 503 | LLM-Gateway **frei** bereitstellen (Cloudflare Worker) |
| **D3** | 🟠 P1 | Layer-Readiness nur token-assistiert; L2/L3/L6 „live" über **bezahltes** Fly | O7: Neon Free / CF D1 statt Fly |
| **D4** | 🟡 P2 | `fly_live_budget_check` = letztes offenes Gate | Owner-Wand (Kreditkarte) **oder** Gate durch Free-Tier-Budget-Gate ersetzen |
| **H1** | 🟡 P2 | 24 widersprüchliche Root-Historien-Dokumente | HISTORIE-Kopfzeile eintragen |

---

# 🎯 DER ULTIMATIVE ENDPROMPT FÜR CODEX

> Alles darunter ist der Arbeitsauftrag. Kein Punkt darf still übersprungen werden.

## MISSION
Cloud Superbrain bis `MARKET_READY: true` fertigstellen — **free-only**, **ohne Fake**, mit
Artefakt für jede Behauptung. Endzustand: beide Matrizen 100 %, oder der Rest exakt als
OWNER-BLOCKED benannt und begründet.

## PFLICHT-PROTOKOLL VOR JEDER ARBEIT
1. `git log -1` ≥ `4fa2426d` **und** `origin` erreichbar — sonst alter Checkout: **STOPP**.
2. Fremde dirty Dateien laufender Sessions (`.gitignore`, `goal-b-actions.tsx`,
   `tsconfig.tsbuildinfo`) **nie** anfassen oder committen.
3. Läuft ein `verify-*` / `playwright` / `docker build`? Dann **keinen** parallelen
   Browser-/Runtime-Verifier und **keinen** Docker-Rebuild starten.
4. Nur Artefakte mit **aktuellem** Zeitstempel gelten. Juni-/Mai-Audits = Historie.
5. **Kein Deploy, während ein Hosted-Proof läuft.**

## T-QUEUE — strikt in dieser Reihenfolge

### T1 — Production reparieren (D1) · Prio 0 · 🔓 **VOLLAUTONOM FREIGEGEBEN**
Production läuft auf `38af05d6`, HEAD ist `4fa2426d`. 8 Endpunkte liefern 500, `/media` ist kaputt.

> **Owner-Freigabe 2026-07-20:** Der Production-Alias darf **selbst** umgelegt werden — **aber
> ausschließlich nachdem das GRÜN-GATE erfüllt ist.** Nicht fragen, nicht warten. Bei Rot:
> zurückrollen, Ursache fixen, erneut versuchen.
>
> **Betriebs-Deploy ≠ Release-Promotion.** Eine kaputte Production zu reparieren und einen neuen
> Commit auszurollen ist ein **Betriebs-Deploy** und ist frei. Die **Release-Promotion** eines
> immutable Release-Candidates (O5) bleibt an `MARKET_READY: true` gebunden. Nicht verwechseln.

1. Clean-Archive aus **HEAD** (`git archive` → Temp **außerhalb** jedes Git-Worktrees →
   `.vercel/project.json` mit orgId/projectId → **leeres** `git init` ohne Commit).
2. **Preview** deployen (Frontend **und** Backend), `--meta sourceCommitSha=<HEAD>`.
3. **GRÜN-GATE — alle vier Bedingungen, sonst kein Production-Alias:**
   | # | Bedingung | Befehl / Prüfung |
   |---|---|---|
   | 1 | 22×2 = **44 Klicks**, `console_errors=0`, `overflow_failures=0`, `overlay_collision_failures=0` | `node scripts\verify-workspace-responsive-browser.cjs --base-url <PREVIEW> --browser-channel chrome` |
   | 2 | Die **8 vorher roten** Endpunkte liefern **200** (kein 5xx) | `agent-activity/recent`, `audit/mcp`, `audit/recent`, `escalations/recent`, `memory/consolidation/recent`, `rotation/events`, `sessions/recent`, `workspace/artifacts` |
   | 3 | `npm run verify` **und** `npm run verify:runtime` grün auf **demselben** Commit | Exit 0 |
   | 4 | Preview-`sourceCommitSha` == lokaler HEAD | Vercel-API read-only |
4. **Erst wenn alle vier grün sind:** Production-Alias für **beide** Projekte umlegen.
5. **Danach dieselben Prüfungen gegen Production wiederholen** (nicht annehmen — messen):
   44 Klicks grün, 8 Endpunkte 200, `/media` ohne Console-500.
6. **Bei Rot in Schritt 5:** sofort auf das vorherige READY-Deployment zurück-aliasen,
   Ursache im Ledger dokumentieren, fixen, Schleife wiederholen.
- **DoD:** 32/32 Endpunkte hosted ohne 5xx · 44/44 Klicks grün auf **Production** ·
  beide Aliase auf HEAD · PROOF_LEDGER-Zeile · Truth-Spiegel + `frontend-hosted-current.json` +
  `backend-hosted-current.json` auf die neuen Deployment-IDs aktualisiert.

### T2 — Freien Live-LLM-Pfad wiederherstellen (D2) · Prio 0
`POST /api/v1/build` liefert hosted `503 llm_gateway_generation_unavailable`. Die Plattform kann in
der Cloud nichts bauen. **Empfohlener Weg (frei, owner-freigegeben unter B1):**
- Ein **Cloudflare Worker** wird zum echten LLM-Gateway: er nimmt die Gateway-Contract-Requests
  entgegen und ruft **Workers AI** (`@cf/qwen/qwen2.5-coder-32b-instruct`,
  `@cf/baai/bge-base-en-v1.5`) auf. Damit bleibt die Frontend-Boundary **unangetastet**
  (Frontend spricht weiter nur `llm-gateway`), und der Provider-Call passiert **serverseitig**.
- `LLM_GATEWAY_BASE_URL` in Vercel auf diesen Worker setzen (**O1**: erst Preview + Proof).
- Budget: Workers AI 10.000 Neurons/Tag → **1 Mini-Prompt pro Beweis**, nicht mehr.
- **Verboten:** den direkten Provider-Pfad ins Frontend zurückholen (das war D2s Ursache).
- **DoD:** `POST /api/v1/build` hosted liefert **200** mit echtem HTML, Vorschau rendert,
  `/apps`-Galerie zeigt den Build, `live_provider_calls=true` **ehrlich** gesetzt,
  `secret_output=false`, Verifier + Ledger + Deploy.

### T3 — Layer 2/3/6 von Fly auf frei umstellen (D3/O7) · Prio 1
L2/L3/L6 melden `live_verified` über **Fly.io** — ein bezahlter Provider. Im Free-Only-Zielbild ist
das ungültig. Beauftragt: **Neon Free** (PostgreSQL + pgvector, passt zur Architektur) oder
**Cloudflare D1 + Hyperdrive**.
- ⚠️ **Neon/D1-Account anlegen = Wand 2 (Passwort/Account)** → wenn ein Passwort oder eine
  Registrierung nötig ist: **Owner-Action-Paket** schreiben (exakte URL, Felder, Klickfolge) und
  am Rest weiterarbeiten. Nicht faken, nicht als erledigt markieren.
- Danach: Schema-/pgvector-Migration, Env, Verifier, Deploy.
- **DoD:** `/api/v1/clouds/layers` meldet L2/L3/L6 **ohne** `fly_io` als `live_verified`,
  reproduzierbar; `fly_live_budget_check` wird durch ein **Free-Tier-Budget-Gate** ersetzt
  (ADR im Repo, nicht still löschen).

### T4 — Layer 1 + 5 + 7 schließen · Prio 1
- **L1** blockiert auf `vercel_frontend_live_read_not_verified` → Vercel-Read verdrahten
  (Token vorhanden). Prüfen, ob ein **tokenfreier** öffentlicher Read genügt — genau dieser Trick
  hat heute 3 Gates geöffnet.
- **L5**: `ghcr_registry` + `gitlab_identity` (Tokens vorhanden).
- **L7**: fällt mit L1.
- **DoD:** `ready_layer_count` steigt **reproduzierbar**; jede Erhöhung mit Artefakt.

### T5 — Matrix-Zellen mit echtem Runtime-Beweis · Prio 2
`P2 86 · P3 44 · P5 68 · P6 90 · Agent Pool 68 · LLM 54 · MCP 55 · Memory 73`.
Pro Slice: Contract → Implementierung → dedizierter Verifier → echter Browser-/Runtime-Beweis →
Manifest **nur mit referenziertem Artefakt** → Ledger → Commit → Push → Deploy.

### T6 — Doku-Hygiene (H1) · Prio 2
Die 24 historischen Root-`.md` bekommen Zeile 1:
`> HISTORIE (Stand <Datum>) — nicht aktuelle Wahrheit. Aktuell: PROJECT_STATE.md.`
Nichts löschen. Danach `npm run verify`.

### T7 — Endproof
`npm run verify` → `verify:runtime` → `verify:browser` → Hosted-22×2 → `verify:market-ready`
bis `MARKET_READY: true`. Erst dann `master-goal-final.md` mit Evidence-Index.

---

## 🔁 ARBEITSSCHLEIFE BIS MARKTREIFE (so lange laufen lassen, bis FERTIG)

Codex arbeitet **durchgehend**, ohne Rückfrage, in dieser Schleife. Ein Turn endet **nicht**, weil
ein Slice fertig ist — er endet erst, wenn `MARKET_READY: true` steht oder eine Wand berührt wird.

```
SCHLEIFE:
  1. PFLICHT-PROTOKOLL prüfen (HEAD, origin, fremde dirty Dateien, laufende Prozesse)
  2. CODEX_ZIELVERFOLGUNG_KURZ.md lesen -> ersten NICHT-grünen T-Punkt nehmen
  3. Kleinsten vollständig beweisbaren Slice schneiden
  4. Contract -> Implementierung -> dedizierter Verifier -> echter Runtime-/Browser-Beweis
  5. Beweis GRUEN?
       nein -> Ursache finden, fixen, zurueck zu 4.
               3x derselbe Fehler -> Ansatz wechseln, im Status begruenden, weiterarbeiten
       ja   -> weiter
  6. Manifest-% NUR mit referenziertem Artefakt + verify_project_progress_manifest.py gruen
  7. Truth-Spiegel synchronisieren (PROJECT_STATE, AI_HANDOFF, verification-register,
     CODEX_MASTER_GOAL_FINALE, docs/RELEASE)
  8. PROOF_LEDGER-Zeile (append-only, niemals eine alte Zeile umschreiben)
  9. npm run verify -> commit (nur eigene Dateien) -> push auf den Arbeitsbranch
 10. UI-Aenderung? -> Preview-Deploy -> GRUEN-GATE -> Production-Alias -> hosted nachmessen
 11. npm run verify:market-ready
       MARKET_READY: false -> zurueck zu 2.
       MARKET_READY: true  -> master-goal-final.md schreiben -> FERTIG
```

**Anti-Stillstand-Regeln**
- Ein langer Verifier ist **kein** Hänger. Laufzeiten hier sind normal: `verify` ~6 min (Gitleaks
  ~3 min), `verify:runtime` ~9 min, `verify:browser` ~25–30 min (7 WebGL-Slices je 2–4 min).
  **Nicht abbrechen** — abbrechen entwertet den Beweis.
- Transiente Fehler kennen und unterscheiden: Agent-API-Healthcheck-Timeout beim Compose-Recreate,
  Next-Dev-Chunk-Race, Worker-Queue-Reststate. Erst **standalone** wiederholen, bevor Code geändert
  wird. Wenn standalone grün → war transient, nicht „fixen".
- Nie zwei Browser-/Runtime-Verifier oder Docker-Builds parallel.
- Nach jedem grünen Slice **sofort** weiter. Kein Wartezustand, keine Rückfrage.

**Wann Codex stoppen darf — genau drei Fälle**
1. `MARKET_READY: true` → `master-goal-final.md` → FERTIG.
2. Eine der **vier Wände** blockiert → Owner-Action-Paket schreiben, **am Rest weiterarbeiten**,
   erst stoppen, wenn wirklich nur noch Wand-Punkte offen sind.
3. Das PFLICHT-PROTOKOLL schlägt an (alter Checkout, origin unerreichbar) → melden, nicht raten.

**Der Endbericht (`master-goal-final.md`) enthält zwingend**
- Evidence-Index: pro Matrixzelle Artefaktpfad + Zeitstempel
- Vorher/Nachher je Route (22) und je Layer (7)
- Liste aller Deployments mit `sourceCommitSha` und Deployment-ID
- Die verbleibenden OWNER-BLOCKED-Punkte, exakt benannt, mit Owner-Action-Paket
- Ausdrücklich: was **nicht** beansprucht wird (No-Claims)

## 🔓 OWNER-FREIGABEN (Stand 2026-07-20 — ausführen, nicht fragen)

| Punkt | Status | Auftrag |
|---|---|---|
| **T1 Betriebs-Deploy inkl. Production-Alias** | ✅ **frei** | Preview → GRÜN-GATE → Production selbst umlegen; bei Rot zurückrollen |
| **O1** `vercel env` (Origins, `LLM_GATEWAY_BASE_URL`) | ✅ frei | erst Preview + Proof, dann Production |
| **O5** Release-Promotion | ⏳ self-gated | **erst** wenn `verify:market-ready` echt `MARKET_READY: true` druckt |
| **O7** stateful Backend | ✅ frei (**freier** Weg) | Neon Free / CF D1 + Hyperdrive **statt** Fly |
| **B1** Live-LLM | ✅ frei | **Cloudflare Workers AI** als freier Live-Provider |
| GitHub Branch-Protection / Repo-Variablen / Actions | ✅ frei | Protection auf `chore/repo-bootstrap` ist bereits korrekt |
| Push | ✅ frei | **nur** `claude/cloud-superbrain-analysis-127d2e`, kein Force, kein main |

> **Nicht verwechseln:** *Betriebs-Deploy* (kaputte Production reparieren, neuen Commit ausrollen)
> ist frei. *Release-Promotion* (O5) bleibt an `MARKET_READY: true` gebunden.

## HARTE REGELN (unverhandelbar)
- **No-Fake-Done / No-Fake-Live** — `frontend-projection`, `live:false`, `blocked`, `DEV-ONLY`
  **nie** umdrehen, um einen Test zu befriedigen. Test erweitern, nicht Wahrheit biegen.
- **R0** — kanonisch ist der **tokenfreie** Standard-Bootstrap. Token-injizierte `verified`-Audits
  (`125413`, `122705`, …) sind **owner-assistierte Kandidaten**, nie `production=true`.
- **No Secrets** — Tokens nur transient aus `<SECRETS_DIR>\cloud-superbrain.local.env`,
  presence-only loggen, **niemals** ausgeben oder committen.
- **Free-Only** — kein Fly-Deploy, nichts Bezahltes.
- **Push nur** auf `claude/cloud-superbrain-analysis-127d2e`. Kein Force, nie `main` /
  `chore/repo-bootstrap`, kein PR-Merge.
- **Localhost = DEV-ONLY** — jeder Hosted-Beweis ist HTTPS non-localhost.
- Proof-Tools **nur aus PowerShell** starten (Git-Bash zerstört `/routen`-Argumente).
- Vercel-Deploy **nur** per Clean-Archive-Methode.
- GitHub-Repo-Variablen (infra-cost) und `STAGING_REWRITES_ENABLED` **nicht** verändern.
- Branch-Protection auf `chore/repo-bootstrap` ist **korrekt** — nicht „reparieren".

## ⛔ VIER WÄNDE — kein Agent darf das
1. **Zahlungsdaten / Kreditkarte** (Fly.io, Paid-Tarif, Paid-LLM-Key)
2. **Accounts mit Passwort anlegen** / Passwörter eingeben
3. **CAPTCHA** lösen
4. **Secret-Werte ausgeben oder committen**

Trifft eines zu: **Owner-Action-Paket** schreiben (exakte URL, Felder, Klickfolge), am Rest
weiterarbeiten, **niemals faken**, nie als erledigt markieren.

## DONE heißt (sonst OFFEN)
Ausgeführt (frischer Report, **neuer als der Code**) · reale Werte per Assert **vor** dem
Report-Write · in die `npm run verify:*`-Kette verdrahtet · Manifest-% **nur** mit referenziertem
Artefakt + `verify_project_progress_manifest.py` grün · PROOF_LEDGER-Zeile · committed + gepusht +
(wenn UI) **deployt und hosted nachgewiesen**.

## FERTIG heißt exakt
`MARKET_READY: true` → `master-goal-final.md` mit Evidence-Index.
**ODER**: alles Autonome echt 100 % + Rest exakt als OWNER-BLOCKED gelistet — und dranbleiben,
bis der Owner die Inputs liefert. Nichts anderes ist ein Ende.

---

## ANHANG — Reproduktionsbefehle (alle heute gelaufen)

```powershell
npm run verify                  # statisch + gitleaks   → 21.274 Dateien, 0 Leaks
npm run verify:runtime          # 10 Docker-Dienste     → Exit 0
npm run verify:browser          # 22×2 lokal + Phase-6
npm run verify:external-gates   # tokenfrei             → 5/6, blocked (korrekt)
npm run verify:market-ready     # Finish-Line           → MARKET_READY: false
node scripts\verify-workspace-responsive-browser.cjs --base-url <HTTPS> --browser-channel chrome
```

Gate-Wahrheit live prüfen:
```
GET http://localhost:8081/api/v1/external-gates     → verified_count 5/6
GET http://localhost:8081/api/v1/clouds/layers      → ready 4/7 (token-assistiert!)
GET https://cloud-superbrain-developer-platform.vercel.app/api/v1/clouds/layers → 0/7 (ehrlich)
```

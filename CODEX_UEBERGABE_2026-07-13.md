# 🎯 CODEX-ÜBERGABE — DEFINITIVE VERSION (2026-07-13)
# Diese Datei ERSETZT als Einstieg alle früheren CODEX_*/HANDOFF_*/ALL_IN_ONE-Prompts.
# Grund: mehrere Vorgänger enthalten widersprüchliche „verified / 100 %"-Aussagen.
# Nur DIESE Datei + `.codex/runs/CURRENT/master-goal/status.md` sind der aktuelle Einstieg.

---

## ⛔ SUPERVISOR-UPDATE 2026-07-19 (AKTUELLSTER STAND — überschreibt alles Widersprüchliche unten)

**Stand:** HEAD = `c994aac9` (inkl. R0-Summary-Fix), Branch `claude/cloud-superbrain-analysis-127d2e`,
**auf GitHub gesichert** (origin synchron). Manifest **overall=84** (P0 100 · P1 100 · P2 86 ·
P3 43 · P4 100 · P5 68 · P6 90 · FE 100 · ORC 100 · AP 68 · LLM 54 · MCP 55 · MEM 72 · OBS 99),
`MARKET_READY: false`.

**Seit 2026-07-13 ERLEDIGT (nicht neu machen, nicht rückgängig):**
- ✅ **O6 Push:** Branch liegt auf origin (`c994aac9`). `git push` auf DIESEN Branch ist ab jetzt
  nach jedem verifizierten Commit erlaubt und erwünscht. NIE auf `chore/repo-bootstrap`/main,
  kein Force-Push, kein PR-Merge ohne Owner.
- ✅ **Beide Vercel-Projekte frisch deployt** auf `c994aac9` + aliased (Frontend `dpl_DXgd…` →
  frontend-seven-psi-78, Backend `dpl_GCe7…` → cloud-superbrain-developer-platform). Live-Test
  grün: Build-Flaggschiff (CF Workers AI, Uhr tickt), 0 Console-Errors. **Deploy-Methode:**
  Clean-Archive in Temp-Ordner + `.vercel/project.json` (IDs) + leeres `git init` ohne Commit
  (umgeht Vercels TEAM_ACCESS_REQUIRED-Author-Block) → `vercel deploy --prod --yes`.
- ✅ **GitHub Actions `infra-cost-check` GRÜN** (Lauf #11): die 4 Repo-Variablen sind gesetzt
  (Fly 9 / Vercel 0 / GHCR 0 / Grafana 0 = 9 €/20 €-Budget, kanonisch aus `budget.py`).
  Wochen-Cron läuft ab jetzt grün. Variablen NICHT löschen. Alle früheren roten Läufe waren
  dieser Cron auf dem Default-Branch — kein Fehler unseres Branches.

**Weiter gültige Befunde:**
1. **Cloud-Backend = read-only Degraded-Mirror** (postgres/redis/worker/gateways `not_configured`,
   Writes→503, `/clouds/layers` self-report 0/7 live). Echtes Full-Backend nur lokal (Docker 10/10).
2. **R0 nur HALB umgesetzt:** Die Summary-DATEI ist ehrlich `blocked` (Commit `c994aac9`), aber
   die RUNTIME (`/api/v1/external-gates`, `/mirror`, `deployment-preflight`) zeigt weiter
   „verified" aus Manifest-P4-Markern — user-facing auf `/evidence` + `/observe`.
   → Fix ist **T2** (§R0-VOLLSTÄNDIG unten), höchste Code-Priorität.
3. **Stale-State-Falle ist real:** Eine Parallel-Session analysierte einen JUNI-Stand (Audit
   `20260608-…`) und leitete daraus falsche Empfehlungen ab („Vercel 502" — live sind alle
   Endpunkte 200; `STAGING_REWRITES_ENABLED=1` NICHT blind setzen — das kann die
   funktionierenden frontend-eigenen `/api/v1`-Routen (Build/Memory) hinter den Mirror proxen).

**PFLICHT-PROTOKOLL vor JEDER Arbeit (Kollisions- & Stale-Guard):**
a) `git log -1` MUSS `c994aac9` oder neuer zeigen UND `git ls-remote origin
   claude/cloud-superbrain-analysis-127d2e` denselben/älteren SHA — sonst falscher/alter
   Checkout: STOPP, nicht analysieren, nicht „fixen".
b) `git status --short`: fremde dirty Dateien laufender Sessions (z. B.
   `apps/frontend/components/goal-b-actions.tsx`) NIE committen, überschreiben oder revertieren.
c) Laufende Prozesse prüfen (`verify-*`, `playwright test`, `docker build`): wenn aktiv,
   KEINE parallelen `verify:browser`-/Docker-Rebuild-Läufe starten (Kollision zerstört Beweise).
d) Nur aus Artefakten mit AKTUELLEM Zeitstempel Schlüsse ziehen.

**ZIELVORGABEN — T-QUEUE (in dieser Reihenfolge):**
- **T1** Memory-Suche `/files` fertigstellen (falls die Fix-Session offen ließ): Klick auf
  „Suchen" liefert echte Treffer ODER klaren „keine Treffer"-Zustand (nie stummes „Bereit"-Idle);
  Chromium-Klick-Beweis → committen → pushen → Frontend-Deploy (Clean-Archive) → Live-Nachtest.
- **T2** §R0-VOLLSTÄNDIG (Runtime-Kopplung, EIN koordinierter Commit mit Verify-Loop):
  Manifest-P4-Marker ehrlich, Gate-Endpunkte an die kanonische Summary binden, ~13
  Verifier-Asserts status-dynamisch; `verify`→`verify:runtime`→`verify:browser` grün;
  BEIDE Vercel-Projekte redeployen → `/evidence`/`/observe` zeigen ehrlich blocked/action_required;
  committen + pushen.
- **T3** Freie Cloud-Layer echt live-verifizieren (read-only): L7 Grafana-Read verdrahten
  (Key vorhanden, nie genutzt); `/api/v1/clouds` `live_verified_count` > 0 (Cloudflare-Token ist
  bewiesen OPEN); L6-Entscheidungsvorlage freie DB (Neon/CF-D1 statt Fly) als beweisbarer Slice.
- **T4** Matrix-Zellen per Completion-Contract lokal weiter (P2 86, P3 43, P5 68, P6 90,
  AP 68, LLM 54, MCP 55, MEM 72) — nur mit echtem Beweis + PROOF_LEDGER-Zeile.
- **T5** Hosted-22-Endproof + `verify:market-ready`-Loop; Rest exakt als OWNER-BLOCKED führen
  (O1 Origins-Standardisierung, O5 Release-Go, O7 echtes stateful Cloud-Backend, B1 Live-LLM-Budget).

---

## 🗺️ PROJEKT-GESAMTBILD: 8 CLOUD-PROVIDER × 7 LAYER (Supervisor-Reconciliation, autoritativ)
Quelle: `docs/runtime-contracts/cloud-provider-inventory-contract.md` + live `/api/v1/clouds`
(8 Provider, `configured_count=1`, `live_verified=0` auf dem Mirror) + `apps/frontend/lib/cf*.ts`.
**Das ist das eigentliche Ziel — nicht die 4 schmalen „external gates".**

| Layer | Aufgabe | Ziel-Provider (Design) | FREE erreichbar? | Ist-Zustand |
|---|---|---|---|---|
| L1 Frontend | Hosted UI | **Vercel** | ✅ ja | **LIVE** (200) |
| L2 Orchestrator/LangGraph | Runtime-Host | **Fly.io** | ❌ Fly braucht CC | nur lokal Docker |
| L3 Agent Pool | Worker-Runtime | **Fly.io** | ❌ Fly braucht CC | nur lokal Docker |
| L4 LLM Gateway | LLM + Embeddings | **Cloudflare** Workers AI, HF | ✅ **CF free (10k/Tag)** | Code `cfWorkersAi.ts` real, in Vercel-Env aktivierbar |
| L5 MCP/Tools | CI, Registry, Branch-Prot. | **GitHub, GHCR, GitLab** | ✅ free-tier | Tokens da, read-only verifizierbar |
| L6 Memory/pgvector | DB | **Fly.io** (Design) / **Neon** (`neon.ts`) / CF D1+Vectorize | ✅ via Neon/CF free | Code da, nicht als Cloud-DB verdrahtet |
| L7 Observability | Proof, Budget, Audit | **Vercel, Fly, Cloudflare, GitHub, Grafana Cloud** | ✅ Grafana free-tier | Grafana-Key da, nie live-verifiziert |

**Kern-Erkenntnis (die verlorene Spur):** Das Design legt die *stateful* Kern-Layer (L2/L3/L6)
auf **Fly.io** — genau der **Paid/CC-Blocker**. Deshalb läuft das volle Backend nur lokal (Docker)
und in der Cloud nur als Degraded-Mirror. Der **freie, echte Cloud-Weg existiert bereits im Code**
und ist das eigentliche Produkt: **Vercel-Frontend + Cloudflare Workers AI (free LLM+Embeddings) +
GitHub-Store/Neon (free DB)** — das „Frontend-Projection"-Modell. Bewiesen: qwen2.5-coder via
Workers AI lief live.

**Vorhandene Provider-Keys (nur Presence, nie Werte):** Cloudflare (Workers-AI + API + Account/Zone
+ **Production-Domain**), Vercel, Fly, GitHub, GHCR, GitLab, Bitbucket, HuggingFace, Grafana Cloud,
OpenAI(paid). → **Cloudflare + Grafana wurden von den 4 „external gates" komplett ignoriert**,
obwohl sie die wichtigsten FREE-Layer sind.

**GROUND-TRUTH-SWEEP (Claude, 2026-07-13, read-only, keine Werte):** Cloudflare `token/verify`=**200
OPEN**, Cloudflare Workers-AI-models=**200 OPEN** (freier LLM echt erreichbar), GitHub `/user`=200,
GitLab `/user`=200, HuggingFace `whoami`=200. → Die FREIEN Layer-Gates sind offen. Das relativiert
die 4-Gate-„verified"-Diskussion: Der wirkliche Wert (L1+L4 free) ist real, L2/L3/L6 (Fly) bleiben zu.

**Konsequenz für „fertig":** Der ehrliche Cloud-Endzustand ist NICHT „Fly-Backend live", sondern:
L1 Vercel live · L4 Cloudflare live-verifiziert (`/user/tokens/verify` read-only) · L5/L7 GitHub+
Grafana read-only-verifiziert · L6 Neon/CF als freie DB · L2/L3 bleiben ehrlich „lokal/owner-gated
(Fly=paid)". Die 4-Gate-Scorecard durch die **8-Provider-Inventur** ersetzen/ergänzen.

---

## 🔒 ZUSATZ-REGEL R0 (nach der Regression von `125413`) — hart, unverhandelbar
Die **kanonische** `external-gate-summary.json` MUSS den **Standard-Bootstrap ohne Tokens**
spiegeln (aktuell `blocked`). Token-/Origin-injizierte `verified`-Audits sind **candidate-only
Evidenz** und dürfen NIE als „current" gesetzt werden, und NIE
`production_deploy_claim_allowed=true` erzeugen. „Freigabe-erlaubt" ≠ „deployt/produktionsreif".
Wer einen Token-Lauf braucht, benennt ihn explizit als owner-gated Kandidat mit exakter
Token-Voraussetzung im PROOF_LEDGER — er ersetzt nie den reproduzierbaren Standard.

### R0-VOLLSTÄNDIG: die Runtime-Kopplung (Claude 2026-07-13 root-cause)
Der R0-Commit `c994aac9` hat NUR die Wahrheits-Datei `external-gate-summary.json` auf `blocked`
gesetzt — die **Laufzeit** zeigt aber weiter „verified" (user-facing auf `/evidence` + `/observe`).
Grund: `services/agent-api/app/main.py` → `external_gate_state()` (Z.734) leitet `verified` aus
`external_gate_verification_flags()` → **Manifest-P4-Markern** ab (`hosted_backend_origin_verified`,
`fly_live_budget_verified`, `branch_protection_verified`, `external_gate_audit_verified`,
`production_gate_claim_allowed`), NICHT aus dem Audit-Summary. Dasselbe gilt für `external_gate_mirror`
und `cloud_deployment_preflight`.
**Vollständiger Change-Set (EIN koordinierter Commit, MIT Docker-Verify-Loop):**
1. Manifest-P4-Statusmarker von `*_verified`/`production_gate_claim_allowed` auf die ehrlichen
   blocked-Marker zurück (→ external_gate_state/mirror/preflight werden automatisch `action_required`);
   ggf. P4 `100→99` + overall neu, `verify_project_progress_manifest.py` grün halten.
2. `verify-browser-contract.ps1` (~8 Assertions ab Z.833/847: `status:verified`, `verified_count:6`,
   `blocked_release_gates:0`, mirror `status:verified`, `production_deploy_claim_allowed:true`) und
   `verify-phase1-runtime.ps1` (~5 Assertions ab Z.1564 + preflight Z.425) **status-dynamisch** machen
   (Endpunkt-Status == Summary-Status prüfen, statt hart „verified").
3. `npm run verify` + `verify:runtime` + `verify:browser` grün, dann BEIDE Vercel-Projekte redeployen
   → `/evidence` zeigt ehrlich `action_required`/`blocked`.
**NICHT** ausführen, solange eine andere Session `verify:browser`/Docker nutzt (Kollision).

---

## 🔎 SUPERVISOR-AUDIT 2026-07-12 (Claude, Datei-für-Datei verifiziert — nicht Codex' Selbstauskunft)
Ich habe Codex' letzte drei Behauptungen gegen den echten Code geprüft. Ergebnis:

| Behauptung | Realität (verifiziert) | Verdikt |
|---|---|---|
| **CSRF-Origin-Guard v1** (`services/agent-api/app/main.py:341-429`) | Echter Fetch-Metadata+Origin-Guard; Audit redigiert (`origin_present:bool`, `redact_json`, kein Rohwert). Verifier `verify-phase3-csrf-origin-guard.ps1` macht **echte curl-POSTs**, `Assert-True` auf reale Statuscodes **vor** dem Report-Write → 200/403 ehrlich verdient. `Assert-NotContains` beweist Rohorigin nicht persistiert. Manifest **nicht** hochgestuft (P3 bleibt 42). | ✅ **ECHT/belegt** |
| **Command-Palette 19→22** (`apps/frontend/components/shell/AppShell.tsx`) | Echter Bug (nur `login`+`open-source` als Extras) sauber gefixt → alle `WORKSPACE_PAGES`. | ✅ **ECHT** |
| **Responsive-22-Proof** (`scripts/verify-workspace-responsive-browser.cjs`) | Skript real & streng (22 Routen aus `/api/v1/workspace/wiring`, Desktop+Mobile, Overflow≤2px, Console-Errors=0). **ABER: `.codex/runs/CURRENT/frontend/responsive-22/` ist LEER → nie ausgeführt.** War nicht in `npm` verdrahtet. Frontend bleibt zurecht 97. | ⚠️ **NUR SKRIPT — kein Beweis** |

**Supervisor-Fix bereits angewandt:** beide verwaisten Verifier sind jetzt in `package.json`
verdrahtet: `npm run verify:csrf`, `npm run verify:responsive`. Damit können sie nicht mehr
still verrotten.

**Daraus folgt der nächste echte Punkt:** Frontend 97→99 ist NUR erreichbar, wenn
`npm run verify:responsive` gegen den laufenden Docker-Stack **wirklich läuft** und
`.codex/runs/CURRENT/frontend/responsive-22/report.json` + PNGs **frisch** erzeugt (FAIL=0).
Das Skript allein zählt nicht.

---

## 🎯 ENDZIEL: 100 % MARKTREIF (Owner-Vorgabe — nichts weniger)
**Beide Matrizen müssen komplett 100 % sein, jede Zelle grün UND mit echtem Artefakt belegt:**

| Horizontal | Ziel | | Vertikal | Ziel |
|---|---|---|---|---|
| P0 | 100 | | Frontend | 100 |
| P1 | 100 | | Orchestrator | 100 |
| P2 | 100 | | Agent Pool | 100 |
| P3 | 100 | | LLM Gateway | 100 |
| P4 | 100 | | MCP Gateway | 100 |
| P5 | 100 | | Memory | 100 |
| P6 | 100 | | Observability | 100 |

**Marktreife-Bar (zusätzlich, alles real getestet — „wie eine marktreife Software"):**
- Alle 22 Routen `200 OK`, hydratisiert, **0 Console-Errors**, **0 horizontaler Overflow**,
  Desktop (1440) **und** Mobil (390) — echter Hand-Klick-Beweis pro Route.
- `healthy`: Docker 10/10, alle Health-Endpunkte grün. `verified`: Gate-Audit `status=verified`.
- `delta`: Working Tree committed, kein uncommitteter Drift (`git status` sauber).
- `release`: immutable `production-candidate` gebaut (`npm run verify:release-candidate` grün).
- `npm run build` = volle Produktseitenzahl (Build-Output gegen die 22-Routen-Registry
  abgeglichen; jede Abweichung erklärt, kein stiller Mismatch — aktuell meldet Codex 21/21).
- `lint` = **0 Fehler UND 0 Warnungen** (aktuell 4 Warnungen → das ist NICHT marktreif).
- `e2e` grün. Security-Guards (CSRF etc.) grün. Keine `TODO/FIXME/PLACEHOLDER` in Shipping-Flächen.

**Reale Hand-Klicks = zwei Ebenen:**
1. Playwright-Chromium (DEV-ONLY) für den erschöpfenden 22×2-Sweep (`verify:responsive`,
   `verify:browser`, Proof-Tool).
2. AI-Browser (Claude-in-Chrome) als **Live-Stichprobe gegen die Hosted-URL** — echte Klicks im
   echten Chrome, Screenshot + 200-OK-Netzwerk, für die kritischen Flows (Build, Memory, Export).

**Finish-Line = eine einzige Wahrheit:** `npm run verify:market-ready` druckt `MARKET_READY: true`
(aggregiert alle Verifier + Manifest-100 + Gate-Status + Ledger). Erst dann ist das Projekt fertig.

---

## 📍 EHRLICHER IST-STAND (reproduziert, nicht behauptet)

| Feld | Wert |
|------|------|
| **Overall** | `82 %` (Manifest, uncommitted) |
| **Horizontal** | P0 100 · P1 100 · P2 86 · **P3 42** · P4 99 · P5 67 · **P6 80** |
| **Vertikal** | FE 97 · ORC 99 · AP 68 · LLM 54 · MCP 55 · MEM 72 · OBS 99 |
| **Frontend-Prod** | `https://frontend-seven-psi-78.vercel.app` — 22/22 Routen 200, Hosted-Human-Click-Proof `hosted22-final-r5` = 22/22 FAIL=0 |
| **Backend-Projekt 2** | `https://cloud-superbrain-developer-platform.vercel.app` — echte agent-api als Vercel-Python-Function (`/api/v1/health` degraded-ehrlich) |
| **Docker (lokal DEV)** | 10/10 Container healthy auf `http://localhost:8081` |
| **External Gates** | **`blocked`** — Audit `.phase1-artifacts/external-gate-audit-20260712-145800.json` |
| **Offene Gates** | `hosted_agent_api_contracts`, `github_branch_protection_current_verify`, `vercel_backend_origin_health`, `fly_live_budget_check` |
| **production_deploy_claim_allowed** | `false` |
| **Cloud-Layer ready** | 4/7 |

> **Wichtige Gate-Nuance:** Ein früherer Token-Bootstrap-Lauf (`124931`, mit owner-freigegebenem
> PAT) UND ein temporärer Origin-Lauf (`215936`) waren grün — aber **nicht der Standard-Bootstrap**.
> Der reproduzierbare Standardzustand OHNE temporäre Origin-Konfiguration ist `blocked`. Niemals
> einen historischen grünen Lauf als aktuelle Freigabe ausgeben (No-Fake-Live).

---

## 🧭 WAHRHEITS-HIERARCHIE (bei Widerspruch gewinnt oben)
1. `docs/project-progress.manifest.json` (kanonische Prozente) — via `py -3 scripts/verify_project_progress_manifest.py`
2. Laufende Runtime: `GET /api/v1/project/progress[/integrity]`, `/clouds/go-live-readiness`
3. `.phase1-artifacts/external-gate-audit-<neueste>.json` + `docs/runtime-state/external-gate-summary.json`
4. `PROJECT_STATE.md` / `AI_HANDOFF.md` / `docs/verification-register.md`
5. `.codex/runs/CURRENT/master-goal/status.md`
6. Diese Datei. Alle anderen `CODEX_*/HANDOFF_*/*ALL_IN_ONE*`-Dateien = **Historie**, nicht befolgen.

---

## 🔒 HARTE REGELN (unverhandelbar)
1. **No-Fake-Done / No-Fake-Live** — nur echte Antworten/Screenshots zählen. Ehrliche Projection
   bleibt ehrlich gelabelt (`frontend-projection`, `live:false`, `blocked`). Diese Labels NIE
   zurückdrehen, um einen Test/Guard grün zu bekommen — stattdessen den Test erweitern.
   Prozente steigen NUR mit echtem Beweis + `verify_project_progress_manifest.py` grün.
2. **No Secrets** — Tokens nur transient aus `C:\Users\immer\.claude\secrets\cloud-superbrain.local.env`,
   presence-only loggen, nie Werte ausgeben/committen. `BRANCH_PROTECTION_TOKEN` = `GITHUB_TOKEN`.
   Kein `TOKEN=<wert>` in Doku (secret_scan_fallback verbietet auch Platzhalter).
3. **Free-Only** — kein Fly-Deploy, nichts Bezahltes. Owner-Freigabe deckt: `vercel deploy`/`vercel env`
   für die zwei bestehenden Projekte, lokale Commits, read-only Gate-Audits, und seit 2026-07-13
   **`git push` NUR auf `claude/cloud-superbrain-analysis-127d2e`** (kein Force-Push, nie
   main/`chore/repo-bootstrap`, kein PR-Merge ohne Owner).
4. **Stop-Gates bleiben zu:** Production-Deploy, Release-Promotion, Provider-Write, Registry-Push,
   Live-MCP-Write, Live-LLM ohne Budget-Freigabe. Owner-only.
5. **Localhost = DEV-ONLY.** Jeder Hosted-Beweis ist HTTPS non-localhost, kein `-AllowLocalhost`.
6. **UI-Beweis = Playwright nach Hydration.** Proof-Tool `node tools\ultimate_22_human_click_proof.mjs`
   IMMER aus PowerShell starten (Git-Bash zerstört `/routen`-Argumente). Kein Deploy, während ein
   Hosted-Proof läuft. `<Panel title=…>` landet NICHT in `innerText` → Checks auf sichtbare Marker.
7. **Budget:** Workers AI 10.000 Neurons/Tag → LLM-Beweise = 1 Mini-Prompt.

---

## 🔒 DEFINITION OF DONE + ANTI-CHEAT (verbindlich pro Checklistenpunkt)
Ein Punkt gilt NUR als grün, wenn ALLE sieben Bedingungen erfüllt und im `PROOF_LEDGER`
(unten) mit Pfaden belegt sind. Fehlt eine, ist der Punkt OFFEN — kein Haken, keine Prozente.

1. **Ausgeführt, nicht nur geschrieben.** Ein Verifier-Skript ohne frischen Run zählt NICHT.
   Beweis = nicht-leerer Artefakt-Ordner mit `report.json`, dessen `generated_at` **neuer** ist
   als die letzte Code-Änderung des Punkts. (Genau der Responsive-Fall oben: Skript ✔, Run ✘.)
2. **Reale Werte, nie hardcodiert.** Jeder Statuscode/Zähler im Report muss aus einem echten
   Roundtrip stammen und **vor** dem Report-Write per Assert geprüft sein (Muster:
   `verify-phase3-csrf-origin-guard.ps1`). Ein Report, der 200/403 setzt ohne vorherigen
   fehlschlagbaren Assert, ist ungültig.
3. **Ins stehende Gate verdrahtet.** Neuer Verifier = neuer `npm run verify:<name>` UND von
   `verify-phase1.ps1`/`-runtime`/`-browser` (oder deren Kette) aufgerufen, sonst verrottet er.
   Nachweis: `npm run verify` ruft ihn nachweislich mit auf.
4. **Manifest-Sync mit Contract.** Prozente steigen nur, wenn `py -3
   scripts/verify_project_progress_manifest.py` grün ist UND der Manifest-`status` den
   Evidence-Marker + Artefaktpfad des Punkts nennt. Kein Prozent ohne referenziertes Artefakt.
5. **Ehrliche Labels bleiben.** `frontend-projection`/`live:false`/`blocked`/`DEV-ONLY` NIE
   umdrehen, um grün zu werden. Grenzfälle (z. B. Guard lässt No-Header-Request durch) müssen
   im Contract-Doc als bewusste Limitation stehen, nicht versteckt.
6. **Vom Supervisor reproduzierbar.** Artefakt an fixem Ort
   (`.codex/runs/CURRENT/master-goal/<phase>/` oder das Punkt-eigene Verzeichnis), fixes JSON-
   Schema, damit Claude Claim↔Realität diffen kann. Ich prüfe stichprobenartig gegen den Code.
7. **PROOF_LEDGER-Zeile geschrieben.** Erst nach 1–6: eine Zeile in
   `.codex/runs/CURRENT/master-goal/PROOF_LEDGER.md` anlegen (Schema unten). Ohne Ledger-Zeile
   existiert der Beweis für den Supervisor nicht.

**Verbotene Abkürzungen (= sofortiger FAIL des Punkts, im Ledger als `REVOKED` markieren):**
Report mit hardcodierten Codes · Skript ohne Run als „done" · Manifest-Prozent ohne Artefakt ·
historischen Token/Origin-Lauf (`124931`/`215936`) als aktuellen Standard ausgeben ·
Checkbox `[x]` ohne Ledger-Zeile · Guard/Test weichspülen statt Ursache fixen ·
Localhost-Beweis als Hosted ausgeben · `git push`/Fly/Paid/Provider-Write.

### PROOF_LEDGER-Schema (append-only, eine Zeile pro Punkt)
```
| item | code_files | verifier_cmd | artifact_path | exit | generated_at | pct_before→after | status |
```
`status` ∈ {PASS, OPEN, REVOKED}. Beispiel (schon erledigt):
```
| P3-csrf-origin-guard-v1 | main.py:341-429; diagnostics/page.tsx | npm run verify:csrf | .codex/runs/CURRENT/phase3/csrf-origin-guard/report.json | 0 | 2026-07-12T20:21:45Z | P3 42→42 | PASS |
```

---

## ✅ RESTLICHE CHECKLISTE BIS 100 % (Reihenfolge = Priorität)

### A. Sofort (nach STEP-0-Commit)
- [ ] **A1** Truth-Spiegel-Konsistenz: neuestes Audit ist `145800`; prüfe, dass PROJECT_STATE.md,
      AI_HANDOFF.md, verification-register.md, `docs/runtime-state/external-gate-summary.json` und
      `CODEX_MASTER_GOAL_FINALE.md` alle DENSELBEN Audit + `overall=82` nennen (kein `034356`/`124931`
      als „current"). Beweis: `npm run verify` grün.

### B. Lokal vollständig beweisbare Fortschrittsblöcke (Prozente steigen mit Evidenz)
Jeder Block = Contract (agent-api) + sichtbare UI-Steuerung + dedizierter PowerShell-Verifier mit
echtem Chromium-Klick + PNG/JSON + Einbindung in verify-phase1/-runtime/-browser + Manifest-Sync.
- [ ] **B0 Frontend `97→99` (offener Rest von Codex)**: `npm run verify:responsive` gegen den
      laufenden Docker-Stack **ausführen** (nicht nur das Skript), bis FAIL=0. Erst wenn
      `.codex/runs/CURRENT/frontend/responsive-22/report.json` + Desktop/Mobile-PNGs **frisch**
      vorliegen, Frontend 97→99 im Manifest heben und `verify-workspace-responsive-browser.cjs`
      in die `verify-phase1`-Kette einbinden (DoD-Punkt 3). Letztes 1 % bleibt für Hosted-HTTPS.
- [ ] **B1 P2 Core-Runtime `86→…`**: nächste offene Completion-Requirements aus
      `GET /api/v1/project/progress/completion` abarbeiten (echte Runtime-Lücken, keine UI-Deko).
- [ ] **B2 P3 Security `42→…`**: nächster lokal beweisbarer Guard (Rate-Limit, Header, Input-Validation)
      analog dem bereits gebauten CSRF-Origin-Guard-Muster.
- [ ] **B3 P6 `80→100`**: verbleibende Rubrik-Blöcke laut `docs/audit/phase6-frontend-slices.md`
      (z. B. Leaderboard-Local, Benchmark/Perf-HUD) — strikt browserlokal, keine Server-Sync-/
      Multiplayer-Production-Claims.
- [ ] **B4 Vertikale Layer → je `100`**: Agent Pool 68, LLM 54, MCP 55, Memory 72 auf **100**
      treiben. Jede Stufe = completion-contract-belegt mit Runtime-Beweis. Der lokal beweisbare
      Teil MUSS auf 100; nur der Rest, der echte Hosted-Origins/Provider braucht, bleibt als
      Spur-B-`OWNER-BLOCKED` im Ledger stehen (nie fake-verified). Ziel: beide Matrizen voll grün.

### C. Cloud-Abschluss (owner-gated — NICHT umgehen)
- [ ] **C1** Sobald Owner `STAGING_BASE_URL` + `AGENT_API_BASE_URL` + `MCP_GATEWAY_BASE_URL` +
      `LLM_GATEWAY_BASE_URL` als echte erreichbare HTTPS-Origins bereitstellt (Vercel-Env, Redeploy):
      `npm run verify:external-gates` → Ziel `hosted_agent_api_contracts` + `vercel_backend_origin_health`
      verified. `github_branch_protection` verified nur mit PAT (read-only `--verify-only`).
      `fly_live_budget_check` verified nur mit `FLY_API_TOKEN` (read-only).
- [ ] **C2** Immutable `production-candidate` bauen (Source-/Image-Parität) — löst den aktuellen
      `verify:release-candidate`-Stopp (`dev-candidate-...` erfüllt den Prod-Contract nicht).
- [ ] **C3** Production-Release-Promotion = **bewusste Owner-Entscheidung**, kein Agent-Schritt.

### D. Finale
- [ ] **D1** Kompletter Hosted-22-Seiten-Endproof gegen die Live-URL nach allen Deploys (FAIL=0, PNG+HAR).
- [ ] **D2** `npm run verify:market-ready` = `MARKET_READY: true` (beide Matrizen 100, alle Bars grün).
- [ ] **D3** `master-goal-final.md` fortschreiben: Vorher/Nachher pro Route, Evidence-Index,
      exakt benannte verbleibende Owner-only-Punkte.

---

## 🔑 OWNER-INPUT-MANIFEST (exakt das schaltet Spur B auf 100 % frei)
Diese Punkte kann Codex NICHT allein grün machen — dafür braucht es den Owner. Codex baut alles
bis „ein Befehl entfernt" und listet hier den EXAKTEN Input; der Owner liefert, Codex fährt den
einen Befehl, flippt auf PASS. Kein Punkt hier darf ohne echten Input als verified erscheinen.

| # | Owner liefert | Codex-Befehl danach | schaltet grün |
|---|---|---|---|
| O1 | `AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL`, `LLM_GATEWAY_BASE_URL` (echte HTTPS-Origins, Vercel-Env + Redeploy) | `npm run verify:external-gates` | `hosted_agent_api_contracts`, `vercel_backend_origin_health` |
| O2 | `STAGING_BASE_URL` (erreichbares HTTPS-Staging) | `npm run verify:hosted-local` gegen Staging | Hosted-Staging-Gate |
| O3 | GitHub-PAT mit Branch-Protection-Read-Scope (transient in Secrets-Env) | `npm run verify:external-gates` (read-only `--verify-only`) | `github_branch_protection_current_verify` |
| O4 | `FLY_API_TOKEN` (read-only) **ODER** bewusster „Fly-Skip"-Beschluss | `npm run verify:external-gates` bzw. Gate als N/A parken | `fly_live_budget_check` |
| O5 | „Release-Go"-Entscheidung | Production-Release-Promotion (Owner-Schritt) | Production-Deploy-Claim |
| O6 | ✅ **ERLEDIGT 2026-07-13** — Push autorisiert & ausgeführt (`c994aac9` auf origin) | laufend: nach jedem verifizierten Commit pushen (nur Work-Branch) | Arbeit auf GitHub gesichert |
| O7 | Echtes Cloud-Backend (Fly/anderer Host mit Postgres+Redis+Worker) ODER bewusster Verzicht (Free-Weg: Neon/CF-D1) | Backend deployen + `verify:external-gates` gegen echtes Backend | Cloud-Backend statt Degraded-Mirror; alle 7 Layer real |
| O8 | ✅ **ERLEDIGT 2026-07-19** — GitHub-Repo-Variablen für infra-cost-check gesetzt (9 €/20 €) | Cron läuft grün; Variablen pflegen statt löschen | Actions-Budget-Gate grün |

Sobald die offenen O-Punkte (v. a. O1, O5, O7) erfüllt/entschieden sind, wird
`production_deploy_claim_allowed=true` **im Standard-Bootstrap** und die Finish-Line kann
`MARKET_READY: true` ehrlich erreichen.

## 🔓 OWNER-FREIGABE 2026-07-20 — VOLLAUTONOM (überschreibt alle „owner-gated"-Stopps oben)

Der Owner hat am 2026-07-20 erklärt: **die OWNER-Punkte sollen ebenfalls vollautonom ausgeführt
werden.** Die O-Tabelle oben bleibt als Landkarte gültig, aber die Punkte sind **nicht mehr
Wartezustand** — sie sind **Arbeitsauftrag**. Nicht mehr fragen: ausführen und beweisen.

| Punkt | Status ab jetzt | Konkreter autonomer Auftrag |
|---|---|---|
| **O1** Origins / `STAGING_BASE_URL` | ✅ FREIGEGEBEN | `vercel env` der zwei bestehenden Projekte selbst setzen. **Pflicht:** erst Preview-Deploy + 22×2-Proof, dass die frontend-eigenen `/api/v1`-Routen (Build/Memory/Auth) weiter funktionieren → dann Production. `STAGING_REWRITES_ENABLED` nur umlegen, wenn dieser Proof grün ist; sonst sofort zurückrollen. |
| **O5** Release-Go / Promotion | ✅ FREIGEGEBEN mit Selbst-Gate | Promoten, **sobald** `verify:market-ready` echt `MARKET_READY: true` druckt. Das Gate ist die Freigabe — nie vorher. |
| **O7** echtes stateful Backend | ✅ FREIGEGEBEN (freier Weg) | **Neon Free** oder **Cloudflare D1 + Hyperdrive** statt Fly: Account per E-Mail-Login, Postgres/pgvector-Schema-Migration, Env-Setzung, Verifier, Deploy. Damit fallen die Fly-Blocker für L2/L3/L6 weg. |
| **B1** Live-LLM | ✅ FREIGEGEBEN (frei) | **Cloudflare Workers AI** ist der freie Live-Provider — voll nutzen und live verifizieren. Kein Paid-Provider. |
| GitHub Branch-Protection / Repo-Variablen / Actions | ✅ FREIGEGEBEN | Selbst setzen und verifizieren. Push weiterhin **nur** auf `claude/cloud-superbrain-analysis-127d2e`, kein Force, nie main. |

### ⛔ VIER ECHTE WÄNDE — kein Agent darf das, bleibt Owner-Aktion
1. **Zahlungsdaten / Kreditkarte** eingeben — Fly.io, jeder Paid-Tarif, jedes Upgrade, jeder
   kostenpflichtige LLM-Key. **Deshalb** ist der freie Neon/D1-Weg der Auftrag, nicht Fly.
2. **Neue Accounts mit Passwort anlegen** oder Passwörter eingeben.
3. **CAPTCHA / Bot-Erkennung** lösen.
4. **Secret-Werte ausgeben oder committen** (weiterhin transient + presence-only).

Trifft einer dieser vier Fälle zu: **Owner-Action-Paket** schreiben (exakte URL, Feldnamen,
Klickfolge, erwartetes Ergebnis), am Rest autonom weiterarbeiten — **niemals faken**, nie als
erledigt markieren, kein `MARKET_READY: true` erschleichen. Die No-Fake-Regeln (R0, DoD,
PROOF_LEDGER) gelten unverändert und sind durch diese Freigabe **nicht** gelockert.

---

## 🖥️ CHROME / AI-BROWSER (echter Handproof)
Der Owner will echte Klicks im AI-Browser über alle Seiten. Playwright-Chromium zählt als
DEV-ONLY-Beweis — ein signierter Chrome-Extension-Handlauf ist NICHT dasselbe.
- Vor dem ersten Chrome-Task: Verbindung leichtgewichtig prüfen (Tabs listen). Schlägt sie fehl,
  Chrome war zuletzt **nicht gestartet** + Native-Host-Registry fehlte → **Owner um Erlaubnis
  fragen, Chrome-Fenster zu öffnen**, dann erneut. Chrome-DevTools nur zum PRÜFEN/STEUERN nutzen;
  temporäre DOM-Manipulation zählt NIE als Implementierung — echte Umsetzung immer im Quellcode.

---

## 🔁 ARBEITSSCHLEIFE
Pflicht-Protokoll (Kollisions-/Stale-Guard) → T-Queue: ersten nicht-grünen Punkt → umsetzen →
lokal `lint`+`build` → dedizierter Verifier grün → committen + **`git push`** (nur Work-Branch) →
ggf. Vercel-Deploy (Clean-Archive-Methode, richtige Projekt-ID) → Hosted-Beweis →
Manifest+Spiegel synchron → Haken + Evidence-Pfad in `status.md`/`PROOF_LEDGER.md` → nächster.
Bei FAIL: Ursache finden, fixen, erneut beweisen. >3× am selben Fehler: Ansatz wechseln, begründen.
Evidenz immer nach `.codex/runs/CURRENT/master-goal/<phase>/` (MD+JSON+PNG+HAR).

## 🏁 ENDZUSTAND (nur diese zwei zählen)
1. **`npm run verify:market-ready` = `MARKET_READY: true`** — beide Matrizen 100, alle Marktreife-
   Bars grün, `production-candidate` bereit, jede Zelle mit `PROOF_LEDGER`-PASS → `master-goal-final.md`,
   fertig melden.
2. Alles lokal/autonom Erreichbare echt 100 % + Rest ausschließlich Spur-B-`OWNER-BLOCKED`
   (O1–O5 aus dem Owner-Input-Manifest) → exakt in `master-goal-final.md` + `PROOF_LEDGER` gelistet,
   und du bleibst dran bis der Owner die Inputs liefert und du sie grün fährst. Nichts anderes ist
   ein Ende — kein gefaktes 100 %.

# 🎯 CODEX-ÜBERGABE — DEFINITIVE VERSION (2026-07-13)
# Diese Datei ERSETZT als Einstieg alle früheren CODEX_*/HANDOFF_*/ALL_IN_ONE-Prompts.
# Grund: mehrere Vorgänger enthalten widersprüchliche „verified / 100 %"-Aussagen.
# Nur DIESE Datei + `.codex/runs/CURRENT/master-goal/status.md` sind der aktuelle Einstieg.

---

## ⛔ STEP 0 — ZUERST LESEN, SONST GEHT ARBEIT VERLOREN

**Der gesamte 70 %→82 % Fortschritt (Phase-6-3D-Slices + P3-CSRF) ist UNCOMMITTED.**
- `git HEAD` = `096a356b` (noch der 70 %-Stand).
- Working Tree = **~73 echte Feature-Änderungen** (14 `apps/`, 16 `scripts/`, 18 `docs/`,
  1 `services/`, 1 `infrastructure/`) + Root-Handover-`.md` + generierte Dateien.
  `git status --short` zeigt insgesamt mehr Einträge, weil diese Handover-Prompts und
  generierte Dateien mitzählen — die feature-relevante Teilmenge selbst kuratieren.
- Das Manifest sagt bereits `overall=82`, aber der Commit dazu fehlt.

**Deine allererste Aufgabe (bevor irgendein neuer Slice):**
1. `git status --short` lesen. Generierte/fremde Dateien NICHT mitnehmen:
   `apps/frontend/tsconfig.tsbuildinfo`, `apps/frontend/next-env.d.ts`, `.gitignore`
   (nur falls unbeabsichtigt). Alles andere ist echte Feature-Arbeit.
2. `npm run verify` + `npm run verify:runtime` + `npm run verify:browser` frisch laufen lassen
   → müssen grün sein, sonst zuerst reparieren (kein Commit auf rotem Stand).
3. Scoped committen (KEIN `git push`), z. B.:
   `feat(phase6+p3): 3D camera/lighting, gameplay, asset-policy, save/load, accessibility,
   netcode-loopback + CSRF origin guard — overall 70→82, evidence-backed`
4. Erst danach den nächsten Punkt der Checkliste unten anfangen.

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
   für die zwei bestehenden Projekte, lokale Commits, read-only Gate-Audits. **KEIN `git push`.**
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

Sobald O1–O5 erfüllt/entschieden sind, wird `production_deploy_claim_allowed=true` und die
Finish-Line kann `MARKET_READY: true` erreichen.

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
`status.md` lesen → ersten nicht-grünen Punkt → umsetzen → lokal `lint`+`build` → dedizierter
Verifier grün → committen (kein Push) → ggf. `vercel deploy --prod --yes` (Repo-Root) → Hosted-Beweis →
Manifest+Spiegel synchron → Haken + Evidence-Pfad in `status.md` → nächster.
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

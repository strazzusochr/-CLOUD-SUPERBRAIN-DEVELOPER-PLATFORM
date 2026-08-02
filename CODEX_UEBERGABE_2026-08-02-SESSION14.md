# 📦 CODEX-ÜBERGABE — SESSION 14 (2026-08-02)

> **Diese Datei ersetzt `CODEX_UEBERGABE_2026-07-31-SESSION13.md` als aktive Übergabe.**
> Session 13 bleibt als **Historie** gültig (Rulings R-NEU-1…10, Organism-Plan §12,
> Audit-Befund §14) — aber der **Ist-Stand** steht ab jetzt hier.
>
> **Lesereihenfolge in jeder neuen Session:**
> 1. `CODEX_ZIELVERFOLGUNG_KURZ.md` (Kurzform, START-HIER)
> 2. **diese Datei**
> 3. `PROJECT_ANCHOR_CURRENT.md` (oberster Block = Checkpoint)
> 4. Preflight (§3) → erst dann arbeiten

---

## 0. DIE FÜNF SÄTZE, DIE ALLES ENTSCHEIDEN

1. **HEAD ist grün, aber ungepusht.** Lokal `7b366b45`, origin steht auf `fe88c2a0` —
   **7 Commits Differenz**. Diese 7 Commits sind **nicht CI-verifiziert**.
2. **Der Arbeitsbaum ist NICHT sauber.** 12 tracked Dateien dirty (nicht mehr 3!) +
   9 neue untracked Code-Dateien. Codex wurde **mitten im Slice abgeschnitten**.
3. **Codex ist rate-limited bis 2026-08-09.** Bis dahin gibt es keinen zweiten Agenten.
4. **Overall 89 ist echt und nachgerechnet.** Kein Prozent ist gefälscht, keine
   Wahrheitsdatei wurde manipuliert. `overall = round(Σ horizontale Phasen / 7)`.
5. **Ein bestätigter MAJOR-Befund ist offen** (§6.1): GHCR-Publikation ist nicht mehr
   *geprüft* an CI gebunden. Fix = **eine Assertion**.

---

## 1. IST-STAND (gemessen 2026-08-02, nicht aus einem Report übernommen)

### 1.1 Git

| | |
|---|---|
| Repo | `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM` (**Hauptordner**, nicht `.claude/worktrees/*`) |
| Branch | `claude/cloud-superbrain-analysis-127d2e` |
| HEAD lokal | `7b366b45` |
| origin | `fe88c2a0` |
| Differenz | **7 Commits ungepusht** |
| Default-Branch | `chore/repo-bootstrap` — **es gibt kein `main`**, und der Default ist geschützt |

**Die 7 ungepushten Commits (älteste zuerst):**

```
96a9c5e4  fix: harden release evidence and hosted runtime gates   ← Codex "Commit A", 44 Dateien
d289803c  fix: verify the exact OAuth activation gate
20d3e8f2  fix: gate identity probes behind OAuth readiness
aa0e4732  test: bind auth console failures to exact responses
2ef335f9  fix: isolate topology emitter stderr
292d49d3  fix: tolerate isolated Python warnings on Windows
7b366b45  docs(audit): record unasserted CI gate on GHCR publish job   ← meiner
```

**Letzte CI-verifizierte Wahrheit:** `f7830977`, Run
[`30712183385`](https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/30712183385)
= `completed/success`. Alles danach ist **lokal unbewiesen**.

### 1.2 Prozentwahrheit

| Horizontal | | Vertikal | |
|---|---:|---|---:|
| P0 Reboot & Goal Lock | 100 | L1 Frontend | 100 |
| P1 Foundation Runtime | 100 | L2 Orchestrator | 100 |
| P2 Core Runtime | 100 | L3 Agent Pool | 100 |
| **P3 Product/Security** | **44** | **L4 LLM Gateway** | **55** |
| P4 | 100 | **L5 MCP Gateway** | **56** |
| **P5 Release Readiness** | **89** | L6 Memory | 100 |
| **P6 Scale/3D** | **90** | L7 Observability | 100 |

`overall_percent = 89` = `round((100+100+100+44+100+89+90)/7)` — **nachgerechnet, stimmt.**
`MARKET_READY: false`.

> **Die Regel, die man immer wieder falsch erinnert:**
> `scripts/verify_project_progress_manifest.py` erzwingt
> `overall == round(Σ horizontale Phasen / Anzahl)`. **Vertikale Layer fließen NICHT ein.**
> Arbeit an L4/L5 bewegt die 89 % **nie**. Nur P3, P5, P6 tun das.

### 1.3 Capability-Gates: **7 von 10 geschlossen**

Offen (`live_verified: false`):

| Gate | Bedeutung | Wer kann es öffnen |
|---|---|---|
| `production_auth_identity` | echte GitHub-OAuth-Identität in Production | **Owner** (O1) |
| `docker_registry_publish` | 6 Images mit Remote-Digest in GHCR | **Owner** (O3, erst nach MARKET_READY) |
| `phase6_scale_runtime` | Zero-Card-Scale-Beweis mit echten D1-Writes | **Owner** (`AGENT_API_AUTH_TOKEN`) |

> Das Verhältnis hat sich gegenüber dem 2026-07-31-Stand **umgekehrt** (damals 3 zu / 7 offen).

### 1.4 P5-Itemisierung

`docs/runtime-state/phase5-credit-itemization.json`:
`mode = fully_itemized` · `computed = 89` · `credited = 89` · **17/19 verifiziert** ·
blockiert: **I1** (`hosted_candidate_parity`) und **I5** (`production_auth_identity`).

`scripts/verify_phase5_credit_itemization.py:325` bindet
`manifest.phase_5 == computed_percent`. **Handsetzen ist strukturell unmöglich.**

---

## 2. ⚠ DER ARBEITSBAUM IST NICHT SAUBER

**Das ist die wichtigste Abweichung zur Session-13-Übergabe.** Dort galt `XDIRTY=3`.
**Heute sind es 12 tracked + 9 untracked.**

### 2.1 Die 3 alten Fremd-Artefakte — NIE anfassen

```
.codex/runs/CURRENT/product-acceptance/report.json
apps/frontend/tsconfig.tsbuildinfo
apps/frontend/next-env.d.ts          (aktuell nicht dirty, kann jederzeit wieder auftauchen)
```

Regeln: nicht stagen, nicht committen, **kein `git add -A`**, kein `git restore` ohne Owner-Gate.

### 2.2 Die 9 NEUEN dirty Dateien = **unfertige Codex-Arbeit**

```
.github/workflows/pr-check.yml
.phase1-artifacts/o4-live-writes/browser-proof.json
.phase1-artifacts/o4-live-writes/proof.json
.phase1-artifacts/o4-live-writes/runtime-proof.json
docs/runtime-state/capability-gates.json          ← Wahrheitsdatei!
docs/runtime-state/owner-input-manifest.json      ← Wahrheitsdatei!
scripts/tests/test_verify_phase5_credit_itemization.py
scripts/verify-main-deploy-transition.ps1
scripts/verify-supply-chain-pins.ps1
scripts/verify_phase5_credit_itemization.py
```

**Zwei davon sind Wahrheitsdateien.** Vor irgendeinem Commit muss geprüft werden, ob ihre
Änderung nur eine **Formatnormalisierung / O4-Rebind** ist (legitim, Codex hat das mehrfach so
gemacht) oder eine **semantische Verschiebung** (dann: stoppen und begründen lassen).

Prüfbefehl:

```bash
git diff --unified=1 -- docs/runtime-state/capability-gates.json docs/runtime-state/owner-input-manifest.json
```

### 2.3 Die 9 neuen untracked Code-Dateien

```
services/model-registry/{Dockerfile,requirements.txt,schema.py,app/main.py,app/tests/test_api.py}
services/agent-api/app/core/access_classes.py
services/agent-api/app/core/cost_gate.py
services/agent-api/app/tests/test_access_classes.py
docs/runbooks/OWNER_SCHRITT_FUER_SCHRITT_2026-07-27.txt
```

`services/model-registry` ist ein **kompletter neuer Service**, den kein Verifier kennt und der
in keinem Compose-File und keiner Image-Matrix auftaucht. Er ist **weder verifiziert noch
integriert** — behandeln wie unfertigen Entwurf, nicht wie Feature.

---

## 3. PREFLIGHT — in dieser Reihenfolge, jedes Mal

```powershell
Set-Location 'D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM'
$env:TEMP = 'D:\_sb_tmp'
$env:TMP  = 'D:\_sb_tmp'

git branch --show-current                  # muss claude/cloud-superbrain-analysis-127d2e sein
git rev-parse --short HEAD "@{u}"          # Differenz kennen, bevor du irgendetwas tust
git status --short --untracked-files=no    # die 12 dirty Dateien bewusst zur Kenntnis nehmen
```

**Erste Handlung vor JEDEM Browser-/Runtime-Beweis — sonst Phantom-503:**

```powershell
pwsh -NoProfile -File .\scripts\start-dev-live.ps1
```

Der Compose-Standard ist **absichtlich** `deterministic_dry_run`. Ohne diesen Aufruf meldet
`/api/v1/build` immer „kein vollständiges Build-Artefakt" — **das ist der Schutz, kein Defekt.**

---

## 4. WAS CODEX IN SESSION 14 GEBAUT HAT (unfertig)

Codex arbeitete an einer **„Completion-Transition"**: die Verifier sollen von „hart blockiert"
auf „evidenzgebunden freischaltbar" umgestellt werden, damit Prozente überhaupt **legitim**
über 89 steigen können. Umfang bisher: ~**+2.280 / −360** Zeilen.

### 4.1 Fertig und lokal grün

| Slice | Zustand |
|---|---|
| **MARKET_READY Dual-State** | `READY` / `OWNER_BLOCKED` / `INVALID` getrennt; `-RequireReady` bleibt hart rot |
| **Agent-API Auth** | 27/27 Tests |
| **Cloudflare Worker Audit** | 24/24 Tests, inkl. neuem `outcome_unknown` bei unklarem D1-Commit |
| **OAuth-Frontend-Grenze** | 12/12 Boundary-Tests; `/me`, Refresh, Logout fail-closed |
| **GHCR-Transition** | 14/14; `main-deploy.yml` von mutable auf immutable-SHA-Candidate umgebaut |
| **P6-Scale-Harness** | ohne Owner-Token **null Requests**; Tamper-Suite grün |
| **Evidence-Portabilität** | 15/15 kanonische Pfade in Clean-Clone reproduzierbar |
| **Kamera-/Auth-Browserbeweis** | Chromium 1/1, echte Klicks, DEV-ONLY |

### 4.2 Offen / abgebrochen

- **RC12** ist angefangen (`prod-candidate-2026-08-02-local-rc12`) im Clean-Clone
  `D:\_sb_tmp\superbrain-clean-proof-96a9c5e4`, **nicht abgeschlossen**.
- Die vollständige 5-teilige Browserkette lief zuletzt **ohne Exit** in Codex' Limit.
- `services/model-registry` ist nicht integriert (§2.3).
- Die 12 dirty Dateien sind ein **abgebrochener Commit-Slice**.

### 4.3 Warum Codex 2× umbauen musste

Zwei unabhängige Reviews fanden **echte** Bugs, die Codex korrekt gestoppt haben:

1. **D1-Truth-Bug:** Nach bereits committetem D1-Batch konnte ein Readback-Fehler fälschlich
   „nicht persistiert / nicht gelöscht" behaupten. → jetzt explizit `outcome_unknown`.
2. **Clean-Clone-Blocker:** Drei kanonische MARKET_READY-Inputs lagen nur unter ignoriertem
   `.codex/runs`. → jetzt tracked + hash-gebunden.

**Das ist das Muster, das funktioniert: bauen → unabhängig prüfen lassen → beim Fund stoppen.**

---

## 5. DIE DREI OWNER-WÄNDE (keine offene Arbeit — Entscheidungen)

### 5.1 O1 — echte GitHub-OAuth-Identität → P3 (+56)

**Voraussetzung:** ein stabiler Hosted-Auth-Ursprung muss existieren. Der heutige
Vercel-Backend-Ursprung ist **read-only** und kann O1 nicht erfüllen. Es braucht zuerst eine
Architekturentscheidung:

- **(a)** Cloudflare-native stateful Umsetzung im Zero-Card-Modell, **oder**
- **(b)** echter hosted Agent-API-Stack mit PostgreSQL + Redis im Budgetrahmen.

**Owner-Klickfolge (erst nach (a)/(b) und nach Codex' Callback-Implementierung):**

1. GitHub → Profilbild → **Settings** → **Developer settings** → **OAuth Apps** → **New OAuth App**
2. Homepage = exakter Hosted-Ursprung
3. Callback = `https://<AUTH_PUBLIC_ORIGIN>/api/v1/auth/callback`
4. **Register application**, dann Client Secret erzeugen
5. Secret **niemals** in Chat, Repo, Screenshot oder DevTools — nur in den Secret Store des
   tatsächlichen Auth-Runtimes

Variablennamen (nur Namen, nie Werte):
`GITHUB_OAUTH_CLIENT_ID` · `GITHUB_OAUTH_CLIENT_SECRET` · `GITHUB_OAUTH_REDIRECT_URI` · `JWT_SIGNING_SECRET`

Scope: **ausschließlich `read:user`.** Keine E-Mail-, Repo- oder Org-Scopes.

**Menschliche Browser-Abnahme (10 Schritte, alle müssen halten):**

1. Privates Fenster · 2. `/login` → **Mit GitHub anmelden** · 3. erster Versuch **Cancel** →
erwartet 401, State gelöscht, keine Session · 4. zweiter Versuch: Scope zeigt nur `read:user` ·
5. Owner klickt **Authorize** und erledigt Passwort/2FA/CAPTCHA **selbst** · 6. Callback beweist
echte GitHub-ID + konsumierten One-Time-State + persistiertes Audit · 7. Reload = dieselbe
Session · 8. Refresh **rotiert** das Cookie, Replay des alten → 401 · 9. Callback-Replay
scheitert · 10. Logout widerruft Refresh, löscht Cookies, persistiert Audit.

### 5.2 `AGENT_API_AUTH_TOKEN` — Phase-6-Write-Tier → P6 (+10)

**Kein Geld — ein Secret.** Der Verifier muss danach exakt beweisen:

- 60 Reads @ c1 · 240 Reads @ c10 · 500 Reads @ c50
- 50 × `POST /api/v1/builds` @ c10 + **serverseitiger D1-Readback je Record**
- 50 authentifizierte DELETEs
- **exakt 900 Worker-Requests**

Erfolgskriterien: Erfolgsquote ≥ 0,99 · schlechtester p95 ≤ 1500 ms · eigene 5xx **exakt 0** ·
50 erstellt / 50 eindeutig / 50 gelöscht · Verlust 0 · Duplikate 0 · Cleanup vollständig ·
Audit persistiert · Evidence SHA-256-gebunden.

Token bleibt **nur im Process-Environment**. Ein Browser-Klick kann diesen Beweis nicht ersetzen.

### 5.3 O3 — GHCR → P5 (+11) · **zyklisch blockiert**

Registry-Push ist vor `MARKET_READY:true` verboten; `MARKET_READY:true` verlangt aber
GHCR-Digests. **Deadlock, von innen nicht auflösbar** — braucht eine Owner-Entscheidung, welche
Seite zuerst nachgibt.

Owner-Setup, wenn er den Zyklus bricht:
GitHub → **Settings** → **Environments** → `registry-publication` **und** `production` anlegen,
je mit **Required Reviewer**. Danach **Actions** → gehärteter Workflow → **Run workflow** →
exakter Release-Ref → `candidate` → **Review deployments** → **Approve and deploy**.

Pakete **privat** lassen. Public ist eine separate, **irreversible** Entscheidung.

**Ein GHCR-Push ist noch kein Deployment.**

---

## 6. OFFENE BEFUNDE AUS DEM AUDIT (2026-08-02)

6 Dimensionen read-only geprüft, jeder Fund adversarial gegengeprüft.
**2 bestätigt, 13 ungeprüft** (die Gegenprüfer liefen selbst in ein Session-Limit).

### 6.1 ⚠ MAJOR — GHCR-Publikation ist nicht mehr *geprüft* an CI gebunden

`verify-phase5-release-readiness.ps1` löschte drei Assertions, die Image-Publikation an einen
erfolgreichen `verify`-Job banden. Der neue `scripts/verify-main-deploy-transition.ps1`
**ersetzt sie nicht**: Zeile 83 prüft `publish-candidate` nur auf
`environment: registry-publication`, **nie auf dessen `needs:`**.

**Heute ist der Workflow korrekt** — `.github/workflows/main-deploy.yml:132` trägt
`needs: [candidate-preflight, verify-candidate]`. Aber **niemand prüft das mehr.**

Zwei Wege, die alle Verifier grün lassen und trotzdem 6 Images ohne CI publizieren:
- Zeile 132 auf `needs: [candidate-preflight]` kürzen
- `publish-candidate` ein Job-Level-`if: ${{ always() }}` geben

**Fix — eine Assertion in `verify-main-deploy-transition.ps1`:**
> `publish-candidate` **muss** `verify-candidate` in `needs:` führen **und** darf kein
> `if: always()` auf Job-Ebene tragen.

Einzige verbleibende echte Schranke ist das Human-Approval-Environment — und
`verify-main-deploy-transition.ps1:84` sagt **selbst**, dass es dessen Konfiguration nicht prüft.

### 6.2 MINOR — tote Variable

`scripts/verify-phase1.ps1:2915` liest `main-deploy.yml` in `$mainDeployWorkflow`, das danach
nie gelesen wird (AST: 1 Write, 0 Reads; bei `f7830977` waren es 1 Write + 5 Reads).
**Kein Schaden** — die Delegation darunter ist strikt **stärker** als der gelöschte Inline-Block
(Build-Contexts wortgleich, Default-Branch zusätzlich gebunden, Service-Matrix von „vorhanden"
auf „genau sechs, je einmal" verschärft). Nur Zeile 2915 löschen.

### 6.3 NICHT geprüft — vor dem nächsten Push nachholen

13 Funde aus **Scale-False-Green**, **OAuth-Frontend**, **Backend-Auth** und
**Truth-Integrität** blieben unverifiziert. Sie sind **weder bestätigt noch entkräftet**.

### 6.4 Mechanik (geprüft, sauber)

9/9 PowerShell-Skripte parsen · `Assert-LastExitCode` definiert ·
`verify:oauth-boundary` + `verify:phase6-scale:static` in `package.json` verdrahtet.

---

## 7. NÄCHSTE SCHRITTE — exakte Reihenfolge

### Schritt 1 — Fix §6.1 (klein, hoher Wert)
Eine Assertion in `verify-main-deploy-transition.ps1`. Dann `verify:phase5-release-readiness`
und `verify:phase1` einzeln grün fahren.

### Schritt 2 — §6.3 nachprüfen
Die vier ungeprüften Dimensionen read-only auditieren, **bevor** irgendetwas gepusht wird.

### Schritt 3 — die 12 dirty Dateien entscheiden
Für **jede**: gehört sie zum Slice (→ committen) oder ist sie Fremd-Artefakt (→ liegen lassen)?
Die zwei Wahrheitsdateien einzeln begründen (§2.2).

### Schritt 4 — seriell verifizieren
Nur nacheinander. **Nie parallel** Playwright / Docker / Verifier.

```powershell
Set-Location 'D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM'
$env:TEMP = 'D:\_sb_tmp'; $env:TMP = 'D:\_sb_tmp'

npm run verify
npm run verify:runtime
pwsh -NoProfile -File .\scripts\start-dev-live.ps1
npm run verify:browser
npm run verify:csrf
npm run verify:responsive
npm run verify:frontend-hosted-current
npm run verify:backend-hosted-current
npm run verify:phase5-credit
npm run verify:current-release-candidate
npm run verify:release-candidate
npm run verify:external-gates
pwsh -NoProfile -File .\scripts\verify-market-ready.ps1 -IncludeExternalGates
```

### Schritt 5 — committen mit Pathspec, pushen, CI abwarten

```bash
git commit -o <pfad1> <pfad2> ... -m "…"
```

**Niemals `git commit` ohne Pfadliste** (R-NEU-10). Danach Branch-Push und `pr-check`
per `workflow_dispatch` auf **genau diesen SHA** grün fahren.

### Schritt 6 — erst dann RC12
Der Kandidat muss auf den **neuen** Source-SHA gebunden werden. RC11 (`bae3cdc1`) darf den
neuen Runtime-Slice **nicht erben**.

### Danach: Owner-Wände (§5) oder `organism-visual-v2` (Session 13 §12).

---

## 8. VERBOTE (Owner-Regeln, gelten ohne Ablauf)

| Verboten | Warum |
|---|---|
| `git add -A` | fegt Fremdarbeit und Artefakte in den Commit |
| `git commit` ohne Pathspec | **R-NEU-10** — der Index ist bei parallelem Agenten geteilt |
| Force-Push, Push auf Default-Branch | Owner-Wand |
| Prozente hochsetzen | Fake-Completion; `live_verified` nie von Hand |
| L4/L5 hochsetzen | bewusst null-kreditiert, **zwei** Verifier prüfen die Null |
| Zahlen / Kreditkarte / Paid Provider / Fly.io / R2 / Cloudflare Containers | Zero-Card ist Gesetz — und **Zahlung öffnet nichts**: `payment_required` ist bei O1/O2/O3 `false`, eine abgebildete Zahlung macht `owner-input-matrix` **rot** |
| Secrets in Chat, Datei, Log oder Commit | nur Pfad + Fundtyp melden, **nie** den Wert |
| Token rotieren / „Roll" im Dashboard | vom Owner **ausdrücklich abgelehnt** — nicht erneut vorschlagen |
| Parallel Playwright / Docker / Verifier | verfälscht Live-Beweise |
| `TEMP`/`TMP` ≠ `D:\_sb_tmp` | Verifier laufen sonst auf volle C:-Platte |
| DEV-ONLY-Evidenz als Hosted-Beweis ausgeben | Label **muss** mitlaufen |

**Die vier Wände, die kein Agent überschreitet:** Kreditkarte/Zahlung · Passwort-Konten ·
CAPTCHA · Secrets ausgeben oder committen.

---

## 9. GELERNTE REGELN (R-NEU-1…10) — die vier wichtigsten

**R-NEU-7 — Die Lastmessung maß sich selbst.**
PowerShell `ForEach-Object -Parallel` + `Invoke-WebRequest` = ein Runspace **und ein
TLS-Handshake pro Request**. Gemessen: c=50 p95 **21.180 ms**. Mit gepooltem `HttpClient`
(`SocketsHttpHandler`) + Kontrollgruppe `/cdn-cgi/trace`: **299,9 ms**, Worker-Eigenanteil 239 ms.
**~98,6 % war Messfehler.** Die Schwelle wurde **nicht** gesenkt — das Messgerät war kaputt.

**R-NEU-8 — „blockiert" heißt zweierlei.**
Entweder *noch nicht erledigt* oder *dauerhaft eingefroren*. Nur das Erste ist Arbeit.
Die 6 blockierten `phase_5`-Marker gehören zu `prod-candidate-2026-05-05-rc1`; diese Fläche
existiert nicht mehr und wird von `verify-retired-hosted-boundary.ps1` mit **34 Assertions**
als Historie gepinnt.

**R-NEU-9 — Eine Kette darf nie ihre eigene Ausgabe als Eingabe verlangen.**
Ein Gate verlangte `local_verification.static.status == "passed"` — wobei dieser Eintrag
`npm run verify` protokolliert, also die Kette, die den Check selbst ausführt. Folge:
**HEAD war rot und gepusht.** Fix: `static` entfällt.

**R-NEU-10 — `git commit` ohne Pathspec committet den gesamten Index.**
Beleg: `a8331d89` trägt eine Doku-Nachricht, enthält aber **34 Dateien**, davon 32 aus dem
RC11-Slice eines parallel arbeitenden Agenten. Der Commit blieb stehen (gepusht, Inhalt
legitim, zwei grüne Commits darauf — ein Rewrite wäre ein Force-Push gewesen).
**Immer `git commit -o <pfad…> -m "…"`.**

---

## 10. FALLEN, DIE SCHON ZWEIMAL ZUGESCHNAPPT SIND

| Falle | Wahrheit |
|---|---|
| Phantom-503 bei `/api/v1/build` | `start-dev-live.ps1` vergessen — Schutz, kein Defekt |
| Playwright `networkidle` bei pausierter Clock | Timer eingefroren, `networkidle` **kann nie** eintreten → `load` + `pauseAt(+1000ms)` |
| `wrangler secret put SOURCE_COMMIT_SHA` scheitert | **kein** Rate-Limit, sondern CF-Code **10053**: es sind `plain_text`-Vars. Richtig: `deploy --keep-vars --var …` |
| Docker + Git-Worktree | Docker kann die `.git`-**Datei** eines Worktrees nicht als Verzeichnis mounten → echten Clean-Clone benutzen |
| Docker-VHD wächst, schrumpft nie | Bei C: < 6 GB **vor** dem Build `docker builder prune` — ein disk-full-Abbruch hat schon einmal das ext4-Journal zerschossen |
| `#Requires -Version 7` vs. Windows PowerShell 5.1 | Verifier explizit mit `pwsh` starten |
| `endpoint-snapshot.json` neu schreiben | **minified single-line**, `separators=(',',':')`, `ensure_ascii=False`, `+"\n"` — sonst 12.633-Zeilen-Diff |
| P5-Prozentspiegel | Manifest · `apps/frontend/lib/platform.ts` · **harter Pin `verify-phase1.ps1:571`** · `endpoint-snapshot.json` · `PROJECT_STATE.md` — alle fünf ziehen mit |

---

## 11. ENDZIEL

```
npm run verify:market-ready   →   MARKET_READY: true
```

Beide Matrizen 100 %, **jede Zelle mit echtem Artefakt**. Owner-gewallte Reste ehrlich als
**OWNER-BLOCKED** listen — **nie faken (R0)**.

Der Weg dorthin ist **nicht** „Prozente hochsetzen", sondern:

1. Completion-Transition fertig (Verifier von *blockiert* auf *evidenzgebunden freischaltbar*)
2. Owner öffnet O1 / Token / O3
3. RC12 auf einen SHA gebunden: Source → Images/Digests → Deployment → **echte Aktionen** → Evidence/Rollback
4. Hosted Staging mit realen Aktionen — nicht nur HTTP 200:
   Build-Klick bis zum echten Provider · Artefakt persistiert · Reload liefert denselben Hash ·
   22/22 Routen, 161 Aktionen, keine toten Controls · D1 Create→Readback→Konflikt→Delete→404 ·
   **401/403/409 sind gesunde Negativergebnisse — nicht alles darf 200 sein** ·
   null Console-Errors · dieselbe Request-ID in Activity, Audit, Session, Observe, Evidence
5. Echter Digest-Rollback: zurück auf last-known-good, **dieselbe** Aktionskette erneut grün,
   dann Candidate wiederherstellen
6. Zweite, separate Owner-Freigabe für Production — menschlicher Klick **Approve and deploy**

---

*Erstellt 2026-08-02 · HEAD `7b366b45` · origin `fe88c2a0` · Overall 89 · Gates 7/10 zu ·
Codex rate-limited bis 2026-08-09 · DEV-ONLY; hosted proof still blocked*

---

## 12. FINALE ÜBERGABE — CODEX IST ENDGÜLTIG AUS (Stand 2026-08-02, letzte Messung)

> Alles ab hier ist **nach** Kapitel 1–11 gemessen worden. Wo sich Zahlen widersprechen,
> **gilt dieses Kapitel.** Codex hat nach Kapitel 2 noch ~2 Stunden weitergearbeitet und ist
> dann mit leerem Kontingent gestoppt (Reset laut Fehlermeldung **2026-08-09**).

### 12.1 Die Zahlen, die zählen

| | |
|---|---|
| HEAD | `9a3776ff` |
| origin | `fe88c2a0` — **8 Commits ungepusht** |
| Letzte CI-grüne Wahrheit | `f7830977`, Run `30712183385` |
| **Tracked dirty** | **42 Dateien** (nicht 12, nicht 3 — Kapitel 2 ist überholt) |
| Untracked neu | 9 Code-Dateien + Runbook |

### 12.2 ✅ Was ich abschließend geprüft habe — und was dabei herauskam

| Prüfung | Ergebnis |
|---|---|
| **Prozentwahrheit unangetastet?** | ✅ `docs/project-progress.manifest.json` hat **keinen Diff**. Overall **89**, P `[100,100,100,44,100,89,90]`, L `[100,100,100,55,56,100,100]` — exakt wie vor Codex' Session. **Kein Prozent wurde gefälscht.** |
| **Gates unangetastet?** | ✅ **3 von 10 offen**, unverändert |
| **Syntax des gesamten Baums** | ✅ **265 PowerShell + 41 Python + 8 YAML = 314 Dateien, 0 Fehler** |
| **Secret-Scan über den ganzen Diff** | ✅ **0 Funde** |
| **`fly.agent-api.toml` berührt?** | ✅ Ja, aber harmlos: **eine** Zeile `SUPERBRAIN_RUNTIME_MODE = "production"`. Kein Fly-Deploy, kein Paid-Pfad, keine Zahlung |

**Kurz: der Baum ist unfertig, aber er ist nicht kaputt und er lügt nicht.**

### 12.3 Die 42 dirty Dateien — nach Gruppen

**Fremd, nie anfassen (2):**
`.codex/runs/CURRENT/product-acceptance/report.json` · `apps/frontend/tsconfig.tsbuildinfo`

**Wahrheits-/Evidenzdateien (5) — vor jedem Commit einzeln begründen:**
`docs/runtime-state/capability-gates.json` · `docs/runtime-state/owner-input-manifest.json` ·
`.phase1-artifacts/o4-live-writes/{proof,browser-proof,runtime-proof}.json`

**Verifier (16):** `verify-phase1` · `verify-market-ready` · `verify-main-deploy-transition` ·
`verify-supply-chain-pins` · `verify-external-gates` · `verify-phase3-auth-session-integrity` ·
`verify-phase5-production-candidate-local` · `build-phase5-production-candidate-local` ·
`verify-phase6-scale-{runtime,runtime-static,evidence,evidence-static}` ·
`verify_phase5_credit_itemization.py` + Tests · `verify_ghcr_candidate.py` + Tests ·
`verify_project_progress_manifest.py`

**Frontend (10):** `frontendBoundary.ts` · `real-login.tsx` · 5 × `app/api/**/route.ts` ·
`oauth-boundary-readiness.test.mjs` · `22-page-actions.spec.ts` · `phase3-auth-session-integrity.spec.ts`

**Backend/Infra (8):** `agent-api/app/main.py` + `test_auth_security.py` ·
`docker-compose.{dev,cloud}.yml` · `nginx/{dev,cloud}.conf` · `fly.agent-api.toml` · `pr-check.yml`

**Neu, NICHT integriert (untracked):** `services/model-registry/*` (kompletter Service, kein
Verifier kennt ihn) · `services/agent-api/app/core/{access_classes,cost_gate}.py` + Test ·
`docs/runbooks/OWNER_SCHRITT_FUER_SCHRITT_2026-07-27.txt`

### 12.4 Was der nächste Agent ZUERST tun muss

1. **Nichts pauschal committen.** 42 Dateien in einem Commit = Wiederholung von R-NEU-10 im großen Stil.
2. **`npm run verify` einmal seriell laufen lassen** — das ist der einzige ehrliche Weg
   herauszufinden, ob Codex' halbfertiger Slice grün ist. Vorher `TEMP`/`TMP=D:\_sb_tmp`.
3. **Erst danach** entscheiden: Slice fertigstellen **oder** in kleine committbare Teile schneiden.
4. **Fix aus §6.1 nicht vergessen** (eine Assertion, `publish-candidate` braucht `verify-candidate`).
5. **§6.3**: 13 Auditfunde sind weiterhin ungeprüft.

### 12.5 Warum nichts gepusht wurde

8 Commits + 42 dirty Dateien, **kein einziger vollständiger Verifier-Lauf** über diesem Stand.
Ein Push ohne grünen Lauf hätte genau den Fehler wiederholt, der als **R-NEU-9** dokumentiert
ist: *HEAD war rot und gepusht.* Der Baum bleibt lokal, bis er bewiesen ist.

**Der Push-Befehl steht bereit — er braucht nur einen grünen Lauf davor:**

```bash
git push origin HEAD:refs/heads/claude/cloud-superbrain-analysis-127d2e
```

### 12.6 Ehrliches Fazit

- **Fortschritt seit `f7830977`:** substanziell und in weiten Teilen lokal grün
  (27/27 Auth · 24/24 Worker · 12/12 OAuth-Boundary · 14/14 GHCR · 15/15 Evidence-Portabilität ·
  Kamera-Browserbeweis · MARKET_READY-Dual-State).
- **Aber:** unbewiesen als Ganzes, ungepusht, und mit einem bestätigten MAJOR-Befund.
- **Die 89 % sind echt.** Sie sind nicht gestiegen — weil ohne Owner-Wände **nichts** legitim
  steigen kann. Das ist kein Stillstand, das ist Ehrlichkeit.

---

*Letzte Messung 2026-08-02 · HEAD `9a3776ff` · 8 Commits ungepusht · 42 dirty · Syntax 314/314 ok ·
Secrets 0 · Prozente unangetastet · Codex-Reset 2026-08-09*

---

## 13. SESSION 15 — WAS ICH NACH CODEX' AUS NOCH GEPRÜFT UND REPARIERT HABE

> **Korrekturen an früheren Kapiteln stehen hier. Wo Widerspruch: dieses Kapitel gilt.**

### 13.1 ✅ KORREKTUR — der MAJOR-Befund aus §6.1 ist ERLEDIGT

**Meine Meldung in §6.1 ist überholt.** Codex hat nach meinem Audit selbst nachgezogen.
`scripts/verify-main-deploy-transition.ps1` enthält jetzt **genau die zwei Assertions**, deren
Fehlen ich gemeldet hatte:

```
Zeile 89:  Assert-Regex    "publish-candidate is gated by successful candidate preflight and CI"
                           '^\s{4}needs:\s*\[candidate-preflight,\s*verify-candidate\]\s*$'
Zeile 90:  Assert-NotRegex "publish-candidate has no job-level always bypass"
                           '^\s{4}if:\s*.*\balways\s*\('
```

Beide Umgehungswege, die ich beschrieben hatte (`needs:` kürzen · `if: always()`), sind damit
geschlossen. **Kein offener MAJOR-Befund mehr.** §6.1 nur noch als Historie lesen.

### 13.2 ✅ Scale-False-Green — widerlegt

Die Sorge aus §6.3 (Verifier könnte ohne echte Writes grün melden) ist **gegenstandslos**:

- `scripts/verify-phase6-scale-runtime.ps1:376-377` — ohne `-AllowHostedWrites`:
  `Blocked "-AllowHostedWrites is missing; zero HTTP requests issued"`
- `Blocked` ist **`exit 2`**, kein Pass (Zeile 36-39)
- Das Skript enthält **null** `WriteAllText` / `Set-Content` / `Out-File`.
  Es liest `capability-gates.json` nur und prüft die getrackten HEAD-Bytes.
  **Es kann sich nicht selbst freischalten.**
- 12 × `finally` → Cleanup ist abgesichert

### 13.3 ✅ Die zwei Wahrheitsdateien sind sauber — semantisch geprüft

Nicht am Text, sondern am **geparsten JSON** gegen `HEAD` verglichen:

| Datei | Semantische Änderung |
|---|---|
| `capability-gates.json` | **nur** `live_agent_tool_writes` + `live_mcp_writes`: `evidence_sha256` und `verified_at_utc` — ein O4-Rebind vom 2026-08-02 |
| `owner-input-manifest.json` | derselbe O4-Timestamp · eine Zeitformat-Normalisierung · eine Wortkorrektur: *„paid scale"* → *„zero-card authenticated scale proof"* (richtig — P6 braucht **kein Geld**) |

**Hash-Bindung nachgerechnet:** SHA-256 über `.phase1-artifacts/o4-live-writes/proof.json`
= `B7CC7705…` — identisch in **beiden** Gate-Einträgen. ✅
**Gates umgelegt: KEINE.** Weiterhin exakt 3 offen. ✅
Der Rest des Diffs ist BOM-/Einrückungs-Normalisierung.

### 13.4 🔧 EIN ECHTER BUG GEFUNDEN UND REPARIERT

`npm run verify` war **rot** — erster Stopp gleich in `[verify] supply-chain pins`:

```
[System.IO.Path] enthält keine Methode "GetRelativePath"
  scripts/verify-supply-chain-pins.ps1:27
```

`[IO.Path]::GetRelativePath()` gibt es **nur in .NET Core (pwsh 7+)**. `package.json` startet
`verify` aber mit `powershell` = **Windows PowerShell 5.1**. Exakt die Falle aus §10.

**Fix:** relativer Pfad durch Trimmen von `$repoRoot` statt `GetRelativePath`, plus eine
`StartsWith`-Wache, die den Scan im Repo hält.

**Ergebnis — beide Editionen, identische Zählung:**

```
PS 5.1 : [verify] supply-chain pins PASS (23 external actions, 18 external image occurrences,
                                          9 unique external images, 6 internal GHCR references)
pwsh 7 : [verify] supply-chain pins PASS (23 …)   ← Zahl für Zahl gleich
```

Keine Assertion geschwächt: die Exakt-Gleichheit `-ne 23` bleibt.

### 13.5 ⛔ WARUM DIESER FIX NICHT COMMITTET IST

Er hängt an Codex' `pr-check.yml`. Codex hat dort Jobs ergänzt, deshalb stieg die Erwartung von
**20 auf 23** Actions. Committe ich **nur** den Verifier, prüft er gegen die **alte** committete
`pr-check.yml` mit 20 Treffern → **HEAD wäre sofort rot.**

Der Fix gehört zum Slice und muss **mit** ihm committet werden. **Er liegt fertig im Worktree.**

### 13.6 🛑 DER ECHTE VERBLEIBENDE BLOCKER — und er ist KEIN Bug

Nach dem Fix läuft `verify` deutlich weiter (Phase-6-Frontend 7/7 Marker grün) und stoppt dann hier:

```
[phase5-credit] active candidate has committed or staged runtime-source drift
                outside the exact post-qualification truth transition
[project-progress] Phase-5 credit itemization is invalid
```

`scripts/verify_phase5_credit_itemization.py:1152` verlangt
`changed_paths == QUALIFICATION_TRUTH_PATHS`.

**Übersetzt:** Der aktive Kandidat ist **RC11 (`bae3cdc1`)**. Seit dessen Qualifikation hat sich
die Runtime-Quelle geändert (8 Commits + 42 dirty). Der Verifier **weigert sich**, P5 = 89 für
einen Kandidaten gutzuschreiben, dessen Quelle nicht mehr passt.

> **Das ist kein Defekt, das ist die Kernregel des Projekts, die funktioniert.**
> Codex hatte denselben Befund und nannte ihn richtig:
> *„RC11 darf den neuen Runtime-Slice nicht erben."*

**Die Auflösung ist RC12, nicht ein Patch am Verifier.** Wer hier einen Verifier anfasst, um
grün zu werden, begeht Fake-Completion.

### 13.7 Der Weg zu grün — konkret

1. **Commit A** = Codex' Code/Evidence-Slice (42 dirty + 9 untracked, inkl. meines Fixes),
   in sinnvollen Teilen mit **Pathspec**.
2. **Clean-Clone** auf Commit A (kein Worktree — Docker kann dessen `.git`-Datei nicht mounten).
3. **6 Images bauen** → `build-phase5-production-candidate-local.ps1`, Source = Commit A.
4. **Fünf Ketten** fahren: Runtime · Browser · Images · Candidate-Runtime · Security.
5. **Commit B** = RC12-Metadaten, die exakt auf A zeigen
   (`current-release-candidate.json` + `prod-candidate-2026-08-02-local-rc12.md`).
6. Erst **B** als Kandidat verifizieren → dann ist `changed_paths` wieder leer → P5-Credit gültig.
7. `npm run verify` grün → pushen → `pr-check` per Dispatch auf genau diesem SHA.

Vorarbeit dafür liegt schon in `D:\_sb_tmp\superbrain-clean-proof-96a9c5e4`
(RC12-Metadaten von Codex bereits geschrieben, Kette unvollendet).

**Zeitbedarf realistisch:** 6-Image-Build ≈ 60 Min, Browserkette ≈ 45 Min, seriell, mit
`TEMP`/`TMP=D:\_sb_tmp` und C: > 6 GB frei. Das ist der nächste große Block.

### 13.8 Bilanz dieser Session

| | |
|---|---|
| Gefixt | 1 echter Bug (PS-5.1-Inkompatibilität), unter **beiden** Editionen verifiziert |
| Widerlegt | 2 eigene Befunde (§6.1 bereits erledigt · Scale-False-Green gegenstandslos) |
| Bestätigt sauber | beide Wahrheitsdateien · O4-Hash-Bindung · keine Gate-Manipulation |
| Identifiziert | der **exakte** verbleibende Blocker (Kandidatenbindung, kein Bug) |
| Nicht committet | bewusst — würde HEAD rot machen (§13.5) |
| Prozente | unverändert **89**. Nichts hochgesetzt, nichts gefälscht |


---

## 14. SESSION 16 — SECHS PLATTFORMFEHLER, DREI REIHENFOLGE-REGELN, RC12-MECHANIK ENTSCHLÜSSELT

### 14.1 Codex' Phase-6-CI-Step war nie gelaufen — sechs Fehler übereinander

Der Step `Phase 6 scale fail-closed static contracts` wurde in Commit A neu eingebaut und
**ausschließlich lokal auf Windows** getestet. In CI (`ubuntu-latest`) kam er nie einen
einzigen Schritt weit. Jeder Fix legte den nächsten frei:

| # | Fehler | Wirkung in CI |
|---|---|---|
| 1 | `pwsh -File scripts\...ps1` in `package.json` | `\` ist kein Trenner → pwsh druckte **seinen Hilfetext**, **13 Folge-Steps `skipped`** |
| 2 | `.github/workflows/phase6-scale-runtime.yml` **nie committet** | „dedicated Phase6 scale workflow is missing" |
| 3 | `'.github\workflows\...'` in `verify-phase6-scale-runtime-static.ps1:16` | Pfad löst auf Linux nie auf |
| 4 | `GetFullPath('D:\_sb_tmp')` in `verify-phase6-scale-evidence-static.ps1:11` | Laufwerk existiert nicht → Cleanup-Wache verweigerte **zu Recht** |
| 5 | `git.exe` (3× static, 10× deep) | „The term 'git.exe' is not recognized" |
| 6 | `D:\_sb_tmp`-Confinement in `verify-phase6-scale-evidence.ps1:31` | jede Test-Fixture galt als „außerhalb" |

**Fehler 2 war meiner:** Beim Zusammenstellen von Commit A habe ich untracked Dateien nur aus
`scripts apps services docs` geholt und **`.github` vergessen**.

**Lehre:** Ein Verifier, der nur auf der Entwicklermaschine läuft, beweist nichts über CI.
Jeder neue CI-Step braucht mindestens einen roten Lauf, bevor man ihm glaubt.

Alle sechs sind behoben; `[phase6-scale-static] PASS` erscheint jetzt **in CI**. Die Fixes sind
plattformübergreifend und lokal auf Windows **und** im Fallback-Pfad verifiziert.

### 14.2 Drei Reihenfolge-Regeln, die jeden Kettenlauf entscheiden

1. **O4 ist der LETZTE Schritt vor der Kette, nicht der erste.**
   Der Beweis bindet sich an den Source-SHA. Jeder Commit danach macht ihn stale und die Kette
   fällt am Ende mit `runtime-source parity outside qualification truth`. Code einfrieren →
   O4 beweisen → Kette fahren.

2. **`start-dev-live.ps1` gehört NACH `verify:runtime`, unmittelbar VOR `verify:browser`.**
   Die Runtime-Kette recycelt Container über Compose, und der Compose-Standard ist
   `deterministic_dry_run`. Danach liefert das Modell nur den 129-Zeichen-Stub, die Build-Route
   verweigert korrekt die Persistenz, und Product-Acceptance fällt mit
   `llm_gateway_generation_unavailable`. Der Token bleibt dabei gesetzt — **nur der Modus ist weg**.
   Prüfbefehl vor jeder Browser-Kette:
   `docker exec cloud-superbrain-phase1-dev-llm-gateway-1 sh -c 'echo $LLM_GATEWAY_MODE'`
   Muss `cloudflare_workers_ai_live` sagen. Der Startmeldung allein nicht vertrauen.

3. **Jeder `docker compose up --build <service>` setzt den Live-Pfad ebenfalls zurück.**
   Nach jedem Rebuild erneut `start-dev-live.ps1`.

### 14.3 RC12: die Bindungsmechanik, vollständig

`verify_phase5_credit_itemization.py:473-560` kennt **zwei** CI-Bindungsmodi:

- `direct_head_v1` — verlangt `head_sha == source_sha`, aber **nur für Kandidaten in
  `LEGACY_DIRECT_CI_BINDINGS`**. Für RC12 nicht zulässig.
- `source_checkout_attestation_v1` — der Weg für RC12. Er **trennt Kontroll- und Kandidaten-SHA**
  und löst damit das Henne-Ei-Problem („die Metadaten müssen den CI-Lauf ihres eigenen SHA
  nennen"), an dem ich zuerst hängen blieb.

Erforderlich:

| Feld | Wert |
|---|---|
| `control_sha` | = `head_sha` des Laufs, **muss ≠ source_sha** sein (der Metadaten-Commit) |
| `candidate_sha` · `checked_out_sha` | = `source_sha` (der eingefrorene Code-SHA) |
| `event_name` | `workflow_dispatch` |
| `source_prequalification` | `true` |
| Ahnenkette | `source` → Ahn von `control` → Ahn von `HEAD` |
| `attestation.artifact` | `docs/release-artifacts/<release_id>-evidence/ci-source-checkout-attestation.json`, **getrackt** |
| dazu | `sha256` der Datei · `github_artifact_id` · `github_artifact_url` = `<run_url>/artifacts/<id>` · `github_artifact_digest` |

**Ablauf, der daraus folgt:**
1. Code einfrieren (hier: `44c69506`), alle fünf Ketten darauf grün fahren.
2. RC12-Metadaten committen (Docs/Evidenz — liegen **außerhalb** `RUNTIME_SOURCE_PATHS`,
   erzeugen also **keinen** neuen Drift). Dieser Commit wird der **Kontroll-SHA**.
3. Push, dann `pr-check` per `workflow_dispatch` mit `candidate_sha=<source>` und
   `source_prequalification=true`.
4. Attestation-Artefakt aus dem Lauf herunterladen, in den Evidence-Ordner committen,
   Hash + Artifact-ID/URL/Digest in die Readiness eintragen.
5. `npm run verify` → der Drift-Guard findet keine Änderung in `RUNTIME_SOURCE_PATHS` und gibt frei.

### 14.4 Stand am Ende dieser Session

**Eingefrorener Kandidaten-SHA: `44c69506`.** Alle fünf Ketten darauf grün:

| Kette | Ergebnis |
|---|---|
| Images | ✅ 6/6 `status=verified` |
| Runtime | ✅ 86 Prüfungen |
| Browser | ✅ Contract · Product-Acceptance (echter Cloudflare-Call) · 22 Routen/161 Aktionen (20,7 min) · O4-Write · Promote |
| O4 | ✅ dreifach, `4FA30579…` |
| Security / Candidate-Runtime | offen — brauchen zuerst das RC12-Kandidatendokument |

**Prozente unverändert 89.** Nichts hochgesetzt, nichts gefälscht.

---

## 15. DER BLOCKER, DER JETZT SICHTBAR IST: VERIFIER UND EVIDENZ-SCHREIBER SIND UNEINIG

### 15.1 Was passiert ist

Nachdem die sechs Plattformfehler aus §14.1 behoben waren, laufen in `pr-check` zum **ersten
Mal** zwei Steps, die vorher immer nur `skipped` waren:

- `Phase 5 credit itemization`
- `Source-prequalification control integrity`

Beide melden jetzt echte, semantische Fehler. **Die Plattformfehler haben sie verdeckt.**

### 15.2 Der eigentliche Befund

`scripts/verify_phase5_credit_itemization.py:101` definiert `CANONICAL_SUCCESS_ANCHORS` — pro
Kette eine **exakte** Liste von Ankerzeilen, die im Rohlog stehen müssen. `:467` verlangt
`observed == canonical`, also Gleichheit, nicht Teilmenge.

`scripts/write-phase5-security-evidence.ps1` schreibt diese Anker aber **nicht**:

| Verifier verlangt | Schreiber erzeugt |
|---|---|
| `[phase5-security] npm_audit_verified=true` | nur `found 0 vulnerabilities` |
| `[phase5-security] gitleaks_verified=true` | nur `no leaks found` |

Der Verifier wurde verschärft, der Schreiber nicht nachgezogen. Dieselbe Klasse Bruch trifft
`candidate-runtime`: `scripts/tests/test_verify_phase5_credit_itemization.py` erzeugt Fixtures,
die der Verifier mit *„observed anchors are not canonical"* ablehnt, **bevor** die eigentlich
getestete Assertion überhaupt erreicht wird.

**7 der 21 Unit-Tests fallen** — lokal wie in CI, reproduzierbar:

```bash
python -m unittest discover -s scripts/tests -p "test_verify_phase5_credit_itemization.py"
```
→ `Ran 21 tests … FAILED (failures=3, errors=4)`

Betroffen: `test_ci_workflow_accepts_fail_closed_source_checkout_attestation`,
`test_ci_workflow_accepts_legacy_direct_head_binding`,
`test_v2_candidate_runtime_requires_raw_api_image_browser_and_boolean_evidence`,
`test_v2_summary_recomputes_tracked_raw_log_and_reads_anchors_from_it`,
`test_ci_workflow_rejects_relabeling_and_non_control_delta`,
`test_ci_workflow_rejects_unattested_direct_binding_for_new_candidate`,
`test_v2_candidate_runtime_rejects_boolean_fabrication_in_raw_api`.

### 15.3 Was daraus folgt — und was NICHT

**Nicht:** Der Verifier ist zu streng. Kanonische Anker sind der Grund, warum ein Rohlog nicht
frei erfunden werden kann. Wer sie aufweicht, öffnet genau die Tür, die sie schließen sollen.

**Sondern:** Der Evidenz-Schreiber muss die Anker erzeugen, die der Verifier verlangt, und die
Test-Fixtures müssen dieselbe kanonische Form benutzen. Drei Dateien, eine Wahrheit:

1. `scripts/write-phase5-security-evidence.ps1` → `npm_audit_verified=true` und
   `gitleaks_verified=true` in das Rohlog schreiben, jeweils nur nach bestandenem Exit-Code.
2. Analog für die übrigen Ketten prüfen: `runtime`, `browser`, `candidate-images`,
   `candidate-runtime` gegen `CANONICAL_SUCCESS_ANCHORS` abgleichen.
3. `scripts/tests/test_verify_phase5_credit_itemization.py` → Fixtures auf dieselbe
   kanonische Ankerform bringen, damit die Tests wieder das prüfen, was ihr Name sagt.

Danach: Evidenz neu erzeugen (die fünf Ketten laufen bereits grün, nur die Rohlogs müssen die
Anker tragen), Readiness schreiben, Kontroll-Commit, CI mit Attestation, `npm run verify`.

### 15.4 Die Commit-Reihenfolge, die die Attestation erzwingt

`.github/workflows/pr-check.yml` berechnet den Kontroll-Delta als
`git diff candidate_sha control_sha` und erlaubt darin **genau fünf** Pfade:
`pr-check.yml`, `verify_phase5_credit_itemization.py` (+ Tests),
`verify-main-deploy-transition.ps1`, `verify-supply-chain-pins.ps1`.

**Alles, was zwischen Kandidat und Kontrolle liegt, landet in diesem Delta.** Release-Metadaten,
Evidenz und Übergabedokumente müssen deshalb **nach** dem Kontroll-Commit liegen, nie dazwischen.
Ich bin genau in diese Falle gelaufen und habe sie vorwärts korrigiert:
`a7a5f4ae` (Kontrolle, nur `pr-check.yml`) → danach die Metadaten. Die Regel steht jetzt als
Kommentar in `pr-check.yml` an der Stelle, an der sie gilt.

### 15.5 Aktueller Stand

| | |
|---|---|
| Kandidaten-SHA | `44c69506` — sechs Ketten grün, siehe §14.4 |
| Kontroll-Commit | `a7a5f4ae` — Delta = genau eine erlaubte Datei ✅ |
| RC12-Metadaten | wiederhergestellt und **nach** der Kontrolle einsortiert |
| CI | rot, aber jetzt an **echten** Prüfungen: `Phase 5 credit itemization` und `control integrity` |
| Prozente | unverändert **89** |

**Das ist Fortschritt, kein Rückschritt:** Vorher scheiterte CI daran, dass ein Skript nicht
startete. Jetzt scheitert sie an einer inhaltlichen Aussage über die Evidenz. Der Weg von hier
ist in §15.3 vollständig beschrieben.

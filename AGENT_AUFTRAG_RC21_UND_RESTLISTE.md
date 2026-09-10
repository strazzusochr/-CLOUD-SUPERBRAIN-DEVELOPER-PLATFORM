# 🧾 AGENTEN-AUFTRAG — RC21 binden und Restliste schliessen

> **Das ist eine vollstaendige Arbeitsanweisung. Fuehre sie in dieser Reihenfolge aus.**
> Ueberspringe nichts. Wenn ein Schritt rot wird: **anhalten, Ursache messen, berichten** —
> niemals weitergehen, niemals eine Zahl von Hand setzen, niemals einen Verifier umgehen.
>
> Repo: `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`
> Branch: `codex/organism-visual-v2` — **niemals** `main` oder `chore/repo-bootstrap`
> Stand dieser Anweisung: HEAD `abead9ac57c6fc2877d0efd2250301c90e566f42`

## AUSFUEHRUNGSSTAND 2026-08-29 — nicht erneut beginnen

- Aufgabe A ist abgeschlossen: RC21 Quelle `c1b022a884eb16939fe0542b2eb9056b60706b20`,
  Control `9f2ee383`, CI `33217980790`, aktiver Kandidat technisch verifiziert.
- Aufgabe B ist abgeschlossen: `api_error` war ein stale DEV-ONLY-Container-Token;
  scoped Agent-API-Recreate stellte `github_actions.status=verified` her, ohne
  Rotation oder Secret-Ausgabe.
- Aufgabe C ist abgeschlossen: Audit und Regression laufen in
  `scripts/verify-phase1.ps1`; die Suite-Registry entdeckt nur PS1-Dateien.
- Aufgabe E ist abgeschlossen: Follow-up-CI `33223542872` bestand `25/25` mit
  `0` skipped.
- V0 ist als `docs/runtime-contracts/layer-credit-rubric.md` entworfen. Der
  Entwurf vergibt keinen Credit und wartet auf Owner-Freigabe.
- Die Owner-Konsolen sind vorbereitet, aber Hosted OAuth, Phase-6-Scale,
  Hosted-Candidate-Paritaet, GHCR und Production bleiben beweispflichtig bzw.
  explizit gegatet.

Die Detailanweisung unten bleibt der reproduzierbare historische Ablauf. Fuer
den naechsten Schritt gilt der Seitenkopf in `CODEX_ZIELVERFOLGUNG_KURZ.md`.

---

## 0 · HARTE REGELN — Verstoss macht den ganzen Lauf ungueltig

### 0.1 Git

1. **Niemals `git add -A`.** Immer explizite Pfade: `git commit --only -- <pfad> <pfad>`.
2. **Niemals `git stash`** (der Stack wird mit anderen Worktrees geteilt).
3. **Kein Force-Push. Kein Push auf den Default-Branch.**
4. Nach jedem Commit pruefen: `git status --porcelain | Select-String '^ D'` **muss leer sein**.

### 0.2 Diese Dateien gehoeren dir NICHT — nicht stagen, nicht zuruecksetzen, nicht loeschen

```
.codex/runs/CURRENT/product-acceptance/report.json
.phase1-artifacts/o4-live-writes/proof.json
.phase1-artifacts/o4-live-writes/runtime-proof.json
.phase1-artifacts/o4-live-writes/browser-proof.json
docs/runtime-state/capability-gates.json
docs/runtime-state/external-gate-audit-v2.json
docs/runtime-state/external-gate-summary.json
docs/runtime-state/owner-input-manifest.json
docs/release-artifacts/current-release-candidate.json      <- Ausnahme: siehe Schritt A7
docs/release-artifacts/prod-candidate-2026-08-02-local-rc12.md   <- ist GESTAGED, muss gestaged BLEIBEN
```

`.phase1-artifacts/` und `docs/release-artifacts/` sind beim Aufraeumen **tabu**.

### 0.3 Ausfuehrung

- **Niemals parallel:** Playwright, Docker-Builds und Verifier laufen **streng nacheinander**.
- **Vor jedem Verifier:** `$env:TEMP='D:\_sb_tmp'; $env:TMP='D:\_sb_tmp'`
- **Nutze `pwsh` (7), nicht `powershell` (5.1)** — mehrere Skripte haben `#Requires -Version 7`.
- **Waehrend eines Browser-Laufs keine Datei unter `apps/frontend/` aendern.** Das Verzeichnis
  ist live in den Container gemountet; ein Hot-Reload kann den Lauf verfaelschen.
- **Evidenz niemals nachbearbeiten.** Die Dateien sind hashgebunden; jede spaetere Aenderung
  bricht die Kreuzreferenz.

### 0.4 Wahrheit

- **Keine Prozentzahl von Hand setzen.** Kein `live_verified` von Hand.
- **Kein „fertig" ohne Beleg.** Ein grep im eigenen Quelltext ist kein Beweis.
- Jedes lokale Ergebnis wird als **`DEV-ONLY; hosted proof still blocked`** gekennzeichnet.

### 0.5 Vier Waende, die du niemals ueberschreitest

Kreditkarte/Zahlung · Passwort-Konten · CAPTCHA · Secrets ausgeben oder committen.
Bei Secrets gilt: **nur Pfad und Fundtyp nennen, niemals den Wert.**

---

## 1 · PREFLIGHT — vor allem anderen

```powershell
Set-Location 'D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM'
$env:TEMP='D:\_sb_tmp'; $env:TMP='D:\_sb_tmp'

git branch --show-current                       # MUSS codex/organism-visual-v2 sein
git status --porcelain | Select-String '^ D'    # MUSS leer sein
git rev-parse HEAD                              # notieren -> das ist SRC
(Get-PSDrive D).Free/1GB                        # MUSS > 25 sein (Image-Builds)
docker ps                                       # Daemon lebt?
```

**Abbruch, wenn:** Branch falsch · geloeschte tracked Dateien · < 25 GB frei · Docker tot.

---

# AUFGABE A · RC21 BINDEN  ← wichtigster Punkt, alles andere haengt daran

## Warum das noetig ist (nicht ueberspringen, das erklaert die Fallen)

`docs/release-artifacts/current-release-candidate.json` zeigt **uncommitted** auf
`prod-candidate-2026-08-28-local-rc21`. Dieser Kandidat hat nur eine `.md` — **kein**
`-evidence/`-Verzeichnis, **keine** `-readiness.json`. Deshalb ist `verify:phase5-credit`
rot mit `C3 evidence #1 anchor is not present in the evidence artifact`.

**Ein Rueckfall auf RC20 ist unmoeglich.** Seit der RC20-Quelle `c29c738b` haben sich
fuenf Pfade in `RUNTIME_SOURCE_PATHS` geaendert:

```
apps/frontend/app/api/v1/build/route.ts
apps/frontend/app/marketplace/page.tsx
apps/frontend/components/organism/CortexLive.tsx
apps/frontend/lib/providerStatus.ts
apps/frontend/tests/provider-status-tone.test.mjs
```

Der RC21-Stumpf nennt ausserdem die **veraltete** Quelle `88fc985a`; HEAD ist inzwischen
weiter. **Du frierst auf dem aktuellen HEAD neu ein.**

---

## A1 · Quelle einfrieren

```powershell
$SRC = (git rev-parse HEAD).Trim()
$REL = "prod-candidate-2026-08-28-local-rc21"
$ROLLBACK = "c29c738b82e4e35cc1288bc603319cba60d167d2"   # RC20 = exakter Rollback-Anker
Write-Host "SRC=$SRC  REL=$REL  ROLLBACK=$ROLLBACK"
```

**Ab hier keine Aenderung mehr an `RUNTIME_SOURCE_PATHS`** bis A9 durch ist. Jede
Aenderung macht alle folgenden Beweise ungueltig und du faengst bei A1 neu an.

`RUNTIME_SOURCE_PATHS` ist exakt (aus `scripts/verify_phase5_credit_itemization.py:53`):

```
.dockerignore · apps/frontend · services/agent-api · services/agent-worker
services/memory-worker · services/mcp-gateway · services/llm-gateway
PROJECT_STATE.md · docs/project-progress.manifest.json
docs/runtime-state/external-gate-summary.json
docs/codex-integration/autonomous-agent-roster.json
```

## A2 · Statische Wahrheit — muss gruen sein, bevor gebaut wird

```powershell
npx tsc --noEmit -p apps/frontend/tsconfig.json
node --test apps/frontend/tests/generated-html-runnability.test.mjs
node --test apps/frontend/tests/oauth-boundary-readiness.test.mjs
node --test apps/frontend/tests/auth-session-integrity.test.mjs
node --test apps/frontend/tests/provider-status-tone.test.mjs
node --test scripts/tests/five-axis-audit-regression.test.mjs
Set-Location services\llm-gateway; python -m unittest discover -s tests; Set-Location ..\..
npm run build
```

**Erwartung:** alles gruen, Build `21/21` Seiten. Bei rot: anhalten und berichten.

## A3 · Sechs Images aus dem committeten Archiv

```powershell
$RUNID = [guid]::NewGuid().ToString()
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\build-phase5-production-candidate-local.ps1 `
  -SourceSha $SRC `
  -ReleaseId $REL `
  -RollbackTarget $ROLLBACK `
  -OutputDir .codex\runs\CURRENT\master-goal\phase5\production-candidate-local `
  -EvidenceRunId $RUNID
```

Dauert ~30 min. **Nicht abbrechen, nichts parallel starten.**
Bei „no space": aufraeumen — aber **niemals** `.phase1-artifacts/` oder
`docs/release-artifacts/`.

> ### ⛔ FALLE: falsches `tar` — bricht den Build sofort ab
>
> ```
> /usr/bin/tar: Cannot connect to D: resolve failed
> git archive extraction failed with exit code 128
> ```
>
> **Ursache:** Auf dieser Maschine steht Gits GNU-`tar`
> (`C:\Program Files\Git\usr\bin\tar.exe`) im PATH **vor** dem Windows-`tar`
> (`C:\WINDOWS\system32\tar.exe`) — auch in einer sauberen `pwsh`. GNU-`tar` liest
> `D:\_sb_tmp\…\source.tar` als **Remote-Host** `D:` und versucht eine Netzverbindung.
>
> **Fix — PATH vor dem Aufruf korrigieren:**
> ```powershell
> $env:PATH = 'C:\WINDOWS\system32;' + $env:PATH
> (Get-Command tar).Source     # MUSS C:\WINDOWS\system32\tar.exe sein
> ```
>
> Pruefe das **vor** dem Build. Sonst laeufst du 30 Minuten in einen Abbruch, der wie ein
> Code-Fehler aussieht, aber keiner ist.

## A4 · Runtime-Kette

Der Runtime-Verifier braucht den Service-Token **im Prozess**. Wert niemals ausgeben:

```powershell
$secretFile = Join-Path $env:USERPROFILE '.codex\secrets\cloud-superbrain.local.env'
foreach ($line in Get-Content -LiteralPath $secretFile) {
  if ($line -match '^\s*AGENT_API_AUTH_TOKEN\s*=(.*)$') {
    $env:AGENT_API_AUTH_TOKEN = $matches[1].Trim().Trim('"'); break
  }
}
if (-not $env:AGENT_API_AUTH_TOKEN) { throw "AGENT_API_AUTH_TOKEN fehlt" }

pwsh -NoProfile -File scripts\start-dev-live.ps1 -DryRun     # 10/10 healthy abwarten
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\write-phase5-local-verification-evidence.ps1 `
  -Chain runtime -ReleaseId $REL -SourceSha $SRC -EvidenceRunId ([guid]::NewGuid().ToString())
```

> **Falle:** Der Verifier vergleicht gegen den **aktiven Zeiger**. Wenn er ueber
> „selector RC20 ↔ artifact RC21" stolpert, ist A7 (Zeiger) noch nicht gesetzt — das ist
> erwartet. Setze dann A7 **vorher** und wiederhole A4.

## A5 · DEV-LIVE hochfahren — **NACH** Runtime, **VOR** Browser

```powershell
pwsh -NoProfile -File scripts\start-dev-live.ps1
```

**Pruefe die ausgegebenen Schalter, glaube nicht der Startmeldung:**

```
Gateway-Modus          : cloudflare_workers_ai_live
Owner-Live-Master-Gate : true
Frontend erlaubt Live  : true
CF_WORKERS_AI_TOKEN    : yes
CLOUDFLARE_ACCOUNT_ID  : yes
```

Steht dort `deterministic_dry_run`, ist der Browser-Beweis wertlos — **nicht weitermachen.**

## A6 · Browser-Kette mit echten Klicks

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\write-phase5-local-verification-evidence.ps1 `
  -Chain browser -ReleaseId $REL -SourceSha $SRC -EvidenceRunId ([guid]::NewGuid().ToString())
```

Falls du die Teilbeweise einzeln brauchst — **streng nacheinander**:

```powershell
npm run verify:product-acceptance          # echter Prompt -> Build -> Interaktion -> Reload
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\verify-22-page-actions.ps1 `
  -BaseUrl http://localhost:8081 -AllowLocalhost -ApproveLiveProviderCalls
npm run verify:responsive                  # 22 x 2 = 44 Klicks
```

> **Falle 1:** `verify-22-page-actions.ps1` bricht **ohne** `-ApproveLiveProviderCalls`
> sofort ab. Das ist eine Kostenbremse, kein Fehler — zwei gebundene Provider-Calls.
> **Falle 2:** Der Lauf dauert **~30 Minuten** und puffert seine Ausgabe. Kein Output
> heisst **nicht** „haengt". Pruefe stattdessen, ob `apps/frontend/test-results` waechst.
> **Falle 3:** Waehrend des Laufs **keine** Datei unter `apps/frontend/` anfassen.

**Erwartung:** `routes=22 families=29 members=161 direct=160 preverified_exact=1`

## A7 · Aktiven Zeiger auf RC21 setzen

`docs/release-artifacts/current-release-candidate.json` — **nur diese vier Felder**:

```json
{
  "active_release_id": "prod-candidate-2026-08-28-local-rc21",
  "updated_at": "<UTC jetzt, Format 2026-08-28T20:01:19Z>",
  "updated_by": "codex-rc21-local-qualification",
  "reason": "<ein Satz: welche Quelle, welcher Zustand, RC20 c29c738b bleibt Rollback-Ziel. Endet mit: DEV-ONLY; hosted proof still blocked.>",
  "production_rollout_claimed": false
}
```

`production_rollout_claimed` bleibt **immer** `false`.

## A8 · O4 — ZULETZT, direkt vor der Evidenzbindung

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\verify-o4-live-writes.ps1
```

> **Kritisch:** O4 ist der **letzte** quellgebundene Schreib-/Browserbeweis.
>
> **Praezise Bedingung** (gemessen an `verify-o4-live-writes.ps1:371` und `:397`) — O4 bleibt
> gueltig, solange **beides** gilt:
> 1. der `source_commit` des Reports ist ein **Vorfahr von HEAD** (nicht: gleich HEAD), und
> 2. diese neun Pfade sind **sauber**:
>    `.dockerignore` · `apps/frontend` · `docker-compose.dev.yml` ·
>    `infrastructure/nginx/dev.conf` · `services/agent-api` · `services/mcp-gateway` ·
>    `scripts/start-dev-live.ps1` · `scripts/verify-o4-live-write-browser.cjs` ·
>    `scripts/verify-o4-live-writes.ps1`
>
> **Daraus folgt:** Ein reiner **Doku-Commit nach O4 ist unschaedlich** — er macht den
> Beweis nicht stale. Nur eine Aenderung an einem der neun Pfade zwingt zur Wiederholung
> von A5–A8. (Eine frueher hier stehende Formulierung war zu streng.)
>
> ⚠️ **Haeufigste Ursache fuer ein rotes O4:** `apps/frontend/next-env.d.ts`. Next.js
> schaltet die Zeile beim Build zwischen `./.next/dev/types/routes.d.ts` und
> `./.next/types/routes.d.ts` um. Die Datei ist generiert („should not be edited") — nach
> einem `npm run build` mit `git restore -- apps/frontend/next-env.d.ts` zuruecksetzen,
> sonst blockiert sie den Sauberkeits-Guard.

## A9 · Evidenz binden, Kontroll-Commit, CI

**A9.1 — Evidenzsatz anlegen (Vorbild: RC20 hat exakt 27 Dateien):**

```powershell
$dst = "docs\release-artifacts\$REL-evidence"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
# Die fuenf Kettenberichte + raw-Logs aus
# .codex\runs\CURRENT\master-goal\phase5\production-candidate-local\ hierher kopieren.
# VERBATIM kopieren - niemals nachbearbeiten.
(Get-ChildItem $dst -Recurse -File).Count      # MUSS 27 ergeben (ohne CI-Readback)
```

**A9.2 — `$REL.md` schreiben.** Vorlage 1:1 uebernehmen:
`docs/release-artifacts/prod-candidate-2026-08-28-local-rc20.md`
Ersetzen: `release_id`, `source_commit_sha`, `immutable_image_commit_sha`,
`rollback_target_commit_sha` = `c29c738b…`, `workflow_run_url`, `scope`.
`immutable_tag_publish_status` bleibt **`unpublished`**.

**A9.3 — Kontroll-Commit auf eigenem Branch:**

```powershell
git switch -c codex/source-prequal-<kurz-sha>
# genau EINE Datei aendern: scripts/verify-main-deploy-transition.ps1
git commit --only -m "ci: bind source prequalification to <kurz-sha>" -- scripts\verify-main-deploy-transition.ps1
git push -u origin codex/source-prequal-<kurz-sha>
```

**A9.4 — CI ausloesen.** `gh workflow run` nimmt einen **Ref, keinen SHA**:

```powershell
gh workflow run pr-check.yml --ref codex/source-prequal-<kurz-sha> `
  -f candidate_sha=$SRC -f source_prequalification=true
gh run watch <RUN_ID> --exit-status --interval 20
```

> **Falle:** `source_prequalification=true` verlangt, dass `candidate_sha` sich vom
> Control-SHA **unterscheidet**. Branch-Tip als beides = sofortiger Abbruch
> (`source prequalification requires candidate_sha to differ`).

**A9.5 — Attestation zurueckholen und binden:**

```powershell
gh run download <RUN_ID> -n pr-check-source-checkout-attestation-<RUN_ID>-1 -D D:\_sb_tmp\rc21-attest
Get-FileHash -Algorithm SHA256 D:\_sb_tmp\rc21-attest\ci-source-checkout-attestation.json
```

Kopiere sie nach `$dst\ci-source-checkout-attestation.json` und schreibe
`$REL-readiness.json` (Vorlage: `…-rc20-readiness.json`) mit **allen** SHA-256-Werten.

**A9.6 — Control-Branch zurueckmergen, dann Selection-Commit:**

```powershell
git switch codex/organism-visual-v2
git merge --ff-only codex/source-prequal-<kurz-sha>     # mergen, NICHT cherry-picken
git commit --only -m "release: qualify local RC21 candidate" -- `
  docs\release-artifacts\current-release-candidate.json `
  "docs\release-artifacts\$REL.md" `
  "docs\release-artifacts\$REL-readiness.json" `
  "docs\release-artifacts\$REL-evidence" `
  docs\runtime-state\phase5-credit-itemization.json `
  AI_HANDOFF.md docs\verification-register.md
```

**A9.7 — Abnahme:**

```powershell
npm run verify:phase5-credit               # MUSS gruen: 17/19 = 89%, blockiert nur I1 und I5
npm run verify:current-release-candidate   # gruen; promotion_eligible=false ist KORREKT
git push origin codex/organism-visual-v2
```

**A ist fertig, wenn `verify:phase5-credit` gruen ist.**

---

# AUFGABE B · `github_actions = api_error` untersuchen

`GET /api/v1/clouds` meldet fuer GitHub Actions `status: api_error` bei `configured: true`
(`GITHUB_TOKEN` ist gesetzt). Token da, API-Aufruf scheitert. In derselben Session konnte
sich auch der `github`-MCP-Server nicht verbinden (`CONNECTION_CLOSED`).
**Welche Ursache — nicht gemessen.** Das blockiert L5/L7-Gates.

```powershell
curl.exe -s http://localhost:8081/api/v1/clouds | ConvertFrom-Json |
  Select-Object -ExpandProperty providers | Where-Object id -eq github_actions | ConvertTo-Json -Depth 5
docker logs --tail 200 cloud-superbrain-phase1-dev-agent-api-1 | Select-String -Pattern "github" -Context 0,3
gh auth status
gh api rate_limit
```

**Berichte:** exakter Fehlercode und Ursache. **Niemals den Tokenwert ausgeben.**
Wenn der Token abgelaufen ist: **das ist eine Owner-Entscheidung** — melden, nicht rotieren.

---

# AUFGABE C · Gate-Luecke schliessen — Fuenf-Achsen-Audit in die Kette

`verify:five-axis-audit` und sein Regressionstest haengen **nicht** in
`scripts/verify.suites.json` oder `scripts/verify-phase1.ps1`. Deshalb konnte RC20 gruen
werden, obwohl der Test rot war.

**Erst nach Aufgabe A**, damit die Kette nicht mitten in einer Bindung rot wird:

1. Bestaetigen, dass beide gruen sind.
2. In `scripts/verify.suites.json` als eigenen Eintrag ergaenzen.
3. `npm run verify` einmal vollstaendig fahren — **muss durchlaufen**.
4. Nur wenn gruen: committen. Wird sie rot, **zurueckziehen und berichten**.

---

# AUFGABE D · `PROJECT_STATE.md` nachziehen — nur im Vierer-Uebergang

`PROJECT_STATE.md` ist veraltet (nennt noch **RC14**, Stand `2026-08-27`).

> **⛔ Niemals allein aktualisieren.** Die Datei steht in **beiden** Mengen —
> `RUNTIME_SOURCE_PATHS` **und** `QUALIFICATION_TRUTH_PATHS` — und der erlaubte
> Nachqualifizierungs-Uebergang prueft mit **exakter Mengengleichheit**
> (`scripts/verify_phase5_credit_itemization.py:1160`):
>
> ```python
> require(changed_paths == QUALIFICATION_TRUTH_PATHS, ...)
> ```
>
> Die geforderte Menge ist **genau**:
> ```
> PROJECT_STATE.md
> apps/frontend/lib/endpoint-snapshot.json
> apps/frontend/lib/platform.ts
> docs/project-progress.manifest.json
> ```
> Ein Einzel-Update ergibt eine 1-elementige Menge -> ungleich -> Kandidatenbindung bricht.

**Zwei zulaessige Wege — waehle einen:**

- **(a) Bevorzugt:** `PROJECT_STATE.md` **vor** dem naechsten Source-Freeze aktualisieren,
  also vor A1 des naechsten Kandidaten. Dann ist es Teil der Quelle, kein Uebergang noetig.
- **(b)** Alle **vier** Pfade gemeinsam in **einem** Commit aendern — nur wenn sich die
  Prozente wirklich bewegen und `mode=fully_itemized` gilt.

---

# AUFGABE E · Die neuen Tests einmal in einem gruenen CI-Lauf sehen

CI-Lauf `33187389678` brach am **11. von 27** Schritten ab; **14 Schritte wurden
uebersprungen** — darunter `Generated HTML runnability guard`, `OAuth boundary unit
contract`, `Frontend audit`, `Secret scan` und `Build Phase 1 images`.
**Die neu ergaenzten Tests sind in CI also nie gelaufen.**

Nach Aufgabe A pruefen, ob der CI-Lauf aus A9.4 **alle** Schritte durchlaufen hat:

```powershell
gh api repos/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/<RUN_ID>/jobs `
  --jq '.jobs[0].steps[] | "\(.conclusion)\t\(.name)"'
```

**Kein einziger Schritt darf `skipped` sein.** Ist einer uebersprungen: Ursache benennen.

---

# ⛔ WAS DU NICHT DARFST — Owner-Waende

Diese Punkte sind **keine** Arbeit, sondern Entscheidungen. **Nicht anfassen, nur melden.**

| Gesperrt | Warum |
|---|---|
| GitHub-OAuth-App anlegen (**O1**, P3 +56) | Owner-Konto, Passwort, Scope-Entscheidung |
| `AGENT_API_AUTH_TOKEN` fuer Phase-6-Scale setzen (P6 +10) | Owner-Secret |
| GHCR-Publikation (**O3**, P5 +11) | zyklisch: Push verboten vor `MARKET_READY:true`, das aber GHCR-Digests verlangt |
| L4/L5-Prozente (+45 / +44) | **es gibt keine freigegebene Rubrik** — jede Zahl waere Fake |
| Production-Deploy, Release-Promotion, Default-Branch-Push | Owner-Gate |
| Token rotieren | Der Owner hat das ausdruecklich abgelehnt |
| Zahlung, Kreditkarte, Paid Provider, Fly.io, R2 | Free-Only-Vorgabe |

**Zahlung oeffnet nichts.** `payment_required` ist bei O1/O2/O3 `false`.

**100 % ist derzeit nicht erreichbar** — der gesamte Rest von `overall 89 -> 100` haengt an
diesen Waenden. Setze **nichts** hoch. Melde den Delta ehrlich.

---

# 🎯 DER VOLLSTAENDIGE WEG AUF 100 % — jeder fehlende Punkt

`overall` ist der **Mittelwert der sieben horizontalen Phasen**. Vertikale Layer zaehlen
**nicht** hinein — sie muessen trotzdem auf 100, weil das Endziel beide Matrizen verlangt.

```
overall 89 -> 100 = +11
horizontal offen: P3 +56 · P5 +11 · P6 +10   = 77 Zellpunkte
vertikal   offen: L4 +45 · L5 +44            = 89 Zellpunkte
```

Es gibt **fuenf** Bloecke. Drei kann der Agent **vorbereiten**, aber **keinen** allein
abschliessen. Reihenfolge ist bindend: **V0 zuerst**, sonst sind V1–V4 nicht messbar.

---

## V0 · L4/L5-RUBRIK — sie EXISTIERT NICHT und blockiert 89 Zellpunkte

**Befund:** Im ganzen Repo gibt es **keine** freigegebene Bewertungsrubrik fuer
`layer_4` (55 %) und `layer_5` (56 %). Ohne sie ist **jede** Prozentzahl dort eine
Erfindung. Das ist der groesste einzelne Blocker — und der einzige, bei dem der Agent
echte Vorarbeit leisten kann.

**Agent-Aufgabe (Entwurf, KEINE Prozente setzen):**

Lege `docs/runtime-contracts/layer-credit-rubric.md` an. Fuer L4 und L5 je eine Tabelle:

| Feld | Inhalt |
|---|---|
| Kriterium | genau eine pruefbare Faehigkeit |
| Punkte | Summe pro Layer **exakt 100** |
| Beweisart | Unit · Runtime · Browser · Hosted |
| Verifier | konkreter Skriptpfad, der es misst |
| Aktueller Stand | erfuellt / offen — **mit Beleg** |

Vorschlag als Startpunkt (Owner darf jede Zahl aendern):

```
L4 LLM Gateway (+45):
  Hosted Gateway erreichbar                10
  Stream + Non-Stream Parity               10
  Routing / Fallback / Budget              10
  Audit + Trace vollstaendig                8
  Negative Guards (401/403/422/oversize)    7

L5 MCP Gateway (+44):
  Hosted MCP Write                         10
  Auth / Scope / Timeout / Idempotenz      10
  Audit / Readback / Rollback              10
  Registry / SBOM / Scan                    8
  Geschuetzter Workflow                     6
```

**Danach:** Owner gibt die Rubrik frei -> **erst dann** darf ein Verifier Punkte vergeben,
und zwar **aus Evidenz berechnet**, nie von Hand eingetragen.

> **Ohne diesen Schritt sind L4 und L5 dauerhaft blockiert.** Es gibt keinen Umweg.

---

## V1 · P3 +56 — GitHub-OAuth-Identitaet (`production_auth_identity`, **O1**)

**Blockiert weil** `I5` woertlich verlangt: *"Complete the GitHub OAuth
consent/configuration and run the hosted fail-closed auth verifier."*

**Zuerst eine Architekturentscheidung des Owners** — der heutige Vercel-Ursprung ist
read-only und kann O1 **nicht** erfuellen:

- (a) Cloudflare-native stateful im Zero-card-Modell, **oder**
- (b) gehosteter Agent-API-Stack mit PostgreSQL + Redis im Budgetrahmen

**Owner-Klickfolge (nur der Owner, niemals der Agent):**

1. GitHub -> Profilbild -> **Settings** -> **Developer settings** -> **OAuth Apps**
   -> **New OAuth App**
2. Homepage: exakter Hosted-Ursprung
3. Callback: `https://<AUTH_PUBLIC_ORIGIN>/api/v1/auth/callback`
4. **Register application**, dann Client Secret erzeugen
5. **Scope ausschliesslich `read:user`** — keine E-Mail-, Repo- oder Org-Scopes
6. Secret **niemals** in Chat, Repo, Screenshot oder DevTools

**Vier Variablennamen** (Werte nur in den Secret Store des Auth-Runtimes):

```
GITHUB_OAUTH_CLIENT_ID · GITHUB_OAUTH_CLIENT_SECRET
GITHUB_OAUTH_REDIRECT_URI · JWT_SIGNING_SECRET
```

**Abnahme = 10 echte Browserschritte, alle muessen halten:**

1. Privates Fenster, `/login` -> Mit GitHub anmelden
2. Erster Versuch **Cancel** -> erwartet `401`, State geloescht, keine Session
3. Zweiter Versuch: Scope zeigt **nur** `read:user`
4. Owner klickt **Authorize** (Passwort/2FA/CAPTCHA macht **nur** der Owner)
5. Callback beweist echte GitHub-ID + konsumierten One-Time-State + persistiertes Audit
6. Reload -> dieselbe Session
7. Refresh **rotiert** das Refresh-Cookie
8. Replay des alten Tokens -> `401`
9. Callback-Replay scheitert
10. Logout widerruft Refresh, loescht Cookies, persistiert Audit

---

## V2 · P5 +11 — `I1` hosted staging **und** `I5` production auth

**`I1`** woertlich: *"Candidate-bound hosted staging verified over non-local HTTPS"* —
Owner-Aktion: *"Authorize and provide the candidate-bound hosted staging surface; then run
the hosted candidate verifier."*

Konkret: **exakt dieselben Images/Digests** des Kandidaten laufen auf einer
**nicht-lokalen HTTPS-Flaeche**, und dort ist mehr gruen als nur Health:

- Health exakt `200`, keine Redirects, Body `healthy`, **Source-SHA stimmt**
- Build-Klick: UI -> Agent API -> LLM Gateway -> echter Provider, persistiert
- Run oeffnet echtes HTML/Three.js/WebGL; Klick/Tastatur veraendert DOM **oder** Pixel
- Reload liefert **denselben** Artefakt-Hash
- 22/22 Routen, 161 Aktionen, keine toten Controls
- D1: Create -> Readback -> Queue/DO -> Konflikt -> Delete -> `404`
- **Negative Ergebnisse sind Pflicht:** Unauthorized `401`, Main-Write `403`,
  Konflikt `409`, Oversize-Guard. **Nicht alles darf `200` sein.**
- Dieselbe Request-ID korreliert in Activity, Audit, Session, Observe und Evidence
- Null Console-/Page-Errors

**Zusaetzlich echter Rollback vor jeder Production-Aussage:** auf Last-known-good-Digests
zurueck, **dieselbe** semantische Aktionskette erneut gruen, Rollback-Audit gespeichert,
danach Candidate wiederherstellen und erneut pruefen.

**`I5`** = V1 (OAuth) plus Branch-Protection- und Secret-Gates.

---

## V3 · P6 +10 — `AGENT_API_AUTH_TOKEN` und der 900-Request-Beweis

**Owner setzt genau ein Secret.** Danach ein einziger Zero-card-Lauf mit **exakt 900**
Worker-Requests:

```
 60 Reads @ Concurrency 1
240 Reads @ Concurrency 10
500 Reads @ Concurrency 50
 50 POST /api/v1/builds @ Concurrency 10  -> serverseitiger D1-Readback pro Record
 50 authentifizierte DELETEs
------------------------------------------
900 Requests gesamt
```

**Schwellen (aus `docs/runtime-state/phase6-scale-criterion.json`):**

| Kriterium | Wert |
|---|---|
| Erfolgsquote | ≥ 0,99 |
| schlechtester p95 | ≤ 1500 ms |
| eigene 5xx | **exakt 0** |
| Records | 50 erstellt · 50 eindeutig · 50 geloescht |
| Verlust / Duplikate | 0 / 0 |
| Cleanup | `soft_delete_then_active_row_absence_and_audit_readback` |
| Audit | persistiert · Evidence SHA-256-gebunden |

Kommando (erst nach Owner-Freigabe):

```powershell
. .\scripts\import-local-env.ps1 -Quiet
pwsh -NoProfile -File .\scripts\verify-phase6-scale-runtime.ps1 `
  -CriterionPath .\docs\runtime-state\phase6-scale-criterion.json `
  -BaseUrl 'https://<worker-url>' -AllowHostedWrites
```

**Ohne das Flag: null Requests, `Blocked` = exit 2.** Der Token bleibt ausschliesslich im
privaten Prozess-Environment. **Ein Browser-Klick kann diesen Beweis nicht ersetzen.**

---

## V4 · O3 — GHCR-Deadlock, den nur der Owner brechen kann

**Der Zyklus:** Registry-Push ist verboten vor `MARKET_READY:true` — aber
`MARKET_READY:true` verlangt GHCR-Digests. **Das loest sich nicht von selbst.**

**Owner richtet ein:**

1. GitHub -> **Settings** -> **Environments**
2. `registry-publication` anlegen, **Required Reviewer** setzen
3. `production` separat anlegen, **Required Reviewer** setzen
4. Nach gemergtem Transition-PR: **Actions** -> gehaerteter Workflow -> **Run workflow**
   -> exakter Release-Ref -> `candidate`
5. **Review deployments** -> `registry-publication` -> **Approve and deploy**

**Danach muss fuer alle sechs Services ein Remote-Digest existieren:**
`frontend · agent-api · agent-worker · memory-worker · mcp-gateway · llm-gateway`

Pakete **privat** lassen — `public` ist irreversibel und eine eigene Owner-Entscheidung.
**Ein GHCR-Push ist noch kein Deployment.**

---

## 📋 ZUSAMMENFASSUNG — wer muss was tun

| Block | Delta | Agent kann vorbereiten | Nur Owner |
|---|---:|---|---|
| **V0** Rubrik L4/L5 | +89 vert. | **Ja** — Rubrik entwerfen, Verifier bauen | Rubrik **freigeben** |
| **V1** O1 OAuth | P3 +56 | Auth-Pfad implementieren, Verifier | Architekturentscheidung · App anlegen · 10 Klicks |
| **V2** I1 + I5 | P5 +11 | Hosted-Verifier vorbereiten | Hosted-Flaeche autorisieren + bereitstellen |
| **V3** P6 Scale | P6 +10 | Verifier ist fertig | **ein Secret** setzen |
| **V4** O3 GHCR | P5-Anteil | Transition-Workflow haerten | Environments + Approve |

**Zahlung oeffnet keinen dieser Punkte.** `payment_required` ist bei O1/O2/O3 `false`;
eine im Manifest abgebildete Zahlung macht `owner-input-matrix` sogar **rot**.

> **Realistische Reihenfolge:** V0 -> V3 -> V1 -> V2 -> V4.
> V0 zuerst, weil es 89 vertikale Zellpunkte freischaltet und ausser einer Entscheidung
> **keine** externe Freigabe braucht. V3 danach, weil es nur **ein** Secret kostet.

---

# ✅ ABNAHME — woran du erkennst, dass du fertig bist

| Nr | Kriterium | Beleg |
|---|---|---|
| 1 | `npm run verify:phase5-credit` gruen | `verified 17/19 = 89%`, blockiert nur `I1`,`I5` |
| 2 | `npm run verify:current-release-candidate` gruen | `promotion_eligible=false` ist korrekt |
| 3 | Evidenzsatz vollstaendig | 27 Dateien + CI-Readback |
| 4 | CI gruen, **kein** Schritt `skipped` | `gh api …/jobs` |
| 5 | Browser-Beweis | `routes=22 families=29 members=161 direct=160` |
| 6 | Produktabnahme | `live_provider_calls=true`, echter `build_id` |
| 7 | Build | `21/21` Seiten |
| 8 | Fremde Dateien unveraendert | RC12 weiter **gestaged**, O4-Proofs weiter dirty |
| 9 | `git status --porcelain | Select-String '^ D'` leer | keine geloeschte tracked Datei |
| 10 | Gepusht — **nur** `codex/organism-visual-v2` | `HEAD == origin` |

**Abschlussbericht enthaelt:** die 10 Kriterien mit Ja/Nein, den neuen Kandidaten-SHA, die
CI-Run-ID, und **ausdruecklich** was **nicht** lief und warum.

---

*Erstellt 2026-08-28 auf HEAD `abead9ac`. Jeder Wert hier ist gemessen, keiner geschaetzt.
Bindende Regeln: `REGELN_OPTIK_UND_FERTIG.md`. Ziel-Datei: `CODEX_ZIELVERFOLGUNG_KURZ.md`.*

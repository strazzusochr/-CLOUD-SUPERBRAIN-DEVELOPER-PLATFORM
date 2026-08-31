# CODEX ZIEL-MASTER — MARKTREIFE-ZIELVERFOLGUNG

Status: `ACTIVE_CURRENT_TRUTH`
Stand: **2026-08-31**
Branch: `codex/organism-visual-v2`
Qualification Source: **`1cb03979740859f0350cf18f6f08ef06c3d72b72`**; Control: **`d016e4b928290d8fa358522af08609ae80aeb1cc`**
Market Status: `MARKET_READY:false` — Overall `89`

**Dies ist die einzige Zieldatei.** Sie sagt, *was zu tun ist*.
Die Lage steht in `CODEX_UEBERGABE_MASTER_2026-08-29.md`.

> Der Dateiname bleibt bewusst auf `2026-08-29` stehen, damit Codex genau eine Zieldatei und
> genau eine Uebergabe findet. Massgeblich ist das Feld `Stand` oben.

**Vorrangregel.** Im Repository liegen aus historischen Gruenden weitere `CODEX_*.md`.
Gueltig sind ausschliesslich diese beiden Dateien. Ausdruecklich ueberholt und im Kopf
entsprechend markiert sind `CODEX_100_PROZENT_ZIEL_2026-08-29.md`,
`CODEX_ZIELVERFOLGUNG_KURZ.md`, `CODEX_UEBERGABE_2026-08-29-SESSION16.md`,
`CODEX_MASTER_GOAL_AUTONOM_WEITER.md` und `CODEX_MASTER_GOAL_FINALE.md`. Alle uebrigen
`CODEX_UEBERGABE_2026-0[478]-*.md` sind aeltere Sessionprotokolle ohne Weisungscharakter.

---

## 0. RC24-Zielcheckpoint — 2026-08-31

RC24 ist lokal source-gebunden qualifiziert: fuenf Ketten gruen, exaktes 27-Dateien-Set,
CI `33359506266` mit `30/30`, Browser `22/22` Seiten, `29/29` Funktionsfamilien und
`161/161` Aktionen. Der Auswahluebergang ist fail-closed als
`no_credit_requalification` akzeptiert. Dadurch steigt kein Fortschritt: Overall `89`,
P3 `44`, P5 `89`, P6 `90`, L4 `55`, L5 `56`; I1/I5 bleiben null Kredite und
`MARKET_READY:false`.

Naechster autonomer Schritt ist nur der Abschluss des lokalen Gate-Stacks, exakter Commit,
Feature-Branch-Push und final-head CI. Danach bleiben ausschliesslich echte, explizit
freigegebene hosted Beweise und die sanktionierte Delta-Ledger-Buchung auf dem Weg zu 100.
Kein lokaler RC24-Beweis darf als hosted, Production-Deploy, Promotion, Registry-Push,
Produktions-OAuth oder Marktfreigabe umgedeutet werden. `DEV-ONLY; hosted proof still
blocked`.

---

## 1. Endziel

`npm run verify:market-ready` druckt real:

```text
MARKET_READY: true
```

Dafuer muessen beide Matrizen **evidenzbasiert** 100 sein. Production-Deploy und
Release-Promotion bleiben danach **separate** Owner-Entscheidungen.

---

## 2. Restdelta

```text
Horizontal:  P0 100 | P1 100 | P2 100 | P3 44 | P4 100 | P5 89 | P6 90
Vertikal:    L1 100 | L2 100 | L3 100 | L4 55 | L5 56 | L6 100 | L7 100
Delta-Ledger: 0 Eintraege
```

| Zelle | Rest | Was den Rest wirklich blockiert |
| --- | ---: | --- |
| P3 | **+56** | Code ist fertig und deployfaehig. Es fehlt der **echte Authorize-Beweis** im Browser. |
| P5 | **+11** | `I5` faellt automatisch nach dem P3-Beweis. `I1` braucht Hosted-Candidate-Paritaet **plus** eine Codeaenderung. |
| P6 | **+10** | Der vorhandene 900er-Lauf ist kriterien-unvollstaendig. Wiederholung mit dem zugelassenen Verifier noetig. |
| L4 | **+45** | Fuenf Verifier existieren nur als Geruest und beweisen nichts. Neu schreiben. |
| L5 | **+44** | Dito, plus ein echtes SBOM. |

**166 offene Punkte.** `overall = round(sum(7 Phasen)/7)` — Layerarbeit (L4/L5) bewegt die
89 **nie**; sie ist trotzdem Pflicht fuer die vertikale 100.

---

## 3. Kritischer Pfad

```text
D0  Worker-Deploy (F1+F2 scharfschalten)  ── Voraussetzung fuer ALLES Hosted
     │
     ├─> D1  OAuth-Browserkette ──> P3 +56 ──> P5-I5
     │        (braucht Owner: Passwort + 2FA)
     │
     ├─> D2  RC24 einfrieren + qualifizieren ──> P5-I1 (+ Codeaenderung)
     │
     ├─> D3  10 Verifier neu schreiben ──> L4 +45, L5 +44
     │
     └─> D4  P6-Scale mit echtem Verifier ──> P6 +10
                     │
                     └─> D5  Delta-Ledger buchen ──> D6  Final-Stack ──> MARKET_READY
```

**Engpass:** `D0`. Ohne ihn ist der Worker weiterhin auf die falsche Redirect-URI
konfiguriert und ohne Source-Bindung — dann sind D1 und D2 unmoeglich.

---

## 4. Die Stufen im Detail

### D0 — Worker-Deploy: F1 und F2 scharfschalten

**Zustand:** Beide Fixes sind in `4adb250c` committet und per Dry-Run validiert
(13/13 Bindings, beide Source-Vars, korrigierte Redirect-URI). Sie sind **noch nicht live**.

**Aktion — genau ein Befehl:**

```powershell
Set-Location 'D:\_sb_tmp\clean-head-7f181868'
$env:TEMP='D:\_sb_tmp'; $env:TMP='D:\_sb_tmp'
Get-Content 'C:\Users\immer\.codex\secrets\cloud-superbrain.local.env' | ForEach-Object {
  if ($_ -match '^(CLOUDFLARE_API_TOKEN|CLOUDFLARE_ACCOUNT_ID)=(.*)$') {
    Set-Item -Path "env:$($Matches[1])" -Value ($Matches[2].Trim().Trim('"').Trim("'"))
  }
}
pwsh -NoProfile -File .\scripts\deploy-cloudflare-stateful-runtime.ps1
```

**Nie wieder `wrangler deploy` direkt aufrufen** — das hat F2 verursacht.

**Abnahme (das Skript prueft es selbst).** Es deployt standardmaessig `HEAD` und berechnet
`SOURCE_ARCHIVE_SHA256` daraus neu; die folgenden Werte gelten fuer `4adb250c` und aendern
sich mit jedem weiteren Commit — entscheidend ist, dass Health **exakt den deployten
Commit** meldet:

```text
/api/v1/health   source_commit_sha     = 4adb250c9948f9728c477eaabfc5964252b5707b
                 source_archive_sha256 = 60c43b638f3ed6fd43162ae906c99c0781ff8289bf08d64333b0ec63269f118e
/api/v1/auth/github  Location enthaelt
                 redirect_uri = https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev/api/v1/auth/callback
```

**Kredit:** keiner. D0 ist reine Voraussetzung.

**Erwartung daempfen:** `/api/v1/project/progress` bleibt danach bei `84`. Der Worker hat
keine native Progress-Route und reicht an den degradierten `CONTRACT_ORIGIN` durch. Das ist
ein eigener Punkt (§6), kein Fehler des Deploys.

---

### D1 — OAuth-Browserkette: P3 +56 und P5-I5

**Voraussetzung:** D0 gruen.

**Vorher pruefen:** Die GitHub-OAuth-App muss als Callback exakt
`https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev/api/v1/auth/callback`
fuehren, Scope nur `read:user`, Wildcard-Matching aus. Weicht das ab, scheitert die Kette an
`redirect_uri_mismatch` — genau der Fehler aus F1.

**Die Kette, in privatem Fenster, mit echten Klicks:**

1. `/login` -> „Mit GitHub anmelden" -> **Cancel**. Erwartet: `401`, State geloescht, keine
   Session.
2. Erneut starten. Der Consent-Screen darf **nur** `read:user` zeigen.
3. **Owner klickt Authorize selbst** — Passwort und 2FA bleiben beim Owner.
4. Callback muss beweisen: echte numerische GitHub-ID, konsumierter One-Time-State,
   persistiertes Audit **vor** der Credential-Ausgabe.
5. `/api/v1/auth/me` liefert die Identitaet; Reload behaelt die Session.
6. `POST /api/v1/auth/refresh` rotiert. Der **alte** Refresh-Token danach -> `401`
   `auth_refresh_reuse_blocked`, die Familie ist widerrufen.
7. Callback-Replay mit demselben State scheitert.
8. `POST /api/v1/auth/logout` widerruft die Familie, loescht beide Cookies; Refresh danach
   `401`.

**Evidence:** SHA-256-gebunden ablegen, Audit-Kette request-/session-korreliert, **ohne**
Codes, State, Tokens, Cookies oder Secrets im Klartext.

**Kredit:** P3 `44 -> 100` gegen `docs/runtime-contracts/phase3-credit-rubric.md`
(P3-01 bis P3-08, Summe 56) — **erst nach B1-Freigabe der Rubrik**. Danach faellt `I5`
automatisch, weil `expected_blocked_ids` es rein evidenzgetrieben behandelt
(`verify_phase5_credit_itemization.py:290`). P5 geht damit auf `95` (18/19).

---

### D2 — RC24 einfrieren und qualifizieren: P5-I1

**Warum noetig:** RC23 zeigt auf `7db18d90`. Mit `9ec4741f` ist neuer **Produktquellcode**
dazugekommen (722 Zeilen OAuth, Migration 0005). RC23 kann I1 nicht mehr tragen.

**Aktion:**

1. Kandidaten an dem SHA einfrieren, der auch deployt ist (`4adb250c` oder spaeter).
2. Die fuenf Ketten fahren: sechs Clean-Archive-Images, Runtime `10/10`, Browser-Umbrella,
   Candidate-Runtime mit realer Auswahl und Klick, Candidate-Archiv npm-audit + gitleaks.
3. Evidence-Set (27 Dateien) neu binden, `current-release-candidate.json` umstellen.
4. Kontroll-Commit + CI mit `conclusion=success`, `skipped=0`, Source-Attestierung auf den
   eingefrorenen SHA.
5. Kandidatgebundenes Hosted-Staging mit **denselben** Digests -> das ist I1.

**Danach — und nur danach — die Codeaenderung:**

```python
# scripts/verify_phase5_credit_itemization.py:44
BASELINE_BLOCKED_IDS = set()      # war: {"I1"}
```

Ohne diese Aenderung bleibt `expected_percent` bei 95 und
`require(computed_percent == expected_percent)` schlaegt fehl. Fuer `I5` gilt das **nicht** —
dort genuegt der Beweis.

**Kredit:** P5 `95 -> 100` (19/19).

---

### D3 — Die zehn Verifier neu schreiben: L4 +45, L5 +44

**Ausgangslage:** Die zehn Dateien in `scripts/` sind als `NOT CREDIT-BEARING` markiert und
schreiben `status="scaffold_not_credit_bearing"` mit `credit_eligible=false`. Sie sind
Geruest, kein Beweis (Details in der Uebergabe §5).

**Beide Ziel-Gateways sind live** und antworten `200`:

```text
https://cloud-superbrain-llm-gateway-preview.strazzusochr.workers.dev/api/v1/health  -> service=llm-gateway
https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev/mcp/api/v1/health -> service=mcp-gateway
```

Echte Verifier sind also baubar. Jeder muss: einen **erfolgreichen** Hosted-Aufruf machen,
das Ergebnis gegen das Rubrikkriterium pruefen, fail-closed sein und Evidence
SHA-256-gebunden schreiben. Ein `401` auf einen Dummy-Token ist kein Beweis.

| Punkte | L4 (LLM Gateway) | Punkte | L5 (MCP Gateway) |
| ---: | --- | ---: | --- |
| 10 | Stream vs. Non-Stream Paritaet — **echter Stream noetig** | 10 | Hosted-Write — **echter Write + Readback** |
| 7 | Negative Guards | 10 | Audit-Readback + Rollback |
| 4 | Trace-Korrelation | 6 | Auth-Scope |
| 3 | Fallback | 4 | Timeout + Idempotenz |
| 3 | Budget-Guard | 3 | SBOM **erzeugen** (nicht Pins pruefen) |
| 10 | generativer Hosted-Beweis | 11 | Digest + Scan + approvierter Lauf |
| 8 | Routing + Audit nach Rebind | | |

**Kredit:** L4 `55 -> 100`, L5 `56 -> 100` gegen
`docs/runtime-contracts/layer-credit-rubric.md` — **erst nach B1-Freigabe**.

---

### D4 — Phase-6-Scale mit dem zugelassenen Verifier: P6 +10

**Voraussetzung:** Gate `phase6_scale_runtime` offen; GitHub-Environment
`phase6-scale-hosted-writes` existiert **und** enthaelt das Secret `AGENT_API_AUTH_TOKEN`;
`.github/workflows/phase6-scale-runtime.yml` liegt auf dem **Default-Branch**.

**Der vorhandene Lauf zaehlt nicht.** Er lief am Verifier vorbei und liefert keinen
D1-Readback, keine No-Loss/No-Duplicate-Zaehlung, keine Cleanup-Semantik und kein
Control-Tier.

**Aktion:** `scripts/verify-phase6-scale-runtime.ps1 -AllowHostedWrites` gegen
`docs/runtime-state/phase6-scale-criterion.json` (v2):

```text
Reads   60 @ concurrency 1 | 240 @ 10 | 500 @ 50
Writes  50 x POST /api/v1/builds @ 10, serverseitiger D1-Readback je Record
Deletes 50 authentifiziert, soft_delete_then_active_row_absence_and_audit_readback
Control /cdn-cgi/trace, separates Budget, max 500
Gesamt  exakt 900 Worker-Requests
```

Bestehen: Quote ≥ `0.99`, p95 ≤ `1500 ms`, eigene 5xx = `0`, 50 erstellt / eindeutig /
geloescht, Verlust `0`, Duplikate `0`, Cleanup vollstaendig, Audit persistiert, Evidence
SHA-256-gebunden. `429` ist **nur** auf Health-Read-Tiers zulaessig und muss fail-closed
sein.

Der Token gehoert ausschliesslich ins Prozess-Environment — nie in Ausgabe, Log oder Commit.

**Kredit:** P6 `90 -> 100`.

---

### D5 — Delta-Ledger buchen

`docs/runtime-state/project-progress-delta-ledger.json` ist der **einzige** zugelassene Weg,
eine Manifestzelle zu bewegen. `entries = 0`, `baseline.source_sha = 9a3776ff`. Der
Mechanismus ist bis heute **nie** erprobt worden — der erste echte Kredit ist zugleich sein
erster Test. Vorher einen synthetischen Probeeintrag mit Negativfaellen fahren (falscher
`source_sha`, falscher Projection-Hash, Zelle ausserhalb 0–100, Summe passt nicht zu
`overall`) und danach wieder entfernen.

Je bewegter Zelle **ein** SHA-gebundener Eintrag. Danach muss
`py -3 scripts/verify_project_progress_manifest.py` die neuen Werte akzeptieren.

**Niemals** einen Prozentwert direkt im Manifest setzen.

---

### D6 — Abschluss-Stack, streng seriell

```powershell
Set-Location 'D:\_sb_tmp\clean-head-7f181868'
$env:TEMP='D:\_sb_tmp'; $env:TMP='D:\_sb_tmp'; $env:PYTHONUTF8='1'

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

Zielausgabe muss **real** sein: `MARKET_READY: true`, Overall `100`, alle Zellen `100`,
Ledger enthaelt die legitimen Eintraege, Hosted-SHA = Truth-HEAD, keine `OWNER_BLOCKED`
mehr.

---

## 5. Owner-Gates — was nur der Owner erteilen kann

| Gate | Entscheidung | Blockiert |
| --- | --- | --- |
| **B1** | Die drei Rubriken freigeben (`DRAFT_OWNER_APPROVAL_REQUIRED` -> approved, Freigabecommit benennen) | P3 +56, P6 +10, L4 +45, L5 +44 |
| **B2** | OAuth-ADR festschreiben (Cloudflare-native ist implementiert und deployfaehig) | Dokumentationslage |
| **B3** | Environment `phase6-scale-hosted-writes` anlegen, Secret `AGENT_API_AUTH_TOKEN` setzen, Workflow auf den Default-Branch bringen | P6 +10 |
| **B4** | Gehaerteten `main-deploy`-Blob auf den Default-Branch bringen, dann Candidate dispatchen und `registry-publication` freigeben | GHCR / letztes External Gate |
| **B5** | Hosted-Deploy-Freigabe fuer Worker **und** Contract-Origin | D0, D2, §6 |

Zu **B4**: **kein Deadlock.** `scripts/verify-main-deploy-transition.ps1:63` fuehrt
`market_ready` in der Liste **verbotener** Tokens. Die Kandidatenpublikation setzt
`MARKET_READY:true` also nicht voraus.

### Drei Wände, die keine Freigabe verschiebt

1. **Der GitHub-Authorize-Klick** braucht Passwort und 2FA des Owners. Nicht delegierbar.
2. **Secret-Werte in Konsolen-Felder eintippen** ist einem Agenten kategorisch untersagt.
3. **Die Deploy-Sperre der Claude-Code-Harness** — sie hat D0 zweimal geblockt. Der Owner
   loest sie per Permission-Regel oder fuehrt den Befehl aus §D0 selbst aus.

---

## 6. Der offene Architekturpunkt: die hosted `84`

`/api/v1/project/progress` liefert hosted `84` statt `89` — und **kein Worker-Deploy aendert
das**. Der Worker hat keine native Progress-Route; alles Unbekannte faellt auf
`CONTRACT_ORIGIN` durch (`src/index.js:2011`), hart verdrahtet auf
`cloud-superbrain-developer-platform.vercel.app`, der selbst `status=degraded` und `84`
meldet.

Zwei saubere Wege, beide Owner-Entscheidung:

- **A** — den Contract-Origin source-gebunden neu deployen, oder
- **B** — eine native Progress-Projektion in den Worker bauen und `CONTRACT_ORIGIN` fuer
  diese Route nicht mehr benutzen.

Bis dahin gilt: hosted `84` ist **kein Defekt des Workers**, sondern ein bekannter,
dokumentierter Origin-Rueckstand.

---

## 7. Schutzregeln — bindend

- nie `git add -A`; immer exakte Pathspecs; nie `git commit` ohne Pathspec
- kein `git stash`, kein Force-Push, kein Push auf `chore/repo-bootstrap`
- Playwright, Docker-Build und Verifier **nie parallel**
- keine Frontend-Datei aendern, waehrend ein Browserlauf laeuft
- Evidence nie nachbearbeiten; `.phase1-artifacts/` und `docs/release-artifacts/` nie
  aufraeumen
- `live_verified` **niemals** von Hand setzen
- Verifier **nie** abschwaechen, um gruen zu werden
- keine Secrets in Ausgabe, Log oder Commit
- fremde Dirty-Pfade weder stagen noch zuruecksetzen
- Worker **nur** ueber `scripts/deploy-cloudflare-stateful-runtime.ps1` deployen
- `PYTHONUTF8=1` vor jedem Python-Verifier
- solange ein RC eingefroren ist: kein neuer Produktcode-Commit, sonst driftet der Kandidat

---

## 8. Was ausdruecklich verboten bleibt

Ein Kredit ohne den zugehoerigen echten Beweis ist **Fake-Done** und zerstoert genau das,
was dieses Projekt ausmacht. Konkret heute:

- Die zehn Verifier-Geruste **nicht** fuer L4/L5 kreditieren.
- Den vorhandenen 900er-Lauf **nicht** fuer P6 kreditieren.
- `production_auth_identity` **nicht** oeffnen, bevor der Authorize-Klick real erfolgt ist.
- `BASELINE_BLOCKED_IDS` **nicht** leeren, bevor I1 wirklich belegt ist.
- Keinen Prozentwert direkt im Manifest setzen — ausschliesslich ueber den Delta-Ledger.

`MARKET_READY:false` · `DEV-ONLY; hosted proof still blocked.`

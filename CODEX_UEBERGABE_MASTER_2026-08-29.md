# CODEX UEBERGABE-MASTER

Status: `ACTIVE_CURRENT_HANDOFF`
Stand: **2026-08-31**
Branch: `codex/organism-visual-v2`
Qualification Source: **`1cb03979740859f0350cf18f6f08ef06c3d72b72`**; Control: **`d016e4b928290d8fa358522af08609ae80aeb1cc`**
Market Status: `MARKET_READY:false` — Overall `89`

**Dies ist die einzige Uebergabe.** Sie sagt, *was los ist*.
Was zu tun ist, steht in `CODEX_ZIEL_MASTER_2026-08-29.md`.

> Der Dateiname bleibt bewusst auf `2026-08-29` stehen, damit Codex genau eine Uebergabe
> und genau eine Zieldatei findet. Massgeblich ist das Feld `Stand` oben.

**Vorrangregel.** Im Repository liegen aus historischen Gruenden weitere `CODEX_*.md`.
Gueltig sind ausschliesslich diese beiden Dateien. Ausdruecklich ueberholt und im Kopf
entsprechend markiert sind `CODEX_100_PROZENT_ZIEL_2026-08-29.md`,
`CODEX_ZIELVERFOLGUNG_KURZ.md`, `CODEX_UEBERGABE_2026-08-29-SESSION16.md`,
`CODEX_MASTER_GOAL_AUTONOM_WEITER.md` und `CODEX_MASTER_GOAL_FINALE.md`. Alle uebrigen
`CODEX_UEBERGABE_2026-0[478]-*.md` sind aeltere Sessionprotokolle ohne Weisungscharakter.

Alles hier ist **gemessen** — live gegen den Endpunkt oder gegen den Quellcode am
Truth-HEAD. Wo etwas nur protokolliert und nicht nachmessbar war, steht das ausdruecklich
dabei.

## RC24-Aktualisierung — 2026-08-31

`prod-candidate-2026-08-31-local-rc24` ist lokal qualifiziert und ausgewaehlt. Die
eingefrorene Quelle ist `1cb03979740859f0350cf18f6f08ef06c3d72b72`, der
Source-Attestation-Control ist `d016e4b928290d8fa358522af08609ae80aeb1cc`. Der exakte
Source-Lauf `33359506266` ist mit `30/30` beobachteten Schritten, `0` skipped und `0`
failed gruen. Das unveraenderliche Set enthaelt exakt 27 Evidence-Dateien.

Fuenf lokale Ketten sind gruen: sechs Candidate-Images, Runtime `10/10 healthy`, Security,
Candidate-Runtime mit echter Browserauswahl/einem echten Klick und der komplette
Browserlauf mit `22/22` Seiten, `29/29` Funktionsfamilien und `161/161` Aktionen. Die
Auswahl ist ausschliesslich als exakter Fuenf-Pfad-`no_credit_requalification`-Uebergang
zulaessig. Sie erhoeht keinen Kredit: P5 bleibt `17/19 = 89`, I1/I5 bleiben blockiert,
Overall bleibt `89`, Delta-Ledger `0`, `MARKET_READY:false`. RC23-Quelle `7db18d90` ist
Rollback. `DEV-ONLY; hosted proof still blocked`.

Selection `378a66bfeb5d8685805a35e55ae825b2ce3a1503` ist auf den Feature-Branch
gepusht. `pr-check` `33369934779` lief exakt darauf und bestand `30/30`, `0` skipped,
`0` failed. Der sichtbare In-App-Zweitcheck lud `22/22` Seiten mit HTTP `200`, fuehrte
`22/22` echte sichere Navigationsklicks aus und meldete `0` Console-Errors; er ist
supplementaer und vergibt keinen Kredit.

Hosted read-only ist Worker `bc0f4dc8`: Health `200`, Progress `84`, Team
`200`/`external_degraded`, Auth `verified_identity_fail_closed`. Er liegt acht Commits
hinter RC24-Source. Alle zehn L4/L5-Hosted-Verifier existieren jetzt als echte Skripte;
ohne Rubrikfreigabe, Source-Rebind und reale Hosted-Laeufe bleiben L4/L5 trotzdem bei
`55/56`. Diese RC24-Messung ersetzt entgegenstehende historische Aussagen weiter unten.

Truth-Doku-Measurement-Ref `8adb6183` wurde lokal fast-forward integriert und durch
`pr-check` `33391613008` auf exakt diesem SHA mit `30/30`, `0` skipped und `0` failed
verifiziert. Der Delta-Ledger-Protokoll-Probelauf bestand lokal `27/27`; alle geforderten
Negativfaelle greifen, waehrend das reale Ledger bei `entries=0` und alle Prozente
unveraendert bleiben. Die nachfolgende reine Doku-Synchronisation gilt ueber die bestehende
dynamische Regel: Remote-Feature-Head muss exakt dem neuesten erfolgreichen `pr-check`
mit `skipped=0` und `failed=0` entsprechen.

Die folgenden historischen Abschnitte bleiben als Diagnoseverlauf erhalten. Fuer den
aktuellen Kandidaten und die aktuellen Non-Claims haben diese RC24-Aktualisierung,
`PROJECT_STATE.md`, `AI_HANDOFF.md` und der Verification Register Vorrang.

---

## 1. Koordinaten

| Groesse | Wert |
| --- | --- |
| Truth-Doku-Measurement | `8adb6183` — `pr-check` `33391613008`, `30/30`, `0` skipped/failed |
| Selection-Head | `378a66bf` — gepusht, `pr-check` `33369934779` `30/30` gruen |
| RC24 Source / Control | `1cb03979` / `d016e4b9` |
| Hosted Worker | `cloud-superbrain-stateful-runtime.strazzusochr.workers.dev` |
| Hosted Source | `bc0f4dc8` — acht Commits hinter RC24-Source; Progress `84` |
| Aktiver RC-Zeiger | RC24 `prod-candidate-2026-08-31-local-rc24` @ `1cb03979`; RC23 ist Rollback |
| D1 | `cloud-superbrain-state-prod` (`91520f43-5d38-4a31-9d5a-6fca890e1dd6`), Migrationen 0001–0005 angewandt |
| Overall | `89` — `deltas=0`, Phase 5 `17/19`, blockiert `I1`, `I5` |

```text
Horizontal:  P0 100 | P1 100 | P2 100 | P3 44 | P4 100 | P5 89 | P6 90
Vertikal:    L1 100 | L2 100 | L3 100 | L4 55 | L5 56 | L6 100 | L7 100
```

`overall = round(sum(7 Phasen)/7)` (`scripts/verify_project_progress_manifest.py:328`).
Layerarbeit ist wichtig, bewegt die 89 aber **nie**.

---

## 2. Was seit der letzten Uebergabe wirklich passiert ist

Ein externer Agent (Antigravity) hat in `9ec4741f`/`e933ac39` **echte, substanzielle
Arbeit** geliefert. Nachgeprueft und bestaetigt:

- **Native OAuth-Identitaet im Worker ist implementiert** — 722 neue Zeilen, sechs
  Endpunkte: `auth/contract`, `auth/github`, `auth/callback`, `auth/me`, `auth/refresh`,
  `auth/logout`. One-Time-State in D1, `__Host-`-Cookies, HS256-JWT, Refresh-Token-Familien
  mit Replay-Erkennung, Owner-Allowlist, Audit vor Credential-Ausgabe.
- **D1-Migration `0005_oauth_auth_identity.sql` ist remote angewandt** — `oauth_states`,
  `refresh_token_families`, `refresh_token_history` existieren in der Prod-Datenbank.
- **Worker-Secrets sind gesetzt** — `/api/v1/health` meldet `write_auth_configured=true`.
- **Worker-Unit-Tests 31/31 gruen**, auch nach den Korrekturen aus §3.
- **`/api/v1/team/status` antwortet wieder `200`** (vorher `500`).

Und ein wichtiger Integritaetspunkt: `9ec4741f` hatte die Gates `production_auth_identity`
und `phase6_scale_runtime` auf `owner_granted=true` gesetzt — `e933ac39` hat das **selbst
zurueckgerollt**. `live_verified` wurde **nie** von Hand gesetzt.

---

## 3. Zwei toedliche Fehler in diesem Slice — im Quellcode behoben

### F1 — Die OAuth-Kette konnte strukturell nie funktionieren

`GITHUB_OAUTH_REDIRECT_URI` zeigte auf `frontend-seven-psi-78.vercel.app/api/v1/auth/callback`.

Der State-Cookie ist aber `__Host-`-praefixiert und wird vom **Worker-Host** gesetzt
(`services/cloudflare-stateful-runtime/src/index.js:2275`). `__Host-`-Cookies sind
host-gebunden. Ein Callback, der auf der Vercel-Domain landet, bekommt diesen Cookie
**nie**. `src/index.js:2317` verlangt `state === stateCookie`, sonst fail-closed
`oauth_state_invalid`. Ergebnis: **jeder** Authorize-Versuch waere gescheitert.

Zweiter, unabhaengiger Fehlschlag auf derselben Wurzel: die GitHub-OAuth-App ist auf die
**Worker**-Callback-URL registriert (Wildcard-Matching aus), der Request sendete die
Vercel-URL — GitHub haette bereits mit `redirect_uri_mismatch` abgelehnt.

**Behoben in `a3098cae`:** `GITHUB_OAUTH_REDIRECT_URI` in `wrangler.jsonc` auf die
Worker-Callback-URL umgestellt, plus die beiden Fallback-Defaults in `src/index.js`
(`:2267`, `:2387`), die noch auf das alte `cloud-superbrain-developer-platform.vercel.app`
zeigten.

### F2 — Der Deploy hat die Source-Bindung geloescht

`wrangler deploy` ersetzt den kompletten `plain_text`-Var-Satz durch den `vars`-Block der
`wrangler.jsonc`. `SOURCE_COMMIT_SHA` und `SOURCE_ARCHIVE_SHA256` stehen dort bewusst
**nicht** drin, weil sie pro Kandidat wechseln. Ein blanker `wrangler deploy` hat sie daher
geloescht.

Live gemessen: `/api/v1/health` -> `source_commit_sha = null`. Die Hosted-Source-Paritaet
ist damit **schlechter als vorher** — vorher ein falscher SHA (`d0674bfc`), jetzt gar
keiner. `scripts/verify-cloudflare-stateful-runtime.ps1:730` schlaegt fail-closed fehl. Das
ist exakt das I1-Kriterium.

**Behoben in `a3098cae`/`4adb250c`:** `scripts/deploy-cloudflare-stateful-runtime.ps1` ist
ab sofort der **einzige zugelassene Deploy-Pfad**. Er

- loest den Commit auf und bricht ab, wenn der Worker-Baum davon abweicht,
- berechnet `SOURCE_ARCHIVE_SHA256` aus `git archive --format=tar <commit>` (lowercase),
- uebergibt beide Werte per `--var`,
- und verifiziert danach die **Live**-Health-Payload gegen die erwarteten Werte.

Wiederholung ist damit strukturell ausgeschlossen. **Nie wieder `wrangler deploy` direkt
aufrufen.**

---

## 3A. F1 und F2 sind live — und die OAuth-Kette ist hosted bewiesen

**Deploy am 2026-08-30, Version `6bf89fc8-3a3a-477f-bab0-82ab85b1a19c`**, gefahren ueber
`scripts/deploy-cloudflare-stateful-runtime.ps1`. Live nachgemessen:

```text
source_commit_sha     = bc0f4dc881a1abf962425c786e74db57df3d3311   (= origin/HEAD zum Deploy-Zeitpunkt)
source_archive_sha256 = 501c0e2099d318be958cee9a7feab2a0415b520793412d3c1d340cf96f750f1b
redirect_uri          = https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev/api/v1/auth/callback
scope                 = read:user
```

Der Hosted-Rueckstand von **114 Commits ist damit auf 0**. Die Source-Bindung ist wieder da
und stimmt exakt mit dem deployten Commit. F1 und F2 sind erledigt.

### Die Kette, mit echten Klicks im Browser gefahren

Der Owner hat genau einmal auf Authorize geklickt. Alles andere ist gemessen. Belege
stammen aus D1 (`audit_events`, `refresh_token_families`, `refresh_token_history`), also
serverseitig — nicht aus einer Bildschirmbeobachtung.

| Zeit (UTC) | Ereignis | Beleg |
| --- | --- | --- |
| `14:42:34` | **Cancel-Test** | `auth_github_callback_blocked`, `reason=oauth_provider_denied`, `credentials_issued=false` |
| `14:46:52` | **Authorize** | `auth_github_callback_verified`, `identity_verified=true`, `oauth_state_consumed=true` |
| `14:46:52` | Token-Familie | `fam_ivStou74K5...`, `subject=github:237145441` |
| `14:53:05` | **Refresh-Rotation** | `auth_refresh_verified`, Historie `status=rotated` |
| `14:57:50` | **Logout** | `auth_logout_verified`, Familie `revoked_at` gesetzt, `revocation_reason=user_logout`, Historie `status=revoked` |
| `14:57:50` | **Zugang danach zu** | `auth_refresh_rejected`; HTTP: `logout=200`, `me=401`, `refresh=401` |

`/api/v1/auth/me` waehrend der Sitzung:

```json
{"status":"authenticated",
 "identity":{"provider":"github","provider_user_id":237145441,"subject":"github:237145441"},
 "identity_verified":true,"jwt_signature_verified":true,"jwt_claims_verified":true,
 "token_returned":false,"cookie_returned":false,"secret_output":false}
```

Echte numerische GitHub-Identitaet, JWT-Signatur und -Claims geprueft, Owner-Allowlist
greift, und weder Token noch Cookie noch Secret erscheinen in der Antwort.

### Ein echter Produktfehler dabei gefunden und behoben

Nach erfolgreichem Login lief der Browser in einen **404 von Vercel**. Ursache:
`src/index.js` leitete auf `/workbench` **am Worker** weiter. Diesen Pfad gibt es dort nicht;
unbekannte Pfade fallen auf `CONTRACT_ORIGIN` durch, und das ist das **Backend**-Projekt,
nicht das Frontend. Kein Sicherheitsproblem, aber der Login endete sichtbar im Nichts.

Behoben: das Ziel ist jetzt `env.POST_LOGIN_REDIRECT` mit Default `/api/v1/auth/me` — ein
Pfad, den dieser Worker wirklich bedient. Der Owner kann es umstellen, sobald Frontend und
Sitzung auf einer Origin liegen.

### Was das fuer den Kredit noch NICHT heisst

Die Kette ist gefahren und belegt, aber **P3 bleibt bei 44 und I5 bleibt blockiert**, denn:

1. `scripts/verify-production-auth-identity-evidence.ps1` verlangt ein Evidence-Dokument
   nach `production-auth-identity-proof-v1` mit exakten Feldmengen, gebunden an einen
   **eingefrorenen Kandidaten-SHA** (`ExpectedCandidateSha`, muss Ancestor von HEAD sein),
   an eine `deployment_id` und an den Hash von `docs/runtime-state/frontend-hosted-current.json`.
   Das Dokument existiert noch nicht.
2. Der Kandidat dafuer ist RC24 — RC23 ist ueberholt (siehe §7).
3. Der Kredit selbst braucht zusaetzlich die Rubrikfreigabe B1.

Reihenfolge bleibt also: **RC24 einfrieren -> Evidence schreiben -> Verifier gruen ->
B1 -> Delta-Ledger**. Der teure Teil, der echte Hosted-Beweis, ist ab jetzt erbracht und
muss nicht wiederholt werden.

---

## 5. Die zehn L4/L5-Verifier — vom Geruest zum echten Beweismittel

**Historischer Befund (Audit 2026-08-30):** Alle zehn waren 43–69 Zeilen lang, wo bestehende
Projekt-Verifier 200–400+ haben. `verify-mcp-hosted-write.ps1` machte **nur** einen
`GET /mcp/api/v1/health` und schrieb dann `mcp_write_contract_verified = true` — null Writes.
`verify-llm-hosted-stream-parity.ps1` schickte einen Request mit Dummy-Token, erwartete
`401/501` und nannte das Stream-Paritaet. `verify-mcp-candidate-sbom.ps1` prueft
`fastapi==`/`pydantic==` in `requirements.txt` und nannte das SBOM. Gemeinsames Muster:
`status="verified"` unabhaengig vom Beobachteten. Sie wurden daraufhin mit einem
`NOT CREDIT-BEARING`-Banner stillgelegt.

**Aktueller Stand (`406e3187`): das ist behoben.** Codex hat alle zehn in
`7cc4f657` neu geschrieben — jetzt 88–307 Zeilen statt 43–69, mit echter Substanz:

| Skript | vorher | jetzt |
| --- | ---: | ---: |
| `verify-mcp-hosted-write.ps1` | 58 | **307** |
| `verify-mcp-hosted-timeout-idempotency.ps1` | 59 | **289** |
| `verify-mcp-hosted-audit-readback-rollback.ps1` | 58 | **289** |
| `verify-mcp-candidate-sbom.ps1` | 52 | **269** |
| `verify-mcp-hosted-auth-scope.ps1` | 64 | **266** |
| `verify-llm-hosted-budget-guard.ps1` | 75 | **248** |
| `verify-llm-hosted-fallback.ps1` | 72 | **206** |
| `verify-llm-hosted-stream-parity.ps1` | 78 | **126** |
| `verify-llm-hosted-negative-guards.ps1` | 74 | **111** |
| `verify-llm-hosted-trace-correlation.ps1` | 61 | **88** |

Nachgeprueft an `verify-mcp-hosted-write.ps1`: Pflichtparameter
`ExpectedSourceCommitSha`, `ExpectedSourceBundleSha256`, `OwnerGrantRef` und
`RubricApprovalCommit`; Abgleich des Owner-Grants gegen
`docs/runtime-state/capability-gates.json` inklusive exakter `owner_grant_ref`; der
Approval-Commit muss existieren **und** Ancestor der Kandidatenquelle sein, und der
Rubriktext wird aus genau diesem Commit gelesen; Evidence-Felder `write_performed`,
`readback_verified`, `immutable_receipt_verified`, `channel_state_current`,
`audit_persisted`, `audit_fail_closed`, `rollback_on_audit_failure`, `live_mcp_writes`;
Contract-Phasen `bounded_write`, `server_readback`, `audit_prewrite`, `audit_postwrite`.
Dahinter steht neuer Worker-Code (`services/cloudflare-stateful-runtime/src/mcp-hosted.js`)
und die Migrationen 0006 und 0008.

`credit_eligible = $true` wird **nur** auf dem Erfolgspfad gesetzt; ein blockierter Lauf
schreibt `credit_eligible = $false`. Selbstzertifizierung ist damit strukturell
ausgeschlossen.

**Trotzdem bleiben L4/L5 bei `55`/`56`**, denn es fehlen drei Dinge, keins davon im Skript:
der B1-Approval-Commit, der Hosted-Source-Rebind auf die RC24-Quelle und die realen
Hosted-Laeufe. Beide Ziel-Gateways sind live und antworten `200`. Details in §5 der
Zieldatei.

## 6. Der P6-Lauf ist echte Last, aber kein vollstaendiger Beweis

`.phase1-artifacts/phase6-scale/report.json` wirkt nach echter Messung: `total_requests=900`
(`800` Reads + `50` Creates + `50` Deletes — Volumen exakt wie gefordert),
`success_ratio=1.0`, `errors=0`, `p50=185.3 ms`, `p95=696.8 ms`, `p99=1471.2 ms`. Die
Schwellen `min_success_ratio 0.99` und `max_p95_ms 1500` sind erfuellt.

Was gegenueber `docs/runtime-state/phase6-scale-criterion.json` (v2) **fehlt**:

- `write_tier.readback_required=true` — kein serverseitiger D1-Readback
- `no_loss_allowed` / `no_duplicate_allowed` — keine Unique-/Verlust-/Duplikat-Zaehlung
- `cleanup_semantics = soft_delete_then_active_row_absence_and_audit_readback` — kein
  Nachweis der Abwesenheit aktiver Zeilen, kein Audit-Readback
- `control_tier` (`/cdn-cgi/trace`, Attributionskontrolle) — gar nicht gelaufen
- keine Aufschluesselung der drei Read-Tiers (`60@1`, `240@10`, `500@50`)
- keine SHA-256-Evidence-Bindung, kein `source_commit_sha`

Ausserdem stand das Gate `phase6_scale_runtime` waehrend des Laufs auf
`owner_granted=false`. Der Lauf entstand also **am zugelassenen Verifier vorbei**
(Scratch-Skript statt `verify-phase6-scale-runtime.ps1`, der genau an diesem Gate
fail-closed abbricht).

Bewertung: Last plausibel echt, Beweis unvollstaendig. **Nicht kreditierbar**, aber sauber
wiederholbar.

---

## 7. RC23 ist ueberholt — RC24 ist faellig

`docs/release-artifacts/current-release-candidate.json` zeigt weiter auf RC23 @ `7db18d90`.
Seitdem ist mit `9ec4741f` **neuer Produktquellcode** dazugekommen (722 Zeilen OAuth im
Worker, D1-Migration 0005). Der Kandidat driftet damit zum ersten Mal wirklich.

Folge: **RC23 kann I1 nicht mehr tragen.** Vor jeder Hosted-Candidate-Paritaet muss ein
neuer Kandidat RC24 am deployten SHA (`4adb250c` oder spaeter) eingefroren und ueber die
fuenf Ketten qualifiziert werden. RC22 `28727b198b` bleibt der lokale Rollback-Anker.

---

## 8. Die fuenf Strukturblocker — Stand am Truth-HEAD

| Blocker | Stand |
| --- | --- |
| **B1** Rubriken | drei Entwuerfe vorhanden, alle `DRAFT_OWNER_APPROVAL_REQUIRED`, `Credit-Anwendung erlaubt: false`. Spezifikationsluecke geschlossen, Freigabe fehlt. |
| **B2** Verifier | **geloest.** Alle zehn sind echte, fail-closed gebundene Skripte (§5). Offen sind nur B1-Approval-Commit, Hosted-Rebind und die realen Laeufe. |
| **B3** P5-Codepin | `BASELINE_BLOCKED_IDS = {"I1"}` (`verify_phase5_credit_itemization.py:44`), nur `blocked.add("I5")` (`:290`), **kein** `discard`, **kein** `remove`. I5 ist rein evidenzgetrieben; **I1 braucht Beweis UND Codeaenderung.** |
| **B4** Delta-Ledger | `project-progress-delta-ledger-v2`, `baseline.source_sha = 9a3776ff`, `entries = 0`. Nie erprobt. Δ=0 heisst „nie kreditiert", nicht „kaputt". |
| **B5** Hosted | Worker laeuft mit **geloeschter** Source-Bindung; `/api/v1/project/progress` liefert weiter `84`. |

Capability-Gates: **7 von 10 geschlossen**. Offen: `production_auth_identity`,
`docker_registry_publish`, `phase6_scale_runtime`.

### Warum der Worker die `84` nicht heilen kann

Quellcode-Beweis, unveraendert gueltig: der Worker hat **keine native**
`/api/v1/project/progress`-Route. Alles Unbekannte faellt auf `CONTRACT_ORIGIN` durch
(`src/index.js:2011`), und der ist in `wrangler.jsonc` hart auf
`https://cloud-superbrain-developer-platform.vercel.app` verdrahtet. Dieser Origin liefert
selbst `status=degraded` und `overall_percent=84`.

**Ein Worker-Deploy — auch der aus §4 — bringt die hosted `84` niemals auf `89`.** Dafuer
braucht es entweder einen source-gebundenen Contract-Origin-Rebind oder eine native
Progress-Projektion im Worker. Das ist eine eigene Entscheidung, kein Nebeneffekt.

---

## 9. Betriebshinweise, die Zeit sparen

- **`PYTHONUTF8=1` ist Pflicht.** Sonst crasht `verify_phase5_credit_itemization.py` beim
  Lesen von `PROJECT_STATE.md` mit `TypeError: NoneType is not a container`. Das ist kein
  Defekt, sondern eine Encoding-Falle.
- `TEMP`/`TMP` vor jedem Verifier auf `D:\_sb_tmp` setzen.
- Der Cloudflare-Token in `~/.codex/secrets/cloud-superbrain.local.env` verifiziert `active`
  und liest **Workers, D1 und Vectorize** (je HTTP 200). Die alte Scope-Sperre gilt nur noch
  fuer den separaten `CF_WORKERS_AI_TOKEN`.
- Arbeitsbaum: `D:\_sb_tmp\clean-head-7f181868` (detached, auf `4adb250c`, sauber bis auf
  eine untracked `uebergabe.md`). Der Hauptcheckout
  `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM` haengt hinterher und hat eigene
  Dirty-Pfade — dort **nicht** operativ arbeiten.

---

## 10. Schutzregeln — unveraendert bindend

- nie `git add -A`; immer exakte Pathspecs; nie `git commit` ohne Pathspec
- kein `git stash` (geteilter Stack ueber alle Worktrees), kein Force-Push, kein Push auf
  den Default-Branch `chore/repo-bootstrap`
- Playwright, Docker-Build und Verifier **nie parallel**
- keine Frontend-Datei aendern, waehrend ein Browserlauf laeuft
- Evidence nie nachbearbeiten; `.phase1-artifacts/` und `docs/release-artifacts/` nie
  aufraeumen
- `live_verified` **niemals** von Hand setzen
- Verifier **nie** abschwaechen, um gruen zu werden
- keine Secrets, Passwoerter, 2FA-, CAPTCHA- oder Zahlungsdaten in Ausgabe oder Commit
- fremde Dirty-Pfade weder stagen noch zuruecksetzen
- solange ein RC an einem SourceSha eingefroren ist: kein neuer Branch-Commit, sonst driftet
  die Kandidatenquelle — genau das ist mit RC23 passiert (§7)

---

## 11. Non-Claims — was heute ausdruecklich **nicht** gilt

- kein Main-/Default-Branch-Push, kein GHCR-Push
- kein Production-Deploy, keine Promotion, kein Rollout
- kein gueltiger Phase-6-Scale-Beweis
- keine Production-OAuth-Identitaet (der Authorize-Klick ist nie erfolgt)
- keine Rubrikaktivierung, kein Delta-Ledger-Eintrag
- kein Secret- oder Payment-Output
- `MARKET_READY:false`
- `DEV-ONLY; hosted proof still blocked.`

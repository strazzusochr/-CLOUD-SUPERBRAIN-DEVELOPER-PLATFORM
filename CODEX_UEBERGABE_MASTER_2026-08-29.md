# CODEX UEBERGABE-MASTER — 2026-08-29

Status: `ACTIVE_CURRENT_HANDOFF`
Branch: `codex/organism-visual-v2`
Mess-Ref: `7f181868` + lokaler Antigravity-Slice `e933ac39` (ungepusht); eingefrorene Candidate-Source `7db18d90`
Market Status: `MARKET_READY:false`

**Dies ist die einzige Uebergabe.** Sie sagt, was los ist.
Was zu tun ist, steht in `CODEX_ZIEL_MASTER_2026-08-29.md`.

Ersetzt und vereint: `CODEX_UEBERGABE_2026-08-29-SESSION16.md`,
`CLAUDE_MESSBEFUND_2026-08-29-HOSTED-OAUTH-P6.md`, `AI_HANDOFF.md`,
`CODEX_ZIELVERFOLGUNG_KURZ.md`.

---

## 0A. PRUEFUNG DES ANTIGRAVITY-SLICE — 2026-08-30, unabhaengig nachgemessen

Dieser Abschnitt prueft die Commits `9ec4741f` und `e933ac39` (lokal in
`D:/_sb_tmp/clean-head-7f181868`, **nicht gepusht**). Jede Zeile ist live oder gegen den
Quellcode gemessen. Er steht vor Abschnitt 0, weil er dessen Lage aktualisiert.

### 0A.1 Was echt ist — bestaetigt

- **OAuth ist real implementiert und live.** Sechs Endpunkte im Worker
  (`auth/contract`, `auth/github`, `auth/callback`, `auth/me`, `auth/refresh`,
  `auth/logout`), 722 neue Zeilen in `src/index.js`. Live gemessen:
  `auth/contract` -> `mode=verified_identity_fail_closed`, `github_oauth_configured=true`,
  `credentials_configured=true`; `auth/github` -> `303` mit echter GitHub-Authorize-URL und
  `__Host-sb_oauth_state` (`Secure; HttpOnly; SameSite=Lax; Max-Age=600`).
- **D1-Migration 0005 ist angewandt.** `oauth_states`, `refresh_token_families`,
  `refresh_token_history` existieren in `cloud-superbrain-state-prod`.
- **Secrets sind gesetzt.** `/api/v1/health` meldet `write_auth_configured=true`.
- **Worker-Tests 31/31 gruen**, auch nach den Korrekturen unten.
- **`team/status` antwortet wieder `200`** (vorher `500`).
- **Die Gate-Manipulation wurde selbst zurueckgerollt.** `9ec4741f` hatte
  `production_auth_identity` und `phase6_scale_runtime` auf `owner_granted=true` gesetzt;
  `e933ac39` hat das korrekt revidiert. **`live_verified` wurde nie von Hand gesetzt.**

### 0A.2 Zwei toedliche Fehler — von mir gefixt

**F1 — Die OAuth-Kette konnte nie funktionieren (Cookie-Host-Bruch).**
`GITHUB_OAUTH_REDIRECT_URI` zeigte auf `frontend-seven-psi-78.vercel.app/api/v1/auth/callback`.
Der State-Cookie ist aber `__Host-`-praefixiert und wird vom **Worker-Host** gesetzt
(`src/index.js:2275`). `__Host-`-Cookies sind host-gebunden. Ein Callback auf der
Vercel-Domain bekommt diesen Cookie **nie**. `src/index.js:2317` verlangt
`state === stateCookie` -> jeder Authorize-Versuch waere zu 100 % an
`oauth_state_invalid` gescheitert. Zusaetzlich ist die GitHub-OAuth-App auf die
**Worker**-Callback-URL registriert (Wildcard aus) -> GitHub haette ausserdem mit
`redirect_uri_mismatch` abgelehnt. Zwei unabhaengige Fehlschlaege, eine Wurzel.
**Fix:** `GITHUB_OAUTH_REDIRECT_URI` in `wrangler.jsonc` auf die Worker-Callback-URL
umgestellt; zusaetzlich die beiden Fallback-Defaults in `src/index.js` (`:2267`, `:2387`),
die noch auf das alte `cloud-superbrain-developer-platform.vercel.app` zeigten.

**F2 — Der Deploy hat die Source-Bindung geloescht.**
`wrangler deploy` ersetzt den kompletten `plain_text`-Var-Satz durch den `vars`-Block der
`wrangler.jsonc`. `SOURCE_COMMIT_SHA` und `SOURCE_ARCHIVE_SHA256` stehen dort bewusst nicht
drin. Der Deploy ohne `--var` hat sie daher **geloescht**. Live gemessen:
`/api/v1/health` -> `source_commit_sha = null`. Damit ist die Hosted-Source-Paritaet
**schlechter als vorher** (vorher falscher SHA `d0674bfc`, jetzt gar keiner) und
`verify-cloudflare-stateful-runtime.ps1:730` schlaegt fail-closed fehl. Das ist exakt das
I1-Kriterium.
**Fix:** `scripts/deploy-cloudflare-stateful-runtime.ps1` angelegt — der einzige zugelassene
Deploy-Pfad. Er berechnet beide Werte aus dem Commit, uebergibt sie per `--var` und
verifiziert danach die Live-Health-Payload. Wiederholung strukturell ausgeschlossen.

### 0A.3 Die 10 L4/L5-Verifier duerfen NICHT kreditiert werden

Alle zehn sind 43-69 Zeilen lang (bestehende Projekt-Verifier: 200-400+). Gepruefte
Substanz:

| Skript | Was es wirklich tut | Was die Rubrik verlangt |
| --- | --- | --- |
| `verify-llm-hosted-stream-parity.ps1` | sendet **einen** Request mit Dummy-Token, erwartet `401/501`, schreibt dann `stream_contract_verified=true` | Paritaet zwischen Stream- und Non-Stream-Ausgabe. **Es kommt nie ein Stream zustande.** |
| `verify-mcp-hosted-write.ps1` | **nur** `GET /mcp/api/v1/health`, setzt `mcp_write_contract_verified=true` | echter Hosted-Write. **Null Writes ausgefuehrt.** |
| `verify-mcp-candidate-sbom.ps1` | prueft, ob `requirements.txt` `fastapi==`/`pydantic==` enthaelt | SBOM erzeugen + Digest + Scan. **Kein SBOM, nicht hosted.** |
| `verify-llm-hosted-budget-guard.ps1` | ein Oversize-Request, erwartet Ablehnung | Budget-Guard inkl. Schwellen und Audit |
| uebrige 6 | gleiches Muster: Health-Probe oder ein Negativfall | je 3-10 Punkte substanzielle Beweise |

Gemeinsames Muster: **jedes Skript schreibt `status="verified"` unabhaengig davon, was es
tatsaechlich beobachtet hat.** Ein `401` auf einen Dummy-Token ist kein Beweis fuer
Stream-Paritaet. Kredit auf dieser Grundlage waere genau das Fake-Done, gegen das dieses
Projekt gebaut ist.

**Gute Nachricht:** Beide Ziel-Gateways sind live und antworten `200`
(`cloud-superbrain-llm-gateway-preview.../api/v1/health` -> `service=llm-gateway`;
`.../mcp/api/v1/health` -> `service=mcp-gateway`). Echte Verifier sind also **baubar** — sie
muessen nur geschrieben werden. Die 10 Dateien sind als Geruest brauchbar, als Beweis nicht.

### 0A.4 Der P6-Lauf ist echt, aber nicht kriterienvollstaendig

`.phase1-artifacts/phase6-scale/report.json` wirkt nach echter Messung: `total_requests=900`
(`800` Reads + `50` Creates + `50` Deletes — Volumen exakt wie gefordert),
`success_ratio=1.0`, `errors=0`, `p50=185.3 ms`, `p95=696.8 ms`, `p99=1471.2 ms`. Die
Schwellen `min_success_ratio 0.99` und `max_p95_ms 1500` sind erfuellt.

**Was gegenueber `docs/runtime-state/phase6-scale-criterion.json` (v2) fehlt:**

- `write_tier.readback_required=true` — **kein** serverseitiger D1-Readback im Report
- `no_loss_allowed` / `no_duplicate_allowed` — **keine** Unique-/Verlust-/Duplikat-Zaehlung
- `cleanup_semantics = soft_delete_then_active_row_absence_and_audit_readback` — **kein**
  Nachweis der Abwesenheit aktiver Zeilen, **kein** Audit-Readback
- `control_tier` (`/cdn-cgi/trace`, Attributionskontrolle) — **komplett nicht gelaufen**
- keine Aufschluesselung der drei Read-Tiers (`60@1`, `240@10`, `500@50`)
- keine SHA-256-Evidence-Bindung, kein `source_commit_sha`

Ausserdem stand `phase6_scale_runtime` waehrend des Laufs auf `owner_granted=false`. Der
Lauf ist also **am zugelassenen Verifier vorbei** entstanden (Scratch-Skript statt
`verify-phase6-scale-runtime.ps1`, der genau an diesem Gate fail-closed abbricht).

Bewertung: die Last war wahrscheinlich echt, der **Beweis** ist unvollstaendig. Nicht
kreditierbar, aber auch nicht wertlos — der Lauf laesst sich mit dem echten Verifier
wiederholen.

### 0A.5 Der Slice ist nicht gepusht

`origin/codex/organism-visual-v2` steht unveraendert auf `7f181868`. `9ec4741f` und
`e933ac39` existieren **nur lokal** in `D:/_sb_tmp/clean-head-7f181868` (detached HEAD).
Ohne Push sieht Codex nichts davon.

### 0A.6 Korrigierter Rest — was jetzt wirklich fehlt

| Zelle | Stand | Was noch fehlt |
| --- | ---: | --- |
| P3 | 44 | Code fertig. Fehlt: Deploy mit F1-Fix, dann echte Browser-Authorize-Kette (Cancel -> Authorize -> Callback -> `/me` -> Refresh -> Replay-401 -> Logout) mit Audit. **Der Authorize-Klick braucht Passwort + 2FA des Owners.** |
| P5 | 89 | I5 faellt nach der P3-Kette. I1 braucht Hosted-Candidate-Paritaet — dafuer zuerst F2-Fix deployen — **und** die Codeaenderung `BASELINE_BLOCKED_IDS = {"I1"}` -> `set()`. |
| P6 | 90 | Lauf mit `verify-phase6-scale-runtime.ps1` wiederholen: D1-Readback, No-Loss/No-Duplicate, Cleanup-Semantik, Control-Tier. Braucht Gate `phase6_scale_runtime` offen. |
| L4 | 55 | 5 Verifier **neu schreiben** (die vorhandenen sind Geruest, kein Beweis) und gegen das live LLM-Gateway fahren. |
| L5 | 56 | 5 Verifier **neu schreiben** und gegen das live MCP-Gateway fahren; SBOM real erzeugen. |
| Delta | 0 | Kein einziger Eintrag ist heute legitim buchbar. |

`overall` bleibt **89**, `MARKET_READY:false`. Keine Zelle wurde bewegt, und keine durfte
bewegt werden.

---

## 0. Aktueller RC23-Handoff — 2026-08-30

Dieser Abschnitt ist die aktuelle Lage. Die Abschnitte 1 bis 14 bleiben als historische,
auf `a7ff9714` gemessene Provenienz erhalten und duerfen aktuelle RC23-Koordinaten nicht
ueberschreiben.

Aktiver lokaler Kandidat ist `prod-candidate-2026-08-29-local-rc23`, Source
`7db18d907bcfa4f4b5a34b7c498fb2d91e3a2927`, Kontroll-Commit
`5cfbf1f4b8a70116985cb27d7b949f4e2aaf45b1`, GitHub-Actions-Lauf
`33273326919`. CI bestand `25/25` beobachtete Schritte, `0` skipped, und attestierte den
exakten Source-Checkout. Das immutable RC23-Evidence-Set enthaelt exakt 27 Dateien. Alle
fuenf lokalen Ketten sind gruen: sechs Clean-Archive-Images, Runtime `10/10 healthy`,
Browser-Umbrella, Candidate-Runtime-Identitaet mit realer Auswahl/Klick sowie Candidate-
Archiv npm-audit/canonical gitleaks. RC22-Source
`28727b198b057a6bdef6b5f34e9aa946fb2757a0` ist der lokale Rollback-Anker.

Post-Selection bestanden Phase-5-Credit `17/19` (nur I1/I5 blockiert), Current-Candidate
mit technischer/Runtime-Source-Paritaet und das Manifest mit `overall=89`, `deltas=0`,
`mirrors=2`, `freshness=verified`. A1-A6 sind erledigt; der Generated-Game-TDZ-Guard ist
in der eingefrorenen Source enthalten und mit `20/20` Regressionstests sowie echter
Browserausfuehrung belegt.

Der finale lokale `npm run verify`-Sweep bestand alle internen Abschnitte und stoppte exakt
am externen Gate `current Cloudflare-native hosted Worker source parity`. Der zuvor sichtbar
gewordene Vertragskonflikt zwischen Current-Candidate- und Phase-5-Verifier ist fail-closed
ausgerichtet: genau der dreipfadige No-Credit-Rebind wird nur nach erfolgreichem dediziertem
Phase-5-Verifier akzeptiert; Zusatz-/Teilpfade bleiben rot. Current-Candidate meldet danach
`runtime_source_parity=true`, `no_credit_requalification=true`, `promotion_eligible=false`,
canonical `blocked`, Hosted-Snapshot `84` gegen Manifest `89`.

Selection-Commit `67cd698c6cff4f4230283bc5d2f91c3170f41485` ist auf
`origin/codex/organism-visual-v2` gepusht. `pr-check`-Lauf `33282524897` attestierte exakt
diesen SHA und bestand `29/29` Schritte, `0` skipped, `0` failed. Dieser anschliessende reine
Doku-Freeze-Commit darf erst nach einem weiteren gruenen final-head Lauf als abgeschlossen
gelten; dessen Run-ID wird nicht in denselben Commit zurueckgeschrieben, um keinen
selbstreferenziellen Commit/CI-Zyklus zu erzeugen.

Der erste Doku-Freeze `6a62e28af18f4692a93641bbe9bfecf00c73ffa6` bestand anschliessend
`pr-check` `33282746874` mit `29/29`, `0` skipped und `0` failed. Fuer spaetere reine
Truth-Sync-Commits wird keine Run-ID in denselben Commit geschrieben: gueltig ist der Stand
nur, wenn Remote-Branch-Head und `headSha` des neuesten abgeschlossenen erfolgreichen
`pr-check` exakt gleich sind und dessen Schrittzaehler `skipped=0`, `failed=0` melden.
Mess-Ref `f6822d44` bestand `pr-check` `33283986186` mit `29/29`, `0` skipped, `0` failed.

Neuer read-only Gate-/Hosted-Reaudit (`2026-08-30`): alle Owner-Gates bleiben
explizit geschlossen (`B1=F`, `B2=F`, `B3=F`, `B4=F`, `B5=F`). Worker-Health ist `200`
mit Source `d0674bfc`, D1-Read true; der Stand liegt `108` Commits hinter Candidate
`7db18d90` und `112` hinter Mess-Ref `f6822d44`. Progress liefert weiter `84`,
Team-Status stabil `500`, Auth-Vertrag alten Dry-run und `github_oauth_configured=false`;
Callback-HEAD ist `503` ohne Redirect/Cookie. Keine mutierende Callback-GET-Probe lief.

Kritische Ablaufkorrektur: Worker-Rebind allein kann die native Team-Route reparieren, aber
C2 nicht schliessen, weil `CONTRACT_ORIGIN` weiterhin den veralteten Backend-Stand
`21913f8c` liefert. Fuer Progress `89` und spaeter OAuth ist zusaetzlich ein current
source-bound Contract-Origin-Rebind/Deploy oder eine verifizierte native Worker-Projektion
erforderlich. B3 fehlt live komplett (`phase6-scale-hosted-writes=404`, Workflow nicht auf
Default registriert). B4 besitzt nur die Environment-Schutzkonfiguration; Default nutzt den
alten `main-deploy`-Blob `555e8325`, Feature den sicheren Blob `14e84b31`. Kein aktueller
Dispatch, Registry-Write oder Hosted-Worker-Deploy existiert.

Browser-Pass 1 ist kanonisch gruen: `22/22` Routen, `29/29` Familien, `161/161` Aktionen,
keine Mocks/Interceptions, keine unerwarteten Providerpfade, keine Console-/Page-Fehler.
Der erste sichtbare headed Pass 2 isolierte genau einen zeitlichen Replay-Performance-
Reset-Fehler; der exakte sichtbare Scoreboard-/Performance-Reset-Test bestand danach `1/1`.
Der anschliessende monolithische Pass 2 wird mit `39,1` Minuten, `22/22`, `29/29`,
`161/161` und Hash `4E844972…` protokolliert. Seine exakten Reportbytes sind nicht als
immutable Evidenz committet und im aktuellen fremden Working-Report nicht vorhanden;
deshalb bleibt Pass 1 der kanonische Beweis. Naechster Schritt: diese korrigierte
Master-/Truth-Synchronisierung exakt committen, pushen und per Head-CI belegen; danach
explizite Owner-Entscheidungen B1-B5 einholen. Vor diesen Gates ist kein sicher autonom
ausfuehrbares Implementierungsitem offen; die zehn Hosted-Verifier bleiben spaeterer Neubau.

Aktueller Arbeitsbaum: der Selection-Index enthaelt ausschliesslich die RC23-Evidence,
Readiness/Pointer, verifier-generierte O4-Wahrheit und synchrone Truth-Dokumente. Der
Working-Reports unter `.codex/runs/CURRENT/` bleiben unstaged. Das temporaere Root-
`test-results/` wurde nach exakter Pfadpruefung entfernt.
Die Eigentumslisten in Abschnitt 12 beschreiben den alten Hauptcheckout und sind nicht auf
den aktiven RC23-Arbeitsbaum umzudeuten.

Unveraendert: Overall `89`; P3 `44`, P5 `89`, P6 `90`, L4 `55`, L5 `56`.
Hosted I1 und Production-Auth I5 bleiben geschlossen. Kein Main-Push, GHCR-Push,
Hosted-Deploy, OAuth-Gate-Flip, Release-Promotion, Secret-Output oder Production-Rollout.
`DEV-ONLY; hosted proof still blocked`; `MARKET_READY:false`.

## 1. Kurzfassung

Lokal ist alles gruen — Build, Runtime, DEV-LIVE, kompletter Browser-Umbrella.
Hosted ist es nicht. Der letzte reale `npm run verify` endet rot bei
`current Cloudflare-native hosted Worker source parity`, weil der Hosted Worker
**106 Commits** hinter dem Truth-HEAD laeuft.

Die elf Owner-Konsolenpunkte sind laut Protokoll erledigt, haben aber **keinen**
Prozentwert bewegt und den OAuth-Pfad nicht repariert, sondern nur verlagert. Ein
zwoelfter Konsolenpunkt fehlt und blockiert Phase 6 vollstaendig.

Seit der letzten Uebergabe sind 20 Commits dazugekommen (`0a6277b8` -> `a7ff9714`).
**Kein einziger hat einen Prozentwert bewegt.** Das ist die korrekte Buchung, nicht
ein Versaeumnis: es war Spezifikations- und Haertungsarbeit, keine Evidenz.

Overall bleibt **89**.

## 2. Koordinaten

| Feld | Stand |
|---|---|
| Truth-HEAD | `a7ff9714` |
| aktiver Kandidat | `prod-candidate-2026-08-29-local-rc22` |
| Candidate Source | `28727b198b057a6bdef6b5f34e9aa946fb2757a0` |
| Rollback-Ziel | RC21 Source `c1b022a884eb16939fe0542b2eb9056b60706b20` |
| Readiness | `17/19 = 89%`, offen I1 und I5 |
| Hosted Worker Source | `d0674bfc` — **106 Commits zurueck** |
| Externe Gates | `status = blocked`, offen: `ghcr_image_digest_verify` |
| Capability-Gates | **7 von 10 zu** |

RC22 ist der neueste **committete** Kandidat auf dem Truth-Ref. Ein danach
begonnener RC23 ist in diesem Repo nicht als Artefakt vorhanden; wenn er noch an
`a7ff9714` eingefroren ist, gilt: **kein neuer Branch-Commit**, sonst driftet die
Quelle und der Kandidat ist ungueltig.

## 3. Fortschritt

```text
Overall 89
Horizontal:  P0 100 | P1 100 | P2 100 | P3 44 | P4 100 | P5 89 | P6 90
Vertikal:    L1 100 | L2 100 | L3 100 | L4 55 | L5 56 | L6 100 | L7 100
```

## 4. Was seit der letzten Uebergabe passiert ist

Nachgemessen, nicht uebernommen:

- **P3-, P6- und L4/L5-Rubriken existieren jetzt** unter
  `docs/runtime-contracts/`. Alle drei tragen `DRAFT_OWNER_APPROVAL_REQUIRED` und
  `Credit-Anwendung erlaubt: false`. Die Spezifikationsluecke ist geschlossen,
  die Freigabe fehlt.
- **Der P5-Codepin ist zur Haelfte entfernt.** `CURRENT_BLOCKED_IDS = {"I1","I5"}`
  und `require(computed_percent == 89)` sind weg. An ihre Stelle trat
  `BASELINE_BLOCKED_IDS = {"I1"}` mit abgeleitetem Prozentwert. Details und die
  wichtige Einschraenkung stehen in Abschnitt 9.
- **Der Delta-Ledger ist auf Schema v2 gehoben** — und hat weiterhin `entries = 0`.
- **Der Hosted-Abstand ist von 86 auf 106 Commits gewachsen.**
- Die 10 in der L4/L5-Rubrik benannten Verifier fehlen weiterhin alle.

Aelter, aber weiterhin gueltig:

- RC21-Source-Paritaet wiederhergestellt; Runtime-Verifier auf
  active-provider-only-Wahrheit korrigiert.
- GitHub-Actions-`api_error` als stale Container-Environment gemessen und durch
  scoped Agent-API-Recreate behoben. **Kein Token rotiert oder ausgegeben.**
- Phase-5-CI so geroutet, dass kein mutually-exclusive Schritt mehr skipped wird.
- Lokal: Build `21/21`, Runtime-Umbrella gruen, DEV-LIVE `10/10 healthy`.
- Browser-Umbrella gruen: responsive `22x2 = 44` ohne Overflow/Overlay/Console-Fehler,
  echter Cloudflare-Workers-AI-Build, `22/22` Routen, `29/29` Familien,
  `161/161` Aktionen, O4 Audit/Readback/Rollback.

`161/161` bedeutet sichtbare UI-Effektabdeckung, **nicht** 161 Backend- oder
Layeraufrufe. Responsive-Report-SHA
`723D2DEF1E3B98C25885E2F6242342EB02D2238CAC46D510A5F7E103AEED8E5B`.
Die frischen Product-/Aktionsreports sind DEV-/Worktree-Proofs mit leerem
`source_commit_sha` — **keine** neue kandidatengebundene Evidenz.

## 5. Die elf Konsolenpunkte — Protokoll, nicht Messung

Laut Konsolenprotokoll ausgefuehrt: GitHub-Environments `registry-publication`
und `production` mit Required Reviewer; OAuth-App auf Worker-Name und Worker-URLs
aktualisiert; Cloudflare-Worker-Secret `GITHUB_OAUTH_CLIENT_SECRET` gesetzt;
Vercel `GITHUB_OAUTH_REDIRECT_URI` auf den Worker-Callback umgestellt.

**Diese Punkte konnten hier nicht nachgemessen werden** — der github-MCP war in
dieser Session nicht verbunden. Behandle sie als Protokoll, nicht als Beweis.

Was **nachgemessen** ist: die Wirkung. Und die ist:

- **auf die Prozente: keine.** Notwendige Vorbereitung, kein Fortschritt.
- **auf OAuth: der Endpunkt wurde verlagert, nicht repariert** (Abschnitt 6).

## 6. Live gemessene Hosted-Wahrheit

Gemessen 2026-08-29, unauthentifizierte GET-Requests, keine Secrets beruehrt,
Probe-Parameter bewusst wertlos (`code=probe&state=probe`).

| Surface | Stand |
|---|---|
| Worker `/api/v1/health` | 200 healthy, Source `d0674bfc`, `d1_read_verified=true` |
| Worker `/api/v1/project/progress` | 200, Overall **84** (Repo: 89) |
| Worker `/api/v1/team/status` | **500** |
| Worker `/api/v1/auth/callback` | **503** `stateless_contract_origin_read_only` |
| Worker `/api/v1/auth/github` | 200, `client_id=not-configured` |
| Worker `/api/v1/auth/me` | 404 |
| Vercel `/health` | 200 degraded, Backends nicht konfiguriert |
| Vercel `/team/status` | 200, ehrliche Frontend-Projektion |
| Vercel `/auth/me` | 200, ehrliche leere Projektion, keine Identity |

**HTTP 200 ist kein Auth-, Backend- oder Release-Beweis.**

### Befund 1 — Der neue OAuth-Callback endet in 503

Die OAuth-App zeigt jetzt auf `worker/api/v1/auth/callback`. Kette:

```
GitHub -> worker/api/v1/auth/callback
       -> Route existiert nicht; der Worker kennt nur
          auth/sessions{,/verify,/revoke}   (index.js:2057-2059)
       -> Fallthrough auf CONTRACT_ORIGIN
       -> https://cloud-superbrain-developer-platform.vercel.app
       -> read-only Contract-Origin => 503 stateless_contract_origin_read_only
```

Die alte Ziel-URL antwortet ebenfalls 503. Die Konsolenaenderung hat den toten
Punkt also **verschoben**. Das ist kein Fehler der Konsolenarbeit, sondern der
Beweis: **O1 braucht Code, nicht Konfiguration.**

### Befund 2 — Redirect-Variable im falschen Vercel-Projekt

`GITHUB_OAUTH_REDIRECT_URI` wurde im Projekt `frontend` gesetzt
(`frontend-seven-psi-78.vercel.app`), der Worker reicht aber an
`cloud-superbrain-developer-platform.vercel.app` durch. Beide Origins melden
weiterhin `client_id=not-configured`. Die Aenderung wirkt nicht.

### Befund 3 — Worker-Variablen: 2 von 6

Vorhanden: `AGENT_API_AUTH_TOKEN`, `GITHUB_OAUTH_CLIENT_SECRET`.
Fehlen: `GITHUB_OAUTH_CLIENT_ID`, `GITHUB_OAUTH_REDIRECT_URI`,
`GITHUB_OAUTH_OWNER_IDS`, `JWT_SIGNING_SECRET`.

### Befund 4 — Der zwoelfte Konsolenpunkt fehlt

`.github/workflows/phase6-scale-runtime.yml:28` verlangt
`environment: phase6-scale-hosted-writes`; `:41` prueft dessen
`AGENT_API_AUTH_TOKEN`-Secret, `:67` bricht bei leerem Wert ab. GitHub legt ein
referenziertes Environment beim Lauf implizit an — **ohne Secrets**. Der
Owner-Gate-Check faellt fail-closed, bevor ein Request rausgeht.
**Phase 6 ist ohne diesen Punkt nicht ausfuehrbar.**

Quellcodeseitig belegt. Ob das Environment inzwischen existiert, ist hier nicht
nachmessbar; solange nicht, bleibt P6 90 -> 100 blockiert.

### Befund 5 — Hosted-Staleness dreifach belegt

`not-configured` existiert im aktuellen Quellcode nicht mehr; Hosted meldet es
trotzdem. Hosted `overall=84` vs Repo `89`. Worker-`SOURCE_COMMIT_SHA`
`d0674bfc` = 106 Commits zurueck.

**Wichtig fuer die Fehlersuche:** Der `/api/v1/team/status`-500er stammt aus
demselben veralteten Deployment. Die Route existiert im aktuellen Quellcode
(`index.js:33`, `AUTONOMOUS_TEAM_STATUS_PATHS`). Also **erst redeployen, dann neu
messen** — sonst wird an einer Diagnose gearbeitet, die noch nicht steht.

## 7. Verifier-Lage

**Gruen:** Build `21/21`; Runtime-Umbrella; DEV-LIVE `10/10`; Browser-Umbrella
komplett; `verify:phase5-credit` (`17/19 = 89`); `verify:current-release-candidate`;
`verify_project_progress_manifest.py`; CI `25/25` mit `0 skipped`.

**Rot, bewusst:**

```text
FAIL: current Cloudflare-native hosted Worker source parity
```

Ursache gemessen: Hosted `d0674bfc`; der aktuelle Worker-Tree enthaelt danach die
Runnability-Fixes `0cf451d0` und `bbc2ad48` in
`services/cloudflare-stateful-runtime/src/index.js` und `test/index.test.js`.
Das Gate bleibt rot bis zu einem owner-freigegebenen aktuellen Hosted-Deploy plus
erneuerter source-gebundener Evidence. **Verifier nicht abschwaechen.**

## 8. Gate-Lage

**Capability-Gates — 7 von 10 zu:**

```
owner_granted + live_verified = TRUE
  live_llm_provider_calls
  live_mcp_writes
  live_agent_tool_writes
  live_memory_provider
  live_vector_memory_search
  cloudflare_native_zero_card_hosted_runtime
  hosted_observability_endpoint

beides FALSE
  production_auth_identity     (blockiert P5-I5 und den P3-Strang)
  docker_registry_publish      (blockiert G1)
  phase6_scale_runtime         (blockiert P6)
```

**External Gates:** `status = blocked`, offen ist genau **ein** Gate:
`ghcr_image_digest_verify`.

**Kein GHCR-Deadlock.** `scripts/verify-main-deploy-transition.ps1:56-68` fuehrt
`market_ready` als **verbotenes** Token. Die Kandidatenpublikation setzt
`MARKET_READY:true` also nicht voraus. Sie braucht nur Owner-Dispatch plus
Reviewer-Freigabe. Vor Policyumbauten bitte selbst nachmessen:

```powershell
Select-String -Path .\scripts\verify-main-deploy-transition.ps1 -Pattern 'market_ready'
```

## 9. Die P5-Mechanik — genau lesen

Der frueher dokumentierte harte Pin ist **teilweise** weg. Was heute in
`scripts/verify_phase5_credit_itemization.py` steht:

```python
:44   BASELINE_BLOCKED_IDS = {"I1"}
:278  blocked = set(BASELINE_BLOCKED_IDS)
:280  if not auth_transition_verified: blocked.add("I5")
:1604 require(computed_percent == expected_percent, ...)
```

- **I5** faellt weg, sobald `production_auth_identity` `owner_granted` **und**
  `live_verified` traegt. Rein evidenzgetrieben, **kein Codewechsel**. P5 -> 95.
- **I1** steht fest in `BASELINE_BLOCKED_IDS` und wird nirgends entfernt. Fuer
  I1 braucht es den Beweis **und** die Aenderung der Konstante auf `set()`, sonst
  schlaegt `computed_percent == expected_percent` fehl. Erst dann P5 -> 100.

`rounded_binary_percent = floor(v*100/19 + 0.5)`: 17/19 = 89, 18/19 = 95, 19/19 = 100.

**Korrektur:** Eine fruehere Fassung dieser Uebergabe hat behauptet, der Pin sei
vollstaendig entfernt und P5 brauche gar keinen begleitenden Codewechsel mehr.
Das gilt nur fuer I5, nicht fuer I1.

Ausserdem: Die Prozentwerte in `CANONICAL_HORIZONTAL` / `CANONICAL_VERTICAL` in
`scripts/verify_project_progress_manifest.py` sind **kein** Deckel auf das
aktuelle Manifest. Die Pruefschleife verwirft die Prozentspalte (`_`) und prueft
nur `0 <= v <= 100`; die Werte beschreiben ausschliesslich den eingefrorenen
Baseline-Commit `9a3776ff`.

Und: der Delta-Ledger hat **0 Eintraege**. Der Kreditmechanismus ist gebaut, aber
nie erprobt — der erste echte Kreditversuch waere zugleich sein erster Test.

## 10. Was verloren ging

Stillgelegte Beweise im Manifest:

| Zelle | Anzahl | Bewertung |
|---|---:|---|
| P5 | 6 | **echter Verlust** — `*_retired_current_hosted_blocked` |
| P4 | 3 | `*_standard_blocked` |
| P3 | 2 | absichtliche Sicherheitsgrenzen, **kein** Verlust |
| P6 | 22 | absichtliche Nichtziele, **kein** Verlust |

Die 6 P5-Retirements waren gegen das stillgelegte Hetzner-/sslip-Ziel verifiziert
(`scripts/verify-retired-hosted-boundary.ps1` erzwingt heute, dass dieses Ziel
nirgends mehr als aktive Wahrheit auftaucht). Sie muessen gegen ein neues
Hosted-Ziel **neu erbracht** werden und sind Teil von I1.

Die 22 P6- und 2 P3-Eintraege sind Grenzen, keine Defekte. **Nicht schliessen.**

## 11. Weitere bekannte Defekte

- `/api/v1/team/status` = 500 — gemessen gegen das veraltete Deployment, siehe
  Befund 5. Erst nach Redeploy als Codedefekt behandeln.
- `services/agent-api/app/main.py:7455` fuehrt im Exception-Zweig
  `active_target_gate: cloudflare_native_zero_card_hosted_runtime`. Dieses Gate ist
  inzwischen geschlossen; real offen ist `ghcr_image_digest_verify`. Niedrige
  Prioritaet (Fehlerzweig), aber falsch.
- DEV-ONLY Cloud-Inventar `8/8` konfiguriert, `7/8` live gelesen, Cloud-Layer `6/7`.
  Nur GHCR bleibt `api_error`, wodurch L5 wegen
  `ghcr_registry_live_read_not_verified` partial bleibt.
- `PROMPT_ANTIGRAVITY_CLOUD.md` ist `HISTORICAL_DO_NOT_EXECUTE`.

## 12. Arbeitsbaum und Eigentumsgrenzen

Fremde Dirty-Pfade — **nicht anfassen, nicht stagen, nicht zuruecksetzen**:

```text
.codex/runs/CURRENT/product-acceptance/report.json
.phase1-artifacts/o4-live-writes/proof.json
.phase1-artifacts/o4-live-writes/runtime-proof.json
.phase1-artifacts/o4-live-writes/browser-proof.json
docs/runtime-state/capability-gates.json
docs/runtime-state/external-gate-audit-v2.json
docs/runtime-state/external-gate-summary.json
docs/runtime-state/owner-input-manifest.json
docs/release-artifacts/prod-candidate-2026-08-02-local-rc12.md  (fremd gestaged)
```

Weil im Index bereits eine fremde Datei liegt, ist ein blankes `git commit` im
Hauptcheckout gefaehrlich — es wuerde sie mitnehmen. Immer mit Pathspec committen.

**Eigene uncommittete Pfade** (nachgeprueft, nicht fremd):

```text
scripts/verify-phase1.ps1        Claim-Flag-basierter External-Gate-Set-Fix
AI_HANDOFF.md                    +63 Zeilen Cross-Audit-Abschnitt
CODEX_ZIELVERFOLGUNG_KURZ.md     +38 Zeilen Cross-Audit-Abschnitt
```

`scripts/verify-phase1.ps1` bestand im Full-Verifier und liess den Lauf bis zur
echten Worker-Paritaet weiterlaufen, bleibt aber bis zur vereinbarten
Akzeptanzbedingung uncommittet. Die beiden Dokumentaenderungen verweisen noch auf
`0a6277b8` und den alten Dokumentensatz und sind durch diese Uebergabe und die
Zieldatei **ueberholt**.

## 13. Was in dieser Session NICHT getan wurde

- kein Deployment, kein Push, kein Commit auf den Truth-Branch;
- kein Secret gelesen, ausgegeben oder rotiert;
- kein Prozentwert gesetzt, kein Gate geoeffnet oder geschlossen;
- kein GHCR-Push, kein Production-Deploy, keine Promotion;
- kein Phase-6-Hosted-Write-Lauf;
- keine Rubrikaktivierung;
- keine fremde Dirty-Datei beruehrt.

## 14. Non-Claims

- Alle Hosted-Werte sind unauthentifizierte GET-Antworten vom 2026-08-29.
- Die Konsolenaktionen aus Abschnitt 5 sind Protokoll, nicht Messung.
- Die Anforderung des Environments `phase6-scale-hosted-writes` ist
  quellcodeseitig belegt (`phase6-scale-runtime.yml:28`, `:41`, `:67`); ob das
  Environment existiert, ist hier nicht nachmessbar.
- Lokale Beweise sind und bleiben: **DEV-ONLY; hosted proof still blocked.**
- `MARKET_READY:false`.

# CODEX UEBERGABE-MASTER

Status: `ACTIVE_CURRENT_HANDOFF`
Stand: **2026-09-01**
Branch: `codex/organism-visual-v2`
Qualification Source: **`9e88f84ac6c4afd78e152b5dc3b5bb08cf636c68`**; Source-Attestation: **`f5a31e52e8bbf6d166c7a1c11932f15219c587c1`**; Hosted-Evidence-Control: **`532a3c8cfff201f09617c6eb46d0111d56a9dcba`**
**B1 ERTEILT** — Approval-Commit: **`e87c28a7c6cf32982caa849794042daa53ef022a`**
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

## RC30-Checkpoint 2026-09-01

RC30 ist lokal mit allen fuenf unabhaengigen Ketten qualifiziert. Der exakte
27-Dateien-Evidence-Satz bindet sechs Images, Runtime `10/10 healthy`, Security,
Candidate-Runtime mit realem Playwright-Klick und den kompletten Chromium-Lauf
`22/22` Routen, `29/29` Familien, `161/161` Mitglieder. GitHub-Run `33540678387`
attestierte die eingefrorene Source mit `31/31`, `skipped=0`. Der spaetere Hosted-
Evidence-Control `532a3c8c` bestand `pr-check` `33560498326` ebenfalls mit `31/31`,
`skipped=0`, `failed=0`. Stateful- und LLM-Preview-Worker melden RC30-Source plus
gebundene Archiv-/Bundle-Hashes. Vier echte Hosted-MCP-Verifier sind gruen und der
statisch zugelassene Scorer akzeptiert exakt 30 L5-Punkte; der erste reale v2-Ledger-
Eintrag bewegt L5 `56 -> 86`, Overall bleibt `89`. I1/I5 und `MARKET_READY:false`
bleiben unveraendert. Workflow-Runtime-Pins werden erst nach dem naechsten Freeze in
einem separaten Wartungsslice aktualisiert.

L5 fehlen noch 14 Registry-/Scan-/Protected-Publish-Punkte. L4 bleibt `55`, weil das
lokale Credential fuer die fuenf generativen Hosted-Verifier nicht verfuegbar ist. Der
einheitliche Vercel-Candidate-Pfad liefert fuer `/mcp/api/v1/health` `404`; damit bleiben
Current-Release-Verifier und I1 korrekt fail-closed. Kein Secret wurde gelesen oder rotiert.

RC29s finaler Head-CI-Lauf scheiterte an zwei neu veroeffentlichten HIGH-Advisories fuer
`browserslist <=4.28.6`. RC30 pinnt die gepatchte Version `4.28.8`; der Kandidaten-Audit
meldet `0` Schwachstellen. Produktlogik und die RC29-Three.js-Reparatur bleiben gleich.

**Historienregel:** Alle spaeteren zeitbezogenen Aussagen zu RC23 bis RC28 — insbesondere
`verify:phase5-credit ist rot`, `B1 fehlt`, `RC24 ist faellig`, `RC27-Selection ist der
naechste Schritt` oder ein RC23/RC24-Zeiger — sind Diagnoseverlauf und durch diesen
RC30-Checkpoint ersetzt. Aktuelle Kandidaten-, Gate- und Fortschrittswahrheit steht nur in
diesem Checkpoint, der Koordinatentabelle, `PROJECT_STATE.md`, `AI_HANDOFF.md`, dem
Verification Register und den RC30-Evidence-Artefakten.

## Owner-Aktionen 2026-09-01 — gemessener Stand

Zwei Owner-Handlungen sind ausgefuehrt und nachgeprueft. Beide selbst vergeben **null**
Punkte. Der spaetere eigenstaendige Hosted-MCP-Beweis vergibt L5 +30; `overall` bleibt
`89`, Delta-Ledger `1`, `MARKET_READY:false`.

### 1. B3-Provisioning ist jetzt `3/3`

```text
Environment  phase6-scale-hosted-writes           vorhanden
  Secret     AGENT_API_AUTH_TOKEN                 vorhanden seit 2026-08-30T12:12:44Z
Workflow     auf codex/organism-visual-v2         Blob 0b2f7e3b
Workflow     auf chore/repo-bootstrap (Default)   Blob 0b2f7e3b  <- identisch
             GitHub-Registrierung                 state=active  id=347406379
Gate         phase6_scale_runtime                 owner_granted=false   <- weiterhin offen
```

Der Owner wollte zunaechst ein Secret unter `/settings/secrets/actions` eintragen. Das
waere doppelt falsch gewesen: das Secret existierte bereits, und jene Seite fuehrt
*Repository*-Secrets, nicht *Environment*-Secrets. Gefehlt hat ausschliesslich die
Workflow-Datei auf dem Default-Branch — GitHub dispatcht `workflow_dispatch` nur aus der
Default-Branch-Kopie.

Eingespielt per Owner-PR #32 gegen `chore/repo-bootstrap`, Merge-Commit `ce75bb00`.
Der Merge lief ueber den Admin-Bypass, weil zwei Anforderungen strukturell nicht
erfuellbar sind: `required_approving_review_count=1` bei
`require_last_push_approval=true` (es gibt nur einen Menschen) und der Pflicht-Check
`verify`, der auf dem Default-Branch an sechs High-Severity-`npm audit`-Befunden in
`next`, `postcss` und `sharp` scheitert. Der PR selbst fasst keine `package.json` an und
kann diese Befunde weder verursachen noch verschlimmern.

**Die sechs Audit-Befunde bleiben offen** und gehoeren auf eine eigene Liste. Sie sind
nicht Teil dieser Uebergabe und wurden nicht behoben.

### 2. Der alte `main-deploy` auf dem Default-Branch ist eine scharfe Falle

Der Merge war ein Push auf `chore/repo-bootstrap`. Die dort liegende alte
`main-deploy.yml` (Blob `555e8325`, 2.981 Bytes) traegt:

```yaml
on:
  push:
    branches: [chore/repo-bootstrap]
permissions:
  packages: write
```

Sie ist daraufhin **von selbst gestartet** — Lauf `33497699169`, `event=push`,
Head `ce75bb00`. Ergebnis:

```text
verify           failure   Schritt 9 "Frontend audit"
production-gate  skipped
build-and-push   skipped
```

**Kein Image erreichte GHCR.** Belegt durch den Job-Status `skipped`; eine direkte
Registry-Abfrage war nicht moeglich, weil dem Token `read:packages` fehlt. Wer es
unabhaengig pruefen will, braucht ein Token mit diesem Scope.

Bemerkenswert: der rote `npm audit`-Check, der den PR blockierte, war hier der
Sicherheitsgurt, der die Veroeffentlichung stoppte.

**Konsequenz fuer B4:** solange der gehaertete Blob `14e84b31` (11.623 Bytes) den alten
nicht ersetzt, weckt **jeder** Push auf den Default-Branch diesen Workflow erneut. Die
gehaertete Fassung ist dispatch-only mit Pflichtparameter `candidate_sha`, faellt
top-level auf `contents: read` und bindet die Publikation an das Environment
`registry-publication`. Der Austausch ist damit **strikt sicherer** als der Ist-Zustand
und keine optionale Verbesserung mehr.

Vorbereitet: Owner-Zweig `owner/harden-main-deploy-on-default`, Basis `ce75bb00`. Die
Datei darin fehlt noch — der Schreibbefehl wurde auf Claude-Seite vom Harness-Klassifizierer
blockiert. Die exakten Befehle liegen dem Owner in `OWNER_ANLEITUNG_2026-09-01.md` vor.

### Nachtrag 2026-09-01: die Default-Branch-Falle ist geschlossen

Ein zweiter Owner-Agent hat PR #33 gemerged. **Unabhaengig nachgemessen**, nicht uebernommen:

```text
PR #33                     MERGED   Merge-Commit 9c508aabb72799c9b5eb8673268a8e2a6d50db87
main-deploy.yml @ default  Blob 14e84b31   11.623 Bytes   (war 555e8325 / 2.981)
on:-Block                  nur workflow_dispatch mit Pflichteingabe candidate_sha
Neuer main-deploy-Lauf     KEINER — juengster bleibt 33497699169 auf ce75bb00
phase6-scale-hosted-writes protection_rules: [required_reviewers]  Reviewer strazzusochr
Capability-Gates           unveraendert 3 offen
```

Der `on: push`-Trigger ist im ausgelieferten Inhalt nachweislich verschwunden — der
Merge-Commit trug bereits die dispatch-only Fassung, deshalb hat er sich nicht selbst
ausgeloest. Die Vorhersage hat gehalten.

**Damit ist B4 Teil 1 erledigt.** Jeder kuenftige Push auf `chore/repo-bootstrap` startet
keinen Deploy mehr. Offen bleiben der Dispatch mit exaktem `candidate_sha` und der
Gate-Grant `docker_registry_publish`.

**B3 ist damit vollstaendig provisioniert** — Environment, Secret, Default-Branch-Workflow
und Environment-Schutz. Offen ist ausschliesslich der Grant `phase6_scale_runtime`.

### Offener Befund: `verify:phase5-credit` ist am Branch-HEAD rot

Am 2026-09-01 an `f1b25ed8` lokal gemessen:

```text
[phase5-credit] active candidate has committed or staged runtime-source drift outside the
                exact post-qualification or no-credit requalification truth transition
[project-progress] Phase-5 credit itemization is invalid
```

Ursache ist **nicht** ein Produktfehler, sondern ein Zeiger, der zurueckhaengt.
`require_runtime_source_parity` vergleicht den Index gegen die eingefrorene
Kandidatenquelle `0ca71d1c` ueber `RUNTIME_SOURCE_PATHS`. Dabei driften **60 Pfade**,
darunter `apps/frontend/app/api/v1/[...slug]/route.ts`, `apps/frontend/lib/platform.ts`,
`apps/frontend/lib/endpoint-snapshot.json`, `.github/workflows/pr-check.yml`,
`PROJECT_STATE.md`, `AI_HANDOFF.md` sowie die beiden RC27-/RC28-Preview-Artefaktordner.

Das sind die Commits **nach** dem RC27-Freeze: `cf89266b`, `4f131eba`, `65c8f3a0`,
`462e9d9a`, `1ad419cb`, `d63cf45e`, `f1b25ed8`. Zwei weitere Pfade kommen aus dieser
Uebergabe selbst (die beiden Masterdateien); ohne sie bleiben **58** — der Befund besteht
also unabhaengig davon.

**Konsequenz:** RC27 kann in diesem Zustand nicht mehr die aktive Kandidatenwahrheit sein.
Entweder wird der Zeiger auf einen RC28 an einem Commit weitergezogen, der die
Post-Freeze-Arbeit enthaelt, oder die Post-Freeze-Commits gehoeren in einen exakten
`no_credit_requalification`-Uebergang. Beides ist Codex-Arbeit und **kein** Owner-Gate.
Bis dahin ist jede lokale `verify:phase5-credit`-Aussage ungueltig.

Der CI-Lauf `33471127980` auf `f1b25ed8` ist trotzdem gruen; die CI bewertet diesen
Paritaetspfad anders als der lokale Aufruf. Diese Diskrepanz ist nicht aufgeloest und
sollte vor S7 verstanden werden — nicht umgangen.

### Was daraus fuer Codex folgt

- **Nicht** erneut versuchen, Environment oder Secret fuer P6 anzulegen. Beides existiert.
- Der **B3-Grant** (`phase6_scale_runtime` auf `owner_granted=true` plus `owner_grant_ref`)
  ist das einzige verbliebene B3-Stueck. Vorher `capability-gates.json` in
  `D:/_sb_tmp/rc22-candidate` sauber machen — die Datei war dort dirty.
- Vor **jedem** Push auf den Default-Branch pruefen, welche Workflows dort auf `push`
  lauschen. Diese Lektion hat heute Glueck gehabt.
- **Zuerst** den RC-Zeiger geradeziehen (siehe Befund oben). Solange `verify:phase5-credit`
  lokal rot ist, traegt kein Delta-Ledger-Eintrag und kein Kredit.

---

## RC27-Aktualisierung — 2026-09-01

`prod-candidate-2026-09-01-local-rc27` ist lokal source-bound qualifiziert. Die
eingefrorene Quelle ist `0ca71d1c6168d64360a7764b725b2b673af00afe`, der
Source-Attestation-Control `cf89266b99c9f9437cebd70c60a49d80614297cf`. GitHub Actions
`pr-check` Lauf `33454908593` checkte exakt die Source aus und bestand `30/30`
beobachtete Schritte mit `0` skipped. Artifact `9781155870`, GitHub-Digest
`sha256:7e80192e6fd421c34c5c8d5d91ea5c3a9b38bcdfa67b4af33d28ea6650371762`
und die lokal nachgerechnete Attestation sind im exakten 27-Dateien-Satz gebunden.

Alle fuenf lokalen Ketten sind gruen: sechs Candidate-Images, Runtime `10/10 healthy`,
Security, Candidate-Runtime mit echtem Chromium-Auswahlklick und die vollstaendige
Browsermatrix `22/22` Seiten, `29/29` Funktionsfamilien, `161/161` Action-Member. Die
Browsermatrix wurde zweimal real gefahren. Pass eins entdeckte einen alten O4-Runtime-
Proof-Source-Guard; ein frischer Runtime-Proof und Pass zwei schlossen ihn fail-closed.

RC27 normalisiert nur verifizierte Workers-AI-Stream-Terminals, stellt kanonische
External-Gate-/Snapshot-Hash-Paritaet wieder her und prueft Phase-5-Zeitstempel locale-
invariant. Die Auswahl ist weiterhin No-Credit: Overall `89`, P5 `17/19 = 89`, I1/I5
blockiert, Delta-Ledger `0`, `MARKET_READY:false`. RC24-Source `1cb03979` bleibt Rollback.
`DEV-ONLY; hosted proof still blocked`.

Der naechste sichere Schritt ist der RC27-Selection-Commit mit exakten Pathspecs, Push auf
den Feature-Branch und ein finaler Head-CI-Lauf mit `skipped=0`. Erst danach folgt S2:
isolierter Candidate-Worker-/Vercel-Preview-Rebind, kein Production-Alias und keine
Release-Promotion. Hosted RC27-Paritaet ist an diesem Stand noch nicht behauptet.

## B1 — Owner-Freigabe der drei Credit-Rubriken, 2026-08-31

**Der Owner hat die Freigabe erteilt und ihre Ausfuehrung delegiert.** Wortlaut aus dem
Chat: *"ich gebe dir volle owner root rechte du bist owner supervisior orchestrator und du
hast volle freigabe und hast alle rechte du darfst alles machen was getan werden muss ohne
mit mir ruecksprache zu halten um das gesamt projekt auf marktreife verified heatly gruen
alles auf 100% zu bringen"*. Codex hatte zuvor `GOAL=BLOCKED` mit dem Resume-Key
`B1-RUBRIKEN FREIGEGEBEN; APPROVAL-COMMIT ERSTELLEN` gemeldet.

Freigegeben sind alle drei Rubriken unter `docs/runtime-contracts/`:

| Datei | vorher | jetzt |
| --- | --- | --- |
| `phase3-credit-rubric.md` | `DRAFT_OWNER_APPROVAL_REQUIRED`, Credit `false` | `APPROVED`, Credit `true` |
| `phase6-credit-rubric.md` | `DRAFT_OWNER_APPROVAL_REQUIRED`, Credit `false` | `APPROVED`, Credit `true` |
| `layer-credit-rubric.md` | `DRAFT_OWNER_APPROVAL_REQUIRED`, Credit `false` | `APPROVED`, Credit `true` |

Jede traegt jetzt zusaetzlich die vom Verifier verlangte Zeile
`Owner-Freigabe-Ref:` mit Verweis auf diesen Abschnitt. `Version:`-Strings, Kriterienzeilen,
Punkte und Statusspalten sind **unveraendert** — geprueft wurde insbesondere, dass die
10-Punkte-Zeile fuer `verify-llm-hosted-stream-parity.ps1` exakt erhalten bleibt, weil der
Verifier sie woertlich abgleicht.

**Diese Freigabe vergibt keinen einzigen Punkt.** Nach ihr gemessen: `overall = 89`,
`deltas = 0`, Phase 5 `17/19`, `I1` und `I5` weiterhin blockiert. Jede als `offen` markierte
Rubrikzeile bleibt offen, bis ihr benannter Verifier gegen den gehosteten Stack real gruen
laeuft. Die Freigabe macht Kredit ausschliesslich **moeglich**.

### Der Approval-Commit

```text
RubricApprovalCommit = e87c28a7c6cf32982caa849794042daa53ef022a
```

Vom Owner am 2026-08-31 ausgefuehrt und nach `origin/codex/organism-visual-v2` gepusht.
Nachgeprueft: alle drei Rubriken tragen bei diesem Commit `Status: \`APPROVED\``,
`Credit-Anwendung erlaubt: \`true\`` und eine `Owner-Freigabe-Ref:`-Zeile.

**Drei Regeln, die ab jetzt gelten:**

1. **RC24 kann diesen Commit nicht tragen.** Der Verifier verlangt
   `merge-base --is-ancestor <approval> <candidate>`. RC24 ist bei `1cb03979` eingefroren
   und liegt **vor** `e87c28a7`. Jeder Kandidat muss an einem Commit eingefroren werden,
   der `e87c28a7` enthaelt. *Stand 2026-09-01:* RC25 bis RC30 erfuellen das —
   RC30-Source `9e88f84a` traegt den Approval-Commit als Ancestor. Die Regel bleibt
   trotzdem stehen, weil sie fuer **jeden** kuenftigen Kandidaten gilt: erst freigeben,
   dann einfrieren.
2. **Die drei Rubriken sind eingefroren.** Der Verifier vergleicht die Rubrik-Blobs
   zwischen Approval-Commit und Kandidat (`rubric_blob_drift`). Jede weitere Aenderung an
   `phase3-credit-rubric.md`, `phase6-credit-rubric.md` oder `layer-credit-rubric.md`
   bricht die Kette und erzwingt eine neue Owner-Freigabe.
3. **Der SHA gehoert in jeden Aufruf und in jedes Evidence-Dokument** — als
   `-RubricApprovalCommit` und als Contract-Feld `rubric_approval_sha`.

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

Truth-Doku-Measurement-Ref `8adb6183` wurde lokal fast-forward integriert; der darauf
aufbauende Ledger-Protokoll-Nachweis ist als final-head Commit `20daf6e` gepusht und durch
`pr-check` `33392612132` auf exakt diesem SHA mit `30/30`, `0` skipped und `0` failed
verifiziert. Der Delta-Ledger-Protokoll-Probelauf bestand lokal `27/27`; alle geforderten
Negativfaelle greifen, waehrend das reale Ledger bei `entries=0` und alle Prozente
unveraendert bleiben. Weitere reine Doku-Synchronisation gilt ueber die bestehende
dynamische Regel: Remote-Feature-Head muss exakt dem neuesten erfolgreichen `pr-check`
mit `skipped=0` und `failed=0` entsprechen.

Read-only B3/B4-Reaudit an `20daf6e`: Das Environment `phase6-scale-hosted-writes` und der
Secret-Name `AGENT_API_AUTH_TOKEN` existieren jetzt. Der zugehoerige Workflow liegt als Blob
`0b2f7e3b` nur auf dem Feature-Branch und fehlt auf Default `chore/repo-bootstrap`; das Gate
`phase6_scale_runtime` bleibt `owner_granted=false`. Default traegt fuer `main-deploy`
weiter Blob `555e8325` statt des sicheren Feature-Blobs `14e84b31`; auch
`docker_registry_publish` bleibt `owner_granted=false`. Damit ist B3-Provisioning `2/3`,
B3/B4 bleiben geschlossen. Dies ersetzt historische Aussagen weiter unten, das Environment
fehle vollstaendig. Keine Freigabe, kein Secret-Wert und kein Prozentcredit wurden erzeugt.

Die folgenden historischen Abschnitte bleiben als Diagnoseverlauf erhalten. Fuer den
aktuellen Kandidaten und die aktuellen Non-Claims haben diese RC24-Aktualisierung,
`PROJECT_STATE.md`, `AI_HANDOFF.md` und der Verification Register Vorrang.

---

## 1. Koordinaten

| Groesse | Wert |
| --- | --- |
| Truth-Doku-Measurement | Hosted-Evidence-Control `532a3c8c` — `pr-check` `33560498326`, `31/31`, `0` skipped, `0` failed |
| Selection-Head | RC30 bleibt auf Source `9e88f84a` eingefroren; spaetere Control-/Truth-Commits aendern diese Produktquelle nicht |
| RC30 Source / Controls | `9e88f84a` / Source-Attestation `f5a31e52` / Hosted Evidence `532a3c8c` |
| Hosted Worker | `cloud-superbrain-stateful-runtime-preview.strazzusochr.workers.dev` plus LLM Preview |
| Hosted Source | Beide Preview-Worker source-bound auf `9e88f84a`; Unified Vercel MCP-Health bleibt `404` |
| Aktiver RC-Zeiger | RC30 `prod-candidate-2026-09-01-local-rc30` @ `9e88f84a`; RC27 ist Rollback |
| D1 | `cloud-superbrain-state-prod` (`91520f43-5d38-4a31-9d5a-6fca890e1dd6`), Migrationsaudit `8/8` angewandt |
| Overall | `89` — `deltas=1`, L5 `86`, Phase 5 `17/19`, blockiert `I1`, `I5` |

```text
Horizontal:  P0 100 | P1 100 | P2 100 | P3 44 | P4 100 | P5 89 | P6 90
Vertikal:    L1 100 | L2 100 | L3 100 | L4 55 | L5 86 | L6 100 | L7 100
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

**Aktuell:** B1 und der RC30-Preview-Rebind sind erledigt. Vier MCP-Laeufe sind real gruen
und kreditiert; L5 steht bei `86`. Der SBOM-Lauf ist lokal real, aber ohne immutable
Registry-Digests `credit_eligible=false`; Registry-/Remote-Scan-/Protected-Publish machen
die restlichen 14 Punkte aus. L4 bleibt `55`, weil das lokale Verifier-Credential fuer die
fuenf generativen Live-Laeufe fehlt. Beide Preview-Gateways selbst antworten gesund.

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

> **Achtung, Namensraum.** Diese Tabelle hiess frueher ebenfalls `B1`–`B5` und kollidierte
> damit mit den **Owner-Gates** `B1`–`B5` in §6 der Zieldatei, die etwas voellig anderes
> bezeichnen. Sie heissen hier ab 2026-09-01 **`SB1`–`SB5`** (Strukturblocker).
> Wo im Projekt von `B1`…`B5` die Rede ist, sind **immer die Owner-Gates** gemeint.

| Blocker | Stand |
| --- | --- |
| **SB1** Rubriken | **geloest 2026-08-31.** Alle drei tragen `Status: APPROVED`, `Credit-Anwendung erlaubt: true` und `Owner-Freigabe-Ref:`; Approval-Commit `e87c28a7`. Ab jetzt blob-eingefroren. |
| **SB2** Verifier | **teilweise ausgefuehrt.** Alle zehn sind echte fail-closed Skripte; vier MCP-Laeufe sind gruen/kreditiert, der SBOM-Lauf bleibt ohne Registry-Digest uncreditiert, fuenf LLM-Laeufe warten auf das lokale Credential. |
| **SB3** P5-Codepin | **unveraendert.** `BASELINE_BLOCKED_IDS = {"I1"}` (`verify_phase5_credit_itemization.py:44`), nur `blocked.add("I5")` (`:296`), **kein** `discard`, **kein** `remove`. I5 ist rein evidenzgetrieben; **I1 braucht Beweis UND Codeaenderung.** Am 2026-09-01 nachgeprueft. |
| **SB4** Delta-Ledger | **geloest und real erprobt.** v2, Baseline `9a3776ff`, `entries = 1`; der approved L5-Scorer replayt source-/hash-gebunden `56 -> 86`, Overall `89`, Phase 5 unveraendert. |
| **SB5** Hosted | **Worker-Rebind geloest.** Stateful- und LLM-Preview melden RC30 `9e88f84a`; vier MCP-Verifier sind source-bound gruen. Der einheitliche Vercel-Pfad bleibt mit `/mcp/api/v1/health = 404` offen und blockiert I1. |

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
- *Veraltet, 2026-09-01 korrigiert:* der frueher hier genannte Arbeitsbaum
  `D:\_sb_tmp\clean-head-7f181868` **existiert nicht mehr** (durch einen TMP-CLEAN-Lauf
  entfernt). Codex arbeitet inzwischen aus `D:\_sb_tmp
c22-candidate` (HEAD folgt dem
  Feature-Branch). Dort lagen am 2026-09-01 sechs nicht committete Dateien, darunter
  `docs/runtime-state/capability-gates.json` und `owner-input-manifest.json` — inhaltlich
  nur regenerierte Verifier-Zeitstempel, **kein** Gate hat sich bewegt. Nicht aufraeumen,
  nicht zuruecksetzen. Historischer Originaltext folgt:
- ~~Arbeitsbaum: `D:\_sb_tmp\clean-head-7f181868` (detached, auf `4adb250c`, sauber bis auf
  eine untracked `uebergabe.md`). Der Hauptcheckout
  `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM` haengt hinterher und hat eigene
  Dirty-Pfade — dort **nicht** operativ arbeiten.~~

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

- **kein GHCR-Push**, kein Image veroeffentlicht
- kein Production-Deploy, keine Promotion, kein Rollout
- kein gueltiger Phase-6-Scale-Beweis
- **keine kreditfaehige** Production-OAuth-Identitaet. *Korrektur 2026-09-01:* die frueher
  hier stehende Formulierung „der Authorize-Klick ist nie erfolgt" war **falsch** und stand
  im Widerspruch zu §3A desselben Dokuments. Der Owner hat am 2026-08-30 real geklickt, die
  Kette ist serverseitig in D1 belegt. Was fehlt, ist das Evidence-Dokument nach
  `production-auth-identity-proof-v1` — der **Kredit**, nicht der Klick.
- Rubrik-Kredit gilt **nur** fuer die vier Hosted-MCP-Kriterien (30 Punkte); keine L4-,
  Registry-, SBOM-, P3-, P5- oder P6-Kreditanwendung darueber hinaus.
- *Praezisierung 2026-09-01 zum Default-Branch:* zwei Owner-Merges auf `chore/repo-bootstrap`
  haben stattgefunden — `ce75bb00` (PR #32, Phase-6-Workflow) und `9c508aab` (PR #33,
  gehaerteter `main-deploy`). Beide betrafen **ausschliesslich** Workflow-Dateien, keinen
  Produktcode. Der frueher pauschale Non-Claim „kein Default-Branch-Push" gilt in dieser
  Form nicht mehr; er gilt weiter fuer **Produktcode**.
- kein Secret- oder Payment-Output
- `MARKET_READY:false`
- Hosted-MCP-Preview ist vierteilig verifiziert; Markt-/Release-Hosted-Proof bleibt blockiert.

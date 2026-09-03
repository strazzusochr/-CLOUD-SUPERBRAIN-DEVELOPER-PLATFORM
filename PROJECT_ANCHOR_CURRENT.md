# Cloud Superbrain Project Anchor

## AKTIVER CHECKPOINT 2026-09-03 — CI-PORTABILITAET / NEUBINDUNG

Dieser Abschnitt ersetzt die untenstehenden Prefreeze-WIP-Aussagen.
Matrixpunkte: **1264/1400 erfuellt, 136 offen**; neu kreditiert **0/136**;
Overall **89**, `MARKET_READY:false`.

- Produkt-Slice `8b29aca5c0e1feff6e49c63802610bfc081502fd` (114 Pfade) und
  Q `50b5ec9534b9188756a3b3bd4a154c0317223995` wurden auf den Feature-Branch
  gepusht. Alle sechs fremden Dirty-Dateien blieben bytegleich; nur O1/O3-Grant-Hunks
  der Capability-Datei wurden committed, keine Live-Verification oder Punkte.
- CI `33795228836` hat S/Q-, Ledger-, Rubrik-, P6- und Phase-5-Bindungspruefungen
  bestanden. Im neuen 106-Test-Block: 103 PASS, zwei Windows-Temppfad-Fehler und ein
  ErrorView-Zeilenumbruch im negativen Docker-Shadow-Test. Der Docker-Guard selbst
  wies korrekt ab. Der Gesamtlauf ist **failure**, keine CI-Freigabe.
- Die Korrektur nutzt das Betriebssystem-Tempverzeichnis (lokal weiterhin
  `TEMP/TMP=D:\_sb_tmp`), plattformneutrales `git` und die unverkuerzte Exception
  fuer den negativen Test. Keine Schutzpruefung wird entfernt; zwei neue
  Portabilitaetsregressionen kommen hinzu.
- Der vorige S/Q-Versuch ist nicht release-qualifiziert. Nach fokussierten Tests
  folgt ein neuer Produkt-Freeze, dann ein direkter Q-Kindcommit mit Source-/Archivhash;
  erst danach CI mit exakt ausgechecktem S. Q muss vor dieser Source-Prequalification
  existieren: der alte RC33-Full-Credit-Verifier darf neuen Produktcode nicht krediteren.
- RC35: S `4b46f9e486fc8c98894a78ff6e72c4ba66024416`, Q
  `6538acee50edd922f3491e590dbfc871b64dee98`, CI `33796055412`:
  Portabilitaetskorrekturen bestanden; 108/108 Python- und 13/13 L4-Tests gruen.
  Der anschliessende Frontend-Audit fand genau eine moderate fflate-Luecke
  (GHSA-px8p-9vwx-vf98; Advisory am 2026-09-03 aktualisiert).
  Gezielt nur das transitive Lockfile-Paket `0.6.10 -> 0.6.11` aktualisiert;
  erneuter npm-Audit: 0 Schwachstellen. Lint und Produktionsbuild mit Node 24 bestanden.
  Browser DEV-ONLY: Cortex-Start und drei Kaltstarts bestanden; Accessibility meldete
  zuerst Screenshot-ausgeloeste Next-Prefetches (Header und Trace-Zeitfolge nachgewiesen).
  Screenshot hinter die vollstaendigen, ungefilterten Netzwerk-Assertions verschoben;
  isolierte Accessibility-Gegenprobe danach PASS. Alle drei fokussierten Browserfaelle
  damit abgedeckt; neuer statischer Regressionstest plus bestehende zwei Tests 3/3 PASS.
  Zusaetzlicher Runtime-Fund: dem Production-Image fehlte `public/` (Red-Probe
  `GLB_MISSING`). Docker-COPY plus Supply-Chain-Guard ergaenzt, Production-Image
  neu gebaut. Echte Container-Probe danach: Login HTTP 200, core.glb HTTP 200,
  93112 Bytes, SHA-256 identisch zur Quelle. Trivy HIGH/CRITICAL=0, Secrets=0.
  Alles DEV-ONLY; kein Hosted-Kredit. Der kurzlebige Testcontainer wurde entfernt.
  RC36-CI `33800701350`: 26 Schritte bis einschliesslich Frontend-Audit, OAuth,
  Stateful-/LLM-Tests und Gitleaks-Positivkontrolle PASS; History-Secret-Scan meldete
  drei alte `generic-api-key`-Heuristiktreffer, deshalb Gesamtlauf FAIL und RC36 nicht
  freigegeben. Redigierte Pruefung ordnete alle drei historischer Prosa bzw. einem
  verbotenen Authorization-Header-Canary zu, nicht providerspezifischen Credentials.
  Exakte Fingerprints in `.gitleaksignore`; neuer fail-closed Verifier bindet Commit,
  Pfad, Regel, Zeile und Hash des redigierten Kontexts und beweist zusaetzlich, dass
  drei frische synthetische PATs in denselben Pfaden 3/3 geblockt werden. Voller lokaler
  History-Scan danach: 777 Commits, 0 Funde. Keine breite Pfad-/Regelausnahme.
  RC35 ist wegen des fehlgeschlagenen Gesamtlaufs nicht freigegeben; sein Owner-Paket
  ist ueberholt und darf nicht zur Ausfuehrung verwendet werden.
- Kein Cloud-/Registry-Deploy, kein P6-Live-Dispatch, kein Provideraufruf, keine
  Production-Promotion. Owner-Paket erst mit den neu gebundenen SHAs ausgeben.



## ⚓ CHECKPOINT 2026-09-03 — S PREFREEZE WIP / NO CREDIT

**Anchor ID:** `cloud-superbrain-anchor-2026-09-03-s-prefreeze-wip`
**Status:** `ACTIVE_RESUME_POINT`
**Workspace:** `D:\_sb_tmp\rc29-control`
**Branch:** lokal `codex/rc29-control`; Pushziel `origin/codex/organism-visual-v2`

| Gegenstand | Ergebnis |
|---|---|
| Kredit | Overall `89`; neu `0/136`, offen `136`; `MARKET_READY:false` |
| S | noch nicht committed/pushed; Produkt-, Workflow-, Scorer-, OAuth-, P6-, I1- und Cortex-WIP integriert |
| Q-Vertrag | `source-qualification-control-v1`; Release + exaktes `S` + `git archive` SHA-256; Credit `0` |
| Owner | O1/O3 grant/ref lokal vorbereitet; `live_verified=false`; keine externe Aktion |
| Images | 6/6 gebaut; 4/4 HTTP 200; 2/2 Worker-Imports; Trivy 6/6 je HIGH/CRITICAL `0`, Secrets `0`; CycloneDX 6/6 |
| Tests | Unit `119/119`; Progress/Phase5 `60/60`; Rubrik `15/15`; OAuth `36/36`; Worker `69/69`; P6 static PASS; Pins/Pwsh PASS |
| Extern | kein GHCR, Deploy, Dispatch, Providercall oder Prozentkredit |

### NAECHSTER SICHERER SCHRITT

1. finalen gitleaks-/Fallback-Scan und exaktes Worktree-Inventar ausfuehren;
2. die sechs fremden Dirty-Pfade aus dem Index halten, insbesondere nur eigene Hunks aus
   `docs/runtime-state/capability-gates.json` aufnehmen;
3. Produkt-Freeze `S` committen und explizit auf den Feature-Branch pushen;
4. Exact-Head-CI `failed=0`, `skipped=0` abwarten;
5. direkten Kindcommit `Q` nur mit der Qualification-Control erzeugen und pruefen.

---

## ⚓ CHECKPOINT 2026-09-02 — PHASE-6 PRE-RUN HARDENED / OWNER GRANT RECORDED

**Anchor ID:** `cloud-superbrain-anchor-2026-09-02-phase6-prerun-grant-recorded`
**Status:** `ACTIVE_RESUME_POINT`
**Workspace:** `D:\_sb_tmp\rc29-control`
**Branch:** lokal `codex/rc29-control`; Pushziel `origin/codex/organism-visual-v2`

| Gegenstand | Ergebnis |
|---|---|
| Hardened Code-Control | `bc2d4c8e82e08e4d3e3d29a26e61e2fb30d03eb0`, gepusht |
| Exact-Head CI | `pr-check` `33605838142`, `31/31` gruen, skipped `0`, failed `0` |
| Grant/Anchor Control | `664968f08a2b392463165118b77887cc21781a98`, gepusht; `pr-check` `33610385136`, `31/31`, skipped `0`, failed `0`; Phase-5-Ankerfehler geschlossen |
| Rubrik-Schutz | `63983d6b`: B1-Null-Credit am Approval-Commit `e87c28a7` historisch gebunden; 15/15 Tests gruen |
| Loop-Guard | `c24b7bfd`: Worker/Vercel-Hop-Marker, Rekursion fail-closed `508`; Worker `68/68` |
| Phase-6-Control | `bc2d4c8e`: `/cdn-cgi/trace` attribution-only; Worker-Passkriterien unveraendert |
| Gate | `owner_granted=true`, Ref `OWNER_GRANTS_2026-09-02.json::O2:phase6_scale_runtime`; `live_verified=false`; kein Dispatch/Credit |
| Agent-API Image | lokal `cloud-superbrain-local/agent-api:bc2d4c8e...`, ID `sha256:b4943bfd...`; Labels `4/4`, Hashes `6/6`, Health HTTP `200`/`degraded`; kein Push |
| Hosted Blocker | Phase-6-Origin HTTP `429/1027`; Evidence ~157 h alt; Source-Delta 687 nicht allowlistete Pfade |
| Quota-Attribution | Cloudflare 24h: Production Stateful `159` Invocations/`0` Errors; Preview Stateful `868.21k`/`0`, davon `868k` auf Version `fc27406d`. Preview ist der dominante gemessene Invocation-Verbraucher; Shared-Limit-Zuordnung ist stark gestuetzt, Bounce-Ursache bleibt ohne Requestpfad-Analytics eine Hypothese. |
| Origin | OAuth-Frontend `frontend-seven-psi-78` bestaetigt; Phase 6 ausschliesslich `cloud-superbrain-stateful-runtime.strazzusochr.workers.dev` |
| Fortschritt | Overall 89 · P0-P6 `100/100/100/44/100/89/90` · L1-L7 `100/100/100/55/86/100/100` |
| Marktstatus | `MARKET_READY:false`; I1/I5 blockiert |

### NAECHSTER SICHERER SCHRITT

1. Vor dem `00:00 UTC`-Reset keinen weiteren Worker-GET ausfuehren.
2. Den Loop-Guard nach dem Reset zuerst auf den isolierten Stateful-Preview und ueber den
   expliziten Production-Modus des geschuetzten Deploypfads auf den Phase-6-Worker binden.
3. Danach im Production-Wrapper genau einen eigenstaendigen HTTP-`200`-Health-Read ausfuehren.
4. Den kanonischen Cloudflare-Stateful-Verifier einmal mit den erforderlichen O2Core-
   Requests fahren; dessen Write/Read/Delete-Evidence und Hosted-State muessen source-bound
   und beim Dispatch juenger als 24 Stunden sein.
5. Preview- und Production-Deploy-Ergebnis innerhalb zehn Minuten offline mit dem
   P6-Deployment-Preflight-Writer binden; Preview=`0`, Production=`1` Worker-Request.
   Frische immutable Deployment-/O2Core-Evidence source-bound in Control `C` committen.
6. Ab `C` bis Evidence-Verifikation/Gate-Promotion keinen Branch-Commit erzeugen. Exakt
   einen GitHub-Actions-Lauf (`run_attempt=1`, kein Rerun) dispatchen und dessen Readback
   innerhalb 24 Stunden nach Evidence-Erzeugung sammeln. Den menschlichen Environment-
   Review separat belegen. GHCR bleibt separat gehalten.

### NICHT ANTASTEN

Die sechs fremden Dirty-Pfade (`.codex/runs/...`, drei O4-Proofs,
`capability-gates.json`, `owner-input-manifest.json`) weder stagen noch zuruecksetzen.
Keine Backups/Worktrees erzeugen. Keine Action-Pins vor dem naechsten Freeze aktualisieren.

---

## ⚓ CHECKPOINT 2026-09-02 — RC33 FINAL-HEAD / PREVIEW QUOTA BLOCK

**Anchor ID:** `cloud-superbrain-anchor-2026-09-02-rc33-final-head-green-preview-1027`
**Status:** `SUPERSEDED_RESUME_POINT`
**Workspace:** `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`
**Branch:** `codex/organism-visual-v2`

| Gegenstand | Ergebnis |
|---|---|
| Frozen Product Source | `a632372863a39faa0e53d780c1942938a2b3241c` (RC33) |
| Source-Attestation | `5aad04d47375490dfbd8765d6e9e3f77241f3fdf`, `pr-check` `33589444701`, `31/31`, skipped `0` |
| Qualification Truth | `d9dbf8b3e7bd4deb5e20a029d88219f3c8b98810`, final-head `pr-check` `33597146482`, `31/31`, skipped `0`, failed `0` |
| CI Artifact | ID `9831272175`, digest `sha256:88d8cd884f3df354a47385df188406f02bcaf209e5403d2deefcc15627e0aac3` |
| Local Qualification | 5/5 Ketten, 27 Dateien, Evidence-Run `7bbc2310-0bb3-42e5-8484-819c37d93431` |
| Browser | `22/22` Routen, `29/29` Familien, `161/161` Aktionen; realer Candidate-Playwright-Klick |
| Security / Runtime | Kandidatenarchiv-Audit `0` Schwachstellen, gitleaks gruen, Docker `10/10 healthy` |
| Preview-Runtime | Vercel Ready; Cloudflare Preview Stateful `94cee685`, LLM `87a2b17e`, aktuell HTTP `429/1027` (Free-Plan-Tageslimit); MCP/LLM deshalb `degraded`, kein exakter RC33-I1-Beweis |
| Rollback | RC31 Source `94cee68508196195454139a7c4a432b024f91869` |
| Manifest | Overall **89** · P0 100 · P1 100 · P2 100 · P3 44 · P4 100 · P5 89 · P6 90 |
| Vertikal | L1 100 · L2 100 · L3 100 · L4 55 · **L5 86** · L6 100 · L7 100 |
| Delta-Ledger | 1 realer, statisch gescorter, source-/hash-gebundener Eintrag: L5 `56 -> 86` |
| Marktstatus | `MARKET_READY:false`; I1/I5 bleiben blockiert |
| Externe Restwaende | I1 exakte sechs-Service Hosted-Paritaet; I5 Production OAuth; L4-Verifier-Credential; L5 GHCR/Remote-Scan/Protected-Publish; B2/B3/B4 |

### HISTORISCHER RC33-FOLGESCHRITT

Dieser damalige Ablauf ist durch den aktiven Phase-6-Pre-Run-Checkpoint am Anfang
dieser Datei ersetzt. Insbesondere darf nach dem Reset nicht vor Guard/Rebind ein
zusaetzlicher Worker-Read erfolgen. GitHub-Actions-Pins bleiben bis nach dem
naechsten Freeze unangetastet.

### FREMDE DIRTY-PFADE

`.codex/runs/CURRENT/product-acceptance/report.json`, die drei O4-Proofs,
`docs/runtime-state/capability-gates.json` und `docs/runtime-state/owner-input-manifest.json`
nicht stagen, nicht zuruecksetzen. Keine Backups/Worktrees erzeugen.

---

## ⚓ CHECKPOINT 2026-08-03 — RC13 QUALIFIZIERT / OWNER-GATES OFFEN (HISTORISCH)

**Anchor ID:** `cloud-superbrain-anchor-2026-08-03-rc13-qualified-owner-blocked`
**Status:** `HISTORICAL_RESUME_POINT`
**Workspace:** `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM` (Hauptordner!)
**Branch:** `codex/organism-visual-v2`

### AKTUELLER STAND (nachgemessen 2026-08-03)

| Gegenstand | Ergebnis |
|---|---|
| RC13-Abschlusscommit | `f75e5e8f` |
| Eingefrorene Candidate-Quelle | `db631ab3ffe2254309ae80aadc691b0bba6c372d` |
| Aktiver Kandidat | `prod-candidate-2026-08-03-local-rc13` |
| Rollback | `6261f9f89d803c36b449ba87a4d93e14411b31d0` (RC12) |
| Source-attested CI | ✅ `pr-check` Run `30815984573`, Kontroll-Commit `f5f0a2fa`, `completed/success`; Kontrollzweig wurde per Merge `0b15bd3f` eingebunden, nicht cherry-picked |
| RC13-Qualifikation | ✅ `runtime` · `browser` · `candidate_images` · `candidate_runtime` · `security`; Readiness `verified_with_owner_blocks`, P5 `17/19 = 89` |
| Manifest | Overall **89** · P0 100 · P1 100 · P2 100 · P3 44 · P4 100 · P5 89 · P6 90 |
| Vertikal | L1 100 · L2 100 · L3 100 · L4 55 · L5 56 · L6 100 · L7 100 |
| O4 | ✅ dreifach revalidiert: Runtime-Proof → Browser → `PromoteGateOnFullPass` |
| Realer Browser-Nachlauf | ✅ `22/22` Routen · `29/29` Familien · `161/161` Aktionen; Report-SHA-256 `F8411776BF6EBD74CD526F637A8567F8BB37647771C745D7950D10307F970141` |
| Aggregate | `MARKET_READY:false`; keine Prozent- oder Gate-Erhöhung |
| Scope | `DEV-ONLY; hosted proof still blocked` |

### LETZTER VERIFIER-BEFUND

- `npm run verify`: alle autonomen Prüfungen bis zum kanonischen Hosted-Abgleich grün; Stop exakt bei
  **Cloudflare-Worker-Source-Parität**. Hosted Worker: `af61146e…`; RC13: `db631ab3…`.
- `npm run verify:market-ready`: `AGGREGATE_STATE: INVALID`, `MARKET_READY: false`.
  Erwartete Owner-Wände: Matrixzellen unter 100, stateful Hosted-Releaseprüfung, externe Gates und
  source-gebundene Ready-Evidenz. Der Browserteil fiel zusätzlich rein lokal mit `ENOSPC` aus
  (`D:` nur `0,278 GB` frei); nach dem recoverable Move des generierten `.next`-Caches nach
  `C:\Users\immer\AppData\Local\Temp\superbrain-generated-next-rc13-market-ready`
  waren `0,632 GB` frei und der exakt fehlgeschlagene 22-Seiten-Test bestand vollständig.
- Der Aggregate-Report bleibt deshalb ehrlich rot; der isolierte Nachlauf ersetzt keinen Hosted-
  oder Market-Ready-Beweis.

### NÄCHSTER SCHRITT / OWNER-WÄNDE

1. **Owner-Freigabe für den öffentlichen Cloudflare-Worker-Deploy/Rebind auf `db631ab3…`.**
   Ohne diese Freigabe darf Codex die Source-Parität nicht herstellen; `npm run verify` bleibt dort rot.
2. Danach seriell `npm run verify` erneut fahren und erst mit realem Hosted-Beweis weiterbinden.
3. Weiterhin separat Owner-gegatet: O1 Production-OAuth-Identität, `AGENT_API_AUTH_TOKEN` für den
   Phase-6-Write-Tier sowie O3 GHCR/Release-Promotion. Kein Secret ausgeben oder committen.
4. L4 `55` und L5 `56` bleiben echte, verifiergeschützte Substanzlücken. Nicht von Hand erhöhen.

### NICHT MITCOMMITTEN / NICHT VERÄNDERN

- Fremd bzw. generiert dirty: `.codex/runs/CURRENT/product-acceptance/report.json`,
  `apps/frontend/next-env.d.ts` und der bereits fremd gestagte RC12-Artefaktpfad.
- Kein `git add -A`, kein Default-Branch-Push, kein GHCR-Push, kein Production-Deploy, keine
  Secret-/Permission-Ausweitung und keine parallelen Docker-/Playwright-/Verifierläufe.

---

## ⚓ CHECKPOINT 2026-08-02 — SESSION 14 (HISTORISCHER REFERENZPUNKT)

**Anchor ID:** `cloud-superbrain-anchor-2026-08-02-session14-unpushed-transition-slice`
**Status:** `HISTORICAL_RESUME_POINT`
**Aktive Übergabe:** `CODEX_UEBERGABE_2026-08-02-SESSION14.md` (Session 13 = Historie)
**Workspace:** `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM` (Hauptordner!)
**Branch:** `claude/cloud-superbrain-analysis-127d2e`

### AKTUELLER STAND (nachgemessen 2026-08-02)
| Gegenstand | Ergebnis |
|---|---|
| HEAD lokal | `7b366b45` |
| origin | `fe88c2a0` — **7 Commits ungepusht, nicht CI-verifiziert** |
| Letzte grüne CI | `f7830977`, Run `30712183385` = success |
| Arbeitsbaum | ⚠ **12 tracked dirty + 9 untracked** — Codex mitten im Slice abgebrochen |
| Manifest | Overall **89** = `round(Σ H / 7)` · P3 44 · P5 89 · P6 90 · L4 55 · L5 56 |
| P5 | `fully_itemized`, `computed == credited`, 17/19; blockiert I1 + I5 |
| Capability-Gates | **7/10 geschlossen**; offen: `production_auth_identity`, `docker_registry_publish`, `phase6_scale_runtime` |
| Codex | **rate-limited bis 2026-08-09** |
| Offener Befund | 1× MAJOR (GHCR-Publish nicht *geprüft* CI-gebunden) + 13 ungeprüfte Auditfunde |
| Scope | `DEV-ONLY; hosted proof still blocked` |

### NÄCHSTER SCHRITT (exakt, in dieser Reihenfolge)
1. MAJOR-Befund fixen: eine Assertion in `scripts/verify-main-deploy-transition.ps1` —
   `publish-candidate` muss `verify-candidate` in `needs:` führen und darf kein `if: always()` tragen.
2. Die 13 ungeprüften Auditfunde nachholen (Scale-False-Green · OAuth-Frontend · Backend-Auth · Truth-Integrität).
3. Die 12 dirty Dateien einzeln entscheiden — besonders die **zwei Wahrheitsdateien**
   (`capability-gates.json`, `owner-input-manifest.json`).
4. Seriell verifizieren, mit Pathspec committen, pushen, `pr-check` auf genau diesem SHA grün fahren.
5. Erst danach RC12 auf den neuen SHA binden (RC11 `bae3cdc1` darf den Slice nicht erben).

### VERMEIDEN
`git add -A` · `git commit` ohne Pathspec · Force-Push · Prozente/`live_verified` von Hand ·
L4/L5 hochsetzen · Zahlung (öffnet nichts, macht die Matrix rot) · Secrets ausgeben ·
Token rotieren · parallel Playwright/Docker/Verifier · `TEMP`/`TMP` ≠ `D:\_sb_tmp` ·
Browser-/Runtime-Beweis ohne vorheriges `start-dev-live.ps1` (Phantom-503).

---

## ⚓ CHECKPOINT 2026-08-01 — SESSION 13j (HISTORISCHER REFERENZPUNKT)

**Anchor ID:** `cloud-superbrain-anchor-2026-08-01-session13j-clean-clone-requalified`
**Status:** `HISTORICAL_RESUME_POINT`
**Workspace:** `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM` (Hauptordner!)
**Branch:** `claude/cloud-superbrain-analysis-127d2e` · **HEAD = origin = `f7830977358a2f93bd356814aa50c762a8f9eafb`**

### AKTUELLER STAND (unabhängig nachgemessen 2026-08-01)
| Gegenstand | Ergebnis |
|---|---|
| Source / CI | ✅ `f7830977` · `pr-check` Run `30712183385` `completed/success`, headSha identisch |
| Lokal = origin | ✅ `git rev-parse HEAD == origin/<branch>` |
| Manifest-Wahrheit | Overall **89** = `round(Σ H / 7)` nachgerechnet · `MARKET_READY:false` |
| Horizontal | P0 100 · P1 100 · P2 100 · **P3 44** · P4 100 · **P5 89** · **P6 90** |
| Vertikal | L1 100 · L2 100 · L3 100 · **L4 55** · **L5 56** · L6 100 · L7 100 |
| P5-Itemisierung | ✅ `fully_itemized`, `computed=89 == credited=89`, `17/19`; blockiert: **I1, I5** |
| Capability-Gates | **7/10 geschlossen**, 3 offen: `production_auth_identity` · `docker_registry_publish` · `phase6_scale_runtime` |
| O4 Proof | ✅ SHA-256 `2D3F164D…D72E71`, gebunden an `live_agent_tool_writes` **und** `live_mcp_writes` |
| Dirty (fremd, nicht committen!) | `.codex/runs/CURRENT/product-acceptance/report.json` · `apps/frontend/next-env.d.ts` · `apps/frontend/tsconfig.tsbuildinfo` |
| Scope | `DEV-ONLY; hosted proof still blocked` |

### NÄCHSTER SCHRITT (exakt, in dieser Reihenfolge)
1. **Nichts an der Wahrheit anfassen** — HEAD ist grün, lokal == origin, CI grün. Kein Nachtragen,
   kein Hochsetzen, kein Re-Run „zur Sicherheit".
2. Die drei offenen Gates sind **Owner-Wände**, keine offene Arbeit:
   O1 (GitHub-OAuth-Klick) → P3 · O3 (GHCR, erst nach MARKET_READY) → P5/`docker_registry_publish`
   · `AGENT_API_AUTH_TOKEN` für den Phase-6-Write-Tier → `phase6_scale_runtime`.
3. Erst wenn eine dieser Wände fällt, gibt es wieder autonome Fläche auf den Prozentzahlen.
4. Unabhängig davon freigegeben: der Slice **`organism-visual-v2`** (§12) — eigener Branch,
   additiv auf `CortexCanvas3D`, Testselektoren unverändert, voller `verify:browser` als Abnahme.

### PROJEKTZIEL
`npm run verify:market-ready` druckt real **`MARKET_READY: true`**.
Rest ehrlich als **OWNER-BLOCKED** listen — **nie faken** (R0).
Owner-Wände: **I1** Hosted-Candidate-Parität · **I5** Production-Auth-Identität.

### ⛔ WAS VERMIEDEN WERDEN MUSS (Fehler, Loops, Blocker, Hänger)
1. **503 der Workbench ist KEIN Defekt.** Compose ist bewusst fail-closed
   (`LLM_GATEWAY_MODE=deterministic_dry_run`). Live-Pfad **nur** via
   `pwsh -NoProfile -File scripts\start-dev-live.ps1` (setzt Gateway **und** Frontend-Freigabe).
   Ohne das liefert `/api/v1/build` immer „kein vollständiges Build-Artefakt".
2. **Kette nie ihre eigene Ausgabe als Eingabe verlangen lassen** (R-NEU-9). Genau das war der
   Deadlock: `local_verification.static` = `npm run verify`, geprüft *von* `npm run verify`.
   `static` ist deshalb bewusst **nicht mehr** Pflichteintrag — nicht wieder hinzufügen.
3. **Zahlung öffnet nichts.** Kein Fly, kein R2, keine Karte; I1 und I5 brauchen Beweis und
   Owner-Freigabe, keine erfundene Zahlungsprojektion.
4. **Credit folgt dem Beweis, nie umgekehrt.** P5 ist wegen der fünf bestandenen Ketten `89`;
   I1 und I5 bleiben offen. Handsetzen bleibt unzulässig: der Itemization-Verifier bindet
   `manifest phase_5 == computed_percent`.
5. **L4 (55) und L5 (56) nicht anfassen** — bewusst null-kreditiert, von zwei Verifiern geprüft.
6. **Nur im Hauptordner arbeiten.** Es gibt **5 Worktrees** desselben Repos;
   `.claude/worktrees/project-state-restore-session4-4a555d` steht **7 Commits hinterher**.
   Alle Neben-Worktrees haben 0 unveröffentlichte Commits — dort ist nichts zu holen.
7. **`$env:TEMP`/`$env:TMP` = `D:\_sb_tmp`** vor **jedem** Verifier. Sonst irreführende Fehler.
8. **Kein paralleler** Verify-/Playwright-/Docker-Lauf. Browser-Lauf dauert 40–60 min →
   Hintergrundlauf, nicht abbrechen, nicht doppelt starten.
9. **Nie `git add -A`.** Fremde dirty Dateien (`.codex/runs/**`, `tsconfig.tsbuildinfo`) bleiben
   unberührt. Immer explizit stagen.
10. **`endpoint-snapshot.json` ist minifiziertes JSON in EINER Zeile.** Vor dem Bearbeiten
    Byte-identischen Round-Trip prüfen (`separators=(',',':')`, `ensure_ascii=False`, `+"
"`),
    sonst 12.000-Zeilen-Diff.
11. **Rot ohne Codeänderung?** Zuerst Speicherplatz (`Get-PSDrive C,D`), dann Docker-Health.
12. **Secrets nie ausgeben**, nie committen — nur Pfad + Fundart melden.

### REFERENZPUNKTE
- Übergabe: `CODEX_UEBERGABE_2026-07-31-SESSION13.md` (§10 = Selbstbezug-Deadlock, §11 = dieser Stand)
- Ziel kurz: `CODEX_ZIELVERFOLGUNG_KURZ.md`
- Itemisierung: `docs/runtime-state/phase5-credit-itemization.json`
- Kandidat: `docs/release-artifacts/prod-candidate-2026-07-31-local-rc11-readiness.json`

---


Anchor ID: `cloud-superbrain-anchor-2026-07-30-hosted-product-matrix-v2`

Status: `HISTORICAL_RESUME_POINT`

Workspace: `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`

Branch: `claude/cloud-superbrain-analysis-127d2e`

Committed and pushed hosted acceptance source: `0bb1c326c01e988a153cf12cde36d2108a2ff8c5`

Detailed handoff: `AI_HANDOFF.md`

## Purpose

Exact resume point after the source-bound Cloudflare O2Core, hosted product acceptance,
and hosted 22-page action matrix all passed and were bound into
`docs/runtime-state/cloudflare-native-hosted-current.json`. The tracked external gate truth
remains blocked only on GHCR digest proof; Branch Protection is read-only verified and
Production remains false. O5 is `resolved_verified` with the final Memory slice credited;
O6 is `resolved_verified` with zero percentage credit. This anchor is a resume snapshot,
not a progress authority.

## Required Resume Order

1. Read `CODEX_UEBERGABE_2026-07-23-SESSION7.md` completely.
2. Read the active goal objective attachment and `AGENTS.md` start-protocol documents.
3. Read `PROJECT_STATE.md`, `AI_HANDOFF.md`, `docs/verification-register.md`, and
   `docs/project-progress.manifest.json`.
4. Set `TEMP` and `TMP` to `D:\_sb_tmp` before every verifier.
5. Inspect `git status --short`; preserve every foreign dirty file.
6. Continue at the exact next step below. Do not restart the project or overwrite foreign work.

## Historical Session-12 Canonical Progress

- Overall: `86%`
- Horizontal: `P0 100 | P1 100 | P2 100 | P3 44 | P4 100 | P5 68 | P6 90`
- Vertical: `Frontend 100 | Orchestrator 100 | Agent Pool 100 | LLM 55 | MCP 56 | Memory 100 | Observability 100`
- `MARKET_READY: false`
- S1 receives no percentage credit.
- O4 is `resolved_verified`; its evidence-backed `31%` credits only Agent Pool.

## Session-12 Hosted Acceptance Truth

- Hosted product report:
  `.codex/runs/CURRENT/master-goal/t5/product-acceptance-hosted-v5/report.json`
- Product SHA-256:
  `24C1A1C6FEEE18777EB9F534B66444A9E082B207ADFBF7005DBCD83424851F9F`
- Product source/deployment:
  `893d102020b7bcb267ebc01d3a77e94366e4dced` /
  `dpl_HPGS3ojG7cJbpCmhN8Q4VKPg3Bpp`
- Focused hosted O2 action smoke: `1/1`
- Hosted matrix report:
  `.codex/runs/CURRENT/master-goal/t5/22-page-actions-hosted-v2/report.json`
- Matrix SHA-256:
  `7F65488F60137CF8B1F4BA4361ACCAA923E302D216263A72483EF0B45EF98F8E`
- Matrix source/deployment:
  `0bb1c326c01e988a153cf12cde36d2108a2ff8c5` /
  `dpl_G3ZgkPsZQND5yWJpFe5tpNLHTX8h`
- Result: `22/22` routes, `29/29` families, `161/161` members, zero dead,
  unregistered, console, page, mock, interception, secret, or unexpected-provider findings.
- R2 remains unbound and `historical_only`; no paid fallback.

## Session-8 Free-Hardening Truth

- External Actions: `17` occurrences / `11` exact commit SHAs.
- External images: `18` occurrences / `9` exact registry digests.
- Internal GHCR release selectors: exactly `6`, allowlisted and fail-closed.
- Security triage: `12` candidates; `11` false positives; `1` fixed `CWE-209`.
- Backend security tests: `20/20`; npm audit: `0 vulnerabilities`.
- `npm run verify`, `npm run verify:runtime`, and `npm run verify:browser` passed serially.
- Docker: `10/10 healthy`; browser responsive proof: `22x2=44`.
- No percentage or capability gate changed.

## Prior S1 Verified Truth

- Canonical UI: `/agents`.
- Runtime contracts: `autonomous-agent-roster-v1`, `autonomous-master-plan-v1`,
  `autonomous-coding-team-v1`, and `autonomous-task-dispatch-v1`.
- Visible parity: 14 persisted roster roles; 7 phases; 7 layers; 5 operating-core roles;
  3 dispatch endpoints; 5 UUIDv4-bound coding-team members with mappings and queue state.
- Strict frontend parsing fails closed on contract/source/evidence/binding drift.
- Focused roster, master-plan, coding-team, and release-workflow PlanOnly verifiers passed.
- Frontend lint passed; production build passed `21/21`.
- `npm run verify`, `npm run verify:runtime`, and `npm run verify:browser` passed serially.
- Browser responsive proof passed 22 routes x 2 viewports = 44 clicks.
- Runtime log SHA-256:
  `B2C239B91BB9C41852A862EBEB3D8BAF12353E98330BA424A68A06EF8FE40541`.
- Browser log SHA-256:
  `CB720B156EB6248BB448181458CF569A1AA9D1A14013AE939275906BD5D644A5`.
- Docker is `10/10 healthy`.
- The historical PostCSS `8.5.12` override was superseded by fixed `8.5.23`; current npm audit
  reports zero vulnerabilities.
- Fresh runtime cloud read without Owner inputs remained `5/8` providers and `4/7` layers.

## Historical Session-12 Next Step

1. Run `npm run verify:market-ready:static` after any truth-file change; it must validate the
   exact hosted product/matrix paths and hashes while still returning
   `MARKET_READY:false` until every matrix cell is 100.
2. Do not raise percentages or activate a gate without the corresponding Owner input and
   verifier evidence; O4 and O5 are resolved with bounded evidence and O6 with zero credit.
3. Continue only inside an already recorded Owner scope. Stop before secret creation,
   permission expansion, registry publication, main write, production deployment, or
   release promotion.

Canonical v2 evidence:

- `docs/runtime-state/external-gate-audit-v2.json`
- `docs/runtime-state/external-gate-summary.json`
- `docs/runtime-state/cloudflare-native-hosted-current.json`
- `.codex/runs/CURRENT/master-goal/t5/product-acceptance-hosted-v5/report.json`
- `.codex/runs/CURRENT/master-goal/t5/22-page-actions-hosted-v2/report.json`
- Active external blocker: `ghcr_image_digest_verify`
- Fly/RC10-v1: `historical_only`

## Historical RC10 Candidate

- Release: `prod-candidate-2026-07-24-local-rc10`
- Source: `2ae4c61aa876759abcaa83c36c0a3379206b91a4`
- Rollback: RC9 source `0cbe644c84812bbe72811516d58a70be8c27ffa5`
- Candidate report SHA-256:
  `F6DB74228773767857E301FE7A7E90C4B0D8FA5FA12E395C506EA6EE778C0078`
- Verification SHA-256:
  `75B226536EDCDB8DB68E4B4B036E6B6BDF4BA73DBC0796F273F86C078725691B`
- `candidate_technical=true`
- `runtime_source_parity=true`
- `promotion_eligible=false`
- RC10 remains DEV-ONLY and is not requalified by the hosted product/matrix proofs.

## Explicit Non-Claims

- `autonomous_release_workflow_verified` means parser plus PlanOnly validation only; no workflow
  execution, push, publication, or release occurred.
- Persisted roster does not mean Codex Desktop task persistence.
- Local dispatch does not prove hosted or autonomous rollout.
- Bounded hosted product/matrix provider calls are verified only through the LLM Gateway.
- `direct_provider_calls=false`
- `live_mcp_writes=false`
- `model_downloads=false`
- `production_deploy=false`
- `production_rollout_claimed=false`
- `secret_output=false`

## Owner Walls

- Production OAuth identity and credential configuration.
- Phase-6 scale/capacity proof.
- GHCR publication and release promotion.
- Live MCP/agent writes outside the recorded bounded scope and their required verifier proof.
- Password, CAPTCHA, secret disclosure, or permission expansion.

## Final Audit

- `owner-input-matrix=PASS`
- `hosted-acceptance=PASS`
- Covered cells: `phase_3`, `phase_5`, `phase_6`, `layer_3`, `layer_4`, `layer_5`, `layer_6`
- Autonomous-open items: none
- Report SHA-256:
  `E3429B1A170EF4173D8FFC82B9E2BF565AFDF6B2B55D8BC5E0B8563001530268`
- `MARKET_READY:false`
- Final packet: `master-goal-final.md`

## Foreign Dirty Files: Never Stage, Revert, Or Rewrite

- `CODEX_ZIELVERFOLGUNG_KURZ.md`
- `apps/frontend/next-env.d.ts`
- `.codex/cache/`
- `.codex/environments/`
- `.codex/tmp/`
- `.playwright-cli/`
- all pre-existing untracked goal, handoff, screenshot, Python-environment, agent-api core/test,
  model-registry, and local-helper files unless ownership is independently re-established.

## Non-Negotiable Rules

- No `git add -A`.
- No fake completion or duplicate percentage credit.
- No secret values in output, files, reports, logs, commits, or screenshots.
- No main push, force push, registry publication, production deployment, or release promotion.
- No parallel verifier, Playwright, or Docker-build execution.
- Localhost evidence label: `DEV-ONLY; hosted proof still blocked`.
- Keep working on autonomous items; stop only at a real Owner gate.

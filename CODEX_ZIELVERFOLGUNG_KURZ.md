# 🎯 ZIEL-VERFOLGUNG (KURZ) — Stand 2026-07-31 — HEAD WIEDER GRÜN
# In JEDER Session: (1) diese Datei → (2) CODEX_UEBERGABE_2026-07-27-SESSION12.md → (3) arbeiten.

## 🔴 ZUERST LESEN — `0a982c2a` WAR ROT, IST REPARIERT (2026-07-31)
Codex hat `53e4d242` + `0a982c2a` gepusht, **ohne danach `npm run verify` zu fahren** — obwohl `0a982c2a`
`verify-phase1.ps1` anfasste. Zwei Regressionen aus `53e4d242`, beide behoben:
1. **Verifier-Widerspruch:** `verify-market-ready.ps1` verlangte `product_acceptance_hosted_proof=true` +
   `workspace_22_page_hosted_proof=true`, `verify-phase1.ps1` verlangte für dieselben Felder `false`.
   Der Verbots-Guard ist jetzt **evidenzgebunden** (Artefakt + SHA-256 + Commit-Ancestry + Deployment-ID).
   **Negativtest:** 1 verändertes Hex-Zeichen → Ablehnung. Strenger als vorher, nicht lockerer.
2. **Gelöschter Marker:** `53e4d242` entfernte den von `verify-retired-hosted-boundary.ps1` gepinnten Satz
   aus `AI_HANDOFF.md`. Wiederhergestellt (er ist weiterhin wahr).
3. **Kein Repo-Bug, aber wichtig:** Die LLM-Evidenzkette vergleicht zwei **untracked** Artefakte, die
   auseinandergelaufen waren (D1 neu geseedet 30.07., Browser-Artefakt vom 25.07.). Resynchronisiert über
   `.codex/tmp/stateful-browser-sync.ps1`; `new_provider_calls=0` → kein Prozent-Credit.
   ⚠️ **Folge: `npm run verify` kann auf einem frischen Clone nie grün werden.**
**Ergebnis: `verify-phase1` PASS (Exit 0), Gitleaks 0/3737.** Regel daraus: **nach jedem Commit, der einen
Verifier anfasst, den Gesamtlauf fahren — nicht nur den Fokustest.**

## ✅ EXTERNES GATE GESCHLOSSEN — NUR NOCH **EINS** OFFEN (2026-07-31)
`missing_or_failed_gates = ghcr_image_digest_verify` — von zwei auf eins.
Ursache war nicht fehlender Schutz, sondern eine Probe **ohne Branch**: `$Branch` hatte Fallback `""`.
`Resolve-DefaultBranchName()` löst den echten Default-Branch jetzt anonym auf (tokenfrei, fail-closed).
Kopplung im selben Slice mitgezogen: `verify-phase1.ps1` (an `branch_protection_claim_allowed` gebunden,
beidseitig fail-closed), `verify-market-ready.ps1` (2 Stellen), `owner-input-manifest.json`.
`verify-go-live-readiness.ps1` war bereits konditional.
⚠️ **Betriebs-Falle:** Jeder `verify-external-gates`-Lauf erzeugt ein neues Artefakt in
`.phase1-artifacts/`; `PROJECT_STATE.md`, `AI_HANDOFF.md` **und** `docs/verification-register.md` müssen
im selben Slice auf das neueste zeigen — sonst rot.
**`MARKET_READY` bleibt korrekt `false`** (GHCR offen, Manifest 86 %) — das ist kein Fehler, sondern ehrlich.

## ✅ BRANCH PROTECTION — CODEX' OFFENE GATE-FRAGE IST BEANTWORTET: **NICHTS ANWENDEN**
Zwei Illusionsschichten: (1) Das Skript hatte **keinen Apply-Codepfad** (Codex korrekt gefixt).
(2) Darunter: `DEFAULT_BRANCH_NAME = "main"` — **`main` existiert in diesem Repo nicht.**
Default-Branch ist **`chore/repo-bootstrap`** — und der ist **bereits korrekt geschützt**:
`status: verified`, **0 Abweichungen**, Force-Push aus, Löschen aus, 1 Review, Exit 0. **Kein Write nötig.**
Skript gehärtet: `resolve_target_branch()` + `assert_branch_exists()` + 2 Offline-Selbsttests.
⚠️ „**`main` niemals**" bleibt als Regel richtig, meint faktisch aber `chore/repo-bootstrap`.

## 🔑 CF-TOKEN — PROMOTION HAT STATTGEFUNDEN, O5-SCOPE IST FREI
Aktiv **und** Kandidat: `workers/d1/queues/durable_object/vectorize` je **200**, `identical: true`.
Das in §4b beschriebene Risiko „aktiver Token schwächer" ist **erledigt**.
`workers_ai` 403 = **Management-API (Modell-Liste), nicht Inferenz** — die läuft über das Worker-Binding
und ist mit `live_provider_calls=true` belegt. **Nicht verwechseln.**

## 📊 GATES: 4 OFFEN / 6 ZU (gemessen, nicht geschätzt)
offen: `live_llm_provider_calls` · `live_memory_provider` · `hosted_observability_endpoint` ·
`cloudflare_native_zero_card_hosted_runtime`
zu: `live_vector_memory_search` (O5) · `production_auth_identity` (O1) · `live_mcp_writes` +
`live_agent_tool_writes` (O4) · `docker_registry_publish` (O3) · `phase6_scale_runtime` (Zahlung)

## ▶ NÄCHSTER SCHRITT
`scripts/verify-live-vector-memory-search.ps1` **existiert nicht**, wird aber vom Owner-Manifest als
O5-Verifier referenziert → tote Referenz. Da Vectorize jetzt lesbar ist, ist das der erste echte Schritt
für **L6 90 → 100**. **Aber:** Index-Anlage ist Ressourcenerzeugung außerhalb der in
`actions[O2].owner_scope_decision` freigegebenen Liste (Workers, D1, DO, Queues) → **erst Owner fragen.**

## ✅ STAND — aktueller Feature-Branch
Branch `claude/cloud-superbrain-analysis-127d2e` · Overall **86 %** · `MARKET_READY:false`
`P0 100·P1 100·P2 100·P3 44·P4 100·P5 68·P6 90` — `FE 100·ORC 100·AP 69·LLM 55·MCP 56·MEM 90·OBS 100`
RC10 aus `2ae4c61a`; Rollback RC9 @ `0cbe644c`; GHCR unveröffentlicht.
Projekt-Integrität: **833/833 versionierte Dateien, `git fsck` sauber.**

## ✅ FÜNF COMMITS SEIT SESSION 11 — ALLE GEPUSHT
`0d0ff548` Token-Skript gehärtet (4 High-Risiken, 16/16 Tests) · `d726ddc1` Agent-Research an sichere Quellen
gebunden · `e4271e76` Vier-Rollen-Analyse (23/23) · `6750ed70` `/organism/map` auf echten Topologie-Vertrag
(245 Knoten / 495 Kanten, Chromium 4/4) · **`23c11c21` `/technology` an Runtime-Verträge gebunden**.

**`/technology` war Codex' abgebrochener Slice** — geprüft, fertiggestellt, Truth nachgezogen, gesichert:
statischer + **Laufzeit**-Verifier ✅ (`current_live_proof=true`, 8 Provider / 7 Layer) · Build exit 0 ·
**Chromium 6/6** inkl. 5 Fail-closed-Beweisen · TS 0 · ESLint 0 · `verify-phase1` PASS · **Gitleaks 0/3726**.
Sicherheitskern: nginx löscht eingehenden `X-Superbrain-Source`, versteckt Upstream-Werte und stempelt
`agent-api-boundary` — **Live-Grün ist nicht fälschbar, auch nicht durch die UI selbst.**

## 22-SEITEN-AUDIT
**9 ECHT NUTZBAR · 11 NUR CONTRACT · 2 STUB/MOCK · 0 FEHLT/BROKEN** (`/technology` STUB → NUR CONTRACT)

## ✅ P1 — AKTUELLE 22-SEITEN-ABNAHME GRÜN (2026-07-30)
**22/22 Routen · 29/29 aktivierte Familien · 161/161 aktivierte Aktionen · 0 tote · 0 unregistrierte ·
0 Click-only/Non-direct · 0 unerwartete Console-Fehler · 0 Page-Fehler.** Zwei erlaubte Provider-Builds waren
live; zwei erwartete 403 gehörten exakt zu den gegateten Games-/Apps-DELETEs.

Die Registry enthält **31 Familien / 173 Mitglieder / 161 enabled**. Die frühere Rechnung `198/187` war falsch:
Die dedizierte `/organism/map`-Topologie besitzt 7 statt der früher wiederverwendeten 33 Phase-6-Controls;
`/technology` besitzt 4 Mitglieder, davon 3 enabled und 1 conditional. Die 162 datengetriebenen Knoten- und
Adjazenzbuttons teilen einen **explizit registrierten** Auswahlhandler; keine stille Ausnahme.

Der einmalige 503 war ein transienter Read des bereits persistierten P0-Builds. Der idempotente öffentliche
Build-Read versucht deshalb exakt zweimal je 15 Sekunden innerhalb des alten 30-Sekunden-Budgets.
**Keine 503-Whitelist-Erweiterung.** Zusätzlich grün: fokussierter Map-Chromium-Test, 40/40 Build-Reads,
TypeScript, ESLint, Next-Build 21/21, `verify-phase1`, npm audit 0 und Gitleaks 0/3730.
Report-SHA-256 `399F310FBDA0D4D584C6847F6462D1B1CF4895037FAB9FAFF90D123E7C183F6F`.
DEV-ONLY; hosted proof still blocked. Kein Prozentcredit.

## ✅ O2Core — HOSTED ZERO-CARD-RUNTIME GRÜN (2026-07-30)
Worker `https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev` ist source-gebunden an
`826a78b29a4dbf82a7115ecdd5562b238ade3594` / Archiv
`f3d86b36883d743713c1c7e86477776dc575b87b9e941af849dfd2c4f94e325b`.
Echter Hosted-Verifier: D1 W/R/D, Queue, SQLite-DO, LangGraph, Build-/Workspace-Persistenz sowie Auth-/Secret-/
Oversize-/Replay-/Konfliktpfade grün; R2 ungebunden, kein Paid-Fallback. Report-SHA-256
`FEEE5D40E14E547C9B8EB5903B993E61BC324E2C2CAD64ECF8C7DF3BA9049D0B`.
Gate verifier-geöffnet; Management-Token nach Evidenzbindung atomar auf den qualifizierten Kandidaten umgestellt.
Kanonischer externer Audit: Hosted Staging, Vercel-Origins, Gitleaks und O2Core grün; nur Branch Protection und
GHCR-Digests offen. `production_deploy_claim_allowed=false`. Vercel-Preview-Laufzeitwerte sind gesetzt; neuer
Preview-Build sowie Produkt-/22-Seiten-Hosted-Beweis folgen. Kein Prozentcredit.

## 🟢 DURCHBRUCH: CF-TOKEN 5/6 — O2Core UND O5 SIND OFFEN (2026-07-27)
Owner hat einen Token mit korrekten Permissions geliefert. Er lag zunächst als 68-Zeichen-Zeile vor
(**Tokenwert + Token-Name in derselben Zeile** → `err=6003`). Nach Extraktion des reinen 53-Zeichen-Werts:
**Workers Scripts · D1 · Queues · Durable Objects · Vectorize alle HTTP 200.**
Einzig **R2: 403 `err=10042`** — **kein Permission-Fehler** (das wäre `10000`), sondern „R2 nicht aktiviert".

**⛔ ARCHITEKTURENTSCHEID: R2 IST RAUS — wie Fly.io.** Cloudflare verlangt für die R2-Aktivierung eine
**hinterlegte Zahlungsmethode, auch für den Gratis-Tarif** (Community-Berichte über 5 USD bei Aktivierung).
Das verletzt die Free-Only-Wand. **Owner hat entschieden: nicht aktivieren. Final, nicht erneut vorschlagen.**
→ **Artefakte in D1, Session/Koordination in Durable Objects** — beide offen und kartenfrei.
→ **Verbindliches Profil: `O2Core` (+ `O5`).** `-Profile Full` / `O2WithR2` sind bauartbedingt unerreichbar und
**kein Zielzustand mehr**. R2 im Code wie Fly als `historical_only` führen. **`5/6` IST der Zielzustand.**

**Persistiert und aktiviert:** `-Profile O2Core` → **4/4 PASS**, `-Profile O5` → **1/1 PASS**.
Der source-gebundene Hosted-Write/Read/Delete-Verifier qualifizierte den Kandidaten; das fail-closed
Promotionsskript ersetzte danach atomar nur `CLOUDFLARE_API_TOKEN` und legte einen Rollback an.
🧹 Defekte 68-Zeichen-Zeile aus der kanonischen Datei entfernt (hätte alle Dienste mit `6003` scheitern lassen).
⚠️ Owner hat „Roll" **ausdrücklich abgelehnt** — nicht erneut vorschlagen.

## ⛔ TOKEN-ERSTELLUNG IST OWNER-ONLY — CODEX DARF ES NICHT VERSUCHEN
`POST /user/tokens` braucht `User·API Tokens·Edit` → bei 0/6 kein Bootstrap · Dashboard = Passwort/2FA (R0-Wand) ·
eine unerfüllbare Pflichtaufgabe erzwingt Fake-Done. Schnittstelle: `scripts/owner-set-cloudflare-token.ps1`
(fail-closed, `-FromClipboard`, schreibt nur bei 6/6, `-ProbeOnly` = nur prüfen).
Codes: `6003` = kein reiner Token · `1000`/`9106` = ungültig · `10000` = **Permission fehlt**.

## ▶ SOFORT-SCHLEIFE
**P1 — ✅ O2Core Hosted-Beweis und Token-Promotion sichern/pushen; Vercel-Preview neu bauen.**
**P2 — `verify-product-acceptance.ps1` gegen die neue gehostete Preview → `hosted_proof:true`.**
**P3 — Hosted 22-Seiten-Lauf → 22/22, 0 tote/unregistrierte/Non-direct/Click-only.**
**P4 — O5/MEM** Vectorize hosted → 90→100.
**P5 — Top-10-Lücken** aus `vision-vs-reality`; danach Manifest/Gates/RC/`verify:market-ready`.

## 🔴 WORKBENCH BRAUCHT VIER SCHALTER — NACH JEDEM CONTAINER-NEUAUFBAU WEG
Owner-Meldung „Workbench funktioniert nicht" war **kein Codefehler**, sondern vier fail-closed Standards:
1. `LLM_GATEWAY_MODE=cloudflare_workers_ai_live` (gateway) — sonst `chatcmpl-dryrun-…`
2. `PRODUCT_ACCEPTANCE_LIVE_PROVIDER_APPROVED=true` (**frontend**) — steuert `live_provider_calls_allowed` pro Request
3. `WORKBENCH_LLM_MODEL=@cf/qwen/qwen2.5-coder-32b-instruct` — ⚠️ Compose-Standard ist **`gemma-3-1b-it`**
   (lokales llama.cpp, **nicht** auf der Workers-AI-Allowlist) → Gateway `400` → Build `503`
4. `AGENT_API_AUTH_TOKEN` identisch in frontend **und** agent-api — leer ⇒ jeder Build-Write abgelehnt
   (`503 build_persistence_unavailable`, obwohl die Generierung erfolgreich war)

**➡️ Immer so starten:** `pwsh -NoProfile -File scripts\start-dev-live.ps1` (setzt alle vier, erzeugt den
Service-Token einmalig, liest die effektiven Werte aus den Containern zurück; `-DryRun` = sicherer Trockenmodus).
**Beweis:** P0 PASS, Build `cba73a86…`, `provider=cloudflare-workers-ai`, `live_provider_calls=true`.

## ✅ `session_missing` = NICHT EINGELOGGT (endgültig)
Direktaufruf ohne Session liefert lokal `401 write_session_required / session_missing`. Kein Bug, keine fehlende
Runtime — das war auch die Ursache der Vercel-Meldung. **Nie wieder als Backend-Defekt behandeln.**

## ⚠️ NEUE LEHRE: VOLLES LAUFWERK TARNT SICH ALS CODE-FEHLER
`D:` auf 0,41 GB → `verify-phase1` brach mit `organism topology static surface` ab. Sah aus wie eine Regression in
`6750ed70`, **war reiner Speichermangel** — nach Freigabe fehlerfrei. **Erst `Get-PSDrive D` prüfen, dann Code
verdächtigen.** Ursache: Windows-Backup (~37 GB) unter `D:\NEWPC`, vom Owner entfernt. Jetzt **37 GB frei**.

## 🔑 SECRETS-DATEI: BEREINIGT + VOLLSTÄNDIG VALIDIERT (2026-07-30)
Der Owner hat nur ergänzt, nie gelöscht → **zwei tote Duplikate**, bei denen Parser (letzter Wert gewinnt)
jeweils den **ungültigen** erwischt hätten. Beide entfernt, Backup `*.bak-dedup-20260730-180631`:
- `GITHUB_TOKEN` Zeile 15 (`ghp_…`, **HTTP 401 abgelaufen**) entfernt — gültig bleibt Zeile 2
  (`github_pat_…`, **HTTP 200**, `admin=true push=true pull=true` auf dem Repo → **O4-tauglich**)
- `CLOUDFLARE_API_TOKEN` Zeile 11 (0/2 lesbar) entfernt — gültig bleibt Zeile 9

**Live-Validierung nach Bereinigung:** `GITHUB_TOKEN` 200 (`strazzusochr`) · `VERCEL_TOKEN` 200 ·
`GITHUB_REPOSITORY` korrekt · Branch-Protection-API 404 (= noch nicht gesetzt, erwartet) ·
O1-Konfiguration **4/4** · **keine Duplikate mehr**, keine Leerzeichen-/Quote-Fehler in kritischen Werten.

### ✅ CF-TOKEN-PROMOTION NACH ECHTEM HOSTED-BEWEIS
Der frühere Kandidat ist nach dem source-gebundenen Hosted W/R/D-Beweis der aktive Management-Token.
O2Core und Vectorize-Read wurden nach der atomaren Promotion erneut geprüft. Rollback liegt nur im privaten
Secrets-Verzeichnis. Keine Tokenwerte in Repo, Report oder Ausgabe; R2 bleibt absichtlich aus.

## ✅ O1 KONFIGURATION ERLEDIGT (2026-07-27) — der Blocker war ein Compose-Defekt
Lokaler Auth-Vertrag jetzt: `github_oauth_configured: true` · `jwt_signing_configured: true` ·
`credential_issuance_ready: true` · `missing_configuration: []` · `mode: verified_identity_fail_closed`
(vorher `local_contract_with_dry_run_oauth`). `verify-phase3-auth-fail-closed.ps1` **PASS**,
`status=verified_dev_only`, `credentials_issued=false`, `live_github_oauth_call=false`.

**Der eigentliche Blocker war nicht die Owner-Eingabe.** `docker-compose.dev.yml` hat
`GITHUB_OAUTH_CLIENT_ID/_SECRET/_REDIRECT_URI` **nie an die agent-api durchgereicht** — Auth blieb also
fail-closed, egal was in der Secrets-Datei oder bei Vercel stand. Behoben in `99bc9c3e`.
**Vierte, nirgends dokumentierte Voraussetzung: `JWT_SIGNING_SECRET`** — ohne ihn bleibt
`credential_issuance_ready` false trotz gültiger OAuth-Daten. `start-dev-live.ps1` erzeugt ihn einmalig.

⚠️ **Wichtig für Codex:** Auf **Vercel** wird `github_oauth_configured` **nie** `true` — dort läuft keine
agent-api; die Seite liefert eine statische Projektion mit hart kodiertem `false`
(`apps/frontend/lib/endpointDefaults.ts:29`). Die drei Variablen sind dort korrekt gesetzt (vom Assistenten
direkt am Projekt `frontend` verankert, `production,preview`, Redeploy `dpl_5uLu9a2B…` READY), aber **inert,
bis der hosted CF-Runtime steht (O2′)**. Das Gate `production_auth_identity` braucht danach noch den
**hosted** OAuth-Austausch — die lokale Evidenz ist `verified_dev_only`, kein Hosted-Proof.

## ✅ ZERO-CARD-PFLICHT AUS DER OWNER-MATRIX ERLEDIGT
ADR-010 und `cloudflare-native-runtime-candidate-v2` verwenden jetzt den echten
`cloudflare-d1-bounded-text`-Adapter: maximal `32768` Bytes UTF-8 in D1, Queue/SQLite-DO nur zur Koordination,
kein Rohinhalt in Queue, DO, Antwort oder Audit. R2 ist ungebunden und ausschließlich `historical_only`;
kein Spillover. Migration `0003_zero_card_d1_artifacts.sql`, `17/17` Unit-Tests, statischer Verifier und echter
lokaler Wrangler-Roundtrip sind grün. Report
`.codex/runs/CURRENT/master-goal/t3/cloudflare-d1-local-v2/report.json`, SHA-256
`CB108383C338E41C47440FA2618009DC174053E08E6401CAD7255AD333A65F43`.
Dieser lokale Report bleibt historische DEV-Evidenz; aktueller Hosted-State:
`docs/runtime-state/cloudflare-native-hosted-current.json`. Kein Prozentcredit.

## ✅ O5 IST ERLEDIGT
Die Matrix fordert für O5 nur „Extend the Cloudflare token with Vectorize Edit". Der gelieferte Token liest
Vectorize (HTTP 200), `-Profile O5` **1/1 PASS**. **Der Owner-Teil von O5 entfällt.** Rest ist Codex-Arbeit
(Index anlegen, Embedding, Roundtrip, hosted Semantic-Search-Beweis) — `live_verified` nie handsetzen.

## 🧾 OWNER-TODO (alles gratis, keine Kreditkarte)
> **📖 Vollständige Klick-für-Klick-Anleitung: [`docs/runbooks/OWNER_SCHRITT_FUER_SCHRITT_2026-07-27.md`](docs/runbooks/OWNER_SCHRITT_FUER_SCHRITT_2026-07-27.md)**
> Enthält exakte Feldwerte, Variablennamen, Berechtigungsstufen und die Reihenfolge.
> **O3 erst nach `MARKET_READY: true`** — die Matrix verbietet frühere Registry-Veröffentlichung.
| # | Was du tust | schaltet frei |
|---|---|---|
| ~~O2′ Runtime~~ | ✅ **HOSTED VERIFIZIERT** — O2Core W/R/D + Source-Parität; Scale-Gate separat offen | Produkt-Hosted-Pfad |
| ~~O5~~ | ✅ **ERLEDIGT** — Vectorize 1/1 | MEM-Weg offen |
| ~~O6~~ | ✅ `resolved_verified` | — |
| ~~R2~~ | ⛔ **GESTRICHEN** — Kreditkarte nötig, verletzt Free-Only. Artefakte → D1/DO. | — |
| ~~O1~~ | ✅ **KONFIGURATION ERLEDIGT** — 4/4 lokal verifiziert, Vercel-Variablen am Projekt verankert. Hosted-OAuth-Beweis folgt mit O2′. | P3 nach hosted Proof |
| ~~O4 (Owner-Teil)~~ | ✅ **ERLEDIGT 2026-07-30.** Token gültig (`github_pat_…`, HTTP 200, `admin/push/pull=true`) · Freigaben vom Owner erteilt (*„ja, so"*) und in `owner-input-manifest.json` → `actions[O4].owner_scope_decision` gespiegelt. **Rest ist Codex-Arbeit.** | **AP/MCP↑** |
| **2 · O3** ⚠️ | **erst nach `MARKET_READY: true`** — `write:packages` → `GHCR_TOKEN`, Paket auf **Public** (dann gratis), Release-Freigabe im Chat | **P5↑** |

## ⛔ REGELN
No-Fake-Done/Live · `live_verified` nie handsetzen · **Free-Only: kein Fly, keine Karte, keine CF-Containers,
kein Docker-Abo** · Localhost/Preview = **DEV-ONLY** · Manifest = einzige %-Wahrheit · Push nur
`claude/cloud-superbrain-analysis-127d2e` (kein main/force) · kein GHCR/Promotion ohne O3 · kein paralleler
verify/Playwright/Docker-Build · Preflight `git log -1` ≥ `23c11c21` + `$env:TEMP/$env:TMP='D:\_sb_tmp'` +
**≥10 GB frei auf D:** · 33 fremde untracked Dateien tabu, **NIE `git add -A`**.
**Contract-Beweis ≠ Produkt-Beweis.** · **Nie 1–2-Zeichen-Funktionsnamen in Secret-Skripten.**

## 🏁 FERTIG heißt
`MARKET_READY: true` **UND** `verify-product-acceptance` mit **`hosted_proof: true`** (echtes spielbares 3D-Game
aus echtem Prompt, in der Cloud, persistiert) **UND** hosted 22-Seiten-Matrix ohne tote Aktionen.
**Lokale 22-Seiten-Abnahme und D1-Adapter sind grün. Offen: echte Hosted-Beweise.**

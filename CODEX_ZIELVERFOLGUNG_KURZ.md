# 🎯 ZIEL-VERFOLGUNG (KURZ) — Stand 2026-08-04 · RC13

> **Dies ist die EINZIGE Arbeitsdatei.** Aufbau: Ziel → Owner-Entscheidung → Start → Befunde →
> Wände → Reihenfolge → Regeln → **Anweisungen für Codex** → **Referenz** (Details, Test-Inventar,
> Owner-Klickfolgen).
> **Zweites und letztes Dokument:** `REGELN_OPTIK_UND_FERTIG.md` — das Regelwerk mit den Belegen.
> Alle `CODEX_UEBERGABE_*.md` sind **Historie**.

## ENDZIEL

`npm run verify:market-ready` druckt real **`MARKET_READY: true`**.
Beide Matrizen 100 %, jede Zelle mit echtem Artefakt.
Owner-gewallte Reste ehrlich als **OWNER-BLOCKED** listen — **nie faken (R0)**.

---

## 🔴 OWNER-ENTSCHEIDUNG — gilt ab sofort

> **Organismus-Optik kommt GANZ ANS ENDE.** Alles andere ist wichtiger.
> Kein Agent arbeitet am Aussehen von `CortexCanvas3D`, bis Funktion und Ketten stehen.

---

## 🚀 START HIER — RC13 `db631ab3` · CI `30815984573` grün

```
[phase5-credit] verified mode=fully_itemized computed=89 credited=89 verified=17/19 blocked=I1,I5
```
Overall **89** · P3 44 · P5 89 · P6 90 · L4 55 · L5 56 · Gates **7/10 zu** · `MARKET_READY:false`

**Preflight:**
```powershell
Set-Location 'D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM'
$env:TEMP='D:\_sb_tmp'; $env:TMP='D:\_sb_tmp'
$env:PSModulePath='C:\Program Files\WindowsPowerShell\Modules;C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules'
git status --porcelain | Select-String '^ D'   # MUSS leer sein
(Get-PSDrive D).Free/1GB                       # vor Image-Builds
docker ps                                      # Daemon lebt?
```

---

## ⚠️ ZWEI NEUE BEFUNDE AUS DIESER SESSION

**1. Ein geschlossenes Gate war gebrochen — behoben.**
`.phase1-artifacts/live-vector-memory-search-proof.json` war beim 30-GB-Aufräumen gelöscht worden.
`verify-vector-memory-gate.ps1` schlug fehl: *„an opened vector gate is backed by an existing
evidence artifact"*. Per `git restore` wiederhergestellt, Gate wieder grün.
**Regel:** Aufräumen fasst `.phase1-artifacts/` und `docs/release-artifacts/` **nie** an.

**2. Das 5-Achsen-Audit ist teilweise fest verdrahtet.**
`verify-five-axis-substance-audit.mjs:295` ist ein **Literal**:
`console.log("… inspector=true replay=true neuroglass_tokens=12 organism_visual_v2=verified")`.
Ebenso `actions=161`, `docs_endpoint_mentions=98`, `strict_unfinished=0`, `dead_scaffolds=0`.
Zusätzlich prüft es, ob ein Markdown-Dokument Sätze enthält, die derselbe Commit hineinschrieb.
**Meine frühere Aussage „die fünf Achsen sind gemessen" ist damit falsch** — nur Layer-Prozente
und Routen-Klassifikation werden berechnet.

---

## ⛔ DIE VIER OWNER-WÄNDE

| Wand | öffnet | Art |
|---|---|---|
| **Worker-Deploy** auf `db631ab3` | `npm run verify` | Live-Fläche, keine Zahlung |
| **O1** OAuth | P3 +56 | zuerst Architekturentscheidung; Scope nur `read:user` |
| **`AGENT_API_AUTH_TOKEN`** | P6 +10 | ein Secret, keine Zahlung |
| **O3** GHCR | P5 +11 | zyklisch — Owner muss den Zyklus brechen |

**Zahlung öffnet nichts.**

---

## ✅ AUTONOM — in dieser Reihenfolge

```
1. Docker stabil bekommen  ->  npm run verify · verify:runtime · verify:browser
   (in dieser Session NICHT gelaufen: Daemon stuerzte beim Stack-Start ab)
2. L4 Responses-SSE fertig (Codex' laufender Slice, 16 dirty Dateien - nicht anfassen)
3. L5 Adapter aus contract/dry-run holen
4. Rubrik fuer L4/L5 vom Owner freigeben lassen  ->  erst DANN Prozente
5. RC14 binden
6. GANZ ZULETZT: Organismus-Optik
```

---

## 🔒 ZEHN REGELN, DIE JEDEN LAUF ENTSCHEIDEN

1. **Kein Commit benotet sich selbst** (R-SELF-1) — Prüfung vor Umsetzung, getrennter Commit, einmal rot.
2. **Quelltext-Textsuche ist keine Prüfung** (R-SELF-2) — `includes("function DotGlobe")` misst nichts.
3. **Optik-Behauptung nur mit Screenshot gegen benannte Referenz** (R-VIS-1/2).
4. **O4 zuletzt** vor den Ketten — jeder Commit danach macht den Beweis stale.
5. **`start-dev-live.ps1` NACH `verify:runtime`, VOR `verify:browser`** — sonst
   `deterministic_dry_run` und ein 129-Zeichen-Stub. Modus prüfen, nicht der Startmeldung trauen.
6. **Evidenz VERBATIM** — Nachbearbeiten bricht die Kreuzreferenz-Hashes.
7. **`gh workflow run` nimmt einen Ref, keinen SHA** — Kontroll-Commit auf den Kandidaten,
   eigener Branch, danach **mergen** (nicht cherry-picken).
8. **Nie `git add -A`**, nie Commit ohne Pathspec.
9. **Nie parallel** Playwright / Docker / Verifier.
10. **Neuem Prüfschritt erst nach einem roten Lauf glauben.**

---

## ⛔ VERBOTEN

Prozente oder `live_verified` von Hand · L4/L5 ohne freigegebene Rubrik hochsetzen ·
Selbstbenotung · Quelltext-Grep als Abnahme · Effekte zählen, die unter Test aus sind ·
`.phase1-artifacts/` oder `docs/release-artifacts/` beim Aufräumen löschen ·
Hosted-Deploy ohne Freigabe · Zahlung/Karte/Paid Provider/Fly.io/R2 ·
Secrets ausgeben (nur Pfad + Fundtyp) · Force-Push · Push auf Default-Branch ·
DEV-ONLY als Hosted-Beweis ausgeben.

**Vier Wände:** Kreditkarte/Zahlung · Passwort-Konten · CAPTCHA · Secrets ausgeben/committen.

---

*RC13 `db631ab3` · CI `30815984573` grün · Overall 89 · Gates 7/10 zu · `MARKET_READY:false`
Details: `CODEX_UEBERGABE_2026-08-04-FINAL.md` · Regeln: `REGELN_OPTIK_UND_FERTIG.md`*

---

# 📋 ANWEISUNGEN FÜR CODEX — Stand 2026-08-04

## 0. ZUERST LESEN: `REGELN_OPTIK_UND_FERTIG.md`

Zwei Regelfamilien sind **neu und bindend**:

- **R-SELF-1: Kein Commit benotet sich selbst.** Prüfung und Umsetzung in getrennte Commits;
  die Prüfung existiert **vorher** und war **einmal rot**.
- **R-SELF-2: Eine Prüfung, die den eigenen Quelltext liest, ist keine Prüfung.**
  `read(datei).includes("function DotGlobe")` misst nichts. Ebenso verboten: DOM-Attribute mit
  fest verdrahteten Werten als Zustandsbeweis, und `console.log("… verified")` als Ergebnis.
- **R-SELF-3: Was unter Test abgeschaltet ist, gilt als unbewiesen** (`navigator.webdriver`,
  CI-Flag, Hardware-Gate).
- **R-VIS-1: Ohne Screenshot gegen eine benannte Referenz ist keine Optik fertig.**

**Warum:** Zwei deiner Prüfungen sind daran gescheitert — `verify-phase6-frontend.mjs`
(sieben Quelltext-Textsuchen, im selben Commit wie die Effekte geschrieben) und
`verify-five-axis-substance-audit.mjs:295` (`console.log` mit fest verdrahtetem
`organism_visual_v2=verified`). **Das war kein Betrug — die Regeln erlaubten es. Jetzt nicht mehr.**
Ich habe denselben Fehler gemacht und per `grep` bestätigt; das steht ebenfalls dort.

---

## 1. 🔴 DEIN NÄCHSTER BLOCKER — RC13 reproduziert heute nicht mehr

`npm run verify` ist **ROT**: `Verification failed: frontend npm audit`.

**Der Code ist unverändert — die Advisory-Datenbank hat sich geändert:**
`brace-expansion` 4.0.0–5.0.8 und `js-yaml` 4.0.0–4.3.0, beide **high**, beide veröffentlicht
**nach** RC13s grünem CI-Lauf (2026-08-03 13:29).

Das bindet an drei Stellen: `pr-check.yml:284` (CI wäre heute rot) ·
`write-phase5-security-evidence.ps1:98` (`Assert-True "npm audit"`) ·
`apps/frontend` in `RUNTIME_SOURCE_PATHS` (Lockfile-Änderung = Kandidaten-Drift).

`npm audit fix` löst es **nicht** — npm verlangt `--force`. **Ich habe es nicht ausgeführt**,
weil es mitten in deinen laufenden L4-Slice fällt.

**Reihenfolge für dich:**
```
1. L4-Slice abschliessen und lokal beweisen
2. npm audit fix --force   (in apps/frontend)
3. npm run build --prefix apps/frontend        <- MUSS gruen sein, Major-Bumps pruefen
4. npx tsc --noEmit -p apps/frontend/tsconfig.json
5. npm run verify:browser                      <- Regression durch Major-Bump ausschliessen
6. erst dann einfrieren -> RC14
```

---

## 2. ⚠️ AUFRÄUMEN HAT EIN GATE GEBROCHEN

Beim 30-GB-Aufräumen wurde `.phase1-artifacts/live-vector-memory-search-proof.json` gelöscht.
Fünf Stellen verlangen sie. `verify-vector-memory-gate.ps1` schlug fehl:
*„an opened vector gate is backed by an existing evidence artifact"* — ein **geschlossenes Gate
war gebrochen**. Ich habe es per `git restore` wiederhergestellt, Gate ist wieder grün.

**Regel:** Aufräumen fasst `.phase1-artifacts/` und `docs/release-artifacts/` **nie** an.
Nach jedem Aufräumen: `git status --porcelain | Select-String '^ D'` — **muss leer sein.**

---

## 3. ✅ WAS NACHWEISLICH FUNKTIONIERT — dein Fundament

Live gemessen, DEV-ONLY, in dieser Session:

```
Login -> POST /api/v1/build -> HTTP 200 in 8,8 s
Modell   : @cf/qwen/qwen2.5-coder-32b-instruct   (echte Cloudflare Workers AI)
Artefakt : 1.202 Zeichen, vollstaendiges <html></html>, interaktiv
persisted: true (postgres) · in /api/v1/builds wiedergefunden
```

Ebenfalls grün: OAuth-Grenze **22/22** · Worker-Tests **24** · Supply-Chain-Pins **PASS** ·
P5-Credit `verified 89, 17/19` · P5-Unit-Tests **21**.

**Die Produktkette steht. Was fehlt, ist L4/L5-Funktion und die Owner-Freigaben.**

---

## 4. DEIN LAUFENDER SLICE — L4 Responses-SSE

16 dirty Dateien: `services/llm-gateway/app/main.py` · `apps/frontend/lib/endpointDefaults.ts` ·
`docs/runtime-contracts/llm-responses-adapter-contract.md` ·
`scripts/verify-llm-responses-contract.ps1` · `infrastructure/nginx/{cloud,dev}.conf` ·
`services/agent-api/app/main.py`.

**Ich habe nichts davon angefasst.** Mach ihn fertig — er ist die richtige Arbeit.

**Beim Abschluss beachten:**
- Der Verifier für Streaming darf **nicht** prüfen, ob der Quelltext `"response.output_text.delta"`
  enthält. Er muss einen **echten SSE-Strom lesen** und die Ereignisfolge zusicheren (R-SELF-2).
- Schreib den Verifier **vor** dem Feature und lass ihn **einmal rot** laufen (R-SELF-1).
- Nichts unter `navigator.webdriver` abschalten, was danach als bewiesen gelten soll (R-SELF-3).

---

## 5. WAS DANACH KOMMT — und was NICHT

**Danach:** L5-Adapter aus contract/dry-run holen (GitHub, PostgreSQL, Filesystem, Playwright, E2B).

**Vorher klären:** Für L4/L5 existiert **keine autoritative Credit-Rubrik**. Ohne Owner-Freigabe
ist jede Prozentbewegung Fake-Grün — zwei Verifier prüfen die Null aktiv.
**Bauen und beweisen zuerst, bewerten später.**

**NICHT jetzt:** Die Organismus-Optik. Der Owner hat sie ausdrücklich **ans Ende** gestellt.
Der Befund bleibt gültig (kein Gehirn, Dot-Globus 21 %-Satellit, Matrix-Rain 9 % Deckkraft,
Shards 6 %, Waveform 2D-SVG) — aber sie wird zuletzt bearbeitet.

---

## 6. UMGEBUNG — zwei Dinge, die dich sonst Stunden kosten

- **Docker Desktop ist in dieser Session mitten im Stack-Start abgestürzt** (`npipe` weg,
  nachdem 4 Container `Healthy` waren). Dasselbe Muster wie Session 14, wo es das ext4-Dateisystem
  im VHD beschädigte. **Vor jedem Image-Build: Platz UND Daemon prüfen.** Bricht er weg, nicht
  blind neu starten — erst `wsl --list --verbose` und Docker-Log.
- **D: hat wieder 30,5 GB frei.** Halte es so; ein voller Datenträger war schon einmal die
  Ursache der Korruption.

---

## 7. UNVERÄNDERT VERBOTEN

Prozente oder `live_verified` von Hand · L4/L5 ohne freigegebene Rubrik hochsetzen ·
Selbstbenotung · Quelltext-Grep oder `console.log` als Abnahme ·
Effekte zählen, die unter Test abgeschaltet sind ·
`.phase1-artifacts/` oder `docs/release-artifacts/` beim Aufräumen löschen ·
`git add -A` · Commit ohne Pathspec · Force-Push · Push auf Default-Branch ·
Hosted-Deploy ohne Owner-Freigabe · Zahlung/Karte/Paid Provider/Fly.io/R2 ·
Secrets ausgeben (**nur Pfad + Fundtyp**) · DEV-ONLY als Hosted-Beweis ausgeben.

**Vier Wände:** Kreditkarte/Zahlung · Passwort-Konten · CAPTCHA · Secrets ausgeben/committen.

---

# 📚 REFERENZ — Details, die man nicht auswendig kennt

## R1 · Vollständiger Ist-Stand

| Gegenstand | Wert |
|---|---|
| Branch | `codex/organism-visual-v2` (Default `chore/repo-bootstrap`, **kein `main`**) |
| **Kandidat RC13** | `db631ab3ffe2254309ae80aadc691b0bba6c372d` |
| Kontroll-Commit | `f5f0a2fac884a443fe3f34ef20272c1fc67991a0` (`rc13-ctl`, gemerged) |
| CI grün am | Run `30815984573`, **2026-08-03 13:29** — siehe Blocker §1 |
| **Rollback-Anker** | RC12 `6261f9f89d803c36b449ba87a4d93e14411b31d0` |
| Overall | **89** · P3 44 · P5 89 · P6 90 · L4 55 · L5 56 |
| Gates | **7/10 zu**; offen: `production_auth_identity`, `docker_registry_publish`, `phase6_scale_runtime` |

**Fremd-dirty, nie mitcommitten:** `.codex/runs/CURRENT/product-acceptance/report.json`
**Entwürfe ausgelagert:** `D:\_sb_tmp\superbrain-drafts-2026-08-02\` — `model-registry`,
`access_classes`, `cost_gate`. Sie brachen Supply-Chain **und** O4. Nicht zurückkopieren.

---

## R2 · Test-Inventar — was welcher Befehl wirklich prüft

**Ohne Docker:**

| Befehl | Prüft |
|---|---|
| `npm run verify` | Gesamtkette Phase 1 — **derzeit ROT**, siehe §1 |
| `python scripts/verify_phase5_credit_itemization.py` | P5-Credit, Evidenz, CI-Bindung, 32 Anker |
| `python -m unittest discover -s scripts/tests -p "test_verify_phase5*"` | 21 Tests |
| `node --test apps/frontend/tests/oauth-boundary-readiness.test.mjs` | 22/22 OAuth-Grenze |
| `pwsh -File scripts/verify-supply-chain-pins.ps1` | 23 Actions / 18 Images / 9 unique / 6 GHCR |
| `pwsh -File scripts/verify-vector-memory-gate.ps1` | Vektor-Gate + Beweis-Artefakt (§2) |
| `pwsh -File scripts/verify-main-deploy-transition.ps1` | Immutable-Candidate-GHCR-Vertrag |
| `npm run verify:phase6-scale:static` | Zero-Request-Preflight, Tamper-Guards |
| `npm run verify:current-release-candidate` | Kandidatenbindung |
| `cd services/cloudflare-stateful-runtime && npm test` | 24 Worker-Tests |

**Mit Docker:** `npm run verify:runtime` (86 Prüfungen) ·
`npm run verify:browser` (Contract → Product-Acceptance → 22 Seiten/161 Aktionen → O4)

**Owner-gated:** `verify-phase6-scale-runtime.ps1 -AllowHostedWrites` ·
`verify-market-ready.ps1 -IncludeExternalGates`

**Existiert NICHT:** Pixelvergleich, Visual-Regression-Baseline.

---

## R3 · Die vier Owner-Wände im Detail

**① Cloudflare-Worker-Deploy** auf `db631ab3` → `npm run verify` läuft durch.
Live-Fläche, **keine Zahlung** (zero-card).
> **Falle:** `wrangler secret put` scheitert mit **CF-10053** — es sind `plain_text`-Vars.
> Richtig: `wrangler deploy --keep-vars --var …`

**② O1 — OAuth-Identität** → P3 +56.
Braucht **zuerst** eine Architekturentscheidung: CF-native stateful **oder** hosted Agent-API mit
PostgreSQL+Redis. Der Vercel-Ursprung ist read-only und kann O1 **nicht** erfüllen.
GitHub → Settings → Developer settings → OAuth Apps → New OAuth App ·
Callback `https://<AUTH_PUBLIC_ORIGIN>/api/v1/auth/callback` · Scope **nur `read:user`**.
Variablen: `GITHUB_OAUTH_CLIENT_ID` · `_CLIENT_SECRET` · `_REDIRECT_URI` · `JWT_SIGNING_SECRET`.
**Abnahme = 10 echte Browserschritte:** Cancel→401 · Scope prüfen · Authorize · Reload ·
Refresh rotiert · Replay→401 · Callback-Replay scheitert · Logout widerruft + Audit.

**③ `AGENT_API_AUTH_TOKEN`** → P6 +10. Ein Secret, keine Zahlung.
Danach exakt **900 echte Requests**: 60@c1 + 240@c10 + 500@c50 Reads, 50 POST mit
serverseitigem D1-Readback, 50 authentifizierte DELETEs.
Schwellen: Erfolg ≥ 0,99 · p95 ≤ 1500 ms · eigene 5xx **exakt 0** · Cleanup vollständig.
Ohne Flag: **null Requests**, `Blocked` = exit 2.

**④ O3 — GHCR** → P5 +11, **zyklisch**: Push verboten vor `MARKET_READY:true`, das aber
GHCR-Digests verlangt. Owner muss den Zyklus brechen.
Settings → Environments → `registry-publication` **und** `production`, je mit Required Reviewer.
Pakete **privat** lassen — public ist irreversibel.

> **Zahlung öffnet nichts.** `payment_required` ist bei O1/O2/O3 `false`; eine im Manifest
> abgebildete Zahlung macht `owner-input-matrix` **rot**.

---

## R4 · Organismus — Befund für später

Vollständig mit Zeilennummern in **`REGELN_OPTIK_UND_FERTIG.md`** (B1–B17). Kurzfassung:
`core.glb` ist eine **Icosphere**, kein Gehirn · die Komponente `Brain` ist eine
Fibonacci-Punktwolke (X × 1.28 → Ellipsoid) · Dot-Globus = 21 %-Satellit ohne Kontinente ·
Matrix-Rain = waagerechte **104 × 9 px**-Striche bei ~9 % Deckkraft, cyan statt grün ·
Shards = 12 Rechtecke bei 6 % · Waveform = 2D-SVG-Polyline · `MeshTransmission` unter
Playwright abgeschaltet · Bloom stammt aus einem älteren Commit.

**Die Substanz ist echt** (Live-State/Events/Replay, Run-State-Filter, Kamera/Licht/Belichtung,
Gameplay, Asset-Policy, Snapshot, Accessibility, Multiplayer-Loopback, Performance, WebGPU).

**Per Owner-Entscheidung: ganz zuletzt.**

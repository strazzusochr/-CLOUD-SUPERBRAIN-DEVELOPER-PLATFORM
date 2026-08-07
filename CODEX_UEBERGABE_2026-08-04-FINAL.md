# 🏁 ÜBERGABE — Stand 2026-08-04 · RC13 · **Optik zurückgestellt, Funktion zuerst**

> **Aktive Übergabe.** Ersetzt `CODEX_UEBERGABE_2026-08-02-FINAL.md`.
> Regelwerk: **`REGELN_OPTIK_UND_FERTIG.md`** (R-VIS-1…8, R-SELF-1…3) — **vor jeder Arbeit lesen.**
> Reihenfolge: (1) `CODEX_ZIELVERFOLGUNG_KURZ.md` → (2) diese Datei → (3) Preflight §4 → (4) arbeiten.

---

## 1. OWNER-ENTSCHEIDUNG, DIE ALLES ORDNET

> **Die Organismus-Optik wird ans Ende gestellt.** Alles andere ist wichtiger.
> Kein Agent arbeitet an `CortexCanvas3D`-Aussehen, bis Funktion und Ketten stehen.

Das ist keine Abwertung des Befunds — die Optik ist nachweislich nicht wie die Referenz
(§7) — sondern eine Reihenfolge-Entscheidung des Owners.

---

## 2. WAS ICH IN DIESER SESSION SELBST GEMESSEN HABE

| | Ergebnis | Wie geprüft |
|---|---|---|
| P5-Credit | `verified · computed=89 · credited=89 · 17/19 · blocked=I1,I5` | `python scripts/verify_phase5_credit_itemization.py` |
| P5-Unit-Tests | **21 Tests gelaufen** | `python -m unittest discover -s scripts/tests` |
| OAuth-Grenze | **22/22 pass, 0 fail** | `node --test apps/frontend/tests/oauth-boundary-readiness.test.mjs` |
| Supply-Chain-Pins | **PASS** (23 Actions / 18 Images / 9 unique / 6 GHCR) | `verify-supply-chain-pins.ps1` |
| Cloudflare-Worker-Tests | **24 Tests** | `cd services/cloudflare-stateful-runtime && npm test` |
| Vektor-Gedächtnis-Gate | war **ROT**, jetzt wieder grün | §3 |
| Freier Platz D: | **30,5 GB** (nach Codex' Aufräumen) | `Get-PSDrive` |

| `npm run verify` | **ROT** — `frontend npm audit` (§3b) | in dieser Session nachgeholt |

**Nicht geprüft — und deshalb hier nicht behauptet:**
`verify:runtime`, `verify:browser`, Workbench-Klickstrecke. **Grund: Docker Desktop ist während
des Stack-Starts abgestürzt** (§5). Die Container erreichten `Healthy`, dann brach der Daemon weg.

---

## 3. ⚠️ REGRESSION GEFUNDEN UND BEHOBEN — gelöschtes Beweis-Artefakt

Nach der 30-GB-Aufräumaktion fehlte `.phase1-artifacts/live-vector-memory-search-proof.json`
(tracked, 3 619 Bytes). Fünf Stellen verlangen sie:
`verify-live-vector-memory-search.ps1` · `verify-market-ready.ps1` · `verify-vector-memory-gate.ps1` ·
`capability-gates.json` · `owner-input-manifest.json`.

**Folge, gemessen:**
```
Vector-memory gate verification failed:
an opened vector gate is backed by an existing evidence artifact
```
Ein **geschlossenes Gate war gebrochen** — es galt als offen, ohne Beweis.

**Behoben** mit `git restore` auf die committete Fassung; danach:
```
[vector-memory] HOSTED-EVIDENCE-BOUND; no new network or provider call
[vector-memory] checks completed
```
Keine weiteren gelöschten tracked Dateien.

> **Regel daraus:** Aufräumen darf `.phase1-artifacts/` und `docs/release-artifacts/` **nie**
> berühren. Nach jedem Aufräumen `git status | grep "^ D"` prüfen.

---

## 3b. 🔴 NEU UND SCHWERWIEGEND — RC13-Evidenz ist heute NICHT mehr reproduzierbar

`npm run verify` bricht ab bei **`Verification failed: frontend npm audit`**.

**Der Code hat sich nicht geaendert — die Advisory-Datenbank hat sich geaendert.**

| | |
|---|---|
| Funde | **2 high**, beide transitiv |
| `brace-expansion` | 4.0.0-5.0.8 — *DoS via unbounded intermediate arrays, bypassing the CVE-2026-14257 mitigation* |
| `js-yaml` | 4.0.0-4.3.0 — *Quadratic CPU consumption in `!!omap` resolution, CVE-2026-59870 nicht backportiert* |
| RC13 CI gruen am | **2026-08-03 13:29** — die Advisories kamen danach |

**Warum das mehr als eine Warnung ist — drei gebundene Stellen:**

1. **CI:** `.github/workflows/pr-check.yml:284` fuehrt `npm audit --audit-level=moderate` aus.
   Ein **erneuter Lauf gegen RC13 waere heute ROT**.
2. **P5-Security-Evidenz:** `scripts/write-phase5-security-evidence.ps1:98` prueft
   `Assert-True "npm audit" ($auditExit -eq 0)`. Die RC13-Security-Kette laesst sich damit
   **nicht mehr neu erzeugen**.
3. **Kandidatenbindung:** `apps/frontend` steht in `RUNTIME_SOURCE_PATHS`
   (`verify_phase5_credit_itemization.py:55`). Jede Aenderung an `package-lock.json` erzeugt
   **Kandidaten-Drift** → RC13 waere ungueltig, es braucht **RC14**.

**Der Fix ist nicht trivial:** `npm audit fix` alleine loest beide **nicht**; npm verlangt
`npm audit fix --force`, also potenziell brechende Major-Bumps.

**Ich habe ihn deshalb NICHT ausgefuehrt.** Gruende: er wuerde mitten in Codex' laufenden
L4-Slice fallen (16 dirty Dateien) und den Build brechen koennen.

**Empfohlenes Vorgehen — gehoert in RC14:**
```
1. Codex' L4-Slice abschliessen
2. npm audit fix --force  in apps/frontend
3. npm run build --prefix apps/frontend   (MUSS gruen sein - Major-Bumps pruefen)
4. npx tsc --noEmit -p apps/frontend/tsconfig.json
5. npm run verify:browser                 (Regression durch Major-Bump ausschliessen)
6. erst dann Quelle einfrieren und RC14 bauen
```

> **Lehre:** Eine gruene CI ist ein **Zeitpunkt-Beweis**, keine Dauerzusage. Zeitabhaengige
> Pruefungen (Advisories, Zertifikate, Token-Ablauf) koennen einen unveraenderten Kandidaten
> nachtraeglich rot machen. Vor jeder Behauptung *"RC ist gruen"* muss der Lauf **erneut**
> erfolgen oder das Datum mitgenannt werden.

---

## 4. ⛔ ZWEITER SELBSTBENOTUNGS-FUND — das 5-Achsen-Audit

`scripts/verify-five-axis-substance-audit.mjs` galt als Beleg dafür, dass die fünf
Substanz-Achsen **gemessen** sind. **Das stimmt nur teilweise.**

**Berechnet** (echt): `classCounts.real/contract/spec`, `layers.get("layer_4").percent`,
`deltaLedger.entries.length`, `productFiles.length`.

**Fest verdrahtet** (Zeilen 291–295) — reine Literale, nichts wird gemessen:
```js
console.log(`[five-axis-audit] actions=161 direct=160 preverified=1 excluded=13 provider_live=2`);
console.log(`[five-axis-audit] docs_endpoint_mentions=98 implemented=96 … unresolved=0`);
console.log(`[five-axis-audit] product_files=… strict_unfinished=0 dead_scaffolds=0`);
console.log("[five-axis-audit] inspector=true replay=true neuroglass_tokens=12 organism_visual_v2=verified");
```
Zusätzlich prüft das Skript, ob **ein Markdown-Dokument bestimmte Sätze enthält**
(`"L4 bleibt 55 %"`, `"10 NUR CONTRACT"` …) — Sätze, die derselbe Commit hineingeschrieben hat.
Das ist zirkulär.

**Korrektur meiner eigenen früheren Aussage:** Ich hatte geschrieben *„die fünf Achsen sind
gemessen"*. Für `inspector`, `replay`, `neuroglass_tokens`, `organism_visual_v2`,
`strict_unfinished`, `dead_scaffolds` und die 161 Aktionen ist das **falsch** — die stehen als
Literale im Skript. Nur die Layer-Prozente und die Routen-Klassifikation sind berechnet.

**Was daraus für L4/L5 bleibt:** Die `LAYER_MATRIX.md`-Aussagen (L4 = `deterministic_dry_run`
als Standard, keine belegte Live-Flotte/Routing/Streaming; L5 = Adapter contract/dry-run) sind
inhaltlich plausibel und decken sich mit den Prozentwerten — aber sie sind **beschrieben, nicht
gemessen**. Wer sie als Messung zitiert, verstößt gegen R-VIS-1.

---

## 5. UMGEBUNG — was diese Session behindert hat

- **Docker Desktop stürzte während `start-dev-live.ps1` ab.** Log zeigt: llm-gateway,
  mcp-gateway, agent-api, frontend `Healthy`, nginx `Started`, dann
  `failed to connect to the docker API at npipe:////./pipe/dockerDesktopLinuxEngine`.
- Das ist **dasselbe Muster wie Session 14** (dort führte es zu ext4-Korruption im VHD und
  erforderte `fsck`).
- **Vor jedem Image-Build/Ketten-Lauf:** freien Platz prüfen **und** Docker-Health prüfen.
  Bricht der Daemon weg, **nicht** blind neu starten — erst `wsl --list --verbose` und
  Docker-Log ansehen (Vorgehen steht in `CODEX_UEBERGABE_2026-08-02-SESSION14.md`).

---

## 6. IST-STAND (unverändert, verifiziert)

| Gegenstand | Wert |
|---|---|
| Branch | `codex/organism-visual-v2` (Default `chore/repo-bootstrap`, **kein `main`**) |
| **Kandidat RC13** | `db631ab3ffe2254309ae80aadc691b0bba6c372d` |
| Kontroll-Commit | `f5f0a2fac884a443fe3f34ef20272c1fc67991a0` (`rc13-ctl`, gemerged) |
| CI grün | Run `30815984573` — alle Steps |
| Overall | **89** · P3 44 · P5 89 · P6 90 · L4 55 · L5 56 |
| Gates | **7/10 zu**; offen: `production_auth_identity`, `docker_registry_publish`, `phase6_scale_runtime` |
| Rollback-Anker | RC12 `6261f9f89d803c36b449ba87a4d93e14411b31d0` |
| Doku-HEAD | `a234a81a` |

**Codex arbeitet gerade an L4** — 16 dirty Dateien: `services/llm-gateway/app/main.py`,
`apps/frontend/lib/endpointDefaults.ts`, `docs/runtime-contracts/llm-responses-adapter-contract.md`,
`scripts/verify-llm-responses-contract.ps1`, `infrastructure/nginx/{cloud,dev}.conf` (SSE-Durchreichung),
`services/agent-api/app/main.py`. **Diesen Slice nicht anfassen und nicht mitcommitten.**

**Fremd-dirty, nie mitcommitten:** `.codex/runs/CURRENT/product-acceptance/report.json`

---

## 7. ORGANISM — der Befund bleibt, die Arbeit wird verschoben

Vollständig belegt in **`REGELN_OPTIK_UND_FERTIG.md`** (B1–B17). Kurz:
kein Gehirn (Icosphere + Ellipsoid-Punktwolke) · Dot-Globus = 21 %-Satellit ohne Kontinente ·
Matrix-Rain = waagerechte 104×9-px-Striche bei ~9 % Deckkraft · Shards 6 % · Waveform = 2D-SVG ·
`MeshTransmission` unter Playwright abgeschaltet · Bloom stammt aus einem älteren Commit.

**Die Substanz ist echt** (Live-State/Events/Replay, Run-State-Filter, Kamera/Licht/Belichtung,
Gameplay, Asset-Policy, Snapshot, Accessibility, Multiplayer-Loopback, Performance, WebGPU).

**Per Owner-Entscheidung: ganz am Ende.** Nicht jetzt.

---

## 8. PREFLIGHT

```powershell
Set-Location 'D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM'
$env:TEMP='D:\_sb_tmp'; $env:TMP='D:\_sb_tmp'
$env:PSModulePath='C:\Program Files\WindowsPowerShell\Modules;C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules'
git status --short --untracked-files=no      # 16 = Codex' L4-Slice, nicht anfassen
git status --porcelain | Select-String '^ D' # MUSS leer sein (siehe §3)
(Get-PSDrive D).Free/1GB                     # vor Image-Builds
docker ps                                    # Daemon lebt?
```

Vor jedem Browser-/Runtime-Beweis:
```powershell
pwsh -NoProfile -File scripts\start-dev-live.ps1
docker exec cloud-superbrain-phase1-dev-llm-gateway-1 sh -c 'echo $LLM_GATEWAY_MODE'
```
Muss `cloudflare_workers_ai_live` sagen.

---

## 9. TEST-INVENTAR

**Ohne Docker (in dieser Session gelaufen):**
`verify_phase5_credit_itemization.py` · P5-Unit-Tests · `oauth-boundary-readiness.test.mjs` 22/22 ·
`verify-supply-chain-pins.ps1` · `verify-vector-memory-gate.ps1` · Worker-Tests 24 ·
`verify:phase6-scale:static` · `verify-main-deploy-transition.ps1` · `verify:current-release-candidate`

**Mit Docker (in dieser Session NICHT gelaufen — Daemon-Absturz):**
`npm run verify` · `npm run verify:runtime` (86 Prüfungen) ·
`npm run verify:browser` (Contract → Product-Acceptance → 22 Seiten/161 Aktionen → O4)

**Owner-gated:** `verify-phase6-scale-runtime.ps1 -AllowHostedWrites` · `verify-market-ready.ps1 -IncludeExternalGates`

**Nicht vorhanden:** Pixelvergleich, Visual-Regression-Baseline (`REGELN…` B6).

---

## 10. DIE VIER OWNER-WÄNDE (unverändert)

| Wand | öffnet | Art |
|---|---|---|
| **Cloudflare-Worker-Deploy** auf `db631ab3` | `npm run verify` läuft durch | Live-Fläche, **keine** Zahlung. Falle: `wrangler secret put` → CF-10053; richtig `deploy --keep-vars --var …` |
| **O1** OAuth-Identität | P3 +56 | zuerst Architekturentscheidung CF-native **oder** hosted PG+Redis. Vercel ist read-only. Scope nur `read:user`. Abnahme = 10 echte Browserschritte |
| **`AGENT_API_AUTH_TOKEN`** | P6 +10 | ein Secret. Danach 900 echte Requests, p95 ≤ 1500 ms, eigene 5xx exakt 0 |
| **O3** GHCR | P5 +11 | zyklisch — Push verboten vor `MARKET_READY:true`, das GHCR-Digests verlangt |

**Zahlung öffnet nichts** — `payment_required` ist überall `false`.

---

## 11. REIHENFOLGE — der eigentliche Plan

```
1.  Docker stabil bekommen, dann die drei ungelaufenen Ketten fahren:
      npm run verify  ->  verify:runtime  ->  start-dev-live  ->  verify:browser
2.  Codex' L4-Slice (Responses-SSE) fertig machen und LOKAL beweisen
3.  L5-Adapter aus contract/dry-run holen
4.  Owner: Worker-Deploy  ->  npm run verify laeuft durch
5.  Owner: AGENT_API_AUTH_TOKEN   ->  P6 100
6.  Owner: Architekturentscheidung + O1  ->  P3 100
7.  Owner: O3-Zyklus brechen  ->  P5 100
8.  L4/L5-Credit-Rubrik vom Owner freigeben lassen  ->  erst DANN Prozente
9.  RC14 binden
10. GANZ ZULETZT: Organismus-Optik gegen die Referenz
```

---

## 12. VERBOTEN

Prozente oder `live_verified` von Hand · L4/L5 ohne freigegebene Rubrik hochsetzen ·
**ein Commit benotet sich selbst** (R-SELF-1) · Quelltext-Textsuche als Abnahme (R-SELF-2) ·
Effekte zählen, die unter Test abgeschaltet sind (R-SELF-3) ·
Optik-Behauptung ohne Screenshot gegen benannte Referenz (R-VIS-1) ·
`.phase1-artifacts/` oder `docs/release-artifacts/` beim Aufräumen löschen (§3) ·
`git add -A` · Commit ohne Pathspec · Force-Push · Push auf Default-Branch ·
Hosted-Deploy ohne Freigabe · Zahlung/Karte/Paid Provider · Secrets ausgeben (nur Pfad + Fundtyp) ·
DEV-ONLY als Hosted-Beweis ausgeben.

**Vier Wände:** Kreditkarte/Zahlung · Passwort-Konten · CAPTCHA · Secrets ausgeben/committen.

---

*Stand 2026-08-04 · RC13 `db631ab3` · CI `30815984573` grün · Overall 89 · Gates 7/10 zu ·
`MARKET_READY:false` · DEV-ONLY; hosted proof still blocked*

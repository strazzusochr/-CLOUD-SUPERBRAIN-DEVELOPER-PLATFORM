# 🎯 ZIEL-VERFOLGUNG (KURZ) — Stand 2026-08-28 · **RC19 faellig**

> **Dies ist die EINZIGE Arbeitsdatei.** Aufbau: Ziel → Owner-Entscheidung → Start → Befunde →
> Wände → Reihenfolge → Regeln → **Anweisungen für Codex** → **Referenz** (Details, Test-Inventar,
> Owner-Klickfolgen).
> **Zweites und letztes Dokument:** `REGELN_OPTIK_UND_FERTIG.md` — das Regelwerk mit den Belegen.
> Alle `CODEX_UEBERGABE_*.md` sind **Historie**.

## ENDZIEL

`npm run verify:market-ready` druckt real **`MARKET_READY: true`**.
Beide Matrizen 100 %, jede Zelle mit echtem Artefakt.
Owner-gewollte Reste ehrlich als **OWNER-BLOCKED** listen — **nie faken (R0)**.

---

## 🔴 OWNER-ENTSCHEIDUNG — gilt weiter

> **Organismus-Optik kommt GANZ ANS ENDE.** Alles andere ist wichtiger.
> Kein Agent arbeitet am Aussehen von `CortexCanvas3D`, bis Funktion und Ketten stehen.

---

## 🚀 START HIER — das Produkt baut jetzt echte 3D-Spiele

**Der Kern des Produkts war kaputt und ist repariert.** Die Workbench erzeugte bisher nur
Spielzeug („Taschenrechner-Niveau"). Ursache war **nicht** das Modell, sondern **drei
gestapelte Deckel**, alle gemessen, keiner geraten:

| # | Deckel | Messung |
|---|---|---|
| 1 | `CF_WORKERS_AI_MAX_TOKENS` **im Container UNSET** → Default **2048** | Die Route bittet um 5200; `min(5200, 2048)` schnitt **~60 %** weg, ohne Fehler, ohne Logzeile |
| 2 | `docker-compose.dev.yml` setzte die Variable **nie** | Der stille Code-Default war der echte Betriebswert |
| 3 | Systemprompt forderte **„~300 lines"** | Er beschrieb die Verstümmelung statt das Produkt |

**Folge, an allen 40 persistierten Artefakten gemessen:** groesstes **6867 Bytes / 191 Zeilen**,
Median **2967 Bytes** — gegen ein Persistenz-Limit von **160 KB**. Ein unvollstaendiges Dokument
wird von der Persistenzgrenze hart abgelehnt, deshalb konnten **nur kleine Apps** je durchkommen.

Zur Einordnung: `@cf/qwen/qwen2.5-coder-32b-instruct` hat laut offizieller Cloudflare-Doku ein
**Kontextfenster von 32 768 Token**. Der Deckel lag bei rund **6 %** dessen, was das Modell kann.

### Was danach sofort auffiel — ein vierter, invertierter Deckel

Sobald der Token-Deckel weg war, antwortete `POST /api/v1/build` mit **HTTP 503
`configured_boundary_unavailable` nach 53,8 s**. Es war **nichts unavailable**: die Route brach
ihren Gateway-Aufruf bei **50 s** ab, während das Gateway noch bis **90 s** auf den Provider
wartete. Der innere Hop durfte laenger leben als der Hop, der auf ihn wartet — ein langsamer
**Erfolg** konnte nur als **falscher Ausfall** erscheinen.

Zeitbudget jetzt monoton nach aussen:
**Provider 90 s < Route 100 s < maxDuration 115 s < nginx 120 s.**

Dass das noetig war, ist belegt: der erfolgreiche Lauf brauchte **61,9 s** und waere unter dem
alten 50-s-Limit erneut als Ausfall gemeldet worden.

### Beweis — echtes 3D, wirklich spielbar (DEV-ONLY)

Live gegen `@cf/qwen/qwen2.5-coder-32b-instruct`, Gateway `cloudflare_workers_ai_live`:

```
build: HTTP 200 in 61,9 s
id    : 5a5fbcce-0e78-4020-8e41-499f8760b708
bytes : 7953   lines: 232      <- groesser als jedes der 40 vorherigen Artefakte
```

| Geprueft | Ergebnis |
|---|---|
| WebGL-Kontext | **WebGL 2.0 (OpenGL ES 3.0 Chromium)**, Canvas 1280×800 |
| Console-/Page-Errors | **0** |
| Renderbeweis | Screenshot: blauer Himmel, grosser gruener Boden, violette Plattformen, roter Spieler **mit geworfenem Schatten**, Muenzen, HUD `Score: 0` |
| Bewegung | Pfeil rechts → Welt verschiebt sich unter **mitlaufender Kamera** |
| Sprung | Leertaste → Spieler loest sich sichtbar **von seinem Schatten** |
| Material | `MeshStandardMaterial` ×5, **`MeshBasicMaterial` 0** |
| Schatten | `castShadow` 5 · `receiveShadow` 4 · `shadowMap` 2 |
| Eingabe | `keydown` **und** `keyup` (echter Tastenzustand, kein Einzelzweig) |

Artefakte: `docs/audit/workbench-3d-game-2026-08-28/` — 3 Screenshots + das generierte HTML.

> **Ehrlich dazu:** Die Optik ist solide beleuchtetes 3D, aber noch **kein „3-Sterne"-Look**.
> Die Kamera steht weit weg, die Formen sind einfach. Das ist der naechste Optik-Schritt —
> und der kommt nach der Owner-Reihenfolge, also **spaeter**.

### ⚠️ Eine Zwischenversion war schlechter — und wird nicht als Fortschritt behauptet

Der erste Versuch, Optik zu fordern, verlangte Tone-Mapping. Ergebnis: **fast schwarze
Silhouetten, Boden komplett verschwunden**. Der Grund ist real und erklaerbar: three.js r155+
nutzt physikalische Lichteinheiten, ACES ueber Default-Intensitaeten rendert dunkel. Der Prompt
fordert jetzt ausdruecklich **helle Intensitaeten** (Directional 2.5–3.5, Ambient/Hemisphere
1.5–2.5), einen **200×200-Boden**, Fog in **Himmelsfarbe** — und sagt: *ein dunkles Rendering
ist ein fehlgeschlagenes Rendering*. Diese Zwischenversion ist verworfen.

---

## 📍 IST-STAND

```
Overall 89   H: P0 100 · P1 100 · P2 100 · P3 44 · P4 100 · P5 89 · P6 90
             V: L1 100 · L2 100 · L3 100 · L4 55 · L5 56 · L6 100 · L7 100
Gates 7/10 zu   offen: production_auth_identity · docker_registry_publish · phase6_scale_runtime
Quellstand c0c57d3d (letzter Commit an Runtime-Source; Docs-Commit liegt darueber)
Branch codex/organism-visual-v2   MARKET_READY:false
```

**Preflight:**
```powershell
Set-Location 'D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM'
$env:TEMP='D:\_sb_tmp'; $env:TMP='D:\_sb_tmp'
git status --porcelain | Select-String '^ D'   # MUSS leer sein
(Get-PSDrive D).Free/1GB                       # vor Image-Builds
docker ps                                      # Daemon lebt?
```

---

## 🔴 DER NAECHSTE BLOCKER — RC18 ist ein unvollstaendiger Stumpf

`docs/release-artifacts/current-release-candidate.json` zeigt auf
`prod-candidate-2026-08-28-local-rc18`. Dieser Kandidat ist **nicht qualifiziert**:

- die RC18-`.md` ist ein **untracked 12-Zeilen-Stumpf** (`qualification_status: in-progress`)
- es gibt **kein** `-evidence/`-Verzeichnis und **keine** `-readiness.json`
- `npm run verify:phase5-credit` stoppt deshalb an
  `C4 evidence #1 anchor is not present in the evidence artifact`

**Das ist Codex' abgebrochener Lauf, kein neuer Defekt** — die Datei war bereits vor dieser
Session dirty. Zusaetzlich liegt jetzt **echter Runtime-Source-Drift** darauf: `apps/frontend`
und `services/` stehen in `RUNTIME_SOURCE_PATHS`, und beide wurden geaendert.

> **Konsequenz: RC18 ist nicht mehr rettbar. Es braucht RC19 auf dem neuen HEAD.**

**CI bestaetigt das** (Run `33187389678` auf dem gepushten Stand): 10 Schritte gruen —
inkl. `Forbid patched-plan drift in compose`, `Backend auth security unit contract` und
`Phase 6 scale fail-closed static contracts` — Abbruch **erst** an
`Phase 5 credit itemization` mit
`active candidate has committed or staged runtime-source drift`.

> **Falle beim Dispatch:** `-f source_prequalification=true` verlangt, dass `candidate_sha`
> sich vom Control-SHA **unterscheidet**. Branch-Tip als beides = sofortiger Abbruch.
> Fuer RC19 zuerst den Kontroll-Commit auf eigenem Branch, dann dispatchen.

---

## ⛔ DIE VIER OWNER-WÄNDE

| Wand | öffnet | Art |
|---|---|---|
| **Worker-Deploy** auf den Kandidaten-SHA | `npm run verify` | Live-Fläche, keine Zahlung |
| **O1** OAuth | P3 +56 | zuerst Architekturentscheidung; Scope nur `read:user` |
| **`AGENT_API_AUTH_TOKEN`** | P6 +10 | ein Secret, keine Zahlung |
| **O3** GHCR | P5 +11 | zyklisch — Owner muss den Zyklus brechen |

**Zahlung öffnet nichts.**

---

## ✅ AUTONOM — in dieser Reihenfolge

```
1. [ERLEDIGT] L4 Responses-SSE                                (Codex, test-first)
2. [ERLEDIGT] L5 Filesystem-Adapter                            (Codex, test-first)
3. [ERLEDIGT] npm-Advisories x3
4. [ERLEDIGT] Runnability-Guard fuer generiertes HTML           (Codex 0cf451d0/bbc2ad48)
5. [ERLEDIGT] R3F-Remount-Race /organism                        (Codex 048ba550)
6. [ERLEDIGT] Generierungs-Deckel + Zeitbudget + 3D-Qualitaet   <- diese Session
7. RC19 BINDEN  <- der naechste Schritt, alles andere haengt daran
     Quelle einfrieren -> 6 Images -> O4 -> runtime -> dev-live -> browser
     -> Evidenz -> Kontroll-Commit auf den Kandidaten -> CI -> P5-Credit
8. Rubrik fuer L4/L5 vom Owner freigeben lassen  ->  erst DANN Prozente
9. GANZ ZULETZT: Organismus-Optik (und der 3-Sterne-Look der generierten Spiele)
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

### R-MEAS-1 · Eine Messung, die still fehlschlagen kann, gilt erst nach dem Gegenbeweis

**Neu aus dieser Session.** Ich habe den Canvas per `createImageBitmap` ausgelesen und
`distinctColours: 1, litSamples: 0` bekommen — also „schwarzes Bild, Spiel kaputt".
**Das war falsch.** WebGL-Canvases liefern ohne `preserveDrawingBuffer: true` nach dem
Compositing schwarz zurueck. Der Playwright-**Screenshot** zeigte eine vollstaendig gerenderte
Szene. Haette ich der Zahl geglaubt, haette ich ein funktionierendes Produkt als kaputt gemeldet.

> **Regel:** Wenn eine Messung „nichts da" sagt, zuerst pruefen, ob die Messmethode ueberhaupt
> etwas sehen **kann**. Bei Optik entscheidet das Bild, nicht der Zahlenwert.

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

# 📋 ANWEISUNGEN FÜR CODEX — Stand 2026-08-28

## 0. ZUERST LESEN: `REGELN_OPTIK_UND_FERTIG.md`

Bindend: **R-SELF-1** (kein Commit benotet sich selbst) · **R-SELF-2** (Quelltextsuche ist keine
Pruefung) · **R-SELF-3** (unter Test abgeschaltet = unbewiesen) · **R-VIS-1** (ohne Screenshot
gegen benannte Referenz ist keine Optik fertig) · **neu R-MEAS-1** (oben).

## 1. 🔴 DEIN NAECHSTER SCHRITT — RC19 binden

RC18 ist tot (unvollstaendiger Stumpf **plus** Runtime-Source-Drift). Nicht reparieren — neu binden:

```
1. Quelle einfrieren auf den aktuellen HEAD
2. 6 Images aus dem committeten git-archive
3. O4 ZULETZT vor den Ketten
4. verify:runtime  ->  start-dev-live.ps1  ->  verify:browser
5. Evidenz VERBATIM einsammeln, Hashes binden
6. Kontroll-Commit auf den Kandidaten, eigener Branch, dann mergen
7. CI dispatchen (Ref, nicht SHA), Attestation zurueckholen
8. verify:phase5-credit gruen fahren
```

## 2. WAS DU NICHT ANFASSEN DARFST

Diese Dateien sind **fremd dirty** und gehoeren nicht dir:

- `.codex/runs/CURRENT/product-acceptance/report.json`
- `.phase1-artifacts/o4-live-writes/{proof,runtime-proof,browser-proof}.json`
- `docs/runtime-state/{capability-gates,external-gate-audit-v2,external-gate-summary,owner-input-manifest}.json`
- `docs/release-artifacts/current-release-candidate.json`
- **gestaged:** `docs/release-artifacts/prod-candidate-2026-08-02-local-rc12.md`

Nie stagen, nie zuruecksetzen, nie `git add -A`.

## 3. ✅ WAS NACHWEISLICH FUNKTIONIERT — dein Fundament

- **Produktkern:** Workbench erzeugt echte, spielbare 3D-WebGL-Spiele (Beweis oben)
- **Runnability-Guard:** `apps/frontend/lib/generatedHtml.ts` lehnt tote `examples/js`-Pfade,
  klassisch geladenes `examples/jsm` und fehlende THREE-Kerne ab; **14 Tests gruen**
- **Generierungsbudget:** 8192 Token, in `docker-compose.dev.yml` deklariert; Zeitbudget monoton
- **Gateway:** 31 Tests gruen · **Build:** 21/21 Seiten · **TypeScript:** sauber
- **Stack:** 10/10 healthy, `cloudflare_workers_ai_live`, Modell auf Allowlist

## 4. WAS DANACH KOMMT — und was NICHT

**Danach:** L4/L5-Rubrik vom Owner, dann erst Prozente.
**NICHT:** Organismus-Optik, und **nicht** der 3-Sterne-Look der generierten Spiele.
Beides ist per Owner-Entscheidung **ganz am Ende**.

---

# 📚 REFERENZ — Details, die man nicht auswendig kennt

## R1 · Vollständiger Ist-Stand

| Gegenstand | Wert |
|---|---|
| Branch | `codex/organism-visual-v2` (Default `chore/repo-bootstrap`, **kein `main`**) |
| Letzter Runtime-Source-Commit | `c0c57d3d` (Docs-Commits liegen darueber) |
| **Kandidat RC18** | `048ba5502a0149a6880abe6acf7325d42c191e08` — **unvollstaendig, verworfen** |
| Rollback-Anker | RC17 `bbc2ad481352e8d9ee1e8e9fc010a5d3407d7b85` |
| Letzte gruene CI | Run `33179887487` (Source-Prequalification auf `048ba550`) |
| Overall | **89** · P3 44 · P5 89 · P6 90 · L4 55 · L5 56 |
| Gates | **7/10 zu**; offen: `production_auth_identity`, `docker_registry_publish`, `phase6_scale_runtime` |

---

## R2 · Test-Inventar — was welcher Befehl wirklich prüft

**Ohne Docker:**

| Befehl | Prüft |
|---|---|
| `npm run verify` | Gesamtkette Phase 1 |
| `npm run verify:phase5-credit` | P5-Credit — **derzeit ROT**: RC18-Evidenz fehlt |
| `npm run build` | 21/21 Seiten — **gruen** |
| `npx tsc --noEmit -p apps/frontend/tsconfig.json` | **gruen** |
| `node --test apps/frontend/tests/generated-html-runnability.test.mjs` | 14/14 Runnability |
| `node --test apps/frontend/tests/oauth-boundary-readiness.test.mjs` | OAuth-Grenze |
| `cd services/llm-gateway && python -m unittest discover -s tests` | **31/31**, inkl. Generierungsbudget |
| `pwsh -File scripts/verify-supply-chain-pins.ps1` | Actions/Images/GHCR-Pins |
| `pwsh -File scripts/verify-vector-memory-gate.ps1` | Vektor-Gate + Beweis-Artefakt |
| `npm run verify:current-release-candidate` | Kandidatenbindung |

**Mit Docker:** `npm run verify:runtime` · `npm run verify:browser`
(Contract → Product-Acceptance → 22 Seiten/161 Aktionen → O4)

**Owner-gated:** `verify-phase6-scale-runtime.ps1 -AllowHostedWrites` ·
`verify-market-ready.ps1 -IncludeExternalGates`

**Existiert NICHT:** Pixelvergleich, Visual-Regression-Baseline.

---

## R3 · Die vier Owner-Wände im Detail

**① Cloudflare-Worker-Deploy** auf den Kandidaten-SHA → `npm run verify` laeuft durch.
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
Matrix-Rain = waagerechte **104 × 9 px**-Striche bei ~9 % Deckkraft · Shards = 12 Rechtecke
bei 6 % · Waveform = 2D-SVG-Polyline · `MeshTransmission` unter Playwright abgeschaltet ·
Bloom stammt aus einem älteren Commit.

**Die Substanz ist echt** (Live-State/Events/Replay, Run-State-Filter, Kamera/Licht/Belichtung,
Gameplay, Asset-Policy, Snapshot, Accessibility, Multiplayer-Loopback, Performance, WebGPU).

Ein echter Defekt wurde inzwischen gefunden und behoben: der **R3F-Remount-Race**
(`connect(null)`) beim Moduswechsel — Commit `048ba550`.

**Per Owner-Entscheidung: ganz zuletzt.**

# 🎯 ZIEL-VERFOLGUNG (KURZ) — Stand 2026-08-28 · **RC20 qualifiziert**

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
Kandidat c29c738b · Control 6f9387c6 · CI 33200830176 · Evidenz 27/27
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

## ✅ RC20-BINDUNG ABGESCHLOSSEN

`prod-candidate-2026-08-28-local-rc20` ist an Quelle
`c29c738b82e4e35cc1288bc603319cba60d167d2` gebunden. Sechs Images, Candidate Runtime,
Runtime, Security, Browser `22/22` und `161/161`, O4 sowie GitHub Actions Run
`33200830176` sind gruen. Die Source-Attestation bindet Control
`6f9387c6d492151b9195e3afcbf5a031b094dd67` als direkten Nachfahren und genau einen
zugelassenen Delta-Pfad. Das Evidenzset enthaelt exakt 27 Dateien.

Der reale Produktbeweis haelt ArrowRight und KeyD jetzt ueber mehrere
`requestAnimationFrame`-Frames gedrueckt und verlangt weiterhin eine messbare sichtbare
Zustands- oder Pixelaenderung. RC19 `5062de35` ist der Rollback-Anker.

`npm run verify:phase5-credit` ist gruen: `17/19 = 89%`, blockiert bleiben nur I1 und I5.
`npm run verify:current-release-candidate` ist gruen, aber `promotion_eligible=false` bleibt
korrekt. DEV-ONLY; hosted proof still blocked.

---

## 🔴 ARBEITSBAUM STEHT MITTEN IN RC21 — `verify:phase5-credit` ist deshalb ROT

Nachgeprueft am 2026-08-28: `docs/release-artifacts/current-release-candidate.json` ist
**uncommitted** auf `prod-candidate-2026-08-28-local-rc21` (Quelle `88fc985a`) gesetzt.
RC21 hat nur eine `.md` — **kein** `-evidence/`, **keine** `-readiness.json`.

```
[phase5-credit] C3 evidence #1 anchor is not present in the evidence artifact
```

Ursache exakt: C3-Evidenz #1 verlangt in genau dieser Datei den Anker
`"active_release_id": "prod-candidate-2026-08-28-local-rc20"`. Der **committete** Stand
(HEAD `88fc985a`) enthaelt ihn; der Arbeitsbaum nicht.

**RC21 ist zwingend, nicht optional.** Ein Zurueckstellen auf RC20 geht nicht mehr:
Codex' Lint-Fix `88fc985a` hat nach der RC20-Qualifizierung
`apps/frontend/components/organism/CortexLive.tsx` geaendert — ein Pfad in
`RUNTIME_SOURCE_PATHS`. Die RC20-Quelle `c29c738b` deckt HEAD damit nicht mehr ab.

> **Kein Defekt** — der Verifier meldet korrekt, dass der Kandidat neu gebunden werden muss.
> `current-release-candidate.json` ist **fremd-dirty**: nicht stagen, nicht zuruecksetzen.

## ⛔ FALLE: `PROJECT_STATE.md` niemals allein nachziehen

`PROJECT_STATE.md` ist veraltet (nennt noch **RC14**, Stand `2026-08-27`), darf aber nicht
einfach aktualisiert werden. Es steht in **beiden** Mengen — `RUNTIME_SOURCE_PATHS` und
`QUALIFICATION_TRUTH_PATHS` — und der Uebergang prueft **exakte Mengengleichheit**
(`verify_phase5_credit_itemization.py:1160`):

```
PROJECT_STATE.md · apps/frontend/lib/endpoint-snapshot.json
apps/frontend/lib/platform.ts · docs/project-progress.manifest.json
```

Ein Einzel-Update ergibt eine 1-elementige Menge -> ungleich -> Kandidatenbindung bricht.
**Also: vor dem naechsten Source-Freeze aktualisieren, oder alle vier gemeinsam.**

---

## 🔎 DREI BEFUNDE AUS DEM ABGEBROCHENEN PRUEF-WORKFLOW — heute nachgemessen

Ein frueherer Workflow starb im Session-Limit (`messen 4/5`, `pruefen 2/12`), aber **6 Agenten
liefen durch**. Ihre Ergebnisse standen nirgends. Ich habe sie geborgen und **jeden Befund am
heutigen HEAD neu gemessen**, statt ihn zu uebernehmen.

### A · LLM-Gateway hat KEINE Aufrufer-Authentifizierung

Zwei unabhaengige Pruefer konnten das nicht widerlegen (`refuted: false`, „if anything
understated"). Heute erneut gemessen:

| Geprueft | Ergebnis |
|---|---|
| `add_middleware` / `Depends(` / `HTTPBearer` / `APIKeyHeader` / `Security(` / `@app.middleware` | **alle 0** in `services/llm-gateway/app/main.py` |
| `infrastructure/nginx/dev.conf:119-131` | `proxy_set_header Authorization ""` **und** `Cookie ""` |
| anonymer `GET /llm/v1/models` (ohne jeden Header) | **HTTP 200**, 148 Modelle, `live_verified: true` |
| Tokenwert im Body | **nein** — kein Secret-Output |

Der Dienst kann eine Aufrufer-Identitaet **prinzipiell nicht lesen**. Ein unauthentifizierter
lokaler Aufrufer loest damit einen **authentifizierten Upstream-Call auf dem Owner-Token** aus.

> **Korrektur am Agenten-Befund:** Er meldete
> `external_provider_calls_disabled_by_default:false`. **Heute ist es `true`**, Modus
> `deterministic_dry_run`, `LLM_LIVE_PROVIDER_DEFAULT=false`. Die Schwere haengt am Gate:
> **Read-Calls** sind immer anonym ausloesbar; **generative Calls** nur, solange DEV-LIVE
> laeuft — dann aber ebenfalls ohne jede Aufrufer-Identitaet.
>
> Scope: `localhost:8081`, DEV-ONLY. Nicht aus dem Internet erreichbar.

### B · Die 161/161-Aktionsmatrix ist **kein** Beweis fuer echte Backend-Calls

`apps/frontend/lib/actionMatrix.ts` hat **kein `endpoint`-Feld** (heute geprueft: FEHLT).
Die Matrix kann deshalb gar nicht die Autoritaet dafuer sein, ob eine Aktion das Backend
erreicht. Der Agent hat die Endpunkte aus den Komponenten hergeleitet und gemessen:

```
161 aktivierte Aktionen  ->  21 (13 %) machen einen Backend-Request
                             28 sind Navigation
                            112 sind reiner lokaler State / Browser-API
```

**`161/161 gruen` heisst also „161 Aktionen loesen einen sichtbaren Effekt aus" — nicht
„161 Aktionen laufen ueber die Layer".** Das ist die ehrliche Lesart (R-VIS-1-Geist).

### C · Kein Layer laeuft ueber die Cloud — die Hosted-Flaechen sind weit zurueck

`infrastructure/nginx/dev.conf:8-11` definiert **alle vier Upstreams als Container-DNS**
(`frontend:3000`, `agent-api:8000`, `mcp-gateway:9000`, `llm-gateway:4000`) — **null hosted
Upstreams**. L1–L7 laufen local-docker-only. Der einzige Ausgang nach draussen ist der
Provider-Call des LLM-Gateways zu Cloudflare Workers AI.

Die Hosted-Flaechen tragen alten Code — heute nachgerechnet, **schlechter als vom Agenten
gemessen**, weil HEAD weitergelaufen ist:

| Flaeche | Quelle | Abstand zu HEAD |
|---|---|---|
| Vercel Frontend | `67f41cec` | **252 Commits** zurueck (Agent mass 229) |
| Vercel Backend Contract Origin | `21913f8c` | **254 Commits** zurueck (Agent mass 231) |

> **Antwort auf „laufen alle Layer ueber die Clouds?" — Nein.** Sie laufen lokal; die
> gehosteten Flaechen zeigen einen mehrere hundert Commits alten Stand.

---

## 🐞 ZWEI PRODUKT-BUGS AUS DEM TIEFEN-CHECK — beide behoben

### 1 · Der Marktplatz zeigte einen **stillgelegten** Provider als „verified" (Fake-Live)

`apps/frontend/app/marketplace/page.tsx` bestimmte den Status-Ton mit
`/verified|live/.test(status)`. Das Inventar meldet Fly.io als
`historical_read_verified` — der Vertrag nennt sie selbst `historical_only`,
„not an active runtime target". Der Teilstring enthaelt aber **„verified"**:

```
/verified|live/.test("historical_read_verified")  ->  true  ->  GRUEN
```

Die stillgelegte Fly.io bekam damit denselben gruenen Punkt und dasselbe gruene Badge wie
die echt laufende Cloudflare-Runtime. **Auf einer Produktflaeche ist das eine Live-Behauptung
ohne Beleg — genau das Fake-Live, das R0 verbietet.**

Behoben: exakte Klassifikation statt Teilstring (`apps/frontend/lib/providerStatus.ts`).
Nur `live_verified` und `verified` sind gruen. Test 4/4, tsc und Lint gruen.

> Das erklaert auch den Widerspruch zwischen den Flaechen: **Marktplatz „4/8 verifiziert"**
> gegen **Vertragsseite „Live verifiziert 3"**. Laufzeit-Wahrheit aus `GET /api/v1/clouds`:
> 8 Provider, `live_verified` **1**, `verified` **2**, `historical_read_verified` **1**,
> `action_required` **2**, `api_error` **1**, `metadata_only` **1**.
> **3 sind aktuell verifiziert — nicht 4.**

### 2 · Der Fuenf-Achsen-Audit war rot (zwei Ursachen)

`PROJECT_STATE.md` nennt die Basis-URL `…/llm/v1`, die der Auditor nicht klassifizieren
konnte (jetzt `NAMESPACE-ONLY`). Dahinter lag ein zweiter Fehler: **meine** Prompt-Zeile
enthielt das Literal `TODO`, was der repo-weite Unfinished-Marker-Guard korrekt bemaengelte.
Beides behoben — Auditor `PASS`, Regression **2/2**.

> **Luecke in der Gate-Kette:** `verify:five-axis-audit` haengt **nicht** in
> `verify.suites.json` oder `verify-phase1.ps1`. Deshalb konnte RC20 gruen werden, obwohl
> dieser Test rot war. Das gehoert in die Kette.

### 3 · Offen und **nicht** von mir behoben: `github_actions = api_error`

`GET /api/v1/clouds` meldet fuer GitHub Actions `status: api_error` bei
`configured: true` (`GITHUB_TOKEN` ist gesetzt). Der Token ist also da, der API-Aufruf
scheitert trotzdem. In derselben Session konnte sich auch der `github`-MCP-Server nicht
verbinden (`CONNECTION_CLOSED`) — moeglicherweise dieselbe Ursache.
**Nicht gemessen, welche.** Das blockiert L5/L7-Gates und gehoert als Naechstes untersucht.

---

## 📐 DER ECHTE DELTA AUF 100 % — und warum ihn niemand setzen darf

Aus `docs/project-progress.manifest.json` gerechnet, nicht geschaetzt:

| Horizontal | ist | Delta | wer oeffnet das |
|---|---:|---:|---|
| `phase_3` | 44 % | **+56** | **O1** GitHub-OAuth-Identitaet (Owner) |
| `phase_5` | 89 % | **+11** | **I1** hosted candidate parity · **I5** production auth (Owner) |
| `phase_6` | 90 % | **+10** | **`AGENT_API_AUTH_TOKEN`** (Owner, ein Secret) |
| P0 · P1 · P2 · P4 | 100 % | 0 | — |

| Vertikal | ist | Delta | wer oeffnet das |
|---|---:|---:|---|
| `layer_4` LLM Gateway | 55 % | **+45** | Rubrik fehlt — **Owner muss sie freigeben** |
| `layer_5` MCP Gateway | 56 % | **+44** | Rubrik fehlt — **Owner muss sie freigeben** |
| L1 · L2 · L3 · L6 · L7 | 100 % | 0 | — |

```
horizontal offen: 77 Zellpunkte  ->  Mittelwert 89  ->  100 = +11
vertikal   offen: 89 Zellpunkte  (zaehlt NICHT in `overall`)
Gates: 7 zu / 3 offen  ->  production_auth_identity · docker_registry_publish · phase6_scale_runtime
```

### Warum ich nichts auf 100 setze

**Jeder einzelne Restpunkt haengt an einer Owner-Wand.** Es gibt keinen offenen Punkt, den ein
Agent autonom schliessen koennte:

- P3, P5, P6 brauchen **Secrets/Freigaben**, die nur der Owner geben kann (R3 unten).
- L4 und L5 haben **keine freigegebene Rubrik**. Prozente ohne Rubrik hochzusetzen ist
  ausdruecklich verboten — das waere exakt der Fake, den R0 verhindert.
- `MARKET_READY:true` ist zusaetzlich per Deadlock blockiert: O3 verlangt GHCR-Digests,
  aber Registry-Push ist vor `MARKET_READY:true` untersagt. **Den Zyklus kann nur der Owner brechen.**

> **Zahlung oeffnet nichts.** `payment_required` ist bei O1/O2/O3 `false`; eine im Manifest
> abgebildete Zahlung macht `owner-input-matrix` sogar **rot**.

**Ehrliche Antwort auf „mach alles 100 % gruen":** Alles, was ohne Owner-Freigabe gruen sein
kann, **ist** gruen (Liste oben). Die verbleibenden 11 % sind kein Arbeitsrueckstand, sondern
vier Entscheidungen. Sie zu setzen waere kein Fortschritt, sondern eine Faelschung.

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
7. [ERLEDIGT] RC20 BINDEN
     Quelle -> 6 Images -> O4 -> runtime -> dev-live -> browser
     -> 27 Evidenzen -> Kontroll-Commit -> CI -> P5-Credit
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

## 1. 🔴 DEIN NAECHSTER SCHRITT — Auswahl committen und final verifizieren

```
1. Nur RC20-Auswahlpfade committen; den fremden RC12-Stage nicht mitnehmen
2. npm run build
3. npm run verify:runtime
4. scripts/start-dev-live.ps1
5. npm run verify:browser nur falls ein spaeter Runtime-Source-Commit entstand
6. npm run verify
7. current-candidate, release-boundary, market-ready:static, release-candidate
8. Feature-Branch pushen und Remote-SHA pruefen
```

## 2. WAS DU NICHT ANFASSEN DARFST

Diese Dateien sind **fremd dirty** und gehoeren nicht dir:

- `.codex/runs/CURRENT/product-acceptance/report.json`
- `.phase1-artifacts/o4-live-writes/{proof,runtime-proof,browser-proof}.json`
- `docs/runtime-state/{capability-gates,external-gate-audit-v2,external-gate-summary,owner-input-manifest}.json`
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
| **Kandidat RC20** | `c29c738b82e4e35cc1288bc603319cba60d167d2` — **lokal qualifiziert** |
| Rollback-Anker | RC19 `5062de35a5c033354ba81a988d699aad418347c3` |
| Letzte gruene CI | Run `33200830176` (Source-Attestation auf `c29c738b`) |
| Overall | **89** · P3 44 · P5 89 · P6 90 · L4 55 · L5 56 |
| Gates | **7/10 zu**; offen: `production_auth_identity`, `docker_registry_publish`, `phase6_scale_runtime` |

---

## R2 · Test-Inventar — was welcher Befehl wirklich prüft

**Ohne Docker:**

| Befehl | Prüft |
|---|---|
| `npm run verify` | Gesamtkette Phase 1 |
| `npm run verify:phase5-credit` | P5-Credit — **gruen: 17/19 = 89%, I1/I5 blocked** |
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

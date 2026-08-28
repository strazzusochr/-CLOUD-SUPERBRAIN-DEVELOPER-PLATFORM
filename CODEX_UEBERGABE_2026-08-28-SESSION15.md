# 🏁 ÜBERGABE — 2026-08-28 · Session 15 · **Der Produktkern ist repariert**

> **Arbeitsgrundlage ist `CODEX_ZIELVERFOLGUNG_KURZ.md`.** Diese Datei ist der Anhang:
> was in dieser Session gemessen, geaendert und bewiesen wurde — und was **nicht**.
> Regelwerk: `REGELN_OPTIK_UND_FERTIG.md`.

---

## 1. DIE EINE SACHE, DIE ZAEHLT

Die Workbench erzeugte bis heute nur Spielzeug. Der Owner hat das so beschrieben:

> *„mit dem aktuellen llm qwen funktioniert nur sowas wie taschenrechner,
> es muss aber richtiges 3d webgl gerendert werden"*

**Der Befund ist bestaetigt — und die Ursache war nicht das Modell.**
Vier Deckel lagen uebereinander. Alle vier sind gemessen worden, keiner geraten.

---

## 2. WAS ICH GEMESSEN HABE, BEVOR ICH ETWAS GEAENDERT HABE

| Messung | Ergebnis | Wie |
|---|---|---|
| `CF_WORKERS_AI_MAX_TOKENS` im laufenden Container | **UNSET** | `docker exec … echo` |
| Wirksamer Deckel | **2048** | Code-Default in `services/llm-gateway/app/main.py:32` |
| Anfrage der Build-Route | **5200** | `apps/frontend/app/api/v1/build/route.ts` |
| Tatsaechlich gesendet | `min(5200, 2048)` = **2048** | `main.py:1027` |
| Groesstes je persistiertes Artefakt | **6867 Bytes / 191 Zeilen** | alle 40 Builds ueber `/api/v1/build/{id}` |
| Median | **2967 Bytes** | dito |
| Persistenz-Limit | **160 KB** | `MAX_PERSISTED_HTML_BYTES` |
| Kontextfenster des Modells | **32 768 Token** | offizielle Cloudflare-Doku |

Der Deckel lag bei rund **6 %** dessen, was das Modell kann. Und weil ein unvollstaendiges
Dokument von der Persistenzgrenze **hart abgelehnt** wird, konnten nur kleine Apps je durchkommen.

---

## 3. WAS GEAENDERT WURDE — 5 Commits, R-SELF-1 durchgehend eingehalten

| Commit | Art | Inhalt |
|---|---|---|
| `84f0e82b` | **test (rot)** | Bindet den stillen Token-Deckel: Default zu klein, Route-Budget still reduziert, Compose deklariert nichts |
| `f970678b` | fix | Default 2048 → **8192**; `docker-compose.dev.yml` deklariert die Variable; Prompt fordert die ganze App statt „~300 lines" |
| `0a9b2630` | **test (rot)** | Bindet das **invertierte Zeitbudget** |
| `1917cfaf` | fix | Route 50 s → **100 s**, `maxDuration` 60 → **115** |
| `c0c57d3d` | feat | Prompt fordert eine **beleuchtete, fertige** 3D-Szene |

Jeder Test war **nachweislich rot**, bevor die Umsetzung kam, und lag in einem **eigenen Commit**.

---

## 4. DER VIERTE DECKEL — erst sichtbar, nachdem der erste weg war

Sobald mehr Token erlaubt waren, antwortete `POST /api/v1/build` mit
**HTTP 503 `configured_boundary_unavailable` nach 53,8 s**.

Es war **nichts unavailable**. Die Kette war invertiert:

```
vorher:  Route 50 s  <  Provider 90 s      <- der innere Hop lebt laenger als der wartende
jetzt:   Provider 90 s < Route 100 s < maxDuration 115 s < nginx 120 s
```

Ein **langsamer Erfolg** konnte damit nur als **falscher Ausfall** erscheinen.
Der spaetere erfolgreiche Lauf brauchte **61,9 s** — unter dem alten Limit waere er
erneut als Ausfall gemeldet worden.

---

## 5. DER BEWEIS — echtes 3D, wirklich spielbar (DEV-ONLY)

Live gegen `@cf/qwen/qwen2.5-coder-32b-instruct`, Gateway `cloudflare_workers_ai_live`,
ueber den echten Produktpfad (Gastsession → `POST /api/v1/build`):

```
build: HTTP 200 in 61,9 s
id    : 5a5fbcce-0e78-4020-8e41-499f8760b708
bytes : 7953   lines: 232
```

**7953 Bytes ist groesser als jedes der 40 zuvor persistierten Artefakte.**

| Geprueft | Ergebnis |
|---|---|
| WebGL-Kontext | **WebGL 2.0 (OpenGL ES 3.0 Chromium)**, Canvas 1280×800 |
| Console-/Page-Errors | **0** |
| Render | blauer Himmel, grosser gruener Boden, violette Plattformen, roter Spieler **mit geworfenem Schatten**, Muenzen, HUD `Score: 0` |
| Bewegung | Pfeil rechts → Welt verschiebt sich unter **mitlaufender Kamera** |
| Sprung | Leertaste → Spieler loest sich sichtbar **von seinem Schatten** |
| Material | `MeshStandardMaterial` ×5 · `MeshBasicMaterial` **0** |
| Schatten | `castShadow` 5 · `receiveShadow` 4 · `shadowMap` 2 |
| Eingabe | `keydown` **und** `keyup` |

**Artefakte:** `docs/audit/workbench-3d-game-2026-08-28/`
`01-render.png` · `02-move-right.png` · `03-jump.png` · `generated-game.html`

---

## 6. ⛔ EIN EIGENER MESSFEHLER — und warum er hier steht

Mein erster Renderbeweis las den Canvas per `createImageBitmap` aus und meldete:

```
Pixels: { distinctColours: 1, litSamples: 0 }   ->  "schwarzes Bild"
KeyMove: { changedSamples: 0 }                  ->  "reagiert nicht"
```

**Beides war falsch.** WebGL-Canvases geben ohne `preserveDrawingBuffer: true` nach dem
Compositing schwarz zurueck. Der Playwright-**Screenshot** derselben Seite zeigte eine
vollstaendig gerenderte 3D-Szene.

Haette ich der Zahl geglaubt, haette ich ein funktionierendes Produkt als kaputt gemeldet —
und vermutlich „repariert", bis es wirklich kaputt gewesen waere.

> **Daraus wurde `R-MEAS-1`** (jetzt in der Ziel-Datei): Wenn eine Messung „nichts da" sagt,
> zuerst pruefen, ob die Messmethode ueberhaupt etwas sehen **kann**.
> Bei Optik entscheidet das Bild, nicht der Zahlenwert.

---

## 7. ⚠️ EINE ZWISCHENVERSION WAR SCHLECHTER — nicht als Fortschritt gezaehlt

Der erste Versuch, Optik zu fordern, verlangte ACES-Tone-Mapping. Ergebnis:
**fast schwarze Silhouetten, Boden komplett verschwunden.**

Der Grund ist real: three.js r155+ nutzt physikalische Lichteinheiten; ACES ueber
Default-Intensitaeten rendert dunkel. Der Prompt fordert jetzt explizit helle Intensitaeten
(Directional 2.5–3.5, Ambient/Hemisphere 1.5–2.5), einen 200×200-Boden, Fog in Himmelsfarbe —
und sagt ausdruecklich: *ein dunkles Rendering ist ein fehlgeschlagenes Rendering*.

Diese Zwischenversion ist **verworfen**, nicht behauptet.

---

## 8. WAS ICH **NICHT** GETAN HABE — ausdruecklich

Damit niemand mehr hineinliest, als da ist:

| Nicht getan | Grund |
|---|---|
| **22-Seiten-Test / 161 Aktionen** | in dieser Session **nicht** gelaufen |
| **Cloud-Layer-Routing ueber alle 7 Layer** | in dieser Session **nicht** geprueft |
| **`npm run verify` Gesamtkette** | wuerde an der Kandidatenbindung stoppen (RC18 tot) |
| **`verify:runtime` / `verify:browser`** | nicht gelaufen |
| **RC19 gebaut oder gebunden** | offen — das ist der naechste Schritt |
| **Push** | siehe unten |
| **Organismus-Optik** | per Owner-Entscheidung **ganz am Ende** |
| **3-Sterne-Look der Spiele** | erreicht ist „solide beleuchtetes 3D", **nicht** 3-Sterne |

**Alles, was oben in Abschnitt 5 steht, ist DEV-ONLY. Hosted proof still blocked.**

---

## 9. DER ZUSTAND, IN DEM DU UEBERNIMMST

```
Quellstand c0c57d3d (letzter Runtime-Source-Commit)   Branch codex/organism-visual-v2
Overall 89   P0/P1/P2/P4 100 · P3 44 · P5 89 · P6 90
             L1/L2/L3/L6/L7 100 · L4 55 · L5 56
Gates   7/10 zu    offen: production_auth_identity · docker_registry_publish · phase6_scale_runtime
Stack   10/10 healthy · cloudflare_workers_ai_live
Build   21/21 Seiten gruen · tsc sauber
Tests   llm-gateway 31/31 · runnability 14/14 · oauth-boundary gruen
MARKET_READY: false
```

### 🔴 RC18 ist tot — und das war schon so, bevor ich anfing

`current-release-candidate.json` zeigt auf `prod-candidate-2026-08-28-local-rc18`.
Dieser Kandidat hat **kein** `-evidence/`-Verzeichnis und **keine** `-readiness.json`;
die `.md` ist ein untracked **13**-Zeilen-Stumpf mit `qualification_status: in-progress`.
`verify:phase5-credit` stoppt folgerichtig an
`C4 evidence #1 anchor is not present in the evidence artifact`.

Das ist Codex' abgebrochener Lauf (Nutzungslimit), **kein neuer Defekt** — die Datei war
bereits vor dieser Session dirty. Zusaetzlich liegt jetzt echter Runtime-Source-Drift darauf:
`apps/frontend` und **`services/llm-gateway`** stehen namentlich in `RUNTIME_SOURCE_PATHS`
(nicht `services/` pauschal), und beide wurden geaendert.

> **RC18 nicht reparieren. RC19 auf dem neuen HEAD binden.**

### CI-Signal auf dem gepushten Stand — Run `33187389678`

Nach dem Push habe ich `pr-check` auf dem Branch-Tip dispatcht. Ergebnis, exakt:

```
success  Checkout / Setup Node / Setup Python
success  Bind run control to exact checked-out source
success  Docker Compose config
success  Forbid patched-plan drift in compose      <- validiert meine Compose-Aenderung
success  Python syntax
success  Backend auth security unit contract
success  Phase 6 scale fail-closed static contracts
failure  Phase 5 credit itemization
         "active candidate has committed or staged runtime-source drift
          outside the exact post-qualification truth transition"
```

**10 Schritte gruen, dann Abbruch am 11. von 27** — danach wurden **14 Schritte uebersprungen**,
darunter der Runnability-Guard, der OAuth-Kontrakt, der Secret-Scan und der Image-Build.
**Die in dieser Session ergaenzten Tests sind in CI also nie gelaufen.** Grund des Abbruchs:
Der aktive Kandidat ist RC18, und meine Aenderungen an `apps/frontend` und `services/` sind
Runtime-Source-Drift dagegen. **Das System arbeitet korrekt.** Gruen wird das erst mit RC19.

> Nebenbefund fuer den naechsten Lauf: `-f source_prequalification=true` verlangt, dass
> `candidate_sha` sich vom Control-SHA **unterscheidet**. Mit dem Branch-Tip als beidem
> bricht der Guard sofort ab (`source prequalification requires candidate_sha to differ`).
> Fuer RC19 also erst den Kontroll-Commit auf einem eigenen Branch, dann dispatchen.

---

### Fremd-dirty — nie anfassen

`.codex/runs/CURRENT/product-acceptance/report.json` ·
`.phase1-artifacts/o4-live-writes/{proof,runtime-proof,browser-proof}.json` ·
`docs/runtime-state/{capability-gates,external-gate-audit-v2,external-gate-summary,owner-input-manifest}.json` ·
`docs/release-artifacts/current-release-candidate.json` ·
**gestaged:** `docs/release-artifacts/prod-candidate-2026-08-02-local-rc12.md`

---

## 10. WAS DANACH GESCHAH — RC19, RC20, und ein offener RC21

Diese Uebergabe endete bei „RC19 faellig". Codex hat danach weitergearbeitet und beides
geliefert; der Stand unten ist am 2026-08-28 nachgeprueft, nicht uebernommen.

| Kandidat | Quelle | Status |
|---|---|---|
| **RC19** | `5062de35` (= der Quellstand dieser Session) | qualifiziert, CI `33193522336`, 27 Evidenzen |
| **RC20** | `c29c738b` | qualifiziert, Control `6f9387c6`, CI `33200830176`, 27 Evidenzen — **committed aktiv** |
| **RC21** | `88fc985a` | **in Arbeit, nicht qualifiziert** — nur `.md`, kein `-evidence/`, keine `-readiness.json` |

RC20 haelt in der Abnahme ArrowRight/KeyD jetzt ueber mehrere `requestAnimationFrame`-Frames
gedrueckt — eine **Harness**-Korrektur fuer Spiele, die Tastenzustand im Frame pollen.
Das ist keine Optik-Umsetzung und keine visuelle Abnahme.

### ⚠️ `npm run verify:phase5-credit` ist derzeit ROT — und das ist korrekt

```
[phase5-credit] C3 evidence #1 anchor is not present in the evidence artifact
```

Ursache exakt belegt, nicht vermutet: C3-Evidenz #1 verlangt in
`docs/release-artifacts/current-release-candidate.json` den Anker
`"active_release_id": "prod-candidate-2026-08-28-local-rc20"`. Der **committete** Stand
enthaelt genau das. Der **Arbeitsbaum** wurde von Codex auf `…-rc21` gesetzt (uncommitted,
fremd-dirty), also fehlt der Anker.

> **Das ist kein Defekt.** Der committete Stand ist konsistent; der Arbeitsbaum steht
> mitten in RC21. Wer RC21 nicht fertigstellt, sieht dieses Rot dauerhaft.

### ⛔ FALLE: `PROJECT_STATE.md` darf **nicht allein** aktualisiert werden

`PROJECT_STATE.md` ist inhaltlich veraltet — es nennt noch **RC14** als aktiven Kandidaten
und traegt `Letzte Aktualisierung: 2026-08-27`. Trotzdem darf man es jetzt **nicht** einfach
nachziehen:

`PROJECT_STATE.md` steht in **beiden** Mengen — `RUNTIME_SOURCE_PATHS` **und**
`QUALIFICATION_TRUTH_PATHS`. Der erlaubte Nachqualifizierungs-Uebergang prueft mit
**exakter Mengengleichheit**:

```python
require(changed_paths == QUALIFICATION_TRUTH_PATHS, ...)   # verify_phase5_credit_itemization.py:1160
```

Ein Update von `PROJECT_STATE.md` allein ergibt eine 1-elementige Menge und ist damit
**ungleich** der geforderten Vierermenge:

```
PROJECT_STATE.md · apps/frontend/lib/endpoint-snapshot.json
apps/frontend/lib/platform.ts · docs/project-progress.manifest.json
```

> **Regel:** `PROJECT_STATE.md` wird **vor** dem Einfrieren der naechsten Kandidatenquelle
> aktualisiert — oder gemeinsam mit allen vier Truth-Pfaden als bewusster Uebergang.
> Nachtraeglich allein nachziehen bricht die Kandidatenbindung.

---

## 12. TIEFEN-CHECK — was dabei wirklich kaputt war

Auftrag war: nichts falsch, nichts vergessen, keine Haenger, keine Bugs. Ergebnis:

### 12.1 Ein echter roter Test — zwei unabhaengige Ursachen

`node --test scripts/tests/five-axis-audit-regression.test.mjs` war **rot**. Nicht
„historisch rot", sondern jetzt.

**Ursache 1 — vorbestehend.** `PROJECT_STATE.md` nennt die Basis-URL
`http://localhost:8081/llm/v1`. Der Auditor hatte fuer diesen Token keine Klassifikation und
zaehlte ihn als `unresolved authoritative endpoint`. Es ist ein Namespace hinter der
Nginx-Grenze `location /llm/`, kein Handler — die Handler sind
`/llm/v1/chat/completions`, `/llm/v1/responses`, `/llm/v1/models`.
Als `NAMESPACE-ONLY` klassifiziert, neben `/api/v1`.
*Beweis, dass es nicht meins war:* alle drei beteiligten Dateien wurden zuletzt am
**2026-08-27** geaendert, also vor dieser Session.

**Ursache 2 — meins.** Dahinter lag ein zweiter Fehler, den erst die erste Reparatur
sichtbar machte:

```
[five-axis-audit] strict unfinished markers exist: apps/frontend/app/api/v1/build/route.ts:25
```

Meine Prompt-Zeile enthielt das Literal **`TODO`** („never stop early with a TODO or a
placeholder comment"). Der Auditor wertet dieses Wort in Produktquelltext repo-weit als
unfertigen Marker — **zu Recht**. Umformuliert auf „a placeholder comment or an
unfinished-work marker"; Bedeutung unveraendert.

Danach: Auditor `PASS`, `routes=22 real=11 contract=10 spec=1`, Regressionstest **2/2**.

> **Warum das durchrutschen konnte:** `verify:five-axis-audit` haengt **nicht** in
> `verify.suites.json` oder `verify-phase1.ps1` — es sind eigenstaendige npm-Skripte.
> Deshalb konnte RC20 gruen werden, obwohl dieser Test rot war. **Das ist eine echte
> Luecke in der Gate-Kette**, kein Einzelfall-Pech.

### 12.2 Ein Guard hat korrekt gestoppt — kein Bug

Der erste 22-Seiten-Lauf brach sofort ab:

```
22-page action acceptance requires explicit -ApproveLiveProviderCalls
because two registered controls perform one real LLM provider call each
```

Das ist eine **Kostenbremse**, kein Fehler. Der Lauf wurde mit expliziter Freigabe
wiederholt (2 gebundene Cloudflare-Calls, Free-Tier).

### 12.3 Echte Klicks — bestanden

`npm run verify:product-acceptance` mit **echtem Provider**:

```
ok 1  real prompt builds, runs, interacts, and reloads the persisted 3D game (1.2m)
build_id=eaf70ed3-a170-4697-864d-f3c9ac1903fa
provider=cloudflare-workers-ai   live_provider_calls=true
report sha256=788D7F9D…3D2ACE
```

Also: echter Prompt -> echter Build -> laeuft -> **Interaktion** -> Reload mit identischem
Artefakt. Nicht simuliert, nicht abgefangen, kein Mock.

### 12.4 Was gruen ist

| Pruefung | Ergebnis |
|---|---|
| `tsc --noEmit` | gruen |
| `generated-html-runnability` | **14/14** |
| `oauth-boundary-readiness` | gruen |
| `auth-session-integrity` | gruen |
| `llm-gateway` Unit | **31/31** |
| `five-axis-audit` + Regression | **PASS · 2/2** (nach Reparatur) |
| Produktabnahme, echte Klicks, Live-Provider | **PASS** |
| Stack | **10/10 healthy**, `cloudflare_workers_ai_live` |

---

## 11. NAECHSTER SCHRITT

```
1. RC21 auf 88fc985a fertig binden - ZWINGEND, nicht optional:
   Codex' Lint-Fix 88fc985a aenderte CortexLive.tsx (in RUNTIME_SOURCE_PATHS)
   nach RC20, also deckt RC20-Quelle c29c738b den HEAD nicht mehr ab.
   Bis dahin bleibt verify:phase5-credit korrekt rot.
2. PROJECT_STATE.md im Rahmen des Vierer-Truth-Uebergangs oder vor dem naechsten
   Source-Freeze nachziehen (siehe Falle oben)
3. Die in CI nie gelaufenen neuen Tests einmal in einem gruenen CI-Lauf sehen
4. L4/L5-Rubrik vom Owner freigeben lassen -> erst dann Prozente
5. GANZ ZULETZT: Organismus-Optik und der 3-Sterne-Look
```

---

*Session 15 · 2026-08-28 · Quellstand dieser Session `c0c57d3d` (= RC19-Quelle `5062de35` nach
den Doku-Commits) · committed aktiver Kandidat RC20 `c29c738b` · Overall 89 · Gates 7/10 ·
`MARKET_READY:false`
Ziel-Datei: `CODEX_ZIELVERFOLGUNG_KURZ.md` · Regeln: `REGELN_OPTIK_UND_FERTIG.md`*

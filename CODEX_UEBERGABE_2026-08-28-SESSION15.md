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
HEAD    c0c57d3d   Branch codex/organism-visual-v2
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
die `.md` ist ein untracked 12-Zeilen-Stumpf mit `qualification_status: in-progress`.
`verify:phase5-credit` stoppt folgerichtig an
`C4 evidence #1 anchor is not present in the evidence artifact`.

Das ist Codex' abgebrochener Lauf (Nutzungslimit), **kein neuer Defekt** — die Datei war
bereits vor dieser Session dirty. Zusaetzlich liegt jetzt echter Runtime-Source-Drift darauf.

> **RC18 nicht reparieren. RC19 auf dem neuen HEAD binden.**

### Fremd-dirty — nie anfassen

`.codex/runs/CURRENT/product-acceptance/report.json` ·
`.phase1-artifacts/o4-live-writes/{proof,runtime-proof,browser-proof}.json` ·
`docs/runtime-state/{capability-gates,external-gate-audit-v2,external-gate-summary,owner-input-manifest}.json` ·
`docs/release-artifacts/current-release-candidate.json` ·
**gestaged:** `docs/release-artifacts/prod-candidate-2026-08-02-local-rc12.md`

---

## 10. NAECHSTER SCHRITT

```
1. RC19 binden  (Quelle einfrieren -> 6 Images -> O4 zuletzt -> runtime
                 -> dev-live -> browser -> Evidenz -> Kontroll-Commit -> CI -> P5-Credit)
2. 22-Seiten-Test und Layer-Routing im Rahmen von verify:browser nachholen
3. L4/L5-Rubrik vom Owner freigeben lassen -> erst dann Prozente
4. GANZ ZULETZT: Organismus-Optik und der 3-Sterne-Look
```

---

*Session 15 · 2026-08-28 · HEAD `c0c57d3d` · Overall 89 · Gates 7/10 · `MARKET_READY:false`
Ziel-Datei: `CODEX_ZIELVERFOLGUNG_KURZ.md` · Regeln: `REGELN_OPTIK_UND_FERTIG.md`*

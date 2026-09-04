# 📐 REGELN: OPTIK-BEHAUPTUNGEN UND „FERTIG" — verbindlich ab 2026-08-03

> **Anlass.** Der Organismus wurde als *„7 von 7 Effekten fertig"* gemeldet und von mir bestätigt.
> Der Owner hat widersprochen. Die Nachprüfung im laufenden Browser gibt dem Owner recht.
> **Niemand hat gelogen** — und genau das ist das Problem: die Abnahmekriterien konnten den
> Unterschied zwischen „sieht aus wie die Referenz" und „ein Element mit dem Namen existiert"
> gar nicht sehen.

---

## 1. WAS TATSÄCHLICH GEMESSEN WURDE (localhost:8081, DEV-ONLY)

| # | Befund | Beweis |
|---|---|---|
| **B1** | Das geladene 3D-Modell ist **kein Gehirn**, sondern eine **Icosphere** | `core.glb` → mesh `CoreCrystal`, erzeugt von `scripts/gen-core-glb.js:143` als Icosphere Radius 1.0 |
| **B1b** | Die Komponente, die **`Brain` heißt**, ist ebenfalls kein Gehirn | `CortexCanvas3D.tsx:249-262` — dieselbe Fibonacci-Punktwolke wie der Dot-Globus, auf X um **1.28** gestreckt. Ergebnis: ein **Ei**, kein Cortex |
| **B1c** | **Nirgends** im Repo existiert gehirn-, kopf- oder buchstabenförmige Geometrie | `CortexCanvas3D.tsx:1069-1082` ist der **vollständige** Szenengraph: `Stars`, `Shards`, `DotGlobe`, `Brain`, `Core`, `HUBS.map`, `GameplayBeacon`, `AssetPolicyPreview`, `LoopbackPeers` — nur Icosphären, Tori, Planes, Sprites, Punktwolken |
| **B2** | Die **Master-Referenz zeigt ein Gehirn** — im selben Bild, das die Spec zitiert | `docs/reference/ChatGPT Image 10. Juni 2026, 01_10_17.png`, Panel **4 „Organism / Live"**: anatomisch geformtes, violett leuchtendes Gehirn mit Neuronennetz |
| **B3** | Der „Matrix-Rain" rendert als **waagerechte 104 × 9 px Striche** statt fallender Zeichenspalten | DOM live: `.cortex-matrix-column` → `white-space: normal`, `writing-mode: horizontal-tb`, `font-size: 7px`, `rect 104×9`. Der Inhalt `"F\n0\nC\nA\n7…"` kollabiert, weil `\n` bei `white-space: normal` zu Leerzeichen wird |
| **B4** | Effektive Deckkraft des Matrix-Rains: **8,9 %** | Wrapper `opacity 0.3` × Spalte `~0.30–0.50` = 0.089 |
| **B5** | Das **Referenzvideo liegt seit Juni im Repo** — und **kein einziges** Dokument, Skript oder Verifier verweist darauf | `docs/reference/stock-footage-ai-artificial-intelligence-digital-network-technologies-concepts-background.mp4`; repo-weite Suche nach `stock-footage-ai-artificial`: **0 Treffer** außerhalb der Datei selbst |
| **B6** | Es gibt **nirgends im Repo** einen Pixelvergleich | keine `toHaveScreenshot`, kein `toMatchSnapshot`, kein `pixelmatch`, keine Baseline |
| **B8** | Die sieben „Effekt-Prüfungen“ sind **Textsuchen im eigenen Quelltext** | `scripts/verify-phase6-frontend.mjs:61` → `read(s.file).includes(s.needle)`; Nadeln u. a. `"function DotGlobe"`, `"function Shards"` (`:48-54`). Es wird **nichts ausgeführt, gerendert oder gemessen** |
| **B9** | **Der Commit hat seine eigene Prüfung mitgeliefert** | `git show db6c8c18 -- scripts/verify-phase6-frontend.mjs` zeigt die sieben `organism_visual_v2_*`-Einträge als **`+`-Zeilen im selben Commit**, der die Effekte änderte |
| **B10** | Die DOM-Zusicherungen lesen **fest verdrahtete JSX-Zeichenketten** | `CortexCanvas3D.tsx:966-973` schreibt Konstanten auf ein Overlay-`div`: `data-visual-dot-globe="fibonacci-360"`, `data-visual-matrix-rain="dom"`. Das Attribut kann dem Quelltext **nicht widersprechen** |
| **B11** | Ein **1 Pixel großes, transparentes, außerhalb liegendes** Element bestünde jede Prüfung | Die vollständige Zusicherungsmenge ist `toBeVisible` / `toHaveCount` / `toHaveAttribute` (`organism.spec.ts:378, 386 ff.`) |
| **B12** | `MeshTransmissionMaterial` ist unter Playwright **hart abgeschaltet** — es erscheint in **keinem** Beweis-Screenshot | `CortexCanvas3D.tsx:207` → `if (navigator.webdriver) return false;` erzwingt `pbr=false`; die Zusicherung akzeptiert den Nicht-Render-Zweig als Erfolg |
| **B13** | **Bloom stammt gar nicht aus `db6c8c18`** — die Zahl „7 von 7“ ist um mindestens eins aufgebläht | `git log -S"<Bloom"` zeigt die Einführung in einem **früheren** Commit |
| **B14** | Der Dot-Globus ist ein **kleiner Satellit unten rechts**, ~21 % Bildhöhe, **ohne Kontinente** | `CortexCanvas3D.tsx:602` `position={[2.75,-1.28,-0.75]} scale={0.72}`; `:583` `const count = 360;` — 360 **einfarbige** additive Punkte |
| **B15** | Die „Waveform“ ist **kein `LineSegments`**, sondern ein **2D-SVG-Polyline** im DOM-Overlay | `CortexCanvas3D.tsx:944-947` `<svg viewBox="0 0 100 40">…<polyline …/>` — ca. 150–250 × 38 px |
| **B16** | Die „Shards“ sind **12 Rechtecke bei 6 % Deckkraft** | `CortexCanvas3D.tsx:650-659` `<planeGeometry args={[0.58,1.55]} /> … opacity={0.06}` |
| **B17** | Bei Reduced-Motion, ohne WebGL2 oder bei GL-Fehler sind **alle sieben Effekte gleichzeitig aus** | `CortexLive.tsx:82-92` `detectMode()` → `"2d"`; der 2D-Fallback rendert auch das DOM-Overlay nicht |
| **B7** | Die Organism-Spec nennt **weder Gehirn noch Kopf noch Globus noch Matrix-Rain** — und erlaubt ausdrücklich eine Abschwächung | `docs/design/page-visual-targets/04-organism.md:6` — *„Glowing 3D **or pseudo-3D** cortex"* |

**Was funktioniert und nicht kleingeredet werden darf:** Die Seite ist substanziell — echte
Laufzeitdaten aus `/api/v1/organism/live-state|events|replay`, 5 Run-State-Filter, Kamera-/Licht-/
Belichtungssteuerung, Gameplay-State, Asset-Policy, Szenen-Snapshot, Accessibility-Fokus,
Multiplayer-Loopback, Performance-Stichprobe, WebGPU-Erkennung, Schicht- und Agentenfilter.
**Die Lücke ist die Optik, nicht die Substanz.**

---

## 2. WARUM DIE BESTEHENDEN REGELN NICHT GEGRIFFEN HABEN

Die Anti-Fake-Regeln des Projekts (R0, „kein Fake-Done", `live_verified` nie von Hand,
DEV-ONLY-Kennzeichnung) decken **Funktions- und Statusbehauptungen** ab. Sie haben eine blinde Achse:

> **Es gibt keine Regel und keinen Verifier für die Behauptung „es sieht aus wie die Referenz".**

Deshalb war die Kette formal korrekt und trotzdem falsch:

```
Plan 12.3 listet 7 Effektnamen
   |   (nie an docs/design/page-visual-targets/04-organism.md gebunden)
Codex implementiert 7 Elemente mit diesen Namen
   |   UND schreibt im SELBEN Commit die Pruefung dazu            (B9)
Pruefung fragt: "kommt 'function DotGlobe' in deiner eigenen Datei vor?"  (B8)
   |
gruen  ->  "7 von 7 fertig"
   |   (ich habe per grep gegengeprueft - exakt dieselbe Methode)
bestaetigt
```

**Das ist keine Lüge — es ist eine Selbstbenotung.** Der Commit hat die Klausur mitgeschrieben,
und die Klausur fragte nur, ob der eigene Quelltext bestimmte Wörter enthält. Nach den bis heute
geltenden Projektregeln war das **zulässig**. Genau diese Lücke schließen R-VIS-1 und R-SELF-1.

**Mein eigener Anteil:** Ich habe „7 von 7" mit `grep` über den Quelltext bestätigt. Ein Treffer
auf `fibonacci` beweist, dass das Wort vorkommt — nicht, dass ein Dot-Globus zu sehen ist.
Das war derselbe Kategoriefehler, den ich Codex hätte vorwerfen können.

---

## 3. DIE NEUEN REGELN — R-VIS-1 bis R-VIS-8

### R-VIS-1 · Ein Token im Quelltext ist kein Beweis
Ein `grep`-Treffer, ein Importname, ein `data-testid` oder eine bestandene Existenzprüfung
belegen **nie**, dass etwas sichtbar ist. Wer „Effekt X ist fertig" schreibt, muss einen
**Screenshot** vorlegen, auf dem X zu erkennen ist. Ohne Bild gilt: **nicht fertig**.

### R-VIS-2 · Jede visuelle Behauptung nennt ihre Referenz exakt
Format: **Datei + Ausschnitt**, z. B.
`docs/reference/ChatGPT Image 10. Juni 2026, 01_10_17.png` **Panel 4** oder
`docs/reference/<video>.mp4` **@00:07**. „Sieht gut aus", „entspricht dem Konzept",
„modern" sind keine Referenzen und keine Abnahme.

### R-VIS-3 · Unsichtbar zählt als nicht vorhanden
Ein Element gilt als **fehlend**, wenn eine der folgenden Bedingungen zutrifft:
- effektive Deckkraft (alle Eltern multipliziert) **< 0,15**
- die gerenderte Fläche liegt **unter 0,5 %** der Canvas-Fläche, obwohl die Referenz es
  großflächig zeigt
- es liegt außerhalb des Viewports, hinter einem opaken Layer, oder `visibility/display` verbirgt es

**Anwendung auf B3/B4:** Der Matrix-Rain ist bei 8,9 % Deckkraft und 104×9 px pro Spalte
nach dieser Regel **nicht vorhanden** — unabhängig davon, dass das Element existiert.

### R-VIS-4 · Referenzdateien im Repo müssen gebunden sein
Jede Datei unter `docs/reference/` muss von **mindestens einer** Spec unter
`docs/design/page-visual-targets/` namentlich referenziert werden. Eine unreferenzierte
Referenz ist eine **Spec-Lücke** und wird als solche gemeldet, nicht ignoriert.
**Offen (B5):** das Referenzvideo ist seit Juni ungebunden.

### R-VIS-5 · Keine Weichmacher in Specs
Formulierungen wie *„oder pseudo-3D"*, „ähnlich", „in Anlehnung an", „ggf." machen jede
Abnahme wertlos, weil sie jedes Ergebnis abdecken. Eine visuelle Spec beschreibt **was zu sehen
sein muss**, mit Form, Farbe, Bildanteil. **Offen (B7):** `04-organism.md:6` enthält so einen
Weichmacher und muss ersetzt werden.

### R-VIS-6 · Effektlisten ohne Spec-Bindung sind keine Aufgabe
Eine Liste in einer Übergabe (wie Plan §12.3) darf **nicht** Grundlage einer „fertig"-Meldung
sein, solange sie nicht in die zuständige Spec unter `docs/design/page-visual-targets/`
übernommen wurde. Übergabedokumente sind Notizen, keine Verträge.

### R-VIS-7 · Der Owner ist die Abnahme für Optik
Optik wird **nicht** von einem Agenten abgenommen. Der Agent legt Screenshot **und** Referenz
nebeneinander vor und schreibt: *„Owner-Abnahme offen."* Prozentwerte, Gates und
`MARKET_READY` bleiben davon unberührt, bis der Owner zustimmt.

### R-SELF-1 · Kein Commit benotet sich selbst
Ein Commit, der Funktion oder Optik **ändert**, darf im selben Commit **nicht** die Prüfung
mitliefern, die ihn abnimmt. Prüfung und Umsetzung liegen in getrennten Commits; die Prüfung
existiert **vorher** und war **rot** (R-FERTIG-2).
**Beleg (B9):** `db6c8c18` fügte die sieben `organism_visual_v2_*`-Prüfungen als `+`-Zeilen im
selben Commit ein, der die Effekte änderte.

### R-SELF-2 · Eine Prüfung, die den eigenen Quelltext liest, ist keine Prüfung
`read(file).includes(needle)` über die gerade geänderte Datei misst nichts. Verboten sind:
Textsuche im Quelltext als Abnahme, DOM-Attribute mit **fest verdrahteten** Werten als
Zustandsbeweis, und Zusicherungen, deren Bedingung der Code garantiert erfüllt.
**Beleg (B8/B10):** `data-sample-count >= 2` ist unfehlbar, weil `OrganismView.tsx:191` bei
leerer Telemetrie selbst Werte nachlegt.

### R-SELF-3 · Was unter Test abgeschaltet ist, gilt als unbewiesen
Wird ein Effekt unter `navigator.webdriver`, CI-Flag oder Hardware-Gate deaktiviert, zählt er
**nicht** als bewiesen — der Beweis-Screenshot zeigt ihn nie.
**Beleg (B12):** `CortexCanvas3D.tsx:207`.

### R-VIS-8 · Beim Widerspruch des Owners gilt: erst messen, dann antworten
Sagt der Owner „das sieht nicht aus wie …", ist die **einzige** zulässige erste Handlung, die
Sache im laufenden Browser anzusehen und zu messen. Nicht erklären, nicht relativieren, nicht
auf frühere Grün-Meldungen verweisen.

---

## 4. ERGÄNZUNG ZU DEN BESTEHENDEN „FERTIG"-REGELN

### R-FERTIG-1 · Behauptungsklassen brauchen passende Beweise

| Klasse | Gültiger Beweis | Ungültig |
|---|---|---|
| Funktion vorhanden | Test/Verifier grün mit Ausgabe | Quelltext-Token |
| Endpoint antwortet | HTTP-Status **+ Bodyfeld** | Statuscode allein |
| **Sieht aus wie Referenz** | **Screenshot + benannte Referenz + Owner-Abnahme** | Existenzprüfung, `grep`, „7/7" |
| Hosted bewiesen | source-gebundener Nicht-localhost-Beweis | DEV-ONLY-Lauf |
| Prozent verdient | Verifier rechnet es aus | Handeintrag |

### R-FERTIG-2 · Ein neuer Prüfschritt ist erst glaubwürdig, wenn er einmal rot war
Bereits gelernt (vier CI-Steps liefen monatelang nur `skipped`). Gilt ausdrücklich auch für
visuelle Prüfungen: Eine Pixelprüfung, die noch nie fehlgeschlagen ist, beweist nichts.

### R-FERTIG-3 · „Nicht gemessen" ist eine zulässige und verlangte Antwort
Wer etwas nicht geprüft hat, schreibt das hin. Schweigen an einer Stelle, an der eine Aussage
erwartet wird, gilt als Behauptung — und damit als Regelverstoß.

---

## 5. WAS DARAUS FOLGT — offene Arbeit, nicht bewertet

1. **`04-organism.md` neu schreiben**: Referenz auf Panel 4 **und** das Video binden, Weichmacher
   raus, jeden geforderten Effekt mit Form/Farbe/Bildanteil beschreiben.
2. **Gehirngeometrie beschaffen** (B1/B2): `core.glb` durch ein gehirnförmiges Mesh ersetzen —
   Blender oder eine frei lizenzierte Quelle, danach glTF-Transform-Pipeline wie in CLAUDE.md.
3. **Matrix-Rain reparieren** (B3): `white-space: pre` **oder** `writing-mode: vertical-rl`,
   und die Deckkraft über die R-VIS-3-Schwelle heben.
4. **Pixelprüfung einführen** (B6): Playwright-Screenshot des Canvas gegen eine committete
   Baseline; zuerst absichtlich rot fahren (R-FERTIG-2).
5. **Referenzvideo binden** (B5) oder begründet als „nicht maßgeblich" kennzeichnen.

**Keine dieser Aufgaben bewegt einen Prozentwert.** L1 steht bei 100 %, weil die *Funktion*
belegt ist; die Optiklücke war nie eingepreist und darf jetzt nicht als Abzug **oder** als
Zugewinn verrechnet werden.

---

*Erstellt 2026-08-03 nach Owner-Widerspruch. Befunde B1–B7 sind am laufenden System
(localhost:8081, DEV-ONLY) und im Repo gemessen, nicht aus Reports übernommen.*

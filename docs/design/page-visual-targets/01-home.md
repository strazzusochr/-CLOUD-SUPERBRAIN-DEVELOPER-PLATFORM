# 01 Home — Visual Target

**Status:** verbindlicher Zielvertrag, geändert am 2026-09-18
**Route:** `/home`
**Seitenrolle:** ruhige Produkteinstiegs- und Fortsetzungsfläche; die Workbench
bleibt die einzige Bauflaeche.

## Änderungsbegründung 2026-09-18

Die bisher sichtbaren Auditmarker `DEV-ONLY`, `fake_stats=false` und
`PASS home_hero_check` werden aus dem Hero entfernt. Sie waren als
Selbstbescheinigung im Produkt-Hero unvereinbar mit der übergeordneten
Produktregel für HOME und WORKBENCH: keine Audit-Hero- oder
Projektstand-Oberfläche. Wahrheits- und Abnahmebelege gehören in Tests,
Screenshot-Abnahme und die dafür vorgesehenen Evidence-/Diagnostics-Flächen,
nicht in die Einstiegsfläche.

Die frühere Home-Forderung nach einem Prompt-Builder widersprach außerdem der
Trennung zwischen Home und Workbench. Home eröffnet und setzt eigene
Arbeitsstände fort; `/workbench` erstellt und bearbeitet Builds.

### Präzisierung der Proportionen und Kartenhierarchie 2026-09-18

Die erste Umsetzung erfüllte die inhaltlichen Regeln, ließ bei 1440×900 aber
eine kurze, oben ausgerichtete Textsäule neben einem 360-px-Cortex zurück,
zeichnete den Cortex nur als kleinen Punkt im großen Rahmen und erzeugte mit
drei Karten im Zweispaltenraster ein leeres rechtes Rasterfeld. Das ist weder
die ausgewogene Zweispalten-Komposition noch die kompakte Kartenfolge aus
Panel 1. Diese Präzisierung konkretisiert daher die bestehende Referenz, ohne
Kennzahlen oder Runtime-Behauptungen aus ihr zu übernehmen.

- Bei 1440×900 misst die Hero-Zeile 272 bis 320 CSS-Pixel Höhe; die sichtbare
  Text-/Handlungsgruppe ist vertikal zum Cortex zentriert (Mittelpunktdifferenz
  höchstens 32 CSS-Pixel). Der Cortex bleibt rechts und nimmt 32 bis 52 Prozent
  der Hero-Breite ein.
- Die tatsächlich gerenderte cyan/violette Cortex-Geometrie — nicht bloß ihr
  dunkler Rahmen — nimmt mindestens 42 Prozent der Canvas-Breite und
  mindestens 62 Prozent der Canvas-Höhe ein. Sie ist eine bewusste, große
  Dekoration und kein Placeholder-Objekt.
- Die zwei persönlichen Karten bilden die erste zweispaltige Kartenzeile;
  `Produktflächen` belegt darunter die vollständige Rasterbreite. Es bleibt
  kein bewusst freies Gegenfeld neben einer einzelnen Produktkarte.
- Die beiden persönlichen Karten derselben Desktop-Rasterzeile schließen unten
  auf gleicher Höhe ab (höchstens ein CSS-Pixel Differenz). Ihre Kopfzeilen
  trennen Handlungen von Kennzeichnungen: nur `Workbench öffnen →` ist eine
  Handlung; eine passive Bereichskennzeichnung belegt keinen gleichwertigen
  Aktionsplatz und erhält keinen Button-/Pillencharakter.
- Ein einzeiliger Leerzustand erhält bei Desktopbreite höchstens 86 CSS-Pixel
  Inhaltsfläche; die Leerheit wird sachlich angezeigt, aber nicht durch große
  Reserven dramatisiert.
- Bei 375×812 bleibt die Handlung `Workbench öffnen →` im Kopf der persönlichen
  Karte einzeilig. Die ausführlichen Metatexte der vier Produktkurzwege werden
  mobil ausgeblendet statt in mehrere Zeilen umzubrechen; Titel, Ziel und Link
  bleiben sichtbar und erreichbar.

## Verbindliche visuelle Referenz (R-VIS-2)

**Referenzdatei:** `docs/reference/ChatGPT Image 10. Juni 2026, 01_10_17.png`
**Ausschnitt:** **Panel 1 — „Home / Overview“**

Die Referenz bindet folgende Komposition: dunkle, ruhige Produktfläche mit
einem zweispaltigen Einstieg, klarer Text- und Handlungsseite links sowie
einem leuchtenden violett-cyanen Cortex rechts. Unterhalb folgen kompakte
Arbeits- und Navigationskarten.

Die in der Referenz abgebildeten numerischen Kennzahlen, Prozentwerte,
Uptime-, Projekt- oder Integrationsangaben sowie Aktivitätsbadges werden
ausdrücklich **nicht** übernommen: Für sie gibt es hier keine belegte
Runtime-Quelle.

## Produktziel

Eine authentifizierte Person erkennt beim Öffnen der Seite sofort:

1. was die Plattform bietet,
2. wie sie die Workbench öffnet und
3. wie sie ausschließlich ihre eigenen zuletzt verwendeten oder angehefteten
   Arbeitsstände fortsetzt.

Die Seite ist keine Auditkonsole, keine Statuswand und keine zweite
Prompt-/Build-Oberfläche.

## Prüfbare Elementregeln

### A. Hero und primäre Handlung

- Der Hero nutzt bei Desktopbreite eine klar erkennbare Zweispalten-Komposition:
  Text und primäre Handlung links, der dekorative Cortex rechts; der Cortex
  belegt ungefähr ein Drittel bis die Hälfte der Hero-Breite.
- Die primäre Handlung lautet verständlich „Workbench öffnen“ oder
  gleichwertig und navigiert same-origin nach `/workbench`.
- Der Cortex ist eine clientlokale, nicht-interaktive Dekoration. Die
  sichtbare Produktbeschreibung darf ihn als Visualisierung kennzeichnen,
  darf jedoch weder Laufzeitstatus noch Live-Metriken behaupten.
- Im Hero erscheinen weder `DEV-ONLY`, `fake_stats`, `PASS`, Testnamen,
  Gate-Zustände, Recovery-Historie noch Rohdaten-Ausgaben.

### B. Eigene zuletzt verwendete Arbeitsstände

- Home zeigt höchstens vier zuletzt verwendete Arbeitsstände der aktuell
  authentifizierten Person.
- Jeder Eintrag enthält eine belegte Bezeichnung, einen belegten Zeitpunkt
  und einen same-origin Fortsetzungslink nach `/workbench?build=<id>`.
- Die Liste kommt ausschließlich aus einer explizit user-gebundenen
  Server-Read-Route oder einem gleichwertig abgesicherten `mine`-Scope. Ein
  globaler `default`-Projektbestand ist keine Quelle für persönliche Listen.
- Ohne eigene Einträge lautet die leere, wahrheitsgemäße Anzeige:
  „Noch keine eigenen Arbeitsstände — in der Workbench starten.“
- Ein Seitenwechsel, Reload oder Gerätewechsel darf den serverseitig
  gespeicherten, berechtigten Arbeitsstand nicht aus der persönlichen Liste
  entfernen.

### C. Angeheftete Arbeitsstände

- Angeheftete Builds sind eine eigene Workspace-Domäne und werden getrennt
  von Marketplace-, Modell-, Skill- oder Plugin-Favoriten gespeichert.
- Home zeigt sie als eigene Sektion; sie bleiben sichtbar, bis dieselbe
  berechtigte Person die Anheftung aufhebt.
- Leere und Fehlerzustände dürfen keine fremden oder erfundenen Einträge
  auffüllen.

### C.1 Löschsemantik und Backend-Grenze (2026-09-18)

Die verbindliche, für die Oberfläche beobachtbare Semantik ist eine logische
Löschung: Nach einem erfolgreichen Löschen verschwindet der Arbeitsstand aus
der eigenen Liste und aus der eigenen Anheftungsliste; eine andere Identität
darf ihn weder lesen noch anheften noch löschen. Das Löschen verändert nur
Datensätze, die an die aktuell serverseitig abgeleitete Identität gebunden
sind. Ob ein Backend den Datensatz physisch entfernt oder mit einem
`deleted_at`-Zeitpunkt aus den aktiven Abfragen nimmt, ist kein sichtbarer
Produktvertrag, solange diese Nachbedingungen und der owner-only-Schutz
identisch belegt sind.

Der lokale Page-01-Abnahmestack verwendet den Postgres-Workspace-Service. Dort
werden `workspace_build_pins` und der owner-gebundene Build in einer
Transaktion entfernt (`services/agent-api/app/main.py`, Funktionen
`delete_workspace_build_registry_entry` und
`remove_workspace_build_pin`). Die lokale Abnahme belegt deshalb die
Postgres-Ausprägung einschließlich Datenbank-Readback.

Der Cloudflare-Stateful-Code hält generische Builds per `deleted_at`-Update
verborgen (`services/cloudflare-stateful-runtime/src/index.js`, `deleteBuild`);
seine aktiven Abfragen schließen `deleted_at IS NULL` aus. Für die Workspace-
Domäne existieren daneben owner-gebundene D1-Routen, die den Subject-Header
nicht als Berechtigungsquelle akzeptieren, sondern ihn nur zusammen mit dem
internen Agent-Token verwenden und jede SQL-Lese-/Schreiboperation an
`owner_subject` binden. Die generische interne `deleteBuild`-Route bleibt von
diesen Benutzerpfaden getrennt. Die lokale Page-01-Abnahme beweist Postgres;
die D1-Ausprägung ist zusätzlich per Worker-Test und Hosted-Readback zu
belegen, nicht durch die lokale Postgres-Messung zu ersetzen.

### C.2 Löschbestätigung (2026-09-18)

Das Löschen eines eigenen Arbeitsstands ist eine zweistufige, sichtbare
Benutzerhandlung: Der erste Klick auf `Löschen` wechselt zu `Wirklich löschen`
und zeigt `Abbrechen`; erst der zweite Klick darf den DELETE-Request auslösen.
Ein Abbruch darf keinen Netzwerkaufruf und keine Datenänderung auslösen. Diese
Regel gilt unabhängig davon, ob das Backend physisch hart (Postgres) oder
logisch per `deleted_at` (D1) löscht.

### D. Produktnavigation

- Kompakte same-origin Kurzwege für Games, Apps, Media und Docs bleiben
  sichtbar und per Tastatur erreichbar.
- Links zu Workbench und Produktbereichen sind Navigation, keine
  Provider- oder Schreibaktion.

### E. Wahrheits- und Sicherheitsgrenzen

- `/home` führt keinen `POST /api/v1/build`, keinen Live-LLM-Aufruf, keine
  MCP-Schreibaktion, keinen Produktions-Claim und keine Credential-Ausgabe
  aus.
- Die Seite lädt nicht automatisch Rohantworten von Health-, Cloud- oder
  Plattform-Endpunkten in eine sichtbare Konsole.
- Das Nichtvorhandensein dieser Wirkungen wird durch echte Netzwerk- und
  Berechtigungsprüfungen belegt, nie durch ein hart verdrahtetes DOM-Attribut
  oder eine Textsuche im eigenen Quelltext.
- Persönliche Listen dürfen nur eigene Datensätze lesen, öffnen, anheften
  oder löschen; clientseitig gelieferte Nutzerkennungen sind keine
  Berechtigungsquelle.

## Abnahme und Bildbeleg

- Desktop-Abnahme erfolgt bei **1440×900**; sie prüft die Hero-Komposition,
  den lesbaren Cortex, die sichtbare primäre Workbench-Handlung und die
  kompakten Arbeits-/Navigationskarten gegen Panel 1 der Referenz.
- Mobile-Abnahme erfolgt bei **375×812**; keine Überlappung, kein verdeckter
  primärer Einstieg, Cortex und Karten bleiben lesbar und bedienbar.
- Automatisierte Screenshots schützen ausschließlich vor Regression. Die
  visuelle Übereinstimmung mit dem benannten Referenzpanel und die endgültige
  Abnahme entscheidet der Owner.
- Vor einer Implementierung muss der neue Test- und Verifier-Satz gegen den
  unveränderten alten Code nachweislich rot laufen; erst danach darf die
  Umsetzung beginnen.

# TRAE — FINALE MISSION: PLATTFORM VOLL ECHT FUNKTIONSFAEHIG (lokal, ohne Cloud)
# Ziel: Aus der bedienbaren, aber simulierten (dry-run) Plattform eine machen, in der JEDE
# Funktion ECHT laeuft - komplett LOKAL auf localhost:8081, OHNE Cloud, OHNE Kreditkarte.
# Arbeite eigenstaendig: planen -> bauen -> ECHT testen -> Fehler beheben -> wiederholen,
# bis alles unten ECHT funktioniert. Kein Schoenfaerben, keine Marker, kein dry-run als "fertig".
#
# QUELLE DER WAHRHEIT: docs/END_ZIEL_GESAMTSPEC.md + alle Spec-/Masterplan-Docs im Repo.
# ABLAGE DER BEWEISE: .codex/runs/CURRENT/trae-final/  (screenshots/, har/, erzeugte Dateien, logs)

## WAS "FUNKTIONIERT" HEISST (Beweis-Standard)
Ein Nutzer klickt im Browser und bekommt ein ECHTES Ergebnis:
echte LLM-Tokens, echte gespeicherte/abrufbare Datei, echtes erzeugtes Bild, echtes
spielbares 3D-WebGL-Canvas, echter Agenten-Lauf mit echtem Artefakt.
NICHT gueltig: "200 OK", "Marker sichtbar", "dry-run geplant". Jede Behauptung mit Beweis-Datei.

## SCHRITT 0 — STABILES FUNDAMENT
0.1 Lokalen Stack sicherstellen: docker compose -f docker-compose.dev.yml up -d
    (frontend, agent-api, mcp-gateway, llm-gateway, agent-worker, memory-worker, postgres+pgvector,
    redis, nginx auf :8081). Warten bis /api/v1/health = 200.
0.2 PUBLIC-ORIGIN-FIX: Frontend origin-unabhaengig machen - relative API-/Asset-Pfade, KEINE
    hartkodierten http://localhost-Adressen, alle Requests same-origin ueber nginx :8081.
    (Damit es auch hinter einer oeffentlichen URL/Tunnel mit Grafiken + Aktionen laeuft.)

## ECHTE LLM - LOKAL & OPEN SOURCE (damit KEIN Token/keine Karte noetig ist)
Implementiere im llm-gateway einen ECHTEN Modus, der ein LOKALES Open-Source-Modell als
OpenAI-kompatiblen Endpoint bedient (z.B. ein klein quantisiertes CPU-taugliches Modell).
- Modell lokal beziehen/einbinden ist fuer DIESEN Zweck erlaubt (Owner-Entscheidung; ersetzt
  eine evtl. alte "nur-API"-Regel).
- LLM_GATEWAY_MODE auf live; echte Antworten muessen durch Workbench UND Agenten fliessen.
- Reicht die Hardware fuer ein brauchbares Modell nicht, nimm das groesste, das stabil laeuft,
  und vermerke die Grenze ehrlich in REAL_READINESS.md (nicht faken).

## REIHENFOLGE (jedes Feature endet mit ECHTEM Ergebnis + Beweis)
F1  ECHTE LLM-ANTWORT in /workbench: Prompt -> echte Tokens sichtbar (kein dry-run).
F2  ECHTE AGENTEN: planner/coder/tester/devops fuehren echte Schritte aus (echter LLM-Call,
    echtes Code-/Datei-Ergebnis); /agents Start/Reset/Status wirken echt.
F3  MULTI-AGENTEN (LangGraph): ein Auftrag wird real in Subtasks zerlegt, Agenten arbeiten
    zusammen, echtes Ergebnis entsteht; Organismus-Events sind ECHT (kein Replay).
F4  TOOLS/MCP/CLI: MCP-Tools liefern echte Ergebnisse; CLI/Bash/Tests laufen real im lokalen
    Sandbox-Container.
F5  SKILLS & PLUGINS: real registrierbar und im Agenten/LLM-Werkzeugguertel echt aufrufbar.
F6  FILES/MEMORY: echte pgvector-Suche, echtes Indexieren, echtes Lesen/Schreiben lokaler Dateien.
F7  3D-WEB-GAME: in /games + /workbench ein echtes Game erstellen -> spielbares Three.js/WebGL-
    Canvas in der Vorschau, als Artefakt gespeichert.
F8  BILDER: echte Bildgenerierung ueber ein lokales Open-Source-Modell -> echte Bilddatei sichtbar.
F9  DOCS/EXPORT: echte Markdown/PDF-Erstellung + Download.
F10 VIDEO/MEDIA: best-effort echt lokal; wenn nur mit GPU realistisch -> voll verdrahten +
    ehrlich in BLOCKERS.md (kein Fake).
F11 3D-ORGANISMUS: pulsiert mit ECHTEN Live-Events aus F1-F3 (SSE/WS), Brain-Mapping aktiv.

## GUARDRAILS
- Keine Secret-Werte in Dateien/Logs. Kein Production-Deploy, kein Push auf main, kein
  Registry-Push, keine externen Provider-/MCP-Writes. Lokale ECHTE Ausfuehrung ist erwuenscht.
- Auf Feature-Branch arbeiten, lokal committen.

## NACHWEIS & FORTSCHRITT
- Pro Feature: ECHT-Test + Beweis in .codex/runs/CURRENT/trae-final/<feature>/.
- Pflege docs/REAL_READINESS.md: pro Feature ECHT / TEILWEISE / BLOCKER(Grund) + ehrliche
  Gesamt-Zahl (real funktionierende / geplante Features).
- Am Ende: Klick-bis-Ergebnis-Proof ueber alle 22 Seiten gegen localhost:8081, FAIL=0,
  und je Kernfeature ein echtes Ergebnis-Artefakt.

## ABSCHLUSS
Arbeite weiter, bis F1-F9 + F11 ECHT funktionieren und bewiesen sind (F10 echt ODER ehrlich als
Blocker). docs/REAL_READINESS.md nennt die ehrliche Endzahl. Wo eine echte Grenze besteht
(Hardware/GPU): klar benennen, NICHT vortaeuschen. Kein Fake-Done.

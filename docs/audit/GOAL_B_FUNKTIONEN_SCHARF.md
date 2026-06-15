# GOAL B — FUNKTIONEN ECHT SCHARF SCHALTEN (lokal, kein Cloud/Owner noetig)
# Grundlage: .codex/runs/CURRENT/total-audit/report.md (Teil B/C/D/E) + inventory.json.
# Ausgangslage: reale Funktion 8%, alle 22 Seiten network_or_state_actions=0,
#   /games /apps /media = 502, Playwright-MCP kaputt, viele tote Controls.
# Ziel dieser Mission: aus toter Huelle eine echt bedienbare LOKALE Plattform machen.
#
# EISERNE REGELN:
# - Beweis-Standard: jede "fertig"-Behauptung NUR mit echtem Browser-Klick-bis-Ergebnis
#   (Screenshot vorher/nachher + HAR/Trace, das einen ausgeloesten Request/State zeigt).
#   "Endpoint 200" oder "Marker im DOM" zaehlt NICHT.
# - Keine Secret-Werte. Kein Fake-Done. Keine Cloud-Mutation. Keine der 8 Gefahr-Gates
#   oeffnen (Production deploy, Release promotion, Provider writes, Main push, Registry
#   push, Live MCP write, Live LLM call, Secret output) -- die sind Owner-only.
# - Live-LLM bleibt dry-run. MCP nur READ-ONLY ausfuehren (memory_read, task_router),
#   keine Write-Tools scharf schalten.
# - Bei echtem Blocker: STOP + BLOCKER-REPORT (PROBLEM/BEWEIS/URSACHE/WAS FEHLT/
#   LOESUNG mit Befehlen/WER), nicht still das Thema wechseln.
# - Nach JEDEM gefixten Punkt: inventory.json fuer die betroffene Seite neu erzeugen,
#   sodass network_or_state_actions_observed > 0 und functional_percent_observed steigt.
#
# ABLAGE DER BEWEISE: .codex/runs/CURRENT/goal-b/  (screenshots/ traces/ logs/ progress.md)

## PHASE 0 — VORAUSSETZUNGEN (zuerst, sonst kann nichts bewiesen werden)
P0.1 Playwright-MCP reparieren: `npx playwright install chrome` (oder MCP-Config auf das
     vorhandene Chromium unter ms-playwright zeigen). Danach MCP `browser_tabs list`
     erneut testen, bis es funktioniert. Beweis: erfolgreicher MCP-Call im Log.
P0.2 502-Seiten reparieren: /games, /apps, /media liefern 502 Bad Gateway. Ursache
     finden (Route/SSR-Fehler/fehlender Handler im Frontend-Container) und beheben,
     bis alle drei HTTP 200 liefern und im Browser laden. Beweis: Screenshot + Status 200.

## PHASE 1 — KERN-FUNKTIONEN VERDRAHTEN (Teil E.2/E.4, lokal, dry-run)
Reihenfolge nach Hebelwirkung. Jeder Punkt endet mit Browser-Klick-Beweis:
1. WORKBENCH RUN: "Run"/Submit im /workbench-UI an `POST /api/v1/phase2/runtime/start`
   (oder `/api/v1/live-agents/steer`) anbinden; Ergebnis/Artefakt + Terminal-Output
   sichtbar rendern. Beweis: Prompt eingeben -> Run klicken -> sichtbares Ergebnis.
2. AGENTS: Start/Reset/Status-Buttons auf /agents an Live-Agent-Steering anbinden
   (planner/coder/tester/devops, dry-run). Beweis: Button -> sichtbarer Status/Antwort.
3. ARTIFACT REGISTRY: Run-Ergebnisse als session/task-Artefakt speichern und in der UI
   listbar machen (Grundlage fuer Games/Apps/Media/Docs). Beweis: Run -> Artefakt erscheint.
4. TOOLS SAFE EXECUTE: fuer READ-ONLY MCP-Tools (memory_read, task_router) einen
   Execute-Button mit sichtbarem Ergebnis + Audit-Eintrag bauen. Beweis: Execute -> Ergebnis.
5. FILES SEARCH: Suchfeld auf /files an `GET/POST /api/v1/memory/search` (pgvector)
   anbinden. Beweis: Suchbegriff -> echte Treffer.
6. MARKETPLACE: Details-Modal + Install als echten dry-run/activate-Flow mit
   Audit-Eintrag (kein toter Button). Beweis: Install -> sichtbarer Plan/Statuswechsel.
7. GAMES/APPS/MEDIA/DOCS: die Karten an eine gemeinsame Action-Pipeline (Workbench-Modi
   + Artifact Registry aus #3) binden, statt statischer Karten. Beweis: je 1 Kernaktion
   (erzeugen/exportieren/oeffnen) bis Ergebnis.
8. SETTINGS-GATES: als read-only Owner-Gate-Plan mit explizitem disabled-Zustand ODER
   sicherer PlanOnly-Aktion umsetzen (KEINE echte Gate-Mutation). Beweis: Klick zeigt
   PlanOnly/▶disabled korrekt.

## PHASE 2 — TESTS AUF WAHRHEIT UMSTELLEN
9. E2E/Playwright-Specs von DOM-Marker-Checks auf "Nutzeraktion -> Ergebnis"-Checks
   erweitern: pro Kernfunktion ein action-to-result-Spec, das einen echten Request/State
   beweist. Beweis: gruene action-to-result-Specs + aktualisiertes inventory.json.

## ABSCHLUSSKRITERIUM (so weiss der Goal, wann er fertig ist)
- /games, /apps, /media liefern HTTP 200 (keine 502 mehr).
- Auf /workbench, /agents, /files, /tools, /marketplace zeigt das neu erzeugte
  inventory.json je network_or_state_actions_observed > 0 und functional_percent_observed > 0.
- Die Teil-B-Faelle B1, B4, B5, B7, B8 wechseln von FAIL/PARTIAL auf PASS (lokal, dry-run),
  jeweils mit Screenshot-vorher/nachher + HAR-Beweis in .codex/runs/CURRENT/goal-b/.
- progress.md fasst je Punkt zusammen: vorher -> nachher, mit Beweis-Pfaden.
- Reale Funktions-Readiness (lokal) deutlich ueber 8%; nenne die neue Zahl mit Methode.
Wenn etwas nur mit Owner/Cloud loesbar ist: als BLOCKER-REPORT auflisten, NICHT faken.

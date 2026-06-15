# GOAL E — DAS PROJEKT-ENDZIEL: ALLES ECHT FUNKTIONSFAEHIG (vollautonom)
# Mission: Aus der bewiesen bedienbaren, aber dry-run-Plattform eine Plattform machen, in der
# JEDE jemals implementierte/spezifizierte Funktion ECHT funktioniert - kein dry-run, keine
# Attrappe, keine Marker. Arbeite autonom (plan->build->REAL-test->fix) bis das maximal
# Erreichbare ohne bezahlte Infrastruktur ECHT laeuft und bewiesen ist.
#
# QUELLE DER WAHRHEIT: docs/END_ZIEL_GESAMTSPEC.md + die Feature-Matrix aus
# .codex/runs/CURRENT/total-audit/report.md (Teil D) + alle Spec-/Masterplan-Docs im Repo.
#
# ======================= EHRLICHKEIT & GRENZEN (Pflicht) =======================
# - "FUNKTIONIERT" = ein Nutzer loest im Browser eine Aktion aus und bekommt ein ECHTES
#   Ergebnis: echte LLM-Tokens, echte gespeicherte/abrufbare Datei, echtes erzeugtes Bild,
#   echtes spielbares 3D-Game-Canvas, echter Agenten-Lauf mit echtem Artefakt. NICHT:
#   "200 OK", "Marker im DOM", "dry-run geplant".
# - NIEMALS faken. Wo ein Feature wirklich bezahlte Infra/GPU oder ein Owner-Credential
#   braucht: (a) baue es VOLLSTAENDIG, sodass es in der Sekunde funktioniert, in der die
#   Ressource da ist, und (b) trage es in BLOCKERS_OWNER.md mit exaktem naechsten Schritt ein.
# - Manifest-Prozente nur durch ECHTEN, bewiesenen Fortschritt aendern.
#
# ======================= LLM: OPEN SOURCE & ECHT (Owner-autorisiert) =======================
# Der Owner autorisiert hiermit ECHTE LLM-Nutzung lokal. Implementiere im llm-gateway einen
# ECHTEN Modus (LLM_GATEWAY_MODE live) ueber den besten GRATIS/Open-Source-Weg, Prioritaet:
#   1) Lokales Open-Source-Modell, vom Gateway als OpenAI-kompatibler Endpoint bedient
#      (gratis, kein Token). Waehle ein CPU-taugliches, klein quantisiertes Open-Source-Modell;
#      Modell-Bezug zur Build-Zeit ist fuer DIESEN Zweck erlaubt (ersetzt die alte "API-only"-Regel).
#   2) Falls Hardware nicht reicht: kostenlose Inferenz-API (z.B. HuggingFace Router Free-Tier)
#      mit einem GRATIS Token, den der OWNER in die Env legt. Token NIE erfinden, NIE in Dateien
#      schreiben. Fehlt der Token: alles fertig verdrahten + in BLOCKERS_OWNER.md eine Ein-Zeilen-
#      Anleitung "setze HF_TOKEN (gratis, ohne Karte)" hinterlegen und mit dem Rest weitermachen.
# Echte LLM-Antworten muessen real durch die Workbench und durch die Agenten fliessen.
#
# ======================= SICHERHEITS-GUARDRAILS (bleiben) =======================
# - Keine Secret-WERTE in Repo/Logs/Chat/Artefakten.
# - Diese Aktionen NICHT autonom: Production-Deploy, Push auf main, Registry-Push,
#   Schreiben in EXTERNE Provider/Repos (provider_write), externe MCP-Writes (live_mcp_write),
#   Secret-Output. Lokale ECHTE Ausfuehrung (LLM, Code, Game-Build, Bild) ist erwuenscht und erlaubt.
# - Arbeite auf einem Feature-Branch, committe lokal; KEIN Push auf main/Remote.
#
# ======================= FUNDAMENT ZUERST: PUBLIC-ORIGIN-FIX =======================
# Bug: ueber oeffentliche Origin (Cloudflare-Tunnel) fehlen Grafiken/Funktionen, weil das
# Frontend auf localhost zeigt. Mach das Frontend origin-unabhaengig: relative API-/Asset-Pfade
# (keine hartkodierten http://localhost), korrekter Asset-Prefix, same-origin Requests ueber den
# nginx-Proxy auf :8081. Beweis: hinter einer fremden Origin laden Grafiken UND Aktionen.
#
# ======================= REIHENFOLGE (echte Features, je mit REAL-Beweis) =======================
# Baue in dieser Hebel-Reihenfolge; jedes Feature endet mit echtem Ergebnis + Screenshot/HAR/Datei:
# F1  ECHTE LLM-ANTWORT in /workbench: Prompt -> echte Tokens/Antwort sichtbar (kein dry-run).
# F2  ECHTE AGENTEN: planner/coder/tester/devops fuehren echte Schritte aus (echter LLM-Call,
#     echtes Datei-/Code-Ergebnis), Status live. /agents Start/Reset wirken echt.
# F3  MULTI-AGENTEN-ORCHESTRIERUNG (LangGraph): ein Auftrag wird real in Subtasks zerlegt,
#     Agenten arbeiten zusammen, Ergebnis entsteht. Organismus-Events sind ECHT (kein Replay).
# F4  ECHTE TOOLS/MCP: read-only UND (lokal) ausfuehrende MCP-Tools liefern echte Ergebnisse;
#     CLI-Aufrufe (run_bash_command, Tests) laufen real im sicheren lokalen Sandbox-Container.
# F5  SKILLS & PLUGINS: installierbare Skills/Plugins werden real registriert und sind im
#     LLM/Agenten-Werkzeugguertel echt aufrufbar (kein toter Marketplace).
# F6  FILES/MEMORY: echte pgvector-Suche, echtes Indexieren neuer Dateien, echtes Lesen/Schreiben
#     lokaler Projektdateien (im erlaubten Workspace).
# F7  3D-WEB-GAME: in /games + /workbench ein echtes Game erstellen -> echtes spielbares WebGL-
#     Canvas (Three.js), in der Vorschau lauffaehig, als Artefakt gespeichert.
# F8  BILDER: echte Bildgenerierung ueber Open-Source-Modell/Gratis-API -> echte Bilddatei sichtbar.
# F9  DOCS/EXPORT: echte Markdown/PDF-Erstellung + Download.
# F10 VIDEO/MEDIA: best-effort echt; wenn nur mit bezahlter GPU realistisch -> voll verdrahten +
#     BLOCKERS_OWNER.md (kein Fake).
# F11 3D-ORGANISMUS: pulsiert mit ECHTEN Live-Events aus F1-F3 (SSE/WS), Brain-Mapping aktiv.
# F12 CLI/Agentic: die in den Specs definierten CLI-/Agent-Workflows laufen real.
#
# ======================= NACHWEIS & FORTSCHRITT =======================
# - Pro Feature: REAL-Test (echtes Ergebnis), Beweis nach .codex/runs/CURRENT/goal-e/<feature>/
#   (screenshots/, har/, erzeugte Dateien, logs).
# - Pflege docs/REAL_READINESS.md: pro Feature ECHT_FUNKTIONIERT / TEILWEISE / BLOCKER(Grund),
#   plus eine ehrliche Gesamt-Zahl = real funktionierende Features / geplante Features.
# - Pflege BLOCKERS_OWNER.md: alles, was Owner/Bezahl-Ressource braucht, mit exaktem Schritt.
# - Am Ende: Human-Click-Proof + REAL-Result-Proof ueber alle 22 Seiten gegen localhost:8081.
#
# ======================= AUTONOMIE & ABSCHLUSS =======================
# Arbeite ununterbrochen weiter (bei Budget-Ende wird derselbe /goal neu gestartet und macht
# am offenen Feature weiter). Ziel erreicht, wenn:
# - Public-Origin-Fix bewiesen (Grafiken+Aktionen hinter fremder Origin).
# - F1-F9 + F11 ECHT funktionieren und bewiesen sind (F10 Video real ODER sauber als Owner-
#   Blocker dokumentiert), CLI/Skills/Plugins/MCP/Multi-Agenten real.
# - docs/REAL_READINESS.md zeigt die maximal ohne bezahlte Infra erreichbare Zahl, und
#   BLOCKERS_OWNER.md listet praezise, was fuer den absoluten 100%-Endausbau noch Owner/Geld braucht.
# Kein Fake-Done. Wo echte Grenze: ehrlich benennen, nicht vortaeuschen.

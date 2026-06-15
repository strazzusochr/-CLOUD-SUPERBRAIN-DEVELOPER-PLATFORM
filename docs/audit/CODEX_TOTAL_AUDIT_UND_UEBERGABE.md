# CODEX TOTAL-AUDIT & VOLLSTAENDIGE UEBERGABE
# Zweck: EIN Lauf, der ALLES offenlegt. Schluss mit "70% gruen, aber nichts geht".
# Du (Codex) lieferst ROHDATEN + BEWEISE, keine Zusammenfassung, kein Schoenfaerben.
#
# EISERNE REGELN (Verstoss = Abbruch + ehrlicher BLOCKER-REPORT):
# - Keine Secret-/Token-WERTE ausgeben (nur present=true/false + Laenge).
# - Keine neuen Features in diesem Lauf. Keine Prozentzahl aendern. Keine Mirror-Reparatur.
# - KEINE Behauptung ohne beigelegten Beweis (Screenshot-Datei / HAR-Trace / Log / Exit-Code).
# - "funktioniert" heisst: ein Nutzer fuehrt im Browser eine echte Aktion bis zum sichtbaren
#   Ergebnis aus. "Endpoint liefert 200" oder "Marker im DOM sichtbar" ist KEIN Funktionsbeweis.
# - Wo etwas nicht geht: klar "FAIL" + Ursache. Ehrlich schlaegt schoen.
# - Wenn du eine Anforderung nicht erfuellen kannst: STOP + BLOCKER-REPORT
#   (PROBLEM / BEWEIS / URSACHE / WAS FEHLT / LOESUNG mit Befehlen / WER: Codex oder Owner).
#
# ABLAGE ALLER ARTEFAKTE: .codex/runs/CURRENT/total-audit/
#   report.md  (alle Tabellen)   screenshots/   traces/ (HAR/Playwright)   logs/
#   inventory.json (Klickbarkeit)   capability.json (deine Selbstauskunft)
# Gib am Ende NUR report.md + die Pfadliste zurueck. Keine Secrets.
#
# ZUERST LESEN (binding truth), und im Report bestaetigen, dass gelesen:
#   PROJECT_STATE.md, AI_HANDOFF.md, docs/verification-register.md,
#   docs/project-progress.manifest.json, docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md,
#   docs/system-architecture.md, docs/codex-integration/autonomous-agent-roster.json,
#   alle docs/*MASTERPLAN*/Phasendokumente, AGENTS.md (global + projekt).

================================================================================
TEIL 0 — DEINE EIGENE WAHRHEIT (Selbstauskunft, ohne Werte)
================================================================================
0.1 IDENTITAET/LIMITS: aktuelles Modell + Reasoning-Effort, Kontextfenster, ob
    approval_policy dich blockiert/erlaubt, ob du im Browser SELBST navigieren &
    klicken kannst und mit WELCHEM Tool (playwright-mcp / chrome-devtools-mcp /
    keins). Wenn du es NICHT kannst: sage es klar — dann ist Teil B nicht erfuellbar
    und das ist der wichtigste Befund.
0.2 MCP-REALITAET: liste jeden konfigurierten MCP-Server und teste ihn LIVE
    (Aufruf). Tabelle: server | konfiguriert | erreichbar(ja/nein) | ein echter
    Beispiel-Call funktioniert(ja/nein) | Fehler.
0.3 TOKEN-MATRIX (NUR present/laenge/quelle, NIE Wert): OPENAI/CODEX, GITHUB_TOKEN,
    BRANCH_PROTECTION_TOKEN, GHCR_TOKEN, VERCEL_TOKEN, FLY_API_TOKEN, HF_TOKEN,
    CLOUDFLARE_API_TOKEN, GITLAB_TOKEN, GRAFANA_CLOUD_API_KEY, E2B_API_KEY.
    Je Variable: in Datei vorhanden? als $env: im VERIFIER-Prozess vorhanden?
    Platzhalter? enthaelt Whitespace? required_by_gate? Sage ausdruecklich, wenn ein
    Wert nur in C:\Users\immer\.codex\secrets/config.toml liegt, aber NICHT als
    $env: im Verifier-Prozess: "exists in local store, NOT injected into verifier".
0.4 TEST-METHODEN-GESTAENDNIS: liste exakt, womit du bisher "fertig/gruen" bewiesen
    hast (verify-phase1.ps1, verify-browser-contract.ps1, verify:runtime,
    verify:external-gates, E2E specs, gitleaks ...). Sage je Methode, WAS sie
    wirklich prueft: Health-200? DOM-Marker/Text? data-Attribut? Pixel? ODER echte
    Nutzeraktion-bis-Ergebnis? Beantworte hart: "Habe ich jemals als echter Nutzer
    im Browser eine Funktion bis zum Ergebnis ausgefuehrt? ja/nein." Wenn nein: sage es.

================================================================================
TEIL A — MANIFEST-WAHRHEIT vs. FUNKTION (jede Schicht & Phase entlarven)
================================================================================
A.1 Lies docs/project-progress.manifest.json. Fuer JEDE vertikale Schicht
    (Frontend 97, Orchestrator 99, Agent Pool 68, LLM Gateway 54, MCP Gateway 55,
    Memory 72, Observability 99) und JEDE Phase (P0..P6): erklaere, WORAUS sich die
    Prozentzahl zusammensetzt (welche Tasks/Artefakte) und WIE VIEL davon echte,
    nutzbare Funktion ist vs. nur Contract/Dokument/Spec/dry-run.
A.2 Sage fuer jede Schicht klar: was ist ECHT verdrahtet & nutzbar, was ist nur
    UI-Huelle/Spec ohne Wirkung. Mit Datei/Endpoint-Belegen.
A.3 Erklaere in einfachen Worten den Widerspruch: warum kann "70% / Schicht 99%"
    stimmen, obwohl der Nutzer KEINE Funktion ausfuehren kann?

================================================================================
TEIL B — ECHTER FUNKTIONS-BEWEIS pro Kernfunktion (Browser-Klick, lokal:8081)
================================================================================
Fuehre JEDEN Punkt als echter Nutzer im Browser gegen http://localhost:8081 aus.
Pro Punkt: (1) Screenshot vorher, (2) genaue Klick/Eingabe-Schritte, (3) ausgeloeste
Netzwerk-Requests + HTTP-Status (HAR/Trace), (4) Screenshot nachher, (5) PASS/FAIL +
Ursache. Wenn "gated/dry-run/locked": sage, WELCHES Gate/Flag es blockt und was es
braucht.
B1  WORKBENCH: Prompt eingeben -> Run -> entsteht ein echtes Artefakt? laeuft ein
    Agent? kommt Output ins Terminal? (Route /workbench)
B2  WORKBENCH 3D-GAME-PREVIEW: rendert ein echtes WebGL-Canvas (nicht leer)? FPS sichtbar?
B3  ORGANISM live: /organism + /organism?run_id=... -> echte Events/Run-State
    (PLANNING->EXECUTING...) aus /api/v1/organism/events bzw. /replay, oder statisch?
B4  AGENTS: Planner/Coder/Tester/Devops starten -> passiert real etwas? (Route /agents)
B5  TOOLS/MCP: je ein MCP-Tool (memory_read, task_router, github_mcp, filesystem_mcp,
    playwright_mcp, e2b_mcp) auswaehlen & ausfuehren -> echte Antwort? (Route /tools)
B6  LLM: echter LLM-Call ODER bewusster dry-run ueber das LLM-Gateway -> Antwort/Fehler?
B7  FILES/KNOWLEDGE + LOCAL FILES: Quelle oeffnen, pgvector-Suche, lokale Datei lesen
    -> echtes Ergebnis? (Routen /files, /files/local)
B8  MARKETPLACE: bei je 1 Skill/Agent/MCP/Model "Install"/"Details" -> passiert etwas
    oder toter Button? (Route /marketplace, 26 Eintraege)
B9  MEDIA / DOCS / APPS / GAMES: je eine Kernaktion (erzeugen/exportieren/oeffnen/
    starten) -> PASS/FAIL. (Routen /media, /docs-output, /apps, /games)
B10 OBSERVE / EVIDENCE / DIAGNOSTICS: zeigen sie echte Live-Werte oder "—/nicht
    verfuegbar/spec-only"? Woran haengt es? (Routen /observe, /evidence, /diagnostics)
B11 SETTINGS-GATES: als Admin ein Gate schalten -> aendert es echtes Verhalten oder
    nur Anzeige? (Route /settings; die 8 Gates)
B12 LOGIN/ONBOARDING: GitHub/Google/Email/Guest -> echter Flow oder dry-run? (Route /login)

================================================================================
TEIL C — KLICKBARKEITS-/FUNKTIONS-INVENTAR aller 22 Seiten
================================================================================
Crawle alle 22 kanonischen Routen (home, login, workbench, organism, organism/replay,
organism/map, agents, files, files/local, tools, marketplace, observe, games, apps,
media, docs-output, evidence, diagnostics, design-system, technology, settings,
open-source). Tabelle je Seite: #interaktive Elemente | #die real eine Aktion
ausloesen (mit Netzwerk-/State-Wirkung) | #tote/Platzhalter | funktionsfaehig %.
Schreibe inventory.json mit Belegen (Trace/Screenshot je Stichprobe).

================================================================================
TEIL D — VOLLSTAENDIGE FEATURE-MATRIX (alles, was je spezifiziert war)
================================================================================
Extrahiere aus den binding docs (ULTIMATUM_FINALE_PATCHED, system-architecture,
MASTERPLAN-Phasendokumente, manifest, roster) die KOMPLETTE Liste der geplanten
Funktionen/Optionen/Eigenschaften (Tools, Skills, LLM-Routing, MCP, Plugins, Media,
Docs, Apps, 3D-Games, Organismus-Features, Memory, Observability, Gates, Marketplace).
Eine Zeile pro Feature:
  feature | spezifiziert-in(Doc) | Status: ECHT_FUNKTIONIERT / UI_HUELLE / SPEC_ONLY /
  FEHLT | Beweis-Ref | Ursache wenn nicht | WAS FEHLT (Code/Endpoint/Gate/Token/Deploy)
  | WER (Codex/Owner) | exakter naechster Schritt.
Nichts auslassen. Wenn ein Doc fehlt/unklar: BLOCKER-REPORT statt raten.

================================================================================
TEIL E — EHRLICHE GESAMTBILANZ + KLARE TRENNUNG
================================================================================
E.1 ECHTER FUNKTIONS-READINESS in % = real funktionierende Kernaktionen / geplante
    Kernaktionen (aus Teil B+C+D). Ausdruecklich UNTERSCHIEDLICH von der Manifest-%.
    Nenne beide nebeneinander und erklaere die Differenz.
E.2 Was kann CODEX SELBST fixen (lokaler Code, UI<->Backend-Verdrahtung, echte
    Funktionen scharf schalten, Tests die echte Aktionen pruefen)? Priorisierte Liste.
E.3 Was kann NUR der OWNER (fly deploy der 3 Apps, Vercel-Env/Origins,
    Tokens als $env:/Secrets, Branch-Protection, Gates oeffnen, Budget)? Genaue Befehle.
E.4 Top-10 Hebel, nach Wirkung sortiert, um von "leere Huelle" zu "benutzbarer
    Plattform" zu kommen — je mit konkretem ersten Schritt und Owner/Codex-Flag.

================================================================================
ABSCHLUSS
================================================================================
Schreibe alles nach .codex/runs/CURRENT/total-audit/ und gib report.md + Pfadliste
zurueck. Keine Secrets, kein Fake-Done, keine Prozentaenderung. Wenn ein Teil nicht
ausfuehrbar ist (z.B. du kannst den Browser nicht steuern), sage es offen und liefere
einen BLOCKER-REPORT mit der exakten Loesung (welches MCP/Tool/Recht noetig ist).

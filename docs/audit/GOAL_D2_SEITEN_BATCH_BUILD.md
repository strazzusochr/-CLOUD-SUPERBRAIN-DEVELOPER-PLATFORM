# GOAL D2 (v2) — 22 SEITEN SEITENWEISE FERTIG BAUEN + BEWEISEN (kleine Batches)
# Pro /goal-Lauf NUR EIN Batch (3-4 Seiten) WIRKLICH fertig + per Human-Click-Proof
# beweisen (FAIL=0), dann stoppen. Naechster Batch im naechsten Lauf.
#
# QUELLEN DER WAHRHEIT:
# - docs/END_ZIEL_GESAMTSPEC.md (End-Ziel je Seite)
# - VISUELLE VORLAGE: docs/reference/  (die 3 ChatGPT-Mockups = SOLL-Design;
#   die Screenshots in docs/reference/aktuell desin = aktueller Ist-Stand)
# - page-visual-targets docs/design/page-visual-targets/NN-*.md FALLS vorhanden
# - Runtime-Contracts docs/runtime-contracts/*
#
# EISERNE REGELN: keine Secrets; kein Fake-Done; keine Manifest-%-Aenderung ohne Beweis;
# Gefahr-Gates NICHT selbst oeffnen (Owner); LLM dry-run, MCP read-only; nur localhost:8081.
# PASS nur bei STARKEM Signal (URL/Modal/Toast/Result/api-Request/Storage). Marker zaehlt nicht.
# Owner/Cloud-Bedarf -> BLOCKER-REPORT, nicht faken.
# ABLAGE je Batch: .codex/runs/CURRENT/goal-d2/<batch>/ (screenshots/, har/, report.md)

## STEP 0 — VORBEDINGUNG (einmalig, vor Batch 1)
0.0 RESYNC SELBST NACHPRUEFEN (nicht auf fremden Lauf vertrauen):
    docker compose -f docker-compose.dev.yml up -d
    curl http://localhost:8081/api/v1/clouds/layers
    MUSS aktuelle Provider zeigen (vercel/fly_io/cloudflare/huggingface/github_actions/
    ghcr/gitlab/grafana), KEIN Hetzner/GitKraken. Falls doch -> erst neu bauen
    (docker compose -f docker-compose.dev.yml down && up -d --build), dann weiter.
0.1 Pruefe, ob tools/ultimate_22_human_click_proof.mjs existiert UND K1-K6 erfuellt:
    K1 EXAKT diese 22 Routen (keine erfundenen):
       /home /login /workbench /organism /organism/replay /organism/map /agents
       /files /files/local /tools /marketplace /observe /games /apps /media
       /docs-output /evidence /diagnostics /design-system /technology /settings /open-source
    K2 STARKES PASS-Signal: URL-Wechsel ODER neues Modal ODER neuer Toast/Result-Text ODER
       echter /api|/mcp|/llm-Request ODER Storage-Aenderung. Reine innerText/htmlLength-
       Aenderung = WARN_WEAK (kein PASS) - wichtig wegen animiertem Cortex.
    K3 EINGABE-FLOWS vor FAIL: Workbench Prompt fuellen->Run; Files Suchbegriff->Suche;
       Tools read-only Tool waehlen->Execute; Marketplace Eintrag oeffnen->Install(dry-run).
    K4 Externe Links / target=_blank NICHT folgen (nur same-origin/relativ).
    K5 Klassen: PASS_ACTION_RESULT|PASS_NAVIGATION|PASS_DISABLED_EXPLAINED|WARN_WEAK|
       WARN_DECORATIVE_IMAGE|FAIL_DEAD_INTERACTIVE|FAIL_STATIC_LOOKS_CLICKABLE|
       FAIL_CLICK_ERROR|FAIL_DISABLED_UNEXPLAINED.
0.2 Falls Tool fehlt/unvollstaendig: bauen/patchen, dann Trockenlauf auf 2 Routen, Beweis ablegen.
0.3 AUDIT-STABILITAET (Pflicht, sonst Timeouts): der Dev-Frontend (Turbopack) reloadet/
    rekompiliert und brach den letzten Browser-Audit ab. Deshalb Human-Click-Proof gegen
    eine STABILE Front laufen lassen: entweder `next build && next start` (prod) ODER den
    Dev-Container erst voll kompilieren lassen und idle abwarten; HMR/Polling waehrend des
    Audits aus. Pro Route: waitUntil networkidle + kurze Settle-Zeit, Navigations-Timeout
    >= 45s, 1 Retry. Ein Turbopack-Recompile-Abort = RETRY, NICHT FAIL.

## BATCH-REIHENFOLGE (im Lauf NUR EINEN nennen)
- BATCH 1: /workbench, /organism, /agents
- BATCH 2: /tools, /files, /marketplace
- BATCH 3: /games, /apps, /media, /docs-output
- BATCH 4: /home, /login, /observe, /evidence
- BATCH 5: /diagnostics, /design-system, /technology, /settings, /open-source,
           /files/local, /organism/replay, /organism/map

## PRO SEITE IM BATCH
1. End-Ziel aus END_ZIEL_GESAMTSPEC.md lesen. VISUELLE VORLAGE aus docs/reference/ (Soll-
   Mockups). Falls docs/design/page-visual-targets/NN-*.md fehlt: aus der Referenz NEU
   erstellen, dann danach bauen.
2. Volle Ziel-UX bauen, VISUELL an die Referenz angeglichen (Layout, Glow, NeuroGlass-Dark,
   3D wo vorgesehen), Reduced-Motion + Fallback.
3. JEDES sichtbare Bedienelement genau eine Sorte:
   A) Funktion lokal vorhanden -> ECHT verdrahten (Klick -> /api dry-run/read-only ->
      sichtbares Result/Status/Toast/Panel).
   B) Noch nicht implementiert -> sichtbar disabled + Text ("Coming soon"/"Dry-run only"/
      "Requires live gate") + kein cursor:pointer.
   C) Reine Deko/Bild -> nicht klickbar wirkend (kein role/onClick/tabindex/pointer; alt/aria).
4. Keine Hetzner/GitKraken-Reste.

## VISUELLE ABNAHME (zusaetzlich zum Klick-Proof)
- Screenshot der gebauten Seite neben das Referenz-Mockup legen; sichtbare Naehe zum SOLL.
- BATCH 1 /organism: gluehender 3D-Cortex wie Referenz (Core + Hubs + Glow). Hinweis:
  Live-PULSIEREN braucht echte Events (Owner-Go-Live); im Dry-run simulierte/Replay-Events
  zeigen - klar als DEV-ONLY kennzeichnen, nicht faken.
- BATCH 4 /home: gluehendes 3D-Hirn-Hero wie Referenz (DEV-ONLY/gated, kein Fake-Stat).
- WORKBENCH-Sondercheck (Batch 1): Datei oeffnen->Editor zeigt Inhalt; Run->Terminal/Result;
  Preview-Tabs (Game/App/Video/Doc/3D) schalten sichtbar; Agent-Assistance zeigt Schritte;
  Mini-Cortex zeigt Run-State. Jeweils Screenshot+HAR.

## NACH DEM BAU
5. Human-Click-Proof NUR ueber die Batch-Routen laufen lassen.
6. report.md + screenshots + har. EHRLICHE Readiness je Seite =
   (PASS_ACTION + PASS_NAV) / (alle klickbar-aussehenden Elemente).

## ABSCHLUSSKRITERIUM (pro Batch-Lauf)
- Jede Batch-Seite: HTTP 200, Ziel-UX vollstaendig & visuell nah an der Referenz,
  Human-Click-Proof FAIL=0, jedes Element sauber klassifiziert.
- Visuelle Abnahme-Punkte (Cortex/Home/Workbench wo im Batch) mit Screenshot belegt.
- report.md nennt ehrliche Readiness je Seite + verbleibende Owner/Cloud-Blocker.
Toter Button nur wegen Owner/Cloud-Gate -> sichtbar "Requires live gate" + BLOCKER-REPORT.

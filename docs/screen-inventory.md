# Screen Inventory

Stand: 2026-08-02
Status: kanonische 22-Routen-Inventur
Quelle: `apps/frontend/lib/nav.tsx`, `apps/frontend/lib/actionMatrix.ts`,
`apps/frontend/lib/workspaceWiring.ts`

## Zweck

Dieses Inventar bildet genau die 22 Workspace-Routen ab. Klickbarkeit und
Substanz sind getrennte Aussagen: Der aktuelle lokale Browserreport belegt
22/22 Routen, 29/29 aktivierte Familien und 161/161 aktivierte Aktionen, aber
nicht automatisch Hosted-Parität oder eine Live-Wirkung hinter jeder Fläche.

| # | Page-ID | Route | Layer | Produktkern | Aktueller Rand |
| ---: | --- | --- | --- | --- | --- |
| 1 | `home` | `/home` | FE | Einstieg, Cortex-Hero, Build | lokaler Live-Gateway-Build belegt; Hosted Source-Parität offen |
| 2 | `login` | `/login` | FE | Gast-Session und Identität | Gast lokal echt; Production OAuth OWNER-BLOCKED |
| 3 | `workbench` | `/workbench` | FE | Prompt, Build, Preview, Artefakt | lokaler Prompt→Provider→Persistenz-Fluss echt; Hosted-Parität offen |
| 4 | `organism` | `/organism` | FE | 3D-Cortex, Inspector, Run-State, Hubs | 3D/Controls/Visual-v2 lokal echt; Cloud-Telemetrie nur teilweise gebunden |
| 5 | `organism-replay` | `/organism/replay` | OBS | Events, Replay-Frames, Run-/Hub-Controls | Zielvertrag sichtbar; ohne gebundenen Run ist Fallback/Contract möglich |
| 6 | `organism-map` | `/organism/map` | FE | Topologie, Filter, Auswahl, Nachbarschaft | strikt validierter read-only Vertrag; `live=false` |
| 7 | `agents` | `/agents` | AP | Vier Rollen und Ergebnisprojektion | gebundene Analyse und begrenzter O4-Write; keine allgemeine autonome Lieferung |
| 8 | `files` | `/files` | MEM | Suche und Gedächtnis | lexikalisch lokal sowie D1/Vectorize im begrenzten Hosted-Scope belegt |
| 9 | `files-local` | `/files/local` | MEM | lokaler Dateibaum | interaktive Spezifikation; kein Host-Dateisystem-Mount |
| 10 | `tools` | `/tools` | MCP | Toolkatalog, Safe-Envelope, Audit | interne Read-only-Tools echt; externe Adapter überwiegend contract/dry-run |
| 11 | `marketplace` | `/marketplace` | LLM | Modelle/Skills/Tools durchsuchen | Details und Installationsplan; keine echte Paketaktivierung |
| 12 | `observe` | `/observe` | OBS | Health, Metriken, Kosten, Rotation | Basisdaten/OTLP begrenzt echt; vollständige Trace-/Dashboard-UX offen |
| 13 | `games` | `/games` | AP | Game-Vorlagen, Build, Preview, Bibliothek | lokale Wirkung und Gateway-Build; kein vollständiger Cloud-Lifecycle |
| 14 | `apps` | `/apps` | AP | App-Vorlagen, Buildliste, Preview | lokale Wirkung; Test-/Deploy-Lifecycle offen |
| 15 | `media` | `/media` | LLM | Browser-Medien, Aufnahme, Download | echte Browserfunktionen; keine behauptete KI-Medienpipeline |
| 16 | `docs-output` | `/docs-output` | MEM | Markdown, Preview, Download | lokal echt; PDF/Zitate/Hosted-Persistenz offen |
| 17 | `evidence` | `/evidence` | OBS | Claims, Artefakte, Verifierstatus | read-only Projektion; führt bewusst keine Verifierjobs aus |
| 18 | `diagnostics` | `/diagnostics` | OBS | Audit, Fehler, Archive, Recovery-Links | read-only Diagnose; Restore-Wirkung offen |
| 19 | `design-system` | `/design-system` | FE | NeuroGlass-Tokens, Typografie, Komponenten | CSS-Tokenquelle gebunden; Figma-/22-Seiten-Pixelabnahme offen |
| 20 | `stack` | `/technology` | ORC | Layer-/Provider-/Preflight-Verträge | fail-closed Runtimeprojektion; Hosted Provider-Parität offen |
| 21 | `settings` | `/settings` | MCP | Gates, Rollen, Governance | Plan/Contract; Apply OWNER-BLOCKED |
| 22 | `open-source` | `/open-source` | FE | Quellcode-/Lizenzinventar | keine Root-Lizenz; Lizenzwahl OWNER-BLOCKED |

## Verifikationsregeln

1. `WORKSPACE_PAGES` bleibt die alleinige Routenquelle und enthält exakt 22
   eindeutige Einträge.
2. Jede Route besitzt eine reale `page.tsx`, einen Wiring-Eintrag, ein visuelles
   Ziel und einen Action-Matrix-Eintrag.
3. Aktivierte Controls müssen einen direkten Effekt oder exakt gebundene
   Vorabevidenz besitzen; Spec-/Contract-/Provider-Gates werden separat gezählt.
4. Localhost-Beweise tragen immer `DEV-ONLY; hosted proof still blocked`.
5. Production-, Secret-, Provider-, Registry- und Write-Gates werden nie durch
   eine UI-Projektion geschlossen.

`MARKET_READY:false`; Lizenz-, OAuth-, Scale-, Registry- und Hosted-Source-
Entscheidungen bleiben außerhalb dieser Inventur.

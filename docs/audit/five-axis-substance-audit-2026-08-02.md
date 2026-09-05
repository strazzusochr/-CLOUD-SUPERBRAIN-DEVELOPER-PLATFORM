# Fünf-Achsen-Substanzaudit

Stand: 2026-08-26
Scope: 22 Seiten · L4/L5 · autoritative Docs-Endpunkte/Services · halbfertiger
Produktcode · Inspector/Replay/NeuroGlass
Fortschrittswirkung: **0 Prozentpunkte**
Marktreife: **`MARKET_READY:false`**

## Ergebnis

Die fünf Achsen sind sequenziell inventarisiert. Nur Browserwirkungen und
manifest-/artefaktgebundene Werte gelten als gemessen; Route-Kategorien,
Quellinventare und Design-Tokens bleiben ausdrücklich deklarative Audits:

- **11 ECHT NUTZBAR** im jeweils genannten Scope,
- **10 NUR CONTRACT**,
- **1 SPEC/STUB**,
- **0 FEHLT/BROKEN** als Route.

Der lokale Real-Chromium-Beweis meldet 22/22 Routen, 29/29 aktivierte
Familien, 161/161 aktivierte Aktionen, 160 direkte Effekte und exakt einen
source-gebundenen Vorabbeweis. Er enthält zwei erlaubte Live-Gateway-
Buildantworten, null unerwartete Provideraufrufe, null Mocks, null
Request-Interception, null tote/unregistrierte Aktionen und keinen Secret-
Output. Das belegt Bedienbarkeit, nicht automatisch Hosted-Parität oder die
volle Wirkung jeder beworbenen Funktion.

**Messgrenze:** Der Action-Report misst Bedienwirkungen. Die Route-Kategorie
ist eine dokumentierte Auditbewertung, der Endpoint-/Routenabgleich ist statisch,
und die Organismus-Optik besitzt ohne Screenshotvergleich plus Owner-Abnahme
keinen Fertig-Beweis.

`DEV-ONLY; hosted proof still blocked`.

## Methode

1. Kanonische Routen aus `apps/frontend/lib/nav.tsx` gegen reale
   `page.tsx`-Dateien, Action Matrix und aktuellen Browserreport gespiegelt.
2. Für jede Route die beworbene Hauptwirkung gegen benannte UI-, API- und
   Laufzeitevidenz als Auditbewertung klassifiziert; die Kategorie selbst ist
   kein automatisch gemessener Prozent- oder Release-Beweis.
3. L4/L5 gegen Manifest, Implementierung, O4/O6-Evidenz und den leeren,
   verifier-gesperrten Delta-Ledger geprüft.
4. Alle Endpoint-Tokens in den vier autoritativen Quellen statisch gegen
   deklarierte FastAPI/Hono-Routen und nginx-Gatewaypräfixe verglichen.
5. Getrackte Produktquellen ohne Tests/Buildoutputs auf strikte
   `TODO`/`FIXME`/`HACK`/`NotImplementedError`/`not_implemented`-Marker und
   ungemountete Scaffolds geprüft.
6. Inspector-/Replay-Bedienwirkung aus dem echten Browserreport geprüft.
   Design-Tokens werden nur als deklarierte Source-Inventur geführt. Keine Optik-Verifikation aus Quelltext-Markern; nach R-VIS-1 braucht jede
   sichtbare Fertig-Behauptung Screenshot, benannte Referenz und Owner-Abnahme.

Reproduzierbarer Guard:

```powershell
npm run verify:five-axis-audit
```

## Achse 1 — 22 Seiten: Klickbarkeit gegen Substanz

| # | Route | Reale Hauptwirkung | Urteil | Ehrlicher Rest |
| ---: | --- | --- | --- | --- |
| 1 | `/home` | Eigener lokaler Prompt→Gateway→Live-Provider→persistierter Build sowie Cortex-Hero und Navigation | **ECHT NUTZBAR — DEV-ONLY** | Hosted Source-/Persistenzparität |
| 2 | `/login` | Signierte Gast-Session, Sessionread und Logout lokal | **ECHT NUTZBAR** für Gast | Production OAuth ist OWNER-BLOCKED; Google/E-Mail nicht live |
| 3 | `/workbench` | Prompt→Gateway→Workers AI→HTML→PostgreSQL/Audit→Run/Reload | **ECHT NUTZBAR — DEV-ONLY** | vollständige IDE/Terminal-/Hosted-Artefaktparität |
| 4 | `/organism` | R3F/three.js, GLB/Fallback, Kamera, Gameplay, Save/Clear, Accessibility und echte Feedprojektion | **ECHT NUTZBAR — DEV-ONLY** | Optik-Referenzabnahme und vollständige Live-Agenten-/MCP-/OTel-Telemetrie |
| 5 | `/organism/replay` | Eventfeed, Replay-Frames, Run-State- und Hub-Controls sind sichtbar/bedienbar | **NUR CONTRACT** | ohne gebundenen Run ist redaktierter Spec-Fallback zulässig; kein vollwertiger persistierter Player |
| 6 | `/organism/map` | 245 Knoten/494 Kanten, Filter, Auswahl und Nachbarschaft aus strikt validiertem Vertrag | **NUR CONTRACT** | Vertrag setzt `live=false`; keine echte Cloud-/Agententelemetrie |
| 7 | `/agents` | Vier getrennte, quellengebundene Planner→Coder→Tester→DevOps-Analysen; begrenzter O4 Agent→MCP-Write existiert | **NUR CONTRACT** für die beworbene Agentenlieferung | UI-Pipeline bleibt `analysis_only`; keine allgemeine Code-/Test-/Deploy-Lieferung |
| 8 | `/files` | lokale Memory-Suche plus begrenzte Hosted-D1-/Vectorize-Semantik | **ECHT NUTZBAR** im gebundenen Scope | kein allgemeiner Knowledge-Graph/Dateisystemkatalog |
| 9 | `/files/local` | lokaler Filter, Auswahl, Vorschau und Copy auf statischem Baum | **SPEC/STUB** | `host_filesystem_mounted=false`, keine Live-Filesystem-Reads |
| 10 | `/tools` | interne Read-only-Tools mit Safe-Envelope/Audit-ID; O4-Dateiwrite mit Pre-/Post-Audit, Readback und Rollback | **ECHT NUTZBAR — DEV-ONLY** begrenzt | allgemeine externe Adapter bleiben contract/dry-run; Writes allowlist-/owner-gegatet |
| 11 | `/marketplace` | Browse, Auswahl, Details und persistierbarer Installationsplan | **NUR CONTRACT** | ausdrücklich Install-Dry-run; keine Paketinstallation/-aktivierung |
| 12 | `/observe` | lokale Health-/Audit-/Metrikwerte und begrenzte Hosted-OTLP-Ingestion | **NUR CONTRACT** als Gesamtprodukt | keine vollständige Trace-, Dashboard-, Alert- oder Langfuse-UX |
| 13 | `/games` | Vorlagen, lokaler Build, Preview, Bibliothek/History und Öffnen-Pfade | **ECHT NUTZBAR — DEV-ONLY** | kein vollständiger Cloud-Projekt-/Deploy-Lifecycle |
| 14 | `/apps` | Vorlagen, Buildliste, Auswahl, Preview und Öffnen-Pfade | **ECHT NUTZBAR — DEV-ONLY** | keine vollständige Datei-/Test-/Deploy-Pipeline |
| 15 | `/media` | echte browserlokale Audio-/Video-/Aufnahme-/Downloadfunktionen | **ECHT NUTZBAR — DEV-ONLY** | keine als live behauptete KI-Medienpipeline oder Hosted-Library |
| 16 | `/docs-output` | Markdown-Editor, Preview, Store-Ausgabe und Download | **ECHT NUTZBAR — DEV-ONLY** | PDF, Zitate und Hosted-Persistenz offen |
| 17 | `/evidence` | read-only Claims, Artefakte, Integrität und Verifierstatus | **NUR CONTRACT** | führt absichtlich keine Verifierjobs aus |
| 18 | `/diagnostics` | read-only Audit-, Fehler-, Archiv- und Evidence-Navigation | **NUR CONTRACT** | kein kontrollierter Restore-/Recovery-Effekt |
| 19 | `/design-system` | zwölf echte CSS-Farbtokens, Typografie, Komponenten und tokengebundene Swatches | **ECHT NUTZBAR** als Referenzfläche | keine Figma-Quelle oder 22-Seiten-Pixel-/Visual-Regression |
| 20 | `/technology` | drei fail-closed validierte Runtime-/Provider-/Preflight-Verträge | **NUR CONTRACT** | Provider- und Kandidatenparität bleibt extern/source-gebunden |
| 21 | `/settings` | Rollen-, Gate- und Governanceplan sichtbar | **NUR CONTRACT** | Apply bleibt OWNER-BLOCKED und write-frei |
| 22 | `/open-source` | ehrliche Quellcode-/Upstream-Lizenzinventur | **NUR CONTRACT / OWNER-BLOCKED** | keine Root-`LICENSE`, keine Projektlizenz, kein SBOM-Compliance-Beweis |

Die Klassifikation ist bewusst strenger als der Action-Report. Eine Route kann
vollständig klickbar und dennoch `NUR CONTRACT` sein.

## Achse 2 — L4 55 % und L5 56 %

### L4 LLM Gateway

Echt vorhanden:

- OpenAI-kompatible Chat- und Responses-Endpunkte,
- Routing-/Policy-/Providerstatus-/Streamingverträge,
- Gateway-only Browsergrenze,
- begrenzter Cloudflare-Workers-AI-Livepfad mit echter Buildantwort,
- O6 source-gebundene read-only Hosted-Parität.

Nicht als volle L4-Wirkung belegt:

- Standardmodus bleibt `deterministic_dry_run`, wenn der ausdrückliche
  DEV-LIVE-Modus nicht gesetzt ist,
- keine vollständig live verifizierte Modellflotte,
- kein allgemein bewiesenes dynamisches Multi-Provider-Failover samt
  Budgetwirkung,
- Responses-Streaming ist nicht als Live-Ende-zu-Ende-Pfad belegt,
- kein neuer vertrauenswürdiger Prozent-Delta-Vertrag.

**L4 bleibt 55 %.** O6 ist real, aber ausdrücklich ohne Prozentcredit. Die
fehlenden 45 Punkte sind im v1-Manifest nicht einzeln rubriziert; sie dürfen
nicht aus vorhandenen Features rückwärts erfunden werden.

### L5 MCP Gateway

Echt vorhanden:

- Safe-Envelopes mit Scope, Timeout, Audit und Versionspins,
- interne Read-only-Ausführung für die gebundenen Tools,
- O4: exakt begrenzter Agent→MCP-Dateiwrite im Projektroot/Branch mit
  Branchschutz-Read, Pre-/Post-Audit, Readback, Fail-closed-Rollback und
  Browserbeweis,
- source-gebundene Hosted-Read-only-Vertragsparität.

Nicht als volle L5-Wirkung belegt:

- GitHub, PostgreSQL, allgemeines Filesystem, Playwright und E2B liefern im
  allgemeinen Adapterpfad weiterhin `dry_run_contract_only`,
- keine allgemeine externe Provideraktion,
- keine beliebigen Tool-/Agent-Writes,
- keine Freigabe zur Scope-Erweiterung,
- kein neuer vertrauenswürdiger Prozent-Delta-Vertrag.

**L5 bleibt 56 %.** O4 kreditiert ausschließlich L3. Die fehlenden 44 Punkte
sind im v1-Manifest nicht einzeln rubriziert; ein Prozentanstieg wäre ohne
neuen Vertrag Fake-Done.

`docs/runtime-state/project-progress-delta-ledger.json` bleibt deshalb korrekt
bei exakt null Einträgen.

## Achse 3 — Docs-Versprechen gegen Code

Geprüfte autoritative Quellen:

1. `PROJECT_STATE.md`
2. `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`
3. `docs/CLOUD_SUPERBRAIN_ULTIMATUM_GPT55_PATCHED_2026-04-29.md`
4. `docs/system-architecture.md`

Ergebnis der Endpoint-Inventur:

| Token | Statische Klasse | Begründung |
| --- | --- | --- |
| `/api/v1` | `NAMESPACE-ONLY` | Gemeinsamer Namespace, kein einzelner Handler. |
| `/llm/v1` | `NAMESPACE-ONLY` | OpenAI-kompatibler Basis-Namespace hinter der Nginx-Grenze `location /llm/`; die konkreten Handler sind `/llm/v1/chat/completions`, `/llm/v1/responses` und `/llm/v1/models`. Der nackte Prefix ist eine Basis-URL, kein Handler. |
| `/api/v1/model-capabilities` | `NEGATIVE-ONLY` | Dokumentierter verbotener Altalias; die echte Route ist `/api/v1/models/capabilities`. |
| `/mcp/internal` | `NEGATIVE-ONLY` | Öffentliche Nginx-/Vercel-Grenzen müssen diesen internen Teilbaum mit `404` verbergen. |

- Der Verifier berechnet die Zahl der eindeutigen Endpoint-/Namespace-Tokens
  bei jedem Lauf neu und druckt sie aus; feste Literale sind kein Messwert.
- Aktuelle Tokens müssen statisch einer deklarierten FastAPI/Hono-Route oder
  dem nginx-Präfixrouting `/mcp/...` beziehungsweise `/llm/...` entsprechen.
- `/api/v1` ist nur der Namespace.
- `/api/v1/model-capabilities` ist absichtlich nicht implementiert und
  erscheint ausschließlich als dokumentierter, verbotener Altalias; die
  echte Route ist `/api/v1/models/capabilities`.
- Ungelöste aktuelle Endpoint-Tokens lassen den Guard fehlschlagen.

**Endpoint-/Routenabgleich ist statisch.** Er beweist deklarierte
Source-Konsistenz, aber weder HTTP-Erreichbarkeit noch Hosted-Parität. Diese
Behauptungen brauchen getrennte Runtime-/Hosted-Beweise.

Service-Abgleich:

- sechs Applikationsimages besitzen echte Dockerfiles: Frontend, Agent API,
  Agent Worker, Memory Worker, MCP Gateway und LLM Gateway,
- PostgreSQL, Redis und nginx sind in Dev- und Cloud-Compose sichtbar;
  `local-llm` ist nur der Dev-Fallback, Caddy nur der Cloud-Edge-Service,
- `cloudflare-stateful-runtime` und `cloudflare-llm-gateway` besitzen eigene
  Sourceverzeichnisse und getrennte Hosted-Gates,
- kein fehlender aktiver Build-Context wurde gefunden.

Bereinigte Dokumentdrift:

- `AGENTS.md` nennt jetzt die tatsächlich installierte Next.js-Version
  16.2.11 statt der früheren 15er-Baseline,
- `LAYER_MATRIX.md` verwendet jetzt das kanonische L1-Frontend-bis-L7-
  Observability-Mapping und Next.js 16.2.11,
- `docs/screen-inventory.md` enthält jetzt exakt die 22 kanonischen Routen
  statt sieben Phase-0-Entwürfen.

Außerhalb dieser Endpointprüfung bleiben historische/superseded Dokumente
historisch. Sie sind keine aktuellen Runtime-Versprechen.

## Achse 4 — Halbfertiger Produktcode

Der getrackte Produktpfad (`apps/frontend/**`, `services/**`, ohne Tests,
E2E, Dependencies und Buildoutputs) enthält:

- 0 strikte `TODO`-/`FIXME`-/`HACK`-Marker,
- 0 `NotImplementedError`,
- 0 `not_implemented`-Marker,
- 0 der zuvor ungemounteten Probe-/Dry-run-Scaffolds.

Autonom bereinigt:

- irreführender Fallbackgrund
  `agent_api_build_registry_unavailable_or_not_implemented` auf den realen
  Zustand `agent_api_build_registry_unavailable` reduziert,
- sieben ungemountete Scaffolds entfernt,
- Open-Source-/Compliance-Falschclaims entfernt; Lizenzwahl sichtbar
  OWNER-BLOCKED gemacht.

Absichtlich unvollständige, aber ehrlich markierte Produktgrenzen bleiben:

- `/files/local`: Spec-only, kein Host-Filesystem-Mount,
- `/marketplace`: Installationsplan, keine Installation,
- `/settings`: Plan-only, kein Apply,
- `/agents`: Hauptpipeline `analysis_only`,
- allgemeine externe MCP-Adapter: `dry_run_contract_only`,
- Replay-Frames: Contract-Fallback ohne gebundenen Run zulässig.

Diese Grenzen sind Produktlücken, keine versteckten Code-Stubs.

## Achse 5 — Ziel gegen Realität

### Inspector

Vorhanden: ausgewählter Hub, Detailpanel **Inspektion**, Schicht/Region/Status,
Hub-Navigation und source-markierte Runtimeprojektion.

### Replay

Das aktuelle Functional Target verlangt Cortex-Fläche, Runtimeeventfeed,
Replay-Frames, Run-State- und Hub-Controls. Diese Funktionsflächen sind
browsergemessen. Nicht vorhanden ist ein vollwertiger, persistierter
Timeline-Player mit Scrubbing über beliebige historische Runs; das wird nicht
behauptet.

### Organism Visual v2

Organismus-Optik: **OWNER-ABNAHME OFFEN**.

Die Funktionskette und die Canvas-Bedienung sind gemessen. Nicht bewiesen ist,
dass der gerenderte Cortex der benannten Masterreferenz entspricht. Frühere
`data-visual-*`-Marker, Komponentenamen und Quelltext-Tokens sind nach R-VIS-1,
R-SELF-2 und R-SELF-3 kein visueller Fertig-Beweis. Maßgeblich bleiben
`REGELN_OPTIK_UND_FERTIG.md`, die benannte Referenz, ein aktueller Screenshot
und die ausdrückliche Owner-Abnahme. Bis dahin lautet der Status
`OWNER-BLOCKED`, nicht `verified`.

### NeuroGlass

Zwölf CSS-Farbtokens und tokengebundene Swatches sind statisch deklariert.
Diese Source-Inventur beweist weder Sichtbarkeit noch Referenztreue. Offen
bleiben Screenshot-/Pixelvergleich, Figma-Quelle, vollständige WCAG-Abnahme
und 22-Seiten-Visual-Regression.

## Externe Wände und nächste Kette

Das Audit schließt keine Owner-Gates. Für echte 100 % bleiben:

1. Hosted Candidate Parity über eine echte schreibfähige Owner-Identität; der
   aktuelle Preview-Produktlauf stoppt korrekt an dieser Grenze.
2. Owner-Architekturentscheidung und Production-OAuth-Identität für P3.
3. Owner-bereitgestelltes `AGENT_API_AUTH_TOKEN`; danach der gegatete
   900-Request-Scale-Beweis für P6.
4. Owner-Entscheidung zum GHCR-Zyklus/Required-Reviewer-Setup für P5.
5. Owner-Lizenzentscheidung vor jeder Open-Source-/Fork-/Weitergabe-Behauptung.
6. Owner-Abnahme der Organismus-Optik gegen die benannte Referenz; ohne
   Prozentwirkung, aber erforderlich für eine Optik-Fertig-Behauptung.
7. Nach dem letzten Runtime-Source-Commit O4 Runtime- und Browserproof zuletzt
   erzeugen, dann erst die fünf Qualifikationsketten und den Market-Ready-
   Verifier ausführen.

Keine Zahlung ist erforderlich oder autorisiert. Kein Deploy, Registry-Push,
Secret-Output, Default-Branch-Write oder Scope-Expand wurde durch dieses Audit
ausgeführt.

## Schlussurteil

Die zuvor unbekannten Achsen sind nicht mehr unbekannt: 22/22 Routen existieren
und sind bedienbar, aber nur 11 besitzen im beworbenen Kern bereits echte
Wirkung. L4/L5 enthalten mehr reale Substanz als reine Prozentzahlen zeigen,
doch der aktuelle Ledger erlaubt ehrlicherweise keinen zusätzlichen Credit.
Alle aktuellen autoritativen Endpoint-Tokens sind statisch an deklarierte
Routen gebunden; Runtime- und Hosted-Erreichbarkeit bleiben getrennte
Beweisklassen. Die verbleibenden Lücken sind sichtbar als Contract, Spec,
Dry-run oder OWNER-BLOCKED markiert.

**`MARKET_READY:false` — DEV-ONLY; hosted proof still blocked.**

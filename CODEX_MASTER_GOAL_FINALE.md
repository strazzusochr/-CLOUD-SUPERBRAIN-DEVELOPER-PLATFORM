# 🏁 CODEX MASTER GOAL — FINALE (bis Vollendung + fehlerfreier Beweis)
# Version: 2026-07-20 (T1 Production-Betriebsreparatur verifiziert)
# Führt CODEX_MASTER_GOAL.md zu Ende. Dieses Dokument ist der aktuelle Einstieg.

## DAS ZIEL IN EINEM SATZ
Cloud Superbrain vollständig fertigstellen und **fehlerfrei beweisen**: alle 22 Seiten
produktreif, echtes Free-Backend live, 3D-Organismus mit echten Events, alle External
Gates verified — dokumentiert mit Artefakten, ohne Fake-Done, bis wirklich nichts Offenes
mehr übrig ist außer nachweislich Owner-only-Punkten.

## MODUS: ZIEL-PERSISTENZ
Status lesen (`.codex/runs/CURRENT/master-goal/status.md`) → ersten NICHT-grünen Punkt
weiterarbeiten → PASS nur mit Artefakt → Haken + Evidence-Pfad → nächster. Bei FAIL:
Ursache finden, fixen, erneut beweisen. Stuck >3 Versuche am selben Fehler: Ansatz wechseln,
im Status begründen — aber weiterarbeiten. Kein vorzeitiger Stop, kein Loop ohne Fortschritt.

## HARTE REGELN (unverändert)
1. **No-Fake-Done / No-Fake-Live** — nur echte Antworten/Screenshots zählen; ehrliche
   Projection bleibt ehrlich gelabelt (`frontend-projection`, `live:false`). Diese Labels
   NIE zurückdrehen, um einen Test zu befriedigen — stattdessen den Test erweitern.
2. **No Secrets** — Tokens nur aus `C:\Users\immer\.claude\secrets\cloud-superbrain.local.env`
   transient laden, presence-only loggen, nie Werte ausgeben/committen. (Konvention:
   `BRANCH_PROTECTION_TOKEN` = `GITHUB_TOKEN`.)
3. **Free-Only** — kein Fly-Deploy, nichts Bezahltes. Owner-Freigabe deckt
   `vercel deploy`/`vercel env` fuer die zwei bestehenden Projekte, Commits, read-only
   Gate-Audits und Push ausschliesslich auf `claude/cloud-superbrain-analysis-127d2e`.
   Kein Force-Push und kein Main-Push. Ein scoped Betriebs-Deploy darf nach seinem
   dokumentierten Gruen-Gate reparieren; Release-Candidate-Promotion bleibt bis
   `MARKET_READY: true` verboten.
4. **Localhost = DEV-ONLY** — jeder Hosted-Beweis ist HTTPS non-localhost, kein `-AllowLocalhost`.
5. **UI-Checks nur mit Playwright nach Hydration.** Proof-Tool: `node tools\ultimate_22_human_click_proof.mjs`
   IMMER aus PowerShell starten (Git-Bash zerstört `/routen`-Argumente).
6. **Kein Deploy, während ein Hosted-Proof läuft** (invalidiert den Beweis).
7. Budget: Workers AI 10.000 Neurons/Tag → LLM-Beweise = 1 Mini-Prompt.

## VERIFIZIERTE BASELINE (2026-07-20 — nicht neu herleiten, nur fortführen)
- **Frontend Production** `https://frontend-seven-psi-78.vercel.app`:
  `frontend-hosted-current-proof-v1` bindet READY Production Deployment
  `dpl_9KPqcjNPnV9irpJ9W8tyjff8LMbX` an Source
  `21913f8c3ef13949ca962980c143e757ca87a7cc` und Archiv-SHA-256
  `314bd1d9c7830dc5ac9077398025fed4ab48041b31fefae491916e838d5f7080`.
  Echtes Google Chrome `148.0.7778.96` bestand 22 Desktop- und 22 Mobile-Routen
  mit 44 Klicks, vier PNGs, Overflow 0, Overlay-Kollisionen 0 und Console Errors 0.
  Der 32-Read-Sweep lieferte durchgehend HTTP 200, inklusive aller acht ehemaligen
  HTTP-500-Routen; immutable/Alias-Inhalte sind bytegleich. Evidence:
  `.codex/runs/CURRENT/master-goal/production/t1-21913f8c`; Frontend `100%`.
- **Backend Production Contract Origin**
  `https://cloud-superbrain-developer-platform.vercel.app`:
  `backend-hosted-current-proof-v1` bindet READY Production Deployment
  `dpl_AQaBJxdQwHLcQKid8xYXkNJ3wva2` an dieselbe Source und denselben Archivhash.
  Die immutable URL bleibt deployment-geschuetzt; Alias-Reads belegen `overall=84`,
  `P4=100`, Integritaet `verified`, External Gates `5/6 action_required`, Blocker
  `fly_cloud_stack`, MCP/LLM `healthy`, Agent API `degraded` und App-POST HTTP 503
  `stateless_contract_origin_read_only`. Dies ist ein scoped Betriebs-Deploy des
  zustandslosen Contract Origin, nicht der stateful Docker-Stack oder ein Plattform-Release.
- **External-Gate-Wahrheit:** Der kanonische reproduzierbare Standard-Bootstrap-Audit (ohne
  Owner-Origin-Injektion) `.phase1-artifacts/external-gate-audit-20260720-191532.json` ist
  `blocked` mit `production_deploy_claim_allowed=false`; offen ist nur noch
  `fly_live_budget_check` (Fly.io verlangt Zahlungsdaten - Owner-Wand unter Free-Only).
  `hosted_agent_api_contracts`, `vercel_backend_origin_health` und
  `github_branch_protection_current_verify` sind seit Audit `20260720-191532` tokenfrei
  reproduzierbar `verified`: die oeffentlichen Vercel-Origins sind als nicht-geheime
  Defaults im Verifier hinterlegt, und die Branch-Protection wird auf dem oeffentlichen
  Repository anonym als `protected=true` mit Pflicht-Check `verify` belegt
  (`verification_scope=public_anonymous_subset`; Review-/Force-Push-/Deletion-Settings
  sind anonym nicht lesbar und werden ausdruecklich NICHT beansprucht - dafuer bleibt
  `BRANCH_PROTECTION_TOKEN` die staerkere Pruefung). Jede Probe bleibt eine anonyme
  HTTPS-GET mit Pflicht-Marker und faellt bei Drift wieder fail-closed. Der
  owner-assistierte Token-/Origin-Lauf `.phase1-artifacts/external-gate-audit-20260713-125413.json`
  meldete `verified` mit `production_deploy_claim_allowed=true`, wird aber gemaess R0 ausschliesslich
  als nicht-aktueller Kandidat gefuehrt (`docs/runtime-state/external-gate-summary.candidate-125413.json`)
  und ersetzt niemals den Standard; bestehende Credentials wurden nur transient geladen, ohne Ausgabe,
  Persistenz oder Audit-seitige Provider-Mutation. Das bindende Manifest steht bei
  `overall=84`; das Frontend ist bereitgestellt, die Backend-Gesamtplattform wurde nicht
  als Production Release ausgerollt.
- **R0 Runtime-Bindung:** Die lokalen Runtime-Endpunkte fuer External Gates, Mirror,
  Deployment Preflight, Completion und Go-live Readiness lesen die kanonische Summary und
  zeigen den Standard deshalb einheitlich als geblockt. `npm run verify`,
  `npm run verify:runtime` und `npm run verify:browser` sind gruen; letzterer umfasst 22
  Seiten, zwei Viewports und 44 Klicks ohne Overflow-, Overlay- oder Console-Fehler.
  Evidence: `.codex/runs/CURRENT/master-goal/r0-canonical-runtime-truth-20260719.md`.
- **T4 Frontend-Providergrenze:** Direkte Neon-, Cloudflare- und GitHub-Store-Pfade im
  Frontend sind entfernt. Acht Action-Routen nutzen nur Agent API, LLM Gateway oder MCP
  Gateway und bleiben ohne konfigurierte Grenze fail-closed; drei Vercel-Wrapper bleiben
  zustandslos und read-only. Static-, Runtime-, Browser-, Lint- und Build-Gates sind gruen.
  Evidence: `.codex/runs/CURRENT/master-goal/t4/frontend-provider-boundary/report.json` und
  `.codex/runs/CURRENT/master-goal/production/t1-21913f8c`.
  Overall bleibt `84%`; Release-Promotion und Live-Provider-Aktivierung sind unbeansprucht.
- **Phase 1 ✔ (1.1–1.5), Phase 2 ✔ (2.1–2.3).** Class-Matrix A=85/B=0/C=5/D=4.
- **Phase 3 deployt (~80 %):** S1 Build-Log-Grid, S2 Media/Docs-Entflechtung,
  S3 Apps-Kuration, S4 ehrliche Idle-Texte, S5 Hero-Labels, S6 /observe-Ehrlichkeit,
  S8 Agents-Zielarchitektur-Labels. Commits `b6e81505`, `14633a8a`, `8d155b47`, `83127a50`.
- **Merke:** `<Panel title=…>` landet NICHT in `innerText` → Checks auf sichtbare Marker
  bauen. GH-Store-Suche filtert nach `project_id` (Panel nutzt `goal-b-local`). agent-api
  bootet DB-optional (degraded ohne Postgres/Redis).

---

# ✅ RESTLICHE CHECKLISTE (in dieser Reihenfolge bis grün)

## PHASE 3 — Rest der Frontend-Politur
- [x] **3.5a S7 Sprach-Konsistenz**: DE als Produktsprache durchziehen — verbleibende
      EN-Reste in App-Shell/Seitentiteln/Buttons finden und übersetzen; Beweis: Playwright-
      Body-Text-Scan über alle 22 Seiten ohne gemischte EN/DE-Kernbegriffe.
- [x] **3.5b S9 Marketplace-Politur**: Karten-Kopfflächen bekommen Icons/Typ-Badges statt
      leerer Flächen; Detail/Install-Ergebnis als echtes UI statt Roh-`<pre>`. Beweis:
      Screenshot + Klickpfad (select → details → install dry-run, `provider_writes=false`).
- [x] **3.5c Stale-Chip Organism**: `data-source-kind`-Chip dynamisch aus `payload.source_kind`
      rendern (nicht mehr statisch `agent_api_redacted`). Beweis: /organism zeigt korrektes
      Label je Quelle (platform_audit vs. frontend_projection).

## PHASE 3 — Store-backed Bibliotheken (Kern des „unstrukturiert"-Befunds)
- [x] **3.7 Media-Bibliothek**: /media zeigt neben dem Studio eine echte Galerie der im
      GH-Store persistierten Media-/Artifact-Einträge (öffnen/löschen), analog BuildsGallery.
      Beweis: Artifact erzeugen → erscheint in der Galerie (Store-Roundtrip).
- [x] **3.8 Dokument-Bibliothek**: /docs-output zeigt neben dem Editor die Liste echter
      Session-/Dokument-Outputs aus dem Store. Beweis: Store-Roundtrip.
- [x] **3.9 /games-Galerie**: gebaute Spiele aus dem Store als Bibliothek listen
      („In Workbench öffnen" / „Öffnen" → /run/<id>). Beweis: Spiel bauen → gelistet.

## PHASE 4 — Finale & Wahrheit
- [x] **4.1 22-Seiten-Endproof 2.0**: kompletter Hosted-Human-Click-Proof nach allen
      Fixes, FAIL=0, PNG+HAR pro Route, gegen die Live-URL.
- [x] **4.2 Verifier-Suite grün**: `verify-phase1.ps1`, `verify-browser-contract.ps1`
      (DEV), `npm run lint/build`, `npm run test:e2e`, gitleaks — alle grün.
- [x] **4.3 Manifest + Spiegel**: `docs/project-progress.manifest.json` NUR mit den neuen
      Beweisen aktualisieren (Prozente contract-konform; aktuelle Claims aus no-token Audit
      `194215` gespiegelt). PROJECT_STATE/AI_HANDOFF/verification-register synchron.
- [x] **4.4 END_ZIEL_GESAMTSPEC §4** „Jetzt"-Zeilen mit dem echten Stand aktualisieren
      (mehrere Seiten übertreffen die alte Spec — belegen).
- [x] **4.5 `master-goal-final.md`** schreiben: Vorher/Nachher pro Seite, Evidence-Index,
      verbleibende Owner-only-Punkte exakt benannt.

---

## ENDZUSTAND (nur diese zwei zählen)
1. **Alle Haken grün** → `master-goal-final.md` mit Evidence-Index. FERTIG.
2. Alles Erreichbare grün + Rest NACHWEISLICH owner-only (der Standard-Bootstrap braucht
   weiterhin Hosted-Staging- und Origin-Konfiguration; Production-Release-Promotion bleibt
   zusaetzlich eine bewusste Owner-Entscheidung) →
   exakt in `master-goal-final.md` auflisten. Nichts anderes ist ein Ende.

## DETAIL-REFERENZEN (nur bei Bedarf)
`CODEX_MASTER_GOAL.md` (Phasen-Detail), `CODEX_GOAL_D6_FRONTEND_STRUKTUR_AUDIT_2026-07-11.md`
(S1–S9), `.codex/runs/CURRENT/goal-d6/batch0/claude-live-recon-2026-07-11.md` (Recon + 22/22-Matrix),
`.codex/runs/CURRENT/master-goal/status.md` (Live-Fortschritt), `docs/END_ZIEL_GESAMTSPEC.md` §4.

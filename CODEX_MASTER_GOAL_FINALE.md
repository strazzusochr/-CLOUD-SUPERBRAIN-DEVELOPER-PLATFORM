# 🏁 CODEX MASTER GOAL — FINALE (bis Vollendung + fehlerfreier Beweis)
# Version: 2026-08-01 (RC11 local qualification)
# Führt CODEX_MASTER_GOAL.md zu Ende. Dieses Dokument ist der aktuelle Einstieg.

Current canonical marker: `overall=89`; `P5=89`; `MARKET_READY:false`.

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

## AKTUELLER RC11-QUALIFIKATIONSSTAND (2026-08-01)

- Release: `prod-candidate-2026-07-31-local-rc11`.
- Source: `bae3cdc1692e1e99e7f546f72664a3c747958b8c`.
- CI: GitHub Actions `pr-check`, Run `30686367636`, `success`.
- Fünf unabhaengige Ketten sind grün und artefakt-/hash-/ankergebunden:
  `runtime`, `browser`, `candidate_images`, `candidate_runtime`, `security`.
- Ergebnis: `17/19`, P5 `89%`, Overall `89%`.
- Horizontal: `P0 100 | P1 100 | P2 100 | P3 44 | P4 100 | P5 89 | P6 90`.
- Vertikal: `FE 100 | ORC 100 | AP 100 | LLM 55 | MCP 56 | MEM 100 | OBS 100`.
- O4-Evidence SHA-256:
  `50304C69B3D748C95804C4C72C2970694748F469AE322D5C24DAA6BCB545B11B`.
- `MARKET_READY:false`: I1 `hosted_candidate_parity` und I5
  `production_auth_identity` bleiben `OWNER-BLOCKED`.
- Alle fünf Ketten sind `DEV-ONLY; hosted proof still blocked`.
- Kein GHCR-Publish, kein Deploy, keine Promotion und kein Production-Auth-Claim.

## HISTORISCHE BASELINE (2026-07-20 — Provenienz, nicht aktuelle Prozentautorität)
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
  Die immutable URL bleibt deployment-geschuetzt; die source-bound Alias-Reads belegen den
  damaligen Snapshot `overall=84`, `P4=100`, MCP/LLM `healthy`, Agent API `degraded` und
  App-POST HTTP 503
  `stateless_contract_origin_read_only`. Dies ist ein scoped Betriebs-Deploy des
  zustandslosen Contract Origin, nicht der stateful Docker-Stack oder ein Plattform-Release.
- **External-Gate-Wahrheit v2:** Der getrackte kanonische Audit
  `docs/runtime-state/external-gate-audit-v2.json` (`external-gate-audit-v2`, SHA-256
  `5E05F8EC80F17845C7CAC980177275F008216560C3BEECFDCF0DD3B40D05C21C`) und
  `external-gate-summary-v2` melden `blocked`, `production_deploy_claim_allowed=false`
  und exakt `cloudflare_native_zero_card_hosted_runtime` als aktiven Blocker. Der volle
  lokale Lauf liegt unter
  `.phase1-artifacts/external-gate-audit-v2-20260726-084042.json`.
  Hosted-Vertraege, Vercel-Origins, Branch Protection, GHCR-Digests und Gitleaks sind
  positiv, ersetzen aber nicht den stateful O2'-Hosted-Proof. Die GET-only Cloudflare-
  Scope-Inventur konnte wegen HTTP 401/403, Code 10000, 0/6 Ressourcenfamilien lesen;
  sie beweist unzureichende Management-Scopes, nicht Ressourcenabwesenheit. Fly/RC10-v1
  und Kandidat `125413` sind `historical_only`.
- **Runtime-Bindung v2:** External Gates, Mirror, Deployment Preflight, Completion,
  Infra-Budget und Go-live Readiness lesen die v2-Summary und das CF-Capability-Gate.
  Aktiver Target-Key ist `cloudflare_native_runtime`; Budgetquelle ist
  `cloudflare_zero_card_projection`; Production bleibt false. Overall bleibt `86%`.
- **Phase 3 Auth Fail-Closed:** `phase3-auth-credential-issuance-fail-closed-v1` ersetzt die
  sicherheitsinvaliden RC1-Dry-run-Issuance-Claims. Einmaliger Redis-State, verifizierte numerische
  GitHub-ID, exakt `read:user`, starkes base64url-256-Bit-Signing-Secret, aktive Cookie-Refresh-
  Registry, Audit-before-Cookie, truthful Logout und query-sichere Access-Logs sind implementiert.
  19 Tests, echte Redis-Konkurrenz sowie Static/Runtime/Browser sind seriell gruen. Evidence:
  `.codex/runs/CURRENT/phase3/auth-fail-closed/report.json`, SHA-256
  `FB90E6D57FFBC6C646C583D6F5DD18F4EDB71D9E881B9B7090B3FFDD31FCADC1`. P3 bleibt ohne
  Doppelcredit `44%`; Overall `86%`. DEV-ONLY; hosted proof still blocked. Der neue `sharp`-
  Advisory ist per `0.35.3`-Override geschlossen, npm audit `0`. Commit `255e328a` ist gepusht;
  RC5 deckt die neue Source per Clean-Archive-Beweis ab.
- **Phase 2 Runtime:** Der fehlende siebte Pflichtbeweis ist gutgeschrieben. Ein
  abgeschlossener LangGraph-Checkpoint wurde vor und nach echter `agent-api`-/`nginx`-
  Recreation unter demselben `thread_id` aus PostgreSQL gelesen. Der fokussierte
  Recreate-Probe und `npm run verify:runtime` sind gruen. Phase 2 `100%`, Overall `86%`.
  Evidence: `.codex/runs/CURRENT/master-goal/phase2/checkpoint-restart-recovery-20260721.md`.
- **Agent Pool Hosted Readback:** Ein tokenfreier HTTPS-GET-Verifier liest den aktuellen
  Cloudflare-D1-Contract, einen persistierten terminalen Lauf und exakt vier abgeschlossene
  Rollen-Tasks (`planner`, `coder`, `tester`, `devops`) zurueck. Bereits kreditiertes lokales
  Vier-Rollen-/Worker-/Priority-Queue-Evidence wird nicht doppelt gezaehlt; nur der neue
  Hosted-D1-Readback-Marker hebt Agent Pool `68% -> 69%`. Evidence:
  `.codex/runs/CURRENT/master-goal/t3/agent-pool-hosted-readonly/report-20260721-102425.json`.
- **MCP Hosted Read-only Contract Parity:** Der source-gebundene Vercel Contract Origin
  liefert per oeffentlichem HTTPS GET Health, fuenf Dry-run-Vertraege, exakte Dependency-/
  Tool-Pins und den MCP-Audit-Vertrag mit HTTP `200`. Sieben deployte MCP-Quellpfade sind
  zwischen Source `21913f8c3ef13949ca962980c143e757ca87a7cc` und HEAD blob-identisch.
  Evidence: `.codex/runs/CURRENT/mcp-gateway/hosted-readonly-contract/report.json`, SHA-256
  `67281BB2B9CE8A411D88954D7604D9205E13726644FDA21BA0DE5673A596D15C`. Nur der neue
  Marker wird kreditiert: MCP Gateway `55% -> 56%`, Overall bleibt `86%`. Kein Token,
  MCP-Execute, Audit-Write, Provider-Write, stateful Backend-, Release- oder Production-Claim.
- **Phase 5 Current Candidate RC5:** Sechs Images wurden aus dem Clean-Archive von Auth-/Security-
  Commit `255e328a76b3f84bf74358bc7258b9ffb797b339` gebaut und auf OCI-/Source-Identitaet,
  Frontend-`BUILD_ID`, Runtime-Source-Paritaet, RC4-Rollback und echten Diagnostics-Klick
  verifiziert. Der Vercel Contract Origin bleibt ein stale read-only Snapshot (`84` vs lokal
  `86`) und berechtigt keine Promotion. P5 bleibt ohne Doppelcredit `68%`. DEV-ONLY; hosted proof
  still blocked.
- **LLM Preview Read-only Source Parity:** Der oeffentliche Cloudflare Preview Worker liefert
  tokenfrei Health und exakt zwei allowlist-basierte Modelle. Source `67f41ce` und der aktuelle
  Service-Tree sind blob-identisch; alle Live-Call-/Write-Claims bleiben false. Evidence:
  `.codex/runs/CURRENT/llm-gateway/cloudflare-hosted-readonly/report.json`, SHA-256
  `D9DE8F7C46309F1FDA1EED43D4C2F14A65D99A2D77D60B01AAC449A1CAB83D71`. LLM Gateway
  `54% -> 55%`, Overall bleibt `86%`; keine Inferenz, kein Production-Worker- oder Release-Claim.
- **Workbench LLM-503 operational behoben:** Auth-/Origin-Paritaet zwischen Vercel und dem
  Cloudflare Preview Worker ist wiederhergestellt. Preview und Production-Alias liefern echte
  Mini-Builds mit HTTP `200`; beide bestanden Real-Chrome 22x2. Evidence:
  `.codex/runs/CURRENT/llm-gateway/frontend-build-503-fix/report.json`, SHA-256
  `B66A02387CD5CCA631947DAC7E6A99BF9B1E0BC5A498F6828437018794F42F0A`. Kein Prozentcredit
  und kein Full-Platform-Production-Readiness-/Release-Promotion-Claim.
- **T4 Frontend-Providergrenze:** Direkte Neon-, Cloudflare- und GitHub-Store-Pfade im
  Frontend sind entfernt. Acht Action-Routen nutzen nur Agent API, LLM Gateway oder MCP
  Gateway und bleiben ohne konfigurierte Grenze fail-closed; drei Vercel-Wrapper bleiben
  zustandslos und read-only. Static-, Runtime-, Browser-, Lint- und Build-Gates sind gruen.
  Evidence: `.codex/runs/CURRENT/master-goal/t4/frontend-provider-boundary/report.json` und
  `.codex/runs/CURRENT/master-goal/production/t1-21913f8c`.
  Overall bleibt `86%`; Release-Promotion und Live-Provider-Aktivierung sind unbeansprucht.
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

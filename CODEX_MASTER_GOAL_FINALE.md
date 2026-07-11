# 🏁 CODEX MASTER GOAL — FINALE (bis Vollendung + fehlerfreier Beweis)
# Version: 2026-07-11 (Claude-Supervisor-Baseline nach Codex-Token-Ende)
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
3. **Free-Only** — kein Fly-Deploy, nichts Bezahltes. Owner-Freigabe (2026-07-11) deckt:
   `vercel deploy`/`vercel env` für die zwei bestehenden Projekte, lokale Commits,
   read-only Gate-Audits mit vorhandenen Tokens. **KEIN `git push`.**
4. **Localhost = DEV-ONLY** — jeder Hosted-Beweis ist HTTPS non-localhost, kein `-AllowLocalhost`.
5. **UI-Checks nur mit Playwright nach Hydration.** Proof-Tool: `node tools\ultimate_22_human_click_proof.mjs`
   IMMER aus PowerShell starten (Git-Bash zerstört `/routen`-Argumente).
6. **Kein Deploy, während ein Hosted-Proof läuft** (invalidiert den Beweis).
7. Budget: Workers AI 10.000 Neurons/Tag → LLM-Beweise = 1 Mini-Prompt.

## VERIFIZIERTE BASELINE (2026-07-11 — nicht neu herleiten, nur fortführen)
- **Frontend-Produktion** `https://frontend-seven-psi-78.vercel.app`: 22/22 Routen 200.
  Hosted-22-Human-Click-Proof `hosted22-final-r5` = **22/22 FAIL=0, exit 0** (echte
  Klickpfade: Multi-Agent-Lauf via Workers AI, Build-Roundtrip, Memory-Seed+Hit,
  Musik-Export). Deploy aus REPO-ROOT: `vercel deploy --prod --yes` (Root-Link vorhanden,
  rootDirectory=apps/frontend).
- **Backend-Projekt 2** `https://cloud-superbrain-developer-platform.vercel.app`:
  echte agent-api als Vercel-Python-Function (`/api/v1/health` degraded-ehrlich,
  `/llm/...` + `/mcp/...`-Contracts live). Frontend-Origins umgebogen
  (`X-Superbrain-Source: live-agent-api`).
- **External-Gate-Wahrheit:** Audit `.phase1-artifacts/external-gate-audit-20260711-124931.json`
  war zum Erzeugungszeitpunkt mit Owner-Tokens `verified`. Der aktuelle no-token Audit
  `.phase1-artifacts/external-gate-audit-20260711-194215.json` ist `blocked`; aktuelle
  Produktions-Claims bleiben deshalb false. Der historische Audit ist nur Evidence, keine
  gegenwärtige Freigabe.
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
2. Alles Erreichbare grün + Rest NACHWEISLICH owner-only (aktueller no-token Audit ist auf
   Hosted-Agent-API, Branch Protection, Vercel-Origins und Fly-Budget geblockt;
   Production-Release-Promotion bleibt bewusste Owner-Entscheidung, kein Bug) →
   exakt in `master-goal-final.md` auflisten. Nichts anderes ist ein Ende.

## DETAIL-REFERENZEN (nur bei Bedarf)
`CODEX_MASTER_GOAL.md` (Phasen-Detail), `CODEX_GOAL_D6_FRONTEND_STRUKTUR_AUDIT_2026-07-11.md`
(S1–S9), `.codex/runs/CURRENT/goal-d6/batch0/claude-live-recon-2026-07-11.md` (Recon + 22/22-Matrix),
`.codex/runs/CURRENT/master-goal/status.md` (Live-Fortschritt), `docs/END_ZIEL_GESAMTSPEC.md` §4.

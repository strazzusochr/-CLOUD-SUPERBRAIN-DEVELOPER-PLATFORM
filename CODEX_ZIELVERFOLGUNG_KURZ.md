# 🎯 ZIEL-VERFOLGUNG (KURZ) — Stand 2026-07-20 — autonom bis 100 % MARKTREIF
# In JEDER Session: (1) diese Datei → (2) CODEX_UEBERGABE_2026-07-20.md → (3) arbeiten.

## ENDZIEL
Beide Matrizen **100 %** (P0–P6 + FE/ORC/AP/LLM/MCP/MEM/OBS), jede Zelle mit echtem Artefakt.
**FINISH-LINE:** `npm run verify:market-ready` druckt `MARKET_READY: true` → erst dann
`master-goal-final.md` + FERTIG. Owner-gated Reste bleiben ehrlich OWNER-BLOCKED, nie gefaked.

## ✅ REALITÄT 2026-07-20 (Supervisor live gemessen, nicht zitiert)
HEAD `4fa2426d` = origin, 0 unpushed · Manifest **84 %** · `MARKET_READY:false` (korrekt)
`P0 100 · P1 100 · P2 86 · P3 44 · P4 100 · P5 68 · P6 90`
`FE 100 · ORC 100 · AP 68 · LLM 54 · MCP 55 · MEM 73 · OBS 99`

- **External Gates: 2/6 → 5/6 tokenfrei geöffnet** ✅ (Audit `20260720-191532`).
  Zwei Gates waren **Config-**, keine Secret-Blockade; Branch-Protection war bereits korrekt
  (`mismatches: []`, nichts an GitHub geändert) und ist auf dem **public** Repo anonym prüfbar.
  Einziger Blocker: `fly_live_budget_check` (Kreditkarte).
- **Alle 22 Routen: 200 lokal UND hosted** ✅ — kein 504/502/404.
- **Platzhalter/Bilder: sauber** ✅ — 0 Lorem/Coming-soon/Dummy, 0 TODO/FIXME, 0 `<img>`;
  einziges Asset `public/organism/core.glb`, real im 3D-Organismus genutzt.
- **R0 intakt:** Summary `blocked`, `production_deploy_claim_allowed=false`.

## 🔴 DREI ECHTE DEFEKTE (heute gefunden — vor allem anderen fixen)
- **D1 · Production ist 2 Commits alt.** Beide Aliase auf `38af05d6`, HEAD `4fa2426d`.
  Folge: **8 Endpunkte liefern HTTP 500** (`agent-activity/recent`, `audit/mcp`, `audit/recent`,
  `escalations/recent`, `memory/consolidation/recent`, `rotation/events`, `sessions/recent`,
  `workspace/artifacts`) — lokal alle 200. Der Chrome-Klicktest bricht sichtbar auf **`/media`** ab.
- **D2 · Der Build funktioniert in der Cloud nicht mehr.** `POST /api/v1/build` → `503
  llm_gateway_generation_unavailable`. Die T4-Boundary-Härtung hat den direkten
  Cloudflare-Workers-AI-Pfad entfernt; der Ersatz (LLM Gateway) existiert in der freien Cloud nicht.
- **D3 · Layer-Wahrheit ist token-assistiert.** Hosted tokenfrei **0/7**; lokal 4/7 nur, weil der
  Container 10 Tokens im Env hat — und **L2/L3/L6 melden `live_verified` über das bezahlte Fly.io**.
  Das ist im Free-Only-Zielbild ungültig.

## ✅ T-QUEUE (Reihenfolge; PASS nur mit Beweis + PROOF_LEDGER-Zeile)
- **T1 (Prio 0)** D1 fixen: HEAD als **Preview** deployen → 22×2 + die 8 Endpunkte grün →
  **erst dann** Production-Alias. Bei Rot sofort zurückrollen.
- **T2 (Prio 0)** D2 fixen: **Cloudflare Worker als echtes LLM-Gateway** (Workers AI serverseitig),
  `LLM_GATEWAY_BASE_URL` per `vercel env` (O1: erst Preview + Proof).
  ⛔ Den Direktpfad **nicht** ins Frontend zurückholen — das war die Ursache.
- **T3 (Prio 1)** D3/O7: L2/L3/L6 von Fly auf **Neon Free / CF D1** umstellen; `fly_live_budget_check`
  durch ein Free-Tier-Budget-Gate ersetzen (ADR, nicht still löschen).
- **T4 (Prio 1)** L1 (`vercel_frontend_live_read_not_verified`), L5 (GHCR + GitLab), L7 schließen —
  zuerst prüfen, ob ein **tokenfreier** Public-Read genügt (dieser Trick hat heute 3 Gates geöffnet).
- **T5 (Prio 2)** Matrix-Zellen mit echtem Runtime-Beweis: P2/P3/P5/P6, AP/LLM/MCP/MEM.
- **T6 (Prio 2)** Doku-Hygiene: 24 historische Root-`.md` bekommen Zeile 1
  `> HISTORIE (Stand …) — nicht aktuelle Wahrheit. Aktuell: PROJECT_STATE.md.` Nichts löschen.
- **T7** Endproof-Loop bis `MARKET_READY: true`.

## 🔒 PFLICHT-PROTOKOLL vor JEDER Arbeit
1. `git log -1` ≥ `4fa2426d` UND origin erreichbar — sonst alter Checkout: **STOPP**.
2. Fremde dirty Dateien (`.gitignore`, `goal-b-actions.tsx`, `tsconfig.tsbuildinfo`) **nie** anfassen.
3. Läuft `verify-*` / `playwright` / `docker build`? Keine parallelen Verifier/Rebuilds.
4. Nur Artefakte mit **aktuellem** Zeitstempel gelten (Mai/Juni = Historie).
5. Kein Deploy, während ein Hosted-Proof läuft.

## 🔓 OWNER-FREIGABE (gilt weiter, vollautonom)
`vercel env` + Deploy der zwei bestehenden Projekte (O1: **erst Preview + 22×2-Proof**) ·
Promotion (O5) **sobald** `MARKET_READY: true` · freier Stateful-Weg statt Fly (O7) ·
**Cloudflare Workers AI = freier Live-Provider** (B1) · GitHub Branch-Protection/Variablen/Actions.
Push weiterhin **nur** `claude/cloud-superbrain-analysis-127d2e`, kein Force, kein main.

## ⛔ VIER WÄNDE (bleiben Owner-Aktion)
1. **Zahlungsdaten/Kreditkarte** · 2. **Accounts mit Passwort** · 3. **CAPTCHA** ·
4. **Secret-Werte ausgeben/committen**
→ Owner-Action-Paket schreiben (URL, Felder, Klicks), am Rest weiterarbeiten, **niemals faken**.

## HARTE REGELN
No-Fake-Done/Live (`frontend-projection`/`live:false`/`blocked`/`DEV-ONLY` NIE umdrehen — Test
erweitern statt Wahrheit biegen) · R0: kanonisch ist der **tokenfreie** Bootstrap, Token-Audits sind
owner-assistierte Kandidaten · No Secrets (transient, presence-only) · Free-Only, kein Fly/Paid ·
Push nur auf den Arbeitsbranch · Localhost = DEV-ONLY · Proof-Tools nur aus PowerShell ·
Vercel-Deploy nur per Clean-Archive · Repo-Variablen und `STAGING_REWRITES_ENABLED` nicht ändern ·
Branch-Protection auf `chore/repo-bootstrap` ist korrekt — nicht „reparieren".

## DONE heißt (sonst OFFEN)
Ausgeführt (frischer Report, neuer als der Code) · reale Werte per Assert VOR Report-Write ·
in `npm run verify:*` verdrahtet · Manifest-% nur mit referenziertem Artefakt +
`verify_project_progress_manifest.py` grün · Ledger-Zeile · committed + gepusht + (wenn UI) deployt
**und hosted nachgewiesen**.

## FERTIG heißt exakt
`MARKET_READY: true` → `master-goal-final.md` mit Evidence-Index. ODER: alles Autonome echt 100 %
+ Rest exakt als OWNER-BLOCKED gelistet — und dranbleiben, bis der Owner liefert.
Nichts anderes ist ein Ende.

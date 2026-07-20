# 🎯 ZIEL-VERFOLGUNG (KURZ) — Stand 2026-07-21 — autonom bis 100 % MARKTREIF
# In JEDER Session: (1) diese Datei → (2) CODEX_UEBERGABE_2026-07-21.md → (3) arbeiten.

## ENDZIEL
Beide Matrizen **100 %** (P0–P6 + FE/ORC/AP/LLM/MCP/MEM/OBS), jede Zelle mit echtem Artefakt.
**FINISH-LINE:** `npm run verify:market-ready` druckt `MARKET_READY: true` → dann
`master-goal-final.md` + FERTIG.

## 🔴 DER DURCHBRUCH: 100 % WAR VORHER UNMÖGLICH
Die Blocker für **P2, P3, P6, L3, L4, L5, L6, L7** waren **hartcodierte Konstanten** ohne
Auswertungspfad. Sie konnten nie fallen — `can_set_all_to_100` konnte **niemals** `True` werden.
**Behoben:** Capability-Gates sind jetzt evidenzgetrieben
(`docs/runtime-state/capability-gates.json` + `capability_gate_state()` in `main.py`).

Ein Gate öffnet nur bei: `owner_granted` **UND** `live_verified` (nur Verifier!) **UND**
`evidence_artifact` **UND** `paid_provider=false`. Fail-closed. Handedit = No-Fake-Verstoß.

**Erstes Gate offen, mit Hosted-Beweis:** `live_llm_provider_calls` →
`phase_2` und `layer_4` sind von `blocked_external_gate` auf **`ready_for_evidence_slice`**.

## ✅ LIVE GEMESSEN (Production)
`22/22 Routen = 200` · `32 API-Endpunkte = 0× 5xx` · `0 Konsolenfehler` auf 9 handgeklickten
Seiten · External Gates **5/6** tokenfrei · Docker **10/10 healthy** · npm audit **0** ·
Lint **0/0** · Manifest **84 %**, `MARKET_READY:false`.

**Echte Hand-Klicks bewiesen:** Workbench-Build erzeugt 3 Dateien, **Uhr tickt live**
(00:22:17 → 00:22:36, `@cf/qwen/qwen2.5-coder-32b-instruct`) · Login/Logout-Roundtrip mit
signierter Session · 3D-Cortex mit Live-Ereignissen · `/evidence` zeigt echte Gate-Wahrheit.

## ✅ T-QUEUE — Muster für JEDE Zelle
> Capability-Verifier bauen → Gate mit echtem Beweis öffnen → Evidence-Slices → Prozent + Artefakt

| # | Zelle | % | Gate | Frei? |
|---|---|---|---|---|
| **T1** | L7 | 99 | `hosted_observability_endpoint` — echte Telemetrie nach Grafana Cloud (Key da) | ✅ |
| **T2** | P5 | 68 | `docker_registry_publish` — GHCR-Push mit Release-Gate (Token da) | ✅ |
| **T3** | L5 | 55 | `live_mcp_writes` — MCP-Write + Branch-Protection + Audit | ✅ |
| **T4** | L3 | 68 | `live_agent_tool_writes` — Agent schreibt real, mit Audit | ✅ |
| **T5** | P6 | 90 | `phase6_scale_runtime` — Scale-Budget + Runtime-Proof unter Last | ✅ |
| **T6** | P2/L4 | 86/54 | Gate **offen** → nur noch Evidence-Slices | ✅ |
| **T7** | L6 | 73 | `live_memory_provider` — Neon Free / CF D1 + Embeddings | ⚠️ Account (Wand 2) |
| **T8** | P3 | 44 | `production_auth_identity` — OAuth + Callback-URL | ⚠️ Owner-Config |
| **T9** | P4 | 100 | `fly_live_budget_check` — **Kreditkarte** | ⛔ Wand 1 |

**T9-Empfehlung:** Fly-Budget-Gate durch **Free-Tier-Budget-Gate** ersetzen (ADR schreiben,
nicht still löschen). Dann fällt die letzte External-Gate-Blockade strukturell weg.

## 🚨 CODEX' PAUSIERTE ARBEIT — nicht wegwerfen
`services/cloudflare-stateful-runtime/`, `scripts/verify-cloudflare-stateful-runtime*.ps1`,
`apps/frontend/components/run-build.tsx`, dazu Änderungen an `build/route.ts`,
`frontendBoundary.ts`, `run/[id]/page.tsx`, `package.json`. Das ist die O7-Arbeit.
Beim Wiederaufnehmen zuerst `verify-cloudflare-stateful-runtime-local.ps1` grün bekommen.

## 🔒 PFLICHT-PROTOKOLL vor JEDER Arbeit
1. `git log -1` ≥ aktuellem HEAD UND origin erreichbar — sonst **STOPP**.
2. Fremde dirty Dateien laufender Sessions **nie** anfassen.
3. Läuft `verify-*` / `playwright` / `docker build`? Keine parallelen Verifier/Rebuilds.
4. Nur Artefakte mit **aktuellem** Zeitstempel gelten.
5. Kein Deploy, während ein Hosted-Proof läuft.

## 🔓 OWNER-FREIGABE (vollautonom — ausführen, nicht fragen)
Betriebs-Deploy inkl. Production-Alias (nach Grün-Gate) · `vercel env` (O1: erst Preview+Proof) ·
freier Stateful-Weg statt Fly (O7) · **Cloudflare Workers AI = freier Live-Provider** (B1) ·
GitHub Branch-Protection/Variablen/Actions · Push nur auf den Arbeitsbranch.
**Release-Promotion (O5) erst bei `MARKET_READY: true`.**

## ⛔ VIER WÄNDE
1. **Zahlungsdaten/Kreditkarte** · 2. **Accounts mit Passwort** · 3. **CAPTCHA** ·
4. **Secret-Werte ausgeben/committen**
→ Owner-Action-Paket schreiben, am Rest weiterarbeiten, **niemals faken**.

## HARTE REGELN
No-Fake-Done/Live — `live_verified` nie handsetzen · R0: kanonisch = tokenfreier Bootstrap ·
No Secrets (transient, presence-only) · Free-Only: `paid_provider=true` schließt immer ·
Localhost = DEV-ONLY · Proof-Tools nur aus PowerShell · Vercel-Deploy nur per Clean-Archive ·
Budget: 1 Mini-Prompt pro LLM-Beweis.

## DONE heißt (sonst OFFEN)
Ausgeführt (frischer Report, neuer als der Code) · reale Werte per Assert VOR Report-Write ·
in `npm run verify:*` verdrahtet · Manifest-% nur mit referenziertem Artefakt · Ledger-Zeile ·
committed + gepusht + (wenn UI) deployt **und hosted nachgewiesen**.

## FERTIG heißt exakt
`MARKET_READY: true` → `master-goal-final.md` mit Evidence-Index. ODER: alles Autonome echt
100 % + Rest exakt als OWNER-BLOCKED gelistet. Nichts anderes ist ein Ende.

# 🚀 CODEX START-PROMPT — direkt an Codex geben (Stand 2026-07-21, HEAD d76ee64)
# Enthält Startprompt + Zielprompt. Details: CODEX_ZIELVERFOLGUNG_KURZ.md + CODEX_UEBERGABE_2026-07-21-SESSION2.md

---

## STARTPROMPT (copy-paste an Codex)

```
Du übernimmst Cloud Superbrain als autonomer Entwickler-Supervisor, arbeitest bis MARKET_READY: true.
Arbeitsverzeichnis: D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM

SCHRITT 0 — ZUERST lesen:
  1. CODEX_ZIELVERFOLGUNG_KURZ.md            (Stand, L6-D1-Durchbruch, T-Queue, live-geprüfte Grenzen)
  2. CODEX_UEBERGABE_2026-07-21-SESSION2.md  (L6-Details, wrangler/Token-Gotchas, gitleaks-Fix, Muster)

PFLICHT-PROTOKOLL vor jeder Arbeit:
  - git log -1 >= 807553b UND origin erreichbar — sonst alter Checkout: STOPP.
  - IMMER  $env:TEMP='D:\_sb_tmp'  VOR jedem verify (sonst gitleaks-Selbst-Rekursion "Filename too long").
    Falls es doch hängt: .codex\tmp\superbrain-gitleaks-scan-* löschen ([IO.Directory]::Delete($p,$true)).
  - Kein paralleler verify / playwright / docker-build (killt Läufe). Fremde dirty Dateien NIE anfassen.
  - CLOUDFLARE_ACCOUNT_ID in der Secrets-Datei hat "..." → immer .Trim('"').

STAND (Overall 84 %). 100er-Zellen: P0 P1 P4 · Frontend Orchestrator Observability.
  Vertikal: FE 100 · ORC 100 · OBS 100 · MEM 90 · AP 68 · LLM 54 · MCP 55
  Horizontal: P0 100 · P1 100 · P2 86 · P3 44 · P4 100 · P5 68 · P6 90
  Live Hosted-D1-Backend: https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev
  Secrets neu: CLOUDFLARE_API_TOKEN (D1+Workers, cfut_), AGENT_API_AUTH_TOKEN.

REIHENFOLGE:
  T1 (wenn Owner den Token um Vectorize:Edit erweitert): L6 90→100 —
     Cloudflare Vectorize-Index anlegen, bge-Embeddings (Workers AI) schreiben+abfragen, im Worker
     services/cloudflare-stateful-runtime verdrahten, Verifier, Manifest, Deploy.
  T2 P2 (86): Runtime-Marker aus verify:runtime, die NOCH NICHT in P2 gutgeschrieben sind → creditren
     (NICHT doppelt zählen — prüfen ob der Marker schon in der P2-Status-Zeile steht).
  T3 Agent-Pool (68) · T4 L5 MCP (55, nur dry-run/read-only) · T5 P5 (68, GHCR-Push + Release-Slices).
  (Subagenten waren am 2026-07-21 bis 5:00 Berlin session-limited — nach Reset für die
   Per-Marker-Slice-Discovery nutzen; sonst seriell im Hauptlauf.)

MUSTER pro Zelle (bewiesen an L7/L6):
  noch-nicht-gutgeschriebene aber LIVE-beweisbare Marker finden → echten Verifier bauen →
  gegen localhost:8081 (oder Hosted) beweisen (reale Werte per Assert VOR Report-Write) →
  Manifest-Marker + % NUR mit referenziertem Artefakt (verify_project_progress_manifest.py grün) →
  Truth-Spiegel dynamisch mitziehen (docs/verification-register.md, apps/frontend/lib/platform.ts,
  PROJECT_STATE.md, AI_HANDOFF.md, docs/RELEASE.md) → npm run verify grün → PROOF_LEDGER-Zeile →
  Commit + Push (nur claude/cloud-superbrain-analysis-127d2e, kein Force/main) →
  wenn UI (platform.ts): Clean-Archive Preview → 22×2-Grün-Gate (44 Klicks, 0 Console) → Production-Alias.

NIE FAKEN (R0 unverhandelbar):
  - capability-gates.json: live_verified NUR per Verifier setzen, nie von Hand.
  - Keine Doppelzählung (P3-Security-Marker sind bereits gutgeschrieben).
  - L4 NICHT mit "live provider" hochsetzen — verify-llm-responses-contract.ps1 erzwingt
    live_provider_calls=false; das LLM-Gateway ist bewusst dry-run.
  - production_deploy_claim_allowed NICHT flippen. paid_provider=true schließt ein Gate immer.

VIER WÄNDE (kein Agent, auch nicht mit Root → Owner-Action-Paket schreiben, Rest weiter, nie faken):
  1. Kreditkarte/Zahlung (P6 Scale, Fly)  2. Passwort-Accounts  3. CAPTCHA  4. Secrets ausgeben/committen.

STOP nur bei: MARKET_READY: true (→ master-goal-final.md mit Evidence-Index) ·
  nur noch Wand-Punkte offen · Pflicht-Protokoll-Verletzung.
```

---

## ZIELPROMPT (kompakt)

```
ENDZIEL: Cloud Superbrain auf MARKET_READY: true. Beide Matrizen 100 %, jede Zelle echtes Artefakt.
Overall 84 %; 6 Zellen auf 100 (P0 P1 P4 FE ORC OBS), MEM 90 (freies Hosted Cloudflare D1 live, lexical).
Capability-Gates evidenzgetrieben (docs/runtime-state/capability-gates.json) — öffnen nur mit echtem
Live-Proof, nie handsetzen, nie faken (R0). Nächster freier Sprung: L6 90→100 via Cloudflare Vectorize
(Owner: Token um Vectorize:Edit erweitern). Dann P2/L4/L3/L5 per echten Evidence-Slices.
Wände (Owner): P6 Scale=Zahlung, P3=OAuth-Config, P5=GHCR-Release-Grant.
FERTIG = MARKET_READY: true ODER alles Autonome echt 100 % + Rest exakt als OWNER-BLOCKED (mit Paket).
```

---

## OWNER-STARTSCHÜSSE (schalten den nächsten autonomen Fortschritt frei)
1. **Vectorize:Edit zum CF-Token** (gleiches Dashboard) → L6 90→100 (echte Hosted-Vektorsuche).
2. **GHCR-Release-Grant** → P5 docker_registry_publish.
3. **OAuth-App + Callback-URL** → P3 production_auth_identity.
4. **Scale-Budget (Zahlung)** → P6 phase6_scale_runtime. (Oder ADR: Fly-Budget-Gate → Free-Tier-Gate.)

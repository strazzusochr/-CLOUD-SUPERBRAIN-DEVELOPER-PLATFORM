# 📋 CODEX-ÜBERGABE 2026-07-21 (Session 2) — Supervisor-Fortschritt + ehrliche Grenzen
# Ergänzt CODEX_UEBERGABE_2026-07-21.md. Alles gemessen, nichts zitiert.
# Reihenfolge: (1) CODEX_ZIELVERFOLGUNG_KURZ.md → (2) diese Datei → (3) arbeiten.

## ⭐ NEUESTER STAND (Session 2b, HEAD 807553b) — L6 HOSTED D1 LIVE
- **L6 Memory 73 → 90 %** (Commit `807553b`). Owner spielte einen D1-gescopeten CF-Token ein.
  Supervisor hat vollautonom das freie Hosted-Stateful-Backend gebaut+deployt:
  - D1-DB `cloud-superbrain-state-prod` (id `91520f43-5d38-4a31-9d5a-6fca890e1dd6`) angelegt
  - `0001_foundation.sql` remote migriert
  - Worker deployt → **`https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev`**
  - `AGENT_API_AUTH_TOKEN`-Secret auf Worker gesetzt (auch in `cloud-superbrain.local.env`)
  - Beide Verifier hosted grün: `scripts/verify-cloudflare-stateful-runtime.ps1` (5 Tests) +
    `scripts/verify-live-memory-provider.ps1` (Capability-Gate `live_memory_provider` geöffnet)
- **Matrix jetzt:** Overall 84 % · FE 100 · ORC 100 · OBS 100 · **MEM 90** · AP 68 · LLM 54 · MCP 55.
- **L6 letzte 10 % = Hosted-Vektorsuche (Cloudflare Vectorize).** D1 ist LEXICAL, kein pgvector.
  Wenn der Owner dem Token `Vectorize:Edit` gibt (gleiches Dashboard): Vectorize-Index anlegen,
  Embeddings (bge über Workers AI) schreiben+abfragen, im Worker verdrahten → L6 → 100.
- **Neue Secrets in `cloud-superbrain.local.env`:** `CLOUDFLARE_API_TOKEN` (jetzt D1+Workers, `cfut_`),
  `AGENT_API_AUTH_TOKEN`. **GOTCHA:** `CLOUDFLARE_ACCOUNT_ID` steht mit `"..."` → immer `.Trim('"')`.
- **gitleaks-Bug (der „Hänger"):** IMMER `$env:TEMP='D:\_sb_tmp'` VOR verify setzen (außerhalb
  Scan-Baum), sonst kopiert der Scan seinen eigenen Rest-Mirror rekursiv → „Filename too long".
- **wrangler-Befehle:** `node services/cloudflare-stateful-runtime/node_modules/wrangler/bin/wrangler.js`,
  Env `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` (getrimmt) + `CI=true` setzen.
- **Owner-Redeploy-Sync offen:** platform.ts zeigt MEM 90; Hosted-`/evidence` erst nach Frontend-Redeploy.

---

## 0. WAS DIESE SESSION REAL GELIEFERT HAT (committet + gepusht + hosted-getestet)

| Ergebnis | Beweis / Commit |
|---|---|
| **L7 Observability 99 → 100 %** | `scripts/verify-grafana-cloud-ingestion.ps1`: echte Grafana-Cloud-Ingestion (OTLP Log HTTP 204 + Metric HTTP 200 + Negativ-Kontrolle 401), Commit `985f5779` |
| **Production auf HEAD** | Beide Vercel-Aliase auf `985f5779` (sha-verifiziert), 22×2 Chrome-Proof grün (44 Klicks, 0 Console/Overflow/Overlay) |
| **gitleaks-Rekursionsbug behoben** | Verschachtelte Scan-Mirror in `.codex\tmp` → „Filename too long". Fix: Mirror gelöscht, `.codex\tmp` 252→7 MB, **TEMP nach `D:\_sb_tmp`**. Scan 7,5 min → **52 s** |

Frühere Session-1-Commits: `f2a27b1b` (Capability-Gate-Mechanismus), plus die vorherigen
(External Gates tokenfrei 5/6, D1-Fixes etc.).

**Matrix jetzt:** Overall **84 %** · 6 Zellen auf 100 (P0, P1, P4, FE, ORC, **OBS**) ·
`P2 86 · P3 44 · P5 68 · P6 90 · AP 68 · LLM 54 · MCP 55 · MEM 73` · MARKET_READY:false.

## 1. DER GITLEAKS-BUG (falls „Hänger" wieder auftaucht)
**Symptom:** verify hängt bei „gitleaks scan", kein Fortschritt, Log stoppt.
**Ursache:** ein abgewürgter verify-Lauf hinterlässt `.codex\tmp\superbrain-gitleaks-scan-*`; weil
`.codex\tmp` NICHT gitignored ist, kopiert der nächste Scan diesen Rest-Mirror rekursiv in sich.
**Fix:** (1) `superbrain-gitleaks-scan-*` in `.codex\tmp` mit Langpfad löschen
(`cmd /c rmdir /s /q "\\?\<pfad>"` scheitert im Sandbox → `[System.IO.Directory]::Delete($p,$true)`),
(2) **immer `$env:TEMP='D:\_sb_tmp'` VOR verify setzen** (außerhalb Scan-Baum),
(3) `.codex\tmp` schlank halten (alte Logs/Snapshots löschen).
**Dauerhaft:** `.codex/` in `.gitignore` aufnehmen — ABER `.gitignore` ist Codex-dirty, erst mit
deinem eigenen Slice sauber committen.

## 2. EHRLICHE PER-ZELL-GRENZEN (Supervisor LIVE geprüft — nicht spekulativ)
Diese Befunde verhindern Fake-Done und Verifier-Brüche. **Vor jedem Marker prüfen:**

- **P3 (44):** Die Security-Marker (`csp_report_*`, `csrf_*`, `cross_origin_*`, `auth_session_*`)
  sind in der Manifest-Status-Zeile **schon enthalten** → NICHT erneut crediten (Doppelzählung).
  Terminal-Blocker `production_auth_identity` = OAuth-Provider + gehostete Callback-URL = Owner.
- **L4 (54):** **Dry-run-gesperrt.** `verify-llm-responses-contract.ps1` erzwingt
  `contract.live_provider_calls == false`, `response.live_provider_calls == false` und verbietet
  `"live_provider_calls": True`. Das LLM-Gateway macht bewusst KEINE Live-Calls; die Live-CF-Workers-AI
  läuft in einer separaten Fläche (Frontend-Build). **L4 NICHT mit „live provider" hochsetzen.**
  L4-Fortschritt nur über routing/streaming/deny-CONTRACT-Marker (dry-run), die noch fehlen.
- **L6 (73):** D1-Probe live = **HTTP 401** (Token Workers-AI-only). Braucht D1-Scope oder Neon.
- **P6 (90):** Scale = Zahlung. Local-Load-Test wäre Kapazitäts-Overclaim.

## 3. WIE MAN EINE ZELLE EHRLICH HOCHZIEHT (Muster, bewiesen an L7)
1. Manifest-Status-Zeile der Zelle lesen → welche Marker fehlen noch?
2. Für einen fehlenden Marker: gibt es schon einen grünen Verifier (`verify:runtime`/`verify:browser`),
   der genau dieses Verhalten beweist? → dann nur **crediten** (Marker anhängen). Sonst Verifier bauen.
3. Verifier gegen `localhost:8081` beweisen (reale Werte per Assert VOR Report-Write).
4. Manifest: Marker anhängen + % nur bei echtem Artefakt. `verify_project_progress_manifest.py` grün.
5. **Truth-Spiegel dynamisch** — der Guard in `verify-phase1.ps1` liest den %-Wert aus dem Manifest
   und verlangt ihn in `docs/verification-register.md` ("<Label> `<pct>%`"), `apps/frontend/lib/platform.ts`
   (`pct:`), und je nach Zelle in `PROJECT_STATE.md`/`AI_HANDOFF.md`. Alle mitziehen, sonst bricht verify.
6. Bei UI-relevantem % (platform.ts): Preview → 22×2 Grün-Gate → Production-Alias → hosted nachmessen.
7. Ledger-Zeile (`.codex/runs/CURRENT/master-goal/PROOF_LEDGER.md`), Commit, Push.

## 4. DIE CAPABILITY-VERIFIER (Vorlagen)
- `scripts/verify-live-llm-free-provider.ps1` — öffnet `live_llm_provider_calls` (hosted Build 200).
- `scripts/verify-grafana-cloud-ingestion.ps1` — öffnet `hosted_observability_endpoint` (OTLP 204/200).
Beide: Token transient aus env, presence-only, Report → `.codex/runs/.../capability/`, dann
`live_verified=true` im Gate. **Muster für neue Gates kopieren.** Laufen NICHT in der tokenfreien
Always-on-`verify` (Hosted-Abhängigkeit) — gehören in die Capability/Market-Ready-Lane.

## 5. OWNER-AKTIONEN (Startschüsse für autonomen Fortschritt)
- **Paket 1 (kostenlos, 2 Min) — schaltet L6 (+27) frei:** CF-Dashboard → API Tokens →
  Create Custom Token → `Account · D1 · Edit` + `Account · Workers Scripts · Edit` →
  in `cloud-superbrain.local.env` `CLOUDFLARE_API_TOKEN` ersetzen. Dann Codex: D1 anlegen,
  pgvector-kompatibles Schema, `services/cloudflare-stateful-runtime/` deployen, Persistenz beweisen.
- **Paket 2 (Zahlung) — P6 Scale:** Cloudflare Workers Paid / Vercel Pro. ODER Scale-Gate durch
  Free-Tier-Budget-Gate ersetzen (ADR, Owner-Review).
- **Paket 3 (Owner-Config) — P3:** OAuth-Provider (GitHub OAuth App) + gehostete Callback-URL.

## 6. HINWEIS ZU SUBAGENTEN / SESSION-LIMIT
Am 2026-07-21 waren Subagenten durch ein Session-Limit blockiert („resets 5am Europe/Berlin"). Falls
Workflow-Agenten mit diesem Fehler scheitern: seriell im Hauptlauf weiterarbeiten oder nach Reset erneut.

# 🎯 ZIEL-VERFOLGUNG (KURZ) — Stand 2026-07-31 (Session 13)
> **Reihenfolge in JEDER Session:** (1) diese Datei → (2) `CODEX_UEBERGABE_2026-07-31-SESSION13.md`
> → (3) Preflight → (4) arbeiten. Die Session-12-Übergabe ist **historisch**.

## ENDZIEL
Beide Matrizen **100 %**, jede Zelle mit echtem Artefakt.
**Finish-Line:** `npm run verify:market-ready` druckt real `MARKET_READY: true`.
Owner-gewallte Reste ehrlich als **OWNER-BLOCKED** listen — **nie faken** (R0).

---

## ✅ STAND (gemessen, nicht geschätzt)
Branch `claude/cloud-superbrain-analysis-127d2e` · HEAD = `origin` · Overall **86 %** · `MARKET_READY:false`
`P0 100 · P1 100 · P2 100 · P3 44 · P4 100 · P5 68 · P6 90`
`FE 100 · ORC 100 · AP 69 · LLM 55 · MCP 56 · MEM 90 · OBS 100`

**Capability-Gates: 5 offen / 5 zu** · **Externe Gates: nur noch `ghcr_image_digest_verify`**

| offen ✅ | zu 🔴 |
|---|---|
| `live_llm_provider_calls` | `production_auth_identity` (O1) |
| `live_memory_provider` | `live_agent_tool_writes` + `live_mcp_writes` (O4) |
| `cloudflare_native_zero_card_hosted_runtime` | `docker_registry_publish` (O3, **zuletzt**) |
| `live_vector_memory_search` **(neu)** | `phase6_scale_runtime` (Zahlung = echte Wand) |
| `hosted_observability_endpoint` | |

**Hosted echt bewiesen:** Produktabnahme + 22-Seiten-Matrix mit `dev_only=false`,
`proof_scope=hosted_https` — 22/22 Routen · 29/29 Familien · 161/161 Aktionen · 0 tote · 0 Fehler.

---

## ▶ ARBEITSREIHENFOLGE BIS MARKTREIFE

**1. Restarbeit schließen (klein, zuerst).** Hosted-Source-Rebinding: Wahrheit bindet auf `af61146e`,
   der Worker meldet in `/api/v1/health` noch `62648856`. `wrangler secret put` für
   `SOURCE_COMMIT_SHA` + `SOURCE_ARCHIVE_SHA256` wiederholen (Rate-Limit war die Ursache),
   danach **per `health` gegenprüfen**. Exakter Befehl: Übergabe §2.5.

**2. L6 90 → 100 gutschreiben.** O5 ist bewiesen, der Prozentwert **noch nicht** fortgeschrieben.
   Marker `hosted_lexical_memory_only_vector_search_vectorize_pending` ist überholt.
   **Kein Doppelcredit** — die lexikalische D1-Persistenz zählt bereits.

**3. O4 abschließen.** Owner-Freigabe liegt vor. Gebundenen Live-Write-Verifier bauen, Grenzen hart
   durchsetzen, Audit fail-closed, Gates nur über `verify:runtime` + `verify:browser` öffnen.

**4. P3 (O1).** Konfiguration erledigt, lokal `verified_dev_only`. Der interaktive GitHub-Klick ist
   eine **echte Owner-Wand**. Nur den ohne ihn beweisbaren Teil gutschreiben.

**5. P5/P6 Restzellen.** Nur noch nicht kreditierte, live beweisbare Marker.
   `phase6_scale_runtime` bleibt zu (Zahlung).

**6. O3 GHCR — ZULETZT**, laut Matrix erst nach `MARKET_READY: true`.

---

## ⚠️ DIE ACHT FALLEN (alle in Session 13 real passiert)
| Falle | Richtig |
|---|---|
| `Authorization: Bearer` am Worker | **`x-superbrain-agent-token`** |
| `--var SOURCE_COMMIT_SHA` | Sind **Secrets** → `wrangler secret put` |
| `//`-Kommentar in `wrangler.jsonc` | Verifier parst mit reinem `ConvertFrom-Json` → **keine Kommentare** |
| Substring-Check `semantic\|vectorize` | Traf Non-Claims → **falsches Grün**. Auf **Verwendung** prüfen |
| `Set-Location` + `[IO.File]` | .NET hat eigenes CWD → **absolute Pfade** |
| `Set-Content` zum Restaurieren | Ändert BOM/Zeilenenden → **`git checkout --`** |
| 1-Zeichen-Funktionsnamen | `H` = `Get-History`; Exception gab Token aus |
| `ErrorActionPreference='Stop'` um Kindprozess | stderr wird terminierend → Test bricht zu früh ab |

**Merksatz:** *Verträge nie über Wortvorkommen prüfen, immer über tatsächliche Verwendung.*

## 🔗 GEKOPPELTE ASSERTIONS — nie einzeln anfassen
Gate schließen ⇒ im **selben Slice**: `verify-phase1.ps1` · `verify-market-ready.ps1` (2 Stellen) ·
`owner-input-manifest.json`. (`verify-go-live-readiness.ps1` ist bereits konditional.)
Jeder `verify-external-gates`-Lauf erzeugt ein **neues** Artefakt in `.phase1-artifacts/` —
`PROJECT_STATE.md`, `AI_HANDOFF.md` **und** `docs/verification-register.md` müssen auf das neueste zeigen.

## 🧱 STRUKTURELL
`npm run verify` kann auf einem **frischen Clone nie grün** werden: Die LLM-Evidenzkette hängt an zwei
**untracked** Artefakten. Bei Drift: `.codex/tmp/stateful-browser-sync.ps1`.

---

## 🔒 PFLICHT-PROTOKOLL
1. `$env:TEMP`/`$env:TMP` = `D:\_sb_tmp` **vor jedem** Verifier.
2. Nach **jedem** Commit an Verifier/Wahrheitsdatei: **Gesamtlauf**, nicht nur Fokustest.
3. Fremde dirty Dateien nie anfassen · **nie `git add -A`**.
4. Kein paralleler Verify-/Playwright-/Docker-Lauf.
5. Rot ohne Codeänderung? Zuerst `Get-PSDrive C,D`, dann Docker-Health.

## ⛔ REGELN (R0)
`live_verified` **nie** handsetzen · keine Doppelzählung · Free-Only (kein R2, kein Fly, keine Karte) ·
keine Secrets ausgeben · **kein `main`** (existiert nicht — Default ist `chore/repo-bootstrap`,
bereits geschützt) · kein Force-Push · kein GHCR/Release ohne Gate · Localhost = **DEV-ONLY**.

## ⛔ VIER WÄNDE
1. Kreditkarte/Zahlung · 2. Passwort-Accounts · 3. CAPTCHA · 4. Secrets ausgeben/committen

---

## 🏁 FERTIG HEISST EXAKT
`npm run verify:market-ready` druckt real **`MARKET_READY: true`**.
**Oder:** alles autonom Lösbare echt auf 100 **+** der Rest exakt als OWNER-BLOCKED mit
Owner-Action-Paket. Nichts anderes.

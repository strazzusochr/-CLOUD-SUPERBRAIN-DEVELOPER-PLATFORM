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
`FE 100 · ORC 100 · AP 100 · LLM 55 · MCP 56 · MEM 100 · OBS 100`

**Capability-Gates: 7 offen / 3 zu** · **Externe Gates: nur noch `ghcr_image_digest_verify`**

| offen ✅ | zu 🔴 |
|---|---|
| `live_llm_provider_calls` | `production_auth_identity` (O1 — OAuth-Klick = Owner-Wand) |
| `live_memory_provider` | `docker_registry_publish` (O3 — **zuletzt**, nach MARKET_READY) |
| `cloudflare_native_zero_card_hosted_runtime` | `phase6_scale_runtime` (Zahlung = echte Wand) |
| `live_vector_memory_search` | |
| `hosted_observability_endpoint` | |
| `live_agent_tool_writes` **(O4, neu)** | |
| `live_mcp_writes` **(O4, neu)** | |

## 🧮 WARUM VERTIKALE ARBEIT DIE 86 % NIE BEWEGT
`scripts/verify_project_progress_manifest.py` erzwingt:
`overall_percent == round(Summe der horizontalen Phasen / Anzahl)`.
**Vertikale Layer fließen gar nicht ein.** L3 69→100 und L6 90→100 haben `overall` deshalb korrekt
bei 86 gelassen — das ist Arithmetik, kein Beschönigen. Wer die 86 bewegen will, muss **P3, P5 oder P6**
bewegen. Alle drei sind Owner-/Zahlungs-Gates.

## ⛔ L4 (55) UND L5 (56) SIND NICHT „VERGESSEN" — SIE SIND BEWUSST NULL-CREDIT
Die Fähigkeiten **sind** bewiesen (L4: `gateway_mode=cloudflare_workers_ai_live`, `live_calls=true`,
`direct=false`, hosted+auditiert · L5: bounded, auditierter MCP-Write mit Rollback). Trotzdem gilt:
- `actions[O4].percentage_credit_breakdown` = `layer_3: 31`, **`layer_5: 0`**, `phase_6: 0`
- `actions[O6].percentage_credit` = **0**, Boundary: *„does not make Layer 4 equal 100 … or grant
  percentage credit"*

**Beide Nullen werden hart geprüft** — von `verify-market-ready.ps1` **und**
`verify-o4-live-writes.ps1` (`[int]$o4Action.percentage_credit_breakdown.layer_5 -eq 0`).
**Wer L4 oder L5 hochsetzt, bricht zwei Verifier und erzeugt Fake-Vollständigkeit. Nicht anfassen.**

**Hosted echt bewiesen:** Produktabnahme + 22-Seiten-Matrix mit `dev_only=false`,
`proof_scope=hosted_https` — 22/22 Routen · 29/29 Familien · 161/161 Aktionen · 0 tote · 0 Fehler.

---

## ▶ ARBEITSREIHENFOLGE BIS MARKTREIFE

**1. ✅ Restarbeit geschlossen.** Hosted-Source-Rebinding meldet in `/api/v1/health`
   exakt `af61146e22d1a56e9d62232c159ea7b352405ba9` +
   `1d85f2cd6c948a43e0f79fb17d1f02706687d5857d80f4096780692d094b63fc`.
   Worker-Version: `757cf74c-7988-4790-ae03-ff51534ccea4`.

**2. ✅ L6 90 → 100 gutgeschrieben.** Marker:
   `hosted_semantic_vector_search_cloudflare_vectorize_roundtrip_verified`.
   **Kein Doppelcredit** — die lexikalische D1-Persistenz bleibt ihr eigener Slice.

**3. ✅ O4 abgeschlossen.** `live_agent_tool_writes` + `live_mcp_writes` sind vom Verifier geöffnet,
   Evidenz `.phase1-artifacts/o4-live-writes/proof.json`, Audit vor/nach Write + Readback + Rollback
   bewiesen, `main_write=false`. Agent Pool **69 → 100** (Credit 31, itemisiert hinterlegt).

**4. P3 (O1) — OWNER.** Konfiguration erledigt, lokal `verified_dev_only`. Der interaktive
   GitHub-Zustimmungsklick ist eine **echte Owner-Wand**.

**5. P6 — ZAHLUNG.** `phase6_scale_runtime` braucht Zahlung. Eine der vier Wände.

**6. P5 / O3 GHCR — OWNER, ZULETZT**, laut Matrix erst nach `MARKET_READY: true`.

## 🧾 OWNER-AKTIONSPAKET — nur noch ZWEI Handlungen trennen uns von der Finish-Line

**O1 — GitHub-OAuth-Klick (schaltet P3 44 → höher)**
Der Owner öffnet die OAuth-App-Autorisierung und bestätigt einmalig den Zustimmungsdialog.
Konfiguration ist fertig (Compose + `JWT_SIGNING_SECRET`), lokal `verified_dev_only`.
Danach Codex: hosted Nachweis fahren, `production_auth_identity` **nur** über den echten Verifier
öffnen. **Der Klick selbst ist eine der vier Wände — kein Agent darf ihn ersetzen.**

**O3 — GHCR (schaltet P5 68 → höher) — ERST NACH `MARKET_READY: true`**
Owner gibt Registry-Publikation der sechs Images aus dem aktiven RC frei.
`codex_boundary` verbietet es davor. Danach: `verify:release-candidate` +
`verify:current-release-candidate`.

**P6 90 bleibt zu** — `phase6_scale_runtime` braucht Zahlung. Wand, kein Verhandlungsgegenstand.

## 🛑 EHRLICHER BEFUND: DIE AUTONOME FLÄCHE IST ERSCHÖPFT
Jede Zelle unter 100 ist entweder **owner-/zahlungsgewallt** (P3, P5, P6) oder **bewusst
null-kreditiert** (L4, L5). Es gibt derzeit **keine** Zelle, die ein Agent ohne Owner-Handlung
ehrlich anheben könnte. Wer trotzdem eine Zahl erhöht, fälscht.
**Nächste echte Arbeit beginnt erst nach einer Owner-Entscheidung (O1 oder O3).**

---

## ⚠️ DIE ACHT FALLEN (alle in Session 13 real passiert)
| Falle | Richtig |
|---|---|
| `Authorization: Bearer` am Worker | **`x-superbrain-agent-token`** |
| `wrangler secret put SOURCE_*` | Remote sind beide `plain_text`; `secret put` scheitert mit `10053`. Rebind per `deploy --keep-vars --var ...` |
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

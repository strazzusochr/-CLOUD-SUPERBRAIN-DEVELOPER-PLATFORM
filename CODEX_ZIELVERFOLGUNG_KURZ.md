# 🎯 ZIEL-VERFOLGUNG (KURZ) — Stand 2026-08-04 · RC13

> **Reihenfolge in JEDER Session:** (1) diese Datei → (2) `CODEX_UEBERGABE_2026-08-04-FINAL.md`
> → (3) **`REGELN_OPTIK_UND_FERTIG.md`** → (4) Preflight → (5) arbeiten.

## ENDZIEL

`npm run verify:market-ready` druckt real **`MARKET_READY: true`**.
Beide Matrizen 100 %, jede Zelle mit echtem Artefakt.
Owner-gewallte Reste ehrlich als **OWNER-BLOCKED** listen — **nie faken (R0)**.

---

## 🔴 OWNER-ENTSCHEIDUNG — gilt ab sofort

> **Organismus-Optik kommt GANZ ANS ENDE.** Alles andere ist wichtiger.
> Kein Agent arbeitet am Aussehen von `CortexCanvas3D`, bis Funktion und Ketten stehen.

---

## 🚀 START HIER — RC13 `db631ab3` · CI `30815984573` grün

```
[phase5-credit] verified mode=fully_itemized computed=89 credited=89 verified=17/19 blocked=I1,I5
```
Overall **89** · P3 44 · P5 89 · P6 90 · L4 55 · L5 56 · Gates **7/10 zu** · `MARKET_READY:false`

**Preflight:**
```powershell
Set-Location 'D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM'
$env:TEMP='D:\_sb_tmp'; $env:TMP='D:\_sb_tmp'
$env:PSModulePath='C:\Program Files\WindowsPowerShell\Modules;C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules'
git status --porcelain | Select-String '^ D'   # MUSS leer sein
(Get-PSDrive D).Free/1GB                       # vor Image-Builds
docker ps                                      # Daemon lebt?
```

---

## ⚠️ ZWEI NEUE BEFUNDE AUS DIESER SESSION

**1. Ein geschlossenes Gate war gebrochen — behoben.**
`.phase1-artifacts/live-vector-memory-search-proof.json` war beim 30-GB-Aufräumen gelöscht worden.
`verify-vector-memory-gate.ps1` schlug fehl: *„an opened vector gate is backed by an existing
evidence artifact"*. Per `git restore` wiederhergestellt, Gate wieder grün.
**Regel:** Aufräumen fasst `.phase1-artifacts/` und `docs/release-artifacts/` **nie** an.

**2. Das 5-Achsen-Audit ist teilweise fest verdrahtet.**
`verify-five-axis-substance-audit.mjs:295` ist ein **Literal**:
`console.log("… inspector=true replay=true neuroglass_tokens=12 organism_visual_v2=verified")`.
Ebenso `actions=161`, `docs_endpoint_mentions=98`, `strict_unfinished=0`, `dead_scaffolds=0`.
Zusätzlich prüft es, ob ein Markdown-Dokument Sätze enthält, die derselbe Commit hineinschrieb.
**Meine frühere Aussage „die fünf Achsen sind gemessen" ist damit falsch** — nur Layer-Prozente
und Routen-Klassifikation werden berechnet.

---

## ⛔ DIE VIER OWNER-WÄNDE

| Wand | öffnet | Art |
|---|---|---|
| **Worker-Deploy** auf `db631ab3` | `npm run verify` | Live-Fläche, keine Zahlung |
| **O1** OAuth | P3 +56 | zuerst Architekturentscheidung; Scope nur `read:user` |
| **`AGENT_API_AUTH_TOKEN`** | P6 +10 | ein Secret, keine Zahlung |
| **O3** GHCR | P5 +11 | zyklisch — Owner muss den Zyklus brechen |

**Zahlung öffnet nichts.**

---

## ✅ AUTONOM — in dieser Reihenfolge

```
1. Docker stabil bekommen  ->  npm run verify · verify:runtime · verify:browser
   (in dieser Session NICHT gelaufen: Daemon stuerzte beim Stack-Start ab)
2. L4 Responses-SSE fertig (Codex' laufender Slice, 16 dirty Dateien - nicht anfassen)
3. L5 Adapter aus contract/dry-run holen
4. Rubrik fuer L4/L5 vom Owner freigeben lassen  ->  erst DANN Prozente
5. RC14 binden
6. GANZ ZULETZT: Organismus-Optik
```

---

## 🔒 ZEHN REGELN, DIE JEDEN LAUF ENTSCHEIDEN

1. **Kein Commit benotet sich selbst** (R-SELF-1) — Prüfung vor Umsetzung, getrennter Commit, einmal rot.
2. **Quelltext-Textsuche ist keine Prüfung** (R-SELF-2) — `includes("function DotGlobe")` misst nichts.
3. **Optik-Behauptung nur mit Screenshot gegen benannte Referenz** (R-VIS-1/2).
4. **O4 zuletzt** vor den Ketten — jeder Commit danach macht den Beweis stale.
5. **`start-dev-live.ps1` NACH `verify:runtime`, VOR `verify:browser`** — sonst
   `deterministic_dry_run` und ein 129-Zeichen-Stub. Modus prüfen, nicht der Startmeldung trauen.
6. **Evidenz VERBATIM** — Nachbearbeiten bricht die Kreuzreferenz-Hashes.
7. **`gh workflow run` nimmt einen Ref, keinen SHA** — Kontroll-Commit auf den Kandidaten,
   eigener Branch, danach **mergen** (nicht cherry-picken).
8. **Nie `git add -A`**, nie Commit ohne Pathspec.
9. **Nie parallel** Playwright / Docker / Verifier.
10. **Neuem Prüfschritt erst nach einem roten Lauf glauben.**

---

## ⛔ VERBOTEN

Prozente oder `live_verified` von Hand · L4/L5 ohne freigegebene Rubrik hochsetzen ·
Selbstbenotung · Quelltext-Grep als Abnahme · Effekte zählen, die unter Test aus sind ·
`.phase1-artifacts/` oder `docs/release-artifacts/` beim Aufräumen löschen ·
Hosted-Deploy ohne Freigabe · Zahlung/Karte/Paid Provider/Fly.io/R2 ·
Secrets ausgeben (nur Pfad + Fundtyp) · Force-Push · Push auf Default-Branch ·
DEV-ONLY als Hosted-Beweis ausgeben.

**Vier Wände:** Kreditkarte/Zahlung · Passwort-Konten · CAPTCHA · Secrets ausgeben/committen.

---

*RC13 `db631ab3` · CI `30815984573` grün · Overall 89 · Gates 7/10 zu · `MARKET_READY:false`
Details: `CODEX_UEBERGABE_2026-08-04-FINAL.md` · Regeln: `REGELN_OPTIK_UND_FERTIG.md`*

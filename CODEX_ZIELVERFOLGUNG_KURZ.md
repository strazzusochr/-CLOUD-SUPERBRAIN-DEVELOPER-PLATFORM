# 🎯 ZIEL-VERFOLGUNG (KURZ) — Endspurt, Stand 2026-08-02

> **Reihenfolge in JEDER Session:** (1) diese Datei → (2) `CODEX_UEBERGABE_2026-08-02-FINAL.md`
> → (3) Preflight → (4) arbeiten. `…SESSION14.md` = Detailprotokoll, `…SESSION13.md` = Historie.

## ENDZIEL

`npm run verify:market-ready` druckt real **`MARKET_READY: true`**.
Beide Matrizen 100 %, jede Zelle mit echtem Artefakt.
Owner-gewallte Reste ehrlich als **OWNER-BLOCKED** listen — **nie faken (R0)**.

---

## 🚀 START HIER — Kandidat `6261f9f8` · CI `30762156522` **grün**

**RC12 ist gebunden. Der Verifier bestätigt es selbst:**

```
[phase5-credit] verified mode=fully_itemized computed=89 credited=89 verified=17/19 blocked=I1,I5
```

Overall **89** · P3 44 · P5 89 · P6 90 · L4 55 · L5 56 · Gates **7/10 zu** · `MARKET_READY:false`

**Preflight (PSModulePath ist Pflicht aus pwsh 7):**

```powershell
Set-Location 'D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM'
$env:TEMP='D:\_sb_tmp'; $env:TMP='D:\_sb_tmp'
$env:PSModulePath='C:\Program Files\WindowsPowerShell\Modules;C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules'
```

---

## ⛔ DER EINE BLOCKER — Owner-Entscheidung, kein Bug

`npm run verify` stoppt an **Cloudflare-Worker-Source-Parität**: der gehostete Worker läuft auf
`af61146e`, der Kandidat ist `6261f9f8`.

Auflösen heißt **einen öffentlich erreichbaren Live-Worker neu deployen**. Kostenlos
(zero-card), aber eine Live-Fläche — deshalb rührt kein Agent das an. Danach läuft die Kette durch.

---

## 🧱 DIE VIER WÄNDE

| Wand | öffnet | Art |
|---|---|---|
| **Worker-Deploy** auf `6261f9f8` | `npm run verify` | Live-Fläche, keine Zahlung |
| **O1** OAuth-Identität | P3 +56 | braucht **zuerst** Architekturentscheidung: CF-native **oder** hosted PG+Redis. Vercel ist read-only und kann O1 nicht erfüllen. Scope nur `read:user` |
| **`AGENT_API_AUTH_TOKEN`** | P6 +10 | **Secret, keine Zahlung.** Danach 900 echte Requests |
| **O3** GHCR | P5 +11 | **zyklisch** — Push verboten vor `MARKET_READY:true`, das GHCR-Digests verlangt. Owner muss den Zyklus brechen |

**Zahlung öffnet nichts** — `payment_required` ist überall `false`; eine abgebildete Zahlung
macht die Owner-Matrix **rot**.

---

## ✅ AUTONOM, SOFORT MÖGLICH

1. **`organism-visual-v2`** — 5 von 7 Effekten fehlen (Dot-Globus, Matrix-Rain, Scanlines,
   Shards, Waveform). Die Substanz ist echt: GLB lädt, Szene kommt aus
   `/api/v1/organism/live-state|events|replay`. **Optik-Lücke, keine Substanz-Lücke.**
   Additiv auf `CortexCanvas3D`, `data-testid` unverändert, voller `verify:browser` als Abnahme.
2. **Die 5 ungemessenen Achsen** (Übergabe §8): 22 Seiten · L4/L5 · Docs-Versprechen ·
   halbfertiger Code · Inspector/Replay/Design-System. Das Audit lief **zweimal ins Limit** —
   **sequenziell inline messen, nicht per Subagent.**

---

## 🔒 ACHT REGELN, DIE JEDEN LAUF ENTSCHEIDEN

1. **O4 zuletzt** vor den Ketten — jeder Commit danach macht den Beweis stale.
2. **`start-dev-live.ps1` NACH `verify:runtime`, VOR `verify:browser`** — die Runtime-Kette setzt
   den Gateway auf `deterministic_dry_run` zurück; danach liefert das Modell einen 129-Zeichen-Stub.
   Prüfen: `docker exec …llm-gateway-1 sh -c 'echo $LLM_GATEWAY_MODE'` muss `…_live` sagen.
3. **Evidenz VERBATIM** aus dem erzeugenden Lauf — Nachbearbeiten bricht die Kreuzreferenz-Hashes.
4. **CI-Dispatch:** `gh workflow run` nimmt einen **Ref, keinen SHA**. Kontroll-Commit direkt auf
   den Kandidaten, eigener Branch, dispatchen, danach **mergen** (nicht cherry-picken).
5. **Nie `git add -A`**, nie `git commit` ohne Pathspec.
6. **`PSModulePath` setzen** — sonst fehlen PS-5.1-Standard-Cmdlets.
7. **Nie parallel** Playwright / Docker / Verifier.
8. **Jedem neuen CI-Step erst nach einem roten Lauf glauben.** Vier Steps liefen monatelang nur
   `skipped` — und enthielten **alle** Fehler.

---

## ⛔ VERBOTEN

Prozente oder `live_verified` von Hand · L4/L5 hochsetzen · kanonische Anker aufweichen ·
Hosted-Deploy ohne Freigabe · Zahlung/Karte/Paid Provider/Fly.io/R2 · Secrets ausgeben
(**nur Pfad + Fundtyp**) · Token rotieren · Force-Push · Push auf Default-Branch ·
DEV-ONLY-Evidenz als Hosted-Beweis ausgeben.

**Vier Wände:** Kreditkarte/Zahlung · Passwort-Konten · CAPTCHA · Secrets ausgeben/committen.

---

*Details, Belege und Owner-Klickfolgen: `CODEX_UEBERGABE_2026-08-02-FINAL.md`*
